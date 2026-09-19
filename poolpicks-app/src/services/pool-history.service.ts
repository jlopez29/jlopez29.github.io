import { Injectable, inject } from '@angular/core';
import { Game } from '../models/game.model';
import { Participant, Pool } from '../models/pool.model';
import { GameService } from './game.service';

/** Scores are derived data, never client-writable leaderboard totals in Firestore. */
export function scoreParticipants(participants: Participant[], games: Game[]): Participant[] {
  const finals = games.filter(game => game.status === 'final' && game.winner);
  const winners = new Map(finals.map(game => [game.id, game.winner]));
  const tiebreaker = games.find(game => game.isMondayNight) ?? (games.length === 1 ? games[0] : undefined);
  const actualTotal = tiebreaker?.status === 'final' ? tiebreaker.homeScore + tiebreaker.awayScore : null;
  return participants.map(participant => ({
    ...participant,
    score: participant.playoffPicks
      ? finals.reduce((sum, game) => sum + (participant.playoffPicks!.confidencePicks[game.winner!] ?? 0), 0)
      : (participant.picks ?? []).reduce((sum, pick) => sum + (winners.get(pick.gameId) === pick.winner ? pick.confidence : 0), 0),
  })).sort((a, b) => b.score - a.score || (actualTotal === null ? 0 :
    Math.abs(a.tiebreaker - actualTotal) - Math.abs(b.tiebreaker - actualTotal)));
}

@Injectable({ providedIn: 'root' })
export class PoolHistoryService {
  private readonly games = inject(GameService);

  /** Only stats and concluded-week awards need the entire scored archive. */
  async withScores(pool: Pool): Promise<Pool> {
    const weeks: Record<string, Participant[]> = { ...pool.history, [pool.week]: pool.participants };
    const concludedWeeks: number[] = [];
    const scored = await Promise.all(Object.entries(weeks).map(async ([week, participants]) => {
      if (!participants.length) return [week, participants] as const;
      const games = await this.games.getWeekGames(Number(week), pool.year);
      if (!games.length) throw new Error(`The schedule for week ${week} is unavailable. Please try again.`);
      if (games.every(game => game.status === 'final')) concludedWeeks.push(Number(week));
      return [week, scoreParticipants(participants, games)] as const;
    }));
    const history = Object.fromEntries(scored);
    const participants = history[pool.week];
    delete history[pool.week];
    return { ...pool, participants, history, concludedWeeks };
  }
}
