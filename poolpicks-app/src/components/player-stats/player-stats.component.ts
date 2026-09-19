import { Component, ChangeDetectionStrategy, inject, signal, computed, effect, OnDestroy, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { GameService } from '../../services/game.service';
import { DataService } from '../../services/data.service';
import { TeamService } from '../../services/team.service';
import { Pool, Participant } from '../../models/pool.model';
import { Game } from '../../models/game.model';
import { AuthService, User, UserStats } from '../../services/auth.service';
import { PoolStateService } from '../../services/pool-state.service';
import { Trophy, Achievement } from '../../models/achievement.model';
import { AchievementService } from '../../services/achievement.service';
import { SafeHtmlPipe } from '../achievement-toast/achievement-toast.component';
import { PoolHistoryService } from '../../services/pool-history.service';

interface WeeklyPlayerStats {
  record: {
    correct: number;
    incorrect: number;
    pending: number;
  };
  percentage: number;
  score: number;
  underdogs: {
    picked: number;
    correct: number;
  };
  pointsVsField: number;
}

@Component({
  selector: 'app-player-stats',
  imports: [CommonModule, RouterLink, SafeHtmlPipe],
  templateUrl: './player-stats.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PlayerStatsComponent implements OnDestroy {
  private route: ActivatedRoute = inject(ActivatedRoute);
  private dataService: DataService = inject(DataService);
  private gameService: GameService = inject(GameService);
  private teamService: TeamService = inject(TeamService);
  private authService: AuthService = inject(AuthService);
  private router: Router = inject(Router);
  private poolStateService: PoolStateService = inject(PoolStateService);
  private achievementService: AchievementService = inject(AchievementService);
  private readonly poolHistory = inject(PoolHistoryService);

  poolId = signal<string | null>(null);
  participantName = signal<string | null>(null);
  viewedWeek = signal<number | null>(null);

  pool = signal<Pool | null | undefined>(undefined);
  allPools = signal<Pool[]>([]);
  viewedUser = signal<User | null>(null);
  private readonly params = toSignal(this.route.paramMap);
  private readonly query = toSignal(this.route.queryParamMap);
  private readonly userId = computed(() => this.authService.currentUser()?.uid);
  private loadVersion = 0;
  private destroyed = false;

  participant = computed(() => {
    const p = this.pool();
    const name = this.participantName();
    const week = this.viewedWeek();
    if (!p || !name || week === null) return null;
    const uid = this.query()?.get('uid');
    const matches = (part: Participant) => uid ? part.userId === uid : part.displayName === name;

    if (p.week === week) {
      return p.participants.find(matches) || null;
    }
    return p.history?.[week]?.find(matches) || null;
  });

  playerData = computed<{ weekly: WeeklyPlayerStats, overall: UserStats, trophies: Trophy[], badges: Achievement[] } | null>(() => {
    const participant = this.participant();
    const allGames = this.gameService.games();
    const currentPool = this.pool();
    const viewedWeek = this.viewedWeek();
    const participantName = this.participantName();
    const allPoolsData = this.allPools();
    const user = this.viewedUser();

    if (!participant || !allGames.length || !currentPool || viewedWeek === null || !participantName) return null;

    // --- Weekly Stats Calculation ---
    let correct = 0;
    let incorrect = 0;
    let pending = 0;
    let totalFinal = 0;
    let underdogsPicked = 0;
    let underdogsCorrect = 0;
    
    const gamesById = new Map<number, Game>(allGames.map(g => [g.id, g]));

    for (const pick of participant.picks ?? []) {
      const game = gamesById.get(pick.gameId);
      if (!game) continue;

      const isUnderdogPick = pick.isUnderdog === true;

      if (isUnderdogPick) {
        underdogsPicked++;
      }

      if (game.status === 'final') {
        totalFinal++;
        if (game.winner === pick.winner) {
          correct++;
          if (isUnderdogPick) {
            underdogsCorrect++;
          }
        } else {
          incorrect++;
        }
      } else {
        pending++;
      }
    }

    const percentage = totalFinal > 0 ? Math.round((correct / totalFinal) * 100) : 0;
    
    const participantsForWeek = viewedWeek === currentPool.week ? currentPool.participants : (currentPool.history?.[viewedWeek] ?? []);
    const competitors = participantsForWeek.filter(p => p.userId !== participant.userId);
    let pointsVsField = 0;
    if (competitors.length > 0) {
        const competitorTotalScore = competitors.reduce((sum, c) => sum + c.score, 0);
        const competitorAverageScore = competitorTotalScore / competitors.length;
        pointsVsField = participant.score - competitorAverageScore;
    }

    const weekly: WeeklyPlayerStats = {
      record: { correct, incorrect, pending },
      percentage,
      score: participant.score,
      underdogs: { picked: underdogsPicked, correct: underdogsCorrect },
      pointsVsField
    };

    // --- Overall Stats, Trophies, and Badges ---
    const overall: UserStats = user?.stats ?? {
      totalScore: 0,
      averageScore: 0,
      firstPlaceFinishes: 0,
      secondPlaceFinishes: 0,
      thirdPlaceFinishes: 0,
      weeksPlayed: 0,
    };
    
    const trophies: Trophy[] = [];
    const trophiesFound = new Set<string>(); // "poolId_week"

    for (const p of allPoolsData) {
      const history = p.history ?? {};
      
      for (const weekStr in history) {
        const weekKey = `${p.id}_${weekStr}`;
        if (trophiesFound.has(weekKey)) continue;

        const weekParticipants = history[weekStr];
        const userAsParticipant = weekParticipants.find(wp => wp.userId === participant.userId);

        if (userAsParticipant) {
          const sorted = [...weekParticipants].sort((a, b) => b.score - a.score);
          if (sorted.length > 0 && sorted[0].score > 0) { // only count if there's a non-zero winner
            const userRank = sorted.findIndex(s => s.userId === userAsParticipant.userId);
            if (userRank !== -1 && userRank < 3) {
              const rank = (userRank + 1) as 1 | 2 | 3;
              trophies.push({
                 poolId: p.id,
                 poolName: p.name,
                 week: Number(weekStr),
                 year: p.year,
                 rank: rank as 1 | 2 | 3
              });
              trophiesFound.add(weekKey);
            }
          }
        }
      }
    }

    trophies.sort((a, b) => {
      if (b.year !== a.year) return b.year - a.year;
      return b.week - a.week;
    });
    
    const badges = this.achievementService.getUnlockedBadges(user);

    return { weekly, overall, trophies, badges };
  });

  poolPicksRating = computed(() => {
    const data = this.playerData();
    const currentPool = this.pool();
    const allGames = this.gameService.games();
    const participant = this.participant();
    const viewedWeek = this.viewedWeek();

    if (!data || !currentPool || !participant || viewedWeek === null) {
      return 0;
    }
    
    // Create a snapshot of overall stats to potentially augment with current week's results
    const tempOverall = { ...data.overall };
    const weekly = data.weekly;
    
    // If the viewed week is the pool's active week AND it's fully concluded,
    // let's factor its result into the rating calculation as if it were history.
    const isCurrentWeekConcluded = currentPool.week === viewedWeek && 
                                   allGames.length > 0 && 
                                   allGames.every(g => g.status === 'final');
    
    if (isCurrentWeekConcluded) {
      // Avoid double-counting if this week is somehow already in history
      const weekAlreadyInHistory = currentPool.history && currentPool.history[viewedWeek];
      if (!weekAlreadyInHistory) {
        tempOverall.weeksPlayed += 1;
        tempOverall.totalScore += weekly.score;
        tempOverall.averageScore = tempOverall.weeksPlayed > 0 ? tempOverall.totalScore / tempOverall.weeksPlayed : 0;

        // Determine rank for the concluded week
        const participantsForWeek = currentPool.participants;
        const sorted = [...participantsForWeek].sort((a, b) => b.score - a.score);
        const userRank = sorted.findIndex(p => p.userId === participant.userId);

        if (sorted.length > 0 && sorted[0].score > 0) {
            if (userRank === 0) tempOverall.firstPlaceFinishes += 1;
            else if (userRank === 1) tempOverall.secondPlaceFinishes += 1;
            else if (userRank === 2) tempOverall.thirdPlaceFinishes += 1;
        }
      }
    }
    
    const historicalRating = (tempOverall.weeksPlayed * 20) +
                           (tempOverall.firstPlaceFinishes * 150) +
                           (tempOverall.secondPlaceFinishes * 75) +
                           (tempOverall.thirdPlaceFinishes * 40) +
                           Math.round(tempOverall.averageScore * 1.5);
    
    const weeklyBonus = Math.round(weekly.pointsVsField) + 
                        (weekly.record.correct * 5) + 
                        (weekly.underdogs.correct * 20);
                        
    // Base rating gives new players a non-zero start and acknowledges participation.
    const baseRating = 100;
    const totalRating = baseRating + historicalRating + weeklyBonus;
    
    return Math.max(0, Math.round(totalRating));
  });

  constructor() {
    effect(() => {
      if (!this.authService.authReady()) return;
      if (!this.userId()) {
        this.router.navigate(['/']);
        return;
      }
      const id = this.params()?.get('id');
      const name = this.params()?.get('name');
      const week = Number(this.query()?.get('week'));
      if (!id || !name) { this.pool.set(null); return; }
      this.poolId.set(id);
      this.participantName.set(name);
      this.viewedWeek.set(Number.isInteger(week) && week > 0 && week <= 22 ? week : null);
      this.poolStateService.setCurrentPoolId(id);
      untracked(() => void this.loadPoolData(id));
    });

    effect(() => {
      const week = this.viewedWeek();
      const year = this.pool()?.year;
      if (week && year && (this.gameService.gamesWeek() !== week || this.gameService.gamesYear() !== year)) {
        untracked(() => this.gameService.loadSpecificWeek(week, year));
      }
    });

    effect(() => {
      if (this.poolStateService.refreshRequested() > 0) {
        const id = this.poolId();
        if (id) {
          untracked(() => void this.loadPoolData(id));
        }
      }
    });
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    this.loadVersion++;
    this.poolStateService.setCurrentPoolId(null);
  }

  async loadPoolData(poolId: string) {
    const version = ++this.loadVersion;
    this.pool.set(undefined); // loading
    this.viewedUser.set(null);
  
    let poolData: Pool | null = null;
    let allPoolsData: Pool[] = [];
  
    try {
      // First, get the primary pool for this page
      const fetchedPoolData = await this.dataService.getPool(poolId);
      if (this.destroyed || version !== this.loadVersion) return;
      if (!fetchedPoolData) {
        // Pool not found, exit gracefully
        this.pool.set(null);
        return;
      }
      poolData = fetchedPoolData;
      if (!this.viewedWeek()) this.viewedWeek.set(poolData.week);
  
      // Now find the participant in this pool to get their UID
      const participantName = this.participantName();
      const viewedWeek = this.viewedWeek();
      let participant: Participant | undefined;
      if (participantName && viewedWeek !== null) {
        const participantsForWeek = viewedWeek === poolData.week ? poolData.participants : (poolData.history?.[viewedWeek] ?? []);
        const uid = this.query()?.get('uid');
        participant = participantsForWeek.find(p => uid ? p.userId === uid : p.displayName === participantName);
      }
  
      // Then, fetch all pools that participant has ever been in using their user document.
      if (participant) {
        const userForStats = await this.dataService.getUser(participant.userId);
        this.viewedUser.set(userForStats);
        if (userForStats && userForStats.joinedPools) {
          // Another player's private pools are not readable by this viewer.
          const viewerPools = this.authService.currentUser()?.joinedPools ?? {};
          const poolIds = Object.keys(userForStats.joinedPools).filter(id => id !== poolId && id in viewerPools);
          const results = await Promise.allSettled(poolIds.map(id => this.dataService.getPool(id)));
          const poolDetails = [poolData, ...results.flatMap(result => result.status === 'fulfilled' ? [result.value] : [])];
          allPoolsData = await Promise.all(poolDetails.filter((p): p is Pool => p !== null).map(p => this.poolHistory.withScores(p)));
        } else {
          // Fallback for legacy guests without a user doc.
          allPoolsData = [await this.poolHistory.withScores(poolData)];
        }
      }
      
    } catch (error) {
      console.error('Failed to load player stats data:', error);
      poolData = null; // Ensure we signal an error state
      allPoolsData = [];
    }
  
    if (!this.destroyed && version === this.loadVersion) {
      poolData = allPoolsData.find(p => p.id === poolId) ?? poolData;
      this.pool.set(poolData);
      this.allPools.set(allPoolsData);
    }
  }
}
