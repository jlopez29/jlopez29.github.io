import { Component, ChangeDetectionStrategy, input, output, computed, signal, inject, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Pick } from '../../models/pool.model';
import { TeamService } from '../../services/team.service';
import { GameService } from '../../services/game.service';
import { Game } from '../../models/game.model';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-picks',
  imports: [CommonModule, FormsModule],
  templateUrl: './picks.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PicksComponent {
  picksSubmitted = output<{ picks: Pick[], tiebreaker: number }>();
  viewSchedule = output<void>();

  gameService = inject(GameService);
  teamService = inject(TeamService);
  authService = inject(AuthService);

  poolIdentifier = input.required<string>();
  week = input.required<number>();
  
  currentUser = this.authService.currentUser;
  picks = signal<Map<number, { winner: string, confidence: number | null }>>(new Map());
  tiebreaker = signal<number | null>(null);

  private storageKey = computed(() => `nfl-pool-picks-${this.poolIdentifier()}-${this.week()}`);
  private loadedFromStorage = signal(false);

  confidenceOptions = computed(() => {
    const numGames = this.gameService.games().length;
    return Array.from({ length: numGames }, (_, i) => i + 1);
  });

  usedConfidenceValues = computed(() => {
    const values = new Set<number>();
    for (const pick of this.picks().values()) {
      if (pick.confidence !== null) {
        values.add(pick.confidence);
      }
    }
    return values;
  });

  isFormValid = computed(() => {
    return this.picks().size === this.gameService.games().length &&
           this.usedConfidenceValues().size === this.gameService.games().length &&
           this.tiebreaker() !== null && this.tiebreaker()! >= 0 &&
           [...this.picks().values()].every(p => p.winner !== '');
  });

  tiebreakerGame = computed(() => {
    const games = this.gameService.games();
    if (games.length === 0) {
      return undefined;
    }
    // Prioritize the designated Monday Night game.
    const mnf = games.find(g => g.isMondayNight);
    if (mnf) {
      return mnf;
    }
    // Fallback to the last game of the week if no MNF game exists.
    return games[games.length - 1];
  });

  constructor() {
    effect(() => {
      const key = this.storageKey();
      if (!key) return;

      // Load once
      if (!this.loadedFromStorage()) {
        const savedPicksJson = localStorage.getItem(key);
        if (savedPicksJson) {
          try {
            const savedData = JSON.parse(savedPicksJson);
            if (savedData.picks) {
              const picksMap = new Map<number, { winner: string, confidence: number | null }>(
                Object.entries(savedData.picks).map(([k, v]) => [Number(k), v as any])
              );
              this.picks.set(picksMap);
            }
            if (savedData.tiebreaker !== undefined && savedData.tiebreaker !== null) {
              this.tiebreaker.set(savedData.tiebreaker);
            }
          } catch (e) {
            console.error('Error parsing saved picks from local storage', e);
            localStorage.removeItem(key);
          }
        }
        this.loadedFromStorage.set(true);
        // Do not save on the first run to avoid race condition of saving empty state before loading.
        return;
      }

      // Save on subsequent changes
      const dataToSave = {
        picks: Object.fromEntries(this.picks()),
        tiebreaker: this.tiebreaker()
      };
      
      // Don't save an empty object if user clears everything. Instead, remove item.
      if (this.picks().size === 0 && (this.tiebreaker() === null || this.tiebreaker() === undefined)) {
        localStorage.removeItem(key);
      } else {
        localStorage.setItem(key, JSON.stringify(dataToSave));
      }
    }, { allowSignalWrites: true });
  }

  onTeamSelect(gameId: number, team: string) {
    this.picks.update(p => {
      const pick = p.get(gameId) || { winner: '', confidence: null };
      pick.winner = team;
      p.set(gameId, pick);
      return new Map(p);
    });
  }

  onConfidenceSelect(gameId: number, confidence: number) {
    this.picks.update(p => {
      const pick = p.get(gameId) || { winner: '', confidence: null };
      
      // If the clicked confidence is the one already selected, deselect it.
      if (pick.confidence === confidence) {
        pick.confidence = null;
      } else {
        pick.confidence = confidence;
      }
      
      p.set(gameId, pick);
      return new Map(p);
    });
  }

  submitPicks() {
    if (!this.isFormValid()) return;
    
    const gamesById = new Map(this.gameService.games().map(g => [g.id, g]));
    const finalPicks: Pick[] = [];

    for (const [gameId, pick] of this.picks().entries()) {
      const game = gamesById.get(gameId);
      let isUnderdogPick = false;
      if (game) {
        const underdog = this.teamService.getUnderdog(game);
        isUnderdogPick = !!underdog && pick.winner === underdog;
      }
      
      finalPicks.push({
        gameId: gameId,
        winner: pick.winner,
        confidence: pick.confidence as number,
        isUnderdog: isUnderdogPick,
      });
    }

    this.picksSubmitted.emit({ picks: finalPicks, tiebreaker: this.tiebreaker() as number });

    // Clean up local storage after submission
    localStorage.removeItem(this.storageKey());
  }

  getGradient(awayTeamName: string, homeTeamName: string, winnerName?: string): string {
    const awayColor = this.teamService.getTeamByName(awayTeamName)?.primaryColor || '#374151';
    const homeColor = this.teamService.getTeamByName(homeTeamName)?.primaryColor || '#4B5563';

    if (winnerName === awayTeamName) {
      // Shift gradient to favor away team color
      return `linear-gradient(105deg, ${awayColor} 70%, ${homeColor} 100%)`;
    } else if (winnerName === homeTeamName) {
      // Shift gradient to favor home team color
      return `linear-gradient(105deg, ${awayColor} 0%, ${homeColor} 30%)`;
    }

    // Default, balanced gradient using team colors.
    return `linear-gradient(105deg, ${awayColor} 0%, ${homeColor} 100%)`;
  }

  getAnimatedBorder(teamName: string): string {
    const team = this.teamService.getTeamByName(teamName);
    if (!team) {
      return '';
    }
    const { primaryColor, secondaryColor } = team;
    // This creates 4 gradients for the 4 corners of the oversized rotating element.
    const grad1 = `linear-gradient(${primaryColor}, ${primaryColor})`;
    const grad2 = `linear-gradient(${secondaryColor}, ${secondaryColor})`;
    return `${grad1}, ${grad2}, ${grad1}, ${grad2}`;
  }
}