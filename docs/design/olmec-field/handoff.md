# Handoff: Olmec field (greybox)

## Run it

`./run-olmec-field.command`, or
`godot --path . res://studies/olmec_field.tscn -- --no-title`.
Optional flags: `--earn-charge` (build charge by moving, as on other isles),
`--calm` (he doesn't hunt), `--olmec-at=x,z`, `--body-knob=<knob>=<value>`.

Controls: walk at him, Tab / R3 / middle mouse to lock on (within 22 m),
X (pad X) to fire the gust shot, R to reset you and the Olmec. The updraft
charge refills every frame on foot, so X always fires. Use `--earn-charge` to
turn that off.

## Built

- `studies/olmec_field.gd/.tscn` (extends `studies/kit_isle.gd`): one round
  isle 80 m across of near-flat turf at y 30, with seven standing stones at
  the rim. You start at the south end. The Olmec stands mid-field, side on,
  whole, with chase on, as in `whole_body_chase`. The plane is parked on the
  west side, nosed north along a clear run of about 50 m to the edge.
  `studies/olmec_field_sky.gd` is the kit sky without the aqueduct's plane
  tokens. A card at the top left shows hits as pips and his state.
- `scripts/lock_on/olmec_target.gd`: a subclass of the headless body that
  only this scene spawns, so the Olmec everywhere else is unchanged. It adds:
  - lock-target support: the `lock_targets` group, `aim_point` (his chest)
    and `tall` (over his head);
  - `hit()`: he rocks back on his feet, slides back about 1.1 m per shot,
    is stopped a beat in his heavy "land" squash, and the camera quakes,
    with dust puffs;
  - after 6 hits, `crumble()`: his figure and head vanish and 16 weathered
    blocks tumble out and settle.
- In the field only, the locked camera drops lower and looks up toward his
  shoulders so his head stays in frame. The gust ball also flies through his
  box collider (`see_through`) so it bursts at his chest.

## Proof

- Smoke passes with 0 errors.
- A headless drive (`scratch/olmec_lock.gd`, uncommitted) uses the real
  input: it walks him in, presses Tab and checks the lock is on the Olmec,
  then presses X six times. All six shots hit (shot 1 landed after 24
  frames), he crumbled, R brought him back, and the rubble was cleared. 7/7
  checks passed.
- Stills (git-ignored, in this worktree's `captures/shots/`):
  - `olmec_field_wide.png`
  - `olmec_field_start.png`
  - `olmec_field_locked.png` (the game camera locked on, with depth of field)
  - `olmec_field_shot.png`
  - `olmec_field_hit.png`
  - `olmec_field_hit_side.png`
  - `olmec_field_crumble.png`
  - `olmec_field_rubble.png`

## Not driven / open

- His attacks were not driven: swat, pounce, suck and gulp. Being caught or
  swallowed mid-fight has not been tried.
- Pushing him off the edge has not been tried. If he falls he comes back
  after 3 s.
- A hit doesn't interrupt suck, climb or leap.
- Taking off from and landing the plane on the field was not driven.
- The hit reaction reuses the "land" clip and the body's flat dust rings. A
  real stagger clip would read better.
- Existing tests: none expected to break, since the change only adds files.
  The suite was not run.
