extends SceneTree
## A headless run-through of the chunk atlas (docs/chunk-atlas/DESIGN.md):
## raises a ridge against a seam, grows three more chunks round a corner,
## regenerates one, lays it back to a plain, walks the ring, saves and
## relaunches. After each step it checks the atlas invariants: stored
## neighbours untouched, seams shut, frozen chunks sharing no material with the
## live one and drawn fully grown, one sky, and the pad ready.
## Run: godot --headless --path . --script tools/probe_chunk_atlas_tour.gd -- --atlas
const Atlas = preload("res://scripts/chunk_atlas.gd")
var failures := 0
var folder := ""

func check(ok: bool, message: String) -> void:
	print(("ok   " if ok else "FAIL ")+message)
	if not ok: failures += 1

func _initialize() -> void: run.call_deferred()

func open_scene() -> Node:
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	scene.places_path = folder+"/places.json"
	scene.atlas_path = folder+"/atlas.json"
	root.add_child(scene)
	var began := Time.get_ticks_msec()
	while not scene.shell_ready and Time.get_ticks_msec()-began < 90000: await process_frame
	return scene

func settle(scene: Node) -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	for i in range(600):
		await process_frame
		if editor.refresh_pending == 0 and not editor.water_settling and not editor.forming and not scene.atlas.busy and not scene.places.busy and i > 10: break

func drag(scene: Node, from: Vector2, to: Vector2) -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.select_brush("land")
	editor.creation_brush().prepare(editor.data,editor.land_seed)
	editor.creation_brush().begin()
	editor.data.begin_stroke()
	for step in range(40):
		editor.land_dab(from.lerp(to,step/39.0),editor.brush_strength()/10.0)
		await editor.refresh()
	editor.data.end_stroke()
	await editor.refresh(self)

func seam(scene: Node) -> float:
	var atlas = scene.atlas.atlas
	return atlas.seam_delta(atlas.live,scene._chunk_editor.data.heights,scene._chunk_editor.data.points)

func step(scene: Node, direction: Vector2i, label: String) -> void:
	var began := Time.get_ticks_usec()
	check(await scene.atlas.move(direction),label)
	print("  %s: %.1f ms, carried band %.1f m" % [label,(Time.get_ticks_usec()-began)/1000.0,scene.atlas.last_carry])
	await settle(scene)

## Every ShaderMaterial reachable from `node`'s geometry.
func materials_under(node: Node) -> Dictionary:
	var found := {}
	var nodes: Array = node.find_children("*","GeometryInstance3D",true,false)
	if node is GeometryInstance3D: nodes.append(node)
	for geometry: GeometryInstance3D in nodes:
		if geometry.material_override is ShaderMaterial: found[geometry.material_override] = true
		var mesh: Mesh = null
		if geometry is MeshInstance3D:
			# Only what is drawn: an override hides the mesh's own material.
			if geometry.mesh != null:
				for surface in range(geometry.mesh.get_surface_count()):
					var active: Material = geometry.get_active_material(surface)
					if active is ShaderMaterial: found[active] = true
		elif geometry is MultiMeshInstance3D and geometry.multimesh != null and geometry.material_override == null: mesh = geometry.multimesh.mesh
		if mesh != null:
			for surface in range(mesh.get_surface_count()):
				if mesh.surface_get_material(surface) is ShaderMaterial: found[mesh.surface_get_material(surface)] = true
	return found

## Revisions and document hashes of every stored chunk but the live one.
func neighbours_snapshot(scene: Node) -> Dictionary:
	var atlas = scene.atlas.atlas
	var snapshot := {}
	for slot: Vector2i in atlas.slots:
		if slot == atlas.live: continue
		snapshot[slot] = [atlas.slots[slot].revision,hash(atlas.slots[slot].document)]
	return snapshot

func check_isolated(scene: Node, label: String) -> void:
	var live_materials := materials_under(scene._chunk_editor)
	var reference: Node = scene.get_node_or_null("Reference")
	if reference != null: live_materials.merge(materials_under(reference))
	var shared := 0
	var thawed := 0
	var total := 0
	for view in scene.atlas.views.values():
		for material: ShaderMaterial in materials_under(view):
			total += 1
			if live_materials.has(material): shared += 1
			if material.get_shader_parameter("zs_atlas_frozen") != true: thawed += 1
	check(total > 0 and shared == 0 and thawed == 0,"%s: %d frozen-view materials, %d shared with the live chunk, %d not frozen" % [label,total,shared,thawed])

func pad_ready(scene: Node, label: String) -> void:
	await process_frame
	var controller = scene.atlas
	var ready := true
	for button: Button in controller._pad_buttons.values(): ready = ready and not button.disabled
	var coords := "%d, %d" % [controller.atlas.live.x,controller.atlas.live.y]
	check(ready and controller._pad_label.text.begins_with(coords),"%s: pad ready at %s (%s)" % [label,coords,controller._pad_label.text.replace("\n"," · ")])

func look_colors(scene: Node) -> String:
	return JSON.stringify(scene._celestial.look.document().get("colors",{}))

func run() -> void:
	root.size = Vector2i(1280,800)
	create_timer(900).timeout.connect(func() -> void:
		print("probe timed out")
		quit(2))
	folder = "/private/tmp/zs-atlas-tour-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var scene = await open_scene()
	check(scene.atlas != null,"the atlas is up")
	await settle(scene)
	var editor: NativeChunkEditor = scene._chunk_editor

	# A ridge up against the east border of (0, 0).
	for i in range(3): await drag(scene,Vector2(9.0,-8.0),Vector2(13.6,8.0))
	await settle(scene)
	var ridge := 0.0
	var edges := Atlas.edge_ids(editor.data.points)
	for id in edges.e: ridge = maxf(ridge,editor.data.heights[id])
	print("  ridge on the east border of (0, 0): %.2f m" % ridge)

	await step(scene,Vector2i(1,0),"grow (1, 0) east of the ridge")
	check(seam(scene) < 1e-3,"(1, 0) seam %.6f" % seam(scene))
	# The ridge runs on into the new plain well past the 5 m pin band.
	var carried := -INF
	var baseline := INF
	for id in range(editor.data.points.size()):
		var p: Vector2 = editor.data.points[id]
		if absf(p.x-(-14.0+7.0)) < 0.7: carried = maxf(carried,editor.data.heights[id])
		if absf(p.x-8.0) < 0.7: baseline = minf(baseline,editor.data.heights[id])
	print("  7 m into (1, 0): highest %.2f m; far side lowest %.2f m" % [carried,baseline])
	check(scene.atlas.last_carry > Atlas.BAND_FRAC*Atlas.SIZE+0.5 and carried > baseline+0.5,"the ridge carries on inward (band %.1f m)" % scene.atlas.last_carry)
	check_isolated(scene,"after growing (1, 0)")
	await pad_ready(scene,"after growing (1, 0)")

	await step(scene,Vector2i(0,1),"grow (1, 1) north")
	await step(scene,Vector2i(-1,0),"grow (0, 1) west, a corner chunk")
	check(seam(scene) < 1e-3,"(0, 1) corner seam %.6f" % seam(scene))
	check(scene.atlas.atlas.shared_sides(Vector2i(0,1)).size() == 2,"(0, 1) meets two neighbours")
	check(scene.atlas.views.size() == 3,"three frozen chunks drawn round (0, 1), got %d" % scene.atlas.views.size())
	check_isolated(scene,"four chunks")

	# Regenerate the live chunk.
	var before := neighbours_snapshot(scene)
	var view_ids := {}
	for slot in scene.atlas.views: view_ids[slot] = scene.atlas.views[slot].get_instance_id()
	var sky := look_colors(scene)
	var began := Time.get_ticks_usec()
	scene.places.regrow()
	var peak_growth_ok := true
	while scene.places.busy and Time.get_ticks_usec()-began < 240000000:
		await process_frame
		# Mid-regrow: every frozen chunk keeps its own frozen materials.
		for view in scene.atlas.views.values():
			for material: ShaderMaterial in view.frozen_materials:
				peak_growth_ok = peak_growth_ok and material.get_shader_parameter("zs_atlas_frozen") == true
	await settle(scene)
	print("  regenerate: %.0f ms, inherited %s (%s)" % [(Time.get_ticks_usec()-began)/1000.0,scene.places.generated_world.get("atlas_inherited","none"),scene.places.generated_world.terrain.get("composition","plain")])
	check(peak_growth_ok,"frozen chunks stay frozen through the whole regrow")
	check(neighbours_snapshot(scene) == before,"regenerate leaves every stored neighbour's document untouched")
	var same_views := true
	for slot in view_ids: same_views = same_views and scene.atlas.views.has(slot) and scene.atlas.views[slot].get_instance_id() == view_ids[slot]
	check(same_views,"regenerate does not redraw the neighbours")
	check(look_colors(scene) == sky,"the sky and palette do not jump on regenerate")
	check(seam(scene) < 1e-3,"regenerated seam %.6f" % seam(scene))
	check(not editor.data.to_document().get("terrain_recipe",{}).is_empty(),"the live chunk is a generated world now")
	check_isolated(scene,"after regenerate")
	await pad_ready(scene,"after regenerate")

	# Back to a plain.
	before = neighbours_snapshot(scene)
	scene.places.regrow(-1,true)
	while scene.places.busy: await process_frame
	await settle(scene)
	check(neighbours_snapshot(scene) == before,"a new plain leaves the neighbours untouched")
	check(seam(scene) < 1e-3,"new plain seam %.6f" % seam(scene))
	check(look_colors(scene) == sky,"the sky stays through a new plain")

	# Walk the ring: every stored chunk, reloaded live, still meets its
	# neighbours, and the regenerated one comes back as it was left.
	await step(scene,Vector2i(0,-1),"walk south onto (0, 0)")
	check(seam(scene) < 1e-3,"(0, 0) seam %.6f" % seam(scene))
	await step(scene,Vector2i(1,0),"walk east onto (1, 0)")
	check(seam(scene) < 1e-3,"(1, 0) seam %.6f" % seam(scene))
	await step(scene,Vector2i(0,1),"walk north onto (1, 1)")
	check(seam(scene) < 1e-3,"(1, 1) seam %.6f" % seam(scene))
	await step(scene,Vector2i(1,0),"grow (2, 1) east")
	check(scene.atlas.chunk_count() == 5,"five chunks in the atlas, got %d" % scene.atlas.chunk_count())
	check_isolated(scene,"after the walk")
	await pad_ready(scene,"after the walk")

	check(scene.save_current(),"save")
	var live: Vector2i = scene.atlas.atlas.live
	var count: int = scene.atlas.chunk_count()
	scene.queue_free()
	await process_frame
	await process_frame
	var again = await open_scene()
	await settle(again)
	check(again.atlas.atlas.live == live and again.atlas.atlas.slots.size() == count,"relaunch restores %d chunks at %s" % [count,live])
	check(seam(again) < 1e-3,"relaunched seam %.6f" % seam(again))
	check_isolated(again,"after relaunch")
	again.queue_free()
	await process_frame
	print("probe_chunk_atlas_tour: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
