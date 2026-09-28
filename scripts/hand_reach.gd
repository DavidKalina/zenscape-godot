extends Node
## The hand's reach (docs/scenic/hand-world.md, docs/scenic/hand-sun-rim.md):
## what the pointer is reaching for, and holding it. Where you reach is what
## you touch: the sun's disc in the sky (or the moon's, by night) and the rim
## of the diorama, the top edge of its earth block, belong to the hand; the
## land and empty space stay the camera's and the brushes'. A press on
## something the hand can hold is taken here, in `_input`, before the camera's
## orbit and the creation brushes see it.
##
## - **The sun.** Dragged along its arc it sets the hour: the disc follows the
##   pointer to the nearest point of its own arc, so a drag anywhere reads.
##   Let go and it drifts on a little, slowing. Then the hour is held (pinned
##   through scripts/mood_look.gd as a held hour, the way the old scrubber
##   pinned one), or on a day that was turning, the day turns on from there.
##   By night the moon rides the same ring, half a day round, and is held the
##   same way.
## - **The rim.** Dragged along the rim, round the diorama, it turns the
##   season: a full turn is a year, a side of the plate about a season, with
##   gentle detents at the four seasons (Living.SEASONS, mid-season values).
##   The season follows live through the world clock, so the leaves and the
##   snow line follow it; let go and it settles into the nearest detent, which
##   is pinned through mood_look as the drawer's Season would be.
##
## The mouse drives and the hand interprets: nothing here recognises a gesture.
## The hand (scripts/god_hand.gd) shows the hold, through its `reach_gesture`
## and `reach_point`; it may be absent (`--no-hand`) and the reach works the
## same. A hint line names what the pointer is near, until it has been used a
## couple of times.
##
## The rim's grab is shared with the snow-globe shake (another slice): it
## listens to `rim_dragged`, and when a shake fires it calls
## `revert_season_to_grab` so the dial goes back to where it was taken.

const Living = preload("res://scripts/living_weather.gd")

signal rim_grabbed(screen_pos: Vector2)
signal rim_dragged(screen_delta: Vector2, delta: float)
signal rim_released()
## The hand took hold of "sun" or "rim", or let go ("").
signal holding_changed(what: String)

## Half the plate's side, metres (the terrain is 28 m square, centred).
const PLATE_HALF := 14.0
## The sun's disc is small (about 2 degrees), so it is grabbed generously:
## within this many pixels of its centre, or this many degrees of it.
const SUN_PIXELS := 64.0
const SUN_DEGREES := 7.0
## A body this far under the horizon (the sine of its height) is not in reach.
const SUN_LOW := -0.05
## The rim is in reach within this many pixels of its outline on screen, over
## the land's border band RIM_BAND metres deep, or over the block's walls.
const RIM_PIXELS := 28.0
const RIM_BAND := 0.8
## Metres from the camera, along the ray to the sun, the hand holds it: about
## where the Reach clips' cup is the size of the disc on screen.
const SUN_REACH := 12.0
## Searching the arc for the pointer: phase either side of the current one,
## and the steps of the coarse and fine passes.
const ARC_WINDOW := 0.12
const ARC_STEP := 0.004
const ARC_FINE := 0.0004
## Letting the sun go: it drifts on at the speed it was dragged (phase per
## second, at most DRIFT_MAX, about 1.2 hours a second), slowing at
## DRIFT_FRICTION (1/s), and comes to rest under DRIFT_STOP.
const DRIFT_MAX := 0.05
const DRIFT_FRICTION := 2.6
const DRIFT_STOP := 0.0015
## How quickly (1/s) the drag's speed is read, for the drift.
const SPEED_READ := 14.0
## The season dial: quarters (seasons) a full turn of the rim, how strongly
## the dial sticks at each season's detent (0 none, under 1), and how quickly
## (1/s) it settles into the nearest detent once let go.
const QUARTERS_PER_TURN := 4.0
const DETENT := 0.6
const SETTLE := 7.0
const SETTLED := 0.002
## The hint line, and how many holds of a thing it takes to stop naming it.
const SUN_HINT := "Drag to grab the sun  ·  let go and it drifts"
const MOON_HINT := "Drag to grab the moon  ·  let go and it drifts"
const RIM_HINT := "Drag to turn the rim for the season"
const HINT_UNTIL := 2

var scene: Node3D
## What the pointer is over now ("sun", "rim" or ""), and what the hand holds.
var reaching := ""
var holding := ""
## Holding the sky: "sun" or "moon".
var body := "sun"
## The sun's speed along its arc (phase per second), read while it is dragged
## and carried on after a let-go, and whether it is drifting now.
var phase_speed := 0.0
var drifting := false
## The season dial, in quarters (0 spring's detent, 1 summer's...), unwrapped,
## and whether it is settling into a detent after a let-go.
var dial := 0.0
var settling := false
## What the rim's grab took: the dial, the clock's season override and the
## season pin, for `revert_season_to_grab`.
var grab_dial := 0.0
var grab_season_override := -1.0
var grab_season_pin := ""
## Where the hand works (plate coordinates), for scripts/god_hand.gd.
var reach_point: Variant = null
## Times each thing has been held, for the hint.
var uses := {"sun":0,"rim":0}
var _offset := Vector2.ZERO
var _last_phase := 0.0
var _turning := false
var _rim_angle: Variant = null
var _hint := ""
var _cursor_owned := false
var _block_low: Variant = null
var _hover_key := []
var _land_cache := {}
var _land_frame := -1
## A shake undid this hold's turn: the let-go leaves the season as it was.
var _reverted := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "HandReach"
	# Last among the scene's children, so its `_input` comes before theirs.
	scene.move_child.call_deferred(self,-1)

# --- What the pointer reaches --------------------------------------------------

func _editor() -> Node:
	return scene.get("_chunk_editor")

func _mood() -> Node:
	return scene.get("mood_look")

## True when the hand may reach at all: a world is open and nothing else owns
## the pointer (a menu, Craft, a regrowth, a forming world, a stroke).
func available() -> bool:
	var editor := _editor()
	if editor == null or scene.camera == null or editor.forming: return false
	if scene.get("crafting") == true: return false
	if scene.get("_has_world") == false: return false
	var photo: Node = scene.get("photo")
	if photo != null and photo.get("active") == true: return false
	var mood := _mood()
	if mood != null and mood.busy(): return false
	return not (editor.get("_painting") == true or editor.get("_ball_holding") == true)

## What a pointer at `point` reaches: "sun", "rim" or "". The sky's body
## wins where both are near; land under the pointer (but for its border band)
## is the camera's.
func reach_at(point: Vector2) -> String:
	var editor := _editor()
	if not editor.pointer_in_world(point): return ""
	if not _body_at(point).is_empty(): return "sun"
	if _rim_at(point) != null: return "rim"
	return ""

## The body ("sun" or "moon") whose disc is within grabbing reach of `point`,
## the nearer if both; "" when neither.
func _body_at(point: Vector2) -> String:
	var best := ""
	var gap := INF
	for which in ["sun","moon"]:
		var direction := body_direction(which,float(scene._celestial.phase))
		if direction.y < SUN_LOW: continue
		var at: Variant = _screen(direction)
		if at == null: continue
		var pixels: float = point.distance_to(at)
		var ray: Vector3 = scene.camera.project_ray_normal(point)
		if pixels > SUN_PIXELS and rad_to_deg(ray.angle_to(direction)) > SUN_DEGREES: continue
		# A disc behind the land is hidden by it: the land is the camera's.
		if pixels > SUN_PIXELS*0.5 and _land(point) != null: continue
		if pixels < gap:
			gap = pixels
			best = which
	return best

## The sun's or the moon's direction at a phase, as studies/celestial.gd
## rings them: the moon half a day round, on a flatter ring.
func body_direction(which: String, at_phase: float) -> Vector3:
	var celestial: RefCounted = scene._celestial
	var theta := (at_phase-0.25)*TAU
	if which == "moon": return celestial._ring_direction(theta+PI,celestial._tilt*0.75)
	return celestial._ring_direction(theta,celestial._tilt)

## Where a sky direction is on screen, or null behind the camera.
func _screen(direction: Vector3) -> Variant:
	var camera: Camera3D = scene.camera
	var far := camera.global_position+direction*400.0
	if camera.is_position_behind(far): return null
	return camera.unproject_position(far)

## The rim point (plate coordinates) a pointer at `point` reaches, or null.
## Found on the plane of the rim's height, the block's walls and the rim's
## outline on screen, which are cheap; only a candidate asks the land (a
## ray into the terrain, about a millisecond) whether a hill stands in front.
func _rim_at(point: Vector2) -> Variant:
	var rim: Variant = null
	var at: Variant = _plate_at(point)
	if at != null and absf(at.x) <= PLATE_HALF and absf(at.z) <= PLATE_HALF:
		if maxf(absf(at.x),absf(at.z)) < PLATE_HALF-RIM_BAND: return null
		rim = _edge(Vector2(at.x,at.z))
	else:
		rim = _wall_hit(point)
		if rim == null:
			var near: Array = _outline_nearest(point)
			if float(near[0]) > RIM_PIXELS: return null
			rim = near[1]
	var hit: Variant = _land(point)
	if hit != null and maxf(absf(hit.x),absf(hit.z)) < PLATE_HALF-RIM_BAND: return null
	return rim

## The rim point nearest the pointer, wherever it is: for a drag, which may
## wander off the rim. Cheap: no ray into the terrain.
func rim_point(point: Vector2) -> Vector3:
	var at: Variant = _plate_at(point)
	if at != null and absf(at.x) <= PLATE_HALF and absf(at.z) <= PLATE_HALF: return _edge(Vector2(at.x,at.z))
	var wall: Variant = _wall_hit(point)
	if wall != null: return wall
	return _outline_nearest(point)[1]

## Where the pointer's ray meets the plane of the rim's height near it (plate
## coordinates), or null when it looks up.
func _plate_at(point: Vector2) -> Variant:
	var terrain: Node3D = _editor().terrain
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(point)).normalized()
	if direction.y > -0.001: return null
	var at := origin+direction*(-origin.y/direction.y)
	var height := _edge(Vector2(at.x,at.z)).y
	return origin+direction*((height-origin.y)/direction.y)

## The land under a pointer (NativeChunkEditor.pick), once a frame per point;
## the editor's own hit when it has read this pointer already.
func _land(point: Vector2) -> Variant:
	var editor := _editor()
	var frame := Engine.get_process_frames()
	if frame != _land_frame:
		_land_frame = frame
		_land_cache.clear()
	if not _land_cache.has(point):
		var mouse := scene.get_viewport().get_mouse_position()
		var read: bool = editor.active and not scene.get("_orbiting") == true and point.distance_to(mouse) < 0.5
		_land_cache[point] = editor.pointer_hit if read else editor.pick(point)
	return _land_cache[point]

## The rim point nearest a plate position: on the nearer edge, at the land's height there.
func _edge(p: Vector2) -> Vector3:
	var edge := p.clamp(Vector2.ONE*-PLATE_HALF,Vector2.ONE*PLATE_HALF)
	if absf(edge.x) >= absf(edge.y): edge.x = signf(edge.x)*PLATE_HALF if edge.x != 0.0 else PLATE_HALF
	else: edge.y = signf(edge.y)*PLATE_HALF
	return Vector3(edge.x,_rim_height(edge),edge.y)

func _rim_height(edge: Vector2) -> float:
	var inside := edge.clamp(Vector2.ONE*-(PLATE_HALF-0.02),Vector2.ONE*(PLATE_HALF-0.02))
	var h: Variant = _editor().data.ground_height(inside)
	return float(h) if h != null else 0.0

## The block's walls: where the pointer's ray meets one, between the block's
## foot and the rim over it.
func _wall_hit(point: Vector2) -> Variant:
	var editor := _editor()
	var terrain: Node3D = editor.terrain
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(point)).normalized()
	var low := _foot()
	var best: Variant = null
	var nearest := INF
	for axis in [0,2]:
		if absf(direction[axis]) < 1e-5: continue
		for side in [-1.0,1.0]:
			var t: float = (side*PLATE_HALF-origin[axis])/direction[axis]
			if t <= 0.0 or t >= nearest: continue
			var at: Vector3 = origin+direction*t
			var across := at.z if axis == 0 else at.x
			if absf(across) > PLATE_HALF: continue
			var edge := Vector2(at.x,at.z)
			var top := _rim_height(edge)
			if at.y < low or at.y > top+0.3: continue
			nearest = t
			best = Vector3(edge.x,top,edge.y)
	return best

## The foot of the earth block, plate coordinates (the skirt mesh's lowest point).
func _foot() -> float:
	if _block_low == null:
		_block_low = -6.0
		var editor := _editor()
		var skirt: MeshInstance3D = editor.get("_skirt")
		if skirt != null and skirt.mesh != null:
			var box := skirt.mesh.get_aabb()
			_block_low = editor.terrain.to_local(skirt.to_global(box.position)).y
	return float(_block_low)

## [pixels, rim point] for the rim's outline sample nearest `point` on screen.
func _outline_nearest(point: Vector2) -> Array:
	var camera: Camera3D = scene.camera
	var terrain: Node3D = _editor().terrain
	var best := [INF,Vector3.ZERO]
	var steps := 24
	for side in range(4):
		for i in range(steps):
			var f := -PLATE_HALF+2.0*PLATE_HALF*(i+0.5)/steps
			var edge: Vector2 = [Vector2(f,-PLATE_HALF),Vector2(PLATE_HALF,f),Vector2(-f,PLATE_HALF),Vector2(-PLATE_HALF,-f)][side]
			var local := Vector3(edge.x,_rim_height(edge),edge.y)
			var world := terrain.to_global(local)
			if camera.is_position_behind(world): continue
			var pixels := point.distance_to(camera.unproject_position(world))
			if pixels < float(best[0]): best = [pixels,local]
	return best

# --- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle(event): get_viewport().set_input_as_handled()

## The pointer's events. True when the event was the hand's.
func handle(event: InputEvent) -> bool:
	if scene == null or not scene.is_node_ready(): return false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT: return false
		if button.pressed:
			if not holding.is_empty() or not available() or button.ctrl_pressed or button.double_click: return false
			var what := reach_at(button.position)
			if what.is_empty(): return false
			grab(what,button.position)
			return true
		if holding.is_empty(): return false
		release()
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if holding.is_empty(): return false
		drag(motion.position,motion.relative)
		return true
	return false

## Take hold of `what` ("sun" or "rim") with the pointer at `point`.
func grab(what: String, point: Vector2) -> void:
	holding = what
	drifting = false
	settling = false
	_reverted = false
	uses[what] = int(uses.get(what,0))+1
	var mood := _mood()
	if mood != null: mood.finish_fade()
	var clock: WorldClock = scene.world_clock
	if what == "sun":
		body = _body_at(point)
		if body.is_empty(): body = "sun"
		var at: Variant = _screen(body_direction(body,float(scene._celestial.phase)))
		_offset = (at-point) if at != null else Vector2.ZERO
		_turning = clock.running
		clock.running = false
		_last_phase = float(scene._celestial.phase)
		phase_speed = 0.0
	else:
		dial = dial_for_season(clock.season)
		grab_dial = dial
		grab_season_override = clock.season_override
		grab_season_pin = str(mood.pins.get("season","")) if mood != null else ""
		reach_point = rim_point(point)
		_rim_angle = _angle_round(point)
		rim_grabbed.emit(point)
	_set_cursor(Input.CURSOR_DRAG)
	_show_hint("")
	holding_changed.emit(what)

func drag(point: Vector2, relative: Vector2) -> void:
	if holding == "sun":
		var phase := arc_phase(point+_offset,float(scene._celestial.phase))
		scene._celestial.set_phase(phase)
	elif holding == "rim":
		var angle: Variant = _angle_round(point)
		if angle != null and _rim_angle != null:
			turn_dial(angle_difference(float(_rim_angle),float(angle))/TAU*QUARTERS_PER_TURN)
		_rim_angle = angle
		reach_point = rim_point(point)
		rim_dragged.emit(relative,get_process_delta_time())

## Let go of what the hand holds.
func release() -> void:
	var what := holding
	holding = ""
	_set_cursor(Input.CURSOR_ARROW)
	if what == "sun":
		drifting = true
		phase_speed = clampf(phase_speed,-DRIFT_MAX,DRIFT_MAX)
	elif what == "rim":
		settling = not _reverted
		rim_released.emit()
	holding_changed.emit("")

## A hold ends if the window loses the pointer mid-drag, as a release would.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not holding.is_empty(): release()

# --- The sun ------------------------------------------------------------------

## The phase near `from` whose body lands nearest `target` on screen: a coarse
## pass over ARC_WINDOW either side, then a fine one round the best.
func arc_phase(target: Vector2, from: float) -> float:
	var best := from
	var gap := _arc_gap(target,from)
	var span := ARC_WINDOW
	for step: float in [ARC_STEP,ARC_FINE]:
		var centre := best
		var count := int(span/step)
		for i in range(-count,count+1):
			var candidate: float = centre+i*step
			var d := _arc_gap(target,candidate)
			if d < gap:
				gap = d
				best = candidate
		span = ARC_STEP*1.5
	return fposmod(best,1.0)

func _arc_gap(target: Vector2, at_phase: float) -> float:
	var at: Variant = _screen(body_direction(body,at_phase))
	return INF if at == null else target.distance_squared_to(at)

# --- The season dial ------------------------------------------------------------

## The pointer's angle round the plate's middle, seen from above (radians,
## growing as the rim turns anticlockwise, which is the near rim pushed to the
## right): where its ray meets the rim's height, else round the plate's middle
## on screen.
func _angle_round(point: Vector2) -> Variant:
	var editor := _editor()
	var terrain: Node3D = editor.terrain
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(point)).normalized()
	var height: float = reach_point.y if reach_point != null else 0.0
	if direction.y < -0.02:
		var at := origin+direction*((height-origin.y)/direction.y)
		if Vector2(at.x,at.z).length() > 0.5: return atan2(at.x,at.z)
	var middle := camera.unproject_position(terrain.to_global(Vector3(0,height,0)))
	var away := point-middle
	if away.length() < 4.0: return null
	return -atan2(away.y,away.x)

## Turn the dial by `quarters` (a season is 1).
func turn_dial(quarters: float) -> void:
	dial += quarters
	_apply_dial()

## The season value (0..1, the world clock's) a dial position shows: the
## detents stick (DETENT), and between them the value runs piecewise between
## Living weather's mid-season values.
static func season_for_dial(value: float) -> float:
	var shaped := value-DETENT*sin(TAU*value)/TAU
	var q := fposmod(shaped,4.0)
	var i := int(floor(q))%4
	var seasons: Array = Living.SEASONS
	var a := float(seasons[i])
	var b := float(seasons[(i+1)%4])+(1.0 if i == 3 else 0.0)
	return fposmod(lerpf(a,b,q-floor(q)),1.0)

## The dial position (in [0, 4)) that shows a season value.
static func dial_for_season(season: float) -> float:
	var seasons: Array = Living.SEASONS
	var s := fposmod(season,1.0)
	if s < float(seasons[0]): s += 1.0
	var q := 3.0+(s-float(seasons[3]))/(float(seasons[0])+1.0-float(seasons[3]))
	for i in range(3):
		if s < float(seasons[i+1]):
			q = i+(s-float(seasons[i]))/(float(seasons[i+1])-float(seasons[i]))
			break
	# Undo the detents' shaping: solve u - DETENT sin(2πu)/2π = q.
	var u := q
	for _i in range(8): u -= (u-DETENT*sin(TAU*u)/TAU-q)/(1.0-DETENT*cos(TAU*u))
	return u

## The season id ("spring"...) of a dial position's nearest detent.
static func season_id(value: float) -> String:
	return str(WorldClock.SEASON_NAMES[posmod(roundi(value),4)])

func _apply_dial() -> void:
	var clock: WorldClock = scene.world_clock
	clock.season_override = season_for_dial(dial)
	# The shown season follows at once: no glide behind the hand.
	scene._season_shown = clock.season

## A shake (the snow-globe slice) undoes the turn: the dial goes back to where
## the rim was taken, and a settle in progress stops. After the let-go it
## puts the season pin back as it was too.
func revert_season_to_grab() -> void:
	settling = false
	_reverted = not holding.is_empty()
	dial = grab_dial
	var clock: WorldClock = scene.world_clock
	clock.season_override = grab_season_override
	scene._season_shown = clock.season
	var mood := _mood()
	if mood == null or not holding.is_empty(): return
	var pinned := str(mood.pins.get("season",""))
	if pinned == grab_season_pin: return
	if grab_season_pin.is_empty(): mood.unpin("season")
	else: mood.pin("season",grab_season_pin)

# --- Frames ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if scene == null or scene.camera == null or _editor() == null: return
	delta = minf(delta,0.1)
	var phase := float(scene._celestial.phase)
	if holding == "sun":
		var moved := angle_difference(_last_phase*TAU,phase*TAU)/TAU
		phase_speed = lerpf(phase_speed,moved/maxf(delta,0.001),1.0-exp(-SPEED_READ*delta))
		_last_phase = phase
	elif drifting:
		phase_speed *= exp(-DRIFT_FRICTION*delta)
		scene._celestial.set_phase(phase+phase_speed*delta)
		if absf(phase_speed) < DRIFT_STOP: _rest_sun()
	if settling:
		var goal := roundf(dial)
		dial = lerpf(dial,goal,1.0-exp(-SETTLE*delta))
		if absf(dial-goal) < SETTLED:
			dial = goal
			settling = false
			_apply_dial()
			_rest_season()
		else:
			_apply_dial()
	_drive_hand()
	if holding.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_hover(scene.get_viewport().get_mouse_position())

## The sun has come to rest: the hour is held, or a day that was turning turns on.
func _rest_sun() -> void:
	drifting = false
	phase_speed = 0.0
	var phase := float(scene._celestial.phase)
	var mood := _mood()
	if _turning:
		scene.world_clock.running = true
	elif mood != null:
		mood.pin_hour(phase)
	else:
		scene._celestial.set_phase(phase)

## The dial has settled into a detent: pin that season, as the drawer would.
func _rest_season() -> void:
	var mood := _mood()
	if mood == null: return
	var id := season_id(dial)
	if mood.value("season") != id or not mood.pinned("season"): mood.pin("season",id)

## The hand shows the hold: it cups the sun SUN_REACH out along the ray to
## it, or grips the rim under the pointer.
func _drive_hand() -> void:
	var hand: Node3D = scene.get("god_hand")
	if holding == "sun":
		var direction := body_direction(body,float(scene._celestial.phase))
		reach_point = _editor().terrain.to_local(scene.camera.global_position+direction*SUN_REACH)
	elif holding.is_empty():
		reach_point = null
	if hand == null: return
	hand.reach_gesture = holding
	hand.reach_point = reach_point

# --- Hover and hint --------------------------------------------------------------

func _hover(point: Vector2) -> void:
	# Only when the pointer or the camera has moved.
	var key := [point,scene.camera.global_transform,snappedf(float(scene._celestial.phase),0.0005)]
	if key == _hover_key: return
	_hover_key = key
	var what := reach_at(point) if available() else ""
	if what == "sun" and _body_at(point) == "moon": what = "moon"
	reaching = "sun" if what == "moon" else what
	_set_cursor(Input.CURSOR_POINTING_HAND if not what.is_empty() else Input.CURSOR_ARROW)
	var text := ""
	if not what.is_empty() and int(uses.get(reaching,0)) < HINT_UNTIL:
		text = {"sun":SUN_HINT,"moon":MOON_HINT,"rim":RIM_HINT}[what]
	_show_hint(text)

## The hint line: the Lantern shell's (`reach_hint`); the glass palette's
## status line otherwise.
func _show_hint(text: String) -> void:
	if text == _hint: return
	_hint = text
	var shell: Node = scene.get("creation_palette")
	if shell != null and shell.has_method("reach_hint"): shell.reach_hint(text)
	elif not text.is_empty() and _editor() != null: _editor()._set_status(text)

func _set_cursor(shape: Input.CursorShape) -> void:
	if shape == Input.CURSOR_ARROW:
		if not _cursor_owned: return
		_cursor_owned = false
	else:
		_cursor_owned = true
	Input.set_default_cursor_shape(shape)
