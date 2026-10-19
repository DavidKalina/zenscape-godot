# Handoff: picking up and carrying things (loop `carry`)

Spec: `spec-carry.md`. Trail: `git log --grep='^ITER(carry)'` on branch
`iter/carry` (worktree `/Users/davidkalina/Documents/Projects/zenscape-carry`),
six tasks and one spec change, not merged.

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
- **Cargo sling:** a rope-net basket on a 2.6 m rope under the plane's belly,
  lying on the turf behind the parked plane. E loads a carried treasure (holds
  4) or takes the last one out. In flight it swings as a pendulum with the
  treasures visible.

## Stood in

- Lift, carry, balk and load poses are procedural on the existing rig;
  Blender clips come with lock-in.
- The motor gained move switches (wall, ledge, sail, rope) and a `refused`
  signal, all on by default.

## Open

- The sling has no collision but a ground ray: in flight it passes through
  walls and arches. Its swing still wants judging in play.
- The load doesn't change the plane's flight (the `--heavy` work).
- The knight's knock is mostly upward on a narrow causeway, so the egg often
  rolls off and is lost; the heavy throw in `carry_weights.gd` tunes it.
- A treasure dropped in tall grass is hard to see.
- Walking off an edge while heavy isn't refused.
- Merging with `iter/dig`: both add an action to `scripts/pad.gd` (carry E /
  pad B, dig G / pad Y) and small hooks in `studies/wreck_cluster.gd`; carry
  also edits `scripts/pilot_motor.gd`, `swing_rope.gd` and `foot_pieces.gd`.
