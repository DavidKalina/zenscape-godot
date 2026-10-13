extends RefCounted
## A layer's shape, chosen (docs/design/roguelike/layer-round7-ring.md):
## "" round 3's (scripts/roguelike/layer_plan.gd), "sprawl" (scripts/
## roguelike/layer_sprawl.gd), "ring" (scripts/roguelike/layer_ring.gd).
## A run (studies/run_layer.gd --shape=sprawl or --shape=ring) alternates
## them by depth: its first region the asked shape, each gate's region the
## other (`after`), so a run begun on the sprawl goes sprawl, ring, sprawl,
## ... `--knob=alternate=0` keeps the one shape. The next region drawn far
## off past a gate is laid with the shape it will have (LayerSprawl
## `next_plan` asks `after`), so its silhouette is its own shape.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const LayerRing = preload("res://scripts/roguelike/layer_ring.gd")

## The shapes a run alternates between, in turn.
const RUN := ["sprawl","ring"]

## The plan for `seed_value` in `shape` (its next region too on the main
## thread, as each shape's `make`).
static func make(shape: String, seed_value: int, knobs := {}) -> Dictionary:
	match shape:
		"sprawl": return LayerSprawl.make(seed_value,knobs)
		"ring": return LayerRing.make(seed_value,knobs)
	return LayerPlan.make(seed_value,knobs)

## The same without its next region (each shape's kept plans).
static func core(shape: String, seed_value: int, knobs := {}) -> Dictionary:
	match shape:
		"sprawl": return LayerSprawl.core(seed_value,knobs)
		"ring": return LayerRing.core(seed_value,knobs)
	return LayerPlan.make(seed_value,knobs)

## The shape `plan` was laid in.
static func shape_of(plan: Dictionary) -> String:
	if plan.has("shape"): return str(plan.shape)
	return str((plan.get("knobs",{}) as Dictionary).get("shape",""))

## The shape of the region past `plan`'s gate: the other of RUN, or the
## same with `--knob=alternate=0` (or round 3's, which has no run).
static func after(plan: Dictionary) -> String:
	var shape := shape_of(plan)
	if not RUN.has(shape): return shape
	if int((plan.get("user_knobs",{}) as Dictionary).get("alternate",1)) == 0: return shape
	return RUN[(RUN.find(shape)+1)%RUN.size()]

## What the shape adds to a built layer (its next region's silhouette, the
## sprawl's chain cannons).
static func dress(stage: Node3D, plan: Dictionary) -> void:
	match shape_of(plan):
		"ring": LayerRing.dress(stage,plan)
		"sprawl": LayerSprawl.dress(stage,plan)

## The shape's line for the card ("" for round 3's).
static func card(plan: Dictionary) -> String:
	match shape_of(plan):
		"ring": return LayerRing.card(plan)
		"sprawl": return LayerSprawl.card(plan)
	return ""
