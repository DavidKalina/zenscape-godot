extends Node3D
## The wanderer's own rope and hook (docs/design/rope/spec-rope.md), on the
## rope study's room (studies/rope_study.gd: its `holds` and `pieces`).
##
## Throw: `walk_throw` held (LMB / T / pad RT) on the ground, coiled: he
## whirls the hook at his side, and a reticle shows where it goes, moved by
## the stick and the camera (the bag's aim, scripts/carry/loot_bag.gd). The
## reticle snaps to the lip of a top above him (the edge facing him) or to
## an anchor post near it. Gold: a hold there (a solid or crumbly lip, a
## post). Red: it won't catch (a smooth top, the floor, the way blocked, out
## of reach); thrown anyway, it misses. Released, the hook flies the arc
## shown, trailing the rope. On a hold it catches: dragged back to the lip
## and hooked over it (state "caught"; the tug, task 3, seats it). With no
## hold it slides off the lip and falls; a blocked arc knocks it down.
##
## Tug: `walk_tug` (E / pad B) on a caught hook: he reaches up the rope
## and yanks it back. A good hold (a post, a solid lip) seats: the rope goes
## taut and it clicks (state "seated", `tested`). A crumbly lip can be a bad
## placement (`bad`, rolled at the catch): the tug pulls the hook back over
## the lip in a spill of grit and it falls. Left untested, a bad hook seems
## caught; it gives under his weight partway up (the climb, task 4).
##
## Climb: Jump by the hanging rope of a caught or seated hook takes hold
## (the motor's rider, scripts/pilot_motor.gd `mount`, held as the swing
## rope's "swing" hang). Stick toward the wall: hand over hand, a pull at a
## time (the body hauled up on the top hand, then the low hand reaching past
## it), slow; let go of the stick and he hangs. Stick away: down hand under
## hand; crouch (Shift / C): slides down fast; Jump: lets go. At the top he
## is handed to the motor's own ledge hang and climb (the haul over the lip,
## slowed to HAUL_TIME). An untested bad hook gives partway up: it tears out
## in grit and he falls.
##
## Rappel: E (the tug) by an anchor post on a top, the rope coiled, ties it
## round the post's foot and throws it over the drop beyond the post (the
## way he looks past it), tugged to seat (`fixed`). Jump at an edge a
## seated rope runs over, facing out: the motor's own catch and lower take
## him over to a hang, then he's on the rope rappelling: leaned back, feet
## on the wall (leg IK), the lead hand up the rope, the brake hand at his
## hip. Stick away from the wall: a hop down (crouch in, push out, swing
## back, land), chained while held, finished when let go; crouch slides;
## stick toward the wall: climbing as from below; Jump lets go. At the
## floor he steps off; the rope stays fixed, so Jump by it climbs back up.
##
## Reel: `walk_reel` (F / pad down) draws the rope in. A caught hook is
## flicked free off its lip first, falls, then is dragged in along the
## ground till it's coiled at his side. From below a fixed rope, it's
## pulled down: it runs round the post and over the edge and falls. From a
## top, it's pulled up hand over hand, the hanging end rising (state
## "pull_up"), then coiled.
##
## The rope is a line of segments from his hand to the hook, sagging by its
## slack (a parabola; paid out length minus the span) and lying on what's
## under it. Kept apart from the motor and the figure's clips, so a bag or
## a load can later ride on it (spec's out-of-scope note).
const CarryHost = preload("res://scripts/carry/carry_host.gd")
const Pad = preload("res://scripts/pad.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## The rope's full length (m, times size); a throw reaches this far.
const ROPE_LEN := 14.0
## The reticle's reach across from his feet (m, times size), its least, where
## it starts (of the reach) and how fast the stick moves it.
const AIM_REACH := 10.0
const AIM_MIN := 1.2
const AIM_START := 0.45
const AIM_SPEED := 8.0
## A top counts as above him (a lip to hook) this high over his feet (m).
const ABOVE := 1.2
## The reticle snaps to an anchor post within this (m, flat).
const POST_SNAP := 1.6
## The hook lands this far in past the lip and is dragged back to it.
const LAND_IN := 0.7
## The hook wraps a post this far under its top.
const POST_WRAP := 0.25
## The throw's arc: its top over the higher end, plus this a metre across.
const AIM_RISE := 1.0
const AIM_RISE_M := 0.08
## The hook flies under this many times gravity (a quick, flat-ish throw).
const HOOK_G := 1.8
const ARC_DOTS := 22
## The whirl while aiming: its radius (m) and turns a second.
const WHIRL_R := 0.45
const WHIRL_RATE := 3.0
## Dragged back from where it landed to the lip (s); sliding off a smooth
## top as long.
const DRAG_TIME := 0.18
## Falling: a bounce off a wall keeps this much.
const BOUNCE := 0.3
## Reeling in: its pace along the ground (m/s) and the flick off a lip.
const REEL_SPEED := 6.0
const FLICK := Vector2(1.6,1.4)
## The tug: reaching up the rope, the yank back, the hold before it settles
## (s); a crumbly lip's chance of being a bad placement; the slip back over
## the lip (s).
const TUG_REACH := 0.2
const TUG_YANK := 0.12
const TUG_HOLD := 0.35
const POOR_BAD := 0.5
const SLIP_TIME := 0.3
## Grit off a crumbly lip: bits, their life (s).
const GRIT := 7
const GRIT_LIFE := 1.4
const GRIT_COLOUR := Color(0.78,0.66,0.46)
## Coiled again within this of his feet (m).
const COILED := 0.7
## The rope's look.
const SEGS := 28
const ROPE_R := 0.022
const ROPE := Color("b59a6a")
const HOOK := Color("3a3d42")
const AIM_OK := Color(1.0,0.92,0.55)
const AIM_BAD := Color(1.0,0.3,0.25)
const LINE_TIME := 2.5
## The climb: within this of the hanging rope (m, flat) Jump takes hold; the
## rope hangs this far out from the edge; a pull's rise (m, the gap between
## the hands too) and time (s: the haul up, then the low hand's reach, at
## REACH_AT of it); down hand under hand and the slide (m/s); the haul over
## the lip (s, the motor's climb slowed); an untested bad hook gives this
## share of the way up (from, to); the hands' spread on the rope (m).
const GRAB_REACH := 1.2
const ROPE_OFF := 0.04
const PULL := 0.4
const PULL_T := 0.42
const REACH_AT := 0.55
const DOWN_SPEED := 1.1
const SLIDE_SPEED := 3.5
const HAUL_TIME := 0.6
const GIVE := Vector2(0.4,0.7)
const HAND_SPREAD := 0.035
## Climbing, the hands sit this far (m) over the hang's grip, reaching up
## the rope; the feet press the wall this share of his leg over his feet
## (IK weight CLIMB_FEET).
const REACH_UP := 0.3
const FOOT_UP := 0.42
const CLIMB_FEET := 0.85
## On the rope he hangs this much further off the wall than a ledge hang
## (arms out to the rope, so they read), drawn in to the ledge's over the
## last BODY_IN under the top for the haul.
const BODY_OFF := 0.3
const BODY_IN := 0.6
## The rappel: E (the tug) by an anchor post on a top, rope coiled, fixes
## it there (within FIX_REACH, m, flat), tied TIE_UP up the post; Jump at
## the edge (within LOWER_REACH back from it, facing out) lowers him over.
## On the wall: leaning back LEAN (deg), hips out this share of his leg's
## length, feet planted FOOT_DOWN of it under the hips; eased in over
## STANCE_IN (s). A hop: HOP_T (s), down HOP_DROP (m), swung out HOP_OUT (m)
## at its middle; crouched in (HOP_CROUCH of it), flown, landed (from
## HOP_LAND). Pulled up from a top at PULL_UP (m/s).
const FIX_REACH := 1.6
const TIE_UP := 0.3
const LOWER_REACH := 1.6
const LEAN := 44.0
const HIP_OUT := 0.78
const FOOT_DOWN := 0.42
const STANCE_IN := 0.45
const HOP_T := 0.85
const HOP_DROP := 1.5
const HOP_OUT := 0.75
const HOP_CROUCH := 0.22
const HOP_LAND := 0.82
const PULL_UP := 3.0
## The rappel's descent, held stick back: from RAP_SPEED.x to .y (m/s) over
## RAP_RAMP (s) held; stops over RAP_STOP (s) once let go. The feet walk
## the wall a step each RAP_STRIDE of his leg, lifting RAP_LIFT of it; over
## RAP_SKIM (m/s) they skim, the steps fading out. Leaving it to climb, the
## stance eases out over UNRAP (s).
const RAP_SPEED := Vector2(1.1,3.4)
const RAP_RAMP := 1.4
const RAP_STOP := 0.22
const RAP_STRIDE := 0.9
const RAP_LIFT := 0.4
const RAP_SKIM := 2.8
const UNRAP := 0.3

var study: Node3D
## "coiled" (at his side), "aim", "fly", "drag" (pulled back to the lip),
## "caught", "tug", "seated", "slip" (pulled off by the tug), "slide" (off
## a smooth top), "fall", "down", "reel", "pull_up" (hauled up from a top).
var state := "coiled"
## Where the hook is, and where it sits once caught.
var hook_at := Vector3.ZERO
var lip := Vector3.INF
## The lip's outward way (flat, toward where the rope hangs).
var lip_out := Vector3.ZERO
## The hold it caught on ("solid", "poor", "anchor"; "" none) and its piece.
var hold := ""
var piece := ""
## Tugged and seated (a seated hook holds his weight).
var tested := false
## A bad placement on a crumbly lip: the tug pulls it off; untested, it gives
## under his weight.
var bad := false
## Drivers: -1 rolls `bad` at the catch, 0 never, 1 always (poor holds only).
var force_bad := -1
## The aim: the reticle (the target the arc ends at), its lip, hold, piece,
## whether it'll catch and why not, the arc.
var aim_at := Vector3.INF
var aim_lip := Vector3.INF
var aim_out := Vector3.ZERO
var aim_hold := ""
var aim_piece := ""
var aim_ok := false
var aim_why := ""
var aim_arc: PackedVector3Array = []
## The rope paid out (m).
var paid := 0.0
## Tallies (drivers, notes).
var throws := 0
var catches := 0
var misses := 0
var reels := 0
var tugs := 0
var seats := 0
var slips := 0
## Drivers: aim as though the button were held (`release` lets go).
var hold_aim := false
## The edge the rope runs over (a lip's own; for a post, the top's edge on
## the side it hangs) and its outward way (flat): where it hangs to climb.
var edge := Vector3.INF
var edge_out := Vector3.ZERO
## On the rope (the motor's rider), and hauling over the lip after.
var climber := false
var hauling := false
## The climb's pace (1 bare; a load would slow it: the spec's later bag).
var climb_pace := 1.0
## Tallies: holds taken, hauls over, hooks that gave.
var climbs := 0
var hauls := 0
var gave := 0
## Fixed round an anchor post from its top (pulled down from below, not
## flicked); being lowered over the edge (the motor's catch and lower);
## on the rope rappelling (feet on the wall), not climbing.
var fixed := false
var lowering := false
var rappel := false
## Tallies: rappels begun, hops down, ropes pulled down from below.
var rappels := 0
var hops := 0
var pulled_down := 0
## Where the rappel's hands hold the rope (world): the lead hand up the
## rope, the brake hand at his hip; the rope runs through both.
var guide_at := Vector3.INF
var brake_at := Vector3.INF

var _rap_v := 0.0
var _rap_held := 0.0
var _step := 0.0
var _hop_t := -1.0
var _hop_from := 0.0
var _hop_drop := 0.0
var _stance_k := 0.0
var _up_len := 0.0

var _jump_was := false
var _on_t := 0.0
## The hands' heights on the rope (world y): [top, low], and which bone side
## each is (1 right, -1 left).
var _hand_y := [0.0,0.0]
var _hand_side := [1.0,-1.0]
## A pull under way (0 to 1; -1 none), from feet at this height.
var _pull_t := -1.0
var _pull_from := 0.0
var _reach_from := 0.0
## The hands' height an untested bad hook gives at (INF never).
var _give_y := INF
var _climb_time_was := 0.0

var _aim := Vector2.ZERO
var _throw_was := false
var _reel_was := false
var _tug_was := false
var _tug_t := 0.0
var _tug_paid := 0.0
var _tug_said := false
var _grit: Array[Dictionary] = []
var _grit_mat: StandardMaterial3D
var _click: AudioStreamPlayer3D
var _vel := Vector3.ZERO
var _from := Vector3.ZERO
var _fly_t := 0.0
var _fly_all := 0.0
var _t := 0.0
var _whirl := 0.0
var _slide_from := Vector3.ZERO
var _reel_after := false
var _hook: Node3D
var _rope: MultiMeshInstance3D
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D
var _dots: MultiMeshInstance3D
var _dots_mat: StandardMaterial3D
var _line: Label3D
var _line_t := -1.0
var _clink: AudioStreamPlayer3D

func setup(host: Node3D) -> void:
	study = host
	name = "ClimbRope"
	process_priority = 100
	_hook = _hook_figure()
	add_child(_hook)
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = ROPE
	rope_mat.roughness = 0.95
	var seg := CylinderMesh.new()
	seg.top_radius = ROPE_R
	seg.bottom_radius = ROPE_R
	seg.height = 1.0
	seg.radial_segments = 6
	seg.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = seg
	mm.instance_count = SEGS
	_rope = MultiMeshInstance3D.new()
	_rope.name = "Rope"
	_rope.top_level = true
	_rope.multimesh = mm
	_rope.material_override = rope_mat
	add_child(_rope)
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticle_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_reticle = MeshInstance3D.new()
	_reticle.name = "HookReticle"
	_reticle.top_level = true
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	_reticle.mesh = ring
	_reticle.material_override = _reticle_mat
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.visible = false
	add_child(_reticle)
	_dots_mat = _reticle_mat.duplicate()
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	dot.radial_segments = 8
	dot.rings = 4
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	dm.mesh = dot
	dm.instance_count = ARC_DOTS+1
	_dots = MultiMeshInstance3D.new()
	_dots.name = "HookArc"
	_dots.top_level = true
	_dots.multimesh = dm
	_dots.material_override = _dots_mat
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dots.visible = false
	add_child(_dots)
	_line = Label3D.new()
	_line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line.font_size = 30
	_line.pixel_size = 0.006
	_line.outline_size = 8
	_line.no_depth_test = true
	_line.top_level = true
	_line.visible = false
	add_child(_line)
	_clink = AudioStreamPlayer3D.new()
	_clink.stream = _clink_sound()
	_clink.top_level = true
	add_child(_clink)
	_click = AudioStreamPlayer3D.new()
	_click.stream = _click_sound()
	_click.top_level = true
	add_child(_click)
	_grit_mat = StandardMaterial3D.new()
	_grit_mat.albedo_color = GRIT_COLOUR
	_grit_mat.roughness = 1.0
	reset()

## Coiled at his side, nothing out.
func reset() -> void:
	state = "coiled"
	hold = ""
	piece = ""
	lip = Vector3.INF
	tested = false
	bad = false
	paid = 0.0
	hold_aim = false
	edge = Vector3.INF
	edge_out = Vector3.ZERO
	fixed = false
	lowering = false
	_off_rope()
	_reel_after = false
	_show_aim(false)
	_rope.visible = false
	_hook.visible = false

## The rope's out (anything but coiled or aiming).
func out() -> bool:
	return state != "coiled" and state != "aim"

# --- Input ------------------------------------------------------------------------------

## Polled each frame (the drivers' Input.action_press reaches it too).
func _read_input() -> void:
	var throw_down := Input.is_action_pressed(&"walk_throw")
	var reel_down := Input.is_action_pressed(&"walk_reel")
	var tug_down := Input.is_action_pressed(&"walk_tug")
	var throw_hit := throw_down and not _throw_was
	var reel_hit := reel_down and not _reel_was
	var tug_hit := tug_down and not _tug_was
	_throw_was = throw_down
	_reel_was = reel_down
	_tug_was = tug_down
	if _busy(): return
	if throw_hit:
		if state == "coiled":
			if _on_foot(): aim()
		elif out(): _say("Reel it in first (%s)" % Pad.pick("F","D-pad down"))
	if reel_hit: reel()
	if tug_hit: tug()

func _busy() -> bool:
	if study == null or not bool(study.get("walk_ready")): return true
	var editor := study.get_node_or_null("LayoutEdit")
	if editor != null and bool(editor.get("editing")): return true
	return study.has_method("_tuning") and bool(study.call("_tuning"))

func _on_foot() -> bool:
	var motor: Variant = study.get("motor")
	return motor != null and motor.grounded

# --- The throw --------------------------------------------------------------------------

## Held: the hook whirls at his side, the reticle out ahead.
func aim() -> void:
	if state != "coiled": return
	var f := _forward()*AIM_REACH*_size()*AIM_START
	_aim = _to_cam(Vector2(f.x,f.z))
	state = "aim"
	_whirl = 0.0
	_hook.visible = true
	_rope.visible = true
	_aim_update(0.0,Vector2.ZERO)

## Drivers: the reticle put on a world point (then snapped as the stick's).
func aim_toward(point: Vector3) -> void:
	if state != "aim": return
	var feet: Vector3 = study.get("motor").feet
	_aim = _to_cam(Vector2(point.x-feet.x,point.z-feet.z))
	_aim_update(0.0,Vector2.ZERO)

## Aiming, the stick (`want`, the motor's frame) moves the reticle. The
## study calls it from _want.
func aim_steer(want: Vector2, delta: float) -> void:
	if state != "aim": return
	_aim_update(delta,want)

## Let go: the hook flies the arc shown.
func release() -> void:
	if state != "aim": return
	hold_aim = false
	_show_aim(false)
	_from = _hand()+Vector3.UP*0.25*_size()
	hook_at = _from
	_vel = _arc_to(_from,aim_at)
	_fly_all = _flight_time(_from,aim_at,_vel)
	_fly_t = 0.0
	lip = aim_lip
	lip_out = aim_out
	hold = aim_hold
	piece = aim_piece
	throws += 1
	state = "fly"
	paid = 0.0

func _aim_update(delta: float, want: Vector2) -> void:
	var motor: Variant = study.get("motor")
	var s := _size()
	var w := _from_cam(_aim)+want*AIM_SPEED*s*delta
	var l := w.length()
	if l < AIM_MIN*s: w = (w/l if l > 0.01 else Vector2(_forward().x,_forward().z))*AIM_MIN*s
	w = w.limit_length(AIM_REACH*s)
	_aim = _to_cam(w)
	var feet: Vector3 = motor.feet
	var over := Vector3(feet.x+w.x,feet.y,feet.z+w.y)
	var t := target(over)
	aim_at = t.at
	aim_lip = t.lip
	aim_out = t.out
	aim_hold = t.hold
	aim_piece = t.piece
	aim_why = t.why
	aim_ok = t.why == ""
	# He faces it.
	var d := Vector2(aim_at.x-feet.x,aim_at.z-feet.z)
	if d.length() > 0.2: motor.facing = PilotMotor.facing_of(d.normalized())
	# The arc there, and what it meets on the way.
	var from := _hand()+Vector3.UP*0.25*s
	aim_arc = PackedVector3Array()
	var v := _arc_to(from,aim_at)
	var g := _gravity()
	var t_all := _flight_time(from,aim_at,v)
	var space := get_world_3d().direct_space_state
	var was := from
	aim_arc.append(from)
	if from.distance_to(aim_at) > ROPE_LEN*s and aim_ok:
		aim_ok = false
		aim_why = "out of reach"
	for i in range(1,ARC_DOTS+1):
		var tt := t_all*float(i)/ARC_DOTS
		var at := from+v*tt+Vector3.DOWN*0.5*g*tt*tt
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(was,at,CarryHost.SOLID_MASK))
		if not hit.is_empty() and (hit.position as Vector3).distance_to(aim_at) > LAND_IN*s+0.3:
			aim_arc.append(hit.position)
			if aim_ok:
				aim_ok = false
				aim_why = "the way's blocked"
			break
		aim_arc.append(at)
		was = at
	_show_aim(true)

## Where a throw at `over` (a point under the reticle) goes: {at (where it
## comes down), lip (where it'd hook, else INF), out, hold, piece, why (""
## when it catches)}.
func target(over: Vector3) -> Dictionary:
	var motor: Variant = study.get("motor")
	var s := _size()
	var feet: Vector3 = motor.feet
	var holds: Dictionary = study.get("holds")
	var pieces: Dictionary = study.get("pieces")
	# An anchor post near the reticle, over his head.
	var best := ""
	var best_d := POST_SNAP*s
	for id: String in holds:
		if holds[id] != "anchor" or not pieces.has(id): continue
		var top := _post_top(pieces[id])
		if top.y-feet.y < ABOVE*s: continue
		var dd := Vector2(top.x-over.x,top.z-over.z).length()
		if dd < best_d:
			best_d = dd
			best = id
	if best != "":
		var top := _post_top(pieces[best])
		var wrap := top+Vector3.DOWN*POST_WRAP*s
		var o := Vector3(feet.x-top.x,0.0,feet.z-top.z)
		o = o.normalized() if o.length() > 0.01 else -_forward()
		return {"at":wrap+Vector3.UP*0.05,"lip":wrap,"out":o,"hold":"anchor","piece":best,"why":""}
	var space := get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(over+Vector3.UP*16.0*s,over+Vector3.DOWN*30.0*s,CarryHost.SOLID_MASK))
	if down.is_empty():
		return {"at":over+Vector3.DOWN*2.0*s,"lip":Vector3.INF,"out":Vector3.ZERO,"hold":"","piece":"","why":"nothing there"}
	var hit_at: Vector3 = down.position
	var body: Object = down.collider
	var id := _piece_of(body)
	if hit_at.y-feet.y < ABOVE*s:
		return {"at":hit_at+Vector3.UP*0.04,"lip":Vector3.INF,"out":Vector3.ZERO,"hold":"","piece":id,"why":"nothing to catch on"}
	# The lip: the top's edge on his side, along the line to the reticle.
	var y := hit_at.y-0.08*s
	var a := Vector3(feet.x,y,feet.z)
	var b := Vector3(over.x,y,over.z)
	var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b+(b-a).normalized()*0.5*s,CarryHost.SOLID_MASK))
	var edge := hit_at
	var o := -_forward()
	if not side.is_empty() and side.collider == body:
		var n: Vector3 = side.normal
		n.y = 0.0
		if n.length() > 0.5:
			o = n.normalized()
			edge = Vector3((side.position as Vector3).x,hit_at.y,(side.position as Vector3).z)
	var at := edge-o*LAND_IN*s+Vector3.UP*0.05
	var h: String = str(holds.get(id,""))
	if h == "" or h == "anchor":
		return {"at":at,"lip":edge,"out":o,"hold":"","piece":id,"why":"a smooth top: nothing to catch on"}
	return {"at":at,"lip":edge,"out":o,"hold":h,"piece":id,"why":""}

## The study's piece id a collider belongs to ("" none).
func _piece_of(body: Object) -> String:
	if body == null or not body is Node: return ""
	var pieces: Dictionary = study.get("pieces")
	var id := str((body as Node).name)
	return id if pieces.has(id) and pieces[id] == body else ""

## A post's top (its collider's height about its middle).
func _post_top(post: Node3D) -> Vector3:
	var h := 1.0
	for c in post.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CylinderShape3D:
			h = ((c as CollisionShape3D).shape as CylinderShape3D).height
	return post.global_transform*Vector3(0.0,h*0.5,0.0)

# --- The tug ---------------------------------------------------------------------------

## A caught (or seated) hook: he reaches up the rope and yanks it.
func tug() -> void:
	if climber and rappel:
		# Rappelling, E pushes off the wall in a hop.
		if _hop_t < 0.0 and _stance_k >= 1.0 and not study.get("motor").crouch:
			_hop_t = 0.0
			_hop_from = study.get("motor").feet.y
			_hop_drop = minf(HOP_DROP*_size(),_hop_from-_floor_under(study.get("motor").feet))
			_rap_v = 0.0
			hops += 1
		return
	if state == "coiled":
		_fix()
		return
	if state != "caught" and state != "seated": return
	if climber or hauling or on_top(): return
	if not _on_foot():
		_say("Feet on the ground to tug")
		return
	tugs += 1
	state = "tug"
	_tug_t = 0.0
	_tug_paid = paid
	_tug_said = false

func _tug_step(delta: float) -> void:
	_tug_t += delta
	var motor: Variant = study.get("motor")
	var feet: Vector3 = motor.feet
	var d := Vector2(lip.x-feet.x,lip.z-feet.z)
	if d.length() > 0.2: motor.facing = PilotMotor.facing_of(d.normalized())
	var span := _hand().distance_to(hook_at)
	# The slack taken in as he reaches and yanks.
	var k := clampf(_tug_t/(TUG_REACH+TUG_YANK),0.0,1.0)
	paid = lerpf(maxf(_tug_paid,span),span,k*k)
	if _tug_t < TUG_REACH+TUG_YANK: return
	if not _tug_said:
		_tug_said = true
		tested = true
		if bad:
			slips += 1
			state = "slip"
			_slide_from = hook_at
			_fly_t = 0.0
			_spill_grit()
			_clank()
			_say("It slipped: the lip crumbled")
			return
		seats += 1
		_click_play()
		if fixed: _say("Fixed round the post. At the edge, facing out, %s goes over" % Pad.pick("Space","A"))
		else: _say("Seated: %s" % ("round the post" if hold == "anchor" else "safe to climb"))
	if _tug_t >= TUG_REACH+TUG_YANK+TUG_HOLD: state = "seated"

## Pulled back over the crumbling lip, then off it.
func _slip_step(delta: float) -> void:
	_fly_t += delta
	var s := _size()
	var k := clampf(_fly_t/SLIP_TIME,0.0,1.0)
	hook_at = _slide_from+lip_out*0.25*s*k*k+Vector3.DOWN*0.06*s*k
	paid = _hand().distance_to(hook_at)
	if k < 1.0: return
	_vel = lip_out*1.4*s+Vector3.UP*0.4*s
	state = "fall"

## Grit off the lip where the hook tore out.
func _spill_grit() -> void:
	var s := _size()
	for i in GRIT:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		var e := randf_range(0.05,0.11)*s
		b.size = Vector3(e,e*0.8,e)
		m.mesh = b
		m.material_override = _grit_mat
		m.top_level = true
		add_child(m)
		var side := lip_out.cross(Vector3.UP).normalized()
		m.global_position = lip+side*randf_range(-0.25,0.25)*s+Vector3.DOWN*0.05*s
		m.rotation = Vector3(randf()*TAU,randf()*TAU,0.0)
		var v := lip_out*randf_range(0.5,1.6)*s+side*randf_range(-0.6,0.6)*s+Vector3.UP*randf_range(0.0,1.2)*s
		_grit.append({"node":m,"vel":v,"t":0.0,"spin":Vector3(randf_range(-8,8),randf_range(-8,8),0.0)})

func _grit_step(delta: float) -> void:
	var g := _gravity()
	for i in range(_grit.size()-1,-1,-1):
		var b: Dictionary = _grit[i]
		var m: MeshInstance3D = b.node
		b.t = float(b.t)+delta
		if float(b.t) > GRIT_LIFE:
			m.queue_free()
			_grit.remove_at(i)
			continue
		b.vel = (b.vel as Vector3)+Vector3.DOWN*g*delta
		var floor_y := float(study.get("lost"))
		m.global_position += (b.vel as Vector3)*delta
		m.rotation += (b.spin as Vector3)*delta
		if m.global_position.y < floor_y: b.t = GRIT_LIFE

# --- Reeling in -------------------------------------------------------------------------

## Draws the rope in: a caught hook flicked off its lip first.
func reel() -> void:
	if climber or hauling or lowering: return
	if (state == "caught" or state == "seated") and on_top():
		# From the top: pulled up hand over hand, the hanging end rising.
		reels += 1
		state = "pull_up"
		_up_len = maxf(edge.y-_floor_under(line_at(edge.y-0.3*_size())),0.0)
		_say("Pulling it up")
		return
	if state == "seated" and fixed:
		# From below: the free end pulled, it runs round the post and drops.
		reels += 1
		pulled_down += 1
		lip = edge
		lip_out = edge_out
		edge = Vector3.INF
		fixed = false
		_slide_from = hook_at
		_fly_t = 0.0
		state = "slide"
		_reel_after = true
		_say("Pulled it down")
		return
	match state:
		"caught", "drag", "tug", "seated":
			reels += 1
			_flick()
			_reel_after = true
			_say("Flicked free")
		"fall", "slide", "fly", "slip":
			reels += 1
			_reel_after = true
		"down":
			reels += 1
			state = "reel"

func _flick() -> void:
	var s := _size()
	_vel = lip_out*FLICK.x*s+Vector3.UP*FLICK.y*s
	hook_at = (lip if lip != Vector3.INF else hook_at)+lip_out*0.15*s+Vector3.UP*0.1*s
	state = "fall"

# --- The climb -------------------------------------------------------------------------

## The edge the caught rope runs over (`edge`, `edge_out`): a lip's own; a
## post's, walked out from it toward where the rope hangs till the top
## ends, then found exactly by a ray back at its face.
func _find_edge() -> void:
	edge = lip
	edge_out = lip_out
	if hold != "anchor": return
	var s := _size()
	var space := get_world_3d().direct_space_state
	var top_y := INF
	var last := Vector3.INF
	for i in 120:
		var p := lip+lip_out*(0.22+0.05*i)*s
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.6*s,p+Vector3.DOWN*3.0*s,CarryHost.SOLID_MASK))
		if hit.is_empty(): break
		var y := (hit.position as Vector3).y
		if top_y == INF: top_y = y
		if absf(y-top_y) > 0.25*s: break
		last = Vector3(p.x,y,p.z)
	if last == Vector3.INF: return
	var a := last+lip_out*0.4*s+Vector3.DOWN*0.08*s
	var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,a-lip_out*0.8*s,CarryHost.SOLID_MASK))
	edge = last
	if not side.is_empty():
		var n: Vector3 = side.normal
		n.y = 0.0
		if n.length() > 0.5:
			edge_out = n.normalized()
			edge = Vector3((side.position as Vector3).x,last.y,(side.position as Vector3).z)

## He's up on the top the rope's hooked over (or level with it).
func on_top() -> bool:
	if edge == Vector3.INF: return false
	var motor: Variant = study.get("motor")
	return (motor.feet as Vector3).y > edge.y-0.4*_size()

## Where the hanging rope is at height `y` (world).
func line_at(y: float) -> Vector3:
	var s := _size()
	return Vector3(edge.x+edge_out.x*ROPE_OFF*s,y,edge.z+edge_out.z*ROPE_OFF*s)

## Called by the study before the motor's step: Jump by the hanging rope of
## a caught or seated hook takes hold of it (instead of the jump).
func pre_step(jump_down: bool) -> void:
	var hit := jump_down and not _jump_was
	_jump_was = jump_down
	if not hit or climber or hauling or lowering or _busy(): return
	if state != "caught" and state != "seated": return
	if edge == Vector3.INF or not _on_foot(): return
	var motor: Variant = study.get("motor")
	var s := _size()
	var feet: Vector3 = motor.feet
	if on_top():
		# At the edge the rope goes over, facing out: lowered over it.
		var rel := Vector3(feet.x-edge.x,0.0,feet.z-edge.z)
		var back := -rel.dot(edge_out)
		var along := absf(rel.dot(edge_out.cross(Vector3.UP).normalized()))
		var f := PilotMotor.forward(motor.facing)
		if back < -0.1*s or back > LOWER_REACH*s or along > 1.0*s: return
		if f.dot(Vector2(edge_out.x,edge_out.z)) < 0.3: return
		_lower(motor)
		return
	var at := line_at(feet.y)
	if Vector2(at.x-feet.x,at.z-feet.z).length() > GRAB_REACH*s: return
	_mount(motor)

func _mount(motor: Variant) -> void:
	var s := _size()
	var feet: Vector3 = motor.feet
	var y := minf(feet.y+0.12*s,edge.y-float(motor.hang_drop))
	motor.mount(self,_body_at(motor,y),false,PilotMotor.facing_of(Vector2(-edge_out.x,-edge_out.z)),true)
	motor.hold = "swing"
	motor.move = ""
	climber = true
	climbs += 1
	_on_t = 0.0
	_stance_k = 0.0
	_rap_v = 0.0
	_rap_held = 0.0
	_pull_t = -1.0
	var top := y+float(motor.hang_drop)
	_hand_y = [top,top-PULL*s]
	_hand_side = [1.0,-1.0]
	# An untested bad hook gives this far up the climb (the hands' height).
	_give_y = INF
	if bad and not tested: _give_y = top+randf_range(GIVE.x,GIVE.y)*maxf(edge.y-top,0.5*s)
	if rappel:
		_hop_t = -1.0
		_say("Rappelling: %s lowers · %s climbs · %s pushes off · %s slides · %s lets go" % [Pad.pick("S","stick back"),Pad.pick("W","stick up"),Pad.pick("E","B"),Pad.pick("Shift","crouch"),Pad.pick("Space","A")])
		return
	_say("On the rope: %s climbs · %s lets go · %s slides" % [Pad.pick("W","stick up"),Pad.pick("Space","A"),Pad.pick("Shift","crouch")])

## Over the edge from the top: the motor's own catch (turned to face the
## edge) and lower (the climb played back) to a hang, then on the rope,
## rappelling (`_process` takes the hang).
func _lower(motor: Variant) -> void:
	motor.lip = edge
	motor.lip_out = Vector2(edge_out.x,edge_out.z)
	motor.hold = "catch"
	motor._hold_time = 0.0
	motor.facing = PilotMotor.facing_of(-Vector2(edge_out.x,edge_out.z))
	motor._still()
	lowering = true
	rappels += 1

## E by an anchor post on a top, the rope coiled: tied round its foot and
## the rest thrown over the nearest drop beyond it (the way he looks past
## it), tugged to seat it.
func _fix() -> void:
	if not _on_foot(): return
	var motor: Variant = study.get("motor")
	var s := _size()
	var feet: Vector3 = motor.feet
	var holds: Dictionary = study.get("holds")
	var pieces: Dictionary = study.get("pieces")
	var best := ""
	var best_d := FIX_REACH*s
	for id: String in holds:
		if holds[id] != "anchor" or not pieces.has(id): continue
		var post: Node3D = pieces[id]
		var top := _post_top(post)
		var foot := post.global_position*2.0-top
		if absf(foot.y-feet.y) > 0.4*s: continue
		var d := Vector2(top.x-feet.x,top.z-feet.z).length()
		if d < best_d:
			best_d = d
			best = id
	if best == "":
		return
	var post: Node3D = pieces[best]
	var foot := post.global_position*2.0-_post_top(post)
	var o := Vector3(foot.x-feet.x,0.0,foot.z-feet.z)
	o = o.normalized() if o.length() > 0.05 else _forward()
	hold = "anchor"
	piece = best
	lip = foot+Vector3.UP*TIE_UP*s
	lip_out = o
	hook_at = lip
	bad = false
	tested = false
	_find_edge()
	if edge.distance_to(lip) < 0.3*s:
		edge = Vector3.INF
		edge_out = Vector3.ZERO
		_say("No drop that way")
		return
	fixed = true
	tugs += 1
	state = "tug"
	_tug_t = 0.0
	paid = _hand().distance_to(hook_at)+0.3*s
	_tug_paid = paid
	_tug_said = false

## His feet hanging on the rope with them at height `y`: off the wall as
## the motor's ledge hang holds him.
func _body_at(motor: Variant, y: float) -> Vector3:
	var s := _size()
	var near := clampf((edge.y-float(motor.hang_drop)-y)/(BODY_IN*s),0.0,1.0)
	var o := float(motor.hang_out)+BODY_OFF*s*near
	return Vector3(edge.x+edge_out.x*o,y,edge.z+edge_out.z*o)

## One step on the rope (the motor's rider, scripts/pilot_motor.gd `ride`).
func ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var out := {}
	_on_t += delta
	var s := _size()
	if pressed and _on_t > 0.2:
		walker.toss(edge_out*0.3*s+Vector3.UP*0.6*s)
		_off_rope()
		out["let_go"] = true
		return out
	var toward := Vector2(-edge_out.x,-edge_out.z).normalized()
	# The stick's own up/down (forward climbs, back lowers), whatever way
	# the camera looks.
	var push := _to_cam(want).y
	var y := walker.feet.y
	var drop := float(walker.hang_drop)
	var top_y := edge.y-drop
	if rappel:
		if push > 0.35 and _hop_t < 0.0 and not walker.crouch:
			# Stick up: hands up the rope, climbing as from below (the
			# stance eases out, no snap).
			rappel = false
			_rap_v = 0.0
			_hand_y = [y+drop,y+drop-PULL*s]
			_hand_side = [1.0,-1.0]
		else:
			return _rappel_step(walker,delta,push,out)
	if walker.crouch:
		# Sliding down, both hands loose on the rope over his head.
		_pull_t = -1.0
		y -= SLIDE_SPEED*s*delta
		_hand_y = [y+drop,y+drop-0.12*s]
	elif _pull_t >= 0.0 or push > 0.35:
		if _pull_t < 0.0:
			if y >= top_y-0.01*s:
				_haul(walker,out)
				return out
			_pull_t = 0.0
			_pull_from = y
			_reach_from = float(_hand_y[1])
		_pull_t = minf(_pull_t+delta/(PULL_T*climb_pace),1.0)
		var rise := minf(PULL*s,top_y-_pull_from)
		# Hauled up on the top hand (eased in and out), then the low hand
		# reaches past it, arcing off the rope.
		var k := clampf(_pull_t/REACH_AT,0.0,1.0)
		y = _pull_from+rise*k*k*(3.0-2.0*k)
		if _pull_t > REACH_AT:
			var r := (_pull_t-REACH_AT)/(1.0-REACH_AT)
			r = 1.0-(1.0-r)*(1.0-r)
			_hand_y[1] = lerpf(_reach_from,_pull_from+rise+drop,r)
		if _pull_t >= 1.0:
			# The reached hand is the top one now.
			_hand_y = [_hand_y[1],_hand_y[0]]
			_hand_side = [_hand_side[1],_hand_side[0]]
			_pull_t = -1.0
			out["pulled"] = true
		if float(_hand_y[0]) >= _give_y or float(_hand_y[1]) >= _give_y:
			_give(walker,out)
			return out
	elif push < -0.35:
		# Down hand under hand: the hands slide along, swapping as they go.
		y -= DOWN_SPEED*s*climb_pace*delta
		var bob := sin((y/(PULL*s))*PI)*0.5*PULL*s
		_hand_y = [y+drop-maxf(bob,0.0),y+drop-PULL*s+minf(bob,0.0)]
	# Down to the ground under him: off the rope, on his feet.
	var ground := _floor_under(walker.feet)
	if y <= ground+0.01*s:
		walker.feet.y = ground
		walker.toss(Vector3.ZERO)
		_off_rope()
		out["off_rope"] = true
		return out
	_stance_k = maxf(_stance_k-delta/UNRAP,0.0)
	walker.feet = _stance_at(walker,y)
	walker.velocity = Vector3.ZERO
	walker.facing = PilotMotor.facing_of(toward)
	walker.ground_y = ground
	return out

## The floor under the rope at `at` (world y; far under, the room's lost).
func _floor_under(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.3*_size(),at+Vector3.DOWN*40.0,CarryHost.SOLID_MASK))
	return float(study.get("lost")) if hit.is_empty() else (hit.position as Vector3).y

## At the top: handed to the motor's own ledge hang, and its climb over the
## lip (slowed to HAUL_TIME).
func _haul(walker: PilotMotor, out: Dictionary) -> void:
	walker.release(self)
	_off_rope()
	walker.lip = Vector3(edge.x,edge.y,edge.z)
	walker.lip_out = Vector2(edge_out.x,edge_out.z)
	walker.hold = "hang"
	walker.hold_t = 0.0
	walker.feet = walker._hang_at()
	walker.velocity = Vector3.ZERO
	var ground: Variant = study.get("ground")
	_climb_time_was = walker.climb_time
	walker.climb_time = HAUL_TIME*climb_pace
	if walker._climb(ground.ground_callable(),ground.slide_callable()):
		hauling = true
		hauls += 1
		out["hauled"] = true
	else:
		walker.climb_time = _climb_time_was
		_say("No room to stand up there")

## An untested bad hook tears out under him: grit, the hook falls, so does he.
func _give(walker: PilotMotor, out: Dictionary) -> void:
	var s := _size()
	walker.toss(edge_out*0.2*s+Vector3.DOWN*0.5*s)
	_off_rope()
	tested = true
	gave += 1
	slips += 1
	state = "slip"
	_slide_from = hook_at
	_fly_t = 0.0
	_spill_grit()
	_clank()
	_say("It gave way: the lip crumbled")
	out["gave"] = true

## One step rappelling: feet on the wall; stick back lowers him smoothly,
## faster the longer it's held, the feet walking (then skimming) the wall;
## let go, he stops and hangs. E's hop (`tug`) runs to its end; crouch
## slides; at the floor, off.
func _rappel_step(walker: PilotMotor, delta: float, push: float, out: Dictionary) -> Dictionary:
	var s := _size()
	var y := walker.feet.y
	_stance_k = minf(_stance_k+delta/STANCE_IN,1.0)
	var ground := _floor_under(_stance_at(walker,y))
	if walker.crouch:
		_hop_t = -1.0
		_rap_v = 0.0
		y -= SLIDE_SPEED*s*delta
	elif _hop_t >= 0.0:
		_hop_t = minf(_hop_t+delta/(HOP_T*climb_pace),1.0)
		var u := clampf((_hop_t-HOP_CROUCH)/(HOP_LAND-HOP_CROUCH),0.0,1.0)
		y = _hop_from-_hop_drop*u*u*(3.0-2.0*u)
		if _hop_t >= 1.0:
			_hop_t = -1.0
			out["hopped"] = true
	else:
		if push < -0.35 and _stance_k > 0.6:
			_rap_held += delta
			var k := clampf(_rap_held/RAP_RAMP,0.0,1.0)
			var v := lerpf(RAP_SPEED.x,RAP_SPEED.y,k*k)*s/climb_pace
			# Quick to start, quicker as held.
			_rap_v = move_toward(_rap_v,v,8.0*s*delta)
		else:
			_rap_held = 0.0
			_rap_v = move_toward(_rap_v,0.0,RAP_SPEED.y*s/RAP_STOP*delta)
		y -= _rap_v*delta
		_step += _rap_v*delta/(RAP_STRIDE*_leg())
	if y <= ground+0.01*s:
		walker.feet = Vector3(walker.feet.x,ground,walker.feet.z)
		walker.toss(Vector3.ZERO)
		_off_rope()
		out["off_rope"] = true
		_say("Down. The rope stays: %s by it climbs, %s pulls it down" % [Pad.pick("Space","A"),Pad.pick("F","D-pad down")])
		return out
	walker.feet = _stance_at(walker,y)
	walker.velocity = Vector3.ZERO
	walker.facing = PilotMotor.facing_of(Vector2(-edge_out.x,-edge_out.z))
	walker.ground_y = ground
	return out

## Walking down the wall: how far each foot is lifted off it (0..1) and
## the share of a step (fading to a skim at speed).
func _walk_k() -> float:
	return clampf(1.0-(_rap_v/_size()-RAP_SKIM*0.6)/(RAP_SKIM*0.4),0.0,1.0)*clampf(_rap_v/(0.4*_size()),0.0,1.0)

## Where his feet (the motor's) stand rappelling at height `y`: out from the
## wall, the hips HIP_OUT of his leg off it, swung out mid-hop and drawn in
## crouching and landing; eased from the hang's spot as he settles.
func _stance_at(walker: Variant, y: float) -> Vector3:
	var s := _size()
	var out_d := HIP_OUT*_leg()+_hop_swing()
	var at := Vector3(edge.x+edge_out.x*out_d,y,edge.z+edge_out.z*out_d)
	return _body_at(walker,y).lerp(at,_stance_k*_stance_k*(3.0-2.0*_stance_k))

## The hop's swing off the wall (m): in a little crouching, out in an arc
## flying, in again landing.
func _hop_swing() -> float:
	if _hop_t < 0.0: return 0.0
	var s := _size()
	if _hop_t < HOP_CROUCH:
		var c := _hop_t/HOP_CROUCH
		return -0.2*s*c*c
	if _hop_t < HOP_LAND:
		var u := (_hop_t-HOP_CROUCH)/(HOP_LAND-HOP_CROUCH)
		return lerpf(-0.2*s,0.0,u)+sin(PI*u)*HOP_OUT*s
	var w := (_hop_t-HOP_LAND)/(1.0-HOP_LAND)
	return -0.16*s*sin(PI*w)

## His leg's length (m, thigh to ankle; 0.8 m scaled without a skeleton).
func _leg() -> float:
	var sk := _skeleton()
	if sk != null:
		var a := sk.find_bone("thigh.L")
		var b := sk.find_bone("shin.L")
		var c := sk.find_bone("foot.L")
		if a >= 0 and b >= 0 and c >= 0:
			var g := sk.global_basis
			var pa := sk.get_bone_global_rest(a).origin
			var pb := sk.get_bone_global_rest(b).origin
			var pc := sk.get_bone_global_rest(c).origin
			return (g*(pb-pa)).length()+(g*(pc-pb)).length()
	return 0.8*_size()

func _off_rope() -> void:
	climber = false
	rappel = false
	_rap_v = 0.0
	_rap_held = 0.0
	_hop_t = -1.0
	guide_at = Vector3.INF
	brake_at = Vector3.INF
	_pull_t = -1.0
	_give_y = INF

# --- Each frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if study == null or study.get("motor") == null: return
	_read_input()
	_t += delta
	if climber and study.get("motor").rider != self: _off_rope()
	if lowering:
		var motor: Variant = study.get("motor")
		if motor.hold == "hang":
			# Hanging under the edge: onto the rope, feet to the wall.
			lowering = false
			motor.hold = ""
			rappel = true
			_mount(motor)
		elif motor.hold != "catch" and motor.hold != "lower":
			lowering = false
	if hauling and study.get("motor").hold != "climb":
		hauling = false
		study.get("motor").climb_time = _climb_time_was
		if study.get("motor").grounded: _say("Up and over")
	match state:
		"aim": _aim_step(delta)
		"fly": _fly_step(delta)
		"drag": _drag_step(delta)
		"slide": _slide_step(delta)
		"fall": _fall_step(delta)
		"reel": _reel_step(delta)
		"tug": _tug_step(delta)
		"slip": _slip_step(delta)
		"pull_up": _pull_up_step(delta)
	if not _grit.is_empty(): _grit_step(delta)
	_arm_pose()
	_draw_rope()
	_place_hook()
	if _line_t >= 0.0:
		_line_t += delta
		_line.global_position = (study.get("motor").feet as Vector3)+Vector3.UP*2.4*_size()
		if _line_t > LINE_TIME:
			_line_t = -1.0
			_line.visible = false

## Pulled up from the top: the hanging end rises to the edge, then coiled.
func _pull_up_step(delta: float) -> void:
	var motor: Variant = study.get("motor")
	var feet: Vector3 = motor.feet
	var d := Vector2(edge.x-feet.x,edge.z-feet.z)
	if d.length() > 0.2: motor.facing = PilotMotor.facing_of(d.normalized())
	_up_len -= PULL_UP*_size()*delta
	if _up_len > 0.0: return
	_coil()
	_say("Pulled it up")

func _aim_step(delta: float) -> void:
	if not _on_foot():
		state = "coiled"
		reset()
		return
	_whirl += delta*TAU*WHIRL_RATE
	var s := _size()
	var f := _forward()
	var r := f.cross(Vector3.UP).normalized()
	var c := _hand()+Vector3.UP*0.2*s+r*0.1*s
	hook_at = c+(f*cos(_whirl)+Vector3.UP*sin(_whirl)*0.6+r*0.2)*WHIRL_R*s
	_show_aim(true)
	if not Input.is_action_pressed(&"walk_throw") and not hold_aim: release()

func _fly_step(delta: float) -> void:
	var g := _gravity()
	_fly_t += delta
	var t := minf(_fly_t,_fly_all)
	var next := _from+_vel*t+Vector3.DOWN*0.5*g*t*t
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hook_at,next,CarryHost.SOLID_MASK))
	paid = maxf(paid,_hand().distance_to(next)*1.03)
	if not hit.is_empty() and (hit.position as Vector3).distance_to(aim_at) > 0.35*_size():
		# Knocked down on the way.
		var n: Vector3 = hit.normal
		var v := _vel+Vector3.DOWN*g*t
		hook_at = (hit.position as Vector3)+n*0.05
		_vel = v.bounce(n)*BOUNCE
		misses += 1
		_clank()
		_say("Knocked down")
		state = "fall"
		return
	hook_at = next
	if _fly_t < _fly_all: return
	_clank()
	_slide_from = hook_at
	_fly_t = 0.0
	if hold != "":
		state = "drag"
	else:
		_vel = Vector3.ZERO
		misses += 1
		if lip != Vector3.INF:
			state = "slide"
			_say("No catch: %s" % aim_why if aim_why != "" else "No catch")
		else:
			# Down on open ground.
			state = "down"
			if _reel_after:
				_reel_after = false
				state = "reel"
			else: _say("Nothing to catch on. %s reels it in" % Pad.pick("F","D-pad down"))

## Pulled taut, back to the lip, where it hooks over.
func _drag_step(delta: float) -> void:
	_fly_t += delta
	var k := clampf(_fly_t/DRAG_TIME,0.0,1.0)
	hook_at = _slide_from.lerp(lip,k*k)
	if k < 1.0: return
	state = "caught"
	catches += 1
	tested = false
	bad = hold == "poor" and (force_bad == 1 or (force_bad < 0 and randf() < POOR_BAD))
	paid = _hand().distance_to(lip)+0.3*_size()
	_find_edge()
	_clank()
	_say("Caught (%s). %s tugs it" % [{"solid":"a solid lip","poor":"a crumbly lip","anchor":"a post"}.get(hold,hold),Pad.pick("E","B")])

## Off a smooth top: dragged to the lip and over it.
func _slide_step(delta: float) -> void:
	_fly_t += delta
	var k := clampf(_fly_t/DRAG_TIME,0.0,1.0)
	hook_at = _slide_from.lerp(lip,k*k)
	if k < 1.0: return
	_vel = lip_out*0.6*_size()
	hook_at = lip+lip_out*0.1*_size()
	state = "fall"

func _fall_step(delta: float) -> void:
	_vel += Vector3.DOWN*_gravity()*delta
	var next := hook_at+_vel*delta
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hook_at+Vector3.UP*0.03,next,CarryHost.SOLID_MASK))
	paid = maxf(paid,_hand().distance_to(next))
	if hit.is_empty():
		hook_at = next
		if hook_at.y < float(study.get("lost")): _coil()
		return
	var n: Vector3 = hit.normal
	hook_at = (hit.position as Vector3)+n*0.04
	if n.y > 0.6:
		state = "down"
		_vel = Vector3.ZERO
		_clank()
		if _reel_after:
			_reel_after = false
			state = "reel"
		else:
			_say("Down. %s reels it in" % Pad.pick("F","D-pad down"))
		return
	_vel = _vel.bounce(n)*BOUNCE

## Dragged in along the ground toward his feet, over what's in the way.
func _reel_step(delta: float) -> void:
	var feet: Vector3 = study.get("motor").feet
	var s := _size()
	var to := Vector2(feet.x-hook_at.x,feet.z-hook_at.z)
	if to.length() < COILED*s and absf(feet.y-hook_at.y) < 1.5*s:
		_coil()
		_say("Reeled in")
		return
	var step := to.limit_length(REEL_SPEED*s*delta)
	var at := Vector3(hook_at.x+step.x,hook_at.y,hook_at.z+step.y)
	var space := get_world_3d().direct_space_state
	var top := maxf(hook_at.y,feet.y)+1.0*s
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,top,at.z),Vector3(at.x,at.y-20.0*s,at.z),CarryHost.SOLID_MASK))
	if not hit.is_empty(): at.y = (hit.position as Vector3).y+0.04
	hook_at = at
	paid = _hand().distance_to(hook_at)*1.05

func _coil() -> void:
	reset()

# --- The look ---------------------------------------------------------------------------

## The hook: a shank and three tines, its eye up (+Y) toward the rope.
func _hook_figure() -> Node3D:
	var root := Node3D.new()
	root.name = "Hook"
	root.top_level = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HOOK
	mat.metallic = 0.6
	mat.roughness = 0.45
	var shank := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.03
	c.height = 0.34
	c.radial_segments = 8
	shank.mesh = c
	shank.material_override = mat
	root.add_child(shank)
	var eye := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.025
	ring.outer_radius = 0.05
	ring.rings = 10
	ring.ring_segments = 6
	eye.mesh = ring
	eye.rotation = Vector3(PI*0.5,0.0,0.0)
	eye.position = Vector3(0.0,0.2,0.0)
	eye.material_override = mat
	root.add_child(eye)
	for i in 3:
		var a := TAU*float(i)/3.0
		var tine := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.022
		tm.bottom_radius = 0.012
		tm.height = 0.2
		tm.radial_segments = 6
		tine.mesh = tm
		tine.material_override = mat
		var out := Vector3(cos(a),0.0,sin(a))
		# Splayed out and curled back up.
		tine.transform = Transform3D(Basis(out.cross(Vector3.UP).normalized(),deg_to_rad(-55.0)),Vector3(0.0,-0.16,0.0)+out*0.07+Vector3.UP*0.02)
		root.add_child(tine)
	return root

func _place_hook() -> void:
	_hook.visible = state != "coiled"
	if not _hook.visible: return
	var s := _size()
	var up := Vector3.UP
	match state:
		"fly":
			var v := _vel+Vector3.DOWN*_gravity()*_fly_t
			if v.length() > 0.1: up = -v.normalized()
		"aim":
			up = (_hand()-hook_at).normalized() if _hand().distance_to(hook_at) > 0.05 else Vector3.UP
		"caught", "drag", "tug", "seated", "slip", "pull_up":
			if hold == "anchor":
				var pull := _hand()-hook_at
				if fixed and state != "tug" and edge != Vector3.INF: pull = line_at(edge.y)-hook_at
				up = pull.normalized() if pull.length() > 0.05 else Vector3.UP
			else:
				# Lying on the top, its eye over the lip, tines dug in behind.
				up = (lip_out+Vector3.DOWN*0.15).normalized()
				_hook.global_transform = Transform3D(_basis_up(up)*Basis.from_scale(Vector3.ONE*s),hook_at-lip_out*0.17*s+Vector3.UP*0.05*s)
				return
		"down", "reel":
			up = (lip_out+Vector3.UP*0.2).normalized() if lip_out != Vector3.ZERO else Vector3.RIGHT
		_:
			up = (_hand()-hook_at).normalized() if _hand().distance_to(hook_at) > 0.05 else Vector3.UP
	_hook.global_transform = Transform3D(_basis_up(up)*Basis.from_scale(Vector3.ONE*s),hook_at)

## A basis whose +Y is `up`.
static func _basis_up(up: Vector3) -> Basis:
	var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x,up,x.cross(up)).orthonormalized()

## The rope from his hand to the hook's eye: sagging by its slack, lying on
## what's under it.
func _draw_rope() -> void:
	_rope.visible = state != "coiled"
	if not _rope.visible: return
	var s := _size()
	if state == "pull_up":
		var over := line_at(edge.y+ROPE_R*s)
		var low := maxf(_floor_under(line_at(edge.y-0.3*s))+ROPE_R*s,edge.y-_up_len)
		_draw_line(PackedVector3Array([hook_at,over,line_at(low)]))
		return
	if climber and rappel and guide_at != Vector3.INF:
		# Over the edge, through his lead hand and the brake at his hip, down.
		var over := line_at(edge.y+ROPE_R*s)
		var foot := _floor_under(brake_at)
		var down := Vector3(brake_at.x,foot+ROPE_R*s,brake_at.z)
		_draw_line(PackedVector3Array([hook_at,over,guide_at,brake_at,down,down+edge_out*0.5*s]))
		return
	if edge != Vector3.INF and (state == "caught" or state == "seated") and (climber or hauling or fixed or on_top()):
		_draw_hanging()
		return
	var a := _hand()
	var b := hook_at
	var d := a.distance_to(b)
	if state == "aim": paid = d
	elif state == "caught": paid = maxf(paid,d)
	elif state == "seated": paid = d+0.02*s
	var slack := maxf(paid-d,0.0)
	var sag := sqrt(3.0*d*slack/8.0) if d > 0.01 else 0.0
	var space := get_world_3d().direct_space_state
	var pts := PackedVector3Array()
	for i in SEGS+1:
		var t := float(i)/SEGS
		var p := a.lerp(b,t)+Vector3.DOWN*4.0*sag*t*(1.0-t)
		if i > 0 and i < SEGS and sag > 0.01:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*(4.0*sag*t*(1.0-t)+0.05),p+Vector3.DOWN*0.05,CarryHost.SOLID_MASK))
			if not hit.is_empty(): p.y = (hit.position as Vector3).y+ROPE_R*s
		pts.append(p)
	var mm := _rope.multimesh
	for i in SEGS:
		var p := pts[i]
		var q := pts[i+1]
		var dir := q-p
		var l := dir.length()
		if l < 0.0001:
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),p))
			continue
		var y := dir/l
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < 0.95 else Vector3.RIGHT
		mm.set_instance_transform(i,Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l+0.01,s)),(p+q)*0.5))

## Hooked and hanging free of his hand (he's on it, or up top): from the
## hook over the edge, straight down the face to the floor, a little lying
## there. Segments shared out by each leg's length, so the edge is a corner.
func _draw_hanging() -> void:
	var s := _size()
	var over := line_at(edge.y+ROPE_R*s)
	var foot := line_at(_floor_under(line_at(edge.y-0.3*s))+ROPE_R*s)
	var tail := foot+edge_out*0.5*s
	var pts := PackedVector3Array([hook_at,over,foot,tail])
	_draw_line(pts)

## The rope along the polyline `pts`, its SEGS segments shared by length.
func _draw_line(pts: PackedVector3Array) -> void:
	var s := _size()
	var total := 0.0
	for i in pts.size()-1: total += pts[i].distance_to(pts[i+1])
	var line := PackedVector3Array([pts[0]])
	var left := SEGS
	for i in pts.size()-1:
		var legs := pts.size()-1-i
		var n := left-(legs-1) if legs == 1 else clampi(roundi(SEGS*pts[i].distance_to(pts[i+1])/maxf(total,0.001)),1,left-(legs-1))
		left -= n
		for j in n: line.append(pts[i].lerp(pts[i+1],float(j+1)/n))
	var mm := _rope.multimesh
	for i in SEGS:
		var p := line[i]
		var q := line[i+1]
		var dir := q-p
		var l := dir.length()
		if l < 0.0001:
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),p))
			continue
		var y := dir/l
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < 0.95 else Vector3.RIGHT
		mm.set_instance_transform(i,Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l+0.01,s)),(p+q)*0.5))

## His throwing arm: up over his shoulder while whirling, flung forward as
## it flies.
func _arm_pose() -> void:
	var sk := _skeleton()
	if sk == null: return
	var arm := sk.find_bone("upper_arm.R")
	if arm < 0: return
	var r := _forward().cross(Vector3.UP).normalized()
	if climber:
		if rappel: _rappel_pose(sk)
		else:
			# Just off a rappel: its lean eases out under the climb.
			if _stance_k > 0.0: _lean_figure(sk,_stance_k*_stance_k*(3.0-2.0*_stance_k),deg_to_rad(LEAN))
			_climb_feet(sk)
			_climb_hands(sk)
		return
	if state == "tug":
		_tug_pose(sk,arm,r)
		return
	if state == "pull_up":
		# Hand over hand, the arms taking turns hauling.
		var w := sin(_t*TAU*1.4)
		CarryHost._turn_bone(sk,arm,r,deg_to_rad(70.0+45.0*w))
		var left := sk.find_bone("upper_arm.L")
		if left >= 0: CarryHost._turn_bone(sk,left,r,deg_to_rad(70.0-45.0*w))
		var chest := sk.find_bone("chest")
		if chest >= 0: CarryHost._turn_bone(sk,chest,r,deg_to_rad(10.0+6.0*w))
		return
	if hauling or on_top(): return
	match state:
		"aim":
			CarryHost._turn_bone(sk,arm,r,deg_to_rad(120.0))
		"fly":
			var k := clampf(_fly_t/0.15,0.0,1.0)
			CarryHost._turn_bone(sk,arm,r,deg_to_rad(lerpf(120.0,60.0,k)))
		"caught", "drag", "reel", "seated":
			CarryHost._turn_bone(sk,arm,r,deg_to_rad(45.0))

## The tug: both hands reach up the rope (leaning in), then yank it down to
## his chest (leaning back), held there; the slip throws him back a touch more.
func _tug_pose(sk: Skeleton3D, arm: int, r: Vector3) -> void:
	var up_a := 45.0
	var lean := 0.0
	if _tug_t < TUG_REACH:
		var k := _tug_t/TUG_REACH
		k = k*k*(3.0-2.0*k)
		up_a = lerpf(45.0,150.0,k)
		lean = lerpf(0.0,-14.0,k)
	elif _tug_t < TUG_REACH+TUG_YANK:
		var k := (_tug_t-TUG_REACH)/TUG_YANK
		k = 1.0-(1.0-k)*(1.0-k)
		up_a = lerpf(150.0,10.0,k)
		lean = lerpf(-14.0,26.0,k)
	else:
		var k := clampf((_tug_t-TUG_REACH-TUG_YANK)/TUG_HOLD,0.0,1.0)
		up_a = lerpf(10.0,40.0,k*k)
		lean = lerpf(26.0,4.0,k*k)
	CarryHost._turn_bone(sk,arm,r,deg_to_rad(up_a))
	var left := sk.find_bone("upper_arm.L")
	if left >= 0: CarryHost._turn_bone(sk,left,r,deg_to_rad(up_a-8.0))
	var chest := sk.find_bone("chest")
	if chest >= 0: CarryHost._turn_bone(sk,chest,r,deg_to_rad(lean))

## On the rope: each hand on it at its height (two-bone IK over the hang's
## clip), elbows out and back off the wall, the mitt closed round it.
func _climb_hands(sk: Skeleton3D) -> void:
	var s := _size()
	var fwd := -edge_out
	var right := fwd.cross(Vector3.UP).normalized()
	var to_sk := sk.global_transform.affine_inverse()
	for i in 2:
		var sd: float = _hand_side[i]
		var names := ["upper_arm.R","forearm.R","hand.R"] if sd > 0.0 else ["upper_arm.L","forearm.L","hand.L"]
		var upper := sk.find_bone(names[0])
		var fore := sk.find_bone(names[1])
		var hand := sk.find_bone(names[2])
		if upper < 0 or fore < 0 or hand < 0: return
		var at := line_at(minf(float(_hand_y[i])+REACH_UP*s,edge.y-0.04*s))+right*sd*HAND_SPREAD*s
		# The reaching hand comes off the rope a little as it passes.
		if i == 1 and _pull_t > REACH_AT:
			var r := (_pull_t-REACH_AT)/(1.0-REACH_AT)
			at += edge_out*sin(PI*r)*0.14*s+right*sd*sin(PI*r)*0.06*s
		var pole_w := right*sd*0.8+Vector3.DOWN*0.6+edge_out*0.5
		var pole := (sk.global_basis.inverse()*pole_w).normalized()
		CarryHost._two_bone(sk,upper,fore,hand,to_sk*at,pole,1.0)

## Climbing: the feet pressed to the wall a little over his feet, one
## higher than the other by which hand is on top, knees out.
func _climb_feet(sk: Skeleton3D) -> void:
	var motor: Variant = study.get("motor")
	var s := _size()
	var leg := _leg()
	var right := (-edge_out).cross(Vector3.UP).normalized()
	var to_sk := sk.global_transform.affine_inverse()
	var to_sk_b := sk.global_basis.inverse()
	var y0 := (motor.feet as Vector3).y+FOOT_UP*leg
	if hauling or (motor.feet as Vector3).y > edge.y-float(motor.hang_drop)-0.2*s: return
	for sd: float in [1.0,-1.0]:
		var side := "R" if sd > 0.0 else "L"
		var a := sk.find_bone("thigh."+side)
		var b := sk.find_bone("shin."+side)
		var c := sk.find_bone("foot."+side)
		if a < 0 or b < 0 or c < 0: continue
		var up := 0.18*leg if sd == float(_hand_side[0]) else 0.0
		var goal := Vector3(edge.x,y0+up,edge.z)+edge_out*0.06*s+right*sd*0.14*s
		var pole := (to_sk_b*(Vector3.UP*0.8-edge_out*0.5+right*sd*0.4)).normalized()
		CarryHost._two_bone(sk,a,b,c,to_sk*goal,pole,CLIMB_FEET)

## The figure leaned back `lean` (rad) times `k` about its hips, the hips set
## over the motor's feet (up his leg as `k` grows); the hips' world spot.
func _lean_figure(sk: Skeleton3D, k: float, lean: float) -> Vector3:
	var fig: Node3D = study.get("figure")
	var motor: Variant = study.get("motor")
	var hips := sk.find_bone("hips")
	if fig == null or hips < 0: return Vector3.INF
	var hip_w := sk.global_transform*sk.get_bone_global_pose(hips).origin
	var hip_up := hip_w.y-fig.global_position.y
	var tilt := Basis(Vector3.UP.cross(edge_out).normalized(),lean*k)
	var want_hip := (motor.feet as Vector3)+Vector3.UP*lerpf(hip_up,_leg()*0.95,k)
	fig.global_basis = tilt*fig.global_basis
	hip_w = sk.global_transform*sk.get_bone_global_pose(hips).origin
	fig.global_position += want_hip-hip_w
	return want_hip

## Rappelling: the figure (in the hang's clip) leaned back off the wall
## about its hips, set where the stance puts them; legs (two-bone IK) to
## the wall, knees up, walking down it as he lowers (each foot lifting in
## turn, skimming at speed); the lead hand up the rope before his chest,
## the brake hand at his hip. Eased in by `_stance_k` from the hang.
func _rappel_pose(sk: Skeleton3D) -> void:
	var hips := sk.find_bone("hips")
	if hips < 0: return
	var s := _size()
	var k := _stance_k*_stance_k*(3.0-2.0*_stance_k)
	var leg := _leg()
	var right := (-edge_out).cross(Vector3.UP).normalized()
	var lean := deg_to_rad(LEAN)
	if _hop_t >= HOP_CROUCH and _hop_t < HOP_LAND:
		lean += deg_to_rad(8.0)*sin(PI*(_hop_t-HOP_CROUCH)/(HOP_LAND-HOP_CROUCH))
	# Faster, he sits back further into it.
	lean += deg_to_rad(6.0)*clampf(_rap_v/(RAP_SPEED.y*s),0.0,1.0)
	var want_hip := _lean_figure(sk,k,lean)
	if want_hip == Vector3.INF: return
	var to_sk := sk.global_transform.affine_inverse()
	var to_sk_b := sk.global_basis.inverse()
	# Feet on the wall under the hips, walking down it.
	var wall_y := want_hip.y-FOOT_DOWN*leg
	var walk := _walk_k()
	for sd: float in [1.0,-1.0]:
		var side := "R" if sd > 0.0 else "L"
		var a := sk.find_bone("thigh."+side)
		var b := sk.find_bone("shin."+side)
		var c := sk.find_bone("foot."+side)
		if a < 0 or b < 0 or c < 0: continue
		var ph := _step*PI+(0.0 if sd > 0.0 else PI)
		var lift := maxf(sin(ph),0.0)*walk
		var goal := Vector3(edge.x,wall_y-cos(ph)*0.2*leg*walk,edge.z)+edge_out*(0.06*s+lift*RAP_LIFT*leg)+right*sd*0.13*s
		var pole := (to_sk_b*(Vector3.UP*0.8-edge_out*0.6+right*sd*0.2)).normalized()
		CarryHost._two_bone(sk,a,b,c,to_sk*goal,pole,k)
	# The hands: the lead up the rope before his chest, the brake at the hip.
	var chest := sk.find_bone("chest")
	var chest_w := sk.global_transform*sk.get_bone_global_pose(chest if chest >= 0 else hips).origin
	var hip_w := sk.global_transform*sk.get_bone_global_pose(hips).origin
	guide_at = chest_w-edge_out*0.3*s+Vector3.UP*0.12*s
	brake_at = hip_w+right*0.22*s+edge_out*0.12*s-Vector3.UP*0.04*s
	var arms := [["upper_arm.L","forearm.L","hand.L",guide_at,-right*0.7+Vector3.DOWN*0.7],
		["upper_arm.R","forearm.R","hand.R",brake_at,right*0.7+Vector3.DOWN*0.3+edge_out*0.5]]
	for arm: Array in arms:
		var u := sk.find_bone(arm[0])
		var f := sk.find_bone(arm[1])
		var h := sk.find_bone(arm[2])
		if u < 0 or f < 0 or h < 0: continue
		CarryHost._two_bone(sk,u,f,h,to_sk*(arm[3] as Vector3),(to_sk_b*(arm[4] as Vector3)).normalized(),1.0)

## The reticle (a ring at the target) and the arc's dots, gold or red.
func _show_aim(on: bool) -> void:
	_reticle.visible = on
	_dots.visible = on
	if not on: return
	var colour := AIM_OK if aim_ok else AIM_BAD
	_reticle_mat.albedo_color = Color(colour,0.85)
	_dots_mat.albedo_color = Color(colour,0.55)
	var s := _size()
	var pulse := 1.0+0.08*sin(Time.get_ticks_msec()*0.008)
	var ring := (0.35 if aim_hold == "anchor" else 0.45)*s*pulse
	var at := aim_lip if aim_lip != Vector3.INF else aim_at
	_reticle.global_transform = Transform3D(Basis.from_scale(Vector3(ring,1.0,ring)),at+Vector3.UP*0.06*s)
	var mm := _dots.multimesh
	mm.visible_instance_count = mini(aim_arc.size(),mm.instance_count)
	for i in mm.visible_instance_count:
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*s),aim_arc[i]))

func _clank() -> void:
	_clink.global_position = hook_at
	_clink.pitch_scale = randf_range(0.9,1.15)
	_clink.play()

## A short metal clink, made up.
static func _clink_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.18)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var v := (sin(TAU*2400.0*t)*0.5+sin(TAU*3700.0*t)*0.3+sin(TAU*1300.0*t)*0.2)*exp(-t*28.0)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _click_play() -> void:
	_click.global_position = hook_at
	_click.play()

## The seat: a sharp, dry double click, made up.
static func _click_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.14)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var v := 0.0
		for at: float in [0.0,0.055]:
			if t >= at:
				var u := t-at
				v += (sin(TAU*4200.0*u)*0.6+sin(TAU*1900.0*u)*0.4)*exp(-u*90.0)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*22000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _say(text: String) -> void:
	_line.text = text
	_line.visible = true
	_line_t = 0.0

# --- Helpers ----------------------------------------------------------------------------

func _size() -> float:
	return float(study.get("motor").size)

func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))*HOOK_G

## The arc from `from` to `to` over a top AIM_RISE (plus AIM_RISE_M a metre
## across) above the higher end.
func _arc_to(from: Vector3, to: Vector3) -> Vector3:
	var g := _gravity()
	var s := _size()
	var flat := Vector3(to.x-from.x,0.0,to.z-from.z)
	var top := maxf(from.y,to.y)+AIM_RISE*s+AIM_RISE_M*flat.length()
	var up := sqrt(2.0*g*(top-from.y))
	var t := up/g+sqrt(2.0*g*(top-to.y))/g
	return flat/t+Vector3.UP*up

func _flight_time(from: Vector3, to: Vector3, v: Vector3) -> float:
	var g := _gravity()
	var top := from.y+v.y*v.y/(2.0*g)
	return v.y/g+sqrt(2.0*maxf(top-to.y,0.0)/g)

func _to_cam(v: Vector2) -> Vector2:
	var f := PilotMotor.forward(float(study.get("_yaw")))
	var r := Vector2(-f.y,f.x)
	return Vector2(v.dot(r),v.dot(f))

func _from_cam(v: Vector2) -> Vector2:
	var f := PilotMotor.forward(float(study.get("_yaw")))
	var r := Vector2(-f.y,f.x)
	return r*v.x+f*v.y

func _forward() -> Vector3:
	var fig: Node3D = study.get("figure")
	if fig == null: return Vector3.FORWARD
	var f := -fig.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

func _skeleton() -> Skeleton3D:
	var body: Node = study.get("body")
	return null if body == null else body.get("_skeleton") as Skeleton3D

## His right hand (or near his hip).
func _hand() -> Vector3:
	var sk := _skeleton()
	if sk != null:
		for b: String in ["hand.R","forearm.R"]:
			var i := sk.find_bone(b)
			if i >= 0: return sk.global_transform*sk.get_bone_global_pose(i).origin
	var motor: Variant = study.get("motor")
	return (motor.feet as Vector3)+Vector3.UP*0.9*_size()
