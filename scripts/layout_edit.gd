extends Node
## The in-game layout editor (docs/design/layout-edit/layout-edit-handoff.md):
## F4 on foot puts the pilot away and gives a free camera over the isle, to
## pick the objects the placers named (scripts/layout_overrides.gd: the ring
## route's rings, slabs and crags), move, lift, turn, copy, delete and add
## them, and save the scene's layout file; F4 again drops him where the
## camera looks, live, to try it at once. Only where the developer keys
## are on (scripts/kit_isle/dev_keys.gd); the isle adds it.
##
## A move sets only that object's own transform (a ring's or slab's rest
## pose, a crag's node): nothing is rebuilt, and its collision goes with
## it. A click is one physics ray and one screen test over the named list;
## nothing runs per frame while it is off.
##
## The fly camera, the pick (ray, then the nearest drawn middle on screen)
## and play-from-here are the motif editor's (studies/motif_editor.gd
## `_edit_step`, `piece_hit`, `play`), cut down.

const Layout = preload("res://scripts/layout_overrides.gd")
const AirRing = preload("res://scripts/interactables/air_ring.gd")
const BobSlab = preload("res://scripts/interactables/bob_slab.gd")
const Islands = preload("res://scripts/world_islands.gd")
const Chunks = preload("res://scripts/layout_chunks.gd")

const TOGGLE := KEY_F4
const LOOK_RATE := 0.004
const PICK_PX := 28.0
## A pick's screen reach round a ring's or a slab's middle (m).
const REACH := {"air_ring":AirRing.RADIUS+0.3,"bob_slab":1.5,"sink_slab":1.5,"drift_slab":1.5,"rope":4.0,"token":1.0}
const LIFT := 0.25
## A size step (m: a ring's radius, a slab's longer side), and Shift's.
const GROW := 0.25
const GROW_FINE := 0.05
const TURN := 15.0
const SNAP := 0.05
## A new piece: this far along the view (nearer if something is in the way).
const ADD_OUT := 14.0
## The ring-stair slabs' launch (ring_route.gd RING_SLAB_PUMPS).
const RING_SLAB_PUMPS := 7.0
## What stands on a selected island: boxed faintly under its bright rim.
const MEMBER_TINT := Color(1.0,0.75,0.4,0.28)
## The landing-strip warning (AGENTS.md: every isle the plane reaches
## keeps turf long enough to land on): each island's longest clear run
## (the study's `longest_run`, looked for up to STRIP_CAP m) when the view
## first opens, and again after each change; one that falls more than
## STRIP_SLACK m under its first is warned of on screen. It doesn't block.
const STRIP_CAP := 40.0
const STRIP_SLACK := 2.0
const HINT := """LAYOUT EDIT  (F4: back to play, he drops where you look)
RMB hold + move  look      W A S D / Q E  fly / down, up    Shift  fast
LMB  select, drag to move (at its height; an island too)     wheel / PgUp PgDn  height (Shift: 1 m)
Shift+LMB  add to / drop from the group    drag on empty sky or Shift+drag  box-select    (a group moves, turns, tips, sizes, copies, deletes as one)
Z / X  turn 15 deg (Shift 5)    T / G  tip 15 deg (a ring throws along its arrow; a group about the view's level right)    [ / ]  size (rings, slabs; Shift finer)    C  duplicate    Del / Backspace  delete
1  add air ring    2  add bob slab    3  add ring-stair slab (7 pumps)    K  save the selection as a chunk    J  chunks: stamp one where you look
click an island's ground: the island    U  from a piece to the island it stands on    O  open the island alone (motif editor)
Ctrl/Cmd+Z  undo    Ctrl/Cmd+S  save"""

var study: Node3D
var host: Node3D
var editing := false
var selected := ""
## Coded names deleted (the file's as read, and this session's).
var gone: Array = []
var dirty := false
var cam_speed := 14.0
var saves := 0
var _cam_pos := Vector3.ZERO
var _cam_yaw := 0.0
var _cam_pitch := 0.0
var _looking := false
var _look_from := Vector2.ZERO
var _dragging := false
var _drag_y := 0.0
var _drag_off := Vector3.ZERO
var _was_scripted := false
var _stood := Vector3.ZERO
var _stood_face := Vector2(0.0,-1.0)
var _ui: CanvasLayer
var _status: Label
var _said := ""
var _box: MeshInstance3D
## The island taken (scripts/world_islands.gd `grab`), while it is dragged;
## its pivot when taken.
var _grab := {}
var _grab_pivot := Vector3.ZERO
## Each island's longest clear run (m) when the view first opened, and now;
## set when a change may have taken one away (checked once it is let go).
var strip_first := {}
var strip_now := {}
var _strips_stale := false
var _warn: Label
## The undo stack (Ctrl/Cmd+Z), newest last: each record what one action
## changed, as it was before (see `undo`). A burst of the same nudge (wheel
## ticks, a held Z) on one object within NUDGE_MS is one record.
const UNDO_MAX := 200
const NUDGE_MS := 800
var undos: Array = []
## A drag's start (the piece's pose, or the island's move from coded), set
## on the click and made a record on let go if it moved.
var _drag_from: Variant = null
## The group (spec goal 2): two or more pieces selected as one, `selected`
## its last; empty when one thing (or nothing) is selected. Islands don't
## group.
var group: Array = []
## A group drag's start: each piece's pose, and the grabbed point.
var _group_from := {}
var _group_at := Vector3.ZERO
var _group_d := Vector3.ZERO
## A box being dragged out on screen (from `_box_from`); Shift adds to the
## selection.
var _boxing := false
var _box_from := Vector2.ZERO
var _box_add := false
var _rubber: ReferenceRect
## The group's other pieces' boxes (the last's is `_box`).
var _boxes: Array = []
## Chunks (scripts/layout_chunks.gd): the name field while a selection is
## being saved as one (`_naming`: the names it saves, and the view's yaw
## then), and the list to stamp from.
var _naming: Array = []
var _naming_yaw := 0.0
var _name_box: PanelContainer
var _name_field: LineEdit
var _chunk_panel: PanelContainer
var _chunk_list: ItemList
## A stamp's reach: the view's middle hits something this near, or the
## chunk goes ADD_OUT m out past its own reach.
const STAMP_REACH := 250.0

func setup(scene: Node3D, pieces: Node3D) -> void:
	study = scene
	host = pieces
	var was: Array = Layout.data.get("deleted",[])
	gone = was.duplicate()
	set_process(false)
	# Back from the island view (studies/motif_editor.gd F4): the world view
	# opened again on that island once he can walk.
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--world-view="): _reopen = a.get_slice("=",1)
	if _reopen != "" and scene.has_signal("isle_ready"): scene.isle_ready.connect(_reopen_view,CONNECT_ONE_SHOT|CONNECT_DEFERRED)

## The island the world view opens on at load (`--world-view=`), "" none.
var _reopen := ""
func _reopen_view() -> void:
	if not is_inside_tree(): return
	if not can_enter():
		get_tree().create_timer(0.2).timeout.connect(_reopen_view)
		return
	enter()
	if not is_island(_reopen):
		say("no island %s to open on" % _reopen)
		return
	select(_reopen)
	# Looked at from its south-east, high, as from the plane.
	var i: Dictionary = Islands.islands[_reopen]
	var r: Rect2 = i.rect
	var mid := Islands.pivot(_reopen)
	var back := maxf(r.size.x,r.size.y)*0.8+20.0
	_cam_yaw = deg_to_rad(30.0)
	_cam_pitch = -0.6
	_cam_pos = mid+Basis.from_euler(Vector3(_cam_pitch,_cam_yaw,0.0))*Vector3(0.0,0.0,back)
	_apply_cam()
	say("back from the island view: %s rebuilt from its recipe" % _reopen)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == TOGGLE:
		if editing: leave()
		elif can_enter(): enter()
		else: return
		get_viewport().set_input_as_handled()
		return
	if not editing: return
	# The chunk name field has the keys (Enter saves, Esc doesn't).
	if not _naming.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			var kc := (event as InputEventKey).keycode
			if kc == KEY_ESCAPE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
				_end_naming(kc != KEY_ESCAPE)
				get_viewport().set_input_as_handled()
		return
	# The chunk list takes clicks on itself.
	if _listing() and event is InputEventMouseButton and _chunk_panel.get_global_rect().has_point((event as InputEventMouseButton).position): return
	if _listing() and event is InputEventKey and event.pressed and _list_key(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	# Esc still pauses (scripts/kit_isle/pause_host.gd).
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE: return
	_edit_input(event)
	# (O leaves the scene: the tree is gone by then.)
	if is_inside_tree(): get_viewport().set_input_as_handled()

## On foot and walking, the title gone.
func can_enter() -> bool:
	if study == null or not bool(study.get("walk_ready")) or bool(study.get("flying")): return false
	var door: Variant = study.get("front_door")
	if door != null and bool((door as Object).get("titled")): return false
	return true

func enter() -> void:
	editing = true
	_was_scripted = study.scripted
	study.scripted = true
	var motor: Object = study.motor
	_stood = motor.feet
	var f: float = motor.facing
	_stood_face = Vector2(-sin(f),-cos(f))
	var cam: Camera3D = study.camera
	var e := cam.global_basis.get_euler()
	_cam_pos = cam.global_position
	_cam_yaw = e.y
	_cam_pitch = e.x
	_apply_cam()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_ui.visible = true
	set_process(true)
	# What stands on each island, found once (scripts/world_islands.gd).
	if not Islands.anchored and not Islands.islands.is_empty():
		var began := Time.get_ticks_msec()
		Islands.anchor(study.world_roots() if study.has_method("world_roots") else study.get_children())
		print("world view: anchored in %d ms: %s" % [Time.get_ticks_msec()-began,Islands.summary()])
	if strip_first.is_empty() and study.has_method("longest_run"):
		var began := Time.get_ticks_msec()
		for name: String in Islands.islands: strip_first[name] = _strip_of(name)
		strip_now = strip_first.duplicate()
		print("world view: landing runs in %d ms: %s" % [Time.get_ticks_msec()-began,_strip_line(strip_first)])
	_show_warn()
	say("%d named objects, %d islands" % [Layout.entries.size(),Islands.islands.size()])

## Back to play: he is dropped where the camera's middle looks (on what it
## hits), facing the view, else back where he stood.
func leave() -> void:
	let_go()
	_looking = false
	select("")
	editing = false
	set_process(false)
	_show_throws(false)
	if not _naming.is_empty(): _end_naming(false)
	show_chunks(false)
	if _ui != null: _ui.visible = false
	var cam: Camera3D = study.camera
	var at := _stood
	var face := _stood_face
	var mid := get_viewport().get_visible_rect().size*0.5
	var hit := _ray(cam.project_ray_origin(mid),cam.project_ray_normal(mid),int(study.ground.mask))
	if not hit.is_empty():
		at = hit.position
		var fwd := -cam.global_basis.z
		var flat := Vector2(fwd.x,fwd.z)
		if flat.length() > 0.05: face = flat.normalized()
	study.scripted = _was_scripted
	if host != null: host.set("on",null)
	study.place(at+Vector3.UP*0.05,face)
	if get_tree().current_scene == study: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not editing: return
	var way := Vector3.ZERO
	if _naming.is_empty() and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		if Input.is_key_pressed(KEY_W): way.z -= 1.0
		if Input.is_key_pressed(KEY_S): way.z += 1.0
		if Input.is_key_pressed(KEY_A): way.x -= 1.0
		if Input.is_key_pressed(KEY_D): way.x += 1.0
		if Input.is_key_pressed(KEY_E): way.y += 1.0
		if Input.is_key_pressed(KEY_Q): way.y -= 1.0
	if way != Vector3.ZERO:
		var b: Basis = (study.camera as Camera3D).global_basis
		var move := b*Vector3(way.x,0.0,way.z)+Vector3.UP*way.y
		_cam_pos += move.normalized()*cam_speed*(3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)*delta
	# Every frame: the study's foot lock or look may have set the camera.
	_apply_cam()
	if _strips_stale and not _dragging: check_strips()
	_show_throws(true)

## Each ring's throw arrow (AirRing `show_throw`) on in the world view.
func _show_throws(on: bool) -> void:
	var rings: Variant = host.get("rings") if host != null else null
	if not rings is Array: return
	for r: Variant in rings:
		if is_instance_valid(r) and (r as Object).has_method("show_throw"): r.show_throw(on)

func _apply_cam() -> void:
	(study.camera as Camera3D).global_transform = Transform3D(Basis.from_euler(Vector3(_cam_pitch,_cam_yaw,0.0)),_cam_pos)

# --- Input ---------------------------------------------------------------------------

func _edit_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _looking:
			_cam_yaw -= mm.relative.x*LOOK_RATE
			_cam_pitch = clampf(_cam_pitch-mm.relative.y*LOOK_RATE,-1.5,1.5)
			_apply_cam()
		elif _boxing: _box_to(mm.position)
		elif _dragging: drag_to(mm.position)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				if mb.pressed and not _looking: _look_from = mb.position
				_looking = mb.pressed
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
				if not _looking and get_tree().current_scene == study: get_viewport().warp_mouse(_look_from)
			MOUSE_BUTTON_LEFT:
				if mb.pressed: click(mb.position,mb.shift_pressed)
				else: let_go()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not mb.pressed: return
				var up := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				if selected != "": lift(up*(4.0 if mb.shift_pressed else 1.0)*LIFT)
				else: cam_speed = clampf(cam_speed*(1.2 if up > 0.0 else 1.0/1.2),2.0,120.0)
		return
	if not event is InputEventKey or not event.pressed: return
	var k := event as InputEventKey
	var fine := k.shift_pressed
	var cmd := k.ctrl_pressed or k.meta_pressed
	match k.keycode:
		KEY_S:
			if cmd and not k.echo: save()
		KEY_PAGEUP: lift(4.0*LIFT if fine else LIFT)
		KEY_PAGEDOWN: lift(-4.0*LIFT if fine else -LIFT)
		KEY_Z:
			if cmd: undo()
			else: turn(5.0 if fine else TURN)
		KEY_X: turn(-5.0 if fine else -TURN)
		KEY_BRACKETLEFT: resize(-(GROW_FINE if fine else GROW))
		KEY_BRACKETRIGHT: resize(GROW_FINE if fine else GROW)
		KEY_T: tip(5.0 if fine else TURN)
		KEY_G: tip(-5.0 if fine else -TURN)
		KEY_C: if not k.echo and not cmd: duplicate_selected()
		KEY_DELETE, KEY_BACKSPACE: if not k.echo: delete_selected()
		KEY_1: if not k.echo: add("air_ring")
		KEY_2: if not k.echo: add("bob_slab")
		KEY_3: if not k.echo: add("bob_slab",RING_SLAB_PUMPS)
		KEY_U: if not k.echo: step_out()
		KEY_O: if not k.echo and not cmd: open_island()
		KEY_K: if not k.echo and not cmd: begin_chunk()
		KEY_J: if not k.echo and not cmd: show_chunks(not _listing())

# --- Picking and moving --------------------------------------------------------------

func _ray(from: Vector3, way: Vector3, mask := 0xFFFFFFFF) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from,from+way*2000.0,mask)
	return study.get_world_3d().direct_space_state.intersect_ray(q)

## The named object under screen point `at` ("" none): the ring or
## slab whose middle is nearest it on screen (within its reach), unless the ray's hit
## (a named object's collider, a crag's turf, or anything else) is nearer.
func pick(at: Vector2) -> String:
	var cam: Camera3D = study.camera
	var from := cam.project_ray_origin(at)
	var way := cam.project_ray_normal(at)
	var hit := _ray(from,way)
	var hit_name := ""
	var hit_d := INF
	if not hit.is_empty():
		hit_d = from.distance_to(hit.position)
		var n: Node = hit.collider
		while n != null and n != study:
			if n.has_meta("layout_name"):
				hit_name = str(n.get_meta("layout_name"))
				break
			n = n.get_parent()
		# Else the island it is (its ground) or stands on (a member).
		if hit_name == "": hit_name = Islands.island_of(hit.collider)
	var best := ""
	var best_d := INF
	var best_k := INF
	for name: String in Layout.entries:
		var e: Dictionary = Layout.entries[name]
		if not REACH.has(e.kind) or not is_instance_valid(e.node): continue
		var mid: Vector3 = e.node.layout_mid() if e.node.has_method("layout_mid") else (e.node as Node3D).global_position
		if cam.is_position_behind(mid): continue
		var r: float = e.node.layout_reach() if e.node.has_method("layout_reach") else REACH[e.kind]
		var c := cam.unproject_position(mid)
		var edge := cam.unproject_position(mid+cam.global_basis.x*r)
		var reach := maxf(c.distance_to(edge),PICK_PX)
		var off := c.distance_to(at)
		if off > reach: continue
		# The one whose middle is nearest the click (for its size on screen).
		if off/reach < best_k:
			best_k = off/reach
			best_d = from.distance_to(mid)
			best = name
	if best != "" and best_d-_reach_of(best) <= hit_d: return best
	return hit_name

func _reach_of(name: String) -> float:
	var e: Dictionary = Layout.entries[name]
	return float(e.node.layout_reach()) if e.node.has_method("layout_reach") else float(REACH[e.kind])

## A left click: with Shift, the piece under it into or out of the group
## (or a box begun, over no piece); on a piece of the group, the group
## taken to drag; on nothing, the selection cleared and a box begun; else
## that object selected and taken to drag.
func click(at: Vector2, shift := false) -> void:
	var name := pick(at)
	if shift:
		if name != "" and not is_island(name): toggle(name)
		else: _begin_box(at,true)
		return
	if name != "" and name in group:
		_take_group(at,name)
		return
	select(name)
	if name == "":
		_begin_box(at,false)
		return
	if is_island(name):
		# Dragged by its middle, in the level plane at its rim.
		# Held where it was taken: in the level plane through that point.
		_grab_pivot = Islands.pivot(name)
		var cam: Camera3D = study.camera
		var hit := _ray(cam.project_ray_origin(at),cam.project_ray_normal(at))
		_drag_y = (hit.position as Vector3).y if not hit.is_empty() else _grab_pivot.y
		var q := _on_level(at,_drag_y)
		if q == Vector3.INF: return
		_grab = _take(name)
		_drag_from = Islands.islands[name].xf
		_drag_off = Vector3(_grab_pivot.x-q.x,0.0,_grab_pivot.z-q.z)
		_dragging = true
		return
	# Dragged in the level plane through its middle, held where it was taken.
	# (A rope by the level through its middle, where it was picked.)
	var t := Layout.current(name)
	var node: Node3D = Layout.entries[name].node
	_drag_y = node.layout_mid().y if node.has_method("layout_mid") else t.origin.y
	var p := _on_level(at,_drag_y)
	_drag_off = t.origin-p if p != Vector3.INF else Vector3.ZERO
	_dragging = p != Vector3.INF
	_drag_from = t

## Screen point `at` on the level plane at height `y` (INF if the view
## doesn't meet it ahead).
func _on_level(at: Vector2, y: float) -> Vector3:
	var cam: Camera3D = study.camera
	var from := cam.project_ray_origin(at)
	var way := cam.project_ray_normal(at)
	if absf(way.y) < 1e-4: return Vector3.INF
	var k := (y-from.y)/way.y
	if k <= 0.0 or k > 3000.0: return Vector3.INF
	return from+way*k

## The mouse up: an island let go (what reads its place redone); a piece
## given to the island it stands over now.
func let_go() -> void:
	if _boxing:
		_end_box()
		return
	var was := _dragging
	_dragging = false
	if not _group_from.is_empty():
		_record_group_drag()
		if was:
			for n: String in group: _reanchor(n)
		return
	_record_drag()
	if not _grab.is_empty(): _settle()
	elif was and selected != "" and not is_island(selected): _reanchor(selected)

## Piece `name` given to the island under it now (or none), its box redrawn.
func _reanchor(name: String) -> void:
	var e: Dictionary = Layout.entries[name]
	var on := Islands.reanchor(e.node)
	# A piece stamped on an island goes to the island it is let go over.
	if e.has("on") and on != "": e.on = on
	if on != "" or Islands.anchored: _show_status()

func drag_to(at: Vector2) -> void:
	if selected == "": return
	var p := _on_level(at,_drag_y)
	if p == Vector3.INF: return
	if not _grab.is_empty():
		var to := p+_drag_off
		to = Vector3(snappedf(to.x,SNAP),_grab_pivot.y,snappedf(to.z,SNAP))
		Islands.move(_grab,Transform3D(Basis.IDENTITY,to-_grab_pivot)*(_grab.xf as Transform3D))
		dirty = true
		_show_status()
		return
	if not _group_from.is_empty():
		var d := p-_group_at
		d = Vector3(snappedf(d.x,SNAP),0.0,snappedf(d.z,SNAP))
		for n: String in _group_from:
			if not Layout.entries.has(n): continue
			var g: Transform3D = _group_from[n]
			g.origin += d
			Layout.apply(n,g)
		_group_d = d
		dirty = true
		_strips_stale = true
		_show_status()
		return
	var t := Layout.current(selected)
	var to := p+_drag_off
	t.origin = Vector3(snappedf(to.x,SNAP),t.origin.y,snappedf(to.z,SNAP))
	_put(selected,t)

func lift(dy: float) -> void:
	if selected == "": return
	if not group.is_empty():
		_group_step(Transform3D(Basis.IDENTITY,Vector3.UP*dy),"lift")
		_drag_y += dy
		return
	if is_island(selected):
		_island_step(Transform3D(Basis.IDENTITY,Vector3.UP*dy))
		return
	var t := Layout.current(selected)
	if not _dragging: _nudged({"do":"pose","name":selected,"t":t},"lift")
	t.origin.y = snappedf(t.origin.y+dy,SNAP)
	_drag_y += dy
	_put(selected,t)
	if not _dragging: _reanchor(selected)

## Turned `deg` about the world's up, round its own middle.
func turn(deg: float) -> void:
	if selected == "": return
	if not group.is_empty():
		_group_swing(Basis(Vector3.UP,deg_to_rad(deg)),"turn")
		return
	if is_island(selected):
		var c := Islands.pivot(selected)
		_island_step(Transform3D(Basis.IDENTITY,c)*Transform3D(Basis(Vector3.UP,deg_to_rad(deg)),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-c))
		return
	var t := Layout.current(selected)
	if not _dragging: _nudged({"do":"pose","name":selected,"t":t},"turn")
	t.basis = Basis(Vector3.UP,deg_to_rad(deg))*t.basis
	_put(selected,t)

## Tipped `deg` about its own x.
func tip(deg: float) -> void:
	if selected == "" or _island_held(): return
	if not group.is_empty():
		# About the view's level right, through the group's middle.
		var right: Vector3 = (study.camera as Camera3D).global_basis.x
		right = Vector3(right.x,0.0,right.z)
		if right.length() < 0.01: right = Vector3.RIGHT
		_group_swing(Basis(right.normalized(),deg_to_rad(deg)),"tip")
		return
	var t := Layout.current(selected)
	if not _dragging: _nudged({"do":"pose","name":selected,"t":t},"tip")
	t.basis = t.basis*Basis(Vector3.RIGHT,deg_to_rad(deg))
	_put(selected,t)

## The selected ring or slab grown by `step` m (a ring's radius; a slab's
## longer side, its footprint scaled to keep its shape, its thickness kept),
## that piece alone built again at once.
func resize(step: float) -> void:
	if selected == "" or _island_held(): return
	if not group.is_empty():
		_group_resize(step)
		return
	var was: Variant = Layout.size_of(selected)
	if was == null:
		say("only rings and slabs size (not %s)" % Layout.entries[selected].kind)
		return
	var began := Time.get_ticks_usec()
	if not _grow(selected,step):
		say("%s is as %s as it goes" % [selected,"big" if step > 0.0 else "small"])
		return
	_nudged({"do":"size","name":selected,"size":was},"size")
	print("world view: %s sized %s in %.1f ms" % [selected,size_text(selected),(Time.get_ticks_usec()-began)/1000.0])
	dirty = true
	_strips_stale = true
	_show_box()
	_show_status()

## Ring or slab `name` grown by `step` (that piece alone rebuilt); false
## if it didn't change (at its end, or not a sizing kind).
func _grow(name: String, step: float) -> bool:
	var was: Variant = Layout.size_of(name)
	if was == null: return false
	var node: Node3D = Layout.entries[name].node
	if was is Vector3:
		var v: Vector3 = was
		var long := maxf(v.x,v.z)
		var k := maxf(long+step,0.01)/long
		# Its shape kept at the ends too (FootSlab SIDE_MIN, SIDE_MAX).
		k = clampf(k,float(node.SIDE_MIN)/minf(v.x,v.z),float(node.SIDE_MAX)/long)
		node.layout_resize(Vector3(v.x*k,v.y,v.z*k))
	else: node.layout_resize(float(was)+step)
	return not Layout._same_size(Layout.size_of(name),was)

## `name`'s size for the status line ("" none).
func size_text(name: String) -> String:
	var v: Variant = Layout.size_of(name)
	if v == null: return ""
	if v is Vector3: return "%.2f x %.2f m" % [v.x,v.z]
	return "%.2f m across (radius %.2f)" % [float(v)*2.0,float(v)]

func _put(name: String, t: Transform3D) -> void:
	Layout.apply(name,t)
	dirty = true
	_strips_stale = true
	_show_status()

# --- Adding, copying, deleting, saving -------------------------------------------------

## A new `kind` piece where the view's middle looks, selected.
func add(kind: String, pumps := 0.0) -> void:
	if host == null:
		say("no pieces host here")
		return
	var cam: Camera3D = study.camera
	var from := cam.global_position
	var way := -cam.global_basis.z
	var at := from+way*ADD_OUT
	var hit := _ray(from,way)
	if not hit.is_empty() and from.distance_to(hit.position) < ADD_OUT: at = (hit.position as Vector3)+Vector3.UP*1.5
	var name := Layout.fresh_name(kind)
	var yaw := atan2(-way.x,-way.z)
	Layout.spawn(host,name,kind,Transform3D(Basis(Vector3.UP,yaw),at.snappedf(SNAP)),pumps)
	_push({"do":"add","name":name})
	dirty = true
	select(name)

## A copy of the selected ring or slab, 3 m to the camera's right.
func duplicate_selected() -> void:
	if selected == "" or _island_held(): return
	if not group.is_empty():
		_group_copy()
		return
	var e: Dictionary = Layout.entries[selected]
	if not str(e.kind) in Layout.ADDABLE:
		say("only rings and slabs copy (not %s)" % e.kind)
		return
	var t := Layout.current(selected)
	var right: Vector3 = (study.camera as Camera3D).global_basis.x
	t.origin += Vector3(right.x,0.0,right.z).normalized()*3.0
	var name := Layout.fresh_name(str(e.kind))
	Layout.spawn(host,name,str(e.kind),t,float(e.get("pumps",0.0)),Layout.size_of(selected))
	_push({"do":"add","name":name})
	dirty = true
	select(name)

func delete_selected() -> void:
	if selected == "" or _island_held(): return
	if not group.is_empty():
		_group_delete()
		return
	var name := selected
	select("")
	_push(_remove(name))
	dirty = true
	_strips_stale = true
	say("deleted %s" % name)

## `name` taken out of the world: what undoes it back. A piece is taken
## out of the tree (not freed: the undo stack holds it, `_drop` frees it);
## a land is hidden and out of the physics space (its turf stays registered
## for flora and outlines until the reload).
func _remove(name: String) -> Dictionary:
	var e: Dictionary = Layout.entries[name]
	var node: Node3D = e.node
	var rec := {"do":"delete","name":name,"entry":e,"node":node,"lists":[],"on":""}
	if host != null:
		for list: String in ["rings","slabs","ropes","rails"]:
			var a: Array = host.get(list)
			if node in a:
				a.erase(node)
				(rec.lists as Array).append(list)
		if host.get("on") == node: host.set("on",null)
		if host.get("on_rail") == node: host.set("on_rail",null)
	var isl := str(node.get_meta("world_island","")) if node.has_meta("world_island") else ""
	if isl != "" and Islands.islands.has(isl) and node in Islands.islands[isl].members:
		(Islands.islands[isl].members as Array).erase(node)
		rec.on = isl
	if str(e.kind) == "land":
		node.visible = false
		var layers: Array = []
		for c: Node in node.find_children("*","CollisionObject3D",true,false):
			var co := c as CollisionObject3D
			layers.append([co,co.collision_layer,co.collision_mask])
			co.collision_layer = 0
			co.collision_mask = 0
		rec.layers = layers
	else:
		var parent := node.get_parent()
		rec.parent = parent
		rec.index = node.get_index()
		parent.remove_child(node)
	Layout.entries.erase(name)
	if not Layout.is_added(name) and not name in gone:
		gone.append(name)
		rec.gone = true
	return rec

# --- Groups (spec goal 2) --------------------------------------------------------------

## Piece `name` into the group, or out of it if it is in (Shift+click).
## The one piece selected before becomes the group's first.
func toggle(name: String) -> void:
	var g: Array = group.duplicate()
	if g.is_empty() and selected != "" and not is_island(selected): g = [selected]
	if name in g: g.erase(name)
	else: g.append(name)
	select_group(g)

## `names` selected: none, one (as `select`), or a group (the last is
## `selected`).
func select_group(names: Array) -> void:
	var g: Array = []
	for n: Variant in names:
		if Layout.entries.has(str(n)) and not str(n) in g: g.append(str(n))
	if g.size() < 2:
		select(str(g[0]) if g.size() == 1 else "")
		return
	group = g
	selected = str(g.back())
	_show_box()
	_show_status()

## The group's middle: the mean of its pieces' spots.
func group_mid() -> Vector3:
	var c := Vector3.ZERO
	for n: String in group: c += Layout.current(n).origin
	return c/maxf(group.size(),1.0)

## The group's key in the undo stack (a burst on the same group is one).
func _group_key() -> String:
	return "group:"+",".join(PackedStringArray(group))

## Each piece's pose now, as undo records.
func _group_poses() -> Array:
	var out: Array = []
	for n: String in group: out.append({"do":"pose","name":n,"t":Layout.current(n)})
	return out

## The group taken to drag, by its piece `name` under screen point `at`:
## dragged in the level plane through that piece's middle.
func _take_group(at: Vector2, name: String) -> void:
	var node: Node3D = Layout.entries[name].node
	_drag_y = node.layout_mid().y if node.has_method("layout_mid") else Layout.current(name).origin.y
	var p := _on_level(at,_drag_y)
	if p == Vector3.INF: return
	_group_at = p
	_group_d = Vector3.ZERO
	_group_from = {}
	for n: String in group: _group_from[n] = Layout.current(n)
	_dragging = true

## The group let go: one record of where it all stood, if it moved.
func _record_group_drag() -> void:
	var from := _group_from
	_group_from = {}
	var recs: Array = []
	for n: String in from:
		if Layout.entries.has(n) and not Layout._same(from[n],Layout.current(n)): recs.append({"do":"pose","name":n,"t":from[n]})
	if not recs.is_empty(): _push({"do":"group","name":_group_key(),"recs":_from_all(from),"names":group.duplicate()})

static func _from_all(from: Dictionary) -> Array:
	var out: Array = []
	for n: String in from: out.append({"do":"pose","name":n,"t":from[n]})
	return out

## Every piece of the group moved by world transform `d` (a burst of the
## same nudge is one record).
func _group_step(d: Transform3D, by: String) -> void:
	if not _dragging: _nudged({"do":"group","name":_group_key(),"recs":_group_poses(),"names":group.duplicate()},by)
	for n: String in group:
		var t := d*Layout.current(n)
		t.basis = t.basis.orthonormalized()
		if d.basis == Basis.IDENTITY: t.origin.y = snappedf(t.origin.y,SNAP)
		Layout.apply(n,t)
		if not _dragging: _reanchor(n)
	# Mid-drag: the drag's start swung too, so the drag keeps it.
	if _dragging:
		for n: String in _group_from: _group_from[n] = Transform3D(Basis.IDENTITY,-_group_d)*Layout.current(n)
	dirty = true
	_strips_stale = true
	_show_box()
	_show_status()

## The group swung by `b` about its middle, each piece keeping its place
## in it.
func _group_swing(b: Basis, by: String) -> void:
	var c := group_mid()
	_group_step(Transform3D(Basis.IDENTITY,c)*Transform3D(b,Vector3.ZERO)*Transform3D(Basis.IDENTITY,-c),by)

## Every ring and slab in the group grown by `step` (each rebuilt alone).
func _group_resize(step: float) -> void:
	var began := Time.get_ticks_usec()
	var recs: Array = []
	for n: String in group:
		var was: Variant = Layout.size_of(n)
		if was == null: continue
		if _grow(n,step): recs.append({"do":"size","name":n,"size":was})
	if recs.is_empty():
		say("nothing in the group sizes further (only rings and slabs size)")
		return
	# A burst on the group is one record: its first sizes kept.
	var last: Variant = undos.back() if not undos.is_empty() else null
	if last is Dictionary and str(last.get("by","")) == "size" and str(last.name) == _group_key() and Time.get_ticks_msec()-int(last.at) < NUDGE_MS:
		last.at = Time.get_ticks_msec()
		var had := {}
		for r: Dictionary in last.recs: had[str(r.name)] = true
		for r: Dictionary in recs:
			if not had.has(str(r.name)): (last.recs as Array).append(r)
	else: _push({"do":"group","name":_group_key(),"recs":recs,"names":group.duplicate(),"by":"size"})
	print("world view: %d of the group sized in %.1f ms" % [recs.size(),(Time.get_ticks_usec()-began)/1000.0])
	dirty = true
	_strips_stale = true
	_show_box()
	say("sized %d of %d (rings and slabs)" % [recs.size(),group.size()])

## A copy of the group's rings and slabs, beside it to the camera's right
## (clear of it), selected as the new group.
func _group_copy() -> void:
	var right: Vector3 = (study.camera as Camera3D).global_basis.x
	right = Vector3(right.x,0.0,right.z)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var lo := INF
	var hi := -INF
	for n: String in group:
		var x := Layout.current(n).origin.dot(right)
		lo = minf(lo,x)
		hi = maxf(hi,x)
	var off := right*(hi-lo+3.0)
	var made: Array = []
	var recs: Array = []
	var skipped := 0
	for n: String in group:
		var e: Dictionary = Layout.entries[n]
		if not str(e.kind) in Layout.ADDABLE:
			skipped += 1
			continue
		var t := Layout.current(n)
		t.origin += off
		var name := Layout.fresh_name(str(e.kind))
		Layout.spawn(host,name,str(e.kind),t,float(e.get("pumps",0.0)),Layout.size_of(n))
		made.append(name)
		recs.append({"do":"add","name":name})
	if made.is_empty():
		say("only rings and slabs copy (none in the group)")
		return
	_push({"do":"group","name":"copy:"+",".join(PackedStringArray(made)),"recs":recs,"names":group.duplicate()})
	dirty = true
	select_group(made)
	say("copied %d%s" % [made.size(),"  (%d not rings or slabs left)" % skipped if skipped > 0 else ""])

func _group_delete() -> void:
	var names: Array = group.duplicate()
	select("")
	var recs: Array = []
	for n: String in names:
		if Layout.entries.has(n): recs.append(_remove(n))
	_push({"do":"group","name":"delete:"+",".join(PackedStringArray(names)),"recs":recs,"names":names})
	dirty = true
	_strips_stale = true
	say("deleted %d" % recs.size())

## A box dragged out on screen: begun at `at` (`add`: onto the selection).
func _begin_box(at: Vector2, add: bool) -> void:
	_boxing = true
	_box_from = at
	_box_add = add
	if _rubber == null:
		_rubber = ReferenceRect.new()
		_rubber.name = "BoxSelect"
		_rubber.editor_only = false
		_rubber.border_color = Color(1.0,0.85,0.2)
		_rubber.border_width = 1.5
		_rubber.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = Color(1.0,0.85,0.2,0.12)
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rubber.add_child(fill)
		_ui.add_child(_rubber)
	_box_to(at)

func _box_to(at: Vector2) -> void:
	var r := Rect2(_box_from,Vector2.ZERO).expand(at)
	_rubber.position = r.position
	_rubber.size = r.size
	_rubber.visible = r.size.length() > 4.0

## The box let go: every named piece whose middle is in it selected (with
## Shift, added to what was). A click with no drag selects nothing new.
func _end_box() -> void:
	_boxing = false
	var r := Rect2(_rubber.position,_rubber.size)
	_rubber.visible = false
	if r.size.length() <= 4.0: return
	select_group(box_pick(r,_box_add))

## The pieces in screen rect `r` (`add`: the selection's first).
func box_pick(r: Rect2, add := false) -> Array:
	var cam: Camera3D = study.camera
	var out: Array = []
	if add: out = group.duplicate() if not group.is_empty() else ([selected] if selected != "" and not is_island(selected) else [])
	for name: String in Layout.entries:
		var e: Dictionary = Layout.entries[name]
		if not is_instance_valid(e.node) or not (e.node as Node).is_inside_tree() or name in out: continue
		var mid: Vector3 = e.node.layout_mid() if e.node.has_method("layout_mid") else (e.node as Node3D).global_position
		if cam.is_position_behind(mid): continue
		if r.has_point(cam.unproject_position(mid)): out.append(name)
	return out

# --- Chunks (spec goal 2) ---------------------------------------------------------------

func _listing() -> bool:
	return _chunk_panel != null and _chunk_panel.visible

## The view's yaw (a new piece faces it; a chunk is kept and stamped by it).
func _view_yaw() -> float:
	var way := -(study.camera as Camera3D).global_basis.z
	return atan2(-way.x,-way.z)

## The pieces a chunk would take now: the group, else the one piece.
func _chunk_names() -> Array:
	if not group.is_empty(): return group.duplicate()
	if selected != "" and not is_island(selected): return [selected]
	return []

## The name field opened for the selection (K); Enter saves it.
func begin_chunk() -> void:
	var names := _chunk_names()
	if names.is_empty():
		say("select pieces first (a group, or one ring or slab), then K to keep them as a chunk")
		return
	_naming = names
	_naming_yaw = _view_yaw()
	if _name_box == null:
		_name_box = PanelContainer.new()
		_name_box.name = "ChunkName"
		_name_box.position = Vector2(16.0,268.0)
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "chunk name (Enter saves, Esc cancels):"
		row.add_child(l)
		_name_field = LineEdit.new()
		_name_field.custom_minimum_size = Vector2(260.0,0.0)
		row.add_child(_name_field)
		_name_box.add_child(row)
		_ui.add_child(_name_box)
	_name_field.text = Chunks.fresh()
	_name_box.visible = true
	_name_field.grab_focus()
	_name_field.select_all()

func _end_naming(keep: bool) -> void:
	var names := _naming
	_naming = []
	if _name_box != null:
		_name_box.visible = false
		_name_field.release_focus()
	if keep: save_chunk(Chunks.clean(_name_field.text),names,_naming_yaw)
	else: say("chunk not saved")

## `names` kept as chunk `name`, about their middle, facing `yaw`.
func save_chunk(name: String, names: Array, yaw: float) -> void:
	if name == "":
		say("a chunk needs a name (letters, digits, _ -)")
		return
	var c := Vector3.ZERO
	for n: String in names: c += Layout.current(n).origin
	c /= maxf(names.size(),1.0)
	var had := name in Chunks.names()
	var res: Array = Chunks.save(name,names,Transform3D(Basis(Vector3.UP,yaw),c.snappedf(SNAP)))
	if int(res[0]) != OK:
		say("chunk %s not saved: %s" % [name,"only rings and slabs go in a chunk" if int(res[0]) == ERR_INVALID_DATA else error_string(int(res[0]))])
		return
	say("%s chunk %s: %d pieces%s  (%s)" % ["replaced" if had else "saved",name,int(res[1]),"  (%d not rings or slabs left out)" % int(res[2]) if int(res[2]) > 0 else "",Chunks.file_of(name)])
	if _listing(): show_chunks(true)

## The chunk list on (J) or off: Up / Down pick, Enter or a click stamps
## (on the island under the view's middle; Shift: free), J / Esc closes.
func show_chunks(on: bool) -> void:
	if not on:
		if _chunk_panel != null: _chunk_panel.visible = false
		return
	if _chunk_panel == null:
		_chunk_panel = PanelContainer.new()
		_chunk_panel.name = "ChunkList"
		_chunk_panel.position = Vector2(16.0,268.0)
		var col := VBoxContainer.new()
		var l := Label.new()
		l.text = "CHUNKS  Up/Down pick   Enter or click: stamp where you look,\non the island under it (Shift: free)   J / Esc close"
		col.add_child(l)
		_chunk_list = ItemList.new()
		_chunk_list.custom_minimum_size = Vector2(420.0,180.0)
		_chunk_list.item_clicked.connect(func(i: int, _at: Vector2, button: int) -> void:
			if button == MOUSE_BUTTON_LEFT: stamp(_chunk_list.get_item_text(i),Input.is_key_pressed(KEY_SHIFT)))
		col.add_child(_chunk_list)
		_chunk_panel.add_child(col)
		_ui.add_child(_chunk_panel)
	var was := _chunk_list.get_selected_items()
	_chunk_list.clear()
	for n: String in Chunks.names(): _chunk_list.add_item(n)
	if _chunk_list.item_count > 0: _chunk_list.select(clampi(was[0] if not was.is_empty() else 0,0,_chunk_list.item_count-1))
	_chunk_panel.visible = true
	if _chunk_list.item_count == 0: say("no chunks yet in %s (select pieces, K to keep them)" % Chunks.dir())
	else: say("%d chunks" % _chunk_list.item_count)

## A key while the list is open: true if the list took it.
func _list_key(k: InputEventKey) -> bool:
	var n := _chunk_list.item_count
	var at := _chunk_list.get_selected_items()
	var i: int = at[0] if not at.is_empty() else 0
	match k.keycode:
		KEY_UP, KEY_DOWN:
			if n > 0:
				_chunk_list.select(clampi(i+(1 if k.keycode == KEY_DOWN else -1),0,n-1))
				_chunk_list.ensure_current_is_visible()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if not k.echo and n > 0: stamp(_chunk_list.get_item_text(i),k.shift_pressed)
			return true
		KEY_ESCAPE:
			show_chunks(false)
			return true
	return false

## Chunk `chunk` stamped where the view's middle looks (its lowest piece
## 1.5 m over what it hits), turned by the view as it was turned by the
## view it was kept from; its pieces on the island under that spot unless
## `free`. One record; selected as a group.
func stamp(chunk: String, free := false) -> void:
	if host == null:
		say("no pieces host here")
		return
	var pieces := Chunks.read(chunk)
	if pieces.is_empty():
		say("chunk %s has no rings or slabs to stamp" % chunk)
		return
	var cam: Camera3D = study.camera
	var from := cam.global_position
	var way := -cam.global_basis.z
	var lo := INF
	var reach := 0.0
	for p: Dictionary in pieces:
		var o: Vector3 = (p.t as Transform3D).origin
		lo = minf(lo,o.y)
		reach = maxf(reach,Vector2(o.x,o.z).length())
	var at := from+way*(ADD_OUT+reach)
	var on := ""
	var hit := _ray(from,way)
	if not hit.is_empty() and from.distance_to(hit.position) < STAMP_REACH:
		at = (hit.position as Vector3)+Vector3.UP*(1.5-lo)
		if not free: on = Islands.island_under(hit.position)
	var anchor := Transform3D(Basis(Vector3.UP,_view_yaw()),at.snappedf(SNAP))
	var prefix := Chunks.stamp_prefix(chunk)
	var made: Array = []
	var recs: Array = []
	var count := {}
	for p: Dictionary in pieces:
		var kind := str(p.kind)
		count[kind] = int(count.get(kind,0))+1
		var name := prefix+"%s_%d" % [kind,count[kind]]
		var t: Transform3D = anchor*(p.t as Transform3D)
		t.basis = t.basis.orthonormalized()
		var node := Layout.spawn(host,name,kind,t,float(p.pumps),p.size,on)
		if node == null: continue
		if on != "": _reanchor(name)
		made.append(name)
		recs.append({"do":"add","name":name})
	if made.is_empty(): return
	_push({"do":"group","name":"stamp:"+prefix,"recs":recs,"names":_chunk_names()})
	dirty = true
	_strips_stale = true
	select_group(made)
	say("stamped %s (%d pieces) %s" % [chunk,made.size(),"on "+on if on != "" else "free"])

# --- Undo ----------------------------------------------------------------------------

## A record on the stack (the oldest dropped past UNDO_MAX).
func _push(rec: Dictionary) -> void:
	rec["at"] = Time.get_ticks_msec()
	undos.append(rec)
	while undos.size() > UNDO_MAX: _drop(undos.pop_front())

## A nudge's record, unless the last record is the same nudge on the same
## object within NUDGE_MS (a burst of wheel ticks undoes as one).
func _nudged(rec: Dictionary, by: String) -> void:
	if not undos.is_empty():
		var last: Dictionary = undos.back()
		if str(last.get("by","")) == by and str(last.name) == str(rec.name) and Time.get_ticks_msec()-int(last.at) < NUDGE_MS:
			last.at = Time.get_ticks_msec()
			return
	rec["by"] = by
	_push(rec)

## The drag let go: its start made a record if it moved.
func _record_drag() -> void:
	if _drag_from == null: return
	var from: Variant = _drag_from
	_drag_from = null
	if selected == "": return
	if is_island(selected):
		if not Layout._same(from,Islands.islands[selected].xf): _push({"do":"island","name":selected,"xf":from})
	elif Layout.entries.has(selected) and not Layout._same(from,Layout.current(selected)):
		_push({"do":"pose","name":selected,"t":from})

## A record no longer undoable: a deleted piece it held freed.
func _drop(rec: Dictionary) -> void:
	if str(rec.do) == "group":
		for r: Dictionary in rec.recs: _drop(r)
		return
	if str(rec.do) != "delete" or not rec.has("parent"): return
	var node: Variant = rec.node
	if is_instance_valid(node) and not (node as Node).is_inside_tree(): (node as Node).free()

func _exit_tree() -> void:
	for rec: Dictionary in undos: _drop(rec)
	undos = []

## The last action taken back (Ctrl/Cmd+Z): a move, lift, turn or tip put
## back where it stood, a size back, an added or copied piece taken out, a
## deleted one put back, an island put back where it was (what stands on it
## carried back with it).
func undo() -> void:
	if _dragging or not _grab.is_empty(): return
	while not undos.is_empty():
		var rec: Dictionary = undos.pop_back()
		if not _undo_one(rec): continue
		dirty = true
		_strips_stale = true
		say("undid %s %s (%d more)" % [rec.do,rec.name,undos.size()])
		return
	say("nothing to undo")

## Record `rec` undone; false if what it names is gone (then the next
## record is undone instead). A group's records undo last first, and the
## group is selected again.
func _undo_one(rec: Dictionary) -> bool:
	var name := str(rec.name)
	match str(rec.do):
		"group":
			var any := false
			var recs: Array = rec.recs
			for k in range(recs.size()-1,-1,-1):
				if _undo_one(recs[k]): any = true
			select_group(rec.get("names",[]))
			return any
		"pose":
			if not Layout.entries.has(name) or not is_instance_valid(Layout.entries[name].node): return false
			Layout.apply(name,rec.t)
			select(name)
			_reanchor(name)
		"size":
			if not Layout.entries.has(name) or not is_instance_valid(Layout.entries[name].node): return false
			(Layout.entries[name].node as Node).layout_resize(rec.size)
			select(name)
		"island":
			if not is_island(name): return false
			select(name)
			_grab = _take(name)
			Islands.move(_grab,rec.xf)
			_settle()
		"add":
			if not Layout.entries.has(name): return false
			if selected == name or name in group: select("")
			var gone_rec := _remove(name)
			_drop(gone_rec)
		"delete":
			var node: Node3D = rec.node
			if not is_instance_valid(node): return false
			if rec.has("parent"):
				var parent: Node = rec.parent
				if not is_instance_valid(parent): return false
				parent.add_child(node)
				parent.move_child(node,mini(int(rec.index),parent.get_child_count()-1))
			else:
				node.visible = true
				for l: Array in rec.get("layers",[]):
					if is_instance_valid(l[0]):
						(l[0] as CollisionObject3D).collision_layer = int(l[1])
						(l[0] as CollisionObject3D).collision_mask = int(l[2])
			Layout.entries[name] = rec.entry
			if host != null:
				for list: String in rec.lists: (host.get(list) as Array).append(node)
			var on := str(rec.on)
			if on != "" and Islands.islands.has(on): (Islands.islands[on].members as Array).append(node)
			if bool(rec.get("gone",false)): gone.erase(name)
			select(name)
	return true

func save() -> void:
	var err := Layout.save(gone,Islands.moves())
	if err == OK:
		saves += 1
		dirty = false
		say("saved %s" % Layout.path)
	else: say("save failed (%s): %s" % [error_string(err),Layout.path])

# --- Islands -------------------------------------------------------------------------

func is_island(name: String) -> bool:
	return Islands.islands.has(name)

## True (and said) when the selection is an island: it moves and turns,
## but doesn't tip, copy or go.
func _island_held() -> bool:
	if not is_island(selected): return false
	say("an island moves and turns (drag, wheel, Z X); it doesn't tip, copy or delete")
	return true

## The selected island taken (its flora carried with it the first time).
func _take(name: String) -> Dictionary:
	var began := Time.get_ticks_msec()
	var first := not bool(Islands.islands[name].flora)
	var g := Islands.grab(name,study)
	if first: print("world view: %s taken, its flora carried, in %d ms" % [name,Time.get_ticks_msec()-began])
	return g

## The selected island moved by `d` (world) at once, and let go.
func _island_step(d: Transform3D) -> void:
	if not _dragging: _nudged({"do":"island","name":selected,"xf":Islands.islands[selected].xf},"island")
	if _grab.is_empty(): _grab = _take(selected)
	Islands.move(_grab,d*(Islands.islands[selected].xf as Transform3D))
	dirty = true
	_settle()

## The taken island let go: its outline, pools, paths and turf outlines
## redone where it went (scripts/world_islands.gd `settle`).
func _settle() -> void:
	var began := Time.get_ticks_usec()
	Islands.settle(_grab,study)
	_grab = {}
	_strips_stale = true
	print("world view: %s let go, refreshed in %.1f ms" % [selected,(Time.get_ticks_usec()-began)/1000.0])
	_show_status()

## From the selected piece to the island it stands on (or over).
func step_out() -> void:
	if selected == "" or is_island(selected): return
	var e: Dictionary = Layout.entries[selected]
	var on := Islands.island_of(e.node)
	if on == "": on = Islands.island_under(Layout.current(selected).origin)
	if on == "":
		say("%s stands on no island (a free piece)" % selected)
		return
	select(on)

## The island view (spec goal 4): the selected island opened alone in the
## motif editor (studies/motif_editor.tscn `--island=`), its recipe
## `motifs/authored/isle_<name>.json` if it has one. Unsaved world-view
## changes are saved first (the layout file), so coming back rebuilds them.
## The editor is told where it came from (`--world-scene=`) and gets the
## same launch flags (the ledger, the layout file) for the way back.
const ISLAND_VIEW := "res://studies/motif_editor.tscn"
var opened_island := ""
func open_island() -> void:
	if not is_island(selected):
		say("select an island first (click its ground, or U from a piece on it)")
		return
	if dirty: save()
	opened_island = selected
	var args := PackedStringArray(["--island="+selected,"--world-scene="+get_tree().current_scene.scene_file_path])
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if not a.begins_with("--island=") and not a.begins_with("--world-scene=") and not a in args: args.append(a)
	print("world view: opening %s alone in the motif editor (%s)" % [selected," ".join(args)])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preload("res://scripts/launch_args.gd").open_scene(get_tree(),ISLAND_VIEW,args)

# --- The landing strips --------------------------------------------------------------

## Island `name`'s longest clear run (m) where it stands now.
func _strip_of(name: String) -> float:
	var i: Dictionary = Islands.islands[name]
	return float(study.longest_run(i.outline,Islands.rim_y(i),STRIP_CAP))

## Every island's run looked at again (after a change is let go), and the
## warning shown for those that lost theirs.
func check_strips() -> void:
	_strips_stale = false
	if strip_first.is_empty(): return
	var began := Time.get_ticks_msec()
	for name: String in strip_first: strip_now[name] = _strip_of(name)
	print("world view: landing runs again in %d ms: %s" % [Time.get_ticks_msec()-began,_strip_line(strip_now)])
	_show_warn()

## The islands whose run fell short of their first.
func strips_lost() -> Array:
	var out: Array = []
	for name: String in strip_first:
		if float(strip_now.get(name,0.0)) < float(strip_first[name])-STRIP_SLACK: out.append(name)
	return out

## The links' jumps (scripts/world_islands.gd `link_gaps`) the islands'
## moves made longer or shorter than built by more than GAP_SLACK:
## [[link, label, now, built]].
const GAP_SLACK := 0.5
func gaps_changed() -> Array:
	var out: Array = []
	for name: String in Islands.links:
		for g: Array in Islands.link_gaps(name):
			if absf(float(g[2])-float(g[1])) > GAP_SLACK: out.append([name,g[0],g[2],g[1]])
	return out

static func _strip_line(runs: Dictionary) -> String:
	var parts := PackedStringArray()
	for name: String in runs: parts.append("%s %.0f m" % [name,float(runs[name])])
	return ", ".join(parts)

func _show_warn() -> void:
	if _warn == null: return
	var lines := PackedStringArray()
	for name: String in strips_lost():
		lines.append("LANDING STRIP: %s's longest clear run is %.0f m (was %.0f m)" % [name,float(strip_now[name]),float(strip_first[name])])
	var by_link := {}
	for gap: Array in gaps_changed():
		if not by_link.has(gap[0]): by_link[gap[0]] = []
		(by_link[gap[0]] as Array).append("%s %.1f m (was %.1f)" % [gap[1],gap[2],gap[3]])
	for name: String in by_link:
		lines.append("LINK: %s: %s" % [name,", ".join(PackedStringArray(by_link[name]))])
	_warn.text = "\n".join(lines)
	_warn.visible = not lines.is_empty()

# --- Selection and text ----------------------------------------------------------------

func select(name: String) -> void:
	group = []
	selected = name if Layout.entries.has(name) or is_island(name) else ""
	_show_box()
	_show_status()

## A box round the selected object's drawn bounds, a child of it (it
## follows with no work a frame), drawn over everything.
func _show_box() -> void:
	if _box == null:
		_box = MeshInstance3D.new()
		_box.name = "LayoutSelection"
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0,0.85,0.2)
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_box.material_override = mat
		_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _box.get_parent() != null: _box.get_parent().remove_child(_box)
	for b: Variant in _boxes:
		if is_instance_valid(b): (b as Node).free()
	_boxes = []
	if selected == "": return
	# The group's others: a box each, the same look.
	for n: String in group:
		if n == selected or not Layout.entries.has(n): continue
		var on: Node3D = Layout.entries[n].node
		var extra := MeshInstance3D.new()
		extra.name = "LayoutSelectionGroup"
		extra.material_override = _box.material_override
		extra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra.mesh = _wire_box(_drawn_box(on).grow(0.15))
		on.add_child(extra)
		_boxes.append(extra)
	if is_island(selected):
		var i: Dictionary = Islands.islands[selected]
		var land: Node3D = i.node
		_box.mesh = _island_wire(i,land.global_transform.affine_inverse())
		land.add_child(_box)
		_box.transform = Transform3D.IDENTITY
		return
	var node: Node3D = Layout.entries[selected].node
	var box := _drawn_box(node)
	_box.mesh = _wire_box(box.grow(0.15))
	node.add_child(_box)
	_box.transform = Transform3D.IDENTITY

## `node`'s drawn bounds in its own space.
static func _drawn_box(node: Node3D) -> AABB:
	var inv := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for c: Node in node.find_children("*","VisualInstance3D",true,false):
		var v := c as VisualInstance3D
		if v.name == "LayoutSelection" or v.name.begins_with("LayoutSelectionGroup") or v.name.begins_with("ThrowArrow") or not v.is_visible_in_tree(): continue
		var b := (inv*v.global_transform)*v.get_aabb()
		if b.size == Vector3.ZERO: continue
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-1.0,-1.0,-1.0),Vector3(2.0,2.0,2.0))

static func _wire_box(b: AABB) -> ImmediateMesh:
	var m := ImmediateMesh.new()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	_box_lines(m,b,Transform3D.IDENTITY)
	m.surface_end()
	return m

static func _box_lines(m: ImmediateMesh, b: AABB, to: Transform3D, tint := Color.WHITE) -> void:
	m.surface_set_color(tint)
	for i in range(12):
		var a: int = [0,1,3,2,4,5,7,6,0,1,3,2][i]
		var c: int = [1,3,2,0,5,7,6,4,4,5,7,6][i]
		m.surface_add_vertex(to*b.get_endpoint(a))
		m.surface_add_vertex(to*b.get_endpoint(c))

## An island's outline drawn twice round its rim (at its drawn top, and
## 0.6 m under), and a box round each thing that stands on it (world
## bounds, into the land's space by `to`).
static func _island_wire(i: Dictionary, to: Transform3D) -> ImmediateMesh:
	var m := ImmediateMesh.new()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	var outline: PackedVector2Array = i.outline
	var y := Islands.rim_y(i)
	for k in range(outline.size()):
		var a := outline[k]
		var b := outline[(k+1)%outline.size()]
		for h: float in [y,y-0.6]:
			m.surface_set_color(Color.WHITE)
			m.surface_add_vertex(to*Vector3(a.x,h,a.y))
			m.surface_add_vertex(to*Vector3(b.x,h,b.y))
	for n: Node3D in i.members:
		if not is_instance_valid(n): continue
		var b := Islands.drawn_box(n)
		if b.size != Vector3.ZERO: _box_lines(m,b.grow(0.1),to,MEMBER_TINT)
	m.surface_end()
	return m

func say(line: String) -> void:
	_said = line
	_show_status()

func _build_ui() -> void:
	if _ui != null: return
	_ui = CanvasLayer.new()
	_ui.name = "LayoutEditUI"
	_ui.layer = 50
	add_child(_ui)
	var hint := Label.new()
	hint.text = HINT
	hint.position = Vector2(16.0,12.0)
	hint.add_theme_color_override("font_color",Color(1.0,0.95,0.8))
	hint.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.85))
	hint.add_theme_constant_override("outline_size",5)
	hint.add_theme_font_size_override("font_size",15)
	_ui.add_child(hint)
	_status = Label.new()
	_status.position = Vector2(16.0,218.0)
	_status.add_theme_color_override("font_color",Color(1.0,0.85,0.3))
	_status.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.85))
	_status.add_theme_constant_override("outline_size",5)
	_status.add_theme_font_size_override("font_size",16)
	_ui.add_child(_status)
	_warn = Label.new()
	_warn.name = "StripWarning"
	# Top right, clear of the keys' hint on the left.
	_warn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_warn.offset_left = -700.0
	_warn.offset_right = -16.0
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.offset_top = 16.0
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_warn.add_theme_color_override("font_color",Color(1.0,0.45,0.3))
	_warn.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.9))
	_warn.add_theme_constant_override("outline_size",6)
	_warn.add_theme_font_size_override("font_size",20)
	_warn.visible = false
	_ui.add_child(_warn)

func _show_status() -> void:
	if _status == null: return
	var line := "nothing selected"
	if is_island(selected):
		var i: Dictionary = Islands.islands[selected]
		var c: Vector2 = (i.rect as Rect2).get_center()
		var xf: Transform3D = i.xf
		line = "%s  (island)  %d things stand on it  middle %.1f, %.1f" % [selected,(i.members as Array).size(),c.x,c.y]
		if xf != Transform3D.IDENTITY: line += "  moved %.1f, %.1f, %.1f  turned %.0f" % [xf.origin.x,xf.origin.y,xf.origin.z,rad_to_deg(xf.basis.get_euler().y)]
	elif not group.is_empty():
		var c := group_mid()
		var names := PackedStringArray()
		for n: String in group.slice(0,4): names.append(n)
		line = "group of %d  (%s%s)  middle %.1f, %.1f, %.1f" % [group.size(),", ".join(names)," ..." if group.size() > 4 else "",c.x,c.y,c.z]
	elif selected != "":
		var t := Layout.current(selected)
		var e := t.basis.get_euler()
		line = "%s  (%s)  at %.2f, %.2f, %.2f  yaw %.0f  tip %.0f" % [selected,Layout.entries[selected].kind,t.origin.x,t.origin.y,t.origin.z,rad_to_deg(e.y),rad_to_deg(e.x)]
		var sz := size_text(selected)
		if sz != "": line += "  size "+sz
	_status.text = line+("   [unsaved]" if dirty else "")+("\n"+_said if _said != "" else "")
