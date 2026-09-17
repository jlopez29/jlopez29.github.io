
import { Component, ChangeDetectionStrategy, inject, effect, Pipe, PipeTransform } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AchievementService } from '../../services/achievement.service';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

@Pipe({
  name: 'safeHtml',
})
export class SafeHtmlPipe implements PipeTransform {
  // FIX: Explicitly type injected DomSanitizer to work around a type inference issue where it was being resolved as 'unknown'.
  private sanitizer: DomSanitizer = inject(DomSanitizer);
  transform(value: string): SafeHtml {
    return this.sanitizer.bypassSecurityTrustHtml(value);
  }
}

@Component({
  selector: 'app-achievement-toast',
  imports: [CommonModule, SafeHtmlPipe],
  templateUrl: './achievement-toast.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AchievementToastComponent {
  private achievementService = inject(AchievementService);
  achievements = this.achievementService.newlyUnlocked;

  constructor() {
    effect(() => {
      const newAchievements = this.achievements();
      if (newAchievements.length > 0) {
        newAchievements.forEach(achievement => {
          setTimeout(() => {
            this.dismissToast(achievement.id);
          }, 5000); // Auto-dismiss after 5 seconds
        });
      }
    });
  }

  dismissToast(id: string): void {
    this.achievementService.dismiss(id);
  }
}