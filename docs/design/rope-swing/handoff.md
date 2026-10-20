# Handoff: swinging on the rope from beams (greybox study)

Spec: `docs/design/rope-swing/spec-rope-swing.md`. Branch `iter/rope-swing`
(cut from `iter/rope`, the climbing rope: `docs/design/rope/handoff.md`),
trail `git log --grep='^ITER(rope-swing)'`.

## Where to play it

`./run-swing-study.command` (`studies/swing_study.tscn`). A grey room, decks
at y 0 over a pit (y -6) that runs under every crossing:

| Key | Spot |
| --- | --- |
| 1 | lane A: a 9 m gap, one beam (7 m) over its middle |
| 2 | lane B: an 8 m gap, a platform (6 x 4.5 m), a 7.5 m gap; a beam (7 m, 7.5 m) over each |
| 3 | lane B's platform |
| 4 | lane C: a 14 m gap, a beam too high (16 m, red) and a tall one (11 m) |
| 5 | a low beam (3.2 m) over the start deck: the swing scrapes the floor |
| 6 | the pit: every deck face is a solid lip, so a bad release climbs out on the rope |
| 7 | far deck A |

R back to start, F1 numbers, F4 world view (pieces named
`swing_study/<piece>`; a moved or turned beam takes its hook line along),
Esc frees the mouse.

## Controls

| Action | Keys | Pad |
| --- | --- | --- |
| Aim the hook (hold), throw (let go); the reticle snaps to a beam overhead, gold when it'll wrap | LMB / T | RT |
| Tug a caught hook (seats it round the beam) | E | B |
| Take hold of the rope over a beam (anywhere within its length) | Space | A |
| Holding it: run off an edge, or jump, to swing; let go on the ground | Space / Shift | A / crouch |
| Pump the swing | W / S along the swing | stick |
| Climb up the rope mid-swing (shorter, faster, tighter) | E | B |
| Slide down it mid-swing (longer, slower, wider) | F | d-pad down |
| Let go with the swing's pace (timing decides the landing) | Space | A |
| Reel in a rope left on a beam (it's yanked over the beam back to him) | F | d-pad down |
| Throw with a rope still on a beam: it's reeled in and, held, aimed in one go | LMB / T | RT |
| Reduced / full moveset | M | d-pad left |

The course: 2, aim at beam B1, let go, E, Space, run off the edge, Space
a little past the plumb (rising), land on the platform, hold LMB (the rope
comes back and the aim starts), aim at beam B2, let go, E, Space, run off,
Space at the far top: far deck B.

## What's built

- **Hooking** (`scripts/rope/climb_rope.gd` `_beam_target`): the reticle
  snaps to the nearest hook line within BEAM_SNAP (2.5 m flat) of it, over
  his head, kept BEAM_END in from its ends. More than BEAM_HIGH (12 m) over
  his feet is red ("too high": the hook comes down on it and slides off).
  The hook wraps over (WRAP_TIME 0.22 s) and hangs under the far side; the
  tug seats it. The play camera tips up toward the beam while aiming.
- **The swing**: the pendulum is the motor's fixed swing rope's own
  (`scripts/interactables/swing_rope.gd`, an instance never added to the
  tree): its pump, steer, MOST, release timing. Holding on the ground he
  takes in the slack (rope as long as his hands are from the beam's top,
  1.4 m to 13 m); the frame he leaves the ground he mounts at that length.
  A face hit keeps a quarter of the pace into it; the floor puts him down
  still holding (the low beam). Body along the rope, hands IK'd onto it.
- **Rope length mid-swing**: E climbs (3.5 m/s), F slides (5 m/s); the
  pace scales by old/new length (momentum round the beam kept).
- **Let go**: Jump, with the swing's own boost and pop (`SWING_BOOST` 2,
  `SWING_POP` 1.5 in climb_rope.gd, swapped in round the swing rope's ride,
  its shared t_boost 6 left alone). Released 2.5-4.5 m past the plumb, lane
  A lands 1.5-5.6 m onto the far deck (was up to 10 m); lane B's platform
  takes releases 2.0-3.5 m past the plumb (was 2.0-2.5, about 0.1 s); 1.5
  falls short, 4.5 overshoots.
- **The camera** (`studies/swing_study.gd` `_swing_view`): holding the rope,
  swinging and in the air after, its polar eases to just over level behind
  him, under the beam: the swing and the landing in view, not up at his hat
  and not drawn in by the beam.
- **The hint** ("Holding the rope", "Swinging: ...") clears when he's back
  on his feet.
- **The rope after**: let go, it hangs off the beam, its end swinging on.
  F reels it from anywhere (flicked over the beam toward him, yanked to his
  hand: 32-57 frames). The throw does the same and, held, starts the aim.

## The hook line (the contract)

What the hook wraps over is a **hook line**, `scripts/rope/hook_line.gd`:
a node, child of the piece that carries it, in the group `hook_line`, with

- `a`, `b`: the segment along the piece's top where the rope rests (in the
  node's frame, so the piece's world-view moves and turns carry it);
- `clearance`: the radius round the line's axis that the hook wraps at and
  the rope runs over (the axis is `clearance` under the segment);
- `piece`: the carrier's piece id.

The rope gathers every visible one (`HookLine.all_in(tree)`) and asks
`line()` for it in world space; the hook, the wrap, the seat, the swing and
the reel don't know what carries it. Beams get theirs from
`HookLine.on_box(body, id)` (along the top of the box collider's long
side, clearance half its thickness). To make a branch, a rock spur or an
arch swingable, add a hook line to it; nothing in the rope changes.

## Stood in

- Moves are procedural on the existing figure (IK hands on the rope, body
  along it), no authored clips.
- Beams are plain grey bars on dark pillars.
- Internally a caught hook line's hold is still called "beam" in
  climb_rope.gd.

## Open

- **Mid-air chaining** (throw while swinging to the next beam): out of
  scope here, a possible later round.
- The swing camera stays low after he lands until the mouse or stick moves
  it; the mouse fights its ease while swinging.
- Throw-to-caught on a 7 m beam is ~95 frames (the flight under HOOK_G);
  the beam reel 32-57.
- A rope left on a beam settles under it out of reach of either deck;
  taking hold of a hanging one (GRAB_REACH) is in but little exercised.
- No committed tests (prototype); the throwaway drivers were
  `scratch/swing_*.gd`.
