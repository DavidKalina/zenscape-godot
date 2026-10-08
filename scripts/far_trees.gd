extends RefCounted
## Far stand-ins for an islet's trees (a recipe's `far_trees`, SkyIslets
## `_plant`): past that many metres each tree part (a spruce's crown, a
## birch's trunk) is drawn by a few faceted faces instead of its own
## hundreds, so a sea of forested islands shows at once (the forest
## landform, scripts/landform_forest.gd).
##
## A part's stand-in is turned from its own mesh (`proxy`): its height cut
## into BANDS, each band's reach the REACH_SHARE quantile of how far its
## vertices stand off the part's axis and its colour their mean (the baked
## light and shade the crowns carry), the outline lathed round in SIDES
## flat faces (TRUNK_SIDES for a trunk), closed under and pointed on top.
## It wears the part's own material and takes the same instance buffer, so
## every tree keeps its place, size, turn and tint, and the crowns sway as
## before. Made once a part, on the main thread, and shared.

## The lathe: faces round a crown and a trunk (a trunk a plain prism
## tapering to half), bands up a crown, and the share of a band's vertices
## inside its reach, a crown's and a trunk's (its branches left out).
const SIDES := 5
const TRUNK_SIDES := 3
const BANDS := 3
const REACH_SHARE := 0.65
const TRUNK_SHARE := 0.3
## The stand-ins draw from the near trees' end out to RANGE (m), crossing
## over MARGIN m (the near trees' own margin, SkyIslets `_plant`).
const RANGE := 1600.0
const MARGIN := 30.0

static var _proxies := {}

## The stand-in for catalog part `key` (its mesh `mesh`), made once.
static func proxy(key: String, mesh: Mesh) -> ArrayMesh:
	if _proxies.has(key): return _proxies[key]
	var trunk := "trunk" in key or key.ends_with("mesh-11")
	var sides := TRUNK_SIDES if trunk else SIDES
	var box := mesh.get_aabb()
	var axis := Vector2(box.get_center().x,box.get_center().z)
	var bottom := box.position.y
	var height := maxf(box.size.y,0.01)
	var radii: Array = []
	var colours: Array = []
	for b in range(BANDS):
		radii.append([])
		colours.append([Color(0,0,0,0),0])
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: Variant = arrays[Mesh.ARRAY_COLOR]
		for i in range(vertices.size()):
			var v := vertices[i]
			var b := clampi(int((v.y-bottom)/height*BANDS),0,BANDS-1)
			(radii[b] as Array).append(Vector2(v.x,v.z).distance_to(axis))
			if colors is PackedColorArray and (colors as PackedColorArray).size() == vertices.size():
				colours[b][0] += (colors as PackedColorArray)[i]
				colours[b][1] += 1
	# The outline: the foot, each band's middle, the top.
	var profile: Array = []
	var shades: Array = []
	for b in range(BANDS):
		var list: Array = radii[b]
		var r := 0.0
		if not list.is_empty():
			list.sort()
			r = list[mini(int(list.size()*(TRUNK_SHARE if trunk else REACH_SHARE)),list.size()-1)]
		var count := int(colours[b][1])
		shades.append(Color(colours[b][0])/float(count) if count > 0 else Color.WHITE)
		profile.append(Vector2(r,bottom+height*(b+0.5)/BANDS))
	# Bands with no vertices take their neighbours' reach.
	for b in range(BANDS):
		if profile[b].x <= 0.0: profile[b].x = maxf(profile[maxi(b-1,0)].x,profile[mini(b+1,BANDS-1)].x)
	var foot := Vector2((profile[0] as Vector2).x*(1.0 if trunk else 0.55),bottom)
	var tip := Vector2(foot.x*0.5 if trunk else 0.0,bottom+height)
	# A trunk is a plain prism; a crown swells through its bands.
	profile = [foot,tip] if trunk else [foot]+profile+[tip]
	shades = [shades[0],shades[BANDS-1]] if trunk else [shades[0]]+shades+[shades[BANDS-1]]
	# Lathed round in flat faces, turned a little a ring so the facets
	# stagger.
	# (Plain arrays: a lambda holds a packed array by value.)
	var vertices := []
	var normals := []
	var colors := []
	var ring := func(k: int, s: int) -> Vector3:
		var p: Vector2 = profile[k]
		var a := TAU*(float(s)+0.5*(k % 2))/sides
		return Vector3(axis.x+cos(a)*p.x,p.y,axis.y+sin(a)*p.x)
	# A face whose front looks the way of `out` (Godot's front: (c-a)x(b-a),
	# as SkyIslet `_tri`), its normal its own, so it draws flat.
	var face := func(a: Vector3, b: Vector3, c: Vector3, tone: Color, out: Vector3) -> void:
		var n := (c-a).cross(b-a)
		if n.length_squared() < 1e-12: return
		if n.dot(out) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		n = n.normalized()
		for v in [a,b,c]:
			vertices.append(v)
			normals.append(n)
			colors.append(tone)
	for k in range(profile.size()-1):
		var tone: Color = (shades[k] as Color).lerp(shades[k+1],0.5)
		for s in range(sides):
			var a: Vector3 = ring.call(k,s)
			var b: Vector3 = ring.call(k,s+1)
			var c: Vector3 = ring.call(k+1,s+1)
			var d: Vector3 = ring.call(k+1,s)
			var middle := (a+b+c+d)*0.25
			var out := middle-Vector3(axis.x,middle.y,axis.y)
			face.call(a,b,c,tone,out)
			face.call(a,c,d,tone,out)
	var under := Vector3(axis.x,bottom,axis.y)
	for s in range(sides): face.call(under,ring.call(0,s),ring.call(0,s+1),shades[0],Vector3.DOWN)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	out[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	out[Mesh.ARRAY_COLOR] = PackedColorArray(colors)
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,out)
	_proxies[key] = made
	return made

## Stands the stand-ins for the tree parts among `plants` (an islet's
## flora: per part key its instance buffer and count) under `node`, drawn
## from `far` m out to RANGE: `meshes` and `roles` are the catalog's, and
## `material_of` gives a part's material (SkyIslets `_plant_material`).
static func stand(node: Node3D, plants: Dictionary, meshes: Dictionary, roles: Dictionary, material_of: Callable, far: float) -> void:
	for key: String in plants:
		if roles.get(key,"") != "tree" or not meshes.has(key): continue
		var batch := MultiMeshInstance3D.new()
		batch.name = "Far_"+key.replace(":","_")
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = proxy(key,meshes[key])
		multimesh.instance_count = int(plants[key].count)
		multimesh.buffer = plants[key].buffer
		batch.multimesh = multimesh
		batch.material_override = material_of.call(key)
		batch.set_meta("skip_reflection",true)
		batch.visibility_range_begin = far
		batch.visibility_range_begin_margin = MARGIN
		batch.visibility_range_end = RANGE
		batch.visibility_range_end_margin = MARGIN*4.0
		batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(batch)

## The triangles a part's stand-in draws (tests, the budget).
static func triangles(key: String, mesh: Mesh) -> int:
	return (proxy(key,mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
