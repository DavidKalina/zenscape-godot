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
| turn | 1.8 rad/s | turning to aim |
| tell / lock | 0.8 s / 0.3 s | paw time; it stops aiming for the last `lock` |
| charge_speed / accel | run x 1.6 = 7.7 m/s / run x 8 | never steers after the tell |
| charge_dist | head x 13 = 14.6 m | then it skids (decel = TUMBLE_SKID 14) |
| shove_out / shove_up | run x 1.9 = 9.1 m / 0.5 m | the knock, via `knock_velocity` |
| push_speed / push_carry | run x 1.1 / 0.85 | his pace to throw it / share it takes |
| stun_miss / hit / wall / knock | 1.2 / 0.6 / 2.5 / 1.5 s | stuns |
| wander_speed, edge_look, rest | walk x 0.5, head x 0.8, 0.8 s | idle wander turns back from edges |

Body: height = jump x 0.9 (0.72 m, a plain jump clears it), width = height,
length = height x 2.2. Cost 3, tags knockable/pushes/loud.

## Test

`tests/test_enemy_ram.gd` (headless): telegraphs then charges on his line; a
charge that misses sails off the open edge and is gone; a hit shoves him
(tumble, 11.7 m/s). Only this test and the yard load were run.

## Unverified

- Feel: the tell length, charge speed, shove distance, the 0.72 m back, the
  sight cone, whether a dodge reads. Your call; all are knobs.
- Windowed look, the dust/paw reading, the tint's glow.
- Pushing the ram by a slide or long jump (`pilot_pushes`), standing on a
  stunned ram and being carried, and the wall stun are written but have no
  test. A "landing into it" has no special case: only horizontal pace counts.
- Wandering is simple (turns back at edges, may jitter at corners).
- The yard's `lost` is -20; a ram thrown off is gone at that height.
