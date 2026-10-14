# Loading screen, round 2b: the safe parts of fast-load (2026-10-14)

> On `perf/load-safe` (from `perf/loading-screen`). For merging into
> `roguelike`; not merged. A cut of `perf/fast-load` (a94f45e4,
> loading-screen-round2.md): only what helps a player whose every run is a new
> seed, needs no helper process, and writes little to disk.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
# the base and footprints built in the game, nothing kept
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --no-fixed-cache
# the full shader sweep on macOS
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --shader-warmup
```

Measure: `Godot --windowed --path . -s res://tools/bench_loading.gd -- --no-title --shape=sprawl --seed=2 --secs=10 [--raygrid]`.
Prove the cache gives back the same art (headless, about 40 s):
`Godot --headless --path . -s res://tools/fixed_cache_check.gd` (it ends with an
engine crash message at exit, from the headless renderer being gone while
materials free; the CHECK lines are printed before it).

## Taken from a94f45e4

1. **The plant edge index** (`KitFlora.EdgeIndex`): the same distance calls on
   the nearby outline segments only; identical answers (round 2 checked 1,000,000
   points, 0 differ), about 4x faster. Whole `kit_flora.gd` taken.
2. **The plant rays' determinism** (`KitFlora.Site.looks_past`,
   `MotifIsle.looks_past_neighbours`, `_neighbour`, `SETTLE_STEPS`; set in
   `MotifSky._add_isle`): a placed isle's rays look past other motif isles, the
   Broken Viaduct and anything that moves, and wait two physics steps after the
   isle's last held shape. Not taken: the store's "stand in the old order" rule
   (without the store the one worker already builds nearest first, as before).
3. **Shader warm-up**: off on macOS, on elsewhere (`LayerLoading.warm_wanted`;
   `--shader-warmup` forces, `--no-shader-warmup` removes). Off, the pilot's
   own view is drawn 4 frames under the screen.
4. **The base isle's art and the plan's piece footprints kept on disk**, in a
   trimmed store, `scripts/roguelike/fixed_cache.gd` (see below).

Also: `studies/aqueduct_isle_base.gd` (the base's art as one build, the same
calls in the same order; the study applies its collision parts and fields
after), `KitMotif.boxes_take/boxes_all`, and `tools/bench_loading.gd` (loading
frame sums, `--raygrid`, `--change-after=`).

## Left out, and why

- The per-motif-seed isle store: every run is a new seed, so the isles it kept
  would almost never be asked for again; about 1 GB written per layer.
- `isle_forge.gd` and the helper processes: they never run in an exported
  build (they need the editor binary and a project to point at).
- `--forge-ahead`, `--forge-procs`, `--loading-hide-world`, the load-mark trace
  and per-step timings, the roost tower's bound static function (it only
  existed so the store could keep a lambda).

## Are the base and the footprints seed-independent? Yes.

- **The base** is `Isle.SEED` (11) and the constants beside it (`STAIR_SEED`,
  `CIRCLE_SEED`, `STEPS_SEED`, `pieces()`, `stumps()`): one isle, no run seed, no
  shape, no knobs. Its file is keyed by a hash of every script and data file,
  the stone look, the engine and the launch flags a build may read (all but
  `--seed=`, `--shape=` and the measuring flags, `LOOSE_FLAGS`). The same file
  was loaded by sprawl 2 and ring 1.
- **The footprints** (`KitMotif.piece_block`) are keyed by piece, seed and
  weathering; each value is the box of that piece as the kit builds it, a pure
  function of the key and the code. The seeds are constants of the motifs
  (the spine's `SPINE_SEED`+n, the ring's `note_for` 91-99). Only which keys a
  launch asks for varies: `LayerPlan.warm` draws its isles from an unseeded
  RNG, so one launch measured 12 keys, another 15 (the universe is 15). The
  saved table is the union (loaded keys kept), so it fills up over launches;
  a key not in it is measured in the game, as before. The table is saved right
  after `LayerPlan.warm`, not after the plan, so a key only the plan asks for
  is not kept.
- Check (`tools/fixed_cache_check.gd`): the base built here against the base
  loaded from the file, node by node (class, script, groups, every stored and
  script property, metas, the motif's fields, resources by content, arrays
  hashed): **0 of 117,065 lines differ**, triangles 367,911 / 367,911. The
  footprints measured fresh against the saved file: identical.

## The store, trimmed

`fixed_cache.gd`: the base art's scene file (123 MB; the meshes keep their
build arrays) and the footprints (about 1 KB text) under `user://fixed_cache`,
only the newest of each (older code's are removed when a new one is saved), so
about 123 MB on disk in all, not per layer. Only the encode/decode of what a
scene can't hold (node references, metas, groups, script state) and the
shared-material re-tagging of the old store are kept; no seed files, no
helpers, no pruning pass.
It is saved from a copy: the game builds the base as before, a duplicate is
taken (the encode reads the original, the scene is packed from the copy) and
packed and written on a worker (about 13.5 s of wall in the check, engine
work; the worker waits on the main thread's frames to read mesh arrays). The
first launch after a code change costs the duplicate (not measured alone) and
keeps the base; later launches load it in about 0.13 s against 4.0 s to build.
`--no-fixed-cache` turns it off. Headless never keeps or loads the base.
Exported builds: the key stands the executable's size and time in for the
scripts (they are compiled behind .remap files); untested.

## Plant counts (sprawl 2, grass tufts per isle, 3 runs of this branch; 2 of the base)

| Isle, in order | Base (2 runs) | This branch (3 runs) |
|---|---|---|
| stair clouds | 2031, 2201 | 2031, 2031, 2031 |
| colonnade spine | 4279, 4279 | 4279 x3 |
| sundered gorge | 8375, 8375 | 8375 x3 |
| colonnade spine | 4281, 4281 | 4281 x3 |
| stair clouds (second) | 3114, 3114 | 3114 x3 |
| bell spires | 4155 | 4155 x3 |
| sundered gorge | 8363 | 8363 x3 |
| roost | 7107 | 7107 x3 |

The fast-load note's second stair-clouds isle (2,061 tufts, instead of 3,114)
**did not happen** in these three runs: 3,114 each time, equal to the base.
Three runs are not proof (fast-load saw it in about one run in three on a
faster timeline, and its store loaded isles on workers; this branch builds as
before). The first stair clouds varied on the base (2031 / 2201) and held at
2031 here.

## Launch to playable (rendered, windowed, `bench_loading.gd`, display on)

The display was awake (powerd held "prevent sleep while display is on"). The
machine was not quite quiet: load average 1.6-2.9, another agent running
headless benchmarks in another worktree. Interleaved runs, base =
`perf/loading-screen`:

| | Base | This branch, first launch (cache empty) | This branch, cache warm |
|---|---|---|---|
| Sprawl 2 | 43.9 s, 48.4 s | 40.0 s | 34.9 s, 36.2 s |
| Ring 1 | 39.5 s, 38.9 s | 29.6 s (base art already kept by sprawl) | 29.0 s, 28.0 s |

About 8-13 s off sprawl 2 and about 10 s off ring 1 (base art 4 s, footprints
2-4 s, warm-up 4 s, edge index 1 s). Round 2's own 20 s needed the isle store.

## Proof

- Headless import clean; headless `run_layer` sprawl 2 and ring 4, 400 frames:
  no script errors. Rendered: the bench runs above (sprawl 2 and ring 1, plus
  the stills run), no script errors, no cache errors.
- Stills (`tools/bench_run_layer.gd --stills`, sprawl 2, four spots) against the
  base: same isles, ruins, bridges, growth and grass; differences are
  time-driven only (the airship's place, the wind ribbons). Looked at the gulf
  and mid views side by side; spawn and next not looked at by eye.
- Tests touching what changed (40): 33 pass, 2 pass with a known engine error,
  5 fail: `test_aqueduct_isle_look`, `test_aqueduct_isle_sky`, `test_motif_sky`,
  `test_layer_sprawl` (all known on the base) and `test_motif_families`
  (colonnade spine and broken ring "builds today's isle" hashes; **fails on the
  base too**, same four lines, so not caused here and not on the known list).
  `test_run_layer` passes. **Breaks: none found.**

## Unverified

- Exported builds and Windows: the cache key, the file paths and the
  worker save are untried there; the shader warm-up stays on there as round 1.
- The cost of the first-launch duplicate and save on frame time in the first
  seconds of play (not measured; the save runs on a worker and was not seen as a
  hitch, but no frame-time run was made of it).
- Collision of a loaded base in play: the dump compares shapes, metas and fields
  (equal), but no `--raygrid` run or walk on the loaded base was made.
- Plant counts over more than 3 runs, and ring 1's counts.
- The base's save was not run under the fast-load tool's cold/warm repeated
  changes of code; only one cold launch each.
