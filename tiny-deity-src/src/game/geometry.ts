import { TAU, type World, type Terrain } from "./types";
export const clamp = (n: number, a: number, b: number) =>
  Math.max(a, Math.min(b, n));
export const wrap = (a: number) => ((a % TAU) + TAU) % TAU;
export const distance = (a: number, b: number) =>
  Math.abs(Math.atan2(Math.sin(a - b), Math.cos(a - b)));
export const signedDistance = (a: number, b: number) =>
  Math.atan2(Math.sin(a - b), Math.cos(a - b));
export const radial = (angle: number, radius: number) => ({
  x: Math.sin(angle) * radius,
  y: -Math.cos(angle) * radius,
});
export const angleAt = (x: number, y: number) => wrap(Math.atan2(x, -y));
export function sample(terrain: Terrain[], angle: number): Terrain {
  return terrain[
    Math.floor((wrap(angle) / TAU) * terrain.length) % terrain.length
  ];
}
export function ground(w: World, angle: number): number {
  const n = (wrap(angle) / TAU) * w.terrain.length,
    i = Math.floor(n),
    t = n - i;
  return (
    w.radius +
    w.terrain[i].height * (1 - t) +
    w.terrain[(i + 1) % w.terrain.length].height * t
  );
}
export interface Camera {
  rotation: number;
  zoom: number;
  x: number;
  y: number;
}
export function toScreen(x: number, y: number, c: Camera) {
  const a = Math.cos(c.rotation),
    b = Math.sin(c.rotation);
  return {
    x: c.x + (x * a - y * b) * c.zoom,
    y: c.y + (x * b + y * a) * c.zoom,
  };
}
export function fromScreen(x: number, y: number, c: Camera) {
  const dx = (x - c.x) / c.zoom,
    dy = (y - c.y) / c.zoom,
    a = Math.cos(c.rotation),
    b = Math.sin(c.rotation);
  return { x: dx * a + dy * b, y: -dx * b + dy * a };
}
export function deform(
  w: World,
  angle: number,
  amount: number,
  smooth = false,
  width = 0.105,
  remember = true,
) {
  if (remember) w.undo = w.terrain.map((t) => t.height);
  const center = sample(w.terrain, angle).height;

  w.terrain.forEach((t, i) => {
    const d = distance((i / w.terrain.length) * TAU, angle);
    if (d < width) {
      const falloff = Math.pow((Math.cos((d / width) * Math.PI) + 1) / 2, 1.2);
      t.height = clamp(
        t.height + (smooth ? (center - t.height) * 0.7 : amount) * falloff,
        -120,
        150,
      );
    }
  });
  w.terrainVersion++;
}
/** Local one-dimensional basins: water head cannot exceed the lower of two enclosing rims. */
export function basinCapacity(w: World, index: number): number {
  const n = w.terrain.length,
    h = w.terrain[index].height;
  let left = h,
    right = h;
  for (let d = 1; d <= 16; d++) {
    left = Math.max(left, w.terrain[(index - d + n) % n].height);
    right = Math.max(right, w.terrain[(index + d) % n].height);
  }
  return clamp(Math.min(left, right) - h, 0, 65);
}

/** Conservatively redistribute pond water toward a shared downhill surface. */
export function redistributeWater(w: World, passes = 4) {
  const n = w.terrain.length;
  const limits = w.terrain.map((_, i) => basinCapacity(w, i));
  for (let pass = 0; pass < passes; pass++) {
    const volumes = w.terrain.map((t) => t.water);
    const changes = new Array<number>(n).fill(0);
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      const difference =
        w.terrain[i].height + volumes[i] - (w.terrain[j].height + volumes[j]);
      if (Math.abs(difference) < 0.05) continue;
      const source = difference > 0 ? i : j;
      const destination = difference > 0 ? j : i;
      const flow = Math.min(
        Math.max(0, volumes[source] + changes[source]),
        Math.max(
          0,
          limits[destination] - volumes[destination] - changes[destination],
        ),
        Math.abs(difference) * 0.3,
      );
      if (flow <= 0) continue;
      changes[source] -= flow;
      changes[destination] += flow;
    }
    for (let i = 0; i < n; i++) {
      w.terrain[i].water = Math.max(0, volumes[i] + changes[i]);
    }
  }
}
