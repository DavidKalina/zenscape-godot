extends Node3D
## What stands on the coast's isles (coast_isles.gd): the lighthouse on Light
## Rock with its turning beam, built once at setup and left standing; and the
## two pirate ships sailing the deep water off the Horn (pirate_ship.gd), stepped
## here (`before`, `after`), which also picks what only one of them may set.
##
## Handle: `coast/lighthouse` (LayoutOverrides), the ships' their own. The light's
## solid reaches the flight the way the land's stone does: `ground` and `inside`
## in plane_ground and _blocked, a StaticBody on layer 1 for the wing rays.
## Model: art/blender/coast/lighthouse_build.py, in the temple kit's stone
## (shaders/temple_stone.gdshader); `--lighthouse=old` puts coast_build.py's back.

const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const Isles = preload("res://scripts/endless/coast_isles.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const PirateShip = preload("res://scripts/endless/pirate_ship.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const LIGHT_MODEL := "res://assets/models/lighthouse.glb"
## The stone lighthouse (lighthouse_build.py): four meshes, its solids beside it.
const STONE_MODEL := "res://assets/models/lighthouse_stone.glb"
const STONE_BOXES := "res://assets/models/lighthouse_stone.boxes.json"
const STONE_SHADER := preload("res://shaders/temple_stone.gdshader")
## Where the stone lighthouse swaps to its far LOD (m from the camera).
const STONE_FAR_AT := 320.0
const SEA_Y := -40.0
## The lamp over the lighthouse's foot (m; coast_build.py LAMP).
const LAMP_Y := 50.0
## The beam: length (m), one turn (s), its strength.
const BEAM_LONG := 800.0
const TURN := 16.0
const BEAM_GLOW := 0.07
const LAYER := 1
## Local solids of the old lighthouse (AABBs, its model's frame); the stone
## one's come from STONE_BOXES.
const LIGHT_BOXES := [
	[-12.0,-5.0,-12.0, 12.0,4.0,12.0], [-8.2,4.0,-8.2, 8.2,16.0,8.2], [-6.8,16.0,-6.8, 6.8,30.0,6.8],
	[-5.8,30.0,-5.8, 5.8,46.0,5.8], [-7.6,46.0,-7.6, 7.6,47.6,7.6], [-3.7,47.6,-3.7, 3.7,56.5,3.7],
	[-15.0,-3.0,-4.0, -5.0,11.4,7.0],
]

var light_at := Vector3.INF
## The pirate ships (pirate_ship.gd), and the first of them, the one with the ring,
## or null. --one-ship leaves the second out, for the cost pairs.
var ships: Array[Node3D] = []
var ship: Node3D
var _game: Node
## The sites' solids: [{inv, oy, g, reach}].
var _solids: Array = []
var _beam: Node3D
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _t := 0.0

func setup(game: Node) -> void:
	_game = game
	var isles: RefCounted = game.field.isles()
	if isles == null: return
	# The colours, with a fill so the shaded side reads as paint from the coast
	# (the sun stands behind the sea; a stock material goes black there).
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nvoid fragment(){ALBEDO=COLOR.rgb;ROUGHNESS=0.9;EMISSION=COLOR.rgb*0.28;}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if not LayoutOverrides.deleted("coast/lighthouse") and is_finite(isles.world("coast/light",0.0).x):
		var at: Vector2 = isles.world("coast/light",Isles.LIGHT_AT.x,Isles.LIGHT_AT.y)
		var coded := Transform3D(Basis(Vector3.UP,float(isles.yaw("coast/light"))),Vector3(at.x,SEA_Y+Isles.LIGHT_TOP,at.y))
		var t: Transform3D = LayoutOverrides.xform("coast/lighthouse",coded)
		var n: Node3D
		if "--lighthouse=old" in LaunchArgs.user_args():
			n = _place("Lighthouse",LIGHT_MODEL,t,mat,_grime_light)
			_add_solid(t,LIGHT_BOXES,n)
		else:
			n = _place_stone("Lighthouse",t)
			_add_solid(t,_stone_boxes(),n)
		LayoutOverrides.track("coast/lighthouse",n,"coast",coded)
		_lamp(n)
		light_at = t.origin
	var args := LaunchArgs.user_args()
	if "--no-ship" in args: return
	if not LayoutOverrides.deleted("coast/ship"):
		ship = _sail(game,PirateShip.ROUTE_AT,"coast/ship",PirateShip.ROUTE_LEG,0.0)
	if not LayoutOverrides.deleted("coast/ship2") and not "--one-ship" in args:
		_sail(game,PirateShip.ROUTE2_AT,"coast/ship2",PirateShip.ROUTE2_LEG,PirateShip.ROUTE2_TURN)

## A ship on the oval round `at`, by the handle `label`.
func _sail(game: Node, at: Vector2, label: String, leg: float, turn: float) -> Node3D:
	var s: Node3D = PirateShip.new()
	add_child(s)
	s.setup(game,at,label,ship,leg,turn)
	ships.append(s)
	return s

## One turn of the beam, the lamp's flash as it comes round on the eye.
func step(delta: float, game: Node) -> void:
	if _beam == null: return
	_t += delta
	var a := _t*TAU/TURN
	_beam.rotation.y = a
	var eye: Vector3 = game.camera.global_position
	var to := Vector2(eye.x-light_at.x,eye.z-light_at.z)
	var way := Vector2(cos(a),-sin(a))
	var on := pow(absf(way.dot(to.normalized())),48.0)
	var d := eye.distance_to(light_at)
	var size := clampf(d*0.022,3.0,120.0)*(0.22+0.78*on)
	_flash.scale = Vector3.ONE*size
	_flash_mat.albedo_color = Color(1.0,0.86,0.6,0.35+0.65*on)

## Before the surge and the plane's move: the ships sail and their guns aim. The
## skim rate is the best either gives.
func before(delta: float) -> void:
	if ships.is_empty(): return
	var skim := 1.0
	for s: Node3D in ships:
		s.before(delta)
		skim = maxf(skim,s.skim)
	_game.near.skim_scale = skim

## After the plane's move: their balls meet it (`events`, the frame's).
func after(delta: float, events: Dictionary) -> void:
	for s: Node3D in ships: s.after(delta,events)

## The chase camera, each frame: the newest sink that wants it has it, and any older
## one lets go for good, so two sinks never pull it both ways.
func watch(chase: RefCounted) -> void:
	var eye: Node3D = null
	for s: Node3D in ships:
		if s.wants_eye() and (eye == null or s.sink_t < eye.sink_t): eye = s
	for s: Node3D in ships:
		if s == eye: continue
		if eye != null: s.give_up_eye()
		else: s.watch(chase)
	if eye != null: eye.watch(chase)

## The way off a ship's gun deck or wreck at `p` (PirateShip `deck_way_off`), or ZERO.
func deck_way_off(p: Vector3, what: String) -> Vector3:
	for s: Node3D in ships:
		var off: Vector3 = s.deck_way_off(p,what)
		if off != Vector3.ZERO: return off
	return Vector3.ZERO

## True inside a sinking ship, grown by `pad`.
func in_wreck(p: Vector3, pad: float) -> bool:
	for s: Node3D in ships:
		if s.wreck_inside(p,pad): return true
	return false

## SkyGlide's `ground` at `p` over the land `h` (as LandRocks `ground`).
func ground(p: Vector3, h: Variant, pad := 0.4) -> Variant:
	for s: Node3D in ships: h = s.wreck_ground(p,h,pad)
	if not h is float: return h
	var list: Array = []
	for s: Dictionary in _solids:
		if Vector2(p.x-float(s.x),p.z-float(s.z)).length_squared() > float(s.reach2): continue
		var l: Vector3 = (s.inv as Transform3D)*p
		BoxSolid.stretches(s.g,l.x,l.z,pad,float(s.oy),list)
	if list.is_empty(): return h
	return LandHalls.over(p,h,BoxSolid.joined(list))

## True inside a solid, grown by `pad`.
func inside(p: Vector3, pad := 0.4) -> bool:
	if in_wreck(p,pad): return true
	for s: Dictionary in _solids:
		if Vector2(p.x-float(s.x),p.z-float(s.z)).length_squared() > float(s.reach2): continue
		if BoxSolid.inside(s.g,(s.inv as Transform3D)*p,pad): return true
	return false

## The model `path` at `t`, every surface baked to vertex colours with `grime`.
func _place(nm: String, path: String, t: Transform3D, mat: Material, grime: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.transform = t
	add_child(root)
	var m := MeshInstance3D.new()
	m.mesh = _bake(load(path) as PackedScene,grime,mat)
	root.add_child(m)
	return root

## The stone lighthouse at `t`: its stone in the kit's shader near and far, the
## iron and the glass near only, each with its own small material.
func _place_stone(nm: String, t: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.transform = t
	add_child(root)
	var stone := ShaderMaterial.new()
	stone.shader = STONE_SHADER
	# The limewash and the red are in the vertex colours; less lichen over them.
	stone.set_shader_parameter("lichen",0.3)
	var iron := ShaderMaterial.new()
	iron.shader = Shader.new()
	iron.shader.code = "shader_type spatial;\nvoid fragment(){ALBEDO=COLOR.rgb;ROUGHNESS=0.55;EMISSION=COLOR.rgb*0.3;}"
	var glass := ShaderMaterial.new()
	glass.shader = Shader.new()
	# Dark panes with a sheen; the lens (bright vertex colour) lit from within.
	glass.shader.code = "shader_type spatial;\nvoid fragment(){float lens=smoothstep(0.3,0.7,COLOR.r);ALBEDO=COLOR.rgb*(1.0-0.6*lens);ROUGHNESS=0.06;SPECULAR=0.9;EMISSION=COLOR.rgb*mix(0.35,2.2,lens);}"
	var scene: PackedScene = load(STONE_MODEL)
	var model: Node = scene.instantiate()
	for node in model.find_children("*","MeshInstance3D",true,false):
		var src := node as MeshInstance3D
		var m := MeshInstance3D.new()
		m.name = String(src.name)
		m.mesh = src.mesh
		var named := String(src.name)
		if named.ends_with("_far"):
			m.material_override = stone
			m.visibility_range_begin = STONE_FAR_AT
		else:
			m.material_override = iron if named.contains("iron") else (glass if named.contains("glass") else stone)
			m.visibility_range_end = STONE_FAR_AT
		if named.contains("glass"): m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
	model.free()
	return root

## The stone lighthouse's solids, from its export's boxes.json ([x, y, z, sx, sy, sz],
## the model's frame), as [x0, y0, z0, x1, y1, z1].
static func _stone_boxes() -> Array:
	var out: Array = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STONE_BOXES))
	if not data is Dictionary:
		push_error("coast_sites: no solids in %s" % STONE_BOXES)
		return LIGHT_BOXES
	for b: Array in (data as Dictionary).get("boxes",[]):
		out.append([b[0],b[1],b[2],float(b[0])+float(b[3]),float(b[1])+float(b[4]),float(b[2])+float(b[5])])
	return out

static func _bake(scene: PackedScene, grime: Callable, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root: Node3D = scene.instantiate()
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		var pose := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			pose = (n as Node3D).transform*pose
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(s)
			var named := material.resource_name if material != null else ""
			var colour: Color = (material as BaseMaterial3D).albedo_color if material is BaseMaterial3D else Color.WHITE
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ids.is_empty():
				ids.resize(vs.size())
				for i in vs.size(): ids[i] = i
			for i in ids:
				var at: Vector3 = pose*vs[i]
				st.set_color(grime.call(colour.srgb_to_linear(),at,named))
				st.set_normal((pose.basis*ns[i]).normalized())
				st.add_vertex(at)
	root.free()
	var out := st.commit()
	out.surface_set_material(0,mat)
	return out

## The lighthouse's weather: run-off streaks under the gallery, the foot
## stained, no two bands alike. Colours are linear on the vertices.
static func _grime_light(c: Color, at: Vector3, named: String) -> Color:
	var k := 0.78+0.3*Isles._n(atan2(at.z,at.x)*3.4+at.y*0.015,at.y*0.09)
	var streak := pow(Isles._n(atan2(at.z,at.x)*5.0,3.0),2.0)*smoothstep(46.0,20.0,at.y)*0.55
	var out := c*k
	out = out.lerp(Color(0.16,0.10,0.06),streak)
	if named != "window": out = out.lerp(Color(0.05,0.055,0.04),(1.0-smoothstep(3.0,11.0,at.y))*0.6)
	out.a = 1.0
	return out

func _add_solid(t: Transform3D, boxes: Array, host: Node3D) -> void:
	var list: Array = []
	var far := 0.0
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	for b: Array in boxes:
		var a := AABB(Vector3(b[0],b[1],b[2]),Vector3(float(b[3])-float(b[0]),float(b[4])-float(b[1]),float(b[5])-float(b[2])))
		list.append(a)
		far = maxf(far,maxf(a.position.length(),a.end.length()))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = a.size
		shape.shape = box
		shape.position = a.get_center()
		body.add_child(shape)
	host.add_child(body)
	far += BoxSolid.grow_most()+1.0
	_solids.append({"inv":t.affine_inverse(),"oy":t.origin.y,"g":BoxSolid.build(list),"x":t.origin.x,"z":t.origin.z,"reach2":far*far})

## The lamp: a glow in the lantern, two beams turning, the flash facing the eye.
func _lamp(host: Node3D) -> void:
	var lamp := Node3D.new()
	lamp.position = Vector3(0.0,LAMP_Y,0.0)
	host.add_child(lamp)
	_beam = Node3D.new()
	lamp.add_child(_beam)
	var mesh := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var warm := Color(1.0,0.86,0.6)
	for side: float in [1.0,-1.0]:
		for q in 4:
			var r := q*PI*0.25
			var off := Vector3(0.0,cos(r),sin(r))
			# Each blade bright up its spine, nothing at its edges or its end.
			var near := off*1.2
			var far := off*20.0
			var a0 := Vector3(side*2.0,0.0,0.0)
			var a1 := Vector3(side*BEAM_LONG,-14.0,0.0)
			for sign_of: float in [1.0,-1.0]:
				var quad := [a0,a0+near*sign_of,a1+far*sign_of,a1]
				var alpha := [BEAM_GLOW,0.0,0.0,0.0]
				for i: int in [0,1,2,0,2,3]:
					vs.append(quad[i])
					cs.append(Color(warm,float(alpha[i])))
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_COLOR] = cs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var ray := StandardMaterial3D.new()
	ray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray.vertex_color_use_as_albedo = true
	ray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ray.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray.disable_fog = true
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = ray
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(m)
	# The flash: a soft disc on the lamp, big as it swings on the eye.
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.0,0.5)
	var g := Gradient.new()
	g.set_color(0,Color.WHITE)
	g.set_color(1,Color(1.0,1.0,1.0,0.0))
	g.add_point(0.18,Color(1.0,1.0,1.0,0.75))
	tex.gradient = g
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mat.albedo_texture = tex
	_flash_mat.disable_fog = true
	var quad := QuadMesh.new()
	_flash = MeshInstance3D.new()
	_flash.mesh = quad
	_flash.material_override = _flash_mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(_flash)
