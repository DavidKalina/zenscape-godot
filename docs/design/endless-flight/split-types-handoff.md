# Split mountains: kinds and carved walls (handoff)

Each split mountain is now one of four kinds, with its own numbers rolled from the seed and its square. The walls are carved: they wander, step in level strata, and stand out in buttresses and back in alcoves. The see-through ghost the user saw on the walls is fixed (below). This is a prototype round: smoke checks, throwaway drivers and stills. No tests were committed.

## Play each kind

```
./run-endless-flight.command --split-near-start --split-kind=slot
./run-endless-flight.command --split-near-start --split-kind=winding
./run-endless-flight.command --split-near-start --split-kind=gorge
./run-endless-flight.command --split-near-start --split-kind=grand
python3 tools/play.py -- --split-near-start --split-kind=winding     # any OS
```

Without `--split-kind` the land picks the kind. Add `--seed=N` for other land. The console prints the kind, its length and its floor's width. Seeds 12 and 14 have no grand canyon within the five rings of squares round the start, so `--split-kind=grand` warns there. Use another seed.

## The kinds

The floor's narrowest width is `WorldScale.opening(toy)`; the table gives it at the default knobs. Every number in the table is in `TYPES` at the top of `scripts/endless/split_sites.gd`.

| | slot | winding | gorge | grand |
|---|---|---|---|---|
| toy width (`TOY_*`), floor at its narrowest | 6: 12 m | 9: 18 m | 18: 36 m | 38: 76 m |
| floor rolled to | ×1–1.1 | ×1–1.15 | ×1–1.2 | ×1–1.3 |
| crossing it takes, foot to foot | 160–400 m | 240–700 m | 180–640 m | 400–860 m |
| crest over the floor, at least | 70 m | 70 m | 95 m | 85 m |
| leans to the land | sharp crest | sharp | broad | broad (tableland) |
| bends (half waves, swing, tightest turn) | 1–2, ≤9 m, 240 m | 2–5, ≤30 m, 120 m | 1–2, ≤28 m, 300 m | 2–3, ≤40 m, 320 m |
| tiers, each tier's rise | 2–3, 22–38 m | 2–3, 18–32 m | 3–4, 18–32 m | 3–5, 14–26 m |
| bench between tiers | 0–2.5 m | 0.5–5 m | 3–12 m | 6–22 m |
| riser across (sheerness) | 2.2 m | 3 m | 4.5 m | 5.5 m |
| lean over the top tier | 0.07–0.11 | 0.14–0.22 | 0.28–0.42 | 0.45–0.7 |
| talus at the foot (rise, across) | none | 2, 3 m | 4, 7 m | 6, 12 m |
| buttresses/alcoves (depth, spacing) | 3.5–6 m, 12–18 m | 4–7 m, 20–30 m | 10–16 m, 36–55 m | 16–26 m, 50–80 m |
| mouth flare (length, floor widening) | 80–100 m, ×3.2–3.8 | 70–90 m, ×2.3–2.7 | 90–110 m, ×1.8–2.1 | 100–130 m, ×1.5–1.8 |

Some kinds read differently up close:
- The slot's mouth flares to about 40 m, so it reads as a way in on approach even though the inside is 12 m.
- Winding has 3 to 4 bends on most crossings. Neither end is visible from the other.
- The grand floor is 78 to 98 m of meadow, wide enough to roam and land on.

**How the kind is picked.** Each square draws an order of kinds from the world's mix. Each kind is tried at every crest spot in the square whose crossing fits it (its length and depth):
- First pass: only where the land takes the kind. Each kind has a land lean, and the chance follows `_fill`: the mean land height across the crossing as a share of the crest. Below about 0.44 a crest reads sharp; above about 0.62 it reads broad, like a tableland.
- Second pass: anywhere the kind fits.

On seeds 1 to 8 (144 km² each) this gives 67 slots, 60 winding, 53 gorges and 17 grand canyons, out of 197 splits. Grand canyons are rare because few crossings are 400 m or longer.

## Knobs and flags

| Knob / flag | What it does |
|---|---|
| world layer `split_kinds` (wilderness `{"slot":0.7,"winding":1.0,"gorge":1.8,"grand":2.5}`) | The mix of kinds. The weights lean toward gorge and grand because they fit fewer crossings. Without the layer the script's `MIX` (all 1) is used. |
| `--split-kind=K` | Every split is kind K, where it fits. |
| `--split-slot=X` | The slot kind's toy width (6, giving 12 m). |
| `TYPES`, `FILL_SHARP`, `FILL_BROAD`, `LAND_KEEP` | Per-kind ranges, and how much the land matters. |
| `DEEP_SHADE`, `FLUTE`, `BENCH_SCALE`, `RIB_EDGE`, `BLOCK_EDGE` | The walls' finish. |

The flags from the last round still hold: `--split-near-start`, `--splits=X`, `--no-splits`. The handle names `<world>/split/<cx>_<cz>` are unchanged.

## The carved walls

What the cut does now (`_back`, `_blocks`, `_bench`, `_rise`, `_strata` in `split_sites.gd`):
- **Walls that aren't parallel.** Each wall's setback wanders on its own noise, so the floor widens and pinches.
- **Buttresses and alcoves.** A stepped noise along the canyon makes square-ish ribs stand out and bays set in, the full height of the wall. The alcoves write the carve's groove mark and the ribs its crest mark, so the rock shader shades them.
- **Joints.** Each tier's line steps in blocks (4 to 14 m long, up to 1.6 to 3.5 m deep), so the tiers' edges aren't smooth curves.
- **Strata.**
  - Each tier stands to a level, the same world height along the canyon and on both walls. A tier simply ends where the floor climbs past its level.
  - The benches between tiers pinch to nothing in places and widen to ledges in others.
  - Above the top tier, the lean rises in level steps (`strata`, 6 to 12 m a step).
- **Risers rounded at foot and lip** (smoothstep, wider edges). The last round's sharp 2.5 m risers aliased on the 1 to 2 m mesh into dark sawtooth teeth along every tier lip. Those are gone.
- **Path.** It swings as a cosine through the kind's half waves, so it runs straight along the way at both mouths. The tightest turn is a per-kind limit.

## The ghost on the walls (must-fix)

**What it was.** The forest floor is a see-through sheet (`endless_forest_floor.gdshader`, `blend_mix`) draped over the land under the woods and pulled toward the eye. With the native kernels (the default), `land_trees.gd` builds each block's and far cell's floor natively, over the native land field. That field knows nothing of the splits, which are a GDScript layer `LandField` cuts in afterwards. So over every canyon the sheet hung at the old ground's height, inside the canyon's air, where the woods had been on the uncut slope. Over the seed-1 gorge there were 1903 floor triangles on the cut, 1861 of them weighted. The dark streak across the sky between the rims in this round's early gorge stills was the same sheet seen edge-on.

**The fix** (`land_trees.gd` `_floor_off_cuts`, GDScript, nothing native changed):
- Every floor triangle with a corner on a split's cut is dropped after each build, native or GDScript.
- Off the cut the two fields' heights are the same, so what's kept lies on the land.
- Over the seed 1 to 3 gorges, 0 floor triangles are now on a cut.

**Before and after, the same views:** `captures/split_types/ghost_gorge_before_after.png`. The left column is the forest floor's draping as before (the filter switched off), the right is the fix. It shows the mouth, inside, and a mid-canyon still.

**How I got there.** These were ruled out, each by an A/B of the same flight:
- valley fog;
- clouds;
- grass;
- glow and the environment's fog;
- tree shadows;
- temporal effects (a static SubViewport still shows the same thing);
- the stair-stepped normals.

The A/B with no forest floor in the slot view showed nothing because that crest wasn't wooded. Counting the floor's triangles on the cut found it.

**Two more changes, which read as solid shaded rock deep in a canyon:**
- **Deep shade (split code).** The cut writes how deep each wall point lies under the old ground, over the canyon's width (`DEEP_SHADE`), into the carve's groove mark. The shader already darkens and cools grooves and dims their bounce light. Before this, the deep walls were painted as open sunlit faces, though a CPU march toward the sun showed the whole slot is in shadow.
- **One line in `shaders/endless_rock.gdshaderinc` (all rock).** Where the groove mark is over 0.6, the rock's painted light leans to its shade tone. This only touches the deepest grooves. The land cliffs and open slopes on the approach stills look the same before and after (`captures/split_types/ab_cliffs.png`, top two rows).
- **The joints (also all rock, from the first commit).** `er_rock` now takes the joints' direction along the face snapped to one of 16 headings. The coordinate is world-sized, so before a hair's turn of the interpolated normal slid the joints metres and combed them into fine vertical hatching down long triangles (`captures/split_types/ab_joints_crop.png`).

## Cost

- **Field sample over a cut** (`scratch/split/bench.gd`, 5 seeds, 2 m grid over each cut): 4.06 µs a point before, 4.21 after.
- **The cut alone:** 3.65 µs before, 3.71 after.
- **A 64×64 chunk over a cut:** 20.1 ms before, 18.7 after.
- So no change beyond noise. The sites differ now, so the per-seed numbers aren't like for like.
- **Finding sites:** 2.4 s for 8 seeds × 81 squares, about 3.7 ms a square native. That is up from 2.2 to 3.4 ms, because a square tries more spots before it falls back.
- **The forest floor filter** runs on the tree workers, only for blocks that meet a cut.

## Proof

**Smoke** (`tools/smoke.py`, headless), 0 errors in each:
- endless flight with no flags;
- `--split-near-start`;
- `--gdscript-kernels`;
- `--gdscript-kernels --split-near-start`;
- `--world=regions`;
- `--world=regions --split-near-start`;
- `--world=overgrown`;
- `--split-near-start --split-kind=grand --gdscript-kernels`;
- `studies/flight_study.tscn`.

**Fly-through on the stick** (`scratch/split/fly.gd`, uncommitted): `python3 tools/sweep.py scratch/split/fly.gd --seed 1..14 --set split-kind=slot,winding,gorge,grand -j 6 -- --scene-args --split-near-start`. The default weight and brisk pace, 9 m over the floor, steering on the `move_*` actions.

| kind | runs | length | floor | half waves | least wingtip clearance (median) | in the canyon | contact |
|---|---|---|---|---|---|---|---|
| slot | 14 | 176–388 m | 12–13 m | 1 | 6.1 m (6.6) | 5–11 s | none |
| winding | 14 | 272–644 m | 18–20.5 m | 2–4 | 9.6 m (11.3) | 8–19 s | none |
| gorge | 14 | 192–592 m | 36–42.5 m | 1–2 | 26.4 m (29.4) | 6–17 s | none |
| grand | 12 | 412–648 m | 78–98 m | 2 | 52.9 m (61.4) | 12–19 s | none |

54 of 56 runs fly end to end. The two misses are seeds 12 and 14, which have no grand canyon in reach.

Two crashes earlier in the round were at the approach, not in a canyon. Both are fixed:
- the start 520 m out was under a rise beyond the 400 m open-way check;
- a mouth high on the flank stood over a drop.

`--split-near-start` now starts high enough to clear the land on the way in and the mouth's floor.

**Same land with and without the native kernels** (`tools/land_hash.py`, macOS arm64):

| land | native = GDScript `exact` |
|---|---|
| wilderness seed 1 | `74f3321f…` |
| wilderness seed 7 | `a5b8e0f3…` |
| regions seed 1 | `db1d32ea…` |
| wilderness seed 1, `--no-splits` | `c515311f…`, the hash from before splits |
| overgrown seed 1 | `9385c033…`, the same on this round's base commit `f5a12a33` |

The last handoff gave overgrown as `28f79dfa…`; that came from an older base.

**Stills** (`captures/split_types/`, git-ignored; chase camera, rendered, `--no-title`). Each contact sheet shows the approach, the mouth, inside twice, the look back at the exit, and an aerial:
- `final_slot_s1/sheet.png`
- `final_winding_s1/sheet.png`
- `final_gorge_s1/sheet.png`
- `final_grand_s1/sheet.png`

## Tests

These were run headless: `test_world_scale_guard`, `test_native_*`, `test_threaded_*`, `test_inland_recipe`, `test_forest_hold`, `test_landform_*`, `test_landscape` and `test_tree_degrowth`.
- 22 pass and 1 GPU test is skipped.
- `test_landform_forest` fails with "trees draw at most 1200000 triangles near (7773402)". It is the same count the last round saw failing on an untouched base, so this round did not cause it.
- No test breaks. The full suite was not run.

## Not verified

- How each kind feels by hand, especially the slot's 12 m at boost and winding's bends in the heavy weight.
- Landing on the floors.
- Windows, or another machine's hashes.
- **Engine errors under load.** Twice in about 108 runs of the fly driver, at 6 in parallel on a loaded machine, a run hit an engine-side error: "caller thread can't call propagate_notification() on /root" once, and "Attempting to initialize the wrong RID" once. Neither had a GDScript backtrace or reproduced alone. The base commit gave none in 48 runs of the last round's driver. Unexplained; watch for it.
- **The halls' and tunnels' cuts** are GDScript layers too. Their forest floor likely hangs over them the same way. `_floor_off_cuts` only reads the splits for now.

## Next

- **Overhanging gorge lips** (mesh pieces along the rims). The rim line at any `u` is the cut's top: `_edge(s, u, s[11])`. The tier levels are in the site (`K_LEVEL..`), so a lip can sit on a bench at a stratum's height. The flight would need the lips as solids, the way the arches answer `ground` / `inside`. The forest floor and grass already keep off the cut.
- **A rival race through the canyons.**
  - `Splits.point(s, u)` gives the centre line, floor height included.
  - `kind_name(s)` gives the kind.
  - Winding is the natural race course: 3 to 4 bends, no line of sight end to end.
  - The grand floor holds two planes side by side.
- **Smaller additions:**
  - the same forest floor guard for the halls and tunnels;
  - per-kind colour (a cooler slot, a warmer grand);
  - perched birds on the grand benches;
  - letting `--split-near-start` take the nearest of a kind rather than forcing every square.
