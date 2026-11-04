extends Node3D
## Spray off the big swell's breaking crests (spec-big-swell.md, task 3). One
## mesh of cards, one draw, one shader (shaders/surge_spray.gdshader), which
## places, moves and drops every card from the sea's clock and the eye, so the
## only CPU is a look at where the eye is each frame and at the sky's haze
## twice a second. The cards sit in three rings round the eye, small near and
## big far; away from the belt the mesh is hidden. No collision: it is air.
## --spray=0 none.

const SHADER := preload("res://shaders/surge_spray.gdshader")
const LaunchArgs := preload("res://scripts/launch_args.gd")
const Field := preload("res://scripts/endless/land_field.gd")

## Over the cloud sheet, as the Peak's spindrift (EndlessClouds.RENDER_PRIORITY).
const PRIORITY := 7
## The rings: tile (m), shown from, gone by (m from the eye), card size (m),
## cards, life (s, least and most), climb (m).
const RINGS := [
	{"tile":720.0, "from":0.0, "to":340.0, "size":6.0, "cards":1800, "life":Vector2(1.2,2.0), "climb":4.0},
	{"tile":1900.0, "from":280.0, "to":900.0, "size":10.0, "cards":1800, "life":Vector2(1.4,2.4), "climb":5.0},
	{"tile":4800.0, "from":760.0, "to":2300.0, "size":17.0, "cards":2000, "life":Vector2(1.6,2.8), "climb":6.0},
]
## The surge uniforms the cards read as the sea does (EndlessSea's material).
const SHARED := ["surge_edge","surge_belt","surge_size","surge_peak","surge_break","swell_heading"]
## How often the sky's haze is read (s).
const HAZE_EVERY := 0.5

var stats := {"cards":0, "verts":0}

var _host: Node
var _sea: ShaderMaterial
var _edge := Vector4.ZERO
var _reach := 0.0
## Where the belt starts past the edge line (m; surge_belt.x).
var _belt_from := -2400.0
var _mat: ShaderMaterial
var _inst: MeshInstance3D
var _wait := 0.0

static func wanted() -> bool:
	return not "--spray=0" in LaunchArgs.user_args()

## `host` the study (its look gives the haze), `sea` the sea's material, `edge`
## the edge line the surge runs in from.
func setup(host: Node, sea: ShaderMaterial, edge: Vector4) -> void:
	name = "SurgeSpray"
	_host = host
	_sea = sea
	_edge = edge
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("surge/spray")
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var ix := PackedInt32Array()
	var corners := [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
	for r: Dictionary in RINGS:
		var life: Vector2 = r.life
		for i in int(r.cards):
			var base := v.size()
			var seeds := [rng.randf(),float(stats.cards)+rng.randf(),rng.randf_range(life.x,life.y),float(r.climb)*rng.randf_range(0.6,1.3)]
			for c: Vector2 in corners:
				v.append(Vector3.ZERO)
				uv.append(c)
				c0.append_array([float(r.tile),float(r.from),float(r.to),float(r.size)*rng.randf_range(0.75,1.25)])
				c1.append_array(seeds)
			ix.append_array([base,base+1,base+2,base,base+2,base+3])
			stats.cards += 1
		_reach = maxf(_reach,float(r.to))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_CUSTOM0] = c0
	arrays[Mesh.ARRAY_CUSTOM1] = c1
	arrays[Mesh.ARRAY_INDEX] = ix
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	# The cards go wherever the belt is: the whole edge square and past it.
	var half := edge.z+_reach+3000.0
	mesh.custom_aabb = AABB(Vector3(edge.x-half,Field.SEA_Y-60.0,edge.y-half),Vector3(half*2.0,160.0,half*2.0))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = PRIORITY
	_mat.set_shader_parameter("sea_y",Field.SEA_Y)
	for k: String in SHARED:
		var val: Variant = sea.get_shader_parameter(k)
		if val != null: _mat.set_shader_parameter(k,val)
	var belt: Variant = sea.get_shader_parameter("surge_belt")
	if belt != null: _belt_from = Vector4(belt).x
	_inst = MeshInstance3D.new()
	_inst.name = "Cards"
	_inst.mesh = mesh
	_inst.material_override = _mat
	_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_inst.visible = false
	add_child(_inst)
	stats.verts = v.size()
	_read_look()

func _process(delta: float) -> void:
	if _inst == null: return
	var view := get_viewport().get_camera_3d()
	if view == null: return
	var eye := view.global_position
	_inst.visible = Field.GDField.edge_off(_edge,eye.x,eye.z) > _belt_from-_reach
	if not _inst.visible: return
	_wait -= delta
	if _wait <= 0.0:
		_wait = HAZE_EVERY
		_read_look()

## The haze the cloud sheet draws with, for the spray to sit in the same air
## (as PeakSpindrift does).
func _read_look() -> void:
	if _host == null or _host.get("look") == null or _host.look.clouds == null: return
	var sheet: ShaderMaterial = _host.look.clouds.material
	var shape: Texture2D = _host.look.clouds.effect.resolved_b
	if shape != null: _mat.set_shader_parameter("cloud_shape",shape)
	if sheet != null:
		for k: String in ["haze","haze_height"]:
			var val: Variant = sheet.get_shader_parameter(k)
			if val != null: _mat.set_shader_parameter(k,val)
