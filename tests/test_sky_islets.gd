extends SceneTree
## The sky islets (scripts/sky_islet.gd, scripts/sky_islets.gd):
## a seed always grows the same islet; its ground sits over its stone, the
## mesh is what the queries say and faces outward; a spring's pond lies in
## its bowl with a channel to the lip, and its fall pours off clear of the
## rim; trees stand inside, apart and out of the water. Streamed round the
## eye they keep clear of the islands' spots, come back the same, go when
## far, never while perched on, ride the swaps' origin and are solids to the
## glide.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
var failures := 0

func _initialize() -> void:
	_same_seed()
	_kinds()
	_ground_over_stone()
	_mesh_matches()
	_pond()
	_fall()
	_trees()
	_streaming()
	print("PASS: sky islets" if failures == 0 else "FAIL: sky islets")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _same_seed() -> void:
	var a: RefCounted = SkyIslet.make(4242)
	var b: RefCounted = SkyIslet.make(4242)
	var c: RefCounted = SkyIslet.make(4243)
	check(a.kind == b.kind and a.rim == b.rim and a.trees == b.trees and is_equal_approx(a.depth,b.depth),"A seed grows the same islet")
	check(a.rim != c.rim,"Another seed grows another")

func _kinds() -> void:
	var seen := {}
	for s in range(200): seen[SkyIslet.make(s*7919).kind] = true
	check(seen.size() == SkyIslet.KINDS.size(),"Every kind turns up (%s)" % ", ".join(seen.keys()))

func _ground_over_stone() -> void:
	var worst := INF
	var out_ok := true
	for s in range(40):
		var islet: RefCounted = SkyIslet.make(s*131+5)
		for i in range(60):
			var a := TAU*i/60.0
			for f in [0.0,0.3,0.6,0.9,0.99]:
				var p: Vector2 = Vector2.from_angle(a)*islet.rim_radius(a)*f
				worst = minf(worst,islet.top(p)-islet.underside(p))
			if islet.inside(Vector2.from_angle(a)*islet.rim_radius(a)*1.05): out_ok = false
	check(worst >= SkyIslet.EARTH_FOOT-SkyIslet.BOWL,"The ground stands over the stone everywhere (least %.2f m)" % worst)
	check(out_ok,"Just past the rim is outside")
	var islet: RefCounted = SkyIslet.make(77,"grove")
	check(islet.underside(Vector2.ZERO) < -islet.radius,"The stone hangs deep under the middle (%.1f m, radius %.1f)" % [islet.underside(Vector2.ZERO),islet.radius])

func _mesh_matches() -> void:
	for kind in ["grove","spring","crag","tuft"]:
		var islet: RefCounted = SkyIslet.make(900+kind.length(),kind)
		var mesh: ArrayMesh = islet.build_mesh([Color(0.2,0.4,0.1)],[Color(0.4,0.4,0.4)],null)
		var arrays := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var wound := 0
		var off := 0.0
		var up_faces := 0
		var down_faces := 0
		for t in range(0,v.size(),3):
			var face := (v[t+2]-v[t]).cross(v[t+1]-v[t])
			if face.dot(n[t]) > 0.0: wound += 1
			var mid := (v[t]+v[t+1]+v[t+2])/3.0
			var at := Vector2(mid.x,mid.z)
			if n[t].y > 0.5 and islet.share(at) < 0.95:
				up_faces += 1
				if islet.spire.w == 0.0: off = maxf(off,absf(mid.y-islet.ground_at(at)))
			if n[t].y < -0.3: down_faces += 1
		check(wound == v.size()/3,"%s: every face is wound to face out (%d of %d)" % [kind,wound,v.size()/3])
		check(up_faces > 50 and down_faces > 50,"%s: a top facing up and stone facing down (%d, %d)" % [kind,up_faces,down_faces])
		if islet.spire.w == 0.0: check(off < 0.005,"%s: the top is where the glide reads it (off by %.4f m)" % [kind,off])
		var box := mesh.get_aabb()
		check(box.size.x < islet.radius*2.8 and box.position.y < -islet.depth*0.5,"%s: the mesh is the islet's size (%.1f across, %.1f deep)" % [kind,box.size.x,-box.position.y])

func _pond() -> void:
	var islet: RefCounted = SkyIslet.make(31337,"spring")
	var w: Dictionary = islet.water()
	check(not w.is_empty(),"A spring islet has a pond")
	check(islet.top(w.middle) < w.level-0.2,"The pond's bed lies under its water (%.2f under %.2f)" % [islet.top(w.middle),w.level])
	var into := (w.lip as Vector2)-(w.out as Vector2)*0.2
	check(islet.top(into) < w.level,"The channel runs under the water out to the lip (%.2f)" % islet.top(into))
	var dry := 0
	for i in range(24):
		var p: Vector2 = (w.middle as Vector2)+Vector2.from_angle(TAU*i/24.0)*float(w.radius)*1.6
		if islet.inside(p) and islet._channel_distance(p) > SkyIslet.CHANNEL*1.5 and islet.top(p) > w.level: dry += 1
	check(dry > 8,"Round the pond the bank stands over the water (%d dry)" % dry)
	check(SkyIslet.make(5,"grove").water().is_empty(),"A grove has none")
	var mesh: ArrayMesh = islet.build_water(null)
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
	check(clear,"It pours clear of the grass lip")
	check(float(rings.break_from) > 9.0 and float(rings.break_length) > 5.0,"It breaks up below the sheet (from %.1f m, over %.1f m)" % [rings.break_from,rings.break_length])

func _trees() -> void:
	var ok := true
	var any := 0
	for s in range(60):
		var islet: RefCounted = SkyIslet.make(s*977+3)
		any += islet.trees.size()
		for i in range(islet.trees.size()):
			var t: Vector4 = islet.trees[i]
			var at := Vector2(t.x,t.y)
			if islet.share(at) > SkyIslet.TREE_IN+0.01: ok = false
			if SkyIslets.blocked(islet,at+Vector2(0.5,0.0)) and islet.pond.z > 0.0 and at.distance_to(Vector2(islet.pond.x,islet.pond.y)) < islet.pond.z: ok = false
			for j in range(i):
				if at.distance_to(Vector2(islet.trees[j].x,islet.trees[j].y)) < SkyIslet.TREE_APART: ok = false
		var crown: Vector4 = islet.trees[0] if not islet.trees.is_empty() else Vector4.ZERO
		if crown.z > 0.0 and islet.solid_top(Vector2(crown.x,crown.y)) < islet.top(Vector2(crown.x,crown.y))+crown.z-0.01: ok = false
	check(any > 60,"Islets carry trees (%d on 60)" % any)
	check(ok,"Trees stand inside, apart, out of the pond, and the glide rides over their crowns")

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
	# The same cell grows the same islet.
	var key: String = islets.built.keys()[0]
	var shape: RefCounted = islets.built[key].shape
	var cell: Vector2i = islets.built[key].cell
	check(SkyIslet.make(SkyIslets.seed_of(cell)).rim == shape.rim,"A cell always grows the same islet")
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
