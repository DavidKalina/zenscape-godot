extends RefCounted
## Detached terrain arithmetic. No scene, renderer or physics-server access.
const Blast = preload("res://scripts/terrain_blast.gd")
const Collapse = preload("res://scripts/mountain_collapse.gd")
const InternalBlast = preload("res://scripts/internal_blast.gd")

static func build(data: NativeTerrainData, salvo: Array[Dictionary], colors: PackedColorArray) -> Dictionary:
	assert(not colors.is_empty(), "Workers require sampled colors, never a live mesh")
	var collapses: Array[Dictionary] = []
	# Preserve ordered charges and relaxation passes exactly. Their writes depend
	# on preceding writes; parallelizing those steps changes the world result.
	for charge in salvo:
		var point := data.object_position(charge)
		var initial := data.heights.duplicate()
		var collapse := InternalBlast.rupture(data,point,charge.blast_radius,colors,true)
		if collapse.is_empty() and not InternalBlast.confined(data,point,charge.blast_radius):
			Blast.carve_native(data,point,charge.blast_radius)
			collapse = Collapse.collapse(data,initial,point,charge.blast_radius,colors,true)
		if not collapse.is_empty(): collapses.append(collapse)
		data.remove_object(charge.id)
	return {"heights":data.heights,"grass":data.grass,"meadow":data.meadow,"blades":data.blades,"tint":data.tint,"collapses":collapses}
