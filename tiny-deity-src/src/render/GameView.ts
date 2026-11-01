import {
  Application,
  Container,
  Graphics,
  Sprite,
  Text,
  Texture,
} from "pixi.js";
import { BUILDINGS, POWERS } from "../game/data";
import {
  angleAt,
  clamp,
  distance,
  fromScreen,
  ground,
  radial,
  sample,
  toScreen,
  type Camera,
} from "../game/geometry";
import { assign, cast, collect, placement, purchase } from "../game/simulation";
import { message, useGame } from "../game/store";
import { random } from "../game/world";
import { TAU, type BuildingType, type Power, type World } from "../game/types";
import {
  buildingTexture,
  graveTexture,
  cloudTexture,
  followerTexture,
  rockTexture,
  sunTexture,
  treeTexture,
} from "./art";
interface SkyObject {
  sprite: Sprite;
  kind: Power;
  homeX: number;
  homeY: number;
  phase: number;
}
interface Drag {
  pointer: number;
  startX: number;
  startY: number;
  x: number;
  y: number;
  start: number;
  rotation: number;
  kind: "camera" | "follower" | "weather" | "terrain" | "click";
  id?: string;
  sky?: SkyObject;
  angle: number;
  original?: { x: number; y: number };
}
export class GameView {
  app = new Application();
  camera: Camera = { x: 0, y: 0, zoom: 0.8, rotation: 0 };
  targetZoom = 0.8;
  velocity = 0;
  scene = new Container();
  terrain = new Graphics();
  water = new Graphics();
  details = new Graphics();
  objects = new Container();
  fx = new Graphics();
  sky = new Container();
  preview = new Graphics();
  labels = new Container();
  private textures = new Map<string, Texture>();
  private sprites = new Map<string, Sprite>();
  private skyObjects: SkyObject[] = [];
  private drag: Drag | null = null;
  private pointers = new Map<number, { x: number; y: number }>();
  private pinch = 0;
  private pinchZoom = 0;
  private meshVersion = -1;
  private seed = -1;
  private sceneWorld: World | null = null;
  private lastSize = "";
  private observer: ResizeObserver | null = null;
  private disposed = false;
  private elapsed = 0;
  private hoverAngle = 0;
  private pointerInside = false;
  private lastFrame = performance.now();
  fps = 60;
  private labelPool: Text[] = [];
  private labelCursor = 0;
  constructor(private host: HTMLElement) {}
  async init() {
    await this.app.init({
      resizeTo: this.host,
      backgroundAlpha: 0,
      antialias: false,
      resolution: Math.min(window.devicePixelRatio || 1, 2),
      autoDensity: true,
      preference: "webgl",
      preserveDrawingBuffer: true,
    });
    if (this.disposed) {
      this.app.destroy(true);
      return;
    }
    this.app.ticker.maxFPS = 60;
    const renderer = this.app.renderer as unknown as {
      gl?: WebGLRenderingContext;
    };
    const gl = renderer.gl;
    const debug = gl?.getExtension("WEBGL_debug_renderer_info");
    if (
      gl &&
      debug &&
      /swiftshader|llvmpipe|software/i.test(
        String(gl.getParameter(debug.UNMASKED_RENDERER_WEBGL)),
      )
    )
      this.app.ticker.maxFPS = 20;
    this.host.appendChild(this.app.canvas);
    this.app.canvas.setAttribute(
      "aria-label",
      "Living planet. Drag empty space to rotate. Select a miracle, then choose the surface.",
    );
    this.app.canvas.setAttribute("role", "application");
    this.app.canvas.tabIndex = 0;
    this.app.stage.addChild(this.sky, this.scene);
    this.scene.addChild(
      this.terrain,
      this.details,
      this.water,
      this.objects,
      this.preview,
      this.fx,
      this.labels,
    );
    const put = (k: string, t: Texture) => this.textures.set(k, t);
    for (let i = 0; i < 3; i++) put(`tree${i}`, treeTexture(i));
    put("rock", rockTexture());
    put("grave", graveTexture());
    for (let i = 0; i < 6; i++) {
      put(`f${i}`, followerTexture(i));
      put(`fa${i}`, followerTexture(i, true));
    }
    Object.keys(BUILDINGS).forEach((t) =>
      put(t, buildingTexture(t as BuildingType)),
    );
    const sun = new Sprite(sunTexture());
    sun.anchor.set(0.5);
    sun.scale.set(0.8);
    this.sky.addChild(sun);
    this.skyObjects.push({
      sprite: sun,
      kind: "sun",
      homeX: 0.82,
      homeY: 0.15,
      phase: 0,
    });
    for (let i = 0; i < 4; i++) {
      const s = new Sprite(cloudTexture(i === 3));
      s.anchor.set(0.5);
      s.scale.set(i === 3 ? 0.65 : 0.8 + i * 0.1);
      s.alpha = i === 3 ? 0.8 : 0.95;
      this.sky.addChild(s);
      this.skyObjects.push({
        sprite: s,
        kind: i === 3 ? "lightning" : "rain",
        homeX: [0.12, 0.48, 0.91, 0.63][i],
        homeY: [0.19, 0.1, 0.33, 0.26][i],
        phase: i * 2,
      });
    }
    const c = this.app.canvas;
    c.addEventListener("pointerdown", this.down);
    c.addEventListener("pointermove", this.move);
    c.addEventListener("pointerup", this.up);
    c.addEventListener("pointercancel", this.cancel);
    c.addEventListener("lostpointercapture", this.lost);
    c.addEventListener("pointerleave", this.leave);
    c.addEventListener("wheel", this.wheel, { passive: false });
    c.addEventListener("contextmenu", this.context);
    window.addEventListener("keydown", this.key);
    window.addEventListener("blur", this.blur);
    this.observer = new ResizeObserver(() => this.layout());
    this.observer.observe(this.host);
    this.layout();
    this.app.ticker.add(this.frame);
  }
  private layout() {
    const w = this.host.clientWidth,
      h = this.host.clientHeight;
    const size = `${w}/${h}`;
    if (size === this.lastSize) return;
    this.lastSize = size;
    const radius = useGame.getState().world.radius;
    const mobile = w < 600;
    this.targetZoom = mobile ? 0.55 : 0.83;
    this.camera.zoom = this.targetZoom;
    this.camera.x = w / 2;
    this.camera.y = h * 0.43 + radius * this.targetZoom;
  }
  home = () => {
    const w = this.host.clientWidth;
    this.targetZoom = w < 600 ? 0.55 : 0.83;
    this.camera.rotation = 0;
    this.velocity = 0;
  };
  overview = () => {
    this.targetZoom =
      (Math.min(this.host.clientWidth, this.host.clientHeight) * 0.32) /
      useGame.getState().world.radius;
    this.velocity = 0;
  };
  zoom = (factor: number) => {
    this.targetZoom = clamp(this.targetZoom * factor, 0.15, 1.7);
  };
  rotate = (delta: number) => {
    this.camera.rotation += delta;
    this.velocity = 0;
  };
  focus = (angle: number) => {
    this.camera.rotation = -angle;
    this.velocity = 0;
    this.targetZoom = this.host.clientWidth < 600 ? 0.65 : 0.95;
  };
  snapshot = () => {
    this.app.render();
    const a = document.createElement("a");
    a.download = "tiny-deity-planet.png";
    a.href = this.app.canvas.toDataURL("image/png");
    a.click();
  };
  private point = (e: PointerEvent | WheelEvent) => {
    const r = this.app.canvas.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  private worldPoint = (x: number, y: number) => fromScreen(x, y, this.camera);
  private getAngle = (x: number, y: number) => {
    const p = this.worldPoint(x, y);
    return angleAt(p.x, p.y);
  };
  private onSurface = (x: number, y: number) => {
    const p = this.worldPoint(x, y),
      w = useGame.getState().world;
    return Math.abs(Math.hypot(p.x, p.y) - ground(w, angleAt(p.x, p.y))) < 180;
  };
  private hit = (x: number, y: number) => {
    const w = useGame.getState().world;
    let closest: {
      kind: "follower" | "building";
      id: string;
      d: number;
    } | null = null;
    for (const f of w.followers) {
      const p = radial(f.angle, ground(w, f.angle) + 17),
        s = toScreen(p.x, p.y, this.camera),
        d = Math.hypot(s.x - x, s.y - y);
      if (
        d < Math.max(17, 23 * this.camera.zoom) &&
        (!closest || d < closest.d)
      )
        closest = { kind: "follower", id: f.id, d };
    }
    if (closest) return closest;
    for (const b of w.buildings) {
      if (b.stored > 0) {
        const coin = radial(b.angle, ground(w, b.angle) + 95),
          point = toScreen(coin.x, coin.y, this.camera),
          d = Math.hypot(point.x - x, point.y - y);
        if (d < Math.max(19, 23 * this.camera.zoom))
          return { kind: "building" as const, id: b.id, d };
      }
      const p = radial(b.angle, ground(w, b.angle) + 37),
        s = toScreen(p.x, p.y, this.camera),
        d = Math.hypot(s.x - x, s.y - y);
      if (d < Math.max(25, 52 * this.camera.zoom))
        return { kind: "building" as const, id: b.id, d };
    }
    return null;
  };
  private down = (e: PointerEvent) => {
    if (e.button > 2) return;
    const p = this.point(e);
    this.pointers.set(e.pointerId, p);
    this.app.canvas.setPointerCapture(e.pointerId);
    if (this.pointers.size === 2) {
      this.restoreWeather();
      this.drag = null;
      const pts = [...this.pointers.values()];
      this.pinch = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
      this.pinchZoom = this.targetZoom;
      return;
    }
    const ui = useGame.getState();
    const hit = this.hit(p.x, p.y);
    const sky = this.skyObjects.find(
      (o) =>
        Math.hypot(o.sprite.x - p.x, o.sprite.y - p.y) <
        (o.kind === "sun" ? 40 : 55),
    );
    let kind: Drag["kind"] = "camera";
    if (e.button !== 0) kind = "camera";
    else if (ui.placing || ui.moving) kind = "click";
    else if (ui.tool !== "hand")
      kind = ["raise", "lower", "smooth"].includes(ui.tool)
        ? "terrain"
        : "click";
    else if (sky) kind = "weather";
    else if (hit?.kind === "follower") kind = "follower";
    else if (hit) kind = "click";
    this.drag = {
      pointer: e.pointerId,
      startX: p.x,
      startY: p.y,
      x: p.x,
      y: p.y,
      start: performance.now(),
      rotation: this.camera.rotation,
      kind,
      id: hit?.id,
      sky,
      angle: this.getAngle(p.x, p.y),
      original: sky ? { x: sky.sprite.x, y: sky.sprite.y } : undefined,
    };
    this.velocity = 0;
    if (kind === "follower" && hit)
      useGame.setState({
        selected: { kind: "follower", id: hit.id },
        panel: null,
      });
  };
  private move = (e: PointerEvent) => {
    const p = this.point(e);
    this.hoverAngle = this.getAngle(p.x, p.y);
    this.pointerInside = true;
    if (this.pointers.has(e.pointerId)) this.pointers.set(e.pointerId, p);
    if (this.pointers.size >= 2) {
      const pts = [...this.pointers.values()];
      const d = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
      this.targetZoom = clamp(
        (this.pinchZoom * d) / Math.max(this.pinch, 1),
        0.15,
        1.7,
      );
      return;
    }
    const drag = this.drag;
    if (!drag || drag.pointer !== e.pointerId) return;
    const dx = p.x - drag.x;
    drag.x = p.x;
    drag.y = p.y;
    if (drag.kind === "camera") {
      const diff =
        (p.x - drag.startX) /
        Math.max(250, useGame.getState().world.radius * this.camera.zoom);
      this.camera.rotation = drag.rotation + diff;
      this.velocity =
        (dx /
          Math.max(250, useGame.getState().world.radius * this.camera.zoom)) *
        0.8;
    } else if (drag.kind === "weather" && drag.sky) {
      drag.sky.sprite.position.set(p.x, p.y);
    }
  };
  private finishPointer = (e: PointerEvent) => {
    this.pointers.delete(e.pointerId);
    if (this.app.canvas.hasPointerCapture(e.pointerId))
      this.app.canvas.releasePointerCapture(e.pointerId);
  };
  private restoreWeather() {
    const d = this.drag;
    if (d?.sky && d.original)
      d.sky.sprite.position.set(d.original.x, d.original.y);
  }
  private up = (e: PointerEvent) => {
    const d = this.drag;
    const p = this.point(e);
    const wasPinch = this.pointers.size > 1;
    this.finishPointer(e);
    if (wasPinch || !d || d.pointer !== e.pointerId) {
      this.drag = null;
      return;
    }
    const moved = Math.hypot(p.x - d.startX, p.y - d.startY) > 8;
    const ui = useGame.getState(),
      w = ui.world;
    const angle = this.getAngle(p.x, p.y);
    let error: string | null = null;
    if (ui.paused && d.kind !== "camera") {
      message("Resume your world to interact.");
      this.restoreWeather();
      this.drag = null;
      return;
    }
    if (ui.placing || ui.moving) {
      if (!moved) {
        if (!this.onSurface(p.x, p.y))
          error = "Choose a spot along the grass-covered surface.";
        else if (ui.moving) {
          const b = w.buildings.find((b) => b.id === ui.moving);
          if (b) {
            error = placement(w, b.type, angle, b.id);
            if (!error) {
              b.angle = angle;
              useGame.setState({
                moving: null,
                selected: { kind: "building", id: b.id },
              });
            }
          }
        } else if (ui.placing) {
          const result = purchase(w, ui.placing, angle);
          if (typeof result === "string") error = result;
          else {
            useGame.setState({
              placing: null,
              selected: { kind: "building", id: result.id },
              tool: "hand",
            });
            message("A new beginning! Assign a follower to build it.");
          }
        }
      }
    } else if (d.kind === "follower" && d.id) {
      const f = w.followers.find((f) => f.id === d.id)!;
      if (moved && f.alive) {
        const hit = this.hit(p.x, p.y);
        const near = w.buildings.find((b) => distance(b.angle, angle) < 0.065);
        if (near && (hit?.kind === "building" || this.onSurface(p.x, p.y)))
          error = assign(w, f.id, near.id);
        else {
          f.angle = angle;
          f.origin = angle;
          assign(w, f.id, null);
          message("A soft landing. A very surprised little friend.");
        }
      }
    } else if (d.kind === "weather" && d.sky) {
      if (ui.world.settings.classic && performance.now() - d.start < 450)
        error =
          "Hold a cloud or the sun briefly, then swipe toward the surface.";
      else if (
        this.onSurface(p.x, p.y) &&
        (moved || performance.now() - d.start > 450)
      )
        error = cast(w, d.sky.kind, angle);
      else if (!moved)
        message(
          "Drag this " +
            (d.sky.kind === "sun" ? "sun" : "cloud") +
            " toward your planet to perform a miracle.",
        );
      this.restoreWeather();
    } else if (ui.tool !== "hand" && d.kind !== "camera") {
      if (!this.onSurface(p.x, p.y))
        error = "Choose a spot on the surface of your planet.";
      else
        error = cast(
          w,
          ui.tool,
          d.kind === "terrain" ? d.angle : angle,
          d.kind === "terrain" ? Math.max(1, (d.startY - p.y) / 35) : 1,
        );
    } else if (!moved) {
      const hit = this.hit(p.x, p.y);
      if (hit) {
        if (hit.kind === "building") {
          const gold = collect(w, hit.id);
          if (gold) message(`A golden little harvest. +${gold} gold`);
        }
        useGame.setState({
          selected: { kind: hit.kind, id: hit.id },
          panel: null,
        });
      } else useGame.setState({ selected: null });
    }
    if (error) message(error);
    useGame.getState().refresh();
    this.drag = null;
  };
  private cancel = (e: PointerEvent) => {
    this.restoreWeather();
    this.drag = null;
    this.finishPointer(e);
  };
  private lost = () => {
    if (this.pointers.size === 0) {
      this.restoreWeather();
      this.drag = null;
    }
  };
  private leave = () => {
    this.pointerInside = false;
  };
  private context = (e: Event) => e.preventDefault();
  private wheel = (e: WheelEvent) => {
    e.preventDefault();
    this.zoom(Math.exp(-e.deltaY * 0.001));
  };
  private blur = () => {
    this.restoreWeather();
    this.drag = null;
    this.pointers.clear();
    this.velocity = 0;
  };
  private key = (e: KeyboardEvent) => {
    if ((e.target as HTMLElement)?.matches("input,textarea,select,button"))
      return;
    const ui = useGame.getState();
    if (e.key === "Escape") {
      useGame.setState({
        panel: null,
        selected: null,
        placing: null,
        moving: null,
        tool: "hand",
      });
      return;
    }
    if (e.code === "Space") {
      e.preventDefault();
      useGame.setState({ paused: !ui.paused });
      return;
    }
    if (e.key === "ArrowLeft") {
      e.preventDefault();
      this.rotate(0.12);
    }
    if (e.key === "ArrowRight") {
      e.preventDefault();
      this.rotate(-0.12);
    }
    if (e.key.toLowerCase() === "h") this.home();
    const keys: Record<string, Power> = {
      r: "rain",
      s: "sun",
      t: "raise",
      f: "fire",
      "1": "rain",
      "2": "sun",
      "3": "raise",
      "4": "lower",
      "5": "smooth",
      "6": "lightning",
      "7": "fire",
      "8": "resurrect",
    };
    const power = keys[e.key.toLowerCase()];
    if (power) {
      if (warnLocked(power, ui.world)) return;
      useGame.setState({
        tool: power,
        placing: null,
        moving: null,
        panel: null,
      });
    }
  };
  private createSprite(key: string, texture: string): Sprite {
    const s = new Sprite(this.textures.get(texture));
    s.anchor.set(0.5, 1);
    this.objects.addChild(s);
    this.sprites.set(key, s);
    return s;
  }
  private drawTerrain(w: World) {
    const g = this.terrain;
    g.clear();
    const layer = (offset: number, color: number) => {
      const points: number[] = [];
      w.terrain.forEach((t, i) => {
        const a = (i / 512) * TAU,
          p = radial(a, w.radius + t.height - offset);
        points.push(p.x, p.y);
      });
      g.poly(points).fill(color);
    };
    layer(0, 0x5d875c);
    layer(9, 0xb5c279);
    layer(27, 0x89a563);
    layer(74, 0x6b945d);
    layer(168, 0xa3ad69);
    layer(210, 0xc1a46a);
    layer(226, 0xcdb67a);
    layer(285, 0xbca06d);
    layer(318, 0xa78b64);
    layer(440, 0x917a5d);
    layer(620, 0x7d7058);
    const detail = this.details;
    detail.clear();
    const rng = random(w.seed);
    for (let i = 0; i < 330; i++) {
      const a = rng() * TAU,
        r = Math.sqrt(rng()) * (w.radius - 30),
        p = radial(a, r),
        sz = 3 + rng() * 14;
      detail.ellipse(p.x, p.y, sz * 1.5, sz).fill({
        color: [0xd4c28b, 0x8e9762, 0x6b8559, 0xe1c58b][i % 4],
        alpha: 0.28,
      });
      if (i % 4 === 0)
        detail
          .ellipse(p.x - 2, p.y - 2, sz * 0.6, sz * 0.3)
          .fill({ color: 0xf6d79a, alpha: 0.3 });
    }
    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * TAU + 0.22,
        r = w.radius * 0.7,
        p = radial(a, r);
      detail
        .circle(p.x, p.y, 35 + (i % 3) * 12)
        .stroke({ color: 0xd8bb80, width: 7, alpha: 0.35 });
      detail
        .circle(p.x + 2, p.y, 21 + (i % 3) * 12)
        .stroke({ color: 0x8e9466, width: 4, alpha: 0.3 });
    }
    this.water.clear();
    w.terrain.forEach((t, i) => {
      const a = (i / 512) * TAU,
        next = w.terrain[(i + 1) % 512],
        a2 = ((i + 1) / 512) * TAU;
      const color =
        t.fire > 0.1
          ? 0x806746
          : t.moisture < 0.24
            ? 0xb9ad69
            : t.vegetation > 0.8
              ? 0x79a465
              : 0x9ab866;
      const p = radial(a, w.radius + t.height),
        p2 = radial(a2, w.radius + next.height);
      detail.moveTo(p.x, p.y).lineTo(p2.x, p2.y).stroke({ color, width: 8 });
      if (i % 2 === 0 && t.vegetation > 0.3) {
        const top = radial(a, w.radius + t.height + 5 + (i % 3) * 3);
        detail
          .moveTo(p.x, p.y)
          .lineTo(top.x - 2, top.y)
          .stroke({ color: 0x799b55, width: 1.5 });
      }
      if (t.water > 0.5) {
        const b = radial(a, w.radius + t.height + t.water),
          b2 = radial(
            a2,
            w.radius + next.height + Math.max(next.water, t.water * 0.8),
          );
        this.water
          .poly([p.x, p.y, p2.x, p2.y, b2.x, b2.y, b.x, b.y])
          .fill({ color: 0x7bbeca, alpha: 0.8 });
        this.water
          .moveTo(b.x, b.y)
          .lineTo(b2.x, b2.y)
          .stroke({ color: 0xd9eee0, width: 2, alpha: 0.8 });
      }
    });
    this.meshVersion = w.terrainVersion;
  }
  private rebuildDecor(w: World) {
    for (const [id, s] of this.sprites) {
      if (id.startsWith("d")) {
        s.destroy();
        this.sprites.delete(id);
      }
    }
    const rng = random(w.seed + 7);
    for (let i = 0; i < 155; i++) {
      const a = (i / 155) * TAU + (rng() - 0.5) * 0.03;
      if (
        w.buildings.some((b) => distance(b.angle, a) < 0.065) ||
        distance(a, 0.02) < 0.045
      )
        continue;
      const isTree = i % 3 !== 0;
      const s = this.createSprite(`d${i}`, isTree ? `tree${i % 3}` : "rock");
      s.label = `${a}`;
      s.scale.set(isTree ? 0.37 + rng() * 0.24 : 0.5 + rng() * 0.25);
      s.alpha = 1;
    }
    this.seed = w.seed;
  }
  private renderEntities(w: World) {
    const live = new Set<string>();
    for (const [id, s] of this.sprites) {
      if (!id.startsWith("d")) continue;
      const a = Number(s.label),
        p = radial(a, ground(w, a));
      s.position.set(p.x, p.y);
      s.rotation = a;
      const t = sample(w.terrain, a);
      if (id && s.texture !== this.textures.get("rock")) {
        s.visible =
          t.vegetation > 0.28 &&
          t.fire < 0.2 &&
          !w.buildings.some((b) => distance(b.angle, a) < 0.06);
        s.rotation = a + Math.sin(this.elapsed * 1.2 + a * 20) * 0.014;
        s.tint = t.moisture < 0.25 ? 0xd4c28b : 0xffffff;
      } else {
        s.visible =
          t.rock > 0.35 &&
          !w.buildings.some((b) => distance(b.angle, a) < 0.06);
      }
    }
    for (const b of w.buildings) {
      live.add(b.id);
      let s = this.sprites.get(b.id);
      if (!s) s = this.createSprite(b.id, b.type);
      s.texture = this.textures.get(b.type)!;
      const p = radial(b.angle, ground(w, b.angle));
      s.position.set(p.x, p.y);
      s.rotation = b.angle;
      s.scale.set(0.73 + (b.upgrade - 1) * 0.035);
      s.alpha = b.construction < 1 ? 0.5 : 0.99;
      s.tint = b.durability < 30 ? 0xc2a193 : 0xffffff;
    }
    for (const f of w.followers) {
      live.add(f.id);
      let s = this.sprites.get(f.id);
      if (!s) s = this.createSprite(f.id, `f${f.appearance}`);
      const animated = [
        "working",
        "worshipping",
        "constructing",
        "observing",
        "frightened",
        "fishing",
      ].includes(f.task);
      s.texture = this.textures.get(
        `${animated && Math.sin(this.elapsed * 5) > 0 ? "fa" : "f"}${f.appearance}`,
      )!;
      const p = radial(f.angle, ground(w, f.angle));
      s.position.set(p.x, p.y);
      s.rotation =
        f.angle +
        (f.task === "wandering"
          ? Math.sin(this.elapsed * 8 + f.appearance) * 0.06
          : 0);
      s.scale.set(0.64);
      s.alpha = f.faith < 50 ? 0.88 : 1;
      s.tint = f.alive ? 0xffffff : 0x87908a;
      if (!f.alive) {
        s.texture = this.textures.get("grave")!;
        s.rotation = f.angle;
        s.scale.set(0.65);
        s.tint = 0xffffff;
      }
      if (
        this.drag?.kind === "follower" &&
        this.drag.id === f.id &&
        Math.hypot(
          this.drag.x - this.drag.startX,
          this.drag.y - this.drag.startY,
        ) > 8
      ) {
        const dragP = this.worldPoint(this.drag.x, this.drag.y);
        s.position.set(dragP.x, dragP.y);
        s.rotation = -this.camera.rotation;
      }
    }
    for (const [id, s] of this.sprites) {
      if (!id.startsWith("d") && !live.has(id)) {
        s.destroy();
        this.sprites.delete(id);
      }
    }
  }
  private frame = () => {
    if (this.disposed) return;
    const now = performance.now(),
      dt = Math.min(0.25, (now - this.lastFrame) / 1000);
    this.lastFrame = now;
    this.elapsed += dt;
    this.fps = this.fps * 0.95 + 0.05 / Math.max(dt, 0.001);
    const ui = useGame.getState(),
      w = ui.world;
    const W = this.host.clientWidth,
      H = this.host.clientHeight;
    if (this.sceneWorld !== w) {
      this.sceneWorld = w;
      this.meshVersion = -1;
      this.rebuildDecor(w);
    }
    if (this.seed !== w.seed) this.rebuildDecor(w);
    this.camera.zoom +=
      (this.targetZoom - this.camera.zoom) * Math.min(1, dt * 9);
    if (!this.drag) {
      this.camera.rotation += this.velocity;
      this.velocity *= Math.pow(0.025, dt);
    }
    this.camera.x = W / 2;
    const overview = this.camera.zoom < 0.42;
    const overviewZoom = (Math.min(W, H) * 0.32) / w.radius;
    const blend = clamp((this.camera.zoom - overviewZoom) / 0.2, 0, 1);
    this.camera.y =
      H * 0.5 * (1 - blend) + (H * 0.43 + w.radius * this.camera.zoom) * blend;
    this.scene.position.set(this.camera.x, this.camera.y);
    this.scene.scale.set(this.camera.zoom);
    this.scene.rotation = this.camera.rotation;
    for (const o of this.skyObjects) {
      if (this.drag?.sky === o) continue;
      const drift = w.settings.reduced
        ? 0
        : Math.sin(this.elapsed * 0.035 + o.phase) * W * 0.055;
      o.sprite.position.set(
        W * o.homeX + drift,
        H * o.homeY +
          (w.settings.reduced
            ? 0
            : Math.sin(this.elapsed * 0.25 + o.phase) * 5),
      );
      if (o.kind === "lightning") o.sprite.visible = w.level >= 3;
    }
    if (this.meshVersion !== w.terrainVersion) this.drawTerrain(w);
    this.renderEntities(w);
    this.drawFeedback(w, overview);
  };
  private drawFeedback(w: World, _overview: boolean) {
    const g = this.fx;
    g.clear();
    this.labelCursor = 0;
    this.labelPool.forEach((t) => (t.visible = false));
    const label = (
      text: string,
      a: number,
      offset: number,
      color = "#fff5ce",
      size = 14,
    ) => {
      const p = radial(a, ground(w, a) + offset);
      let t = this.labelPool[this.labelCursor++];
      if (!t) {
        t = new Text({
          text,
          style: {
            fontFamily: "Trebuchet MS, sans-serif",
            fontSize: size,
            fontWeight: "bold",
            fill: color,
            stroke: { color: "#5b634d", width: 2 },
          },
        });
        t.anchor.set(0.5);
        this.labelPool.push(t);
        this.labels.addChild(t);
      }
      t.text = text;
      t.style.fontSize = size;
      t.style.fill = color;
      t.visible = true;
      t.position.set(p.x, p.y);
      t.rotation = -this.camera.rotation;
    };
    for (const b of w.buildings) {
      const p = radial(b.angle, ground(w, b.angle) + 6);
      if (b.construction < 1) {
        const a = b.angle,
          c = Math.cos(a),
          s = Math.sin(a);
        const local = (x: number, y: number) => ({
          x: p.x + x * c - y * s,
          y: p.y + x * s + y * c,
        });
        for (const x of [-38, 38]) {
          const l = local(x, 0),
            top = local(x, -68);
          g.moveTo(l.x, l.y)
            .lineTo(top.x, top.y)
            .stroke({ color: 0xb99568, width: 4 });
        }
        for (const y of [-20, -48]) {
          const l = local(-44, y),
            r = local(44, y);
          g.moveTo(l.x, l.y)
            .lineTo(r.x, r.y)
            .stroke({ color: 0xc1a375, width: 4 });
        }
        label(`${Math.floor(b.construction * 100)}%`, b.angle, 92);
      } else if (b.stored > 0) {
        const c = radial(
          b.angle,
          ground(w, b.angle) + 95 + Math.sin(this.elapsed * 2) * 3,
        );
        g.ellipse(c.x, c.y, 15, 10)
          .fill(0xe8be65)
          .stroke({ color: 0xb58d48, width: 2 });
        g.ellipse(c.x - 2, c.y - 3, 8, 4).fill(0xf6d88a);
        label(`+${b.stored}`, b.angle, 119, "#fff1ae", 13);
      } else if (b.progress > 0) {
        const c = radial(b.angle, ground(w, b.angle) + 84);
        g.roundRect(c.x - 20, c.y - 3, 40, 5, 2).fill(0x6f795d);
        g.roundRect(c.x - 20, c.y - 3, 40 * b.progress, 5, 2).fill(0xe6ce8c);
      }
    }
    const ui = useGame.getState();
    if (ui.selected) {
      const f =
        ui.selected.kind === "follower"
          ? w.followers.find((f) => f.id === ui.selected!.id)
          : null;
      const b =
        ui.selected.kind === "building"
          ? w.buildings.find((b) => b.id === ui.selected!.id)
          : null;
      const a = f?.angle ?? b?.angle;
      if (a !== undefined) {
        const p = radial(a, ground(w, a) + 2);
        g.ellipse(p.x, p.y, f ? 17 : 48, 5).stroke({
          color: 0xffefb0,
          width: 3,
        });
      }
    }
    w.followers.forEach((f) => {
      if (!f.alive) {
        label("†", f.angle, 25, "#c6c4ac", 26);
        return;
      }
      const bubble =
        f.faith < 50
          ? "?"
          : f.energy < 20
            ? "Zz"
            : f.comfort < 35
              ? "…"
              : f.task === "observing"
                ? "♡"
                : f.task === "worshipping"
                  ? "✧"
                  : null;
      if (bubble) label(bubble, f.angle, 56, "#fff5d9", 16);
    });
    if (w.monster) {
      const p = radial(w.monster.angle, ground(w, w.monster.angle) + 16);
      g.ellipse(p.x, p.y, 16, 22)
        .fill(0x686278)
        .stroke({ color: 0x4f5062, width: 2 });
      g.circle(p.x - 6, p.y - 4, 3).fill(0xf0be78);
      g.circle(p.x + 6, p.y - 4, 3).fill(0xf0be78);
      label("Shadowling", w.monster.angle, 55, "#f5cf9b", 12);
    }
    for (const e of w.effects) {
      const progress = 1 - e.life / 3,
        a = e.angle,
        p = radial(a, ground(w, a));
      const local = (x: number, y: number) => ({
        x: p.x + x * Math.cos(a) - y * Math.sin(a),
        y: p.y + x * Math.sin(a) + y * Math.cos(a),
      });
      const count = w.settings.reduced ? 12 : 55;
      if (e.type === "rain") {
        for (let i = 0; i < count; i++) {
          const x = ((i % 11) - 5) * 10,
            y = -200 + ((this.elapsed * 260 + i * 19) % 190);
          const start = local(x, y),
            end = local(x - 3, y + 10);
          g.moveTo(start.x, start.y)
            .lineTo(end.x, end.y)
            .stroke({ color: 0x8dc9da, width: 2, alpha: Math.min(1, e.life) });
        }
        g.ellipse(p.x, p.y + 3, 60 + Math.sin(this.elapsed * 6) * 5, 7).stroke({
          color: 0xbce6e5,
          width: 2,
          alpha: e.life / 3,
        });
      } else if (e.type === "lightning" && e.life > 2) {
        const points = [
          [-12, -230],
          [10, -150],
          [-15, -145],
          [4, -70],
          [-8, -75],
          [0, 0],
        ].map(([x, y]) => local(x, y));
        points.forEach((point, i) =>
          i ? g.lineTo(point.x, point.y) : g.moveTo(point.x, point.y),
        );
        g.stroke({ color: 0xffebae, width: 7 });
        const branch = local(28, -100);
        g.moveTo(points[1].x, points[1].y)
          .lineTo(branch.x, branch.y)
          .stroke({ color: 0xffefc3, width: 3 });
        g.circle(p.x, p.y, 60 * (3 - e.life)).stroke({
          color: 0xffefc1,
          width: 3,
          alpha: e.life - 2,
        });
      } else if (e.type === "fire") {
        for (let i = 0; i < 16; i++) {
          const x = p.x + ((i % 8) - 4) * 11,
            y = p.y - ((this.elapsed * 50 + i * 17) % 60);
          g.ellipse(x, y, 5, 12).fill({
            color: i % 2 ? 0xf3c96d : 0xd78c51,
            alpha: Math.min(e.life, 1),
          });
        }
      } else if (e.type === "sun") {
        for (let i = 0; i < 9; i++) {
          const x = (i - 4) * 17,
            start = local(x - 40, -200),
            end = local(x, -10);
          g.moveTo(start.x, start.y)
            .lineTo(end.x, end.y)
            .stroke({ color: 0xffe39d, width: 4, alpha: e.life * 0.1 });
        }
        if (w.discoveries.includes("Rainbow")) {
          for (let i = 0; i < 4; i++)
            g.arc(p.x, p.y - 40, 95 + i * 8, Math.PI, TAU).stroke({
              color: [0xe5ad9d, 0xe9ce8b, 0xa4c693, 0x9ebfc2][i],
              width: 6,
              alpha: e.life * 0.2,
            });
        }
      } else {
        for (let i = 0; i < 10; i++) {
          const x = p.x + Math.sin(i * 2.4) * progress * 75,
            y = p.y - 30 - progress * 90 + Math.cos(i) * 20;
          g.circle(x, y, 2 + (i % 3)).fill({
            color: 0xf7dda0,
            alpha: 1 - progress,
          });
        }
      }
    }
    w.terrain.forEach((t, i) => {
      if (t.fire > 0.15 && i % 3 === 0) {
        const p = radial(
          (i / 512) * TAU,
          ground(w, (i / 512) * TAU) + 8 + Math.sin(this.elapsed * 8 + i) * 5,
        );
        g.ellipse(p.x, p.y, 5, 12).fill({ color: 0xe4a05e, alpha: t.fire });
      }
    });
    this.preview.clear();
    if ((ui.placing || ui.moving || ui.tool !== "hand") && this.pointerInside) {
      const type =
        ui.placing || w.buildings.find((b) => b.id === ui.moving)?.type;
      const valid = type
        ? !placement(w, type, this.hoverAngle, ui.moving ?? undefined)
        : w.mana >= POWERS[ui.tool as Power].cost;
      const p = radial(this.hoverAngle, ground(w, this.hoverAngle));
      this.preview
        .ellipse(p.x, p.y, type ? 52 : 75, type ? 12 : 18)
        .stroke({ color: valid ? 0xe6efb3 : 0xd88776, width: 3, alpha: 0.9 });
      if (type)
        this.preview
          .circle(p.x, p.y - 40, 28)
          .fill({ color: valid ? 0xc6dfaa : 0xd89585, alpha: 0.2 });
    }
    if (w.rune) {
      const a = 0.72,
        p = radial(a, ground(w, a) + 30);
      g.poly([p.x, p.y - 15, p.x + 10, p.y, p.x, p.y + 15, p.x - 10, p.y])
        .fill(0xd9c6eb)
        .stroke({ color: 0xffe8bd, width: 3 });
    }
    if (this.drag?.kind === "weather") {
      const d = this.drag,
        amount = clamp((performance.now() - d.start) / 600, 0, 1);
      g.visible = true;
      const p = this.worldPoint(d.x, d.y);
      g.circle(p.x, p.y, 50 / this.camera.zoom)
        .arc(
          p.x,
          p.y,
          50 / this.camera.zoom,
          -Math.PI / 2,
          -Math.PI / 2 + amount * TAU,
        )
        .stroke({ color: 0xf9dfa0, width: 3 / this.camera.zoom, alpha: 0.7 });
    }
  }
  destroy() {
    this.disposed = true;
    this.observer?.disconnect();
    window.removeEventListener("keydown", this.key);
    window.removeEventListener("blur", this.blur);
    if (this.app.renderer) {
      this.app.ticker.remove(this.frame);
      this.app.destroy(true, { children: true });
    }
    for (const t of this.textures.values()) t.destroy(true);
  }
}
function warnLocked(p: Power, w: World) {
  if (w.level < POWERS[p].level) {
    message(`${POWERS[p].name} unlocks at level ${POWERS[p].level}.`);
    return true;
  }
  return false;
}
