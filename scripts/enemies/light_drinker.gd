class_name LightDrinker
extends Node3D
## A thing that drinks light, for the Olmec's sight (the Hollow Child,
## scripts/city_hollow_child.gd; card x5-hollow): the negative of a
## SightLight. Within its reach every flame is drunk: the wanderer's torch
## when he stands there, and any SightLight (a cresset, a lamp, a lit
## beacon) whose flame stands there or whose light falls there. So by
## LightLevel (scripts/enemies/light_level.gd) a point inside it reads as
## the ambient only, torch lit or not. Not a renderer effect: a point, a
## reach and a share, joined to the group GROUP while in the tree.
##
## `drink_at(p)`: `share` (0..1) within `radius` x FULL, falling straight to
## 0 at `radius`; 0 while not `drinking`.

const GROUP := &"light_drinkers"
## Drinks all of `share` within this share of `radius`.
const FULL := 0.75

## How far it drinks (m).
@export var radius := 6.0
## How much of the light it drinks at full (1 all).
@export var share := 1.0
## Drinking now (the Hollow Child stops while it cries and while spent).
@export var drinking := true

func _enter_tree() -> void:
	add_to_group(GROUP)

## The share of the light at `p` drunk (0 none .. 1 all).
func drink_at(p: Vector3) -> float:
	if not drinking or radius <= 0.0: return 0.0
	var d := global_position.distance_to(p)
	if d >= radius: return 0.0
	return share*clampf((radius-d)/(radius*(1.0-FULL)),0.0,1.0)

## The most any drinker in `tree` drinks at `p` (0 with none).
static func drunk(tree: SceneTree, p: Vector3) -> float:
	if tree == null: return 0.0
	var m := 0.0
	for n in tree.get_nodes_in_group(GROUP):
		if n is LightDrinker and n.is_inside_tree():
			m = maxf(m,(n as LightDrinker).drink_at(p))
	return m
