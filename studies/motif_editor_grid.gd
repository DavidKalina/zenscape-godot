extends Node3D
## The motif editor's pilot grid (loop editor-traps): a grid shown round
## the cursor whose cell is the pilot's own reach, not metres typed in.
## H (or the "Grid" button under the look label) turns it on and off; off
## by default.
##
## The cell is one plain jump carried at a run: the motor's first jump
## height (`jumps[0]`, fitted to his size by PilotMotor.set_size) and run
## pace under GRAVITY, the sum `tools/kit_piece.py numbers` reports as
## carry_jump0 (2.381 m at size 1). Heights go in ledge steps: RuinKit's
## SET_OFF (1.6 m), the rise the kit's set-offs and broken steps climb by,
## under GRAB_TOP (a lip one plain jump catches).
##
## The grid is fixed to the world (cell centres at whole multiples of the
## cell from the origin, levels at whole steps from y 0), so it stays put
## through edits and loads, and the yard builds in the same frame.
##
## With it on: a trap that does not snap to a lip or a piece's top sets
## its way in on the centre of the cell under the cursor and sits on the
## ground there, as everywhere else in the editor ("on": "grid"). Holding
## STEP_KEY (T) snaps its height to ledge steps for a stepped layout: the
## level nearest the ground, raised only as far as needed not to bury the
## trap's footprint ("on": "ledge"). Both re-seat by their rule on load and
## on land edits; the yard keeps the saved y. A kit piece that does not snap to a connector
## stands on a cell centre; its height stays the kit's seat on the land
## (pieces stand from the ground on every build, so a stepped height would
## not survive a load).

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## Cells drawn out from the cursor's cell each way.
const REACH := 3
## Draped lines sampled this often (m).
const SAMPLE := 0.4
const LINE := Color(1.0,0.93,0.72,0.9)
const LEVEL := Color(0.45,0.85,1.0,0.95)

var editor: Node
var on := false
var _mesh: MeshInstance3D
var _im: ImmediateMesh
var _label: Label
var _button: Button
## The cell drawn round last (its centre, level y), for drivers.
var shown_cell := Vector3.INF

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	name = "PilotGrid"
	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.name = "GridLines"
	_mesh.mesh = _im
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 2
	_mesh.material_override = mat
	_mesh.visible = false
	add_child(_mesh)
	var layer := CanvasLayer.new()
	layer.name = "GridReadout"
	layer.layer = 7
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -520.0
	box.offset_right = -16.0
	box.offset_top = 44.0
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	_button = Button.new()
	_button.name = "GridButton"
	_button.focus_mode = Control.FOCUS_NONE
	_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_button.add_theme_font_size_override("font_size",16)
	_button.pressed.connect(toggle)
	box.add_child(_button)
	_label = Label.new()
	_label.name = "GridLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size",16)
	_label.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.55))
	_label.add_theme_constant_override("outline_size",5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	_show_readout()

## One plain jump's carry at a run, from the motor's real numbers (m).
func cell() -> float:
	var m: Variant = editor.get("motor") if editor != null else null
	var h := float(PilotMotor.JUMPS[0])
	var run := PilotMotor.RUN
	if m is PilotMotor:
		h = float((m as PilotMotor).jumps[0])
		run = (m as PilotMotor).run
	return run*2.0*sqrt(2.0*h/PilotMotor.GRAVITY)

## Held while placing or dragging a trap: heights in ledge steps.
const STEP_KEY := KEY_T

static func stepping() -> bool:
	return Input.is_key_pressed(STEP_KEY)

## A ledge step (m).
static func step() -> float:
	return RuinKit.SET_OFF

## How far a ledge-stepped trap may sit under the ground under it (a trap
## sunk into the land is broken).
const SINK := 0.05

## The ledge level nearest ground height `y`.
static func nearest(y: float) -> float:
	return roundf(y/step())*step()

## A ledge-stepped trap's y: the level nearest the ground at `mid`, raised
## (not to the next step, only as far as needed) to SINK under the highest
## ground under its footprint `foot` (local xz points, turned `turn` deg
## about `mid`), so it is never buried.
static func ledge_y(g: Callable, mid: Vector2, foot: PackedVector2Array, turn := 0.0) -> float:
	var y := nearest(float(g.call(mid.x,mid.y)))
	var top := -INF
	for q: Vector2 in foot:
		var w := mid+q.rotated(-deg_to_rad(turn))
		top = maxf(top,float(g.call(w.x,w.y)))
	if top > -INF: y = maxf(y,top-SINK)
	return y

## The centre of the cell holding ground point `p`.
func centre(p: Vector2) -> Vector2:
	var c := cell()
	return Vector2(roundf(p.x/c)*c,roundf(p.y/c)*c)

func readout() -> String:
	return "1 cell = one plain jump at a run, %.2f m · traps sit on the ground; hold T for ledge steps of %.2f m (a jump catches %.2f m)" % [cell(),step(),RuinKit.GRAB_TOP]

func toggle() -> void:
	on = not on
	_show_readout()
	if editor != null:
		editor.say("Pilot grid on: %s" % readout() if on else "Pilot grid off")
	if not on: _mesh.visible = false

func _show_readout() -> void:
	if _button != null: _button.text = "Grid: %s  (H)" % ("on" if on else "off")
	if _label != null:
		_label.visible = on
		_label.text = readout()

## The readout and lines only while editing.
func _process(_delta: float) -> void:
	if editor == null: return
	var v: bool = editor.editing
	var layer := get_node_or_null("GridReadout") as CanvasLayer
	if layer != null and layer.visible != v: layer.visible = v
	if not v: _mesh.visible = false

## The grid drawn round the ground under screen point `at` (hidden off the
## land, off, or not editing).
func show_at(at: Vector2) -> void:
	if not on or not editor.editing or editor.motif == null:
		_mesh.visible = false
		return
	var hit: Dictionary = editor.ground_hit(at)
	if hit.is_empty():
		_mesh.visible = false
		return
	draw_round(Vector2(hit.position.x,hit.position.z))

func draw_round(p: Vector2) -> void:
	var g: Callable = editor.motif.ground_fn()
	var c := cell()
	var mid := centre(p)
	var y := float(g.call(mid.x,mid.y))
	if stepping(): y = nearest(y)
	shown_cell = Vector3(mid.x,y,mid.y)
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var lift := 0.06
	# Cell edges sit half a cell from the centres.
	var lo := -float(REACH)-0.5
	var hi := float(REACH)+0.5
	var span := (hi-lo)*c
	var n := maxi(2,ceili(span/SAMPLE))
	for i in range(REACH*2+2):
		var off := (lo+float(i))*c
		for axis in range(2):
			for s in range(n):
				var t0 := lo*c+span*float(s)/n
				var t1 := lo*c+span*float(s+1)/n
				var a := mid+(Vector2(off,t0) if axis == 0 else Vector2(t0,off))
				var b := mid+(Vector2(off,t1) if axis == 0 else Vector2(t1,off))
				var fade := 1.0-clampf(((a+b)*0.5-mid).length()/(span*0.5),0.0,1.0)
				var col := Color(LINE.r,LINE.g,LINE.b,LINE.a*fade)
				_im.surface_set_color(col)
				_im.surface_add_vertex(Vector3(a.x,float(g.call(a.x,a.y))+lift,a.y))
				_im.surface_set_color(col)
				_im.surface_add_vertex(Vector3(b.x,float(g.call(b.x,b.y))+lift,b.y))
	# The cell under the cursor at its ledge level, its corners dropped to
	# the ground, and a cross on its centre.
	var h := c*0.5
	var corners := [mid+Vector2(-h,-h),mid+Vector2(h,-h),mid+Vector2(h,h),mid+Vector2(-h,h)]
	for k in range(4):
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k+1)%4]
		_line(Vector3(a.x,y+lift,a.y),Vector3(b.x,y+lift,b.y),LEVEL)
		_line(Vector3(a.x,y+lift,a.y),Vector3(a.x,float(g.call(a.x,a.y)),a.y),Color(LEVEL,0.5))
	var q := c*0.12
	_line(Vector3(mid.x-q,y+lift,mid.y),Vector3(mid.x+q,y+lift,mid.y),LEVEL)
	_line(Vector3(mid.x,y+lift,mid.y-q),Vector3(mid.x,y+lift,mid.y+q),LEVEL)
	_im.surface_end()
	_mesh.visible = true

func _line(a: Vector3, b: Vector3, col: Color) -> void:
	_im.surface_set_color(col)
	_im.surface_add_vertex(a)
	_im.surface_set_color(col)
	_im.surface_add_vertex(b)

## Where a trap goes on the grid for ground point `p`: on the ground at the
## cell centre, or (`stepped`) at ledge_y for footprint `foot` turned
## `turn`. {position, on} or {}.
func trap_spot(p: Vector2, stepped := false, foot := PackedVector2Array(), turn := 0.0) -> Dictionary:
	if not on or editor.motif == null: return {}
	var mid := centre(p)
	var g: Callable = editor.motif.ground_fn()
	if stepped: return {"position":Vector3(mid.x,ledge_y(g,mid,foot,turn),mid.y),"on":"ledge"}
	return {"position":Vector3(mid.x,float(g.call(mid.x,mid.y)),mid.y),"on":"grid"}
