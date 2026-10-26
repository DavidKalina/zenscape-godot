extends RefCounted
## Where the endless land's spruces stand (docs/design/endless-flight/
## forests-handoff.md): a pure function of the seed and a world cell, read
## from the land's shape (scripts/endless/land_field.gd `shape`), so every
## run and every worker plants the same trees. scripts/endless/land_trees.gd
## streams them.
##
## The forest mask (`mask`), three kinds of place:
##   dense   real woods, where a broad forest noise (FOREST m) rises past
##           DENSE_AT, helped by the land: gentle slopes and valley sides,
##           river banks, higher ground; thinned toward the coast.
##   grove   scattered clumps (CLUMP m noise) in a band under DENSE_AT.
##   lone    the odd big tree out on the open land (LONE_P a slot).
## None on the beach, a river or its bank, steep rock, over the tree line,
## or a valley's floor. The meadows and flats the plane lands on (AGENTS.md
## "Meadows and flats") stay open, but for the wild ones (MEADOW_WILD): there
## groves may come out onto a meadow's edges, all but its heart, and dense
## woods onto a flat off the meadows (measured: scratch/forest/map.gd, the
## flats check, in docs/design/endless-flight/forests-handoff.md). None in
## an arch's opening or its approach.
##
## The spacing is the plane's (WorldScale): trees stand on a SLOT m lattice,
## one candidate a slot, jittered over the whole slot; the candidates stand
## in a hashed rank's order, each unless one already standing is nearer than
## their two crowns' reach (SPACE_AT of it) plus a gap, `opening(TOY_GAP)`
## times a spread, wider in the groves. A square is thinned with BORDER
## times that reach past it, so neighbouring squares agree on their edge.
## Lanes (LANE m noise's zero lines, `opening(TOY_LANE)` wide) and clearings
## (CLEARING) open the dense woods.
##
## A tree: STRIDE floats, [x, y (its foot, world), z, scale, wide (its
## crown's xz stretch), yaw, variant (HeroTrees.SPRUCE), kind].

const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const RockPlan = preload("res://scripts/endless/rocks/rock_plan.gd")
const HallSites = preload("res://scripts/endless/hall_sites.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")

enum {DENSE, GROVE, LONE}
const STRIDE := 8

## A plan cell's side (m), and the candidate lattice's slot (m).
const CELL := 128.0
const SLOT := 6.0
## The far plan (`far_cell`): its cell, its lattice's slot, and the share of
## the near trees it keeps (each grown FAR_GROW wide and tall to cover).
const FAR_CELL := 1024.0
const FAR_SLOT := 24.0
## Toy widths (WorldScale.opening): the least gap between two crowns in the
## dense woods (where their radius is SPACE_AT of their widest), and a
## lane's width.
const TOY_GAP := 2.6
const TOY_LANE := 8.0
## The gap is measured where a crown's radius is SPACE_AT of its widest
## (about halfway up a spruce: the height the plane threads them at; lower
## the gaps narrow toward the skirts, higher they open), and the candidates
## are thinned over BORDER times their reach past the square.
const SPACE_AT := 0.5
const BORDER := 2.0
## The gap's spread over its least, by kind (x..y times opening(TOY_GAP)).
const GAP_DENSE := Vector2(1.0,1.5)
const GAP_GROVE := Vector2(1.5,3.2)
const GAP_LONE := 9.0
## A slot's chance of a candidate, by kind (the rank thins them after).
const TAKE_DENSE := 0.95
const TAKE_GROVE := 0.85
const LONE_P := 0.0022
## The forest noise (m), and where it turns dense or grove (`f` 0..1 with
## the land's bias: DENSE_AT, GROVE_AT); the share flag shifts `f` (SHARE_SHIFT a unit).
const FOREST := 1500.0
const DENSE_AT := 0.47
const GROVE_AT := 0.36
const EDGE := 0.035
const SHARE_SHIFT := 0.4
## The groves' clumps: a noise of CLUMP m over CLUMP_ON (soft over CLUMP_SOFT).
const CLUMP := 75.0
const CLUMP_ON := 0.1
const CLUMP_SOFT := 0.08
## Lanes through the dense woods: a noise of LANE m whose zero lines open a
## lane opening(TOY_LANE) wide (LANE_WARP m of wander); clearings where a
## CLEARING m noise rises over CLEARING_ON.
const LANE := 320.0
const CLEARING := 140.0
const CLEARING_ON := 0.42
## The land's bias on `f`: gentle slopes (up from SLOPE_BIAS.x to .y),
## valley sides, river banks (RIVER_BAND m off the water), higher ground
## (HIGH_BIAS m over the sea), the coast (COAST m over the sea) against.
const SLOPE_BIAS := Vector3(0.995,0.95,0.1)
const VALLEY_BIAS := 0.08
const RIVER_BAND := Vector2(6.0,70.0)
const RIVER_BIAS := 0.14
const HIGH_BIAS := Vector3(12.0,38.0,0.08)
const COAST := Vector3(5.0,18.0,0.25)
## Where none grow: under BEACH_CLEAR m over the sea, within RIVER_KEEP m
## of a river's water, ground whose up is under STEEP.x (thinning from .y),
## over the tree line (TREE_LINE m over the sea, thinning from .x to .y),
## on meadows (MEADOW_OFF.x thinning to none at .y).
const BEACH_CLEAR := 5.0
const RIVER_KEEP := 4.0
const STEEP := Vector2(0.8,0.88)
const TREE_LINE := Vector2(60.0,82.0)
const MEADOW_OFF := Vector2(0.1,0.28)
## The meadows are many (about two fifths of the land): where a MEADOW_KEEP m
## noise falls under MEADOW_WILD (wild) the woods may come out onto them, as
## groves only, all but their hearts (meadow over MEADOW_DEEP); elsewhere
## they stay open, and so does any flat. --forest-meadows=X: 0 none wild
## (every meadow and flat open), over 1 more of them wild.
const MEADOW_KEEP := 1100.0
const MEADOW_WILD := -0.05
const MEADOW_DEEP := Vector2(0.75,0.92)
## Flat enough to land on (`_flat`): this slope or less across FLAT_REACH m
## either way. Kept open where the meadows are kept.
const FLAT_SLOPE := 0.06
const FLAT_REACH := 32.0
const FLAT_STEP := 16.0
## The forest floor's weight in a grove's clump (`floor_weight`).
const FLOOR_GROVE := 0.7
## Clear round an arch (m): past its feet, and its approach either side.
const ARCH_CLEAR := 18.0
const ARCH_APPROACH := 110.0
## Scales (times the model; the mature is 4.4 m) and crown stretch, by kind.
const SIZE_DENSE := Vector2(3.0,4.4)
const SIZE_GROVE := Vector2(2.4,4.0)
const SIZE_LONE := Vector2(3.6,4.6)
const WIDE_DENSE := Vector2(1.35,1.7)
const WIDE_LONE := Vector2(1.15,1.35)
## The foot sunk under the land (m), more on a slope.
const SINK := 0.35

var seed := 1
## The share: 1 the default; 0 none (--forest=X).
var share := 1.0
## How much of the meadows the woods may take (1; 0 none: --forest-meadows=X).
var meadows := 1.0
## How much the last `suits` stood on a wild meadow (0..1).
var last_wild := 0.0
## Per variant Vector3(crown radius, crown top, crown bottom) at scale 1.
var dims: Array = []
var arches := {"density":1.0,"rock":1.0,"ruin":1.0}

var _forest := FastNoiseLite.new()
var _clump := FastNoiseLite.new()
var _lane := FastNoiseLite.new()
var _lane_warp := FastNoiseLite.new()
var _clearing := FastNoiseLite.new()
var _meadow_keep := FastNoiseLite.new()
var _weights := PackedFloat32Array()
var _flats := {}
var _heights := {}

static var _arch_cache := {}
static var _arch_lock := Mutex.new()

func _init(land_seed := 1, forest_share := 1.0, variant_dims: Array = [], arch_flags: Dictionary = {}) -> void:
	seed = land_seed
	share = forest_share
	dims = variant_dims
	if dims.is_empty():
		for i in HeroTrees.SPRUCE.size(): dims.append(Vector3(0.65,4.1,0.3))
	if not arch_flags.is_empty(): arches = arch_flags
	_noise(_forest,1,FOREST,3,FastNoiseLite.FRACTAL_FBM)
	_noise(_clump,2,CLUMP,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_lane,3,LANE,1,FastNoiseLite.FRACTAL_NONE)
	_noise(_lane_warp,4,LANE*0.6,1,FastNoiseLite.FRACTAL_NONE)
	_noise(_clearing,5,CLEARING,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_meadow_keep,6,MEADOW_KEEP,2,FastNoiseLite.FRACTAL_FBM)
	_weights = variant_weights()

## The spruce family's variant weights: the world's flora `tree_weights`, or
## HeroTrees.SPRUCE's own (wilderness).
static func variant_weights() -> PackedFloat32Array:
	return weights_of(preload("res://scripts/endless/world/world_profile.gd").current())

## A world profile's variant weights (its flora `tree_weights`, or
## HeroTrees.SPRUCE's own): each region's, in a world of regions.
static func weights_of(profile: RefCounted) -> PackedFloat32Array:
	var w: PackedFloat32Array = profile.flora_value("tree_weights",PackedFloat32Array())
	if w.size() == HeroTrees.SPRUCE.size(): return w.duplicate()
	var out := PackedFloat32Array()
	for entry: Array in HeroTrees.SPRUCE: out.append(float(entry[1]))
	return out

func _noise(n: FastNoiseLite, salt: int, scale: float, octaves: int, kind: int) -> void:
	n.seed = seed*6271+salt*92821+17
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0/scale
	n.fractal_type = kind
	n.fractal_octaves = octaves

func _forget() -> void:
	if _heights.size() > 20000:
		_heights.clear()
		_flats.clear()

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

# --- The mask --------------------------------------------------------------

## Where trees may grow at all (0..1) from the land's shape `s` and the
## ground's up there.
func suits(field: RefCounted, x: float, z: float, s: Dictionary, up: float) -> float:
	var over := float(s.height)-Field.SEA_Y
	if over < BEACH_CLEAR: return 0.0
	if float(s.river) < RIVER_KEEP: return 0.0
	if up < STEEP.x: return 0.0
	var k := smoothstep(STEEP.x,STEEP.y,up)
	k *= 1.0-smoothstep(TREE_LINE.x,TREE_LINE.y,over)
	var off := MEADOW_OFF
	last_wild = 0.0
	var v := float(s.valley)
	if v < INF and v < float(s.half): return 0.0
	if meadows > 0.0:
		var wild := smoothstep(MEADOW_WILD-0.06,MEADOW_WILD+0.06,-_meadow_keep.get_noise_2d(x,z)+(meadows-1.0)*0.3)
		off = MEADOW_OFF.lerp(MEADOW_DEEP,wild)
		last_wild = wild*smoothstep(MEADOW_OFF.x,MEADOW_OFF.y,float(s.meadow))
		# Where the meadows are kept, a flat off them is kept open too.
		if wild < 0.5 and _flat(field,x,z): return 0.0
	elif _flat(field,x,z): return 0.0
	k *= 1.0-smoothstep(off.x,off.y,float(s.meadow))
	return k

## Whether the ground at a point is flat enough to land on: FLAT_SLOPE or
## less across FLAT_REACH m either way (the flats check's measure), read at
## the nearest node of a FLAT_STEP m world grid (heights cached a node).
func _flat(field: RefCounted, x: float, z: float) -> bool:
	var i := roundi(x/FLAT_STEP)
	var j := roundi(z/FLAT_STEP)
	var key := Vector2i(i,j)
	var got: Variant = _flats.get(key)
	if got != null: return got
	var r := roundi(FLAT_REACH/FLAT_STEP)
	var most := FLAT_SLOPE*r*FLAT_STEP*2.0
	var flat := absf(_node_height(field,i+r,j)-_node_height(field,i-r,j)) <= most and absf(_node_height(field,i,j+r)-_node_height(field,i,j-r)) <= most
	_flats[key] = flat
	return flat

func _node_height(field: RefCounted, i: int, j: int) -> float:
	var key := Vector2i(i,j)
	var got: Variant = _heights.get(key)
	if got != null: return got
	var h: float = field.height(i*FLAT_STEP,j*FLAT_STEP)
	_heights[key] = h
	return h

## The forest's reach at a point (about 0..1, DENSE_AT and over the woods) from
## the land's shape `s` and the ground's up.
func reach(x: float, z: float, s: Dictionary, up: float) -> float:
	var f := _forest.get_noise_2d(x,z)*0.62+0.5
	var over := float(s.height)-Field.SEA_Y
	f += SLOPE_BIAS.z*smoothstep(SLOPE_BIAS.x,SLOPE_BIAS.y,up)
	var v := float(s.valley)
	var half := float(s.half)
	if v < INF and v > half: f += VALLEY_BIAS*(1.0-smoothstep(half+float(s.side)*0.6,half+float(s.side)*1.4+20.0,v))
	var r := float(s.river)
	if r < INF: f += RIVER_BIAS*smoothstep(RIVER_BAND.x,RIVER_BAND.x+6.0,r)*(1.0-smoothstep(RIVER_BAND.y*0.5,RIVER_BAND.y,r))
	f += HIGH_BIAS.z*smoothstep(HIGH_BIAS.x,HIGH_BIAS.y,over)
	f -= COAST.z*(1.0-smoothstep(COAST.x,COAST.y,over))
	return f+(share-1.0)*SHARE_SHIFT

## Vector3(dense, grove, open) weights (0..1) at a point; their sum is how
## well trees suit it. Clearings and lanes open the woods.
func mask(field: RefCounted, x: float, z: float, s: Dictionary, up: float) -> Vector3:
	if share <= 0.0: return Vector3.ZERO
	var k := suits(field,x,z,s,up)
	if k <= 0.0: return Vector3.ZERO
	var f := reach(x,z,s,up)
	var dense := smoothstep(DENSE_AT-EDGE,DENSE_AT+EDGE,f)
	var grove := smoothstep(GROVE_AT-EDGE,GROVE_AT+EDGE,f)*(1.0-dense)
	if dense > 0.0:
		var open := 0.0
		if _clearing.get_noise_2d(x,z) > CLEARING_ON: open = 1.0
		var w := _lane_warp.get_noise_2d(x,z)*LANE*0.35
		var l := absf(_lane.get_noise_2d(x+w,z-w))
		# |noise| near its zero line grows about 1.6/LANE a metre.
		if l*LANE/1.6 < WorldScale.opening(TOY_LANE)*0.5: open = 1.0
		dense *= 1.0-open
	# Out on a wild meadow the woods come as groves only.
	grove += dense*last_wild
	dense *= 1.0-last_wild
	return Vector3(dense,grove,1.0-dense-grove)*k

## Whether a grove's clump stands at a point (0..1).
func clump(x: float, z: float) -> float:
	return smoothstep(CLUMP_ON-CLUMP_SOFT,CLUMP_ON+CLUMP_SOFT,_clump.get_noise_2d(x,z))

# --- The arches ------------------------------------------------------------

## The arches near a world rectangle as [pos XZ, cos, sin, half span (local x), half depth]
## (shared cache: ArchPlan is a pure function of the seed and cell).
func _arches_near(field: RefCounted, x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	var pad := ARCH_APPROACH+120.0
	# The slot halls' cuts (scripts/endless/hall_sites.gd) as arches whose
	# span runs across the slot and whose approach runs along it: no tree in
	# the cut, on its rims or in the way in and out.
	if field.has_method("halls_in"):
		for s: PackedFloat32Array in field.halls_in(x0-pad,z0-pad,x1+pad,z1+pad):
			var turned := atan2(-s[3],s[2])+PI*0.5
			out.append([Vector2(s[0],s[1]),cos(turned),sin(turned),s[8],s[7]])
	# The split mountains' slots (split_sites.gd), likewise: none on the
	# floor, the walls or in the way in and out.
	if field.has_method("splits_in"):
		for s: PackedFloat32Array in field.splits_in(x0-pad,z0-pad,x1+pad,z1+pad):
			out.append_array(preload("res://scripts/endless/split_sites.gd").tree_keepouts(s))
	# The mountain tunnels' trenches and portals (tunnel_sites.gd), likewise.
	if field.has_method("tunnels_in"):
		for t: RefCounted in field.tunnels_in(x0-pad,z0-pad,x1+pad,z1+pad):
			out.append_array(preload("res://scripts/endless/tunnel_sites.gd").tree_keepouts(t))
	var rocks := _rock_flags()
	var any_rocks: bool = RockPlan.any(rocks)
	if float(arches.density) <= 0.0 and not any_rocks: return out
	var a := ArchPlan.cell_of(x0-pad,z0-pad)
	var b := ArchPlan.cell_of(x1+pad,z1+pad)
	for cz in range(a.y,b.y+1):
		for cx in range(a.x,b.x+1):
			# The rock shapes' keep-outs (hoodoo pockets: RockPlan, the
			# same cells), cached as the arches are.
			if any_rocks:
				var rkey := Vector3i(cx,cz,-1-seed)
				_arch_lock.lock()
				var kept: Variant = _arch_cache.get(rkey)
				_arch_lock.unlock()
				if kept == null:
					kept = RockPlan.tree_keepouts(field,cx,cz,rocks)
					_arch_lock.lock()
					if _arch_cache.size() > 4000: _arch_cache.clear()
					_arch_cache[rkey] = kept
					_arch_lock.unlock()
				out.append_array(kept)
			if float(arches.density) <= 0.0: continue
			var key := Vector3i(cx,cz,seed)
			_arch_lock.lock()
			var got: Variant = _arch_cache.get(key)
			_arch_lock.unlock()
			if got == null:
				var list: Array = []
				for spec: Dictionary in ArchPlan.plan(field,cx,cz,float(arches.density),float(arches.rock),float(arches.ruin)):
					var pos: Vector3 = spec.pos
					var yaw := float(spec.yaw)
					var c := cos(yaw)
					var sn := sin(yaw)
					var hx := 0.0
					var hz := 0.0
					for foot: Array in spec.get("foot",[]):
						var fc: Vector2 = foot[0]
						var fe: Vector2 = foot[1]
						var fr := fe.length()
						var ox := fc.x-pos.x
						var oz := fc.y-pos.z
						# Basis(UP, yaw): local x is (cos, 0, -sin).
						var lx := ox*c-oz*sn
						var lz := ox*sn+oz*c
						hx = maxf(hx,absf(lx)+fr)
						hz = maxf(hz,absf(lz)+fr)
					list.append([Vector2(pos.x,pos.z),c,sn,hx,hz])
				got = list
				_arch_lock.lock()
				if _arch_cache.size() > 4000: _arch_cache.clear()
				_arch_cache[key] = list
				_arch_lock.unlock()
			out.append_array(got)
	return out

## The rock shapes' densities (RockPlan `flags`), read once (under the
## arches' lock: the tree workers ask at once).
static var _rocks := {}
static func _rock_flags() -> Dictionary:
	_arch_lock.lock()
	if _rocks.is_empty(): _rocks = RockPlan.flags()
	var got := _rocks
	_arch_lock.unlock()
	return got

## The arches near a world rectangle (`_arches_near`) as six floats each,
## [x, z, cos, sin, half span, half depth]: for the native plan (ZenScapeTrees).
func arches_flat(field: RefCounted, x0: float, z0: float, x1: float, z1: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for a: Array in _arches_near(field,x0,z0,x1,z1):
		var p: Vector2 = a[0]
		out.append_array([p.x,p.y,float(a[1]),float(a[2]),float(a[3]),float(a[4])])
	return out

## How far past a square `area`, `far_cell` and `floor_grid` read the land
## (m): its border's slots, the flats' reach, a far slot or two, and slack.
func sample_pad() -> float:
	var gap := WorldScale.opening(TOY_GAP)
	var r_most := 0.0
	for d: Vector3 in dims: r_most = maxf(r_most,d.x)
	var reach_most := r_most*maxf(SIZE_LONE.y,SIZE_DENSE.y)*maxf(WIDE_LONE.y,WIDE_DENSE.y)*SPACE_AT*2.0+gap*maxf(GAP_GROVE.y,GAP_DENSE.y)
	var border := int(ceil(reach_most*BORDER/SLOT))+1
	return maxf((border+3)*SLOT,FAR_SLOT*3.0)+FLAT_REACH+FLAT_STEP+8.0

static func _by_arch(list: Array, x: float, z: float) -> bool:
	for a: Array in list:
		var p: Vector2 = a[0]
		var ox := x-p.x
		var oz := z-p.y
		if absf(ox) > 400.0 or absf(oz) > 400.0: continue
		var lx := absf(ox*float(a[1])-oz*float(a[2]))
		var lz := absf(ox*float(a[2])+oz*float(a[1]))
		var hx := float(a[3])
		var hz := float(a[4])
		if lx < hx+ARCH_CLEAR and lz < hz+ARCH_CLEAR: return true
		# Its approach, either side of the opening.
		if lx < hx and lz < hz+ARCH_APPROACH: return true
	return false

# --- The near plan ---------------------------------------------------------

func _hash01(i: int, j: int, salt: int) -> float:
	return float(hash([seed,i,j,salt]) & 0xffffff)/16777216.0

func _variant(r: float) -> int:
	var total := 0.0
	for w in _weights: total += w
	var roll := r*total
	for i in _weights.size():
		roll -= _weights[i]
		if roll <= 0.0: return i
	return 0

## The trees of plan cell (cx, cz): STRIDE floats each.
func cell(field: RefCounted, cx: int, cz: int) -> PackedFloat32Array:
	return area(field,cx*CELL,cz*CELL,CELL)

## The trees of a square of plan cells (`x0`, `z0` on the CELL grid, `size`
## a whole number of cells): the same trees its cells give one by one (all
## but rarely, at their shared edges), for less work.
func area(field: RefCounted, x0: float, z0: float, size: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if share <= 0.0: return out
	_forget()
	var gap := WorldScale.opening(TOY_GAP)
	var r_most := 0.0
	for d: Vector3 in dims: r_most = maxf(r_most,d.x)
	var reach_most := r_most*maxf(SIZE_LONE.y,SIZE_DENSE.y)*maxf(WIDE_LONE.y,WIDE_DENSE.y)*SPACE_AT*2.0+gap*maxf(GAP_GROVE.y,GAP_DENSE.y)
	var border := int(ceil(reach_most*BORDER/SLOT))+1
	var i0 := floori(x0/SLOT)-border
	var j0 := floori(z0/SLOT)-border
	var n := int(size/SLOT)+border*2+2
	var near_arches := _arches_near(field,x0,z0,x0+size,z0+size)
	# The lattice's land: shapes at the slot middles, for the mask and the
	# up (from the neighbours' heights).
	var shapes: Array = []
	shapes.resize(n*n)
	var hs := PackedFloat32Array()
	hs.resize(n*n)
	for j in n:
		for i in n:
			var s: Dictionary = field.shape((i0+i+0.5)*SLOT,(j0+j+0.5)*SLOT)
			shapes[j*n+i] = s
			hs[j*n+i] = float(s.height)
	# Candidates: [x, z, rank, crown reach, gap, kind, slot i, slot j].
	var cand: Array = []
	for j in range(1,n-1):
		for i in range(1,n-1):
			var si := i0+i
			var sj := j0+j
			var roll := _hash01(si,sj,1)
			var gx := (hs[j*n+i+1]-hs[j*n+i-1])/(SLOT*2.0)
			var gz := (hs[(j+1)*n+i]-hs[(j-1)*n+i])/(SLOT*2.0)
			var up := 1.0/sqrt(1.0+gx*gx+gz*gz)
			var s: Dictionary = shapes[j*n+i]
			var px := (si+_hash01(si,sj,2))*SLOT
			var pz := (sj+_hash01(si,sj,3))*SLOT
			var m := mask(field,px,pz,s,up)
			var kind := -1
			if roll < m.x*TAKE_DENSE: kind = DENSE
			elif roll < m.x*TAKE_DENSE+m.y*TAKE_GROVE*clump(px,pz): kind = GROVE
			elif roll > 1.0-m.z*LONE_P: kind = LONE
			if kind < 0: continue
			if _by_arch(near_arches,px,pz): continue
			var v := _variant(_hash01(si,sj,4))
			var sizes := SIZE_DENSE if kind == DENSE else (SIZE_GROVE if kind == GROVE else SIZE_LONE)
			var wide := WIDE_LONE if kind == LONE else WIDE_DENSE
			var sc := lerpf(sizes.x,sizes.y,_hash01(si,sj,5))
			var wd := lerpf(wide.x,wide.y,_hash01(si,sj,6))
			var spread := GAP_DENSE if kind == DENSE else GAP_GROVE
			var g := gap*(GAP_LONE if kind == LONE else lerpf(spread.x,spread.y,_hash01(si,sj,7)))
			cand.append([px,pz,_hash01(si,sj,8),(dims[v] as Vector3).x*sc*wd*SPACE_AT,g,kind,si,sj,v,sc,wd])
	# The thinning, in rank order (highest first) over the cell and its
	# border: a candidate stands unless one already standing is nearer than
	# their two crowns' reach and the wider gap of the two. The border is
	# wide enough that a cell and its neighbour agree on their shared edge
	# (all but rarely: a slip there only narrows one gap a little).
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	var grid := PackedInt32Array()
	grid.resize(n*n)
	grid.fill(-1)
	var kept := PackedByteArray()
	kept.resize(cand.size())
	var gap_most := gap*maxf(GAP_GROVE.y,GAP_DENSE.y)
	var r_reach := r_most*maxf(SIZE_LONE.y,SIZE_DENSE.y)*maxf(WIDE_LONE.y,WIDE_DENSE.y)*SPACE_AT
	for k in cand.size():
		var c: Array = cand[k]
		var px := float(c[0])
		var pz := float(c[1])
		var gi := int(c[6])-i0
		var gj := int(c[7])-j0
		var slots := int(ceil((float(c[3])+r_reach+maxf(float(c[4]),gap_most))/SLOT))+1
		var ok := true
		for dj in range(maxi(gj-slots,0),mini(gj+slots+1,n)):
			for di in range(maxi(gi-slots,0),mini(gi+slots+1,n)):
				var other := grid[dj*n+di]
				if other < 0: continue
				var o: Array = cand[other]
				var need := float(c[3])+float(o[3])+maxf(float(c[4]),float(o[4]))
				var dx := px-float(o[0])
				var dz := pz-float(o[1])
				if dx*dx+dz*dz < need*need:
					ok = false
					break
			if not ok: break
		if ok:
			grid[gj*n+gi] = k
			kept[k] = 1
	for k in cand.size():
		if kept[k] == 0: continue
		var c: Array = cand[k]
		var si := int(c[6])
		var sj := int(c[7])
		var px := float(c[0])
		var pz := float(c[1])
		if px < x0 or px >= x0+size or pz < z0 or pz >= z0+size: continue
		var y: float = field.height(px,pz)
		var hx: float = field.height(px+1.0,pz)
		var hz: float = field.height(px,pz+1.0)
		var tilt := Vector2(hx-y,hz-y).length()
		out.append_array([px,y-SINK-tilt*float(c[3])*0.3,pz,float(c[9]),float(c[10]),_hash01(si,sj,9)*TAU,float(c[8]),float(c[5])])
	return out

# --- The far plan ----------------------------------------------------------

## FAR_KEEP of the trees, each grown FAR_GROW (xz, y) to cover for the rest.
const FAR_KEEP := Vector3(0.24,0.3,1.0)
const FAR_GROW := Vector2(1.9,1.25)

## The far stand-ins of far cell (cx, cz) (FAR_CELL m): a coarser lattice
## of the same mask, thinned, each grown to cover (`trees`, STRIDE floats
## each), with the lattice's land for the forest floor: `h` the heights at
## the slots' middles two slots past the cell's edges (side `n`), `w` the
## woods' weight (`floor_weight`) one slot past (side n-2), `x`, `z` the
## world middle of the slot at h's [0].
func far_cell(field: RefCounted, cx: int, cz: int) -> Dictionary:
	var out := PackedFloat32Array()
	var own := int(FAR_CELL/FAR_SLOT)
	var n := own+4
	var i0 := floori(cx*FAR_CELL/FAR_SLOT)-2
	var j0 := floori(cz*FAR_CELL/FAR_SLOT)-2
	var got := {"trees":out,"h":PackedFloat32Array(),"w":PackedFloat32Array(),"n":n,"x":(i0+0.5)*FAR_SLOT,"z":(j0+0.5)*FAR_SLOT,"step":FAR_SLOT}
	if share <= 0.0: return got
	_forget()
	var x0 := cx*FAR_CELL
	var z0 := cz*FAR_CELL
	var near_arches := _arches_near(field,x0,z0,x0+FAR_CELL,z0+FAR_CELL)
	var hs := PackedFloat32Array()
	hs.resize(n*n)
	var shapes: Array = []
	shapes.resize(n*n)
	for j in n:
		for i in n:
			var s: Dictionary = field.shape((i0+i+0.5)*FAR_SLOT,(j0+j+0.5)*FAR_SLOT)
			shapes[j*n+i] = s
			hs[j*n+i] = float(s.height)
	var ws := PackedFloat32Array()
	ws.resize((n-2)*(n-2))
	# Near trees a slot of this lattice, by kind (the near plan's density,
	# measured: scratch/forest/map.gd), kept FAR_KEEP of.
	var per := Vector3(DENSITY.x,DENSITY.y,DENSITY.z)*FAR_SLOT*FAR_SLOT/10000.0
	for j in range(1,n-1):
		for i in range(1,n-1):
			var si := i0+i
			var sj := j0+j
			var cxm := (si+0.5)*FAR_SLOT
			var czm := (sj+0.5)*FAR_SLOT
			var gx := (hs[j*n+i+1]-hs[j*n+i-1])/(FAR_SLOT*2.0)
			var gz := (hs[(j+1)*n+i]-hs[(j-1)*n+i])/(FAR_SLOT*2.0)
			var up := 1.0/sqrt(1.0+gx*gx+gz*gz)
			var m := mask(field,cxm,czm,shapes[j*n+i],up)
			var c := clump(cxm,czm)
			ws[(j-1)*(n-2)+i-1] = floor_weight(m,c)
			var px := (si+0.5+(_hash01(si,sj,12)-0.5)*0.8)*FAR_SLOT
			var pz := (sj+0.5+(_hash01(si,sj,13)-0.5)*0.8)*FAR_SLOT
			if px < x0 or px >= x0+FAR_CELL or pz < z0 or pz >= z0+FAR_CELL: continue
			var want := m.x*per.x*FAR_KEEP.x+m.y*c*per.y*FAR_KEEP.y+m.z*per.z*FAR_KEEP.z
			var roll := _hash01(si,sj,11)
			if roll >= want: continue
			var kind := DENSE if roll < m.x*per.x*FAR_KEEP.x else (GROVE if roll < m.x*per.x*FAR_KEEP.x+m.y*c*per.y*FAR_KEEP.y else LONE)
			if _by_arch(near_arches,px,pz): continue
			var size := SIZE_DENSE if kind == DENSE else (SIZE_GROVE if kind == GROVE else SIZE_LONE)
			var sc := lerpf(size.x,size.y,_hash01(si,sj,15))
			var grow := FAR_GROW if kind != LONE else Vector2.ONE
			var y: float = field.height(px,pz)
			out.append_array([px,y-SINK,pz,sc*grow.y,grow.x/grow.y*(WIDE_LONE.x if kind == LONE else 1.1),_hash01(si,sj,16)*TAU,float(_variant(_hash01(si,sj,14))),float(kind)])
	got.trees = out
	got.h = hs
	got.w = ws
	return got

## The forest floor's weight (0..1) from a point's mask and grove clump: the
## dense woods' (after lanes and clearings) and FLOOR_GROVE of a clump's.
func floor_weight(m: Vector3, c: float) -> float:
	return clampf(m.x+m.y*c*FLOOR_GROVE,0.0,1.0)

## The floor's land and weights over a square (`step` m a node), as
## `far_cell` gives them: for scripts/endless/land_trees.gd's near blocks.
func floor_grid(field: RefCounted, x0: float, z0: float, size: float, step: float) -> Dictionary:
	var own := int(size/step)
	var n := own+4
	var ox := x0-1.5*step
	var oz := z0-1.5*step
	var hs := PackedFloat32Array()
	hs.resize(n*n)
	var shapes: Array = []
	shapes.resize(n*n)
	for j in n:
		for i in n:
			var s: Dictionary = field.shape(ox+i*step,oz+j*step)
			shapes[j*n+i] = s
			hs[j*n+i] = float(s.height)
	var ws := PackedFloat32Array()
	ws.resize((n-2)*(n-2))
	if share > 0.0:
		for j in range(1,n-1):
			for i in range(1,n-1):
				var x := ox+i*step
				var z := oz+j*step
				var gx := (hs[j*n+i+1]-hs[j*n+i-1])/(step*2.0)
				var gz := (hs[(j+1)*n+i]-hs[(j-1)*n+i])/(step*2.0)
				var m := mask(field,x,z,shapes[j*n+i],1.0/sqrt(1.0+gx*gx+gz*gz))
				ws[(j-1)*(n-2)+i-1] = floor_weight(m,clump(x,z))
	return {"h":hs,"w":ws,"n":n,"x":ox,"z":oz,"step":step}

## The near plan's trees a hectare at full weight, by kind (dense, grove
## in a clump, lone): measured with scratch/forest/map.gd.
const DENSITY := Vector3(40.0,35.0,0.025)
