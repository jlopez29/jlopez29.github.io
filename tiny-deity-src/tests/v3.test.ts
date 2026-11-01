import { describe, expect, it } from "vitest";
import { createWorld, addFollower } from "../src/game/world";
import {
  assign,
  grab,
  releaseCarried,
  landFollower,
  purchase,
  step,
  slotAngle,
} from "../src/game/simulation";
import { deform, distance } from "../src/game/geometry";
import { deserialize, serialize } from "../src/persistence/database";
import { POWERS } from "../src/game/data";
const advance = (w: ReturnType<typeof createWorld>, seconds: number) => {
  for (let t = 0; t < seconds; t += 0.05) step(w, 0.05);
};
describe("V3 world interaction and autonomy", () => {
  it("unlocks basic sculpting immediately and retains one snapshot through many dabs", () => {
    const w = createWorld();
    expect(POWERS.raise.level).toBe(1);
    expect(POWERS.lower.level).toBe(1);
    const before = w.terrain.map((t) => t.height);
    w.undo = [...before];
    for (let i = 0; i < 30; i++) deform(w, i * 0.003, 2, false, 0.14, false);
    expect(w.undo).toEqual(before);
    expect(w.terrain[2].height).toBeGreaterThan(before[2] + 20);
    expect(
      Math.max(
        ...w.terrain.map((t, i) =>
          Math.abs(t.height - w.terrain[(i + 1) % 512].height),
        ),
      ),
    ).toBeLessThan(15);
  });
  it("canceling a pickup restores a reserved job; an intentional land drop releases it", () => {
    const w = createWorld(),
      f = w.followers[1],
      b = w.buildings[0];
    assign(w, f.id, b.id);
    const slot = f.slot,
      angle = f.angle;
    grab(w, f.id);
    expect(f.task).toBe("carried");
    expect(f.assigned).toBe(b.id);
    releaseCarried(w);
    expect(f.task).toBe("traveling");
    expect(f.slot).toBe(slot);
    expect(f.angle).toBe(angle);
    grab(w, f.id);
    landFollower(w, f.id, 1);
    expect(f.assigned).toBeNull();
    expect(f.angle).toBeCloseTo(1);
    expect(f.jobCooldown).toBeGreaterThan(0);
  });
  it("canceling pickup during a food trip preserves the need and return job", () => {
    const w = createWorld(),
      f = w.followers[1];
    assign(w, f.id, w.buildings[0].id);
    f.hunger = 60;
    step(w, 0.05);
    expect(f.task).toBe("seekingResources");
    const previous = f.returnTo;
    grab(w, f.id);
    releaseCarried(w);
    expect(f.task).toBe("seekingResources");
    expect(f.returnTo).toBe(previous);
    advance(w, 40);
    expect(f.hunger).toBeLessThan(5);
    expect(f.assigned).toBe(w.buildings[0].id);
  });
  it("automatically reserves capacity, walks to separate slots, and keeps jobs stable", () => {
    const w = createWorld();
    while (w.followers.length < 5)
      addFollower(w, 0.2 + w.followers.length * 0.1, 80);
    w.followers.forEach((f) => (f.faith = 80));
    step(w, 0.05);
    const workers = w.followers.filter((f) => f.assigned);
    expect(workers).toHaveLength(3);
    expect(new Set(workers.map((f) => f.slot)).size).toBe(3);
    expect(workers.every((f) => f.task === "traveling")).toBe(true);
    advance(w, 40);
    workers.forEach((f) => {
      expect(f.task).toBe("worshipping");
      expect(
        distance(f.angle, slotAngle(w, w.buildings[0], f.slot!)) * w.radius,
      ).toBeLessThan(1);
    });
    const reservations = workers.map((f) => [f.assigned, f.slot]);
    advance(w, 20);
    expect(workers.map((f) => [f.assigned, f.slot])).toEqual(reservations);
  });
  it("automatic workers leave worship to construct while manual workers retain their task", () => {
    const w = createWorld();
    w.followers[0].faith = 80;
    assign(w, w.followers[0].id, w.buildings[0].id);
    advance(w, 5);
    const b = purchase(w, "logging", 0.72);
    if (typeof b === "string") throw Error(b);
    advance(w, 70);
    expect(b.construction).toBe(1);
    expect(w.followers[0].assigned).toBe(w.buildings[0].id);
    expect(w.followers[0].manual).toBe(true);
    expect(w.followers[1].assigned).toBe(b.id);
  });
  it("exhausted workers rest and return to the manual job without teleporting", () => {
    const w = createWorld();
    const tent = purchase(w, "tent", 0.5);
    if (typeof tent === "string") throw Error(tent);
    tent.construction = 1;
    const f = w.followers[1],
      shrine = w.buildings[0];
    assign(w, f.id, shrine.id);
    advance(w, 20);
    f.energy = 7;
    const before = f.angle;
    step(w, 0.05);
    expect(f.assigned).toBe(tent.id);
    expect(f.angle).toBe(before);
    expect(f.returnTo).toBe(shrine.id);
    advance(w, 170);
    expect(f.assigned).toBe(shrine.id);
    expect(f.manual).toBe(true);
    expect(f.task).toBe("worshipping");
  });
  it("loads pre-V3 version-2 worlds and never shrinks them", () => {
    const w = createWorld();
    w.radius = w.targetRadius = 1000;
    w.followers.forEach((f) => {
      delete f.manual;
      delete f.jobCooldown;
    });
    const restored = deserialize(serialize(w));
    advance(restored, 1);
    expect(restored.version).toBe(2);
    expect(restored.radius).toBe(1000);
    expect(restored.followers[1].manual).toBe(false);
  });
});
