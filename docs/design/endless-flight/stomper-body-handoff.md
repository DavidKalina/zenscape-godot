# The stomper's new body and the small heads: handoff

The stomper walks the real Amberlands in a new headless stone body, and 84 heads
of its own size lie in the land with the 39 big ruins, rebuilt in the same
stone. Trail: `git log --grep='^ITER(stomper-body)'`. Spec:
`spec-stomper-body.md`. The stomper's first handoff is `stomper-handoff.md`; its
list of what the body does still stands, except where this one changes it.

Play, from `/Users/davidkalina/Documents/Projects/zenscape-stomper-body`:

    python3 tools/play.py --no-pull studies/endless_flight.tscn -- --no-title --pilot-file=/tmp/stomper.json

Fly through the hall. The stomper is left of dead ahead on the way out, and an
`elder_55_awake` lies by the first big mourner, so the hall shows both sizes.

## Built

- **Body:** `assets/models/stomper_body.glb`, 23,672 triangles, one skinned mesh
  on the old skeleton and clips. It is a waisted torso on legs, with arms, a
  snapped neck, no head, and nothing of the archive's design. Source:
  `art/blender/giant_ruins/stomper_body_build.py`. Baked maps:
  `assets/textures/giants/stomper_{normal,ao}.png`, 4.4 MB.
- **Stone:** `shaders/stomper_stone.gdshader`, the ruins' stone with the land's
  bounce. Blotches are read from the rest pose, kept in vertex colour, so they
  do not slide on a walking limb.
- **Capsules:** the same 17 in `stomper_solid.gd`, refit to the new shape. The
  mesh stands past them by at most 8.8 m, at the chest's flanks; 8% of vertices
  stand over 2 m past.
- **Small heads:** `small_heads.py` carves three 55 m faces in five poses:
  `elder_55_awake`, `mourner_55_bowed`, `mourner_55_on_its_cheek`,
  `warden_55_gazing`, `warden_55_on_its_ear`. 84 lie in the land
  (`giant_swells.gd`, `_small_heads`), through the same ruin path, with no nodes.
- **Sockets:** only `elder_55`'s bore is hollow, 16 x 9 m, sized with
  `WorldScale.opening(8)` at plane 2. The other two are solid, with blind sockets.
- **Big ruins:** the 39 are rebuilt in the new `weather()`. The big heads now
  take hand-placed losses off the face instead of random ones that took noses.

## Checks, this last pass

All through the real play loop on the real far side (`doors._swap(1)`), launched
at 50 m/s. Drivers are throwaway, in `scratch/`.

| Check | Result |
| --- | --- |
| Smoke | PASS, 400 frames, 0 errors, 1/1 |
| Under the crotch, stick held, about 16 m up, along the walk both ways | 8 runs. All 6 that got under the hips passed clean, closest skin 7.8-19.1 m, least room under the hips 15-35 m. The other 2 never got under: the land falls away hard there, the plane came in at hip height and hit the front of the hips, a crash at the skin. |
| Under a lifted foot, head on, lifted 19-23 m | 8 runs under the sole. 7 clean, closest skin 1.9-7.8 m. 1 crash, 0.9 m over the land, 1.1 m off that foot: it came down on the plane. |
| Into a limb, stick let go | 8 aimed. 5 hit, each stopped 1.3-1.9 m off a capsule and flew on 30-73 m clear: chest, forearm, and the runs aimed at waist, shin and foot, which met the chest, a foot and a thigh first. The runs at thigh, hand and upper arm missed a limb that had moved (13, 4 and 50 m), none inside a capsule. |
| Grass through a footfall | Seen from 170 m through the play camera, before, 0.5 s and 4 s after. It presses flat and stays, with no hole. At 4 s it is still pressed, as the wake means it to be. The 70 s hold was not watched to its end. |
| Flats, 200 m strip 50 m wide within 3 m of level, over the 17 km square | Nearest strip: all land median 180 m, p95 532, max 1471. Within 500 m of a ruin median 158, p95 474, max 1012. Old build (9bd42b3e): 180, 532, 1471, and near a ruin 150, 461, 1012 on far fewer cells (673 against 1634). Strips 11,088 against 11,183. The small heads take less than 1% and the worst spot has not moved. |
| Cost (the iteration before) | Frame time within noise of the old build on this Mac, with another agent's load on it. All 123 ruins on screen 54-75 k primitives, under 0.5 ms. |

Stills:
`scratch/look/fall/before.png`, `a_0_1s.png`, `b_0_5s.png`, `c_1_5s.png`,
`d_4s.png` (a footfall); `scratch/look/c/front.png`, `legs.png`, `hip.png`,
`knee.png` (the body); `scratch/levels/mouth.png`, `small_1..5.png` (the levels).

Not run: the full suite (prototype rules), a PC, the walk watched as a moving
clip, and any flight by hand. The check counts its
crash causes by where the plane last was, since the game does not keep one.

## Stood in

- The walk is the old `stomp` clip on the old bones, unchanged.
- The swat is still not built.
- Head-to-body match is by size and stone only. Nothing puts a small head on a
  body or says one came from it.

## Open

- **The deep crouch.** Flagged for you, not reauthored. At each footfall the hips'
  underside sinks to 29-33 m over the land, and it rises to 51-54 m mid stride.
  The body reads as lunging, knee far forward, more than as striding upright
  (`scratch/stomper_shots/walk_sheet.png`, shot on the body before the last
  knee fix; the clip is the same).
- **The lifted foot's sole** reads as flat black from below
  (`scratch/look/fall/before.png`). The cause was not looked at.
- **Up close** the body's stone softens: at about 170 m the low mesh and
  bake read pillowy at the foot and knee, against the crisp Blender stills
  (`scratch/look/fall/d_4s.png`).
- **The shove.** A footfall within 520 m knocks the plane up to 34 m/s, which can
  throw it into the hips or the ground. Still your call (below).
- **A foot swings at 48-57 m/s,** faster than the plane's 50, so a plane chasing
  one from behind ends up under it as it lands. Whether that is fair is for play.
- The small heads still read softer in the game than in Blender at a hazy hour;
  the normal map carries the hard edges.
- From the first handoff, unchanged: the smoke failure twice in about 35 runs
  (it did not come back here), the engine's "BUG, indexing did not unpair"
  line, and the saw-tooth edge at low sun. The body's place still depends on play.
- Grass beyond 4 s, and the far LODs seen on their own, were not looked at.
- The worktree `../zenscape-stomper-old` (9bd42b3e) was meant to go, but its
  removal was refused here (irreversible). It holds nothing but the old build
  and a copy of `scratch/flats.gd`:
  `git worktree remove --force ../zenscape-stomper-old`.

## If the giants change size

Nothing below scales by itself.

**Would break outright:**

- `stomper.gd` `HEIGHT` 250 sets the body's scale, but `stomper_solid.gd`'s capsule
  tables are metres on a 250 m body, divided by `size`, and their radii are used as
  they stand. Change `HEIGHT` alone and the capsules no longer fit the mesh.
  The fix is to scale those tables by `HEIGHT/250`.
- `stomper_shadow.gd` `LONGEST` 1800, `ROOM` 200, `UP` 900: the shadow's reach.
- The dressing's `REST_SPAN` 290 (metres in vertex colour) must hold the body.
- The 55 m in `small_heads.py` and the claim "sits on its shoulders": a new body
  means a new head level. The faces are carved in true metres, so they want
  recarving rather than scaling.
- `elder_55`'s bore (16 x 9 m) follows the plane, not the giant. A smaller head
  may not hold it.

**Would go wrong quietly:**

- Flying: hips' underside 29-54 m over the land, sole lifted about 19-27 m. At a
  third of the size neither passage exists. Those two checks need flying again.
- `stomper.gd`: `SOLE` 22, `SWING_CLEAR` 8, `RUIN_CLEAR` 110, `DOOR_CLEAR` 220,
  `SINK_RATE` 16. `START_OFF` is a place, not a size.
- Pace: the clip's two 92 m steps in 16 s give 11.6 m/s, and 17.7 min a lap of the
  12.3 km ring. `stomper_route.gd` `EASY` 28, `HARD` 75, `CELL` 80, `RADIUS_NEAR`
  300 fit that stride.
- `stomper_fall.gd`: `REACH` 1500, `FRONT` 220, `FELT_REACH` 2200, `SHOVE_REACH`
  520, `SHOVE` 34, `SKIRT_RUN` 300.
- `stomper_wake.gd`: `STEP` 46, `HIP` 40, `STEP_EVERY` 8, `FLAT_REACH` 150,
  `HANG_ROUND` 130, `FLAT_FRONT` 220.
- `giant_swells.gd`: `SMALL_CELL` 800, `SMALL_SPACE` 260, `FIRST_SMALL`, `SPACE`
  650, and each ruin's `ground`, `inside`, stride and grid.
- The masonry's metres (`stomper_body_build.py`, `CALM` 1.7, body stone 1.5; heads
  stone by size). Scaling the body in the game scales its courses too, so they stop
  matching the ruins'.
- `stomper_stone.gdshader`'s blotches, placed in the rest pose's metres.
- Rebuilding at a new size also means the bake and its 4.14 m grid, and the waist,
  elbows, knees and thumbs have to survive it again.

## Your calls

- The deep crouch: keep it or reauthor the clip.
- The shove: should a footfall be able to throw the plane into the hips?
- Being stepped on is a crash today. Keep it?
- From the first handoff: clouds cut by the body, and whether a footfall rocks a
  parked plane.

## Model budget (`docs/art/model-budget.md`)

| Trick | Used | Savings |
| --- | --- | --- |
| Sculpt high, bake low | Yes, body and heads | Body 2.2 M to 23.7 k triangles. Small heads 240-330 k to 6.4-8.6 k. Unbaked, the body alone would draw more than the whole cruise view (1.43 M). |
| Import LODs | Yes | Each small pose has 3-5 levels, down to 134-890 triangles. All 123 ruins draw 54-75 k primitives on screen where their meshes sum to 630 k: about 90% off, under 0.5 ms. No hand-built far mesh is needed. |
| Silhouette geometry | Yes | Lost blocks, chest break and worn flank are in the low mesh. It costs triangles rather than saving them, and it is what keeps the outline at 4.14 m. |
| Rigid parts on bones | Yes, as weights | Each vertex is rigid in its mass, ramped at the joints, on one mesh. Separate meshes would add nodes against the budget of 13 (the glb keeps 23 nodes, 1 mesh). |
| Instancing shared poses (not on the list) | Yes | 84 heads from 5 meshes, no nodes. About 540 k triangles at 6.4 k each would be 37 k in memory across the five. |
| Parallax depth | No | Not tried, not estimated. |
| Vertex-colour grime | No | The AO map does it, and the colour holds the rest pose. |

Maps: the small heads add 2.4 MB of png; the giants' folder went from 35.4 to
30.8 MB, as the big rebakes compress smaller.
