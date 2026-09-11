extends SceneTree
## The twin-chunk prototype really builds a second island and a crossing: the
## copy carries the terrain, the skirt and the chunk's plants, the two anchors
## face each other across the chasm a bridge can span, they stand on ground rather
## than in the air, and a sagging plank deck joins them.
##
## Instantiates the study, so it needs a real window and the native kernels.
## Never --headless: the fidelity scene hangs there.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_twin_chunks.gd
const MIN_VISUALS := 10      ## A copied chunk is terrain, skirt and its plants.
const MIN_SPAN := 34.0       ## The chasm is 45 m; anchors sit 0.5 m inside each rim.
const MAX_SPAN := 50.0
const MAX_STEP := 6.0        ## Level islands: only the two rims' own ground.
const GROUND_TOLERANCE := 0.1
var failures := 0
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(55).timeout.connect(func() -> void:
		print("FAIL: the study never finished forming")
		print("Failures: 1")
		quit(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(960, 600)
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	check(scene.second_chunk_ready, "The study instantiates and builds its copy inside _ready")
	# Authored content and landmarks publish asynchronously; let them land, then
	# rebuild so the copy is measured against a settled world.
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)

	# ------------------------------------------------------------- the copy
	var copy: Node3D = scene.second_chunk
	check(copy != null and copy.get_parent() == scene, "SecondChunk hangs off the study root")
	# The seam a generated island will land on: the study asks the node, not the copy.
	check(copy.has_method("ground_height_at"), "The second island answers for its own ground")
	check(scene.ground_y_at(Vector2(scene.second_chunk_centre().x, scene.second_chunk_centre().z), true) != null, "It answers at its own centre")
	check(scene.ground_y_at(Vector2(scene.second_chunk_centre().x, scene.second_chunk_centre().z), false) == null, "Chunk one declines to answer for ground it does not own")
	# A grown island names its parts terrain/skirt; the stand-in copy prefixes Twin_.
	var grown := copy.get_node_or_null("Twin_terrain") == null
	var terrain_copy: MeshInstance3D = copy.get_node_or_null("terrain" if grown else "Twin_terrain")
	check(terrain_copy != null, "The far island carries a terrain mesh (%s)" % ("grown" if grown else "copy"))
	check(copy.get_node_or_null("skirt" if grown else "Twin_skirt") != null, "The far island carries an earth skirt")
	var visuals: int = scene.visual_instance_count()
	check(visuals >= MIN_VISUALS, "The far island carries at least %d visual instances: %d" % [MIN_VISUALS, visuals])
	if grown:
		check(terrain_copy != null and terrain_copy.mesh != editor.terrain.mesh, "A grown island has its own terrain mesh")
	else:
		check(terrain_copy != null and terrain_copy.mesh == editor.terrain.mesh, "The copied terrain shares the original mesh resource")
	check(copy.find_children("*", "CollisionObject3D", true, false).is_empty(), "Nothing in the copy can be hit by a ray")
	check(editor.terrain.get_parent() == scene.get_node("Reference"), "The editor still owns only the first chunk's terrain")

	# ---------------------------------------------------------- the anchors
	var anchors: Array[Transform3D] = scene.bridge_anchors()
	check(anchors.size() == 2, "bridge_anchors returns two poses")
	if anchors.size() == 2:
		var a := anchors[0].origin
		var b := anchors[1].origin
		var span := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		check(span > MIN_SPAN and span < MAX_SPAN, "The anchors stand %.2f m apart horizontally" % span)
		var step := absf(a.y - b.y)
		check(step < MAX_STEP, "The crossing steps %.2f m, under %.1f m" % [step, MAX_STEP])
		var near_ground: Variant = scene.ground_y_at(Vector2(a.x, a.z), false)
		var far_ground: Variant = scene.ground_y_at(Vector2(b.x, b.z), true)
		check(near_ground != null and far_ground != null, "Both anchors sit over their own chunk's ground")
		if near_ground != null and far_ground != null:
			check(a.y >= float(near_ground) - GROUND_TOLERANCE, "The near anchor is on the ground, not under it: %.3f vs %.3f" % [a.y, float(near_ground)])
			check(b.y >= float(far_ground) - GROUND_TOLERANCE, "The far anchor is on the ground, not under it: %.3f vs %.3f" % [b.y, float(far_ground)])
		var across := (b - a).normalized()
		check(anchors[0].basis.z.dot(across) > 0.9, "The near anchor's +Z points across the gap")
		check(anchors[1].basis.z.dot(-across) > 0.9, "The far anchor's +Z points back")

	# ----------------------------------------------------------- the bridge
	check(scene.bridge != null and scene.bridge.get_parent() == scene, "A bridge joins the two islands")
	if scene.bridge.has_method("sag_depth"):
		# The real rope bridge: a physics rope with planks painted along it.
		var planks: int = scene.bridge.plank_count()
		check(planks >= 40, "The rope bridge paints %d planks along the span" % planks)
	else:
		var slats: int = scene.bridge.find_children("Plank*", "MeshInstance3D", true, false).size()
		check(slats >= 40, "The placeholder deck is laid in %d separate planks, not one beam" % slats)
		check(scene.bridge.find_children("Rope*", "MeshInstance3D", true, false).size() == slats * 2, "Every plank has a rope either side")
	# The whole point of a rope bridge: midspan hangs below the straight chord.
	if anchors.size() == 2:
		var chord := anchors[0].origin.lerp(anchors[1].origin, 0.5)
		var middle: Vector3 = scene.deck_point(0.5)
		var sag := chord.y - middle.y
		var span := anchors[0].origin.distance_to(anchors[1].origin)
		check(sag > span * 0.08 and sag < span * 0.16, "The deck sags %.2f m over a %.2f m span" % [sag, span])
		check(scene.deck_point(0.0).is_equal_approx(anchors[0].origin), "The curve starts on the near anchor")
		if scene.bridge.has_method("sag_depth"):
			# And the rope that was actually built hangs where it was asked to.
			var hung: float = scene.bridge.sag_depth()
			check(hung > span * 0.08 and hung < span * 0.18, "The built rope hangs %.2f m below the chord" % hung)

	scene.queue_free()
	await process_frame
	print("PASS: two islands and a crossing" if failures == 0 else "FAIL: twin chunks")
	print("Failures: ", failures)
	quit(1 if failures else 0)
