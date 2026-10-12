extends "res://scripts/traps/trap.gd"
## Sluice Flush (docs/design/roguelike/ideas-traps.md module 5; built to the
## contract in scripts/traps/trap.gd; played in context on the aqueduct
## isle's channel by scripts/traps/sluice_aqueduct.gd, `--sluice`): a walled
## stone channel with a sluice gate at its head. A pressure plate (or,
## `trigger` "timer", a wait in the channel) sets it off.
##
## The tell lasts `tell_time` s and is meant to be unmissable: the channel's
## water drains away down its length (its tail running off from the gate to
## the channel's end, what is left sinking to a trickle), the gate's leaf
## rattles and grinds up in jerks, spray bursts from under it, harder as it
## goes, a deep rumble rises (a synthesized placeholder, `rumble`; the
## `tell_sound`s are three gurgles, low, mid, high) and the gate flashes the
## tell's orange. Then a wave (a translucent foamy slab `wave_height` high,
## `wave_length` long, a white crest and spray at its front) runs down the
## channel at `speed`, faster than he runs, and carries anyone standing in it
## below its top: `motor.carry` each frame (as the seesaw carries him with
## its body, never a teleport), his own pace in it only a wade (`wade`, m/s,
## against the water's), the drawn body leaning back and rocking (`pose`).
## At the channel's open end the wave spills over the gap (`gap`, a cascade
## of spray) and runs on along the floor past it (`beyond`, m, none in the
## yard), and spills again off that end. Carried off an end he leaves at the
## water's pace (`spills`), tumbling, and drops; the pool end (`end` "pool")
## has a wall instead, and he is only swept against it.
##
## Counters: a refuge over the wave (`refuges`, `refuge_top` over the
## floor, over `wave_height` and over the parapets): jump up and stand while
## it passes under. Or ride it as a conveyor: anything that leaves the water
## leaves at its pace (as a slab's pace goes with him off it), so a jump
## taken while carried keeps the wave's pace (`rides`) and, taken at the
## end, clears the gap that a body only carried off drops into.
##
## Knobs: `length` of the channel's floor (m), `gap` (m of drop at its open
## end), `beyond` (m of floor past the gap the wave runs on), `end` ("open"
## or "pool"), `walls` (true: the trap lays its own floor and parapets;
## false: in context, the host's channel is the floor), `width` (the
## channel's clear width), `parapet` (thickness, height), `cover` (the half
## width the wave covers: over the parapets), `wave_height`, `wave_length`
## (m), `speed` (m/s), `wade` (m/s, his own pace in the water), `tell_time`
## (s), `trigger` ("plate" or "timer"), `period` (s in the channel before a
## timer's tell), `plate_at` (m down the channel), `second_wave` (a second
## one `second_gap` s behind the first), `refuge` (0 none), `refuges` ([m
## down the channel, side (+1 east, -1 west)] each), `refuge_top`, `gate`
## ("header": posts and a header over the head; "side": a gatehouse on one
## parapet, `gate_side`, its top a refuge, its leaf on its inner face),
## `gate_up` (the header's height), `flow` (the idle water's depth, m).
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const STONE := Color(0.5,0.49,0.47)
const WATER := Color(0.25,0.5,0.7,0.45)
const SURGE := Color(0.55,0.75,0.88,0.6)
const FOAM := Color(0.93,0.97,1.0,0.85)
const LEAF := Color(0.36,0.27,0.2)
const THICK := 0.4
const TRICKLE := 0.02
## Past an end's edge (m) his feet still stand on its lip; flung off it,
## the rise (a share of the jump's height).
const LIP := 0.4
const FLING_UP := 0.12
## The tell's share over which the water's tail runs off down the channel.
const DRAIN_SHARE := 0.7
## The gatehouse along the channel (m) and its leaf's thickness (m).
const HOUSE_LONG := 1.6
const LEAF_THICK := 0.12
## The rocking of the carried body: lean back (radians), roll, its rate (Hz);
## the tumble off an end (turns a second) and how long it is drawn (s).
const LEAN := 0.28
const ROCK := 0.14
const ROCK_HZ := 2.2
const TUMBLE_TURNS := 1.4
const TUMBLE_TIME := 0.9
## The rumble's sample rate.
const RUMBLE_RATE := 22050

const IDLE := 0
const TELLING := 1
const FLOWING := 2

var state := IDLE
var waves_run := 0
## Seconds since the tell began, then since the first wave was loosed.
var clock := 0.0
## Seconds waiting in the channel (the timer trigger).
var waited := 0.0
## Counted: jumps out of the water (its pace kept), and bodies carried off
## an end.
var rides := 0
var spills := 0
## Seconds carried, all told.
var swept := 0.0
## Where the idle water's tail is now (m down the channel; 0 full).
var drained := 0.0
var _released := 0
var _sounds := 0
var _carried := false
var _was_carried := false
var _carry_t := 0.0
var _tumble_t := 0.0
var _water: MeshInstance3D
var _water_mat: StandardMaterial3D
var _gate_mat: StandardMaterial3D
var _leaf: MeshInstance3D
var _leaf_home := Vector3.ZERO
var _plate: MeshInstance3D
var _waves: Array = []
var _gate_spray: CPUParticles3D
var _lips: Array = []
var _rumble: AudioStreamPlayer3D
var _rumble_wav: AudioStreamWAV
## The host's own water (in context), hidden while the trap's drains.
var _host_water: Node3D = null

func _init() -> void:
	super()
	trap_name = "sluice"
	cost = 3
	under = "void"
	verbs = PackedStringArray(["climb","jump"])

func defaults() -> Dictionary:
	var p := pilot()
	var s := WorldScale.wanderer
	var width := Aqueduct.CHANNEL*s
	var parapet := Aqueduct.PARAPET*s
	return {
		"length":p.run*6.0,"gap":p.walk,"beyond":0.0,"end":"open",
		"walls":true,"width":width,"parapet":parapet,"cover":width*0.5+parapet.x,
		"wave_height":float(p.jumps[0])*0.75,"wave_length":p.walk*1.5,"speed":p.run*2.0,"wade":p.walk,
		"tell_time":2.0,"trigger":"plate","period":4.0,"plate_at":p.run*0.9,
		"second_wave":false,"second_gap":1.5,
		"refuge":1,"refuges":[[p.run*3.0,1.0]],"refuge_top":float(p.jumps[0]),
		"gate":"header","gate_side":-1.0,"gate_up":float(p.jumps[1])*1.6,
		"flow":parapet.y*0.5,
	}

## Channel width and parapet (thickness, height).
func channel() -> float:
	return float(knob("width"))

func parapet() -> Vector2:
	return knob("parapet")

func pool_end() -> bool:
	return str(knob("end")) == "pool"

## The channel's floor before the gap.
func channel_length() -> float:
	return float(knob("length"))

## Where the floor past the gap starts, and where the wave's run ends.
func far_start() -> float:
	return channel_length()+float(knob("gap"))

func run_end() -> float:
	if pool_end(): return channel_length()
	return far_start()+float(knob("beyond"))

func length() -> float:
	return channel_length() if pool_end() else run_end()

func footprint() -> Rect2:
	var w := float(knob("cover"))*2.0
	return Rect2(-w*0.5,-length(),w,length())

## Whether `along` (m down the route) has floor under it.
func on_floor(along: float) -> bool:
	if along < 0.0: return false
	if along <= channel_length(): return true
	return not pool_end() and along >= far_start() and along <= run_end()

## The refuges' top: over the wave and the parapets.
func refuge_top() -> float:
	return float(knob("refuge_top"))

## Where a pilot stands on each refuge (local): the gatehouse's top first
## (a "side" gate), then each of `refuges`.
func refuge_spots() -> Array:
	var out: Array = []
	if int(knob("refuge")) <= 0: return out
	if str(knob("gate")) == "side":
		out.append(Vector3(float(knob("gate_side"))*(channel()*0.5+_house_wide()*0.5),refuge_top(),-HOUSE_LONG*0.5-0.2))
	for r: Array in knob("refuges"):
		out.append(Vector3(float(r[1])*(channel()*0.5+_refuge_wide()*0.5),refuge_top(),-float(r[0])))
	return out

## The first refuge in the channel (the yard's shelf).
func refuge_at() -> Vector3:
	var spots := refuge_spots()
	return spots[-1] if not spots.is_empty() else Vector3.ZERO

func _refuge_wide() -> float:
	return parapet().x*2.5

func _house_wide() -> float:
	return parapet().x*2.5

func build() -> void:
	var L := channel_length()
	var w := channel()
	var pt := parapet()
	if bool(knob("walls")):
		_box(Vector3(w+pt.x*2.0,THICK,L),Vector3(0.0,-THICK*0.5,-L*0.5),STONE.darkened(0.15),true)
		for side: float in [-1.0,1.0]:
			_box(Vector3(pt.x,pt.y,L),Vector3(side*(w*0.5+pt.x*0.5),pt.y*0.5,-L*0.5),STONE,true)
		if pool_end():
			var up := float(pilot().jumps[0])*1.25
			_box(Vector3(w,up,0.3),Vector3(0.0,up*0.5,-L-0.15),STONE,true)
	# The refuges: blocks on the parapet, their tops over the wave.
	if int(knob("refuge")) > 0:
		for r: Array in knob("refuges"):
			var side := float(r[1])
			var wide := _refuge_wide()
			var top := refuge_top()
			_box(Vector3(wide,top,1.6),Vector3(side*(w*0.5+wide*0.5),top*0.5,-float(r[0])),STONE.lightened(0.1),true)
	_gate_mat = paint(STONE.lightened(0.2))
	if str(knob("gate")) == "side": _build_gatehouse()
	else: _build_header()
	_water_mat = paint(WATER)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water = _box(Vector3(w,1.0,1.0),Vector3.ZERO,STONE,false,_water_mat)
	_set_water(float(knob("flow")),0.0)
	# In context the host's water shows till the tell.
	_water.visible = _host_water == null
	if str(knob("trigger")) == "plate":
		_plate = _box(Vector3(w*0.8,0.06,0.7),Vector3(0.0,0.03,-float(knob("plate_at"))),Color(0.3,0.28,0.26),false)
		var ring := _box(Vector3(w*0.5,0.065,0.35),Vector3.ZERO,STONE,false,paint(STONE.darkened(0.4)))
		ring.reparent(_plate,false)
	_gate_spray = _spray(60,Vector3(0.0,2.0,-4.0),Vector3(0.5,0.25,0.3),0.9)
	add_child(_gate_spray)
	_gate_spray.position = _gate_mouth()
	# The cascades over the ends (the gap's lip, and the end past it).
	for along: float in ([channel_length()] if pool_end() else [channel_length(),run_end()]):
		var lip := _spray(140,Vector3(0.0,0.5,-float(knob("speed"))*0.6),Vector3(float(knob("cover")),float(knob("wave_height"))*0.5,0.3),1.4)
		add_child(lip)
		lip.position = Vector3(0.0,float(knob("wave_height"))*0.5,-along)
		_lips.append(lip)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.name = "Rumble"
	_rumble_wav = rumble_stream(float(knob("tell_time"))+1.5)
	_rumble.unit_size = 30.0
	_rumble.max_db = 6.0
	add_child(_rumble)
	_rumble.position = _gate_mouth()

## The yard's gate: two posts on the parapets and a header over the head,
## the leaf hung in it.
func _build_header() -> void:
	var w := channel()
	var pt := parapet()
	var up := float(knob("gate_up"))
	for side: float in [-1.0,1.0]:
		_box(Vector3(pt.x,up,0.4),Vector3(side*(w*0.5+pt.x*0.5),up*0.5,0.0),STONE,false)
	_box(Vector3(w+pt.x*2.0,0.5,0.5),Vector3(0.0,up+0.25,0.0),STONE,false,_gate_mat)
	_leaf_home = Vector3(0.0,up-0.25,0.0)
	_leaf = _box(Vector3(w,0.5,LEAF_THICK),_leaf_home,LEAF,false)

## In context: a gatehouse on the `gate_side` parapet, the castellum's feed
## coming into it; its leaf on the channel side, its top a refuge.
func _build_gatehouse() -> void:
	var side := float(knob("gate_side"))
	var wide := _house_wide()
	var top := refuge_top()
	var x := side*(channel()*0.5+wide*0.5)
	_box(Vector3(wide,top,HOUSE_LONG),Vector3(x,top*0.5,-HOUSE_LONG*0.5-0.2),STONE.lightened(0.05),true)
	# Its lintel, the tell's flash.
	_box(Vector3(wide+0.1,0.16,HOUSE_LONG+0.1),Vector3(x,top-0.08,-HOUSE_LONG*0.5-0.2),STONE,false,_gate_mat)
	# The leaf, in the house's inner face, shut to a crack under it.
	var leaf_h := top*0.7
	_leaf_home = Vector3(side*(channel()*0.5-LEAF_THICK*0.5),leaf_h*0.5+0.04,-HOUSE_LONG*0.5-0.2)
	_leaf = _box(Vector3(LEAF_THICK,leaf_h,HOUSE_LONG*0.7),_leaf_home,LEAF,false)

## Where the water comes out of the gate (local).
func _gate_mouth() -> Vector3:
	if str(knob("gate")) == "side":
		return Vector3(float(knob("gate_side"))*channel()*0.45,0.1,-HOUSE_LONG*0.5-0.2)
	return Vector3(0.0,0.1,-0.3)

## A box of `size` at local `at`; solid ones collide.
func _box(size: Vector3, at: Vector3, colour: Color, solid: bool, mat: StandardMaterial3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = at
	mesh.material_override = mat if mat != null else paint(colour)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mesh.add_child(body)
	add_child(mesh)
	return mesh

## White spray: `amount` balls flung at `velocity` (local) from a box of
## `extent` (half sizes), living `life` s. Off till told.
static func _spray(amount: int, velocity: Vector3, extent: Vector3, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.18
	ball.radial_segments = 6
	ball.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = FOAM
	ball.material = m
	p.mesh = ball
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.direction = velocity.normalized() if velocity.length() > 0.01 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = velocity.length()*0.6
	p.initial_velocity_max = velocity.length()*1.1
	p.gravity = Vector3(0.0,-9.8,0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	return p

## The idle water: `depth` deep (its top; the floor is 0), its tail `tail`
## m down the channel (what has drained off ahead of it).
func _set_water(depth: float, tail: float) -> void:
	var d := maxf(depth,0.005)
	var L := channel_length()
	tail = clampf(tail,0.0,L-0.05)
	_water.scale = Vector3(1.0,d,L-tail)
	_water.position = Vector3(0.0,d*0.5,-(tail+L)*0.5)
	drained = tail

## In context: the host's water (the channel's own), hidden while this one
## drains and runs; set before the trap is added.
func adopt_water(node: Node3D) -> void:
	_host_water = node

## Set off now (the plate, the timer, or a test).
func trigger() -> void:
	if state != IDLE: return
	state = TELLING
	clock = 0.0
	_sounds = 0
	drained = 0.0
	if _host_water != null:
		_host_water.visible = false
		_water.visible = true
	_gate_spray.emitting = true
	_rumble.stream = _rumble_wav
	_rumble.play()

## Where wave `i` (0 the first) is: {"front","back"} z in the trap's frame,
## clipped to its run; {} if it isn't there.
func wave_span(i: int) -> Dictionary:
	var t := clock-(float(knob("second_gap")) if i > 0 else 0.0)
	if i >= _released or t < 0.0: return {}
	var front := -float(knob("speed"))*t
	var lo := maxf(front,-run_end())
	var hi := minf(front+float(knob("wave_length")),0.0)
	if lo >= hi: return {}
	return {"front":lo,"back":hi}

func waves_wanted() -> int:
	return 2 if bool(knob("second_wave")) else 1

## Is `local` (the trap's frame) in a wave: across what it covers, over
## floor, in its length and below its top.
func in_wave(local: Vector3) -> bool:
	return not _wave_at(local).is_empty()

## The span of the wave `local` is in, or {}.
func _wave_at(local: Vector3) -> Dictionary:
	if absf(local.x) > float(knob("cover")) or local.y >= float(knob("wave_height")) or local.y < -0.5: return {}
	# Over floor, or standing on its lip (his body past the end).
	if not on_floor(-local.z) and not on_floor(-local.z-LIP*WorldScale.wanderer): return {}
	for i in range(_released):
		var span := wave_span(i)
		if not span.is_empty() and local.z >= float(span.front)-0.05 and local.z <= float(span.back): return span
	return {}

func _in_channel(local: Vector3) -> bool:
	return absf(local.x) < channel()*0.5 and local.z < 0.0 and local.z > -channel_length() and local.y > -0.5 and local.y < 1.0

## The way down the channel (world).
func _down() -> Vector3:
	return global_transform.basis*Vector3(0.0,0.0,-1.0)

func before(delta: float) -> void:
	_was_carried = _carried
	_carried = false
	_tumble_t = maxf(0.0,_tumble_t-delta)
	if motor == null: return
	var local := to_local(motor.feet)
	match state:
		IDLE:
			if str(knob("trigger")) == "plate":
				var on := motor.grounded and absf(local.x) < channel()*0.4 and absf(local.z+float(knob("plate_at"))) < 0.35 and local.y < 0.3
				_plate.position.y = 0.0 if on else 0.03
				if on: trigger()
			elif _in_channel(local):
				waited += delta
				if waited >= float(knob("period")): trigger()
		TELLING:
			clock += delta
			var tt := maxf(float(knob("tell_time")),0.01)
			var share := clampf(clock/tt,0.0,1.0)
			_tell_step(share)
			var kinds: Array[StringName] = [&"gurgle_low",&"gurgle_mid",&"gurgle_high"]
			var marks := [0.0,0.5,0.8]
			while _sounds < 3 and share >= float(marks[_sounds]):
				tell_sound(kinds[_sounds],to_global(Vector3(0.0,0.5,-channel_length()*0.5)))
				_sounds += 1
			tell_sight(share)
			if clock >= tt: _loose()
		FLOWING:
			clock += delta
			if _released < waves_wanted() and clock >= float(knob("second_gap"))*float(_released):
				_released += 1
				tell_sound(&"surge",to_global(Vector3(0.0,0.5,0.0)))
			_show_waves()
			_sweep(delta,local)
			var done := true
			for i in range(waves_wanted()):
				if i >= _released or not wave_span(i).is_empty(): done = false
			if done: _settle()

## The tell at `share` (0 to 1): the water's tail running off down the
## channel, what is left sinking; the leaf rattling, grinding up in jerks;
## the spray from under it harder.
func _tell_step(share: float) -> void:
	var drain := clampf(share/DRAIN_SHARE,0.0,1.0)
	var eased := drain*drain*(3.0-2.0*drain)
	_set_water(lerpf(float(knob("flow")),TRICKLE,minf(share*2.0,1.0)),channel_length()*eased)
	if _leaf != null:
		var jerk := floorf(share*5.0)/5.0
		var shake := sin(clock*53.0)*0.025*(0.3+share)
		_leaf.position = _leaf_home+Vector3(shake,refuge_top()*0.15*jerk if str(knob("gate")) == "side" else 0.12*jerk,shake*0.5)
	_gate_spray.set("amount_ratio",0.25+0.75*share)

## The tell is over: the first wave goes, the leaf flung up.
func _loose() -> void:
	state = FLOWING
	clock = 0.0
	_released = 1
	waves_run += 1
	_set_water(TRICKLE,channel_length())
	_water.visible = false
	if _leaf != null: _leaf.position = _leaf_home+Vector3.UP*(refuge_top()*0.6 if str(knob("gate")) == "side" else 0.0)
	_gate_spray.set("amount_ratio",1.0)
	tell_sound(&"surge",to_global(Vector3(0.0,0.5,0.0)))
	tell_sight(1.0)

func _settle() -> void:
	state = IDLE
	waited = 0.0
	for w: Dictionary in _waves:
		for key: String in ["near","far","crest","front"]: w[key].visible = false
		(w.spray as CPUParticles3D).emitting = false
	for lip: CPUParticles3D in _lips: lip.emitting = false
	_gate_spray.emitting = false
	_quiet()
	if _leaf != null: _leaf.position = _leaf_home
	_set_water(float(knob("flow")),0.0)
	_water.visible = _host_water == null
	if _host_water != null: _host_water.visible = true
	tell_sight(0.0)

## Carries him along in any wave he stands in (the pool end holds him at
## its wall): moved with the water, his own pace in it (the water's taken
## off as he comes into it) only a wade.
func _sweep(delta: float, local: Vector3) -> void:
	if not motor.grounded: return
	var span := _wave_at(local)
	if span.is_empty(): return
	# Never carried past its front (out ahead of it on his own, he goes on
	# at its pace: `after`).
	var step := clampf(local.z-float(span.front),0.0,float(knob("speed"))*delta)
	if pool_end(): step = clampf(local.z+channel_length()-0.5*WorldScale.wanderer,0.0,step)
	# Carried over an end's edge: flung off it at the water's pace, a little up.
	if not on_floor(-local.z+step):
		_fling(local)
		return
	var down := Vector2(_down().x,_down().z)
	var own := Vector2(motor.velocity.x,motor.velocity.z)
	if not _was_carried: own -= down*clampf(own.dot(down),0.0,float(knob("speed")))
	var wade := float(knob("wade"))
	if own.length() > wade: own = own.normalized()*wade
	motor.velocity.x = own.x
	motor.velocity.z = own.y
	_carried = true
	_carry_t += delta
	swept += delta
	motor.carry(Transform3D(Basis.IDENTITY,_down()*step),0.0)

## Out of the water ahead of it (a jump, carried off an end, or out past
## its front), the water's pace goes with him, as a slab's does; out of its
## back, his own pace is all he has.
func after(_delta: float, events: Dictionary) -> void:
	if motor == null: return
	if _carried:
		var local := to_local(motor.feet)
		var air := not motor.grounded and motor.hold == ""
		if air or (motor.grounded and not in_wave(local) and _ahead(local)):
			var pace := _down()*float(knob("speed"))
			motor.velocity.x += pace.x
			motor.velocity.z += pace.z
			if events.has("jumped"): rides += 1
			_carried = false
	if not _carried: _carry_t = 0.0

## Carried onto an end's lip: tossed off it (no catching the lip, no jump
## left: a twirl or the sail still) at the water's pace, a little up, the
## body tumbling a moment.
func _fling(_local: Vector3) -> void:
	var down := _down()*float(knob("speed"))
	var up := sqrt(2.0*motor.gravity*float(pilot().jumps[0])*FLING_UP)
	motor.toss(Vector3(motor.velocity.x+down.x,up,motor.velocity.z+down.z))
	spills += 1
	_tumble_t = TUMBLE_TIME
	tell_sound(&"spill",motor.feet)

## Whether `local` is down the channel of every wave's front.
func _ahead(local: Vector3) -> bool:
	for i in range(_released):
		var span := wave_span(i)
		if not span.is_empty() and local.z > float(span.front): return false
	return true

## The drawn body: carried, leaning back against the water and rocking;
## carried off an end, tumbling head over heels a moment.
func pose(figure: Node3D) -> void:
	if _carried:
		var t := _carry_t
		var lean := Basis(Vector3.RIGHT,-LEAN*minf(t*4.0,1.0))
		var rock := Basis(Vector3.FORWARD,ROCK*sin(t*TAU*ROCK_HZ))
		figure.basis = figure.basis*lean*rock
	elif _tumble_t > 0.0 and not motor.grounded:
		var turned := (TUMBLE_TIME-_tumble_t)*TUMBLE_TURNS*TAU
		figure.basis = figure.basis*Basis(Vector3.RIGHT,-turned)

## Whether he is being carried this frame.
func carrying() -> bool:
	return _carried

func _show_waves() -> void:
	while _waves.size() < waves_wanted():
		var body := paint(SURGE)
		body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var foam := paint(FOAM)
		foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var spray := _spray(90,Vector3(0.0,2.6,-float(knob("speed"))*0.5),Vector3(float(knob("cover")),0.1,0.2),0.7)
		add_child(spray)
		_waves.append({"near":_box(Vector3.ONE,Vector3.ZERO,SURGE,false,body),"far":_box(Vector3.ONE,Vector3.ZERO,SURGE,false,body),
			"crest":_box(Vector3.ONE,Vector3.ZERO,FOAM,false,foam),"front":_box(Vector3.ONE,Vector3.ZERO,FOAM,false,foam),"spray":spray})
	var wh := float(knob("wave_height"))
	var cover := float(knob("cover"))*2.0
	var lip_wet: Array = [false,false]
	for i in range(_waves.size()):
		var span := wave_span(i)
		var w: Dictionary = _waves[i]
		var here := not span.is_empty()
		for key: String in ["near","far","crest","front"]: w[key].visible = false
		(w.spray as CPUParticles3D).emitting = here
		if not here: continue
		var back := -float(span.back)
		var front := -float(span.front)
		# Its body over the floor before the gap and past it.
		_slab(w.near,maxf(back,0.0),minf(front,channel_length()),wh,cover)
		if not pool_end(): _slab(w.far,maxf(back,far_start()),minf(front,run_end()),wh,cover)
		# Its crest of foam along the top, the white front.
		var head := front
		if on_floor(head) or head >= run_end() - 0.01:
			var crest_from := maxf(back,head-float(knob("wave_length"))*0.35)
			if head-crest_from > 0.05:
				(w.crest as MeshInstance3D).visible = true
				w.crest.scale = Vector3(cover*1.02,wh*0.25,head-crest_from)
				w.crest.position = Vector3(0.0,wh*0.9,-(head+crest_from)*0.5)
			if on_floor(head):
				(w.front as MeshInstance3D).visible = true
				w.front.scale = Vector3(cover*1.04,wh*1.15,0.3)
				w.front.position = Vector3(0.0,wh*0.55,-head)
		(w.spray as CPUParticles3D).position = Vector3(0.0,wh,-clampf(head,0.0,run_end()))
		# Pouring over a lip while it spans it.
		if back < channel_length() and front > channel_length(): lip_wet[0] = true
		if not pool_end() and back < run_end() and front > run_end()-0.5: lip_wet[1] = true
	for k in range(_lips.size()): (_lips[k] as CPUParticles3D).emitting = lip_wet[k]

## A wave's slab from `a` to `b` m down the run, or hidden.
func _slab(node: MeshInstance3D, a: float, b: float, height: float, wide: float) -> void:
	if b-a <= 0.02:
		node.visible = false
		return
	node.visible = true
	node.scale = Vector3(wide,height,b-a)
	node.position = Vector3(0.0,height*0.5,-(a+b)*0.5)

## The gate flashes the tell's orange as the tell builds.
func tell_sight(amount: float) -> void:
	if _gate_mat != null: _gate_mat.albedo_color = STONE.lightened(0.2).lerp(TELL,amount)

## A placeholder rumble, `seconds` long: low brown noise and a hum rising
## from a growl, the gate's rattle quickening in it, swelling to the surge.
static func rumble_stream(seconds: float) -> AudioStreamWAV:
	var n := int(seconds*RUMBLE_RATE)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var brown := 0.0
	var phase := 0.0
	var next_click := 0.0
	var click := 0.0
	for i in range(n):
		var t := float(i)/RUMBLE_RATE
		var share := clampf(t/maxf(seconds-1.5,0.1),0.0,1.0)
		brown = clampf(brown*0.996+rng.randf_range(-1.0,1.0)*0.04,-1.0,1.0)
		phase += TAU*(32.0+60.0*share*share)/RUMBLE_RATE
		if t >= next_click:
			click = 1.0
			next_click = t+1.0/(4.0+14.0*share)
		click *= 0.992
		var surge := 0.0
		if t > seconds-1.5: surge = rng.randf_range(-1.0,1.0)*clampf((t-(seconds-1.5))*3.0,0.0,1.0)*0.5
		var v := (brown*1.6+sin(phase)*0.5)*(0.25+0.6*share)+click*rng.randf_range(-1.0,1.0)*0.35+surge
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RUMBLE_RATE
	s.stereo = false
	s.data = data
	return s

## Its sound let go with it (a playing stream is held past teardown).
func _exit_tree() -> void:
	_quiet()
	_rumble_wav = null

func _quiet() -> void:
	if _rumble == null: return
	_rumble.stop()
	_rumble.stream = null

func reset() -> void:
	super()
	state = IDLE
	clock = 0.0
	waited = 0.0
	waves_run = 0
	rides = 0
	spills = 0
	swept = 0.0
	_released = 0
	_sounds = 0
	_carried = false
	_was_carried = false
	_tumble_t = 0.0
	if _water != null: _settle()
	if _plate != null: _plate.position.y = 0.03
	_quiet()
	tell_sight(0.0)
