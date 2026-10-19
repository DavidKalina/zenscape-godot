extends Node3D
## The dig's bits (docs/design/dig/spec-dig.md, loop `dig`): clods of earth
## kicked up and flung, a beat of dust, stone chips and a spark off rock,
## the scoops left in the turf, and the sounds (the foley hammer-on-soil,
## hammer-on-rock, chisel knock and crumble takes, played through the
## isle's KitAudio pool).
##
## Scoops are laid on the turf (a dark dish and a rim of turned clods), the
## ground's collision untouched: KitLand's one trimesh per land is too dear
## to rebuild per dig (see the trail, ITER(dig) task 1).

const FOLEY := "res://assets/audio/foley/"
const EARTH := Color(0.27,0.17,0.09)
const EARTH_DARK := Color(0.11,0.07,0.04)
const EARTH_TURNED := Color(0.33,0.21,0.11)
const STONE := Color(0.70,0.68,0.64)
const DUST := Color(0.62,0.52,0.40,0.55)
const GRAVITY := 9.8
## Scoops kept at once (plain soil dug anywhere); the oldest goes.
const SCOOPS_MOST := 16

var audio: Node = null
var size := 1.0
var _bits: Array = []
var _scoops: Array[Node3D] = []
var _clod_mesh: Mesh
var _earth: StandardMaterial3D
var _stone: StandardMaterial3D
var _dust_mesh: Mesh
var _spark_mesh: Mesh
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "DigFx"
	top_level = true
	_rng.randomize()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_clod_mesh = box
	_earth = _flat(EARTH)
	_stone = _flat(STONE)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	_dust_mesh = ball
	var spark := SphereMesh.new()
	spark.radius = 0.5
	spark.height = 1.0
	spark.radial_segments = 6
	spark.rings = 3
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0,0.86,0.55)
	hot.emission_enabled = true
	hot.emission = Color(1.0,0.75,0.4)
	hot.emission_energy_multiplier = 4.0
	spark.material = hot
	_spark_mesh = spark

static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

## The sounds into the isle's pool (KitAudio `shot`), once.
func hook_audio(kit_audio: Node) -> void:
	audio = kit_audio

## (KitAudio fills its takes in its _ready, after the cluster's setup: the
## dig's are added at the first sound.)
func _hook_clips() -> void:
	if audio == null: return
	var clips: Variant = audio.get("_clips")
	if not (clips is Dictionary) or (clips as Dictionary).has("dig_soil"): return
	clips["dig_soil"] = _takes("hammer-soil-%d.wav",6)
	clips["dig_rock"] = _takes("hammer-rock-%d.wav",6)
	clips["dig_clank"] = _takes("chisel-knock-%d.wav",6)
	clips["dig_crumble"] = _takes("crumble-%d.wav",6)

static func _takes(pattern: String, count: int) -> Array:
	var out := []
	for i in range(1,count+1):
		var path := FOLEY+(pattern % i)
		if ResourceLoader.exists(path): out.append(load(path))
	return out

func sound(kind: String, gain: float, pitch: float, at: Vector3) -> void:
	_hook_clips()
	if audio != null and audio.has_method("shot"): audio.shot(kind,gain,pitch,at)

## The blade biting soil at `at`: dirt kicked up round it, a puff, the thunk.
func bite(at: Vector3, out: Vector3) -> void:
	sound("dig_soil",0.9,_rng.randf_range(0.85,1.0),at)
	for i in range(7):
		var v := out*_rng.randf_range(0.3,1.0)+Vector3(_rng.randf_range(-0.6,0.6),_rng.randf_range(1.0,2.0),_rng.randf_range(-0.6,0.6))
		_clod(at+Vector3.UP*0.03*size,v*sqrt(size),_rng.randf_range(0.025,0.045),_earth,at.y)
	_puff(at,4,0.10,0.5)

## The load flung off the blade at `at` along `way`: clods arcing out, a
## trail of dust, the crumble.
func fling(at: Vector3, way: Vector3, ground_y: float) -> void:
	sound("dig_crumble",0.7,_rng.randf_range(0.95,1.1),at)
	for i in range(14):
		var v := way*_rng.randf_range(1.4,2.6)+Vector3.UP*_rng.randf_range(1.2,2.4)+Vector3(_rng.randf_range(-0.4,0.4),0.0,_rng.randf_range(-0.4,0.4))
		_clod(at+Vector3(_rng.randf_range(-0.05,0.05),0.0,_rng.randf_range(-0.05,0.05))*size,v*sqrt(size),_rng.randf_range(0.025,0.055),_earth,ground_y)
	_puff(at,5,0.12,0.7)

## The blade off stone at `at`: the clank, chips and a spark, no hole.
func clank(at: Vector3) -> void:
	sound("dig_clank",1.0,_rng.randf_range(1.05,1.2),at)
	sound("dig_rock",0.6,_rng.randf_range(1.1,1.25),at)
	for i in range(9):
		var v := Vector3(_rng.randf_range(-1.6,1.6),_rng.randf_range(1.2,2.8),_rng.randf_range(-1.6,1.6))
		_clod(at+Vector3.UP*0.02*size,v*sqrt(size),_rng.randf_range(0.012,0.026),_stone,at.y)
	var spark := MeshInstance3D.new()
	spark.mesh = _spark_mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spark)
	spark.global_position = at+Vector3.UP*0.03*size
	_bits.append({"node":spark,"kind":"spark","age":0.0,"life":0.14})
	_puff(at,2,0.07,0.35)

func _clod(at: Vector3, v: Vector3, r: float, mat: Material, floor_y: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _clod_mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var s := r*size
	m.global_transform = Transform3D(Basis.from_euler(Vector3(_rng.randf()*TAU,_rng.randf()*TAU,_rng.randf()*TAU)).scaled(Vector3.ONE*s),at)
	_bits.append({"node":m,"kind":"clod","v":v,"spin":Vector3(_rng.randf_range(-12,12),_rng.randf_range(-12,12),0.0),
		"age":0.0,"life":_rng.randf_range(0.9,1.3),"floor":floor_y+s*0.4,"s":s})

func _puff(at: Vector3, n: int, r: float, life: float) -> void:
	for i in range(n):
		var m := MeshInstance3D.new()
		m.mesh = _dust_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = DUST
		mat.disable_receive_shadows = true
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		var off := Vector3(_rng.randf_range(-1,1),_rng.randf_range(0.2,0.8),_rng.randf_range(-1,1))*r*size
		m.global_position = at+off
		m.scale = Vector3.ONE*r*size*0.6
		_bits.append({"node":m,"kind":"dust","age":0.0,"life":life*_rng.randf_range(0.8,1.2),"r":r*size,"v":off.normalized()*0.25*size+Vector3.UP*0.3*size,"mat":mat})

func _process(delta: float) -> void:
	if _bits.is_empty() or delta <= 0.0: return
	var keep: Array = []
	for b: Dictionary in _bits:
		var node: Node3D = b.node
		b.age += delta
		var u: float = b.age/b.life
		if u >= 1.0 or not is_instance_valid(node):
			if is_instance_valid(node): node.queue_free()
			continue
		match b.kind:
			"clod":
				var p := node.global_position
				if p.y > b.floor or (b.v as Vector3).y > 0.0:
					b.v += Vector3.DOWN*GRAVITY*delta
					p += (b.v as Vector3)*delta
					if p.y < b.floor:
						p.y = b.floor
						b.v = Vector3.ZERO
					node.global_position = p
					node.rotate_object_local(Vector3.RIGHT,(b.spin as Vector3).x*delta)
				var shrink := clampf((1.0-u)/0.3,0.0,1.0)
				node.scale = Vector3.ONE*b.s*shrink
			"dust":
				node.global_position += (b.v as Vector3)*delta
				node.scale = Vector3.ONE*lerpf(b.r*0.6,b.r*1.8,sqrt(u))
				(b.mat as StandardMaterial3D).albedo_color.a = DUST.a*(1.0-u)*(1.0-u)
			"spark":
				node.scale = Vector3.ONE*0.16*size*sin(PI*u)
		keep.append(b)
	_bits = keep

# --- Scoops -------------------------------------------------------------------------

## A scoop laid at `at` on ground of normal `n`, its spoil toward `spoil`
## (a world way along the ground); `deep` 0 to 1 grows it (the second
## stroke deepens the first's). Returns the scoop.
func scoop(at: Vector3, n: Vector3, spoil: Vector3, deep := 0.5) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = "Scoop"
	node.mesh = _scoop_mesh(_rng.randi())
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var up := n.normalized()
	var x := spoil.slide(up).normalized()
	if x.length() < 0.5: x = up.cross(Vector3.FORWARD).normalized()
	var z := x.cross(up).normalized()
	node.global_transform = Transform3D(Basis(x,up,z),at+up*0.012*size)
	deepen(node,deep)
	_scoops.append(node)
	while _scoops.size() > SCOOPS_MOST:
		var old: Node3D = _scoops.pop_front()
		if is_instance_valid(old): old.queue_free()
	return node

func deepen(node: Node3D, deep: float) -> void:
	if node == null or not is_instance_valid(node): return
	node.scale = Vector3.ONE*size*lerpf(0.7,1.0,clampf(deep,0.0,1.0))
	node.set_meta("deep",deep)

## Every scoop gone (the re-deal fills them).
func clear_scoops() -> void:
	for s in _scoops:
		if is_instance_valid(s): s.queue_free()
	_scoops.clear()

func scoops() -> Array[Node3D]:
	return _scoops

## The scoop's mesh, its own frame (y up, x toward the spoil): a dark dish
## sunk a little (its middle under the rim), a rim of turned clods, and a
## low heap of spoil off to +x.
func _scoop_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 10
	var r_in := 0.13
	var rim := []
	for i in range(SIDES):
		var a := TAU*i/SIDES
		rim.append(Vector3(cos(a)*r_in*rng.randf_range(0.85,1.1),0.0,sin(a)*r_in*rng.randf_range(0.85,1.1)))
	# The dish: dark, its middle a touch down (seen from above it reads as
	# depth; it never sinks under the turf it lies on far enough to clip).
	st.set_color(EARTH_DARK)
	var mid := Vector3(0.0,-0.004,0.0)
	for i in range(SIDES):
		var a: Vector3 = rim[i]
		var b: Vector3 = rim[(i+1)%SIDES]
		_tri(st,mid,a,b,EARTH_DARK)
	# The rim: a ring of turned-earth lumps round it.
	for i in range(SIDES):
		var c: Vector3 = (rim[i] as Vector3)*1.12
		_lump(st,c,rng.randf_range(0.03,0.05),rng.randf_range(0.02,0.035),rng,EARTH_TURNED.lerp(EARTH,rng.randf()))
	# The spoil: a low heap to one side.
	var heap := Vector3(0.24,0.0,rng.randf_range(-0.04,0.04))
	_lump(st,heap,0.10,0.05,rng,EARTH)
	for i in range(4):
		_lump(st,heap+Vector3(rng.randf_range(-0.08,0.08),0.0,rng.randf_range(-0.08,0.08)),rng.randf_range(0.03,0.05),rng.randf_range(0.03,0.05),rng,EARTH_TURNED)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	st.set_material(m)
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

## A low lump: a squat six-sided cone, radius `r`, height `h`.
static func _lump(st: SurfaceTool, at: Vector3, r: float, h: float, rng: RandomNumberGenerator, col: Color) -> void:
	var top := at+Vector3(rng.randf_range(-0.2,0.2)*r,h,rng.randf_range(-0.2,0.2)*r)
	var ring := []
	for i in range(6):
		var a := TAU*i/6.0+rng.randf()*0.4
		ring.append(at+Vector3(cos(a),0.0,sin(a))*r*rng.randf_range(0.8,1.15)+Vector3.DOWN*0.01)
	for i in range(6):
		_tri(st,top,ring[i],ring[(i+1)%6],col)
