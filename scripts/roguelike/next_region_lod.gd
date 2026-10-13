extends RefCounted
## The next region, far off (docs/design/roguelike/layer-round4-sprawl.md;
## scripts/roguelike/layer_sprawl.gd `_place_next`): the next seed's isles
## drawn as soft silhouettes from their occupancy alone (data/layer/
## pieces.json, per 2 m cell an isle's lowest and highest solid; a rolled
## broken ring's from its plan), never built. Cheap: one mesh, one
## material, no collision, no art, no life.
##
## Each isle is a closed hull over its cells' MIDDLES (a dual grid): a top
## at each cell's highest solid and a keel at its lowest, joined where four
## (or three) neighbouring cells stand, walled round its outline. A lone
## tall cell (a spire, a pier) so comes to a point over its neighbours
## rather than a block, and its keel hangs as the isle's root hangs: a
## silhouette, not a voxel model. The landmark (the region's highest isle)
## keeps its 2 m cells; the rest are merged MERGE cells to a side (their
## lowest and highest).
##
## Its colour and haze are the shader's (shaders/next_region_lod.gdshader):
## turf on what faces up, stone and earth down the flanks, all going into
## the sky's own colour with distance and more so down the keels, the
## landmark held a little clearer.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const SHADER := preload("res://shaders/next_region_lod.gdshader")

## Cells merged to a side on all but the landmark.
const MERGE := 2
## The haze (the shader's uniforms, mirrored by `haze` for the tests):
## its reach (m), the most it takes, the extra down a keel, how much
## clearer the landmark stays.
const HAZE_REACH := 1100.0
const HAZE_MOST := 0.8
const KEEL_MIST := 0.45
const LANDMARK_CLEAR := 0.35

## The silhouette node for `next` (LayerSprawl `_place_next`): a
## MeshInstance3D at its transform, its numbers on `stats` meta ({ms,
## triangles, vertices, isles}).
static func build(next: Dictionary) -> MeshInstance3D:
	var began := Time.get_ticks_usec()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	# The region's height range (its own frame): the shader's height share.
	var low := INF
	var high := -INF
	for isle: Dictionary in next.isles:
		var span := LayerPlan._span({"occ":isle.occ,"offset":isle.offset})
		low = minf(low,span.x)
		high = maxf(high,span.y)
	var k := 0
	for isle: Dictionary in next.isles:
		_hull(isle.occ,isle.offset,1 if isle.landmark else MERGE,bool(isle.landmark),k,Vector2(low,high),verts,normals,colors,uvs,index)
		k += 1
	for i in range(normals.size()): normals[i] = normals[i].normalized() if normals[i].length_squared() > 1e-12 else Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	if not index.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.name = "NextRegion"
	node.mesh = mesh
	node.transform = next.xform
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("haze_reach",HAZE_REACH)
	material.set_shader_parameter("haze_most",HAZE_MOST)
	material.set_shader_parameter("keel_mist",KEEL_MIST)
	material.set_shader_parameter("landmark_clear",LANDMARK_CLEAR)
	node.material_override = material
	node.set_meta("stats",{"ms":(Time.get_ticks_usec()-began)/1000.0,"triangles":index.size()/3,"vertices":verts.size(),"isles":(next.isles as Array).size(),
		"surfaces":mesh.get_surface_count()})
	return node

## How much of the region at `dist` m from the eye, `share` of the way up
## its height range, has gone into the sky (the shader's curve).
static func haze(dist: float, share: float, landmark: bool) -> float:
	var h := 1.0-exp(-pow(dist/HAZE_REACH,2.0))
	h = lerpf(h,1.0,KEEL_MIST*(1.0-share))
	if landmark: h *= 1.0-LANDMARK_CLEAR
	return minf(h,HAZE_MOST)

## One isle's hull into the arrays: its occupancy `occ` at `offset`, cells
## merged `merge` to a side.
static func _hull(occ: Dictionary, offset: Vector3, merge: int, landmark: bool, n: int, range_y: Vector2,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, index: PackedInt32Array) -> void:
	var cols := int(ceil(float(occ.cols)/merge))
	var rows := int(ceil(float(occ.rows)/merge))
	var cell := float(occ.cell)*merge
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(cols*rows)
	hi.resize(cols*rows)
	lo.fill(INF)
	hi.fill(-INF)
	var flo: PackedFloat32Array = occ.lo
	var fhi: PackedFloat32Array = occ.hi
	for k in range(flo.size()):
		if flo[k] == INF: continue
		var c := (k%int(occ.cols))/merge
		var r := (k/int(occ.cols))/merge
		lo[r*cols+c] = minf(lo[r*cols+c],flo[k])
		hi[r*cols+c] = maxf(hi[r*cols+c],fhi[k])
	var origin: Vector2 = occ.origin
	# A tint of its own, a little warmer on the landmark.
	var tint := Color(1.0,1.0,1.0,1.0 if landmark else 0.0)
	var shade := 0.94+0.06*float(n%3)
	tint.r = shade*(1.04 if landmark else 1.0)
	tint.g = shade
	tint.b = shade*(0.96 if landmark else 1.0)
	var span := maxf(range_y.y-range_y.x,1.0)
	var top := PackedInt32Array()
	var bottom := PackedInt32Array()
	top.resize(cols*rows)
	bottom.resize(cols*rows)
	top.fill(-1)
	bottom.fill(-1)
	for k in range(lo.size()):
		if lo[k] == INF: continue
		var x := origin.x+((k%cols)+0.5)*cell+offset.x
		var z := origin.y+((k/cols)+0.5)*cell+offset.z
		top[k] = verts.size()
		bottom[k] = verts.size()+1
		for y: float in [hi[k]+offset.y,lo[k]+offset.y]:
			verts.append(Vector3(x,y,z))
			normals.append(Vector3.ZERO)
			colors.append(tint)
			uvs.append(Vector2(clampf((y-range_y.x)/span,0.0,1.0),0.0))
	# The faces between neighbouring cells' middles: two triangles where
	# four stand, one where three; each edge's uses counted for the walls.
	var uses := {}
	for r in range(rows-1):
		for c in range(cols-1):
			var q := [r*cols+c,r*cols+c+1,(r+1)*cols+c+1,(r+1)*cols+c]
			var on: Array = q.filter(func(i: int) -> bool: return top[i] >= 0)
			var tris: Array = []
			if on.size() == 4: tris = [[q[0],q[1],q[2]],[q[0],q[2],q[3]]]
			elif on.size() == 3: tris = [on]
			for t: Array in tris:
				_tri(top[t[0]],top[t[1]],top[t[2]],Vector3.UP,verts,normals,index)
				_tri(bottom[t[0]],bottom[t[1]],bottom[t[2]],Vector3.DOWN,verts,normals,index)
				for e in range(3):
					var a: int = t[e]
					var b: int = t[(e+1)%3]
					var key := Vector2i(mini(a,b),maxi(a,b))
					if uses.has(key): uses[key][0] += 1
					else: uses[key] = [1,t[(e+2)%3]]
	# The outline: an edge of one face only, walled from top to keel, out
	# from the face's third corner.
	for key: Vector2i in uses:
		var u: Array = uses[key]
		if int(u[0]) != 1: continue
		var a: int = key.x
		var b: int = key.y
		var third: int = u[1]
		var mid := (verts[top[a]]+verts[top[b]])*0.5
		var out := mid-verts[top[third]]
		var along := verts[top[b]]-verts[top[a]]
		out = out-along*(out.dot(along)/maxf(along.length_squared(),1e-6))
		out.y = 0.0
		_tri(top[a],top[b],bottom[b],out,verts,normals,index)
		_tri(top[a],bottom[b],bottom[a],out,verts,normals,index)

## A triangle facing `want` (its winding turned to, Godot's clockwise
## front), its area-weighted normal added to its corners'.
static func _tri(a: int, b: int, c: int, want: Vector3, verts: PackedVector3Array, normals: PackedVector3Array, index: PackedInt32Array) -> void:
	var pa := verts[a]
	var pb := verts[b]
	var pc := verts[c]
	var n := (pa-pc).cross(pa-pb)
	if n.dot(want) < 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	if n.length_squared() < 1e-10: return
	index.append_array([a,b,c])
	normals[a] += n
	normals[b] += n
	normals[c] += n
