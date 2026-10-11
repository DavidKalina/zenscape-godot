# Colonnade spine: handoff (round 1)

Branch `look/motif-colonnade-spine` (from main 94a4d1c0). Not merged, not pushed.

One of the new hand-built sky-island motifs in the aqueduct isle's style. This one is long and narrow: a knife-edge ridge floating in the sky. A processional colonnade runs up its crest in terraces to a temple gate on the high head. Its tail curls away east in fragments that step down, tied by stepping stones and two live rope bridges.

## Run

```sh
./run-colonnade-spine.command                  # on foot, at the way's low end, looking west up the colonnade
./run-colonnade-spine.command --fly            # in the plane
./run-colonnade-spine.command --look=rosewater_dusk
godot --headless --path . --script tests/test_colonnade_spine_isle.gd
zsh tools/colonnade_spine_captures.sh OUTDIR [flags]    # the 8 look views
```

It is also in the scene picker (Ruins, "Colonnade spine").

The keys and flags are the aqueduct isle's:
- **Keys.** R start, L / Shift+L look presets, B gust, F (pad Y) plane.
- **Flags.** `--no-flora`, `--no-life` (and each part's), `--no-sky` (and each part's), `--no-lode`, `--fly`, `--capture`, `--at`, `--look`, `--place`.

## Files

| File | What |
|---|---|
| `studies/colonnade_spine_isle.gd` | The scene. It extends `studies/aqueduct_isle.gd` (unchanged) and overrides only what is isle-specific: no station, its start, the art, the lodestone's rest, the life and sky subclasses, and rope-bridge walking. |
| `studies/colonnade_spine_isle_art.gd` | Everything built: the landform, its island builder, the colonnade, step walls, temple, slabs, fragments, stones, anchors and the plane's token lines. |
| `studies/colonnade_spine_isle_life.gd` | Extends the aqueduct life. Its own perch groups, chaff meadows, leaf anchors and on-foot tokens. |
| `studies/colonnade_spine_isle_sky.gd` | Extends the aqueduct sky. Only the tokens change (`Spine.plane_tokens()`). |
| `scripts/ruin_kit.gd` | **Additive only.** New `bridge_anchor(seed, weathered, width)`: a stone sill and two capped posts where a rope bridge comes to ground. It is not in `PIECES`, so the gallery and `test_ruin_kit` are unchanged. |
| `tests/test_colonnade_spine_isle.gd` | Headless route test. |
| `run-colonnade-spine.command`, `scripts/scene_catalog.gd` entry, `tools/colonnade_spine_captures.sh` | Launcher, picker entry, capture script. |

## Composition

The axis runs along x, from the head (west, x ≈ 14) to the tail (east, x ≈ 147). It bows about 4.5 m north. The isle shares the aqueduct isle's sky, its rim near y 30.

**The ridge (`ground`, `profile`).**
- **Crest.** It is levelled in terraces, each a kit flight (2.24 m) over the next: the podium (+17.9), the plaza (+13.4), L2 (+11.2), L1 (+9.0), the saddle, and L0 (+6.7, the start). Each step is a coursed retaining wall with the stair up its middle: the grand stair onto the podium, and kit flights at x 70 and 90.
- **Flanks.** They fall about 56° (1.5 m a metre) in faceted rock, to a rim 5 m under TOP. Under that, the sides taper to a keel along the axis, deeper under the head.
- **Saddle (x 104–116).** The crest narrows to a 1.5 m knife-edge. A cleft cuts through the ridge at x 110. A lintel has fallen across it (a balance beam), and two drums are wedged on its floor. The floor opens north onto the shelf.
- **North shelf.** It is cut along the north flank and climbs from the tail (+1) to the plaza (+13.4), the easy way up.
- **South bench.** It runs along the south flank's east half (+3 to +1).
- **Rock shelves (overhangs).** They jut from the flanks: three up the south flank from the bench's west end to L1 (each a jump-catch), the pulpit off the podium's south side, and the balcony under the north shelf.

**Colonnade (`colonnade`).**
- **Rows.** Two rows of the kit's clustered piers stand ±3.4 m off the axis, on 12 lines about 6 m apart, across four terraces. The piers are 3.4 m to the abacus.
- **Lintels.** They run along each row (top 4.0 m over the terrace), walked as balance beams on clean hulls.
- **Portals.** Three pointed portal arches span the way at the stair heads. They spring at 3.4 m, their crowns about 8.7 m up and 6.2 m clear. The middle one has lost its crown stones, and the low one one.
- **Cross lintels.** Two tie the rows, at x 77 and 123.5.
- **Ruin.** Hand-placed, nothing random in the layout:
  - piers snapped to stubs;
  - lintels fallen into the way, cracked in two;
  - one pier toppled across the way in drums, its capital rolled off;
  - a drum and a stub beside the row at x 126.5 and 100.1, as ways up.

**The temple gate (`temple`).**
- **Gate.** The kit's rose gable faces east down the way on the podium.
- **Around it.** A stair turret stands either side. The cella's lancet walls stand behind (the south pair fallen to one), with floor slabs. The altar (the carved chest) is on the prow beyond.
- **Approach.** You walk through the gable's door.
- **From the plane.** The rose window (3.96 m with its spokes gone) is meant as a thread, but it is not proven.

**The tail (`FRAGMENTS`, `platforms`, `bridge_ends`).**
- **Fragments.** Five, curling south and back west, each smaller and lower: radius 4.4 down to 2.3 m, top +0.8 down to −2.4.
- **Links between them:**
  - stepping stones (Art's floating stones, set through its `platforms`);
  - rope bridge 1, frag 2 to frag 3 (about 10 m);
  - rope bridge 2, frag 5 back up to the south bench (about 14 m), so the tail is a loop.
- **Anchors.** Every bridge end stands on a `bridge_anchor`.
- **Lodestone.** It rests on frag 5, at the end of the curl.

## Routes (all proven headless, `tests/test_colonnade_spine_isle.gd`: PASS, 27 checks)

**Easy (no jump):**
- **The way.** From the start, walk the length of the crest:
  1. L0's colonnade;
  2. the cleft's lintel beam;
  3. the knife-edge;
  4. round the toppled pier;
  5. the three stairs;
  6. through the gate's door;
  7. to the altar.
- **The north shelf.** From the tail's ridge, walk up to the head's plaza. It joins the way at both ends and at the cleft, so the two make loops.

**Jumps and catches:**
- **The cleft.** Hop down onto the first wedged drum, over to the second, then a catch up onto the east lip.
- **South slabs.** From the bench, up three jutting shelves to the crest.
- **The tail.** Off the ridge's tip, over the stones and fragments, walk both rope bridges, and back up to the bench.
- **Vistas.** Drop from the podium onto the pulpit, and from the shelf onto the balcony.

**Lintels (the expert line):**
- Up the drum and the stub onto L0's south row, along it, over the cross lintel, and along the north row to the portal (a loop up high).
- From L2's edge, a catch onto L1's north lintels, then along them.
- Off the podium, down onto the plaza's north row, then along it to the portal.

So each terrace's lintels can be reached from the terrace above. The test also checks:
- 6 on-foot tokens: 5 are taken on the routes above. `cross_high` is placed, not driven.
- 4 songbird flocks perched on the colonnade.
- Every plane token stands in open air.
- No hole in the ridge's flats (8.6k probes).
- Every stepping stone stands where it is drawn.

**Not proven:**
- The plane slalom flown end to end (no flight bot here).
- The turret climb.
- Twirled jumps over the fallen-lintel gaps (about 4.6 m, within the twirl's 5.4).
- Wall kicks between piers.

## The plane's line (`plane_tokens`)

- **`cs:slalom`.** From the gate east down the colonnade:
  1. out under the north row's lintels between two piers;
  2. back in through the plaza's portal;
  3. out through the south row;
  4. through the broken portal;
  5. over the cleft;
  6. through L0's portal;
  7. under the cross lintel.
- **`cs:tail`.** Off the tail's tip and down the curl: over the first stones, under rope bridge 1, between frags 3 and 4, under rope bridge 2.

Straight legs between the slalom tokens clip piers. That is intended: the line curves at a 14 m/s cruise.

## On-foot tokens

| Token | Where | Move |
|---|---|---|
| `cross_low` | L0's cross lintel | Up onto the lintels and across the rows |
| `cross_high` | L2's cross lintel | A catch from the plaza's edge |
| `cleft` | Over the wedged drums | Hop the drums |
| `south_3` | On the top shelf | Up the south shelves |
| `pulpit` | On the pulpit | Drop off the podium |
| `bridge` | Over rope bridge 1 | Cross it |

## Rope bridges on foot

The character study's motor walks physics colliders, and a live bridge has none. `BridgeGround` (in the scene) extends `scripts/pilot_physics_ground.gd`:
- **Deck height.** Over a deck, the ground is the planks' top as the sim has them (`RopeBridge._on_deck`).
- **Hand ropes.** The step is held between the hand ropes (`RopeBridge.hold`).
- **Each tick.** The deck takes the pilot's weight and landings (`RopeBridge.tread`), and carries him with its sway.
- **Not wired.** Footfall bounces.

## Perf

Measured on this Mac, rendered at 1440×900, `--capture`. Other agents were running Godot in parallel, so the frame times are noisy.

- **Static triangles.** About 303k: ridge, colonnade, temple, lands. The budget is 900k.
- **Instanced grass.** 261k triangles in 94 multimeshes (2,751 tufts and 158 flowers). That is about a third of the aqueduct isle's, because the steep flanks grow none.
- **Draw calls.** 300–640 in most views with the sky. About 1,080 in the wide view along the isle from the head, which sees every far isle. Without the sky it is about 400.
- **Primitives.** 0.76–1.26M.
- **Frame time.** 16.7–30 ms (vsync off).
- **Collision.** The ridge's trimesh, plus 9.3k rock prisms under its steep faces, in bodies of 2,000. One body with all of them fails in Jolt: the compound runs out of sub-shape ids.
- **Build (headless).** The ridge about 0.6 s, everything else about 2.4 s, life about 1 s. Walking about 8 s from launch, against the aqueduct isle's about 4.5 s.

## Captures

These are in `captures/colonnade-spine/` (git-ignored). Use `best-*.png` for the final pass. `r1` is the first landform (a box, then gentler flanks), `r2` the first full pass, `r3` the flanks forced to rock.

- **`best-along-from-head.png`.** The strongest: along the crest from behind the head, the colonnade receding east past the portals.
- **`best-establishing.png`.** South-east, high: the whole ridge and the tail's curl.
- **`best-tail-curl.png`.** The fragments, stones and both bridges.
- **`best-head.png`.** Portal, grand stair and the rose-gable gate.
- **`best-onfoot-start.png`.** The start: the way, the fallen lintel, the drum and the stub.

## Weak / open

- **It still reads as a long block from the side.** The flanks are an even 56° wall the whole length, and the outline is nearly parallel-sided. It is a "hull", not quite an arete. Ways to fix it:
  - more taper in plan, with the head broader and the middle pinched;
  - buttress ribs and gullies down the flanks;
  - a higher, more peaked head;
  - a deeper notch at the saddle.
- **Terrace steps show as vertical seams down the flanks** under each retaining wall. The flank's lerp hides them past 3 m, but they read in the side views.
- **The flank rock is the palette's pale beige**, as on the aqueduct isle's crags. The far isles are darker. The two don't clash, but the ridge reads warmer than its neighbours.
- **Gothic piers carrying flat lintels** is a mix. The kit has no classical column. It reads fine from afar but is odd up close.
- **The lintels butt into the portal arches' springers** (drawn overlap). Lintel runs end at portals, so the high line is per terrace.
- **The walker camera clips into lintels** under the colonnade (`7-onfoot-plaza`). The study camera's ball cast pulls in hard.
- **The turrets and the rose window are unproven** as routes.
- **The cleft is shallow** (floor 2.4 m under the crest) so that it opens onto the shelf. The drum hop is easy.
- **The slabs' keels are drawn only.** Their sides collide as a convex hull 2.2 m deep, so the pilot can't be inside one, but the lower keel is not solid.
- **The plane slalom is laid but not flown.** It was not checked rendered, nor were the night and other presets.

## Extract into a shared "kit isle" builder

These are written here or copied in, because the aqueduct isle's versions are tied to its own layout:

1. **The profiled island builder.** `spine_island` and `_sides` take a height field, crease lines, a cell size, steep-face prisms (split into bodies), sides tapering to a keel line, and colours from `Art.ground_tone`. This should replace `Art.island`'s hill-specific branch: give it `(outline, height callable, creases, keel callable)`.
2. **Profile helpers.** An axis with a bow and (x, d) frames (`zc`, `at`, `frame`). Also `profile`'s crest / flank / shelf model (`shelf_out`).
3. **Paths and platforms as data, not statics.** `Art.path_wear` and `Art.platforms` read static vars. This isle swaps them in (`use_paths`, `use_platforms`) and restores them on exit. Flora, undergrowth, life and `floating_stones` should take them as arguments.
4. **The perch finder.** `SpineBirds.perches_from` is the second half of the birds' `find_groups`, generalized over a spots dictionary.
5. **The isle scene base.** The plane, look rig, lodestone and life/sky hookup in `aqueduct_isle.gd`, minus the station. This scene works by overriding `_load_pack`, `_build_room`, `_build_lode`, `_add_sky` and `_add_life`, which could become the base's contract. The tokens should be data.
6. **`BridgeGround`.** Rope bridges walked by the physics-ground motor. Move it to `scripts/` beside `pilot_physics_ground.gd`.
7. **Land solids.** Slabs and fragments get a convex prism under their tops (`LAND_SOLID`). `Art.island` should do this for any small isle.

## Checks run

- **Import check.** Clean.
- **`tests/test_colonnade_spine_isle.gd`.** PASS.
- **Not run.** The full suite and `test_ruin_kit` (the kit change is one new function, not in `PIECES`). Nothing was added to `tests/known_failures.txt`.
