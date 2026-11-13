extends Node3D
## The temple kit's gallery (docs/design/temple-kit/spec-temple-kit.md):
## every piece in TempleKit.PIECES on grass under the game's own sky and
## light, in a row a few bays apart, and a pair of columns one BAY apart to
## show the gap the plane flies.
##   ./run-temple-kit.command [--hour=17.5] [--piece=column]
## Drag to orbit, wheel to zoom, 1-9 to frame a piece, 0 the whole row.
## --at=x,y,z --look=x,y,z put the eye there (shot.py places its own).
const TempleKit = preload("res://scripts/temple_kit.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://scripts/shared/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")

## The game's look, as the ruin gallery restores it (studies/ruin_kit_gallery.gd).
const GAME_LOOK := {"version":1,"palette":"Custom","colors":{"grass":[0.3647,0.6196,0.3255],"foliage":[0.2784,0.4627,0.2902],
	"rock":[0.5529,0.5216,0.4667],"earth":[0.4157,0.3137,0.2431],"water":[0.2235,0.4902,0.4745],"sun":[0.9804,0.8392,0.6863],
	"ambient":[0.5608,0.7020,0.8510],"bounce":[0.2902,0.3216,0.2510],"rim":[0.4980,0.6588,0.7882],"fog":[0.8627,0.8863,0.8745],
	"sky":[0.4784,0.6,0.8],"horizon":[0.7529,0.7922,0.7961],"glow":[0.9529,0.7843,0.6667]},
	"settings":{"strength":0.7416,"sun_energy":1.041,"ambient_energy":1.3539,"exposure":1.0896}}
const CLOUD := 0.14
const DECK := Vector2(20.0,12.0)
## The hour (scripts/shared/celestial.gd phase): the ruin gallery's late
## morning; --hour=H for another (17.5 the dusk).
const DAY := 0.45
const GRASS := Color(0.3647,0.6196,0.3255)
## Pieces stand this far apart along x; the pair of columns behind them.
const SPACING := 2.0*TempleKit.BAY
const PAIR_Z := -40.0

var _lighting: LandscapeLighting
var _celestial: Celestial
var _look: LookPass
var _camera: Camera3D
var _environment: Environment
## What the look pass reads off the scene it dresses (scripts/look_pass.gd).
var _display_fog: CanvasLayer = null
var _precipitation := {"ground_texture":null}
var _spots: Array[Vector3] = []
var _focus := Vector3(0.0,15.0,0.0)
var _yaw := 0.6
var _pitch := 0.25
var _distance := 90.0
var _drag := false

func _ready() -> void:
	_build_world()
	_build_ground()
	_build_pieces()
	_celestial.set_phase(DAY)
	var eye := Vector3.INF
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--hour="): _celestial.set_phase(float(arg.get_slice("=",1))/24.0)
		elif arg.begins_with("--at="): eye = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--look="): _focus = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--piece="):
			var i := TempleKit.PIECES.find(StringName(arg.get_slice("=",1)))
			if i >= 0: _frame(i)
	if eye != Vector3.INF:
		var off := eye-_focus
		_distance = off.length()
		_pitch = asin(clampf(off.y/maxf(_distance,0.01),-1.0,1.0))
		_yaw = atan2(off.x,off.z)

func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

func _build_world() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 400.0
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
	_camera.fov = 50.0
	_camera.near = 0.1
	_camera.far = 6000.0
	add_child(_camera)
	_camera.make_current()

## A wide grass plate, its colour mottled by vertex, gently rolling past the
## pieces, drawn with the kit's stone shader (grain softened) so it takes the
## same light.
func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 120
	var size := 2400.0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.01
	var lin := GRASS.srgb_to_linear()
	var height := func(x: float, z: float) -> float:
		var d := Vector2(x,z).length()
		return noise.get_noise_2d(x*0.3,z*0.3)*6.0*smoothstep(150.0,500.0,d)-0.05
	for i in n:
		for j in n:
			var x0 := -size/2+size*i/n
			var z0 := -size/2+size*j/n
			var x1 := x0+size/n
			var z1 := z0+size/n
			var pts := [Vector3(x0,height.call(x0,z0),z0),Vector3(x1,height.call(x1,z0),z0),Vector3(x1,height.call(x1,z1),z1),Vector3(x0,height.call(x0,z1),z1)]
			for k in [0,1,2,0,2,3]:
				var p: Vector3 = pts[k]
				var v := 1.0+noise.get_noise_2d(p.x*3.0,p.z*3.0)*0.12
				st.set_color(Color(lin.r*v,lin.g*v,lin.b*v))
				st.add_vertex(p)
	st.generate_normals()
	var mat: ShaderMaterial = TempleKit.material().duplicate()
	mat.set_shader_parameter("grain",0.08)
	mat.set_shader_parameter("pits",0.0)
	mat.set_shader_parameter("bump",0.0)
	for k in ["streaks","lichen","dirt","moss_top"]: mat.set_shader_parameter(k,0.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	st.set_material(mat)
	ground.mesh = st.commit()
	add_child(ground)

func _build_pieces() -> void:
	var count := TempleKit.PIECES.size()
	for i in count:
		var id: StringName = TempleKit.PIECES[i]
		var node := TempleKit.piece(id)
		node.position = Vector3((i-(count-1)*0.5)*SPACING,0.0,0.0)
		add_child(node)
		_spots.append(node.position)
	# A pair of columns one bay apart, as the temple stands them.
	for k in 2:
		var col := TempleKit.piece(&"column")
		col.name = "Pair%d" % k
		col.position = Vector3((k-0.5)*TempleKit.BAY,0.0,PAIR_Z)
		col.rotation.y = k*0.7
		add_child(col)

func _frame(i: int) -> void:
	if i < 0 or i >= _spots.size():
		_focus = Vector3(0.0,15.0,PAIR_Z*0.5)
		_distance = 60.0+_spots.size()*SPACING*0.6
		return
	_focus = _spots[i]+Vector3(0.0,15.0,0.0)
	_distance = 60.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT: _drag = b.pressed
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed: _distance = maxf(3.0,_distance*0.9)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed: _distance = minf(1500.0,_distance*1.1)
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x*0.006
		_pitch = clampf(_pitch+mm.relative.y*0.006,-0.2,1.45)
	elif event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9: _frame(k-KEY_1)
		elif k == KEY_0: _frame(-1)

func _process(_delta: float) -> void:
	_camera.position = _focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
	_camera.look_at(_focus)
	RenderingServer.global_shader_parameter_set("zs_camera_position",_camera.global_position)
	_look.update(get_viewport().get_camera_3d(),_celestial)
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,DECK.x,DECK.y))
