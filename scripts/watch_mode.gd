extends Node
## Watch mode (docs/scenic/watch.md): put the tools down and just look. O hides
## every piece of chrome and hands the camera to a slow director, which keeps
## choosing shots the way a nature film would:
##
## - "orbit": the whole plate from the overview, turning slowly, easing in a
##   little. Always the first shot, and back every few shots.
## - "drift": a place worth looking at (a grove, a pond, the cabin, a
##   summit, lamps and the fire at night), dollying in slowly while it turns.
## - "skim": low across the land, side-lit or against the sun at golden hour.
## - "follow": a deer, the heron or a bird, loosely, until it goes.
##
## The director moves a mark (a pivot, yaw, polar and log distance) along each
## shot. The camera trails the mark on two chained critically damped springs,
## so a move between shots starts and ends at rest and nothing ever jerks. The
## pose is written into the scene's own orbit, as photo mode does, so the fog,
## reflections and look pass read the same camera they always have. The room
## is not turned: the sun stays where it is in the world, so the light comes
## round as the camera does.
##
## Moving the pointer shows a faint line saying how to come back; a still
## pointer hides itself and the line. O, Esc or a click comes back, and the
## camera stays where the watch left it. `--watch` opens a world in watch mode.
const Inspector = preload("res://scripts/scene_inspector.gd")
const Glass = preload("res://scripts/glass_chrome.gd")
const Rig = preload("res://scripts/camera_rig.gd")
## The camera trails the mark on two chained springs of SETTLE 1/s: a move
## between shots covers 95 % in about 10 s, and within a shot the camera lags
## the mark softly.
const SETTLE := 0.62
## The most the picture may change per second while moving between shots
## (see `_limit_pace`).
const PACE := 0.24
## Seconds a shot lasts; a followed creature may end its shot sooner.
const SHOT := Vector2(16.0,26.0)
const POLAR := Vector2(0.5,1.4)
## Shot distances; the far one grows with an island bigger than the old
## square (scripts/island_frame.gd `scale`).
const DISTANCE := Vector2(3.0,90.0)
## The camera stays this far above the ground under it: the director plans
## shots with CLEARANCE to spare, the mark and the pose's lift keep LIFT_MARGIN
## (the lift on its own spring of LIFT_W 1/s, looking LOOK_AHEAD seconds along
## the camera's way), and FLOOR is a hard floor.
const CLEARANCE := 0.9
const LIFT_MARGIN := 2.0
const LIFT_W := 3.0
const LOOK_AHEAD := 0.7
const FLOOR := 0.35
## Yaw drift, radians per second (a full turn in 2 to 4 minutes).
const DRIFT := Vector2(0.025,0.05)
## The distance breathes by this much (log) over BREATH seconds.
const BREATH := 0.045
const BREATH_TIME := 23.0
## Lenses by shot: the overview's own 45°, closer shots a little longer.
const FOV := {"orbit":45.0,"drift":36.0,"skim":40.0,"follow":34.0}
## Objects are counted on a grid of CELL terrain units to find groves.
const CELL := 3.5
## A place seen in the last RECENT shots is not chosen again.
const RECENT := 3
const POINTER_IDLE := 2.5
const HINT := "Watching  ·  O, Esc or a click to come back"
const PAD_HINTS := {HINT:"Watching  ·  any button to come back"}
## Built and rare things worth a look, by weight; LIT ones count more at night.
const SPECIAL := {"cabin":3.0,"campfire":3.0,"waterfall":3.0,"bridge":2.0,"arch":2.0,"bigfoot_tree":2.0,"stone_lamp":1.2,"redwood":1.2,"willow":1.2,"sunflower":0.8,"wheat":0.6}
const LIT := ["cabin","campfire","stone_lamp"]
const TREES := ["tree","broadleaf","layered_tree","redwood","birch","willow","juniper"]
const FOLLOWED := {"deer":1.6,"heron":1.6,"bird":1.0}

const IslandFrame = preload("res://scripts/island_frame.gd")

signal entered
signal left

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
var inspector := Inspector.new()
var active := false
## The shot under way: {kind, t, length, pivot, yaw, rate, polar (from, to),
## distance (log, from, to), fov, place}; a followed creature also has `found`.
var shot := {}
## Kinds of shot taken so far this watch, in order.
var taken: Array[String] = []
var _recent: Array[Vector3] = []
var _places: Array[Dictionary] = []
var _overview_pose := {}
var _turn_sign := 1.0
var _rng := RandomNumberGenerator.new()
var _before := {}
var _hidden: Array[CanvasLayer] = []
var _pending := false
# The mark after the first spring, and the pose after the second.
var _pivot_mid := Vector3.ZERO
var _pivot_mid_v := Vector3.ZERO
var _view_mid := Vector3.ZERO
var _view_mid_v := Vector3.ZERO
var _pivot := Vector3.ZERO
var _pivot_v := Vector3.ZERO
var _view := Vector3.ZERO
var _view_v := Vector3.ZERO
## Radians the pose's polar is lifted to clear a bank, and its rate.
var _lift := 0.0
var _lift_v := 0.0
var _fov := 45.0
var _fov_home := 45.0
var _fov_back := 0.0
var _clock := 0.0
# Chrome: one faint line, shown while the pointer moves.
var layer := CanvasLayer.new()
var hint: Label = preload("res://scripts/pad_prompt.gd").new()
var _still := 0.0
var _pointer_hidden := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	name = "WatchMode"
	# Before the scene, as photo mode: the scene places the camera from this pose.
	process_priority = -10
	inspector.setup(scene)
	_rng.randomize()
	layer.name = "WatchChrome"
	layer.layer = 4
	layer.visible = false
	add_child(layer)
	hint.text = HINT
	hint.alternates = PAD_HINTS
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color(Glass.INK,0.85))
	hint.add_theme_color_override("font_shadow_color",Color("182628",0.85))
	hint.add_theme_constant_override("shadow_offset_y",1)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate.a = 0.0
	layer.add_child(hint)
	_pending = "--watch" in preload("res://scripts/launch_args.gd").user_args()

# --- Entering and leaving -------------------------------------------------------

func can_enter() -> bool:
	if active or scene == null or not scene.get("shell_ready") or not scene._has_world: return false
	if scene._menu.visible or scene.crafting or editor.forming: return false
	if scene.get("titled") == true: return false
	for other: String in ["photo","wanderer"]:
		var node: Node = scene.get(other)
		if node != null and (node.active or float(node.get("_returning")) > 0.0): return false
	var places: Node = scene.get("places")
	return places == null or not places.busy

func enter() -> void:
	if not can_enter(): return
	_pending = false
	_before = {"looking":scene.looking,"auto":scene._auto_orbit,"mouse":Input.mouse_mode}
	if _fov_back <= 0.0: _fov_home = camera.fov
	_fov_back = 0.0
	# The brush goes away, as in photo mode.
	if not scene.looking:
		scene._set_looking_state(true)
		editor.set_active(false)
		scene._sync_creation_ui()
	active = true
	scene._orbiting = false
	scene._panning = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	scene._auto_orbit = false
	_pivot = scene.target
	_view = Vector3(scene.yaw,scene.polar,log(maxf(scene.distance,0.01)))
	_pivot_mid = _pivot
	_view_mid = _view
	_pivot_v = Vector3.ZERO
	_view_v = Vector3.ZERO
	_pivot_mid_v = Vector3.ZERO
	_view_mid_v = Vector3.ZERO
	_lift = 0.0
	_lift_v = 0.0
	_fov = camera.fov
	_clock = 0.0
	taken.clear()
	_recent.clear()
	_turn_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_overview_pose = _measure_overview()
	_places = gather_places()
	_begin(_orbit_shot())
	_hide_chrome()
	layer.visible = true
	_still = 0.0
	hint.modulate.a = 1.0
	entered.emit()

func leave() -> void:
	if not active: return
	active = false
	shot = {}
	layer.visible = false
	_show_chrome()
	if _pointer_hidden: Input.mouse_mode = int(_before.get("mouse",Input.MOUSE_MODE_VISIBLE))
	_pointer_hidden = false
	if not bool(_before.looking): scene.select_brush(scene.brush)
	scene._auto_orbit = bool(_before.auto)
	# The camera stays where the watch left it; the lens eases home.
	_fov_back = 0.6
	left.emit()

func toggle() -> void:
	if active: leave()
	else: enter()

## Every CanvasLayer at layer 1 or above is chrome (photo_mode.gd `_hide_chrome`).
func _hide_chrome() -> void:
	for node in scene.get_tree().root.find_children("*","CanvasLayer",true,false):
		var canvas := node as CanvasLayer
		if canvas == layer or canvas.layer < 1 or not canvas.visible: continue
		canvas.visible = false
		_hidden.append(canvas)

func _show_chrome() -> void:
	for canvas in _hidden:
		if is_instance_valid(canvas): canvas.visible = true
	_hidden.clear()

## True while every piece of chrome but the watch's own line is hidden.
func chrome_hidden() -> bool:
	for node in scene.get_tree().root.find_children("*","CanvasLayer",true,false):
		var canvas := node as CanvasLayer
		if canvas != layer and canvas.layer >= 1 and canvas.visible: return false
	return true

# --- What is worth a look ---------------------------------------------------------

## The overview's pose, as the scene frames it, without moving the camera.
func _measure_overview() -> Dictionary:
	var saved := [scene.target,scene.yaw,scene.polar,scene.distance]
	scene._overview()
	var pose := {"pivot":scene.target,"polar":scene.polar,"distance":scene.distance}
	scene.target = saved[0]
	scene.yaw = saved[1]
	scene.polar = saved[2]
	scene.distance = saved[3]
	scene._update_camera()
	return pose

## Places on the plate worth a drift or a skim: {point (global), size (m),
## kind, weight}. Groves come from one pass over the objects on a coarse grid;
## built and rare things, ponds and a summit are added on their own.
func gather_places() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var data := editor.data
	var terrain := editor.terrain
	var scale := terrain.global_basis.get_scale().x
	var night := _night()
	var cells := {}
	for item: Dictionary in data.objects:
		var asset := str(item.asset)
		var at := Vector2(float(item.x),float(item.z))
		var key := Vector2i((at/CELL).floor())
		var cell: Dictionary = cells.get(key,{})
		if cell.is_empty():
			cell = {"count":0,"trees":0,"sum":Vector2.ZERO}
			cells[key] = cell
		cell.count += 1
		cell.sum += at
		if asset in TREES: cell.trees += 1
		if SPECIAL.has(asset):
			var weight: float = SPECIAL[asset]*(3.0 if night and asset in LIT else 1.0)
			found.append({"point":terrain.to_global(data.object_position(item)+Vector3.UP*0.8),"size":3.0,"kind":asset,"weight":weight})
	for key: Vector2i in cells:
		var cell: Dictionary = cells[key]
		if cell.count < 4: continue
		var at: Vector2 = cell.sum/float(cell.count)
		var point := terrain.to_global(Vector3(at.x,data.ground_height(at)+1.0,at.y))
		var weight := sqrt(float(cell.count))*0.35+float(cell.trees)*0.25
		found.append({"point":point,"size":CELL*scale*1.4,"kind":"grove" if cell.trees >= 3 else "meadow","weight":weight*(0.4 if night else 1.0)})
	for i in range(data.ponds.size()):
		var pond: Dictionary = data.ponds[i]
		var point := terrain.to_global(Vector3(float(pond.x),float(pond.level),float(pond.z)))
		found.append({"point":point,"size":clampf(inspector.pond_size(i),1.5,10.0),"kind":"pond","weight":2.5})
	var summit := _summit()
	if not summit.is_empty(): found.append(summit)
	return found

## The highest point, when it stands well above the land around it: read on
## a grid over the island's land (scripts/island_frame.gd), not the plate.
func _summit() -> Dictionary:
	var area := IslandFrame.reach(editor.data,0.5,0.85)
	var best := Vector3.ZERO
	var total := 0.0
	var count := 0
	var best_y := -INF
	for i in range(13):
		for j in range(13):
			var local := Vector3(lerpf(area.position.x,area.end.x,i/12.0),0.0,lerpf(area.position.y,area.end.y,j/12.0))
			var y: Variant = inspector.ground_y(editor.terrain.to_global(local))
			if y == null: continue
			total += float(y)
			count += 1
			if float(y) > best_y:
				best_y = float(y)
				best = editor.terrain.to_global(local)
	if count == 0 or best_y-total/count < 3.0: return {}
	best.y = best_y+0.8
	return {"point":best,"size":5.0,"kind":"summit","weight":1.5}

func _night() -> bool:
	var clock: Object = scene.get("world_clock")
	return clock != null and float(clock.daylight) < 0.2

## Golden hour or the afterglow: the sun is low and still lighting the land.
func _low_sun() -> bool:
	var sun := _sun()
	return sun.y > -0.03 and sun.y < 0.26

func _sun() -> Vector3:
	var sky: Object = scene.get("_celestial")
	if sky == null: return Vector3.UP
	return sky.state.get("zs_sun_direction",Vector3.UP)

# --- Shots ------------------------------------------------------------------------

## The next shot: never the same kind twice running (unless nothing else is
## there), back to the orbit every few shots, a place not seen lately.
func next_shot() -> Dictionary:
	var since_orbit := 0
	for i in range(taken.size()-1,-1,-1):
		if taken[i] == "orbit": break
		since_orbit += 1
	var last: String = taken.back() if not taken.is_empty() else ""
	var night := _night()
	var weights := {
		"orbit":0.6+0.5*since_orbit,
		"drift":2.0 if not _places.is_empty() else 0.0,
		"skim":(2.2 if _low_sun() else 0.9) * (0.0 if night else 1.0) * (1.0 if not _places.is_empty() else 0.0),
		"follow":1.4 if not _followable().is_empty() else 0.0,
	}
	if weights.has(last) and weights.values().filter(func(w: float) -> bool: return w > 0.0).size() > 1: weights[last] = 0.0
	var kind := str(_pick_weighted(weights))
	var made := {}
	match kind:
		"drift": made = _place_shot(false)
		"skim": made = _place_shot(true)
		"follow": made = _follow_shot()
	return made if not made.is_empty() else _orbit_shot()

func _begin(next: Dictionary) -> void:
	shot = next
	taken.append(str(shot.kind))
	if shot.has("place"):
		_recent.append(shot.pivot)
		if _recent.size() > RECENT: _recent.pop_front()
	# Now and then the turn goes the other way.
	if _rng.randf() < 0.25: _turn_sign = -_turn_sign

func _orbit_shot() -> Dictionary:
	var pose := _overview_pose
	var d := float(pose.distance)
	var polar := clampf(float(pose.polar)+_rng.randf_range(-0.05,0.12),POLAR.x,POLAR.y)
	return _shot("orbit",pose.pivot,_view.x+_rng.randf_range(-0.3,0.3),_rng.randf_range(DRIFT.x,DRIFT.y)*1.3,
		Vector2(polar,polar+_rng.randf_range(-0.06,0.04)),Vector2(d*1.06,d*_rng.randf_range(0.86,0.95)))

## A drift (closer, dollying in) or a skim (low, across the land) on a place.
func _place_shot(skim: bool) -> Dictionary:
	var place := _pick_place(skim)
	if place.is_empty(): return {}
	var size := float(place.size)
	var fit := size/tan(deg_to_rad(FOV.drift)*0.5)
	var distance: Vector2
	var polar: Vector2
	var yaw := _view.x+_rng.randf_range(-0.7,0.7)
	if skim:
		var d := clampf(fit*2.4,10.0,24.0)
		distance = Vector2(d,d*0.88)
		var low := _rng.randf_range(1.28,1.36)
		polar = Vector2(low,low-0.04)
		if _low_sun():
			# Look across the low sun: side-lit, now and then against it.
			var sun := _sun()
			var toward := atan2(-sun.x,-sun.z)
			var off := _rng.randf_range(0.35,0.9)*(-1.0 if _rng.randf() < 0.5 else 1.0)
			yaw = _view.x+angle_difference(_view.x,toward+off)
	else:
		var d := clampf(fit*1.6,6.0,32.0)
		distance = Vector2(d,d*_rng.randf_range(0.66,0.78))
		var tilt := _rng.randf_range(1.0,1.22)
		polar = Vector2(tilt,tilt+0.06)
	var made := _shot("skim" if skim else "drift",place.point,yaw,_rng.randf_range(DRIFT.x,DRIFT.y)*(0.6 if skim else 1.0),polar,distance)
	made.place = str(place.kind)
	_clear_view(made)
	return made

func _follow_shot() -> Dictionary:
	var choices := _followable()
	if choices.is_empty(): return {}
	var weights := {}
	for i in range(choices.size()): weights[i] = FOLLOWED[choices[i].kind]
	var found: Dictionary = choices[int(_pick_weighted(weights))]
	var d := 7.0 if found.kind != "bird" else 9.0
	var made := _shot("follow",found.p,_view.x+_rng.randf_range(-0.5,0.5),DRIFT.x,Vector2(1.15,1.2),Vector2(d,d*0.85))
	made.found = found
	made.place = str(found.kind)
	_clear_view(made)
	return made

func _shot(kind: String, pivot: Vector3, yaw: float, rate: float, polar: Vector2, distance: Vector2) -> Dictionary:
	var far := DISTANCE.y*maxf(1.0,IslandFrame.scale(editor.data))
	return {"kind":kind,"t":0.0,"length":_rng.randf_range(SHOT.x,SHOT.y),"pivot":pivot,"yaw":yaw,"rate":rate*_turn_sign,
		"polar":polar.clamp(Vector2.ONE*POLAR.x,Vector2.ONE*POLAR.y),"distance":Vector2(log(clampf(distance.x,DISTANCE.x,far)),log(clampf(distance.y,DISTANCE.x,far))),
		"fov":FOV[kind]}

func _followable() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for creature: Dictionary in inspector.creatures():
		if FOLLOWED.has(creature.kind) and _on_plate(creature.p): found.append(creature)
	return found

func _pick_place(skim: bool) -> Dictionary:
	var weights := {}
	for i in range(_places.size()):
		var place: Dictionary = _places[i]
		var weight := float(place.weight)
		for seen in _recent:
			if seen.distance_to(place.point) < 4.0: weight = 0.0
		# A skim wants open land, water and groves, not a lamp.
		if skim and not str(place.kind) in ["meadow","grove","pond","summit","wheat","sunflower","cabin"]: weight *= 0.2
		if weight > 0.0: weights[i] = weight
	if weights.is_empty(): return {}
	return _places[int(_pick_weighted(weights))]

func _pick_weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for key: Variant in weights: total += maxf(float(weights[key]),0.0)
	var roll := _rng.randf()*total
	var chosen: Variant = null
	for key: Variant in weights:
		if float(weights[key]) <= 0.0: continue
		chosen = key
		roll -= float(weights[key])
		if roll <= 0.0: break
	return chosen if chosen != null else "orbit"

## Turn a shot's yaw (in steps, alternating sides) until the land hides
## neither its pivot at the start nor half way, and lift its polar until the
## eye clears the ground all the way through.
func _clear_view(made: Dictionary) -> void:
	for turn: float in [0.0,0.5,-0.5,1.0,-1.0,1.6,-1.6,2.3,-2.3,PI]:
		var clear := true
		for u: float in [0.0,0.5,1.0]:
			if not _sees(made,u,turn):
				clear = false
				break
		if clear:
			made.yaw += turn
			break
	for u: float in [0.0,0.25,0.5,0.75,1.0]:
		var mark := mark_at(made,u*float(made.length))
		var pivot: Vector3 = mark[0]
		var view: Vector3 = mark[1]
		var d := exp(view.z)
		var eye := pivot+Rig.offset(view.x,view.y)*d
		var ground: Variant = inspector.ground_y(eye)
		if ground == null: continue
		var rise := (float(ground)+CLEARANCE*1.5-pivot.y)/d
		if rise >= 0.98: continue
		var most := acos(maxf(rise,-1.0))
		if view.y > most:
			made.polar = Vector2(minf(made.polar.x,most),minf(made.polar.y,most))

func _sees(made: Dictionary, u: float, turn: float) -> bool:
	var mark := mark_at(made,u*float(made.length))
	var eye: Vector3 = mark[0]+Rig.offset(mark[1].x+turn,mark[1].y)*exp(mark[1].z)
	for i in range(1,9):
		var p: Vector3 = (mark[0] as Vector3).lerp(eye,0.1+0.9*i/8.0)
		var ground: Variant = inspector.ground_y(p)
		if ground != null and float(ground) > p.y-0.2: return false
	return true

## The director's mark at `t` seconds into a shot: [pivot, Vector3(yaw, polar,
## log distance)]. The yaw drifts steadily; tilt and dolly ease from start to
## end; the distance breathes a little.
func mark_at(made: Dictionary, t: float) -> Array:
	var u := clampf(t/maxf(float(made.length),0.01),0.0,1.0)
	var e := u*u*(3.0-2.0*u)
	var polar: Vector2 = made.polar
	var distance: Vector2 = made.distance
	var view := Vector3(float(made.yaw)+float(made.rate)*t,lerpf(polar.x,polar.y,e),lerpf(distance.x,distance.y,e)+BREATH*sin(t*TAU/BREATH_TIME))
	return [made.pivot,view]

## Whether a point is over the island's land (its bounds, 0.5 m in).
func _on_plate(point: Vector3) -> bool:
	return IslandFrame.holds(IslandFrame.reach(editor.data,0.5),editor.terrain.to_local(point))

# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _pending and can_enter(): enter()
	if not active:
		if _fov_back > 0.0:
			_fov_back = maxf(0.0,_fov_back-delta)
			camera.fov = lerpf(camera.fov,_fov_home,1.0-exp(-delta/0.15)) if _fov_back > 0.0 else _fov_home
		return
	# Something else took the world (the menu, a regrowth, the title): stand aside.
	if scene._menu.visible or editor.forming or scene.get("titled") == true or not scene._has_world:
		leave()
		return
	_clock += delta
	shot.t = float(shot.t)+delta
	if shot.has("found"):
		var at: Variant = inspector.track(shot.found)
		if at == null or not _on_plate(at): shot.length = minf(float(shot.length),float(shot.t)+2.0)
		else: shot.pivot = at
	if float(shot.t) >= float(shot.length):
		if taken.size()%4 == 0: _places = gather_places()
		_begin(next_shot())
	_follow_mark(delta)
	_write()
	_advance_chrome(delta)

## The camera trails the mark on two chained springs. The first one's eye is
## kept over the ground, and the pose rises over a bank on a lift of its own,
## so the camera is never pushed up abruptly.
func _follow_mark(delta: float) -> void:
	var mark := mark_at(shot,float(shot.t))
	var goal_view: Vector3 = mark[1]
	goal_view.x = _view_mid.x+angle_difference(_view_mid.x,goal_view.x)
	var p := Rig.spring(_pivot_mid,_pivot_mid_v,mark[0],SETTLE,delta)
	_pivot_mid = p[0]
	_pivot_mid_v = p[1]
	var v := Rig.spring(_view_mid,_view_mid_v,goal_view,SETTLE,delta)
	_view_mid = v[0]
	_view_mid_v = v[1]
	_limit_pace()
	_keep_clear()
	p = Rig.spring(_pivot,_pivot_v,_pivot_mid,SETTLE,delta)
	_pivot = p[0]
	_pivot_v = p[1]
	v = Rig.spring(_view,_view_v,_view_mid,SETTLE,delta)
	_view = v[0]
	_view_v = v[1]
	# The pose rises over a bank on its own spring rather than being pushed,
	# looking LOOK_AHEAD seconds along its way so the rise starts early.
	var need := maxf(_need_lift(_pivot,_view,LIFT_MARGIN),_need_lift(_pivot+_pivot_v*LOOK_AHEAD,_view+_view_v*LOOK_AHEAD,LIFT_MARGIN))
	var l := Rig.spring(_lift,_lift_v,need,LIFT_W,delta)
	_lift = l[0]
	_lift_v = l[1]
	# Last resort: a hard floor.
	for pass_index in range(3):
		var floor_lift := _need_lift(_pivot,_view-Vector3(0.0,_lift,0.0),FLOOR)
		if floor_lift <= 0.0: break
		_lift += floor_lift
		_lift_v = maxf(_lift_v,0.0)
	_fov = lerpf(_fov,float(shot.fov),1.0-exp(-delta/3.0))

## A long move between shots cruises: the mid mark's pace (how fast the
## picture changes: its pivot's speed over the distance, the dolly's rate and
## the turn) is held under PACE per second. The second spring smooths the cap.
func _limit_pace() -> void:
	var pace := _pivot_mid_v.length()/exp(_view_mid.z)+absf(_view_mid_v.z)+absf(_view_mid_v.x)*sin(_view_mid.y)+absf(_view_mid_v.y)
	if pace <= PACE: return
	_pivot_mid_v *= PACE/pace
	_view_mid_v *= PACE/pace

## Keep the mid mark's eye LIFT_MARGIN over the ground by lifting its polar.
func _keep_clear() -> void:
	var need := _need_lift(_pivot_mid,_view_mid,LIFT_MARGIN)
	if need <= 0.0: return
	_view_mid.y -= need
	_view_mid_v.y = minf(_view_mid_v.y,0.0)

## How far the polar must rise (radians) for the eye to stand `margin` over
## the ground under it.
func _need_lift(pivot: Vector3, view: Vector3, margin: float) -> float:
	var d := exp(view.z)
	var eye := pivot+Rig.offset(view.x,view.y)*d
	var ground: Variant = inspector.ground_y(eye)
	if ground == null: return 0.0
	var floor_y := float(ground)+margin
	if eye.y >= floor_y: return 0.0
	var rise := clampf((floor_y-pivot.y)/d,-1.0,0.999)
	return maxf(view.y-acos(rise),0.0)

func _write() -> void:
	scene.target = _pivot
	scene.yaw = _view.x
	scene.polar = clampf(_view.y-_lift,POLAR.x*0.5,POLAR.y)
	scene.distance = exp(_view.z)
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = _fov

func _advance_chrome(delta: float) -> void:
	_still += delta
	var showing := _still < POINTER_IDLE
	hint.modulate.a = move_toward(hint.modulate.a,1.0 if showing else 0.0,delta*(4.0 if showing else 0.7))
	hint.visible = hint.modulate.a > 0.01
	if hint.visible:
		var screen := scene.get_viewport().get_visible_rect().size
		hint.size = hint.get_minimum_size()
		hint.position = Vector2((screen.x-hint.size.x)*0.5,screen.y-hint.size.y-28.0)
	# A still pointer hides itself, as a film's would. Probes leave it alone.
	if not showing and not _pointer_hidden and not scene.has_meta("movie_capture") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_pointer_hidden = true

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		_still = 0.0
		if _pointer_hidden:
			Input.mouse_mode = int(_before.get("mouse",Input.MOUSE_MODE_VISIBLE))
			_pointer_hidden = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: leave()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventGesture:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		# Cmd and Ctrl shortcuts (quit, full screen) go on.
		if key.meta_pressed or key.ctrl_pressed: return
		if key.pressed and not key.echo and key.keycode in [KEY_O,KEY_ESCAPE]: leave()
		get_viewport().set_input_as_handled()
