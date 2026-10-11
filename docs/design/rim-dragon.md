# Rim dragon (experiment)

A giant dragon from the cloud sea, after the Ruined Kingdom dragon in Mario
Odyssey. Round 1 gripped the isle's rim and blew gales; the user found it
"animatronic" (no body) and out of the game's style. Round 2 gave it a full
body and made it fly well. Round 3 rebuilds it as a wyvern after Smaug and
makes it ride the air. Round 4 brings the attack back on a far isle: it
clings to the rim and blows gales across it, seen from the aqueduct isle.
Round 5 adds the edge spring: its weight sags the isle, and the snap back
flings the pilot. Round 6 keeps the head out of the isle, rests the chin on
the turf, Odyssey-style, and lets the pilot surf down the tipped isle.
Round 7 moves it onto the ruin motif isles that replaced the old far isles.
Round 8 makes its breath the game's own breeze ribbons, smooths the head and
sends the ride round the other isles. Round 9 fixes swimming in mid-air on the
tipped tarn and makes the held isle walkable.

Branch `study/rim-dragon`. This is a demo round: no tests, no bot sweeps, no
perf pass.

## Round 9: water that tips, a walkable hold

The user's notes on round 8 ("Awesome! ... wow, really cool so far"), two
severe bugs: on the cloister tarn, after the tilt he was swimming in
mid-air; and not being able to walk while the isle is tipped is still very
frustrating.

### Play

- `./run-rim-dragon.command --dragon-ride` (the cloister tarn), or add
  `--dragon-target=bell_spires`; `--dragon-ride-repeat` for the quick loop.
- The slam tips the isle steep (about 21 to 23° at its peak) for about
  1.5 s. Then it eases back to about 9° by about 3 s after the grip. Walk,
  run and jump there as on the flat. Crouch (or carve) to surf; nothing
  slides you on its own any more.
- Each blast nudges the tilt to about 10 to 12°, and that eases away.
- The tell: just before it lets go, the dragon rears back, jaw clenched,
  and hauls the rim down over 0.85 s (back to about 18°, rubble falling).
  Then it lets go and the isle springs back and flings you, as before.
- The ride's hold on your isle is 8.5 s (it was 6), so it always gets to
  one blast, and you have about 10 s on the walkable tilt.
- `--dragon-walk-check` (headless check): the stick runs the pilot to and
  fro through the hold, and his pace, slope, tip and water are printed.

### Water (scripts/pilot_physics_ground.gd, scripts/kit_isle/motif_isle.gd)

- **Cause.** The pilot's wade and swim depth came from `ground.pools`:
  flat rects with a world `top`, registered at rest. The bed (physics rays)
  tipped with the isle, but the top stayed put. Near the gripped rim the
  bed sank metres under the rest top, so he was "in deep water" and floated
  at the rest top, in mid-air over the sunken tarn.
- **Fix.** A motif isle's pools now carry their `node` and its `rest`
  transform. `_pool_top` reads the rect in the rest frame and returns the
  posed surface's height over the point, for `depth` and `surface` alike.
  Pools without a node (the aqueduct's channel, the motifs' own scenes)
  work as before.
- **Look: the water tips with the basin.** The tarn's mesh, its plane
  collider and the curtain fall are already under the isle's node, so the
  surface tips as a rigid sheet with the isle. The wade/swim test now
  matches that sheet. Level water in a tipped basin would be more correct,
  but it would need a re-cut mesh and spill handling. At the 9° hold it
  reads fine; it is steeper only for the slam's moment and the pull.
- Logged on the hold (cloister tarn, 8.4°): the tarn's posed water at
  y 29.45, and the pilot's ground reads 29.45 (rest top 30.00), 2.28 m
  deep. At the channel's middle it is 32.44 against the rest top's 30.00.
  Placed in the tarn (`--place=60,31,365`), he swims 0.56 to 0.62 m under
  the tipped surface through the slam, the hold, the pull and the snap. In
  every run, no swimming while above water.
- **Other isle-local data checked.** Ground, walls and ledges are physics
  rays on the node's colliders, so they move with it. Live rope decks read
  `bridge.global_transform`, and the bell spires' rest decks are walk boxes
  under the node: they tip with it (round 7's note on them was stale).
  On-foot tokens, birds and flora are under the node. The sky's plane tokens
  stay put: they float in the air and are taken in flight, so they can't
  strand him. Left as is.

### The tilt (scripts/dragon_gale.gd, scripts/sky_dragon.gd)

- **No auto-slide.** Round 6's `RIDE_SLIDE_AUTO` (15°), `_tilt_slide` and
  `_falls_to_dragon` are gone. The motor keeps its own `slide_auto` (44°).
- **Steep, then ease back.** The hold's goal is set by angle (`_sag_for`):
  `SLAM_TIP` 17° (it overshoots to about 23° on the slam's kick), held
  `STEEP_FOR` 1.1 s, eased over `EASE_BACK` 1.6 s to `HOLD_TIP` 9°. That is
  under the motor's crouch surf (`SLIDE_FROM` 10°) and far under its slowing
  (`SLOPE_SLOW` 22°).
- **Blasts nudge.** Each adds `BLAST_TIP` 2.5° (at most 4°), which eases
  away at 0.9/s.
- **The pull.** `gale.pull_down()` ramps the goal to `PULL_TIP` 20° over
  `PULL_TIME` 0.85 s on a stiffer spring (w 6.5, ζ 0.75). The groan stops
  under it. The dragon's new "pull" beat (rear back, jaw shut, wings half
  open, crumbling) runs in its place once the hold is up; then `_let_go`. G
  and the treasure still let go at once.
- **Carry.** The ease and the pull are the same per-frame `moved` that
  `PilotMotor.carry` follows. Headless he stays grounded through both, and
  he never left the ground except for the blast's knock and the launch.

### Measured (headless, `--fixed-fps 60`, `--dragon-walk-check`)

- **Pace on the held tilt:** 4.80 m/s (the motor's flat `RUN`) on most
  samples. The rest are turnarounds and the blast's knock. This is on the
  cloister tarn (two loops) and the bell spires.
- **Standing through the slam:** 0 m/s, grounded, on local slopes up to
  14°. No surf.
- **Launches:** cloister tarn 22.0 m/s at 15.8 m from the rim (round 8: 9
  to 29); bell spires 27.0 m/s at 16.5 m. In later `--dragon-ride-repeat`
  loops a blast knocked him to the far side (20 to 26 m from the mouth, by
  the pivot). There the snap doesn't throw him, as before.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r9_hold_0.png`, `r9_hold_1.png`: the cloister tarn on the eased hold (about 9°)
  from the side, the dragon's chin on the rim, the cloister and tarn
  readable and level enough to walk. Command: `--dragon-ride
  --dragon-walk-check --dragon-watch=orbit --dragon-orbit=110
  --dragon-orbit-up=35 --dragon-orbit-far=90 --capture-wait=6
  --capture-seq=2,1.5`.

### Rough

- The steep moment is short (about 1.5 s over 15°). If it wants more drama,
  raise `SLAM_TIP` or `STEEP_FOR`.
- The pull reaches about 18° by the let-go, not the full 20° (the spring
  lags). Launches are still in round 8's range.
- The tarn's surface is tipped, not level. It is visible on the slam and
  the pull.
- No capture of the pull itself; wall-clock capture timing missed it.
- The ride's hold is longer (8.5 s), so a full ride cycle is a few seconds
  longer.
- Not played by hand. Checked from headless logs and two captures. Headless
  import passes. The plain aqueduct isle (no `--dragon`) loads with no
  errors. No test suite run.

## Round 8: ribbon breath, a heavy head, the ride goes round

The user's notes on round 7 (`--dragon-ride` on the cloister tarn): the head
is super janky; it keeps looping over the same island; the air it blows
goes through the island instead of sweeping off the top. Should it use the
eddies we have?

### Play

- `./run-rim-dragon.command --dragon-ride`: it grips your isle (the
  cloister tarn), blows once, lets go (and flings you), then flies off to
  grip another motif isle for 16 s (nearest first, the others in turn,
  gripped on its flank as seen from your isle), then comes back to yours.
  A cycle is about 70 s.
- `--dragon-ride-repeat`: round 5's instant swoop back to the same rim.
- Normal mode goes to the isle left longest since its last attack. An isle
  in the camera's view gets a minute's head start. A headless run with
  `--dragon-attack-every=12 --dragon-cling=12` went bell spires, colonnade
  spine, cloister tarn, sundered gorge.
- `--dragon-cling=<s>` sets how long it holds on outside the ride (checks).

### The breath (scripts/dragon_breath.gd, scripts/dragon_gale.gd)

- **The game's breeze ribbons.** `DragonBreath` extends
  scripts/breeze_ribbons.gd. It is a dedicated instance owned by the
  gale, not a front fed to the isle's own ribbons (those live round the
  aqueduct isle, 400 m off, with 8 slots). It reuses the class's flow,
  look-ahead ground probe, eddies, sweeps, tail and stroke shader. The one
  change to the shared class is that `capacity` is a var.
- **Born in the mouth.** Through the blow, 9 ribbons a second (at full
  envelope) leave the jaw's tip, each on its own way within ±0.26 rad of
  the head's aim, at 19 to 26 m/s. They ride 1.4 to 3.6 m over the floor,
  1.5 to 3 m wide, with 1.2 to 1.8 s tails. That makes strokes 25 to 45 m
  long.
- **The floor is the posed isle.** `gale.air_floor(p)` is the isle's
  shape (dragon_isle_shape.gd, sampled once at rest) seen through the
  isle node's current transform. It is the tipped, sagged, trembling isle,
  solved for the world vertical in three steps. It reads `top_at`: the top
  of anything solid (turf, ruins, bells, trees, rock, water), spread a
  cell either way so a thin wall reads from both sides. The breeze's
  look-ahead (to 1.2 s, about 25 m) lifts a ribbon before a wall. A hard
  floor keeps every new point at least 0.9 m above it.
- **Eddies.** Where the floor under a ribbon falls more than 1.8 m below
  the highest it has just ridden over (behind a wall or ruin), it curls in
  the lee. Behind a tall wall it rolls down into the hollow; behind a low
  one it swirls flat. The breeze's own random eddies are kept but
  tightened to 0.75 to 1.15 s a turn. At 20 m/s the breeze's 3 s turn
  would make a loop 15 m across.
- **Sweeps off the far rim.** Half the ribbons take the breeze's sweep:
  they dive to skim the turf at 1.1 to 1.7 m (the stroke is wide), with
  the skim timed so the lift-off starts at the far rim (`_to_rim`). Past
  the rim, every ribbon's remembered floor sinks at 3 to 7 m/s, so it
  spills down off the edge and out over the cloud sea. It dies 110 m past
  the main land or after 7.5 s.
- **Bolder far off.** The stroke shader is the breeze's, rebuilt at load
  (`_far_shader`) with fog off and the width scaled up with distance (x1
  at 90 m, up to x3). At 390 m from the aqueduct isle it reads as white
  strokes pouring over the isle and curling up off its far side. Before
  this the fog hid it entirely.
- **Plants.** It publishes no `zs_ribbon_*` heads: those 8 slots belong to
  the isle breeze (kit_life's ribbons) and would be overwritten. The
  gale's `zs_blow_*` lanes still thrash the plants along the blast. The
  inhale still uses round 4's streaks drawn into the mouth.

### The head (scripts/sky_dragon.gd)

Measured as the snout's speed and its change of speed against the body,
now in the `--dragon-log` line. Round 7 panting showed 40 to 130 m/s
spikes and jerks of 2,000 to 8,000 m/s², from one-frame pops. Now the
cloister tarn runs at 2 to 20 m/s and under about 400 m/s². Only the slam
reaches about 1,300 m/s² (it is an impact).

- **Root cause: the body didn't tip with the isle.** The tipped turf
  (17 to 23°) rose into the pose's head, so it had to be lifted by up to
  11 m every blow. The clinging body now takes the isle's rotation
  (`BODY_TIP` 1.0): dragon and isle tip as one, and the pose's sink
  drops to about 5 m.
- **The isle from its shape, not rays.** `_floor_gap` measures each probe
  against the shape (turf, plus `solid_at`, the unspread solid tops,
  within 5 m over the head) in the isle's posed frame. It is a smooth
  field rather than collider edges. The chin rest uses it too.
- **Clearance is a goal.** Each frame, a Newton solve from no lift finds
  the smallest neck lift and nod that clear the deepest probes by 0.25 m.
  The applied lift and nod spring to it (critically damped, 12/s) at a
  limited rate (1.2 and 1.8 rad/s). What's left in, the body eases up out
  of (a 6/s spring, at most 6 m). The one-frame body bump is gone.
- **A heavy neck.** Each neck bone and the head may turn at most 1.6 rad/s
  against the body, and must speed up and brake within 7 rad/s². That
  removed the last pops.
- **Other pops fixed:**
  - The chest swell is eased. It switched size between panting and
    breathing and at the let-go, and it carries the neck: a 1 to 1.5 m
    head pop.
  - The heave's phase now carries on through a change of pace.
  - The rest's lift and nod are sprung. The solve jumped as the head came
    down in the recover.
  - The body's turn is eased toward its pose (10/s), and toward the
    flight pose over the let-go.
  - The slam blends over 0.75 s (it was 0.3).
  - The neck is left out of the snapshot blends, so its clearance isn't
    laid on twice.
  - The blow's buzz is quieter and the thrust is softer (rear to -0.5,
    from -0.8).
- Residual sink on the cloister tarn: 0 to 0.5 m panting, about 1 m for a
  moment as the blow thrusts, 1 to 2 m as the isle snaps up under the
  leaving head.

### The launch (round 7's missing "flings" line)

In headless runs on the cloister tarn and the bell spires it fires every
time the pilot stands on the isle (9 to 29 m/s). The likely cause of the
user's run without one: `stands_on` only knew the main land's turf. A
pilot on a ruin's floor or wall top, on a satellite, or hanging from a
lip or ledge (round 7's auto-surf can end in a hang 13 m from the rim) was
neither carried nor launched. He hung in the air while the isle moved.
`stands_on` now also accepts anything solid of the isle under him (its
`top_at`), up to 2.6 m below its top for a hang. So he is carried while he
hangs and flung on the snap. The log line now prints his hold and whether
he counts as on the held isle.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r8_breath_top.png`: high over the cloister tarn, mid-blow. Ribbons pour
  out of the mouth across the tipped isle, rise over the cloister walls,
  and run on over the far satellite and off the rim. Leaves are flung
  along.
- `r8_breath_side.png`: from the side, the ribbons over the tipped turf
  and the far satellite's arch, out over the cloud sea.
- `r8_breath_from_aqueduct.png`: from the aqueduct isle's turf (V look),
  390 m off. White ribbons pour over the isle and curl up off its far
  side.

Commands: `--dragon-ride --dragon-watch=orbit --dragon-orbit=60
--dragon-orbit-up=40 --dragon-orbit-far=75 --capture-wait=9.5
--capture-seq=5,0.6` (top); `--dragon-orbit=100 --dragon-orbit-up=45
--dragon-orbit-far=120 --capture-wait=9 --capture-seq=6,0.7` (side);
`--dragon --dragon-attack --dragon-target=cloister_tarn --no-serpent
--dragon-watch=look --capture-wait=19.5 --capture-seq=5,0.6` (aqueduct).

### Rough

- **Bell spires.** Every way round it is crowded with bell frames (the
  grip scores 8 tall solids where the head works, even with the new
  penalty). The head sits up to 5 m into a bell frame through much of
  the hold. It needs its own grip or a way for the head to rest over the
  frames.
- The shape grid's margin grew to 14 m, which moved the cloister tarn's
  picked grip from (95, 31, 370) to (39, 32, 371). The ride start moved
  with it.
- Lee curls are frequent on the cloister (most ribbons take one). That
  reads well in the top capture but may be busy close up.
- The ribbon wake doesn't bow the plants (the slots are the isle
  breeze's). The zs_blow lanes still do.
- From the aqueduct isle the strokes are fog-free, so they read a little
  brighter than the hazy isle they cross.
- The grab's first frame out of flight still shows one jerk (about
  3,000 m/s²) when it starts from a let-go in `--dragon-ride-repeat`.
- A tall beige column of cloud stands beside the cloister tarn in every
  capture. It is not from the dragon.
- Not played by hand: checked from headless logs (snout metric, sink,
  launches, target order) and three captures. test_breeze_ribbons and
  test_motif_sky pass headless. The import and the plain isle without
  `--dragon` load with no errors.

## Round 7: the motif isles

The merge of `consolidate/motif-sky` took the old far isles out of the
aqueduct sky (the import failed on `IsleSky.ISLES`). The user asked whether
it now goes from island to island on the four ruin motif isles. It does.

### Play

- `./run-rim-dragon.command --dragon-ride`: the pilot starts on foot on the
  motif isle with the best grip (the cloister tarn). He stands on open turf
  about 15 m in from the gripped rim, off the blast's line, facing it.
- `--dragon-target=bell_spires|cloister_tarn|sundered_gorge|colonnade_spine`
  picks the isle, with `--dragon-ride` or `--dragon-attack`.
- `--dragon --dragon-attack`: it swoops in from the aqueduct isle at once.
  Without `--dragon-attack` it roams and attacks every 60 to 85 s.
- G still makes it let go.
- Headless runs build the motif isles only near the eye. Add
  `--motifs-now` to watch attacks headless (`--dragon-ride` flushes them).

### Targets (studies/aqueduct_isle.gd, scripts/sky_dragon.gd)

- The targets come from the sky's `places()`, whatever motifs it places.
  `DRAGON_TARGETS` is gone. Each isle's record is made the first time the
  dragon asks after the isle stands (`_dragon_isle`). It holds the
  `Motif_<id>` node, a land shape (scripts/dragon_isle_shape.gd), the main
  land's middle and radius, the shape's frame and the pivot.
- **The shape.** Its land is all its outlines, so satellites and spire
  tops count as land. On a 1.5 m grid over the main land (the biggest
  outline), heights come from rays at its main turf only, and an open map
  comes from rays at everything solid. A cell is open when nothing stands
  more than 0.5 m over the turf there (no ruin, bell, tree or water).
- **Choice** (`_choose_target`): a target is skipped if it hasn't stood
  yet, if the pilot is on it, or if it was the last one let go. It must be
  in the camera's view (within 75°, 900 m); failing that, it takes the
  next in turn. `--dragon-ride` takes the isle with the best grip score.
  An attack planned before its isle stood is planned again once it does
  (`_replan_attack`). The motif isles come up a while after the scene.

### The grip (`_best_turn`)

48 ways round the main land are scored. The score is made of:

- open turf along the chin's line, 3 to 16 m in;
- turf near the lip's height out to 11 m in (no ridge rising from it);
- no land under the body beyond the rim, out to 55 m;
- a lip at the wrists' reach either side;
- a rim 10 to 34 m from the middle;
- off the isle, a flank as seen from the camera.

The wrists and feet are now found on lines 8.5 m and 2.8 m either side of
the grip, marched out to the real lip, rather than at fixed angles.
Picked: cloister tarn 95 to 100% open, flat; bell spires 62 to 76% open;
the gorge 100% open with a 0.8 m rise; the colonnade spine 100% open but a
ridge of 8 m.

### The sag (scripts/dragon_gale.gd)

- **One node, a pivot.** A placed motif isle's node stands at the world's
  origin. Under it are its art (land, rock, keel, ruins, kit pieces,
  bells, rope bridges, water), its flora and its life (birds, butterflies,
  on-foot tokens). So the gale poses that node. It now tips about a
  pivot, the main land's middle, rather than the node's origin. Its
  shape's frame is passed in, so `stands_on` and the debris spawn read the
  land right. The colliders (turf, rock, ruin boxes, tarn water) are its
  children and move with it.
- **The satellites ride along**, rigid with the mother isle, and so do the
  rope bridges between them. Nothing stretches and nothing is left
  floating. The isle's far satellites rise as its near rim sinks, like a
  raft tipping. This was the simplest choice that doesn't look broken.
- **Round 6's angles kept.** The motif rims are 24 to 33 m from the pivot
  (hills_ne's was 14 m). At round 6's sag they tipped only 8 to 12°. The
  sag, kick, blasts and groan are now scaled by the rim's distance over
  14 m (at most 2.5x). They tip 17 to 20° held, as in round 6. The snap's
  rates are divided by the square root of that scale, so a big isle
  springs back a little slower. Launches are logged at 14 to 25 m/s
  (hills_ne: 15).
- **Birds.** On the slam the isle's own songbirds flush off their perches
  (kit_birds `flush`) and the sky's gulls over it stir.

### Head and chin

- Head probes clear ruin colliders too. A solid top up to 5 m above the
  probe counts; an arch far overhead does not.
- The dragon's turf rays skip the isle's other lands while it holds on.
  Without that, on the bell spires a spire's top turf read as ground, and
  the head was lifted 30 m onto it.
- Headless, the chin lies flush (0.00 m miss) on the cloister tarn and the
  bell spires through the pant. It never sinks after the lift on any of
  the four.

### Which work

- **Cloister tarn: best.** Open, level turf at the grip, a clear view from
  the aqueduct isle, the ruins and satellites tipping with it. Default
  for the ride.
- **Bell spires: good.** It is crowded, so the grip is 62 to 76% open. The
  pilot on the tipped turf surfs off the rim on his own (17° there) unless
  he steers. Seen from the aqueduct isle, the rune serpent often crosses
  the view.
- **Sundered gorge: fair.** The turf falls away behind the chin into the
  gorge, so the chin rests on its back edge (logged miss up to 6 m at the
  snout). It reads as the head lying on the lip.
- **Colonnade spine: awkward.** Every side climbs to the spine's ridge, so
  the chin can't lie flush (miss 3 to 9 m). The head is held up on the
  slope by the lift, and launches cap at 32 m/s.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r7_sag_cloister.png`: the cloister tarn tipped toward the dragon from
  the side. The cloister walls, the colonnade of stumps, the satellites and
  rope bridges all lean with it.
- `r7_chin_cloister.png`: close, the pant. The lower jaw lies on the tipped
  turf, the head lifted off it.
- `r7_from_aqueduct_cloister.png`: from the aqueduct isle's turf (V look),
  mid-blast on the cloister tarn, about 390 m off and hazy.

Commands: `--dragon-ride --dragon-target=cloister_tarn --dragon-watch=orbit
--dragon-orbit=100 --dragon-orbit-up=35 --dragon-orbit-far=110
--capture-wait=6` (sag), the same with `--dragon-orbit=125
--dragon-orbit-up=8 --dragon-orbit-far=24 --capture-wait=5.5` (chin), and
`--dragon --dragon-attack --dragon-target=cloister_tarn --no-serpent
--dragon-watch=look --capture-wait=17` (from the aqueduct isle).

### Rough

- The pilot is only carried on the main land. He is not carried on a
  satellite or a spire top (`ground_at` covers the main land only).
- Walk and wade data stays at rest while the isle tips: the tarn's wade
  pools (`ground.pools`) and the bell spires' rope-bridge rest decks
  (deck_ground). Plane tokens in the sky's collectibles don't move either.
  Perched songbirds are flushed on the slam, so they don't hang in the air.
- At 350 to 450 m the dragon is small and hazy from the aqueduct isle;
  V's look camera helps.
- The colonnade spine has no level rim; it wants its own grip rule (e.g.
  one end of the spine) if it is kept as a target.
- Not played by hand; checked from headless logs and three captures.
  test_motif_sky.gd and test_aqueduct_isle_sky.gd pass headless. The plain
  isle without `--dragon` loads with no errors (the dragon code only runs
  with the flag).

## Round 6: chin on the turf, surfing the tilt

The user's notes on round 5: the head clips into the isle a lot. Let it
rest flush on the edge, as in Mario Odyssey. And the tilted isle should be
a slope the pilot can slide down, as on any other slope.

### Play

- `./run-rim-dragon.command --dragon-ride`, as in round 5. While it pants
  the chin lies on the turf about 7 m inside the rim. Crouch (C, Shift or
  LT) on the tipped isle to surf down toward it. On turf that falls toward
  the dragon at 15° or more, he surfs on his own.
- `--dragon-ride-gem` keeps the treasure. It now lies at the front of the
  mouth, in reach of a pilot pressed up against the chin.
- `--dragon-target=meadow_south|grove_east` as before. All three were run.
- The `--dragon-log` line now also prints the pilot's move, the slope under
  him, how deep the head would have sunk without the fix and how deep it
  is with it, the rest weight and the isle's tip.

### Head, jaw, neck and thumbs (scripts/sky_dragon.gd)

- **Probes.** About 20 points on the mesh's underside are measured off
  rim_dragon_c.glb and pinned to their bones: the jaw's floor and sides,
  the snout, the head's underside, the neck's underside (neck.1 to
  neck.3) and each thumb claw's tip, middle and wrist. The isle's surface
  under each comes from a vertical ray at the isle's turf collider (or the
  rock too, for the neck), so it is the isle as posed this frame, sagged
  and tipped. Trees are ignored.
- **Never in it.** Every frame of the grab, the hold and the let-go, after
  the blend and after the isle's move, the deepest probe is lifted clear
  (`_clear_turf`). The neck bends up (shared down its bones) or the head
  nods, whichever moves that probe more. It takes up to six Newton steps.
  If it is still sunk, the whole body is bumped up. This covers the isle
  springing up under the neck on the let-go. Logged on all three targets
  through the sag, the blows and the snap: unfixed, the head would sink up
  to about 14 m (the blow's thrust on the tipped isle). Fixed, 0.00 m.
- **Resting.** Between blasts (the pant, the end of the settle, the second
  half of the recover) `_rest_w` blends to 1 over about 0.6 s. A two-unknown
  Newton solve (neck lift and head nod, warm-started each frame) puts the
  jaw's floor flush on the turf, back and front, 4 cm over it. Logged miss:
  0.00 m. The jaw's own opening sits on top of that, so the lower jaw lies
  still and the head bobs up off it to pant (the pant jaw is smaller while
  resting). Glances shrink to small turns of the head where it lies. The
  inhale lifts it off at 3.2/s.
- **Neck.** Its underside is kept over the turf and the lip. A neck probe
  more than 3 m under the turf is taken to be under the lip's overhang,
  beside the cliff (the root hangs there), not in the rock.
- **Thumbs.** After the wrist's reach, the thumb claw's tip is moved onto
  the turf 0.9 m inside the lip, using two more reaches shifted by its miss.
  Then tip, claw and wrist are lifted over the top if any is still in it.
- **Chin collider.** While it clings, a box on the lower jaw (layer 1)
  stops the pilot. He surfs into the chin rather than through it, and he
  can reach the gem from there. The blast's line-of-sight ray ignores it.

### The slide (scripts/dragon_gale.gd, scripts/sky_dragon.gd)

- **Why it didn't slide.** The motor already read the tilt: its ground
  rays hit the moved colliders, and the log showed 10 to 13° at the start
  spot under the sag (4° at rest). But the tip was only about 14°, just over
  the crouch surf's 10° (SLIDE_FROM) and far under the 44° at which he
  surfs on his own (SLIDE_AUTO). The hills isle's own bumps then took it
  under 6° locally. Crouched, he slid 1.2 m into a hollow and stopped.
- **More tip.** `SAG_DROP` is 0.12 (it was 0.3): less of the sag drops the
  isle whole and more of it tips it. It is now about 17 to 22° held (24° on
  the slam), with the same sag. The launch still works: hills_ne flings
  him at 15 m/s 9 m from the rim. grove_east, a smaller isle, tips further
  and hits the 32 m/s cap close to the rim.
- **On his own.** While the isle is held and tipped past 0.12 rad, and he
  stands on it on turf that falls toward the gripped rim (within about
  60°), the motor's `slide_auto` drops to 15° (`RIDE_SLIDE_AUTO`). It goes
  back to his own value once he is off that turf or the dragon lets go.
  Steeper turf toward the dragon surfs him on his own. Crouched he surfs
  from 10° as anywhere, and steers across as usual.
- Headless, crouched from the start spot: he surfs off at the grip, about
  8 m to the rim, and catches the lip. Crouched from above the mouth with
  `--dragon-ride-gem`, he surfs down to the mouth and takes the treasure,
  and it lets go.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r6_chin_rest.png`: the pant on hills_ne, from the side above the rim.
  The lower jaw lies on the tipped turf, the head is lifted off it a
  little, the neck arcs over the lip, and a thumb claw is hooked on the
  lip. The pilot is a few metres off.
- `r6_slide.png`, `r6_slide_on.png`: from the pilot's camera, crouched
  just after the grip. He surfs down the tipped turf toward the rim, with
  rubble breaking off and the neck beside him.
- `r6_blow.png`: mid-blast. The jaw sweeps low over the turf without
  sinking in.

Captures use V's orbit, e.g. `--dragon-ride --dragon-watch=orbit
--dragon-orbit=125 --dragon-orbit-up=8 --dragon-orbit-far=22
--capture-wait=5.5`. The capture saves about 2 s after `--capture-wait`
(a frame-time measure runs first). `--at` captures are not reliable here:
in that mode the turf colliders lag the drawn isle, so the head is solved
against a stale isle.

### Rough

- Trees are not probed. The chin can rest through a tree trunk or canopy
  on the turf.
- The fix is a clamp, not a pose. In the blow, the head is lifted by
  bending, so it skims the turf rather than thrusting along it. It reads
  fine at a distance, but the neck's curve changes from frame to frame.
- On the let-go, as the isle snaps up, the body can be bumped up a little
  in one frame.
- Auto-surfing follows the turf's fall line. On hills_ne it often curves
  him away from the mouth and off the rim, where he catches the lip or
  falls. Reaching the mouth takes steering. The default start spot is on
  13 to 17° and does not surf on its own unless crouched.
- The chin collider is a box on the lower jaw only. With the gem on, just
  walking up to the mouth takes it.
- Not played by hand; checked from headless logs and four captures.

## Round 5: the spring launch

The user's ask: the editor's edge spring in the attack. The dragon's weight
drags its edge of the isle down; let go, the isle snaps back and springs
the pilot into the air.

### Play

- `./run-rim-dragon.command --dragon-ride`: the pilot starts on foot on
  **hills_ne**, half way out toward the rim and off to one side, facing it.
  The dragon swoops in at once. It grips at about 3.5 s, holds through
  one blast, and lets go at about 19 s. If he is still on the isle, it
  flings him up. Then it swoops straight back for another grip (about 23 s
  a cycle). `--dragon-target=meadow_south|grove_east` picks another isle.
- **G** makes it let go at once (while it clings, any mode).
- The gem is left out of the ride: on an 18 m isle its chin sweeps most of
  the turf, so standing still takes it. `--dragon-ride-gem` keeps it.
- `--dragon-log` now also prints the pilot's feet and the rim's sag.

### What happens (scripts/dragon_gale.gd, scripts/sky_dragon.gd)

- **One pivot.** The far isles are SkyIslets. Their turf, rock, pond,
  trees, flora and colliders are all children of the one `Isle_<name>`
  node (scripts/sky_islets.gd `stand`, aqueduct_isle_sky.gd `_solidify`),
  so posing that node carries everything. The kit isle's sibling problem
  does not apply to these targets.
- **The grip.** A single sag value (metres the gripped rim sits below rest)
  drives the pose. Of it, 30% drops the whole isle and 70% tips it about
  its middle toward the dragon. On the slam the rim sags 4.5 m, kicked
  down on a heavy, soft spring (w 3.2, ζ 0.3), so it drops, bobs and hangs
  there.
- **The hold.** It groans: a slow creak of about ±0.3 m and a small lean.
  Each blast sinks it 0.8 m deeper (7.5 m at most) with a tremble. The
  logged rim sag is about 4.4 to 5.9 m.
- **The release.** This is the editor's `_step_dip` maths as is:
  semi-implicit, 240 Hz substeps, w²(goal - x) - 2ζw v. The rise uses
  DIP_RISE_W 26 and ζ 0.5, then RECOIL_W 40 once past rest. The rates are
  scaled by 0.4 (`SNAP_SCALE`): at the editor's 26 1/s a 5 m sag comes up
  at about 70 m/s and would throw the pilot 100 m. The recoil is damped at
  ζ 0.32 rather than the editor's critical damping, so the isle wobbles a
  few times before it settles. As it comes up through rest, `jolt` throws
  stone, dust and leaves off the turf at its speed, and more rubble breaks
  off the rim.
- **Riding it.** Each frame the gale records its move (`moved`). If the
  pilot stands on the isle's land (checked against its pose before the
  move), `PilotMotor.carry(moved)` takes him along, as the serpent ride
  does. The colliders are the node's StaticBody3D children, moved with it.
  In headless runs he stays grounded through the sag, hold and snap, and
  walks around on the tilted isle.
- **The launch.** He leaves the isle once its upward speed at his feet is
  over 3 m/s and it is slowing faster than his gravity (26). That is the
  moment a real body would leave it. `knock` uses the isle's speed there
  (at most 32 m/s) plus 10% inward, so he lands back on the isle in a
  tumble, and X twirls out as usual. He goes up hardest by the rim: about
  17 to 22 m/s logged 6 to 9 m from it, so about 6 to 9 m up.

### Checked on foot (round 4's open points)

- **Standing and walking on the target isle** work once the isle stands.
  The isles are built on worker threads and stood up over several frames,
  so `--place` onto one at load can land before it exists. The ride calls
  `sky.flush()` first.
- **Knock:** works. The log shows "the gale knocks the pilot", 1.2 to
  10 m from the mouth. Round 4's push in the wider band crashed: it passed
  the deck ground's `slide` a Vector3 where it takes a Vector2. Fixed.
- **Treasure:** works on foot. It was taken (and it let go) just by
  standing near the chin, so it is too easy on a small isle.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r5_sag_side.png`: from the side, the dragon on hills_ne's rim. The isle
  is sagged about 5 m at the grip and tipped toward it.
- `r5_launch.png`: from the pilot's camera, the frame after the snap. He
  tumbles up off the turf, with stone, dust and leaves flung up round him
  and the wing at the edge.

Capture examples: `--dragon-ride --dragon-skip=5 --at=410,64,-152
--look=327,47,-126 --capture=x.png` (side), and `--dragon-ride
--capture-wait=17 --capture-seq=30,0.15 --capture=x.png` (the launch is
in the first frames; timing is wall-clock).

### Rough

- The snap dust is thick: from the pilot's camera the puffs briefly fog
  the view.
- The isle tips about its middle, so its far side rises as the near rim
  sags. A hinge at the far rim may read more like a pulled edge.
- The snap speed is tuned for hills_ne (rim about 14 m from the middle along
  the grip). Smaller isles tip further for the same sag.
- The dragon's body rides the isle's move, but its own basis does not
  tilt with it. Its tail rope still sticks out level in the side capture.
- The launch is upward and slightly inward. He can still tumble off a
  small isle if a blast knocked him near the edge first.
- With his feel untouched, the camera follows him through the sag. There
  is no camera shake on the snap and no sound.
- Not played by hand; tuned from headless logs and two captures.

## Round 4: the attack on a far isle

The user's note on round 3: "Much better. Now, can we work on the attack?
I'd like to see him cling on to one of the other islands in the distance."

### Play

- `./run-rim-dragon.command --dragon-attack`: the dragon starts far out on
  its way in to **hills_ne**, about 270 m east-north-east of the turf. It
  grabs about 6 s in and is on the rim by about 10 s. Stand on the turf's
  east side and look ENE.
- Without the flag it roams as in round 3 and makes its first attack about
  40 s after rising, then another every 60 to 85 s
  (`--dragon-attack-every=<s>`, 70). The targets rotate: hills_ne (270 m),
  meadow_south (190 m, south), grove_east (135 m, east; the most trees).
  `--dragon-target=<name>` picks the first one.
- V's cameras frame the rim while it clings: chase is a three-quarter view
  from outside and to the side, orbit circles the rim point
  (`--dragon-orbit=<deg>` is measured from the rim's outward way), and look
  aims at the rim from where you stood.

### What happens (scripts/sky_dragon.gd, scripts/dragon_gale.gd)

- **Target and side.** Targets are listed in `DRAGON_TARGETS`
  (studies/aqueduct_isle.gd). It grips the isle's flank as seen from the
  turf (`_clear_side`): of the two flanks, the one whose rim stands
  furthest, as seen, from any nearer isle. grove_east would otherwise hide
  it on hills_ne. So it shows in profile, and the blast crosses the view.
  The rim is found on the isle's real outline (SkyIslet `on_land` and
  `ground_at`, marched outward), as are the wrist and foot holds either
  side.
- **Approach and grab.** It goes in wide and banking round, then low
  outside the rim. The grab is a 3.4 s Hermite curve from its flight
  velocity onto the hold. It pitches up into a flare, with the wings swept
  forward and back-beating at 0.75 Hz and the legs swung forward. The
  swell and bumps fade out.
- **The slam.** The pose snaps over in 0.3 s. The isle node itself dips
  (an under-damped spring) and tilts toward the dragon, collision and all,
  and stays a little tilted while held. Dust puffs burst along the rim,
  about 30 stones break off and tumble into the clouds, and the isle's
  songbird flock (SkyAmbientLife) is flushed.
- **Clinging.** The body hangs nose up (1.12 rad), belly to the cliff. The
  wrists (thumb claws) and the hind feet are reached to the lip each frame
  by a small CCD IK (`_reach`), so they ride the isle's shudder. The
  membranes hang folded like a cape and open on the blast. The tail rope
  hangs and swings slowly under the keel. The neck rears over the turf.
- **Breath cycle.**
  - **Settle:** a gasp.
  - **Pant:** 4.5 to 7 s, jaw panting, glancing round on springs.
  - **Inhale:** 2.1 s, the tell. The head draws back and up, streaks flow
    into the mouth, and the isle's trees lean toward it.
  - **Blow:** 3.8 s. The head thrusts forward and sweeps ±0.42 rad across.
  - **Recover:** 1.3 s.

  Most of the blow reuses round 1's streaks, about 3x bigger (up to 34 m
  long), pouring across and on into the sky. The trees thrash because the
  wind tool's own foliage lanes (`zs_blow_*`, read by every plant's shader
  through `zs_blow_at`, conifers included) fire every 0.32 s along the
  blast. Nothing else publishes them on the aqueduct isle. Leaves are torn
  off the turf, stones shake loose, and big soft puffs churn up out of the
  cloud tops 70 to 420 m beyond in a widening wake.
- **The treasure.** A gem on its tongue, with a four-pointed glint that
  flares every few seconds and a small light.
- **Let go.** After 45 to 60 s, at the end of a pant, it pushes off. It
  drops back and turns out on one heavy beat (3.2 s, blended from the cling
  pose), the isle springs back, and it flies a circuit before roaming on.
- **The pilot.** If he is on foot on the attacked isle, the blow uses round
  1's rules: knocked into a tumble in the cone's core (±0.34 rad, 70 m) with
  a clear line, and pushed along in the band. Touching the gem (3.2 m)
  takes it: `yielded` pops the HUD, and it roars and lets go.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r4_from_turf_blast.png`: from the turf's east side, mid-blast on
  hills_ne. It shows the streaks across the isle, the leaves flung off and
  the tail hanging.
- `r4_close_blast.png`: close side view mid-blast. The neck is reared over
  the turf, the jaw open, a wrist hooked on the rim.
- `r4_slam_chase.png`: chase camera at the end of the grab.
- `r4_top_grip.png`: from above, the wrists on the rim either side.

Capture example: `--dragon --dragon-attack --dragon-skip=17 --at=122,40,6
--look=330,50,-120 --capture=x.png` (mid-blast from the turf).

### Rough

- From the turf, at 270 m, the dragon is small, about a tenth of the screen
  wide. The blast streaks and the leaf cloud read; the trees thrashing do
  not read at that range. Using `look` (V) narrows the FOV to 40.
  grove_east (135 m) shows it bigger.
- (Round 5 checked standing, walking, the knock and the treasure on foot.)
- The cloud-sea wake is plain soft billboards, not the volumetric clouds
  themselves (cloud_wakes.gd is tied to the puffs and towers). It sits at
  "about 80 m under the mouth", a guess at the cloud tops.
- The neck's sweep axis and sign are rough. The blast's way follows the
  dragon's facing plus the sweep rather than the head's true aim, so they
  can disagree by a little.
- The grab is a curve, not physics, and the slam has no camera shake or
  sound. The let-go turn is a simple yaw lerp.
- The membranes fold like a cape. The thumb claws are not posed separately.
- Leaves are flat quads. Debris is big on purpose (0.5 to 1.3 m).
- While it clings, nothing else reads the isle's tilt: the airships, the
  traffic and the islet life still use the home position.

## Round 3: a wyvern after Smaug

The user's notes on round 2 (look c, watched from the isle): still a bit
animatronic, the mouth most of all; reads well from the rear but not the side
or front; "lipstick" (the red mouth band); the tail too short; a lizard body;
the flight good but slow in a weird way, it should adjust to the wind and go
up and down a little; think Smaug; no shadow over the isle; wider wings.

### Play

- `./run-rim-dragon.command`: as round 2. Look **c** (stone body, soft
  glowing membranes) is now the default.
- `./run-rim-dragon.command --dragon-pass`: starts on the low pass's way in,
  so it comes over the isle and its shadow crosses the turf about 12 s in.
- V cycles the dragon camera, as before.

New flags (scripts/sky_dragon.gd): `--dragon-pass`, `--dragon-size=<x>`
(0.85, the model's scale), `--dragon-pose=roar` (with `--dragon-hold`: roars
on a loop), `--dragon-orbit-up=<m>` and `--dragon-orbit-far=<m>` (the orbit
camera's height and distance, for side and head-on captures).

### The model (art/blender/rim_dragon/dragon_body_build.py)

All three dresses still build from the one script (`--style=a|b|c`, c the
default); it was cheap to keep them.

- **A wyvern.** The wings are the forelimbs: there are no forelegs. Each
  wrist has a big hooked thumb claw, the one it would walk on. Two heavy
  hind legs, folded back under the tail's root in flight.
- **Neck.** Five neck bones (`neck.0` at the root to `neck.4`) along a long,
  thick neck that rises from the chest in a shallow S and carries the head
  out level.
- **Body.** A massive, deep chest (6 m half-width before scale), with a
  separate mass of wing muscle over each shoulder, then a lean waist into
  the hips.
- **Tail.** Eight bones, about 43 m from the hips to the tip before scale
  (head to hips is about 42 m). It is thick at the root and tapers to a whip
  with a spade blade.
- **Wings.** About 122 m span and 20 m chord at the arm before scale (round
  2: 84 m and 16 m). The membrane runs back to the hips.
- **Head.** A long wedge: broad at the cheeks, the brow peaked out over sunk
  amber slit eyes, the top falling straight to a narrow snout with nostril
  bosses. Horns swept back, cheek spikes, a row of blades over each brow.
- **Mouth.** The lips are the hide. The palate (`dragon_mouth`) and tongue
  (`dragon_tongue`) are a deep maroon going near black; the teeth ivory. A
  cheek-skin web joins the upper lip to the jaw at the back of the mouth,
  weighted from the head to the jaw, so it stretches open. The jaw's front
  half is its own bone (`jaw.tip`) for the lower lip's follow-through.
- **Size in game.** The game scales it by 0.85: about 74 m nose to tail and
  104 m span. Triangles: a 3.1k, b 5.1k, c 4.9k.
- **Sheet.** `dragon_body_sheet.py -- --styles=abc` renders side, head on,
  three-quarter, head close-up and top for each dress (c is the default
  style). `--jaw=-0.55` opens the mouth. `--tiles` keeps each view as its own
  png.

### The flight (scripts/sky_dragon.gd)

- **Faster.** It cruises at about 28 to 40 m/s (round 2: 19 to 26). Beats
  come at 0.3 Hz, and bouts start under 28 m/s. It glides until it is slow
  again, usually 8 to 12 s rather than 15 to 20. The turn rate is higher. The
  circuits are tighter and shorter (3 points, not 4) and the climbs a little
  lower, so there is less flying far off.
- **Riding the air.**
  - A slow swell lifts and sinks it a few metres, a bounded offset rather
    than a drift. Three sines, strongest when gliding and with the isle's
    breeze.
  - The air rolls and pitches the body a little. The nose rides the swell.
  - Every 3.5 to 8 s a bump hits: an under-damped roll and pitch spring
    that jolts, sways and settles. The wingtips flex with it.
  - Gliding, each wing trims against the air. The low wing lifts against the
    roll, and the hands twist with the swell. The wings take a gull's bend at
    the wrist, which also reads better head on.
  - A slow weave in the heading means no straight is ruled.
  - It drifts down the isle's wind. The host passes `air`
    (`Atmosphere.breeze()`) and `air_angle` each frame.
- **Mouth, all on springs.**
  - It breathes: a slight part of the jaw, and the chest swells (bone scale).
  - Every 2.5 to 6.5 s it chews, one or two soft small bites.
  - Every 12 to 22 s it roars. First it tightens, with a small dip. Then the
    jaw eases open (an under-damped spring, so it overshoots and settles)
    while the head lifts and the neck draws back. It holds with a tremble,
    then eases shut.
  - The lower lip lags the jaw's speed and springs back.
- **Neck.** Generic over the five bones. It holds the S, takes a share of
  the turn's lead, and a slow sway and slither pass up it.
- **Tail.** The rope now runs in world space through the skeleton's real
  transform (so it scales), over eight segments, with a slow whip wave down
  it.

### The shadow

Cast shadows were already on in round 2; they are now two-sided, so the
wings cast too. The isle's sun is an orthogonal map out to 140 m, which
reaches the turf under a pass 42 m up; the captures show the shadow
plainly. Round 2's trouble was aim. The low pass went over `IsleSky.MIDDLE`,
which sits on the near island's north edge. Under a sun about 38 degrees up,
the shadow fell 55 m away, mostly off the turf, and only for a moment. Now
the pass's middle point is set up-sun of the near island's turf (the middle
of `Art.NEAR`), by the shadow's offset (capped at 80 m). It is flown right
through: low passes arrive within 40 m, not round 2's 95 m skip. So the
shadow sweeps across the turf.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r3_side.png`: side, held glide.
- `r3_head_on.png`: head on, held glide.
- `r3_rear_three_quarter.png`: rear three-quarter in flight, banked.
- `r3_shadow_from_isle.png`: the shadow sweeping the turf with the dragon
  overhead, from the isle (`r3_shadow_after.png`: a second later, gone).
- `r3_shadow_overhead.png`: from above, the shadow over the hill.
- `r3_from_below.png`: from below on the low pass, against the sun.
- `r3_roar_open.png`, `r3_roar_closing.png`: a held roar.
- `r3_mouth_open_sheet.png`: the mouth open in Blender: dark inside, hide
  lips, cheek skin.
- `dragon_sheet.png`: the three dresses, five views each.

### Rough

- From the side, gliding, the wings are still edge-on and read as thin
  lines, though the neck, head and tail now carry the silhouette. Head on,
  the chest reads as a dark block and the head is foreshortened.
- The cheek web is subtle; the roar reads mostly through the head lift and
  the dark gape. No tongue motion.
- The membrane glow is toned down a little (0.42 from 0.7) but still lilac
  in bright daylight.
- It is big now (104 m span). Watch it against the isles and airships; there
  is still no collision. `--dragon-size` scales it.
- The swell, bumps and gain are tuned by eye, from captures only, not
  played. The wind tie is through the breeze strength and the drift; gust
  fronts are not sampled.
- The low pass picks a random approach heading, so on some passes the
  shadow crosses behind the ruins. The aim uses the first shadowed sun at
  the time the pass is planned. If the look preset's hour changes a lot,
  the aim goes stale.
- The capture rig: `studies/kit_isle.gd` gains a `_capture_tick` hook so a
  fixed-eye capture (`--at`) still flies the dragon.
- Still from round 2: no sound, the dragon camera doesn't stop pilot input,
  and the waypoints can make wide loops.

## Round 2: the sky dragon (superseded by round 3)

### Play

- `./run-rim-dragon.command`: the aqueduct isle with `--dragon`. The dragon
  rises out of the cloud sea after 3 s, makes a low pass over the isle, then
  roams.
- `./run-rim-dragon.command --dragon-look=a` (or `b`, `c`): the dress.
  `b` was the default (c is now).
- Press **V** in game to cycle the dragon camera: chase, orbit, look (from
  where the camera was), then off. `--dragon-watch[=chase|orbit|look]`
  starts on it.
- Title, then Scenes, then Ruins, then "Sky dragon". "Rim dragon (round 1)"
  is round 1.

Flags (scripts/sky_dragon.gd):

| Flag | What it does |
|------|--------------|
| `--dragon` | turns it on (studies/aqueduct_isle.gd) |
| `--dragon-look=a\|b\|c` | the dress: a angular, b carved (default), c stone and glow |
| `--dragon-watch[=mode]` | starts with the dragon camera on (chase, orbit, look) |
| `--dragon-delay=<s>` | seconds before it rises (3) |
| `--dragon-skip=<s>` | runs it on that far at the start (captures) |
| `--dragon-seed=<n>` | the route's dice |
| `--dragon-log` | prints where it is and what it is doing every 2 s |
| `--dragon-hold` | pose check: holds it in place 120 m up east of the isle |
| `--dragon-phase=<0..1>` / `--dragon-pose=glide\|dive` | with hold: freezes a beat phase or a pose |
| `--dragon-orbit=<deg>` | fixes the orbit camera's angle from its nose (90 = right side) |
| `--dragon-rim` | round 1's rim grip instead (scripts/rim_dragon.gd) |

Capture example: `--dragon --dragon-delay=0 --dragon-skip=26
--dragon-watch=chase --capture=/tmp/x.png --capture-wait=4`.

### The model

`art/blender/rim_dragon/dragon_body_build.py --style=a|b|c` builds one body
and one rig in three dresses in headless Blender, and writes
`assets/models/rim_dragon_<style>.glb` (`--blend` also saves a .blend).

- **Body.** One loft runs from the back of the head down a thick neck,
  through a deep, broad chest and the back, and out along a long tapering
  tail. It ends in a flat diamond blade. The head is 1.22x scale, with a
  heavy brow peaked over sunk amber eyes. The horns sweep back flat. The
  snout is short and square, the lower jaw big, and the teeth are ivory (no
  longer gold). It has four thick legs with claws. The wings span about
  84 m, with deep membranes (about 16 m chord at the body) on a real arm,
  wrist and four fingers. The body is about 56 m nose to tail. Everything
  is flat shaded: a 2.8k triangles, b 5k, c 4.6k (round 1 was 86k).
- **Rig.** `root`, `chest`, `spine.2`, `neck.0-2`, `head`, `jaw`, `hips`,
  `tail.0-5`. Each wing has `wing_arm`, `wing_fore`, `wing_hand`,
  `wing_f1`/`wing_f1b`, `wing_f2-4`. The legs are `fore_upper/lower/foot`
  and `hind_upper/lower/foot`. Rest is the glide pose. The body loft is
  weighted by its ring centres along the spine chain, so a deep chest ring
  moves as one. The membranes blend between the finger bones and the body,
  so they fold with the wrist.
- **Dresses.**
  - **a, angular:** 8-sided rings 2.3 m apart, few spikes, the biggest
    planes.
  - **b, carved:** 12-sided rings 1.45 m apart. The bands alternate, which
    gives scutes on the belly and plates on the neck. It adds a double row
    of back plates, brow plates, cheek spikes, jaw spikes, ringed horns, a
    nose horn and a lesser horn pair.
  - **c, stone and glow:** a's solids with a matte, stone-like hide. The
    membranes are smooth and soft, going from deep violet to a rose glow at
    the trailing edge (a ShaderMaterial in the game). The back fins and the
    tail blade glow amber. This follows the style rule.

  The game repaints by material name (`_material` in sky_dragon.gd) with a
  dark basalt-violet hide.
- **Sheet.** `art/blender/rim_dragon/dragon_body_sheet.py` writes
  `docs/design/rim-dragon/dragon_sheet.png`. It has a row per dress (a, b,
  c from the top) and columns for side, three-quarter, head close-up and
  top (Workbench, rest pose).

### The flight (scripts/sky_dragon.gd)

All of it is procedural on the rig, every frame.

- **Flight model.** It keeps a heading, a path angle, a speed and a turn
  rate, and steers at a waypoint with an eased turn rate (at most
  0.3 rad/s). The bank follows the turn: atan(v * rate / g). Speed comes
  from thrust (on the downstroke only), drag and gravity along the path.
- **Rhythm.** This follows the user's mid-round note: "less flaps, big flaps
  that let it coast". Cruising, it beats in bouts of 1 to 2 big, slow beats
  (0.27 Hz, raise +1.1 to -0.78 rad) when it drops under 21 m/s. Then it
  glides on spread wings until it is slow again, usually 15 to 20 s.
  Continuous, quicker beats (0.36 Hz) only come on climbs steeper than
  about 12 degrees and in the rise.
- **A beat.**
  - The downstroke is the power stroke, quick through its middle.
  - On the upstroke the wing folds: the forearm swings in, the hand and
    fingers fold back, and the outer membrane collapses.
  - The tips lag the raise's speed.
  - The body heaves 2 m against each beat, and the chest, hips and neck
    nod with it.
- **Gliding.** Small separate trims on each wing. The inside wing dips a
  touch in turns.
- **Dives.** The wings half tuck: raised, folded and swept back.
- **Neck, head and tail.**
  - The neck leads into turns through a spring (with a little overshoot).
  - The head holds level against pitch and bank.
  - The head turns to look at the camera when it passes within about
    200 m.
  - Every 10 to 20 s the jaw drops in a silent roar.
  - The tail is a verlet rope dragged from the hips, pulled softly toward
    its rest line. It trails the curve through turns and swings late out
    of them, and the bones are turned to lie along it.
  - The legs are tucked: forelegs folded up, hind legs trailing.
- **Route.** It runs in legs.
  - The start: a spiralling rise out of the cloud sea east-south-east of
    the isle, then a low pass over the isle about 44 m above its top.
  - After that it picks big circuits (r 300 to 460 m, 115 to 160 m up),
    threads between two neighbouring isles a little above the lower rim,
    or makes a climb to about 220 m followed by a long dive.
  - After about 3 legs there is usually another low pass.
  - The isles come from `aqueduct_isle_sky.gd`: ISLES and CLUSTERS within
    700 m.
- **Dragon camera.** It overrides the host's camera after the host has
  placed it each frame, so walking or flying carries on underneath. The
  FOV is restored when you turn it off.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `dragon_sheet.png`: the three dresses compared.
- `flight_a_chase.png`: a, banked glide from the chase camera.
- `flight_b_upstroke.png`: b, the wings folding up on the upstroke, the
  tail trailing.
- `flight_b_glide.png`: b, gliding past the aqueduct isle (orbit).
- `flight_c_chase.png`: c, from behind, the glowing membranes spread.
- `flight_c_from_isle.png`: c, overhead in the low pass, seen from the isle.
- `flight_a_glide_hold.png`: a, held glide pose (pose check).

### Rough

- The head reads big and squat (on purpose). Head-on, the red mouth roof
  shows between the teeth as a flat band. Close up, the face is still a
  plain box next to Odyssey's.
- Seen from the side the wings go edge-on and thin. They read best from
  above and behind. The sheet's three-quarter view is framed loosely.
- The dragon camera does not stop pilot input, so walking keys still move
  him underneath.
- There is no collision with isles or airships. The waypoint heights keep
  it clear, but a thread leg can pass close to hanging rock, and it flies
  through the airship route near the isle.
- No sound: no wingbeat whump or roar.
- The waypoint steering can make a wide loop when a point lands inside its
  turn radius. It skips points behind it within 200 m.
- The C membrane glow is fairly saturated in bright daylight.
- Pose-check flags (`--dragon-hold` and the rest) are debug aids.
- No LODs. They are not needed at about 5k triangles.

## Round 1 (parked behind `--dragon-rim`)

### Play

- `./run-rim-dragon.command --dragon-rim`: the dragon rises after 5 s.
- `./run-rim-dragon.command --dragon-rim --dragon-perched`: starts with it already on the rim.
- Title, then Scenes, then Ruins, then "Rim dragon (round 1)".

Flags (scripts/rim_dragon.gd):

| Flag | What it does |
|------|--------------|
| `--dragon-rim` | turns it on (studies/aqueduct_isle.gd) |
| `--dragon-perched` | skips the flight |
| `--dragon-delay=<s>` | seconds before it rises (5) |
| `--dragon-fly=<s>` | length of the flight (24) |
| `--dragon-calm` | gusts are look only and never knock |
| `--dragon-skip=<s>` | runs it on that far at the start (for captures: `--dragon-perched --dragon-skip=3.1` with `--capture` lands mid-gust) |

### What's built

- **Model**: `art/blender/rim_dragon/rim_dragon_build.py` generates it in
  headless Blender and writes `assets/models/rim_dragon.glb` (about 86k
  triangles). `rim_dragon_preview.py` renders Workbench stills. The head,
  jaw, neck, arms and hands are metaball unions. Each one is turned into a
  mesh, then gets two displaces (lumps, then Voronoi scale plates). After
  that it is decimated into irregular flat-shaded facets. Horns, teeth,
  claws and neck spines are ringed swept tubes. The wings are lofted
  scalloped membranes. Rig: `neck.0-2`, `head`, `jaw`,
  `upper_arm/forearm/hand.L/R`, `wing/wing_tip.L/R`. It has no clips, because
  the game poses the bones. Its origin is the rim's lip and the island lies
  ahead. The head is about 9 m tall without the horns.
- **Behaviour**: `scripts/rim_dragon.gd`, one self-contained node:
  - It waits, then flies a Catmull-Rom path in the perch's frame. The path
    climbs out of the cloud sea (`IsleChain.SEA_TOP`), passes high over the
    isle, banks round, drops under the rim and lands.
  - Once perched it loops through four states:
    - **pant** (4.6 s): chin on the turf, jaw open, the gem glinting on its
      tongue.
    - **inhale** (1.5 s): the tell. The head rears up and back and streaks
      flow into the mouth.
    - **blow** (2.4 s): the head thrusts forward and sweeps its yaw ±0.42 rad,
      throwing streaks out of the mouth. At the same moment the isle sends a
      strong gust front along that way, so the grass and air ribbons lie over.
    - **recover**.
  - In the cone's core (±0.34 rad, 55 m) with a clear ray from the throat,
    the pilot gets `motor.knock` into a tumble. In the wider band (±0.6 rad)
    he's only pushed along the ground. Stone between him and the throat
    shelters him.
  - Touch the gem (2.8 m from the pilot's middle) and it's taken. The dragon
    roars, lifts its hands, falls back off the rim and sinks into the clouds,
    and a crystal pops on the HUD.
  - While perched, invisible collision rides the skull, the snout, the lower
    jaw (you can stand on it) and the hands.
- **Pilot knock and tumble**: `scripts/pilot_motor.gd` and
  `scripts/pilot_figure.gd` carry over the henge guardian's changes from
  `park/henge-guardian` unchanged: `knock`, `knock_velocity`, `recovering`,
  the tumble step, twirl-out recovery and the somersault and sit-down pose.
- **Isle hook**: `studies/aqueduct_isle.gd` builds it at `DRAGON_RIM`
  (126.6, -9, east rim, facing west), advances it every frame and runs it
  during `--capture`. It also wires the gust front and the "treasure taken"
  pop, and adds a foot-hint line.

### Captures (local, gitignored)

- `docs/design/rim-dragon/rim_wide.png`: on the rim, panting (taken before
  the materials were brightened).
- `docs/design/rim-dragon/mid_gust.png`: mid-gust, with streaks across the
  isle.
- `docs/design/rim-dragon/mouth_open.png`: mouth open, the gem on the tongue.

### Rough

- The head is good at a distance. Close up it still reads more "Western
  dragon on a pug's snout" than Odyssey's massive brow. The brow and
  cheekbones want more mass and the snout wants to be shorter and squarer.
- The hide is a dark violet-black. It's lit glossy, but the sheen is a
  StandardMaterial clearcoat, not a wet shader. The teeth pick up warm light
  and read gold-ish.
- The pant pose leaves the jaw tilted: the chin is on the turf and the back
  of the jaw sits about 0.8 m up. The neck is never shown properly, and seen
  from the side the chest blob hangs below the rim.
- The flight is only seen in passing. The flying pose and banking are rough,
  and there is no body or tail, so close up mid-swoop it looks odd. The
  landing interpolates its transform rather than really climbing.
- No sound: no roar, inhale or wind.
- The pilot isn't carried by the moving jaw. If the head moves while he
  stands on the jaw or skull, he can clip in. A gust usually throws him out
  first.
- It runs one cycle: once the treasure is taken it doesn't come back.
- Stretch goal not done: seeing it clinging to another isle from afar.
- The model is 12 MB because flat shading splits every vertex. It could be
  decimated harder or use LODs.
