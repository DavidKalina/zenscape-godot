# Spec: lock-on and gust shot (loop `lock-on`)

Trail prefix: `ITER(lock-on):`. Cap: the skill's default. Prototype round:
smoke checks and throwaway play-loop checks, no committed tests.

All of it lives in the main game: `studies/zenscape.tscn` with
`-- --no-title` (on foot beside the parked plane on the aqueduct isle,
`studies/aqueduct_isle.gd`, `scripts/kit_isle/`).

No lanes: the three parts build on each other, so this is one trunk.

## What done looks like (what the user plays)

1. **A target.** A lock-on target stands on the turf within a short walk of
   where the wanderer starts beside the plane, clearly visible from the
   start. A simple placeholder object is fine (a standing stone, post or
   dummy that matches the isle's weathered stone look), sized from the
   wanderer (`scripts/world_scale.gd`). It must not take away the plane's
   landing stretch (AGENTS.md, Motifs). It answers a hit visibly (a rock,
   wobble, puff or knock) so the shot reads.
2. **Lock-on (pad R3, right stick press; keyboard: a free key, e.g. Tab or
   middle mouse).** On foot, pressing R3 with a target in range and roughly
   in view locks onto it; pressing again, or the target going out of range
   or out of sight long enough, releases. While locked:
   - the camera keeps the target framed with the wanderer (the right stick
     no longer free-looks, or only nudges), easing in and out, never
     snapping;
   - a **depth-of-field** effect: the target and wanderer sharp, the
     background (and very near foreground) softly blurred, fading in on
     lock and out on release;
   - a small marker on or over the target shows it is locked.
   R3's old on-foot binding (`overview`, scripts/pad.gd) gives way on foot
   in this scene if they clash; flying keeps `fly_camera` on R3.
3. **Gust shot (pad X).** On foot, when the updraft charge
   (`scripts/updraft.gd`) is at least its release threshold, X spends the
   charge and launches an air gust ball: the dragon's air blast look and
   burst (`scripts/dragon_air_blast.gd`, reuse it or its pieces; the
   wanderer is the shooter, the blast must not knock the wanderer himself).
   - Locked on: the ball flies at the locked target and the hit lands on it.
   - Not locked: it flies where the camera faces (forward, level-ish).
   - Without charge, X does what it does today (the twirl), so nothing
     the user has learned is lost. The keyboard X key matches the pad.
   - A short shooting pose or recoil on the wanderer is welcome; the
     Animation bar in AGENTS.md applies to anything new authored.

## Checks per iteration

- Headless import, then `tools/smoke.py` on `studies/zenscape.tscn` with
  `--no-title`: PASS.
- Lock-on and shot: a throwaway driver through the real play loop
  (`tools/drive.py`, `tools/harness/drive.gd`) that presses the real
  actions: lock acquires and releases, the ball launches only with charge,
  and the locked ball reaches the target.
- Looks (target, marker, depth of field, the ball): rendered stills with
  `tools/shot.py` (`-- --no-title`), looked at before committing.

## Out of scope

Damage, health, enemies that react to lock-on, more than one target type
(several instances of the one target are fine if lock-on cycles among them,
but one is enough).
