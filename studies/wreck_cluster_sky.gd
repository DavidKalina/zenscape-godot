extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the wreck cluster (studies/wreck_cluster.gd): the aqueduct
## isle's clouds and light, and nothing else in it: no motif isles, airships,
## biplanes, serpent or plane tokens (they fly the aqueduct region's places),
## so the cluster stands alone in open sky. Its motes round the cluster.

func _build_airships() -> void:
	pass

func _build_traffic() -> void:
	pass

func _build_serpent() -> void:
	pass

func _build_tokens() -> void:
	pass

func _build_motes() -> void:
	var m: Node3D = SkyMotes.new()
	m.position = Vector3(0.0,24.0,0.0)
	m.scale = Vector3.ONE*2.0
	add_child(m)
	m.set_strength(0.75)
	motes.append(m)
