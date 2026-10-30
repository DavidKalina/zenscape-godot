# Doors: discrete regions joined by a flown door (round 1)

Branch `claude/game-direction-architecture-fe6e13`. Prototype round: no
committed tests; proof by smoke, a throwaway driver and rendered stills.

## What was built

- **The `doors` world, now the default** (`WorldProfile.PLAYS`;
  `scripts/endless/world/profiles/doors.gd`). It is the regions engine
  (`profiles/regions.gd`) over a new map, `scripts/endless/world/door_map.gd`:
  two half-worlds, wilderness round x = 0 (the start) and amberlands round
  x = 50 km (`OFFSET`, `--door-offset=M`), with the one 1.5 km blend band at
  x = 25 km. Each home is 25 km from the band, past the widest view
  (7.6 km fog x view 2.5 = 19 km), so each side plays at full strength:
  its own land, paint, mood and hour. `--world=regions` (the patchwork),
  `--world=wilderness` and `--world=amberlands` play as before.
  `regions.gd` gained two hooks for this (`_region_list`, `_make_map`).
- **The doors** (`scripts/endless/region_doors.gd`, built by
  `studies/endless_flight.gd` when the world has them):
  - `doors/amber-wall`: a wall of cloud (760 x 640 x 220 m, 90 camera-facing
    puffs, `shaders/door_cloud.gdshader`) placed from the start meadow: the
    best of 24 headings x 2.4–3.6 km over low ground or sea, in line of
    sight from the meadow, favouring ahead of the takeoff and low ground on
    the far side. Warm gold, with its own lighter haze so the hue still
    reads at 2.4 km.
  - `doors/morning-wall`: the same spot on the amberlands side, cool pale
    blue against the amber hour.
  - Flying into a wall's core: whiteout in the wall's hue (0.35 s), the
    plane moved to the same spot in the other wall and out past its far
    face, heading and speed kept, height over the ground kept (at least
    25 m, under the ceiling); held in white while the land stands
    (0.45 s least, 4 s most, `--door-hold=S`), the near dressing primed,
    then the white clears into the far side's light (0.85 s). The stick is
    let be through the white. The view also whitens with depth as the
    camera enters any wall, so the entry is continuous.
  - Each side has its own land stream (the host's `land` is swapped at the
    carry); while the plane is within 1.8 km of a wall, the far side's
    stream is stepped round the exit point, so the land is standing on
    arrival. The side left keeps its chunks for the way back.
  - Each side keeps its own clock: the day cycle is put on the far side's
    hour as it was left (the first time, the region's `paint.hour`).
  - Hysteresis: the wall it came out of only works again once the plane is
    300 m clear of its box.
  - No carry while a rival race runs or on the wheels.
- **The hint**: every 80–160 s (first after 20–40 s), while the plane is in
  wilderness within 6 km of the amber wall, one traffic plane comes in
  between the player and the wall and flies into it, put away inside
  (`EndlessTraffic.door_run`, plan "door": no tricks, not recycled for
  distance).
- **The logbook**: the first pass of each wall is a find, `door/amber-wall`
  and `door/morning-wall`; it shows in the J logbook as "door" (no fixed
  FINDS row, so the logbook says nothing before the first pass).
- Layout names: `doors/amber-wall`, `doors/morning-wall` (LayoutOverrides
  `xform` and `track`). A moved wall carries its own frame: the plane maps
  through each wall's local frame and the heading turns by the yaw
  difference.

## How to play

- `.\run-endless-flight.cmd` (or `python tools/play.py`). Take off from the
  meadow; the gold cloud tower is 2.4–3.6 km off over the sea or low land.
  Fly into it. In amberlands the pale wall is behind you; turn round and
  fly into it to go home.
- Flags: `--doors=0` (no doors), `--door-near` (the wilderness wall 900 m
  ahead of the start), `--door-offset=M`, `--door-hold=S`.
- `--world=regions` for the old patchwork.

## Proof

Headless, `--fixed-fps 60`, seed 1, `--pilot=fresh`:

- Smoke (`tools/smoke.py`): main scene default (doors), `--world=regions`
  and `--title`: PASS, 0 errors.
- Driver `scratch/doors.gd` (uncommitted; `--full` flies from the start by
  the stick): 21/21 checks. From the start (origin, `--no-title`) the
  wall stands 2.4 km off over the sea, in sight; flown in after 6321
  frames. After the carry: region weights [0, 1], mood `amber_hour`, hour
  10.08 -> 16.71, heading 0.0–0.9 deg off, speed 38.4 -> 36.0 (another
  run 36.7 -> 36.7), flying away from the morning wall, find logged.
  Landed on an amberlands meadow (MenuSpot) in about 260 frames (the
  driver sets up a short final approach and holds the brake). Back
  through the morning wall: mood `alpine_morning`, the wilderness hour
  where it was left, heading 0.0 deg off, out 171 m from the wilderness
  wall, no re-trigger over the next 300 frames, second find logged.
- Hold and frame times (headless wall clock, carry start to 3 s after):
  into amberlands the land was 100% prewarmed; hold 1.9–2.5 s, worst
  frame 1.6–2.1 s: one frame of near-dressing prime (the arches of a
  fresh amberlands side), under full white. Back to wilderness: hold
  0.35–0.45 s, worst frame 160–300 ms.
- Before the prewarm (one stream, re-streamed after the jump): 117 of 222
  chunks stood after 4 s; a full rebuild takes about 7 s here. The
  prewarm is what makes the jump fit in the white.
- Hint driver `scratch/doors_hint.gd`: a door plan sent 1147 m from the
  wall, flew 64 s and was put away inside it.
- Rendered stills (`scratch/doors_shots.gd --rendered`, `--no-title` at the
  title's meadow `--at=96.89,14.71 --heading=112.5`):
  `captures/doors/f_sheet.png` (the meadow from the grass and from 45 m,
  the approach, the edge whiteout, mid carry, the clearing, the arrival,
  and the morning wall seen from ahead). In that rendered run the plane
  was placed only 500 m short of the wall, so the prewarm had about 14 s:
  hold 4.4 s (the cap), worst frame 477 ms.

## Stood in or open

- The band is still there at x = 25 km: flying 23 km straight east from
  home (about 10 minutes at cruise) reaches it. Nothing turns the plane
  back yet.
- The walls are their own puff meshes, not part of the raymarched cloud
  volume: no shadow, no collision, and up close they are softer than the
  game's clouds.
- The first visit to amberlands has a single 1.5–2 s frame (the arches'
  prime) inside the white; the trees are left to stream. Rendered frame
  times over a real play session are unverified (the numbers above are
  headless or one short rendered run).
- Arrival height over the ground has a 25 m floor, so a very low entry
  comes out higher.
- The existing region caption ("Amberlands" / "Wilderness") shows on
  arrival.
- The rival race, shop and beat routes still sit round the wilderness
  start; amberlands has none of them.
- Both sides' land stays in memory once visited (about 230 chunks each).
- The meadows-and-flats guarantee: the doors add no terrain, and each
  side is its region's unchanged land, so each keeps its own guarantee.
  The arrival point itself is not chosen for a flat (the driver found a
  meadow within reach and landed there).

## Tests

No test references the changed files except `test_cloud_shade_steady`
(suite gpu: skipped headless, unverified). None known broken.

## What the next door round needs

- More than two regions: the door map generalised from two half-worlds to
  N homes far apart (homes k x OFFSET along x, bands half way), the door
  list from a fixed pair to door pairs `{from side, to side, kind, spot}`,
  and one land stream per visited side (freed when a side has not been
  visited for a while, to cap memory).
- Hidden doors: placement away from the start and out of sight, chosen per
  seed and named for the layout file; a hint per door (the traffic plane
  `door_run` takes any door's frame).
- A whirlpool in water (once there is a third region): a sea or lake spot
  from the field (`LandPonds`, the sea), a swirl in the sea shader or a
  mesh over the water, a trigger when the plane skims or touches the
  vortex (WaterContact), and the same carry. The cloud wall's carry
  (`_carry`, the prewarm, the hold) is shape-independent; only the
  trigger and the look change.
- Keeping the band out of reach (a turn back, or a wrap of each side
  round its home).
- Prewarming the dressing too (the arches' first-visit prime), or
  spreading it over the hold without blocking.
