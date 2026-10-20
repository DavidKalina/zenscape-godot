# Crag reach: the Olmec hunt (experiment)

**Launch:** `godot --path . res://studies/crag_reach.tscn -- --no-title --olmec`
(or `--olmec-after=N` to have him come N s in; `--body-knob=<knob>=<value>` over his knobs).
Without either flag the crag reach plays as before.

**What happens:** he spawns as the whole Olmec (the headless body with its inhaler head on, `OlmecTarget`). He clings under the rim of the crown you stand on, on a face out of the camera's view. The pick tries 32 ways round the crown. It prefers the crown's own rim and a face whose climb finds no false shelf (`_face_clean`). He climbs about 4 m, with hand puffs and stones as the tell and a "Stone grinds on stone below the rim..." line. Then he hauls over the lip and hunts you: relentless, swat, pounce, plant and suck, no periscope. Tab locks on, X fires the gust shot (its charge refills while he's out), and R puts you back at the start and spawns him again. If he falls off the world, another one comes up a cliff 6 s later. While you fly he keeps moving toward where you took off.

**The new knob** (`scripts/enemies/headless_body.gd`): `leap_catch` (default 0, so olmec_field and whole_body_chase play as before). With it on:
- A wall met mid-leap (feet ray or bulk stop) whose lip is within `climb_max` gets caught: he is set on the face, faces it and goes to "climb" (`_catch_wall`).
- Hunting, at an edge with no landing and you beyond and above, he throws a jump arc at a face across the gap up to `catch_gap` Hh (default 9, about 30 m) away (`_wall_leap`).
- `wall_catches`, `wall_leaps`, `catch_why` and `wall_leap_why` are there for drivers.

**Proved (headless driver, scratch/, uncommitted):**
- Spawn out of view about 31 m off; 6.4 s from spawn to the lip; states climb, mantle, chase, plant, suck.
- Main to east: he leaps at east's face 28 m across, catches it about 1.5 m under the lip of the lower shelf there, mantles and keeps hunting.
- Main to north: he follows down the fallen pillar, leaping and dropping, and pounces on you.

**What doesn't:**
- On east he ends on the lower shelf under the crown's overhang. You are 15 m above him and he can't get up, so he loops seek and chase.
- He can't use the rope bridge or the aqueduct, and the main-to-west gap is too wide. He paces the rim there for good.
- The isle's clouds show up in the harness's own SubViewport cameras (`shot_at`/`film` with `eye`), so use the `play` view for stills here.

**Tests at risk:** none found that reference these files. The full suite was not run.
