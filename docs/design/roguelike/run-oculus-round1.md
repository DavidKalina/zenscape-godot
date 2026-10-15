# Run oculus, round 1

The run's underground now wears the oculus look (warm key, jade fill, mist
sea, crisp flagstones) instead of the torch look the user found drab and dark.

## What changed
- Merged `look/underground-oculus-2` (it was a fast-forward of this worktree's
  base), then merged today's `roguelike` (city layers, crossings, ...): no conflicts.
- `scripts/roguelike/layer_worlds.gd`: `UNDER_LOOK` is `"oculus"` (was `"haze"`;
  the launcher used to force torch). Underground regions of the run take it.
- `run-game.command`: no longer passes `--under-look=torch`.
  `--under-look=torch` (or `haze`) brings the old looks back; `--underground=...`
  still forces a look on every layer.

## Play
`./run-game.command` (the default is oculus), or `./run-game.command --under-look=torch`.

## Stills (seed 2, gameplay camera, driver scratch/tour.gd, git-ignored)
`captures/shots/run_oculus_s2_{landing,isle1_gb_procession,isle2_gb_face,isle3_gb_coliseum_pit,crossing,gate}.png`
and wide stills `run_oculus_s2_three.png`, `run_oculus_s2_close.png`.

## Reads well
Flagstone ground is crisp and warm, grass and the Olmec stone read. Ledges and
rims read: the lit stone edge sits against the lighter teal mist sea, and the
spillway crossing's walls and the causeway edges are clear at gameplay range.

## Weak / open
- No retuning done; the parked branch's open items (joints as crazy paving,
  roof as mosaic, plain far cities, blank sky in the opening) are untouched.
  The close view shows the flagstone joints still read as large crazy paving.
- Far island undersides are very dark against the mist sea.
- Not driven: a trip through the gate into the next layer (a still at the gate
  only); smoke was clean on seeds 1-3.

## The Olmec's sight
`LightLevel.LOOK_AMBIENT` has no `oculus` entry, so the sight reads ambient
0.1 (as the torch look): he still sees the wanderer by his torch and lights, not
by the brighter look. Gameplay is unchanged. Add `"oculus"` there to make him
see by the brighter ambient (not done; not redesigned).

## Tests
None run; no existing test checked for broken. Tests that assume the run's
default look is torch/haze (if any) were not searched for beyond the smoke.
