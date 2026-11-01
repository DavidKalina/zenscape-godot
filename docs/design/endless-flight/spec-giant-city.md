# The giants' city: a grey, flyable slice

The real Amberlands gets a new architecture kit, sized for the giants: a person
of about 300 m (the stomper's 250 m body plus a 55 m head). This loop builds the
first slice in plain grey, with no baked stone, so that its lines can be flown and
judged before anything is spent on looks.

## Done looks like

Played in the default game, through the hall, on the real Amberlands (`doors`
world, the far side; force `doors._swap(1)` or really cross, or land and look stay
on the home side). `--world=amberlands` is a debug world on other land: never
judge anything by it.

- Coming out of the hall you can fly one linked line: a gate, a slalom of columns,
  a pillared hall, a stepped pyramid with a colonnade on top. Each piece's exit sets
  you up for the next, with no long dull stretch between them.
- Every piece has at least two ways through: a wide, easy line and a tight, risky
  one. No piece is a solid mass you can only fly round.
- All of it is solid to the plane, the camera and the wing rays.
- It looks like plain grey architecture, in simple shapes: no stone, no detail.
- The mourner head dead ahead of the hall's mouth stays in sight on the way out.

## Architecture

Mesoamerican mass with Greco-Roman order: stepped, sloped bulk, carrying columns,
entablatures and proportion. Openings are corbelled (stones stepping in to a flat
or slit top) and trapezoid. No domes, spires or pointed arches, and round arches
only sparingly. No household objects.

True size for what is judged against the body: doors about 340 m tall, stair treads
about 30 m high. Tighter layout than true size: streets about 400 m wide.

## Flying first

The plane flies about 57 m/s level on Boost with a 2.8 m span. Design each piece
from the line through it: gaps, slaloms, height changes, rhythm. The tight line of a
piece is sized with `WorldScale.opening` (scripts/world_scale.gd) or wider, on purpose;
try spacings and keep the one that flies best. Scale alone is not a reason for a piece.

Proof is flying, not stills: a throwaway driver (`scratch/`, on
`tools/harness/drive.gd`) flies each line by stick through the real play loop with no
crash, and a film of the flight is looked at. The user judges feel by playing.

## Keep it cheap

- One Godot node for the whole city, drawn through RenderingServer with shared
  meshes, as `scripts/endless/giant_ruins.gd` does.
- A plain piece is built from simple shapes (boxes, tapered boxes, cylinders), so its
  collision is analytic, through `ground` and `inside` like `giant_ruins.gd`, with a
  bucketed lookup. The plane collides only with the heightfield plus these; physics
  bodies only serve the near-miss wing rays, which need
  `body_attach_object_instance_id`.
- Rough budgets: a wall section 2,000 triangles, a pier 500, a gate 5,000, a hall
  section 3,000, the pyramid 10,000. Every piece gets a far version from day one.
- Pieces in the land are placed with stable names through `scripts/layout_overrides.gd`
  (`city/<piece>`; AGENTS.md, Handles).

## The land

The land's shape stays: hills, steps, water, and flats to land on (AGENTS.md, Meadows
and flats). Pieces sit on it with the bases they need. Keep clear of the hall's mouth
and the ruins, and keep the stomper's route (`stomper_route.gd`) off the city with a
`clear_of` like `giant_swells.gd`'s, or lead it along the avenue if that is simple.

## Plan

**Foundation (one iteration, first).** `scripts/endless/giant_city.gd` and a
`scripts/endless/city/` folder: the one node, drawing and solids from a piece's plain
description, far versions, hooks in `studies/endless_flight.gd` (`ground`, `_blocked`,
camera sight, wing rays), only on the Amberlands side. One test piece, a plain gate,
standing near the mouth, flown through. Write the piece contract at the top of
`giant_city.gd`: each piece is one new file in `scripts/endless/city/`, and adding one
touches the shared files in one line.

**Lanes (run at once, one agent each, in worktrees from the loop's branch).** Each
makes one piece file, with its own flown driver and film:

- `colonnade`: rows of giant figure-columns (plain stepped shapes for now), the slalom.
- `pillar_hall`: a dense forest of piers under a broken roof, with ways out above.
- `pyramid`: stepped, a stair run up the face, a colonnade on top, a way off the back.

**Trunk (after the lanes merge).** The gate, the columns, the hall and the pyramid
placed in one line from the mouth, tuned so each sets up the next, flown end to end by
both lines. Smoke, then a handoff and a window for the user.

## Rules

- Smoke `studies/endless_flight.tscn` every iteration.
- Prototype rules hold: no committed tests, no full suite.
- Windowed runs pass `-- --no-title`. Any play or capture run that needs a save uses
  `--pilot-file=/tmp/<name>.json`, never the real one.
- The native kernels were rebuilt into this worktree; don't copy over them from the
  main checkout, which is older.
- The smoke failure in `stomper-handoff.md` is unexplained. If it comes back, keep the
  whole log and put the message in your commit.
- A loop in `../zenscape-stomper-body` is rebuilding the ruins and changing the stomper's
  body. Stay out of those files beyond one-line hooks, so the two merge cleanly.
- Iteration cap: the skill's default.
