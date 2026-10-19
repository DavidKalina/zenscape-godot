# Handoff: picking up and carrying things (loop `carry`)

Spec: `spec-carry.md`. Trail: `git log --grep='^ITER(carry)'` on branch
`iter/carry` (worktree `/Users/davidkalina/Documents/Projects/zenscape-carry`),
ten tasks and two spec changes (the towed sling; the haul home, tasks 7–10), not
merged.

## Play it

`./run-wreck-cluster.command -- --plane-fixed` from the worktree (drop
`--plane-fixed` to play with the plane broken; loading still works, flying
doesn't). E (pad B) lifts, sets down and loads. N re-deals.

## What's built

- **Treasures** (`wreck_cluster/treasure_NN`): a jade idol (light) on the
  spine's south bench, a terracotta urn (medium) in the cella, a dragon egg
  (heavy) on the knight's causeway, a gold chalice (light) on the tower
  lookout. All on stone: the grass carpet buries anything under about 0.6 m.
- **Lift and carry:** crouch and reach, strain, a heave timed to the load
  (0.6 / 0.95 / 1.45 s), settle. Light and medium at the chest, heavy in a low
  hug. Crouched set-down.
- **Weight** (one table, `scripts/carry/carry_weights.gd`): pace 4.16 m/s empty,
  3.62 light, 2.86 medium, 1.87 heavy. Medium bars the wall moves; heavy also
  bars ledges, sail and ropes, and sways the camera and thuds. A refused move
  balks (lurch, head shake).
- **Dropping:** a knock, a stun or a fall over about 5 m knocks the treasure
  loose; it tumbles and comes to rest, never pushing the player. Off the isle
  it is lost until N.
- **The bag:** a burlap-and-net sack on a rope under the plane's belly, lying
  on the turf behind the parked plane. E loads a carried treasure or takes
  the last one out. It swells with the weight inside (0.40 to 0.95 m) and its
  rope lengthens (2.6 to 5.35 m), so a full bag hangs low and swings wide. It
  collides with the world; a hit of 3 m/s spills the last-loaded treasure and
  each further 3.5 m/s one more. Spills on land come to rest to be fetched;
  over open sky they're lost for the deal.
- **The stretch:** a 700 m (about 45 s) flight west off the strip's rim:
  floating rocks, two spires (10 m gap), islet_a (109 m landing run), a broken
  three-arch aqueduct to fly through, drifting debris, a lone span, islet_b
  (94 m run), a rock arch (8 m gap). Pieces `wreck_cluster/stretch/<piece>`,
  islets `island/stretch_islet_a|b`. `--no-stretch` leaves it out.
- **Load:** the bag's kg feeds the `--heavy` weight model plus new takeoff
  settings: longer roll, slower climb, mushing pull-ups, turns that swing on.
  Over 20 kg it won't lift off and stops at the rim (the four treasures are
  25 kg, so two trips). A label says "Too heavy to fly". Table `LOAD`.
- **Strain:** builds from tight turns, pull-ups, bumps and bag hits, scaled by
  the load, and eases at a fixed rate (an empty plane never breaks). Shown on
  the plane: creaks, wings bowing up (opt-in shader `flex`), rattle, a
  labouring engine. At the break a part tears off and the engine dies; the
  plane glides down and won't take off till the part is fitted. The part
  lies where it lands, or on a free cluster part spot if it falls into the
  sky. A broken plane sunk into the cloud, or parked over 150 m from its
  part, is hauled home. Tables `STRAIN` and `TEAR`.

## Stood in

- Lift, carry, balk and load poses are procedural on the existing rig;
  Blender clips come with lock-in.
- The motor gained move switches (wall, ledge, sail, rope) and a `refused`
  signal, all on by default.

## Open

- Tuning to judge in play: near 20 kg the plane's path lags the nose by
  31–36°; a full bag breaks the plane in about 6.5 s of full turn, and one
  bump with a full bag takes it about halfway.
- Untested in play: landing the broken plane on an islet and finding its part
  there, the 150 m haul home, strain from bumps and bag hits.
- The stretch's islets are flat discs; they want a landform pass.
- The "Too heavy to fly" label is a readout; drop it if the cap should be felt
  only.
- The knight's knock is mostly upward on a narrow causeway, so the egg often
  rolls off and is lost; the heavy throw in `carry_weights.gd` tunes it.
- A treasure dropped in tall grass is hard to see.
- Walking off an edge while heavy isn't refused.
- Merging with `iter/dig`: both add an action to `scripts/pad.gd` (carry E /
  pad B, dig G / pad Y) and small hooks in `studies/wreck_cluster.gd`; carry
  also edits `scripts/pilot_motor.gd`, `swing_rope.gd`, `foot_pieces.gd`,
  `scripts/sky_plane.gd` and `scripts/manual_landing.gd` (opt-in, neutral at
  no load), and fixes the cluster's missing part sounds.
