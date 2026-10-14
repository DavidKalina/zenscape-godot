class_name KitFlora
extends RefCounted
## The kit isles' grass, flowers and undergrowth (docs/scenic/kit-isle-shared.md),
## grown the way the game grows them on its sky islands (scripts/sky_islet.gd,
## scripts/sky_islets.gd): plant records (the plate catalog's shader grass
## tuft, scripts/grass_tuft_mesh.gd, the meadow flowers, scripts/
## meadow_flower_mesh.gd, and the undergrowth's fern, shrub, mushroom, leaf
## bed and mossy log) turned into per-part transforms by the plate's own
## instance builder (scripts/garden_instance_samples.gd `add_item`) and drawn
## as multimeshes with the catalog's materials made safe for the sky
## (SkyIslets `_plant_material`). So the breeze and the gust fronts sway
## them, the pilot's wake (scripts/pilot_wake.gd) parts them, and they take
## the scene look's grass and flower colours and the seasons as the game's do.
## The aqueduct isle's growers (studies/aqueduct_isle_flora.gd,
## _undergrowth.gd), which every motif had copied, its isle's own ground
## given as a `Site`.
##
## Placed over what the physics space stands there: a ray down must land on
## an island's own turf (one of `turf`, the ground bodies), on a face no
## steeper than the palette's rock slope (the crags stay bare rock), and the
## same within REACH round it, so nothing grows into a stone's foot, a wall,
## a stair's tread or a box. The worn ground's middles (the site's `wear`)
## stay bare and thin toward their edges; water (`wet`) grows nothing; the
## islands' rims are kept clear.
##
## Grass comes in drifts (`tufts` a square metre at their thickest, THIN
## between). Flowers follow a meadow type's composition (scripts/
## meadow_types.gd, MEADOW: drifts of one kind with a companion, a few
## strays) at a sparse share of its packing, so they read as wildflowers in
## the grass, not a carpet. Drawn in TILE m tiles, one multimesh a tile and
## part, so each tile culls on its own and fades out past its kind's range.
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Samples = preload("res://scripts/garden_instance_samples.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")

## Grass tufts a square metre at a drift's thickest (a site's own `tufts`
## by default), the least share of it between drifts, the drifts' scale
## (1/m), the tufts' size range.
const TUFTS := 4.6
const THIN := 0.35
const DRIFT_FREQUENCY := 0.07
const TUFT_SIZE := Vector2(0.85,1.45)
## The meadow type the flowers compose as, flower candidates a square
## metre, the share of the type's packing kept (a sparse sowing), strays.
const MEADOW := "alpine"
const FLOWER_TRIES := 2.2
const FLOWER_SHARE := 0.16
const STRAY := 0.006
## Kept bare: in from the rim (m), the worn ground (wear past PATH_BARE,
## thinning from PATH_THIN), anything else than turf within REACH of the
## root, faces steeper than the palette's rock slope times STEEP_SHARE.
const RIM := 0.5
const PATH_BARE := 0.5
const PATH_THIN := 0.1
const REACH := 0.25
const STEEP_SHARE := 0.85
## Tiles (m: the grass and flowers', the undergrowth's, sparser, larger)
## and how far each kind draws (m), with the fade's margin.
const TILE := 24.0
const UNDER_TILE := 40.0
const GRASS_RANGE := 95.0
const FLOWER_RANGE := 65.0
const FADE := 15.0

## The undergrowth: [asset, count a square metre of the isle's turf, size
## range] (the mushrooms come in clusters, each counted once); fallen mossy
## logs, a few, on the meadow skirts, at a foot; metres round a root that
## count as "at the foot" of what stands, and the share kept away from any
## foot or rim; metres in from the rim the plants keep, and within which a
## rim counts; its probe's reach round a root.
const KINDS := [
	["fern",0.045,Vector2(0.9,1.45)],
	["shrub",0.028,Vector2(0.8,1.35)],
	["mushroom",0.012,Vector2(0.6,1.1)],
	["leaf_bed",0.006,Vector2(0.7,1.1)],
]
const LOGS := 5
const LOG_SIZE := Vector2(0.7,1.0)
const FOOT := 2.4
const OPEN_KEEP := 0.12
const UNDER_RIM := 0.7
const RIM_NEAR := 3.0
const UNDER_REACH := 0.3

## An isle's ground as the growers read it: `wear` ((x, z) -> 0..1, its
## worn paths: bare past PATH_BARE), `wet` ((x, z) -> bool, its water: bare),
## `ray` (world y from, to: the rays down onto its turf), `tufts` (grass a
## square metre at a drift's thickest).
class Site extends RefCounted:
	var wear := Callable()
	var wet := Callable()
	var ray := Vector2(90.0,22.0)
	var tufts := 4.6
	## (collider) -> bool: what a plant's ray looks past, as if it weren't
	## there (a placed isle's neighbours: scripts/kit_isle/motif_isle.gd);
	## none by default.
	var looks_past := Callable()

	func _init(top := 30.0, wear_fn := Callable(), wet_fn := Callable()) -> void:
		ray = Vector2(top+60.0,top-8.0)
		wear = wear_fn
		wet = wet_fn

	func worn(p: Vector2) -> float:
		return float(wear.call(p)) if wear.is_valid() else 0.0

	func is_wet(p: Vector2) -> bool:
		return wet.is_valid() and bool(wet.call(p))

## What the instance builder asks of the land a record stands on.
class Ground extends RefCounted:
	var heights := {}
	func object_position(item: Dictionary) -> Vector3:
		return Vector3(item.x,float(heights.get(item.id,0.0)),item.z)

## The turf's height under `p` (a ray down over `site`'s span onto one of
## `turf`, its face no steeper than the rock slope's share, the same `reach`
## round it), or NAN where it isn't open turf: a callable (p, reach).
static func prober(space: PhysicsDirectSpaceState3D, turf: Array, site: Site) -> Callable:
	var turf_ids := {}
	for body: Object in turf: turf_ids[body.get_instance_id()] = true
	var steep: float = float(KitLook.palette().rock_slope)*STEEP_SHARE
	var ray := PhysicsRayQueryParameters3D.new()
	var span := site.ray
	var past := site.looks_past
	return func(p: Vector2, reach: float) -> float:
		var top := NAN
		var offsets: Array = [Vector2.ZERO] if reach <= 0.0 else [Vector2.ZERO,Vector2(reach,0.0),Vector2(-reach,0.0),Vector2(0.0,reach),Vector2(0.0,-reach)]
		for off: Vector2 in offsets:
			ray.from = Vector3(p.x+off.x,span.x,p.y+off.y)
			ray.to = Vector3(p.x+off.x,span.y,p.y+off.y)
			var hit := space.intersect_ray(ray)
			# Past what the site looks past, cast again without it.
			if past.is_valid() and not hit.is_empty() and not turf_ids.has((hit.collider as Object).get_instance_id()) and bool(past.call(hit.collider)):
				var skipped: Array[RID] = []
				while not hit.is_empty() and not turf_ids.has((hit.collider as Object).get_instance_id()) and bool(past.call(hit.collider)) and skipped.size() < 16:
					skipped.append(hit.rid)
					ray.exclude = skipped
					hit = space.intersect_ray(ray)
				ray.exclude = []
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top

## How far `p` is in from the rim of the outline holding it, -1 off them all.
static func edge(p: Vector2, outlines: Array) -> float:
	for outline: PackedVector2Array in outlines:
		if Geometry2D.is_point_in_polygon(p,outline): return KitLand.edge_distance(p,outline)
	return -1.0

## `edge` for many points over the same outlines, faster: each outline's
## segments filed by the cells (REACH_INDEX across) their box grown by
## REACH_INDEX touches, so a point looks only at the segments that could be
## within REACH_INDEX of it, with the very calls `edge` makes. `upto(p)` is
## `edge(p)` exactly when that is under REACH_INDEX (or -1 off the outlines),
## and INF otherwise: every test against a distance under REACH_INDEX (the
## rim, RIM_NEAR, a log's clearance) comes out as `edge`'s does.
const REACH_INDEX := 3.5

class EdgeIndex extends RefCounted:
	var _outlines: Array
	var _grids: Array = []

	func _init(outlines: Array) -> void:
		_outlines = outlines
		var grow := REACH_INDEX*1.01+0.01
		for outline: PackedVector2Array in outlines:
			var grid := {}
			var n := outline.size()
			for i in range(n):
				var a := outline[i]
				var b := outline[(i+1)%n]
				var lo := a.min(b)-Vector2.ONE*grow
				var hi := a.max(b)+Vector2.ONE*grow
				for cx in range(floori(lo.x/REACH_INDEX),floori(hi.x/REACH_INDEX)+1):
					for cz in range(floori(lo.y/REACH_INDEX),floori(hi.y/REACH_INDEX)+1):
						var key := Vector2i(cx,cz)
						if not grid.has(key): grid[key] = []
						(grid[key] as Array).append(i)
			_grids.append(grid)

	func upto(p: Vector2) -> float:
		for k in range(_outlines.size()):
			var outline: PackedVector2Array = _outlines[k]
			if not Geometry2D.is_point_in_polygon(p,outline): continue
			var segs: Variant = (_grids[k] as Dictionary).get(Vector2i(floori(p.x/REACH_INDEX),floori(p.y/REACH_INDEX)))
			if segs == null: return INF
			var n := outline.size()
			var best := INF
			for i: int in segs:
				best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,outline[i],outline[(i+1)%n])))
			return best if best < REACH_INDEX else INF
		return -1.0

## [the outlines' box, their area].
static func box_and_area(outlines: Array) -> Array:
	var area := 0.0
	var box := Rect2()
	for i in range(outlines.size()):
		var outline: PackedVector2Array = outlines[i]
		area += absf(KitLand.area(Array(outline)))
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	return [box,area]

## The grass and flowers: a Node3D of tiled multimeshes, its meta "records"
## (the plant records), "counts" (records by asset), "instances" (instances
## by part) and "triangles" (instanced triangles drawn at most). `space` the
## physics space the isle stands in; `turf` the islands' ground bodies (a
## ray must land on one); `outlines` the islands' (world x, z) polygons.
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array, site: Site) -> Node3D:
	var job := Grow.new(seed_value,space,turf,outlines,site)
	while not job.step(-1): pass
	return job.node

## `grow` in steps, so a placed isle (scripts/kit_isle/motif_isle.gd) grows
## its plants a slice a frame: `step(usec)` works on for about that long
## (-1: to the end) and answers true once `node` is drawn. The same records
## in the same order as `grow`.
class Grow extends RefCounted:
	var node: Node3D
	var _site: Site
	var _outlines: Array
	var _rng := RandomNumberGenerator.new()
	var _drift := FastNoiseLite.new()
	var _meadow: MeadowTypes
	var _probe: Callable
	var _ground := Ground.new()
	var _records: Array = []
	var _box: Rect2
	var _area := 0.0
	var _grass := 0
	var _flowers := 0
	var _n := 0
	var _phase := 0
	var _draw: Draw
	var _edges: EdgeIndex

	func _init(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array, site: Site) -> void:
		_site = site
		_outlines = outlines
		_edges = EdgeIndex.new(outlines)
		_rng.seed = seed_value
		_drift.seed = seed_value+5
		_drift.frequency = DRIFT_FREQUENCY
		_meadow = MeadowTypes.new(MEADOW,seed_value+9)
		# The isle stands far off the plate: no plate rim thins its drifts.
		_meadow.rim_band = Vector2(1.0e6,2.0e6)
		_probe = KitFlora.prober(space,turf,site)
		var ba := KitFlora.box_and_area(outlines)
		_box = ba[0]
		_area = ba[1]
		_grass = int(_box.get_area()*site.tufts)
		_flowers = int(_box.get_area()*FLOWER_TRIES)

	func _add(asset: String, p: Vector2, size: float, extra := {}) -> bool:
		var h: float = _probe.call(p,REACH)
		if is_nan(h) or _site.is_wet(p): return false
		var item := {"id":_records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":_rng.randf()*TAU,"scale":size}
		item.merge(extra,true)
		_ground.heights[item.id] = h
		_records.append(item)
		return true

	func step(usec: int) -> bool:
		var end := Time.get_ticks_usec()+usec
		# Grass: thick in drifts, thinner between, thinning onto the paths.
		while _phase == 0:
			if _n >= _grass:
				_phase = 1
				_n = 0
				break
			_n += 1
			if usec >= 0 and _n % 32 == 0 and Time.get_ticks_usec() > end:
				_n -= 1
				return false
			var p := Vector2(_rng.randf_range(_box.position.x,_box.end.x),_rng.randf_range(_box.position.y,_box.end.y))
			var thick := clampf(0.6+_drift.get_noise_2d(p.x,p.y)*1.3,THIN,1.0)
			var worn := _site.worn(p)
			if worn > PATH_BARE or _rng.randf() > thick*(1.0-smoothstep(PATH_THIN,PATH_BARE,worn)): continue
			if _edges.upto(p) < RIM: continue
			_add("grass_tuft",p,_rng.randf_range(TUFT_SIZE.x,TUFT_SIZE.y)*lerpf(1.0,0.75,worn))
		# Flowers: the meadow type's drifts, sown sparse.
		var sizes: Dictionary = _meadow.type.sizes
		while _phase == 1:
			if _n >= _flowers:
				_phase = 2
				_draw = Draw.new(_records,_ground,_area)
				break
			_n += 1
			if usec >= 0 and _n % 32 == 0 and Time.get_ticks_usec() > end:
				_n -= 1
				return false
			var p := Vector2(_rng.randf_range(_box.position.x,_box.end.x),_rng.randf_range(_box.position.y,_box.end.y))
			var presence := _meadow.presence(p)
			var kind := _meadow.kind_at(p,_rng.randf())
			var keep := pow(presence,1.2)*MeadowTypes.packing(kind)*FLOWER_SHARE
			if _rng.randf() > maxf(keep,STRAY): continue
			if _site.worn(p) > PATH_THIN or _edges.upto(p) < RIM+0.3: continue
			var range_of: Array = sizes.get(kind,[0.85,1.1])
			var formed: Array = MeadowTypes.form(kind,_rng.randf_range(float(range_of[0]),float(range_of[1])),_rng.randf()*TAU)
			var extra := {}
			var tint := MeadowTypes.tint(kind,_meadow.variant(p))
			if tint != "": extra.tint = tint
			if not (formed[1] as Dictionary).is_empty(): extra.pose = formed[1]
			_add(MeadowTypes.asset(kind),p,float(formed[0]),extra)
		if _phase == 2:
			if not _draw.step(maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1): return false
			node = _draw.node
			_phase = 3
		return true

## The undergrowth at what stands' feet and under the rims, a few
## elsewhere (KINDS), and a few mossy logs, off the worn ground and the
## water: a Node3D as `grow`'s (meta "records", "counts", "instances",
## "triangles").
static func undergrowth(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array, site: Site) -> Node3D:
	var job := Undergrow.new(seed_value,space,turf,outlines,site)
	while not job.step(-1): pass
	return job.node

## `undergrowth` in steps, as `Grow` is `grow`'s.
class Undergrow extends RefCounted:
	var node: Node3D
	var _site: Site
	var _outlines: Array
	var _rng := RandomNumberGenerator.new()
	var _probe: Callable
	var _ground := Ground.new()
	var _records: Array = []
	var _box: Rect2
	var _area := 0.0
	## Where it is: the kind, its candidate, how many placed; then the logs'
	## candidate and count; then the draw.
	var _kind := 0
	var _n := 0
	var _placed := 0
	var _logs := 0
	var _phase := 0
	var _draw: Draw

	var _edges: EdgeIndex

	func _init(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array, site: Site) -> void:
		_site = site
		_outlines = outlines
		_edges = EdgeIndex.new(outlines)
		_rng.seed = seed_value
		_probe = KitFlora.prober(space,turf,site)
		var ba := KitFlora.box_and_area(outlines)
		_box = ba[0]
		_area = ba[1]

	func _at_foot(p: Vector2) -> bool:
		for k in range(8):
			if is_nan(_probe.call(p+Vector2.from_angle(k*TAU/8.0+0.2)*FOOT,0.0)): return true
		return false

	func _add(asset: String, p: Vector2, size: float) -> bool:
		if _site.worn(p) > 0.1: return false
		var h: float = _probe.call(p,UNDER_REACH)
		if is_nan(h) or _site.is_wet(p): return false
		var item := {"id":_records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":_rng.randf()*TAU,"scale":size}
		_ground.heights[item.id] = h
		_records.append(item)
		return true

	func step(usec: int) -> bool:
		var end := Time.get_ticks_usec()+usec
		while _phase == 0:
			if _kind >= KINDS.size():
				_phase = 1
				_n = 0
				break
			var entry: Array = KINDS[_kind]
			var asset: String = entry[0]
			var want := int(_area*float(entry[1]))
			var sizes: Vector2 = entry[2]
			if _placed >= want or _n >= want*14:
				_kind += 1
				_n = 0
				_placed = 0
				continue
			if usec >= 0 and Time.get_ticks_usec() > end: return false
			_n += 1
			var p := Vector2(_rng.randf_range(_box.position.x,_box.end.x),_rng.randf_range(_box.position.y,_box.end.y))
			var e := _edges.upto(p)
			if e < UNDER_RIM or _site.worn(p) > 0.05: continue
			if e > RIM_NEAR and not _at_foot(p) and _rng.randf() > OPEN_KEEP: continue
			if asset == "mushroom":
				var any := false
				for k in range(_rng.randi_range(3,6)):
					var q := p+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.12,0.5)
					any = _add(asset,q,_rng.randf_range(sizes.x,sizes.y)) or any
				if any: _placed += 1
			elif _add(asset,p,_rng.randf_range(sizes.x,sizes.y)):
				_placed += 1
				# A fern or shrub seldom stands alone: a second close by.
				if asset in ["fern","shrub"] and _rng.randf() < 0.45:
					_add(asset,p+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.6,1.2),_rng.randf_range(sizes.x,sizes.y)*0.85)
		# The logs: lying at a foot on open turf, a fern or two by each.
		while _phase == 1:
			if _n >= 400 or _logs >= LOGS:
				_phase = 2
				_draw = Draw.new(_records,_ground,_area,UNDER_TILE)
				break
			if usec >= 0 and Time.get_ticks_usec() > end: return false
			_n += 1
			var p := Vector2(_rng.randf_range(_box.position.x,_box.end.x),_rng.randf_range(_box.position.y,_box.end.y))
			if _edges.upto(p) < 2.0 or _site.worn(p) > 0.02 or not _at_foot(p): continue
			# A log wants its length clear: probe along it.
			var angle := _rng.randf()*TAU
			var along := Vector2.from_angle(angle)
			if is_nan(_probe.call(p+along*1.2,UNDER_REACH)) or is_nan(_probe.call(p-along*1.2,UNDER_REACH)): continue
			if _add("log",p,_rng.randf_range(LOG_SIZE.x,LOG_SIZE.y)):
				(_records[-1] as Dictionary).angle = angle
				_logs += 1
				for k in range(_rng.randi_range(1,2)):
					_add("fern",p+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.9,1.5),_rng.randf_range(0.5,0.75))
		if _phase == 2:
			if not _draw.step(maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1): return false
			node = _draw.node
			node.name = "Undergrowth"
			_phase = 3
		return true

## A multimesh's buffer (3D transforms and colours) for `transforms`
## and `colours` (white past their end), as set_instance_transform and
## set_instance_color would lay it out.
static func batch_buffer(transforms: Array, colours: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(transforms.size()*16)
	var k := 0
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var c: Color = colours[i] if i < colours.size() else Color.WHITE
		out[k] = t.basis.x.x; out[k+1] = t.basis.y.x; out[k+2] = t.basis.z.x; out[k+3] = t.origin.x
		out[k+4] = t.basis.x.y; out[k+5] = t.basis.y.y; out[k+6] = t.basis.z.y; out[k+7] = t.origin.y
		out[k+8] = t.basis.x.z; out[k+9] = t.basis.y.z; out[k+10] = t.basis.z.z; out[k+11] = t.origin.z
		out[k+12] = c.r; out[k+13] = c.g; out[k+14] = c.b; out[k+15] = c.a
		k += 16
	return out

## The records drawn as the islets draw theirs, one multimesh a tile and
## catalog part, `tile_size` m a tile.
static func draw(records: Array, ground: Ground, area: float, tile_size := TILE) -> Node3D:
	var job := Draw.new(records,ground,area,tile_size)
	while not job.step(-1): pass
	return job.node

## `draw` in steps, a tile at a time.
class Draw extends RefCounted:
	var node := Node3D.new()
	var _records: Array
	var _ground: Ground
	var _area: float
	var _tiles := {}
	var _keys: Array = []
	var _at := 0
	var _instances := {}
	var _triangles := 0

	func _init(records: Array, ground: Ground, area: float, tile_size := TILE) -> void:
		_records = records
		_ground = ground
		_area = area
		node.name = "Flora"
		# Records by tile, each built on its own so its parts stay together.
		for item: Dictionary in records:
			var key := Vector2i(floori(float(item.x)/tile_size),floori(float(item.z)/tile_size))
			if not _tiles.has(key): _tiles[key] = []
			(_tiles[key] as Array).append(item)
		_keys = _tiles.keys()

	func step(usec: int) -> bool:
		var end := Time.get_ticks_usec()+usec
		var catalog: Dictionary = SkyIslets.catalog()
		var data: Dictionary = catalog.data
		var meshes: Dictionary = catalog.meshes
		while _at < _keys.size():
			if usec >= 0 and Time.get_ticks_usec() > end: return false
			var tile: Vector2i = _keys[_at]
			_at += 1
			var transforms := {}
			var sources := {}
			var tints := {}
			for item: Dictionary in _tiles[tile]:
				Samples.add_item(item,_ground,data.parts,data.poses,data.tints,data.world,false,transforms,sources,tints)
			for key: String in transforms:
				var list: Array = transforms[key]
				if list.is_empty() or not meshes.has(key): continue
				var colours: Array = tints[key]
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.use_colors = true
				multimesh.mesh = meshes[key]
				multimesh.instance_count = list.size()
				# One upload, not two renderer calls an instance (each tile's
				# went 20-30 ms over its slice rendered).
				multimesh.buffer = KitFlora.batch_buffer(list,colours)
				var batch := MultiMeshInstance3D.new()
				batch.name = "%s_%d_%d" % [key.replace(":","_"),tile.x,tile.y]
				batch.multimesh = multimesh
				batch.material_override = SkyIslets._plant_material(key)
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				batch.visibility_range_end = GRASS_RANGE if key.begins_with("grass") else FLOWER_RANGE
				batch.visibility_range_end_margin = FADE
				batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				batch.set_meta("part",key)
				node.add_child(batch)
				_instances[key] = int(_instances.get(key,0))+list.size()
				_triangles += KitFlora._mesh_triangles(meshes[key])*list.size()
		var counts := {}
		for item: Dictionary in _records: counts[item.asset] = int(counts.get(item.asset,0))+1
		node.set_meta("records",_records)
		node.set_meta("counts",counts)
		node.set_meta("instances",_instances)
		node.set_meta("triangles",_triangles)
		node.set_meta("area",_area)
		return true

static func _mesh_triangles(mesh: Mesh) -> int:
	var count := 0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		count += (idx.size() if idx != null and idx is PackedInt32Array and idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3
	return count
