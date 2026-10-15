extends RefCounted
## The run's two worlds (docs/design/roguelike/layer-round13-worlds.md): a
## run starts deep underground in the abandoned Olmec city ("under": the
## dark look, the city kit's motifs, the Olmecs, the rune serpent, no plane,
## no dragon) and climbs to the sky ("sky": the old world, the gothic ruin
## kit, the clouds, the plane, the dragon's roost).
##
## Each region (layer) knows its world from its plan's knobs (scripts/
## roguelike/layer_plan.gd KNOBS):
##   region         which region of the run it is (1 the first; 0 outside a
##                  run's count: sky, as every layer was before)
##   under_regions  how many regions from the first are underground (2)
##   world          "under" or "sky" forces every region ("" by region)
## Flags on studies/run_layer.tscn: `--world=under|sky`, `--under-regions=N`
## (or `--knob=world=...`, `--knob=under_regions=N`), and `--region=N` for
## the region a launch starts at. Sprawl and ring keep alternating within
## each world (scripts/roguelike/layer_shapes.gd `after`).
##
## Motifs declare their world in scripts/kit_isle/greybox/registry.gd WORLD;
## an untagged one is sky's. Kept free of the generator's scripts (layer_
## plan.gd preloads this).

const WORLDS := ["under","sky"]
const UNDER_REGIONS := 2
## Underground, the readout is the height under the surface: each region
## underground stands this far (m) below the next, the first sky region's
## start at the run's own climb (scripts/roguelike/run_loop.gd `_readout`).
const UNDER_DEPTH := 250.0
## The look an underground region wears (scripts/underground/underground.gd
## PRESETS); `--under-look=torch` for the other. `--underground=...` still
## forces a look on every layer, sky too.
const UNDER_LOOK := "haze"
## Underground, one motif may come this many times a layer (the pool is thin).
const UNDER_REPEATS := 99

## The world of a layer laid with `knobs`.
static func world_of(knobs: Dictionary) -> String:
	var forced := str(knobs.get("world",""))
	if WORLDS.has(forced): return forced
	var region := int(knobs.get("region",0))
	if region <= 0: return "sky"
	return "under" if region <= int(knobs.get("under_regions",UNDER_REGIONS)) else "sky"

## The world of `plan` (its knobs').
static func of(plan: Dictionary) -> String:
	return world_of(plan.get("knobs",plan.get("user_knobs",{})))

## The region of `plan` (0 outside a run's count).
static func region_of(plan: Dictionary) -> int:
	return int((plan.get("user_knobs",plan.get("knobs",{})) as Dictionary).get("region",0))

## The knobs a region past `plan`'s gate is laid with: the region one on.
static func next_knobs(knobs: Dictionary) -> Dictionary:
	var out := knobs.duplicate()
	if int(out.get("region",0)) > 0: out.region = int(out.region)+1
	return out

## The knobs for `region` (the run's own count, 1 the first).
static func at_region(knobs: Dictionary, region: int) -> Dictionary:
	var out := knobs.duplicate()
	out.region = maxi(region,1)
	return out

## Whether `plan` is the run's first sky region (the climb out of the dark).
static func first_sky(plan: Dictionary) -> bool:
	var k: Dictionary = plan.get("knobs",{})
	if WORLDS.has(str(k.get("world",""))): return false
	return of(plan) == "sky" and region_of(plan) == int(k.get("under_regions",UNDER_REGIONS))+1 and region_of(plan) > 1

## The look an underground region asks (the flags'): haze, or torch.
static func under_look() -> String:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--under-look="): return a.get_slice("=",1)
	return UNDER_LOOK

## How far under the surface (m, positive) region `region` of a run whose
## first `under_regions` are underground begins; 0 in the sky.
static func depth_below(region: int, under_regions: int) -> float:
	if region <= 0 or region > under_regions: return 0.0
	return UNDER_DEPTH*float(under_regions-region+1)
