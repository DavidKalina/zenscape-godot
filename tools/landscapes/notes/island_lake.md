# Island lake (takes 1 to 3)

**Intent:** a broad lake basin, one island in it with a single oak, water
filling round it. Also a test: can a Chisel drag raise a levee or dam?

**Recipe:** `tools/landscapes/island_lake.gd`. Paddle at size 3: hold-swell
down to -1.2 m (the floor) at (0,-1). Take 1: Modeller pinch for the island
to 1.6 m. Takes 2-3 (in the script now): a Shift Paddle swell to 0.7 m. Oak
sown by a short drag across the island. Water poured twice in the lake.
Dam: Chisel drag at z=+4 across the lake's near end from the west shore
(take 1 pressed on bare shore at 0.42 m; takes 2-3 first heaped a Shift
Paddle mound to 1.4-1.6 m and pressed on its top). Another pour behind it.

**Stills:** /private/tmp/zs-landscapes/island_lake-take1/, island_lake-take2/
and island_lake/ (take 3): 01-shaped, 02-lake, 03-island, 04-dammed, 05-dam.

## What came out
- **Basin:** the swell-down hits the -1.2 m clay floor after an 18-21 px pull.
  A broad, smooth bowl about 15 m across. Fine.
- **Island:** the Modeller pinch made a steep bare **cone** (1.73 m, 0.29 m
  two metres out). Reads as a rock spike, not an island. A Shift Paddle
  swell made a low green mound (0.84 m), which is the right shape.
- **The oak is not controllable.** Seeds go to the wind. Take 1: nothing on
  the island. Takes 2-3: the island grew a pine, a birch or a layered tree
  plus grass, **never an oak** (oak sows as "broadleaf"). "One oak on the
  island" is not a thing a player can do.
- **Lake:** 10-15 m³, 0.45-0.78 m deep, and the island stays dry. But the
  lake **barely reads**: fog sits on it (milky haze in 02/03) and by 20 s at
  4x a forest of 100+ trees closes round and over it. From the overview,
  04-dammed, the lake is a grey smudge in a forest.
- **Levee test: the Chisel makes a causeway, not a levee.**
  - Take 1, pressed on the 0.42 m shore: a dead-level shelf at 0.42 across
    the lake (`0.42 0.42 ... 0.42`, fill up to 0.8 m over the lake floor).
    The face goes downhill toward the camera, so the near side was **cut
    down** to -0.58 m. The dam holds (2.1 m³ behind, 0 below), but on screen
    it reads as a **trench** with a step, not a raised bank.
  - Take 3, pressed on a 1.57 m mound: the shelf can only fill 1.2 m below
    its press, so across the lake it **stepped down twice**
    (1.57 -> 0.57 -> -0.43) and the downhill face cut the far side to -1.3.
    The crest over the lake ended up 0.17 m above the water. A chisel shelf
    can't stand proud of the ground on both sides: it always cuts a face on
    one side.
- **Dead presses.** Take 2's mound hold and its chisel drag at (-9.5, 4) did
  nothing. Take 3 logged a layered_tree and a shrub under that spot. One step
  aside (0.7 m) the hold worked at once. In a grown world, presses on trees
  are silently swallowed by shaping tools, and trees are everywhere.

## How the tools felt
- Paddle swell-down is the obvious basin verb and it is good. Rim pull-up
  (random basin) was not tried: it places the basin randomly, and this
  build needed one in a known place.
- Modeller pinch vs Paddle Shift swell is a real choice, cone vs mound. Good
  differentiation.
- The Chisel as a dam builder is a workaround that needs knowing the rules
  (FILL_MAX, the downhill face). It is not a levee.

## Gaps
- **A line-raising verb (levee/dam/ridge/rampart) is confirmed missing.**
  The Paddle sweep's ridges are 0.38 m side-effects; the chisel shelf cuts
  one side; nothing raises a bank above ground on both sides.
- Placing **one specific tree** at a spot (planting, not sowing).
- Water visibility under fog, and a way to keep life back from a shore.
- Presses on props should fall through to the land for shaping tools, or
  show why they didn't.

## Scores
Buildable 3/5 · Looks 2/5 (fog and forest hide it) · Matched intent 2/5

## Harness wishes (from this group's four builds)
- `still()` leaves the hover label and selection ring of whatever was last
  under the pointer in the shot ("Tree", "Perch", "Broadleaf" in take 3's
  stills). It is not a CanvasLayer, so the hide loop misses it.
- `settle()` does not wait for the tool's own `busy()` (the hammer's
  recoil), so back-to-back hammer gestures can be eaten.
- A `press_ok()` check or a retry-aside helper for presses that land on a
  prop. Every build that runs life before shaping will hit it.
- run.sh's `grep | head -120` fills with the `!v.is_finite()` flood, so the
  LANDSCAPE lines after about 45 s never print. Read report.txt instead.
- `view()` zooms in, and gestures after it aim at off-screen plate points
  and silently do nothing. Have gestures return the camera to the overview,
  or warn when a point is off screen.
