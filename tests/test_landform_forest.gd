extends SceneTree
## suite: serial
## The forest landform (scripts/landform_forest.gd, scripts/forest_canopy.gd,
## scripts/islet_stream.gd, scripts/far_trees.gd): its contract as the
## lower world registers it (NAME, ACROSS, `recipe`); over a few seeds at
## the narrowest, middle and widest widths its islands (SkyIslet `author`)
## are the same from the same seed, wooded (a canopy, not a few trees),
## every tree on dry land, a clearing open of trunks and a glade or more,
## spruce on the high ground and birch lower, a stream on the wide ones
## running down to the shore with its water falling all the way, and a
## shaded floor; the plants within an instance and triangle budget, the far
## stand-ins a few faces a part; and each island built in good time.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Forest = preload("res://scripts/landform_forest.gd")
const FarTrees = preload("res://scripts/far_trees.gd")
const Woodland = preload("res://scripts/woodland.gd")
const SEEDS := [4100,12019,19938]
const TREES := ["tree","birch","redwood","juniper","broadleaf","willow","layered_tree"]
## The budgets: trees a square metre at most and at least, instances on the
## widest island, its trees' triangles near and as stand-ins, a stand-in
## part's triangles, and a build (shape, arrays, flora; ms, generous for a
## loaded machine).
const DENSITY := Vector2(0.08,0.2)
const INSTANCES := 4500
const NEAR_TRIANGLES := 1200000
const FAR_TRIANGLES := 60000
const PART_TRIANGLES := 40
const BUDGET_MS := 3500.0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _make(seed_value: int, across: float) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SkyIslet.author(seed_value,Forest.recipe(rng,across))

func _triangles(mesh: Mesh) -> int:
	var n := 0
	for s in range(mesh.get_surface_count()):
		var a := mesh.surface_get_arrays(s)
		var index: Variant = a[Mesh.ARRAY_INDEX]
		n += (index.size() if index != null and (index as PackedInt32Array).size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3
	return n

func _run() -> void:
	check(Forest.NAME == "forest","The landform is named forest")
	check(Forest.ACROSS.x >= 25.0 and Forest.ACROSS.y <= 100.0 and Forest.ACROSS.x < Forest.ACROSS.y,"Its width range is %s m" % Forest.ACROSS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var spec: Dictionary = Forest.recipe(rng,60.0)
	check(spec.get("kind") == "grove" and spec.has("forest") and float(spec.radius) == 30.0,"Its recipe is a SkyIslet's, a grove planted as a forest")
	var catalog: Dictionary = SkyIslets.catalog()
	var tri := {}
	for key: String in catalog.meshes:
		if catalog.meshes[key] is Mesh: tri[key] = _triangles(catalog.meshes[key])
	var widths := [Forest.ACROSS.x,lerpf(Forest.ACROSS.x,Forest.ACROSS.y,0.5),Forest.ACROSS.y]
	var same := true
	var dry := true
	var sparse: Array = []
	var no_clearing: Array = []
	var cluttered: Array = []
	var streams := 0
	var stream_bad: Array = []
	var high_spruce := 0.0
	var high_birch := 0.0
	var spruces := 0
	var birches := 0
	var slowest := 0.0
	var widest := {"instances":0,"near":0,"far":0}
	var shaded := true
	for across: float in widths:
		for s: int in SEEDS:
			var began := Time.get_ticks_usec()
			var islet: RefCounted = _make(s,across)
			islet.top_arrays(SkyIslet.plain_palette())
			islet.side_arrays()
			islet.water_arrays()
			var plants: Dictionary = islet.flora(catalog.data)
			slowest = maxf(slowest,(Time.get_ticks_usec()-began)/1000.0)
			var again: RefCounted = _make(s,across)
			if again.objects.size() != islet.objects.size() or again.heights != islet.heights: same = false
			elif not islet.objects.is_empty():
				var a: Dictionary = islet.objects[islet.objects.size()/2]
				var b: Dictionary = again.objects[again.objects.size()/2]
				if a.asset != b.asset or not is_equal_approx(float(a.x),float(b.x)) or not is_equal_approx(float(a.z),float(b.z)): same = false
			var trees: Array = islet.objects.filter(func(o: Dictionary) -> bool: return o.asset in TREES)
			var density := trees.size()/maxf(islet.land_area(),1.0)
			if density < DENSITY.x or density > DENSITY.y: sparse.append("%.0f m seed %d: %.3f trees/m2" % [across,s,density])
			for o: Dictionary in trees:
				var p := Vector2(o.x,o.z)
				if not islet.on_land(p) or islet.wet(p): dry = false
			# The clearing: there, and open of trunks over most of it.
			var clearing: Vector3 = islet.get_meta("clearing",Vector3.ZERO)
			var glades: Array = islet.get_meta("glades",[])
			if clearing.z <= 0.0 or glades.size() < 2: no_clearing.append("%.0f m seed %d" % [across,s])
			else:
				for o: Dictionary in trees:
					if Vector2(o.x,o.z).distance_to(Vector2(clearing.x,clearing.y)) < clearing.z*0.6: cluttered.append("%.0f m seed %d" % [across,s]); break
			# Spruce high, birch low: their mean height over the land's lowest.
			var low := INF
			for i in range(islet.points.size()):
				if islet.shore_distance[i] >= 0.0: low = minf(low,islet.heights[i])
			for o: Dictionary in trees:
				var h: float = islet.ground_at(Vector2(o.x,o.z))-low
				if o.asset == "tree": high_spruce += h; spruces += 1
				elif o.asset == "birch": high_birch += h; birches += 1
			# The stream: down to the shore, falling all the way, drawn.
			var stream: Dictionary = islet.stream
			if not stream.is_empty():
				streams += 1
				var level: PackedFloat32Array = stream.level
				var course: PackedVector2Array = stream.course
				for k in range(1,level.size()):
					if level[k] > level[k-1]+0.0001: stream_bad.append("%.0f m seed %d rises" % [across,s]); break
				if islet.on_land(course[course.size()-1]): stream_bad.append("%.0f m seed %d ends inland" % [across,s])
				if (islet.water_arrays() as Array).is_empty() or islet.water().is_empty(): stream_bad.append("%.0f m seed %d draws no water" % [across,s])
				if not islet.wet(course[course.size()/2]): stream_bad.append("%.0f m seed %d is dry midway" % [across,s])
			var shade: PackedFloat32Array = islet.get_meta("forest_shade",PackedFloat32Array())
			if shade.size() != islet.points.size(): shaded = false
			if across == widths[2]:
				var instances := 0
				var near := 0
				var far := 0
				for key: String in plants:
					instances += int(plants[key].count)
					if catalog.roles.get(key,"") == "tree":
						near += int(plants[key].count)*int(tri.get(key,0))
						far += int(plants[key].count)*FarTrees.triangles(key,catalog.meshes[key])
				widest.instances = maxi(widest.instances,instances)
				widest.near = maxi(widest.near,near)
				widest.far = maxi(widest.far,far)
	check(same,"The same seed makes the same island")
	check(sparse.is_empty(),"Every island is wooded, %.2f to %.2f trees a square metre%s" % [DENSITY.x,DENSITY.y,"" if sparse.is_empty() else " (%s)" % ", ".join(sparse)])
	check(dry,"Every tree stands on dry land")
	check(no_clearing.is_empty(),"Every island has a clearing and a glade%s" % ("" if no_clearing.is_empty() else " (none on %s)" % ", ".join(no_clearing)))
	check(cluttered.is_empty(),"The clearings are open of trunks%s" % ("" if cluttered.is_empty() else " (not on %s)" % ", ".join(cluttered)))
	var spruce_h := high_spruce/maxf(spruces,1.0)
	var birch_h := high_birch/maxf(birches,1.0)
	check(spruces > 0 and birches > 0 and spruce_h > birch_h,"Spruce stands higher than birch (%.2f m over the lowest ground to %.2f)" % [spruce_h,birch_h])
	check(streams >= SEEDS.size(),"The wider islands have their streams (%d of %d islands)" % [streams,widths.size()*SEEDS.size()])
	check(stream_bad.is_empty(),"Each stream runs wet, falling, to the shore%s" % ("" if stream_bad.is_empty() else " (%s)" % ", ".join(stream_bad)))
	check(shaded,"The floor is shaded under the crowns")
	check(widest.instances <= INSTANCES,"The widest island draws at most %d instances (%d)" % [INSTANCES,widest.instances])
	check(widest.near <= NEAR_TRIANGLES,"Its trees draw at most %d triangles near (%d)" % [NEAR_TRIANGLES,widest.near])
	check(widest.far <= FAR_TRIANGLES,"And at most %d as far stand-ins (%d)" % [FAR_TRIANGLES,widest.far])
	var most := 0
	for key: String in catalog.meshes:
		if catalog.roles.get(key,"") == "tree" and catalog.meshes[key] is Mesh: most = maxi(most,FarTrees.triangles(key,catalog.meshes[key]))
	check(most > 0 and most <= PART_TRIANGLES,"A tree part's stand-in is a few faces (%d at most)" % most)
	check(slowest < BUDGET_MS,"Each island builds within %.0f ms (slowest %.0f ms)" % [BUDGET_MS,slowest])
	print("  widest: %d instances, %d near tree triangles, %d far; slowest build %.0f ms" % [widest.instances,widest.near,widest.far,slowest])
	print("PASS: landform forest" if failures == 0 else "FAIL: landform forest")
	quit(1 if failures else 0)
