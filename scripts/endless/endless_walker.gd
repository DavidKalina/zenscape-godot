extends Node3D
## The pilot on foot over the endless land (studies/endless_flight.gd): the
## game's motor (scripts/pilot_motor.gd) drawn by the game's figure
## (scripts/pilot_figure.gd) with its footsteps, puffs, ripples, drop
## shadow and pocket sail, under the walker's camera, as the character
## study and the kit isles run him (studies/character_study.gd `tick`,
## `_frame`; the camera's numbers are its). Only what he stands on is the
## land's: the streamed heightfield colliders, the spruces' and the arches'
## bodies (all layer 1, scripts/endless/land_stream.gd LAYER), read through
## scripts/pilot_physics_ground.gd, with the land field under them where no
## collider has stood yet (a chunk still building, a seam), so he never
## falls through it.
##
## His moves: walk, run, jump (held higher, the pump on landing), the crouch
## slide, the slope surf, the long jumps chained, the pocket sail. The wall
## slide and kick, ledges, ropes and the wall run are off (the motor's
## switches), and the twirl with them (the roll out of a hard landing is
## the twirl pressed at the touch).
##
## Water: he wades the sea's shallows and a river's edge (slowed, rippling)
## up to WADE_MAX m deep, and walking on, deeper water stops him as a bank
## would (`_slide`). Come down in deep water from the air (a jump, the
## sail), the motor's own swim keeps him afloat and he swims out.

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const WandererSteps = preload("res://scripts/wanderer_steps.gd")
const PilotPuffs = preload("res://scripts/pilot_puffs.gd")
const PilotRipples = preload("res://scripts/pilot_ripples.gd")
const PilotStepSmooth = preload("res://scripts/pilot_step_smooth.gd")
const PocketSail = preload("res://scripts/pocket_sail.gd")
const PocketSailFigure = preload("res://scripts/pocket_sail_figure.gd")
const Pad = preload("res://scripts/pad.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## The walker's camera, as studies/character_study.gd's (its constants).
const CAM_DISTANCE := 7.0
const CAM_HEIGHT := 0.8
const CAM_POLAR := PI*0.5-0.62
const POLAR := Vector2(0.45,1.85)
const EASE_CAM_Y := 0.08
const EASE_CAM_Y_AIR := 0.35
const CAM_FOLLOW := 1.4
const CAM_LAG := 1.6
const LOOK_REST := 0.8
const FOLLOW := 0.9
const CAM_NEAREST := 0.9
const EASE_CAM_OUT := 0.4
const CAM_BALL := 0.25
const FOV := 60.0
const RIDE_FOV := 9.0
const RIDE_EASE := 0.6
const LOOK := 0.0025
const STICK_WALK_LOOK := Vector2(2.2,1.4)
const PUFF_LAND := 5.0
const PUFF_LAND_FULL := 10.0
const SET_OFF := 0.7
## The parked plane's column he keeps off (studies/kit_isle.gd's layer).
const PARKED_LAYER := 1 << 13
## The deepest water (m over the bed) he walks into.
const WADE_MAX := PilotMotor.SWIM_OUT
## Under the land's own height by this much (m), off the ground and not
## swimming, he is put back on it (`rescues`): a fall through nothing.
const UNDER_LAND := 3.0
## The hop out of the plane or into it: its height at the top (m).
const HOP_HEIGHT := 0.55

var motor := PilotMotor.new()
var ground: PhysicsGround
var field: RefCounted
## Callable(Vector3) -> float: the water's level at a point (the sea's
## swell, or a river's level over it; endless_flight.gd `water_at`).
var water_level: Callable
## The grass reacting (scripts/endless/grass_react.gd), or null.
var react: Node
var camera: Camera3D
var size: float = WorldScale.wanderer
var figure: Node3D
var body: Node3D
var puffs: Node3D
var drop_shadow: MeshInstance3D
var ripples: Node3D
var steps: Node
var sail_wing: Node3D
var step_smooth := PilotStepSmooth.new()
## Counts of what he did (for the drivers): moves seen, events.
var seen := {}
## Times he was put back on the land from under it.
var rescues := 0
## Frames his ground was the land field's (no collider there yet).
var field_reads := 0
var _ground_c: Callable
var _slide_c: Callable
var _yaw := 0.0
var _polar := CAM_POLAR
var _cam_y := 0.0
var _cam_at := Vector2.ZERO
var _cam_pace := Vector2.ZERO
var _cam_distance := CAM_DISTANCE
var _cam_out := 0.0
var _look_rest := 0.0
var _cam_ball: PhysicsShapeQueryParameters3D
var _asked := 0.0
var _skid_was := false
var _column: StaticBody3D
var _field_read := false
var _afloat_ok := false
## The solid's top under a point over the land field's height there
## (p: Vector3, h: float) -> float: a bore's floor under its rock
## (LandTunnels `land_y`). Unset, the field's height is the top.
var land_at: Callable

## Made after it is in the tree (it reads the world's physics space).
func setup(cam: Camera3D, land_field: RefCounted, level: Callable, grass_react: Node) -> void:
	camera = cam
	field = land_field
	water_level = level
	react = grass_react
	ground = PhysicsGround.new(get_world_3d().direct_space_state,motor)
	ground.see(1|PARKED_LAYER)
	motor.ground_from = _ground_from
	motor.water = _depth
	motor.wall = ground.wall_callable()
	motor.mover = ground.mover_callable()
	motor.soft = ground.soft_callable()
	motor.wall_on = false
	motor.ledge_on = false
	motor.rope_on = false
	motor.wallrun_on = false
	_ground_c = _ground
	_slide_c = _slide
	figure = Node3D.new()
	figure.name = "Pilot"
	add_child(figure)
	body = PilotFigure.new()
	figure.add_child(body)
	puffs = PilotPuffs.new()
	figure.add_child(puffs)
	drop_shadow = preload("res://scripts/pilot_drop_shadow.gd").new()
	figure.add_child(drop_shadow)
	ripples = PilotRipples.new()
	figure.add_child(ripples)
	sail_wing = PocketSailFigure.new()
	figure.add_child(sail_wing)
	steps = WandererSteps.new()
	add_child(steps)
	body.scale = Vector3.ONE*size
	body.size = size
	ground.scale_body(size)
	motor.set_size(size)
	sail_wing.scale = Vector3.ONE*size
	figure.visible = false

## Set down at `at` facing `face` (x, z), the camera behind (or, with
## `keep_yaw`, round where it looks).
func place(at: Vector3, face: Vector2, keep_yaw := false) -> void:
	motor.reset(at,PilotMotor.facing_of(face))
	sail_wing.reset()
	if not keep_yaw: _yaw = motor.facing
	_polar = CAM_POLAR
	step_smooth.reset()
	_cam_y = at.y+CAM_HEIGHT*size
	_cam_at = Vector2(at.x,at.z)
	_cam_pace = Vector2.ZERO
	_cam_distance = CAM_DISTANCE*size
	_cam_out = 0.0
	_look_rest = 0.0
	figure.visible = true
	body.settle()
	_sync_figure()
	_frame(0.0)

## The camera's way round him (radians, as the motor's facing).
func yaw() -> float:
	return _yaw

## The mouse's turn of the camera (pixels).
func look(relative: Vector2) -> void:
	_yaw -= relative.x*LOOK
	_polar = clampf(_polar-relative.y*LOOK,POLAR.x,POLAR.y)
	_look_rest = 0.0

## The pilot mid-hop between `from` (the cockpit) and `to` (the turf),
## `k` 0 at `from`, 1 at `to`, through the jump's pose.
func hop(from: Vector3, to: Vector3, k: float, delta: float) -> void:
	figure.visible = k > 0.02
	var at := from.lerp(to,smoothstep(0.0,1.0,k))
	at.y += HOP_HEIGHT*sin(PI*k)
	figure.position = at
	figure.rotation = Vector3(0.0,motor.facing,0.0)
	body.hop(cos(PI*k),delta)

## Hidden (in the plane).
func hide_figure() -> void:
	figure.visible = false
	ripples.dry()

## The parked plane's column (`radius` m round `at`, `tall` up) he keeps
## off; `clear_column` takes it away.
func set_column(at: Vector3, radius: float, tall: float) -> void:
	clear_column()
	_column = StaticBody3D.new()
	_column.name = "ParkedPlaneRoom"
	_column.collision_layer = PARKED_LAYER
	_column.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = tall
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3.UP*tall*0.5
	_column.add_child(cs)
	add_child(_column)
	_column.global_position = at

func clear_column() -> void:
	if _column != null: _column.free()
	_column = null

## One frame on foot: the stick read (unless `controls` is false), the
## motor stepped over the land, the body drawn, its sounds and puffs, the
## grass parted, the camera. Returns the motor's events.
func tick(delta: float, controls := true) -> Dictionary:
	var want := _want(delta) if controls else Vector2.ZERO
	var jump := controls and Input.is_action_pressed(&"walk_jump")
	motor.crouch = controls and Input.is_action_pressed(&"walk_crouch")
	motor.twirl = false
	_asked = want.length()
	# Off the ground (not afloat) he may come down in deep water and swim;
	# walked in, the shallows only wade him.
	if not motor.swimming: _afloat_ok = not motor.grounded
	ground.head(delta)
	_field_read = false
	var events := motor.step(delta,want,motor.run,jump,_ground_c,_slide_c,ground.ledge_callable())
	if _field_read: field_reads += 1
	var land := _land(motor.feet)
	if not motor.grounded and not motor.swimming and motor.feet.y < land-UNDER_LAND:
		rescues += 1
		push_warning("endless walker: under the land at %s, set back on it" % motor.feet)
		place(Vector3(motor.feet.x,land,motor.feet.z),PilotMotor.forward(motor.facing),true)
	_count(events)
	drop_shadow.update(motor,_ground_c)
	step_smooth.step(motor,_ground_c,delta)
	_sync_figure()
	_motor_events(events)
	var drawn: Dictionary = body.drive(motor.pose(),delta)
	sail_wing.update(delta,motor.move == "sail",PocketSail.steer(motor.sail.heading,want) if motor.move == "sail" else 0.0,1.0 if motor.sail.riding else 0.0)
	_body_events(drawn,delta)
	_water_events(events,drawn,delta)
	if react != null and motor.grounded and not motor.swimming:
		react.walker(motor.feet,motor.velocity,motor.move == "slide")
	_frame(delta)
	return events

func _count(events: Dictionary) -> void:
	if motor.move != "": seen[motor.move] = int(seen.get(motor.move,0))+1
	if motor.move == "slide" and motor.slope.length() > 0.3: seen["surfing"] = int(seen.get("surfing",0))+1
	if motor.wade > 0.03: seen["wading"] = int(seen.get("wading",0))+1
	for key: String in ["jumped","long","landed","sail","slide","swam"]:
		if events.has(key): seen["ev_"+key] = int(seen.get("ev_"+key,0))+1
	if events.has("jumped") and int(events.jumped) > 1: seen["ev_pump"] = int(seen.get("ev_pump",0))+1

# --- The land under him ---------------------------------------------------------------

## The ground under `p` seen from his feet (PhysicsGround `ground`).
func _ground(p: Vector2) -> float:
	return _ground_from(p,motor.feet.y)

## The colliders' ground under `p` from feet at `y`, but never under the
## land field's height there by more than its mesh's error: where no
## collider stands yet the field is the ground.
func _ground_from(p: Vector2, y: float) -> float:
	var h := ground.height_from(p,y)
	var land := _land(Vector3(p.x,y,p.y))
	if h < land-0.5:
		_field_read = true
		return land
	return h

## The land's top under `p` seen from its height: the field's, or a bore's
## floor under the mountain's rock (`land_at`).
func _land(p: Vector3) -> float:
	var h: float = field.height(p.x,p.z)
	return float(land_at.call(p,h)) if land_at.is_valid() else h

## The water's depth over the land's bed at `p` (0 on dry land), as the
## motor reads it: walked in (not come down from the air, not swimming), never
## deep enough to float him, so a swell running up the beach wades him and
## doesn't sweep him off (`_afloat_ok`).
func _depth(p: Vector2) -> float:
	var d := water_depth(p)
	if _afloat_ok or motor.swimming: return d
	return minf(d,motor.swim_in-0.05)

## The water's depth over the land's bed at `p` now (0 on dry land).
func water_depth(p: Vector2) -> float:
	var level: float = water_level.call(Vector3(p.x,Field.SEA_Y,p.y))
	return maxf(level-float(field.height(p.x,p.y)),0.0)

## The body slid round what it meets (PhysicsGround `slide`), and on foot
## kept out of water deeper than WADE_MAX that is deeper than where he
## stands (along the bank, if a part of the step stays shallow).
func _slide(feet: Vector3, step: Vector2) -> Vector3:
	var to := ground.slide(feet,step)
	if motor.swimming or not motor.grounded: return to
	var here := water_depth(Vector2(feet.x,feet.z))
	var there := water_depth(Vector2(to.x,to.z))
	if there <= WADE_MAX or there <= here: return to
	for part: Vector2 in [Vector2(step.x,0.0),Vector2(0.0,step.y)]:
		var t := ground.slide(feet,part)
		var d := water_depth(Vector2(t.x,t.z))
		if d <= WADE_MAX or d <= here: return t
	return feet

# --- Drawn ----------------------------------------------------------------------------

## The stick in the motor's frame: the camera's way taken out; the right
## stick swings the camera as the mouse does (character_study `_want`).
func _want(delta: float) -> Vector2:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var look_stick := Pad.curve(Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down"),1.6)
	if look_stick != Vector2.ZERO:
		_yaw -= look_stick.x*STICK_WALK_LOOK.x*delta
		_polar = clampf(_polar-look_stick.y*STICK_WALK_LOOK.y*delta,POLAR.x,POLAR.y)
		_look_rest = 0.0
	var forward := PilotMotor.forward(_yaw)
	var right := Vector2(-forward.y,forward.x)
	return right*stick.x+forward*-stick.y

func _sync_figure() -> void:
	figure.position = motor.feet+Vector3.UP*step_smooth.lift
	figure.rotation = Vector3(0.0,motor.facing,0.0)

## What the feet are on: water wading, sand by the sea, else grass.
func _surface() -> String:
	if motor.swimming or motor.wade >= 0.03: return "water"
	return "sand" if motor.feet.y < Field.SEA_Y+3.0 else "grass"

func _puff_at(at: Vector3) -> Vector3:
	if is_finite(motor.surface) and motor.wade > 0.0: at.y = maxf(at.y,motor.surface)
	return at

func _world_way(way: Vector3) -> Vector3:
	var flat := Vector3(way.x,0.0,way.z)
	if flat.length_squared() < 0.01:
		var f := PilotMotor.forward(motor.facing)
		flat = Vector3(f.x,0.0,f.y)
	return flat.normalized()

## Jumps and landings sound and puff, the body squashes, the sail swirls,
## a slide and a surf spray (character_study `_motor_events`, the moves on
## here).
func _motor_events(events: Dictionary) -> void:
	if events.has("jumped"):
		steps.step(_surface(),0.3+0.15*float(events.jumped))
		var at := _puff_at(figure.global_position)
		var way := _world_way(motor.velocity)
		if events.has("long") or events.has("slide_jump"): puffs.burst(at,_surface(),0.3,-way)
		elif int(events.jumped) > 1 or events.has("side_flip"): puffs.burst(at,_surface(),0.45)
	if events.has("sail"):
		steps.step(_surface(),0.3 if events.sail else 0.15)
		if events.sail: puffs.swirl(figure.global_position+Vector3.UP*1.6,0.6,0.5)
	if events.get("slide",false): steps.slide(_surface(),clampf(motor.speed()/PilotMotor.RUN,0.4,1.0))
	if motor.move == "slide" and motor.speed() > 1.0:
		var travel := _world_way(motor.velocity)
		puffs.spray(_puff_at(figure.global_position+travel*0.2),travel,_surface(),clampf(motor.speed()/PilotMotor.SPRAY_FULL,0.3,1.0),get_process_delta_time())
	if events.has("landed"):
		var hard := float(events.landed)
		steps.step(_surface(),clampf(hard/8.0,0.3,1.0))
		body.land(hard)
		if hard > PUFF_LAND: puffs.burst(_puff_at(figure.global_position),_surface(),(hard-PUFF_LAND)/PUFF_LAND_FULL)

func _body_events(out: Dictionary, delta: float) -> void:
	var speed: float = motor.speed()
	var effort := clampf((speed-PilotMotor.WALK)/(PilotMotor.RUN-PilotMotor.WALK),0.0,1.0)
	if out.has("footfall"):
		var side := int(out.footfall)
		steps.step(_surface(),effort,side)
		puffs.footfall(_puff_at(body.boot(side)),-_world_way(motor.velocity),_surface(),effort)
	if out.has("set_off") and _asked >= SET_OFF: puffs.burst(_puff_at(figure.global_position),_surface(),0.0,-_world_way(Vector3.ZERO))
	if out.has("turned"): puffs.burst(_puff_at(figure.global_position),_surface(),0.1,-_world_way(Vector3.ZERO))
	if motor.skidding:
		var travel := _world_way(motor.velocity)
		if not _skid_was: steps.slide(_surface(),speed/PilotMotor.RUN)
		puffs.spray(_puff_at(figure.global_position+travel*0.15),travel,_surface(),clampf(speed/PilotMotor.RUN,0.3,1.0),delta)
	_skid_was = motor.skidding

func _water_events(events: Dictionary, drawn: Dictionary, delta: float) -> void:
	for at in body.soak(motor.pose(),delta): puffs.drip(at,at.y-figure.global_position.y)
	if not is_finite(motor.surface):
		ripples.dry()
		return
	var top := Vector3(figure.global_position.x,motor.surface,figure.global_position.z)
	if events.has("swam"):
		var hard := clampf(float(events.swam)/8.0,0.3,1.0)
		ripples.splash(top,hard)
		puffs.burst(top,"water",hard)
		steps.step("water",hard)
	if events.has("hopped"):
		ripples.splash(top,0.4)
		puffs.burst(top,"water",0.3)
	var ahead := _world_way(Vector3.ZERO)
	if motor.swimming: ripples.trail(top+ahead*0.15,true,0.16)
	elif motor.grounded and motor.wade > 0.04 and motor.speed() > 0.3: ripples.trail(top,false,0.18)
	else: ripples.dry()
	if drawn.has("footfall") and motor.wade > 0.04:
		var boot: Vector3 = body.boot(int(drawn.footfall))
		ripples.ring(Vector3(boot.x,top.y,boot.z),0.07,0.25)
	if drawn.has("stroke"):
		var mitt: Vector3 = body.mitt(int(drawn.stroke))
		var paddling := motor.speed() > 0.3
		ripples.ring(Vector3(mitt.x,top.y,mitt.z),0.06,0.3 if paddling else 0.15)
		puffs.footfall(Vector3(mitt.x,top.y,mitt.z),-ahead,"water",0.5 if paddling else 0.2)
		steps.step("water",0.2 if paddling else 0.1,int(drawn.stroke))

# --- The camera -----------------------------------------------------------------------

## The walker's camera (character_study `_frame`): round a point over the
## feet that follows them on a spring and, lagging in a jump, up and down;
## swung round behind the run when left alone; drawn in where something
## stands between it and him.
func _frame(delta: float) -> void:
	var goal := motor.feet.y+step_smooth.lift+CAM_HEIGHT*size
	if delta > 0.0: _cam_y = lerpf(_cam_y,goal,_ease(EASE_CAM_Y if motor.grounded else EASE_CAM_Y_AIR,delta))
	_cam_y = clampf(_cam_y,goal-1.2,goal+1.2)
	_look_rest += delta
	var speed: float = motor.speed()
	if speed > 0.3 and _look_rest > LOOK_REST:
		var at_camera := maxf(0.0,-PilotMotor.forward(_yaw).dot(PilotMotor.forward(motor.facing)))
		_yaw = lerp_angle(_yaw,motor.facing,_ease(FOLLOW,delta)*clampf(speed/PilotMotor.RUN,0.0,1.0)*(1.0-at_camera))
	var feet := Vector2(motor.feet.x,motor.feet.z)
	var w := TAU*CAM_FOLLOW
	var left := minf(delta,0.25)
	while left > 0.0:
		var dt := minf(left,1.0/60.0)
		_cam_pace += (w*w*(feet-_cam_at)-2.0*w*_cam_pace)*dt
		_cam_at += _cam_pace*dt
		left -= dt
	if _cam_at.distance_to(feet) > CAM_LAG: _cam_at = feet+(_cam_at-feet).normalized()*CAM_LAG
	var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
	var out := Vector3(sin(_polar)*sin(_yaw),cos(_polar),sin(_polar)*cos(_yaw))
	var reach := _cam_reach(pivot,out)
	if reach < _cam_distance or delta <= 0.0:
		_cam_distance = reach
		_cam_out = 0.0
	else:
		var spring := 2.0/EASE_CAM_OUT
		var out_left := minf(delta,0.25)
		while out_left > 0.0:
			var out_dt := minf(out_left,1.0/120.0)
			_cam_out += (spring*spring*(reach-_cam_distance)-2.0*spring*_cam_out)*out_dt
			_cam_distance = minf(_cam_distance+_cam_out*out_dt,reach)
			out_left -= out_dt
	var eye := pivot+out*_cam_distance
	# Over the land even where no collider stands yet.
	eye.y = maxf(eye.y,_land(eye)+0.4)
	camera.look_at_from_position(eye,pivot)
	var riding: bool = motor.move == "sail" and motor.sail.riding
	if delta <= 0.0: camera.fov = FOV
	else: camera.fov = lerpf(camera.fov,FOV+(RIDE_FOV if riding else 0.0),_ease(RIDE_EASE,delta))

## How far out along `out` from `pivot` the camera may stand (character_study
## `_cam_reach`): a ball cast out, the land's and the trees' layer only.
func _cam_reach(pivot: Vector3, out: Vector3) -> float:
	var far := CAM_DISTANCE*size
	var length := far+0.3
	if _cam_ball == null:
		var ball := SphereShape3D.new()
		ball.radius = CAM_BALL
		_cam_ball = PhysicsShapeQueryParameters3D.new()
		_cam_ball.shape = ball
		_cam_ball.collision_mask = 1
	_cam_ball.transform = Transform3D(Basis.IDENTITY,pivot)
	_cam_ball.motion = Vector3.ZERO
	if ground.space.intersect_shape(_cam_ball,1).is_empty():
		_cam_ball.motion = out*length
		var cast := ground.space.cast_motion(_cam_ball)
		if float(cast[0]) >= 1.0: return far
		return clampf(float(cast[0])*length+CAM_BALL-0.3,CAM_NEAREST,far)
	var ray := PhysicsRayQueryParameters3D.create(pivot,pivot+out*length,1)
	var hit := ground.space.intersect_ray(ray)
	if hit.is_empty(): return far
	return clampf(pivot.distance_to(hit.position)-0.3,CAM_NEAREST,far)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)
