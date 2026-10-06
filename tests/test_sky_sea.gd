extends SceneTree
## The near cloud sea (scripts/sky_sea.gd, shaders/sky_sea.gdshader): the
## look pass adds it, it stands round the camera wherever the camera goes,
## inside the camera's far plane, takes the sky's sea style, goes with the
## sea when it is off (--no-cloud-sea, F6) and with --dome-sea, and is told
## of the plate and the islands nearest first. Headless: what it draws is not
## checked here, only that its shader compiles and is set as the sky's is.
const LookPass = preload("res://scripts/look_pass.gd")
const SkySea = preload("res://scripts/sky_sea.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var look = scene.look_pass
	var sea: MeshInstance3D = scene.get_node_or_null("SkySea")
	check(sea != null and sea == look.sea, "The look pass adds the near sea")
	if sea == null:
		finish(scene)
		return
	var names: Array = sea.material.shader.get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)
	check(names.has("islands") and names.has("ranges") and names.has("reach") and names.has("cloud_sea_style"), "Its shader compiles and takes the sea's style, reach and islands")
	check(sea.material.render_priority < preload("res://scripts/sky_towers.gd").RENDER_PRIORITY, "It draws before the towers that rise out of it")
	check(names.has("cauliflower") and names.has("has_noise"), "Its heaps take the cumulus' cauliflower")
	look.cloud_sea = 1.0
	look._update_cloud_sea(1.0)
	check(sea.visible, "It shows with the sea")

	# It stands round the camera.
	var camera: Camera3D = scene.camera
	camera.global_position = Vector3(310.0, 40.0, -220.0)
	await process_frame
	await process_frame
	var at: Vector3 = sea.global_position
	check(is_equal_approx(at.x, camera.global_position.x) and is_equal_approx(at.z, camera.global_position.z), "It follows the camera (%s)" % at)
	var box: BoxMesh = sea.mesh
	check(at.y - box.size.y * 0.5 <= SkySea.FLOOR and at.y + box.size.y * 0.5 >= SkySea.FLOOR + (SkySea.TALL + SkySea.SWELL) * SkySea.HEADROOM, "Its box holds the heaps from their feet to the swell")
	var corner := Vector3(box.size.x * 0.5, at.y - box.size.y * 0.5 - camera.global_position.y, box.size.z * 0.5).length()
	check(corner < camera.far, "Its far corners stand inside the camera's far plane (reach %.0f, far %.0f)" % [sea.reach, camera.far])
	camera.far = 1000.0
	sea.follow(camera)
	check(is_equal_approx(sea.reach, 1000.0 * SkySea.FAR_SHARE), "A nearer far plane draws it in")
	camera.far = 9000.0
	sea.follow(camera)
	check(is_equal_approx(sea.reach, SkySea.REACH), "A far plane past it leaves it at its full reach")

	# The towers' own noise, made on a worker and handed over once ready.
	for i in range(600):
		if float(sea.material.get_shader_parameter("has_noise")) > 0.0: break
		sea.follow(camera)
		await process_frame
	check(float(sea.material.get_shader_parameter("has_noise")) == 1.0, "The cumulus' noise reaches the heaps")
	check(sea.material.get_shader_parameter("cauliflower") == preload("res://scripts/cumulus_noise.gd").texture(), "It is the towers' one noise volume, not a second")

	# Each style is the sky's.
	var sky: ShaderMaterial = scene._environment.sky.sky_material
	for index in LookPass.CLOUD_STYLES.size():
		look.set_cloud_style(LookPass.CLOUD_STYLES[index], false)
		check(int(sea.material.get_shader_parameter("cloud_sea_style")) == index and int(sky.get_shader_parameter("cloud_sea_style")) == index, "%s paints the near sea as the sky's" % LookPass.CLOUD_STYLES[index])

	# Off with the sea, with the look pass (F6) and with --dome-sea.
	look.cloud_sea = 0.0
	look._update_cloud_sea(1.0)
	check(not sea.visible and float(sea.material.get_shader_parameter("cloud_sea")) == 0.0, "With the sea off (--no-cloud-sea) it paints none")
	look.cloud_sea = 1.0
	look._update_cloud_sea(0.0)
	check(not sea.visible, "With the look pass off (F6) it goes with the sea")
	look.near_sea = false
	look._update_cloud_sea(1.0)
	check(not sea.visible, "--dome-sea leaves the dome's sea alone")
	look.near_sea = true
	look._update_cloud_sea(1.0)
	check(sea.visible, "And back")

	# The islands: the plate first, the rest nearest first, no more than it holds.
	var plate := Node3D.new()
	scene.add_child(plate)
	plate.global_position = Vector3(5.0, 0.0, 7.0)
	var islands := FakeIslands.new()
	for i in range(12): islands.offsets.append(Vector3(400.0 - 30.0 * i, 0.0, 0.0))
	var spots: Array = SkySea.island_spots(islands, plate, Vector3(400.0, 0.0, 0.0))
	check(spots.size() == SkySea.ISLANDS, "At most %d islands" % SkySea.ISLANDS)
	check(is_equal_approx(spots[0].x, 5.0) and is_equal_approx(spots[0].y, 7.0), "The plate comes first")
	check(is_equal_approx(spots[1].x, 405.0), "Then the island nearest the eye")
	check(spots[0].w < plate.global_position.y and spots[0].z > 0.0, "Each with a reach, its underside below the plate")
	check(SkySea.island_spots(null, null, Vector3.ZERO).size() == 1, "With no islands, the plate alone")
	sea.set_ranges([Vector4(1.0, 2.0, 0.0, 720.0)])
	var ranges: PackedVector4Array = sea.material.get_shader_parameter("ranges")
	check(ranges.size() == SkySea.RANGES and ranges[0] == Vector4(1.0, 2.0, 720.0, 0.0) and ranges[1].z == 0.0, "A range's keep-out is its reach round its foot, the rest of the list empty")
	plate.queue_free()
	islands.free()
	finish(scene)

func finish(scene: Node) -> void:
	scene.queue_free()
	# Long enough for the audio server to let go of the scene's sounds' playbacks.
	for i in range(10): await process_frame
	print("PASS: sky sea" if failures == 0 else "FAIL: sky sea (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

class FakeIslands extends Node:
	var offsets: Array[Vector3] = []
	func sunk(_index: int) -> float: return 0.0
