extends Node3D
## A hook line: what the wanderer's rope (scripts/rope/climb_rope.gd) can be
## thrown over, wrap round and swing from. Whatever carries one is
## swingable, with no change to the hook or swing code: a beam (the swing
## study's), later a branch, a rock spur, an arch.
##
## The contract: a node of this script, a child of the piece that carries
## it, in the group GROUP; a segment `a`..`b` along the piece's top (where
## the rope rests, in this node's frame, so a world-view move or turn of the
## piece carries it), and its swing `clearance`: the radius round the
## line's axis that the hook wraps at and the rope runs over (the axis is
## `clearance` under the segment). `piece` is the carrier's name (the
## study's piece id). The rope asks `line()` for it in world space.
##
## The rope's reticle snaps to a hook line within its reach overhead, the
## hook wraps over it (hold "beam"), a tug seats it, and the swing hangs
## from its top.

const GROUP := &"hook_line"

@export var a := Vector3.ZERO
@export var b := Vector3.ZERO
@export var clearance := 0.15
## A ring: the hook snaps to the line anywhere along it as usual, but always
## hooks its middle (so the swing from it runs the same whatever the aim).
@export var ring := false
var piece := ""

func _enter_tree() -> void:
	add_to_group(GROUP)

## The line in world space: {a, b, half (the clearance, scaled), piece}.
func line() -> Dictionary:
	var t := global_transform
	return {"a":t*a,"b":t*b,"half":clearance*t.basis.get_scale().y,"piece":piece,"ring":ring}

## Every hook line in `tree` that's showing, in world space.
static func all_in(tree: SceneTree) -> Array:
	var out := []
	for n: Node in tree.get_nodes_in_group(GROUP):
		if n.is_inside_tree() and (n as Node3D).is_visible_in_tree(): out.append(n.call("line"))
	return out

## A box piece's hook line (a beam): along the top of its box collider's long
## side, the clearance half its thickness; added to it, named `piece`. Null
## if it has no box.
static func on_box(body: Node3D, piece_id: String) -> Node3D:
	for c in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
			var long := Vector3(size.x*0.5,0.0,0.0) if size.x >= size.z else Vector3(0.0,0.0,size.z*0.5)
			var top := Vector3(0.0,size.y*0.5,0.0)
			var line: Node3D = load("res://scripts/rope/hook_line.gd").new()
			line.name = "HookLine"
			line.transform = (c as CollisionShape3D).transform
			line.a = top-long
			line.b = top+long
			line.clearance = maxf(minf(size.x,size.z),size.y)*0.5
			line.piece = piece_id
			body.add_child(line)
			return line
	return null
