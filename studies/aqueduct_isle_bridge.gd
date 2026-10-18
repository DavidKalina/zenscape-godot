extends RefCounted
## The aqueduct bridge (docs/design/aqueduct-bridge/handoff-round-1.md): the
## isle's aqueduct gone on east across the gap from the near island's east
## rim toward crag 1 as a broken bridge, carrying the ring course
## (docs/design/ring-course/ring-course-note.md) on one line against the
## sky. In the aqueduct's own look and module (studies/aqueduct_isle_art.gd:
## its arches WorldScale `opening` wide, the plane flying under them, its
## piers one PITCH_X apart, its deck DECK over its springing base), on a
## wider deck, with the Sundered hall's torn-edge grammar (scripts/
## sundered_hall.gd): a span ends in a ragged torn edge, then open sky, then
## the next piece.
##
## Built round the course's pieces, which stay where the user tuned them:
##   - the abutment on the near rim, north of the course's lane (z -7.2), its
##     deck torn off at the rim over the lodestone's floating stone;
##   - the missing spans over the gap, where the big slab (a fallen deck
##     section) and rings 1 and 2 hang: a lost pier's stump under the slab,
##     well below its spring, and a pier standing to its springing beside
##     ring 2, the arch it carried over to span 1 fallen but for its
##     springers;
##   - span 1, the walkable one: three arches on four hanging piers, torn at
##     both ends, its deck RISE over the kicker's top (a hop off its east
##     torn edge slams the kicker). Ring 2's throw carries over its west
##     torn edge; dropped short, he lands on it and walks it; the rune
##     knight patrols it (`knight_line`);
##
## Each piece by its stable name (`bridge/abutment`, `bridge/stump_1`,
## `bridge/gap_pier`, `bridge/span_1`) through the layout
## file (scripts/layout_overrides.gd, kind "piece"), so the world view (F4)
## moves it; the build's knobs (`bridge/line`: rise, hang, seed;
## scripts/layout_knobs.gd) rebuild it. --no-bridge leaves it out.

const Art = preload("res://studies/aqueduct_isle_art.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const Layout = preload("res://scripts/layout_overrides.gd")
const Knobs = preload("res://scripts/layout_knobs.gd")
const RingRoute = preload("res://scripts/interactables/ring_route.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const BUILD := "bridge/line"
## The line (world x, z): from the abutment's back on the near island to
## span 1's east torn edge, just short of the kicker's west edge (a hop
## off it lands on the kicker, as off the ring route's crag rims).
const WEST := Vector2(119.5,-10.6)
const EAST := Vector2(182.3,-8.5)
## The walling's half depth across the line, the deck's half width (wider
## than the aqueduct's channel: a road, a throw's landing), the parapets.
const FACE := 1.75
const DECK_HALF := 1.8
const PARAPET := Vector2(0.38,0.42)
## A pier: the aqueduct's width along the line, as deep as the walling.
static var PIER := Vector2(Art.PIER.x,FACE*2.0)
## The piers along the line (m from WEST): span 1's first at FIRST, then
## one module (Art.PITCH_X) apart each way: k -3 the abutment, -2 and -1
## the gap's stump and pier, 0..3 span 1's.
const FIRST := 30.0
## Span 1's torn ends: the west TORN_WEST past its first pier's middle
## (an arch's springer and a stub of walling), the east at EAST.
const TORN_WEST := 4.0
## The abutment: its block's length along the line, its middle ABUT_BACK
## behind pier k -3's, its torn stub out to RIM_S (m from WEST: just past
## the near island's east rim, over the lodestone's floating stone's west).
const ABUT_LONG := 5.0
const ABUT_BACK := 1.5
const RIM_S := 7.5
## How deep each pier hangs under the base (m, before the `hang` knob):
## span 1's four; the stump's top and foot (well under the big slab, which
## sinks 1.5 m on its spring); the gap pier's foot, and its walling's top
## over the springing (well under ring 2).
const HANGS := [14.0,18.5,16.0,11.0]
const STUMP := Vector2(-6.0,-17.0)
const GAP_FOOT := -15.0
const GAP_WALL := 1.6
const WEATHERED := 0.62

## The line's frame (x along it from WEST, z across, y up from the base:
## the deck at Art.DECK), set by `build`.
static var frame := Transform3D.IDENTITY
static var base_y := 0.0
static var length := 0.0
## What `build` placed: name -> node; span 1's torn ends (its x in its own
## frame).
static var pieces := {}
static var span_ends := Vector2.ZERO
static var root: Node3D = null

static func wanted() -> bool:
	return not LaunchArgs.user_args().has("--no-bridge")

## The pier k's place along the line (m from WEST).
static func pier_s(k: int) -> float:
	return FIRST+Art.PITCH_X*k

## The bridge on `study` (the aqueduct isle), its pieces under one node
## (AqueductBridge), registered as the build `bridge/line` with its knobs.
static func build(study: Node3D) -> Node3D:
	if not wanted(): return null
	root = Node3D.new()
	root.name = "AqueductBridge"
	study.add_child(root)
	var specs := [["rise","Deck over the kicker",snappedf(RingRoute.STEP_DOWN*WorldScale.wanderer,0.01),1.8,5.0,0.05],
		["hang","Piers hang",1.0,0.3,2.0,0.05],
		["seed","Seed",0,0,99,1]]
	Knobs.register(BUILD,"Aqueduct bridge",specs,_make)
	return root

## The deck's top (world y): the kicker's top (as the layout file has it)
## and `rise`.
static func deck_top(rise: float) -> float:
	var coded := Transform3D(Basis(Vector3.UP,0.2),RingRoute.kicker())
	return Layout.xform("ring_route/kicker_slab",coded).origin.y+rise

static func _make(v: Dictionary) -> Array:
	var began := Time.get_ticks_msec()
	var rise := float(v.rise)
	var hang := float(v.hang)
	var seed_value := 7100+int(v.seed)*17
	base_y = deck_top(rise)-Art.DECK
	var way := (EAST-WEST)
	length = way.length()
	way = way.normalized()
	frame = Transform3D(Basis(Vector3.UP,atan2(-way.y,way.x)),Vector3(WEST.x,base_y,WEST.y))
	pieces = {}
	var names: Array = []
	var sp := Art.spring()
	var radius := Art.HALF*2.0*Art.PITCH
	var wall_top := Art.DECK-Art.SLAB
	# The abutment on the near rim.
	var at := pier_s(-3)-ABUT_BACK
	var ground := Art.TOP-base_y
	_place("bridge/abutment",at,_abutment(seed_value,ground,sp,radius,wall_top,RIM_S-at),names)
	# The gap: a lost pier's stump under the big slab, then a pier standing to
	# its springing, the arch it carried over to span 1 fallen but for its
	# springers (ring 2 hangs beside it).
	_place("bridge/stump_1",pier_s(-2),_stump(seed_value+11,STUMP.x,STUMP.y*hang),names)
	_place("bridge/gap_pier",pier_s(-1),_gap_pier(seed_value+12,GAP_FOOT*hang,sp,radius),names)
	# Span 1, the walkable one, torn at both ends.
	var w := pier_s(0)-TORN_WEST
	var e := length
	var mid := (w+e)*0.5
	span_ends = Vector2(w-mid,e-mid)
	_place("bridge/span_1",mid,_span(seed_value+21,mid,w,e,sp,radius,wall_top,hang),names)
	print("aqueduct bridge: %d pieces, deck at %.2f, %.1f m long, built in %d ms" % [names.size(),base_y+Art.DECK,length,Time.get_ticks_msec()-began])
	return names

## A piece built round its own middle (`s` along the line) stood where the
## layout file has `name`, tracked (kind "piece": a move sets its transform).
static func _place(name: String, s: float, node: Node3D, names: Array) -> void:
	if Layout.deleted(name):
		node.free()
		return
	var coded := frame*Transform3D(Basis.IDENTITY,Vector3(s,0.0,0.0))
	node.transform = Layout.xform(name,coded)
	root.add_child(node)
	Layout.track(name,node,"piece",coded)
	pieces[name] = node
	names.append(name)
	RuinLod.add_async(node)

const RuinLod = preload("res://scripts/ruin_lod.gd")

## The rune knight's line (scripts/enemies/rune_knight.gd `setup`): span 1's
## deck where it stands, from just in from its west torn edge to just in from
## its east one; {} without the bridge or span 1.
static func knight_line() -> Dictionary:
	var span: Node3D = pieces.get("bridge/span_1")
	if span == null or not is_instance_valid(span): return {}
	return {"xf":span.global_transform if span.is_inside_tree() else span.transform,
		"head":span_ends.x+0.8,"snap":span_ends.y-0.8,"deck":Art.DECK,"half":DECK_HALF}

## The deck's walk: one clean box (its top WALK_LIFT over the floor slabs'
## tops, between the parapets, WALK_SHORT in from a torn end, where the
## snapped slab may stop short), so the walk along it is level: the settled
## slabs' own hulls step a few cm at each joint, which lifts a runner off
## his feet for a frame. The stone draws; the box only collides.
const WALK_LIFT := 0.02
const WALK_SHORT := 0.6
static func _walk_box(node: Node3D, x0: float, x1: float) -> void:
	var body := node.get_node_or_null("Body") as StaticBody3D
	if body == null: return
	var shape := BoxShape3D.new()
	var inner := DECK_HALF-PARAPET.x
	shape.size = Vector3(x1-x0,0.3,inner*2.0)
	var holder := CollisionShape3D.new()
	holder.name = "Walk"
	holder.shape = shape
	holder.position = Vector3((x0+x1)*0.5,Art.DECK+WALK_LIFT-0.15,0.0)
	body.add_child(holder)

static func _builder(seed_value: int, label: String) -> Build:
	var b := Build.new(seed_value,WEATHERED,label)
	b.drop_floating = true
	b.drop_loose = true
	b.settle = Aqueduct.SETTLE
	return b

## The deck from `x0` to `x1` (piece x), its floor's top at Art.DECK, its
## parapets along both edges; `torn_west`/`torn_east` snap that end off
## ragged (a deck built from its middle out each way, so either end can).
static func _deck(b: Build, x0: float, x1: float, torn_west: bool, torn_east: bool) -> void:
	var mid := (x0+x1)*0.5
	var z := DECK_HALF-PARAPET.x*0.5
	for side: float in [1.0,-1.0]:
		var reach := (x1-mid) if side > 0.0 else (mid-x0)
		var torn := torn_east if side > 0.0 else torn_west
		b.frame = Transform3D(Basis(Vector3.UP,0.0 if side > 0.0 else PI),Vector3(mid,0.0,0.0))
		Aqueduct._deck(b,0.0,reach,Art.DECK,Callable(),torn,DECK_HALF)
		for s: float in [-1.0,1.0]:
			var end := reach-(b.rng.randf_range(0.2,0.9) if torn else 0.0)
			Aqueduct._parapet_run(b,0.0,end,s*z,Art.DECK,PARAPET.y,PARAPET.x,Callable(),torn)
	b.frame = Transform3D.IDENTITY

## A full arch at `cx` and its spandrels (the aqueduct's, as deep as the
## walling).
static func _arch(b: Build, cx: float, sp: float, radius: float, wall_top: float) -> void:
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
	var d := FACE-0.1
	RuinKit._arch_ring(b,pose,0.0,sp,Art.HALF,radius,d,true)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < sp: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(Art.HALF,radius,outer-radius,y-sp))
	var top := func(_x: float) -> float: return wall_top
	var reach := Art.HALF+PIER.x*0.5
	RuinKit._courses(b,pose,-reach,reach,sp,top,d-0.04,hole,0.55)

## A torn end off the pier at `px` going `dir` (+1, -1) to `end` (piece x):
## the next arch's springer standing on the pier, the walling over it to the
## deck's foot breaking off down and away in a ragged line short of the end
## (the deck runs on over it a little), a few stones hung up on the springer.
static func _torn(b: Build, px: float, dir: float, end: float, sp: float, radius: float, wall_top: float) -> void:
	var cx := px+dir*(PIER.x*0.5+Art.HALF)
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
	var d := FACE-0.1
	var u_end := (end-cx)*dir
	var stands := func(u: float) -> float: return 99.0 if u*dir < u_end-1.1 else -99.0
	RuinKit._arch_ring(b,pose,0.0,sp,Art.HALF,radius,d,true,0,1.0,stands)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < sp: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(Art.HALF,radius,outer-radius,y-sp))
	var pm := -(Art.HALF+PIER.x*0.5)*dir
	var ue := u_end*dir
	var ragged := RuinKit._ruin_line(b,minf(pm,ue),maxf(pm,ue),0.0,1.0,1.0)
	var top := func(u: float) -> float:
		var out := u*dir-(u_end-1.6)
		if out <= 0.0: return wall_top
		return wall_top-out*2.6+(float(ragged.call(u))-0.5)*0.7
	RuinKit._courses(b,pose,minf(pm,ue),maxf(pm,ue),sp,top,d-0.04,hole,0.55)
	# Fallen stones hung up on the springer and the pier's head.
	for i in range(3):
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,b.rng.randf_range(-0.5,0.5))
		var s := Vector3(b.rng.randf_range(0.25,0.4),b.rng.randf_range(0.2,0.3),b.rng.randf_range(0.4,0.7))
		b.solid(RuinKit._box(b,s),Transform3D(tumble,Vector3(px+dir*b.rng.randf_range(1.0,1.8),sp+b.rng.randf_range(0.3,1.0),b.rng.randf_range(-1.2,1.2))),RuinKit._stone(b,0.98))
	for i in range(3):
		b.hang(Vector3(end-dir*b.rng.randf_range(0.4,2.0),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(1.2,3.4),true)

## A hanging pier at `x`, its foot broken off at `foot` (under the base),
## ivy and roots trailing.
static func _hanging_pier(b: Build, x: float, foot: float, sp: float, wall_top: float) -> void:
	Aqueduct._pier(b,x,foot,sp,wall_top,PIER,0.0,INF,false)
	Art._broken_foot(b,x,foot)

## The abutment: a block on the near island's turf (`ground`, under the
## base) up to the deck, its back falling away ragged, its pier's next
## arch torn off at the rim, the deck over it torn there too.
static func _abutment(seed_value: int, ground: float, sp: float, radius: float, wall_top: float, reach: float) -> Node3D:
	var b := _builder(seed_value,"BridgeAbutment")
	var half := ABUT_LONG*0.5
	# Coursed solid from under the turf to the deck's foot, the back (west)
	# end broken down.
	var ragged := RuinKit._ruin_line(b,-half,half,0.0,1.0,1.0)
	var top := func(x: float) -> float:
		var back := (-half+2.2)-x
		if back <= 0.0: return wall_top
		return wall_top-back*2.4+(float(ragged.call(x))-0.5)*0.8
	var pose := Transform3D.IDENTITY
	RuinKit._courses(b,pose,-half,half,ground-Aqueduct.FOOTING,top,FACE-0.04,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),0.55)
	_torn(b,half-PIER.x*0.5,1.0,reach,sp,radius,wall_top)
	_deck(b,-half+2.0,reach,true,true)
	for i in range(4): b.hang(Vector3(b.rng.randf_range(half,reach),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(0.8,2.4),true)
	var node := b.finish()
	_walk_box(node,-half+2.0+WALK_SHORT,reach-WALK_SHORT)
	return node

## A stump of a lost pier hanging in the gap: broken off at `top` and
## `foot` (under the base).
static func _stump(seed_value: int, top: float, foot: float) -> Node3D:
	var b := _builder(seed_value,"BridgeStump")
	Aqueduct._pier(b,0.0,foot,Art.spring(),0.0,PIER,0.0,top,false)
	Art._broken_foot(b,0.0,foot)
	for i in range(2): b.hang(Vector3(b.rng.randf_range(-0.8,0.8),top,b.rng.randf_range(-1.2,1.2)),b.rng.randf_range(1.5,3.5),true,top)
	return b.finish()

## The gap pier: hanging (its foot at `foot`), standing to its springing,
## the next arch's springer standing on it toward span 1 under a low ragged
## stub of walling (the deck and the walling over it fallen).
static func _gap_pier(seed_value: int, foot: float, sp: float, radius: float) -> Node3D:
	var b := _builder(seed_value,"BridgeGapPier")
	var top := sp+GAP_WALL
	_hanging_pier(b,0.0,foot,sp,top)
	_torn(b,0.0,1.0,PIER.x*0.5+Art.HALF-0.4,sp,radius,top)
	return b.finish()

## Span 1 (`mid` its middle along the line, `w`..`e` its torn ends): its
## piers (k 0..3) hanging, the arches between them, a springer and a stub
## of walling torn off past each end pier, the deck over all of it.
static func _span(seed_value: int, mid: float, w: float, e: float, sp: float, radius: float, wall_top: float, hang: float) -> Node3D:
	var b := _builder(seed_value,"BridgeSpan1")
	var xs: Array = []
	for k in range(4): xs.append(pier_s(k)-mid)
	for k in range(4): _hanging_pier(b,float(xs[k]),-float(HANGS[k])*hang,sp,wall_top)
	for k in range(3): _arch(b,(float(xs[k])+float(xs[k+1]))*0.5,sp,radius,wall_top)
	_torn(b,float(xs[0]),-1.0,w-mid,sp,radius,wall_top)
	_torn(b,float(xs[3]),1.0,e-mid,sp,radius,wall_top)
	_deck(b,w-mid,e-mid,true,true)
	for i in range(14):
		b.hang(Vector3(b.rng.randf_range(w-mid+1.0,e-mid-1.0),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(0.8,2.8),true)
	var node := b.finish()
	_walk_box(node,w-mid+WALK_SHORT,e-mid-WALK_SHORT)
	return node
