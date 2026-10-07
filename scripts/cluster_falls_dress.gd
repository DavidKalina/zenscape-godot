extends RefCounted
## What stands on the waterfall terraces (scripts/cluster_falls.gd), stood
## up for the cluster dresser (scripts/cluster_dresser.gd): the paddies'
## water and bunds, the moss cushions, the mill wheel and its posts, and at
## each fall's foot its plunge: a ring of churning foam on the pool, a mist
## ring rising off it (shaders/sky_tepui_mist.gdshader, small), and after
## dark a warm light by the pool that the falling water catches.
##
## `prepare` makes a feature's own meshes (safe on a worker); `furnish`
## stands them under the member's node, adding its night lights to the
## dresser's `live` and halos to its batch. The paddies' water is the
## islets' pond water (SkyIslets `_pond_material`), laid OFF_MAP off as the
## ponds are, so it reads the sky as they do and none of the plate's maps.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Falls = preload("res://scripts/cluster_falls.gd")
const Builds = preload("res://scripts/showcase_builds.gd")
const WaterFlowView = preload("res://scripts/water_flow_view.gd")

## The bunds' turf and earth, the moss's greens (sRGB).
const TURF := Color("74964a")
const EARTH := Color("6b5640")
const MOSS := [Color("4d6e2c"),Color("5b7d33"),Color("3f5f28"),Color("6a8a3a")]
## The plunge: its foam ring's size (m across), the mist's puffs (count,
## radius m, rise m, life s), and its light by night (reach m, energy), and
## how far it fades out (m).
const FOAM := 2.6
const MIST := 9
const MIST_SIZE := Vector2(0.3,0.6)
const MIST_RISE := Vector2(0.8,2.0)
const MIST_LIFE := Vector2(3.5,6.0)
const MIST_RANGE := 220.0
const GLOW := Vector2(7.0,1.7)
const FADE := 60.0
const LIGHT_COLOR := Color("ffb36b")
## The depth the paddies' water is drawn as (m; its tint and how much of
## the bed shows through).
const PADDY_SEEN := 0.45

static var _foam_material: ShaderMaterial
static var _mist_material: ShaderMaterial
static var _quad: QuadMesh

## A feature's own meshes, safe on a worker: paddies {water (arrays), bunds},
## moss and wheel {mesh, posts}.
static func prepare(member: Dictionary, f: Dictionary) -> Variant:
	var shape: RefCounted = member.shape
	match str(f.type):
		"paddies": return {"water":_paddy_water(f.pads),"bunds":_bunds(f.pads,int(member.seed))}
		"moss": return _moss(shape,f.cushions,int(member.seed))
		"wheel": return {"wheel":_wheel_mesh(),"posts":_wheel_posts(f)}
	return null

## Stands feature `f` of `member` under `node`; `mats` the dresser's shared
## materials, `halos` and `live` its night batch and lights.
static func furnish(node: Node3D, member: Dictionary, f: Dictionary, made: Variant, mats: Dictionary, halos: Array, live: Dictionary) -> void:
	match str(f.type):
		"paddies":
			var islets: Node = node.get_parent()
			var water := MeshInstance3D.new()
			water.name = "Paddies"
			water.mesh = SkyIslet.mesh_from(made.water,islets._pond_material() if islets != null and islets.has_method("_pond_material") else null,SkyIslet.WATER_FORMAT)
			water.position = -SkyIslets.OFF_MAP
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			water.set_meta("skip_reflection",true)
			node.add_child(water)
			var bunds := MeshInstance3D.new()
			bunds.name = "Bunds"
			bunds.mesh = made.bunds
			bunds.material_override = mats.solid
			node.add_child(bunds)
		"moss":
			var moss := MeshInstance3D.new()
			moss.name = "Moss"
			moss.mesh = made
			moss.material_override = mats.solid
			moss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(moss)
		"wheel":
			var posts := MeshInstance3D.new()
			posts.name = "WheelPosts"
			posts.mesh = made.posts
			posts.material_override = mats.solid
			node.add_child(posts)
			var hub := Node3D.new()
			hub.name = "Wheel"
			hub.transform = Transform3D(_wheel_basis(f.way),Vector3(f.at.x,float(f.y),f.at.y))
			node.add_child(hub)
			var wheel := MeshInstance3D.new()
			wheel.mesh = made.wheel
			wheel.material_override = mats.solid
			hub.add_child(wheel)
			# It turns with the windmills' sails (SkyClusters `_animate`).
			live.sails.append(hub)
		"plunge":
			_plunge(node,member,f,live)

# --- Paddies ---------------------------------------------------------------------------

## The paddies' water: a fine flat sheet over each, inset under its bund, as
## the islets' pond arrays (SkyIslet `water_arrays`): depth, the run to the
## bank, the fetch in eight ways.
static func _paddy_water(pads: Array) -> Array:
	var tint: Color = WaterFlowView.TINT.mid.srgb_to_linear()
	var shift: Vector3 = SkyIslets.OFF_MAP
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var dirs := []
	for i in range(8): dirs.append(Vector2.from_angle(TAU*i/8.0))
	var order := [dirs[0],dirs[1],dirs[2],dirs[3],-dirs[0],-dirs[1],-dirs[2],-dirs[3]]
	for pad: Dictionary in pads:
		var rect: Rect2 = (pad.rect as Rect2).grow(-Falls.BUND.x*0.5)
		var y: float = float(pad.y)+Falls.PADDY_DEPTH
		var nx := maxi(int(ceil(rect.size.x/0.35)),1)
		var nz := maxi(int(ceil(rect.size.y/0.35)),1)
		for j in range(nz):
			for i in range(nx):
				var p00 := rect.position+Vector2(rect.size.x*i/nx,rect.size.y*j/nz)
				var p11 := rect.position+Vector2(rect.size.x*(i+1)/nx,rect.size.y*(j+1)/nz)
				var p10 := Vector2(p11.x,p00.y)
				var p01 := Vector2(p00.x,p11.y)
				for p: Vector2 in [p00,p11,p10,p00,p01,p11]:
					vertices.append(Vector3(p.x,y,p.y)+shift)
					normals.append(Vector3.UP)
					colors.append(tint)
					var bank := minf(minf(p.x-rect.position.x,rect.end.x-p.x),minf(p.y-rect.position.y,rect.end.y-p.y))
					# Read as a little deeper than it is, so the water shows
					# its own body and the sky over the mud rather than
					# vanishing into it.
					uv.append(Vector2(bank*3.0+0.3,0.0))
					uv2.append(Vector2(PADDY_SEEN,0.0))
					var runs := []
					for d: Vector2 in order:
						var run := 9.0
						if d.x > 0.001: run = minf(run,(rect.end.x-p.x)/d.x)
						if d.x < -0.001: run = minf(run,(rect.position.x-p.x)/d.x)
						if d.y > 0.001: run = minf(run,(rect.end.y-p.y)/d.y)
						if d.y < -0.001: run = minf(run,(rect.position.y-p.y)/d.y)
						runs.append(clampf(run,0.0,9.0))
					fetch_a.append_array([runs[0],runs[1],runs[2],runs[3]])
					fetch_b.append_array([runs[4],runs[5],runs[6],runs[7]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays

## Low turf bunds round each paddy: a faceted ridge along each side, a
## little crooked, its top BUND.y over the water.
static func _bunds(pads: Array, seed_value: int) -> ArrayMesh:
	var st := Builds._begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*31+7
	var high := Falls.PADDY_DEPTH+Falls.BUND.y
	for pad: Dictionary in pads:
		var rect: Rect2 = pad.rect
		var y: float = pad.y
		var w := Falls.BUND.x
		var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		for k in range(4):
			var a: Vector2 = corners[k]
			var b: Vector2 = corners[(k+1)%4]
			var way := (b-a).normalized()
			var inward := Vector2(way.y,-way.x)
			if (rect.get_center()-a).dot(inward) < 0.0: inward = -inward
			# In two or three crooked lengths.
			var pieces := 2+rng.randi() % 2
			for s in range(pieces):
				var p0 := a.lerp(b,float(s)/pieces)
				var p1 := a.lerp(b,float(s+1)/pieces)
				var mid := (p0+p1)*0.5+inward*w*0.5+inward*rng.randf_range(-0.03,0.03)
				var length := p0.distance_to(p1)*0.5+w*0.5
				var tone := TURF.darkened(rng.randf_range(0.0,0.14)) if rng.randf() < 0.8 else EARTH
				var lift := rng.randf_range(-0.02,0.02)
				var basis := Basis(Vector3.UP,-way.angle()+rng.randf_range(-0.02,0.02))
				# A low ridge: a wide foot and a narrower crown over it.
				Builds.box(st,Vector3(mid.x,y-0.1+lift,mid.y),basis,Vector3(length,0.12+Falls.PADDY_DEPTH*0.5,w*0.5),tone)
				Builds.box(st,Vector3(mid.x,y+high*0.5+lift,mid.y),basis,Vector3(length*0.99,high*0.5+0.01,w*0.3),tone.lightened(0.04))
	return Builds._end(st)

# --- Moss ------------------------------------------------------------------------------

## Moss cushions: each a low faceted dome (a seven-sided foot ring, a
## shoulder ring, a crown) seated on the ground, in the moss's greens.
static func _moss(shape: RefCounted, cushions: Array, seed_value: int) -> ArrayMesh:
	var st := Builds._begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*13+5
	for c: Vector4 in cushions:
		var tone: Color = MOSS[rng.randi() % MOSS.size()]
		var linear := tone.srgb_to_linear()
		var top := linear.lightened(0.08)
		var at := Vector2(c.x,c.y)
		var sides := 7
		var turn := rng.randf()*TAU
		var foot: Array = []
		var shoulder: Array = []
		for k in range(sides):
			var a := turn+TAU*k/sides
			var stretch := rng.randf_range(0.85,1.15)
			var p := at+Vector2.from_angle(a)*c.z*stretch
			var g: float = shape.ground_at(p) if shape.on_land(p) else shape.ground_at(at)
			foot.append(Vector3(p.x,g-0.04,p.y))
			var q := at+Vector2.from_angle(a+PI/sides)*c.z*0.62*stretch
			shoulder.append(Vector3(q.x,shape.ground_at(at)+c.w*0.72,q.y))
		var crown := Vector3(at.x,shape.ground_at(at)+c.w,at.y)
		for k in range(sides):
			var k1 := (k+1)%sides
			_face(st,linear,foot[k],shoulder[k],foot[k1])
			_face(st,linear,foot[k1],shoulder[k],shoulder[k1])
			_face(st,top,shoulder[k],crown,shoulder[k1])
	return Builds._end(st)

## One face wound to face up and out.
static func _face(st: SurfaceTool, colour: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b-a).cross(c-a)
	if n.y < 0.0:
		var swap := b
		b = c
		c = swap
	# Front faces are clockwise from outside (Builds `_tri`).
	for v: Vector3 in [a,c,b]:
		st.set_color(colour)
		st.add_vertex(v)

# --- The wheel ----------------------------------------------------------------------------

## The wheel about its axle (+Z), in its hub's frame: two rims of tangent
## felloes, spokes, paddles between the rims and a hub.
static func _wheel_mesh() -> ArrayMesh:
	var st := Builds._begin()
	var r: float = Falls.WHEEL.x
	var w: float = Falls.WHEEL.y
	var felloes := 12
	for side: float in [-1.0,1.0]:
		var z := side*(w*0.5-0.04)
		for k in range(felloes):
			var a := TAU*(k+0.5)/felloes
			var seg := 2.0*r*sin(PI/felloes)*0.5+0.02
			Builds.box(st,Vector3(cos(a)*(r-0.05),sin(a)*(r-0.05),z),Basis(Vector3.BACK,a+PI*0.5),Vector3(seg,0.05,0.04),Builds.WOOD)
		for k in range(6):
			var a := TAU*k/6.0
			Builds.box(st,Vector3(cos(a)*r*0.5,sin(a)*r*0.5,z),Basis(Vector3.BACK,a-PI*0.5),Vector3(0.03,r*0.48,0.03),Builds.WOOD_DARK)
	for k in range(felloes):
		var a := TAU*k/felloes
		Builds.box(st,Vector3(cos(a)*(r-0.1),sin(a)*(r-0.1),0.0),Basis(Vector3.BACK,a-PI*0.5),Vector3(0.025,0.17,w*0.5),Builds.PLANK)
	Builds.prism_axis(st,6,0.1,0.1,-w*0.5-0.06,w*0.5+0.06,Builds.WOOD_DARK,0.0)
	return Builds._end(st)

## The wheel's two posts, seated on the banks, and the axle between them.
static func _wheel_posts(f: Dictionary) -> ArrayMesh:
	var st := Builds._begin()
	var y: float = f.y
	var posts: Array = f.posts
	for p: Vector3 in posts:
		Builds.prism(st,6,0.09,0.08,p.y-0.2,y+0.12,Builds.WOOD_DARK,0.3,Vector3(p.x,0.0,p.z))
		Builds.prism(st,6,0.13,0.11,p.y-0.1,p.y+0.18,Builds.STONE_DARK,0.0,Vector3(p.x,0.0,p.z))
	var a: Vector3 = posts[0]
	var b: Vector3 = posts[1]
	var mid := Vector3((a.x+b.x)*0.5,y,(a.z+b.z)*0.5)
	var across := Vector2(b.x-a.x,b.z-a.z)
	Builds.box(st,mid,Basis(Vector3.UP,-across.angle()),Vector3(across.length()*0.5+0.06,0.035,0.035),Builds.WOOD_DARK)
	return Builds._end(st)

## The hub's frame: its +Z the axle across the channel, turned so the
## sails' turn (about -Z, SkyClusters `_animate`) sweeps the paddles at the
## bottom downstream, along `way`.
static func _wheel_basis(way: Vector2) -> Basis:
	var down := Vector3(way.x,0.0,way.y)
	var z := Vector3(-way.y,0.0,way.x)
	var x := Vector3.UP.cross(z)
	if x.dot(down) > 0.0:
		z = -z
		x = Vector3.UP.cross(z)
	return Basis(x,Vector3.UP,z)

# --- The plunge ----------------------------------------------------------------------------

static func _shared() -> void:
	if _foam_material != null: return
	_foam_material = ShaderMaterial.new()
	_foam_material.shader = preload("res://shaders/fall_pool_foam.gdshader")
	_foam_material.render_priority = 2
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://shaders/sky_tepui_mist.gdshader")
	_mist_material.render_priority = 3
	_mist_material.set_shader_parameter("soft_depth",0.8)
	_mist_material.set_shader_parameter("strength",0.75)
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE

## Lets the shared pieces go (with the sky).
static func release() -> void:
	_foam_material = null
	_mist_material = null
	_quad = null

## Where a fall lands in a pool: the churning foam ring on the water, the
## mist ring rising off it, and the night's light that the fall catches.
static func _plunge(node: Node3D, member: Dictionary, f: Dictionary, live: Dictionary) -> void:
	_shared()
	var at := Vector3(f.at.x,float(f.y)+0.015,f.at.y)
	var foam := MeshInstance3D.new()
	foam.name = "PlungeFoam"
	foam.mesh = _quad
	foam.material_override = _foam_material
	foam.transform = Transform3D(Basis(Vector3.RIGHT,-PI*0.5).scaled(Vector3.ONE*FOAM),at)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(foam)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(member.seed)*7+3
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = MIST
	var drop: float = float(f.get("drop",4.0))
	for k in range(MIST):
		var a := TAU*k/MIST+rng.randf_range(-0.3,0.3)
		var ring := Vector3(cos(a),0.0,sin(a))*rng.randf_range(0.3,0.9)
		var r := rng.randf_range(MIST_SIZE.x,MIST_SIZE.y)*(0.8+drop*0.06)
		var rise := Vector3.UP*rng.randf_range(MIST_RISE.x,MIST_RISE.y)+ring*rng.randf_range(0.8,1.6)
		multimesh.set_instance_transform(k,Transform3D(Basis(Vector3.RIGHT*r,rise,Vector3.BACK),at+ring+Vector3.UP*0.1))
		multimesh.set_instance_custom_data(k,Color(rng.randf(),rng.randf(),rng.randf_range(MIST_LIFE.x,MIST_LIFE.y),0.8))
	var mist := MultiMeshInstance3D.new()
	mist.name = "PlungeMist"
	mist.multimesh = multimesh
	mist.material_override = _mist_material
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.custom_aabb = AABB(at-Vector3(4.0,1.0,4.0),Vector3(8.0,7.0,8.0))
	mist.visibility_range_end = MIST_RANGE
	node.add_child(mist)
	# After dark a warm light on the pool's near side, so the falling water
	# and its foam catch it.
	var way: Vector2 = f.way
	var light := OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.omni_range = GLOW.x
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = FADE
	light.distance_fade_length = FADE*0.25
	light.position = at+Vector3(way.x,0.0,way.y)*1.1+Vector3.UP*0.9
	light.visible = false
	node.add_child(light)
	live.lights.append([light,GLOW.y])
