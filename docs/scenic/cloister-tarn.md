# Cloister tarn: handoff (round 1)

Branch `look/motif-cloister-tarn` (from main 94a4d1c0). Not merged, not pushed.

This is one of the new hand-built sky-island motifs in the aqueduct isle's style. It has about the aqueduct isle's footprint: the mother isle is about 60 m across, and with its satellites the whole is about 100 m.

## Run

```sh
./run-cloister-tarn.command                     # on foot, Alpine morning
./run-cloister-tarn.command --look=rosewater_dusk
./run-cloister-tarn.command --fly               # start in the plane
godot --headless --path . --script tests/test_cloister_tarn_isle.gd
zsh tools/cloister_tarn_captures.sh DIR [view ...] [-- scene args]
```

It is also on the title's scene picker under **Ruins → Cloister tarn**.

Keys and flags are the aqueduct isle's:

- **Keys.** R (start), L and Shift+L (look presets), B (gust), F or pad Y (plane), F1, F2, Esc.
- **Look and capture.** `--look=<id>`, `--capture= --at= --look=x,y,z`, `--place=`.
- **Flora and life.** `--no-flora`, plus `--no-life` and its parts: `--no-undergrowth`, `--no-butterflies`, `--no-fireflies`, `--no-birds`, `--no-wind-life`, `--no-tokens`.
- **Sky.** `--no-sky` and its parts: `--no-far-isles`, `--no-airships`, `--no-traffic`, `--no-sky-life`, `--no-motes`, `--no-sky-tokens`.
- **Plane and lodestone.** `--fly`, `--drift=`, `--no-lode`, `--carry`, `--stone-plane`.

The start is the cloister's south-east corner, looking west along the south alley.

## What it is

### Landform

The mother isle is a crater bowl that rings a still tarn. Everything is one heightfield (`ground` in `studies/cloister_tarn_isle_art.gd`), with:

- **The tarn.** A round bowl (radius about 10.6 m, wandering), its water at y 30. It has a shelf, then drops about 2.6 m deep.
- **The garth.** A grass bank between the tarn and the cloister.
- **The alley.** The cloister walk: a level square ring at y 30.5.
- **The rim.** A rounded-square crest whose height wanders round it:
  - **North-west crag.** The crest's top, 10 m over the walk (y 40.5), with a summit plateau. Its last rise is a kit stair flight.
  - **North face.** Rock in six tiers, each 1.4 m high (a jump-catch), rising behind the alley.
  - **South terrace.** Level with the cloister's wall-walk.
  - **West saddle.** Low, 3 m over the walk.
  - **East notch.** The tarn spills through here. A channel runs from the tarn under the cloister's water gate, through the notch, and off the edge as a **4 m-wide curtain fall**. The fall uses the islets' fall strand and droplets and a thread on down to the cloud sea.
- **The outer flank.** It falls to the island's edge, under which hangs the usual rock keel.

### Centrepiece

The centrepiece is a ruined cloister. It is a new, additive kit family, `scripts/ruin_kit_cloister.gd`; nothing in `RuinKit.PIECES` or the gallery changed. It has:

- **Four ranges.** Each is seven pointed arches on the kit's clustered piers, carrying a **wall-walk** at 4.48 m (the height of two kit stair flights). The walk is walked on clean boxes, by the round-3 convention.
- **The water gate.** On the east range, a wider round arch over the spill channel, its walk raised 0.38 m. The plane threads it.
- **The west gap.** The west range has three bays fallen: the cloister's gap. Two snapped piers stand in it as stubs, with clean tops. A fallen chunk of wall and a block lie at each broken end (`heap`).
- **The lavabo.** A pavilion of four arches on a little isle in the tarn, with fallen drums as a way up.
- **The slab bridge.** It crosses from the south terrace onto the wall-walk.
- **The alley's back wall.** Coursed masonry, as high as the rim's first step behind it (4.48 m on the south terrace).
- **Two stepped buttresses** on the north range's garth face.

### Clustering

The satellites form a ring of four isles at different heights round the mother (walk height is y 30.5):

| Isle | Top over the walk | Ruin |
|---|---|---|
| West | +2.2 | Lancet window wall, framing the cloister through the saddle |
| South-west | −1.6 | Snapped pier and carved chest |
| North-east | +6.6 | Pointed arch: a gateway in the sky |
| North | +8.6 | Fallen pier, and the lodestone on an altar stone |

Three are tied to the mother by the game's **live rope bridges** (`Footbridge.build_mesh` and `live`, the spring sim, kept). They are 9 to 12 m long, between **stone heads** from the kit (`abutment`: coursed block, clean top, two bollards with rope lashings).

Floating-stone chains close the ring:

- west isle → south-west isle (6 stones, stepping down);
- crag summit → north isle (4 stones);
- north isle → north-east isle (7 stones).

### Bridges walked live

The study's pilot reads the physics space, which has no deck. So the study swaps its ground for `BridgeGround`, a `PilotPhysicsGround` subclass in `studies/cloister_tarn_isle.gd`:

- **The deck.** On a bridge, the ground is the deck where it sags and sways now (`RopeBridge._on_deck`), as the game's walker reads it.
- **The hand ropes.** Stepping is held between them (`RopeBridge.hold`).
- **Each step.** `RopeBridge.tread` is fed his weight and landings, and he is carried with the sway.
- **The plane.** It shudders the bridges in passing (`flown_by`).

### Water

The tarn uses the sky islets' pond water (`shaders/islet_pond.gdshader`): a dark, glassy, slate-blue tarn, tinted by the presets. It has a collision surface on its own layer (`WATER_LAYER`), so the plane skims it and the pilot never stands on it. He wades and swims through two `pools`, the tarn and the channel.

The plate's real still water (from `geometry.scn`, as `SkyIslets._pond_material` steeps it) was tried first. Off the plate its maps are missing and it rendered milky grey (`captures/cloister-tarn/r1/2-tarn.png`).

### Everything else is the aqueduct isle's, reused

`studies/cloister_tarn_isle.gd` **extends `studies/aqueduct_isle.gd`**, which is not edited. It overrides only:

- the pack load (no station);
- the room and art;
- the light's summit;
- the pilot's ground;
- flora, sky, life and lodestone placement;
- the plane's ground (it skims the water);
- safe ground (never in the tarn);
- the foot hint.

The sky (far isles, clusters, airships, CPU planes, open-air life, motes) comes through a `TarnSky` subclass, which swaps only its plane tokens. Life runs through a `TarnLife` subclass of `studies/aqueduct_isle_life.gd`.

## Routes (all proven headless: `tests/test_cloister_tarn_isle.gd`, PASS, 31 checks)

**Easy (walked, no jump)**
- **Onto the wall-walk.** Up the south-east slope, along the crest, over the south terrace, across the slab bridge.
- **Round the wall-walk.** South range, over the water gate's raised walk, north range, down to the gap.
- **The crag summit.** Out of the west door, over the saddle, up the ridge (about 21°), then the kit stair onto the summit (y 40.5).
- **The rope bridges.** All three walked across and back on their live decks, never falling.

**Medium (jumps and catches)**
- **The west gap's heaps, both ends.** Alley floor → block (1.5 m) → wall chunk (3.0) → catch the wall-walk (4.48).
- **Both north buttresses.** Set-offs at 1.6 and 3.2, then the wall-walk.
- **The lavabo.** Three stepping stones over the tarn to its isle, dry-shod, then its drums (1.5, 3.0) onto its top.
- **The floating-stone chains.** All three hopped end to end onto their isles.
- **The spill channel.** Crossed in the alley on two slabs, dry-shod. Stepped into, he wades it.

**Expert**
- **The loop across the gap.** Walk off the north end onto the chunk, onto the lower stub, a running jump stub to stub (2.7 m, 0.6 m up), onto the south chunk, a catch back onto the walk, and on round to the slab bridge. The loop closes.
- **The north face's six rock tiers.** Climbed from the alley, a jump-catch each, onto the crest.
- **A jump on the north-east bridge's sagging middle.** He lands back on its deck.

**Tarn.** Walked in from the garth, he wades, then swims. He swims across to the lavabo's isle and climbs out.

**Soundness**
- No hole in the mother's ground (7,129 probes).
- Every stone's walked top is where it is drawn (23 stones).
- The isle draws 336k triangles (the cap is 900k).

**On-foot tokens.** The routes above take all 7 (gate, stubs, lavabo, tiers, bridge, crag, stones), with the shared climbing readout.

**Plane line (not proven by test).** The intended line runs:
1. in over the west saddle;
2. through the cloister's gap, between the stubs (2.6 m clear, level wings fit) or over them;
3. skimming the tarn south of the lavabo;
4. through the water gate (4.4 m clear, its crown 3.8 m over the walk);
5. off over the fall.

Five sky tokens lie along it (`ct:gap`, `ct:skim`, `ct:gate`, `ct:fall`, `ct:keel`). It was not flown or tested; that is the first thing to try by hand.

## Perf

Measured with the `--capture` timing on this Mac at 1440×900, vsync off. With the sky on:

| View | ms a frame | Draw calls | Primitives |
|---|---|---|---|
| Establishing (whole isle and sky) | 45.9 | 728 | 1.43M |
| South-west, high | 29.6 | 671 | 1.37M |
| Tarn, west | 26.4 | 628 | 1.26M |
| Gate, low | 18.4 | 743 | 1.28M |
| On foot, alley | 17.7 | 661 | 1.11M |
| Fall | 16.6 | 616 | 1.31M |

- **Triangles.** About 336k static. The plants add about 358k instanced: 3.8k grass tufts and about 200 flowers in 89 multimeshes. The undergrowth is extra.
- **Draw calls.** About twice the aqueduct isle's 344 (from its hill, with the sky). The pieces are separate meshes: four ranges, heaps, lavabo, back walls, eight stone heads, satellites, stones. Merging the cloister (`RuinKit.merge`) is the obvious cut.
- **Build.** About 2.9 s headless to walking (8 s on a cold first run).
- **Collision.** The mother's 18.8k cliff prisms. They live in bodies of 2,048 each, because one compound with the trimesh overflowed Jolt's sub-shape ids and the ground had no collision.

## Captures (`captures/cloister-tarn/`, git-ignored)

- **`r1/`, the first pass.** `1-establishing.png`, `2-tarn.png` (the milky plate water), `3-tarn-west.png`, `4-crag.png`, `5-gate.png`.
- **`r2/`, after the fixes.** `2-southwest.png`, `6-north.png`, `7-onfoot-alley.png` (the masonry back wall), `8-fall.png`.

`r1/1-establishing.png` and `r2/2-southwest.png` read best: square cloister, round tarn, crater, satellites, bridges and fall.

## What's weak

- **The crag isn't dramatic enough from afar.** From the north (`r2/6-north.png`) the rim reads as a raised green ring, not a crag. Its summit is only 10 m over the walk, because the walked ridge would pass 22° if it rose more. A second kit flight, or a switchback ledge, would let the crag go to 14–16 m.
- **The north face's tiers read as a quarry.** They show as horizontal bands of tan rock (`r1/4-crag.png`). The faces are smooth and fluted, as the aqueduct isle's cliffs are. More bulge and overhang, or broken tiers, would help.
- **The mother's sides show a thick band of earth.** Under a high rim, the turf lip and earth rings hang from the rim's own height.
- **The coping reads a touch clean** from the wall-walk, and the slab bridge is a plain beam.
- **The plane line is untested.** The bump through the stubs and the skim over the tarn's surface collider (WATER_LAYER) have not been flown.
- **Two leaps aren't proven, and may not work.** The leap across the north alley from the wall-walk onto the tiers has no run-up across the wall's 1.2 m thickness. The lavabo leap is 5.6 m.
- **The bot can't see a wall's top over a step.** On the buttresses it needed a back-off-and-jump retry.
- **The rope bridges skip the footfall push.** Landings bounce the deck, but footfalls don't, because the drawn body's events aren't exposed.
- **There's a tiny exit leak.** One ParticlesShader RID is leaked at exit, from the fall's droplets. The aqueduct isle has the same known leak.
- **The north isle is plain.** It has only a fallen pier and the lodestone's altar.

## What to extract into a shared "kit isle" builder

The aqueduct isle's parts read its own art by name. These copies are parameterized here and should move to one shared builder:

1. **`island(outline, depth, seed, flat, top, cliffs_box, fine, water)`** and **`cliff_points(rng, flat, box, walled)`**, in `cloister_tarn_isle_art.gd`. These are the aqueduct isle's island and cliff builders, given a ground callable, a cliff box and a wall test. Two things here are new:
   - The prisms are split into bodies of at most 2,048 (needed on any big cliffy isle).
   - The edge rings hang from the rim's own height.
2. **`ground_tone(..., over)`.** The tone with injected wear (paths) and an underwater bed tone.
3. **`grow_flora` and `grow_undergrowth`**, in `cloister_tarn_isle_life.gd`. These are `Flora.grow` and `Undergrowth.grow` with a `bare(p)` callable instead of `Art.path_wear`, and with water excluded. They reuse `Flora._draw`.
4. **`TarnBirds.tarn_groups`.** The aqueduct isle's `find_groups` with the candidate points given.
5. **`TarnTokens` and `TarnSky.tarn_tokens`.** These only swap where the tokens stand. The aqueduct isle's token and sky nodes could take their lists as data.
6. **The `BridgeGround` deck and hold**, in `cloister_tarn_isle.gd`. Any study with live rope bridges wants this in `PilotPhysicsGround` or a shared subclass.
7. **`fall()`.** A free-standing curtain fall off a lip, the islets' `_fall` without an islet. It belongs beside `SkyIslets.curtain`.
8. **The aqueduct isle's rig.** Look, plane, lodestone, sky and life in `aqueduct_isle.gd` worked as a base class with few overrides. Pulling the aqueduct-specific bits (`Art.TOP`, `Art.HILL`, the lodestone text) into overridable members would make it a clean "kit isle" base.

## Files

- `studies/cloister_tarn_isle.gd`, `.tscn`: the study.
- `studies/cloister_tarn_isle_art.gd`: landform, layout, satellites, bridges, stones, water, fall, routes.
- `studies/cloister_tarn_isle_life.gd`: life, flora, birds, tokens, sky tokens.
- `scripts/ruin_kit_cloister.gd`: kit family, additive.
- `tests/test_cloister_tarn_isle.gd`: the route test.
- `run-cloister-tarn.command`, `tools/cloister_tarn_captures.sh`, plus an entry in `scripts/scene_catalog.gd`.

## Checks

- **Import check.** Clean.
- **`tests/test_cloister_tarn_isle.gd`.** PASS.
- **`tests/test_scene_picker.gd`.** PASS for the new entry.
- **Not run.** The full suite, per instructions. Nothing was added to `tests/known_failures.txt`.
