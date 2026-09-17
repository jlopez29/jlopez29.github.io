import { Injectable } from '@angular/core';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { Participant, Pool } from '../models/pool.model';
import type { User } from './auth.service';
import { CreatePoolData, DataStore } from './data-store';
import { firebaseAuth, firestore } from './firebase-client';

type PoolDocument = Omit<Pool, 'id' | 'participants' | 'history'> & {
  ownerId: string;
};

@Injectable()
export class FirestoreDataStore implements DataStore {
  async createPool(data: CreatePoolData): Promise<string> {
    const authUser = this.requireAuth();
    const poolId = this.normalizePoolId(data.name);
    const poolRef = doc(firestore, 'pools', poolId);
    if ((await getDoc(poolRef)).exists()) throw new Error('A pool with this name already exists.');

    const participant = data.participants.find(item => item.userId === authUser.uid);
    if (!participant) throw new Error('The pool creator must submit their own picks.');

    const weekId = this.weekId(data.year, data.week);
    const batch = writeBatch(firestore);
    batch.set(poolRef, {
      name: data.name.trim(),
      week: data.week,
      year: data.year,
      type: data.type,
      ownerId: authUser.uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(firestore, 'pools', poolId, 'members', authUser.uid), {
      userId: authUser.uid,
      displayName: participant.displayName,
      photoUrl: participant.photoUrl,
      role: 'owner',
      joinedAt: serverTimestamp(),
    });
    batch.set(doc(firestore, 'pools', poolId, 'weeks', weekId), {
      year: data.year,
      week: data.week,
      type: data.type,
      lockAt: Timestamp.fromDate(new Date(data.lockAt)),
      createdAt: serverTimestamp(),
    });
    batch.set(
      doc(firestore, 'pools', poolId, 'weeks', weekId, 'submissions', authUser.uid),
      this.toSubmission(participant),
    );
    await batch.commit();
    return poolId;
  }

  async getPool(id: string): Promise<Pool | null> {
    this.requireAuth();
    const poolId = this.normalizePoolId(id);
    const snapshot = await getDoc(doc(firestore, 'pools', poolId));
    if (!snapshot.exists()) return null;

    const data = snapshot.data() as PoolDocument;
    const currentWeekId = this.weekId(data.year, data.week);
    const participants = await this.readParticipants(poolId, currentWeekId);
    const history: { [week: string]: Participant[] } = {};
    const weeks = await getDocs(collection(firestore, 'pools', poolId, 'weeks'));

    await Promise.all(weeks.docs.map(async weekSnapshot => {
      if (weekSnapshot.id === currentWeekId) return;
      const weekData = weekSnapshot.data() as { week?: number };
      if (typeof weekData.week !== 'number') return;
      history[String(weekData.week)] = await this.readParticipants(poolId, weekSnapshot.id);
    }));

    return {
      id: snapshot.id,
      name: data.name,
      week: data.week,
      year: data.year,
      type: data.type ?? 'regular',
      ownerId: data.ownerId,
      participants,
      history,
    };
  }

  async doesPoolExist(id: string): Promise<boolean> {
    this.requireAuth();
    return (await getDoc(doc(firestore, 'pools', this.normalizePoolId(id)))).exists();
  }

  async getCreatePoolOverride(): Promise<boolean> {
    return false;
  }

  async updateParticipants(poolId: string, participants: Participant[]): Promise<void> {
    const authUser = this.requireAuth();
    const pool = await this.getPool(poolId);
    if (!pool) throw new Error('Pool not found.');
    const ownParticipant = participants.find(item => item.userId === authUser.uid);
    if (!ownParticipant) return;

    await setDoc(
      doc(firestore, 'pools', pool.id, 'weeks', this.weekId(pool.year, pool.week), 'submissions', authUser.uid),
      this.toSubmission(ownParticipant),
      { merge: true },
    );
  }

  async updateParticipantPhotoUrl(poolId: string, userId: string, photoUrl: string): Promise<void> {
    const authUser = this.requireAuth();
    if (authUser.uid !== userId) throw new Error('You may only update your own profile.');
    const pool = await this.getPool(poolId);
    if (!pool) return;

    const batch = writeBatch(firestore);
    const memberRef = doc(firestore, 'pools', pool.id, 'members', userId);
    const submissionRef = doc(
      firestore,
      'pools',
      pool.id,
      'weeks',
      this.weekId(pool.year, pool.week),
      'submissions',
      userId,
    );
    if ((await getDoc(memberRef)).exists()) batch.update(memberRef, { photoUrl });
    if ((await getDoc(submissionRef)).exists()) batch.update(submissionRef, { photoUrl, updatedAt: serverTimestamp() });
    await batch.commit();
  }

  async addParticipant(poolId: string, participant: Participant): Promise<void> {
    const authUser = this.requireAuth();
    if (participant.userId !== authUser.uid) throw new Error('You may only submit your own picks.');
    const pool = await this.getPool(poolId);
    if (!pool) throw new Error('Pool not found.');

    const batch = writeBatch(firestore);
    batch.set(doc(firestore, 'pools', pool.id, 'members', authUser.uid), {
      userId: authUser.uid,
      displayName: participant.displayName,
      photoUrl: participant.photoUrl,
      role: pool.ownerId === authUser.uid ? 'owner' : 'member',
      joinedAt: serverTimestamp(),
    }, { merge: true });
    batch.set(
      doc(firestore, 'pools', pool.id, 'weeks', this.weekId(pool.year, pool.week), 'submissions', authUser.uid),
      this.toSubmission(participant),
      { merge: true },
    );
    await batch.commit();
  }

  async archiveAndAdvanceWeek(poolId: string, currentPool: Pool, newWeek: number, lockAt: string): Promise<void> {
    const authUser = this.requireAuth();
    if (currentPool.ownerId !== authUser.uid) return;
    const poolRef = doc(firestore, 'pools', this.normalizePoolId(poolId));
    const nextWeekRef = doc(firestore, 'pools', this.normalizePoolId(poolId), 'weeks', this.weekId(currentPool.year, newWeek));
    const batch = writeBatch(firestore);
    batch.update(poolRef, { week: newWeek, updatedAt: serverTimestamp() });
    batch.set(nextWeekRef, {
      year: currentPool.year,
      week: newWeek,
      type: currentPool.type ?? 'regular',
      lockAt: Timestamp.fromDate(new Date(lockAt)),
      createdAt: serverTimestamp(),
    }, { merge: true });
    await batch.commit();
  }

  async updatePoolType(poolId: string, type: 'regular' | 'playoff'): Promise<void> {
    await updateDoc(doc(firestore, 'pools', this.normalizePoolId(poolId)), {
      type,
      updatedAt: serverTimestamp(),
    });
  }

  async updatePoolHistory(poolId: string, history: { [week: string]: Participant[] }): Promise<void> {
    const authUser = this.requireAuth();
    const pool = await this.getPool(poolId);
    if (!pool) throw new Error('Pool not found.');

    const writes: Promise<void>[] = [];
    for (const [week, participants] of Object.entries(history)) {
      const ownParticipant = participants.find(item => item.userId === authUser.uid);
      if (!ownParticipant) continue;
      writes.push(setDoc(
        doc(firestore, 'pools', pool.id, 'weeks', this.weekId(pool.year, Number(week)), 'submissions', authUser.uid),
        this.toSubmission(ownParticipant),
        { merge: true },
      ));
    }
    await Promise.all(writes);
  }

  async getAllPools(): Promise<Pool[]> {
    this.requireAuth();
    const snapshots = await getDocs(collection(firestore, 'pools'));
    const pools = await Promise.all(snapshots.docs.map(snapshot => this.getPool(snapshot.id)));
    return pools.filter((pool): pool is Pool => pool !== null);
  }

  async removeParticipant(poolId: string, userId: string): Promise<void> {
    const authUser = this.requireAuth();
    if (authUser.uid !== userId) throw new Error('You may only remove yourself from a pool.');
    const pool = await this.getPool(poolId);
    if (!pool) return;
    const weekId = this.weekId(pool.year, pool.week);
    const weekSnapshot = await getDoc(doc(firestore, 'pools', pool.id, 'weeks', weekId));
    const lockAt = weekSnapshot.data()?.['lockAt'];
    const deletes = [deleteDoc(doc(firestore, 'pools', pool.id, 'members', userId))];

    // Locked picks remain as an immutable audit record, even if someone leaves the pool.
    if (lockAt instanceof Timestamp && Date.now() < lockAt.toMillis()) {
      deletes.push(deleteDoc(doc(firestore, 'pools', pool.id, 'weeks', weekId, 'submissions', userId)));
    }
    await Promise.all(deletes);
  }

  async getUser(userId: string): Promise<User | null> {
    this.requireAuth();
    const snapshot = await getDoc(doc(firestore, 'users', userId));
    return snapshot.exists() ? snapshot.data() as User : null;
  }

  async updateUser(user: User): Promise<void> {
    const authUser = this.requireAuth();
    if (authUser.uid !== user.uid) throw new Error('You may only update your own profile.');

    const batch = writeBatch(firestore);
    batch.set(doc(firestore, 'users', user.uid), user, { merge: true });
    for (const [poolId, poolName] of Object.entries(user.joinedPools ?? {})) {
      batch.set(doc(firestore, 'pools', poolId, 'members', user.uid), {
        userId: user.uid,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        poolName,
        joinedAt: serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
  }

  async logError(component: string, errorData: unknown): Promise<void> {
    console.error(`[${component}]`, errorData);
  }

  private async readParticipants(poolId: string, weekId: string): Promise<Participant[]> {
    const authUser = this.requireAuth();
    const weekSnapshot = await getDoc(doc(firestore, 'pools', poolId, 'weeks', weekId));
    const lockAt = weekSnapshot.data()?.['lockAt'];
    if (lockAt instanceof Timestamp && Date.now() < lockAt.toMillis()) {
      const ownSubmission = await getDoc(
        doc(firestore, 'pools', poolId, 'weeks', weekId, 'submissions', authUser.uid),
      );
      return ownSubmission.exists()
        ? [this.fromSubmission(ownSubmission.id, ownSubmission.data() as Participant)]
        : [];
    }

    const snapshots = await getDocs(collection(firestore, 'pools', poolId, 'weeks', weekId, 'submissions'));
    return snapshots.docs.map(snapshot => this.fromSubmission(snapshot.id, snapshot.data() as Participant));
  }

  private fromSubmission(userId: string, data: Participant): Participant {
    return {
      userId,
      displayName: data.displayName,
      photoUrl: data.photoUrl,
      picks: data.picks,
      playoffPicks: data.playoffPicks,
      tiebreaker: data.tiebreaker ?? 0,
      score: 0,
      hasViewedPodium: data.hasViewedPodium ?? false,
    };
  }

  private toSubmission(participant: Participant): Record<string, unknown> {
    return {
      userId: participant.userId,
      displayName: participant.displayName.trim(),
      photoUrl: participant.photoUrl,
      picks: participant.picks,
      playoffPicks: participant.playoffPicks,
      tiebreaker: participant.tiebreaker,
      hasViewedPodium: participant.hasViewedPodium ?? false,
      updatedAt: serverTimestamp(),
    };
  }

  private weekId(year: number, week: number): string {
    return `${year}-${String(week).padStart(2, '0')}`;
  }

  private normalizePoolId(value: string): string {
    const id = value.trim();
    if (!id || id.includes('/')) throw new Error('Pool names cannot be empty or contain slashes.');
    return id;
  }

  private requireAuth() {
    const user = firebaseAuth.currentUser;
    if (!user) throw new Error('Authentication is still loading. Please try again.');
    return user;
  }
}
