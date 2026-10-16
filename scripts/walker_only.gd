class_name WalkerOnly
extends RefCounted
## Walker-only geometry:
## colliders on physics layer 15, "walker_only" (project.godot), which the
## wanderer stands on, walks into, grabs and kicks off, and which the
## headless body (the Olmec) and the other enemies don't read at all: not
## as ground, wall, cover or a route. A place he can't follow.
##
## Opt in per collider, for new kit pieces only:
##   WalkerOnly.mark(body)                 # a StaticBody3D you built
##   var floor := WalkerOnly.box(parent, size, xform)   # a block-out box
## The walker's ground (studies/character_study.gd, studies/kit_isle.gd)
## sees LAYER; an enemy's queries take `strip(study.ground.mask)`.
##
## Only the walker's own queries see it. The plane, rubble and other rigid
## bodies, the dragon, the ground surveys (growth, start spots, way lights)
## and the turf rays don't: a walker-only piece is a ghost to all of them.
## Keep such pieces where that doesn't show: inside a tunnel too low for the
## body, in a niche, high on a wall.

## Layer 15 (bit 14). Free before this round; 14 (bit 13) is the parked
## plane's column, which the body does see.
const LAYER := 1 << 14

## `body` made walker-only: on LAYER alone, looking for nothing (a static
## piece). Returns it, so a build can mark it as it adds it.
static func mark(body: CollisionObject3D) -> CollisionObject3D:
	body.collision_layer = LAYER
	body.collision_mask = 0
	return body

## Whether `body` is on the walker-only layer.
static func marked(body: Object) -> bool:
	return body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & LAYER) != 0

## `mask` with the walker-only layer taken out: what an enemy reads.
static func strip(mask: int) -> int:
	return mask & ~LAYER

## A walker-only box (a StaticBody3D with one BoxShape3D, `size` m, at
## `xform` in `parent`), for block-outs; no mesh.
static func box(parent: Node, size: Vector3, xform: Transform3D, node_name := "WalkerOnly") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	mark(body)
	parent.add_child(body)
	body.transform = xform
	return body
