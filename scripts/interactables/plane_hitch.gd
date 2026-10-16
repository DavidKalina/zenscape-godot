extends Node3D
## The plane's hitch, a ground-only greybox: a line from a reel on the
## parked plane's tail post to a crate or a boulder (scripts/interactables/
## hitch_load.gd, real rigid bodies on the turf), connected on foot.
##
## The line has two ends, each the plane's reel, the pilot's hand or a load.
## E (pad B) does the next thing where he stands:
##   at the reel, empty-handed     takes the hook: the line pays out from
##                                 the reel as he walks, against its brake
##                                 (he walks a little slower);
##   at a load, empty-handed       ties the line on and takes the other end
##                                 (in `pull` mode a fixed length: walk off
##                                 and the line goes taut and he drags the
##                                 load behind him, slowed by its weight and
##                                 held by one he can't shift; in `crank`
##                                 mode it pays out from a coil as he walks);
##   carrying, at the other end    clips the line on: the load hitched to
##                                 the plane, whatever slack he left lying;
##   carrying, anywhere else       drops the line;
##   hitched, at the load          unties it;
##   hitched, at the reel          `crank`: held, winds the line in (the
##                                 slack quickly, then slower as the load
##                                 drags, stalling at CRANK_STALL);
##                                 `pull`: unclips it.
## H (on foot, nothing carried) switches pull and crank. --hitch=pull|crank
## picks the mode to start with (crank); --no-hitch leaves it all out.
##
## The line is a one-way spring (it pulls, never pushes) between its ends,
## K stiff, damped near critically, pulling the load at its tie point in
## the physics step. On the pilot it pulls back by scaling his run and,
## once his pull is spent, holding him at the line's length. Hitched to the
## plane it follows the plane as it taxis; over SNAP it parts. Drawn as a
## rope sagging by its slack, laid on the ground where it meets it.
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const HitchLoad = preload("res://scripts/interactables/hitch_load.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const ACTION := &"hitch"
## The line's stiffness (N/m) and damping (of critical, by the load's mass).
const K := 12000.0
const DAMP := 0.8
## What the pilot can pull (N), what the winch can (it stalls there), and
## where the line parts.
const PULL := 1800.0
const CRANK_STALL := 6000.0
const SNAP := 25000.0
## In the plane (boarded, on its wheels or flying) the line is the air's:
## softer (K_AIR, so the plane's frame steps don't jerk it), and the reel
## slips over BRAKE, paying out line under that brake up to MAX_LINE, so a
## snatch is a lurch, not a snap; only at MAX_LINE can it reach SNAP. The
## plane feels the line (SkyPlane `tow`): its pull over PLANE_HEFT (N per
## m/s²), the heft its engine and wings answer with. With PUSH 4.5 m/s² on
## the wheels the brake's pull straight back (6.7 m/s²) holds it: a load the brake can't
## drag (the big boulder) keeps it on the ground. A load in the air drags
## AIR_DRAG x its size² x speed² (N) against the way it moves.
const K_AIR := 3000.0
const BRAKE := 6000.0
const PLANE_HEFT := 900.0
const AIR_DRAG := 0.6
## Winding (m/s): the slack, and the line under no load (slower as it pulls).
const CRANK_SLACK := 2.4
const CRANK := 0.9
## The line's longest and shortest (m); the coil a tied load starts with
## past his reach in pull mode.
const MAX_LINE := 40.0
const MIN_LINE := 1.4
const LEASH := 0.4
## His reach to a load (m past its size) and to the reel (across).
const GRAB_REACH := 1.1
const REEL_REACH := 2.2
## His run while carrying: the reel's brake (a light lean), and the most a
## load's drag takes off it (at his full pull).
const BRAKE_RUN := 0.85
const DRAG_RUN := 0.7
## The hitch ring on the tail post, in the plane figure's frame (scripts/
## plane_figure.gd: the tail skid at z 0.66).
const TAIL := Vector3(0.0,0.05,0.56)
const SEGMENTS := 20
## The line drawn this thick in the plane (of the swing rope's).
const AIR_THIN := 0.55
const ROPE_LIFT := 0.035
## A crank's tick every this much line wound (m).
const TICK_EVERY := 0.25
const TURF_LAYER := 1 << 11

var isle: Node3D
var motor: PilotMotor
var loads: Array = []
var mode := "crank"
## "idle", "carrying" (an end in his hand) or "hitched" (plane to load).
var state := "idle"
## The ends: "plane", "hand" or "load"; the load and where the line ties on
## it (its own frame).
var end_a := ""
var end_b := ""
var cargo: HitchLoad = null
var tie := Vector3.ZERO
## The line's length (m) and its pull now (N, along the line).
var length := 0.0
var tension := 0.0
var cranking := false
var snapped := 0
## In the plane: the reel slipping now, line it has paid out under the
## brake since hitched (m), the most pull since hitched (N).
var slipping := false
var slipped := 0.0
var peak := 0.0
var _base_run := -1.0
var _base_walk := -1.0
var _wound := 0.0
var _lean := 0.0
var _segments: Array[MeshInstance3D] = []
var _knot: MeshInstance3D
var _reel: Node3D
var _handle: Node3D
var _hint: Label
var _readout: Label
var _say := ""
var _say_left := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _tick: AudioStreamPlayer3D

## The hitch on `scene` (a kit isle): its loads round the parked plane once
## the isle is up.
static func build(scene: Node3D) -> Node3D:
	var args := LaunchArgs.user_args()
	if args.has("--no-hitch"): return null
	var hitch: Variant = load("res://scripts/interactables/plane_hitch.gd").new()
	for arg in args:
		if arg.begins_with("--hitch="): hitch.mode = "pull" if arg.get_slice("=",1) == "pull" else "crank"
	hitch.isle = scene
	scene.add_child(hitch)
	if bool(scene.get("isle_up")): hitch._place_loads()
	else: scene.isle_ready.connect(hitch._place_loads,CONNECT_ONE_SHOT)
	return hitch

func _init() -> void:
	name = "PlaneHitch"

func _ready() -> void:
	_ensure_action()
	motor = isle.motor
	var host: Node3D = isle.get("foot_pieces")
	if host == null:
		host = FootPieces.new()
		isle.add_child(host)
		host.attach(isle)
	host.extras.append(self)
	var mesh := SwingRope._rope_mesh(Color("8a7356"))
	for i in range(SEGMENTS):
		var seg := MeshInstance3D.new()
		seg.mesh = mesh
		seg.visible = false
		add_child(seg)
		_segments.append(seg)
	_knot = MeshInstance3D.new()
	_knot.mesh = SwingRope._knot_mesh(0.07,0.12,Color("5a4a38"))
	_knot.visible = false
	add_child(_knot)
	_build_reel()
	_build_ui()
	_tick = AudioStreamPlayer3D.new()
	_tick.stream = preload("res://assets/audio/foley/chisel-tick-1.wav")
	_tick.volume_db = -8.0
	add_child(_tick)
	_ray.collision_mask = 1|TURF_LAYER

static func _ensure_action() -> void:
	if InputMap.has_action(ACTION): return
	InputMap.add_action(ACTION,0.5)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event(ACTION,key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	pad.device = -1
	InputMap.action_add_event(ACTION,pad)

## Five loads round the parked plane on open, level turf with room over
## it, NEAR to FAR m off, out of its takeoff run (RUN_CLEAR either side of
## straight ahead), SPREAD apart: the nearest free ring for each in turn.
const NEAR := 7.0
const FAR := 26.0
const RUN_CLEAR := deg_to_rad(50.0)
const SPREAD := 4.0
const KINDS := ["crate_small","crate_big","boulder_small","boulder_mid","boulder_big"]

func _place_loads() -> void:
	var at: Vector3 = isle.parked_at
	var heading: float = isle.parked_heading
	var ahead := PilotMotor.forward(heading)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var taken: Array = []
	var r := NEAR
	var turn := 0.0
	while r <= FAR and taken.size() < KINDS.size():
		for i in range(20):
			if taken.size() >= KINDS.size(): break
			var a := TAU*float(i)/20.0+turn
			var way := Vector2(cos(a),sin(a))
			if absf(way.angle_to(ahead)) < RUN_CLEAR: continue
			var top: Vector3 = isle._turf_top(space,at.x+way.x*r,at.z+way.y*r)
			if top == Vector3.INF or absf(top.y-at.y) > 3.0 or not isle._room_for_pilot(space,top): continue
			# A clear walk back to the plane (nothing knee high between).
			var sight := PhysicsRayQueryParameters3D.create(top+Vector3.UP*0.6,at+Vector3.UP*0.6,1|TURF_LAYER)
			if not space.intersect_ray(sight).is_empty(): continue
			var crowded := false
			for t: Vector3 in taken:
				if t.distance_to(top) < SPREAD: crowded = true
			if crowded: continue
			taken.append(top)
		r += 2.5
		turn += 0.4
	for i in range(taken.size()):
		var body: HitchLoad = HitchLoad.new()
		body.setup(KINDS[i],taken[i],heading+0.7*i,900+i)
		add_child(body)
		loads.append(body)
	if taken.size() < KINDS.size(): push_warning("plane hitch: room for %d of %d loads" % [taken.size(),KINDS.size()])

# --- The frame round the motor (scripts/interactables/foot_pieces.gd) -------

func before(_delta: float) -> void:
	if state != "carrying":
		if _base_run >= 0.0:
			motor.run = _base_run
			motor.walk = _base_walk
			_base_run = -1.0
		return
	if _base_run < 0.0:
		_base_run = motor.run
		_base_walk = motor.walk
	var k := BRAKE_RUN
	if _other_end() == "load" and mode == "pull": k = 1.0-DRAG_RUN*clampf(tension/PULL,0.0,1.0)
	motor.run = _base_run*k
	motor.walk = _base_walk*lerpf(1.0,k,0.6)

func after(delta: float, _events: Dictionary) -> void:
	cranking = false
	# (Hung from the plane on a taut line, under an edge or below the isle
	# in flight, it isn't lost: it's carried.)
	var hung := state == "hitched" and _other_end_from("load") == "plane" and tension > 0.0
	if cargo != null and not hung and cargo.global_position.y < float(isle.get("lost")):
		_let_go("The load fell away")
		return
	if state == "carrying": _carry(delta)
	elif state == "hitched": _hitched(delta)

## An end in his hand: the line pays out (from the reel; from a coil in
## crank mode) up to MAX_LINE, or holds him at its length.
func _carry(_delta: float) -> void:
	var other := _other_end()
	var from := _end_point(other)
	var hand := _hand()
	var d := from.distance_to(hand)
	var pays := other == "plane" or mode == "crank"
	if pays and d > length: length = minf(d,MAX_LINE)
	if other == "load" and absf(from.y-hand.y) > 2.5 and d >= length:
		_let_go("The line tore out of your hands")
		return
	# Past what the line gives (its stretch under his full pull): held.
	var give := length+PULL/K+0.03
	if d <= give: return
	var flat := Vector3(hand.x-from.x,0.0,hand.z-from.z)
	var dy := hand.y-from.y
	var room := sqrt(maxf(give*give-dy*dy,0.0))
	if flat.length() <= room or flat.length() < 1e-4: return
	var n := flat.normalized()
	var pull_back := flat.length()-room
	motor.feet -= n*pull_back
	var out := Vector3(motor.velocity.x,0.0,motor.velocity.z).dot(n)
	if out > 0.0: motor.velocity -= n*out

## Plane to load: held at the reel in crank mode, the winch winds it in.
func _hitched(delta: float) -> void:
	if mode != "crank" or not Input.is_action_pressed(ACTION) or not _by_reel() or not motor.grounded: return
	cranking = true
	var d := _end_point("plane").distance_to(_end_point("load"))
	var rate := CRANK_SLACK if length > d+0.05 else CRANK*clampf(1.0-tension/CRANK_STALL,0.0,1.0)
	var was := length
	length = maxf(length-rate*delta,MIN_LINE)
	_wound += was-length
	if _wound >= TICK_EVERY:
		_wound = 0.0
		_tick.global_position = _end_point("plane")
		_tick.pitch_scale = randf_range(0.9,1.15)*(1.0 if length > d else 0.8)
		_tick.play()
	if _handle != null: _handle.rotate_object_local(Vector3.RIGHT,rate*delta*6.0)
	var to := _end_point("plane")-motor.feet
	motor.facing = lerp_angle(motor.facing,PilotMotor.facing_of(Vector2(to.x,to.z)),0.2)

## A lean against the line while it drags at his hand.
func pose(figure: Node3D) -> void:
	var want := 0.0
	if state == "carrying" and _other_end() == "load": want = clampf(tension/PULL,0.0,1.0)*0.28
	_lean = lerpf(_lean,want,0.15)
	if _lean < 0.005: return
	var from := _end_point("load")
	var to := from-figure.global_position
	var flat := Vector3(to.x,0.0,to.z)
	if flat.length() < 0.01: return
	var axis := flat.normalized().cross(Vector3.UP)
	figure.basis = Basis(axis,-_lean)*figure.basis

# --- The line's pull on the load ---------------------------------------------

func _physics_process(_delta: float) -> void:
	tension = 0.0
	slipping = false
	var aloft := _in_plane()
	# In the plane the loads are off layer 1, so the plane's checks for
	# stone (its bumps, what blocks its wheels) don't meet its own load.
	var layer := 0 if aloft else 1
	for body: HitchLoad in loads:
		if body.collision_layer != layer: body.collision_layer = layer
	if cargo == null or state == "idle":
		_tow(Vector3.ZERO)
		return
	var other := _other_end_from("load")
	var towing := aloft and other == "plane"
	if towing:
		cargo.sleeping = false
		_drag_air()
	var p := cargo.to_global(tie)
	var e := _end_point(other)
	var d := p.distance_to(e)
	if d <= length or d < 1e-4:
		_tow(Vector3.ZERO)
		return
	var u := (e-p)/d
	var arm := p-cargo.global_position
	var v_p := cargo.linear_velocity+cargo.angular_velocity.cross(arm)
	var v_e := Vector3.ZERO
	if other == "hand": v_e = motor.velocity
	elif aloft: v_e = isle.plane.velocity
	var closing := (v_p-v_e).dot(u)
	var k := K_AIR if towing else K
	var damp := 2.0*sqrt(k*cargo.mass)*DAMP*closing
	var t := k*(d-length)-damp
	if t <= 0.0:
		_tow(Vector3.ZERO)
		return
	if other == "hand": t = minf(t,PULL)
	elif towing and t > BRAKE and length < MAX_LINE:
		# The reel slips: line out until the stretch holds just the brake's
		# pull (the drum turning takes the stretch's rate, so no damping).
		var was := length
		length = clampf(d-BRAKE/k,was,MAX_LINE)
		slipped += length-was
		slipping = true
		t = BRAKE if length < MAX_LINE else maxf(k*(d-length)-damp,BRAKE)
	if other != "hand" and t > SNAP:
		snapped += 1
		_tow(Vector3.ZERO)
		_let_go("The line parted")
		return
	tension = t
	peak = maxf(peak,t)
	cargo.sleeping = false
	cargo.apply_force(u*t,arm)
	if towing: _tow(-u*t/PLANE_HEFT)
	else: _tow(Vector3.ZERO)

## The line's pull on the plane (SkyPlane `tow`, m/s²), while in it.
func _tow(accel: Vector3) -> void:
	if not _in_plane(): return
	var plane: RefCounted = isle.plane
	plane.tow = accel

## The air against a load swinging under the plane.
func _drag_air() -> void:
	var v := cargo.linear_velocity
	var s := v.length()
	if s < 0.5: return
	cargo.apply_central_force(-v*s*AIR_DRAG*cargo.size*cargo.size)

## In the plane: boarded, on its wheels or flying (isle.plane a SkyPlane).
func _in_plane() -> bool:
	return isle != null and bool(isle.get("flying")) and isle.get("plane") != null and "tow" in isle.plane

# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _on_foot(): return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_H and state == "idle":
		mode = "pull" if mode == "crank" else "crank"
		_said("Hitch: %s" % mode)
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(ACTION) or event.is_echo(): return
	if isle.has_method("can_pick") and isle.can_pick(): return
	if press(): get_viewport().set_input_as_handled()

## E where he stands; true if it did something (drivers call it too).
func press() -> bool:
	var near := _load_in_reach()
	var reel := _by_reel()
	match state:
		"idle":
			if near != null and (not reel or _load_gap(near) < _reel_gap()):
				_tie_on(near)
				end_a = "load"
				end_b = "hand"
				state = "carrying"
				length = _end_point("load").distance_to(_hand())+(LEASH if mode == "pull" else 0.0)
				_said("Line tied to the %s" % _named(near))
				return true
			if reel:
				end_a = "plane"
				end_b = "hand"
				state = "carrying"
				length = _end_point("plane").distance_to(_hand())
				_said("Hitch line in hand")
				return true
		"carrying":
			var other := _other_end()
			if other == "plane" and near != null:
				var slack := length-_end_point("plane").distance_to(_hand())
				_tie_on(near)
				end_b = "load"
				length = _end_point("plane").distance_to(_end_point("load"))+maxf(slack,0.0)
				state = "hitched"
				_said("Hitched to the %s" % _named(near))
				return true
			if other == "load" and reel:
				var slack := length-_end_point("load").distance_to(_hand())
				end_b = "plane"
				length = _end_point("plane").distance_to(_end_point("load"))+maxf(slack,0.0)
				state = "hitched"
				_said("Hitched to the plane")
				return true
			_let_go("Line dropped")
			return true
		"hitched":
			if near == cargo:
				_let_go("Untied")
				return true
			if reel and mode == "pull":
				_let_go("Unclipped")
				return true
	return false

func _tie_on(body: HitchLoad) -> void:
	cargo = body
	tie = body.tie_point(_hand())

func _let_go(why: String) -> void:
	_tow(Vector3.ZERO)
	slipped = 0.0
	peak = 0.0
	state = "idle"
	end_a = ""
	end_b = ""
	cargo = null
	tension = 0.0
	length = 0.0
	_said(why)

# --- Where things are ------------------------------------------------------------

func _on_foot() -> bool:
	return isle != null and not bool(isle.get("flying")) and bool(isle.get("walk_ready"))

func _hand() -> Vector3:
	var f := PilotMotor.forward(motor.facing)
	var s: float = isle.get("wanderer_scale")
	return motor.feet+Vector3.UP*0.95*s+Vector3(f.x,0.0,f.y)*0.3*s

## The hitch ring on the plane's tail post (where it stands parked or
## taxis), or its parked spot with no figure.
func _ring() -> Vector3:
	var fig: Node3D = isle.get("plane_figure")
	if fig != null: return fig.global_transform*TAIL
	return isle.parked_at+Vector3.UP*0.5

func _end_point(which: String) -> Vector3:
	match which:
		"plane": return _ring()
		"hand": return _hand()
		"load": return cargo.to_global(tie) if cargo != null else Vector3.ZERO
	return Vector3.ZERO

func _other_end() -> String:
	return end_a if end_b == "hand" else end_b

func _other_end_from(which: String) -> String:
	return end_b if end_a == which else end_a

func _by_reel() -> bool:
	return _on_foot() and _reel_gap() <= REEL_REACH

func _reel_gap() -> float:
	var r := _ring()
	return Vector2(motor.feet.x-r.x,motor.feet.z-r.z).length()

func _load_gap(body: HitchLoad) -> float:
	return maxf(body.global_position.distance_to(_hand())-body.size,0.0)

func _load_in_reach() -> HitchLoad:
	var best: HitchLoad = null
	for body: HitchLoad in loads:
		var gap := _load_gap(body)
		if gap <= GRAB_REACH and (best == null or gap < _load_gap(best)): best = body
	return best

func _named(body: HitchLoad) -> String:
	return body.kind.replace("_"," ").replace("crate small","small crate").replace("crate big","big crate").replace("boulder small","small boulder").replace("boulder mid","boulder").replace("boulder big","big boulder")

# --- Drawn ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_place_reel()
	_draw_line()
	_update_ui(delta)

func _draw_line() -> void:
	var on := state != "idle" and _on_foot_or_hitched()
	_knot.visible = on and cargo != null
	for seg: MeshInstance3D in _segments: seg.visible = on
	if not on: return
	var a := _end_point(end_a)
	var b := _end_point(end_b)
	var d := a.distance_to(b)
	var slack := maxf(length-d,0.0)
	var sag := sqrt(3.0*d*slack/8.0) if d > 0.01 else slack*0.5
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var skip: Array[RID] = []
	if cargo != null: skip.append(cargo.get_rid())
	_ray.exclude = skip
	var points := PackedVector3Array()
	for i in range(SEGMENTS+1):
		var t := float(i)/SEGMENTS
		var p := a.lerp(b,t)+Vector3.DOWN*sag*4.0*t*(1.0-t)
		if i > 0 and i < SEGMENTS:
			_ray.from = p+Vector3.UP*2.5
			_ray.to = p+Vector3.DOWN*0.2
			var hit := space.intersect_ray(_ray)
			if not hit.is_empty() and (hit.position as Vector3).y+ROPE_LIFT > p.y: p.y = (hit.position as Vector3).y+ROPE_LIFT
		points.append(p)
	# Thinner in the plane, against the toy-sized plane in flight.
	var thin := Basis.from_scale(Vector3(AIR_THIN,1.0,AIR_THIN)) if _in_plane() else Basis.IDENTITY
	for i in range(SEGMENTS):
		_segments[i].transform = Transform3D(SwingRope._segment_basis(points[i],points[i+1])*thin,points[i])
	if cargo != null: _knot.global_position = cargo.to_global(tie)

func _on_foot_or_hitched() -> bool:
	return state == "hitched" or _on_foot()

## A drum and a crank handle on the tail post (in the plane figure's frame,
## so its scale), following the plane.
func _build_reel() -> void:
	_reel = Node3D.new()
	_reel.name = "HitchReel"
	add_child(_reel)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("3a3734")
	iron.roughness = 0.7
	iron.metallic = 0.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("6b4e33")
	wood.roughness = 1.0
	var drum := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 0.09
	cyl.radial_segments = 10
	cyl.material = wood
	drum.mesh = cyl
	drum.rotation = Vector3(0.0,0.0,PI*0.5)
	_reel.add_child(drum)
	_handle = Node3D.new()
	_handle.position = Vector3(0.06,0.0,0.0)
	_reel.add_child(_handle)
	var arm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.008,0.06,0.008)
	box.material = iron
	arm.mesh = box
	arm.position = Vector3(0.0,0.03,0.0)
	_handle.add_child(arm)
	var grip := MeshInstance3D.new()
	var knob := BoxMesh.new()
	knob.size = Vector3(0.03,0.012,0.012)
	knob.material = wood
	grip.mesh = knob
	grip.position = Vector3(0.018,0.06,0.0)
	_handle.add_child(grip)

func _place_reel() -> void:
	var fig: Node3D = isle.get("plane_figure")
	_reel.visible = fig != null and fig.is_visible_in_tree()
	if not _reel.visible: return
	var xf := fig.global_transform
	_reel.global_transform = Transform3D(xf.basis,xf*(TAIL+Vector3(0.0,0.06,0.04)))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hint = Label.new()
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -300.0
	_hint.offset_right = 300.0
	_hint.offset_top = -150.0
	_hint.offset_bottom = -120.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size",20)
	_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	_hint.add_theme_constant_override("shadow_offset_x",1)
	_hint.add_theme_constant_override("shadow_offset_y",1)
	layer.add_child(_hint)
	_readout = Label.new()
	_readout.anchor_left = 1.0
	_readout.anchor_right = 1.0
	_readout.offset_left = -340.0
	_readout.offset_right = -16.0
	_readout.offset_top = 16.0
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_readout.add_theme_font_size_override("font_size",15)
	_readout.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	_readout.add_theme_constant_override("shadow_offset_x",1)
	_readout.add_theme_constant_override("shadow_offset_y",1)
	layer.add_child(_readout)

func _said(text: String) -> void:
	_say = text
	_say_left = 1.6

func _update_ui(delta: float) -> void:
	_say_left = maxf(_say_left-delta,0.0)
	var foot := _on_foot()
	_hint.visible = foot
	_readout.visible = foot or state == "hitched"
	if not foot and state != "hitched": return
	_hint.text = _say if _say_left > 0.0 else _prompt()
	var lines := ["hitch: %s  (H)" % mode]
	if state != "idle":
		var d := _end_point(end_a).distance_to(_end_point(end_b))
		lines.append("line %.1f m  ·  slack %.1f m" % [length,maxf(length-d,0.0)])
		lines.append("pull %d N%s%s" % [int(tension)," · stalled" if cranking and tension > CRANK_STALL*0.97 else ""," · reel slipping" if slipping else ""])
		if state == "hitched" and _in_plane(): lines.append("paid out %.1f m  ·  most %d N" % [slipped,int(peak)])
	_readout.text = "\n".join(lines)

func _prompt() -> String:
	var near := _load_in_reach()
	var reel := _by_reel()
	match state:
		"idle":
			if near != null and (not reel or _load_gap(near) < _reel_gap()): return "E  tie the line to the %s" % _named(near)
			if reel: return "E  take the hitch line"
		"carrying":
			var other := _other_end()
			if other == "plane" and near != null: return "E  hitch the %s" % _named(near)
			if other == "load" and reel: return "E  hitch it to the plane"
			return "E  drop the line"
		"hitched":
			if near == cargo: return "E  untie"
			if reel: return "hold E  crank in" if mode == "crank" else "E  unclip"
	return ""
