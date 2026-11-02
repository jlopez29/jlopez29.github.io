import { describe, expect, it } from "vitest";
import { createWorld } from "../src/game/world";
import { distance, ground, radial, signedDistance } from "../src/game/geometry";
import { step } from "../src/game/simulation";
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
      const b = purchase(w, "collector", 1.18);
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
    const accessible = w.terrain.filter(
      (t) => t.stone > 0.1 && t.rock > 0.12,
    );
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

describe("V4 follower passing lanes", () => {
  it("separates oncoming people before crossing and restores the main path", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    w.settings.events = false;
    const [left, right] = w.followers;
    left.angle = 1.1;
    right.angle = 1.4;
    left.task = right.task = "wandering";
    left.facing = 1;
    right.facing = -1;
    let passing = false;
    let crossed = false;
    let minClearance = Infinity;
    for (let i = 0; i < 140; i++) {
      step(w, 0.05);
      if (left.lane || right.lane) {
        passing = true;
        const a = radial(left.angle, ground(w, left.angle) - left.lane);
        const b = radial(right.angle, ground(w, right.angle) - right.lane);
        minClearance = Math.min(
          minClearance,
          Math.hypot(a.x - b.x, a.y - b.y),
        );
      }
      crossed ||= signedDistance(left.angle, right.angle) > 0;
    }
    expect(passing).toBe(true);
    expect(crossed).toBe(true);
    expect(minClearance).toBeGreaterThan(30);
    expect(distance(left.angle, right.angle) * w.radius).toBeGreaterThan(100);
    expect(left.lane).toBe(0);
    expect(right.lane).toBe(0);
  });

  it("routes a walker around a stationary person rather than through them", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    const [parked, walker] = w.followers;
    parked.angle = 1;
    parked.task = "observing";
    parked.timer = 20;
    walker.angle = 1.22;
    walker.task = "wandering";
    walker.facing = -1;
    let passed = false;
    for (let i = 0; i < 110; i++) {
      step(w, 0.05);
      if (walker.angle < parked.angle) passed = true;
      if (distance(parked.angle, walker.angle) * w.radius < 28) {
        expect(walker.lane).toBeGreaterThanOrEqual(45);
      }
    }
    expect(passed).toBe(true);
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
