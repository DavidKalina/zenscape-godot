extends Node3D
## The bag study's dig spots (docs/design/bag-brood/spec-bag-brood.md, task
## 4): its burrows (studies/bag_study.gd) with something the stone brood
## buried in them (scripts/brood/bag_brood.gd `buried`, `bag_in`). Handed to
## the dig (scripts/dig/dig.gd setup's "spots") in place of the wreck
## cluster's DigSpots: a bite within DIG_REACH of a burrow's mouth bites
## soil (the room's floor is stone elsewhere), and on one with a pile the
## dig's second bite digs it out (`dig_out`).
const K = preload("res://scripts/brood/brood_knobs.gd")

## How far up or down (m, times his size) a bite may land from the mouth.
const LEVEL := 1.0

var host: Node3D = null
var fx: Node3D = null
var size := 1.0

func setup(scene: Node3D, dig_fx: Node3D, s: float) -> void:
	host = scene
	fx = dig_fx
	size = s
	name = "BurrowDigs"

func re_deal(_seed: int) -> void:
	pass

## No grass in the room to cut.
func cut_at(_at: Vector3, _r: float, _keep: float, _clear := 0.0) -> int:
	return 0

func _burrow(at: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := K.DIG_REACH*size
	for b: Variant in host.get("burrows"):
		if not is_instance_valid(b): continue
		var p: Vector3 = (b as Node3D).global_position
		var d := Vector2(p.x-at.x,p.z-at.z).length()
		if d <= best_d and absf(p.y-at.y) <= LEVEL*size:
			best = b
			best_d = d
	return best

## The turned earth round any burrow's mouth.
func soil_at(at: Vector3) -> bool:
	return _burrow(at) != null

## The burrow with a pile a bite at `at` digs: {tell_node, burrow}, else {}.
func near(at: Vector3) -> Dictionary:
	var b := _burrow(at)
	var brood: Variant = host.get("brood")
	if b == null or brood == null or not brood.has_pile(str(b.name)): return {}
	return {"tell_node":b,"burrow":str(b.name)}

func reveal(sp: Dictionary, at: Vector3) -> void:
	var brood: Variant = host.get("brood")
	if sp.is_empty() or brood == null: return
	brood.dig_out(str(sp.burrow),at)
	if fx != null and fx.has_method("dust"): fx.dust(at,9,0.4,1.0)
