import { describe, expect, it } from "vitest";
import { createWorld, addFollower } from "../src/game/world";
import { assign, grab, slotAngle, step } from "../src/game/simulation";
import { deform, distance, ground } from "../src/game/geometry";
import { deserialize, serialize } from "../src/persistence/database";
const advance = (w: ReturnType<typeof createWorld>, seconds: number) => {
  for (let t = 0; t < seconds; t += 0.05) step(w, 0.05);
};
describe("A: inhabitants and reservations", () => {
  it("reserves three distinct curved shrine positions and rejects a fourth", () => {
    const w = createWorld();
    const b = w.buildings[0];
    while (w.followers.length < 4)
      addFollower(w, 0.1 + w.followers.length * 0.08, 80);
    w.followers[0].faith = 80;
    w.followers.slice(0, 3).forEach((f) => {
      const before = f.angle;
      expect(assign(w, f.id, b.id)).toBeNull();
      expect(f.angle).toBe(before);
      expect(f.task).toBe("traveling");
    });
    expect(new Set(w.followers.slice(0, 3).map((f) => f.slot)).size).toBe(3);
    expect(assign(w, w.followers[3].id, b.id)).toContain("full");
    w.mana = 0;
    advance(w, 30);
    w.followers.slice(0, 3).forEach((f) => {
      expect(f.task).toBe("worshipping");
      expect(
        distance(f.angle, slotAngle(w, b, f.slot!)) * w.radius,
      ).toBeLessThan(1);
    });
    expect(w.stats.worship).toBeGreaterThan(20);
    expect(w.mana).toBeGreaterThan(2);
    const restored = deserialize(serialize(w));
    expect(restored.followers.map((f) => f.slot)).toEqual(
      w.followers.map((f) => f.slot),
    );
    grab(w, w.followers[0].id);
    expect(w.followers[0].slot).toBe(0);
    expect(assign(w, w.followers[3].id, b.id)).toContain("full");
    const carriedAngle = w.followers[0].angle;
    advance(w, 2);
    expect(w.followers[0].angle).toBe(carriedAngle);
  });
  it("takes the short path across zero and follows deformed ground", () => {
    const w = createWorld();
    const f = w.followers[0],
      b = w.buildings[0];
    b.angle = 0.1;
    f.angle = 6.2;
    f.faith = 80;
    assign(w, f.id, b.id);
    const start = f.angle;
    step(w, 0.05);
    expect(distance(f.angle, start) * w.radius).toBeLessThan(3);
    advance(w, 10);
    expect(f.task).toBe("worshipping");
    const before = ground(w, f.angle);
    deform(w, f.angle, 25);
    expect(ground(w, f.angle)).toBeGreaterThan(before + 20);
    expect(f.slot).toBe(0);
  });
});

describe("B: compact planets and safe expansion", () => {
  it("starts at 54 percent of the old radius with nearby ecological zones", () => {
    const w = createWorld();
    expect(w.radius / 850).toBeGreaterThan(0.45);
    expect(w.radius / 850).toBeLessThan(0.6);
    expect(w.followers).toHaveLength(2);
    expect(
      w.terrain.some(
        (t, i) => t.vegetation > 0.8 && (i / 512) * Math.PI * 2 < 1,
      ),
    ).toBe(true);
    expect(w.terrain.some((t) => t.rock > 0.75)).toBe(true);
  });
  it("grows continuously while preserving entities, deformations, and dimensions", async () => {
    const { expand } = await import("../src/game/simulation");
    const w = createWorld();
    const ids = w.followers.map((f) => f.id),
      b = w.buildings[0];
    deform(w, 2, 25);
    const heights = w.terrain.map((t) => t.height);
    w.rune = true;
    expand(w);
    expect(w.radius).toBe(460);
    expect(w.targetRadius).toBe(555);
    advance(w, 6);
    expect(w.radius).toBe(555);
    expect(w.buildings[0]).toBe(b);
    expect(w.followers.slice(0, 2).map((f) => f.id)).toEqual(ids);
    expect(w.terrain.map((t) => t.height)).toEqual(heights);
    expect(deserialize(serialize(w)).radius).toBe(555);
  });
  it("migrates v1 without shrinking or deleting a legacy world", () => {
    const old = JSON.parse(serialize(createWorld()));
    old.version = 1;
    old.radius = 850;
    delete old.targetRadius;
    old.followers.forEach((f: any) => {
      delete f.slot;
      delete f.lane;
      delete f.facing;
      f.assigned = old.buildings[0].id;
    });
    const w = deserialize(JSON.stringify(old));
    expect(w.version).toBe(2);
    expect(w.legacy).toBe(true);
    expect(w.radius).toBe(850);
    expect(w.followers).toHaveLength(2);
    expect(new Set(w.followers.map((f) => f.slot)).size).toBe(2);
  });
});

describe("C: landscape economy", () => {
  it("deducts complete recipes atomically and rejects missing materials", async () => {
    const { purchase } = await import("../src/game/simulation");
    const w = createWorld();
    let b = purchase(w, "logging", 0.72);
    expect(typeof b).toBe("object");
    expect(w.gold).toBe(205);
    expect(w.resources.wood).toBe(5);
    expect(w.resources.stone).toBe(3);
    w.resources.wood = 0;
    const before = w.gold;
    expect(purchase(w, "farm", 0.25)).toContain("wood");
    expect(w.gold).toBe(before);
    expect(w.resources.wood).toBe(0);
  });
  it("harvests finite forests and cannot produce on barren land", async () => {
    const { purchase } = await import("../src/game/simulation");
    const { materialProduction } = await import("../src/game/economy");
    const w = createWorld();
    const b = purchase(w, "logging", 0.72);
    if (typeof b === "string") throw Error(b);
    b.construction = 1;
    const f = w.followers[1];
    const stock = w.terrain.reduce((n, t) => n + t.wood, 0);
    for (let i = 0; i < 40; i++) materialProduction(w, b, [f], 1);
    expect(w.resources.wood).toBeGreaterThan(5);
    expect(w.terrain.reduce((n, t) => n + t.wood, 0)).toBeLessThan(stock);
    w.terrain.forEach((t) => {
      t.wood = 0;
      t.vegetation = 0;
    });
    const before = w.resources.wood;
    materialProduction(w, b, [f], 100);
    expect(w.resources.wood).toBe(before);
  });
  it("rain sustains measurable forest regeneration and replanting repairs depletion", async () => {
    const { environmentEconomy, replant } = await import("../src/game/economy");
    const { cast } = await import("../src/game/simulation");
    const w = createWorld();
    w.terrain.forEach((t) => {
      t.moisture = 0.05;
      t.wood = 0;
      t.vegetation = 0.05;
    });
    environmentEconomy(w, 60);
    expect(w.terrain.reduce((n, t) => n + t.wood, 0)).toBe(0);
    replant(w);
    cast(w, "rain", 0.72);
    environmentEconomy(w, 120);
    expect(w.terrain.reduce((n, t) => n + t.wood, 0)).toBeGreaterThan(0);
    expect(w.terrain.some((t) => t.vegetation > 0.3)).toBe(true);
  });
  it("stone requires deposits and declines as it is extracted", async () => {
    const { purchase } = await import("../src/game/simulation");
    const { materialProduction } = await import("../src/game/economy");
    const w = createWorld();
    w.level = 2;
    const b = purchase(w, "mine", -0.86);
    if (typeof b === "string") throw Error(b);
    b.construction = 1;
    const stock = w.terrain.reduce((n, t) => n + t.stone, 0);
    materialProduction(w, b, [w.followers[1]], 60);
    expect(w.resources.stone).toBeGreaterThan(1);
    expect(w.terrain.reduce((n, t) => n + t.stone, 0)).toBeLessThan(stock);
    w.terrain.forEach((t) => {
      t.stone = 0;
      t.rock = 0;
    });
    const before = w.resources.stone;
    materialProduction(w, b, [w.followers[1]], 100);
    expect(w.resources.stone).toBe(before);
  });
  it("manual gathering rescues an empty inventory and salvage returns materials", async () => {
    const { gather, salvage } = await import("../src/game/economy");
    const w = createWorld();
    w.resources.wood = 0;
    expect(gather(w, "wood", 0.72)).toBeNull();
    expect(w.resources.wood).toBe(1);
    expect(gather(w, "wood", 0.72)).toContain("again");
    const gold = w.gold;
    salvage(w, w.buildings[0]);
    expect(w.gold).toBeGreaterThan(gold);
    expect(w.resources.wood).toBe(5);
  });
});

describe("D: food, water, autonomy, and progression", () => {
  it("collects only local rainfall or finite pond water, never moisture alone", async () => {
    const { purchase, cast } = await import("../src/game/simulation");
    const { materialProduction } = await import("../src/game/economy");
    const w = createWorld();
    const b = purchase(w, "collector", 0.25);
    if (typeof b === "string") throw Error(b);
    b.construction = 1;
    const before = w.resources.water;
    w.terrain.forEach((t) => (t.moisture = 1));
    materialProduction(w, b, [], 300);
    expect(w.resources.water).toBe(before);
    cast(w, "rain", 2);
    expect(w.resources.water).toBe(before);
    cast(w, "rain", b.angle);
    expect(w.resources.water).toBeGreaterThan(before);
    const t = w.terrain[Math.floor((b.angle / (Math.PI * 2)) * 512)];
    t.water = 2;
    const water = w.resources.water;
    materialProduction(w, b, [], 10);
    expect(w.resources.water).toBeGreaterThan(water);
    expect(t.water).toBeLessThan(2);
  });
  it("farms turn stored water into food; dry infertile farms produce less", async () => {
    const { purchase } = await import("../src/game/simulation");
    const { materialProduction } = await import("../src/game/economy");
    const wet = createWorld(),
      dry = createWorld();
    const run = (w: ReturnType<typeof createWorld>, fertile: boolean) => {
      const b = purchase(w, "farm", 0.3);
      if (typeof b === "string") throw Error(b);
      b.construction = 1;
      w.terrain.forEach((t) => (t.fertility = fertile ? 1 : 0.1));
      w.resources.water = fertile ? 5 : 0;
      for (let i = 0; i < 90; i++)
        materialProduction(w, b, [w.followers[1]], 1);
      return w.resources.food;
    };
    expect(run(wet, true)).toBeGreaterThan(run(dry, false));
    expect(wet.resources.water).toBeLessThan(5);
    expect(dry.resources.water).toBe(0);
  });
  it("hungry workers reserve no stale slot, eat, and return to their work", () => {
    const w = createWorld();
    const f = w.followers[1];
    assign(w, f.id, w.buildings[0].id);
    advance(w, 10);
    f.hunger = 60;
    const food = w.resources.food;
    step(w, 0.05);
    expect(f.task).toBe("seekingResources");
    expect(f.slot).toBeNull();
    advance(w, 30);
    expect(f.hunger).toBeLessThan(5);
    expect(w.resources.food).toBeLessThan(food);
    expect(f.assigned).toBe(w.buildings[0].id);
    expect(f.task).toBe("worshipping");
  });
  it("exhausted workers recover in a tent and resume their original work", async () => {
    const { purchase } = await import("../src/game/simulation");
    const w = createWorld();
    const b = purchase(w, "tent", -0.8);
    if (typeof b === "string") throw Error(b);
    b.construction = 1;
    const f = w.followers[1];
    assign(w, f.id, w.buildings[0].id);
    advance(w, 10);
    f.energy = 5;
    advance(w, 5);
    expect(f.returnTo).toBe(w.buildings[0].id);
    expect(f.assigned).toBe(b.id);
    advance(w, 65);
    expect(f.assigned).toBe(w.buildings[0].id);
    expect(f.task).toBe("worshipping");
    expect(f.energy).toBeGreaterThan(85);
  });
  it("food shortages are gradual and never produce negative inventories", () => {
    const w = createWorld();
    w.resources.food = 0;
    w.followers.forEach((f) => (f.hunger = 90));
    w.settings.events = false;
    advance(w, 120);
    expect(w.followers.every((f) => f.alive)).toBe(true);
    expect(w.resources.food).toBe(0);
    expect(w.followers[0].happiness).toBeLessThan(70);
  });
  it("food supports population growth and visitors wait safely without it", async () => {
    const { gainXP } = await import("../src/game/simulation");
    const w = createWorld();
    w.resources.food = 0;
    gainXP(w, 100);
    expect(w.followers).toHaveLength(2);
    expect(w.waitingFollowers).toBe(1);
    w.resources.food = 3;
    advance(w, 1.1);
    expect(w.followers).toHaveLength(3);
    expect(w.waitingFollowers).toBe(0);
    expect(w.resources.food).toBe(1);
  });
});

describe("crowd and persistence edge cases", () => {
  it("lands only the dragged follower in a free location", async () => {
    const { landFollower } = await import("../src/game/simulation");
    const w = createWorld();
    const first = w.followers[0],
      other = w.followers[1];
    const angle = other.angle;
    grab(w, first.id);
    landFollower(w, first.id, angle);
    expect(other.angle).toBe(angle);
    expect(
      distance(first.angle, other.angle) * w.radius,
    ).toBeGreaterThanOrEqual(25);
    expect(first.task).toBe("wandering");
    expect(first.slot).toBeNull();
  });
  it("keeps multiple earned expansion runes claimable", async () => {
    const { gainXP, expand } = await import("../src/game/simulation");
    const w = createWorld();
    w.resources.food = 100;
    gainXP(w, 5000);
    const count = [3, 6, 10, 15].filter((n) => n <= w.level).length;
    for (let i = 0; i < count; i++) {
      expect(w.rune).toBe(true);
      expand(w);
    }
    expect(w.rune).toBe(false);
    expect(w.expansions).toBe(count);
    expect(deserialize(serialize(w)).targetRadius).toBe(w.targetRadius);
  });
  it("rejects corrupt inventories and preserves valid resource data exactly", () => {
    const w = createWorld();
    w.resources.water = 2.125;
    expect(deserialize(serialize(w)).resources.water).toBe(2.125);
    const bad = JSON.parse(serialize(w));
    bad.resources.wood = -1;
    expect(() => deserialize(JSON.stringify(bad))).toThrow("inventory");
    bad.resources.wood = 8;
    bad.followers[1].id = bad.followers[0].id;
    expect(() => deserialize(JSON.stringify(bad))).toThrow("identifiers");
  });
});

describe("approachable early game", () => {
  it("reaches real logging, watered food, gold, and the first expansion without gifted resources", async () => {
    const { cast, purchase, collect, expand } =
      await import("../src/game/simulation");
    const { gather } = await import("../src/game/economy");
    const w = createWorld();
    w.settings.events = false;
    expect(cast(w, "rain", w.followers[0].angle)).toBeNull();
    expect(assign(w, w.followers[0].id, w.buildings[0].id)).toBeNull();
    advance(w, 22);
    expect(w.stats.worship).toBeGreaterThan(10);
    expect(cast(w, "rain", 0.72)).toBeNull();
    expect(gather(w, "wood", 0.72)).toBeNull();
    const camp = purchase(w, "logging", 0.72);
    if (typeof camp === "string") throw Error(camp);
    assign(w, w.followers[1].id, camp.id);
    advance(w, 60);
    expect(w.stats.loggedWood).toBeGreaterThanOrEqual(3);
    const farm = purchase(w, "farm", 0.25);
    if (typeof farm === "string") throw Error(farm);
    assign(w, w.followers[0].id, farm.id);
    expect(cast(w, "rain", farm.angle)).toBeNull();
    advance(w, 65);
    expect(w.stats.farmedFood).toBeGreaterThanOrEqual(5);
    expect(w.consumed.water).toBeGreaterThan(0);
    expect(collect(w, farm.id)).toBeGreaterThan(0);
    expect(w.level).toBeGreaterThanOrEqual(3);
    expect(w.rune).toBe(true);
    expand(w);
    advance(w, 6);
    expect(w.radius).toBe(555);
    expect(w.time).toBeLessThan(180);
    expect(Object.values(w.resources).every((n) => n >= 0)).toBe(true);
  });
});
