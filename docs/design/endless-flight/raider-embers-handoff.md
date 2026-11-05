# Handoff: the raider chase with embers

Branch `iter/raider-embers`, spec `spec-raider-embers.md`, two rounds
(`git log --grep='^ITER(raider-embers)'`). Everything is behind `--raider`;
the game without it is unchanged.

Play: `cd /Users/davidkalina/Documents/Projects/zenscape-raider-embers && python3 tools/play.py --no-pull -- --raider --pilot-file=/tmp/raider_pilot.json`

## What it does (round 2)

- A raider buzzes you from behind (overhead or beside, a whoosh), then runs
  ahead low (`scripts/endless/raider_chase.gd`), a crimson ribbon at its tail
  and a wasp livery (black body, yellow wings, red trim).
- Lock on (R3 / Y / middle mouse) to chase it. Close in, the lock's brackets
  open round it so the plane shows (`scripts/endless/lock_on.gd`).
- It panics only when you're on its tail (within 80 m, your nose within 30
  deg of it, it flying away): it jinks (sharper turns, low, tree gaps the
  plane fits) and drops embers off its tail
  (`scripts/endless/raider_embers.gd`). Off its tail it fires nothing.
- Embers are laid in the plane's frame: each closes on you at 30 m/s
  whatever your pace, bowing in from one side, so from 40-80 m one takes
  1.3-2.7 s and the parry's whistle (1.1 s) plays out whole. It strikes at
  its nearest pass, which is what the whistle counts down to.
- A missed ember knocks you (shove, wobble, chain lost) and the raider
  surges away, off its tail. A parried one goes home: it staggers (no panic
  for 1.2 s) and slows; three cripple it.
- Behind past 200 m for 3 s, it gets away for good, locked or not. A full
  gauge's surge roll that reaches it (14 m) kills it. The next one buzzes
  after 20 s.
- `--raider-mode=dogfight` / `=mix` still reach the old fights (embers there
  keep the round 1 world-speed model).

## Numbers (defaults) and flags

| knob | default | flag |
|---|---|---|
| on its tail | 80 m, 30 deg, held 0.5 s past slipping off | `--raider-tail-m=`, `--raider-tail-deg=` |
| kept close | 1.12 x Boost out to 150 m, easing to 1.05 by 200; inside 40 m the plane's speed + 4 | `--raider-keep-far=`, `--raider-keep-near=` |
| getaway | past 200 m for 3 s | `--raider-getaway=`, `--raider-getaway-s=` |
| jink turn | 1.6 rad/s (0.9 calm), side flip every 1.3 s | `--raider-jink-turn=` |
| ember first / every | 0.6 s after getting on its tail, then 1.6 s | `--raider-ember-every=` |
| ember closing | 30 m/s in the plane's frame, seeks 3 rad/s until 10 m off, then straight; rides 2.5 m over rises | `--raider-ember-close=` (0 = round 1's world speed) |
| ember speed / seek (dogfight, mix) | 24 m/s, 0.6 rad/s | `--raider-ember-speed=`, `--raider-ember-seek=` |
| missed ember | keep 0.72 of speed, shove 14 m/s, raider x1.4 for 3 s | |
| parry stagger | 1.2 s no panic | `--raider-stagger=` |
| slow per home hit | 0.12 of its pace, held 4 s | `--raider-slow=`, `--raider-slow-s=` |
| hit cap (crippled) | 3, then x0.64 pace for good | `--raider-hit-cap=` |
| gap between raiders | 20 s | `--raider-gap=` |
| ribbon | 30 points every 0.05 s (1.5 s), 1.8 -> 0.5 m wide x SIZE, Color(1,0.12,0.26) | |
| reticle | brackets at 2.4 x the target's half size on screen (3.5 m unless it says), never under 30 px or over 220 | |

## Pacing (round 2, a driven run, real play loop)

`scratch/tail_check.gd` (uncommitted): Boost, steers onto it skimming,
locks on, rolls when the parry's guess of the nearest pass says now (even
on a full gauge with `--armed=1`), a surge roll inside 22 m.

- Before the closing embers: 12 fired in 90 s, 1 parried, no kill. At
  24 m/s world speed an ember closed at ~85 m/s, under the whistle, and the
  plane's weave threw its straight last 35 m 10-17 m wide.
- Closing embers, 90 s, parrying on a full gauge: kill 22.5 s after lock
  (3 parries, 0 hits). 150 s: 12 fired, 8 parried, 3 passed, 1 kill, 1 got
  away.
- Not parrying on a full gauge (holding the surge for the kill): 7 fired, 4
  parried, 3 hits, each hit knocking it out of reach; no kill in 90 s.
- A lazy line (no Boost, loose): no embers, it got away 2 of 3.

## Open

- The driver kills about one raider in three; a real pilot will differ.
  The tension left: a full gauge means a roll spends the surge, so on the
  run in you either parry (and lose the kill roll) or eat the knock-back.
- Not counted: how often it takes tree gaps or arches while jinking.
- All greybox: the ember's look, the smoke, the sounds.
