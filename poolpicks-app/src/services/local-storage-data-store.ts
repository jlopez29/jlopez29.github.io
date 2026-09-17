import { Injectable } from '@angular/core';
import { Participant, Pool } from '../models/pool.model';
import type { User } from './auth.service';
import { CreatePoolData, DataStore } from './data-store';

const POOLS_KEY = 'poolpicks-demo-v1-pools';
const USERS_KEY = 'poolpicks-demo-v1-users';

@Injectable()
export class LocalStorageDataStore implements DataStore {
  async createPool(data: CreatePoolData): Promise<string> {
    const id = data.name.trim();
    if (!id) throw new Error('A pool name is required.');

    const pools = this.readRecord<Pool>(POOLS_KEY);
    if (pools[id]) throw new Error('A pool with this name already exists.');

    pools[id] = {
      id,
      name: id,
      week: data.week,
      year: data.year,
      participants: this.clone(data.participants),
      type: data.type,
    };
    this.writeRecord(POOLS_KEY, pools);
    return id;
  }

  async joinPool(_poolId: string, _poolName: string, _user: User, _inviteCode: string): Promise<void> {
    // The local demo adapter has no remote membership boundary.
  }

  async getPool(id: string): Promise<Pool | null> {
    const pool = this.readRecord<Pool>(POOLS_KEY)[id];
    return pool ? this.clone(pool) : null;
  }

  async doesPoolExist(id: string): Promise<boolean> {
    return Boolean(this.readRecord<Pool>(POOLS_KEY)[id]);
  }

  async getCreatePoolOverride(): Promise<boolean> {
    return false;
  }

  async updateParticipants(poolId: string, participants: Participant[]): Promise<void> {
    this.updatePool(poolId, pool => ({ ...pool, participants: this.clone(participants) }));
  }

  async updateParticipantPhotoUrl(poolId: string, userId: string, photoUrl: string): Promise<void> {
    this.updatePool(poolId, pool => ({
      ...pool,
      participants: pool.participants.map(participant =>
        participant.userId === userId ? { ...participant, photoUrl } : participant
      ),
      history: pool.history
        ? Object.fromEntries(Object.entries(pool.history).map(([week, participants]) => [
            week,
            participants.map(participant =>
              participant.userId === userId ? { ...participant, photoUrl } : participant
            ),
          ]))
        : undefined,
    }));
  }

  async addParticipant(poolId: string, participant: Participant): Promise<void> {
    this.updatePool(poolId, pool => {
      const participants = [...pool.participants];
      const index = participants.findIndex(item => item.userId === participant.userId);
      if (index >= 0) participants[index] = this.clone(participant);
      else participants.push(this.clone(participant));
      return { ...pool, participants };
    });
  }

  async archiveAndAdvanceWeek(poolId: string, currentPool: Pool, newWeek: number, _lockAt: string): Promise<void> {
    this.updatePool(poolId, pool => ({
      ...pool,
      week: newWeek,
      participants: [],
      history: {
        ...(pool.history ?? {}),
        [currentPool.week]: this.clone(currentPool.participants),
      },
    }));
  }

  async updatePoolType(poolId: string, type: 'regular' | 'playoff'): Promise<void> {
    this.updatePool(poolId, pool => ({ ...pool, type }));
  }

  async updatePoolHistory(poolId: string, history: { [week: string]: Participant[] }): Promise<void> {
    this.updatePool(poolId, pool => ({ ...pool, history: this.clone(history) }));
  }

  async getAllPools(): Promise<Pool[]> {
    return this.clone(Object.values(this.readRecord<Pool>(POOLS_KEY)));
  }

  async removeParticipant(poolId: string, userId: string): Promise<void> {
    this.updatePool(poolId, pool => ({
      ...pool,
      participants: pool.participants.filter(participant => participant.userId !== userId),
    }));
  }

  async getUser(userId: string): Promise<User | null> {
    const user = this.readRecord<User>(USERS_KEY)[userId];
    return user ? this.clone(user) : null;
  }

  async updateUser(user: User): Promise<void> {
    const users = this.readRecord<User>(USERS_KEY);
    users[user.uid] = this.clone(user);
    this.writeRecord(USERS_KEY, users);
  }

  async logError(component: string, errorData: unknown): Promise<void> {
    // Demo errors stay in the browser console. They are never sent off-device.
    console.error(`[${component}]`, errorData);
  }

  private updatePool(poolId: string, update: (pool: Pool) => Pool): void {
    const pools = this.readRecord<Pool>(POOLS_KEY);
    const pool = pools[poolId];
    if (!pool) throw new Error('Pool not found.');
    pools[poolId] = this.clone(update(this.clone(pool)));
    this.writeRecord(POOLS_KEY, pools);
  }

  private readRecord<T>(key: string): Record<string, T> {
    try {
      const raw = localStorage.getItem(key);
      if (!raw) return {};
      const value = JSON.parse(raw);
      return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
    } catch (error) {
      console.warn(`Ignoring invalid local demo data for ${key}.`, error);
      return {};
    }
  }

  private writeRecord<T>(key: string, value: Record<string, T>): void {
    localStorage.setItem(key, JSON.stringify(value));
  }

  private clone<T>(value: T): T {
    return typeof structuredClone === 'function'
      ? structuredClone(value)
      : JSON.parse(JSON.stringify(value));
  }
}
