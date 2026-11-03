extends Node3D
## How the burrower leaves a sunk tunnel (docs/design/endless-flight/spec-burrower-chase.md):
## a plume out of the far mouth, big enough to read from inside the bore. He is never
## drawn: it's a column of dust up out of the sinkhole, dust rolling back down the tube
## at the plane, chips thrown, and a flash on the rock round the mouth.
##
## One mesh of quads the shader throws (burrower_bore_plume.gdshader), so `burst` is one
## write and a frame only sets `now`; one light. Nothing here touches the land's meshes.

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const PLUME_SHADER = preload("res://shaders/burrower_bore_plume.gdshader")

## The quads. The shader shares them out (`dust_share`, `back_share`, the rest chips).
const BITS := 320
## How long it lasts (s): the shader's longest life.
const LASTS_S := 9.0
## The flash: what it starts at, how fast it dies (s), its range, and how far back down
## the bore from the mouth and up off the floor it stands (m).
const FLASH := 60.0
const FLASH_DIE_S := 1.1
const FLASH_RANGE := 90.0
const FLASH_IN := 8.0
const FLASH_UP := 9.0
const FLASH_TINT := Color(1.0,0.6,0.32)

var _mat: ShaderMaterial
var _node: MeshInstance3D
var _light: OmniLight3D
var _now := 0.0
var _left := 0.0
## For drivers: the bursts so far, and where the last one came from.
var stats := {"bursts": 0, "at": Vector3.ZERO}

func _init() -> void:
	name = "BorePlume"

func setup() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = PLUME_SHADER
	_node = MeshInstance3D.new()
	_node.mesh = _bits()
	_node.material_override = _mat
	_node.layers = 1 | LandTunnels.UNDER_LAYER
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.visible = false
	add_child(_node)
	_light = OmniLight3D.new()
	_light.omni_range = FLASH_RANGE
	_light.light_color = FLASH_TINT
	_light.light_cull_mask = LandTunnels.UNDER_LAYER
	_light.shadow_enabled = false
	_light.light_specular = 0.2
	_light.visible = false
	add_child(_light)

## He's out of mouth `end` of `t`.
func burst(t: Tunnels.Site, end: int) -> void:
	var m: Dictionary = Tunnels.mouths(t)[end]
	var at: Vector2 = m.at
	var out: Vector2 = m.out
	var floor_y := Tunnels.floor_at(t,0.0 if end == 0 else t.length)
	var root := Vector3(at.x,floor_y,at.y)
	var way := Vector3(out.x,0.0,out.y)
	_node.position = root
	_mat.set_shader_parameter("out_way",way)
	_mat.set_shader_parameter("lit_at",_now)
	_mat.set_shader_parameter("now",_now)
	_node.visible = true
	_light.position = root-way*FLASH_IN+Vector3.UP*FLASH_UP
	_light.light_energy = FLASH
	_light.visible = true
	_left = LASTS_S
	stats.bursts = int(stats.bursts)+1
	stats.at = root

## One frame.
func step(delta: float) -> void:
	if _left <= 0.0: return
	_now += delta
	_left -= delta
	_mat.set_shader_parameter("now",_now)
	var since := LASTS_S-_left
	if _light.visible:
		var k := 1.0-since/FLASH_DIE_S
		_light.light_energy = FLASH*k*k
		_light.visible = k > 0.0
	if _left <= 0.0: _node.visible = false

## The quads: every draw in COLOR and NORMAL, nothing placed.
func _bits() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bore plume")
	for i in BITS:
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
	mesh.custom_aabb = AABB(Vector3(-260.0,-70.0,-260.0),Vector3(520.0,360.0,520.0))
	return mesh
