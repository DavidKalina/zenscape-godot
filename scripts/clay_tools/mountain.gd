extends "res://scripts/clay_tools/hand.gd"
## The Mountain, "Peak": two modes, one landform, picked on its fan or with
## Q and E (the user, 2026-10-03: people will want to draw a range, and
## pulling up a peak in a corner is too good to lose; telling the two apart
## by the press's timing made a pull start with a little draw, so it is a
## toggle). Each mode's press is its verb at once (`modes`' kinds).
##
## - **Pull** (the first mode): press and drag up, and a mountain is pulled
##   out of the land, its summit following the pointer. It only builds up:
##   dragging down does
##   nothing past the press's ground (the Crater is the tool that goes down).
##   It is the Modeller's pinch (scripts/clay_tools/hand.gd) made bigger
##   (PEAK: a wider spread, a taller reach, a faster pull). As it grows it
##   turns from a swell into a horn with arêtes, and let go it takes the
##   range's rock, as the pinch does.
## - **Draw:** press and drag, and a range is drawn along the path, as the
##   Ravine's gorge is (scripts/clay_tools/wire.gd): while the drag lasts the
##   land is untouched
##   and the ground marks' faint line follows the drawn path; let go, the
##   range grows out of the land along it from the press to the release, its
##   head running GROW_SPEED metres a second (the whole taking GROW_SECONDS)
##   and its summits rising as the head passes them, to the spec's `drawn`
##   height. One undo step, closed once it has grown; an undo, a new press,
##   a change of tool or Esc mid-growth lands the rest of it at once.
##   Shorter than RANGE_DEAD it is a lone peak.
##
## **Shift:** a smaller peak or range (FINE_PEAK).
##
## **Pull sideways as well** and the pulled peak stretches into a range,
## running from the press to the ground under the pointer's sideways travel
## (the clay's `hold_point`, on the press's row of the screen, so the travel
## up the screen is still only the height). The same pull, one undo step. A
## pull straight up is exactly the single peak: sideways travel under
## RANGE_DEAD metres of ground is left alone, and from there the peak eases
## into the range over RANGE_EASE metres, so nothing jumps. The pulled range
## is at most the spec's `range` metres long (PEAK's 20 m spans most of the
## 28 m plate inside its edge fade; FINE_PEAK's 10 m); a drawn one runs as
## long as it is drawn.
##
## A range, not a long dome, pulled or drawn: summits stand along the crest
## every `spacing` metres from the press (at the hand's size), each slipped
## along the line by up to SUMMIT_SLIP of the spacing and off it by up to
## SUMMIT_OFF metres, each RANGE_TALL of the range's height (seeded by the
## spot, so they hold still while the hand moves, and one further along rises
## out of the end as the line reaches it). Each is the pinch's horn, its own
## three to five arêtes, crags and lumpy outline, narrower than a lone peak
## (RANGE_NARROW of its radius, which still grows with its own height) so the
## range reads as a line of teeth. Between them the crest is mountain_forms'
## ridge (its knife edge, one flank steeper than the other, serrated by the
## crag noise) at SADDLE of the summits, so neighbours join in notched cols.
## The range tapers to its ends (RANGE_TAPER: its end summits stand that
## share lower than its middle) and the tallest summit stands at the lift. A
## low pull is a long swell and turns into the range as it grows, as the peak
## turns into a horn (HORN). Let go, the range takes the rock along its
## length, as the peak does.

const PEAK := {"r0":3.0,"grow":0.55,"max_radius":8.0,"raise":14.0,"sink":0.0,"scale":1.4,"range":20.0,"spacing":4.0,"drawn":9.0}
const FINE_PEAK := {"r0":1.8,"grow":0.4,"max_radius":4.0,"raise":6.0,"sink":0.0,"scale":0.6,"range":10.0,"spacing":2.2,"drawn":4.0}
const PEAK_MODES := [{"id":"pull","kind":"hold"},{"id":"draw","kind":"drag"}]
## The drawn range growing: its head's pace in metres a second, the whole
## growth's least and most seconds, and the share of them the lift takes to
## rise to its height (the first summit rises with it).
const GROW_SPEED := 10.0
const GROW_SECONDS := Vector2(0.8,3.0)
const LIFT_RISE := 0.35
const RANGE_DEAD := 1.5
const RANGE_EASE := 2.5
const RANGE_NARROW := 0.45
const RANGE_TAPER := 0.4
const RANGE_TALL := Vector2(0.72,1.0)
const SUMMIT_SLIP := 0.25
const SUMMIT_OFF := 0.4
const SADDLE := 0.55
## The range's points are gathered again once its end has moved REGATHER
## metres; every point it has reached stays written, so ground a shortening
## pull lets go of sinks back.
const REGATHER := 0.25

## The stand-in: a faceted stone pick, its head in the icon's tint
## (scripts/hud_icons.gd "mountain").
const STONE := Color("9a948c")
const HAFT := Color("b98a58")

const Wire = preload("res://scripts/clay_tools/wire.gd")
const DrawnLine = preload("res://scripts/clay_tools/drawn_line.gd")

## Whether this pull has left the dead zone (it is a range from then on, and
## eases back to the peak only by its shape), and the line from the press to
## the range's end last written (plate metres).
var ranged := false
var _shown_line := Vector2.INF
var _gathered_line := Vector2.INF
## Every point the range has reached this press, as indices and as a mask,
## and each one's place against the range's path (`_project`): metres along
## it to the nearest point on it, metres off it, and which side (1 or -1).
var _reached := PackedInt32Array()
var _reached_mask := PackedByteArray()
var _on := PackedFloat32Array()
var _off_path := PackedFloat32Array()
var _side_of := PackedFloat32Array()
## The summits, by their order from the press: along the line in spacings,
## off it in metres, their share of the range's height, and their arêtes.
var _along := PackedFloat32Array()
var _off := PackedFloat32Array()
var _tall := PackedFloat32Array()
var _summit_aretes: Array[PackedFloat32Array] = []
## The drawn range: the line being drawn; once let go, the path it grows
## along (with its arc lengths), the seconds grown and to grow, and whether
## it grows.
var _line_drawn := DrawnLine.new()
var _path := PackedVector2Array()
var _arc := PackedFloat32Array()
var _clock := 0.0
var _seconds := 0.0
var _growing := false
var _fine := false
## How far along its path the growing range's head has run (metres), for the
## tremor and the sound, which feel it with the lift as a pull's rise.
var head := 0.0

func id() -> String: return "mountain"
func horns() -> bool: return true
func modes() -> Array: return PEAK_MODES
func hover_gesture() -> String: return "pinch"
func stroke_radius() -> float: return float(PEAK.r0)*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*float(PEAK.r0)
func hold_tracks() -> bool: return true
func _pinch_spec(fine: bool) -> Dictionary: return FINE_PEAK if fine else PEAK
func _pinch_verb(fine: bool) -> String: return "fine_peak" if fine else "peak"

func reset() -> void:
	super.reset()
	_line_drawn.clear()

# --- The pulled range ------------------------------------------------------------------

## The peak's hold, and the range's summits seeded by the spot.
func hold_begin(fine: bool) -> String:
	var verb := super.hold_begin(fine)
	var spec: Dictionary = _pinch_spec(fine)
	ranged = false
	_shown_line = Vector2.INF
	_gathered_line = Vector2.INF
	_start_reach()
	_seed_summits(spec,float(spec.range))
	return verb

## Straight up it is the peak's step, untouched; past the dead zone the range's.
func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	var spec: Dictionary = _pinch_spec(clay.verb == _pinch_verb(true))
	var line := _line(spec)
	if not ranged:
		if line.length() < RANGE_DEAD: return super.hold_step(heights,rise)
		# The range's first gather takes in every point the peak wrote.
		ranged = true
	_follow(spec,rise)
	if is_equal_approx(lift,_shown_lift) and line.is_equal_approx(_shown_line): return false
	_shown_lift = lift
	_shown_line = line
	var path := PackedVector2Array([clay.center,clay.center+line])
	var arc := Wire._arc(path)
	if _gathered_line == Vector2.INF or line.distance_to(_gathered_line) > REGATHER:
		_gathered_line = line
		_reach_path(path,spec)
	_project(path,arc)
	_shape_range(heights,spec,path,arc,arc[-1])
	return true

## Let go: the peak's own, or the range's rock and trees along its length.
func hold_end() -> void:
	if not ranged:
		super.hold_end()
		return
	var line := _shown_line if _shown_line != Vector2.INF else Vector2.ZERO
	_settle_range(PackedVector2Array([clay.center,clay.center+line]),clay.verb == _pinch_verb(false))

## The line from the press to the range's end: to the clay's `hold_point`,
## at most the spec's `range` long; zero until the pointer has moved.
func _line(spec: Dictionary) -> Vector2:
	if clay.hold_point == null: return Vector2.ZERO
	return ((clay.hold_point as Vector2)-clay.center).limit_length(float(spec.range))

# --- The drawn range -------------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_fine = fine
	_line_drawn.begin(clay.center)
	return "fine_drawn_range" if fine else "drawn_range"

## Nothing is raised while the range is drawn: the path's points wait in the
## clay's queue and are read into the drawn path, as the Ravine's are.
func drag_frame(_delta: float) -> bool:
	_line_drawn.take(clay)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(_line_drawn.end()))
	return false

func gesture(_verb: String) -> String: return "pinch"
func dab(_heights: PackedFloat32Array, _q: Vector2) -> float: return 0.0
## Run off the plate mid-draw: the path simply stops where the land did.
func drag_off() -> void: pass

## The path drawn so far (plate points, press first, the pointer last).
## Empty while no range is being drawn (the ground marks show the line only
## then).
func drawn() -> PackedVector2Array:
	return PackedVector2Array() if _growing else _line_drawn.path(clay)

## Let go: the range is gathered along the drawn path and grown out of the
## land by `frame`, inside the stroke's undo step, which the clay keeps open
## while it grows.
func drag_end() -> bool:
	_path = drawn()
	_line_drawn.clear()
	if _path.is_empty(): return false
	var spec: Dictionary = _pinch_spec(_fine)
	_arc = Wire._arc(_path)
	_horn_setup()
	_start_reach()
	_seed_summits(spec,_arc[-1])
	_reach_path(_path,spec)
	_project(_path,_arc)
	lift = 0.0
	head = 0.0
	_clock = 0.0
	_seconds = clampf(_arc[-1]/GROW_SPEED,GROW_SECONDS.x,GROW_SECONDS.y)
	_growing = true
	return false

## The path the last drawn range grew along (plate points), for probes.
func range_path() -> PackedVector2Array:
	return _path

func busy() -> bool: return _growing or super.busy()
## True while a drawn range grows out of the land.
func growing() -> bool: return _growing
## Where the growing range's head stands (plate).
func head_point() -> Vector2: return Wire._point_at(_path,head) if not _path.is_empty() else clay.center
func drag_running() -> bool: return _growing

## The head runs on along the path, the lift rises, and the summits it has
## passed rise out of the land. Once it reaches the end the range is done.
func frame(delta: float) -> void:
	super.frame(delta)
	if not _growing: return
	_clock += delta
	var t := clampf(_clock/_seconds,0.0,1.0)
	if t >= 1.0:
		finish()
		return
	_grow(t)
	clay.hand_gesture(gesture(clay.verb),clay.ground_at(head_point()))

## The rest of the range at once (it grew out, an undo, a new press, a change
## of tool): the whole of it written, then its rock and the trees.
func finish() -> void:
	super.finish()
	if not _growing: return
	_grow(1.0)
	_growing = false
	_settle_range(_path,not _fine)
	clay.show_land()

## The range `t` of the way through its growth written to the land.
func _grow(t: float) -> void:
	var spec: Dictionary = _pinch_spec(_fine)
	lift = float(spec.drawn)*smoothstep(0.0,LIFT_RISE,t)
	head = _arc[-1]*Wire._ease(t)
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	_shape_range(heights,spec,_path,_arc,head)
	data.heights = heights
	clay.show_land()

# --- The range, pulled or drawn -------------------------------------------------------

## The summits for a range up to `length` metres long, seeded by the press.
func _seed_summits(spec: Dictionary, length: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([clay.editor.land_seed,"range",(clay.center as Vector2).snapped(Vector2.ONE*0.01)])
	_along = PackedFloat32Array()
	_off = PackedFloat32Array()
	_tall = PackedFloat32Array()
	_summit_aretes = []
	var count := ceili(length/(float(spec.spacing)*clay.size_scale))+2
	for k in range(count):
		_along.append(float(k)+(rng.randf_range(-SUMMIT_SLIP,SUMMIT_SLIP) if k > 0 else 0.0))
		_off.append(rng.randf_range(-SUMMIT_OFF,SUMMIT_OFF) if k > 0 else 0.0)
		_tall.append(rng.randf_range(RANGE_TALL.x,RANGE_TALL.y))
		if k == 0:
			_summit_aretes.append(_aretes)
			continue
		var aretes := PackedFloat32Array()
		var arms := rng.randi_range(3,5)
		var turn := rng.randf()*TAU
		for a in range(arms): aretes.append(turn+TAU*(float(a)+rng.randf_range(-0.22,0.22))/arms)
		_summit_aretes.append(aretes)

## Forget the points the last range reached.
func _start_reach() -> void:
	_reached = PackedInt32Array()
	_reached_mask = PackedByteArray()
	_reached_mask.resize(clay.base.size())

## Every point within the widest horn's reach of `path` into the range's reach.
func _reach_path(path: PackedVector2Array, spec: Dictionary) -> void:
	var reach: float = float(spec.max_radius)*clay.size_scale*HORN_REACH
	var points: PackedVector2Array = clay.editor.data.points
	for j in range(maxi(path.size()-1,1)):
		var a := path[j]
		var b := path[mini(j+1,path.size()-1)]
		clay.gather((a+b)*0.5,a.distance_to(b)*0.5+reach)
		for i: int in clay.near:
			if _reached_mask[i] != 0: continue
			var p := points[i]
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)) < reach:
				_reached_mask[i] = 1
				_reached.append(i)

## Each reached point's place against `path` (arc lengths `arc`): along it,
## off it and on which side, into `_on`, `_off_path`, `_side_of`.
func _project(path: PackedVector2Array, arc: PackedFloat32Array) -> void:
	var points: PackedVector2Array = clay.editor.data.points
	_on.resize(_reached.size())
	_off_path.resize(_reached.size())
	_side_of.resize(_reached.size())
	for n in _reached.size():
		var p := points[_reached[n]]
		var best := INF
		for j in range(maxi(path.size()-1,1)):
			var a := path[j]
			var b := path[mini(j+1,path.size()-1)]
			var run := a.distance_to(b)
			var way := (b-a)/run if run > 0.001 else Vector2.RIGHT
			var t := clampf((p-a).dot(way),0.0,run)
			var d := p.distance_to(a+way*t)
			if d < best:
				best = d
				_on[n] = arc[j]+t
				var across := (p-a).dot(Vector2(-way.y,way.x))
				_side_of[n] = 1.0 if across > 0.0 else -1.0
		_off_path[n] = best

## The plate point `s` metres along `path` (arc lengths `arc`), run on
## straight past either end, and the way the path runs there.
static func _along_path(path: PackedVector2Array, arc: PackedFloat32Array, s: float) -> Array:
	if path.size() < 2: return [path[0],Vector2.RIGHT]
	var j := 0
	while j < path.size()-2 and s > arc[j+1]: j += 1
	var run := arc[j+1]-arc[j]
	var way := (path[j+1]-path[j])/run if run > 0.001 else Vector2.RIGHT
	return [path[j]+way*(s-arc[j]),way]

## The share of the range's height its envelope allows `u` of the way along
## it, at `stretch` of the way from the peak to the range: full in the
## middle, RANGE_TAPER lower at the ends.
static func _envelope(u: float, stretch: float) -> float:
	return 1.0-RANGE_TAPER*stretch*(1.0-pow(sin(PI*clampf(u,0.0,1.0)),0.7))

## Write the range along `path` (arc lengths `arc`, its points' places
## `_project`ed) from `clay.base`, as far as `head` metres along it: the
## summits' horns and the ridge between them, whichever stands higher, at
## the lift. A pulled range's head is its whole length; a drawn one's runs
## along it as it grows.
func _shape_range(heights: PackedFloat32Array, spec: Dictionary, path: PackedVector2Array, arc: PackedFloat32Array, head: float) -> void:
	var size: float = clay.size_scale
	var length := head
	var stretch := smoothstep(RANGE_DEAD,RANGE_DEAD+RANGE_EASE,arc[-1])
	var horn := smoothstep(HORN.x,HORN.y,lift)
	var reach: float = float(spec.max_radius)*size*HORN_REACH
	# The summits: where each stands, its share of the height and its radius.
	var spacing: float = float(spec.spacing)*size
	var tops := PackedVector2Array()
	var tall := PackedFloat32Array()
	var radii := PackedFloat32Array()
	var arms: Array[PackedFloat32Array] = []
	var tallest := 0.0
	for k in _along.size():
		var at := _along[k]*spacing
		var shown := 1.0 if k == 0 else smoothstep(at-0.5*spacing,at,length)*stretch
		if shown <= 0.0: continue
		var place: Array = _along_path(path,arc,at)
		var way: Vector2 = place[1]
		tops.append((place[0] as Vector2)+Vector2(-way.y,way.x)*_off[k]*stretch)
		tall.append(lerpf(1.0,_tall[k],stretch)*_envelope(at/maxf(length,0.01),stretch)*shown)
		arms.append(_summit_aretes[k])
		tallest = maxf(tallest,tall[-1])
	var narrow := lerpf(1.0,RANGE_NARROW,stretch)
	for k in tall.size():
		tall[k] /= tallest
		radii.append(minf(float(spec.r0)+float(spec.grow)*absf(lift)*tall[k],float(spec.max_radius))*size*narrow)
	# The ridge between them: SADDLE of the summits, under the envelope.
	var crest_share := SADDLE*stretch/tallest
	var ridge_width: float = minf(float(spec.r0)+float(spec.grow)*absf(lift)*SADDLE,float(spec.max_radius))*size*RANGE_NARROW
	var base: PackedFloat32Array = clay.base
	var points: PackedVector2Array = clay.editor.data.points
	var box := Rect2(path[0],Vector2.ZERO)
	for n in _reached.size():
		var i := _reached[n]
		var p := points[i]
		var shape := 0.0
		for k in tops.size():
			var d := p-tops[k]
			var t := d.length()/radii[k]
			if t >= 1.25: continue
			var summit := pow(1.0-t*t,2.0) if t < 1.0 else 0.0
			if horn > 0.0: summit = lerpf(summit,_horn_from(i,d,t,arms[k]),horn)
			shape = maxf(shape,tall[k]*summit)
		if crest_share > 0.0:
			# mountain_forms' ridge: a knife edge, one flank steeper, serrated.
			# Past the head (or either end) the ridge rounds off.
			var on := minf(_on[n],length)
			var past := _on[n]-on
			var width := ridge_width*(0.85+0.3*_lump[i])*(1.0 if _side_of[n] > 0.0 else 0.72)
			var q := Vector2(_off_path[n],past).length()/width
			if q < 1.0:
				var edge := lerpf(pow(1.0-q*q,2.0),pow(1.0-q,1.45),horn)
				shape = maxf(shape,crest_share*_envelope(on/maxf(length,0.01),stretch)*(0.82+0.18*_jag[i])*edge)
		var h: float = base[i]+lift*shape*clay.fade(i)
		if lift < 0.0: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
		if shape > 0.0: box = box.expand(p)
	clay.touch(box.get_center(),maxf(box.size.x,box.size.y)*0.5+reach)

## Let go of a range along `path`: its rock along its length (`rocky`: not a
## Shift range, whose height stays green), and trees that cannot hold its
## flanks slide down.
func _settle_range(path: PackedVector2Array, rocky: bool) -> void:
	var reach: float = float(_pinch_spec(false).max_radius)*clay.size_scale*HORN_REACH
	var box := Rect2(path[0],Vector2.ZERO)
	for p in path: box = box.expand(p)
	if rocky and lift >= ROCK_FROM:
		var horn := smoothstep(HORN.x,HORN.y,lift)
		var arc := Wire._arc(path)
		var stops := maxi(ceili(arc[-1]/reach),1)
		for k in range(stops):
			clay.paint_rock(Wire._point_at(path,arc[-1]*(k+0.5)/stops),maxf(reach,arc[-1]*0.5/stops+reach*0.5),maxf(2.0,lerpf(10.0,lift,horn)))
	clay.shake_trees(box.get_center(),maxf(box.size.x,box.size.y)*0.5+reach+1.0)

# --- The stand-in prop ------------------------------------------------------------------

## A faceted pick: a wooden haft down to a grey stone point.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),HAFT,Vector3(0.0,-0.1,0.0),Vector3(0.035,0.6,0.035)))
	root.add_child(part(_prism(6,0.05),STONE,Vector3(0.0,-0.52,0.0),Vector3(0.09,0.24,0.09)))
	return root
