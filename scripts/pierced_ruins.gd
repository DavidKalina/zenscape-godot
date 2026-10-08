extends RefCounted
## The pierced isle's ruins (scripts/pierced_isle.gd `ruins`): laid by the
## plan, built here from the ruin kit (scripts/ruin_kit.gd and its
## families) on a worker, off the tree.

const RuinKit = preload("res://scripts/ruin_kit.gd")

## The shared pieces the build needs, made on the main thread.
static func prepare() -> void:
	RuinKit.materials()

## The ruins of `plan` on its lid (`lid`, its SkyIslet shape), as one node
## in the lid's frame, or null if it has none.
static func build(plan: RefCounted, lid: RefCounted) -> Node3D:
	return null
