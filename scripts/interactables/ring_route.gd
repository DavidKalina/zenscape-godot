extends RefCounted
## The ring route (docs/design/ring-route/ring-route-handoff.md): on foot from
## the aqueduct isle's east islet out to the bell spires (scripts/kit_isle/
## motif_sky.gd PLACES, its turf at TOP+12, 290 m east), over crags of the
## isle's own turf and rock (KitLand, as its islets) joined by the slam-spring
## slabs (bob_slab.gd), the air rings (air_ring.gd) and a rock slide:
##   1. off the islet's east edge down onto three springing slabs, slammed
##      one to the next, the third's launch sailed to the first crag;
##   2. off its far edge onto a kicker slab, its launch sailed to the
##      outcrop;
##   3. the outcrop's ring stair: slam its slab, up through four rings
##      stepping back over it, a ring's boost and one updraft each, the last sailed
##      down to the slide rock's perch, the bell spires in view;
##   4. the slide: off the perch onto the slope, slammed into it, slid down
##      to its lip at speed, and the fork: on through the standing ring at
##      the north lip (the speed kept, the bar refilled, boosted, two updrafts and
##      the sail), or a slide jump and an updraft up through the flat ring
##      over the south lip (refilled, its updrafts higher), both onto the
##      far crag;
##   5. the far crag's last slab and ring, sailed south onto the bell
##      spires' north turf.
## Under the fork's flight, a catch crag; its slab and ring stair climb back
## out to the far crag.
##
## Every gap comes from the motor as measured (scratch drivers, size 1, the
## handoff's table); offsets the motor sets go by the wanderer's size
## (WorldScale), the far ends (the islet, the bell spires) stay where they
## stand. Nothing here is on the bell spires' turf, the ferry's loop round
## their west side (airship_ferry.gd ROUTE), the plane's strip by the parked
## plane (x 107) or the hall chain's line out north.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const TurfLips = preload("res://scripts/kit_isle/turf_lips.gd")

const TOP := Art.TOP
static var S: float = WorldScale.wanderer

## --- Measured (size 1)
## A slab's spring launch (6 pumps) tops out LAUNCH_UP over its top
## LAUNCH_ON on along the stick; with the sail opened there, 44.7 m on
## back at the slab's height.
const LAUNCH_UP := 9.0
const LAUNCH_ON := 3.6
## The sail: SAIL_GLIDE m on for a metre of drop (6.55 m/s, sinking 1.5).
const SAIL_GLIDE := 4.3
## The slam needs 1.8 m of air (slam.gd LOW); each slab sits STEP_DOWN
## under the edge he steps off, so a hop off it slams.
const STEP_DOWN := 2.6
## From a ring (AirRing.POP 6 m boost, the bar refilled): his feet rise
## 6.0 m on the boost alone, 9.7 with one updraft, 12.2 with two, 13.3 with
## three, carrying his flat pace all the way (15 m/s: 37.5 m on by the top
## of two; 5 m/s: 12.5). Sailed off that, his pace bleeds slowly (15 m/s to
## 9.5 in 4 s), so a fast take carries twice as far as a slow one.
const RING_RISE := 9.7
## A ring stair as the aqueduct's (aqueduct_foot_route.gd): its slab's
## launch (7 pumps) puts his chest RING_FIRST over the slab; each ring
## RING_STEP over the last and RING_OUT back: the boost alone falls 1.5 m
## short of the next, the boost and one updraft clear it by 2.2.
const RING_FIRST := 9.1
const RING_STEP := 7.5
const RING_OUT := 3.0
const RING_SLAB_PUMPS := 7.0

## --- The route (world)
## The east islet (Art.EAST_ISLET, top Art.EAST_TOP): the start.
static var ISLET := Vector2(Art.EAST_ISLET.x,Art.EAST_ISLET.y)
const ISLET_TOP := Art.EAST_TOP
## 1: three springing slabs east of it, each CHAIN_ON on and CHAIN_RISE up
## from the last: a launch steered on is back at its slab's height 8.0 m on
## (1.18 s up to 9 m, 0.92 s down), and still 2 m over the next (the slam's
## 1.8 m and a little) about 7 m on, with the slam's catch and drive
## carrying him 0.2 s of his flat pace further.
const CHAIN_ON := 6.0
const CHAIN_RISE := 0.3
static var CHAIN_FIRST := Vector3(141.6,ISLET_TOP-STEP_DOWN,-8.5)
## The first crag: past the third slab's launch and sail.
static var CRAG1 := Vector3(186.0,TOP+2.0,-11.0)
const CRAG1_R := 6.5
## 2: the kicker slab off its east edge, its launch sailed to the outcrop.
static var OUTCROP := Vector3(233.0,TOP,-12.0)
const OUTCROP_R := 5.0
## 3: the ring stair off the outcrop's east edge, stepping back west over it.
const RINGS := 4
## 4: the slide rock: a perch, a step down onto the slope, the slope down
## east at SLOPE_DEG for SLOPE_LONG m along it to the lip, LANES wide.
static var PERCH := Vector3(292.0,TOP+24.5,-12.0)
const PERCH_R := 4.5
const PERCH_STEP := 2.0
const SLOPE_DEG := 35.0
const SLOPE_LONG := 20.0
const SLOPE_WIDE := 13.0
## The fork's rings: the standing ring A's middle RING_A_OUT past the lip
## and RING_A_UP over it (his chest a frame off the lip), its face tipped
## RING_A_TIP back; the flat ring B over the south lane RING_B_OUT on and
## RING_B_UP up (where a slide jump and an updraft off the lip at speed
## carry his chest up through it).
const LANE := 3.2
const RING_A_OUT := 1.6
const RING_A_UP := 0.7
const RING_A_TIP := 0.15
const RING_B_OUT := 3.7
const RING_B_UP := 3.6
## The far crag: at the lip's height, where only the slide's pace carries.
static var FAR_CRAG := Vector3(410.0,0.0,-2.0)
const FAR_R := 7.5
## 5: its last slab off the south edge, one ring over it, toward the bell
## spires' north turf (motif_sky.gd: bell spires at y TOP+12).
const BELL_TURF := TOP+12.0
## Under the fork's flight: the catch crag CATCH_UNDER under the lip.
const CATCH_UNDER := 11.0
static var CATCH := Vector3(333.0,0.0,-12.0)
const CATCH_R := 6.0
## Its way back out: a ring stair of CATCH_RINGS, the last's boost and two
## updrafts (12.2 m) sailed on to the far crag.
const CATCH_RINGS := 3

static func slope_top() -> float: return PERCH.y-PERCH_STEP
static func slope_run() -> float: return SLOPE_LONG*cos(deg_to_rad(SLOPE_DEG))*S
static func lip_y() -> float: return slope_top()-SLOPE_LONG*sin(deg_to_rad(SLOPE_DEG))*S
static func slope_x0() -> float: return PERCH.x+PERCH_R
static func lip_x() -> float: return slope_x0()+slope_run()

## The chain's slabs (their tops).
static func chain() -> Array:
	var out: Array = []
	for i in range(3): out.append(CHAIN_FIRST+Vector3(CHAIN_ON*S*i,CHAIN_RISE*i,-1.0*i))
	return out

static func kicker() -> Vector3:
	return Vector3(CRAG1.x+CRAG1_R+2.5,CRAG1.y-STEP_DOWN,CRAG1.z-0.5)

static func ring_slab() -> Vector3:
	return Vector3(OUTCROP.x+OUTCROP_R+1.8,OUTCROP.y-STEP_DOWN,OUTCROP.z)

static func stair(base := ring_slab(), count := RINGS) -> Array:
	var out: Array = []
	for i in range(count): out.append(base+Vector3(-RING_OUT*S*i,(RING_FIRST+RING_STEP*i)*S,0.0))
	return out

static func ring_a() -> Vector3: return Vector3(lip_x()+RING_A_OUT*S,lip_y()+RING_A_UP*S,PERCH.z-LANE)
static func ring_b() -> Vector3: return Vector3(lip_x()+RING_B_OUT*S,lip_y()+RING_B_UP*S,PERCH.z+LANE)
static func far_crag() -> Vector3: return Vector3(FAR_CRAG.x,lip_y(),FAR_CRAG.z)
static func last_slab() -> Vector3:
	var c := far_crag()
	return Vector3(c.x,c.y-STEP_DOWN,c.z+FAR_R+1.8)
static func last_ring() -> Vector3: return last_slab()+Vector3(0.0,RING_FIRST*S,0.0)
static func catch_crag() -> Vector3: return Vector3(CATCH.x,lip_y()-CATCH_UNDER,CATCH.z)
static func catch_slab() -> Vector3:
	var c := catch_crag()
	return Vector3(c.x+CATCH_R+1.6,c.y-STEP_DOWN,c.z)

## Where --foot-at=ring_route starts: on the islet, facing out east.
static func spots() -> Dictionary:
	return {
		"ring_route":[Vector3(ISLET.x+1.2,ISLET_TOP,ISLET.y),Vector2(1.0,0.0)],
		"ring_slide":[Vector3(PERCH.x,PERCH.y,PERCH.z),Vector2(1.0,0.0)],
		"ring_far":[far_crag()+Vector3(0.0,0.0,2.0),Vector2(0.0,1.0)],
	}

## The route on `study` (the aqueduct isle), its pieces on `host`
## (foot_pieces.gd).
static func build(study: Node3D, host: Node3D) -> void:
	var lands: Array = []
	# The crags.
	lands.append(_crag("RouteCrag1",CRAG1,CRAG1_R,501))
	lands.append(_crag("RouteOutcrop",OUTCROP,OUTCROP_R,502))
	lands.append(_slide_rock(503))
	lands.append(_crag("RouteFarCrag",far_crag(),FAR_R,504))
	lands.append(_crag("RouteCatch",catch_crag(),CATCH_R,505))
	for land: Node3D in lands:
		host.add_child(land)
		if study.has_method("add_turf"): study.add_turf(land)
		TurfLips.dress(land,hash(land.name))
	# 1: the slam chain.
	var c := chain()
	for i in range(c.size()): host.bob_slab(c[i],Vector3(2.3,0.7,2.2),0.3*i,510+i)
	# 2: the kicker.
	host.bob_slab(kicker(),Vector3(2.4,0.7,2.4),0.2,515)
	# 3: the ring stair.
	var rs: Node3D = host.bob_slab(ring_slab(),Vector3(2.3,0.7,2.2),0.0,516)
	rs.spring_pumps = RING_SLAB_PUMPS
	var st := stair()
	for i in range(st.size()): host.air_ring(st[i],520+i,0.3*i)
	# 4: the fork's rings: A standing across the north lane's way (its face
	# east, tipped back), B flat over the south lane.
	host.air_ring(ring_a(),530,PI*0.5,PI*0.5-RING_A_TIP)
	host.air_ring(ring_b(),531,0.0)
	# 5: the last slab and ring.
	var ls: Node3D = host.bob_slab(last_slab(),Vector3(2.3,0.7,2.2),0.1,540)
	ls.spring_pumps = RING_SLAB_PUMPS
	host.air_ring(last_ring(),541,0.4)
	# The catch crag's way back up: its slab and ring.
	var cs: Node3D = host.bob_slab(catch_slab(),Vector3(2.3,0.7,2.2),0.5,545)
	cs.spring_pumps = RING_SLAB_PUMPS
	var cst := stair(catch_slab(),CATCH_RINGS)
	for i in range(cst.size()): host.air_ring(cst[i],546+i,0.2+0.3*i)
	# Standing stones on the rest stops.
	var marks: Array = []
	for spec: Array in [[CRAG1,0.4],[OUTCROP,1.1],[PERCH,2.2],[far_crag(),0.8]]:
		var at: Vector3 = spec[0]
		marks.append({"name":"marker","at":at+Vector3(-1.6,1.7,-1.9),"size":Vector3(0.6,2.1,0.5),"yaw":float(spec[1]),"kind":"sarsen","grounded":true})
	var stones := Art.floating_stones(550,marks)
	stones.name = "RouteMarkers"
	host.add_child(stones)

## A crag: a wandering ring of turf `r` round `at` (x, z) at its height, its
## hanging rock under it (the islets' builder).
static func _crag(called: String, at: Vector3, r: float, seed_value: int) -> Node3D:
	var top := at.y
	var flat := func(_x: float, _z: float) -> float: return top
	var node := Art.island(Art.blob(Vector2(at.x,at.z),r,seed_value),r*1.4,seed_value,flat,top)
	node.name = called
	return node

## The slide rock: the perch (a round top), a step down onto the slope's
## head, the slope falling east to the lip, LANES wide, its outline round
## them all.
static func _slide_rock(seed_value: int) -> Node3D:
	var px := PERCH.x
	var pz := PERCH.z
	var x0 := slope_x0()
	var x1 := lip_x()
	var top := PERCH.y
	var head := slope_top()
	var fall := tan(deg_to_rad(SLOPE_DEG))
	var ground := func(x: float, _z: float) -> float:
		if x < x0: return top
		return head-minf(x-x0,x1-x0)*fall
	var half := SLOPE_WIDE*0.5
	var outline: Array = []
	# The perch's round west end, then along the slope's sides to the lip.
	var n := 10
	for i in range(n+1):
		var a := PI*0.5+PI*float(i)/float(n)
		outline.append(Vector2(px+cos(a)*PERCH_R*1.15,pz-sin(a)*half))
	outline.append(Vector2(x1-0.05,pz+half))
	outline.append(Vector2(x1,pz+half*0.4))
	outline.append(Vector2(x1,pz-half*0.4))
	outline.append(Vector2(x1-0.05,pz-half))
	outline.reverse()
	var spec := {"outline":outline,"depth":12.0,"seed":seed_value,"ground":ground,"top":top,
		"tone":KitLook.turf(seed_value,func(_p: Vector2) -> float: return 0.0),
		"cliffs":Rect2(px-PERCH_R*1.3,pz-half-1.0,(x0-px)+PERCH_R*1.3+1.0,SLOPE_WIDE+2.0),
		"name":"RouteSlideRock"}
	var node := KitLand.island(spec)
	node.name = "RouteSlideRock"
	return node
