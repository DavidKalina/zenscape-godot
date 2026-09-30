extends Node
## The creation shell's camera (docs/scenic/camera.md). Always at hand, with
## no mode to switch: right-drag (or Ctrl-drag, or a two-finger swipe) orbits,
## Shift-swipe and middle drag pan, scroll and pinch zoom toward the pointer,
## the arrows pan and Shift+arrows turn. Double-click (or F) on a creature,
## plant, stone or pond glides there and frames it, and the orbit then circles
## it; on bare ground it moves the pivot there. A creature is followed gently
## until you pan or pick something else. R glides to the overview and
## Backspace or Home glides back to the view before.
##
## Pointing at something shows a soft ring on the ground around it and its
## name (at once while looking, after a still moment with a brush in hand).
## Names come from scripts/scene_inspector.gd, which photo mode shares.
##
## Like photo mode, this owns an eased pose and writes it into the scene's own
## orbit (target, yaw, polar, distance) before the scene's _process, so the
## fog, reflections, look pass and tremor read the camera they always have.
## Every move is a critically damped spring toward a goal, so a glide starts
## and ends softly, never overshoots, and any new input takes it over from
## wherever it is. The scene's pooled drag deltas are taken as input here, so
## its own easing has nothing left to apply. A mouse drag that orbits turns
## the world by its grabbed ground instead, and a flick spins it on
## (scripts/world_turn.gd; `--classic-orbit` for the old orbit). The room (sky,
## sun, lights) turns with every yaw change made here, so the diorama is what
## seems to spin (world_turn.gd `turn_room`). A pose written from outside (a
## regrowth, the menu's Overview, a new plain) is adopted as it stands, and
## does not turn the room.
##
## While the rim is pulled down for the edge spring (scripts/edge_spring.gd)
## the camera leans with the dipping block (`lean`): down after it, in toward
## the grabbed edge and a little lower, so the pull reads as digging in, and
## it rides the block's snap back up. The lean is laid over the eased pose as
## it is written and never enters it. That is `--pull-cam=old`; the other
## variants (scripts/modeless_input.gd `pull_cam`, `_pull_step`) hold the
## camera still so the block's drop reads against a fixed frame: "a" holds,
## follows only late in a deep pull, waits a beat after the release and then
## catches up on its own softer spring; "b" also swings low and side-on at
## the press and eases back once the range has settled; "c" stays low.
const Inspector = preload("res://scripts/scene_inspector.gd")
const Glass = preload("res://scripts/glass_chrome.gd")
## Spring stiffness (natural frequency, 1/s). A glide covers 95 % in 0.63 s
## and settles within 1 % by 0.89 s; hand moves trail by about 0.12 s; a
## followed creature is chased loosely (95 % in 1.5 s).
const GLIDE := 7.5
const HAND := 16.0
const FOLLOW := 3.2
## A released mouse drag carries on at FLING of its speed and loses it over
## FLING_DECAY seconds. Trackpads bring their own momentum.
const FLING := 0.35
const FLING_DECAY := 0.22
const POLAR := Vector2(0.22,1.45)
const DISTANCE := Vector2(1.6,110.0)
## The camera stays this far above the ground under it.
const CLEARANCE := 0.7
const PLATE_REACH := 13.5
## Zoom per wheel notch; pinch factor exponent.
const WHEEL := 1.12
const PINCH := 1.3
## Screen points per pan-gesture unit (macOS reports 0.03 per point), and the
## sign that makes a natural-scrolling swipe move like a drag.
const SWIPE := 33.0
const SWIPE_SIGN := -1.0
## Keyboard: screen heights of pan and radians of turn per second.
const KEY_PAN := 0.7
const KEY_TURN := 1.3
const HISTORY := 8
## Seconds the pointer rests before a hover names what is under it.
const HOVER_LOOK := 0.08
const HOVER_BRUSH := 0.45
## The lean at a full dip (diorama_flip `dip` 1): LEAN_FOLLOW of the block's
## drop, LEAN_TOWARD of the way from the pivot to the grabbed edge (level),
## LEAN_IN off the distance, and LEAN_TILT radians lower.
const LEAN_FOLLOW := 0.7
const LEAN_TOWARD := 0.12
const LEAN_IN := 0.12
const LEAN_TILT := 0.08
## The pull's camera (`--pull-cam` a, b, c; see `_pull_step`). Press (b, c),
## once the pull shows (edge_spring DEAD): a view higher than PULL_SIDE
## (polar, radians from straight down; 1.34 is about 13 degrees above the
## horizon) swings down to it on two chained critically damped springs of
## PULL_SIDE_W 1/s (95 % in about 0.28 s, starting and ending at rest); the
## yaw is never touched, and it keeps CLEARANCE over the ground.
const PULL_SIDE := 1.34
const PULL_SIDE_W := 28.0
## Pull: the camera holds. Only past PULL_LATE_FROM (diorama_flip `dip`; 1
## is the cap, so only the deep pull) does it follow, PULL_LATE_SHARE of the
## block's further drop, on a slow critically damped spring of PULL_LATE_W.
const PULL_LATE_FROM := 1.0
const PULL_LATE_SHARE := 0.45
const PULL_LATE_W := 2.6
## Release: the camera holds PULL_HOLD seconds while the block shoots up, then
## catches up on its own softer spring (PULL_CATCH_W 1/s, PULL_CATCH_ZETA; a
## small overshoot), pushed up by PULL_CATCH_KICK m/s per unit of the pull
## over PULL_CATCH_PUSH seconds (a sine-squared push, so its acceleration
## starts and ends at nothing), so it rides the burst and settles.
const PULL_HOLD := 0.12
const PULL_CATCH_W := 7.0
const PULL_CATCH_ZETA := 0.5
const PULL_CATCH_KICK := 2.4
const PULL_CATCH_PUSH := 0.1
## Settle: PULL_RETURN_AFTER seconds after the release the swing eases back
## to the player's view on two chained springs of PULL_RETURN_W (95 % in
## about 1.7 s), or, under "c", is kept as the player's own view.
const PULL_RETURN_AFTER := 0.9
const PULL_RETURN_W := 4.5
const HINT := "Double-click anything to go there  ·  right-drag or swipe with two fingers to look around  ·  pinch or scroll to zoom  ·  Backspace goes back"
const HINT_FILE := "user://camera.cfg"

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
var inspector := Inspector.new()
## True while this drives the camera (the shell is open on a world, no menu,
## no photo mode, no regrowth under way).
var live := false
# The eased pose: pivot, and (yaw, polar, log distance), with velocities and goals.
var _pivot := Vector3.ZERO
var _pivot_v := Vector3.ZERO
var _pivot_goal := Vector3.ZERO
var _view := Vector3.ZERO
var _view_v := Vector3.ZERO
var _view_goal := Vector3.ZERO
var _w_pivot := HAND
var _w_view := HAND
var _written := []
var _glide_time := 0.0
var _history: Array[Dictionary] = []
## What the camera last framed ({} for none), and whether it follows it.
var focus := {}
var following := false
var hovered := {}
## Turning the world like a lazy Susan (scripts/world_turn.gd): a mouse drag
## that orbits grabs the ground and turns it, and a flick spins it on.
var turn: Node
var _dragging := false
var _hand_view := Vector2.ZERO
var _hand_pan := Vector3.ZERO
var _fling_view := Vector2.ZERO
var _fling_pan := Vector3.ZERO
var _press := {}
var _mouse := Vector2(-1,-1)
var _rest := 0.0
var _hover_key := []
var _hover_clock := 0.0
var _cursor_owned := false
## The scene's idle drift was on when this last wrote the pose, so the yaw
## it has added since is a turn of the world.
var _drifting := false
## The lean last written: pivot offset, polar offset and distance factor.
var _lean := [Vector3.ZERO,0.0,1.0]
## The pull's camera: its variant, its beat ("" at rest, "held", "wait",
## "catch"), seconds since the release, the pivot's drop below the pose (m,
## down positive) and its rate, and the swing (polar radians over the pose),
## its rate and its chained goal. All laid over the pose as the lean is.
var pull_cam := preload("res://scripts/modeless_input.gd").pull_cam()
var pull_beat := ""
var pull_clock := 0.0
var pull_drop := 0.0
var pull_swing := 0.0
var _pull_drop_v := 0.0
var _pull_swing_v := 0.0
var _pull_goal := 0.0
var _pull_goal_v := 0.0
var _pull_want := 0.0
var _pull_size := 0.0
var _pull_armed := false
# Chrome: the ring and name, and the first-session hint.
var layer := CanvasLayer.new()
var overlay := Control.new()
var label := Label.new()
var _ring: PackedVector3Array = []
var _ring_alpha := 0.0
var _ring_for := {}
var _label_text := ""
var _label_at := Vector3.ZERO
var _label_time := 0.0
var _label_hold := 0.0
var hint_box := HBoxContainer.new()
var hint := Label.new()
var _hint_close := Button.new()
var _hint_seen := false
var _hint_alpha := 0.0
var _hint_time := 0.0
var _used := {}

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	name = "CameraRig"
	# After photo mode (-10), before the scene: the scene reads this frame's pose.
	process_priority = -9
	inspector.setup(scene)
	turn = preload("res://scripts/world_turn.gd").new()
	add_child(turn)
	turn.setup(self)
	_hint_seen = _read_seen()
	_build_chrome()

# --- Chrome ---------------------------------------------------------------------

func _build_chrome() -> void:
	layer.name = "CameraChrome"
	layer.layer = 3
	add_child(layer)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(_draw_ring)
	layer.add_child(overlay)
	for text: Label in [label,hint]:
		text.add_theme_font_size_override("font_size",13)
		text.add_theme_color_override("font_color",Color(Glass.INK,0.92))
		text.add_theme_color_override("font_shadow_color",Color("182628",0.85))
		text.add_theme_constant_override("shadow_offset_y",1)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	overlay.add_child(label)
	hint.text = HINT
	hint.add_theme_color_override("font_color",Color(Glass.INK,0.8))
	hint_box.add_theme_constant_override("separation",8)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.add_child(hint)
	_hint_close.text = "×"
	_hint_close.flat = true
	_hint_close.focus_mode = Control.FOCUS_NONE
	_hint_close.tooltip_text = "Got it"
	_hint_close.add_theme_font_size_override("font_size",14)
	Glass.button(_hint_close)
	_hint_close.pressed.connect(dismiss_hint)
	hint_box.add_child(_hint_close)
	hint_box.modulate.a = 0.0
	hint_box.hide()
	overlay.add_child(hint_box)

func _read_seen() -> bool:
	if _private(): return false
	var config := ConfigFile.new()
	return config.load(HINT_FILE) == OK and bool(config.get_value("hints","camera_seen",false))

## Probes and the packaged self-check never mark the hint as seen.
func _private() -> bool:
	return scene.has_meta("movie_capture") or "--verify-desktop-build" in OS.get_cmdline_user_args()

func dismiss_hint() -> void:
	if _hint_seen: return
	_hint_seen = true
	if _private(): return
	var config := ConfigFile.new()
	config.load(HINT_FILE)
	config.set_value("hints","camera_seen",true)
	config.save(HINT_FILE)

func contains_pointer(point: Vector2) -> bool:
	return hint_box.is_visible_in_tree() and _hint_alpha > 0.05 and hint_box.get_global_rect().has_point(point)

func _sync_chrome(delta: float) -> void:
	layer.visible = live and scene._toolbar.visible
	var screen := scene.get_viewport().get_visible_rect().size
	# The ring follows a hovered thing, else a followed creature.
	var ring_for := hovered if not hovered.is_empty() else focus if following else {}
	if not ring_for.is_empty() and not is_same(ring_for,_ring_for):
		_ring_for = ring_for
		_ring = _ring_points(ring_for)
	elif following and is_same(ring_for,focus) and Engine.get_process_frames()%3 == 0:
		_ring = _ring_points(focus)
	_ring_alpha = move_toward(_ring_alpha,0.0 if ring_for.is_empty() else 1.0,delta*(6.0 if not ring_for.is_empty() else 3.0))
	if _ring_alpha <= 0.0: _ring_for = {}
	# The name: a hover's title while pointing; a framed thing's story for a while.
	_label_hold = maxf(0.0,_label_hold-delta)
	if not hovered.is_empty():
		_show_label(str(hovered.title),hovered.point+Vector3.UP*float(hovered.size)*0.7,0.0)
	var want := 1.0 if not hovered.is_empty() or _label_hold > 0.0 else 0.0
	label.modulate.a = move_toward(label.modulate.a,want,delta*(6.0 if want > 0.0 else 1.5))
	if following and _label_hold <= 0.0 and hovered.is_empty():
		var at: Variant = inspector.track(focus)
		if at != null: _label_at = at
	if label.modulate.a > 0.0 and not camera.is_position_behind(_label_at):
		label.size = label.get_minimum_size()
		label.position = (camera.unproject_position(_label_at)+Vector2(-label.size.x*0.5,-label.size.y-22.0)).clamp(Vector2(8,8),screen-label.size-Vector2(8,8))
	label.visible = label.modulate.a > 0.01 and not camera.is_position_behind(_label_at)
	# First session: one calm line under the top edge, until dismissed or used.
	var hint_wanted: bool = not _hint_seen and live and not scene.crafting
	if hint_wanted and scene._toolbar.visible:
		# Read for a minute is read.
		_hint_time += delta
		if _hint_time > 60.0: dismiss_hint()
	_hint_alpha = move_toward(_hint_alpha,1.0 if hint_wanted else 0.0,delta*(1.2 if hint_wanted else 0.8))
	hint_box.modulate.a = _hint_alpha
	hint_box.visible = _hint_alpha > 0.01
	if hint_box.visible:
		hint_box.size = hint_box.get_combined_minimum_size()
		var factor := minf(1.0,minf(screen.x/1080.0,screen.y/720.0))
		hint_box.scale = Vector2.ONE*factor
		# Under a shell that runs along the top (scripts/lantern_shell.gd).
		var shell: Control = scene.get("creation_palette")
		var top := 18.0
		if shell != null and shell.has_method("top_clearance") and shell.is_visible_in_tree(): top = shell.top_clearance()
		hint_box.position = Vector2((screen.x-hint_box.size.x*factor)*0.5,top)
	overlay.queue_redraw()

func _show_label(text: String, at: Vector3, hold: float) -> void:
	if text != _label_text:
		_label_text = text
		label.text = text
	_label_at = at
	_label_hold = maxf(_label_hold,hold)

## A ring on the ground around a thing, in world space.
func _ring_points(found: Dictionary) -> PackedVector3Array:
	var points := PackedVector3Array()
	var centre: Vector3 = found.get("base",found.point)
	if following and is_same(found,focus):
		var at: Variant = inspector.track(found)
		if at != null:
			var y: Variant = inspector.ground_y(at)
			centre = Vector3(at.x,float(y) if y != null else at.y-0.5,at.z)
	var radius := clampf(float(found.get("reach",float(found.size)*0.75))+0.25,0.35,9.0)
	var water := str(found.kind) == "pond"
	for i in range(49):
		var angle := TAU*i/48.0
		var p := centre+Vector3(cos(angle),0.0,sin(angle))*radius
		var y: Variant = inspector.ground_y(p) if not water else null
		p.y = float(y)+0.06 if y != null else centre.y+0.06
		points.append(p)
	return points

func _draw_ring() -> void:
	if _ring_alpha <= 0.01 or _ring.is_empty(): return
	var line := PackedVector2Array()
	for p in _ring:
		if camera.is_position_behind(p): return
		line.append(camera.unproject_position(p))
	overlay.draw_polyline(line,Color(1.0,0.95,0.85,0.14*_ring_alpha),5.0,true)
	overlay.draw_polyline(line,Color(1.0,0.95,0.85,0.62*_ring_alpha),1.5,true)

# --- The pose ---------------------------------------------------------------------

func _is_live() -> bool:
	if not scene.get("creation_mode") or not scene.get("shell_ready") or not scene._has_world: return false
	if scene._menu.visible or editor.forming: return false
	var photo: Node = scene.get("photo")
	if photo != null and (photo.active or photo._returning > 0.0): return false
	var wanderer: Node = scene.get("wanderer")
	if wanderer != null and (wanderer.active or wanderer._returning > 0.0): return false
	var places: Node = scene.get("places")
	return places == null or not places.busy

func _process(delta: float) -> void:
	var was_live := live
	live = _is_live()
	var yaw_from: float = scene.yaw
	# Space's idle drift turns the scene's yaw after this has written it; that
	# turn is the world's too (world_turn.gd `turn_room`).
	if live and was_live and _drifting and not _written.is_empty(): turn.turn_room(angle_difference(_written[1],yaw_from))
	if not live or not was_live or _moved_outside(): _adopt()
	if not live:
		hovered = {}
		turn.rest()
	if live:
		_take_scene_drags(delta)
		_keys(delta)
		_advance_fling(delta)
		_advance_follow(delta)
		_step(delta)
		_keep_clear()
		turn.advance(delta)
		_keep_clear()
		_pull_step(delta)
		_write()
		turn.turn_room(angle_difference(yaw_from,scene.yaw))
		_hover(delta)
	elif _cursor_owned:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_cursor_owned = false
	_sync_chrome(delta)
	_drifting = live and bool(scene.get("_auto_orbit"))

## Take the scene's pose as it stands: nothing in flight.
func _adopt() -> void:
	# A pose this wrote with a lean on is taken without it.
	var leaned := not _moved_outside()
	_pivot = scene.target-(_lean[0] if leaned else Vector3.ZERO)
	_pivot_goal = _pivot
	_view = Vector3(scene.yaw,scene.polar-(_lean[1] if leaned else 0.0),log(maxf(scene.distance/(_lean[2] if leaned else 1.0),0.01)))
	_lean = [Vector3.ZERO,0.0,1.0]
	_pull_rest()
	_view_goal = _view
	_pivot_v = Vector3.ZERO
	_view_v = Vector3.ZERO
	_fling_view = Vector2.ZERO
	_fling_pan = Vector3.ZERO
	following = false
	turn.stop()
	_written = [scene.target,scene.yaw,scene.polar,scene.distance]

func _moved_outside() -> bool:
	if _written.is_empty(): return true
	return scene.target.distance_to(_written[0]) > 0.0005 or absf(scene.yaw-_written[1]) > 0.0001 \
		or absf(scene.polar-_written[2]) > 0.0001 or absf(scene.distance-_written[3]) > 0.0005

func _write() -> void:
	_lean = lean()
	scene.target = _pivot+_lean[0]
	scene.yaw = _view.x
	scene.polar = _view.y+_lean[1]
	scene.distance = exp(_view.z)*_lean[2]
	_written = [scene.target,scene.yaw,scene.polar,scene.distance]

## The lean for the block's dip now: [pivot offset, polar offset, distance
## factor]. None unless the block is dipped or rising back.
func lean() -> Array:
	if pull_cam != "old": return [Vector3.DOWN*pull_drop,pull_swing,1.0]
	var flip: Node = scene.get("flip")
	if flip == null or not flip.phase in [flip.Phase.DIP,flip.Phase.RISE] or flip.dip <= 0.0: return [Vector3.ZERO,0.0,1.0]
	var dip: float = flip.dip
	var edge: Vector3 = flip._centre+flip._grab_dir*flip._half-_pivot
	edge.y = 0.0
	var move: Vector3 = edge*LEAN_TOWARD*dip+Vector3.DOWN*flip.DIP_DROP*LEAN_FOLLOW*dip
	var tilt := minf(LEAN_TILT*dip,POLAR.y-_view.y)
	return [move,maxf(tilt,0.0),1.0-LEAN_IN*dip]

## The pull's camera beats (`--pull-cam` a, b, c): see PULL_SIDE. The swing
## and the drop are laid over the eased pose by `lean`, so the player's own
## pose, and any orbit they make meanwhile, stays theirs.
func _pull_step(delta: float) -> void:
	if pull_cam == "old": return
	var flip: Node = scene.get("flip")
	if flip == null: return
	var dipping: bool = flip.phase == flip.Phase.DIP
	if dipping and pull_beat != "held":
		pull_beat = "held"
		_pull_armed = false
	if dipping and not _pull_armed and pull_cam != "a":
		# Press: once the pull shows (the edge spring's DEAD, so a stray
		# twitch does not swing), swing low and side-on, never taking the yaw.
		var edge: Node = scene.get("edge_spring")
		if edge == null or float(edge.pulled) >= float(edge.DEAD):
			_pull_armed = true
			_pull_want = maxf(0.0,PULL_SIDE-_view.y)
	elif pull_beat == "held" and not dipping:
		# Release: hold a beat while the block shoots up.
		pull_beat = "wait"
		pull_clock = 0.0
		_pull_size = clampf(float(flip._dip_amount),0.0,1.0)
		_pull_drop_v = 0.0
	match pull_beat:
		"held":
			var late: float = maxf(float(flip.dip)-PULL_LATE_FROM,0.0)*float(flip.DIP_DROP)*PULL_LATE_SHARE
			var d := spring(pull_drop,_pull_drop_v,late,PULL_LATE_W,delta)
			pull_drop = d[0]
			_pull_drop_v = d[1]
		"wait","catch":
			pull_clock += delta
			if pull_beat == "wait" and pull_clock >= PULL_HOLD: pull_beat = "catch"
			if pull_beat == "catch":
				var remaining := delta
				var since := pull_clock-delta-PULL_HOLD
				while remaining > 0.0:
					var h := minf(remaining,1.0/240.0)
					remaining -= h
					since += h
					var push := 0.0
					if since > 0.0 and since < PULL_CATCH_PUSH: push = PULL_CATCH_KICK*_pull_size*2.0/PULL_CATCH_PUSH*pow(sin(PI*since/PULL_CATCH_PUSH),2.0)
					_pull_drop_v += (-PULL_CATCH_W*PULL_CATCH_W*pull_drop-2.0*PULL_CATCH_ZETA*PULL_CATCH_W*_pull_drop_v-push)*h
					pull_drop += _pull_drop_v*h
			if pull_clock >= PULL_RETURN_AFTER and _pull_want > 0.0:
				if pull_cam == "c":
					# Stay low: the swing becomes the player's own view.
					var kept := _pull_goal-pull_swing
					_view.y += pull_swing
					_view_goal.y = minf(_view_goal.y+pull_swing,POLAR.y)
					pull_swing = 0.0
					_pull_goal = kept
				_pull_want = 0.0
	# The swing: two chained critically damped springs, so it starts and ends
	# at rest; quicker in than back.
	var w := PULL_SIDE_W if _pull_want > 0.0 else PULL_RETURN_W
	var g := spring(_pull_goal,_pull_goal_v,_pull_want,w,delta)
	_pull_goal = g[0]
	_pull_goal_v = g[1]
	var s := spring(pull_swing,_pull_swing_v,_pull_goal,w,delta)
	pull_swing = s[0]
	_pull_swing_v = s[1]
	pull_swing = clampf(pull_swing,0.0,maxf(POLAR.y-_view.y,0.0))
	_pull_clear()
	if pull_beat == "catch" and pull_clock >= PULL_RETURN_AFTER and _pull_want == 0.0 \
			and absf(pull_drop) < 0.001 and absf(_pull_drop_v) < 0.01 and pull_swing < 0.0005 and absf(_pull_goal) < 0.0005:
		_pull_rest()

## The swing never takes the eye under CLEARANCE over the ground.
func _pull_clear() -> void:
	if pull_swing <= 0.0: return
	var d := exp(_view.z)
	var pivot := _pivot+Vector3.DOWN*pull_drop
	var at := pivot+offset(_view.x,_view.y+pull_swing)*d
	var ground: Variant = inspector.ground_y(at)
	if ground == null: return
	var rise := (float(ground)+CLEARANCE-pivot.y)/d
	if rise >= 1.0:
		pull_swing = 0.0
		return
	var most := maxf(acos(maxf(rise,-1.0))-_view.y,0.0)
	if pull_swing > most:
		pull_swing = most
		_pull_swing_v = minf(_pull_swing_v,0.0)

func _pull_rest() -> void:
	pull_beat = ""
	pull_clock = 0.0
	pull_drop = 0.0
	pull_swing = 0.0
	_pull_drop_v = 0.0
	_pull_swing_v = 0.0
	_pull_goal = 0.0
	_pull_goal_v = 0.0
	_pull_want = 0.0
	_pull_size = 0.0
	_pull_armed = false

## Exact critically damped step of x toward goal (floats or vectors): [x, v].
static func spring(x: Variant, v: Variant, goal: Variant, w: float, dt: float) -> Array:
	var e := exp(-w*dt)
	var d: Variant = x-goal
	var t: Variant = (v+d*w)*dt
	return [goal+(d+t)*e,(v-t*w)*e]

func _step(delta: float) -> void:
	_glide_time += delta
	var p := spring(_pivot,_pivot_v,_pivot_goal,_w_pivot,delta)
	_pivot = p[0]
	_pivot_v = p[1]
	var v := spring(_view,_view_v,_view_goal,_w_view,delta)
	_view = v[0]
	_view_v = v[1]

static func offset(yaw: float, polar: float) -> Vector3:
	return Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))

func eye() -> Vector3:
	return _pivot+offset(_view.x,_view.y)*exp(_view.z)

## Never under the ground: the camera's pitch lifts (and, right over a
## steep rise, its distance grows) until it clears the ground beneath it.
func _keep_clear() -> void:
	for pass_index in range(4):
		var d := exp(_view.z)
		var at := eye()
		var ground: Variant = inspector.ground_y(at)
		if ground == null: return
		var floor_y := float(ground)+CLEARANCE
		if at.y >= floor_y: return
		var rise := (floor_y-_pivot.y)/d
		if rise >= 0.995:
			_view.z = log(floor_y-_pivot.y+0.05)
			_view.y = POLAR.x*0.5
		else:
			_view.y = minf(_view.y,acos(rise))
		_view_v.y = minf(_view_v.y,0.0)
		_view_goal.y = minf(_view_goal.y,_view.y+0.01)

func _height() -> float:
	return maxf(scene.get_viewport().get_visible_rect().size.y,1.0)

func _hand() -> void:
	scene._auto_orbit = false

## Orbit by screen pixels, as a drag: a screen height is a full turn.
func orbit_pixels(d: Vector2) -> Vector2:
	var h := _height()
	var before := Vector2(_view_goal.x,_view_goal.y)
	_view_goal.x -= TAU*d.x/h
	_view_goal.y = clampf(_view_goal.y-TAU*d.y/h,POLAR.x,POLAR.y)
	_w_view = HAND
	_hand()
	return Vector2(_view_goal.x,_view_goal.y)-before

## Pan by screen pixels: the ground follows the pointer, the pivot slides
## over the land at its height above it, and a followed creature is let go.
func pan_pixels(d: Vector2) -> Vector3:
	var h := _height()
	var reach := 2.0*exp(_view_goal.z)*tan(deg_to_rad(camera.fov)*0.5)/h
	var yaw := _view_goal.x
	var right := Vector3(cos(yaw),0.0,-sin(yaw))
	var forward := -Vector3(sin(yaw),0.0,cos(yaw))
	var move := -right*d.x*reach+forward*d.y*reach/maxf(cos(_view_goal.y),0.4)
	return _pan_world(move)

func _pan_world(move: Vector3) -> Vector3:
	var before := _pivot_goal
	var lift := 0.0
	var ground: Variant = inspector.ground_y(_pivot_goal)
	if ground != null: lift = clampf(_pivot_goal.y-float(ground),0.0,4.0)
	var goal := _on_plate(_pivot_goal+move)
	var under: Variant = inspector.ground_y(goal)
	if under != null: goal.y = float(under)+lift
	_pivot_goal = goal
	_w_pivot = HAND
	following = false
	_hand()
	return _pivot_goal-before

func _on_plate(point: Vector3) -> Vector3:
	var local := editor.terrain.to_local(point)
	local.x = clampf(local.x,-PLATE_REACH*1.4,PLATE_REACH*1.4)
	local.z = clampf(local.z,-PLATE_REACH*1.4,PLATE_REACH*1.4)
	return editor.terrain.to_global(local)

## Zoom by a factor (above 1 is out) toward what is under the pointer; a
## followed creature stays the pivot.
func zoom_at(point: Vector2, factor: float) -> void:
	var old := exp(_view_goal.z)
	var high := maxf(DISTANCE.y,old)
	var goal := clampf(old*factor,DISTANCE.x,high)
	if is_equal_approx(goal,old): return
	if not following:
		var hit: Variant = inspector.ground_hit(point)
		if hit != null:
			_pivot_goal = _on_plate(hit+(_pivot_goal-hit)*(goal/old))
			_w_pivot = HAND
	_view_goal.z = log(goal)
	_w_view = HAND
	_hand()

## Glide to a pose; any input takes over from wherever the glide has got to.
func glide_to(pivot: Vector3, yaw: float, polar: float, distance: float) -> void:
	_pivot_goal = pivot
	_view_goal = Vector3(_view.x+angle_difference(_view.x,yaw),clampf(polar,POLAR.x,POLAR.y),log(clampf(distance,DISTANCE.x,maxf(DISTANCE.y,distance))))
	_w_pivot = GLIDE
	_w_view = GLIDE
	_glide_time = 0.0
	_fling_view = Vector2.ZERO
	_fling_pan = Vector3.ZERO
	turn.stop()
	_hand()

func _remember() -> void:
	_history.append({"pivot":_pivot_goal,"view":_view_goal})
	if _history.size() > HISTORY: _history.pop_front()

## Frame what is under a screen point, or move the pivot to the ground there.
func focus_at(point: Vector2) -> bool:
	var found := inspector.inspect(point)
	if not found.is_empty():
		frame(found)
		return true
	var hit: Variant = inspector.ground_hit(point)
	if hit == null: return false
	recentre(hit)
	return true

## Frame a found thing (scene_inspector.gd) at a distance that fits it, from
## about where the camera already looks, turned only if the land hides it.
func frame(found: Dictionary) -> void:
	_remember()
	focus = found
	var size := float(found.get("size",1.0))
	var distance := clampf(size/tan(deg_to_rad(camera.fov)*0.5)*1.5,2.4,45.0)
	var polar := clampf(_view_goal.y,1.0,1.28)
	var yaw := _clear_yaw(found.point,_view_goal.x,polar,distance)
	glide_to(found.point,yaw,polar,distance)
	following = inspector.track(found) != null and str(found.kind) not in ["plant","pond"]
	var detail := str(found.get("detail",""))
	_show_label(str(found.title)+("  ·  "+detail if not detail.is_empty() else ""),found.point,4.5)
	_used.focus = true

## Move the pivot to a ground point, keeping the angle and distance.
func recentre(point: Vector3) -> void:
	_remember()
	focus = {}
	following = false
	glide_to(point+Vector3.UP*0.3,_view_goal.x,_view_goal.y,exp(_view_goal.z))
	_used.focus = true

## The first yaw near `yaw` from which the land does not hide `point`.
func _clear_yaw(point: Vector3, yaw: float, polar: float, distance: float) -> float:
	for turn: float in [0.0,0.45,-0.45,0.9,-0.9,1.4,-1.4,2.0,-2.0,PI]:
		var eye_at := point+offset(yaw+turn,polar)*distance
		var clear := true
		for i in range(1,9):
			var p := point.lerp(eye_at,0.12+0.88*i/8.0)
			var ground: Variant = inspector.ground_y(p)
			if ground != null and float(ground) > p.y-0.25:
				clear = false
				break
		if clear: return yaw+turn
	return yaw

## The overview, as a glide: the scene frames it, and the pose it lands on
## becomes the goal.
func overview() -> void:
	var saved := [scene.target,scene.yaw,scene.polar,scene.distance]
	scene._overview()
	var goal := [scene.target,scene.yaw,scene.polar,scene.distance]
	scene.target = saved[0]
	scene.yaw = saved[1]
	scene.polar = saved[2]
	scene.distance = saved[3]
	scene._update_camera()
	_remember()
	focus = {}
	following = false
	glide_to(goal[0],goal[1],goal[2],goal[3])

## Back to the view before the last focus, recentre or overview.
func back() -> bool:
	if _history.is_empty(): return false
	var before: Dictionary = _history.pop_back()
	focus = {}
	following = false
	glide_to(before.pivot,before.view.x,before.view.y,exp(before.view.z))
	return true

func _advance_follow(_delta: float) -> void:
	if not following: return
	var at: Variant = inspector.track(focus)
	if at == null:
		following = false
		return
	_pivot_goal = at
	if _glide_time > 0.9: _w_pivot = FOLLOW

# --- Input ----------------------------------------------------------------------------

## Drags the scene pooled this frame (right, Ctrl, Alt, off-land or Look
## drags orbit; middle drags pan) become goals, and a quick release flings.
## A mouse orbit's side-to-side is the world turn's (scripts/world_turn.gd);
## only its tilt is taken here.
func _take_scene_drags(delta: float) -> void:
	var orbit: Vector2 = scene._orbit_delta
	if turn.takes_orbit(): orbit.x = 0.0
	var pan: Vector2 = scene._pan_delta
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	var turned := orbit_pixels(orbit) if orbit != Vector2.ZERO else Vector2.ZERO
	var moved := pan_pixels(pan) if pan != Vector2.ZERO else Vector3.ZERO
	if orbit != Vector2.ZERO or pan != Vector2.ZERO: _fling_view = Vector2.ZERO
	if pan != Vector2.ZERO: _fling_pan = Vector3.ZERO
	if orbit != Vector2.ZERO: _used.orbit = true
	var dragging: bool = scene._orbiting or scene._panning
	if dragging:
		var k := 1.0-exp(-delta/0.05)
		_hand_view = _hand_view.lerp(turned/maxf(delta,0.001),k)
		_hand_pan = _hand_pan.lerp(moved/maxf(delta,0.001),k)
	elif _dragging:
		_fling_view = (_hand_view*FLING).limit_length(2.5)
		_fling_pan = _hand_pan*FLING
		_hand_view = Vector2.ZERO
		_hand_pan = Vector3.ZERO
	_dragging = dragging

func _advance_fling(delta: float) -> void:
	if _dragging: return
	if _fling_view.length() > 0.01:
		_view_goal.x += _fling_view.x*delta
		_view_goal.y = clampf(_view_goal.y+_fling_view.y*delta,POLAR.x,POLAR.y)
		_fling_view *= exp(-delta/FLING_DECAY)
	else: _fling_view = Vector2.ZERO
	if _fling_pan.length() > 0.01:
		_pan_world(_fling_pan*delta)
		_fling_pan *= exp(-delta/FLING_DECAY)
	else: _fling_pan = Vector3.ZERO

## Held arrows pan; with Shift they turn and tilt.
func _keys(delta: float) -> void:
	if scene.crafting or scene.get_viewport().gui_get_focus_owner() != null or not scene.get_window().has_focus(): return
	var move := Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_UP)))
	if move == Vector2.ZERO or Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT): return
	# In the chunk atlas plain arrows step between chunks (chunk_atlas_controller.gd).
	if scene.get("atlas") != null and not Input.is_key_pressed(KEY_SHIFT): return
	if Input.is_key_pressed(KEY_SHIFT):
		turn.stop()
		_view_goal.x += move.x*KEY_TURN*delta
		_view_goal.y = clampf(_view_goal.y-move.y*KEY_TURN*0.6*delta,POLAR.x,POLAR.y)
		_w_view = HAND
		_hand()
	else:
		pan_pixels(-move*KEY_PAN*_height()*delta)

func _world_pointer(point: Vector2) -> bool:
	return editor.pointer_in_world(point) and not contains_pointer(point)

## Something in the hand (a prop, a bent tree, Bigfoot) owns the pointer.
func _hands_full() -> bool:
	var play: Node = scene.get("world_play")
	if play != null and play.get("owner_scene") != null and (play._tree_drag or play.loose_props.grabbed != null): return true
	var resident: Object = scene.get("_resident_play")
	return resident != null and resident.scene != null and (resident.carrying or resident.hovered)

func _input(event: InputEvent) -> void:
	if live and handle(event): get_viewport().set_input_as_handled()

## The camera's pointer and gesture input. True when the event was used.
func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if not button.pressed or not _world_pointer(button.position) or _hands_full(): return false
			var notches := button.factor if button.factor > 0.0 else 1.0
			zoom_at(button.position,pow(WHEEL,minf(notches,4.0)*(-1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)))
			return true
		if button.button_index != MOUSE_BUTTON_LEFT: return false
		if not button.pressed:
			if not _press.is_empty(): _press.moved = maxf(float(_press.get("moved",0.0)),button.position.distance_to(_press.at))
			return false
		if not _world_pointer(button.position) or scene.crafting: return false
		# Ctrl-drag orbits (a Mac's one-button right drag).
		if button.ctrl_pressed and not button.meta_pressed:
			scene._orbiting = true
			return true
		if button.double_click and not _hands_full():
			_retract_click(button.position)
			return focus_at(button.position)
		_press = {"at":button.position,"time":Time.get_ticks_msec(),"creating":scene._creating(),"undo":editor.data._undo.back() if not editor.data._undo.is_empty() else null}
		return false
	if event is InputEventMouseMotion and not _press.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_press.moved = maxf(float(_press.get("moved",0.0)),event.position.distance_to(_press.at))
		return false
	if event is InputEventMagnifyGesture:
		if not _world_pointer(event.position): return false
		zoom_at(event.position,pow(1.0/maxf(event.factor,0.01),PINCH))
		return true
	if event is InputEventPanGesture:
		if not _world_pointer(event.position): return false
		var fingers: Vector2 = event.delta*SWIPE*SWIPE_SIGN
		if event.shift_pressed: pan_pixels(fingers)
		else:
			turn.stop()
			orbit_pixels(fingers)
			_used.orbit = true
		_fling_view = Vector2.ZERO
		return true
	return false

## A double-click's first click, with a brush in hand, laid a dab: take it
## back when it was a still click. A pour or a rising mountain keeps its undo
## step open after release, so the editor closes it first
## (NativeChunkEditor.retract_click).
func _retract_click(point: Vector2) -> void:
	if _press.is_empty() or not bool(_press.creating) or float(_press.get("moved",0.0)) > 6.0 or point.distance_to(_press.at) > 8.0: return
	if Time.get_ticks_msec()-int(_press.time) > 700: return
	editor.retract_click(_press.undo)
	_press = {}

func _unhandled_key_input(event: InputEvent) -> void:
	if not live or not event is InputEventKey or not event.pressed: return
	var key := event as InputEventKey
	if key.ctrl_pressed or key.meta_pressed or key.alt_pressed: return
	var used := true
	match key.keycode:
		KEY_R:
			if not key.echo: overview()
		KEY_F:
			if scene.crafting: used = false
			elif not key.echo: focus_at(scene.get_viewport().get_mouse_position())
		KEY_BACKSPACE, KEY_HOME:
			if scene.crafting: used = false
			elif not key.echo: back()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			used = not scene.crafting
		_: used = false
	if used: get_viewport().set_input_as_handled()

# --- Hover ------------------------------------------------------------------------------

func _hover(delta: float) -> void:
	var mouse := scene.get_viewport().get_mouse_position()
	_rest = 0.0 if mouse.distance_to(_mouse) > 1.5 else _rest+delta
	_mouse = mouse
	_hover_clock -= delta
	var painting: bool = editor.get("_painting") == true
	var allowed: bool = not scene.crafting and not scene._orbiting and not scene._panning and not painting \
		and not _hands_full() and _world_pointer(mouse)
	var wait := HOVER_LOOK if scene.looking else HOVER_BRUSH
	if not allowed or (not scene.looking and _rest < wait):
		# With a brush in hand the name clears as soon as the pointer moves on.
		hovered = {}
		_hover_key = []
	elif _rest >= wait or _hover_clock <= 0.0:
		var key := [mouse,camera.global_transform.origin.snapped(Vector3.ONE*0.02),Engine.get_frames_drawn()/12]
		if key != _hover_key and (_hover_clock <= 0.0 or _hover_key.is_empty()):
			_hover_key = key
			_hover_clock = 0.12
			var found := inspector.inspect(mouse)
			if found.is_empty() or hovered.is_empty() or found.title != hovered.title or found.point.distance_to(hovered.point) > 0.05: hovered = found
	var pointing: bool = scene.looking and not hovered.is_empty()
	if pointing:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		_cursor_owned = true
	elif _cursor_owned:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_cursor_owned = false
	# Used both ways: the hint has done its work.
	if not _hint_seen and _used.get("focus",false) and _used.get("orbit",false): dismiss_hint()
