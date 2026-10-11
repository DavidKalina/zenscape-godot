extends Node3D
## Landing study: greybox fields of rising difficulty (scripts/
## landing_course.gd) to land the game's plane on by hand, under the manual
## landing's rules (scripts/manual_landing.gd): no F to land it for you.
## Find a spot and put it down: slow, shallow and level is a greaser and a
## tidy rollout; hot or hard it sticks anyway, thumps and slides, and you
## drift it to a stop like a kart (steer hard, or Q E with a turn; Shift
## with a turn is a braked slide, and a blip of Space with it whips the
## tail right round, a power-slide). Off the end, you are flying again.
## Only a barrel roll into the ground or land too steep hops. Only stopped
## can you get out (F, or the pad's Y), and only by asking. On foot, walk back to the plane and Space
## (A) by it climbs in and takes off (scripts/plane_landing.gd's takeoff);
## nothing else flies. Walk off an edge and you drop (scripts/sky_dive.gd),
## Space opening the pocket sail (scripts/pocket_sail.gd) to coast down
## on, nothing opening by itself, the plane staying parked: come down on the plane's field and walk to it; anywhere else (a
## lower shelf, another field, the sea), or once STRAND_BELOW m under the
## edge, and you are stranded PICKUP_WAIT s, then
## the view fades and you stand beside the parked plane again, still to
## board it (`--stranded=pickup` instead has the plane come for you and
## you are flying again, the skydive's sea pickup made slow).
##
## Each approach is a run (scripts/landing_run.gd), a person's or the
## CPU's (scripts/landing_bot.gd), recorded and measured: when the plane
## stops (or after LandingRun TIME_LIMIT s), a report shows the touch's
## grade (a greaser or not), speed and sink, the slide (metres, peak slip),
## the stop's margin to the edge, hops, go-arounds, the rollout and the
## time to stop, and the run is saved as JSON under user://landing_runs.
## F1 shows the live numbers: speed and sink against the greaser's limits,
## bank, height over the land, flaps, what a touch now would be; on the
## wheels the slip, the grit and the room to the edge. H picks the
## approach: normal (far and high at cruise), hot (close and low at
## cruise) or boost (at Boost's speed); the bots fly them slow, at cruise
## and at boost.
##
## Keys: WASD or the left stick turn and pitch (W noses down), Space or RT
## boosts, Shift or LT brakes (and on the wheels, the wheel brakes), F or Y
## lowers and raises the flaps in the air and gets out once stopped, Q and
## E lean (twice: roll; on the wheels with a turn, a drift). 1-5 the
## stations, R again, N the next, H the approach, B who flies (you, then
## the sloppy, decent, sharp and perfect bots), F1 the numbers, Esc lets
## the mouse go. On foot: WASD walks, Space (A) by the plane boards,
## elsewhere hops.
##   ./run-landing-study.command [--station=islet] [--bot=sharp] [--approach=hot] [--stranded=pickup]
##   godot --path . res://studies/landing_study.tscn -- --no-title

const Course = preload("res://scripts/landing_course.gd")
const Run = preload("res://scripts/landing_run.gd")
const Bot = preload("res://scripts/landing_bot.gd")
const Log = preload("res://scripts/flight_log.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyDive = preload("res://scripts/sky_dive.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const WheelSpray = preload("res://scripts/wheel_spray.gd")
const PocketSailFigure = preload("res://scripts/pocket_sail_figure.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const DiveCamera = preload("res://scripts/dive_camera.gd")
const Pad = preload("res://scripts/pad.gd")
const GRID := preload("res://shaders/character_study_grid.gdshader")

const DIR := "user://landing_runs"
## The mouse's and right stick's look.
const LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
const PILOTS := ["human","sloppy","decent","sharp","perfect"]
## The pace a bot flies each approach at (Course APPROACHES).
const BOT_PACE := {"normal":"slow","hot":"cruise","boost":"boost"}
## The grit's tint off the fields.
const TURF := Color(0.5,0.58,0.36)
const COLOURS := {"field":Color(0.6,0.66,0.55),"shelf":Color(0.55,0.56,0.6),"sea":Color(0.42,0.52,0.6),"pilot":Color(0.32,0.24,0.18)}
## On foot: the pace (m/s), the hop (m/s up), the pull down (m/s²), how near
## the plane Space boards it (m), and the camera behind and over (m).
const WALK := 4.0
const HOP := 4.5
const FALL := 20.0
const BOARD_REACH := 2.4
const FOOT_CAM := Vector2(6.0,2.6)
## The hop out lands this far to the plane's left and ahead (m).
const HOP_SIDE := 1.4
const HOP_AHEAD := 0.3
## Off an edge: how far under the edge the pilot is stranded (m).
## Stranded (that, or down anywhere but the plane's field): seconds before
## the way back, and the fade's (s).
const STRAND_BELOW := 20.0
const PICKUP_WAIT := 3.0
const FADE := 0.5
## The thump's shake (at a full hit, or a hop): seconds and metres; the
## thump's length (s) and pitch (Hz).
const SHAKE_TIME := 0.4
const SHAKE := 0.35
const THUMP_TIME := 0.22
const THUMP_HZ := 58.0

signal ready_to_fly

var flight_ready := false
## Driven by a test: no input read; `tick` given its input by hand.
var scripted := false
var log_dir := DIR
var station := {}
var pilot := "human"
## The approach each run starts on (Course APPROACHES).
var approach := "normal"
var run: Run
var bot: Bot
## What the pilot is doing: "plane" (in it: flying, rolling, stopped,
## getting out), "takeoff" (boarding and the takeoff run), "foot",
## "drop" (off an edge, falling or under the sail) or "stranded".
var mode := "plane"
var figure: PlaneFigure
var walker: Node3D
var sail_wing: PocketSailFigure
var spray: WheelSpray
var chase := GlideCamera.new()
var dive_camera := DiveCamera.new()
var camera: Camera3D
## The flaps (down or up), Exit asked this frame.
var flaps := false
var _exit_asked := false
## The takeoff sequence (scripts/plane_landing.gd), the dive, the walker's
## feet, its fall and facing, the foot camera's yaw, the hop out.
var takeoff: PlaneLanding
var dive: SkyDive
var feet := Vector3.ZERO
var _feet_v := 0.0
var facing := 0.0
var _foot_yaw := 0.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _stranded := 0.0
## Off an edge: the edge's height, and Space asked (the sail opened or
## folded).
var _off_y := 0.0
var _open_asked := false
## The plane parked (the pilot out): where it stands.
var parked := false
## Stranded: "return" (back beside the parked plane) or "pickup" (the
## plane comes and you fly).
var stranded_rule := "return"
var _veil: ColorRect
var last_run := {}
var last_path := ""
var _hud: Control
var _hud_label: Label
var _report: PanelContainer
var _report_label: Label
var _hint: Label
var _flash: Label
var _flash_time := 0.0
var _shake := 0.0
var _shake_size := 1.0
var _thump: AudioStreamPlayer
var _materials := {}
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := 0
var _jump_was := false

func _ready() -> void:
	Pad.ensure()
	_build_light()
	_build_course()
	_build_ui()
	figure = PlaneFigure.new()
	add_child(figure)
	walker = _build_walker()
	sail_wing = PocketSailFigure.new()
	walker.add_child(sail_wing)
	spray = WheelSpray.new()
	add_child(spray)
	_thump = AudioStreamPlayer.new()
	_thump.stream = thump_sound()
	add_child(_thump)
	var first: Dictionary = Course.STATIONS[0]
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--station=") and not Course.station(arg.substr(10)).is_empty(): first = Course.station(arg.substr(10))
		if arg.begins_with("--bot=") and arg.substr(6) in PILOTS: pilot = arg.substr(6)
		if arg in ["--stranded=pickup","--stranded=return"]: stranded_rule = arg.substr(11)
		if arg.begins_with("--approach=") and arg.substr(11) in Course.APPROACH_NAMES: approach = arg.substr(11)
	start(first)
	flight_ready = true
	ready_to_fly.emit()
	if not scripted and get_tree().current_scene == self: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- The course ----------------------------------------------------------------------

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("6f9fcf")
	sky.sky_horizon_color = Color("dfe6e4")
	sky.ground_bottom_color = Color("9aa3a6")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("dfe6e4")
	environment.fog_density = 0.002
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.far = 1500.0
	add_child(camera)
	camera.current = true

func _material(kind: String) -> Material:
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",COLOURS.get(kind,COLOURS.field))
		_materials[kind] = m
	return _materials[kind]

## The sea under everything, each station's fields and its sign.
func _build_course() -> void:
	var sea := MeshInstance3D.new()
	var slab := BoxMesh.new()
	var reach := Course.SPACING*Course.STATIONS.size()
	slab.size = Vector3(reach+800.0,1.0,1200.0)
	sea.mesh = slab
	sea.position = Vector3(reach*0.5-Course.SPACING*0.5,Course.SEA_Y-0.5,0.0)
	sea.material_override = _material("sea")
	add_child(sea)
	for s: Dictionary in Course.STATIONS:
		Course.build(s,self,_material)
		var at := Course.origin(s)
		_label(at+Vector3(-14.0,6.0,4.0),"%d  %s" % [int(s.key),s.name],96)
		# A post at the near edge's corners, so the field reads from far off.
		for side in [-1.0,1.0]:
			var post := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.25
			cyl.height = 3.0
			post.mesh = cyl
			post.position = at+Vector3(side*(float(s.width)*0.5+0.6),1.5+Course.floor_at(Vector2(at.x,at.z-0.5)),0.0)
			post.material_override = _material("shelf")
			add_child(post)

func _label(at: Vector3, text: String, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 16
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.12,0.12,0.14)
	label.outline_modulate = Color(1.0,1.0,1.0,0.85)
	label.position = at
	add_child(label)

## The pilot on foot: a greybox capsule, a nose to show its facing.
func _build_walker() -> Node3D:
	var node := Node3D.new()
	node.name = "Walker"
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 0.95
	body.mesh = capsule
	body.position = Vector3(0.0,0.475,0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOURS.pilot
	body.material_override = m
	node.add_child(body)
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12,0.1,0.2)
	nose.mesh = box
	nose.position = Vector3(0.0,0.75,-0.25)
	nose.material_override = m
	node.add_child(nose)
	node.visible = false
	add_child(node)
	return node

## A short low thump (a decaying sine with a little noise), for a bounce.
static func thump_sound() -> AudioStreamWAV:
	var rate := 22050
	var count := int(THUMP_TIME*rate)
	var data := PackedByteArray()
	data.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(count):
		var t := float(i)/rate
		var fall := exp(-t*22.0)
		var v := (sin(TAU*THUMP_HZ*t*(1.0-t*1.5))*0.85+rng.randf_range(-1.0,1.0)*0.15*exp(-t*60.0))*fall
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

# --- Runs ----------------------------------------------------------------------------

## Starts station `s` afresh: in the plane at its start, flown by `pilot`.
func start(s: Dictionary) -> void:
	if run != null: run.abandon()
	station = s
	var params := {} if pilot == "human" else Bot.params(pilot)
	run = Run.new(s,"human" if pilot == "human" else "bot:"+pilot,params,approach)
	bot = null if pilot == "human" else Bot.new(params,randi(),BOT_PACE.get(approach,"slow"))
	mode = "plane"
	flaps = false
	parked = false
	takeoff = null
	dive = null
	walker.visible = false
	sail_wing.reset()
	_report.visible = false
	figure.reset(run.plane)
	chase.reset(run.plane,run.plane.position-run.plane.forward()*6.0+Vector3.UP*2.0,camera.fov)
	_frame(0.0)

## Flying again (after a takeoff or a pickup): the next approach is its
## own run, on the station whose field is nearest, the same pilot.
func _next_run(plane: SkyPlane) -> void:
	var s := Course.station_near(plane.position)
	var params := {} if pilot == "human" else Bot.params(pilot)
	var next := Run.new(s,"human" if pilot == "human" else "bot:"+pilot,params)
	next.adopt(plane)
	run = next
	station = s
	bot = null if pilot == "human" else Bot.new(params,randi())
	if bot != null: bot._go_round(s)
	_report.visible = false

func restart() -> void:
	start(station)

func next_station() -> void:
	start(Course.STATIONS[(Course.index_of(station)+1)%Course.STATIONS.size()])

func _physics_process(delta: float) -> void:
	if flight_ready and not scripted: tick(delta)

## One tick. `given` (a test's) holds the plane's input (turn, pitch,
## boost, brake, ...; `flaps` and `exit` as asked) and on foot `move`
## (Vector2, x right, y forward) and `jump` (true on the press).
func tick(delta: float, given := {}) -> void:
	match mode:
		"plane": _tick_plane(delta,given)
		"takeoff": _tick_takeoff(delta)
		"foot": _tick_foot(delta,given)
		"drop": _tick_drop(delta,given)
		"stranded": _tick_stranded(delta)
	_flash_time = maxf(0.0,_flash_time-delta)
	_flash.modulate.a = clampf(_flash_time/0.6,0.0,1.0)
	_show_hud()

# --- In the plane --------------------------------------------------------------------

func _tick_plane(delta: float, given: Dictionary) -> void:
	var input: Dictionary
	# The bot flies its approach and, stopped, gets out.
	if bot != null and (not run.done or run.ml.on_ground()): input = bot.input(run,delta)
	elif scripted: input = given.duplicate()
	else: input = _plane_input()
	if not input.has("flaps"): input["flaps"] = 1.0 if flaps else 0.0
	var was_done := run.done
	var out := run.tick(delta,input)
	_react(out)
	if run.done and not was_done: _finished()
	var ml := run.ml
	if run.done and ml.phase != ManualLanding.STOPPED: _report.visible = false
	if ml.phase == ManualLanding.EXIT: _hop_figure(ml.hop)
	figure.update(delta,run.plane,0.0,Callable(Course,"ground"),ml.would_grease(Callable(Course,"floor_at")))
	spray.update(delta,_wheels(),run.plane.velocity,ml.grit if ml.phase == ManualLanding.ROLL else 0.0,TURF)
	if out.has("out"):
		_step_out()
		return
	chase.cine = Vector3(-1.2,0.0,0.3) if ml.on_ground() else Vector3.ZERO
	_frame(delta)

## The plane's input from the keys and the pad (as the wanderer's).
func _plane_input() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*get_physics_process_delta_time())
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	var input := {
		"turn":stick.x,"pitch":stick.y,"look":Vector2.ZERO,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),
		"lean":clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0),
		"roll":_roll_asked,"flaps":1.0 if flaps else 0.0,"exit":_exit_asked,
	}
	_roll_asked = 0.0
	_exit_asked = false
	return input

## F (or Y): in the air the flaps go down or up; stopped, get out; rolling,
## it says to stop first.
func land_key() -> void:
	if mode != "plane": return
	var ml := run.ml
	if ml.flying():
		flaps = not flaps
		_say("Flaps %s" % ("down" if flaps else "up"))
	else:
		_exit_asked = true

## Where the wheels meet the ground (global), for the grit.
func _wheels() -> Vector3:
	var p: Vector3 = run.plane.position
	var land := Course.floor_at(Vector2(p.x,p.z))
	return Vector3(p.x,land if not is_nan(land) else p.y-0.8,p.z)

## The touch, a hop, the slide, the stop: the thump, the dust, the shake,
## the pad, a word.
func _react(out: Dictionary) -> void:
	if out.has("bounce"):
		var b: Dictionary = out.bounce
		_thump.volume_db = 0.0
		_thump.play()
		_shake = SHAKE_TIME
		_shake_size = 1.0
		Pad.pulse(0.6,0.5,0.2)
		var why := {"tumble":"mid roll","rough":"ground too steep"}
		_say("Hop: %s" % why.get(str(b.reason),str(b.reason)))
	elif out.has("settled"):
		var k := float(out.settled.k)
		if out.has("greaser"):
			Pad.pulse(0.2,0.1,0.1)
			_say("Greaser!")
		else:
			# Hot or hard: it takes the hit and sticks.
			_thump.volume_db = linear_to_db(0.35+0.65*k)
			_thump.play()
			_shake = SHAKE_TIME
			_shake_size = 0.3+0.7*k
			Pad.pulse(0.3+0.4*k,0.15+0.4*k,0.12+0.1*k)
			spray.burst(_wheels(),k,TURF)
			_say({"hot":"Hot! Drift it to a stop","hard":"Hard one! Stuck it","wingtip":"Wingtip! Stuck it","firm":"Down"}.get(str(out.settled.grade),"Down"))
	if out.has("stopped"): _say("Stopped, %.1f m to spare. F to get out" % float(out.stopped.margin) if float(out.stopped.margin) < 20.0 else "Stopped. F to get out")
	if out.has("not_yet"): _say("Stop first")
	if out.has("off_edge"): _say("Off the edge: flying again")
	if out.has("lifted"): _say("Touch and go")
	if out.has("hit"):
		_thump.volume_db = 0.0
		_thump.play()
		Pad.pulse(0.5,0.4,0.15)

func _say(text: String) -> void:
	_flash.text = text
	_flash_time = 2.2

## The pilot mid-hop out of the cockpit: `k` 0 in, 1 out beside it.
func _hop_figure(k: float) -> void:
	if k <= 0.0:
		var p: Vector3 = run.plane.position
		var h: float = run.plane.heading
		var forward := Vector3(-sin(h),0.0,-cos(h))
		var right := Vector3(cos(h),0.0,-sin(h))
		_hop_from = p+Vector3.UP*0.1
		var spot := p-right*HOP_SIDE+forward*HOP_AHEAD
		var ground := Course.floor_at(Vector2(spot.x,spot.z))
		if is_nan(ground): spot = p+right*HOP_SIDE
		ground = Course.floor_at(Vector2(spot.x,spot.z))
		_hop_to = Vector3(spot.x,ground if not is_nan(ground) else p.y,spot.z)
		figure.show_pilot(false)
	walker.visible = k > 0.0
	var at := _hop_from.lerp(_hop_to,smoothstep(0.0,1.0,k))
	at.y += 0.8*sin(PI*k)
	walker.position = at

## Out: the plane parked where it stopped, the pilot beside it, on foot.
func _step_out() -> void:
	parked = true
	figure.park(PlaneFigure.pose(run.plane.position,run.plane.heading,run.plane.pitch,run.plane.bank))
	if _hop_to == Vector3.ZERO: _hop_figure(0.0)
	feet = _hop_to
	_feet_v = 0.0
	var to := run.plane.position-feet
	facing = atan2(-to.x,-to.z)
	_foot_yaw = facing
	walker.visible = true
	mode = "foot"
	_hop_to = Vector3.ZERO
	_say("Walk back to the plane and Space to fly")

# --- On foot -------------------------------------------------------------------------

## True on foot within BOARD_REACH of the parked plane.
func by_plane() -> bool:
	if mode != "foot" or not parked: return false
	var p: Vector3 = run.plane.position
	return Vector2(feet.x-p.x,feet.z-p.z).length() <= BOARD_REACH

func _tick_foot(delta: float, given: Dictionary) -> void:
	var move: Vector2
	var jump := false
	if scripted:
		move = given.get("move",Vector2.ZERO)
		jump = bool(given.get("jump",false))
	else:
		var stick := Input.get_vector(&"move_left",&"move_right",&"move_back",&"move_forward")
		move = stick
		var held := Input.is_action_pressed(&"walk_jump")
		jump = held and not _jump_was
		_jump_was = held
		var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
		_foot_yaw -= right.x*STICK_LOOK*delta
	var ground := Course.floor_at(Vector2(feet.x,feet.z))
	var grounded := not is_nan(ground) and feet.y <= ground+0.02
	# By the plane, Space climbs in; anywhere else it only hops.
	if jump and grounded and by_plane():
		board()
		return
	if jump and grounded: _feet_v = HOP
	var forward := Vector3(-sin(_foot_yaw),0.0,-cos(_foot_yaw))
	var right := Vector3(cos(_foot_yaw),0.0,-sin(_foot_yaw))
	var way := forward*move.y+right*move.x
	if way.length() > 1.0: way = way.normalized()
	var next := feet+way*WALK*delta
	# The parked plane stands in the way.
	var p: Vector3 = run.plane.position
	if Vector2(next.x-p.x,next.z-p.z).length() < 1.0: next = Vector3(feet.x,next.y,feet.z)
	if way.length() > 0.05: facing = atan2(-way.x,-way.z)
	_feet_v -= FALL*delta
	next.y += _feet_v*delta
	var under := Course.floor_at(Vector2(next.x,next.z))
	if is_nan(under):
		# Off the edge: a drop, never a flight.
		feet = next
		_step_off()
		return
	if next.y <= under:
		next.y = under
		_feet_v = 0.0
	feet = next
	walker.position = feet
	walker.rotation = Vector3(0.0,facing,0.0)
	var eye := feet-forward*FOOT_CAM.x+Vector3.UP*FOOT_CAM.y
	camera.global_transform = Transform3D(Basis.looking_at(feet+Vector3.UP*0.8-eye,Vector3.UP),eye+_shaken(delta))
	camera.fov = lerpf(camera.fov,60.0,1.0-exp(-delta/0.2))

## Space by the plane: in, and the takeoff (board, taxi round to its best
## run, roll, lift) from where it stands.
func board() -> void:
	parked = false
	walker.visible = false
	var plane: SkyPlane = run.plane
	takeoff = PlaneLanding.new()
	takeoff.take_off(plane,takeoff_run(Vector2(plane.position.x,plane.position.z),float(plane.heading)),Callable(Course,"floor_at"))
	figure.reset(plane)
	figure.show_pilot(true)
	chase.reset(plane,camera.global_position,camera.fov)
	mode = "takeoff"
	flaps = false

## The best run from `at` (global XZ), facing `heading`: as PlaneStrip
## `takeoff` reads the plate, over the course's fields.
static func takeoff_run(at: Vector2, heading: float) -> Dictionary:
	var best := {}
	var facing := Vector2(-sin(heading),-cos(heading))
	for k in range(24):
		var dir := Vector2.from_angle(TAU*k/24.0)
		var t := 0.5
		var edge := false
		while t < 60.0:
			if is_nan(Course.floor_at(at+dir*t)):
				edge = true
				break
			t += 0.5
		var length := t-0.5
		var score := minf(PlaneStrip.LIFT_RUN if edge else length,PlaneStrip.LIFT_RUN)*2.0+(1.5 if edge else 0.0)+PlaneStrip.ON_WAY*dir.dot(facing)
		if best.is_empty() or score > float(best.score): best = {"dir":Vector3(dir.x,0.0,dir.y),"length":length,"edge":edge,"score":score}
	return best

func _tick_takeoff(delta: float) -> void:
	takeoff.step(delta)
	var plane: SkyPlane = run.plane
	plane.engine = takeoff.engine
	figure.update(delta,plane,0.0,Callable(Course,"ground"),false)
	chase.cine = Vector3(-1.2,-0.04,0.3) if takeoff.phase != PlaneLanding.LIFT else Vector3.ZERO
	_frame(delta)
	if takeoff.done():
		takeoff = null
		_next_run(plane)
		mode = "plane"
		chase.cine = Vector3.ZERO

# --- Off the edge: the drop and the sail ----------------------------------------------

## Walked off the land: a drop into the air, carried on out the way it
## walked, upright, under the walker's gravity; Space opens the sail. The
## plane stays parked.
func _step_off() -> void:
	dive = SkyDive.new()
	dive.water = Course.SEA_Y
	dive.floor_y = Course.SEA_Y-30.0
	var out := Vector3(-sin(facing),0.0,-cos(facing))*WALK
	dive.step_off(feet+Vector3.UP*SkyDive.HIPS,out,facing,null,PilotMotor.GRAVITY*PilotMotor.FALL,PilotMotor.TERMINAL)
	_off_y = feet.y
	sail_wing.reset()
	dive_camera.reset(dive,camera.global_position,camera.fov)
	mode = "drop"
	_say("Off the edge: Space for the sail")

func _tick_drop(delta: float, given: Dictionary) -> void:
	var input := {}
	if scripted:
		input = given.duplicate()
	else:
		var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
		input = {"turn":stick.x,"pitch":stick.y,"boost":Input.get_action_strength(&"dive_tuck"),"brake":Input.get_action_strength(&"fly_brake"),"open":_open_asked}
		_open_asked = false
	_fall(delta,input)
	if mode != "drop": return
	# Well under the edge (or down on anything but the plane's field):
	# stranded.
	if dive.position.y < _off_y-STRAND_BELOW: _strand()

## The dive's step, the pilot and sail drawn on it, its camera; touched
## down, `_drop_down`.
func _fall(delta: float, input: Dictionary) -> void:
	var out := {}
	if dive.phase != SkyDive.DOWN: out = dive.fall(delta,input,Callable(Course,"ground"),func(p: Vector3) -> Dictionary: return Course.air_at(p,run.t))
	walker.position = dive.position-Vector3.UP*SkyDive.HIPS
	walker.visible = true
	walker.rotation = Vector3(0.0,dive.heading,0.0)
	sail_wing.update(delta,dive.sailing(),-float(input.get("turn",0.0)))
	dive_camera.step(delta,dive)
	camera.global_transform = Transform3D(Basis.looking_at(dive_camera.look-dive_camera.eye,Vector3.UP),dive_camera.eye)
	camera.fov = dive_camera.fov
	if out.has("touched"): _drop_down(out.touched)

## Down off the drop: on the plane's own field, on foot to walk back to
## it; anywhere else (a lower shelf, another field, the sea) stranded.
func _drop_down(touch: Dictionary) -> void:
	feet = dive.position-Vector3.UP*SkyDive.HIPS
	sail_wing.update(0.0,false)
	if mode == "stranded": return
	if not bool(touch.get("water",false)) and parked and walkable_to_plane(feet):
		feet.y = Course.floor_at(Vector2(feet.x,feet.z))
		_feet_v = 0.0
		mode = "foot"
		_say("Down. Walk back to the plane")
		return
	_strand()

func _strand() -> void:
	mode = "stranded"
	_stranded = 0.0
	_say("Stranded: back to the plane soon" if stranded_rule == "return" else "Stranded: the plane is coming for you")

## Whether a walk from `at` (global) reaches the parked plane over land:
## the same field (pad) the plane stands on.
func walkable_to_plane(at: Vector3) -> bool:
	var p: Vector3 = run.plane.position
	var mine := _pad_under(Vector2(at.x,at.z))
	return mine != "" and mine == _pad_under(Vector2(p.x,p.z)) and absf(Course.floor_at(Vector2(at.x,at.z))-at.y) < 1.0

## "station:pad" of the highest pad under a global XZ point, or "".
static func _pad_under(p: Vector2) -> String:
	var s := Course.station_near(Vector3(p.x,0.0,p.y))
	var o := Course.origin(s)
	var best := ""
	var top := -INF
	for i in range(s.pads.size()):
		var h := Course.pad_top(s.pads[i],Vector2(p.x-o.x,p.y-o.z))
		if not is_nan(h) and h > top:
			top = h
			best = "%s:%d" % [s.id,i]
	return best

## Stranded, waiting: then (`stranded_rule` "return") a fade and the
## pilot stands beside the parked plane again, to board it; or ("pickup")
## the plane is there and you are flying, nose up over where you came down.
func _tick_stranded(delta: float) -> void:
	_stranded += delta
	# Still floating down, or bobbing where it came down.
	if dive.phase != SkyDive.DOWN: _fall(delta,{})
	else:
		walker.position = feet+Vector3.UP*0.05*sin(_stranded*3.0)
		sail_wing.update(delta,false)
	feet = dive.position-Vector3.UP*SkyDive.HIPS
	var dark := clampf((_stranded-(PICKUP_WAIT-FADE))/FADE,0.0,1.0)
	_veil.color.a = dark*0.9
	if _stranded < PICKUP_WAIT: return
	_veil.color.a = 0.0
	sail_wing.reset()
	if stranded_rule == "return" and parked:
		_hop_to = Vector3.ZERO
		_hop_figure(0.0)
		walker.visible = true
		feet = _hop_to
		_hop_to = Vector3.ZERO
		_feet_v = 0.0
		var to: Vector3 = run.plane.position-feet
		facing = atan2(-to.x,-to.z)
		_foot_yaw = facing
		mode = "foot"
		_say("Back by the plane")
		return
	var plane: SkyPlane = run.plane
	plane.position = feet+Vector3.UP*3.0
	plane.heading = facing
	plane.resume(SkyPlane.CRUISE_SPEED,0.35)
	_next_run(plane)
	parked = false
	walker.visible = false
	figure.reset(plane)
	chase.reset(plane,camera.global_position,camera.fov)
	mode = "plane"
	_say("Picked up")

# --- The camera ----------------------------------------------------------------------

func _frame(delta: float) -> void:
	chase.step(delta,run.plane,0.0,_solid)
	var way := chase.look-chase.eye
	if way.length() < 0.01: way = run.plane.forward()
	camera.global_transform = Transform3D(Basis.looking_at(way,Vector3.UP),chase.eye+_shaken(delta))
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

## The bounce's shake, dying away.
func _shaken(delta: float) -> Vector3:
	if _shake <= 0.0: return Vector3.ZERO
	_shake = maxf(0.0,_shake-delta)
	var k := _shake/SHAKE_TIME
	var t := Time.get_ticks_msec()*0.001
	return Vector3(sin(t*71.0),sin(t*53.0+1.3),sin(t*61.0+2.1))*SHAKE*_shake_size*k*k

func _solid(p: Vector3) -> bool:
	var under: Variant = Course.ground(p)
	if under == null: return p.y < Course.SEA_Y+0.3
	return p.y < (under as Vector2).x+0.2 and p.y > (under as Vector2).y

# --- The numbers ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Control.new()
	_hud.position = Vector2(16.0,12.0)
	_hud.size = Vector2(440.0,300.0)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_bars)
	layer.add_child(_hud)
	_hud_label = Label.new()
	_style(_hud_label,15)
	_hud_label.position = Vector2(0.0,96.0)
	_hud.add_child(_hud_label)
	_hint = Label.new()
	_hint.text = "WASD/stick turn and pitch (W noses down) · Space/RT boost · Shift/LT brake · F/Y flaps, and out once stopped · Q/E lean · On the wheels: steer hard or Q/E + steer to drift, Shift + steer to slide, + a blip of Space to power-slide · 1-5 stations · H approach · R again · N next · B who flies · F1 numbers · Esc mouse"
	_style(_hint,14)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -36.0
	_hint.offset_left = -700.0
	_hint.offset_right = 700.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_hint)
	_flash = Label.new()
	_style(_flash,28)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_flash.offset_top = 90.0
	_flash.offset_left = -400.0
	_flash.offset_right = 400.0
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_flash)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0.05,0.05,0.07,0.0)
	layer.add_child(_veil)
	layer.move_child(_veil,0)
	_report = PanelContainer.new()
	_report.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_report.offset_left = -320.0
	_report.offset_right = 320.0
	_report.offset_top = -150.0
	_report.offset_bottom = 150.0
	_report.visible = false
	layer.add_child(_report)
	_report_label = Label.new()
	_style(_report_label,17)
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.add_child(_report_label)

func _style(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("fbf6ea"))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	label.add_theme_constant_override("shadow_offset_y",1)

func _show_hud() -> void:
	_hud.queue_redraw()
	if not _hud.visible or run == null: return
	var live := run.live()
	var s: Dictionary = run.ml.stats
	var over := "-" if is_nan(float(live.over)) else "%.1f m" % float(live.over)
	var now := str(live.touch_now)
	var touch_line := ""
	if run.ml.flying(): touch_line = "a touch now would be %s" % ({"greaser":"a GREASER","firm":"firm","hot":"HOT: drift it","hard":"HARD: it sticks","wingtip":"on a WINGTIP: it sticks","tumble":"a HOP (mid roll)","rough":"a HOP (too steep)"}.get(now,now))
	elif run.ml.phase == ManualLanding.ROLL: touch_line = "%s · slip %.0f° · grit %.2f · %.1f m to the edge" % ["POWER-SLIDE" if live.power else ("sliding" if live.sliding else "gripping"),rad_to_deg(absf(float(live.slip))),float(live.grit),float(live.edge)]
	_hud_label.text = "\n".join(PackedStringArray([
		"%s · %s approach · %s · %s%s" % [station.name,approach,run.pilot,mode if mode != "plane" else str(live.phase),"" if not run.done else " (run over)"],
		"time %.1f s · over the land %s · bank %.2f · pitch %.2f · flaps %s" % [float(live.t),over,float(live.bank),float(live.pitch),"down" if flaps else "up"],
		"touches %d · greasers %d · hops %d · go-arounds %d · last touch %s" % [int(live.touches),int(s.greasers),int(live.bounces),int(live.go_arounds),str(live.last_touch) if live.last_touch != "" else "-"],
		"slid %.1f m · peak slip %.0f° · touch-and-gos %d · off the edge %d · out before stopping %d" % [float(s.slide_distance),rad_to_deg(float(s.peak_slip)),int(s.touch_and_gos),int(s.off_edge),int(s.early_exits)],
		touch_line,
	]))

## Speed, sink and bank against a greaser's limits (the white tick).
func _draw_bars() -> void:
	if run == null: return
	var live := run.live()
	var font := ThemeDB.fallback_font
	var rows := [
		["speed",float(live.speed),ManualLanding.TOUCH_FAST,24.0,"%.1f m/s" % float(live.speed)],
		["sink",maxf(0.0,float(live.sink)),ManualLanding.GREASE_SINK,5.0,"%.2f m/s" % float(live.sink)],
		["bank",absf(float(live.bank)),ManualLanding.GREASE_BANK,1.2,"%.2f rad" % float(live.bank)],
	]
	_hud.draw_rect(Rect2(-8.0,-6.0,450.0,210.0),Color(0.0,0.0,0.0,0.35))
	var y := 6.0
	for row: Array in rows:
		_hud.draw_string(font,Vector2(0.0,y+14.0),row[0],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fbf6ea"))
		var full := Rect2(70.0,y,220.0,16.0)
		_hud.draw_rect(full,Color(1.0,1.0,1.0,0.15))
		var share := clampf(float(row[1])/float(row[3]),0.0,1.0)
		var over := float(row[1]) > float(row[2])
		_hud.draw_rect(Rect2(full.position,Vector2(full.size.x*share,full.size.y)),Color(0.9,0.35,0.25) if over else Color(0.45,0.8,0.5))
		var x := full.position.x+full.size.x*clampf(float(row[2])/float(row[3]),0.0,1.0)
		_hud.draw_line(Vector2(x,y-2.0),Vector2(x,y+18.0),Color.WHITE,2.0)
		_hud.draw_string(font,Vector2(300.0,y+14.0),row[4],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fbf6ea"))
		y += 26.0

## The run is over: saved, and the report shown.
func _finished() -> void:
	last_run = run.finish()
	last_path = Log.save(last_run,log_dir)
	_report.visible = true
	_report_label.text = report_text(station,last_run)

static func report_text(s: Dictionary, saved: Dictionary) -> String:
	var m: Dictionary = saved.metrics
	var lines := PackedStringArray()
	lines.append("%s · %s approach · %s" % [s.name,str(m.get("approach","normal")),saved.pilot])
	if bool(m.stopped):
		lines.append("GREASER! A tidy one" if bool(m.greaser) else "Stuck it: %s" % str(m.grade))
		lines.append("Stopped in %.1f s · rolled %.1f m from the touch · %.1f m to spare" % [float(m.time_to_stop),float(m.rollout),float(m.stop_margin)])
		lines.append("The touch: %.1f m/s, sinking %.2f m/s (a greaser under %.1f and %.1f)" % [float(m.touch_speed),float(m.touch_sink),ManualLanding.TOUCH_FAST,ManualLanding.GREASE_SINK])
		if float(m.slide_distance) > 0.5: lines.append("Slid %.1f m · peak slip %.0f° · power-slides %d" % [float(m.slide_distance),rad_to_deg(float(m.peak_slip)),int(m.power_slides)])
	else:
		lines.append("No stop in %.0f s" % float(m.duration))
	if m.first_touch_speed != null and int(m.touches) > 1:
		lines.append("First touch: %.1f m/s, sinking %.2f m/s" % [float(m.first_touch_speed),float(m.first_touch_sink)])
	var reasons: Dictionary = m.bounce_reasons
	lines.append("Hops %d%s · go-arounds %d · touch-and-gos %d · off the edge %d" % [int(m.bounces),
		"" if reasons.is_empty() else " ("+", ".join(reasons.keys().map(func(k: String) -> String: return "%s %d" % [k,int(reasons[k])]))+")",
		int(m.go_arounds),int(m.touch_and_gos),int(m.off_edge)])
	if int(m.early_exits) > 0: lines.append("Asked to get out before stopping: %d" % int(m.early_exits))
	if bool(m.stopped): lines.append("Stopped %.1f m into the field, %.1f m off its middle" % [float(m.stop_along),float(m.stop_off)])
	lines.append("\nF out · R again · N next · H approach · 1-5 a station")
	return "\n".join(lines)

# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var by := Vector2(-event.relative.x,-event.relative.y)*LOOK
		if mode == "foot": _foot_yaw += by.x
		elif mode == "drop": dive_camera.turn(by)
		else: chase.turn(by)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventJoypadButton and event.pressed:
		if Pad.pressed(event,&"fly_land"): land_key()
		elif mode == "drop" and Pad.pressed(event,&"walk_jump"): _open_asked = true
		elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
		elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F: land_key()
			KEY_SPACE: if mode == "drop": _open_asked = true
			KEY_R: restart()
			KEY_N: next_station()
			KEY_H:
				approach = Course.APPROACH_NAMES[(Course.APPROACH_NAMES.find(approach)+1)%Course.APPROACH_NAMES.size()]
				restart()
				_say("Approach: %s" % approach)
			KEY_B:
				pilot = PILOTS[(PILOTS.find(pilot)+1)%PILOTS.size()]
				restart()
			KEY_F1: _hud.visible = not _hud.visible
			KEY_Q: _lean_tapped(-1.0)
			KEY_E: _lean_tapped(1.0)
			_:
				if key >= KEY_1 and key <= KEY_9:
					var s := Course.station_by_key(key-KEY_0)
					if not s.is_empty(): start(s)

func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now
