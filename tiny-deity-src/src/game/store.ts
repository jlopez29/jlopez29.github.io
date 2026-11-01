import { create } from "zustand";
import type { World, Tool, BuildingType } from "./types";
import { createWorld } from "./world";
interface UI {
  world: World;
  revision: number;
  tool: Tool;
  panel:
    | "store"
    | "goals"
    | "settings"
    | "help"
    | "followers"
    | "discoveries"
    | null;
  selected: { kind: "follower" | "building"; id: string } | null;
  placing: BuildingType | null;
  moving: string | null;
  paused: boolean;
  ready: boolean;
  toast: string;
  saveStatus: string;
  refresh: () => void;
}
export const useGame = create<UI>((set) => ({
  world: createWorld(),
  revision: 0,
  tool: "hand",
  panel: null,
  selected: null,
  placing: null,
  moving: null,
  paused: false,
  ready: false,
  toast: "",
  saveStatus: "Starting…",
  refresh: () => set((s) => ({ revision: s.revision + 1 })),
}));
export function message(toast: string) {
  useGame.setState({ toast });
}
