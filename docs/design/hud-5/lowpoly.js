// 5 (Air): 4c + the almanac. Reference implementation of the 4a facet generator + all data for both bars.
// Framework-agnostic; returns plain data. Icon = silhouette paths (clip, unioned) filled with a
// jittered 4x4 triangle grid under a diagonal light, plus stroked line paths. 24x24 viewBox.

const C = (x, y, r) => `M${(x - r).toFixed(2)} ${y.toFixed(2)} a${r} ${r} 0 1 0 ${2 * r} 0 a${r} ${r} 0 1 0 ${-2 * r} 0Z`;
const P = (pts) => 'M' + pts.map((p) => p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join(' L') + 'Z';
const bar = (x0, y0, a, len, w) => {
  const c = Math.cos(a), s = Math.sin(a), nx = -s * w / 2, ny = c * w / 2, x1 = x0 + c * len, y1 = y0 + s * len;
  return P([[x0 + nx, y0 + ny], [x1 + nx, y1 + ny], [x1 - nx, y1 - ny], [x0 - nx, y0 - ny]]);
};
// Frost: filled six-arm snowflake (hex core, 2.6 arms, 2.1 branches at ±0.9 rad, 6 from centre).
export const snowflake = () => {
  const o = [P([0, 1, 2, 3, 4, 5].map((k) => [12 + 3.4 * Math.cos(k * Math.PI / 3), 12 + 3.4 * Math.sin(k * Math.PI / 3)]))];
  for (let k = 0; k < 6; k++) {
    const a = k * Math.PI / 3 - Math.PI / 2, bx = 12 + Math.cos(a) * 6, by = 12 + Math.sin(a) * 6;
    o.push(bar(12, 12, a, 10.6, 2.6), bar(bx, by, a + 0.9, 4, 2.1), bar(bx, by, a - 0.9, 4, 2.1));
  }
  return o;
};
// Dandelion: ball + 12 parachute tufts round the rim, 8 fine spokes, one drifting seed.
const DANDELION_FILLS = [C(11, 9.6, 5.4)], DANDELION_LINES = [];
for (let k = 0; k < 12; k++) { const a = k * Math.PI / 6; DANDELION_FILLS.push(C(11 + 6.3 * Math.cos(a), 9.6 + 6.3 * Math.sin(a), 1.55)); }
DANDELION_FILLS.push('M10 14.5 H12 V22.4 H10Z', C(20.4, 2.3, 1.35));
for (let k = 0; k < 8; k++) { const a = k * Math.PI / 4 + 0.2; DANDELION_LINES.push(`M${(11 + Math.cos(a)).toFixed(2)} ${(9.6 + Math.sin(a)).toFixed(2)} L${(11 + 5.2 * Math.cos(a)).toFixed(2)} ${(9.6 + 5.2 * Math.sin(a)).toFixed(2)}`); }
DANDELION_LINES.push('M19.9 3.6 L18.7 6.2');

// Entry: { name, sub, tint, fills[], lines[], seed, opacity?, lineWidth?, redrawn? }
const E = (name, sub, tint, fills, lines, seed, o = {}) => ({ name, sub, tint, fills, lines, seed, opacity: 1, lineWidth: 1.8, ...o });

// Bottom bar: MATERIALS (what you add). Nine slots. Seeds keep their 4a values.
export const MATERIALS = [
  E('Acorn', 'Oak', '#c98a3e', ['M5 10 Q12 3 19 10 Z', 'M6.5 10 Q6.5 20 12 22 Q17.5 20 17.5 10 Z'], ['M12 5.5 V2.5'], 0),
  E('Cone', 'Pine', '#8a5a3a', ['M12 2 Q18 8 16.5 15 Q15 20.5 12 22 Q9 20.5 7.5 15 Q6 8 12 2Z'], ['M8 9 L16 15 M16 9 L8 15 M7.5 13 L12 17 L16.5 13'], 1),
  E('Sprig', 'Willow', '#7fa35a', ['M10.2 22 Q10.2 12 14.2 2.6 L15.9 3.4 Q12.1 12.5 12.1 22Z', 'M11 16.8 Q3.2 16.8 2.2 9.4 Q10.2 9.8 11 16.8Z', 'M13.2 11.2 Q20.8 10.7 21.8 3.4 Q14 3.8 13.2 11.2Z', 'M11.4 21 Q18.4 21 20.6 14.6 Q13.4 14 11.4 21Z'], [], 2, { redrawn: true }),
  E('Clover', 'Meadow', '#b8607a', [C(12, 8, 4.4), C(7.8, 9.6, 3), C(16.2, 9.6, 3), C(9.2, 5, 2.6), C(14.8, 5, 2.6), C(12, 3.4, 2.4), 'M10.9 12 H13.1 V22.2 H10.9Z', 'M12.6 19.2 Q14 14.4 19.8 13.9 Q18.7 19 12.6 19.9Z'], [], 3, { redrawn: true }),
  E('Clock', 'Dandelion', '#d6c290', DANDELION_FILLS, DANDELION_LINES, 4, { lineWidth: 0.8, redrawn: true }),
  E('Reed', 'Cattail', '#8a5a34', ['M8.8 4.2 Q8.8 2.6 12 2.6 Q15.2 2.6 15.2 4.2 V13.4 Q15.2 15.2 12 15.2 Q8.8 15.2 8.8 13.4Z', 'M11.35 3 V0.8 H12.65 V3Z', 'M10.9 14.6 H13.1 V22.6 H10.9Z', 'M12.6 22.6 Q16.6 17 18 7.2 Q20.2 10 19.4 13.6 Q18 19.6 14.8 22.6Z'], [], 5, { redrawn: true }),
  E('Water', 'Spring', '#4f8fc0', ['M12 3 Q19 12 19 16 A7 7 0 0 1 5 16 Q5 12 12 3Z'], ['M9 15 Q9 18 11.5 19'], 6),
  E('Crystal', 'Quartz', '#9b7fc9', ['M7.5 21 L5.5 11 L8.5 6 L11.5 11 L9.5 21Z', 'M13 21 L12 8 L15 3 L18 8 L16.5 21Z'], [], 8),
  E('Frost', 'Winter', '#7fbfd0', snowflake(), [], 9, { redrawn: true }),
];
export const MATERIAL_GROUPS = [
  { id: 'seeds', items: [0, 1, 2, 3, 4, 5] },
  { id: 'terrain', items: [6, 7] },
  { id: 'weather', items: [8] },
];
export const DIVIDER_BEFORE = [6, 8];

// Redrawn river pebble (seed 7). Stone · Raise left the bar; keep this for a future "River stone · Place".
export const RESERVE = {
  stone: E('River stone', 'Place', '#8f8a86', ['M2.5 14.5 C2.5 9.5 7.5 7.5 12.5 7.5 C18 7.5 21.5 10 21.5 14 C21.5 18 17 20 12 20 C6.5 20 2.5 18.5 2.5 14.5Z'], [], 7, { redrawn: true }),
};

// Side bar: THE TOOL ROLL (how you shape). Seeds 10–14, top to bottom.
export const SHAPING_TOOLS = [
  E('Hand', 'Mould', '#e0a07a', [
    'M7 11.5 Q7 10 8.5 10 L16.5 10.5 Q18 10.6 17.8 12 L17 17 Q16 21.5 12 21.5 Q8 21.5 7.3 17Z',
    'M7.2 11 L7 5.4 A1.25 1.25 0 0 1 9.5 5.3 L9.7 11Z',
    'M10 10.5 L10.2 3.4 A1.25 1.25 0 0 1 12.7 3.5 L12.5 10.6Z',
    'M12.9 10.7 L13.5 4.4 A1.2 1.2 0 0 1 15.9 4.7 L15.3 11Z',
    'M15.6 11.2 L16.6 6.6 A1.1 1.1 0 0 1 18.7 7.1 L17.7 12Z',
    'M7.6 15.5 L3.8 11.8 A1.3 1.3 0 0 1 5.6 9.9 L9.2 13Z',
  ], ['M9.5 15.5 Q12 17 15 14.8'], 10, { opacity: 0.82 }),
  E('Paddle', 'Mass', '#c49a5e', ['M5.5 12 Q5.5 9.5 8 9.5 H16 Q18.5 9.5 18.5 12 V19 Q18.5 22 15.5 22 H8.5 Q5.5 22 5.5 19Z', 'M10.7 9.6 V2.9 A1.3 1.3 0 0 1 13.3 2.9 V9.6Z'], ['M9 13 V19 M15 13 V19', 'M10.9 5.6 H13.1'], 11),
  E('Chisel', 'Cut', '#6f8aa6', ['M6 2.8 Q6 2 6.8 2 H10.2 Q11 2 11 2.8 V10.5 H6Z', 'M6.8 10.5 H10.2 V18.5 L9.2 21.8 H7.8 L6.8 18.5Z', 'M13 4 Q13 3 14 3 H21 Q22 3 22 4 V8.5 Q22 9.5 21 9.5 H14 Q13 9.5 13 8.5Z', 'M16.6 9.5 H18.4 V21 Q18.4 22 17.5 22 Q16.6 22 16.6 21Z'], ['M5.8 10.5 H11.2', 'M6.8 18.5 H10.2', 'M15.5 3 V9.5'], 12),
  E('Wire', 'Slice', '#b8683f', ['M8.6 20.9 L6.6 22.9 L1.1 17.4 L3.1 15.4Z', 'M22.9 6.6 L20.9 8.6 L15.4 3.1 L17.4 1.1Z'], ['M6.2 17.8 L17.8 6.2'], 13),
  E('Hammer', 'Break', '#7a6a5a', ['M3 5.5 Q3 4.5 4 4.5 H15 L20.5 7.2 L15 9.8 H4 Q3 9.8 3 8.8Z', 'M8.2 9.8 H10.8 V20.8 A1.3 1.3 0 0 1 8.2 20.8Z'], ['M12.5 4.5 V9.8'], 14),
  // 5: wind held in hand. Gusts only; the prevailing wind lives in the almanac.
  E('Feather', 'Gust', '#cbb994', ['M4.6 21.2 Q5.4 11 17.6 2.8 Q19.6 1.8 20.6 3.2 Q21.2 4.6 19.8 6.6 Q12.8 17.4 4.6 21.2Z'], ['M3.2 22.6 L17.2 6', 'M9.4 15.2 L6.6 14.4', 'M12.6 11.4 L10 10.2', 'M11.6 15.2 L14.4 14.6', 'M15 11 L17.4 10.8'], 15, { lineWidth: 1.2 }),
];
export const TOOL_DIVIDER_BEFORE = [5];
// Feather lane width (px, 1440 space) and burst ring max, per size pip.
export const GUST = { laneWidth: [20, 34, 52], holdToBurstMs: 400, burstMaxScale: 1.5, cursorTilt: -18 };
export const OPTIONAL_TOOLS = [4];
export const DEFAULT_HELD = { bar: 'side', index: 0 };

export const SIZES = [
  { id: 'small', pip: 8, hit: 16, scale: 0.6 },
  { id: 'medium', pip: 12, hit: 20, scale: 1 },
  { id: 'large', pip: 18, hit: 24, scale: 1.5 },
];

export const TOKENS = {
  cloth: 'rgba(98,88,74,.76)', weave: 'rgba(20,14,8,.12)', weft: 'rgba(255,240,215,.035)',
  hem: 'rgba(227,215,189,.3)', ink: '#e3d7bd', hairline: 'rgba(227,215,189,.45)',
  pressed: 'rgba(20,14,8,.2)', pressedShadow: 'inset 0 2px 5px rgba(10,8,4,.32), inset 0 -1px 0 rgba(255,240,215,.06)',
  hover: 'rgba(20,14,8,.1)', hoverShadow: 'inset 0 2px 5px rgba(10,8,4,.16), inset 0 -1px 0 rgba(255,240,215,.03)',
  focus: '#e3d7bd', cue: 'rgba(227,215,189,.5)', locked: '#a89d8b',
  barShadow: 'inset 0 1px 0 rgba(255,240,215,.09), 0 6px 18px rgba(18,22,30,.2)',
  restOpacity: 0.6, restOffsetBottom: 8, restOffsetSide: 6,
  reach: '250ms cubic-bezier(.25,.1,.25,1)', recede: '400ms cubic-bezier(.25,.1,.25,1) 300ms',
  light: '#fffaf0', shade: '#1a140e',
};
export const LOCKED_FILL = TOKENS.locked;

const hx = (h) => [1, 3, 5].map((k) => parseInt(h.slice(k, k + 2), 16));
export const mix = (a, b, t) => {
  const A = hx(a), B = hx(b), c = Math.max(0, Math.min(1, t));
  return '#' + A.map((v, k) => Math.round(v + (B[k] - v) * c).toString(16).padStart(2, '0')).join('');
};

// 4a parameters, unchanged: N=4, lift 1.3, drop 1.1, jitter 0.55. Deterministic per seed.
export function facets(seed, base, { N = 4, lift = 1.3, drop = 1.1, jit = 0.55 } = {}) {
  let s = seed * 131 + 7;
  const r = () => (s = (s * 9301 + 49297) % 233280) / 233280;
  const st = 26 / N, V = [];
  for (let y = 0; y <= N; y++) for (let x = 0; x <= N; x++) {
    const edge = !x || !y || x === N || y === N;
    V.push([-1 + x * st + (edge ? 0 : (r() - 0.5) * st * 0.75), -1 + y * st + (edge ? 0 : (r() - 0.5) * st * 0.75)]);
  }
  const at = (x, y) => V[y * (N + 1) + x], out = [];
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const a = at(x, y), b = at(x + 1, y), c = at(x, y + 1), d = at(x + 1, y + 1);
    const tris = (x + y) % 2 ? [[a, b, d], [a, d, c]] : [[a, b, c], [b, d, c]];
    for (const q of tris) {
      const cx = (q[0][0] + q[1][0] + q[2][0]) / 3, cy = (q[0][1] + q[1][1] + q[2][1]) / 3;
      const t = (cx + cy) / 48 + (r() - 0.5) * jit;
      out.push({
        points: q.map((v) => v[0].toFixed(2) + ',' + v[1].toFixed(2)).join(' '),
        fill: t < 0.5 ? mix(base, TOKENS.light, (0.5 - t) * lift) : mix(base, TOKENS.shade, (t - 0.5) * drop),
      });
    }
  }
  return out;
}

// bar: 'bottom' | 'side'. selected lights the base tint 10%; locked = flat pale-linen silhouette.
export function iconData(bar, i, { selected = false, locked = false } = {}) {
  const e = (bar === 'side' ? SHAPING_TOOLS : MATERIALS)[i];
  const base = selected ? mix(e.tint, '#ffffff', 0.1) : e.tint;
  return {
    name: e.name, sub: e.sub, label: e.name + ' · ' + e.sub, seed: e.seed,
    silhouette: e.fills,
    triangles: locked ? [{ points: '-1,-1 25,-1 25,25 -1,25', fill: LOCKED_FILL }] : facets(e.seed, base),
    lines: locked ? [] : e.lines, lineWidth: e.lineWidth,
    lineColor: mix(e.tint, TOKENS.shade, 0.45),
    opacity: locked ? 1 : e.opacity,
    shadowY: locked ? 0 : selected ? 1 : 2,
  };
}

// ───────────── 5 · THE ALMANAC (air) ─────────────
const PI = Math.PI;
const rays = [C(12, 12, 5.2)];
for (let k = 0; k < 8; k++) { const a = k * PI / 4; rays.push(bar(12 + Math.cos(a) * 7.2, 12 + Math.sin(a) * 7.2, a, 3.2, 2.2)); }
// Crescent: outer circle (11,12.4) r8.6 minus inner (15.8,8.4) r7.4, sampled to one polygon (no masks needed).
const crescent = () => {
  const c1 = [11, 12.4], r1 = 8.6, c2 = [15.8, 8.4], r2 = 7.4, n = 120, D = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
  const a2 = Math.atan2(c2[1] - c1[1], c2[0] - c1[0]), outer = [], inner = [];
  for (let i = 0; i < n; i++) { const a = a2 + i / n * 2 * PI, p = [c1[0] + r1 * Math.cos(a), c1[1] + r1 * Math.sin(a)]; if (D(p, c2) >= r2) outer.push(p); }
  const a1 = Math.atan2(c1[1] - c2[1], c1[0] - c2[0]) + PI;
  for (let i = 0; i < n; i++) { const a = a1 + i / n * 2 * PI, p = [c2[0] + r2 * Math.cos(a), c2[1] + r2 * Math.sin(a)]; if (D(p, c1) < r1) inner.push(p); }
  const last = outer[outer.length - 1]; if (D(inner[inner.length - 1], last) < D(inner[0], last)) inner.reverse();
  return P([...outer, ...inner]);
};
export const SEASON_TINT = { Spring: '#93b86c', Summer: '#6c9a4a', Autumn: '#c27c3e', Winter: '#cfd8de' };
export const WIND_DROOP = { Calm: 40, Light: 22, Brisk: 10, Gale: 0 }; // degrees the sock hangs below level
// Windsock: pole + sock rotated about (5.2, 8.2) by the droop angle.
export const windsock = (deg) => {
  const a = deg * PI / 180, rot = (q) => { const x = q[0] - 5.2, y = q[1] - 8.2; return [5.2 + x * Math.cos(a) - y * Math.sin(a), 8.2 + x * Math.sin(a) + y * Math.cos(a)]; };
  const S = [[5.2, 4.2], [21, 6.6], [21, 10.4], [5.2, 12.2]].map(rot);
  const L = [[[10.4, 5], [10.4, 11.6]], [[15.6, 5.8], [15.6, 11]]].map((l) => { const p0 = rot(l[0]), p1 = rot(l[1]); return 'M' + p0.map((v) => v.toFixed(2)).join(' ') + ' L' + p1.map((v) => v.toFixed(2)).join(' '); });
  return E('Sock', 'Wind', '#c47c5c', ['M3.4 2.4 H5.2 V22.4 H3.4Z', P(S)], L, 20, { lineWidth: 1.4 });
};
export const plate = (season) => E('Plate', season, SEASON_TINT[season], ['M12 4.4 L21.4 9.6 L12 14.8 L2.6 9.6Z', 'M2.6 9.6 L12 14.8 L21.4 9.6 L21.4 12.6 L12 18 L2.6 12.6Z', C(20.3, 16.8, 1.2)], ['M2.6 9.6 L12 14.8 L21.4 9.6', 'M4 17.4 Q12 22.8 19.2 17.6'], 18, { lineWidth: 1.3 });
const ub = [], ucx = 12.8, ucy = 13.4;
for (let i = 0; i <= 24; i++) { const a = -PI + i / 24 * PI; ub.push([ucx + 7.8 * Math.cos(a), ucy + 7.8 * Math.sin(a)]); }
for (let i = 24; i >= 0; i--) { const a = -PI + i / 24 * PI; ub.push([ucx + 4.6 * Math.cos(a), ucy + 4.6 * Math.sin(a)]); }

// The almanac's pockets, top to bottom. Divider before index 1. Mood is drawn as a vignette, not an icon.
export const AIR_ICONS = {
  sun: E('Sun', 'Day', '#e2b25e', rays, [], 16),
  moon: E('Moon', 'Night', '#c9cfdf', [crescent()], [], 17),
  plate, // seed 18, tinted by season
  globe: E('Globe', 'Weather', '#9fb4c0', [C(12, 10, 7.6), 'M6 16.6 H18 L19.6 21.4 Q19.7 22 19.1 22 H4.9 Q4.3 22 4.4 21.4Z'], ['M5.4 17.6 H18.6', 'M5.6 13.2 Q12 9.8 18.4 13.2', 'M9 6.6 L9 6.7 M14.6 5.6 L14.6 5.7 M12 9 L12 9.1 M16 9.6 L16 9.7 M7.6 10.2 L7.6 10.3'], 19, { lineWidth: 1.5 }),
  windsock, // seed 20, droop by strength
};
export const ALMANAC = [
  { id: 'mood', tag: (v) => 'Mood · ' + v.moodTitle, whisper: null, click: 'openPage' },
  { id: 'time', tag: (v) => 'Time · ' + v.time, whisper: 'or click the sky', click: 'snapDayNight', cue: 'snap' },
  { id: 'season', tag: (v) => 'Season · ' + v.season, whisper: 'or spin the plate by its rim', click: 'nextSeason', cue: 'turn' },
  { id: 'weather', tag: (v) => 'Weather · ' + v.weather, whisper: 'or shake the plate', click: 'nextWeather', cue: 'jiggle' },
  { id: 'wind', tag: (v) => 'Wind · ' + v.wind + ', from the ' + v.windFrom, whisper: 'or press and pull in the sky', click: 'nextStrength', drag: 'turnDirection', cue: 'lift' },
];
export const ALMANAC_DIVIDER_BEFORE = [1];
// One-shot hover cues: [ms, state]. null = back to rest. Played once per hover while the gesture is undiscovered.
export const CUES = {
  jiggle: [[0, { rotate: -9 }], [90, { rotate: 7 }], [180, { rotate: -4 }], [270, { rotate: 0 }], [380, null]], // pivot 50% 80%, 90 ms ease-out steps
  turn: [[0, { rotate: -24 }], [560, { rotate: 0 }], [900, null]], // 320 ms ease each way
  snap: [[0, { icon: 'moon' }], [520, null]], // hard swap, no fade
  lift: [[0, { droop: 'half' }], [80, { droop: -2 }], [460, { droop: 'half' }], [540, null]], // redraw sock per step
};

// Roll foot: Undo and Photo, 32 px slots, 24 px icons.
export const ROLL_FOOT = [
  E('Undo', 'Back', '#b5a78c', [P(ub), P([[ucx - 2.6, ucy - 0.2], [ucx - 9.8, ucy - 0.2], [ucx - 6.2, ucy + 5.6]])], [], 21),
  E('Camera', 'Photo', '#8f8a86', ['M3 8.2 Q3 6.6 4.6 6.6 H8 L9.6 4.4 H14.4 L16 6.6 H19.4 Q21 6.6 21 8.2 V17.8 Q21 19.4 19.4 19.4 H4.6 Q3 19.4 3 17.8Z'], ['M15.6 13 A3.6 3.6 0 1 0 8.4 13 A3.6 3.6 0 1 0 15.6 13', 'M17.6 9.2 L17.7 9.2'], 22, { lineWidth: 1.5 }),
];
export const ROLL_FOOT_WHISPER = ['or Cmd Z', 'the cloth steps out of the shot'];

// Moods. 'world' is shown first once anything differs from the made look. Descriptions other than Alpine morning are placeholder copy.
export const MOODS = [
  ['world', 'This world', 'The look it was made with.', '#8b95a2', '#c4bfb2', '#4f8a5a', 'Summer', 'Midday', 'Fair', 'Granite', 'Light', 23],
  ['alpine', 'Alpine morning', 'Clear blue air. Sunlit stone.', '#7ea3c4', '#e8dcc0', '#6c9a58', 'Summer', 'Morning', 'Clear', 'Granite', 'Light', 24],
  ['golden', 'Golden meadow', 'Warm haze over long grass.', '#b89c68', '#f0cf86', '#9ea247', 'Summer', 'Golden hour', 'Fair', 'Sandstone', 'Calm', 25],
  ['copper', 'Copper autumn', 'Rust leaves under a low sun.', '#9c7a6c', '#e2a462', '#b0703c', 'Autumn', 'Golden hour', 'Leaf fall', 'Sandstone', 'Brisk', 26],
  ['rose', 'Rosewater dusk', 'Pink light pooling in the hollows.', '#8a7c9c', '#e2aaa2', '#6a8c6c', 'Spring', 'Dusk', 'Fair', 'Slate', 'Light', 27],
  ['forest', 'Enchanted forest', 'Green gloom and drifting motes.', '#4c6c6c', '#9cc2a0', '#2f6c4c', 'Summer', 'Dusk', 'Mist', 'Basalt', 'Calm', 28],
  ['hollow', 'Halloween hollow', 'Bruised sky, a lantern moon.', '#4c3c54', '#d27c3c', '#4c5c3c', 'Autumn', 'Night', 'Mist', 'Basalt', 'Brisk', 29],
  ['snow', 'First snow', 'Soft white on every ridge.', '#a8b2be', '#e8e8ea', '#dde3e8', 'Winter', 'Morning', 'Snow', 'Granite', 'Light', 30],
  ['nordic', 'Nordic night', 'Deep blue with a thin green seam.', '#2a3452', '#5c7c9c', '#3a5048', 'Winter', 'Night', 'Clear', 'Slate', 'Calm', 31],
  ['rain', 'After the rain', 'Wet stone, washed air.', '#7a8a96', '#c8d0c6', '#5a8c62', 'Spring', 'Morning', 'Overcast', 'Slate', 'Light', 32],
].map((a) => ({ id: a[0], title: a[1], desc: a[2], sky: a[3], glow: a[4], grass: a[5], season: a[6], time: a[7], weather: a[8], rock: a[9], wind: a[10], seed: a[11] }));

export const SEASONS = ['Spring', 'Summer', 'Autumn', 'Winter'];
export const TIMES = ['Dawn', 'Morning', 'Midday', 'Golden hour', 'Dusk', 'Night', 'Turning day'];
export const WEATHERS = ['Clear', 'Fair', 'Overcast', 'Mist', 'Rain', 'Storm', 'Snow', 'Leaf fall'];
export const WINDS = ['Calm', 'Light', 'Brisk', 'Gale'];
export const ROCKS = ['Granite', 'Slate', 'Sandstone', 'Basalt'];
export const CUSTOMISE_ROWS = [['season', SEASONS], ['time', TIMES], ['weather', WEATHERS], ['wind', WINDS], ['rock', ROCKS]];
export const COLOURS = {
  grass: ['#4f8a5a', '#6c9a58', '#9ea247', '#6a8c6c', '#b0703c', '#dde3e8'],
  leaves: ['#5a8a3c', '#7fa35a', '#c98a3e', '#b8683f', '#8a4a3a', '#3c5a3c'],
  rock: ['#8f8a86', '#6e7278', '#b89a78', '#4a4a50', '#a8a098', '#7a6a5a'],
  earth: ['#6a4a32', '#8a5a3a', '#5a3e2c', '#a0704a', '#3e2e24', '#7a6250'],
  water: ['#4f8fc0', '#3f7a9a', '#6aa8b8', '#2f5a7a', '#7fbfd0', '#5a7a6a'],
  sky: ['#7ea3c4', '#8a7c9c', '#b89c68', '#2a3452', '#a8b2be', '#4c3c54'],
  mist: ['#dfe4e8', '#c8d0c6', '#e2aaa2', '#b8c0cc', '#9cc2a0', '#e8dcc0'],
};

// Pin model (unchanged behaviour): value = pins[key] ?? mood[key]. Setting pins; knot click deletes; Back to mood clears.
export const resolve = (mood, pins) => {
  const v = {};
  for (const [key] of CUSTOMISE_ROWS) v[key] = pins[key] ?? mood[key];
  for (const key of Object.keys(COLOURS)) v['c_' + key] = pins['c_' + key] ?? (key === 'grass' ? mood.grass : key === 'sky' ? mood.sky : key === 'mist' ? mood.glow : COLOURS[key][0]);
  return v;
};

// Mood vignette, viewBox 40x25 (stretched to the card). Three facet fills, each scaled by (40/24, 25/24):
//   sky  = facets(seed, sky) over the whole card
//   glow = facets(seed+40, glow) clipped to horizon band  M0 10.5 L40 8.6 L40 16.4 L0 17.6Z
//   land = facets(seed+80, grass) clipped to slab top      M3 18.2 L20 13.4 L37.5 16.8 L21 22.2Z
//   side = mix(grass, shade, .55) flat                     M3 18.2 L21 22.2 L37.5 16.8 L37.5 19.4 L21 25.5 L3 20.8Z
//   sun/moon disc r1.9 at (30, sy): Night -> #e6eaf2, sy 5.5; Dawn/Golden hour/Dusk -> mix(glow,#fffaf0,.55), sy 10; else #fff3d6, sy 5.5
export function vignette(m) {
  const low = ['Dawn', 'Golden hour', 'Dusk'].includes(m.time), night = m.time === 'Night';
  return {
    sky: facets(m.seed, m.sky), glow: facets(m.seed + 40, m.glow), land: facets(m.seed + 80, m.grass),
    side: mix(m.grass, TOKENS.shade, 0.55),
    sun: night ? '#e6eaf2' : low ? mix(m.glow, TOKENS.light, 0.55) : '#fff3d6', sunY: low ? 10 : 5.5,
  };
}
export const VIGNETTE_SIZES = { strip: [44, 28], card: [78, 49], world: [56, 35], mini: [22, 14] };

export const AIR_TOKENS = {
  page: 'rgba(98,88,74,.8)', pageWidth: { moods: 320, customise: 360 }, pageGap: 10,
  knot: '#e3d7bd', knotShadow: 'inset 0 -1px 0 rgba(26,20,14,.35), 0 1px 0 rgba(12,9,5,.3)', knotHalo: 'rgba(227,215,189,.14)',
  chipStitch: 'rgba(227,215,189,.22)', rule: 'rgba(227,215,189,.3)', whisperInk: '#d6cbb2',
  swatchStitch: 'rgba(255,250,240,.35)', swatchEdge: 'inset 0 -1.5px 0 rgba(26,20,14,.25), 0 0 0 1px rgba(20,14,8,.25)',
  groundMark: 'rgba(255,250,240,.85)', laneFill: 'rgba(255,250,240,.07)', laneDash: [6, 6],
  reachX: 1260,
};
