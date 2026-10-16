extends RefCounted
## Whether a city place lays its own Olmec (its "Keeper"). In a generated layer
## the layer has
## one roaming Olmec (two on the high-danger regions: scripts/roguelike/
## layer_olmec.gd), not one per place, so by default the places' Keepers
## and their own heads stay out; `--knob=olmecs=places` brings the old
## behaviour back (each place its Keeper, the generator's heads by danger).
## Alone in its yard (studies/motif_yard.tscn) or its own study a place
## keeps its Keeper, as designed. Kept free of the generator's scripts (the
## places are preloaded by scripts/kit_isle/greybox/registry.gd, which
## layer_plan.gd preloads).

const LaunchArgs = preload("res://scripts/launch_args.gd")

## The layer's Olmec mode: "roam" (the default) or "places".
static func mode(knobs := {}) -> String:
	if knobs.has("olmecs"): return "places" if str(knobs.olmecs) == "places" else "roam"
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--knob=olmecs="): return "places" if arg.get_slice("=",2) == "places" else "roam"
	return "roam"

## Whether the place live on host `g` (LayerGreybox.Isle) lays its Keeper.
static func keepers(g: Node) -> bool:
	var stage: Node = g.get("stage")
	if stage == null: return true
	var study: Node = stage.get("study")
	# Only a generated layer (run_layer) has the roaming Olmec.
	if study == null or not str(study.get_script().resource_path).ends_with("run_layer.gd"): return true
	var plan: Variant = stage.get("plan")
	var knobs: Dictionary = (plan as Dictionary).get("knobs",{}) if plan is Dictionary else {}
	return mode(knobs) == "places"
