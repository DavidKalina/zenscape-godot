# Handoff: the curtain kind and its waterfall (ITER(wild-kit), lane falls)

Spec: `spec-wild-kit-falls.md`. Branch `lane/wk-falls`, five rounds (the
trail: `git log --grep='^ITER(wild-kit): lane falls'`). Not flown by the
user yet.

## What's built

- **The kind** `curtain` (`scripts/endless/kinds/curtain.gd`): a sheet's
  shape (`sheet_of`: lip, out, drop, half, throw, pool, the cave mouth's
  `open`), its land, the space behind and the punch. The skin says what
  falls (SKINS: `waterfall`). A sand fall or an ice curtain is a new skin.
- **The land** (`curtain_land.gd`, a layer over `land_field.gd` like the
  ponds): an alcove cut 48 m back to a cliff face, the lip 61.5 m over the
  foot, a stream fanning from a spring tarn on the ridge to the lip, a
  plunge pool (r 14) and an outflow to the river. It only lowers the land.
  Site `wild/river_falls` (1940, -25, heading 100 in the launch flag's turn, foot y -21.5),
  `clear` 125 m.
- **The cave** (`curtain_cave.gd`): from behind the sheet through the hill
  on a 60 m bend to a gully down its south flank. Openings
  `WorldScale.opening(TOY_CAVE 11)` wide, `opening(TOY_CAVE_TALL 8)` tall.
  The field has it as a trench (floor and walls), the chunks draw the hill
  whole with holes in its two faces, and the piece draws the tube and the
  faces round its mouths in the land's rock look. A StaticBody on layer 1
  (the near misses' rays) and a BoxSolid over the roof (the crash test).
- **The waterfall** (`world/wilderness/waterfall.gd`,
  `shaders/curtain_fall.gdshader`): three strands of the falls' ring mesh,
  teal glass at the lip under a white crest, whitening in streaks down the
  fall, thinned over the cave mouth; foam on the pool; mist at the foot,
  kept off the middle.
- **The punch** (`curtain_punch.gd`): no collider; crossing the thrown
  sheet wets the screen (`WET` 0.8), splashes and throws a spray burst. The
  roar (water-bed.wav pitched to 0.55, on the bore's bus) drops to 0.45 gain
  and 0.6 pitch inside the cave.

## Play

```
cd /Users/davidkalina/Documents/Projects/zenscape-wk-falls && python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/wild-kit-pilot.json --at=2350,30 --heading=-82 --alt=40
```

410 m east of the falls, facing them. Aim for the sheet's middle, low, then
bank gently left inside. The exit is a short grassy gully, so don't drop low
there.

## Proof

- Smoke: `python3 tools/smoke.py studies/endless_flight.tscn` PASS (also
  with `--at=2150,10 --alt=40`).
- Flown through the real loop (`scratch/falls/fly_cave.gd`, Boost, 55 m/s):
  in through the sheet, through the cave and out. Least wing room 4.8 m a
  side, roof 7.2 m, floor 8.0 m, no crash.
- Stills (in the worktree, git-ignored), `scratch/falls/proof/`:
  `valley.png` and `near.png` (the approach), `punch_before.png` (the plane
  just short of the sheet), `cave_before.png` (from the pool),
  `cave_inside.png`, `punch_+12.png` (in the cave, the screen wet),
  `cave_exit.png` and `cave_exit_near.png`.

## Model budget (`docs/art/model-budget.md`)

What it costs: the cave is 1488 triangles in one mesh (the tube 26 rings,
each mouth face 4 bands) plus a concave collider of the same faces and a
BoxSolid of 1366 columns. It builds on the main thread when the site
streams in: about 35-45 ms (the roof's solid ~19 ms, the faces' hill
samples most of the rest, ~10 us each), a one-off hitch each time. The
sheet is 3 strands x 1104 triangles, the foam a quad and the mist 22
quads in a MultiMesh: 6 draw calls in all, plus the
cave's shadow. Per frame there's one script (the punch test within 260 m:
one affine inverse and a few dot products) and one looping 3D voice. The
burst is 106 CPU particles, made on the first punch. Frame time wasn't
measured, because other agents were rendering on the Mac; the numbers here
are estimates from the work above.

- **Vertex-colour grime: applies, the best next step.** The cave already
  carries vertex colours, all one rock tone. Darkening them with depth
  (distance from the nearer mouth) and in the floor-wall crease would make
  the tube read deeper, and the mouth read darker through the veil. It
  costs no triangles and no frame time.
- **Import LODs / visibility ranges: applies, small saving.** The tube is
  hidden inside the hill from afar, so a `visibility_range_end` of about
  600 m on the cave saves ~1.5k triangles and a draw call at a distance.
  The same on the mist and the foam saves 2 draw calls. Each is under
  ~0.02 ms of GPU time. The sheet is the landmark, so keep it at full
  detail.
- **Silhouette geometry: could apply.** The arch rims are a smooth section
  (12 segments). Chips on the rims would add ~100 triangles. Not done.
- **Sculpt high, bake low; parallax depth: don't apply.** The cave is
  procedural, and its detail comes from the rock shader and RockShape's
  carved shape. Parallax on full-screen cave walls costs fragments for
  little gain.
- **Rigid parts on bones: doesn't apply.** Nothing is skinned.

## Open

- **The roar is stood in:** band noise pitched down. A real waterfall
  recording is an asset ask. Nothing about the sound has been heard, only
  set by its numbers.
- **The spray burst is hard to see from the chase camera,** behind the
  sheet's white streaks. The wet screen carries the punch. `WET` 0.8 is a
  knob.
- **A thin blue zigzag strip shows on the cliff screen-right of the
  pool** (`cave_before.png`). The field reads no water there, so it comes
  from the chunks' per-vertex water reads or the ground shader. It is
  likely the same family as the false water strips fixed in round 1 (the
  distance's sign). A `--no-rivers` still would confirm it.
- **Other looks:**
  - dark turf on the tube's floor;
  - tall grass in the exit gully and at the mouths' floors;
  - the land's own cliff triangles stay jagged beside the exit face;
  - the sheet is a clean rectangle from the valley (ragged sides would
    help);
  - from behind, the thinned sheet reads like icicles in a still.
- **The build hitch:** the falls build on the main thread as the site
  streams in (~35-45 ms, see above), and again each time it streams back.
  Keeping the built piece when it streams out, or building the solid's
  columns off the thread, would remove it.
- **No committed tests.** The suite wasn't run. No test names these
  scripts.
