extends Node3D
## The rune knight's stone (docs/design/rune-knight/spec-rune-knight-body.md):
## the Blender model (art/blender/rune_knight/rune_knight_build.py,
## assets/models/rune_knight.glb) dressed in the Olmec's weathered stone
## (shaders/olmec_stone.gdshader, as scripts/enemies/inhaler_head_look.gd
## dresses the head): each vertex coloured as the kit colours a face
## (scripts/ruin_stone_style.gd `shade`), darkened by the occlusion baked in
## COLOR_0 (kept in the colour's alpha for the shader's grime), moss on what
## faces up, and the rest position in UV/UV2 so the grain rides on him as
## his pieces move.
##
## The runes (chest, hand_l, hand_r) are the faces of the three tablets
## (`<bone>-rune`), cut in as the rune serpent's lit grooves
## (shaders/rune_serpent_runes.gdshaderinc, a band of glyphs: CUSTOM0 what
## 2, the glyph cell's length over its height; CUSTOM1 the tablet's square
## and its glyph count, from the model's UV). Each rune has its own
## material, so it lights (`rune_energy`) and goes dark on its own.
##
## The visor's eye (the back wall of the T slit's bar, material `eye`) glows
## his runes' light: dim at rest, lit while he watches or tracks you
## (`eye_glow`, which the trunk wires to the mind's notice and tracking).
##
## He is a small, deeply creviced figure, so against a bright sky the
## Olmec's stone reads murky on him: his own material lifts the hemisphere
## fill and the sky rim and eases the crevice grime (the shader's knobs on
## his material only; its defaults, the Olmec's, are unchanged), and his
## tone is lifted a little (STONE_LIFT).
##
## Built `height` m to the helm's crown, his feet at the origin, facing -Z.
## Pieces: `pieces` (name -> MeshInstance3D, `<bone>-<piece>`), sockets
## `socket-<name>` (Node3D, each riding its bone). Rigged (task 3): every
## piece is skinned rigidly to one bone of the glb's Skeleton3D, so its
## vertices are in the model's space at rest; the clips are the glb's
## animations (`play`).
##   play(clip, blend)        a glb clip by name (rune_knight_clips.py clips())
##   rune_energy(key, share)  a rune's light, 0 dark, 1 at rest
##   eye_glow(share)          the eye, 0 dark, EYE_REST at rest, 1 full

const Style = preload("res://scripts/ruin_stone_style.gd")
const MODEL := "res://assets/models/rune_knight.glb"
const STONE_SHADER := preload("res://shaders/olmec_stone.gdshader")
## The model's height (m) as authored: the wanderer's 1.19 x 1.6.
const MODEL_HEIGHT := 1.904
## The grain's scale on the rest position: the Olmec's stone, a little finer
## for a figure this size.
const GRAIN := 1.25
const AO_FLOOR := 0.72
const AO_EASE := 0.45
## His stone's tone lifted over the kit's, and his material's knobs (the
## shader's defaults: fill 1.2, rim 0.14, grime_mul 0.34).
const STONE_LIFT := 1.55
const FILL := 2.0
const RIM := 0.4
const GRIME := Vector3(0.52,0.5,0.48)
const MOSS := Color("374726")
const MOSS_LIGHT := Color("4e612e")
const MOSS_UP := 0.6
const MOSS_MOST := 0.7
## The runes' light (the stand-in's RUNE) and its energy at rest and lit.
const RUNE := Color(0.45,0.85,1.0)
const RUNE_REST := 1.2
const RUNE_LIT := 4.0
## Glyphs per tablet (rune_knight_build.py RUNE_GLYPHS), and a glyph cell's
## length over its height on each (the tablets' fronts, a row across).
const GLYPHS := {"chest": 3, "hand_l": 2, "hand_r": 2}
const CELL := {"chest": 0.76, "hand_l": 0.83, "hand_r": 0.83}
## The eye: its light (the runes'), its energy at full, its share at rest.
const EYE := Color(0.55,0.9,1.0)
const EYE_ENERGY := 4.0
const EYE_REST := 0.15
const SLIT := Color(0.02,0.018,0.016)

## The clips that loop.
const LOOPS := ["idle","walk","turn","fall"]

var height := MODEL_HEIGHT
var model: Node3D
var player: AnimationPlayer
var pieces := {}
var runes := {}
var _stone: ShaderMaterial
var _eye := StandardMaterial3D.new()

func build(h: float, seed_value := 7) -> void:
	height = h
	model = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE*(h/MODEL_HEIGHT)
	add_child(model)
	_stone = ShaderMaterial.new()
	_stone.shader = STONE_SHADER
	_stone.set_shader_parameter("roughness_value",0.95)
	Style.dress(_stone)
	_stone.set_shader_parameter("fill",FILL)
	_stone.set_shader_parameter("rim",RIM)
	_stone.set_shader_parameter("grime_mul",GRIME)
	var stone := Style.stone_of(seed_value) if Style.ruled() else Color("5a5d63")
	stone = Color(stone.r*STONE_LIFT,stone.g*STONE_LIFT,stone.b*STONE_LIFT)
	_eye.albedo_color = SLIT
	_eye.roughness = 1.0
	_eye.emission_enabled = true
	_eye.emission = EYE
	var slit := StandardMaterial3D.new()
	slit.albedo_color = SLIT
	slit.roughness = 1.0
	player = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player != null:
		for a in LOOPS:
			if player.has_animation(a): player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		pieces[String(mi.name)] = mi
		var key := ""
		if String(mi.name).ends_with("-rune"):
			key = String(mi.name).get_slice("-",0)
		mi.mesh = _dressed(mi.mesh,stone,_rest_of(mi),key)
		for s in range(mi.mesh.get_surface_count()):
			var m := mi.mesh.surface_get_material(s)
			var mname := m.resource_name if m != null else ""
			if mname == "slit":
				mi.set_surface_override_material(s,slit)
			elif mname == "eye":
				mi.set_surface_override_material(s,_eye)
			elif mname == "rune":
				var rm := _rune_material()
				runes[key] = rm
				mi.set_surface_override_material(s,rm)
			else:
				mi.set_surface_override_material(s,_stone)
	eye_glow(EYE_REST)

## The eye lit `share`: 0 dark, EYE_REST at rest, 1 watching you.
func eye_glow(share: float) -> void:
	var s := clampf(share,0.0,1.0)
	_eye.emission_energy_multiplier = EYE_ENERGY*s

func _rune_material() -> ShaderMaterial:
	var m := _stone.duplicate() as ShaderMaterial
	m.set_shader_parameter("runes",true)
	m.set_shader_parameter("glow",RUNE)
	m.set_shader_parameter("energy",RUNE_REST)
	m.set_shader_parameter("pulse_amp",0.25)
	return m

## A rune's light: 0 dark, 1 at rest, up to RUNE_LIT/RUNE_REST lit.
func rune_energy(key: String, share: float) -> void:
	if runes.has(key): (runes[key] as ShaderMaterial).set_shader_parameter("energy",RUNE_REST*share)

## A socket (riding its bone): hand_r, hand_l, hands_mid, blade, chest_rune, eye.
func socket(name_: String) -> Node3D:
	return model.find_child("socket-"+name_,true,false) as Node3D

## Play a clip of the glb by name (rune_knight_clips.py clips(); a form is "clip-form").
func play(clip: String, blend := 0.15) -> void:
	if player != null and player.has_animation(clip): player.play(clip,blend)

## Where a piece's mesh sits in the model at rest (its vertices are in the
## skeleton's space when skinned, so this is the skeleton's place).
func _rest_of(mi: MeshInstance3D) -> Vector3:
	var t := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != model:
		if n is Node3D: t = (n as Node3D).transform*t
		n = n.get_parent()
	return t.origin

## The piece's mesh coloured as the kit's stone, its rest in UV/UV2, its
## occlusion in alpha, and (a rune tablet, `key`) its glyph square in CUSTOM.
func _dressed(mesh: Mesh, stone: Color, offset: Vector3, key: String) -> ArrayMesh:
	var out := ImporterMesh.new()
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 3.0
	var moss := MOSS.srgb_to_linear()
	var moss_light := MOSS_LIGHT.srgb_to_linear()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var mat := mesh.surface_get_material(s)
		var is_rune := mat != null and mat.resource_name == "rune"
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ao: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var n_v := verts.size()
		var colours := PackedColorArray()
		var rest_a := PackedVector2Array()
		var rest_b := PackedVector2Array()
		colours.resize(n_v)
		rest_a.resize(n_v)
		rest_b.resize(n_v)
		var c0 := PackedFloat32Array()
		var c1 := PackedFloat32Array()
		if is_rune:
			c0.resize(n_v*4)
			c1.resize(n_v*4)
		for i in range(n_v):
			var p := verts[i]+offset
			var n := normals[i]
			var c := Style.shade(stone,p,p+Vector3.UP*4.0,n,1.0)
			var occ := 1.0
			if ao.size() == n_v: occ = pow(clampf(ao[i].r,0.0,1.0),AO_EASE)
			c = c*lerpf(AO_FLOOR,1.0,occ)
			var up := smoothstep(MOSS_UP,0.95,n.y)
			if up > 0.0:
				var patch := clampf(noise.get_noise_3dv(p)*0.9+0.4,0.0,1.0)
				var tone := moss.lerp(moss_light,clampf(noise.get_noise_3dv(p*3.0)+0.5,0.0,1.0))
				c = c.lerp(tone,up*patch*MOSS_MOST*occ)
			c.a = occ
			colours[i] = c
			var r := p*GRAIN
			rest_a[i] = Vector2(r.x,r.y)
			rest_b[i] = Vector2(r.z,0.0)
			if is_rune and uv.size() == n_v:
				var g: int = GLYPHS.get(key,2)
				# glTF flips v: the build's (along, across) is (u, 1 - v).
				c0[i*4] = 2.0
				c0[i*4+1] = CELL.get(key,0.83)
				c0[i*4+2] = 0.0
				c0[i*4+3] = float(hash(key)%97)
				c1[i*4] = uv[i].x
				c1[i*4+1] = 1.0-uv[i].y
				c1[i*4+2] = float(g)
				c1[i*4+3] = 0.0
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = rest_a
		arrays[Mesh.ARRAY_TEX_UV2] = rest_b
		var flags := 0
		if is_rune:
			arrays[Mesh.ARRAY_CUSTOM0] = c0
			arrays[Mesh.ARRAY_CUSTOM1] = c1
			flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},mat,"",flags)
	out.generate_lods(60.0,25.0,[])
	return out.get_mesh()
