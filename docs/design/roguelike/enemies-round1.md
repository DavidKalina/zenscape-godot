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
    `hits_pilot(m)`. Stun ("stun" state) is in the base.
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

A 24 x 29 m isle, open edges, a 1.2 m orange-lipped ledge along the north
side. You start 11 m south of the ram, facing it. F1 shows the ram's state.
R resets you and the ram. Stand on its line: it turns, paws (orange), charges.
Sidestep and it sails off the south edge; get on the ledge and it stuns on the
wall (2.5 s, a platform); slide into it from the side to throw it.

## Ram knobs and defaults (n = pilot numbers: run 4.8, walk 2.4, head 1.12, jump 0.8)

| knob | default | meaning |
|---|---|---|
| notice | run x 2.4 = 11.5 m | sees him this far |
| sight | 1.2 rad | half-angle it notices in (sneak up from behind) |
| line_angle | 0.14 rad | how on-its-line he must be to start the tell |
| turn | 2.6 rad/s (was 1.8) | turning to aim |
| tell / lock | 0.6 s / 0.2 s (was 0.8 / 0.3) | paw time; it stops aiming for the last `lock` |
| charge_speed / wind_up | run x 1.6 = 7.7 m/s / 0.5 s (was 0.7) | top speed; it homes (bullfight, below) |
| chase_turn | 2.6 rad/s | how fast the charge turns toward him while homing |
| commit | 0.4 s (x top speed = 3.1 m) | from this far out the line is set: the late-dodge window |
| lose_angle | 1.3 rad | he is this far off its heading: passed, it brakes into the skid |
| give_up | run x 3.6 = 17 m | farther than this it gives up (and is safe at a lip) |
| lip_pace | walk = 2.4 m/s | a skid slower than this stops dead at a lip; faster, having lost him, it cannot |
| hop | 0.4 | his feet over this share of its height are over it (a jump clears) |
| charge_dist | head x 13 = 14.6 m | cap on one charge (then it gives up) |
| overrun | (removed) | replaced by homing |
| brake / lip_brake / lip | run x 2.2 = 10.6 (was x 3) / run x 5 / head x 0.15 | skid decel; a safe or slow skid brakes harder and stops dead at a lip |
| skid_turn | 4.5 rad/s | how fast its front swings round to him while it slides |
| hurt_speed | run x 0.9 | a sliding ram at this pace or more still shoves him |
| dig / retell | 0.25 s / 0.35 s | dug in after the skid, then a short second tell and on again |
| shove_out / shove_up | run x 1.9 = 9.1 m / 0.5 m | the knock, via `knock_velocity` |
| push_speed / push_carry | run x 1.1 / 0.85 | his pace to throw it / share it takes |
| stun_miss / hit / wall / knock | 1.2 / 0.6 / 2.5 / 1.5 s | stuns; a miss no longer stuns (skid, dig, tell again): stun_miss is only for landing from a fall; hit stuns after its skid |
| wander_speed, edge_look, rest | walk x 0.5, head x 0.8, 0.8 s | idle wander turns back from edges |

Body: height = jump x 0.9 (0.72 m, a plain jump clears it), width = height,
length = height x 2.2. Cost 3, tags knockable/pushes/loud.

## The skid (feature/ram-skid)

After its reach (or a hit) the ram skids like the pilot thrown back at a run:
it keeps sliding along its line, braking, while its front swings round to him,
dust puffs off its feet and a `ram_scrape` sound; then it digs in and, if he is
still in notice, tells again (`retell`) and goes again. A miss is not a stun
any more: a lazy sidestep is chased, a late sharp juke is the counter. It can
be slid into in the skid or the dig. Fix: the "no hit" bug was that a ram in
its skid was never harmful, and it began braking a whole stopping distance
before a lip or its reach, so a pilot near an edge or past its brake point was
safe; it now hurts while sliding over `hurt_speed` and brakes harder only at
a lip.

## The bullfight (feature/ram-bull)

You are the red flag. After the tell and wind-up the charge HOMES: it turns
toward him at `chase_turn` (2.6 rad/s), so an early sidestep is followed and
punished. At `commit` s (0.4 s = 3.1 m at top speed) from him the head is down
and the line is set, so only a LATE dodge beats it: a jump over it, a power
slide aside, a drop into a rim hang. It looks at him, not the ground: charging
it never checks an edge. Once he is more than `lose_angle` off its heading (it
was passed) it brakes into the old skid (swing round, dig, retell). If a rim is
inside its stopping distance it cannot stop and goes over; that is the only
way it dies. A miss in the open costs it nothing: it skids round and comes
again.

- Stopping distance at full speed: charge_speed^2 / (2 brake) = 2.8 m. A skid
  slower than `lip_pace` (2.4 m/s) still stops dead at a lip, so the real kill
  band is (v^2 - lip_pace^2) / (2 brake) = 2.5 m from its middle to the rim at
  the moment it loses him, about 1.7 m from its nose. In play: dodge within
  roughly 2 m of a rim.
- It does not go over when it hit him, or gave up (he is out of range, or it
  has run `charge_dist`): those skids stop at the lip as before. Idle, it still
  turns back from every edge.
- Late-dodge windows measured in the test yard (seconds before its nose
  reaches him, full speed): jump 0.10-0.25 s (a 0.15 s window; earlier he lands
  in front of it, later he is run down); slide aside 0.25-0.6 s with the
  run of it; a standing sidestep is not enough (0.84 m clearance takes ~0.4 s);
  a rim hang counts from 0.35 s out, any time earlier. Late is the last ~0.25-0.6 s.
- A pilot hanging from a rim (`on_ledge`) is never touched: it passes over his
  hands and falls. While charging only its front half hurts, and feet over
  `hop` of its height (0.29 m) are over it, so a plain jump (0.8 m, ~0.2 s of
  air above that) can clear its 0.72 m back. Landing late on its back rides it.
- Still shoves him on contact (a charge, or a skid over `hurt_speed`): dodging
  too early or not at all near a rim is how he dies.
- Yard: every rim hangs (step off slowly); the middle is open ground.

## Test

`tests/test_enemy_ram.gd` (headless): telegraphs then charges; an early sidestep
is followed and hit; a late jump / late slide near the rim sends it over; a
late jump in the open: it skids round, tells again, does not fall; a drop into
a rim hang: it falls and he still hangs; never off an edge with no pilot to
chase (soak); a standing pilot (also near the lip) is hit and shoved; slid into from the
side near an edge it goes over. Only this test and the yard load were run.

## Unverified

- Bullfight: the slide test sets his sideways pace directly (a power slide's run-up), not a real run-up; landing late on its back rides it (and over a rim with it); feel of the 0.15 s jump window.

- Feel: the tell length, charge speed, shove distance, the 0.72 m back, the
  sight cone, whether a dodge reads. Your call; all are knobs.
- Windowed look, the dust/paw reading, the tint's glow.
- Pushing the ram by a slide or long jump (`pilot_pushes`), standing on a
  stunned ram and being carried, and the wall stun are written but have no
  test. A "landing into it" has no special case: only horizontal pace counts.
- Wandering is simple (turns back at edges, may jitter at corners).
- The yard's `lost` is -20; a ram thrown off is gone at that height.
