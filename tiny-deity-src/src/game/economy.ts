import type {
  World,
  Resource,
  Building,
  Follower,
  BuildingType,
} from "./types";
import { TAU } from "./types";
import { BUILDINGS, RECIPES } from "./data";
import { distance, sample, clamp } from "./geometry";

export const RESOURCES: Resource[] = ["wood", "stone", "water", "food"];
export function nearby(w: World, angle: number, radius = 160) {
  return w.terrain.filter(
    (_, i) => distance((i / w.terrain.length) * TAU, angle) * w.radius < radius,
  );
}
export function materialError(
  w: World,
  type: BuildingType,
  multiplier = 1,
): string | null {
  const recipe = RECIPES[type];
  const missing = RESOURCES.filter((r) => r === "wood" || r === "stone").filter(
    (r) => w.resources[r] < recipe[r as "wood" | "stone"] * multiplier,
  );
  return missing.length
    ? `Needs ${missing.map((r) => `${Math.ceil(recipe[r as "wood" | "stone"] * multiplier - w.resources[r])} more ${r}`).join(" and ")}. Gather from the landscape or assign workers.`
    : null;
}
export function addResource(w: World, r: Resource, n: number, angle: number) {
  const amount = Math.min(n, Math.max(0, w.capacity[r] - w.resources[r]));
  if (amount <= 0) return 0;
  w.resources[r] += amount;
  w.produced[r] += amount;
  w.resourceStats[r] += amount;
  if (amount >= 0.5)
    w.effects.push({
      id: w.tick * 100 + w.effects.length,
      type: "coin",
      angle,
      life: 3,
      label: `+${Math.round(amount * 10) / 10} ${r}`,
    });
  return amount;
}
export function consume(w: World, r: Resource, n: number) {
  const amount = Math.min(Math.max(0, n), w.resources[r]);
  w.resources[r] = Math.max(0, w.resources[r] - amount);
  w.consumed[r] += amount;
  return amount;
}
export function extract(
  w: World,
  r: "wood" | "stone",
  angle: number,
  amount: number,
) {
  let left = Math.min(amount, w.capacity[r] - w.resources[r]);
  const requested = left;
  for (const t of nearby(w, angle)) {
    const stock =
      r === "wood"
        ? t.vegetation > 0.2 && t.fire < 0.1
          ? t.wood
          : 0
        : t.rock > 0.12
          ? t.stone
          : 0;
    const take = Math.min(left, stock);
    if (take <= 0) continue;
    t[r] -= take;
    left -= take;
    if (r === "wood") {
      t.harvesting += take;
      t.vegetation = clamp(t.vegetation - take * 0.15, 0.05, 1);
    } else t.rock = clamp(t.stone / 6, 0, 1);
    if (left <= 0) break;
  }
  const amountTaken = addResource(w, r, requested - left, angle);
  if (amountTaken) w.terrainVersion++;
  return amountTaken;
}
/** Manual gathering always uses landscape stocks; rain and free replanting allow recovery. */
export function gather(w: World, r: Resource, angle = 0): string | null {
  if (w.time < w.gatherAt)
    return `Gather again in ${Math.ceil(w.gatherAt - w.time)}s.`;
  if (w.resources[r] >= w.capacity[r]) return `${r} storage is full.`;
  let amount = 0;
  if (r === "wood" || r === "stone") amount = extract(w, r, angle, 1);
  if (r === "water") {
    const pond = nearby(w, angle, 600).find((t) => t.water > 1);
    if (pond) {
      amount = addResource(w, r, 1, angle);
      pond.water = Math.max(0, pond.water - amount * 0.4);
    }
  }
  if (r === "food") {
    const soil = nearby(w, angle, 300).find(
      (t) => t.fertility > 0.5 && t.moisture > 0.15 && t.vegetation > 0.08,
    );
    if (soil) {
      amount = addResource(w, r, 1, angle);
      soil.vegetation = Math.max(0, soil.vegetation - 0.02);
    }
  }
  if (!amount)
    return r === "wood"
      ? "No harvestable trees nearby. Replant and rain on the forest."
      : r === "water"
        ? "No pond nearby. Rain into a depression or build a rain collector."
        : `No accessible ${r} here. Explore the landscape.`;
  if (r === "wood") w.stats.gatheredWood += amount;
  w.gatherAt = w.time + 6;
  w.gold += 1;
  return null;
}
export function replant(w: World, angle = 0.72): string | null {
  if (w.time < w.gatherAt)
    return "Let the seedlings settle before gathering again.";
  for (const t of nearby(w, angle, 100)) {
    t.vegetation = Math.max(0.3, t.vegetation);
    t.fertility = Math.max(0.55, t.fertility);
  }
  w.gatherAt = w.time + 6;
  w.terrainVersion++;
  return null;
}
export function salvage(w: World, b: Building) {
  w.gold += Math.floor(BUILDINGS[b.type].cost * 0.35);
  for (const r of ["wood", "stone"] as const)
    addResource(w, r, RECIPES[b.type][r] * 0.5, b.angle);
}
export function environmentEconomy(w: World, dt: number) {
  for (const r of RESOURCES) {
    const decay = Math.exp(-dt / 60);
    w.produced[r] *= decay;
    w.consumed[r] *= decay;
  }
  for (const t of w.terrain) {
    t.harvesting = Math.max(0, t.harvesting - dt * 0.01);
    if (t.fire > 0.1) {
      t.wood = Math.max(0, t.wood - dt * 0.03);
      continue;
    }
    if (t.moisture > 0.4 && t.fertility > 0.35) {
      const growth = dt * 0.003 * t.moisture * t.fertility;
      t.regrowth += growth;
      t.wood = Math.min(6, t.wood + growth);
      t.vegetation = Math.min(1, t.vegetation + growth * 0.2);
    }
  }
}
/** Returns true for material buildings, whose output must never use generic gold-only production. */
export function materialProduction(
  w: World,
  b: Building,
  workers: Follower[],
  dt: number,
): boolean {
  if (!["logging", "mine", "collector", "farm", "fishing"].includes(b.type))
    return false;
  if (b.construction < 1 || b.durability <= 0) return true;
  if (b.type === "collector") {
    const pond = nearby(w, b.angle, 100).find((t) => t.water > 1);
    if (pond && w.resources.water < w.capacity.water) {
      const n = addResource(w, "water", dt * 0.04, b.angle);
      pond.water = Math.max(0, pond.water - n * 0.4);
    }
    return true;
  }
  if (!workers.length) return true;
  const soil = sample(w.terrain, b.angle);
  if (
    b.type === "logging" &&
    !nearby(w, b.angle).some(
      (t) => t.wood > 0.01 && t.vegetation > 0.2 && t.fire < 0.1,
    )
  )
    return true;
  if (
    b.type === "mine" &&
    !nearby(w, b.angle).some((t) => t.stone > 0.01 && t.rock > 0.12)
  )
    return true;
  if (b.type === "fishing" && !nearby(w, b.angle).some((t) => t.water > 2))
    return true;
  const resource =
    b.type === "logging" ? "wood" : b.type === "mine" ? "stone" : "food";
  if (w.resources[resource] >= w.capacity[resource]) return true;
  let efficiency =
    workers.reduce(
      (n, f) =>
        n +
        (f.energy > 1
          ? (0.5 + f.energy / 200) *
            (0.3 + f.happiness * 0.007) *
            (f.hunger > 70 ? 0.55 : 1)
          : 0),
      0,
    ) *
    (1 + (b.upgrade - 1) * 0.25);
  if (b.type === "farm")
    efficiency *=
      (0.2 + soil.fertility * 0.8) *
      (w.resources.water >= 1 ? 1 : 0.25) *
      (soil.heat > 0.2 && soil.heat < 0.85 ? 1 : 0.5);
  b.progress += (dt * efficiency) / BUILDINGS[b.type].duration;
  if (b.progress < 1) return true;
  b.progress -= 1;
  let amount = 0;
  if (resource === "wood" || resource === "stone")
    amount = extract(w, resource, b.angle, 3);
  else {
    const watered = b.type === "fishing" || consume(w, "water", 1) >= 1;
    amount = addResource(w, "food", watered ? 5 : 2, b.angle);
  }
  if (b.type === "logging") w.stats.loggedWood += amount;
  if (resource === "food") w.stats.farmedFood += amount;
  if (amount > 0) {
    b.stored = Math.min(
      9999,
      b.stored +
        Math.round(BUILDINGS[b.type].output * (1 + (b.upgrade - 1) * 0.35)),
    );
  }
  return true;
}
