export type GameStatus = 'scheduled' | 'in_progress' | 'final';

export interface Game {
  id: number;
  homeTeam: string;
  awayTeam: string;
  homeScore: number;
  awayScore: number;
  status: GameStatus;
  time: string;
  startTime: string;
  isMondayNight: boolean;
  winner: string | null;
  line?: string;
}
