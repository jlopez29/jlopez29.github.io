import { Injectable } from '@angular/core';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { Participant, Pool } from '../models/pool.model';
import type { User } from './auth.service';
import { CreatePoolData, DataStore, PoolReadOptions, SubmissionWeek } from './data-store';
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
      inviteCode: data.inviteCode.trim(),
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

  async joinPool(poolId: string, poolName: string, user: User, inviteCode: string): Promise<void> {
    const authUser = this.requireAuth();
    if (authUser.uid !== user.uid) throw new Error('You may only join a pool as yourself.');

    const memberRef = doc(firestore, 'pools', this.normalizePoolId(poolId), 'members', user.uid);
    if ((await getDoc(memberRef)).exists()) return;

    await setDoc(memberRef, {
      userId: user.uid,
      displayName: user.displayName.trim(),
      photoUrl: user.photoUrl,
      poolName,
      role: 'member',
      inviteCode: inviteCode.trim(),
      joinedAt: serverTimestamp(),
    });
  }

  async getPool(id: string, options: PoolReadOptions = {}): Promise<Pool | null> {
    this.requireAuth();
    const poolId = this.normalizePoolId(id);
    const snapshot = await getDoc(doc(firestore, 'pools', poolId));
    if (!snapshot.exists()) return null;

    const data = snapshot.data() as PoolDocument;
    const currentWeekId = this.weekId(data.year, data.week);
    const [participants, weeks] = await Promise.all([
      this.readParticipants(poolId, currentWeekId),
      getDocs(collection(firestore, 'pools', poolId, 'weeks')),
    ]);
    const history: { [week: string]: Participant[] } = {};
    const availableWeeks: number[] = [data.week];

    await Promise.all(weeks.docs.map(async weekSnapshot => {
      if (weekSnapshot.id === currentWeekId) return;
      const weekData = weekSnapshot.data() as { year?: number; week?: number };
      if (weekData.year !== data.year || typeof weekData.week !== 'number') return;
      availableWeeks.push(weekData.week);
      if (options.historyWeeks && !options.historyWeeks.includes(weekData.week)
        && !(options.includePreviousWeek && weekData.week === data.week - 1)) return;
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
      availableWeeks: availableWeeks.sort((a, b) => b - a),
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
    const pool = await this.getPoolMetadata(poolId);
    if (!pool) throw new Error('Pool not found.');
    const ownParticipant = participants.find(item => item.userId === authUser.uid);
    if (!ownParticipant) return;

    await updateDoc(
      doc(firestore, 'pools', pool.id, 'weeks', this.weekId(pool.year, pool.week), 'submissions', authUser.uid),
      { hasViewedPodium: ownParticipant.hasViewedPodium ?? false, updatedAt: serverTimestamp() },
    );
  }

  async updateParticipantPhotoUrl(poolId: string, userId: string, photoUrl: string): Promise<void> {
    const authUser = this.requireAuth();
    if (authUser.uid !== userId) throw new Error('You may only update your own profile.');
    const pool = await this.getPoolMetadata(poolId);
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
    const [member, submission] = await Promise.all([getDoc(memberRef), getDoc(submissionRef)]);
    let changed = false;
    if (member.exists() && member.data()['photoUrl'] !== photoUrl) {
      batch.update(memberRef, { photoUrl });
      changed = true;
    }
    if (submission.exists() && submission.data()['photoUrl'] !== photoUrl) {
      batch.update(submissionRef, { photoUrl, updatedAt: serverTimestamp() });
      changed = true;
    }
    if (changed) await batch.commit();
  }

  async addParticipant(poolId: string, participant: Participant, expectedWeek?: SubmissionWeek): Promise<void> {
    const authUser = this.requireAuth();
    if (participant.userId !== authUser.uid) throw new Error('You may only submit your own picks.');
    const pool = await this.getPoolMetadata(poolId);
    if (!pool) throw new Error('Pool not found.');
    if (expectedWeek && (pool.week !== expectedWeek.week || pool.year !== expectedWeek.year)) {
      throw new Error('The pool has moved to another week. Refresh before submitting your picks.');
    }

    await setDoc(
      doc(firestore, 'pools', pool.id, 'weeks', this.weekId(pool.year, pool.week), 'submissions', authUser.uid),
      this.toSubmission(participant),
      { merge: true },
    );
  }

  async archiveAndAdvanceWeek(poolId: string, currentPool: Pool, newWeek: number, lockAt: string): Promise<void> {
    const authUser = this.requireAuth();
    if (currentPool.ownerId !== authUser.uid) throw new Error('Only the pool owner can start the next week.');
    if (!Number.isInteger(newWeek) || newWeek <= currentPool.week || newWeek > 22) {
      throw new Error('The next week must be later in the same season.');
    }
    const poolRef = doc(firestore, 'pools', this.normalizePoolId(poolId));
    const nextWeekRef = doc(firestore, 'pools', this.normalizePoolId(poolId), 'weeks', this.weekId(currentPool.year, newWeek));
    await runTransaction(firestore, async transaction => {
      const snapshot = await transaction.get(poolRef);
      const nextWeek = await transaction.get(nextWeekRef);
      const latest = snapshot.data() as PoolDocument | undefined;
      if (!latest || latest.ownerId !== authUser.uid || latest.year !== currentPool.year) {
        throw new Error('The pool has changed. Please refresh.');
      }
      if (latest.week >= newWeek) return; // Another tab already advanced it; never rewind.
      transaction.update(poolRef, { week: newWeek, updatedAt: serverTimestamp() });
      if (!nextWeek.exists()) transaction.set(nextWeekRef, {
        year: currentPool.year,
        week: newWeek,
        type: currentPool.type ?? 'regular',
        lockAt: Timestamp.fromDate(new Date(lockAt)),
        createdAt: serverTimestamp(),
      });
    });
  }

  async updatePoolType(poolId: string, type: 'regular' | 'playoff'): Promise<void> {
    await updateDoc(doc(firestore, 'pools', this.normalizePoolId(poolId)), {
      type,
      updatedAt: serverTimestamp(),
    });
  }

  async updatePoolHistory(poolId: string, history: { [week: string]: Participant[] }): Promise<void> {
    const authUser = this.requireAuth();
    const pool = await this.getPoolMetadata(poolId);
    if (!pool) throw new Error('Pool not found.');

    const writes: Promise<void>[] = [];
    for (const [week, participants] of Object.entries(history)) {
      const ownParticipant = participants.find(item => item.userId === authUser.uid);
      if (!ownParticipant) continue;
      writes.push(updateDoc(
        doc(firestore, 'pools', pool.id, 'weeks', this.weekId(pool.year, Number(week)), 'submissions', authUser.uid),
        { hasViewedPodium: ownParticipant.hasViewedPodium ?? false, updatedAt: serverTimestamp() },
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
    // Submitted picks remain immutable even when someone leaves and later rejoins.
    await deleteDoc(doc(firestore, 'pools', this.normalizePoolId(poolId), 'members', userId));
  }

  async getUser(userId: string): Promise<User | null> {
    this.requireAuth();
    const snapshot = await getDoc(doc(firestore, 'users', userId));
    return snapshot.exists() ? snapshot.data() as User : null;
  }

  async updateUser(user: User): Promise<void> {
    const authUser = this.requireAuth();
    if (authUser.uid !== user.uid) throw new Error('You may only update your own profile.');

    // Replace supplied top-level maps: recursive merge would resurrect removed pools.
    await setDoc(doc(firestore, 'users', user.uid), user, { mergeFields: Object.keys(user) });
  }

  async logError(component: string, errorData: unknown): Promise<void> {
    console.error(`[${component}]`, errorData);
  }

  private async readParticipants(poolId: string, weekId: string): Promise<Participant[]> {
    this.requireAuth();
    const snapshots = await getDocs(collection(firestore, 'pools', poolId, 'weeks', weekId, 'submissions'));
    return snapshots.docs.map(snapshot => this.fromSubmission(snapshot.id, snapshot.data() as Participant));
  }

  private async getPoolMetadata(id: string): Promise<(PoolDocument & { id: string }) | null> {
    this.requireAuth();
    const snapshot = await getDoc(doc(firestore, 'pools', this.normalizePoolId(id)));
    return snapshot.exists() ? { ...snapshot.data() as PoolDocument, id: snapshot.id } : null;
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
