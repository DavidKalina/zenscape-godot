# Spec: the climbing rope (greybox study)

Loop slug `rope`, branch `iter/rope` (branched from `iter/bag` so it can
borrow the bag study's room and aim code). Cap and budget: the skill's
default.

## What it is

The wanderer carries a rope with a hook. He throws it up, makes sure it
has caught, and climbs it. From a top he can fix the rope and lower himself
down a drop (rappel). The rope is how he gets up and down height, so this
study plays him with a **reduced moveset**: walk, run, jump and the slide.
No wall moves, ledge grabs, sail or updraft. A key toggles his full
moveset back on, for comparison.

- **Throw the hook:** hold to aim (the bag's hold-RT aim: a reticle and an
  arc, `scripts/carry/loot_bag.gd`), aimed at an edge or anchor above him.
  Release, and the hook flies trailing the rope. A miss falls back down and
  he reels the rope in.
- **Secure it:** a caught hook isn't trusted yet. He tugs it (a key), and it
  either seats (taut, a clear click, safe to climb) or slips and falls. Good
  holds (a post, a solid lip) seat. Poor ones (a crumbly edge, a shallow
  lip) can slip, and an untested hook may give under his weight partway up.
- **Climb:** on a secured rope he climbs hand over hand, slowly, and can
  stop and hang. At the top he hauls himself over the lip. He can let go
  or slide back down.
- **Rappel:** at a top with an anchor he fixes the rope and lowers himself
  down the drop, feet on the wall, in hops. He can stop on the way. At the
  bottom the rope stays fixed, so he can climb back up. A key pulls it down
  after him.
- **Reel in:** he can take back a rope that's been placed (from below, by
  flicking it free; from a top, by pulling it up).

Moves here are procedural on the existing figure (IK hands on the rope,
feet on the wall), stood in for authored clips later. Keep them readable:
the tug, the reach between hands, the haul over the lip.

Out of scope for now, but kept in mind: climbing the rope wearing the
loot bag (weight slows the climb, a heavy bag gets hauled up after him on
the rope). Don't build it, but don't shape the code so it can't happen.

## Where

A new greybox study, `studies/rope_study.tscn` + `studies/rope_study.gd`,
launched by `run-rope-study.command`, built the way `studies/bag_study.gd`
is. It's an empty grey room with:

- a start floor;
- a wall too tall to jump (about 5 m) with a solid lip to hook;
- a taller face (about 8 m) with an anchor post on top;
- an edge with a crumbly lip that slips sometimes, beside a solid one;
- a top with a drop off its far side down to a lower floor (about 8 to
  10 m) to rappel down, with an anchor at its edge;
- a few loot pieces up top and below, so there's a reason to go.

Number keys jump to each spot. Name the pieces through
`scripts/layout_overrides.gd` (`rope_study/<piece>`) and wire the world
view (F4), as the bag study does.

## Done looks like

The user launches `run-rope-study.command` and can:

1. throw the hook at an edge, see it catch or miss, and reel in a miss;
2. tug it to seat it, or see it slip from a poor hold;
3. climb a seated rope up and over the lip;
4. find that an untested hook on a poor hold can give partway up;
5. fix the rope at an anchor and rappel down the drop, then climb back up
   or pull the rope down;
6. toggle his full moveset with a key to compare.

## Tasks

One trunk, no lanes:

1. The room, with the reduced moveset and its toggle.
2. Throw the hook: aim, fly, catch or miss, reel in.
3. The tug: seat or slip, and holds that can give under him.
4. Climb up and over the lip.
5. Rappel down from an anchor, and pull the rope down.
6. A light tuning pass from play, then the handoff (`docs/design/rope/
   handoff.md`).

## Rules

- Greybox. Grey boxes, no dressing; the rope a simple procedural line
  (segments or a curve that sags when slack and goes straight when taut).
- Prototype: a smoke check (`tools/smoke.py` on `studies/rope_study.tscn`),
  throwaway drivers in `scratch/` through the real play loop
  (`tools/drive.py`), rendered stills (`tools/shot.py`, `-- --no-title`).
  No committed tests, no full suite.
- New controls get a key and a pad button and a short hint line. Keep
  changes to shared files (`pilot_motor.gd`, `pad.gd`) small and additive.
  The reduced moveset uses the motor's own gates (`wall_on`, `ledge_on`,
  `sail_on`, `rope_on`). Existing scenes play as before.
- The motor's existing swing ropes (`rope_on`) are a different thing.
  Read them for anything reusable, but this rope is the wanderer's own.
