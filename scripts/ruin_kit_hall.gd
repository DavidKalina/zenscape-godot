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
## row at +ROW_Z there is always a LANE (z LANE.x to LANE.y, 6.16 m wide, under
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
##   of {kind, box, points, width, height} to keep terrain and props out
##   of (the lane, end to end or as far as the ground lets it, and each
##   flyable breach, from the lane out past the wall; `hall`'s doc says
##   which frame each is in); "ends" Array of {at, heading, height, open}
##   (the nave's two mouths: where a hall or an aqueduct chains on);
##   "weave" Dictionary of what there is to weave (low and high ties,
##   fallen beams, roof gaps, slits, narrows, breaches, doors, open bays,
##   as positions or boxes); a hall's "path" (HallPath) and "layout".
## - Cost: a built hall is merged into one mesh and one body
##   (RuinKit `merge`); RuinKit `set_detail` thins its growth and scatter.
##   ./run-ruin-kit.command  (F3 frames the hall, G flies it)

const RuinKit = preload("res://scripts/ruin_kit.gd")
## The plane's size (scripts/world_scale.gd): the lane, the breaches and
## the bay they stand in keep their toy-era widths in wingspans
## (`opening`), the slits and the low ties follow the plane (static vars,
## read once; at `--plane-scale=1 --opening-ratio=1` each is its toy
## number).
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build

const PIECES := RuinKit.HALL_PIECES

# --- Scale -------------------------------------------------------------------

## A bay's length along the nave (m): bay lines BAY apart. 8 in the toy
## era; long enough now for the broken arch breach (ARCH) and a jamb
## ARCH_JAMB either side of it in its wall: 10.56 at the defaults.
const TOY_BAY := 8.0
const ARCH_JAMB := 0.6
## Across the hall: the outer column rows, the inner columns' offsets, the
## side walls' middles and their thickness. The outer rows and the walls
## stand out by what the lane is wider than the toy's 4 m (LANE_GROW; 9.4
## and 12.4 in the toy era, 12.6 and 15.6 at the defaults).
## The lane's width is an opening (scripts/world_scale.gd): toy 4.0 (2.9
## spans), 7.2 at the defaults, 2.2 m past each wingtip. LANE_GROW what it
## is wider than 4 m. Before ROW_Z: static vars set in order.
const TOY_LANE := 4.0
static var LANE_GROW: float = WorldScale.opening(TOY_LANE)-TOY_LANE
static var ROW_Z: float = 9.4+LANE_GROW
const INNER_Z := 2.6
static var WALL_Z: float = 12.4+LANE_GROW
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
## a high one's (hopped over: 2 m and more over its top), their depth. The
## low one 4.0 at plane 1, up by what the plane is taller (WorldScale
## taller) but never so high the room over it, under the capitals, is under
## TIE_OVER: 4.5 at plane 2 (its whole 0.74 would leave 3.36).
const TIE_OVER := 3.6
static var TIE_LOW: float = minf(4.0+WorldScale.taller,COLUMN_H-CAPITAL_H-TIE_DEPTH-TIE_OVER)
const TIE_HIGH := 6.0
const TIE_DEPTH := 0.9
## The generous line: its z range (between the inner columns at +INNER_Z
## and the outer row) and the heights it is clear between. Its width an
## opening (TOY_LANE: 4.0 in the toy era, 7.2 at the defaults), its top up
## as the low tie goes up (3.6 at plane 1, 4.1 at 2).
static var LANE := Vector2(4.0,8.0+LANE_GROW)
static var LANE_Y := Vector2(1.0,3.6+(TIE_LOW-4.0))
## The paving: thickness (stepped onto) and rough size.
const PAVING := Vector2(0.18,2.4)
## A knife-edge slit through a screen wall: clear width (the plane's
## height on its wingtip and a margin: 1.15 at plane 1, as much more as
## the plane is taller, 1.89 at 2, under its span: a level plane does not
## pass), sill, clear height to the head's springing (the span on edge and
## a margin: a gap, 3.3 at plane 1, 4.7 at 2). Where the screen's top
## (under a tie) comes lower than its head, the slit runs up open to the
## top, the tie its lintel (`_wall`).
const KNIFE_ROOM := 1.9/1.4
static var KNIFE := Vector3(1.15+WorldScale.taller,1.0,WorldScale.gap(KNIFE_ROOM))
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
## The breaches in the side walls (a plan's `breach`, by index): none; a
## door (walked through: DOOR, under THREAD); the wall torn down low
## (LOW_WALL: one jump onto it, flown over); a wide broken arch (ARCH: flown
## through); the wall collapsed to its stumps (walked and flown through).
const BREACHES := ["","door","low","arch","collapse"]
## The broken arch ARCH: an opening on the toy era's 5.2 (9.36 at the
## defaults), equilateral, springing at the toy's 5.4 (ARCH_SPRING) at any
## size, so it keeps the toy's proportions. Where its head would stand over
## the roof's top (`arch_broken`: at the defaults it would crown at 13.5)
## its crown is lost: the wall over it is torn down to a notch from
## ARCH_BROKE of its rise (the two haunches stand, their ring broken off),
## and the aisle roof over it is gone with it, the sky open over the breach
## (`bay`). At plane 1 the toy's whole arch, under the roof.
const DOOR := Vector4(2.4,0.0,2.2,0.7)
const TOY_ARCH := 5.2
const ARCH_SPRING := 5.4
const ARCH_BROKE := 0.7
static var ARCH := Vector4(WorldScale.opening(TOY_ARCH),0.0,ARCH_SPRING,1.0)
const LOW_WALL := Vector2(1.2,1.6)
## A flyable breach's corridor: half its width along the nave (an opening
## on the toy era's 3.6 across: 1.8 in the toy era, 3.24 at the defaults),
## its floor and top over the ground by kind, and how far it reaches out
## past the wall.
const TOY_BREACH := 3.6
static var BREACH_HALF: float = WorldScale.opening(TOY_BREACH)*0.5
## The bay (see TOY_BAY): the arch and its jambs, or the toy's 8.
static var BAY: float = maxf(TOY_BAY,ARCH.x+2.0*ARCH_JAMB)

## The broken arch's head (the top of its ring) over the ground, and
## whether it stands over the roof's top, so its crown is lost.
static func arch_head() -> float:
	return ARCH.y+ARCH.z+RuinKit._rise(ARCH.x*0.5,ARCH.x*ARCH.w)+0.35
static func arch_broken() -> bool:
	return arch_head() > ROOF_TOP
## A breach's corridor floor over the ground: BREACH_FLOOR, or over the
## outer columns' carved feet (plinth, base and niche band) when the
## corridor is wider than the room between those (a big plane's THREAD).
## A flyable breach's corridor in a bay (straight frame): `kind`, its wall's
## side `s` (+1 or -1), the ground `mid` there. From the lane through the
## wall to BREACH_OUT past it, BREACH_HALF either side of the bay's middle.
static func breach_box(kind: String, s: float, mid: float) -> AABB:
	var base := mid+breach_floor(kind)
	var top := mid+float(BREACH_TOP.get(kind,0.0))
	var inside := LANE.x if s > 0.0 else -(WALL_Z+WALL_THICK*0.5+BREACH_OUT)
	var outside := WALL_Z+WALL_THICK*0.5+BREACH_OUT if s > 0.0 else LANE.y
	return AABB(Vector3(BAY*0.5-BREACH_HALF,base,inside),Vector3(BREACH_HALF*2.0,top-base,outside-inside))

static func breach_floor(kind: String) -> float:
	var floor_y := float(BREACH_FLOOR.get(kind,0.0))
	if BREACH_HALF*2.0 > BAY-2.0*(PLINTH.y+0.1): floor_y = maxf(floor_y,PLINTH.x+BASE_H+NICHE_BAND+0.2)
	return floor_y
## Whether a flyable breach's corridor (BREACH_HALF a side) fits between
## the outer row's columns at bay `i`'s lines on `side` (0 left, -Z; 1
## right) of `path`: on the inside of a curve the bay is shorter there, the
## columns closer (path space: a column is wider there by 1 over the
## stretch). Straight, always (BAY less a column's width is wider).
static func breach_fits(path: HallPath, i: int, side: int) -> bool:
	if path == null or not path.curved(): return true
	var z := ROW_Z*(side*2-1)
	var half0 := COLUMN_R/maxf(0.2,path.stretch(BAY*i,z))
	var half1 := COLUMN_R/maxf(0.2,path.stretch(BAY*(i+1),z))
	return BAY-half0-half1 >= BREACH_HALF*2.0+0.2

## The plans' flyable breaches that `breach_fits` refuses on `path` are
## let go, then each side's least (at least two flyable on the right, one
## on the left) made up again where one fits.
static func fit_breaches(plans: Array, path: HallPath) -> void:
	if path == null or not path.curved(): return
	var flyable := ["low","arch","collapse"]
	for i in range(plans.size()):
		var p: Dictionary = plans[i]
		for side in range(2):
			if BREACHES[p.breach[side]] in flyable and not breach_fits(path,i,side):
				var v: Vector2i = p.breach
				v[side] = 0
				p.breach = v
	var bays := plans.size()
	if bays < 4: return
	for side in range(2):
		var have := plans.filter(func(p: Dictionary) -> bool: return BREACHES[p.breach[side]] in flyable).size()
		for i in range(1,bays-1):
			if have >= (2 if side == 1 else 1): break
			var p: Dictionary = plans[i]
			if BREACHES[p.breach[side]] == "" and not (side == 0 and bool(p.fallen)) and breach_fits(path,i,side):
				var v: Vector2i = p.breach
				v[side] = BREACHES.find("collapse" if p.roof == "open" else "arch")
				p.breach = v
				have += 1

const BREACH_FLOOR := {"low":2.3,"arch":1.0,"collapse":1.4}
const BREACH_TOP := {"low":8.0,"arch":6.4,"collapse":8.0}
const BREACH_OUT := 2.5
## The cost: the detail a hall is built at in the world (RuinKit
## `set_detail`), and the most triangles a 12-bay hall may draw there.
const IN_WORLD := 0.25
const BUDGET := 100000
## Over an open bay, the sky from this height up (over the nave between the
## rows, clear of the bay lines' beams and ties).
const OPEN_SKY := 4.6
## The side walls' parapet over the roof (m, a range).
const PARAPET := Vector2(0.6,1.8)
## A gable's rise over the roof beam's top.
const GABLE_RISE := 6.5
## A torn bay line's columns snap this high (m), and a torn bay's walls
## stand at most this high.
const TORN_SNAP := Vector2(2.2,7.5)
const TORN_WALL := Vector2(2.6,5.5)
## A wall course's height (colossal ashlar).
const COURSE := 1.25
## A column's facets round (its drums, mouldings and capital).
const SIDES := 12
## The roundels round a column's roundel band.
const ROUNDELS := 7

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
	b.lean = true
	b.cull = true
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
	b.lean = true
	b.cull = true
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
	b.lean = true
	b.cull = true
	var sleeper := 0.36
	# A stack of the toy bay's slabs (a piece on its own, not a bay's roof).
	for s: float in [-1.0,1.0]:
		b.solid(RuinKit._box(b,Vector3(TOY_BAY*0.36,sleeper*0.5,0.42)),RuinKit._settle(b,Vector3(0.0,sleeper*0.5,s*1.6),0.4),RuinKit._stone(b,0.92))
	var strips := [-2.4,-0.8,0.8,2.4]
	var gone: Array = [0] if weathered > 0.5 else []
	for i in range(strips.size()-1):
		if i in gone: continue
		_slab(b,-TOY_BAY*0.36,TOY_BAY*0.36,float(strips[i]),float(strips[i+1]),sleeper,weathered > 0.4 and i == 2)
	_feet(b,Vector3(0.0,0.0,2.8),TOY_BAY*0.3,int(1+weathered*5.0))
	RuinKit._rubble(b,3.4,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return _finish(b)

## 4. A hall bay: its bay line at x 0 (the outer columns, the inner ones
## the plan asks for, the roof beam across, a tie if asked) and its length
## to x BAY (the architraves along the rows, the roof slabs, the side walls
## with their lancets or breaches, the paving, a screen with its slit, a
## fallen beam, a stepped buttress outside); `plan` (from `hall`; empty, a
## bay showing a little of everything) and `ground` as for `hall`; `path`
## (a Path, shifted to the bay's start) bends it along a curve: it is
## built straight and drawn bent (a wedge on an arc), its columns carried
## whole, so they stay round.
##   plan: inner (Array of z), tie ("", "low", "high"), roof ("whole",
##   "broken": half the nave's slabs gone, "open": no slabs, the beams kept
##   as `beam` and `architraves` say), gaps (Array of the nave's roof
##   strips 1..4 left open in a whole roof), beam (bool: the roof beam at
##   the bay line), architraves (Vector2: left and right row, 1 kept),
##   fallen (bool), screen (bool, a wall with a knife-edge slit between the
##   left outer column and the inner column at -INNER_Z), breach (Vector2i
##   of BREACHES indices, left and right: 0 a whole wall), buttress ("",
##   "plain", "stair"), lancets (Vector2: odds, left and right), gable
##   (bool: a gable over the bay line, standing over the roof), last (bool:
##   the closing bay line at x BAY too), last_gable (a gable on it).
static func bay(seed_value: int, weathered := 0.0, plan := {}, ground := Callable(), path: HallPath = null) -> Node3D:
	if plan.is_empty():
		plan = {"inner":[-INNER_Z],"tie":"low","roof":"broken","gaps":[2],"fallen":weathered > 0.3,"screen":true,"buttress":"stair","lancets":Vector2(1.0,1.0),"breach":Vector2i(0,BREACHES.find("arch")),"gable":true,"last":true}
	var b := Build.new(seed_value,weathered,"HallBay")
	b.settle = SETTLE
	b.lean = true
	b.cull = true
	b.terrain = ground
	b.path = path
	# On flat ground nothing is drawn far under it (a fallen beam's buried end).
	if not ground.is_valid(): b.ground = -0.3
	var roof: String = plan.get("roof","whole")
	var breach: Vector2i = plan.get("breach",Vector2i.ZERO)
	var soffit := COLUMN_H+BEAM.x
	# A torn bay line (a sundered hall's broken end, scripts/sundered_hall.gd):
	# 1 the line at x 0, 2 the closing one; its columns snapped, no beam or
	# gable over it, the bay's walls torn down low.
	var torn: int = plan.get("torn",0)
	b.shelter = func(p: Vector3, n: Vector3) -> float: return _shelter(p,n,roof)
	var weave := {"low_ties":[],"high_ties":[],"fallen":[],"gaps":[],"slits":[],"narrows":[],"breaches":[],"doors":[],"open":[]}
	var feet: Array = []
	# The bay lines: x 0, and x BAY closing the last bay.
	var lines: Array = [0.0]
	if bool(plan.get("last",false)): lines.append(BAY)
	for x: float in lines:
		var inner: Array = plan.get("inner",[]) if x == 0.0 else []
		var torn_line := (x == 0.0 and torn & 1 != 0) or (x > 0.0 and torn & 2 != 0)
		for z: float in [-ROW_Z,ROW_Z]+inner:
			var foot := b.floor_at(x,z)
			b.rigid = true
			_column(b,Transform3D(Basis.IDENTITY,Vector3(x,foot,z)),COLUMN_H-foot,b.rng.randf_range(TORN_SNAP.x,TORN_SNAP.y) if torn_line else INF)
			b.rigid = false
			feet.append(Vector3(x,foot-(FOUNDATION if b.terrain.is_valid() else 0.0),z))
		# The roof beam across, wall to wall, in three stones resting on the
		# outer columns (and the inner ones, which it passes over).
		if (bool(plan.get("beam",true)) or x > 0.0) and not torn_line:
			var turn := Basis(Vector3.UP,PI*0.5)
			for span: Vector2 in [Vector2(-WALL_Z+0.2,-ROW_Z),Vector2(-ROW_Z,ROW_Z),Vector2(ROW_Z,WALL_Z-0.2)]:
				_beam(b,Transform3D(turn,Vector3(x,COLUMN_H,(span.x+span.y)*0.5)),absf(span.y-span.x))
			if (x == 0.0 and bool(plan.get("gable",false))) or (x > 0.0 and bool(plan.get("last_gable",false))):
				_gable(b,x)
	if inner_pair(plan): weave.narrows.append(Vector3(0.0,0.0,0.0))
	# The architraves along the rows (in an open stretch, some fallen).
	var keep: Vector2 = plan.get("architraves",Vector2.ONE)
	for k in range(2):
		if keep[k] > 0.5: _beam(b,Transform3D(Basis.IDENTITY,Vector3(BAY*0.5,COLUMN_H,ROW_Z*(k*2-1))),BAY-0.04)
	# The tie across the nave at the bay line.
	var tie: String = plan.get("tie","")
	if tie != "":
		var tie_y := TIE_LOW if tie == "low" else TIE_HIGH
		_beam(b,Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(0.0,tie_y,0.0)),ROW_Z*2.0,[],TIE_DEPTH)
		(weave.low_ties if tie == "low" else weave.high_ties).append(Vector3(0.0,tie_y,0.0))
	# The roof: six strips across (the aisles' and four over the nave), the
	# gaps the plan asks for left open (big enough to fly out and back in);
	# broken, about half the nave's strips gone; open, none.
	var edges := [-WALL_Z-0.5,-ROW_Z,-ROW_Z*0.5,0.0,ROW_Z*0.5,ROW_Z,WALL_Z+0.5]
	var gaps: Array = (plan.get("gaps",[]) as Array).duplicate()
	if roof == "broken":
		var nave := [1,2,3,4]
		var gone := 2+int(b.rng.randf() < 0.4)
		while gaps.size() < gone:
			var pick: int = nave[b.rng.randi()%nave.size()]
			if not pick in gaps: gaps.append(pick)
		if b.rng.randf() < 0.5: gaps.append(0 if b.rng.randf() < 0.5 else 5)
	# Over a broken arch whose crown is lost the aisle's roof is gone too:
	# the breach open to the sky.
	if arch_broken():
		for k in range(2):
			if BREACHES[breach[k]] == "arch" and not (k*5) in gaps: gaps.append(k*5)
	# An outer nave strip (1, 4: its architrave eats into it) is too narrow
	# to fly out of alone once the plane is big: its inner neighbour goes
	# with it, and the opening is the two (`runs` below).
	if 1 in gaps and not 2 in gaps and RuinKit.THREAD > ROW_Z*0.5-BEAM.y-0.3: gaps.append(2)
	if 4 in gaps and not 3 in gaps and RuinKit.THREAD > ROW_Z*0.5-BEAM.y-0.3: gaps.append(3)
	if roof == "open":
		weave.open.append(AABB(Vector3(ABACUS+0.6,OPEN_SKY,-ROW_Z+ABACUS+0.2),Vector3(BAY-2.0*ABACUS-1.2,ROOF_TOP+6.0-OPEN_SKY,(ROW_Z-ABACUS-0.2)*2.0)))
	else:
		for i in range(edges.size()-1):
			if i in gaps:
				# The opening: clear of the roof beams at the bay lines and of the
				# architraves along the rows; strips gapped side by side, one.
				if i >= 1 and i <= 4 and not (i-1 in gaps and i-1 >= 1):
					var last := i
					while last+1 <= 4 and last+1 in gaps: last += 1
					var z0: float = float(edges[i])+(BEAM.y+0.18 if absf(float(edges[i])) > ROW_Z-0.1 else 0.12)
					var z1: float = float(edges[last+1])-(BEAM.y+0.18 if absf(float(edges[last+1])) > ROW_Z-0.1 else 0.12)
					weave.gaps.append(AABB(Vector3(BEAM.y+0.4,soffit-0.2,z0),Vector3(BAY-2.0*BEAM.y-0.8,SLAB+0.6,z1-z0)))
				continue
			# Broken: a slab here and there tipped up on its neighbour.
			# Two slabs a strip, split at odds along the bay, so the roof reads
			# as laid stone, not one sheet.
			var cut := b.rng.randf_range(BAY*0.35,BAY*0.65)
			var tip := roof == "broken" and b.rng.randf() < 0.3 and (i-1 in gaps or i+1 in gaps)
			_slab(b,0.0,cut,float(edges[i]),float(edges[i+1]),soffit,false)
			_slab(b,cut,BAY,float(edges[i]),float(edges[i+1]),soffit,tip)
		if roof == "broken" and breach.x == 0:
			# A slab or two of what fell, lying broken across the left of the
			# nave (out of the lane).
			for k in range(1+int(b.rng.randf() < 0.5)):
				var at := Vector3(b.rng.randf_range(BAY*0.5-0.4,BAY*0.5+0.6),0.0,b.rng.randf_range(-ROW_Z+2.4,-INNER_Z-1.6))
				at.y = b.floor_at(at.x,at.z)+SLAB*0.5+0.1
				var lie := Basis(Vector3.UP,b.rng.randf_range(-0.6,0.6))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.14,0.14))
				b.solid(RuinKit._box(b,Vector3(b.rng.randf_range(1.1,1.6),SLAB*0.5,b.rng.randf_range(0.9,1.4))),Transform3D(lie,at),RuinKit._stone(b,0.95),true,true,[RuinKit._break(b,SLAB,1.4,0.5,SLAB*0.5)[0]])
	# The side walls: whole (a lancet at the plan's odds), or breached; in an
	# open stretch torn lower.
	var lancets: Vector2 = plan.get("lancets",Vector2(0.7,0.7))
	for k in range(2):
		var s := -1.0 if k == 0 else 1.0
		var kind: String = BREACHES[breach[k]]
		var odds := lancets.x if s < 0.0 else lancets.y
		# Under a roof the wall stands on past it as a parapet (ragged as it
		# weathers), so the roofline rises and falls along the hall.
		var high := ROOF_TOP+b.rng.randf_range(PARAPET.x,PARAPET.y)
		var low := soffit-3.0
		var mid := b.floor_at(BAY*0.5,s*WALL_Z)
		if roof == "open":
			# Torn lower, over the ground where it stands (on a slope too).
			high = minf(soffit,mid+b.rng.randf_range(6.5,9.0))
			low = minf(high-0.5,mid+b.rng.randf_range(2.8,4.0))
		if torn != 0:
			high = minf(high,mid+b.rng.randf_range(TORN_WALL.x,TORN_WALL.y))
			low = minf(high-0.5,mid+0.6)
		var opening := LANCET if b.rng.randf() < odds and kind == "" and roof != "open" else Vector4.ZERO
		var pose := Transform3D(Basis.IDENTITY,Vector3(BAY*0.5,0.0,s*WALL_Z))
		match kind:
			"door": opening = DOOR
			"arch": opening = ARCH
			"low":
				high = mid+b.rng.randf_range(LOW_WALL.x,LOW_WALL.y)
				low = high-0.3
			"collapse":
				high = mid+b.rng.randf_range(0.6,1.0)
				low = mid+0.25
		feet.append(_wall(b,pose,BAY*0.5-0.02,high,opening,low,WALL_THICK,kind == "arch"))
		if kind in ["low","collapse"]:
			# What fell: drifts outside, either side of the gap.
			for x: float in [0.9,BAY-0.9]:
				RuinKit._drift(b,Vector3(x,0.0,s*(WALL_Z+1.6)),1.0,3+int(b.weathered*3.0))
		if kind != "":
			var box := breach_box(kind,s,mid)
			if kind == "door": weave.doors.append({"at":Vector3(BAY*0.5,mid,s*WALL_Z),"side":int(s)})
			else: weave.breaches.append({"box":box,"side":int(s),"kind":kind})
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
		b.rigid = true
		_beam(b,_sag(head-Vector3(0.0,BEAM.x,0.0),foot-Vector3(0.0,BEAM.x,0.0)),head.distance_to(foot)+0.6,RuinKit._break(b,BEAM.x,1.0,0.3,0.0))
		b.rigid = false
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
		# Buried to near the roof, there is no buttress, and no foot.
		if not stages.is_empty():
			RuinKit._buttress(b,Transform3D(Basis.IDENTITY,Vector3(0.0,foot-sunk,WALL_Z+WALL_THICK*0.5-0.05)),stages,1.5,false,true)
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
		if not stages.is_empty():
			RuinKit._buttress(b,pose,stages,1.5,false,buttress == "plain")
			feet.append(Vector3(0.0,foot-sunk,-WALL_Z-1.4))
	_paving(b,plan)
	for i in range(int(b.weathered*5.0)):
		b.hang(Vector3(b.rng.randf_range(0.5,BAY-0.5),0.0,b.rng.randf_range(-ROW_Z,ROW_Z)),b.rng.randf_range(0.8,2.6)*b.weathered,true)
	# Rubble in drifts at the left columns' feet, out of the lane (and of a
	# breach's way across the nave).
	if b.weathered > 0.2:
		var x := b.rng.randf_range(1.0,BAY-1.0)
		if breach.x != 0: x = 1.0 if x < BAY*0.5 else BAY-1.0
		RuinKit._drift(b,Vector3(x,0.0,-ROW_Z+2.0),1.4 if breach.x == 0 else 0.8,int(b.weathered*6.0))
	# A caller's own dressing (plan "dress": Callable(b, plan), e.g. the
	# sundered hall's overgrowth, scripts/sundered_growth.gd), the stone all
	# laid; growth only, never solid.
	var dress: Variant = plan.get("dress")
	if dress is Callable and (dress as Callable).is_valid(): (dress as Callable).call(b,plan)
	var root := _finish(b)
	root.set_meta("feet",feet)
	root.set_meta("weave",weave)
	root.set_meta("ends",[{"at":Vector3(0.0,b.floor_at(0.0,0.0),0.0),"heading":Vector3.LEFT,"height":b.floor_at(0.0,0.0),"open":true},{"at":Vector3(BAY,b.floor_at(BAY,0.0),0.0),"heading":Vector3.RIGHT,"height":b.floor_at(BAY,0.0),"open":true}])
	root.set_meta("corridors",[corridor(HallPath.make([{"bays":1,"turn":0.0}],BAY),_lane(0.0,BAY,ground),"lane")])
	root.set_meta("walk",[{"from":Vector3(0.0,ROOF_TOP,0.0),"to":Vector3(BAY,ROOF_TOP,0.0),"width":WALL_Z*2.0}])
	if not weave.slits.is_empty(): root.set_meta("slit",weave.slits[0])
	return root

## How sheltered a face of a bay is (Build `shelter`): under a whole roof
## deep, under a broken one less, in an open stretch a little (the bright
## floor's bounce); nothing on the roof's top, on the walls' outer faces or
## outside them.
static func _shelter(p: Vector3, n: Vector3, roof: String) -> float:
	var az := absf(p.z)
	if az > WALL_Z+0.7: return 0.0
	if az > WALL_Z-WALL_THICK*0.5-0.05 and n.z*signf(p.z) > 0.3: return 0.0
	if p.y > COLUMN_H+BEAM.x+0.1 and n.y > 0.3: return 0.0
	if p.y > ROOF_TOP+0.2: return 0.0
	var amount: float = {"whole":1.0,"broken":0.75,"open":0.35}.get(roof,1.0)
	# Faces up in the air (the beams, the capitals) catch less of the
	# floor's bounce than those near it.
	return amount*lerpf(1.0,0.7,clampf(p.y/COLUMN_H,0.0,1.0))

## A gable over the bay line at `x`: a triangle of coursed stone on the roof
## beam, standing over the roof (where a roofed stretch meets an open one,
## and at the mouths), its head ragged, so the hall's skyline rises and
## falls.
static func _gable(b: Build, x: float) -> void:
	var half := WALL_Z+0.4
	var base := COLUMN_H+BEAM.x
	var apex := base+GABLE_RISE*b.rng.randf_range(0.85,1.1)
	var peak: Callable = func(zz: float) -> float: return base+(apex-base)*(1.0-absf(zz)/half)
	var top := peak
	if b.weathered > 0.2:
		var ragged := RuinKit._ruin_line(b,-half,half,lerpf(apex,base+1.2,b.weathered*0.5),apex,b.weathered)
		top = func(zz: float) -> float: return minf(float(peak.call(zz)),maxf(float(ragged.call(zz)),base+0.8))
	RuinKit._courses(b,Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,0.0,0.0)),-half,half,base,top,0.6,Callable(),COURSE)

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

## A long hall of `bays` bays (BAY each) from x 0, its plan drawn from the
## seed: stretches of whole roof (the dark nave), broken roof and open sky
## in turn, a gable standing over the roof where a roofed stretch meets an
## open one and at the mouths; breaches in the side walls (doors walked
## through, walls torn low, wide broken arches, collapsed bays: ways out
## and back in from the sides); inner columns staggered from line to line,
## now and then two together; low and high ties at bay lines, both kinds at
## least twice; a beam or two fallen across the nave onto a low tie; a
## couple of screens with knife-edge slits; lancets in the whole walls; a
## stepped buttress outside up to the roof near each end.
## `layout`: the hall's plan view as stretches [{bays, turn}] (turn in
## radians over the stretch, + to the left looking down the nave, 0
## straight; their bays add up to `bays`); none, straight along +X. A
## curved stretch's bays are wedges on the arc, the columns, beams and roof
## following it. `ground` as in the header (the hall's frame); the hall's
## bays are merged into one mesh and body unless `merged` is off.
## Metadata (see the header) in the hall's frame, but for "weave", "walk"
## and each corridor's "box", which are in its path space (x along the
## nave's middle line from the first mouth, z across it): "path" (a
## HallPath) carries them over (`point`) and back (`locate`). On a
## straight hall the two are the same.
static func hall(seed_value: int, weathered := 0.6, bays := 12, ground := Callable(), merged := true, layout: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Hall"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"long hall"])
	var plans := plan(rng,weathered,bays)
	var path := HallPath.make(layout if not layout.is_empty() else [{"bays":bays,"turn":0.0}],BAY)
	fit_breaches(plans,path)
	var curved := path.curved()
	# The ground in path space.
	var pground := Callable()
	if ground.is_valid():
		pground = func(x: float, z: float) -> float:
			var p := path.point(Vector3(x,0.0,z))
			return float(ground.call(p.x,p.z))
	var weave := {"low_ties":[],"high_ties":[],"fallen":[],"gaps":[],"slits":[],"narrows":[],"breaches":[],"doors":[],"open":[]}
	var feet: Array = []
	for i in range(bays):
		var x0 := BAY*i
		var shifted := Callable()
		if pground.is_valid(): shifted = func(x: float, z: float) -> float: return float(pground.call(x+x0,z))
		var bay_seed := seed_value*31+i
		var bay_worn := clampf(weathered+rng.randf_range(-0.12,0.12),0.0,1.0)
		var bay_path: HallPath = path.shifted(x0) if curved else null
		var node := bay(bay_seed,bay_worn,plans[i],shifted,bay_path)
		node.name = "Bay%d" % i
		# Unmerged, each bay keeps how to build it again (a break by its
		# joints, scripts/kit_isle/kit_breaks.gd `add`).
		if not merged:
			var bay_plan: Dictionary = plans[i]
			node.set_meta("rebuild",func() -> Node3D: return bay(bay_seed,bay_worn,bay_plan,shifted,bay_path))
		if not curved: node.position.x = x0
		root.add_child(node)
		var offset := Vector3(x0,0.0,0.0)
		for p: Vector3 in node.get_meta("feet"): feet.append(path.point(p+offset))
		var w: Dictionary = node.get_meta("weave")
		for key: String in weave:
			for item: Variant in w[key]:
				weave[key].append(_moved(item,offset))
	var length := BAY*bays
	var floor0 := float(pground.call(0.0,0.0)) if pground.is_valid() else 0.0
	var floor1 := float(pground.call(length,0.0)) if pground.is_valid() else 0.0
	var lane := _lane(0.0,length,pground)
	var corridors: Array = [corridor(path,lane,"lane")]
	for item: Dictionary in weave.breaches: corridors.append(corridor(path,item.box,"breach"))
	root.set_meta("feet",feet)
	root.set_meta("weave",weave)
	root.set_meta("plans",plans)
	root.set_meta("length",length)
	root.set_meta("path",path)
	root.set_meta("layout",path.layout)
	root.set_meta("corridors",corridors)
	# A mouth is open while the lane reaches it (the ground has not buried it).
	root.set_meta("ends",[{"at":path.point(Vector3(0.0,floor0,0.0)),"heading":-path.tangent(0.0),"height":floor0,"open":lane.position.x < 0.5},{"at":path.point(Vector3(length,floor1,0.0)),"heading":path.tangent(length),"height":floor1,"open":lane.end.x > length-0.5}])
	root.set_meta("walk",[{"from":Vector3(0.0,ROOF_TOP,0.0),"to":Vector3(length,ROOF_TOP,0.0),"width":WALL_Z*2.0},{"from":Vector3(0.0,floor0,LANE.x+2.0),"to":Vector3(length,floor1,LANE.x+2.0),"width":LANE.y-LANE.x}])
	if not (weave.slits as Array).is_empty(): root.set_meta("slit",weave.slits[0])
	if merged: RuinKit.merge(root)
	root.set_meta("bounds",_bounds(root))
	return root

## A weave item of a bay moved along the nave by `offset` (path space).
static func _moved(item: Variant, offset: Vector3) -> Variant:
	if item is Vector3: return item+offset
	if item is AABB: return AABB((item as AABB).position+offset,(item as AABB).size)
	if item is Dictionary:
		var out: Dictionary = (item as Dictionary).duplicate()
		if out.has("box"): out.box = AABB((out.box as AABB).position+offset,(out.box as AABB).size)
		if out.has("at"): out.at = (out.at as Vector3)+offset
		return out
	return [(item[0] as Vector3)+offset,(item[1] as Vector3)+offset]

## A corridor as the metadata gives it: its `box` in path space, and in the
## hall's frame the middle line of its floor (`points`, along its long
## axis: down the nave for the lane, across it for a breach), its `width`
## and `height`, and its `kind`.
static func corridor(path: HallPath, box: AABB, kind: String) -> Dictionary:
	var points := PackedVector3Array()
	var mid := box.get_center()
	if box.size.x >= box.size.z:
		var n := maxi(1,int(ceil(box.size.x/2.0)))
		for k in range(n+1): points.append(path.point(Vector3(box.position.x+box.size.x*k/n,box.position.y,mid.z)))
		return {"kind":kind,"box":box,"points":points,"width":box.size.z,"height":box.size.y}
	points.append(path.point(Vector3(mid.x,box.position.y,box.position.z)))
	points.append(path.point(Vector3(mid.x,box.position.y,box.end.z)))
	return {"kind":kind,"box":box,"points":points,"width":box.size.x,"height":box.size.y}

## The plans for `bays` bays (see `bay`), drawn from `rng`.
static func plan(rng: RandomNumberGenerator, weathered: float, bays: int) -> Array:
	var plans: Array = []
	var choices := [[-INNER_Z],[INNER_Z],[0.0],[-INNER_Z,INNER_Z],[]]
	var last_inner := -1
	for i in range(bays):
		var p := {"inner":[],"tie":"","roof":"whole","gaps":[],"beam":true,"architraves":Vector2.ONE,"fallen":false,"screen":false,"breach":Vector2i.ZERO,"buttress":"","right_buttress":false,"lancets":Vector2(0.75,0.75),"gable":i == 0,"last":i == bays-1,"last_gable":i == bays-1}
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
	if bays < 4: return plans
	# The roof in stretches: whole (the dark nave), broken, open to the sky,
	# broken, whole again..., the first whole.
	var order := ["whole","broken","open","broken"]
	var at := 0
	var k := 0
	while at < bays:
		var state: String = order[k%order.size()]
		var n: int = {"whole":rng.randi_range(2,3),"broken":rng.randi_range(1,2),"open":rng.randi_range(2,3)}[state]
		for j in range(n):
			if at < bays: plans[at].roof = state
			at += 1
		k += 1
	for i in range(bays):
		var p: Dictionary = plans[i]
		var prev: String = plans[i-1].roof if i > 0 else "whole"
		if p.roof == "open":
			p.gaps = []
			# The roof beam stays where a roof still rests on it, and now and
			# then where none does; the architraves now and then.
			p.beam = prev != "open" or rng.randf() < 0.5
			p.architraves = Vector2(float(rng.randf() < 0.6),float(rng.randf() < 0.6))
		elif p.roof == "broken":
			p.gaps = []
		# A gable over the line where a roof meets the open sky.
		if i > 0 and (prev == "open") != (p.roof == "open"): p.gable = true
	# Both kinds of tie at least twice, a fallen beam or two, a couple of
	# screens, a stair up near each end, a gap or two in the roof.
	for kind: String in ["low","high"]:
		var have := plans.filter(func(p: Dictionary) -> bool: return p.tie == kind).size()
		var j := 1
		while have < 2 and j < bays:
			var pick := (j*5+(1 if kind == "high" else 3))%(bays-1)+1
			if plans[pick].tie != kind and not bool(plans[pick].fallen):
				plans[pick].tie = kind
				have += 1
			j += 1
	var fallen := 0
	for i in range(2,bays-1):
		if plans[i].tie == "low" and plans[i].roof != "open" and fallen < 1+int(bays >= 10) and weathered > 0.25:
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
	if plans.all(func(p: Dictionary) -> bool: return (p.gaps as Array).is_empty() and p.roof == "whole"): plans[bays/2].gaps = [2,3]
	# Breaches: open stretches' walls collapse or are torn low; roofed ones
	# open in wide broken arches and doors. A flyable breach on the left
	# crosses the nave, so never where a beam has fallen across it. At least
	# two flyable on the right, one on the left, a door.
	var flyable := ["low","arch","collapse"]
	for i in range(1,bays-1):
		var p: Dictionary = plans[i]
		for side in range(2):
			var roll := rng.randf()
			var kind := ""
			if p.roof == "open": kind = "collapse" if roll < 0.35 else ("low" if roll < 0.6 else "")
			else: kind = "arch" if roll < 0.2 else ("door" if roll < 0.32 else ("low" if roll < 0.4 else ""))
			if side == 0 and kind in flyable and bool(p.fallen): kind = ""
			var v: Vector2i = p.breach
			v[side] = BREACHES.find(kind)
			p.breach = v
	for side in range(2):
		var have := plans.filter(func(p: Dictionary) -> bool: return BREACHES[p.breach[side]] in flyable).size()
		var j := 0
		while have < (2 if side == 1 else 1) and j < bays:
			var i := (j*7+3+side*2)%(bays-2)+1
			var p: Dictionary = plans[i]
			if BREACHES[p.breach[side]] == "" and not (side == 0 and bool(p.fallen)):
				var v: Vector2i = p.breach
				v[side] = BREACHES.find("collapse" if p.roof == "open" else "arch")
				p.breach = v
				have += 1
			j += 1
	if not plans.any(func(p: Dictionary) -> bool: return BREACHES[p.breach.x] == "door" or BREACHES[p.breach.y] == "door"):
		for i in range(1,bays-1):
			if BREACHES[plans[i].breach.y] == "" and plans[i].roof != "open":
				plans[i].breach = Vector2i(plans[i].breach.x,BREACHES.find("door"))
				break
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
			# Its top kept under a high tie's soffit too (the lane is taller
			# for a bigger plane, so it would reach one up a slope).
			var ok := g+LANE_Y.x < LANE_Y.y-1.0 and g+LANE_Y.y < TIE_HIGH-0.4
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
	var bright := [1,4]
	var solid := [0,2,5]
	for k in range(mouldings.size()):
		var m: Array = mouldings[k]
		var tone := RuinKit._stone(b,1.08 if k in bright else (0.8 if k == 2 else 0.97))
		b.solid(RuinKit._prism(SIDES,float(m[0]),float(m[1]),0.0,float(m[2])),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,y,0.0)),tone,k in solid,true,[],-1,0.35)
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
			b.solid(RuinKit._prism(SIDES,COLUMN_R,COLUMN_R,0.0,h),pose,tone,true,true,cut,-1,0.6)
		"roundel":
			# A deep dark recess between two proud fillets, a ring of twelve
			# roundels standing out of it, each a disc with a boss.
			b.solid(RuinKit._prism(SIDES,COLUMN_R-0.16,COLUMN_R-0.16,0.0,h),pose,tone*0.68,true,true,cut,-1,0.3)
			for y: float in [0.0,h-0.13]:
				b.solid(RuinKit._prism(SIDES,COLUMN_R+0.07,COLUMN_R+0.07,y,y+0.13),pose,tone*1.12,false,true,cut,-1,0.25)
			for k in range(ROUNDELS):
				var a := TAU*(k+0.5)/ROUNDELS
				var r := Vector3(cos(a),0.0,sin(a))
				var c := r*(COLUMN_R-0.16)+Vector3.UP*h*0.5
				_disc(b,pose,c,r,0.27,0.2,6,tone*1.14,cut)
				if not b.lean: _disc(b,pose,c+r*0.2,r,0.1,0.07,4,tone*0.9,cut)
		"niche":
			# A deep dark recess; eight strips standing to the drum's face
			# between the niches; over each niche a pointed head (the
			# spandrels filled), proud fillets top and bottom, a lozenge boss
			# in each niche.
			var back := COLUMN_R-0.24
			b.solid(RuinKit._prism(SIDES,back,back,0.0,h),pose,tone*0.62,true,true,cut,-1,0.3)
			b.solid(RuinKit._prism(SIDES,COLUMN_R+0.06,COLUMN_R+0.06,0.0,0.14),pose,tone*1.1,false,true,cut,-1,0.25)
			b.solid(RuinKit._prism(SIDES,COLUMN_R+0.06,COLUMN_R+0.06,h-0.14,h),pose,tone*1.1,false,true,cut,-1,0.25)
			var niches := 6 if b.lean else 8
			var half := COLUMN_R*tan(PI/(2.0*niches))
			for k in range(niches):
				var a := TAU*k/float(niches)
				var r := Vector3(cos(a),0.0,sin(a))
				var t := Vector3(-sin(a),0.0,cos(a))
				var strip: Array[Plane] = [Plane(r,COLUMN_R),Plane(-r,-(back-0.02)),Plane(t,half*0.6),Plane(-t,half*0.6),Plane(Vector3.DOWN,-0.14),Plane(Vector3.UP,h-0.14)]
				b.solid(strip,pose,tone*1.08,false,true,cut,-1,0.25)
				var an := a+PI/float(niches)
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
		if b.lean: continue
		var c := (n+axis).normalized()
		planes.append(Plane(c,c.dot(centre+n*r+axis*depth)-r*0.18))
	b.solid(planes,pose,tone,false,not b.lean,cut,-1,0.25)

## The capital from its foot at `pose`: a necking fillet, the flared
## echinus, the square abacus with its edges chamfered.
static func _capital(b: Build, pose: Transform3D) -> void:
	b.solid(RuinKit._prism(SIDES,COLUMN_R+0.08,COLUMN_R+0.08,0.0,0.12),pose,RuinKit._stone(b,1.08),true,true,[],-1,0.4)
	b.solid(RuinKit._prism(SIDES,COLUMN_R,ABACUS-0.2,0.12,0.6),pose,RuinKit._stone(b,1.0),true,true,[],-1,0.5)
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
	# The roundels along its faces (lean stone: the columns carry the carving).
	var count := 0 if b.lean else int(length/1.8)
	for s: float in [-1.0,1.0]:
		for k in range(count):
			var x := -half+length*(k+0.5)/count
			var ok := true
			for p in extra:
				if p.distance_to(Vector3(x,lower,0.0)) > -0.25: ok = false
			if not ok: continue
			_disc(b,pose,Vector3(x,lower+upper*0.5,s*(w-0.05)),Vector3(0.0,0.0,s),minf(0.14,upper*0.4),0.07,6,RuinKit._stone(b,1.12))

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
		# Settled out of level a little each (the roof's faces catch the sky
		# each its own way, not one sheet).
		var settled := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.01,0.045)*(0.5+b.weathered))
		b.solid(RuinKit._box(b,half,0.03),RuinKit._jiggle(b,Transform3D(settled,at),0.4),RuinKit._stone(b,1.0),true,true,[],-1,0.7)

## A wall at `pose` (along its X, `span` either side of its middle), from
## under the ground (FOUNDATION below its lowest ground) up to `high`:
## coursed, its head torn down weathered (never under `low`, nor near the
## opening under its head), and through its middle a pointed `opening`
## (clear width, sill over the ground there, height to the springing, the
## arc's radius as a share of the width; zero width, none) under a moulded
## ring, on a sill stone. `thick` its thickness. `crown`: an opening whose
## head stands over `high` keeps its arc, its crown lost (the wall over it
## torn to a notch from ARCH_BROKE of its rise, the ring's stones over the
## notch gone), not run up open to the top as a slot. Gives back its foot.
static func _wall(b: Build, pose: Transform3D, span: float, high: float, opening: Vector4, low: float, thick := WALL_THICK, crown := false) -> Vector3:
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
	# No room for its head under the wall's top (a slit under a tie): the
	# opening runs up open to the top, no ring, the tie its lintel.
	var lost := open and crown and head > high
	var slot := open and head > high and not lost
	var top: Callable = func(_x: float) -> float: return high
	if b.weathered > 0.2:
		var ragged := RuinKit._ruin_line(b,-span,span,lerpf(high,low,b.weathered),high,b.weathered)
		top = func(xx: float) -> float: return minf(high,maxf(float(ragged.call(xx)),head+0.7 if open and absf(xx) < w+1.0 else low))
	if lost:
		# The crown lost: over the arch the wall comes down to a notch, its
		# foot at the haunches' broken ends, rising to the wall's top past
		# the jambs (a little ragged).
		var broke := spring+RuinKit._rise(w,radius)*ARCH_BROKE+b.rng.randf_range(-0.3,0.3)
		var reach := w+1.4
		var wall_top := top
		top = func(xx: float) -> float:
			var t := clampf(absf(xx)/reach,0.0,1.0)
			return minf(float(wall_top.call(xx)),lerpf(broke,high,t*t))
	var hole := Callable()
	if open:
		hole = func(y: float) -> Vector2:
			if y < sill: return Vector2(0.0,-1.0)
			if y < spring or slot: return Vector2(0.0,w)
			return Vector2(0.0,RuinKit._arc_half(w,radius,0.32,y-spring))
	if not b.terrain.is_valid(): RuinKit._plinth_course(b,pose,span,thick*0.5)
	RuinKit._courses(b,pose,-span,span,y0+(RuinKit.PLINTH_COURSE.x if not b.terrain.is_valid() else 0.0),top,thick*0.5,hole,COURSE)
	if open:
		var stones := maxi(4,int(radius*1.4))
		if not slot: RuinKit._ring_order(b,pose,0.0,spring,w,radius,0.0,0.32,thick*0.5+0.02,stones,99,1.0,RuinKit._stone(b,1.08),0,top if lost else Callable(),true)
		b.solid(RuinKit._box(b,Vector3(w+0.3,0.08,thick*0.5+0.05)),pose*RuinKit._settle(b,Vector3(0.0,sill-0.08,0.0),0.3),RuinKit._stone(b,1.08))
	return Vector3(pose.origin.x,y0,pose.origin.z)

## The paving over a bay: big worn slabs in rough rows on the ground, left
## out round the columns' feet (outer, and the inner ones the plan stands);
## weathered, slabs gone to grass, heaved and tipped, tufts in the joints.
static func _paving(b: Build, plan: Dictionary) -> void:
	# Under the open sky the paving is sun-bleached, pale: the light pools
	# where the roof is gone.
	var bright: float = {"whole":0.95,"broken":1.12,"open":1.3}.get(plan.get("roof","whole"),0.95)
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
				b.solid(RuinKit._box(b,Vector3((x1-x)*0.5-0.03,PAVING.x*0.5,depth*0.5-0.03)),Transform3D(tilt,Vector3(mid.x,PAVING.x*0.5+lift,mid.y)),RuinKit._stone(b,bright),true,true,[],-1,0.6)
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

# --- The hall's path -------------------------------------------------------------

## A hall's plan view: its nave's middle line, straight and curved
## stretches end to end from the first mouth (at the origin, heading +X).
## Path space: x the distance along the line, y up, z across it (+Z the
## right, looking down the nave). A bay is built straight in path space
## and drawn bent (RuinKit Build `path`).
class HallPath extends RefCounted:
	## The stretches as asked: [{bays, turn}].
	var layout: Array = []
	## Each stretch: [s0, length, curvature (1/m, + turning toward -Z), its
	## start, its heading there (radians round Y)].
	var segs: Array = []
	var length := 0.0
	## Added to every distance asked (a bay's own path starts at its x 0).
	var offset := 0.0

	static func make(stretches: Array, bay: float) -> HallPath:
		var p := HallPath.new()
		p.layout = stretches.duplicate(true)
		var o := Vector3.ZERO
		var theta := 0.0
		for st: Dictionary in stretches:
			var len := float(st.get("bays",1))*bay
			var k := float(st.get("turn",0.0))/len
			p.segs.append([p.length,len,k,o,theta])
			o = p._at(p.segs[-1],len)
			theta += k*len
			p.length += len
		return p

	## Whether any stretch bends.
	func curved() -> bool:
		for seg: Array in segs:
			if absf(float(seg[2])) > 1e-6: return true
		return false

	## The same path, its distances read from `by` on.
	func shifted(by: float) -> HallPath:
		var p := HallPath.new()
		p.layout = layout
		p.segs = segs
		p.length = length
		p.offset = offset+by
		return p

	## The frame at distance `s` (X along the line, Y up, Z across); past
	## either end the line runs on straight.
	func xform(s: float) -> Transform3D:
		s += offset
		var at := 0
		for i in range(segs.size()):
			if s >= float(segs[i][0]): at = i
		var seg: Array = segs[at]
		var u := s-float(seg[0])
		var cap := u
		if at == 0 and u < 0.0: cap = 0.0
		if at == segs.size()-1 and u > float(seg[1]): cap = float(seg[1])
		var basis := Basis(Vector3.UP,float(seg[4])+float(seg[2])*cap)
		return Transform3D(basis,_at(seg,cap)+basis.x*(u-cap))

	## How long a metre of the line is `z` across it at `s` (1 straight;
	## under 1 on the inside of a curve, over it outside).
	func stretch(s: float, z: float) -> float:
		s += offset
		var at := 0
		for i in range(segs.size()):
			if s >= float(segs[i][0]): at = i
		return 1.0+float(segs[at][2])*z

	## Path space to the hall's frame.
	func point(p: Vector3) -> Vector3:
		return xform(p.x)*Vector3(0.0,p.y,p.z)

	## The line's way at `s`.
	func tangent(s: float) -> Vector3:
		return xform(s).basis.x

	## The hall's frame to path space: the stretch `p` lies along (its
	## nearest middle line), how far along and across.
	func locate(p: Vector3) -> Vector3:
		var best := Vector3(0.0,p.y,INF)
		for i in range(segs.size()):
			var seg: Array = segs[i]
			var o: Vector3 = seg[3]
			var theta: float = seg[4]
			var k: float = seg[2]
			var len: float = seg[1]
			var u := 0.0
			var z := 0.0
			var flat := Vector3(p.x,0.0,p.z)
			if absf(k) < 1e-6:
				var b := Basis(Vector3.UP,theta)
				u = (flat-o).dot(b.x)
				z = (flat-o).dot(b.z)
			else:
				var n0 := Basis(Vector3.UP,theta).z
				var c := o-n0/k
				var v := flat-c
				var r := v.length()
				var n := v/r*signf(k)
				var a := wrapf(atan2(n.x,n.z)-theta,-PI,PI)
				u = a/k
				z = signf(k)*r-1.0/k
			var ok := (u >= -0.05 or i == 0) and (u <= len+0.05 or i == segs.size()-1)
			if ok and absf(z) < absf(best.z): best = Vector3(float(seg[0])+u-offset,p.y,z)
		return best

	func _at(seg: Array, u: float) -> Vector3:
		var o: Vector3 = seg[3]
		var theta: float = seg[4]
		var k: float = seg[2]
		if absf(k) < 1e-6: return o+Basis(Vector3.UP,theta).x*u
		return o+Vector3(sin(theta+k*u)-sin(theta),0.0,cos(theta+k*u)-cos(theta))/k
