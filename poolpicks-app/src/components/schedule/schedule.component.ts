
import { Component, ChangeDetectionStrategy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { GameCardComponent } from '../game-card/game-card.component';
import { GameService } from '../../services/game.service';

@Component({
  selector: 'app-schedule',
  imports: [CommonModule, GameCardComponent],
  templateUrl: './schedule.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ScheduleComponent {
  gameService = inject(GameService);
}
