import { Component, ChangeDetectionStrategy, inject, signal, computed, effect, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService, User, UserStats } from '../../services/auth.service';
import { DataService } from '../../services/data.service';
import { Trophy, Achievement } from '../../models/achievement.model';
import { Pool, Participant } from '../../models/pool.model';
import { AchievementService } from '../../services/achievement.service';
import { SafeHtmlPipe } from '../achievement-toast/achievement-toast.component';
import { PoolHistoryService } from '../../services/pool-history.service';

@Component({
  selector: 'app-trophy-case',
  imports: [CommonModule, RouterLink, SafeHtmlPipe],
  templateUrl: './trophy-case.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TrophyCaseComponent {
  private authService = inject(AuthService);
  private dataService = inject(DataService);
  private achievementService = inject(AchievementService);
  private readonly poolHistory = inject(PoolHistoryService);
  private readonly userId = computed(() => this.currentUser()?.uid);
  loadError = signal<string | null>(null);

  isLoading = signal(true);
  currentUser = this.authService.currentUser;
  
  allTrophies = signal<Trophy[]>([]);
  unlockedBadges = signal<Achievement[]>([]);
  lockedAchievements = signal<Omit<Achievement, 'id'>[]>([]);

  constructor() {
    effect(() => {
      if (this.authService.authReady()) {
        this.userId();
        untracked(() => void this.loadTrophyCase());
      }
    });
  }

  async loadTrophyCase(): Promise<void> {
    this.isLoading.set(true);
    this.loadError.set(null);
    try {
    const user = this.currentUser();
    if (!user) {
      this.isLoading.set(false);
      return;
    }
    
    // First, get all pools the user is currently a member of.
    const poolSummaries = await this.authService.getJoinedPools();
    const poolDetails = await Promise.all(
      poolSummaries.map(p => this.dataService.getPool(p.id))
    );
    const validPools = await Promise.all(poolDetails.filter((p): p is Pool => p !== null).map(p => this.poolHistory.withScores(p)));

    // --- Retroactive Achievement Check ---
    // Scan all historical weeks for the user and silently award any achievements that were missed
    // before the persistence logic was added. This ensures user data is always accurate.
    console.log(`Performing retroactive achievement scan for ${user.displayName}...`);
    for (const pool of validPools) {
      if (pool.history) {
        for (const weekStr in pool.history) {
          const week = Number(weekStr);
          // The active week's achievements are handled by the PoolComponent, so we only process historical weeks here.
          if (week !== pool.week) {
            await this.achievementService.processAndNotifyForConcludedWeek(pool, week, user, { silent: true });
          }
        }
      }
    }
    
    // After the scan, refresh the user from the configured store.
    const freshUser = this.currentUser();
    const userForStats = freshUser ?? user;

    // --- Recalculate and Save All-Time Stats & Trophies ---
    // This function now runs against the complete and corrected user history.
    const { stats, trophies } = this.calculateOverallStatsForUser(userForStats, validPools);

    // Save the recalculated stats through the data boundary for consistency.
    this.authService.updateUserStats(stats);
    
    this.allTrophies.set(trophies);

    // --- Calculate Unlocked vs. Locked Badges for Display ---
    const allDefinitions = this.achievementService.getAchievementDefinitions();
    const unlocked = this.achievementService.getUnlockedBadges(userForStats);
    const unlockedTypes = new Set(unlocked.map(a => a.type));

    this.unlockedBadges.set(unlocked);
    this.lockedAchievements.set(allDefinitions.filter(def => !unlockedTypes.has(def.type)));

    } catch (error) {
      console.error('Could not load trophy case.', error);
      this.loadError.set('Could not load your trophies. Check your connection and try again.');
    } finally {
      this.isLoading.set(false);
    }
  }

  private calculateOverallStatsForUser(user: User, pools: Pool[]): { stats: UserStats, trophies: Trophy[] } {
    const stats: UserStats = {
      totalScore: 0,
      averageScore: 0,
      firstPlaceFinishes: 0,
      secondPlaceFinishes: 0,
      thirdPlaceFinishes: 0,
      weeksPlayed: 0,
    };
    const trophies: Trophy[] = [];
    const weeksPlayedSet = new Set<string>(); // Use "poolId_week" to avoid double counting

    for (const pool of pools) {
      // Combine history with the current participant list to include the most recent week
      const allWeeksData: { [week: string]: Participant[] } = { ...(pool.history ?? {}) };
      if (pool.participants && pool.participants.length > 0) {
        allWeeksData[pool.week] = pool.participants;
      }

      for (const weekStr in allWeeksData) {
        const week = Number(weekStr);
        const participants = allWeeksData[weekStr];
        if (!participants || participants.length === 0) continue;
        
        // Display names are not unique; identities and rankings must use the UID.
        const userAsParticipant = participants.find(p => p.userId === user.uid);
        const weekKey = `${pool.id}_${week}`;

        if (userAsParticipant && !weeksPlayedSet.has(weekKey)) {
            weeksPlayedSet.add(weekKey);
            stats.totalScore += userAsParticipant.score;
            
            const sorted = [...participants].sort((a, b) => b.score - a.score);
            // Ensure winner has a score > 0 to count as a competitive week
            if (pool.concludedWeeks?.includes(week) && sorted.length > 0 && sorted[0].score > 0) {
              const userRank = sorted.findIndex(p => p.userId === user.uid);
              if (userRank !== -1 && userRank < 3) {
                const rank = (userRank + 1) as 1 | 2 | 3;
                if (rank === 1) stats.firstPlaceFinishes++;
                if (rank === 2) stats.secondPlaceFinishes++;
                if (rank === 3) stats.thirdPlaceFinishes++;
                
                trophies.push({
                  poolId: pool.id,
                  poolName: pool.name,
                  week,
                  year: pool.year,
                  rank: rank,
                });
              }
            }
        }
      }
    }
    
    stats.weeksPlayed = weeksPlayedSet.size;
    stats.averageScore = stats.weeksPlayed > 0 ? stats.totalScore / stats.weeksPlayed : 0;
    
    // Sort trophies for display
    trophies.sort((a, b) => {
        if (b.year !== a.year) return b.year - a.year;
        return b.week - a.week;
    });

    return { stats, trophies };
  }
}
