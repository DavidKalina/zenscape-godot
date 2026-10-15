extends RefCounted
## [items_passive] What carried items do to the wanderer's noise
## (scripts/noise/wanderer_noise.gd asks `mul(kind)` for every noise it makes,
## live: an item taken mid-layer works at once).
##   Quiet Soles   steps, slides, grabs, landings hush (x0.45; a slam x0.75)
##   Tithe Bell    everything a little louder (x1.3), and it rings (passive_items.gd)
## Knob: `--quiet=` (0.45) the soles' multiplier.

const RunState = preload("res://scripts/roguelike/run_state.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")

static func mul(kind: StringName) -> float:
	if RunState.current == null or not RunFeatures.on(&"items_passive"): return 1.0
	var m := 1.0
	if RunState.holds(&"quiet_soles"):
		m *= 0.75 if kind == &"slam" else float(RunFeatures.value("quiet","0.45"))
	if RunState.holds(&"tithe_bell"): m *= 1.3
	return m
