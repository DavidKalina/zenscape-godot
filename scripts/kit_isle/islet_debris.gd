extends RefCounted
## Floating rock debris (round 3, docs/design/isle-look/islet-unit-handoff.md):
## broken fragments, boulders to pebbles, drawn as multimeshes of three
## faceted fragment shapes (chunky, shard, flake) in the crag rock's shader
## (shaders/islet_crag.gdshader), a share of them slowly turning and bobbing
## on the GPU (INSTANCE_CUSTOM: spin rad/s, phase, bob in the fragment's own
## units). Nothing collides.
##   around(seed, R, depth, outline, amount, tilt_axis, tilt)
##       a unit's own: densest just under it as if it were breaking apart,
##       thinning and spreading as they fall; a ring beside the cliff; a few
##       pebbles high round the rim
##   field(seed, count, inner, outer, low, high)
##       loose through a yard: an annulus of sky round the origin

const SHAPES := 3
## Turning: the share of fragments that turn, their spin (rad/s for a 1 m
## fragment; smaller ones faster), their bob (m).
const TURNING := 0.4
const SPIN := Vector2(0.03,0.22)
const BOB := Vector2(0.04,0.3)

static var _meshes: Array = []
static var _mat: ShaderMaterial = null

## Fragment shape `i`: an icosahedron pushed about (each corner its own
## reach), squashed by shape; flat faces; radius about 1.
static func shape_mesh(i: int) -> ArrayMesh:
	if _meshes.is_empty():
		for s in SHAPES: _meshes.append(_make_shape(s))
	return _meshes[i]

static func _make_shape(kind: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["islet_fragment",kind])
	var t := (1.0+sqrt(5.0))/2.0
	var v: Array = [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
	var squash: Vector3 = [Vector3(1.0,0.85,0.95),Vector3(0.55,1.5,0.7),Vector3(1.2,0.45,1.0)][kind]
	for i in v.size():
		var p: Vector3 = (v[i] as Vector3).normalized()*rng.randf_range(0.72,1.22)
		v[i] = p*squash
	var faces := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for f: Array in faces:
		for idx: int in [f[0],f[2],f[1]]:
			var p: Vector3 = v[idx]
			# Shade: the underside's faces darker.
			st.set_color(Color(lerpf(0.55,1.0,clampf(p.y*0.5+0.5,0.0,1.0)),1.0,1.0,0.0))
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

## The debris material: the crag's shader, its vertex turning each fragment.
static func material() -> ShaderMaterial:
	if _mat == null:
		var code: String = preload("res://shaders/islet_crag.gdshader").code
		var a := code.find("//VERTEX_BEGIN")
		var b := code.find("//VERTEX_END")
		var spin := """void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	float ph = INSTANCE_CUSTOM.y * 6.2831853;
	float ang = TIME * INSTANCE_CUSTOM.x + ph;
	vec3 ax = normalize(vec3(sin(ph * 1.7), 0.8, cos(ph * 2.3)));
	float cs = cos(ang);
	float sn = sin(ang);
	VERTEX = VERTEX * cs + cross(ax, VERTEX) * sn + ax * dot(ax, VERTEX) * (1.0 - cs);
	NORMAL = NORMAL * cs + cross(ax, NORMAL) * sn + ax * dot(ax, NORMAL) * (1.0 - cs);
	VERTEX.y += sin(TIME * 0.4 + ph) * INSTANCE_CUSTOM.z;
}
"""
		var sh := Shader.new()
		sh.code = code.substr(0,a)+spin+code.substr(b+"//VERTEX_END".length())
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("top_y",1.0)
		_mat.set_shader_parameter("bottom_y",-1.2)
		_mat.set_shader_parameter("band_m",0.45)
		_mat.set_shader_parameter("strata",0.55)
		_mat.set_shader_parameter("weather",0.6)
		_mat.set_shader_parameter("greenery",0.6)
		_mat.set_shader_parameter("bed_scale",1.6)
		_mat.set_shader_parameter("block_tilt",0.3)
	return _mat

## Fragments as nodes: one multimesh a shape. Each record: [position,
## size, rng-drawn basis, turning (bool), mossy (bool)].
static func _draw(records: Array, rng: RandomNumberGenerator, range_end: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Debris"
	var by_shape: Array = [[],[],[]]
	for r: Array in records: (by_shape[int(r[5])] as Array).append(r)
	for s in SHAPES:
		var list: Array = by_shape[s]
		if list.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = shape_mesh(s)
		mm.instance_count = list.size()
		var box := AABB()
		for i in list.size():
			var r: Array = list[i]
			var size := float(r[1])
			# Each its own squash, so no two read as the same stone.
			var squash := Vector3(1.0,rng.randf_range(0.45,1.0),rng.randf_range(0.6,1.0))
			var xf := Transform3D((r[2] as Basis)*Basis.from_scale(squash*size),r[0])
			mm.set_instance_transform(i,xf)
			var mossy := bool(r[4])
			mm.set_instance_color(i,Color(rng.randf_range(0.75,1.0),0.7 if mossy else 0.0,rng.randf(),0.0))
			var spin := 0.0
			var bob := 0.0
			if bool(r[3]):
				spin = rng.randf_range(SPIN.x,SPIN.y)/sqrt(maxf(size,0.15))*(1.0 if rng.randf() < 0.5 else -1.0)
				bob = rng.randf_range(BOB.x,BOB.y)/maxf(size,0.1)
			mm.set_instance_custom_data(i,Color(spin,rng.randf(),bob,0.0))
			var here := AABB((r[0] as Vector3)-Vector3.ONE*(size*1.6+0.4),Vector3.ONE*(size*3.2+0.8))
			box = here if i == 0 else box.merge(here)
		mm.custom_aabb = box
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Shape%d" % s
		mmi.multimesh = mm
		mmi.material_override = material()
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = range_end*0.1
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mmi)
	root.set_meta("count",records.size())
	return root

static func _shape_for(rng: RandomNumberGenerator) -> int:
	var x := rng.randf()
	return 0 if x < 0.55 else (1 if x < 0.78 else 2)

## A size drawn on a log scale between `least` and `most`, leaning small
## by `lean_small` (>1 more pebbles).
static func _size(rng: RandomNumberGenerator, least: float, most: float, lean_small := 1.6) -> float:
	return least*pow(most/maxf(least,0.001),pow(rng.randf(),lean_small))

## A unit's debris (its origin the unit's top middle, before its tilt).
static func around(seed_value: int, R: float, depth: float, outline: Array, amount: float, tilt_axis: Vector3, tilt: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["islet_debris",seed_value])
	var n := int(clampf(40.0+R*20.0,40.0,360.0)*clampf(amount,0.0,2.0))
	var biggest := clampf(R*0.17,0.4,3.0)
	var records: Array = []
	var tb := Basis(tilt_axis,tilt) if tilt > 0.0 else Basis()
	for i in n:
		var zone := rng.randf()
		var p: Vector3
		var size: float
		if zone < 0.6:
			# Under: breaking away, the biggest nearest, spreading as it falls.
			var s := pow(rng.randf(),1.8)
			var y := -depth*(0.75+1.0*s)
			var rad := R*(0.15+0.9*s)*sqrt(rng.randf())+R*0.1
			p = Vector3.FORWARD.rotated(Vector3.UP,rng.randf()*TAU)*rad+Vector3(0.0,y,0.0)
			size = _size(rng,0.06,lerpf(biggest,biggest*0.3,s),1.3)
		elif zone < 0.88:
			# Beside the cliff: a loose ring, chips off the faces.
			var a := rng.randf()*TAU
			var rim := _rim_at(outline,a)
			var y := -depth*rng.randf_range(0.04,0.75)
			p = Vector3(cos(a),0.0,sin(a))*rim*rng.randf_range(1.12,1.75)+Vector3(0.0,y,0.0)
			size = _size(rng,0.05,biggest*0.6)
		else:
			# High round the rim: pebbles.
			var a := rng.randf()*TAU
			var rim := _rim_at(outline,a)
			p = Vector3(cos(a),0.0,sin(a))*rim*rng.randf_range(1.2,2.3)+Vector3(0.0,rng.randf_range(-depth*0.2,R*0.35),0.0)
			size = _size(rng,0.04,0.3)
		var basis := Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU))
		var turning := rng.randf() < TURNING
		var mossy := size > biggest*0.4 and rng.randf() < 0.35
		records.append([tb*p,size,basis,turning,mossy,_shape_for(rng)])
	return _draw(records,rng,maxf(260.0,R*45.0))

static func _rim_at(outline: Array, a: float) -> float:
	if outline.is_empty(): return 1.0
	var j := int(wrapf(a,0.0,TAU)/TAU*outline.size())%outline.size()
	return (outline[j] as Vector2).length()

## Loose debris through a yard: `count` fragments in the annulus `inner`..
## `outer` (m) round the origin, `low`..`high` (m) up, boulders to pebbles.
static func field(seed_value: int, count: int, inner: float, outer: float, low: float, high: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["islet_field",seed_value])
	var records: Array = []
	for i in count:
		var a := rng.randf()*TAU
		var d := sqrt(lerpf(inner*inner,outer*outer,rng.randf()))
		var p := Vector3(cos(a)*d,rng.randf_range(low,high),sin(a)*d)
		var size := _size(rng,0.12,3.0,2.2)
		var basis := Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU))
		records.append([p,size,basis,rng.randf() < TURNING,size > 1.0 and rng.randf() < 0.4,_shape_for(rng)])
	var node := _draw(records,rng,outer*1.3)
	node.name = "DebrisField"
	return node
