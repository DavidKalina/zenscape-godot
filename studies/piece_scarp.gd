extends Node3D
## A level piece flown on its own: the gullied scarp with flatirons
## (scripts/pieces/scarp.gd holds the land and every size). Greybox: the land
## is one vertex-coloured mesh of Scarp.height on a STEP m grid, grass or
## rock by Scarp.rock; the plane rides that same grid (`ground`). The plane,
## its figure and the chase camera are set up as studies/burrower_study.gd's.
##
## Keys: as endless flight (A D bank, W S pitch, mouse steers, Shift brake,
## Q E knife edge, Space roll, F boost); R back to the start.
## Flags: --at=x,z --alt=m (above the ground) --heading=deg (the launch;
## heading 0 flies toward -z, up the approach at the scarp).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const FlightWeight = preload("res://scripts/flight_weight.gd")
const FlightPace = preload("res://scripts/flight_pace.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Pad = preload("res://scripts/pad.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Scarp = preload("res://scripts/pieces/scarp.gd")

## The land mesh's grid step (m).
const STEP := 3.0
## How far (m) a cell's two diagonal middles must differ before the land at
## its middle picks the split.
const SPLIT_GAP := 0.5
const GRASS_LOW := Color("4f7535")
const GRASS_HIGH := Color("6f8048")
const ROCK := Color("8a7a66")
const ROCK_DARK := Color("6e6458")
const SLAB := Color("b09a80")
const BARK := Color("4a3a2a")
const LEAF := Color("3f6b2c")

const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
const LOOK_LINGER := 2.5
const RUSH_FOV := 1.8
const CLOSE_IN := 0.12
const CLOSE_DOWN := 0.18

var plane: SkyPlane
var figure: PlaneFigure
var chase: GlideCamera
var camera: Camera3D
var ground_scale := PlaneGroundScale.new()
var weight := FlightWeight.flag(FlightWeight.DEFAULT)
var pace := FlightPace.flag(FlightPace.DEFAULT)
## Set by a driver (tools/harness): its ticks fly the plane, not _physics_process.
var scripted := false
var flight_ready := false
var trees: Array = []
var _space: PhysicsDirectSpaceState3D
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := 0
var _start := Vector3(0.0,30.0,Scarp.APPROACH_LEN-40.0)
var _heading := 0.0
## The grid the mesh is drawn from (and the plane rides).
var _hs := PackedFloat32Array()
var _n := 0
var _m := 0
var _x0 := 0.0
var _z0 := 0.0
## Per grid cell: 1 split along its (0,0)-(1,1) diagonal, else (1,0)-(0,1).
var _split := PackedByteArray()

func _ready() -> void:
	Pad.ensure()
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--at="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 2: _start = Vector3(float(p[0]),_start.y,float(p[1]))
		elif a.begins_with("--alt="): _start.y = a.get_slice("=",1).to_float()
		elif a.begins_with("--heading="): _heading = deg_to_rad(a.get_slice("=",1).to_float())
	_build_light()
	var t0 := Time.get_ticks_msec()
	_build_ground()
	_build_trees()
	print("piece scarp: land built in %d ms, %d trees" % [Time.get_ticks_msec()-t0,trees.size()])
	_build_ui()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = get_world_3d().direct_space_state
	respawn()
	flight_ready = true
	if not scripted and get_tree().current_scene == self and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("4f86c6")
	sky.sky_horizon_color = Color("dfe6e4")
	sky.ground_bottom_color = Color("6b7458")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("d8e0e0")
	environment.fog_density = 0.00012
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	# Low from the side, so the faces and the gully walls shade apart.
	sun.rotation_degrees = Vector3(-38.0,-60.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.far = 5000.0
	add_child(camera)
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "A D bank  ·  W S pitch  ·  mouse steers  ·  Space roll  ·  F boost  ·  Shift brake  ·  Q E knife edge  ·  R back to the start"
	hint.position = Vector2(16.0,12.0)
	hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	hint.add_theme_constant_override("outline_size",4)
	layer.add_child(hint)

func _build_ground() -> void:
	var r: Rect2 = Scarp.EXTENT
	_x0 = r.position.x
	_z0 = r.position.y
	_n = int(ceil(r.size.x/STEP))+1
	_m = int(ceil(r.size.y/STEP))+1
	_hs.resize(_n*_m)
	var faces := PackedFloat32Array()
	faces.resize(_n*_m)
	for j in _m:
		for i in _n:
			var hf: Vector2 = Scarp.sample(_x0+i*STEP,_z0+j*STEP)
			_hs[j*_n+i] = hf.x
			faces[j*_n+i] = hf.y
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	verts.resize(_n*_m)
	normals.resize(_n*_m)
	colours.resize(_n*_m)
	var top := Scarp.SCARP_H+60.0
	for j in _m:
		for i in _n:
			var k := j*_n+i
			var y := _hs[k]
			var hl := _hs[k-1] if i > 0 else y
			var hr := _hs[k+1] if i < _n-1 else y
			var hd := _hs[k-_n] if j > 0 else y
			var hu := _hs[k+_n] if j < _m-1 else y
			var nm := Vector3(hl-hr,2.0*STEP,hd-hu).normalized()
			var x := _x0+i*STEP
			var z := _z0+j*STEP
			verts[k] = Vector3(x,y,z)
			normals[k] = nm
			var grass := GRASS_LOW.lerp(GRASS_HIGH,clampf((y+70.0)/top,0.0,1.0))
			var stone := ROCK_DARK.lerp(ROCK,0.5+0.5*sin(y*0.35))
			# A flatiron's face (one bedding plane, tilted toward the
			# approach) reads paler and unbanded.
			stone = stone.lerp(SLAB,faces[k])
			var c := grass.lerp(stone,Scarp.rock_of(nm))
			# A faint grid of 100 m lines, to judge sizes by.
			if fmod(absf(x)+1.0,100.0) < 2.0 or fmod(absf(z)+1.0,100.0) < 2.0: c = c.darkened(0.08)
			colours[k] = c
	var index := PackedInt32Array()
	index.resize((_n-1)*(_m-1)*6)
	var o := 0
	# Where a cell's two diagonals disagree, split it along the one whose
	# middle matches the land at the cell's middle, so a slanting crease (a
	# slab's edge) follows the cut instead of zig-zagging.
	_split.resize(_n*_m)
	for j in _m-1:
		for i in _n-1:
			var a := j*_n+i
			var m1 := (_hs[a]+_hs[a+_n+1])*0.5
			var m2 := (_hs[a+1]+_hs[a+_n])*0.5
			if absf(m1-m2) > SPLIT_GAP:
				var c := Scarp.height(_x0+(i+0.5)*STEP,_z0+(j+0.5)*STEP)
				_split[a] = 1 if absf(m1-c) < absf(m2-c) else 0
	for j in _m-1:
		for i in _n-1:
			var a := j*_n+i
			if _split[a] == 1:
				index[o] = a; index[o+1] = a+1; index[o+2] = a+_n+1
				index[o+3] = a; index[o+4] = a+_n+1; index[o+5] = a+_n
			else:
				index[o] = a; index[o+1] = a+1; index[o+2] = a+_n
				index[o+3] = a+1; index[o+4] = a+_n+1; index[o+5] = a+_n
			o += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = mesh
	node.material_override = mat
	add_child(node)

## The grid's height at (x, z): its triangles as drawn.
func height(x: float, z: float) -> float:
	var u := clampf((x-_x0)/STEP,0.0,_n-1.001)
	var v := clampf((z-_z0)/STEP,0.0,_m-1.001)
	var i := int(u)
	var j := int(v)
	var fu := u-i
	var fv := v-j
	var k := j*_n+i
	var h00 := _hs[k]
	var h10 := _hs[k+1]
	var h01 := _hs[k+_n]
	var h11 := _hs[k+_n+1]
	if _split[k] == 1:
		if fu >= fv: return h00+fu*(h10-h00)+fv*(h11-h10)
		return h00+fv*(h01-h00)+fu*(h11-h01)
	if fu+fv <= 1.0: return h00+fu*(h10-h00)+fv*(h01-h00)
	return h11+(1.0-fu)*(h01-h11)+(1.0-fv)*(h10-h11)

## The plane's ground (SkyGlide `step`).
func ground(p: Vector3) -> Variant:
	return height(p.x,p.z)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _solid(holder: Node3D, shape: Shape3D, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = RuinBump.LAYER
	body.collision_mask = 0
	var s := CollisionShape3D.new()
	s.shape = shape
	s.transform = xf
	body.add_child(s)
	holder.add_child(body)

## Greybox trees (a trunk and crown lumps, as the burrower study's), solid.
func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Scarp.TREE_SEED
	var bark := _mat(BARK)
	for p: Vector2 in Scarp.tree_spots():
		var tall := rng.randf_range(10.0,16.0)
		var tree := Node3D.new()
		tree.name = "Tree_%d" % trees.size()
		tree.position = Vector3(p.x,height(p.x,p.y)-0.3,p.y)
		add_child(tree)
		var trunk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.55
		cyl.height = tall*0.7
		trunk.mesh = cyl
		trunk.material_override = bark
		trunk.position.y = tall*0.35
		tree.add_child(trunk)
		var leaf := _mat(LEAF.lerp(Color("587a32"),rng.randf()))
		for k in 3:
			var lump := MeshInstance3D.new()
			var s := SphereMesh.new()
			var r := tall*rng.randf_range(0.2,0.28)
			s.radius = r
			s.height = r*1.8
			s.radial_segments = 12
			s.rings = 6
			lump.mesh = s
			lump.material_override = leaf
			lump.position = Vector3(rng.randf_range(-1.5,1.5),tall*0.75+k*tall*0.12,rng.randf_range(-1.5,1.5))
			tree.add_child(lump)
		var shape := CylinderShape3D.new()
		shape.radius = 0.6
		shape.height = tall*0.7
		_solid(tree,shape,Transform3D(Basis.IDENTITY,Vector3.UP*tall*0.35))
		var bush := SphereShape3D.new()
		bush.radius = tall*0.24
		_solid(tree,bush,Transform3D(Basis.IDENTITY,Vector3.UP*tall*0.8))
		trees.append(tree)

## Flying from `at` on `heading`, at cruise, the chase camera behind it.
func launch(at: Vector3, heading: float) -> void:
	plane = SkyPlane.new()
	plane.use_flight_speed()
	plane.use_pace(FlightPace.speed(pace))
	plane.use_weight(weight)
	plane.floor_y = -300.0
	plane.ceiling_y = Scarp.SCARP_H+500.0
	plane.stone = func(_p: Vector3) -> bool: return true
	plane.launch(at,heading,plane.cruise(),false)
	if figure == null:
		figure = PlaneFigure.new()
		figure.name = "Plane"
		add_child(figure)
	figure.reset(plane)
	ground_scale.reset(false)
	ground_scale.apply(figure)
	figure._mark.visible = false
	chase = GlideCamera.new()
	chase.framed = true
	chase.floor_at = func(p: Vector3) -> float: return height(p.x,p.z)
	chase.reset(plane,at+(-plane.forward()*GlideCamera.BACK.x+Vector3.UP*GlideCamera.UP.x)*ground_scale.size(),camera.fov)
	chase.linger = LOOK_LINGER
	chase.use_weight(FlightWeight.knobs(weight))
	chase.close_in = CLOSE_IN
	chase.close_down = CLOSE_DOWN
	chase.speed_fov = RUSH_FOV
	chase.size = ground_scale.size()
	chase.lift = ground_scale.lift()
	var span := WorldScale.TOY_SPAN*ground_scale.size()
	chase.near = span*GlideCamera.NEAR_SPANS
	chase.extent = span*0.5
	chase.cruise = plane.cruise()/float(plane.pace_scale)
	var view := get_viewport().get_visible_rect().size
	if view.y > 0.0: chase.aspect = view.x/view.y
	_frame(0.0)

## Back to the start: over the approach's low end, toward the scarp.
func respawn() -> void:
	launch(Vector3(_start.x,height(_start.x,_start.z)+_start.y,_start.z),_heading)

func _physics_process(delta: float) -> void:
	if flight_ready and not scripted: tick(delta,_fly_input())

## One tick with `input` (the keys', or a driver's).
func tick(delta: float, input: Dictionary) -> void:
	var was: Vector3 = plane.position
	plane.step(delta,input,Callable(self,"ground"))
	if _space != null: RuinBump.bump(_space,plane,was)
	figure.update(delta,plane,0.0,Callable(self,"ground"),false)
	_frame(delta)

## The plane's middle over the ground (m).
func clearance() -> float:
	var p: Vector3 = plane.position
	return p.y-height(p.x,p.z)

func _frame(delta: float) -> void:
	if not scripted:
		var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
		if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*maxf(delta,0.0))
		chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	chase.step(delta,plane,0.0,_under)
	var way := chase.look-chase.eye
	if way.length() < 0.01: way = plane.forward()
	camera.global_transform = Transform3D(Basis.looking_at(way,Vector3.UP),chase.eye)
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

## Under the land, for the camera to keep out of.
func _under(p: Vector3) -> bool:
	return p.y < height(p.x,p.z)+0.3

func _fly_input() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":_boost(),"brake":Input.get_action_strength(&"fly_brake"),"roll":_roll_asked}
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	return input

## Boost: F or the pad's right trigger (Space and the south face roll).
func _boost() -> float:
	var b := 1.0 if Input.is_key_pressed(KEY_F) else 0.0
	for pad: int in Input.get_connected_joypads():
		b = maxf(b,Input.get_joy_axis(pad,JOY_AXIS_TRIGGER_RIGHT))
	return clampf(b,0.0,1.0)

## Space / the pad's south face: a roll toward the side leant to, else the
## way banked, else the way the stick turns, else right.
func roll_button() -> void:
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left")
	var turn := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back").x
	var bank := float(plane.bank)
	if absf(lean) > 0.2: _roll_asked = signf(lean)
	elif absf(bank) > 0.05: _roll_asked = signf(bank)
	elif absf(turn) > 0.2: _roll_asked = signf(turn)
	else: _roll_asked = 1.0

func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

func _unhandled_input(event: InputEvent) -> void:
	if not flight_ready: return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		roll_button()
	elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_R: respawn()
			KEY_SPACE: roll_button()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
