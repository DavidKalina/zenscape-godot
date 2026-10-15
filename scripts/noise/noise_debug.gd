extends Node3D
## `--noise-debug` (scripts/noise/noise_bus.gd): every noise on the bus drawn
## as its hearing ring (radius its loudness, at hearing 1) on a flat circle
## where it was made, fading over FADE s; and every body's heard noise (scripts/enemies/
## body_hearing.gd, its lure) as a short post. A debug read, not the game's look.

const FADE := 1.6
const SEGMENTS := 48

var _rings: Array = []
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()

func _ready() -> void:
	name = "NoiseDebug"
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = true
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var bus := get_parent() as NoiseBus
	if bus != null: bus.noise_made.connect(_on_noise)

func _on_noise(n: NoiseBus.Sound) -> void:
	_rings.append([n.position,n.loudness,0.0,_colour(n.kind)])

func _colour(kind: StringName) -> Color:
	match kind:
		&"olmec_land": return Color(0.55,0.7,0.95)
		&"break": return Color(0.95,0.55,0.35)
		&"step","slide","splash": return Color(0.95,0.9,0.6)
	return Color(1.0,0.75,0.4)

func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	for r: Array in _rings: r[2] += delta
	_rings = _rings.filter(func(r: Array) -> bool: return float(r[2]) < FADE)
	var lines := false
	for r: Array in _rings:
		var at: Vector3 = r[0]
		var rad: float = r[1]
		var c: Color = r[3]
		c.a = 0.9*(1.0-float(r[2])/FADE)
		if not lines:
			_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			lines = true
		for i in SEGMENTS:
			var a := TAU*i/SEGMENTS
			var b := TAU*(i+1)/SEGMENTS
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(at+Vector3(sin(a)*rad,0.1,cos(a)*rad))
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(at+Vector3(sin(b)*rad,0.1,cos(b)*rad))
	# Each body's heard noise, a post where it goes to look.
	for e: Node in get_tree().get_nodes_in_group(&"noise_lures"):
		if not bool(e.get("active")) or not (e is Node3D): continue
		var p: Vector3 = (e as Node3D).global_position
		if not lines:
			_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			lines = true
		_mesh.surface_set_color(Color(0.6,0.85,1.0,0.9))
		_mesh.surface_add_vertex(p)
		_mesh.surface_set_color(Color(0.6,0.85,1.0,0.9))
		_mesh.surface_add_vertex(p+Vector3.UP*4.0)
	if lines: _mesh.surface_end()
