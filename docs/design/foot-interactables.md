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
Rope reach (headless): `godot --headless --path . --script tools/measure_rope_reach.gd -- --lengths=6.6,4.2`.

Round 2 changed the balustrade and the ropes; see "Round 2" at the end. Where the
sections below disagree with it, round 2 wins.

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
