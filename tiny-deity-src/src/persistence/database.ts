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
    w.version !== 1 ||
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
    w.radius < 500 ||
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
