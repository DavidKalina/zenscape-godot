extends "res://scripts/traps/trap.gd"
## Sluice Flush (docs/design/roguelike/ideas-traps.md module 5; built to the
## contract in scripts/traps/trap.gd): a walled stone channel, the
## aqueduct's (its width and parapet height, ruin_kit_aqueduct.gd CHANNEL and
## PARAPET, at the wanderer's size), with a sluice gate over its head.
## A pressure plate (or, `trigger` "timer", a wait in the channel) sets it
## off. The tell lasts `tell_time` s: the water drops to a trickle, a rising
## gurgle (`tell_sound`, three: low, mid, high) and the gate flashes the
## tell's orange. Then a wave (a translucent box of `wave_height`,
## `wave_length` long) runs down the channel at `speed`, faster than he runs,
## and carries anyone in it, below its top, along with it: `motor.carry` each
## frame, as the seesaw carries him with its body, never a teleport. Past
## the open end the floor stops at a gap (`gap`) and he falls; the pool end
## (`end` "pool") has a wall instead, and he is only swept against it.
## Counters: the refuge shelf in the channel wall is higher than the wave
## (`wave_height` 0.6 under the jump's 0.8): jump up to it and stand. Or
## ride the wave as a conveyor: a jump taken while carried keeps the wave's
## pace (the water's momentum), so the leap off the end clears the gap.
##
## Knobs: `length` of the channel (m), `gap` (m of drop at the open end), `end`
## ("open" or "pool"), `wave_height`, `wave_length` (m), `speed` (m/s),
## `tell_time` (s), `trigger` ("plate" or "timer"), `period` (s in the
## channel before a timer's tell), `plate_at` (m down the channel),
## `second_wave` (a second one `second_gap` s behind the first), `refuge`
## (shelf in the wall, 0 none), `flow` (the idle water's depth, m).
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const STONE := Color(0.5,0.49,0.47)
const WATER := Color(0.25,0.5,0.7,0.45)
const SURGE := Color(0.18,0.4,0.65,0.55)
const THICK := 0.4
const TRICKLE := 0.02
const GATE_UP := 2.4

const IDLE := 0
const TELLING := 1
const FLOWING := 2

var state := IDLE
var waves_run := 0
## Seconds since the tell began, then since the first wave was loosed.
var clock := 0.0
## Seconds waiting in the channel (the timer trigger).
var waited := 0.0
var _released := 0
var _sounds := 0
var _carried := false
var _flung := false
var _water: MeshInstance3D
var _water_mat: StandardMaterial3D
var _gate_mat: StandardMaterial3D
var _plate: MeshInstance3D
var _wave_nodes: Array[MeshInstance3D] = []

func _init() -> void:
	super()
	trap_name = "sluice"
	cost = 3
	under = "void"
	verbs = PackedStringArray(["climb","jump"])

func defaults() -> Dictionary:
	var p := pilot()
	var s := WorldScale.wanderer
	return {
		"length":p.run*6.0,"gap":p.walk,"end":"open",
		"wave_height":float(p.jumps[0])*0.75,"wave_length":p.walk*1.5,"speed":p.run*2.0,
		"tell_time":2.0,"trigger":"plate","period":4.0,"plate_at":p.run*0.9,
		"second_wave":false,"second_gap":1.5,"refuge":1,"flow":Aqueduct.PARAPET.y*s*0.5,
	}

## Channel width and parapet (height, thickness) at the wanderer's size.
func channel() -> float:
	return Aqueduct.CHANNEL*WorldScale.wanderer

func parapet() -> Vector2:
	return Aqueduct.PARAPET*WorldScale.wanderer

func pool_end() -> bool:
	return str(knob("end")) == "pool"

## The floor's length: the route's less the gap at an open end.
func channel_length() -> float:
	return float(knob("length"))

func length() -> float:
	return channel_length()+(0.0 if pool_end() else float(knob("gap")))

func footprint() -> Rect2:
	var w := channel()+parapet().y*2.0
	return Rect2(-w*0.5,-length(),w,length())

## The refuge shelf's top: the jump's height, over the wave.
func refuge_top() -> float:
	return float(pilot().jumps[0])

## Where a pilot stands on the shelf (local).
func refuge_at() -> Vector3:
	var w := channel()*0.5+parapet().y*0.75
	return Vector3(w,refuge_top(),-channel_length()*0.5)

func build() -> void:
	var L := channel_length()
	var w := channel()
	var pt := parapet()
	_box(Vector3(w+pt.y*2.0,THICK,L),Vector3(0.0,-THICK*0.5,-L*0.5),STONE.darkened(0.15),true)
	for side: float in [-1.0,1.0]:
		_box(Vector3(pt.y,pt.x,L),Vector3(side*(w*0.5+pt.y*0.5),pt.x*0.5,-L*0.5),STONE,true)
	if pool_end():
		var up := float(pilot().jumps[0])*1.25
		_box(Vector3(w,up,0.3),Vector3(0.0,up*0.5,-L-0.15),STONE,true)
	if int(knob("refuge")) > 0:
		var r := refuge_at()
		var wide := pt.y*1.5
		_box(Vector3(wide,r.y,1.6),Vector3(w*0.5+wide*0.5,r.y*0.5,r.z),STONE.lightened(0.1),true)
	# The gate: two posts on the parapets and a header over the head.
	_gate_mat = paint(STONE.lightened(0.2))
	for side: float in [-1.0,1.0]:
		_box(Vector3(pt.y,GATE_UP,0.4),Vector3(side*(w*0.5+pt.y*0.5),GATE_UP*0.5,0.0),STONE,false)
	_box(Vector3(w+pt.y*2.0,0.5,0.5),Vector3(0.0,GATE_UP+0.25,0.0),STONE,false,_gate_mat)
	_water_mat = paint(WATER)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water = _box(Vector3(w,1.0,L),Vector3(0.0,0.0,-L*0.5),STONE,false,_water_mat)
	_set_water(float(knob("flow")))
	if str(knob("trigger")) == "plate":
		_plate = _box(Vector3(w*0.8,0.06,0.7),Vector3(0.0,0.03,-float(knob("plate_at"))),Color(0.3,0.28,0.26),false)

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

## The idle water at `depth` (its top; the floor is 0).
func _set_water(depth: float) -> void:
	var d := maxf(depth,0.005)
	_water.scale = Vector3(1.0,d,1.0)
	_water.position.y = d*0.5

## Set off now (the plate, the timer, or a test).
func trigger() -> void:
	if state != IDLE: return
	state = TELLING
	clock = 0.0
	_sounds = 0

## Where wave `i` (0 the first) is: {"front","back"} z in the trap's frame,
## clipped to the channel; {} if it isn't there.
func wave_span(i: int) -> Dictionary:
	var t := clock-(float(knob("second_gap")) if i > 0 else 0.0)
	if i >= _released or t < 0.0: return {}
	var front := -float(knob("speed"))*t
	var lo := maxf(front,-channel_length())
	var hi := minf(front+float(knob("wave_length")),0.0)
	if lo >= hi: return {}
	return {"front":lo,"back":hi}

func waves_wanted() -> int:
	return 2 if bool(knob("second_wave")) else 1

## Is `local` (the trap's frame) in a wave: across the channel, in its length
## and below its top.
func in_wave(local: Vector3) -> bool:
	if absf(local.x) > channel()*0.5 or local.y >= float(knob("wave_height")) or local.y < -0.5: return false
	for i in range(_released):
		var span := wave_span(i)
		if not span.is_empty() and local.z >= float(span.front)-0.05 and local.z <= float(span.back): return true
	return false

func _in_channel(local: Vector3) -> bool:
	return absf(local.x) < channel()*0.5 and local.z < 0.0 and local.z > -channel_length() and local.y > -0.5 and local.y < 1.0

func before(delta: float) -> void:
	_carried = false
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
			_set_water(lerpf(float(knob("flow")),TRICKLE,minf(share*4.0,1.0)))
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

## The tell is over: the first wave goes.
func _loose() -> void:
	state = FLOWING
	clock = 0.0
	_released = 1
	waves_run += 1
	tell_sound(&"surge",to_global(Vector3(0.0,0.5,0.0)))
	tell_sight(1.0)

func _settle() -> void:
	state = IDLE
	waited = 0.0
	for n in _wave_nodes: n.visible = false
	_set_water(float(knob("flow")))
	tell_sight(0.0)

## Carries him along in any wave he is in (the pool end holds him at its wall).
func _sweep(delta: float, local: Vector3) -> void:
	if not in_wave(local): return
	var step := float(knob("speed"))*delta
	if pool_end(): step = clampf(local.z+channel_length()-0.5*WorldScale.wanderer,0.0,step)
	_carried = true
	var by := global_transform.basis*Vector3(0.0,0.0,-step)
	motor.carry(Transform3D(Basis.IDENTITY,by),0.0)

## A jump taken in the water keeps its pace.
func after(_delta: float, _events: Dictionary) -> void:
	if motor == null: return
	if motor.grounded: _flung = false
	elif _carried and not _flung and motor.velocity.y > 0.5:
		_flung = true
		motor.velocity += global_transform.basis*Vector3(0.0,0.0,-float(knob("speed")))

func _show_waves() -> void:
	while _wave_nodes.size() < waves_wanted():
		var mat := paint(SURGE)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wave_nodes.append(_box(Vector3.ONE,Vector3.ZERO,SURGE,false,mat))
	for i in range(_wave_nodes.size()):
		var span := wave_span(i)
		var n := _wave_nodes[i]
		n.visible = not span.is_empty()
		if span.is_empty(): continue
		var wh := float(knob("wave_height"))
		n.scale = Vector3(channel(),wh,float(span.back)-float(span.front))
		n.position = Vector3(0.0,wh*0.5,(float(span.front)+float(span.back))*0.5)

## The gate flashes the tell's orange as the tell builds.
func tell_sight(amount: float) -> void:
	if _gate_mat != null: _gate_mat.albedo_color = STONE.lightened(0.2).lerp(TELL,amount)

func reset() -> void:
	super()
	state = IDLE
	clock = 0.0
	waited = 0.0
	waves_run = 0
	_released = 0
	_sounds = 0
	_carried = false
	_flung = false
	for n in _wave_nodes: n.visible = false
	if _water != null: _set_water(float(knob("flow")))
	if _plate != null: _plate.position.y = 0.03
	tell_sight(0.0)
