extends Node3D
## Rigid posing of the editable v01 parts. Replace with authored clips later;
## behavior only calls pose(), and never knows mesh names or joint structure.
var visual: Node3D
var parts: Array[Dictionary] = []
var phase := 0.0
var variant := "photographer"
func setup(kind: String) -> void:
	variant = kind
	visual = (preload("res://assets/models/zenscape-camper-backpacker-v01.glb") if kind == "backpacker" else preload("res://assets/models/zenscape-camper-photographer-v01.glb")).instantiate()
	add_child(visual)
	var hip := 0.78 if kind == "backpacker" else 0.91
	var shoulder := 1.18 if kind == "backpacker" else 1.35
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		var key := str(mesh.name)
		var limb := "body"
		if key.begins_with("Trouser") or key.begins_with("Boot") or key.begins_with("Sole"): limb = "leg"
		elif key.begins_with("Upper_sleeve") or key.begins_with("Forearm") or key.begins_with("Mitten_hand"): limb = "arm"
		elif key.begins_with("Camera") or key.begins_with("Lens"): limb = "camera"
		var side := signf(mesh.position.x)
		parts.append({"node":mesh,"rest":mesh.transform,"limb":limb,"side":side,"pivot":Vector3(side*0.12,hip,0) if limb == "leg" else Vector3(side*(0.265 if kind == "backpacker" else 0.21),shoulder,0)})
		# Retain the authored material colors while letting actual world light shade them.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
func pose(dt: float, moving: bool, state: String, carrying: bool, speed := 0.7) -> void:
	if moving: phase += dt*7.0*speed/0.7
	var gather := state == "collect"
	var photo := state == "photo"
	var startled := state == "flee"
	for part in parts:
		var node: Node3D = part.node
		var rest: Transform3D = part.rest
		var angle := 0.0
		if part.limb == "leg": angle = sin(phase)*0.34*part.side if moving else 0.0
		elif part.limb == "arm":
			angle = -sin(phase)*0.23*part.side if moving else 0.0
			if carrying or photo: angle = -1.10 if photo else -0.72
			elif startled: angle = -0.70
		if part.limb in ["leg","arm"]:
			var pivot: Vector3 = part.pivot
			node.transform = Transform3D(Basis.IDENTITY,pivot)*Transform3D(Basis(Vector3.RIGHT,angle),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-pivot)*rest
		else:
			node.transform = rest
			if part.limb == "camera" and photo: node.position += Vector3(0,0.36,0.10)
	visual.rotation.x = lerpf(visual.rotation.x,0.38 if gather else -0.12 if startled else 0.0,1-exp(-8*dt))
	visual.position.y = absf(sin(phase))*0.018 if moving else 0.0
