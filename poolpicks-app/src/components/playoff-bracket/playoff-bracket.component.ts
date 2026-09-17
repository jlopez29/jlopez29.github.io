
import { Component, ChangeDetectionStrategy, output, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { GameService } from '../../services/game.service';
import { TeamService } from '../../services/team.service';
import { PlayoffPicks } from '../../models/playoff.model';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-playoff-bracket',
  imports: [CommonModule, FormsModule],
  templateUrl: './playoff-bracket.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PlayoffBracketComponent {
  playoffPicksSubmitted = output<{ playoffPicks: PlayoffPicks, tiebreaker: number }>();
  
  gameService = inject(GameService);
  teamService = inject(TeamService);

  confidencePicks = signal<{ [teamName: string]: number | null }>({});
  tiebreaker = signal<number | null>(null);
  
  afcTeams = computed(() => this.gameService.playoffTeams()?.afc.sort((a,b) => a.seed - b.seed) ?? []);
  nfcTeams = computed(() => this.gameService.playoffTeams()?.nfc.sort((a,b) => a.seed - b.seed) ?? []);
  allPlayoffTeams = computed(() => [...this.afcTeams(), ...this.nfcTeams()]);

  confidenceOptions = computed(() => {
    const numTeams = this.allPlayoffTeams().length;
    if (numTeams === 0) return [];
    return Array.from({ length: numTeams }, (_, i) => numTeams - i);
  });
  
  usedConfidenceValues = computed(() => {
    const values = new Set<number>();
    for (const confidence of Object.values(this.confidencePicks())) {
      if (confidence !== null) {
        // FIX: Cast `confidence` to `number` to resolve a type error where it was being inferred as 'unknown'.
        values.add(confidence as number);
      }
    }
    return values;
  });

  isFormValid = computed(() => {
    return Object.keys(this.confidencePicks()).length === this.allPlayoffTeams().length &&
           this.usedConfidenceValues().size === this.allPlayoffTeams().length &&
           this.tiebreaker() !== null && this.tiebreaker()! >= 0 &&
           Object.values(this.confidencePicks()).every(c => c !== null);
  });

  constructor() {
    if (!this.gameService.playoffTeams()) {
      this.gameService.loadPlayoffPicture();
    }
  }

  onConfidenceButtonClick(teamName: string, confidence: number) {
    this.confidencePicks.update(picks => {
      const currentPick = picks[teamName];
      
      // If the clicked confidence is the one already selected, deselect it.
      if (currentPick === confidence) {
        picks[teamName] = null;
      } else {
        picks[teamName] = confidence;
      }
      
      return {...picks};
    });
  }

  submitPicks() {
    if (!this.isFormValid()) return;

    const finalPicks: PlayoffPicks = {
      confidencePicks: this.confidencePicks() as { [teamName: string]: number }
    };
    
    this.playoffPicksSubmitted.emit({
      playoffPicks: finalPicks,
      tiebreaker: this.tiebreaker() as number
    });
  }
}
