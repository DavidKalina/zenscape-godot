# The stomper

One giant headless stone body walks the Amberlands. The user asked for it on
2026-10-31; AGENTS.md lists the Olmec and enemies as out of scope, and this one
body is the exception the user made. There is only one in the world.

Play it: the default game, `--no-title` on `studies/endless_flight.tscn`, with
no `--world` flag: the Amberlands are the far side of the door, reached through
the hall (a tunnel) from wilderness. That is the world id `doors`
(`profiles/doors.gd`), the Amberlands round `world.offset`, 50 km along x.
`--world=amberlands` is only a debug world: other land, and the Peak stands in
it. Don't judge or place anything by it.

## What done looks like, in play

- From anywhere nearby you see one huge body, about 250 m tall, walking the
  land with no head. It is big enough to read on the horizon and slow enough
  to read as heavy: long strides, a hold on each planted foot, weight through
  the hips. Judge it by eye in rendered captures (AGENTS.md, Animation).
- Its feet land on the real ground (`field.height`), on the terraces and hills
  as they are. It keeps away from water and from slopes it can't stand on, and
  walks a long loop that stays near the spawn, so the player meets it.
- Each footfall lands with force: a shockwave ring runs out over the land, dust
  goes up, the grass and ground show it, the camera feels it, and the plane is
  shoved if it is close.
- It leaves a wake: a track of disturbance round where it has walked (flattened
  or blown grass, dust hanging, footprints if they are cheap).
- The plane can't fly through it: the body is solid to the flight, and flying
  into it is a crash the game already knows.

Not in this loop: a head attaching to it, the old boss's phases (charge, knock
offs, rim, rune), hearts or damage, and a swat. Whether it swats at the plane or
stays a spectacle is the user's to decide after playing it, so leave the door
open but build none of it.

## What to start from

The archived body, at the git tag `archive/before-the-cut` (`docs/archive.md`):
`art/blender/headless_body/` (`headless_body_build.py`, `bake_clips.py`,
`mathutils_lite.py`, `headless_body.blend`), `assets/models/headless_body.glb`
(88,840 triangles, 21 joints, 41 clips including `idle`, `walk`, `windup`,
`teeter`, `topple`), `scripts/olmec_boss/boss_body.gd` for how clips were
driven. Bring back only what this needs, with `git show` or a path checkout from
the tag. The old head and boss code stay in the archive.

## Constraints

- Cheap. The body is about 25k triangles or fewer after a reduction, one
  skinned mesh, one Skeleton3D. Keep Godot nodes to the few it needs; prefer
  RenderingServer and PhysicsServer3D where nothing needs a node, one shared
  particle or shader pass over many emitters. Report triangles, nodes and frame
  cost in each commit that changes them.
- The plane only collides with the heightfield and analytic `ground`/`inside`
  (`plane_ground` and `_blocked` in `studies/endless_flight.gd`), not physics
  bodies. The body's solidity goes through those, with a few moving capsules or
  boxes. Near-miss wing rays read physics bodies and need a collider object.
- Its code goes in its own new files (`scripts/endless/stomper*.gd`), with
  small additive hooks in shared files, gated to the world id `amberlands`:
  another branch (`iter/amber-giants`) is adding heads and torsos to this land
  and will be merged with this one.
- The Amberlands keep their terrain and geology, blank of arches, halls,
  tunnels and other kit. Don't change the land recipe.
- One world seed: 1. Nothing past the fixed world's 17 km across (AGENTS.md).
- Never use `git stash` in this worktree; the stash list is shared with the
  user's other work.
- Wind is another piece of work: don't build gusts here.

- The stomper, its loop and its footfall live on the Amberlands side of the door
  world: centred on `world.offset`, every spot passing `world.side_of(x, z) == 1`,
  nothing of it on the wilderness side. Its world gate takes `doors`, and
  `amberlands` still works for debugging at the origin. It must meet the player
  soon after they leave the hall on the far side.
- `iter/amber-giants` already does this (`GiantSwells.home(world)`, a
  `"peak":0.0` layer in amberlands/look.gd read at `_massif` in land_field.gd):
  match it, so the two merge cleanly.

## Order

Trunk only, no lanes; each task ends in something to look at.

1. The body in the land: restored, reduced, standing at size in the Amberlands.
2. It walks: a heavy authored walk at this size, on the real ground, on a loop.
3. The footfall: shockwave, dust, camera, plane shove.
4. The wake.
4b. Move it to the far side of the door (spec change, 2026-11-01): laid out on
   the real Amberlands, seen in the default game, all earlier checks and stills
   redone there, since their land was the debug world.
5. Solid to the flight.
6. Pass on looks and cost, in play.

Cap: the skill's default.

## Checks

Smoke: `python3 tools/smoke.py studies/endless_flight.tscn -- --world=amberlands
--no-title`, and without the world flag. Windowed captures pass `-- --no-title`.
