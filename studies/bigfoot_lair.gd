extends "res://studies/bigfoot_cave.gd"
## Two stories in the same world. The lower one stays closed earth until
## inspected: resting the pointer on a wall glides the camera in and dissolves
## that wall; moving off glides back. Framing the lair also opens its wall.
const INSPECT_DWELL := 0.3
const INSPECT_GLIDE := 1.6
const INSPECT_GRACE := 0.35
var _invitation_notice := ""
var _invitation_notice_time := 0.0
var _lair_view_pose := Vector3.INF
## Tests and captures turn hover off, or aim a synthetic pointer (null = mouse).
var cave_hover := true
var cave_pointer: Variant = null
var _inspect_side := -1
var _view_side := -1
var _inspect_blend := 0.0
var _inspect_home := {}
var _inspect_written := {}
var _hover_side := -1
var _hover_time := 0.0
var _away_time := 0.0


func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Two-story Bigfoot diorama"
	# Scenery mode builds no lower story; --bigfoot restores it.
	if _cave_hidden():
		_focus_stack()
		return
	restore_cave_state({"genome":preload("res://scripts/inland_genome.gd").cave(37),"stash":[]})
	for entry in [["See both stories",_focus_stack],["Look through lair windows",_focus_lair],["Generate another cave",_regenerate],["Change cave palette",_change_palette],["Another rock arrangement",_redress],["Gather a branch",_gather_branch],["Bring home a fish",_bring_fish]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		_life_status.get_parent().add_child(button)
	_focus_stack()

func _redress() -> void:
	lair.redress(lair.seed_value+1)

func _focus_stack() -> void:
	_auto_orbit = false
	target = Vector3(0,0,0)
	distance = 64
	yaw = -0.45
	polar = 1.3
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _focus_lair() -> void:
	_auto_orbit = false
	target = Vector3(0,-1.0,0)
	distance = 60
	yaw = -0.05
	polar = 1.63
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()
	_lair_view_pose = Vector3(yaw,polar,distance)

func _process(delta: float) -> void:
	super._process(delta)
	if lair == null: return
	_update_cutaway(delta)
	# Underground occupancy is hidden by the closed walls, not by visibility.
	creature.visible = resident_enabled and not _habitat_blocked and _growth.terrain>=0.995
	if routine.cave.concealed:
		_life_status.text = ("Bigfoot · storing supplies downstairs · P pause" if routine.cave.reason=="forage" else "Bigfoot · sleeping downstairs · P pause") if not _paused else "Bigfoot · paused · P pause"
	if _invitation_notice_time>0.0:
		_invitation_notice_time = maxf(0.0,_invitation_notice_time-delta)
		_life_status.text = _invitation_notice

func _update_cutaway(delta: float) -> void:
	_watch_takeover()
	var side := _pointed_side()
	if _inspect_side>=0:
		# Any part of the room under the pointer keeps the inspection; brief
		# slips at its edge while the camera moves are forgiven.
		_away_time = 0.0 if side>=0 else _away_time+delta
		if _away_time>INSPECT_GRACE: _inspect_side = -1
	else:
		_hover_time = _hover_time+delta if side>=0 and side==_hover_side else 0.0
		_hover_side = side
		if side>=0 and _hover_time>=INSPECT_DWELL and (_inspect_blend<=0.0 or side==_view_side):
			_begin_inspection(side)
	_glide(delta)
	# The camera arrives first, then the wall opens.
	var open := _inspect_side if _inspect_side>=0 and _inspect_blend>0.6 else -1
	# A framed lair view holds its wall open until the camera moves away.
	if open<0 and _inspect_home.is_empty() and Vector3(yaw,polar,distance).distance_to(_lair_view_pose)<0.02:
		open = lair.side_facing(camera.global_position)
	lair.open_wall(open)
	lair.advance_cutaway(delta)

func _pointed_side() -> int:
	if not cave_hover or _orbiting or _panning: return -1
	var play: Variant = get("_resident_play")
	if play != null and play.scene != null and (play.pressed or play.carrying or play.gust): return -1
	var mouse: Vector2 = cave_pointer if cave_pointer != null else get_viewport().get_mouse_position()
	if cave_pointer == null and (_chunk_editor == null or not _chunk_editor.pointer_in_world(mouse)): return -1
	return lair.side_under_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))

func _begin_inspection(side: int) -> void:
	if _inspect_home.is_empty():
		_inspect_home = {"target":target,"distance":distance,"yaw":yaw,"polar":polar,"auto":_auto_orbit}
	_inspect_side = side
	_view_side = side
	_away_time = 0.0
	_auto_orbit = false
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO

## Eases between the viewer's own pose and the wall's inspection pose.
func _glide(delta: float) -> void:
	if _inspect_home.is_empty(): return
	_inspect_blend = move_toward(_inspect_blend,1.0 if _inspect_side>=0 else 0.0,delta/INSPECT_GLIDE)
	# Smootherstep: an unhurried drift in and a soft settle, in keeping with the game.
	var b := _inspect_blend
	var t := b*b*b*(b*(b*6.0-15.0)+10.0)
	var home: Dictionary = _inspect_home
	var view := _inspect_view(_view_side)
	target = home.target.lerp(view.target,t)
	distance = lerpf(home.distance,view.distance,t)
	yaw = lerp_angle(home.yaw,view.yaw,t)
	polar = lerpf(home.polar,view.polar,t)
	_update_camera()
	if _inspect_blend<=0.0:
		_auto_orbit = home.auto
		_inspect_home = {}
		_inspect_written = {}
	else:
		_inspect_written = {"target":target,"distance":distance,"yaw":yaw,"polar":polar}

## Straight on to the wall, slightly above, with the whole wall in frame.
func _inspect_view(side: int) -> Dictionary:
	var normal: Vector3 = lair.global_basis*lair.wall_normal(side)
	var size := get_viewport().get_visible_rect().size
	var half_fov := deg_to_rad(camera.fov)*0.5
	var half_width := atan(tan(half_fov)*size.x/maxf(size.y,1.0))
	var reach := maxf(lair.HALF_WIDTH*1.08/tan(half_width),(lair.CEILING*0.5+1.5)/tan(half_fov))
	return {"target":lair.to_global(Vector3(0,lair.CEILING*0.45,0)),"distance":reach+lair.HALF_WIDTH,"yaw":atan2(normal.x,normal.z),"polar":1.42}

## Any drag, zoom or preset during an inspection hands the camera back to the
## viewer where it is, rather than gliding somewhere they did not ask for.
func _watch_takeover() -> void:
	if _inspect_written.is_empty(): return
	var written: Dictionary = _inspect_written
	var moved: bool = _orbiting or _panning or target.distance_to(written.target)>0.001 or absf(distance-written.distance)>0.001 \
		or absf(angle_difference(yaw,written.yaw))>0.0005 or absf(polar-written.polar)>0.0005
	if not moved: return
	_inspect_side = -1
	_inspect_blend = 0.0
	_inspect_home = {}
	_inspect_written = {}
	_hover_time = 0.0

func _focus_bigfoot() -> void:
	if routine != null and routine.cave.concealed and lair != null:
		_focus_lair()
		return
	super._focus_bigfoot()

func _reset_camera(reference_pose := false) -> void:
	if lair != null: _focus_stack()
	else: super._reset_camera(reference_pose)

func _regenerate() -> void:
	var state := capture_cave_state()
	state.genome.seed = (int(state.genome.seed)+1)%1000000
	restore_cave_state(state)

func _change_palette() -> void:
	var state := capture_cave_state()
	var names: Array = preload("res://scripts/cave_genome.gd").PALETTES.keys()
	state.genome.palette = names[(names.find(state.genome.palette)+1)%names.size()]
	restore_cave_state(state)

func _gather_branch() -> void:
	routine.cancel("gathering invited")
	if not routine.request("tree"): _life_status.text = "Bigfoot · no nearby reachable tree"

func _bring_fish() -> void:
	routine.cancel("fishing invited")
	_invitation_notice_time = 0.0
	if not routine.request("fish",{},true):
		_invitation_notice = "Bigfoot · no reachable fishing spot · try another shore or clear a path"
		_invitation_notice_time = 6.0
		_life_status.text = _invitation_notice
