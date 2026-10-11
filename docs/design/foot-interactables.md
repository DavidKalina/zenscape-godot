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

## Controls

| Piece | Get on | On it | Get off |
|---|---|---|---|
| Bobbing slab | land on it | it sinks and tips toward you, then springs back; you ride its bob | jump; if the slab is on its way back up, its rise adds to your jump (up to 3 m/s) |
| Drifting slab | land on it | it carries you and turns you with it | jump or walk off; its pace goes with you |
| Swing rope | jump into it (hands or chest within 0.6 m of its lower two-thirds) | the stick along the swing pumps it (only while the swing goes your way, so working the stick in time pumps both halves); across, it steers the swing plane | Space lets go with the rope's pace plus a pop up; crouch drops off with no pop. Twirl and sail are fresh after |
| Balustrade | jump onto it (land on the coping, or come down within 0.45 m of it) | the slope speeds you up; crouch or stick-forward tucks; stick-back brakes; the stick across leans you back to balance | Space jumps off with all your pace, and the slide-hop weave works in the air. The rail's end flings you off. Leaning past 1, you fall off that side |

Your pace carries into a catch. Run and jump into a rope and you are already swinging.
Land on a rail at a slide's speed and you grind at that speed. Land crouched after a
rail and you slide on (carve family). A rope release can carry you straight into the
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
