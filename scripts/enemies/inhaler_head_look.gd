extends Node3D
## The inhaler head's stone (scripts/enemies/inhaler_head.gd): the Blender
## model (art/blender/inhaler_head/inhaler_head_build.py, assets/models/
## inhaler_head.glb) dressed in the ruin kit's stone, so it stands with the
## kit's pieces: the kit's stone material (scripts/ruin_kit.gd
## `materials().stone`) and each vertex coloured as the kit colours a face
## (scripts/ruin_stone_style.gd `shade`: the eroded basalt's tone by facing,
## its height bands, its undersides), darkened in the carving's crevices by
## the occlusion baked in the model's COLOR_0, and moss on what faces up.
## The eyes are polished stone that lights when it locks on; the maw and
## nostrils are near black.
##
## Built at `height` m from chin to crown, the chin's foot at the origin,
## the face toward -Z (the enemy's front). Posed by the enemy:
##   open(share)     the jaw dropped, 0 shut to 1 at JAW_OPEN rad
##   glow(share)     the eyes lit, 0 dark to 1 full
##   mouth()         the lips' parting (global), the way in
##   face_way()      the way it faces (global, unit)

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const MODEL := "res://assets/models/inhaler_head.glb"
## The model's height (m) as authored: chin to crown, the band's boss
## and the dome's swell left out.
const MODEL_HEIGHT := 3.2
## The jaw's widest drop (rad about its hinge).
const JAW_OPEN := 0.42
## The crevices: the share of the stone's tone kept where the occlusion is
## darkest, and how the occlusion is eased (under 1 darkens more of it).
const AO_FLOOR := 0.42
const AO_EASE := 0.7
## Moss on the tops: past this upward share of the normal, up to this much
## of the moss's tone, over the helmet's crown and the ledges.
const MOSS := Color("374726")
const MOSS_LIGHT := Color("4e612e")
const MOSS_UP := 0.62
const MOSS_MOST := 0.7
## The eyes: their stone at rest and the light they take.
const EYE_STONE := Color(0.62,0.58,0.48)
const EYE_LIT := Color(1.0,0.72,0.32)
const EYE_ENERGY := 3.2
const MAW := Color(0.012,0.009,0.008)

var height := MODEL_HEIGHT
var model: Node3D
var jaw: Node3D
var eyes: MeshInstance3D
var maw: MeshInstance3D
var mouth_marker: Node3D
var _eye_mat := StandardMaterial3D.new()
var _maw_mat := StandardMaterial3D.new()
var _open := 0.0

## Builds the head `h` m tall from the stone of `seed_value`.
func build(h: float, seed_value := 7) -> void:
	height = h
	model = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE*(h/MODEL_HEIGHT)
	add_child(model)
	jaw = model.get_node("Jaw")
	eyes = model.get_node("Eyes")
	maw = model.get_node("Maw")
	mouth_marker = model.get_node("Mouth")
	var stone_mat: Material = RuinKit.materials().stone
	var stone := Style.stone_of(seed_value) if Style.ruled() else Color("5a5d63")
	for part: MeshInstance3D in [model.get_node("Head"),jaw]:
		part.mesh = _dressed(part.mesh,stone,part.position)
		part.material_override = stone_mat
	_eye_mat.albedo_color = EYE_STONE
	_eye_mat.roughness = 0.35
	_eye_mat.emission_enabled = true
	_eye_mat.emission = EYE_LIT
	_eye_mat.emission_energy_multiplier = 0.0
	eyes.material_override = _eye_mat
	_maw_mat.albedo_color = MAW
	_maw_mat.roughness = 1.0
	_maw_mat.emission_enabled = true
	_maw_mat.emission = Color(0.35,0.12,0.05)
	_maw_mat.emission_energy_multiplier = 0.0
	maw.material_override = _maw_mat
	for m: MeshInstance3D in [eyes,maw]: m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The mesh's vertices coloured as the kit's stone: `shade` by each
## vertex's normal and place (`offset` the part's place in the model),
## times its baked occlusion, moss on what faces up.
static func _dressed(mesh: Mesh, stone: Color, offset: Vector3) -> ArrayMesh:
	var out := ArrayMesh.new()
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 1.6
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ao: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var colours := PackedColorArray()
		colours.resize(verts.size())
		var moss := MOSS.srgb_to_linear()
		var moss_light := MOSS_LIGHT.srgb_to_linear()
		for i in range(verts.size()):
			var p := verts[i]+offset
			var n := normals[i]
			# The foot's dark is the kit's ground; a head hangs in the air, so
			# its chin is lifted clear of it.
			var c := Style.shade(stone,p,p+Vector3.UP*4.0,n,1.0)
			var occ := 1.0
			if ao.size() == verts.size(): occ = pow(clampf(ao[i].r,0.0,1.0),AO_EASE)
			c = c*lerpf(AO_FLOOR,1.0,occ)
			var up := smoothstep(MOSS_UP,0.95,n.y)
			if up > 0.0:
				var patch := clampf(noise.get_noise_3dv(p)*0.9+0.45,0.0,1.0)
				var tone := moss.lerp(moss_light,clampf(noise.get_noise_3dv(p*3.0)+0.5,0.0,1.0))
				c = c.lerp(tone,up*patch*MOSS_MOST*occ)
			c.a = 1.0
			colours[i] = c
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

## The jaw dropped `share` of JAW_OPEN.
func open(share: float) -> void:
	_open = clampf(share,0.0,1.2)
	if jaw != null: jaw.rotation.x = -JAW_OPEN*_open

func opened() -> float:
	return _open

## The eyes lit `share` (0 dark, 1 full); the maw's deep glow with them.
func glow(share: float) -> void:
	var s := clampf(share,0.0,1.0)
	_eye_mat.emission_energy_multiplier = EYE_ENERGY*s*s
	_eye_mat.albedo_color = EYE_STONE.lerp(EYE_LIT,s*0.5)
	_maw_mat.emission_energy_multiplier = 0.06*s*_open

## The lips' parting, in the world.
func mouth() -> Vector3:
	return mouth_marker.global_position

## The way the face looks, in the world (unit).
func face_way() -> Vector3:
	return -global_transform.basis.z.normalized()
