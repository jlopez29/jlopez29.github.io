import { inject, Injectable, Injector, signal } from '@angular/core';
import {
  browserLocalPersistence,
  onAuthStateChanged,
  setPersistence,
  signInAnonymously,
  signOut as firebaseSignOut,
} from 'firebase/auth';
import { AchievementType } from '../models/achievement.model';
import { AchievementService } from './achievement.service';
import { DataService } from './data.service';
import { firebaseAuth } from './firebase-client';

export interface UserStats {
  totalScore: number;
  averageScore: number;
  firstPlaceFinishes: number;
  secondPlaceFinishes: number;
  thirdPlaceFinishes: number;
  weeksPlayed: number;
}

export interface User {
  uid: string;
  displayName: string;
  email?: string;
  photoUrl: string;
  isGuest?: boolean;
  joinedPools?: { [poolId: string]: string };
  unlockedAchievements?: { [key in AchievementType]?: boolean };
  stats?: UserStats;
}

interface JoinedPool {
  id: string;
  name: string;
}

const LAST_VISITED_POOL_KEY = 'nfl-pool-last-visited-id';
const defaultStats: UserStats = {
  totalScore: 0,
  averageScore: 0,
  firstPlaceFinishes: 0,
  secondPlaceFinishes: 0,
  thirdPlaceFinishes: 0,
  weeksPlayed: 0,
};

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly dataService = inject(DataService);
  private readonly injector = inject(Injector);
  private _achievementService: AchievementService | undefined;
  private profileWrites: Promise<unknown> = Promise.resolve();

  currentUser = signal<User | null>(null);
  authReady = signal(false);

  static GUEST_AVATAR_COLORS = ['#f97316', '#ef4444', '#10b981', '#3b82f6', '#8b5cf6', '#ec4899', '#f59e0b', '#14b8a6'];

  private get achievementService(): AchievementService {
    this._achievementService ??= this.injector.get(AchievementService);
    return this._achievementService;
  }

  constructor() {
    void setPersistence(firebaseAuth, browserLocalPersistence).catch(error => {
      console.error('Could not enable persistent anonymous authentication.', error);
    });

    onAuthStateChanged(firebaseAuth, async firebaseUser => {
      try {
        if (!firebaseUser) {
          this.currentUser.set(null);
          return;
        }
        const storedUser = await this.dataService.getUser(firebaseUser.uid);
        this.currentUser.set(storedUser);
        if (storedUser) {
          setTimeout(() => this.achievementService.checkAndAwardWelcomeAchievement(storedUser), 0);
        }
      } catch (error) {
        console.error('Could not restore the PoolPicks profile.', error);
        this.currentUser.set(null);
      } finally {
        this.authReady.set(true);
      }
    });
  }

  static generateInitialAvatar(name: string): string {
    const initial = (name.trim().charAt(0).toUpperCase() || '?')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const color = AuthService.GUEST_AVATAR_COLORS[Math.floor(Math.random() * AuthService.GUEST_AVATAR_COLORS.length)];
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" data-is-default-avatar="true" viewBox="0 0 100 100"><rect width="100" height="100" fill="${color}" /><text x="50" y="55" font-family="sans-serif" font-size="50" fill="white" text-anchor="middle" dominant-baseline="middle" font-weight="bold">${initial}</text></svg>`;
    return `data:image/svg+xml,${encodeURIComponent(svg.replace(/\s+/g, ' '))}`;
  }

  /** Creates or resumes a silent Firebase anonymous identity, then saves its profile. */
  async signInAsGuest(name: string): Promise<void> {
    const displayName = name.trim();
    if (!displayName) throw new Error('Please enter a name.');
    if (displayName.length > 50) throw new Error('Please use a name of 50 characters or fewer.');

    const credential = firebaseAuth.currentUser
      ? { user: firebaseAuth.currentUser }
      : await signInAnonymously(firebaseAuth);
    const uid = credential.user.uid;
    const existingUser = await this.dataService.getUser(uid);
    const user: User = {
      ...(existingUser ?? {}),
      uid,
      displayName,
      photoUrl: existingUser?.photoUrl ?? AuthService.generateInitialAvatar(displayName),
      isGuest: true,
      joinedPools: existingUser?.joinedPools ?? {},
      unlockedAchievements: existingUser?.unlockedAchievements ?? {},
      stats: existingUser?.stats ?? defaultStats,
    };

    await this.dataService.updateUser(user);
    this.setUserWithTransition(user);
    this.achievementService.checkAndAwardWelcomeAchievement(user);
  }

  signOut(): void {
    void firebaseSignOut(firebaseAuth).then(() => {
      this.setUserWithTransition(null);
      this.clearLastVisitedPoolId();
    }).catch(error => console.error('Could not sign out. Please try again.', error));
  }

  async updateUserAvatar(newPhotoUrl: string): Promise<void> {
    const user = this.currentUser();
    if (!user) return;

    if (user.photoUrl === newPhotoUrl) return;
    const updatedUser = await this.changeProfile(user.uid, latest => ({ ...latest, photoUrl: newPhotoUrl }));
    if (!updatedUser) return;

    const poolIds = Object.keys(updatedUser.joinedPools ?? {});
    await Promise.all(poolIds.map(poolId =>
      this.dataService.updateParticipantPhotoUrl(poolId, user.uid, newPhotoUrl)
    ));
  }

  async getJoinedPools(): Promise<JoinedPool[]> {
    const user = this.currentUser();
    if (!user) return [];
    return Object.entries(user.joinedPools ?? {}).map(([id, name]) => ({ id, name }));
  }

  async addPoolToJoinedList(pool: JoinedPool): Promise<void> {
    const user = this.currentUser();
    if (!user) return;
    if (user.joinedPools?.[pool.id] === pool.name) return;
    await this.changeProfile(user.uid, latest => ({
      ...latest, joinedPools: { ...(latest.joinedPools ?? {}), [pool.id]: pool.name },
    }));
  }

  async removePoolFromJoinedList(poolId: string): Promise<void> {
    const user = this.currentUser();
    if (!user) return;

    if (await this.dataService.doesPoolExist(poolId)) {
      await this.dataService.removeParticipant(poolId, user.uid);
    }
    await this.changeProfile(user.uid, latest => {
      const joinedPools = { ...(latest.joinedPools ?? {}) };
      delete joinedPools[poolId];
      return { ...latest, joinedPools };
    });
  }

  async unlockAchievementForUser(user: User, type: AchievementType): Promise<{ updatedUser: User; newlyAwarded: boolean }> {
    const knownUser = this.currentUser()?.uid === user.uid ? this.currentUser()! : user;
    if (knownUser.unlockedAchievements?.[type]) {
      return { updatedUser: knownUser, newlyAwarded: false };
    }
    let newlyAwarded = false;
    const updatedUser = await this.changeProfile(user.uid, latest => {
      if (latest.unlockedAchievements?.[type]) return latest;
      newlyAwarded = true;
      return { ...latest, unlockedAchievements: { ...latest.unlockedAchievements, [type]: true } };
    });
    return { updatedUser: updatedUser ?? user, newlyAwarded };
  }

  updateUserStats(stats: UserStats): void {
    const user = this.currentUser();
    if (!user) return;
    if (JSON.stringify(user.stats) === JSON.stringify(stats)) return;
    void this.changeProfile(user.uid, latest => ({ ...latest, stats }))
      .catch(error => console.error('Could not update stats.', error));
  }

  getLastVisitedPoolId(): string | null {
    return localStorage.getItem(LAST_VISITED_POOL_KEY);
  }

  setLastVisitedPoolId(poolId: string): void {
    localStorage.setItem(LAST_VISITED_POOL_KEY, poolId);
  }

  clearLastVisitedPoolId(): void {
    localStorage.removeItem(LAST_VISITED_POOL_KEY);
  }

  private async refreshUserFromStore(uid: string): Promise<void> {
    const storedUser = await this.dataService.getUser(uid);
    if (storedUser && this.currentUser()?.uid === uid) this.updateUserState(storedUser);
  }

  private updateUserState(user: User | null): void {
    this.currentUser.set(user);
  }

  private setUserWithTransition(user: User | null): void {
    this.updateUserState(user);
  }

  /** Serialize profile edits so simultaneous awards/joins do not overwrite each other. */
  private changeProfile(uid: string, change: (user: User) => User): Promise<User | null> {
    const operation = this.profileWrites.then(async () => {
      if (this.currentUser()?.uid !== uid) return null;
      const latest = await this.dataService.getUser(uid);
      if (!latest) return null;
      const updated = change(latest);
      if (updated !== latest) await this.dataService.updateUser(updated);
      if (this.currentUser()?.uid === uid) this.updateUserState(updated);
      return updated;
    });
    this.profileWrites = operation.catch(() => undefined);
    return operation;
  }
}
