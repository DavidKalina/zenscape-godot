extends RefCounted
## The Peak's glacier ice: what the ground shader's ice paint
## (shaders/peak_ice.gdshaderinc) reads, and the switch (--peak-ice=0: the
## older ice and seracs).
##
## The paint follows the ice's line, not the massif's axis: a list of points
## from the head to the toe, each {at (world XZ), half (m, the ice's half-width
## there), cover (0 no ice, 1 ice), debris (0 clean, 1 buried)}.
## `uniforms(line)` turns one into the shader's values (up to POINTS points;
## a longer line is thinned). `today(peak)` is today's valley as such a line
## (its bend, its floor's width, its bands). To lay the ice down a gorge, give
## `uniforms` that gorge's line instead: PeakMassif.paint() merges the result.

const LaunchArgs = preload("res://scripts/launch_args.gd")

## The shader's line length.
const POINTS := 32
## The box round the line, past its widest (m).
const BOX_PAD := 80.0

static var wanted: bool = not "--peak-ice=0" in LaunchArgs.user_args()

## The ground shader's ice uniforms for `line` ({} with --peak-ice=0 or no
## line).
static func uniforms(line: Array) -> Dictionary:
	if not wanted or line.size() < 2: return {}
	var pts := _thin(line)
	var a := PackedVector4Array()
	var more := PackedVector2Array()
	a.resize(POINTS)
	more.resize(POINTS)
	var s := 0.0
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	var widest := 0.0
	for i in pts.size():
		var p: Dictionary = pts[i]
		var at: Vector2 = p.at
		if i > 0: s += at.distance_to(pts[i-1].at)
		a[i] = Vector4(at.x,at.y,float(p.half),s)
		more[i] = Vector2(float(p.cover),float(p.debris))
		lo = lo.min(at)
		hi = hi.max(at)
		widest = maxf(widest,float(p.half))
	var pad := widest*1.1+BOX_PAD
	return {"peak_ice_on":1.0,"peak_ice_count":pts.size(),"peak_ice_line":a,"peak_ice_more":more,
		"peak_ice_box":Vector4(lo.x-pad,lo.y-pad,hi.x+pad,hi.y+pad)}

## Up to POINTS of `line`, keeping its ends and the points where its cover
## changes most.
static func _thin(line: Array) -> Array:
	if line.size() <= POINTS: return line
	var out: Array = []
	for i in POINTS: out.append(line[int(round(float(i)/(POINTS-1)*(line.size()-1)))])
	return out

## The ice gorge and the tongue below it as a line, head to toe (GORGE_POINTS of
## the gorge, then TONGUE): its head tapers out below the saddle, it comes out of
## the gorge's mouth, swells and swings down the valley's floor and ends in a
## rounded snout short of the fall.
const GORGE_POINTS := 20
const HEAD_FADE := 0.86
const WET_OVER := 6.0
## The tongue: a, v (the massif's frame), half-width (m), with its debris rising
## to bury the snout.
const TONGUE := [[2075.0,150.0,95.0],[2170.0,118.0,150.0],[2290.0,148.0,195.0],[2430.0,118.0,225.0],
	[2570.0,28.0,215.0],[2710.0,-24.0,190.0],[2830.0,-92.0,172.0],[2925.0,-102.0,148.0],
	[2990.0,-92.0,118.0],[3034.0,-82.0,84.0],[3060.0,-76.0,46.0],[3072.0,-73.0,10.0]]
static func gorge(peak: RefCounted) -> Array:
	var Split: GDScript = peak.Split
	var pts: PackedVector3Array = Split.line(Split.ICE)
	var hs: PackedFloat32Array = Split.halves(Split.ICE)
	var head: int = Split.saddle(Split.ICE)
	var out: Array = []
	for k in GORGE_POINTS:
		var i := int(round(lerpf(head,0.0,float(k)/(GORGE_POINTS-1))))
		var share := float(i)/head
		out.append({"at":peak.world(pts[i].x,pts[i].y),"half":hs[i]+WET_OVER,"cover":1.0-smoothstep(HEAD_FADE,1.0,share),"debris":0.15})
	for k in TONGUE.size():
		var r: Array = TONGUE[k]
		var u := float(k)/(TONGUE.size()-1)
		out.append({"at":peak.world(float(r[0]),float(r[1])),"half":float(r[2]),"cover":1.0,"debris":lerpf(0.25,0.95,u*u)})
	return out

## The rock gorge's floor for the ground's paint: its line (world x, z, half) as
## the shader's `peak_rock_line`, up to ROCK_POINTS points, the saddle to the nose.
const ROCK_POINTS := 24
static func rock_uniforms(peak: RefCounted) -> Dictionary:
	var Split: GDScript = peak.Split
	var pts: PackedVector3Array = Split.line(Split.ROCK)
	var hs: PackedFloat32Array = Split.halves(Split.ROCK)
	var head: int = Split.saddle(Split.ROCK)
	var line := PackedVector3Array()
	line.resize(ROCK_POINTS)
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for k in ROCK_POINTS:
		var i := int(round(lerpf(head,0.0,float(k)/(ROCK_POINTS-1))))
		var at: Vector2 = peak.world(pts[i].x,pts[i].y)
		line[k] = Vector3(at.x,at.y,hs[i])
		lo = lo.min(at)
		hi = hi.max(at)
	return {"peak_rock_count":ROCK_POINTS,"peak_rock_line":line,"peak_rock_box":Vector4(lo.x-140.0,lo.y-140.0,hi.x+140.0,hi.y+140.0)}

## The old valley as a line, head to toe: the icefall and the glacier as the
## old bands had them, the boulder field between with no ice. Close together
## where the cover changes.
static func today(peak: RefCounted) -> Array:
	var ice: Vector2 = peak.ICEFALL
	var gl: Vector2 = peak.GLACIER
	var out: Array = []
	var marks := PackedFloat32Array()
	for k in 7: marks.append(lerpf(ice.x-70.0,ice.x+30.0,k/6.0)-0.0)
	marks.resize(6)
	for k in 4: marks.append(lerpf(ice.x+90.0,ice.y-40.0,k/3.0))
	for k in 4: marks.append(lerpf(ice.y-10.0,ice.y+70.0,k/3.0))
	marks.append((ice.y+gl.x)*0.5)
	for k in 4: marks.append(lerpf(gl.x-80.0,gl.x+170.0,k/3.0))
	for k in 12: marks.append(lerpf(gl.x+340.0,gl.y-220.0,k/11.0))
	marks.append(gl.y-90.0)
	marks.append(gl.y+70.0)
	for a in marks:
		var icefall := smoothstep(ice.x-60.0,ice.x+20.0,a)*(1.0-smoothstep(ice.y-20.0,ice.y+60.0,a))
		var glacier := smoothstep(gl.x-80.0,gl.x+160.0,a)*(1.0-smoothstep(gl.y-200.0,gl.y+60.0,a))
		var t := clampf((a-gl.x)/(gl.y-gl.x),0.0,1.0)
		out.append({"at":peak.world(a,peak._valley_mid(a)),"half":_half(peak,a),"cover":icefall+glacier,"debris":lerpf(0.2,0.85,t*t)})
	return out

## The valley floor's half-width at `a` (as the old paint's).
static func _half(peak: RefCounted, a: float) -> float:
	var h: Vector4 = peak.FLOOR_HALF
	var b: Vector2 = peak.BOULDERS
	if a >= peak.ICEFALL.y and a < b.y: return lerpf(h.x,h.y,smoothstep(0.0,0.3,(a-peak.ICEFALL.y)/(b.y-peak.ICEFALL.y)))
	if a >= b.y: return lerpf(h.z,h.w,clampf((a-b.y)/(peak.GLACIER.y-b.y),0.0,1.0))
	return h.x
