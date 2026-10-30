# The Peak

Loop slug: `peak`. Trail prefix `ITER(peak):`. Cap: the skill's default.
Budget: the skill's default. Model: Opus for the trunk and every lane but
the collar lane (Sonnet).

The wilderness gets one landmark out of scale with everything around it:
a massif about 5 km from the start meadow, rising to a summit lake at
about 800 m over the sea where the land today tops out near 300 m. The
start meadow faces it. It is climbed by flying, by several named routes,
each a standing line with a recorded best, and it is never gated: the
plane may climb straight up from anywhere, slowly, with nothing to chain.

Where the numbers below say "over the sea" they mean above `SEA_Y`
(`scripts/endless/land_field.gd`, -40 m), the same reference the ceiling
uses (`docs/design/endless-flight/flight-ceiling-handoff.md`).

## What done looks like

Playing `studies/endless_flight.tscn` on seed 1 with no flags:

1. From the start meadow, the Peak owns the horizon: one high head wearing
   a cloud collar, a long shoulder leading up to it, standing well above
   every other mountain. The gold door tower (`doors/amber-wall`) is off to
   one side, nearer and lower. Both read at once, through the haze.
2. Flying at it, the ground rises slowly for about 4 km: a glacier valley,
   then a boulder field, then an icefall. Then a wall rises faster than
   anything the land has, with granite towers standing on its crest and the
   summit block above them, in cloud.
3. A ruined stair climbs the approach and up a vertical slot in the wall,
   the couloir. Inside the couloir the plane rises faster than it can on
   its own. Outside it, the air is still, as everywhere in the game.
4. Climbing through the collar, visibility drops to what is close. Coming
   out above it, the sky is a different hour from the land below, the
   collar is a floor, and a tarn lies in a bowl on the summit plateau with
   a shore meadow long enough to land on by hand.
5. Landing there shows the landing card and registers `place/peak` in the
   logbook. The logbook lists the Peak and each route with its best time.
6. Over the lip on the far side, the back face falls to the sea: one dive
   from summit to water.
7. Three routes to the tarn, each a line with gates and a timed record:
   - **The couloir**: foot gate at the start of the glacier, gates at the
     boulders, the icefall, the couloir's mouth and the rim. Lift in the
     couloir. Fastest.
   - **The towers traverse**: round the side along the knife ridge,
     between the spires, to the rim. Longest, most near misses.
   - **The seaward face**: from the back, up the glacier that falls to the
     sea. Gentlest.
   The near-miss chain runs as usual on all of them; nothing new is scored.
8. Straight up, from anywhere, with no lift: a light plane reaches the
   tarn with margin, medium barely, heavy not at all. Heavy reaches it by
   the couloir.
9. A traffic plane now and then flies the couloir route and vanishes over
   the rim.
10. The meadows-and-flats guarantee holds everywhere round the foot and on
    the plateau. Chunks far from the Peak cost nothing extra to build.
11. No script errors in a smoke check; the transition through the collar
    and the climb show no frame over 100 ms away from chunk loads.

## Shape

A shallow horseshoe open toward the start meadow, about 4 to 5 km across,
its summit at the back of the curve with the sea behind it.

| Stretch | Height over the sea | Length | Flying |
|---|---|---|---|
| Glacier valley | 100 to 250 m | about 2.5 km | skim ice, crevasses as near misses |
| Boulder field | 250 to 330 m | about 1 km | slalom between house-sized blocks |
| Icefall | 330 to 420 m | about 0.5 km | thread seracs |
| The wall and couloir | 420 to 700 m | under 1 km of ground | climb the slot with lift |
| Crest and towers | 650 to 750 m | about 1.5 km round | knife ridge, spires to thread |
| Summit block | to 800 m | | into the collar and out |
| Plateau and tarn | 740 to 770 m | 300 m across | land by the tarn |
| Back face | 770 m to the sea | about 2 km | the dive |

The collar is a band from about 550 to 700 m round the summit block only.
It never lifts, and it turns slowly. The sky above it keeps its own hour
(gold hour by default) whatever the land's clock says.

Two fantasy touches and no more: the collar's fixed, turning cloud with
its own sky, and the ruined stair. The tarn's look stays natural; the
hidden door that goes in it later is not this loop's work.

## Ceiling

`CEILING_OVER` (`scripts/sky_plane.gd`) and the presets' `ceiling`
(`scripts/flight_weight.gd`) rise so that: off and light reach about
1,000 m, medium about 950, heavy about 880. The thin-air band above the
old 215 m ceiling keeps its shape; flight below it stays unchanged to the
digit, as the ceiling round proved (its driver is the reference).

## Lanes

Each lane is one agent in its own worktree on `lane/<part>`, branched from
the loop's branch. Each keeps its code in its own new file, keeps edits to
shared files small and additive, proves its part on its own with a
throwaway driver and a still, and ends its commit with **Notes for
merge**. Lane commits: `ITER(peak): lane <part>: <task>`.

- **stamp** (Opus). The massif as an overlay in the land-field wrapper
  (`scripts/endless/land_field.gd`: `sample`, the short-circuit check in
  `height`, `shape`, and an apply step in `build_chunk`, the same pattern
  as ponds and splits). A profile built from a centre, a facing and the
  table above: horseshoe approach ramp, wall with a couloir slot, crest
  with tower bases, summit block, plateau bowl, back face. Placed through
  `LayoutOverrides.xform("peak/massif", coded)`. A cheap bounding reject
  so chunks outside the footprint pay one distance check. Proof: height
  queries, chunk mesh and collision agree along every stretch; a driver
  lands on the plateau rim and on a foot meadow; chunk build time near
  the Peak against far from it, both numbers in the commit.
- **collar** (Sonnet). A localized cloud override in the march field
  (`scripts/endless/endless_clouds.gd`, `shaders/endless_cloud_march.glsl`):
  a ring of dense cloud at a centre, radius and height band, turning
  slowly, immune to `--cloud-cover`. Inside it visibility drops to tens of
  metres. A haze height term in the land haze (`scripts/endless/
  endless_look.gd`) so a summit at 800 m reads from 5 km while the land
  below hazes as today. Proof: stills at a fixed test position from 5 km
  and from inside, with and without the override.
- **lift** (Opus). An air function for the main scene's plane step
  (`studies/endless_flight.gd` passes `Callable()` today; `scripts/
  sky_plane.gd` reads `wind` and `thermal` from it). A lift volume along a
  path with a radius: inside it the plane gains height faster than it can
  on its own; outside it, nothing. `manual_landing.gd` `calmed()` damps
  upward wind near the ground, so a slot climbed close to rock must keep
  its lift; tune or bypass with a reason. Proof: a driver climbs a test
  column with and without the lift, the two climb rates in the commit,
  and the low-band script from the ceiling round unchanged.
- **lines** (Opus). A place line: a named route of gates (reusing
  `scripts/endless/rival_course.gd`'s gate shape and `rival_race.gd`'s
  pass test), a start and a finish, a timed record in the pilot book
  (`best()` with a `LOWER_WINS` entry per route), a logbook entry under
  the place, and a HUD moment at the finish that uses the landing-card
  style. Gates are placed through handles `peak/route/<name>/gate/<n>`.
  Proof: a driver flies a test route and the book records its time and
  improves it on a faster pass.

## Trunk

The four lanes are merged (stamp `077fcc2d`, lift `3773003c`, lines
`803fe1b8`, collar `e2ed0e02`; merged at `d99d9ab6`, smoke passes with
all four on and with `--peak=0 --lift=0 --lines=0 --collar=0`). Each
lane's commit message ends with **Notes for merge** that say how the
trunk uses it: `PeakMassif` helpers (`tarn()`, `couloir()`,
`tower_bases()`, `summit()`, `world(a, v)`, `STRETCHES`, placement
`peak/massif`, test spot `TEST_AT` to replace); `air_lift.add(name,
points, radius, strength)`; `PlaceLines` `PLACES`/`LINES` (delete the
"trial" line); `look.clouds.set_collar(centre, radius, lo, hi)`.

What the stamp lane left open, and the trunk must close: no stills were
taken of the massif; the plateau landing failed because above about
186 m over the sea `LandStream` builds no level-0 chunks and so no
colliders (the plane never touched the plateau); chunk builds near the
Peak cost 30 to 40 ms each in GDScript; the massif is on in every world
profile; rivers stop where it lifts the land; other placers (arches,
rocks, trees) may stand things on it.

In order, one task per iteration:

1. Detail at height, first because nothing above 186 m can be landed on
   or skimmed until it is done: `LandStream._distance` measured from the
   chunk's own ground (a cached min height per chunk, or one field sample
   at the chunk's nearest point), not from the sea, so the plateau and
   the wall get level-0 chunks and colliders when the plane is near them.
   Keep the edit in `land_stream.gd` minimal; a rendering session may
   land changes there, so check `git log main -- scripts/endless/
   land_stream.gd` and rebase if needed. Prove: the plateau landing the
   stamp lane could not make (by real input, graded), rays on the wall
   and the crest agree with `height()`, and the chunk-cost table again.
   Stills of the massif from the foot and from the air, judged against
   the Shape section.
2. Place the massif from the start meadow (about 5 km, horseshoe open to
   the meadow) and turn the start so it faces the summit, with the gold
   door tower off to one side; replace `TEST_AT`. Raise the ceiling. Keep
   other placers off the massif. Still from the meadow: the Peak and the
   door both read.
3. Sculpt. The first stills (`scratch/peak/detail/`, iteration 1) show a
   massif that stands and has detail everywhere but reads as a crater:
   a flat-topped rim of even height, a plain box for the summit block, a
   square-cut trench for the couloir, a flat white floor between two
   straight parallel ridges for the glacier, mesa-like arms from the
   back. Rework the profile in `peak_massif.gd` until, judged from the
   start meadow and from the air, it reads as the Shape section says: one
   head that stands clearly above the rim, a crest that rises and falls
   between the tower bases so it reads as a ridge and not a wall top,
   buttresses and gullies on the wall, the couloir a gully that tapers
   and bends rather than a slot with square walls, the glacier a valley
   between moraine ridges that curve with it, with crevasse bands across
   it, and arms that fall away as ridges, not mesas. Noise on top of the
   profile is fine where it stays inside the profile's envelope; the
   helpers (`tarn()`, `couloir()`, `tower_bases()`, `summit()`,
   `STRETCHES`) must keep returning the right spots afterwards, and the
   chunk-against-`height()` agreement and the plateau landing must still
   pass. Stills before and after from the same spots. Colour is not this
   step: the white above the glacier is the ground shader's and the snow
   line is dressing work.
4. The tarn: a pond entry with a forced level in the plateau bowl, skipping
   the pond site rules; the shore meadow landable; `place/peak` on
   landing; the landing card at the summit.
5. The couloir route: lift in the slot, its gates, its record, the stair
   from the ruin kit along the approach and up the slot, the traffic plane
   flying it.
6. The towers traverse and the seaward face: spires on the crest from the
   sea-stack kit, gates and records for both routes.
7. Dressing: boulder field from the rock kit, seracs on the icefall, ice
   on the glacier and a snow line above about 500 m in the ground shader.
8. The sky above the collar: the land's hour below, the collar's own hour
   above, blended by eye height through the band. Brighten the collar
   from below if it still reads tan against the field clouds.
9. Cost: the chunk-build numbers near the Peak against far from it, the
   straight-up check per preset, and if streaming shows holes near the
   Peak, the massif's profile ported into the C++ field with the
   GDScript mirror kept.
10. Final: smoke checks, a driver through each route, stills from the
   meadow, the glacier, the couloir, above the collar and the tarn; then
   the handoff.

## Proof, every iteration

- `python tools/smoke.py studies/endless_flight.tscn` passes with 0 errors.
- Throwaway drivers in `scratch/` (`python tools/drive.py --api`), left
  uncommitted; the commit quotes their numbers.
- Rendered stills with `tools/shot.py` or a driver's `shot_at`, one window
  at a time, every windowed run with `-- --no-title`; looked at by the
  agent before the commit, listed under Look at.
- Headless-only limits are reported as unverified, never retried with a
  renderer. The full suite is not run; tests touched by the change are,
  and breaks are listed.

## Not in this loop

The hidden door in the tarn (needs a third region). A map or atlas view.
Any change to the near-miss chain, rivals, the shop or the doors world's
transition. Making the whole wilderness steeper: the stamp is one feature,
the noise stays as it is.
