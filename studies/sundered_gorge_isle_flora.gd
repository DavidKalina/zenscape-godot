extends RefCounted
## The Sundered gorge isle's grass, flowers and undergrowth: the aqueduct
## isle's growers (studies/aqueduct_isle_flora.gd `grow`, studies/
## aqueduct_isle_undergrowth.gd `grow`) with this isle's worn paths and its
## pool (Gorge `path_wear`), its heights (the ledges far down the gorge's
## walls, the fragments deep in it) and a sparser sowing for its larger
## land; drawn through the aqueduct isle's own `_draw` (the plate catalog's
## parts, tiled multimeshes, the sky's plant materials), so they sway in
## the same breeze, part for the pilot's wake and follow the look presets.
## Parameterised copies: an extraction candidate (a shared kit-isle flora
## taking a wear callable and a height range).
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
const AqArt = preload("res://studies/aqueduct_isle_art.gd")
const AqFlora = preload("res://studies/aqueduct_isle_flora.gd")
const AqUndergrowth = preload("res://studies/aqueduct_isle_undergrowth.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")

## Grass tufts a square metre at a drift's thickest (the aqueduct isle's
## 4.6, thinned: this land is half as big again).
const TUFTS := 3.0
## The rays down: from this far over the west's lip to this far under it.
const RAY_TOP := 45.0
const RAY_BOTTOM := 18.0

## The rays' reach in world y.
static func ray_span() -> Vector2:
	return Vector2(Gorge.TOP+RAY_TOP,Gorge.TOP-RAY_BOTTOM)

static func _box_and_area(outlines: Array) -> Array:
	var area := 0.0
	var box := Rect2()
	for i in range(outlines.size()):
		var outline: PackedVector2Array = outlines[i]
		area += absf(AqArt._area(Array(outline)))
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	return [box,area]

## The grass and flowers (as AqFlora `grow`).
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var drift := FastNoiseLite.new()
	drift.seed = seed_value+5
	drift.frequency = AqFlora.DRIFT_FREQUENCY
	var meadow := MeadowTypes.new(AqFlora.MEADOW,seed_value+9)
	meadow.rim_band = Vector2(1.0e6,2.0e6)
	var turf_ids := {}
	for body: Object in turf: turf_ids[body.get_instance_id()] = true
	var steep: float = float(AqArt.palette().rock_slope)*AqFlora.STEEP_SHARE
	var ray := PhysicsRayQueryParameters3D.new()
	var span := ray_span()
	var ground := AqFlora.Ground.new()
	var records: Array = []
	var probe := func(p: Vector2) -> float:
		var top := NAN
		for off: Vector2 in [Vector2.ZERO,Vector2(AqFlora.REACH,0.0),Vector2(-AqFlora.REACH,0.0),Vector2(0.0,AqFlora.REACH),Vector2(0.0,-AqFlora.REACH)]:
			ray.from = Vector3(p.x+off.x,span.x,p.y+off.y)
			ray.to = Vector3(p.x+off.x,span.y,p.y+off.y)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top
	var inside := func(p: Vector2, rim: float) -> bool:
		for outline: PackedVector2Array in outlines:
			if Geometry2D.is_point_in_polygon(p,outline): return AqArt._edge_distance(p,outline) >= rim
		return false
	var add := func(asset: String, p: Vector2, size: float, extra := {}) -> bool:
		var h: float = probe.call(p)
		if is_nan(h): return false
		var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
		item.merge(extra,true)
		ground.heights[item.id] = h
		records.append(item)
		return true
	var ba := _box_and_area(outlines)
	var box: Rect2 = ba[0]
	var area: float = ba[1]
	for n in range(int(box.get_area()*TUFTS)):
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var thick := clampf(0.6+drift.get_noise_2d(p.x,p.y)*1.3,AqFlora.THIN,1.0)
		var worn := Gorge.path_wear(p)
		if worn > AqFlora.PATH_BARE or rng.randf() > thick*(1.0-smoothstep(AqFlora.PATH_THIN,AqFlora.PATH_BARE,worn)): continue
		if not inside.call(p,AqFlora.RIM): continue
		add.call("grass_tuft",p,rng.randf_range(AqFlora.TUFT_SIZE.x,AqFlora.TUFT_SIZE.y)*lerpf(1.0,0.75,worn))
	var sizes: Dictionary = meadow.type.sizes
	for n in range(int(box.get_area()*AqFlora.FLOWER_TRIES)):
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var presence := meadow.presence(p)
		var kind := meadow.kind_at(p,rng.randf())
		var keep := pow(presence,1.2)*MeadowTypes.packing(kind)*AqFlora.FLOWER_SHARE
		if rng.randf() > maxf(keep,AqFlora.STRAY): continue
		if Gorge.path_wear(p) > AqFlora.PATH_THIN or not inside.call(p,AqFlora.RIM+0.3): continue
		var range_of: Array = sizes.get(kind,[0.85,1.1])
		var formed: Array = MeadowTypes.form(kind,rng.randf_range(float(range_of[0]),float(range_of[1])),rng.randf()*TAU)
		var extra := {}
		var tint := MeadowTypes.tint(kind,meadow.variant(p))
		if tint != "": extra.tint = tint
		if not (formed[1] as Dictionary).is_empty(): extra.pose = formed[1]
		add.call(MeadowTypes.asset(kind),p,float(formed[0]),extra)
	return AqFlora._draw(records,ground,area)

## The undergrowth at what stands and under the rims (as AqUndergrowth
## `grow`).
static func undergrowth(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var turf_ids := {}
	for body: Object in turf: turf_ids[body.get_instance_id()] = true
	var steep: float = float(AqArt.palette().rock_slope)*AqFlora.STEEP_SHARE
	var ray := PhysicsRayQueryParameters3D.new()
	var span := ray_span()
	var ground := AqFlora.Ground.new()
	var records: Array = []
	var probe := func(p: Vector2, reach: float) -> float:
		var top := NAN
		var offsets: Array = [Vector2.ZERO] if reach <= 0.0 else [Vector2.ZERO,Vector2(reach,0.0),Vector2(-reach,0.0),Vector2(0.0,reach),Vector2(0.0,-reach)]
		for off: Vector2 in offsets:
			ray.from = Vector3(p.x+off.x,span.x,p.y+off.y)
			ray.to = Vector3(p.x+off.x,span.y,p.y+off.y)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top
	var edge := func(p: Vector2) -> float:
		for outline: PackedVector2Array in outlines:
			if Geometry2D.is_point_in_polygon(p,outline): return AqArt._edge_distance(p,outline)
		return -1.0
	var at_foot := func(p: Vector2) -> bool:
		for k in range(8):
			if is_nan(probe.call(p+Vector2.from_angle(k*TAU/8.0+0.2)*AqUndergrowth.FOOT,0.0)): return true
		return false
	var add := func(asset: String, p: Vector2, size: float) -> bool:
		if Gorge.path_wear(p) > 0.1: return false
		var h: float = probe.call(p,AqUndergrowth.REACH)
		if is_nan(h): return false
		var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
		ground.heights[item.id] = h
		records.append(item)
		return true
	var ba := _box_and_area(outlines)
	var box: Rect2 = ba[0]
	var area: float = ba[1]
	for entry: Array in AqUndergrowth.KINDS:
		var asset: String = entry[0]
		var want := int(area*float(entry[1]))
		var sizes: Vector2 = entry[2]
		var placed := 0
		for n in range(want*14):
			if placed >= want: break
			var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
			var e: float = edge.call(p)
			if e < AqUndergrowth.RIM or Gorge.path_wear(p) > 0.05: continue
			if e > AqUndergrowth.RIM_NEAR and not at_foot.call(p) and rng.randf() > AqUndergrowth.OPEN_KEEP: continue
			if asset == "mushroom":
				var any := false
				for k in range(rng.randi_range(3,6)):
					var q := p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.12,0.5)
					any = add.call(asset,q,rng.randf_range(sizes.x,sizes.y)) or any
				if any: placed += 1
			elif add.call(asset,p,rng.randf_range(sizes.x,sizes.y)):
				placed += 1
				if asset in ["fern","shrub"] and rng.randf() < 0.45:
					add.call(asset,p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.6,1.2),rng.randf_range(sizes.x,sizes.y)*0.85)
	var logs := 0
	for n in range(400):
		if logs >= AqUndergrowth.LOGS: break
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var e: float = edge.call(p)
		if e < 2.0 or Gorge.path_wear(p) > 0.02 or not at_foot.call(p): continue
		var angle := rng.randf()*TAU
		var along := Vector2.from_angle(angle)
		if is_nan(probe.call(p+along*1.2,AqUndergrowth.REACH)) or is_nan(probe.call(p-along*1.2,AqUndergrowth.REACH)): continue
		if add.call("log",p,rng.randf_range(AqUndergrowth.LOG_SIZE.x,AqUndergrowth.LOG_SIZE.y)):
			(records[-1] as Dictionary).angle = angle
			logs += 1
			for k in range(rng.randi_range(1,2)):
				add.call("fern",p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.9,1.5),rng.randf_range(0.5,0.75))
	var node: Node3D = AqFlora._draw(records,ground,area)
	node.name = "Undergrowth"
	return node
