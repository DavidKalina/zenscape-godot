# Spec: five places (loop `five-places`)

Five new built places on seed 1's home land, each in ground that has nothing
built today. Each is a lane: one agent, its own worktree, its own files. There
is no trunk beyond merging the lanes and adding the places to the map page.

All five are ruins in the temple kit's stone (docs/design/temple-kit). The
citadel (2ea66132) and the hillside sanctuary (5de2fdc7) are the pattern for
how a place is built, placed and streamed.

## Lanes

Coordinates are world metres, x then z, north is -z. Each lane picks its exact
spot inside its box from the land, and keeps 300 m clear of any existing site
or find.

| Lane | Place | Box (x0..x1, z0..z1) | What you fly |
|---|---|---|---|
| `viaduct` | Two tiers of arches about 1 km long across low ground, some spans fallen | -4200..-1800, -5000..-2600 | Thread the lower arches at grass height, weave between the tiers, cross through the fallen spans |
| `harbour` | A harbour on the inland sea: breakwater, quay, a row of ship sheds open at both ends, and a colossus astride the harbour mouth, broken off at the chest, its arm and head in the shallows | 700..2200, -2700..-1400 | Between the colossus' legs, along the water, in one end of a shed and out the other |
| `dome` | A great rotunda on a hilltop, the eye open at the top and part of the wall fallen away | -1900..-700, -3300..-1800 | Dive in through the eye and out through the breach, or the other way |
| `bridge` | One huge single arch over a ravine or narrow inlet, the deck broken | 1200..3600, -400..2400 | Under the arch, and a tighter pass through the gap in the deck |
| `windmills` | A ridge of stone tower mills with turning sails | -2200..0, 3000..5000 | Along the ridge, timing a pass through or past the sails |

## Every lane

- Seen from 2 km it has a silhouette worth turning towards.
- Every fly-through opening is at least as wide as a colosseum arch (12.8 m)
  and is flyable by hand: proved on medium weight, with and without Boost, on
  lines offset from the centre, not one exact line.
- The land is not reshaped unless the place cannot sit without it; a small
  flattening the way the existing sites do it is fine.
- It streams the way the citadel and sanctuary do, with no build spike on the
  main thread as you approach.
- Proof: smoke check, a throwaway drive through the real play loop, rendered
  stills from 2 km, from the approach and from inside each fly-through.
- Its code is in its own new files; edits to shared files are small and
  additive and listed under Notes for merge, with the place's name and centre
  for the map page.

## Done

All five are on the loop's branch, the smoke check passes, each shows on the
map page, and the user can fly to each from the start.
