extends Node3D
## Plane parts gallery: the six pieces the pilot finds on foot to mend the
## plane (scripts/plane_parts.gd), in the two treatments side by side for
## judging: the top row as coins (the piece drawn flat on a thick faceted
## coin), the bottom row as the pieces themselves hovering, both turning
## and glowing, and the plane they came off parked at the left
## (scripts/plane_figure.gd), in the game's daylight, or at night.
##   Drag     orbit          Wheel   zoom
##   F        freeze the turning     N   day / night
##   ./run-plane-parts.command [--night] [--yaw=0.4] [--distance=6] [--focus=2,0.5]
##   godot --path . res://studies/plane_parts_gallery.tscn -- --capture=out.png
## --capture=<png> waits a moment, saves the view and quits.
const PlaneParts = preload("res://scripts/plane_parts.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")

## The rows: how far apart the columns are (m), each row's height and the
## parts' size (m across).
const STEP := 1.55
const COIN_Y := 1.3
const PIECE_Y := -0.25
const SIZE := 1.0
## The plane: where it stands, how big, and its turn.
const PLANE_AT := Vector3(-6.0,-0.55,0.3)
const PLANE_SCALE := 1.7
const PLANE_YAW := 2.3
## The daylight, and the night's (the hemisphere the folk paint is lit by,
## shaders/folk_surface.gdshaderinc).
const DAY_HEMI := [Vector3(0.28269485,0.4541367,0.6909623),Vector3(0.06847817,0.08437621,0.05126946),0.55825]
const NIGHT_HEMI := [Vector3(0.12,0.17,0.3),Vector3(0.03,0.035,0.05),0.3]

var _holders: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _yaw := 0.0
var _pitch := 0.1
var _distance := 10.6
var _focus := Vector3(-1.5,0.45,0.0)
var _frozen := false
var _night := false
var _camera: Camera3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _capture := ""

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--night": _night = true
		elif arg.begins_with("--yaw="): _yaw = float(arg.get_slice("=",1))
		elif arg.begins_with("--distance="): _distance = float(arg.get_slice("=",1))
		elif arg.begins_with("--focus="):
			var at := arg.get_slice("=",1).split(",")
			_focus = Vector3(float(at[0]),float(at[1]) if at.size() > 1 else _focus.y,0.0)
		elif arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
	_build_world()
	for i in range(PlaneParts.IDS.size()):
		var id: String = PlaneParts.IDS[i]
		var x := (i-2.5)*STEP
		for row in [["coin",COIN_Y],["piece",PIECE_Y]]:
			var holder := PlaneParts.part(id,SIZE,row[0],i*0.9+(0.0 if row[0] == "coin" else 0.45))
			holder.position = Vector3(x,row[1],0.0)
			add_child(holder)
			_holders.append(holder)
		var label := _label(PlaneParts.PARTS[id].name,0.24)
		label.position = Vector3(x,PIECE_Y-0.95,0.0)
	var plane := PlaneFigure.new()
	add_child(plane)
	plane.park(Transform3D(Basis(Vector3.UP,PLANE_YAW).scaled(Vector3.ONE*PLANE_SCALE),PLANE_AT))
	_light(_night)
	if not _capture.is_empty():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture)
		get_tree().quit()

func _label(text: String, height: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = height/64.0
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 0
	add_child(label)
	_labels.append(label)
	return label

func _build_world() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = Color("e6d9c4")
	_env.ambient_light_sky_contribution = 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	_env.tonemap_exposure = 0.9
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.03
	_env.glow_hdr_threshold = 1.1
	_env.fog_enabled = true
	_env.fog_density = 0.0015
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-38.0,-35.0,0.0)
	_sun.shadow_enabled = true
	add_child(_sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	var help := Label.new()
	help.text = "Plane parts · coins above, pieces below · Drag orbit · Wheel zoom · F freeze · N night"
	help.add_theme_color_override("font_color",Color("5a4c3c"))
	help.position = Vector2(24.0,20.0)
	help.name = "Help"
	layer.add_child(help)
	add_child(layer)

## The gallery's light, by day or at night: the sky, the sun (or the
## moon), the folk paint's hemisphere and every part's glow.
func _light(night: bool) -> void:
	_night = night
	_sky.sky_top_color = Color("0d1830") if night else Color("2c5a8e")
	_sky.sky_horizon_color = Color("27365a") if night else Color("7d9cba")
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color("10182a") if night else Color("5f7d9c")
	_env.fog_light_color = _sky.sky_horizon_color
	_env.ambient_light_energy = 0.15 if night else 0.45
	_sun.light_color = Color("aabbe0") if night else Color("fff1dc")
	_sun.light_energy = 0.3 if night else 1.15
	var hemi: Array = NIGHT_HEMI if night else DAY_HEMI
	RenderingServer.global_shader_parameter_set("zs_hemi_sky",hemi[0])
	RenderingServer.global_shader_parameter_set("zs_hemi_ground",hemi[1])
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",hemi[2])
	for holder in _holders: holder.glow_for(1.0 if night else 0.0)
	for label in _labels: label.modulate = Color("e8e0d0") if night else Color("3a2f24")
	var help := get_node_or_null("CanvasLayer/Help") as Label
	if help != null: help.add_theme_color_override("font_color",Color("c8c0b0") if night else Color("5a4c3c"))

func _process(delta: float) -> void:
	for holder in _holders: holder.turning = not _frozen
	var d := lerpf(_camera.position.distance_to(_focus),_distance,minf(1.0,delta*4.0)) if _camera.position != Vector3.ZERO else _distance
	_camera.position = _focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*d
	_camera.look_at(_focus)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x*0.008
		_pitch = clampf(_pitch+event.relative.y*0.006,-1.2,1.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = maxf(2.0,_distance*0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = minf(24.0,_distance*1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: _frozen = not _frozen
			KEY_N: _light(not _night)
