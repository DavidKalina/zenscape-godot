extends SceneTree
## Native topology and mesh publication equivalence; run graphically.
const Prepare = preload("res://scripts/native_blast_preparation.gd")
const Blast = preload("res://scripts/terrain_blast.gd")
const Collapse = preload("res://scripts/mountain_collapse.gd")
const InternalBlast = preload("res://scripts/internal_blast.gd")
var failures := 0
var frames := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func state(data: NativeTerrainData) -> PackedByteArray:
	return var_to_bytes([data.heights,data.grass,data.meadow,data.blades,data.tint])
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(2))
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	process_frame.connect(func() -> void: frames += 1)
	for mode in ["surface","buried","salvo"]:
		await preload("res://scripts/native_landscape_presets.gd").form(data,"horn")
		var peak := 0
		for i in range(data.heights.size()):
			if data.heights[i] > data.heights[peak]: peak = i
		var id := data.place("explosive",data.points[peak])
		data.update_object(id,{"blast_radius":3.5})
		if mode == "buried": data.update_object(id,{"anchor_y":data.heights[peak]-3.0})
		var salvo: Array[Dictionary] = [data.object_by_id(id)]
		if mode == "salvo":
			id = data.place("explosive",data.points[peak]+Vector2(1,0.5))
			data.update_object(id,{"blast_radius":2.5})
			salvo.append(data.object_by_id(id))
		var colors: PackedColorArray = data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var detached := preload("res://scripts/native_terrain_snapshot.gd").for_queries(data,true)
		var reference: Array[Dictionary] = []
		for charge in salvo:
			var origin := data.object_position(charge)
			var initial := data.heights.duplicate()
			var result := InternalBlast.rupture(data,origin,charge.blast_radius,colors)
			if result.is_empty() and not InternalBlast.confined(data,origin,charge.blast_radius):
				Blast.carve_native(data,origin,charge.blast_radius)
				result = Collapse.collapse(data,initial,origin,charge.blast_radius,colors)
			if not result.is_empty(): reference.append(result)
			data.remove_object(charge.id)
		var before := state(data)
		var prior_frames := frames
		var job = preload("res://scripts/background_work.gd").new()
		var prepared: Dictionary = await job.run(Prepare.build.bind(detached,salvo.duplicate(true),colors.duplicate()),self)
		check(frames > prior_frames,mode+": worker permits main-loop progress")
		check(state(data) == before,mode+": detached worker cannot mutate live terrain")
		check(state(detached) == before,mode+": terrain and cover bytes match the original ordered calculation")
		check(reference.size() == prepared.collapses.size(),mode+": same collapses")
		for i in range(mini(reference.size(),prepared.collapses.size())):
			var actual: Dictionary = prepared.collapses[i]
			check(reference[i].chunks.size() == actual.chunks.size(),mode+": same chunk count")
			for j in range(mini(reference[i].chunks.size(),actual.chunks.size())):
				var chunk: Dictionary = actual.chunks[j]
				check(not chunk.has("mesh"),"Worker result contains arrays, not rendering resources")
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,chunk.arrays,[],{},0)
				check(mesh.create_convex_shape(true,false).points.to_byte_array() == reference[i].chunks[j].mesh.create_convex_shape(true,false).points.to_byte_array(),mode+": cleaned collider points match exactly")
				var cpu_hull := preload("res://scripts/native_chunk_hull.gd").build(chunk.arrays[Mesh.ARRAY_VERTEX])
				check(cpu_hull.points.to_byte_array() == mesh.create_convex_shape(true,false).points.to_byte_array(),mode+": CPU hull adapter preserves the engine's exact cleaned points")
				check(var_to_bytes(mesh.surface_get_arrays(0)) == var_to_bytes(reference[i].chunks[j].mesh.surface_get_arrays(0)),mode+": published chunk mesh bytes match")
				check(chunk.center == reference[i].chunks[j].center and chunk.velocity == reference[i].chunks[j].velocity and chunk.delay == reference[i].chunks[j].delay,mode+": chunk motion matches")
		print("THREADED_BLAST ",mode," failures=",failures)
	print("Threaded destruction: ",failures," failures")
	quit(1 if failures else 0)
