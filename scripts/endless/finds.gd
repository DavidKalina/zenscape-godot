extends Node
## The finds at work (lane `finds`, spec-wilderness-demo.md): the table
## (finds_table.gd) resolved to places, streamed by distance, flown through or
## landed by, and kept in the pilot's book as `find/<world>/<id>`.
##
## Streaming stays cheap however long the table gets: rows sit in a coarse grid
## (CELL m), the grid is read only when the plane enters another cell, and only
## the nearest MAX_LIVE within REACH m have a node (find_marks.gd, pooled). Each
## frame walks those few. No C++ twin: nothing here scales with the table.
##
## Main-scene hooks: `setup(game)` late in _ready, `step(delta, game)` in tick
## after the tallies have run. --finds=0: none.

const Table = preload("res://scripts/endless/finds_table.gd")
const Marks = preload("res://scripts/endless/find_marks.gd")
const Hud = preload("res://scripts/endless/finds_hud.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const LandArches = preload("res://scripts/endless/land_arches.gd")
const RockPlan = preload("res://scripts/endless/rocks/rock_plan.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PeakCarve = preload("res://scripts/endless/peak_carve.gd")

signal found_one(entry: Dictionary)

## A row's grid (m), how far off a node stands, and how many stand at once.
const CELL := 300.0
const REACH := 2000.0
const MAX_LIVE := 16
## Reach of a ring: as wide as its stones, so a pass that clips them counts.
const TOY_RING := 5.0
const CAPTURE_OVER := 1.8
## How often (s) the book's events are read and missing anchors retried.
const POLL := 0.4
const RETRY := 2.0
const LAND_RADIUS := 45.0

## The rows, resolved: the table's own keys plus {world, book_id, at
## (Vector3.INF none yet), moves (a handle: re-read while near)}.
var rows: Array = []
## The worlds with rows, and the one the plane is in.
var world := "wilderness"
var _grid := {}
var _by_event := {}
var _pending: Array = []
var _polled: Array = []
var _extra_anchors := {}
var _cell := Vector2i(1 << 30,0)
## Row index -> its node.
var _live := {}
var _pool: Array = []
var _prev := Vector3.INF
## The wheels at rest last frame (true at first: the start is no landing).
var _stopped := true
var _poll := 0.0
var _retry := 0.0
var _game: Node
var _field: RefCounted
var _sides: Array = ["wilderness","amberlands"]
var hud: Hud
var beat: Marks.Beat
var stream_reads := 0

static func wanted(seed: int) -> bool:
	return seed == Table.SEED and not "--finds=0" in LaunchArgs.user_args()

## The anchor of the relic deep in the door's hall (HallDoors `deep`).
const HALL_ANCHOR := "doors/amber-hall/deep"

## A flown ring's opening (m).
static func ring_opening() -> float:
	return WorldScale.opening(TOY_RING)

static func capture() -> float:
	return ring_opening()*0.5*CAPTURE_OVER

## The row's id in the book.
static func book_id(world_id: String, id: String) -> String:
	return "find/%s/%s" % [world_id,id]

func setup(game: Node) -> void:
	name = "Finds"
	_game = game
	_field = game.field
	beat = Marks.Beat.new()
	add_child(beat)
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	hud = Hud.new()
	hud.setup(game,self)
	layer.add_child(hud)
	for world_id: String in Table.WORLDS:
		for r: Dictionary in Table.WORLDS[world_id]: _add(world_id,r)
	_resolve()
	_stream(game.plane.position,true)
	var missing: int = _pending.size()
	print("finds: %d in the table, %d found, %d anchors waiting" % [rows.size(),got(),missing])

func _add(world_id: String, r: Dictionary) -> void:
	var e := r.duplicate()
	e["world"] = world_id
	e["book_id"] = book_id(world_id,str(r.id))
	e["spot"] = r.get("at",Vector3.INF)
	e["at"] = Vector3.INF
	e["moves"] = false
	if not e.has("title"): e["title"] = str(r.id).replace("-"," ").capitalize()
	var i := rows.size()
	rows.append(e)
	var kind := str(e.kind)
	if kind == "event" and e.has("event"): _by_event[str(e.event)] = i
	if e.has("book") or kind == "line": _polled.append(i)
	if kind == "line": _line(e)
	if kind in ["relic","landing"] or e.spot != Vector3.INF or e.has("anchor"): _pending.append(i)

func _line(e: Dictionary) -> void:
	if e.has("gates") and _game.lines != null: _game.lines.add_line({"name":e.name,"place":e.place,"title":e.title,"gates":e.gates,"mark":e.get("mark",-1.0)})
	if e.has("gates"):
		e["line"] = "line/%s/%s" % [e.place,e.name]
		var g: Variant = (e.gates as Array)[0]
		e["spot"] = g if g is Vector3 else (g as Dictionary).at

# --- Anchors ----------------------------------------------------------------------------

## A place for `anchor` names in rows (the lanes' way in, besides a handle).
func anchor(anchor_name: String, at: Vector3) -> void:
	_extra_anchors[anchor_name] = at
	_retry = 0.0

## Each row still without a spot gets one if it can; those that have one go in
## the grid.
func _resolve() -> void:
	var still: Array = []
	for i: int in _pending:
		var e: Dictionary = rows[i]
		var p := _spot(e)
		if p == Vector3.INF:
			still.append(i)
			continue
		var id := "finds/"+str(e.id)
		e.at = LayoutOverrides.xform(id,Transform3D(Basis.IDENTITY,p)).origin
		var c := _cell_of(e.at)
		if not _grid.has(c): _grid[c] = []
		_grid[c].append(i)
		_cell = Vector2i(1 << 30,0)
	_pending = still

func _spot(e: Dictionary) -> Vector3:
	var kind := str(e.kind)
	var up := float(e.get("up",Table.HOVER if kind == "relic" else 0.0))
	var off: Vector3 = e.get("offset",Vector3.ZERO)
	var at: Variant = e.spot
	if at is Vector2:
		var v: Vector2 = at
		return Vector3(v.x,_ground(v.x,v.y)+up,v.y)+off
	if at is Vector3 and at != Vector3.INF: return (at as Vector3)+off
	if not e.has("anchor"): return Vector3.INF
	var p := anchor_spot(str(e.anchor),e)
	return p+Vector3.UP*up+off if p != Vector3.INF else Vector3.INF

func _ground(x: float, z: float) -> float:
	return maxf(float(_field.height(x,z)),Field.SEA_Y)

## Where a named anchor stands (see finds_table.gd), or Vector3.INF for now.
func anchor_spot(a: String, e: Dictionary = {}) -> Vector3:
	if _extra_anchors.has(a): return _extra_anchors[a]
	var parts := a.split("/")
	if a.begins_with("peak/"): return _peak(parts)
	if LayoutOverrides.entries.has(a):
		if not e.is_empty(): e.moves = true
		var node: Node3D = LayoutOverrides.entries[a].node
		return node.global_position if node.is_inside_tree() else node.position
	if a.begins_with("chamber/"): return _chamber("cracked/"+a.trim_prefix("chamber/"))
	if a == HALL_ANCHOR: return _game.doors.deep() if _game.doors != null and _game.doors.has_method("deep") else Vector3.INF
	if a.begins_with("endless/arch/") and parts.size() == 4: return _arch(parts)
	if a.begins_with("endless/rock/") and parts.size() == 5: return _rock(parts,e)
	if a.begins_with("endless/split/") and parts.size() == 3: return _split(parts[2])
	if a.begins_with("pond/") and parts.size() == 2:
		var xz := parts[1].split("_")
		var s: Array = _field.ponds_in(float(xz[0])-2.0,float(xz[1])-2.0,float(xz[0])+2.0,float(xz[1])+2.0)
		if not s.is_empty(): return Vector3(s[0][0],s[0][3],s[0][1])
	return Vector3.INF

func _arch(parts: PackedStringArray) -> Vector3:
	var c := parts[2].split("_")
	var fl: Dictionary = LandArches.flags()
	var want := "/".join(parts)
	for spec: Dictionary in ArchPlan.plan(_field,int(c[0]),int(c[1]),float(fl.density),float(fl.rock),float(fl.ruin)):
		if str(spec.name) == want: return spec.pos
	return Vector3.INF

func _rock(parts: PackedStringArray, e: Dictionary) -> Vector3:
	var c := parts[3].split("_")
	var want := "/".join(parts)
	for spec: Dictionary in RockPlan.plan(_field,int(c[0]),int(c[1]),RockPlan.flags()):
		if str(spec.name) != want: continue
		if not e.has("pillar"): return spec.pos
		var pillar: Dictionary = (spec.pillars as Array)[int(e.pillar)]
		var rings: Array = pillar.profile
		return (spec.pos as Vector3)+(pillar.at as Vector3)+Vector3.UP*float((rings[rings.size()-1] as Array)[0])
	return Vector3.INF

## The room behind a cracked wall (CrackedWalls `chamber_at`).
func _chamber(handle: String) -> Vector3:
	var smash: Variant = _game.get("smash")
	if smash == null or not (smash.walls.sites as Dictionary).has(handle): return Vector3.INF
	return smash.walls.chamber_at(handle)

func _split(key: String) -> Vector3:
	const SPLIT_CELL := 1536.0
	var c := key.split("_")
	var x := float(c[0])*SPLIT_CELL
	var z := float(c[1])*SPLIT_CELL
	for s: PackedFloat32Array in _field.splits_in(x,z,x+SPLIT_CELL,z+SPLIT_CELL):
		if floori(s[0]/SPLIT_CELL) == int(c[0]) and floori(s[1]/SPLIT_CELL) == int(c[1]): return Vector3(s[0],_ground(s[0],s[1]),s[1])
	return Vector3.INF

func _peak(parts: PackedStringArray) -> Vector3:
	var pk: RefCounted = _field.peak() if _field.has_method("peak") else null
	if pk == null: return Vector3.INF
	var t: Dictionary = pk.tarn()
	match parts[1]:
		"summit": return pk.summit()
		"tarn": return t.centre
		"plateau":
			var v: Vector2 = t.plateau
			return Vector3(v.x,_ground(v.x,v.y),v.y)
		"strip":
			if parts[2] == "mid": return ((t.strip as Array)[0]+(t.strip as Array)[1])*0.5
			return (t.strip as Array)[int(parts[2])]
		"tower":
			var bases: Array = pk.tower_bases()
			if int(parts[2]) < bases.size(): return bases[int(parts[2])]
		"hole": return _hole(pk,PeakCarve.HOLES[int(parts[2])],0)
		"sill": return _hole(pk,PeakCarve.SILL_HOLES[int(parts[2])],1)
	return Vector3.INF

## The middle of a hole in the Dike or a Sill: `h` its PeakCarve row, `from` where
## its [a, v, y over the sea] start.
func _hole(pk: RefCounted, h: Array, from: int) -> Vector3:
	var at: Vector2 = pk.world(float(h[from]),float(h[from+1]))
	return Vector3(at.x,float(h[from+2])+Field.SEA_Y,at.y)

# --- The score --------------------------------------------------------------------------

func is_found(e: Dictionary) -> bool:
	return _game.book.found.has(e.book_id)

## How many of `world_id`'s rows are found ("" the plane's world).
func got(world_id := "") -> int:
	var w := world_id if world_id != "" else world
	var n := 0
	for e: Dictionary in rows:
		if e.world == w and is_found(e): n += 1
	return n

func of(world_id := "") -> int:
	var w := world_id if world_id != "" else world
	var n := 0
	for e: Dictionary in rows:
		if e.world == w: n += 1
	return n

## Rows as the site map wants them: {id, kind, area, at}, placed ones only.
func entries() -> Array:
	var out: Array = []
	for e: Dictionary in rows:
		if e.at != Vector3.INF: out.append({"id":str(e.id),"kind":str(e.kind),"area":str(e.area),"at":e.at})
	return out

## The row with `id` ({} none), for drivers and checks.
func row(id: String) -> Dictionary:
	for e: Dictionary in rows:
		if e.id == id: return e
	return {}

## `signal_` fires the event `event` (and `event/<first argument>`). Any
## signal, any arguments: the contract with what breaks and what's caught.
func listen(signal_: Signal, event: String) -> void:
	signal_.connect(_heard.bind(event))

func _heard(...args: Array) -> void:
	var event := str(args.pop_back())
	if not args.is_empty(): fire("%s/%s" % [event,str(args[0])])
	fire(event)

## The event `event` happened: its row, if any, is found.
func fire(event: String) -> void:
	if _by_event.has(event): complete(int(_by_event[event]))

## Row `i` found. False if it already was.
func complete(i: int) -> bool:
	var game := _game
	var e: Dictionary = rows[i]
	if not game.book.find(e.book_id): return false
	game.book.save()
	var p: Vector3 = e.at if e.at != Vector3.INF else game.plane.position
	beat.play(str(e.kind),p,float(got(str(e.world))))
	hud.found(e,got(str(e.world)),of(str(e.world)))
	if _live.has(i): (_live[i] as Marks.Mark).taken()
	found_one.emit(e)
	print("finds: %s (%d / %d)" % [e.book_id,got(str(e.world)),of(str(e.world))])
	return true

# --- The flight -------------------------------------------------------------------------

func step(delta: float, game: Node) -> void:
	var p: Vector3 = game.plane.position
	world = _world_at(p,game)
	if game.stage != null:
		_prev = Vector3.INF
		return
	_poll -= delta
	_retry -= delta
	if _retry <= 0.0:
		_retry = RETRY
		if not _pending.is_empty(): _resolve()
	if _poll <= 0.0:
		_poll = POLL
		_read_book(game)
	var c := _cell_of(p)
	if c != _cell: _stream(p,false)
	var flying: bool = game.hand_landing.flying()
	var a := _prev
	_prev = p
	if a != Vector3.INF and a.distance_to(p) > 150.0: a = Vector3.INF
	var r := capture()
	var eye: Vector3 = game.camera.global_position
	for i: int in _live.keys():
		var e: Dictionary = rows[i]
		var node: Marks.Mark = _live[i]
		if e.moves:
			e.at = anchor_spot(str(e.anchor))+Vector3.UP*float(e.get("up",0.0 if e.kind == "landing" else Table.HOVER))+(e.get("offset",Vector3.ZERO) as Vector3)
			node.position = e.at
		node.tick(delta,p,eye)
		if e.has("hall"): node.visible = not is_found(e) and game.doors != null and game.doors.holds(e.at)
		if e.kind == "relic" and flying and a != Vector3.INF and not is_found(e) and _segment_near(a,p,e.at,r): complete(i)
	# Any stop counts, a taxi in as well as a landing: wheels at rest inside the
	# stones is what the row asks for, and a rollout can run past them.
	var stopped: bool = game.hand_landing.can_exit()
	if stopped and not _stopped: _landed(game,p)
	_stopped = stopped
	beat.tick(delta)

func _world_at(p: Vector3, game: Node) -> String:
	var w: Variant = game.world
	if w.has_method("side_of"): return str(_sides[int(w.side_of(p.x,p.z))])
	return str(w.id)

func _read_book(game: Node) -> void:
	for i: int in _polled:
		var e: Dictionary = rows[i]
		if is_found(e): continue
		if e.kind == "line":
			if game.book.records.has(str(e.line)): complete(i)
			continue
		var ids: Variant = e.book
		for id: String in (ids if ids is Array else [ids]):
			if game.book.found.has(id):
				complete(i)
				break

func _landed(game: Node, p: Vector3) -> void:
	for i: int in _near(p,REACH):
		var e: Dictionary = rows[i]
		if e.kind != "landing" or is_found(e): continue
		if Vector2(p.x-e.at.x,p.z-e.at.z).length() <= float(e.get("radius",LAND_RADIUS)) and absf(p.y-float(e.at.y)) < 30.0:
			complete(i)

static func _segment_near(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b-a
	var k := clampf((c-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
	return (a+ab*k).distance_squared_to(c) <= r*r

# --- The stream -------------------------------------------------------------------------

func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.z/CELL))

## The rows in the grid within `reach` of `p` (by cell: a little over).
func _near(p: Vector3, reach: float) -> Array:
	var c := _cell_of(p)
	var n := ceili(reach/CELL)
	var out: Array = []
	for z in range(c.y-n,c.y+n+1):
		for x in range(c.x-n,c.x+n+1):
			var got_cell: Variant = _grid.get(Vector2i(x,z))
			if got_cell != null: out.append_array(got_cell)
	return out

## Only here does the table get read: the plane has entered another cell.
func _stream(p: Vector3, _first: bool) -> void:
	_cell = _cell_of(p)
	stream_reads += 1
	var want: Array = []
	for i: int in _near(p,REACH):
		var e: Dictionary = rows[i]
		if e.kind == "relic" and is_found(e): continue
		if not e.kind in ["relic","landing"]: continue
		var d := Vector2(p.x-e.at.x,p.z-e.at.z).length_squared()
		if d <= REACH*REACH: want.append([d,i])
	want.sort()
	want.resize(mini(want.size(),MAX_LIVE))
	var keep := {}
	for w: Array in want: keep[int(w[1])] = true
	for i: int in _live.keys():
		if keep.has(i): continue
		var node: Marks.Mark = _live[i]
		_live.erase(i)
		node.visible = false
		_pool.append(node)
	for i: int in keep:
		if _live.has(i): continue
		var node: Marks.Mark = _pool.pop_back() if not _pool.is_empty() else _new_mark()
		var e: Dictionary = rows[i]
		node.show_as(str(e.kind),e.at,e,is_found(e),_field)
		_live[i] = node

func _new_mark() -> Marks.Mark:
	var node := Marks.Mark.new()
	add_child(node)
	return node

## How many nodes stand (for drivers).
func live_count() -> int:
	return _live.size()

# --- The logbook's page -----------------------------------------------------------------

## The Wilderness page: [{area, title, got, of, rows: [{found, text, value}]}]
## in AREAS' order, for every world with rows.
func ledger() -> Array:
	var book: PilotBook = _game.book
	var out: Array = []
	for area: String in Table.AREAS:
		var block := {"area":area,"title":str(Table.AREAS[area]),"got":0,"of":0,"rows":[]}
		for e: Dictionary in rows:
			if e.area != area: continue
			var done := is_found(e)
			var r := {"found":done,"text":str(e.title) if done else str(e.get("hint","")),"value":""}
			if e.kind == "line" and book.records.has(str(e.line)): r.value = preload("res://scripts/endless/place_lines.gd").lap(float(book.records[str(e.line)]))
			if e.kind == "line" and e.has("mark") and float(e.mark) < float(book.records.get(str(e.line),-1.0)): r.value = "%s / %s" % [r.value,preload("res://scripts/endless/place_lines.gd").lap(float(e.mark))]
			block.of = int(block.of)+1
			if done: block.got = int(block.got)+1
			block.rows.append(r)
		if int(block.of) > 0: out.append(block)
	return out
