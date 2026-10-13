extends Node3D
## Footbridges (docs/scenic/bridges.md): spans laid by a drag with the case's
## footbridge in hand (scripts/hand_materials.gd), across a stream or a narrow
## water, or across a gap in the land: a ravine, a crater, the drop between
## two peaks. The terrain decides. Over water the bridge snaps from bank to
## bank across the water found under the drag. Over a gap each end finds
## level footing near where the drag began and ended (`footing`); with none,
## nothing is laid. Up to TIMBER_SPAN it is a timber arch; longer, up to
## MAX_SPAN, a rope bridge that sags. With nothing to cross, a span too long,
## ends too far apart in height or land rising in the way, nothing is laid;
## the ghost shown while dragging says so.
##
## A bridge is an object record (NativeTerrainData `add_bridge`: "bridge",
## x/z the near bank, end_x/end_z the far one), so undo, saving and the trash
## can (scripts/clay_tools/trash.gd) take it as they take any record. It is
## drawn here, not by the garden's instance batches: each record is one
## faceted mesh in plate metres, a child of the terrain, rebuilt from the
## ground under its ends whenever the records or the land change. It changes
## no height and holds no water: the live water runs under it untouched. A
## rope bridge's mesh lives (scripts/rope_bridge.gd, `live`): it sags under
## the walker, bounces and sways, and its deck (`deck_at`) moves with it.
##
## The planning half is static (`water`, `level_at`, `plan`) so probes and the
## editor read the same answer the ghost shows.

const ClaySound = preload("res://scripts/clay_sound.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")

## The longest span (bank to bank, m), and the shortest worth a bridge. Past
## TIMBER_SPAN a bridge is hung on ropes rather than arched in timber.
const MAX_SPAN := 20.0
const MIN_SPAN := 1.0
const TIMBER_SPAN := 6.0
## A gap: somewhere under the drag the ground falls at least GAP m below the
## line between its ends. A footing: within FOOTING_REACH m of the drag's end
## along its line, a pad FOOTING (along, across, m) whose ground varies by at
## most LEVEL m, dry.
const GAP := 1.0
const FOOTING_REACH := 1.5
const FOOTING := Vector2(0.8,0.8)
const LEVEL := 0.2
## A gap end's seat may have its ground fall SEAT_FALL m behind it over half
## the pad (a crater's rim); seats within SEAT_TIE m of the highest count as
## high, and the one nearest the gap is taken.
const SEAT_FALL := 0.4
const SEAT_TIE := 0.1
## How far (m) a gap bridge's planks may sink into the ground near an end.
const SETTLE := 0.03
## Rise over run between the two banks beyond which it is too steep.
const MAX_GRADE := 0.35
## How far onto each bank (m) past the water's edge an end rests.
const BANK := 0.45
## The planner's step along the drag (m), and how far past the drag's ends it
## looks for the water the drag meant.
const STEP := 0.1
const REACH := 1.5
## Water this deep (m) counts; the deck's underside must clear it by CLEARANCE.
const WET := 0.03
const CLEARANCE := 0.02
## Spans this long and longer have hand rails; shorter ones only end posts.
const RAILS_FROM := 2.5
## A rope bridge: its hand ropes' height over the deck (m: RopeBridge
## `hand_rope`, grown with the wanderer), and the tones of rope and of its
## posts.
static var HAND_ROPE: float = RopeBridge.hand_rope
const ROPE := Color("9a8360")
const POST := Color("5a4330")
## The deck: width (m: RopeBridge `width`, grown with the wanderer) and the
## planks' depth. A rope bridge's planks are laid ROPE_PITCH m apart, times
## RopeBridge `chunk` (`rope_planks`).
static var WIDTH: float = RopeBridge.width
const ROPE_PITCH := 0.27
const PLANK := 0.2
const DECK_DEPTH := 0.12
## Timber tones (sRGB): weathered deck, darker stringers and sills, rails.
const DECK := Color("8a6a4a")
const BEAM := Color("5a4330")
const SILL := Color("4c3a2a")
const RAIL := Color("6f5238")
## The ghost: warm and faint where it would be laid, a dull red where not.
const GHOST_OK := Color(1.0,0.94,0.8,0.42)
const GHOST_NO := Color(0.86,0.42,0.36,0.3)

## The editor (NativeChunkEditor): its `data` holds the records.
var editor: Node
## Bridges rebuilt and reused, for probes.
var rebuilt := 0
var reused := 0
var _entries := {}
var _revision := -1
var _material: StandardMaterial3D
var _ghost: MeshInstance3D
var _ghost_key := PackedByteArray()
static var _decks: Array[Dictionary] = []
static var _decks_key := []
## The live rope bridges' sims (scripts/rope_bridge.gd) by record id, for
## the decks the walker reads.
static var _sims := {}

func _init() -> void:
	name = "Footbridges"
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

# --- Reading the water --------------------------------------------------------

## What water the planner reads, gathered once for a drag: the live water's
## depths, the pond surfaces (with their bounds) and the stream beds'
## segments. {"data", "flow", "depths", "ponds", "courses"}.
static func water(source: Node) -> Dictionary:
	var data: NativeTerrainData = source.data
	var flow: Variant = source.get("flow")
	var live: bool = flow != null and flow.ready
	var ponds := []
	for pond: Dictionary in data.ponds:
		var surface := data.pond_surface(pond)
		if surface.is_empty(): continue
		var bounds := Rect2(Vector2(surface[0].x,surface[0].z),Vector2.ZERO)
		for vertex in surface: bounds = bounds.expand(Vector2(vertex.x,vertex.z))
		ponds.append({"surface":surface,"bounds":bounds,"level":float(pond.level)})
	var courses := []
	for stream: Dictionary in data.streams:
		var pts: Array = stream.get("pts",[])
		for i in range(pts.size()-1):
			var a: Dictionary = pts[i]
			var b: Dictionary = pts[i+1]
			courses.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"half":float(stream.get("width",0.6))*0.5,"level":maxf(float(a.h),float(b.h))+float(stream.get("surface",0.06))})
	return {"data":data,"flow":flow if live else null,"depths":flow.depths() if live else PackedFloat32Array(),"ponds":ponds,"courses":courses}

## The water's surface over plate point `p`, or -INF where it is dry (or off
## the land): live water at least WET deep, a pond, or a stream bed.
static func level_at(found: Dictionary, p: Vector2) -> float:
	var data: NativeTerrainData = found.data
	var ground: Variant = data.ground_height(p)
	if ground == null: return -INF
	var best := -INF
	var flow: Variant = found.flow
	if flow != null:
		var cell: int = flow.cell_at(p)
		var depths: PackedFloat32Array = found.depths
		if cell >= 0 and cell < depths.size() and depths[cell] >= WET: best = float(ground)+depths[cell]
	for pond: Dictionary in found.ponds:
		if float(pond.level) < float(ground)+WET or not (pond.bounds as Rect2).has_point(p): continue
		if GardenWater.covers(pond.surface,p): best = maxf(best,float(pond.level))
	for course: Dictionary in found.courses:
		if float(course.level) <= float(ground): continue
		if Geometry2D.get_closest_point_to_segment(p,course.a,course.b).distance_to(p) <= float(course.half): best = maxf(best,float(course.level))
	return best

## The arch's rise (m) at mid-span for a timber span `span` m long.
static func rise(span: float) -> float:
	return clampf(0.08*span+0.1,0.15,0.6)

## A rope bridge's sag (m) at mid-span.
static func sag(span: float) -> float:
	return clampf(0.05*span,0.3,1.0)

## True for a span hung on ropes.
static func roped(span: float) -> bool:
	return span > TIMBER_SPAN

## The deck's bow at mid-span (m): up for a timber arch, down for ropes.
static func bow(span: float) -> float:
	return -sag(span) if roped(span) else rise(span)

## The deck's height over the straight line between its ends (m), at `u` (0
## at one end, 1 at the other) of a span `span` m long. A timber arch is a
## sine; a rope bridge's sag is a sine squared, leaving each anchor level so
## the deck rests on the rim before it hangs out over the drop.
static func lift(span: float, u: float) -> float:
	var shape := sin(PI*u)
	return bow(span)*(shape*shape if roped(span) else shape)

## Where a drag from `from` to `to` (plate) would lay a bridge over `found`
## (`water`). {"ok": true, "a", "b" (ends, plate), "ya", "yb" (ground
## there), "span", "water" (highest level crossed, -INF over a dry gap),
## "gap" (true over a gap)}, or {"ok": false, "reason"}: "short" (no drag to
## read), "dry" (no water and no gap near the drag), "too_long" (more than
## MAX_SPAN end to end), "edge" (an end off the land), "no_bank" (water at an
## end), "no_footing" (no level ground for an end), "too_steep", "blocked"
## (the land rises into the deck) or "flooded" (the water stands as high as
## the deck). A refusal past the snap keeps "a" and "b".
##
## A drag across a gap is read as one (`_plan_gap`). Where the gap will not
## take a bridge, a bridge over water under the drag still may, if it spans at
## least half the drag: a stream in a shallow valley is bridged bank to bank,
## but a drag from peak to peak never drops to a little bridge over the stream
## far below. With no gap, the water decides (`_plan_water`).
static func plan(found: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	if from.distance_to(to) < 0.25: return {"ok":false,"reason":"short"}
	var gap := _plan_gap(found,from,to)
	if gap.ok: return gap
	var wet := _plan_water(found,from,to)
	if not gap.get("gap",false): return wet
	if wet.ok and float(wet.span) >= 0.5*from.distance_to(to): return wet
	return gap

## How far (m) the ground under the line from `a` to `b` falls below the
## straight line between their ground, at most, from `margin` m in from
## each end; or -INF where an end is off the land.
static func depth_under(data: NativeTerrainData, a: Vector2, b: Vector2, margin := 0.0) -> float:
	var ga: Variant = data.ground_height(a)
	var gb: Variant = data.ground_height(b)
	if ga == null or gb == null: return -INF
	var span := a.distance_to(b)
	var deepest := -INF
	var d := margin
	while d <= span-margin:
		var u := d/span
		var g: Variant = data.ground_height(a.lerp(b,u))
		if g != null: deepest = maxf(deepest,lerpf(float(ga),float(gb),u)-float(g))
		d += STEP
	return deepest

## Dry footing for the end of a bridge along `way` near plate point `end`, on
## the line within FOOTING_REACH. With `toward` 0, a level pad: ground that
## varies by at most LEVEL, the nearest to `end`. With `toward` (+1 along
## `way`, -1 against it, the side the gap is on), a seat at the gap's lip
## (`_seat`): the highest one, and of those as high, the furthest toward the
## gap, so an end climbs to a crater's rim rather than settling on its floor
## or walls, and stands at a plateau's edge rather than back from it. Null
## where none.
static func footing(found: Dictionary, end: Vector2, way: Vector2, toward := 0.0) -> Variant:
	var data: NativeTerrainData = found.data
	var across := Vector2(-way.y,way.x)
	if toward != 0.0:
		var ahead := way*signf(toward)
		var best: Variant = null
		var best_y := -INF
		var d := FOOTING_REACH
		while d >= -FOOTING_REACH-0.001:
			var at := end+ahead*d
			var y := _seat(found,at,ahead)
			if y > best_y+SEAT_TIE:
				best = at
				best_y = y
			d -= STEP
		return best
	var offsets := [0.0]
	var d := STEP
	while d <= FOOTING_REACH+0.001:
		offsets.append(d)
		offsets.append(-d)
		d += STEP
	for offset: float in offsets:
		var at := end+way*offset
		var low := INF
		var high := -INF
		var dry := true
		for i in [-1,0,1]:
			for j in [-1,0,1]:
				var p: Vector2 = at+way*FOOTING.x*0.5*float(i)+across*FOOTING.y*0.5*float(j)
				var g: Variant = data.ground_height(p)
				if g == null or level_at(found,p) > -INF:
					dry = false
					break
				low = minf(low,float(g))
				high = maxf(high,float(g))
			if not dry: break
		if dry and high-low <= LEVEL: return at
	return null

## The ground under a bridge end at `at` facing the gap along `ahead`, or
## -INF where it cannot stand: dry under a pad FOOTING wide whose ground
## across the line varies by at most LEVEL, with nothing in the pad, ahead or
## behind, more than LEVEL above the end. Behind the end the ground may fall,
## by at most SEAT_FALL over half the pad, as a crater's rim falls away
## outside its crest; a plateau's level top is a seat too.
static func _seat(found: Dictionary, at: Vector2, ahead: Vector2) -> float:
	var data: NativeTerrainData = found.data
	var across := Vector2(-ahead.y,ahead.x)
	var g: Variant = data.ground_height(at)
	if g == null: return -INF
	var y := float(g)
	for i in [-1,0,1]:
		for j in [-1,0,1]:
			var p: Vector2 = at+ahead*FOOTING.x*0.5*float(i)+across*FOOTING.y*0.5*float(j)
			var h: Variant = data.ground_height(p)
			if h == null or level_at(found,p) > -INF: return -INF
			if float(h) > y+LEVEL: return -INF
			if i == -1 and float(h) < y-SEAT_FALL: return -INF
			if i == 0 and absf(float(h)-y) > LEVEL: return -INF
	return y

## A bridge across a gap in the land: {"gap": false} when the drag does not
## cross one, else the plan (or the refusal) with "gap": true.
static func _plan_gap(found: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	var data: NativeTerrainData = found.data
	if depth_under(data,from,to) < GAP: return {"ok":false,"reason":"dry","gap":false}
	var way := (to-from).normalized()
	var fa: Variant = footing(found,from,way,1.0)
	var fb: Variant = footing(found,to,way,-1.0)
	if fa == null or fb == null: return {"ok":false,"reason":"no_footing","gap":true,"a":from,"b":to}
	var a: Vector2 = fa
	var b: Vector2 = fb
	var span := a.distance_to(b)
	if span < MIN_SPAN: return {"ok":false,"reason":"short","gap":true,"a":a,"b":b}
	if span > MAX_SPAN: return {"ok":false,"reason":"too_long","gap":true,"a":a,"b":b}
	var ya := float(data.ground_height(a))
	var yb := float(data.ground_height(b))
	if absf(yb-ya)/span > MAX_GRADE: return {"ok":false,"reason":"too_steep","gap":true,"a":a,"b":b}
	# Clear of the land, and of any water, between the footings. Over its
	# first and last metre the deck may rest on the ground, as an end does on
	# its sill (sunk at most SETTLE); over the next its underside comes clear.
	var top := -INF
	var d := FOOTING.x*0.5
	while d <= span-FOOTING.x*0.5:
		var u := d/span
		var p := a.lerp(b,u)
		var deck := lerpf(ya,yb,u)+lift(span,u)
		var under := deck-DECK_DEPTH
		var settle := clampf(minf(d,span-d)-1.0,0.0,1.0)
		var g: Variant = data.ground_height(p)
		if g != null and float(g) > deck+SETTLE-(DECK_DEPTH+CLEARANCE+SETTLE)*settle: return {"ok":false,"reason":"blocked","gap":true,"a":a,"b":b}
		var level := level_at(found,p)
		if level > -INF and under < level+CLEARANCE: return {"ok":false,"reason":"flooded","gap":true,"a":a,"b":b}
		top = maxf(top,level)
		d += STEP
	if depth_under(data,a,b) < GAP: return {"ok":false,"reason":"dry","gap":true,"a":a,"b":b}
	return {"ok":true,"a":a,"b":b,"ya":ya,"yb":yb,"span":span,"water":top,"gap":true}

## A bridge across the water found near the drag, bank to bank.
static func _plan_water(found: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	var axis := to-from
	var length := axis.length()
	var way := axis/length
	# The wet sample nearest the drag's middle, on the drag or just past it.
	var seed_t := NAN
	var nearest := INF
	var t := -REACH
	while t <= length+REACH:
		if level_at(found,from+way*t) > -INF and absf(t-length*0.5) < nearest:
			nearest = absf(t-length*0.5)
			seed_t = t
		t += STEP
	if is_nan(seed_t): return {"ok":false,"reason":"dry"}
	# Out along the line to the water's edges on both sides.
	var low := seed_t
	var high := seed_t
	while level_at(found,from+way*(low-STEP)) > -INF:
		low -= STEP
		if high-low+STEP+2.0*BANK > MAX_SPAN: return {"ok":false,"reason":"too_long"}
	while level_at(found,from+way*(high+STEP)) > -INF:
		high += STEP
		if high-low+STEP+2.0*BANK > MAX_SPAN: return {"ok":false,"reason":"too_long"}
	var ta := low-STEP*0.5-BANK
	var tb := high+STEP*0.5+BANK
	var span := tb-ta
	var a := from+way*ta
	var b := from+way*tb
	if span > MAX_SPAN: return {"ok":false,"reason":"too_long","a":a,"b":b}
	if span < MIN_SPAN:
		# A rill: lengthen the ends evenly to the shortest bridge.
		var grow := (MIN_SPAN-span)*0.5
		ta -= grow
		tb += grow
		span = MIN_SPAN
		a = from+way*ta
		b = from+way*tb
	var data: NativeTerrainData = found.data
	var ga: Variant = data.ground_height(a)
	var gb: Variant = data.ground_height(b)
	if ga == null or gb == null: return {"ok":false,"reason":"edge","a":a,"b":b}
	if level_at(found,a) > -INF or level_at(found,b) > -INF: return {"ok":false,"reason":"no_bank","a":a,"b":b}
	var ya := float(ga)
	var yb := float(gb)
	if absf(yb-ya)/span > MAX_GRADE: return {"ok":false,"reason":"too_steep","a":a,"b":b}
	var top := -INF
	t = low
	while t <= high+0.001:
		var level := level_at(found,from+way*t)
		var u := (t-ta)/span
		var under := lerpf(ya,yb,u)+lift(span,u)-DECK_DEPTH
		if level > -INF and under < level+CLEARANCE: return {"ok":false,"reason":"flooded","a":a,"b":b}
		top = maxf(top,level)
		t += STEP
	return {"ok":true,"a":a,"b":b,"ya":ya,"yb":yb,"span":span,"water":top,"gap":false}

# --- Drawing ------------------------------------------------------------------

## Each frame: a change to the records (a placement, the trash can, an undo)
## redraws what changed. The editor's refresh redraws after the land moves.
func _process(_delta: float) -> void:
	if editor == null or editor.data == null: return
	if int(editor.data.objects_revision) != _revision: rebuild()

## Draws every bridge record from the ground under its ends; a bridge whose
## ends have not moved keeps its mesh.
func rebuild() -> void:
	if editor == null: return
	var data: NativeTerrainData = editor.data
	_revision = data.objects_revision
	var current := {}
	for item: Dictionary in data.objects:
		if item.asset != "bridge" or not item.has("end_x"): continue
		var ends := ends_of(data,item)
		if ends.is_empty(): continue
		var signature := var_to_bytes(ends)
		var entry: Dictionary = _entries.get(int(item.id),{})
		if not entry.is_empty() and entry.signature == signature and is_instance_valid(entry.node):
			reused += 1
		else:
			if not entry.is_empty() and is_instance_valid(entry.node): entry.node.free()
			var node := _drawn(ends[0],ends[1],int(item.id))
			node.name = "bridge_%d" % int(item.id)
			add_child(node)
			entry = {"node":node,"signature":signature}
			rebuilt += 1
		current[int(item.id)] = entry
		if entry.node.get("sim") != null: _sims[int(item.id)] = entry.node.sim
	for id: int in _entries:
		if not current.has(id) and is_instance_valid(_entries[id].node): _entries[id].node.free()
		if not current.has(id): _sims.erase(id)
	_entries = current

## A bridge from `a` to `b` drawn: a rope bridge alive (scripts/
## rope_bridge.gd), a timber one as it is.
func _drawn(a: Vector3, b: Vector3, seed: int) -> MeshInstance3D:
	var mesh := build_mesh(a,b,seed)
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	if roped(span): return live(mesh,a,b,seed)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material
	return node

## The rope bridge `build_mesh(a, b, seed)` made as `mesh`, alive (scripts/
## rope_bridge.gd), its deck the walker reads `record` (or none).
static func live(mesh: Mesh, a: Vector3, b: Vector3, seed: int, record := {}) -> MeshInstance3D:
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	return RopeBridge.make(mesh,a,b,seed,bow(span),WIDTH,rope_planks(span),record)

## A rope bridge `span` m long has this many planks, ROPE_PITCH times
## RopeBridge `chunk` apart.
static func rope_planks(span: float) -> int:
	return maxi(8,roundi(span/(ROPE_PITCH*RopeBridge.chunk)))

## A record's two ends on the ground (plate), or [] when one is off the land.
static func ends_of(data: NativeTerrainData, item: Dictionary) -> PackedVector3Array:
	var a := Vector2(float(item.x),float(item.z))
	var b := Vector2(float(item.end_x),float(item.end_z))
	var ya: Variant = data.ground_height(a)
	var yb: Variant = data.ground_height(b)
	if ya == null or yb == null: return PackedVector3Array()
	return PackedVector3Array([Vector3(a.x,float(ya),a.y),Vector3(b.x,float(yb),b.y)])

# --- The deck underfoot -------------------------------------------------------

## Every bridge's deck as something to stand on: one {"a", "b" (the ends on
## the ground, plate), "span" (m, flat), "rails"} a record, from the same ends and
## arch the mesh is built on. Read again at most once a frame, so a
## reshaped bank moves the deck as it moves the drawing.
static func decks(data: NativeTerrainData) -> Array[Dictionary]:
	var key := [data.get_instance_id(),data.objects_revision,Engine.get_process_frames()]
	if key == _decks_key: return _decks
	_decks_key = key
	_decks = []
	for item: Dictionary in data.objects:
		if item.asset != "bridge" or not item.has("end_x"): continue
		var ends := ends_of(data,item)
		if ends.is_empty(): continue
		var span := Vector2(ends[1].x-ends[0].x,ends[1].z-ends[0].z).length()
		if span < 0.01: continue
		_decks.append({"a":ends[0],"b":ends[1],"span":span,"rails":span >= RAILS_FROM,"sim":_sims.get(int(item.id))})
	return _decks

## The deck under plate point `p` (the highest, where two cross): {"y" (the
## planks' top, plate m), "t" (0 at the near end to 1 at the far one),
## "side" (m off the middle line), "deck"}, or {} off every deck.
static func deck_at(found: Array[Dictionary], p: Vector2) -> Dictionary:
	var best := {}
	for deck in found:
		var a: Vector3 = deck.a
		var b: Vector3 = deck.b
		var from := Vector2(a.x,a.z)
		var way := Vector2(b.x,b.z)-from
		var t := (p-from).dot(way)/way.length_squared()
		if t < 0.0 or t > 1.0: continue
		var side := (p-from).cross(way)/way.length()
		# A live rope bridge (scripts/rope_bridge.gd) sways (its +side is
		# this one's -side), rises and sinks.
		var live: Variant = deck.get("sim")
		if live != null: side += float(live.sway(t))
		if absf(side) > WIDTH*0.5: continue
		var y := lerpf(a.y,b.y,t)+lift(float(deck.span),t)+(float(live.drop(t,-side)) if live != null else 0.0)
		if best.is_empty() or y > float(best.y): best = {"y":y,"t":t,"side":side,"deck":deck}
	return best

## `p` held on `deck` between its rails: pulled back in across the deck, as
## far as `margin` m inside its edge, anywhere but past its ends.
static func keep_on(deck: Dictionary, p: Vector2, margin: float) -> Vector2:
	var a: Vector3 = deck.a
	var b: Vector3 = deck.b
	var from := Vector2(a.x,a.z)
	var way := Vector2(b.x,b.z)-from
	var t := (p-from).dot(way)/way.length_squared()
	if t <= 0.0 or t >= 1.0: return p
	var along := from+way*t
	var off := p-along
	var room := maxf(WIDTH*0.5-margin,0.0)
	return along+off.limit_length(room)

## The drawn bridge for record `id`, or null.
func node_of(id: int) -> MeshInstance3D:
	var entry: Dictionary = _entries.get(id,{})
	return entry.node if not entry.is_empty() and is_instance_valid(entry.node) else null

## Bridges drawn now.
func count() -> int:
	return _entries.size()

## Record `id`'s drawn parts, [{mesh, material, transform (world)}], for the
## trash can's flight.
func parts(id: int) -> Array[Dictionary]:
	var node := node_of(id)
	if node == null: return []
	return [{"mesh":node.mesh,"material":_material,"transform":node.global_transform}]

# --- The ghost ----------------------------------------------------------------

## While a drag is under way: the bridge it would lay, faint and warm, or,
## where none would go, a dull red one along the drag itself (from the snap's
## banks when the refusal came after it). Hidden for a drag too short to read.
func show_ghost(found: Dictionary, from: Vector2, to: Vector2) -> void:
	var data: NativeTerrainData = editor.data
	var ok: bool = found.get("ok",false)
	var a: Vector2 = found.get("a",from)
	var b: Vector2 = found.get("b",to)
	var ya: Variant = data.ground_height(a)
	var yb: Variant = data.ground_height(b)
	if a.distance_to(b) < 0.3 or ya == null or yb == null:
		hide_ghost()
		return
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.name = "BridgeGhost"
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost.material_override = material
		add_child(_ghost)
	var ends := PackedVector3Array([Vector3(a.x,float(ya),a.y),Vector3(b.x,float(yb),b.y)])
	var key := var_to_bytes([ends,ok])
	if key != _ghost_key:
		_ghost_key = key
		_ghost.mesh = build_mesh(ends[0],ends[1],0)
		(_ghost.material_override as StandardMaterial3D).albedo_color = GHOST_OK if ok else GHOST_NO
	_ghost.visible = true

func hide_ghost() -> void:
	if _ghost != null: _ghost.visible = false

## The ghost's state, for probes: "" hidden, else "ok" or "no".
func ghost_state() -> String:
	if _ghost == null or not _ghost.visible: return ""
	return "ok" if (_ghost.material_override as StandardMaterial3D).albedo_color == GHOST_OK else "no"

# --- The mesh -----------------------------------------------------------------

## A faceted timber footbridge from `a` to `b` (plate, on the ground), in
## plate metres. A gentle arch (`rise`) of planks laid across two stringers,
## a sill log under each end, and posts: corner stubs on a short span, posts
## and a hand rail each side from RAILS_FROM. Every plank is cut a little
## differently (`seed`), each face flat-shaded in its own tone.
static func build_mesh(a: Vector3, b: Vector3, seed: int) -> ArrayMesh:
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var span := maxf(flat.length(),0.01)
	var across := (flat/span).cross(Vector3.UP).normalized()
	var curve := func(t: float) -> Vector3: return a.lerp(b,t)+Vector3.UP*lift(span,t)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*7919+104729
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if roped(span):
		_rope_bridge(st,a,b,span,across,curve,rng)
		return st.commit()
	# Planks across the arch, each on the curve's slope.
	var planks := maxi(4,roundi(span/PLANK))
	for i in range(planks):
		var t := (i+0.5)/planks
		var along: Vector3 = (curve.call(minf(t+0.01,1.0))-curve.call(maxf(t-0.01,0.0))).normalized()
		var up := across.cross(along).normalized()
		if up.y < 0.0: up = -up
		var yaw := Basis(up,rng.randf_range(-0.05,0.05))
		var centre: Vector3 = curve.call(t)+across*rng.randf_range(-0.03,0.03)+up*rng.randf_range(-0.008,0.008)
		var half := Vector3(span/planks*0.42,0.025+rng.randf_range(0.0,0.008),WIDTH*0.5+rng.randf_range(-0.04,0.03))
		_box(st,centre-up*half.y,yaw*along,up,yaw*across,half,DECK.darkened(rng.randf_range(0.0,0.14)),rng)
	# Two stringers under them, in straight pieces along the arch.
	var pieces := 8
	for side in [-1.0,1.0]:
		var offset: Vector3 = across*side*WIDTH*0.34
		_beam(st,curve,offset+Vector3.DOWN*0.11,pieces,Vector2(0.05,0.045),BEAM,rng)
	# A sill log across under each end, half sunk.
	for t in [0.0,1.0]:
		var at: Vector3 = curve.call(t)
		var way := (b-a).normalized()
		_box(st,at+Vector3.DOWN*0.12,way,Vector3.UP,across,Vector3(0.09,0.08,WIDTH*0.62),SILL.darkened(rng.randf_range(0.0,0.1)),rng)
	# Posts, and a rail along them on a longer span.
	var rails := span >= RAILS_FROM
	var stops := [0.03,0.97]
	if rails:
		stops = [0.03,0.5,0.97] if span < 4.5 else [0.03,0.3,0.7,0.97]
	var tall := 0.56 if rails else 0.2
	for side in [-1.0,1.0]:
		var offset: Vector3 = across*side*(WIDTH*0.5+0.03)
		for t: float in stops:
			var foot: Vector3 = curve.call(t)+offset+Vector3.DOWN*0.12
			_box(st,foot+Vector3.UP*(tall+0.12)*0.5,(b-a).normalized(),Vector3.UP,across,Vector3(0.04,(tall+0.12)*0.5,0.04),RAIL.darkened(rng.randf_range(0.0,0.12)),rng)
		if rails:
			_beam(st,curve,offset+Vector3.UP*(tall-0.03),pieces,Vector2(0.028,0.032),RAIL,rng,stops[0],stops[-1])
	return st.commit()

## A rope bridge from `a` to `b` (plate, on the ground) along `curve`, its
## sagging deck: spaced planks laid on two foot ropes, two hand ropes that
## sag less, cords between them, and a pair of tall posts at each end, sunk
## in the footing, with a sill log across under the planks' ends.
static func _rope_bridge(st: SurfaceTool, a: Vector3, b: Vector3, span: float, across: Vector3, curve: Callable, rng: RandomNumberGenerator) -> void:
	var way := (b-a).normalized()
	var flat_way := Vector3(way.x,0.0,way.z).normalized()
	var hand := func(t: float) -> Vector3: return a.lerp(b,t)+Vector3.UP*(HAND_ROPE+lift(span,t)*0.55)
	# Planks across the sag, with gaps between, each on the curve's slope.
	var planks := rope_planks(span)
	var k := RopeBridge.chunk
	for i in range(planks):
		var t := (i+0.5)/planks
		var along: Vector3 = (curve.call(minf(t+0.01,1.0))-curve.call(maxf(t-0.01,0.0))).normalized()
		var up := across.cross(along).normalized()
		if up.y < 0.0: up = -up
		var yaw := Basis(up,rng.randf_range(-0.07,0.07))
		var centre: Vector3 = curve.call(t)+across*rng.randf_range(-0.03,0.03)
		var half := Vector3(span/planks*0.34,(0.022+rng.randf_range(0.0,0.006))*k,WIDTH*0.5+rng.randf_range(-0.05,0.02))
		_box(st,centre-up*half.y,yaw*along,up,yaw*across,half,DECK.darkened(rng.randf_range(0.0,0.16)),rng)
	var pieces := maxi(12,roundi(span*2.0))
	for side in [-1.0,1.0]:
		# The foot ropes under the planks' ends, the hand ropes above.
		_beam(st,curve,across*side*WIDTH*0.42+Vector3.DOWN*0.05*k,pieces,Vector2(0.02,0.02)*k,ROPE,rng)
		var rail: Vector3 = across*side*(WIDTH*0.5+0.04*k)
		_beam(st,hand,rail,pieces,Vector2(0.022,0.022)*k,ROPE,rng,0.0,1.0)
		# Cords from the hand rope down to the deck's edge, about every 0.5 m.
		var cords := maxi(4,roundi(span/0.5))
		for c in range(1,cords):
			var t := float(c)/cords
			var top: Vector3 = hand.call(t)+rail
			var foot: Vector3 = curve.call(t)+across*side*WIDTH*0.46
			var up := (top-foot).normalized()
			var side_axis := up.cross(flat_way).normalized()
			_box(st,(top+foot)*0.5,flat_way,up,side_axis,Vector3(0.01*k,top.distance_to(foot)*0.5,0.01*k),ROPE.darkened(rng.randf_range(0.05,0.15)),rng)
		# A tall post at each end, sunk in the footing, just outside the deck.
		for t in [0.0,1.0]:
			var outward := -flat_way if t == 0.0 else flat_way
			var foot: Vector3 = curve.call(t)+rail+outward*0.08*k+Vector3.DOWN*0.15*k
			var tall := HAND_ROPE+(0.15+0.15)*k
			_box(st,foot+Vector3.UP*tall*0.5,flat_way,Vector3.UP,across,Vector3(0.055,tall*0.5,0.055)*Vector3(k,1.0,k),POST.darkened(rng.randf_range(0.0,0.12)),rng)
	# A sill log across under each end of the deck.
	for t in [0.0,1.0]:
		_box(st,curve.call(t)+Vector3.DOWN*0.1*k,flat_way,Vector3.UP,across,Vector3(0.09*k,0.08*k,WIDTH*0.62),SILL.darkened(rng.randf_range(0.0,0.1)),rng)

## A beam along the arch from `t0` to `t1` in `pieces` straight lengths,
## `offset` from the curve, `size` (half height, half width).
static func _beam(st: SurfaceTool, curve: Callable, offset: Vector3, pieces: int, size: Vector2, colour: Color, rng: RandomNumberGenerator, t0 := 0.0, t1 := 1.0) -> void:
	for k in range(pieces):
		var p: Vector3 = curve.call(lerpf(t0,t1,float(k)/pieces))+offset
		var q: Vector3 = curve.call(lerpf(t0,t1,float(k+1)/pieces))+offset
		var along := (q-p).normalized()
		var side := along.cross(Vector3.UP).normalized()
		var up := side.cross(along).normalized()
		_box(st,(p+q)*0.5,along,up,side,Vector3(p.distance_to(q)*0.5+0.015,size.x,size.y),colour.darkened(rng.randf_range(0.0,0.08)),rng)

## A box centred at `centre` on axes `x`, `y`, `z` (unit) with half extents
## `half`, each face flat in a tone near `colour`.
static func _box(st: SurfaceTool, centre: Vector3, x: Vector3, y: Vector3, z: Vector3, half: Vector3, colour: Color, rng: RandomNumberGenerator) -> void:
	var corner := func(i: int, j: int, k: int) -> Vector3: return centre+x*half.x*i+y*half.y*j+z*half.z*k
	# Each face: its outward axis and four corners round it.
	var faces := [
		[y,[corner.call(-1,1,-1),corner.call(1,1,-1),corner.call(1,1,1),corner.call(-1,1,1)],1.08],
		[-y,[corner.call(-1,-1,1),corner.call(1,-1,1),corner.call(1,-1,-1),corner.call(-1,-1,-1)],0.7],
		[x,[corner.call(1,-1,-1),corner.call(1,-1,1),corner.call(1,1,1),corner.call(1,1,-1)],0.92],
		[-x,[corner.call(-1,-1,1),corner.call(-1,-1,-1),corner.call(-1,1,-1),corner.call(-1,1,1)],0.88],
		[z,[corner.call(1,-1,1),corner.call(-1,-1,1),corner.call(-1,1,1),corner.call(1,1,1)],0.96],
		[-z,[corner.call(-1,-1,-1),corner.call(1,-1,-1),corner.call(1,1,-1),corner.call(-1,1,-1)],0.84],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var quad: Array = face[1]
		var tone: Color = colour*float(face[2])*rng.randf_range(0.95,1.04)
		tone.a = 1.0
		# Clockwise seen from outside, Godot's front face.
		var order := [0,1,2,0,2,3]
		var n: Vector3 = ((quad[1]-quad[0]) as Vector3).cross(quad[2]-quad[0])
		if n.dot(normal) > 0.0: order = [0,2,1,0,3,2]
		for index: int in order:
			st.set_color(tone)
			st.set_normal(normal)
			st.add_vertex(quad[index])
