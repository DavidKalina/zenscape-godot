extends SceneTree
## Watch the far-island camper second by second: state, route, position, and
## whether the next stride is one the grid will allow. Diagnostic only.
const DT := 1.0 / 60.0
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(300).timeout.connect(func() -> void: quit(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(960, 600)
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)
	scene.set_process(false)
	var island: Node3D = scene.second_chunk
	var data: NativeTerrainData = island.data
	var camps: Node = scene.island_camps
	scene._process(DT)
	var entry: Dictionary = camps.camps[scene.camp_id]
	var nav = camps.world.navigation
	print("PROBE home %s nodes %d" % [entry.home, nav._nodes.size()])
	for record in data.objects:
		if record.asset == "fallen_branch":
			var at := data.object_position(record)
			var foot: Variant = nav.nearest_safe(at)
			print("PROBE branch %d at %s foot %s path %d" % [record.id, at, foot, nav.path(entry.home, foot).size() if foot != null else -1])
	var last_state := ""
	var bails := 0
	var previous_route := 0
	for frame in range(120 * 60):
		var before: int = entry.route.size()
		scene._process(DT)
		if frame % 120 == 0:
			await process_frame
		# A route that vanished mid-walk without arriving is a bail-out.
		if before > 0 and entry.route.is_empty() and entry.waypoint < before and entry.state == "return":
			bails += 1
		if frame % 60 == 0 or entry.state != last_state:
			last_state = entry.state
			var next_ok := "-"
			if not entry.route.is_empty() and entry.waypoint < entry.route.size():
				next_ok = str(nav.segment_safe(entry.actor.position, entry.route[entry.waypoint]))
			var record: Dictionary = data.object_by_id(scene.camp_id)
			print("PROBE %5.1f %-10s route %2d/%2d at (%.2f,%.2f,%.2f) home %.2f m carrying %s wood %d wait %.1f next_safe %s bails %d" % [
				camps.clock, entry.state, entry.waypoint, entry.route.size(), entry.actor.position.x, entry.actor.position.y, entry.actor.position.z,
				entry.actor.position.distance_to(entry.home), record.get("carrying", false), int(record.get("wood", 0)), entry.wait, next_ok, bails])
		if int(data.object_by_id(scene.camp_id).get("wood", 0)) > 0:
			print("PROBE delivered at %.1f" % camps.clock)
			break
	print("PROBE events ", camps.events)
	quit(0)
