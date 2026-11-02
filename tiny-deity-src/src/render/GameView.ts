import {
  Application,
  Container,
  Graphics,
  Sprite,
  Text,
  Texture,
} from "pixi.js";
import { BUILDINGS, POWERS, recipeText } from "../game/data";
import {
  angleAt,
  clamp,
  distance,
  deform,
  fromScreen,
  ground,
  radial,
  sample,
  toScreen,
  type Camera,
} from "../game/geometry";
import { nearby, materialError } from "../game/economy";
import {
  grab,
  gainXP,
  effect,
  landFollower,
  releaseCarried,
  assign,
  cast,
  collect,
  placement,
  purchase,
} from "../game/simulation";
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
  threshold: number;
  touch: boolean;
  lastAngle?: number;
  moved: boolean;
  sculpted: number;
  lastSculpt: number;
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
  private visualLanes = new Map<string, number>();
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
      this.app.ticker.maxFPS = 10;
    this.host.appendChild(this.app.canvas);
    this.app.canvas.setAttribute(
      "aria-label",
      "Living planet. Drag empty space to rotate. Select a miracle, then choose the surface.",
    );
    this.app.canvas.setAttribute("role", "application");
    this.app.canvas.tabIndex = 0;
    this.app.stage.addChild(this.sky, this.scene);
    this.objects.sortableChildren = true;
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
    this.targetZoom = Math.min(w * (mobile ? 0.47 : 0.4), h * 0.34) / radius;
    this.camera.zoom = this.targetZoom;
    this.camera.x = w / 2;
    this.camera.y = h * 0.43 + radius * this.targetZoom;
  }
  home = () => {
    const w = this.host.clientWidth,
      h = this.host.clientHeight;
    this.targetZoom =
      Math.min(w * (w < 600 ? 0.47 : 0.4), h * 0.34) /
      useGame.getState().world.radius;
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
    const minZoom = Math.min(
      0.15,
      (Math.min(this.host.clientWidth, this.host.clientHeight) * 0.25) /
        useGame.getState().world.radius,
    );
    this.targetZoom = clamp(this.targetZoom * factor, minZoom, 1.7);
  };
  rotate = (delta: number) => {
    this.camera.rotation += delta;
    useGame.getState().world.stats.explored++;
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
          return { kind: "building" as const, id: b.id, d, collection: true };
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
    this.pointerInside = true;
    this.hoverAngle = this.getAngle(p.x, p.y);
    this.pointers.set(e.pointerId, p);
    this.app.canvas.setPointerCapture(e.pointerId);
    if (this.pointers.size >= 2) {
      this.restoreWeather();
      releaseCarried(useGame.getState().world);
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
        o.sprite.visible &&
        Math.hypot(o.sprite.x - p.x, o.sprite.y - p.y) <
          (o.kind === "sun" ? 40 : 55),
    );
    let kind: Drag["kind"] = "camera";
    if (e.button !== 0) kind = "camera";
    else if (ui.placing || ui.moving) kind = "click";
    else if (ui.tool === "hand" && hit)
      kind = hit.kind === "follower" ? "follower" : "click";
    else if (sky && !["raise", "lower", "smooth"].includes(ui.tool))
      kind = "weather";
    else if (ui.tool !== "hand")
      kind = ["raise", "lower", "smooth"].includes(ui.tool)
        ? "terrain"
        : "click";
    else if (sky) kind = "weather";
    else if (hit?.kind === "follower") kind = "follower";
    else if (hit) kind = "click";
    this.drag = {
      pointer: e.pointerId,
      touch: e.pointerType === "touch",
      threshold: e.pointerType === "touch" ? 14 : 8,
      moved: false,
      sculpted: 0,
      lastSculpt: 0,
      startX: p.x,
      startY: p.y,
      x: p.x,
      y: p.y,
      start: e.timeStamp,
      rotation: this.camera.rotation,
      kind,
      id: hit?.id,
      sky,
      angle: this.getAngle(p.x, p.y),
      original: sky ? { x: sky.sprite.x, y: sky.sprite.y } : undefined,
    };
    this.velocity = 0;
    useGame.setState({ selected: null, panel: null });
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
    drag.moved ||=
      Math.hypot(p.x - drag.startX, p.y - drag.startY) > drag.threshold;
    if (
      !useGame.getState().paused &&
      drag.kind === "follower" &&
      drag.id &&
      drag.moved
    ) {
      const w = useGame.getState().world;
      if (w.followers.find((f) => f.id === drag.id)?.task !== "carried")
        grab(w, drag.id);
    }
    const dx = p.x - drag.x;
    drag.x = p.x;
    drag.y = p.y;
    if (
      drag.kind === "camera" ||
      (drag.kind === "click" &&
        drag.moved &&
        (useGame.getState().placing || useGame.getState().moving))
    ) {
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
    this.drag = null;
    this.finishPointer(e);
    this.drag = d;
    if (wasPinch || !d || d.pointer !== e.pointerId) {
      this.drag = null;
      return;
    }
    const moved =
      d.moved || Math.hypot(p.x - d.startX, p.y - d.startY) > d.threshold;
    const ui = useGame.getState(),
      w = ui.world;
    const angle = this.getAngle(p.x, p.y);
    let error: string | null = null;
    if (ui.paused && d.kind !== "camera") {
      message("Resume your world to interact.");
      releaseCarried(w);
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
            message("Believers will help build here.");
          }
        }
      }
    } else if (d.kind === "follower" && d.id) {
      const f = w.followers.find((f) => f.id === d.id)!;
      if (moved && f.alive && f.task === "carried") {
        const hit = this.hit(p.x, p.y);
        const near = w.buildings.find((b) => distance(b.angle, angle) < 0.065);
        if (near && (hit?.kind === "building" || this.onSurface(p.x, p.y))) {
          error = assign(w, f.id, near.id);
          if (!error) {
            effect(w, "heart", near.angle);
            w.effects[w.effects.length - 1].label = "Assigned ✓";
          }
        } else if (this.onSurface(p.x, p.y)) {
          landFollower(w, f.id, angle);
          effect(w, "heart", angle);
        }
      } else if (!moved && e.timeStamp - d.start < 500) {
        useGame.setState({
          selected: { kind: "follower", id: f.id },
          panel: null,
        });
      }
    } else if (d.kind === "weather" && d.sky) {
      if (ui.world.settings.classic && e.timeStamp - d.start < 450)
        error =
          "Hold a cloud or the sun briefly, then swipe toward the surface.";
      else if (
        this.onSurface(p.x, p.y) &&
        (moved || e.timeStamp - d.start > 450)
      )
        error = cast(w, d.sky.kind, angle);
      else if (!moved)
        message(
          "Drag this " +
            (d.sky.kind === "sun" ? "sun" : "cloud") +
            " toward your planet to perform a miracle.",
        );
      this.restoreWeather();
    } else if (d.kind === "terrain") {
      this.sculpt(d, performance.now());
      if (d.sculpted > 0) {
        effect(w, "heart", angle);
        w.effects[w.effects.length - 1].label = "World shaped +1 XP";
      }
    } else if (ui.tool !== "hand" && d.kind !== "camera") {
      if (!this.onSurface(p.x, p.y))
        error = "Choose a spot on the surface of your planet.";
      else error = cast(w, ui.tool, angle, 1);
    } else if (!moved) {
      const hit = this.hit(p.x, p.y);
      if (hit) {
        if (hit.kind === "building" && "collection" in hit) {
          const gold = collect(w, hit.id);
          if (gold) {
            message(`A golden little harvest. +${gold} gold`);
            useGame.setState({ selected: null });
            this.drag = null;
            return;
          }
        }
        useGame.setState({
          selected: { kind: hit.kind, id: hit.id },
          panel: null,
        });
      } else {
        useGame.setState({ selected: null });
      }
    }
    releaseCarried(w);
    if (error) message(error);
    useGame.getState().refresh();
    this.drag = null;
  };
  private sculpt(d: Drag, now: number) {
    const ui = useGame.getState(),
      w = ui.world;
    if (
      ui.paused ||
      (d.touch && now - d.start < 120) ||
      !["raise", "lower", "smooth"].includes(ui.tool) ||
      !this.onSurface(d.x, d.y) ||
      this.pointers.size > 1 ||
      now - d.lastSculpt < 50
    )
      return;
    if (w.level < POWERS[ui.tool as Power].level) return;
    if (d.sculpted % 40 === 0) {
      if (w.mana < 1) return;
      w.mana -= 1;
      if (!d.sculpted) {
        w.undo = w.terrain.map((t) => t.height);
        w.stats.terraforms++;
        w.stats.miracles++;
        // Fixed reward per paid stroke, never per pointer event.
        gainXP(w, 1);
      }
    }
    const angle = this.getAngle(d.x, d.y);
    const previous = d.lastAngle ?? angle;
    const delta = Math.atan2(
      Math.sin(angle - previous),
      Math.cos(angle - previous),
    );
    const segments = Math.min(
      16,
      Math.max(1, Math.ceil(Math.abs(delta) / (ui.brush * 0.4))),
    );
    for (let i = 1; i <= segments; i++)
      deform(
        w,
        previous + (delta * i) / segments,
        (ui.tool === "raise" ? 2 : -2) / Math.sqrt(segments),
        ui.tool === "smooth",
        ui.brush,
        false,
      );
    d.lastAngle = angle;
    d.lastSculpt = now;
    d.sculpted++;
  }
  private cancel = (e: PointerEvent) => {
    this.restoreWeather();
    releaseCarried(useGame.getState().world);
    this.drag = null;
    this.finishPointer(e);
  };
  private lost = (e: PointerEvent) => {
    this.pointers.delete(e.pointerId);
    if (this.drag?.pointer === e.pointerId) {
      releaseCarried(useGame.getState().world);
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
    releaseCarried(useGame.getState().world);
    this.drag = null;
    this.pointers.clear();
    this.velocity = 0;
  };
  private key = (e: KeyboardEvent) => {
    if ((e.target as HTMLElement)?.matches("input,textarea,select,button"))
      return;
    const ui = useGame.getState();
    if (e.key === "Escape") {
      this.blur();
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
    layer(0, 0x218e42);
    layer(9, 0x9bed4e);
    layer(27, 0x69d83f);
    layer(74, 0x439d3e);
    layer(168, 0xb89854);
    layer(210, 0xb88049);
    layer(226, 0xe4b86a);
    layer(285, 0xad7445);
    layer(318, 0x94623f);
    layer(440, 0x774832);
    layer(620, 0x5c382c);
    const detail = this.details;
    detail.clear();
    const rng = random(w.seed);
    for (let i = 0; i < 330; i++) {
      const a = rng() * TAU,
        r = Math.sqrt(rng()) * (w.radius - 30),
        p = radial(a, r),
        sz = 3 + rng() * 14;
      detail.ellipse(p.x, p.y, sz * 1.5, sz).fill({
        color: [0xf1c374, 0x8f643d, 0x9d723e, 0xe2b166][i % 4],
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
      const neighbors = [-2, -1, 0, 1, 2].map(
        (d) => w.terrain[(i + d + w.terrain.length) % w.terrain.length],
      );
      const avg = (key: "moisture" | "vegetation" | "rock" | "fertility") =>
        neighbors.reduce((sum, cell) => sum + cell[key], 0) / neighbors.length;
      const mix = (a: number, b: number, t: number) => {
        t = clamp(t, 0, 1);
        return [16, 8, 0].reduce(
          (color, shift) =>
            color |
            (Math.round(
              ((a >> shift) & 255) * (1 - t) + ((b >> shift) & 255) * t,
            ) <<
              shift),
          0,
        );
      };
      let color = mix(0xe4bd58, 0x69d83f, avg("moisture") * 2.5);
      color = mix(color, 0x167537, (avg("vegetation") - 0.35) * 1.6);
      color = mix(color, 0x8797a4, avg("rock") * 0.8);
      if (t.fire > 0.1) color = 0x614735;
      const p = radial(a, w.radius + t.height),
        p2 = radial(a2, w.radius + next.height);
      detail.moveTo(p.x, p.y).lineTo(p2.x, p2.y).stroke({ color, width: 8 });
      if (i % 2 === 0 && t.vegetation > 0.3) {
        const top = radial(a, w.radius + t.height + 5 + (i % 3) * 3);
        detail
          .moveTo(p.x, p.y)
          .lineTo(top.x - 2, top.y)
          .stroke({ color: 0x4cae30, width: 1.5 });
      }
      if (
        i % 5 === 0 &&
        t.fertility > 0.65 &&
        t.moisture > 0.3 &&
        t.water < 1 &&
        t.vegetation > 0.2 &&
        t.fire < 0.1
      ) {
        const flower = radial(a, w.radius + t.height + 8);
        detail.circle(flower.x, flower.y, 3).fill(i % 2 ? 0xffe044 : 0xff78b0);
        detail.circle(flower.x, flower.y, 1).fill(0xffffff);
      }
      if (t.water > 0.5) {
        const b = radial(a, w.radius + t.height + t.water),
          b2 = radial(
            a2,
            w.radius + next.height + Math.max(next.water, t.water * 0.8),
          );
        this.water
          .poly([p.x, p.y, p2.x, p2.y, b2.x, b2.y, b.x, b.y])
          .fill({ color: 0x1ba8ed, alpha: 0.8 });
        this.water
          .moveTo(b.x, b.y)
          .lineTo(b2.x, b2.y)
          .stroke({ color: 0xa7f3ff, width: 2, alpha: 0.8 });
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
    for (let i = 0; i < 260; i++) {
      const a = (i / 260) * TAU + (rng() - 0.5) * 0.03;
      if (
        w.buildings.some((b) => distance(b.angle, a) < 0.065) ||
        distance(a, 0.02) < 0.045
      )
        continue;
      const isTree = i % 3 !== 0;
      const s = this.createSprite(`d${i}`, isTree ? `tree${i % 3}` : "rock");
      s.label = `${a}`;
      s.scale.set(isTree ? 0.46 + rng() * 0.3 : 0.55 + rng() * 0.25);
      s.alpha = 1;
    }
    this.seed = w.seed;
  }
  private renderEntities(w: World, dt: number) {
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
          t.vegetation > 0.42 + (Number(id.slice(1)) % 7) * 0.065 &&
          t.wood > 0.3 &&
          t.fire < 0.2 &&
          !w.buildings.some((b) => distance(b.angle, a) < 0.06);
        s.rotation =
          a +
          (w.settings.reduced
            ? 0
            : Math.sin(this.elapsed * 1.2 + a * 20) * 0.014);
        s.tint = t.moisture < 0.25 ? 0xd4c28b : 0xffffff;
      } else {
        s.visible =
          t.rock > 0.35 &&
          t.stone > 0.2 &&
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
      const bob = ["traveling", "seekingResources", "fleeing"].includes(
        f.task,
      )
        ? Math.abs(Math.sin(this.elapsed * 9)) * 2
        : 0;
      // Use an inner, parallel surface path. A tangent offset used to
      // move the character *towards* the person they were passing.
      const oldLane = this.visualLanes.get(f.id) ?? 0;
      // Only moving pedestrians can use the inner path. A follower who stops
      // to worship, observe or rest must stay anchored to actual ground.
      const walking = [
        "traveling",
        "wandering",
        "fleeing",
        "seekingResources",
      ].includes(f.task);
      const targetLane = walking ? Math.min(36, f.lane) : 0;
      const ease = w.settings.reduced ? 1 : 1 - Math.exp(-dt * 18);
      const lane = oldLane + (targetLane - oldLane) * ease;
      this.visualLanes.set(f.id, lane);
      const p = radial(f.angle, ground(w, f.angle) + bob - lane);
      s.position.set(p.x, p.y);
      s.zIndex = lane > 2 ? -1 : 1;
      s.rotation =
        f.angle +
        (f.task === "wandering" || f.task === "traveling"
          ? Math.sin(this.elapsed * 8 + f.appearance) * 0.06
          : 0);
      const depthScale = 1 - (lane / 36) * 0.12;
      s.scale.set(
        0.64 * depthScale * (f.facing || 1),
        (f.task === "worshipping"
          ? 0.55 + Math.sin(this.elapsed * 3 + f.appearance) * 0.05
          : 0.64) * depthScale,
      );
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
        f.task === "carried"
      ) {
        const dragP = this.worldPoint(this.drag.x, this.drag.y);
        s.position.set(dragP.x, dragP.y);
        s.rotation = -this.camera.rotation;
        s.zIndex = 5;
      }
    }
    for (const [id, s] of this.sprites) {
      if (!id.startsWith("d") && !live.has(id)) {
        this.visualLanes.delete(id);
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
    this.elapsed += useGame.getState().world.settings.reduced ? 0 : dt;
    if (this.drag?.kind === "terrain") this.sculpt(this.drag, now);
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
    const homeZoom = Math.min(W * (W < 600 ? 0.47 : 0.4), H * 0.34) / w.radius;
    const blend = clamp((this.camera.zoom - homeZoom) / 0.3, 0, 1);
    this.camera.y =
      H * 0.51 * (1 - blend) + (H * 0.43 + w.radius * this.camera.zoom) * blend;
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
    this.renderEntities(w, dt);
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
      t.style.fontSize = size / this.camera.zoom;
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
    w.terrain.forEach((t, i) => {
      if (t.water < 1 || i % 3) return;
      const a = (i / w.terrain.length) * TAU;
      const p = radial(a, w.radius + t.height + t.water);
      const shimmer = w.settings.reduced
        ? 0.65
        : 0.5 + Math.sin(this.elapsed * 2 + i) * 0.25;
      g.ellipse(p.x, p.y, 5, 1.5).fill({ color: 0xc7f6ff, alpha: shimmer });
    });
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
          : f.hunger > 55
            ? "Food?"
            : f.energy < 20
              ? "Zz"
              : f.comfort < 35
                ? "…"
                : f.task === "observing"
                  ? "♡"
                  : f.task === "worshipping"
                    ? Math.floor(w.time + f.appearance * 3) % 24 < 3
                      ? "Thank you"
                      : "✧"
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
      if (e.label) {
        label(e.label, e.angle, 65 + progress * 50, "#ffffff", 16);
        continue;
      }
      const count = w.settings.reduced ? 12 : 55;
      if (e.type === "rain") {
        for (let i = 0; i < count; i++) {
          const x = ((i % 11) - 5) * 10,
            y = -200 + ((this.elapsed * 260 + i * 19) % 190);
          const start = local(x, y),
            end = local(x - 3, y + 10);
          g.moveTo(start.x, start.y)
            .lineTo(end.x, end.y)
            .stroke({ color: 0x38bdf8, width: 2, alpha: Math.min(1, e.life) });
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
            .stroke({ color: 0xffdb43, width: 4, alpha: e.life * 0.1 });
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
      const reason = type
        ? placement(w, type, this.hoverAngle, ui.moving ?? undefined) ||
          (!ui.moving ? materialError(w, type) : null)
        : null;
      const valid = type ? !reason : w.mana >= POWERS[ui.tool as Power].cost;
      const p = radial(this.hoverAngle, ground(w, this.hoverAngle));
      this.preview
        .ellipse(p.x, p.y, type ? 52 : w.radius * ui.brush, type ? 12 : 18)
        .stroke({ color: valid ? 0xe6efb3 : 0xd88776, width: 3, alpha: 0.9 });
      if (type) {
        const forest = nearby(w, this.hoverAngle).reduce(
          (n, t) => n + t.wood,
          0,
        );
        const deposit = nearby(w, this.hoverAngle, 90).reduce(
          (n, t) => n + t.stone,
          0,
        );
        const context =
          type === "logging"
            ? `Forest: ${Math.round(forest)} wood`
            : type === "mine"
              ? `Deposit: ${Math.round(deposit)} stone`
              : type === "farm"
                ? `Fertility: ${Math.round(sample(w.terrain, this.hoverAngle).fertility * 100)}% · Water: ${Math.floor(w.resources.water)}`
                : "";
        label(
          `${BUILDINGS[type].name.toUpperCase()}\n${recipeText(type)}\n${context}\nWorkers: ${BUILDINGS[type].capacity} · ${reason || "Placement: VALID"}`,
          this.hoverAngle,
          145,
          valid ? "#486148" : "#934f43",
          13,
        );
      }
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
    if (this.drag?.kind === "follower" && this.drag.moved) {
      label(
        "Drop on land or a workplace",
        this.getAngle(this.drag.x, this.drag.y),
        80,
        "#ffffff",
        16,
      );
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
    this.blur();
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
