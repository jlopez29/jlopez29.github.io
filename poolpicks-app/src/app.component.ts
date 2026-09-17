




import { Component, ChangeDetectionStrategy, inject, signal } from '@angular/core';
import { RouterOutlet, RouterLink, Router, NavigationEnd } from '@angular/router';
import { GameService } from './services/game.service';
import { AuthService } from './services/auth.service';
import { AvatarPickerComponent } from './components/avatar-picker/avatar-picker.component';
import { PoolStateService } from './services/pool-state.service';
import { LOGO_URL } from './assets/logo';
import { AchievementToastComponent } from './components/achievement-toast/achievement-toast.component';
import { filter } from 'rxjs/operators';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styles: [`
    :host {
      display: block;
      height: 100%;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [
    RouterOutlet,
    RouterLink,
    AvatarPickerComponent,
    AchievementToastComponent
  ],
})
export class AppComponent {
  logoUrl = LOGO_URL;
  gameService = inject(GameService);
  authService = inject(AuthService);
  private poolStateService = inject(PoolStateService);
  // FIX: Explicitly type injected Router to work around a type inference issue where it was being resolved as 'unknown'.
  private router: Router = inject(Router);
  
  isAvatarPickerOpen = signal(false);
  isOnHomePage = signal(this.router.url === '/');

  constructor() {
    this.router.events.pipe(
      filter((e): e is NavigationEnd => e instanceof NavigationEnd)
    ).subscribe((e: NavigationEnd) => {
      this.isOnHomePage.set(e.urlAfterRedirects === '/');
    });
  }

  handleAvatarClick(): void {
    const user = this.authService.currentUser();
    if (user?.isGuest) {
      this.isAvatarPickerOpen.set(true);
    }
  }

  resetBrowserIdentity(): void {
    const confirmed = window.confirm(
      'Reset this browser identity? Your existing picks will stay in the pool, but this browser will no longer be able to edit them.',
    );
    if (confirmed) this.authService.signOut();
  }

  async handleAvatarSelected(newAvatarUrl: string): Promise<void> {
    this.isAvatarPickerOpen.set(false);
    try {
        // This now updates the user doc and all participant records globally,
        // without causing a disruptive view transition.
        await this.authService.updateUserAvatar(newAvatarUrl);

        // Only refresh the component data if the user is currently viewing a pool,
        // but NOT the pool creation page.
        const poolId = this.poolStateService.currentPoolId();
        if (poolId && poolId !== 'new') {
            this.poolStateService.triggerRefresh();
        }
    } catch (err) {
        console.error('Failed to update user avatar:', err);
        // Optionally, inform the user that the change could not be saved.
    }
  }
}
