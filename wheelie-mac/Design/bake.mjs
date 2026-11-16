// node Design/bake.mjs -> Sources/BikeShapes.swift
// Reads the vector bodywork drawn in the Claude Design canvas (Design/canvas/project/*.dc.html): the groups
// z0..z3 of each board's <svg> become draw layers. Coordinates are already the game's (rear axle at 0,0, y down).
import { readFileSync, writeFileSync } from 'node:fs';
const dir = new URL('.', import.meta.url);
const boards = { commuter: 'Main', scrambler: 'Scrambler', electric: 'Electric', motocross: 'Enduro', trials: 'Trial', cruiser: 'Cruiser', scooter: 'Scooter', sport: 'Sport', hyperbike: 'Hyper', bmx: 'BMX' };
const PAINT = { '#FFE08A': 0.45, '#EDB52E': 0.12, '#E9AD27': 0, '#C58613': -0.28, '#8F5C0C': -0.55, '#5A3A08': -0.7 };
const f = v => Math.round(v * 100) / 100;

// ── path parsing: M L H V C S Q T A Z (absolute and relative) → absolute M L C Z ──
function parsePath(d, tx = 0, ty = 0) {
  const tok = d.match(/[a-zA-Z]|-?\d*\.?\d+(?:e-?\d+)?/g) || [];
  let i = 0, cmd = '', x = 0, y = 0, sx = 0, sy = 0, lcx = 0, lcy = 0, lq = null;
  const out = [], n = () => parseFloat(tok[i++]);
  const P = (a, b) => [a + tx, b + ty];
  const M = (a, b) => out.push(['M', ...P(a, b)]);
  const Lt = (a, b) => out.push(['L', ...P(a, b)]);
  const C = (a, b, c, e, g, h) => out.push(['C', ...P(a, b), ...P(c, e), ...P(g, h)]);
  function arc(x1, y1, rx, ry, phi, fa, fs, x2, y2) {
    if (rx === 0 || ry === 0) return Lt(x2, y2);
    const ph = phi * Math.PI / 180, c = Math.cos(ph), s = Math.sin(ph);
    const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2, x1p = c * dx + s * dy, y1p = -s * dx + c * dy;
    rx = Math.abs(rx); ry = Math.abs(ry);
    const lam = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry); if (lam > 1) { rx *= Math.sqrt(lam); ry *= Math.sqrt(lam); }
    const num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p, den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    let co = Math.sqrt(Math.max(0, num / den)); if (fa === fs) co = -co;
    const cxp = co * rx * y1p / ry, cyp = -co * ry * x1p / rx, cx = c * cxp - s * cyp + (x1 + x2) / 2, cy = s * cxp + c * cyp + (y1 + y2) / 2;
    const ang = (ux, uy, vx, vy) => { const a = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy); return a; };
    let th1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry), dth = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
    if (!fs && dth > 0) dth -= 2 * Math.PI; if (fs && dth < 0) dth += 2 * Math.PI;
    const segs = Math.ceil(Math.abs(dth) / (Math.PI / 2) - 1e-9), dt = dth / segs, k = 4 / 3 * Math.tan(dt / 4);
    for (let j = 0; j < segs; j++) {
      const a0 = th1 + j * dt, a1 = a0 + dt;
      const pt = (a) => [cx + rx * Math.cos(a) * c - ry * Math.sin(a) * s, cy + rx * Math.cos(a) * s + ry * Math.sin(a) * c];
      const dv = (a) => [-rx * Math.sin(a) * c - ry * Math.cos(a) * s, -rx * Math.sin(a) * s + ry * Math.cos(a) * c];
      const p0 = pt(a0), p1 = pt(a1), d0 = dv(a0), d1 = dv(a1);
      C(p0[0] + k * d0[0], p0[1] + k * d0[1], p1[0] - k * d1[0], p1[1] - k * d1[1], p1[0], p1[1]);
    }
  }
  while (i < tok.length) {
    if (/[a-zA-Z]/.test(tok[i])) cmd = tok[i++];
    const rel = cmd === cmd.toLowerCase(), U = cmd.toUpperCase(), ox = rel ? x : 0, oy = rel ? y : 0;
    if (U === 'Z') { out.push(['Z']); x = sx; y = sy; lq = null; continue; }
    if (U === 'M') { x = n() + ox; y = n() + oy; sx = x; sy = y; M(x, y); cmd = rel ? 'l' : 'L'; lq = null; continue; }
    if (U === 'L') { x = n() + ox; y = n() + oy; Lt(x, y); lq = null; continue; }
    if (U === 'H') { x = n() + ox; Lt(x, y); lq = null; continue; }
    if (U === 'V') { y = n() + oy; Lt(x, y); lq = null; continue; }
    if (U === 'C') { const a = n() + ox, b = n() + oy, c1 = n() + ox, e = n() + oy, g = n() + ox, h = n() + oy; C(a, b, c1, e, g, h); lcx = c1; lcy = e; x = g; y = h; lq = null; continue; }
    if (U === 'S') { const c1 = n() + ox, e = n() + oy, g = n() + ox, h = n() + oy; C(2 * x - lcx, 2 * y - lcy, c1, e, g, h); lcx = c1; lcy = e; x = g; y = h; continue; }
    if (U === 'Q') { const a = n() + ox, b = n() + oy, g = n() + ox, h = n() + oy; C(x + 2 / 3 * (a - x), y + 2 / 3 * (b - y), g + 2 / 3 * (a - g), h + 2 / 3 * (b - h), g, h); lq = [a, b]; x = g; y = h; continue; }
    if (U === 'A') { const rx = n(), ry = n(), ph = n(), fa = n(), fs = n(), x2 = n() + ox, y2 = n() + oy; arc(x, y, rx, ry, ph, fa, fs, x2, y2); x = x2; y = y2; lq = null; continue; }
    throw new Error('unsupported path command ' + cmd);
  }
  return out.map(s => s[0] + s.slice(1).map(f).join(' ')).join('').replace(/([MLCZ])/g, '$1').replace(/Z/g, 'Z');
}
const ell = (cx, cy, rx, ry) => `M${cx + rx} ${cy}A${rx} ${ry} 0 1 1 ${cx - rx} ${cy}A${rx} ${ry} 0 1 1 ${cx + rx} ${cy}Z`;
const attrs = s => { const o = {}; for (const m of s.matchAll(/([\w:-]+)="([^"]*)"/g)) o[m[1]] = m[2]; return o; };

function loadGradients(svg) {
  const g = {};
  for (const m of svg.matchAll(/<linearGradient id="([^"]+)"[^>]*>([\s\S]*?)<\/linearGradient>/g)) {
    g[m[1]] = [...m[2].matchAll(/<stop offset="([^"]+)" stop-color="([^"]+)"/g)].map(s => [parseFloat(s[1]), s[2].toUpperCase()]);
  }
  return g;
}
const rgb = hex => parseInt(hex.slice(1), 16);
const colorExpr = hex => { hex = hex.toUpperCase(); return PAINT[hex] !== undefined ? `ArtColor(rgb:${rgb(hex)},paint:true,tone:${PAINT[hex]})` : `ArtColor(rgb:${rgb(hex)},paint:false,tone:0.0)`; };

function layersOf(svg) {
  const grads = loadGradients(svg), layers = [];
  for (const z of [0, 1, 2, 3]) {
    const gm = svg.match(new RegExp(`<g id="z${z}">([\\s\\S]*?)</g>`));
    if (!gm) continue;
    const body = gm[1];
    for (const m of body.matchAll(/<(path|circle|ellipse|rect|text)\b([^>]*?)(?:\/>|>([^<]*)<\/text>)/g)) {
      const el = m[1], a = attrs(m[2]);
      let tx = 0, ty = 0;
      const tm = (a.transform || '').match(/translate\(\s*(-?[\d.]+)[ ,]+(-?[\d.]+)\s*\)/); if (tm) { tx = parseFloat(tm[1]); ty = parseFloat(tm[2]); }
      const op = a.opacity !== undefined ? parseFloat(a.opacity) : 1;
      if (op === 0) continue;
      if (el === 'text') {
        const fill = (a.fill || '#FFFFFF').toUpperCase();
        layers.push({ z, text: m[3], x: parseFloat(a.x), y: parseFloat(a.y), size: parseFloat(a['font-size'] || 8), color: fill, op });
        continue;
      }
      let d;
      if (el === 'path') d = parsePath(a.d, tx, ty);
      else if (el === 'circle') d = parsePath(ell(+a.cx, +a.cy, +a.r, +a.r), tx, ty);
      else if (el === 'ellipse') d = parsePath(ell(+a.cx, +a.cy, +a.rx, +a.ry), tx, ty);
      else { const x = +a.x, y = +a.y, w = +a.width, h = +a.height; d = parsePath(`M${x} ${y}H${x + w}V${y + h}H${x}Z`, tx, ty); }
      let stops = [];
      const fill = a.fill ?? '#000000';
      if (fill.startsWith('url(#')) stops = grads[fill.slice(5, -1)] || [];
      else if (fill !== 'none') stops = [[0, fill.toUpperCase()]];
      layers.push({ z, d, stops, stroke: a.stroke && a.stroke !== 'none' ? a.stroke.toUpperCase() : null, sw: a['stroke-width'] ? parseFloat(a['stroke-width']) : 0, op });
    }
  }
  return layers;
}

let out = `// Generated by Design/bake.mjs from the Claude Design canvas (Design/canvas/project). Do not edit by hand.
import Foundation

struct ArtColor { let rgb:Int; let paint:Bool; let tone:Double }
struct ArtStop { let at:Double; let color:ArtColor }
struct ArtLayer { let z:Int; let d:String; let stops:[ArtStop]; let stroke:ArtColor?; let sw:Double; let op:Double; let text:String; let tx:Double; let ty:Double; let size:Double }

enum BikeShapes {
    static func layers(_ kind:BikeKind)->[ArtLayer] { table[kind] ?? [] }
    private static let table:[BikeKind:[ArtLayer]] = [
`;
for (const [kind, name] of Object.entries(boards)) {
  const file = name === 'Main' ? 'Main.dc.html' : name + '.dc.html';
  const svg = readFileSync(new URL(`canvas/project/${file}`, dir), 'utf8').match(/<svg[\s\S]*?<\/svg>/)[0];
  const layers = layersOf(svg);
  out += `        .${kind}: [\n`;
  for (const l of layers) {
    if (l.text !== undefined) out += `            ArtLayer(z:${l.z},d:"",stops:[ArtStop(at:0,color:${colorExpr(l.color)})],stroke:nil,sw:0,op:${l.op},text:${JSON.stringify(l.text)},tx:${l.x},ty:${l.y},size:${l.size}),\n`;
    else out += `            ArtLayer(z:${l.z},d:${JSON.stringify(l.d)},stops:[${l.stops.map(s => `ArtStop(at:${s[0]},color:${colorExpr(s[1])})`).join(',')}],stroke:${l.stroke ? colorExpr(l.stroke) : 'nil'},sw:${l.sw},op:${l.op},text:"",tx:0,ty:0,size:0),\n`;
  }
  out += `        ],\n`;
}
out += `    ]\n}\n`;
writeFileSync(new URL('../Sources/BikeShapes.swift', dir), out);
console.log('BikeShapes.swift written');
