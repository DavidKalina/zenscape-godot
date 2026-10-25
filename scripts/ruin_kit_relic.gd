extends RefCounted
## The ruin kit's relics (scripts/ruin_kit.gd, the same stone, wear and
## growth): pieces of colossal sacred works of which one part still stands.
## Pieces by id (RuinKit RELIC_PIECES, `piece`), each the kit's: a Node3D,
## its foot on y 0 round the origin, front toward +Z, "Mesh" and "Body".
##
## The broken nimbus (relic_nimbus): a colossal stone halo set on edge in
## the turf, the ring in the XY plane round (0, CY), its band NIMBUS_DEPTH
## deep in Z, broken at the crown into two horns, the low one on the left
## (-X), the high one on the right. Its climb, all on clean, true hulls:
##   - the trough: the ring's inner face at the bottom, a half-pipe (its
##     floor flat, its sides past SLIDE_AUTO), stepped into at the front;
##   - the inner rays: spoke stubs up the left inner wall, level tops one
##     SET_OFF apart, each set back (outward) from the one under it so the
##     next lip is ahead, not overhead; the lowest out of a pump's catch
##     from the trough's walkable sides (a surf's slide jump takes it);
##   - the spoke: a ray through the band at the equator, its top carried
##     round the band's front face, from the inner wall to the outer;
##   - the outer rays: brackets up the outer face's upper half, where it
##     leans back, each set in from the one under it, the last flush with
##     the outer top where its slope is RAY_FLUSH (walked, slowly);
##   - the rim: the outer top's front and back edges are lips, shimmied
##     where the curve is under SHIMMY_SLOPE (the crown's arcs);
##   - the horns: a level perch on each, the crown gap between them over a
##     pump's carry and under a twirled jump's, the high horn HORNS higher.
## Code over card (kit-k1-grab-climb.md): the outer face's lower half faces
## down and the inner's upper half is a ceiling, so the climb runs up the
## inside to the equator and the outside from there (the card's "rays on
## the inner edge" all the way up have no head room past the equator).

const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build

## The relics built by id (RuinKit RELIC_PIECES).
const PIECES := ["relic_nimbus"]

# --- The broken nimbus ---------------------------------------------------------

## The ring's outer radius and its band's radial depth (m): the inner
## face several KICK_GAPs across, so it reads as a wall along a run.
const NIMBUS_RADIUS := 9.0
const NIMBUS_BAND := 1.6
## The band's depth front to back (m): over TOP_ROOM (one walks its tops
## and the trough's floor).
const NIMBUS_DEPTH := 1.6
## The trough's floor over the turf (m): two steps up from the front.
const NIMBUS_FLOOR := 0.8
## The ring's faces: one stone (and one true facet) every this many degrees.
const NIMBUS_STEP := 5.0
## The crown gap between the horns' broken ends (m, level): over a pump's
## carry (3.0 m level), under a twirled run-up jump's at HORNS up (about
## 4.1 m to land, more to catch the lip).
const NIMBUS_GAP := 3.9
## The high horn's broken end, past the crown (x, m), and how much higher
## its perch stands than the low horn's (m): a long jump across the gap
## comes to the high horn's face with its hands under the lip's catch
## (GRAB_LOW), a twirled jump over it.
const NIMBUS_HIGH_END := 0.3
const NIMBUS_HORNS := 1.6
## The rays: the least a ray stands out of its face (STAND and a margin),
## how far each next one up is set back past the one under it (the body
## and a reach: the next lip ahead of him, not over his head), how far into
## the band it is set, its thickness at its tip and root, its half depth in
## Z (inside the band's).
const RAY_LEAST := RuinKit.STAND+0.2
const RAY_SET := 0.7
const RAY_SET_IN := 0.6
const RAY_THICK := Vector2(0.5,1.0)
const RAY_HALF_Z := 0.7
## The outer top's slope (deg) where the last outer ray stands flush with
## it: under SLIDE_AUTO (walked up, slowly, to the low horn).
const RAY_FLUSH := 40.0
## The lowest inner ray's top over the trough's floor (m): over a jump's
## catch from the trough's side under its tip, a pump's (the inner rungs
## between it and the spoke share the rise evenly, none over SET_OFF).
## Code over card: the trough's surf gives back under half its drop, so a
## slide jump up the far side can't reach a rung out of a pump's catch.
const RAY_LOWEST := 3.6
## The spoke's ledge round the band's front face: its depth past the face.
const SPOKE_FRONT := 0.9
## The front moulding of the rim band: radial width, how far it stands out.
const MOULDING := Vector2(0.32,0.1)
## Broken ray stubs on the right (no climb): their count and length (m).
const STUBS := 4
const STUB_LENGTH := Vector2(0.3,0.5)

## The ring's centre height and its radii.
static func nimbus_centre() -> float:
	return NIMBUS_FLOOR+NIMBUS_RADIUS-NIMBUS_BAND

## The outer top's height over x (on the circle; above the centre).
static func _outer_y(x: float) -> float:
	return nimbus_centre()+sqrt(maxf(0.0,NIMBUS_RADIUS*NIMBUS_RADIUS-x*x))

## The inner face's |x| at height y (on the circle).
static func _inner_x(y: float) -> float:
	var r := NIMBUS_RADIUS-NIMBUS_BAND
	var dy := y-nimbus_centre()
	return sqrt(maxf(0.0,r*r-dy*dy))

## The outer face's |x| at height y.
static func _outer_x(y: float) -> float:
	var dy := y-nimbus_centre()
	return sqrt(maxf(0.0,NIMBUS_RADIUS*NIMBUS_RADIUS-dy*dy))

## The nimbus's climb, worked out from the sizes (all on the left, -X):
## "inner" and "outer" rays [{top, tip, root}] as |x| (tip the end out in
## the air, root at its face), bottom up; "spoke" {top, inner, outer} (its
## tips' |x|); the horns' perches and ends; the crown gap.
static func nimbus_lines() -> Dictionary:
	var cy := nimbus_centre()
	var ri := NIMBUS_RADIUS-NIMBUS_BAND
	# The outer chain, top down: the last flush with the outer top where it
	# slopes RAY_FLUSH, each under it SET_OFF lower and standing out past
	# the one over it by RAY_SET (his feet outward of its lip, a reach off).
	var flush := deg_to_rad(RAY_FLUSH)
	var top := cy+NIMBUS_RADIUS*cos(flush)
	var outer: Array = []
	var tip := NIMBUS_RADIUS*sin(flush)
	tip = maxf(tip+RAY_LEAST,_outer_x(top-RuinKit.SET_OFF)-0.25)
	outer.append({"top":top,"tip":tip,"root":NIMBUS_RADIUS*sin(flush)})
	var y := top-RuinKit.SET_OFF
	while y > cy+0.2:
		var face := _outer_x(y)
		var t := maxf(face+RAY_LEAST,float(outer[0].tip)+RAY_SET)
		outer.push_front({"top":y,"tip":t,"root":face})
		y -= RuinKit.SET_OFF
	# The spoke: the lowest of the outer chain's rungs (just over the
	# equator), through the band and out of its inner face.
	var spoke_rung: Dictionary = outer.pop_front()
	var sy: float = spoke_rung.top
	# The inner chain under the spoke, bottom up: tips stepping out going
	# up (each RAY_SET past the one under it).
	var inner: Array = []
	var spoke_in := _inner_x(sy)-RAY_LEAST
	var lowest := NIMBUS_FLOOR+RAY_LOWEST
	var rungs := int(ceil((sy-lowest)/RuinKit.SET_OFF-0.01))
	var rise := (sy-lowest)/maxf(rungs,1)
	var over_tip := spoke_in
	for k in range(1,rungs+1):
		y = sy-rise*k
		var face := _inner_x(y)
		var t := minf(face-RAY_LEAST,over_tip-RAY_SET)
		inner.push_front({"top":y,"tip":t,"root":face})
		over_tip = t
	# The horns: the high's perch level from its broken end to a metre in
	# (its top cut there), the low's end NIMBUS_GAP left of the high's and
	# its perch HORNS under the high's, level back to where it meets the
	# outer top.
	var low_end := NIMBUS_HIGH_END-NIMBUS_GAP
	var high_perch := _outer_y(NIMBUS_HIGH_END+1.0)
	var low_perch := high_perch-NIMBUS_HORNS
	var low_start := -_outer_x(low_perch)
	return {"centre":cy,"inner_radius":ri,"inner":inner,"outer":outer,
		"spoke":{"top":sy,"inner":spoke_in,"outer":float(spoke_rung.tip),"in_face":_inner_x(sy),"out_face":_outer_x(sy)},
		"low_end":low_end,"low_start":low_start,"low_perch":low_perch,"high_end":NIMBUS_HIGH_END,"high_perch":high_perch,
		"gap":NIMBUS_GAP,"trough":NIMBUS_FLOOR}

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"relic_nimbus": return relic_nimbus(seed_value,weathered)
	return null

## The broken nimbus (see the file's head). `stubs`: broken ray stubs on
## the right (drawn and solid, too short and far apart to climb).
## Meta: "lines" (nimbus_lines), "opening" (the clear ring's least
## diameter, the rays in), "horns" {low: perch top middle, high: ...}.
static func relic_nimbus(seed_value: int, weathered := 0.0, stubs := STUBS) -> Node3D:
	var b := Build.new(seed_value,weathered,"BrokenNimbus")
	b.settle = 0.3
	b.ground = 0.0
	b.cull = true
	var L := nimbus_lines()
	var cy: float = L.centre
	var c := Vector3(0.0,cy,0.0)
	var ro := NIMBUS_RADIUS
	var ri: float = L.inner_radius
	var d := NIMBUS_DEPTH*0.5
	var low_end: float = L.low_end
	var high_end: float = L.high_end
	var low_perch: float = L.low_perch
	var high_perch: float = L.high_perch
	# Grime in the trough and under the rays (vertex alpha: the stone
	# shader's shelter), the band's inside low down darkest.
	b.shelter = func(mid: Vector3, n: Vector3) -> float:
		var r := Vector2(mid.x,mid.y-cy).length()
		if r > ri+0.15 or absf(mid.z) > d+0.05: return 0.0
		return clampf((cy-mid.y)/ri,0.0,1.0)*0.7*clampf(-n.y*0.5+0.6,0.0,1.0)
	# The band: a voussoir every NIMBUS_STEP degrees, in two courses (inner,
	# outer), drawn worn; under them one clean, true facet hull a step.
	var steps := int(round(360.0/NIMBUS_STEP))
	var da := TAU/steps
	var segs := 0
	for k in range(steps):
		var a0 := da*k
		var a1 := da*(k+1)
		var am := (a0+a1)*0.5
		var u := Vector3(sin(am),-cos(am),0.0)
		var t0 := Vector3(cos(a0),sin(a0),0.0)
		var t1 := Vector3(cos(a1),sin(a1),0.0)
		# Its points on the circle, for the gap and the ground.
		var p0 := c+Vector3(sin(a0),-cos(a0),0.0)*ro
		var p1 := c+Vector3(sin(a1),-cos(a1),0.0)*ro
		if maxf(maxf(p0.y,p1.y),cy-ri) < -0.4: continue
		var cut: Array[Plane] = []
		var upper := am > PI*0.5 and am < PI*1.5
		if upper and am <= PI:
			cut.append(Plane(Vector3.LEFT,-high_end))
			cut.append(Plane(Vector3.UP,high_perch))
		elif upper:
			cut.append(Plane(Vector3.RIGHT,low_end))
			cut.append(Plane(Vector3.UP,low_perch))
		var chord := cos(da*0.5)
		var base: Array[Plane] = [Plane(-t0,-t0.dot(c)),Plane(t1,t1.dot(c)),
			Plane(-u,-(u.dot(c)+ri*chord)),Plane(u,u.dot(c)+ro),Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)]
		var whole := base.duplicate()
		whole.append_array(cut)
		if Geometry3D.compute_convex_mesh_points(whole).size() < 4: continue
		segs += 1
		RuinKit._walk_hull(b,Transform3D.IDENTITY,whole)
		# Drawn: two courses, the joint between them part way across.
		var split := ri+(ro-ri)*b.rng.randf_range(0.42,0.58)
		for course in range(2):
			var pl: Array[Plane] = [Plane(-t0,-t0.dot(c)+0.006),Plane(t1,t1.dot(c)-0.006),Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)]
			if course == 0:
				pl.append(Plane(-u,-(u.dot(c)+ri*chord)))
				pl.append(Plane(u,u.dot(c)+split-0.006))
			else:
				pl.append(Plane(-u,-(u.dot(c)+split+0.006)))
				pl.append(Plane(u,u.dot(c)+ro))
			pl.append_array(cut)
			if Geometry3D.compute_convex_mesh_points(pl).size() < 4: continue
			b.solid(pl,RuinKit._jiggle(b,Transform3D.IDENTITY,0.04),RuinKit._stone(b,1.02),false,true,[],-1,0.7)
		# The rim band's moulding on both faces' outer edge (drawn only).
		for s: float in [-1.0,1.0]:
			var mo: Array[Plane] = [Plane(-t0,-t0.dot(c)+0.004),Plane(t1,t1.dot(c)-0.004),
				Plane(-u,-(u.dot(c)+ro-MOULDING.x)),Plane(u,u.dot(c)+ro+0.02)]
			mo.append(Plane(Vector3(0,0,s),d+MOULDING.y))
			mo.append(Plane(Vector3(0,0,-s),-(d-0.05)))
			# Its outer arris chamfered: a roll moulding's profile.
			var ch := (u+Vector3(0,0,s)).normalized()
			mo.append(Plane(ch,ch.dot(c+u*ro+Vector3(0,0,s*d))+0.02))
			mo.append_array(cut)
			if Geometry3D.compute_convex_mesh_points(mo).size() < 4: continue
			b.solid(mo,Transform3D.IDENTITY,RuinKit._stone(b,1.08),false,true,[],-1,0.5)
	# The rays, the spoke and the stubs: clean hulls, drawn worn over them.
	var rays: Array = []
	for r: Dictionary in L.inner:
		_ray(b,-1.0,float(r.top),float(r.tip),float(r.root)+RAY_SET_IN,-RAY_HALF_Z,RAY_HALF_Z)
		rays.append(r)
	for r: Dictionary in L.outer:
		_ray(b,-1.0,float(r.top),float(r.tip),float(r.root)-RAY_SET_IN,-RAY_HALF_Z,RAY_HALF_Z)
	var sp: Dictionary = L.spoke
	var sy: float = sp.top
	_ray(b,-1.0,sy,float(sp.inner),float(sp.in_face)+NIMBUS_BAND*0.5,-RAY_HALF_Z,d+SPOKE_FRONT)
	_ray(b,-1.0,sy,float(sp.outer),float(sp.out_face)-NIMBUS_BAND*0.5,-RAY_HALF_Z,d+SPOKE_FRONT)
	# Round the band's front face: the spoke's ledge (level, its top the
	# spoke's).
	var strap: Array[Plane] = [Plane(Vector3.LEFT,float(sp.out_face)+0.05),Plane(Vector3.RIGHT,-(float(sp.in_face)-0.05)),
		Plane(Vector3.UP,sy),Plane(Vector3.DOWN,-(sy-RAY_THICK.x)),Plane(Vector3.BACK,d+SPOKE_FRONT),Plane(Vector3.FORWARD,-(d-0.1))]
	RuinKit._walk_hull(b,Transform3D.IDENTITY,strap)
	b.solid(strap,Transform3D.IDENTITY,RuinKit._stone(b,0.98),false,true,[],-1,0.6)
	# The right's broken stubs: inside under the equator and outside over
	# it, low (the high horn stays out of any chain's reach).
	for i in range(stubs):
		var inside := i%2 == 0
		var yy := cy-2.5+b.rng.randf_range(0.0,2.0) if inside else cy+b.rng.randf_range(0.3,2.0)
		var face := _inner_x(yy) if inside else _outer_x(yy)
		var stub := b.rng.randf_range(STUB_LENGTH.x,STUB_LENGTH.y)
		if inside: _ray(b,1.0,yy,face-stub,face+RAY_SET_IN,-RAY_HALF_Z*0.8,RAY_HALF_Z*0.8)
		else: _ray(b,1.0,yy,face+stub,face-RAY_SET_IN,-RAY_HALF_Z*0.8,RAY_HALF_Z*0.8)
	# The trough's step at the front: two fallen blocks, true tops.
	var step := NIMBUS_FLOOR*0.5
	var steps_at := [[Vector3(0.0,step,d+0.55),Vector3(0.8,step,0.55)]]
	for s: Array in steps_at:
		var at: Vector3 = s[0]
		var half: Vector3 = s[1]
		var box: Array[Plane] = [Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,step),Plane(Vector3.DOWN,0.3),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)]
		RuinKit._walk_hull(b,Transform3D(Basis.IDENTITY,Vector3(at.x,0.0,at.z)),box)
		b.solid(RuinKit._box(b,Vector3(half.x,(step+0.3)*0.5,half.z)),Transform3D(Basis.IDENTITY,Vector3(at.x,(step-0.3)*0.5,at.z)),RuinKit._stone(b,0.9),false,true,[],-1,1.2)
	# Growth: moss on the perches and the trough, ivy off the rays' tips and
	# the horns; drifts at the foot, rubble with wear.
	for r: Dictionary in rays:
		if b.rng.randf() < 0.3+0.5*weathered:
			b.hang(Vector3(-float(r.tip)-0.15,0.0,b.rng.randf_range(-0.4,0.4)),b.rng.randf_range(0.4,1.2)*(0.5+weathered),true,float(r.top)-RAY_THICK.x)
	for i in range(int(1+weathered*4.0)):
		b.hang(Vector3(low_end-0.2-b.rng.randf()*1.5,0.0,b.rng.randf_range(-d,d)),b.rng.randf_range(0.6,1.8)*(0.5+weathered),true,low_perch-1.0)
	RuinKit._drift(b,Vector3(-ro*0.55,0.0,d+0.9),1.2,int(weathered*4.0))
	RuinKit._drift(b,Vector3(ro*0.5,0.0,-d-0.9),1.0,int(weathered*3.0))
	RuinKit._rubble(b,ro*0.7,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	var node := b.finish()
	# The clear ring: the least distance from the centre to a ray's tip.
	var clear := ri
	for r: Dictionary in L.inner:
		clear = minf(clear,Vector2(float(r.tip),float(r.top)-cy).length())
		clear = minf(clear,Vector2(float(r.tip),float(r.top)-RAY_THICK.x-cy).length())
	clear = minf(clear,Vector2(float(sp.inner),sy-cy).length())
	node.set_meta("lines",L)
	node.set_meta("opening",clear*2.0)
	node.set_meta("segments",segs)
	node.set_meta("horns",{"low":Vector3((low_end+float(L.low_start))*0.5,low_perch,0.0),"high":Vector3(high_end+0.5,high_perch,0.0)})
	return node

## One ray on side `side` (-1 left, 1 right): its level top at `top`, from
## its tip at |x| `tip` back to `root` |x| (into its face), Z from `z0` to
## `z1` (in from the inner face or out from the outer: the tip is the
## end in the air either way). Its underside rakes from RAY_THICK.x at
## the tip to .y at the root. A clean hull under it, drawn worn and broken
## at its tip.
static func _ray(b: Build, side: float, top: float, tip: float, root: float, z0: float, z1: float) -> void:
	var tip_x := tip*side
	var root_x := root*side
	var out := signf(tip_x-root_x)
	var under0 := Vector3(tip_x,top-RAY_THICK.x,0.0)
	var under1 := Vector3(root_x,top-RAY_THICK.y,0.0)
	var along := (under0-under1).normalized()
	var n := Vector3(along.y,-along.x,0.0)
	if n.y > 0.0: n = -n
	var planes: Array[Plane] = [Plane(Vector3(out,0,0),out*tip_x),Plane(Vector3(-out,0,0),-out*root_x),
		Plane(Vector3.UP,top),Plane(n,n.dot(under0)),Plane(Vector3.BACK,z1),Plane(Vector3.FORWARD,-z0)]
	RuinKit._walk_hull(b,Transform3D.IDENTITY,planes)
	# Drawn: the tip snapped off ragged (a cut off its lower end, not its
	# top: the ledge's lip stays true), its sides a little narrower.
	var drawn := planes.duplicate()
	drawn[4] = Plane(Vector3.BACK,z1-0.02)
	drawn[5] = Plane(Vector3.FORWARD,-z0-0.02)
	var extra: Array[Plane] = []
	var m := Vector3(out*b.rng.randf_range(0.6,1.0),-b.rng.randf_range(0.5,1.0),b.rng.randf_range(-0.4,0.4)).normalized()
	extra.append(Plane(m,m.dot(Vector3(tip_x-out*0.12,top-RAY_THICK.x*0.55,0.0))))
	b.solid(drawn,Transform3D.IDENTITY,RuinKit._stone(b,1.05),false,true,extra,-1,0.6)
