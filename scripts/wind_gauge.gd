extends CanvasLayer
## The wind gauge (docs/design/wind-gauge/spec-wind-gauge.md): the updraft's
## charge (scripts/updraft.gd) as a small brushed arc in the lower left,
## split into SEGMENTS. Each segment fills as charge builds, pulses softly
## when it fills, the whole arc brightens when all are full, and a segment
## that empties at once (spent) flicks out. It fades down when empty and
## idle and up as soon as charge builds. `empty_cue()` gives a soft shake
## for a press with nothing to spend.
##
## The host makes it with `setup(updraft, shown)`: `shown` says whether it
## may show at all (on foot, not in the title or the plane). Drawn in the
## lantern look (scripts/lantern_style.gd): warm-white strokes with a wind
## tint, over a soft dark under-stroke so it reads over sky and snow.

const Style = preload("res://scripts/lantern_style.gd")

const SEGMENTS := 3
## Design units at 1440x900 (scaled by Style.ui_scale).
const RADIUS := 40.0
const WIDTH := 7.0
const CORNER := Vector2(84.0,-84.0)    # the arc's centre from the lower-left corner
const ARC_FROM := 155.0                # deg (screen: 0 right, 90 down), clockwise...
const ARC_TO := 385.0                  # ...to here: a 230 deg arc open at the bottom
const GAP := 9.0                       # deg between segments
## Look.
const FILL := Color("fbf6ea")          # Style.LIGHT
const TINT := Color("d2eef0")          # Style's "wind" tint
const SHADE := Color("081218")         # Style.SHADE
const EMPTY_ALPHA := 0.32              # an empty segment's track
const FULL_GLOW := 0.55                # extra glow alpha with all segments full
const EASE := 0.18                     # s the drawn fill eases toward the charge
const PULSE := 0.45                    # s a filled segment's pulse lasts
const FLICK := 0.35                    # s a spent segment takes to flick out
const SPENT_DROP := 0.25               # a segment losing this much in a frame was spent
const IDLE := 1.5                      # s empty before it fades down
const FADE_DOWN := 0.8                 # s to fade down
const FADE_UP := 0.15                  # s to fade up
const IDLE_ALPHA := 0.0                # alpha when faded down
const CUE := 0.35                      # s the empty cue shakes
## A stroke's bristles: offset across, width and alpha, as shares of the band.
const BRISTLE_OFF: Array[float] = [0.0,-0.28,0.3,0.05]
const BRISTLE_W: Array[float] = [1.0,0.42,0.38,0.6]
const BRISTLE_A: Array[float] = [1.0,0.55,0.5,0.35]

var updraft: Node
var shown := Callable()
var alpha := 0.0
## Each segment's drawn fill (0..1), its pulse and flick clocks.
var fills: Array[float] = []
var _pulse: Array[float] = []
var _flick: Array[float] = []
var _flick_from: Array[float] = []
var _idle := IDLE
var _cue := 0.0
var _clock := 0.0
var _full := 0.0                       # 0..1 eased: all segments full
var _view: Control

func setup(drafts: Node, may_show: Callable) -> void:
	updraft = drafts
	shown = may_show

func _ready() -> void:
	layer = 6
	for i in range(SEGMENTS):
		fills.append(0.0)
		_pulse.append(0.0)
		_flick.append(0.0)
		_flick_from.append(0.0)
	_view = Control.new()
	_view.name = "WindGaugeArc"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_paint)
	add_child(_view)

## The charge as segments: how many are full (an int count).
func segments_full() -> int:
	var c: float = updraft.charge if updraft != null else 0.0
	return int(floor(c*SEGMENTS+0.0001))

## A press with nothing to spend: a soft shake and a dim flash.
func empty_cue() -> void:
	_cue = CUE

func _process(delta: float) -> void:
	_clock += delta
	var c: float = updraft.charge if updraft != null else 0.0
	var all_full := true
	for i in range(SEGMENTS):
		var goal := clampf(c*SEGMENTS-float(i),0.0,1.0)
		var was := fills[i]
		if was-goal >= SPENT_DROP:
			# Spent: drops at once and flicks out.
			_flick[i] = FLICK
			_flick_from[i] = was
			fills[i] = goal
		else:
			fills[i] = move_toward(was,goal,delta/EASE)
		if was < 0.999 and fills[i] >= 0.999: _pulse[i] = PULSE
		_pulse[i] = maxf(_pulse[i]-delta,0.0)
		_flick[i] = maxf(_flick[i]-delta,0.0)
		if fills[i] < 0.999: all_full = false
	_full = move_toward(_full,1.0 if all_full else 0.0,delta/0.3)
	_cue = maxf(_cue-delta,0.0)
	var busy := c > 0.005 or _cue > 0.0
	for i in range(SEGMENTS): busy = busy or _flick[i] > 0.0 or fills[i] > 0.005
	_idle = 0.0 if busy else _idle+delta
	var want := 1.0 if (busy or _idle < IDLE) else IDLE_ALPHA
	var may: bool = shown.call() if shown.is_valid() else true
	if not may: want = 0.0
	var rate := FADE_UP if want > alpha else FADE_DOWN
	if not may: rate = 0.1
	alpha = move_toward(alpha,want,delta/rate)
	_view.visible = alpha > 0.005
	if _view.visible: _view.queue_redraw()

## A brushed stroke along the arc from a0 to a1 (deg): a main band with a
## few thinner bristles off it, their widths breathing along the stroke so
## it reads painted, not ruled.
func _brush(at: Vector2, r: float, a0: float, a1: float, w: float, col: Color, seed: float) -> void:
	if a1-a0 < 0.5: return
	var steps := maxi(int((a1-a0)/4.0),3)
	for b in range(4):
		var off: float = BRISTLE_OFF[b]*w
		var bw: float = BRISTLE_W[b]*w
		var ba: float = BRISTLE_A[b]
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for s in range(steps+1):
			var u := float(s)/float(steps)
			var a := deg_to_rad(lerpf(a0,a1,u))
			var wob := 0.6*sin(u*7.0+seed+float(b)*1.7)*w*0.12
			pts.append(at+Vector2(cos(a),sin(a))*(r+off+wob))
			# Dry brush: the stroke thins at its ends.
			var end := clampf(minf(u,1.0-u)*6.0,0.25,1.0)
			cols.append(Color(col.r,col.g,col.b,col.a*ba*end))
		_view.draw_polyline_colors(pts,cols,bw,true)

func _paint() -> void:
	var size := _view.get_viewport_rect().size
	var k := Style.ui_scale(size)
	var shake := Vector2.ZERO
	if _cue > 0.0: shake.x = sin(_cue*70.0)*3.0*(_cue/CUE)*k
	var at := Vector2(CORNER.x*k,size.y+CORNER.y*k)+shake
	var r := RADIUS*k
	var w := WIDTH*k
	var span := (ARC_TO-ARC_FROM-GAP*float(SEGMENTS-1))/float(SEGMENTS)
	var breathe := 0.5+0.5*sin(_clock*2.4)
	var lift := _full*(0.75+0.25*breathe)
	# The under-stroke: one soft dark band under the whole arc.
	_brush(at,r,ARC_FROM-3.0,ARC_TO+3.0,w*2.2,Color(SHADE,0.32*alpha),0.0)
	for i in range(SEGMENTS):
		var a0 := ARC_FROM+float(i)*(span+GAP)
		var a1 := a0+span
		var seed := float(i)*3.1
		# The empty track.
		var track := Color(TINT,EMPTY_ALPHA*alpha*(1.0+0.6*_cue/CUE))
		_brush(at,r,a0,a1,w*0.7,track,seed+9.0)
		# The fill: tinted halo under, warm white over.
		var f := fills[i]
		if f > 0.0:
			var glow := 0.28+0.25*f+FULL_GLOW*lift
			_brush(at,r,a0,a0+span*f,w*(1.7+0.5*lift),Color(TINT,glow*0.45*alpha),seed+4.0)
			_brush(at,r,a0,a0+span*f,w,Color(FILL.lerp(TINT,0.25*(1.0-f)),(0.75+0.25*f)*alpha),seed)
		# A filled segment's pulse: a soft swell out from it.
		if _pulse[i] > 0.0:
			var u := 1.0-_pulse[i]/PULSE
			var swell := sin(u*PI)
			_brush(at,r+w*0.9*u,a0,a1,w*(1.0+2.0*swell),Color(FILL,0.5*swell*alpha),seed+2.0)
		# A spent segment flicks out: thrown outward along the arc, thinning.
		if _flick[i] > 0.0:
			var u := 1.0-_flick[i]/FLICK
			var push := r+w*(0.6+4.0*u)
			var turn := 18.0*u
			var fa := _flick_from[i]
			var fade := (1.0-u)*(1.0-u)
			_brush(at,push,a0+turn,a0+turn+span*fa*(1.0-0.6*u),w*(1.8-1.2*u),Color(TINT,0.6*fade*alpha),seed+7.0)
			_brush(at,push,a0+turn,a0+turn+span*fa*(1.0-0.6*u),w*(1.1-0.7*u),Color(FILL,fade*alpha),seed+6.0)
	# The centre: two small wind wisps, brighter as the charge builds.
	var c: float = updraft.charge if updraft != null else 0.0
	for j in range(2):
		var wisp := PackedVector2Array()
		for s in range(10):
			var u := float(s)/9.0
			var x := lerpf(-0.32,0.32,u)*r+float(j)*0.12*r
			var y := (float(j)*0.3-0.18)*r+sin(u*TAU*0.8+float(j)+_clock*1.5*c)*0.08*r
			wisp.append(at+Vector2(x,y))
		_view.draw_polyline(wisp,Color(SHADE,0.3*alpha),w*0.75,true)
		_view.draw_polyline(wisp,Color(FILL.lerp(TINT,0.4),(0.3+0.5*c+0.2*lift)*alpha),w*0.32,true)
