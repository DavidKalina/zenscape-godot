extends RefCounted
## The underground's ground: living, shaded, wind-moved cover for the stone and
## the turf of the abandoned Olmec city (docs/design/roguelike/
## underground-ground-round1.md). The meadow's grass is the look the user
## loves; under the haze its orange autumn gold is wrong, and the city's walk
## tops are bare stone. Three covers, flipped live with `--ground=` (and G in
## the generator):
##
##   grass  the game's own turf and tufts, re-graded: dusty umber-sage, no
##          seasonal gold, the same tufts, drifts, wave and sheen
##   dust   drifted dust, pale ash and fine sand: the terrain's ground turned
##          sand with ripples that creep across the wind, a sheen on the
##          gusts, grit; sparse dry tufts and pale shoots through it; fine
##          grit stirring in the air (`motes`)
##   moss   cool dark moss with patches that glow faintly and breathe, pale
##          cave mushrooms; spores drifting up
##
## Two ways in, both here:
##   grade(kind)          what the generator's own terrain wears: the
##                        palette's grass ratio, the ground material's dust,
##                        the tufts' seasons (called by underground.gd every
##                        frame it holds the look)
##   cover(parent, area, kind, y)  a layer on a stone top, for the city kit
##
## Cost: the terrain's dust is a handful of noise taps in the ground shader
## only while `ground_dust` > 0. A cover is one skin mesh (a quad or a
## triangulated polygon) and the existing KitFlora multimesh draw of the
## catalog's tufts, in tiles that cull and fade as the isles' grass does.
## Nothing runs a frame.
const Flora = preload("res://scripts/kit_isle/kit_flora.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SKIN :=preload("res://shaders/underground_cover.gdshader")
const FLAG := "--ground"
## The cover the underground wears when the flags don't say.
const DEFAULT := "grass"
## Per cover: `ground` where the field's mid green (FIELD_GREEN, ZS_GROUND_GREEN
## in shaders/ground_look.gdshaderinc) is taken to (linear), the ground
## material's knobs (`dust`, `hue`, `living`, `calm`), the skin's mode and
## colours, and what grows through it: `tufts` a square metre at the
## thickest, `under` [asset, a square metre], `motes` the air's.
const KINDS := {
	"grass": {"title":"Ground: grass, dusted",
		"earth":Vector3(0.15,0.13,0.09),"ground":Color(0.105,0.135,0.082),"dust":0.0,"hue":0.35,"living":0.0,"calm":0.6,
		"skin":2,"tone":Color(0.14,0.15,0.09),"deep":Color(0.08,0.09,0.06),"lit":Color(0.2,0.2,0.12),"glow":0.0,
		"tuft_living":0.3,"tuft_pull":0.45,"tuft_dry":0.3,"tufts":3.2,"under":[["fern",0.02],["mushroom",0.006]],"motes":""},
	"dust": {"title":"Ground: dust and ash",
		"earth":Vector3(0.2,0.185,0.16),"ground":Color(0.25,0.26,0.255),"dust":1.0,"hue":0.15,"living":0.0,"calm":0.85,
		"skin":0,"tone":Color(0.26,0.265,0.255),"deep":Color(0.18,0.185,0.18),"lit":Color(0.36,0.36,0.34),"glow":0.0,
		"tuft_living":0.0,"tuft_pull":0.3,"tuft_dry":0.7,"tufts":0.55,"under":[["mushroom",0.004]],"motes":"grit"},
	"moss": {"title":"Ground: cave moss",
		"earth":Vector3(0.07,0.12,0.1),"ground":Color(0.035,0.1,0.085),"dust":0.0,"hue":0.2,"living":0.0,"calm":0.8,
		"skin":1,"tone":Color(0.035,0.1,0.085),"deep":Color(0.02,0.06,0.055),"lit":Color(0.06,0.16,0.12),"glow":0.5,
		"tuft_living":0.6,"tuft_pull":0.4,"tuft_dry":0.0,"tufts":1.2,"under":[["mushroom",0.03],["fern",0.012]],"motes":"spores"},
}
## The ground's warmth under each preset: the torch's cool moon takes a
## warmer ground (else sand reads as snow), the haze's warm light a cooler one.
const WARM := {"torch":Vector3(1.3,1.0,0.6),"haze":Vector3(1.0,1.0,1.0)}
## How much a glowing cover glows under each preset: the torch's dark lets it
## show, the haze's light washes it out.
const GLOW := {"torch":1.0,"haze":0.3}
const FIELD_GREEN := Vector3(0.1296,0.3563,0.1597)
## The skin lies this far over the stone (m).
const LIFT := 0.012
static var _applied := "?"
static var _tick := 0
static var _preset := ""

## The cover the flags ask: --ground=grass|dust|moss|off, else DEFAULT.
## "" when --underground is not on (nothing is laid) or --ground=off.
static func asked() -> String:
	var args: Array = preload("res://scripts/launch_args.gd").user_args()
	# The look's own answer: its flag, or the run's world (underground.gd `on`).
	if not bool(load("res://scripts/underground/underground.gd").on()): return ""
	for a: String in args:
		if a.begins_with(FLAG+"="):
			var k := a.get_slice("=",1)
			if KINDS.has(k): return k
			if k in ["off","none","orange","default"]: return ""
	return DEFAULT

## The next cover after `kind` ("" is the day's own ground, as before).
static func next(kind: String) -> String:
	var order: Array = [""]
	order.append_array(KINDS.keys())
	return order[(order.find(kind)+1) % order.size()]

# --- The terrain ----------------------------------------------------------------------

## The terrain's ground and tufts wearing `kind` ("" leaves them as the day
## paints them): the grass ratio, the ground material's dust, the tufts'
## seasons (no gold) Cheap; call it every frame the look is held. True the
## frame it hands the day's own ground back: republish the scene's palette.
static func grade(kind: String, preset := "haze") -> bool:
	var changed := kind != _applied or preset != _preset
	var was := _applied
	_applied = kind
	_preset = preset
	_tick += 1
	if kind == "":
		if changed and was != "?" and was != "":
			# Back to the day's own: the ground material's defaults, the
			# tufts' seasons; the caller republishes the scene's palette.
			_ground_materials(func(m: ShaderMaterial) -> void:
				m.set_shader_parameter("ground_dust",0.0)
				m.set_shader_parameter("ground_hue",1.15)
				m.set_shader_parameter("ground_living",0.3)
				m.set_shader_parameter("ground_calm",0.6)
				m.set_shader_parameter("ground_path",Vector3(-1.0,-1.0,-1.0))
				m.set_shader_parameter("leaf_season",Vector4(1.0,0.0,0.0,0.0)))
			for key: String in SkyIslets._plant_materials:
				if not _seasonal(key): continue
				var m: Variant = SkyIslets._plant_materials[key]
				if m is ShaderMaterial:
					(m as ShaderMaterial).set_shader_parameter("leaf_season",preload("res://scripts/scene_look.gd").leaf_season(key))
					if key.begins_with("grass"):
						(m as ShaderMaterial).set_shader_parameter("grass_living",0.4)
						(m as ShaderMaterial).set_shader_parameter("grass_ground_pull",0.4)
						(m as ShaderMaterial).set_shader_parameter("grass_dry",0.25)
			return true
		return false
	var k: Dictionary = KINDS[kind]
	var g: Color = k.ground
	var warm: Vector3 = WARM.get(preset,Vector3.ONE)
	RenderingServer.global_shader_parameter_set("zs_palette_grass",Vector3(g.r*warm.x/FIELD_GREEN.x,g.g*warm.y/FIELD_GREEN.y,g.b*warm.z/FIELD_GREEN.z))
	if changed or _tick % 20 == 0:
		_ground_materials(func(m: ShaderMaterial) -> void:
			m.set_shader_parameter("ground_dust",float(k.dust))
			m.set_shader_parameter("ground_hue",float(k.hue))
			m.set_shader_parameter("ground_living",float(k.living))
			m.set_shader_parameter("ground_calm",float(k.calm))
			m.set_shader_parameter("ground_path",(k.earth as Vector3)*warm)
			# The gold, spring and straw of the seasons stay off the ground
			# and its grass; ivy, vines and the rest keep theirs.
			m.set_shader_parameter("leaf_season",Vector4(0.0,0.0,0.0,0.0)))
		for key: String in SkyIslets._plant_materials:
			if not _seasonal(key): continue
			var m: Variant = SkyIslets._plant_materials[key]
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("leaf_season",Vector4(0.0,0.0,0.0,0.0))
				if key.begins_with("grass"):
					(m as ShaderMaterial).set_shader_parameter("grass_living",float(k.tuft_living))
					(m as ShaderMaterial).set_shader_parameter("grass_ground_pull",float(k.tuft_pull))
					(m as ShaderMaterial).set_shader_parameter("grass_dry",float(k.tuft_dry))
	# The skins on stone take the preset's light the same way.
	if changed or _tick % 20 == 0:
		for n: Node in Engine.get_main_loop().get_nodes_in_group("ground_cover_skin"):
			((n as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("grade",warm)
			((n as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("glow_scale",float(GLOW.get(preset,1.0)))
	return false

## The plants that take the season's gold: the grass tufts, ferns, shrubs.
static func _seasonal(key: String) -> bool:
	return key.begins_with("grass") or key.begins_with("fern:") or key.begins_with("shrub:")

static func _ground_materials(apply: Callable) -> void:
	apply.call(KitLook.ground_material())
	var far: Variant = SkyIslets._ground_material
	if far is ShaderMaterial: apply.call(far)

# --- The layer on a stone top ---------------------------------------------------------

## Lays `kind` ("" the flags' own, nothing laid without --underground) on a
## walk surface and returns the node holding it (named "GroundCover", a child
## of `parent`), or null.
##   parent   the piece's Node3D; everything is in its own frame, so a
##            turned or tilted piece carries its cover
##   area     the top, in the parent's (x, z): a Rect2 (soft ragged edges, the
##            usual stair landing, deck or crown) or a PackedVector2Array
##            polygon (a hard edge: pillar crowns, curved tops)
##   y        the top's height in the parent's frame
##   seed_value  the scatter's seed (the same seed grows the same cover)
##   opts     "tufts": multiplier on the kind's tuft density (0 none),
##            "under": multiplier on shoots and mushrooms, "fade": the soft
##            edge's width in m (Rect2: 0.4), "amount": skin opacity 0..1,
##            "skin": false for tufts without the skin.
## The skin is world-anchored (it runs on from the terrain's and from the
## next piece's), and its colours follow `kind`; the tufts are the game's own
## grass tuft, drawn as the isles' are, and take the graded ground's colour.
static func cover(parent: Node3D, area: Variant, kind := "", y := 0.0, seed_value := 1, opts := {}) -> Node3D:
	if kind == "": kind = asked()
	if kind == "" or not KINDS.has(kind): return null
	var k: Dictionary = KINDS[kind]
	var polygon := PackedVector2Array()
	var box := Rect2()
	if area is Rect2:
		box = area
		polygon = _corners(box)
	elif area is PackedVector2Array:
		polygon = area
		box = Rect2(polygon[0],Vector2.ZERO)
		for q in polygon: box = box.expand(q)
	else:
		return null
	var node := Node3D.new()
	node.name = "GroundCover"
	node.set_meta("kind",kind)
	parent.add_child(node)
	if bool(opts.get("skin",true)):
		node.add_child(_skin(k,polygon,box,area is Rect2,y,float(opts.get("fade",0.4)),float(opts.get("amount",1.0))))
	var flora := _grow(k,polygon,box,y,seed_value,float(opts.get("tufts",1.0)),float(opts.get("under",1.0)))
	if flora != null: node.add_child(flora)
	return node

static func _corners(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])

static func _skin(k: Dictionary, polygon: PackedVector2Array, box: Rect2, rect: bool, y: float, fade: float, amount: float) -> MeshInstance3D:
	var tri := Geometry2D.triangulate_polygon(polygon)
	if tri.is_empty():
		polygon = _corners(box)
		tri = Geometry2D.triangulate_polygon(polygon)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for q in polygon:
		verts.append(Vector3(q.x,y+LIFT,q.y))
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = tri
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var m := ShaderMaterial.new()
	m.shader = SKIN
	m.set_shader_parameter("mode",int(k.skin))
	# The colours are linear here; the shader's are source colours (sRGB).
	m.set_shader_parameter("tone",(k.tone as Color).linear_to_srgb())
	m.set_shader_parameter("tone_deep",(k.deep as Color).linear_to_srgb())
	m.set_shader_parameter("tone_lit",(k.lit as Color).linear_to_srgb())
	m.set_shader_parameter("glow",float(k.glow))
	m.set_shader_parameter("amount",amount)
	m.set_shader_parameter("fade",fade)
	m.set_shader_parameter("boxed",rect)
	var c := box.get_center()
	m.set_shader_parameter("box",Vector4(c.x,c.y,box.size.x*0.5,box.size.y*0.5))
	var mi := MeshInstance3D.new()
	mi.name = "Skin"
	mi.add_to_group("ground_cover_skin")
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Tufts, and shoots and mushrooms, scattered over the polygon at height y.
static func _grow(k: Dictionary, polygon: PackedVector2Array, box: Rect2, y: float, seed_value: int, tufts: float, under: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var drift := FastNoiseLite.new()
	drift.seed = seed_value+5
	drift.frequency = 0.16
	var records: Array = []
	var ground := Flora.Ground.new()
	var area := box.get_area()
	var edges := Flora.EdgeIndex.new([polygon])
	var want := int(area*float(k.tufts)*tufts)
	for i in range(want*3):
		if records.size() >= want: break
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		if not Geometry2D.is_point_in_polygon(p,polygon): continue
		# In drifts: thick where the noise is high, none between.
		if drift.get_noise_2d(p.x,p.y)*0.5+0.5 < rng.randf()*0.85: continue
		if edges.upto(p) < 0.12: continue
		_record(records,ground,"grass_tuft",p,y,rng.randf_range(0.7,1.25),rng)
	for entry: Array in k.under:
		var n := int(area*float(entry[1])*under)
		for i in range(n):
			var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
			if not Geometry2D.is_point_in_polygon(p,polygon) or edges.upto(p) < 0.25: continue
			if str(entry[0]) == "mushroom":
				for j in range(rng.randi_range(2,5)):
					_record(records,ground,"mushroom",p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.1,0.4),y,rng.randf_range(0.5,0.9),rng)
			else:
				_record(records,ground,str(entry[0]),p,y,rng.randf_range(0.6,1.0),rng)
	if records.is_empty(): return null
	var draw := Flora.Draw.new(records,ground,area)
	while not draw.step(-1): pass
	return draw.node

static func _record(records: Array, ground: Flora.Ground, asset: String, p: Vector2, y: float, size: float, rng: RandomNumberGenerator) -> void:
	var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
	ground.heights[item.id] = y
	records.append(item)

# --- The air over it ------------------------------------------------------------------

## Fine grit blowing along the wind, or spores drifting up, in a box round the
## node it is added to (the generator moves it with the wanderer). null for a
## cover without any.
static func motes(kind: String) -> GPUParticles3D:
	if not KINDS.has(kind) or str(KINDS[kind].motes) == "": return null
	var spores: bool = KINDS[kind].motes == "spores"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22.0,2.0,22.0)
	pm.direction = Vector3(0.0,0.35,0.0) if spores else Vector3(1.0,0.06,0.25)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.15 if spores else 1.4
	pm.initial_velocity_max = 0.5 if spores else 3.4
	pm.gravity = Vector3(0.0,0.02,0.0) if spores else Vector3(0.0,-0.05,0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6 if spores else 1.1
	pm.turbulence_noise_scale = 2.2
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.18
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	var ramp := Gradient.new()
	ramp.set_color(0,Color(1,1,1,0))
	ramp.set_color(1,Color(1,1,1,0))
	ramp.add_point(0.2,Color(1,1,1,1))
	ramp.add_point(0.75,Color(1,1,1,0.8))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07,0.07) if spores else Vector2(0.05,0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var round := GradientTexture2D.new()
	round.fill = GradientTexture2D.FILL_RADIAL
	round.fill_from = Vector2(0.5,0.5)
	round.fill_to = Vector2(0.5,0.0)
	var dot := Gradient.new()
	dot.set_color(0,Color(1,1,1,1))
	dot.set_color(1,Color(1,1,1,0))
	round.gradient = dot
	round.width = 16
	round.height = 16
	mat.albedo_texture = round
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45,1.0,0.8,0.9) if spores else Color(0.85,0.78,0.64,0.7)
	if spores:
		mat.emission_enabled = true
		mat.emission = Color(0.3,1.0,0.75)
		mat.emission_energy_multiplier = 2.0
	quad.material = mat
	var p := GPUParticles3D.new()
	p.name = "GroundMotes"
	p.amount = 260
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-30,-6,-30),Vector3(60,14,60))
	p.process_material = pm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	return p

# --- A demo for the eye ---------------------------------------------------------------

## Three stone pieces laid by the wanderer's start with `kind` on their tops,
## to judge the cover on bare stone (`--ground-demo` in the generator): a
## stair landing (Rect2), a causeway deck turned 20 degrees, a pillar crown
## (a polygon). Standing in a node "GroundDemo" under `study`.
static func demo(study: Node3D, at: Vector3, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "GroundDemo"
	study.add_child(root)
	root.global_position = at
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.2,0.185,0.17)
	stone.roughness = 0.95
	var specs: Array = [
		{"name":"Landing","pos":Vector3(-7.5,0.0,-6.0),"yaw":0.0,"size":Vector3(7.0,0.9,5.0),"rect":true},
		{"name":"Deck","pos":Vector3(6.0,0.0,-8.0),"yaw":20.0,"size":Vector3(3.0,0.7,13.0),"rect":true},
		{"name":"Crown","pos":Vector3(-1.0,0.0,-14.0),"yaw":0.0,"size":Vector3(3.4,3.2,3.4),"rect":false},
	]
	for spec: Dictionary in specs:
		var piece := Node3D.new()
		piece.name = spec.name
		root.add_child(piece)
		piece.position = spec.pos
		piece.rotation_degrees.y = float(spec.yaw)
		var size: Vector3 = spec.size
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
		mi.material_override = stone
		mi.position = Vector3(0.0,size.y*0.5-0.2,0.0)
		piece.add_child(mi)
		var top := size.y-0.2
		if bool(spec.rect):
			cover(piece,Rect2(-size.x*0.5,-size.z*0.5,size.x,size.z),kind,top,3)
		else:
			var ring := PackedVector2Array()
			for i in range(10): ring.append(Vector2.from_angle(i*TAU/10.0)*size.x*0.5)
			cover(piece,ring,kind,top,5)
	return root
