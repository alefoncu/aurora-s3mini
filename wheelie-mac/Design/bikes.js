// Wheelie Ride: motorcycle body designs. Single source of truth for the Design Studio artifact and
// for Sources/BikeShapes.swift (baked by Design/bake.mjs). Units: drawing units, origin on the rear
// axle, x forward, y up. Wheels, fork, swingarm, shock, handlebar, brakes and pegs are drawn by the
// app itself; the layers below are everything else on the bike.
(function (g) {
  const r2 = v => Math.round(v * 100) / 100;
  // Smooth closed/open outline through points; a third value of 1 makes a corner.
  function sm(pts, closed = true) {
    const n = pts.length, P = pts.map(p => [p[0], p[1]]);
    const tan = i => {
      if (pts[i][2]) return [0, 0];
      const a = closed ? P[(i + n - 1) % n] : P[Math.max(0, i - 1)], b = closed ? P[(i + 1) % n] : P[Math.min(n - 1, i + 1)];
      return [(b[0] - a[0]) / 2, (b[1] - a[1]) / 2];
    };
    let d = `M${r2(P[0][0])} ${r2(P[0][1])}`;
    for (let i = 0; i < (closed ? n : n - 1); i++) {
      const j = (i + 1) % n, t0 = tan(i), t1 = tan(j);
      d += `C${r2(P[i][0] + t0[0] / 3)} ${r2(P[i][1] + t0[1] / 3)} ${r2(P[j][0] - t1[0] / 3)} ${r2(P[j][1] - t1[1] / 3)} ${r2(P[j][0])} ${r2(P[j][1])}`;
    }
    return d + (closed ? 'Z' : '');
  }
  // Straight-edged polygon.
  function poly(pts) { return 'M' + pts.map(p => `${r2(p[0])} ${r2(p[1])}`).join('L') + 'Z'; }
  function line(pts) { return 'M' + pts.map(p => `${r2(p[0])} ${r2(p[1])}`).join('L'); }
  function lerp(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]; }
  // Tapered capsule between two points.
  function cap(a, b, w0, w1) {
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), ux = dx / l, uy = dy / l, nx = -uy, ny = ux;
    const m = lerp(a, b, .5), wm = (w0 + w1) / 4;
    return sm([[a[0] + nx * w0 / 2, a[1] + ny * w0 / 2, 1], [m[0] + nx * wm, m[1] + ny * wm], [b[0] + nx * w1 / 2, b[1] + ny * w1 / 2, 1],
      [b[0] + ux * w1 * .45, b[1] + uy * w1 * .45], [b[0] - nx * w1 / 2, b[1] - ny * w1 / 2, 1], [m[0] - nx * wm, m[1] - ny * wm],
      [a[0] - nx * w0 / 2, a[1] - ny * w0 / 2, 1], [a[0] - ux * w0 * .45, a[1] - uy * w0 * .45]]);
  }
  // Crescent around a wheel: inner/outer radius, angles in degrees (0 = front, 90 = top, 180 = rear).
  function crescent(cx, cy, rin, rout, a0, a1, valance = 0) {
    const P = (r, a) => [cx + Math.cos(a * Math.PI / 180) * r, cy + Math.sin(a * Math.PI / 180) * r];
    const out = [], inn = [], N = 7;
    for (let i = 0; i <= N; i++) { const a = a0 + (a1 - a0) * i / N; out.push(P(rout, a)); }
    for (let i = N; i >= 0; i--) { const a = a0 + (a1 - a0) * i / N; inn.push(P(rin - (i === 0 || i === N ? valance : 0), a)); }
    const pts = [];
    out.forEach((p, i) => pts.push(i === 0 || i === N ? [p[0], p[1], 1] : p));
    inn.forEach((p, i) => pts.push(i === 0 || i === N ? [p[0], p[1], 1] : p));
    return sm(pts);
  }
  // Layer constructors. z: 0 under the near swingarm, 1 body, 2 front end (after the near fork), 3 on top (after the bars).
  const F = (z, role, d, ol = 0.85) => ({ z, t: 'f', role, d, ol });                  // filled panel
  const T = (z, role, d, w) => ({ z, t: 's', role, d, w });                           // tube with edge and highlight
  const O = (z, role, x, y, r) => ({ z, t: 'c', role, x, y, r });                    // disc
  const L = (z, role, d, w, a = 1) => ({ z, t: 'l', role, d, w, a });                 // thin line
  const X = (z, role, x, y, size, str) => ({ z, t: 'x', role, x, y, size, str });     // lettering
  const rig = (F_, R, seat, grip, peg, fm, shock, pivot = [43, 10]) => ({ F: F_, R, seat, grip, peg, fm, shock, pivot });

  // Steering axis helpers: point at distance t above the front axle along the fork.
  const axis = (rg, t) => { const dx = rg.fm[0] - rg.F, dy = rg.fm[1], l = Math.hypot(dx, dy); return [rg.F + dx / l * t, dy / l * t]; };
  const nrm = rg => { const dx = rg.fm[0] - rg.F, dy = rg.fm[1], l = Math.hypot(dx, dy); return [-dy / l, dx / l]; };   // forward-facing normal

  // Air-cooled single: crankcase, clutch cover, finned barrel leaning forward and a head.
  function engine(ox, oy, s = 1, lean = 1) {
    const P = (x, y) => [ox + x * s, oy + y * s];
    const out = [];
    out.push(F(0, 'metal', sm([[...P(0, 10), 1], P(2, 20), P(12, 23.5), P(24, 21), [...P(29, 12), 1], P(26, 3), P(14, 0), P(4, 3.5)]), .9));
    const bl = P(10, 21), br = P(26, 21), tl = P(10 + 11 * lean, 40), tr = P(26 + 9 * lean, 36);
    out.push(F(0, 'metalDk', poly([bl, br, tr, tl]), .9));
    for (let i = 1; i <= 5; i++) { const t = i / 6; out.push(L(0, 'black', line([lerp(bl, tl, t), lerp(br, tr, t)]), 1.0, .85)); out.push(L(0, 'chrome', line([lerp(bl, tl, t - .06), lerp(br, tr, t - .06)]), .5, .55)); }
    const hl = P(10 + 11 * lean - 1.5, 39), hr = P(26 + 9 * lean + 1.5, 35);
    out.push(F(0, 'dark', sm([[...hl, 1], [...hr, 1], [...P(26 + 9 * lean + 2, 43.5), 1], [...P(10 + 11 * lean - 2.5, 46), 1]]), .9));
    const c = P(13, 11);
    out.push(O(0, 'metalLt', ...c, 8.3 * s), O(0, 'metal', ...c, 5.6 * s), O(0, 'black', ...c, 2.2 * s));
    for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + .6; out.push(O(0, 'black', c[0] + Math.cos(a) * 6.9 * s, c[1] + Math.sin(a) * 6.9 * s, .8)); }
    return out;
  }

  const D = { rigs: {}, bikes: {} };

  // ───────── Street 125: classic roadster ─────────
  D.rigs.commuter = rig(106, 23, [30, 45], [84, 67], [42, 11], [81, 57], [27, 36]);
  D.bikes.commuter = [
    T(1, 'chrome', sm([[66, 27], [70, 17], [62, 8], [48, 5.6], [36, 7]], false), 3.8),
    F(1, 'chrome', cap([36, 9], [-6, 18], 10, 8.6), .9),
    F(1, 'black', cap([-6, 17.6], [-10, 18.7], 8.9, 8.2), .7),
    L(0, 'steel', line([[36, 6.5], [-6, 15]]), 0),
    T(0, 'steel', sm([[79, 60], [62, 55], [44, 49.5], [32, 47.5]], false), 3.6),
    T(0, 'steel', sm([[32, 46.5], [14, 45], [-10, 41]], false), 2.8),
    T(0, 'steel', sm([[80, 56], [71, 42], [62, 24], [54, 9]], false), 3.6),
    T(0, 'steel', sm([[54, 9], [44, 4.6], [32, 6]], false), 3.0),
    T(0, 'steel', sm([[44, 11], [37, 28], [28, 46]], false), 3.0),
    ...engine(33, 5, 1, 1),
    F(1, 'paint', sm([[10, 26, 1], [11, 38], [24, 43], [34, 41.5], [36, 30, 1], [28, 22.5], [17, 22]]), .85),
    L(1, 'white', line([[14, 29], [30, 33]]), 1.3, .55),
    F(1, 'seat', sm([[-8, 45.5, 1], [-4, 48.6], [14, 49.6], [32, 49.4], [44, 48.4, 1], [43, 45], [30, 44.6], [10, 44.3], [-4, 43.8]]), .85),
    L(1, 'chrome', line([[-3, 48.4], [32, 49]]), .6, .55),
    T(0, 'steel', sm([[-8, 43], [-13, 32], [-18.5, 23]], false), 2.2),
        F(1, 'paint', crescent(0, 0, 25.6, 28.8, 62, 142, 0), .75),
    F(1, 'paint', sm([[-17, 34.5, 1], [-15.5, 40.5], [-7, 44.2], [6, 44.8, 1], [2, 38.4], [-6, 35]]), .75),
    F(1, 'red', sm([[-19.8, 38.6, 1], [-16.6, 41.4, 1], [-15.4, 38.4, 1], [-18, 36.8, 1]]), .5),
    F(1, 'paint', sm([[43, 47.5, 1], [45, 54.5], [55, 60.5], [68, 63.6], [79, 61.2, 1], [79, 56], [72, 51.4], [60, 48.8]]), .9),
    L(1, 'white', line([[48, 56], [62, 61.5], [74, 62]]), 1.1, .6),
    L(1, 'paintDk', line([[46, 50.4], [62, 51.8], [76, 54.5]]), 2.6, .7),
    F(1, 'chrome', sm([[62, 63.7, 1], [66, 65.6], [70, 63.7, 1], [66, 63.3]]), .6),
    // front end
    F(2, 'paint', crescent(106, 0, 25.6, 29.6, 20, 140, 3), .85),
    F(3, 'chrome', sm([[88, 52, 1], [89.5, 56.5], [96, 56.5], [97, 51.5, 1], [92, 50]]), .8),   // lamp bracket pad
    O(3, 'chrome', 91.5, 58, 7.2), O(3, 'lamp', 91.5, 58, 5.2), O(3, 'white', 91.5, 58, 2.0),
    O(3, 'dark', 80, 70, 4.6), O(3, 'cream', 80, 70, 3.1),
  ];

  // ───────── Scrambler 400 ─────────
  D.rigs.scrambler = rig(112, 26, [30, 49], [85, 72], [44, 13], [87, 65], [27, 36]);
  D.bikes.scrambler = [
    T(1, 'chrome', sm([[70, 32], [74, 21], [66, 10], [50, 7.5], [32, 12], [14, 24], [2, 33]], false), 3.8),
    F(1, 'chrome', cap([14, 26], [-12, 39.5], 8.8, 7.6), .9),
    F(1, 'black', cap([-12, 39], [-15.5, 40.8], 7.8, 7.2), .7),
    T(0, 'steel', sm([[88, 68], [64, 59], [44, 53], [30, 51.5]], false), 3.6),
    T(0, 'steel', sm([[30, 50.5], [10, 49], [-10, 46.5]], false), 2.8),
    T(0, 'steel', sm([[88, 63], [76, 44], [66, 22], [56, 8]], false), 3.6),
    T(0, 'steel', sm([[56, 8], [44, 5], [32, 7]], false), 3.0),
    T(0, 'steel', sm([[44, 11], [36, 30], [26, 50]], false), 3.0),
    ...engine(35, 5, 1.04, .8),
    F(1, 'paint', crescent(0, 0, 29, 32.4, 56, 150, 0), .75),
    O(1, 'white', 22, 32, 9.6), O(1, 'paintDk', 22, 32, 7.9), X(1, 'white', 22, 32, 11, '4'),
    F(1, 'tan', sm([[-10, 50, 1], [-4, 53.4], [16, 54.4], [38, 54], [48, 52.6, 1], [47, 49], [30, 48], [8, 47.6], [-6, 47]]), .85),
    L(1, 'tanLt', line([[-2, 52.6], [38, 53.2]]), .6, .7),
    F(1, 'paint', sm([[-20, 42, 1], [-17, 48.5], [-8, 52], [10, 52.6, 1], [4, 45.5], [-8, 42]]), .75),
    F(1, 'red', sm([[-22, 46, 1], [-19, 49, 1], [-17.4, 46, 1], [-20, 44.2, 1]]), .5),
    F(1, 'paint', sm([[44, 53, 1], [46, 60], [56, 65.4], [70, 67.6], [81, 66, 1], [80, 60.5], [72, 55.6], [58, 53.2]]), .9),
    L(1, 'white', line([[48, 61], [62, 66], [76, 66.6]]), 1.1, .6),
    L(1, 'paintDk', line([[47, 55.4], [62, 56.4], [78, 59.5]]), 2.6, .7),
    F(1, 'chrome', sm([[62, 67.6, 1], [66, 69.4], [70, 67.7, 1], [66, 67.3]]), .6),
    F(2, 'paint', crescent(112, 0, 31, 34.4, 20, 130, 3), .85),
    O(3, 'chrome', 98, 66, 7.4), O(3, 'lamp', 98, 66, 5.4), O(3, 'white', 98, 66, 2.1),
  ];

  // ───────── Volt E-8 ─────────
  D.rigs.electric = rig(104, 23, [30, 46], [80, 66], [44, 10], [79, 57], [27, 36]);
  D.bikes.electric = [
    L(0, 'black', line([[44, 18.2], [4, 6.5]]), 1.4, .9),
    T(0, 'steel', sm([[78, 59], [64, 54.5], [50, 50], [32, 48]], false), 3.6),
    T(0, 'steel', sm([[32, 47], [14, 45.5], [-8, 42]], false), 2.8),
    T(0, 'steel', sm([[79, 55], [68, 36], [58, 14], [46, 8]], false), 3.8),
    F(0, 'dark', sm([[30, 9, 1], [29, 34], [36, 42], [56, 44.5], [67, 40], [68, 20, 1], [60, 8], [42, 6]]), 1.0),    // battery pack
    L(0, 'black', line([[36, 10], [36, 40]]), 1, .6), L(0, 'black', line([[42, 8], [42, 43]]), 1, .6), L(0, 'black', line([[48, 8], [48, 44]]), 1, .6), L(0, 'black', line([[54, 8], [54, 44]]), 1, .6), L(0, 'black', line([[60, 9], [60, 43]]), 1, .6),
    F(0, 'green', sm([[34, 35, 1], [62, 36.2, 1], [62, 38.6, 1], [34, 37.4, 1]]), .5),
    O(0, 'metalLt', 43, 12.6, 8.2), O(0, 'metal', 43, 12.6, 5.6), O(0, 'orange', 43, 12.6, 2.4),
    F(1, 'paint', sm([[9, 28, 1], [10, 38], [22, 42.5], [33, 41, 1], [31, 29], [20, 24]]), .85),
    F(1, 'seat', sm([[-8, 46, 1], [-4, 48.8], [14, 49.6], [34, 49.2], [46, 47.4, 1], [44, 44.8], [30, 44.4], [10, 44.2], [-4, 43.8]]), .85),
    F(1, 'paint', sm([[-16, 35, 1], [-14, 41], [-6, 44.4], [8, 44.8, 1], [3, 38], [-5, 34.5]]), .75),
    F(1, 'paint', crescent(0, 0, 25.4, 28.4, 55, 150, 0), .75),
    F(1, 'red', sm([[-18.5, 39, 1], [-15.5, 42, 1], [-14, 39, 1], [-16.8, 37, 1]]), .5),
    F(1, 'paint', sm([[34, 49.6, 1], [40, 55], [56, 59.4], [72, 61, 1], [76, 57.8], [72, 53.4], [54, 50.5]]), .9),
    L(1, 'green', line([[44, 55], [70, 58.2]]), 1.2, .9),
    F(2, 'paint', crescent(104, 0, 25.6, 29.4, 22, 140, 3), .85),
    F(3, 'dark', sm([[86, 52, 1], [88, 59.5], [96, 60.2, 1], [96, 52]]), .8),
    F(3, 'lamp', sm([[89, 54.6, 1], [89.2, 58.8], [93.8, 59.2, 1], [93.8, 54.6]]), .5),
  ];

  // ───────── Enduro 250 ─────────
  D.rigs.motocross = rig(111, 26, [29, 57], [82, 82], [43, 17], [86, 76], [27, 47]);
  D.bikes.motocross = [
    T(1, 'chrome', sm([[78, 36], [86, 24], [76, 8], [58, 5], [44, 12], [22, 26], [6, 38], [-8, 45]], false), 4.4),
    F(1, 'chrome', cap([6, 40], [-18, 53], 9.4, 8.2), .9),
    F(1, 'black', cap([-18, 52.6], [-21.5, 54.4], 8.2, 7.6), .7),
    T(0, 'steel', sm([[84, 78], [60, 68], [40, 62], [28, 60]], false), 3.6),
    T(0, 'steel', sm([[85, 72], [70, 52], [56, 30], [50, 14]], false), 3.8),
    T(0, 'steel', sm([[44, 11], [32, 30], [18, 52]], false), 3.2),
    T(0, 'steel', sm([[28, 60], [4, 58], [-12, 53]], false), 3.0),
    ...engine(37, 6, 1.1, 1),
    F(0, 'dark', sm([[34, 8, 1], [34, 3.6], [52, 0.5], [67, 2.4, 1], [66, 6], [46, 9]]), .8),
    F(1, 'seat', sm([[-14, 57, 1], [0, 60.6], [26, 61.6], [48, 60.4], [58, 58.6, 1], [47, 56.2], [24, 55.6], [0, 55.4]]), .85),
    F(1, 'paint', sm([[-27, 53, 1], [-22, 59], [-8, 61.6], [14, 61.4, 1], [6, 56.6], [-10, 55.2]]), .75),
    F(1, 'paint', crescent(0, 0, 29.4, 32.2, 100, 146, 0), .6),
    F(1, 'white', sm([[44, 56.6, 1], [47, 69], [58, 76], [66, 74, 1], [63, 62.4], [54, 57.4]]), .9),
    F(1, 'paint', sm([[50, 69, 1], [58, 76.2], [74, 79], [86, 77, 1], [84, 72.4], [70, 70.6], [56, 70]]), .9),
    X(1, 'dark', 55, 63.6, 10, '7'),
    F(2, 'paint', crescent(111, 0, 30, 33.4, 22, 150, 0), .85),
    F(2, 'white', sm([[93, 74, 1], [94, 85], [101, 89], [107, 85, 1], [105, 75]]), .9),
    X(2, 'dark', 100, 80, 7.5, '7'),
  ];

  // ───────── Trial 200 ─────────
  D.rigs.trials = rig(108, 27, [34, 61], [83, 80], [44, 16], [83, 76], [27, 47]);
  D.bikes.trials = [
    T(1, 'chrome', sm([[78, 40], [84, 30], [74, 14], [56, 8], [40, 16], [20, 38], [4, 52], [-6, 58]], false), 3.6),
    F(1, 'chrome', cap([4, 54], [-16, 62], 7.8, 6.8), .9),
    F(1, 'black', cap([-16, 61.6], [-19, 63], 7, 6.6), .7),
    T(0, 'steel', sm([[82, 78], [60, 71], [44, 65], [34, 63]], false), 3.4),
    T(0, 'steel', sm([[83, 72], [68, 50], [58, 30], [52, 14]], false), 3.4),
    T(0, 'steel', sm([[44, 11], [34, 34], [22, 58]], false), 3.0),
    T(0, 'steel', sm([[34, 62], [10, 61], [-4, 58]], false), 2.8),
    ...engine(37, 6, .95, .9),
    F(0, 'dark', sm([[36, 8, 1], [36, 4], [52, 1], [64, 3, 1], [62, 7], [46, 9.4]]), .8),
    F(1, 'seat', sm([[8, 62, 1], [14, 64.8], [34, 65.6], [46, 64.4, 1], [40, 61.4], [20, 61]]), .85),
    F(1, 'paint', sm([[-14, 56, 1], [-12, 60.4], [0, 63.6], [14, 64, 1], [8, 59], [-4, 56.4]]), .75),
    F(1, 'paint', crescent(0, 0, 30.8, 33.6, 60, 142, 0), .6),
    F(1, 'paint', sm([[44, 66, 1], [48, 74.5], [60, 79.6], [76, 80.4, 1], [78, 75.4], [66, 70.4], [54, 67.2]]), .9),
    L(1, 'white', line([[50, 74], [64, 79], [74, 79.6]]), 1.1, .6),
    F(2, 'white', crescent(108, 0, 33.4, 36.8, 18, 128, 2), .85),
    O(3, 'chrome', 91, 76, 6.6), O(3, 'lamp', 91, 76, 4.8),
  ];

  // ───────── Cruiser 750 ─────────
  D.rigs.cruiser = rig(112, 25, [28, 38], [84, 76], [62, 9], [87, 57], [27, 36]);
  D.bikes.cruiser = [
    // two drag pipes along the right side, slash-cut at the rear
    T(1, 'chrome', sm([[60, 31], [67, 22], [62, 10], [48, 6.4], [22, 5.4], [-8, 8]], false), 4.6),
    T(1, 'chrome', sm([[40, 31], [48, 22], [44, 12], [38, 2], [20, -1], [-14, 2]], false), 4.6),
    F(1, 'chrome', cap([20, 6], [-16, 8.6], 7.8, 8.6), .9),
    F(1, 'black', cap([-16, 8.6], [-19.6, 9], 7.2, 7), .7),
    // frame: backbone, downtube, rear loop
    T(0, 'steel', sm([[86, 60], [68, 56], [50, 50], [36, 42]], false), 3.8),
    T(0, 'steel', sm([[86, 55], [74, 38], [66, 18], [54, 5]], false), 3.8),
    T(0, 'steel', sm([[36, 42], [16, 40], [-6, 34]], false), 3.0),
    T(0, 'steel', sm([[44, 11], [36, 28], [28, 40]], false), 3.2),
    // V-twin: crankcase with two finned barrels in a 70-degree vee, air cleaner between them
    F(0, 'metal', sm([[30, 12, 1], [31, 26], [46, 31], [62, 26, 1], [64, 10], [50, 3], [36, 4]]), .9),
    F(0, 'metalDk', poly([[28, 25], [42, 27.5], [34, 46], [22, 42]]), .9),
    F(0, 'metalDk', poly([[48, 28], [62, 25], [74, 43], [62, 48]]), .9),
    L(0, 'black', line([[27, 29], [41, 31.4]]), 1, .85), L(0, 'black', line([[26, 33], [40, 36]]), 1, .85), L(0, 'black', line([[25, 37], [38, 40.4]]), 1, .85),
    L(0, 'black', line([[50, 31], [63, 28.4]]), 1, .85), L(0, 'black', line([[53, 35.4], [66, 32.4]]), 1, .85), L(0, 'black', line([[56, 39.6], [69, 36.6]]), 1, .85),
    F(0, 'dark', sm([[20, 41.6, 1], [34, 45.8, 1], [32, 50], [19, 46]]), .8),
    F(0, 'dark', sm([[61, 47, 1], [74, 42.6, 1], [77, 46.6], [64, 52]]), .8),
    O(0, 'metalLt', 46, 15, 9), O(0, 'metal', 46, 15, 6), O(0, 'black', 46, 15, 2.4),
    O(0, 'chrome', 47, 40, 7.6), O(0, 'metal', 47, 40, 4.6),
    F(1, 'paint', crescent(0, 0, 27.6, 31.6, 18, 168, 3.4), .8),
    F(1, 'seat', sm([[46, 40.2, 1], [40, 42.2], [26, 38.6], [14, 37.8], [4, 40.4], [-10, 41.4, 1], [-9, 37.6], [4, 36.4], [26, 33.6], [42, 36.4]]), .85),
    L(1, 'chrome', line([[36, 36.5], [34, 31.6]]), 1.2, .8), L(1, 'chrome', line([[14, 34.4], [13, 30]]), 1.2, .8),
    F(1, 'red', sm([[-23.4, 22, 1], [-21, 25.6, 1], [-19, 24, 1], [-20.8, 20.4, 1]]), .5),
    F(1, 'paint', sm([[40, 52, 1], [44, 62], [58, 68.4], [74, 68.8], [88, 64, 1], [87, 57], [74, 53], [58, 51]]), .9),
    L(1, 'white', line([[46, 62], [60, 67], [76, 66.6]]), 1.3, .6),
    L(1, 'paintDk', line([[46, 54.4], [64, 55.4], [84, 59.4]]), 2.6, .65),
    F(1, 'chrome', sm([[60, 68.6, 1], [64, 70.4], [68, 68.7, 1], [64, 68.3]]), .6),
    F(2, 'paint', crescent(112, 0, 28.4, 32.6, 14, 152, 4), .9),
    O(3, 'chrome', 99, 60, 8.8), O(3, 'lamp', 99, 60, 6.6), O(3, 'white', 99, 60, 2.6),
    F(3, 'chrome', sm([[56, 8, 1], [78, 8, 1], [80, 5.4, 1], [54, 5.2, 1]]), .8),
  ];

  // ───────── Scooter 80 ─────────
  D.rigs.scooter = rig(100, 20, [27, 43], [79, 67], [59, 4], [75, 57], [27, 36]);
  D.bikes.scooter = [
    F(1, 'paint', sm([[-15, 22, 1], [-14, 36], [-6, 44], [14, 46.4], [32, 44], [40, 38, 1], [41, 26], [44, 14], [50, 5, 1], [30, 2], [26, 8], [24, 26], [10, 28], [-4, 24]]), .9),
    F(1, 'metal', sm([[-6, 22, 1], [-4, 36], [8, 40], [22, 38, 1], [22, 26], [10, 22]]), .8),
    F(1, 'seat', sm([[-6, 44.6, 1], [0, 47.6], [20, 48.2], [36, 47, 1], [35, 43.4], [16, 42.6], [0, 42.2]]), .85),
    F(1, 'paint', sm([[40, 4, 1], [44, 2], [70, 1.6], [74, 4, 1], [72, 7], [42, 7]]), .8),
    F(1, 'dark', sm([[46, 6, 1], [70, 5.6, 1], [70, 3.6, 1], [46, 3.6, 1]]), .5),
    F(1, 'paint', sm([[68, 6, 1], [66, 20], [66, 38], [70, 54], [78, 62, 1], [88, 64], [92, 56, 1], [86, 40], [82, 20], [82, 6, 1]]), .9),
    F(1, 'red', sm([[-18, 36, 1], [-16, 40, 1], [-14.4, 39, 1], [-16, 35, 1]]), .5),
    F(2, 'paint', crescent(100, 0, 22, 26, 20, 145, 4), .85),
    F(3, 'dark', sm([[76, 58, 1], [88, 62], [98, 64], [96, 57, 1], [86, 53]]), .8),
    O(3, 'chrome', 94, 64, 7.4), O(3, 'lamp', 94, 64, 5.4), O(3, 'white', 94, 64, 2.1),
  ];

  // ───────── BMX ─────────
  D.rigs.bmx = rig(94, 24, [29, 49], [77, 72], [44, 0], [69, 57], [27, 36]);
  D.bikes.bmx = [];

  g.DESIGN = D;
  g.DESIGN.roles = {
    paint: null, paintDk: null,
    metal: ['#C9D1D3', '#7C8A91', '#34414A'], metalLt: ['#EDF0EC', '#A3AFB3', '#5A6870'], metalDk: ['#8E9BA1', '#4A585F', '#1E282D'],
    steel: ['#4A565D', '#232C32'], dark: ['#59666E', '#1B242A'], black: ['#363E44', '#0E1316'],
    chrome: ['#F3F5EF', '#A3AFB3', '#5A6870'], seat: ['#5A666F', '#151D22'], tan: ['#B08A5F', '#4A3D2E'], tanLt: ['#E4C9A2'],
    lamp: ['#FFF7D6', '#E8D79A'], white: ['#FFFFFF', '#D7DDE0'], cream: ['#F4F1DE', '#CFC7A6'], red: ['#FF6A55', '#B2271B'], green: ['#7FF29B', '#2E9E52'], orange: ['#FFB04A', '#E0742A']
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
