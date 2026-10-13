extends RefCounted
## The ruin kit's aqueduct (scripts/ruin_kit.gd, the same stone, wear and
## growth): the long arcades that once carried water across the sea between
## the islands, in the abbey's gothic: tall coursed piers on footings with
## cutwaters, pointed arches of two chamfered orders under a hood mould,
## buttress strips up the piers, a corbel table under the deck, and on top
## the channel between low parapets, still carrying water. A flight run
## through the arches and a walk along the channel on top.
##
## Modular: a span runs SPAN along X from one pier's middle (x -SPAN/2) to
## the next's (+SPAN/2), front toward +Z as every piece. Spans set end to
## end SPAN apart make a run; `piers` says which ends a span stands its own
## pier at (the next span's left pier is this one's right), and `run`
## lays a whole one out. The water runs toward +X, so a run starts at its
## head (`aqueduct_end`, its abutment the first span's left support).
##
## Where a span is broken its channel is snapped off in mid-air and the
## water spills off the snapped end as a thin fall into a pool among the
## rubble (the waterfalls' strand, shaders/flow_fall.gdshader, laid as the
## sky islets lay theirs, scripts/sky_islets.gd `curtain`): crafted, not
## the live water's. Spans past a break are dry. The channel's water is the
## islets' small pond water (shaders/islet_pond.gdshader).
##
## Contract for a layout pass (the landforms to come, aqueducts striding
## over real terrain between the halls):
## - `ground`: an optional Callable(x, z) -> y in the piece's (or run's)
##   frame; flat y 0 if absent. The deck stays level at DECK; each pier
##   grows down to meet the ground and FOOTING below it, so a run across a
##   valley has tall piers in the middle and short ones at the ends, and a
##   pier the ground stands over is buried in it. The head's abutment steps
##   down the slope into the hillside it butts against (its treads under
##   the ground are left out).
## - Metadata on each piece and on a run, in its frame: "bounds" AABB;
##   "feet" Array of Vector3 (each pier's foot, under the ground there);
##   "walk" Array of {from, to, width} (the channel); "corridors" Array of
##   AABB (under each arch, THREAD wide, from over the ground there to over
##   the springing: keep terrain out of them); "ends" Array of {at,
##   heading, height, kind} (the channel's two ends at the deck: "channel"
##   where another span or a hall chains on, "abutment" where the head
##   butts into the land).
## - Cost: a run is merged into one mesh and one body (RuinKit `merge`;
##   water and the spill stay their own); RuinKit `set_detail` thins its
##   growth and scatter.
##   ./run-ruin-kit.command  (F2 frames the aqueduct)

const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build
const POND_SHADER = preload("res://shaders/islet_pond.gdshader")

const PIECES := RuinKit.AQUEDUCT_PIECES

# --- Scale -------------------------------------------------------------------

## The module: pier middle to pier middle (m). A run's spans stand SPAN
## apart: a pier's width and the clear span, CLEAR, an opening (scripts/
## world_scale.gd `opening`) on the toy era's 4.7 (3.4 spans): 8.46 at the
## defaults, SPAN 10.16. No longer tied to THREAD. The arch is equilateral:
## its crown stands SPRING + CLEAR*0.866.
## A pier: its width along the run and depth across it (m).
const PIER := Vector2(1.7,2.8)
const TOY_CLEAR := 4.7
static var CLEAR: float = WorldScale.opening(TOY_CLEAR)
static var SPAN: float = CLEAR+PIER.x
const SPRING := 5.2
## How much higher the crowns stand than the toy era's (the arch's rise on
## its wider span): the decks and the gallery course go up by as much, so
## the spandrels over the arches keep their toy depth (1.1 m at 10.8).
static var GROW: float = (CLEAR-TOY_CLEAR)*0.866
## The deck: the channel's floor top (m: 10.8 in the toy era, 14.06 at the
## defaults), the floor slabs' thickness, the whole deck's width (the
## channel and both parapets).
static var DECK: float = 10.8+GROW
const FLOOR := 0.4
const DECK_WIDTH := 2.3
## The channel: its clear width (a walk along it: TOP_ROOM and more), the
## parapets' thickness and height over the channel floor (under STEP_UP:
## stepped over, as a walker crosses out onto them), the water's depth.
const CHANNEL := 1.5
const PARAPET := Vector2(0.4,0.42)
const WATER := 0.16
## The cutwaters on the piers' faces: how far their prow stands out and
## their height (capped by a sloped stone).
const CUTWATER := Vector2(0.75,2.6)
## The impost's height at the springing and its reach past the pier.
const IMPOST := Vector2(0.32,0.14)
## The buttress strip up each pier's faces over the springing: its width.
const STRIP := 1.05
## The two-tier span: the lower arcade's springing, the gallery course's top
## between the tiers (a walkable ledge along it), the upper piers (width,
## depth), the upper springing over the course, the upper arch's radius as
## a share of its clear span (under 1: a lower, drop arch) and its deck.
## The lower springing: 3.0, or low enough that the lower arch (CLEAR
## wide, equilateral) crowns under the course (2.76 at plane 2).
## The course and the upper deck go up as the arches do (GROW: 8.4 and
## 14.8 in the toy era); the upper deck keeps its spandrel over the upper
## arch's crown, which rises on its wider span too.
static var MID: float = 8.4+GROW
static var LOWER_SPRING: float = minf(3.0,MID-FLOOR-CLEAR*0.866-RuinKit.ORDER*2.0-0.1)
const UPPER_PIER := Vector2(1.3,2.5)
const UPPER_RISE := 1.2
const UPPER_PITCH := 0.78
static var DECK_HIGH: float = MID+(14.8-8.4)+_upper_rise(SPAN)-_upper_rise(TOY_CLEAR+PIER.x)

## The upper arch's rise on a span `span` (pier middle to pier middle).
static func _upper_rise(span: float) -> float:
	var h := (span-UPPER_PIER.x)*0.5
	return RuinKit._rise(h,h*2.0*UPPER_PITCH)
## The head: the abutment's treads (each SET_OFF or under over the next,
## each tread deep enough to stand on: the way up to the channel), the
## cistern's clear size (x, z) and its lip over the deck.
const ABUTMENT_TREAD := 0.8
const CISTERN := Vector2(2.4,2.6)
const CISTERN_LIP := 0.44
## How far the aqueduct's stones have moved out of true, weathered, as a
## share of the abbey's (RuinKit Build `settle`): heavy coursed arcades
## stay in line, so a ruined run reads settled, not shaken.
const SETTLE := 0.35
## How far a pier's footing reaches below the ground under it (m).
const FOOTING := 0.6
## The pier stump: its height range (m), stepping stones in the sea.
const STUMP := Vector2(1.1,2.3)

# --- The pieces -----------------------------------------------------------------

static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"aqueduct_span": return span(seed_value,weathered)
		"aqueduct_two_tier": return two_tier(seed_value,weathered)
		"aqueduct_broken": return broken(seed_value,weathered)
		"aqueduct_stump": return stump(seed_value,weathered)
		"aqueduct_end": return head(seed_value,weathered)
	return null

## 1. A span: a pier at either end (`piers`: 1 the left, 2 the right, 3
## both), a pointed arch between them, the spandrels coursed up to the deck,
## the channel on top between its parapets, carrying water if `wet`.
## Weathered: the parapets broken and gone in runs, the hood mould and the
## outer order gapped, cutwater caps and corbels broken, moss over the deck,
## ivy hanging off it and from the arch; the channel still whole.
static func span(seed_value: int, weathered := 0.0, piers := 3, wet := true, ground := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"AqueductSpan")
	b.settle = SETTLE
	b.terrain = ground
	_arcade(b,0.0,SPRING,DECK-FLOOR,PIER,CLEAR*0.5,1.0,piers,CUTWATER.y,true,true)
	_deck(b,-SPAN*0.5,SPAN*0.5,DECK,Callable())
	if wet: _water(b.root,-SPAN*0.5,SPAN*0.5,DECK+WATER)
	_hang(b,DECK)
	for side: float in [-1.0,1.0]:
		if piers & (1 if side < 0.0 else 2):
			RuinKit._drift(b,Vector3(side*SPAN*0.5+b.rng.randf_range(-0.4,0.4),0.0,PIER.y*0.5+CUTWATER.x+0.4),1.0,int(weathered*4.0))
	RuinKit._rubble(b,SPAN*0.5,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	b.root.set_meta("span",SPAN)
	return _finish(b,DECK,piers,[[CLEAR*0.5,SPRING]])

## 2. A two-tier span for a deep gap: a lower arcade on cutwatered piers, a
## gallery course over it (a ledge to walk along), and an upper arcade of
## lighter piers and drop arches carrying the channel. Weathered as a span,
## the gallery course broken in places.
static func two_tier(seed_value: int, weathered := 0.0, piers := 3, wet := true, ground := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"AqueductTwoTier")
	b.settle = SETTLE
	b.terrain = ground
	_arcade(b,0.0,LOWER_SPRING,MID-FLOOR,PIER,CLEAR*0.5,1.0,piers,CUTWATER.y,true,true)
	# The gallery course: long slabs standing out either side, a ledge.
	var x := -SPAN*0.5
	while x < SPAN*0.5-0.05:
		var x1 := minf(x+b.rng.randf_range(1.0,1.6),SPAN*0.5)
		if SPAN*0.5-x1 < 0.5: x1 = SPAN*0.5
		if weathered < 0.3 or b.rng.randf() > 0.3*weathered:
			var half := Vector3((x1-x)*0.5-0.008,FLOOR*0.5,DECK_WIDTH*0.5+0.22)
			var planes := RuinKit._box(b,half)
			for s: float in [-1.0,1.0]:
				var n := Vector3(0.0,-0.8,s).normalized()
				planes.append(Plane(n,n.dot(Vector3(0.0,-half.y,s*(half.z-0.1)))))
			b.solid(planes,RuinKit._settle(b,Vector3((x+x1)*0.5,MID-FLOOR*0.5,0.0),0.5),RuinKit._stone(b,1.05))
		x = x1
	var upper_half := (SPAN-UPPER_PIER.x)*0.5
	_arcade(b,MID,MID+UPPER_RISE,DECK_HIGH-FLOOR,UPPER_PIER,upper_half,UPPER_PITCH,piers,0.0,false)
	_deck(b,-SPAN*0.5,SPAN*0.5,DECK_HIGH,Callable())
	if wet: _water(b.root,-SPAN*0.5,SPAN*0.5,DECK_HIGH+WATER)
	_hang(b,DECK_HIGH)
	_hang(b,MID)
	RuinKit._drift(b,Vector3(-SPAN*0.5+0.6,0.0,PIER.y*0.5+CUTWATER.x+0.5),1.0,int(weathered*4.0))
	RuinKit._rubble(b,SPAN*0.5,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	b.root.set_meta("span",SPAN)
	return _finish(b,DECK_HIGH,piers,[[CLEAR*0.5,LOWER_SPRING],[upper_half,MID+UPPER_RISE]])

## 3. A broken span: its left pier standing with the arch's first stones
## and a stub of spandrel and channel snapped off in mid-air past it, the
## water spilling off the snapped end as a thin fall into a pool among the
## rubble; the arch's right springers and a ragged stub over the next pier.
## `right`: "stump", the right pier fallen to a broken stump (a piece on its
## own); "pier", standing; "none", another span's pier stands there (in a
## run). Weathered, the stub is shorter and the rubble deeper.
static func broken(seed_value: int, weathered := 0.0, left := true, right := "stump", wet := true, ground := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"AqueductBroken")
	b.settle = SETTLE
	b.terrain = ground
	var hx := PIER.x*0.5
	var deck_foot := DECK-FLOOR
	var h := CLEAR*0.5
	var radius := CLEAR
	var d := DECK_WIDTH*0.5-0.06
	# Where the walling stands full height to, and the channel's snapped end.
	var full := -SPAN*0.5+hx+lerpf(1.3,0.6,weathered)+b.rng.randf_range(-0.2,0.2)
	var snap := full+b.rng.randf_range(0.55,0.9)
	var right_side := right != "stump"
	var right_from := SPAN*0.5-hx-b.rng.randf_range(0.2,0.5)
	var right_high := deck_foot-b.rng.randf_range(1.6,2.6)
	var ragged := RuinKit._ruin_line(b,-SPAN*0.5,SPAN*0.5,0.0,1.0,1.0)
	var top := func(x: float) -> float:
		var l := deck_foot if x < full else deck_foot-(x-full)*2.4
		var r := -INF
		if right_side: r = right_high if x > right_from else right_high-(right_from-x)*2.4
		return maxf(l,r)+((float(ragged.call(x))-0.5)*0.5 if x > full else 0.0)
	var lg := _pier_foot(b,-SPAN*0.5)
	var rg := _pier_foot(b,SPAN*0.5)
	if left: _pier(b,-SPAN*0.5,lg,SPRING,deck_foot,PIER,CUTWATER.y+_sunk(b))
	if right == "pier": _pier(b,SPAN*0.5,rg,SPRING,right_high,PIER,CUTWATER.y+_sunk(b))
	elif right == "stump": _pier(b,SPAN*0.5,rg,SPRING,0.0,PIER,CUTWATER.y+_sunk(b),b.floor_at(SPAN*0.5,0.0)+b.rng.randf_range(STUMP.x,STUMP.y)+0.6)
	# The arch's stones that still stand: the left side's first few, the
	# right's springers.
	var keep_left := lerpf(-h+2.1,-h+1.3,weathered)
	var keep_right := h-0.5
	var stands := func(x: float) -> float:
		if x < keep_left: return 99.0
		if right_side and x > keep_right: return 99.0
		return -99.0
	RuinKit._arch_ring(b,Transform3D.IDENTITY,0.0,SPRING,h,radius,d,true,0,1.0,stands)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < SPRING: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(h,radius,outer-radius,y-SPRING))
	RuinKit._courses(b,Transform3D.IDENTITY,-SPAN*0.5,SPAN*0.5,SPRING,top,d-0.04,hole,0.55)
	# The channel: whole over the standing walling, snapped past it.
	_deck(b,-SPAN*0.5,snap,DECK,Callable(),true)
	if right_side:
		var stub_from := SPAN*0.5-hx-b.rng.randf_range(0.3,0.7)
		# The stub over the next pier, its channel floor ragged and low.
		b.solid(RuinKit._box(b,Vector3((SPAN*0.5-stub_from)*0.5,FLOOR*0.5,DECK_WIDTH*0.5)),RuinKit._settle(b,Vector3((stub_from+SPAN*0.5)*0.5,right_high+FLOOR*0.5,0.0),0.6),RuinKit._stone(b),true,true,RuinKit._break(b,FLOOR,1.0,0.6,FLOOR*0.5))
	if wet:
		_water(b.root,-SPAN*0.5,snap-0.12,DECK+WATER)
		var lip := Vector3(snap-0.1,DECK+WATER-0.02,0.0)
		var pool := _spill(b.root,lip,Vector3.RIGHT,seed_value,b.floor_at(lip.x+1.8,0.0))
		_pool(b,pool,1.25)
	# The fallen: a deep drift under the gap, a length of channel lying in
	# it, voussoirs and coping strewn.
	var heap := Vector3(b.rng.randf_range(-1.4,-0.6),0.0,b.rng.randf_range(-0.6,0.2))
	RuinKit._drift(b,heap,1.9,10+int(weathered*8.0))
	var lie := Basis(Vector3.UP,b.rng.randf_range(-0.5,0.5))*Basis(Vector3.BACK,b.rng.randf_range(0.25,0.45))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.2,0.2))
	var at := heap+Vector3(b.rng.randf_range(-0.6,0.2),0.75,b.rng.randf_range(0.8,1.3))
	b.solid(RuinKit._box(b,Vector3(0.75,FLOOR*0.5,DECK_WIDTH*0.5)),Transform3D(lie,at),RuinKit._stone(b,1.02),true,true,RuinKit._break(b,FLOOR,1.0,0.5,FLOOR*0.5))
	b.solid(RuinKit._box(b,Vector3(0.6,PARAPET.y*0.5,PARAPET.x*0.5)),Transform3D(lie,at+lie*Vector3(0.0,FLOOR*0.5+PARAPET.y*0.5,DECK_WIDTH*0.5-PARAPET.x*0.5)),RuinKit._stone(b,1.06))
	for i in range(3+int(weathered*3.0)):
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,b.rng.randf_range(-0.6,0.6))
		var stone := Vector3(b.rng.randf_range(0.3,0.42),b.rng.randf_range(0.22,0.3),d*b.rng.randf_range(0.45,0.8))
		b.solid(RuinKit._box(b,stone),Transform3D(tumble,heap+Vector3(b.rng.randf_range(-2.4,2.4),stone.y*0.8,b.rng.randf_range(-2.0,2.0))),RuinKit._stone(b,1.02),true,true,[],-1,1.5)
	for i in range(3+int(weathered*5.0)):
		var spot := heap+Vector3(b.rng.randf_range(-2.8,2.8),0.0,b.rng.randf_range(-1.8,2.2))
		spot.y = b.floor_at(spot.x,spot.z)
		b.tuft(spot,0.45)
	_hang(b,DECK,full)
	RuinKit._rubble(b,SPAN*0.5,4+int(round(weathered*b.rng.randf_range(3.0,6.0))))
	b.root.set_meta("span",SPAN)
	var node := _finish(b,DECK,(1 if left else 0)|(2 if right != "none" else 0),[])
	# The channel breaks off at `snap`: its far end is no connection.
	node.set_meta("ends",[(node.get_meta("ends") as Array)[0]])
	node.set_meta("walk",[{"from":Vector3(-SPAN*0.5,DECK,0.0),"to":Vector3(snap,DECK,0.0),"width":CHANNEL}])
	return node

## 4. A pier stump: a pier broken off STUMP high, standing alone in the
## sea or the grass, its cutwaters still on it, its top a course of whole
## stones to stand on: a stepping stone (one jump from the next, or up out
## of the water). Weathered, lower, its head more broken, mossed over.
static func stump(seed_value: int, weathered := 0.0, ground := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"AqueductStump")
	b.settle = SETTLE
	b.terrain = ground
	var height := lerpf(STUMP.y,STUMP.x,weathered*b.rng.randf_range(0.5,1.0))
	if weathered < 0.05: height = STUMP.y
	var g := _pier_foot(b,0.0)
	height += b.floor_at(0.0,0.0)
	_pier(b,0.0,g,SPRING,0.0,PIER,CUTWATER.y+_sunk(b),height)
	RuinKit._drift(b,Vector3(b.rng.randf_range(-0.8,0.8),0.0,PIER.y*0.5+0.8),1.1,1+int(weathered*4.0))
	for i in range(int(2+weathered*4.0)):
		var a := b.rng.randf()*TAU
		b.tuft(Vector3(cos(a)*1.4,b.floor_at(cos(a)*1.4,sin(a)*1.9),sin(a)*1.9),0.4)
	RuinKit._rubble(b,1.8,int(round(weathered*b.rng.randf_range(2.0,5.0))))
	b.root.set_meta("height",height)
	var node := _finish(b,height,0,[])
	node.set_meta("feet",[Vector3(0.0,g,0.0)])
	node.set_meta("ends",[])
	node.set_meta("walk",[{"from":Vector3(-0.5,height,0.0),"to":Vector3(0.5,height,0.0),"width":PIER.x}])
	return node

## A lone pillar for a perch (the crossing yard's horn perches,
## studies/crossings/crossing_viaduct.gd): a pier `height` m tall, `size`
## across (x) and along (z), coursed as a span's, under its impost, whose
## top at `height` is a flat stone to stand on (a true hull). Its foot, at
## y 0, is broken off over the void: a ragged course hangs under it, ivy
## trailing from it. Not in PIECES (it hangs on nothing).
static func pillar(seed_value: int, weathered: float, height: float, size: Vector2) -> Node3D:
	var b := Build.new(seed_value,weathered,"AqueductPillar")
	b.settle = SETTLE
	# The void under it, for the trailing ivy's room.
	b.terrain = func(_x: float, _z: float) -> float: return -8.0
	_pier(b,0.0,0.0,height,0.0,size,0.0,INF,false)
	RuinKit._walk_box(b,Transform3D.IDENTITY,size.x*0.5,height-0.3,height,size.y*0.5,size.y*0.5)
	# The broken foot: what's left of the next course down, ragged.
	var hx := size.x*0.5
	var hz := size.y*0.5
	for i in range(4):
		var cx := (float(i%2)-0.5)*hx
		var cz := ((1.0 if i >= 2 else 0.0)-0.5)*hz
		var deep := b.rng.randf_range(0.3,0.9)
		var m := Vector3(b.rng.randf_range(-0.8,0.8),-1.0,b.rng.randf_range(-0.8,0.8)).normalized()
		var cut: Array[Plane] = [Plane(m,m.dot(Vector3(0.0,-deep*0.5*b.rng.randf_range(0.2,0.9),0.0)))]
		b.solid(RuinKit._box(b,Vector3(hx*0.5-0.01,deep*0.5,hz*0.5-0.01)),RuinKit._settle(b,Vector3(cx,-deep*0.5,cz),0.5),RuinKit._stone(b,0.94),true,true,cut)
		b.hang(Vector3(cx,0.0,cz),b.rng.randf_range(1.2,3.0)*(0.4+weathered),true,0.0)
	var node := b.finish()
	node.set_meta("height",height)
	return node

## 5. The head: where the channel meets the land. A stepped abutment of
## coursed walling (`raised`: its treads each a jump over the last, the way
## up from the ground to the channel; otherwise the land stands at the
## channel's floor, y 0, and only the head is built), on it a cistern
## behind a low lip, full, and over the channel's mouth a small pointed
## arch under a gablet. Its +X face (x 0) is where the first span's left
## end meets it: the abutment stands in for that span's left pier.
## Weathered, the gablet and lip broken, ivy down the abutment.
static func head(seed_value: int, weathered := 0.0, raised := true, wet := true, ground := Callable()) -> Node3D:
	var b := Build.new(seed_value,weathered,"AqueductEnd")
	b.drop_floating = true
	b.settle = SETTLE
	b.terrain = ground
	var feet: Array = []
	var hx := PIER.x*0.5
	var hz := CISTERN.y*0.5+0.5
	var deck_foot := DECK-FLOOR
	var back := -(CISTERN.x+0.45+0.6)
	if not raised: b.frame = Transform3D(Basis.IDENTITY,Vector3(0.0,-DECK,0.0))
	if raised:
		# The stepped abutment: the full height over the cistern, then treads
		# stepping down toward -X, each SET_OFF or under.
		var tops: Array[float] = []
		var y := deck_foot
		while y > RuinKit.GRAB_TOP-0.2:
			tops.append(y)
			y -= RuinKit.SET_OFF
		tops.append(maxf(0.8,y))
		var x1 := hx
		for i in range(tops.size()):
			var x0 := back if i == 0 else x1-ABUTMENT_TREAD
			var high: float = tops[i]
			# On the ground, each section from under its lowest ground; a
			# tread the hillside stands over is buried and left out.
			var low := minf(minf(b.floor_at(x0,-hz),b.floor_at(x0,hz)),minf(b.floor_at(x1,-hz),b.floor_at(x1,hz)))
			var crest := maxf(maxf(b.floor_at(x0,-hz),b.floor_at(x0,hz)),maxf(b.floor_at(x1,-hz),b.floor_at(x1,hz)))
			if b.terrain.is_valid() and crest > high+0.3 and i > 0:
				x1 = x0
				continue
			var y0 := (low-FOOTING) if b.terrain.is_valid() else RuinKit.PLINTH_COURSE.x
			var line := RuinKit._worn_top(b,x0,x1,high,0.3) if i > 0 else func(_x: float) -> float: return high
			if not b.terrain.is_valid(): RuinKit._plinth_course(b,Transform3D(Basis.IDENTITY,Vector3((x0+x1)*0.5,0.0,0.0)),(x1-x0)*0.5,hz-0.1)
			RuinKit._courses(b,Transform3D.IDENTITY,x0,x1,y0,line,hz-0.1-0.03*i,Callable(),0.55)
			feet.append(Vector3((x0+x1)*0.5,y0 if b.terrain.is_valid() else 0.0,0.0))
			if i > 0:
				# A tread's coping, paler, so the way up reads.
				var t := RuinKit._box(b,Vector3((x1-x0)*0.5+0.02,0.09,hz-0.08))
				b.solid(t,RuinKit._settle(b,Vector3((x0+x1)*0.5,high+0.0,0.0),0.4),RuinKit._stone(b,1.1))
			x1 = x0
		RuinKit._drift(b,Vector3(x1-0.4,0.0,1.4),1.2,1+int(weathered*5.0))
	# The cistern's floor and the channel's start, on the abutment.
	_deck(b,back+0.3,0.0,DECK,Callable(),false,hz-0.15)
	# The cistern's lip on three sides, its front wall either side of the
	# mouth, the arch over the mouth, the channel's parapets on from it.
	var cx0 := back+0.35
	var mouth := -0.5
	for s: float in [-1.0,1.0]:
		_parapet_run(b,cx0,mouth-0.22,s*(CISTERN.y*0.5+0.2),DECK,CISTERN_LIP,0.4)
		var front := Vector3(0.22,CISTERN_LIP*0.5,(CISTERN.y*0.5+0.4-(CHANNEL*0.5+0.44))*0.5)
		b.solid(RuinKit._box(b,front),RuinKit._settle(b,Vector3(mouth,DECK+front.y,s*(CHANNEL*0.5+0.44+front.z)),0.4),RuinKit._stone(b,1.04))
		_parapet_run(b,mouth+0.3,0.0,s*(CHANNEL*0.5+PARAPET.x*0.5),DECK,PARAPET.y,PARAPET.x)
	_parapet_run_z(b,cx0+0.2,-(CISTERN.y*0.5+0.4),CISTERN.y*0.5+0.4,DECK,CISTERN_LIP,0.4)
	_mouth(b,mouth,DECK)
	if wet:
		_water(b.root,cx0+0.4,mouth,DECK+WATER,CISTERN.y*0.5,b.frame,"Cistern")
		_water(b.root,mouth-0.1,0.0,DECK+WATER,CHANNEL*0.5-0.01,b.frame)
	_hang(b,DECK,back+0.3)
	for i in range(int(1+weathered*4.0)):
		b.tuft(Vector3(b.rng.randf_range(back,0.0),DECK,b.rng.randf_range(-1.0,1.0)*CISTERN.y*0.5),0.3,4)
	RuinKit._rubble(b,3.4,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	var node := b.finish()
	var lift := 0.0 if raised else -DECK
	node.set_meta("bounds",(node.get_node("Mesh") as MeshInstance3D).mesh.get_aabb())
	node.set_meta("feet",feet)
	node.set_meta("corridors",[])
	node.set_meta("walk",[{"from":Vector3(back+0.4,DECK+lift,0.0),"to":Vector3(0.0,DECK+lift,0.0),"width":CHANNEL}])
	node.set_meta("ends",[{"at":Vector3(back,DECK+lift,0.0),"heading":Vector3.LEFT,"height":DECK+lift,"kind":"abutment"},{"at":Vector3(0.0,DECK+lift,0.0),"heading":Vector3.RIGHT,"height":DECK+lift,"kind":"channel"}])
	return node

## A run: the head at x 0 (unless `with_head` is off), then `count` spans
## SPAN apart along +X, the one at `break_at` broken (-1, none) and those
## past it dry; each span `weathered` give or take. The spans are its
## children, so later code can lay one between two islands.
static func run(seed_value: int, weathered: float, count: int, break_at := -1, with_head := true, ground := Callable(), merged := true) -> Node3D:
	var root := Node3D.new()
	root.name = "AqueductRun"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"aqueduct run"])
	var shift := func(dx: float) -> Callable:
		if not ground.is_valid(): return Callable()
		return func(x: float, z: float) -> float: return float(ground.call(x+dx,z))
	if with_head: root.add_child(head(seed_value,clampf(weathered+rng.randf_range(-0.1,0.1),0.0,1.0),true,true,shift.call(0.0)))
	var wet := true
	for i in range(count):
		var w := clampf(weathered+rng.randf_range(-0.15,0.15),0.0,1.0)
		var x := SPAN*0.5+SPAN*i
		var node: Node3D
		if i == break_at:
			node = broken(seed_value+i,w,i == 0 and not with_head,"none" if i < count-1 else "stump",wet,shift.call(x))
			wet = false
		else:
			# Each span stands its right pier; its left is the last span's
			# (or the head's abutment), but past a break it stands its own.
			var piers := 2
			if (i == 0 and not with_head) or (break_at >= 0 and i == break_at+1): piers |= 1
			node = span(seed_value+i,w,piers,wet,shift.call(x))
		node.position = Vector3(x,0.0,0.0)
		root.add_child(node)
	# The run's metadata: its children's, in its frame.
	var feet: Array = []
	var corridors: Array = []
	for child in root.get_children():
		var at: Vector3 = (child as Node3D).position
		for p: Vector3 in child.get_meta("feet",[]): feet.append(p+at)
		for c: AABB in child.get_meta("corridors",[]): corridors.append(AABB(c.position+at,c.size))
	var length := SPAN*count
	var start := {"at":Vector3(0.0,DECK,0.0),"heading":Vector3.LEFT,"height":DECK,"kind":"channel"}
	if with_head: start = (root.get_child(0).get_meta("ends") as Array)[0]
	var ends: Array = [start]
	if break_at < 0 or break_at < count-1: ends.append({"at":Vector3(length,DECK,0.0),"heading":Vector3.RIGHT,"height":DECK,"kind":"channel"})
	root.set_meta("feet",feet)
	root.set_meta("corridors",corridors)
	root.set_meta("ends",ends)
	root.set_meta("walk",[{"from":(start.at as Vector3),"to":Vector3(length,DECK,0.0),"width":CHANNEL}])
	root.set_meta("length",length)
	if merged: RuinKit.merge(root)
	var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
	root.set_meta("bounds",mesh.mesh.get_aabb() if mesh != null else AABB())
	return root

# --- Parts ----------------------------------------------------------------------

## An arcade of one span from `y0`: its piers (`piers` mask) `size`, the
## pointed arch of clear half span `h` and radius `pitch` of the clear span
## springing at `spring`, the spandrels coursed up to `wall_top`;
## `cutwater` the piers' cutwaters' height (0, none); `impost_strips`
## the buttress strips up the piers' faces.
static func _arcade(b: Build, y0: float, spring: float, wall_top: float, size: Vector2, h: float, pitch: float, piers: int, cutwater: float, strips := true, on_ground := false) -> void:
	var d := DECK_WIDTH*0.5-0.06
	for side: float in [-1.0,1.0]:
		if piers & (1 if side < 0.0 else 2):
			# On the ground, a pier grows down to it (its cutwaters stand as
			# high over the ground as ever).
			var foot := _pier_foot(b,side*SPAN*0.5) if on_ground else y0
			_pier(b,side*SPAN*0.5,foot,spring,wall_top if strips else 0.0,size,cutwater+_sunk(b) if on_ground and cutwater > 0.0 else cutwater)
	var radius := h*2.0*pitch
	var lost_side := -1.0 if b.rng.randf() < 0.5 else 1.0
	RuinKit._arch_ring(b,Transform3D.IDENTITY,0.0,spring,h,radius,d,true,0,lost_side)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < spring: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(h,radius,outer-radius,y-spring))
	var top := func(_x: float) -> float: return wall_top
	RuinKit._courses(b,Transform3D.IDENTITY,-SPAN*0.5,SPAN*0.5,spring,top,d-0.04,hole,0.55)
	# The corbel table under the deck's overhang, along both faces.
	for s: float in [-1.0,1.0]:
		var x := -SPAN*0.5+0.4
		while x < SPAN*0.5-0.3:
			var near_pier := absf(absf(x)-SPAN*0.5) < STRIP*0.5+0.12
			if not near_pier and b.rng.randf() > 0.3*b.weathered:
				var planes := RuinKit._box(b,Vector3(0.1,0.13,0.11),0.015)
				var n := Vector3(0.0,-0.9,s).normalized()
				planes.append(Plane(n,n.dot(Vector3(0.0,-0.13,s*0.0))))
				b.solid(planes,RuinKit._settle(b,Vector3(x,wall_top-0.15,s*(d+0.07)),0.5),RuinKit._stone(b,1.04),false,true)
			x += 0.62

## Where a pier at `x` stands its foot: FOOTING under the ground's lowest
## under it (on terrain), or y 0.
static func _pier_foot(b: Build, x: float) -> float:
	if not b.terrain.is_valid(): return 0.0
	var low := INF
	for dx: float in [-PIER.x*0.5,PIER.x*0.5]:
		for dz: float in [-PIER.y*0.5-CUTWATER.x,PIER.y*0.5+CUTWATER.x]:
			low = minf(low,b.floor_at(x+dx,dz))
	return low-FOOTING

## How far under the ground a pier's foot is (its footing), on terrain.
static func _sunk(b: Build) -> float:
	return FOOTING if b.terrain.is_valid() else 0.0

## A piece's finish: the build and its metadata (see the header): its deck
## at `deck`, its piers (`piers` mask) for its feet, `arches` [half clear
## span, springing] for its corridors.
static func _finish(b: Build, deck: float, piers: int, arches: Array) -> Node3D:
	var node := b.finish()
	node.set_meta("bounds",(node.get_node("Mesh") as MeshInstance3D).mesh.get_aabb())
	var feet: Array = []
	for side: float in [-1.0,1.0]:
		if piers & (1 if side < 0.0 else 2): feet.append(Vector3(side*SPAN*0.5,_pier_foot(b,side*SPAN*0.5),0.0))
	node.set_meta("feet",feet)
	var corridors: Array = []
	# THREAD wide, but never closer than 0.6 to a pier's face (CLEAR is
	# wider than THREAD now; at small ratios the arch's own keeps it).
	var half := minf(RuinKit.THREAD,CLEAR-1.2)*0.5
	for arch: Array in arches:
		var low := -INF
		for x: float in [-half,0.0,half]:
			for z: float in [-DECK_WIDTH,0.0,DECK_WIDTH]: low = maxf(low,b.floor_at(x,z))
		var bottom := maxf(low,0.0 if not b.terrain.is_valid() else low)+1.2
		var top := float(arch[1])+1.5
		if top-bottom >= 2.0: corridors.append(AABB(Vector3(-half,bottom,-DECK_WIDTH*1.5),Vector3(half*2.0,top-bottom,DECK_WIDTH*3.0)))
	node.set_meta("corridors",corridors)
	node.set_meta("walk",[{"from":Vector3(-SPAN*0.5,deck,0.0),"to":Vector3(SPAN*0.5,deck,0.0),"width":CHANNEL}])
	node.set_meta("ends",[{"at":Vector3(-SPAN*0.5,deck,0.0),"heading":Vector3.LEFT,"height":deck,"kind":"channel"},{"at":Vector3(SPAN*0.5,deck,0.0),"heading":Vector3.RIGHT,"height":deck,"kind":"channel"}])
	return node

## A pier with its middle at `x`, from `y0` up to its impost at `spring`,
## `size` (width along the run, depth across): a footing course standing
## out, then courses of two or three stones across, joints staggered;
## cutwaters on both faces `cutwater` high under sloped caps; an impost
## moulding; over the springing a buttress strip up each face to
## `wall_top` (0, none). Snapped at `broken` (a stump), its last course
## partly gone, the rest of it ragged.
static func _pier(b: Build, x: float, y0: float, spring: float, wall_top: float, size: Vector2, cutwater: float, broken := INF, footing := true) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	var foot := RuinKit.PLINTH_COURSE.x
	var y := y0
	if footing:
		var planes := RuinKit._box(b,Vector3(hx+0.2,foot*0.5,hz+0.2))
		for s: float in [-1.0,1.0]:
			for axis: Vector3 in [Vector3.RIGHT,Vector3.BACK]:
				var n := (axis*s+Vector3.UP*1.3).normalized()
				var reach := (hx+0.2) if axis.x > 0.5 else (hz+0.2)
				planes.append(Plane(n,n.dot(axis*s*(reach-0.14)+Vector3.UP*foot*0.5)))
		b.solid(planes,RuinKit._settle(b,Vector3(x,y0+foot*0.5,0.0),0.3),RuinKit._stone(b,0.9))
		y += foot
	var shaft_top := minf(spring-IMPOST.x,broken)
	var k := 0
	while y < shaft_top-0.05:
		var y1 := minf(shaft_top,y+b.rng.randf_range(0.46,0.62))
		if shaft_top-y1 < 0.25: y1 = shaft_top
		var last := y1 >= broken-0.01
		var split := b.rng.randf_range(-0.25,0.25)
		var cuts: Array[float] = [-hz,split,hz]
		if k%2 == 0: cuts = [-hz,split-0.45*hz,split+0.45*hz,hz]
		for c in range(cuts.size()-1):
			var z0 := cuts[c]
			var z1 := cuts[c+1]
			if last and b.rng.randf() < 0.3: continue
			var half := Vector3(hx-0.005,(y1-y)*0.5-0.005,(z1-z0)*0.5-0.005)
			var extra: Array[Plane] = []
			if last and b.rng.randf() < 0.55:
				var m := Vector3(b.rng.randf_range(-0.7,0.7),1.0,b.rng.randf_range(-0.7,0.7)).normalized()
				extra.append(Plane(m,m.dot(Vector3(0.0,half.y*b.rng.randf_range(-0.3,0.6),0.0))))
			b.solid(RuinKit._box(b,half),RuinKit._settle(b,Vector3(x,(y+y1)*0.5,(z0+z1)*0.5),0.35+0.3*float(last)),RuinKit._stone(b,1.0 if k%2 == 0 else 0.96),true,true,extra)
		y = y1
		k += 1
	if cutwater > 0.0:
		var cut_top := minf(y0+cutwater,broken-0.2)
		for s: float in [-1.0,1.0]:
			var cy := y0+(foot if footing else 0.0)
			var nose := CUTWATER.x
			while cy < cut_top-0.05:
				var y1 := minf(cut_top,cy+b.rng.randf_range(0.46,0.62))
				if cut_top-y1 < 0.25: y1 = cut_top
				var planes: Array[Plane] = [Plane(Vector3(0.0,0.0,-s),-(hz-0.05)),Plane(Vector3.DOWN,-cy),Plane(Vector3.UP,y1)]
				for e: float in [-1.0,1.0]:
					var n := Vector3(e*nose,0.0,s*hx).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,0.0,s*(hz+nose)))))
				b.solid(planes,RuinKit._settle(b,Vector3(x,0.0,0.0),0.3),RuinKit._stone(b,0.98))
				cy = y1
			if cut_top >= y0+cutwater-0.01 and not (b.weathered > 0.5 and b.rng.randf() < 0.5*b.weathered):
				# The cap: a sloped stone pitching back to the pier's face.
				var planes: Array[Plane] = [Plane(Vector3(0.0,0.0,-s),-(hz-0.05)),Plane(Vector3.DOWN,-cut_top)]
				for e: float in [-1.0,1.0]:
					var n := Vector3(e*nose,0.0,s*hx).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,0.0,s*(hz+nose+0.06)))))
				var slope := Vector3(0.0,1.0,s*1.15).normalized()
				planes.append(Plane(slope,slope.dot(Vector3(0.0,cut_top+0.08,s*(hz+nose+0.06)))))
				planes.append(Plane(Vector3.UP,cut_top+1.1))
				b.solid(planes,RuinKit._settle(b,Vector3(x,0.0,0.0),0.4),RuinKit._stone(b,1.08))
	if broken < INF: return
	# The impost: a moulded slab at the springing, standing out a little.
	var planes := RuinKit._box(b,Vector3(hx+IMPOST.y,IMPOST.x*0.5,hz+0.06))
	for s: float in [-1.0,1.0]:
		var n := Vector3(s,-1.1,0.0).normalized()
		planes.append(Plane(n,n.dot(Vector3(s*(hx+IMPOST.y),-IMPOST.x*0.5+0.12,0.0))))
	b.solid(planes,RuinKit._settle(b,Vector3(x,spring-IMPOST.x*0.5,0.0),0.4),RuinKit._stone(b,1.06))
	if wall_top > spring: _strips(b,x,spring,wall_top,size)

## The buttress strips up a pier's two faces over the springing, from
## `spring` to `wall_top`, `size` the pier's: proud of the spandrel, in
## courses, a sloped set-off at the head; they hide where one span's
## walling meets the next's.
static func _strips(b: Build, x: float, spring: float, wall_top: float, size: Vector2) -> void:
	var hz := size.y*0.5
	var d := DECK_WIDTH*0.5-0.1
	for s: float in [-1.0,1.0]:
		var y := spring
		while y < wall_top-0.05:
			var y1 := minf(wall_top,y+b.rng.randf_range(0.5,0.7))
			if wall_top-y1 < 0.3: y1 = wall_top
			var half := Vector3(STRIP*0.5-0.005,(y1-y)*0.5-0.005,(hz-d)*0.5)
			var planes := RuinKit._box(b,half)
			if y1 >= wall_top-0.01:
				var n := Vector3(0.0,1.0,s*1.2).normalized()
				planes.append(Plane(n,n.dot(Vector3(0.0,half.y,s*(half.z-0.3)))))
			b.solid(planes,RuinKit._settle(b,Vector3(x,(y+y1)*0.5,s*(d+(hz-d)*0.5)),0.4),RuinKit._stone(b,0.98))
			y = y1

## The deck from `x0` to `x1` with its floor's top at `top`: floor slabs
## across the whole width standing out a little (the string course), and
## the parapets along both edges; `open` (x -> bool) where the parapets
## stand back (a cistern's side); `snapped`, its +X end broken off ragged;
## `half_width` the floor's half width (the deck's unless given).
static func _deck(b: Build, x0: float, x1: float, top: float, open: Callable, snapped := false, half_width := -1.0) -> void:
	var hz := (DECK_WIDTH*0.5+0.1) if half_width < 0.0 else half_width
	var x := x0
	while x < x1-0.05:
		var xb := minf(x+b.rng.randf_range(0.8,1.4),x1)
		if x1-xb < 0.45: xb = x1
		var half := Vector3((xb-x)*0.5-0.006,FLOOR*0.5,hz)
		var planes := RuinKit._box(b,half)
		for s: float in [-1.0,1.0]:
			var n := Vector3(0.0,-1.0,s*0.8).normalized()
			planes.append(Plane(n,n.dot(Vector3(0.0,-half.y,s*(half.z-0.12)))))
		var extra: Array[Plane] = []
		if snapped and xb >= x1-0.01: extra = _snap_cut(b,half)
		b.solid(planes,RuinKit._settle(b,Vector3((x+xb)*0.5,top-FLOOR*0.5,0.0),0.4),RuinKit._stone(b,1.02),true,true,extra,-1,0.8)
		x = xb
	if half_width >= 0.0: return
	for s: float in [-1.0,1.0]:
		var end := x1-(b.rng.randf_range(0.15,0.6) if snapped else 0.0)
		_parapet_run(b,x0,end,s*(CHANNEL*0.5+PARAPET.x*0.5),top,PARAPET.y,PARAPET.x,open,snapped)

## Planes snapping a slab off ragged at its +X end (`half` its half size).
static func _snap_cut(b: Build, half: Vector3) -> Array[Plane]:
	var out: Array[Plane] = []
	for i in range(2):
		var m := Vector3(1.0,b.rng.randf_range(-0.6,0.6),b.rng.randf_range(-0.9,0.9)).normalized()
		out.append(Plane(m,m.dot(Vector3(half.x*b.rng.randf_range(-0.1,0.5),0.0,b.rng.randf_range(-0.4,0.4)*half.z))))
	return out

## A parapet along X from `x0` to `x1` at `z`, its foot on `top`: stones
## `high` and `thick`, a coping chamfered both sides; weathered, stones gone
## in runs and others tipped. `open` (x -> bool) leaves a gap.
static func _parapet_run(b: Build, x0: float, x1: float, z: float, top: float, high: float, thick: float, open := Callable(), snapped := false) -> void:
	var x := x0
	var gone := 0
	while x < x1-0.05:
		var xb := minf(x+b.rng.randf_range(0.7,1.3),x1)
		if x1-xb < 0.35: xb = x1
		var mid := (x+xb)*0.5
		if gone > 0: gone -= 1
		elif b.weathered > 0.2 and b.rng.randf() < 0.32*b.weathered: gone = b.rng.randi_range(0,int(1+3.0*b.weathered))
		var skip := gone > 0 or (open.is_valid() and bool(open.call(mid)))
		if not skip:
			var half := Vector3((xb-x)*0.5-0.008,high*0.5,thick*0.5)
			var planes := RuinKit._box(b,half)
			for s: float in [-1.0,1.0]:
				var n := Vector3(0.0,1.0,s*1.1).normalized()
				planes.append(Plane(n,n.dot(Vector3(0.0,half.y,s*(half.z-0.09)))))
			var extra: Array[Plane] = []
			if snapped and xb >= x1-0.01: extra = _snap_cut(b,half)
			var tip := 0.0
			if b.weathered > 0.3 and b.rng.randf() < 0.25*b.weathered: tip = b.rng.randf_range(0.05,0.2)*signf(z)
			var pose := Transform3D(Basis(Vector3.RIGHT,tip),Vector3(mid,top+half.y,z))
			b.solid(planes,RuinKit._jiggle(b,pose,0.6),RuinKit._stone(b,1.06),true,true,extra)
		x = xb

## A parapet across Z at `x`, from `z0` to `z1` (the cistern's back lip).
static func _parapet_run_z(b: Build, x: float, z0: float, z1: float, top: float, high: float, thick: float) -> void:
	var keep := b.frame
	b.frame = b.frame*Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,0.0,0.0))
	_parapet_run(b,-z1,-z0,0.0,top,high,thick)
	b.frame = keep

## The small pointed arch over the channel's mouth at `x`, its jambs on
## the deck (`top`) either side of the channel, a gablet over it; the pilot
## walks under it. Weathered, the gablet gone.
static func _mouth(b: Build, x: float, top: float) -> void:
	var w := CHANNEL*0.5
	var spring := top+1.5
	var jamb := Vector3(0.3,(spring-top)*0.5,0.22)
	for s: float in [-1.0,1.0]:
		b.solid(RuinKit._box(b,jamb),RuinKit._settle(b,Vector3(x,top+jamb.y,s*(w+0.22)),0.4),RuinKit._stone(b,1.03))
	# The arch, turned to span across Z.
	var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,0.0,0.0))
	var radius := CHANNEL+0.44
	RuinKit._ring_order(b,pose,0.0,spring,w+0.0,radius,0.0,0.26,0.3,4,99,1.0,RuinKit._stone(b,1.05),0,Callable(),true)
	var rise := RuinKit._rise(w,radius)
	if not (b.weathered > 0.5 and b.rng.randf() < b.weathered):
		RuinKit._gablet(b,pose*Transform3D(Basis.IDENTITY,Vector3(0.0,spring+rise+0.2,0.0)),w+0.5,0.75,0.32)
		# The jambs carried on up past the arch to the gablet's eaves.
		for s: float in [-1.0,1.0]:
			var post := Vector3(0.1,(rise+0.2)*0.5,0.3)
			b.solid(RuinKit._box(b,post),pose*RuinKit._settle(b,Vector3(s*(w+0.36),spring+post.y,0.0),0.4),RuinKit._stone(b,1.0))

## Ivy and free strands under a span's deck and arches (more, weathered);
## `from_x` the least x they hang at.
static func _hang(b: Build, deck: float, from_x := -SPAN*0.5) -> void:
	if b.weathered <= 0.0: return
	for i in range(int(2+b.weathered*6.0)):
		var x := b.rng.randf_range(maxf(from_x,-SPAN*0.5+0.5),SPAN*0.5-0.5)
		b.hang(Vector3(x,0.0,b.rng.randf_range(-1.0,1.0)*DECK_WIDTH*0.4),b.rng.randf_range(0.6,2.4)*b.weathered,true)

# --- Water ----------------------------------------------------------------------

static var _pond: ShaderMaterial
static var _fall_mesh: ArrayMesh

## The channel's water: a flat sheet from `x0` to `x1` at height `y`,
## `half` across (the channel's unless given), the islets' pond water.
static func _water(root: Node3D, x0: float, x1: float, y: float, half := CHANNEL*0.5-0.01, frame := Transform3D.IDENTITY, label := "Water") -> MeshInstance3D:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var steps := maxi(1,int(ceil((x1-x0)/1.0)))
	for i in range(steps):
		var a := x0+(x1-x0)*i/steps
		var c := x0+(x1-x0)*(i+1)/steps
		for p in [Vector3(a,y,-half),Vector3(c,y,-half),Vector3(c,y,half),Vector3(a,y,-half),Vector3(c,y,half),Vector3(a,y,half)]:
			v.append(frame*p)
			n.append(Vector3.UP)
	return _sheet(root,v,n,label)

## A sheet of the pond water from triangles `v`, wound to face up.
static func _sheet(root: Node3D, v: PackedVector3Array, n: PackedVector3Array, label: String) -> MeshInstance3D:
	for t in range(0,v.size(),3):
		if (v[t+1]-v[t]).cross(v[t+2]-v[t]).y > 0.0:
			var swap := v[t+1]
			v[t+1] = v[t+2]
			v[t+2] = swap
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if _pond == null:
		_pond = ShaderMaterial.new()
		_pond.shader = POND_SHADER
	var sheet := MeshInstance3D.new()
	sheet.name = label
	sheet.mesh = mesh
	sheet.material_override = _pond
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sheet)
	return sheet

## The spill off a snapped channel at `lip` (the water's edge, its level)
## out along `out`: the waterfalls' strand thrown off and falling to a pool
## on the ground (scripts/sky_islets.gd `curtain`, its look and settings);
## gives back where it lands.
static func _spill(root: Node3D, lip: Vector3, out: Vector3, seed_value: int, ground_y := 0.0) -> Vector3:
	var SkyIslets: GDScript = load("res://scripts/sky_islets.gd")
	var FlowFalls: GDScript = load("res://scripts/flow_falls.gd")
	var half := CHANNEL*0.32
	var rings: Dictionary = SkyIslets.curtain(lip,out,lip.y-ground_y-0.35,0.3,half,0.12,0.4,0.9)
	if _fall_mesh == null: _fall_mesh = FlowFalls._build_ring_mesh(SkyIslets.FALL_RINGS)
	var fall := MeshInstance3D.new()
	fall.name = "Spill"
	fall.mesh = _fall_mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.render_priority = FlowFalls.CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(seed_value%997)*0.37+3.0)
	var white := PackedFloat32Array()
	for s in range(12): white.append(fposmod(sin(float(s*23+seed_value%1000)*12.9898)*43758.5453,1.0))
	material.set_shader_parameter("section_white",white)
	material.set_shader_parameter("ring_count",SkyIslets.FALL_RINGS)
	material.set_shader_parameter("centers_tau",rings.centers)
	material.set_shader_parameter("axis_a_width",rings.across)
	material.set_shader_parameter("axis_b_thick",rings.outward)
	material.set_shader_parameter("aer_steep",rings.aer_steep)
	material.set_shader_parameter("ring_travel",rings.travel)
	material.set_shader_parameter("body_white",0.25)
	# A thin spill, torn into streaks: most of the channel's water is gone.
	material.set_shader_parameter("veil",0.55)
	material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*lip.y),2.5,7.0))
	fall.material_override = material
	fall.custom_aabb = rings.bounds
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fall)
	var points: PackedVector3Array = rings.points
	var foot := points[points.size()-1]
	return Vector3(foot.x,ground_y,foot.z)

## A pool where a spill lands at `at`: an uneven ring of sunk stones round
## a sheet of water `radius` across.
static func _pool(b: Build, at: Vector3, radius: float) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var sides := 9
	var r: Array[float] = []
	for k in range(sides): r.append(radius*b.rng.randf_range(0.8,1.1))
	for k in range(sides):
		var a0 := TAU*k/sides
		var a1 := TAU*(k+1)/sides
		for p in [at,at+Vector3(cos(a0),0.0,sin(a0))*r[k],at+Vector3(cos(a1),0.0,sin(a1))*r[(k+1)%sides]]:
			v.append((p as Vector3)+Vector3(0.0,0.035+b.floor_at((p as Vector3).x,(p as Vector3).z)-at.y,0.0))
			n.append(Vector3.UP)
	_sheet(b.root,v,n,"Pool")
	for k in range(sides+3):
		var a := TAU*k/(sides+3)+b.rng.randf_range(-0.1,0.1)
		var s := Vector3(b.rng.randf_range(0.2,0.36),b.rng.randf_range(0.1,0.18),b.rng.randf_range(0.16,0.28))
		var pose := Transform3D(Basis(Vector3.UP,-a+b.rng.randf_range(-0.3,0.3))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.2,0.2)),at+Vector3(cos(a),0.0,sin(a))*(radius+0.12)+Vector3(0.0,s.y*0.5,0.0))
		b.solid(RuinKit._box(b,s),pose,RuinKit._stone(b,0.92),false,true,[],-1,1.5)
	for k in range(4):
		var a := b.rng.randf()*TAU
		b.tuft(at+Vector3(cos(a),0.0,sin(a))*(radius+0.45),0.4,5)
