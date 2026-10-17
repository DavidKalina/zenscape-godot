extends Node3D
## The rolling coins' track (a prototype): the lap a rolling coin
## (scripts/enemies/rolling_coin.gd) follows when it is given one. Made by
## the coin track kit (scripts/kit_isle/coin_track.gd `circuit(offset)`,
## which calls `setup_track`) from its lap samples ({p, s, leg, k, way}
## every ~0.5 m, p the bed's top) and its legs (the description's `lap`),
## set into the world at `offset`; or by `setup` from the same data.
##
## `at(s)` is the lap's point at `s` m along it: on the beds (roll, arc,
## lip) the coin rolls at `lap_speed`; over a flight (fly) it goes at its
## lip's kick along the chord, on the parabola from the lip's edge with the
## kick's up speed to the cradle's catch (the gravity that closes it is the
## flight's own). That parabola is the flight as planned: a lapping coin
## flies its own free arc (rolling_coin.gd `_lap_fly`, its `fly_gravity`)
## from the flight's `a` at its kick and lands where it lands;
## `flights[leg]` gives it the kick and the catch.
##   coin = circuit.mint(field, s)   a coin on the lap at s (field.spawn,
##                                   so the field's reset mints it again)
##
## Its coins share the lap: a lapping coin slows and stops behind a coin
## lying or stopped on the line ahead (`gap_ahead`) and waits at a lip
## while the cradle ahead is full; a coin lost off the circuit (fallen,
## dazed, or risen off the track where no gate is near) is freed and a new
## one minted into the next free cradle (`_mint_back`, counted in
## `minted_back`). Hunting is opt-in (`hunt`, the description's "hunt"):
## with it a coin that sees him on a field beside a gate leaves the lap to
## charge him, no more than `hunt_cap` at once (`hunting`), and comes home
## through the nearest gate.

const RollingCoin = preload("res://scripts/enemies/rolling_coin.gd")

## The lap's samples (world), its length, its speed on the beds.
var line: Array = []
var length := 1.0
var lap_speed := 5.04
## Each flight's leg index -> {s0, s1, a, b, vx, vy, g}.
var flights := {}
## The kerb gaps a coin leaves the lap by to hunt and comes back in by:
## {name, field, on (the line), at (the gap), out (unit, toward its field),
## s (the lap's s at `on`)}, world.
var gates: Array = []
## The field its coins are in (their list is the field's: its reset
## mints them again).
var field: Node = null
## Whether its coins leave the lap to hunt him (off: they only lap); how
## many may hunt at once; the hub (world, flat) and its radius past which a
## coin rolling home is lost; coins lost and minted back.
var hunt := false
var hunt_cap := 2
var hub_at := Vector2.ZERO
var hub_r := 16.0
var minted_back := 0
## The states a hunting coin is in (off the lap, after him or coming home).
const HUNTING := ["leave","out","stare","windup","charge","spent","crash","topple","flat","rise","home","enter"]
## Each coin's place on the line this physics frame (instance id -> s, or
## NAN off the line).
var _on_line := {}
var _on_line_frame := -1

## From a coin track (scripts/kit_isle/coin_track.gd), set at `offset`:
## its lap, legs, speed and gates; its "hunt", "hunt_cap" and "hub".
func setup_track(track: RefCounted, offset := Vector3.ZERO) -> void:
	var d: Dictionary = track.data
	setup(track.lap_line(),d.lap,track.lap_length(),float(d.lap_speed),offset,d.get("gates",[]))
	hunt = bool(d.get("hunt",false))
	hunt_cap = int(d.get("hunt_cap",hunt_cap))
	var h: Dictionary = d.get("hub",{})
	hub_at = Vector2(offset.x,offset.z)+(h.get("at",Vector2.ZERO) as Vector2)
	hub_r = float(h.get("r",hub_r))

## From lap samples, their legs and their speed, set at `offset`.
func setup(samples: Array, legs: Array, total: float, speed: float, offset: Vector3, gate_list := []) -> void:
	lap_speed = speed
	length = total
	hub_at = Vector2(offset.x,offset.z)
	line.clear()
	for q: Dictionary in samples:
		var d := q.duplicate()
		d.p = (q.p as Vector3)+offset
		line.append(d)
	flights.clear()
	for i in line.size():
		var q: Dictionary = line[i]
		if q.k != "fly" or flights.has(q.leg): continue
		var leg: Dictionary = legs[int(q.leg)]
		var lip: Dictionary = legs[posmod(int(q.leg)-1,legs.size())]
		var kick: Vector2 = lip.get("kick",Vector2(speed,0.0))
		var a: Vector3 = (leg.a as Vector3)+offset
		var b: Vector3 = (leg.b as Vector3)+offset
		var chord := Vector2(b.x-a.x,b.z-a.z).length()
		var t := chord/maxf(kick.x,0.1)
		# The gravity that brings the kick's up speed down onto the catch.
		var g := 2.0*(kick.y*t-(b.y-a.y))/(t*t)
		flights[q.leg] = {"s0":float(q.s),"s1":float(q.s)+chord,"a":a,"b":b,"vx":kick.x,"vy":kick.y,"g":g,"name":str(leg.get("name",""))}
	gates.clear()
	for g: Dictionary in gate_list:
		var on: Vector3 = (g.on as Vector3)+offset
		var best := 0
		for i in line.size():
			var p: Vector3 = line[i].p
			var bp: Vector3 = line[best].p
			if Vector2(p.x-on.x,p.z-on.z).length() < Vector2(bp.x-on.x,bp.z-on.z).length(): best = i
		gates.append({"name":str(g.get("name","")),"field":str(g.get("field","")),"on":(line[best].p as Vector3),"at":(g.at as Vector3)+offset,"out":(g.out as Vector3).normalized(),"s":float(line[best].s)})

## How far ahead along the lap `to` is from `from` (m, 0..length).
func ahead(from: float, to: float) -> float:
	return fposmod(to-from,length)

## Whether a flight lies between `from` and `from`+`d` along the lap.
func flight_between(from: float, d: float) -> bool:
	var x := 0.0
	while x <= d:
		if not flight_at(from+x).is_empty(): return true
		x += 1.0
	return false

## The lap's sample nearest `p` (flat, off the flights): {s, p, way, d}.
func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for q: Dictionary in line:
		if q.k == "fly": continue
		var at: Vector3 = q.p
		var d := Vector2(at.x-p.x,at.z-p.z).length()
		if d < bd:
			bd = d
			best = {"s":float(q.s),"p":at,"way":q.way,"d":d}
	return best

## The gate nearest `p` (flat), {} if none.
func nearest_gate(p: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for g: Dictionary in gates:
		var at: Vector3 = g.at
		var d := Vector2(at.x-p.x,at.z-p.z).length()
		if d < bd:
			bd = d
			best = g
	return best

## Whether the lap has room at `s` for a coin to come in: no lapping coin
## from `behind` m before it to `front` m past it (but `me`).
func room_at(s: float, me: Node, behind := 9.0, front := 4.0) -> bool:
	for c: Node in coins():
		if c == me or c.get("state") not in ["lap","leave"]: continue
		var d := ahead(float(c.lap_s),s)
		if d < behind or length-d < front: return false
	return true

## The speed along the lap at `s` (m/s): the lap's, or a flight's kick.
func speed_at(s: float) -> float:
	var f := flight_at(s)
	return lap_speed if f.is_empty() else float(f.vx)

## The flight `s` is in, {} on the beds.
func flight_at(s: float) -> Dictionary:
	s = fposmod(s,length)
	for f: Dictionary in flights.values():
		if s >= float(f.s0) and s < float(f.s1): return f
	return {}

## The lap at `s`: {p (world, the coin's feet), way (flat, unit), k, leg,
## air (true over a flight)}.
func at(s: float) -> Dictionary:
	s = fposmod(s,length)
	var f := flight_at(s)
	if not f.is_empty():
		var t := (s-float(f.s0))/float(f.vx)
		var k := (s-float(f.s0))/maxf(float(f.s1)-float(f.s0),0.001)
		var a: Vector3 = f.a
		var b: Vector3 = f.b
		var p := a.lerp(b,k)
		p.y = a.y+float(f.vy)*t-0.5*float(f.g)*t*t
		var w := Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
		return {"p":p,"way":w,"k":"fly","leg":-1,"air":true}
	var i := _index(s)
	var q: Dictionary = line[i]
	var n: Dictionary = line[(i+1)%line.size()]
	var s1 := float(n.s) if i+1 < line.size() else length
	var k := clampf((s-float(q.s))/maxf(s1-float(q.s),0.001),0.0,1.0)
	var way: Vector3 = (q.way as Vector3).lerp(n.way,k)
	if way.length() < 0.01: way = q.way
	return {"p":(q.p as Vector3).lerp(n.p,k),"way":way.normalized(),"k":str(q.k),"leg":int(q.leg),"air":false}

## The last sample at or before `s`.
func _index(s: float) -> int:
	var lo := 0
	var hi := line.size()-1
	while lo < hi:
		var mid := (lo+hi+1)/2
		if float(line[mid].s) <= s: lo = mid
		else: hi = mid-1
	return lo

## A coin on the lap at `s` m, off a flight (the field's spawn: its reset
## mints it again; `keep` false: the field's add, gone on its reset).
func mint(on: Node, s: float, overrides := {}, keep := true) -> Node3D:
	field = on
	s = fposmod(s,length)
	var f := flight_at(s)
	if not f.is_empty(): s = fposmod(float(f.s1)+0.5,length)
	var q := at(s)
	var o := {"circuit":self,"lap_s":s}
	o.merge(overrides,true)
	var face := Vector2((q.way as Vector3).x,(q.way as Vector3).z)
	if keep: return field.spawn(RollingCoin,q.p,face,o)
	return field.add(RollingCoin,q.p,face,o)

## The live coins on this circuit (the field's).
func coins() -> Array:
	if field == null: return []
	return field.enemies.filter(func(e) -> bool: return is_instance_valid(e) and not e.gone and e.get("circuit") == self)

## How many coins hunt now (but `me`).
func hunting(me: Node = null) -> int:
	var n := 0
	for c: Node in coins():
		if c != me and c.state in HUNTING: n += 1
	return n

## Where `c` is on the line this frame: its lap s lapping, else the line's
## s it lies on (within 1.2 m, its feet on the bed: where it would rejoin);
## NAN aloft, off the line, or waiting at a gate's mouth.
func line_s(c: Node) -> float:
	var f := Engine.get_physics_frames()
	if f != _on_line_frame:
		_on_line.clear()
		_on_line_frame = f
	var id := c.get_instance_id()
	if _on_line.has(id): return _on_line[id]
	var s := NAN
	if c.aloft or c.get("_falling"): s = NAN
	elif c.state in ["lap","leave"]: s = float(c.lap_s)
	elif c.state == "enter" and (c.get("_path") as Array).is_empty(): s = NAN
	else:
		var q := nearest(c.position)
		if not q.is_empty() and float(q.d) < 1.2 and absf(c.position.y-(q.p as Vector3).y) < 0.3: s = float(q.s)
	_on_line[id] = s
	return s

## How far along the lap from `me` (lapping) the nearest coin on the line
## ahead is (INF: none within `reach`).
func gap_ahead(me: Node, reach := 20.0) -> float:
	var best := INF
	for c: Node in coins():
		if c == me: continue
		var s := line_s(c)
		if is_nan(s): continue
		var d := ahead(float(me.lap_s),s)
		if d > 0.01 and d < reach and d < best: best = d
	return best

## The next flight starting within `reach` ahead of `from`, {} none.
func next_flight(from: float, reach: float) -> Dictionary:
	var best := {}
	var bd := INF
	for f: Dictionary in flights.values():
		var d := ahead(from,float(f.s0))
		if d < reach and d < bd:
			bd = d
			best = f
	return best

## Whether a flight's cradle is clear to land in: no coin on the line from
## just short of its catch to `past` m beyond it (but `me`).
func landing_clear(f: Dictionary, me: Node, past: float) -> bool:
	for c: Node in coins():
		if c == me: continue
		var s := line_s(c)
		if is_nan(s): continue
		var d := ahead(float(f.s1)-1.0,s)
		if d < past+1.0: return false
	return true

# --- Lost coins ----------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if field == null or not is_instance_valid(field): return
	var live := coins()
	for c: Node in live.duplicate():
		if _lost(c):
			_free(c)
			live.erase(c)
	# As many as its spawns (the field's specs): one fell off the world or
	# was freed, a new one into a cradle.
	var want := 0
	for sp: Array in field.specs:
		if (sp[3] as Dictionary).get("circuit") == self: want += 1
	if live.size() < want: _mint_back()

## Off the circuit for good: dazed or strolling after a fall, or rolling
## home off the hub (no gate on its isle).
func _lost(c: Node) -> bool:
	if c.state in ["dazed","scoot"]: return true
	if c.state == "home":
		if Vector2(c.position.x,c.position.z).distance_to(hub_at) > hub_r: return true
		if float(c.state_t) > 30.0: return true
	return false

## A lost coin taken off the field.
func _free(c: Node) -> void:
	field.enemies.erase(c)
	if c.get_parent() != null: c.get_parent().remove_child(c)
	c.queue_free()

## A coin minted into the next free cradle (a catch with room on the lap,
## him not on it).
func _mint_back() -> void:
	minted_back += 1
	var him: Vector3 = field.motor.feet if field.motor != null else Vector3(INF,0,INF)
	var catches: Array = []
	for f: Dictionary in flights.values(): catches.append(float(f.s1)+1.0)
	catches.sort()
	var pick := -1.0
	for s: float in catches:
		var p: Vector3 = at(s).p
		if room_at(s,null,9.0,9.0) and Vector2(p.x-him.x,p.z-him.z).length() > 8.0:
			pick = s
			break
	if pick < 0.0: pick = catches[minted_back%catches.size()]
	field.sound(&"head_thud",at(pick).p)
	mint(field,pick,{},false)
