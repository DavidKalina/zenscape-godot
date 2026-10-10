extends RefCounted
## A copy of the aqueduct isle's (studies/aqueduct_isle_undergrowth.gd) wired to the
## bell spires isle's art (studies/bell_spires_isle_art.gd); an extraction
## candidate for a shared kit isle builder (docs/scenic/bell-spires.md).
## The aqueduct isle's undergrowth (docs/scenic/aqueduct-isle-life.md): the
## game's own woodland floor (the fern and the shrub, scripts/
## undergrowth_mesh.gd; the mushroom, scripts/mushroom_mesh.gd; the mossy
## log, scripts/log_mesh.gd; the leaf bed) gathered where a ruin would
## shelter it: at the feet of what stands (a wall, a pier, a sarsen, a
## cliff), in under the rims, and thinly elsewhere. Plant records drawn the
## way the isle's grass and flowers are (studies/aqueduct_isle_flora.gd
## `_draw`: the plate catalog's parts, tiled multimeshes, the sky's plant
## materials), so they sway in the same breeze, part for the pilot's wake
## and take the look presets' colours and seasons.
##
## Placed as the flora places: a ray down must land on an island's turf on
## a face no steeper than the palette's rock slope, the same a little round
## it (nothing grows into a stone's foot), never on a worn path, the rims
## kept clear. "Near a foot" is a ring of such rays FOOT m round that finds
## something other than open turf.
const Art = preload("res://studies/bell_spires_isle_art.gd")
const Flora = preload("res://studies/bell_spires_isle_flora.gd")

## [asset, count a square metre of the isle's turf, size range]. The
## mushrooms come in clusters (each counted once).
const KINDS := [
	["fern",0.045,Vector2(0.9,1.45)],
	["shrub",0.028,Vector2(0.8,1.35)],
	["mushroom",0.012,Vector2(0.6,1.1)],
	["leaf_bed",0.006,Vector2(0.7,1.1)],
]
## Fallen mossy logs: a few, on the meadow skirts, at a foot.
const LOGS := 5
const LOG_SIZE := Vector2(0.7,1.0)
## Metres round a root that count as "at the foot" of what stands, and the
## share kept away from any foot or rim.
const FOOT := 2.4
const OPEN_KEEP := 0.12
## Metres in from the rim the plants keep, and within which a rim counts.
const RIM := 0.7
const RIM_NEAR := 3.0
## Probe reach round a root (m) and the rock slope's share, as the flora.
const REACH := 0.3

## The undergrowth as a Node3D of tiled multimeshes (meta "records",
## "counts", "instances", "triangles" as the flora's). `space`, `turf`,
## `outlines` as Flora.grow takes them.
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var turf_ids := {}
	for body: Object in turf: turf_ids[body.get_instance_id()] = true
	var steep: float = float(Art.palette().rock_slope)*Flora.STEEP_SHARE
	var ray := PhysicsRayQueryParameters3D.new()
	var ground := Flora.Ground.new()
	var records: Array = []
	var probe := func(p: Vector2, reach: float) -> float:
		var top := NAN
		var offsets: Array = [Vector2.ZERO] if reach <= 0.0 else [Vector2.ZERO,Vector2(reach,0.0),Vector2(-reach,0.0),Vector2(0.0,reach),Vector2(0.0,-reach)]
		for off: Vector2 in offsets:
			ray.from = Vector3(p.x+off.x,Art.TOP+60.0,p.y+off.y)
			ray.to = Vector3(p.x+off.x,Art.TOP-8.0,p.y+off.y)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top
	var edge := func(p: Vector2) -> float:
		for outline: PackedVector2Array in outlines:
			if Geometry2D.is_point_in_polygon(p,outline): return Art._edge_distance(p,outline)
		return -1.0
	var at_foot := func(p: Vector2) -> bool:
		for k in range(8):
			if is_nan(probe.call(p+Vector2.from_angle(k*TAU/8.0+0.2)*FOOT,0.0)): return true
		return false
	var add := func(asset: String, p: Vector2, size: float) -> bool:
		if Art.path_wear(p) > 0.1: return false
		var h: float = probe.call(p,REACH)
		if is_nan(h): return false
		var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
		ground.heights[item.id] = h
		records.append(item)
		return true
	var area := 0.0
	var box := Rect2()
	for i in range(outlines.size()):
		var outline: PackedVector2Array = outlines[i]
		area += absf(Art._area(Array(outline)))
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	for entry: Array in KINDS:
		var asset: String = entry[0]
		var want := int(area*float(entry[1]))
		var sizes: Vector2 = entry[2]
		var placed := 0
		for n in range(want*14):
			if placed >= want: break
			var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
			var e: float = edge.call(p)
			if e < RIM or Art.path_wear(p) > 0.05: continue
			if e > RIM_NEAR and not at_foot.call(p) and rng.randf() > OPEN_KEEP: continue
			if asset == "mushroom":
				var any := false
				for k in range(rng.randi_range(3,6)):
					var q := p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.12,0.5)
					any = add.call(asset,q,rng.randf_range(sizes.x,sizes.y)) or any
				if any: placed += 1
			elif add.call(asset,p,rng.randf_range(sizes.x,sizes.y)):
				placed += 1
				# A fern or shrub seldom stands alone: a second close by.
				if asset in ["fern","shrub"] and rng.randf() < 0.45:
					add.call(asset,p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.6,1.2),rng.randf_range(sizes.x,sizes.y)*0.85)
	# The logs: lying at a foot on open turf, a fern or two by each.
	var logs := 0
	for n in range(400):
		if logs >= LOGS: break
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var e: float = edge.call(p)
		if e < 2.0 or Art.path_wear(p) > 0.02 or not at_foot.call(p): continue
		# A log wants its length clear: probe along it.
		var angle := rng.randf()*TAU
		var along := Vector2.from_angle(angle)
		if is_nan(probe.call(p+along*1.2,REACH)) or is_nan(probe.call(p-along*1.2,REACH)): continue
		if add.call("log",p,rng.randf_range(LOG_SIZE.x,LOG_SIZE.y)):
			(records[-1] as Dictionary).angle = angle
			logs += 1
			for k in range(rng.randi_range(1,2)):
				add.call("fern",p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.9,1.5),rng.randf_range(0.5,0.75))
	var node: Node3D = Flora._draw(records,ground,area)
	node.name = "Undergrowth"
	return node
