# Summit, round 1: the run gets an end you can see (2026-10-15)

Feature `summit` of the game-feel round (items-contract.md). On by default;
`--no-summit` (or `--loot=off`) turns it off.

## What it is

- **A fixed run length**: 6 layers, `--summit-at=N`. The corner shows a quiet
  climbing mark under the hearts: a diamond a layer (climbed gilt, current
  lit and larger, a pulse on each new layer), the last a small sun
  (`summit_mark.gd`). The gate caption reads "3 of 6 · 1,180 m".
- **The sun's gate in view from the start** (`summit_crown.gd`): a warm light
  with a shaft, hung at the upper edge of the view toward the gate's
  bearing (the play camera looks steeply down, so the true sky is never in
  frame). Layer 1: a small glow; each layer it eases larger, brighter and
  lower in the view, and resolves into a temple gate (piers, lintel, steps)
  with light pouring through. One unlit shader quad, depth test off (it
  must show over the next region's rock overhead).
- **The summit layer** (the 6th region): nothing lies past it (no next
  region laid or stood: `LayerSprawl.attach_next`, `NextRegionLoader`), caption
  "THE LAST STAIR", a halo behind its real gate. It is an ordinary
  generated layer (region 6 is sky by default), not a bespoke place.
- **The win** (`run_loop.gd` `_win_begin`..`_win_step`): through the last
  gate he is held; the chord and bell ring (synthesised, 7 s,
  `Summit.chime`), the crown blooms to fill the view (2.8 s), white takes
  the screen (2.2 s), held (1.2 s), then darkens to a warm dark under the
  card: `THE SUMMIT 1,840 m`, through the sun's gate, layers, time, items
  carried, runes and sun glyphs, fastest summit (new / best), summits won.
  Space starts a new climb. Record in `user://summit_record.json`.
- **The death card** gets a line under its cause: "2 layers from the
  summit" / "one layer from the summit" / "on the last stair, short of the
  sun's gate". The items-lost line stays.

## Play

```sh
GODOT=/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
$GODOT --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --summit-at=2   # a short climb
```
N (a layer on) jumps layers; with `--summit-at=3` press N twice then walk
to the gate.

## Knobs

`--summit-at=N`; in `summit_crown.gd`: SIZE_FAR/NEAR, VIEW_FAR/NEAR (where
it hangs), BRIGHT_*, EASE; in `run_loop.gd`: WIN_BLOOM, WIN_WHITE,
WIN_HOLD, WIN_DARKEN. Words in `Summit.WORDS`.

## Hooks in shared files (all marked `# [summit]`)

`run_loop.gd` (setup, state "win", at_exit, `_to_card`, card_title /
card_facts, caption, input), `layer_sprawl.gd` `attach_next`,
`next_region_loader.gd`. Everything else is in `summit.gd`,
`summit_crown.gd`, `summit_mark.gd`.

## Proved

Smoke (`run_layer`, 900 frames, 0 errors). Driver through the real loop
with `--summit-at=2`: gate to layer 2 (final, no next region), gate to
`win`, to the win card with its facts, a death card with the near line, a
new climb from layer 1. Rendered stills of the crown at progress 0 to 1 and
the bloom.

## Rough

- The crown is a screen-anchored overlay, not a physical sky object: it
  draws over terrain at the top of the view, and the stone silhouette reads
  a little grey/flat at p=1. Needs eyes in play.
- The summit layer is not a special place (no city landing reuse); the
  halo and caption carry it. The win freezes him (no animation).
- The chime is synthesised (a placeholder, no music in the game); the
  win-card sums and the window it holds are untuned.
- Underground (regions 1-2) the crown is the only light overhead; not
  judged in a rendered underground run.
- `Summit.base_region` is set when the run loop starts; `--region=N` with a
  tiny `--summit-at` may lay a next region on the first layer.

## Existing tests it may break

None known (no tests cover run_loop's cards). Not run: the full suite.
