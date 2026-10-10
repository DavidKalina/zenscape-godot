# Sundered gorge isle: handoff (round 1)

Branch `look/motif-sundered-gorge` (from main 94a4d1c0). Not merged, not pushed.

This is one of the new hand-built sky-island motifs in the aqueduct isle's universe. It is a bit larger than the aqueduct isle: two halves of about 42 × 85 m each, with a 14–39 m gorge between them.

## Run

```sh
./run-sundered-gorge.command                    # on foot, at the gate, facing the bridge
./run-sundered-gorge.command --fly              # in the plane
./run-sundered-gorge.command --look=rosewater_dusk
godot --headless --path . --script tests/test_sundered_gorge_isle.gd
zsh tools/sundered_gorge_captures.sh DIR [view ...]   # rendered captures (--no-title)
```

It is also in the scene picker: Scenes, then Ruins, then "Sundered gorge" (`scripts/scene_catalog.gd`).

**Keys.** The keys are the aqueduct isle's: L / Shift+L for presets, B for a gust, F (pad Y) for the plane, R to reset, and F1 / F2 / Esc.

**Flags.** It keeps all of the aqueduct isle's opt-outs: `--no-flora`, `--no-life`, `--no-undergrowth`, `--no-butterflies`, `--no-fireflies`, `--no-birds`, `--no-wind-life`, `--no-tokens`, `--no-sky`, `--no-far-isles`, `--no-clusters`, `--no-pierced`, `--no-airships`, `--no-traffic`, `--no-sky-life`, `--no-motes`, `--no-sky-tokens`, `--no-lode`.

**Captures.** `--capture=`, `--at=` and `--look=x,y,z` work, and so do `--place=x,y,z[,turn]`, `--lode-at=<platform>` and `--carry`.

## What was built

### Landform

One isle torn in two along a north–south gorge, the halves drifted apart.

- **The west half (lower).** It is tilted 7° down toward the gorge (`TILT`). Everything on it is built in its tilted frame, so the gate tower visibly leans out over the lip.
- **The east half.** It is level and 1.6 m higher (`E_TOP`).
- **The gorge.** It is 13.5 m wide at the north mouth, 20 m at the bridge and 39 m at the flared south mouth.
- **The walls.** They hang sheer for about 12 m, then undercut to keels pulled in under the split.
  - The walls are faceted in 5 face rings with strata, in a lighter warm rock (`GORGE_ROCK`).
  - They carry the ruin stone shader's shelter bounce (`GORGE_SHELTER`, vertex alpha). The shaded wall reads mid-grey, not black: compare `captures/sundered-gorge/r1/bridge_south.png` with the final one.
  - The walls collide (a "Sides" trimesh on layer 1), so the plane bumps off them and the pilot can catch the lips.
- **Ledges** are cut along both walls:
  - west: L1 (−2.24 m) and L2 (−4.48 m);
  - east: a landing (−4.48 m) and a ramp up the wall.
- **Relief.**
  - The west tor (+8 m) has a long ramp.
  - The east crag (+6.5 m) has a ramp down to the gorge's lip.
  - The east half's south end slumped into two terraces, 1.6 m each, with a walked ramp down.
- **Water.** A spring pool on the west top spills over the lip as a wide curtain (6 m across) down the west wall.
- **Fragments caught in the gap:**
  - two chain fragments (the lower crossing);
  - the "crown" fragment deep under the bridge's break;
  - a spur boulder in the south mouth.

### Clustering

The isle is a dumbbell: two big halves, with fragments and floating stones in the gap.

### Ruin centrepiece: the snapped bridge

- **The arch.** A great semicircular arch (R 9.2 m, two orders) once spanned the gorge. Each half keeps its half-arch:
  - the ring, the coursed spandrel torn down ragged toward the break;
  - a corbelled abutment hanging off the wall with a broken foot;
  - the deck with parapets gone in runs and a snapped end.
- **The rope bridge.** A live rope bridge (`scripts/rope_bridge.gd` + the sim, via `Footbridge.build_mesh` / `live`, unchanged) is slung over the 9.1 m break.
  - It hangs between new stone anchors: `RuinKit.rope_anchor`, two coursed bollards and a sill. This is additive, and not in `PIECES`, so the gallery and `test_ruin_kit` counts are unchanged.
  - It sags under the pilot, bounces on footfalls and landings, sways in the wind and carries him with it. It shudders when the plane passes.
  - The walker reads its live deck through `DeckGround`, a `PilotPhysicsGround` subclass in the study using `Footbridge.deck_at`. `RopeBridge.hold` keeps him between the hand ropes.
- **The crown.** The crown's two voussoirs hang in the gap beside the rope bridge: the expert's crossing. The rest of the crown, voussoirs and a deck slab, lies on the crown fragment about 12 m below.
- **The west lip.** The gatehouse: the kit's gate arch over the road, framing the bridge from the start. Beside it stands a 9.6 m tower leaning over the lip, whose fallen south-west quarter steps up in 1.6 m jump-catches to its crown.
- **The east lip.** A roofless chapel faces the bridge, built from kit pieces: the rose gable as its west front (the door on the road), two lancet walls, broken piers where its apse fell, a chest and a fallen pier.

### The plane line

The plane dives in at the narrow north mouth, passes the curtain, goes under the lower crossing's fragments, then under the broken bridge between the snapped ends and the fallen crown, and out south past the spur.

There are 4 sky tokens on this line (`sg:gorge`), plus `sg:curtain` by the fall and `sg:keel` under the split.

## Routes (all proven headless, `tests/test_sundered_gorge_isle.gd`, 28 checks, PASS)

| Route | How |
|---|---|
| Bridge (easy) | From the start, through the gate, along the west deck, over the rope bridge and the east deck to the east top. It is walked, and run back. Zigzagging on the rope deck, the pilot is held between the ropes (strayed at most 0.23 m). |
| Crown stones (expert) | Twirled and running jumps from the west deck's end over the two hanging voussoirs to the east deck. |
| Lower loop (easy, both ways) | Down the kit's two flights cut in the west wall to L2, running jumps over the two fragments to the east landing, then up the ramp along the east wall. Done in reverse as well. Top route plus lower route make a loop. |
| Chimney (expert) | Wall kicks up the 1.1 m slot of the split pillar on the east landing, onto its inner slab and off onto the east top. |
| Gate tower | Its fallen quarter, five 1.6 m jump-catches, to the crown at 39.9 m. It is a vista over the gorge and bridge. |
| Tors | Both ramps are walked to the top, with no jump. The west tor (41.2 m, broken pier) is the isle's highest walkable top. |
| Slump | Walked down the ramp through both terraces, then back up both 1.6 m steps by jump-catches. |
| Mist stone | From L2's north end onto the floating stone by the curtain, and back. |
| Crown drop | Off the west deck's snapped end, about 12 m down onto the fallen crown. The lodestone rests there and can be picked up. Boarding the plane (F) there flies out of the gorge clear of stone. |
| Plane | A steering bot flies the gorge line north to south through all 4 tokens (misses ≤ 0.24 m) with 0 bumps. |

**Also checked:**
- all 7 on-foot tokens are taken along these routes;
- no hole in either half's ground (about 16.5k probes);
- every floating stone stands where it is drawn;
- both kit flights' treads are sound (10k probes, 72 driven approaches, none under a tread);
- the pool is wadeable;
- the static and instanced triangle budgets hold.

**Test runs.** Only the headless import check and this test were run, per the brief. The full suite and `test_ruin_kit` were not run. Nothing was added to `tests/known_failures.txt`.

## On-foot tokens (`GorgeTokens`, `studies/sundered_gorge_isle_life.gd`)

The tokens are: tower crown, crown stones, chimney (mid-slot), mist stone, fallen crown, the gap between the chain fragments, and the west tor top.

## Files

- `studies/sundered_gorge_isle.gd`: the scene. It extends `studies/aqueduct_isle.gd` and overrides only:
  - pack/start, room/art, the pilot's deck ground;
  - the rope bridge's tread and flown-by;
  - flora, sky, life, the lodestone's place and its hint.
- `studies/sundered_gorge_isle_art.gd`: the composition. This covers:
  - the halves' ground model (lips, ledge strips, tilt, tors, slump, pool);
  - the generalised island builder, sheer gorge walls and `cliff_points`;
  - the bridge, tower, chapel layout, fragments, floating stones, chimney, boulders, water, and route geometry.
- `studies/sundered_gorge_isle_flora.gd`: copies of the aqueduct isle's grass/flower and undergrowth growers, parameterised (wear callable, ray range, density). They draw through `AqFlora._draw`.
- `studies/sundered_gorge_isle_life.gd`: extends `aqueduct_isle_life.gd`. It has its own undergrowth, perch groups (`GorgeBirds`), tokens (`GorgeTokens`), leaf anchors and meadow.
- `studies/sundered_gorge_isle_sky.gd`: extends `aqueduct_isle_sky.gd` and only swaps the plane tokens.
- `scripts/ruin_kit.gd`: added `rope_anchor` and `ANCHOR_POST` (additive).
- Other new files:
  - `run-sundered-gorge.command`;
  - `tools/sundered_gorge_captures.sh`;
  - `tests/test_sundered_gorge_isle.gd`;
  - a scene catalog entry.
- `studies/aqueduct_isle*.gd` are untouched.

## Perf

The capture timings below are from this Mac (Retina window, vsync off, frame time from the `--capture` run).

**Static and instanced triangles:**
- About 196k static triangles. The aqueduct isle is about 304k.
- Instanced plants: about 0.86M grass and flowers (8.3k tufts at `TUFTS` 3.0), plus undergrowth. At most about 1.09M, against the test's 1.3M budget.

**On foot:**

| | Frame time | Draw calls | Primitives |
|---|---|---|---|
| On-foot views | 16.7 ms | 230–260 | 0.64–0.69M |

**Wide views over the whole isle with the sky:**

| | Frame time | Draw calls | Primitives |
|---|---|---|---|
| Wide views | 24–45 ms | 640–850 | 1.1–1.7M |

The aqueduct isle's sky round reported 25 ms and 344 draw calls from its hill. Here the draw calls are higher because of the larger land:
- the plant tiles (16 m multimesh tiles over about 2× the land);
- the undergrowth;
- the 18 kit and bridge pieces.

**Build.** About 5.8 s headless from launch to walking. Flora takes about 0.5 s and life about 0.55 s.

## What's weak

- **The curtain reads as an opaque white sheet** close up (`fall.png`, `lower_crossing.png`), even at strength 0.62. It is the waterfall shader at a 3 m half width, which wasn't tuned for one this wide. Two narrower curtains side by side, or the forest isles' veil settings, might read more like water.
- **Tall terrain cliffs read as flat cards** from afar: the west tor's faces and the slump edges. Adding more broken rows down a cliff made the triangulation bridge from the top onto lower rows (a real hole at the lip), so it was reverted to the aqueduct isle's single row. The fix is a cliff mesh of its own, not heightfield rows (extraction candidate below).
- **The west tor's ramp is a long straight wedge.** It reads built more than natural.
- **The south lawns are large and plain.** The west's south lawn and the east's middle are deliberate run space, but they are bare apart from grass, paths and a few boulders.
- **Ruin stone reads near black against the sky** in backlit views (`bridge_south.png`). This is the house eroded basalt under morning light, shared with the aqueduct isle.
- **The sky tokens show as dark discs** at some angles. This is the shared glyph look; their rendered look was not checked further.
- **The rope bridge's footfall bounce is approximated.** The study derives footfalls from pace, because the character study doesn't expose the body's footfall events. Weight, landings, wind and the plane's shudder are the real sim. In headless tests the sim doesn't step (no process frames), so the deck is static there.
- **The crown fragment is a drop-only dead end.** You leave by boarding the plane (F) or pressing R. A floating-voussoir chain back up to a ledge would close it.
- **Not checked rendered:** butterflies, fireflies, the birds (the perch groups are found, but the flocks were not checked by eye), night presets, and other looks than Alpine morning.
- **The chapel's gable buttress climb** (kit hulls, set-offs at 1.6 / 3.2 / 4.8 m) should work as on the aqueduct isle, but it is not driven in the test.
- **Draw calls in wide views (640–850)** are the cost to watch on min spec.

## What to extract into a shared "kit isle" builder

1. **The island builder.** `Gorge.island` + `_sides` + `_subdivide` take any ground callable, outline, base, depth and keel pull, plus per-rim-point "sheer" walls with shelter bounce and side collision. The aqueduct isle's `island` is the special case.
2. **Cliff points for any ground.** This is `Gorge.cliff_points(ground_fn, box, rng)`. Better still, give tall cliffs their own faceted cliff mesh.
3. **Ground look.** `ground_tone` with a crag shade parameter and a wear callable (paths plus water).
4. **Flora and undergrowth growers** that take a wear callable, a ray range and a density: `studies/sundered_gorge_isle_flora.gd`. These are near-verbatim copies of the aqueduct isle's.
5. **Life hooks.** The perch group finder should take a spots dictionary (`GorgeBirds.gorge_groups` is a copy with only the spots changed). Tokens should take a spots list. Life should take the undergrowth grower, leaf anchors and chaff meadow as parameters. Today these are subclass overrides of whole `setup` functions, because the base scripts call their own consts and static functions directly.
6. **The study.** The aqueduct study's isle-specific bits are `Art.TOP` / `Art.HILL` in `_build_light` and `board`, `Art.platform` in `_build_lode`, the lodestone hint text, and the `Life` / `IsleSky` consts. All of these could be virtual hooks, so a motif scene is "extends kit isle + an art script".
7. **The rope-bridge walker.** `DeckGround` (live deck in `height_from`, hand ropes in `slide`) plus the tread and flown-by calls belong in `pilot_physics_ground.gd` or the character study, for any physics-ground scene with rope bridges.
8. **Floating stones.** The "floating stones on clean walk boxes" and "clean boxes in a tilted frame" helpers.

## Captures

`captures/sundered-gorge/` (git-ignored). The best ones:

- `lower_crossing.png`: the cliff stairs, pool and curtain, gorge, broken bridge, tower, chapel and tor in one view.
- `southwest.png`: the establishing view of the whole dumbbell. The tilt reads here.
- `bridge_south.png`: up the gorge at the snapped half-arches, rope bridge, crown stones and fallen crown.
- `gorge_north.png`: the plane's entry.
- `onfoot_start.png`: the gate framing the bridge from the start.
- `onfoot_bridge.png`, `fall.png`, `establishing.png`, `west_from_chapel.png`.

`r1/` holds the first pass, with black shaded walls, a 4° tilt and low tors. `r2/` and `r3/` hold the intermediate passes.
