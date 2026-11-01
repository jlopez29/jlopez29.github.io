import { describe, expect, it } from "vitest";
import { createWorld } from "../src/game/world";
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
