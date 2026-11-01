import { BUILDINGS, POWERS, QUESTS, maxMana, xpForLevel } from "./data";
import {
  basinCapacity,
  clamp,
  deform,
  distance,
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
    addFollower(w, wrap(0.18 + (w.level % 7) * 0.08), 0);
    if ([4, 7, 10, 15].includes(w.level)) w.rune = true;
    note(w, `Level ${w.level}! A new inhabitant has arrived. +2 Awe`);
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
      w.lastRain = w.time;
    }
    if (power === "sun") {
      w.stats.sun++;
      if (w.time - w.lastRain < 35) discover(w, "Rainbow");
    }
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
        t.rock = 0;
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
    w.buildings.forEach((b) => {
      if (distance(b.angle, angle) > 0.18) return;
      if (
        (power === "rain" && BUILDINGS[b.type].need === "rain") ||
        (power === "sun" && BUILDINGS[b.type].need === "sun")
      )
        b.charge = 180;
      if (power === "fire") b.durability = Math.max(0, b.durability - 20);
    });
    w.followers.forEach((f) => {
      if (!f.alive || distance(f.angle, angle) > 0.2) return;
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
          note(
            w,
            `${f.name} believes in you! Pick them up and give them a purpose.`,
          );
          gainXP(w, 10);
        }
      } else {
        f.task = "frightened";
        f.timer = 7;
        f.happiness = Math.max(10, f.happiness - 12);
      }
    });
    if (w.terrain.some((t) => t.water > 3)) discover(w, "Lakeside");
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
    w.buildings.some((b) => b.id !== ignore && distance(b.angle, angle) < 0.115)
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
  if (type === "mine" && t.rock < 0.4 && t.height < 15)
    return "Mines need rocky or elevated ground.";
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
  w.gold -= BUILDINGS[type].cost;
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
  note(w, `${BUILDINGS[type].name} placed. Assign a believer to build it.`);
  return b;
}
export function assign(
  w: World,
  fid: string,
  bid: string | null,
): string | null {
  const f = w.followers.find((f) => f.id === fid);
  if (!f || !f.alive) return "Select a living follower.";
  if (bid === null) {
    f.assigned = null;
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
  f.assigned = bid;
  f.returnTo = null;
  f.task =
    b.construction < 1
      ? "constructing"
      : BUILDINGS[b.type].role === "rest"
        ? "resting"
        : BUILDINGS[b.type].role === "worship"
          ? "worshipping"
          : b.type === "fishing"
            ? "fishing"
            : "working";
  f.timer = 0;
  return null;
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
  w.gold -= cost;
  b.upgrade++;
  b.durability = 100;
  gainXP(w, 15);
  return null;
}
export function expand(w: World) {
  if (!w.rune) return;
  w.rune = false;
  w.expansions++;
  w.radius += 65;
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
    (1 + Math.min(0.3, f.proficiency / 1000)) *
    (f.trait === "Industrious" ? 1.15 : 1)
  );
}
export function step(w: World, dt: number) {
  w.time += dt;
  w.tick++;
  w.effects.forEach((e) => (e.life -= dt));
  w.effects = w.effects.filter((e) => e.life > 0);
  let worship = 0;
  const groups = new Map<string, Follower[]>();
  for (const f of w.followers) {
    if (!f.alive) continue;
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
      f.task = "frightened";
      f.timer = 2;
      f.angle = wrap(f.angle + dt * 0.04);
    }
    if (f.energy < 0 || (soil.water > 35 && f.energy < 5)) {
      f.alive = false;
      f.task = "dead";
      f.assigned = null;
      note(w, `${f.name} has fallen. Resurrection can bring them back.`);
      continue;
    }
    if (f.timer > 0) {
      f.timer -= dt;
      continue;
    }
    const b = w.buildings.find((b) => b.id === f.assigned);
    if (f.task === "resting" && f.returnTo && f.energy > 95) {
      f.assigned = f.returnTo;
      f.returnTo = null;
      continue;
    }
    if (b) {
      const diff = signedDistance(b.angle, f.angle);
      if (Math.abs(diff) > 0.026) {
        f.angle = wrap(
          f.angle +
            Math.sign(diff) * Math.min(Math.abs(diff), dt * f.speed * 2),
        );
        f.task = b.construction < 1 ? "constructing" : "wandering";
        continue;
      }
      const def = BUILDINGS[b.type];
      if (f.energy < 8 && def.role !== "rest" && w.settings.autonomy) {
        const rest = w.buildings.find(
          (v) =>
            v.construction >= 1 &&
            BUILDINGS[v.type].role === "rest" &&
            w.followers.filter((p) => p.assigned === v.id).length <
              BUILDINGS[v.type].capacity,
        );
        if (rest) {
          f.returnTo = b.id;
          f.assigned = rest.id;
          f.task = "resting";
          continue;
        }
      }
      if (f.energy < 1 && def.role !== "rest") {
        f.task = "exhausted";
        f.energy = Math.min(12, f.energy + dt * 0.2);
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
        f.angle = wrap(f.angle + direction * dt * f.speed * 0.35);
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
      }
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
    w.terrainVersion++;
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
        f.task = "frightened";
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
    if (b.construction < 1 || d.output === 0 || b.durability <= 0) continue;
    const workers = w.followers.filter(
      (f) => f.alive && f.assigned === b.id && f.energy > 1,
    );
    if (!workers.length) continue;
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
