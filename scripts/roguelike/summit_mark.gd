extends Control
## [summit] The climb as a quiet mark in the corner under the hearts: one
## small diamond a layer, the ones climbed gilt, the one he stands on lit
## and a little larger, the rest hollow, the last a small sun. Rides the
## readout's alpha (docs/design/roguelike/summit-round1.md).
const Summit = preload("res://scripts/roguelike/summit.gd")

var overlay: CanvasLayer
var depth := 0
var total := 6
## Design px: the row's top (under the hearts and the items), a diamond's
## half-height, the gap between.
const TOP := 150.0
const HALF := 6.0
const GAP := 22.0
const GOLD := Color("d6ad66")
const SUN := Color("f4e2b0")
var _pulse := INF

func _init() -> void:
	name = "SummitMark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_layers(at_depth: int, of: int) -> void:
	if at_depth != depth and depth > 0: _pulse = 0.0
	depth = at_depth
	total = of

func _process(delta: float) -> void:
	if _pulse != INF:
		_pulse += delta
		if _pulse > 1.6: _pulse = INF
	queue_redraw()

func _draw() -> void:
	if overlay == null or not overlay.readout.visible or depth <= 0: return
	var a: float = overlay._hearts_a()
	if a <= 0.0: return
	var px: float = overlay._px
	var y := TOP*px
	for i in range(total):
		var at := Vector2((overlay.CORNER.x+HALF+GAP*float(i))*px,y)
		var here := i == depth-1
		var done := i < depth
		var h := HALF*px*(1.35 if here else 1.0)
		if here and _pulse != INF: h *= 1.0+0.7*sin(PI*clampf(_pulse/1.6,0.0,1.0))
		if i == total-1:
			_sun(at,h,done,a,px)
			continue
		var pts := PackedVector2Array([at+Vector2(0,-h),at+Vector2(h*0.7,0),at+Vector2(0,h),at+Vector2(-h*0.7,0)])
		if done:
			draw_colored_polygon(pts,Color(GOLD.lightened(0.3 if here else 0.0),a*(0.95 if here else 0.7)))
		else:
			pts.append(pts[0])
			draw_polyline(pts,Color(GOLD,0.4*a),1.2*px,true)

func _sun(at: Vector2, h: float, done: bool, a: float, px: float) -> void:
	var c := Color(SUN,a*(1.0 if done else 0.55))
	draw_arc(at,h*0.85,0.0,TAU,20,c,1.4*px,true)
	for k in range(8):
		var d := Vector2.from_angle(TAU*float(k)/8.0)
		draw_line(at+d*h*1.2,at+d*h*1.75,c,1.2*px,true)
	if done: draw_circle(at,h*0.55,c)
