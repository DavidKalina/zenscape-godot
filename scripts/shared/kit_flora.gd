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
## The aqueduct isle's growers (scripts/shared/aqueduct_isle_flora.gd,
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
## Wild grass (Site `shag`): full wild within SHAG_RIM.x of the rim, none
## past .y; at a foot if what stands is within SHAG_FOOT.x (full) or .y
## (half), read on a SHAG_CELL m grid; the broad noise's share and scale.
const SHAG_RIM := Vector2(0.3,3.0)
const SHAG_FOOT := Vector2(1.0,2.2)
const SHAG_CELL := 1.0
const SHAG_VARY := 0.18
const SHAG_NOISE := 2.3
## The grass's variety (Site `variety`): a tussock's share (times 0.4 +
## wild), its form (x, y, z of a tuft's size) and its two satellites' reach
## (m); thatch's share at a full foot, its form and straw (sRGB); seed heads'
## share (times 0.3 + wild) and size range.
const TUSSOCK_SHARE := 0.08
const TUSSOCK_FORM := Vector3(1.3,1.6,1.3)
const TUSSOCK_REACH := Vector2(0.14,0.3)
const THATCH_SHARE := 0.35
const THATCH_FORM := Vector3(1.45,0.5,1.45)
const THATCH_STRAW := Color("b59c62")
const SEED_SHARE := 0.025
const SEED_SIZE := Vector2(0.7,1.0)
## The rolling height (Site `height_field`): its noise's scale (1/m) and
## how much denser (or sparser) the tall (or short) patches grow.
const HEIGHT_SCALE := 0.12
const HEIGHT_THICK := 0.3
## The spill over the rim (Site `spill`): how far in from the rim a tuft
## roots (m), its lean outward (radians), its size over the site's tuft.
const SPILL_IN := Vector2(0.05,0.35)
const SPILL_LEAN := Vector2(0.7,1.25)
const SPILL_SIZE := Vector2(1.2,1.9)
## Tiles (m: the grass and flowers', the undergrowth's, sparser, larger)
## and how far each kind draws (m), with the fade's margin.
const TILE := 24.0
## `Grow.step` looks at the clock every this many candidates.
const CHECK_EVERY := 4
const UNDER_TILE := 40.0
const GRASS_RANGE := 95.0
const FLOWER_RANGE := 65.0
const FADE := 15.0
## `--flora-fade=pop`: the grass and flowers stop at their range rather than
## fading out over FADE (a visible trade, off by default, for a lower
## graphics preset). A fading tile draws alpha-blended, in the transparent
## pass: 13 ms of the city's 28 ms at the landing.
static var _fade_mode := -1
static func fade_mode() -> int:
	if _fade_mode < 0:
		_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if "--flora-fade=pop" in preload("res://scripts/launch_args.gd").user_args(): _fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return _fade_mode

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
	## Stable scatter (the motif editor's): each candidate's draws are seeded
	## from the seed and its index, not drawn in turn, so a plant refused
	## (or newly let in) by an edit doesn't move every plant after it. Off
	## by default: every isle grows as before.
	var stable := false
	## Opt-in, for an isle with no physics bodies (a flown piece built on a
	## worker: scripts/hall_line_build.gd): (p, reach) -> the turf's height
	## under p, or NAN where it isn't open turf, in place of `prober`'s
	## rays (Grow ignores its `space` and `turf` then).
	var probe := Callable()
	## Opt-in: the tufts' size range (zero: TUFT_SIZE).
	var tuft_size := Vector2.ZERO
	## Opt-in: (p) -> how many times the flowers' share is kept at p (a
	## drift of wildflowers where it is over 1); none: as before.
	var flower_drift := Callable()
	## Opt-in: (p, kind) -> [kind, colour variant] a flower at p grows as
	## in place of the meadow type's `kind` (a drift of one kind), or []
	## for the meadow's own; none: as before.
	var flower_kind := Callable()
	## Opt-in: flower candidates a square metre (zero: FLOWER_TRIES).
	var flower_tries := 0.0
	## Opt-in: (p) -> how many times taller the flower at p stands (its
	## stem and head together); none: as before.
	var flower_lift := Callable()
	## Opt-in: Grow's draw gives its batches as plain data (`Grow.parts`:
	## key, tile, count, buffer), no nodes or materials made, so it can run
	## on a worker; `batch_node` stands one on the main thread.
	var plain := false
	## Opt-in: the grass as a carpet, not drifts: every candidate at full
	## thickness (only the paths thin it), drawn out to `grass_range` (m,
	## zero: GRASS_RANGE) so it covers the turf seen from the plane too.
	var carpet := false
	var grass_range := 0.0
	## Opt-in: how far in from the rim the grass keeps (m, below zero:
	## RIM); in that close, a tuft's probe reaches only as far as the rim.
	var rim := -1.0
	## Opt-in: the grass grows wild (taller by up to `shag` more of its
	## size) toward the rim and at what stands' feet, every tuft `tuft_bump`
	## times its size, and a broad noise of SHAG_VARY either way.
	var shag := 0.0
	var tuft_bump := 1.0
	## Opt-in (with `shag`): more than one grass. Tussocks (a tall tuft
	## and two by it), flattened straw thatch at what stands' feet and a few
	## seed heads (wheat), most where the grass grows wild; and the tufts at
	## a foot darkened by `contact` (0..1).
	var variety := false
	var contact := 0.0
	## Opt-in: the meadow's height rolls (each tuft up to `height_field`
	## of its size taller or shorter on a HEIGHT_SCALE noise, the tall
	## patches denser), and each tuft leans up to `tilt` radians.
	var height_field := 0.0
	var tilt := 0.0
	## Opt-in: the grass drawn in distance rings (a big turf seen on foot
	## and from the plane: studies/heist_home.gd), each tile's grass in two
	## batches. The near ring (all but `lod_share` of the tufts, the full
	## tuft) thins out over `lod.x`..`.y` m, each tuft shrinking into the
	## ground at its own distance; the mid ring (`lod_share` of them, the
	## cheaper tuft GrassTuft.build_lite) grows `lod_grow` (wide, tall) over
	## that band, so its sparser tufts keep the cover, and thins out over
	## `lod.z`..`.w` m. Each tuft goes over `lod_soft` m (reference_surface
	## `grass_ring`). A tile stops drawing once all its tufts have gone
	## (no fade, no alpha pass). Zero: off, one batch drawn to grass_range.
	var lod := Vector4.ZERO
	var lod_share := 0.25
	var lod_grow := Vector2(1.5,1.25)
	var lod_soft := 6.0
	## Opt-in: the candidates only within this box (world x, z; the
	## outlines' box clipped to it), so a big turf grows as several jobs at
	## once; the rim still read off the whole outlines. Zero size: all of it.
	var box := Rect2()
	## Opt-in: wild tufts spilling over the rim, `spill` a metre of it
	## (SPILL_IN m in, leaning out SPILL_LEAN radians, SPILL_SIZE times a
	## wild tuft), so the turf's edge hangs over the cliff's lip.
	var spill := 0.0
	## Opt-in with `spill`: true for a rim spot to leave bare (a fall's notch).
	var spill_off := Callable()

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
			var skipped: Array[RID] = []
			if past.is_valid() and not hit.is_empty() and not turf_ids.has((hit.collider as Object).get_instance_id()) and bool(past.call(hit.collider)):
				while not hit.is_empty() and not turf_ids.has((hit.collider as Object).get_instance_id()) and bool(past.call(hit.collider)) and skipped.size() < 16:
					skipped.append(hit.rid)
					ray.exclude = skipped
					hit = space.intersect_ray(ray)
				ray.exclude = []
			# A placed isle's (one that looks past its neighbours): turf wins a
			# tie. Where another body's face lies on the turf (a cliff's cap on
			# its rim), which the ray meets first depends on the order the
			# bodies were made in, so on how fast the layer loaded. Past such
			# faces, turf at the same point counts.
			if past.is_valid() and not hit.is_empty() and not turf_ids.has((hit.collider as Object).get_instance_id()):
				hit = _turf_at_tie(space,ray,hit,turf_ids,skipped)
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top

## Ties nearer than this (m) along a plant ray are the same point.
const TIE := 0.001

## `hit` (not turf), or the turf the ray meets at the same point past it
## and any other faces there (`prober`), still past what was `skipped`.
static func _turf_at_tie(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, hit: Dictionary, turf_ids: Dictionary, past: Array[RID]) -> Dictionary:
	var at: Vector3 = hit.position
	var skipped: Array[RID] = past.duplicate()
	skipped.append(hit.rid)
	var out := hit
	for k in range(4):
		ray.exclude = skipped
		var next := space.intersect_ray(ray)
		if next.is_empty() or (next.position as Vector3).distance_to(at) > TIE: break
		if turf_ids.has((next.collider as Object).get_instance_id()):
			out = next
			break
		skipped.append(next.rid)
	ray.exclude = []
	return out

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
	## The draw's batches when the site is `plain`.
	var parts: Array = []
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
	var _seed := 0
	var _feet := {}

	func _init(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array, site: Site) -> void:
		_site = site
		_outlines = outlines
		_edges = EdgeIndex.new(outlines)
		_seed = seed_value
		_rng.seed = seed_value
		_drift.seed = seed_value+5
		_drift.frequency = DRIFT_FREQUENCY
		_meadow = MeadowTypes.new(MEADOW,seed_value+9)
		# The isle stands far off the plate: no plate rim thins its drifts.
		_meadow.rim_band = Vector2(1.0e6,2.0e6)
		_probe = site.probe if site.probe.is_valid() else KitFlora.prober(space,turf,site)
		var ba := KitFlora.box_and_area(outlines)
		_box = ba[0]
		_area = ba[1]
		if site.box.has_area():
			_area *= _box.intersection(site.box).get_area()/maxf(_box.get_area(),0.001)
			_box = _box.intersection(site.box)
		_grass = int(_box.get_area()*site.tufts)
		_flowers = int(_box.get_area()*(site.flower_tries if site.flower_tries > 0.0 else FLOWER_TRIES))

	## 1 where something not turf stands within SHAG_FOOT.x of p's cell, 0.5
	## within .y, else 0 (the rim's drop counts too).
	func _foot(p: Vector2) -> float:
		var key := Vector2i(floori(p.x/SHAG_CELL),floori(p.y/SHAG_CELL))
		if _feet.has(key): return _feet[key]
		var c := (Vector2(key)+Vector2(0.5,0.5))*SHAG_CELL
		var f := 0.0
		for ring: float in [SHAG_FOOT.x,SHAG_FOOT.y]:
			for k in range(8):
				if is_nan(_probe.call(c+Vector2.from_angle(k*TAU/8.0+0.2)*ring,0.0)):
					f = 1.0 if ring == SHAG_FOOT.x else 0.5
					break
			if f > 0.0: break
		_feet[key] = f
		return f

	## The rolling height's noise at p (-1..1, about).
	func _rolling(p: Vector2) -> float:
		return clampf(_drift.get_noise_2d(p.x/DRIFT_FREQUENCY*HEIGHT_SCALE-57.0,p.y/DRIFT_FREQUENCY*HEIGHT_SCALE+89.0)*1.6,-1.0,1.0)

	## A tuft's basis turned `angle` round up, leaning up to the site's
	## tilt, `form` its size on each axis.
	func _lean(angle: float, form: Vector3) -> Basis:
		var b := Basis(Vector3.UP,angle).scaled(form)
		if _site.tilt <= 0.0: return b
		var axis := Vector3.RIGHT.rotated(Vector3.UP,_rng.randf()*TAU)
		return Basis(axis,_rng.randf()*_site.tilt)*b

	## How wild the grass grows at p (0..1), `e` from the rim.
	func _wild(p: Vector2, e: float) -> float:
		return maxf(1.0-smoothstep(SHAG_RIM.x,SHAG_RIM.y,e),_foot(p))

	## A tuft's size factor for the site's wild grass.
	func _shag(p: Vector2, wild: float) -> float:
		var n := _drift.get_noise_2d(p.x*SHAG_NOISE+31.0,p.y*SHAG_NOISE-17.0)
		return _site.tuft_bump*lerpf(1.0,1.0+_site.shag,wild)*(1.0+n*SHAG_VARY)

	## A tuft's grass (Site `variety`): a tussock, thatch, a seed head by
	## it, or a plain tuft; darkened at a foot away from the rim.
	func _tuft(p: Vector2, size: float, e: float, wild: float, reach: float) -> void:
		var foot := _foot(p) if e > SHAG_FOOT.y else 0.0
		var shade := 1.0-_site.contact*foot
		var angle := _rng.randf()*TAU
		var roll := _rng.randf()
		if foot > 0.0 and roll < THATCH_SHARE*foot:
			var straw := THATCH_STRAW.srgb_to_linear()*shade
			_add("grass_tuft",p,size,{"tint":NativeObjectPose.encode_tint(straw),"pose":NativeObjectPose.make(_lean(angle,THATCH_FORM*size),0.0)},reach)
			return
		var tint := {} if shade >= 1.0 else {"tint":NativeObjectPose.encode_tint(Color(shade,shade,shade))}
		roll = _rng.randf()
		if roll < TUSSOCK_SHARE*(0.4+wild):
			var tall := tint.duplicate()
			tall.pose = NativeObjectPose.make(_lean(angle,TUSSOCK_FORM*size),0.0)
			_add("grass_tuft",p,size,tall,reach)
			for k in range(2):
				var q := p+Vector2.from_angle(angle+PI*(0.3+k*1.1))*_rng.randf_range(TUSSOCK_REACH.x,TUSSOCK_REACH.y)
				_add("grass_tuft",q,size*_rng.randf_range(1.0,1.25),tint,minf(reach,REACH))
		else:
			var plain := tint.duplicate()
			if _site.tilt > 0.0: plain.pose = NativeObjectPose.make(_lean(angle,Vector3.ONE*size),0.0)
			_add("grass_tuft",p,size,plain,reach)
		if _rng.randf() < SEED_SHARE*(0.3+wild):
			var formed: Array = MeadowTypes.form("wheat",_rng.randf_range(SEED_SIZE.x,SEED_SIZE.y),_rng.randf()*TAU)
			var extra := {}
			var wheat_tint := MeadowTypes.tint("wheat",_rng.randf())
			if wheat_tint != "": extra.tint = wheat_tint
			if not (formed[1] as Dictionary).is_empty(): extra.pose = formed[1]
			_add(MeadowTypes.asset("wheat"),p+Vector2.from_angle(_rng.randf()*TAU)*0.2,float(formed[0]),extra,reach)

	func _add(asset: String, p: Vector2, size: float, extra := {}, reach := REACH) -> bool:
		var h: float = _probe.call(p,reach)
		if is_nan(h) or _site.is_wet(p): return false
		var item := {"id":_records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":_rng.randf()*TAU,"scale":size}
		item.merge(extra,true)
		_ground.heights[item.id] = h
		_records.append(item)
		return true

	## Site `spill`: wild tufts along every outline's rim (within the box),
	## rooted just in and leaning out over it.
	func _spill() -> void:
		var tuft := _site.tuft_size if _site.tuft_size != Vector2.ZERO else TUFT_SIZE
		for outline: PackedVector2Array in _outlines:
			var n := outline.size()
			for i in range(n):
				var a := outline[i]
				var b := outline[(i+1)%n]
				var along := b-a
				var length := along.length()
				if length < 0.001: continue
				var normal := along.normalized().orthogonal()
				# Pointing out of the land.
				if Geometry2D.is_point_in_polygon((a+b)*0.5+normal*0.05,outline) == true: normal = -normal
				var count := int(length*_site.spill)+(1 if _rng.randf() < fmod(length*_site.spill,1.0) else 0)
				for k in range(count):
					var p := a+along*_rng.randf()-normal*_rng.randf_range(SPILL_IN.x,SPILL_IN.y)
					if _box.has_area() and not _box.has_point(p): continue
					if _site.spill_off.is_valid() and _site.spill_off.call(p): continue
					var size := _rng.randf_range(tuft.x,tuft.y)*_rng.randf_range(SPILL_SIZE.x,SPILL_SIZE.y)*_site.tuft_bump
					var out3 := Vector3(normal.x,0.0,normal.y)
					var lean := Basis(Vector3.UP.cross(out3).normalized(),_rng.randf_range(SPILL_LEAN.x,SPILL_LEAN.y))
					var basis := lean*Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3.ONE*size)
					_add("grass_tuft",p,size,{"pose":NativeObjectPose.make(basis,0.0)},0.0)

	func step(usec: int) -> bool:
		var end := Time.get_ticks_usec()+usec
		# Grass: thick in drifts, thinner between, thinning onto the paths.
		while _phase == 0:
			if _n >= _grass:
				if _site.spill > 0.0: _spill()
				_phase = 1
				_n = 0
				break
			_n += 1
			# Checked often: a candidate can cost a dozen rays (its reach,
			# its foot), and a 32-candidate check overran a 4 ms slice by 12.
			if usec >= 0 and _n % CHECK_EVERY == 0 and Time.get_ticks_usec() > end:
				_n -= 1
				return false
			if _site.stable: _rng.seed = hash([_seed,0,_n])
			var p := Vector2(_rng.randf_range(_box.position.x,_box.end.x),_rng.randf_range(_box.position.y,_box.end.y))
			var thick := 1.0 if _site.carpet else clampf(0.6+_drift.get_noise_2d(p.x,p.y)*1.3,THIN,1.0)
			var rolling := _rolling(p) if _site.height_field > 0.0 else 0.0
			if _site.height_field > 0.0: thick *= 1.0-HEIGHT_THICK*0.5*(1.0-rolling)
			var worn := _site.worn(p)
			if worn > PATH_BARE or _rng.randf() > thick*(1.0-smoothstep(PATH_THIN,PATH_BARE,worn)): continue
			var e := _edges.upto(p)
			if e < (_site.rim if _site.rim >= 0.0 else RIM): continue
			var reach := REACH if _site.rim < 0.0 else clampf(e-0.02,0.0,REACH)
			var tuft := _site.tuft_size if _site.tuft_size != Vector2.ZERO else TUFT_SIZE
			var size := _rng.randf_range(tuft.x,tuft.y)*lerpf(1.0,0.75,worn)
			var wild := _wild(p,e) if _site.shag > 0.0 or _site.variety else 0.0
			if _site.shag > 0.0 or _site.tuft_bump != 1.0: size *= _shag(p,wild)
			if _site.height_field > 0.0: size *= 1.0+_site.height_field*rolling
			if _site.variety: _tuft(p,size,e,wild,reach)
			else: _add("grass_tuft",p,size,{},reach)
		# Flowers: the meadow type's drifts, sown sparse.
		var sizes: Dictionary = _meadow.type.sizes
		while _phase == 1:
			if _n >= _flowers:
				_phase = 2
				_draw = Draw.new(_records,_ground,_area)
				_draw.plain = _site.plain
				if _site.grass_range > 0.0: _draw.grass_range = _site.grass_range
				if _site.lod != Vector4.ZERO:
					_draw.ring = {"lod":_site.lod,"share":_site.lod_share,"grow":_site.lod_grow,"soft":_site.lod_soft}
					_draw.ring_seed = _seed
				break
			_n += 1
			if usec >= 0 and _n % CHECK_EVERY == 0 and Time.get_ticks_usec() > end:
				_n -= 1
				return false
			if _site.stable: _rng.seed = hash([_seed,1,_n])
			var p := Vector2(_rng.randf_range(_box.position.x,_box.end.x),_rng.randf_range(_box.position.y,_box.end.y))
			var presence := _meadow.presence(p)
			var kind := _meadow.kind_at(p,_rng.randf())
			var variant := -1.0
			if _site.flower_kind.is_valid():
				var got: Array = _site.flower_kind.call(p,kind)
				if not got.is_empty():
					kind = str(got[0])
					variant = float(got[1])
			var keep := pow(presence,1.2)*MeadowTypes.packing(kind)*FLOWER_SHARE
			if _site.flower_drift.is_valid(): keep *= float(_site.flower_drift.call(p))
			if _rng.randf() > maxf(keep,STRAY): continue
			if _site.worn(p) > PATH_THIN or _edges.upto(p) < RIM+0.3: continue
			var range_of: Array = sizes.get(kind,[0.85,1.1])
			var lift := float(_site.flower_lift.call(p)) if _site.flower_lift.is_valid() else 1.0
			var formed: Array = MeadowTypes.form(kind,_rng.randf_range(float(range_of[0]),float(range_of[1])),_rng.randf()*TAU,lift)
			var extra := {}
			var tint := MeadowTypes.tint(kind,variant if variant >= 0.0 else _meadow.variant(p))
			if tint != "": extra.tint = tint
			if not (formed[1] as Dictionary).is_empty(): extra.pose = formed[1]
			_add(MeadowTypes.asset(kind),p,float(formed[0]),extra)
		if _phase == 2:
			if not _draw.step(maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1): return false
			node = _draw.node
			parts = _draw.parts
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
	const STABLE_TRIES := 3
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
	var _seed := 0

	func _init(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array, site: Site) -> void:
		_site = site
		_outlines = outlines
		_edges = EdgeIndex.new(outlines)
		_seed = seed_value
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
			# Stable: a fixed run of candidates a kind (STABLE_TRIES each
			# wanted), not "until enough are placed", so a plant refused by an
			# edit doesn't let one in elsewhere.
			if (not _site.stable and _placed >= want) or _n >= want*(STABLE_TRIES if _site.stable else 14):
				_kind += 1
				_n = 0
				_placed = 0
				continue
			if usec >= 0 and Time.get_ticks_usec() > end: return false
			_n += 1
			if _site.stable: _rng.seed = hash([_seed,2,_kind,_n])
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
			if _n >= 400 or _logs >= (LOGS*2 if _site.stable else LOGS):
				_phase = 2
				_draw = Draw.new(_records,_ground,_area,UNDER_TILE)
				break
			if usec >= 0 and Time.get_ticks_usec() > end: return false
			_n += 1
			if _site.stable: _rng.seed = hash([_seed,3,_n])
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
	## Plain data in place of nodes (see Site.plain): [{key, tile, count, buffer}].
	var plain := false
	## How far the grass draws (m).
	var grass_range := GRASS_RANGE
	## The site's distance rings (Site `lod`: {lod, share, grow, soft}); empty: off.
	var ring := {}
	var ring_seed := 0
	var parts: Array = []
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
				if not ring.is_empty() and KitFlora.ringed(key):
					_rings(key,tile,list,colours)
					continue
				# One upload, not two renderer calls an instance (each tile's
				# went 20-30 ms over its slice rendered).
				var buffer := KitFlora.batch_buffer(list,colours)
				if plain:
					parts.append({"key":key,"tile":tile,"count":list.size(),"buffer":buffer})
				else:
					node.add_child(KitFlora.batch_node(key,tile,list.size(),buffer,grass_range))
				_instances[key] = int(_instances.get(key,0))+list.size()
				if not plain: _triangles += KitFlora._mesh_triangles(meshes[key])*list.size()
		var counts := {}
		for item: Dictionary in _records: counts[item.asset] = int(counts.get(item.asset,0))+1
		node.set_meta("records",_records)
		node.set_meta("counts",counts)
		node.set_meta("instances",_instances)
		node.set_meta("triangles",_triangles)
		node.set_meta("area",_area)
		return true

	## One tile's grass in its two rings (Site `lod`): `ring.share` of the
	## tufts, drawn by lot, to the mid ring (the cheaper tuft), the rest to
	## the near ring; as nodes, or as plain parts carrying their `ring`.
	func _rings(key: String, tile: Vector2i, list: Array, colours: Array) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([ring_seed,key,tile])
		var split := [[[],[]],[[],[]]]
		for i in range(list.size()):
			var k := 1 if rng.randf() < float(ring.share) else 0
			(split[k][0] as Array).append(list[i])
			(split[k][1] as Array).append(colours[i] if i < colours.size() else Color.WHITE)
		for k in range(2):
			var got: Array = split[k][0]
			if got.is_empty(): continue
			var buffer := KitFlora.batch_buffer(got,split[k][1])
			var r := ring.duplicate()
			r.ring = k+1
			if plain:
				parts.append({"key":key,"tile":tile,"count":got.size(),"buffer":buffer,"ring":r})
			else:
				var batch := KitFlora.batch_node(key,tile,got.size(),buffer,grass_range,r)
				node.add_child(batch)
				_triangles += KitFlora._mesh_triangles(batch.multimesh.mesh)*got.size()
			_instances[key] = int(_instances.get(key,0))+got.size()

## One tile's batch of one catalog part, as Draw makes it (the main
## thread: it makes a material). `buffer` as `batch_buffer`. Opt-in: `mesh`
## drawn in place of the part's own (set before the buffer: set after, the
## multimesh works its bounds out again over every instance).
static func batch_node(key: String, tile: Vector2i, count: int, buffer: PackedFloat32Array, grass_range := GRASS_RANGE, ring := {}, mesh: Mesh = null) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var k := int(ring.get("ring",0))
	multimesh.mesh = mesh if mesh != null else (KitFlora.lite_tuft(key) if k == 2 else SkyIslets.catalog().meshes[key])
	multimesh.instance_count = count
	multimesh.buffer = buffer
	var batch := MultiMeshInstance3D.new()
	batch.name = "%s_%d_%d" % [key.replace(":","_"),tile.x,tile.y]
	batch.multimesh = multimesh
	batch.material_override = SkyIslets._plant_material(key)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = grass_range if key.begins_with("grass") else FLOWER_RANGE
	batch.visibility_range_end_margin = FADE
	batch.visibility_range_fade_mode = KitFlora.fade_mode()
	batch.set_meta("part",key)
	if k > 0:
		# A ringed batch: its tufts are all gone (the shader's ring) by the
		# band's end, so the tile stops there, past its farthest tuft.
		var lod: Vector4 = ring.lod
		batch.name += "_near" if k == 1 else "_mid"
		batch.material_override = KitFlora.ring_material(key,ring)
		batch.visibility_range_end = (lod.y if k == 1 else lod.w)+TILE*0.75
		batch.visibility_range_end_margin = 2.0
		batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		batch.set_meta("ring",k)
	return batch

## Whether `key`'s batches take the distance rings (the soft grass tuft).
static func ringed(key: String) -> bool:
	var mesh: Variant = (SkyIslets.catalog().meshes as Dictionary).get(key)
	return key.begins_with("grass") and mesh is Mesh and (mesh as Mesh).has_meta("grass_root")

static var _lite := {}
static var _ring_materials := {}
static var _ring_lock := Mutex.new()

## The mid ring's cheaper tuft for `key` (GrassTuft.build_lite, its colours).
static func lite_tuft(key: String) -> Mesh:
	_ring_lock.lock()
	if not _lite.has(key):
		var full: Mesh = SkyIslets.catalog().meshes[key]
		_lite[key] = preload("res://scripts/grass_tuft_mesh.gd").build_lite(full.get_meta("grass_root"),full.get_meta("grass_tip"))
	var mesh: Mesh = _lite[key]
	_ring_lock.unlock()
	return mesh

## `key`'s plant material with its ring set (reference_surface `grass_ring`,
## `grass_ring_grow`): one copy a key, ring and band set.
static func ring_material(key: String, ring: Dictionary) -> Material:
	var k := int(ring.ring)
	var lod: Vector4 = ring.lod
	var grow: Vector2 = ring.grow
	var soft := float(ring.soft)
	var id := [key,k,lod,grow,soft]
	if _ring_materials.has(id): return _ring_materials[id]
	var m := SkyIslets._plant_material(key)
	if m is ShaderMaterial:
		m = m.duplicate()
		var band := Vector4(lod.x,lod.y,soft,0.0) if k == 1 else Vector4(lod.z,lod.w,soft,0.0)
		(m as ShaderMaterial).set_shader_parameter("grass_ring",band)
		if k == 2: (m as ShaderMaterial).set_shader_parameter("grass_ring_grow",Vector4(lod.x,lod.y,grow.x,grow.y))
	_ring_materials[id] = m
	return m

## Each mesh's triangle count, by its instance id: reading a mesh's arrays
## back from the renderer waits for the GPU to finish every frame in flight,
## and Draw asked it of the same few plant meshes for every batch.
static var _triangles_of := {}

static func _mesh_triangles(mesh: Mesh) -> int:
	var id := mesh.get_instance_id()
	if not _triangles_of.has(id): _triangles_of[id] = _count_triangles(mesh)
	return int(_triangles_of[id])

static func _count_triangles(mesh: Mesh) -> int:
	var count := 0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		count += (idx.size() if idx != null and idx is PackedInt32Array and idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3
	return count
