extends Node3D
## The Earth Mouths (card a5-earth-mouths): mouths in the
## floor (scripts/city_mouths/earth_mouth.gd) that share one belly.
##
## The rule: **they eat only dead weight, and all the mouths share one
## belly, first in, first out.**
##   Dead weight  the Olmec (a whole or headless body: always, he is stone),
##                fallen stone (scripts/city_mouths/loose_stone.gd), and the
##                wanderer only while stunned (PilotMotor move "tumble":
##                knocked, or down from a fall). Awake you walk in and out:
##                it's a dark alcove.
##   The queue    a meal at mouth n goes into the belly's back; then mouth
##                n+1 (numeral order, III wraps to I) brews (`TELL` s: the
##                lip grinds, the mist thickens into a column) and spits the
##                belly's front: the oldest thing inside. One in, one out:
##                with the belly empty, what went in comes straight back out
##                of n+1 (a passage). "I went in, HE came out."
##   You          living, the belly can't keep you: once you're in, n+1
##                goes on spitting, oldest first, `RETCH` s apart, till
##                you're out. You're last in line: if he is inside, he comes
##                out first, at the mouth you're about to come out of.
## The spit is a throw: out of the throat along the mouth's way (its +z) to
## its `spit_to` (or `SPIT_FAR` m out). The Olmec flies his own leap (its
## arc, its landing's shockwave) and lies `LIE` s in his drop landing, then
## hunts on from there; a stone is thrown as a prop (it skids where it lands);
## you are knocked (PilotMotor.knock, laid down `LIE_WANDERER` s), and fall
## damage is the motor's as ever.
## Tells (all the mouths, every frame): every mouth breathes mist while the
## belly holds anything (more, the fuller), the mouth about to spit
## steams a column, a meal is a deep gulp heard the layer over
## (`mouth_gulp`, unplaced), the spit grinds (`mouth_grind`) and coughs
## (`mouth_spit`) where it is. Their numerals (the dots on each altar) say
## which one is next.
##
## The host (a character study with an EnemyField) calls `setup`, then
## `before(delta)` before the motor steps and `after(delta)` after it, and
## asks `hides_wanderer()` for the figure and `held_olmec()` for its HUD.
## `reset()` puts the belly back as `stock` stones.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const EarthMouth = preload("res://scripts/city_mouths/earth_mouth.gd")
const LooseStone = preload("res://scripts/city_mouths/loose_stone.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")

signal ate(kind: String, mouth: int)
signal spat(kind: String, mouth: int)

## Seconds the mouth after the one fed brews before it spits.
const TELL := 1.8
## Seconds between spits while the belly is retching you out.
const RETCH := 1.3
## How long each goes down (s), and how far (m; the Olmec by his neck).
const SINK := {"olmec":1.2,"stone":0.55,"wanderer":0.7}
const SINK_DEPTH := {"stone":1.8,"wanderer":1.4}
## The Olmec's flat reach into the throat that it takes him at (m in from its
## edge: his middle well in, not a toe on the lip); yours and a stone's.
const OLMEC_IN := 0.9
const WANDERER_IN := 0.0
const STONE_IN := -0.4
## The throw: its peak over the throat (m) and, with no `spit_to`, how far.
const SPIT_UP := {"olmec":5.0,"stone":4.0,"wanderer":3.0}
const SPIT_FAR := 13.0
## Laid down after the spit (s): him in his landing; you.
const LIE := 3.0
const LIE_WANDERER := 1.0
## Not eaten again for this long after a spit (s) (out of the throat by then).
const GRACE := 2.5
## The Olmec's states it can be eaten in: on his feet on the ground.
const OLMEC_OFF := ["leap","fall","climb","mantle","grab_leap","hang","reach","triumph","windup"]

var study: Node3D
var field: Node
var motor: PilotMotor
var mouths: Array = []
## What the belly holds, oldest first: {kind, node, head, mouth, at}.
var belly: Array = []
## The belly's stones at the start (and at `reset`).
var stock := 1
var _sinking: Array = []
var _spits: Array = []
var _grace := {}
var _lie := {}
var _clock := 0.0
## Counts and the last few doings, for the HUD and checks.
var eaten := {"olmec":0,"stone":0,"wanderer":0}
var spat_n := {"olmec":0,"stone":0,"wanderer":0}
var said: Array[String] = []

func setup(host: Node3D, enemy_field: Node, m: PilotMotor) -> void:
	study = host
	field = enemy_field
	motor = m
	name = "EarthMouths"

## A mouth, numbered in the order added (I, II, III ...), at `at` facing
## `out` (x, z), spitting toward `spit_to` (or SPIT_FAR m out).
func add_mouth(at: Vector3, out: Vector2, spit_to := Vector3.INF) -> Node3D:
	var mouth: Node3D = EarthMouth.new()
	add_child(mouth)
	mouth.build(mouths.size()+1,17+mouths.size())
	mouth.position = at
	mouth.rotation.y = atan2(out.x,out.y)
	mouth.set_meta("spit_to",spit_to if spit_to != Vector3.INF else at+Vector3(out.x,0.0,out.y).normalized()*SPIT_FAR)
	mouths.append(mouth)
	return mouth

## The mouth after `i`: the one that spits when `i` is fed.
func next_of(i: int) -> int:
	return (i+1)%mouths.size()

static func roman(i: int) -> String:
	return ["I","II","III","IV","V","VI"][clampi(i,0,5)]

## The belly back as it began: `stock` stones in it (made now, held), all
## else let go (things held here that the field doesn't know are freed).
func reset() -> void:
	for item: Dictionary in belly+_sinking:
		_let_go(item)
	belly.clear()
	_sinking.clear()
	_spits.clear()
	_grace.clear()
	_lie.clear()
	said.clear()
	for k: String in eaten: eaten[k] = 0
	for k: String in spat_n: spat_n[k] = 0
	for i in stock:
		var s: Node3D = field.add(LooseStone,mouths[0].throat()-Vector3.UP*3.0 if not mouths.is_empty() else Vector3.ZERO,Vector2(0.0,1.0))
		field.enemies.erase(s)
		_hide(s)
		belly.append({"kind":"stone","node":s,"head":null,"mouth":-1,"at":-INF})
	_show_mouths()

func _let_go(item: Dictionary) -> void:
	if item.kind == "wanderer":
		return
	for n: Variant in [item.node,item.get("head")]:
		if n == null or not is_instance_valid(n): continue
		var node: Node3D = n
		if node in field.enemies: continue
		node.queue_free()

# --- The frame -------------------------------------------------------------------------------

## Before the motor: you, held, where the belly has you.
func before(_delta: float) -> void:
	for item: Dictionary in _sinking:
		if item.kind == "wanderer": _hold(item.mouth,float(item.t)/float(SINK.wanderer))
	for item: Dictionary in belly:
		if item.kind == "wanderer": _hold(item.mouth,1.0)

func _hold(i: int, k: float) -> void:
	motor.feet = mouths[i].throat()-Vector3.UP*float(SINK_DEPTH.wanderer)*k*k
	motor.velocity = Vector3.ZERO

## After the motor: what goes down, what's brewing and spat, what's eaten.
func after(delta: float) -> void:
	_clock += delta
	for key: int in _grace.keys():
		_grace[key] = float(_grace[key])-delta
		if float(_grace[key]) <= 0.0: _grace.erase(key)
	_lies()
	_sink(delta)
	_brew(delta)
	_meals()
	_show_mouths()

func _show_mouths() -> void:
	var brewing := {}
	for s: Dictionary in _spits: brewing[int(s.mouth)] = true
	var eating := {}
	for item: Dictionary in _sinking: eating[int(item.mouth)] = true
	for i in mouths.size():
		var mouth: Node3D = mouths[i]
		mouth.fullness = belly.size()
		mouth.brewing = brewing.has(i)
		mouth.gape = 1.0 if eating.has(i) else (0.55 if brewing.has(i) else 0.0)

# --- Eating ----------------------------------------------------------------------------------

func _meals() -> void:
	for i in mouths.size():
		var mouth: Node3D = mouths[i]
		for e in field.enemies.duplicate():
			if not is_instance_valid(e) or e.gone or _grace.has(e.get_instance_id()): continue
			if e.has_method("make_whole"):
				if _olmec_eatable(e,mouth): _eat_olmec(e,i)
			elif e.has_method("dead_weight"):
				if absf(e.position.y-mouth.throat().y) < 0.7 and mouth.in_throat(e.position,STONE_IN): _eat_stone(e,i)
		if _wanderer_eatable(mouth): _eat_wanderer(i)

func _olmec_eatable(b: Node3D, mouth: Node3D) -> bool:
	if b.state in OLMEC_OFF or not b.visible: return false
	if absf(b.position.y-mouth.throat().y) > 0.8: return false
	# Not while its head holds you in its mouth.
	var h: Variant = b.get("head")
	if h != null and is_instance_valid(h) and h.get("swallowed"): return false
	return mouth.in_throat(b.position,OLMEC_IN)

## Stunned (knocked or down from a fall), on the throat's floor, not held.
func _wanderer_eatable(mouth: Node3D) -> bool:
	if _grace.has(0) or motor.seized() or motor.rider != null or motor.move != "tumble": return false
	if motor.feet.y-mouth.throat().y > 0.6 or motor.feet.y < mouth.throat().y-0.5: return false
	return mouth.in_throat(motor.feet,WANDERER_IN)

func _eat_olmec(b: Node3D, i: int) -> void:
	var h: Variant = b.get("head")
	var head: Node3D = h if h != null and is_instance_valid(h) and h.get("perch") == b else null
	field.enemies.erase(b)
	b.vel = Vector3.ZERO
	_solid(b,false)
	_sinking.append({"kind":"olmec","node":b,"head":head,"mouth":i,"t":0.0,"from":b.position,"depth":float(b.get("neck_h"))*1.3+2.0})
	_gulp("olmec",i)

func _eat_stone(s: Node3D, i: int) -> void:
	field.enemies.erase(s)
	s.vel = Vector3.ZERO
	_solid(s,false)
	_sinking.append({"kind":"stone","node":s,"head":null,"mouth":i,"t":0.0,"from":s.position,"depth":float(SINK_DEPTH.stone)})
	_gulp("stone",i)

func _eat_wanderer(i: int) -> void:
	motor.seize()
	_sinking.append({"kind":"wanderer","node":null,"head":null,"mouth":i,"t":0.0,"from":motor.feet,"depth":float(SINK_DEPTH.wanderer)})
	_gulp("wanderer",i)

func _gulp(kind: String, i: int) -> void:
	eaten[kind] += 1
	mouths[i].burst()
	field.sound(&"mouth_gulp",mouths[i].throat())
	_said("%s ate %s" % [roman(i),_name(kind)])
	ate.emit(kind,i)

static func _name(kind: String) -> String:
	return {"olmec":"the Olmec","stone":"a stone","wanderer":"you"}.get(kind,kind)

## Going down: the Olmec slumps in (his head goes with him), a stone drops,
## you go limp into the dark. Down, it's in the belly, and the next mouth
## brews.
func _sink(delta: float) -> void:
	for item: Dictionary in _sinking.duplicate():
		item.t = float(item.t)+delta
		var k := clampf(float(item.t)/float(SINK[item.kind]),0.0,1.0)
		var mouth: Node3D = mouths[item.mouth]
		if item.node != null:
			var n: Node3D = item.node
			var to: Vector3 = mouth.throat()
			var from: Vector3 = item.from
			# Drawn to the middle, then down, faster as it goes.
			n.position = Vector3(lerpf(from.x,to.x,minf(k*2.0,1.0)),from.y-float(item.depth)*k*k,lerpf(from.z,to.z,minf(k*2.0,1.0)))
			if item.kind == "stone": n.rotation = Vector3(k*0.6,n.rotation.y,k*0.3)
		if k < 1.0: continue
		_sinking.erase(item)
		if item.node != null: _hide(item.node)
		if item.head != null:
			field.enemies.erase(item.head)
			_hide(item.head)
		belly.append({"kind":item.kind,"node":item.node,"head":item.head,"mouth":item.mouth,"at":_clock})
		_spits.append({"mouth":next_of(int(item.mouth)),"t":TELL})
		mouths[next_of(int(item.mouth))].burst()
		field.sound(&"mouth_grind",mouths[next_of(int(item.mouth))].throat())

func _hide(n: Node3D) -> void:
	n.visible = false
	_solid(n,false)

## Its prop body in the world (as it was) or out of it.
static func _solid(n: Node3D, on: bool) -> void:
	var b: Variant = n.get("body")
	if b == null or not is_instance_valid(b): return
	var sb: StaticBody3D = b
	if not on:
		if sb.collision_layer != 0: n.set_meta("layer_was",sb.collision_layer)
		sb.collision_layer = 0
	else: sb.collision_layer = int(n.get_meta("layer_was",1))

## Brewing: the spit `TELL` s after the meal; while you're inside, the
## belly retches on from the same mouth.
func _brew(delta: float) -> void:
	for s: Dictionary in _spits.duplicate():
		s.t = float(s.t)-delta
		if float(s.t) > 0.0: continue
		_spits.erase(s)
		# A retch is only for you: out already, it doesn't come.
		if belly.is_empty() or (s.get("retch",false) and not _wanderer_inside()): continue
		var item: Dictionary = belly.pop_front()
		_spit(item,int(s.mouth))
		if item.kind != "wanderer" and _wanderer_inside() and not _retching(int(s.mouth)): _spits.append({"mouth":int(s.mouth),"t":RETCH,"retch":true})

func _retching(i: int) -> bool:
	for s: Dictionary in _spits:
		if int(s.mouth) == i and s.get("retch",false): return true
	return false

func _wanderer_inside() -> bool:
	for item: Dictionary in belly:
		if item.kind == "wanderer": return true
	return false

## Thrown out of mouth `i`.
func _spit(item: Dictionary, i: int) -> void:
	var mouth: Node3D = mouths[i]
	var from: Vector3 = mouth.throat()+Vector3.UP*0.15
	var to: Vector3 = mouth.get_meta("spit_to")
	spat_n[item.kind] += 1
	mouth.burst()
	field.sound(&"mouth_spit",from)
	_said("%s spat %s" % [roman(i),_name(item.kind)])
	match item.kind:
		"olmec": _spit_olmec(item,from,to,mouth)
		"stone": _spit_stone(item.node,from,to)
		"wanderer": _spit_wanderer(from,to,mouth)
	spat.emit(item.kind,i)

## The throw from `from` peaking `up` over it to come down at `to`, under
## `g`: [velocity, seconds].
static func toss(from: Vector3, to: Vector3, up: float, g: float) -> Array:
	var peak := maxf(up,to.y-from.y+1.0)
	var vy := sqrt(2.0*g*peak)
	var t := vy/g+sqrt(2.0*maxf(from.y+peak-to.y,0.01)/g)
	return [Vector3((to.x-from.x)/t,vy,(to.z-from.z)/t),t]

func _spit_olmec(item: Dictionary, from: Vector3, to: Vector3, mouth: Node3D) -> void:
	var b: Node3D = item.node
	if b == null or not is_instance_valid(b): return
	var head: Node3D = item.head if item.head != null and is_instance_valid(item.head) else null
	b.visible = true
	_solid(b,true)
	b.position = from
	b.rotation = Vector3(0.0,0.0,0.0)
	var way := to-from
	b.facing = atan2(-way.x,-way.z)
	b.rotation.y = b.facing
	field.enemies.erase(b)
	field.enemies.append(b)
	if head != null:
		head.visible = true
		_solid(head,true)
		field.enemies.erase(head)
		field.enemies.append(head)
	# Off any plan he had; then his own leap (a drop's: no bulk sweep out of
	# the throat), its landing his own (dust, quake, the wave).
	b._go("listen")
	var throw := toss(from,to,float(SPIT_UP.olmec),float(b.knobs.leap_gravity))
	b.leap_kind = "drop"
	b.vel = throw[0]
	b.set("_flight",float(throw[1]))
	b.grounded = false
	b._go("leap")
	# Laid in his landing LIE s (the card's "on his back for 3 s"): his own
	# `land` knob, given back once he's up.
	_lie[b.get_instance_id()] = [b,float(b.knobs.land)]
	b.knobs.land = LIE
	_grace[b.get_instance_id()] = GRACE+float(throw[1])
	Dust.plume(field,mouth.throat(),4.0)

func _lies() -> void:
	for key: int in _lie.keys():
		var pair: Array = _lie[key]
		var b: Variant = pair[0]
		if b == null or not is_instance_valid(b):
			_lie.erase(key)
			continue
		if (b as Node3D).get("state") in ["leap","land"]: continue
		(b as Node3D).knobs.land = float(pair[1])
		_lie.erase(key)

func _spit_stone(s: Node3D, from: Vector3, to: Vector3) -> void:
	if s == null or not is_instance_valid(s): return
	s.visible = true
	_solid(s,true)
	s.position = from
	s.rotation = Vector3.ZERO
	var throw := toss(from,to,float(SPIT_UP.stone),float(s.knobs.gravity))
	s.vel = throw[0]
	s.grounded = false
	s.stun(8.0)
	field.enemies.erase(s)
	field.enemies.append(s)
	_grace[s.get_instance_id()] = GRACE+float(throw[1])

func _spit_wanderer(from: Vector3, to: Vector3, mouth: Node3D) -> void:
	motor.feet = from+Vector3.UP*0.2
	var flat := Vector2(to.x-from.x,to.z-from.z)
	var v := motor.knock_velocity(flat.normalized(),flat.length(),float(SPIT_UP.wanderer),maxf(from.y-to.y,0.0))
	motor.knock(v,mouth,LIE_WANDERER)
	_grace[0] = GRACE

# --- Asked -----------------------------------------------------------------------------------

## Whether the figure is hidden: you're down the throat, or inside.
func hides_wanderer() -> bool:
	for item: Dictionary in _sinking:
		if item.kind == "wanderer" and float(item.t) > float(SINK.wanderer)*0.6: return true
	return _wanderer_inside()

## The Olmec the belly has (going down or inside), or null.
func held_olmec() -> Node3D:
	for item: Dictionary in _sinking+belly:
		if item.kind == "olmec" and item.node != null and is_instance_valid(item.node): return item.node
	return null

func held_head() -> Node3D:
	for item: Dictionary in _sinking+belly:
		if item.kind == "olmec" and item.head != null and is_instance_valid(item.head): return item.head
	return null

## Where the belly's front comes out if mouth `i` is fed now.
func spits_next(i: int) -> int:
	return next_of(i)

func belly_text() -> String:
	var names := PackedStringArray()
	for item: Dictionary in belly: names.append({"olmec":"Olmec","stone":"stone","wanderer":"YOU"}.get(item.kind,item.kind))
	var line := "belly (oldest first): %s" % (", ".join(names) if not names.is_empty() else "empty")
	for s: Dictionary in _spits: line += " · %s spits in %.1fs" % [roman(int(s.mouth)),float(s.t)]
	return line

func _said(text: String) -> void:
	said.append("%.1f %s" % [_clock,text])
	if said.size() > 6: said.remove_at(0)
