
import { Component, ChangeDetectionStrategy, inject, signal, computed, effect, OnDestroy, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
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
  private readonly params = toSignal(this.route.paramMap);
  private readonly query = toSignal(this.route.queryParamMap);
  private readonly userId = computed(() => this.authService.currentUser()?.uid);
  private loadVersion = 0;
  private destroyed = false;

  isPlayoffPool = computed(() => this.pool()?.type === 'playoff');

  participant = computed(() => {
    const p = this.pool();
    const name = this.participantName();
    if (!p || !name) return null;

    const week = this.viewedWeek();
    if (week === null) return null;
    const uid = this.query()?.get('uid');
    const matches = (part: Participant) => uid ? part.userId === uid : part.displayName === name;

    // Check current participants first, then history.
    if (p.week === week) {
      return p.participants.find(matches) || null;
    }
    return p.history?.[week]?.find(matches) || null;
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
  
    let poolData: Pool | null = null;
    try {
      const week = this.viewedWeek();
      poolData = await this.dataService.getPool(poolId, { historyWeeks: week ? [week] : [] });
    } catch (error) {
      console.error('Failed to load participant picks data:', error);
      // poolData will remain null, signaling an error state to the UI.
    }
  
    if (!this.destroyed && version === this.loadVersion) {
      if (!this.viewedWeek() && poolData) this.viewedWeek.set(poolData.week);
      this.pool.set(poolData);
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
