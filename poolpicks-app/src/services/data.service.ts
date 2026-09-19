import { inject, Injectable } from '@angular/core';
import { Participant, Pool } from '../models/pool.model';
import type { User } from './auth.service';
import { CreatePoolData, DATA_STORE, DataStore, PoolReadOptions, SubmissionWeek } from './data-store';

/** Stable application-facing facade over whichever persistence adapter is configured. */
@Injectable({ providedIn: 'root' })
export class DataService implements DataStore {
  private readonly store = inject(DATA_STORE);

  createPool(data: CreatePoolData) { return this.store.createPool(data); }
  joinPool(poolId: string, poolName: string, user: User, inviteCode: string) { return this.store.joinPool(poolId, poolName, user, inviteCode); }
  getPool(id: string, options?: PoolReadOptions) { return this.store.getPool(id, options); }
  doesPoolExist(id: string) { return this.store.doesPoolExist(id); }
  getCreatePoolOverride() { return this.store.getCreatePoolOverride(); }
  updateParticipants(poolId: string, participants: Participant[]) { return this.store.updateParticipants(poolId, participants); }
  updateParticipantPhotoUrl(poolId: string, userId: string, photoUrl: string) { return this.store.updateParticipantPhotoUrl(poolId, userId, photoUrl); }
  addParticipant(poolId: string, participant: Participant, expectedWeek?: SubmissionWeek) { return this.store.addParticipant(poolId, participant, expectedWeek); }
  archiveAndAdvanceWeek(poolId: string, currentPool: Pool, newWeek: number, lockAt: string) { return this.store.archiveAndAdvanceWeek(poolId, currentPool, newWeek, lockAt); }
  updatePoolType(poolId: string, type: 'regular' | 'playoff') { return this.store.updatePoolType(poolId, type); }
  updatePoolHistory(poolId: string, history: { [week: string]: Participant[] }) { return this.store.updatePoolHistory(poolId, history); }
  getAllPools() { return this.store.getAllPools(); }
  removeParticipant(poolId: string, userId: string) { return this.store.removeParticipant(poolId, userId); }
  getUser(userId: string) { return this.store.getUser(userId); }
  updateUser(user: User) { return this.store.updateUser(user); }
  logError(component: string, errorData: unknown) { return this.store.logError(component, errorData); }
}
