extends RefCounted
## The regions world's land (--world=regions; spec-world-regions.md): one
## field per region's recipe (the native ZenScapeLandField where built, else
## LandField.GDField), blended by the region map's weights per sample. It
## stands where LandField's `_impl` stands and answers what a field answers
## (sample, shape, river_y, colour, the last_* reads, the flags), so the
## ponds, halls and tunnels layer over it as over one field.
##
## Where a point (or a chunk, `one_in`) lies wholly in one region it is that
## region's field and nothing else: the same numbers, the native chunk build
## untouched. Only in the border band does a sample ask every region there
## and blend: heights, meadow, the carve's groove and crest, the colour and
## the river's reads (distance, half-width, level, flow) by weight; the
## valley's reads (discrete: its line, floor, side) are the heaviest
## region's.
##
## The weights are the map's (region_map.gd) at a fixed lattice of LATTICE m,
## bilinear between: a function of the point alone (every chunk, LOD,
## collider and worker reads the same), exactly 1 and 0 inside a region
## (the lattice cell's corners all 1), and cheap (the map's own answer costs
## ~40 us; a cell's corners are cached). Each LandField owns its blend, so
## the caches are a thread's own.

const SEA_Y := -40.0
## The weights' lattice (m). The band is ~1.5 km, so its smoothstep is
## sampled every 64 m; between, bilinear.
const LATTICE := 64.0
## The caches' size before they are cleared (lattice corners, cells).
const KEEP := 60000
## The corners every field shares (the map's answers are the same for all),
## and its size before it is cleared.
const SHARED_KEEP := 400000
static var _shared := {}
static var _shared_lock := Mutex.new()

## The region fields by region index (the map's), and whether each is native.
var kids: Array[Object] = []
var kid_native: Array[bool] = []
## The region map (region_map.gd): pure maths, shared read-only.
var map: RefCounted
## The start region's index (the snow line's, until the paint blends).
var home := 0

var _n := 0
var _corners := {}
var _cells := {}
## The last point's weights (where it was in the band).
var _w := PackedFloat32Array()

## The last sample: the region it was wholly in (-1: in the band), the field
## it read (in the band, the heaviest region's) and the blended reads.
var _one := 0
var _kid: Object
var _h := 0.0
var _m := 0.0
var _cavity := 0.0
var _ridge := 0.0
var _mountain := 0.0
var _inland := 0.0
var _river := INF
var _river_r := INF
var _river_w := 0.0
var _river_y := -INF
var _drawn := -INF
var _flow := Vector2.ZERO
var _calm := 0.0

func _init(fields: Array, natives: Array, region_map: RefCounted, home_index := 0) -> void:
	for f: Object in fields: kids.append(f)
	for b: bool in natives: kid_native.append(b)
	map = region_map
	home = home_index
	_n = kids.size()
	_w.resize(_n)
	_kid = kids[home]
	_one = home

# --- The flags, set on every region's field --------------------------------------------

var mountains: float:
	get: return kids[home].mountains
	set(v): _all(&"mountains",v)
var peaks: float:
	get: return kids[home].peaks
	set(v): _all(&"peaks",v)
var valleys: float:
	get: return kids[home].valleys
	set(v): _all(&"valleys",v)
var old_land: bool:
	get: return kids[home].old_land
	set(v): _all(&"old_land",v)
var carve: float:
	get: return kids[home].carve
	set(v): _all(&"carve",v)
var carve_blocks: float:
	get: return kids[home].carve_blocks
	set(v): _all(&"carve_blocks",v)
var carve_ledges: float:
	get: return kids[home].carve_ledges
	set(v): _all(&"carve_ledges",v)
var carve_gullies: float:
	get: return kids[home].carve_gullies
	set(v): _all(&"carve_gullies",v)
var detail: float:
	get: return kids[home].detail
	set(v): _all(&"detail",v)
var rivers: float:
	get: return kids[home].rivers
	set(v): _all(&"rivers",v)
var river_width: float:
	get: return kids[home].river_width
	set(v): _all(&"river_width",v)
var river_drop: float:
	get: return kids[home].river_drop
	set(v): _all(&"river_drop",v)
var river_cut: float:
	get: return kids[home].river_cut
	set(v): _all(&"river_cut",v)
var river_fill: float:
	get: return kids[home].river_fill
	set(v): _all(&"river_fill",v)
var river_mouth: float:
	get: return kids[home].river_mouth
	set(v): _all(&"river_mouth",v)
var river_flare: float:
	get: return kids[home].river_flare
	set(v): _all(&"river_flare",v)

func _all(prop: StringName, v: Variant) -> void:
	for k in kids: k.set(prop,v)

# --- What the last sample found ---------------------------------------------------------

var last_mountain: float:
	get: return _kid.last_mountain if _one >= 0 else _mountain
var last_inland: float:
	get: return _kid.last_inland if _one >= 0 else _inland
var last_cavity: float:
	get: return _kid.last_cavity if _one >= 0 else _cavity
var last_ridge: float:
	get: return _kid.last_ridge if _one >= 0 else _ridge
var last_river: float:
	get: return _kid.last_river if _one >= 0 else _river
var last_river_r: float:
	get: return _kid.last_river_r if _one >= 0 else _river_r
var last_river_w: float:
	get: return _kid.last_river_w if _one >= 0 else _river_w
var last_river_y: float:
	get: return _kid.last_river_y if _one >= 0 else _river_y
var last_river_flow: Vector2:
	get: return _kid.last_river_flow if _one >= 0 else _flow
## The valley's: the heaviest region's.
var last_valley: float:
	get: return _kid.last_valley
var last_half: float:
	get: return _kid.last_half
var last_side: float:
	get: return _kid.last_side
var last_across: Vector2:
	get: return _kid.last_across
var last_floor: float:
	get: return _kid.last_floor

# --- The weights --------------------------------------------------------------------

## The map's weights at lattice corner (i, j), kept: this field's own
## cache, then the one every field shares (a worker's field is made fresh
## for each chunk, so its own starts cold).
func _corner(i: int, j: int) -> PackedFloat32Array:
	var key := Vector2i(i,j)
	var got: Variant = _corners.get(key)
	if got != null: return got
	if _corners.size() > KEEP: _corners.clear()
	_shared_lock.lock()
	got = _shared.get(key)
	_shared_lock.unlock()
	if got == null:
		got = map.weights(i*LATTICE,j*LATTICE)
		_shared_lock.lock()
		if _shared.size() > SHARED_KEEP: _shared.clear()
		_shared[key] = got
		_shared_lock.unlock()
	_corners[key] = got
	return got

## The region lattice cell (i, j) of LATTICE*2^k m lies wholly in (its four
## corners all 1 there), else -1; kept.
func _cell(i: int, j: int, k := 0) -> int:
	var key := Vector3i(i,j,k)
	var got: Variant = _cells.get(key)
	if got != null: return got
	if _cells.size() > KEEP: _cells.clear()
	var one := -1
	var u := 1 << k
	var a := _corner(i*u,j*u)
	for r in _n:
		if a[r] == 1.0:
			if _corner((i+1)*u,j*u)[r] == 1.0 and _corner(i*u,(j+1)*u)[r] == 1.0 and _corner((i+1)*u,(j+1)*u)[r] == 1.0: one = r
			break
	_cells[key] = one
	return one

## The region (x, z) lies wholly in, else -1 with its weights in `_w`, on the
## lattice of LATTICE*2^k m (`lattice_k`; 0, the finest, for every point
## query and the near chunks).
func _at(x: float, z: float, k := 0) -> int:
	var size := LATTICE*(1 << k)
	var fx := x/size
	var fz := z/size
	var i := floori(fx)
	var j := floori(fz)
	var one := _cell(i,j,k)
	if one >= 0: return one
	var tx := fx-i
	var tz := fz-j
	var u := 1 << k
	var a := _corner(i*u,j*u)
	var b := _corner((i+1)*u,j*u)
	var c := _corner(i*u,(j+1)*u)
	var d := _corner((i+1)*u,(j+1)*u)
	for r in _n:
		_w[r] = lerpf(lerpf(a[r],b[r],tx),lerpf(c[r],d[r],tx),tz)
	return -1

## The lattice a chunk of `step` m quads blends on: LATTICE, or twice the
## step for the far chunks (about 32 corners a side), so a far chunk asks
## the map about as often as a near one.
static func lattice_k(step: float) -> int:
	var k := 0
	while LATTICE*(1 << k) < step*2.0 and k < 8: k += 1
	return k

## The weights at (x, z), by region index (the lattice's, as the land reads
## them).
func weights(x: float, z: float) -> PackedFloat32Array:
	var one := _at(x,z)
	if one < 0: return _w.duplicate()
	var out := PackedFloat32Array()
	out.resize(_n)
	out[one] = 1.0
	return out

## The region the box (x0, z0)..(x1, z1) lies wholly in, else -1 (on the
## lattice `k`, as `_at`).
func one_in(x0: float, z0: float, x1: float, z1: float, k := 0) -> int:
	var one := -2
	var size := LATTICE*(1 << k)
	for j in range(floori(z0/size),floori(z1/size)+1):
		for i in range(floori(x0/size),floori(x1/size)+1):
			var c := _cell(i,j,k)
			if c < 0 or (one >= 0 and c != one): return -1
			one = c
	return maxi(one,-1)

# --- The field ----------------------------------------------------------------------

## Every region in the band at (x, z) sampled and blended by `_w`.
func _mix(x: float, z: float) -> void:
	_h = 0.0
	_m = 0.0
	_cavity = 0.0
	_ridge = 0.0
	_mountain = 0.0
	_inland = 0.0
	_river = 0.0
	_river_r = 0.0
	_river_w = 0.0
	_flow = Vector2.ZERO
	_calm = 0.0
	var ry := 0.0
	var dr := 0.0
	var wet := 0.0
	var best := -1.0
	for r in _n:
		var wt := _w[r]
		if wt <= 0.0: continue
		var k: Object = kids[r]
		var s: Vector2 = k.sample(x,z)
		if wt > best:
			best = wt
			_kid = k
		_h += wt*s.x
		_m += wt*s.y
		_cavity += wt*float(k.last_cavity)
		_ridge += wt*float(k.last_ridge)
		_mountain += wt*float(k.last_mountain)
		_inland += wt*float(k.last_inland)
		_river += wt*minf(float(k.last_river),1000.0)
		_river_r += wt*clampf(float(k.last_river_r),-1000.0,1000.0)
		_river_w += wt*float(k.last_river_w)
		_flow += wt*(k.last_river_flow as Vector2)
		_calm += wt*float(k.calm_here())
		var y := float(k.last_river_y)
		if y > -INF:
			ry += wt*y
			dr += wt*float(k.river_drawn())
			wet += wt
	# The level among the regions with a river there (none: no river).
	_river_y = ry/wet if wet > 0.0 else -INF
	_drawn = dr/wet if wet > 0.0 else -INF

## Vector2(world height, meadow 0..1) at a world XZ point.
func sample(x: float, z: float) -> Vector2:
	var one := _at(x,z)
	_one = one
	if one >= 0:
		_kid = kids[one]
		return _kid.sample(x,z)
	_mix(x,z)
	return Vector2(_h,_m)

func shape(x: float, z: float) -> Dictionary:
	var one := _at(x,z)
	_one = one
	if one >= 0:
		_kid = kids[one]
		return _kid.shape(x,z)
	_mix(x,z)
	return {"height":_h,"meadow":_m,"mountain":_mountain,"inland":_inland,"valley":last_valley,"half":last_half,"side":last_side,"across":last_across,
		"river":_river,"river_r":_river_r,"river_w":_river_w,"river_y":_river_y}

func river_y(x: float, z: float) -> float:
	sample(x,z)
	if last_river < 0.0 and river_drawn() > SEA_Y+0.05: return river_drawn()
	return NAN

func river_drawn() -> float:
	return _kid.river_drawn() if _one >= 0 else _drawn

func calm_here() -> float:
	return _kid.calm_here() if _one >= 0 else _calm

func sea_calm(x: float, z: float) -> float:
	sample(x,z)
	return calm_here()

func height(x: float, z: float) -> float:
	return sample(x,z).x

## The start region's (the ground shader's one snow line, until the paint
## blends per spot); each region's colour keeps its own.
func snow_line() -> float:
	return kids[home].snow_line()

func colour(x: float, z: float, y: float, up: float, meadow: float) -> Color:
	var one := _at(x,z)
	if one >= 0: return kids[one].colour(x,z,y,up,meadow)
	var c := Color(0.0,0.0,0.0,0.0)
	for r in _n:
		var wt := _w[r]
		if wt <= 0.0: continue
		var kc: Color = kids[r].colour(x,z,y,up,meadow)
		c += kc*wt
	return c

# --- A chunk in the band ------------------------------------------------------------

## LandField.build_chunk's arrays for a chunk in the band, from each region's
## own native build of it, blended per vertex: heights, meadow, the carve's
## bytes, the river's floats by weight (its level among the regions with a
## river there); the normals of the blended surface (each region's slope by
## weight, plus each height times the weight's slope); the colour each
## region gives the blended height, slope and meadow, by weight. The same
## land as `sample` (to the float32 rounding of the regions' heights).
func build_chunk(x0: float, z0: float, step: float, cells: int, skirt_drop: float, flow_max: float) -> Dictionary:
	var n := cells+1
	var w := n+2
	var lk := lattice_k(step)
	# The weights over the chunk and a one-sample rim (for their slope).
	var ws := PackedFloat32Array()
	ws.resize(w*w*_n)
	var used := PackedByteArray()
	used.resize(_n)
	for j in w:
		for i in w:
			var one := _at(x0+(i-1)*step,z0+(j-1)*step,lk)
			var q := (j*w+i)*_n
			for r in _n:
				var v := (1.0 if r == one else 0.0) if one >= 0 else _w[r]
				ws[q+r] = v
				if v > 0.0: used[r] = 1
	var made: Array = []
	for r in _n:
		made.append(kids[r].build_chunk(x0,z0,step,cells,skirt_drop,flow_max) if used[r] == 1 else {})
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var carved := PackedByteArray()
	var river := PackedFloat32Array()
	var heights := PackedFloat32Array()
	verts.resize(n*n+4*n)
	normals.resize(n*n+4*n)
	colours.resize(n*n+4*n)
	carved.resize((n*n+4*n)*4)
	river.resize((n*n+4*n)*3)
	heights.resize(n*n)
	var inv := 1.0/(2.0*step)
	for j in n:
		for i in n:
			var v := j*n+i
			var q := ((j+1)*w+i+1)*_n
			var y := 0.0
			var gx := 0.0
			var gz := 0.0
			var meadow := 0.0
			var c0 := 0.0
			var c1 := 0.0
			var c2 := 0.0
			var c3 := 0.0
			var rr := 0.0
			var rw := 0.0
			var ry := 0.0
			var wet := 0.0
			for r in _n:
				if used[r] == 0: continue
				var wt := ws[q+r]
				var m: Dictionary = made[r]
				var h: float = (m.heights as PackedFloat32Array)[v]
				# The weight's slope (zero where the rim is wholly one region).
				gx += h*(ws[q+_n+r]-ws[q-_n+r])*inv
				gz += h*(ws[q+w*_n+r]-ws[q-w*_n+r])*inv
				if wt <= 0.0: continue
				var nm: Vector3 = (m.normals as PackedVector3Array)[v]
				y += wt*h
				gx -= wt*nm.x/nm.y
				gz -= wt*nm.z/nm.y
				meadow += wt*(m.colours as PackedColorArray)[v].a
				var cb: PackedByteArray = m.carved
				c0 += wt*cb[v*4]
				c1 += wt*cb[v*4+1]
				c2 += wt*cb[v*4+2]
				c3 += wt*cb[v*4+3]
				var rv: PackedFloat32Array = m.river
				rr += wt*rv[v*3]
				rw += wt*rv[v*3+1]
				if rv[v*3+2] > SEA_Y-99.0:
					ry += wt*rv[v*3+2]
					wet += wt
			var normal := Vector3(-gx,1.0,-gz).normalized()
			verts[v] = Vector3(i*step,y,j*step)
			normals[v] = normal
			heights[v] = y
			var c := Color(0.0,0.0,0.0,0.0)
			for r in _n:
				var wt := ws[q+r]
				if wt <= 0.0: continue
				var kc: Color = kids[r].colour(x0+i*step,z0+j*step,y,normal.y,meadow)
				c += kc*wt
			c.a = meadow
			colours[v] = c
			carved[v*4] = int(roundf(c0))
			carved[v*4+1] = int(roundf(c1))
			carved[v*4+2] = int(roundf(c2))
			carved[v*4+3] = int(roundf(c3))
			river[v*3] = rr
			river[v*3+1] = rw
			river[v*3+2] = ry/wet if wet > 0.0 else SEA_Y-100.0
	# The skirt: each edge's vertices again, dropped.
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			for b in 4: carved[v*4+b] = carved[from*4+b]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	return {"verts":verts,"normals":normals,"colours":colours,"carved":carved,"river":river,"heights":heights}

## Whether every region's field is native (the band's chunks blend their
## native builds; else they are sampled point by point).
func all_native() -> bool:
	return not kid_native.has(false)
