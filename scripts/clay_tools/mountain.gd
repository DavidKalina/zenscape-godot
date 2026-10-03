extends "res://scripts/clay_tools/hand.gd"
## The Mountain, "Peak": press on the land and drag up, and a mountain is pulled
## out of it, its summit following the pointer; drag down and a crater is
## pressed into it (see "The crater").
## It is the Modeller's pinch (scripts/clay_tools/hand.gd) made bigger
## (PEAK: a wider spread, a taller reach, a faster pull), and it is its only
## verb, taken at the press (`press_kind`): no holding still first. As it
## grows it turns from a swell into a horn with arêtes, and let go it takes
## the range's rock, as the pinch does. **Shift:** a smaller peak (FINE_PEAK).
##
## **Drag sideways as well** and the peak stretches into a range, running from
## the press to the ground under the pointer's sideways travel (the clay's
## `hold_point`, on the press's row of the screen, so the travel up the screen
## is still only the height). The same pull, one undo step. A pull straight up
## is exactly the single peak: sideways travel under RANGE_DEAD metres of
## ground is left alone, and from there the peak eases into the range over
## RANGE_EASE metres, so nothing jumps. The range is at most the spec's
## `range` metres long (PEAK's 20 m spans most of the 28 m plate inside its
## edge fade; FINE_PEAK's 10 m).
##
## A range, not a long dome: summits stand along the crest every `spacing`
## metres from the press (at the hand's size), each slipped along the line by
## up to SUMMIT_SLIP of the spacing and off it by up to SUMMIT_OFF metres,
## each RANGE_TALL of the range's height (seeded by the spot, so they hold
## still while the hand moves, and one further along rises out of the end as
## the line reaches it). Each is the pinch's horn, its own three to five
## arêtes, crags and lumpy outline, narrower than a lone peak (RANGE_NARROW
## of its radius, which still grows with its own height) so the range reads as
## a line of teeth. Between them the crest is mountain_forms' ridge (its
## knife edge, one flank steeper than the other, serrated by the crag noise)
## at SADDLE of the summits, so neighbours join in notched cols. The range
## tapers to its ends (RANGE_TAPER: its end summits stand that share lower
## than its middle) and the tallest summit stands at the height the pointer
## pulled. A low pull is a long swell and turns into the range as it grows, as
## the peak turns into a horn (HORN). Let go, the range takes the rock along
## its length, as the peak does.
##
## ### The crater
##
## Pulled down (the pointer below the press), the pull is a crater, never a
## range: sideways travel is ignored, and a range already drawn goes back to
## the ground it stood on. The floor sinks by the pull, level inside
## CRATER_FLOOR of the radius and rising to the rim at CRATER_RIM_AT; a rim
## CRATER_RIM of the depth stands round it, out to CRATER_RIM_OUT radii, the
## ground thrown out of the hole. The radius widens with the depth as the
## peak's does. The floor shows the stratum it reached (the clay's dirt). The
## user, 2026-10-02: they like dragging up for mountains and dragging down.

const PEAK := {"r0":3.0,"grow":0.55,"max_radius":8.0,"raise":14.0,"sink":6.0,"scale":1.4,"range":20.0,"spacing":4.0}
const FINE_PEAK := {"r0":1.8,"grow":0.4,"max_radius":4.0,"raise":6.0,"sink":3.0,"scale":0.6,"range":10.0,"spacing":2.2}
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
const CRATER_FLOOR := 0.45
const CRATER_RIM_AT := 0.95
const CRATER_RIM := 0.3
const CRATER_RIM_OUT := 1.25

## The stand-in: a faceted stone pick, its head in the icon's tint
## (scripts/hud_icons.gd "mountain").
const STONE := Color("9a948c")
const HAFT := Color("b98a58")

## Whether this pull has left the dead zone (it is a range from then on, and
## eases back to the peak only by its shape), and the line from the press to
## the range's end last written (plate metres).
var ranged := false
var _shown_line := Vector2.INF
var _gathered_line := Vector2.INF
## Every point the range has reached this pull, as indices and as a mask.
var _reached := PackedInt32Array()
var _reached_mask := PackedByteArray()
## The summits, by their order from the press: along the line in spacings,
## off it in metres, their share of the range's height, and their arêtes.
var _along := PackedFloat32Array()
var _off := PackedFloat32Array()
var _tall := PackedFloat32Array()
var _summit_aretes: Array[PackedFloat32Array] = []

func id() -> String: return "mountain"
func horns() -> bool: return true
func modes() -> Array: return []
func press_kind() -> String: return "hold"
func hover_gesture() -> String: return "pinch"
func stroke_radius() -> float: return float(PEAK.r0)*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*float(PEAK.r0)
func hold_tracks() -> bool: return true
func _pinch_spec(fine: bool) -> Dictionary: return FINE_PEAK if fine else PEAK
func _pinch_verb(fine: bool) -> String: return "fine_peak" if fine else "peak"
## A pull let go below the press is reported as a crater.
func worked_as(verb: String) -> String:
	if lift < 0.0 and verb == _pinch_verb(true): return "fine_crater"
	if lift < 0.0 and verb == _pinch_verb(false): return "crater"
	return verb

# --- The range -------------------------------------------------------------------------

## The peak's hold, and the range's summits seeded by the spot.
func hold_begin(fine: bool) -> String:
	var verb := super.hold_begin(fine)
	var spec: Dictionary = _pinch_spec(fine)
	ranged = false
	_shown_line = Vector2.INF
	_gathered_line = Vector2.INF
	_reached = PackedInt32Array()
	_reached_mask = PackedByteArray()
	_reached_mask.resize(clay.base.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([clay.editor.land_seed,"range",(clay.center as Vector2).snapped(Vector2.ONE*0.01)])
	_along = PackedFloat32Array()
	_off = PackedFloat32Array()
	_tall = PackedFloat32Array()
	_summit_aretes = []
	var count := ceili(float(spec.range)/(float(spec.spacing)*clay.size_scale))+2
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
	return verb

## Straight up it is the peak's step, untouched; past the dead zone the range's;
## pulled down, the crater's.
func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	var spec: Dictionary = _pinch_spec(clay.verb == _pinch_verb(true))
	if rise < 0.0: return _crater_step(heights,spec,rise)
	var line := _line(spec)
	if not ranged:
		if line.length() < RANGE_DEAD: return super.hold_step(heights,rise)
		# The range's first gather takes in every point the peak wrote.
		ranged = true
	_follow(spec,rise)
	if is_equal_approx(lift,_shown_lift) and line.is_equal_approx(_shown_line): return false
	_shown_lift = lift
	_shown_line = line
	_shape_range(heights,spec,line)
	return true

## Let go: the peak's own, or the range's rock and trees along its length.
func hold_end() -> void:
	if lift < 0.0:
		clay.shake_trees(clay.center,float(_pinch_spec(false).max_radius)*clay.size_scale*CRATER_RIM_OUT+1.0)
		return
	if not ranged:
		super.hold_end()
		return
	var line := _shown_line if _shown_line != Vector2.INF else Vector2.ZERO
	var middle: Vector2 = clay.center+line*0.5
	var reach: float = line.length()*0.5+float(_pinch_spec(false).max_radius)*clay.size_scale*HORN_REACH
	if clay.verb == _pinch_verb(false) and lift >= ROCK_FROM:
		var horn := smoothstep(HORN.x,HORN.y,lift)
		clay.paint_rock(middle,reach,maxf(2.0,lerpf(10.0,lift,horn)))
	clay.shake_trees(middle,reach+1.0)

## The line from the press to the range's end: to the clay's `hold_point`,
## at most the spec's `range` long; zero until the pointer has moved.
func _line(spec: Dictionary) -> Vector2:
	if clay.hold_point == null: return Vector2.ZERO
	return ((clay.hold_point as Vector2)-clay.center).limit_length(float(spec.range))

## The share of the range's height its envelope allows `u` of the way along
## it, at `stretch` of the way from the peak to the range: full in the
## middle, RANGE_TAPER lower at the ends.
static func _envelope(u: float, stretch: float) -> float:
	return 1.0-RANGE_TAPER*stretch*(1.0-pow(sin(PI*clampf(u,0.0,1.0)),0.7))

## Points within the widest horn's reach of the line, into the range's reach.
func _reach_points(found: PackedInt32Array) -> void:
	for i in found:
		if _reached_mask[i] == 0:
			_reached_mask[i] = 1
			_reached.append(i)

## Write the range along `line` from `clay.base`: the summits' horns and the
## ridge between them, whichever stands higher, at the lift.
func _shape_range(heights: PackedFloat32Array, spec: Dictionary, line: Vector2) -> void:
	var size: float = clay.size_scale
	var length := line.length()
	var way := line/length if length > 0.01 else Vector2.RIGHT
	var side := Vector2(-way.y,way.x)
	var stretch := smoothstep(RANGE_DEAD,RANGE_DEAD+RANGE_EASE,length)
	var horn := smoothstep(HORN.x,HORN.y,lift)
	var reach: float = float(spec.max_radius)*size*HORN_REACH
	var center: Vector2 = clay.center
	if _gathered_line == Vector2.INF or line.distance_to(_gathered_line) > REGATHER:
		_gathered_line = line
		clay.gather(center+line*0.5,length*0.5+reach)
		var found := PackedInt32Array()
		var points: PackedVector2Array = clay.editor.data.points
		for k in clay.near.size():
			var i: int = clay.near[k]
			var p := points[i]-center
			var along := clampf(p.dot(way),0.0,length)
			if p.distance_to(way*along) < reach: found.append(i)
		_reach_points(found)
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
		tops.append(center+way*at+side*_off[k]*stretch)
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
	for i in _reached:
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
			var d := p-center
			var along := d.dot(way)
			var across := d.dot(side)
			var on := clampf(along,0.0,length)
			var width := ridge_width*(0.85+0.3*_lump[i])*(1.0 if across > 0.0 else 0.72)
			var q := Vector2(absf(across)/width,absf(along-on)/width).length()
			if q < 1.0:
				var edge := lerpf(pow(1.0-q*q,2.0),pow(1.0-q,1.45),horn)
				shape = maxf(shape,crest_share*_envelope(on/maxf(length,0.01),stretch)*(0.82+0.18*_jag[i])*edge)
		var h: float = base[i]+lift*shape*clay.fade(i)
		if lift < 0.0: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	clay.touch(center+line*0.5,length*0.5+reach)

# --- The crater ------------------------------------------------------------------------

## The crater's step: a range drawn this pull goes back first, then the
## crater is written round the press from `clay.base`.
func _crater_step(heights: PackedFloat32Array, spec: Dictionary, rise: float) -> bool:
	if ranged: _unrange(heights,spec)
	_follow(spec,rise)
	if is_equal_approx(lift,_shown_lift): return false
	_shown_lift = lift
	var radius: float = minf(float(spec.r0)+float(spec.grow)*absf(lift),float(spec.max_radius))*clay.size_scale
	var depth := maxf(-lift,0.0)
	# The rim is the ground thrown out of the hole, so it stands by the depth
	# the floor really reached under the clay's FLOOR, not by the pull.
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	var thrown := minf(depth,maxf(float(ground)-clay.FLOOR,0.0)) if ground != null else depth
	var base: PackedFloat32Array = clay.base
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var t: float = near_d[k]/radius
		var h: float
		if lift >= 0.0:
			# The grip's kick, before the pull has gone below the press.
			h = base[i]+lift*(pow(1.0-t*t,2.0) if t < 1.0 else 0.0)*clay.fade(i)
		else:
			var bowl := 1.0-smoothstep(CRATER_FLOOR,CRATER_RIM_AT,t)
			var rim := 0.0
			if t > CRATER_FLOOR and t < CRATER_RIM_OUT: rim = pow(sin(PI*(t-CRATER_FLOOR)/(CRATER_RIM_OUT-CRATER_FLOOR)),2.0)
			h = base[i]+(thrown*CRATER_RIM*rim-depth*bowl)*clay.fade(i)
			if h < base[i]: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	clay.touch(clay.center,radius*CRATER_RIM_OUT)
	if lift < 0.0: clay.dirty(clay.center,radius*CRATER_RIM_AT)
	return true

## A range drawn this pull goes back to the ground it stood on, and the
## peak's points round the press are gathered again for the crater.
func _unrange(heights: PackedFloat32Array, spec: Dictionary) -> void:
	var base: PackedFloat32Array = clay.base
	for i in _reached: heights[i] = base[i]
	if _shown_line != Vector2.INF:
		clay.touch(clay.center+_shown_line*0.5,_shown_line.length()*0.5+float(spec.max_radius)*clay.size_scale*HORN_REACH)
	ranged = false
	_reached = PackedInt32Array()
	_reached_mask.fill(0)
	_shown_line = Vector2.INF
	_gathered_line = Vector2.INF
	_shown_lift = INF
	clay.gather(clay.center,float(spec.max_radius)*clay.size_scale*HORN_REACH)

# --- The stand-in prop ------------------------------------------------------------------

## A faceted pick: a wooden haft down to a grey stone point.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),HAFT,Vector3(0.0,-0.1,0.0),Vector3(0.035,0.6,0.035)))
	root.add_child(part(_prism(6,0.05),STONE,Vector3(0.0,-0.52,0.0),Vector3(0.09,0.24,0.09)))
	return root
