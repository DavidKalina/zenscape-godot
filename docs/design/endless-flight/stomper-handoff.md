# The stomper: handoff

One 250 m headless stone body walks the real Amberlands, the far side of the
hall in the default game. Trail: `git log --grep='^ITER(stomper)'`. Spec:
`spec-stomper.md`.

Play: `python3 tools/play.py studies/endless_flight.tscn -- --no-title`, fly
through the hall, and look across the lake from the shore road.
`--world=amberlands` is a debug world on other land. `--stomper=0`,
`--no-stomper-fall` and `--no-stomper-wake` leave parts out.

## Built

- Body: `assets/models/stomper_body.glb`, 24,000 triangles, one skinned mesh,
  from `art/blender/headless_body/` (`reduce_stomper.py`, `bake_clips.py`), with
  an authored `stomp` clip: two steps of about 92 m in 16 s.
- Walk (`stomper.gd`, `stomper_legs.gd`, `stomper_route.gd`): feet planted by IK
  on `field.height`, a closed 3.8 km loop laid by hand on the plain over the
  lake from the road (it was a 12.3 km ring round the home), about 5.5 min a
  lap. It only walks while the plane is on that side.
- Footfall (`stomper_fall.gd`): ring pressed into the land, dust, grass, view
  shake, FOV punch, pad rumble, a low thump, a shove within 520 m.
- Wake (`stomper_wake.gd`): prints for 10 min, a scuffed band for 4, grass held
  for 70 s, hanging dust.
- Solid (`stomper_solid.gd`): 17 capsules on the bones through `plane_ground`,
  `_blocked`, the camera and the wing rays. A limb reaching a plane on the
  ground is a crash, and one closing at over 7 m/s in the air.
- Looks (`stomper_shadow.gd`, `shaders/stomper_stone.gdshader`): a shadow past
  the sun's 900 m reach, stone lit in shade by the land's bounce.

## Stood in

The first hour's art is the archive's mesh, reduced. The swat is not built.

## Open

- The smoke check failed twice in about 35 runs: 0/1 at 2b3759a5, and once at
  4c79d65a on `--world=amberlands`, with a GDScript backtrace. Neither error was
  kept. 15 runs under load did not bring it back. A crash at quit was fixed at
  3c86b3b8; whether it is the same thing is unknown.
- Engine line "BUG, indexing did not unpair geometries from light" in windowed
  runs; cause not looked at.
- Not measured: a PC, frame time since part 1, the ring's cost. Nobody has played
  it or watched it as a moving clip.
- The legs seem to pass through a pale buttress at the worst ridge (by eye, 1 km).
- A saw-tooth edge at low sun, likely the shadow map (not tested).
- The body's place depends on play, which co-op will have to revisit.

## For the user

Clouds cut by the body (a shared shader); whether a footfall rocks a parked
plane; whether being stepped on crashes; `root.use_debanding`; the stone's colour;
whether a shove that throws the plane into the hips is wanted.
