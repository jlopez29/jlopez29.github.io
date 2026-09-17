
import { PlayoffPicks } from './playoff.model';

export interface Pick {
  gameId: number;
  winner: string;
  confidence: number;
  isUnderdog?: boolean;
}

export interface Participant {
  userId: string;
  displayName: string;
  photoUrl: string;
  picks?: Pick[];
  playoffPicks?: PlayoffPicks;
  tiebreaker: number;
  score: number;
  hasViewedPodium?: boolean;
}

export interface Pool {
  id: string;
  name: string;
  week: number;
  year: number;
  participants: Participant[];
  history?: { [week: string]: Participant[] };
  type?: 'regular' | 'playoff';
  ownerId?: string;
}
