# Noise and stealth, round 1 (prototype)

The Olmec heard only his head's call and beacons. Now everything loud goes
on one layer-wide noise bus, the wanderer's feet among it, and the Olmec
(headless or whole) goes to look where he heard something. Round 4's cards
that need it (the Echo / Twin Jars, the Tithe-Taker, the Bowing Court, the
Sleeper, the Swallowing Toad, the Whisper Wall) can listen and emit on the
same bus.

Prototype round: proved by smoke checks and throwaway drivers in `scratch/`,
no committed tests.

## The bus: `NoiseBus` (`scripts/noise/noise_bus.gd`)

A node named `NoiseBus` under the current scene, made the first time it is
asked for, so it lives and dies with the layer. Loudness is in metres: how
far off an ear of hearing 1 still hears it, faintly at the edge, fully at the
point.

```gdscript
# Make a noise (any node in the tree; it is the source unless `source` is given)
NoiseBus.make(self, at, 14.0, &"step")                    # -> NoiseBus.Sound
NoiseBus.of(get_tree()).emit(at, 14.0, self, &"step")     # same; emit(..., relayed) for an echo
# Hear
var bus := NoiseBus.of(get_tree())
bus.noise_made.connect(func(n: NoiseBus.Sound) -> void: ...)   # pushed, as made
for n: NoiseBus.Sound in bus.since(last_id): ...               # pulled; bus.last_id()
bus.recent(3.0, at, hearing)      # last 3 s heard at `at`, loudest there first
n.heard_at(p, hearing)            # 0 out of hearing .. 1 at the point
```

`NoiseBus.Sound`: `id`, `position`, `loudness`, `source` (may be freed),
`kind`, `time` (bus clock, s), `relayed` (the noise an echo repeats).
Kept `KEEP` (6 s). `clear()` drops them. Kinds made today: `step`, `land`,
`slam`, `grab`, `slide`, `splash`, `rune`, `break`, `olmec_land`.
No player is hard-wired: each wanderer's noises carry his own figure as
`source` (co-op: a second `WandererNoise`).

## What makes noise (m, at wanderer size 1)

`scripts/noise/wanderer_noise.gd`, stepped by `studies/character_study.gd`
after the motor and body (so every study and the layer):

| What | Loudness |
|---|---|
| footfall, sneak (under 0.45 of his run) | 1.0 to 1.5 |
| footfall, walk / run / carried past the run | about 4 / 14 / up to 24 |
| jump takeoff | his footfall + 2 |
| landing | 5 + 6 a metre fallen, at most 48 (hop 9, 4 m drop 29, 7 m 48); crouch pressed low before the touch x0.6 |
| slam | 30 + 20 x its power |
| ledge grab / climb over / wall kick / wall touch | 6 / 5 / 8 / 4 |
| slide start, then its scrape every 0.35 s | 10, then his footfall |
| skid | 9 |
| splash in / hop out | 11 / 6 |
| rune taken (`layer_stage.gd`) | 4 |
| breaks, via the breakables hub (`breakables.gd`) | crack 20, fall 28, boom 40, thud 18, drum ring 30, drum thud 14 |
| a body's landing / mantle / pounce shockwave (`headless_body.gd`) | 2.5 x its shockwave reach (about 24-41) |

**Sneak.** The motor had no slow pace. Held **Ctrl** (or Alt) eases the
stick to 0.4 (a 1.9 m/s creep, quiet): action `walk_sneak` in
`scripts/pad.gd`. On a pad, the stick eased does the same (under about
half stick is a sneak).

## How the Olmec hears (`scripts/enemies/body_hearing.gd`)

A heard noise is a weaker beacon: a `Lure` (a `Beacon` only its own body
heeds: no group, lights nothing) set where the noise was, blurred up to 5 m
at the edge of hearing. The body's beacon machinery does the rest: it stops
and listens, turns to it, routes there, stands looking `noise_dwell` s,
then tires of it.

- Heard within loudness x `hear_noise` m of its middle (x `noise_wall` 0.6
  with stone between).
- Priority: under a lit beacon (and so under its head in sight or calling,
  and under him seen when whole), over roaming and its head heard but not
  calling. Same `_beacon_free` gate as beacons.
- A better-heard noise takes over from the one it goes to, which fades over
  `noise_memory` s. One more than 6 m from it (or after it tired of
  looking) is news: it stops and listens again; nearer, the goal moves
  quietly.
- Never heard: its own noises, any other body's (`olmec_land`), its
  breaker's crashes within 3 body lengths, and noises older than 1 s when
  first polled.
- **The tell:** as it turns to a noise, a sift of dust off both shoulders
  and the `body_heard` voice, then the listen clip's pause and the turn.
- Knobs (`--body-knob=`): `hearing` 1/0, `hear_noise` 1.0,
  `noise_memory` 15, `noise_dwell` 4, `noise_wall` 0.6.

## His readout

`scripts/noise/noise_ripples.gd` + `shaders/noise_ripple.gdshader`: a noise
of his at 9 m or louder throws a soft ring of brushed dust out over the
ground at his feet, 0.7 m to 3.6 m across and gone in under a second. A
sneak or a walk makes none. `--noise-debug` (any scene) draws every noise's
hearing ring and each body's heard spot (a post).

## Try it

    godot --path . res://studies/whole_body_chase.tscn -- --no-title --ambient=0.1 --noise-debug
    godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=1 --noise-debug

## Proved (headless, scratch drivers, real loop and input)

`scratch/noise_hear.gd` in whole_body_chase, `--body-knob=chase=0` (pure
hearing), the wanderer moving by the stick 11 m off the Olmec's line:

| Case | Loudest | Turned | Went to it |
|---|---|---|---|
| run, 11 m off | 14 m | yes, 1.1 s | 11 m to 0.4 m |
| sneak (Ctrl), 11 m off | 1.4 m | no | - |
| sneak, 5 m off | 1.4 m | no | - |
| half stick, 11 m off | 1.5 m | no | - |
| run, 16 m off | 14 m | no (out of reach) | - |
| fall 3 / 6 / 10 m, 20 m off | 24 / 41 / 48 m | yes | 20 m to 3.7 m |
| same, crouch pressed before the touch | 14 / 25 / 29 m | no / yes / yes | |
| hop, 20 m off | 9 m | no | - |

With the chase on in the dark (`--ambient=0.1`): the run drew it, it came,
spotted him and wound up a pounce; the sneak went unnoticed.
`scratch/noise_headless.gd` (headless_body_isle, the generator's kind):
heard a run circling it 9 m off, not a sneak. `scratch/noise_self.gd`: five
of its own landings (24-41 m) went on the bus, it heard none.
`scratch/noise_break.gd`: a felled column's fall made six `break` noises.

## Seams

- Not rendered: the dust ring and the shoulder sift are unseen (no display
  here). Their sizes and alpha are first guesses.
- No sound assets: `body_heard` is a name handed to the scene's voice hook.
- Hearing ignores height except through the 3D distance and the wall ray;
  noise doesn't bend round corners.
- The whole Olmec keeps hearing while suspicious only through the sight's
  own alert; a noise heard while hunting is dropped.
- Landing loudness uses his fall height tracked in `WandererNoise`, not the
  motor's own `_fall_top`.
- Bodies poll every 0.25 s (`BEACON_POLL`); a noise is heard up to 0.25 s late.

## Existing tests

Run: the 21 tests that touch the changed files (character study, pad,
enemy ram, layer, world scale, scene picker and so on). 16 pass.
- `test_character_recordings.gd` (4) and `test_slide_carve.gd` (1) fail
  the same way on the base commit (checked on a clean copy): not this round.
- `test_gamepad.gd` failed once under load (two zenscape hand-hint checks)
  and passes alone, as on the base.
- `test_run_layer.gd` and `test_layer_sprawl.gd` timed out at 540 s under a
  6-job load, with generator geometry FAILs (seed 15 rim and corridor, seed
  6 exit chain); the beacons round recorded both as already failing on
  `roguelike`. Not re-run on the base here.
