extends SceneTree
## The hills landform (scripts/landform_hills.gd, scripts/hill_downs.gd):
## its contract as the lower world registers it (NAME, ACROSS, `recipe`);
## over a few seeds at the narrowest, middle and widest widths, its islands
## (SkyIslet `author`) are the same from the same seed, as wide as asked,
## rise to real hills over a shore at the rim without towering, keep their
## rock to the sea cliffs and the tors (the downs' slopes stay grass), keep
## every plant on the land, have their crest's trees and their drifts, take
## the coarser grid when wide, and build in good time.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const Hills = preload("res://scripts/landform_hills.gd")
const HillDowns = preload("res://scripts/hill_downs.gd")
const SEEDS := [4100,12019,19938]
## Shape and arrays, per island (ms): generous, so a checkout without the
## native erosion kernel (scripts/native_terrain_kernels.gd) passes too.
const BUDGET_MS := 3000.0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _make(seed_value: int, across: float) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SkyIslet.author(seed_value,Hills.recipe(rng,across))

func _run() -> void:
	check(Hills.NAME == "hills","The landform is named hills")
	check(Hills.ACROSS.x >= 25.0 and Hills.ACROSS.y <= 100.0 and Hills.ACROSS.x < Hills.ACROSS.y,"Its width range is %s m" % Hills.ACROSS)
	var widths := [Hills.ACROSS.x,lerpf(Hills.ACROSS.x,Hills.ACROSS.y,0.5),Hills.ACROSS.y]
	var same := true
	var wide_ok := []
	var low := INF
	var high := -INF
	var lowest_peak := INF
	var steep_inland := 0.0
	var off_land := []
	var bare := []
	var slowest := 0.0
	var faces_widest := 0
	for across: float in widths:
		for seed_value: int in SEEDS:
			var began := Time.get_ticks_usec()
			var a: RefCounted = _make(seed_value,across)
			a.top_arrays(SkyIslet.plain_palette())
			a.side_arrays()
			slowest = maxf(slowest,(Time.get_ticks_usec()-began)/1000.0)
			var b: RefCounted = _make(seed_value,across)
			if a.heights != b.heights or a.objects.size() != b.objects.size(): same = false
			elif not a.objects.is_empty() and str(a.objects[a.objects.size()-1]) != str(b.objects[b.objects.size()-1]): same = false
			var land_across: float = a.radius_of_land()*2.0
			if land_across < across*0.75 or land_across > across*1.25: wide_ok.append("%.0f m seed %d is %.0f m" % [across,seed_value,land_across])
			var peak := -INF
			for i in range(a.points.size()):
				if a.shore_distance[i] < 0.0: continue
				low = minf(low,a.heights[i])
				high = maxf(high,a.heights[i])
				peak = maxf(peak,a.heights[i])
			lowest_peak = minf(lowest_peak,peak-SkyIslet.RIM_HEIGHT)
			# Rock-steep faces away from the coast and the tors.
			var tors: Array = a.get_meta("downs").tors
			var steep := 0
			for f in a.land:
				if a._slope(f) <= SkyIslet.plain_palette().rock_slope: continue
				var c: Vector2 = (a.points[a.ids[f*3]]+a.points[a.ids[f*3+1]]+a.points[a.ids[f*3+2]])/3.0
				if a.inland(c) < 4.0: continue
				var by_tor := false
				for t: Vector4 in tors: by_tor = by_tor or c.distance_to(Vector2(t.x,t.y)) < t.z*1.3
				if not by_tor: steep += 1
			steep_inland = maxf(steep_inland,float(steep)/a.land.size())
			for o: Dictionary in a.objects:
				if not a.on_land(Vector2(o.x,o.z)): off_land.append("%s at (%.1f, %.1f)" % [o.asset,o.x,o.z])
			var trees := 0
			for o: Dictionary in a.objects:
				if o.asset in HillDowns.TREE_POOL: trees += 1
			if trees == 0 or a.flowers.is_empty(): bare.append("%.0f m seed %d: %d trees, flowers %s" % [across,seed_value,trees,a.flowers])
			if across == widths[2]: faces_widest = maxi(faces_widest,a.land.size())
	check(same,"The same seed and width make the same island")
	check(wide_ok.is_empty(),"Each island is about as wide as asked%s" % ("" if wide_ok.is_empty() else " (%s)" % ", ".join(wide_ok.slice(0,3))))
	check(low > SkyIslet.RIM_HEIGHT-1.0 and high < SkyIslet.RIM_HEIGHT+16.0,"Heights stay between the shore and a hill's top (%.1f to %.1f m)" % [low,high])
	check(lowest_peak > 2.0,"Every island rises to real hills (the lowest top %.1f m over the rim)" % lowest_peak)
	check(steep_inland < 0.06,"Inland, the slopes stay grass, not rock (at most %.1f%% rock-steep away from the cliffs and tors)" % (steep_inland*100.0))
	check(off_land.is_empty(),"Every plant and stone stands on the land%s" % ("" if off_land.is_empty() else " (%d off, e.g. %s)" % [off_land.size(),off_land[0]]))
	check(bare.is_empty(),"Each island has its crest's trees and its flowers%s" % ("" if bare.is_empty() else " (%s)" % bare[0]))
	check(faces_widest < 4500,"The widest islands take the coarser grid (at most %d land faces)" % faces_widest)
	check(slowest < BUDGET_MS,"Each island shapes and draws within %.0f ms (slowest %.0f ms)" % [BUDGET_MS,slowest])
	print("landform hills: %d failures" % failures)
	quit(1 if failures > 0 else 0)
