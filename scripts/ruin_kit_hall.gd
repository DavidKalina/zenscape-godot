extends RefCounted
## The ruin kit's colossus halls (scripts/ruin_kit.gd: the same stone, wear
## and growth): long, dim hypostyle halls after the shrine halls of Shadow
## of the Colossus, cut in the kit's facets, built to be flown through:
## a nave you weave down, slaloming between the columns, diving under low
## tie-beams and hopping over high ones, under beams fallen across it, out
## through a gap in the roof and back in, and threading a knife-edge slit
## for a treat. On foot: fallen beams are ramps up onto the ties, the ties
## and beams are walked, a stepped buttress outside climbs to the roof, and
## the roof is a route of its own.
##
## The hall runs along X: a bay is BAY long, its bay line (the columns, the
## roof beam, perhaps a tie) at its x 0, so bays set BAY apart tile; `hall`
## lays a whole one out from a plan it draws from the seed. Across it (Z):
## two outer rows of massive drum columns at +-ROW_Z (their drums carved in
## a band of pointed niches and a ring of roundels), side walls at
## +-WALL_Z with tall lancets, and inner columns at some bay lines, in
## {-INNER_Z, 0, INNER_Z}, staggered from line to line and now and then two
## together, narrowing the middle. A roof of heavy slabs lies on the beams,
## gapped. The ends are open and bright; inside it is dim, the light coming
## down in beams through the gaps and the lancets.
##
## The generous line: between the inner columns at +INNER_Z and the outer
## row at +ROW_Z there is always a LANE (z LANE.x to LANE.y, 4 m wide, under
## every tie) clear from end to end; everything tighter is optional, and
## the tightest lines (the knife-edge slits through the screens) lead
## somewhere worth it.
##
## Contract for a layout pass (the landforms to come, dense with halls and
## aqueducts woven through terrain):
## - `ground`: an optional Callable(x, z) -> y in the hall's frame. Columns
##   and walls stand on it and reach FOUNDATION below it; paving and rubble
##   lie on it. A hall run into a hillside is buried there: its columns and
##   walls are cut off where the ground stands over them (nothing floats).
##   The roof stays level (COLUMN_H over y 0).
## - Metadata on the root (`hall`, and a single `bay`), in its frame:
##   "bounds" AABB; "feet" Array of Vector3 (each column and wall foot,
##   its y below the ground there); "walk" Array of {from, to, width}
##   (the roof's ridge, the ties' tops, the nave floor); "corridors" Array
##   of AABB to keep terrain and props out of (the lane, end to end, or as
##   far as the ground lets it); "ends" Array of {at, heading, height,
##   open} (the nave's two mouths: where a hall or an aqueduct chains on);
##   "weave" Dictionary of what there is to weave (low and high ties,
##   fallen beams, roof gaps, slits, narrows, as positions or boxes).
## - Cost: a built hall is merged into one mesh and one body
##   (RuinKit `merge`); RuinKit `set_detail` thins its growth and scatter.
##   ./run-ruin-kit.command  (F3 frames the hall, G flies it)

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build

const PIECES := RuinKit.HALL_PIECES

# --- Scale -------------------------------------------------------------------

## A bay's length along the nave (m): bay lines BAY apart.
const BAY := 8.0
## Across the hall: the outer column rows, the inner columns' offsets, the
## side walls' middles and their thickness.
const ROW_Z := 9.4
const INNER_Z := 2.6
const WALL_Z := 12.4
const WALL_THICK := 1.2
## A column: its drums' apothem (16 sides, 2.4 m across, four times the
## clustered pier's core), its height from y 0 to the abacus's top (the
## beams' soffit), and how far its foundation reaches below the ground.
const COLUMN_R := 1.2
const COLUMN_H := 10.0
const FOUNDATION := 1.2
## The base: the plinth's height (a step) and half width; the moulded base
## whole.
const PLINTH := Vector2(0.42,1.65)
const BASE_H := 1.16
## The capital's height and the abacus's half width.
const CAPITAL_H := 1.0
const ABACUS := 1.7
## The carved bands' heights.
const NICHE_BAND := 1.5
const ROUNDEL_BAND := 0.95
## The roof beams and architraves: depth and half width (walked: TOP_ROOM
## and more).
const BEAM := Vector2(1.1,0.85)
## The roof slabs' thickness and the roof's top.
const SLAB := 0.5
const ROOF_TOP := COLUMN_H+1.1+0.5
## The ties across the nave: a low one's soffit (dived under: the lane's
## top LANE_Y.y and more under it; flown over: room to the roof beams) and
## a high one's (hopped over: 2 m and more over its top), their depth.
const TIE_LOW := 4.0
const TIE_HIGH := 6.0
const TIE_DEPTH := 0.9
## The generous line: its z range (between the inner columns at +INNER_Z
## and the outer row) and the heights it is clear between.
const LANE := Vector2(4.0,8.0)
const LANE_Y := Vector2(1.0,3.6)
## The paving: thickness (stepped onto) and rough size.
const PAVING := Vector2(0.18,1.8)
## A knife-edge slit through a screen wall: clear width (about the plane's
## height on its wingtip, ~1 m, and under its span 1.4: a level plane does
## not pass), sill, clear height to the head's springing (the span on edge
## and a margin).
const KNIFE := Vector3(1.15,1.0,3.3)
## A side wall's lancet: clear width, sill, height to the springing, the
## arc's radius as a share of the width.
const LANCET := Vector4(1.8,2.6,4.6,1.0)
## A fallen beam's slope (walked up onto the low tie's top).
const RAMP := deg_to_rad(30.0)
## The stepped buttress outside: each tread SET_OFF over the last, this deep.
const TREAD := 0.62
## How far a hall's stones have moved out of true, weathered, as a share of
## the abbey's (heavy walls and columns stay in line).
const SETTLE := 0.4

# --- The pieces -----------------------------------------------------------------

static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"hall_column": return column(seed_value,weathered)
		"hall_beam": return beam(seed_value,weathered)
		"hall_slab": return slabs(seed_value,weathered)
		"hall_bay": return bay(seed_value,weathered)
	return null

## 1. A colossus column: a deep moulded base on its foundation, the shaft
## in drums (plain drums, the band of pointed niches, the ring of
## roundels), the capital's necking, echinus and abacus. Weathered, snapped
## partway, its upper drums and capital lying round its foot.
static func column(seed_value: int, weathered := 0.0, ground := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallColumn")
	b.settle = SETTLE
	b.terrain = ground
	var broken := INF
	if weathered > 0.2: broken = lerpf(COLUMN_H-2.0,3.2,clampf(weathered*b.rng.randf_range(0.75,1.1),0.0,1.0))
	var foot := b.floor_at(0.0,0.0)
	var lost := _column(b,Transform3D(Basis.IDENTITY,Vector3(0.0,foot,0.0)),COLUMN_H-foot,broken)
	if broken < INF:
		var x := 1.8
		var yaw := b.rng.randf_range(-0.3,0.3)
		for drum: Array in lost:
			var lie := Basis(Vector3.UP,yaw)*Basis(Vector3.BACK,-PI*0.5)*Basis(Vector3.UP,b.rng.randf()*TAU)
			var at := Basis(Vector3.UP,yaw)*Vector3(x,0.0,1.2)
			at.y = b.floor_at(at.x,at.z)+COLUMN_R*0.96
			_drum(b,Transform3D(lie,at),str(drum[0]),float(drum[1]),RuinKit._break(b,float(drum[1]),COLUMN_R,0.2,0.0) if b.rng.randf() < 0.4 else [])
			x += float(drum[1])+b.rng.randf_range(0.1,0.4)
		# Upside down on its abacus, a little askew, as a capital comes to rest.
		_capital(b,Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,PI-b.rng.randf_range(0.08,0.2)),Vector3(-2.4,b.floor_at(-2.4,2.0)+0.92,2.0)))
		RuinKit._drift(b,Vector3(-1.5,0.0,-1.2),1.3,3+int(weathered*4.0))
	_feet(b,Vector3.ZERO,PLINTH.y+0.3,int(2+weathered*6.0))
	RuinKit._rubble(b,2.4,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	b.root.set_meta("feet",[Vector3(0.0,foot-(FOUNDATION if b.terrain.is_valid() else 0.0),0.0)])
	return _finish(b)

## 2. A roof beam as the hall lays one from column to column: two fasciae
## under a crown moulding, a row of roundels along its faces, here resting
## on two abacus stones. Weathered, cracked through, one end dropped off its
## bearing to the ground.
static func beam(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallBeam")
	b.settle = SETTLE
	var length := BAY*0.85
	var bearing := 0.4
	for s: float in [-1.0,1.0]:
		b.solid(RuinKit._box(b,Vector3(ABACUS*0.7,bearing*0.5,ABACUS*0.7)),RuinKit._settle(b,Vector3(s*(length*0.5-0.9),bearing*0.5,0.0),0.4),RuinKit._stone(b,1.02))
	if weathered > 0.3:
		var at := b.rng.randf_range(-0.6,0.6)
		var cut := Vector3(1.0,0.0,b.rng.randf_range(-0.2,0.2)).normalized()
		_beam(b,Transform3D(Basis.IDENTITY,Vector3(0.0,bearing,0.0)),length,[Plane(cut,at-0.03)])
		var drop := Transform3D(Basis(Vector3.BACK,-atan2(bearing,length*0.5))*Basis(Vector3.UP,b.rng.randf_range(-0.12,0.12)),Vector3(0.12,0.0,b.rng.randf_range(-0.2,0.2)))
		_beam(b,Transform3D(drop.basis,Vector3(0.0,bearing,0.0)+drop.origin),length,[Plane(-cut,-at-0.03)])
		RuinKit._drift(b,Vector3(at,0.0,BEAM.y+0.9),1.0,int(weathered*5.0))
	else:
		_beam(b,Transform3D(Basis.IDENTITY,Vector3(0.0,bearing,0.0)),length)
	_feet(b,Vector3(0.0,0.0,BEAM.y+0.4),length*0.5,int(1+weathered*5.0))
	RuinKit._rubble(b,length*0.5,int(round(weathered*b.rng.randf_range(2.0,5.0))))
	return _finish(b)

## 3. Roof slabs: a panel of the heavy slabs as the roof lays them, here on
## two sleeper beams, cracked even so. Weathered, a slab gone, another
## broken and its half tipped up against the next.
static func slabs(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallSlabs")
	b.settle = SETTLE
	var sleeper := 0.36
	for s: float in [-1.0,1.0]:
		b.solid(RuinKit._box(b,Vector3(BAY*0.36,sleeper*0.5,0.42)),RuinKit._settle(b,Vector3(0.0,sleeper*0.5,s*1.6),0.4),RuinKit._stone(b,0.92))
	var strips := [-2.4,-0.8,0.8,2.4]
	var gone: Array = [0] if weathered > 0.5 else []
	for i in range(strips.size()-1):
		if i in gone: continue
		_slab(b,-BAY*0.36,BAY*0.36,float(strips[i]),float(strips[i+1]),sleeper,weathered > 0.4 and i == 2)
	_feet(b,Vector3(0.0,0.0,2.8),BAY*0.3,int(1+weathered*5.0))
	RuinKit._rubble(b,3.4,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return _finish(b)

## 4. A hall bay: its bay line at x 0 (the outer columns, the inner ones
## the plan asks for, the roof beam across, a tie if asked) and its length
## to x BAY (the architraves along the rows, the roof slabs, the side walls
## with their lancets, the paving, a screen with its slit, a fallen beam, a
## stepped buttress outside); `plan` (from `hall`; empty, a bay showing a
## little of everything) and `ground` as for `hall`.
##   plan: inner (Array of z), tie ("", "low", "high"), gaps (Array of the
##   nave's roof strips 1..4 left open), fallen (bool), screen (bool, a wall
##   with a knife-edge slit between the left outer column and the inner
##   column at -INNER_Z), buttress ("", "plain", "stair"), lancets
##   (Vector2: odds, left and right), last (bool: the closing bay line at x
##   BAY too).
static func bay(seed_value: int, weathered := 0.0, plan := {}, ground := Callable()) -> Node3D:
	if plan.is_empty():
		plan = {"inner":[-INNER_Z],"tie":"low","gaps":[2],"fallen":weathered > 0.3,"screen":true,"buttress":"stair","lancets":Vector2(1.0,1.0),"last":true}
	var b := Build.new(seed_value,weathered,"HallBay")
	b.settle = SETTLE
	b.terrain = ground
	var weave := {"low_ties":[],"high_ties":[],"fallen":[],"gaps":[],"slits":[],"narrows":[]}
	var feet: Array = []
	# The bay lines: x 0, and x BAY closing the last bay.
	var lines: Array = [0.0]
	if bool(plan.get("last",false)): lines.append(BAY)
	for x: float in lines:
		var inner: Array = plan.get("inner",[]) if x == 0.0 else []
		for z: float in [-ROW_Z,ROW_Z]+inner:
			var foot := b.floor_at(x,z)
			_column(b,Transform3D(Basis.IDENTITY,Vector3(x,foot,z)),COLUMN_H-foot)
			feet.append(Vector3(x,foot-(FOUNDATION if b.terrain.is_valid() else 0.0),z))
		# The roof beam across, wall to wall, in three stones resting on the
		# outer columns (and the inner ones, which it passes over).
		var turn := Basis(Vector3.UP,PI*0.5)
		for span: Vector2 in [Vector2(-WALL_Z+0.2,-ROW_Z),Vector2(-ROW_Z,ROW_Z),Vector2(ROW_Z,WALL_Z-0.2)]:
			_beam(b,Transform3D(turn,Vector3(x,COLUMN_H,(span.x+span.y)*0.5)),absf(span.y-span.x))
	if inner_pair(plan): weave.narrows.append(Vector3(0.0,0.0,0.0))
	# The architraves along the rows.
	for z: float in [-ROW_Z,ROW_Z]:
		_beam(b,Transform3D(Basis.IDENTITY,Vector3(BAY*0.5,COLUMN_H,z)),BAY-0.04)
	# The tie across the nave at the bay line.
	var tie: String = plan.get("tie","")
	if tie != "":
		var soffit := TIE_LOW if tie == "low" else TIE_HIGH
		_beam(b,Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(0.0,soffit,0.0)),ROW_Z*2.0,[],TIE_DEPTH)
		(weave.low_ties if tie == "low" else weave.high_ties).append(Vector3(0.0,soffit,0.0))
	# The roof: six strips across (the aisles' and four over the nave), the
	# gaps the plan asks for left open (big enough to fly out and back in).
	var edges := [-WALL_Z-0.5,-ROW_Z,-ROW_Z*0.5,0.0,ROW_Z*0.5,ROW_Z,WALL_Z+0.5]
	var gaps: Array = plan.get("gaps",[])
	var soffit := COLUMN_H+BEAM.x
	for i in range(edges.size()-1):
		if i in gaps:
			# The opening: clear of the roof beams at the bay lines and of the
			# architraves along the rows.
			var z0: float = float(edges[i])+(BEAM.y+0.18 if absf(float(edges[i])) > ROW_Z-0.1 else 0.12)
			var z1: float = float(edges[i+1])-(BEAM.y+0.18 if absf(float(edges[i+1])) > ROW_Z-0.1 else 0.12)
			weave.gaps.append(AABB(Vector3(BEAM.y+0.25,soffit-0.2,z0),Vector3(BAY-2.0*BEAM.y-0.5,SLAB+0.6,z1-z0)))
			continue
		_slab(b,0.0,BAY,float(edges[i]),float(edges[i+1]),soffit,false)
	# The side walls, a lancet in each at the plan's odds.
	var lancets: Vector2 = plan.get("lancets",Vector2(0.7,0.7))
	for s: float in [-1.0,1.0]:
		var odds := lancets.x if s < 0.0 else lancets.y
		var opening := LANCET if b.rng.randf() < odds else Vector4.ZERO
		feet.append(_wall(b,Transform3D(Basis.IDENTITY,Vector3(BAY*0.5,0.0,s*WALL_Z)),BAY*0.5-0.02,soffit-0.02,opening,soffit-3.0))
	# The screen: a wall across the left of the nave, the knife-edge slit
	# through it (an optional tight line; the lane stays open).
	if bool(plan.get("screen",false)):
		var z := -(ROW_Z+INNER_Z)*0.5
		var span := (ROW_Z-INNER_Z)*0.5-COLUMN_R+0.06
		var high := (TIE_LOW if tie == "low" else (TIE_HIGH if tie == "high" else 7.0))-0.02
		var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(0.0,0.0,z))
		feet.append(_wall(b,pose,span,high,Vector4(KNIFE.x,KNIFE.y,KNIFE.z,0.9),high-1.0,0.9))
		weave.slits.append(Vector3(0.0,b.floor_at(0.0,z)+KNIFE.y+KNIFE.z*0.5,z))
	# A beam fallen across the nave, its head on the low tie's top, its foot
	# on the floor toward the middle: a ramp up onto the tie (RAMP).
	if bool(plan.get("fallen",false)) and tie == "low":
		var head := Vector3(0.55,TIE_LOW+TIE_DEPTH+0.02,-7.0)
		var rise := head.y-b.floor_at(5.0,-1.6)-BEAM.x*0.8
		var run := rise/tan(RAMP)
		var way := Vector3(0.66,0.0,0.75).normalized()
		var foot := head+way*run+Vector3.DOWN*rise
		foot.z = minf(foot.z,LANE.x-BEAM.y-1.0)
		_beam(b,_sag(head-Vector3(0.0,BEAM.x,0.0),foot-Vector3(0.0,BEAM.x,0.0)),head.distance_to(foot)+0.6,RuinKit._break(b,BEAM.x,1.0,0.3,0.0))
		weave.fallen.append([head,foot])
		RuinKit._drift(b,Vector3(foot.x,0.0,foot.z),1.2,3+int(b.weathered*4.0))
	# The stepped buttress outside the left wall at the bay line: plain, or a
	# stair of treads up to the roof (the way up on foot).
	var buttress: String = plan.get("buttress","")
	# Plain buttresses on the right wall too, every other line, so the long
	# walls read in bays from outside.
	if plan.get("right_buttress",false):
		var foot := b.floor_at(0.0,WALL_Z+WALL_THICK*0.5+1.0)
		var sunk := 0.3 if b.terrain.is_valid() else 0.0
		var stages := _plain_stages(foot-sunk)
		if not stages.is_empty(): RuinKit._buttress(b,Transform3D(Basis.IDENTITY,Vector3(0.0,foot-sunk,WALL_Z+WALL_THICK*0.5-0.05)),stages,1.5,b.weathered > 0.5 and b.rng.randf() < 0.5,true)
		feet.append(Vector3(0.0,foot-sunk,WALL_Z+1.4))
	if buttress != "":
		var foot := b.floor_at(0.0,-WALL_Z-WALL_THICK*0.5-1.0)
		var sunk := 0.3 if b.terrain.is_valid() else 0.0
		var pose := Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,foot-sunk,-WALL_Z-WALL_THICK*0.5+0.05))
		var stages: Array = []
		if buttress == "stair":
			var count := int(ceil((ROOF_TOP-0.4-foot)/RuinKit.SET_OFF))
			for k in range(count):
				stages.append([minf(RuinKit.SET_OFF*(k+1)+0.3,ROOF_TOP-0.3-foot+0.3),TREAD*(count-k)+0.5])
		else:
			stages = _plain_stages(foot-sunk)
		if not stages.is_empty(): RuinKit._buttress(b,pose,stages,1.5,b.weathered > 0.5 and b.rng.randf() < 0.5,buttress == "plain")
		feet.append(Vector3(0.0,foot-sunk,-WALL_Z-1.4))
	_paving(b,plan)
	for i in range(int(b.weathered*5.0)):
		b.hang(Vector3(b.rng.randf_range(0.5,BAY-0.5),0.0,b.rng.randf_range(-ROW_Z,ROW_Z)),b.rng.randf_range(0.8,2.6)*b.weathered,true)
	# Rubble in drifts at the left columns' feet, out of the lane.
	if b.weathered > 0.2:
		RuinKit._drift(b,Vector3(b.rng.randf_range(1.0,BAY-1.0),0.0,-ROW_Z+2.0),1.4,int(b.weathered*6.0))
	var root := _finish(b)
	root.set_meta("feet",feet)
	root.set_meta("weave",weave)
	root.set_meta("ends",[{"at":Vector3(0.0,b.floor_at(0.0,0.0),0.0),"heading":Vector3.LEFT,"height":b.floor_at(0.0,0.0),"open":true},{"at":Vector3(BAY,b.floor_at(BAY,0.0),0.0),"heading":Vector3.RIGHT,"height":b.floor_at(BAY,0.0),"open":true}])
	root.set_meta("corridors",[_lane(0.0,BAY,ground)])
	root.set_meta("walk",[{"from":Vector3(0.0,ROOF_TOP,0.0),"to":Vector3(BAY,ROOF_TOP,0.0),"width":WALL_Z*2.0}])
	if not weave.slits.is_empty(): root.set_meta("slit",weave.slits[0])
	return root

## A plain buttress's stages [top, depth] over its foot at `base`: set-offs
## at the same heights over y 0 wherever it stands, those the ground has
## buried left out, so on a slope it never stands over the roof.
static func _plain_stages(base: float) -> Array:
	var out: Array = []
	for st: Array in [[3.4,2.4],[6.8,1.6],[9.6,0.9]]:
		if float(st[0])-base > 0.6: out.append([float(st[0])-base,st[1]])
	return out

## Whether a plan stands two inner columns together at its bay line.
static func inner_pair(plan: Dictionary) -> bool:
	return (plan.get("inner",[]) as Array).size() >= 2

## A long hall of `bays` bays along +X from x 0 (BAY each), its plan drawn
## from the seed: inner columns staggered from line to line, now and then
## two together; low and high ties at bay lines, both kinds at least twice;
## roof gaps every few bays; a beam or two fallen across the nave onto a
## low tie; a couple of screens with knife-edge slits; lancets in the walls;
## a stepped buttress outside up to the roof near each end. The first and
## last lines are kept clear (the mouths). `ground` as in the header; the
## hall's bays are merged into one mesh and body unless `merged` is off.
static func hall(seed_value: int, weathered := 0.6, bays := 12, ground := Callable(), merged := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Hall"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"long hall"])
	var plans := plan(rng,weathered,bays)
	var weave := {"low_ties":[],"high_ties":[],"fallen":[],"gaps":[],"slits":[],"narrows":[]}
	var feet: Array = []
	for i in range(bays):
		var x0 := BAY*i
		var shifted := Callable()
		if ground.is_valid(): shifted = func(x: float, z: float) -> float: return float(ground.call(x+x0,z))
		var node := bay(seed_value*31+i,clampf(weathered+rng.randf_range(-0.12,0.12),0.0,1.0),plans[i],shifted)
		node.name = "Bay%d" % i
		node.position.x = x0
		root.add_child(node)
		var offset := Vector3(x0,0.0,0.0)
		for p: Vector3 in node.get_meta("feet"): feet.append(p+offset)
		var w: Dictionary = node.get_meta("weave")
		for key: String in weave:
			for item: Variant in w[key]:
				if item is Vector3: weave[key].append(item+offset)
				elif item is AABB: weave[key].append(AABB((item as AABB).position+offset,(item as AABB).size))
				else: weave[key].append([(item[0] as Vector3)+offset,(item[1] as Vector3)+offset])
	var length := BAY*bays
	var floor0 := float(ground.call(0.0,0.0)) if ground.is_valid() else 0.0
	var floor1 := float(ground.call(length,0.0)) if ground.is_valid() else 0.0
	var lane := _lane(0.0,length,ground)
	root.set_meta("feet",feet)
	root.set_meta("weave",weave)
	root.set_meta("plans",plans)
	root.set_meta("length",length)
	root.set_meta("corridors",[lane])
	# A mouth is open while the lane reaches it (the ground has not buried it).
	root.set_meta("ends",[{"at":Vector3(0.0,floor0,0.0),"heading":Vector3.LEFT,"height":floor0,"open":lane.position.x < 0.5},{"at":Vector3(length,floor1,0.0),"heading":Vector3.RIGHT,"height":floor1,"open":lane.end.x > length-0.5}])
	root.set_meta("walk",[{"from":Vector3(0.0,ROOF_TOP,0.0),"to":Vector3(length,ROOF_TOP,0.0),"width":WALL_Z*2.0},{"from":Vector3(0.0,floor0,LANE.x+2.0),"to":Vector3(length,floor1,LANE.x+2.0),"width":LANE.y-LANE.x}])
	if not (weave.slits as Array).is_empty(): root.set_meta("slit",weave.slits[0])
	if merged: RuinKit.merge(root)
	root.set_meta("bounds",_bounds(root))
	return root

## The plans for `bays` bays (see `bay`), drawn from `rng`.
static func plan(rng: RandomNumberGenerator, weathered: float, bays: int) -> Array:
	var plans: Array = []
	var choices := [[-INNER_Z],[INNER_Z],[0.0],[-INNER_Z,INNER_Z],[]]
	var last_inner := -1
	for i in range(bays):
		var p := {"inner":[],"tie":"","gaps":[],"fallen":false,"screen":false,"buttress":"","right_buttress":false,"lancets":Vector2(0.75,0.75),"last":i == bays-1}
		if i > 0:
			var pick := rng.randi_range(0,choices.size()-1)
			if pick == last_inner: pick = (pick+1+rng.randi_range(0,2))%choices.size()
			last_inner = pick
			p.inner = choices[pick].duplicate()
		var roll := rng.randf()
		if i > 0: p.tie = "low" if roll < 0.32 else ("high" if roll < 0.62 else "")
		if i > 0 and i < bays-1 and rng.randf() < 0.35:
			var strip := rng.randi_range(1,4)
			p.gaps = [strip] if rng.randf() < 0.6 else [strip,clampi(strip+(1 if strip < 4 else -1),1,4)]
		if i%2 == 0: p.buttress = "plain"
		p.right_buttress = i%2 == 0
		plans.append(p)
	if bays >= 4:
		# Both kinds of tie at least twice, a fallen beam or two, a couple of
		# screens, a stair up near each end, a gap or two in the roof.
		for kind: String in ["low","high"]:
			var have := plans.filter(func(p: Dictionary) -> bool: return p.tie == kind).size()
			var k := 1
			while have < 2 and k < bays:
				var at := (k*5+(1 if kind == "high" else 3))%(bays-1)+1
				if plans[at].tie != kind and not bool(plans[at].fallen):
					plans[at].tie = kind
					have += 1
				k += 1
		var fallen := 0
		for i in range(2,bays-1):
			if plans[i].tie == "low" and fallen < 1+int(bays >= 10) and weathered > 0.25:
				plans[i].fallen = true
				fallen += 1
		var screens := 0
		for i in range(1,bays-1):
			if screens < 2 and not bool(plans[i].fallen) and i%3 == 1:
				plans[i].screen = true
				if plans[i].tie == "low": plans[i].tie = "high"
				if not -INNER_Z in plans[i].inner: plans[i].inner.append(-INNER_Z)
				screens += 1
		plans[1].buttress = "stair"
		plans[bays-2].buttress = "stair"
		if plans.filter(func(p: Dictionary) -> bool: return not (p.gaps as Array).is_empty()).is_empty(): plans[bays/2].gaps = [2,3]
	return plans

## The lane's corridor from `x0` to `x1` (THREAD and more wide, LANE_Y
## high over the floor), shortened where `ground` stands up into it.
static func _lane(x0: float, x1: float, ground: Callable) -> AABB:
	var top := -INF
	var start := x0
	var end := x1
	if ground.is_valid():
		var x := x0
		var clear := false
		while x <= x1:
			var g := -INF
			for z in [LANE.x,(LANE.x+LANE.y)*0.5,LANE.y]: g = maxf(g,float(ground.call(x,z)))
			var ok := g+LANE_Y.x < LANE_Y.y-1.0
			if ok and not clear: start = x
			if ok:
				end = x
				top = maxf(top,g)
			clear = ok
			if not ok and top > -INF:
				# Stopped by the ground: a slab's length short of it, as the
				# paving and rubble on the slope stand up into it.
				end -= PAVING.y*1.5
				break
			x += 0.5
		if top == -INF or end <= start: return AABB()
	else:
		top = 0.0
	return AABB(Vector3(start,top+LANE_Y.x,LANE.x),Vector3(end-start,LANE_Y.y-LANE_Y.x,LANE.y-LANE.x))

# --- Parts ----------------------------------------------------------------------

## Finishes a piece: the build, its bounds.
static func _finish(b: Build) -> Node3D:
	var root := b.finish()
	root.set_meta("bounds",_bounds(root))
	return root

static func _bounds(root: Node3D) -> AABB:
	var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
	return mesh.mesh.get_aabb() if mesh != null and mesh.mesh != null else AABB()

## A column with its foot at `pose`, `height` from the foot to the abacus's
## top, `broken` the height over the foot it snaps at (INF, whole): its
## foundation under the ground, the moulded base, drums (plain ones of a
## man's height or so, the niche band, the roundel band), the capital;
## gives back the drums over the break [kind, height] (what fell).
static func _column(b: Build, pose: Transform3D, height: float, broken := INF) -> Array:
	# The foundation, below grade (on terrain: on a slope its downhill side
	# shows, so the column never stands on air): a square block.
	if b.terrain.is_valid(): b.solid(RuinKit._box(b,Vector3(PLINTH.y+0.05,FOUNDATION*0.5,PLINTH.y+0.05)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,-FOUNDATION*0.5+0.01,0.0)),RuinKit._stone(b,0.85),true,false)
	_base(b,pose)
	var shaft := height-BASE_H-CAPITAL_H
	var drums: Array = []
	if shaft > NICHE_BAND+ROUNDEL_BAND+2.0:
		var rest := shaft-NICHE_BAND-ROUNDEL_BAND
		for part: Array in [["plain",rest*0.36],["niche",NICHE_BAND],["plain",rest*0.4],["roundel",ROUNDEL_BAND],["plain",rest*0.24]]:
			if str(part[0]) != "plain":
				drums.append(part)
				continue
			# A plain stretch in drums of a metre and a half or so.
			var n := maxi(1,int(round(float(part[1])/1.5)))
			for k in range(n): drums.append(["plain",float(part[1])/n])
	elif shaft > 0.3:
		drums.append(["plain",shaft])
	var y := BASE_H
	var fell: Array = []
	for d: Array in drums:
		var h: float = d[1]
		if y >= broken:
			fell.append(d)
			y += h
			continue
		var extra: Array[Plane] = []
		if y+h > broken: extra = RuinKit._break(b,h,COLUMN_R,clampf((y+h-broken)/h,0.3,0.8),0.0)
		var slip := Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1))*(0.004+0.015*b.weathered)
		_drum(b,pose*Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.03,0.03)),Vector3(0.0,y,0.0)+slip),str(d[0]),h,extra)
		y += h
	if broken >= height and shaft > 0.3: _capital(b,pose*RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3(0.0,BASE_H+shaft,0.0)),0.5))
	return fell

## The moulded base at `pose`: a square plinth (a step) with its top
## chamfered, a torus, a scotia, a smaller torus, a fillet.
static func _base(b: Build, pose: Transform3D) -> void:
	var plinth := RuinKit._box(b,Vector3(PLINTH.y,PLINTH.x*0.5,PLINTH.y))
	for s: float in [-1.0,1.0]:
		for axis: Vector3 in [Vector3.RIGHT,Vector3.BACK]:
			var n := (axis*s+Vector3.UP*1.2).normalized()
			plinth.append(Plane(n,n.dot(axis*s*(PLINTH.y-0.12)+Vector3.UP*PLINTH.x*0.5)))
	b.solid(plinth,pose*RuinKit._settle(b,Vector3(0.0,PLINTH.x*0.5,0.0),0.3),RuinKit._stone(b,0.9))
	var y := PLINTH.x
	var r := COLUMN_R
	# [bottom radius, top radius, height]: the mouldings, crisp.
	var mouldings := [[r+0.3,r+0.38,0.14],[r+0.38,r+0.26,0.14],[r+0.06,r+0.06,0.16],[r+0.12,r+0.2,0.11],[r+0.2,r+0.1,0.11],[r+0.04,r+0.04,0.08]]
	for k in range(mouldings.size()):
		var m: Array = mouldings[k]
		var tone := RuinKit._stone(b,1.08 if k in [1,4] else (0.8 if k == 2 else 0.97))
		b.solid(RuinKit._prism(16,float(m[0]),float(m[1]),0.0,float(m[2])),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,y,0.0)),tone,k in [0,2,5],true,[],-1,0.35)
		y += float(m[2])

## One drum from its foot at `pose`, `h` tall: plain, the roundel band or
## the niche band; `extra` cuts every block of it (a break). The bands are
## carved deep and crisp, their recesses dark and their raised work pale,
## so they read as carving at flight distance; the carving is worn little.
static func _drum(b: Build, pose: Transform3D, kind: String, h: float, extra: Array) -> void:
	var cut: Array[Plane] = []
	for p in extra: cut.append(p)
	var tone := RuinKit._stone(b)
	match kind:
		"plain":
			b.solid(RuinKit._prism(16,COLUMN_R,COLUMN_R,0.0,h),pose,tone,true,true,cut,-1,0.6)
		"roundel":
			# A deep dark recess between two proud fillets, a ring of twelve
			# roundels standing out of it, each a disc with a boss.
			b.solid(RuinKit._prism(16,COLUMN_R-0.16,COLUMN_R-0.16,0.0,h),pose,tone*0.68,true,true,cut,-1,0.3)
			for y: float in [0.0,h-0.13]:
				b.solid(RuinKit._prism(16,COLUMN_R+0.07,COLUMN_R+0.07,y,y+0.13),pose,tone*1.12,false,true,cut,-1,0.25)
			for k in range(12):
				var a := TAU*(k+0.5)/12.0
				var r := Vector3(cos(a),0.0,sin(a))
				var c := r*(COLUMN_R-0.16)+Vector3.UP*h*0.5
				_disc(b,pose,c,r,0.24,0.2,8,tone*1.14,cut)
				_disc(b,pose,c+r*0.2,r,0.1,0.07,6,tone*0.9,cut)
		"niche":
			# A deep dark recess; eight strips standing to the drum's face
			# between the niches; over each niche a pointed head (the
			# spandrels filled), proud fillets top and bottom, a lozenge boss
			# in each niche.
			var back := COLUMN_R-0.24
			b.solid(RuinKit._prism(16,back,back,0.0,h),pose,tone*0.62,true,true,cut,-1,0.3)
			b.solid(RuinKit._prism(16,COLUMN_R+0.06,COLUMN_R+0.06,0.0,0.14),pose,tone*1.1,false,true,cut,-1,0.25)
			b.solid(RuinKit._prism(16,COLUMN_R+0.06,COLUMN_R+0.06,h-0.14,h),pose,tone*1.1,false,true,cut,-1,0.25)
			var half := COLUMN_R*tan(PI/16.0)
			for k in range(8):
				var a := TAU*k/8.0
				var r := Vector3(cos(a),0.0,sin(a))
				var t := Vector3(-sin(a),0.0,cos(a))
				var strip: Array[Plane] = [Plane(r,COLUMN_R),Plane(-r,-(back-0.02)),Plane(t,half*0.6),Plane(-t,half*0.6),Plane(Vector3.DOWN,-0.14),Plane(Vector3.UP,h-0.14)]
				b.solid(strip,pose,tone*1.08,false,true,cut,-1,0.25)
				var an := a+TAU/16.0
				var rn := Vector3(cos(an),0.0,sin(an))
				var tn := Vector3(-sin(an),0.0,cos(an))
				var nw := half*1.42
				var spring := h-0.62
				var apex := h-0.18
				for s: float in [-1.0,1.0]:
					var head: Array[Plane] = [Plane(rn,COLUMN_R),Plane(-rn,-(back-0.02)),Plane(Vector3.UP,h-0.14),Plane(-tn*s,0.0),Plane(tn*s,nw+0.004)]
					var up := (tn*s*(apex-spring)+Vector3.UP*nw).normalized()
					head.append(Plane(-up,-up.dot(tn*s*nw+Vector3.UP*spring)))
					b.solid(head,pose,tone*1.06,false,true,cut,-1,0.25)
				# The boss: a lozenge standing out of the niche's back.
				var at := rn*back+Vector3.UP*(0.14+(spring-0.14)*0.5)
				var boss: Array[Plane] = [Plane(-rn,-rn.dot(at))]
				for e in range(4):
					var ea := TAU*e/4.0
					var side := tn*cos(ea)+Vector3.UP*sin(ea)*1.4
					var n := (rn*0.9+side.normalized()).normalized()
					boss.append(Plane(n,n.dot(at+side.normalized()*0.14)))
				b.solid(boss,pose,tone*1.15,false,true,cut,-1,0.25)

## A disc standing out of a face along `axis` from `centre`: `sides` sided,
## apothem `r`, `depth` proud, its front edge chamfered; `cut` cuts it.
static func _disc(b: Build, pose: Transform3D, centre: Vector3, axis: Vector3, r: float, depth: float, sides: int, tone: Color, cut: Array[Plane] = []) -> void:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	var planes: Array[Plane] = [Plane(axis,axis.dot(centre)+depth),Plane(-axis,-axis.dot(centre))]
	for k in range(sides):
		var a := TAU*(k+0.5)/sides
		var n := u*cos(a)+v*sin(a)
		planes.append(Plane(n,n.dot(centre)+r))
		var c := (n+axis).normalized()
		planes.append(Plane(c,c.dot(centre+n*r+axis*depth)-r*0.18))
	b.solid(planes,pose,tone,false,true,cut,-1,0.25)

## The capital from its foot at `pose`: a necking fillet, the flared
## echinus, the square abacus with its edges chamfered.
static func _capital(b: Build, pose: Transform3D) -> void:
	b.solid(RuinKit._prism(16,COLUMN_R+0.08,COLUMN_R+0.08,0.0,0.12),pose,RuinKit._stone(b,1.08),true,true,[],-1,0.4)
	b.solid(RuinKit._prism(16,COLUMN_R,ABACUS-0.2,0.12,0.6),pose,RuinKit._stone(b,1.0),true,true,[],-1,0.5)
	var abacus := RuinKit._box(b,Vector3(ABACUS,0.2,ABACUS))
	for s: float in [-1.0,1.0]:
		for axis: Vector3 in [Vector3.RIGHT,Vector3.BACK]:
			var n := (axis*s-Vector3.UP*1.0).normalized()
			abacus.append(Plane(n,n.dot(axis*s*(ABACUS-0.1)-Vector3.UP*0.2)))
	b.solid(abacus,pose*RuinKit._settle(b,Vector3(0.0,0.6+0.2,0.0),0.5),RuinKit._stone(b,1.05))

## A beam at `pose` (its soffit's middle; it runs along X), `length` long,
## `depth` deep: two fasciae and a crown moulding over them, each one long
## stone, a row of roundels along the upper fascia's faces; `cut` cuts
## every stone (a crack or a break).
static func _beam(b: Build, pose: Transform3D, length: float, cut: Array = [], depth := BEAM.x) -> void:
	var extra: Array[Plane] = []
	for p in cut: extra.append(p)
	var half := length*0.5
	var lower := depth*0.5
	var upper := depth*0.35
	var crown := depth-lower-upper
	var w := BEAM.y
	b.solid(RuinKit._box(b,Vector3(half,lower*0.5,w-0.12)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,lower*0.5,0.0)),RuinKit._stone(b,0.92),true,true,extra,-1,0.6)
	b.solid(RuinKit._box(b,Vector3(half,upper*0.5,w-0.05)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,lower+upper*0.5,0.0)),RuinKit._stone(b,1.0),true,true,extra,-1,0.6)
	var top := RuinKit._box(b,Vector3(half,crown*0.5,w))
	for s: float in [-1.0,1.0]:
		var n := Vector3(0.0,-1.0,s*1.1).normalized()
		top.append(Plane(n,n.dot(Vector3(0.0,-crown*0.5,s*(w-0.08)))))
	b.solid(top,pose*Transform3D(Basis.IDENTITY,Vector3(0.0,depth-crown*0.5,0.0)),RuinKit._stone(b,1.08),true,true,extra,-1,0.6)
	var count := int(length/1.2)
	for s: float in [-1.0,1.0]:
		for k in range(count):
			var x := -half+length*(k+0.5)/count
			var ok := true
			for p in extra:
				if p.distance_to(Vector3(x,lower,0.0)) > -0.25: ok = false
			if not ok: continue
			_disc(b,pose,Vector3(x,lower+upper*0.5,s*(w-0.05)),Vector3(0.0,0.0,s),minf(0.14,upper*0.4),0.07,8,RuinKit._stone(b,1.12))

## The pose of a beam laid from soffit `a` to soffit `b2` (a fallen one).
static func _sag(a: Vector3, b2: Vector3) -> Transform3D:
	var along := (b2-a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var up := side.cross(along).normalized()
	return Transform3D(Basis(along,up,side),(a+b2)*0.5)

## One roof slab over `x0`..`x1`, `z0`..`z1`, its soffit at `y`: cracked
## across at odds (the parts settled apart, more weathered); `tip`, broken
## and its half tipped up against its neighbour.
static func _slab(b: Build, x0: float, x1: float, z0: float, z1: float, y: float, tip: bool) -> void:
	var half := Vector3((x1-x0)*0.5-0.015,SLAB*0.5,(z1-z0)*0.5-0.015)
	var at := Vector3((x0+x1)*0.5,y+SLAB*0.5,(z0+z1)*0.5)
	if b.rng.randf() < 0.35+0.45*b.weathered or tip:
		var n := Vector3(b.rng.randf_range(-0.5,0.5),0.0,1.0).normalized() if b.rng.randf() < 0.5 else Vector3(1.0,0.0,b.rng.randf_range(-0.5,0.5)).normalized()
		var off := b.rng.randf_range(-0.3,0.3)*minf(half.x,half.z)
		for s: float in [-1.0,1.0]:
			var planes := RuinKit._box(b,half,0.03)
			planes.append(Plane(n*s,s*off-0.02-0.04*b.weathered))
			var pose := RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,at+Vector3(0.0,-0.03*b.weathered*float(s > 0.0),0.0)),0.5)
			if tip and s > 0.0: pose = Transform3D(Basis(Vector3.BACK,0.5),at+Vector3(-0.3,0.55,0.0))
			b.solid(planes,pose,RuinKit._stone(b,1.0),true,true,[],-1,0.7)
	else:
		b.solid(RuinKit._box(b,half,0.03),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,at),0.4),RuinKit._stone(b,1.0),true,true,[],-1,0.7)

## A wall at `pose` (along its X, `span` either side of its middle), from
## under the ground (FOUNDATION below its lowest ground) up to `high`:
## coursed, its head torn down weathered (never under `low`, nor near the
## opening under its head), and through its middle a pointed `opening`
## (clear width, sill over the ground there, height to the springing, the
## arc's radius as a share of the width; zero width, none) under a moulded
## ring, on a sill stone. `thick` its thickness. Gives back its foot.
static func _wall(b: Build, pose: Transform3D, span: float, high: float, opening: Vector4, low: float, thick := WALL_THICK) -> Vector3:
	var ground_low := INF
	var ground_mid := b.floor_at(pose.origin.x,pose.origin.z)
	var x := -span
	while x <= span+0.01:
		var p := pose*Vector3(x,0.0,0.0)
		ground_low = minf(ground_low,b.floor_at(p.x,p.z))
		x += 1.0
	var y0 := (ground_low-FOUNDATION) if b.terrain.is_valid() else 0.0
	var open := opening.x > 0.0
	var w := opening.x*0.5
	var radius := opening.x*opening.w
	var sill := ground_mid+opening.y
	var spring := sill+opening.z
	var head := spring+RuinKit._rise(w,radius)+0.35
	var top: Callable = func(_x: float) -> float: return high
	if b.weathered > 0.2:
		var ragged := RuinKit._ruin_line(b,-span,span,lerpf(high,low,b.weathered),high,b.weathered)
		top = func(xx: float) -> float: return minf(high,maxf(float(ragged.call(xx)),head+0.7 if open and absf(xx) < w+1.0 else low))
	var hole := Callable()
	if open:
		hole = func(y: float) -> Vector2:
			if y < sill: return Vector2(0.0,-1.0)
			if y < spring: return Vector2(0.0,w)
			return Vector2(0.0,RuinKit._arc_half(w,radius,0.32,y-spring))
	if not b.terrain.is_valid(): RuinKit._plinth_course(b,pose,span,thick*0.5)
	RuinKit._courses(b,pose,-span,span,y0+(RuinKit.PLINTH_COURSE.x if not b.terrain.is_valid() else 0.0),top,thick*0.5,hole,0.62)
	if open:
		var stones := maxi(4,int(radius*1.4))
		RuinKit._ring_order(b,pose,0.0,spring,w,radius,0.0,0.32,thick*0.5+0.02,stones,99,1.0,RuinKit._stone(b,1.08),0,Callable(),true)
		b.solid(RuinKit._box(b,Vector3(w+0.3,0.08,thick*0.5+0.05)),pose*RuinKit._settle(b,Vector3(0.0,sill-0.08,0.0),0.3),RuinKit._stone(b,1.08))
	return Vector3(pose.origin.x,y0,pose.origin.z)

## The paving over a bay: big worn slabs in rough rows on the ground, left
## out round the columns' feet (outer, and the inner ones the plan stands);
## weathered, slabs gone to grass, heaved and tipped, tufts in the joints.
static func _paving(b: Build, plan: Dictionary) -> void:
	var feet: Array[Vector2] = []
	for x: float in [0.0,BAY]:
		for z: float in [-ROW_Z,ROW_Z]: feet.append(Vector2(x,z))
	for z: float in plan.get("inner",[]): feet.append(Vector2(0.0,z))
	var z := -WALL_Z+WALL_THICK*0.5
	while z < WALL_Z-WALL_THICK*0.5-0.1:
		var depth := minf(PAVING.y*b.rng.randf_range(0.7,1.2),WALL_Z-WALL_THICK*0.5-z)
		var x := 0.0
		while x < BAY-0.1:
			var x1 := minf(x+PAVING.y*b.rng.randf_range(0.7,1.5),BAY)
			if BAY-x1 < 0.5: x1 = BAY
			var mid := Vector2((x+x1)*0.5,z+depth*0.5)
			var clear := true
			for f in feet:
				if absf(mid.x-f.x) < PLINTH.y+0.6 and absf(mid.y-f.y) < PLINTH.y+0.6: clear = false
			if clear and b.rng.randf() > 0.4*b.weathered:
				var lift := b.rng.randf_range(-0.04,0.0)+b.rng.randf_range(-0.04,0.03)*b.weathered+b.floor_at(mid.x,mid.y)
				var tilt := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.004,0.02)+b.rng.randf()*0.05*b.weathered)
				b.solid(RuinKit._box(b,Vector3((x1-x)*0.5-0.03,PAVING.x*0.5,depth*0.5-0.03),0.03),Transform3D(tilt,Vector3(mid.x,PAVING.x*0.5+lift,mid.y)),RuinKit._stone(b,0.9),true,true,[],-1,0.6)
			elif clear and b.weathered > 0.3 and b.rng.randf() < 0.5:
				b.tuft(Vector3(mid.x,b.floor_at(mid.x,mid.y),mid.y),0.35,4)
			x = x1
		z += depth
	for f in feet: _feet(b,Vector3(f.x,0.0,f.y),PLINTH.y+0.25,int(1+b.weathered*3.0))

## Grass tufts round a foot at `at` (x, z; on the ground), `reach` out.
static func _feet(b: Build, at: Vector3, reach: float, count: int) -> void:
	for i in range(count):
		var a := b.rng.randf()*TAU
		var p := at+Vector3(cos(a),0.0,sin(a))*reach*b.rng.randf_range(0.85,1.25)
		p.y = b.floor_at(p.x,p.z)
		b.tuft(p,0.42,b.rng.randi_range(4,7))
