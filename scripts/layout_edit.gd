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

const TOGGLE := KEY_F4
const LOOK_RATE := 0.004
const PICK_PX := 28.0
## A pick's screen reach round a ring's or a slab's middle (m).
const REACH := {"air_ring":AirRing.RADIUS+0.3,"bob_slab":1.5}
const LIFT := 0.25
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
Z / X  turn 15 deg (Shift 5)    T / G  tip 15 deg    C  duplicate    Del / Backspace  delete
1  add air ring    2  add bob slab    3  add ring-stair slab (7 pumps)
click an island's ground: the island    U  from a piece to the island it stands on    O  open the island alone (motif editor)
Ctrl/Cmd+S  save"""

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
	if not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
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
				if mb.pressed: click(mb.position)
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
		KEY_Z: turn(5.0 if fine else TURN)
		KEY_X: turn(-5.0 if fine else -TURN)
		KEY_T: tip(5.0 if fine else TURN)
		KEY_G: tip(-5.0 if fine else -TURN)
		KEY_C: if not k.echo and not cmd: duplicate_selected()
		KEY_DELETE, KEY_BACKSPACE: if not k.echo: delete_selected()
		KEY_1: if not k.echo: add("air_ring")
		KEY_2: if not k.echo: add("bob_slab")
		KEY_3: if not k.echo: add("bob_slab",RING_SLAB_PUMPS)
		KEY_U: if not k.echo: step_out()
		KEY_O: if not k.echo and not cmd: open_island()

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
		var mid: Vector3 = (e.node as Node3D).global_position
		if cam.is_position_behind(mid): continue
		var r: float = REACH[e.kind]
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
	if best != "" and best_d-float(REACH[Layout.entries[best].kind]) <= hit_d: return best
	return hit_name

func click(at: Vector2) -> void:
	var name := pick(at)
	select(name)
	if name == "": return
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
		_drag_off = Vector3(_grab_pivot.x-q.x,0.0,_grab_pivot.z-q.z)
		_dragging = true
		return
	# Dragged in the level plane through its middle, held where it was taken.
	var t := Layout.current(name)
	_drag_y = t.origin.y
	var p := _on_level(at,_drag_y)
	_drag_off = t.origin-p if p != Vector3.INF else Vector3.ZERO
	_dragging = p != Vector3.INF

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

## The mouse up: an island let go (what reads its place redone).
func let_go() -> void:
	_dragging = false
	if not _grab.is_empty(): _settle()

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
	var t := Layout.current(selected)
	var to := p+_drag_off
	t.origin = Vector3(snappedf(to.x,SNAP),t.origin.y,snappedf(to.z,SNAP))
	_put(selected,t)

func lift(dy: float) -> void:
	if selected == "": return
	if is_island(selected):
		_island_step(Transform3D(Basis.IDENTITY,Vector3.UP*dy))
		return
	var t := Layout.current(selected)
	t.origin.y = snappedf(t.origin.y+dy,SNAP)
	_drag_y += dy
	_put(selected,t)

## Turned `deg` about the world's up, round its own middle.
func turn(deg: float) -> void:
	if selected == "": return
	if is_island(selected):
		var c := Islands.pivot(selected)
		_island_step(Transform3D(Basis.IDENTITY,c)*Transform3D(Basis(Vector3.UP,deg_to_rad(deg)),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-c))
		return
	var t := Layout.current(selected)
	t.basis = Basis(Vector3.UP,deg_to_rad(deg))*t.basis
	_put(selected,t)

## Tipped `deg` about its own x.
func tip(deg: float) -> void:
	if selected == "" or _island_held(): return
	var t := Layout.current(selected)
	t.basis = t.basis*Basis(Vector3.RIGHT,deg_to_rad(deg))
	_put(selected,t)

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
	dirty = true
	select(name)

## A copy of the selected ring or slab, 3 m to the camera's right.
func duplicate_selected() -> void:
	if selected == "" or _island_held(): return
	var e: Dictionary = Layout.entries[selected]
	if not str(e.kind) in Layout.ADDABLE:
		say("only rings and slabs copy (not %s)" % e.kind)
		return
	var t := Layout.current(selected)
	var right: Vector3 = (study.camera as Camera3D).global_basis.x
	t.origin += Vector3(right.x,0.0,right.z).normalized()*3.0
	var name := Layout.fresh_name(str(e.kind))
	Layout.spawn(host,name,str(e.kind),t,float(e.get("pumps",0.0)))
	dirty = true
	select(name)

func delete_selected() -> void:
	if selected == "" or _island_held(): return
	var name := selected
	select("")
	var e: Dictionary = Layout.entries[name]
	var node: Node3D = e.node
	if host != null:
		(host.get("rings") as Array).erase(node)
		(host.get("slabs") as Array).erase(node)
		if host.get("on") == node: host.set("on",null)
	if str(e.kind) == "land":
		# Its turf stays registered (flora, outlines) until the reload: put
		# out of sight and out of the physics space, not freed.
		node.visible = false
		for c: Node in node.find_children("*","CollisionObject3D",true,false):
			(c as CollisionObject3D).collision_layer = 0
			(c as CollisionObject3D).collision_mask = 0
	else: node.queue_free()
	Layout.entries.erase(name)
	if not name.begins_with("added/") and not name in gone: gone.append(name)
	dirty = true
	_strips_stale = true
	say("deleted %s" % name)

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
	if selected == "": return
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
		if v.name == "LayoutSelection" or not v.is_visible_in_tree(): continue
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
	_status.position = Vector2(16.0,196.0)
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
	elif selected != "":
		var t := Layout.current(selected)
		var e := t.basis.get_euler()
		line = "%s  (%s)  at %.2f, %.2f, %.2f  yaw %.0f  tip %.0f" % [selected,Layout.entries[selected].kind,t.origin.x,t.origin.y,t.origin.z,rad_to_deg(e.y),rad_to_deg(e.x)]
	_status.text = line+("   [unsaved]" if dirty else "")+("\n"+_said if _said != "" else "")
