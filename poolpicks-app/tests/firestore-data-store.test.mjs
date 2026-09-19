import test from 'node:test';
import assert from 'node:assert/strict';
import { loadSource, decorator } from './load-source.mjs';

const pool = { name: 'AFCU', year: 2026, week: 3, type: 'regular', ownerId: 'owner' };
const participant = { userId: 'owner', displayName: 'John', photoUrl: 'avatar', picks: [], tiebreaker: 42, score: 99, hasViewedPodium: true };

function fixture(uid = 'owner') {
  const documents = new Map([['pools/AFCU', pool]]);
  const collections = new Map();
  const reads = [];
  const writes = [];
  const snapshot = path => ({ id: path.split('/').at(-1), exists: () => documents.has(path), data: () => documents.get(path) });
  const writer = {
    set: (...args) => writes.push(['set', ...args]),
    update: (...args) => writes.push(['update', ...args]),
    commit: async () => {},
    get: async path => { reads.push(path); return snapshot(path); },
  };
  const sdk = {
    doc: (_, ...parts) => parts.join('/'), collection: (_, ...parts) => parts.join('/'),
    getDoc: writer.get,
    getDocs: async path => {
      reads.push(path);
      return { docs: (collections.get(path) ?? []).map(([id, data]) => ({ id, data: () => data })) };
    },
    setDoc: async (...args) => writer.set(...args),
    updateDoc: async (...args) => writer.update(...args),
    deleteDoc: async (...args) => writes.push(['delete', ...args]),
    serverTimestamp: () => 'SERVER_TIME', Timestamp: { fromDate: date => date.toISOString() },
    writeBatch: () => writer, runTransaction: async (_, callback) => callback(writer),
  };
  const { FirestoreDataStore } = loadSource('services/firestore-data-store.ts', {
    '@angular/core': { Injectable: decorator },
    'firebase/firestore': sdk,
    './firebase-client': { firestore: {}, firebaseAuth: { currentUser: { uid } } },
  });
  collections.set('pools/AFCU/weeks', [
    ['2026-01', { year: 2026, week: 1 }], ['2026-02', { year: 2026, week: 2 }],
    ['2026-03', { year: 2026, week: 3 }], ['2025-01', { year: 2025, week: 1 }],
  ]);
  for (let week = 1; week <= 3; week++) collections.set(`pools/AFCU/weeks/2026-0${week}/submissions`, [['owner', participant]]);
  return { store: new FirestoreDataStore(), documents, reads, writes };
}

test('current-week page does not read historical submissions', async () => {
  const { store, reads } = fixture();
  const result = await store.getPool('AFCU', { historyWeeks: [] });
  assert.deepEqual(result.availableWeeks, [3, 2, 1]);
  assert.deepEqual(result.history, {});
  assert.equal(reads.length, 3);
  assert.equal(result.participants[0].score, 0, 'stored scores must not be trusted');
});

test('selected history and previous podium load without reading the full archive', async () => {
  const { store, reads } = fixture();
  const result = await store.getPool('AFCU', { historyWeeks: [1] });
  assert.deepEqual(Object.keys(result.history), ['1']);
  assert.equal(reads.length, 4);
  assert.ok(!reads.some(path => path.includes('2025')));
  const previous = await store.getPool('AFCU', { historyWeeks: [], includePreviousWeek: true });
  assert.deepEqual(Object.keys(previous.history), ['2']);
});

test('stats can still request complete history, without mixing seasons', async () => {
  const { store } = fixture();
  const result = await store.getPool('AFCU');
  assert.deepEqual(Object.keys(result.history), ['1', '2']);
});

test('saving picks reads metadata only and rejects stale submission weeks', async () => {
  const { store, reads, writes } = fixture();
  await assert.rejects(store.addParticipant('AFCU', participant, { week: 2, year: 2026 }), /moved to another week/);
  assert.equal(writes.length, 0);
  await store.addParticipant('AFCU', participant, { week: 3, year: 2026 });
  assert.deepEqual(reads, ['pools/AFCU', 'pools/AFCU']);
  assert.equal(writes[0][1], 'pools/AFCU/weeks/2026-03/submissions/owner');
  assert.ok(!('score' in writes[0][2]));
});

test('podium updates write only the flag, not immutable picks or scores', async () => {
  const { store, reads, writes } = fixture();
  await store.updateParticipants('AFCU', [participant]);
  await store.updatePoolHistory('AFCU', { 1: [participant] });
  assert.deepEqual(reads, ['pools/AFCU', 'pools/AFCU']);
  assert.deepEqual(writes.map(write => write[2]), [
    { hasViewedPodium: true, updatedAt: 'SERVER_TIME' },
    { hasViewedPodium: true, updatedAt: 'SERVER_TIME' },
  ]);
});

test('unchanged avatar causes no writes and no leaderboard reads', async () => {
  const { store, documents, reads, writes } = fixture();
  documents.set('pools/AFCU/members/owner', { photoUrl: 'avatar' });
  documents.set('pools/AFCU/weeks/2026-03/submissions/owner', participant);
  await store.updateParticipantPhotoUrl('AFCU', 'owner', 'avatar');
  assert.equal(writes.length, 0);
  assert.equal(reads.length, 3);
});

test('leaving a pool does not fetch or delete submissions', async () => {
  const { store, reads, writes } = fixture();
  await store.removeParticipant('AFCU', 'owner');
  assert.deepEqual(reads, []);
  assert.deepEqual(writes, [['delete', 'pools/AFCU/members/owner']]);
});

test('profile map updates replace joinedPools so removed entries stay removed', async () => {
  const { store, writes } = fixture();
  await store.updateUser({ uid: 'owner', joinedPools: { OTHER: 'Other' } });
  assert.deepEqual(writes[0][3], { mergeFields: ['uid', 'joinedPools'] });
});

test('only owner can advance; backward weeks are rejected', async () => {
  await assert.rejects(fixture('member').store.archiveAndAdvanceWeek('AFCU', pool, 4, '2026-09-24T00:00:00Z'), /owner/);
  await assert.rejects(fixture().store.archiveAndAdvanceWeek('AFCU', pool, 2, '2026-09-24T00:00:00Z'), /later/);
});

test('advancement preserves an existing deadline and never rewinds a newer week', async () => {
  const { store, documents, writes } = fixture();
  documents.set('pools/AFCU/weeks/2026-04', { lockAt: 'ORIGINAL' });
  await store.archiveAndAdvanceWeek('AFCU', pool, 4, '2026-09-24T00:00:00Z');
  assert.equal(writes.length, 1);
  assert.equal(writes[0][0], 'update');
  documents.set('pools/AFCU', { ...pool, week: 5 });
  writes.length = 0;
  await store.archiveAndAdvanceWeek('AFCU', pool, 4, '2026-09-24T00:00:00Z');
  assert.equal(writes.length, 0);
});

test('new week receives its supplied kickoff deadline', async () => {
  const { store, writes } = fixture();
  await store.archiveAndAdvanceWeek('AFCU', pool, 4, '2026-09-24T00:00:00Z');
  assert.equal(writes[1][1], 'pools/AFCU/weeks/2026-04');
  assert.equal(writes[1][2].lockAt, '2026-09-24T00:00:00.000Z');
});
