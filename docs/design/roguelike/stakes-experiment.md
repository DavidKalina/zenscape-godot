# Stakes, an experiment (2026-10-12)

> Branch `experiment/stakes`, cut from `roguelike` at d7eb317b. Only under
> `--shape=sprawl`. Round 3's shape (no `--shape`) is unchanged.

The user: "making it feel just a little bit like there are stakes. Like you
can actually fall off and die... a designated starting point that makes
sense... pretty easy to see where you're headed next." This is something to
play and feel. It is not a final system.

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
```

Good seeds: 11 (the start looks straight down the route to the serpent
gulf, and the gate leads to 12), 3 and 15. Without `--seed=` a seed is drawn.

## What a run is now

- **A run** starts at layer 1 on a seed. The corner shows a small readout:
  `layer 2   3 runes`. The layer's long card (seeds, isles, gulfs) is
  hidden. **I** shows it.
- **Through the gate**: a warm flash, and you stand at the next layer's
  start (the region you saw far off). The layer count goes up and your
  runes come with you. A caption ("Layer 2") fades in and out.
- **Into the void** (below the plan's `void_y`): you keep falling for
  1.1 s, then the screen goes dark over 1.3 s. A quiet card follows:

  ```
  Fell from layer 3

  2 runes lost          (or "nothing carried")
  6:41

  deepest: layer 4      (or "the deepest yet")

  space  climb again          r  the same climb
  ```

  - **Space** (or Enter, E, pad A) starts a new run at layer 1 on a new
    seed.
  - **R** (pad X) replays the same run seed.
  - The new climb is laid on a worker behind the card while you read it,
    so it is usually ready by the time you press.
- **A fall onto a lower isle** is still just a setback, with its fall stun.
- **Runes** (the greed branch's set) are counted per run. They are lost
  when you fall and kept through the gate. They buy nothing yet.
- **The record** lives in `user://run_record.json`: the deepest layer, the
  runs and the falls. The card reads from it.
- **Dev keys** still work:
  - **N** counts as going a layer deeper.
  - **Shift+N** and **Backspace** keep the layer count.
  - **R** outside the card is still the study's "back to the start".

## The start spot

`scripts/roguelike/start_spot.gd` builds the start at the plan's spawn on
the base. The spawn's position is still the one layer_sprawl.gd chooses,
which sees the next region.

- **The landing**: a worn stone landing (`RuinKit.floor_slabs`) under your
  feet. It is laid at 1, 0.75 or 0.55 scale, whichever is the largest that
  lies flat on the turf.
- **The piers**: two broken piers (`RuinKit.pier`, weathered) behind you
  and to each side. They are what's left of an arch you came through. The
  camera looks out between them. A pier is skipped if its ground is off
  or something already stands there.
- **The lantern**: a lit stone lantern (the stone lamp mesh, its core,
  halo and a shadowed warm light) at the landing's front corner. It is
  lit by day too, more fully at night.
- **The facing** (`face_for`) takes the direction to the main line's first
  crossing and turns it toward the next cluster's highest point, halfway
  if the two are within 100 degrees. The first frame looks that way.

## The way on (`scripts/roguelike/way_lights.gd`)

There are no screen markers. Lights in the world show the way:

- **Main-line lanterns.** The main line is the route from the base to the
  exit chain (`main_line`). A stone lantern stands beside the start of
  each of its crossings, plus the chain's first crossing. The gulf's far
  pier gets one too, and a light hangs 9 m over its near pier because the
  base's hill can hide the pier from the start. Side crossings and the
  greed branch stay dark: a lit rim means onward.
- **Cluster tops.** Each further cluster's highest point has a broad faint
  halo and a warm light hung over it.
- **The gate's beam** marks the end, as before.

Lanterns on motif isles wait, hidden, until the isle under them has stood.

## Files

| File | What |
|---|---|
| `scripts/roguelike/run_state.gd` | The run (seed, depth, runes, time) and the record file |
| `scripts/roguelike/run_loop.gd` | The state machine: play, falling, card, gate, arrive. Keys. Lays the start spot and the lights when a layer stands |
| `scripts/roguelike/run_overlay.gd` | Readout, veil, caption, card |
| `scripts/roguelike/start_spot.gd` | The start spot and its facing |
| `scripts/roguelike/way_lights.gd` | The lanterns and the hung lights |
| `studies/run_layer.gd` | Small hooks: makes a RunLoop under sprawl, `before_tick` / `after_tick` round `tick`, `layer_stood` at the end of `_stand_layer`, input first, no toast in run mode, card hidden. Round 3's path is untouched |

layer_sprawl.gd and layer_stage.gd are not touched.

## Checks

Following the prototyping rule that came in mid-round, there are no
committed tests and the slow layer tests were not run.

- **Headless import:** clean.
- **Smoke run:** run_layer `--shape=sprawl --seed=11`, headless, 2400
  frames. No script errors.
- **Throwaway play-loop check** (`tests/test_run_stakes.gd`, left
  uncommitted in the worktree). It drives the study's own `tick`:
  - the run starts at layer 1;
  - two runes are carried;
  - through the gate is layer 2 of the same run (the region seen), with
    the runes kept;
  - the void gives "falling", then the card after 2.4 s ("Fell from layer
    2 / 2 runes lost"), and holds you still meanwhile;
  - the deepest layer is written and read back;
  - Space starts layer 1 on a new seed with nothing carried;
  - after another fall, R replays the same seed;
  - the record counts the runs and the falls;
  - the start spot stands on solid ground, and you stand still on it;
  - the camera's first frame looks along the chosen facing;
  - part of the first crossing's way is in sight;
  - the main line's lanterns all stand.

  29 of 30 checks pass. The one that fails: on seed 13, the first crossing
  (stones, 94 degrees off the spawn's view) and the next cluster are 118
  degrees apart. The start faces the crossing turned 45 degrees toward the
  cluster, so the cluster sits 73 degrees off and out of the first frame.

**Existing tests this breaks:**
- **tests/test_layer_sprawl.gd**, at `_sprawl_gate`'s last check, "Into
  the void, the next layer (seed n -> n+1)". The void now ends the run
  with a 2.4 s fall and a card, so 30 ticks later the seed hasn't moved on.
  It would also write the player's `user://run_record.json` unless it
  points `RunState.record_path` elsewhere.
- **tests/test_run_layer.gd** (round 3's shape) should be unaffected: no
  RunLoop is made without `--shape=sprawl`. Not run.

## Unverified (headless can't see it)

- **The whole feel**:
  - the dark fade's timing;
  - whether the card reads quiet or bleak;
  - whether the warm flash at the gate is too bright (`RunOverlay.WARM`
    at full alpha).
- **Whether the lanterns can be seen by day** (`DAY_GLOW` 0.45 of the
  night glow), and whether the hung lights read as "over there" or as
  floating blobs. The cluster-top halo is 7 m wide.
- **The start spot's look**: the piers' size beside the pilot, slabs
  hanging off a slope, the piers framing the camera.
- **Windowed timing behind the card**: a random seed plans in 1-16 s
  headless, longer windowed. Pressing Space before it's ready shows "...".
- **The base's hill** often hides the gulf's near rim from the spawn
  (seeds 6, 11, 12: no base perch sees it). The serpent or ferry in the
  sky and the hung pier light have to carry it.

## Next steps for stakes

- **The dragon.** A knock-off into the void now costs the run, which is
  exactly the stake the roost dragon needs (cover from his sight).
- **A shop or an altar between layers** where carried runes buy something,
  so losing them hurts.
- **Move picks at the gate** ("take one of three"), which turns depth into
  power.
- **Smaller things:**
  - a checkpoint at every few layers;
  - "the same climb" kept in the record so a seed can be shared;
  - a better start position on seeds where the first crossing is off to
    the side (move the spawn, which is layer_sprawl.gd's call).
