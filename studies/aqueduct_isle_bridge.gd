extends RefCounted
## The aqueduct bridge (docs/design/aqueduct-bridge/handoff-round-1.md,
## handoff-round-2.md): the isle's aqueduct gone on east across the gap from
## the near island's east rim, past crag 1, the outcrop, the slide rock and
## the far crag toward the bell spires as one broken bridge, carrying the
## ring course (docs/design/ring-course/ring-course-note.md, and the user's
## tuning after it in layouts/aqueduct_isle.json) on one line against the
## sky. In the aqueduct's own look and module (studies/aqueduct_isle_art.gd:
## its arches WorldScale `opening` wide, the plane flying under them, its
## piers one PITCH_X apart, its deck DECK over its springing base), on a
## wider deck, with the Sundered hall's torn-edge grammar (scripts/
## sundered_hall.gd): a span ends in a ragged torn edge, then open sky, then
## the next piece.
##
## Built round the course's pieces, which stay where the user tuned them (read
## from the layout file: `course_at`), on legs that bend at the gaps:
##   leg 1, the near rim to crag 1 (round 1):
##   - the abutment on the near rim, north of the course's lane (z -7.2), its
##     deck torn off at the rim over the lodestone's floating stone, a rubble
##     ramp up onto it from the rim's turf (`bridge/abutment_ramp`);
##   - the missing spans over the gap, where the big slab and rings 1 and 2
##     hang: a lost pier's lower half under the floating stone's run-off,
##     broken off at its middle, and a pier standing to its springing beside
##     ring 2;
##   - span 1, the walkable one: three arches on four hanging piers, torn at
##     both ends, its deck RISE over the kicker's top (a hop off its east
##     torn edge slams the kicker), the rune knight patrolling it. Its
##     channel is silted (SILT): ring 2's throw dropped onto it lands soft
##     and stops with room before the torn edge;
##   leg 2, crag 1 to the outcrop: a lone pier past crag 1 under rings 5 and
##     6's throw, then span 2, the second walkable span: two tiers, the lower
##     arcade's deck at span 1's height, an upper arcade on it carrying a deck
##     RISE_2 over slab 3. The standing ring 4 hangs where its first upper
##     arch fell, over that pier's broken upper stub; its throw lands on the
##     upper deck (silted too), walked to its east torn edge and hopped off
##     onto slab 3, slammed;
##   leg 3, a lone pier past slab 3 toward the slide rock;
##   leg 4, past the slide rock's lip (ring A in the gap there): a broken
##     arcade, its deck fallen, under ring A's throw to slab 2;
##   leg 5, the far abutment: two arches and a torn deck up to the far crag's
##     west flank, under slab 2's throw;
##   leg 6, two lone piers south from the far crag toward the bell spires,
##     under the last ring's throw.
## Every hanging pier ends in a torn foot (`_torn_foot`): its last courses
## snapped off along a slanted ragged line, the rubble core showing, stones
## hung up under it.
##
## Each piece by its stable name (`bridge/<piece>`) through the layout file
## (scripts/layout_overrides.gd, kind "piece"), so the world view (F4) moves
## it; the build's knobs (`bridge/line`: rise, rise_2, hang, silt, seed;
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
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

const BUILD := "bridge/line"
## Leg 1 (world x, z): from the abutment's back on the near island to
## span 1's east torn edge, just short of the kicker's west edge (a hop
## off it lands on the kicker, as off the ring route's crag rims).
const WEST := Vector2(119.5,-10.6)
const EAST := Vector2(182.3,-8.5)
## The course's pieces the later legs are built round, as the user saved
## them (layouts/aqueduct_isle.json, 7ee36fc5); `course_at` reads them from
## the layout file as it stands.
const RING_4 := Vector3(223.25,50.176,-9.8)
const SLAB_3 := Vector3(270.879,45.65,-20.112)
const RING_A := Vector3(315.9,41.728,-11.75)
const SLAB_2 := Vector3(365.85,45.65,-4.1)
## Where the line meets the slide rock's west face, the far crag's west
## flank and (leg 6) heads for the bell spires' north turf (world x, z;
## scripts/interactables/ring_route.gd, scripts/kit_isle/motif_sky.gd).
const ROCK_FACE := Vector2(286.0,-12.5)
const FAR_FLANK := Vector2(402.0,-2.0)
const FAR_SOUTH := Vector2(412.5,5.5)
const SPIRES := Vector2(418.0,40.0)
## The walling's half depth across the line, the deck's half width (wider
## than the aqueduct's channel: a road, a throw's landing), the parapets.
const FACE := 1.75
const DECK_HALF := 1.8
const PARAPET := Vector2(0.38,0.42)
## A pier: the aqueduct's width along the line, as deep as the walling.
static var PIER := Vector2(Art.PIER.x,FACE*2.0)
## The piers along leg 1 (m from WEST): span 1's first at FIRST, then
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
## span 1's four; the stump's top and foot (under the floating stone's
## run-off and the plane's thread past it, aqueduct_isle_sky.gd "aq:east");
## the gap pier's foot, and its walling's top over the springing (well
## under ring 2).
const HANGS := [14.0,18.5,16.0,11.0]
const STUMP := Vector2(-6.0,-17.0)
const GAP_FOOT := -15.0
const GAP_WALL := 1.6
const WEATHERED := 0.62

## The ramp up onto the abutment from the rim's turf (`bridge/abutment_ramp`):
## its slope as steep as he runs up without surfing down (between
## PilotMotor.SLOPE_SLOW, where he slows, and SLIDE_AUTO, where he can't
## stand), its half width (a wanderer stride either side of the middle),
## where it meets the deck (m along leg 1) and how far it swings west off
## square (rad: its foot stays on the turf, clear of the plane's strip by
## the parked plane at x 107 and of the rim at x 118).
static var RAMP_DEG: float = lerpf(PilotMotor.SLOPE_SLOW,PilotMotor.SLIDE_AUTO,0.6)
static var RAMP_HALF: float = 1.3*WorldScale.wanderer
const RAMP_S := -0.5
const RAMP_YAW := 0.35

## The silt bed on a walkable span's deck (soft ground, scripts/
## pilot_physics_ground.gd `mark_soft`): a throw landed on it keeps `keep`
## of its flat pace (the `silt` knob), so ring 2's 21 m/s stops in about 3 m
## (let go) instead of 12; standing and running on it is as on stone. Its
## stretch along span 1 (m along leg 1) and span 2 (m along its leg).
const SILT_LIFT := 0.05
const SILT_1 := Vector2(37.0,60.4)
const SILT_2 := Vector2(12.0,46.0)

## Span 2 (leg 2): its east torn edge SLAB_SHORT short of slab 3's west edge
## (the kicker's 0.9), its lower west torn end SPAN2_LONG back along the
## line; the lower piers SPAN2_PIERS from the west end; how deep each hangs.
## The upper tier: its walling's half depth (a ledge of the lower walling
## each side), its arch's pitch (a lower drop arch than the lower tier's),
## the broken stub of its first pier under ring 4.
const SLAB_SHORT := 0.9
const SPAN2_LONG := 48.0
const SPAN2_PIERS := [4.0,14.0,24.0,34.0,44.0]
const SPAN2_HANGS := [15.0,19.5,21.0,18.0,13.5]
const UPPER_FACE := 1.4
const UPPER_PITCH := 0.65
const UPPER_STUB := 3.2
## The lone piers (crag 1's, the slide rock's, the bell spires' two): how
## far along their leg (m) and how deep they hang; the broken arcade under
## ring A's throw (leg 4): its piers along the leg, its torn ends; the far
## abutment (leg 5): its piers back from the deck's torn end at the far
## crag's flank.
const CRAG_PIER := [0.5,-16.0]
const ROCK_PIER := [9.5,-14.0]
const ARCADE_PIERS := [28.0,38.0]
const ARCADE_HANGS := [17.0,13.0]
const ARCADE_TORN := 4.5
const FAR_PIERS := [14.0,4.0]
const FAR_HANGS := [12.0,15.5]
const SPIRES_PIERS := [[9.0,-15.0],[24.0,-17.5]]

## Leg 1's frame (x along it from WEST, z across, y up from the base:
## the deck at Art.DECK), set by `build`.
static var frame := Transform3D.IDENTITY
static var base_y := 0.0
static var length := 0.0
## What `build` placed: name -> node; span 1's torn ends (its x in its own
## frame); span 2's frame (its leg's), its upper deck's height over its base
## and its upper deck's torn ends (x in its own frame).
static var pieces := {}
static var span_ends := Vector2.ZERO
static var span2_frame := Transform3D.IDENTITY
static var span2_up := 8.0
static var span2_ends := Vector2.ZERO
static var root: Node3D = null

static func wanted() -> bool:
	return not LaunchArgs.user_args().has("--no-bridge")

## The pier k's place along leg 1 (m from WEST).
static func pier_s(k: int) -> float:
	return FIRST+Art.PITCH_X*k

static func _knob_specs() -> Array:
	return [["rise","Deck over the kicker",snappedf(RingRoute.STEP_DOWN*WorldScale.wanderer,0.01),1.8,5.0,0.05],
		["rise_2","Upper deck over slab 3",snappedf(RingRoute.STEP_DOWN*WorldScale.wanderer,0.01),1.8,5.0,0.05],
		["hang","Piers hang",1.0,0.3,2.0,0.05],
		["silt","Silt keeps of a landing's pace",0.5,0.1,1.0,0.05],
		["seed","Seed",0,0,99,1]]

## The bridge on `study` (the aqueduct isle), its pieces under one node
## (AqueductBridge), registered as the build `bridge/line` with its knobs.
static func build(study: Node3D) -> Node3D:
	if not wanted(): return null
	root = Node3D.new()
	root.name = "AqueductBridge"
	study.add_child(root)
	Knobs.register(BUILD,"Aqueduct bridge",_knob_specs(),_make)
	return root

## A course piece's place (world) as the layout file has it: added, moved,
## or `saved` (as the user saved it).
static func course_at(name: String, saved: Vector3) -> Vector3:
	var added: Array = Layout.data.get("added",[])
	for a: Variant in added:
		if a is Dictionary and str((a as Dictionary).get("name","")) == name:
			var p: Array = (a as Dictionary).get("pos",[])
			if p.size() == 3: return Vector3(float(p[0]),float(p[1]),float(p[2]))
	var moved: Dictionary = Layout.data.get("moved",{})
	var m: Variant = moved.get(name)
	if m is Dictionary:
		var p: Array = (m as Dictionary).get("pos",[])
		if p.size() == 3: return Vector3(float(p[0]),float(p[1]),float(p[2]))
	return saved

## A slab's half size along x (the layout file's size, else the kicker's).
static func _slab_half(name: String) -> float:
	var added: Array = Layout.data.get("added",[])
	for a: Variant in added:
		if a is Dictionary and str((a as Dictionary).get("name","")) == name:
			var s: Variant = (a as Dictionary).get("size")
			if s is Array and (s as Array).size() == 3: return float((s as Array)[0])*0.5
	return 3.075

## The deck's top (world y): the kicker's top (as the layout file has it)
## and `rise`.
static func deck_top(rise: float) -> float:
	var coded := Transform3D(Basis(Vector3.UP,0.2),RingRoute.kicker())
	return Layout.xform("ring_route/kicker_slab",coded).origin.y+rise

## A leg's frame: x from `a` toward `b` (world x, z), y up from `base`.
static func leg_xf(a: Vector2, b: Vector2, base: float) -> Transform3D:
	var d := (b-a).normalized()
	return Transform3D(Basis(Vector3.UP,atan2(-d.y,d.x)),Vector3(a.x,base,a.y))

## Span 2's line (world x, z): [its lower west torn end, its upper deck's
## east torn edge], on the line from ring 4 through slab 3's middle.
static func span2_line() -> Array:
	var r4 := course_at("ring_route/stair_ring_4",RING_4)
	var s3 := course_at("added/bob_slab_3",SLAB_3)
	var a := Vector2(r4.x,r4.z)
	var c := Vector2(s3.x,s3.z)
	var d := (c-a).normalized()
	var e := c-d*(_slab_half("added/bob_slab_3")+SLAB_SHORT)
	return [e-d*SPAN2_LONG,e]

## Where --foot-at= starts him on the bridge (aqueduct_foot_route.gd SPOTS):
## the ramp's foot, facing up it; span 2's upper deck past its west torn
## edge, facing along it (at the knobs' defaults).
static func spots() -> Dictionary:
	var rise := snappedf(RingRoute.STEP_DOWN*WorldScale.wanderer,0.01)
	var base := deck_top(rise)-Art.DECK
	var f1 := leg_xf(WEST,EAST,base)
	var yaw := -PI*0.5+RAMP_YAW
	var ramp := f1*Transform3D(Basis(Vector3.UP,yaw),Vector3(RAMP_S,0.0,-DECK_HALF))
	var run := (Art.DECK-(Art.TOP-base))/tan(deg_to_rad(RAMP_DEG))
	var foot := ramp*Vector3(-run-1.5,0.0,0.0)
	var up := (ramp.basis*Vector3.RIGHT)
	var line: Array = span2_line()
	var f2 := leg_xf(line[0],line[1],base)
	var s3 := course_at("added/bob_slab_3",SLAB_3)
	var on := f2*Vector3(15.0,s3.y+rise-base+0.05,0.0)
	var way := f2.basis*Vector3.RIGHT
	return {
		"bridge_ramp":[Vector3(foot.x,Art.TOP,foot.z),Vector2(up.x,up.z).normalized()],
		"bridge_span2":[on,Vector2(way.x,way.z).normalized()],
	}

static func _make(v: Dictionary) -> Array:
	var began := Time.get_ticks_msec()
	var rise := float(v.get("rise",2.6))
	var rise2 := float(v.get("rise_2",2.6))
	var hang := float(v.get("hang",1.0))
	var keep := float(v.get("silt",0.5))
	var seed_value := 7100+int(v.get("seed",0))*17
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
	# --- Leg 1: the abutment on the near rim, its ramp up from the turf.
	var at := pier_s(-3)-ABUT_BACK
	var ground := Art.TOP-base_y
	var gap := Vector2(RAMP_S-at-RAMP_HALF/cos(RAMP_YAW)-0.4,RAMP_S-at+RAMP_HALF/cos(RAMP_YAW)+0.4)
	_place("bridge/abutment",at,_abutment(seed_value,ground,sp,radius,wall_top,RIM_S-at,gap),names)
	var ramp_xf := frame*Transform3D(Basis(Vector3.UP,-PI*0.5+RAMP_YAW),Vector3(RAMP_S,0.0,-DECK_HALF))
	_place_at("bridge/abutment_ramp",ramp_xf,_ramp(seed_value+5,ground),names)
	# The gap: a lost pier's lower half under the floating stone's run-off,
	# then a pier standing to its springing, the arch it carried over to span
	# 1 fallen but for its springers (ring 2 hangs beside it).
	_place("bridge/stump_1",pier_s(-2),_stump(seed_value+11,STUMP.x,STUMP.y*hang),names)
	_place("bridge/gap_pier",pier_s(-1),_gap_pier(seed_value+12,GAP_FOOT*hang,sp,radius),names)
	# Span 1, the walkable one, torn at both ends, its channel silted.
	var w := pier_s(0)-TORN_WEST
	var e := length
	var mid := (w+e)*0.5
	span_ends = Vector2(w-mid,e-mid)
	var xs1: Array = []
	for k in range(4): xs1.append(pier_s(k)-mid)
	var hangs1: Array = []
	for k in range(4): hangs1.append(-float(HANGS[k])*hang)
	var span1 := _span(seed_value+21,"BridgeSpan1",xs1,hangs1,w-mid,e-mid,sp,radius,wall_top)
	_silt(span1,seed_value+22,SILT_1.x-mid,SILT_1.y-mid,Art.DECK,keep)
	_place("bridge/span_1",mid,span1,names)
	# --- Leg 2: crag 1's lone pier, then span 2 (two tiers) to slab 3.
	var line2: Array = span2_line()
	var w2: Vector2 = line2[0]
	var e2: Vector2 = line2[1]
	var crag_leg := leg_xf(EAST,w2,base_y)
	var crag_long := EAST.distance_to(w2)
	_place_at("bridge/crag_pier",crag_leg*Transform3D(Basis.IDENTITY,Vector3(crag_long*float(CRAG_PIER[0]),0.0,0.0)),_lone_pier(seed_value+31,"BridgeCragPier",float(CRAG_PIER[1])*hang,sp,radius),names)
	span2_frame = leg_xf(w2,e2,base_y)
	var s3 := course_at("added/bob_slab_3",SLAB_3)
	span2_up = (s3.y+rise2)-(base_y+Art.DECK)
	var mid2 := SPAN2_LONG*0.5
	_place_at("bridge/span_2",span2_frame*Transform3D(Basis.IDENTITY,Vector3(mid2,0.0,0.0)),_span2(seed_value+41,mid2,sp,radius,wall_top,hang,keep),names)
	# --- Leg 3: past slab 3, a lone pier toward the slide rock's west face.
	var s3v := Vector2(s3.x,s3.z)
	var rock_leg := leg_xf(s3v,ROCK_FACE,base_y)
	_place_at("bridge/rock_pier",rock_leg*Transform3D(Basis.IDENTITY,Vector3(float(ROCK_PIER[0]),0.0,0.0)),_lone_pier(seed_value+51,"BridgeRockPier",float(ROCK_PIER[1])*hang,sp,radius),names)
	# --- Leg 4: past the slide rock's lip (ring A hangs in the gap), a
	# broken arcade under ring A's throw, its deck fallen.
	var ra := course_at("ring_route/ring_a",RING_A)
	var s2 := course_at("added/bob_slab_2",SLAB_2)
	var lip_leg := leg_xf(Vector2(ra.x,ra.z),Vector2(s2.x,s2.z),base_y)
	var amid := (float(ARCADE_PIERS[0])+float(ARCADE_PIERS[1]))*0.5
	var axs: Array = [float(ARCADE_PIERS[0])-amid,float(ARCADE_PIERS[1])-amid]
	var ahs: Array = [-float(ARCADE_HANGS[0])*hang,-float(ARCADE_HANGS[1])*hang]
	_place_at("bridge/arcade_3",lip_leg*Transform3D(Basis.IDENTITY,Vector3(amid,0.0,0.0)),_arcade(seed_value+61,axs,ahs,float(axs[0])-ARCADE_TORN,float(axs[1])+ARCADE_TORN,sp,radius,wall_top),names)
	# --- Leg 5: the far abutment, up to the far crag's west flank.
	var s2v := Vector2(s2.x,s2.z)
	var far_leg := leg_xf(s2v,FAR_FLANK,base_y)
	var far_e := s2v.distance_to(FAR_FLANK)
	var fxs: Array = []
	var fhs: Array = []
	for k in range(2):
		fxs.append(far_e-float(FAR_PIERS[k]))
		fhs.append(-float(FAR_HANGS[k])*hang)
	var fw := float(fxs[0])-TORN_WEST
	var fmid := (fw+far_e)*0.5
	for k in range(2): fxs[k] = float(fxs[k])-fmid
	_place_at("bridge/far_abutment",far_leg*Transform3D(Basis.IDENTITY,Vector3(fmid,0.0,0.0)),_span(seed_value+71,"BridgeFarAbutment",fxs,fhs,fw-fmid,far_e-fmid,sp,radius,wall_top,GROWTH_FAR),names)
	# --- Leg 6: two lone piers south toward the bell spires.
	var sp_leg := leg_xf(FAR_SOUTH,SPIRES,base_y)
	for k in range(SPIRES_PIERS.size()):
		var spec: Array = SPIRES_PIERS[k]
		_place_at("bridge/spires_pier_%d" % (k+1),sp_leg*Transform3D(Basis.IDENTITY,Vector3(float(spec[0]),0.0,0.0)),_lone_pier(seed_value+81+k,"BridgeSpiresPier%d" % (k+1),float(spec[1])*hang,sp,radius),names)
	print("aqueduct bridge: %d pieces, deck at %.2f, upper deck at %.2f, built in %d ms" % [names.size(),base_y+Art.DECK,base_y+Art.DECK+span2_up,Time.get_ticks_msec()-began])
	return names

## A piece built round its own middle (`s` along leg 1) stood where the
## layout file has `name`, tracked (kind "piece": a move sets its transform).
static func _place(name: String, s: float, node: Node3D, names: Array) -> void:
	_place_at(name,frame*Transform3D(Basis.IDENTITY,Vector3(s,0.0,0.0)),node,names)

## The same at a coded transform (world).
static func _place_at(name: String, coded: Transform3D, node: Node3D, names: Array) -> void:
	if Layout.deleted(name):
		node.free()
		return
	node.transform = Layout.xform(name,coded)
	root.add_child(node)
	Layout.track(name,node,"piece",coded)
	pieces[name] = node
	names.append(name)
	RuinLod.add_async(node)

const RuinLod = preload("res://scripts/ruin_lod.gd")

## The rune knight's line (scripts/enemies/rune_knight.gd `setup`): span 1's
## deck where it stands, from KNIGHT_FROM along leg 1 (round 1: its west torn
## edge) to just in from its east torn edge: the stretch where ring 2's throw
## lands, so his patrol is round and ahead of a landing, not behind it; {}
## without the bridge or span 1.
const KNIGHT_FROM := 34.0
static func knight_line() -> Dictionary:
	var span: Node3D = pieces.get("bridge/span_1")
	if span == null or not is_instance_valid(span): return {}
	var mid := (pier_s(0)-TORN_WEST+length)*0.5
	return {"xf":span.global_transform if span.is_inside_tree() else span.transform,
		"head":maxf(span_ends.x+0.8,KNIGHT_FROM-mid),"snap":span_ends.y-0.8,"deck":Art.DECK,"half":DECK_HALF}

## The deck's walk: one clean box (its top WALK_LIFT over the floor slabs'
## tops, between the parapets, WALK_SHORT in from a torn end, where the
## snapped slab may stop short), so the walk along it is level: the settled
## slabs' own hulls step a few cm at each joint, which lifts a runner off
## his feet for a frame. The stone draws; the box only collides.
const WALK_LIFT := 0.02
const WALK_SHORT := 0.6
static func _walk_box(node: Node3D, x0: float, x1: float, top := -1.0) -> void:
	var body := node.get_node_or_null("Body") as StaticBody3D
	if body == null: return
	if top < 0.0: top = Art.DECK
	var shape := BoxShape3D.new()
	var inner := DECK_HALF-PARAPET.x
	shape.size = Vector3(x1-x0,0.3,inner*2.0)
	var holder := CollisionShape3D.new()
	holder.name = "Walk"
	holder.shape = shape
	holder.position = Vector3((x0+x1)*0.5,top+WALK_LIFT-0.15,0.0)
	body.add_child(holder)

## The silt bed on a deck from `x0` to `x1` (piece x), its floor's top at
## `top`: the channel's old silt, earth lumps between the parapets mossed
## over and tufted, drawn on `node`'s Build-less mesh as its own small build;
## its own body (Silt) one box SILT_LIFT over the floor, marked soft (a
## landing keeps `keep` of its flat pace).
static func _silt(node: Node3D, seed_value: int, x0: float, x1: float, top: float, keep: float) -> void:
	var b := _builder(seed_value,"Silt")
	var inner := DECK_HALF-PARAPET.x
	var earth := Color("6a5a41")
	var x := x0
	while x < x1-0.2:
		var xb := minf(x+b.rng.randf_range(0.5,1.2),x1)
		var z := -inner
		while z < inner-0.15:
			var zb := minf(z+b.rng.randf_range(0.5,1.1),inner)
			var lift := b.rng.randf_range(0.03,SILT_LIFT+0.04)
			var half := Vector3((xb-x)*0.5+0.06,0.06,(zb-z)*0.5+0.05)
			var tilt := Basis(Vector3.RIGHT,b.rng.randf_range(-0.05,0.05))*Basis(Vector3.BACK,b.rng.randf_range(-0.04,0.04))
			b.solid(RuinKit._box(b,half,0.04),Transform3D(tilt,Vector3((x+xb)*0.5,top+lift-0.06,(z+zb)*0.5)),earth*b.rng.randf_range(0.85,1.1),false,false,[],-1,1.0,b.rng.randf() < 0.35)
			z = zb
		if b.rng.randf() < 0.5: b.tuft(Vector3(b.rng.randf_range(x,xb),top+SILT_LIFT,b.rng.randf_range(-inner,inner)*0.85),b.rng.randf_range(0.25,0.5))
		x = xb
	var look := b.finish()
	look.name = "SiltLook"
	node.add_child(look)
	var body := StaticBody3D.new()
	body.name = "Silt"
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1-x0,0.3,inner*2.0)
	var holder := CollisionShape3D.new()
	holder.shape = shape
	holder.position = Vector3((x0+x1)*0.5,top+SILT_LIFT-0.15,0.0)
	body.add_child(holder)
	PhysicsGround.mark_soft(body,{"slow":1.0,"catch":0.0,"keep":keep})
	node.add_child(body)

## A piece's build: the aqueduct's settle (not the kit's `cull`: it takes
## everything under the piece's y 0 for buried, the hanging piers too), its
## growth (ivy, moss, vine curtains) thinned to `growth` of the kit's
## detail (round 2's pieces stand in the far view: GROWTH_LONE and the rest).
const GROWTH_LONE := 0.35
const GROWTH_FAR := 0.4
const GROWTH_SPAN2 := 0.6
static func _builder(seed_value: int, label: String, growth := 1.0) -> Build:
	var b := Build.new(seed_value,WEATHERED,label)
	b.drop_floating = true
	b.drop_loose = true
	b.settle = Aqueduct.SETTLE
	b.level *= growth
	return b

## The deck from `x0` to `x1` (piece x), its floor's top at `top`, its
## parapets along both edges; `torn_west`/`torn_east` snap that end off
## ragged (a deck built from its middle out each way, so either end can);
## `open_north` (piece x -> bool) leaves a gap in the north (-z) parapet.
static func _deck(b: Build, x0: float, x1: float, torn_west: bool, torn_east: bool, top := -1.0, open_north := Callable()) -> void:
	if top < 0.0: top = Art.DECK
	var mid := (x0+x1)*0.5
	var z := DECK_HALF-PARAPET.x*0.5
	for side: float in [1.0,-1.0]:
		var reach := (x1-mid) if side > 0.0 else (mid-x0)
		var torn := torn_east if side > 0.0 else torn_west
		b.frame = Transform3D(Basis(Vector3.UP,0.0 if side > 0.0 else PI),Vector3(mid,0.0,0.0))
		Aqueduct._deck(b,0.0,reach,top,Callable(),torn,DECK_HALF)
		for s: float in [-1.0,1.0]:
			var end := reach-(b.rng.randf_range(0.2,0.9) if torn else 0.0)
			var open := Callable()
			if open_north.is_valid() and s*side < 0.0:
				open = func(u: float) -> bool: return bool(open_north.call(mid+u*side))
			Aqueduct._parapet_run(b,0.0,end,s*z,top,PARAPET.y,PARAPET.x,open,torn)
	b.frame = Transform3D.IDENTITY

## A full arch at `cx` and its spandrels (the aqueduct's, as deep as the
## walling `d`) up to `wall_top`, or to `top` (x -> y) where given.
static func _arch(b: Build, cx: float, sp: float, radius: float, wall_top: float, d := FACE-0.1, top := Callable()) -> void:
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
	RuinKit._arch_ring(b,pose,0.0,sp,Art.HALF,radius,d,true)
	var outer := radius+RuinKit.ORDER*2.0+0.04
	var hole := func(y: float) -> Vector2:
		if y < sp: return Vector2(0.0,99.0)
		return Vector2(0.0,RuinKit._arc_half(Art.HALF,radius,outer-radius,y-sp))
	if not top.is_valid(): top = func(_x: float) -> float: return wall_top
	var reach := Art.HALF+PIER.x*0.5
	var shifted := func(u: float) -> float: return float(top.call(u+cx))
	RuinKit._courses(b,pose,-reach,reach,sp,shifted,d-0.04,hole,0.55)

## A torn end off the pier at `px` going `dir` (+1, -1) to `end` (piece x):
## the next arch's springer standing on the pier, the walling over it to the
## deck's foot breaking off down and away in a ragged line short of the end
## (the deck runs on over it a little), a few stones hung up on the springer.
static func _torn(b: Build, px: float, dir: float, end: float, sp: float, radius: float, wall_top: float, d := FACE-0.1) -> void:
	var cx := px+dir*(PIER.x*0.5+Art.HALF)
	var pose := Transform3D(Basis.IDENTITY,Vector3(cx,0.0,0.0))
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
		b.solid(RuinKit._box(b,s),Transform3D(tumble,Vector3(px+dir*b.rng.randf_range(1.0,1.8),sp+b.rng.randf_range(0.3,1.0),b.rng.randf_range(-1.2,1.2)*d/(FACE-0.1))),RuinKit._stone(b,0.98))
	for i in range(3):
		b.hang(Vector3(end-dir*b.rng.randf_range(0.4,2.0),0.0,b.rng.randf_range(-1.0,1.0)*d*0.8),b.rng.randf_range(1.2,3.4),true)

## A hanging pier at `x`, its foot broken off at `foot` (under the base),
## torn (`_torn_foot`), ivy and roots trailing.
static func _hanging_pier(b: Build, x: float, foot: float, sp: float, wall_top: float, size := Vector2.ZERO) -> void:
	if size == Vector2.ZERO: size = PIER
	Aqueduct._pier(b,x,foot,sp,wall_top,size,0.0,INF,false)
	_torn_foot(b,x,foot,size)

## A pier's torn foot under `foot` (its shaft's lowest course's bottom), the
## pier `size` (along, across): its last courses snapped off along a slanted
## ragged line, deepest on one side and corner (TORN_DEEP under the shaft at
## most), each course's stones fewer and more out of true going down, the
## break's own stones cut off ragged, the darker rubble core showing in the
## break, and under it a few stones hung up and the ivy and roots trailing
## (Art._broken_foot). A break, not a post's end: from below and the side
## it reads as the remains of a pier that went on down. Only its upper,
## settled stones collide (the plane bumps them); the loose ones under and
## the core only draw.
const TORN_DEEP := Vector2(2.2,3.6)
static func _torn_foot(b: Build, x: float, foot: float, size: Vector2) -> void:
	var hx := size.x*0.5
	var hz := size.y*0.5
	var lean := Vector2(b.rng.randf_range(-1.0,1.0),b.rng.randf_range(-1.0,1.0)).normalized()
	var deep := b.rng.randf_range(TORN_DEEP.x,TORN_DEEP.y)
	var ragged := RuinKit._ruin_line(b,-1.0,1.0,0.0,1.0,1.0)
	# How far under `foot` the break reaches at (u, w) across the pier (each
	# -1..1): a slanted plane, deepest toward `lean`, roughened.
	var reach := func(u: float, w: float) -> float:
		var t := (lean.x*u+lean.y*w)*0.5+0.5
		return deep*(0.12+0.88*t*t)+(float(ragged.call(clampf((u+w)*0.5,-1.0,1.0)))-0.5)*0.9
	var y := foot
	var k := 0
	while y > foot-deep-0.1:
		var y0 := y-b.rng.randf_range(0.46,0.6)
		var nx := 2 if k%2 == 0 else 3
		var nz := 3 if k%2 == 0 else 2
		for i in range(nx):
			for j in range(nz):
				var u0 := -1.0+2.0*float(i)/nx
				var u1 := -1.0+2.0*float(i+1)/nx
				var w0 := -1.0+2.0*float(j)/nz
				var w1 := -1.0+2.0*float(j+1)/nz
				var r := float(reach.call((u0+u1)*0.5,(w0+w1)*0.5))
				if foot-y >= r: continue
				var half := Vector3((u1-u0)*hx*0.5-0.01,(y-y0)*0.5-0.01,(w1-w0)*hz*0.5-0.01)
				var extra: Array[Plane] = []
				var loose := clampf((foot-y)/maxf(r,0.3),0.0,1.0)
				if foot-y0 > r:
					# The break runs through this stone: cut off ragged under.
					var m := Vector3(b.rng.randf_range(-0.8,0.8),-1.0,b.rng.randf_range(-0.8,0.8)).normalized()
					extra.append(Plane(m,m.dot(Vector3(0.0,-half.y*b.rng.randf_range(-0.4,0.5),0.0))))
				var at := Vector3(x+(u0+u1)*0.5*hx,(y+y0)*0.5,(w0+w1)*0.5*hz)
				var pose := Transform3D(Basis(Vector3(b.rng.randf(),0.0,b.rng.randf()).normalized(),b.rng.randf_range(0.0,0.06+0.12*loose)),at+Vector3(b.rng.randf_range(-0.05,0.05),-loose*b.rng.randf_range(0.0,0.08),b.rng.randf_range(-0.05,0.05))*(1.0+loose))
				b.solid(RuinKit._box(b,half),pose,RuinKit._stone(b,0.96-0.08*loose),loose < 0.4,true,extra)
		y = y0
		k += 1
	# The rubble core in the break: rough dark stones packed inside the
	# faces, standing a little lower than the courses round them.
	for i in range(5):
		var s := Vector3(b.rng.randf_range(0.25,0.45),b.rng.randf_range(0.2,0.4),b.rng.randf_range(0.25,0.5))
		var u := b.rng.randf_range(-0.55,0.55)
		var w := b.rng.randf_range(-0.55,0.55)
		var under := float(reach.call(u,w))+b.rng.randf_range(-0.2,0.35)
		var cut: Array[Plane] = [Plane(Vector3(b.rng.randf_range(-0.6,0.6),-1.0,b.rng.randf_range(-0.6,0.6)).normalized(),b.rng.randf_range(0.0,0.15))]
		b.solid(RuinKit._box(b,s),Transform3D(Basis(Vector3(b.rng.randf(),b.rng.randf(),b.rng.randf()).normalized(),b.rng.randf_range(0.0,0.6)),Vector3(x+u*hx,foot-under+s.y*0.6,w*hz)),RuinKit._stone(b,0.72),false,true,cut)
	Art._broken_foot(b,x+lean.x*hx*0.4,foot-deep*0.85)

## The abutment: a block on the near island's turf (`ground`, under the
## base) up to the deck, its back falling away ragged, its pier's next
## arch torn off at the rim, the deck over it torn there too; the north
## parapet open over `gap` (piece x) where the ramp comes up.
static func _abutment(seed_value: int, ground: float, sp: float, radius: float, wall_top: float, reach: float, gap: Vector2) -> Node3D:
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
	var open := func(x: float) -> bool: return x > gap.x and x < gap.y
	_deck(b,-half+2.0,reach,true,true,-1.0,open)
	for i in range(4): b.hang(Vector3(b.rng.randf_range(half,reach),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(0.8,2.4),true)
	var node := b.finish()
	_walk_box(node,-half+2.0+WALK_SHORT,reach-WALK_SHORT)
	return node

## The rubble ramp up onto the abutment (its own frame: +x toward the deck,
## its top at x 0 on the deck's north edge at Art.DECK, its foot RAMP_DEG
## down on the turf at `ground`): the abutment's fallen walling heaped
## against its north face, its top stones tilted in the slope's plane (a
## stone a hair under, none over), the heap of fallen courses under them,
## a few loose blocks spilled on the turf beside its foot. One clean box
## along the slope collides as its walk (the stones' own hulls step at each
## joint).
static func _ramp(seed_value: int, ground: float) -> Node3D:
	var b := _builder(seed_value,"BridgeAbutmentRamp",GROWTH_FAR)
	b.drop_floating = false
	var angle := deg_to_rad(RAMP_DEG)
	var rise := Art.DECK-ground
	var run := rise/tan(angle)
	var along := Vector3(cos(angle),sin(angle),0.0)
	var long := run/cos(angle)
	var low := Vector3(-run,ground,0.0)
	var t := 0.0
	while t < long-0.1:
		var step := minf(b.rng.randf_range(0.7,1.2),long-t)
		if long-(t+step) < 0.4: step = long-t
		var split := b.rng.randf_range(-0.45,0.45)*RAMP_HALF if b.rng.randf() < 0.75 else 99.0
		var parts: Array = [[-RAMP_HALF,RAMP_HALF]] if split > 50.0 else [[-RAMP_HALF,split],[split,RAMP_HALF]]
		for p: Array in parts:
			var z0: float = p[0]
			var z1: float = p[1]
			var sink := b.rng.randf_range(0.0,0.04)
			var half := Vector3(step*0.5-0.02,0.2,(z1-z0)*0.5-0.015)
			var basis := Basis(Vector3.BACK,angle)*Basis(Vector3.UP,b.rng.randf_range(-0.04,0.04))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.03,0.03))
			var top_mid := low+Vector3(0.0,0.0,(z0+z1)*0.5)+along*(t+step*0.5)
			var centre := top_mid-basis*Vector3(0.0,half.y+sink,0.0)
			b.solid(RuinKit._box(b,half),Transform3D(basis,centre),RuinKit._stone(b,b.rng.randf_range(0.9,1.12)),false,true,[],-1,1.6)
		t += step
	# The heap under: courses of fallen walling stepping down to the turf.
	var heap := func(px: float) -> float: return ground+clampf((px+run)*tan(angle)-0.45,0.2,rise-0.5)
	RuinKit._courses(b,Transform3D.IDENTITY,-run+0.6,-0.2,ground-Aqueduct.FOOTING,heap,RAMP_HALF-0.12,Callable(),0.5)
	# Loose blocks spilled at its foot and beside it on the turf.
	for i in range(7):
		var s := Vector3(b.rng.randf_range(0.25,0.5),b.rng.randf_range(0.18,0.32),b.rng.randf_range(0.3,0.6))
		var side := -1.0 if b.rng.randf() < 0.5 else 1.0
		var at := Vector3(-run+b.rng.randf_range(-1.6,run*0.35),ground+s.y*0.6,side*(RAMP_HALF+b.rng.randf_range(0.2,1.4)))
		b.solid(RuinKit._box(b,s),Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,b.rng.randf_range(-0.3,0.3)),at),RuinKit._stone(b,0.95))
	for i in range(3): b.hang(Vector3(b.rng.randf_range(-run*0.6,-1.0),0.0,b.rng.randf_range(-1.0,1.0)*RAMP_HALF),b.rng.randf_range(0.6,1.4),true)
	var node := b.finish()
	var body := node.get_node_or_null("Body") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "Body"
		node.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(long+0.8,0.4,RAMP_HALF*2.0-0.1)
	var holder := CollisionShape3D.new()
	holder.name = "Walk"
	holder.shape = shape
	var normal := Vector3(-sin(angle),cos(angle),0.0)
	var surface_mid := low+along*(long-0.8)*0.5
	holder.transform = Transform3D(Basis(Vector3.BACK,angle),surface_mid+normal*(WALK_LIFT-0.2))
	body.add_child(holder)
	return node

## A lost pier's lower half hanging in the gap: its shaft from `foot` up to
## `top` (under the base), the top broken off ragged, a stone or two of the
## courses over it still standing on its north half, the fallen arch's
## voussoirs lodged on it, its foot torn.
static func _stump(seed_value: int, top: float, foot: float) -> Node3D:
	var b := _builder(seed_value,"BridgeStump")
	Aqueduct._pier(b,0.0,foot,Art.spring(),0.0,PIER,0.0,top,false)
	_torn_foot(b,0.0,foot,PIER)
	var hx := PIER.x*0.5
	var hz := PIER.y*0.5
	# The broken head: stones of the next course or two on its north half,
	# fewer going up.
	for c in range(2):
		var y0 := top+0.5*c
		for i in range(3):
			if b.rng.randf() < 0.3+0.3*c: continue
			var half := Vector3(hx*b.rng.randf_range(0.3,0.5),0.24,hz*b.rng.randf_range(0.18,0.3))
			var at := Vector3(b.rng.randf_range(-hx+half.x,hx-half.x),y0+0.25,-hz+half.z+float(i)*hz*0.45)
			var cut: Array[Plane] = [Plane(Vector3(b.rng.randf_range(-0.7,0.7),1.0,b.rng.randf_range(0.2,0.8)).normalized(),b.rng.randf_range(-0.05,0.15))]
			b.solid(RuinKit._box(b,half),RuinKit._settle(b,at,0.5),RuinKit._stone(b,1.0),true,true,cut)
	# The fallen arch's voussoirs lodged on its head.
	for i in range(2):
		var s := Vector3(b.rng.randf_range(0.22,0.3),b.rng.randf_range(0.35,0.5),b.rng.randf_range(0.5,0.8))
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.BACK,b.rng.randf_range(0.6,1.2))
		b.solid(RuinKit._box(b,s),Transform3D(tumble,Vector3(b.rng.randf_range(-0.5,0.5),top+0.3,b.rng.randf_range(0.0,0.9))),RuinKit._stone(b,1.02))
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

## A lone pier of the line: hanging (its foot at `foot`), standing to its
## springing, both arches' springers standing on it under low ragged stubs
## of walling, everything over them fallen.
## The side that kept more (its way, `long`) carries its springer and a
## chunk of spandrel walling well up toward the deck; the other only a
## short springer under a low stub, so it reads as a pier of the line
## whose spans fell, not a fork.
static func _lone_pier(seed_value: int, label: String, foot: float, sp: float, radius: float) -> Node3D:
	var b := _builder(seed_value,label,GROWTH_LONE)
	var long := 1.0 if b.rng.randf() < 0.5 else -1.0
	var high := sp+b.rng.randf_range(3.4,4.4)
	_hanging_pier(b,0.0,foot,sp,high)
	_torn(b,0.0,long,long*(PIER.x*0.5+Art.HALF+b.rng.randf_range(-0.4,0.6)),sp,radius,high)
	_torn(b,0.0,-long,-long*(PIER.x*0.5+b.rng.randf_range(1.6,2.4)),sp,radius,sp+b.rng.randf_range(1.6,2.4))
	return b.finish()

## A walkable span (`xs` its piers' x in its frame, `foots` how deep each
## hangs under the base, `w`..`e` its torn ends): its piers hanging, the
## arches between them, a springer and a stub of walling torn off past each
## end pier, the deck over all of it.
static func _span(seed_value: int, label: String, xs: Array, foots: Array, w: float, e: float, sp: float, radius: float, wall_top: float, growth := 1.0) -> Node3D:
	var b := _builder(seed_value,label,growth)
	var n := xs.size()
	for k in range(n): _hanging_pier(b,float(xs[k]),float(foots[k]),sp,wall_top)
	for k in range(n-1): _arch(b,(float(xs[k])+float(xs[k+1]))*0.5,sp,radius,wall_top)
	_torn(b,float(xs[0]),-1.0,w,sp,radius,wall_top)
	_torn(b,float(xs[n-1]),1.0,e,sp,radius,wall_top)
	_deck(b,w,e,true,true)
	for i in range(int((e-w)*0.38)):
		b.hang(Vector3(b.rng.randf_range(w+1.0,e-1.0),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(0.8,2.8),true)
	var node := b.finish()
	_walk_box(node,w+WALK_SHORT,e-WALK_SHORT)
	return node

## A broken arcade, its deck fallen (`xs` its piers, `foots` how deep they
## hang, `w`..`e` its torn ends): the piers hanging, the arches between
## them, the walling over them broken down to a ragged line short of the
## deck (the arch's crown showing where it went lowest), torn off past each
## end pier.
static func _arcade(seed_value: int, xs: Array, foots: Array, w: float, e: float, sp: float, radius: float, wall_top: float) -> Node3D:
	var b := _builder(seed_value,"BridgeArcade3",GROWTH_FAR)
	var n := xs.size()
	var crown := sp+RuinKit._rise(Art.HALF,radius)+RuinKit.ORDER*2.0
	var ragged := RuinKit._ruin_line(b,w,e,0.0,1.0,1.0)
	var low := wall_top-0.6
	var top := func(x: float) -> float: return lerpf(crown+0.2,low,float(ragged.call(clampf(x,w,e))))
	for k in range(n): _hanging_pier(b,float(xs[k]),float(foots[k]),sp,low)
	for k in range(n-1): _arch(b,(float(xs[k])+float(xs[k+1]))*0.5,sp,radius,low,FACE-0.1,top)
	_torn(b,float(xs[0]),-1.0,w,sp,radius,low-0.5)
	_torn(b,float(xs[n-1]),1.0,e,sp,radius,low-0.8)
	for i in range(5):
		b.hang(Vector3(b.rng.randf_range(w+1.0,e-1.0),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(1.0,3.0),true)
	return b.finish()

## Span 2 (its frame's x from its leg's west end; `mid` its middle): the
## lower arcade (SPAN2_PIERS hanging, four arches, its deck at Art.DECK, as
## span 1's, torn off past its end piers, parapets only on its stretch west
## of the upper tier), the upper arcade on it from pier 1 (its piers over
## the lower ones, three drop arches, its deck span2_up over the lower's,
## torn at both ends: the west in a springer reaching toward ring 4, the
## east SLAB_SHORT short of slab 3), the broken stub of pier 0's upper
## pier under ring 4, the upper deck's silt.
static func _span2(seed_value: int, mid: float, sp: float, radius: float, wall_top: float, hang: float, keep: float) -> Node3D:
	var b := _builder(seed_value,"BridgeSpan2",GROWTH_SPAN2)
	var xs: Array = []
	for s: float in SPAN2_PIERS: xs.append(s-mid)
	var n := xs.size()
	var w := -mid
	var e := SPAN2_LONG-mid
	# The lower arcade: its piers hanging, but where one stands over the
	# outcrop (the ring route's crag under ring 4's throw) it stands on the
	# outcrop's turf on its footing, the arcade come down to the land.
	var outcrop: Vector3 = Layout.xform("ring_route/outcrop",Transform3D.IDENTITY)*RingRoute.OUTCROP
	for k in range(n):
		var at := span2_frame*Vector3(float(SPAN2_PIERS[k]),0.0,0.0)
		var on := Vector2(at.x,at.z).distance_to(Vector2(outcrop.x,outcrop.z)) < RingRoute.OUTCROP_R+PIER.y*0.5
		if on: Aqueduct._pier(b,float(xs[k]),outcrop.y-span2_frame.origin.y-Aqueduct.FOOTING,sp,wall_top,PIER,Aqueduct.CUTWATER.y,INF,true)
		else: _hanging_pier(b,float(xs[k]),-float(SPAN2_HANGS[k])*hang,sp,wall_top)
	for k in range(n-1): _arch(b,(float(xs[k])+float(xs[k+1]))*0.5,sp,radius,wall_top)
	_torn(b,float(xs[0]),-1.0,w,sp,radius,wall_top)
	var low_e := float(xs[n-1])+PIER.x*0.5+1.4
	_torn(b,float(xs[n-1]),1.0,low_e,sp,radius,wall_top)
	# Its deck: the floor all along, parapets west of the upper tier only.
	var up_w := float(xs[1])-PIER.x*0.5-Art.HALF+0.6
	var low_mid := (w+low_e)*0.5
	for side: float in [1.0,-1.0]:
		b.frame = Transform3D(Basis(Vector3.UP,0.0 if side > 0.0 else PI),Vector3(low_mid,0.0,0.0))
		Aqueduct._deck(b,0.0,(low_e-low_mid),Art.DECK,Callable(),true,DECK_HALF)
	b.frame = Transform3D.IDENTITY
	for s: float in [-1.0,1.0]:
		b.frame = Transform3D(Basis(Vector3.UP,PI),Vector3(float(xs[0])+PIER.x*0.5+Art.HALF*0.5,0.0,0.0))
		Aqueduct._parapet_run(b,0.0,float(xs[0])+PIER.x*0.5+Art.HALF*0.5-w-b.rng.randf_range(0.2,0.8),s*(DECK_HALF-PARAPET.x*0.5),Art.DECK,PARAPET.y,PARAPET.x,Callable(),true)
	b.frame = Transform3D.IDENTITY
	# The upper arcade: its piers on the lower deck over piers 1..4, the
	# drop arches between them, its deck.
	var up := span2_up
	var u_radius := Art.HALF*2.0*UPPER_PITCH
	var u_rise := RuinKit._rise(Art.HALF,u_radius)
	var u_top := Art.DECK+up-Art.SLAB
	var u_sp := maxf(Art.DECK+0.4,u_top-0.5-u_rise-RuinKit.ORDER*2.0)
	var u_size := Vector2(PIER.x,UPPER_FACE*2.0)
	var ud := UPPER_FACE-0.1
	for k in range(1,n): Aqueduct._pier(b,float(xs[k]),Art.DECK,u_sp,u_top,u_size,0.0,INF,false)
	for k in range(1,n-1): _arch(b,(float(xs[k])+float(xs[k+1]))*0.5,u_sp,u_radius,u_top,ud)
	_torn(b,float(xs[1]),-1.0,up_w,u_sp,u_radius,u_top,ud)
	_torn(b,float(xs[n-1]),1.0,e,u_sp,u_radius,u_top,ud)
	# Pier 0's upper pier: a broken stub under ring 4.
	Aqueduct._pier(b,float(xs[0]),Art.DECK,u_sp,u_top,u_size,0.0,Art.DECK+UPPER_STUB,false)
	_deck(b,up_w,e,true,true,Art.DECK+up)
	for i in range(int((e-up_w)*0.3)):
		b.hang(Vector3(b.rng.randf_range(up_w+1.0,e-1.0),0.0,b.rng.randf_range(-1.0,1.0)*FACE*0.8),b.rng.randf_range(0.8,2.6),true)
	var node := b.finish()
	span2_ends = Vector2(up_w,e)
	_walk_box(node,up_w+WALK_SHORT,e-WALK_SHORT,Art.DECK+up)
	_walk_box(node,w+WALK_SHORT,up_w-0.3)
	_silt(node,seed_value+1,SILT_2.x-mid,SILT_2.y-mid,Art.DECK+up,keep)
	return node
