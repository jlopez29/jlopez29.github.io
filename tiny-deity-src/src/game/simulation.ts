import {
  materialError,
  materialProduction,
  environmentEconomy,
  nearby,
  addResource,
  consume,
} from "./economy";
import {
  BUILDINGS,
  RECIPES,
  POWERS,
  QUESTS,
  maxMana,
  xpForLevel,
} from "./data";
import {
  basinCapacity,
  redistributeWater,
  clamp,
  deform,
  distance,
  ground,
  sample,
  signedDistance,
  wrap,
} from "./geometry";
import { addFollower } from "./world";
import {
  TAU,
  type World,
  type Power,
  type BuildingType,
  type Building,
  type Follower,
} from "./types";
const carriedFrom = new WeakMap<
  Follower,
  { task: Follower["task"]; timer: number }
>();
export function note(w: World, message: string) {
  w.log.unshift(message);
  w.log = w.log.slice(0, 30);
}
export function gainXP(w: World, xp: number) {
  w.xp += xp;
  while (w.level < 50 && w.xp >= xpForLevel(w.level)) {
    w.xp -= xpForLevel(w.level);
    w.level++;
    w.awe += 2;
    w.mana = maxMana(w);
    const canWelcome = w.resources.food >= 2;
    if (canWelcome) {
      consume(w, "food", 2);
      addFollower(w, wrap(0.18 + (w.level % 7) * 0.08), 0);
    } else w.waitingFollowers++;
    if ([3, 6, 10, 15].includes(w.level)) w.rune = true;
    note(
      w,
      `Level ${w.level}! ${canWelcome ? "A new inhabitant has arrived." : "An inhabitant awaits a food surplus."} +2 Awe`,
    );
  }
}
export function effect(
  w: World,
  type: Power | "coin" | "heart" | "rune",
  angle: number,
) {
  w.effects.push({ id: w.tick * 100 + w.effects.length, type, angle, life: 3 });
}
export function discover(w: World, name: string) {
  if (w.discoveries.includes(name)) return;
  w.discoveries.push(name);
  w.stats.discoveries++;
  w.awe++;
  gainXP(w, 20);
  note(w, `Discovery: ${name}. +1 Awe`);
}
export function cast(
  w: World,
  power: Power,
  angle: number,
  strength = 1,
): string | null {
  const p = POWERS[power];
  if (w.level < p.level) return `Unlock ${p.name} at level ${p.level}.`;
  if (w.mana < p.cost)
    return "A little more mana is needed. Try worshipping at the shrine.";
  if (
    power === "resurrect" &&
    !w.followers.some((f) => !f.alive && distance(f.angle, angle) < 0.15)
  )
    return "Choose a gravestone to bring a follower back.";
  if (
    power === "lightning" &&
    !w.terrain.some(
      (t, i) =>
        distance((i / w.terrain.length) * TAU, angle) < 0.12 && t.rock > 0.35,
    ) &&
    !(w.monster && distance(w.monster.angle, angle) < 0.2)
  )
    return "Choose rocky ground or a shadowling.";
  w.mana -= p.cost;
  w.stats.miracles++;
  gainXP(w, p.cost * 3);
  effect(w, power, angle);
  if (["raise", "lower", "smooth"].includes(power)) {
    deform(
      w,
      angle,
      (power === "raise" ? 1 : -1) * 22 * clamp(strength, 0.5, 3),
      power === "smooth",
    );
    w.stats.terraforms++;
  } else if (power === "resurrect") {
    const f = w.followers.find(
      (f) => !f.alive && distance(f.angle, angle) < 0.15,
    )!;
    f.alive = true;
    f.energy = 30;
    f.task = "recovering";
    f.happiness = 80;
    f.comfort = 60;
    note(w, `${f.name} is back. A second little chance.`);
  } else {
    if (power === "rain") {
      w.stats.rain++;
      if (
        nearby(w, angle, w.radius * 0.15).some(
          (t) => t.vegetation > 0.5 && t.wood > 0.1,
        )
      )
        w.stats.forestRain++;
      w.lastRain = w.time;
    }
    if (power === "sun") {
      w.stats.sun++;
      if (w.time - w.lastRain < 35) discover(w, "Rainbow");
    }
    const dryBeforeRain =
      power === "rain" &&
      nearby(w, angle).some((t) => t.moisture < 0.25 && t.vegetation < 0.25);
    let exposedStone = 0;
    w.terrain.forEach((t, i) => {
      const d = distance((i / w.terrain.length) * TAU, angle);
      if (d > 0.15) return;
      const f = 1 - d / 0.18;
      if (power === "rain") {
        const burned = t.fire > 0;
        t.moisture = clamp(t.moisture + 0.48 * f, 0, 1);
        t.heat = Math.max(0.1, t.heat - 0.1);
        t.vegetation = clamp(t.vegetation + 0.19 * f, 0, 1);
        t.fire = 0;
        t.water = Math.min(basinCapacity(w, i), t.water + 9 * f);
        if (burned) discover(w, "Life after fire");
      }
      if (power === "sun") {
        t.heat = clamp(t.heat + 0.25 * f, 0, 1);
        t.moisture = Math.max(0, t.moisture - 0.12 * f);
        if (t.moisture > 0.3)
          t.vegetation = clamp(t.vegetation + 0.12 * f, 0, 1);
        t.water = Math.max(0, t.water - 3);
      }
      if (power === "lightning") {
        // Shatter the rock but do not make the remaining stone inaccessible.
        const loosened = Math.min(t.stone, 0.15 * f);
        t.stone -= loosened;
        exposedStone += loosened;
        t.rock = t.stone > 0.1 ? Math.max(0.14, t.rock * 0.65) : 0;
        t.vegetation = Math.max(0, t.vegetation - 0.12);
      }
      if (power === "fire") {
        t.fire = 1;
        t.heat = 0.95;
      }
    });
    if (
      power === "lightning" &&
      w.monster &&
      distance(w.monster.angle, angle) < 0.2
    ) {
      w.monster = null;
      w.gold += 50;
      gainXP(w, 20);
      note(w, "Shadowling banished! +50 gold.");
    }
    if (exposedStone > 0) {
      const gained = addResource(w, "stone", exposedStone, angle);
      if (gained > 0) {
        effect(w, "coin", angle);
        w.effects[w.effects.length - 1].label =
          `Stone exposed +${gained.toFixed(1)}`;
      }
    }
    if (power === "rain") {
      const local = nearby(w, angle);
      if (w.stats.terraforms > 0 && local.some((t) => t.water > 7)) {
        discover(w, "Lake Maker");
      }
      if (dryBeforeRain && local.some((t) => t.vegetation > 0.28)) {
        discover(w, "Green Thumb");
      }
    }
    w.buildings.forEach((b) => {
      if (distance(b.angle, angle) > 0.18) return;
      if (
        (power === "rain" && BUILDINGS[b.type].need === "rain") ||
        (power === "sun" && BUILDINGS[b.type].need === "sun")
      )
        b.charge = 180;
      if (power === "rain" && b.type === "collector" && b.construction >= 1)
        addResource(
          w,
          "water",
          8 * clamp(strength, 0.5, 3) * (1 - distance(b.angle, angle) / 0.18),
          b.angle,
        );
      if (power === "fire") b.durability = Math.max(0, b.durability - 20);
    });
    w.followers.forEach((f) => {
      if (!f.alive || f.task === "carried" || distance(f.angle, angle) > 0.2)
        return;
      if (power === "rain" || power === "sun") {
        const old = f.faith;
        f.faith = clamp(f.faith + 55, 0, 100);
        f.happiness = clamp(f.happiness + 20, 0, 100);
        f.comfort = clamp(f.comfort + 25, 0, 100);
        f.timer = 3;
        f.task = "observing";
        if (old < 50 && f.faith >= 50) {
          w.stats.converted++;
          effect(w, "heart", f.angle);
          note(w, `${f.name} believes in you! They will find useful work.`);
          gainXP(w, 10);
        }
      } else {
        f.task = "frightened";
        f.timer = 7;
        f.happiness = Math.max(10, f.happiness - 12);
      }
    });
    if (nearby(w, angle).some((t) => t.water > 3)) discover(w, "Lakeside");
    w.terrainVersion++;
  }
  checkQuests(w);
  return null;
}
export function placement(
  w: World,
  type: BuildingType,
  angle: number,
  ignore?: string,
): string | null {
  const d = BUILDINGS[type],
    t = sample(w.terrain, angle);
  if (w.level < d.level) return `Unlocked at level ${d.level}.`;
  if (
    w.buildings.some(
      (b) => b.id !== ignore && distance(b.angle, angle) * w.radius < 170,
    )
  )
    return "Give neighboring buildings a little room.";
  const left = sample(w.terrain, angle - 0.04).height,
    right = sample(w.terrain, angle + 0.04).height;
  if (Math.abs(left - right) > 26)
    return "Too steep. Smooth this patch of land first.";
  if (t.water > 6 && type !== "fishing")
    return "Too much water here. Find a dry patch.";
  if (
    type === "fishing" &&
    !w.terrain.some(
      (s, i) =>
        s.water > 2 && distance((i / w.terrain.length) * TAU, angle) < 0.15,
    )
  )
    return "Place beside a lake. Lower land, then add rain.";
  if (
    type === "mine" &&
    !nearby(w, angle, 90).some((t) => t.stone > 0.1 && t.rock > 0.4)
  )
    return "Quarries require accessible rocky stone deposits.";
  if (
    type === "logging" &&
    !nearby(w, angle).some((t) => t.wood > 0.1 && t.vegetation > 0.4)
  )
    return "Logging camps need a nearby harvestable forest.";
  return null;
}
export function purchase(
  w: World,
  type: BuildingType,
  angle: number,
): string | Building {
  const error = placement(w, type, angle);
  if (error) return error;
  if (w.gold < BUILDINGS[type].cost)
    return "You need more gold for this building.";
  const missing = materialError(w, type);
  if (missing) return missing;
  w.gold -= BUILDINGS[type].cost;
  consume(w, "wood", RECIPES[type].wood);
  consume(w, "stone", RECIPES[type].stone);
  const b: Building = {
    id: `b${w.nextId++}`,
    type,
    angle: wrap(angle),
    construction: 0,
    progress: 0,
    stored: 0,
    durability: 100,
    upgrade: 1,
    charge: 0,
  };
  w.buildings.push(b);
  note(w, `${BUILDINGS[type].name} placed. Believers will help build it.`);
  return b;
}
export function assign(
  w: World,
  fid: string,
  bid: string | null,
  manual = true,
): string | null {
  const f = w.followers.find((f) => f.id === fid);
  if (!f || !f.alive) return "Select a living follower.";
  if (bid === null) {
    f.assigned = null;
    f.manual = false;
    f.jobCooldown = 12;
    f.slot = null;
    f.lane = 0;
    f.returnTo = null;
    f.task = "wandering";
    return null;
  }
  if (f.faith < 50)
    return "Perform a gentle miracle near this inhabitant to earn their faith.";
  const b = w.buildings.find((b) => b.id === bid);
  if (!b) return "That building is no longer here.";
  if (
    w.followers.filter(
      (other) => other.alive && other.id !== fid && other.assigned === bid,
    ).length >=
    BUILDINGS[b.type].capacity + b.upgrade - 1
  )
    return "This building is full.";
  const occupied = new Set(
    w.followers
      .filter((o) => o.alive && o.id !== fid && o.assigned === bid)
      .map((o) => o.slot),
  );
  const slot = Array.from(
    { length: BUILDINGS[b.type].capacity + b.upgrade - 1 },
    (_, i) => i,
  ).find(
    (i) =>
      !occupied.has(i) &&
      !w.followers.some((other) => {
        if (
          !other.alive ||
          other.id === fid ||
          other.assigned === bid ||
          other.slot === null
        )
          return false;
        const neighbor = w.buildings.find(
          (building) => building.id === other.assigned,
        );
        return (
          neighbor &&
          distance(slotAngle(w, b, i), slotAngle(w, neighbor, other.slot)) *
            w.radius <
            25
        );
      }),
  );
  if (slot === undefined)
    return "No clear work position. This building is full or neighboring work positions are too close.";
  f.assigned = bid;
  f.manual = manual;
  f.jobCooldown = 18;
  f.slot = slot;
  f.returnTo = null;
  f.task = "traveling";
  f.timer = 0;
  return null;
}
/** Stable arc-length slots stay attached to terrain and do not move other workers. */
export function slotAngle(w: World, b: Building, slot: number): number {
  const offset = (slot % 2 === 0 ? -1 : 1) * (48 + Math.floor(slot / 2) * 30);
  return wrap(b.angle + offset / ground(w, b.angle));
}
export function grab(w: World, id: string) {
  const f = w.followers.find((f) => f.id === id);
  if (!f?.alive) return;
  // Preserve needs and reservations until a drop succeeds or the gesture is canceled.
  carriedFrom.set(f, { task: f.task, timer: f.timer });
  f.timer = 0;
  f.task = "carried";
}
export function landFollower(w: World, id: string, angle: number) {
  const f = w.followers.find((f) => f.id === id);
  if (!f?.alive) return;
  assign(w, id, null);
  for (
    let i = 0;
    i < 100 &&
    w.followers.some(
      (other) =>
        other.id !== id &&
        other.alive &&
        distance(other.angle, angle) * w.radius < 25,
    );
    i++
  )
    angle = wrap(angle + 27 / w.radius);
  f.angle = wrap(angle);
  f.origin = f.angle;
  f.timer = 8;
}
export function releaseCarried(w: World) {
  w.followers
    .filter((f) => f.task === "carried")
    .forEach((f) => {
      const previous = carriedFrom.get(f);
      f.task =
        previous?.task ??
        (f.assigned
          ? "traveling"
          : f.returnTo
            ? "seekingResources"
            : "wandering");
      f.timer = previous?.timer ?? 0;
      carriedFrom.delete(f);
    });
}
/** Repair old/duplicate reservations without changing any physical positions. */
export function restoreSlots(w: World) {
  const used = new Map<string, Set<number>>();
  for (const f of w.followers) {
    f.facing ??= 1;
    f.lane ??= 0;
    const b = w.buildings.find((b) => b.id === f.assigned);
    if (f.task === "carried")
      f.task = f.assigned
        ? "traveling"
        : f.returnTo
          ? "seekingResources"
          : "wandering";
    if (!b || !f.alive) {
      f.assigned = null;
      f.slot = null;
      continue;
    }
    const slots = used.get(b.id) || new Set<number>();
    const capacity = BUILDINGS[b.type].capacity + b.upgrade - 1;
    if (
      !Number.isInteger(f.slot) ||
      f.slot! < 0 ||
      f.slot! >= capacity ||
      slots.has(f.slot!)
    )
      f.slot =
        Array.from({ length: capacity }, (_, i) => i).find(
          (i) => !slots.has(i),
        ) ?? null;
    if (f.slot === null) {
      f.assigned = null;
      f.task = "wandering";
    } else {
      slots.add(f.slot);
      used.set(b.id, slots);
    }
  }
}
function walk(w: World, f: Follower, target: number, dt: number) {
  const radius = ground(w, f.angle),
    diff = signedDistance(target, f.angle);
  const direction = Math.sign(diff);
  f.facing = direction || f.facing;
  // Two narrow footpaths let opposing traffic pass without pushing inhabitants.
  f.lane = 0;
  let amount = Math.min(Math.abs(diff), (dt * f.speed * 1700) / radius);
  for (const other of w.followers) {
    if (other.id === f.id || !other.alive || other.task === "carried") continue;
    const ahead = signedDistance(other.angle, f.angle) * direction * radius;
    const moving =
      other.task === "traveling" ||
      other.task === "wandering" ||
      other.task === "fleeing" ||
      other.task === "seekingResources";
    if (
      moving &&
      other.facing === direction &&
      ahead > 0 &&
      ahead < 23 &&
      Math.abs(other.lane - f.lane) < 6
    )
      amount = Math.min(amount, Math.max(0, (ahead - 21) / radius));
    if (
      (!moving && Math.abs(ahead) < 35) ||
      (moving &&
        other.facing !== direction &&
        Math.abs(ahead) < 45 &&
        f.id > other.id)
    )
      f.lane = 28;
    if (
      moving &&
      other.facing === direction &&
      Math.abs(ahead) < 0.1 &&
      f.id > other.id
    ) {
      amount = 0;
      f.lane = 28;
    }
  }
  f.angle = wrap(f.angle + direction * amount);
  return distance(f.angle, target) * radius < 0.5;
}
export function collect(w: World, id: string): number {
  const b = w.buildings.find((b) => b.id === id);
  if (!b || !b.stored) return 0;
  const gold = b.stored;
  b.stored = 0;
  w.gold += gold;
  w.stats.collected += gold;
  gainXP(w, Math.ceil(gold / 3));
  effect(w, "coin", b.angle);
  checkQuests(w);
  return gold;
}
export function upgrade(w: World, id: string): string | null {
  const b = w.buildings.find((b) => b.id === id);
  if (!b) return "Choose a building.";
  const cost = Math.round(BUILDINGS[b.type].cost * 0.65 * b.upgrade);
  if (b.construction < 1) return "Finish construction first.";
  if (b.upgrade >= 4) return "This building is fully upgraded.";
  if (w.gold < cost) return `You need ${cost} gold.`;
  const missing = materialError(w, b.type, 0.5 * b.upgrade);
  if (missing) return missing;
  consume(w, "wood", RECIPES[b.type].wood * 0.5 * b.upgrade);
  consume(w, "stone", RECIPES[b.type].stone * 0.5 * b.upgrade);
  w.gold -= cost;
  b.upgrade++;
  b.durability = 100;
  gainXP(w, 15);
  return null;
}
export function expand(w: World) {
  if (!w.rune) return;
  w.expansions++;
  w.rune =
    [3, 6, 10, 15].filter((level) => level <= w.level).length > w.expansions;
  w.targetRadius += 95;
  // New ground becomes productive without replacing terrain or entities.
  const center = (w.expansions * 1.43 + 1.2) % TAU;
  w.terrain.forEach((t, i) => {
    if (distance((i / w.terrain.length) * TAU, center) < 0.25) {
      t.vegetation = Math.max(t.vegetation, 0.8);
      t.moisture = Math.max(t.moisture, 0.65);
      t.rock = Math.max(t.rock, 0.6);
      t.wood += 3;
      t.stone += 4;
    }
  });
  w.terrainVersion++;
  w.awe += 3;
  addFollower(w, 0.8, 60);
  effect(w, "rune", 0);
  note(w, "Your little world grew! New shores, new possibilities. +3 Awe");
  gainXP(w, 30);
}
export function checkQuests(w: World) {
  for (const q of QUESTS) {
    if (!w.completed.includes(q.id) && q.value(w) >= q.target) {
      w.completed.push(q.id);
      w.gold += q.gold;
      gainXP(w, q.reward);
      note(w, `Goal complete: ${q.name}. +${q.gold} gold, +${q.reward} XP`);
    }
  }
}
function workEfficiency(f: Follower) {
  return (
    ((f.energy / 100) * 0.5 + 0.5) *
    ((f.happiness / 100) * 0.7 + 0.3) *
    (f.hunger > 70 ? 0.55 : 1) *
    (1 + Math.min(0.3, f.proficiency / 1000)) *
    (f.trait === "Industrious" ? 1.15 : 1)
  );
}
export function step(w: World, dt: number) {
  if (w.radius < w.targetRadius) {
    w.radius = Math.min(w.targetRadius, w.radius + dt * 18);
    w.terrainVersion++;
  }
  environmentEconomy(w, dt);
  w.time += dt;
  w.tick++;
  w.effects.forEach((e) => (e.life -= dt));
  w.effects = w.effects.filter((e) => e.life > 0);
  let worship = 0;
  const groups = new Map<string, Follower[]>();
  for (const f of w.followers) {
    if (!f.alive || f.task === "carried") continue;
    f.jobCooldown = Math.max(0, (f.jobCooldown ?? 0) - dt);
    f.manual ??= !!f.assigned;
    f.hunger = Math.min(100, f.hunger + dt * 0.06);
    if (f.hunger > 70) f.happiness = Math.max(15, f.happiness - dt * 0.04);
    if (
      w.settings.autonomy &&
      f.hunger > 55 &&
      f.task !== "seekingResources" &&
      f.timer <= 0 &&
      w.resources.food >= 1
    ) {
      const previous = f.returnTo || f.assigned;
      if (!f.returnTo) f.returnManual = f.manual;
      assign(w, f.id, null);
      f.returnTo = previous;
      f.task = "seekingResources";
    }
    if (f.task === "seekingResources") {
      const home =
        w.buildings.find(
          (b) =>
            b.construction >= 1 && (b.type === "tent" || b.type === "farm"),
        ) || w.buildings[0];
      const index = w.followers.indexOf(f);
      const target = wrap((home?.angle || 0) + (140 + index * 26) / w.radius);
      if (walk(w, f, target, dt)) {
        f.lane = 0;
        if (consume(w, "food", 1) >= 1) {
          f.hunger = 0;
          f.happiness = Math.min(100, f.happiness + 5);
        }
        const previous = f.returnTo;
        assign(w, f.id, null);
        if (previous && w.settings.autonomy)
          assign(w, f.id, previous, f.returnManual ?? true);
        else f.task = "wandering";
        f.timer = 1;
      }
      continue;
    }
    // Manual worlds keep workers in place, but shared food still supports their needs.
    if (!w.settings.autonomy && f.hunger > 55 && w.resources.food >= 1) {
      consume(w, "food", 1);
      f.hunger = 0;
    }
    f.comfort = Math.max(0, f.comfort - dt * 0.025);
    f.happiness = clamp(
      f.happiness + dt * (f.comfort > 40 ? 0.015 : -0.09),
      0,
      100,
    );
    const soil = sample(w.terrain, f.angle);
    if (soil.fire > 0.2) {
      f.energy -= dt * 4;
      f.happiness = Math.max(0, f.happiness - dt);
      f.timer = 2;
      f.task = "fleeing";
    }
    if (f.energy < 0 || (soil.water > 35 && f.energy < 5)) {
      f.alive = false;
      f.task = "dead";
      f.assigned = null;
      note(w, `${f.name} has fallen. Resurrection can bring them back.`);
      continue;
    }
    if (f.timer > 0) {
      if (f.task === "fleeing") {
        const direction = w.monster
          ? Math.sign(signedDistance(f.angle, w.monster.angle)) || 1
          : 1;
        walk(w, f, wrap(f.angle + direction * 0.3), dt);
      }
      f.timer -= dt;
      continue;
    }
    // Reservations and a cooldown prevent tick-by-tick competition. Legacy and
    // explicit player assignments stay preferred through food/rest detours.
    if (
      w.settings.autonomy &&
      (!f.assigned || !f.manual) &&
      f.faith >= 50 &&
      f.energy > 30 &&
      !f.returnTo &&
      f.jobCooldown <= 0
    ) {
      const score = (b: Building) =>
        (b.construction < 1
          ? -4
          : BUILDINGS[b.type].role === "produce"
            ? -1
            : 0) +
        distance(b.angle, f.angle) * 0.3;
      const current = w.buildings.find((b) => b.id === f.assigned);
      const candidates = w.buildings
        .filter(
          (b) =>
            b.durability > 0 &&
            BUILDINGS[b.type].role !== "rest" &&
            (!current || score(b) < score(current) - 0.7),
        )
        .sort((a, b) => score(a) - score(b));
      for (const candidate of candidates)
        if (!assign(w, f.id, candidate.id, false)) break;
      f.jobCooldown = 18;
    }
    const b = w.buildings.find((b) => b.id === f.assigned);
    if (
      f.task === "resting" &&
      f.returnTo &&
      f.energy > 95 &&
      w.settings.autonomy
    ) {
      const previous = f.returnTo;
      const manual = f.returnManual ?? true;
      assign(w, f.id, null);
      assign(w, f.id, previous, manual);
      continue;
    }
    if (b) {
      if (f.slot === null) {
        restoreSlots(w);
        continue;
      }
      const target = slotAngle(w, b, f.slot);
      if (distance(target, f.angle) * ground(w, f.angle) > 0.5) {
        f.task = "traveling";
        walk(w, f, target, dt);
        continue;
      }
      f.lane = 0;
      f.facing = Math.sign(signedDistance(b.angle, f.angle)) || 1;
      const def = BUILDINGS[b.type];
      if (f.energy < 8 && def.role !== "rest" && w.settings.autonomy) {
        const rest = w.buildings.find(
          (v) =>
            v.construction >= 1 &&
            BUILDINGS[v.type].role === "rest" &&
            w.followers.filter((p) => p.assigned === v.id).length <
              BUILDINGS[v.type].capacity + v.upgrade - 1,
        );
        if (rest) {
          const manual = f.manual;
          assign(w, f.id, rest.id, false);
          f.returnManual = manual;
          f.returnTo = b.id;
          continue;
        }
      }
      if ((f.energy < 1 || f.task === "exhausted") && def.role !== "rest") {
        f.task = "exhausted";
        f.energy = Math.min(100, f.energy + dt * 0.8);
        if (f.energy > 65) f.task = "traveling";
        continue;
      }
      const group = groups.get(b.id) || [];
      group.push(f);
      groups.set(b.id, group);
      if (b.construction < 1) {
        f.task = "constructing";
        f.energy = Math.max(0, f.energy - dt * 0.22);
        f.proficiency += dt;
      } else if (def.role === "rest") {
        f.task = "resting";
        const powered = !def.need || b.charge > 0;
        f.energy = clamp(f.energy + dt * (powered ? 2.2 : 0.8), 0, 100);
        f.comfort = clamp(f.comfort + dt * 0.5, 0, 100);
        f.happiness = clamp(f.happiness + dt * 0.25, 0, 100);
      } else if (def.role === "worship") {
        f.task = "worshipping";
        worship +=
          (b.type === "temple" ? 3 : b.type === "observatory" ? 2 : 1) *
          (f.trait === "Mystic" ? 1.3 : 1);
        f.energy = Math.max(0, f.energy - dt * 0.06);
        w.stats.worship += dt;
      } else {
        f.task = b.type === "fishing" ? "fishing" : "working";
        f.energy = Math.max(0, f.energy - dt * 0.35);
        f.proficiency += dt;
      }
    } else {
      f.assigned = null;
      if (f.energy < 25) {
        f.task = "recovering";
        f.energy = Math.min(100, f.energy + dt * 0.6);
      } else {
        f.task = "wandering";
        const direction =
          Math.floor(w.time / 12 + f.appearance) % 2 === 0 ? 1 : -1;
        walk(w, f, wrap(f.angle + direction * 0.1), dt * 0.35);
        f.energy = Math.min(100, f.energy + dt * 0.04);
      }
    }
  }
  w.mana = Math.min(maxMana(w), w.mana + dt * (1 / 45 + worship / 14));
  for (const b of w.buildings) {
    const def = BUILDINGS[b.type],
      workers = groups.get(b.id) || [];
    b.charge = Math.max(0, b.charge - dt);
    if (b.construction < 1 && workers.length) {
      b.construction = Math.min(
        1,
        b.construction +
          (dt *
            workers.reduce(
              (s, f) =>
                s + workEfficiency(f) * (f.trait === "Builder" ? 1.3 : 1),
              0,
            )) /
            12,
      );
      if (b.construction >= 1) {
        w.stats.built++;
        gainXP(w, 15);
        note(w, `${def.name} is ready!`);
        effect(w, "rune", b.angle);
        effect(w, "coin", b.angle);
        w.effects[w.effects.length - 1].label = "Built! +15 XP";
      }
    } else if (materialProduction(w, b, workers, dt)) {
      // Material production checks actual deposits and storage.
    } else if (
      b.construction >= 1 &&
      workers.length &&
      def.output > 0 &&
      b.durability > 0
    ) {
      const t = sample(w.terrain, b.angle);
      const powered =
        def.need === "water"
          ? w.terrain.some(
              (s, i) =>
                s.water > 2 &&
                distance((i / w.terrain.length) * TAU, b.angle) < 0.15,
            )
          : !def.need || b.charge > 0;
      if (powered) {
        const efficiency =
          workers
            .filter((f) => f.energy > 1)
            .reduce((s, f) => s + workEfficiency(f), 0) *
          (1 + (b.upgrade - 1) * 0.25);
        b.progress +=
          ((dt * efficiency) / def.duration) *
          (b.type === "farm" ? 0.5 + t.fertility * 0.5 : 1);
        if (b.progress >= 1) {
          const cycles = Math.floor(b.progress);
          b.progress -= cycles;
          b.stored = Math.min(
            9999,
            b.stored +
              cycles * Math.round(def.output * (1 + (b.upgrade - 1) * 0.35)),
          );
        }
      }
    }
  }
  if (w.tick % 20 === 0) {
    const dtEnv = dt * 20;
    w.terrain.forEach((t, i) => {
      const capacity = basinCapacity(w, i);
      t.water = Math.max(
        0,
        Math.min(t.water, capacity) - dtEnv * (0.015 + t.heat * 0.03),
      );
      t.moisture = clamp(
        t.moisture - dtEnv * 0.0006 + (t.water > 0 ? dtEnv * 0.003 : 0),
        0,
        1,
      );
      if (t.fire > 0) {
        t.vegetation = Math.max(0, t.vegetation - dtEnv * 0.04);
        t.fire = Math.max(
          0,
          t.fire - dtEnv * (t.moisture > 0.65 ? 0.5 : 0.025),
        );
        const next = w.terrain[(i + 1) % 512];
        if (t.fire > 0.3 && next.vegetation > 0.5 && next.moisture < 0.4)
          next.fire = Math.max(next.fire, 0.4);
        w.buildings.forEach((b) => {
          if (distance(b.angle, (i / 512) * TAU) < 0.02)
            b.durability = Math.max(0, b.durability - dtEnv);
        });
      } else {
        const target =
          t.moisture > 0.3 ? Math.min(1, t.moisture * 1.4) : t.moisture * 0.7;
        t.vegetation = clamp(
          t.vegetation + (target - t.vegetation) * 0.005,
          0,
          1,
        );
      }
      const season = w.settings.seasons
        ? Math.sin((w.time / 240) * Math.PI * 2) * 0.15
        : 0;
      t.heat = clamp(t.heat + (0.5 + season - t.heat) * 0.001, 0, 1);
    });
    redistributeWater(w);
    w.terrainVersion++;
    if (w.waitingFollowers > 0 && w.resources.food >= 3) {
      consume(w, "food", 2);
      w.waitingFollowers--;
      addFollower(w, 0.35 + w.followers.length * 0.04, 0);
      note(w, "A well-fed settlement welcomes a waiting inhabitant.");
    }
    checkQuests(w);
  }
  if (w.settings.events && w.time > w.eventAt) {
    w.eventAt = w.time + 240 + ((w.seed + w.tick) % 180);
    const event = (Math.floor(w.time / 240) + w.seed) % 4;
    if (event === 0 && w.level >= 3) {
      w.monster = { angle: 0.4, health: 100 };
      note(
        w,
        "A shadowling is approaching. A lightning miracle will send it away.",
      );
    } else if (event === 1) {
      w.gold += 35;
      note(w, "Pip found a buried trinket! +35 gold.");
    } else if (event === 2) {
      note(w, "A dry breeze is arriving. Keep your farms watered.");
      w.terrain.forEach((t) => (t.moisture = Math.max(0, t.moisture - 0.08)));
    } else {
      note(w, "A gentle shower visits the far side of the world.");
      w.terrain.forEach((t, i) => {
        if (i > 200 && i < 260) t.moisture = clamp(t.moisture + 0.2, 0, 1);
      });
    }
  }
  if (w.monster) {
    w.monster.angle = wrap(w.monster.angle + dt * 0.006);
    w.followers.forEach((f) => {
      if (f.alive && distance(f.angle, w.monster!.angle) < 0.08) {
        f.happiness = Math.max(0, f.happiness - dt * 0.4);
        if (f.task === "carried") return;
        f.task = "fleeing";
        f.timer = 1;
      }
    });
  }
}
/** Offline rewards never cast miracles, kill followers, or trigger disasters. Cap at 4 hours. */
export function offline(w: World, seconds: number): number {
  const duration = clamp(seconds, 0, 14400);
  let total = 0;
  for (const b of w.buildings) {
    const d = BUILDINGS[b.type];
    if (b.construction < 1 || b.durability <= 0) continue;
    const workers = w.followers.filter(
      (f) =>
        f.alive &&
        f.assigned === b.id &&
        f.energy > 1 &&
        ["working", "fishing"].includes(f.task),
    );
    if (!workers.length) continue;
    if (["logging", "mine", "farm", "fishing", "collector"].includes(b.type)) {
      // One exhausted worker cannot stop the healthy workers' offline output.
      const elapsed = Math.min(
        duration,
        Math.max(...workers.map((f) => Math.max(0, (f.energy - 1) / 0.35))),
      );
      const before = b.stored;
      for (let t = 0; t < elapsed; t++) {
        const slice = Math.min(1, elapsed - t);
        const active = workers.filter((f) => f.energy > 1);
        if (!active.length) break;
        materialProduction(w, b, active, slice);
        active.forEach(
          (f) => (f.energy = Math.max(1, f.energy - slice * 0.35)),
        );
      }
      total += b.stored - before;
      continue;
    }
    const available =
      d.need && d.need !== "water"
        ? Math.min(duration, b.charge)
        : d.need === "water" &&
            !w.terrain.some(
              (s, i) =>
                s.water > 2 && distance((i / 512) * TAU, b.angle) < 0.15,
            )
          ? 0
          : duration;
    const energyTime = Math.min(...workers.map((f) => f.energy / 0.35));
    const elapsed = Math.min(available, energyTime);
    const cycles = Math.floor(elapsed / d.duration);
    const amount = cycles * d.output;
    b.stored = Math.min(9999, b.stored + amount);
    total += amount;
    workers.forEach((f) => (f.energy = Math.max(0, f.energy - elapsed * 0.35)));
    b.charge = Math.max(0, b.charge - duration);
  }
  w.mana = Math.min(maxMana(w), w.mana + duration / 45);
  if (total) note(w, `While you were away: ${total} gold is ready to collect.`);
  return total;
}
