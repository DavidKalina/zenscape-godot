extends Node3D
## The inhaler head's stone (scripts/enemies/inhaler_head.gd): the Blender
## model (art/blender/inhaler_head/inhaler_head_build.py, assets/models/
## inhaler_head.glb) dressed in the ruin kit's stone, so it stands with the
## kit's pieces: the kit's stone material (scripts/ruin_kit.gd
## `materials().stone`) and each vertex coloured as the kit colours a face
## (scripts/ruin_stone_style.gd `shade`: the eroded basalt's tone by facing,
## its height bands, its undersides), darkened in the carving's crevices by
## the occlusion baked in the model's COLOR_0, and moss on what faces up.
## The stone is weathered in shaders/olmec_stone.gdshader (`stone_material`),
## the same for the headless body, so the two read as one figure: grain and
## pits, cracks, chipped pale high points, grime in the crevices, a hint of
## lichen. The mesh carries its rest position in UV and UV2 for that, and
## its occlusion in the colour's alpha.
## The eyes are polished stone that lights when it locks on; the maw and
## nostrils are near black.
##
## Built at `height` m from chin to crown, the chin's foot at the origin,
## the face toward -Z (the enemy's front). Posed by the enemy:
##   open(share)     the jaw dropped, 0 shut to 1 at JAW_OPEN rad
##   glow(share)     the eyes lit, 0 dark to 1 full
##   hinge()         the jaw's hinge (local): a head on the ground tips
##                   back about it as the jaw opens
##   mouth()         the lips' parting (global), the way in
##   face_way()      the way it faces (global, unit)

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const MODEL := "res://assets/models/inhaler_head.glb"
const STONE_SHADER := preload("res://shaders/olmec_stone.gdshader")
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
const Underground = preload("res://scripts/underground/underground.gd")
## --underground: the eyes' lit share at rest and their energy there.
const UNDER_REST := 0.7
const UNDER_ENERGY := 4.5
const MAW := Color(0.012,0.009,0.008)

var height := MODEL_HEIGHT
## The model built from, and its authored height (the rolling heads'
## coin sets its own: scripts/enemies/rolling_coin.gd).
var model_path := MODEL
var model_height := MODEL_HEIGHT
var model: Node3D
var jaw: Node3D
var eyes: MeshInstance3D
var maw: MeshInstance3D
var mouth_marker: Node3D
var _eye_mat := StandardMaterial3D.new()
var _maw_mat := StandardMaterial3D.new()
var _open := 0.0
static var _stone_material: ShaderMaterial = null
## The dressed parts made once per model, stone and part (a head coming
## back up a cliff dressed its meshes again: ~50 ms on the main thread).
static var _dressed_parts := {}

## The weathered stone both halves of the Olmec wear, lit as the kit's stone.
static func stone_material() -> ShaderMaterial:
	if _stone_material == null:
		_stone_material = ShaderMaterial.new()
		_stone_material.shader = STONE_SHADER
		_stone_material.set_shader_parameter("roughness_value",0.95)
	Style.dress(_stone_material)
	return _stone_material

## Builds the head `h` m tall from the stone of `seed_value`.
func build(h: float, seed_value := 7) -> void:
	height = h
	model = (load(model_path) as PackedScene).instantiate()
	model.scale = Vector3.ONE*(h/model_height)
	add_child(model)
	jaw = model.get_node("Jaw")
	eyes = model.get_node("Eyes")
	maw = model.get_node("Maw")
	mouth_marker = model.get_node("Mouth")
	var stone_mat: Material = stone_material()
	var stone := Style.stone_of(seed_value) if Style.ruled() else Color("5a5d63")
	for part: MeshInstance3D in [model.get_node("Head"),jaw]:
		var key := "%s|%s|%s|%s" % [model_path,stone.to_html(),part.name,part.position]
		if not _dressed_parts.has(key): _dressed_parts[key] = _dressed(part.mesh,stone,part.position)
		part.mesh = _dressed_parts[key]
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

## The dressed meshes' LODs: normals merged under this angle (the
## importer's own default), split over this.
const LOD_MERGE := 60.0
const LOD_SPLIT := 25.0

## The mesh's vertices coloured as the kit's stone: `shade` by each
## vertex's normal and place (`offset` the part's place in the model),
## times its baked occlusion, moss on what faces up.
static func _dressed(mesh: Mesh, stone: Color, offset: Vector3) -> ArrayMesh:
	# Built as an ImporterMesh so its LODs are made again (round 10, layer-
	# round10-far-bodies.md: an ArrayMesh made from the arrays had none, so
	# the head and body drew every triangle at any distance).
	var out := ImporterMesh.new()
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
		var rest_a := PackedVector2Array()
		var rest_b := PackedVector2Array()
		rest_a.resize(verts.size())
		rest_b.resize(verts.size())
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
			c.a = occ
			colours[i] = c
			rest_a[i] = Vector2(p.x,p.y)
			rest_b[i] = Vector2(p.z,0.0)
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = rest_a
		arrays[Mesh.ARRAY_TEX_UV2] = rest_b
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.generate_lods(LOD_MERGE,LOD_SPLIT,[])
	return out.get_mesh()

## The jaw dropped `share` of JAW_OPEN.
func open(share: float) -> void:
	_open = clampf(share,0.0,1.2)
	if jaw != null: jaw.rotation.x = -JAW_OPEN*_open

func opened() -> float:
	return _open

## The jaw's hinge in this node's space (the jaw turns about it).
func hinge() -> Vector3:
	return jaw.position*model.scale if jaw != null else Vector3.ZERO

## The eyes lit `share` (0 dark, 1 full); the maw's deep glow with them.
func glow(share: float) -> void:
	var s := clampf(share,0.0,1.0)
	_eye_mat.emission_energy_multiplier = EYE_ENERGY*s*s
	# --underground: the eyes burn in the dark even at rest, brighter when lit.
	if Underground.on():
		s = maxf(s,UNDER_REST)
		_eye_mat.emission_energy_multiplier = UNDER_ENERGY*(0.5+s*s)
	_eye_mat.albedo_color = EYE_STONE.lerp(EYE_LIT,s*0.5)
	_maw_mat.emission_energy_multiplier = 0.06*s*_open

## The lips' parting, in the world.
func mouth() -> Vector3:
	return mouth_marker.global_position

## The way the face looks, in the world (unit).
func face_way() -> Vector3:
	return -global_transform.basis.z.normalized()
