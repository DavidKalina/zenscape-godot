# Marsh delta (three takes)

**Intent:** a low, wide flat with shallow braided channels fanning across it,
shallow water spreading through the braids, and reeds, cattails and
wildflowers along them. Question: does shallow water read on screen?

**Recipe:** `tools/landscapes/marsh_delta.gd` (take 3 shown). Paddle at size 3:
a swell up at the head (to 1.9 m) for a spring, seven pats over the flat, a
Modeller palm (Shift drag) across the south. Braids: three Paddle narrow
sweeps (Shift, size 1) fanning from the head's foot, plus two cross links.
Two fast Modeller drags to rub the islands between them. One small spring on
the head. Reeds tapped and dragged along the braids, wildflowers on the dry
ground. Earlier takes:
- Take 1: a sunk Paddle hollow (-0.45 m) under the flat, braids drawn with
  the Modeller thumb at size 1, a spring and a burst.
- Take 2: the same hollow, with braids drawn using the Paddle narrow sweep,
  and three pours.

**Stills:** /private/tmp/zs-landscapes/marsh_delta/ (take 3: 02-braids,
03-water, 05-marsh-low, 07-marsh-noon). Takes 1 and 2 are in
`marsh_delta-take1/` and `marsh_delta-take2/` beside it.

## What came out
- **The braids never read as braids.** At size 1 the thumb's groove is still
  0.75 m deep and about 1.6 m wide, because the pips scale width and not
  depth. On a plate that starts 0.0-0.8 m high, three of them meeting at a fan
  dug a jagged brown gully system (take 1: braid beds at -1.0 to -1.3 m). The
  narrow paddle sweep is shallower (0.45 m), but at 2.5 m spacing its ridges
  overlap the next trough. Five of them left one lumpy, churned basin with
  bare-earth facets. In take 2 the ground *between* the braids measured lower
  (-0.82 m) than the braids themselves (-0.33 to -0.59 m).
- **Water:** in takes 1 and 2, every pour ran together into one pond. Take 2
  held 34.5 m³ over 76 m², 1.39 m deep, with the braids as lumpy islands.
  That is a pond with islands, not a marsh. In take 3 there was one small
  spring (4.2 m³). Its course took steepest descent west, off the fan. It wore
  its own pool at (-8.4, -4.1) and **never entered the braids**: 0.00 m³ in
  every braid, and 0.5 m³ over 6 m² on the flat after 25 s.
- **Shallow water does not read well.** Where the water is shallow (the
  spring's pool, take 3), it shows as a pale, glassy sheet with a thin white
  shoreline. It reads only from close. Deeper water is murky and translucent,
  and fish are visible in it. Over every hollow the morning ground mist sits
  as a milky blanket that hides the water in most stills. In take 3 the mist
  covered the whole basin even though the basin held almost no water. It is
  still there at noon (`set_phase(0.5)`).
- **Life:** reeds are good. 27-33 reeds came from a few taps and drags, and
  frogs, frogspawn and lily pads followed into the water. Wildflowers show only
  in the close stills. The flat filled with birch, spruce and broadleaf
  within 25 s at 4x (in take 3, 14 trees on the flat, 32 spruce on the plate),
  which works against a marsh.

## How the tools felt
- **Paddle pat:** good. It flattens without moving earth. Seven pats took
  the flat from 0.6 m of spread to about 0.4 m. Rough, not level.
- **Modeller palm:** it digs. Each pass presses 0.4 m below the press, so
  "flatten" sinks the ground and roughens its rim. In take 2, a slow Shift
  drag also came out as a **fine pinch**. The press sat still too long before
  moving, so the hold-or-drag race (0.3 s, 6 px) read it as a hold.
- **Thumb rub:** two fast zig-zag drags (about 1500 px/s at the overview)
  both registered as "groove" and did nothing measurable. I couldn't get a
  rub out of the scripted pointer. It may be the scripted pointer, but a
  player who whips the mouse is meant to get a rub.
- **Thumb groove vs narrow sweep:** they are differently shaped on paper.
  On screen both read as dark dirt trenches, and at the smallest pip neither
  is fine enough for a channel 30-50 cm across.

## Gaps
- **No shallow mark.** Nothing makes a 10-20 cm runnel. A Shift groove (the
  Modeller's Shift is the palm) or depth that scales with the pips would make
  one.
- **No way to lead water.** A spring follows steepest descent and wears its
  own rill and pool, ignoring channels the player drew. To feed the braids I
  would need to drop water into the fan itself, as a burst, and that floods.
- **Mist hides water.** Ground mist over hollows is a pleasant mood, but
  it makes "does the water read" unanswerable in most stills. The near-white
  haze is the commonest thing in the picture.
- **Life won't stay low.** The world forests every open flat. Nothing
  says "this is wet meadow, keep it open".
- **Harness wish:** stills catch hover labels ("Kohaku koi", "Perch") and
  their rings. These are 3D or world-anchored, not on a CanvasLayer.

## Scores
Buildable 2/5 · Looks 3/5 (reeds and frogs lovely, ground churned) · Matched intent 1/5
