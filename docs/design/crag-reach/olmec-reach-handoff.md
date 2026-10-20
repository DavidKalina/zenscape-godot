# Handoff: the Olmec's reach in the crag reach (loop `olmec-reach`)

Spec: `spec-olmec-reach.md`. Earlier rounds: `olmec-hunt-handoff.md` (the
hunt), `olmec-look-handoff.md` (the upright hunt stride, the eye-contact gaze).
Trail: `git log --grep='^ITER(olmec-reach)'`.

**Play:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`
(or `--olmec-after=N`). Without either flag the crag reach plays as before.

## What's built

All behind `--olmec`. Each new body behaviour is a knob in
`scripts/enemies/headless_body.gd`, off by default and switched on in
`OLMEC_KNOBS` in `studies/crag_reach.gd`. olmec_field and whole_body_chase
play as before.

- **Down to you** (`down_to`, `down_deep`): from a rim he finds a floor
  near you up to about 27 m down and leaps to it, on a higher arc over a lip.
- **Breaks** (`studies/crag_reach.gd`, `scripts/kit_isle/kit_breaks.gd`): 33
  kit pieces (aqueduct spans, hall bays, colonnade columns, single ruins,
  terrace and islet landmarks) break under his bulk and landings through
  the breakables hub. Each piece's cut is made ahead on a worker at spawn,
  so breaks don't hitch. A piece breaks at its middle, not where he hits it.
- **Out of the rock** (`climb_clear`, `leg_slope`, `drop_bulk`): on a face,
  a grid of rays holds his front off the rock. Leg nudges ignore rising
  ground. He only drops off an edge if his whole body clears the arc.
- **Routes** (`edge_fan`, `skirt_hold`, `beam`, `parked_off`): he tries
  leaps either side of his facing at a rim, keeps one side going round a
  wall, walks the fallen pillar end to end, and ignores the parked plane's
  column.
- **Never stuck** (`dive`, `dive_walk`, `_never_stuck` in crag_reach.gd):
  no progress for 7 s, or 16 s with no edge near, and he walks to a rim, throws
  himself off, and 3 s later comes back up a clean, roomy cliff near you.
- **Close but no way in** (`suck_in`): within 15 m with no ground gained
  for 1.5 s, he plants and sucks you out (the east overhang).
  `watch_throw`: he tracks where his wave or swat throws you.
- **The surprise** (`down_show`): the 24 m drop off main's south rim onto
  main_terrace_3, landing where your camera sees his legs. Stand at the
  terrace's east end, about (15,6,38), look west and wait about 15 s.
- **No stall on spawn or return:** the head's dressed meshes are cached
  (`inhaler_head_look.gd`), and the crag reach warms his body, head and
  sounds at load (`_warm_olmec`).

## Numbers (headless reach table, 20 places, 60 s window)

- Reached when he saw you go there: 6 at the start → 18. When he didn't:
  6 → 15. Places near the edge flip between runs, so rerun a row twice
  before calling it a change.
- Worst sink of his body into the land: 0.55 m (his shins as he steps from
  main's crown onto the pillar). It was 0.95 m on every climb before.
- Frame times, run alone: worst 10–41 ms. Breaks and returns hitched before
  (up to 959 ms); now nothing goes over 50 ms. Spawn is about 20 ms.

## Open

- **Your call:** at west_terrace_1 the only cliff he can come back up is in
  your view, 9 m off. Keep it, or make returns out of sight only.
- **Camera:** the play camera doesn't frame him. He shows as legs at the
  frame's edge or a mass filling it. It goes inside his body on the suck-in
  and into dust and rubble on the main_terrace_2 landing
  (`play/2a_drop_main_terrace_2.png` reads poorly).
- **Throw into the void:** his landing wave throws you off narrow terraces,
  so the surprise often ends in your fall rather than a catch.
- **Not reached:** west and west_spire when he didn't see you go there (60 s
  runs out mid-route). north_terrace_2's cleft under a 12 m overhang has no
  clean, roomy face for him to come up.
- **Level tuning candidates:** north_terrace_2's cleft, the main-to-west gap
  and east's overhang are places the land, not his moves, decides.
- Trees don't break. The fallen pillar and the bridge anchors aren't
  breakable.
- **Throwaway tools (uncommitted, scratch/):** `olmec_reach.gd` (the reach
  table, `--place`, `--blind`, `--secs`, `--film-*`), `pick_probe.gd` (why
  each return face passes or fails), `look_scout.gd`, `pose_view.gd`.
- **Play-view sheets:** `docs/design/crag-reach/play/` (git-ignored, on disk
  in the loop's worktree).
- No committed tests, and the full suite wasn't run. Smoke checks pass for
  crag_reach (plain, `--olmec`, `--olmec-after=2`), olmec_field,
  whole_body_chase, aqueduct_isle and zenscape.
