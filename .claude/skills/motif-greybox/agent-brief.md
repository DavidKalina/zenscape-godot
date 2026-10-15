# Place agent brief (fill in CARD, SLUG, FOCUS)

Build one motif card as a playable place for this Godot 4.7 game, in the
motif yard. Your card: CARD. Read it, plus
docs/design/motifs/motif-brief.md and AGENTS.md (Prototyping, Sizes, Test
execution, Models).

**Work in this order, and look at each before the next:**
1. **Land.** The landform as `KitLand.island` islands (outline, height
   function whose steps are grabbable cliffs, `hang`, keel), with the turf
   and flora on. Shoot the arrival view. Does it read as the card's Place?
   Fix it before going on.
2. **Pieces.** RuinKit pieces (scripts/ruin_kit.gd and its family files)
   as the card describes. Shoot again.
3. **Routes.** The card's routes, sized from the pilot's real numbers
   (`Trap.pilot()`, scripts/pilot_motor.gd, WorldScale per AGENTS.md
   "Sizes"; fix the card's guesses and say so). Walk each through the real
   input.
4. **Threat.** The card's traps and enemies, if any.

**Templates (read first):**
- scripts/kit_isle/motif_greybox.gd header: the contract a `gb_`
  motif answers (`slug`, `isle_name`, `brief`, `parts()`, `rims()`,
  `spots()`, the registry line). Skip its "copy the study's numbers"
  advice: there is no study; your land is the layout.
- scripts/kit_isle/greybox/gb_sunken_giant.gd: a motif built on KitLand
  islands with turf, flora and life (its `build`, `warm`, `flora_site`,
  `flora_seed`, `life_script`, `_solids`).
- tools/README.md, "The motif yard": how the yard stands one motif.
- scripts/traps/*.gd, scripts/enemies/*.gd, scripts/cannon/ for threats.

**Deliverables:**
- scripts/kit_isle/greybox/gb_SLUG.gd and its line in
  scripts/kit_isle/greybox/registry.gd. No `class_name`; preload by path.
  The layout in ONE const data table near the top (islands: outline, tiers;
  pieces, traps, enemies: place and facing), built from that table.
- A missing kit piece or mechanic (the card's "Kit asks") gets the nearest
  stand-in, labelled "STAND-IN: ...". Do not edit any existing file other
  than the registry (motor, traps, enemies, cannon, KitLand, RuinKit). If no
  stand-in works, leave the gap labelled.
- Append "## Place (round N)" to the card: yard command, the routes, the
  threat, real vs stand-in, distances you changed, your read of the stills,
  and the model-budget tricks that apply (docs/art/model-budget.md).

**Prove it.** Use the harness (tools/README.md); don't hunt for Godot or
write your own runner. Headless for everything but stills.
1. Smoke: `python tools/smoke.py studies/motif_yard.tscn -- --motif=SLUG`.
   It must PASS.
2. Stills, one window at a time, watchdog-closed: `python tools/shot.py
   studies/motif_yard.tscn --frame Motif_gb_SLUG --view three -- --motif=SLUG
   --sky`. Look at them yourself and iterate.
3. Routes through the real play loop: `scratch/SLUG_routes.gd` extending
   `tools/harness/drive.gd`, run with `python tools/drive.py
   scratch/SLUG_routes.gd -- --scene-args --motif=SLUG` (the driver calls
   `open("studies/motif_yard.tscn")`, as tools/harness/chain.gd does): `walk_to` and
   `jump` along each route through the input, rim in to rim out. Check
   every trap and enemy builds and ticks. Then FOCUS. Report honestly what
   you could and couldn't verify.

Do not commit. Final reply (200 words or fewer): yard command, the routes,
the threat, real vs stand-in, the still paths, what you couldn't verify.
