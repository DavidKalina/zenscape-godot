# Endless flight: getting out and walking (handoff)

## What works

- Stopped on the wheels, **F (pad Y)** gets out: the engine spins down and
  the pilot hops down beside the plane (the hand landing's EXIT phase, as on
  the isles). The plane stays parked where it stopped.
- On foot he runs on the real endless land with the game's motor, figure,
  footsteps, puffs, ripples, drop shadow and walker camera
  (`scripts/endless/endless_walker.gd`): walk, run, jump (held higher, the
  pump), crouch slide, slope surf, chained long jumps and the pocket sail.
  Wall slide/kick, ledges, ropes, wall run and the twirl (and with it the
  roll) are off.
- Back by the plane, **F or Space (pad Y or A)** climbs in (the hop run
  backwards), stopped on the wheels; Space rolls it and it takes off as
  before. **R** on foot puts him back in the air in the plane over where he
  stands.
- The grass parts round him (`GrassReact.walker`, each grounded frame).
- `--on-foot` starts parked on the nearest open, level, dry turf to `--at`
  with the pilot out (for drivers and quick play).

## Ground and collision

- He stands on layer 1: the land stream's heightfield chunks, the spruces'
  convex bodies and the arches' bodies, through
  `scripts/pilot_physics_ground.gd`. The parked plane is a column on layer
  13 only he sees (as `kit_isle.gd`).
- On foot the land, arches and grass stream round the walker camera (7 m
  from him), and the trees' colliders round his feet, so the 70 m collider
  ring follows him.
- Where no collider stands yet, or a ray slips a seam, his ground is the
  land field's height (`_ground_from`); fallen more than 3 m under the field
  he is put back on it (`rescues`, warned). The camera never goes under the
  field.

## Water (chosen behaviour)

He wades the sea's shallows and river edges (slowed, rippling). Walking on,
water deeper than 0.45 m (`WADE_MAX`, the motor's SWIM_OUT) stops him like a
bank; he slides along it. Walked in, the depth the motor sees is capped
under its swim depth, so a swell running up the beach never floats him off.
Coming down in deep water from the air (a jump off the bank, the sail), the
motor's own untuned swim keeps him afloat and he can swim back.

## Proof

- Headless driver (scratch, uncommitted) `scratch/endless_get_out.gd`
  (`python tools/drive.py scratch/endless_get_out.gd -- --timeout=500
  --scene-args --on-foot`): 17/17 checks. Boards by F, gets out by F through
  the EXIT hop, ~1.1 km on foot over meadow, river banks, a 31 to 44 degree
  slope (surfed), through spruces (bodies there), pump, slide, 4 chained
  long jumps, a 176 m sail off a 17 m drop on a mountain, walks into the sea
  (stops at 0.5 m, not swimming), walks back, boards, takes off. 0 rescues,
  0 frames under the land, 0 grounded frames without a collider under him,
  0 frames where the land 2 s ahead had no collider. Zero script errors.
- Rendered sheet: `captures/shots/endless_get_out_sheet.png`
  (`scratch/endless_film.gd`, `--rendered`).
- Smoke: `studies/endless_flight.tscn` with and without `--on-foot`, 0 errors.

## Weak spots

- The meadow grass comes up to his chest: at the wanderer's size he reads
  as a hat in the grass from the walker camera. The grass was sized for the
  plane's eye.
- Stopped and hopping out, the plane's chase camera sits low in the grass
  (its on-ground cine), so the hop out is mostly hidden; the cut from the
  chase camera to the walker camera at "out" is a snap.
- Tall reeds by rivers stand between the walker camera and him (tufts have
  no colliders for the camera to avoid).
- The walker's per-frame code is a trimmed copy of `character_study.gd`'s
  `tick`, `_frame` and events (left alone so the isles stay exactly as they
  were); a tuning change there won't reach here.
- Only the stopped-after-boarding exit was driven; a flown hand landing then
  F runs the same STOPPED path but no bot landed it this round.
- The bot found the moves by setting him down at a flat, a slope and a drop
  (setup); the moves themselves were through input.

## For the merge

`studies/endless_flight.gd`: header, preloads, a few vars, `--on-foot` in
`_ready`, three lines in `tick` (early return to `_foot_tick` on foot, the
`exit` input, `_hop_out`), F/pad Y through `_land_key`, and an "On foot"
section at the end. On foot `tick` returns early into `_foot_tick`, which
has its own copy of the per-frame land/arches/trees/grass/look calls; a new
per-frame hook (the birds) needs adding there too.

## Next

Swimming proper, collectibles to walk to, a softer camera hand-off at
getting out and in, and the grass height against the wanderer.
