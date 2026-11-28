extends Node3D
## A piece to fly on its own: the fin ridge splitting a clearing
## (scripts/pieces/fin_ridge.gd holds its land and every size). Greybox:
## the land a vertex-coloured mesh (grass, bare rock by slope, forest floor),
## stand-in trees (cone and trunk), the wilderness waterfall down the east
## cliff into its pool. Flown by the game's plane and chase camera as
## studies/burrower_study.gd sets them up; the plane meets the land through
## its height (no crash: it skims and is turned aside), the trees through
## static bodies on RuinBump.LAYER.
##
## Keys: as endless flight (A D bank, W S pitch, mouse steers, Shift brake,
## Space boost, Q E knife edge), R back to the start.
## Flags: --at=x,z --alt=m --heading=deg (the launch; default over the
## clearing off the ridge's south end, heading north along it).

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
const Waterfall = preload("res://scripts/endless/world/wilderness/waterfall.gd")
const Ridge = preload("res://scripts/pieces/fin_ridge.gd")

## The land's meshes: the ridge's box finely, the rest coarser (m a step).
const FINE := 2.0
const COARSE := 6.0
const GRASS := Color("5f8a3a")
const TOP_GRASS := Color("6d9440")
const FOREST_FLOOR := Color("3f5e2a")
const ROCK := Color("8a7a66")
const ROCK_DARK := Color("6e6252")
const LEAF := Color("2f5a28")
const LEAF_LIGHT := Color("4c7a30")
const BARK := Color("4a3a2a")
const WATER := Color("3d6a7a")

const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
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
var tree_count := 0
var _space: PhysicsDirectSpaceState3D
var _fly_look := Vector2.ZERO
var _start := Vector3(0.0,40.0,Ridge.RIDGE_LENGTH*0.5+160.0)
var _heading := 0.0

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
	_build_land()
	var t1 := Time.get_ticks_msec()
	_build_trees()
	_build_fall()
	print("fin ridge piece: land %d ms, trees %d ms (%d)" % [t1-t0,Time.get_ticks_msec()-t1,tree_count])
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
	sky.ground_bottom_color = Color("4a5a3a")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("d8e0e0")
	environment.fog_density = 0.00012
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0,-55.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.far = 4000.0
	add_child(camera)
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "A D bank  ·  W S pitch  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  Q E knife edge  ·  R back to the start"
	hint.position = Vector2(16.0,12.0)
	hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	hint.add_theme_constant_override("outline_size",4)
	layer.add_child(hint)

## The ridge's box (x0, z0, x1, z1), on the coarse grid's lines.
func _ridge_box() -> Rect2:
	var hx := ceilf((Ridge.BEND+Ridge.BASE_WIDTH*0.5+Ridge.WOBBLE+40.0)/COARSE)*COARSE
	var hz := ceilf((Ridge.RIDGE_LENGTH*0.5+30.0)/COARSE)*COARSE
	return Rect2(-hx,-hz,hx*2.0,hz*2.0)

func _build_land() -> void:
	var half := ceilf((Ridge.CLEARING_R+Ridge.FOREST_RUN+120.0)/COARSE)*COARSE
	var box := _ridge_box()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	_grid("Ridge",box.position,int(box.size.x/FINE),int(box.size.y/FINE),FINE,Rect2(),m)
	_grid("Clearing",Vector2(-half,-half),int(half*2.0/COARSE),int(half*2.0/COARSE),COARSE,box,m)
	_build_canopy(half)

## The forest ring's canopy: a lumpy dark-green sheet over the floor, from
## its ragged edge out (cells wholly in the clearing left out).
func _build_canopy(half: float) -> void:
	var n := int(half*2.0/COARSE)
	var w := n+1
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	verts.resize(w*w)
	colours.resize(w*w)
	var lifted := PackedByteArray()
	lifted.resize(w*w)
	for j in w:
		for i in w:
			var x := -half+i*COARSE
			var z := -half+j*COARSE
			var rise := Ridge.canopy_rise(x,z)
			# Tucked just under the ground where it meets it (no z-fight).
			verts[j*w+i] = Vector3(x,Ridge.height(x,z)+rise-0.4,z)
			lifted[j*w+i] = 1 if rise > 0.0 else 0
			colours[j*w+i] = LEAF.lerp(LEAF_LIGHT,0.3+0.3*sin(x*0.05)*sin(z*0.06)).darkened(0.1)
	var index := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j*w+i
			if lifted[a]+lifted[a+1]+lifted[a+w]+lifted[a+w+1] == 0: continue
			index.append_array([a,a+1,a+w,a+1,a+w+1,a+w])
	var st := SurfaceTool.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	st.create_from_arrays(arrays)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	var node := MeshInstance3D.new()
	node.name = "Canopy"
	node.mesh = st.commit()
	node.material_override = m
	add_child(node)

## A grid mesh of the land from `origin`, `nx` by `nz` cells of `step` m,
## leaving out the cells inside `hole`.
func _grid(label: String, origin: Vector2, nx: int, nz: int, step: float, hole: Rect2, m: Material) -> void:
	var w := nx+1
	var hs := PackedFloat32Array()
	hs.resize((nx+3)*(nz+3))
	# Heights with a one-cell border, for the normals.
	for j in nz+3:
		for i in nx+3:
			hs[j*(nx+3)+i] = Ridge.height(origin.x+(i-1)*step,origin.y+(j-1)*step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	verts.resize(w*(nz+1))
	normals.resize(w*(nz+1))
	colours.resize(w*(nz+1))
	for j in nz+1:
		for i in w:
			var b := (j+1)*(nx+3)+(i+1)
			var x := origin.x+i*step
			var z := origin.y+j*step
			var y := hs[b]
			var nm := Vector3(hs[b-1]-hs[b+1],2.0*step,hs[b-(nx+3)]-hs[b+(nx+3)]).normalized()
			var k := j*w+i
			verts[k] = Vector3(x,y,z)
			normals[k] = nm
			colours[k] = _colour(x,z,y,nm)
	var index := PackedInt32Array()
	for j in nz:
		for i in nx:
			if hole.size != Vector2.ZERO:
				var c := origin+Vector2((i+0.5)*step,(j+0.5)*step)
				if hole.has_point(c): continue
			var a := j*w+i
			index.append_array([a,a+1,a+w,a+1,a+w+1,a+w])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = m
	add_child(node)

func _colour(x: float, z: float, y: float, nm: Vector3) -> Color:
	var r := Vector2(x,z).length()
	var c := GRASS.lerp(FOREST_FLOOR,smoothstep(Ridge.CLEARING_R-30.0,Ridge.CLEARING_R+40.0,r))
	var rise := Ridge.ridge_height(x,z)
	if rise > 1.0: c = TOP_GRASS
	var rock := smoothstep(Ridge.ROCK_UP+0.06,Ridge.ROCK_UP-0.06,nm.y)
	var stone := ROCK.lerp(ROCK_DARK,0.5+0.5*sin(y*0.35+x*0.05))
	c = c.lerp(stone,rock)
	return c.lerp(c*0.88,0.5+0.5*sin(x*0.07)*sin(z*0.09))

## The stand-in trees: a trunk and a cone crown each (two MultiMeshes), and
## a cylinder on RuinBump.LAYER each for the plane to glance off.
func _build_trees() -> void:
	var list := Ridge.trees()
	tree_count = list.size()
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.0
	crown.height = 1.0
	crown.radial_segments = 8
	crown.rings = 1
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.6
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var crowns := _multi(crown,list.size(),"Crowns")
	var trunks := _multi(trunk,list.size(),"Trunks")
	var body := StaticBody3D.new()
	body.name = "TreeBodies"
	body.collision_layer = RuinBump.LAYER
	body.collision_mask = 0
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = Ridge.TREE_SEED+1
	for i in list.size():
		var t: Dictionary = list[i]
		var at: Vector3 = t.at
		var tall := float(t.tall)
		var r := tall*rng.randf_range(0.2,0.28)
		var spin := Basis(Vector3.UP,rng.randf()*TAU)
		crowns.set_instance_transform(i,Transform3D(spin.scaled(Vector3(r,tall*0.8,r)),at+Vector3.UP*(tall*0.2+tall*0.4)))
		crowns.set_instance_color(i,LEAF.lerp(LEAF_LIGHT,rng.randf()))
		trunks.set_instance_transform(i,Transform3D(spin.scaled(Vector3(tall*0.025,tall*0.3,tall*0.025)),at+Vector3.UP*tall*0.15))
		trunks.set_instance_color(i,BARK)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r*0.7
		cyl.height = tall
		shape.shape = cyl
		shape.position = at+Vector3.UP*tall*0.5
		body.add_child(shape)

func _multi(mesh: Mesh, count: int, label: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.material_override = m
	add_child(node)
	return mm

## The waterfall (the wilderness's curtain skin) down the east cliff, and
## its pool's water.
func _build_fall() -> void:
	var lip := Ridge.fall_lip()
	var pool := Ridge.pool_centre()
	var out := Ridge.side_normal(Ridge.FALL_T,Ridge.FALL_SIDE)
	var root := Node3D.new()
	root.name = "Waterfall"
	add_child(root)
	Waterfall.dress(root,{"lip": lip, "out": out, "pool": Vector3(pool.x,Ridge.POOL_Y,pool.y),
		"drop": lip.y-Ridge.POOL_Y, "half": 6.0},{})
	var water := MeshInstance3D.new()
	water.name = "PoolWater"
	var disc := CylinderMesh.new()
	disc.top_radius = Ridge.POOL_R*1.05
	disc.bottom_radius = Ridge.POOL_R*1.05
	disc.height = 0.05
	disc.radial_segments = 32
	water.mesh = disc
	var wm := StandardMaterial3D.new()
	wm.albedo_color = WATER
	wm.roughness = 0.15
	wm.metallic = 0.2
	water.material_override = wm
	water.position = Vector3(pool.x,Ridge.POOL_Y,pool.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

## The plane's ground (SkyGlide `step`): the land's height under it.
func ground(p: Vector3) -> Variant:
	return Ridge.solid_height(p.x,p.z)

## Flying from `at` on `heading`, at cruise, the chase camera behind it.
func launch(at: Vector3, heading: float) -> void:
	plane = SkyPlane.new()
	plane.use_flight_speed()
	plane.use_pace(FlightPace.speed(pace))
	plane.use_weight(weight)
	plane.floor_y = -40.0
	plane.water = Ridge.POOL_Y
	plane.ceiling_y = 900.0
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
	chase.floor_at = func(p: Vector3) -> float: return maxf(Ridge.solid_height(p.x,p.z),Ridge.POOL_Y)
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

## Back to the start: over the clearing off the ridge's south end.
func respawn() -> void:
	launch(Vector3(_start.x,Ridge.height(_start.x,_start.z)+_start.y,_start.z),_heading)

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
	return p.y-maxf(Ridge.solid_height(p.x,p.z),Ridge.POOL_Y)

func _frame(delta: float) -> void:
	if not scripted:
		var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
		if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*maxf(delta,0.0))
		chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	chase.step(delta,plane,0.0,_solid)
	var way := chase.look-chase.eye
	if way.length() < 0.01: way = plane.forward()
	camera.global_transform = Transform3D(Basis.looking_at(way,Vector3.UP),chase.eye)
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

## Under the land or the water, for the camera to keep out of.
func _solid(p: Vector3) -> bool:
	return p.y < maxf(Ridge.solid_height(p.x,p.z),Ridge.POOL_Y)+0.3

func _fly_input() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),"roll":0.0}
	_fly_look = Vector2.ZERO
	return input

func _unhandled_input(event: InputEvent) -> void:
	if not flight_ready: return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_R: respawn()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
