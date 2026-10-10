# Aqueduct isle: the sky round it (handoff)

Branch `look/aqueduct-isle-sky`. This round makes the sky round the aqueduct isle
feel lived in. It only wires up systems the game already has and adds no new ones.

## Where

- `studies/aqueduct_isle_sky.gd` holds all of the work: one `Sky` node with a
  `setup(study)` call. It runs its own `_process`, reads the study's camera,
  `flying`, `plane` and `plane_figure`, and does all its wiring there.
- `studies/aqueduct_isle.gd` has one self-contained block: the `IsleSky` preload,
  the `sky` var, `_add_sky()` (under "The sky round it"), and one `_add_sky()`
  call in `_ready` after `_build_lode()`. A capture flushes the sky whole first.
- `tests/test_aqueduct_isle_sky.gd` is the feature test (headless).

## What is in

| Part | Reused from | Wiring here |
|---|---|---|
| Lone far isles (17) | `SkyIslets._make` / `stand`, `SkyIslet.author` recipes | 4 near isles (125–200 m, to fly to), 6 in a mid ring (350–750 m), 7 big coarse ones (step 2.5, radius 40–58) in the haze at 1.3–2 km. Groves, springs with falls to the cloud sea, hills, crag, shore. Trees per m² by kind (`TREE_DENSITY`). |
| Clusters (6) | `SkyClusters._plan` / `_stand_some` / `_animate`, the solver and dresser | farmstead, falls, hamlet, reef (lighthouse), lake, forest at 250–950 m: cabins, windmills turning, docks, bridges, lamps, sky folk, night lights. |
| Pierced isle (1) | `SkyPierced._plan` / `_stand_some` / `bump` | seed 3 at (520, 64, -700): a landmark to thread. Its rock bumps the plane through its own field (`bump`, called after the study's fly step). |
| Collision | – | Every isle's top is a trimesh on layer 1 plus the isle's `TURF_LAYER`, and its sides on layer 1. The plane skims them, gets bumped off them and can set down on them, the same as on the isle. |
| Airships (3) | `SkyAirship._make_ship` (the tow event's ship: envelope, gondola, crew, windows, lantern), `airship_build.gd` | They fly slow Catmull-Rom loops (`ROUTES`). Route 0 passes about 100 m off the isle. Propellers spin, the bow crewman waves within 70 m, and they light up at night. Each has a capsule and box body on layer 1, so the plane bumps off them. |
| Engine drone | `GlideAir.engine` (the plane's propeller hum) | It's faint, heard from 170 m and full at 45 m from the nearest airship. |
| CPU planes (4) | `SkyTraffic` (subclass `IsleTraffic` swaps only `_choose`) | They lap the clusters and the pierced isle and buzz the near and mid isles. The `ground` callable is a physics ray plus the pierced isle's box, so they climb clear over what stands. They are always shown. |
| Open-air life | `SkyAmbientLife` (subclass `IsleLife`; `IsleHosts` stands in for SkyIslands) | Gulls ride thermals and songbird flocks burst out of the tallest crown on the 3 nearest isles within 420 m. The gull mesh is the Fidelity source gull from `geometry.scn`, the same as LandLife's. |
| Motes | `SkyMotes` | One set spread round the isle (scale 2) and one round each of the two nearest clusters, at a fixed strength of 0.75. The game shows them only with the Mystic sea, so this is the one place we turn them on by default. |
| Tokens (6) | `SkyCollectibles` (`add_source`, its HUD, blip and line run), `CollectibleLines.line` | Laid by hand in world coordinates. There are no seeded trails here (`_trails_laid` is set). |

## Flags

Everything is on by default. You can turn parts off with:

- `--no-sky`: all of it.
- `--no-far-isles`: the lone isles, clusters and pierced isle. This also turns
  off the life, which needs them.
- `--no-clusters` and `--no-pierced`: the game's own flags, honoured here too.
- `--no-airships`
- `--no-traffic`: the game's own flag.
- `--no-sky-life`
- `--no-motes`
- `--no-sky-tokens`

## Tokens and the line each one asks for

| Id | Where (world) | Line |
|---|---|---|
| `aq:knife` ×2 | (91.8, 25, -29.2) and (100, 25, -29.2) | Fly east along z -29.2 on **knife edge** (hold Q or E). The line slips through the 1.9 m gap between the first two stepping stumps, then past the arch pier under the aqueduct. Flying level bumps you off the stumps (the test checks this). |
| `aq:break` | (100, 31.5, -34) | East through the fallen span, right where the channel's water spills. |
| `aq:keel` | (85, -9.5, 0) | Under the near island's hanging rock, about 4.5 m below its lowest point. |
| `aq:west` | (37.8, 34, -0.5) | Thread the 4 m gap between the west islet and the hill's crag, flying along z. |
| `aq:east` | (128.8, 27.5, -8) | Thread between the east islet and the isle's rim, flying along z. |

## Perf

These were measured on a Mac with a Retina window (`--capture` timing, vsync off):

- From the hill looking out: 25.2 ms, 344 draw calls, 1.54 M primitives. With
  `--no-sky` it is 17.2 ms, 129 draw calls, 1.16 M primitives.
- Wide shot from outside: 16.7 ms, 363 draw calls.
- From the plane: 16.7 ms, 281 draw calls.

What keeps it cheap:

- Near trees draw out to 300 m, then the far stand-ins take over out to
  1600 m. Small plants draw out to 170 m.
- The far isles use a 2.5 m grid.
- Nothing far casts shadows (the shadow distance is 140 m).
- Isles are made on workers and stood up one part a frame inside
  `SkyCommits`' 4 ms budget, fading in.

Building everything synchronously (`flush`, used by tests and captures) takes
about 4.5 s. Nothing streams out: the whole set stands for the session. That
is about 55 islet records plus the pierced rock.

The draw-call count is the cost to watch on min spec. If it bites, drop the
mid ring's trees to stand-ins earlier, or cut some far isles.

## Skipped and why

- **The airship tow event** (an islet torn free and towed) was skipped. Its
  rules for picking a mooring read the main game's world: SkyWorld bounds, the
  seeded tower, forest-isle and islet cells, and `islets.cells`. Here it would
  find phantom islets and almost no clear moorings. It needs that layout logic
  re-wired before it can run here. The ship itself is reused.
- **Peaks, pillars, tepuis, forested isles and the Sundered hall** were left
  out. The first three are off in the game. The forested isles and the hall are
  very large and would compete with the isle.
- **Islands made from `sky_islands.gd` chunks** were skipped. They are baked
  from the plate's NativeTerrainData and editor, which this scene doesn't have.
  Authored islets give the same look.
- **`islet_lod.gd`** was skipped. It is the lower world's coarse-top swap. The
  sky's islets use the far stand-ins and visibility ranges instead, as here.
- **Chaff** from the ambient life was skipped. It needs a land coverage map.

## Known issues and what's open

- Trees, cabins and windmills on the far isles do not collide (only ground and
  rock do), so the plane passes through them. The main game's glide reads
  crowns as solid; this scene's bump is physics-only.
- The chase camera can go inside far-isle rock and the pierced rock.
  `_inside_stone` uses point queries, which a trimesh doesn't answer.
- The pierced bump runs one frame after the study's camera is placed, so the
  camera can lag one frame on a bump there.
- Nothing bobs. The isles stay still so their static bodies stay true.
- Headless exit reports one leaked shader RID (DummyShader / ParticlesShader).
  It comes from the islets' fall droplets' ParticleProcessMaterial, an
  engine-level leak that also shows with `--no-clusters --no-pierced`. The
  runner files it as a known exit leak, not a failure.
- The farthest isles (1.3–2 km) read as very faint silhouettes in Alpine
  morning. They could come nearer, or go bigger, if wanted.
- Merging with `look/aqueduct-isle-life`: if that branch also adds a
  `SkyCollectibles` node for on-foot tokens, there will be two HUDs. Fold both
  token sets into one source on one node.

## Try it

```
./run-aqueduct-isle.command            # on foot; look out from the hill
./run-aqueduct-isle.command --fly      # in the plane
godot --headless --path . --script tests/test_aqueduct_isle_sky.gd
```
