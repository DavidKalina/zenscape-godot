extends RefCounted
## Slot halls (docs/design/endless-flight/overgrown-halls-handoff.md): a
## clean cut straight through a ridge, from foot to foot, and a Sundered
## hall standing in it (scripts/sundered_hall.gd `slot_piece`), its walls
## against the cut's rock, its roof spanning wall to wall in places and open
## in others. A layer over the land field, as the ponds are: LandField
## (land_field.gd) cuts the slot in after the native or GDScript field has
## worked, so both fields read the same slots and nothing native changes.
##
## At most one hall per CELL m square, from the seed and the square alone.
## A square rolls (CHANCE times the density), then scans its middle for a
## ridge's crest (`mountain` at least CREST_MIN) and tries the best spots:
## the crest's way read off a ring round the spot, the spot moved onto the
## crest, the crest checked straight either side of it, then the ridge
## walked out across to its feet. The hall runs foot to foot, in whole bays.
## Its centre is kept MARGIN m inside the square and its reach under that,
## so a point only asks its own square.
##
## The cut: inside the slot's half width (the hall's walls' outer faces)
## the land comes down to the floor; past it the rock stands back up within
## EDGE m to SHEER m over the floor (the sheer, sundered walls), and over
## that the walls lean back at LEAN (run over rise) to the land, so the cut
## opens into a notch in the ridgeline that reads from afar. Past the
## hall's ends the floor runs flat for APRON m, then climbs at GRADE till it
## meets the land.
##
## A site is a PackedFloat32Array: [centre x, centre z, way x, way z (unit,
## the nave's +X), half length (the hall's), half width (the slot's), floor
## (the land's, under the hall's), reach (half length of the whole cut),
## the cut's half width at its widest (its top)].
## `site_info` has the rest (the name, the hall frame, the bays, the seed).
##
## In a world of regions (the field a LandBlend) a hall stands only where
## its whole cut, and SITE_CLEAR m round it, lies in one region that grows
## halls (LandBlend `site_ok`), so no cut meets a border band.
##
## Each is named `<world>/hall/<cx>_<cz>` and placed through
## scripts/layout_overrides.gd: a move in the layout file moves the hall and
## its cut (only its yaw and place are kept), a deletion drops both.

const SEA_Y := -40.0
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Sundered = preload("res://scripts/sundered_hall.gd")
const Ponds = preload("res://scripts/endless/land_ponds.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")

const CELL := 1024.0
const MARGIN := 300.0
## The share of squares that roll a hall (times the density, up to CHANCE_MAX).
const CHANCE := 0.7
const CHANCE_MAX := 0.95
## The scan of a square's middle (spots a side) and the best spots tried.
const SCAN := 9
const TRIES := 8
## The crest: its `mountain` at the least, the ring its way is read off (m),
## how far either side it is looked for (m), how far along it is checked
## straight (m) and how far off the line its middle may stand (m).
const CREST_MIN := 0.6
const RING := 30.0
const SNAP := 60.0
const ALONG := 50.0
const BEND := 10.0
## The walk out to the feet: step (m), how far (m), the flank's slope
## (rise over run, over FOOT_RUN m) the foot eases under, a river's water
## kept this far off (m).
const WALK := 4.0
const WALK_MOST := 200.0
const FOOT_SLOPE := 0.12
const FOOT_RUN := 12.0
const RIVER_OFF := 30.0
## The crest at least this far over the floor (m), the hall's bays.
const TALL_MIN := 30.0
const BAYS := Vector2i(10,24)
## The slot's half width: the hall's walls' outer faces, and a little.
static var HALF: float = Hall.WALL_Z+Hall.WALL_THICK*0.5+0.5
## The walls: their rise (m across, from the floor to SHEER m over it),
## then their lean back (run over rise) to the land. The land's floor under
## the hall's (m), the flat past each end (m: the apse's ring stands in it)
## and the climb past that (rise over run), its most (m).
const EDGE := 2.0
const SHEER := 30.0
const LEAN := 0.35
const SINK := 0.4
const APRON := 16.0
const GRADE := 0.25
const RAMP_MOST := 100.0
## How far over the crest the land round a cut may stand (m: its top width).
const TOP_OVER := 25.0

static var _cache := {}
static var _info := {}
static var _lock := Mutex.new()

## The halls' density: the world's `halls` layer (0: none), then
## `--halls=X` or `--no-halls`.
static func wanted(default := 0.0) -> float:
	var out := default
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == "--no-halls": out = 0.0
		elif a.begins_with("--halls="): out = maxf(0.0,float(a.get_slice("=",1)))
	return out

static func _hash01(seed: int, i: int, j: int, salt: int) -> float:
	return float(hash([seed,i,j,salt,4421]) & 0xffffff)/16777216.0

## The site of the CELL square holding (x, z), or an empty array. `impl` is
## the field doing the work (its last sample is overwritten when the square
## is first looked at); `local` is the asking LandField's own cache;
## `ponds` the field's pond density (a hall keeps off the ponds).
static func cell_site(impl: Object, seed: int, density: float, ponds: float, x: float, z: float, local: Dictionary) -> PackedFloat32Array:
	var key := Vector2i(floori(x/CELL),floori(z/CELL))
	var got: Variant = local.get(key)
	if got != null: return got
	var k4 := Vector4i(key.x,key.y,seed,int(density*1000.0))
	_lock.lock()
	got = _cache.get(k4)
	_lock.unlock()
	if got == null:
		# Read at full detail whatever chunk the asking field last built (its
		# carve fades by `detail`), so the same land gives the same halls.
		var was: float = impl.detail
		impl.detail = 0.0
		var made := _make(impl,seed,density,ponds,key.x,key.y)
		impl.detail = was
		got = made.get("site",PackedFloat32Array())
		_lock.lock()
		_cache[k4] = got
		if not made.is_empty(): _info[k4] = made
		_lock.unlock()
	local[key] = got
	return got

## A square's hall, for the builder: {name, key, site, frame (the hall
## frame in the world: the gate's mouth at the floor, the nave along +X),
## bays, seed, length}, or empty. Asks `cell_site` first.
static func site_info(impl: Object, seed: int, density: float, ponds: float, key: Vector2i) -> Dictionary:
	cell_site(impl,seed,density,ponds,(key.x+0.5)*CELL,(key.y+0.5)*CELL,{})
	_lock.lock()
	var got: Dictionary = _info.get(Vector4i(key.x,key.y,seed,int(density*1000.0)),{})
	_lock.unlock()
	return got

## Every site whose cut meets the box (x0, z0)..(x1, z1).
static func sites_in(impl: Object, seed: int, density: float, ponds: float, x0: float, z0: float, x1: float, z1: float, local: Dictionary) -> Array:
	var out: Array = []
	for cj in range(floori(z0/CELL),floori(z1/CELL)+1):
		for ci in range(floori(x0/CELL),floori(x1/CELL)+1):
			var s := cell_site(impl,seed,density,ponds,(ci+0.5)*CELL,(cj+0.5)*CELL,local)
			if s.is_empty(): continue
			var r := s[7]+s[8]
			if s[0]+r < x0 or s[0]-r > x1 or s[1]+r < z0 or s[1]-r > z1: continue
			out.append(s)
	return out

## (x, z) in site `s`'s frame: Vector2(along the nave from its middle, across).
static func local(s: PackedFloat32Array, x: float, z: float) -> Vector2:
	var dx := x-s[0]
	var dz := z-s[1]
	return Vector2(dx*s[2]+dz*s[3],-dx*s[3]+dz*s[2])

## True where (x, z) is on the cut (its floor or its walls' rise), or
## within `margin` m of it.
static func on_cut(s: PackedFloat32Array, x: float, z: float, margin := 0.0) -> bool:
	var q := local(s,x,z)
	return absf(q.x) <= s[7]+margin and absf(q.y) <= s[8]+margin

## The land's height `base` with site `s`'s slot cut in at (x, z).
static func carve(s: PackedFloat32Array, base: float, x: float, z: float) -> float:
	var q := local(s,x,z)
	var au := absf(q.x)
	var av := absf(q.y)
	if au > s[7] or av > s[8]: return base
	var lid := s[6]
	var past := au-s[4]-APRON
	if past > 0.0: lid += past*GRADE
	if base <= lid: return base
	if av <= s[5]: return lid
	if av <= s[5]+EDGE: return minf(base,lid+SHEER*(av-s[5])/EDGE)
	return minf(base,lid+SHEER+(av-s[5]-EDGE)/LEAN)

# --- Finding a site ------------------------------------------------------------------

static func _make(impl: Object, seed: int, density: float, ponds: float, ci: int, cj: int) -> Dictionary:
	if density <= 0.0: return {}
	if _hash01(seed,ci,cj,1) >= minf(CHANCE*density,CHANCE_MAX): return {}
	var x0 := ci*CELL+MARGIN
	var z0 := cj*CELL+MARGIN
	var span := CELL-MARGIN*2.0
	var spots: Array = []
	var gated := impl.has_method("site_ok")
	for gj in SCAN:
		for gi in SCAN:
			var x := x0+(gi+0.5)/SCAN*span
			var z := z0+(gj+0.5)/SCAN*span
			# In a world of regions, only where the land is wholly a region
			# that grows halls (LandBlend `site_spot`).
			if gated and not impl.site_spot(&"halls",x,z): continue
			impl.sample(x,z)
			var m: float = impl.last_mountain
			if m >= CREST_MIN: spots.append([m,x,z])
	if spots.is_empty(): return {}
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for t in mini(TRIES,spots.size()):
		var got := _fit(impl,seed,ponds,ci,cj,float(spots[t][1]),float(spots[t][2]))
		if not got.is_empty(): return got
	return {}

static func _h(impl: Object, x: float, z: float) -> float:
	return (impl.sample(x,z) as Vector2).x

## The crest nearest (x, z) across way `d`: the highest point along it.
static func _snap(impl: Object, p: Vector2, d: Vector2, reach: float, step: float) -> Vector2:
	var best := p
	var top := -INF
	var t := -reach
	while t <= reach:
		var q := p+d*t
		var h := _h(impl,q.x,q.y)
		if h > top:
			top = h
			best = q
		t += step
	return best

## Walks from `c` (the crest, `top` high) along `d` to the ridge's foot,
## where the flank eases under FOOT_SLOPE over FOOT_RUN m: Vector3(distance,
## height there, 1 if fit else 0: never on a river's water or the sea).
static func _foot(impl: Object, c: Vector2, d: Vector2, top: float) -> Vector3:
	var back := int(FOOT_RUN/WALK)
	var hs: Array = [top]
	var t := WALK
	while t <= WALK_MOST:
		var q := c+d*t
		var h: float = (impl.sample(q.x,q.y) as Vector2).x
		if h < SEA_Y+3.0 or float(impl.last_river) < RIVER_OFF: return Vector3(t,h,0.0)
		hs.append(h)
		if hs.size() > back and top-h > TALL_MIN and (float(hs[-1-back])-h)/FOOT_RUN < FOOT_SLOPE: return Vector3(t,h,1.0)
		t += WALK
	return Vector3(t,0.0,0.0)

static func _fit(impl: Object, seed: int, ponds: float, ci: int, cj: int, x: float, z: float) -> Dictionary:
	# Up the slope onto the crest (across the ridge on a flank).
	var e := 6.0
	var g := Vector2(_h(impl,x+e,z)-_h(impl,x-e,z),_h(impl,x,z+e)-_h(impl,x,z-e))
	var c := Vector2(x,z)
	if g.length() > 0.01: c = _snap(impl,c,g.normalized(),SNAP,3.0)
	# The crest's way: where a ring round it stays highest both ways.
	var best_a := 0.0
	var best_h := -INF
	for k in 16:
		var a := PI*k/16.0
		var w := Vector2(cos(a),sin(a))*RING
		var h := _h(impl,c.x+w.x,c.y+w.y)+_h(impl,c.x-w.x,c.y-w.y)
		if h > best_h:
			best_h = h
			best_a = a
	var along := Vector2(cos(best_a),sin(best_a))
	var across := Vector2(-along.y,along.x)
	c = _snap(impl,c,across,SNAP*0.5,2.0)
	# Straight: the crest either side, and the middle on their line.
	var c1 := _snap(impl,c-along*ALONG,across,SNAP*0.7,3.0)
	var c2 := _snap(impl,c+along*ALONG,across,SNAP*0.7,3.0)
	var line := (c2-c1).normalized()
	var off := absf((c-c1).dot(Vector2(-line.y,line.x)))
	if off > BEND: return {}
	across = Vector2(-line.y,line.x)
	var hc := _h(impl,c.x,c.y)
	var fa := _foot(impl,c,-across,hc)
	var fb := _foot(impl,c,across,hc)
	if fa.z < 1.0 or fb.z < 1.0: return {}
	var floor_y := minf(fa.y,fb.y)
	if hc-floor_y < TALL_MIN or floor_y < SEA_Y+4.0: return {}
	var crossing := fa.x+fb.x
	var bays := roundi(crossing/Hall.BAY)
	if bays < BAYS.x or bays > BAYS.y: return {}
	var mid := c+across*((fb.x-fa.x)*0.5)
	# The way the gate faces, from the seed.
	if _hash01(seed,ci,cj,2) < 0.5: across = -across
	var piece := Sundered.slot_piece(hash([seed,ci,cj,"hall"]),bays)
	bays = int(piece.bays)
	var half_len := bays*Hall.BAY*0.5
	# The climb out of each end, to where it meets the land.
	var rise := maxf(fa.y,fb.y)-floor_y
	var reach := half_len+APRON+minf(rise/GRADE+12.0,RAMP_MOST)
	if mid.distance_to(Vector2((ci+0.5)*CELL,(cj+0.5)*CELL)) > CELL*0.5-reach-HALF-EDGE-(hc+TOP_OVER-floor_y-SHEER)*LEAN: return {}
	var name := "%s/hall/%d_%d" % [_world_id(),ci,cj]
	if LayoutOverrides.deleted(name): return {}
	var yaw := atan2(-across.y,across.x)
	var mouth := Vector3(mid.x-across.x*half_len,floor_y,mid.y-across.y*half_len)
	var coded := Transform3D(Basis(Vector3.UP,yaw),mouth)
	var site := _site(coded,half_len,reach,hc)
	var centre := Vector2(site[0],site[1])
	var way := Vector2(site[2],site[3])
	# In a world of regions, the whole cut inside one region that grows
	# halls, clear of the band (the coded place: a move in the layout file
	# still wins).
	if impl.has_method("site_ok"):
		var ex := absf(way.x)*site[7]+absf(way.y)*site[8]
		var ez := absf(way.y)*site[7]+absf(way.x)*site[8]
		if not impl.site_ok(&"halls",centre.x-ex,centre.y-ez,centre.x+ex,centre.y+ez): return {}
	# The ends climb out to the land within the reach, and no pond is near.
	for end: float in [-1.0,1.0]:
		var q := centre+way*end*reach
		if _h(impl,q.x,q.y) > floor_y-SINK+(reach-half_len-APRON)*GRADE+1.0: return {}
	if ponds > 0.0:
		for pond: PackedFloat32Array in Ponds.ponds_in(impl,seed,ponds,centre.x-reach,centre.y-reach,centre.x+reach,centre.y+reach,{}):
			var q := local(site,pond[0],pond[1])
			if absf(q.x) < reach+pond[11]+Ponds.REACH and absf(q.y) < site[8]+pond[11]+Ponds.REACH: return {}
	# A move in the layout file wins (its yaw and place), checks or none.
	var xf := LayoutOverrides.xform(name,coded)
	var frame := Transform3D(Basis(Vector3.UP,atan2(-xf.basis.x.z,xf.basis.x.x)),xf.origin)
	if frame != coded: site = _site(frame,half_len,reach,hc)
	var info := {"name":name,"key":Vector2i(ci,cj),"site":site,"frame":frame,"coded":coded,"bays":bays,"seed":hash([seed,ci,cj,"hall"]),
		"length":half_len*2.0,"crest":hc,"floor":frame.origin.y}
	return info

## A site's array for the hall frame `frame` (the gate's mouth at the floor).
static func _site(frame: Transform3D, half_len: float, reach: float, crest: float) -> PackedFloat32Array:
	var way := Vector2(frame.basis.x.x,frame.basis.x.z).normalized()
	var centre := Vector2(frame.origin.x,frame.origin.z)+way*half_len
	var wide := HALF+EDGE+maxf(crest+TOP_OVER-frame.origin.y-SHEER,0.0)*LEAN
	return PackedFloat32Array([centre.x,centre.y,way.x,way.y,half_len,HALF,frame.origin.y-SINK,reach,wide])

static func _world_id() -> String:
	return String(preload("res://scripts/endless/world/world_profile.gd").current().id)

# --- The cut over a chunk's and a grid's arrays ------------------------------------

## The slot pass over a chunk's arrays (LandField.build_chunk; its args),
## after the ponds'. `field` is the LandField (its `height` has the slots in).
static func apply_chunk(field: Object, impl: Object, made: Dictionary, ss: Array, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var moved := PackedByteArray()
	moved.resize(n*n)
	var any_moved := false
	for s: PackedFloat32Array in ss:
		var r := s[7]+s[8]
		var i0 := clampi(floori((s[0]-r-x0)/step),0,cells)
		var i1 := clampi(ceili((s[0]+r-x0)/step),0,cells)
		var j0 := clampi(floori((s[1]-r-z0)/step),0,cells)
		var j1 := clampi(ceili((s[1]+r-z0)/step),0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var v := j*n+i
				var y := carve(s,heights[v],x0+i*step,z0+j*step)
				if absf(y-heights[v]) > 0.0005:
					heights[v] = y
					verts[v] = Vector3(verts[v].x,y,verts[v].z)
					moved[v] = 1
					any_moved = true
	if not any_moved: return
	# Normals round what moved (central differences, as the field's), and
	# the colour for them; the carve's groove and crest off the cut rock.
	var redo := PackedByteArray()
	redo.resize(n*n)
	for j in n:
		for i in n:
			if moved[j*n+i] == 0: continue
			for d: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var ii := i+d.x
				var jj := j+d.y
				if ii >= 0 and ii < n and jj >= 0 and jj < n: redo[jj*n+ii] = 1
	for j in n:
		for i in n:
			var v := j*n+i
			if redo[v] == 0: continue
			var x := x0+i*step
			var z := z0+j*step
			var hl: float = heights[v-1] if i > 0 else field.height(x-step,z)
			var hr: float = heights[v+1] if i < cells else field.height(x+step,z)
			var hd: float = heights[v-n] if j > 0 else field.height(x,z-step)
			var hu: float = heights[v+n] if j < cells else field.height(x,z+step)
			var normal := Vector3(hl-hr,2.0*step,hd-hu).normalized()
			normals[v] = normal
			var meadow := colours[v].a
			if moved[v] != 0: meadow = 0.0
			var c: Color = impl.colour(x,z,heights[v],normal.y,meadow)
			c.a = meadow
			colours[v] = c
			if moved[v] != 0:
				carved[v*4] = 0
				carved[v*4+1] = 0
	# The skirt's copies of the edges.
	var edges := [[],[],[],[]]
	for t in n:
		edges[0].append(t)
		edges[1].append(t*n+cells)
		edges[2].append(cells*n+t)
		edges[3].append(t*n)
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			if redo[from] == 0: continue
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			for q in 4: carved[v*4+q] = carved[from*4+q]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The slot pass over LandField.grid's arrays (the grass's): the cut's
## heights, and its floor and walls read as a river's water (`river` -1),
## so no tuft or flower grows in the slot.
static func apply_grid(got: Dictionary, ss: Array, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var rs: PackedFloat32Array = got.river
	for s: PackedFloat32Array in ss:
		var r := s[7]+s[8]
		var i0 := clampi(floori((s[0]-r-x0)/step)+pad,0,nx-1)
		var i1 := clampi(ceili((s[0]+r-x0)/step)+pad,0,nx-1)
		var j0 := clampi(floori((s[1]-r-z0)/step)+pad,0,nz-1)
		var j1 := clampi(ceili((s[1]+r-z0)/step)+pad,0,nz-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var x := x0+(i-pad)*step
				var z := z0+(j-pad)*step
				var q := local(s,x,z)
				if absf(q.x) > s[7] or absf(q.y) > s[8]: continue
				var k := j*nx+i
				hs[k] = carve(s,hs[k],x,z)
				if absf(q.y) <= s[5]+EDGE+1.0 and (absf(q.x) <= s[4]+APRON or hs[k] < s[6]+0.5): rs[k] = minf(rs[k],-1.0)
	got.heights = hs
	got.river = rs
