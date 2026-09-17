export interface Trophy {
  poolId: string;
  poolName: string;
  week: number;
  year: number;
  rank: 1 | 2 | 3;
}

export type AchievementType = 'PERFECT_WEEK' | 'UPSET_KING' | 'BACK_TO_BACK' | 'THREE_PEAT' | 'QUAD_CRUSHER' | 'OCHO_CINCO' | 'WELCOME_ABOARD' | 'THE_ARCHITECT' | 'FIRST_DOWN' | 'FIRST_VICTORY';

export interface Achievement {
  id: string; // e.g., 'PERFECT_WEEK_poolId_week_year'
  name: string;
  description: string;
  iconSvg: string;
  poolName?: string; // Optional for non-pool-specific achievements
  week?: number;
  year?: number;
  type: AchievementType;
}