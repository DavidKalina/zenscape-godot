# Handoff: the raider chase with embers

Branch `iter/raider-embers`, spec `spec-raider-embers.md`, four rounds
(`git log --grep='^ITER(raider-embers)'`). Everything is behind `--raider`;
the game without it is unchanged.

Play: `cd /Users/davidkalina/Documents/Projects/zenscape-raider-embers && python3 tools/play.py --no-pull -- --raider --pilot-file=/tmp/raider_pilot.json`

## What it does

- A raider buzzes you from behind (overhead or beside, a whoosh), then runs
  ahead low (`scripts/endless/raider_chase.gd`).
- Lock on (R3 / Y / middle mouse) to chase it. Not locked, 550 m off or 4 s
  out of view: it's gone, and the next one buzzes you after the gap.
  No offscreen arrow.
- While it runs it fires embers back from its tail
  (`scripts/endless/raider_embers.gd`). They go through the parry. A missed
  one knocks you (shove and wobble, chain lost, meter kept) and the raider
  pulls away for a moment. A parried one goes home onto it: it slows for a
  few seconds and trails smoke. Three stacked cripple it (slow, low, dark
  smoke) until it dies or leaves.
- With a full gauge, the surge roll that reaches it knocks it out of the sky.
  20 s later the next one buzzes you.
- `--raider-mode=dogfight` / `=mix` still reach the old fights.

## Numbers (defaults) and flags

| knob | default | flag |
|---|---|---|
| ember every | 2.2 s (about 1 per 3 s actually fired, it must be in view and 35-300 m off) | `--raider-ember-every=` |
| ember speed | 24 m/s | `--raider-ember-speed=` |
| ember seek | 0.6 rad/s | `--raider-ember-seek=` |
| slow per home hit | 0.12 of its pace | `--raider-slow=` |
| slow held after the last | 4 s | `--raider-slow-s=` |
| hit cap (crippled) | 3, then x0.64 pace for good, 0.75 x its low height | `--raider-hit-cap=` |
| let go | 550 m / 4 s out of view | `--raider-let-go=`, `--raider-let-go-s=` |
| gap between raiders | 20 s of flight (a kill waits the same) | `--raider-gap=` |

Its run is about 65 m/s against the plane's 57-62 at Boost, so a plane that
only follows loses it (gap 200 m at 20 s, 400 m at 60 s, with no parries).
Parries slow it to 49-52 m/s, and skim heat takes the plane to 72-78 m/s.

## Pacing (a driven run, real play loop)

`scratch/kill_check.gd` (uncommitted) holds Boost, steers onto the raider,
locks on, rolls when the parry's guess of the closest pass says now, and
on a full gauge rolls inside 22 m.

- Defaults, 130 s: kill 1 at 29.8 s after lock (3 parries), kill 2 at
  42.9 s after lock (5 parries), the next raider 20 s after each.
- `--raider-slow-s=6`: 34.4 s and 56.6 s. `--raider-slow-s=6 --raider-slow=0.15`:
  29.7 s and 38.7 s.
- No parries, 100 s: no kill, the gauge stays empty, gap 415 m.

The defaults land in the 30-60 s window and stayed as they were. Driven runs
vary (the driver crashes now and then and relaunches), so expect a real
flight to differ.

## Open

- Smoke reads weakly at range (mid-grey through the haze); a look pass could
  give it a bigger start or a little emission.
- Embers far off sit behind the plane in the chase cam and read small.
- Locked on and far behind (past ember range, 300 m) nothing happens until
  you close up or let it go.
- All greybox: the ember's look, the smoke, the sounds.
