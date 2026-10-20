# Spec: swinging on the rope from beams (greybox study)

Loop slug `rope-swing`, branch `iter/rope-swing`, cut from `iter/rope` (the
climbing rope, `docs/design/rope/handoff.md`). Cap and budget: the skill's
default.

## What it is

The wanderer's own rope (`scripts/rope/climb_rope.gd`: throw, catch, tug,
climb, rappel) can also be hooked over an overhead **beam** and swung from,
to cross gaps he can't jump.

- **Hook a beam:** the same hold-to-aim and release as the climb throw.
  The reticle snaps to beams overhead within reach and shows gold when
  the hook will wrap over one. The hook wraps round the beam; a tug seats
  it as now (a beam is a solid hold).
- **Swing:** take hold (Space by the rope, as the climb) and step or jump
  off an edge, and he swings as a pendulum under the beam. The stick
  along the swing pumps it for more height. Climbing up or down the rope
  while swinging shortens or lengthens it (faster and tighter, or longer
  and further).
- **Let go:** Jump releases him with the swing's velocity, so timing the
  release decides where he lands. Releasing at the top of the forward arc
  carries him furthest.
- **Chain:** from a landing (a platform, a ledge) he throws again at the
  next beam. Throwing mid-swing to chain beams in the air is **out of
  scope** for this loop, a possible later round.
- **The rope after:** a rope left on a beam hangs there; he can reel it in
  from the far side (it slides off the beam back to him) or leave it.

Reuse the motor's existing swing-rope pendulum (`rope_on`, the fixed swing
ropes in `scripts/pilot_motor.gd`) where it fits; this rope is his own
thrown one. Moves are procedural on the existing figure (IK hands on the
rope), stood in for authored clips.

## Where

A new greybox study, `studies/swing_study.tscn` + `studies/swing_study.gd`,
launched by `run-swing-study.command`, built the way
`studies/rope_study.gd` is (same reduced moveset and M toggle, numbered
stations, `swing_study/<piece>` names through `scripts/layout_overrides.gd`,
F4 world view). It's a grey room with:

- a start floor and a gap too wide to jump, one beam over its middle (one
  swing across);
- a wider crossing with two beams and a small platform between them (swing,
  land, throw, swing);
- beams at a few heights and spacings, including one too high to reach
  and one so low the swing scrapes the floor;
- a pit under the crossings to fall into on a bad release, with a way back
  up (a rope-able wall or a ramp).

## Done looks like

The user launches `run-swing-study.command` and can:

1. hook a beam and seat it;
2. swing across the first gap, pumping for height, and release to land;
3. lengthen or shorten the rope mid-swing and feel the difference;
4. cross the two-beam course: swing, land on the platform, throw, swing;
5. fall into the pit on a bad release and climb back out;
6. reel in a rope left on a beam.

## Tasks

One trunk, no lanes:

1. The room, with beams, gaps, the pit and the stations.
2. Hooking a beam: aim, wrap, tug.
3. The swing: take hold, swing off an edge, pump, release with momentum.
4. Rope length while swinging, and the two-beam course end to end.
5. A light tuning pass, then the handoff (`docs/design/rope-swing/
   handoff.md`).

## Rules

- Greybox. Beams are plain grey bars.
- Prototype: a smoke check (`tools/smoke.py` on `studies/swing_study.tscn`
  and `studies/rope_study.tscn`), throwaway drivers in `scratch/` through
  the real play loop (`tools/drive.py`), rendered stills (`tools/shot.py`,
  `-- --no-title`). No committed tests, no full suite.
- Keep the rope study playing as before. Changes to `climb_rope.gd`,
  `pilot_motor.gd` and `pad.gd` stay small and additive.
- Pace: the user found the first rope rounds a little slow and liked them
  faster. Make the swing snappy from the start.

## Task 5: tuning and the handoff (spec change)

The user played rounds 1 to 4: "super fun". Keep the feel; fix only:

- **Release:** the boost overshoots (lane A lands about 10 m past the far
  edge). Soften it so a good release lands on the far deck, not far past.
- **The platform:** widen the landing window on lane B's platform (about
  0.1 s now) without making it automatic.
- **Camera:** don't stare up at his hat when he's climbed high on a short
  rope; keep the swing and the landing in view.
- **Hint:** the "Swinging" hint clears once he lands.
- **Throw with a rope still on a beam:** the throw reels it in and aims in
  one go (no separate F first).
- **The hook line:** make what the hook wraps over a generic **hook line**
  (a segment with its swing clearance), which beams provide. A branch, a
  rock spur or an arch can then be made swingable later by giving it a hook
  line, with no change to the hook or swing code. No new pieces here; just
  the contract, used by the beams, and described in the handoff.
- **The handoff** (`docs/design/rope-swing/handoff.md`, from the trail):
  what's built, the controls, where to play it, what's stood in, what's
  open (mid-air chaining is a possible later round).
