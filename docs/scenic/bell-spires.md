# Bell spires: handoff (round 1)

Branch `look/motif-bell-spires` from main 94a4d1c0. Not merged, not pushed. Run it with `./run-bell-spires.command`, or open **Ruins → Bell spires** from the title's Scenes picker.

This is one of the new hand-built sky motifs that replace the old cluster motifs. It lives in the aqueduct isle's world. Its footprint is smaller than the aqueduct isle's (about 50 × 40 m against 90 × 50 m plus the far island), but it is tall: the turf is at 30 m and the belfry's wall head is at 68.9 m.

## What it is

The motif is a crescent of turf over hanging rock. Rock spires rise out of it and around it like sea stacks (think Meteora or Zhangjiajie). The landmark is a ruined belfry, with its bell still hanging, on the tallest spire.

**The spires.** All six are built by `spire_rock` in `studies/bell_spires_isle_art.gd`:

| Spire | Top | Where | Crown |
|---|---|---|---|
| **hero** | 58.0 m | middle | the belfry |
| **low** | 38.96 m | by the start, east-south-east | a broken kit arch; the low bridge leaves through it |
| **gable** | 44.0 m | west | a kit arch with a small bell hanging in it (a bell gable) |
| **fin_high** | 47.08 m | north-west, part of a split fin | a broken pier |
| **fin_low** | 38.12 m | north-west, part of a split fin | a fallen pier |
| **needle** | 52.12 m | east | the kit's turret, weathered so its spiral is open |

- **How a spire is built.** Each spire is laid in beds of rock 2.4 to 4.4 m tall, sub-ringed about every 1.5 m and pushed in and out so the faces break up, with vertical grooves.
  - The beds step in to ledges. Ledges wider than 0.45 m are mostly turf-green.
  - Turf tops use the game's ground material and palette. Grass and flowers grow on them.
- **Free stacks.** The gable stack and the needle stand free of the isle, each on its own keel. Their beds swell and pinch, so some overhang.
- **Stacks with stairs.** The other four stacks never get wider going up, so their cut stairs always have headroom.
- **The fin.** The two fin stacks are clipped flat where they face each other. This makes a true 2.6 m chimney between them, from the turf up to 38 m. A chockstone (a big fallen block) is wedged across its outer end at the low stack's top.

**The cut stairs.** There are four (`cut_stair`), each winding round its spire:
- The hero's has 68 steps and 8 landings, and winds about 390° from the low bridge (38.96 m) to the summit (58 m).
- The low stack's has 32 steps from the turf.
- The fin_low stack's has 29 steps from the turf to the chockstone.
- The fin_high stack's has 32 steps from the chockstone to its top.

How they are built:
- **Treads** are the kit's stone (RuinKit `Build`, lean stone so tops stay level), over a corbel of rock tapering into the face.
- **Collision.** They walk on clean sector hulls (the `_walk_hull` convention). Each hull overlaps its neighbours by 6 cm, because a ray exactly on a shared hull edge slipped through.

**The bridges.** Four live rope bridges (`Footbridge.build_mesh` and `Footbridge.live`, that is `scripts/rope_bridge.gd` and its spring sim) radiate from the hero's stair landings, one at each height. Spans run from 7.2 to 13 m.

| Bridge | Height | Goes to |
|---|---|---|
| low | 38.96 m | the low stack |
| gable | 44.0 m | the gable stack |
| fin | 47.08 m | the fin's high stack |
| needle | 52.12 m | the needle |

- **Anchors.** Every end has a stone anchor from the ruin kit: two square posts under caps, a lashing band, a sill stone the deck rests on, and a coursed plinth.
- **Collision.** The deck walks on thin boxes along the bridge's resting curve. In this study the walker's ground (`BridgeGround`, an inner class of `studies/bell_spires_isle.gd`) adds the sim's drop, so the planks sag under the pilot. `RopeBridge.hold` keeps him between the hand ropes; jumping over the ropes lets him through. `RopeBridge.tread` takes his weight and landings.
- **The plane.** A plane passing close makes the bridges shudder (`RopeBridge.flown_by`).

**The belfry.** This is new in the kit: `scripts/ruin_kit_belfry.gd` `belfry()`.
- **Tower.** A 5.2 m square tower with 1.3 m walls round a 2.6 m shaft, 10.6 m to the wall head.
- **Openings.** A pointed door is at its foot. Slit windows run up the shaft. The belfry stage is open on four sides under pointed heads, and the west opening is at floor level.
- **Wall head and pinnacles.** The wall head is ragged on one side. Snapped pinnacles stand at three corners.
- **Outer stair.** It winds up round three faces in three kit flights (`RuinKit._flight`), with corner piers between them, to the floor at 6.16 m.
- **Inside.** Two piles of squared stone in the corners step up to the wall head, which is a walk all the way round.
- **The bell.** It hangs from a timber beam. It is faceted dull bronze with verdigris, has no glow, and has its own node. It swings as a pendulum, leaned on by the wind's gusts and pushed when the pilot lands in the belfry or a plane passes within 22 m. The gable's small bell swings the same way. `--no-bell` keeps both still.

**Floating stones.**
- **The drift.** A necklace of 8 stones hung in an arc in front of the hero, from the low stack's top to the gable's. Each rises 0.56 m, with 1.3 to 1.5 m of air between stones.
- **The causeway.** 4 stones from the needle turret's head across to the hero's summit.

**Life, sky and look.** These are all the aqueduct isle's:
- The grass and flowers, undergrowth, butterflies, fireflies, songbirds, the wind made visible, look presets (L, `--look=`), light, air and weather.
- The far isles, airships, CPU planes, the plane on F, and the lodestone.
- **The lodestone** hums on the belfry floor under the bell.
- **Songbirds** perch on the belfry's wall head, the anchor posts, the crowns and the floating stones.

## Routes up (all proven headless in `tests/test_bell_spires_isle.gd`)

**Easy routes (walked, no jump):**
1. **Start to the belfry.** From the start, up the low stack's cut stair, over the low bridge through the arch, up the hero's stair round the spire to the summit, then up the belfry's outer stair to its floor under the bell.
2. **The fin.** Up the fin_low stack's stair to the chockstone, over it and round the fin_high stack's stair to its top, then over the fin bridge onto the hero's stair. This makes a loop with route 1.
3. **Every bridge, both ways.** Each is walked both ways without a fall. The deck sags 0.18 to 0.21 m under the pilot.

**Jumping lines:**
4. **The drift.** From the low stack's top over the 8 floating stones onto the gable stack's top, and back down. This makes the gable a third loop through the hero (via the gable bridge).
5. **The needle.** Over the high bridge, in at the turret's door and up its spiral to its broken head (57.16 m). Then a twirled jump onto the causeway, and over its 4 stones onto the summit. This skips the last turn of the hero's stair.

**Expert lines:**
6. **The chimney.** Wall kicks up the 2.6 m chimney between the fin's stacks: 33 kicks from the turf to 38.12 m, onto the low fin stack's top.
7. **The belfry's wall head.** Up the two stone piles inside, a 1.4 m jump-catch each, onto the wall head (68.5 to 68.9 m), the isle's highest walk and its vista.

**Soundness:**
- Every cut-stair tread grounds its top (0 of 1602 probes off).
- Every floating stone stands where it is drawn.
- The start is on turf.

## Tokens

- **On foot.** Seven tokens, in the aqueduct isle's style (`studies/bell_spires_isle_tokens.gd`): the chimney, the drift, the high bridge, the turret's head, the causeway, the belfry's wall head, and the fin's top.
- **The plane.** Seven more (`studies/bell_spires_isle_sky.gd`):
  - Under the low, gable and needle bridges.
  - Knife-edge down the chimney.
  - Low between the needle and the hero.
  - Over the belfry's open head.
  - Under the keel.
- **The plane line.** Threading the spires and dropping under the radiating bridges is the moment. The bridges sit at four heights, so the gaps under them stack.

## Flags

These are the same as the aqueduct isle's, because the study extends it:
- `--no-flora`
- `--no-life`, and each part alone: `--no-undergrowth`, `--no-butterflies`, `--no-fireflies`, `--no-birds`, `--no-wind-life`, `--no-tokens`
- `--no-sky`, and each part alone: `--no-far-isles`, `--no-airships`, `--no-traffic`, `--no-sky-life`, `--no-motes`, `--no-sky-tokens`
- `--fly`, `--drift=`, `--no-lode`, `--carry`, `--stone-plane`, `--stone=<look>`, `--look=<preset>`
- `--capture=out.png --at=x,y,z --look=x,y,z`, and `--place=x,y,z[,turn]`

New here: `--no-bell`.

## Perf

Measured on this Mac, rendered at 1440×900 with the 1080p cap, vsync off.

- **Art.** About 185k triangles (the aqueduct isle's is about 300k). The test budget is 900k. Built in about 1.1 to 2.6 s.
- **Flora.** 2.1k grass tufts plus about 150 flowers, about 210k instanced triangles.
- **Frames:**

| View | Draw calls | Primitives | Frame |
|---|---|---|---|
| Establishing | 633 | 877k | 22–41 ms |
| From the meadow | 689 | 965k | 17–33 ms |
| Belfry close-up | 439 | 746k | 26 ms |
| Start on foot | 249 | 545k | 25 ms |

  The aqueduct isle's establishing view is 539 draw calls, 958k primitives and 18 ms. Frame times on this Mac swing a lot between runs, so treat them as rough.

## Checks

- **Import.** The headless import is clean.
- **`tests/test_bell_spires_isle.gd`.** PASS headless, 26 checks.
- **`tests/test_scene_picker_entries.gd`.** The bell spires entry runs with no script errors.
- **Not done.** The full suite was not run, per standing instructions. Nothing was added to `tests/known_failures.txt`.

## Captures

These are in `captures/bell-spires/` in this worktree (ignored by git):

| File | View |
|---|---|
| `bs_1-establishing.png` | From the south-east, high. The whole motif: hero, belfry, the free stacks, the high bridge and the causeway. |
| `bs_2-from-the-meadow.png` | Low from the start's meadow. The best read: arches, bridges, belfry, needle. |
| `bs_3-thread.png` | At plane height between the needle and the hero, under the high bridge. |
| `bs_4-belfry.png` | The belfry close, its outer stair, the causeway and the needle's bridge. |
| `bs_5-fin-chimney.png` | The fin from the west, its stairs and the chockstone. |
| `bs_6-start-on-foot.png` | The walker's camera at the start, by the low stack's stair foot. |

## Weak

- **The rock reads brown and smooth from afar.** It uses the aqueduct isle's island-side rock tone (drawn toward basalt) under the ruin stone shader. It matches the aqueduct isle but not the far islets' grey strata. Up close it is faceted and grooved. It could use the rock looks' strata (`scripts/rock_looks.gd`, `scripts/sky_pillar.gd`'s beds) for more drama.
- **The corbels look busy.** The rock corbels under the cut stairs read as a jagged collar of slabs round the hero's upper beds, especially round the summit. They want fewer, bigger brackets, or the stair cut into the face (a notch) rather than hung off it.
- **The bell is hard to see from afar.** The belfry openings are small at distance. The belfry's silhouette carries the landmark; the bell doesn't.
- **The arches repeat.** The gable stack's arch and the low stack's arch are the same kit piece, so the two read alike. A proper bell-cote (a gable wall with one opening) would differ.
- **The meadow is plain.** The base turf has only grass and undergrowth, with no boulders yet.
- **The chimney is unclear from afar.** It reads from the west, but from most angles the fin reads as two stacks.
- **Some lines are bot-proven only by scripted jumps.** The causeway's first jump off the turret's head needs a twirl. Kicks against the jittered (not flat) rock beyond the chimney's ends are untested. So are ledge-to-ledge climbs up the spires' bed ledges; they are there, but no route is laid on them.
- **The sky is borrowed.** The far isles, the airship route and the old cluster motifs in the sky are the aqueduct isle's, centred near the same middle. The old clusters are still out there.
- **No sound.** The bell has no voice yet.

## What to extract into a shared "kit isle" builder

The flora, undergrowth, life, birds and tokens here are copies of the aqueduct isle's, with only their art preload and a few constants changed. That is why they should become one builder. Each item below is an extraction candidate:

1. **`IsleHost`.** `studies/bell_spires_isle.gd` extends `studies/aqueduct_isle.gd` and overrides `_load_pack`, `_build_room`, `_build_art`, `_build_lode`, `_add_sky`, `_add_life`, `_grow` and `_pack_runs`. Everything else is reused: the look, the plane, safe ground, the lodestone and the HUD. A base "kit isle" scene with those as hooks, and no aqueduct constants in it, would let every motif be a small subclass. The base still reads `Art.TOP` (30) for its rays and the plane's floor, which is fine only while every motif keeps its turf near 30 m.
2. **An art protocol** for the shared growth and life: `TOP`, `ground(x, z)`, `palette()`, `path_wear(p)`, `_edge_distance`, `_area`, `platforms()`/`platform(name)`. The five copies (`bell_spires_isle_flora/undergrowth/life/birds/tokens.gd`) differ only in which art they preload, the chaff meadow rect, the leaf anchors, the bird perch groups (`find_groups`) and the token spots. Pass the art in, and let the motif supply perches and spots.
3. **`turf(outline, height, seed, cell)` and `island(...)`.** These are parameterised versions of AqArt `island`, with the tone's path wear injected.
4. **`spire_rock` and `cut_stair`/`stair_node`.** These are general: any landform of stacked beds, and any stair winding round a vertical rock with clean walk sectors.
5. **The live bridge for the pilot.** `_bridges` (the mesh, the live sim, the deck colliders, the anchors) and `BridgeGround` (sag and hold for `pilot_physics_ground.gd`). Any motif with rope bridges needs both, and the hold and sag could live in `pilot_physics_ground.gd` itself.
6. **The pendulum bells** (`_swing`), as a small reusable node.

## Files

- **Scene:** `studies/bell_spires_isle.tscn`, `studies/bell_spires_isle.gd`
- **Art:** `studies/bell_spires_isle_art.gd`
- **Copies** (extraction candidates): `studies/bell_spires_isle_flora.gd`, `_undergrowth.gd`, `_life.gd`, `_birds.gd`, `_tokens.gd`
- **Sky:** `studies/bell_spires_isle_sky.gd`, a subclass that adds its own plane tokens
- **Kit, additive:** `scripts/ruin_kit_belfry.gd` (`belfry`, `bell`, `bridge_anchor`). No existing kit piece's output changed. `ruin_kit.gd`, `rope_bridge*.gd` and `studies/aqueduct_isle*.gd` are untouched.
- **Launch:** `run-bell-spires.command`, and a `scripts/scene_catalog.gd` entry (`bell_spires`)
- **Test:** `tests/test_bell_spires_isle.gd`
