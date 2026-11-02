import { describe, expect, it } from "vitest";
import { Sprite, Texture } from "pixi.js";
import { GameView } from "../src/render/GameView";
import { createWorld } from "../src/game/world";
import { ground, radial } from "../src/game/geometry";
import type { World } from "../src/game/types";

describe("follower rendering during crossings", () => {
  it.each([false, true])(
    "ignores old passing lanes with reduced effects %s",
    (reduced) => {
      const w = createWorld();
      w.buildings = [];
      w.settings.reduced = reduced;
      const [parked, walker] = w.followers;
      parked.task = "observing";
      walker.task = "traveling";
      parked.angle = walker.angle = 0.4;
      parked.lane = walker.lane = 36;
      const sprites = new Map(
        w.followers.map((f) => [f.id, new Sprite(Texture.EMPTY)]),
      );
      const textures = new Map(
        w.followers.map((f) => [`f${f.appearance}`, Texture.EMPTY]),
      );
      // Render without starting a browser application or GPU renderer.
      const view = Object.assign(Object.create(GameView.prototype), {
        sprites,
        textures,
        elapsed: 0,
        drag: null,
      }) as { renderEntities(world: World): void };
      view.renderEntities(w);
      const position = radial(parked.angle, ground(w, parked.angle));
      for (const sprite of sprites.values()) {
        expect(sprite.x).toBeCloseTo(position.x);
        expect(sprite.y).toBeCloseTo(position.y);
        expect(Math.abs(sprite.scale.x)).toBe(0.64);
        expect(sprite.scale.y).toBe(0.64);
        expect(sprite.zIndex).toBe(1);
        sprite.destroy();
      }
    },
  );
});
