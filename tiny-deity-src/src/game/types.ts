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
}
export interface Follower {
  id: string;
  name: string;
  angle: number;
  origin: number;
  appearance: number;
  age: "adult";
  energy: number;
  happiness: number;
  comfort: number;
  faith: number;
  task: Task;
  assigned: string | null;
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
export interface World {
  version: 1;
  seed: number;
  name: string;
  time: number;
  tick: number;
  nextId: number;
  radius: number;
  terrain: Terrain[];
  followers: Follower[];
  buildings: Building[];
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
