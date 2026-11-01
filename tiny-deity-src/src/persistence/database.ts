import { newStats } from "../game/data";
import { RESOURCES } from "../game/economy";
import { restoreSlots } from "../game/simulation";
import Dexie, { type EntityTable } from "dexie";
import type { World } from "../game/types";
const db = new Dexie("tiny-deity") as Dexie & {
  saves: EntityTable<{ id: string; world: World }, "id">;
};
db.version(1).stores({ saves: "id" });
export function serialize(w: World): string {
  return JSON.stringify({
    ...w,
    effects: [],
    undo: null,
    lastSaved: Date.now(),
  });
}
export function deserialize(raw: string): World {
  const w = JSON.parse(raw) as World;
  const finite = (n: unknown) => typeof n === "number" && Number.isFinite(n);
  if (
    !w ||
    ![1, 2].includes(w.version) ||
    !Array.isArray(w.terrain) ||
    w.terrain.length !== 512 ||
    !Array.isArray(w.followers) ||
    !Array.isArray(w.buildings) ||
    !Array.isArray(w.log) ||
    !Array.isArray(w.completed) ||
    !Array.isArray(w.discoveries) ||
    !w.stats ||
    !w.settings ||
    typeof w.name !== "string" ||
    w.name.length > 32
  )
    throw new Error("This is not a Tiny Deity save.");
  for (const key of [
    "gold",
    "mana",
    "awe",
    "xp",
    "level",
    "radius",
    "tick",
    "nextId",
    "time",
    "lastSaved",
    "terrainVersion",
    "seed",
    "eventAt",
    "expansions",
  ] as const)
    if (!finite(w[key]) || w[key] < 0)
      throw new Error("Save contains invalid numbers.");
  if (
    w.level < 1 ||
    w.level > 50 ||
    w.radius < 350 ||
    w.radius > 5000 ||
    w.followers.length > 200 ||
    w.buildings.length > 300
  )
    throw new Error("Save is outside world limits.");
  if (
    !Object.values(w.stats).every(finite) ||
    typeof w.lastRain !== "number" ||
    !Number.isFinite(w.lastRain) ||
    typeof w.rune !== "boolean" ||
    ![...w.log, ...w.completed, ...w.discoveries].every(
      (v) => typeof v === "string",
    )
  )
    throw new Error("Invalid world history.");
  for (const key of [
    "sound",
    "reduced",
    "classic",
    "autonomy",
    "seasons",
    "debug",
    "events",
  ] as const)
    if (typeof w.settings[key] !== "boolean")
      throw new Error("Invalid settings.");
  if (w.monster && (!finite(w.monster.angle) || !finite(w.monster.health)))
    throw new Error("Invalid world event.");
  const types = [
    "logging",
    "collector",
    "shrine",
    "farm",
    "tent",
    "campfire",
    "garden",
    "fountain",
    "windmill",
    "mine",
    "fishing",
    "workshop",
    "observatory",
    "temple",
  ];
  for (const t of w.terrain)
    for (const key of [
      "height",
      "moisture",
      "heat",
      "fertility",
      "vegetation",
      "water",
      "fire",
      "rock",
    ] as const)
      if (!finite(t[key])) throw new Error("Invalid terrain.");
  for (const b of w.buildings)
    if (
      !types.includes(b.type) ||
      typeof b.id !== "string" ||
      ![
        "angle",
        "construction",
        "progress",
        "stored",
        "durability",
        "upgrade",
        "charge",
      ].every((k) => finite(b[k as keyof typeof b]))
    )
      throw new Error("Invalid building.");
  for (const f of w.followers)
    if (
      typeof f.id !== "string" ||
      typeof f.name !== "string" ||
      !Number.isInteger(f.appearance) ||
      f.appearance < 0 ||
      f.appearance > 5 ||
      typeof f.alive !== "boolean" ||
      typeof f.trait !== "string" ||
      (f.assigned !== null && typeof f.assigned !== "string") ||
      ![
        "angle",
        "energy",
        "happiness",
        "comfort",
        "faith",
        "speed",
        "proficiency",
        "timer",
        "appearance",
      ].every((k) => finite(f[k as keyof typeof f]))
    )
      throw new Error("Invalid follower.");
  const legacy = (w.version as number) === 1;
  if (legacy) {
    w.resources = { wood: 8, stone: 3, water: 5, food: 5 };
    w.capacity = { wood: 150, stone: 150, water: 60, food: 80 };
    w.produced = { wood: 0, stone: 0, water: 0, food: 0 };
    w.consumed = { wood: 0, stone: 0, water: 0, food: 0 };
    w.resourceStats = { wood: 0, stone: 0, water: 0, food: 0 };
    w.gatherAt = 0;
    w.waitingFollowers = 0;
    w.stats = { ...newStats(), ...w.stats };
    w.followers.forEach((f) => (f.hunger = 0));
    for (const t of w.terrain) {
      t.wood = t.vegetation * 5;
      t.stone = t.rock * 6;
      t.regrowth = 0;
      t.harvesting = 0;
    }
  }
  if (!finite(w.waitingFollowers) || w.waitingFollowers < 0)
    throw new Error("Invalid population queue.");
  if (
    !w.followers.every(
      (f) => finite(f.hunger) && f.hunger >= 0 && f.hunger <= 100,
    )
  )
    throw new Error("Invalid follower needs.");
  const ids = [...w.followers, ...w.buildings].map((e) => e.id);
  if (new Set(ids).size !== ids.length)
    throw new Error("Duplicate entity identifiers.");
  for (const record of [
    w.resources,
    w.capacity,
    w.produced,
    w.consumed,
    w.resourceStats,
  ])
    if (
      !record ||
      !RESOURCES.every(
        (r) => finite(record[r]) && record[r] >= 0 && record[r] <= 1e8,
      )
    )
      throw new Error("Invalid resource inventory.");
  if (!finite(w.gatherAt) || w.gatherAt < 0)
    throw new Error("Invalid gathering time.");
  for (const t of w.terrain)
    if (
      ![t.wood, t.stone, t.regrowth, t.harvesting].every(
        (n) => finite(n) && n >= 0,
      )
    )
      throw new Error("Invalid resource deposits.");
  if (legacy) {
    w.version = 2;
    w.targetRadius = w.radius;
    w.legacy = true;
    w.rune ||=
      [3, 6, 10, 15].filter((level) => level <= w.level).length > w.expansions;
    w.log.unshift(
      "Legacy world preserved at its original size. Sacred runes continue its growth.",
    );
  }
  if (
    !Object.keys(newStats()).every((key) =>
      finite(w.stats[key as keyof typeof w.stats]),
    )
  )
    throw new Error("Invalid progression statistics.");
  if (
    !w.followers.every(
      (f) => finite(f.facing ?? 1) && finite(f.lane ?? 0) && f.speed >= 0,
    )
  )
    throw new Error("Invalid follower movement.");
  if (
    !finite(w.targetRadius) ||
    w.targetRadius < w.radius ||
    w.targetRadius > 5000
  )
    throw new Error("Invalid growth dimensions.");
  // V3 adds optional job preferences without changing the v2 world schema.
  for (const f of w.followers) {
    f.manual = typeof f.manual === "boolean" ? f.manual : !!f.assigned;
    f.jobCooldown = finite(f.jobCooldown)
      ? Math.max(0, Math.min(300, f.jobCooldown!))
      : 0;
    f.returnManual =
      typeof f.returnManual === "boolean" ? f.returnManual : !!f.returnTo;
  }
  restoreSlots(w);
  w.effects = [];
  w.undo = null;
  w.settings.speed = [1, 2, 4].includes(w.settings.speed)
    ? w.settings.speed
    : 1;
  return w;
}
export async function save(w: World) {
  const world = deserialize(serialize(w));
  await db.saves.put({ id: "current", world });
}
export async function load(): Promise<World | null> {
  const entry = await db.saves.get("current");
  return entry ? deserialize(JSON.stringify(entry.world)) : null;
}

export async function storedBackup(): Promise<string | null> {
  const entry = await db.saves.get("current");
  return entry ? JSON.stringify(entry.world) : null;
}
