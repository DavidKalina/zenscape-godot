# The Peak: handoff

Loop `peak` (spec: `spec-peak.md`), branch
`claude/game-direction-architecture-fe6e13`. Four lanes (stamp, lift,
lines, collar; merged at `d99d9ab6`) and fifteen trunk iterations, then
this final pass. The trail is `git log --grep='^ITER(peak)'`; each commit
has its numbers and its notes. Everything below was measured on this
Windows PC, seed 1, with the land in GDScript (this worktree's native
kernels fail their version check).

## What is built

**The massif** (`scripts/endless/peak_massif.gd`). An overlay in the land
field (`land_field.gd`: sample, height, shape, build_chunk, the horizon
grid), built from a centre, a facing and a profile table in the massif's
own frame (a along the axis from the plateau toward the start, v across).
A horseshoe open toward the start: glacier valley (a 4050..2050, 100..300
m over the sea) between curving moraines with crevasse bands, boulder
field (2050..1250, 300..400 m), icefall (1250..850, 400..520 m), the wall
(to the crest at ~1000..1100 m) with irregular buttresses and gullies
(`_lay_ribs`: per-rib width, strength, gully and wander, laid at load),
a crest that dips to cols between eight tower bases, a ridged head on the
axis (summit 1200 m), the plateau (1145) behind it and the back face
falling ~2 km to the sea. The couloir is a tapering, bending gully 280 m
off the axis on the -v side (mouth 610 m, notch 1025 m). Placed 4.5 km
from the start along the way `_way` scores best (sea behind, clear sight
from the start), through the handle `peak/massif`. The way search and a
64 m live-cell mask are worked out once per land and shared by every
worker's field; chunks outside the live cells skip the massif.

**Detail at height** (`land_stream.gd`). The stream measures each chunk's
distance from that chunk's own ground (tops returned by the workers, kept
in `_tops`), not from the sea, so the wall, the slot and the plateau get
level-0 chunks and colliders when the plane is near. Level-0 chunks go to
the worker pool as high-priority tasks, at most four in flight.

**Placement and ceiling.** The start meadow faces the summit (the menu's
meadow search prefers a take-off run toward it); the door
(`doors/amber-wall`) is placed off to one side over low ground, its height
capped so its top stands under the summit's angle from the meadow. Other
placers (arches, set pieces, rocks, shops, beat routes, trees) keep off
the massif (`LandField.off_peak`, the `peak` shape flag). The ceiling
rose (`CEILING_OVER` 1400); `FlightWeight.reach` gives each preset its
own flown top without lift.

**The tarn and the cirque.** The tarn is a pond entry the massif lays
itself, level forced at 1144 m, lobed outline shared by the water, the
river reads and the bowl (handle `peak/tarn`). The plateau is a cirque: a
lobed outline, a broken floor with knobs, a rock rim with a gap either
end of one exactly flat strip (236 x 44 m, the hand landing's length)
between the tarn and the head, the floor climbing to the head past it.
Landing on the plateau finds `place/peak`; the landing card adds "on the
Peak"; the logbook's places column lists it (`pilot_tallies.gd`,
`landing_summary.gd`).

**The couloir's lift** (`peak_routes.gd`, `air_lift.gd`, `sky_plane.gd`).
A lift tube (radius 60 m, 26 m/s) along the couloir's floor line 40 m up
and on over the rim toward the plateau. One way: the ridden rise scales
with the heading against the path's direction, all of it flying up, none
flying down. Outside the tube the air is as before.

**The ruined stair** (`peak_stair.gd`). A stand-in from the ruin kit's
stair flights (`RuinKit._flight` + `_rubble`), scaled 8x, cut into 26 m
flights from the icefall's head up the slot's floor beside the lift's
core, one in four missing. Built one flight a frame after load, kept in
the tree; `plane_ground` rises over each flight. Handles
`peak/stair/<n>`.

**Rock kinds on the Peak** (`scripts/endless/rocks/`, in
`RockPlan.KINDS`, on in every world through `RockPlan.ON_PEAK`):
`peak_spires.gd` (granite towers and satellites on the eight tower
bases, gaps from `WorldScale.opening`, kept off the lift tube and the
plateau), `peak_boulders.gd` (blocks on the cirque's rim, floor and
talus, kept off the strip, the tarn and the lift), `peak_valley.gd`
(boulder field and seracs on one weaving line, `PeakValley.line`, nothing
within `opening(10)/2` of it, poles on the bends, kept off the stair and
the lift). Each kind streams within 8 km and answers the flight as the
other rocks do.

**Paint** (`shaders/endless_ground.gdshader`, `PeakMassif.paint()`). Inside
the massif's zone only: a snow line rising to 500 m and holding to steeper
ground with height, granite above the land's own tops, glacier and
icefall ice on the valley floor, scree on the boulder field, granite on
the cirque's rim. Outside the zone the land paints as before.

**The collar and its sky** (`endless_collar.gd`, `endless_clouds.gd`,
`shaders/endless_cloud_march.glsl`, `endless_look.gd`,
`shaders/endless_height_haze.gdshaderinc`). A standing, slowly turning
ring of dense cloud round the summit, 500 m radius, band 850..1050 m,
immune to `--cloud-cover`, lit paler from below than the field clouds.
Above the band, near the Peak, the sky shows its own hour (the ring sun
at 0.3, 16.45 h) blended in by eye height through the band; the land's
clock, the HUD hour and saved clocks stay the land's. A height term in
the land haze.

**Place lines** (`place_lines.gd`, `place_lines_hud.gd`, `pilot_book.gd`).
Merged and unused: no line is declared (`LINES` empty). `PLACES` names
"the Peak" for the card and the logbook.

## How to play it

`.\run-endless-flight.cmd` (seed 1). The start meadow faces the Peak. Fly
up the glacier, weave the boulder field and the seracs, pull up in the
V cut to the left of the head (the couloir) and ride the lift over the
rim; land across the plateau between the tarn and the head. Flags:

| Flag | What |
|---|---|
| `--peak=0` | no massif (and none of the below) |
| `--peak-at=x,z`, `--peak-yaw=deg` | put the plateau's centre there / face that way |
| `--ceiling=m` | the ceiling over the sea (default 1400) |
| `--lift=0` | no couloir lift |
| `--stair=0` | no stair |
| `--spires=0`, `--boulders=0`, `--valley=0` | each rock kind off (`--no-rocks` takes all) |
| `--cirque=0` | the old flat plateau disc and round tarn |
| `--peak-paint=0` | the Peak's ground paint off |
| `--collar=0` | no collar |
| `--collar-sky=0`, `--collar-hour=H` | the sky above the collar keeps the land's hour / shows hour H |
| `--peak-mask=0` | no live-cell mask (the massif tested everywhere in its circle) |
| `--lines=0` | no place-lines layer |

## Numbers

- Ceiling over the sea: off/light 1400, medium 1329, heavy 1222.
- Straight up, full back + Boost from 400 m, no lift (final pass): light
  1376 m at 150 s, the tarn's 1145 at 89 s; medium 1174 m, 1145 at 99 s
  (29 m over, barely); heavy 1100 m at 150 s, never.
- Couloir by the stick (final pass): medium up 141.3 s, slot ridden
  26.0 m/s, rim 1096 over the sea, carried to 1188, down 39.7 s, ridden
  0; heavy up 144.7 s, rim 1092, carried to 1175.5, down 43.3 s.
- From the start meadow (149, -38): summit 4210 m off, 15.7 degrees up;
  door top 9.6 degrees up, 55 degrees off the summit line.
- Chunk builds (cost pass, headless, mean of 4): Field.new 50.5 -> 0.61
  ms; a chunk build near the Peak ~90..130 -> ~40..76 ms, far ~51..56 ->
  ~1..6 ms. With no Peak in iteration 1: far level 0 6.4 ms.
- Frames (cost pass, rendered 1440x900, the couloir flight up and down,
  11610 frames): median 6.2 -> 7.0 ms, p99 12.9 -> 11.6, worst away from
  loads 49.8 -> 28.5, frames over 100 ms away from loads 0 -> 0, hole
  frames (under 40 m with no collider below) 109 -> 0. Far cruise:
  median 7.6 -> 8.6, worst quiet 76.7 -> 30.6.
- First load (headless): the land stands in 8.2 -> 4.3 s (2.8 s with
  `--peak=0`); the scene's open() 35.0 -> 23.5 s (13.4 s with
  `--peak=0`). Smoke "ready" in the final pass: 26.1 s against 16.8 s
  with `--peak=0`.
- Rocks at full detail: spires ~14 pillars, cirque 127 blocks / 44k
  tris, valley 231 pieces / 93k tris; the stair 72k tris, always drawn.

## Stood in

- The stair is the ruin kit's flights scaled 8x and fitted to the slot's
  floor, not a kit piece made to climb a 1.9 m/m gully. On gentle ground
  near the icefall its flights lay as terraces (3 steps, 8.7 m treads). It
  reads from the mouth and the glacier's head, not from mid-glacier.
- The place-lines layer is merged and unused (no line declared).

## Parked by the user (2026-10-29)

The routes' gates and timed records, the logbook's per-route best times,
and the traffic plane flying the couloir. Iteration 6
(`0298d83a`, Notes) holds a gate layout for the couloir if wanted: glacier
a 3950/3150/2350, boulders 1650, icefall 1050 (valley middle, 35 m over
the ground, half 6 x 4.5 wingspans), mouth 70 m in front of the slot at
28 m over its ground (half 7 x 9), rim at the top's floor + 45 (half 8 x
10); `PlaceLines.LOST` 900 needs gates under 900 m apart; times by the
stick then: medium 136 s, boosted 87 s, heavy 139 / 90. Its driver is
`scratch/peak_couloir.gd`.

## Against "What done looks like" (final pass)

1. From the meadow: **partial.** Holds: the Peak stands well above every
   other hill, 15.7 degrees up; the door's gold cloud is off to one side,
   nearer and clearly lower. Not yet: the massif reads as a long snowy
   wall with spires and a darker head in its middle, the head only a
   little over the crest; the collar shows as a few clumps in front of
   the head, not a ring; and the middle distance (2 to 4 km, the arms and
   the glacier's foot) reads as a tan haze bank (`place/meadow.png`).
   Iteration 8 could not reproduce that bank; this pass's stills show it.
2. Flying at it: **holds** by eye (glacier, boulder field, icefall, the
   wall with towers on its crest, the head in cloud). The glacier's ice
   streaks show as long rectangular facets up close (`glacier.png`).
3. Stair and couloir: **holds**: the stair climbs the slot beside the
   flown line; the lift carries medium and heavy to the rim; flying back
   down rides 0 m/s. The stair is a stand-in (above).
4. Through the collar: **partial.** Holds: the sky above shows its own
   hour (16.45 h above, the land's 8.6 h below, by the numbers and by eye:
   low warm light above); the tarn lies in its bowl with a landable
   strip. Not met: from above, the collar reads as a cloud band hugging
   the head's front, not a floor (`sky/final/above.png`). The visibility
   drop inside it was judged in iteration 6 (a white-out in the slot's
   upper half), not looked at again here.
5. Landing card and logbook: **holds** for the Peak (landed by hand,
   grade hot, card "on the Peak", `place/peak` found, logbook places
   lists "the Peak"). The per-route best times are parked.
6. The back face: **partial.** The ground falls from the lip to the sea
   (iteration 4's profile checks); flown up from the sea by the stick to
   the plateau in 446 s with no crash, 39 ride frames and 1 brush on the
   spur at the lip. The dive down it was not flown in any iteration.
7. Three ways up as flyable ground: **holds** for the couloir and the
   crest between the spires (36.9 s round to the head, no crash); the
   back face is flyable but steep (about 1.3 m/m on the axis, a 7.5 min
   switchback climb), not the gentlest of the three. Gates and records
   parked.
8. Straight up: **holds** (light with margin, medium barely, heavy
   never; heavy reaches the plateau by the couloir).
9. Parked.
10. Meadows and flats: **holds** on the plateau (the strip is flat to
    0.00 m, landed on); the start meadow stands. Foot meadows round the
    toe were last landed on in the stamp lane, not since. Far chunks:
    **holds** (far builds ~1..6 ms, same as with no Peak).
11. Smoke: **holds** (0 errors default, `--peak=0`, `--world=regions`).
    No frame over 100 ms away from loads: **holds** by iteration 10's
    rendered measurement through the collar and the climb; not re-run in
    this pass.

## Open

- `scratch/peak_check.gd --part=agree`: collision against `height()` is
  red at its 0.05 m threshold: the rays read the 1 m mesh's linear fill,
  which departs from `height()` by centimetres where crevasses and
  moraine crests curve sharply (every ray over 3 cm matches the fill);
  and one ray near the start, at (71, -181) on ordinary land, hit 3.57 m
  over the ground: a collider other than the land, not identified.
- The collar's edge shows blocky stepping from the side (the rim still),
  from the march.
- Seracs' faces were faceted and layered in iteration 8; up close they
  are still simple slabs.
- A sharp dark horizontal line on a near tower (`crest_fly_14`), not a
  bed step; maybe the flare rings or `rock_build`'s ledge term. Base 0's
  flat top (by the couloir, no flare) reads as a plinth.
- First load is still ~10 s slower with the Peak (open() 23.5 vs 13.4 s
  headless); the land's prime is only 1.5 s of it. Not found which other
  prime (arches, halls, tunnels, trees, grass near the massif, the Peak's
  setup) takes the rest.
- The stair's 20..21 flights build on the main thread, one a frame,
  53..68 ms each, in the first frames after load.
- Straight up, heavy never reaches the plateau; medium only 29 m over it.
  If heavy should get there with Boost and patience, `FlightWeight.reach`.
- The massif, its rocks and its paint are on in every world profile
  (`--world=regions` included).
- Rivers stop where the massif lifts the land; only the tarn has water.
- The live mask keeps 69% of the circle live (a fixed 80 m margin).
- Other seeds and other hours (night land under a gold collar sky) are
  unmeasured and unseen; the slot's ~1.9 m/m middle let a boosted heavy
  plane skim to 2.8 m over its floor.
- The native land is untested: the kernels need rebuilding
  (`tools/build_native_kernels.py --godot-cpp`, no godot-cpp on this PC);
  the native readers skip the massif outside the live cells.
- From the final pass's stills: contour-ring patterns on the boulder
  field's scree (the rock paint's beds by height); yellow flecks on the
  snow by the tarn at eye height (`cirque/final/shore.png`), not
  identified.

## Tests the loop's changes may break

Not run (prototyping). Tests that read files the loop touched:

- `tests/test_sky_plane.gd`, `tests/test_glide_camera.gd`,
  `tests/test_knife_drift.gd`: preload `scripts/sky_plane.gd` (the
  one-way lift's scaling, the ceiling, `FlightWeight.reach`; reach 1.0
  and thin 0 under 215 m leave the old maths by construction).
- `tests/test_cloud_shade_steady.gd`: reads `endless_clouds.gd`,
  `shaders/endless_cloud_march.glsl` and `studies/endless_flight.tscn`
  (the collar, its paler underside, the collar sky).

No test in `tests/` names the other touched files (`land_field.gd`,
`land_stream.gd`, `peak_*.gd`, `rock_plan.gd`, `land_rocks.gd`,
`tree_plan.gd`, `arch_plan.gd`, `set_plan.gd`, `shop_sites.gd`,
`beat_routes.gd`, `menu_spot.gd`, `region_doors.gd`, `endless_look.gd`,
`pilot_tallies.gd`, `pilot_book.gd`, `landing_summary.gd`,
`place_lines*.gd`, `rival_marks.gd`, `rival_race.gd`, `flight_weight.gd`,
`endless_ground.gdshader`); tests that load the main scene through other
paths may still see the Peak.

## Drivers

Uncommitted, in `scratch/`: `peak_couloir2.gd` (`--boost`, `--shots`,
scene `--weight=`), `peak_spires.gd` (`--part=plan,crest,back`),
`peak_valley.gd` (`--part=plan|fly|stills`), `peak_tarn.gd`,
`peak_land2.gd`, `peak_climb.gd` (`--secs`), `peak_helpers.gd`,
`peak_place.gd` (`--shots --title_door --x=149 --z=-38`),
`peak_sky.gd`, `peak_cirque.gd`, `peak_stair.gd`, `peak_boulders.gd`,
`peak_cost.gd`, `peak_load.gd`, `peak_check.gd`.
