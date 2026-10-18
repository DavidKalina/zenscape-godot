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
const HINT := """LAYOUT EDIT  (F4: back to play, he drops where you look)
RMB hold + move  look      W A S D / Q E  fly / down, up    Shift  fast
LMB  select, drag to move (at its height)     wheel / PgUp PgDn  height (Shift: 1 m)
Z / X  turn 15 deg (Shift 5)    T / G  tip 15 deg    C  duplicate    Del / Backspace  delete
1  add air ring    2  add bob slab    3  add ring-stair slab (7 pumps)
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

func setup(scene: Node3D, pieces: Node3D) -> void:
	study = scene
	host = pieces
	var was: Array = Layout.data.get("deleted",[])
	gone = was.duplicate()
	set_process(false)

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
	get_viewport().set_input_as_handled()

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
	say("%d named objects" % Layout.entries.size())

## Back to play: he is dropped where the camera's middle looks (on what it
## hits), facing the view, else back where he stood.
func leave() -> void:
	_dragging = false
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
				else: _dragging = false
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

func drag_to(at: Vector2) -> void:
	if selected == "": return
	var p := _on_level(at,_drag_y)
	if p == Vector3.INF: return
	var t := Layout.current(selected)
	var to := p+_drag_off
	t.origin = Vector3(snappedf(to.x,SNAP),t.origin.y,snappedf(to.z,SNAP))
	_put(selected,t)

func lift(dy: float) -> void:
	if selected == "": return
	var t := Layout.current(selected)
	t.origin.y = snappedf(t.origin.y+dy,SNAP)
	_drag_y += dy
	_put(selected,t)

## Turned `deg` about the world's up, round its own middle.
func turn(deg: float) -> void:
	if selected == "": return
	var t := Layout.current(selected)
	t.basis = Basis(Vector3.UP,deg_to_rad(deg))*t.basis
	_put(selected,t)

## Tipped `deg` about its own x.
func tip(deg: float) -> void:
	if selected == "": return
	var t := Layout.current(selected)
	t.basis = t.basis*Basis(Vector3.RIGHT,deg_to_rad(deg))
	_put(selected,t)

func _put(name: String, t: Transform3D) -> void:
	Layout.apply(name,t)
	dirty = true
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
	if selected == "": return
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
	if selected == "": return
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
	say("deleted %s" % name)

func save() -> void:
	var err := Layout.save(gone)
	if err == OK:
		saves += 1
		dirty = false
		say("saved %s" % Layout.path)
	else: say("save failed (%s): %s" % [error_string(err),Layout.path])

# --- Selection and text ----------------------------------------------------------------

func select(name: String) -> void:
	selected = name if Layout.entries.has(name) else ""
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
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_box.material_override = mat
		_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _box.get_parent() != null: _box.get_parent().remove_child(_box)
	if selected == "": return
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
	for i in range(12):
		var a: int = [0,1,3,2,4,5,7,6,0,1,3,2][i]
		var c: int = [1,3,2,0,5,7,6,4,4,5,7,6][i]
		m.surface_add_vertex(b.get_endpoint(a))
		m.surface_add_vertex(b.get_endpoint(c))
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
	_status.position = Vector2(16.0,150.0)
	_status.add_theme_color_override("font_color",Color(1.0,0.85,0.3))
	_status.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.85))
	_status.add_theme_constant_override("outline_size",5)
	_status.add_theme_font_size_override("font_size",16)
	_ui.add_child(_status)

func _show_status() -> void:
	if _status == null: return
	var line := "nothing selected"
	if selected != "":
		var t := Layout.current(selected)
		var e := t.basis.get_euler()
		line = "%s  (%s)  at %.2f, %.2f, %.2f  yaw %.0f  tip %.0f" % [selected,Layout.entries[selected].kind,t.origin.x,t.origin.y,t.origin.z,rad_to_deg(e.y),rad_to_deg(e.x)]
	_status.text = line+("   [unsaved]" if dirty else "")+("\n"+_said if _said != "" else "")
