@tool
extends EditorScenePostImport
## The steam train's glbs on import (art/blender/train/train_build.py writes each
## .import naming this script): the far look. Each car's Far mesh (the whole car
## at rest, simpler, one mesh) shows from FAR_FROM m out, and every other node
## that draws (Body, the trucks and wheels, the doors, the rods, the plugs) only
## nearer: their visibility_parent is Far (Godot's HLOD), so the whole car
## switches at once, on the distance to Far's middle. The smash car's FarPlugs
## (its plugs in the far look) take Far's range. Empties with nothing to draw
## (StackMouth, Steam_R/_L) are left alone, so what code hangs on them shows at
## any range. Hide Far (visible = false) and the parts show at every range.

## Where the far look starts (m from the car's middle): the engine's rods and
## drivers read farther than a car's trucks.
const FAR_FROM := {"engine":250.0,"tender":200.0}
const FAR_DEFAULT := 150.0
## Hysteresis either side of the switch (m), so a car hovering at the range
## doesn't flicker.
const MARGIN := 8.0

func _post_import(scene: Node) -> Object:
	var far := scene.find_child("Far",true,false) as GeometryInstance3D
	if far == null: return scene
	var kind := get_source_file().get_file().get_basename()
	var from: float = FAR_FROM.get(kind,FAR_DEFAULT)
	var plugs := far.get_parent().get_node_or_null("FarPlugs") as GeometryInstance3D
	for node: GeometryInstance3D in [far,plugs]:
		if node == null: continue
		node.visibility_range_begin = from
		node.visibility_range_begin_margin = MARGIN
	for child in far.get_parent().get_children():
		if child == far or child == plugs or not child is Node3D: continue
		if _draws(child): (child as Node3D).visibility_parent = child.get_path_to(far)
	return scene

## Whether anything under node (or node itself) draws.
func _draws(node: Node) -> bool:
	if node is VisualInstance3D: return true
	for child in node.get_children():
		if _draws(child): return true
	return false
