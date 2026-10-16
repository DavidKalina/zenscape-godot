# Handoff: lock-on and gust shot (loop `lock-on`)

Spec: `spec-lock-on.md`. Trail: `git log --grep='^ITER(lock-on)'`.

## Built

- **Target stone** (`scripts/lock_on/target_stone.gd`, placed by
  `studies/aqueduct_isle.gd` `_build_lock_target`): a weathered sarsen
  1.35 walker heights tall, 5 m along and 8 m right of the parked plane.
  Rocks on its foot and puffs dust when hit. `--no-lock-target` leaves it
  out. Take-off run unchanged (14 m with and without it).
- **Lock-on** (`scripts/lock_on/foot_lock.gd`, hooked in
  `studies/kit_isle.gd`): on foot, R3 / Tab / middle mouse locks the
  nearest "lock_targets" member within 22 m and in view; again releases.
  Auto-release after 1.5 s past 28 m or out of sight, and at once on
  flying or falling off. Camera eases behind the wanderer toward the
  target, stick only nudges. Bone-white wedge marker over the target.
  With no target, R3 still resets the camera; flying R3/Tab unchanged.
- **Depth of field** while locked: wanderer and target sharp, far and
  very near soft, fading with the lock; the camera's own attributes are
  restored on release.
- **Gust shot** (`scripts/lock_on/gust_shot.gd`, `Updraft.spend()`): X on
  pad or keyboard, on foot or in the air, with updraft charge at or past
  its release threshold spends all of it and fires the dragon's air ball
  (no knock on the shooter). Locked: homes on the target and rocks it.
  Unlocked: flies level along the camera heading. No charge: X twirls as
  before.

## Play it

`studies/zenscape.tscn -- --no-title`. Build charge by moving well
(slides, long jumps, flips, twirls, speed), press R3 at the start to lock
the stone, then X.

## Open

- No shooting pose or recoil yet; he doesn't turn to face the shot, and
  the shot has no whoosh of its own (task 5 in the plan).
- Charge was set by hand in the driver checks; building it through real
  play then shooting was not driven.
- From the start, the locked camera half hides the wanderer behind the
  parked plane.
- The depth of field is gentle (lighter than photo mode); tune by eye.
- The release past 28 m was not driven (out of sight released first).
- No committed tests (prototype round).
