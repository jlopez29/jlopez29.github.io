import test from 'node:test';
import assert from 'node:assert/strict';
import * as rxjs from 'rxjs';
import * as operators from 'rxjs/operators';
import { loadSource, decorator, signal } from './load-source.mjs';

const core = { Injectable: decorator, Component: decorator, signal, computed: fn => fn, ChangeDetectionStrategy: { OnPush: 0 } };
const event = (id, date, status = 'STATUS_FINAL') => ({
  id: String(id), date,
  competitions: [{ competitors: [
    { homeAway: 'home', team: { displayName: 'Home' }, score: '21' },
    { homeAway: 'away', team: { displayName: 'Away' }, score: '7' },
  ], status: { type: { name: status } } }],
});

function gamesFixture() {
  const requests = [];
  const http = { get: url => { const subject = new rxjs.Subject(); requests.push({ url, subject }); return subject; } };
  const { GameService } = loadSource('services/game.service.ts', {
    '@angular/core': { ...core, inject: token => token === 'http' ? http : { getCreatePoolOverride: async () => false } },
    '@angular/common/http': { HttpClient: 'http' }, './data.service': { DataService: 'data' },
    rxjs, 'rxjs/operators': operators,
  });
  const service = new GameService();
  requests[0].subject.next({ week: { number: 1 }, season: { year: 2026 }, events: [] });
  requests[0].subject.complete();
  return { service, requests };
}

test('changing weeks cancels outdated HTTP requests and deduplicates identical requests', () => {
  const { service, requests } = gamesFixture();
  service.loadSpecificWeek(2);
  service.loadSpecificWeek(2);
  assert.equal(requests.length, 2);
  service.loadSpecificWeek(3);
  assert.equal(requests[1].subject.observed, false);
  requests[2].subject.next({ events: [event(3, '2026-09-28T23:00:00Z')] });
  requests[2].subject.complete();
  requests[1].subject.next({ events: [event(2, '2026-09-21T23:00:00Z')] });
  assert.equal(service.gamesWeek(), 3);
  assert.equal(service.games()[0].id, 3);
});

test('background deadline fetch does not change the visible week; finals are reused', async () => {
  const { service, requests } = gamesFixture();
  const first = service.getWeekGames(2, 2026);
  const second = service.getWeekGames(2, 2026);
  assert.equal(first, second);
  requests[1].subject.next({ events: [event(2, '2026-09-21T23:00:00Z')] });
  requests[1].subject.complete();
  const games = await first;
  assert.equal(service.gamesWeek(), 1);
  assert.equal(await service.getWeekGames(2, 2026), games);
  assert.equal(requests.length, 2);
});

test('Monday tiebreaker is selected in Eastern time, independent of browser timezone', () => {
  const { service } = gamesFixture();
  const games = service.mapEspnToGames([
    event(1, '2026-09-21T00:20:00Z'), // Sunday evening ET
    event(2, '2026-09-22T00:15:00Z'), // Monday evening ET
    event(3, '2026-09-23T00:15:00Z'), // Tuesday evening ET
  ]);
  assert.equal(games.find(game => game.isMondayNight).id, 2);
});

test('historical schedule requests use the pool season, not the live season', () => {
  const { service, requests } = gamesFixture();
  service.loadSpecificWeek(3, 2025);
  assert.match(requests[1].url, /year=2025/);
  requests[1].subject.next({ events: [] });
  requests[1].subject.complete();
  assert.equal(service.gamesYear(), 2025);
  assert.equal(service.year(), 2026);
});

test('historical regular and playoff scores count final winners only and preserve identities', () => {
  const { scoreParticipants } = loadSource('services/pool-history.service.ts', {
    '@angular/core': core, './game.service': {},
  });
  const participants = [
    { userId: 'a', displayName: 'John', score: 999, picks: [
      { gameId: 1, winner: 'Home', confidence: 3 }, { gameId: 2, winner: 'Away', confidence: 2 },
    ] },
    { userId: 'b', displayName: 'John', score: 999, playoffPicks: { confidencePicks: { Home: 14, Away: 13 } } },
  ];
  const scored = scoreParticipants(participants, [
    { id: 1, winner: 'Home', status: 'final' }, { id: 2, winner: 'Away', status: 'in_progress' },
  ]);
  assert.deepEqual(scored.map(p => [p.userId, p.score]), [['b', 14], ['a', 3]]);
  assert.equal(participants[0].score, 999, 'source documents remain untouched');
});

function poolComponentClass() {
  return loadSource('components/pool/pool.component.ts', {
    '@angular/core': core, '@angular/common': {}, '@angular/router': {}, '@angular/core/rxjs-interop': {},
    '../picks/picks.component': {}, '../leaderboard/leaderboard.component': {}, '../schedule/schedule.component': {},
    '../podium/podium.component': {}, '../playoff-bracket/playoff-bracket.component': {},
    '../../services/game.service': {}, '../../services/data.service': {}, '../../services/auth.service': {},
    '../../services/pool.service': {}, '../../services/pool-state.service': {}, '../../services/achievement.service': {},
    '../../services/pool-history.service': {},
  }).PoolComponent;
}

test('failed submissions retain the form; double clicks do not submit twice', async () => {
  const PoolComponent = poolComponentClass();
  const component = Object.create(PoolComponent.prototype);
  let resolveSave;
  let saves = 0;
  let reloads = 0;
  let draftClears = 0;
  Object.assign(component, {
    poolId: signal('AFCU'), pool: signal({ week: 3, year: 2026 }), viewedWeek: signal(3),
    isSubmitting: signal(false), isCreatingPool: signal(false),
    poolService: { submitPicks: () => { saves++; return new Promise(resolve => { resolveSave = resolve; }); } },
    loadPoolData: async () => { reloads++; }, picksForm: () => ({ clearSavedDraft: () => { draftClears++; } }),
  });
  const first = component.handlePicksSubmitted({ picks: [], tiebreaker: 42 });
  await component.handlePicksSubmitted({ picks: [], tiebreaker: 42 });
  assert.equal(saves, 1);
  resolveSave(false);
  await first;
  assert.equal(reloads, 0);
  assert.equal(draftClears, 0);
  assert.equal(component.isSubmitting(), false);
  const retry = component.handlePicksSubmitted({ picks: [], tiebreaker: 42 });
  resolveSave(true);
  await retry;
  assert.equal(reloads, 1);
  assert.equal(draftClears, 1);
});

test('advancing a week uses the next schedule, never the displayed kickoff', async () => {
  const component = Object.create(poolComponentClass().prototype);
  let deadline;
  const current = { id: 'AFCU', week: 3, year: 2026, ownerId: 'owner', participants: [] };
  Object.assign(component, {
    poolId: signal('AFCU'), pool: signal(current), currentUser: signal({ uid: 'owner' }), route: {},
    gameService: { getWeekGames: async (week, year) => {
      assert.equal(week, 4); assert.equal(year, 2026);
      return [{ startTime: '2026-09-24T00:00:00Z' }, { startTime: '2026-09-27T00:00:00Z' }];
    } },
    dataService: {
      updateParticipants: async () => {},
      archiveAndAdvanceWeek: async (_, __, ___, lockAt) => { deadline = lockAt; },
    }, router: { navigate: async () => true },
  });
  await component.handleStartNextWeek();
  assert.equal(deadline, '2026-09-24T00:00:00.000Z');
});

test('late pool loads cannot replace a newer week or update a destroyed page', async () => {
  const component = Object.create(poolComponentClass().prototype);
  const pending = [];
  const query = signal('2');
  Object.assign(component, {
    poolId: signal('AFCU'), pool: signal(undefined), isCreatingPool: signal(false), loadError: signal(null),
    loadVersion: 0, destroyed: false, viewedWeek: signal(null),
    authService: { currentUser: () => ({ uid: 'member' }) },
    dataService: { getPool: () => new Promise(resolve => pending.push(resolve)) },
    gameService: { week: () => 3, year: () => 2026, LAST_REGULAR_SEASON_WEEK: 18 },
    route: { snapshot: { queryParamMap: { get: () => query() } } },
  });
  const older = component.loadPoolData();
  query.set('3');
  const newer = component.loadPoolData();
  pending[1]({ id: 'AFCU', year: 2026, week: 3, participants: [], name: 'new' });
  await newer;
  pending[0]({ id: 'AFCU', year: 2026, week: 2, participants: [], name: 'old' });
  await older;
  assert.equal(component.pool().name, 'new');
  const leaving = component.loadPoolData();
  component.destroyed = true;
  pending[2]({ id: 'AFCU', year: 2026, week: 3, participants: [] });
  await leaving;
  assert.equal(component.pool(), undefined);
});

test('simultaneous profile awards are serialized and known awards require no read', async () => {
  let stored = { uid: 'owner', displayName: 'John', unlockedAchievements: {}, joinedPools: {} };
  let reads = 0;
  const data = { getUser: async () => { reads++; return structuredClone(stored); }, updateUser: async user => { stored = structuredClone(user); } };
  const { AuthService } = loadSource('services/auth.service.ts', {
    '@angular/core': core, 'firebase/auth': {}, './achievement.service': {}, './data.service': {}, './firebase-client': {},
  });
  const auth = Object.create(AuthService.prototype);
  Object.assign(auth, { dataService: data, currentUser: signal(stored), profileWrites: Promise.resolve() });
  await Promise.all([
    auth.unlockAchievementForUser(stored, 'FIRST_DOWN'),
    auth.unlockAchievementForUser(stored, 'WELCOME_ABOARD'),
    auth.addPoolToJoinedList({ id: 'AFCU', name: 'AFCU' }),
  ]);
  assert.deepEqual(stored.unlockedAchievements, { FIRST_DOWN: true, WELCOME_ABOARD: true });
  assert.deepEqual(stored.joinedPools, { AFCU: 'AFCU' });
  const before = reads;
  const result = await auth.unlockAchievementForUser(stored, 'FIRST_DOWN');
  assert.equal(result.newlyAwarded, false);
  assert.equal(reads, before);
  assert.deepEqual(await auth.getJoinedPools(), [{ id: 'AFCU', name: 'AFCU' }]);
  assert.equal(reads, before, 'home menu uses the restored profile without rereading it');
});

test('pick form validates actual games, confidence range and integer tiebreaker', () => {
  const games = signal([{ id: 1, homeTeam: 'Home', awayTeam: 'Away' }]);
  const dependencies = {
    games: { games, year: () => 2026 },
    auth: { currentUser: () => ({ uid: 'owner' }) },
    teams: { getUnderdog: () => null },
  };
  const { PicksComponent } = loadSource('components/picks/picks.component.ts', {
    '@angular/core': {
      ...core, inject: token => dependencies[token], input: { required: () => signal(null) },
      output: () => ({ emit() {} }), effect() {},
    },
    '@angular/common': {}, '@angular/forms': {},
    '../../services/game.service': { GameService: 'games' },
    '../../services/team.service': { TeamService: 'teams' },
    '../../services/auth.service': { AuthService: 'auth' },
  });
  const form = new PicksComponent();
  form.tiebreaker.set(42);
  form.picks.set(new Map([[1, { winner: 'Home', confidence: 1 }]]));
  assert.equal(form.isFormValid(), true);
  assert.doesNotThrow(() => form.submitPicks(), 'emitting a submission must not delete the draft before it is accepted');
  for (const invalid of [42.5, -1, 501, null]) {
    form.tiebreaker.set(invalid);
    assert.equal(form.isFormValid(), false);
  }
  form.tiebreaker.set(42);
  for (const pick of [{ winner: 'Other', confidence: 1 }, { winner: 'Home', confidence: 2 }]) {
    form.picks.set(new Map([[1, pick]]));
    assert.equal(form.isFormValid(), false);
  }
  form.picks.set(new Map([[2, { winner: 'Home', confidence: 1 }]]));
  assert.equal(form.isFormValid(), false, 'outdated draft game IDs cannot be submitted');
  games.set([]);
  form.picks.set(new Map());
  assert.equal(form.isFormValid(), false);
});

test('history rankings use the designated game tiebreaker for equal scores', () => {
  const { scoreParticipants } = loadSource('services/pool-history.service.ts', {
    '@angular/core': core, './game.service': {},
  });
  const picks = [{ gameId: 1, winner: 'Home', confidence: 1 }];
  const scored = scoreParticipants([
    { userId: 'a', picks, tiebreaker: 60 }, { userId: 'b', picks, tiebreaker: 28 },
  ], [{ id: 1, winner: 'Home', status: 'final', isMondayNight: true, homeScore: 21, awayScore: 7 }]);
  assert.deepEqual(scored.map(p => p.userId), ['b', 'a']);
});
