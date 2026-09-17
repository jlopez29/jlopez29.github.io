
import { Component, ChangeDetectionStrategy, inject, signal, computed, effect, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { GameService } from '../../services/game.service';
import { DataService } from '../../services/data.service';
import { TeamService } from '../../services/team.service';
import { Pool, Participant, Pick } from '../../models/pool.model';
import { Game } from '../../models/game.model';
import { AuthService } from '../../services/auth.service';
import { PoolStateService } from '../../services/pool-state.service';

interface PickWithGame extends Pick {
  game: Game;
  isCorrect: boolean | null; // null if game not final, true if correct, false if incorrect
}

// New interface for the detailed playoff picks view
interface PlayoffPickWithGame {
  game: Game;
  pickedWinner: string;
  homeConfidence: number;
  awayConfidence: number;
  pickWasCorrect: boolean | null;
  pointsAwarded: number;
}


@Component({
  selector: 'app-participant-picks',
  imports: [CommonModule, RouterLink],
  templateUrl: './participant-picks.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ParticipantPicksComponent implements OnDestroy {
  // FIX: Explicitly type injected services to work around a type inference issue where they were being resolved as 'unknown'.
  private route: ActivatedRoute = inject(ActivatedRoute);
  private dataService: DataService = inject(DataService);
  private authService: AuthService = inject(AuthService);
  private router: Router = inject(Router);
  private poolStateService: PoolStateService = inject(PoolStateService);
  gameService: GameService = inject(GameService);
  teamService: TeamService = inject(TeamService);

  poolId = signal<string | null>(null);
  participantName = signal<string | null>(null);
  viewedWeek = signal<number | null>(null);

  pool = signal<Pool | null | undefined>(undefined);

  isPlayoffPool = computed(() => this.pool()?.type === 'playoff');

  participant = computed(() => {
    const p = this.pool();
    const name = this.participantName();
    if (!p || !name) return null;

    const week = this.viewedWeek();
    if (week === null) return null;

    // Check current participants first, then history.
    if (p.week === week) {
      return p.participants.find(part => part.displayName === name) || null;
    }
    return p.history?.[week]?.find(part => part.displayName === name) || null;
  });

  picksWithGameDetails = computed<PickWithGame[]>(() => {
    const p = this.participant();
    const allGames = this.gameService.games();
    if (!p || !p.picks || !allGames.length) return [];

    const picks = p.picks.map(pick => {
      const game = allGames.find(g => g.id === pick.gameId);
      if (!game) return null;

      let isCorrect: boolean | null = null;
      if (game.status === 'final' && game.winner) {
        isCorrect = game.winner === pick.winner;
      }

      return { ...pick, game, isCorrect };
    });

    // FIX: Explicitly cast confidence values to `Number` to resolve a type error in the sort comparison.
    return (picks.filter(p => p !== null) as PickWithGame[]).sort((a, b) => Number(b.confidence) - Number(a.confidence));
  });
  
  playoffPicksWithGameDetails = computed<PlayoffPickWithGame[]>(() => {
    const participant = this.participant();
    const allGames = this.gameService.games();
    if (!participant?.playoffPicks?.confidencePicks || !allGames.length) return [];

    const confidencePicks = participant.playoffPicks.confidencePicks;

    const picks = allGames.map(game => {
      const homeConfidence = confidencePicks[game.homeTeam] ?? 0;
      const awayConfidence = confidencePicks[game.awayTeam] ?? 0;

      // Skip rendering a card if the participant had no confidence in either team.
      if (homeConfidence === 0 && awayConfidence === 0) return null;
      
      const pickedWinner = homeConfidence > awayConfidence ? game.homeTeam : game.awayTeam;

      let pickWasCorrect: boolean | null = null;
      let pointsAwarded = 0;
      
      if (game.status === 'final' && game.winner) {
        pickWasCorrect = pickedWinner === game.winner;
        pointsAwarded = confidencePicks[game.winner] ?? 0;
      }

      return {
        game,
        pickedWinner,
        homeConfidence,
        awayConfidence,
        pickWasCorrect,
        pointsAwarded
      };
    });

    return (picks.filter(p => p !== null) as PlayoffPickWithGame[]).sort((a, b) => {
      const maxConfA = Math.max(a.homeConfidence, a.awayConfidence);
      const maxConfB = Math.max(b.homeConfidence, b.awayConfidence);
      return maxConfB - maxConfA;
    });
  });

  constructor() {
    if (!this.authService.currentUser()) {
      this.router.navigate(['/']);
      return;
    }

    // Subscribe to query params to get the week, which determines which games to load.
    this.route.queryParamMap.subscribe(params => {
      const weekStr = params.get('week');
      if (weekStr) {
        const week = Number(weekStr);
        this.viewedWeek.set(week);
        // FIX: Check against the week of the currently loaded games, not the overall current week of the season.
        if (this.gameService.gamesWeek() !== week) {
          this.gameService.loadSpecificWeek(week);
        }
      }
    });
    
    const id = this.route.snapshot.paramMap.get('id');
    const name = this.route.snapshot.paramMap.get('name');
    
    if (id && name) {
      this.poolId.set(id);
      this.participantName.set(name);
      this.poolStateService.setCurrentPoolId(id);
      this.loadPoolData(id);
    } else {
      this.pool.set(null);
    }

    effect(() => {
      if (!this.authService.currentUser()) {
        this.router.navigate(['/']);
      }
    });

    effect(() => {
      if (this.poolStateService.refreshRequested() > 0) {
        const id = this.poolId();
        if (id) {
          this.loadPoolData(id);
        }
      }
    });
  }

  ngOnDestroy(): void {
    this.poolStateService.setCurrentPoolId(null);
  }

  async loadPoolData(poolId: string) {
    this.pool.set(undefined); // loading
  
    let poolData: Pool | null = null;
    try {
      const user = this.authService.currentUser();
      // Only sync guest avatar to DB if it's a custom one, not a default.
      if (user?.isGuest && user.photoUrl && !user.photoUrl.includes('data-is-default-avatar')) {
        await this.dataService.updateParticipantPhotoUrl(poolId, user.uid, user.photoUrl);
      }
  
      // Add a minimum delay to appreciate the shimmer effect
      const delayPromise = new Promise(resolve => setTimeout(resolve, 1000));
      const poolPromise = this.dataService.getPool(poolId);
      const [_, fetchedPoolData] = await Promise.all([delayPromise, poolPromise]);
      poolData = fetchedPoolData;
    } catch (error) {
      console.error('Failed to load participant picks data:', error);
      // poolData will remain null, signaling an error state to the UI.
    }
  
    const updateState = () => {
      this.pool.set(poolData);
    };
  
    // Use View Transitions API for a smooth cross-fade from skeleton to content.
    if ((document as any).startViewTransition) {
      (document as any).startViewTransition(updateState);
    } else {
      updateState();
    }
  }

  getSpreadForTeam(game: Game, teamName: string): string | null {
    if (!game.line || game.line.toUpperCase() === 'EVEN') return null;
  
    const parts = game.line.split(' ');
    if (parts.length < 2) return null;
    const abbr = parts[0];
    const spreadValue = parseFloat(parts[1]);

    if (isNaN(spreadValue)) return null;

    const teamFromLine = this.teamService.getTeamByAbbr(abbr);
    if (!teamFromLine) return null;

    if (teamFromLine.name === teamName) {
      return spreadValue > 0 ? `+${spreadValue}` : `${spreadValue}`;
    } else {
      const oppositeSpread = -spreadValue;
      return oppositeSpread > 0 ? `+${oppositeSpread}` : `${oppositeSpread}`;
    }
  }
}
