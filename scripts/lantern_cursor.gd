extends Control
## Size and strength on the cursor, not in the bar: a ring of motes round the
## brush's ground circle (its size), five larger motes on the ring's front arc
## lit in the brush's tint for its strength, and a thin beam up from the
## centre carrying the brush, or the land form, in hand. Your eyes are on the
## cursor while you paint, so that is where the readout lives. Drawn in screen
## space over the terrain shader's own ring (NativeChunkEditor `brush_center`).
const Style = preload("res://scripts/lantern_style.gd")
const Forms = preload("res://scripts/mountain_forms.gd")
const MOTES := 40
const STRENGTH_MOTES := 5
const BEAM := 64.0

var scene: Node3D
var editor: NativeChunkEditor
var shell: Control
var _alpha := 0.0
var _puff := 0.0
var _spin := 0.0
var _ring := PackedVector2Array()
var _center := Vector2.ZERO

func setup(owner_scene: Node3D, owner_shell: Control) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	shell = owner_shell
	name = "LanternCursor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.stroke_moved.connect(func(_c: Vector3, _r: float, _m: String, amount: float) -> void:
		if amount > 0.0: _puff = minf(1.0,_puff+0.35))

func _wanted() -> bool:
	if not scene._creating() or editor._material == null: return false
	if editor.get("_ball_holding") == true: return false
	if not bool(editor._material.get_shader_parameter("brush_visible")): return false
	var mouse: Vector2 = editor.pointer_override if editor.pointer_override != null else get_viewport().get_mouse_position()
	return not shell.contains_pointer(mouse)

func _process(delta: float) -> void:
	var wanted := _wanted()
	_alpha = move_toward(_alpha,1.0 if wanted else 0.0,delta*(8.0 if wanted else 5.0))
	_puff = move_toward(_puff,0.0,delta*2.5)
	_spin += delta*0.12
	if _alpha > 0.0: _project()
	queue_redraw()

## The ground circle under the brush, sampled on the terrain so it hugs hills.
func _project() -> void:
	var camera: Camera3D = scene.camera
	var center: Vector2 = editor._material.get_shader_parameter("brush_center")
	var radius := editor.preview_radius()*(1.0+0.05*_puff)
	var data := editor.data
	_ring.resize(MOTES)
	for i in range(MOTES):
		var p := center+Vector2.from_angle(TAU*i/MOTES+_spin)*radius
		var h: Variant = data.ground_height(p)
		var world := editor.terrain.to_global(Vector3(p.x,float(h) if h != null else 0.0,p.y))
		_ring[i] = camera.unproject_position(world) if not camera.is_position_behind(world) else Vector2(-1e5,-1e5)
	var h0: Variant = data.ground_height(center)
	_center = camera.unproject_position(editor.terrain.to_global(Vector3(center.x,float(h0) if h0 != null else 0.0,center.y)))

func _draw() -> void:
	if _alpha <= 0.0 or _ring.is_empty(): return
	var k := Style.ui_scale(size)
	var brush := editor.held_brush()
	var tint := Style.tint(brush)
	var light := Color(Style.LIGHT,_alpha)
	# The front arc: the motes nearest the viewer (lowest on screen).
	var front := 0
	for i in range(MOTES):
		if _ring[i].y > _ring[front].y: front = i
	var strength := editor.brush_setting(brush,"strength")
	var lit := 0
	if not strength.is_empty():
		lit = clampi(roundi(inverse_lerp(strength.low,strength.high,strength.value)*STRENGTH_MOTES),1,STRENGTH_MOTES)
	var near := {}
	for j in range(STRENGTH_MOTES):
		near[posmod(front-STRENGTH_MOTES/2+j,MOTES)] = j
	for i in range(MOTES):
		var p := _ring[i]
		if p.x < -1e4: continue
		# Motes brighten toward the viewer.
		var depth := inverse_lerp(_center.y-(_ring[front].y-_center.y),_ring[front].y,p.y)
		if near.has(i):
			var on: bool = near[i] < lit
			draw_circle(p,3.6*k,Color(Style.SHADE,0.6*_alpha))
			draw_circle(p,2.6*k,Color(tint.lerp(Color("f2c27e"),0.35),_alpha) if on else Color(light,0.35*_alpha))
		else:
			draw_circle(p,2.2*k,Color(Style.SHADE,0.35*_alpha))
			draw_circle(p,1.35*k,Color(light,(0.45+0.5*clampf(depth,0.0,1.0))*_alpha))
	# The beam, and the brush or form in hand floating at its top.
	var top := _center-Vector2(0,BEAM*k)
	draw_line(_center,top+Vector2(0,15*k),Color(Style.SHADE,0.4*_alpha),3.0*k,true)
	draw_line(_center,top+Vector2(0,15*k),Color(light,0.8*_alpha),1.0*k,true)
	draw_circle(_center,2.4*k,light)
	var id := brush
	if brush == "land": id = str(Forms.form_entry(editor.land_form).get("glyph","land")) if editor.land_form != "hill" else "hill"
	if editor.get("other_way") == true: id = "lower"
	draw_circle(top,15*k,Color(Style.SHADE,0.72*_alpha))
	draw_arc(top,14.5*k,0,TAU,40,Color(tint,0.8*_alpha),1.2*k,true)
	draw_texture_rect(Style.glyph(id),Rect2(top-Vector2.ONE*11*k,Vector2.ONE*22*k),false,light)
