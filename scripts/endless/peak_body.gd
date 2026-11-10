extends RefCounted
## A generated body for the Peak, a candidate shape chosen by
## `--peak-shape=a|b|c` (PeakMassif `body`; without the flag the massif keeps
## its old profile and this is never made). GDScript only: the flag turns the
## native twin off.
##
## Heights are over the sea, in the massif's frame (`a` along its facing, toward
## the start; `v` across), the summit at the frame's centre.
##
## The body is a pyramid of faces between main ridges, each face its own
## profile, steepening toward the top (`_prof`): the ridges are where two faces
## meet, so every ridge climbs to the summit. Over it:
##   sag       each face hollows between its ridges (`sag`, m per m out), so the
##             ridges stand as crests; `teeth` break the upper crests
##   warp      the ridges wander (and, with `twist`, curl round the summit)
##   valleys   one down a face's fall line: a floor climbing to a headwall
##             under the summit, walls up to the face either side
##   gullies   ridged noise drawn out down the fall line, closing in toward the
##             top, so the faces break into ribs and couloirs
##   the flat  a level shelf at the top among the crown's spires, to land on
##
## SHAPES holds the three candidates; each one's height is its `tall`.

const SEA_Y := -40.0
## The pyramid's foot (m over the sea): under the land, which takes over there.
const FOOT := -30.0
## A valley's floor at its mouth.
const MOUTH_Y := 15.0

## The candidates. `ridges`: [angle (degrees, 0 toward the start, + toward +v),
## run (m from the summit to where the ridge meets the foot)], in order round.
## `faces`: one per gap between ridge i and i+1: [k (profile power: higher is a
## gentler foot and a steeper top), horn (share of the height in the top's
## extra steepness), horn_reach (share of the run it spans), valley (true or
## false)]. `tall` the height where the ridges meet (the one to change for a
## taller or lower Peak); `spire` how far the main spire's tip stands over it.
## `twist` radians a km the ridges curl; `warp` (angle, radius) their wander;
## `sag` and `teeth` (m, m along) see above; `valley` {head (m from the summit),
## top (the head's floor, share of `tall`), power, half (floor's half-width at
## head and mouth), wall (slope), bend}; `gully` (m, count round, m along);
## `flat_face` the face whose valley climbs to the flat (and the quick start).
## `court` (optional): the flat on the top itself, cut level into the summit,
## {r, blend, off (m toward the flat's face), ribbon (the spirals' radius as a
## share of their own), ribbon_root (m over the court their roots), spires: [[on (the ridge it stands on, -1 behind the
## court off the flat's way), m from the summit, tip (share of `spire`), girth,
## lean in toward the court (girths)], ...] the main one first}; without it the
## flat is a shelf out on the flat's face under the CROWN spires.
## `arete` (optional): per ridge `steps` breaks (shoulders, notches, towers)
## of `amp` m, and per face `spurs` side ridges of `spur_amp` m.
const SHAPES := {
	# Four ridges square round a horn: four valleys, one up each face.
	# The crown is a court on the top among a ring of spires (`court`); the
	# ridges break into steps, notches and spurs (`arete`).
	"a": {"tall":1450.0,"spire":600.0,"twist":0.0,"warp":Vector2(0.10,0.10),
		"ridges":[[40.0,2150.0],[128.0,1950.0],[222.0,2250.0],[312.0,2050.0]],
		"faces":[[1.5,0.42,0.42,true],[1.45,0.42,0.42,true],[1.55,0.42,0.42,true],[1.5,0.42,0.42,true]],"sag":0.15,"teeth":Vector2(28.0,110.0),
		"valley":{"head":540.0,"top":0.30,"power":1.2,"half":Vector2(55.0,190.0),"wall":1.15,"bend":0.10},
		"gully":Vector3(55.0,8.0,380.0),"flat_face":3,
		"court":{"r":62.0,"blend":40.0,"off":0.0,"ribbon":0.62,"ribbon_root":15.0,
			"spires":[[-1,255.0,1.0,135.0,0.9],[1,275.0,0.62,102.0,0.6],[2,285.0,0.55,96.0,0.55],[0,280.0,0.40,84.0,0.5],[3,275.0,0.34,78.0,0.5]]},
		"arete":{"steps":3,"amp":Vector2(80.0,160.0),"spurs":2,"spur_amp":Vector2(80.0,150.0)}},
	# A long ridge running out to one side against a sheer wall on the far
	# side, between two short ridges; two big valleys either side of the long
	# ridge.
	"b": {"tall":1400.0,"spire":470.0,"twist":0.0,"warp":Vector2(0.08,0.08),
		"ridges":[[75.0,3300.0],[195.0,1100.0],[280.0,1300.0],[345.0,2300.0]],
		"faces":[[1.4,0.3,0.6,true],[1.15,0.3,0.7,false],[1.45,0.3,0.6,true],[1.5,0.3,0.6,true]],"sag":0.12,"teeth":Vector2(22.0,220.0),
		"valley":{"head":430.0,"top":0.30,"power":1.25,"half":Vector2(60.0,230.0),"wall":1.25,"bend":0.12},
		"gully":Vector3(65.0,7.0,340.0),"flat_face":3},
	# Five ridges that spiral round a slim, steep, taller body; five narrow
	# gorges curling up between them.
	"c": {"tall":1650.0,"spire":540.0,"twist":1.1,"warp":Vector2(0.10,0.08),
		"ridges":[[18.0,1700.0],[88.0,1550.0],[160.0,1750.0],[232.0,1500.0],[300.0,1650.0]],
		"faces":[[1.35,0.48,0.4,true],[1.35,0.48,0.4,true],[1.4,0.48,0.4,true],[1.3,0.48,0.4,true],[1.35,0.48,0.4,true]],"sag":0.3,"teeth":Vector2(40.0,100.0),
		"valley":{"head":380.0,"top":0.30,"power":1.15,"half":Vector2(55.0,160.0),"wall":1.8,"bend":0.15},
		"gully":Vector3(60.0,9.0,300.0),"flat_face":4},
}

## How much the warp grows from the summit out (m).
const WARP_GROW := 700.0
## The fine roughness (m) and its scale (m).
const ROUGH := 9.0
const ROUGH_SCALE := 90.0
## The flat at the top: its radius, its blend out (m), how far its centre
## stands off the summit toward the flat's face (out in front of the crown, so
## the spires and their ribbons stand in view) and how far under the body
## there it is cut.
const FLAT_R := 62.0
const FLAT_BLEND := 50.0
const FLAT_OFF := 125.0
const FLAT_UNDER := 12.0
## The crown's spires: [angle off the flat's face's way (degrees), distance
## from the summit (m), tip over `tall` (share of `spire`), girth (m)]. The
## first is the main one, behind the flat.
const CROWN := [[180.0,60.0,1.0,80.0],[100.0,235.0,0.56,52.0],[-102.0,245.0,0.46,48.0]]
## A lean (m) per metre of girth, toward the main spire's tip (the main one
## leans over the flat).
const LEAN := 2.2

var shape := ""
var tall := 0.0
## The landing flat: its centre, height (over the sea), radius and blend out.
var flat_c := Vector2.ZERO
var flat_y := 0.0
var flat_r := FLAT_R
var flat_blend := FLAT_BLEND
## The shape's `court`, or empty.
var _court: Dictionary = {}
## The broken ridges, per ridge: [[r along, half-length along, amp, half-width
## across, kind (0 a shoulder, 1 pointed)], ...]; the spurs: [start (q), way
## out, length, amp, half-width].
var _steps: Array = []
## Where the crests' teeth start (m from the summit): past the court's rim.
var _teeth_from := 80.0
var _spurs: Array = []
## Each face's g: a point q (warped) has u = q.g, 0 at the summit, 1 on the foot.
var _g := PackedVector2Array()
var _k := PackedFloat32Array()
var _horn := PackedFloat32Array()
var _horn_at := PackedFloat32Array()
var _valley := PackedByteArray()
## Each ridge's angle (warped) and each face's span (radians, ridge f to f+1).
var _ridge_th := PackedFloat32Array()
var _span := PackedFloat32Array()
var _sag := 0.0
var _teeth := Vector2.ZERO
## Each valley's fall-line angle (warped) and mouth (m).
var _phi := PackedFloat32Array()
var _mouth := PackedFloat32Array()
var _v: Dictionary
var _twist := 0.0
var _warp_amt := Vector2.ZERO
var _gully_amt := Vector3.ZERO
var _flat_face := 0
var _warp := FastNoiseLite.new()
var _rough := FastNoiseLite.new()
var _gully := FastNoiseLite.new()

## The shape `--peak-shape=` names ("" without the flag or for an unknown one).
static func wanted(args: PackedStringArray) -> String:
	for a: String in args:
		if a.begins_with("--peak-shape="):
			var s := a.get_slice("=",1).to_lower()
			if SHAPES.has(s): return s
			push_warning("--peak-shape=%s: no such shape (a, b, c)" % s)
	return ""

func _init(which: String, land_seed: int) -> void:
	shape = which
	var d: Dictionary = SHAPES[which]
	tall = float(d.tall)
	_twist = float(d.twist)
	_warp_amt = d.warp
	_gully_amt = d.gully
	_v = d.valley
	_flat_face = int(d.flat_face)
	_sag = float(d.get("sag",0.0))
	_teeth = d.get("teeth",Vector2.ZERO)
	var ridges: Array = d.ridges
	var faces: Array = d.faces
	var n := ridges.size()
	for f in n:
		var ri: Array = ridges[f]
		var rj: Array = ridges[(f+1)%n]
		_ridge_th.append(deg_to_rad(float(ri[0])))
		_span.append(wrapf(deg_to_rad(float(rj[0])-float(ri[0])),0.0,TAU))
		var bi := Vector2.from_angle(deg_to_rad(float(ri[0])))*float(ri[1])
		var bj := Vector2.from_angle(deg_to_rad(float(rj[0])))*float(rj[1])
		var det := bi.x*bj.y-bi.y*bj.x
		var g := Vector2((bj.y-bi.y)/det,(bi.x-bj.x)/det)
		_g.append(g)
		var row: Array = faces[f]
		_k.append(float(row[0]))
		_horn.append(float(row[1]))
		_horn_at.append(float(row[2]))
		_valley.append(1 if bool(row[3]) else 0)
		_phi.append(g.angle())
		_mouth.append(1.0/g.length())
	_warp.seed = hash([land_seed,"peak_body_warp"]) & 0x7fffffff
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = 1.0/700.0
	_warp.fractal_octaves = 2
	_rough.seed = hash([land_seed,"peak_body_rough"]) & 0x7fffffff
	_rough.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rough.frequency = 1.0/ROUGH_SCALE
	_rough.fractal_octaves = 3
	_gully.seed = hash([land_seed,"peak_body_gully"]) & 0x7fffffff
	_gully.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_gully.frequency = 1.0
	_gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_gully.fractal_octaves = 3
	if d.has("arete"): _broken(d.arete,ridges,land_seed)
	_court = d.get("court",{})
	if not _court.is_empty(): _teeth_from = 320.0
	if _court.is_empty():
		flat_c = Vector2.from_angle(_phi[_flat_face])*FLAT_OFF
		flat_y = _body(flat_c.x,flat_c.y).x-FLAT_UNDER
	else:
		# The court: level with the lowest of the body over its disk, so it is
		# only ever cut down into the top, never built out over a face.
		flat_r = float(_court.r)
		flat_blend = float(_court.blend)
		flat_c = Vector2.from_angle(_phi[_flat_face])*float(_court.off)
		var lo := INF
		for ring: float in [0.0,0.35,0.7,1.0,1.08]:
			for i in 32:
				var p := flat_c+Vector2.from_angle(TAU*i/32.0)*flat_r*ring
				lo = minf(lo,_body(p.x,p.y).x)
		flat_y = lo-2.0

## The ridges' breaks and the faces' spurs, placed by the seed.
func _broken(ar: Dictionary,ridges: Array,land_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([land_seed,"peak_body_arete",shape])
	var amp: Vector2 = ar.amp
	var n := ridges.size()
	var count := int(ar.steps)
	for f in n:
		var run := float(ridges[f][1])
		var list: Array = []
		for i in count:
			# Slots down the ridge from 0.16 to 0.7 of its run, jittered.
			var at := run*lerpf(0.16,0.7,(float(i)+rng.randf_range(0.2,0.8))/count)
			var a := rng.randf_range(amp.x,amp.y)
			match (i+f)%3:
				0: list.append([at,rng.randf_range(170.0,260.0),a,190.0,0])  # a shoulder
				1: list.append([at,rng.randf_range(55.0,85.0),-0.7*a,130.0,1])  # a notch
				_: list.append([at,rng.randf_range(50.0,80.0),0.8*a,110.0,1])  # a tower
		_steps.append(list)
	var samp: Vector2 = ar.spur_amp
	for f in n:
		for s in int(ar.spurs):
			# Off ridge f or the next, into face f, down and out.
			var from := f if s%2 == 0 else (f+1)%n
			var run := float(ridges[from][1])
			var th := deg_to_rad(float(ridges[from][0]))
			var off := deg_to_rad(rng.randf_range(20.0,32.0))*(1.0 if from == f else -1.0)
			var start := Vector2.from_angle(th)*run*rng.randf_range(0.28,0.5)
			_spurs.append([start,Vector2.from_angle(th+off),run*rng.randf_range(0.3,0.45),rng.randf_range(samp.x,samp.y),rng.randf_range(90.0,130.0)])

## The ground's dark rock on this body (shaders/endless_ground.gdshader
## `peak_basalt_span`, m over the sea): it and its clearing haze come in low
## on the body and together, so the body reads as one rock, not a dark top
## stacked on a pale foot.
func basalt_span() -> Vector4:
	return Vector4(-100.0,450.0,-100.0,550.0)

## How ragged its start is (m) and how much of that its haze's climb takes:
## wide, and the haze with it, so it comes in as tongues rather than at one
## height.
func basalt_rag() -> Vector3:
	return Vector3(400.0,120.0,1.0)

## The spirals on this crown: `axes` (PeakSpirals.on_towers, world, the crown's
## order) brought in to the rock and, on a court, rooted `ribbon_root` m over it
## so their coils stand in view from it, each kept 70 m off its edge
## (`court`: its world centre; `court_y` its world height).
func ribbons(axes: Array, court: Vector2, court_y: float) -> Array:
	if _court.is_empty(): return axes
	var root := court_y+float(_court.get("ribbon_root",0.0))
	for ax: Dictionary in axes:
		var b: Vector3 = ax.base
		var t: Vector3 = ax.tip
		if b.y > root and t.y > b.y: b = b.lerp(t,(root-b.y)/(t.y-b.y))
		ax.base = b
		var off := Vector2(b.x,b.z).distance_to(court)-flat_r-70.0
		ax.radius = minf(float(ax.radius)*float(_court.ribbon),maxf(off,20.0))
	return axes

## The profile's share of the height at u (1 at the summit, 0 on the foot).
func _prof(u: float, f: int) -> float:
	if u >= 1.0: return -(u-1.0)*0.4
	var base := pow(1.0-u,_k[f])
	var horn := pow(maxf(1.0-u/_horn_at[f],0.0),1.2)
	return (1.0-_horn[f])*base+_horn[f]*horn

## Vector3(height over the sea, cut 0..1, meadow) at (a, v).
func h(a: float, v: float) -> Vector3:
	var b := _body(a,v)
	# The flat at the top.
	var df := Vector2(a,v).distance_to(flat_c)
	if df < flat_r+flat_blend:
		var wf := 1.0-smoothstep(flat_r,flat_r+flat_blend,df)
		var fy := flat_y+1.5*_rough.get_noise_2d(a*3.0,v*3.0)
		# The court only cuts down; the shelf is cut and built.
		if _court.is_empty() or b.x > fy: b.x = lerpf(b.x,fy,wf)
		b.y = maxf(b.y,wf)
	return b

## The body without the flat.
func _body(a: float, v: float) -> Vector3:
	var r := sqrt(a*a+v*v)
	var th := atan2(v,a)
	var grow := smoothstep(0.0,WARP_GROW,r)
	var thw := th+_twist*r/1000.0+_warp_amt.x*_warp.get_noise_2d(a,v)*grow*PI
	var rw := r*(1.0+_warp_amt.y*_warp.get_noise_2d(a+7100.0,v-3900.0)*grow)
	var dir := Vector2(cos(thw),sin(thw))
	var q := dir*rw
	# The faces: the lowest is the one here.
	var best := INF
	var bu := 0.0
	for f in _g.size():
		var u := q.dot(_g[f])
		var y := _prof(u,f)
		if y < best:
			best = y
			bu = u
	var y := FOOT+(tall-FOOT)*best
	var fade := 1.0-smoothstep(0.75,1.05,bu)
	# The faces sag between their ridges, so the ridges stand out as crests;
	# the crests break into teeth and notches.
	var near := INF
	for f in _ridge_th.size():
		var t := wrapf(thw-_ridge_th[f],0.0,TAU)
		if t < _span[f]:
			var tf := t/_span[f]
			y -= _sag*rw*pow(sin(PI*tf),0.7)*clampf(best*1.6,0.0,1.0)
		near = minf(near,absf(wrapf(thw-_ridge_th[f],-PI,PI)))
	if _teeth.x > 0.0:
		var dr := rw*sin(minf(near,0.5*PI))
		var on := 1.0-smoothstep(0.0,90.0,dr)
		if on > 0.0: y += on*_teeth.x*_gully.get_noise_2d(rw/_teeth.y,float(_ridge_th.size())*17.0+thw*3.0)*smoothstep(_teeth_from,_teeth_from+220.0,rw)*(1.0-smoothstep(0.45,0.8,bu))
	# The ridges' breaks: shoulders (a level run, then a drop), notches and
	# towers on the crest, spread across it so they cut the skyline.
	for f in _steps.size():
		var dth := absf(wrapf(thw-_ridge_th[f],-PI,PI))
		if dth > 0.5*PI: continue
		var dr := rw*sin(dth)
		for st: Array in _steps[f]:
			var wide := float(st[3])
			if dr >= wide: continue
			var x := rw-float(st[0])
			var half := float(st[1])
			if absf(x) >= half: continue
			var s := 0.0
			if int(st[4]) == 0:
				s = (x+half)/(1.6*half) if x < 0.6*half else (half-x)/(0.4*half)
				s = smoothstep(0.0,1.0,s)
			else:
				s = pow(1.0-absf(x)/half,1.4)
			var across := 1.0-dr/wide
			y += float(st[2])*s*across*across
	# The spurs: side ridges off the main ones, down into the faces.
	for sp: Array in _spurs:
		var st: Vector2 = sp[0]
		var t := (q-st).dot(sp[1])
		var ln := float(sp[2])
		if t < -60.0 or t > ln: continue
		var wide := float(sp[4])
		var d := (q-st-(sp[1] as Vector2)*t).length()
		if d >= wide: continue
		var across := 1.0-d/wide
		y += float(sp[3])*pow(across,1.6)*(1.0-smoothstep(0.5*ln,ln,t))*smoothstep(-60.0,40.0,t)
	# Gullies and ribs down the fall line, closing in toward the top.
	var mid := clampf(bu,0.0,1.0)
	var amt := _gully_amt.x*pow(sin(PI*minf(mid*1.15,1.0)),0.6)
	if amt > 0.01:
		y += amt*_gully.get_noise_3d(dir.x*_gully_amt.y,dir.y*_gully_amt.y,rw/_gully_amt.z)
	y += ROUGH*_rough.get_noise_2d(a,v)*smoothstep(0.0,0.3,mid)
	var c := 1.0-smoothstep(0.62,0.95,bu)
	# The valleys.
	for f in _g.size():
		if _valley[f] == 0: continue
		var bend := float(_v.bend)*sin(rw/520.0+float(f)*1.7)*smoothstep(200.0,900.0,rw)
		var d := wrapf(thw-_phi[f]-bend,-PI,PI)
		if absf(d) > 1.3: continue
		var w := rw*sin(d)
		var along := rw*cos(d)
		var head := float(_v.head)
		var mouth := _mouth[f]*1.08
		var t := clampf((along-head)/(mouth-head),0.0,1.0)
		var top := FOOT+(tall-FOOT)*float(_v.top)
		var fl := MOUTH_Y+(top-MOUTH_Y)*pow(1.0-t,float(_v.power))
		# The headwall: up from the head to over the summit's height by 0.4 of
		# the head's way in, so the valleys never cut the top.
		if along < head: fl += (head-along)*(tall+60.0-top)/(head*0.6)
		var hv: Vector2 = _v.half
		var half := lerpf(hv.x,hv.y,t)
		var aw := absf(w)
		var hy := fl+0.12*half*minf(aw/half,1.0)*minf(aw/half,1.0)+maxf(aw-half,0.0)*float(_v.wall)
		if hy >= y+40.0: continue
		# A soft join where the walls meet the faces.
		var k := 40.0
		var m := clampf(0.5+0.5*(y-hy)/k,0.0,1.0)
		y = lerpf(y,hy,m)-k*m*(1.0-m)
		var past := smoothstep(1.0,1.35,along/mouth)
		c = maxf(c,(1.0-past)*(1.0-smoothstep(half+40.0,half+160.0,aw)))
	return Vector3(y,c,0.0)

## The crown in the frame: [{at (a, v), base (m over the sea), tip, lean
## (a, v), girth, seed}], the main spire first.
func crown() -> Array:
	var out: Array = []
	var way := _phi[_flat_face]
	if not _court.is_empty():
		# A ring round the court, each spire leaning in over it.
		var k := 0
		for row: Array in _court.spires:
			var on := int(row[0])
			var at := Vector2.from_angle(way+PI if on < 0 else _ridge_th[on])*float(row[1])
			var girth := float(row[3])
			var lean := (flat_c-at).normalized()*girth*float(row[4])
			# Its foot at the lowest ground round it (within reason), so on a
			# steep top it never stands out over the slope as a ledge.
			var mid := h(at.x,at.y).x
			var foot := mid
			for i in 16:
				var p := at+Vector2.from_angle(TAU*i/16.0)*girth*1.5
				foot = minf(foot,h(p.x,p.y).x)
			foot = maxf(foot,mid-450.0)
			out.append({"at":at,"base":foot-10.0,"tip":tall+float(SHAPES[shape].spire)*float(row[2]),"lean":lean,"girth":girth,"seed":31+k*17})
			k += 1
		return out
	var main_tip := Vector2.ZERO
	for k in CROWN.size():
		var row: Array = CROWN[k]
		var at := Vector2.from_angle(way+deg_to_rad(float(row[0])))*float(row[1])
		var girth := float(row[3])
		var to := flat_c if k == 0 else main_tip
		var lean := (to-at).normalized()*girth*LEAN*(0.5 if k == 0 else 1.0)
		if k == 0: main_tip = at+lean
		out.append({"at":at,"base":h(at.x,at.y).x-10.0,"tip":tall+float(SHAPES[shape].spire)*float(row[2]),"lean":lean,"girth":girth,"seed":31+k*17})
	return out

## A quick start: Vector3(a, v, heading toward the summit as an angle in the
## frame) off the flat's valley's mouth.
func start() -> Vector3:
	var r := _mouth[_flat_face]*1.25
	var at := valley_point(_flat_face,r)
	var on := valley_point(_flat_face,r-250.0)
	return Vector3(at.x,at.y,(on-at).angle())

## The flat's valley's face.
func flat_face() -> int:
	return _flat_face

## A point (a, v) on face f's valley's floor line, r m from the summit (the
## warp and the bend undone by a few fixed-point steps).
func valley_point(f: int, r: float) -> Vector2:
	var th := _phi[f]
	for i in 6:
		var p := Vector2.from_angle(th)*r
		var grow := smoothstep(0.0,WARP_GROW,r)
		var rw := r*(1.0+_warp_amt.y*_warp.get_noise_2d(p.x+7100.0,p.y-3900.0)*grow)
		var bend := float(_v.bend)*sin(rw/520.0+float(f)*1.7)*smoothstep(200.0,900.0,rw)
		th = _phi[f]+bend-_twist*r/1000.0-_warp_amt.x*_warp.get_noise_2d(p.x,p.y)*grow*PI
	return Vector2.from_angle(th)*r
