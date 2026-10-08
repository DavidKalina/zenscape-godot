extends SceneTree
## The cliffs landform (scripts/landform_cliffs.gd, shaped by scripts/
## sea_cliffs.gd): the lower world's contract (NAME, ACROSS, `recipe`); a
## seed and width always make the same island; the tableland stands well
## over the sea, the cove's beach comes down to it, the stacks stand apart
## off the cliffs and an arch's span is open from the sea to its crown;
## every shore point's wall runs unbroken from its rim to its foot, rings
## going down; and an island is made (shape, top, walls, plants) within its
## budget, its faces counted.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Cliffs = preload("res://scripts/landform_cliffs.gd")
const SeaCliffs = preload("res://scripts/sea_cliffs.gd")
## Seeds and widths tried, and the build budget (ms, shape and arrays) for
## the widest.
const SEEDS := [11,23,37,58,71,94]
const WIDTHS := [30.0,55.0,90.0]
const BUDGET_MS := 1500.0
var failures := 0

func _initialize() -> void:
	_contract()
	_same_seed()
	var arches := 0
	var coves := 0
	for across: float in WIDTHS:
		for s: int in SEEDS:
			var islet := _make(s,across)
			_heights(islet,s,across)
			_stacks(islet,s,across)
			_walls(islet,s,across)
			if not (islet.cliffs.arch as Dictionary).is_empty(): arches += 1
			if float(islet.cliffs.cove_reach) > 0.0: coves += 1
	check(arches > 0,"Some islands stand an arch (%d of %d)" % [arches,SEEDS.size()*WIDTHS.size()])
	check(coves > SEEDS.size(),"Most islands come down to a cove (%d of %d)" % [coves,SEEDS.size()*WIDTHS.size()])
	_budget()
	print("PASS: landform cliffs" if failures == 0 else "FAIL: landform cliffs")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _make(seed_value: int, across: float) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SkyIslet.author(seed_value,Cliffs.recipe(rng,across))

func _contract() -> void:
	check(Cliffs.NAME == "cliffs","The landform is named cliffs")
	check(Cliffs.ACROSS.x >= 20.0 and Cliffs.ACROSS.y <= 100.0 and Cliffs.ACROSS.x < Cliffs.ACROSS.y,"Its width range is %s m" % Cliffs.ACROSS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r: Dictionary = Cliffs.recipe(rng,60.0)
	check(r.has("cliffs") and r.has("kind") and SkyIslet.ACROSS.has(r.kind),"Its recipe is a SkyIslet recipe with cliffs")

func _same_seed() -> void:
	var a := _make(4242,60.0)
	var b := _make(4242,60.0)
	var c := _make(4243,60.0)
	check(a.outline == b.outline and a.heights == b.heights and a.keel == b.keel and a.objects == b.objects
		and a.side_arrays()[Mesh.ARRAY_VERTEX] == b.side_arrays()[Mesh.ARRAY_VERTEX],"A seed and width make the same island")
	check(a.heights != c.heights,"Another seed makes another")

func _heights(islet: RefCounted, s: int, across: float) -> void:
	var cliffs: RefCounted = islet.cliffs
	var top := -INF
	var low_rim := INF
	for i in range(islet.points.size()):
		if islet.shore_distance[i] < 0.0: continue
		top = maxf(top,islet.heights[i])
	for k in range(0,islet.shore_edges.size(),3): low_rim = minf(low_rim,islet.heights[islet.shore_edges[k]])
	var want: float = cliffs.high
	check(top > want*0.8 and top < want*1.6+2.0 and want >= Cliffs.CLIFF.x*0.8,"%d m %d: the tableland stands %.1f m over the sea (cliff %.1f m)" % [across,s,top,want])
	if float(cliffs.cove_reach) > 0.0:
		check(low_rim < SeaCliffs.SEA+1.5,"%d m %d: the cove comes down to the sea (%.2f m)" % [across,s,low_rim])

func _stacks(islet: RefCounted, s: int, across: float) -> void:
	var cliffs: RefCounted = islet.cliffs
	for k in range(cliffs.stacks.size()):
		var st: Vector4 = cliffs.stacks[k]
		var middle := Vector2(st.x,st.y)
		var on: bool = islet.on_land(middle)
		var y: float = islet.ground_at(middle)
		check(on and absf(y-st.w) < 1.5,"%d m %d: stack %d stands %.1f m up at its middle (%.1f m)" % [across,s,k,y,st.w])
		if not cliffs.arch.is_empty() and k == int(cliffs.arch.stack): continue
		# Open water between it and the cliff, toward the middle.
		var way := -middle.normalized()
		var gap := middle+way*(st.z*(1.0+SeaCliffs.STACK_LOBE)+1.5)
		check(not islet.on_land(gap),"%d m %d: open sea between stack %d and the cliff" % [across,s,k])
	if cliffs.arch.is_empty(): return
	var arch: Dictionary = cliffs.arch
	var mid: Vector2 = (arch.from as Vector2)+(arch.out as Vector2)*float(arch.span)*0.5
	var under: float = islet.underside(mid)
	var over: float = islet.ground_at(mid)
	check(islet.on_land(mid) and under > SeaCliffs.SEA+3.0 and over > under+2.0,"%d m %d: the arch's span is open to %.1f m under a %.1f m roof" % [across,s,under,over-under])

## Every shore point's column runs from its rim down to its foot, rings
## going down, so the stitched wall has no gaps; and the wall's faces are
## counted.
func _walls(islet: RefCounted, s: int, across: float) -> void:
	var cliffs: RefCounted = islet.cliffs
	var outward: Dictionary = preload("res://scripts/island_shore.gd")._outward(islet.points,islet.shore_edges)
	var bad := 0
	for i: int in outward:
		var col: Array = cliffs._column(islet,i,outward[i])
		var first: Vector3 = col[0]
		var last: Vector3 = col[col.size()-1]
		if absf(first.y-islet.heights[i]) > 0.001 or absf(last.y-(islet.base-islet.keel[i])) > 0.001: bad += 1
		for r in range(1,col.size()):
			if (col[r] as Vector3).y >= (col[r-1] as Vector3).y: bad += 1
	check(bad == 0,"%d m %d: every wall runs rim to foot, down all the way (%d bad)" % [across,s,bad])
	var sides: Array = islet.side_arrays()
	var verts: PackedVector3Array = sides[Mesh.ARRAY_VERTEX]
	var degenerate := 0
	for v in range(0,verts.size(),3):
		if (verts[v+2]-verts[v]).cross(verts[v+1]-verts[v]).length() < 1.0e-6: degenerate += 1
	check(degenerate*20 < verts.size()/3,"%d m %d: few degenerate wall faces (%d of %d)" % [across,s,degenerate,verts.size()/3])

## The widest islands made within the budget: shape, top, walls, plants.
func _budget() -> void:
	var catalog := SkyIslets.catalog()
	var palette := SkyIslet.plain_palette()
	for across: float in WIDTHS:
		var worst := 0.0
		var faces := Vector2i.ZERO
		var plants := 0
		for s: int in SEEDS.slice(0,3):
			var began := Time.get_ticks_usec()
			var islet := _make(s,across)
			var shaped := Time.get_ticks_usec()
			var top: Array = islet.top_arrays(palette)
			var sides: Array = islet.side_arrays()
			var drawn := Time.get_ticks_usec()
			var flora: Dictionary = islet.flora(catalog.data)
			var done := Time.get_ticks_usec()
			worst = maxf(worst,(drawn-began)/1000.0)
			faces = Vector2i((top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,(sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3)
			plants = 0
			for key: String in flora: plants += int(flora[key].count)
			print("     %d m seed %d: step %.2f m, shape %.0f ms, arrays %.0f ms, plants %.0f ms; %d top + %d wall faces, %d plant instances, %d stacks, arch %s" % [
				across,s,islet.step,(shaped-began)/1000.0,(drawn-shaped)/1000.0,(done-drawn)/1000.0,faces.x,faces.y,plants,islet.cliffs.stacks.size(),not islet.cliffs.arch.is_empty()])
		check(worst < BUDGET_MS*across/Cliffs.ACROSS.y+200.0,"%d m: made within its budget (worst %.0f ms)" % [across,worst])
		check(faces.x+faces.y < 40000,"%d m: %d faces" % [across,faces.x+faces.y])
