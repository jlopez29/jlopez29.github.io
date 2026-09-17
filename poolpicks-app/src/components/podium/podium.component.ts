

import { Component, ChangeDetectionStrategy, input, output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LeaderboardParticipant } from '../leaderboard/leaderboard.component';

@Component({
  selector: 'app-podium',
  imports: [CommonModule],
  templateUrl: './podium.component.html',
  styles: [`
    .podium-item {
      animation: podium-rise 0.5s ease-out forwards;
      opacity: 0;
      transform: translateY(30px);
    }
    @keyframes podium-rise {
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PodiumComponent {
  topThree = input.required<LeaderboardParticipant[]>();
  poolName = input.required<string>();
  week = input.required<number>();
  isHistorical = input<boolean>(false);
  isLastGameOfWeek = input<boolean>(false);
  isPlayoffPool = input<boolean>(false);
  
  startNextWeek = output<void>();
  viewLeaderboard = output<void>();
}
