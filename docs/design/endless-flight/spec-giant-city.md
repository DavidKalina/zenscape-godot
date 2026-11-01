# The giants' city: a grey, flyable slice

The real Amberlands gets a new architecture kit: a grand ancient city, big but built
to sit on the land, and not a city for giants. The giant and the city are two things:
the 250 m stomper towers over it and wades through it, and the buildings are what show
his size. (Spec change: the first sizing, for a 300 m person, made pieces too big to fit
the landscape.) This loop builds the first slice in plain grey, with no baked stone, so
that its lines can be flown and judged before anything is spent on looks.

## The structure (spec change: the road)

Pieces placed one by one read as stuff thrown on a map, so the city now has one spine.
The land has three rings, each with its own job:

- **The road:** a winding colonnade road from the hall's mouth up to the pyramid, which
  stands on a hill, further out, the shape on the horizon you head for. The road decays as
  it goes: near the gate mostly standing, columns, beams and some roof; then runs of
  columns with spans missing, fallen slabs, drums and stumps; on the climb barely a road,
  scattered columns, heaps and half-buried paving. It must still read as one line
  through the wreckage, pointing at the pyramid. The gate is where it enters the city.
- **Off the path:** the heads, smaller chunks of the civilization, and the pillared hall,
  an optional run you notice from the road (a sight line or a broken spur) and peel off to.
- **The outskirts:** the stomper, on open ground, seen from the road as a shape on the
  horizon. He does not need to cross the road. What breaks the road is age.

What stands at the end of the road, on the pyramid's top, is not decided; don't build it.

## Done looks like

Played in the default game, through the hall, on the real Amberlands (`doors`
world, the far side; force `doors._swap(1)` or really cross, or land and look stay
on the home side). `--world=amberlands` is a debug world on other land: never
judge anything by it.

- Coming out of the hall you can follow one road, bending over the land, to the pyramid,
  with no long dull stretch, and the place reads as one made thing, from the air too.
- Every stretch has at least two ways through: a wide, easy line and a tight, risky
  one. No stretch is a sealed tube: you can always leave and rejoin.
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

**Done, before the road:** the foundation, the three lanes, the gate at its new size and
a first placing (2e2a83e6). `colonnade.gd`'s straight rows of figures are replaced by the
road; the file can stay, out of `PLACED`, or lend its figures as accents.

**The road, one iteration each, in order:**

1. **A road kit, on a short stretch.** Stretches that follow a bending path over the land:
   **open** (columns down both sides, a beam on them, sky above), **roofed** (a low cover
   with gaps of light, still with bays to slip out by) and **broken** (fallen columns, a
   dropped roof, a gap to thread). Lay something under them that reads as a paved road from
   the air. Lay about 600-800 m of it from the gate's far side, all three kinds, bending
   both ways, and fly a wide line down the middle and a tight line that weaves the columns
   and bays. Try column spacing, road width and bend tightness, and keep what flies best.
   Stop for the user's verdict: this step decides whether the idea feels good. (Done at
   96c37a5a; the user flew it: "Solid start".)
2. **The hill.** Find a hill further out and seat the pyramid on it, with what it needs
   under it. Judge the spot by eye in the play camera from the mouth and from the gate,
   with land fully streamed. Show the user the choices; stop for their verdict before any
   road is laid.
   (Done at 8c7c0aa0; the user took spot A and said keep going.)
3. **The whole road.** First cut the pyramid's base right back: it is a wide flat wedge up
   to 575 m across that hides the hill, and the hill must read. The pyramid can't be seen
   from the mouth, and that stays: the mouth keeps the mourner, and the road's first
   swing to the lake's shore is the reveal, the pyramid across the water. Then the route
   from the gate round the shore and up the hill's east side, about 3.4 km by the map, with
   the decay rising along it, mostly the broken kit, still one readable line. Fly it end to
   end, wide and tight.
   (Road done at a0fcc21a. The stomper goes first: he stands by the shore and hides the reveal.)
4. **The stomper to the outskirts.** A smaller range on open ground, off the road.
5. **The hall off the path.** Move it to the side, with its sight line or spur.
6. **Off the path.** Small chunks of ruin, cheap reuses of the road's kit, and the heads
   moved clear of the road. Then cost, smoke; the handoff and the window are the loop's.

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
