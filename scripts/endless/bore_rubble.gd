extends Node3D
## What's left of a spur (or a plug) the surge smashes in a bore (docs/design/endless-flight/
## spec-chase-smash.md): a burst of rock chunks and dust thrown off the plane's line, and a
## flash. Pooled: SLOTS bursts, each two meshes the shaders throw (burrower_bore_rubble.
## gdshader for the chunks, burrower_bore_rubble_dust.gdshader for the dust), so a `burst`
## is a few uniforms and a frame only sets `now`. Nothing here touches the bore.
##
## A burst's stone stands along a stick: `from` and `seg` (its root to its tip) and `girth`
## (its radius at the root, tapering to TAPER of it at the tip). A spur is its axis; a plug
## can be a short stick as wide as the bore.

const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const CHUNK_SHADER = preload("res://shaders/burrower_bore_rubble.gdshader")
const DUST_SHADER = preload("res://shaders/burrower_bore_rubble_dust.gdshader")

## Bursts at once, and each one's chunks and puffs.
const SLOTS := 3
const CHUNKS := 110
const PUFFS := 46
## How long a burst lasts (s): the shaders' longest life.
const LASTS_S := 3.6
## The flash: energy, how fast it dies (s), range (m), tint.
const FLASH := 20.0
const FLASH_DIE_S := 0.55
const FLASH_RANGE := 55.0
const FLASH_TINT := Color(1.0,0.62,0.34)

class Slot:
	var chunks: MeshInstance3D
	var dust: MeshInstance3D
	var left := 0.0

var _slots: Array[Slot] = []
var _turn := 0
var _now := 0.0
var _light: OmniLight3D
var _light_left := 0.0
## For drivers: bursts so far and where the last one stood.
var stats := {"bursts": 0, "at": Vector3.ZERO}

func _init() -> void:
	name = "BoreRubble"

func setup() -> void:
	var chunk_mesh := _chunk_mesh()
	var dust_mesh := _dust_mesh()
	for i in SLOTS:
		var s := Slot.new()
		s.chunks = _node(chunk_mesh,CHUNK_SHADER)
		s.dust = _node(dust_mesh,DUST_SHADER)
		_slots.append(s)
	_light = OmniLight3D.new()
	_light.omni_range = FLASH_RANGE
	_light.light_color = FLASH_TINT
	_light.light_cull_mask = LandTunnels.UNDER_LAYER
	_light.shadow_enabled = false
	_light.light_specular = 0.2
	_light.visible = false
	add_child(_light)

func _node(mesh: ArrayMesh, shader: Shader) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = shader
	m.material_override = mat
	m.layers = LandTunnels.UNDER_LAYER
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m

## Stone from `from` along `seg`, `girth` round, burst with the plane going `blast` (m/s).
func burst(from: Vector3, seg: Vector3, girth: float, blast: Vector3) -> void:
	if _slots.is_empty(): return
	var s := _slots[_turn]
	_turn = (_turn+1)%_slots.size()
	for node: MeshInstance3D in [s.chunks,s.dust]:
		node.position = from
		var mat := node.material_override as ShaderMaterial
		mat.set_shader_parameter("from",from)
		mat.set_shader_parameter("seg",seg)
		mat.set_shader_parameter("girth",girth)
		mat.set_shader_parameter("blast",blast)
		mat.set_shader_parameter("lit_at",_now)
		mat.set_shader_parameter("now",_now)
		node.visible = true
	s.left = LASTS_S
	_light.position = from+seg*0.4
	_light.light_energy = FLASH
	_light.visible = true
	_light_left = FLASH_DIE_S
	stats.bursts = int(stats.bursts)+1
	stats.at = from+seg*0.5

## One frame.
func step(delta: float) -> void:
	_now += delta
	for s: Slot in _slots:
		if s.left <= 0.0: continue
		s.left -= delta
		(s.chunks.material_override as ShaderMaterial).set_shader_parameter("now",_now)
		(s.dust.material_override as ShaderMaterial).set_shader_parameter("now",_now)
		if s.left <= 0.0:
			s.chunks.visible = false
			s.dust.visible = false
	if _light.visible:
		_light_left -= delta
		var k := maxf(_light_left/FLASH_DIE_S,0.0)
		_light.light_energy = FLASH*k*k
		_light.visible = k > 0.0

## The chunks: CHUNKS lumps (a squashed, jagged octahedron each, flat faces), each corner
## its offset off the lump's middle, its draws in COLOR, UV and UV2.
func _chunk_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var colors := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bore rubble")
	var faces := [[0,2,4],[2,1,4],[1,3,4],[3,0,4],[2,0,5],[1,2,5],[3,1,5],[0,3,5]]
	for i in CHUNKS:
		var c := Color(rng.randf(),rng.randf(),rng.randf(),rng.randf())
		var a := Vector2(rng.randf(),rng.randf())
		var b := Vector2(rng.randf(),rng.randf())
		var squash := Vector3(rng.randf_range(0.6,1.2),rng.randf_range(0.35,0.8),rng.randf_range(0.6,1.2))
		var tips: Array[Vector3] = []
		for d: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3.UP,Vector3.DOWN]:
			tips.append((d*rng.randf_range(0.7,1.25)+Vector3(rng.randf_range(-0.2,0.2),rng.randf_range(-0.2,0.2),rng.randf_range(-0.2,0.2)))*squash)
		for f: Array in faces:
			var p0: Vector3 = tips[f[0]]
			var p1: Vector3 = tips[f[1]]
			var p2: Vector3 = tips[f[2]]
			var n := (p1-p0).cross(p2-p0).normalized()
			for p: Vector3 in [p0,p1,p2]:
				verts.append(p)
				normals.append(n)
				colors.append(c)
				uv.append(a)
				uv2.append(b)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3(-150.0,-80.0,-150.0),Vector3(300.0,160.0,300.0))
	return mesh

## The dust: PUFFS quads, every draw in COLOR and NORMAL, UV its corner.
func _dust_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bore rubble dust")
	for i in PUFFS:
		var c := Color(rng.randf(),rng.randf(),rng.randf(),rng.randf())
		var n := Vector3(rng.randf(),rng.randf(),rng.randf())
		var at := verts.size()
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			verts.append(Vector3.ZERO)
			normals.append(n)
			uv.append(corner)
			colors.append(c)
		index.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3(-150.0,-80.0,-150.0),Vector3(300.0,160.0,300.0))
	return mesh
