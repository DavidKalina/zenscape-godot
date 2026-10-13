extends "res://scripts/traps/trap.gd"
## Wind (docs/design/roguelike/ideas-traps.md modules 6 Draft Vents and 8
## Gargoyle Spitter; built to the contract in scripts/traps/trap.gd): a
## narrow deck over a drop with stone mouths along its -x side that blow
## across it (+x, the way off). One trap, two trigger modes (`mode`):
##   - "vent": each mouth breathes on a timer, `on` s of wind then `off` s
##     of quiet, mouth i `stagger` s after the one before, so a crossing is
##     a timing. The sharp inhale (`tell` s of glow and a sound) comes first.
##   - "blaster": the dart corridor with air. A visible pressure plate
##     (`plate_at` along the lane) is stepped on and the mouths nearest where
##     he is (plus `lead` x his pace x `delay`, so 0 aims where he stands and
##     1 ahead of him) inhale, then `delay` s later blast for `blast_time`.
##     Keep moving and the blast lands behind him; stop and he is shoved off.
##     The plate re-arms `rearm` s after the blast. A blast is pressurized
##     air, not a breeze: the first frame he is in a firing mouth's zone it
##     knocks him (PilotMotor.knock, a tumble) `blast_out` m across and
##     `blast_up` m up, out of a hang or the sail too; once per blast.
## A mouth's wind is a zone `reach` either side of it along the lane, as
## wide as the deck and `throw` past it, pushing at `force` (m/s; harder than
## the run, so steering cannot hold against it). It goes out through
## `air_at` (the motor's `air`, which the pocket sail reads and is carried
## by); a pilot not sailing is moved by the same wind in `before` (a shove
## with `motor.carry`, not a velocity change), on the ground toward the edge,
## in the air as extra range.
##
## Knobs (times in s, sizes in m, from the pilot's walk and run): `mode`,
## `count` mouths, `reach` (run x 0.25), `width` of the deck (run x 0.6),
## `force` (run x 1.3), `throw`, `on`, `off`, `tell`, `stagger`, `delay`,
## `blast_time`, `rearm`, `plate_at`, `plate_len`, `lead`, `spread` (how far
## from the aim, in mouth spacings, a mouth fires).
const STONE := Color(0.42,0.41,0.4)
const MOUTH := Color(0.12,0.12,0.13)
const DECK := Color(0.5,0.49,0.47)
const PLATE := Color(0.3,0.3,0.34)
const MOUTH_H := 1.0
const TOP := 3.0
const BOTTOM := -1.0

## Mouth states.
const QUIET := 0
const TELL_ON := 1
const BLOWING := 2

## Blaster states.
const ARMED := 0
const COUNTDOWN := 1
const BLAST := 2
const COOLING := 3

## One record per mouth: index, z (local), state, material, particles, body.
var mouths: Array[Dictionary] = []
var clock := 0.0
var blaster_state := ARMED
var blaster_t := 0.0
var targets: Array = []
var shoves := 0
var _plate_mat: StandardMaterial3D
var _plate_node: MeshInstance3D
var _prev_feet := Vector3.ZERO
var _pace_z := 0.0
var _have_prev := false
## This blast has knocked him already.
var _blasted := false

func _init() -> void:
	super()
	trap_name = "wind"
	cost = 3
	under = "void"
	verbs = PackedStringArray(["run","time"])

func defaults() -> Dictionary:
	var p := pilot()
	var reach := p.run*0.25
	return {
		"mode":"vent","count":3,"reach":reach,"width":p.run*0.6,"force":p.run*1.3,"throw":p.run*1.5,
		"on":1.0,"off":4.0,"tell":0.3,"stagger":1.0,
		"delay":0.5,"blast_time":0.3,"rearm":2.0,"blast_out":p.run*3.0,"blast_up":p.run*0.25,"plate_at":reach,"plate_len":p.walk*0.5,"lead":0.0,"spread":0.6,
	}

func is_blaster() -> bool:
	return String(knob("mode")) == "blaster"

func spacing() -> float:
	return float(knob("reach"))*2.0

func length() -> float:
	return float(knob("count"))*spacing()

func footprint() -> Rect2:
	var w := float(knob("width"))
	return Rect2(-w*0.5,-length(),w,length())

## The direction the wind blows (world): this trap's +x.
func blow_dir() -> Vector3:
	return (global_transform.basis*Vector3.RIGHT).normalized()

func build() -> void:
	var wide := float(knob("width"))
	var long := length()
	var deck := StaticBody3D.new()
	deck.name = "Deck"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wide,0.4,long)
	shape.shape = box
	shape.position = Vector3(0.0,-0.2,-long*0.5)
	deck.add_child(shape)
	var dm := MeshInstance3D.new()
	var dmesh := BoxMesh.new()
	dmesh.size = box.size
	dm.mesh = dmesh
	dm.position = shape.position
	dm.material_override = paint(DECK)
	deck.add_child(dm)
	add_child(deck)
	var reach := float(knob("reach"))
	for i in range(int(knob("count"))):
		var z := -(reach+i*spacing())
		mouths.append(_mouth(i,z,wide))
	if is_blaster():
		_plate_mat = paint(PLATE)
		_plate_node = MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(wide*0.9,0.04,float(knob("plate_len")))
		_plate_node.mesh = pm
		_plate_node.material_override = _plate_mat
		_plate_node.position = Vector3(0.0,0.02,-float(knob("plate_at")))
		add_child(_plate_node)
	reset()

func _mouth(i: int, z: float, wide: float) -> Dictionary:
	var body := StaticBody3D.new()
	body.position = Vector3(-(wide*0.5+0.4),0.7,z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8,2.4,1.0)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	mesh.material_override = paint(STONE)
	body.add_child(mesh)
	# The dark opening on the face towards the deck.
	var hole := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.04,0.6,0.6)
	hole.mesh = hm
	var mat := paint(MOUTH)
	hole.material_override = mat
	hole.position = Vector3(0.42,MOUTH_H-0.7,0.0)
	body.add_child(hole)
	var streaks := CPUParticles3D.new()
	streaks.emitting = false
	streaks.amount = 14
	streaks.lifetime = 0.5
	streaks.direction = Vector3.RIGHT
	streaks.spread = 6.0
	streaks.initial_velocity_min = float(knob("force"))*0.8
	streaks.initial_velocity_max = float(knob("force"))
	streaks.gravity = Vector3.ZERO
	var sm := BoxMesh.new()
	sm.size = Vector3(0.5,0.03,0.03)
	streaks.mesh = sm
	streaks.material_override = paint(Color(0.85,0.9,0.95))
	streaks.position = hole.position+Vector3(0.1,0.0,0.0)
	if is_blaster():
		# A burst, not a breath: many, fast, at once.
		streaks.amount = 48
		streaks.lifetime = 0.35
		streaks.explosiveness = 0.85
		streaks.spread = 12.0
		streaks.initial_velocity_min = float(knob("blast_out"))*2.0
		streaks.initial_velocity_max = float(knob("blast_out"))*3.0
		sm.size = Vector3(0.9,0.05,0.05)
	body.add_child(streaks)
	add_child(body)
	return {"i":i,"z":z,"state":QUIET,"mat":mat,"streaks":streaks,"body":body}

## Is mouth `m` breathing now.
func blowing(m: Dictionary) -> bool:
	return int(m.state) == BLOWING

## The wind at `p` (world): the mouths blowing there (one's force, not summed).
func air_at(p: Vector3) -> Dictionary:
	var local := to_local(p)
	var wide := float(knob("width"))*0.5
	if local.x < -wide-0.5 or local.x > wide+float(knob("throw")): return {}
	if local.y < BOTTOM or local.y > TOP: return {}
	var reach := float(knob("reach"))
	for m: Dictionary in mouths:
		if blowing(m) and absf(local.z-float(m.z)) <= reach:
			return {"wind":blow_dir()*float(knob("force")),"thermal":0.0}
	return {}

func before(delta: float) -> void:
	if is_blaster(): _step_blaster(delta)
	else: _step_vent(delta)
	_dress()
	_shove(delta)

func _step_vent(delta: float) -> void:
	clock += delta
	var period := float(knob("on"))+float(knob("off"))
	for m: Dictionary in mouths:
		var t := fposmod(clock+int(m.i)*float(knob("stagger")),period)
		var s := QUIET
		if t < float(knob("on")): s = BLOWING
		elif t >= period-float(knob("tell")): s = TELL_ON
		_set_state(m,s)

func _step_blaster(delta: float) -> void:
	match blaster_state:
		COUNTDOWN:
			blaster_t += delta
			if blaster_t >= float(knob("delay")):
				blaster_state = BLAST
				blaster_t = 0.0
		BLAST:
			blaster_t += delta
			if blaster_t >= float(knob("blast_time")):
				blaster_state = COOLING
				blaster_t = 0.0
		COOLING:
			blaster_t += delta
			if blaster_t >= float(knob("rearm")):
				blaster_state = ARMED
				blaster_t = 0.0
	for m: Dictionary in mouths:
		var s := QUIET
		if targets.has(m.i):
			if blaster_state == COUNTDOWN: s = TELL_ON
			elif blaster_state == BLAST: s = BLOWING
		_set_state(m,s)

func after(delta: float, _events: Dictionary) -> void:
	if motor == null: return
	var feet := motor.feet
	_pace_z = 0.0
	if _have_prev and delta > 0.0: _pace_z = (to_local(feet).z-to_local(_prev_feet).z)/delta
	_prev_feet = feet
	_have_prev = true
	if is_blaster() and blaster_state == ARMED and plate_pressed(feet):
		_trip(to_local(feet).z)

func plate_pressed(feet: Vector3) -> bool:
	if motor == null or not motor.grounded: return false
	var local := to_local(feet)
	return absf(local.x) <= float(knob("width"))*0.5 and absf(local.z+float(knob("plate_at"))) <= float(knob("plate_len"))*0.5 and absf(local.y) < 0.25

## The plate went down with the pilot at local `z`: the mouths nearest where
## he will be at the blast (`lead` of the way he is going) take aim.
func _trip(z: float) -> void:
	var aim := z+float(knob("lead"))*_pace_z*float(knob("delay"))
	targets.clear()
	for m: Dictionary in mouths:
		if absf(float(m.z)-aim) <= spacing()*float(knob("spread")): targets.append(m.i)
	if targets.is_empty() and not mouths.is_empty():
		var best: Dictionary = mouths[0]
		for m: Dictionary in mouths:
			if absf(float(m.z)-aim) < absf(float(best.z)-aim): best = m
		targets.append(best.i)
	blaster_state = COUNTDOWN
	blaster_t = 0.0
	_blasted = false
	tell_sound(&"click",to_global(Vector3(0.0,0.0,-float(knob("plate_at")))))

func _set_state(m: Dictionary, s: int) -> void:
	if int(m.state) == s: return
	m.state = s
	var at := to_global((m.body as Node3D).position)
	if s == TELL_ON: tell_sound(&"inhale",at)
	elif s == BLOWING:
		tell_sound(&"gust",at)
		(m.streaks as CPUParticles3D).emitting = true
	if s != BLOWING: (m.streaks as CPUParticles3D).emitting = false

## The tell in colour: a mouth glows orange while it inhales, white-hot blowing.
func _dress() -> void:
	var loud := 0.0
	for m: Dictionary in mouths:
		var c := MOUTH
		match int(m.state):
			TELL_ON:
				c = TELL
				loud = maxf(loud,0.6)
			BLOWING:
				c = Color(0.9,0.95,1.0)
				loud = 1.0
		(m.mat as StandardMaterial3D).albedo_color = c
	tell_sight(loud)

func tell_sight(_amount: float) -> void:
	if _plate_mat == null: return
	var c := PLATE
	if blaster_state == COUNTDOWN: c = TELL
	elif blaster_state == ARMED: c = PLATE.lerp(TELL,0.35)
	_plate_mat.albedo_color = c
	if _plate_node != null: _plate_node.position.y = 0.0 if blaster_state != ARMED else 0.02

## Not sailing: the wind at his feet moves him, as extra range in the air or
## a shove towards the edge on the ground.
func _shove(delta: float) -> void:
	if motor == null or motor.rider != null or motor.swimming: return
	if is_blaster():
		_blast()
		return
	if motor.move == "sail" or motor.hold != "": return
	var w: Vector3 = air_at(motor.feet).get("wind",Vector3.ZERO)
	if w == Vector3.ZERO: return
	shoves += 1
	motor.carry(Transform3D(Basis.IDENTITY,w*delta),0.0)

## The blaster's bang: once per blast, a knock across the deck and off it.
func _blast() -> void:
	if blaster_state != BLAST or _blasted or air_at(motor.feet).is_empty(): return
	_blasted = true
	shoves += 1
	var way := blow_dir()
	motor.knock(motor.knock_velocity(Vector2(way.x,way.z),float(knob("blast_out")),float(knob("blast_up"))),self)

func reset() -> void:
	super()
	_blasted = false
	clock = float(knob("on"))
	blaster_state = ARMED
	blaster_t = 0.0
	targets.clear()
	shoves = 0
	_have_prev = false
	for m: Dictionary in mouths:
		m.state = QUIET
		(m.streaks as CPUParticles3D).emitting = false
		(m.mat as StandardMaterial3D).albedo_color = MOUTH
	tell_sight(0.0)
