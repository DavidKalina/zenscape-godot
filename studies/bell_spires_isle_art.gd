extends RefCounted
## The bell spires isle's art (studies/bell_spires_isle.gd): a crescent of
## low turf over hanging rock, and out of it and round it a stand of rock
## spires (sea stacks risen into the sky: Meteora, Zhangjiajie), each laid
## in beds of the islands' own rock, stepping in to ledges as they rise,
## turf on their tops. The hero spire stands in the middle, the belfry
## crowning it (scripts/ruin_kit_belfry.gd); round it the others at four
## heights, each tied to it by a rope bridge (scripts/rope_bridge.gd) on
## stone anchors, the bridges radiating from a stair cut into the hero's
## rock that winds up it nearly a full turn from the low stack's bridge to
## the summit. Two of the spires stand free of the isle on keels of their
## own; two stand as a split fin, a chimney 2.6 m wide between them, a
## chockstone wedged across its head. Floating stones step from the low
## stack to the south stack, and from the needle's turret to the summit.
##
## Everything is in the world's frame: the isle's turf at TOP (30 m, the
## aqueduct isle's, so the sky round it fits), the hero spire's middle at
## HERO. Directions are angles in the x-z plane (x = cos, z = sin).
##
## The layout is composed, not scattered: the hero's stair is laid first
## (its flights' risers set every height), and each spire it bridges to is
## set out along the bridge from the landing the stair reaches it at.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")
## The aqueduct isle's art, for its ground look (palette, material,
## faces, outlines): called, never changed.
const AqArt = preload("res://studies/aqueduct_isle_art.gd")
const Build = RuinKit.Build

const TOP := 30.0
const HERO := Vector2(86.0,-24.0)
## The low stack, by the start; where the stair begins (its bridge).
const LOW := Vector2(101.0,-12.0)
const RISER := RuinKit.RISER
const TREAD := RuinKit.TREAD
## The cut stair: its band out from the rock's face (in under it, out
## from it), a landing's length along the path, a bridge landing's, and
## how much further out a bridge landing stands.
const CUT_IN := 0.7
const CUT_OUT := 1.6
const LANDING := 1.3
## How far (m) each walked sector reaches over its neighbours.
const OVERLAP := 0.06
const BRIDGE_LANDING := 2.6
const BRIDGE_OUT := 1.1
## The hero's stair from the low stack's bridge to the summit: flights of
## steps, each ending on a landing ("" a plain one, else the bridge it
## gives on to, "top" the summit).
const HERO_FLIGHTS := [[9,""],[9,"gable"],[11,"fin"],[9,""],[9,"needle"],[11,""],[10,"top"]]
## The other stairs' steps: the low stack's (from the turf), the fin's low
## stack's (from the turf to the chockstone), the fin's high one's (from
## the chockstone to its top).
const LOW_STEPS := 32
const FIN_LOW_STEPS := 29
const FIN_HIGH_STEPS := 32
## Each bridge's span (m) from the hero's landing out to the spire.
const SPANS := {"low":0.0,"gable":10.0,"fin":9.0,"needle":11.0}
## The chimney between the fin's two stacks, clear across (wall kicks).
const CHIMNEY := 2.6
## Radii (m) and seeds.
const RADII := {"hero":8.2,"low":4.6,"gable":4.0,"fin_high":4.6,"fin_low":4.4,"needle":3.6}
const ROCK := Color("675b50")
## The spires' rock: the isle's, drawn a little toward a cool basalt grey.
const BASALT := Color("4d4945")
const EARTH := Color("6a4f37")
const CRAG_SHADE := 0.7
## The drift's bow out from the hero (m) and the air between its stones.
const DRIFT_BOW := 7.0
const DRIFT_GAP := 1.3
## The needle's causeway: its first stone's middle out from the needle's,
## and the stones' pitch.
const NEEDLE_FIRST := 4.2
const NEEDLE_STEP := 2.9

static var _layout := {}

## The isle laid out: {"spires": {name: spire}, "stairs": {name: stair},
## "bridges": [..], "platforms": [..], "outline": the isle's, "start",
## "chock"}. Built once.
static func layout() -> Dictionary:
	if not _layout.is_empty(): return _layout
	var spires := {}
	var hero := _make_spire("hero",HERO,RADII.hero,TOP-1.5,58.0,false,501,[])
	spires.hero = hero
	var a0 := (LOW-HERO).angle()
	var stairs := {}
	var hs := cut_stair(hero,a0,TOP+LOW_STEPS*RISER,1.0,HERO_FLIGHTS)
	stairs.hero = hs
	# Each spire off a bridge landing: along the landing's middle line.
	var bridges: Array = []
	var low_top := TOP+LOW_STEPS*RISER
	spires.low = _make_spire("low",LOW,RADII.low,TOP-1.5,low_top,false,502,[])
	for landing: Dictionary in hs.landings:
		var kind: String = landing.kind
		if kind in ["","top","start"]: continue
		var dir := Vector2.from_angle(float(landing.mid))
		var r_out: float = landing.r_out
		var at: Vector2 = HERO+dir*(r_out+float(SPANS.get(kind,9.0)))
		var y: float = landing.y
		match kind:
			"gable":
				var c := at+dir*RADII.gable*0.85
				spires.gable = _make_spire("gable",c,RADII.gable,y-26.0,y,true,503,[])
			"needle":
				var c := at+dir*RADII.needle*0.85
				spires.needle = _make_spire("needle",c,RADII.needle,y-30.0,y,true,504,[])
			"fin":
				# The fin's high stack on the bridge's line; its low stack
				# beside it across the chimney, a quarter turn round.
				var c := at+dir*RADII.fin_high*0.85
				var side := Vector2.from_angle(float(landing.mid)-PI*0.5)
				var d1: float = RADII.fin_high*0.78
				var d2: float = RADII.fin_low*0.78
				var c2 := c+side*(d1+CHIMNEY+d2)
				var low_y := TOP+FIN_LOW_STEPS*RISER
				spires.fin_high = _make_spire("fin_high",c,RADII.fin_high,TOP-1.5,low_y+FIN_HIGH_STEPS*RISER,false,505,[[side,d1]])
				spires.fin_low = _make_spire("fin_low",c2,RADII.fin_low,TOP-1.5,low_y,false,506,[[-side,d2]])
	# The bridges: from the hero's landing to the spire's edge (the low
	# stack's: from its top to the hero's first landing).
	for landing: Dictionary in hs.landings:
		var kind: String = landing.kind
		if kind in ["","top","start"]: continue
		var dir := Vector2.from_angle(float(landing.mid))
		var y: float = landing.y
		var from := HERO+dir*(float(landing.r_out)-0.7)
		var target: Dictionary = spires[{"low":"low","gable":"gable","fin":"fin_high","needle":"needle"}[kind]]
		var c: Vector2 = target.c
		var back := (HERO-c).angle()
		var edge := radius_at(target,back,y-0.05)-0.9
		var to := c+Vector2.from_angle(back)*edge
		bridges.append({"name":kind,"a":Vector3(from.x,y,from.y),"b":Vector3(to.x,y,to.y),"to":target.name})
	# The fin: the chockstone across the chimney's outer end at the low
	# stack's top; the low stack's stair up from the turf to it, the high
	# one's on from it to the top.
	var fh: Dictionary = spires.fin_high
	var fl: Dictionary = spires.fin_low
	var axis: Vector2 = ((fl.c as Vector2)-(fh.c as Vector2)).normalized()
	var along := Vector2(-axis.y,axis.x)
	if along.dot((fh.c as Vector2)-HERO) < 0.0: along = -along
	var mid: Vector2 = (fh.c as Vector2).lerp(fl.c,float(RADII.fin_high*0.78+CHIMNEY*0.5)/((fl.c as Vector2)-(fh.c as Vector2)).length())
	var chock_y: float = fl.top
	var chock := {"at":Vector3(mid.x,chock_y,mid.y)+Vector3(along.x,0.0,along.y)*1.6,"axis":axis,"along":along}
	stairs.fin_low = _stair_to(fl,(Vector2(chock.at.x,chock.at.z)-(fl.c as Vector2)).angle(),TOP,FIN_LOW_STEPS,1.0)
	stairs.fin_high = cut_stair(fh,(Vector2(chock.at.x,chock.at.z)-(fh.c as Vector2)).angle(),chock_y,-1.0,[[FIN_HIGH_STEPS/2,""],[FIN_HIGH_STEPS-FIN_HIGH_STEPS/2,"top"]])
	# The low stack's stair: from the turf on its east, ending on the side
	# away from the hero, so its top is crossed to the bridge.
	stairs.low = _stair_to(spires.low,a0+0.35,TOP,LOW_STEPS,-1.0)
	bridges.push_front({"name":"low","a":Vector3(0,0,0),"b":Vector3(0,0,0),"to":"low"})
	var first: Dictionary = hs.landings[0]
	var hdir := Vector2.from_angle(float(first.mid))
	var hfrom := HERO+hdir*(float(first.r_out)-0.7)
	var lr := radius_at(spires.low,a0+PI,low_top-0.05)-0.9
	var lto := LOW+Vector2.from_angle(a0+PI)*lr
	bridges[0] = {"name":"low","a":Vector3(hfrom.x,low_top,hfrom.y),"b":Vector3(lto.x,low_top,lto.y),"to":"low"}
	var out := {"spires":spires,"stairs":stairs,"bridges":bridges,"chock":chock}
	_layout = out
	out.platforms = _platforms(out)
	out.outline = _outline(out)
	var foot: Dictionary = stairs.low.steps[0]
	var fp := (spires.low.c as Vector2)+Vector2.from_angle(float(foot.mid))*(float(foot.r_out)+1.8)
	out.start = Vector3(fp.x,TOP,fp.y)
	out.start_face = (LOW-fp).normalized()
	return out

static func spire(name: String) -> Dictionary:
	return layout().spires.get(name,{})

# --- Spires ---------------------------------------------------------------------------

## A spire: its middle, radius, the y its beds start at (under the turf, or
## its keel's waist when it stands free), its top, its beds [y0, y1, scale
## at y0, at y1], its plan's waves, its flat clips [[way (x, z), distance
## from its middle]] (the chimney's faces), and whether it stands free.
static func _make_spire(name: String, c: Vector2, r: float, foot: float, top: float, free: bool, seed_value: int, clips: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var beds: Array = []
	var taper := 0.8 if not free else 0.92
	var y := foot
	var prev := 1.14 if not free else rng.randf_range(0.9,1.0)
	while y < top-0.01:
		var h := rng.randf_range(2.4,4.4)
		if top-(y+h) < 1.8: h = top-y
		var t0 := (y-foot)/(top-foot)
		var t1 := (y+h-foot)/(top-foot)
		var s0: float
		var s1: float
		if free:
			# A free stack swells and pinches bed by bed (a notch, a proud
			# bed overhanging the one under it), widest a third of the way up.
			var swell := 0.9+0.12*sin(t0*PI*1.2+0.4)
			s0 = swell+rng.randf_range(-0.06,0.07)
			s1 = s0-rng.randf_range(0.0,0.04)
		else:
			# A stack with a stair: never wider over a bed than under it,
			# stepping in now and then to a ledge.
			var want0 := lerpf(1.12,taper,pow(t0,0.85))
			var want1 := lerpf(1.12,taper,pow(t1,0.85))
			var inset := rng.randf_range(0.06,0.11) if rng.randf() < 0.45 else rng.randf_range(0.0,0.015)
			s0 = minf(prev-inset,want0+0.03)
			s1 = minf(s0-0.01,want1+0.04)
			s0 = maxf(s0,taper-0.06)
			s1 = maxf(minf(s1,s0),taper-0.08)
		beds.append([y,y+h,s0,s1])
		prev = s1
		y += h
	var waves := [rng.randf()*TAU,rng.randf()*TAU,rng.randf_range(0.05,0.08),rng.randf_range(0.02,0.035)]
	var s := {"name":name,"c":c,"r":r,"foot":foot,"top":top,"beds":beds,"waves":waves,"clips":clips,"free":free,"seed":seed_value}
	if free:
		# Its keel under the waist: two beds drawing in to a point.
		var s_first: float = (beds[0] as Array)[2]
		var deep := (top-foot)*0.45
		s.keel = [[foot-deep*0.45,foot,s_first*0.62,s_first],[foot-deep,foot-deep*0.45,0.08,s_first*0.62]]
	return s

## The spire's plan radius at angle `a` for bed scale `scale`: its waves,
## cut by its clips.
static func plan_r(s: Dictionary, a: float, scale: float) -> float:
	var w: Array = s.waves
	var r: float = float(s.r)*scale*(1.0+float(w[2])*sin(3.0*a+float(w[0]))+float(w[3])*sin(5.0*a+float(w[1])))
	for clip: Array in s.clips:
		var n: Vector2 = clip[0]
		var k := Vector2.from_angle(a).dot(n)
		if k > 0.01: r = minf(r,float(clip[1])/k)
	return r

## The bed scale at height `y` (the top bed's over the top, the first's
## under the foot).
static func scale_at(s: Dictionary, y: float) -> float:
	for bed: Array in s.beds:
		if y <= float(bed[1]): return lerpf(float(bed[2]),float(bed[3]),clampf((y-float(bed[0]))/maxf(float(bed[1])-float(bed[0]),0.01),0.0,1.0))
	return float((s.beds[s.beds.size()-1] as Array)[3])

## How far the rock's face stands from the spire's middle at angle `a`,
## height `y`.
static func radius_at(s: Dictionary, a: float, y: float) -> float:
	return plan_r(s,a,scale_at(s,y))

## The spire's turf top's outline (world x, z).
static func top_outline(s: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var last: Array = s.beds[s.beds.size()-1]
	for i in range(RING):
		var a := TAU*i/RING
		out.append((s.c as Vector2)+Vector2.from_angle(a)*plan_r(s,a,float(last[3])))
	return out

## The turf's height on a spire's top at `p`: a low dome over its rim.
static func top_height(s: Dictionary, p: Vector2) -> float:
	var c: Vector2 = s.c
	var a := (p-c).angle()
	var edge := radius_at(s,a,float(s.top)-0.01)
	var t := clampf((p-c).length()/maxf(edge,0.1),0.0,1.0)
	return float(s.top)+0.35*(1.0-t*t)

const RING := 20

## A spire drawn and collided: its beds (and keel) as faceted rings of the
## isle's rock, the steps between beds as ledges (turf-green where wide),
## each bed a convex hull; and its turf top (`top_turf`).
static func spire_rock(s: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed)*13+7
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var body := StaticBody3D.new()
	body.name = "Body"
	var c: Vector2 = s.c
	var c3 := Vector3(c.x,0.0,c.y)
	var beds: Array = []
	if s.has("keel"): beds.append_array(s.keel)
	beds.append_array(s.beds)
	var pal := AqArt.palette()
	var grass: Array = pal.grass
	var last_ring: Array = []
	for k in range(beds.size()):
		var bed: Array = beds[k]
		# Its rings: at its foot and head, and between them every metre and
		# a half or so (pushed out and in more, so its faces break up).
		var rows := maxi(1,int(round((float(bed[1])-float(bed[0]))/1.5)))
		var rings: Array = []
		for e in range(rows+1):
			var f := float(e)/rows
			var y: float = lerpf(float(bed[0]),float(bed[1]),f)
			var scale: float = lerpf(float(bed[2]),float(bed[3]),f)
			var ring: Array[Vector3] = []
			var top_ring := k == beds.size()-1 and e == rows
			var inner := e > 0 and e < rows
			for i in range(RING):
				var a := TAU*i/RING
				var r := plan_r(s,a,scale)
				var flat := false
				for clip: Array in s.clips:
					var kk := Vector2.from_angle(a).dot(clip[0])
					if kk > 0.01 and r >= float(clip[1])/kk-0.001: flat = true
				var spread := 0.32 if inner else 0.2
				var jitter := 0.0 if (flat or top_ring) else rng.randf_range(-spread,spread)-0.32*pow(absf(sin(a*3.5+float(s.seed))),8.0)
				var dy := rng.randf_range(-0.25,0.25) if inner else 0.0
				ring.append(c3+Vector3(cos(a)*(r+jitter),y+dy,sin(a)*(r+jitter)))
			rings.append(ring)
		var lo: Array = rings[0]
		var hi: Array = rings[rows]
		var band := 0.88+0.14*sin(float(bed[0])*1.3)+rng.randf_range(-0.08,0.08)
		for e in range(rows):
			var r0: Array = rings[e]
			var r1: Array = rings[e+1]
			for i in range(RING):
				var j := (i+1)%RING
				var mid: Vector3 = (r0[i]+r1[j])*0.5
				var out := Vector3(mid.x-c.x,0.0,mid.z-c.y).normalized()
				AqArt._tri(v,n,col,[r0[i],r0[j],r1[j]],_rock_tone(rng,mid,band),out)
				AqArt._tri(v,n,col,[r0[i],r1[j],r1[i]],_rock_tone(rng,mid,band),out)
		# The step from the bed under: a ledge where this one is narrower.
		if not last_ring.is_empty():
			for i in range(RING):
				var j := (i+1)%RING
				var under: Vector3 = last_ring[i]
				var here: Vector3 = lo[i]
				var wider := Vector2(under.x-c.x,under.z-c.y).length()-Vector2(here.x-c.x,here.z-c.y).length()
				var up := (Vector3.UP if wider > 0.0 else Vector3.DOWN)+Vector3(here.x-c.x,0.0,here.z-c.y).normalized()*0.6
				var tone := _rock_tone(rng,here,band*0.95)
				if wider > 0.45 and rng.randf() < 0.65: tone = (grass[rng.randi()%grass.size()] as Color).linear_to_srgb()*rng.randf_range(0.85,1.0)
				# Both ways: where the beds' rings cross, the step is a sliver
				# seen from either side.
				for way: Vector3 in [up,-up]:
					AqArt._tri(v,n,col,[last_ring[i],last_ring[j],lo[j]],tone,way)
					AqArt._tri(v,n,col,[last_ring[i],lo[j],lo[i]],tone,way)
		# The first bed's foot (a free stack's keel point).
		if k == 0:
			var point := c3+Vector3(rng.randf_range(-0.5,0.5),float(bed[0])-(1.5 if s.free else 0.0),rng.randf_range(-0.5,0.5))
			for i in range(RING):
				var j := (i+1)%RING
				AqArt._tri(v,n,col,[lo[i],point,lo[j]],_rock_tone(rng,point,0.85),Vector3.DOWN)
		last_ring = hi
		var hull := PackedVector3Array()
		for ring: Array in rings:
			for p: Vector3 in ring: hull.append(p)
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var holder := CollisionShape3D.new()
		holder.shape = shape
		body.add_child(holder)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := Node3D.new()
	node.name = "Spire_"+str(s.name)
	var drawn := MeshInstance3D.new()
	drawn.name = "Mesh"
	drawn.mesh = mesh
	drawn.material_override = RuinKit.materials().stone
	node.add_child(drawn)
	node.add_child(body)
	return node

static func _rock_tone(rng: RandomNumberGenerator, at: Vector3, band: float) -> Color:
	var b := band*(0.9+0.1*sin(at.y*2.1))*lerpf(0.8,1.0,clampf((at.y-TOP+10.0)/40.0,0.0,1.0))
	return ROCK.lerp(BASALT,0.7)*b*rng.randf_range(0.84,1.12)

## A spire's turf top (the ground look, collided as one trimesh).
static func top_turf(s: Dictionary) -> Node3D:
	var outline := top_outline(s)
	var height := func(x: float, z: float) -> float: return top_height(s,Vector2(x,z))
	var node := turf(outline,height,int(s.seed)+40,1.3)
	node.name = "Top_"+str(s.name)
	return node

# --- The cut stairs -------------------------------------------------------------------

## A stair cut into a spire's rock, winding round it from angle `a0` (rad)
## at height `y0`, `way` +1 counterclockwise in (x, z) or -1, in `flights`
## [[steps, landing kind]]: a landing first (where it is come on to), then
## each flight's steps (RISER up, TREAD along its middle line) and its
## landing. Each step and landing: {a0, a1, mid (angles), y (its top),
## r_in, r_out (from the middle), kind}. The band reaches CUT_IN into the
## rock under the face and CUT_OUT out from it.
static func cut_stair(s: Dictionary, a0: float, y0: float, way: float, flights: Array) -> Dictionary:
	var steps: Array = []
	var landings: Array = []
	var a := a0
	var y := y0
	var first := _landing(s,a,y,way,BRIDGE_LANDING,"start")
	landings.append(first)
	a = first.end
	for f: Array in flights:
		for i in range(int(f[0])):
			y += RISER
			var face := radius_at(s,a,y)
			var da := TREAD/(face+CUT_OUT*0.4)
			var st := _sector(s,a,a+da*way,y,"step")
			steps.append(st)
			a += da*way
		var kind: String = f[1]
		var l := _landing(s,a,y,way,BRIDGE_LANDING if kind not in ["","top"] else LANDING,kind)
		landings.append(l)
		a = l.end
	return {"steps":steps,"landings":landings,"way":way,"spire":s.name,"end":a,"top":y}

## A stair of `count` steps up from `y0` that ends at angle `a_end`: laid
## from the angle that brings it there.
static func _stair_to(s: Dictionary, a_end: float, y0: float, count: int, way: float) -> Dictionary:
	var flights := [[count/3,""],[count/3,""],[count-2*(count/3),"top"]]
	var trial := cut_stair(s,0.0,y0,way,flights)
	var sweep := float(trial.end)
	return cut_stair(s,a_end-sweep,y0,way,flights)

static func _landing(s: Dictionary, a: float, y: float, way: float, length: float, kind: String) -> Dictionary:
	var face := radius_at(s,a,y)
	var da := length/(face+CUT_OUT*0.5)
	var l := _sector(s,a,a+da*way,y,"landing")
	l.kind = kind
	l.end = a+da*way
	if kind not in ["","top","start"]: l.r_out += BRIDGE_OUT
	if kind == "start" and s.name == "hero": l.r_out += BRIDGE_OUT
	return l

static func _sector(s: Dictionary, a0: float, a1: float, y: float, kind: String) -> Dictionary:
	var lo := minf(a0,a1)
	var hi := maxf(a0,a1)
	var mid := (lo+hi)*0.5
	# The face over the step (the bed over it is never wider: the cut
	# reaches under the narrowest of its ends and middle).
	var face := minf(radius_at(s,mid,y+0.05),minf(radius_at(s,lo,y+0.05),radius_at(s,hi,y+0.05)))
	var under := maxf(radius_at(s,mid,y-0.6),face)
	return {"a0":lo,"a1":hi,"mid":mid,"y":y,"r_in":face-CUT_IN,"r_out":under+CUT_OUT,"kind":kind}

## The sector `st` of spire middle `c` between its angles, from `bottom` to
## `top`, its outer face leaning out `lean` (0 upright) as planes.
static func sector_planes(c: Vector2, st: Dictionary, bottom: float, top: float, r_in: float, r_out: float, lean := 0.0) -> Array[Plane]:
	var c3 := Vector3(c.x,0.0,c.y)
	var lo: float = st.a0
	var hi: float = st.a1
	var mid: float = st.mid
	var half := (hi-lo)*0.5
	var radial := Vector3(cos(mid),0.0,sin(mid))
	var planes: Array[Plane] = [Plane(Vector3.UP,top),Plane(Vector3.DOWN,-bottom)]
	var nlo := -Vector3(-sin(lo),0.0,cos(lo))
	var nhi := Vector3(-sin(hi),0.0,cos(hi))
	planes.append(Plane(nlo,nlo.dot(c3)))
	planes.append(Plane(nhi,nhi.dot(c3)))
	var outer := radial
	var at := c3+radial*r_out*cos(half)+Vector3.UP*top
	if lean != 0.0: outer = (radial+Vector3.UP*lean).normalized()
	planes.append(Plane(outer,outer.dot(at)))
	planes.append(Plane(-radial,-(radial.dot(c3)+r_in*cos(half))))
	return planes

## A stair drawn (worn steps of the kit's stone over a corbel of rock
## each) and walked (each step's clean sector, down past the one under, so
## no joint is a gap).
static func stair_node(stair: Dictionary, seed_value: int) -> Node3D:
	var s: Dictionary = spire(stair.spire)
	var c: Vector2 = s.c
	var b := Build.new(seed_value,0.35,"Stair_"+str(stair.spire))
	var all: Array = []
	all.append_array(stair.steps)
	all.append_array(stair.landings)
	for st: Dictionary in all:
		var y: float = st.y
		# A stair come on to from the turf starts on the turf itself.
		if y <= TOP+0.01: continue
		var r_in: float = st.r_in
		var r_out: float = st.r_out
		var split := int(ceil((float(st.a1)-float(st.a0))*r_out/0.9))
		for k in range(split):
			var part := st.duplicate()
			part.a0 = lerpf(float(st.a0),float(st.a1),float(k)/split)
			part.a1 = lerpf(float(st.a0),float(st.a1),float(k+1)/split)
			part.mid = (float(part.a0)+float(part.a1))*0.5
			b.lean = true
			b.solid(sector_planes(c,part,y-0.34,y,r_in,r_out-0.02),Transform3D.IDENTITY,RuinKit._stone(b,1.1),false,true,[],-1,0.5,false)
			b.lean = false
			# The rock it is cut from, drawing in under it.
			b.solid(sector_planes(c,part,y-2.6,y-0.34,r_in,r_out,-1.4),Transform3D.IDENTITY,ROCK.lerp(BASALT,0.7)*b.rng.randf_range(0.8,0.96),false,true,[],-1,1.2,false)
			# Walked on a clean sector a little wider than its own, so the seam
			# with the next is never a gap a ray slips through.
			var walked: Dictionary = part.duplicate()
			var over := OVERLAP/maxf(r_out,1.0)
			walked.a0 = float(part.a0)-over
			walked.a1 = float(part.a1)+over
			RuinKit._walk_hull(b,Transform3D.IDENTITY,sector_planes(c,walked,y-RISER-0.4,y,r_in,r_out))
	return b.finish()

# --- The turf -------------------------------------------------------------------------

## Turf over `outline` (world), its height `height` (x, z), faces about
## `cell` m: the ground look (the sky islets' material and palette), its
## faces collided as one trimesh ("Body"); meta "outline".
static func turf(outline: PackedVector2Array, height: Callable, seed_value: int, cell: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := PackedVector2Array(outline)
	var heights := PackedFloat32Array()
	for p in outline: heights.append(height.call(p.x,p.y))
	var box := Rect2(outline[0],Vector2.ZERO)
	for p in outline: box = box.expand(p)
	var gx := box.position.x+cell*0.5
	while gx < box.end.x:
		var gz := box.position.y+cell*0.5
		while gz < box.end.y:
			var p := Vector2(gx+rng.randf_range(-0.3,0.3)*cell,gz+rng.randf_range(-0.3,0.3)*cell)
			gz += cell
			if not Geometry2D.is_point_in_polygon(p,outline) or AqArt._edge_distance(p,outline) <= cell*0.45: continue
			points.append(p)
			heights.append(height.call(p.x,p.y))
		gx += cell
	var tris := Geometry2D.triangulate_delaunay(points)
	var pal := AqArt.palette()
	var patch := FastNoiseLite.new()
	patch.seed = seed_value+5
	patch.frequency = 0.4
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var faces := PackedVector3Array()
	for t in range(0,tris.size(),3):
		var a := points[tris[t]]
		var bb := points[tris[t+1]]
		var cc := points[tris[t+2]]
		var mid := (a+bb+cc)/3.0
		if not Geometry2D.is_point_in_polygon(mid,outline): continue
		var pa := Vector3(a.x,heights[tris[t]],a.y)
		var pb := Vector3(bb.x,heights[tris[t+1]],bb.y)
		var pc := Vector3(cc.x,heights[tris[t+2]],cc.y)
		faces.append_array([pa,pb,pc])
		var normal := (pb-pa).cross(pc-pa).normalized()
		if normal.y < 0.0:
			normal = -normal
			var swap := pb
			pb = pc
			pc = swap
		var tone := ground_tone(pal,patch,mid,normal,rng.randf_range(-0.035,0.035))
		for p: Vector3 in [pa,pc,pb]:
			v.append(p-Vector3(0.0,0.02,0.0))
			n.append(normal)
			c.append(tone)
			uv.append(Vector2(0.0,1.0))
			uv2.append(Vector2(0.5,p.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,AqArt.ground_material())
	var node := Node3D.new()
	node.name = "Turf"
	var drawn := MeshInstance3D.new()
	drawn.name = "Ground"
	drawn.mesh = mesh
	node.add_child(drawn)
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
	node.set_meta("outline",outline)
	return node

## A ground face's colour (linear), as the aqueduct isle's (AqArt
## `ground_tone`), worn by this isle's own paths.
static func ground_tone(pal: Dictionary, patch: FastNoiseLite, at: Vector2, normal: Vector3, shimmer: float) -> Color:
	var grass: Array = pal.grass
	var n := patch.get_noise_2d(at.x,at.y)*0.5+0.5
	var tone: Color = grass[1 if n > 0.55 else (2 if n < 0.42 else 0)]
	var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
	if slope > float(pal.rock_slope):
		var rock: Array = pal.rock
		tone = rock[0 if patch.get_noise_2d(at.x+71.0,at.y) > 0.0 else rock.size()-1]
		tone *= CRAG_SHADE+0.12*patch.get_noise_2d(at.x*0.7-13.0,at.y*0.7)
	else:
		var worn := path_wear(at)
		if worn > 0.0: tone = tone.lerp((pal.gravel as Color).lerp(EARTH.srgb_to_linear(),0.45)*lerpf(0.85,1.0,n),worn*0.8)
	return Color(tone.r+shimmer,tone.g+shimmer,tone.b+shimmer,1.0)

# --- The isle -------------------------------------------------------------------------

## The isle's outline: round the hero, the low stack and the fin (a star
## round their middle), drawn in where the free stacks stand off it.
static func _outline(l: Dictionary) -> Array:
	var on: Array = []
	for name: String in ["hero","low","fin_high","fin_low"]:
		var s: Dictionary = l.spires[name]
		on.append([s.c,float(s.r)*1.14+(6.5 if name == "low" else 4.2)])
	var middle := Vector2.ZERO
	for d: Array in on: middle += d[0]
	middle /= on.size()
	var off: Array = []
	for name: String in ["gable","needle"]:
		var s: Dictionary = l.spires[name]
		off.append([s.c,float(s.r)*1.1+5.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var radii: Array[float] = []
	var count := 72
	for i in range(count):
		var u := Vector2.from_angle(TAU*i/count)
		var best := 6.0
		for d: Array in on:
			# The far side of disc d along the ray from the middle.
			var rel: Vector2 = (d[0] as Vector2)-middle
			var along := rel.dot(u)
			var across2 := rel.length_squared()-along*along
			var r: float = d[1]
			if across2 < r*r: best = maxf(best,along+sqrt(r*r-across2))
		# Drawn in short of a free stack.
		var t := best
		while t > 4.0:
			var p := middle+u*t
			var clear := true
			for d: Array in off:
				if p.distance_to(d[0]) < float(d[1]): clear = false
			if clear: break
			t -= 0.5
		radii.append(t)
	var out: Array = []
	for i in range(count):
		var r := (radii[(i-1+count)%count]+radii[i]*2.0+radii[(i+1)%count])*0.25
		out.append(middle+Vector2.from_angle(TAU*i/count)*(r+rng.randf_range(-0.5,0.5)))
	return out

## The isle's ground: level at TOP but for a gentle swell.
static func ground(x: float, z: float) -> float:
	return TOP+0.25*sin(x*0.21+1.0)*sin(z*0.17-0.5)

## The isle itself: turf over the outline, and its sides and keel of
## hanging rock (as AqArt `island`), its keel's point `depth` under it.
static func island(seed_value: int, depth := 24.0) -> Node3D:
	var l := layout()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ring: Array[Vector2] = AqArt._resample(l.outline,96,rng)
	var poly := PackedVector2Array(ring)
	var node := turf(poly,func(x: float, z: float) -> float: return ground(x,z),seed_value,2.0)
	node.name = "Isle"
	var centre := Vector2.ZERO
	for p in ring: centre += p
	centre /= ring.size()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var count := ring.size()
	var outward: Array[Vector2] = []
	var ccw := AqArt._area(ring) > 0.0
	for i in range(count):
		var tangent: Vector2 = (ring[(i+1)%count]-ring[(i-1+count)%count]).normalized()
		outward.append(Vector2(tangent.y,-tangent.x) if ccw else Vector2(-tangent.y,tangent.x))
	var rims: Array = []
	var top_ring: Array[Vector3] = []
	for i in range(count): top_ring.append(Vector3(ring[i].x,ground(ring[i].x,ring[i].y)-0.02,ring[i].y))
	rims.append(top_ring)
	var specs := [[0.0,0.45,0.28,1],[0.0,2.1,0.35,1],[0.1,depth*0.22,0.0,2],[0.32,depth*0.48,0.0,4],[0.6,depth*0.74,0.0,8],[0.82,depth*0.92,0.0,16]]
	for spec: Array in specs:
		var stride: int = spec[3]
		var r: Array[Vector3] = []
		for i in range(0,count,stride):
			var p := ring[i]
			var q := p.lerp(centre,clampf(float(spec[0])+rng.randf_range(-0.05,0.05)*float(float(spec[0]) > 0.0),0.0,0.95))+outward[i]*float(spec[2])*rng.randf_range(0.3,1.2)
			r.append(Vector3(q.x,TOP-float(spec[1])*rng.randf_range(0.85,1.15),q.y))
		rims.append(r)
	var keel := Vector3(centre.x+rng.randf_range(-2.0,2.0),TOP-depth,centre.y+rng.randf_range(-2.0,2.0))
	for k in range(rims.size()-1):
		var upper: Array = rims[k]
		var lower: Array = rims[k+1]
		var ratio := upper.size()/lower.size()
		for j in range(lower.size()):
			var l0: Vector3 = lower[j]
			var l1: Vector3 = lower[(j+1)%lower.size()]
			for s in range(ratio):
				var u0: Vector3 = upper[j*ratio+s]
				var u1: Vector3 = upper[(j*ratio+s+1)%upper.size()]
				AqArt._tri(v,n,c,[u0,l0,u1],AqArt._side_tone(rng,(u0+u1+l0)/3.0,k),AqArt._out(centre,(u0+u1+l0)/3.0))
			var ue: Vector3 = upper[((j+1)*ratio)%upper.size()]
			AqArt._tri(v,n,c,[ue,l0,l1],AqArt._side_tone(rng,(ue+l0+l1)/3.0,k),AqArt._out(centre,(ue+l0+l1)/3.0))
	var last: Array = rims[rims.size()-1]
	for j in range(last.size()):
		var a: Vector3 = last[j]
		var b2: Vector3 = last[(j+1)%last.size()]
		var mid := (a+b2+keel)/3.0
		AqArt._tri(v,n,c,[a,keel,b2],AqArt._side_tone(rng,mid,9),AqArt._out(centre,mid)+Vector3.DOWN)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var drawn := MeshInstance3D.new()
	drawn.name = "Mesh"
	drawn.mesh = mesh
	drawn.material_override = RuinKit.materials().stone
	node.add_child(drawn)
	return node

# --- Paths ----------------------------------------------------------------------------

static var _paths: Array = []

## How worn the ground is at `at` (0 off the paths, 1 on their middle):
## from the start to the low stack's stair and round to the fin's.
static func path_wear(at: Vector2) -> float:
	if _paths.is_empty():
		var l := layout()
		var start := Vector2(l.start.x,l.start.z)
		var low_foot := _stair_foot(l.stairs.low,l.spires.low)
		var fin_foot := _stair_foot(l.stairs.fin_low,l.spires.fin_low)
		var hero: Dictionary = l.spires.hero
		var round_by := HERO+((start+fin_foot)*0.5-HERO).normalized()*(float(hero.r)*1.14+2.4)
		_paths = [[start,low_foot],[start,start.lerp(round_by,0.5),round_by,fin_foot]]
	var best := INF
	for path: Array in _paths:
		for i in range(path.size()-1):
			best = minf(best,at.distance_to(Geometry2D.get_closest_point_to_segment(at,path[i],path[i+1])))
	return clampf(1.25-best/1.5,0.0,1.0)

## Where a stair from the turf begins: just off its first step.
static func _stair_foot(stair: Dictionary, s: Dictionary) -> Vector2:
	var first: Dictionary = stair.landings[0]
	return (s.c as Vector2)+Vector2.from_angle(float(first.mid))*(float(first.r_out)+0.9)

static func palette() -> Dictionary:
	return AqArt.palette()

static func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	return AqArt._edge_distance(p,poly)

static func _area(ring: Array) -> float:
	return AqArt._area(ring)

# --- Floating stones ------------------------------------------------------------------

## The floating stones: {name, at (its top's middle), size, yaw, kind,
## chain}. "drift": from the low stack's top up to the south stack's, a
## metre a stone; "needle": from the needle's turret head across to the
## summit; two loose ones off the hero, a perch and a vista.
static func _platforms(l: Dictionary) -> Array:
	var out: Array = []
	# The drift: a necklace of stones hung in an arc out in front of the
	# hero (bowed DRIFT_BOW m away from it), from the low stack's top to the
	# gable stack's, rising evenly, DRIFT_GAP m of air between stones.
	var low: Dictionary = l.spires.low
	var gable: Dictionary = l.spires.gable
	var a: Vector2 = low.c
	var b: Vector2 = gable.c
	var bow := (a+b)*0.5+((a+b)*0.5-HERO).normalized()*DRIFT_BOW
	var curve := func(t: float) -> Vector2: return a.lerp(bow,t).lerp(bow.lerp(b,t),t)
	var t0 := 0.0
	while curve.call(t0).distance_to(a) < radius_at(low,(curve.call(t0)-a).angle(),float(low.top))+0.4: t0 += 0.002
	var t1 := 1.0
	while curve.call(t1).distance_to(b) < radius_at(gable,(curve.call(t1)-b).angle(),float(gable.top))+0.4: t1 -= 0.002
	var length := 0.0
	for k in range(100): length += (curve.call(lerpf(t0,t1,(k+1)/100.0)) as Vector2).distance_to(curve.call(lerpf(t0,t1,k/100.0)))
	var count := maxi(3,int(round(length/(2.0+DRIFT_GAP))))
	var rise := (float(gable.top)-float(low.top))/(count+1)
	for i in range(count):
		var t := lerpf(t0,t1,(i+0.5)/count)
		var p: Vector2 = curve.call(t)
		var way: Vector2 = ((curve.call(minf(t+0.01,1.0)) as Vector2)-curve.call(maxf(t-0.01,0.0))).normalized()
		out.append({"name":"drift_%d" % (i+1),"at":Vector3(p.x,float(low.top)+rise*(i+1),p.y),"size":Vector3(2.0,0.7,1.8),
			"yaw":-way.angle()+(0.25 if i%2 == 0 else -0.2),"kind":"lintel" if i == count/2 else "block","chain":"drift"})
	var needle: Dictionary = l.spires.needle
	var hero: Dictionary = l.spires.hero
	var nc: Vector2 = needle.c
	var hw := (HERO-nc).normalized()
	var head := float(needle.top)+18*RISER
	# From the turret's head across to the summit's lip: a causeway of
	# stones at about its height, a metre of air between them.
	var edge := (HERO-nc).length()-radius_at(hero,(-hw).angle(),float(hero.top))
	count = int(floor((edge-NEEDLE_FIRST+1.0)/NEEDLE_STEP))
	var lift := (float(hero.top)+0.5-head)/count
	for i in range(count):
		var p := nc+hw*(NEEDLE_FIRST+NEEDLE_STEP*i)
		var side := Vector2(-hw.y,hw.x)*(0.5 if i%2 == 0 else -0.4)
		out.append({"name":"needle_%d" % (i+1),"at":Vector3(p.x+side.x,head+0.35+lift*i,p.y+side.y),"size":Vector3(1.9,0.7,1.7),
			"yaw":-hw.angle()+(0.25 if i%2 == 1 else -0.3),"kind":"lintel" if i == 1 else "block","chain":"needle"})
	_layout.platforms = out
	return out

static func platforms() -> Array:
	return layout().platforms

static func platform(name: String) -> Dictionary:
	for p: Dictionary in platforms():
		if p.name == name: return p
	return {}

## The floating stones drawn worn and walked on clean boxes (as AqArt
## `floating_stones`), a clod hanging under the torn-up ones.
static func floating_stones(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.55,"FloatingStones")
	for p: Dictionary in platforms():
		var size: Vector3 = p.size
		var half := size*0.5
		var at: Vector3 = p.at
		var pose := Transform3D(Basis(Vector3.UP,float(p.yaw)),at-Vector3(0.0,half.y,0.0))
		b.lean = true
		b.solid(RuinKit._box(b,half,0.06 if p.kind == "lintel" else -1.0),pose,RuinKit._stone(b,1.04),false,true)
		b.lean = false
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
		if p.kind == "block":
			var deep := b.rng.randf_range(0.9,1.6)
			var clod := RuinKit._prism(5,0.12,minf(half.x,half.z)*0.95,-half.y-deep,-half.y+0.02,b.rng.randf()*TAU)
			b.solid(clod,pose,EARTH.lerp(ROCK,0.4)*b.rng.randf_range(0.85,1.05),false,true,[],-1,1.6,false)
			for i in range(3): AqArt._tuft(b,pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.8,half.y,b.rng.randf_range(-half.z,half.z)*0.8),0.3,4)
		for i in range(2): b.hang(pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.7,0.0,b.rng.randf_range(-half.z,half.z)*0.7),b.rng.randf_range(0.8,2.2),true,at.y-size.y)
	return b.finish()

## The chockstone wedged across the chimney's outer end at the fin's low
## top: a great fallen block, walked on a clean box.
static func chockstone(seed_value: int) -> Node3D:
	var l := layout()
	var chock: Dictionary = l.chock
	var axis: Vector2 = chock.axis
	var at: Vector3 = chock.at
	var b := Build.new(seed_value,0.5,"Chockstone")
	var half := Vector3(CHIMNEY*0.5+1.4,0.45,1.0)
	var pose := Transform3D(Basis(Vector3.UP,-axis.angle()),at-Vector3(0.0,half.y,0.0))
	b.lean = true
	b.solid(RuinKit._box(b,half,0.08),pose,RuinKit._stone(b,1.0),false,true,[],-1,1.3)
	b.lean = false
	RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
	for i in range(3): b.hang(pose*Vector3(b.rng.randf_range(-1.0,1.0),0.0,b.rng.randf_range(-0.6,0.6)),b.rng.randf_range(1.0,2.6),true,at.y-0.9)
	return b.finish()

# --- Ways up ----------------------------------------------------------------------------

## Points along a stair's middle line, foot to head (world, on its treads).
static func stair_way(stair: Dictionary) -> Array:
	var s: Dictionary = spire(stair.spire)
	var c: Vector2 = s.c
	var all: Array = []
	all.append_array(stair.steps)
	all.append_array(stair.landings)
	all.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.y) < float(q.y) or (float(p.y) == float(q.y) and (float(p.mid)-float(q.mid))*float(stair.way) < 0.0))
	var out: Array = []
	for st: Dictionary in all:
		var r := (float(st.r_in)+CUT_IN+float(st.r_out))*0.5
		if st.kind not in ["step","landing","","top","start"]: r = (float(st.r_in)+CUT_IN+float(st.r_out)-BRIDGE_OUT)*0.5
		var p := c+Vector2.from_angle(float(st.mid))*r
		out.append(Vector3(p.x,float(st.y),p.y))
	return out

## The landing on the hero's stair a bridge gives on to.
static func hero_landing(kind: String) -> Dictionary:
	for l: Dictionary in layout().stairs.hero.landings:
		if l.kind == kind: return l
	return {}

## The bridge called `name`.
static func bridge(name: String) -> Dictionary:
	for b: Dictionary in layout().bridges:
		if b.name == name: return b
	return {}
