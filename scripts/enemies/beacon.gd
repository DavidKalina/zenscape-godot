class_name Beacon
extends SightLight
## A lit thing every Olmec turns to: the great cresset, a beacon tower's crown,
## Mudge alight on his spire. A SightLight (it lights the ground round it for
## the Olmec's sight) that also draws: lit, every headless body and calm
## whole Olmec within `draw` m (flat) hears it the way a body hears its
## head's call (scripts/enemies/headless_body.gd, `_beacon_pick`), turns to
## it and goes there by its routes, stands looking at it `dwell` s, then
## tires of it (its `beacon_rest` knob, s) unless it is lit again.
##
## Any piece adds one as a child where the flame is:
##   var b := Beacon.new()
##   b.position = Vector3(0, 4, 0)   # the bowl
##   b.stand = Vector3(0, 0, 3)      # optional: where an Olmec comes to, local
##   bowl.add_child(b)
##   b.lit = false ... b.light()     # lit_changed(on) fires
## It joins the group BEACONS (and SightLight.GROUP) while in the tree.

const BEACONS := &"beacons"

## How strongly it draws, against other beacons (a body takes the one with
## the most `pull` / (1 + d / `draw`)).
@export var pull := 1.0
## How far off (m, flat) it draws an Olmec; 0 or less: `radius` x DRAW_K.
@export var draw := 0.0
## Where an Olmec comes to, in its own space (INF: under it, at the flame's
## x and z, on the ground the body finds there).
@export var stand := Vector3.INF
## How near it comes to `stand` (m, past its own half length) before it
## stops and looks, and how long it looks (s).
@export var gather := 3.0
@export var dwell := 6.0

const DRAW_K := 8.0

func _enter_tree() -> void:
	super._enter_tree()
	add_to_group(BEACONS)

## How far off it draws (m, flat).
func draw_range() -> float:
	return draw if draw > 0.0 else radius*DRAW_K

## Where an Olmec comes to (world).
func stand_at() -> Vector3:
	if stand == Vector3.INF: return global_position
	return to_global(stand)

## The lit beacons in `tree`. A flame a LightDrinker (scripts/enemies/
## light_drinker.gd, the Hollow Child) drinks half or more of draws no one.
static func all_lit(tree: SceneTree) -> Array:
	var out := []
	if tree == null: return out
	var drinkers := tree.has_group(LightDrinker.GROUP)
	for b in tree.get_nodes_in_group(BEACONS):
		if b is Beacon and b.lit and b.is_inside_tree():
			if drinkers and LightDrinker.drunk(tree,(b as Beacon).global_position) >= 0.5: continue
			out.append(b)
	return out
