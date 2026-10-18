extends RefCounted
## What tools/bake_layer_pieces.gd read off the built isles (data/layer/
## pieces.json; scripts/roguelike/isle_probe.gd): per isle its occupancy
## (a grid of its lowest and highest solid) and, for the motifs that are not
## families yet and the aqueduct isle, its rims and clear spots. Loaded
## once. A sockets-only motif answers the family contract's `sockets`,
## `footprint` and `height_span` from here (scripts/kit_isle/kit_motif.gd
## `baked_*`); scripts/roguelike/layer_plan.gd reads the occupancy of an
## isle it makes and the aqueduct isle's rims.
const PATH := "res://data/layer/pieces.json"
## A spot this roomy is an arena (an on-isle trap or enemy); every spot is
## a perch.
const ARENA_ROOM := 4.0

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		_data = parsed if parsed is Dictionary else {}
		if _data.is_empty(): push_error("layer pieces: %s missing or unreadable (run tools/bake_layer_pieces.gd)" % PATH)
	return _data

static func has(id: String) -> bool:
	return data().has(id)

## Its sockets (its own frame), as KitMotif `socket` dictionaries: its rims
## (each with its `lip`, how far ahead its lip is), its clear spots as
## perches, the roomy ones arenas too.
static func sockets(id: String) -> Array:
	var entry: Dictionary = data().get(id,{})
	var out: Array = []
	for r: Dictionary in entry.get("rims",[]):
		var at := _v3(r.at)
		var face := Vector3(float(r.face[0]),0.0,float(r.face[1])).normalized()
		out.append({"kind":"rim","name":str(r.name),"at":at,"face":face,"room":float(r.lip),"run_up":float(r.run_up),"lip":float(r.lip)})
	var k := 0
	for s: Dictionary in entry.get("spots",[]):
		var at := _v3(s.at)
		var room := float(s.room)
		if room >= ARENA_ROOM: out.append({"kind":"arena","name":"a%d" % k,"at":at,"face":Vector3.FORWARD,"room":room,"run_up":0.0})
		out.append({"kind":"perch","name":"p%d" % k,"at":at,"face":Vector3.FORWARD,"room":room,"run_up":0.0})
		k += 1
	return out

## Its occupancy: {origin (Vector2), cell, cols, rows, lo, hi (Arrays)}.
static func occupancy(id: String) -> Dictionary:
	var entry: Dictionary = data().get(id,{})
	if not entry.has("occupancy"): return {}
	var o: Dictionary = entry.occupancy
	if not o.has("_ready"):
		o.origin = _v2(o.origin)
		var lo := PackedFloat32Array()
		var hi := PackedFloat32Array()
		for v: Variant in o.lo: lo.append(INF if v == null else float(v))
		for v: Variant in o.hi: hi.append(-INF if v == null else float(v))
		o.lo = lo
		o.hi = hi
		o._ready = true
	return o

## Its rect (x, z) where anything stands, and its lowest and highest solid.
static func footprint(id: String) -> Rect2:
	var o := occupancy(id)
	if o.is_empty(): return Rect2()
	var box := Rect2()
	var first := true
	var cols: int = o.cols
	for k in range((o.lo as PackedFloat32Array).size()):
		if (o.lo as PackedFloat32Array)[k] == INF: continue
		var cell := Rect2((o.origin as Vector2)+Vector2(k%cols,k/cols)*float(o.cell),Vector2.ONE*float(o.cell))
		box = cell if first else box.merge(cell)
		first = false
	return box

static func height_span(id: String) -> Vector2:
	var o := occupancy(id)
	var span := Vector2(INF,-INF)
	for v: float in o.get("lo",[]): span.x = minf(span.x,v)
	for v: float in o.get("hi",[]): span.y = maxf(span.y,v)
	return span

static func start(id: String) -> Vector3:
	var entry: Dictionary = data().get(id,{})
	return _v3(entry.start) if entry.has("start") else Vector3.INF

static func _v3(a: Variant) -> Vector3:
	if a is String: a = JSON.parse_string("[%s]" % (a as String).trim_prefix("(").trim_suffix(")"))
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func _v2(a: Variant) -> Vector2:
	if a is String:
		var parts := (a as String).trim_prefix("(").trim_suffix(")").split(",")
		return Vector2(float(parts[0]),float(parts[1]))
	return Vector2(float(a[0]),float(a[1]))
