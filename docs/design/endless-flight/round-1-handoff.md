# Endless flight, round 1: the plane over endless land

Step 1 of the build order: endless streamed land, the sea and the plane.
No foliage, birds or ruins yet. The on-foot moves are untouched.

## Launch

- Mac: `./run-endless-flight.command [--seed=7]`
- Windows (PowerShell, repo root):
  `& $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 studies/endless_flight.tscn -- --no-title --seed=7`
- Any: `godot --path . res://studies/endless_flight.tscn -- --no-title [flags]`

It starts in the air at cruise. The controls are the aqueduct isle's:
WASD or the left stick to bank and pitch (W is nose down), the mouse
steers, Space boosts, Shift brakes, Q and E held give the knife edge
(tap twice, or click, to roll), F lowers the flaps, and holding the right
mouse button looks round. Put it down on a meadow, brake to a stop, then
Space rolls it off again; pull back past 8 m/s and it lifts off. R puts it
back up in the air over where it is. F1 shows the numbers (speed, height,
chunks drawn, building and queued, colliders, build cost). Esc frees the
mouse. You can't get out of the plane yet.

## What it is

- `studies/endless_flight.gd` / `.tscn`: the scene. It flies the game's
  own plane: `SkyPlane` at game speed, the hand landing
  (`ManualLanding`), `PlaneFigure` with its ground scale, and the
  `GlideCamera` chase, all fed by the isle's input path. The land counts
  as a heightfield to the flight (`SkyGlide.stone`): the plane rides up
  slopes, a cliff face turns it aside, the sea is ridden as water, and a
  dive into the ground slams and hops, as on the isle. The sky is a plain
  `ProceduralSkyMaterial` plus depth fog. The isle's live sky and clouds
  (`KitWeather`, `KitClouds`, `LandscapeLighting`) are tied up with the
  isle and didn't drop in, so they were left out.
- `scripts/endless/land_field.gd`: the land as a pure function of the
  seed (FastNoiseLite). Broad continents that sink under the sea, rolling
  hills, a few ridged mountains with snow, and meadows where a mask eases
  the hills almost flat. Colour comes from height, slope and meadow (sand,
  grass, meadow, rock, snow, seabed).
- `scripts/endless/land_stream.gd`: the streamer, a quadtree round the
  camera. Every chunk has 64×64 quads whatever its size: level 0 is 64 m
  across (1 m quads), and each level up doubles that, to level 7 at
  8192 m. 3×3 root chunks reach about 12 km out, and the fog closes at
  7 km.
  - Cracks are covered by skirts hung from every chunk edge. A chunk still
    building is covered by its parent or its children until it stands, so
    nothing pops open.
  - Chunks are built on WorkerThreadPool tasks, one field per task, using
    the cores less two. The main thread only turns the arrays into a
    mesh, capped at 2.5 ms a frame.
  - Level-0 chunks within 70 m get a `HeightMapShape3D` on layer 1, for
    the wheels and whatever walks later.
- `run-endless-flight.command`: the Mac launcher.
- `scripts/glide_camera.gd` (shared): one guard. When the flight direction
  barely changes it lerps instead of slerping. That stops a stream of
  engine "axis must be normalized" errors while the plane skims the
  ground, and makes no visible difference.

## Flags and knobs

Flags: `--seed=N` picks the land (default 1). `--at=x,z` sets the start
(0,0). `--heading=deg` is clockwise from -z (0). `--alt=m` is the height
over the ground at the start (45).

Knobs, all consts:
- `land_field.gd`: `SEA_Y` (-40, which keeps the peaks under the flight's
  fixed `CEILING` of 95), `CONTINENT*`, `LOWLAND`, `HILLS`/`HILL_TALL`,
  `MOUNTAINS`/`MOUNTAIN_BAND`/`RIDGES`/`MOUNTAIN_TALL`,
  `MEADOWS`/`MEADOW_BAND`/`MEADOW_KEEP` (how flat the flats are),
  `BEACH`, `SNOW`, and the colours.
- `land_stream.gd`: `CELLS`, `BASE`, `TOP_LEVEL`, `ROOT_REACH`, `SPLIT`
  (how soon chunks split, which sets the detail and the triangle count),
  `REPLAN`, `MAX_TASKS`, `COMMIT_BUDGET`, `COLLIDE`, `SKIRT`.
- `endless_flight.gd`: `FOG_BEGIN`, `FOG_END`, `FOG_DENSITY` (used only by
  the Compatibility renderer), `HORIZON`, `SEA_COLOUR`, `START_ALT`.

## Verified (cloud box: Linux, 4 cores, no GPU, Godot 4.7.2)

- Headless import: 0 errors. Smoke: `endless_flight.tscn` PASS (the land
  stands in about 3 s, then 400 frames with 0 errors). `aqueduct_isle.tscn`
  and `flight_study.tscn` still PASS after the camera guard.
  `test_glide_camera.gd`, `test_sky_plane.gd` and
  `test_world_scale_guard.gd` pass. The full suite was not run.
- Throwaway play-loop drivers in `scratch/` (git-ignored):
  - `endless_fly.gd`: about 70 s of real time (paced to 60 fps), with
    boost held and an altitude hold on the pitch, on seeds 1 and 7.
    - It flew about 1.7 km at 24.5 m/s and built about 11 chunks a second
      (0 to 26 in any one second). A chunk takes 11 to 12 ms on a worker,
      35 ms at worst.
    - The main thread's worst frame was 7.6 to 10.4 ms, with no frame over
      16 ms and 0 to 3 over 8 ms. The worst single mesh commit was 9 ms.
    - There was a collider under the plane on every frame.
  - The flats check, a 6 km square at the start and the end:
    - About 61% of it is land, and 17 to 20% of the land is flat (no
      steeper than 0.06 across 64 m).
    - Of about 350 land blocks (256 m each), 0 to 7 have no flat within
      600 m.
  - `endless_land.gd`, on seeds 1, 3, 7 and 42, through the real input:
    - It found a 200 m meadow strip within 400 m of the start every time,
      flew in with flaps and brake, and touched down (a greaser each
      time).
    - It rolled to a stop, the collider under the wheels matched the drawn
      ground to 0.3 m, it took off again, and a dive into the ground
      slammed and hopped with no errors.
    - The same seed gives the same land, and another seed gives different
      land.
- Stills from software GL (Mesa llvmpipe under Xvfb, the Compatibility
  renderer) show the shapes reading well: coast and beaches, the sea,
  snowy peaks, rolling hills and land to the horizon, with no seams
  visible.

## Not verified

- The look in Forward+ on a real GPU (the box has none). The llvmpipe
  stills over-light the sun (the sea comes out pale too), so the colours
  and light are unjudged. The fog curve and horizon blend, shadows on the
  near rings, and GPU frame time are unverified as well.
- The mesh upload cost on a real GPU. Headless uses the dummy renderer,
  so the commit times above leave the GPU out.
- About 250 chunks are drawn at a time, roughly 2.2M triangles. If that is
  heavy on the Mac, lower `SPLIT` (fewer, coarser chunks; not
  measured) or use 32 cells on the far levels.
- How flight feels over this land at this scale, and flights beyond about
  30 km. World coordinates grow without an origin shift. An
  unpaced headless run got about 15 km out with no errors, but very long
  flights will lose float precision.

## Existing tests this breaks

None known. The tests that cover the one shared change pass. The full
suite was not run.

## Next: round two (grass and trees that hold up at speed)

- Put scatter on the stream. Each level-0/1 chunk gets a worker-built
  instance list (MultiMesh) from the same field: grass where the meadow
  and slope allow, trees off the flats so they stay clear to land. Free
  it with the chunk.
- Reuse `scripts/dense_grass.gd` and its shaders for the near grass, fed
  from the chunk heights rather than the isle's ground, with a far grass
  tint in the land's vertex colour so it doesn't pop.
- Tree LOD in rings: full trees near, cards or impostors further out, and
  a canopy tint in the coarse chunks' colour beyond that. The forest mask
  can be another noise in `land_field.gd`.
- Measure the scatter build at 25 m/s with `scratch/endless_fly.gd`
  (copy it), the same way: chunks a second and main-thread spikes.
- Later: kinds of place (lakes and rivers need a water table, since the
  sea is one plane now), the isle's live sky and clouds, an origin shift,
  the on-foot hand-off (Exit when stopped, with the motor's switches), and
  making `endless_flight.tscn` the project's main scene behind a title.
