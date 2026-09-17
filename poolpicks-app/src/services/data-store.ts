import { InjectionToken } from '@angular/core';
import { Participant, Pool } from '../models/pool.model';
import type { User } from './auth.service';

export interface CreatePoolData {
  name: string;
  inviteCode: string;
  participants: Participant[];
  week: number;
  year: number;
  type: 'regular' | 'playoff';
  lockAt: string;
}

/**
 * The persistence contract used by the UI.
 *
 * The demo provides a browser-local implementation. A production backend can
 * implement the same contract without leaking database credentials into the
 * client or changing the components that consume DataService.
 */
export interface DataStore {
  createPool(data: CreatePoolData): Promise<string>;
  joinPool(poolId: string, poolName: string, user: User, inviteCode: string): Promise<void>;
  getPool(id: string): Promise<Pool | null>;
  doesPoolExist(id: string): Promise<boolean>;
  getCreatePoolOverride(): Promise<boolean>;
  updateParticipants(poolId: string, participants: Participant[]): Promise<void>;
  updateParticipantPhotoUrl(poolId: string, userId: string, photoUrl: string): Promise<void>;
  addParticipant(poolId: string, participant: Participant): Promise<void>;
  archiveAndAdvanceWeek(poolId: string, currentPool: Pool, newWeek: number, lockAt: string): Promise<void>;
  updatePoolType(poolId: string, type: 'regular' | 'playoff'): Promise<void>;
  updatePoolHistory(poolId: string, history: { [week: string]: Participant[] }): Promise<void>;
  getAllPools(): Promise<Pool[]>;
  removeParticipant(poolId: string, userId: string): Promise<void>;
  getUser(userId: string): Promise<User | null>;
  updateUser(user: User): Promise<void>;
  logError(component: string, errorData: unknown): Promise<void>;
}

export const DATA_STORE = new InjectionToken<DataStore>('POOLPICKS_DATA_STORE');
