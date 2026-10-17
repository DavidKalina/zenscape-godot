extends "res://scripts/enemies/inhaler_head.gd"
## The rolling coin (a prototype): a variation of the Olmec's head, standalone
## (no body comes for it). A round head (art/blender/inhaler_head/, --wheel:
## assets/models/wheel_head.glb) standing on its rim like a coin, its face one
## of the flat sides. Study: studies/rolling_coin_isle.tscn.
##
##   "scoot"   it strolls its round: grinds round to its next point, a slow
##             roll, a stop, a rest.
##   "stare"   it sees him (all round, nothing between): grinds round to face
##             him, its eyes lighting.
##   "windup"  a quarter turn more, its rim at him, then it rocks back (the
##             tell), its jaw dropping.
##   "charge"  it speeds up to `charge_speed` (`charge_accel`), steering only in
##             wide arcs (`turn`), banking into them, quicker downhill. Rolled
##             into, he is knocked aside out of its way (a heart).
##   "spent"   past him by `pass_by`, or `charge_max` s on: it slows, wobbles
##             like a dropped coin, wider and quicker, and
##   "topple"  topples flat on its face or its back; "flat" `flat_for` s (a
##             low drum he stands on), then "rise": it strains and heaves
##             itself back up onto its rim.
##   "crash"   into stone it can't break: a thud, it reels back and topples.
##
## Breaking (scripts/kit_isle/breakables.gd, the breaker `coin`, on in its
## study): rolling into stone at speed it hits the hub there with
## `smash_strength` times its share of `charge_speed`; what breaks, it rolls
## on through, keeping `smash_keep` of its speed (stone it isn't strong
## enough for, it crashes into). Falling pieces and rubble don't stop it.
## Laid down flat, its thud hits what's under its rim (`flop_strength`).
## Off a rim it rolls over and falls. It still calls out as he nears (the
## inhaler head's calls); it never draws its breath in.
##
## On a track (opt-in: `circuit`, a scripts/enemies/coin_circuit.gd, given
## as the override "circuit", with "lap_s" where on it) it starts in
##   "lap"     rolling the lap's line at the circuit's lap speed; at a
##             lip's edge it is kicked into the open air (the lip's kick,
##             under `fly_gravity`, a free ballistic arc) and lands where it
##             lands: in the next cradle (near its catch, on its bed) it
##             rolls on (`caught`); anywhere else it is off the lap
##             (`missed`): on stone or turf it rolls on spent and topples,
##             over nothing it falls.
##   "leave"   (only on a circuit whose `hunt` is on) it saw him on a field
##             beside a gate just ahead on the lap: it
##             rolls on to the gate's point on the line, then
##   "out"     brakes and swings out through the kerb's gap onto the field,
##             and hunts (stare, windup, charge, spent/crash, topple, rise).
##   "home"    risen: it rolls back to the nearest gate's mouth, faces in,
##   "enter"   waits for room on the lap and rolls in onto the line ("lap").
##             Risen in a channel's bed it enters where it lies.
##             After it rejoins it doesn't leave again for `hunt_rest` s.
## The circuit's coins share it: it doesn't leave while the circuit's
## `hunt_cap` coins hunt; lapping, it slows and stops behind a coin lying
## or stopped on the line ahead (from `queue_slow` to `queue_stop` m back),
## and rolls on when it goes; lost off the circuit, the circuit mints a new
## one into a cradle (scripts/enemies/coin_circuit.gd).
## Without one it is as above.

const WHEEL_MODEL := "res://assets/models/wheel_head.glb"
## The model as authored: its diameter (chin to crown), its thickness.
const WHEEL_HEIGHT := 3.36
const WHEEL_THICK := 1.72
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
## Its breaker's name in the hub.
const BREAKER := &"coin"
## The slam (its GROUP, `decent`): a buried find (scripts/buried_find.gd)
## in its group hears a circuit coin's topple thud as a decent slam.
const CoinSlam = preload("res://scripts/slam.gd")

## The breakables hub it breaks through (null: the scene's first, if any).
var breaker: Node = null
## Crashes, smashes (stone broken), topples, hits on him: the HUD's.
var crashes := 0
var smashes := 0
var topples := 0
var hits := 0
## What its probe last met (a node path), for checks.
var last_met := ""
# Its radius, thickness, speed along its way (m/s), its way (a facing), its
# spin (rad), its bank (rad; + onto its back, - onto its face) and where the
# bank is going, the wobble's phase (and, toppling, its side), whether it
# lies flat, the facing it noticed him at, its squash.
var _r := 1.0
var _thick := 1.0
var _speed := 0.0
var _heading := 0.0
var _spin := 0.0
var _bank := 0.0
var _bank_to := 0.0
var _wobble := 0.0
var _flat := false
var _notice_face := 0.0
var _squash := 1.0
var _probe := PhysicsRayQueryParameters3D.new()
## Its track (scripts/enemies/coin_circuit.gd; null: none), how far along
## its lap it is (m), its laps done, whether it is over a flight.
var circuit: Node = null
var lap_s := 0.0
var laps := 0
var aloft := false
## Flights caught in their cradle, flights missed.
var caught := 0
var missed := 0
# The flight it is in ({} on the beds), its velocity there, the way from
# where it landed to the lap's line (eased away).
var _fly := {}
var _fly_vel := Vector3.ZERO
var _ease := Vector3.ZERO
## The gate it is leaving or coming home by ({} none), its scripted way
## through the gap (points, world), the time left before it may hunt again,
## how long it has been stuck rolling home.
var gate := {}
var _path: Array = []
var _hunt_rest := 0.0
var _stuck := 0.0
var _stuck_at := Vector3.ZERO
## Hunts begun (left through a gate), rejoins (back on the lap).
var hunts := 0
var rejoins := 0

func _init() -> void:
	cost = 3
	tags = PackedStringArray(["grounded","loud","rolls","breaks"])

func default_knobs(n: Dictionary) -> Dictionary:
	var k := super.default_knobs(n)
	k.merge({
		"charge_speed":n.run*1.75,"charge_accel":n.run*1.5,"turn":0.55,"charge_max":4.5,
		"pass_by":n.unit*3.0,"roll_friction":n.run*0.7,"wobble_from":n.run*0.55,
		"topple_at":n.run*0.12,"flat_for":2.2,"rise":1.5,"stare":0.55,"windup":1.15,
		"stroll":n.run*0.3,"stroll_for":2.4,"knock_out":n.unit*4.5,"knock_up":n.unit*1.2,
		"smash_strength":1.0,"smash_keep":0.7,"smash_min":n.run*0.6,"flop_strength":0.6,
	},true)
	# Off a lip (on a track): the arc's gravity.
	k["fly_gravity"] = float(n.gravity)*float(n.fall)
	# Leaving the lap to hunt: how far ahead a gate may be, how far from
	# the gate he may stand; rolling home, its speed; after a rejoin, rest.
	k["gate_ahead"] = n.unit*12.0
	k["gate_reach"] = float(k.sight)+n.unit*3.0
	k["home_speed"] = float(n.run)*0.5
	k["hunt_rest"] = 8.0
	# Queued on the lap: how far back of the coin ahead it stops and begins
	# to slow (m, centre to centre; its flat drum is 2.9 across).
	k["queue_stop"] = n.unit*4.0
	k["queue_slow"] = n.unit*9.0
	return k

func _size(n: Dictionary) -> void:
	super._size(n)
	_r = height*0.5
	_thick = height*WHEEL_THICK/WHEEL_HEIGHT
	width = height
	length = _thick

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	var o := overrides.duplicate()
	circuit = o.get("circuit")
	lap_s = float(o.get("lap_s",0.0))
	o.erase("circuit")
	o.erase("lap_s")
	super.setup(host,at,face,o)
	state = "scoot"
	_heading = facing-PI*0.5
	_rest = _rng.randf_range(0.5,1.5)
	if circuit != null:
		state = "lap"
		_settled = true
		_speed = float(circuit.lap_speed)
		_lap_move(0.0)

func _build() -> void:
	super._build()
	var col: CollisionShape3D = body.get_child(0)
	var cyl := CylinderShape3D.new()
	cyl.radius = _r
	cyl.height = _thick
	col.shape = cyl
	col.position = Vector3.UP*_r
	col.rotation = Vector3(PI*0.5,0.0,0.0)

func _art(root: Node3D) -> void:
	look = Look.new()
	look.name = "Look"
	look.model_path = WHEEL_MODEL
	look.model_height = WHEEL_HEIGHT
	root.add_child(look)
	look.build(height)
	air = Air.new()
	air.name = "Air"
	add_child(air)
	air.setup(self,float(knobs.reach),float(knobs.cone),DisplayServer.get_name() != "headless")

## The HUD's lines.
func hud_lines() -> PackedStringArray:
	if circuit != null:
		return PackedStringArray(["coin  %s %.1fs · %.1f m/s · lap %.1f m (%d laps, %d caught, %d missed, %d hunts, %d rejoins)%s · smashes %d · crashes %d · topples %d · hits %d · falls %d · circuit %d hunting, %d minted back" % [state,state_t,_speed,lap_s,laps,caught,missed,hunts,rejoins," aloft" if aloft else "",smashes,crashes,topples,hits,falls,circuit.hunting(),circuit.minted_back]])
	return PackedStringArray(["coin  %s %.1fs · %.1f m/s · bank %.2f · smashes %d · crashes %d · topples %d · hits %d · falls %d" % [state,state_t,_speed,_bank,smashes,crashes,topples,hits,falls]])

## The hub it breaks through.
func hub() -> Node:
	if breaker == null or not is_instance_valid(breaker):
		breaker = get_tree().get_first_node_in_group(Breakables.HUBS) if is_inside_tree() else null
	return breaker

# --- A frame -----------------------------------------------------------------------

func think(delta: float) -> void:
	_clock += delta
	state_t += delta
	var m: PilotMotor = field.motor
	var chest := _chest(m)
	if not _settled:
		air.draw(0.0,delta)
		return
	if _falling or state in ["fall","dazed"]:
		_fallen(delta)
		_speed = 0.0
		return
	var sees := _sees(m,chest)
	_unseen = 0.0 if sees else _unseen+delta
	var w := _roll_think(chest,sees,delta)
	var want_open := w.y
	_shake = move_toward(_shake,0.0,delta*0.06)
	_calls(m,delta)
	if _flap > 0.0:
		_flap = maxf(0.0,_flap-delta)
		want_open = maxf(want_open,0.32*sin(clampf(1.0-_flap/0.55,0.0,1.0)*PI))
	_open = move_toward(_open,want_open,(4.0 if _flap > 0.0 else 2.0)*delta)
	_glow = move_toward(_glow,w.x,1.5*delta)
	look.open(_open)
	look.glow(_glow)
	draw_share = 0.0
	pulling = 0.0
	air.draw(0.0,delta)

## It sees him all round (it looks out of both sides): near enough, nothing
## between its middle and his chest.
func _sees(_m: PilotMotor, chest: Vector3) -> bool:
	var mid := position+Vector3.UP*height*0.6
	if mid.distance_to(chest) > float(knobs.sight): return false
	return _clear(mid,chest)

func harm_cause() -> String:
	return "olmec"

func harmful() -> bool:
	return state in ["charge","lap","leave"] and _speed > 2.0

func bucks() -> bool:
	return _falling or absf(_speed) > 1.0 or state in ["topple","rise"]

func shove(v: Vector3) -> void:
	if gone: return
	_speed = 0.0
	super.shove(v)

## No body wears it.
func _perched(_delta: float) -> void:
	pass

## Its states; returns (eyes' glow, jaw's opening).
func _roll_think(chest: Vector3, sees: bool, delta: float) -> Vector2:
	var to := Vector2(chest.x-position.x,chest.z-position.z)
	var at_him := PilotMotor.facing_of(to.normalized()) if to.length() > 0.01 else facing
	var glow := 0.0
	var open := 0.0
	_bank_to = 0.0
	_hunt_rest = maxf(0.0,_hunt_rest-delta)
	match state:
		"lap":
			if sees and circuit != null and bool(circuit.get("hunt")) and not aloft and _hunt_rest <= 0.0 and circuit.hunting(self) < int(circuit.hunt_cap):
				var g := _gate_for(chest)
				if not g.is_empty():
					gate = g
					_go("leave")
		"leave":
			glow = smoothstep(0.0,0.6,state_t)
			var d: float = circuit.ahead(lap_s,float(gate.s))
			if d < 0.3 or d > circuit.length*0.5:
				_go("out")
				hunts += 1
				var at: Vector3 = gate.at
				var out: Vector3 = gate.out
				_path = [at,at+out*_r*1.8]
				field.sound(&"head_grind",global_position)
		"out":
			glow = 1.0
			if _path.is_empty():
				_go("stare")
				_notice_face = facing
				_settled = true
				_ground = position.y
				_home = position
		"home":
			glow = 0.0
			_roll_home(delta)
		"enter":
			if _path.is_empty():
				# At the mouth: in when the lap has room.
				_speed = 0.0
				var g: Dictionary = gate
				var to_in: Vector3 = -(g.out as Vector3)
				var off := angle_difference(_heading,PilotMotor.facing_of(Vector2(to_in.x,to_in.z)))
				_set_heading(_heading+clampf(off,-1.2*delta,1.2*delta))
				if absf(off) < 0.1 and circuit.room_at(float(g.s),self):
					_path = [g.at,g.on]
					state_t = 0.0
		"scoot":
			_stroll(delta)
			if sees:
				_go("stare")
				_notice_face = facing
				field.sound(&"head_grind",global_position)
		"stare":
			# Ground round on its rim to stare at him.
			glow = smoothstep(0.0,float(knobs.stare),state_t)
			_speed = move_toward(_speed,0.0,float(knobs.roll_friction)*2.0*delta)
			var off := angle_difference(facing,at_him)
			_set_facing(facing+clampf(off,-1.6*delta,1.6*delta))
			_shake = 0.006 if absf(off) > 0.05 else 0.0
			if absf(off) < 0.08 and state_t > float(knobs.stare):
				_go("windup")
				_notice_face = facing
				tell()
				field.sound(&"head_strain",global_position)
		"windup":
			# A quarter turn more, its rim at him; then it rocks back.
			glow = 1.0
			var k := clampf(state_t/float(knobs.windup),0.0,1.0)
			var turn := smoothstep(0.0,0.42,k)
			_set_facing(_notice_face+PI*0.5*turn)
			# Keeps a bead on him through the turn.
			_notice_face += clampf(angle_difference(_notice_face,at_him),-0.8*delta,0.8*delta)
			if k > 0.45:
				var back := smoothstep(0.45,0.85,k)
				_speed = -1.2*sin(back*PI)*(1.0-smoothstep(0.85,1.0,k))
				_shake = 0.01*back
				open = back*0.5
			if state_t >= float(knobs.windup):
				_go("charge")
				_speed = 1.0
				field.sound(&"head_blast",global_position)
		"charge":
			glow = 1.0
			open = 0.65
			_speed = minf(_speed+float(knobs.charge_accel)*delta,float(knobs.charge_speed))
			# Steering in wide arcs: its way bends toward him a little.
			var way := PilotMotor.facing_of(to.normalized()) if to.length() > 0.01 else _heading
			var off := angle_difference(_heading,way)
			var turn := clampf(off,-float(knobs.turn)*delta,float(knobs.turn)*delta)
			_set_heading(_heading+turn)
			_bank_to = clampf(-turn/maxf(delta,0.001)*_speed*0.05,-0.3,0.3)
			var ahead := Vector2(PilotMotor.forward(_heading))
			var passed := ahead.dot(to) < 0.0 and to.length() > float(knobs.pass_by)
			if passed or state_t > float(knobs.charge_max): _go("spent")
		"spent":
			glow = 1.0-smoothstep(0.0,1.5,state_t)
			_speed = move_toward(_speed,0.0,float(knobs.roll_friction)*delta)
			# Slow, it wobbles like a dropped coin, quicker and wider.
			var w := 1.0-clampf(_speed/float(knobs.wobble_from),0.0,1.0)
			_wobble += delta*lerpf(3.0,13.0,w)
			_bank_to = sin(_wobble)*0.28*w*w
			if _speed <= float(knobs.topple_at): _topple(signf(sin(_wobble)) if absf(sin(_wobble)) > 0.2 else (1.0 if _rng.randf() < 0.5 else -1.0))
		"crash":
			# Bounced off the stone: it reels back, then topples.
			_speed = move_toward(_speed,0.0,float(knobs.roll_friction)*3.0*delta)
			_bank_to = sin(state_t*14.0)*0.2
			if state_t > 0.35: _topple(1.0 if _rng.randf() < 0.5 else -1.0)
		"topple":
			_speed = move_toward(_speed,0.0,float(knobs.roll_friction)*4.0*delta)
			var k := clampf(state_t/0.5,0.0,1.0)
			_bank = _wobble*(PI*0.5)*k*k
			if k >= 1.0:
				_go("flat")
				_set_flat(true)
				topples += 1
				_shake = 0.04
				_squash = 0.86
				air.thud(rest_point(),face_flat()*-signf(_wobble),1.6,_r*1.6)
				field.sound(&"head_thud",rest_point())
				_flop()
		"flat":
			_bank = _wobble*PI*0.5
			if state_t >= float(knobs.flat_for):
				_go("rise")
				field.sound(&"head_strain",global_position)
		"rise":
			var k := clampf(state_t/float(knobs.rise),0.0,1.0)
			# Straining at first (a tremble, a little lift), then swung up
			# past upright and settled.
			var strain := smoothstep(0.0,0.45,k)
			var up := smoothstep(0.45,0.85,k)
			_shake = 0.012*strain*(1.0-up)
			var lift := 0.06*strain*(1.0-up)
			_bank = _wobble*(PI*0.5-lift-PI*0.5*up)
			if up > 0.5 and _flat: _set_flat(false)
			if k >= 1.0:
				_bank = 0.0
				_squash = 0.9
				field.sound(&"head_thud",rest_point())
				_go("stare" if sees else "scoot")
				if circuit != null: _go_home()
				_notice_face = facing
				_rest = 0.8
	return Vector2(glow,open)

## A gate ahead on the lap (within `gate_ahead`, no flight between) whose
## field he stands on near it; {} for none.
func _gate_for(chest: Vector3) -> Dictionary:
	for g: Dictionary in circuit.gates:
		var d: float = circuit.ahead(lap_s,float(g.s))
		if d > float(knobs.gate_ahead) or circuit.flight_between(lap_s,d): continue
		var at: Vector3 = g.at
		var rel := Vector3(chest.x-at.x,0.0,chest.z-at.z)
		if rel.dot(g.out) > 0.5 and rel.length() < float(knobs.gate_reach): return g
	return {}

## Risen on a field: off home to the nearest gate's mouth. Risen in a
## channel's bed (on the line), it rejoins where it lies.
func _go_home() -> void:
	var q: Dictionary = circuit.nearest(position)
	if not q.is_empty() and float(q.d) < 1.2 and absf(position.y-(q.p as Vector3).y) < 0.3:
		var way: Vector3 = q.way
		# Straight back on the lap from a standstill: those behind it
		# already queue for it.
		_lap_to(float(q.s))
		_ease = position-(circuit.at(lap_s).p as Vector3)
		_set_heading(PilotMotor.facing_of(Vector2(way.x,way.z)))
		_speed = 0.0
		_go("lap")
		rejoins += 1
		_hunt_rest = float(knobs.hunt_rest)
		gate = {}
		return
	gate = circuit.nearest_gate(position)
	_go("home" if not gate.is_empty() else "scoot")
	_stuck = 0.0
	_stuck_at = position

## Rolling home on the turf to the gate's mouth: grinds round toward it,
## rolls; against stone a while, it turns aside. At the mouth: "enter".
func _roll_home(delta: float) -> void:
	var at: Vector3 = gate.at
	var mouth := at+(gate.out as Vector3)*_r*0.8
	var to := Vector2(mouth.x-position.x,mouth.z-position.z)
	_speed = maxf(_speed,0.0)
	if to.length() < 1.2:
		_go("enter")
		_path = []
		return
	var way := PilotMotor.facing_of(to.normalized())
	_stuck += delta
	if position.distance_to(_stuck_at) > 0.5:
		_stuck = 0.0
		_stuck_at = position
	if _stuck > 1.5: way += 1.2
	if _stuck > 3.0: _stuck = 0.0
	var off := angle_difference(_heading,way)
	if absf(off) > 0.3 and absf(_speed) < 0.5:
		_set_heading(_heading+clampf(off,-1.2*delta,1.2*delta))
		_speed = move_toward(_speed,0.0,float(knobs.roll_friction)*delta)
		_shake = 0.004
		return
	_set_heading(_heading+clampf(off,-0.8*delta,0.8*delta))
	var want := minf(float(knobs.home_speed),to.length()*1.5+0.5)
	_speed = move_toward(_speed,want,float(knobs.home_speed)*delta)

## Strolling its round when it hasn't seen him: grinds round to its next
## point, then a slow roll toward it, a stop, a rest.
func _stroll(delta: float) -> void:
	if _rest > 0.0:
		_rest -= delta
		_speed = move_toward(_speed,0.0,float(knobs.roll_friction)*delta)
		return
	var goal: Vector3 = route[_leg%route.size()]
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	if to.length() < _r:
		_leg += 1
		_rest = _rng.randf_range(0.8,2.0)
		return
	var way := PilotMotor.facing_of(to.normalized())
	var off := angle_difference(_heading,way)
	if absf(off) > 0.12 and absf(_speed) < 0.3:
		_set_heading(_heading+clampf(off,-0.9*delta,0.9*delta))
		_shake = 0.004
		return
	_set_heading(_heading+clampf(off,-0.3*delta,0.3*delta))
	_speed = move_toward(_speed,float(knobs.stroll),float(knobs.stroll)*delta)
	if state_t > float(knobs.stroll_for) and _rng.randf() < delta*0.5:
		_rest = _rng.randf_range(0.8,2.0)
		state_t = 0.0

func _set_heading(h: float) -> void:
	_heading = wrapf(h,-PI,PI)
	facing = wrapf(_heading+PI*0.5,-PI,PI)

func _set_facing(f: float) -> void:
	facing = wrapf(f,-PI,PI)
	_heading = wrapf(facing-PI*0.5,-PI,PI)

## Topples flat: `side` + onto its back, - onto its face.
func _topple(side: float) -> void:
	_go("topple")
	_wobble = side
	_bank_to = 0.0

## Lying flat (true) it is a low drum he stands on; up, a coin on its rim.
func _set_flat(on: bool) -> void:
	_flat = on
	if on:
		height = _thick
		length = _r*2.0
	else:
		height = _r*2.0
		length = _thick

# --- Breaking ---------------------------------------------------------------------------

## What its probe met ahead: {} for nothing; else {at, rid, live} (live: a
## falling piece, which doesn't stop it).
func _ahead(from: Vector3, along: Vector3) -> Dictionary:
	_probe.from = from
	_probe.to = from+along
	_probe.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	var skip: Array[RID] = [body.get_rid()]
	var h := hub()
	if h != null: skip.append_array(h.rubble_rids())
	_probe.exclude = skip
	var hit: Dictionary = field.study.get_world_3d().direct_space_state.intersect_ray(_probe)
	if hit.is_empty(): return {}
	last_met = str(hit.collider.get_path()) if hit.collider is Node else str(hit.collider)
	return {"at":hit.position,"rid":hit.rid,"live":hit.collider is RigidBody3D and not (hit.collider as RigidBody3D).freeze}

## Into stone at speed: it hits the hub there. True if something broke (it
## rolls on through, slowed); false, it stopped against it.
func _smash(at: Vector3, dir: Vector3) -> bool:
	var h := hub()
	if h == null or absf(_speed) < float(knobs.smash_min): return false
	var share := clampf(absf(_speed)/float(knobs.charge_speed),0.0,1.0)
	var n: int = h.hit(at+dir*0.3,_r*0.9,float(knobs.smash_strength)*share,BREAKER)
	if n <= 0: return false
	smashes += n
	_speed *= float(knobs.smash_keep)
	_shake = 0.05
	_squash = 0.9
	air.thud(at,dir,1.2,_r*1.2)
	field.sound(&"head_thud",at)
	return true

## Laid down flat: its thud hits what's under its rim.
func _flop() -> void:
	var h := hub()
	if h == null: return
	var side := face_flat()*-signf(_wobble)
	h.hit(rest_point()+side*_r+Vector3.UP*_thick*0.5,_r,float(knobs.flop_strength),BREAKER)
	# On a circuit, the thud digs: a covered buried find in the slam group
	# under where it lies (within its radius) breaks open as under a decent
	# slam (none laid: nothing). Off a circuit, as before.
	if circuit != null:
		var lies := rest_point()+side*_r
		for n: Node in get_tree().get_nodes_in_group(CoinSlam.GROUP):
			if n.has_method("covered") and n.covered(): n.slam(lies,_r,CoinSlam.decent())

# --- Moving -----------------------------------------------------------------------------

func _move(delta: float) -> void:
	if state in ["lap","leave"] and circuit != null: _lap_move(delta)
	elif state in ["out","enter"] and circuit != null: _path_move(delta)
	elif _falling:
		_fall_step(delta)
		if gone: return
	else: _roll_ground(delta)
	rotation.y = facing
	var t := _coin_pose(delta)
	if _tumble != Vector3.ZERO:
		var mid := Vector3.UP*height*0.5
		t = Transform3D(Basis.from_euler(_tumble),mid)*Transform3D(Basis.IDENTITY,-mid)*t
	var shake := Vector3(sin(_clock*53.0),sin(_clock*41.0+1.3),sin(_clock*47.0+2.1))*_shake
	t.basis = Basis.from_euler(Vector3(shake.x,0.0,shake.z)*0.6)*t.basis
	t.origin += shake*height*0.3
	skin.transform = t
	# The cylinder needn't spin: its bank only.
	body.transform = _bank_xf()

## On the turf: rolled along its way at its speed, sped up down a slope;
## into stone it smashes through or crashes, past a rim it rolls off and
## falls.
func _roll_ground(delta: float) -> void:
	if not _settled:
		var g := _settle_floor()
		if g == -INF: return
		_settled = true
		position.y = g
		_ground = g
		_home.y = g
	var way := Vector3(PilotMotor.forward(_heading).x,0.0,PilotMotor.forward(_heading).y)
	if _slide.length() > 0.01:
		position += _slide*delta
		_slide = _slide.move_toward(Vector3.ZERO,float(knobs.stone_skid)*delta)
	if not _flat and absf(_speed) > 0.01:
		var step := way*_speed*delta
		var dir := way*signf(_speed)
		var reach := dir*(_r*0.9+step.length()+0.05)
		var met := _ahead(position+Vector3.UP*(float(knobs.climb)+0.2),reach)
		if met.is_empty(): met = _ahead(position+Vector3.UP*_r,reach)
		var through := met.is_empty() or bool(met.live)
		if not through: through = _smash(met.at,dir)
		if through:
			position += step
		elif state == "charge" or absf(_speed) > 3.0:
			crashes += 1
			_shake = 0.05
			_squash = 0.84
			air.thud(rest_point()+dir*_r,dir,1.8,_r*1.5)
			field.sound(&"head_thud",rest_point()+dir*_r)
			_speed = -_speed*0.25
			_go("crash")
		else:
			_speed = 0.0
			_rest = 0.6
			_leg += 1
		_spin += _speed*delta/_r
	var mid := _floor(position)
	if mid == -INF:
		# Off a rim: it rolls over and falls, still going.
		_falling = true
		falls += 1
		vel = way*_speed+Vector3(_slide.x,0.0,_slide.z)
		_slide = Vector3.ZERO
		_speed = 0.0
		_go("fall")
		field.sound(&"head_scrape",position)
		return
	# The slope along its way: downhill it speeds up, uphill it slows.
	var f := _floor(position+way*_r*0.8)
	var b := _floor(position-way*_r*0.8)
	if f != -INF and b != -INF and not _flat:
		var slope := atan2(f-b,_r*1.6)
		_speed -= float(knobs.gravity)*sin(slope)*(2.0/3.0)*delta
	position.y = mid if mid < position.y else lerpf(position.y,mid,1.0-exp(-16.0*delta))
	_ground = position.y
	_tumble = _tumble.lerp(Vector3.ZERO,1.0-exp(-6.0*delta))

## On its track: along the lap's line at the circuit's lap speed, its feet
## on the bed; at a flight's lip edge, kicked off into the air.
func _lap_move(delta: float) -> void:
	if not _fly.is_empty():
		_lap_fly(delta)
		return
	# Queued: slowing to a stop behind a coin on the line ahead.
	var ls := float(circuit.lap_speed)
	if delta > 0.0:
		var gap: float = circuit.gap_ahead(self,float(knobs.queue_slow)+2.0)
		# A lip whose cradle has a coin in it: it waits at the lip's edge.
		var lip: Dictionary = circuit.next_flight(lap_s,float(knobs.queue_slow)+2.0)
		if not lip.is_empty() and not circuit.landing_clear(lip,self,float(knobs.queue_stop)+3.5):
			gap = minf(gap,circuit.ahead(lap_s,float(lip.s0))-0.2+float(knobs.queue_stop))
		var want := ls*clampf((gap-float(knobs.queue_stop))/maxf(float(knobs.queue_slow)-float(knobs.queue_stop),0.1),0.0,1.0)
		_speed = move_toward(_speed,want,ls*(2.5 if want < _speed else 1.0)*delta)
	var s: float = lap_s+_speed*delta
	var f: Dictionary = circuit.flight_at(s)
	if not f.is_empty() and delta > 0.0:
		_launch(f)
		return
	_lap_to(s)
	var q: Dictionary = circuit.at(lap_s)
	_ease = _ease.lerp(Vector3.ZERO,1.0-exp(-8.0*delta))
	if _ease.length() < 0.01: _ease = Vector3.ZERO
	position = (q.p as Vector3)+_ease
	_ground = position.y
	aloft = false
	var way: Vector3 = q.way
	if way.length() > 0.01: _set_heading(PilotMotor.facing_of(Vector2(way.x,way.z)))
	_spin += _speed*delta/_r
	_tumble = Vector3.ZERO

## Scripted through a gate's gap along `_path` (out: braking to a crawl;
## in: speeding up to the lap's speed), its feet on the floor; through, in
## onto the lap.
func _path_move(delta: float) -> void:
	if state == "out": _speed = move_toward(_speed,float(knobs.stroll),float(circuit.lap_speed)*1.2*delta)
	elif not _path.is_empty(): _speed = move_toward(_speed,float(circuit.lap_speed),float(circuit.lap_speed)*delta)
	var go := absf(_speed)*delta
	var moved := false
	while not _path.is_empty() and go > 0.0:
		moved = true
		var p: Vector3 = _path[0]
		var to := Vector3(p.x-position.x,0.0,p.z-position.z)
		if to.length() > 0.01: _set_heading(PilotMotor.facing_of(Vector2(to.x,to.z).normalized()))
		if to.length() <= go:
			position = Vector3(p.x,position.y,p.z)
			go -= to.length()
			_path.pop_front()
		else:
			position += to.normalized()*go
			go = 0.0
	var fl: float = field.floor_under(position,1.2,1.2,body.get_rid())
	if fl != -INF: position.y = lerpf(position.y,fl,1.0-exp(-16.0*delta))
	_ground = position.y
	_spin += _speed*delta/_r
	if state == "enter" and moved and _path.is_empty():
		# Through the gap and on the line: back on the lap.
		var s := float(gate.s)
		_lap_to(s)
		_ease = position-(circuit.at(s).p as Vector3)
		_go("lap")
		rejoins += 1
		_hunt_rest = float(knobs.hunt_rest)
		gate = {}

## Sets its lap at `s`, counting a lap when it comes round.
func _lap_to(s: float) -> void:
	var length: float = circuit.length
	while s >= length:
		s -= length
		laps += 1
	lap_s = s

## Kicked off a lip's edge: the lip's kick along the flight's way and up.
func _launch(f: Dictionary) -> void:
	_fly = f
	aloft = true
	lap_s = float(f.s0)
	var a: Vector3 = f.a
	var b: Vector3 = f.b
	var way := Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
	position = a
	_ease = Vector3.ZERO
	_fly_vel = way*float(f.vx)+Vector3.UP*float(f.vy)
	_speed = float(f.vx)
	_set_heading(PilotMotor.facing_of(Vector2(way.x,way.z)))

## In the air off a lip: a free arc under `fly_gravity`; coming down, the
## first floor under it is where it lands.
func _lap_fly(delta: float) -> void:
	var g := float(knobs.fly_gravity)
	var was := position
	position += _fly_vel*delta+Vector3.DOWN*0.5*g*delta*delta
	_fly_vel.y -= g*delta
	var a: Vector3 = _fly.a
	lap_s = minf(float(_fly.s0)+Vector2(position.x-a.x,position.z-a.z).length(),float(_fly.s1))
	_ground = position.y
	_spin += _speed*delta/_r
	_tumble = Vector3.ZERO
	if _fly_vel.y > 0.0: return
	var fl: float = field.floor_under(position,was.y-position.y+0.1,0.05,body.get_rid())
	if fl != -INF:
		_touch_down(fl)
		return
	var b: Vector3 = _fly.b
	if position.y < b.y-2.0:
		# Short or wide of the cradle, over nothing: it falls.
		missed += 1
		falls += 1
		_falling = true
		vel = _fly_vel
		_fly = {}
		aloft = false
		_speed = 0.0
		_go("fall")
		field.sound(&"head_scrape",position)

## Landed off a flight on the floor at `fl`: in its cradle (near the catch,
## on the bed, on the line) it rolls on along the lap; elsewhere it is off
## the lap, rolling on spent.
func _touch_down(fl: float) -> void:
	position.y = fl
	_ground = fl
	var f := _fly
	_fly = {}
	aloft = false
	var a: Vector3 = f.a
	var b: Vector3 = f.b
	var chord := Vector2(b.x-a.x,b.z-a.z)
	var dir := chord.normalized()
	var rel := Vector2(position.x-a.x,position.z-a.z)
	var d := rel.dot(dir)
	var side := absf(rel.dot(Vector2(-dir.y,dir.x)))
	var flat := Vector3(_fly_vel.x,0.0,_fly_vel.z)
	_squash = 0.82
	_shake = 0.03
	air.thud(position,flat.normalized(),1.4,_r*1.4)
	field.sound(&"head_thud",position)
	if side < 1.0 and absf(d-chord.length()) < 3.5 and absf(fl-b.y) < 0.35:
		caught += 1
		_lap_to(float(f.s1)+maxf(0.0,d-chord.length()))
		_ease = position-(circuit.at(lap_s).p as Vector3)
		_speed = float(circuit.lap_speed)
		return
	missed += 1
	_speed = flat.length()
	_go("spent")

## Its bank: tipped about the rim's edge it goes over (+ onto its back).
func _bank_xf() -> Transform3D:
	var pivot := Vector3(0.0,0.0,signf(_bank)*_thick*0.5*smoothstep(0.05,0.5,absf(_bank)))
	return Transform3D(Basis(Vector3.RIGHT,_bank),pivot)*Transform3D(Basis.IDENTITY,-pivot)

func _coin_pose(delta: float) -> Transform3D:
	if state not in ["topple","flat","rise"]:
		_bank = lerpf(_bank,_bank_to,1.0-exp(-8.0*delta))
	_squash = move_toward(_squash,1.0,delta*1.2)
	var c := Vector3.UP*_r
	# Its spin about its axle (rolling along its +X, the crown goes over
	# toward it).
	var t := Transform3D(Basis(Vector3.FORWARD,_spin),c)*Transform3D(Basis.IDENTITY,-c)
	t = _bank_xf()*t
	if absf(_squash-1.0) > 0.0001:
		var s := Basis.from_scale(Vector3(1.0+(1.0-_squash)*0.5,_squash,1.0+(1.0-_squash)*0.5))
		t = Transform3D(s,Vector3.ZERO)*t
	return t

# --- Him -------------------------------------------------------------------------------

## Rolled into: knocked aside, out of its way.
func touch(m: PilotMotor, _v_pre: Vector3) -> void:
	if gone or _cool > 0.0 or not harmful(): return
	if m.seized() or m.recovering() or m.on_ledge(): return
	var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
	var r := float(knobs.radius)
	if absf(local.x) > _r+r or absf(local.z) > _thick*0.5+r+0.2: return
	if m.feet.y > position.y+_r*1.8 or m.feet.y < position.y-0.6: return
	hits += 1
	var way := PilotMotor.forward(_heading)
	var side := Vector2(PilotMotor.forward(facing))*(-1.0 if local.z < 0.0 else 1.0)
	var out := (way*0.75-side*0.65).normalized()
	out = OlmecVoid.toward(field,m.feet,out,0.4)
	shove_pilot(m,out,float(knobs.knock_out),float(knobs.knock_up))
	_speed *= 0.8
