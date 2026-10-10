extends Node3D
## The lodestone: the key the player finds somewhere hard to reach, that
## points the plane to a hidden set piece (docs/design/lodestone-study.md).
## A world in miniature: a faceted chip of sky island, its keel of dark
## stone veined with a glowing lode, and on its top, at a few thousandths of
## its size, the real place it leads to (scripts/lodestone_miniatures.gd:
## the Sundered hall, an aqueduct), pale with distance and standing in its
## own wisps of cloud. Round it all a soft slow wind swirl turns, as the
## water ball's vortex turns its water and fish (scripts/water_ball.gd,
## shaders/water_ball.gdshader): strokes of the current painted with the
## breeze ribbons' brush (shaders/lodestone_ribbon.gdshader), motes of warm
## light, petals and glints riding it (shaders/lodestone_motes.gdshader),
## and a warm-white glow behind (shaders/lodestone_glow.gdshader).
##
## It hums (`hum_goal`, 0 to 1: the pilot coming near): the glow and the
## lode brighten, the swirl quickens and draws in, a small warm light
## wakes on what it rests on. It points (`stream_goal` 0 to 1 toward
## `stream_dir`, in its own frame): the swirl lets go of the stone and
## streams off it that way, a comet's tail drawn out toward the place.
## The miniature turns slowly on its own (`idle_turn`) or as the player
## turns it (`turn_by`).
##
## Its origin is the swirl's middle; the stone's top stands TOP_Y under it.

const Minis = preload("res://scripts/lodestone_miniatures.gd")
const STONE_SHADER := preload("res://shaders/lodestone_stone.gdshader")
const MINI_SHADER := preload("res://shaders/lodestone_mini.gdshader")
const RIBBON_SHADER := preload("res://shaders/lodestone_ribbon.gdshader")
const MOTES_SHADER := preload("res://shaders/lodestone_motes.gdshader")
const GLOW_SHADER := preload("res://shaders/lodestone_glow.gdshader")
const THREAD_SHADER := preload("res://shaders/lodestone_thread.gdshader")

## The miniature's half extent across (m) and the stone's keel depth (m),
## whatever the place: the stone in the hand is always about this size.
const REACH := 0.16
const KEEL := 0.12
## The stone's top under the swirl's middle (m).
const TOP_Y := -0.04
## The swirl: strokes (each of RIBBON_SEGMENTS along), motes, petals,
## glints and wisps of cloud riding it.
const RIBBONS := 14
const RIBBON_SEGMENTS := 28
const MOTES := 36
const PETALS := 9
const GLINTS := 8
const WISPS := 12
## The idle turn (rad/s) of the miniature, the swirl's pace (rad/s) at
## rest, humming and streaming.
const IDLE_TURN := 0.12
const SPIN := Vector3(0.45,0.95,1.6)
## The light it casts on what it rests on, at rest and humming (energy),
## and its reach (m).
const LIGHT := Vector2(0.05,0.45)
const LIGHT_RANGE := 1.6
## The render layer the lodestone's own meshes draw on, which its light
## leaves out (it lights what the stone rests on, never the stone, which it
## would burn white from a few centimetres).
const OWN_LAYER := 1 << 11

var hum := 0.0
var hum_goal := 0.0
var stream := 0.0
var stream_goal := 0.0
## The way it streams, in its own frame (unit).
var stream_dir := Vector3.FORWARD
var idle_turn := true
var kind := ""
## What it costs: {triangles (miniature, stone), draws (meshes drawn), scale}.
var info := {}

var _turn: Node3D
var _mini_root: Node3D
var _swirl := 0.0
var _clock := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _stone_material: ShaderMaterial
var _mini_material: ShaderMaterial
var _water_material: ShaderMaterial
var _ribbon_material: ShaderMaterial
var _motes_material: ShaderMaterial
var _glow_material: ShaderMaterial
var _thread_materials: Array[ShaderMaterial] = []
var _ribbons: MultiMeshInstance3D
var _motes: MultiMeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D

func _init() -> void:
	name = "Lodestone"
	_stone_material = ShaderMaterial.new()
	_stone_material.shader = STONE_SHADER
	_mini_material = ShaderMaterial.new()
	_mini_material.shader = MINI_SHADER
	_water_material = ShaderMaterial.new()
	_water_material.shader = MINI_SHADER
	_water_material.set_shader_parameter("water",1.0)
	_ribbon_material = ShaderMaterial.new()
	_ribbon_material.shader = RIBBON_SHADER
	_motes_material = ShaderMaterial.new()
	_motes_material.shader = MOTES_SHADER
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GLOW_SHADER
	_turn = Node3D.new()
	_turn.name = "Turn"
	add_child(_turn)
	_ribbons = _swirl_layer("Ribbons",_strip(RIBBON_SEGMENTS),_ribbon_material,RIBBONS)
	_motes = _swirl_layer("Motes",_quad(),_motes_material,MOTES+PETALS+GLINTS+WISPS)
	_seed_swirl()
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	_glow.mesh = _quad()
	_glow.material_override = _glow_material
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.custom_aabb = AABB(Vector3.ONE*-0.6,Vector3.ONE*1.2)
	add_child(_glow)
	_light = OmniLight3D.new()
	_light.name = "Hum"
	_light.light_color = Color(1.0,0.86,0.64)
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_light.position = Vector3(0.0,TOP_Y-KEEL-0.06,0.0)
	_light.light_cull_mask = 0xFFFFF & ~OWN_LAYER
	add_child(_light)

func _ready() -> void:
	if kind.is_empty(): set_miniature(Minis.KINDS[0])

## Stands `which` (Minis KINDS) on the stone, the stone shaped to it.
func set_miniature(which: String) -> void:
	if _mini_root != null: _mini_root.free()
	kind = which
	var made: Dictionary = Minis.build(which)
	var place: Node3D = made.node
	var reach: float = made.reach
	var s := REACH/maxf(reach,0.001)
	_mini_root = Node3D.new()
	_mini_root.name = "Miniature"
	_mini_root.scale = Vector3.ONE*s
	var centre: Vector2 = made.centre
	_mini_root.position = Vector3(-centre.x*s,TOP_Y,-centre.y*s)
	_turn.add_child(_mini_root)
	_mini_root.add_child(place)
	var draws := 0
	for node: MeshInstance3D in place.find_children("*","MeshInstance3D",true,false):
		var wet := String(node.name) in ["Water","Cistern","Pool"]
		node.material_override = _water_material if wet else _mini_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draws += 1
	var haze: Dictionary = made.haze
	_mini_material.set_shader_parameter("haze_heights",haze.heights)
	var fringe: Vector2 = haze.fringe
	_mini_material.set_shader_parameter("fringe",Vector4(centre.x,centre.y,fringe.x,fringe.y))
	_water_material.set_shader_parameter("haze_heights",haze.heights)
	_water_material.set_shader_parameter("fringe",Vector4(centre.x,centre.y,fringe.x,fringe.y))
	# The stone: its top the place's ground, its keel KEEL deep whatever
	# the place's size; and the shards the place's other pieces stand on.
	var depth := KEEL/s
	var stone := MeshInstance3D.new()
	stone.name = "Stone"
	stone.mesh = keel_mesh(made.top,depth,hash([which,"stone"]),true)
	stone.material_override = _stone_material
	_mini_root.add_child(stone)
	var stone_tris := stone.mesh.get_faces().size()/3
	draws += 1
	for shard: Dictionary in made.shards:
		var piece := MeshInstance3D.new()
		piece.name = "Shard"
		piece.mesh = keel_mesh(shard.outline,minf(float(shard.depth),depth*0.45),int(shard.seed),false)
		piece.material_override = _stone_material
		piece.transform = shard.transform
		_mini_root.add_child(piece)
		stone_tris += piece.mesh.get_faces().size()/3
		draws += 1
	_thread_materials.clear()
	for thread: Dictionary in made.threads:
		var material := ShaderMaterial.new()
		material.shader = THREAD_SHADER
		material.set_shader_parameter("fall",float(thread.fall))
		material.set_shader_parameter("width",1.3)
		_thread_materials.append(material)
		var fall := MeshInstance3D.new()
		fall.name = "Thread"
		fall.mesh = _fall_strip(12)
		fall.material_override = material
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fall.position = thread.at
		fall.custom_aabb = AABB(Vector3(-2.0,-float(thread.fall)-1.0,-2.0),Vector3(4.0,float(thread.fall)+2.0,4.0))
		_mini_root.add_child(fall)
		draws += 1
	# The swirl round the place: a little wider than it, as tall as it
	# stands and its keel hangs.
	var tall := float(made.height)*s
	var radius := REACH*1.3+0.02
	for material: ShaderMaterial in [_ribbon_material,_motes_material,_glow_material]:
		material.set_shader_parameter("swirl_radius",radius)
		material.set_shader_parameter("swirl_height",maxf(tall*0.75,0.06)+0.04)
	_glow_material.set_shader_parameter("size",radius*1.25)
	for node: VisualInstance3D in find_children("*","VisualInstance3D",true,false):
		if not node is Light3D: node.layers = OWN_LAYER
	info = {"name":made.name,"triangles":int(made.triangles),"stone_triangles":stone_tris,"scale":s,
		"draws":draws+3,"swirl":"%d strokes, %d motes" % [RIBBONS,MOTES+PETALS+GLINTS+WISPS]}

## The player turns the miniature: `by` (radians: yaw, pitch).
func turn_by(by: Vector2) -> void:
	_yaw += by.x
	_pitch = clampf(_pitch+by.y,-0.9,0.9)

func reset_turn() -> void:
	_pitch = 0.0

func _process(delta: float) -> void:
	advance(minf(delta,0.05))

func advance(delta: float) -> void:
	_clock += delta
	hum = move_toward(hum,hum_goal,delta*1.2)
	stream = move_toward(stream,stream_goal,delta*0.8)
	# The hum breathes.
	var breath := hum*(0.88+0.12*sin(_clock*2.1))
	var pace := lerpf(SPIN.x,SPIN.y,hum)
	pace = lerpf(pace,SPIN.z,stream)
	_swirl += pace*delta
	if idle_turn: _yaw += IDLE_TURN*delta*(1.0-stream*0.7)
	_turn.basis = Basis(Vector3.UP,_yaw)*Basis(Vector3.RIGHT,_pitch)
	var dir := stream_dir.normalized() if stream_dir.length() > 0.01 else Vector3.FORWARD
	for material: ShaderMaterial in [_ribbon_material,_motes_material,_glow_material]:
		material.set_shader_parameter("swirl",_swirl)
		material.set_shader_parameter("spin",pace)
		material.set_shader_parameter("clock",_clock)
		material.set_shader_parameter("hum",breath)
		material.set_shader_parameter("stream",stream)
		material.set_shader_parameter("stream_dir",dir)
	for material: ShaderMaterial in [_stone_material,_mini_material,_water_material]:
		material.set_shader_parameter("hum",breath)
		material.set_shader_parameter("clock",_clock)
	for material in _thread_materials:
		material.set_shader_parameter("clock",_clock)
		material.set_shader_parameter("hum",breath)
	_light.light_energy = lerpf(LIGHT.x,LIGHT.y,breath)*(1.0-stream*0.5)
	_light.omni_range = LIGHT_RANGE*global_basis.get_scale().x

## The light on what it rests on (off in the plane's cradle).
func show_light(on: bool) -> void:
	_light.visible = on

# --- Building -------------------------------------------------------------------

## A swirl layer: `count` copies of `mesh` placed by the shader (their
## transforms identity), each with its draws in the custom data.
func _swirl_layer(label: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves them: bounds wide enough for the stream.
	node.custom_aabb = AABB(Vector3.ONE*-2.0,Vector3.ONE*4.0)
	add_child(node)
	return node

## Each stroke's and each rider's draws: seed, orbit, level, and the
## stroke's tail (s, /4) or the rider's kind.
func _seed_swirl() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(RIBBONS):
		_ribbons.multimesh.set_instance_transform(i,Transform3D.IDENTITY)
		_ribbons.multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf_range(0.55,1.0),rng.randf(),rng.randf_range(1.1,2.2)/4.0))
	var kinds: Array[float] = []
	for i in range(MOTES): kinds.append(0.0)
	for i in range(PETALS): kinds.append(0.33)
	for i in range(GLINTS): kinds.append(0.66)
	for i in range(WISPS): kinds.append(1.0)
	for i in range(kinds.size()):
		_motes.multimesh.set_instance_transform(i,Transform3D.IDENTITY)
		var orbit := rng.randf_range(0.3,1.0) if kinds[i] < 0.5 else rng.randf()
		_motes.multimesh.set_instance_custom_data(i,Color(rng.randf(),orbit,rng.randf(),kinds[i]))

## A strip `segments` long: UV.x 0 tail..1 head along, UV.y 0..1 across.
static func _strip(segments: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segments+1):
		for j in range(2):
			v.append(Vector3.ZERO)
			uv.append(Vector2(float(i)/segments,float(j)))
	for i in range(segments):
		var a := i*2
		idx.append_array([a,a+1,a+2,a+1,a+3,a+2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3.ONE*-2.0,Vector3.ONE*4.0)
	return mesh

## A falling strip: UV.x across, UV.y 0 at the lip..1 at the foot.
static func _fall_strip(segments: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segments+1):
		for j in range(2):
			v.append(Vector3.ZERO)
			uv.append(Vector2(float(j),float(i)/segments))
	for i in range(segments):
		var a := i*2
		idx.append_array([a,a+1,a+2,a+1,a+3,a+2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,1,3,2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3.ONE*-2.0,Vector3.ONE*4.0)
	return mesh

## The stone: a faceted chip of sky island under `outline` (x z, its top
## at y 0), its keel hanging `depth` under it to a point, as the sky
## islands' keels hang (scripts/rock_looks.gd). A moss top, a band of earth
## at the rim, dark warm stone below; with `veins` a lode winds round the
## keel in two bands of facets that glow (vertex alpha 0, the stone
## shader's lode). Every face its own flat facet.
static func keel_mesh(outline: PackedVector2Array, depth: float, seed_value: int, veins: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Twice the outline's corners, so the keel's facets run narrow.
	var fine := PackedVector2Array()
	for k in range(outline.size()):
		var a := outline[k]
		var b := outline[(k+1)%outline.size()]
		fine.append(a)
		fine.append((a+b)*0.5*rng.randf_range(0.97,1.03))
	outline = fine
	var n := outline.size()
	var middle := Vector2.ZERO
	for p in outline: middle += p
	middle /= n
	# Rings from the top's edge down: (shrink toward the middle, height as a
	# share of the depth).
	var shape := [Vector2(0.55,0.012),Vector2(1.0,0.0),Vector2(1.03,-0.07),Vector2(0.86,-0.24),Vector2(0.62,-0.5),Vector2(0.32,-0.78)]
	var rings: Array = []
	var twist := 0.0
	for r in range(shape.size()):
		var ring := PackedVector3Array()
		var share: Vector2 = shape[r]
		for k in range(n):
			var p := outline[k]
			var jitter := 1.0 if r == 1 else rng.randf_range(0.9,1.08)
			var q := middle+(p-middle).rotated(twist)*share.x*jitter
			var y := share.y*depth+(rng.randf_range(-0.035,0.035)*depth if r > 2 else rng.randf_range(-0.004,0.004)*depth)
			ring.append(Vector3(q.x,y,q.y))
		rings.append(ring)
		if r > 2: twist += rng.randf_range(-0.12,0.12)
	var top := Vector3(middle.x,0.018*depth,middle.y)
	var tip := Vector3(middle.x+rng.randf_range(-0.08,0.08)*depth,-depth,middle.y+rng.randf_range(-0.08,0.08)*depth)
	var centre := Vector3(middle.x,-0.35*depth,middle.y)
	# Plain arrays: a lambda's captured packed arrays would be its own copies.
	var v: Array = []
	var nm: Array = []
	var c: Array = []
	var uv: Array = []
	var vein_turn := rng.randf()
	var face := func(a: Vector3, b: Vector3, d: Vector3, colour: Color) -> void:
		var normal := (b-a).cross(d-a)
		if normal.length_squared() < 1e-12: return
		normal = normal.normalized()
		var mid := (a+b+d)/3.0
		var out := mid-centre
		if mid.y > -0.02*depth: out = Vector3.UP
		if normal.dot(out) < 0.0:
			normal = -normal
			var swap := b
			b = d
			d = swap
		# Godot's front faces wind clockwise seen from outside.
		v.append_array([a,d,b])
		for i in range(3):
			nm.append(normal)
			c.append(colour)
		var s := rng.randf()
		uv.append_array([Vector2(s,0.0),Vector2(s,0.0),Vector2(s,0.0)])
	var moss := [Color(0.25,0.33,0.19),Color(0.28,0.35,0.2),Color(0.23,0.3,0.18),Color(0.3,0.34,0.21)]
	# The top: a fan to the middle over the inner ring, then out to the edge.
	var inner: PackedVector3Array = rings[0]
	var edge: PackedVector3Array = rings[1]
	for k in range(n):
		var k1 := (k+1)%n
		face.call(top,inner[k],inner[k1],moss[rng.randi()%moss.size()])
		face.call(inner[k],edge[k],edge[k1],moss[rng.randi()%moss.size()])
		face.call(inner[k],edge[k1],inner[k1],moss[rng.randi()%moss.size()])
	# Down the keel.
	for r in range(1,rings.size()-1):
		var up: PackedVector3Array = rings[r]
		var down: PackedVector3Array = rings[r+1]
		for k in range(n):
			var k1 := (k+1)%n
			for tri in [[up[k],down[k],down[k1]],[up[k],down[k1],up[k1]]]:
				var colour := _keel_colour(rng,r,float(k)/n,vein_turn,veins)
				face.call(tri[0],tri[1],tri[2],colour)
	var last: PackedVector3Array = rings[rings.size()-1]
	for k in range(n):
		face.call(last[k],tip,last[(k+1)%n],_keel_colour(rng,rings.size(),float(k)/n,vein_turn,veins))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(v)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(nm)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(c)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uv)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## A keel facet's colour: the earth band at the rim, dark warm stone
## below, and, on the lode's two bands winding round, pale stone that
## glows (alpha 0).
static func _keel_colour(rng: RandomNumberGenerator, ring: int, around: float, vein_turn: float, veins: bool) -> Color:
	if ring == 1: return Color(0.4,0.31,0.24)*rng.randf_range(0.9,1.08)
	var stone := Color(0.21,0.19,0.18).lerp(Color(0.28,0.25,0.23),rng.randf())
	if veins:
		var band := fposmod(around*2.0+ring*0.13+vein_turn,1.0)
		if band < 0.06 or rng.randf() < 0.03:
			var lode := Color(0.3,0.25,0.19)
			lode.a = 0.0
			return lode
	return stone
