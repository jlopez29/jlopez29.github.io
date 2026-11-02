import { describe, expect, it } from "vitest";
import { createWorld } from "../src/game/world";
import { distance, signedDistance, wrap } from "../src/game/geometry";
import { assign, slotAngle, step } from "../src/game/simulation";
import { redistributeWater } from "../src/game/geometry";
import { materialProduction } from "../src/game/economy";
import { cast, offline, purchase } from "../src/game/simulation";

describe("V4 environmental consistency and rewards", () => {
  it("moves water downhill, conserving the volume while filling neighboring valley samples", () => {
    const w = createWorld();
    w.terrain.forEach((t) => {
      t.height = 30;
      t.water = 0;
    });
    for (let i = 250; i <= 260; i++) w.terrain[i].height = -25;
    w.terrain[255].water = 20;
    const before = w.terrain.reduce((sum, t) => sum + t.water, 0);
    redistributeWater(w, 8);
    const after = w.terrain.reduce((sum, t) => sum + t.water, 0);
    expect(after).toBeCloseTo(before, 6);
    expect(w.terrain[256].water).toBeGreaterThan(0);
  });

  it("makes a rain-charged farm grow substantially faster", () => {
    const run = (charged: boolean) => {
      const w = createWorld();
      const b = purchase(w, "farm", 0.3);
      if (typeof b === "string") throw Error(b);
      b.construction = 1;
      b.charge = charged ? 180 : 0;
      materialProduction(w, b, [w.followers[1]], 10);
      return b.progress;
    };
    expect(run(true)).toBeGreaterThan(run(false) * 2);
  });

  it("keeps passive water collection but rewards assigning a worker", () => {
    const run = (staffed: boolean) => {
      const w = createWorld();
      const b = purchase(w, "collector", 1.0);
      if (typeof b === "string") throw Error(b);
      b.construction = 1;
      const start = w.resources.water;
      materialProduction(w, b, staffed ? [w.followers[1]] : [], 10);
      return w.resources.water - start;
    };
    expect(run(true)).toBeGreaterThan(run(false) * 3);
  });

  it("lightning exposes stone without making the remaining deposit unmineable", () => {
    const w = createWorld();
    w.level = 3;
    w.mana = 10;
    expect(cast(w, "lightning", -0.86)).toBeNull();
    expect(w.resources.stone).toBeGreaterThan(3);
    const accessible = w.terrain.filter((t) => t.stone > 0.1 && t.rock > 0.12);
    expect(accessible.length).toBeGreaterThan(0);
  });

  it("lets healthy workers produce while a coworker is exhausted offline", () => {
    const w = createWorld();
    const b = purchase(w, "farm", 0.3);
    if (typeof b === "string") throw Error(b);
    b.construction = 1;
    b.charge = 180;
    w.followers[0].assigned = b.id;
    w.followers[0].task = "working";
    w.followers[0].energy = 2;
    w.followers[1].assigned = b.id;
    w.followers[1].task = "working";
    w.followers[1].energy = 100;
    const before = w.resources.food;
    offline(w, 100);
    expect(w.resources.food).toBeGreaterThan(before);
    expect(w.followers[0].energy).toBeGreaterThanOrEqual(1);
  });
});

describe("follower surface crossing", () => {
  it.each([1, -1])(
    "walks through a stationary follower in direction %s",
    (direction) => {
      const w = createWorld();
      w.settings.autonomy = false;
      w.settings.events = false;
      const [parked, walker] = w.followers;
      parked.angle = 0;
      parked.task = "observing";
      parked.timer = 20;
      walker.angle = wrap(-direction * 0.08);
      // Wandering direction is derived from world time and appearance.
      walker.appearance = direction > 0 ? 0 : 1;
      walker.lane = 36; // A save from the old passing-lane build.
      const original = parked.angle;
      let crossed = false;
      let closest = Infinity;
      for (let i = 0; i < 100; i++) {
        step(w, 0.05);
        closest = Math.min(
          closest,
          distance(walker.angle, parked.angle) * w.radius,
        );
        crossed ||= signedDistance(walker.angle, parked.angle) * direction > 0;
        expect(walker.lane).toBe(0);
        expect(parked.angle).toBe(original);
        expect(parked.lane).toBe(0);
      }
      expect(crossed).toBe(true);
      expect(closest).toBeLessThan(1);
    },
  );

  it("lets oncoming followers cross without offsets or blocking", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    w.settings.events = false;
    const [left, right] = w.followers;
    left.angle = 0.5;
    right.angle = 0.7;
    left.appearance = 0;
    right.appearance = 1;
    let closest = Infinity;
    for (let i = 0; i < 100; i++) {
      step(w, 0.05);
      closest = Math.min(closest, distance(left.angle, right.angle) * w.radius);
      expect(left.lane).toBe(0);
      expect(right.lane).toBe(0);
    }
    expect(signedDistance(left.angle, right.angle)).toBeGreaterThan(0);
    expect(closest).toBeLessThan(1);
  });

  it("lets a faster walker overtake without tailgating", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    w.settings.events = false;
    const [slow, fast] = w.followers;
    slow.angle = 0.6;
    fast.angle = 0.55;
    slow.appearance = fast.appearance = 0;
    slow.speed = 0.01;
    fast.speed = 0.04;
    for (let i = 0; i < 80; i++) {
      step(w, 0.05);
      expect(slow.lane).toBe(0);
      expect(fast.lane).toBe(0);
    }
    expect(signedDistance(fast.angle, slow.angle)).toBeGreaterThan(0);
  });

  it("reaches a reserved job slot through a stationary follower", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    w.settings.events = false;
    const [parked, worker] = w.followers;
    const b = w.buildings[0];
    worker.faith = 80;
    expect(assign(w, worker.id, b.id)).toBeNull();
    const target = slotAngle(w, b, worker.slot!);
    worker.angle = wrap(target + 0.2);
    parked.angle = wrap(target + 0.1);
    parked.task = "observing";
    parked.timer = 20;
    for (let i = 0; i < 120; i++) step(w, 0.05);
    expect(distance(worker.angle, target) * w.radius).toBeLessThan(0.5);
    expect(worker.task).toBe("worshipping");
    expect(worker.lane).toBe(0);
    expect(parked.angle).toBe(wrap(target + 0.1));
  });
});

describe("V4.3 stationary follower grounding", () => {
  it("clears a stranded passing lane when a follower stops to observe", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    const follower = w.followers[1];
    follower.task = "observing";
    follower.timer = 4;
    follower.lane = 36;
    const originalAngle = follower.angle;
    step(w, 0.05);
    expect(follower.lane).toBe(0);
    expect(follower.angle).toBe(originalAngle);
    expect(follower.task).toBe("observing");
  });

  it("does not keep a passing lane when a worker starts resting", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    const follower = w.followers[1];
    follower.task = "resting";
    follower.timer = 3;
    follower.lane = 36;
    step(w, 0.05);
    expect(follower.lane).toBe(0);
  });
});
