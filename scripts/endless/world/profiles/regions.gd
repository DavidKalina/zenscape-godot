extends "res://scripts/endless/world/world_profile.gd"
## Regions: one world stitched from the registered regions
## (scripts/endless/world/regions.gd), a patchwork of irregular cells about
## 6 km across (scripts/endless/world/region_map.gd), each one region's
## world profile, easing into the next over a border band
## (--world=regions; docs/design/endless-flight/spec-world-regions.md).
##
## Not uniform: the engine asks `at`, `weights_at` and `layer_at` per unit of
## work. Its own tables are the start region's: the land, flora and paint
## that stand where no per-spot answer reaches yet.
##
## Knobs (the registry only sets defaults):
##   --region-size=M    a region's mean width (Regions.SIZE)
##   --region-blend=M   the border band's width (Regions.BLEND)
##   --region-seed=N    the layout's own seed (default the land's --seed=)
##   --regions=id:share[:start],...   the registry's list and shares
##   --region-border    start short of the nearest border, heading across it
##   --region-debug     show the region and its weights under the eye

const Base = preload("res://scripts/endless/world/world_profile.gd")
const Registry = preload("res://scripts/endless/world/regions.gd")
const RegionMap = preload("res://scripts/endless/world/region_map.gd")

## The child profiles, by region index (the map's).
var regions: Array[RefCounted] = []
## Whether the start may lie in each region.
var startable: Array[bool] = []
var map: RefCounted
## The start's region index.
var start_region := 0
## --region-border: the start sits short of a border, heading across it.
var border_start := false
## Where the --region-border start's border lies (NAN when none was found).
var border_at := Vector2(NAN,NAN)

func _init() -> void:
	id = "regions"
	title = "Regions"
	uniform = false
	var size := Registry.SIZE
	var band := Registry.BLEND
	var layout_seed := 1
	var seed_given := false
	var list: Array = Registry.REGISTRY.duplicate(true)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--region-size="): size = a.get_slice("=",1).to_float()
		elif a.begins_with("--region-blend="): band = a.get_slice("=",1).to_float()
		elif a.begins_with("--region-seed="):
			layout_seed = a.get_slice("=",1).to_int()
			seed_given = true
		elif a.begins_with("--seed=") and not seed_given: layout_seed = a.get_slice("=",1).to_int()
		elif a.begins_with("--regions="): list = _parse_list(a.get_slice("=",1))
		elif a == "--region-border": border_start = true
	var shares := PackedFloat32Array()
	for e: Dictionary in list:
		var rid := str(e.id)
		if rid == id:
			push_error("regions: a region can't be the regions world itself; skipped")
			continue
		var p: RefCounted = Base.make(rid)
		if p.uniform == false:
			push_error("regions: '%s' is not a one-profile world; skipped" % rid)
			continue
		regions.append(p)
		startable.append(bool(e.get("start",false)))
		shares.append(float(e.get("share",1.0)))
	if regions.is_empty():
		regions.append(Base.make(DEFAULT))
		startable.append(true)
		shares.append(1.0)
	if not startable.has(true): startable[0] = true
	map = RegionMap.new(size,band,layout_seed,shares)
	_place_start()
	# The tables where no per-spot answer reaches: the start region's.
	var home: RefCounted = regions[start_region]
	land = home.land.duplicate(true)
	flora = home.flora.duplicate(true)
	paint = home.paint.duplicate(true)
	layers = home.layers.duplicate(true)
	# Halls and tunnels stand only once their sites keep inside their region.
	layers.halls = 0.0
	layers.tunnels = 0.0

## --regions=wilderness:2:start,overgrown:1 into registry entries.
static func _parse_list(text: String) -> Array:
	var out: Array = []
	for part in text.split(",",false):
		var bits := part.split(":")
		var e := {"id":bits[0],"share":1.0,"start":false}
		if bits.size() >= 2 and bits[1] != "": e.share = bits[1].to_float()
		if bits.size() >= 3: e.start = bits[2] == "start" or bits[2] == "1"
		out.append(e)
	if not out.is_empty():
		var any := false
		for e: Dictionary in out: any = any or bool(e.start)
		if not any: out[0].start = true
	return out

# --- Per spot ------------------------------------------------------------------------

func at(x: float, z: float) -> RefCounted:
	return regions[map.dominant(x,z)]

func weights_at(x: float, z: float) -> Dictionary:
	var w: PackedFloat32Array = map.weights(x,z)
	var out := {}
	for r in w.size():
		if w[r] > 0.0: out[regions[r]] = w[r]
	return out

## The regions' weights at (x, z) by region index (the map's own answer).
func weights_by_index(x: float, z: float) -> PackedFloat32Array:
	return map.weights(x,z)

## One line for --region-debug: the region, its cell and the weights.
func describe(x: float, z: float) -> String:
	var w: PackedFloat32Array = map.weights(x,z)
	var c: Vector2i = map.cell_at(x,z)
	var parts := PackedStringArray()
	for r in w.size():
		if w[r] > 0.001: parts.append("%s %.2f" % [regions[r].id,w[r]])
	return "region %s  ·  cell %d, %d  ·  %s" % [at(x,z).title,c.x,c.y,"  ".join(parts)]

# --- The start -----------------------------------------------------------------------

## The start: the nearest startable cell to the origin, well inside it, a
## border within about a minute's flight (or, --region-border, just short of
## the nearest border, heading across it).
func _place_start() -> void:
	var cell := _nearest_startable()
	start_region = map.region_of(cell.x,cell.y)
	var site := _unwarp(map.site(cell.x,cell.y))
	# The nearest border into another region, from the cell's middle.
	var cross := _nearest_border(site,start_region)
	var at_xz := site
	var dir := Vector2(0.0,-1.0)
	if not is_nan(cross.x):
		dir = (cross-site).normalized()
		var reach := site.distance_to(cross)
		if border_start:
			# In the band's outer edge, its middle about 20 s off at cruise.
			at_xz = cross-dir*(map.blend*0.4)
			border_at = cross
		else:
			# Well inside (1.5 km past the band), a border under a minute off.
			var keep: float = map.blend*0.5+1500.0
			if reach > keep: at_xz = site+dir*(reach-keep)
	spawn = {"at":at_xz,"alt":45.0,"heading":-rad_to_deg(atan2(-dir.x,-dir.y)) if border_start else 0.0}

func _nearest_startable() -> Vector2i:
	var home: Vector2i = map.cell_at(0.0,0.0)
	for ring in 12:
		var best := Vector2i.MAX
		var best_d := INF
		for dj in range(-ring,ring+1):
			for di in range(-ring,ring+1):
				if maxi(absi(di),absi(dj)) != ring: continue
				var c := home+Vector2i(di,dj)
				if not startable[map.region_of(c.x,c.y)]: continue
				var d: float = map.site(c.x,c.y).length_squared()
				if d < best_d:
					best_d = d
					best = c
		if best != Vector2i.MAX: return best
	return home

## The world point that warps onto warped point q (the warp moves under a
## third of a size per size, so the fixed point converges).
func _unwarp(q: Vector2) -> Vector2:
	var p := q
	for i in 12:
		p += q-map.warp(p.x,p.y)
	return p

## The nearest point from `from` (36 headings, 100 m steps, then halved
## down to a few metres) where another region than `home` takes over; NAN
## when none lies within two sizes.
func _nearest_border(from: Vector2, home: int) -> Vector2:
	var best := Vector2(NAN,NAN)
	var best_d := INF
	var step := 100.0
	for k in 36:
		var a := TAU*k/36.0
		var d := Vector2(cos(a),sin(a))
		var t := 0.0
		while t < minf(map.size*2.0,best_d):
			t += step
			var p := from+d*t
			if map.weights(p.x,p.y)[home] >= 0.5: continue
			var lo := t-step
			var hi := t
			for i in 5:
				var mid := (lo+hi)*0.5
				var m := from+d*mid
				if map.weights(m.x,m.y)[home] >= 0.5: lo = mid
				else: hi = mid
			if hi < best_d:
				best_d = hi
				best = from+d*hi
			break
	return best
