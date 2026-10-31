extends Node3D
## What stands on the coast's isles (coast_isles.gd): the lighthouse on Light
## Rock with its turning beam, and the old freighter moored in the Horn's
## lagoon, whose deck the plane can land on. Built once at setup and left
## standing: both are meant to read from far off.
##
## Handles: `coast/lighthouse`, `coast/boat` (LayoutOverrides). Their solids
## reach the flight the way the land's stone does: `ground` and `inside` in
## plane_ground and _blocked, `deck_at` in floor_at, a StaticBody on layer 1
## for the wing rays. Models: art/blender/coast/coast_build.py.

const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const Isles = preload("res://scripts/endless/coast_isles.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")

const LIGHT_MODEL := "res://assets/models/lighthouse.glb"
const BOAT_MODEL := "res://assets/models/boat.glb"
const SEA_Y := -40.0
## The lamp over the lighthouse's foot, the deck over the waterline (m;
## coast_build.py LAMP, DECK).
const LAMP_Y := 50.0
const DECK_Y := 4.6
## The hull's half length and half beam, and the clear deck's stern end
## (local z, the house beyond it; bow toward -z).
const HULL := Vector2(56.0,10.5)
const DECK_AFT := 27.0
## The beam: length (m), one turn (s), its strength.
const BEAM_LONG := 800.0
const TURN := 16.0
const BEAM_GLOW := 0.07
const LAYER := 1
## Local solids of the lighthouse and the boat (AABBs, their models' frames).
const LIGHT_BOXES := [
	[-12.0,-5.0,-12.0, 12.0,4.0,12.0], [-8.2,4.0,-8.2, 8.2,16.0,8.2], [-6.8,16.0,-6.8, 6.8,30.0,6.8],
	[-5.8,30.0,-5.8, 5.8,46.0,5.8], [-7.6,46.0,-7.6, 7.6,47.6,7.6], [-3.7,47.6,-3.7, 3.7,56.5,3.7],
	[-15.0,-3.0,-4.0, -5.0,11.4,7.0],
]
const BOAT_BOXES := [
	[-10.5,-6.0,-25.0, 10.5,4.6,56.0], [-9.5,-6.0,-35.0, 9.5,4.6,-25.0], [-7.0,-6.0,-45.0, 7.0,4.6,-35.0],
	[-3.5,-6.0,-56.0, 3.5,4.6,-45.0], [-8.0,4.6,28.0, 8.0,7.8,46.0], [-6.0,7.8,29.0, 6.0,11.1,42.0],
	[-4.0,11.1,30.0, 4.0,13.9,35.0], [-2.0,11.1,37.0, 2.0,19.6,41.0], [-0.3,4.6,47.7, 0.3,23.6,48.3],
	[-9.9,4.6,-14.3, -9.3,16.6,-13.7], [9.3,4.6,-14.3, 9.9,16.6,-13.7], [-9.9,4.6,11.7, -9.3,16.6,12.3], [9.3,4.6,11.7, 9.9,16.6,12.3],
]

var light_at := Vector3.INF
var boat_at := Vector3.INF
## The sites' solids: [{inv, oy, g, reach}].
var _solids: Array = []
var _boat_inv := Transform3D.IDENTITY
var _boat_on := false
var _beam: Node3D
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _t := 0.0

func setup(game: Node) -> void:
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
		var n := _place("Lighthouse",LIGHT_MODEL,t,mat,_grime_light)
		LayoutOverrides.track("coast/lighthouse",n,"coast",coded)
		_add_solid(t,LIGHT_BOXES,n)
		_lamp(n)
		light_at = t.origin
	if not LayoutOverrides.deleted("coast/boat") and is_finite(isles.world("coast/horn",0.0).x):
		var at: Vector2 = isles.world("coast/horn",Isles.BOAT_AT.x,Isles.BOAT_AT.y)
		var coded := Transform3D(Basis(Vector3.UP,float(isles.yaw("coast/horn"))-PI*0.5),Vector3(at.x,SEA_Y,at.y))
		var t: Transform3D = LayoutOverrides.xform("coast/boat",coded)
		var n := _place("Boat",BOAT_MODEL,t,mat,_grime_boat)
		LayoutOverrides.track("coast/boat",n,"coast",coded)
		_add_solid(t,BOAT_BOXES,n)
		_boat_inv = t.affine_inverse()
		_boat_on = true
		boat_at = t.origin

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

## The deck's height (world y) at world XZ `p`, or NAN off it.
func deck_at(p: Vector2) -> float:
	if not _boat_on: return NAN
	var l: Vector3 = _boat_inv*Vector3(p.x,_boat_inv.inverse().origin.y,p.y)
	if l.z > DECK_AFT or l.z < -HULL.x: return NAN
	if absf(l.x) > _deck_half(l.z)-0.3: return NAN
	return SEA_Y+DECK_Y

## The deck's half beam at local z (coast_build.py `hull_section`).
static func _deck_half(z: float) -> float:
	var t := -z/HULL.x
	var bow := maxf(0.0,(t-0.45)/0.55)
	return HULL.y*(1.0-pow(bow,2.1)*0.97)

## SkyGlide's `ground` at `p` over the land `h` (as LandRocks `ground`).
func ground(p: Vector3, h: Variant, pad := 0.4) -> Variant:
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

## The boat's weather: rust down the plates from each scupper, the deck worn
## pale up its middle, the waterline fouled.
static func _grime_boat(c: Color, at: Vector3, named: String) -> Color:
	var rust := pow(Isles._n(at.z*0.13,at.y*0.05+at.x*0.09),2.0)
	var out := c.lerp(Color(0.16,0.07,0.035),rust*(0.6 if named == "hull" or named == "rust" else 0.4))
	if named == "deck" or named == "plate":
		out = out.lerp(Color(0.44,0.41,0.36),(1.0-smoothstep(1.0,5.0,absf(at.x)))*0.5)
	if named == "hull" and at.y < 0.8: out = out.lerp(Color(0.03,0.05,0.035),1.0-smoothstep(-1.0,0.8,at.y))
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
