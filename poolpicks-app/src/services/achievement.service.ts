

import { Injectable, signal, inject } from '@angular/core';
import { Achievement, Trophy, AchievementType } from '../models/achievement.model';
import { Pool, Participant } from '../models/pool.model';
import { AuthService, User } from './auth.service';
import { GameService } from './game.service';
import { TeamService } from './team.service';
import { Game } from '../models/game.model';

@Injectable({ providedIn: 'root' })
export class AchievementService {
  private gameService = inject(GameService);
  private teamService = inject(TeamService);
  private authService = inject(AuthService);
  
  newlyUnlocked = signal<Achievement[]>([]);

  private achievementDefinitions: Omit<Achievement, 'id'>[] = [
    { type: 'WELCOME_ABOARD', name: 'Welcome Aboard!', description: 'Sign in for the first time.', iconSvg: this.getAchievementIcon('WELCOME_ABOARD') },
    { type: 'THE_ARCHITECT', name: 'The Architect', description: 'Create your first pool.', iconSvg: this.getAchievementIcon('THE_ARCHITECT') },
    { type: 'FIRST_DOWN', name: 'First Down', description: 'Submit your picks for the first time.', iconSvg: this.getAchievementIcon('FIRST_DOWN') },
    { type: 'FIRST_VICTORY', name: 'The Champion', description: 'Win a weekly pool for the first time.', iconSvg: this.getAchievementIcon('FIRST_VICTORY') },
    { type: 'BACK_TO_BACK', name: 'Back 2 Back', description: 'Win 2 weekly pools in a row.', iconSvg: this.getAchievementIcon('BACK_TO_BACK') },
    { type: 'THREE_PEAT', name: '3-Peat', description: 'Win 3 weekly pools in a row.', iconSvg: this.getAchievementIcon('THREE_PEAT') },
    { type: 'QUAD_CRUSHER', name: 'Quad Crusher', description: 'Win 4 weekly pools in a row.', iconSvg: this.getAchievementIcon('QUAD_CRUSHER') },
    { type: 'OCHO_CINCO', name: 'Ocho Cinco', description: 'Win 5 or more weekly pools in a row.', iconSvg: this.getAchievementIcon('OCHO_CINCO') },
    { type: 'UPSET_KING', name: 'Upset King', description: 'Have the most correct underdog picks in a week.', iconSvg: this.getAchievementIcon('UPSET_KING') },
    { type: 'PERFECT_WEEK', name: 'Perfect Week', description: 'Correctly pick every winner in a single week.', iconSvg: this.getAchievementIcon('PERFECT_WEEK') },
  ];

  getAchievementDefinitions(): Omit<Achievement, 'id'>[] {
    return this.achievementDefinitions;
  }
  
  private async triggerAchievement(user: User, type: AchievementType, options?: { silent?: boolean, details?: Partial<Achievement> }): Promise<void> {
    const definition = this.achievementDefinitions.find(def => def.type === type);
    if (!definition) {
        return;
    }

    const { newlyAwarded } = await this.authService.unlockAchievementForUser(user, type);

    if (newlyAwarded && !options?.silent) {
        const newAchievement: Achievement = {
            ...definition,
            ...(options?.details ?? {}),
            id: `${type}_${Date.now()}` // Unique ID for the toast
        };
        this.newlyUnlocked.update(current => [...current, newAchievement]);
    }
  }

  checkAndAwardWelcomeAchievement(user: User): void {
      this.triggerAchievement(user, 'WELCOME_ABOARD');
  }

  checkAndAwardArchitectAchievement(user: User): void {
      this.triggerAchievement(user, 'THE_ARCHITECT');
  }

  checkAndAwardFirstDownAchievement(user: User): void {
      this.triggerAchievement(user, 'FIRST_DOWN');
  }
  
  getUnlockedBadges(user: User | null): Achievement[] {
    if (!user) return [];

    // Prioritize the live signal state, but fall back to the passed user object.
    const currentUserState = this.authService.currentUser();
    const unlocked = (currentUserState?.uid === user.uid)
        ? currentUserState.unlockedAchievements
        : user.unlockedAchievements;
        
    const badges: Achievement[] = [];
    
    for (const def of this.achievementDefinitions) {
      if (unlocked?.[def.type]) {
        badges.push({ ...def, id: def.type });
      }
    }
    return badges;
  }

  // Method to be called from PoolComponent when a week concludes
  async processAndNotifyForConcludedWeek(pool: Pool, week: number, user: User, options: { silent?: boolean } = {}): Promise<void> {
    // The new source of truth for "processed" is whether the user has the badge unlocked.
    // This removes the need for a separate "processed weeks" tracker in local storage.
    const newAchievementsForToast: Achievement[] = [];
    const participants = pool.history?.[week] ?? pool.participants;
    
    const sortedParticipants = [...participants].sort((a, b) => b.score - a.score);

    const winner = sortedParticipants.length > 0 ? sortedParticipants[0] : null;
    if (winner && winner.score > 0) {
      const userRank = sortedParticipants.findIndex(p => p.userId === user.uid);

      if (userRank !== -1 && userRank < 3) {
        const rank = (userRank + 1) as (1 | 2 | 3);
        
        if (!options.silent) {
          const trophyName = rank === 1 ? 'Gold Trophy' : rank === 2 ? 'Silver Trophy' : 'Bronze Trophy';
          newAchievementsForToast.push({
            id: `trophy_${rank}_${pool.id}_${week}_${pool.year}`,
            type: rank === 1 ? 'FIRST_VICTORY' : 'PERFECT_WEEK',
            name: trophyName,
            description: `Finished ${rank === 1 ? '1st' : rank === 2 ? '2nd' : '3rd'} in ${pool.name} for Week ${week}!`,
            iconSvg: this.getTrophyIcon(rank),
            poolName: pool.name,
            week,
            year: pool.year,
          });
        }

        if (rank === 1) {
          await this.triggerAchievement(user, 'FIRST_VICTORY', options);
        }
      }
    }

    const weeklyGames = await this.fetchGamesForWeek(week, pool.year);
    if (weeklyGames.length > 0) {
      const userParticipant = participants.find(p => p.userId === user.uid);
      if (userParticipant) {
          if (this.isPerfectWeek(userParticipant, weeklyGames)) {
              await this.triggerAchievement(user, 'PERFECT_WEEK', options);
          }
          if (this.isUpsetKing(userParticipant, participants, weeklyGames)) {
              await this.triggerAchievement(user, 'UPSET_KING', options);
          }
      }
    }
    
    const streakAchievement = this.checkWinningStreaks(pool, week, user);
    if (streakAchievement) {
      await this.triggerAchievement(user, streakAchievement.type, options);
    }

    if (newAchievementsForToast.length > 0) {
      this.newlyUnlocked.set(newAchievementsForToast);
    }
  }

  dismiss(achievementId: string): void {
    this.newlyUnlocked.update(achievements =>
      achievements.filter(a => a.id !== achievementId)
    );
  }

  private didUserWinWeek(userId: string, participants: Participant[]): boolean {
    if (!participants || participants.length === 0) return false;
    const maxScore = Math.max(...participants.map(p => p.score));
    if (maxScore === 0) return false;
    const userParticipant = participants.find(p => p.userId === userId);
    return !!userParticipant && userParticipant.score === maxScore;
  }

  private checkWinningStreaks(pool: Pool, concludedWeek: number, user: User): { type: AchievementType, name: string, description: string } | null {
    let streakLength = 0;
    const history = pool.history ?? {};
    for (let week = concludedWeek; week > 0; week--) {
      const participantsForWeek = history[week];
      if (!participantsForWeek) break;
      if (this.didUserWinWeek(user.uid, participantsForWeek)) {
        streakLength++;
      } else {
        break;
      }
    }
    
    let achievementType: AchievementType | null = null;
    let name = '';
    let description = '';
    
    switch (streakLength) {
      case 2: achievementType = 'BACK_TO_BACK'; break;
      case 3: achievementType = 'THREE_PEAT'; break;
      case 4: achievementType = 'QUAD_CRUSHER'; break;
      default:
        if (streakLength >= 5) achievementType = 'OCHO_CINCO';
        break;
    }

    if (!achievementType) return null;
    
    const definition = this.achievementDefinitions.find(d => d.type === achievementType);
    if (!definition) return null;

    return { type: achievementType, name: definition.name, description: definition.description };
  }
  
  private isPerfectWeek(participant: Participant, games: Game[]): boolean {
    if (participant.picks.length < games.length) return false;
    const gamesById = new Map(games.map(g => [g.id, g]));
    return participant.picks.every(pick => {
        const game = gamesById.get(pick.gameId);
        return game && game.winner === pick.winner;
    });
  }

  private isUpsetKing(participant: Participant, allParticipants: Participant[], games: Game[]): boolean {
    const gamesById = new Map(games.map(g => [g.id, g]));
    const countCorrectUnderdogs = (p: Participant): number => {
      return p.picks.reduce((count, pick) => {
        const game = gamesById.get(pick.gameId);
        if (game) {
          const underdog = this.teamService.getUnderdog(game);
          if (underdog && pick.winner === underdog && game.winner === underdog) return count + 1;
        }
        return count;
      }, 0);
    };
    const userCorrectUnderdogs = countCorrectUnderdogs(participant);
    if (userCorrectUnderdogs === 0) return false;
    const maxCorrectUnderdogs = Math.max(...allParticipants.map(p => countCorrectUnderdogs(p)));
    return userCorrectUnderdogs === maxCorrectUnderdogs;
  }

  private async fetchGamesForWeek(week: number, year: number): Promise<Game[]> {
     try {
       const seasontype = 2;
       const url = `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?week=${week}&year=${year}&seasontype=${seasontype}`;
       const response = await fetch(url);
       const data = await response.json();
       const events = data.events || [];
       return events.map((event: any) => {
          const competition = event.competitions[0];
          const homeComp = competition.competitors.find((c:any) => c.homeAway === 'home');
          const awayComp = competition.competitors.find((c:any) => c.homeAway === 'away');
          if (!homeComp || !awayComp) return null;
          const homeScore = parseInt(homeComp.score || '0', 10);
          const awayScore = parseInt(awayComp.score || '0', 10);
          let winner: string | null = null;
          if (homeScore > awayScore) winner = homeComp.team.displayName;
          else if (awayScore > homeScore) winner = awayComp.team.displayName;
          return {
              id: parseInt(event.id, 10),
              homeTeam: homeComp.team.displayName,
              awayTeam: awayComp.team.displayName,
              homeScore, awayScore, status: 'final', winner,
              line: competition.odds?.[0]?.details,
          };
       }).filter((g: any) => g !== null);
     } catch (error) {
       console.error(`Failed to fetch historical game data for week ${week}, ${year}:`, error);
       return [];
     }
  }

  private getTrophyIcon(rank: 1 | 2 | 3): string {
    if (rank === 1) return `<svg viewBox="0 0 24 24" fill="currentColor" class="text-yellow-400"><path d="M17 2H7C6.45 2 6 2.45 6 3V4C6 4.55 6.45 5 7 5H17C17.55 5 18 4.55 18 4V3C18 2.45 17.55 2 17 2Z" /><path d="M18 6H6C4.34 6 3 7.34 3 9V13C3 14.66 4.34 16 6 16H7V18C7 19.1 7.9 20 9 20H15C16.1 20 17 19.1 17 18V16H18C19.66 16 21 14.66 21 13V9C21 7.34 19.66 6 18 6Z" /></svg>`;
    if (rank === 2) return `<svg viewBox="0 0 24 24" fill="currentColor" class="text-gray-400"><path d="M17 2H7C6.45 2 6 2.45 6 3V4C6 4.55 6.45 5 7 5H17C17.55 5 18 4.55 18 4V3C18 2.45 17.55 2 17 2Z" /><path d="M18 6H6C4.34 6 3 7.34 3 9V13C3 14.66 4.34 16 6 16H7V18C7 19.1 7.9 20 9 20H15C16.1 20 17 19.1 17 18V16H18C19.66 16 21 14.66 21 13V9C21 7.34 19.66 6 18 6Z" /></svg>`;
    return `<svg viewBox="0 0 24 24" fill="currentColor" class="text-orange-400"><path d="M17 2H7C6.45 2 6 2.45 6 3V4C6 4.55 6.45 5 7 5H17C17.55 5 18 4.55 18 4V3C18 2.45 17.55 2 17 2Z" /><path d="M18 6H6C4.34 6 3 7.34 3 9V13C3 14.66 4.34 16 6 16H7V18C7 19.1 7.9 20 9 20H15C16.1 20 17 19.1 17 18V16H18C19.66 16 21 14.66 21 13V9C21 7.34 19.66 6 18 6Z" /></svg>`;
  }

  private getAchievementIcon(type: AchievementType): string {
    switch(type) {
      case 'WELCOME_ABOARD':
        return `<svg xmlns="http://www.w3.org/2000/svg" class="w-full h-full text-green-400" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" /></svg>`;
      case 'THE_ARCHITECT':
        return `<svg xmlns="http://www.w3.org/2000/svg" class="w-full h-full text-blue-400" viewBox="0 0 20 20" fill="currentColor"><path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" /></svg>`;
      case 'FIRST_DOWN':
        return `<svg xmlns="http://www.w3.org/2000/svg" class="w-full h-full text-indigo-400" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a6 6 0 00-6 6v3.586l-1.293 1.293a1 1 0 001.414 1.414L6 12.414V8a4 4 0 118 0v4.414l1.293 1.293a1 1 0 001.414-1.414L14 11.586V8a6 6 0 00-6-6z" /><path d="M10 12a2 2 0 100 4 2 2 0 000-4z" /></svg>`;
      case 'FIRST_VICTORY':
        return `<svg class="w-full h-full text-yellow-400" fill="currentColor" viewBox="0 0 20 20"><path d="M17 2H7C6.45 2 6 2.45 6 3V4C6 4.55 6.45 5 7 5H17C17.55 5 18 4.55 18 4V3C18 2.45 17.55 2 17 2Z" /><path d="M18 6H6C4.34 6 3 7.34 3 9V13C3 14.66 4.34 16 6 16H7V18C7 19.1 7.9 20 9 20H15C16.1 20 17 19.1 17 18V16H18C19.66 16 21 14.66 21 13V9C21 7.34 19.66 6 18 6Z" /></svg>`;
      case 'PERFECT_WEEK':
        return `<svg class="w-full h-full text-cyan-400" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>`;
      case 'UPSET_KING':
        return `<svg class="w-full h-full text-yellow-400" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"></path></svg>`;
      case 'BACK_TO_BACK':
        return `<svg viewBox="0 0 24 24" class="w-full h-full text-blue-400" fill="currentColor"><text x="12" y="16" font-family="sans-serif" font-size="14" fill="currentColor" text-anchor="middle" font-weight="bold">2x</text><path d="M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20Z" opacity="0.3"></path></svg>`;
      case 'THREE_PEAT':
        return `<svg viewBox="0 0 24 24" class="w-full h-full text-purple-400" fill="currentColor"><text x="12" y="16" font-family="sans-serif" font-size="14" fill="currentColor" text-anchor="middle" font-weight="bold">3x</text><path d="M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20Z" opacity="0.3"></path></svg>`;
      case 'QUAD_CRUSHER':
        return `<svg viewBox="0 0 24 24" class="w-full h-full text-red-500" fill="currentColor"><text x="12" y="16" font-family="sans-serif" font-size="14" fill="currentColor" text-anchor="middle" font-weight="bold">4x</text><path d="M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20Z" opacity="0.3"></path></svg>`;
      case 'OCHO_CINCO':
        return `<svg viewBox="0 0 24 24" class="w-full h-full text-yellow-400" fill="currentColor"><text x="12" y="16" font-family="sans-serif" font-size="14" fill="currentColor" text-anchor="middle" font-weight="bold">5x</text><path d="M12 17.27L18.18 21L16.54 13.97L22 9.24L14.81 8.63L12 2L9.19 8.63L2 9.24L7.46 13.97L5.82 21L12 17.27Z" opacity="0.3" /></svg>`;
    }
  }
}
