import { type World, type Follower, type BuildingType, TAU } from "./types";
import { newStats } from "./data";
export function random(seed: number) {
  let a = seed | 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const NAMES = [
  "Pip",
  "Clover",
  "Bramble",
  "Nell",
  "Moss",
  "Juniper",
  "Wren",
  "Fern",
  "Otto",
  "Maple",
  "Rue",
  "Cedar",
  "Sunny",
  "Lark",
  "Hazel",
  "Finch",
];
export function addFollower(w: World, angle: number, faith = 0): Follower {
  const n = w.nextId++;
  const f: Follower = {
    id: `f${n}`,
    name: NAMES[w.followers.length % NAMES.length],
    angle,
    origin: angle,
    appearance: n % 6,
    age: "adult",
    energy: 100,
    happiness: 70,
    comfort: 80,
    faith,
    task: "wandering",
    assigned: null,
    returnTo: null,
    speed: 0.018 + (n % 4) * 0.003,
    proficiency: 0,
    alive: true,
    trait:
      w.level >= 11
        ? "Mystic"
        : w.level >= 9
          ? "Naturalist"
          : w.level >= 8
            ? "Builder"
            : n % 3 === 0
              ? "Industrious"
              : "Curious",
    timer: 0,
  };
  w.followers.push(f);
  return f;
}
export function createWorld(seed = 19207, demo = false): World {
  const rng = random(seed);
  const w: World = {
    version: 1,
    seed,
    name: "Clover",
    time: 0,
    tick: 0,
    nextId: 1,
    radius: 850,
    terrain: Array.from({ length: 512 }, (_, i) => {
      const a = (i / 512) * TAU;
      const dry = a < 0.24 || a > TAU - 0.15;
      return {
        height:
          Math.sin(a * 5) * 12 + Math.cos(a * 9) * 7 + Math.sin(a * 17) * 3,
        moisture: dry ? 0.12 : 0.48 + rng() * 0.15,
        heat: 0.5,
        fertility: 0.7,
        vegetation: dry ? 0.12 : 0.6 + rng() * 0.3,
        water: 0,
        fire: 0,
        rock: rng(),
      };
    }),
    followers: [],
    buildings: [],
    gold: 200,
    mana: 10,
    awe: 5,
    xp: 0,
    level: 1,
    stats: newStats(),
    completed: [],
    discoveries: [],
    log: ["Welcome to your little corner of the cosmos."],
    effects: [],
    settings: {
      sound: false,
      reduced: false,
      classic: false,
      autonomy: true,
      seasons: false,
      speed: 1,
      debug: false,
      events: true,
    },
    terrainVersion: 1,
    undo: null,
    lastRain: -100,
    rune: false,
    expansions: 0,
    lastSaved: Date.now(),
    eventAt: 300,
    monster: null,
  };
  w.buildings.push({
    id: `b${w.nextId++}`,
    type: "shrine",
    angle: -0.25,
    construction: 1,
    progress: 0,
    stored: 0,
    durability: 100,
    upgrade: 1,
    charge: 120,
  });
  addFollower(w, 0.02);
  if (demo) {
    w.level = 8;
    w.mana = 24;
    w.gold = 650;
    w.awe = 15;
    w.stats.converted = 10;
    w.stats.rain = 3;
    w.stats.miracles = 8;
    const types: BuildingType[] = [
      "farm",
      "tent",
      "windmill",
      "garden",
      "fountain",
      "farm",
      "campfire",
      "mine",
      "fishing",
      "workshop",
    ];
    types.forEach((type, i) =>
      w.buildings.push({
        id: `b${w.nextId++}`,
        type,
        angle: -1.45 + i * 0.3,
        construction: 1,
        progress: (i % 3) / 3,
        stored: i % 2 === 0 ? 24 : 0,
        durability: 100,
        upgrade: 1,
        charge: 180,
      }),
    );
    for (let i = 0; i < 11; i++) addFollower(w, -1.5 + i * 0.27, 75);
    w.followers[0].faith = 75;
    w.followers.forEach((f, i) => {
      f.assigned = w.buildings[i % w.buildings.length].id;
      f.task = "working";
    });
    w.terrain.forEach((t, i) => {
      if (i > 50 && i < 70) {
        t.height -= 25 * Math.sin(((i - 50) / 20) * Math.PI);
        t.water = 12;
      }
    });
  }
  return w;
}
