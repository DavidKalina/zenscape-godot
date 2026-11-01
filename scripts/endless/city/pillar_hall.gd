extends RefCounted
## The giants' city's pillared hall (giant_city.gd has the contract): the kit's
## weave. A forest of piers under a broken roof, laid as a line of acts that never
## repeats one bay (PLAN), each changing what you do:
##   gate     out of the sky into the dark, through a corbelled door or a slit
##   nave     whole roof in short runs, each broken by a wide door out the side
##   shafts   the roof half fallen: light in shafts, slabs tipped across the way
##   open     the roof gone: walls torn low, the bare ribs over the piers
##   slit     narrow: screens across the hall, a door or a slit in each, every
##            other bay
##   release  the piers snapping lower, the end wall's notch, and open sky
##
## Two lines through it (`lines`): the wide one down the nave, and the tight one
## down the left aisle, sideways between the staggered columns and up and down
## round what fell, in by a slit and out by a slit. The holes in the roof and the
## doors in the walls are ways out: no more than MAX_SHUT bays run without one
## (`problems`).

const Shapes = preload("res://scripts/endless/city/city_shapes.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## How far under the origin the feet go (m), past the city's DEEP: the trunk may
## stand this hall over low land.
const FEET := 100.0
const BAYS := 28
## Bays along the hall (m): 0.74 s each at speed.
const BAY := 42.0
const REACH := 625.0
const MAX_SHUT := 2
## One line a bay, from the mouth: act, then the roofs (nave, left aisle, right
## aisle: # whole, . gone, v a slab hanging by its far edge, ^ by its near edge),
## then the walls (left, right: W whole, B a wide door, L torn low, . gone).
const PLAN := [
	["gate","#","#","#","W","W"],
	["gate","#","#","#","W","W"],
	["gate","#",".","#","W","W"],
	["nave","#","#","#","W","W"],
	["nave","#","#","#","W","B"],
	["nave","#","#","#","W","W"],
	["nave","#","#","#","W","W"],
	["nave","#","#","#","B","W"],
	["nave","#","#","#","W","W"],
	["shafts",".","#","#","W","W"],
	["shafts","#","v",".","W","W"],
	["shafts",".","#","#","W","W"],
	["shafts","#",".","^","W","W"],
	["shafts",".","#",".","B","W"],
	["open",".",".",".","L","L"],
	["open",".",".",".","L","."],
	["open",".",".",".",".","L"],
	["slit","#","#","#","W","W"],
	["slit","#",".","#","W","W"],
	["slit","#","#","#","W","B"],
	["slit","#","#",".","W","W"],
	["slit","#",".","#","W","W"],
	["shafts",".",".","#","W","W"],
	["shafts","#","#",".","W","W"],
	["shafts",".","#","#","W","L"],
	["release",".","#",".","L","W"],
	["release",".",".",".","L","L"],
	["release",".",".",".",".","."],
]
## Across the hall: the nave's piers (x, half width), the aisle's wall.
const PIER_X := 40.0
const PIER_HALF := 7.0
const WALL_X := 124.0
const WALL_THICK := 12.0
const WALL_THIN := 6.0
## Heights: under the nave's roof and to its top, the aisles' the same.
const NAVE := 72.0
const NAVE_TOP := 82.0
const AISLE := 46.0
const AISLE_TOP := 54.0
## The aisles' columns: the first's x, the shaft's radius foot and top. Every other
## pair of rows is staggered by half the pitch, wider than a shaft, so no straight
## lane runs down the aisle, and the weave swings once in two bays: every bay was
## past what the stick turns at speed. TOY_WEAVE: the gap between two in a row. Static: a driver
## tries spacings.
static var toy_weave := 9.0
const COL_X := 56.0
const COL_R := 5.0
const COL_TOP := 4.2
## Lone columns down the nave in the nave act: row: x, a slalom on the wide line.
const NAVE_COLS := {4:10.0,5:10.0,6:-10.0,7:-10.0,8:10.0}
const NAVE_COL_R := 6.5
## A corbelled door: width at the floor, at the head, how tall, on how many
## courses, from what sill. The mouth's, the wide door in a side wall, a screen's.
const DOOR := [50.0,18.0,56.0,5,0.0]
const BREAK := [28.0,12.0,36.0,4,0.0]
const SCREEN_DOOR := [32.0,16.0,44.0,4,0.0]
## The slits, the tight line: toy width at the sill and at the head.
const TOY_SLIT := 7.0
const TOY_SLIT_HEAD := 4.0
const SLIT_TALL := 24.0
const SLIT_SILL := 10.0
const SLIT_COURSES := 3
## The front and the end wall, half their thickness; the front's top; the side
## mass of the end wall and the notch between.
const END_THICK := 9.0
const FRONT_FOOT := 62.0
const FRONT_TOP := 94.0
const FRONT_TIERS := 2
const FRONT_STEP := 16.0
const END_TOP := 74.0
const NOTCH_TOP := 44.0
const NOTCH := 36.0
## The rows screens stand on: row: [door's x, slit's x, slit's sill].
const SCREENS := {17:[14.0,-84.0,10.0],19:[-14.0,-70.0,10.0],21:[14.0,-78.0,18.0]}
const END_SLIT_X := -70.0
const MOUTH_SLIT_X := 70.0
## Piers snapped, near the end: row: height. Aisle columns snapped: [side, row, i].
const SNAPPED := {25:46.0,26:30.0,27:14.0}
const STUMP := 16.0
const STUMPS: Array[Vector3i] = [
	Vector3i(1,14,1),Vector3i(-1,15,1),Vector3i(1,16,0),
	Vector3i(1,26,0),Vector3i(-1,26,1),Vector3i(1,27,1),Vector3i(-1,27,0),Vector3i(-1,26,0),Vector3i(1,26,1),Vector3i(1,27,0),Vector3i(-1,27,1),Vector3i(1,26,2),Vector3i(-1,26,2),
]
## Rows of bare ribs, over the open stretch.
const RIBS: Array[int] = [15,16]
## A low edge of a slab hanging in an aisle.
const SLUMP := 22.0
const SLAB := 10.0

static func half_long() -> float:
	return BAYS*BAY*0.5

static func col_pitch() -> float:
	return WorldScale.opening(toy_weave)+COL_R*2.0

## Row `i`'s z: rows stand between bays, 0 the front and BAYS the end wall.
static func row_z(i: int) -> float:
	return (i-BAYS*0.5)*BAY

static func col_at(row: int, i: int) -> float:
	return COL_X+(i+(0.5 if (row+1)/2%2 == 1 else 0.0))*col_pitch()

static func _bay_out(i: int) -> bool:
	var p: Array = PLAN[i]
	for c: int in [1,2,3]:
		if p[c] != "#": return true
	return p[4] != "W" or p[5] != "W"

## What breaks the exits rule: empty when no more than MAX_SHUT bays lack a way
## out. The mouth's run is let be: its door is behind you.
static func problems() -> Array[String]:
	var out: Array[String] = []
	var shut := 0
	for i in BAYS:
		shut = 0 if _bay_out(i) else shut+1
		if shut > MAX_SHUT: out.append("bay %d shut too long" % i)
	return out

static func build(s: Shapes) -> void:
	s.layer = Shapes.NEAR
	var column := _column(AISLE,true)
	var stump := _column(STUMP,false)
	var pier := _pier(NAVE,true)
	var snapped := {}
	for h: float in SNAPPED.values(): snapped[h] = _pier(h,false)
	for row in range(1,BAYS):
		for side: float in [-1.0,1.0]:
			var z := row_z(row)
			s.stamp(snapped[SNAPPED[row]] if SNAPPED.has(row) else pier,Vector3(PIER_X*side,0.0,z))
			if SCREENS.has(row): continue
			var i := 0
			while col_at(row,i) < WALL_X-COL_R-2.0:
				s.stamp(stump if STUMPS.has(Vector3i(int(side),row,i)) else column,Vector3(col_at(row,i)*side,0.0,z))
				i += 1
	var lone := _column(NAVE,true,NAVE_COL_R)
	for row: int in NAVE_COLS: s.stamp(lone,Vector3(float(NAVE_COLS[row]),0.0,row_z(row)))
	for i in BAYS:
		_bay(s,i)
	_front(s)
	_end(s)
	for row: int in SCREENS: _screen(s,row)
	_ribs(s)
	_fallen(s)
	s.layer = Shapes.FAR
	_far(s)
	s.layer = Shapes.BOTH

## An aisle column: a square foot, a round shaft, a flare and a square head; or
## with no `whole`, what is left of one, its top sheared.
static func _column(tall: float, whole: bool, r := COL_R) -> Shapes:
	var c := Shapes.new()
	c.layer = Shapes.NEAR
	var foot := r+1.5
	c.box(Vector3(-foot,-FEET,-foot),Vector3(foot,3.0,foot))
	if not whole:
		c.cyl(Vector3(0.0,-1.0,0.0),r,r-0.4,tall+1.0,8)
		return c
	var top := r*0.84
	c.cyl(Vector3(0.0,-1.0,0.0),r,top,tall-5.0,8)
	c.cyl(Vector3(0.0,tall-6.0,0.0),top,r+1.5,4.0,8)
	var head := r+2.0
	c.box(Vector3(-head,tall-2.0,-head),Vector3(head,tall,head))
	return c

## A pier of the nave: square, battered, stepping out at foot and head.
static func _pier(tall: float, whole: bool) -> Shapes:
	var p := Shapes.new()
	p.layer = Shapes.NEAR
	var foot := PIER_HALF+2.0
	var thin := PIER_HALF-1.0
	p.box(Vector3(-foot,-FEET,-foot),Vector3(foot,4.0,foot))
	var top := tall-3.0 if whole else tall
	p.slope(_square(PIER_HALF),_square(lerpf(PIER_HALF,thin,top/NAVE)),4.0,top)
	if whole: p.box(Vector3(-foot,top,-foot),Vector3(foot,tall,foot))
	return p

static func _square(half: float) -> Rect2:
	return Rect2(-half,-half,half*2.0,half*2.0)

## One bay's roofs and walls.
static func _bay(s: Shapes, i: int) -> void:
	var p: Array = PLAN[i]
	var z0 := row_z(i)
	var z1 := row_z(i+1)
	var edge := PIER_X+PIER_HALF
	if p[1] == "#":
		s.box(Vector3(-edge,NAVE,z0),Vector3(edge,NAVE_TOP,z1))
		# The clerestory: the dark of a whole roof.
		for side: float in [-1.0,1.0]:
			var x := PIER_X*side
			s.box(Vector3(x-2.0,AISLE,z0),Vector3(x+2.0,NAVE,z1))
	_aisle_roof(s,str(p[2]),z0,z1,-WALL_X,-edge)
	_aisle_roof(s,str(p[3]),z0,z1,edge,WALL_X)
	_wall(s,str(p[4]),i,-1.0)
	_wall(s,str(p[5]),i,1.0)

static func _aisle_roof(s: Shapes, kind: String, z0: float, z1: float, x0: float, x1: float) -> void:
	var w := x1-x0
	match kind:
		"#":
			s.box(Vector3(x0,AISLE,z0),Vector3(x1,AISLE_TOP,z1))
		"v":
			s.slope(Rect2(x0,z0+2.0,w,SLAB),Rect2(x0,z1-SLAB,w,SLAB),SLUMP,AISLE_TOP)
		"^":
			s.slope(Rect2(x0,z1-SLAB-2.0,w,SLAB),Rect2(x0,z0,w,SLAB),SLUMP,AISLE_TOP)

## A bay's side wall: battered out from a plumb inner face.
static func _wall(s: Shapes, kind: String, i: int, side: float) -> void:
	var z0 := row_z(i)
	var z1 := row_z(i+1)
	match kind:
		"W":
			_wall_run(s,z0,z1,AISLE_TOP,side)
		"L":
			_wall_run(s,z0,z1,14.0+(i*7)%13,side)
		"B":
			var x := (WALL_X+WALL_THICK*0.5)*side
			var o := _opening((z0+z1)*0.5,BREAK)
			_pierced(s,false,x,WALL_THICK*0.5,z0,z1,AISLE_TOP,[o])

static func _wall_run(s: Shapes, z0: float, z1: float, top: float, side: float) -> void:
	var share := clampf((top+FEET)/(AISLE_TOP+FEET),0.0,1.0)
	var at_top := lerpf(WALL_THICK,WALL_THIN,share)
	if side > 0.0:
		s.slope(Rect2(WALL_X,z0,WALL_THICK,z1-z0),Rect2(WALL_X,z0,at_top,z1-z0),-FEET,top)
	else:
		s.slope(Rect2(-WALL_X-WALL_THICK,z0,WALL_THICK,z1-z0),Rect2(-WALL_X-at_top,z0,at_top,z1-z0),-FEET,top)

## An opening at `mid` of a kind ([floor, head, tall, courses, sill]).
static func _opening(mid: float, kind: Array) -> Dictionary:
	return {"mid":mid,"floor":float(kind[0]),"head":float(kind[1]),"tall":float(kind[2]),"courses":int(kind[3]),"sill":float(kind[4])}

## A slit at `mid`, sized to the plane.
static func _slit(mid: float, sill := SLIT_SILL) -> Dictionary:
	return {"mid":mid,"floor":WorldScale.opening(TOY_SLIT),"head":WorldScale.opening(TOY_SLIT_HEAD),"tall":SLIT_TALL,"courses":SLIT_COURSES,"sill":sill}

## A wall `thick` either side of `at`, from `from` to `to` along it, up to `top`,
## less its openings, each stepping in course by course to its head: a stack of
## level bands is the corbelling. `across`: the wall runs along x.
static func _pierced(s: Shapes, across: bool, at: float, thick: float, from: float, to: float, top: float, holes: Array) -> void:
	var cuts: Array[float] = [-FEET,top]
	for h: Dictionary in holes:
		for i in int(h.courses)+1:
			cuts.append(float(h.sill)+float(h.tall)*i/int(h.courses))
	cuts.sort()
	for b in cuts.size()-1:
		var y0 := cuts[b]
		var y1 := cuts[b+1]
		if y1 <= y0 or y0 >= top: continue
		var y := (y0+y1)*0.5
		var open: Array[Vector2] = []
		for h: Dictionary in holes:
			var share := (y-float(h.sill))/float(h.tall)
			if share <= 0.0 or share >= 1.0: continue
			var course := floorf(share*int(h.courses))/maxf(int(h.courses)-1.0,1.0)
			var half := lerpf(float(h.floor),float(h.head),course)*0.5
			open.append(Vector2(float(h.mid)-half,float(h.mid)+half))
		open.sort_custom(func(l: Vector2, r: Vector2) -> bool: return l.x < r.x)
		var u := from
		for o: Vector2 in open:
			if o.x > u: _run(s,across,u,o.x,at,thick,y0,y1)
			u = o.y
		if u < to: _run(s,across,u,to,at,thick,y0,y1)

static func _run(s: Shapes, across: bool, u0: float, u1: float, at: float, thick: float, y0: float, y1: float) -> void:
	if across: s.box(Vector3(u0,y0,at-thick),Vector3(u1,y1,at+thick))
	else: s.box(Vector3(at-thick,y0,u0),Vector3(at+thick,y1,u1))

static func _wide_out() -> float:
	return WALL_X+WALL_THICK

## The front: a thick wall, a door to the nave, a slit to each aisle, stepping back
## in tiers with a cornice on each.
static func _front(s: Shapes) -> void:
	var z := row_z(0)
	var w := _wide_out()
	_pierced(s,true,z,END_THICK,-w,w,FRONT_FOOT,[_opening(0.0,DOOR),_slit(-MOUTH_SLIT_X),_slit(MOUTH_SLIT_X)])
	var y := FRONT_FOOT
	for tier in FRONT_TIERS:
		var inset := FRONT_STEP*tier
		s.box(Vector3(-w+inset-3.0,y,z-END_THICK-3.0),Vector3(w-inset+3.0,y+3.0,z+END_THICK+3.0))
		y += 3.0
		var top := y+(FRONT_TOP-FRONT_FOOT)/FRONT_TIERS-3.0
		s.box(Vector3(-w+inset+FRONT_STEP,y,z-END_THICK),Vector3(w-inset-FRONT_STEP,top,z+END_THICK))
		y = top
	var inset := FRONT_STEP*FRONT_TIERS
	s.box(Vector3(-w+inset-3.0,y,z-END_THICK-3.0),Vector3(w-inset+3.0,y+3.0,z+END_THICK+3.0))

## The end wall, low in its notch: climb out over it, or take the slit.
static func _end(s: Shapes) -> void:
	var z := row_z(BAYS)
	var w := _wide_out()
	_pierced(s,true,z,END_THICK,-w,-NOTCH,END_TOP,[_slit(END_SLIT_X)])
	_pierced(s,true,z,END_THICK,NOTCH,w,END_TOP,[])
	_pierced(s,true,z,END_THICK,-NOTCH,NOTCH,NOTCH_TOP,[])

## A screen across the hall: a door in the nave and a slit in the left aisle.
static func _screen(s: Shapes, row: int) -> void:
	var at: Array = SCREENS[row]
	_pierced(s,true,row_z(row),2.5,-WALL_X,WALL_X,NAVE,[_opening(float(at[0]),SCREEN_DOOR),_slit(float(at[1]),float(at[2]))])

## The bare ribs: beams still over the piers where the roof has gone.
static func _ribs(s: Shapes) -> void:
	for row: int in RIBS:
		var z := row_z(row)
		s.box(Vector3(-PIER_X,NAVE-5.0,z-2.0),Vector3(PIER_X,NAVE,z+2.0))
		for side: float in [-1.0,1.0]:
			var a := PIER_X*side
			var b := WALL_X*side
			s.box(Vector3(minf(a,b),AISLE-4.0,z-2.0),Vector3(maxf(a,b),AISLE,z+2.0))

## What fell, each placed by hand against the two lines.
static func _fallen(s: Shapes) -> void:
	var edge := PIER_X+PIER_HALF
	var m := func(i: int) -> float: return row_z(i)+BAY*0.5
	# The tight line. A block of cornice on the aisle's floor to hop, a beam to duck.
	var z := float(m.call(4))
	s.box(Vector3(-WALL_X,-FEET,z-10.0),Vector3(-edge,22.0,z+10.0))
	z = float(m.call(7))
	s.box(Vector3(-WALL_X,24.0,z-5.0),Vector3(-edge,AISLE,z+5.0))
	# A column fallen across the open aisle, propped on the wall: over its low end
	# or under its high one.
	z = float(m.call(15))
	s.slope(Rect2(-62.0,z-5.0,10.0,10.0),Rect2(-118.0,z-5.0,10.0,10.0),-4.0,42.0)
	# The nave. A slab down across it, foot on the floor right, head on the left
	# pier: over it on the right, the sky above, or under it on the left.
	z = float(m.call(9))
	s.slope(Rect2(12.0,z-16.0,16.0,32.0),Rect2(-46.0,z-16.0,16.0,32.0),-8.0,76.0)
	# A slab hanging from the roof by its near edge, its far edge low on the right:
	# past it on the left, or under its tip.
	z = float(m.call(11))
	s.slope(Rect2(-2.0,z+BAY*0.5-12.0,48.0,12.0),Rect2(-2.0,z-BAY*0.5,48.0,12.0),14.0,78.0)
	# The same as the first the other way: foot on the left, under it on the right.
	z = float(m.call(13))
	s.slope(Rect2(-28.0,z-16.0,16.0,32.0),Rect2(30.0,z-16.0,16.0,32.0),-8.0,76.0)
	# A pier fallen across the open nave, head on the left pier.
	z = float(m.call(15))
	s.slope(Rect2(22.0,z-6.0,12.0,12.0),Rect2(-40.0,z-6.0,12.0,12.0),-4.0,50.0)
	# Over then under: a slab heaped across the nave, then one hung across it.
	z = float(m.call(22))
	s.slope(Rect2(-edge,z-20.0,edge*2.0,12.0),Rect2(-edge,z+8.0,edge*2.0,12.0),-4.0,30.0)
	z = float(m.call(24))
	s.slope(Rect2(-edge,z+8.0,edge*2.0,12.0),Rect2(-edge,z-20.0,edge*2.0,12.0),28.0,78.0)
	# The slab that ramps you up to the notch, from the floor to its top.
	z = row_z(27)
	s.slope(Rect2(-26.0,z-44.0,52.0,12.0),Rect2(-26.0,z+BAY-20.0,52.0,12.0),-4.0,36.0)

## The stand-in: the hall's masses by the runs of its roofs, the walls' stubs,
## front and end.
static func _far(s: Shapes) -> void:
	var edge := PIER_X+PIER_HALF
	var w := _wide_out()
	_far_runs(s,1,-edge,edge,NAVE_TOP)
	_far_runs(s,2,-w,-edge,AISLE_TOP)
	_far_runs(s,3,edge,w,AISLE_TOP)
	var z0 := row_z(14)
	var z1 := row_z(17)
	for side: float in [-1.0,1.0]:
		var x := WALL_X*side
		s.box(Vector3(x-WALL_THICK*0.5,-FEET,z0),Vector3(x+WALL_THICK*0.5,18.0,z1))
		var p := PIER_X*side
		s.box(Vector3(p-PIER_HALF,-FEET,z0),Vector3(p+PIER_HALF,NAVE,z1))
		s.box(Vector3(p-PIER_HALF,-FEET,row_z(25)),Vector3(p+PIER_HALF,30.0,row_z(BAYS)))
		s.box(Vector3(x-WALL_THICK*0.5,-FEET,row_z(25)),Vector3(x+WALL_THICK*0.5,18.0,row_z(BAYS)))
	var f := row_z(0)
	s.box(Vector3(-w,-FEET,f-END_THICK),Vector3(w,FRONT_FOOT,f+END_THICK))
	s.box(Vector3(-w+FRONT_STEP,FRONT_FOOT,f-END_THICK),Vector3(w-FRONT_STEP,FRONT_TOP,f+END_THICK))
	var e := row_z(BAYS)
	s.box(Vector3(-w,-FEET,e-END_THICK),Vector3(-NOTCH,END_TOP,e+END_THICK))
	s.box(Vector3(NOTCH,-FEET,e-END_THICK),Vector3(w,END_TOP,e+END_THICK))
	s.box(Vector3(-NOTCH,-FEET,e-END_THICK),Vector3(NOTCH,NOTCH_TOP,e+END_THICK))

## A mass over each run of bays whose roof in `field` of PLAN stands.
static func _far_runs(s: Shapes, field: int, x0: float, x1: float, top: float) -> void:
	var from := -1
	for i in BAYS+1:
		var whole: bool = i < BAYS and PLAN[i][field] == "#"
		if whole and from < 0: from = i
		if not whole and from >= 0:
			s.box(Vector3(x0,-FEET,row_z(from)),Vector3(x1,top,row_z(i)))
			from = -1

## The lines, in the piece's frame, near end to far: a pilot's path, not a rail;
## the trunk's end-to-end flight reads them. "up" leaves the wide line by the hole
## over the first slab.
static func lines() -> Dictionary:
	var tight: Array[Vector3] = [Vector3(-MOUTH_SLIT_X,20.0,row_z(0)-140.0)]
	for t: Vector3 in TIGHT:
		tight.append(Vector3(t.x,t.y,row_z(int(t.z))+(t.z-floorf(t.z))*BAY))
	tight.append(Vector3(END_SLIT_X,15.0,row_z(BAYS)+140.0))
	var wide: Array[Vector3] = [Vector3(0.0,22.0,row_z(0)-140.0)]
	for t: Vector3 in WIDE:
		wide.append(Vector3(t.x,t.y,row_z(int(t.z))+(t.z-floorf(t.z))*BAY))
	wide.append(Vector3(0.0,62.0,row_z(BAYS)+160.0))
	var up: Array[Vector3] = wide.slice(0,8)
	up.append(Vector3(14.0,44.0,row_z(9)+6.0))
	up.append(Vector3(14.0,130.0,row_z(10)+60.0))
	up.append(Vector3(14.0,160.0,row_z(14)))
	return {"wide":wide,"tight":tight,"up":up}

## The tight line at each row: (x, height, row), by hand.
const TIGHT: Array[Vector3] = [
	Vector3(-70,16,0),Vector3(-70,18,0.3),Vector3(-84,24,1),Vector3(-84,30,2),Vector3(-70,33,3),Vector3(-70,33,4),
	Vector3(-84,32,5),Vector3(-84,26,6),Vector3(-70,14,7),Vector3(-70,14,8),Vector3(-84,14,9),
	Vector3(-84,14,10),Vector3(-70,18,11),Vector3(-70,22,12),Vector3(-84,26,13),Vector3(-84,28,14),
	Vector3(-70,30,15),Vector3(-70,24,16),Vector3(-84,15,17),Vector3(-84,15,18),Vector3(-70,15,19),
	Vector3(-73,20,20),Vector3(-78,25,20.8),Vector3(-78,26,21),Vector3(-84,28,22),Vector3(-70,28,23),Vector3(-70,26,24),
	Vector3(-84,22,25),Vector3(-84,20,26),Vector3(-70,16,27),Vector3(-70,15,28),
]
## The wide line: (x, height, row and a half).
const WIDE: Array[Vector3] = [
	Vector3(0,24,0),Vector3(0,24,2.5),Vector3(-13,26,4),Vector3(-13,26,5),Vector3(13,26,6),Vector3(13,26,7),Vector3(-13,26,8),
	Vector3(14,50,9.5),Vector3(0,34,10.5),Vector3(-22,26,11.6),Vector3(-16,24,12.1),Vector3(20,20,13.5),Vector3(6,40,15.5),
	Vector3(14,26,17),Vector3(-14,26,19),Vector3(14,26,21),Vector3(0,46,22.5),Vector3(0,44,23.1),Vector3(0,17,24.5),Vector3(0,17,25.1),Vector3(0,36,26.5),Vector3(0,56,28),
]
