# Spec: kit-breaks

Every kit piece can come down the way the colonnade does: piers, lintels,
arch rings and gables split along real stone joints, fall, and settle into
rubble. Which sources can break things is a toggle. For now only the
Olmec and the slam break things; the plane and the dragon are wired but off.

## Done looks like

- In the colonnade scene (`studies/colonnade_spine_isle.gd`, run with
  `--olmec`), the Olmec breaks the colonnade exactly as before, through
  the shared code.
- In the motif yard, the Olmec breaks ordinary RuinKit pieces (towers,
  halls, aqueduct spans, belfries, cloisters, walls, stairs) at the
  colonnade's quality. No piece has hand-written break code.
- City kit break pieces answer to the same hub and toggles, keeping their
  own choreography.
- The motif editor can mark a piece or a whole motif unbreakable. Saved
  motifs build exactly as before.
- Agents can break things in a headless check with `hit()` in
  `tools/harness/drive.gd`.

## Tasks (all trunk, in order; no lanes: each needs the one before)

1. **Shared breakable + source toggles.** Lift `scripts/kit_isle/colonnade_breaks.gd`'s
   behaviour out of the colonnade into a shared breakable on the
   `scripts/kit_isle/breakables.gd` hub. That behaviour is:
   - cuts along real joints via `masonry_cuts.gd` / RuinKit `Build.keep_only`;
   - the Jolt fall under the 24-body cap;
   - settling to frozen rubble, then `changed(box)` so enemies re-plan.

   Add named breakers with a strength (`olmec` on; `plane`, `dragon`,
   `slam` off) and one entry point, `hit(at, radius, strength, source)`.
   The Olmec's breaker calls (`met`, `wave`, `smash` in
   `scripts/enemies/headless_body.gd`) go through it.

   Proof:
   - The colonnade breaks as before, judged by before and after `film()`
     contact sheets of the same moment.
   - Measure the frame cost of a cut at hit time.
2. **Break points per RuinKit part kind** (pier, lintel, arch, gable, wall,
   stair, and whatever else the kit builds from), so any RuinKit piece
   breaks with no per-piece code.
   - Cut lazily, on the first hit strong enough to break it; until then the
     build is untouched.
   - Per-piece toughness.
   - If the step 1 measurement showed a hitch, pre-cut when a breaker wakes
     nearby.

   Proof: motif yard pieces broken by the Olmec, filmed.

   **Build the part kinds as the public contract for any kit, current or
   future.** A new kit gets breakable by one of these, with no break code
   of its own:
   - **Tag its parts with a break kind.** Kinds are things like `pier`,
     `lintel`, `arch`, `wall`, `slab`, `post`. Each kind owns how it
     splits, falls and settles.
   - **Register one cut function for a new kind.** Do this only when a kit
     has a genuinely new shape (a bell, a hanging bridge, a statue). Every
     piece of that kind then breaks.
   - **Answer the hub itself, with its own choreography.** This is for
     set pieces, as the city kit does.

   The hub, source toggles, `hit()`, the body cap, rubble and the re-plan
   are never a kit's job. Prove the contract by making one non-RuinKit
   shape breakable through a registered kind, in a scratch check.
3. **City kit onto the hub.** `scripts/city_kit_breaks*.gd` and
   `scripts/city_breaks/` join the same hub and source toggles, keeping
   their own choreography. The slam keeps working on them when `slam` is
   on.
4. **Editor toggle and harness.**
   - Breakable on/off per piece and per motif in the motif editor. It must
     be opt-in-safe, keep piece ids stable, and build saved
     `motifs/authored/*.json` as before.
   - `hit()` in `tools/harness/drive.gd` for headless checks; regenerate the
     index with `python tools/drive.py --api --update`.
   - **Teach the contract**, using the `writing-for-agents` skill:
     - a short contract section in the loop's handoff doc (tag a kind,
       register a cut, or answer the hub);
     - one line each where new kit pieces are made: `docs/design/motifs/motif-brief.md`
       (its kit-piece pipeline), and the `motif-greybox` and `motif-turf`
       briefs. The line is: a new kit piece tags its parts with a break
       kind or registers a cut.

## Constraints

- KitLand ground stays solid: no terrain breaking. Every isle keeps its
  landing strip. Flora is out.
- Nothing about a piece's build changes until it is hit (AGENTS.md, The
  motif editor). Smoke a kit motif and an `editor_*` motif in the motif
  yard.
- The aqueduct isle has no Olmec, so it must build and play as before.
- Use the harness: `python tools/drive.py --api` (`route`, `watch`,
  `film`, `shot_at`, `ray`, `what_is_at`).
- Scenes to smoke:
  - `studies/colonnade_spine_isle.tscn -- --olmec`
  - the motif yard with a kit motif and an `editor_*` motif
  - a city yard that uses breaks
  - `studies/aqueduct_isle.tscn`

## Added: frame time (spec change after iteration 7)

5. **No visible stutter.** Do this after task 4, or sooner if it blocks
   anything. A step of a cut built ahead (and a re-cut of what stands)
   cost 100–185 ms a frame in iteration 7. Bring each frame's share under
   about 8 ms. Options: split the stands build further, or run builds on a
   worker thread with the build settings passed per build rather than read
   from shared statics. Prove it with the worst frame over a headless
   `--olmec` run on sundered_gorge, and say whether the machine was loaded.
