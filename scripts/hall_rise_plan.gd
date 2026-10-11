extends RefCounted
## The Sundered hall rising out of the cloud sea in a few big chunks
## (docs/design/hall-rise.md): plain data, safe on a worker, the same every
## time.
##
## The hall is the moments set piece the sky world stands (`moments_hall`,
## scripts/sky_moments_plan.gd layout 0: sundered_flow's greybox stone, two
## halves with the gap between). Its solids are taken exactly as SkyMoments
## stands them (`Plan.local_solids`, the station's own metres, the entry at
## 0 flying north), and each goes to exactly one chunk, so the settled hall
## is the same hall: the line, the moments and the tokens still fit. Each
## bay is laid again here (FlightCourse `_bay`, the same order) only to say
## which bay each solid is in.
##
## The chunks (CHUNKS) are runs of whole bays along the nave, each fully
## formed (floor, columns, walls, arches, roof): the gate half's roofed nave,
## its torn end, the far half's screened bays and its apse. They are split
## along the nave rather than stacked (a base, then walls, then a roof)
## because every chunk rises straight up: one standing over another would
## have to come up through it. Each chunk rises whole, one after another
## (`from`: the apse first, or the gate first), at a steady speed, eases
## to a stop a hand's breadth over its place and sinks gently into it.
##
## Additions, both off by default: `keels` hangs a faceted rock keel under
## each bay's floor (it rises with its bay's chunk), `stones` adds a last
## chunk of floating stones (clear of the line and every moment).
##
## Each chunk: {id, title, bays (first, last), solids (indices into
## `local_solids`), extra (keels or stones: their own solids), pivot (the
## middle of its box, station metres), lo, hi (its box), boxes (each
## solid's box, for the plane check), rim (points round its floors, at the
## floor tops: where the cloud breaks), top (the chunk's top over its
## pivot), start (s), from_y (its pivot's height when it starts, under the
## cloud), and the motion: speed (m/s), ease_in, ease_out (m), over (m),
## t_in, t_run, t_out, settle (s)}.

const Course = preload("res://scripts/flight_course.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")

## The moments layout this is (sky_moments_plan.gd: 0 is moments_hall).
const LAYOUT := 0
## The chunks, along the nave: bays first to last (sky_moments_plan's
## moments_hall: bays 0-8 the gate half, 9-14 the far half).
const CHUNKS := [
	{"id":"gate","title":"the gate's roofed nave","bays":[0,4]},
	{"id":"torn","title":"the torn end","bays":[5,8]},
	{"id":"screens","title":"the screened bays","bays":[9,11]},
	{"id":"apse","title":"the apse","bays":[12,14]},
]
## The rise, all of it tunable by flag (scripts/hall_rise.gd `options`):
##   speed     m/s, the steady speed through the cloud top
##   ease_in   m it takes to get up to speed (under the cloud)
##   ease_out  m it takes to slow to a stop
##   over      m over its place it stops at, before it sinks in (0: none)
##   settle    s the sink into place takes
##   gap       s between one chunk's start and the next's
##   lead      s before the first chunk starts (the cloud swells first)
##   under     m under the cloud top a chunk's top starts
const RISE := {"speed":9.0,"ease_in":5.0,"ease_out":8.0,"over":0.35,"settle":1.3,"gap":1.5,"lead":0.6,"under":6.0}
## Where the cloud top is (station metres) when the caller doesn't say.
const SEA := -26.0
## Rim points every this many metres round each floor.
const RIM_STEP := 3.0
static var HALF_W: float = Hall.WALL_Z+Hall.WALL_THICK*0.5
## The keels: depth under the floor (m, at a half's middle and its ends),
## how far the bottom draws in (share of the top), the jitter (m).
const KEEL_DEEP := Vector2(16.0,6.0)
const KEEL_TAPER := 0.42
const KEEL_JITTER := 1.6
## The floating stones: how many, their size (m), seed, and how far they
## keep from the line and every moment (m, past their own half diagonal).
const STONES := 9
const STONE_SIZE := Vector2(1.6,4.2)
const STONE_SEED := 7
const STONE_KEEP := 7.0

## The hall's chunks, planned and timed. opts: sea (the cloud top, station
## metres, SEA), from ("apse" or "gate": which end rises first, "apse"),
## keels (false), stones (false), and any of RISE's keys (speed, ease_in,
## ease_out, over, settle, gap, lead, under).
static func make(opts := {}) -> Dictionary:
	var solids := Plan.local_solids(LAYOUT)
	var info := classify()
	var chunks := _group(solids,info,opts)
	schedule(chunks,opts)
	return {"solids":solids,"chunks":chunks,"length":length(chunks),"sea":float(opts.get("sea",SEA))}

## The same chunks as `base` (a `make` with the same from, keels and stones),
## timed again for `opts` (a chain's next hall, its cloud top elsewhere in
## its frame): no classify, no grouping, so it is cheap on the main thread.
## The chunks' own data (solids, boxes, rim) is shared with `base`, read only.
static func remake(base: Dictionary, opts := {}) -> Dictionary:
	var chunks := []
	for c: Dictionary in base.chunks: chunks.append(c.duplicate())
	schedule(chunks,opts)
	return {"solids":base.solids,"chunks":chunks,"length":length(chunks),"sea":float(opts.get("sea",SEA))}

## `base` (a `make`) mirrored across the hall's length (x to -x, station
## metres): the same hall swinging left where it swung right (a chain's
## every other hall, scripts/hall_chain_plan.gd). Boxes keep a proper turn
## (their basis mirrored on both sides), so the kit draws and collides
## with them as ever. Its chunks are timed as `base`'s; `remake` it.
static func mirrored(base: Dictionary) -> Dictionary:
	var solids := []
	for q: Dictionary in base.solids: solids.append(mirror_solid(q))
	var chunks := []
	for c: Dictionary in base.chunks:
		var m := c.duplicate()
		var lo: Vector3 = c.lo
		var hi: Vector3 = c.hi
		m.lo = Vector3(-hi.x,lo.y,lo.z)
		m.hi = Vector3(-lo.x,hi.y,hi.z)
		m.pivot = _flip(c.pivot)
		var boxes := []
		for b: AABB in c.boxes: boxes.append(AABB(Vector3(-b.end.x,b.position.y,b.position.z),b.size))
		m.boxes = boxes
		var rim := PackedVector3Array()
		for p: Vector3 in c.rim: rim.append(_flip(p))
		m.rim = rim
		var extra := []
		for q: Dictionary in c.extra: extra.append(mirror_solid(q))
		m.extra = extra
		chunks.append(m)
	return {"solids":solids,"chunks":chunks,"length":base.length,"sea":base.sea,"mirrored":true}

## One solid mirrored across x.
static func mirror_solid(q: Dictionary) -> Dictionary:
	var m := q.duplicate()
	if q.has("middle"): m.middle = _flip(q.middle)
	if q.has("basis"):
		var f := Basis(Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,0,1))
		m.basis = (f*(q.basis as Basis)*f).orthonormalized()
	if q.has("points"):
		var pts := PackedVector3Array()
		for p: Vector3 in q.points: pts.append(_flip(p))
		m.points = pts
	return m

static func _flip(p: Vector3) -> Vector3:
	return Vector3(-p.x,p.y,p.z)

## The rise's settings: RISE with any given in opts.
static func settings(opts := {}) -> Dictionary:
	var out := RISE.duplicate()
	for key: String in RISE:
		if opts.has(key): out[key] = float(opts[key])
	out.speed = maxf(0.5,float(out.speed))
	out.ease_in = maxf(0.0,float(out.ease_in))
	out.ease_out = maxf(0.0,float(out.ease_out))
	out.over = maxf(0.0,float(out.over))
	out.settle = maxf(0.0,float(out.settle))
	out.gap = maxf(0.0,float(out.gap))
	out.lead = maxf(0.0,float(out.lead))
	out.under = maxf(0.0,float(out.under))
	return out

## What every solid of the hall is: [{bay, half, kind ("floor", "column",
## "span", "wall", "roof")}], in `Plan.local_solids` order.
static func classify() -> Array:
	var s: Dictionary = Plan.stations()[LAYOUT]
	var out := []
	var bay := 0
	var half := 0
	for part: Array in s.parts:
		if str(part[0]) != "bay": continue
		var at: Vector3 = part[1]
		var yaw := float(part[2])
		var plan: Dictionary = part[3]
		var turn := Basis(Vector3.UP,yaw+PI*0.5)
		for q: Dictionary in Course._bay(at,yaw,plan,false):
			var local: Vector3 = turn.inverse()*((q.middle as Vector3)-at)
			var kind := "span"
			if q.kind == "cyl": kind = "column"
			elif local.y < 0.0: kind = "floor"
			elif absf(absf(local.z)-Hall.WALL_Z) < 0.01 and is_equal_approx((q.size as Vector3).z,Hall.WALL_THICK): kind = "wall"
			elif is_equal_approx((q.size as Vector3).x,Hall.BAY): kind = "roof"
			out.append({"bay":bay,"half":half,"kind":kind})
		if bool(plan.get("last",false)): half += 1
		bay += 1
	return out

static func _group(solids: Array, info: Array, opts: Dictionary) -> Array:
	var chunks := []
	for c: Dictionary in CHUNKS:
		var chunk := {"id":c.id,"title":c.title,"bays":c.bays,"solids":[],"extra":[]}
		for k in range(info.size()):
			var b := int(info[k].bay)
			if b >= int(c.bays[0]) and b <= int(c.bays[1]): chunk.solids.append(k)
		chunks.append(chunk)
	if opts.get("keels",false):
		# Each keel goes with its bay's chunk.
		for half in range(2):
			var floors := []
			for k in range(info.size()):
				if info[k].half == half and info[k].kind == "floor": floors.append(k)
			var made := keels(solids,info,half)
			for n in range(made.size()):
				var b := int(info[floors[n]].bay)
				for chunk: Dictionary in chunks:
					if b >= int(chunk.bays[0]) and b <= int(chunk.bays[1]): chunk.extra.append(made[n])
	if str(opts.get("from","apse")) == "apse": chunks.reverse()
	if opts.get("stones",false):
		chunks.append({"id":"stones","title":"the floating stones","bays":[-1,-1],"solids":[],"extra":stones(solids)})
	for chunk: Dictionary in chunks: _shape(chunk,solids,info)
	return chunks

## A chunk's box, middle, solids' boxes and rim.
static func _shape(chunk: Dictionary, solids: Array, info: Array) -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var boxes := []
	var all := []
	for k: int in chunk.solids: all.append(solids[k])
	all.append_array(chunk.extra)
	for q: Dictionary in all:
		var a := Vector3.INF
		var b := -Vector3.INF
		if q.kind == "hull":
			for v: Vector3 in q.points:
				a = a.min(v)
				b = b.max(v)
		else:
			var e := Plan.extent(q)
			a = (q.middle as Vector3)-e
			b = (q.middle as Vector3)+e
		boxes.append(AABB(a,b-a))
		lo = lo.min(a)
		hi = hi.max(b)
	chunk.lo = lo
	chunk.hi = hi
	chunk.pivot = (lo+hi)*0.5
	chunk.boxes = boxes
	chunk.top = hi.y-(lo.y+hi.y)*0.5
	# The rim: round each floor's top face (or each stone), every RIM_STEP.
	var rim := PackedVector3Array()
	for k: int in chunk.solids:
		if info[k].kind != "floor": continue
		var q: Dictionary = solids[k]
		var h: Vector3 = (q.size as Vector3)*0.5
		var corners := []
		for c: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			corners.append((q.middle as Vector3)+(q.basis as Basis)*Vector3(c.x*h.x,h.y,c.y*h.z))
		for n in range(4):
			var a: Vector3 = corners[n]
			var b: Vector3 = corners[(n+1)%4]
			var steps := maxi(1,int(ceil(a.distance_to(b)/RIM_STEP)))
			for s in range(steps): rim.append(a.lerp(b,float(s)/float(steps)))
	for q: Dictionary in chunk.extra:
		if q.get("stone",false): rim.append(q.middle)
	if rim.is_empty(): rim.append(chunk.pivot)
	chunk.rim = rim

## Each chunk's start and motion. One after another, `gap` apart, after
## `lead`; each starts with its top `under` under the cloud top (`sea`).
static func schedule(chunks: Array, opts := {}) -> void:
	var r := settings(opts)
	var sea := float(opts.get("sea",SEA))
	var t := float(r.lead)
	for c: Dictionary in chunks:
		for key: String in ["speed","ease_in","ease_out","over","settle"]: c[key] = r[key]
		c.from_y = minf(sea-float(r.under)-float(c.top),(c.pivot as Vector3).y-1.0)
		var climb := (c.pivot as Vector3).y+float(c.over)-float(c.from_y)
		# Shorter than its ease in and out: both shrink to fit.
		var e_in := float(c.ease_in)
		var e_out := float(c.ease_out)
		if e_in+e_out > climb:
			var k := climb/maxf(e_in+e_out,1e-6)
			e_in *= k
			e_out *= k
		c.ease_in = e_in
		c.ease_out = e_out
		var v := float(c.speed)
		c.t_in = 2.0*e_in/v
		c.t_out = 2.0*e_out/v
		c.t_run = (climb-e_in-e_out)/v
		c.start = t
		t += float(r.gap)

## When a chunk has come to a stop over its place (s from the start).
static func stops(c: Dictionary) -> float:
	return float(c.start)+float(c.t_in)+float(c.t_run)+float(c.t_out)

## When it is still in its place (s).
static func settles(c: Dictionary) -> float:
	return stops(c)+(float(c.settle) if float(c.over) > 0.0 else 0.0)

## The whole rise's length (s): the last chunk settled.
static func length(chunks: Array) -> float:
	var out := 0.0
	for c: Dictionary in chunks: out = maxf(out,settles(c))
	return out

## How high (m) chunk `c`'s pivot is `t` s after it began: getting up to
## speed under the cloud, steady through it, easing to a stop `over` over
## its place, then sinking into it. Exactly its place from the end on.
static func height_at(c: Dictionary, t: float) -> float:
	var home := (c.pivot as Vector3).y
	var y0 := float(c.from_y)
	var v := float(c.speed)
	var t_in := float(c.t_in)
	var t_run := float(c.t_run)
	var t_out := float(c.t_out)
	var over := float(c.over)
	if t <= 0.0: return y0
	if t < t_in: return y0+0.5*v/t_in*t*t
	var y := y0+float(c.ease_in)
	if t < t_in+t_run: return y+v*(t-t_in)
	y += v*t_run
	if t < t_in+t_run+t_out:
		var s := t-t_in-t_run
		return y+v*s-0.5*v/t_out*s*s
	if over <= 0.0: return home
	var u := (t-t_in-t_run-t_out)/maxf(float(c.settle),1e-6)
	if u >= 1.0: return home
	return home+over*(1.0-smoothstep(0.0,1.0,u))

## How fast (m/s, up) it is rising `t` s after it began.
static func speed_at(c: Dictionary, t: float) -> float:
	var v := float(c.speed)
	var t_in := float(c.t_in)
	var t_run := float(c.t_run)
	var t_out := float(c.t_out)
	if t <= 0.0: return 0.0
	if t < t_in: return v*t/t_in
	if t < t_in+t_run: return v
	if t < t_in+t_run+t_out: return v*(1.0-(t-t_in-t_run)/t_out)
	return 0.0

# --- Additions round the hall (off by default) ---------------------------------------

## The rock keel under half `half`'s floor: a faceted frustum under each
## bay's floor, deepest at the half's middle, drawn in at the bottom, the
## end bays drawn in at their outer ends so the gap stays open sky. Each a
## {"kind":"hull","points"}, one per floor in bay order.
static func keels(solids: Array, info: Array, half: int) -> Array:
	var bays := []
	for k in range(info.size()):
		var i: Dictionary = info[k]
		if i.half == half and i.kind == "floor": bays.append([k,i])
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242+half
	for n in range(bays.size()):
		var k: int = bays[n][0]
		var q: Dictionary = solids[k]
		var b: Basis = q.basis
		var h: Vector3 = (q.size as Vector3)*0.5
		var top := (q.middle as Vector3).y-h.y
		var u := (float(n)+0.5)/float(bays.size())
		var deep := lerpf(KEEL_DEEP.y,KEEL_DEEP.x,sin(u*PI))+rng.randf_range(-KEEL_JITTER,KEEL_JITTER)
		var mid: Vector3 = q.middle
		# The bay's own frame: x along the nave, z across.
		var ax := b.x
		var az := b.z
		var long := h.x+0.3
		var wide := h.z-0.4
		var pull_back := 0.0
		var pull_front := 0.0
		if n == 0: pull_back = 1.0
		if n == bays.size()-1: pull_front = 1.0
		var pts := PackedVector3Array()
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var lx := long-(pull_back if sx < 0.0 else pull_front)*0.8
				pts.append(Vector3(mid.x,top-0.02,mid.z)+ax*sx*lx+az*sz*wide)
		var drift := ax*rng.randf_range(-1.5,1.5)+az*rng.randf_range(-2.0,2.0)
		var taper := KEEL_TAPER+rng.randf_range(-0.08,0.08)
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var lx := long*taper*(0.55 if (sx < 0.0 and pull_back > 0.0) or (sx > 0.0 and pull_front > 0.0) else 1.0)
				var d := deep*(0.85+0.15*rng.randf())
				pts.append(Vector3(mid.x,top-d,mid.z)+ax*sx*lx+az*sz*wide*taper+drift)
		# A shoulder ring half way down, pushed out a little: facets.
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var lx := long*(0.8+rng.randf()*0.1)-(pull_back if sx < 0.0 else pull_front)*2.0
				pts.append(Vector3(mid.x,top-deep*0.38,mid.z)+ax*sx*lx+az*sz*wide*(0.8+rng.randf()*0.12)+drift*0.4)
		out.append({"kind":"hull","points":pts,"keel":true})
	return out

## A few floating stones round the hall, beside its walls and down in the
## gap, each a turned box, every one STONE_KEEP clear of the line (and its
## way in) and of every moment, and clear of the hall's stone.
static func stones(solids: Array) -> Array:
	var keep := keep_points()
	var rng := RandomNumberGenerator.new()
	rng.seed = STONE_SEED
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for q: Dictionary in solids:
		var e := Plan.extent(q)
		lo = lo.min((q.middle as Vector3)-e)
		hi = hi.max((q.middle as Vector3)+e)
	var out := []
	var tries := 0
	while out.size() < STONES and tries < 4000:
		tries += 1
		var bay := rng.randi_range(0,14)
		var at := bay_at(bay)
		var yaw := float(_bay_part(bay)[2])
		var turn := Basis(Vector3.UP,yaw+PI*0.5)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var c := Vector3(rng.randf_range(0.0,Hall.BAY),rng.randf_range(-14.0,7.0),side*(HALF_W+rng.randf_range(5.0,16.0)))
		if out.size() >= STONES-2:
			# Two down in the gap, well under the line.
			at = (bay_at(8)+bay_at(9))*0.5
			turn = Basis.IDENTITY
			c = Vector3(rng.randf_range(-12.0,12.0),rng.randf_range(-26.0,-17.0),rng.randf_range(-8.0,8.0))
		var middle: Vector3 = at+turn*c
		var size := Vector3(rng.randf_range(STONE_SIZE.x,STONE_SIZE.y),rng.randf_range(STONE_SIZE.x,STONE_SIZE.y)*0.7,rng.randf_range(STONE_SIZE.x,STONE_SIZE.y))
		var r := size.length()*0.5
		var ok := true
		for p: Vector3 in keep:
			if p.distance_to(middle) < r+STONE_KEEP:
				ok = false
				break
		for q: Dictionary in out:
			if (q.middle as Vector3).distance_to(middle) < r+(q.size as Vector3).length()*0.5+3.0: ok = false
		var inside := middle.x > lo.x-r and middle.x < hi.x+r and middle.z > lo.z-r and middle.z < hi.z+r and middle.y > lo.y-r and middle.y < hi.y+r
		if inside:
			for q: Dictionary in solids:
				if Course.distance(q,middle) < r+1.0: ok = false
		if not ok: continue
		var basis := Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-0.5,0.5))*Basis(Vector3.BACK,rng.randf_range(-0.5,0.5))
		out.append({"kind":"box","middle":middle,"size":size,"basis":basis.orthonormalized(),"stone":true})
	return out

## Bay `bay`'s floor-line point (station metres).
static func bay_at(bay: int) -> Vector3:
	var part := _bay_part(bay)
	return part[1] if not part.is_empty() else Vector3.ZERO

static func _bay_part(bay: int) -> Array:
	var s: Dictionary = Plan.stations()[LAYOUT]
	var k := 0
	for part: Array in s.parts:
		if str(part[0]) != "bay": continue
		if k == bay: return part
		k += 1
	return []

## The points the additions keep clear of (station metres): the line every
## metre, its way in (the starter, the leads) and its way out, and every
## moment.
static func keep_points() -> Array[Vector3]:
	var line := Plan.line(LAYOUT)
	var way: Array[Vector3] = [Vector3(0.0,0.0,float(Plan.LEADS[-1])+20.0),Vector3(0.0,0.0,0.0)]
	way.append_array(line)
	var last: Vector3 = line[-1]
	var before: Vector3 = line[-2]
	way.append(last+(last-before).normalized()*40.0)
	var out: Array[Vector3] = []
	for i in range(way.size()-1):
		var a: Vector3 = way[i]
		var b: Vector3 = way[i+1]
		var n := maxi(1,int(ceil(a.distance_to(b))))
		for k in range(n): out.append(a.lerp(b,float(k)/float(n)))
	out.append(way[-1])
	for m: Dictionary in Plan.moments(LAYOUT): out.append(m.at)
	return out
