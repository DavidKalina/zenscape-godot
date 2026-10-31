extends RefCounted
## The Peak's glacier ice: what the ground shader's ice paint
## (shaders/peak_ice.gdshaderinc) reads, and the switch (--peak-ice=0: the
## older ice and seracs).
##
## The paint follows the ice's line, not the massif's axis: a list of points
## from the head to the toe, each {at (world XZ), half (m, the ice's half-width
## there), cover (0 no ice, 1 ice), debris (0 clean, 1 buried)}.
## `uniforms(line)` turns one into the shader's values (up to POINTS points;
## a longer line is thinned). `gorge(peak)` is the crown's: the ice gorge and
## the tongue below it. PeakMassif.paint() merges the result.

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
## Bare only below ROCK_SNOWED of the way down: over it the floor tapers out and
## the saddle's snow runs down into the gorge.
const ROCK_POINTS := 24
const ROCK_SNOWED := 0.2
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
		line[k] = Vector3(at.x,at.y,hs[i]*maxf(smoothstep(0.0,ROCK_SNOWED,float(k)/(ROCK_POINTS-1)),0.02))
		lo = lo.min(at)
		hi = hi.max(at)
	return {"peak_rock_count":ROCK_POINTS,"peak_rock_line":line,"peak_rock_box":Vector4(lo.x-140.0,lo.y-140.0,hi.x+140.0,hi.y+140.0)}
