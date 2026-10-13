extends SceneTree
## Captures of the wind-horn (scripts/ruin_kit_horn.gd) at rest, mid-tell,
## firing and knocked out, near and from ~30 m, to docs/captures/wind-horn/
## (windowed; pass -- --no-title):
##   godot --path . --windowed --resolution 1280x720 -s tools/capture_wind_horn.gd -- --no-title [--weathered=0.4]
const Horn = preload("res://scripts/ruin_kit_horn.gd")
const OUT := "res://docs/captures/wind-horn/"

var _cam: Camera3D
var _horn: Node3D
var _rig: Node
var _target: Node3D

func _initialize() -> void:
	var weathered := 0.4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weathered="): weathered = a.get_slice("=",1).to_float()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35,0.55,0.85)
	sky_mat.sky_horizon_color = Color(0.75,0.82,0.9)
	sky_mat.ground_horizon_color = Color(0.6,0.65,0.6)
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0,-35.0,0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0,200.0)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32,0.42,0.22)
	ground.material_override = gm
	root.add_child(ground)
	_horn = Horn.wind_horn(1,weathered)
	root.add_child(_horn)
	_rig = Horn.rig(_horn)
	# A stand-in for the pilot: a pillar the head looks at.
	_target = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	(_target as MeshInstance3D).mesh = cap
	_target.position = Vector3(-5.0,0.6,12.0)
	root.add_child(_target)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	root.add_child(_cam)
	await process_frame
	await _run()
	quit()

func _look(from: Vector3, at: Vector3) -> void:
	_cam.position = from
	_cam.look_at(at)

func _settle(frames: int, share := -1.0) -> void:
	for i in range(frames):
		_rig.aim_at(_target.position,0.05)
		if share >= 0.0: _rig.tell(share)
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))

func _run() -> void:
	# The head swings round to the stand-in (slow: many frames).
	for i in range(240):
		_rig.aim_at(_target.position,0.05)
	await _settle(2)
	var views := {"near":[Vector3(5.5,2.3,9.0),Vector3(0.0,2.0,1.0)],"far":[Vector3(-9.0,4.0,30.0),Vector3(0.0,2.0,0.0)]}
	for v: String in views:
		_look(views[v][0],views[v][1])
		await _settle(3)
		await _shot(v+"_rest")
		await _settle(30,0.55)
		await _shot(v+"_tell")
		_rig.fired()
		await _settle(10)
		await _shot(v+"_fired")
		await _settle(40)
		_rig.disabled(4.0)
		await _settle(30)
		await _shot(v+"_disabled")
		await _settle(300)
