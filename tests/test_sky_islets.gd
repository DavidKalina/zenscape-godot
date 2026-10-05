extends SceneTree
## The sky islets (scripts/sky_islet.gd, scripts/sky_islets.gd): made the
## way the islands are, only small. A seed always grows the same islet; its
## outline is an island's (one irregular piece, lobed, inside its grid) and
## clearly smaller than an island's; its ground stands over its rock, the
## top faces up and is what the queries read, the walls face out and the
## rock down; a spring's pond lies in its bowl with a channel under its water
## out to the lip, where its fall pours off clear of the rim. Across the
## cells there is variety: every kind, several tree species, several flower
## kinds, flowers on most islets; trees stand inside, apart, out of the
## water, and the glide rides over their crowns. Streamed round the eye they
## keep clear of the islands' spots, come back the same, go when far, never
## while perched on, ride the swaps' origin, are solids to the glide and can
## be walked on; their plants are drawn from the plate's catalog.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const IslandOutline = preload("res://scripts/island_outline.gd")
const Emergence = preload("res://scripts/emergence.gd")
var failures := 0

func _initialize() -> void:
	_same_seed()
	_outlines()
	_ground_over_stone()
	_weathered()
	_mesh_matches()
	_pond()
	_fall()
	_variety()
	_trees()
	_streaming()
	print("PASS: sky islets" if failures == 0 else "FAIL: sky islets")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## A sample of cells' islets, in a fixed order.
func _sample(count: int) -> Array:
	var found := []
	for x in range(-20,20):
		for z in range(-20,20):
			if found.size() >= count: return found
			var cell := Vector2i(x,z)
			if SkyIslets.raw(cell) != null: found.append(SkyIslet.make(SkyIslets.seed_of(cell)))
	return found

func _same_seed() -> void:
	var a: RefCounted = SkyIslet.make(4242)
	var b: RefCounted = SkyIslet.make(4242)
	var c: RefCounted = SkyIslet.make(4243)
	check(a.kind == b.kind and a.outline == b.outline and a.heights == b.heights and a.keel == b.keel and a.objects == b.objects,"A seed grows the same islet: outline, ground, rock and plants")
	check(a.outline != c.outline or a.heights != c.heights,"Another seed grows another")

func _outlines() -> void:
	var low := INF
	var high := 0.0
	var largest_area := 0.0
	var areas := 0.0
	var one_piece := true
	var clear_of_grid := true
	var lobed := 0
	var islets := _sample(80)
	for islet: RefCounted in islets:
		var box: Rect2 = islet.extent()
		var across := maxf(box.size.x,box.size.y)
		low = minf(low,across)
		high = maxf(high,across)
		var area: float = islet.land_area()
		largest_area = maxf(largest_area,area)
		areas += area
		# One piece: every land face reached from the middle's across edges.
		if _pieces(islet) != 1: one_piece = false
		for f: int in islet.land:
			for k in range(3):
				var p: Vector2 = islet.points[islet.ids[f*3+k]]
				if maxf(absf(p.x),absf(p.y)) > islet.half-0.01: clear_of_grid = false
		# Irregular: the rim's reach round the middle varies well beyond a
		# circle's, and bays leave the land well short of its bounding box.
		var reaches := []
		for i in range(48): reaches.append(islet.rim_radius(TAU*i/48.0))
		reaches.sort()
		if reaches[-1] > reaches[0]*1.35 and area < box.get_area()*0.85: lobed += 1
	check(low >= 5.0 and high <= 21.0,"Islets are 5 to 21 m across (%.1f to %.1f m)" % [low,high])
	var island_mean := 0.0
	for i in range(21): island_mean += IslandOutline.area_for(i/20.0)/21.0
	check(largest_area < IslandOutline.area_for(0.5) and areas/islets.size() < island_mean*0.3,"Clearly smaller than islands (largest %.0f m^2, mean %.0f m^2 against the islands' mean %.0f m^2)" % [largest_area,areas/islets.size(),island_mean])
	check(one_piece,"Each outline is one piece")
	check(clear_of_grid,"No land reaches its grid's edge")
	check(lobed >= islets.size()*0.85,"Outlines are irregular, lobed and bayed (%d of %d)" % [lobed,islets.size()])

## Land pieces joined across face edges.
func _pieces(islet: RefCounted) -> int:
	var edges := {}
	var faces: PackedInt32Array = islet.land
	var ids: PackedInt32Array = islet.ids
	for f in faces:
		for k in range(3):
			var a := ids[f*3+k]
			var b := ids[f*3+(k+1)%3]
			var key := Vector2i(mini(a,b),maxi(a,b))
			if not edges.has(key): edges[key] = []
			edges[key].append(f)
	var seen := {}
	var pieces := 0
	for f in faces:
		if seen.has(f): continue
		pieces += 1
		var stack := [f]
		seen[f] = true
		while not stack.is_empty():
			var g: int = stack.pop_back()
			for k in range(3):
				var a := ids[g*3+k]
				var b := ids[g*3+(k+1)%3]
				for h: int in edges[Vector2i(mini(a,b),maxi(a,b))]:
					if not seen.has(h):
						seen[h] = true
						stack.append(h)
	return pieces

func _ground_over_stone() -> void:
	var worst := INF
	var out_ok := true
	var deep_ok := true
	for islet: RefCounted in _sample(30):
		for i in range(48):
			var a := TAU*i/48.0
			var rim: float = islet.rim_radius(a)
			for f in [0.0,0.3,0.6,0.9,0.99]:
				var p: Vector2 = Vector2.from_angle(a)*rim*f
				worst = minf(worst,islet.ground_at(p)-islet.underside(p))
			if islet.inside(Vector2.from_angle(a)*(islet.reach+0.6)): out_ok = false
		# Inside is the outline's own faces.
		for f in range(0,islet.outline.size(),7):
			var ids: PackedInt32Array = islet.ids
			var middle: Vector2 = (islet.points[ids[f*3]]+islet.points[ids[f*3+1]]+islet.points[ids[f*3+2]])/3.0
			if islet.inside(middle) != (islet.outline[f] == 0): out_ok = false
		if islet.underside(Vector2.ZERO) > -islet.radius*0.6: deep_ok = false
	check(worst >= 1.0,"The ground stands over the rock everywhere (least %.2f m)" % worst)
	check(out_ok,"Inside is the outline's faces, and past its reach is off the land")
	check(deep_ok,"The rock hangs deep under the middle")

## Their edges are weathered, as the islands' land: the rim wanders and
## slumps, the erosion cuts gullies down to the shore and the walls slump
## out and overhang; at a spring's lip the wall stands back for its fall.
func _weathered() -> void:
	var islets := _sample(40)
	var ragged := 0
	var gullied := 0
	var slumped := 0
	for islet: RefCounted in islets:
		var low := INF
		var high := -INF
		var cut_shore := 0
		for k in range(0,islet.shore_edges.size(),3):
			var i: int = islet.shore_edges[k]
			low = minf(low,islet.heights[i])
			high = maxf(high,islet.heights[i])
			if islet.wear[i] > 0.12: cut_shore += 1
		if high-low > 0.35: ragged += 1
		if cut_shore >= 2: gullied += 1
		# The wall's facet ring: out past the rim in places, under it in others.
		var sides: PackedVector3Array = islet.side_arrays()[Mesh.ARRAY_VERTEX]
		var out_of_rim := 0
		for v in sides:
			if v.y > islet.base+0.2 and v.y < islet.heights[0]+5.0 and not islet.inside(Vector2(v.x,v.z)): out_of_rim += 1
		if out_of_rim > 20: slumped += 1
	check(ragged >= islets.size()*0.9,"The rim wanders and slumps, never one level (%d of %d)" % [ragged,islets.size()])
	check(gullied >= islets.size()*0.7,"Erosion cuts gullies down to the shore (%d of %d)" % [gullied,islets.size()])
	check(slumped >= islets.size()*0.9,"The walls slump out past the rim (%d of %d)" % [slumped,islets.size()])
	var clear := true
	for s in range(8):
		var spring: RefCounted = SkyIslet.make(31337+s*101,"spring")
		var lip := Vector3(spring.lip.x,0.0,spring.lip.y)
		var out := Vector3(spring.lip_out.x,0.0,spring.lip_out.y)
		# The wall's rings under the shore near the lip stand no further out
		# than LIP_CLEAR ahead of it, inside the overhang the fall clears
		# (SkyIslets `_fall_rings`).
		var outward: Dictionary = SkyIslets.IslandShore._outward(spring.points,spring.shore_edges)
		var slump := FastNoiseLite.new()
		for i: int in outward:
			if spring.points[i].distance_to(spring.lip) > 1.5: continue
			for v: Vector3 in spring._wall_rings(i,outward[i],slump):
				if (Vector3(v.x,0.0,v.z)-lip).dot(out) > SkyIslet.LIP_CLEAR+0.001: clear = false
	check(clear and SkyIslet.LIP_CLEAR < SkyIslets.IslandShore.RING_OUT.y+0.05,"At a spring's lip the wall stands back for the fall")

func _mesh_matches() -> void:
	for kind in ["meadow","grove","hills","crag","spring","shore"]:
		var islet: RefCounted = SkyIslet.make(900+kind.length()*31,kind)
		var arrays: Array = islet.top_arrays(SkyIslet.plain_palette())
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var up := 0
		var off := 0.0
		for t in range(0,v.size(),3):
			var face := (v[t+2]-v[t]).cross(v[t+1]-v[t])
			if face.y > 0.0: up += 1
			var mid := (v[t]+v[t+1]+v[t+2])/3.0
			off = maxf(off,absf(mid.y-islet.ground_at(Vector2(mid.x,mid.z))))
		check(up == v.size()/3 and up == islet.land.size(),"%s: one top face a land face, every one facing up (%d of %d)" % [kind,up,v.size()/3])
		check(off < 0.005,"%s: the top is where the glide reads it (off by %.4f m)" % [kind,off])
		var sides: Array = islet.side_arrays()
		var s: PackedVector3Array = sides[Mesh.ARRAY_VERTEX]
		var wrong := 0
		var down := 0
		var walls := 0
		for t in range(0,s.size(),3):
			var face := (s[t+2]-s[t]).cross(s[t+1]-s[t]).normalized()
			var mid := (s[t]+s[t+1]+s[t+2])/3.0
			if face.y < -0.3: down += 1
			elif absf(face.y) <= 0.3:
				walls += 1
				# A wall faces away from the land behind it: just out in front of
				# it is sky, just behind it land.
				var out := Vector2(face.x,face.z).normalized()
				var at := Vector2(mid.x,mid.z)
				if islet.inside(at+out*0.35) and not islet.inside(at-out*0.35): wrong += 1
			else: wrong += 1
		check(down >= islet.land.size()*0.85 and walls > 20 and wrong <= walls/20,"%s: the rock faces down, the walls out, none up (%d down, %d walls, %d wrong)" % [kind,down,walls,wrong])
		var box := AABB(s[0],Vector3.ZERO)
		for p in s: box = box.expand(p)
		check(box.position.y < -islet.depth+0.01 and box.size.x < islet.reach*2.0+1.0,"%s: the sides are the islet's size (%.1f across, %.1f deep)" % [kind,box.size.x,-box.position.y])

func _pond() -> void:
	var springs := 0
	var ok := true
	var dry_ok := true
	var reason := ""
	for s in range(12):
		var islet: RefCounted = SkyIslet.make(31337+s*101,"spring")
		var w: Dictionary = islet.water()
		if w.is_empty():
			ok = false
			reason = "no pond"
			continue
		springs += 1
		if not islet.ground_at(w.middle) < w.level-0.2:
			ok = false
			reason = "bed %.2f under %.2f" % [islet.ground_at(w.middle),w.level]
		var into := (w.lip as Vector2)-(w.out as Vector2)*0.2
		if not islet.ground_at(into) < w.level:
			ok = false
			reason = "channel %.2f at the lip" % islet.ground_at(into)
		var outside: Vector2 = (w.lip as Vector2)+(w.out as Vector2)*0.4
		if islet.inside(outside):
			ok = false
			reason = "the lip is not on the rim"
		var dry := 0
		var asked := 0
		for i in range(24):
			var p: Vector2 = (w.middle as Vector2)+Vector2.from_angle(TAU*i/24.0)*float(w.radius)*1.3
			if not islet.inside(p) or islet._channel_distance(p) < SkyIslet.CHANNEL*1.6: continue
			asked += 1
			if islet.ground_at(p) > w.level: dry += 1
		if dry < asked: dry_ok = false
	check(springs == 12,"Every spring islet has a pond")
	check(ok,"Each pond's bed lies under its water, and its channel runs under the water out to a lip on the rim (%s)" % ("ok" if reason == "" else reason))
	check(dry_ok,"Round each pond the bank stands over the water but at the channel")
	check(SkyIslet.make(5,"meadow").water().is_empty(),"A meadow has none")
	var mesh: ArrayMesh = SkyIslet.make(31337,"spring").build_water(null)
	check(mesh != null and mesh.get_aabb().size.y < 0.01,"The water is one flat level")

func _fall() -> void:
	var lip := Vector3(6.0,-0.14,0.0)
	var rings := SkyIslets.curtain(lip,Vector3.RIGHT,10.0,9.0,0.36,0.25,0.55)
	var points: PackedVector3Array = rings.points
	var falling := true
	for r in range(1,points.size()):
		if points[r].y > points[r-1].y+0.0001: falling = false
	check(falling,"The fall only ever falls")
	check(points[points.size()-1].y < lip.y-18.0,"It falls the sheet and its tail (%.1f m)" % (lip.y-points[points.size()-1].y))
	var clear := true
	for r in range(1,points.size()):
		if points[r].x < lip.x+0.25: clear = false
	check(clear,"It pours clear of the wall's lip")
	check(float(rings.break_from) > 9.0 and float(rings.break_length) > 5.0,"It breaks up below the sheet (from %.1f m, over %.1f m)" % [rings.break_from,rings.break_length])
	var spring: RefCounted = SkyIslet.make(31337,"spring")
	var made: Dictionary = SkyIslets._fall_rings(spring)
	var first: Vector3 = (made.points as PackedVector3Array)[0]
	check(Vector2(first.x,first.z).distance_to(spring.lip) < 0.2 and is_equal_approx(first.y,SkyIslet.WATER),"A spring's fall leaves from its lip at the water's level")

func _variety() -> void:
	var kinds := {}
	var species := {}
	var flowers := {}
	var with_flowers := 0
	var bare := 0
	var trees_by_kind := {}
	var islets := _sample(150)
	for islet: RefCounted in islets:
		kinds[islet.kind] = int(kinds.get(islet.kind,0))+1
		for s in islet.species: species[s] = true
		for f in islet.flowers: flowers[f] = true
		if not islet.flowers.is_empty(): with_flowers += 1
		if islet.objects.size() < 5: bare += 1
		var trees := 0
		for item: Dictionary in islet.objects:
			if item.asset in Emergence.TREES: trees += 1
		trees_by_kind[islet.kind] = (trees_by_kind.get(islet.kind,[]) as Array)+[trees]
	check(kinds.size() == SkyIslet.KINDS.size(),"Every kind of ground turns up across the cells (%s)" % str(kinds))
	check(species.size() >= 5,"Several tree species stand on them (%s)" % ", ".join(species.keys()))
	check(flowers.size() >= 5,"Several kinds of flower bloom on them (%s)" % ", ".join(flowers.keys()))
	check(with_flowers >= islets.size()*0.55,"Most islets carry flowers (%d of %d)" % [with_flowers,islets.size()])
	check(bare == 0,"Every islet grows something (%d nearly bare)" % bare)
	var mean := func(list: Array) -> float:
		var total := 0.0
		for v in list: total += float(v)
		return total/maxf(list.size(),1.0)
	check(mean.call(trees_by_kind.grove) > mean.call(trees_by_kind.meadow)*2.0,"A grove is a wood, a meadow open (%.1f trees against %.1f)" % [mean.call(trees_by_kind.grove),mean.call(trees_by_kind.meadow)])
	var meadows_bloom := true
	for islet: RefCounted in islets:
		if islet.kind == "meadow" and islet.flowers.is_empty(): meadows_bloom = false
	check(meadows_bloom,"Every meadow blooms")
	var beach := SkyIslet.make(77,"shore")
	var colours: PackedColorArray = beach.top_arrays(SkyIslet.plain_palette())[Mesh.ARRAY_COLOR]
	var sandy := 0
	var sand: Color = SkyIslet.plain_palette().sand
	for c in colours:
		if absf(c.r-sand.r) < 0.05 and absf(c.g-sand.g) < 0.05: sandy += 1
	check(sandy > colours.size()/10,"A shore islet is ringed with sand (%d of %d)" % [sandy,colours.size()])
	var crag := SkyIslet.make(77,"crag")
	var rocky := 0
	for f: int in crag.land:
		if crag._slope(f) > SkyIslet.plain_palette().rock_slope: rocky += 1
	check(rocky > crag.land.size()/8,"A crag stands in rock (%d of %d faces)" % [rocky,crag.land.size()])

func _trees() -> void:
	var catalog: Dictionary = SkyIslets.catalog().data
	var ok := true
	var crowns_ok := true
	var any := 0
	var reason := ""
	for islet: RefCounted in _sample(60):
		islet.flora(catalog)
		var trees := []
		for item: Dictionary in islet.objects:
			if not item.asset in Emergence.TREES: continue
			var at := Vector2(item.x,item.z)
			trees.append(at)
			any += 1
			if not islet.inside(at) or islet.inland(at) < SkyIslet.TREE_IN-0.01:
				ok = false
				reason = "too near the shore"
			if islet.wet(at):
				ok = false
				reason = "in the water"
		for i in range(trees.size()):
			for j in range(i):
				if (trees[i] as Vector2).distance_to(trees[j]) < SkyIslet.TREE_APART*0.6:
					ok = false
					reason = "crowded"
		for c: Vector4 in islet.crowns:
			if islet.solid_top(Vector2(c.x,c.y)) < islet.ground_at(Vector2(c.x,c.y))+c.z-0.01: crowns_ok = false
		if islet.crowns.size() < trees.size(): crowns_ok = false
	check(any > 120,"Islets carry trees (%d on 60)" % any)
	check(ok,"Trees stand inside, in from the shore, apart and out of the water (%s)" % ("ok" if reason == "" else reason))
	check(crowns_ok,"Every tree and stone has a crown the glide rides over")

func _streaming() -> void:
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var eye := Vector3(150.0,0.0,150.0)
	for i in range(240):
		islets.advance(1.0/60.0,eye)
		islets.flush()
	var count: int = islets.islet_count()
	check(count >= 8,"Islets grow round the eye (%d)" % count)
	var near_island := false
	var far := false
	for key in islets.built:
		var b: Dictionary = islets.built[key]
		var home: Vector3 = b.home
		if not cells.spots_near(home,SkyIslets.CLEAR).is_empty(): near_island = true
		if Vector2(home.x-eye.x,home.z-eye.z).length() > SkyIslets.VIEW: far = true
	check(not near_island,"None stands near an island's spot")
	check(not far,"None is built beyond VIEW")
	# Their plants are the plate's own, drawn safe for the sky.
	var batches := 0
	var safe := true
	var meshes: Dictionary = SkyIslets.catalog().meshes
	for key in islets.built:
		for child in (islets.built[key].node as Node3D).get_children():
			if not child is MultiMeshInstance3D: continue
			batches += 1
			var batch := child as MultiMeshInstance3D
			if not batch.multimesh.mesh in meshes.values(): safe = false
			var m := batch.material_override as ShaderMaterial
			if m != null and (m.get_shader_parameter("instance_birth_enabled") == true or m.get_shader_parameter("plant_growth") == true): safe = false
	check(batches > count*3,"Their plants stand as batches of the catalog's own meshes (%d batches)" % batches)
	check(safe,"No plant reads the plate's births or growth")
	# A solid to the glide: over one, the ground and the stone.
	var any: Dictionary = islets.built.values()[0]
	var node: Node3D = any.node
	var over: Vector3 = islets.place(any)+Vector3.UP*20.0
	var body: Variant = islets.body(over)
	check(body is Vector2 and (body as Vector2).x > (body as Vector2).y,"Over an islet it is a solid with a top and an underside")
	var glide := SkyGlide.new()
	glide.launch(islets.place(any)+Vector3(0.0,4.0,0.0),0.0,4.0,false)
	var lowest := INF
	for i in range(240):
		glide.step(1.0/60.0,{"dive":1.0},Callable(islets,"body"))
		var here: Variant = islets.body(glide.position)
		if here != null: lowest = minf(lowest,glide.position.y-(here as Vector2).x)
	check(lowest > -0.05 or lowest == INF,"A dive onto one skims, never sinks in (%.2f m)" % lowest)
	# Walking it: the middle is land, a trunk blocks, the rim is the edge.
	var shape: RefCounted = any.shape
	check(SkyIslets.blocked(shape,Vector2(-999.0,0.0)) == false and shape.inside(Vector2.ZERO) and shape.share(Vector2.ZERO) == 0.0,"Its middle is land a walker stands on")
	var trunk_ok := true
	for b: Vector3 in shape.blocks:
		if not SkyIslets.blocked(shape,Vector2(b.x,b.y)): trunk_ok = false
	check(trunk_ok,"Trunks and stones block a walker")
	var perched: Dictionary = islets.islet_at(islets.place(any)+Vector3.UP*2.0)
	check(not perched.is_empty() and perched.node == node,"The islet under a point is found for a perch")
	# The same cell grows the same islet.
	var key: String = islets.built.keys()[0]
	var built_shape: RefCounted = islets.built[key].shape
	var cell: Vector2i = islets.built[key].cell
	var again: RefCounted = SkyIslet.make(SkyIslets.seed_of(cell))
	check(again.outline == built_shape.outline and again.objects == built_shape.objects,"A cell always grows the same islet")
	# A swap: the origin moves, the islets with it.
	var before: Vector3 = islets.place(any)
	cells.origin += Vector3(-200.0,0.0,50.0)
	islets.advance(0.0,eye+Vector3(-200.0,0.0,50.0))
	var moved: Vector3 = islets.place(any)-before
	check(Vector2(moved.x,moved.z).distance_to(Vector2(-200.0,50.0)) < 0.01,"They ride the swaps' origin")
	# Far off, they go; the pinned one stays.
	islets.pinned = node
	var away := eye+Vector3(5000.0,0.0,5000.0)+cells.origin
	for i in range(60): islets.advance(1.0/60.0,away)
	var kept := false
	var old := 0
	for k in islets.built:
		if islets.built[k].node == node: kept = true
		if Vector2((islets.built[k].home as Vector3).x-eye.x,(islets.built[k].home as Vector3).z-eye.z).length() < SkyIslets.VIEW: old += 1
	check(kept,"The islet perched on is never let go")
	check(old == 1,"The rest far behind are let go (%d left)" % old)
	islets.free()
