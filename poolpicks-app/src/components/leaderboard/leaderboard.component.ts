

import { Component, ChangeDetectionStrategy, input, output, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { Participant } from '../../models/pool.model';
import { AuthService } from '../../services/auth.service';
import { GameService } from '../../services/game.service';

export interface LeaderboardParticipant extends Participant {
  currentPotential: number;
  totalPotential: number;
  tiebreakerDiff?: number;
}

@Component({
  selector: 'app-leaderboard',
  imports: [CommonModule],
  templateUrl: './leaderboard.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LeaderboardComponent {
  leaderboard = input.required<LeaderboardParticipant[]>();
  weekConcluded = input<boolean>(false);
  weekInProgress = input<boolean>(false);
  poolId = input.required<string>();
  gamesInfo = input<{ completed: number, total: number }>();
  viewedWeek = input.required<number>();
  isHistorical = input<boolean>(false);

  viewSchedule = output<void>();
  viewPodium = output<void>();

  // FIX: Explicitly type injected Router to work around a type inference issue where it was being resolved as 'unknown'.
  private router: Router = inject(Router);
  private authService: AuthService = inject(AuthService);
  gameService = inject(GameService);

  currentUser = this.authService.currentUser;

  viewPicks(participant: Participant): void {
    this.router.navigate(['/pool', this.poolId(), 'picks', participant.displayName], {
      queryParams: { week: this.viewedWeek(), uid: participant.userId }
    });
  }
}
