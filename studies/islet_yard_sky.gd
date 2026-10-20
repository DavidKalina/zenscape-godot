extends "res://studies/aqueduct_isle_sky.gd"
## The islet yard's sky (studies/islet_yard.gd): the aqueduct isle's clouds
## and motes round the yard, nothing that flies loops (no motif isles,
## airships, CPU planes, serpent or tokens).

func _with_motifs() -> bool:
	return false

func _build_airships() -> void:
	pass

func _build_traffic() -> void:
	pass

func _build_serpent() -> void:
	pass

func _build_tokens() -> void:
	pass

## The motes round the yard only.
func _build_motes() -> void:
	var m: Node3D = SkyMotes.new()
	m.position = Vector3(0.0,24.0,0.0)
	m.scale = Vector3.ONE*2.0
	add_child(m)
	m.set_strength(0.6)
	motes.append(m)
