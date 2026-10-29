extends Node
## The shops (docs/design/endless-flight/spec-wild-loop.md, lane `shop`):
## one per CELL m square by the seed, beside a flat landing strip (never on
## it: "Meadows and flats", AGENTS.md), read from far off by a tall mast with
## a lamp and a windsock, a small open hangar and the strip's edge posts.
## Stopping on its strip opens the shop (shop_view.gd) as the game's
## overlay; Esc leaves, and taking off leaves too.
##
## The square holding the start keeps its shop START_REACH m from the start,
## so the first is in reach. A square looks for its strip a few tries a frame
## (BUDGET_MS) once the plane comes within SEARCH m, in an order fixed by the
## seed: the same land gives the same shop. A try is a spot and a heading:
## STRIP m of level dry ground across LANE_HALF m either side of its line,
## one end with an open approach, no tree planted near it nor by the hangar
## (RivalStrip `_tree_free`), the hangar's ground level with it. Near it
## (CHECK m) what stands on the land is read too (the game's `_blocked` and
## `plane_ground`), and a strip something stands on goes on to the next try.
##
## Each shop is named `shop/<ci>_<cj>` for the layout file
## (scripts/layout_overrides.gd): its frame, the strip's centre with -Z down
## the strip, is the coded one unless moved; a deleted name has none.
## The plane wears what the book says (shop_stock.gd `dress`), checked
## every frame, so a new figure or a purchase shows at once.
##
## --shops=0 none.

const ShopStock = preload("res://scripts/endless/shop_stock.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const ShopView = preload("res://scripts/endless/shop_view.gd")
const RivalStrip = preload("res://scripts/endless/rival_strip.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const SEA_Y := -40.0
const CELL := 3200.0
const MARGIN := 500.0
## The start's square: its shop this far from the start (m), nearest first.
const START_REACH := Vector2(400.0,1500.0)
## Spots a square tries, and headings at each.
const TRIES := 400
const HEADINGS := 6
## A square is looked at once the plane is this near its box (m); a shop is
## built this near (m), freed past DROP, and checked against what stands on
## the land this near.
const SEARCH := 2800.0
const SHOW := 3400.0
const DROP := 4200.0
const CHECK := 1100.0
const BUDGET_MS := 1.5
## The strip: STRIP m long (the land's flats check: land_ponds.gd STRIP),
## read every READ m on three lines LANE_HALF m apart; no rise over
## STEP_RISE between neighbours, nor over SPAN_RISE across 64 m, nor over
## ACROSS_RISE from line to line.
const STRIP := 208.0
const READ := 16.0
const LANE_HALF := 6.0
const STEP_RISE := 1.92
const SPAN_RISE := 3.84
const ACROSS_RISE := 1.4
## Dry by this much (m) over the sea and past a river's edge.
const DRY := 3.0
## A stop counts on the strip within ON_HALF m of its line and its ends'
## ON_PAST m past them.
const ON_HALF := 16.0
const ON_PAST := 30.0
## The approach: from APPROACH_FROM to APPROACH m out from one end, the land
## under a CLEAR m over a 1:GLIDE slope up from the strip.
const APPROACH_FROM := 40.0
const APPROACH := 360.0
const CLEAR := 6.0
const GLIDE := 8.0
## The hangar: its centre SHED_OFF m off the strip's line, SHED_LONG m
## along the strip, SHED_DEEP deep and SHED_TALL to its eaves; its ground
## within SHED_LEVEL m of the strip's.
const SHED_OFF := 30.0
const SHED_LONG := 11.0
const SHED_DEEP := 8.0
const SHED_TALL := 4.6
const SHED_LEVEL := 2.2
## The mast: by the hangar, MAST m tall, its lamp LAMP m across.
const MAST := 28.0
const LAMP := 2.4
## Edge posts every POST_EVERY m down both sides, POST m tall.
const POST_EVERY := 26.0
const POST := 2.2

var game: Node
var seed := 1
var on := true
## The start (XZ), for the start's square.
var start := Vector2.ZERO
## Vector2i -> {"k": next try, "site": {} or the site, "state": "looking",
## "found", "none", "checked"}.
var cells := {}
## Vector2i -> the built Node3D.
var built := {}
## The shop open now (its cell), or null; and whether the pilot left it on
## this stop (it opens again on the next stop).
var view: Control
var view_cell := Vector2i.ZERO
var _left_on_stop := false
var _layer: CanvasLayer
var _sock_t := 0.0

static func wanted() -> bool:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == "--shops=0": return false
	return true

static func _hash01(s: int, i: int, j: int, salt: int) -> float:
	return float(hash([s,i,j,salt,4421]) & 0xffffff)/16777216.0

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

static func name_of(key: Vector2i) -> String:
	return "shop/%d_%d" % [key.x,key.y]

func setup(g: Node) -> void:
	game = g
	seed = int(g.seed)
	on = wanted()
	start = Vector2(g.plane.position.x,g.plane.position.z)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)

## The cells' sites found so far: [{name, cell, frame, axis, across, side,
## centre, half_len, ...}].
func sites() -> Array:
	var out: Array = []
	for key: Vector2i in cells:
		var c: Dictionary = cells[key]
		if not (c.site as Dictionary).is_empty(): out.append(c.site)
	return out

## The site of the start's square, looked for at once (all its tries); {} if
## it has none.
func first_site() -> Dictionary:
	var key := cell_of(start.x,start.y)
	var c := _cell(key)
	while c.state == "looking": _look(key,c,INF)
	return c.site

## One frame: look, build and free, check what stands, dress the plane,
## open or close the shop.
func step(delta: float, g: Node) -> void:
	game = g
	_sock_t += delta
	if game.plane_figure != null and game.book != null and view == null: ShopStock.dress(game.plane_figure,game.book)
	if not on: return
	var at := Vector2(game.plane.position.x,game.plane.position.z)
	var spent_from := Time.get_ticks_usec()
	var here := cell_of(at.x,at.y)
	for dj in range(-1,2):
		for di in range(-1,2):
			var key := here+Vector2i(di,dj)
			var box := Rect2(Vector2(key)*CELL,Vector2(CELL,CELL))
			var near := _box_distance(box,at)
			if near > SEARCH and key != cell_of(start.x,start.y): continue
			if near > SEARCH: continue
			var c := _cell(key)
			if c.state == "looking":
				var left := BUDGET_MS*1000.0-float(Time.get_ticks_usec()-spent_from)
				if left > 0.0: _look(key,c,left)
	for key: Vector2i in cells:
		var c: Dictionary = cells[key]
		var site: Dictionary = c.site
		if site.is_empty(): continue
		var d := at.distance_to(Vector2(site.centre.x,site.centre.z))
		if c.state == "found" and d < CHECK:
			if _stands_clear(site): c.state = "checked"
			else:
				print("shop %s: something stands on its strip; looking on" % site.name)
				_free(key)
				c.site = {}
				c.state = "looking"
				continue
		if d < SHOW and not built.has(key): _build(key,site)
		elif d > DROP and built.has(key): _free(key)
	for key: Vector2i in built:
		_sway(built[key])
	_open_or_close()

func _cell(key: Vector2i) -> Dictionary:
	if not cells.has(key): cells[key] = {"k":0,"site":{},"state":"looking" if not LayoutOverrides.deleted(name_of(key)) else "none"}
	return cells[key]

static func _box_distance(box: Rect2, p: Vector2) -> float:
	var q := p.clamp(box.position,box.end)
	return q.distance_to(p)

# --- Looking ----------------------------------------------------------------------------

## Tries on in `key`'s square for up to `budget_us` µs.
func _look(key: Vector2i, c: Dictionary, budget_us: float) -> void:
	var from := Time.get_ticks_usec()
	var field: RefCounted = game.field
	var is_start := key == cell_of(start.x,start.y)
	while int(c.k) < TRIES:
		var k := int(c.k)
		c.k = k+1
		var p: Vector2
		if is_start:
			# Out from the start, nearest first, round by the golden angle.
			var r := lerpf(START_REACH.x,START_REACH.y,float(k)/TRIES)
			var a := k*2.39996+_hash01(seed,key.x,key.y,1)*TAU
			p = start+Vector2(cos(a),sin(a))*r
		else:
			p = Vector2(key)*CELL+Vector2(MARGIN+_hash01(seed,key.x,key.y,10+k*2)*(CELL-2.0*MARGIN),MARGIN+_hash01(seed,key.x,key.y,11+k*2)*(CELL-2.0*MARGIN))
		var turn := _hash01(seed,key.x,key.y,5000+k)*PI
		for h in HEADINGS:
			var yaw := turn+PI*h/HEADINGS
			var site := _try(field,p,Vector2(cos(yaw),sin(yaw)))
			if not site.is_empty():
				c.site = _named(key,site)
				c.state = "found" if not c.site.is_empty() else "none"
				if not c.site.is_empty(): print("shop %s: a strip %.0f m from the start (try %d)" % [c.site.name,start.distance_to(Vector2(c.site.centre.x,c.site.centre.z)),k])
				return
		if float(Time.get_ticks_usec()-from) > budget_us: return
	c.state = "none"

## The site for a strip centred on `p` along `d` (XZ), or {}.
## Why tries failed, by reason (for checks).
static var why := {}
static func _no(k: String) -> Dictionary:
	why[k] = int(why.get(k,0))+1
	return {}

static func _try(field: RefCounted, p: Vector2, d: Vector2) -> Dictionary:
	var axis := Vector3(d.x,0.0,d.y)
	var across := axis.cross(Vector3.UP).normalized()
	var n := int(STRIP/READ)
	var rows: Array = []
	for l: float in [-LANE_HALF,0.0,LANE_HALF]:
		var hs := PackedFloat32Array()
		hs.resize(n+1)
		for t in n+1:
			var q := Vector3(p.x,0.0,p.y)+axis*(t*READ-STRIP*0.5)+across*l
			var h := float(field.sample(q.x,q.z).x)
			if h-SEA_Y < DRY or float(field.last_river) < DRY+WorldScale.span: return _no("wet")
			if t > 0 and absf(h-hs[t-1]) > STEP_RISE: return _no("step")
			if t > 3 and absf(h-hs[t-4]) > SPAN_RISE: return _no("span")
			hs[t] = h
		rows.append(hs)
	for t in n+1:
		if absf(float(rows[0][t])-float(rows[1][t])) > ACROSS_RISE or absf(float(rows[2][t])-float(rows[1][t])) > ACROSS_RISE: return _no("across")
	var level := float(rows[1][n/2])
	var c := Vector3(p.x,level,p.y)
	# One end open to come in over.
	var ends: Array = []
	for e: float in [1.0,-1.0]:
		var open := true
		var u := APPROACH_FROM
		while u <= APPROACH and open:
			var q := c+axis*e*(STRIP*0.5+u)
			if float(field.height(q.x,q.z))+CLEAR > level+u/GLIDE: open = false
			u += 40.0
		if open: ends.append(e)
	if ends.is_empty(): return _no("approach")
	# The hangar's side: level ground, nothing planted by the strip or it.
	for side: float in [1.0,-1.0]:
		var ok := true
		var shed := c+across*side*SHED_OFF
		for u: float in [-SHED_LONG*0.5,0.0,SHED_LONG*0.5]:
			for v: float in [-SHED_DEEP*0.5,0.0,SHED_DEEP*0.5]:
				var q := shed+axis*u+across*side*v
				var h := float(field.sample(q.x,q.z).x)
				if absf(h-level) > SHED_LEVEL or h-SEA_Y < DRY or float(field.last_river) < DRY: ok = false
		if not ok:
			_no("shed")
			continue
		var acr := across*side
		if not RivalStrip._tree_free(field,c-acr*LANE_HALF,axis,acr,LANE_HALF+SHED_OFF+SHED_DEEP,-STRIP*0.5,STRIP*0.5):
			_no("trees")
			continue
		return {"centre":c,"axis":axis,"side":side,"ends":ends}
	return {}

## The found strip framed and named (the layout file's move over it), or {}
## when the file deletes it.
func _named(key: Vector2i, s: Dictionary) -> Dictionary:
	var name := name_of(key)
	if LayoutOverrides.deleted(name): return {}
	var axis: Vector3 = s.axis
	var across := axis.cross(Vector3.UP).normalized()
	var coded := Transform3D(Basis(across,Vector3.UP,-axis),s.centre)
	var frame := LayoutOverrides.xform(name,coded)
	var ax := -frame.basis.z
	ax = Vector3(ax.x,0.0,ax.z).normalized()
	return {"name":name,"cell":key,"frame":frame,"centre":frame.origin,"axis":ax,"across":ax.cross(Vector3.UP).normalized(),
		"side":float(s.side),"ends":s.ends,"half_len":STRIP*0.5}

## Nothing standing on the strip's lanes or the hangar's ground, as the
## rolling plane meets the land (the game's `_blocked`, `plane_ground`).
func _stands_clear(site: Dictionary) -> bool:
	var field: RefCounted = game.field
	var c: Vector3 = site.centre
	var axis: Vector3 = site.axis
	var across: Vector3 = site.across
	var u := -STRIP*0.5
	while u <= STRIP*0.5+0.1:
		for v: float in [-LANE_HALF,-LANE_HALF*0.5,0.0,LANE_HALF*0.5,LANE_HALF]:
			var q := c+axis*u+across*v
			var h := float(field.height(q.x,q.z))
			if bool(game._blocked(Vector3(q.x,h+1.0,q.z))): return false
			var g: Variant = game.plane_ground(Vector3(q.x,h+60.0,q.z))
			if g is Vector2: return false
			if g != null and float(g) > h+0.5: return false
		u += 8.0
	return true

## Whether `p` (XZ) is on `site`'s strip, as a stop counts.
static func on_strip(site: Dictionary, p: Vector3) -> bool:
	var o := p-(site.centre as Vector3)
	return absf(o.dot(site.across)) <= ON_HALF and absf(o.dot(site.axis)) <= float(site.half_len)+ON_PAST

# --- The shop open ----------------------------------------------------------------------

func _open_or_close() -> void:
	var landing: RefCounted = game.hand_landing
	var stopped: bool = landing.can_exit()
	if view != null:
		# Taking off (Boost rolls it on) leaves the shop.
		if not stopped: close()
		return
	if not stopped:
		_left_on_stop = false
		return
	if _left_on_stop or game.overlay != null or game.stage != null: return
	if game.race != null and String(game.race.state) == "racing": return
	# A beat route's stop is the route's: not while one runs, nor on the stop
	# that ended it (its result shows), and not again until the next stop.
	var beats: Node = game.get("beats")
	if beats != null and (beats.running() or String(beats.state) == "end"):
		_left_on_stop = true
		return
	for key: Vector2i in built:
		var site: Dictionary = cells[key].site
		if on_strip(site,game.plane.position):
			open(key)
			return

## Opens `key`'s shop as the game's overlay.
func open(key: Vector2i) -> void:
	if view != null or game.overlay != null: return
	view_cell = key
	game.book.find(name_of(key))
	view = ShopView.new()
	view.setup(game.book,game.plane_figure,Callable(self,"close"))
	_layer.add_child(view)
	game.overlay = view

## Leaves the shop: the overlay gone, the plane dressed as worn.
func close() -> void:
	if view == null: return
	_left_on_stop = true
	if game.overlay == view: game.overlay = null
	view.queue_free()
	view = null
	ShopStock.dress(game.plane_figure,game.book)

# --- The model --------------------------------------------------------------------------

## The shop at `site`: built from a few boxes, cylinders and cones, each
## part on the land under it.
func _build(key: Vector2i, site: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Shop_%d_%d" % [key.x,key.y]
	add_child(root)
	built[key] = root
	var field: RefCounted = game.field
	var c: Vector3 = site.centre
	var axis: Vector3 = site.axis
	var across: Vector3 = site.across*float(site.side)
	# Faces the strip: local -Z toward it, X along it.
	var shed_at := c+across*SHED_OFF
	shed_at.y = _ground(field,shed_at,SHED_LONG*0.5)
	var shed := Node3D.new()
	shed.name = "Hangar"
	shed.transform = Transform3D(Basis(axis*float(site.side),Vector3.UP,across),shed_at)
	root.add_child(shed)
	var wood := _mat(Color("a8865e"),0.9)
	var plank := _mat(Color("6b4f36"),0.9)
	var roof := _mat(Color("7a3d2c"),0.8)
	var cream := _mat(Color("ece2c8"),0.8)
	var gilt := _mat(Color("d6a84a"),0.5)
	var w := SHED_LONG
	var dp := SHED_DEEP
	var tall := SHED_TALL
	var sunk := 0.6
	# Floor, back wall, two sides; open to the strip.
	_box(shed,Vector3(w,0.3,dp),Vector3(0,0.15-0.1,0),plank)
	_box(shed,Vector3(w,tall+sunk,0.3),Vector3(0,(tall-sunk)*0.5,dp*0.5),wood)
	for s: float in [-1.0,1.0]:
		_box(shed,Vector3(0.3,tall+sunk,dp),Vector3(s*w*0.5,(tall-sunk)*0.5,0),wood)
		# The gable ends' triangles as a squat box under the ridge.
		_box(shed,Vector3(0.3,1.2,dp*0.6),Vector3(s*w*0.5,tall+0.6,0),wood)
	# A pitched roof, its two slopes, past the walls.
	var pitch := 0.42
	for s: float in [-1.0,1.0]:
		var slope := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w+1.2,0.25,dp*0.5/cos(pitch)+0.8)
		slope.mesh = bm
		slope.material_override = roof
		slope.transform = Transform3D(Basis(Vector3.RIGHT,s*pitch),Vector3(0,tall+dp*0.25*tan(pitch)+0.15,s*dp*0.25))
		shed.add_child(slope)
	# The sign over the open front: a gilt board, a cream band.
	_box(shed,Vector3(w*0.62,1.1,0.2),Vector3(0,tall-0.2,-dp*0.5-0.1),gilt)
	_box(shed,Vector3(w*0.62+0.3,0.18,0.24),Vector3(0,tall+0.42,-dp*0.5-0.1),cream)
	# A counter in the mouth, and a few crates.
	_box(shed,Vector3(w*0.5,1.1,0.8),Vector3(-w*0.15,0.55,-dp*0.5+0.9),plank)
	_box(shed,Vector3(1.2,1.2,1.2),Vector3(w*0.3,0.6,-dp*0.1),wood)
	_box(shed,Vector3(0.9,0.9,0.9),Vector3(w*0.36,1.65,-dp*0.1),plank)
	# The mast, its lamp and windsock, at the hangar's far corner.
	var mast_at := c+across*(SHED_OFF-SHED_DEEP*0.5-2.5)+axis*(SHED_LONG*0.5+3.5)
	mast_at.y = _ground(field,mast_at,1.0)
	var mast := Node3D.new()
	mast.name = "Mast"
	mast.position = mast_at
	root.add_child(mast)
	var steel := _mat(Color("d8d2c4"),0.6)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.4
	cm.height = MAST+1.0
	cm.radial_segments = 8
	cm.rings = 1
	pole.mesh = cm
	pole.material_override = steel
	pole.position = Vector3(0,MAST*0.5-0.5,0)
	mast.add_child(pole)
	# Red and white bands up it, to read against the sky.
	var red := _mat(Color("b8342a"),0.7)
	for b in 4:
		var band := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.3
		bc.bottom_radius = 0.33
		bc.height = 2.2
		bc.radial_segments = 8
		bc.rings = 1
		band.mesh = bc
		band.material_override = red
		band.position = Vector3(0,MAST-2.6-b*4.8,0)
		mast.add_child(band)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = LAMP*0.5
	sm.height = LAMP
	sm.radial_segments = 10
	sm.rings = 5
	lamp.mesh = sm
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd36b")
	glow.emission_enabled = true
	glow.emission = Color("ffc65a")
	glow.emission_energy_multiplier = 4.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.material_override = glow
	lamp.position = Vector3(0,MAST+LAMP*0.4,0)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mast.add_child(lamp)
	# The lamp's glint far off: the same few pixels at any distance, fading
	# in past GLINT_FROM m, so the shop is found from far.
	var glint := MeshInstance3D.new()
	glint.name = "Glint"
	var gq := QuadMesh.new()
	gq.size = Vector2(GLINT,GLINT)
	glint.mesh = gq
	glint.material_override = _glint_material()
	glint.position = Vector3(0,MAST+LAMP*0.4,0)
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mast.add_child(glint)
	# A long gilt pennant off the top, red at the hoist, to read from far.
	var flag := MeshInstance3D.new()
	flag.name = "Pennant"
	flag.mesh = _pennant()
	flag.material_override = _pennant_material()
	flag.position = Vector3(0,MAST-0.2,0)
	flag.basis = Basis.looking_at(-axis*float(site.ends[0]),Vector3.UP)*Basis(Vector3.UP,PI*0.5)
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mast.add_child(flag)
	# The sock on its arm: a cone in orange and white bands, along the strip.
	var sock := Node3D.new()
	sock.name = "Sock"
	sock.position = Vector3(0,MAST-1.0,0)
	sock.basis = Basis.looking_at(axis*float(site.ends[0]),Vector3.UP)
	mast.add_child(sock)
	var orange := _mat(Color("e0702a"),0.85)
	var white := _mat(Color("f2ece0"),0.85)
	var long := 6.0
	for b in 4:
		var seg := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		var r0 := lerpf(1.0,0.45,float(b)/4.0)
		var r1 := lerpf(1.0,0.45,float(b+1)/4.0)
		fm.top_radius = r0
		fm.bottom_radius = r1
		fm.height = long/4.0
		fm.radial_segments = 10
		fm.rings = 1
		fm.cap_top = false
		fm.cap_bottom = false
		seg.mesh = fm
		seg.material_override = orange if b % 2 == 0 else white
		# Along local -Z (Basis.looking_at's forward), from the arm out.
		seg.transform = Transform3D(Basis(Vector3.RIGHT,-PI*0.5),Vector3(0,0,-(b+0.5)*long/4.0-0.2))
		sock.add_child(seg)
	# The strip's edge posts, cream with gilt caps, both sides; the ends'
	# all gilt.
	var post := BoxMesh.new()
	post.size = Vector3(0.35,POST,0.35)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.5,0.35,0.5)
	var u := -STRIP*0.5
	var edge := site.across as Vector3
	while u <= STRIP*0.5+0.1:
		var end := absf(absf(u)-STRIP*0.5) < 1.0
		for v: float in [-LANE_HALF-3.0,LANE_HALF+3.0]:
			var q := c+axis*u+edge*v
			q.y = float(field.height(q.x,q.z))
			var m := MeshInstance3D.new()
			m.mesh = post
			m.material_override = gilt if end else cream
			m.position = q+Vector3.UP*(POST*0.5-0.3)
			root.add_child(m)
			var top := MeshInstance3D.new()
			top.mesh = cap
			top.material_override = gilt
			top.position = q+Vector3.UP*(POST-0.15)
			top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(top)
		u += POST_EVERY

## The glint: its size on screen (as seen 1 m off), fading in from
## GLINT_FROM to GLINT_FULL m.
const GLINT := 0.026
const GLINT_FROM := 220.0
const GLINT_FULL := 420.0
static var _glint_mat: StandardMaterial3D

static func _glint_material() -> StandardMaterial3D:
	if _glint_mat != null: return _glint_mat
	var g := Gradient.new()
	g.set_color(0,Color(1.0,0.86,0.5,1.0))
	g.set_color(1,Color(1.0,0.78,0.35,0.0))
	g.add_point(0.35,Color(1.0,0.84,0.45,0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.fixed_size = true
	m.no_depth_test = false
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = GLINT_FROM
	m.distance_fade_max_distance = GLINT_FULL
	_glint_mat = m
	return m

## The pennant: PENNANT m long (+X), tapering from PENNANT_DEEP at the
## hoist to a point, hanging down from y 0.
const PENNANT := 10.0
const PENNANT_DEEP := 3.4
static var _pennant_mesh: ArrayMesh
static var _pennant_shader: Shader
const PENNANT_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 hoist : source_color = vec4(0.72,0.2,0.16,1.0);
uniform vec4 fly : source_color = vec4(1.0,0.83,0.42,1.0);
varying float u;
void vertex() {
	u = UV.x;
	VERTEX.z += sin(TIME*3.1-u*5.0)*0.45*u+sin(TIME*5.3-u*9.0)*0.12*u;
	VERTEX.y -= u*u*0.6;
}
void fragment() {
	ALBEDO = u < 0.22 ? hoist.rgb : fly.rgb;
	ROUGHNESS = 0.85;
	EMISSION = ALBEDO*0.18;
}
"""

static func _pennant() -> ArrayMesh:
	if _pennant_mesh != null: return _pennant_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for i in n:
		var u0 := float(i)/n
		var u1 := float(i+1)/n
		var d0 := PENNANT_DEEP*(1.0-u0)
		var d1 := PENNANT_DEEP*(1.0-u1)
		var a := Vector3(u0*PENNANT,0,0)
		var b := Vector3(u1*PENNANT,0,0)
		for v: Array in [[a,u0],[b,u1],[b+Vector3(0,-d1,0),u1],[a,u0],[b+Vector3(0,-d1,0),u1],[a+Vector3(0,-d0,0),u0]]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(v[1],0.0))
			st.add_vertex(v[0])
	_pennant_mesh = st.commit()
	return _pennant_mesh

static func _pennant_material() -> ShaderMaterial:
	if _pennant_shader == null:
		_pennant_shader = Shader.new()
		_pennant_shader.code = PENNANT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _pennant_shader
	return m

## The lowest land over a square of half-side `r` at `p` (so nothing floats).
static func _ground(field: RefCounted, p: Vector3, r: float) -> float:
	var lo := INF
	for dx: float in [-r,0.0,r]:
		for dz: float in [-r,0.0,r]:
			lo = minf(lo,float(field.height(p.x+dx,p.z+dz)))
	return lo

func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m

## Paint lit as the plane's and the ruins' are (PlaneFigure `_paint`: the
## sky's hemisphere as fill, so the shade side is not black).
static func _mat(col: Color, _rough: float) -> Material:
	return PlaneFigure._paint(col)

## The windsock's lazy swing in the still air.
func _sway(root: Node3D) -> void:
	var sock := root.get_node_or_null("Mast/Sock") as Node3D
	if sock == null: return
	if not sock.has_meta("rest"): sock.set_meta("rest",sock.basis)
	var rest: Basis = sock.get_meta("rest")
	sock.basis = rest*Basis(Vector3.UP,sin(_sock_t*0.7)*0.12)*Basis(Vector3.RIGHT,-0.35+sin(_sock_t*1.3)*0.05)

func _free(key: Vector2i) -> void:
	if not built.has(key): return
	if view != null and view_cell == key: close()
	(built[key] as Node).queue_free()
	built.erase(key)
