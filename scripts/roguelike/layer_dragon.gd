extends Node
## The roost's dragon live over a generated layer (a demo round: docs/design/
## roguelike/layer-round12-dragon.md). With --dragon-live, run_layer's
## sleeping roost dragon (scripts/dragon_roost.gd on scripts/sky_dragon.gd)
## wakes a few seconds after the layer stands (his wake's stir and takeoff,
## scripts/dragon_wake.gd), then flies a loop of behaviours over the layer:
##   - monitor: a high, slow circuit round the layer's edge (MONITOR_OVER
##     over its highest solid, MONITOR_OUT past its furthest isle, bent
##     round his own roost), his head turned in and down to the isle nearest
##     under him;
##   - swoop: a low pass over one isle (the one nearest you in view), down
##     to SWOOP_OVER over the highest thing under his line, so his downwash
##     (scripts/dragon_downwash.gd) sweeps its grass, trees and water, then
##     a climb back up;
##   - grip: off to cling to the rim of an isle with room for it (SkyDragon
##     `_has_room`; never the base, nor the isle you stand on), its beats
##     as they are (slam, pant, inhale, gale, haul, let go), held GRIP_HOLD s.
## In that ORDER, the monitor MONITOR_FOR s each time. All the while his
## sight looks for you (scripts/dragon_sight.gd) and, spotted, he fires his
## air blast (scripts/dragon_air_blast.gd): a knock and a stun, no damage.
##
## Flags (run_layer's): --dragon-live; --dragon-wake-at=<s> (WAKE_AFTER after
## the layer stands); --dragon-monitor=<s>; --dragon-grip-hold=<s>;
## --dragon-swoop-over=<m>; --dragon-first=swoop|grip|monitor;
## --dragon-no-blast; --dragon-watch[=chase|orbit|look] (his camera once he
## flies); --dragon-log.
## Keys: U wakes him, J swoops next, K grips next, H back to his circuit (he
## lets go of a rim), V his camera, G lets go (SkyDragon's own).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const DragonWake = preload("res://scripts/dragon_wake.gd")
const DragonIsleShape = preload("res://scripts/dragon_isle_shape.gd")
const DragonSight = preload("res://scripts/dragon_sight.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")

## Seconds after play begins (the loading screen lifted, the layer whole) he wakes.
const WAKE_AFTER := 3.0
## The circuit: over the highest solid under it (m), out past the furthest
## isle's reach from its middle (m), its points' spacing (m), their rise
## and fall (m), and how far it keeps off the roost's reach (m). "near"
## (the default) rings the isles within NEAR m of you, laid again each time
## he goes back to it (at least NEAR_R, at most FAR_R round); "layer"
## (--dragon-circuit=layer) the whole layer.
const MONITOR_OVER := 70.0
const MONITOR_OUT := 70.0
const MONITOR_STEP := 120.0
const NEAR := 260.0
const NEAR_R := Vector2(180.0,340.0)
const MONITOR_WAVE := 10.0
const ROOST_CLEAR := 110.0
## Seconds on the circuit before the next behaviour.
const MONITOR_FOR := 25.0
## The swoop: over the highest thing under its line (a band SWOOP_BAND m
## either side) by SWOOP_OVER (m); in from SWOOP_IN m out, out SWOOP_OUT m.
const SWOOP_OVER := 30.0
const SWOOP_BAND := 30.0
const SWOOP_IN := 300.0
const SWOOP_OUT := 260.0
## The grip's way in kept this far over anything under its line (m).
const GRIP_CLEAR := 25.0
## How long he holds the rim (s; his own CLING_HOLD is 45-60).
const GRIP_HOLD := 22.0
## What he does, round and round.
const ORDER := ["swoop","monitor","grip","monitor"]

var study: Node3D
var layer: Dictionary
var dragon: Node3D
var wake: RefCounted = null
## asleep, waking, monitor, swoop, grip.
var behavior := "asleep"
var _order_i := 0
var _t := 0.0
var _up_t := 0.0
var _next := ""
var _was_state := ""
var _log := false
var _log_t := 0.0
var wake_after := WAKE_AFTER
var monitor_for := MONITOR_FOR
var grip_hold := GRIP_HOLD
var swoop_over := SWOOP_OVER
var blast := true
var watch := ""
var circuit := "near"
var sea_y := -120.0

## The layer: its middle and highest solid, the base's middle, the
## circuit's points.
var middle := Vector3.ZERO
var top := 0.0
var base_at := Vector3.ZERO
var ring: Array = []
## The plan's isles by id, and their placed motif isles (the sky's).
var _plan_isles := {}
var _nodes := {}
var _records := {}
var _swooped := ""
var _swoop_mid := Vector3.INF
var grips := 0
var swoops := 0

func setup(owner: Node3D, plan: Dictionary, roost_dragon: Node3D, args: PackedStringArray, sea: float) -> void:
	study = owner
	layer = plan
	dragon = roost_dragon
	sea_y = sea
	name = "LayerDragon"
	for arg in args:
		if arg.begins_with("--dragon-wake-at="): wake_after = maxf(float(arg.get_slice("=",1)),0.0)
		elif arg.begins_with("--dragon-monitor="): monitor_for = maxf(float(arg.get_slice("=",1)),1.0)
		elif arg.begins_with("--dragon-grip-hold="): grip_hold = maxf(float(arg.get_slice("=",1)),3.0)
		elif arg.begins_with("--dragon-swoop-over="): swoop_over = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-first="):
			var first := arg.get_slice("=",1)
			if ORDER.has(first): _order_i = ORDER.find(first)
		elif arg == "--dragon-no-blast": blast = false
		elif arg == "--dragon-watch": watch = "chase"
		elif arg.begins_with("--dragon-watch="): watch = arg.get_slice("=",1)
		elif arg == "--dragon-log": _log = true
		elif arg.begins_with("--dragon-circuit="): circuit = arg.get_slice("=",1)
	_lay_out()
	print("layer dragon: asleep on his roost; wakes %.1f s after play begins; his circuit over %s" % [wake_after,"the whole layer" if circuit == "layer" else "the isles near you"])

# --- The layer as he reads it ------------------------------------------------------

func _lay_out() -> void:
	var isles: Array = layer.get("isles",[])
	var sum := Vector3.ZERO
	top = -INF
	for isle: Dictionary in isles:
		var c := _centre(isle)
		sum += c
		top = maxf(top,LayerPlan._span(isle).y)
		_plan_isles[str(isle.id)] = isle
		if isle.role == "base": base_at = c
	middle = sum/maxf(isles.size(),1.0)

## The circuit laid now: round the isles near you (or the whole layer),
## MONITOR_OVER over the highest of them; `ring_mid` its middle.
var ring_mid := Vector3.ZERO
func _lay_ring() -> void:
	var at := _pilot_at()
	var near: Array = []
	for isle: Dictionary in layer.get("isles",[]):
		var c := _centre(isle)
		if circuit == "layer" or Vector2(c.x-at.x,c.z-at.z).length() < NEAR+_reach(isle)*0.5: near.append(isle)
	if near.is_empty(): near = layer.get("isles",[])
	var mid := Vector3.ZERO
	for isle: Dictionary in near: mid += _centre(isle)
	mid /= float(near.size())
	var r := 0.0
	var hi := -INF
	for isle: Dictionary in near:
		var c := _centre(isle)
		r = maxf(r,Vector2(c.x-mid.x,c.z-mid.z).length()+_reach(isle)*0.5)
	r += MONITOR_OUT
	if circuit != "layer": r = clampf(r,NEAR_R.x,NEAR_R.y)
	# Over whatever stands under the ring and inside it.
	for isle: Dictionary in layer.get("isles",[]):
		var c := _centre(isle)
		if Vector2(c.x-mid.x,c.z-mid.z).length() < r+_reach(isle)*0.5+40.0: hi = maxf(hi,c.y)
	ring_mid = Vector3(mid.x,hi,mid.z)
	ring = _circuit(ring_mid,r,hi+MONITOR_OVER)
	print("layer dragon: his circuit %.0f m round (%.0f, %.0f), %.0f m up, %d points" % [r,mid.x,mid.z,hi+MONITOR_OVER,ring.size()])

static func _centre(isle: Dictionary) -> Vector3:
	var c := LayerPlan._rect(isle).get_center()
	return Vector3(c.x,LayerPlan._span(isle).y,c.y)

static func _reach(isle: Dictionary) -> float:
	return LayerPlan._rect(isle).size.length()*0.5

## The circuit's points round `mid` at `r`, `y` up, bent off the roost.
func _circuit(mid: Vector3, r: float, y: float) -> Array:
	var roost: Dictionary = layer.get("roost",{})
	var pts: Array = []
	var n := clampi(int(TAU*r/MONITOR_STEP),8,24)
	for k in range(n):
		var a := TAU*float(k)/float(n)
		var p := Vector3(mid.x,0.0,mid.z)+Vector3(cos(a),0.0,sin(a))*r
		p.y = y+MONITOR_WAVE*sin(a*3.0)
		pts.append(p)
	if roost.is_empty(): return pts
	var at: Vector3 = roost.at
	var keep := float(roost.reach)+ROOST_CLEAR
	# Each point, and each leg's middle, pushed out of the roost's keep.
	var out: Array = []
	for k in range(pts.size()):
		for p: Vector3 in [pts[k],((pts[k] as Vector3)+(pts[(k+1)%pts.size()] as Vector3))*0.5]:
			var flat := Vector2(p.x-at.x,p.z-at.z)
			if flat.length() < keep:
				if flat.length() < 1.0: flat = Vector2(p.x-mid.x,p.z-mid.z)
				flat = flat.normalized()*keep
				p = Vector3(at.x+flat.x,p.y,at.z+flat.y)
			out.append(p)
	return out

## The highest solid along a line (flat), SWOOP_BAND either side, every 8 m.
func _highest(a: Vector3, b: Vector3, band := SWOOP_BAND) -> float:
	var hi := -INF
	var flat := Vector2(b.x-a.x,b.z-a.z)
	var n := maxi(int(flat.length()/8.0),1)
	var across := Vector2(-flat.y,flat.x).normalized()
	for isle: Dictionary in layer.get("isles",[]):
		for i in range(n+1):
			var p := Vector2(a.x,a.z)+flat*float(i)/float(n)
			for s: float in [-band,-band*0.5,0.0,band*0.5,band]:
				var q := p+across*s
				var o := LayerPlan.occ_at(isle,q.x,q.y)
				if o.y > -INF: hi = maxf(hi,o.y)
	return hi

# --- Each frame ---------------------------------------------------------------------

func update(delta: float) -> void:
	if dragon == null or not is_instance_valid(dragon) or delta <= 0.0: return
	var standing: bool = bool(study.get("walk_ready"))
	var loading: Node = study.get("loading")
	if loading != null and bool(loading.get("active")): standing = false
	if standing: _up_t += delta
	if behavior == "asleep":
		if standing and _up_t >= wake_after: wake_up()
		return
	if behavior == "waking":
		if wake != null and str(wake.get("phase")) == "flying": _go_live()
		return
	_t += delta
	dragon.on_foot = not bool(study.get("flying"))
	dragon.set("_attack_in",INF)
	var state := str(dragon.state)
	match behavior:
		"monitor":
			dragon.gaze = ring_mid
			if (dragon.route as Array).size() < 4: _top_up_ring()
			if _next != "" or _t >= monitor_for: _advance()
		"swoop":
			dragon.gaze = _swoop_mid if _swoop_mid != Vector3.INF else _under()
			if (dragon.route as Array).size() <= 1 or _next != "": _advance()
		"grip":
			dragon.gaze = Vector3.INF
			if _was_state == "leaving" and state == "roaming": _advance()
			elif state == "roaming" and (dragon.grip as Dictionary).is_empty(): _advance()
			elif _next == "monitor" and state == "clinging": dragon.call("_let_go")
	_was_state = state
	_blast_on_pilot()
	if _log:
		_log_t += delta
		if _log_t >= 2.0:
			_log_t = 0.0
			var p: Vector3 = dragon.pos
			var roost: Dictionary = layer.get("roost",{})
			var to_roost := Vector2(p.x-(roost.at as Vector3).x,p.z-(roost.at as Vector3).z).length() if not roost.is_empty() else -1.0
			print("layer dragon: %s, %s, at (%.0f, %.0f, %.0f) %.0f m/s, %.0f m over the layer's top, %.0f m from the roost; sight %s; wash on the ground %.2f" % [behavior,state,p.x,p.y,p.z,float(dragon.speed),p.y-top,to_roost,str(dragon.sight.state),float(dragon.downwash.reach_ground())])

## Up off his roost now (his wake's stir and takeoff).
func wake_up() -> void:
	if behavior != "asleep": return
	wake = DragonWake.new()
	wake.setup(dragon,study.get("roost_air"),PackedStringArray(),Callable(),base_at)
	dragon.wake = wake
	wake.call("wake_now")
	behavior = "waking"
	_say("The dragon wakes")

## The wake's takeoff done: the whole flight, his targets, his sight.
func _go_live() -> void:
	var list: Array = []
	for isle: Dictionary in layer.get("isles",[]): list.append([_centre(isle),_reach(isle)])
	dragon.blast_on = blast
	dragon.attack = "blast" if blast else "none"
	dragon.idle_roars = false
	# His grip's targets: every isle but the base (the start: never), each
	# known once it stands (`_record`); room is his own rule.
	dragon.targets.clear()
	for isle: Dictionary in layer.get("isles",[]):
		if isle.role == "base": continue
		dragon.targets.append({"name":str(isle.id),"home":_centre(isle),"radius":_reach(isle)*0.5})
	_map_nodes()
	dragon.find_isle = _record
	dragon.flush_birds = Callable(study,"_flush_isle_birds")
	dragon.walker = study.get("motor")
	var ground: Object = study.get("ground")
	if ground != null and ground.has_method("slide_callable"): dragon.slide = ground.call("slide_callable")
	dragon.sight_target = _sight_target
	dragon.spare_home = true
	dragon.go_live(sea_y,base_at,base_at.y,list)
	if not dragon.grip_beat.is_connected(_grip_beat): dragon.grip_beat.connect(_grip_beat)
	if not dragon.sight.state_changed.is_connected(_sight_changed): dragon.sight.state_changed.connect(_sight_changed)
	if dragon.air_blast != null: dragon.air_blast.broke.connect(func(_at: Vector3) -> void: _say("The blast pops on cover"))
	if watch != "":
		dragon.watch = watch
		dragon.set("_watch_fresh",true)
	# His downwash on the plane and the sail (the study's own, once).
	if not study.has_meta("dragon_wash"):
		study.set_meta("dragon_wash",true)
		study.call("_wash_air")
	print("layer dragon: he flies; %d isles he may grip once they stand" % (dragon.targets as Array).size())
	_begin(ORDER[_order_i] if _next == "" else _next)

## The isles' placed motif isles by plan id (the sky's isles are laid in
## the plan's order, the base left out, the roost last).
func _map_nodes() -> void:
	_nodes.clear()
	var sky: Node = study.get("sky")
	var motifs: Variant = sky.get("motifs") if sky != null else null
	if motifs == null: return
	var built: Array = motifs.get("isles")
	var k := 0
	for isle: Dictionary in layer.get("isles",[]):
		if isle.role == "base": continue
		if k < built.size(): _nodes[str(isle.id)] = built[k]
		k += 1

## An isle's record for his grip (as the aqueduct isle's `_dragon_isle`),
## once it stands; {} till then.
func _record(id: String) -> Dictionary:
	if _records.has(id): return _records[id]
	var isle: Node3D = _nodes.get(id)
	if isle == null or not is_instance_valid(isle) or not isle.stands(): return {}
	var shape: RefCounted = DragonIsleShape.new()
	shape.build(isle,study.get_world_3d().direct_space_state)
	if not shape.ok: return {}
	var home: Vector3 = shape.home
	var rec := {"node":isle,"shape":shape,"home":home,"radius":float(shape.radius),"exclude":shape.exclude,
		"frame":isle.global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,home),"pivot":home}
	_records[id] = rec
	return rec

# --- The behaviours -----------------------------------------------------------------

## On to the next: the asked-for one, else the next in ORDER.
func _advance() -> void:
	var what := _next
	if what == "":
		_order_i = (_order_i+1)%ORDER.size()
		what = ORDER[_order_i]
	_begin(what)

func _begin(what: String) -> void:
	_next = ""
	_t = 0.0
	# ORDER carries on from what he does now (asked for or not).
	if ORDER[_order_i] != what and ORDER.has(what): _order_i = ORDER.find(what)
	match what:
		"swoop":
			if _swoop(): return
			_monitor()
		"grip":
			if _grip(): return
			_say("Dragon: no isle with room for his grip; he swoops instead")
			if _swoop(): return
			_monitor()
		_: _monitor()

## Asks for `what` next (a key): the circuit now, a swoop or a grip at once
## (the grip only from the air).
func ask(what: String) -> void:
	if behavior == "asleep":
		_next = what
		wake_up()
		return
	if behavior == "waking":
		_next = what
		_say("Dragon: %s once he is up" % what)
		return
	if what == "monitor" and behavior == "grip" and str(dragon.state) == "clinging":
		_next = "monitor"
		dragon.call("_let_go")
		return
	if behavior == "grip" and str(dragon.state) in ["grabbing","clinging","leaving"]:
		_next = what
		_say("Dragon: %s after his grip" % what)
		return
	if behavior == "grip": dragon.grip = {}
	_begin(what)

func _monitor() -> void:
	behavior = "monitor"
	_lay_ring()
	dragon.route = []
	dragon.set("_leg_kinds",[])
	# From the circuit's point nearest ahead of him, round the way he faces.
	var p: Vector3 = dragon.pos
	var yaw := float(dragon.yaw)
	var fwd := Vector2(-sin(yaw),-cos(yaw))
	var near := INF
	for i in range(ring.size()):
		var q: Vector3 = ring[i]
		var to := Vector2(q.x-p.x,q.z-p.z)
		var d := to.length()+(0.0 if to.dot(fwd) > 0.0 else 1000.0)
		if d < near:
			near = d
			_ring_i = i
	if not ring.is_empty():
		var a: Vector3 = ring[_ring_i]
		var b: Vector3 = ring[(_ring_i+1)%ring.size()]
		_ring_step = 1 if Vector2(b.x-a.x,b.z-a.z).dot(fwd) >= 0.0 else -1
	_top_up_ring()
	_say("Dragon: watching the layer from on high")

## The circuit's next lap onto his route.
var _ring_i := 0
var _ring_step := 1
func _top_up_ring() -> void:
	if ring.is_empty(): return
	var route: Array = dragon.route
	var kinds: Array = dragon.get("_leg_kinds")
	for k in range(ring.size()):
		route.append(ring[_ring_i])
		kinds.append("circuit")
		_ring_i = (_ring_i+_ring_step+ring.size())%ring.size()
	dragon.route = route
	dragon.set("_leg_kinds",kinds)

## The isle nearest under him (its top), for his head to watch.
func _under() -> Vector3:
	var p: Vector3 = dragon.pos
	var best := middle
	var near := INF
	for isle: Dictionary in layer.get("isles",[]):
		var c := _centre(isle)
		var d := Vector2(c.x-p.x,c.z-p.z).length()
		if d < near:
			near = d
			best = c
	return best

## The player's feet (or the plane).
func _pilot_at() -> Vector3:
	if bool(study.get("flying")) and study.get("plane") != null: return study.get("plane").get("position")
	return (study.get("motor") as Object).get("feet")

## Whether `p` is in the camera's view (within 60 degrees of its look).
func _in_view(p: Vector3) -> bool:
	var cam: Camera3D = study.get("camera")
	if cam == null: return false
	var look := -cam.global_transform.basis.z
	var to := p-cam.global_position
	return Vector2(look.x,look.z).normalized().dot(Vector2(to.x,to.z).normalized()) > cos(deg_to_rad(60.0))

## A low pass over the isle nearest you in view (not the last swooped).
func _swoop() -> bool:
	var at := _pilot_at()
	var pick: Dictionary = {}
	var best := INF
	for isle: Dictionary in layer.get("isles",[]):
		if str(isle.id) == _swooped and layer.isles.size() > 1: continue
		var c := _centre(isle)
		var score := Vector2(c.x-at.x,c.z-at.z).length()-(120.0 if _in_view(c) else 0.0)
		if score < best:
			best = score
			pick = isle
	if pick.is_empty(): return false
	_swooped = str(pick.id)
	var c := _centre(pick)
	var p: Vector3 = dragon.pos
	var way := Vector3(c.x-p.x,0.0,c.z-p.z)
	way = way.normalized() if way.length() > 1.0 else Vector3.FORWARD
	var mid := Vector3(c.x,0.0,c.z)
	var hi := _highest(mid-way*SWOOP_IN,mid+way*SWOOP_OUT)
	var pass_y := (hi if hi > -INF else c.y)+swoop_over
	var high := pass_y+60.0
	var pts := [mid-way*SWOOP_IN+Vector3.UP*(pass_y+40.0),mid-way*120.0+Vector3.UP*(pass_y+6.0),mid+Vector3.UP*pass_y,
		mid+way*150.0+Vector3.UP*(pass_y+12.0),mid+way*SWOOP_OUT*1.8+Vector3.UP*high]
	# Points behind him already (he is near): from the first ahead.
	var fwd := Vector2(-sin(float(dragon.yaw)),-cos(float(dragon.yaw)))
	while pts.size() > 3:
		var to := Vector2((pts[0] as Vector3).x-p.x,(pts[0] as Vector3).z-p.z)
		if to.length() > 140.0 and to.dot(fwd) > 0.0: break
		pts.pop_front()
	var kinds: Array = []
	for i in range(pts.size()): kinds.append("low pass")
	dragon.route = pts
	dragon.set("_leg_kinds",kinds)
	_swoop_mid = mid+Vector3.UP*(pass_y-swoop_over)
	behavior = "swoop"
	swoops += 1
	_say("Dragon: swooping low over %s" % str(pick.id).replace("_"," "))
	print("layer dragon: swoop %d over %s, %.0f m over its highest under the line (pass at y %.0f, the isle's top %.0f)" % [swoops,str(pick.id),swoop_over,pass_y,c.y])
	return true

## Off to grip the isle with room nearest you in view (not yours).
func _grip() -> bool:
	var at := _pilot_at()
	var targets: Array = dragon.targets
	var pick := -1
	var best := INF
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if _record(str(t.name)).is_empty() or not dragon.call("_has_room",t): continue
		var home: Vector3 = t.home
		var d := Vector2(home.x-at.x,home.z-at.z).length()
		if d < float(t.radius)+12.0: continue
		var score := d-(150.0 if _in_view(home) else 0.0)
		if score < best:
			best = score
			pick = i
	if pick < 0: return false
	dragon.grip_isle(pick,grip_hold)
	if (dragon.grip as Dictionary).is_empty(): return false
	# His way in kept over what stands under it.
	var route: Array = dragon.route
	if route.size() >= 2:
		var way: Vector3 = route[0]
		var grab: Vector3 = route[1]
		var hi := maxf(_highest(dragon.pos,way,20.0),_highest(way,grab,20.0))
		if hi > -INF and way.y < hi+GRIP_CLEAR:
			way.y = hi+GRIP_CLEAR
			route[0] = way
			dragon.route = route
	behavior = "grip"
	grips += 1
	_say("Dragon: off to grip %s" % str(targets[pick].name).replace("_"," "))
	print("layer dragon: grip %d on %s (held %.0f s)" % [grips,str(targets[pick].name),grip_hold])
	return true

# --- His sight and blast on you ---------------------------------------------------

func _sight_target() -> Dictionary:
	var plane: Variant = study.get("plane")
	if bool(study.get("flying")) and plane != null:
		return {"points":DragonSight.pilot_points(Vector3.ZERO,true,plane.get("position"),plane.call("forward")),"airborne":true}
	var motor: Object = study.get("motor")
	return {"points":DragonSight.pilot_points(motor.get("feet"),false),"airborne":not bool(motor.get("grounded"))}

func _blast_on_pilot() -> void:
	if dragon.air_blast == null or bool(study.get("flying")): return
	var motor: Object = study.get("motor")
	var v: Vector3 = dragon.air_blast.pilot_knock(motor.get("feet"),motor)
	if v != Vector3.ZERO:
		motor.call("knock",v,dragon,DragonAirBlast.STUN_DOWN)
		_say("Blasted!")

func _sight_changed(now: String, _was: String) -> void:
	match now:
		"suspicious": _say("The dragon is suspicious")
		"spotted": _say("Spotted!")
		"unaware": _say("He has lost you")

func _grip_beat(what: String) -> void:
	var said: String = {"grab":"He grabs the isle!","staggered":"Staggered!","inhale":"He draws breath: take cover!",
		"blown":"Blown off your feet!","pull":"He hauls on the rim: hold on!","thrown":"Thrown!","let go":"He lets go"}.get(what,"")
	if said != "": _say(said)

func _say(text: String) -> void:
	print("layer dragon: %s" % text)
	if study.has_method("_show_toast"): study.call("_show_toast",text)

## The card's line.
func card_line() -> String:
	var now: String = {"asleep":"asleep (U wakes him)","waking":"waking","monitor":"watching from on high","swoop":"swooping","grip":"gripping"}.get(behavior,behavior)
	return "Dragon: %s  ·  J swoop · K grip · H circuit · V his camera" % now
