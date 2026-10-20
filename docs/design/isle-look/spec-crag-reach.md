# Spec: crag reach (ITER(crag-reach))

Builds on the islet unit's three rounds (`islet-unit-handoff.md` beside this
file): IsletUnit with the crag style (`scripts/kit_isle/islet_crag.gd`,
`islet_debris.gd`, `shaders/islet_crag.gdshader`), KitFlora's lush grass,
and the yard `studies/islet_yard.tscn`. The yard stays as it is.

## What the user asked

They like round three's silhouettes and want, in that crag style:

- **Larger land masses** on the scale of the aqueduct isle
  (`studies/aqueduct_isle.gd`) or the colonnade spine
  (`studies/colonnade_spine_isle.gd`), reimagined in the new style: tiered,
  terraced crag masses with buttresses, overhangs and hanging fangs, lush
  grass growing out of the rock, not a flat slab with a skirt.
- **Architecture** that ties them into a sprawling place: rope bridges
  between masses, fallen pillars spanning gaps that you can slide along,
  aqueducts, ruins and colonnades on the masses.
- **Less floating debris.** Round three has too much in the air. Keep it
  gathered under and near the masses, far fewer strays between them.

## Done looks like

`run-crag-reach.command` opens `studies/crag_reach.tscn` with you on foot
on the main mass. Around you:

1. 3 to 5 big crag masses, at least one the aqueduct isle's size, at
   different heights, with smaller crag islets between and around them.
   The main mass keeps a clear stretch of landing turf long enough to land
   the plane by hand (AGENTS.md, Landing turf), and the plane is parked on
   it if the aqueduct isle's parked plane can be reused cheaply.
2. Walkable routes between masses through the real motor: at least one
   rope bridge (`scripts/rope_bridge.gd`, `scripts/footbridge.gd`), at
   least one fallen pillar across a gap that the run slide
   (`scripts/pilot_motor.gd`, move "slide") carries you along, and at
   least one aqueduct (`scripts/ruin_kit_aqueduct.gd`) running between or
   along masses. Use existing pieces; a new movement mechanic is out of
   scope (say so in Notes if the pillar slide needs one).
3. Ruins and colonnades from RuinKit seated on the masses' terraces, so
   the masses read as built-on and lived-in once, not bare rock.
4. Debris cut to roughly a third of round three's, gathered under the
   masses; small islets still at many distances for depth.
5. From a far still, the whole reads as one layered, sprawling place:
   masses overlapping in depth, architecture spanning between them.

## Rules

- Every mass, islet, bridge, pillar and aqueduct gets a stable name via
  `scripts/layout_overrides.gd` (`crag_reach/<piece>`), so the user can
  move them in F4; procedural pieces show their knobs.
- Shared code (KitFlora, RuinKit, KitLand, rope bridge, motor) changes
  only additively or opt-in; the aqueduct isle, colonnade, yard and saved
  motifs build as before.
- Sizes from `scripts/world_scale.gd` (gaps, openings, steps).
- Keep the crag look: palette, rock shader, grass ending at the stone.

## Checks (every iteration)

- `python3 tools/smoke.py studies/crag_reach.tscn` passes; from the task
  that touches shared code on, also `studies/aqueduct_isle.tscn` and
  `studies/islet_yard.tscn`.
- Routes: a throwaway drive (`scratch/`, `tools/drive.py`) that walks a
  bridge, slides a pillar and crosses to another mass with real input.
- Stills (`tools/shot.py`, `-- --no-title`): far, mid, and the route
  pieces close. Look at them and fix what reads wrong.
- No committed tests (prototyping).

## Loop

Model Opus. Cap: the skill's default. One task per iteration, each ending
in something the user can look at (a still or the launcher). No lanes:
masses come first, then the pieces that span them, then dressing and
debris.
