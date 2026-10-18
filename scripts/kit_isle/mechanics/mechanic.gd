extends "res://scripts/traps/trap.gd"
## A mechanic placed on a motif (scripts/kit_isle/motif_mechanics.gd): a
## trap that holds one of the aqueduct isle's foot pieces (an air ring, a
## slab, a rope: scripts/interactables/foot_pieces.gd's host methods) in a
## FootPieces of its own, so the piece is built and stepped exactly as on
## the isle.
##
## The trap's own frame is where the editor set it down (on the ground,
## turned); `lay` places the pieces in the world from it (FootPieces works
## in the world's frame, so its node is `top_level` at the origin). Moved or
## turned (the editor's drag), the pieces are laid again at the end of the
## frame. Stepping (`before`, `after`, `rope_pose`) is handed to the FootPieces,
## which looks the study up the tree (its ground mask, its updraft) the
## first time it runs. `reset` lays them again as built.
##
## While editing, a faint line (`hint_path`) shows what is not obvious from
## the piece: how high it floats over its spot, a drift's path. Playing, it
## hides.
##
## A subclass overrides `defaults` (calling super's) and `lay`, and
## `hint_path` if it has more to show.

const HINT := Color(0.98,0.85,0.35,0.7)

## The FootPieces holding the laid pieces (null before `build`).
var host: Node3D = null
var study: Node3D = null
var hint: MeshInstance3D = null
var live_on := false
var _relay := false

func _init() -> void:
	super()
	cost = 1
	set_notify_transform(true)

func defaults() -> Dictionary:
	return {"seed":0}

func build() -> void:
	_lay()

## The pieces laid in the world from `frame` (the trap's own) into `pieces`
## (a FootPieces at the origin). Override.
func lay(_pieces: Node3D, _frame: Transform3D) -> void:
	pass

## The hint's line in the world ([] none): by default from the spot up to
## `lift_point()`.
func hint_path() -> PackedVector3Array:
	var top := lift_point()
	if top == Vector3.INF: return PackedVector3Array()
	return PackedVector3Array([global_position,top])

## Where the piece floats (world), INF if it doesn't.
func lift_point() -> Vector3:
	if not knobs.has("lift"): return Vector3.INF
	return global_transform*Vector3(0.0,float(knobs.lift),0.0)

## The frame's turn about up (rad).
static func yaw_of(frame: Transform3D) -> float:
	return frame.basis.get_euler().y

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and host != null and is_inside_tree() and not _relay and not live_on:
		_relay = true
		_lay.call_deferred()

func _lay() -> void:
	_relay = false
	if not is_inside_tree(): return
	if host != null:
		if motor != null and motor.rider != null and motor.rider in host.ropes: motor.toss(motor.velocity)
		remove_child(host)
		host.free()
	host = load("res://scripts/roguelike/layer_greybox.gd").FootPieces.new()
	host.name = "Pieces"
	host.top_level = true
	add_child(host)
	host.global_transform = Transform3D.IDENTITY
	host.study = study
	host.motor = motor
	lay(host,global_transform)
	if hint != null:
		remove_child(hint)
		hint.free()
		hint = null
	var path := hint_path()
	if path.size() >= 2:
		hint = _line(path)
		hint.visible = not live_on
		add_child(hint)
	if name == "TrapGhost":
		for g: GeometryInstance3D in host.find_children("*","GeometryInstance3D",true,false):
			g.transparency = 0.45
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _line(path: PackedVector3Array) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = HINT
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,m)
	for p: Vector3 in path: mesh.surface_add_vertex(p)
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "Hint"
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The study (the character study whose motor this is) up the tree: the
## editor itself, or a TrapField's `study` in the game's host.
func find_study() -> Node3D:
	var n := get_parent()
	while n != null:
		if n.get("ground") != null and n.get("motor") != null: return n as Node3D
		var s: Variant = n.get("study")
		if s is Node3D and (s as Node3D).get("ground") != null: return s as Node3D
		n = n.get_parent()
	return null

## Live from the first step: the FootPieces given the study and motor.
func _wake() -> bool:
	if live_on: return host != null and host.study != null
	live_on = true
	if study == null: study = find_study()
	if host == null: return false
	host.study = study
	host.motor = motor
	if hint != null: hint.visible = false
	if study == null: push_warning("mechanic %s: no study up the tree; not stepped" % trap_name)
	woke()
	return study != null

## Called once when it goes live (a subclass's extra set-up).
func woke() -> void:
	pass

func before(delta: float) -> void:
	if _wake(): host.before(delta)

func after(delta: float, events: Dictionary) -> void:
	if live_on and host != null and host.study != null: host.after(delta,events)

## The drawn body along a rope it holds (TrapField `pose` hands it on).
func rope_pose(figure: Node3D) -> void:
	if live_on and host != null and host.study != null: host.pose(figure)

func reset() -> void:
	super.reset()
	live_on = false
	_lay()

## Its spot's local rect: the piece's size round the spot (for the grid's
## ledge seats).
func footprint() -> Rect2:
	return Rect2(-1.2,-1.2,2.4,2.4)
