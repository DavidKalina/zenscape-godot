# Game v1: the run climbs up (2026-10-14)

> Branch `feature/v1-climb-up`, cut from `roguelike` at 76ee7b19. One part
> of the v1 stitch round. Prototype: no committed tests.

## Run it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --underground=torch
```

Walk the exit chain to the gate. Each gate puts you at the next layer's
start, higher, and the corner and the caption carry the true height. N
still skips a layer and counts the same way.

## What changed

- **The gate leads up, and the height is true.** The generator already
  laid the next region past the gate and above it (`LayerSprawl._place_next`:
  its base turf `RISE_ROLL` (25-60) + `RISE_OVER` (20) m over the gate,
  raised in 20 m steps until its landmark can be seen from the spawn). But
  the run counted the new start at the gate's height. Now the run loop
  takes the new start into the old layer's frame through the next region's
  `xform` and banks that:
  - `RunState.ascend(rise)` replaces `descend()`. The new start is banked
    `rise` over the old start, stood on, and counts toward the best.
  - `RunLoop._note_way_up` is called at the gate (and on N). It keeps the
    old layer's `next`, its start y, and the feet.
  - `RunLoop._rise_through` gives `(next.xform * new start).y - old start y`.
    If the layer laid isn't the region seen (a skipped seed, or `next` not
    laid yet), it falls back to the gate's height plus `next_rise(seed)`.
- **The words.** WORDS already spoke in heights (`FELL FROM 203 m`,
  `HIGHER STILL / 203 m`, `highest: 203 m`), so no player-facing word
  changed. Only the comments that said "a layer deeper" changed. The
  record file keeps its `deepest` key (the layer count, never shown)
  beside `highest`.
- **The dark lightens as the run climbs** (`RunLoop.CLIMB_LIGHTEN` 0.2 a
  layer past the first, at most `CLIMB_LIGHTEN_MOST` 0.6;
  `Underground.climb_lift`, `set_climb_lift`, `_lift_preset`):
  - It applies to the torch preset only. Its colours, fog, volume, ambient,
    moon, exposure and far haze are eased toward the haze preset's.
  - The torch's own light and range are left alone, because the Olmec's
    sight reads them (`light_level.gd`). So the change is air only, never
    who sees whom.
  - Growth is never touched.
  - Set `CLIMB_LIGHTEN` to 0 to turn it off.
- **The next region reads in the dark:**
  - **Haze.** Its underground haze was 420 m reach / 0.88 most, which at
    1000-1500 m left it the air's own colour, so it was invisible. It is
    now torch 900 m / 0.62 and haze 800 m / 0.72, so the silhouettes stand
    dark against the abyss.
  - **The far fire.** A soft warm billboard sits on the region's landmark
    (`Underground._far_fire`, `FAR_FIRE` 14 m, strength 1.5). It is
    additive, with no light and no shadow, and only underground. Set
    `FAR_FIRE` to 0 to drop it.

## Numbers and why

From `scratch/next_geom.gd` over seeds 2-5, sprawl and ring:

| What | Range |
|---|---|
| Next base over the gate | 47-79 m |
| Next start over this layer's start | ~60-140 m |
| Landmark distance from the spawn | 1000-1500 m |
| Landmark height | 185-300 m |

From the throwaway play-loop check (seed 2, `--underground=torch`), the
heights read:

| Point | Height |
|---|---|
| Start | 0 m |
| Gate 1 | 49 m |
| Layer 2 start | 112 m |
| Gate 2 | 155 m |
| Layer 3 start | 203 m |

The card read `FELL FROM 203 m`, with `highest: 203 m` written to the
record.

## Checks

- **Headless import:** clean.
- **Smoke:** `run_layer.tscn -- --shape=sprawl --underground=torch`
  passed 400 frames with 0 errors.
- **The throwaway play-loop driver** (`scratch/climb_up.gd`, uncommitted)
  passed 17/17 on seed 2. The record was pointed at a scratch file.
  - He was set down before each gate and walked in with the stick.
  - Each new start was over the gate and over the last start.
  - The captions read heights with no layer count.
  - In the void, the card title and facts read heights, and the record's
    `highest` matched the run's best.
  - The lift read 0.2 and then 0.4.
  - **Seed 11:** gate 1 gave 107 m at the gate and 175 m at the start.
    On gate 2 (a ring layer), the driver's set-down 3 m before the gate
    never reported grounded. That is a limit of the driver's placement,
    not the climb.
- **Rendered stills** (`scratch/far_up_shot.gd`, from the spawn's eye and
  from the gate, aimed at the landmark):
  - **Before:** the far region was lost in the murk.
  - **After:** its silhouettes read dark against the abyss from the gate.
  - **The lift at 0.6:** the haze goes warm umber-grey. It reads as
    climbing toward the light, and the stone stays readable.

## Breaks

- **No new test breaks** that I know of. The suite wasn't run (prototype).
- **`tests/test_layer_sprawl.gd`** keeps its old break from the stakes
  experiment (the void ends the run).
- **Nothing in tests calls `RunState.descend`**, so its rename breaks no
  test.

## Seams

- **"Up there" is mild.** The next region is above the gate, but 1000+ m
  off. From the spawn it sits only ~7 degrees over the eye, often behind
  this layer's own isles. The play camera's first frame looks down at the
  wanderer, so it mostly misses the region. Two ways to make it loom
  overhead, both bigger generator changes than this part's remit:
  - stack the next layer over this one (a vertical shaft, the climb's
    spine), not past the gate;
  - or bring it much nearer.
- **The far fire is often hidden.** On seed 2 the region's own nearer
  isles hide it from both the spawn and the gate. It wants a beacon per
  isle top, or a real flame (`scripts/flame.gd`) once that is cheap far
  off. At close zoom it can read as a moon disc. Judge it in play.
- **The fallback height** (seed skipped, or `next` not laid before he
  reaches the gate) is the gate's height plus the rolled rise. It's an
  estimate, close but not exact.
- **Room for later:**
  - **More than one gate per layer:** `_note_way_up` reads `plan.next`. A
    layer with several gates should hand in the region its gate leads to.
    `stage.at_exit` and `plan.exit` are still single.
  - **Shortcuts:** a run started part way up needs `RunState.banked` seeded
    with that layer's height.
- **The `layer/under-sky-pools` round** (still uncommitted when I looked)
  adds per-region worlds:
  - Its `shown_height()` subtracts `depth_below(region)`
    (`UNDER_DEPTH` 250 m a region), so the underground reads below zero.
    That composes with this branch's true `run.height`, but the two
    together mean the readout goes negative underground. Decide which
    "height" the player reads.
  - Its default underground look is haze, and the climb lift only acts on
    torch.
  - Its `detach` / re-`attach` keeps `climb_lift`, because the lift is a
    static.

## Functions touched (for the merge)

- **`scripts/roguelike/run_loop.gd`:**
  - header comment;
  - new consts `LayerSprawl`, `CLIMB_LIGHTEN`, `CLIMB_LIGHTEN_MOST`,
    `Underground`, and the var `_way_up`;
  - `after_tick` (one line, `_note_way_up(feet)` in the gate branch);
  - `layer_stood` (`run.descend()` becomes `run.ascend(_rise_through())`);
  - `_arrive` (one line, `_lighten()`);
  - `input` (the N key line);
  - new at the end: `_note_way_up`, `_rise_through`, `_lighten`,
    `_exit_tree`.
- **`scripts/roguelike/run_state.gd`:** header comment; `descend` replaced
  by `ascend(rise)`.
- **`scripts/underground/underground.gd`:**
  - the torch and haze `next_reach` / `next_most` values;
  - `set_preset` (one line, `_lift_preset()`);
  - new `climb_lift`, `set_climb_lift`, `_lift_preset`;
  - `_publish_stone` (one line);
  - `_tint_next_region` (one line, `_far_fire(mi)`);
  - new `FAR_FIRE*` consts and `_far_fire`.
- **`studies/run_layer.gd`:** one header comment word.
- **`scripts/roguelike/layer_sprawl.gd`:** not touched.
