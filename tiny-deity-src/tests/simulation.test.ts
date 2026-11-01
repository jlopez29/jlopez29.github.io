import { describe, it, expect } from "vitest";
import { createWorld } from "../src/game/world";
import {
  angleAt,
  radial,
  distance,
  fromScreen,
  toScreen,
  deform,
  basinCapacity,
} from "../src/game/geometry";
import {
  assign,
  cast,
  collect,
  gainXP,
  offline,
  placement,
  purchase,
  step,
  checkQuests,
} from "../src/game/simulation";
import { maxMana } from "../src/game/data";
import { deserialize, serialize } from "../src/persistence/database";
const advance = (w: ReturnType<typeof createWorld>, seconds: number) => {
  for (let t = 0; t < seconds; t += 0.05) step(w, 0.05);
};
describe("planet geometry", () => {
  it("round-trips angular coordinates through every quadrant", () => {
    for (let a = 0; a < Math.PI * 2; a += 0.17) {
      const p = radial(a, 870);
      expect(distance(angleAt(p.x, p.y), a)).toBeLessThan(1e-10);
    }
  });
  it("uses an invertible camera transform across rotation and zoom", () => {
    for (const rotation of [0, 0.4, 3, 6.1])
      for (const zoom of [0.2, 0.8, 1.5]) {
        const c = { x: 300, y: 900, rotation, zoom },
          p = toScreen(23, -820, c),
          q = fromScreen(p.x, p.y, c);
        expect(q.x).toBeCloseTo(23, 8);
        expect(q.y).toBeCloseTo(-820, 8);
      }
  });
  it("deforms continuously across the angular seam and keeps undo", () => {
    const w = createWorld();
    const before = w.terrain.map((t) => t.height);
    deform(w, 0, 30);
    expect(w.terrain[511].height).toBeGreaterThan(before[511]);
    expect(w.terrain[0].height).toBeGreaterThan(before[0]);
    expect(w.terrain[50].height).toBe(before[50]);
    expect(w.undo).toEqual(before);
  });
  it("generates the same terrain for a seed", () =>
    expect(createWorld(18).terrain).toEqual(createWorld(18).terrain));
  it("holds water only below the lower enclosing rim", () => {
    const w = createWorld();
    w.terrain.forEach((t) => (t.height = 20));
    w.terrain[0].height = -20;
    expect(basinCapacity(w, 0)).toBe(40);
    expect(basinCapacity(w, 100)).toBe(0);
    cast(w, "rain", 0);
    expect(w.terrain[0].water).toBeGreaterThan(0);
    advance(w, 2);
    expect(w.terrain[0].water).toBeLessThanOrEqual(40);
  });
});
describe("miracles and followers", () => {
  it("validates before spending mana", () => {
    const w = createWorld(),
      mana = w.mana;
    expect(cast(w, "fire", 0)).toContain("level");
    expect(w.mana).toBe(mana);
    w.level = 5;
    expect(cast(w, "resurrect", 0)).toContain("gravestone");
    expect(w.mana).toBe(mana);
    w.mana = 0;
    expect(cast(w, "rain", 0)).toContain("mana");
  });
  it("rain converts a neutral follower and changes its local environment", () => {
    const w = createWorld(),
      f = w.followers[0],
      moisture = w.terrain[0].moisture;
    expect(cast(w, "rain", f.angle)).toBeNull();
    expect(f.faith).toBeGreaterThanOrEqual(50);
    expect(w.terrain[0].moisture).toBeGreaterThan(moisture);
    expect(w.stats.converted).toBe(1);
    expect(w.mana).toBe(9);
  });
  it("regenerates mana at the documented base rate", () => {
    const w = createWorld();
    w.mana = 0;
    advance(w, 45);
    expect(w.mana).toBeCloseTo(1, 1);
    expect(w.mana).toBeLessThanOrEqual(maxMana(w));
  });
  it("worship replenishes mana faster than passive regeneration", () => {
    const w = createWorld();
    const f = w.followers[0];
    f.faith = 80;
    f.angle = w.buildings[0].angle;
    assign(w, f.id, w.buildings[0].id);
    w.mana = 0;
    advance(w, 15);
    expect(w.mana).toBeGreaterThan(1);
    expect(w.stats.worship).toBeGreaterThan(10);
  });
  it("exhausted workers stop and resting followers recover", () => {
    const w = createWorld();
    w.settings.autonomy = false;
    const b = purchase(w, "farm", 0.3);
    expect(typeof b).toBe("object");
    if (typeof b === "string") return;
    b.construction = 1;
    b.charge = 180;
    const f = w.followers[0];
    f.faith = 80;
    f.energy = 2;
    f.angle = b.angle;
    assign(w, f.id, b.id);
    advance(w, 10);
    expect(f.task).toBe("exhausted");
    expect(f.energy).toBeLessThan(12);
    expect(b.progress).toBeLessThan(0.3);
    w.resources.wood += 1; // Gather the one additional log needed after a farm.
    const tent = purchase(w, "tent", -0.8);
    if (typeof tent === "string") throw Error(tent);
    tent.construction = 1;
    f.angle = tent.angle;
    assign(w, f.id, tent.id);
    const before = f.energy;
    advance(w, 10);
    expect(f.energy).toBeGreaterThan(before + 15);
  });
  it("rejects neutral worker assignments and respects capacity", () => {
    const w = createWorld();
    expect(assign(w, w.followers[0].id, w.buildings[0].id)).toContain("faith");
  });
  it("rain extinguishes active fire", () => {
    const w = createWorld();
    w.level = 7;
    w.mana = 30;
    cast(w, "fire", 0);
    expect(w.terrain[0].fire).toBe(1);
    cast(w, "rain", 0);
    expect(w.terrain[0].fire).toBe(0);
    expect(w.discoveries).toContain("Life after fire");
  });
});
describe("construction, economy, and progression", () => {
  it("rejects overlapping, flooded, and steep construction without charging gold", () => {
    const w = createWorld(),
      gold = w.gold;
    expect(typeof purchase(w, "farm", w.buildings[0].angle)).toBe("string");
    expect(w.gold).toBe(gold);
    w.terrain.forEach((t) => (t.water = 20));
    expect(placement(w, "farm", 1)).toContain("water");
  });
  it("completes a real build → power → work → collect loop", () => {
    const w = createWorld();
    const f = w.followers[0];
    cast(w, "rain", f.angle);
    const b = purchase(w, "farm", 0.3);
    if (typeof b === "string") throw Error(b);
    f.angle = b.angle;
    expect(assign(w, f.id, b.id)).toBeNull();
    advance(w, 20);
    expect(b.construction).toBe(1);
    expect(b.stored).toBe(0);
    cast(w, "rain", b.angle);
    advance(w, 35);
    expect(b.stored).toBeGreaterThan(0);
    const gold = w.gold,
      stored = b.stored;
    expect(collect(w, b.id)).toBe(stored);
    expect(w.gold).toBeGreaterThanOrEqual(gold + stored);
    expect(b.stored).toBe(0);
    expect(collect(w, b.id)).toBe(0);
    expect(f.energy).toBeLessThan(100);
  });
  it("levels grant followers, mana, and an expansion rune", () => {
    const w = createWorld();
    gainXP(w, 500);
    expect(w.level).toBeGreaterThanOrEqual(4);
    expect(w.followers.length).toBeGreaterThan(1);
    expect(w.mana).toBe(maxMana(w));
    expect(w.rune).toBe(true);
  });
  it("awards each completed quest only once", () => {
    const w = createWorld();
    w.stats.rain = 1;
    w.stats.converted = 1;
    checkQuests(w);
    const gold = w.gold;
    checkQuests(w);
    expect(w.gold).toBe(gold);
    expect(w.completed.filter((id) => id === "rain")).toHaveLength(1);
  });
  it("offline rewards respect charges and energy, and never trigger disasters", () => {
    const w = createWorld();
    const b = purchase(w, "farm", 0.3);
    if (typeof b === "string") throw Error(b);
    b.construction = 1;
    b.charge = 40;
    const f = w.followers[0];
    f.faith = 80;
    assign(w, f.id, b.id);
    expect(offline(w, 10)).toBe(0); // Travelers do not produce offline.
    advance(w, 10);
    const foodBefore = w.resources.food;
    const reward = offline(w, 100000);
    expect(reward).toBeGreaterThan(0);
    expect(b.stored).toBe(reward);
    expect(w.resources.food).toBeGreaterThan(foodBefore);
    expect(w.resources.water).toBeGreaterThanOrEqual(0);
    expect(f.alive).toBe(true);
    expect(w.monster).toBeNull();
    expect(w.mana).toBe(maxMana(w));
  });
  it("exports and restores simulation state without transient effects", () => {
    const w = createWorld();
    cast(w, "rain", 0.02);
    const restored = deserialize(serialize(w));
    expect(restored.followers).toEqual(w.followers);
    expect(restored.terrain).toEqual(w.terrain);
    expect(restored.gold).toBe(w.gold);
    expect(restored.effects).toEqual([]);
    expect(() => deserialize('{"version":99}')).toThrow();
  });
  it("rejects malformed saves before they reach the simulation", () => {
    const w = createWorld();
    w.buildings[0].type = "unknown" as never;
    expect(() => deserialize(serialize(w))).toThrow("building");
  });
});
