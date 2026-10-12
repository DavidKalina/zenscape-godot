# Enemies, round 1 (greybox): the base and the Plinth Ram

Branch `feature/enemy-ram`. Greybox only: boxes, a colour tell, a logged
placeholder sound. Rules and numbers come from ideas-enemies.md.

## The base

- `scripts/enemies/enemy.gd`: one enemy. `knobs` (a dictionary built from the
  pilot's numbers, then per-enemy defaults, then spawn `overrides`, so a tier
  can randomize any of it), `cost` (1-5), `tags`, `state`, `vel`.
  - Tell: `tell(colour)` tints the body, calls `field.sound(name, at)` (logged
    in `field.sounds`, `sound_hook` plays it later), emits `told`.
  - Pilot shoved through `PilotMotor.knock` (`shove_pilot`), never damage.
  - Pilot knocks it: his pace along the line to it at `push_speed`
    (run x 1.1) or more (a slide, a long jump) throws it (`pilot_pushes`), stuns
    it, and takes most of his pace. Off an edge it falls under the pilot's
    gravity and is gone below the study's `lost` (`fell` signal,
    `field.gone_count`).
  - A prop: a `StaticBody3D` the size of the body, so he stands on it and the
    field carries him with it.
  - Hooks to override: `default_knobs(n)`, `_size(n)`, `_art(root)`,
    `think(delta)`, `harmful()`, `bumped()`, `landed()`, `pushed(speed)`,
    `hits_pilot(m)`, `_air_pose(delta)`. `_part(size, at, tinted, colour,
    parent)` returns the mesh and can hang it on a pivot. Stun ("stun"
    state) is in the base.
- `scripts/enemies/enemy_field.gd`: steps all enemies from the character
  study's `foot_pieces` hook (same pattern as foot_pieces.gd), supplies
  `numbers()` (run, walk, head height, jump, gravity, radius, ...) and the
  ground/wall rays. `spawn(script, at, face, overrides)`, `reset()`.
- `scripts/enemies/plinth_ram.gd`: the Ram.

## Add an enemy

1. `scripts/enemies/<name>.gd`: `extends "res://scripts/enemies/enemy.gd"`,
   set `cost`/`tags`, override the hooks above (the Ram is the template; a
   patrolling Millstone Beetle is `think` = walk a line, tell, sprint, with
   `harmful()` true while sprinting).
2. One line in `ENEMIES` in `studies/enemy_yard.gd`:
   `"beetle":{"script":Beetle,"at":Vector3(..),"pilot":Vector3(..)},`
   (optional `"knobs":{...}` overrides). Run with `--enemy=beetle`.

## Play it (windowed)

    godot --path . res://studies/enemy_yard.tscn -- --no-title --enemy=ram

The arena (`studies/enemy_yard.gd`): a 24 x 26 m isle with open rims all
round (every rim hangs: step off slowly), open ground in the middle, a 2.5 m
wide, 9 m long spit off the south rim (stand at its tip: any late dodge
there sends it off the end, but a slide aside goes off with it unless you
hang), two low boulders to bait it into (a wall stun), the orange-lipped
ledge 1.2 m up along the north side (out of its reach), and west an islet
over a 2.5 m gap (it won't charge across). You start 10 m south of the ram,
facing it. F1 shows its state. R resets you and the ram. The enemies' sound
calls play short synthesized placeholders (huff, paw thump, hooves, snort,
scrape, scrabble, bellow, thud).

## The bull (feature/enemy-ram, enhance/ram-bull, enhance/ram-solid-curve)

"You're the red flag." One bull, its states in order:

- **idle**: wanders at `wander_speed`, turning back from every edge.
- **notice**: he is within `notice`, inside `sight`, at a height it can
  reach and with no gap in the ground between them: it stops, its head comes
  up, it huffs and warms in colour, and turns to face him. Too close for a
  run-up (`room`), it backs off facing him (never over a lip).
- **tell** (`tell`, a second go `retell`): `scrapes` scrapes of the front
  right hoof, each a dust kick and a paw thump; the head sinks and the body
  heats to orange; it stops aiming for the last `lock`.
- **charge**: hooves sound, winds up over `wind_up` to `charge_speed`
  (run x 1.6), dust trailing, and HOMES like a bull hooking after the cape:
  it turns toward where he will be (his pace led on; off at more than a
  stroll he is reckoned to keep running at his run) at `chase_turn` (3.4
  rad/s) from a stand, falling to `chase_top` (2.4 rad/s) at its top speed.
  Its body banks into the turn and its head looks round (`lean`). An early
  dodge is followed and hit. Short of the commit it still sees the ground (a
  lip ahead is a safe stop).
- **commit**: `commit` s (0.7) from its horns reaching him, his own pace
  counted (so a fleeing pilot is locked on later and closer): the head snaps
  onto his lead point (at most `lock_on` rad) and drops, it snorts, a dust
  kick, it goes deep red: the cue to dodge. It still hooks after him, at
  `hook` (0.5) of its chase turn (1.2 rad/s at top speed), until its last
  `blind` (0.45) s, when its head is down and its line is set. So the path
  visibly curves after the cue and a lazy dodge (begun right on the cue) is
  hooked, but a late one beats the turn.
- **skid**: it lost him (more than `lose_angle` off its heading, or he is
  over its horns): a big dust spray and a scrape, sliding on along its line,
  braking so that from full speed it stops in `kill_band` m, its front
  swinging round to him. If the rim is inside the distance it needs at the
  pace it lost him at, it can't stop.
- **teeter**: front feet at the lip, scrabbling and rocking for `teeter` s,
  then a bellow and it tips over, nose first. A committed charge that meets a
  lip (he dropped into a hang under it) teeters too.
- **dig**: dug in, coming round to face him; winded (`stun_hit`) if it hit
  him, else straight back to notice (no beat) and a short retell.

Edge rules: idle it never walks off; a skid it did not lose him in (it hit
him, he went out of range `give_up`, it ran `charge_dist`, or he dropped out
of reach before it committed) stops dead at a lip; only a committed charge or
a skid that lost him at speed near a rim goes over. Hit rules: only the
horns hurt (the front `horns` share of its length, while charging or
committed, his feet under `hop` of its height); a pilot hanging from a rim is
never touched. Its body is always solid stone: he bumps into it in every
state, stands on it when it is still, and when it moves or turns into him
it shoves him out of its box (`push_out`, sliding him along any wall).
Charging, skidding or teetering it `bucks()`: a pilot whose jump comes down
on its back is thrown off behind it (`buck`, a small knock), so a jump over
it still lands behind it rather than riding its back over the rim. A slide
or long jump into it (`push_speed`) knocks it, off a rim if it is near one.

### The clip (enhance/ram-solid-curve)

Its height was never the cause. The pilot's body cylinder starts at
BODY_LOW = STEP_UP + 0.05 = 0.5 m, under its 0.72 m back, and the ground ray
reads its back as a 0.72 m wall (over STEP_UP 0.45), so a solid ram always
stops him. He passed through for two other reasons:

- `_solid()` cleared the body's collision layer whenever its pace was over
  2x `wander_speed` (2.4 m/s) or it was teetering. That covered all of a
  skid until it slowed under 2.4 m/s, and backing off in **notice**, which
  moves at exactly 2x wander speed, so a float rounding error made it
  flicker. While the layer was clear he walked straight through.
- The body is a StaticBody3D moved by `position`. The physics space only
  picked up the move at the frame's transform flush, and the ram's own move
  never looked for him (he is no collider to it). So when it walked, backed
  off or swung its 1.6 m length round into him, his body started the step
  inside its box. The cast lets a body that starts inside move freely so it
  can get out, and he walked out the far side. Headless tests that tick
  without frames never saw the body move at all, and reset enemies left
  their bodies standing until the frame ended.

The fix: the body is always solid and goes into the physics space as it
moves (`force_update_transform`). Reset enemies leave the space at once.
`push_out` shoves him out of its box after each step. A charging, skidding
or teetering back bucks him off instead of carrying him, and the same goes
for a hang caught on its edge.

### What was broken in play (found driving the real pad input)

Measured by playing the old ram through the study's own input path (left
stick axes, A, LT through the InputMap) rather than by setting velocities:

- A real power slide never dodged it: from a run at it, every slide was hit.
  The old slide test set his sideways pace directly.
- An early dodge was not punished: running out of its line 1.2 s before
  contact always worked, because homing on where he *is* can't catch a pilot
  who keeps running. Now it leads him, and the head locks on at the commit.
- The jump window was 0.15 s (0.10-0.25 s before contact); landing late on
  its back rode it (over the rim with it).
- A miss right beside him in the open left it too close to tell again, and
  it wandered into him; now it backs off for a run-up.
- Layers of fixes (a skid that hurt above `hurt_speed`, `lip_pace`, a
  separate homing/commit flag) are gone: one state machine, one stopping
  rule (`kill_band`), one hit rule (the horns).

Not fixable here (the motor is outside these files): from a standstill, LT
held with the stick is a crouch, not a slide (the slide needs his run's pace
first, `LONG_PACE` 3 m/s), so the power-slide dodge is "stick across, then
LT a beat later". Sliding carves at most pace / 2 rad/s, so a slide straight
out of a flight from it barely leaves its line.

### Dodge windows with the curving charge (enhance/ram-solid-curve)

These were measured through real input, at 60 Hz with the stick at full
tilt, by sweeping `tau` over 0.05, 0.1, 0.2, 0.3, 0.35, 0.4, 0.5, 0.6, 0.7,
0.8, 1.0 and 1.2 s. The cue (commit) comes at 0.7 s and the ram runs blind
from 0.45 s.

| dodge | works | too early | too late |
|---|---|---|---|
| jump (A), 2 m from the rim | 0.05-0.5 s: it goes over (0.35-0.5: he comes down on its back and is bucked off behind it) | 0.6 s or more: on its horns | at contact |
| run out of its line, 1.5 m from the rim | 0.3-0.7 s: it goes over | 1.0 s or more: hooked and hit (0.8: it pulls up short, a miss) | under 0.3 s |
| power slide (stick across, LT once running), 1.5 m from the rim | 0.35-0.6 s: it goes over | 0.7 s or more: hooked and hit | under 0.35 s |
| drop into a rim hang | 0.4-0.8 s: it goes over his hands | 1.0 s or more: it gives up short of the lip | under 0.4 s |
| running at it, then slide carving aside, 0.6 m from the rim | 0.4 s only | 0.5 s or more: hit | under 0.4 s |
| run out of its line, in the open | 0.3-0.8 s: a miss, it comes again | 1.0 s or more: hit | under 0.3 s |
| power slide, in the open | 0.35-0.6 s | 0.7 s or more: hit | under 0.35 s |
| jump, in the open | 0.05-0.5 s | 0.6 s or more | at contact |

Compared with the straight committed line, the power slide lost its
0.7-0.8 s end (now hooked), the run at the rim lost 0.8 s, and the carving
slide while running at it narrowed from 0.4-0.6 to 0.4. The jump gained
0.4-0.5 s, because a jump that comes down on its back is now bucked off
behind it instead of falling through the ghost body onto the ground in
front of its horns. The fleeing rows of the old table (below) were not
re-measured. The kill band is unchanged: a skid that loses him slides on
along its actual velocity, so a curving charge that loses him near a rim
still goes over.

### Dodge windows (round 2, the straight committed line, kept for comparison)

Seconds before its horns reach him when the dodge is begun (`tau`, his pace
counted); the cue (commit) comes at 0.7 s.

| dodge | works | too early | too late |
|---|---|---|---|
| jump (A) | 0.05-0.35 s | 0.4 s or more: he comes down on its horns | at contact |
| run out of its line (stick across) | 0.3-0.8 s | 1.0 s or more: led and hit | under 0.3 s |
| power slide (stick across, LT once running) | 0.3-0.8 s | 1.0 s or more: hit | under 0.3 s |
| drop into a rim hang (ease off the rim) | 0.35-0.8 s: it goes over his hands | 1.0 s or more: it gives up short of the lip, no hit | under 0.35 s |
| fleeing toward the rim, then jump | 0.05-0.35 s | 0.4 s or more: hit | at contact |
| fleeing, then turn out of its line | 0.35-0.5 s (0.6-1.0 s: a miss, met too far from the rim) | 1.2 s: hit | under 0.35 s |
| fleeing, then slide with the stick across (carve) | 0.6-0.7 s only | 0.8 s or more: hit | under 0.6 s |
| running at it, then slide carving aside | 0.4-0.6 s: a miss | 0.7 s or more: hit | under 0.4 s |

Kill band: a late jump or run aside sends it over with him up to 2.0 m from
the rim; 2.4 m out it stops short and comes again (`kill_band` 1.9 m of
stopping from full speed, plus its half length and the lip).

## Ram knobs and defaults (n = pilot numbers: run 4.8, walk 2.4, head 1.12, jump 0.8)

| knob | default | meaning |
|---|---|---|
| wander_speed, rest, edge_look | walk x 0.5, 0.8 s, head x 0.8 | idle wander; turns back from edges |
| notice / sight | run x 2.4 = 11.5 m / 1.2 rad | sees him this far, in this half-angle |
| line_angle / turn | 0.14 rad / 2.6 rad/s | on its line to tell; turning to aim |
| notice_beat | 0.35 s | head up, huff, before the tell |
| room | head x 1.5 = 1.7 m | the run-up it backs off for (past its nose) |
| tell / retell / lock / scrapes | 0.75 / 0.4 / 0.2 s / 3 | paws; it stops aiming for the last `lock` |
| charge_speed / wind_up | run x 1.6 = 7.7 m/s / 0.5 s | top speed and its build-up |
| chase_turn / chase_top / lead | 3.4 / 2.4 rad/s / 1.2 s | homing on where he will be (led at most `lead`), turning `chase_turn` from a stand down to `chase_top` at its top speed |
| commit / lock_on | 0.7 s / 0.6 rad | time to reach him at the cue; the head's snap onto his lead then |
| hook / blind | 0.5 / 0.45 s | after the cue it still turns at `hook` x its chase turn (1.2 rad/s at top), until its last `blind` s (head down, line set). More hook or less blind: a narrower late window |
| lean | 0.04 | the bank into a turn: turn rate x pace x this (rad, at most 0.35); the head looks round turn rate x 0.35 (at most 0.5) |
| lose_angle | 1.3 rad | off its heading this far: passed (or he is over its horns) |
| kill_band | head x 1.7 = 1.9 m | stopping distance from full speed (the skid's braking) |
| lip / lip_brake | head x 0.15 / run x 5 | the lip margin; a safe skid's hard stop at a lip |
| teeter | 0.45 s | scrabbling at the lip before it goes |
| skid_turn / dig | 4.5 rad/s / 0.3 s | its front swinging round in the skid; dug in |
| give_up / charge_dist | run x 3.6 = 17 m / head x 13 = 14.6 m | it gives up (a safe stop) |
| horns / hop | 0.35 / 0.25 | the front share of its length that hurts; feet over this share of its height are over it |
| shove_out / shove_up | run x 1.9 = 9.1 m / head x 0.45 | the knock, via `knock_velocity` |
| push_speed / push_carry | run x 1.1 / 0.85 | his pace to throw it / share it takes (base) |
| stun_hit / stun_wall / stun_miss / stun_knock | 0.6 / 2.5 / 1.2 / 1.5 s | winded after a hit; into a wall; landing from a fall; pushed |

Body: height = jump x 0.9 (0.72 m), width = height, length = height x 2.2;
greybox torso, shoulders, a head on a pivot (horns, a yellow muzzle), four
legs. Cost 3, tags knockable/pushes/loud.

## Test

`tests/test_enemy_ram.gd` (headless) plays every bout through the study's
own tick reading the InputMap as the pad drives it (stick axes relative to
the camera, A, LT); only the start positions are set. Notice, tell, charge,
commit in order with their sounds and colours. The charge curves: with him
running sideways it turns up to about 3.2 rad/s before the cue; with him
starting sideways on the cue it still turns about 0.17 rad after it, at no
more than 1.2 rad/s, and not at all in its blind last 0.45 s; it banks and
looks into the turn. It is solid stone: walking and running into it idle,
wandering, backing off, telling, skidding or dug in, and stunned, he stops
against it and never gets inside its box, and as it turns round into him
standing by its shoulder it shoves him aside. Still, he jumps onto its back
and stands there. Standing on its line he is knocked. Near the rim these
send it over: a late jump (0.1, 0.2, 0.3 s; at 0.45 s he lands on its back
and is bucked off behind it, staying on the isle), a late run aside, a late
power slide (0.4, 0.6 s), a carving slide while running at it (0.4 s) and a
late drop into the hang (he still hangs). A lazy slide at 0.75 s is hooked
and hit. Early jump, run and slide are hit, an early hang is waited out,
and too late is run down. A late jump in the
open: it skids round, comes again, does not fall; idle soak at four rims (one
the spit) for 40 s; out-of-range stops at the rim; the ledge is a wall stun;
across the gap it doesn't charge; a real long jump into its side knocks it
over the rim; a late jump at the spit's tip sends it off the end. Run with
it: test_gamepad, the import, a headless load of the yard. Not the suite.

## Unverified

- Everything visual: the poses (head up, sinking, the commit snap, the
  skid's sit-back, the teeter's rocking, the nose-first fall), the colours,
  the dust, and whether the commit reads at a glance. Headless only; no
  rendered run was asked for.
- The placeholder sounds are synthesized and played, never heard.
- Feel on a real pad: the windows above are from scripted input at 60 Hz
  with the stick at full tilt; a human's reaction to the snort (about
  0.2-0.25 s) leaves roughly 0.2-0.45 s for the sideways dodges and the last
  0.3 s for the jump.
- Riding a stunned ram, and being carried by it, has no test (standing on
  one does).
- The curve's look: the bank and head turn are greybox transforms, checked
  only as numbers. Whether the hook reads as a bull after the cape, and
  whether the buck (a short tumble behind it) feels fair rather than like a
  hit, needs a windowed run.
- The push-out keeps him out of its box. Pinned between a moving ram and a
  wall, the wall wins and he stays partly inside the ram until it moves off.
  This is untested.
- A careful step off a still ram's 0.72 m back can catch its edge as a
  hang (the motor's ledge catch), with his feet a little under the ground.
  That is the motor's, not touched here. If the ram then charges, skids or
  teeters he is bucked off; if it wanders, he is carried.
