extends SceneTree
## A floating island's fall carried down to the cloud sea (scripts/
## sky_fall_thread.gd): the thread reaches into the sea, with no gap between
## its rows and none to the strand it takes over from; it only ever falls,
## widens as it goes, fades in over the strand's break and never thins out
## on the way, only melting away at the sea; its bloom stands at the foot;
## a seed always makes the same one; it stays a small mesh; and a spring
## islet's fall carries one.
const SkyFallThread = preload("res://scripts/sky_fall_thread.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
var failures := 0

func _initialize() -> void:
	var lip := Vector3(6.0,-0.14,2.0)
	var out := Vector3(0.6,0.0,0.8)
	var home_y := 30.0
	var sea := SkyFallThread.SEA-home_y
	var from := 12.0
	var p := SkyFallThread.plan(lip,out,0.36,sea,4242,from,1.4,0.5)
	_reaches(p,lip,sea)
	_continuous(p,lip,out,from)
	_tapers(p,lip,sea,from)
	_bloom(p,sea)
	_same_seed(p,lip,out,sea,from)
	_bounded(lip,out)
	_on_islets()
	print("PASS: sky fall thread" if failures == 0 else "FAIL: sky fall thread")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _reaches(p: Dictionary, lip: Vector3, sea: float) -> void:
	var points: PackedVector3Array = p.points
	var bottom := points[points.size()-1]
	check(bottom.y <= sea and bottom.y >= sea-SkyFallThread.DIP-0.01,"It runs down into the sea's top (foot %.1f m, sea %.1f m)" % [bottom.y,sea])
	var bounds: AABB = p.bounds
	check(bounds.has_point(lip+Vector3.DOWN*13.0) and bounds.position.y < sea-SkyFallThread.DIP,"Its box holds it from the strand down to below the sea")

func _continuous(p: Dictionary, lip: Vector3, out: Vector3, from: float) -> void:
	var points: PackedVector3Array = p.points
	var falling := true
	var worst := 0.0
	for r in range(1,points.size()):
		if points[r].y >= points[r-1].y: falling = false
		worst = maxf(worst,points[r].distance_to(points[r-1]))
	check(falling,"It only ever falls")
	check(worst <= SkyFallThread.MAX_STEP,"No gap between its rows (longest step %.2f m)" % worst)
	# The top row is above where it takes over, on the strand's own line.
	var top := points[0]
	check(top.y >= lip.y-from+SkyFallThread.FADE_IN-0.01,"It starts above the strand's break (%.1f m under the lip)" % (lip.y-top.y))
	check(top.distance_to(SkyFallThread.point(lip,out.normalized(),lip.y-top.y,1.4,0.5)) < 0.01,"On the strand's line")
	var clear := true
	for q in points:
		if Vector2(q.x-lip.x,q.z-lip.z).dot(Vector2(out.x,out.z).normalized()) < 0.5-0.001: clear = false
	check(clear,"Clear of the lip all the way down")
	# The mesh's ribbon is the rows, two a row, indices all in range.
	var arrays: Array = p.arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ribbon := true
	for r in range(points.size()):
		if not vertices[r*2].is_equal_approx(points[r]) or not vertices[r*2+1].is_equal_approx(points[r]): ribbon = false
	var in_range := indices.size()%3 == 0
	for i in indices: if i < 0 or i >= vertices.size(): in_range = false
	check(ribbon and in_range,"The mesh's ribbon is its rows, every row joined")
	# Each pair of rows shares a quad: the ribbon's triangles join every row.
	var joined := 0
	for r in range(1,points.size()):
		var a := (r-1)*2
		for t in range(0,indices.size(),3):
			var tri := [indices[t],indices[t+1],indices[t+2]]
			if tri.has(a) and tri.has(a+2):
				joined += 1
				break
	check(joined == points.size()-1,"Every row is joined to the next (%d of %d)" % [joined,points.size()-1])

func _tapers(p: Dictionary, lip: Vector3, sea: float, from: float) -> void:
	var points: PackedVector3Array = p.points
	var halves: PackedFloat32Array = p.halves
	var alphas: PackedFloat32Array = p.alphas
	var widening := true
	for r in range(1,halves.size()):
		if halves[r] < halves[r-1]-0.0001: widening = false
	check(widening,"It widens as it falls (%.2f m to %.2f m half width)" % [halves[0],halves[halves.size()-1]])
	check(halves[halves.size()-1] > halves[0]*3.0 and halves[halves.size()-1] < 12.0,"Into a soft veil a few metres wide, not a wall")
	check(alphas[0] < 0.2,"It fades in over the strand's break (%.2f at the top)" % alphas[0])
	var fading := true
	var low_air := 1.0
	for r in range(points.size()):
		var d := lip.y-points[r].y
		if d < from+SkyFallThread.FADE_OVER: continue
		if r > 0 and lip.y-points[r-1].y >= from+SkyFallThread.FADE_OVER and alphas[r] > alphas[r-1]+0.0001: fading = false
		if points[r].y > sea+SkyFallThread.MELT: low_air = minf(low_air,alphas[r])
	check(fading,"Past the break it only ever softens")
	check(low_air >= SkyFallThread.VEIL_ALPHA*0.95,"It never thins out in the air (least %.2f above the sea)" % low_air)
	check(alphas[alphas.size()-1] < 0.01,"It melts away only into the sea (%.3f at the foot)" % alphas[alphas.size()-1])
	var at_sea := SkyFallThread.alpha_at(lip.y-sea,from,lip.y,sea)
	check(at_sea > 0.1,"Still there where it meets the sea's top (%.2f)" % at_sea)

func _bloom(p: Dictionary, sea: float) -> void:
	var foot: Vector3 = p.foot
	check(absf(foot.y-sea) < 0.01,"The bloom stands where it meets the sea")
	var arrays: Array = p.arrays
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var puffs := 0
	var near := true
	for i in range(int(p.rows)*2,vertices.size(),4):
		if uv2[i].x >= 0.0: continue
		puffs += 1
		if vertices[i].distance_to(foot) > 20.0: near = false
	check(puffs == int(p.puffs) and near,"Its puffs (%d) gather at the foot" % puffs)

func _same_seed(p: Dictionary, lip: Vector3, out: Vector3, sea: float, from: float) -> void:
	var again := SkyFallThread.plan(lip,out,0.36,sea,4242,from,1.4,0.5)
	var other := SkyFallThread.plan(lip,out,0.36,sea,4243,from,1.4,0.5)
	var a: Array = p.arrays
	var b: Array = again.arrays
	var c: Array = other.arrays
	check(a[Mesh.ARRAY_VERTEX] == b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_COLOR] == b[Mesh.ARRAY_COLOR] and a[Mesh.ARRAY_TEX_UV2] == b[Mesh.ARRAY_TEX_UV2],"A seed makes the same thread")
	check(a[Mesh.ARRAY_VERTEX] != c[Mesh.ARRAY_VERTEX],"Another seed blooms otherwise")
	check(p.points == other.points,"The seed moves only the bloom, never the line")

func _bounded(lip: Vector3, out: Vector3) -> void:
	var most := 0
	var ok := true
	for drop in [40.0,90.0,150.0,260.0]:
		var p := SkyFallThread.plan(lip,out,0.36,lip.y-drop,7,10.0,1.4,0.5)
		var vertices: PackedVector3Array = p.arrays[Mesh.ARRAY_VERTEX]
		most = maxi(most,vertices.size())
		var points: PackedVector3Array = p.points
		for r in range(1,points.size()):
			if points[r].distance_to(points[r-1]) > SkyFallThread.MAX_STEP: ok = false
	check(most <= 160,"A small mesh, whatever the drop (at most %d vertices)" % most)
	check(ok,"No gaps even on the longest drop")
	var node := SkyFallThread.build(lip,out,0.36,lip.y-120.0,7,10.0)
	check(node.mesh != null and node.mesh.get_surface_count() == 1 and node.material_override != null,"One mesh, one draw")
	node.free()

func _on_islets() -> void:
	var cells := SkyCells.new([Vector3.ZERO])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var found := 0
	var reaching := true
	var cell := Vector2i(0,0)
	var tried := 0
	while found < 3 and tried < 4000:
		cell = Vector2i(tried%60-30,tried/60-30)
		tried += 1
		var home: Variant = SkyIslets.raw(cell)
		if home == null: continue
		var shape: RefCounted = SkyIslet.make(SkyIslets.seed_of(cell))
		if shape.water().is_empty(): continue
		islets._build(cell,home)
		var node: Node3D = islets.built[islets._key(cell)].node
		var thread: MeshInstance3D = node.get_node_or_null("FallThread")
		var fall: Node = node.get_node_or_null("Fall")
		if thread == null or fall == null:
			reaching = false
			found += 1
			continue
		var low := (thread.custom_aabb as AABB).position.y+node.position.y
		if low > SkyFallThread.SEA-SkyFallThread.DIP: reaching = false
		found += 1
	check(found >= 3 and reaching,"A spring islet's fall carries its thread down to the sea (%d islets)" % found)
	islets.free()
