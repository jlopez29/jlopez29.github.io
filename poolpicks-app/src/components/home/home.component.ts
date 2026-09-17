




import { Component, ChangeDetectionStrategy, inject, signal, computed, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PoolService } from '../../services/pool.service';
import { GameService } from '../../services/game.service';
import { AuthService } from '../../services/auth.service';
import { ActivatedRoute, Router } from '@angular/router';
import { DataService } from '../../services/data.service';
import { Pool } from '../../models/pool.model';
import { appSettings } from '../../app-settings';

interface JoinedPool {
  id: string;
  name: string;
}

@Component({
  selector: 'app-home',
  imports: [CommonModule, FormsModule],
  templateUrl: './home.component.html',
  // FIX: The import for ChangeDetectionStrategy had a typo ('ChangeChangeDetectionStrategy'). This has been corrected in the import statement.
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class HomeComponent {
  readonly settings = appSettings;
  // FIX: Explicitly type injected services to work around a type inference issue where they were being resolved as 'unknown'.
  private poolService: PoolService = inject(PoolService);
  gameService: GameService = inject(GameService);
  authService: AuthService = inject(AuthService);
  private router: Router = inject(Router);
  private route: ActivatedRoute = inject(ActivatedRoute);
  private dataService: DataService = inject(DataService);

  // Guest sign-in
  guestName = signal('');
  isSigningInAsGuest = signal(false);
  guestNameError = signal<string | null>(null);

  // Joining a pool
  joinIdentifier = signal('');
  inviteCode = signal('');
  joinError = signal<string | null>(null);
  joinIdentifierError = signal<string | null>(null);
  isFindingOrJoining = signal(false);

  // Creating a pool
  createPoolName = signal('');
  createPoolError = signal<string | null>(null);
  isCreating = signal(false);
  
  // General state
  joinedPools = signal<JoinedPool[]>([]);
  isInitializing = signal(true);
  isPrimaryPoolMember = computed(() =>
    this.joinedPools().some(pool => pool.id === this.settings.primaryPoolId)
  );

  canCreatePool = computed(() => {
    if (!this.settings.allowPoolCreation) {
      return false;
    }
    const games = this.gameService.games();

    // The view waits for `isCheckingOverride` to be false, which has a 1s delay,
    // so `gameService` should be done loading. This check handles edge cases.
    if (this.gameService.isLoading()) {
      return false;
    }

    // If there are no games for the current week (e.g., offseason), allow creation.
    if (games.length === 0) {
      return true;
    }
    
    const allGamesAreScheduled = games.every(g => g.status === 'scheduled');
    const allGamesAreFinal = games.every(g => g.status === 'final');
    
    return allGamesAreScheduled || allGamesAreFinal || this.gameService.createPoolOverride();
  });

  constructor() {
    const inviteFromLink = this.route.snapshot.queryParamMap.get('invite');
    if (inviteFromLink) this.inviteCode.set(inviteFromLink);

    // Effect to react to user logging in/out
    effect(() => {
      if (!this.authService.authReady()) {
        this.isInitializing.set(true);
        return;
      }
      const user = this.authService.currentUser();
      if (user) {
        // Defer initialization to the next macrotask to prevent a race condition
        // with Angular's View Transitions API on initial app load. This ensures
        // the home view is stable before any automatic navigation occurs.
        setTimeout(() => this.initializeApp());
      } else {
        // No user, so initialization is complete.
        this.isInitializing.set(false);
        // Reset state when user logs out
        this.joinedPools.set([]);
        this.joinError.set(null);
        this.joinIdentifierError.set(null);
        this.joinIdentifier.set('');
      }
    });
  }

  private async initializeApp() {
    this.isInitializing.set(true);

    // Perform initial redirect check only on first load.
    // The router.navigated property is false before the first navigation completes.
    const lastPoolId = this.authService.getLastVisitedPoolId();
    if (lastPoolId && !this.router.navigated) {
      const exists = await this.dataService.doesPoolExist(lastPoolId);
      if (exists) {
        this.router.navigate(['/pool', lastPoolId]);
        // We are navigating away, so keep the loader on and don't continue to load home page data.
        return;
      } else {
        // The stored pool ID is invalid, clear it.
        this.authService.clearLastVisitedPoolId();
      }
    }

    // If not redirecting, proceed to load the home page content.
    const pools = await this.authService.getJoinedPools();
    this.joinedPools.set(pools);
    this.isInitializing.set(false);
  }

  async handleGuestSignIn(): Promise<void> {
    this.guestNameError.set(null);
    if (!this.guestName().trim()) {
      this.guestNameError.set('Please enter a name.');
      return;
    }

    this.isSigningInAsGuest.set(true);
    try {
      await this.authService.signInAsGuest(this.guestName());
      // On success, the effect that watches currentUser will handle UI changes.
    } catch (error) {
      const errorMessage = (error as Error).message;
      this.guestNameError.set(errorMessage);
    } finally {
      this.isSigningInAsGuest.set(false);
    }
  }

  navigateToPool(poolId: string): void {
    this.authService.setLastVisitedPoolId(poolId);
    this.router.navigate(['/pool', poolId]);
  }

  async openPrimaryPool(): Promise<void> {
    if (this.isFindingOrJoining()) return;
    this.isFindingOrJoining.set(true);
    this.joinError.set(null);
    try {
      const poolId = this.settings.primaryPoolId;
      if (this.isPrimaryPoolMember()) {
        this.navigateToPool(poolId);
        return;
      }

      const inviteCode = this.inviteCode().trim();
      if (!inviteCode) throw new Error('Enter the AFCU invite code.');

      if (await this.dataService.doesPoolExist(poolId)) {
        await this.poolService.joinPool({ id: poolId, name: poolId }, inviteCode);
        return;
      }

      this.router.navigate(['/pool', 'new'], {
        state: { poolName: poolId, inviteCode },
      });
    } catch (error) {
      const code = (error as { code?: string }).code ?? '';
      this.joinError.set(
        code.includes('permission-denied')
          ? 'That invite code is not valid.'
          : ((error as Error).message || 'Could not open the AFCU pool.'),
      );
    } finally {
      this.isFindingOrJoining.set(false);
    }
  }

  async handleJoinAction() {
    if (this.isFindingOrJoining()) return;
    this.isFindingOrJoining.set(true);
    this.joinError.set(null);
    this.joinIdentifierError.set(null);
    
    try {
      const identifier = this.joinIdentifier().trim();
      if (!identifier) {
        throw new Error('Please enter a pool name.');
      }

      const pool = await this.findPoolByIdentifier(identifier);
      
      if (!pool) {
        throw new Error('Pool not found. Please check the name and try again.');
      }

      await this.poolService.joinPool(pool, this.inviteCode().trim());
      
    } catch (error) {
      const errorMessage = (error as Error).message;
      if (errorMessage.startsWith('Pool not found') || errorMessage === 'Please enter a pool name.') {
        this.joinIdentifierError.set(errorMessage);
      } else {
        this.joinError.set(errorMessage);
      }
    } finally {
      this.isFindingOrJoining.set(false);
    }
  }

  private async findPoolByIdentifier(identifier: string): Promise<Pool | null> {
    return this.dataService.getPool(identifier);
  }

  async handleCreatePool() {
    if (this.isCreating()) return;
    this.createPoolError.set(null);
    const poolName = this.createPoolName().trim();
    if (!poolName) {
      alert('Please enter a pool name.');
      return;
    }
    
    this.isCreating.set(true);
    
    const existingPool = await this.dataService.getPool(poolName);
    if (existingPool) {
        this.createPoolError.set('A pool with this name already exists.');
        this.isCreating.set(false);
        return;
    }

    const games = this.gameService.games();
    const isCurrentWeekConcluded = games.length > 0 && games.every(g => g.status === 'final');

    this.router.navigate(['/pool', 'new'], {
      state: {
        poolName: poolName,
        isNextWeek: isCurrentWeekConcluded
      }
    }).finally(() => {
      this.isCreating.set(false);
    });
  }
  
  async handleCreatePlayoffChallenge() {
    if (this.isCreating()) return;
    this.createPoolError.set(null);
    const poolName = this.createPoolName().trim();
    if (!poolName) {
      alert('Please enter a challenge name.');
      return;
    }
    
    this.isCreating.set(true);
    
    const existingPool = await this.dataService.getPool(poolName);
    if (existingPool) {
        this.createPoolError.set('A challenge with this name already exists.');
        this.isCreating.set(false);
        return;
    }

    this.router.navigate(['/pool', 'new'], {
      state: {
        poolName: poolName,
        isPlayoff: true
      }
    }).finally(() => {
      this.isCreating.set(false);
    });
  }


  async removePool(poolId: string, event: MouseEvent): Promise<void> {
    event.stopPropagation();
    if (confirm('Are you sure you want to remove this pool from your list?')) {
      await this.authService.removePoolFromJoinedList(poolId);
      this.joinedPools.update(pools => pools.filter(p => p.id !== poolId));
    }
  }
}
