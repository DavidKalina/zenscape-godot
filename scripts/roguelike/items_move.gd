extends Node3D
## [items_move] The movement items (docs/design/roguelike/items_move-round1.md):
## verbs a run finds and loses with him. Each is read live from
## `RunState.holds(id)` every tick, round the motor's own step (the run loop
## calls `before` ahead of the study's tick and `after` behind it), so the
## motor itself is untouched but for the ledge hang and climb it lends.
##
## - **Grapnel** (`grapnel`): V (pad RT) throws a hook up and ahead
##   (`_aim`: rays fanned round his facing). It bites a lip (a wall's top in
##   reach of the hit) or the underside of an arch or beam, and he rides
##   the line as a swing rope (scripts/roguelike/grapnel_rope.gd): pump,
##   steer, Jump to let go with the boost. Held, the button hauls him up the
##   line; hauled to a lip he climbs onto it. One throw an airtime (the
##   ground, a ledge, a wall or the water give it back), so a gap is one
##   swing, not a chain across the sky.
## - **Drift Cloak** (`cloak`): Jump held while falling (past CLOAK_AFTER
##   of the fall) spreads it: his fall caught to CLOAK_FALL, his steer
##   CLOAK_STEER times the air's, and the landing never a fall's (no stun,
##   no hearts). Let go of Jump, he drops. Slower across than the sail
##   (about 2:1 at a run against the sail's 3.7:1), so it never crosses a
##   gap the sail can't; it is the sail's opposite: straight down, slow,
##   placed, and it opens where the sail can't (by walls, in shafts, after a
##   kick).
## - **Rock Picks** (`picks`): on a wall (the slide, stick into it) each
##   PICK_EVERY s the picks bite and pull him up (PICK_UP m/s), PICKS
##   pulls an airtime; past the top he is handed to the lip and climbs on.
const RunState = preload("res://scripts/roguelike/run_state.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const GrapnelRope = preload("res://scripts/roguelike/grapnel_rope.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const DriftCloak = preload("res://scripts/roguelike/drift_cloak.gd")

const GRAPNEL_ACTION := &"item_grapnel"
## The hook's reach (m, by his size), its flight (m/s), its fan of throws:
## pitches up (radians) and turns off his facing (radians).
const REACH := 9.0
const THROW := 42.0
const PITCHES := [1.3,1.18,1.06,0.95,0.85,0.75,0.66,0.57,0.49,0.41,0.34,0.27]
const TURNS := [0.0,0.14,-0.14,0.28,-0.28,0.42,-0.42,0.56,-0.56]
## A wall's hit is a lip if the wall's top is within LIP_BITE over it;
## a lip or soffit is worth hooking at least HOOK_OVER over his feet.
const LIP_BITE := 1.2
const HOOK_OVER := 1.3
## Between throws (s).
const THROW_COOL := 0.35

## The cloak: falling capped (m/s), caught at (m/s², net), the air steer's
## share more, the fall before it spreads (s).
const CLOAK_FALL := 2.3
const CLOAK_CATCH := 55.0
const CLOAK_STEER := 1.8
const CLOAK_AFTER := 0.08

## The picks: pulls an airtime, the rise each gives (m/s), the beat between.
const PICKS := 4
const PICK_UP := 3.8
const PICK_EVERY := 0.3

var study: Node3D
var motor: PilotMotor

var _throw_was := false
var _throw_cool := 0.0
var _air_throw := true
## The hook in flight: {from, to, t, length, hit, lip}, {} none.
var _hook := {}
var _hook_mesh: MeshInstance3D
var _line_mesh: MeshInstance3D
var rope: Node3D = null

var _falling := 0.0
var cloaked := false
var _base_air := PilotMotor.AIR_ACCEL
var _cloak_fig: Node3D = null

var _pulls := PICKS
var _pull_t := 0.0
var _picked := 9.0
var _wall_out := Vector2.ZERO

var _sound: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "ItemsMove"

## The grapnel's button: V, or the pad's right trigger.
static func ensure_action() -> void:
	if InputMap.has_action(GRAPNEL_ACTION): return
	InputMap.add_action(GRAPNEL_ACTION,0.4)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	InputMap.action_add_event(GRAPNEL_ACTION,key)
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	rt.device = -1
	InputMap.action_add_event(GRAPNEL_ACTION,rt)

func setup(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	_base_air = motor.air_accel
	ensure_action()
	scene.add_child(self)
	_hook_mesh = MeshInstance3D.new()
	_hook_mesh.mesh = _hook_shape()
	_hook_mesh.visible = false
	add_child(_hook_mesh)
	_line_mesh = MeshInstance3D.new()
	_line_mesh.mesh = SwingRope._rope_mesh()
	_line_mesh.visible = false
	add_child(_line_mesh)
	_sound = AudioStreamPlayer3D.new()
	_sound.volume_db = -4.0
	_sound.max_distance = 60.0
	add_child(_sound)

static func on() -> bool:
	return RunFeatures.on(&"items_move")

# --- Round the study's tick -------------------------------------------------------

## Before the motor's step: the throw, the cloak's catch, the picks' pull.
func before(delta: float) -> void:
	if not on() or motor == null: return
	motor = study.motor
	_throw_cool = maxf(0.0,_throw_cool-delta)
	_pull_t = maxf(0.0,_pull_t-delta)
	_picked += delta
	if motor.grounded or motor.hold != "" or motor.swimming:
		_air_throw = true
		_pulls = PICKS
	if motor.move == "wall": _air_throw = true
	_grapnel_before(delta)
	_cloak_before(delta)
	_picks_before(delta)

## After the step: the hook's flight, the line, the cloak drawn, the picks'
## top.
func after(delta: float) -> void:
	if not on() or motor == null: return
	_hook_step(delta)
	if rope != null:
		if not is_instance_valid(rope) or motor.rider != rope:
			_drop_rope()
		else:
			rope.advance(delta)
	_picks_after()
	_cloak_draw(delta)

# --- Grapnel ----------------------------------------------------------------------

func _throw_held() -> bool:
	return InputMap.has_action(GRAPNEL_ACTION) and Input.is_action_pressed(GRAPNEL_ACTION)

func _grapnel_before(_delta: float) -> void:
	var held := _throw_held()
	var pressed := held and not _throw_was
	_throw_was = held
	if rope != null and is_instance_valid(rope): rope.hauling = held
	if not RunState.holds(&"grapnel"):
		if rope != null and motor.rider == rope: motor.toss(motor.velocity)
		return
	if not pressed or _throw_cool > 0.0 or not _hook.is_empty(): return
	if motor.rider != null or motor.hold != "" or motor.swimming or motor.move == "tumble" or motor.seized(): return
	if not motor.grounded and not _air_throw: return
	_throw_cool = THROW_COOL
	if not motor.grounded: _air_throw = false
	var from := _hands()
	var found := _aim(from)
	if found.is_empty():
		# A miss: the hook flies out its reach and falls back.
		var f := PilotMotor.forward(motor.facing)
		var to := from+Vector3(f.x*0.75,0.66,f.y*0.75).normalized()*REACH*motor.size*0.8
		_hook = {"to":to,"t":0.0,"length":from.distance_to(to),"hit":false,"lip":{}}
	else:
		_hook = {"to":found.at,"t":0.0,"length":from.distance_to(found.at),"hit":true,"lip":found.lip}
	_play("rope-whip",3,0.0)

## Where his hands are (the throw's start, the line's end in flight).
func _hands() -> Vector3:
	return motor.feet+Vector3.UP*(PilotMotor.HANG_DROP+0.25)*motor.size

## The best bite in the fan up and ahead: {at, lip ({} a soffit)}, or {}.
func _aim(from: Vector3) -> Dictionary:
	var ground: Object = study.get("ground")
	if ground == null: return {}
	var space: PhysicsDirectSpaceState3D = ground.get("space")
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = int(ground.get("_ray").collision_mask)
	var reach := REACH*motor.size
	var aim := PilotMotor.forward(motor.facing)
	var best := {}
	var best_score := -INF
	for turn: float in TURNS:
		var way := aim.rotated(-turn)
		for pitch: float in PITCHES:
			var d := Vector3(way.x*cos(pitch),sin(pitch),way.y*cos(pitch))
			ray.from = from
			ray.to = from+d*reach
			var hit := space.intersect_ray(ray)
			if hit.is_empty(): continue
			var n: Vector3 = hit.normal
			if n == Vector3.ZERO: continue
			var p: Vector3 = hit.position
			var got := _bite(ground,p,n)
			if got.is_empty(): continue
			var at: Vector3 = got.at
			if at.y < motor.feet.y+HOOK_OVER*motor.size: continue
			# Nearest the facing, a lip over a soffit, a middling pitch.
			var score := -absf(turn)*2.0-absf(pitch-0.8)*0.8+(0.8 if not (got.lip as Dictionary).is_empty() else 0.0)
			if from.distance_to(at) < 1.6*motor.size: score -= 1.5
			if score > best_score:
				best_score = score
				best = got
	return best

## What a hit at `p` (its normal `n`) bites: a soffit's underside, or a
## wall's lip in reach over the hit; {} a bare face or a top.
func _bite(ground: Object, p: Vector3, n: Vector3) -> Dictionary:
	if n.y < -0.6: return {"at":p+n*0.05,"lip":{}}
	if absf(n.y) > 0.6: return {}
	var out := Vector2(n.x,n.z).normalized()
	var top: float = ground.call("top_from",Vector2(p.x,p.z)-out*0.3,p.y)
	if not is_finite(top) or top < p.y-0.1 or top > p.y+LIP_BITE*motor.size: return {}
	var found: Dictionary = ground.call("ledge",Vector2(p.x,p.z)-out*0.1,top)
	if found.is_empty(): found = {"at":Vector3(p.x,top,p.z),"out":out}
	var o: Vector2 = found.out
	return {"at":(found.at as Vector3)+Vector3(o.x,0.0,o.y)*0.15+Vector3.UP*0.02,"lip":found}

## The hook's flight out (and, a miss, back), the line drawn to his hands;
## arrived and bitten, he takes the line.
func _hook_step(delta: float) -> void:
	if _hook.is_empty():
		_hook_mesh.visible = false
		_line_mesh.visible = false
		return
	var length: float = _hook.length
	_hook.t = float(_hook.t)+delta*THROW/maxf(length,0.5)
	var from := _hands()
	var to: Vector3 = _hook.to
	var s: float = _hook.t
	var at := from.lerp(to,minf(s,1.0))
	if not bool(_hook.hit) and s > 1.0: at = from.lerp(to,maxf(2.0-s,0.0))
	_hook_mesh.visible = true
	_line_mesh.visible = true
	_hook_mesh.global_transform = Transform3D(Basis.looking_at((to-from).normalized() if (to-from).length() > 0.01 else Vector3.FORWARD,Vector3.UP).scaled(Vector3.ONE*motor.size),at)
	_line_mesh.global_transform = Transform3D(SwingRope._segment_basis(at,from),at)
	if bool(_hook.hit) and s >= 1.0:
		var lip: Dictionary = _hook.lip
		_hook = {}
		_hook_mesh.visible = false
		_line_mesh.visible = false
		_bitten(to,lip)
	elif not bool(_hook.hit) and s >= 2.0:
		_hook = {}

## The hook bit at `at`: he takes the line, if he still can.
func _bitten(at: Vector3, lip: Dictionary) -> void:
	_play("grab",4,-2.0)
	if motor.rider != null or motor.hold != "" or motor.swimming or motor.move == "tumble" or motor.seized(): return
	if not RunState.holds(&"grapnel"): return
	_drop_rope()
	var r: Node3D = GrapnelRope.new()
	r.name = "GrapnelLine"
	r.setup_grapnel(at,SwingRope.hand_of(motor),study.get("ground"),lip)
	study.add_child(r)
	rope = r
	r.hauling = _throw_held()
	r.take(motor)
	if study.get("puffs") != null: study.puffs.burst(at,"stone",0.3)

func _drop_rope() -> void:
	if rope != null and is_instance_valid(rope):
		motor.release(rope)
		rope.queue_free()
	rope = null

# --- Drift Cloak ------------------------------------------------------------------

func _jump_held() -> bool:
	if bool(study.get("scripted")): return bool(study.get("script_jump"))
	return Input.is_action_pressed(&"walk_jump")

func _cloak_before(delta: float) -> void:
	var has := RunState.holds(&"cloak")
	var free_fall := not motor.grounded and motor.rider == null and motor.hold == "" and not motor.swimming \
		and not motor.seized() and not (motor.move in ["sail","wall","wallrun","slam","tumble"])
	_falling = _falling+delta if free_fall and motor.velocity.y < 0.0 else 0.0
	var was := cloaked
	cloaked = has and free_fall and _jump_held() and _falling >= CLOAK_AFTER
	if cloaked:
		var g := motor.gravity*motor.fall
		var low := -CLOAK_FALL*sqrt(motor.size)
		var target := low+g*delta
		if motor.velocity.y < target: motor.velocity.y = move_toward(motor.velocity.y,target,(CLOAK_CATCH+g)*delta)
		# Held up: the fall starts again, so the touch is never a fall's.
		motor._fall_top = motor.feet.y
		motor.air_accel = _base_air*CLOAK_STEER
		if not was:
			_play("swish",4,-6.0)
	elif was:
		motor.air_accel = _base_air

func _cloak_draw(delta: float) -> void:
	var has := RunState.holds(&"cloak")
	if has and _cloak_fig == null:
		var body: Node3D = study.get("body")
		if body == null: return
		_cloak_fig = DriftCloak.new()
		var tilt: Variant = body.get("_tilt")
		(tilt as Node3D if tilt is Node3D else body).add_child(_cloak_fig)
	if _cloak_fig == null: return
	_cloak_fig.visible = has
	if has: _cloak_fig.update(delta,cloaked,motor)

# --- Rock Picks -------------------------------------------------------------------

## The stick in the motor's frame, as the study reads it (the camera's way
## taken out), without touching the camera.
func _want() -> Vector2:
	if bool(study.get("scripted")): return study.get("script_want")
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var forward := PilotMotor.forward(float(study.get("_yaw")))
	var right := Vector2(-forward.y,forward.x)
	return right*stick.x+forward*-stick.y

func _picks_before(_delta: float) -> void:
	if not RunState.holds(&"picks") or motor.move != "wall": return
	_wall_out = motor.wall_out
	var into := _want().dot(-motor.wall_out)
	if into < 0.5 or _pulls <= 0 or _pull_t > 0.0: return
	_pulls -= 1
	_pull_t = PICK_EVERY
	_picked = 0.0
	motor.velocity.y = PICK_UP*sqrt(motor.size)
	var bite := motor.feet+Vector3.UP*(PilotMotor.HANG_DROP+0.35)*motor.size-Vector3(motor.wall_out.x,0.0,motor.wall_out.y)*0.25*motor.size
	if study.get("puffs") != null: study.puffs.burst(bite,"stone",0.15)
	_play("tick",6,-3.0,1.0+0.12*float(PICKS-_pulls))

## Pulled past the wall's top (it ended under his hands): the lip there
## taken and climbed onto, the motor's own hang and climb.
func _picks_after() -> void:
	if _picked > 0.45 or motor.move == "wall" or motor.grounded or motor.hold != "" or motor.rider != null: return
	if _wall_out == Vector2.ZERO: return
	var ground: Object = study.get("ground")
	if ground == null: return
	var into := -_wall_out
	var reach_y := motor.feet.y+PilotMotor.HANG_DROP*motor.size
	for ahead: float in [0.35,0.6]:
		var found: Dictionary = ground.call("ledge",Vector2(motor.feet.x,motor.feet.z)+into*ahead*motor.size,reach_y+0.3*motor.size)
		if found.is_empty(): continue
		var lip_y := float((found.at as Vector3).y)
		if lip_y < reach_y-0.4*motor.size or lip_y > reach_y+0.9*motor.size: continue
		var was := motor.feet
		motor._hang_on(found)
		var g: Callable = ground.call("ground_callable")
		var sl: Callable = ground.call("slide_callable")
		if not motor._climb(g,sl):
			motor._snap = was-motor.feet
			motor.feet = was
		_picked = 9.0
		_play("grab",4,-4.0)
		return

# --- Bits -------------------------------------------------------------------------

func _play(stem: String, count: int, db: float, pitch := 1.0) -> void:
	if _sound == null or DisplayServer.get_name() == "headless": return
	var path := "res://assets/audio/kit/%s-%d.wav" % [stem,_rng.randi_range(1,count)]
	if not ResourceLoader.exists(path): return
	_sound.stream = load(path)
	_sound.volume_db = db
	_sound.pitch_scale = pitch*_rng.randf_range(0.94,1.06)
	_sound.global_position = motor.feet+Vector3.UP
	_sound.play()

## The hook: three tarnished iron tines round a shank, a faceted lump.
static func _hook_shape() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := Color("4a4540")
	var bits := [[Vector3.ZERO,Vector3(0,0,-0.22)]]
	for k in range(3):
		var a := TAU*float(k)/3.0
		var side := Vector3(cos(a),sin(a),0.0)*0.11
		bits.append([Vector3(0,0,-0.2),Vector3(0,0,-0.16)+side])
		bits.append([Vector3(0,0,-0.16)+side,Vector3(0,0,-0.06)+side*1.25])
	for b: Array in bits:
		var p0: Vector3 = b[0]
		var p1: Vector3 = b[1]
		var ax := (p1-p0).normalized()
		var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()*0.018
		var v := ax.cross(u).normalized()*0.018
		for i in range(4):
			var a0 := TAU*float(i)/4.0
			var a1 := TAU*float(i+1)/4.0
			var o0 := u*cos(a0)+v*sin(a0)
			var o1 := u*cos(a1)+v*sin(a1)
			var nrm := (o0+o1).normalized()
			for q: Vector3 in [p0+o0,p1+o0,p1+o1,p0+o0,p1+o1,p0+o1]:
				st.set_color(iron.lightened(0.15 if i%2 == 0 else 0.0))
				st.set_normal(nrm)
				st.add_vertex(q)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.55
	m.metallic = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,m)
	return mesh
