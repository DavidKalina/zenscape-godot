extends RefCounted
## The greybox motifs the generator can place (docs/design/roguelike/
## greybox-in-generator.md; the base is scripts/kit_isle/motif_greybox.gd,
## whose header says how to convert the next one). One line each: slug ->
## script. Opt-in on the layer's knob `greybox` (scripts/roguelike/
## layer_plan.gd KNOBS): "" none (the default: the pool as it was), "all",
## or a comma list of slugs; `greybox_force` 1 (the default) makes every
## layer hold at least one (its first draw is one, and a plan without one
## placed is laid again), 0 leaves them to the draw.
## Kept free of the generator's scripts (layer_plan.gd preloads this).
const MOTIFS := {
	"sunken_giant":preload("res://scripts/kit_isle/greybox/gb_sunken_giant.gd"),
	"wardens_well":preload("res://scripts/kit_isle/greybox/gb_wardens_well.gd"),
	"lidstack":preload("res://scripts/kit_isle/greybox/gb_lidstack.gd"),
}
## A greybox motif's weight in the draw (the pool's own run 1-3), and how
## many times one may come a layer.
const WEIGHT := 3.0
const MOST := 1

## The slugs a layer's knobs ask for (unknown ones warned).
static func wanted(knobs: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var asked := str(knobs.get("greybox","")).strip_edges()
	if asked == "": return out
	if asked == "all":
		for s: String in MOTIFS: out.append(s)
		return out
	for s: String in asked.split(",",false):
		var slug := s.strip_edges().trim_prefix("gb_")
		if MOTIFS.has(slug): out.append(slug)
		else: push_warning("greybox: no motif '%s' (%s)" % [slug,", ".join(PackedStringArray(MOTIFS.keys()))])
	return out

## The pool entries ([id, script, weight], LayerPlan POOL's) the knobs add.
static func entries(knobs: Dictionary) -> Array:
	var out: Array = []
	for slug: String in wanted(knobs): out.append(["gb_"+slug,MOTIFS[slug],WEIGHT])
	return out

## Whether every layer must hold one.
static func forced(knobs: Dictionary) -> bool:
	return int(knobs.get("greybox_force",1)) != 0 and not wanted(knobs).is_empty()

## Whether a pool id is a greybox motif's.
static func has(id: String) -> bool:
	return id.begins_with("gb_") and MOTIFS.has(id.trim_prefix("gb_"))

## Whether a forced plan lacks one (its isles' ids).
static func missing(plan: Dictionary) -> bool:
	if not forced(plan.get("knobs",{})): return false
	for isle: Dictionary in plan.isles:
		if has(str(isle.id)): return false
	return true
