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
| charge_speed / wind_up | run x 1.6 = 7.7 m/s / 0.5 s (was 0.7) | never steers after the tell |
| overrun | run x 1.1 = 5.3 m (was run x 0.8) | goes this far past where he stood when it locked |
| charge_dist | head x 13 = 14.6 m | cap on the reach |
| brake / lip_brake / lip | run x 2.2 = 10.6 (was x 3) / run x 5 / head x 0.15 | skid decel; near an edge it brakes harder and stops dead at the lip |
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

## Test

`tests/test_enemy_ram.gd` (headless): telegraphs then charges; a miss slides on
and stops on the isle; at an edge with reach to spare it stops at the lip and
never goes over; a standing pilot (also near the lip) is hit and shoved; a late
sharp juke is missed; the skid carries on along the old line while the front
swings round, then it tells and charges again, aimed at him; slid into from the
side near an edge it goes over. Only this test and the yard load were run.

## Unverified

- Feel: the tell length, charge speed, shove distance, the 0.72 m back, the
  sight cone, whether a dodge reads. Your call; all are knobs.
- Windowed look, the dust/paw reading, the tint's glow.
- Pushing the ram by a slide or long jump (`pilot_pushes`), standing on a
  stunned ram and being carried, and the wall stun are written but have no
  test. A "landing into it" has no special case: only horizontal pace counts.
- Wandering is simple (turns back at edges, may jitter at corners).
- The yard's `lost` is -20; a ram thrown off is gone at that height.
