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

## Rounds 3 to 5 (2026-11-14, Windows): a test of flight, parked

Main merged in first. The user flew each build; the direction moved from
embers to "screw the parrying, I just want to chase him", then to the raider
as a retuned rival that is beaten only by following its trail accurately.
The last flight: "He got away." Parked there.

Play (Windows): `python tools/play.py --no-pull -- --raider --raider-tape=res://scratch/flights/<tape>.flight`

- **A taped line** (`--raider-tape=FILE`, a flight taped with `--record`): no
  buzz. With the plane at cruise speed, within 150 m of the tape's line and
  flying its way, the raider shows up 30 m on along it and flies it on
  rails, at the chase's pace (`raider_chase.gd`, phase `tape`). At the
  tape's end it runs on by its own plans. Without the flag it buzzes and
  plans as before. The tapes are in `scratch/` (git-ignored), so a tape has
  to be flown again on another machine.
- **Its stream**: the ribbon, now 3 s long. The plane within 8 m of its line
  is in the stream (`raider.gd` `stream`): drawn along up to 16 m/s over its
  pace, the raider held 22 m ahead, the ribbon gold and wider. Out of it the
  raider runs at 1.15 x Boost, the plane + 7 m/s at least; past 140 m for
  3 s it's gone.
- **Beating it**: the bar at the top (`raider.gd` `follow`, class `Trail`)
  fills in the stream, full in 12 s on the ribbon's own line and 0.35 of
  that pace at the stream's edge, and drains over 30 s out of it. Full: a
  bell, BEATEN, it leaves. Got away: GOT AWAY.
- **Off in the chase**: embers (`--raider-embers` brings them back, now on a
  set arc: 0.9 s out to 14 m beside the line, 1.25 s straight in, the last
  0.3 s not following) and the surge roll's kill (`--raider-kill`).

Flags: `--raider-tape=`, `--raider-tape-lead=`, `--raider-keep-near=` (22),
`--raider-stream-r=` (8), `--raider-stream-over=` (16), `--raider-follow=`
(12), `--raider-ember-arc=` (14 m; 0: round 2's seek), `--raider-ember-in=`.

Checked: smoke with the tape, with `--raider` and with neither; a throwaway
driver through the real play loop (uncommitted). Steering straight at it:
28-30 s of 40 in the stream, the bar at 0.52 after 40 s at an 18 s fill.
Steering 14 m to one side: 8 s in the stream, the bar at 0, the gap wider.
BEATEN fired with the fill forced to 4 s. Nothing was looked at rendered.

Open:

- The user did not beat it by hand; whether that is the 12 s, the 8 m, the
  bar draining, or the trail being hard to read is not known.
- The opt-in the user asked for is not built: the rival's own parts (a
  traffic plane bracketed, R3 held, it bolts, the result, peeling back into
  the traffic) in place of it popping up on the line.
- It vanishes when beaten or lost. The bar and the result words are
  greybox, not the new UI's look.
- On rails it flies the tape faster than the tape was flown.
