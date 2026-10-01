# Rice terraces (takes 1 and 2)

**Intent:** a flight of paddy terraces stepping down the flank of a big hill,
water poured at the top running down from terrace to terrace.

**Recipe:** `tools/landscapes/rice_terraces.gd`. Paddle at size 3: hold-swell
up to 5 m at (0,-2). Chisel at size 2: drags as arcs round the crown on the
camera side, top first. Take 1: four arcs at r 2.4/4.2/6.0/7.8, full depth,
±1.4 rad. Take 2 (in the script now): six arcs at r 2.0..8.5 every 1.3 m,
Shift (shallow), ±1.9 rad. Water poured on the crown (3 s), 20 s at 4x.

**Stills:** /private/tmp/zs-landscapes/rice_terraces-take1/ (02-terraced,
03-terraces-low, 05-water-low) and rice_terraces-take2/ (same names).

## What came out
- **Take 1 is the good one.** Transect from the crown toward the camera:
  `5.19 4.87 4.49 | 3.62 3.33 | 2.04 2.04 | 0.97 0.97 0.73`, i.e. four level
  shelves with ~1.2 m rock risers. From the low view it reads at once as a
  stepped hill: crisp granite risers, green shelf tops, dirt on the benches.
  More ziggurat or quarry than paddy: the risers are as tall as the shelves
  are wide, and they are bare rock.
- **Water does step down, a bit.** The crown pour became a spring that
  cascaded over the shelves as a chain of small falls (pretty in
  05-water-low). Each shelf held only 0.17-0.28 m³ (0.07-0.36 m deep pockets);
  nothing pooled across a shelf. Shelves are dead level with no lip, so water
  crosses them and falls off the next riser. Total plate water 5.2 m³.
  Headless the same recipe sent the water straight off the side (0 m³ on
  every shelf): the sim is not stable run to run.
- **Arc ends leave fins.** Where an arc stops mid-slope, the shelf's fill
  and the downhill face cut leave thin standing blades of rock (right of
  03-terraces-low, take 1). Looks broken rather than designed.
- **Take 2 was worse.** Closer, shallower rings chewed into each other's
  benches: steps of `4.56 4.52 4.24 | 2.74 | 1.98 1.77 1.65 | 1.21`, one 1.5 m
  drop and several 0.1-0.4 m nicks. Reads as rubble, brown and lumpy. Water
  spilled off one side to the plate edge (an edge fall) and the shelves held
  0.04-0.12 m³.

## How the tools felt
- **Chisel shelf is the right verb** and the "level at the press height"
  rule is predictable once known: press higher up the hill to get a higher
  shelf. It is the only tool here that makes a deliberate step.
- **Fighting it:** the press height comes from the pointer's spot, and a
  press near an earlier face snaps to the bench below (FOOT_REACH), so close
  terraces cannibalise each other. Spacing has to be at least ~1.8 m (shelf
  plus bench plus ramp) or the flight degrades. The player has no feedback
  for that spacing.
- **Shift (shallow)** halves the face but not the bench/ramp footprint, so it
  makes terraces messier, not finer.

## Gaps
- No **lip/bund** on a shelf: a paddy needs a raised rim at the outer edge to
  hold water. Without it, terraces cannot hold ponds, which is the point.
- No way to make the riser **earth/grass** instead of granite. Every chisel
  face is rock.
- No **closed-ring** behaviour: an arc's open ends need trimming; a full ring
  would need the face to know "outward".

## Scores
Buildable 4/5 · Looks 3/5 · Matched intent 2/5 (stepped hill yes, paddies no)
