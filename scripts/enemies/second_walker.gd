extends Node3D
## The Second Walker (round 4 card h2): "Came in by the same door you
## did. Has no road of his own." A clay figure the wanderer's size that
## walks his exact footprints, in order, with his timing, `delay` s behind.
##
## The rule, all of it from the trail (scripts/enemies/foot_trail.gd):
## - **Seated** in its niche (`seat`, facing `seat_face`, the way you came
##   in), it wakes when a wanderer walks past (WAKE walker heights). It
##   follows that one from then on, never "the player" (co-op: whoever
##   woke it; `follow(motor)` picks one by hand).
## - **Rising**, it gets up (RISE s) while his trail starts filling.
## - **Walking**, it is wherever he was `delay` s ago, in his pose: his
##   run, jumps, wall kicks, hangs and climbs, played by his own clips on
##   a clay body (scripts/enemies/clay_figure.gd) from a stand-in motor.
##   There is no AI: no steering, no motor of its own.
## - **The catch.** Stand still `delay` s and it arrives where you stand
##   and steps into your place: a knock out of it and a heart (`harm`
##   "walker"). Then it **sits** on the spot SIT s (your head start), and
##   gets up again, its delay shortened, 8 then 6 then 4 s (DELAYS). Behind
##   its delay (after a sit) it walks the trail CATCH_UP times faster, so
##   its steps come quicker, until it is back at its leash.
## - **The fall.** Each footprint it reaches is looked for again (the
##   ground under where he stood, the lip he hung from). If it has gone
##   since (a slab dropped, a column broke), it takes the step anyway and
##   **falls**: tumbling at his gravity until it meets the ground, where it
##   **breaks** into sherds, or the void. REFORM s later it is seated in
##   its niche again, asleep.
##
## The tell: sight, a pale figure re-doing your last climb; sound, your own
## footsteps come back eight seconds late in clay (a hollow *tok* at each
## of its footfalls, a heavier one landing, a dry scrape at each grab),
## heard through `sound_hook` (StringName, Vector3) and `sounded`, so a
## noise bus can take them (a listener goes to where you WERE).
##
## Stepped by its host (`step(delta)`, after the wanderers' own step), set
## up with `setup(seat, seat_face, wanderers)`. It has no collider: the
## Olmec can't see or swat it yet.
const FootTrail = preload("res://scripts/enemies/foot_trail.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const ClayFigure = preload("res://scripts/enemies/clay_figure.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

signal sounded(kind: StringName, at: Vector3)
signal caught(wanderer: Object)
signal fell(at: Vector3)
signal broke(at: Vector3)
signal woke(wanderer: Object)

## Its leash after 0, 1, 2+ catches (s).
const DELAYS := [8.0,6.0,4.0]
## Seconds it sits after a catch; seconds getting up out of its niche.
const SIT := 4.0
const RISE := 1.2
## Woken by a wanderer this many walker heights away (flat), within
## WAKE_UP of its height.
const WAKE := 2.6
const WAKE_UP := 2.0
## The catch: within CATCH walker radii (flat) and CATCH_UP_DOWN m up or
## down of his feet. The knock out of it: KNOCK_OUT walker heights along
## its way, KNOCK_UP up.
const CATCH := 1.8
const CATCH_UP_DOWN := 0.9
const KNOCK_OUT := 2.6
const KNOCK_UP := 0.7
## Trail seconds a second while behind its leash.
const CATCH_UP := 1.6
## A footprint's footing gone: nothing under it within GONE_DROP m.
const GONE_DROP := 0.35
## Seconds broken before it sits in its niche again; seconds the sherds
## stay.
const REFORM := 14.0
const SHERDS_FOR := 10.0
## Seconds it eases from where it stands onto the trail.
const BLEND_IN := 0.8
const VOICES := {
	"walker_tok":[0.12,560.0,400.0,0.3,0.55,0.002,0.0],
	"walker_land":[0.28,330.0,210.0,0.4,0.35,0.002,0.0],
	"walker_scrape":[0.32,0.0,0.0,1.0,0.65,0.02,24.0],
	"walker_wake":[1.1,80.0,150.0,0.55,0.18,0.25,5.0],
	"walker_catch":[0.45,240.0,120.0,0.4,0.3,0.003,0.0],
	"walker_sit":[0.35,170.0,120.0,0.5,0.3,0.01,0.0],
	"walker_break":[1.0,0.0,0.0,1.0,0.7,0.002,0.0],
}
## How far each is heard (m).
const REACH := {"walker_tok":16.0,"walker_land":20.0,"walker_scrape":12.0,"walker_wake":18.0,"walker_catch":20.0,"walker_sit":10.0,"walker_break":40.0}

## The wanderers it may follow (their motors); the one it follows.
var wanderers: Array = []
var target: Object = null
var trail := FootTrail.new()
## "seated", "rising", "waiting", "walking", "sitting", "falling", "broken".
var state := "seated"
var state_t := 0.0
var delay: float = DELAYS[0]
## The trail's time it stands at (s on the trail's clock).
var cursor := 0.0
var seat := Vector3.ZERO
var seat_face := 0.0
## Where it stands (its figure's origin) and faces.
var pos := Vector3.ZERO
var facing := 0.0
## Below this it is gone (the study's `lost`).
var lost := -40.0
var sound_hook := Callable()
## Counts, for the HUD and the checks.
var catches := 0
var falls := 0
var toks := 0
var wakes := 0
var last_fall := {}
## Its size (walker heights): the wanderer's.
var size: float = WorldScale.wanderer

var puppet := PilotMotor.new()
var ground: PhysicsGround
var body: Node3D
var _root: Node3D
var _last_i := -1
var _fall_v := Vector3.ZERO
var _from := Vector3.INF
var _blend := 1.0
var _grounded_was := true
var _hold_was := ""
var _sherds: Array = []
var _sherd_t := 0.0

func _init() -> void:
	name = "SecondWalker"

## Seated at `at` facing `face` (radians, as PilotMotor.facing), following
## the first of `motors` to walk past.
func setup(at: Vector3, face: float, motors: Array) -> void:
	seat = at
	seat_face = face
	wanderers = motors
	puppet.set_size(size)
	if not is_inside_tree(): return
	_build()
	reset()

func _ready() -> void:
	if body == null and wanderers.size() > 0:
		_build()
		reset()

func _build() -> void:
	if body != null: return
	ground = PhysicsGround.new(get_world_3d().direct_space_state,puppet)
	ground.see(1|WalkerOnly.LAYER)
	_root = Node3D.new()
	_root.name = "Figure"
	_root.top_level = true
	add_child(_root)
	body = ClayFigure.new()
	body.name = "Clay"
	body.scale = Vector3.ONE*size
	body.size = size
	_root.add_child(body)

## Asleep in its niche again, its trail empty, its leash at its longest.
func reset() -> void:
	for s: Dictionary in _sherds: (s.node as Node).queue_free()
	_sherds.clear()
	target = null
	trail.clear()
	catches = 0
	delay = DELAYS[0]
	cursor = 0.0
	_last_i = -1
	pos = seat
	facing = seat_face
	puppet.reset(seat,seat_face)
	puppet.knocks = 0
	_to("seated")
	if body != null:
		_root.visible = true
		body.settle()
		_draw(0.0)

## Follows `motor` from now: its trail starts here, it gets up.
func follow(motor: Object) -> void:
	target = motor
	trail.clear(motor)
	trail.keep = maxf(FootTrail.KEEP,DELAYS[0]+SIT+REFORM)
	cursor = 0.0
	_last_i = -1
	wakes += 1
	_to("rising")
	_say(&"walker_wake",pos)
	woke.emit(motor)

func _to(s: String) -> void:
	state = s
	state_t = 0.0

## One frame, after the wanderers have stepped.
func step(delta: float) -> void:
	if body == null: return
	state_t += delta
	if target != null and state != "broken": trail.record(delta)
	match state:
		"seated": _seated()
		"rising":
			_stand()
			if state_t >= RISE: _to("waiting")
		"waiting":
			_stand()
			if trail.clock-cursor >= delay-0.001:
				_from = pos
				_blend = 0.0
				_to("walking")
		"walking": _walk(delta)
		"sitting":
			puppet.velocity = Vector3.ZERO
			if puppet.hold == "": puppet.move = "crouch"
			if state_t >= SIT:
				_say(&"walker_sit",pos)
				_to("waiting")
		"falling": _fall(delta)
		"broken":
			if state_t >= REFORM: reset()
	_step_sherds(delta)
	if state != "broken": _draw(delta)

func _seated() -> void:
	pos = seat
	facing = seat_face
	puppet.feet = seat
	puppet.facing = seat_face
	puppet.velocity = Vector3.ZERO
	puppet.grounded = true
	puppet.move = "crouch"
	puppet.hold = ""
	for m: Object in wanderers:
		if m == null: continue
		var f: Vector3 = m.feet
		if Vector2(f.x-seat.x,f.z-seat.z).length() <= WAKE*_tall() and absf(f.y-seat.y) <= WAKE_UP:
			follow(m)
			return

## Stood where it is (rising, waiting), facing along the trail's start.
func _stand() -> void:
	puppet.feet = pos
	puppet.velocity = Vector3.ZERO
	puppet.grounded = true
	puppet.move = ""
	puppet.hold = ""
	puppet.facing = facing

func _walk(delta: float) -> void:
	var lag := trail.clock-cursor
	var rate := CATCH_UP if lag > delay+0.05 else 1.0
	cursor = minf(cursor+delta*rate,trail.clock-delay)
	var s := trail.at_time(cursor)
	if s.is_empty(): return
	# Every footprint passed this frame, looked for again.
	var i := int(s.i)
	for f: Dictionary in trail.since(_last_i,i):
		var at := FootTrail.footing(f)
		if at.is_finite() and floor_gone(at):
			_last_i = i
			_step_off(f)
			return
	_last_i = i
	FootTrail.pose(puppet,s)
	puppet.velocity = (s.vel as Vector3)*rate
	_blend = minf(1.0,_blend+delta/BLEND_IN)
	var want: Vector3 = s.draw
	pos = _from.lerp(want,smoothstep(0.0,1.0,_blend)) if _from.is_finite() and _blend < 1.0 else want
	facing = float(s.facing)
	if _blend < 1.0:
		puppet.feet = pos
		if _from.is_finite():
			var way := Vector2(want.x-_from.x,want.z-_from.z)
			if way.length() > 0.3: facing = lerp_angle(PilotMotor.facing_of(way),facing,smoothstep(0.0,1.0,_blend))
	_catch()

## Whether the footing at `at` has gone: nothing under it within GONE_DROP.
func floor_gone(at: Vector3) -> bool:
	var under := ground.height_from(Vector2(at.x,at.z),at.y)
	return not is_finite(under) or under < at.y-GONE_DROP

## Into the target's place: a knock out along its way and a heart.
func _catch() -> void:
	if target == null or not is_instance_valid(target) or state != "walking": return
	var f: Vector3 = target.feet
	var flat := Vector2(f.x-pos.x,f.z-pos.z)
	if flat.length() > CATCH*PhysicsGround.RADIUS*size or absf(f.y-pos.y) > CATCH_UP_DOWN: return
	if target.has_method("downed") and target.downed(): return
	var way := flat if flat.length() > 0.05 else PilotMotor.forward(facing)
	if target.has_method("knock"):
		target.knock(target.knock_velocity(way,KNOCK_OUT*_tall(),KNOCK_UP*size),self)
	if target.has_method("harm"): target.harm("walker",1,self)
	catches += 1
	delay = DELAYS[mini(catches,DELAYS.size()-1)]
	# It takes up the trail from here, the moment it stepped into his place.
	cursor = trail.clock
	_last_i = trail.index_at(cursor)
	_say(&"walker_catch",pos)
	caught.emit(target)
	_to("sitting")

## Onto nothing: it takes the step anyway and drops.
func _step_off(f: Dictionary) -> void:
	falls += 1
	var at: Vector3 = FootTrail.footing(f)
	last_fall = {"at":at,"t":f.t,"from":pos}
	pos = (f.draw as Vector3) if String(f.hold) == "" else pos
	var v: Vector3 = f.vel
	_fall_v = Vector3(v.x,maxf(v.y,0.0),v.z)
	puppet.hold = ""
	puppet.grounded = false
	puppet.move = "tumble"
	puppet.velocity = _fall_v
	puppet.knocks += 1
	fell.emit(at)
	_to("falling")

func _fall(delta: float) -> void:
	var was := pos
	_fall_v.y -= puppet.gravity*(puppet.fall if _fall_v.y < 0.0 else 1.0)*delta
	_fall_v.y = maxf(_fall_v.y,-puppet.terminal)
	pos += _fall_v*delta
	puppet.feet = pos
	puppet.velocity = _fall_v
	puppet.grounded = false
	puppet.move = "tumble"
	if _fall_v.y < 0.0:
		var under := ground.height_from(Vector2(pos.x,pos.z),was.y)
		if is_finite(under) and pos.y <= under and was.y >= under-0.05:
			pos.y = under
			_break(pos)
			return
	if pos.y < lost:
		_break(Vector3.INF)

## Broken into sherds where it came down (or gone into the void: INF).
func _break(at: Vector3) -> void:
	_root.visible = false
	if at.is_finite():
		_say(&"walker_break",at)
		_shatter(at)
	broke.emit(at)
	_to("broken")

func _shatter(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = falls*7919+catches
	var mat := ClayFigure.clay_material()
	var tall := _tall()
	for k in range(16):
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(0.06,0.2),rng.randf_range(0.03,0.07),rng.randf_range(0.06,0.18))*size
		mi.mesh = box
		mi.material_override = mat
		mi.top_level = true
		add_child(mi)
		var p := at+Vector3(rng.randf_range(-0.2,0.2),rng.randf_range(0.1,0.9)*tall,rng.randf_range(-0.2,0.2))
		mi.global_position = p
		var a := rng.randf()*TAU
		var out := rng.randf_range(0.8,3.0)
		_sherds.append({"node":mi,"v":Vector3(cos(a)*out,rng.randf_range(1.0,3.5),sin(a)*out),"floor":at.y,"spin":Vector3(rng.randf_range(-9,9),rng.randf_range(-9,9),rng.randf_range(-9,9))})
	_sherd_t = 0.0

func _step_sherds(delta: float) -> void:
	if _sherds.is_empty(): return
	_sherd_t += delta
	if _sherd_t > SHERDS_FOR:
		for s: Dictionary in _sherds: (s.node as Node).queue_free()
		_sherds.clear()
		return
	for s: Dictionary in _sherds:
		var n: Node3D = s.node
		var v: Vector3 = s.v
		if n.global_position.y <= float(s.floor)+0.02 and v.y <= 0.0: continue
		v.y -= puppet.gravity*delta
		var p := n.global_position+v*delta
		if p.y <= float(s.floor)+0.02:
			p.y = float(s.floor)+0.02
			v = Vector3.ZERO
		s.v = v
		n.global_position = p
		n.rotation += (s.spin as Vector3)*delta*(1.0 if v != Vector3.ZERO else 0.0)

## The clay body set where it stands and posed; its sounds.
func _draw(delta: float) -> void:
	_root.global_position = pos
	_root.rotation = Vector3(0.0,facing,0.0)
	puppet.facing = facing
	var drawn: Dictionary = body.drive(puppet,delta)
	if state != "walking": return
	if drawn.has("footfall"):
		toks += 1
		_say(&"walker_tok",pos)
	if puppet.grounded and not _grounded_was: _say(&"walker_land",pos)
	if puppet.hold != "" and _hold_was == "": _say(&"walker_scrape",pos)
	_grounded_was = puppet.grounded
	_hold_was = puppet.hold

func _say(kind: StringName, at: Vector3) -> void:
	sounded.emit(kind,at)
	if sound_hook.is_valid(): sound_hook.call(kind,at)

func _tall() -> float:
	return PhysicsGround.HEAD*size

## What the HUD shows.
func line() -> String:
	var lag := trail.clock-cursor if target != null else 0.0
	return "walker  %s %.1fs · leash %.0f s (behind %.1f s) · caught you %d · fell %d · toks %d" % [state,state_t,delay,lag,catches,falls,toks]
