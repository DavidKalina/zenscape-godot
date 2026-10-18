extends "res://scripts/kit_isle/mechanics/mechanic.gd"
## An air ring on a motif (scripts/interactables/air_ring.gd, laid by
## FootPieces `air_ring`): flown or jumped through, the charge refilled and
## a pop up; its top a trampoline. `lift` m over its spot (its middle),
## `tip` degrees tipped about its own x (0 flat: taken going up through it;
## 90 standing, taken going along the arrow); `radius` its size (m, the
## stones' ring; the hole and the top's disc go with it).

const AirRing = preload("res://scripts/interactables/air_ring.gd")

func _init() -> void:
	super()
	trap_name = "air_ring"
	verbs = PackedStringArray(["jump","sail"])

func defaults() -> Dictionary:
	return {"lift":3.5,"tip":0.0,"radius":AirRing.RADIUS,"seed":0}

func lay(pieces: Node3D, frame: Transform3D) -> void:
	pieces.air_ring(frame*Vector3(0.0,float(knobs.lift),0.0),int(knobs.seed),yaw_of(frame),deg_to_rad(float(knobs.tip)),float(knobs.get("radius",AirRing.RADIUS)))
