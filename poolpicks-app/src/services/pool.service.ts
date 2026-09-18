
import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { DataService } from './data.service';
import { AuthService } from './auth.service';
import { Pick, Participant } from '../models/pool.model';
import { Pool } from '../models/pool.model';
import { AchievementService } from './achievement.service';
import { PlayoffPicks } from '../models/playoff.model';

interface CreatePoolOptions {
  poolName: string;
  inviteCode: string;
  picks: Pick[];
  tiebreaker: number;
  week: number;
  year: number;
  isPlayoff: boolean;
  lockAt: string;
}

interface CreatePlayoffPoolOptions {
  poolName: string;
  inviteCode: string;
  playoffPicks: PlayoffPicks;
  tiebreaker: number;
  week: number;
  year: number;
  lockAt: string;
}

@Injectable({ providedIn: 'root' })
export class PoolService {
  private dataService: DataService = inject(DataService);
  private authService: AuthService = inject(AuthService);
  private achievementService: AchievementService = inject(AchievementService);
  private router: Router = inject(Router);

  async createPoolAndSubmitInitialPicks(options: CreatePoolOptions): Promise<string | null> {
    const currentUser = this.authService.currentUser();
    if (!currentUser) {
      alert('You must be signed in to create a pool.');
      this.router.navigate(['/']);
      return null;
    }
    if (!options.poolName.trim()) {
      alert('A pool name is required.');
      return null;
    }

    const initialParticipant: Participant = {
      userId: currentUser.uid,
      displayName: currentUser.displayName,
      photoUrl: currentUser.photoUrl,
      picks: options.picks,
      tiebreaker: options.tiebreaker,
      score: 0,
      hasViewedPodium: false
    };

    try {
      const trimmedPoolName = options.poolName.trim();
      const poolId = await this.dataService.createPool({
        name: trimmedPoolName, 
        inviteCode: options.inviteCode,
        participants: [initialParticipant], 
        week: options.week, 
        year: options.year,
        type: options.isPlayoff ? 'playoff' : 'regular',
        lockAt: options.lockAt,
      });
      await this.authService.addPoolToJoinedList({ id: poolId, name: trimmedPoolName });
      this.authService.setLastVisitedPoolId(poolId);

      // Award achievements
      this.achievementService.checkAndAwardArchitectAchievement(currentUser);
      this.achievementService.checkAndAwardFirstDownAchievement(currentUser);

      return poolId;
    } catch (error) {
      console.error('Failed to create pool with initial picks:', error);
      try {
        const existingPoolId = await this.joinExistingPoolAndSubmit(
          options.poolName.trim(),
          options.inviteCode,
          initialParticipant,
        );
        if (existingPoolId) return existingPoolId;
      } catch (joinError) {
        console.error('AFCU was created by someone else, but joining it failed:', joinError);
        alert('AFCU already exists, but your picks could not be saved. Check the invite code and make sure picks are still open.');
        return null;
      }
      alert('Could not create AFCU. Check the invite code and make sure picks are still open.');
      return null;
    }
  }
  
  async createPlayoffPoolAndSubmitInitialPicks(options: CreatePlayoffPoolOptions): Promise<string | null> {
    const currentUser = this.authService.currentUser();
    if (!currentUser) {
      alert('You must be signed in to create a pool.');
      this.router.navigate(['/']);
      return null;
    }

    const initialParticipant: Participant = {
      userId: currentUser.uid,
      displayName: currentUser.displayName,
      photoUrl: currentUser.photoUrl,
      playoffPicks: options.playoffPicks,
      tiebreaker: options.tiebreaker,
      score: 0,
      hasViewedPodium: false
    };

    try {
      const trimmedPoolName = options.poolName.trim();
      const poolId = await this.dataService.createPool({
        name: trimmedPoolName,
        inviteCode: options.inviteCode,
        participants: [initialParticipant],
        week: options.week,
        year: options.year,
        type: 'playoff',
        lockAt: options.lockAt,
      });
      await this.authService.addPoolToJoinedList({ id: poolId, name: trimmedPoolName });
      this.authService.setLastVisitedPoolId(poolId);
      this.achievementService.checkAndAwardArchitectAchievement(currentUser);
      this.achievementService.checkAndAwardFirstDownAchievement(currentUser);
      return poolId;
    } catch (error) {
      console.error('Failed to create playoff challenge:', error);
      try {
        const existingPoolId = await this.joinExistingPoolAndSubmit(
          options.poolName.trim(),
          options.inviteCode,
          initialParticipant,
        );
        if (existingPoolId) return existingPoolId;
      } catch (joinError) {
        console.error('The challenge was created by someone else, but joining it failed:', joinError);
        alert('The challenge already exists, but your picks could not be saved. Check the invite code and make sure picks are still open.');
        return null;
      }
      alert('Could not create the challenge. Check the invite code and make sure picks are still open.');
      return null;
    }
  }


  async joinPool(pool: { id: string; name: string }, inviteCode: string): Promise<void> {
    const currentUser = this.authService.currentUser();
    if (!currentUser) {
      throw new Error('You must be signed in to join a pool.');
    }
    
    await this.dataService.joinPool(pool.id, pool.name, currentUser, inviteCode);
    await this.authService.addPoolToJoinedList({ id: pool.id, name: pool.name });
    this.authService.setLastVisitedPoolId(pool.id);
    this.router.navigate(['/pool', pool.id]);
  }

  async submitPicks(poolId: string, picks: Pick[], tiebreaker: number): Promise<void> {
    const currentUser = this.authService.currentUser();
    if (!currentUser) {
      alert('You are not signed in.');
      this.router.navigate(['/']);
      return;
    }

    try {
      await this.dataService.addParticipant(poolId, {
        userId: currentUser.uid,
        displayName: currentUser.displayName,
        photoUrl: currentUser.photoUrl,
        picks,
        tiebreaker,
        score: 0,
        hasViewedPodium: false
      });
      // Award achievement for submitting picks
      this.achievementService.checkAndAwardFirstDownAchievement(currentUser);
    } catch (error) {
      console.error('Failed to submit picks:', error);
      alert('Could not submit your picks. Please try again.');
    }
  }

  async submitPlayoffPicks(poolId: string, playoffPicks: PlayoffPicks, tiebreaker: number): Promise<void> {
    const currentUser = this.authService.currentUser();
    if (!currentUser) {
      alert('You are not signed in.');
      this.router.navigate(['/']);
      return;
    }

    try {
      await this.dataService.addParticipant(poolId, {
        userId: currentUser.uid,
        displayName: currentUser.displayName,
        photoUrl: currentUser.photoUrl,
        playoffPicks,
        tiebreaker,
        score: 0,
        hasViewedPodium: false
      });
      this.achievementService.checkAndAwardFirstDownAchievement(currentUser);
    } catch (error) {
      console.error('Failed to submit playoff picks:', error);
      alert('Could not submit your picks. Please try again.');
    }
  }

  private async joinExistingPoolAndSubmit(
    poolId: string,
    inviteCode: string,
    participant: Participant,
  ): Promise<string | null> {
    const currentUser = this.authService.currentUser();
    if (!currentUser || !(await this.dataService.doesPoolExist(poolId))) return null;

    await this.dataService.joinPool(poolId, poolId, currentUser, inviteCode);
    await this.authService.addPoolToJoinedList({ id: poolId, name: poolId });
    this.authService.setLastVisitedPoolId(poolId);
    await this.dataService.addParticipant(poolId, participant);
    this.achievementService.checkAndAwardFirstDownAchievement(currentUser);
    return poolId;
  }
}
