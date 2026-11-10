extends Node3D
## The train yard (docs/design/endless-flight/spec-steam-train.md, lane `model`):
## the steam train's models (art/blender/train/train_build.py, into
## assets/models/train/) standing on a straight track, lit as the game is (its
## sky, sun and look pass: the ruin kit gallery's setup), for stills and to look
## round. Nothing here is played.
##
##   godot --path . res://studies/train_yard.tscn -- --no-title
##   python3 tools/shot.py studies/train_yard.tscn -- --no-title --view=three
##
## The cars stand as RailTrain's train does: each car's middle on the bed, the
## next GAP behind its coupler, forward -Z (scripts/endless/rail_train.gd). A kind
## with a model (assets/models/train/<kind>.glb) shows it; one without, its
## greybox blocks.
##
## Flags (after --):
##   --train          every car of RailTrain.CARS, not just those with models
##   --line=a,b,...   these kinds in this order instead (sizes from RailTrain.CARS,
##                    else the spec's table: SIZES), e.g. --line=box,doors,stock,flat,open,van;
##                    --line=24 the train as it runs (RailTrain.CARS)
##   --lod=near|far   the parts at every range (each Far hidden), or the far look
##                    at every range (train_import.gd sets where it starts)
##   --stats          print what the frame drew (draw calls, primitives, objects)
##   --solids         each car's colliders (RailTrain._parts) drawn over it, see-through
##   --view=NAME      three (default), side, front, back, top, close, gear, cab, coal
##   --car=N          frame car N (1 the engine) instead of the whole train
##   --yaw= --pitch= --distance= --look=x,y,z   the orbit, by hand (radians, m)
##   --night
## Drag to orbit, the wheel to zoom, 1-9 frame a car, 0 the whole train.

const RailTrain = preload("res://scripts/endless/rail_train.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://scripts/shared/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const MODELS := "res://assets/models/train/%s.glb"
## Sizes (length, top) for a kind RailTrain.CARS doesn't run (else 20 x 9).
const SIZES := {"box":[24.0,9.0]}
## The hours (scripts/shared/celestial.gd phase), as the gallery's: a late
## morning, and midnight.
const DAY := 0.45
const NIGHT := 0.0
## The game's own look at its noon (studies/ruin_kit_gallery.gd GAME_LOOK, from
## the look tour), and its cloud deck.
const GAME_LOOK := {"version":1,"palette":"Custom","colors":{"grass":[0.3647,0.6196,0.3255],"foliage":[0.2784,0.4627,0.2902],
	"rock":[0.5529,0.5216,0.4667],"earth":[0.4157,0.3137,0.2431],"water":[0.2235,0.4902,0.4745],"sun":[0.9804,0.8392,0.6863],
	"ambient":[0.5608,0.7020,0.8510],"bounce":[0.2902,0.3216,0.2510],"rim":[0.4980,0.6588,0.7882],"fog":[0.8627,0.8863,0.8745],
	"sky":[0.4784,0.6,0.8],"horizon":[0.7529,0.7922,0.7961],"glow":[0.9529,0.7843,0.6667]},
	"settings":{"strength":0.7416,"sun_energy":1.041,"ambient_energy":1.3539,"exposure":1.0896}}
const CLOUD := 0.14
const DECK := Vector2(20.0,12.0)
## How the yard is turned to the sun (radians): the sun onto the train's right
## side (+x), a little round toward its front.
const SUN_SIDE := 0.45
## The track runs this far past the train's ends (m); the ground's half size.
const TRACK_MORE := 40.0
const GROUND := 400.0
const GRASS := Color(0.36,0.47,0.27)
const RAIL_C := Color(0.36,0.36,0.38)
## The views: [yaw (radians, 0 from behind +z, PI/2 from the right), pitch, distance
## as a share of the framed length, focus up (m)].
const VIEWS := {"three":[2.25,0.28,1.15,3.5],"side":[PI*0.5,0.06,1.25,4.0],"front":[PI-0.12,0.12,0.9,4.0],
	"back":[0.35,0.2,1.1,4.0],"top":[PI*0.5,1.25,1.3,0.0],"close":[2.0,0.12,0.55,2.5],
	"gear":[PI*0.5+0.25,0.02,0.45,2.2],"cab":[1.0,0.35,0.6,6.0],"coal":[0.7,0.75,0.55,5.0]}

## What the look pass reads off the scene it dresses (scripts/look_pass.gd).
var _environment: Environment
var _lighting: LandscapeLighting
var _display_fog: CanvasLayer = null
var _precipitation := {"ground_texture":null}
var _motion_time := 0.0

var _celestial: RefCounted
var _look: Node
var _sun: DirectionalLight3D
var _camera: Camera3D
var _yard: Node3D
var _yard_yaw := 0.0
var _cars: Array[Dictionary] = []   # {kind, long, tall, z (middle), node}
var _focus := Vector3.ZERO
var _yaw := 2.25
var _pitch := 0.28
var _distance := 60.0
var _dragging := false
var _stats_at := -1
var _stats_cpu := 0.0
var _stats_gpu := 0.0
var _stats_n := 0
## --stats: frames to settle, then frames whose render times are averaged.
const STATS_SETTLE := 40
const STATS_FRAMES := 60
var _stats_tag := ""

func _ready() -> void:
	var whole := false
	var solids := false
	var night := false
	var view := "three"
	var car := 0
	var manual := {}
	var line: Array = []
	var lod := ""
	for arg in LaunchArgs.user_args():
		if arg == "--train": whole = true
		elif arg == "--line=24":
			line = []
			for row: Array in RailTrain.CARS: line.append(String(row[0]))
		elif arg.begins_with("--line="): line = Array(arg.get_slice("=",1).split(","))
		elif arg == "--solids": solids = true
		elif arg.begins_with("--lod="): lod = arg.get_slice("=",1)
		elif arg == "--stats":
			_stats_at = STATS_SETTLE+STATS_FRAMES
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
		elif arg == "--night": night = true
		elif arg.begins_with("--view="): view = arg.get_slice("=",1)
		elif arg.begins_with("--car="): car = int(arg.get_slice("=",1))
		elif arg.begins_with("--yaw="): manual.yaw = float(arg.get_slice("=",1))
		elif arg.begins_with("--pitch="): manual.pitch = float(arg.get_slice("=",1))
		elif arg.begins_with("--distance="): manual.distance = float(arg.get_slice("=",1))
		elif arg.begins_with("--look="):
			var p := arg.get_slice("=",1).split(",")
			manual.look = Vector3(float(p[0]),float(p[1]),float(p[2]))
	_build_world()
	_celestial.set_phase(NIGHT if night else DAY)
	_yard = Node3D.new()
	_yard.name = "Yard"
	add_child(_yard)
	_build_train(whole,solids,line)
	if not lod.is_empty(): _force_lod(lod)
	_stats_tag = "view %s car %d lod %s, %d cars" % [view,car,lod if not lod.is_empty() else "auto",_cars.size()]
	_build_ground()
	_face_sun()
	_frame(car,view)
	if manual.has("yaw"): _yaw = manual.yaw
	if manual.has("pitch"): _pitch = manual.pitch
	if manual.has("distance"): _distance = manual.distance
	if manual.has("look"): _focus = manual.look
	_place_camera()

func _build_world() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 200.0
	_sun = _lighting.lights[0]
	_celestial = Celestial.new()
	_celestial.setup(_lighting.lights)
	_celestial.cycling = false
	_celestial.cloud = CLOUD
	_celestial.look.restore(GAME_LOOK)
	var exposure: float = float(source.exposure)/1.08*float(_celestial.look.settings.exposure)
	_environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)
	_look = LookPass.new()
	_look.setup(self)
	_look.apply_tier(_look.tier)
	preload("res://scripts/render_resolution.gd").attach(get_viewport())
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.1
	_camera.far = 4000.0
	add_child(_camera)
	_camera.make_current()

## The cars nose to tail, the engine's middle at the origin: its models, or its
## greybox blocks.
func _build_train(whole: bool, solids: bool, line: Array) -> void:
	var z := 0.0
	var prev := -1.0
	var index := 0
	var rows: Array = RailTrain.CARS
	if not line.is_empty():
		rows = []
		for kind: String in line:
			var size: Array = SIZES.get(kind,[20.0,9.0])
			for row: Array in RailTrain.CARS:
				if String(row[0]) == kind: size = [row[1],row[2]]
			rows.append([kind,size[0],size[1]])
		whole = true
	for row: Array in rows:
		var kind := String(row[0])
		var long := float(row[1])
		var tall := float(row[2])
		var path := MODELS % kind
		var has_model := ResourceLoader.exists(path)
		if not has_model and not whole: continue
		if prev >= 0.0: z += prev*0.5+RailTrain.GAP+long*0.5
		prev = long
		index += 1
		var node: Node3D
		if has_model:
			node = (load(path) as PackedScene).instantiate()
		else:
			node = _greybox(kind,long,tall)
		node.name = "%s_%d" % [kind.capitalize(),index]
		node.position = Vector3(0.0,0.0,z)
		_yard.add_child(node)
		if solids: node.add_child(_solid_boxes(kind,long,tall))
		_cars.append({"kind":kind,"long":long,"tall":tall,"z":z,"node":node})

## Every car's far look (Far, FarPlugs) hidden ("near": the parts at every
## range) or shown at every range ("far": its parts never).
func _force_lod(lod: String) -> void:
	for c: Dictionary in _cars:
		for name: String in ["Far","FarPlugs"]:
			var far := (c.node as Node).find_child(name,true,false) as GeometryInstance3D
			if far == null: continue
			if lod == "near": far.visible = false
			elif lod == "far": far.visibility_range_begin = 0.0

func _greybox(kind: String, long: float, tall: float) -> Node3D:
	var root := Node3D.new()
	var parts: Dictionary = RailTrain._parts(kind,long,tall)
	for list: Array in [parts.solid,parts.dress]:
		for item: Array in list:
			var look := String(item[1])
			if look.is_empty(): continue
			var c: Color = RailTrain.LOOKS.get(look,Color.GRAY)
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			if item[0] is AABB:
				var a: AABB = item[0]
				box.size = a.size
				mi.position = a.get_center()
			else:
				var t: Transform3D = item[0]
				box.size = Vector3.ONE
				mi.transform = t
			box.material = _flat(c)
			mi.mesh = box
			root.add_child(mi)
	for plate: AABB in parts.plates:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = plate.size
		box.material = _flat(RailTrain.LOOKS.plate)
		mi.mesh = box
		mi.position = plate.get_center()
		root.add_child(mi)
	return root

## The car's colliders (its solid blocks and plates) as see-through boxes.
func _solid_boxes(kind: String, long: float, tall: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Solids"
	var parts: Dictionary = RailTrain._parts(kind,long,tall)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0,0.55,0.1,0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	var boxes: Array[AABB] = []
	for item: Array in parts.solid: boxes.append(item[0])
	for plate: AABB in parts.plates: boxes.append(plate)
	for a in boxes:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = a.size
		box.material = mat
		mi.mesh = box
		mi.position = a.get_center()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root

## A plain colour lit as the greybox is: its share FILL showing in shade.
func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = c*RailTrain.FILL
	return m

## The ground, and the track under the train: ballast, sleepers and rails at
## rail_track.gd's sizes.
func _build_ground() -> void:
	var z0: float = -float(RailTrain.CARS[0][1])*0.5-TRACK_MORE
	var z1: float = TRACK_MORE
	if not _cars.is_empty():
		var last: Dictionary = _cars[-1]
		z1 = float(last.z)+float(last.long)*0.5+TRACK_MORE
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND*2.0,GROUND*2.0)
	plane.material = _flat(GRASS)
	ground.mesh = plane
	ground.position = Vector3(0.0,-0.02,(z0+z1)*0.5)
	_yard.add_child(ground)
	var long := z1-z0
	var mid := (z0+z1)*0.5
	# Ballast: a strip, its top BALLAST_HALF either side, its foot BALLAST_FOOT.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := RailTrack.BALLAST_TOP
	var ht := RailTrack.BALLAST_HALF
	var hf := RailTrack.BALLAST_FOOT
	var prof := [Vector2(-hf,-0.02),Vector2(-ht,top),Vector2(ht,top),Vector2(hf,-0.02)]
	for i in range(3):
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i+1]
		var p := [Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1)]
		st.add_vertex(p[0]); st.add_vertex(p[2]); st.add_vertex(p[1])
		st.add_vertex(p[0]); st.add_vertex(p[3]); st.add_vertex(p[2])
	st.generate_normals()
	var ballast := MeshInstance3D.new()
	ballast.mesh = st.commit()
	ballast.material_override = _flat(RailTrack.BALLAST_C)
	_yard.add_child(ballast)
	# Sleepers.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(RailTrack.SLEEPER_HALF*2.0,RailTrack.SLEEPER_TOP-RailTrack.SLEEPER_BASE,RailTrack.SLEEPER_WIDTH)
	sleeper.material = _flat(RailTrack.SLEEPER_C)
	mm.mesh = sleeper
	var count := int(long/RailTrack.SLEEPER_STEP)
	mm.instance_count = count
	for i in range(count):
		mm.set_instance_transform(i,Transform3D(Basis(),Vector3(0.0,(RailTrack.SLEEPER_TOP+RailTrack.SLEEPER_BASE)*0.5,z0+(i+0.5)*RailTrack.SLEEPER_STEP)))
	var sleepers := MultiMeshInstance3D.new()
	sleepers.multimesh = mm
	_yard.add_child(sleepers)
	# Rails.
	for s: float in [-1.0,1.0]:
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(RailTrack.RAIL_WIDTH,RailTrack.RAIL_TOP-RailTrack.SLEEPER_TOP,long)
		box.material = _flat(RAIL_C)
		rail.mesh = box
		rail.position = Vector3(s*RailTrack.GAUGE*0.5,(RailTrack.RAIL_TOP+RailTrack.SLEEPER_TOP)*0.5,mid)
		_yard.add_child(rail)

## Turns the yard so the sun falls on the train's right side (+x), a little round
## toward its front; the camera orbits in the yard's frame.
func _face_sun() -> void:
	_celestial.advance(0.0,true)
	var toward: Vector3 = _sun.global_basis.z
	var flat := Vector2(toward.x,toward.z)
	if flat.length() < 0.01: return
	_yard_yaw = atan2(flat.x,flat.y)-PI*0.5-SUN_SIDE
	_yard.rotation.y = _yard_yaw

## Frames car n (1 the engine; 0 the whole train) from a view.
func _frame(n: int, view: String) -> void:
	if _cars.is_empty(): return
	var v: Array = VIEWS.get(view,VIEWS.three)
	var z0: float
	var z1: float
	if n >= 1 and n <= _cars.size():
		var c: Dictionary = _cars[n-1]
		z0 = float(c.z)-float(c.long)*0.5
		z1 = float(c.z)+float(c.long)*0.5
	else:
		z0 = float(_cars[0].z)-float(_cars[0].long)*0.5
		z1 = float(_cars[-1].z)+float(_cars[-1].long)*0.5
	var long := z1-z0
	_focus = Vector3(0.0,float(v[3]),(z0+z1)*0.5)
	if view == "cab" or view == "gear" or view == "close" or view == "front":
		# The engine's end of it.
		_focus.z = z0+minf(long*0.5,11.0) if view != "cab" else z0+minf(long,18.0)
	if view == "coal" and _cars.size() > 1 and n == 0:
		_focus.z = float(_cars[1].z)
	_yaw = float(v[0])
	_pitch = float(v[1])
	_distance = maxf(long,20.0)*float(v[2])

func _place_camera() -> void:
	var frame := Transform3D(Basis(Vector3.UP,_yard_yaw),Vector3.ZERO)
	var off := Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
	_camera.position = frame*(_focus+off)
	_camera.look_at(frame*_focus,Vector3.UP if absf(_pitch) < 1.5 else Vector3.FORWARD)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT: _dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _distance *= 0.9
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _distance /= 0.9
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x*0.005
		_pitch = clampf(_pitch+mm.relative.y*0.005,-0.2,1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_0 and k <= KEY_9: _frame(k-KEY_0,"three")

func _process(delta: float) -> void:
	_motion_time += delta
	if _stats_at > 0:
		_stats_at -= 1
		if _stats_at < STATS_FRAMES:
			var vp := get_viewport().get_viewport_rid()
			_stats_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			_stats_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			_stats_n += 1
		if _stats_at == 0:
			print("| yard stats (%s): draw calls %d, primitives %d, objects %d; render cpu %.2f ms, gpu %.2f ms (mean of %d frames); camera %.0f m from the focus" % [_stats_tag,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				_stats_cpu/maxf(_stats_n,1),_stats_gpu/maxf(_stats_n,1),_stats_n,_distance])
	_celestial.advance(delta,true)
	_place_camera()
	RenderingServer.global_shader_parameter_set("zs_camera_position",_camera.global_position)
	RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
	_look.update(_camera,_celestial)
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,DECK.x,DECK.y))
