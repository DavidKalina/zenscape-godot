extends RefCounted
## The two worlds a layer's isles belong to: "under" (the abandoned Olmec
## city: the dark look, the city kit's motifs, the Olmecs, the rune serpent,
## no plane, no dragon) and "sky" (the old world, the gothic ruin kit, the
## clouds, the plane, the dragon's roost).
##
## Each region (layer) knows its world from its plan's knobs (scripts/
## roguelike/layer_plan.gd KNOBS):
##   region         which region of the run it is (1 the first; 0 outside a
##                  run's count: sky, as every layer was before)
##   under_regions  how many regions from the first are underground (2)
##   world          "under" or "sky" forces every region ("" by region)
## Flags: `--world=under|sky`, `--under-regions=N` (or `--knob=world=...`,
## `--knob=under_regions=N`).
##
## Motifs declare their world in scripts/kit_isle/greybox/registry.gd WORLD;
## an untagged one is sky's.

const WORLDS := ["under","sky"]
const UNDER_REGIONS := 2

## Whether `knobs` lay a city (underground) layer with the sky kit stripped.
static func city(knobs: Dictionary) -> bool:
	return world_of(knobs) == "under" and int(knobs.get("sky_kit",0)) == 0

## The danger by height (layer-round14-city-layers.md): 0 on the run's
## first region, rising DANGER_STEP a region to 1. The `danger` knob (0-1)
## pins it. Read by the heads' count (LayerEnemies), the bodies' spawn
## rules (LayerBodies) and the flyers' count (LayerFlyers).
const DANGER_STEP := 0.34
static func danger(knobs: Dictionary) -> float:
	var pinned := float(knobs.get("danger",-1.0))
	if pinned >= 0.0: return clampf(pinned,0.0,1.0)
	var region := int(knobs.get("region",0))
	if region <= 0: return 0.0
	return clampf(float(region-1)*DANGER_STEP,0.0,1.0)

## The world of a layer laid with `knobs`.
static func world_of(knobs: Dictionary) -> String:
	var forced := str(knobs.get("world",""))
	if WORLDS.has(forced): return forced
	var region := int(knobs.get("region",0))
	if region <= 0: return "sky"
	return "under" if region <= int(knobs.get("under_regions",UNDER_REGIONS)) else "sky"
