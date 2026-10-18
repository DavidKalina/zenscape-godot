extends "res://scripts/kit_isle/mechanics/mechanic.gd"
## A swing rope on a motif (scripts/interactables/swing_rope.gd): with
## `frame` on, hung from a trilithon's lintel (FootPieces `rope_frame`, the
## aqueduct isle's floating-stone look; its stones `span` m apart across the
## arrow), else from the air; its anchor `height` m over the spot, the rope
## `length` m down to its knot.

func _init() -> void:
	super()
	trap_name = "swing_rope"
	verbs = PackedStringArray(["jump","swing"])

func defaults() -> Dictionary:
	return {"height":7.0,"length":5.6,"frame":true,"span":3.2,"seed":0}

func lay(pieces: Node3D, frame: Transform3D) -> void:
	var height := maxf(float(knobs.height),float(knobs.length)+0.5)
	if bool(knobs.frame):
		var side := frame.basis.x
		pieces.rope_frame(frame.origin,Vector2(side.x,side.z),maxf(float(knobs.span),1.5),height,float(knobs.length),int(knobs.seed))
	else:
		pieces.rope(frame.origin+Vector3.UP*height,float(knobs.length))

func hint_path() -> PackedVector3Array:
	return PackedVector3Array()
