# The giants' city: a grey, flyable slice

The real Amberlands gets a new architecture kit: a grand ancient city, big but built
to sit on the land, and not a city for giants. The giant and the city are two things:
the 250 m stomper towers over it and wades through it, and the buildings are what show
his size. (Spec change: the first sizing, for a 300 m person, made pieces too big to fit
the landscape.) This loop builds the first slice in plain grey, with no baked stone, so
that its lines can be flown and judged before anything is spent on looks.

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
- From the air it sits on the hills, and the stomper plainly dwarfs it.
- It looks like plain grey architecture, in simple shapes: no stone, no detail.
- The mourner head dead ahead of the hall's mouth stays in sight on the way out.

## Architecture

Mesoamerican mass with Greco-Roman order: stepped, sloped bulk, carrying columns,
entablatures and proportion. Openings are corbelled (stones stepping in to a flat
or slit top) and trapezoid. No domes, spires or pointed arches, and round arches
only sparingly. No household objects.

Sizes: monumental, and every piece must sit on the hills without swallowing them. Check
each against the land from the air. As a guide: gates about 90 m tall, columns 35-50 m,
pillared hall about 60 m high and 400 m long, pyramid about 350-400 m across and 130 m
tall with stair treads about 8 m high, streets about 100 m wide. The stomper's knee comes
to about the top of a gate. The tight lines keep their width: they are sized to the plane,
so at this size they sit closer together.

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
`clear_of` like `giant_swells.gd`'s for now. Having him wade through the city is wanted
later; the slice need not do it.

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

- `colonnade`: rows of figure-columns (plain stepped shapes for now), the slalom.
- `pillar_hall`: a dense forest of piers under a broken roof, with ways out above.
- `pyramid`: stepped, a stair run up the face, a colonnade on top, a way off the back.

**Trunk (after the lanes merge).** The gate, the columns, the hall and the pyramid
placed in one line from the mouth, tuned so each sets up the next, flown end to end by
both lines. Smoke, then a handoff and a window for the user. The lanes are merged. Trunk
tasks, one iteration each:

1. **The gate at the new size.** `gate.gd` is still the first sizing (340 m door, 410 m
   wall, 22 m slits). Rebuild it to the guide, about 90 m tall, with its two lines,
   and fly both.
2. **The line on the land.** Choose the real spots (`PLACED`) and seat the pieces,
   rechecking each piece's flown heights and notes in its lane commit: the colonnade's
   feet reach 60 m down, the pyramid's door floor stands 10 m over its origin, the hall's
   heights were tuned to its trial site and it needs 1.2 km. The line may bend. Keep the
   mourner in sight, the mouth clear and the route off it. Stills from the air, with the
   stomper in shot.
3. **Link and fly it.** Tune the gaps so each piece's exit sets up the next, and fly the
   wide line and the tight line end to end through a real hall crossing if the harness
   can do it, by stick, with films. Say where a line breaks and fix it.
4. **Depth in the dark.** The shared `GLOW` leaves shaded faces one flat tone inside the
   hall, so depth is hard to read at speed. A plain grey that still shows form, seen in the
   play camera in the dark bays. Grey only: this is not the look pass.
5. **Cost.** Frame time and triangles on screen flying the line, against the build
   without the city. Smoke. Then stop: the handoff and the window are the loop's.

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
