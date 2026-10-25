extends Node
## The layer's roaming Olmec (docs/design/roguelike/olmec-threat-round1.md),
## a child of the generator's enemies (scripts/roguelike/layer_enemies.gd),
## on underground layers unless `--knob=olmecs=places`. One head a layer
## (two high up, LayerEnemies ROAM_TWO), its body coming up the cliffs for
## it (scripts/enemies/body_spawner.gd: mostly a far climb in view, the
## main entrance, LayerBodies ROAM_SPAWN). This node:
##   - hands every Olmec the layer's breakables hub (scripts/kit_isle/
##     breakables.gd; the places' Keepers did, and they are gone) and the
##     masonry breaker (scripts/enemies/olmec_breach.gd), and puts the hub's
##     quake on the camera;
##   - the head going on (`reunited`): the beat. A slow-motion beat, a roar
##     heard across the layer, a ring off his feet, the camera's quake, a
##     line on the screen; then he knows where you are (the body's
##     `relentless`);
##   - his weight (`weighed`): the stone under him tips (scripts/enemies/
##     olmec_tilt.gd), and leans while he stands out on it;
##   - spans: whole and hunting, the crossings' stone under him cracks and
##     goes (OlmecBreach `crack_under`);
##   - travel: whole and hunting, you gone where he can't follow (out of
##     his sight TRAVEL_UNSEEN s and TRAVEL_FAR m off, or stuck), he goes
##     down into the dark (out of view he is simply gone; in view near a
##     rim he leaps off it), and TRAVEL_T s on comes up a cliff of the isle
##     you're on, starting down its face so you see him climb (a rumble,
##     dust at each hold), hauls over, the stone tipping, and hunts on.
##     A fall into the void (a span gone under him) is a travel too.
## Keys (dev): O, the Olmec now (headless: a far climb if one is in view,
## else one up a near cliff; whole: up a cliff of your isle); Shift+O, his
## head put on now (the beat).

const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
const OlmecBreach = preload("res://scripts/enemies/olmec_breach.gd")
const OlmecTilt = preload("res://scripts/enemies/olmec_tilt.gd")
const OlmecVoid = preload("res://scripts/enemies/olmec_void.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")

## Travel: you unseen this long (s) and this far off (m, flat; or this far
## over or under him), or him stuck in a STUCK_BOX m box this long (s).
const TRAVEL_UNSEEN := 7.0
const TRAVEL_FAR := 34.0
const TRAVEL_RISE := 14.0
const STUCK_FOR := 9.0
const STUCK_BOX := 3.0
## Gone this long (s, by your distance from where he went: TRAVEL_T.x at
## 0, +1 s a TRAVEL_PACE m, at most TRAVEL_T.y), then up a cliff.
const TRAVEL_T := Vector2(6.0,16.0)
const TRAVEL_PACE := 14.0
## In view at the trigger: he leaps off a rim within LEAP_RIM m; he's
## given IN_VIEW_MOST s to get out of view (or off) before he goes anyway.
const LEAP_RIM := 9.0
const IN_VIEW_MOST := 10.0
## Under this far below where he left (m), falling, he's away.
const AWAY_DOWN := 22.0
## His cliff up your isle: a rim RIM_NEAR..RIM_FAR m from you (flat),
## found by rays marched out RIM_DIRS ways from your feet; its face climbed
## from up to RIM_CLIMB m down it.
const RIM_NEAR := 16.0
const RIM_FAR := 48.0
const RIM_DIRS := 20
const RIM_STEP := 2.0
const RIM_CLIMB := 9.0
## No rim found: tried again this often (s); one you'll see wanted for the
## first SEEN_TRIES tries.
const RIM_AGAIN := 2.0
const SEEN_TRIES := 3
## A clean face: nothing under these (m) out from the lip down his hang.
const CLEAN_OUT := [0.5,1.2,2.2]
const CLEAN_IN := 1.4
## Room to haul onto: level ground (within ROOM_LEVEL m of the lip) behind
## the lip his body's length deep and his breadth wide, so a pier top, a
## crossing's stone or a causeway's deck is never a cliff of his.
const ROOM_LEVEL := 1.5
## A fall within BAN_AFTER s of coming up a lip bans cliffs within BAN_NEAR
## m of it for the rest of the layer.
const BAN_AFTER := 25.0
const BAN_NEAR := 10.0
## The lip his climb finds no more than this off the cliff's top (m).
const SHELF_LEVEL := 1.0
## A rim on screen this share in from its edges counts as seen.
const SEEN_EDGE := 0.04
## Entrances: the first after this long on the layer, again this long after
## a body is lost (s); you within ENTER_REACH m of the head; the cliff
## ENTER_NEAR..ENTER_FAR m from the head; one you see wanted for
## ENTER_PICKY s; looked for every ENTER_EVERY s.
const ENTER_FIRST := 12.0
const ENTER_AGAIN := 8.0
const ENTER_REACH := 320.0
const ENTER_NEAR := 4.0
const ENTER_FAR := 70.0
const ENTER_PICKY := 20.0
const ENTER_EVERY := 0.5
## No rim off the head's own top: the tops round it WIDE_RINGS m off (in
## WIDE_WAYS ways, WIDE_UP over to WIDE_DOWN under its height), each
## marched from WIDE_DIRS ways; that wide look at most every WIDE_AGAIN s.
const WIDE_RINGS := [22.0,36.0,52.0]
const WIDE_WAYS := 8
const WIDE_UP := 10.0
const WIDE_DOWN := 25.0
const WIDE_DIRS := 10
const WIDE_AGAIN := 4.0
## Nothing clean and no planned cliff this long past the picky spell (s):
## a stepped face.
const ENTER_LAX := 10.0
## Spans: standing on the crossings' stone this long (s) hunting, it cracks.
const SPAN_ON := 0.35
## The head-on beat: slow motion (time scale, real s), the roar's ring.
const BEAT_SCALE := 0.3
const BEAT_FOR := 0.7
const BEAT_SHOCK := 1.1
const LINE := "He has his head."
const LINE_FOR := 3.5

var lay: Node = null
var stage: Node3D = null
var study: Node3D = null
var field: Node = null
var hub: Node3D = null
var breach: Node3D = null
var tilt: Node = null
## Per body (by instance id): {body, at (stuck watch), stuck, unseen, view,
## left (where he left), span}.
var _watch := {}
## Away bodies: [{body, head, from (where he left), t, due, tries}].
var away: Array = []
## Counted, for checks.
var travels := 0
var leaps_off := 0
var comebacks := 0
var beats := 0
var tilts := 0
var last_travel := ""
var last_comeback := Vector3.INF
var last_out := Vector2.ZERO
var last_below := 0.0
var entrances := 0
## Why the last `seen_rim` said no (for checks).
var seen_why := ""
var entrances_seen := 0
var _clock := 0.0
var _bodiless := {}
var _enter_t := 0.0
var _wide_ready := 0.0
var _lax := false
var _banned: Array = []
var _up_at := -INF
var _build := {}
## The comeback's cliffs no more than this over or under your feet (m):
## past TRAVEL_RISE he'd count you out of reach and leave at once.
var max_rise := INF
var _beat_t := -1.0
var _was_scale := 1.0
var _line: Label = null
var _line_t := 0.0
var _quake := 0.0

## The director for `lay` (LayerEnemies) on `owner_stage`.
static func dress(owner_lay: Node, owner_stage: Node3D, _plan: Dictionary) -> Node:
	var node := new()
	node.name = "LayerOlmec"
	owner_lay.add_child(node)
	node.build(owner_lay,owner_stage)
	return node

func build(owner_lay: Node, owner_stage: Node3D) -> void:
	lay = owner_lay
	stage = owner_stage
	study = owner_stage.get("study")
	field = owner_stage.get("enemies")
	hub = Breakables.new()
	hub.name = "Breakables"
	hub.field = field
	hub.sound_hook = Callable(lay,"_voice")
	add_child(hub)
	breach = OlmecBreach.new()
	breach.field = field
	breach.hub = hub
	breach.spans = owner_stage.get("stones")
	add_child(breach)
	tilt = OlmecTilt.new()
	tilt.field = field
	tilt.study = study
	tilt.never = [owner_stage,field]
	tilt.riders = _riders
	add_child(tilt)
	var hud := CanvasLayer.new()
	hud.layer = 6
	add_child(hud)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size",30)
	_line.add_theme_color_override("font_color",Color("f3e6c8"))
	_line.add_theme_color_override("font_shadow_color",Color(0,0,0,0.85))
	_line.add_theme_constant_override("shadow_offset_x",2)
	_line.add_theme_constant_override("shadow_offset_y",2)
	_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_line.offset_top = 120.0
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_line.visible = false
	hud.add_child(_line)

func _exit_tree() -> void:
	if _beat_t >= 0.0: Engine.time_scale = 1.0
	if tilt != null: tilt.settle_all()
	for a: Dictionary in away:
		for n: Variant in [a.body,a.head]:
			if n is Node and is_instance_valid(n) and not (n as Node).is_inside_tree(): (n as Node).free()
	away.clear()

## The Olmecs in the field now.
func bodies() -> Array:
	var out: Array = []
	if field == null: return out
	for e in field.enemies:
		if is_instance_valid(e) and e is HeadlessBody and not e.gone: out.append(e)
	return out

# --- A frame --------------------------------------------------------------------------

func before(delta: float) -> void:
	if field == null: return
	var real := delta/maxf(Engine.time_scale,0.01)
	_beat_step(real)
	var list := bodies()
	for b: Node3D in list:
		_hook(b)
		_travel_watch(b,delta)
		_span_watch(b,delta)
	_away_step(delta)
	_entrances(delta)
	tilt.step(delta,list)

## The camera placed: the hub's quake and the beat's.
func frame(camera: Camera3D, delta: float) -> void:
	_quake = maxf(0.0,_quake-delta*1.4)
	if _line != null and _line.visible:
		_line_t -= delta
		_line.modulate.a = clampf(_line_t/0.8,0.0,1.0)
		if _line_t <= 0.0: _line.visible = false
	var q := maxf(_quake,float(hub.quake) if hub != null else 0.0)
	if camera == null or q < 0.001: return
	var t := Time.get_ticks_msec()/1000.0
	camera.position += Vector3(sin(t*59.0),sin(t*51.0+1.0),sin(t*43.0+2.0))*q*0.35

## A body seen for the first time: its breaker, breacher, signals.
func _hook(b: Node3D) -> void:
	var key := b.get_instance_id()
	if _watch.has(key): return
	_watch[key] = {"body":b,"at":b.position,"stuck":0.0,"unseen":0.0,"view":0.0,"left":Vector3.INF,"span":0.0,"going":false}
	if b.get("breaker") == null: b.breaker = hub
	b.breacher = breach
	if not b.reunited.is_connected(_on_whole): b.reunited.connect(_on_whole)
	if not b.weighed.is_connected(_on_weight): b.weighed.connect(_on_weight.bind(b))

# --- The head going on ------------------------------------------------------------------

func _on_whole(b: Node3D) -> void:
	beats += 1
	field.sound(&"olmec_roar",b.position+Vector3.UP*float(b.neck_h))
	field.sound(&"body_rumble",b.position)
	# A ring off his feet (a walker near is thrown), the stone tipping.
	b._shock(b.position,BEAT_SHOCK)
	b.quake = maxf(float(b.quake),1.0)
	_quake = maxf(_quake,0.55)
	Dust.plume(field,b.position,float(b.hh)*3.0)
	if tilt != null: tilt.weigh(b,b.position,0.8)
	_was_scale = Engine.time_scale if _beat_t < 0.0 else _was_scale
	Engine.time_scale = BEAT_SCALE
	_beat_t = BEAT_FOR
	if _line != null:
		_line.text = LINE
		_line.visible = true
		_line_t = LINE_FOR

func _beat_step(real: float) -> void:
	if _beat_t < 0.0: return
	_beat_t -= real
	if _beat_t <= 0.0:
		_beat_t = -1.0
		Engine.time_scale = 1.0

# --- His weight -------------------------------------------------------------------------

## What rides a tipping stone `node` (its meshes' box `box`): the live host
## of a place (scripts/roguelike/layer_greybox.gd `Isle`) when the stone is
## most of that place, so its fires and lamps go over with it.
func _riders(_node: Node3D, box: AABB) -> Array:
	var out: Array = []
	var gb: Node = stage.get("greybox")
	if gb == null: return out
	var flat := Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
	for h: Node3D in gb.get("hosts"):
		var r: Rect2 = h.get("rect")
		if r.get_area() <= 0.0: continue
		if flat.intersection(r).get_area() >= r.get_area()*0.6: out.append(h)
	return out

func _on_weight(at: Vector3, power: float, kind: String, b: Node3D) -> void:
	if tilt == null: return
	var t: Variant = tilt.weigh(b,at,power*(1.2 if kind == "land" else 1.0))
	if t != null: tilts += 1
	_quake = maxf(_quake,0.15+0.2*power)

# --- Spans ------------------------------------------------------------------------------

func _span_watch(b: Node3D, delta: float) -> void:
	if not _watch.has(b.get_instance_id()) or not field.enemies.has(b): return
	var w: Dictionary = _watch[b.get_instance_id()]
	if not (bool(b.whole) and bool(b.hunting)) or not bool(b.grounded) or breach == null:
		w.span = 0.0
		return
	# Checked a few times a second.
	w.span = float(w.span)+delta
	if float(w.span) < SPAN_ON: return
	w.span = 0.0
	if breach.on_span(b): breach.crack_under(b)

# --- Travel -----------------------------------------------------------------------------

func _travel_watch(b: Node3D, delta: float) -> void:
	var w: Dictionary = _watch[b.get_instance_id()]
	if not bool(b.whole): return
	var m: PilotMotor = study.motor
	# Fallen (a span gone, a leap off): away under AWAY_DOWN.
	if str(b.state) in ["fall","leap"] and not bool(b.grounded):
		var from: Vector3 = w.left if w.left != Vector3.INF else w.at
		var sp: Node = lay.get("spawner")
		var low := maxf(float(field.lost),float(sp.lost_y) if sp != null else -INF)
		if b.position.y < from.y-AWAY_DOWN or b.position.y < low+30.0:
			_send_away(b,"fell" if not bool(w.going) else "leapt off")
		return
	w.left = b.position
	if not bool(b.hunting): return
	var to := m.feet-b.position
	var far := Vector2(to.x,to.z).length() > TRAVEL_FAR or absf(to.y) > TRAVEL_RISE
	var seeing: bool = b.sight != null and b.sight.seeing()
	w.unseen = 0.0 if seeing else float(w.unseen)+delta
	if (b.position-(w.at as Vector3)).length() > STUCK_BOX:
		w.at = b.position
		w.stuck = 0.0
	else: w.stuck = float(w.stuck)+delta
	var go := (far and float(w.unseen) > TRAVEL_UNSEEN) or (float(w.stuck) > STUCK_FOR and not seeing and far)
	if not go:
		w.view = 0.0
		return
	if bool(w.going): return
	# Out of view: simply gone (into the dark under the isle).
	if not _in_view(b):
		_send_away(b,"out of view")
		return
	w.view = float(w.view)+delta
	if str(b.state) in ["chase","seek","listen","roam","return"]:
		var rim: Array = OlmecVoid.nearest(field,b.position)
		if float(rim[1]) <= LEAP_RIM:
			_leap_off(b,rim[0])
			w.going = true
			return
	if float(w.view) > IN_VIEW_MOST: _send_away(b,"in view, no rim")

## He leaps off the rim along `way` (x, z) into the dark.
func _leap_off(b: Node3D, way: Vector2) -> void:
	leaps_off += 1
	var w3 := Vector3(way.x,0.0,way.y)
	b.facing = PilotMotor.facing_of(way)
	b._leap_to = b.position+w3*(float(b.length)+10.0)-Vector3.UP*60.0
	b.leap_kind = "drop"
	b._route = []
	b._search = null
	b._go("windup")
	field.sound(&"body_windup",b.position)

func _in_view(b: Node3D) -> bool:
	var camera: Camera3D = study.get("camera")
	if camera == null: return false
	for p: Vector3 in [b.position+Vector3.UP*float(b.neck_h)*0.5,b.position+Vector3.UP*float(b.neck_h)]:
		if camera.is_position_in_frustum(p) and camera.global_position.distance_to(p) < 260.0: return true
	return false

## `b` (and his head) out of the field, to come back up a cliff.
func _send_away(b: Node3D, why: String) -> void:
	travels += 1
	last_travel = why
	var h: Node3D = b.head if b.head != null and is_instance_valid(b.head) and b.head.perch == b else null
	var m: PilotMotor = study.motor
	var w: Dictionary = _watch.get(b.get_instance_id(),{})
	var from: Vector3 = w.get("left",b.position) if w.get("left",Vector3.INF) != Vector3.INF else b.position
	var flat := Vector2(m.feet.x-from.x,m.feet.z-from.z).length()
	var due := minf(TRAVEL_T.x+flat/TRAVEL_PACE,TRAVEL_T.y)
	for n: Node3D in [b,h]:
		if n == null: continue
		field.enemies.erase(n)
		if n.get_parent() == field: field.remove_child(n)
	_watch.erase(b.get_instance_id())
	if why == "fell" and last_comeback != Vector3.INF and _now()-_up_at < BAN_AFTER:
		_banned.append(last_comeback)
		print("olmec: fell soon after coming up at %s; that cliff is banned" % str(last_comeback.round()))
	away.append({"body":b,"head":h,"from":from,"t":0.0,"due":due,"tries":0})
	print("olmec: away (%s), back in %.0f s" % [why,due])

func _away_step(delta: float) -> void:
	if away.is_empty(): return
	var keep: Array = []
	for a: Dictionary in away:
		a.t = float(a.t)+delta
		if float(a.t) < float(a.due) or not _back(a): keep.append(a)
	away = keep

## Away body `a` brought up a cliff of the walker's isle; false: no cliff
## yet (tried again RIM_AGAIN s on).
func _back(a: Dictionary) -> bool:
	var b: Node3D = a.body
	if not is_instance_valid(b): return true
	var m: PilotMotor = study.motor
	if not m.grounded or m.seized():
		a.due = float(a.t)+0.5
		return false
	# Seen first, then any clean face (round you too), then a stepped one.
	var tries := int(a.tries)
	_lax = tries >= SEEN_TRIES+3
	max_rise = TRAVEL_RISE-2.0
	var rim := find_rim(m.feet,RIM_NEAR,RIM_FAR,-1.0,tries < SEEN_TRIES,tries >= SEEN_TRIES)
	max_rise = INF
	_lax = false
	if rim.is_empty():
		a.tries = int(a.tries)+1
		a.due = float(a.t)+RIM_AGAIN
		return false
	_bring(b,a.head,rim)
	return true

## Body `b` (head `h`) up `rim` ({lip, out, below, seen}) now, hunting.
func _bring(b: Node3D, h: Node3D, rim: Dictionary) -> void:
	var at := 0
	if h != null and field.enemies.has(h): at = field.enemies.find(h)
	if b.get_parent() == null: field.add_child(b)
	field.enemies.insert(at,b)
	if h != null:
		if h.get_parent() == null: field.add_child(h)
		if not field.enemies.has(h): field.enemies.insert(at+1,h)
	b.gone = false
	b.cling(rim.lip,rim.out,float(rim.below),true)
	b.body.force_update_transform()
	b._wake_hunt()
	b._go("climb")
	comebacks += 1
	last_comeback = rim.lip
	last_out = rim.out
	last_below = float(rim.below)
	_up_at = _now()
	field.sound(&"body_rumble",rim.lip)
	print("olmec: back up a cliff at %s (%.0f m off, %.0f m down the face%s)" % [str((rim.lip as Vector3).round()),
		Vector2((rim.lip as Vector3).x-study.motor.feet.x,(rim.lip as Vector3).z-study.motor.feet.z).length(),float(rim.below)," in view" if bool(rim.seen) else ""])

## A cliff for him to come up near `around` (on an isle's top): rims
## marched out RIM_DIRS ways from it, `near`..`far` m off (flat), fitted to
## the face (BodySpawner `fit`); scored by how near `ideal` m off it is and
## how far it is from your level, and first by whether you'll see it
## (on screen, the line to it clear): {lip, out, below, seen} or {}.
## `need_seen`: none unless seen.
func find_rim(around: Vector3, near := RIM_NEAR, far := RIM_FAR, ideal := -1.0, need_seen := false, wide := false) -> Dictionary:
	var sp: Node = lay.get("spawner")
	if sp == null: return {}
	if ideal < 0.0: ideal = (near+far)*0.45
	var best := _rims_from(around,around,near,far,ideal,need_seen,RIM_DIRS,0.0)
	if not best.is_empty() or not wide: return best
	# None off its own top (a cap with no face to climb): the tops round
	# it, WIDE_RINGS m off, about its height, each marched from.
	var best_score := INF
	for r: float in WIDE_RINGS:
		for k in WIDE_WAYS:
			var w := Vector2.from_angle(TAU*k/WIDE_WAYS)
			var p := around+Vector3(w.x,0.0,w.y)*r
			var g: float = field.floor_under(Vector3(p.x,around.y+WIDE_UP,p.z),0.0,WIDE_UP+WIDE_DOWN)
			if g == -INF: continue
			var got := _rims_from(Vector3(p.x,g,p.z),around,0.0,far*0.6,ideal,need_seen,WIDE_DIRS,r)
			if got.is_empty(): continue
			if float(got.score) < best_score:
				best_score = float(got.score)
				best = got
	return best

## Rims marched out `dirs` ways from `start`, scored off `around`.
func _rims_from(start: Vector3, around: Vector3, near: float, far: float, ideal: float, need_seen: bool, dirs: int, extra: float) -> Dictionary:
	var sp: Node = lay.get("spawner")
	var hang: float = sp.hang()
	var feet: Vector3 = study.motor.feet
	var cands: Array = []
	for i in dirs:
		var w := Vector2.from_angle(TAU*i/dirs+0.13)
		var w3 := Vector3(w.x,0.0,w.y)
		var last := start
		var d := RIM_STEP
		var lip := Vector3.INF
		while d <= far:
			var p := start+w3*d
			var g: float = field.floor_under(Vector3(p.x,last.y,p.z),3.0,hang+2.0)
			if g == -INF:
				lip = last
				break
			if g > last.y+2.5: break
			last = Vector3(p.x,g,p.z)
			d += RIM_STEP
		if lip == Vector3.INF: continue
		var flat := Vector2(lip.x-around.x,lip.z-around.z).length()
		if flat < near or Vector2(lip.x-start.x,lip.z-start.z).length() < near: continue
		var fitted: Array = sp.fit(lip,w)
		if fitted.is_empty(): continue
		var at: Vector3 = fitted[0]
		var out: Vector2 = fitted[1]
		if not _room(at,out) or _is_banned(at): continue
		if not _lax and not _clean_face(at,out,hang): continue
		var seen := seen_rim(at,out)
		if need_seen and not seen: continue
		if absf(at.y-feet.y) > max_rise: continue
		var score := absf(flat-ideal)+(0.0 if seen else 200.0)+absf(at.y-feet.y)*0.5+extra
		cands.append({"lip":at,"out":out,"below":0.0,"seen":seen,"score":score})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) < float(b.score))
	# The best whose climb his own rays would make: started down the face
	# if that holds, else at the lip.
	for c: Dictionary in cands:
		var below: float = sp.face_below(c.lip,c.out,RIM_CLIMB)
		for bl: float in ([below,0.0] if below > 0.0 else [0.0]):
			if _climb_ok(c.lip,c.out,bl):
				c.below = bl
				return c
	return {}

## Whether there's level ground behind the lip `at` (its face out `out`)
## for his body to haul onto: his length deep, his breadth wide.
func _room(at: Vector3, out: Vector2) -> bool:
	if _build.is_empty():
		var sp: Node = lay.get("spawner")
		_build = HeadlessBody.build_of(sp._body_k(),float(field.numbers().unit))
	var f3 := Vector3(out.x,0.0,out.y).normalized()
	var side := Vector3(-f3.z,0.0,f3.x)
	var deep := float(_build.length)
	var half := float(_build.width)*0.5
	var spans: Node = breach.get("spans") if breach != null else null
	var space := study.get_world_3d().direct_space_state
	var mask: int = WalkerOnly.strip(study.ground.mask)
	for d: float in [1.0,deep*0.5,deep+1.0]:
		for s: float in [-half,0.0,half]:
			var p := at-f3*d+side*s
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*ROOM_LEVEL,p-Vector3.UP*ROOM_LEVEL,mask))
			if hit.is_empty(): return false
			# A crossing's stone (a causeway's deck, a pier) is no cliff
			# top: it cracks under him (olmec_breach.gd `on_span`).
			if spans != null and is_instance_valid(spans) and hit.collider is Node and spans.is_ancestor_of(hit.collider): return false
	return true

## Whether his climb from `below` m down the face under the lip `at` (out
## `out`) would hold, by the climb's own rays (headless_body.gd `_climb`):
## the face before his chest all the way up till his reach finds the lip,
## and room over the lip for him to haul into.
func _climb_ok(at: Vector3, out: Vector2, below: float) -> bool:
	if _build.is_empty(): _room(at,out)
	var k: Dictionary = (lay.get("spawner") as Node)._body_k()
	var n3 := Vector3(out.x,0.0,out.y).normalized()
	var half := float(_build.length)*0.5+float(k.standoff)
	var neck := float(_build.neck)
	var reach := neck+float(_build.arm)*0.75
	var space := study.get_world_3d().direct_space_state
	var mask: int = WalkerOnly.strip(study.ground.mask)
	# What his own rays skip (headless_body.gd `_skip`): bodies, and the
	# standing masonry he'd break through.
	var skip: Array[RID] = []
	for e in field.enemies:
		if is_instance_valid(e) and e.get("body") != null: skip.append(e.body.get_rid())
	if hub != null and hub.has_method("standing_rids"): skip.append_array(hub.standing_rids())
	var ray := func(from: Vector3, to: Vector3) -> Dictionary:
		var q := PhysicsRayQueryParameters3D.create(from,to,mask)
		q.exclude = skip
		return space.intersect_ray(q)
	var pos := Vector3(at.x,at.y-float(_build.hang)-below,at.z)+n3*half
	var from := pos.y
	while pos.y-from <= float(k.climb_max):
		var chest := pos+Vector3.UP*neck*0.55
		var hit: Dictionary = ray.call(chest,chest-n3*(half+1.5))
		var wall := not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7
		var face := chest-n3*half
		if wall:
			face = hit.position as Vector3
			pos = Vector3(face.x,pos.y,face.z)+n3*half
		var past := face-n3*float(k.lip_in)
		var lip: Dictionary = ray.call(Vector3(past.x,pos.y+reach,past.z),Vector3(past.x,pos.y+float(k.step),past.z))
		if not lip.is_empty() and (lip.normal as Vector3).y > 0.6:
			# The lip his hands find: the top itself (not a shelf under it
			# he'd haul onto and stand on, under the rim), with room over it.
			var l := lip.position as Vector3
			if absf(l.y-at.y) > SHELF_LEVEL: return false
			return (ray.call(l+Vector3.UP*0.1,l+Vector3.UP*neck*0.5) as Dictionary).is_empty()
		if not wall: return false
		pos.y += 0.5
	return false

func _is_banned(at: Vector3) -> bool:
	for b: Vector3 in _banned:
		if b.distance_to(at) < BAN_NEAR: return true
	return false

func _now() -> float:
	return Time.get_ticks_msec()*0.001

## Whether the face under `at` (out `out`) is clean down past his hang: no
## ledge or shelf just out from it he would mantle onto halfway (he'd stand
## there, under the rim).
func _clean_face(at: Vector3, out: Vector2, hang: float) -> bool:
	var f3 := Vector3(out.x,0.0,out.y)
	for d: float in CLEAN_OUT:
		var p := at+f3*d
		if field.floor_under(p-Vector3.UP*1.0,0.0,hang+2.0) != -INF: return false
	# Not undercut: the face down his hang no more than CLEAN_IN in under
	# the lip (a recess hides a shelf his hands would find first).
	var space := study.get_world_3d().direct_space_state
	var mask: int = WalkerOnly.strip(study.ground.mask)
	var depth := 2.0
	while depth <= hang:
		var y := at-Vector3.UP*depth
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(y+f3*3.0,y-f3*(CLEAN_IN+0.5),mask))
		if hit.is_empty() or ((hit.position as Vector3)-at).dot(f3) < -CLEAN_IN: return false
		depth += 2.0
	return true

## Whether you'd see him come over the lip at `at` (its face out `out`):
## the face turned to the camera, his shoulders over the lip on screen
## (SEEN_EDGE in from its edges) with a clear line to them.
func seen_rim(at: Vector3, out: Vector2) -> bool:
	var camera: Camera3D = study.get("camera")
	if camera == null: return false
	var cp := camera.global_position
	seen_why = "facing"
	if out.dot(Vector2(cp.x-at.x,cp.z-at.z).normalized()) < 0.1: return false
	var p := at+Vector3(out.x,0.0,out.y)*0.6+Vector3.UP*1.6
	seen_why = "frustum"
	if not camera.is_position_in_frustum(p): return false
	var uv := camera.unproject_position(p)/camera.get_viewport().get_visible_rect().size
	seen_why = "edge"
	if uv.x < SEEN_EDGE or uv.x > 1.0-SEEN_EDGE or uv.y < SEEN_EDGE or uv.y > 1.0-SEEN_EDGE: return false
	var q := PhysicsRayQueryParameters3D.create(cp,p,WalkerOnly.strip(study.ground.mask))
	var hit := study.get_world_3d().direct_space_state.intersect_ray(q)
	seen_why = "" if hit.is_empty() else "line: %s at %s" % [str((hit.collider as Node).name) if hit.collider is Node else "?",str((hit.position as Vector3).round())]
	return hit.is_empty()

# --- Entrances (headless) ---------------------------------------------------------------

## Head `i` bodiless: its body brought up a cliff by its isle, one you see
## if one can be found (the far climb, the main entrance), after
## ENTER_FIRST s on the layer (ENTER_AGAIN after a body is lost), you
## within ENTER_REACH m of the head; seen only for ENTER_PICKY s.
func _entrances(delta: float) -> void:
	var sp: Node = lay.get("spawner")
	if sp == null: return
	_clock += delta
	for i in range(sp.heads.size()):
		var h: Node3D = sp.head_of(i)
		if h == null or sp.body_of(i) != null or _away_head(h):
			_bodiless.erase(i)
			continue
		var t := float(_bodiless.get(i,0.0))+delta
		_bodiless[i] = t
		var due := ENTER_FIRST if entrances == 0 else ENTER_AGAIN
		if _clock < due or t < minf(due,ENTER_AGAIN): continue
		var home: Vector3 = h.home()
		var feet: Vector3 = study.motor.feet
		if Vector2(home.x-feet.x,home.z-feet.z).length() > ENTER_REACH: continue
		_enter_t += delta
		if _enter_t < ENTER_EVERY: continue
		_enter_t = 0.0
		var picky := t < ENTER_PICKY+due
		var rim := find_rim(home,ENTER_NEAR,ENTER_FAR,ENTER_NEAR+4.0,picky,_clock >= _wide_ready)
		if rim.is_empty():
			_wide_ready = _clock+WIDE_AGAIN
			# None clean of its own: past the picky spell, the plan's
			# cliffs that reach the head (layer_bodies.gd), far first.
			if not picky:
				var b: Node3D = sp.spawn_far_now(i)
				if b == null: b = sp.spawn_on_demand(i)
				if b != null:
					entrances += 1
					_bodiless.erase(i)
					print("olmec: up a planned cliff (%s, %.0f m off you)" % [str(sp.last_cliff),float(sp.last_far)])
				elif t > due+ENTER_PICKY+ENTER_LAX:
					# Last: a stepped face (he may stop on its ledge and
					# climb on from there).
					_lax = true
					rim = find_rim(home,ENTER_NEAR,ENTER_FAR,ENTER_NEAR+4.0,false,true)
					_lax = false
					if not rim.is_empty():
						enter(i,rim)
			continue
		enter(i,rim)

func _away_head(h: Node3D) -> bool:
	for a: Dictionary in away:
		if a.head == h: return true
	return false

## Head `i`'s body up `rim` now.
func enter(i: int, rim: Dictionary) -> Node3D:
	var sp: Node = lay.get("spawner")
	var b: Node3D = sp.spawn_fitted(i,rim.lip,rim.out,float(rim.below),true)
	if b == null: return null
	entrances += 1
	if bool(rim.seen): entrances_seen += 1
	last_comeback = rim.lip
	_up_at = _now()
	_bodiless.erase(i)
	var feet: Vector3 = study.motor.feet
	print("olmec: up a cliff by his head at %s (%.0f m off you, %.0f m down the face%s)" % [str((rim.lip as Vector3).round()),
		Vector2((rim.lip as Vector3).x-feet.x,(rim.lip as Vector3).z-feet.z).length(),float(rim.below)," in view" if bool(rim.seen) else ""])
	return b

# --- Dev keys ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var key := event as InputEventKey
	if key.keycode != KEY_O: return
	get_viewport().set_input_as_handled()
	if key.shift_pressed: whole_now()
	else: come_now()

## O: the Olmec now.
func come_now() -> String:
	for a: Dictionary in away:
		a.due = 0.0
		return "away: back now"
	for b: Node3D in bodies():
		if bool(b.whole):
			_send_away(b,"asked")
			away[away.size()-1].due = 0.0
			return "whole: up your isle"
	var sp: Node = lay.get("spawner")
	if sp == null or sp.heads.is_empty() or sp.head_of(0) == null: return "no heads"
	var home: Vector3 = sp.head_of(0).home()
	var rim := find_rim(home,ENTER_NEAR,ENTER_FAR,ENTER_NEAR+4.0,false,true)
	if not rim.is_empty() and enter(0,rim) != null: return "climb by his head (%s)" % ("in view" if bool(rim.seen) else "unseen")
	if sp.spawn_on_demand(0) != null: return "near climb"
	_lax = true
	rim = find_rim(home,ENTER_NEAR,ENTER_FAR,ENTER_NEAR+4.0,false,true)
	_lax = false
	if not rim.is_empty():
		if enter(0,rim) != null: return "climb by his head (a stepped face)"
	return "none"

## Shift+O: his head on now (the beat).
func whole_now() -> String:
	var sp: Node = lay.get("spawner")
	for b: Node3D in bodies():
		if bool(b.whole): continue
		var h: Node3D = null
		if sp != null:
			for i in range(sp.heads.size()):
				if sp.body_of(i) == b: h = sp.head_of(i)
		if h == null: continue
		b.make_whole(h)
		b.rest()
		_on_whole(b)
		b._triumph_thud = false
		b._go("triumph")
		return "whole"
	return "no headless body"
