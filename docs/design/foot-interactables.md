# On-foot interactables: handoff

Branch `feature/foot-interactables` (from main 5430e81b). This adds four things to
play with on foot, so routes through the isles have more in them than static ruins:
bobbing slabs, drifting/turning slabs, swing ropes and balustrades to slide. All four
carry momentum in and out. Each gives back the pace you bring, and a well-timed exit
sends you further.

## Launch

    ./run-interactables.command                 # the yard: all four side by side
    ./run-interactables.command --at=rope       # bob | drift | rope | rail (or 1-4)
    godot --path . res://studies/zenscape.tscn -- --no-title --foot-at=ropes
    godot --path . res://studies/aqueduct_isle.tscn -- --no-title --foot-at=rail
    godot --path . res://studies/stair_clouds_isle.tscn -- --no-title --foot-at=stair

`--foot-at=` takes `rail`, `ropes`, `ferry` or `slabs` on the aqueduct isle and the
game. On the Stair to the Clouds it takes `stair` (the top rail) or `stair_slabs`. In
the aqueduct isle's sky the stair's spots work too, though it stands 450 m away.
`--no-foot-pieces` leaves every piece out. The yard is also under Scenes, in
On-foot greyboxes.

Test (headless): `godot --headless --path . --script tests/test_foot_interactables.gd`.
Stills (rendered): `godot --path . --script tools/capture_interactables.gd -- --no-title [dir]`.
Spawn still (rendered): `godot --path . --script tools/capture_foot_spawn.gd -- --no-title --foot-at=ropes [dir]`.
Rope reach (headless): `godot --headless --path . --script tools/measure_rope_reach.gd -- --lengths=5.6,4.9 [--set=t_boost=6] [--curve]`.

Round 2 changed the balustrade and the ropes, round 3 the ropes again; see "Round 2" and "Round 3" at the end. Where the
sections below disagree with them, the later round wins.

## Controls

| Piece | Get on | On it | Get off |
|---|---|---|---|
| Bobbing slab | land on it | it sinks and tips toward you, then springs back; you ride its bob | jump; if the slab is on its way back up, its rise adds to your jump (up to 3 m/s) |
| Drifting slab | land on it | it carries you and turns you with it | jump or walk off; its pace goes with you |
| Swing rope | jump into it (hands within 0.3 m, or chest within 0.32 m, of its lower two-thirds; the rope swings to your hands, you are never pulled in) | the stick along the swing pumps it (only while the swing goes your way, so working the stick in time pumps both halves); across, it steers the swing plane | Space lets go with the rope's pace plus a pop up; crouch drops off with no pop. Twirl and sail are fresh after |
| Balustrade | it's only stone: walk up its eased head, or hop onto the coping | stand or run on it; crouch and the motor's slope surf takes you down it, the stick across carving | the slide jump; carve or drift off its side and you fall; its end is a drop you fly off at full pace |

Your pace carries into a catch. Run and jump into a rope and you are already swinging.
Land on the coping crouched at a slide's speed and you surf on at that speed. Land
crouched after a rail and you slide on (carve family). A rope release can carry you straight into the
next rope.

## How it's built

- **Motor (small and additive).** `scripts/pilot_motor.gd` gains `var rider`. While
  it's set, `step` reads the buttons and hands the frame to `rider.ride(motor,
  delta, want, pressed)`. `toss(push, hop := false)` lets go: it clears `rider`, and
  `hop` keeps the slide-hop weave. A reset or knock clears `rider` too. The diff is
  20 lines.
- **Figure.** `scripts/pilot_figure.gd` treats `hold == "swing"` as the ledge hang (2
  lines). The host tilts the drawn body along the rope (`pose`), then eases it upright
  over 0.25 s after release.
- **Character study.** `studies/character_study.gd` gains `var foot_pieces`, which
  calls `before(delta)` and `after(delta, events)` around the motor's step and
  `pose(figure)` in `_sync_figure` (4 lines). Every kit isle and the yard inherit this.
- **`scripts/interactables/`**:
  - `foot_pieces.gd` is the host. It steps every piece, carries the pilot on the slab
    under him (`PilotMotor.carry`), hands a slab's velocity to him when he leaves it,
    and runs the catches. It also builds pieces (`bob_slab`, `drift_slab`, `rope`,
    `rope_frame`, `balustrade`).
  - `foot_slab.gd` is the base slab. It is one of the aqueduct isle's floating stones
    (`Art.floating_stones`: eroded stone, clod, ivy) on a clean walking box, with a
    sag and tilt spring. It calls `body.force_update_transform()` after moving, so
    the motor's rays see the slab where it is drawn that same frame. Without this,
    moved bodies only reach physics at the tree's transform flush.
  - `bob_slab.gd`, `drift_slab.gd` (path ping-pong with eased ends, a closed loop, or
    a spin), `swing_rope.gd` (spherical pendulum, faceted rope in the footbridge
    tone) and `balustrade.gd` (kit-stone coping, balusters and newels, with a clean
    collision wall under the coping). `Balustrade.grand_stair_rail(frame, side)`
    gives the coping line down either cheek of any `RuinKit.grand_stair`.
  - `aqueduct_foot_route.gd` and `stair_clouds_foot_route.gd` hold the placements.
    `aqueduct_isle.gd` and `stair_clouds_isle.gd` each call them with one line.
    Nothing went into `kit_isle.gd`.

## Tuning constants (yard: F4 sliders, live; Print copies them as consts)

The `t_*` static vars mirror these constants. Every piece reads them each frame.

- **Bobbing slab:** SINK 0.24 m, TILT 0.09 rad at the edge, GIVE 0.05 (landing kick per
  m/s of fall), HZ 1.15, DAMP 0.28 (springy, so it overshoots), BOB 0.12 m over
  BOB_TIME 4.6 s.
- **Drifting slab:** SINK 0.06, TILT 0.025, HZ 2.2, DAMP 0.45. `t_speed` scales every
  drifter's clock.
- **Swing rope:** GRAVITY 20, PUMP 3.5 m/s², STEER 3, MOST 1.35 rad (77°), DAMP 0.08,
  TOP 12 m/s release cap (the long jump's top), POP 1.5 m/s, CATCH 0.6 m, GRIP_HIGH
  0.35, REGRAB 0.45 s. PUMP was 7 at first, which reached full swing in 1.5 s and 16
  m/s; 3.5 takes about two swings.
- **Balustrade:** PULL 18 (the surf's SLIDE_PULL), DRAG 1, AIR 0.03, TUCK 0.6, BRAKE 5,
  TOP 18, START 2 m/s, JUMP 0.9 m, END_POP 1.2, TIP 1.1/s, WOBBLE 0.35, LEAN 2.4,
  CATCH 0.45 m. Coping HEIGHT is 0.95 m over the nosings. Down a grand stair (24°,
  12.7 m) from a standing catch, it reaches 10.7 m/s.
- **Host:** RISE_KEEP 3 m/s, UPRIGHT 0.25 s.

Measured headless: a running jump reaches 2.24 m. A rope release lands 6.1 m from
where you let go, at 10 to 12 m/s.

## Placements

**The yard** (`studies/interactables_yard.gd`) is a greybox deck in open sky. You fall
below -4 m and respawn at the nearest station.
1. Four bobbing slabs to a far deck.
2. A slab sliding across your path, a ferry going out and back, a 7 m arm turning,
   and one circling a ring.
3. Two ropes on trilithons over a gap, then a far deck with metre ticks.
4. A grand stair down from a high deck with a balustrade on each cheek, then a 30 m
   run-out with ticks.

**The aqueduct isle**, a loop:
1. **Grand stair.** A balustrade down each cheek, from the henge terrace east onto the
   meadow (`--foot-at=rail`).
2. **North rim beside the aqueduct** (x 104.8). Three ropes hang from stone beams laid
   over the east parapet, at z -26.4, -32.2 and -37.6, each 6 m long from 36 m up.
   The middle one hangs over the fallen span. They take you across the 17 m gap to the
   far island (`--foot-at=ropes`). Checked headless: rim run, rope to rope to rope,
   onto the far island.
3. **Ferry.** A drifting slab at x 110 between z -40.8 and -27, 11 s there and back,
   0.3 m over the turf (`--foot-at=ferry`). Checked headless: boarded from the far rim
   and ridden back.
4. **East rim.** Three bobbing slabs climb to the east islet. The lodestone's floating
   stone is just north of them (`--foot-at=slabs`).

**The Stair to the Clouds** (in its own scene, and in the aqueduct isle's sky at
(440, 14, -254.6)):
- A balustrade down the outer cheek of each of the top four flights, over the drop.
  Each one flings you onto a landing, and from there you jump onto the next (`stair`).
- Four bobbing slabs off the first flight's outer side, a shortcut from the lawn to
  its head (`stair_slabs`).

## What's weak or unverified

- **Hand-feel is untested.** The numbers come from headless bots and a few rendered
  stills; nobody has played them with a pad yet. Rope pumping, rail balance (TIP,
  WOBBLE, LEAN) and the bob spring need a hands-on pass in the yard with F4.
- **Ropes swing through geometry.** The pendulum doesn't collide. The isle's ropes
  hang in clear air beside the aqueduct, but a rope placed near walls would pass
  through them.
- **No swing clip.** The hang clip tilted along the rope reads fine in stills, but
  there is no swing-specific pose (legs leading, a kick at the top).
- **Rails are straight polylines.** Bends don't push the balance; there are no sparks
  (it uses the slide's spray) and no grind sound.
- **The camera doesn't take up a turning slab's yaw** the way the serpent ride's does.
  It just follows.
- **The Stair to the Clouds placements weren't run by a bot.** Only captures checked
  them (the outer rails look right). The rail-to-rail chain between flights and the
  last bob-slab jump onto the first landing may need nudging.
- **In the aqueduct isle's sky, the stair's pieces exist from the start.** Headless,
  the isle itself is only built when you come near, so there the pieces float alone
  until it is. Rendered builds stand every isle from the start.
- **`--foot-at=` behind the title** (the game without `--no-title`) is untested.
- **The suite was not run**, as asked. Only these ran: the import check, headless
  loads of `zenscape.tscn` (`--quit-after 300`) and the yard, and the new test (all
  27 checks pass).

## Next ideas

- **Ladders:** a hold state like the rope's, where up and down climbs; it could reuse
  `rider`. Jump kicks off it sideways, carrying any climb speed.
- **Gust rings:** a ring that tosses you along its axis (`motor.toss`) and refreshes
  the twirl and the sail. Chained with ropes, they make airborne lines.
- **Swing-to-ledge and rope-to-rail chains** on the isles (the chains are possible
  now, but nothing is placed for them).
- **Sinking slabs** that sink slowly while you stand, to keep you moving; slabs that
  tip you off if you stand at the edge too long.
- **A curved balustrade** down the stair to the clouds' spiral, with a balance push in
  the bends.
- **Recorded challenges** (the recorder branch): the aqueduct loop (rail, ropes,
  ferry, slabs) is meant as the first one to record.

## Round 2 (2026-10-11): organic play

**The user's rule.** No magnet catches, no teleporting the body onto a line, no mode
that takes over on proximity. The existing moveset works on things, and every entry
keeps the player's full velocity. Round 1's balustrade broke all three. It grabbed you
within 0.45 m, set you on its line, cut your sideways pace, forced a START pace and
handed you to a rider. The user said: "I don't like how it snapped."

### Balustrade: a real surface

- `balustrade.gd` lost its catch, its rider (`try_catch`, `_take`, `ride`, `_place`,
  the balance meter) and its `t_*` tuning. It is only stone now. The coping's clean
  collision box *is* the surface. Stood on it you can walk and run. Crouched (or
  landing crouched) on its slope, the motor's ordinary slope surf takes you down, and
  the stick across carves, as on the serpent's back. Your feet leave its top and you
  fall. Its end is a drop: you fly off at all your pace, with no scripted pop.
- **Shape.** COPING is 0.38 m wide (was 0.3). The line runs straight from 0.95 m over
  the top step's nosing down to 0.95 m over the foot step's: about 21°, ramped over the
  half landing the way a handrail is. It used to go level there, which braked the
  slide. Over the steps it stands 0.67 to 1.24 m. The head eases down to MOUNT 0.42 m
  over the landing, RAMP 1.3 m back, onto a newel pedestal of the same height. A step
  (STEP_UP 0.45) or a plain jump gets you on, which you need now that nothing catches
  you. The foot newel stands NEWEL_DROP 0.3 m under the coping's end, so you fly over
  it. Both newels collide. Balusters reach down to the steps' nosing line, `floor_line`
  (`Balustrade.grand_stair_floor`). A groove or lips would not help: the motor reads a
  feature under 0.4 m as a ridge or gully, so it would be flat. The wider coping does
  the work.
- **Motor change (small, generic, additive).** `PilotMotor._gradient` takes an optional
  axis. `step` also reads the slope along his way (the velocity, or the facing when
  slow) and keeps that read only if it is steeper than the world-axes one. The world-x/z
  read calls a narrow coping or beam a ridge (flat) unless it runs along an axis. With
  that read, a diagonal leg of the Stair to the Clouds threw you off after 3.3 m
  (headless). Now every narrow slope, in any heading, is its slope. Planes read the
  same as before. Ground rays per grounded step go from 9 to 18.
- **Host.** `foot_pieces.gd` only notes `on_rail` (the balustrade under his feet),
  counts times on it and keeps its top pace for F1. Events: `rail` true or false on
  getting on or off. `rider`/`toss` stay in the motor for the rope.
- **Measured (headless).** Run onto it, then crouch over the top of the flight: 4.8 to
  9.6 m/s by the foot, off its end at 9.2 m/s, landed sliding at 8.7. Round 1's rider
  gave 10.7 m/s from a standing catch. With the stick held straight down it (no
  corrections), every placed rail runs to its end: the yard, the aqueduct isle, the
  Stair to the Clouds' four diagonal legs and their copies in the sky, all at 9.0 m/s.
  A full carve across drops you off the side in about half a second.

### Ropes: findable and fair

- **Why they were hard to find.** `--foot-at=ropes` stood him 3.5 m from the rim. The
  walker's camera (polar PI/2-0.7) looks 50° down at his feet, so the first rope hung
  above the top of the frame. What you saw was grass and a dark island underside, with
  one thin 7 cm rope near the top edge, hanging against the aqueduct's dark stone.
  Nothing said which island you were on or where the ropes were.
- **Spawn.** He now starts at (107.4, 30, -14), 10 m from the first rope, facing it
  (`SPOTS.ropes`). Every `--foot-at=` start sets the camera low behind him (SPOT_POLAR
  1.32), looking out along his way. From there both ropes and their beams stand
  against the sky, with the gap and the far island beyond (checked in a rendered still).
- **Read from afar.** The rope is thicker (RADIUS 0.06, was 0.035), with a bigger knot
  and anchor ring. `SwingRope.add_tag` hangs a weathered madder cloth tag (TAG 0.6 x
  1.8 m, TAG_TONE b04a2c, folded facets, notched hem) that stirs in the air. The
  aqueduct ropes have one off each beam's outer end; the yard's are on each lintel.
  There are no HUD markers.
- **Grab audit.** Your hands (where the hang holds them, `hand_of`: HANG_DROP up,
  0.25 m ahead) must come within CATCH 0.3 m of the rope's lower part, or your chest
  (0.6 m up) within CATCH_BODY 0.32 m. It was 0.6 m. Taken, the rope swings to your
  hands and your body stays where it was. All your speed is kept, the part along the
  rope turned into the swing, up to TOP. A jump passing 0.5 m beside a rope misses it
  (tested).
- **Spacing (user: "I want to have to twirl or glide to the next rope").** Measured
  with `tools/measure_rope_reach.gd`: pumped to full swing, let go at the best angle,
  the furthest a like rope can stand and still be caught. Each figure is in metres
  from the first rope's anchor.

  | rope | plain release | twirl at the top | sail popped at the top |
  |---|---|---|---|
  | 6.6 m (yard) | 13.1 | 17.6 | 35.5 |
  | 6.0 m | 12.9 | 16.9 | 30.4 |
  | 4.2 m (aqueduct) | 9.4 | 13.6 | 25.2 |

  - **Yard:** three ropes at z -3.8, -19.0 and -43.0. The 15.2 m gap needs the twirl;
    the 24 m gap needs the sail. The far deck moved to z -48 to -64.
  - **Aqueduct isle:** the 16 m gap (rims at about z -24.5 and -40.5) can't hold three
    ropes spaced like that, so there are two. Both are 4.2 m long, so their ends hang
    1.8 m over the turf and the first is jumped to from the near island. They sit at
    z -23.8 and -36.0, 12.2 m apart: past a plain release (9.4) and inside the twirl
    (13.6) and the sail. From the second, a plain release lands on the far island. The
    sail gap is only in the yard.
  - **Tests:** in the yard, a plain release falls short of the second rope, a twirl
    reaches it, and the sail reaches the third. On the isle, a plain release falls
    short and a twirl reaches the second.

### Constants (round 2)

- Balustrade: HEIGHT 0.95, COPING 0.38 x 0.16, PITCH 0.42, MOUNT 0.42, RAMP 1.3,
  NEWEL_DROP 0.3. All rider constants are gone. The slide is the motor's SLIDE_* and
  CARVE_*.
- Swing rope: CATCH 0.3, CATCH_BODY 0.32, CHEST 0.6, RADIUS 0.06, TAG 0.6 x 1.8,
  TAG_TONE b04a2c. The others are unchanged.
- Aqueduct route: ROPE_ZS [-23.8, -36.0], ROPE_LENGTH 4.2, SPOT_POLAR 1.32.
- Yard: ROPES at z -3.8, -19.0, -43.0. The F4 panel lost the balustrade sliders and
  gained the rope's `catch_body`.

### Still weak or unverified (round 2)

- **Hand-feel is unplayed.** Nobody has slid the coping or chained the spaced ropes
  with a pad. The coping may feel too forgiving held straight, or too twitchy to get
  onto. The bots land on it with the stick let go; land with 3 m/s sideways and you
  slide off the far side, which is physical but may feel harsh.
- **The rail is slower than round 1's** (about 9.6 against 10.7 m/s), because the
  motor's own surf drag sets its pace. Making it faster means a steeper coping or a
  motor change. Neither was made.
- **No sail gap on the aqueduct isle.** The 16 m gap only fits one twirl gap. A sail
  gap needs a longer line, perhaps out to an islet.
- **The Stair to the Clouds' eased heads** (RAMP 1.3 m back onto each landing) weren't
  checked in a still for clashes with the previous leg's foot newel.
- **The spawn capture checked `--foot-at=ropes` only.** The other `--foot-at=` spots now
  get the lower camera too, but nobody has looked at them.
- **Moving the ropes moved the beams too.** A beam at z -36.0 stands just past the
  fallen span's broken deck (it resumes at -35.5), and it looks right in the still.
- **The suite was not run.** These ran: the import check, headless loads of the game,
  the yard and the Stair to the Clouds (`--quit-after 300`), and the test (42 checks
  pass).

## Round 3 (2026-10-11): a real fling, ropes you can reach

The user played round 2 (`--foot-at=ropes`) and said: "Release doesn't fling you
nearly far enough", and "Ropes are too high up, don't extend down enough to grab."
They liked the ropes and want the second rope to need a twirl or the sail. Organic
play still holds: no magnets, no pulling the body in. Where this section and earlier
ones disagree, this one wins.

### The fling: a timed release boost

- **Boost.** Jump off a rope and he leaves with the rope's velocity at his hands plus
  BOOST (6 m/s) along it, scaled by the timing (`SwingRope.timing()`, 0 to 1). The
  timing is 1 rising with the rope BEST (0.75 rad, 43°) past the plumb. It falls off
  as the square to 0 at WINDOW (0.5 rad, 29°) either side. Let go falling, at the
  bottom or crouched off, and you get no boost. Then the cap (TOP, now 24, was 12)
  and the pop (POP 1.5 up) are applied. So the skill is in the timing, and a
  well-pumped swing still matters, since the boost adds to it.
- **Longer ropes.** The ropes are 5.6 m long (`SwingRope.LENGTH`; the aqueduct's were
  4.2), so they swing faster. GRAVITY, PUMP, MOST and DAMP are unchanged.
- **Feel.** On a 5.6 m rope, a well-timed release leaves at about 18.6 m/s, 47° up,
  from an 11.5 m/s swing. Released early (17°), it leaves at 14.9 m/s, only 23° up.
  For comparison, a running long jump is 7.6 m/s and covers 4.3 m.
- **F1** shows the timing you would get letting go now, and the timing of the last
  release.

### Reachable ropes

- **Knot at the hands.** Every placed rope's knot hangs KNOT (0.9 m) over the ground
  under it. A standing walker's hands are at 0.825 m (HANG_DROP), and a running
  jump's hands reach 1.62 m at the top of its 0.8 m rise. So a jump's hands cross the
  rope's lower part anywhere along their arc, and a running jump 1.6 m short of the
  rope takes it about 0.7 m above the knot (held 4.9 m down). CATCH and CATCH_BODY
  are unchanged (0.3 and 0.32).
- **Run into it.** On the ground, `try_catch` now takes the rope too, but only at a
  run (RUN_IN 3 m/s or more) and moving toward it, using the same hands and chest
  tests. His hands meet the knot, which lifts the body about 8 cm. Walking past or
  standing beside a rope doesn't take it, and neither does running past 0.55 m off it
  (tested).

### Measured reaches (round 3)

Measured with `tools/measure_rope_reach.gd`, as in round 2: pumped to full swing, then
let go on the forward rise. Figures are the furthest a like rope can stand and still be
caught, in metres from the first rope's anchor. "lands" is where he comes down to the
ground under the knot. "Early" means let go 17° past the plumb, and "late" 69°. The
tool now measures in open sky, away from the yard's frames (round 2's numbers were
right, but a higher arc can hit a lintel). Round 2's 4.2 m setting still measures 9.4,
13.6 and 25.2.

| rope (held at) | well-timed plain | early / late plain | twirl | sail |
|---|---|---|---|---|
| 5.6 m (knot) | **19.0** (lands 18.8) | 10.0 / 10.9 | 24.4 | 44.9 |
| 4.9 m (running-jump catch) | 17.4 (lands 17.1) | 9.2 / 9.7 | 22.8 | 41.3 |
| 4.5 m | 16.4 | 7.9 / 9.4 | 21.6 | 38.7 |
| 4.2 m (round 2's length, new boost) | 15.6 | 8.1 / 8.9 | 20.7 | 37.0 |

A well-timed plain release from the aqueduct's rope reaches 19.0 m, 2.0 times round
2's 9.4. In the test, measured from where he let go to the deck's height, a well-timed
release flies 13.7 m and an early one 7.1 m. A running long jump goes 4.3 m.

### Spacing

- **Aqueduct isle.** A 21 m spacing doesn't fit across the 16 m gap rim to rim, so
  the first rope moved back onto the near island's north meadow. Both ropes are on
  x 106.3 (ROPE_X; it was 104.8), clear of the buttress at x 104.3, z -6 to -12, and
  4 m from the ferry. They hang from beams laid out over the aqueduct's east parapet
  (now 6.4 m long), with the anchors at TOP+6.5. The first rope is at z -16.6, 7.7 m
  in from the rim, so you run into it or jump to it. The second is at z -37.6, over
  the gap 2.8 m short of the far rim. The ropes are 21 m apart, past the well-timed
  plain release (19.0) and inside the twirl (22.8 when held from a running jump).
  The test's plain release from the first rope falls into the gap at z -35.6, about
  5 m short of the far rim. From the second rope, a release lands him well up the far
  island (z -50 in the test). There is still no sail gap on the isle.
- **Spawn.** `--foot-at=ropes` is at (106.3, TOP, -6.6), facing -z, 10 m back from
  the first rope.
- **Yard.** Station 3's ropes are the same 5.6 m with the knot 0.9 m over the deck.
  The first is on the deck's edge at z -1.2 (its trilithon stands on the deck). The
  second is at z -22.2, 21 m on, for the twirl. The third is at z -52.2, 30 m on, for
  the sail: past the twirl (24.4), inside the sail (about 39 to 45). The far deck runs
  from z -58 to -84 with ticks. The station's spawn is at z 6.5, 7.7 m back.

### Tuning it yourself (yard F4)

The F4 panel leads with the rope's length, pump, top (the release cap), boost, best and
window, then pop, gravity, steer, most, damp, catch and catch_body. The length slider
(`SwingRope.t_length`) re-lays station 3's ropes and trilithons at the new length, with
the knot kept at 0.9 m. It takes effect when you're not hanging from a rope. The
isle's ropes keep `SwingRope.LENGTH`. Print copies everything out as constants
(`const LENGTH := …  # swing_rope`), and Defaults puts them back. The test drives the
sliders and checks all of this.

### Constants (round 3)

- Swing rope: LENGTH 5.6, KNOT 0.9, TOP 24 (was 12), BOOST 6, BEST 0.75, WINDOW 0.5,
  RUN_IN 3. New live values: `t_length`, `t_boost`, `t_best`, `t_window`. The others
  are unchanged (GRAVITY 20, PUMP 3.5, POP 1.5, MOST 1.35, DAMP 0.08, CATCH 0.3,
  CATCH_BODY 0.32).
- Aqueduct route: ROPE_X 106.3, ROPE_ZS [-16.6, -37.6], ROPE_LENGTH = LENGTH,
  ROPE_TOP = TOP+KNOT+LENGTH, spawn (106.3, TOP, -6.6).
- Yard: ROPE_ZS [-1.2, -22.2, -52.2], with `lay_ropes()` and `FootPieces.remove_rope`.
- Reach tool: `--set=t_boost=…,…` overrides the live values, `--curve` prints every
  release angle, and it reports where he lands as well as where he catches.

### Still weak or unverified (round 3)

- **Hand-feel is unplayed.** Nobody has tried the boost window with a pad. A 29°
  window either side may feel too strict or too loose. Hold Jump's press against the
  F1 timing readout to learn it. There is no visual or sound cue for a good release.
- **The twirl gap is narrow.** On the isle the margins are about 2 m: plain 19.0
  against a 21 m spacing, and the twirl at 22.8 held from a jump. A rope caught
  higher, say a twirl arriving at a second rope 3 m down it, swings slower and flings
  less far: about 16 m/s from rope 2 in the test.
- **The sideways swing.** If you catch a rope a little off its line, the pump grows
  the sideways swing too, because it pumps along the velocity. The test's bot steers
  that out with the stick, as a player would. Without steering, a sail from the
  yard's second rope drifted 3.5 m sideways and missed the third. A pump along the
  stick only might be kinder.
- **Feet at the bottom of the swing.** With the knot at hand height, a rope held by
  its knot swings his feet within about 8 cm of the turf at the plumb, over the meadow
  and the yard's deck. Rope swings don't collide, so on uneven turf his feet could
  dip into the grass.
- **Rendered still.** `capture_foot_spawn` shows the first rope hanging nearly to the
  turf beside the aqueduct, with its beam and the second rope over the gap beyond
  (`/tmp/foot_spawn_r3/ropes_far.png`). From the spawn camera itself, the rope is a
  thin dark line against the sky above the aqueduct's end, and the tag is hard to
  make out.
- **What ran.** The import check, headless loads of the game (`--foot-at=ropes`) and
  the yard (`--quit-after 300`), and the test (all checks pass, including the new
  F4, run-in, jump-catch, timing and spacing checks). The full suite was not run.
