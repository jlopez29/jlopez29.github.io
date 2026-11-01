import { CanvasSource, Texture } from "pixi.js";
import type { BuildingType } from "../game/types";
const ink = "#625846";
function canvas(
  w: number,
  h: number,
  draw: (c: CanvasRenderingContext2D) => void,
): Texture {
  const el = document.createElement("canvas");
  el.width = w * 2;
  el.height = h * 2;
  const c = el.getContext("2d")!;
  c.scale(2, 2);
  c.lineJoin = "round";
  c.lineCap = "round";
  draw(c);
  return new Texture({
    source: new CanvasSource({ resource: el, resolution: 2 }),
  });
}
function path(
  c: CanvasRenderingContext2D,
  p: number[][],
  fill: string,
  stroke = ink,
  width = 2,
) {
  c.beginPath();
  p.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y)));
  c.closePath();
  c.fillStyle = fill;
  c.fill();
  if (stroke) {
    c.strokeStyle = stroke;
    c.lineWidth = width;
    c.stroke();
  }
}
function ellipse(
  c: CanvasRenderingContext2D,
  x: number,
  y: number,
  rx: number,
  ry: number,
  color: string,
  stroke = "",
) {
  c.beginPath();
  c.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
  c.fillStyle = color;
  c.fill();
  if (stroke) {
    c.strokeStyle = stroke;
    c.lineWidth = 2;
    c.stroke();
  }
}
function rect(
  c: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  color: string,
  r = 3,
) {
  c.fillStyle = color;
  c.beginPath();
  c.roundRect(x, y, w, h, r);
  c.fill();
}
function line(
  c: CanvasRenderingContext2D,
  x: number,
  y: number,
  x2: number,
  y2: number,
  color = ink,
  width = 2,
) {
  c.strokeStyle = color;
  c.lineWidth = width;
  c.beginPath();
  c.moveTo(x, y);
  c.lineTo(x2, y2);
  c.stroke();
}
function flower(
  c: CanvasRenderingContext2D,
  x: number,
  y: number,
  color: string,
) {
  line(c, x, y + 10, x, y, "#608651", 1.5);
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    ellipse(c, x + Math.cos(a) * 3, y + Math.sin(a) * 3, 2.5, 2.5, color);
  }
  ellipse(c, x, y, 1.7, 1.7, "#f8d079");
}
export function treeTexture(variant: number): Texture {
  return canvas(92, 142, (c) => {
    ellipse(c, 46, 134, 27, 5, "#48684924");
    path(
      c,
      [
        [40, 132],
        [43, 66],
        [50, 62],
        [54, 132],
      ],
      "#997351",
    );
    line(c, 47, 99, 25, 78, "#997351", 5);
    line(c, 49, 91, 67, 67, "#997351", 5);
    const colors =
      variant === 2
        ? ["#c5b264", "#b8bb68", "#d3c17b"]
        : variant === 1
          ? ["#559578", "#75ab80", "#97bf87"]
          : ["#639b63", "#8bb471", "#b1c87c"];
    if (variant === 1) {
      path(
        c,
        [
          [45, 6],
          [14, 63],
          [29, 61],
          [6, 93],
          [86, 93],
          [64, 62],
          [78, 63],
        ],
        colors[0],
        "#4b7a60",
      );
      path(
        c,
        [
          [45, 6],
          [22, 59],
          [68, 59],
        ],
        colors[1],
        "",
      );
      path(
        c,
        [
          [45, 38],
          [18, 84],
          [69, 83],
        ],
        colors[2],
        "",
      );
    } else {
      ellipse(c, 31, 66, 25, 29, colors[0], "#578059");
      ellipse(c, 61, 58, 25, 31, colors[1], "#578059");
      ellipse(c, 44, 35, 29, 31, colors[1], "#578059");
      ellipse(c, 35, 28, 17, 15, colors[2]);
      ellipse(c, 63, 55, 12, 17, colors[2]);
      ellipse(c, 22, 61, 10, 12, colors[1]);
      if (variant === 2) {
        [
          [-6, 17],
          [24, 2],
          [-13, -9],
        ].forEach(([dx, dy]) => ellipse(c, 45 + dx, 46 + dy, 4, 4, "#e6a278"));
      }
    }
  });
}
export function rockTexture(): Texture {
  return canvas(50, 35, (c) => {
    ellipse(c, 25, 31, 22, 3, "#47634925");
    path(
      c,
      [
        [5, 29],
        [9, 15],
        [20, 5],
        [34, 9],
        [45, 25],
        [42, 31],
      ],
      "#aaa99a",
      "#838a7b",
      1.5,
    );
    path(
      c,
      [
        [9, 15],
        [20, 5],
        [27, 16],
        [16, 22],
      ],
      "#d4d0b9",
      "",
    );
    line(c, 27, 16, 34, 9, "#c1bfac", 1);
  });
}
export function followerTexture(appearance: number, arms = false): Texture {
  const coats = [
    "#e29a65",
    "#879bbb",
    "#b197ba",
    "#9aa86d",
    "#db8790",
    "#76a79d",
  ];
  return canvas(40, 62, (c) => {
    ellipse(c, 20, 59, 13, 3, "#38574628");
    line(c, 16, 47, 14, 57, "#685e53", 4);
    line(c, 24, 47, 26, 57, "#685e53", 4);
    path(
      c,
      [
        [12, 33],
        [27, 33],
        [29, 48],
        [10, 48],
      ],
      coats[appearance % 6],
      "#776455",
      1.3,
    );
    line(c, 12, 35, arms ? 4 : 7, arms ? 24 : 44, "#edc29b", 4);
    line(c, 28, 35, arms ? 36 : 33, arms ? 24 : 44, "#edc29b", 4);
    ellipse(c, 20, 23, 11.5, 12, "#f4cba1", "#9c795d");
    path(
      c,
      [
        [9, 23],
        [8, 17],
        [12, 9],
        [24, 8],
        [32, 16],
        [30, 23],
        [26, 16],
        [17, 18],
        [13, 15],
      ],
      appearance % 2 ? "#8c604a" : "#6c5c45",
      "",
      1,
    );
    ellipse(c, 16, 24, 1.2, 1.8, "#443f36");
    ellipse(c, 24, 24, 1.2, 1.8, "#443f36");
    line(c, 18, 29, 22, 29, "#ba806e", 1);
    ellipse(c, 11, 26, 2, 1.5, "#e9a48b");
    ellipse(c, 29, 26, 2, 1.5, "#e9a48b");
  });
}
export function buildingTexture(type: BuildingType): Texture {
  return canvas(144, 156, (c) => {
    ellipse(c, 73, 147, 58, 7, "#3c594b25");
    if (type === "tent") {
      path(
        c,
        [
          [12, 143],
          [66, 43],
          [130, 143],
        ],
        "#d28c71",
      );
      path(
        c,
        [
          [66, 43],
          [72, 142],
          [130, 143],
        ],
        "#e6b08c",
      );
      path(
        c,
        [
          [37, 143],
          [67, 88],
          [85, 143],
        ],
        "#6c6855",
      );
      line(c, 66, 35, 66, 53, "#8a7556", 4);
      line(c, 16, 143, 3, 146, "#8a7556");
      line(c, 126, 143, 140, 147, "#8a7556");
      line(c, 45, 93, 89, 93, "#f2d1a1", 3);
      return;
    }
    if (type === "garden") {
      rect(c, 11, 116, 122, 29, "#b8956c");
      line(c, 16, 130, 126, 130, "#8f785a");
      for (let i = 0; i < 13; i++)
        flower(
          c,
          18 + ((i * 29) % 107),
          88 + (i % 3) * 12,
          ["#e5a2a1", "#ede4a5", "#d0afcb"][i % 3],
        );
      return;
    }
    if (type === "campfire") {
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        ellipse(
          c,
          72 + Math.cos(a) * 25,
          130 + Math.sin(a) * 9,
          9,
          6,
          "#a6a391",
          ink,
        );
      }
      line(c, 52, 133, 86, 120, "#99704f", 8);
      line(c, 53, 120, 88, 135, "#a67c54", 8);
      path(
        c,
        [
          [50, 122],
          [58, 90],
          [68, 104],
          [76, 69],
          [96, 122],
          [77, 136],
        ],
        "#e79655",
        "#bc7e4c",
      );
      path(
        c,
        [
          [65, 124],
          [74, 101],
          [83, 126],
        ],
        "#f8d182",
        "",
      );
      rect(c, 10, 137, 30, 8, "#a47c56");
      rect(c, 108, 137, 30, 8, "#a47c56");
      return;
    }
    if (type === "fountain") {
      ellipse(c, 72, 136, 54, 12, "#90aba5", ink);
      ellipse(c, 72, 131, 48, 11, "#81c4cb");
      rect(c, 65, 80, 14, 47, "#c6c9ac");
      ellipse(c, 72, 84, 33, 8, "#a6bdae", ink);
      ellipse(c, 72, 81, 28, 6, "#9cd4d8");
      line(c, 72, 81, 72, 47, "#a9e2e0", 4);
      for (let i = 0; i < 4; i++) {
        line(c, 72, 52, 46 + i * 17, 67, "#b6e9e5", 2);
      }
      ellipse(c, 72, 47, 5, 4, "#d1f6ed");
      return;
    }
    if (type === "shrine" || type === "temple") {
      const temple = type === "temple";
      rect(c, 22, 132, 100, 13, "#b5ad91");
      rect(c, 29, 123, 85, 11, "#d5c8a7");
      if (temple) {
        rect(c, 39, 65, 65, 60, "#e6d6b2");
        [42, 62, 85].forEach((x) => rect(c, x, 76, 12, 48, "#b5bfa5"));
        path(
          c,
          [
            [25, 67],
            [71, 34],
            [119, 67],
          ],
          "#8c9d9f",
        );
      } else {
        path(
          c,
          [
            [52, 123],
            [55, 64],
            [88, 64],
            [94, 123],
          ],
          "#bba783",
        );
        path(
          c,
          [
            [52, 69],
            [46, 56],
            [73, 42],
            [98, 57],
            [91, 69],
          ],
          "#a491ad",
        );
        rect(c, 61, 78, 24, 33, "#9b8c76");
        ellipse(c, 73, 92, 7, 9, "#d6bf75");
        line(c, 72, 85, 72, 100, "#fff0b5", 2);
      }
      ellipse(c, 72, 32, 9, 9, "#e9cf89");
      line(c, 72, 19, 72, 9, "#e9cf89", 2);
      line(c, 56, 27, 51, 23, "#e9cf89", 2);
      line(c, 88, 27, 93, 23, "#e9cf89", 2);
      flower(c, 29, 123, "#d7a6c4");
      flower(c, 116, 130, "#ede2a2");
      return;
    }
    if (type === "mine") {
      path(
        c,
        [
          [10, 143],
          [25, 77],
          [57, 43],
          [99, 60],
          [134, 143],
        ],
        "#9c9d8c",
      );
      path(
        c,
        [
          [25, 77],
          [57, 43],
          [70, 80],
          [45, 112],
        ],
        "#b8b8a3",
        "",
      );
      rect(c, 45, 97, 55, 48, "#625f51", 22);
      line(c, 42, 95, 42, 144, "#b58b60", 8);
      line(c, 102, 95, 102, 144, "#b58b60", 8);
      line(c, 41, 95, 104, 95, "#c6a174", 8);
      line(c, 59, 142, 48, 152, "#a19a80");
      line(c, 88, 142, 99, 152, "#a19a80");
      ellipse(c, 72, 91, 6, 8, "#f0d083");
      return;
    }
    const roof =
      type === "farm"
        ? "#b66e55"
        : type === "windmill"
          ? "#b18a68"
          : type === "workshop"
            ? "#b87e66"
            : type === "observatory"
              ? "#829bb1"
              : "#6d9d96";
    if (type === "observatory") {
      rect(c, 31, 88, 82, 57, "#e0caa1");
      ellipse(c, 72, 87, 44, 36, roof, ink);
      rect(c, 25, 87, 93, 10, "#9fb0ae");
      line(c, 74, 62, 105, 37, "#7e8d8e", 12);
      line(c, 99, 32, 111, 43, "#bfcac1", 5);
      rect(c, 64, 112, 18, 33, "#8d8e7b", 8);
      return;
    }
    rect(c, 31, 83, 82, 61, "#e5cea3");
    rect(c, 96, 87, 17, 57, "#cab48c");
    path(
      c,
      [
        [18, 90],
        [70, 42],
        [126, 90],
      ],
      roof,
    );
    path(
      c,
      [
        [28, 87],
        [70, 50],
        [116, 87],
      ],
      roof,
      "#d8ad80",
      1,
    );
    rect(c, 63, 111, 20, 33, "#867b60", 8);
    rect(c, 37, 103, 17, 17, "#8daaa5");
    rect(c, 91, 103, 15, 17, "#8daaa5");
    line(c, 45, 104, 45, 118, "#f4dfa9");
    line(c, 38, 111, 52, 111, "#f4dfa9");
    line(c, 98, 104, 98, 118, "#f4dfa9");
    if (type === "farm") {
      rect(c, 7, 138, 41, 9, "#9a7b55");
      for (let i = 0; i < 5; i++) {
        line(c, 9 + i * 8, 137, 13 + i * 8, 121, "#8e9e59", 2);
        ellipse(c, 13 + i * 8, 121, 3, 5, "#d4bf75");
      }
      rect(c, 110, 132, 26, 15, "#a78a5e");
      ellipse(c, 119, 129, 10, 7, "#ddb96f");
    }
    if (type === "windmill") {
      rect(c, 56, 56, 33, 89, "#dfceb0");
      path(
        c,
        [
          [49, 61],
          [73, 31],
          [96, 61],
        ],
        roof,
      );
      const x = 72,
        y = 81;
      for (let i = 0; i < 4; i++) {
        const a = (i / 4) * Math.PI * 2 + 0.25;
        const ux = Math.cos(a),
          uy = Math.sin(a),
          vx = -uy,
          vy = ux;
        path(
          c,
          [
            [x + ux * 8, y + uy * 8],
            [x + ux * 53 + vx * 3, y + uy * 53 + vy * 3],
            [x + ux * 53 + vx * 13, y + uy * 53 + vy * 13],
            [x + ux * 17 + vx * 10, y + uy * 17 + vy * 10],
          ],
          "#f0dfb5",
          "#8e856b",
          1.5,
        );
      }
      ellipse(c, x, y, 6, 6, "#bc9972", ink);
    }
    if (type === "workshop") {
      rect(c, 94, 35, 14, 39, "#b7a18a");
      rect(c, 90, 32, 22, 7, "#d4b994");
      ellipse(c, 33, 134, 15, 15, "#998b73", ink);
      ellipse(c, 33, 134, 7, 7, "#d1bb8c");
    }
    if (type === "fishing") {
      line(c, 120, 145, 120, 68, "#9d805d", 3);
      line(c, 120, 68, 139, 125, "#d6d7ba", 1);
      rect(c, 3, 143, 138, 8, "#bca17a");
    }
    flower(c, 22, 134, "#ede0a2");
  });
}
export function cloudTexture(dark = false): Texture {
  return canvas(180, 95, (c) => {
    const col = dark ? "#91a5b0" : "#fffdf0",
      shade = dark ? "#7b929e" : "#e2f1e8";
    ellipse(c, 90, 67, 81, 22, shade);
    ellipse(c, 45, 51, 32, 26, col);
    ellipse(c, 82, 37, 39, 34, col);
    ellipse(c, 121, 48, 32, 28, col);
    ellipse(c, 148, 61, 24, 19, col);
    ellipse(c, 89, 63, 71, 22, col);
  });
}
export function sunTexture(): Texture {
  return canvas(145, 145, (c) => {
    const grad = c.createRadialGradient(72, 72, 20, 72, 72, 70);
    grad.addColorStop(0, "#f7d97590");
    grad.addColorStop(1, "#f7d97500");
    c.fillStyle = grad;
    c.fillRect(0, 0, 145, 145);
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      line(
        c,
        72 + Math.cos(a) * 43,
        72 + Math.sin(a) * 43,
        72 + Math.cos(a) * 51,
        72 + Math.sin(a) * 51,
        "#edc66e",
        3,
      );
    }
    ellipse(c, 72, 72, 32, 32, "#f6d77f", "#e1b46a");
    ellipse(c, 64, 68, 1.7, 2.3, "#977a4e");
    ellipse(c, 80, 68, 1.7, 2.3, "#977a4e");
    c.beginPath();
    c.arc(72, 72, 8, 0.25, Math.PI - 0.25);
    c.strokeStyle = "#bb955d";
    c.lineWidth = 1.5;
    c.stroke();
    ellipse(c, 57, 76, 4, 2, "#ebbc7a");
    ellipse(c, 87, 76, 4, 2, "#ebbc7a");
  });
}

export function graveTexture(): Texture {
  return canvas(40, 54, (c) => {
    ellipse(c, 20, 50, 17, 3, "#53654a28");
    rect(c, 6, 14, 28, 36, "#b4b6a4", 13);
    rect(c, 10, 18, 20, 27, "#c7c8b4", 9);
    line(c, 20, 24, 20, 37, "#919a86", 2);
    line(c, 15, 29, 25, 29, "#919a86", 2);
    flower(c, 30, 42, "#dbb7bf");
  });
}
