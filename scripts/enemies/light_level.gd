class_name LightLevel
extends RefCounted
## How lit the wanderer stands, for the Olmec's sight. Cheap, no GPU readback: the ambient level,
## the wanderer's torch, and every lit SightLight (scripts/enemies/
## sight_light.gd; a lit Beacon is one) reaching him, summed.
##
## Where the ambient and the torch come from, `refresh` each frame:
##   1. the flags `--ambient=0.1 [--torch=1]`, if given (a test's dark, on any
##      scene), read by `from_args` when an enemy field is made
##      (scripts/enemies/enemy_field.gd);
##   2. else the underground look (scripts/underground/underground.gd, the
##      study's "Underground" child, `--underground=torch|haze`): its preset's
##      ambient (LOOK_AMBIENT), its torch lit while the torch is shown, as
##      bright as its `torch` knob against the torch preset's;
##   3. else daylight.
## Daylight (`ambient` 1) is no change at all: `exposure` is 1 whatever lights
## stand about, and the sky game is untouched. A LightDrinker (scripts/enemies/
## light_drinker.gd, the Hollow Child) drinks the torch and the sight lights
## where it reaches (at him, or at the light's own flame): none, no change. To put his torch out (to
## hide), hide the look's `torch` node; the sight reads him dark.

const Underground = preload("res://scripts/underground/underground.gd")

## What the sight takes each look preset's ambient for (0 black .. 1 day).
const LOOK_AMBIENT := {"torch":0.1,"haze":0.45}
## The torch's light on him at the torch preset's brightness.
const TORCH := 0.85

static var ambient := 1.0
static var torch := false
## His torch's light on him (he holds it: always full).
static var torch_strength := TORCH
## True while the flags set the light (the look is not read).
static var flagged := false

## Back to daylight, then the flags `args` set (`--ambient=`, `--torch=`).
static func from_args(args: PackedStringArray) -> void:
	ambient = 1.0
	torch = false
	torch_strength = TORCH
	flagged = false
	for a: String in args:
		if a.begins_with("--ambient="):
			ambient = clampf(float(a.get_slice("=",1)),0.0,1.0)
			flagged = true
		elif a.begins_with("--torch="):
			torch = a.get_slice("=",1) in ["1","on","true","lit"]
			flagged = true

## The underground look on the scene, or null.
static func look(tree: SceneTree) -> Node:
	if tree == null or tree.current_scene == null: return null
	return tree.current_scene.get_node_or_null("Underground")

## The ambient and torch now: the flags', else the look's, else day.
static func refresh(tree: SceneTree) -> void:
	if flagged: return
	var u := look(tree)
	if u == null or not (u is Underground):
		ambient = 1.0
		torch = false
		return
	var ug := u as Underground
	ambient = float(LOOK_AMBIENT.get(ug.preset,0.1))
	torch = ug.torch != null and ug.torch.is_visible_in_tree()
	torch_strength = TORCH*clampf(float(ug.knobs.get("torch",Underground.KNOBS.torch))/float(Underground.KNOBS.torch),0.0,1.0)

## Day: nothing about light changes what is seen.
static func daylight() -> bool:
	return ambient >= 0.999

## How lit `p` is (0 black .. 1 as day): the ambient, his torch (`carried`:
## `p` is him), the lit sight lights reaching it; 1 by day.
static func exposure(tree: SceneTree, p: Vector3, carried := true) -> float:
	if daylight(): return 1.0
	var e := ambient
	var dk := _drunk(tree,p)
	if carried and torch: e += torch_strength*(1.0-dk)
	if e >= 1.0: return 1.0
	if tree != null:
		for l in tree.get_nodes_in_group(SightLight.GROUP):
			if l is SightLight and l.is_inside_tree():
				e += _light_at(tree,l as SightLight,p,dk)
				if e >= 1.0: return 1.0
	return clampf(e,0.0,1.0)

## The light the lights alone (his torch and the sight lights, not the
## ambient) put on `p` (0..1): how far past the dark he glows.
static func glow(tree: SceneTree, p: Vector3, carried := true) -> float:
	if daylight(): return 0.0
	var dk := _drunk(tree,p)
	var g := torch_strength*(1.0-dk) if carried and torch else 0.0
	if tree != null:
		for l in tree.get_nodes_in_group(SightLight.GROUP):
			if l is SightLight and l.is_inside_tree(): g += _light_at(tree,l as SightLight,p,dk)
	return clampf(g,0.0,1.0)

## The share of the light at `p` the light drinkers drink (0 with none).
static func _drunk(tree: SceneTree, p: Vector3) -> float:
	if tree == null or not tree.has_group(LightDrinker.GROUP): return 0.0
	return LightDrinker.drunk(tree,p)

## `l`'s light at `p`, less what a drinker drinks of it there (`dk`) or at
## its own flame.
static func _light_at(tree: SceneTree, l: SightLight, p: Vector3, dk: float) -> float:
	var v := l.light_at(p)
	if v <= 0.0 or not tree.has_group(LightDrinker.GROUP): return v
	return v*(1.0-maxf(dk,LightDrinker.drunk(tree,l.global_position)))
