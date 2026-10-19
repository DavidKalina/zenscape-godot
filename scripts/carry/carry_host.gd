extends Node3D
## Picking up and carrying treasures (docs/design/carry/spec-carry.md), on a
## kit isle's wanderer (studies/kit_isle.gd: its `motor`, `body`, `figure`).
## The host stands the treasures on their spots (each spot a node the world
## view moves, `<scene>/treasure_NN`, the treasure resting on it), and takes
## the `walk_carry` action (E, pad B; scripts/pad.gd) on foot:
##
## - by a treasure he lifts it, over its weight's `lift` (scripts/carry/
##   carry_weights.gd): he crouches and bends over to it, reaching down, holds
##   there under it (`strain`, a shiver for the heavy), heaves it up as he
##   straightens, and it settles (a squash, his knees giving, a lean back
##   past the carry); his paces held to a shuffle meanwhile;
## - carrying, he holds it in both hands (two-bone IK on the figure's arms
##   after its clips): before his chest, or hugged low against his belly for
##   the heavy (`hold`), his knees a little bent (`sag`), leaning back
##   against it (`lean`), rolling side to side at each step (`waddle`); his
##   walk, run, jump and turn scaled by its weight. All procedural (legs by
##   IK on a lowered pivot), stood in for authored clips (lock-in);
## - pressed again, he crouches and sets it down on the ground before him
##   (or at his feet where there is no ground before him), lets go and
##   stands;
## - the moves its weight bars (`bars`: the motor's `wall_on`, `ledge_on`,
##   `sail_on`, `rope_on`) are off while he holds it; tried, the motor's
##   `refused` comes and he balks: a stagger to the side and a shake of the
##   head, his pace held back (procedural, stood in for authored clips);
## - a heavy load sways the camera at each footfall and puts a thud under
##   his steps (`sway`, `dip`, `thud`);
## - a knock (the rune knight's shot, a stun) or a long fall knocks it out
##   of his hands, and set down in the air it is let fall: it tumbles loose
##   (a rigid body on TREASURE_LAYER, which his walk never sees, so it
##   can't push or launch him; continuous collision, spawned only where it
##   is clear of walls), is frozen where it comes to rest, and can be
##   lifted from there. Fallen under the isle (`lost` on the study) it is
##   lost for the deal.
##
## - the plane trails a cargo sling on a rope (scripts/carry/cargo_sling.gd,
##   made with the plane): parked, it lies on the turf behind it. Pressed
##   carrying by the sling, he turns to it and lowers the load in over its
##   rim; it rides in the sling from then: dragged as the plane taxis,
##   swinging under it in flight. Pressed there empty-handed he takes the
##   last one loaded back out. The bag swells and its rope pays out with
##   the kg in it; a hit on it spills the last loaded, more the harder
##   (SPILL_* in carry_weights.gd): they tumble loose as a drop does.
##
## `deal()` puts every treasure back on its spot (the scene's re-deal),
## the loaded ones too.
const Weights = preload("res://scripts/carry/carry_weights.gd")
const Models = preload("res://scripts/carry/treasure_models.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const Pad = preload("res://scripts/pad.gd")
const GenesisAudio = preload("res://scripts/genesis_audio.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const CargoSling = preload("res://scripts/carry/cargo_sling.gd")

## What he stands on and sets things down on.
const SOLID_MASK := 1|(1 << 11)
## Reach (m across from his feet to the treasure's foot, times his size; and
## up or down from his feet).
const REACH := 1.1
const REACH_UP := 0.7
## Where its middle rides at the chest: out from the chest bone (m, times
## his size, past its own radius) and up from it (the chest bone's root is
## at his belly, about 0.48 m up on a 1 m wanderer).
const HOLD_OUT := 0.1
const HOLD_UP := 0.08
## Where it is set down: this far before his feet (times his size, past its
## radius); the ground looked for this far over and under.
const SET_OUT := 0.35
const SET_OVER := 1.2
const SET_UNDER := 2.5
## The elbows' pull: out to his sides, down and back (figure frame, +z back).
const ELBOW := Vector3(0.8,-0.6,0.35)
## His paces while he heaves or sets down, times the empty-handed ones.
const BUSY_PACE := 0.05
## A "hug" (heavy): its middle this far out before the chest bone (past its
## radius) and up from it (m, times size), the hands this far down its
## height from its middle.
const HUG_OUT := 0.04
const HUG_UP := -0.02
const HUG_UNDER := 0.22
## The lift's beats, of its length: the reach down ends, the heave ends (its
## settle after). Setting down takes SET_TIME of the lift: lowered by
## SET_DOWN, let go and standing from SET_LET.
const REACH_END := 0.3
const HEAVE_END := 0.78
const SET_TIME := 0.8
const SET_DOWN := 0.55
const SET_LET := 0.65
## The legs: thigh, shin, boot, side (+1 right).
## The loose treasures' own layer (his walk's queries don't see it).
const TREASURE_LAYER := 1 << 24
const LEGS := [["thigh.L","shin.L","foot.L",-1.0],["thigh.R","shin.R","foot.R",1.0]]

var study: Node3D = null
var scene_id := ""
## The treasures: [{id, kind, weight, spot (Node3D), node (Node3D), measures,
## body (RigidBody3D while loose, else null), still (s it has lain still),
## lost (fell off the isle this deal), slot (its spot in the sling, -1
## none), strapped (s since it was loaded)}].
var treasures: Array = []
## The one in his hands ({} none), and its phase: "lift", "carry", "set".
var held: Dictionary = {}
var phase := ""
var phase_t := 0.0
## Where the treasure was lifted from or is set down at (its foot, world).
var _ground_at := Transform3D.IDENTITY
## The motor's own feel, kept while he carries.
var _base := {}
var _prompt: Label3D = null
## The balk (a refused move): seconds into it (<0 none), the move refused,
## the side he staggers to. `balks` counts them (drivers read it).
var _balk_t := -1.0
var balked := ""
var balks := 0
var _balk_side := 1.0
## The footfalls under a load: the figure's stride phase last frame, the
## side and seconds since the last footfall, the thud's player.
var _stride := 0.0
var _fall_side := 1.0
var _fall_t := 99.0
var heavy_steps := 0
var _thud: AudioStreamPlayer = null
## Drops: the motor's knock count last seen, the top of his air since he
## left the ground, how many were knocked out, how many lost (drivers).
var _knocks := 0
var _air_top := -INF
var drops := 0
## Others holding him back (the stone brood's clingers, scripts/brood/):
## his carry's walk and run times this (1: free). `set_slow`.
var slow := 1.0
var losses := 0
## The hitch: the plane's sling (null until the plane is drawn), the spot
## the one in his hands goes to, how many have been loaded (drivers).
var sling: Node3D = null
var _slot_to := -1
var hitches := 0
## Spilled from the bag so far (drivers); time since the last spill.
var spills := 0
var _spill_t := 99.0
## The load's effects now (carry_weights.gd `load_of`, from the bag's kg),
## told to the plane and its hand landing every frame (the plane can be
## made anew); the `--heavy` flag's weight, which a light bag never lowers.
var load_now := Weights.load_of(0.0)
## Others riding the bag (the stone brood's clingers): their kg, added to
## the bag's load but never past its takeoff limit. `set_riders_kg`.
var riders_kg := 0.0
var _heavy_flag := -1.0
static var _thud_take: AudioStreamWAV = null

## Stands the treasures in `spec` ([id, kind, weight, foot (world), yaw deg])
## for the kit isle `host`, named `<id_scene>/<id>`.
func setup(host: Node3D, id_scene: String, spec: Array) -> void:
	study = host
	scene_id = id_scene
	name = "Treasures"
	process_priority = 100
	for row: Array in spec:
		var called := "%s/%s" % [scene_id,str(row[0])]
		if LayoutOverrides.deleted(called): continue
		var spot := Node3D.new()
		spot.name = "Spot_"+str(row[0])
		var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(row[4]))),row[3])
		spot.transform = LayoutOverrides.xform(called,coded)
		add_child(spot)
		LayoutOverrides.track(called,spot,"token",coded)
		var made := Models.build(str(row[1]))
		var node := Node3D.new()
		node.name = "Treasure_"+str(row[0])
		node.add_child(made.node as Node3D)
		spot.add_child(node)
		treasures.append({"id":str(row[0]),"kind":str(row[1]),"weight":str(row[2]),"spot":spot,"node":node,"measures":made,"body":null,"still":0.0,"lost":false,"slot":-1,"strapped":0.0})
	_prompt = Label3D.new()
	_prompt.name = "Prompt"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 36
	_prompt.pixel_size = 0.006
	_prompt.outline_size = 8
	_prompt.visible = false
	add_child(_prompt)
	var motor: Variant = study.get("motor")
	if motor != null: motor.refused.connect(_on_refused)
	_thud = AudioStreamPlayer.new()
	_thud.name = "Thud"
	_thud.bus = GenesisAudio.BUS
	_thud.stream = _thud_stream()
	add_child(_thud)

## Every treasure back on its spot, settled on what's under it; nothing
## carried.
func deal() -> void:
	if not held.is_empty(): _let_go()
	for t: Dictionary in treasures: _home(t)

func _home(t: Dictionary) -> void:
	_unloose(t)
	_unstrap(t)
	t.lost = false
	var node: Node3D = t.node
	node.visible = true
	var spot: Node3D = t.spot
	if node.get_parent() != spot:
		node.get_parent().remove_child(node)
		spot.add_child(node)
	node.transform = Transform3D.IDENTITY
	var foot := _ground_under(spot.global_position,SET_OVER,SET_UNDER)
	if foot != Vector3.INF: node.global_position = foot

## Whether he carries anything (lifting and setting down count).
func carrying() -> bool:
	return not held.is_empty()

## The weight class of what he carries, or "".
func load_class() -> String:
	return "" if held.is_empty() else str(held.weight)

# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"walk_carry",false,true) or event.is_echo(): return
	if not _on_foot(): return
	if held.is_empty():
		var t := in_reach()
		if t.is_empty(): t = _last_hitched() if _by_sling() else {}
		if t.is_empty(): return
		lift(t)
	elif phase == "carry":
		if _by_sling(): hitch()
		else: set_down()
	else: return
	get_viewport().set_input_as_handled()

## On foot, walking, the world view shut.
func _on_foot() -> bool:
	if study == null or not bool(study.get("walk_ready")) or bool(study.get("flying")): return false
	var editor := study.get_node_or_null("LayoutEdit")
	return editor == null or not bool(editor.get("editing"))

## The nearest resting treasure in reach of his feet, or {}.
func in_reach() -> Dictionary:
	var motor: Variant = study.get("motor")
	if not motor.grounded: return {}
	var feet: Vector3 = motor.feet
	var s: float = motor.size
	var best := {}
	var near := REACH*s
	for t: Dictionary in treasures:
		if t == held or bool(t.lost) or int(t.slot) >= 0: continue
		if t.body != null and not (t.body as RigidBody3D).freeze: continue
		var at: Vector3 = (t.node as Node3D).global_position
		var across := Vector2(at.x-feet.x,at.z-feet.z).length()-float(t.measures.radius)
		if across < near and absf(at.y-feet.y) < REACH_UP:
			near = across
			best = t
	return best

# --- Lifting and setting down ---------------------------------------------------------

## Starts the heave of `t`: off its spot, into his hands over its lift.
func lift(t: Dictionary) -> void:
	var node: Node3D = t.node
	_unstrap(t)
	_ground_at = node.global_transform
	_unloose(t)
	node.get_parent().remove_child(node)
	add_child(node)
	node.global_transform = _ground_at
	held = t
	phase = "lift"
	_knocks = int(study.get("motor").knocks)
	_air_top = -INF
	phase_t = 0.0
	_keep_feel()
	_apply_feel(BUSY_PACE)

## Starts setting the carried one down before him.
func set_down() -> void:
	if held.is_empty(): return
	var motor: Variant = study.get("motor")
	if not motor.grounded:
		drop("let fall")
		return
	var fwd := _forward()
	var s: float = motor.size
	var out := SET_OUT*s+float(held.measures.radius)
	var foot := _ground_under(motor.feet+fwd*out,SET_OVER,SET_UNDER)
	if foot == Vector3.INF or absf(foot.y-motor.feet.y) > SET_OVER: foot = motor.feet+fwd*(float(held.measures.radius)*0.5)
	_ground_at = Transform3D(Basis(Vector3.UP,atan2(-fwd.x,-fwd.z)),foot)
	phase = "set"
	phase_t = 0.0
	_apply_feel(BUSY_PACE)

## Let go where it is now: left resting on the ground at `_ground_at`.
func _let_go() -> void:
	var node: Node3D = held.node
	node.global_transform = _ground_at
	held = {}
	phase = ""
	_balk_t = -1.0
	_restore_feel()

func _process(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	_spill_t += delta
	_sling_step(delta)
	if not held.is_empty():
		if bool(study.get("flying")):
			var t := held
			_let_go()
			_home(t)
		else:
			_drop_check()
			if not held.is_empty(): _carry_step(delta)
	for t: Dictionary in treasures:
		if t.body != null: _loose_step(t,delta)
		if int(t.slot) >= 0: _ride(t,delta)
	_show_prompt()

# --- Dropping ----------------------------------------------------------------------

## Knocked (his knock count up, or laid down stunned) or fallen DROP_FALL
## below the top of his air: it is knocked out of his hands.
func _drop_check() -> void:
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var knocked: bool = int(motor.knocks) > _knocks or str(motor.move) == "tumble"
	_knocks = int(motor.knocks)
	if bool(motor.grounded): _air_top = -INF
	else: _air_top = maxf(_air_top,float(motor.feet.y))
	if knocked: drop("knock")
	elif _air_top > -INF and _air_top-float(motor.feet.y) > Weights.DROP_FALL*s: drop("fall")

## Out of his hands now, as it is (`why`: "knock", "fall", "let fall"):
## it tumbles loose with his velocity times its `spill`, a toss up and a
## spin, from where it is clear of walls between his chest and his hands.
func drop(why: String) -> void:
	if held.is_empty(): return
	var t := held
	var w := Weights.of(str(t.weight))
	var motor: Variant = study.get("motor")
	var node: Node3D = t.node
	var at := node.global_transform
	held = {}
	phase = ""
	_balk_t = -1.0
	_restore_feel()
	_knocks = int(motor.knocks)
	_air_top = -INF
	drops += 1
	var h: float = t.measures.height
	# Its middle, moved back toward his chest till it is clear of walls.
	var mid := at*Vector3(0.0,h*0.5,0.0)
	var chest := _bone_world("chest")
	if chest == Vector3.INF: chest = motor.feet+Vector3.UP*0.6*float(motor.size)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _loose_shape(float(t.measures.radius),h)
	q.collision_mask = SOLID_MASK
	q.transform = Transform3D(at.basis,chest)
	q.motion = mid-chest
	var cast := get_world_3d().direct_space_state.cast_motion(q)
	var safe: float = cast[0] if cast.size() > 0 else 1.0
	var v: Vector3 = motor.velocity if why == "knock" else motor.ground_velocity()
	var spin := Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))
	_loosen(t,Transform3D(at.basis,chest+(mid-chest)*maxf(safe-0.02,0.0)),
		v*float(w.spill)+Vector3.UP*Weights.DROP_UP*(1.0 if why == "knock" else 0.3),
		spin.limit_length(1.0)*Weights.DROP_SPIN*(1.0 if why == "knock" else 0.4))
	if OS.is_debug_build(): print("carry: %s dropped (%s) at %s" % [t.id,why,(t.body as Node3D).global_position])

## `t` loose: a tumbling body with its middle at `mid`, moving `v`,
## spinning `spin`.
func _loosen(t: Dictionary, mid: Transform3D, v: Vector3, spin: Vector3) -> void:
	var w := Weights.of(str(t.weight))
	var node: Node3D = t.node
	var h: float = t.measures.height
	var r: float = t.measures.radius
	var body := RigidBody3D.new()
	body.name = "Loose_"+str(t.id)
	body.collision_layer = TREASURE_LAYER
	body.collision_mask = SOLID_MASK
	body.mass = float(w.mass)
	body.continuous_cd = true
	body.can_sleep = true
	body.linear_damp = 0.2
	body.angular_damp = 1.5
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.1
	body.physics_material_override = mat
	var shape := CollisionShape3D.new()
	shape.shape = _loose_shape(r,h)
	body.add_child(shape)
	add_child(body)
	body.global_transform = mid
	node.get_parent().remove_child(node)
	body.add_child(node)
	node.transform = Transform3D(Basis.IDENTITY,Vector3(0.0,-h*0.5,0.0))
	body.linear_velocity = v
	body.angular_velocity = spin
	t.body = body
	t.still = 0.0

## An eight-sided prism its size, about its middle (rolls on its side,
## stands on its foot).
static func _loose_shape(r: float, h: float) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for i in 8:
		var a := TAU*i/8.0
		var p := Vector2(cos(a),sin(a))*r*0.9
		pts.append(Vector3(p.x,-h*0.5,p.y))
		pts.append(Vector3(p.x*0.8,h*0.5,p.y*0.8))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	return shape

## A loose one's frame: frozen once it has lain still SETTLE_TIME; lost
## once under the isle.
func _loose_step(t: Dictionary, delta: float) -> void:
	var body: RigidBody3D = t.body
	var lost_y: Variant = study.get("lost")
	var floor_y := float(lost_y) if lost_y != null and is_finite(float(lost_y)) else -200.0
	if body.global_position.y < floor_y:
		_unloose(t)
		(t.node as Node3D).visible = false
		t.lost = true
		losses += 1
		if OS.is_debug_build(): print("carry: %s lost off the isle" % t.id)
		return
	if body.freeze: return
	if body.linear_velocity.length() < Weights.SETTLE_SPEED and body.angular_velocity.length() < Weights.SETTLE_SPIN:
		t.still = float(t.still)+delta
	else: t.still = 0.0
	if float(t.still) >= Weights.SETTLE_TIME or body.sleeping:
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true
		if OS.is_debug_build(): print("carry: %s came to rest at %s" % [t.id,body.global_position])

## Its body gone: the treasure back under the host where it lies.
func _unloose(t: Dictionary) -> void:
	var body: RigidBody3D = t.body
	if body == null: return
	var node: Node3D = t.node
	var at := node.global_transform
	body.remove_child(node)
	add_child(node)
	node.global_transform = at
	body.queue_free()
	t.body = null
	t.still = 0.0

# --- Refusals ------------------------------------------------------------------------

func _on_refused(what: String) -> void:
	if held.is_empty(): return
	balked = what
	balks += 1
	_balk_t = 0.0
	_balk_side = -_balk_side
	if phase == "carry": _apply_feel(Weights.BALK_PACE)

## The balk's pose on the figure after its clips: the chest lurched to one
## side and back, the head shaken no; over BALK_TIME.
func _balk_pose(delta: float) -> void:
	if _balk_t < 0.0: return
	_balk_t += delta
	var k := _balk_t/Weights.BALK_TIME
	if k >= 1.0:
		_balk_t = -1.0
		if phase == "carry": _apply_feel(1.0)
		return
	var sk := _skeleton()
	if sk == null: return
	var fwd := _forward()
	var lurch := sin(PI*minf(k*1.6,1.0))
	var chest := sk.find_bone("chest")
	if chest >= 0:
		var roll := deg_to_rad(Weights.BALK_LEAN)*lurch*_balk_side
		_turn_bone(sk,chest,fwd,roll)
		# Rocked back on his heels under it, too.
		_turn_bone(sk,chest,fwd.cross(Vector3.UP),deg_to_rad(Weights.BALK_LEAN)*0.5*lurch)
	var head := sk.find_bone("head")
	if head >= 0:
		var shake := sin(TAU*Weights.BALK_SHAKES*k)*(1.0-k)*deg_to_rad(Weights.BALK_HEAD)
		_turn_bone(sk,head,Vector3.UP,shake)

## Turns `bone` by `angle` about the world axis `axis`.
static func _turn_bone(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	var in_sk := (sk.global_basis.inverse()*axis).normalized()
	var local := (sk.get_bone_global_pose(bone).basis.inverse()*in_sk).normalized()
	sk.set_bone_pose_rotation(bone,sk.get_bone_pose_rotation(bone)*Quaternion(local,angle))

# --- The load underfoot ----------------------------------------------------------------

## At each footfall of a carry (the figure's stride crossing 0 or 0.5),
## the thud; the camera's lurch and dip after it.
func _load_feel(delta: float) -> void:
	var w := Weights.of(str(held.weight))
	var body: Node = study.get("body")
	var motor: Variant = study.get("motor")
	var stride: float = body.get("_phase") if body != null and body.get("_phase") != null else 0.0
	var moving: bool = motor.grounded and Vector2(motor.velocity.x,motor.velocity.z).length() > 0.3
	if moving and phase == "carry" and (stride < _stride or (_stride < 0.5 and stride >= 0.5)):
		_fall_side = 1.0 if stride < 0.5 else -1.0
		_fall_t = 0.0
		if float(w.thud) > 0.0:
			heavy_steps += 1
			_thud.volume_db = linear_to_db(float(w.thud))
			_thud.pitch_scale = randf_range(0.9,1.05)
			_thud.play()
	_stride = stride
	_fall_t += delta
	var camera: Camera3D = study.get("camera")
	if camera == null or float(w.sway) <= 0.0: return
	var env := sin(PI*clampf(_fall_t/0.4,0.0,1.0))
	if env <= 0.0: return
	camera.global_position += Vector3.DOWN*float(w.dip)*float(motor.size)*env
	camera.rotate_object_local(Vector3.BACK,deg_to_rad(float(w.sway))*env*_fall_side)

## A low thump: a falling sine under a puff of noise (made once).
static func _thud_stream() -> AudioStreamWAV:
	if _thud_take != null: return _thud_take
	var rate := 22050
	var n := int(rate*0.22)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var ph := 0.0
	var lp := 0.0
	for i in range(n):
		var t := float(i)/rate
		ph += TAU*lerpf(95.0,48.0,minf(t/0.15,1.0))/rate
		lp += (rng.randf_range(-1.0,1.0)-lp)*0.08
		var env := minf(t/0.004,1.0)*exp(-t*18.0)
		var v := clampf((sin(ph)*0.9+lp*0.6*exp(-t*40.0))*env,-1.0,1.0)
		data.encode_s16(i*2,int(v*32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_thud_take = wav
	return wav

## One frame of the heave, the carry or the setting down: his body posed
## (`_pose_at`), the treasure moved between the ground and his hands, his
## arms reached to it.
func _carry_step(delta: float) -> void:
	var w := Weights.of(str(held.weight))
	var lift_time: float = w.lift
	var node: Node3D = held.node
	var k := 1.0
	match phase:
		"lift":
			phase_t += delta
			k = clampf(phase_t/lift_time,0.0,1.0)
			if phase_t-delta < lift_time*HEAVE_END and phase_t >= lift_time*HEAVE_END:
				var body: Node = study.get("body")
				if body != null and body.has_method("land"): body.land(float(w.settle))
			if k >= 1.0:
				phase = "carry"
				_apply_feel(1.0)
		"set":
			phase_t += delta
			k = clampf(phase_t/(lift_time*SET_TIME),0.0,1.0)
		"hitch":
			phase_t += delta
			k = clampf(phase_t/(lift_time*Weights.HITCH_TIME),0.0,1.0)
			var slot: Variant = _slot_xform(_slot_to)
			if slot == null:
				# The sling went (boarded): he keeps it.
				phase = "carry"
				_apply_feel(1.0)
				return
			_ground_at = slot
			_face(_ground_at.origin,delta)
	var pose := _pose_at(phase,k,w)
	_pose_body(pose,w,delta)
	_balk_pose(delta)
	var hands := _hold_xform()
	node.global_transform = _ground_at.interpolate_with(hands,pose[4])
	if phase == "hitch":
		# Lifted in over the rim, not through the net.
		var s: float = study.get("motor").size
		node.global_position += Vector3.UP*Weights.HITCH_ARC*s*sin(PI*clampf(float(pose[4]),0.0,1.0))
	_reach_arms(node.global_transform,maxf(pose[3],0.0001))
	_load_feel(delta)
	if phase == "set" and k >= 1.0: _let_go()
	elif phase == "hitch" and k >= 1.0: _strap()

## The body's pose at `k` through `ph` ("lift", "carry", "set") for the
## weight row `w`: [hips' drop (m), bend over (deg), lean back (deg), the
## arms' reach (0..1), the load's way from the ground to his hands (0..1)].
## Lifting: he crouches and bends to it, reaching down (REACH_END), holds
## there under it (its `strain`), heaves it up as he straightens into the
## carry (to HEAVE_END), and the load settles: his knees give and he leans
## back past the carry and comes back. Setting down runs the other way and
## lets go at the bottom before he stands.
static func _pose_at(ph: String, k: float, w: Dictionary) -> Array:
	var stand := [0.0,0.0,0.0,0.0,0.0]
	var low := [float(w.squat),float(w.bend),0.0,1.0,0.0]
	var carry := [float(w.sag),0.0,float(w.lean),1.0,1.0]
	match ph:
		"lift":
			var grip_end := REACH_END+float(w.strain)
			if k < REACH_END: return _mix(stand,low,_ease(k/REACH_END))
			if k < grip_end:
				var held_low := low.duplicate()
				# The strain: a shiver through him under the weight.
				held_low[1] += float(w.strain)*12.0*sin(k*float(w.lift)*70.0)
				return held_low
			if k < HEAVE_END:
				var p := (k-grip_end)/(HEAVE_END-grip_end)
				# The heave: slow off the ground under a load, then up.
				var e := _ease(pow(p,1.0+float(w.strain)*3.0))
				var up := _mix(low,carry,e)
				up[3] = 1.0
				return up
			var s := sin(PI*(k-HEAVE_END)/(1.0-HEAVE_END))
			var settle := carry.duplicate()
			settle[0] += float(w.squat)*0.35*s
			settle[2] += float(w.lean)*0.6*s
			return settle
		"hitch":
			# Lowered in over the sling's rim: half the set-down's crouch,
			# bent over it.
			var push := [float(w.squat)*0.55,float(w.bend)*0.8,0.0,1.0,0.0]
			if k < SET_DOWN: return _mix(carry,push,_ease(k/SET_DOWN))
			if k < SET_LET: return push
			var u := _mix(push,stand,_ease((k-SET_LET)/(1.0-SET_LET)))
			u[3] = 1.0-_ease(minf((k-SET_LET)/(1.0-SET_LET)*2.0,1.0))
			u[4] = 0.0
			return u
		"set":
			if k < SET_DOWN: return _mix(carry,low,_ease(k/SET_DOWN))
			if k < SET_LET: return low
			var r := _mix(low,stand,_ease((k-SET_LET)/(1.0-SET_LET)))
			r[3] = 1.0-_ease(minf((k-SET_LET)/(1.0-SET_LET)*2.0,1.0))
			r[4] = 0.0
			return r
	return carry

static func _mix(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in range(a.size()): out.append(lerpf(float(a[i]),float(b[i]),t))
	return out

static func _ease(t: float) -> float:
	return smoothstep(0.0,1.0,clampf(t,0.0,1.0))

## His body put in `pose` on the figure after its clips: the hips dropped
## (the figure's pivot lowered, his feet kept where the clips stood them by
## two-bone IK on each leg, knees forward), the chest bent over and leaned
## back, the head looking down at what he reaches for; carrying, the chest
## rolls with each footfall (`waddle`).
func _pose_body(pose: Array, w: Dictionary, _delta: float) -> void:
	var sk := _skeleton()
	var body: Node3D = study.get("body")
	if sk == null or body == null: return
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var drop: float = float(pose[0])*s
	var pivot := body.get("_pivot") as Node3D
	if pivot != null and drop > 0.0005 and motor.grounded:
		var feet: Array = []
		for leg: Array in LEGS:
			var foot := sk.find_bone(str(leg[2]))
			if foot < 0: return
			feet.append([sk.global_transform*sk.get_bone_global_pose(foot).origin,sk.get_bone_global_pose(foot).basis])
		pivot.global_position += Vector3.DOWN*drop
		var to_sk := sk.global_transform.affine_inverse()
		var knee := (sk.global_basis.inverse()*(fwd+right*0.0+Vector3.UP*0.2)).normalized()
		for i in range(LEGS.size()):
			var leg: Array = LEGS[i]
			var thigh := sk.find_bone(str(leg[0]))
			var shin := sk.find_bone(str(leg[1]))
			var foot := sk.find_bone(str(leg[2]))
			var out_side := (sk.global_basis.inverse()*(right*float(leg[3]))).normalized()
			_two_bone(sk,thigh,shin,foot,to_sk*(feet[i][0] as Vector3),(knee+out_side*0.25).normalized(),1.0)
			# The boot kept as the clip set it.
			var parent := sk.get_bone_global_pose(shin).basis
			sk.set_bone_pose_rotation(foot,(parent.inverse()*(feet[i][1] as Basis)).get_rotation_quaternion())
	var chest := sk.find_bone("chest")
	if chest >= 0:
		var lean := float(pose[2])-float(pose[1])
		if absf(lean) > 0.01: _turn_bone(sk,chest,right,deg_to_rad(lean))
		if phase == "carry" and float(w.waddle) > 0.0:
			var env := sin(PI*clampf(_fall_t/0.45,0.0,1.0))
			_turn_bone(sk,chest,fwd,deg_to_rad(float(w.waddle))*env*_fall_side)
	var head := sk.find_bone("head")
	if head >= 0 and float(pose[1]) > 0.01:
		# Eyes on it as he bends: the head a little further down.
		_turn_bone(sk,head,right,-deg_to_rad(float(pose[1]))*0.35)

## Two-bone IK: `upper` and `fore` turned so `end`'s root reaches `goal`
## (skeleton space), bending toward `pole`, `weight` of the way.
static func _two_bone(sk: Skeleton3D, upper: int, fore: int, end: int, goal: Vector3, pole: Vector3, weight: float) -> void:
	var root := sk.get_bone_global_pose(upper).origin
	var mid := sk.get_bone_global_pose(fore).origin
	var tip := sk.get_bone_global_pose(end).origin
	var a := root.distance_to(mid)
	var b := mid.distance_to(tip)
	var to := goal-root
	var d := clampf(to.length(),0.01,(a+b)*0.999)
	var n := to.normalized()
	var along := (a*a-b*b+d*d)/(2.0*d)
	var out := sqrt(maxf(a*a-along*along,0.0))
	var bend := (pole-n*pole.dot(n)).normalized()
	_aim(sk,upper,mid-root,n*along+bend*out,weight)
	mid = sk.get_bone_global_pose(fore).origin
	tip = sk.get_bone_global_pose(end).origin
	_aim(sk,fore,tip-mid,root+n*d-mid,weight)

## Where its foot rides in his hands now (world): before his chest, or
## for a "hug" low against his belly.
func _hold_xform() -> Transform3D:
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var fwd := _forward()
	var chest := _bone_world("chest")
	if chest == Vector3.INF: chest = motor.feet+Vector3.UP*0.6*s
	var r: float = held.measures.radius
	var h: float = held.measures.height
	var mid := chest+fwd*(HOLD_OUT*s+r)+Vector3.UP*HOLD_UP*s
	if str(Weights.of(str(held.weight)).hold) == "hug":
		mid = chest+fwd*(HUG_OUT*s+r)+Vector3.UP*(HUG_UP*s)
	var foot := mid+Vector3.DOWN*h*0.5
	return Transform3D(Basis(Vector3.UP,atan2(-fwd.x,-fwd.z)),foot)

## His facing (world, flat).
func _forward() -> Vector3:
	var fig: Node3D = study.get("figure")
	var f := -fig.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

# --- The arms ------------------------------------------------------------------------

func _skeleton() -> Skeleton3D:
	var body: Node = study.get("body")
	return null if body == null else body.get("_skeleton") as Skeleton3D

func _bone_world(bone_name: String) -> Vector3:
	var sk := _skeleton()
	if sk == null: return Vector3.INF
	var b := sk.find_bone(bone_name)
	return Vector3.INF if b < 0 else sk.global_transform*sk.get_bone_global_pose(b).origin

## Both hands reached to the treasure's sides at `at` (its foot, world),
## `weight` of the way, by two-bone IK on each arm (the clips' pose under it);
## a "hug" puts them low on its sides, under its belly.
func _reach_arms(at: Transform3D, weight: float) -> void:
	var sk := _skeleton()
	if sk == null: return
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var h: float = held.measures.height
	var mid := at.origin+Vector3.UP*h*0.5
	var grip: float = held.measures.grip
	if str(Weights.of(str(held.weight)).hold) == "hug" and phase != "":
		mid += Vector3.DOWN*h*HUG_UNDER
	var to_sk := sk.global_transform.affine_inverse()
	var sides := [["upper_arm.L","forearm.L","hand.L",-1.0],["upper_arm.R","forearm.R","hand.R",1.0]]
	for side: Array in sides:
		var upper := sk.find_bone(str(side[0]))
		var fore := sk.find_bone(str(side[1]))
		var hand := sk.find_bone(str(side[2]))
		if upper < 0 or fore < 0 or hand < 0: return
		var sd: float = side[3]
		var goal := to_sk*(mid+right*sd*grip)
		var pole_w := right*sd*ELBOW.x+Vector3.UP*ELBOW.y-fwd*ELBOW.z
		var pole := (sk.global_basis.inverse()*pole_w).normalized()
		_two_bone(sk,upper,fore,hand,goal,pole,weight)
		# The mitt turned in, palm to the treasure's side.
		var wrist := sk.get_bone_global_pose(hand).origin
		var tip := sk.get_bone_global_pose(hand)*Vector3(0.0,0.03,0.0)
		_aim(sk,hand,tip-wrist,goal-wrist+(to_sk.basis*(-right*sd))*0.02,weight)

## Turns `bone` so its `from` (skeleton space) points along `to`, `weight`
## of the way (scripts/pilot_figure.gd's `_aim_bone`).
static func _aim(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	var axis := from.cross(to)
	if axis.length() < 1e-6: return
	var angle := from.angle_to(to)*weight
	var local := (sk.get_bone_global_pose(bone).basis.inverse()*axis).normalized()
	sk.set_bone_pose_rotation(bone,sk.get_bone_pose_rotation(bone)*Quaternion(local,angle))

# --- The motor's feel ----------------------------------------------------------------

func _keep_feel() -> void:
	var m: Variant = study.get("motor")
	_base = {"walk":m.walk,"run":m.run,"jumps":(m.jumps as Array).duplicate(),"turn":m.turn,"turn_run":m.turn_run,
		"wall_on":m.wall_on,"wallrun_on":m.wallrun_on,"ledge_on":m.ledge_on,"sail_on":m.sail_on,"rope_on":m.rope_on}

## The carried weight's scales on the kept feel; `pace` times the paces
## more (BUSY_PACE while heaving).
func _apply_feel(pace: float) -> void:
	if _base.is_empty(): return
	var m: Variant = study.get("motor")
	var w := Weights.of(str(held.weight))
	m.walk = float(_base.walk)*float(w.walk)*pace*slow
	m.run = float(_base.run)*float(w.run)*pace*slow
	var j: Array = []
	for h: float in _base.jumps: j.append(h*float(w.jump)*(1.0 if pace >= 1.0 else 0.0))
	m.jumps = j
	m.turn = float(_base.turn)*float(w.turn)
	m.turn_run = float(_base.turn_run)*float(w.turn)
	var bars: Array = w.bars
	m.wall_on = bool(_base.wall_on) and not bars.has("wall")
	m.wallrun_on = bool(_base.wallrun_on) and not bars.has("wall")
	m.ledge_on = bool(_base.ledge_on) and not bars.has("ledge")
	m.sail_on = bool(_base.sail_on) and not bars.has("sail")
	m.rope_on = bool(_base.rope_on) and not bars.has("rope")

## Held back to `k` of his carry's paces (1 free); applied at once while
## he walks with it (not while lifting, setting down or balking).
func set_riders_kg(kg: float) -> void:
	riders_kg = maxf(kg,0.0)

func set_slow(k: float) -> void:
	if is_equal_approx(k,slow): return
	slow = k
	if not held.is_empty() and phase == "carry" and _balk_t < 0.0: _apply_feel(1.0)

func _restore_feel() -> void:
	if _base.is_empty(): return
	var m: Variant = study.get("motor")
	m.walk = _base.walk
	m.run = _base.run
	m.jumps = (_base.jumps as Array).duplicate()
	m.turn = _base.turn
	m.turn_run = _base.turn_run
	for gate: String in ["wall_on","wallrun_on","ledge_on","sail_on","rope_on"]: m.set(gate,_base[gate])
	_base = {}

# --- The prompt ----------------------------------------------------------------------

func _show_prompt() -> void:
	_prompt.visible = false
	if bool(load_now.over) and sling != null and sling.grounded:
		# Too heavy to fly: said over the bag, in the plane or by it.
		var by := _by_sling() and held.is_empty() and in_reach().is_empty()
		if not _on_foot() or by:
			_prompt.text = "Too heavy to fly: %.0f of %.0f kg" % [float(load_now.kg),float(Weights.LOAD.max_kg)]
			if by: _prompt.text += "\n"+Pad.pick("E  take it out","B  take it out")
			_prompt.global_position = sling.middle()+Vector3.UP*(float(sling.radius)+0.6)
			_prompt.visible = true
			return
	if not _on_foot(): return
	if not held.is_empty():
		if phase != "carry" or not _by_sling(): return
		var free := _free_slot()
		if free < 0: return
		var at: Variant = _slot_xform(free)
		if at == null: return
		_prompt.text = Pad.pick("E  load it in the sling","B  load it in the sling")
		_prompt.global_position = (at as Transform3D).origin+Vector3.UP*(float(held.measures.height)+0.3)
		_prompt.visible = true
		return
	var t := in_reach()
	var line := Pad.pick("E  lift","B  lift")
	if t.is_empty() and _by_sling():
		t = _last_hitched()
		line = Pad.pick("E  take it out","B  take it out")
	if t.is_empty(): return
	_prompt.text = line
	_prompt.global_position = (t.node as Node3D).global_position+Vector3.UP*(float(t.measures.height)+0.3)
	_prompt.visible = true

## The ground under `p` (a ray from `over` above to `under` below; flat
## enough to stand on), or INF.
func _ground_under(p: Vector3, over: float, under: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*over,p+Vector3.DOWN*under,SOLID_MASK)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6: return Vector3.INF
	return hit.position

# --- The hitch: the plane's cargo sling --------------------------------------------

## The sling made with the plane's figure, and swung under it.
func _sling_step(delta: float) -> void:
	var pf: Node3D = study.get("plane_figure")
	if pf == null: return
	if sling == null:
		sling = CargoSling.new()
		add_child(sling)
		sling.hit.connect(_on_bag_hit)
		_refill()
		sling.rest_behind(pf)
	sling.step(delta,pf)
	_apply_load()

## The bag's kg weighs the plane (carry_weights.gd LOAD): its flight's
## weight model and climb, and its takeoff (roll, lift, unstick, the dip
## off an edge); past max_kg it won't leave the ground.
func _apply_load() -> void:
	var kg := float(sling.load_kg)
	load_now = Weights.load_of(kg+minf(riders_kg,maxf(float(Weights.LOAD.max_kg)-kg,0.0)))
	var plane: Variant = study.get("plane")
	if plane != null:
		if _heavy_flag < 0.0: _heavy_flag = float(plane.heavy)
		plane.heavy = maxf(_heavy_flag,float(load_now.heavy))
		plane.climb_share = 1.0-float(load_now.climb)
	var hl: Variant = study.get("hand_landing")
	if hl != null:
		hl.load_roll = float(load_now.roll)
		hl.load_lift = float(load_now.lift)
		hl.load_unstick = float(load_now.unstick)
		hl.load_dip = float(load_now.dip)
		hl.too_heavy = bool(load_now.over)
		hl.load_top = float(load_now.top)

## By the sling where it lies on the ground, on foot.
func _by_sling() -> bool:
	if sling == null or not sling.grounded or bool(study.get("flying")): return false
	var motor: Variant = study.get("motor")
	var mid: Vector3 = sling.middle()
	var across := Vector2(mid.x-motor.feet.x,mid.z-motor.feet.z).length()-float(sling.radius)
	return across < Weights.SLING_REACH*float(motor.size) and absf(mid.y-float(motor.feet.y)) < 1.0

## The first spot in the bag nothing is loaded in (no cap: its weight
## caps it, in the plane).
func _free_slot() -> int:
	var i := 0
	while true:
		var taken := false
		for t: Dictionary in treasures:
			if int(t.slot) == i: taken = true
		if not taken: return i
		i += 1
	return -1

## The kg in the bag, told to the bag (it swells and pays out rope).
func _refill() -> void:
	if sling == null: return
	var kg := 0.0
	for t: Dictionary in treasures:
		if int(t.slot) >= 0: kg += float(Weights.of(str(t.weight)).mass)
	sling.set_load(kg)

## The bag hit something `speed` m/s hard: it spills, the last loaded
## first, one at SPILL_SPEED and one more each SPILL_STEP harder. Each goes
## loose (it tumbles; onto land it comes to rest where he can find it, into
## the sky it is lost).
func _on_bag_hit(speed: float, _at: Vector3, normal: Vector3, vel: Vector3) -> void:
	if OS.is_debug_build() and speed > 1.0: print("carry: the bag hit something at %.1f m/s" % speed)
	if speed < Weights.SPILL_SPEED or _spill_t < Weights.SPILL_GRACE: return
	var n := 1+int(floor((speed-Weights.SPILL_SPEED)/Weights.SPILL_STEP))
	var gone := 0
	while gone < n:
		var t := _last_hitched()
		if t.is_empty(): break
		_unstrap(t)
		var node: Node3D = t.node
		var h: float = t.measures.height
		var mid := node.global_transform*Vector3(0.0,h*0.5,0.0)
		var side := Vector3(randf_range(-1,1),0.0,randf_range(-1,1)).limit_length(1.0)
		var v := vel*Weights.SPILL_KEEP+(normal+side*0.4)*Weights.SPILL_OUT+Vector3.UP*Weights.SPILL_UP
		var spin := Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).limit_length(1.0)*Weights.DROP_SPIN
		_loosen(t,Transform3D(node.global_basis,mid),v,spin)
		gone += 1
		spills += 1
		if OS.is_debug_build(): print("carry: %s spilled from the bag at %s (hit %.1f m/s)" % [t.id,mid,speed])
	if gone > 0:
		_spill_t = 0.0
		_refill()

## The last one loaded (the highest spot taken), or {}.
func _last_hitched() -> Dictionary:
	var best := {}
	for t: Dictionary in treasures:
		if int(t.slot) >= 0 and (best.is_empty() or int(t.slot) > int(best.slot)): best = t
	return best

## Spot `i` in the sling (world), or null with no sling.
func _slot_xform(i: int) -> Variant:
	var pf: Node3D = study.get("plane_figure")
	if sling == null or pf == null or i < 0: return null
	return sling.slot(i,pf)

## Starts lowering the carried one into the sling's next free spot; with
## none free he balks.
func hitch() -> void:
	if held.is_empty() or phase != "carry": return
	_slot_to = _free_slot()
	phase = "hitch"
	phase_t = 0.0
	_apply_feel(BUSY_PACE)

## He turns to face `p` (his motor's facing, so the walk and figure agree).
func _face(p: Vector3, delta: float) -> void:
	var motor: Variant = study.get("motor")
	var to := Vector2(p.x-motor.feet.x,p.z-motor.feet.z)
	if to.length() < 0.05: return
	motor.facing = lerp_angle(float(motor.facing),PilotMotor.facing_of(to),1.0-exp(-10.0*delta))

## Let go into the sling: it rides there from now.
func _strap() -> void:
	var t := held
	held = {}
	phase = ""
	_balk_t = -1.0
	_restore_feel()
	t.slot = _slot_to
	t.strapped = 0.0
	_slot_to = -1
	hitches += 1
	_refill()
	var cls := Weights.of(str(t.weight))
	_thud.volume_db = linear_to_db(maxf(float(cls.thud),0.05)*1.5)
	_thud.play()
	_ride(t,0.0)
	if OS.is_debug_build(): print("carry: %s loaded in the sling (spot %d)" % [t.id,int(t.slot)])

## Out of the sling: its spot free.
func _unstrap(t: Dictionary) -> void:
	if int(t.slot) < 0: return
	t.slot = -1
	_refill()

## A loaded one rides its spot in the sling (a bounce as it lands there).
func _ride(t: Dictionary, delta: float) -> void:
	var at: Variant = _slot_xform(int(t.slot))
	if at == null: return
	t.strapped = float(t.strapped)+delta
	var k := clampf(float(t.strapped)/Weights.HITCH_SETTLE,0.0,1.0)
	var bounce := Weights.HITCH_BOUNCE*sin(k*PI*2.0)*(1.0-k)
	var xf: Transform3D = at
	(t.node as Node3D).global_transform = Transform3D(xf.basis,xf.origin+xf.basis.y*bounce)
