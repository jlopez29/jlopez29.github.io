

import { Component, ChangeDetectionStrategy, inject, signal, computed, effect, OnDestroy, Signal, untracked, viewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink, ParamMap } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { PicksComponent } from '../picks/picks.component';
import { LeaderboardComponent, LeaderboardParticipant } from '../leaderboard/leaderboard.component';
import { ScheduleComponent } from '../schedule/schedule.component';
import { PodiumComponent } from '../podium/podium.component';
import { GameService } from '../../services/game.service';
import { DataService } from '../../services/data.service';
import { AuthService, User } from '../../services/auth.service';
import { PoolService } from '../../services/pool.service';
import { Pool, Pick, Participant } from '../../models/pool.model';
import { Game } from '../../models/game.model';
import { PoolStateService } from '../../services/pool-state.service';
import { AchievementService } from '../../services/achievement.service';
import { PlayoffBracketComponent } from '../playoff-bracket/playoff-bracket.component';
import { PlayoffPicks } from '../../models/playoff.model';
import { PoolHistoryService } from '../../services/pool-history.service';

@Component({
  selector: 'app-pool',
  imports: [CommonModule, PicksComponent, LeaderboardComponent, ScheduleComponent, PodiumComponent, RouterLink, PlayoffBracketComponent],
  templateUrl: './pool.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PoolComponent implements OnDestroy {
  // FIX: Explicitly type injected services to work around a type inference issue where they were being resolved as 'unknown'.
  private route: ActivatedRoute = inject(ActivatedRoute);
  private router: Router = inject(Router);
  gameService: GameService = inject(GameService);
  private dataService: DataService = inject(DataService);
  private authService: AuthService = inject(AuthService);
  private poolService: PoolService = inject(PoolService);
  private poolStateService: PoolStateService = inject(PoolStateService);
  private achievementService: AchievementService = inject(AchievementService);
  private readonly poolHistory = inject(PoolHistoryService);
  private readonly processedWeeks = new Set<string>();
  private readonly picksForm = viewChild(PicksComponent);
  
  poolId = signal<string | null>(null);
  pool = signal<Pool | null | undefined>(undefined); // undefined: loading, null: not found
  currentUser = this.authService.currentUser;
  private readonly userId = computed(() => this.currentUser()?.uid);
  private loadVersion = 0;
  private destroyed = false;
  isSubmitting = signal(false);
  loadError = signal<string | null>(null);
  isScheduleDrawerOpen = signal(false);
  viewedWeek = signal<number | null>(null);
  showPodiumView = signal(false); // To toggle podium for historical weeks

  // State for the new pool creation flow
  private isCreatingPool = signal(false);
  private newPoolData = signal<{ name: string; inviteCode: string } | null>(null);
  
  // FIX: The type for `paramMap` and `queryParamMap` was being inferred as 'unknown'.
  // Explicitly typing them as `Signal<ParamMap | undefined>` resolves the issue.
  private paramMap: Signal<ParamMap | undefined> = toSignal(this.route.paramMap);
  private queryParamMap: Signal<ParamMap | undefined> = toSignal(this.route.queryParamMap);

  userHasSubmitted = computed(() => {
    if (this.isCreatingPool()) return false;
    const user = this.currentUser();
    if (!user) return false;
    
    const participant = this.participantsForViewedWeek().find(p => p.userId === user.uid);
    if (!participant) return false;

    if (this.isPlayoffPool()) {
      return !!participant.playoffPicks;
    } else {
      return !!participant.picks && participant.picks.length > 0;
    }
  });

  isPlayoffPool = computed(() => this.pool()?.type === 'playoff');
  
  isPickingOpen = computed(() => {
    const pool = this.pool();
    if (!pool) return false;

    const games = this.gameService.games();
    const gamesLoadedForViewedWeek = this.gameService.gamesWeek() === this.viewedWeek() && this.gameService.gamesYear() === pool.year;

    if (!gamesLoadedForViewedWeek || games.length === 0) {
        return false;
    }

    // Picking is open if we are creating a new pool,
    // OR if we are viewing the current active week of an existing pool.
    const canPickForThisWeek = this.isCreatingPool() || this.viewedWeek() === pool.week;

    if (!canPickForThisWeek) {
        return false;
    }
    
    // The only remaining check is if games for the viewed week have started.
    const allGamesAreScheduled = games.every(g => g.status === 'scheduled');
    return allGamesAreScheduled || this.gameService.createPoolOverride();
  });

  isReady = computed(() => {
    if (this.pool() === undefined) {
      return false;
    }
    // For both pool types, we are ready when the games for the specific `viewedWeek` are loaded.
    return this.gameService.gamesWeek() === this.viewedWeek() && this.gameService.gamesYear() === this.pool()?.year && !this.gameService.isLoading();
  });

  participantsForViewedWeek = computed<Participant[]>(() => {
    const p = this.pool();
    const week = this.viewedWeek();
    if (!p || week === null) return [];

    if (p.week === week) {
      return p.participants;
    }
    return p.history?.[week] ?? [];
  });

  availableWeeks = computed<number[]>(() => {
    const p = this.pool();
    const liveWeek = p?.year === this.gameService.year() ? this.gameService.week() : p?.week ?? this.gameService.week();
    
    if (!p || this.isCreatingPool()) {
        const viewed = this.viewedWeek();
        return viewed ? [viewed] : [];
    }

    const historyWeeks = p.availableWeeks ?? (p.history ? Object.keys(p.history).map(Number) : []);
    const potentialWeeks = new Set([p.week, ...historyWeeks, liveWeek]);
    
    const filteredWeeks = [...potentialWeeks].filter(week => {
        // Always include the current live week as an option.
        if (week === liveWeek) {
            return true;
        }
        // For past weeks, only include them if they have participants.
        if (week < liveWeek) {
            if (p.availableWeeks?.includes(week)) return true;
            const participantsForWeek = (p.week === week) ? p.participants : (p.history?.[week] ?? []);
            return participantsForWeek.length > 0;
        }
        // For future weeks (e.g., creating a pool for next week), include them.
        if (week > liveWeek) {
            return true;
        }
        return false;
    });

    return filteredWeeks.sort((a, b) => b - a);
  });

  leaderboardData = computed<LeaderboardParticipant[]>(() => {
    const participants = this.participantsForViewedWeek();
    const games = this.gameService.games();
    if (!participants.length) {
      return [];
    }
    // If games haven't loaded for this week, return participants with score from DB (for historical viewing).
    if (!games.length) {
        return participants.map(p => ({
            ...p, 
            score: p.score, 
            currentPotential: 0, 
            totalPotential: this.isPlayoffPool() 
                // FIX: Add explicit types to the `reduce` function's parameters to resolve an 'unknown' type error.
                ? Object.values(p.playoffPicks?.confidencePicks ?? {}).reduce((a: number, b: number) => a + b, 0)
                : p.picks?.reduce((sum, pick) => sum + pick.confidence, 0) ?? 0,
            tiebreakerDiff: undefined
        })).sort((a,b) => b.score - a.score);
    }
    
    const gamesById: Map<number, Game> = new Map(games.map(g => [g.id, g]));
    
    const tiebreakerGame = this.isSuperBowlWeek() 
        ? games[0] 
        : games.find(g => g.isMondayNight) ?? (games.length > 0 ? games[games.length - 1] : undefined);
    
    const tiebreakerTotalScore = tiebreakerGame && tiebreakerGame.status === 'final' 
        // FIX: Operator '+' cannot be applied to types 'number' and 'unknown'.
        // Explicitly casting to number to fix a persistent type inference issue.
        ? (tiebreakerGame.homeScore as number) + (tiebreakerGame.awayScore as number)
        : -1;

    const participantsWithScores = participants.map(p => {
      const tiebreakerDiff = tiebreakerTotalScore !== -1 ? Math.abs(p.tiebreaker - tiebreakerTotalScore) : undefined;
      
      if (this.isPlayoffPool()) {
        // --- Playoff Challenge Scoring Logic (Weekly) ---
        if (!p.playoffPicks?.confidencePicks) {
          return { ...p, score: 0, currentPotential: 0, totalPotential: 0, tiebreakerDiff };
        }
        
        let score = 0; // Score is calculated weekly
        let currentPotential = 0;
        const confidence = p.playoffPicks.confidencePicks;

        games.forEach(game => {
          if (game.status === 'final' && game.winner && confidence[game.winner]) {
            score += confidence[game.winner];
          } 
          else if (game.status === 'in_progress') {
            const currentWinner = game.homeScore > game.awayScore ? game.homeTeam : (game.awayScore > game.homeScore ? game.awayTeam : null);
            if (currentWinner && confidence[currentWinner]) {
              currentPotential += confidence[currentWinner];
            }
          }
        });
        
        const losersThisWeek = new Set<string>();
        games.forEach(game => {
          if (game.status === 'final' && game.winner) {
            const loser = game.winner === game.homeTeam ? game.awayTeam : game.homeTeam;
            losersThisWeek.add(loser);
          }
        });
        
        let totalPotential = Object.entries(confidence).reduce((sum, [team, conf]) => {
          if (!losersThisWeek.has(team)) {
            return sum + (conf ?? 0);
          }
          return sum;
        }, 0);

        return { ...p, score, currentPotential, totalPotential, tiebreakerDiff };

      } else {
        // --- Regular Season Scoring Logic ---
        if (!p.picks) {
           return { ...p, score: 0, currentPotential: 0, totalPotential: 0, tiebreakerDiff };
        }

        let score = 0;
        let currentPotential = 0;
        let totalPotential = p.picks.reduce((sum, pick) => sum + pick.confidence, 0);

        p.picks.forEach(pick => {
          const game = gamesById.get(pick.gameId);
          if (game) {
            if (game.status === 'final') {
              if (game.winner === pick.winner) {
                score += pick.confidence;
              } else {
                totalPotential -= pick.confidence;
              }
            } else if (game.status === 'in_progress') {
              const currentWinner = game.homeScore > game.awayScore 
                ? game.homeTeam 
                : game.awayScore > game.homeScore 
                  ? game.awayTeam 
                  : null;
              if (currentWinner === pick.winner) {
                currentPotential += pick.confidence;
              }
            }
          }
        });
        
        return { ...p, score, currentPotential, totalPotential, tiebreakerDiff };
      }
    });

    return participantsWithScores.sort((a, b) => {
      // 1. Score (desc)
      if (b.score !== a.score) {
        return b.score - a.score;
      }
      // 2. Current Potential (desc)
      if (b.currentPotential !== a.currentPotential) {
        return b.currentPotential - a.currentPotential;
      }
      // 3. Total Potential (desc)
      if (b.totalPotential !== a.totalPotential) {
        return b.totalPotential - a.totalPotential;
      }
      // 4. Tiebreaker (asc)
      if (tiebreakerTotalScore !== -1 && a.tiebreakerDiff !== undefined && b.tiebreakerDiff !== undefined) {
          return a.tiebreakerDiff - b.tiebreakerDiff;
      }
      // Fallback
      return a.displayName.localeCompare(b.displayName);
    });
  });
  
  weekConcluded = computed(() => {
    const games = this.gameService.games();
    // Week is concluded if there are games and all of them are final.
    return !this.gameService.isLoading() && this.gameService.gamesWeek() === this.viewedWeek()
      && this.gameService.gamesYear() === this.pool()?.year
      && games.length > 0 && games.every(g => g.status === 'final');
  });

  weekInProgress = computed(() => {
    const games = this.gameService.games();
    return games.length > 0 && games.some(g => g.status === 'in_progress');
  });

  gamesInfo = computed(() => {
    const allGames = this.gameService.games();
    const completed = allGames.filter(g => g.status === 'final').length;
    return {
      completed,
      total: allGames.length
    };
  });

  isHistoricalView = computed(() => {
    const p = this.pool();
    const vw = this.viewedWeek();
    if (!p || vw === null) return false;
    return p.week !== vw;
  });
  
  isSuperBowlWeek = computed(() => {
    // Super Bowl is the only week with just one game.
    return this.isPlayoffPool() && this.gameService.games().length === 1 && this.gameService.gamesWeek() === this.viewedWeek();
  });

  showPodium = computed(() => {
    const isWeekDataLoaded = this.gameService.gamesWeek() === this.viewedWeek();
    if (!this.weekConcluded() || !isWeekDataLoaded) {
      return false;
    }
    
    const user = this.currentUser();
    if (!user) return false;
    
    const participants = this.participantsForViewedWeek();
    const userParticipant = participants.find(part => part.userId === user.uid);
    
    if (!userParticipant) {
      return this.showPodiumView();
    }
    if (userParticipant.hasViewedPodium === false || userParticipant.hasViewedPodium === undefined) {
      return true;
    }
    return this.showPodiumView();
  });

  topThree = computed(() => this.leaderboardData().slice(0, 3));

  constructor() {
    // Effect 1: Handles route changes and initial setup for new OR existing pools.
    effect(() => {
        const id = this.paramMap()?.get('id');
        const liveWeek = this.gameService.week(); // Depend on liveWeek to prevent race condition
        this.queryParamMap();

        if (!this.authService.authReady()) return;
        if (!this.userId()) {
            this.router.navigate(['/']);
            return;
        }

        if (id) {
          this.poolId.set(id);
          this.poolStateService.setCurrentPoolId(id);
          if (id === 'new') {
              if (liveWeek <= 0) {
                return;
              }
              untracked(() => this.setupNewPool());
          } else {
              // Guard against running before the game service is initialized.
              if (liveWeek <= 0) {
                  return;
              }
              this.isCreatingPool.set(false);
              this.newPoolData.set(null);
              untracked(() => void this.loadPoolData());
          }
        } else {
            this.pool.set(null); // No ID, pool not found
        }
    });

    // Effect 2: Fetches game data when viewedWeek changes for an EXISTING pool.
    effect(() => {
        if (this.isCreatingPool() || !this.pool()) return;

        const week = this.viewedWeek();
        const loadedGamesWeek = this.gameService.gamesWeek();
        
        const year = this.pool()!.year;
        if (typeof week === 'number' && week > 0 && (week !== loadedGamesWeek || year !== this.gameService.gamesYear())) {
            untracked(() => this.gameService.loadSpecificWeek(week, year));
        }
    });
    
    // Scores are derived from the schedule. Updating them must not write to Firestore.
    effect(() => {
      const pool = this.pool();
      const leaderboard = this.leaderboardData();
      
      if (pool && leaderboard.length > 0 && pool.participants.length > 0 && this.viewedWeek() === pool.week
          && this.gameService.gamesWeek() === pool.week && this.gameService.gamesYear() === pool.year && !this.gameService.isLoading()) {
        const updatesNeeded = leaderboard.some(leaderboardParticipant => {
          const originalParticipant = pool.participants.find(p => p.userId === leaderboardParticipant.userId);
          return originalParticipant && originalParticipant.score !== leaderboardParticipant.score;
        });
        
        if (updatesNeeded) {
          this.updateLocalScores(leaderboard);
        }
      }
    });

    // Effect to refetch pool data when requested by another component (e.g., on avatar change)
    effect(() => {
      if (this.poolStateService.refreshRequested() > 0) {
        const id = this.poolId();
        if (id) {
          untracked(() => void this.loadPoolData());
        }
      }
    });
    
    // Effect to check for achievements when a week concludes
    effect(() => {
      const pool = this.pool();
      const user = this.currentUser();
      const viewedWeek = this.viewedWeek();
      
      if (this.weekConcluded() && pool && user && viewedWeek === pool.week) {
        const key = `${pool.id}/${pool.year}/${viewedWeek}/${user.uid}`;
        if (!this.processedWeeks.has(key)) {
          this.processedWeeks.add(key);
          untracked(() => void this.processConcludedWeek(pool.id, viewedWeek, user, key));
        }
      }
    });
  }

  private async processConcludedWeek(id: string, week: number, user: User, key: string) {
    try {
      const fullPool = await this.dataService.getPool(id);
      if (!fullPool) return;
      const scored = await this.poolHistory.withScores(fullPool);
      if (this.destroyed) return;
      await this.achievementService.processAndNotifyForConcludedWeek({
        ...scored, history: { ...scored.history, [scored.week]: scored.participants },
      }, week, user);
    } catch (error) {
      this.processedWeeks.delete(key);
      console.error('Could not check concluded-week achievements.', error);
    }
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    this.loadVersion++;
    this.poolStateService.setCurrentPoolId(null);
  }

  private setupNewPool(): void {
    const poolState = history.state as { poolName: string, inviteCode?: string, isNextWeek?: boolean, isPlayoff?: boolean };

    if (!poolState || !poolState.poolName || !poolState.inviteCode) {
        console.error('Pool creation state not found, redirecting home.');
        this.router.navigate(['/']);
        return;
    }
    
    const targetWeek = poolState.isPlayoff ? this.gameService.week() : (poolState.isNextWeek ? this.gameService.week() + 1 : this.gameService.week());
    const currentYear = this.gameService.year();

    if (this.gameService.gamesWeek() !== targetWeek) {
        this.gameService.loadSpecificWeek(targetWeek);
    }

    this.isCreatingPool.set(true);
    this.newPoolData.set({ name: poolState.poolName, inviteCode: poolState.inviteCode });
    
    const tempPool: Pool = {
        id: 'new',
        name: poolState.poolName,
        week: targetWeek,
        year: currentYear,
        participants: [],
        type: poolState.isPlayoff ? 'playoff' : 'regular',
    };
    this.pool.set(tempPool);
    this.viewedWeek.set(targetWeek);
  }

  toggleScheduleDrawer(isOpen?: boolean): void {
    this.isScheduleDrawerOpen.set(isOpen ?? !this.isScheduleDrawerOpen());
  }

  async loadPoolData() {
    const id = this.poolId();
    if (!id || this.isCreatingPool()) return;
  
    const version = ++this.loadVersion;
    this.pool.set(undefined); // Start loading
    this.loadError.set(null);
  
    let poolData: Pool | null = null;
  
    try {
      const user = this.authService.currentUser();
      const queryWeek = Number(this.route.snapshot.queryParamMap.get('week'));
      const readOptions = {
        historyWeeks: Number.isInteger(queryWeek) && queryWeek > 0 && queryWeek <= 22 ? [queryWeek] : [],
        includePreviousWeek: !queryWeek,
      };
      let fetchedPoolData = await this.dataService.getPool(id, readOptions);
      if (this.destroyed || version !== this.loadVersion) return;
      
      const liveWeek = this.gameService.week();
      
      // Advance stale, empty, regular season pools to the current week.
      if (fetchedPoolData && fetchedPoolData.year === this.gameService.year() && fetchedPoolData.ownerId === user?.uid && fetchedPoolData.type !== 'playoff' && fetchedPoolData.week < liveWeek && fetchedPoolData.participants.length === 0) {
          console.log(`Pool "${fetchedPoolData.name}" is on an empty past week (${fetchedPoolData.week}). Advancing to current week ${liveWeek}.`);
          const games = await this.gameService.getWeekGames(liveWeek, fetchedPoolData.year);
          await this.dataService.archiveAndAdvanceWeek(id, fetchedPoolData, liveWeek, this.weekLockAt(games));
          // After advancing, refetch the data before continuing.
          fetchedPoolData = await this.dataService.getPool(id, readOptions);
      }

      // Convert any regular season pool that is now in a playoff week to the playoff challenge format.
      if (fetchedPoolData && fetchedPoolData.ownerId === user?.uid && fetchedPoolData.week > this.gameService.LAST_REGULAR_SEASON_WEEK && fetchedPoolData.type !== 'playoff') {
        console.warn(`Pool "${fetchedPoolData.name}" is a regular season pool active during the playoffs. Converting to a playoff challenge.`);
        await this.dataService.updatePoolType(id, 'playoff');
        // Re-fetch the data to get the updated type and ensure subsequent logic is correct.
        fetchedPoolData = await this.dataService.getPool(id, readOptions);
      }
      if (this.destroyed || version !== this.loadVersion) return;
      
      poolData = fetchedPoolData;
  
      if (poolData) {
        if (typeof poolData.year !== 'number' || poolData.year <= 0) {
          poolData.year = this.gameService.year();
        }
        if (typeof poolData.week !== 'number' || poolData.week <= 0) {
          poolData.week = this.gameService.week();
        }
  
        const weekFromQuery = this.route.snapshot.queryParamMap.get('week');
        if (!weekFromQuery && poolData.type !== 'playoff') {
          let defaultWeek = poolData.week;

          if (poolData.year === this.gameService.year() && poolData.week < liveWeek) {
            defaultWeek = liveWeek;
          } 
          else if (user) { 
            const prevWeek = poolData.week - 1;
            const prevWeekHistory = poolData.history?.[prevWeek];
            if (prevWeekHistory) {
              const userInPrevWeek = prevWeekHistory.find(p => p.userId === user.uid);
              if (userInPrevWeek && (userInPrevWeek.hasViewedPodium === undefined || userInPrevWeek.hasViewedPodium === false)) {
                defaultWeek = prevWeek;
              }
            }
          }
          
          this.router.navigate([], { 
            relativeTo: this.route, 
            queryParams: { week: defaultWeek },
            queryParamsHandling: 'merge',
            replaceUrl: true 
          });
        } else {
            // For playoff pools or when week is in query, just set it.
            this.viewedWeek.set(readOptions.historyWeeks[0] ?? poolData.week);
        }
      }
    } catch (error) {
      console.error('Failed to load pool data:', error);
      if (this.destroyed || version !== this.loadVersion) return;
      this.loadError.set('Could not load this pool. Check your connection and make sure you have joined with the invite code.');
    }
    if (!this.destroyed && version === this.loadVersion) this.pool.set(poolData);
  }

  async handlePicksSubmitted(submission: { picks: Pick[], tiebreaker: number }) {
    const id = this.poolId();
    if (!id || this.isSubmitting()) return;
    this.isSubmitting.set(true);
    try {

    if (this.isCreatingPool()) {
      const newPoolInfo = this.newPoolData();
      const currentPool = this.pool();
      if (!newPoolInfo || !currentPool) {
        console.error('Pool data not available for new pool submission.');
        alert('Could not create pool. Please try again.');
        return;
      }

      const newPoolId = await this.poolService.createPoolAndSubmitInitialPicks({
        poolName: newPoolInfo.name, 
        inviteCode: newPoolInfo.inviteCode,
        picks: submission.picks, 
        tiebreaker: submission.tiebreaker, 
        week: currentPool.week, 
        year: currentPool.year,
        isPlayoff: currentPool.type === 'playoff',
        lockAt: this.weekLockAt(),
      });

      if (newPoolId) {
        this.picksForm()?.clearSavedDraft();
        setTimeout(() => {
          this.router.navigate(['/pool', newPoolId], { replaceUrl: true });
        }, 0);
      }
    } else {
      const currentPool = this.pool();
      const viewedWeek = this.viewedWeek();
      if (!currentPool || viewedWeek === null) return;
      
      if (viewedWeek > currentPool.week) {
        await this.dataService.archiveAndAdvanceWeek(id, currentPool, viewedWeek, this.weekLockAt());
      }
      
      const saved = await this.poolService.submitPicks(id, submission.picks, submission.tiebreaker, { year: currentPool.year, week: viewedWeek });
      if (saved) {
        this.picksForm()?.clearSavedDraft();
        await this.loadPoolData();
      }
    }
    } catch (error) {
      console.error('Could not submit picks:', error);
      alert(error instanceof Error ? error.message : 'Could not save picks. Please try again.');
    } finally {
      this.isSubmitting.set(false);
    }
  }
  
  async handlePlayoffPicksSubmitted(submission: { playoffPicks: PlayoffPicks, tiebreaker: number }) {
    const id = this.poolId();
    if (!id || this.isSubmitting()) return;
    this.isSubmitting.set(true);
    try {

    if (this.isCreatingPool()) {
      const newPoolInfo = this.newPoolData();
      const currentPool = this.pool();
      if (!newPoolInfo || !currentPool) {
        console.error('Pool data not available for new pool submission.');
        alert('Could not create pool. Please try again.');
        return;
      }

      const newPoolId = await this.poolService.createPlayoffPoolAndSubmitInitialPicks({
        poolName: newPoolInfo.name,
        inviteCode: newPoolInfo.inviteCode,
        playoffPicks: submission.playoffPicks,
        tiebreaker: submission.tiebreaker,
        week: currentPool.week,
        year: currentPool.year,
        lockAt: this.weekLockAt(),
      });

      if (newPoolId) {
        setTimeout(() => {
          this.router.navigate(['/pool', newPoolId], { replaceUrl: true });
        }, 0);
      }
    } else {
      const currentPool = this.pool();
      if (!currentPool) return;
      const saved = await this.poolService.submitPlayoffPicks(id, submission.playoffPicks, submission.tiebreaker, currentPool);
      if (saved) await this.loadPoolData();
    }
    } catch (error) {
      console.error('Could not submit playoff picks:', error);
      alert(error instanceof Error ? error.message : 'Could not save picks. Please try again.');
    } finally {
      this.isSubmitting.set(false);
    }
  }

  async handleStartNextWeek() {
    const id = this.poolId();
    const p = this.pool();
    const user = this.currentUser();
    if (!id || !p || !user) return;
    if (p.ownerId && p.ownerId !== user.uid) {
      alert('The pool owner needs to start the next week.');
      return;
    }

    try {
      const updatedParticipants = p.participants.map(participant => {
        if (participant.userId === user.uid) {
          return { ...participant, hasViewedPodium: true };
        }
        return participant;
      });

      const poolWithUpdatedFlag: Pool = { ...p, participants: updatedParticipants };
      const newWeek = p.week + 1;
      const nextGames = await this.gameService.getWeekGames(newWeek, p.year);
      const lockAt = this.weekLockAt(nextGames);
      await this.dataService.updateParticipants(id, updatedParticipants);
      await this.dataService.archiveAndAdvanceWeek(id, poolWithUpdatedFlag, newWeek, lockAt);
      
      this.router.navigate([], {
        relativeTo: this.route,
        queryParams: { week: newWeek },
        queryParamsHandling: 'merge'
      });
    } catch (error) {
      console.error('Failed to start next week:', error);
      alert('An error occurred while trying to advance to the next week. Please try again.');
    }
  }

  async handleViewLeaderboard() {
    const user = this.currentUser();
    const p = this.pool();
    const week = this.viewedWeek();

    if (!user || !p || week === null) {
      this.showPodiumView.set(false);
      return;
    }

    const participantsForWeek = (p.week === week) ? p.participants : (p.history?.[week] ?? []);
    const userParticipant = participantsForWeek.find(part => part.userId === user.uid);

    if (userParticipant && (userParticipant.hasViewedPodium === false || userParticipant.hasViewedPodium === undefined)) {
      try {
        if (p.week === week) {
          const updatedParticipants = p.participants.map(participant => 
            participant.userId === user.uid ? { ...participant, hasViewedPodium: true } : participant
          );
          this.pool.update(pool => pool ? { ...pool, participants: updatedParticipants } : null);
          await this.dataService.updateParticipants(p.id, updatedParticipants);
        } else {
          const history = { ...(p.history ?? {}) };
          const participantsInHistory = [...(history[week] ?? [])];
          const userIndex = participantsInHistory.findIndex(part => part.userId === user.uid);
          
          if (userIndex > -1) {
            participantsInHistory[userIndex] = { ...participantsInHistory[userIndex], hasViewedPodium: true };
            history[week] = participantsInHistory;
            
            this.pool.update(pool => pool ? { ...pool, history } : null);
            await this.dataService.updatePoolHistory(p.id, { [week]: participantsInHistory });
          }
        }
      } catch (error) {
        console.error("Failed to update podium view status:", error);
      }
    }

    this.showPodiumView.set(false);
  }

  handleWeekChange(event: Event) {
    const newWeek = Number((event.target as HTMLSelectElement).value);
    this.router.navigate([], { 
      relativeTo: this.route, 
      queryParams: { week: newWeek },
      queryParamsHandling: 'merge'
    });
    this.showPodiumView.set(false);
  }

  goHome(): void {
    this.authService.clearLastVisitedPoolId();
    this.router.navigate(['/']);
  }

  private weekLockAt(games = this.gameService.games()): string {
    const startTimes = games
      .map(game => Date.parse(game.startTime))
      .filter(time => Number.isFinite(time));
    if (startTimes.length === 0) {
      throw new Error('The weekly schedule is unavailable, so the pick deadline could not be set.');
    }
    return new Date(Math.min(...startTimes)).toISOString();
  }

  private updateLocalScores(leaderboard: LeaderboardParticipant[]): void {
    const currentPool = this.pool();
    if (!currentPool) return;

    const updatedParticipants = currentPool.participants.map(p => {
        const leaderboardEntry = leaderboard.find(lp => lp.userId === p.userId);
        if (leaderboardEntry && p.score !== leaderboardEntry.score) {
            return { ...p, score: leaderboardEntry.score };
        }
        return p;
    });

    this.pool.set({ ...currentPool, participants: updatedParticipants });
  }
}
