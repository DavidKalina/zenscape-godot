extends RefCounted
## The landing study's islands (studies/landing_study.gd): greybox fields of
## rising difficulty, each flown into by hand under the manual landing's
## rules (scripts/manual_landing.gd). Plain data and maths, so the bench
## (tools/landing_bench.gd) and the tests read the same ground.
##
## Each station is {id, key, name, note, pads, touch, length, width, wind,
## gust, start}, in local metres: the field's near edge is at local z 0 and
## it runs north (-Z) for `length` m, `width` m wide; the plane starts
## START_OUT m south of it, START_UP m over it, flying north at cruise.
## `touch` (local) is where a careful pilot would set the wheels down.
## A pad is a solid of land: a `rect` (Rect2 over x, z) or a `circle`
## (Vector3 x, z, radius), its top at `y` plus `slope` (Vector2: metres up
## per metre of x and of z), `depth` m of rock under it. Stations stand
## SPACING m apart along x; the sea lies at SEA_Y under them all.
##
##   1 long_field   a long wide field, flat: room for anything
##   2 short_ledge  a short field ending at a ledge, a lower shelf beyond it
##   3 slope_field  a field rising 1 in 7 away from the approach
##   4 islet        a round islet 18 m across
##   5 crosswind    a narrow strip with a gusting wind across it

const SPACING := 500.0
const SEA_Y := -60.0
## The plane's start: how far south of the near edge and how high over the
## field (m).
const START_OUT := 170.0
const START_UP := 24.0

const STATIONS: Array[Dictionary] = [
	{"id":"long_field","key":1,"name":"Long field","note":"90 m by 24, flat. Room to float, bounce and settle again.",
		"pads":[{"rect":Rect2(-12.0,-90.0,24.0,90.0),"y":0.0,"depth":14.0}],
		"touch":Vector3(0.0,0.0,-12.0),"length":90.0,"width":24.0},
	{"id":"short_ledge","key":2,"name":"Short field, ledge","note":"30 m long, ending at a ledge; a lower shelf 22 m down beyond it.",
		"pads":[{"rect":Rect2(-9.0,-30.0,18.0,30.0),"y":0.0,"depth":12.0},
			{"rect":Rect2(-14.0,-85.0,28.0,38.0),"y":-22.0,"depth":10.0}],
		"touch":Vector3(0.0,0.0,-4.0),"length":30.0,"width":18.0},
	{"id":"slope_field","key":3,"name":"Sloped field","note":"50 m long, rising 1 in 7 away from you: it comes up to meet the wheels.",
		"pads":[{"rect":Rect2(-10.0,-50.0,20.0,50.0),"y":0.0,"slope":Vector2(0.0,-0.14),"depth":12.0}],
		"touch":Vector3(0.0,0.84,-6.0),"length":50.0,"width":20.0},
	{"id":"islet","key":4,"name":"Small islet","note":"A round islet 18 m across. Slow, flaps, brakes.",
		"pads":[{"circle":Vector3(0.0,-9.0,9.0),"y":0.0,"depth":9.0}],
		"touch":Vector3(0.0,0.0,-3.0),"length":18.0,"width":18.0},
	{"id":"crosswind","key":5,"name":"Crosswind strip","note":"60 m by 10, the wind across it from the west, gusting.",
		"pads":[{"rect":Rect2(-5.0,-60.0,10.0,60.0),"y":0.0,"depth":12.0}],
		"touch":Vector3(0.0,0.0,-10.0),"length":60.0,"width":10.0,
		"wind":Vector3(2.5,0.0,0.0),"gust":1.0,"gust_hz":0.23},
]

static func station(id: String) -> Dictionary:
	for s: Dictionary in STATIONS:
		if s.id == id: return s
	return {}

static func station_by_key(key: int) -> Dictionary:
	for s: Dictionary in STATIONS:
		if int(s.key) == key: return s
	return {}

static func index_of(s: Dictionary) -> int:
	for i in range(STATIONS.size()):
		if STATIONS[i].id == s.get("id",""): return i
	return 0

## The station's origin (global): its field's near edge, on the middle line.
static func origin(s: Dictionary) -> Vector3:
	return Vector3(index_of(s)*SPACING,0.0,0.0)

## Where the plane starts (global) and its heading (north).
static func start_at(s: Dictionary) -> Vector3:
	return origin(s)+Vector3(0.0,START_UP,START_OUT)

## The touch spot (global) and the field's way (level, north).
static func touch_at(s: Dictionary) -> Vector3:
	return origin(s)+(s.touch as Vector3)

static func way() -> Vector2:
	return Vector2(0.0,-1.0)

## A pad's top at local `p`, or NAN off it.
static func pad_top(pad: Dictionary, p: Vector2) -> float:
	if pad.has("rect"):
		if not (pad.rect as Rect2).has_point(p): return NAN
	else:
		var c: Vector3 = pad.circle
		if Vector2(c.x,c.y).distance_to(p) > c.z: return NAN
	var slope: Vector2 = pad.get("slope",Vector2.ZERO)
	var base := Vector2.ZERO
	if pad.has("rect"): base = Vector2((pad.rect as Rect2).position.x+(pad.rect as Rect2).size.x*0.5,(pad.rect as Rect2).end.y)
	return float(pad.y)+slope.x*(p.x-base.x)+slope.y*(p.y-base.y)

## The land's height under a global XZ point (the wheels' ground), or NAN
## off every field; where pads overlap, the highest.
static func floor_at(p: Vector2) -> float:
	var best := NAN
	for s: Dictionary in STATIONS:
		var o := origin(s)
		var local := Vector2(p.x-o.x,p.y-o.z)
		if absf(local.x) > 200.0: continue
		for pad: Dictionary in s.pads:
			var top := pad_top(pad,local)
			if not is_nan(top) and (is_nan(best) or top > best): best = top
	return best

## The flight's solids (SkyGlide `step`'s ground): Vector2(top, underside)
## of the land under a global point, or null over open air. The pad whose
## top is the nearest at or under the point (or, under every pad, the
## lowest) is the one that counts, so a plane can fly beneath a field to the
## shelf under it.
static func ground(point: Vector3) -> Variant:
	var best: Variant = null
	for s: Dictionary in STATIONS:
		var o := origin(s)
		var local := Vector2(point.x-o.x,point.z-o.z)
		if absf(local.x) > 200.0: continue
		for pad: Dictionary in s.pads:
			var top := pad_top(pad,local)
			if is_nan(top): continue
			var body := Vector2(top,_underside(pad))
			if best == null: best = body
			elif point.y >= body.y and (point.y < (best as Vector2).y or body.x > (best as Vector2).x): best = body
	return best

## A pad's underside (its lowest rock).
static func _underside(pad: Dictionary) -> float:
	var slope: Vector2 = pad.get("slope",Vector2.ZERO)
	var reach := 0.0
	if pad.has("rect"): reach = absf(slope.x)*(pad.rect as Rect2).size.x+absf(slope.y)*(pad.rect as Rect2).size.y
	return float(pad.y)-float(pad.depth)-reach

## The air: the crosswind station's wind, gusting, near it (within 220 m);
## still air elsewhere. As SkyCurrents `air_at` (only `wind`).
static func air_at(point: Vector3, t: float) -> Dictionary:
	for s: Dictionary in STATIONS:
		if not s.has("wind"): continue
		var o := origin(s)
		if Vector2(point.x-o.x,point.z-o.z).length() > 220.0: continue
		var gust := float(s.get("gust",0.0))*sin(TAU*float(s.get("gust_hz",0.2))*t)
		var w: Vector3 = s.wind
		return {"wind":w+w.normalized()*gust}
	return {}

## The station whose area the global point is in (nearest origin).
static func station_near(point: Vector3) -> Dictionary:
	var i := clampi(roundi(point.x/SPACING),0,STATIONS.size()-1)
	return STATIONS[i]

## Builds the station's pads as greybox solids under `parent`, with
## `material` a Callable(String) -> Material.
static func build(s: Dictionary, parent: Node3D, material: Callable) -> Node3D:
	var node := Node3D.new()
	node.name = "Station_%s" % s.id
	node.position = origin(s)
	parent.add_child(node)
	for i in range(s.pads.size()):
		var pad: Dictionary = s.pads[i]
		var mesh := MeshInstance3D.new()
		mesh.mesh = pad_mesh(pad)
		mesh.material_override = material.call("field" if i == 0 else "shelf")
		node.add_child(mesh)
	return node

## A pad as a prism: its top (sloped as it is), its sides down to its
## underside.
static func pad_mesh(pad: Dictionary) -> ArrayMesh:
	var ring := PackedVector2Array()
	if pad.has("rect"):
		var r: Rect2 = pad.rect
		ring = PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	else:
		var c: Vector3 = pad.circle
		for k in range(24): ring.append(Vector2(c.x,c.y)+Vector2.from_angle(TAU*k/24.0)*c.z*0.999)
	var bottom := _underside(pad)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector2.ZERO
	for p in ring: centre += p
	centre /= ring.size()
	var top := func(p: Vector2) -> Vector3: return Vector3(p.x,pad_top(pad,p.lerp(centre,0.0005)),p.y)
	for k in range(ring.size()):
		var a := ring[k]
		var b := ring[(k+1)%ring.size()]
		# The top, a fan from the middle.
		st.add_vertex(top.call(centre))
		st.add_vertex(top.call(a))
		st.add_vertex(top.call(b))
		# The side, down to the underside.
		var ta: Vector3 = top.call(a)
		var tb: Vector3 = top.call(b)
		st.add_vertex(ta)
		st.add_vertex(Vector3(b.x,bottom,b.y))
		st.add_vertex(tb)
		st.add_vertex(ta)
		st.add_vertex(Vector3(a.x,bottom,a.y))
		st.add_vertex(Vector3(b.x,bottom,b.y))
	st.generate_normals()
	return st.commit()
