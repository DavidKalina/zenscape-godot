extends CanvasLayer
## The frame counter: fps, frame time (mean, worst 1 %, worst) over the last
## WINDOW frames, the main thread's split, the GPU's time and what was drawn
## (draw calls, objects, primitives). Shift+F4 shows and hides it anywhere (plain F4 is
## the world view's, scripts/layout_edit.gd); --perf starts it shown.
## "logic" is the main thread from one frame's draw to the next (input,
## physics, every script's process), "draw" the renderer's turn on it
## (culling, recording, waiting on the GPU), read off RenderingServer's
## frame_pre_draw and frame_post_draw. Performance's TIME_PROCESS reads
## more than the whole frame here, so it isn't shown.
## `attach(parent)` adds one (studies/kit_isle.gd).
##
## The GPU time is the root viewport's own measure (RenderingServer
## `viewport_get_measured_render_time_gpu`), a frame or two late; a frame
## bound by the GPU shows it near the frame time with the CPU well under.

const WINDOW := 120
const REFRESH := 0.25
const KEY := KEY_F4

var _label: Label
var _times := PackedFloat32Array()
var _at := 0
var _since := 0.0
var _vp := RID()
var _pre := 0
var _post := 0
var _logic := 0.0
var _draw := 0.0

static func attach(parent: Node) -> CanvasLayer:
	var overlay: CanvasLayer = load("res://scripts/perf_overlay.gd").new()
	overlay.name = "PerfOverlay"
	parent.add_child(overlay)
	return overlay

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_times.resize(WINDOW)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0,0.0,0.0,0.55)
	box.set_content_margin_all(8.0)
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",box)
	panel.position = Vector2(10.0,10.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size",15)
	_label.add_theme_color_override("font_color",Color(0.92,0.95,0.88))
	_label.add_theme_constant_override("outline_size",3)
	_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	panel.add_child(_label)
	visible = "--perf" in preload("res://scripts/launch_args.gd").user_args()
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp,true)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_on_post_draw)

## Eased toward each frame's (ms), about a WINDOW/4-frame memory.
func _on_pre_draw() -> void:
	_pre = Time.get_ticks_usec()
	if _post > 0: _logic = lerpf(_logic,(_pre-_post)/1000.0,4.0/WINDOW)

func _on_post_draw() -> void:
	_post = Time.get_ticks_usec()
	if _pre > 0: _draw = lerpf(_draw,(_post-_pre)/1000.0,4.0/WINDOW)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY and (event as InputEventKey).shift_pressed:
		visible = not visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_times[_at % WINDOW] = delta*1000.0
	_at += 1
	if not visible: return
	_since += delta
	if _since < REFRESH: return
	_since = 0.0
	_label.text = text()

## The overlay's lines, as shown.
func text() -> String:
	var n := mini(_at,WINDOW)
	if n == 0: return ""
	var sorted := _times.slice(0,n)
	sorted.sort()
	var mean := 0.0
	for t in sorted: mean += t
	mean /= n
	var low := sorted[clampi(int(n*0.99),0,n-1)]
	var worst := sorted[n-1]
	var P := Performance
	var lines := PackedStringArray()
	lines.append("%d fps   %.1f ms  (1%% %.1f, worst %.1f)" % [roundi(1000.0/maxf(mean,0.001)),mean,low,worst])
	lines.append("main thread  logic %.1f  draw %.1f ms" % [_logic,_draw])
	lines.append("gpu %.1f ms" % RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	lines.append("draws %d   objects %d   prims %.2fM" % [int(P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME)),P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME)/1.0e6])
	lines.append("vram %d MB   nodes %d" % [int(P.get_monitor(P.RENDER_VIDEO_MEM_USED)/1048576.0),int(P.get_monitor(P.OBJECT_NODE_COUNT))])
	return "\n".join(lines)
