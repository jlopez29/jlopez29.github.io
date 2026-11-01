export const TAU = Math.PI * 2;
export type Power =
  | "rain"
  | "sun"
  | "lightning"
  | "raise"
  | "lower"
  | "smooth"
  | "fire"
  | "resurrect";
export type Tool = "hand" | Power;
export type BuildingType =
  | "logging"
  | "collector"
  | "shrine"
  | "farm"
  | "tent"
  | "campfire"
  | "garden"
  | "fountain"
  | "windmill"
  | "mine"
  | "fishing"
  | "workshop"
  | "observatory"
  | "temple";
export type Task =
  | "idle"
  | "carried"
  | "traveling"
  | "seekingResources"
  | "fleeing"
  | "wandering"
  | "observing"
  | "working"
  | "worshipping"
  | "constructing"
  | "resting"
  | "fishing"
  | "frightened"
  | "exhausted"
  | "recovering"
  | "dead";
export interface Terrain {
  height: number;
  moisture: number;
  heat: number;
  fertility: number;
  vegetation: number;
  water: number;
  fire: number;
  rock: number;
  wood: number;
  stone: number;
  regrowth: number;
  harvesting: number;
}
export interface Follower {
  manual?: boolean;
  jobCooldown?: number;
  returnManual?: boolean;
  id: string;
  name: string;
  angle: number;
  origin: number;
  appearance: number;
  age: "adult";
  energy: number;
  hunger: number;
  happiness: number;
  comfort: number;
  faith: number;
  task: Task;
  assigned: string | null;
  slot: number | null;
  facing: number;
  lane: number;
  returnTo: string | null;
  speed: number;
  proficiency: number;
  alive: boolean;
  trait: string;
  timer: number;
}
export interface Building {
  id: string;
  type: BuildingType;
  angle: number;
  construction: number;
  progress: number;
  stored: number;
  durability: number;
  upgrade: number;
  charge: number;
}
export interface Effect {
  id: number;
  type: Power | "coin" | "heart" | "rune";
  angle: number;
  life: number;
  label?: string;
}
export interface Stats {
  miracles: number;
  rain: number;
  sun: number;
  terraforms: number;
  collected: number;
  built: number;
  converted: number;
  discoveries: number;
  worship: number;
  gatheredWood: number;
  loggedWood: number;
  forestRain: number;
  explored: number;
  farmedFood: number;
}
export interface Settings {
  sound: boolean;
  reduced: boolean;
  classic: boolean;
  autonomy: boolean;
  seasons: boolean;
  speed: number;
  debug: boolean;
  events: boolean;
}
export type Resource = "wood" | "stone" | "water" | "food";
export type Inventory = Record<Resource, number>;
export interface World {
  version: 2;
  targetRadius: number;
  legacy: boolean;
  seed: number;
  name: string;
  time: number;
  tick: number;
  nextId: number;
  radius: number;
  terrain: Terrain[];
  followers: Follower[];
  buildings: Building[];
  resources: Inventory;
  capacity: Inventory;
  produced: Inventory;
  consumed: Inventory;
  resourceStats: Inventory;
  gatherAt: number;
  waitingFollowers: number;
  gold: number;
  mana: number;
  awe: number;
  xp: number;
  level: number;
  stats: Stats;
  completed: string[];
  discoveries: string[];
  log: string[];
  effects: Effect[];
  settings: Settings;
  terrainVersion: number;
  undo: number[] | null;
  lastRain: number;
  rune: boolean;
  expansions: number;
  lastSaved: number;
  eventAt: number;
  monster: { angle: number; health: number } | null;
}
export interface BuildingDef {
  name: string;
  tagline: string;
  cost: number;
  level: number;
  capacity: number;
  output: number;
  duration: number;
  need: "rain" | "sun" | "water" | null;
  role: "produce" | "worship" | "rest" | "beauty";
  color: string;
}
