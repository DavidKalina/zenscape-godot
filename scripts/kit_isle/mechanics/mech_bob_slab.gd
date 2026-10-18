extends "res://scripts/kit_isle/mechanics/mechanic.gd"
## A bobbing slab on a motif (scripts/interactables/bob_slab.gd, laid by
## FootPieces `bob_slab`): its top's middle `lift` m over its spot, `width`
## x `thick` x `depth` m. Slammed onto (`spring` on), it coils and throws
## him `spring_pumps` of his pump high (BobSlab SPRING_PUMPS). Its coil
## sinks it FootSlab SPRING_SINK (1.5 m), so `lift` starts that and its
## thickness clear of the ground (a lower spring slab bottoms out on the
## land and he is left standing on the ground); he reaches its top from
## the ground by its lip.

func _init() -> void:
	super()
	trap_name = "bob_slab"
	verbs = PackedStringArray(["jump","slam"])

func defaults() -> Dictionary:
	return {"lift":2.4,"width":2.3,"thick":0.7,"depth":2.2,"spring":true,"spring_pumps":6.0,"seed":0}

func lay(pieces: Node3D, frame: Transform3D) -> void:
	var s: Node3D = pieces.bob_slab(frame*Vector3(0.0,float(knobs.lift),0.0),Vector3(float(knobs.width),float(knobs.thick),float(knobs.depth)),yaw_of(frame),int(knobs.seed))
	s.spring_on = bool(knobs.spring)
	s.spring_pumps = float(knobs.spring_pumps)

func footprint() -> Rect2:
	var w := float(knobs.width)
	var d := float(knobs.depth)
	return Rect2(-w*0.5,-d*0.5,w,d)
