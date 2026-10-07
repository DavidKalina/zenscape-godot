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
##     the plain is (scripts/genesis_canvas.gd `shape`), to a rim that
##     wanders and slumps, then weathered by the plate's own erosion
##     (scripts/terrain_erosion.gd, `_erode`): gullies and runnels cut down
##     to the shore and break the lip, scree left in them; drawn as the plate
##     draws its ground: one flat face a triangle in the world's grass greens,
##     rock where a face is steeper than the palette's rock slope, sand at a
##     pond's bank and on a beach;
##   the sides: the islands' shore wall and the hanging rock under the land
##     (scripts/island_shore.gd: its facet ring, `keel`), from a shallower
##     foot (BASE), in the earth sides' strata; the wall slumps out and
##     overhangs along the shore and bulges part way down (`_wall_rings`);
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
const Erosion = preload("res://scripts/terrain_erosion.gd")

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
## Claimed ground eases back to the land round it over this many metres.
const LEVEL_EASE := 1.6
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
## The rim (the ground's height at the shore): how far it wanders up and
## down (m), how far it slumps where the lip has broken away (m), over
## waves LIP_WAVE (1/m).
const LIP := Vector2(0.16,0.4)
const LIP_WAVE := 0.32
## The erosion (`_erode`): its grid reaches ERODE_MARGIN m past the land,
## the sky round it stands ERODE_DROP m under the lowest rim, and its
## strengths by kind over the common settings (TerrainErosion `erode`; the
## plate's own families run 0.004 to 0.010 for k and 0.3 to 1.1 m of cut,
## an islet a little harder, so its small slopes show their weathering).
const ERODE_MARGIN := 1.5
const ERODE_DROP := 1.5
const ERODE_COMMON := {"frequency":0.32,"warp":1.3,"slope_ref":1.0,"iterations":16,"channel_area":1.5,"jitter":0.6,
	"deposit":0.45,"deposit_slope":0.35,"deposit_cap":0.06}
const ERODE := {"meadow":{"detail":0.12,"k":0.02,"max_cut":0.5},"grove":{"detail":0.14,"k":0.02,"max_cut":0.55},
	"hills":{"detail":0.3,"k":0.025,"max_cut":0.8},"crag":{"detail":0.5,"k":0.03,"max_cut":1.0},
	"spring":{"detail":0.12,"k":0.02,"max_cut":0.5},"shore":{"detail":0.06,"k":0.015,"max_cut":0.35}}
## Scree: ground the erosion cut this deep (m) and at least this steep
## turns to gravel and earth, and a few loose stones lie in the deepest
## gullies (SCREE_STONES).
const SCREE := Vector2(0.12,0.3)
const SCREE_STONES := Vector2i(0,4)
## The shore wall: its facet ring's drop under the rim (m) and how far it
## stands out (m, negative undercut under an overhanging lip), wandering
## along the shore so the earth slumps out in places; a second ring part
## way down bulges by up to WALL_BULGE m. Near the spring's lip the wall
## stands back at most LIP_CLEAR m, so its fall pours clear.
const WALL_DROP := Vector2(0.35,1.5)
const WALL_OUT := Vector2(-0.12,0.45)
const WALL_BULGE := 0.3
const WALL_WAVE := 0.45
const LIP_CLEAR := 0.15
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
## How deep the erosion cut each point (m): gully floors and scree.
var wear := PackedFloat32Array()
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
## An authored islet's recipe (`author`), empty for a seeded one. What it
## may set, each optional, every place in the islet's frame (m):
##   radius: the land's radius, instead of the kind's range;
##   mounds / peaks: Array of Vector4(x, z, reach, height), smooth hill
##     mounds or the crag's ridged peaks, instead of the kind's own;
##   dome: how high the ground rises inland, instead of the kind's;
##   pond: {at: Vector2, radius, toward: Vector2}, a pond whose channel
##     leaves over the rim in the `toward` direction, on any kind;
##   pads: Array of Vector4(x, z, radius, lift), ground levelled to its
##     height at the middle (plus lift) for something to stand on, and kept
##     clear of plants;
##   clear: Array of Vector3(x, z, radius) kept clear of plants;
##   trees: Vector2i, the trees' count, and tree_pool: the species pool;
##     mixed: each tree drawn from the whole pool (not a dominant and a
##     companion); tree_size: a multiplier range on each tree's size;
##   drifts: Vector2i, how many flower drifts; apart: a multiplier on how
##     far apart the trees keep;
##   undergrowth: a multiplier on the kind's undergrowth;
##   objects: Array of records ({asset, x, z, angle, scale, tint}) set as
##     they are, after the planting (a cabin, lamps, a field's rows);
##   blocks / crowns: extra walker blocks Vector3(x, z, radius) and glide
##     crowns Vector4(x, z, top, reach), for what stands on it;
##   keel: a multiplier on how deep the rock hangs under it;
##   rock: the look of its earth sides (SkyIslets `rock_material`):
##     {"palette": name, "tone": brightness, "seed"};
##   decks: Array of {a: Vector3, b: Vector3, width, bow}, planked ways a
##     walker and the glide treat as land, reaching off the rim (a dock, a
##     footbridge's deck): straight from a to b, bowed `bow` m at the middle
##     (Footbridge `lift`'s shapes: up a sine, down a sine squared).
var recipe := {}
## The recipe's decks, as it gives them.
var decks: Array = []
## Ground claimed after it was shaped (`claim`), for something to stand on:
## Vector4(x, z, radius, 0) circles and Vector4(x, z, half x, half z) with
## w > 0 rectangles. `find_spot` keeps off them.
var claims: Array[Vector4] = []
## Rectangles (Rect2) of tilled earth, drawn in the earth's colour.
var soil: Array[Rect2] = []

## An islet laid out by hand from `spec` (see `recipe`), its kind
## `spec.kind`, the rest of it seeded by `seed_value` as any islet's is.
static func author(seed_value: int, spec: Dictionary) -> RefCounted:
	var islet: RefCounted = new()
	islet.recipe = spec
	islet._shape(seed_value,str(spec.get("kind","")))
	return islet

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
	if recipe.has("radius"): radius = float(recipe.radius)
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
	if recipe.has("keel"):
		var deeper := float(recipe.keel)
		for i in range(keel.size()): keel[i] *= deeper
	base = -(BASE.x+BASE.y*radius)
	var deepest := 0.0
	for k in keel: deepest = maxf(deepest,k)
	depth = -base+deepest
	_plant(rng)
	decks = recipe.get("decks",[])
	for deck: Dictionary in decks:
		for end: Vector3 in [deck.a,deck.b]: reach = maxf(reach,Vector2(end.x,end.z).length()+1.0)

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
	# A recipe's own: smooth mounds, then ridged peaks (`peaked` from).
	var peaked := 1000000
	if recipe.has("mounds") or recipe.has("peaks"):
		for m: Vector4 in recipe.get("mounds",[]): mounds.append(m)
		peaked = mounds.size()
		for m: Vector4 in recipe.get("peaks",[]): mounds.append(m)
	elif kind == "hills":
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
	var lip_noise := FastNoiseLite.new()
	lip_noise.seed = seed+43
	lip_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lip_noise.frequency = LIP_WAVE
	heights.resize(points.size())
	for i in range(points.size()):
		var d := shore_distance[i]
		if d < 0.0:
			heights[i] = RIM_HEIGHT
			continue
		var p := points[i]
		var roll := swell.get_noise_2d(p.x,p.y)*SWELL.x+ripple.get_noise_2d(p.x,p.y)*RIPPLE.x
		var dome := float(recipe.get("dome",DOME[kind]))*smoothstep(0.0,1.0,d/inland)
		# A beach lies low and nearly flat.
		var h := RIM_HEIGHT+0.05+roll*0.3+dome if kind == "shore" else GROUND+roll+dome
		for mi in range(mounds.size()):
			var m := mounds[mi]
			var r := p.distance_to(Vector2(m.x,m.y))/m.z
			if r >= 1.0: continue
			if mi >= peaked or (peaked > mounds.size() and kind == "crag"):
				var fall := pow(1.0-r,1.2)
				h += m.w*fall+RIDGE*fall*(ridge.get_noise_2d(p.x,p.y)*0.5+0.5)
			else:
				h += m.w*(1.0-r*r)*(1.0-r*r)
		# The lip wanders up and down, and slumps in places (`_rim_at`).
		heights[i] = lerpf(_rim_at(p,lip_noise),h,smoothstep(0.0,ease,d))
	_erode()
	if kind == "spring" or recipe.has("pond"): _cut_pond(rng,inland)
	_level_pads()

## A recipe's pads: the ground eased to the height at each pad's middle
## (plus its lift) over its radius, fading back over half as much again.
func _level_pads() -> void:
	var pads: Array = recipe.get("pads",[])
	if pads.is_empty(): return
	var targets := []
	for pad: Vector4 in pads: targets.append(ground_at(Vector2(pad.x,pad.y))+pad.w)
	for i in range(points.size()):
		if shore_distance[i] < 0.0: continue
		for k in range(pads.size()):
			var pad: Vector4 = pads[k]
			var d := points[i].distance_to(Vector2(pad.x,pad.y))
			var t := 1.0-smoothstep(pad.z,pad.z*1.5+0.5,d)
			if t > 0.0: heights[i] = lerpf(heights[i],float(targets[k]),t)

## The rim's height at shore point `p`: RIM_HEIGHT wandering by LIP.x, and
## slumped down by up to LIP.y where the lip has broken away.
func _rim_at(p: Vector2, noise: FastNoiseLite) -> float:
	var wander := noise.get_noise_2d(p.x,p.y)
	var slump := smoothstep(0.15,0.6,noise.get_noise_2d(p.x+137.0,p.y-59.0))
	return RIM_HEIGHT+wander*LIP.x-slump*LIP.y

## The plate's erosion (scripts/terrain_erosion.gd `erode`, the stream power
## the islands' land is weathered by) over the islet's ground, on its own
## 0.7 m grid over the land: the sky round the land is a fixed outlet just
## under the lowest rim, so water runs off every side and cuts gullies and
## runnels down to the shore, breaking the lip where they leave, and the
## ridged detail roughens the slopes. Each point's cut is kept (`wear`) for
## the scree it leaves.
func _erode() -> void:
	var cell := Erosion.CELL
	var n := ceili((reach+ERODE_MARGIN)*2.0/cell)+1
	var origin := -float(n-1)*0.5*cell
	var low := INF
	for k in range(0,shore_edges.size(),3): low = minf(low,heights[shore_edges[k]])
	var base := PackedFloat64Array()
	var fixed := PackedByteArray()
	base.resize(n*n)
	fixed.resize(n*n)
	for j in range(n):
		for i in range(n):
			var p := Vector2(origin+i*cell,origin+j*cell)
			var hit := _locate(p)
			var f: int = hit[0]
			if f < 0:
				base[j*n+i] = low-ERODE_DROP
				fixed[j*n+i] = 1
				continue
			var w: Vector3 = hit[1]
			base[j*n+i] = w.x*heights[ids[f*3]]+w.y*heights[ids[f*3+1]]+w.z*heights[ids[f*3+2]]
	var settings: Dictionary = (ERODE[kind] as Dictionary).duplicate()
	settings.merge(ERODE_COMMON)
	settings.merge({"size":n,"cell":cell,"origin":origin,"seed":(seed*7+53) & 0x7fffffff,"edge_inner":1.0e5,"edge_outer":1.0e5+1.0})
	var delta := Erosion.erode(base,fixed,settings)
	wear.resize(points.size())
	wear.fill(0.0)
	if delta.size() != n*n: return
	for i in range(points.size()):
		if shore_distance[i] < 0.0: continue
		var p := points[i]
		var cut := Erosion.sample(delta,p.x,p.y,n,origin)
		heights[i] += cut
		wear[i] = maxf(-cut,0.0)

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
	var spec: Dictionary = recipe.get("pond",{})
	if spec.has("at"): middle = spec.at
	if spec.has("radius"): r = float(spec.radius)
	pond = Vector3(middle.x,middle.y,r)
	# The lip: the shore point nearest the pond, a little seeded among the
	# nearest few, so the channel is short; or, for a recipe's, the shore
	# point the way it says, near.
	var shore := []
	for k in range(0,shore_edges.size(),3):
		var i := shore_edges[k]
		var score := points[i].distance_to(middle)
		if spec.has("toward"): score += 12.0*(1.0-(points[i]-middle).normalized().dot((spec.toward as Vector2).normalized()))
		shore.append([score,i])
	shore.sort()
	var pick: int = shore[0 if spec.has("toward") else rng.randi_range(0,mini(2,shore.size()-1))][1]
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
	return int(_locate(p)[0]) >= 0 or deck_y(p) > -INF

## True on the land itself (not a deck).
func on_land(p: Vector2) -> bool:
	return int(_locate(p)[0]) >= 0

## The planks' top over `p` on a deck (the highest, where two cross), or
## -INF off every deck.
func deck_y(p: Vector2) -> float:
	var best := -INF
	for deck: Dictionary in decks:
		var a: Vector3 = deck.a
		var b: Vector3 = deck.b
		var from := Vector2(a.x,a.z)
		var way := Vector2(b.x,b.z)-from
		var t := (p-from).dot(way)/maxf(way.length_squared(),0.0001)
		if t < 0.0 or t > 1.0: continue
		if absf((p-from).cross(way)/way.length()) > float(deck.get("width",1.0))*0.5: continue
		var bow := float(deck.get("bow",0.0))
		var shape := sin(PI*t)
		best = maxf(best,lerpf(a.y,b.y,t)+bow*(shape if bow > 0.0 else shape*shape))
	return best

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
	if decks.is_empty(): return _sample(heights,p,RIM_HEIGHT)
	var deck := deck_y(p)
	if not on_land(p) and deck > -INF: return deck
	return maxf(_sample(heights,p,RIM_HEIGHT),deck)

func top(p: Vector2) -> float:
	return ground_at(p)

## Metres in from the shore at `p`, 0 off the land.
func inland(p: Vector2) -> float:
	return maxf(_sample(shore_distance,p,0.0),0.0)

## The rock's underside under a point inside.
func underside(p: Vector2) -> float:
	if not decks.is_empty() and not on_land(p):
		var deck := deck_y(p)
		if deck > -INF: return deck-0.4
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
		if not on_land(dir*(r+step)): break
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
	for c: Vector3 in recipe.get("clear",[]): taken.append(c)
	for pad: Vector4 in recipe.get("pads",[]): taken.append(Vector3(pad.x,pad.y,pad.z))
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
	var pool: Dictionary = recipe.get("tree_pool",TREE_POOLS[kind])
	var dominant := _weighted(pool,rng.randf())
	var companion := _weighted(pool,rng.randf())
	var purity := rng.randf_range(PURITY.x,PURITY.y)
	var bounds: Vector2i = recipe.get("trees",TREE_COUNT[kind])
	var want := clampi(roundi(area*float(TREE_DENSITY[kind])*rng.randf_range(0.7,1.3)),bounds.x,bounds.y)
	if recipe.has("trees"): want = rng.randi_range(bounds.x,bounds.y)
	var tints := {}
	for n in range(want):
		var tree := dominant if rng.randf() < purity else companion
		if recipe.get("mixed",false): tree = _weighted(pool,rng.randf())
		var size := rng.randf_range(Emergence.TREE_SIZE.x,Emergence.TREE_SIZE.y)*float(Emergence.KIND_SIZE.get(tree,1.0))
		if recipe.has("tree_size"): size *= rng.randf_range((recipe.tree_size as Vector2).x,(recipe.tree_size as Vector2).y)
		var room := TREE_APART*maxf(size,0.6)*(1.6 if tree in ["layered_tree","broadleaf","willow"] else 1.0)*float(recipe.get("apart",1.0))
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
		var drifts: Vector2i = recipe.get("drifts",DRIFTS[kind])
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
		var count := _count(rng,area*float(entry[1])*float(recipe.get("undergrowth",1.0)))
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
	# Loose stones in the deepest gullies, where the erosion cut most.
	if wear.size() == points.size():
		var worn := []
		for i in range(points.size()):
			if wear[i] > SCREE.y and shore_distance[i] > 0.3 and not wet(points[i]): worn.append([wear[i],i])
		worn.sort()
		worn.reverse()
		var placed := 0
		var loose := rng.randi_range(SCREE_STONES.x,SCREE_STONES.y)
		for entry: Array in worn:
			if placed >= loose: break
			var p: Vector2 = points[int(entry[1])]+Vector2(rng.randf_range(-0.2,0.2),rng.randf_range(-0.2,0.2))
			if not inside(p) or _near(p,taken,0.2): continue
			_add(BOULDERS[rng.randi() % BOULDERS.size()],p,rng.randf()*TAU,rng.randf_range(0.22,0.42))
			taken.append(Vector3(p.x,p.y,0.3))
			placed += 1
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
	# What the recipe sets as it is: a cabin, lamps, a field's rows.
	for item: Dictionary in recipe.get("objects",[]):
		# Only on the land, a little in from the rim (a field's rows stop
		# at the shore).
		if inland(Vector2(item.x,item.z)) < float(item.get("inset",0.4)): continue
		_add(item.asset,Vector2(item.x,item.z),float(item.get("angle",0.0)),float(item.get("scale",1.0)),str(item.get("tint","")))

# --- Claiming ground ----------------------------------------------------------------

## A spot on the land for something `radius` m round (or, with `rect` set,
## a rectangle of those half extents, axis-aligned), at least `rim` m in
## from the shore past its own reach, dry with `wet_room` m to spare,
## whose ground varies by at most `flat` m over it, clear of what is
## claimed and of `avoid` (Vector3(x, z, radius)). Scored by `prefer`:
## {"toward": Vector2 a way to lean to, "high": weight on height, "middle":
## weight on staying central, "near": Vector2 a place to stay near}; null
## if none suits. Scanned on a STEP grid, so the same islet and asks give
## the same spot.
func find_spot(radius: float, rim: float, flat: float, avoid: Array = [], prefer: Dictionary = {}, rect := Vector2.ZERO, wet_room := 1.0) -> Variant:
	var reach_of := rect.length() if rect != Vector2.ZERO else radius
	var best: Variant = null
	var best_score := -INF
	var toward: Vector2 = (prefer.get("toward",Vector2.ZERO) as Vector2).normalized()
	var step := maxf(0.6,reach/28.0)
	var span := reach
	var x := -span
	while x <= span:
		var z := -span
		while z <= span:
			var p := Vector2(x,z)
			z += step
			if not on_land(p) or inland(p) < rim+reach_of: continue
			if _blocked_by(p,reach_of,avoid): continue
			var spread := _spread(p,radius,rect,wet_room)
			if spread < 0.0 or spread > flat: continue
			var score := -spread*2.0
			if toward != Vector2.ZERO: score += p.dot(toward)/maxf(radius_of_land(),1.0)*float(prefer.get("toward_weight",3.0))
			score += ground_at(p)*float(prefer.get("high",0.0))
			score -= p.length()/maxf(radius_of_land(),1.0)*float(prefer.get("middle",0.0))
			if prefer.has("near"): score -= p.distance_to(prefer.near)*float(prefer.get("near_weight",0.3))
			score += _hash01(p)*0.05
			if score > best_score:
				best_score = score
				best = p
		x += step
	return best

## A circle of the land's area's radius (m).
func radius_of_land() -> float:
	if _land_radius < 0.0: _land_radius = sqrt(maxf(land_area(),1.0)/PI)
	return _land_radius

var _land_radius := -1.0

## How much the ground varies over a footprint at `p` (circle `radius`, or
## a `rect` of half extents), -1 where any of it is off the land or wet.
func _spread(p: Vector2, radius: float, rect: Vector2, wet_room: float) -> float:
	var low := INF
	var high := -INF
	var samples: Array[Vector2] = [p]
	if rect != Vector2.ZERO:
		for i in range(-2,3):
			for j in range(-2,3): samples.append(p+Vector2(rect.x*i/2.0,rect.y*j/2.0))
	else:
		for k in range(8): samples.append(p+Vector2.from_angle(TAU*k/8.0)*radius)
		for k in range(4): samples.append(p+Vector2.from_angle(TAU*k/4.0+0.4)*radius*0.5)
	for q in samples:
		if not on_land(q): return -1.0
		if wet(q): return -1.0
		if pond.z > 0.0 and q.distance_to(Vector2(pond.x,pond.y)) < pond.z+wet_room: return -1.0
		if pond.z > 0.0 and _channel_distance(q) < CHANNEL+wet_room: return -1.0
		var h := ground_at(q)
		low = minf(low,h)
		high = maxf(high,h)
	return high-low

func _blocked_by(p: Vector2, room: float, avoid: Array) -> bool:
	for c in claims:
		var r := Vector2(c.z,c.w).length() if c.w > 0.0 else c.z
		if p.distance_to(Vector2(c.x,c.y)) < r+room+0.4: return true
	for a: Vector3 in avoid:
		if p.distance_to(Vector2(a.x,a.y)) < a.z+room: return true
	return false

static func _hash01(p: Vector2) -> float:
	return fposmod(sin(p.x*12.9898+p.y*78.233)*43758.5453,1.0)

## Claims ground for something to stand on: the ground levelled to its
## height at `at` (plus `lift`) over a circle of `radius` (or a `rect` of
## half extents), easing back over LEVEL_EASE m; whatever grew on it or on
## the ease is cleared. Done before `flora` and the meshes.
func claim(at: Vector2, radius: float, lift := 0.0, rect := Vector2.ZERO) -> void:
	var target := ground_at(at)+lift
	for i in range(points.size()):
		if shore_distance[i] < 0.0: continue
		# Ground claimed before keeps its level.
		if _claimed(points[i]): continue
		var d := _footprint_distance(points[i]-at,radius,rect)
		var t := 1.0-smoothstep(0.0,LEVEL_EASE,d)
		if t > 0.0: heights[i] = lerpf(heights[i],target,t)
	objects = objects.filter(func(o: Dictionary) -> bool:
		return _footprint_distance(Vector2(o.x,o.z)-at,radius,rect) > LEVEL_EASE*0.5+0.3)
	claims.append(Vector4(at.x,at.y,rect.x,rect.y) if rect != Vector2.ZERO else Vector4(at.x,at.y,radius,0.0))

## True on ground already claimed (within its footprint, a little past).
func _claimed(p: Vector2) -> bool:
	for c in claims:
		var d := _footprint_distance(p-Vector2(c.x,c.y),c.z,Vector2(c.z,c.w) if c.w > 0.0 else Vector2.ZERO)
		if d < 0.05: return true
	return false

## How far `d` (from a footprint's middle) lies outside it: 0 inside.
static func _footprint_distance(d: Vector2, radius: float, rect: Vector2) -> float:
	if rect != Vector2.ZERO: return Vector2(maxf(absf(d.x)-rect.x,0.0),maxf(absf(d.y)-rect.y,0.0)).length()
	return maxf(d.length()-radius,0.0)

func _in_soil(p: Vector2) -> bool:
	for r in soil:
		if r.has_point(p): return true
	return false

## Sets a record (a cabin, a lamp, a row's wheat) as it is.
func add_record(asset: String, at: Vector2, angle: float, size := 1.0, tint := "") -> void:
	_add(asset,at,angle,size,tint)

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
	for b: Vector3 in recipe.get("blocks",[]): blocks.append(b)
	for c: Vector4 in recipe.get("crowns",[]): crowns.append(c)
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
	var earth: Color = palette.get("earth",Color(Genesis.FIDELITY.earth).srgb_to_linear())
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
		var slope := _slope(f)
		var worn := (wear[ids[f*3]]+wear[ids[f*3+1]]+wear[ids[f*3+2]])/3.0 if wear.size() == points.size() else 0.0
		var edge := (shore_distance[ids[f*3]]+shore_distance[ids[f*3+1]]+shore_distance[ids[f*3+2]])/3.0
		if slope > rock_slope:
			tone = rock[0 if patch.get_noise_2d(at.x+71.0,at.y) > 0.0 else rock.size()-1]
		elif (worn > SCREE.x and slope > SCREE.y) or (edge < 0.45 and slope > SCREE.y*2.0):
			# Scree: a gully's floor or the crumbling lip, gravel and earth.
			tone = gravel.lerp(earth,clampf(patch.get_noise_2d(at.x*3.0,at.y*3.0)*0.5+0.5,0.0,1.0))
		elif _in_soil(at):
			tone = earth.lerp(gravel,0.15)*lerpf(0.8,0.95,n)
		elif pond.z > 0.0 and minf(a.y,minf(b.y,c.y)) < WATER+0.06 and (at.distance_to(Vector2(pond.x,pond.y)) < pond.z*1.5 or _channel_distance(at) < CHANNEL*1.5):
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
	var slump := FastNoiseLite.new()
	slump.seed = seed+61
	slump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	slump.frequency = WALL_WAVE
	var rings := {}
	for k in range(0,shore_edges.size(),3):
		for i in [shore_edges[k],shore_edges[k+1]]:
			if not rings.has(i): rings[i] = _wall_rings(i,outward[i],slump)
	for k in range(0,shore_edges.size(),3):
		var a := shore_edges[k]
		var b := shore_edges[k+1]
		var pa := points[a]
		var pb := points[b]
		var out: Vector2 = ((outward[a] as Vector2)+(outward[b] as Vector2)).normalized()
		var face := Vector3(out.x,0.0,out.y)
		var ha := heights[a]
		var hb := heights[b]
		# Down the wall: the rim, the facet ring, the bulge, the foot.
		var wall_a: Array = [Vector3(pa.x,ha,pa.y)]+(rings[a] as Array)+[Vector3(pa.x,base-keel[a],pa.y)]
		var wall_b: Array = [Vector3(pb.x,hb,pb.y)]+(rings[b] as Array)+[Vector3(pb.x,base-keel[b],pb.y)]
		for r in range(wall_a.size()-1):
			IslandShore._add(vertices,uvs,into,[wall_a[r],wall_b[r],wall_b[r+1]],face,[ha,hb,hb],0.0)
			IslandShore._add(vertices,uvs,into,[wall_a[r],wall_b[r+1],wall_a[r+1]],face,[ha,hb,ha],0.0)
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

## A shore point's wall under its rim: the facet ring and the bulge below
## it, each stood out (or undercut) by a seeded amount that wanders along
## the shore (`slump`), so the earth slumps out in places and the lip
## overhangs in others; never further out than LIP_CLEAR near the spring's
## lip, where the fall pours.
func _wall_rings(i: int, out: Vector2, slump: FastNoiseLite) -> Array:
	var p := points[i]
	var top := heights[i]
	var foot := base-keel[i]
	var lean := slump.get_noise_2d(p.x,p.y)*0.5+0.5
	var jitter := PlateMesh._hash(i,seed % 7919,9)
	var drop := lerpf(WALL_DROP.x,WALL_DROP.y,clampf(lean*0.6+jitter*0.4,0.0,1.0))
	var reach := lerpf(WALL_OUT.x,WALL_OUT.y,clampf(lean*0.75+jitter*0.25,0.0,1.0))
	var bulge := reach*0.5+(PlateMesh._hash(i,seed % 7919,11)-0.35)*WALL_BULGE
	var ring_y := maxf(top-drop,foot+0.6)
	var ring := Vector3(p.x+out.x*reach,ring_y,p.y+out.y*reach)
	var mid_y := lerpf(ring_y,foot,0.45+0.2*PlateMesh._hash(i,seed % 7919,13))
	var mid := Vector3(p.x+out.x*bulge,mid_y,p.y+out.y*bulge)
	if pond.z > 0.0 and p.distance_to(lip) < 2.0:
		ring = _behind_lip(ring)
		mid = _behind_lip(mid)
	return [ring,mid]

## A wall point near the spring's lip held back to no more than LIP_CLEAR m
## ahead of the lip along its way out, so the fall pours clear of the wall.
func _behind_lip(v: Vector3) -> Vector3:
	var ahead := Vector2(v.x,v.z).dot(lip_out)-lip.dot(lip_out)-LIP_CLEAR
	if ahead <= 0.0: return v
	return v-Vector3(lip_out.x,0.0,lip_out.y)*ahead

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
