extends "res://studies/aqueduct_isle.gd"
## Fire study (scripts/flame.gd): the new fire, set down on the aqueduct
## isle's own turf in its own light, to judge by eye by day and by night.
## A bonfire in a ring of stones, a stone brazier, a pair of torches on
## posts and a candle on a block, east of the aqueduct; the wanderer starts
## facing them.
##   godot --path . res://studies/fire_study.tscn -- --no-title
##     [--phase=0..1] (the time of day; e.g. 0.5 noon, 0.85 night)
##     [--fire-wind=x,z] (lean the flames)
const Flame = preload("res://scripts/flame.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")

const START_AT := Vector2(110.0,11.0)
## [kind, (x, z), scale, prop]
const FIRES := [
	["bonfire",Vector2(118.0,2.0),1.0,"ring"],
	["brazier",Vector2(113.0,-2.0),1.0,"bowl"],
	["torch",Vector2(114.5,6.0),1.0,"post"],
	["torch",Vector2(121.5,6.5),1.0,"post"],
	["candle",Vector2(111.8,5.0),1.0,"block"],
]

var fires: Array[Node3D] = []
var _phase := -1.0
var _wind := Vector2.ZERO

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--phase="): _phase = float(arg.get_slice("=",1))
		elif arg.begins_with("--fire-wind="):
			var xz := arg.get_slice("=",1).split(",")
			if xz.size() == 2: _wind = Vector2(float(xz[0]),float(xz[1]))
	chain_on = false
	dragon_roost = false
	_no_lode = true
	isle_ready.connect(_stand_fires,CONNECT_ONE_SHOT)
	super._ready()

func _load_pack() -> void:
	super._load_pack()
	start = Vector3(START_AT.x,Art.TOP,START_AT.y)
	start_face = (Vector2(118.0,2.0)-START_AT).normalized()
	_last_stood = start

func plane_home() -> Vector4:
	var was := start
	start = Art.START
	var home := super.plane_home()
	start = was
	return home

func _stand_fires() -> void:
	if _phase >= 0.0 and _celestial != null: _celestial.set_phase(_phase)
	var holder := Node3D.new()
	holder.name = "Fires"
	add_child(holder)
	for f: Array in FIRES:
		var at: Vector2 = f[1]
		var ground := _turf_y(at)
		var base := Node3D.new()
		base.position = Vector3(at.x,ground,at.y)
		holder.add_child(base)
		var top := _prop(base,String(f[3]),float(f[2]))
		var flame: Node3D = Flame.new()
		flame.kind = f[0]
		flame.scale_by = float(f[2])
		flame.position = Vector3(0.0,top,0.0)
		base.add_child(flame)
		flame.set("wind",_wind)
		fires.append(flame)
	start.y = _turf_y(START_AT)+0.05

func _process(delta: float) -> void:
	super._process(delta)
	var night := StoneLampLights.night_for(_daylight_now())
	for f in fires: f.set("night",night)

func _daylight_now() -> float:
	if _celestial != null and _celestial.get("state") is Dictionary and _celestial.state.has("zs_daylight"):
		return float(_celestial.state.zs_daylight)
	return 1.0

# --- The props: plain, so the fire is what is judged ---------------------------

## Stands the fire's prop on `base`; returns the height its flame sits at.
func _prop(base: Node3D, prop: String, s: float) -> float:
	match prop:
		"ring":
			for i in range(11):
				var a := TAU*float(i)/11.0+0.2*sin(float(i)*3.1)
				var r := 1.25*s+0.08*sin(float(i)*5.7)
				_rock(base,Vector3(cos(a)*r,0.08*s,sin(a)*r),Vector3(0.42,0.3,0.36)*s*(0.85+0.3*fmod(float(i)*0.618,1.0)),float(i))
			# Logs leant in a cone, charred toward the heart.
			for i in range(7):
				var a := TAU*float(i)/7.0+0.3
				var foot := Vector3(cos(a)*0.85*s,0.05,sin(a)*0.85*s)
				var head := Vector3(cos(a+0.4)*0.12*s,0.85*s,sin(a+0.4)*0.12*s)
				_log(base,foot,head,0.09*s)
			_ash(base,1.05*s)
			return 0.02
		"bowl":
			_column(base,Vector3.ZERO,0.32*s,0.75*s,_stone())
			var bowl := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.62*s
			c.bottom_radius = 0.4*s
			c.height = 0.3*s
			c.radial_segments = 12
			bowl.mesh = c
			bowl.material_override = _stone()
			bowl.position = Vector3(0.0,0.9*s,0.0)
			base.add_child(bowl)
			_ash(base,0.5*s,1.04*s)
			return 1.02*s
		"post":
			_column(base,Vector3.ZERO,0.08*s,1.75*s,_wood())
			var wrap := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.1*s
			c.bottom_radius = 0.085*s
			c.height = 0.26*s
			wrap.mesh = c
			wrap.material_override = _cloth()
			wrap.position = Vector3(0.0,1.75*s+0.1*s,0.0)
			base.add_child(wrap)
			return 1.9*s
		"block":
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6,0.7,0.6)*s
			b.mesh = bm
			b.material_override = _stone()
			b.position = Vector3(0.0,0.35*s,0.0)
			base.add_child(b)
			_column(base,Vector3(0.0,0.7*s,0.0),0.03*s,0.12*s,_wax())
			return 0.83*s
	return 0.0

func _column(base: Node3D, at: Vector3, r: float, h: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r*0.92
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	m.position = at+Vector3(0.0,h*0.5,0.0)
	base.add_child(m)

func _rock(base: Node3D, at: Vector3, size: Vector3, seed_value: float) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radial_segments = 7
	s.rings = 4
	s.radius = 0.5
	s.height = 1.0
	m.mesh = s
	m.material_override = _stone()
	m.scale = size
	m.rotation = Vector3(0.3*sin(seed_value),seed_value*1.7,0.25*cos(seed_value*2.0))
	m.position = at
	base.add_child(m)

func _log(base: Node3D, foot: Vector3, head: Vector3, r: float) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r*0.8
	c.bottom_radius = r
	c.height = foot.distance_to(head)
	c.radial_segments = 8
	m.mesh = c
	m.material_override = _wood(true)
	var up := (head-foot).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.01: side = Vector3.RIGHT
	m.basis = Basis(side,up,side.cross(up)).orthonormalized()
	m.position = (foot+head)*0.5
	base.add_child(m)

func _ash(base: Node3D, r: float, y := 0.01) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.02
	m.mesh = c
	var mat := _noise_material(Color(0.16,0.15,0.14),0.9,0.12)
	mat.emission_enabled = true
	mat.emission = Color(0.6,0.12,0.02)
	mat.emission_energy_multiplier = 0.6
	mat.emission_texture = mat.albedo_texture
	m.material_override = mat
	m.position = Vector3(0.0,y,0.0)
	base.add_child(m)

var _mats := {}
func _stone() -> Material:
	if not _mats.has("stone"): _mats.stone = _noise_material(Color(0.42,0.42,0.43),1.0,0.5)
	return _mats.stone
func _wood(charred := false) -> Material:
	var k := "char" if charred else "wood"
	if not _mats.has(k): _mats[k] = _noise_material(Color(0.13,0.1,0.08) if charred else Color(0.3,0.22,0.15),0.95,0.9)
	return _mats[k]
func _cloth() -> Material:
	if not _mats.has("cloth"): _mats.cloth = _noise_material(Color(0.2,0.16,0.12),1.0,0.7)
	return _mats.cloth
func _wax() -> Material:
	if not _mats.has("wax"): _mats.wax = _noise_material(Color(0.78,0.72,0.6),0.6,0.3)
	return _mats.wax

## A plain material with grain: a noise in albedo, laid triplanar.
func _noise_material(colour: Color, rough: float, contrast: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.noise = n
	t.seamless = true
	var g := Gradient.new()
	g.set_color(0,colour.darkened(contrast))
	g.set_color(1,colour.lightened(contrast*0.5))
	t.color_ramp = g
	m.albedo_texture = t
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE*0.7
	m.roughness = rough
	return m

## The turf's top at `at` (x, z), or the isle's top off it.
func _turf_y(at: Vector2) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,Art.TOP+40.0,at.y),Vector3(at.x,Art.TOP-40.0,at.y),TURF_LAYER))
	return (hit.position as Vector3).y if not hit.is_empty() else Art.TOP
