# Balloons: the bounce and the gold balloon's find (prototype round, 2026-11-15)

Follows `handoff-balloons-glow.md`. Branch `lane/reveal-balloon`.

## What's built

- **The bounce** (`scripts/endless/balloon_bounce.gd`, called from
  `endless_balloons.gd` `_bounce`): every balloon's envelope (its two balls,
  as the graze reads it) pushes the plane off. The part of the path going
  into the cloth comes back at 0.45, the nose turned with the path, 22 % of
  the speed lost at a square hit (less glancing), a 7 m/s shove out dying
  over 0.3 s, and the plane set back on the cloth. Under a balloon the push
  is turned sideways and the way out never dives more than about 12 degrees;
  with under 35 m below it or under its way out, it leaves level or rising.
  The basket and ropes stay open (simplest; the plane flies through them as
  before). A touch scores no graze.
- **The balloon answers**: a broad dent where it was hit (new `poke`
  instance uniform in `shaders/balloon_canvas.gdshader`, on a spring: in over
  about 0.2 s, a small bulge back, settled in about 1.5 s), a jolt away of a
  metre or so that bobs back, the rock and the basket's swing.
- **The gold balloons** (`scripts/endless/balloon_odd.gd`): three fixed
  groups of four, seed 1. Three wear one blue and cream striped cloth, the
  fourth is bigger in gold, cream and amber checks, and after dark it is lit
  from inside (a held lantern), so it shows as the orange lantern among
  lavender ones. Bouncing off it calls `finds.anchor("balloon/<name>", p)`:
  the ring appears 24 m off the cloth on the balloon's far side from the
  plane's way out, at the balloon's middle height, and the burner roars.
- **The ring stays where it was let out**: the finds contract reads an
  anchor once, and the groups don't drift with the wind. Each balloon
  wanders 26 m round its own spot, so the ring stays beside the balloon
  while the plane comes round, and the group is where the hint says however
  long the flight. A group is put within 1900 m of the plane, taken past 2600 m.
- **Saved state**: with its find in the book the gold one wears the blue
  cloth like the rest and isn't lit; a bounce does nothing.

## Where they are (finds_table.gd rows, area)

| Site | Middle (x, z) | Row | From the start (0, 0) |
|---|---|---|---|
| meadow | (680, 300) | `gold-balloon` (meadow) | 740 m east-south-east, about 25 s at cruise; turn round from the start's heading |
| south | (0, 2000) | `south-balloon` (south) | 2 km south, over low land by the sound |
| coast | (2120, 2120) | `coast-balloon` (coast) | 3 km south-east |

Fastest: `.\run-endless-flight.cmd --fresh`, turn right round to the east
and fly about 700 m; the gold one floats about 24 m up.

## Proof (scratch drivers, not committed)

- `scratch/bounce.gd` through the real loop and the stick, medium weight:
  side, from below (a high and a low balloon), from above, and held into
  it, at cruise and with Boost (35 to 60 m/s in). Every case came off
  flying, never inside the cloth after (least 1.2 m), no crash from the
  bounce, speed after 1.5 s 86 to 97 % of before, each balloon settled.
  The gold one let its ring out, the ring was flown, the book had it; a
  second run on the same book: the find held, the gold one was plain, a
  bounce let nothing out. `scratch/sites.gd`: all three sites the same.
- `tools/smoke.py studies/endless_flight.tscn`: PASS.
- Stills in `scratch/shots/reveal_*` (day: group, dent, ring; night: group).

## Open

- Nobody has flown it by hand. A driven pilot can't tell whether the snap
  of the nose onto the new path (one frame, the chase camera following)
  feels soft enough, or whether the shove and loss are right. Knobs:
  `RESTITUTION`, `LOSS`, `KICK` in balloon_bounce.gd; `POKE`, `JOLT` in
  endless_balloons.gd.
- The dent reads in a still from the hit side; from square across it is faint.
- At night the plain cloth glows lavender, the gold orange and brighter;
  close enough to tell, but a stronger night tell (a steady flame) is an option.
- A headless driver's exit (Godot's quit) hangs to the tool's timeout in
  this tree; the drivers kill themselves after their RESULT line.
