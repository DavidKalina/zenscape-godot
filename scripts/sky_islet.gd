extends RefCounted
## One small islet floating between the sky islands (scripts/sky_islets.gd):
## scenery to fly past, round and under, and to perch on. Nothing is built on
## it and nothing on it is simulated, but it is made the way the islands
## are, only small, so it reads as cut from the same world:
##   the grid: the plate's own triangulation (scripts/plate_mesh.gd: points
##     Plate.POINT_STEP apart, nudged by the same fixed hash, every square
##     split along the same diagonal), over a square just large enough for
##     the islet (`_grid`, cached by size);
##   the outline: the islands' own (scripts/island_outline.gd `mask`, asked
##     for the islet's land in m^2 on its small grid), so it is lobed, bayed
##     and warped as an island is; then its shore distance and edges;
##   the top: heights on the grid's points, a seeded field by kind (KINDS)
##     eased to Genesis RIM_HEIGHT over the last metres before the shore as
##     the plain is (scripts/genesis_canvas.gd `shape`), drawn as the plate
##     draws its ground: one flat face a triangle in the world's grass greens,
##     rock where a face is steeper than the palette's rock slope, sand at a
##     pond's bank and on a beach;
##   the sides: the islands' shore wall and the hanging rock under the land
##     (scripts/island_shore.gd: its facet ring, `keel`), from a shallower
##     foot (BASE), in the earth sides' strata;
##   what grows: object records like the plate's ({asset, x, z, angle, scale,
##     tint}), drawn with the plate's own catalog (GardenView, through
##     scripts/garden_instance_samples.gd `add_item`): the world's tree
##     species, its meadow flowers, grass tufts, ferns, shrubs, mushrooms,
##     logs, reeds and stones.
## Kinds (KINDS): meadow, open grass in drifts of flowers with a tree or two;
## grove, a wood of one or two species over ferns and fallen wood; hills,
## grassy mounds turning to rock where steep, with stones; crag, a rocky
## knoll, a juniper or spruce clinging on; spring, a pond whose water leaves
## over a lip in the rim (the fall, sky_islets.gd), reeds round it; shore, a
## low islet ringed with sand and gravel, reeds and driftwood.
##
## The frame is the islet's own: its grid's middle at the origin, y up, the
## rim near RIM_HEIGHT. Every query (`ground_at`, `underside`, `inside`) reads
## the same faces the mesh draws.

const Plate = preload("res://scripts/plate.gd")
const PlateMesh = preload("res://scripts/plate_mesh.gd")
const IslandOutline = preload("res://scripts/island_outline.gd")
const IslandShore = preload("res://scripts/island_shore.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const Emergence = preload("res://scripts/emergence.gd")
const Stands = preload("res://scripts/tree_stands.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Samples = preload("res://scripts/garden_instance_samples.gd")

## Kinds and how often each turns up.
const KINDS := [["meadow",0.22],["grove",0.22],["hills",0.15],["crag",0.11],["spring",0.18],["shore",0.12]]
## How wide (m) the islet is, by kind: the width of a circle of its land.
const ACROSS := {"meadow":Vector2(6.0,13.0),"grove":Vector2(8.0,15.0),"hills":Vector2(9.0,15.0),
	"crag":Vector2(5.5,11.0),"spring":Vector2(9.0,14.0),"shore":Vector2(5.5,11.0)}
## The grid reaches this many times the islet's radius past its middle, plus
## MARGIN m, so the outline's lobes and the rim's band fit.
const REACH := 1.45
const MARGIN := 3.2
## The grid's step and nudge: the plate's (scripts/plate_mesh.gd).
const STEP := Plate.POINT_STEP
## The shore's ease: the ground meets RIM_HEIGHT this far in (m), at most
## a share of the islet's radius.
const RIM_HEIGHT := Genesis.RIM_HEIGHT
const RIM_EASE := 2.5
const RIM_EASE_SHARE := 0.4
## The rolling ground (as the plain's swell and ripple, finer for the small
## islet): base height, swell (m, 1/m), ripple (m, 1/m), and the dome a kind
## rises to inland (m).
const GROUND := 0.32
const SWELL := Vector2(0.42,0.085)
const RIPPLE := Vector2(0.1,0.25)
const DOME := {"meadow":0.5,"grove":0.65,"hills":0.35,"crag":0.4,"spring":0.45,"shore":0.12}
## Hills: how many mounds, their height (m) and radius (share of the islet's).
const MOUNDS := Vector2i(1,3)
const MOUND := Vector2(1.4,3.0)
const MOUND_SIZE := Vector2(0.4,0.7)
## The crag: its peak (m), its reach (share of the radius), the ridged
## noise's height (m), and a second, lower knob (share of the peak).
const PEAK := Vector2(3.0,5.5)
const PEAK_SIZE := Vector2(0.6,0.85)
const RIDGE := 0.9
const KNOB := Vector2(0.35,0.6)
## The earth wall's foot under the rim (m): BASE.x plus BASE.y a metre of
## radius. The hanging rock (IslandShore `keel`) hangs from it.
const BASE := Vector2(1.5,0.25)
## The pond: its radius (m, and share of the islet's radius at most), the
## bowl's depth under the water, the water's level, and the channel's half
## width (m) out to the lip on the rim, where the fall pours off.
const POND := Vector2(1.5,3.0)
const POND_SHARE := 0.34
const BOWL := 0.55
const WATER := RIM_HEIGHT-0.1
const CHANNEL := 0.75
const BANK := 0.28
## The water's arrays carry the fetch as two float vec4s.
const WATER_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
## Where the bowl's bank meets the water, as a share of the pond's radius.
const SHORE := 0.85
## A beach (shore kind): sand this far in from the shore (m), gravel in
## patches through it.
const BEACH := 1.5
## What grows, by kind. Trees: how many a square metre, at least and most,
## and the species pool (Stands TREE_POOLS' weights); a dominant species and
## a companion are drawn from it per islet, the dominant taking PURITY.
const TREE_DENSITY := {"meadow":0.012,"grove":0.06,"hills":0.022,"crag":0.018,"spring":0.025,"shore":0.012}
const TREE_COUNT := {"meadow":Vector2i(1,3),"grove":Vector2i(4,14),"hills":Vector2i(1,5),"crag":Vector2i(1,2),"spring":Vector2i(1,4),"shore":Vector2i(0,2)}
const TREE_POOLS := {
	"meadow":{"broadleaf":1.0,"birch":0.8,"layered_tree":0.6,"tree":0.4,"willow":0.25},
	"grove":{"tree":1.0,"broadleaf":1.0,"birch":0.7,"layered_tree":0.5,"redwood":0.45,"juniper":0.25,"willow":0.15},
	"hills":{"tree":1.0,"juniper":0.7,"birch":0.5,"broadleaf":0.45},
	"crag":{"juniper":1.0,"tree":1.0},
	"spring":{"willow":1.0,"birch":0.8,"broadleaf":0.6,"tree":0.4,"layered_tree":0.3},
	"shore":{"willow":0.8,"juniper":0.6,"birch":0.5},
}
const PURITY := Vector2(0.6,0.9)
## Trees keep this far apart (m, times their record scale), in from the shore
## (m), and off ground steeper than TREE_STEEP.
const TREE_APART := 2.2
const TREE_IN := 1.0
const TREE_STEEP := 0.8
## Flower drifts: the odds an islet has any, how many, flowers a drift and
## its spread (m), and the kinds it draws from (MeadowTypes FLOWER_KEYS).
## Each islet takes FLOWER_KINDS of them; sunflowers come up as a small
## stand of their own.
const FLOWER_ODDS := {"meadow":1.0,"grove":0.6,"hills":0.85,"crag":0.5,"spring":0.85,"shore":0.6}
const DRIFTS := {"meadow":Vector2i(3,6),"grove":Vector2i(1,2),"hills":Vector2i(1,3),"crag":Vector2i(1,1),"spring":Vector2i(1,3),"shore":Vector2i(1,2)}
const DRIFT_SIZE := Vector2i(7,20)
const DRIFT_SPREAD := Vector2(0.7,1.5)
const FLOWER_POOLS := {
	"meadow":{"oxeye_daisy":1.0,"buttercup":0.9,"cosmos":0.8,"poppy":0.8,"lupine":0.6,"dandelion":0.6,"sunflower":0.45},
	"grove":{"oxeye_daisy":1.0,"lupine":0.8,"buttercup":0.6},
	"hills":{"poppy":1.0,"lupine":0.8,"buttercup":0.7,"oxeye_daisy":0.6,"sunflower":0.25},
	"crag":{"lupine":1.0,"oxeye_daisy":0.6},
	"spring":{"buttercup":1.0,"oxeye_daisy":0.8,"cosmos":0.6,"dandelion":0.6},
	"shore":{"poppy":1.0,"oxeye_daisy":0.8,"cosmos":0.6},
}
const FLOWER_KINDS := Vector2i(1,3)
const FLOWER_SIZE := Vector2(0.8,1.15)
const SUNFLOWERS := Vector2i(3,8)
## Grass tufts a square metre of grass, and the undergrowth by kind:
## [asset, count a square metre, size range] (counts are the mean; each
## islet draws round it).
const TUFTS := 0.35
const UNDERGROWTH := {
	"meadow":[["shrub",0.01,Vector2(0.5,0.9)],["dandelion_clock",0.02,Vector2(0.8,1.1)]],
	"grove":[["fern",0.05,Vector2(0.5,0.75)],["shrub",0.02,Vector2(0.5,0.9)],["mushroom",0.03,Vector2(0.6,1.1)],
		["log",0.008,Vector2(0.75,1.0)],["stump",0.008,Vector2(0.6,0.95)]],
	"hills":[["shrub",0.015,Vector2(0.5,0.9)]],
	"crag":[["shrub",0.01,Vector2(0.45,0.8)]],
	"spring":[["fern",0.015,Vector2(0.5,0.7)],["shrub",0.01,Vector2(0.5,0.9)]],
	"shore":[["log",0.012,Vector2(0.75,1.0)]],
}
## Stones: how many on the islet (and their size), the boulders' kinds.
const STONES := {"meadow":Vector2i(0,1),"grove":Vector2i(0,2),"hills":Vector2i(2,4),"crag":Vector2i(4,8),"spring":Vector2i(1,3),"shore":Vector2i(1,3)}
const STONE_SIZE := Vector2(0.45,1.3)
const BOULDERS := ["boulder_1","boulder_2","boulder_3","boulder_4","rock"]
## Reeds and bank grass round a pond's water and along a beach.
const REEDS := Vector2i(6,14)
## A walker can't step within this share of a stone's reach, or a trunk's
## TRUNK m (times the tree's record scale).
const TRUNK := 0.35
const STONE_BLOCK := 0.6

static var _grids := {}
static var _grid_lock := Mutex.new()

var seed := 0
var kind := "meadow"
## The radius of a circle of the islet's land (m), and the farthest any of
## its land reaches from the middle.
var radius := 5.0
var reach := 5.0
## The grid: its points, three ids a face, cells a side and half its width.
var points := PackedVector2Array()
var ids := PackedInt32Array()
var cells := 0
var half := 0.0
## The outline (a byte a face, 0 on the land: IslandOutline `mask`), each
## point's metres in from the shore (-1 off the land), the shore's edges.
var outline := PackedByteArray()
var shore_distance := PackedFloat32Array()
var shore_edges := PackedInt32Array()
## Each point's ground height, and how far under BASE the rock hangs.
var heights := PackedFloat32Array()
var keel := PackedFloat32Array()
## The wall's foot (m, under 0), and how deep the islet hangs at its deepest
## (m, positive).
var base := -2.5
var depth := 8.0
## The land's faces (indices into the faces).
var land := PackedInt32Array()
## The pond (x, z, radius), zero radius if none; the lip on the rim where
## the channel leaves, and the way out.
var pond := Vector3.ZERO
var lip := Vector2.ZERO
var lip_out := Vector2.ZERO
## What grows: object records, as the plate's.
var objects: Array[Dictionary] = []
## Trees and stones, for the glide and the walker: crowns (x, z, top over
## the ground, reach) and blocks (x, z, radius).
var crowns: Array[Vector4] = []
var blocks: Array[Vector3] = []
## The tree species and flower kinds standing on it, for the curious.
var species: Array[String] = []
var flowers: Array[String] = []

## The islet for `seed` (a hash from its cell), of `kind` if given, or one
## drawn by the seed.
static func make(seed_value: int, forced := "") -> RefCounted:
	var islet: RefCounted = new()
	islet._shape(seed_value,forced)
	return islet

static func pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k: Array in KINDS: total += float(k[1])
	var roll := rng.randf()*total
	for k: Array in KINDS:
		roll -= float(k[1])
		if roll <= 0.0: return k[0]
	return KINDS[0][0]

func _shape(seed_value: int, forced: String) -> void:
	seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	kind = forced if forced != "" else pick_kind(rng)
	var across: Vector2 = ACROSS[kind]
	radius = rng.randf_range(across.x,across.y)*0.5
	var area := PI*radius*radius
	var grid := _grid(ceili((radius*REACH+MARGIN)/STEP))
	points = grid.points
	ids = grid.ids
	cells = grid.cells
	half = grid.half
	outline = IslandOutline.mask(points,ids,seed_value,-1.0,half,area)
	shore_distance = IslandOutline.shore_distance(points,ids,outline)
	shore_edges = IslandOutline.shore_edges(ids,outline)
	land.clear()
	for f in range(outline.size()):
		if outline[f] == 0: land.append(f)
	reach = 0.0
	for i in range(points.size()):
		if shore_distance[i] >= 0.0: reach = maxf(reach,points[i].length())
	_lay_ground(rng)
	keel = IslandShore.keel(points,ids,outline,shore_distance)
	base = -(BASE.x+BASE.y*radius)
	var deepest := 0.0
	for k in keel: deepest = maxf(deepest,k)
	depth = -base+deepest
	_plant(rng)

## The grid of `n` cells each way from the middle (2n a side), the plate's
## own triangulation: [points, ids, cells a side, half width]. Cached, and
## shared by every islet of its size (read only).
static func _grid(n: int) -> Dictionary:
	_grid_lock.lock()
	var made: Variant = _grids.get(n)
	_grid_lock.unlock()
	if made != null: return made
	var side := n*2
	var span := float(n)*STEP
	var at := PackedVector2Array()
	var plain := PackedVector2Array()
	at.resize((side+1)*(side+1))
	plain.resize(at.size())
	var reach := PlateMesh.NUDGE*STEP
	for j in range(side+1):
		for i in range(side+1):
			var p := Vector2(-span+i*STEP,-span+j*STEP)
			plain[j*(side+1)+i] = p
			if i > 0 and j > 0 and i < side and j < side:
				p += Vector2(PlateMesh._hash(i,j,1)*2.0-1.0,PlateMesh._hash(i,j,2)*2.0-1.0)*reach
			at[j*(side+1)+i] = p
	var faces := PackedInt32Array()
	for j in range(side):
		for i in range(side):
			var a := j*(side+1)+i
			faces.append_array([a,a+1,a+side+1,a+side+1,a+1,a+side+2])
	# As the plate: a face come out too sharp has its corners eased back.
	for _pass in range(6):
		var eased := false
		for f in range(0,faces.size(),3):
			if PlateMesh._sharpest(at[faces[f]],at[faces[f+1]],at[faces[f+2]]) >= PlateMesh.SHARPEST: continue
			for k in range(3): at[faces[f+k]] = plain[faces[f+k]].lerp(at[faces[f+k]],0.5)
			eased = true
		if not eased: break
	made = {"points":at,"ids":faces,"cells":side,"half":span}
	_grid_lock.lock()
	_grids[n] = made
	_grid_lock.unlock()
	return made

static func forget_grids() -> void:
	_grid_lock.lock()
	_grids.clear()
	_grid_lock.unlock()

# --- The ground -----------------------------------------------------------------

## Heights on every point: the kind's field, eased to the rim, then a
## spring's pond and channel cut in.
func _lay_ground(rng: RandomNumberGenerator) -> void:
	var swell := FastNoiseLite.new()
	swell.seed = seed
	swell.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	swell.frequency = SWELL.y
	swell.fractal_octaves = 2
	var ripple := FastNoiseLite.new()
	ripple.seed = seed+17
	ripple.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ripple.frequency = RIPPLE.y
	ripple.fractal_octaves = 2
	var ridge := FastNoiseLite.new()
	ridge.seed = seed+29
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge.frequency = 0.35
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 2
	var inland := 0.01
	for d in shore_distance: inland = maxf(inland,d)
	# The kind's shapes: mounds (hills), a peak and its knob (crag).
	var mounds: Array[Vector4] = []
	if kind == "hills":
		for k in range(rng.randi_range(MOUNDS.x,MOUNDS.y)):
			var at := _inland_point(rng,inland*0.35)
			mounds.append(Vector4(at.x,at.y,radius*rng.randf_range(MOUND_SIZE.x,MOUND_SIZE.y),rng.randf_range(MOUND.x,MOUND.y)))
	elif kind == "crag":
		var at := _inland_point(rng,inland*0.5)
		var peak := rng.randf_range(PEAK.x,PEAK.y)
		mounds.append(Vector4(at.x,at.y,radius*rng.randf_range(PEAK_SIZE.x,PEAK_SIZE.y),peak))
		var knob := _inland_point(rng,inland*0.2)
		mounds.append(Vector4(knob.x,knob.y,radius*rng.randf_range(0.35,0.5),peak*rng.randf_range(KNOB.x,KNOB.y)))
	var ease := minf(RIM_EASE,radius*RIM_EASE_SHARE)
	heights.resize(points.size())
	for i in range(points.size()):
		var d := shore_distance[i]
		if d < 0.0:
			heights[i] = RIM_HEIGHT
			continue
		var p := points[i]
		var roll := swell.get_noise_2d(p.x,p.y)*SWELL.x+ripple.get_noise_2d(p.x,p.y)*RIPPLE.x
		var dome := float(DOME[kind])*smoothstep(0.0,1.0,d/inland)
		# A beach lies low and nearly flat.
		var h := RIM_HEIGHT+0.05+roll*0.3+dome if kind == "shore" else GROUND+roll+dome
		for m in mounds:
			var r := p.distance_to(Vector2(m.x,m.y))/m.z
			if r >= 1.0: continue
			if kind == "crag":
				var fall := pow(1.0-r,1.2)
				h += m.w*fall+RIDGE*fall*(ridge.get_noise_2d(p.x,p.y)*0.5+0.5)
			else:
				h += m.w*(1.0-r*r)*(1.0-r*r)
		heights[i] = lerpf(RIM_HEIGHT,h,smoothstep(0.0,ease,d))
	if kind == "spring": _cut_pond(rng,inland)

## A land point at least `inside` m in from the shore, seeded; the middle if
## none.
func _inland_point(rng: RandomNumberGenerator, inside: float) -> Vector2:
	var choices := PackedInt32Array()
	for i in range(points.size()):
		if shore_distance[i] >= inside: choices.append(i)
	if choices.is_empty(): return Vector2.ZERO
	return points[choices[rng.randi_range(0,choices.size()-1)]]

## The spring: a pond in the most inland ground, its banks standing over
## its water, and a channel to the nearest shore point, the lip, cut under
## the water's level so it leaves there.
func _cut_pond(rng: RandomNumberGenerator, inland: float) -> void:
	var middle := _inland_point(rng,inland*0.85)
	var r := clampf(inland*0.6,POND.x,minf(POND.y,radius*POND_SHARE))
	pond = Vector3(middle.x,middle.y,r)
	# The lip: the shore point nearest the pond, a little seeded among the
	# nearest few, so the channel is short.
	var shore := []
	for k in range(0,shore_edges.size(),3):
		var i := shore_edges[k]
		shore.append([points[i].distance_to(middle),i])
	shore.sort()
	var pick: int = shore[rng.randi_range(0,mini(2,shore.size()-1))][1]
	lip = points[pick]
	var outward: Dictionary = IslandShore._outward(points,shore_edges)
	lip_out = outward.get(pick,(lip-middle).normalized())
	for i in range(points.size()):
		if shore_distance[i] < 0.0: continue
		var p := points[i]
		var h := heights[i]
		var d := p.distance_to(middle)/r
		var cut := 1.0-smoothstep(CHANNEL*0.8,CHANNEL*1.45,_channel_distance(p))
		# The bank stands over the water all round, but where the channel runs.
		if d < 1.8 and cut <= 0.0: h = maxf(h,WATER+BANK*(1.0-smoothstep(1.2,1.8,d))+0.06)
		var bowl := 1.0-smoothstep(0.55,1.15,d)
		h = minf(h,lerpf(h,WATER-BOWL,bowl))
		h = minf(h,lerpf(h,WATER-0.14,cut))
		heights[i] = h

## The pond's water in the islet frame: level, middle and radius, with the
## lip and the way out; empty if the islet has none.
func water() -> Dictionary:
	if pond.z <= 0.0: return {}
	return {"level":WATER,"middle":Vector2(pond.x,pond.y),"radius":pond.z,"lip":lip,"out":lip_out}

func _channel_distance(p: Vector2) -> float:
	if pond.z <= 0.0: return INF
	var a := Vector2(pond.x,pond.y)
	var ab := lip-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
	return p.distance_to(a+ab*t)

## True over the pond's water or its channel.
func wet(p: Vector2) -> bool:
	if pond.z <= 0.0: return false
	return p.distance_to(Vector2(pond.x,pond.y)) < pond.z*1.05 or _channel_distance(p) < CHANNEL

# --- Reading it -----------------------------------------------------------------

## The land face holding `p`, as Vector4(face, weights a, b, c's first two),
## or face -1 off the land.
func _locate(p: Vector2) -> Array:
	var i := floori((p.x+half)/STEP)
	var j := floori((p.y+half)/STEP)
	for dj in [0,-1,1]:
		for di in [0,-1,1]:
			var ci: int = i+di
			var cj: int = j+dj
			if ci < 0 or cj < 0 or ci >= cells or cj >= cells: continue
			for side in range(2):
				var f := (cj*cells+ci)*2+side
				var w := _barycentric(p,points[ids[f*3]],points[ids[f*3+1]],points[ids[f*3+2]])
				if w.x >= -0.0001 and w.y >= -0.0001 and w.z >= -0.0001:
					return [f if outline[f] == 0 else -1,w]
	return [-1,Vector3.ZERO]

func inside(p: Vector2) -> bool:
	if absf(p.x) > reach+0.5 or absf(p.y) > reach+0.5: return false
	return int(_locate(p)[0]) >= 0

## A per-point value at `p` on the faces it is drawn on, or `fallback` off
## the land.
func _sample(values: PackedFloat32Array, p: Vector2, fallback: float) -> float:
	var hit := _locate(p)
	var f: int = hit[0]
	if f < 0: return fallback
	var w: Vector3 = hit[1]
	return w.x*values[ids[f*3]]+w.y*values[ids[f*3+1]]+w.z*values[ids[f*3+2]]

## The ground's height as drawn, at a point inside (islet frame); off the
## land, the rim's height.
func ground_at(p: Vector2) -> float:
	return _sample(heights,p,RIM_HEIGHT)

func top(p: Vector2) -> float:
	return ground_at(p)

## Metres in from the shore at `p`, 0 off the land.
func inland(p: Vector2) -> float:
	return maxf(_sample(shore_distance,p,0.0),0.0)

## The rock's underside under a point inside.
func underside(p: Vector2) -> float:
	return base-_sample(keel,p,0.0)

## The height the glide rides over: the ground, the crowns, the stones.
func solid_top(p: Vector2) -> float:
	var h := ground_at(p)
	for c in crowns:
		if p.distance_to(Vector2(c.x,c.y)) < c.w: h = maxf(h,ground_at(Vector2(c.x,c.y))+c.z)
	return h

## How far out toward the rim a point is along its ray from the middle: 0 at
## the middle, 1 where the ray first leaves the land.
func share(p: Vector2) -> float:
	if p.length() < 0.0001: return 0.0
	return p.length()/rim_radius(p.angle())

## The rim's distance from the middle at angle `a`: where the ray from the
## middle first leaves the land (the middle is always land).
func rim_radius(a: float) -> float:
	var dir := Vector2.from_angle(a)
	var r := 0.0
	var step := 0.15
	while r < reach+1.0:
		if not inside(dir*(r+step)): break
		r += step
	return maxf(r,0.05)

func rim_point(a: float) -> Vector2:
	return Vector2.from_angle(a)*rim_radius(a)

## True where a walker can't step: a trunk, a stone, the pond's water.
func blocked(at: Vector2) -> bool:
	for b in blocks:
		if at.distance_to(Vector2(b.x,b.y)) < b.z: return true
	return wet(at)

static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b-a
	var v1 := c-a
	var v2 := p-a
	var den := v0.cross(v1)
	if absf(den) < 0.0000001: return Vector3(-1.0,-1.0,-1.0)
	var v := v2.cross(v1)/den
	var w := v0.cross(v2)/den
	return Vector3(1.0-v-w,v,w)

## The land's extent: Rect2 of its points.
func extent() -> Rect2:
	var box := Rect2()
	var first := true
	for i in range(points.size()):
		if shore_distance[i] < 0.0: continue
		if first:
			box = Rect2(points[i],Vector2.ZERO)
			first = false
		else: box = box.expand(points[i])
	return box

func land_area() -> float:
	var total := 0.0
	for f in land:
		var a := points[ids[f*3]]
		total += absf((points[ids[f*3+1]]-a).cross(points[ids[f*3+2]]-a))*0.5
	return total

# --- What grows -------------------------------------------------------------------

## The islet's plants and stones as object records, seeded: trees of its
## species, flower drifts, undergrowth, tufts, stones, reeds.
func _plant(rng: RandomNumberGenerator) -> void:
	objects.clear()
	species.clear()
	flowers.clear()
	var area := land_area()
	var taken: Array[Vector3] = []
	# Stones first: the trees and flowers go round them.
	var stones: Vector2i = STONES[kind]
	for n in range(rng.randi_range(stones.x,stones.y)):
		var size := rng.randf_range(STONE_SIZE.x,STONE_SIZE.y)
		var at: Variant = _find(rng,0.4,99.0,taken,size*0.6,false)
		if at == null: continue
		var asset: String = BOULDERS[rng.randi() % BOULDERS.size()]
		_add(asset,at,rng.randf()*TAU,size)
		taken.append(Vector3(at.x,at.y,size*0.6))
	# Trees: a dominant species and a companion.
	var pool: Dictionary = TREE_POOLS[kind]
	var dominant := _weighted(pool,rng.randf())
	var companion := _weighted(pool,rng.randf())
	var purity := rng.randf_range(PURITY.x,PURITY.y)
	var bounds: Vector2i = TREE_COUNT[kind]
	var want := clampi(roundi(area*float(TREE_DENSITY[kind])*rng.randf_range(0.7,1.3)),bounds.x,bounds.y)
	var tints := {}
	for n in range(want):
		var tree := dominant if rng.randf() < purity else companion
		var size := rng.randf_range(Emergence.TREE_SIZE.x,Emergence.TREE_SIZE.y)*float(Emergence.KIND_SIZE.get(tree,1.0))
		var room := TREE_APART*maxf(size,0.6)*(1.6 if tree in ["layered_tree","broadleaf","willow"] else 1.0)
		var at: Variant = _find(rng,TREE_IN,TREE_STEEP,taken,room*0.5,true)
		if at == null: continue
		if not tints.has(tree): tints[tree] = _tree_tint(tree,rng)
		_add(tree,at,rng.randf()*TAU,size,tints[tree])
		taken.append(Vector3(at.x,at.y,room*0.5))
		if not tree in species: species.append(tree)
	# Flower drifts.
	if rng.randf() < float(FLOWER_ODDS[kind]):
		var kinds: Array[String] = []
		var choices: Dictionary = (FLOWER_POOLS[kind] as Dictionary).duplicate()
		for n in range(rng.randi_range(FLOWER_KINDS.x,FLOWER_KINDS.y)):
			if choices.is_empty(): break
			var k := _weighted(choices,rng.randf())
			choices.erase(k)
			kinds.append(k)
		var drifts: Vector2i = DRIFTS[kind]
		for d in range(rng.randi_range(drifts.x,drifts.y)):
			var flower: String = kinds[d % kinds.size()]
			var middle: Variant = _find(rng,0.6,TREE_STEEP,taken,0.0,true)
			if middle == null: continue
			var variant := rng.randf()
			var tint := MeadowTypes.tint(flower,variant)
			var count := rng.randi_range(SUNFLOWERS.x,SUNFLOWERS.y) if flower == "sunflower" else rng.randi_range(DRIFT_SIZE.x,DRIFT_SIZE.y)
			var spread := rng.randf_range(DRIFT_SPREAD.x,DRIFT_SPREAD.y)*(0.8 if flower == "sunflower" else 1.0)
			var placed := 0
			for n in range(count*3):
				if placed >= count: break
				var p: Vector2 = middle+Vector2(rng.randfn(0.0,spread),rng.randfn(0.0,spread))
				if not _ground_ok(p,0.3,TREE_STEEP,true) or _near(p,taken,0.0): continue
				_add(flower,p,rng.randf()*TAU,rng.randf_range(FLOWER_SIZE.x,FLOWER_SIZE.y),tint)
				placed += 1
			if placed > 0 and not flower in flowers: flowers.append(flower)
	# Undergrowth.
	for entry: Array in UNDERGROWTH[kind]:
		var count := _count(rng,area*float(entry[1]))
		var sizes: Vector2 = entry[2]
		for n in range(count):
			var asset: String = entry[0]
			var at: Variant = _find(rng,0.5,TREE_STEEP,taken,0.25,true)
			if at == null: continue
			if asset == "mushroom":
				# Mushrooms come up in a little ring.
				for m in range(rng.randi_range(3,6)):
					var p: Vector2 = at+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.1,0.45)
					if _ground_ok(p,0.3,TREE_STEEP,true): _add(asset,p,rng.randf()*TAU,rng.randf_range(sizes.x,sizes.y))
				continue
			_add(asset,at,rng.randf()*TAU,rng.randf_range(sizes.x,sizes.y))
			if asset in ["log","stump"]: taken.append(Vector3(at.x,at.y,0.5))
	# Reeds and bank grass round the pond's water, and along a beach.
	if pond.z > 0.0:
		for n in range(rng.randi_range(REEDS.x,REEDS.y)):
			var a := rng.randf()*TAU
			var p := Vector2(pond.x,pond.y)+Vector2.from_angle(a)*pond.z*rng.randf_range(0.95,1.3)
			if not inside(p) or _channel_distance(p) < CHANNEL*1.2: continue
			_add("reeds" if rng.randf() < 0.6 else "bank_grass",p,rng.randf()*TAU,rng.randf_range(0.6,1.0))
	if kind == "shore":
		for n in range(rng.randi_range(REEDS.x,REEDS.y)):
			var at: Variant = _find(rng,BEACH*0.8,TREE_STEEP,taken,0.0,false,BEACH*1.5)
			if at == null: continue
			_add("reeds" if rng.randf() < 0.5 else "bank_grass",at,rng.randf()*TAU,rng.randf_range(0.6,1.0))
	# Grass tufts over the grass, thicker round trunks and stones.
	for n in range(_count(rng,area*TUFTS)):
		var at: Variant = _find(rng,0.25,TREE_STEEP,[],0.0,true)
		if at == null: continue
		_add("grass_tuft",at,rng.randf()*TAU,rng.randf_range(0.7,1.2))
	for t in taken:
		for n in range(rng.randi_range(1,3)):
			var p := Vector2(t.x,t.y)+Vector2.from_angle(rng.randf()*TAU)*(t.z*rng.randf_range(0.5,0.9)+0.2)
			if _ground_ok(p,0.25,TREE_STEEP,true): _add("grass_tuft",p,rng.randf()*TAU,rng.randf_range(0.6,1.0))

## A seeded count round a mean: its whole part, and one more at the odds of
## the rest.
static func _count(rng: RandomNumberGenerator, mean: float) -> int:
	mean *= rng.randf_range(0.6,1.4)
	return int(mean)+(1 if rng.randf() < mean-floorf(mean) else 0)

## A seeded spot on ground that suits (`_ground_ok`), clear of `taken`
## (x, z, radius) by `room` more; null after a few tries. `most` keeps it
## within that many metres of the shore.
func _find(rng: RandomNumberGenerator, inset: float, steep: float, taken: Array, room: float, grassy: bool, most := INF) -> Variant:
	for attempt in range(24):
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		if not _ground_ok(p,inset,steep,grassy): continue
		if most < INF and inland(p) > most: continue
		if _near(p,taken,room): continue
		return p
	return null

func _near(p: Vector2, taken: Array, room: float) -> bool:
	for t: Vector3 in taken:
		if p.distance_to(Vector2(t.x,t.y)) < t.z+room: return true
	return false

## Ground a plant stands on: on the land at least `inset` m in from the
## shore, no steeper than `steep`, dry, and (if `grassy`) grass rather than
## a beach.
func _ground_ok(p: Vector2, inset: float, steep: float, grassy: bool) -> bool:
	var hit := _locate(p)
	var f: int = hit[0]
	if f < 0: return false
	if inland(p) < inset or wet(p): return false
	if pond.z > 0.0 and p.distance_to(Vector2(pond.x,pond.y)) < pond.z*1.25: return false
	if _slope(f) > steep: return false
	if grassy and kind == "shore" and inland(p) < BEACH: return false
	return true

## A face's slope (rise over run).
func _slope(f: int) -> float:
	var n := _face_normal(f)
	return sqrt(maxf(0.0,1.0-n.y*n.y))/maxf(n.y,0.001)

func _face_normal(f: int) -> Vector3:
	var a := _vertex(ids[f*3])
	var b := _vertex(ids[f*3+1])
	var c := _vertex(ids[f*3+2])
	var n := (c-a).cross(b-a)
	return n.normalized() if n.y >= 0.0 else -n.normalized()

func _vertex(i: int) -> Vector3:
	return Vector3(points[i].x,heights[i],points[i].y)

func _add(asset: String, at: Vector2, angle: float, size: float, tint := "") -> void:
	var item := {"id":objects.size()+1,"asset":asset,"x":at.x,"z":at.y,"angle":angle,"scale":size}
	if tint != "": item.tint = tint
	objects.append(item)

## What the garden's instance builder asks of the land a record stands on.
func object_position(item: Dictionary) -> Vector3:
	return Vector3(item.x,ground_at(Vector2(item.x,item.z)),item.z)

static func _weighted(pool: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in pool: total += float(pool[k])
	roll *= total
	for k in pool:
		roll -= float(pool[k])
		if roll <= 0.0: return k
	return pool.keys()[0]

## A crown colour for `tree` (Stands TREE_COLOURS), as its record tint.
static func _tree_tint(tree: String, rng: RandomNumberGenerator) -> String:
	if not Stands.TREE_COLOURS.has(tree): return ""
	var options: Array = Stands.TREE_COLOURS[tree]
	var pool := {}
	for n in range(options.size()): pool[str(n)] = float(options[n][1])
	var pick := int(_weighted(pool,rng.randf()))
	var color := Color(options[pick][0]).srgb_to_linear()*rng.randf_range(Stands.TREE_BRIGHTNESS.x,Stands.TREE_BRIGHTNESS.y)
	return NativeObjectPose.encode_tint(Color(minf(color.r,1.0),minf(color.g,1.0),minf(color.b,1.0)))

## The plants drawn as the plate's catalog draws them (GardenInstanceSamples
## `add_item`): per part, a multimesh buffer (TRANSFORM_3D with colours, 16
## floats an instance) laid `shift` off, and its count. `catalog` is the
## catalog's parts, poses and tints, and each part's box (`boxes`), all
## plain data, so this is safe on a worker. Fills `crowns` and `blocks` from
## what each record draws.
func flora(catalog: Dictionary, shift := Vector3.ZERO) -> Dictionary:
	var transforms := {}
	var sources := {}
	var tints := {}
	var boxes: Dictionary = catalog.boxes
	crowns.clear()
	blocks.clear()
	for item in objects:
		var counts := {}
		for key in transforms: counts[key] = (transforms[key] as Array).size()
		Samples.add_item(item,self,catalog.parts,catalog.poses,catalog.tints,catalog.world,false,transforms,sources,tints)
		var asset: String = item.asset
		var tree := asset in Emergence.TREES
		var stone := asset in BOULDERS
		if not tree and not stone: continue
		var box := AABB()
		var any := false
		for key in transforms:
			var list: Array = transforms[key]
			for n in range(int(counts.get(key,0)),list.size()):
				if not boxes.has(key): continue
				var drawn: AABB = (list[n] as Transform3D)*(boxes[key] as AABB)
				box = drawn if not any else box.merge(drawn)
				any = true
		if not any: continue
		var ground := ground_at(Vector2(item.x,item.z))
		var top := box.end.y-ground
		var spread := maxf(box.size.x,box.size.z)*0.5
		if tree:
			crowns.append(Vector4(item.x,item.z,top,maxf(spread*0.75,0.6)))
			blocks.append(Vector3(item.x,item.z,TRUNK*maxf(float(item.scale),0.6)))
		else:
			crowns.append(Vector4(item.x,item.z,top,spread*0.9))
			blocks.append(Vector3(item.x,item.z,spread*STONE_BLOCK))
	var out := {}
	for key: String in transforms:
		var list: Array = transforms[key]
		if list.is_empty(): continue
		var colors: Array = tints[key]
		var buffer := PackedFloat32Array()
		buffer.resize(list.size()*16)
		for i in range(list.size()):
			var t: Transform3D = list[i]
			var c: Color = colors[i] if i < colors.size() else Color.WHITE
			var o := i*16
			buffer[o] = t.basis.x.x; buffer[o+1] = t.basis.y.x; buffer[o+2] = t.basis.z.x; buffer[o+3] = t.origin.x+shift.x
			buffer[o+4] = t.basis.x.y; buffer[o+5] = t.basis.y.y; buffer[o+6] = t.basis.z.y; buffer[o+7] = t.origin.y+shift.y
			buffer[o+8] = t.basis.x.z; buffer[o+9] = t.basis.y.z; buffer[o+10] = t.basis.z.z; buffer[o+11] = t.origin.z+shift.z
			buffer[o+12] = c.r; buffer[o+13] = c.g; buffer[o+14] = c.b; buffer[o+15] = c.a
		out[key] = {"buffer":buffer,"count":list.size()}
	return out

# --- Its meshes -------------------------------------------------------------------

## The top's surface arrays, safe to make on a worker: one flat face a land
## triangle, coloured as the plate's ground (`palette`: grass and rock lists,
## sand, gravel, rock_slope, all linear), each point's normal the mean of
## the faces round it (the ground's smoothed normal, which the plate's
## terrain material lights by). Laid `shift` off (see SkyIslets OFF_MAP).
func top_arrays(palette: Dictionary, shift := Vector3.ZERO) -> Array:
	var grass: Array = palette.grass
	var rock: Array = palette.rock
	var sand: Color = palette.sand
	var gravel: Color = palette.gravel
	var rock_slope: float = palette.rock_slope
	var patch := FastNoiseLite.new()
	patch.seed = seed+5
	patch.frequency = 0.4
	var smooth := PackedVector3Array()
	smooth.resize(points.size())
	for f in land:
		var n := _face_normal(f)
		for k in range(3): smooth[ids[f*3+k]] += n
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var count := land.size()*3
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	uv.resize(count)
	uv2.resize(count)
	var v := 0
	for f in land:
		var a := _vertex(ids[f*3])
		var b := _vertex(ids[f*3+1])
		var c := _vertex(ids[f*3+2])
		var middle := (a+b+c)/3.0
		var at := Vector2(middle.x,middle.z)
		var shimmer := (PlateMesh._hash(f,seed % 9973,5)-0.5)*0.07
		var n := patch.get_noise_2d(at.x,at.y)*0.5+0.5
		var tone: Color = grass[1 if n > 0.55 else (2 if n < 0.42 else 0) if grass.size() > 2 else 0]
		if _slope(f) > rock_slope:
			tone = rock[0 if patch.get_noise_2d(at.x+71.0,at.y) > 0.0 else rock.size()-1]
		elif pond.z > 0.0 and minf(a.y,minf(b.y,c.y)) < WATER+0.06:
			tone = sand*lerpf(1.0,0.72,clampf((WATER-middle.y)/BOWL,0.0,1.0))
		elif kind == "shore":
			var d := (shore_distance[ids[f*3]]+shore_distance[ids[f*3+1]]+shore_distance[ids[f*3+2]])/3.0
			if d < BEACH*(0.8+0.4*n): tone = gravel if patch.get_noise_2d(at.x*2.0,at.y*2.0) > 0.25 else sand
		tone = Color(tone.r+shimmer,tone.g+shimmer,tone.b+shimmer,1.0)
		var corners := [a,b,c]
		for k in range(3):
			var p: Vector3 = corners[k]
			vertices[v] = p+shift
			normals[v] = smooth[ids[f*3+k]].normalized()
			colors[v] = tone
			uv[v] = Vector2(0.0,1.0)
			uv2[v] = Vector2(0.5,p.y+shift.y)
			v += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

## The sides' surface arrays, safe on a worker: the islands' shore wall
## (scripts/island_shore.gd `build`) hung under every shore edge, from the
## land's edge through a faceted ring to the foot, and under the land the
## rock hanging from it (`keel`), one face under each land face. For the
## earth sides' material: each wall vertex carries its rim top in UV.
func side_arrays() -> Array:
	var into := Transform3D.IDENTITY
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var outward: Dictionary = IslandShore._outward(points,shore_edges)
	for k in range(0,shore_edges.size(),3):
		var a := shore_edges[k]
		var b := shore_edges[k+1]
		var pa := points[a]
		var pb := points[b]
		var out: Vector2 = ((outward[a] as Vector2)+(outward[b] as Vector2)).normalized()
		var top_a := Vector3(pa.x,heights[a],pa.y)
		var top_b := Vector3(pb.x,heights[b],pb.y)
		var ring_a := IslandShore._ring(a,top_a,outward[a])
		var ring_b := IslandShore._ring(b,top_b,outward[b])
		ring_a.y = maxf(ring_a.y,base+0.3)
		ring_b.y = maxf(ring_b.y,base+0.3)
		var foot_a := Vector3(pa.x,base-keel[a],pa.y)
		var foot_b := Vector3(pb.x,base-keel[b],pb.y)
		var face := Vector3(out.x,0.0,out.y)
		var ha := heights[a]
		var hb := heights[b]
		IslandShore._add(vertices,uvs,into,[top_a,top_b,ring_b],face,[ha,hb,hb],0.0)
		IslandShore._add(vertices,uvs,into,[top_a,ring_b,ring_a],face,[ha,hb,ha],0.0)
		IslandShore._add(vertices,uvs,into,[ring_a,ring_b,foot_b],face,[ha,hb,hb],0.0)
		IslandShore._add(vertices,uvs,into,[ring_a,foot_b,foot_a],face,[ha,hb,ha],0.0)
	for f in land:
		var tri := []
		for k in range(3):
			var i := ids[f*3+k]
			tri.append(Vector3(points[i].x,base-keel[i],points[i].y))
		IslandShore._add(vertices,uvs,into,tri,Vector3.DOWN,[],0.0)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays

## The top as a mesh (tests): `palette` as `top_arrays` takes it.
func build_mesh(palette: Dictionary, material: Material = null, shift := Vector3.ZERO) -> ArrayMesh:
	return mesh_from(top_arrays(palette,shift),material)

## A one-surface mesh from surface arrays, with its material.
static func mesh_from(arrays: Array, material: Material, format := 0) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	if material != null: mesh.surface_set_material(0,material)
	return mesh

## A plain palette, the plate's own colours (NativeTerrainPalette's sources),
## for tests and stand-ins.
static func plain_palette() -> Dictionary:
	return {"grass":[Color("5d9e53").srgb_to_linear(),Color("7fb069").srgb_to_linear(),Color("4a8548").srgb_to_linear()],
		"rock":[Color("8d8577").srgb_to_linear(),Color("6f6a5f").srgb_to_linear()],
		"sand":Color("c9b57e").srgb_to_linear(),"gravel":Color("a8a08c").srgb_to_linear(),"rock_slope":0.93}

## The pond's surface for the plate's own still-water material
## (reference_water_body): a fine sheet, so its chop has vertices to stand
## on, a disc over the pond and a strip down the channel to the lip. Each
## vertex carries what that water reads: its depth over the bed (UV2.x),
## a run to the bank for the shore foam (UV.x), and the fetch, open water
## upwind in eight directions (CUSTOM0, CUSTOM1), for the chop. `color` is
## the body where the material has no depth tint. Laid `shift` off, as the
## top is.
func build_water(material: Material, color := Color(0.25,0.57,0.59), shift := Vector3.ZERO) -> ArrayMesh:
	var arrays := water_arrays(color,shift)
	return null if arrays.is_empty() else mesh_from(arrays,material,WATER_FORMAT)

## The pond's surface arrays (`build_water`), empty with no pond; safe to
## make on a worker.
func water_arrays(color := Color(0.25,0.57,0.59), shift := Vector3.ZERO) -> Array:
	if pond.z <= 0.0: return []
	var middle := Vector2(pond.x,pond.y)
	var r := pond.z*1.1
	var rings := maxi(int(ceil(r/0.28)),4)
	var segments := 36
	var faces := []
	var at := func(p: Vector2) -> Vector3: return Vector3(p.x,WATER,p.y)
	var ring := func(k: int, s: int) -> Vector2: return middle+Vector2.from_angle(TAU*s/segments)*r*k/rings
	for k in range(rings):
		for s in range(segments):
			var a: Vector2 = ring.call(k,s)
			var b: Vector2 = ring.call(k,s+1)
			var c: Vector2 = ring.call(k+1,s+1)
			var d: Vector2 = ring.call(k+1,s)
			if k == 0:
				_tri(faces,at.call(a),at.call(c),at.call(d),color)
			else:
				_tri(faces,at.call(a),at.call(b),at.call(c),color)
				_tri(faces,at.call(a),at.call(c),at.call(d),color)
	# The channel: from inside the pond to just past the lip.
	var way := (lip-middle).normalized()
	var side := Vector2(-way.y,way.x)*CHANNEL*0.85
	var from := middle+way*pond.z*0.6
	var to := lip+way*0.05
	var steps := maxi(int(ceil(from.distance_to(to)/0.3)),1)
	for i in range(steps):
		var p0 := from.lerp(to,float(i)/steps)
		var p1 := from.lerp(to,float(i+1)/steps)
		_tri(faces,at.call(p0-side),at.call(p0+side),at.call(p1+side),color)
		_tri(faces,at.call(p0-side),at.call(p1+side),at.call(p1-side),color)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var dirs := []
	for i in range(8): dirs.append(Vector2.from_angle(TAU*i/8.0))
	for f: Array in faces:
		var v: Vector3 = f[0]
		var p := Vector2(v.x,v.z)
		var deep := maxf(WATER-ground_at(p),0.0)
		vertices.append(v+shift)
		normals.append(Vector3.UP)
		colors.append(f[1])
		uv.append(Vector2(deep*2.5,0.0))
		uv2.append(Vector2(deep,0.0))
		# Fetch order (reference_lake_chop zsFetch): +x, +x+z, +z, -x+z, then
		# the opposites. The open water that way: to the pond's shore, taken
		# as a circle where the bowl meets the water (SHORE of its radius).
		var runs := []
		for d: Vector2 in [dirs[0],dirs[1],dirs[2],dirs[3],-dirs[0],-dirs[1],-dirs[2],-dirs[3]]:
			var o := p-middle
			var shore := pond.z*SHORE
			var bq := o.dot(d)
			var cq := o.length_squared()-shore*shore
			var disc := bq*bq-cq
			runs.append(clampf(-bq+sqrt(disc),0.0,9.0) if disc > 0.0 else 0.0)
		fetch_a.append_array([runs[0],runs[1],runs[2],runs[3]])
		fetch_b.append_array([runs[4],runs[5],runs[6],runs[7]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays

## A flat water triangle facing up (Godot's front, as the terrain's faces:
## (c-a)×(b-a) up).
static func _tri(out: Array, a: Vector3, b: Vector3, c: Vector3, tone: Color) -> void:
	if (c-a).cross(b-a).y < 0.0:
		var swap := b
		b = c
		c = swap
	for p in [a,b,c]: out.append([p,tone])
