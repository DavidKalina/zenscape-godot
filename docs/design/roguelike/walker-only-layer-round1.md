# Walker-only layer, round 1

The engine feature the underground Olmec city's refuge pieces need
(`brainstorm/round3-olmec-city/README.md`, its "Kit-ask tally"): geometry
that the wanderer stands on, grabs and kicks off, and that the headless
body (the Olmec) doesn't read at all. Use it for places he can't follow,
like a mouse run, votive niches, a hush gallery, wall slots or a summit door.

This is opt-in per collider, for new pieces only. No existing kit piece or
motif is retagged. That was layer round 12 (`feature/body-ground`), which
was stopped.

Branch `engine/walker-only-layer`, off `roguelike` (after the
olmec-destruction merge).

## The layer

Physics layer 15 (bit 14), named `walker_only` in `project.godot`. Before
this round no code used it. The same commit also names layers 1 (`solid`),
12 (`turf`), 13 (`water`) and 14 (`walker_props`).

Layer 14 is a different layer. It holds the parked plane's column, the
watcher room and the lantern posts. The walker sees it and so does the
body, because the body reads the study's `ground.mask`. That is unchanged.

**Who sees layer 15.** Only the walker's ground sees it
(`scripts/pilot_physics_ground.gd`, through `see()`):
- `studies/character_study.gd` `_build_pilot` adds it.
- `studies/kit_isle.gd` adds it to the DeckGround, so `run_layer`, the
  motif yard and every kit isle see it.

His ground answers all of the motor's surface questions: the ground ray,
the body slide, the head stop, ledges (`PilotLedge`), walls (wall slide,
wall kick, wallrun) and water depth. So everything the motor does works on
walker-only stone. The study's camera ball and the drop shadow also see it.

`PhysicsGround`'s own default mask stays `1`. Anything else that builds a
PhysicsGround (traps, the tumble run, the dragon, ropes, the wind horn)
doesn't see the layer.

## The helper (`scripts/walker_only.gd`, `class_name WalkerOnly`)

```gdscript
WalkerOnly.mark(body)        # layer = LAYER only, mask = 0; returns body
WalkerOnly.box(parent, size, xform, name := "WalkerOnly")  # a block-out StaticBody3D box, marked
WalkerOnly.marked(obj)       # on the layer?
WalkerOnly.strip(mask)       # mask without the layer: what an enemy reads
WalkerOnly.LAYER             # 1 << 14
```

A kit piece marks a collider in one line, `WalkerOnly.mark(body)`, after
building it. `mark` replaces the body's layer outright. A walker-only piece
is on no other layer, so nothing else's mask catches it.

## What each enemy does with it

Every enemy query that used to read `study.ground.mask` now reads
`WalkerOnly.strip(study.ground.mask)`.

- **Headless body** (`scripts/enemies/headless_body.gd`). It ignores the
  layer everywhere:
  - `_cast`, which covers its feet, walls, lips, leaps, the ground for
    shockwaves and `_floor`
  - its bulk box (`_bulk_at`) and the periscope's head box (`_head_q`)
  - the neck-to-head sense ray
  - its sight (`body_sight.gd` gets the stripped mask, so a walker-only
    piece doesn't hide him)
- **Shockwaves.** A walker standing on walker-only stone is off the
  body's ground, so the wave passes under him. Added in `_shock_meets`,
  using `EnemyField.pilot_on_walker_only()`.
- **Route planner** (`body_routes.gd`). Its column rays ignore the layer,
  so walker-only floors are never places or moves.
- **Inhaler head** (`inhaler_head.gd`). Its mouth-to-walker sight ray
  (`_clear`) ignores the layer.
- **EnemyField** (`floor_under`, `blocked`). These are used by the other
  enemies, such as the plinth ram, and they ignore the layer.
  - `under_pilot` (what *he* stands on, for riding a body) keeps his full
    mask.
- **Body spawner** (`body_spawner.gd`). Every cliff, lip and sight ray
  ignores the layer, so a body never spawns on or behind walker-only stone.
- **Olmec destruction** (`colonnade_breaks.gd`). Nothing changed and
  nothing was needed:
  - It breaks only the pieces it registered (the colonnade's piers,
    lintels, rings, walls and gable).
  - Its rays and its rubble rigid bodies use mask `1`.
  - **Walker-only pieces can't be broken by him.** They aren't in a
    breaker, and his bulk doesn't touch them.
  - Allowing a break would mean registering the piece with a breaker. That
    is the colonnade's own pre-cut machinery, so it isn't trivial.
- **Not enemies, and they also ignore the layer** (default mask `1`, or
  `1 | turf`):
  - the dragon (sight, air blast, cyclone)
  - traps (wind blaster, seesaws, tumble run, cannon)
  - the plane
  - rubble and rigid bodies
  - the ground surveys (flora, start spots, way lights, turf rays)

## How it was proved

**The throwaway driver.** `scratch/mouse_run.gd` (uncommitted) opens
`studies/whole_body_chase.tscn` and builds a block-out mouse run with
`WalkerOnly.box`:
- **The wall.** Solid, 30 m tall (past the body's 22 m climb) and 4 m
  thick, with a 2 x 2.4 m tunnel through it.
- **The tunnel floor.** A walker-only slab, 0.2 m high.
- **The far shelf.** Walker-only, 8 x 7 m, at `RuinKit.GRAB_TOP`
  (1.88 m), on the wall's far face.
- **The near shelf.** The same, on the near face.
- **The kick wall.** Walker-only, 8 m tall.

`--solid` builds the same pieces on layer 1, as the A/B. Every move below
is real input through the stick and the jump.

```
python3 tools/drive.py scratch/mouse_run.gd -- [--solid] [--near] [--kick] [--send]
```

- **Far run (the mouse run).** The body is spotted at f53. He runs through
  the tunnel, stands on its walker-only floor (y 0.20), grabs the far
  shelf's lip and climbs onto it (y 1.875). The body's beats: spotted,
  pounce, scope, scope none, lost, gave up. It then returns and roams.
  - **Tunnel.** 0 frames with the body in the tunnel, and 0 north of the
    wall.
  - **Far shelf.** 0 frames on it.
  - **`--solid`.** The same, because the wall hides him there.
- **Near shelf A/B.** He climbs the near shelf in the body's sight.
  - **Walker-only.** 0 frames with the body standing on it. Its only
    frames over the shelf's rect were airborne: 37 in a pounce arc, 1
    falling. He was still caught: by a pounce 3 times, and by one suck and
    gulp.
  - **`--solid`.** The body stood on the shelf for **1499** frames and
    swatted him off it 3 times.
- **Kick.** He runs and jumps at the walker-only wall. He is kept out of it
  (feet x 17.71, face at 18), slides down it (`move == "wall"`), and kicks
  off it (`move == "kick"`, peak 2.07 m).
- **Planner probe (`--send`).** I asked `body_routes.Search` for a route
  from the body to the far shelf and to the tunnel's far mouth. Neither
  route has a leg in the tunnel or on a shelf. I then sent the body down
  that route by `_start_search`. It walked to the wall's south face and
  stopped (0 frames in the tunnel).
- **Smoke.** All passed with 0 errors:
  - `studies/run_layer.tscn` `--shape=sprawl --seed=1` and
    `--shape=ring --seed=1`, none of which have walker-only colliders
  - `studies/headless_body_isle.tscn`
  - `studies/whole_body_chase.tscn`
  - `studies/colonnade_spine_isle.tscn --olmec`

## Limits

- **A ghost to everyone but him.** The body walks through a walker-only
  piece as if it weren't there, and so do the plane and rubble. Put
  walker-only pieces where that doesn't show:
  - inside a tunnel or slot too small for the body
  - in a niche
  - high on a wall
  - over a drop he can't reach

  A free-standing walker-only shelf in the open, like the A/B shelf, has
  him wading through it.
- **No protection from attacks that reach him.** The body still pounces,
  sucks and swats a walker standing on walker-only stone. Only the
  shockwave passes under him.
- **Sight goes through it.** The body's and the head's sight ignore the
  layer, so a walker-only piece is never cover. Cover is ordinary stone.
  This was a choice: it keeps "the body doesn't know it's there" one rule.
  Flip it in `headless_body.gd` `_see` and `inhaler_head.gd` `_clear` if a
  lens wants walker-only cover.
- **A planner quirk, found here and not caused by this round.**
  `body_routes.gd` `col` reads the floor under a solid block standing on a
  separate floor collider (the block-out wall on the arena floor) as a
  place with full room. Its room ray starts inside the block, and the
  query has no `hit_from_inside`. So the probe's legs run *through the
  solid wall* at x -7 and x -1, though never through the tunnel. At run
  time his bulk stops him at the face (he stopped and listened, and never
  got through). Kit walls standing on turf may read the same way. Worth a
  look in a planner round.
- **No breakage.** He can't break walker-only pieces (see above).
- **Untested beyond the body.** Other enemies (ram, inhaler head alone,
  traps) were changed only to strip the layer; they weren't run against
  walker-only stone. Wallrun and the sail were not driven on walker-only
  walls. They read the same `wall` callable as the kick, which was driven.
- **Only the two study bases see it.** Studies that build their own
  walker ground outside `character_study` / `kit_isle` don't see the
  layer.

## Tests

There are no new tests, because this is a prototype round. I ran the tests
that touch the changed code:

- **Passed:** `test_character_study`, `test_character_tricks`,
  `test_character_momentum`, `test_character_climb`, `test_enemy_ram`,
  `test_aqueduct_under` and `test_kit_isle_landing`.
- **Passed with known exit-leak noise:** `test_trap_giants` and
  `test_tumble_run`.
- **Failed, but not because of this round:** `test_collision_audit`. It
  fails on two DragonTower stones resting on nothing, and it fails the same
  way on `roguelike` (`e37139ec`) without this change.

I didn't run the full suite. As far as I know, this round breaks no test.
