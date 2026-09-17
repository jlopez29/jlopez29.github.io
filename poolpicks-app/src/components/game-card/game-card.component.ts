

import { Component, ChangeDetectionStrategy, input, inject, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Game } from '../../models/game.model';
import { TeamService } from '../../services/team.service';

@Component({
  selector: 'app-game-card',
  imports: [CommonModule],
  templateUrl: './game-card.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class GameCardComponent {
  game = input.required<Game>();
  teamService = inject(TeamService);

  isUnderdogWin = computed(() => {
    const game = this.game();
    if (game.status !== 'final' || !game.winner) return false;
    const underdog = this.teamService.getUnderdog(game);
    return game.winner === underdog;
  });
}
