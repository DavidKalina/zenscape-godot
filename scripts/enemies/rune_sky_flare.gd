extends Node3D
## The flare on the rune knight's blade while he gathers at the plane
## (task 18b): a bright point and a short vertical glint, like a lighthouse
## catching, that shows from his whole sky sight (90 m) in the plane's
## chase camera.
##
## - `follow(socket)`: sits on that node (his `blade` socket) each frame.
## - `on`: true while he gathers and swings at the plane; it eases in over
##   RISE s and out over FALL s.
## - `catch_light()`: one big flash of the glint (the gather's `full`).
## - Its size is never less than POINT_FAR / GLINT_FAR of its distance from
##   the camera, so it holds a few pixels from far and is a small spark near.
##   Drawn over everything near it (no depth test): he only gathers at a
##   plane he has a clear line to.

const POINT := 0.5
const POINT_FAR := 0.03
const GLINT := 2.2
const GLINT_FAR := 0.13
const GLINT_THIN := 0.1
## The white core over the blue halo, a share of the halo's size.
const CORE := 0.4
const RISE := 0.5
const FALL := 0.35
## The glint's catches: one every CATCH_EVERY s while lit, sharp.
const CATCH_EVERY := 0.55
## The halo and glint in his rune blue (it reads against white cloud as
## well as blue sky), the core white.
const TINT := Color(0.35,0.82,1.0)
const CORE_TINT := Color(1.0,1.0,1.0)

var on := false
var level := 0.0
var _flash := 0.0
var _clock := 0.0
var _socket: Node3D
var _point: MeshInstance3D
var _glint: MeshInstance3D
var _core: MeshInstance3D

static var _mat: StandardMaterial3D
static var _core_mat: StandardMaterial3D

func _init() -> void:
	name = "SkyFlare"
	top_level = true

func _ready() -> void:
	if _mat == null:
		var g := Gradient.new()
		g.set_color(0,Color(1,1,1,1))
		g.set_color(1,Color(1,1,1,0))
		g.add_point(0.25,Color(1,1,1,0.85))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5,0.5)
		tex.fill_to = Vector2(1.0,0.5)
		tex.width = 64
		tex.height = 64
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mat.billboard_keep_scale = true
		_mat.no_depth_test = true
		_mat.disable_fog = true
		_mat.vertex_color_use_as_albedo = false
		_mat.albedo_texture = tex
		_mat.albedo_color = TINT
		_mat.render_priority = 10
		_core_mat = _mat.duplicate()
		_core_mat.albedo_color = CORE_TINT
		_core_mat.render_priority = 11
	_point = _quad("Point",_mat)
	_glint = _quad("Glint",_mat)
	_core = _quad("Core",_core_mat)
	visible = false

func _quad(label: String, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.name = label
	m.mesh = q
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

func follow(socket: Node3D) -> void:
	_socket = socket

func catch_light() -> void:
	_flash = 1.0

func _process(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	level = move_toward(level,1.0 if on else 0.0,delta/(RISE if on else FALL))
	_flash = maxf(0.0,_flash-delta*2.2)
	visible = level > 0.001
	if not visible: return
	if _socket != null and is_instance_valid(_socket): global_position = _socket.global_position
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(global_position) if cam != null else 10.0
	var e := level*level*(3.0-2.0*level)
	var beat := pow(maxf(0.0,sin(_clock*TAU/CATCH_EVERY)),8.0)
	var pulse := 1.0+0.12*sin(_clock*31.0)
	var p := maxf(POINT,d*POINT_FAR)*e*pulse*(1.0+0.6*_flash)
	var g := maxf(GLINT,d*GLINT_FAR)*e*(0.45+0.55*beat+1.0*_flash)
	_point.scale = Vector3(p,p,1.0)
	_core.scale = Vector3(p,p,1.0)*CORE
	_glint.scale = Vector3(maxf(p*GLINT_THIN*2.0,g*GLINT_THIN),g,1.0)
