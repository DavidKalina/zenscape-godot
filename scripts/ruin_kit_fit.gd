extends RefCounted
## How the ruin kit's pieces fit together: each piece's **connectors**, named
## points in
## its own frame (as `RuinKit.piece` builds it, front toward +Z) with a
## facing and a kind, read off the kit's Scale constants; which kinds
## **mate**; where a **cliff lip** is; and the **runs**: an aqueduct, a
## wall or a rope bridge laid between two points on real ground, re-fitted
## whenever the ground under them changes.
##
## A connector: {name, at: Vector3, facing: Vector3, kind, mode}.
##   mode "end"   two ends meet: the same point, facings opposite (a wall's
##                ends, a channel's ends, a flight's foot onto a flight's top)
##   mode "post"  a column's axis on the ground: the same point (x, z), the
##                turn free (a pier's foot, an arch's feet: an arch set on a
##                pier stands its own pier where the pier stands)
##   mode "top"   something stands on it: any piece's foot (its origin)
## Nothing here knows the editor; the editor and scripts/kit_isle/
## motif_authored.gd read it.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")
const Relic = preload("res://scripts/ruin_kit_relic.gd")
const Keel = preload("res://scripts/ruin_kit_keel.gd")
const Torana = preload("res://scripts/ruin_kit_torana.gd")

## Which kinds mate (each way round).
const MATES := {"column":["column"],"wall_end":["wall_end"],"channel":["channel"],"aq_pier":["aq_pier"],
	"flight_top":["flight_foot"],"flight_foot":["flight_top"],"hinge":["hinge"]}

## A cliff lip: the ground falls at least LIP_DROP m within LIP_REACH m out.
const LIP_DROP := 1.2
const LIP_REACH := 1.2
## How far inland of the lip an anchor or a wall stands (m).
const LIP_BACK := 0.7

static func _c(name: String, at: Vector3, facing: Vector3, kind: String, mode: String) -> Dictionary:
	return {"name":name,"at":at,"facing":facing,"kind":kind,"mode":mode}

## Piece `id`'s connectors in its own frame. `node` (the built piece, if
## there is one) gives what its seed decided: a broken pier's or a worn
## wall's top, a stump's height.
static func connectors(id: String, node: Node3D = null) -> Array:
	var top_of := func(whole: float) -> float:
		if node == null: return whole
		var box := _mesh_box(node)
		return minf(whole,box.end.y) if box.size != Vector3.ZERO else whole
	match id:
		"pier":
			return [_c("foot",Vector3.ZERO,Vector3.FORWARD,"column","post"),
				_c("top",Vector3(0.0,top_of.call(RuinKit.SPRING),0.0),Vector3.UP,"top","top")]
		"arch":
			# Its two clustered piers (the springers over them), ARCH_SPAN
			# clear between them.
			var px := RuinKit.ARCH_SPAN*0.5+RuinKit.ORDER
			return [_c("left_springer",Vector3(-px,0.0,0.0),Vector3.LEFT,"column","post"),
				_c("right_springer",Vector3(px,0.0,0.0),Vector3.RIGHT,"column","post")]
		"wall":
			var h := RuinKit.WALL_LENGTH*0.5
			return [_c("left",Vector3(-h,0.0,0.0),Vector3.LEFT,"wall_end","end"),
				_c("right",Vector3(h,0.0,0.0),Vector3.RIGHT,"wall_end","end"),
				_c("top",Vector3(0.0,top_of.call(RuinKit.WALL_HEIGHT),0.0),Vector3.UP,"top","top")]
		"lancet_wall":
			var h := RuinKit.WINDOW_WALL.x*0.5
			return [_c("left",Vector3(-h,0.0,0.0),Vector3.LEFT,"wall_end","end"),
				_c("right",Vector3(h,0.0,0.0),Vector3.RIGHT,"wall_end","end")]
		"stairs":
			var front := ((RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING)*0.5
			return [_c("foot",Vector3(0.0,0.0,front),Vector3.BACK,"flight_foot","end"),
				_c("landing",Vector3(0.0,RuinKit.STEPS*RuinKit.RISER,-front),Vector3.FORWARD,"flight_top","end")]
		"aqueduct_span", "aqueduct_two_tier":
			var deck: float = Aqueduct.DECK if id == "aqueduct_span" else Aqueduct.DECK_HIGH
			var h: float = Aqueduct.SPAN*0.5
			return [_c("left",Vector3(-h,deck,0.0),Vector3.LEFT,"channel","end"),
				_c("right",Vector3(h,deck,0.0),Vector3.RIGHT,"channel","end")]
		"aqueduct_broken":
			var h: float = Aqueduct.SPAN*0.5
			return [_c("left",Vector3(-h,Aqueduct.DECK,0.0),Vector3.LEFT,"channel","end"),
				_c("fallen_pier",Vector3(h,0.0,0.0),Vector3.RIGHT,"aq_pier","post")]
		"aqueduct_stump":
			var tall := float(node.get_meta("height",Aqueduct.STUMP.y)) if node != null else Aqueduct.STUMP.y
			return [_c("foot",Vector3.ZERO,Vector3.FORWARD,"aq_pier","post"),
				_c("top",Vector3(0.0,tall,0.0),Vector3.UP,"top","top")]
		"aqueduct_end":
			return [_c("channel",Vector3(0.0,Aqueduct.DECK,0.0),Vector3.RIGHT,"channel","end")]
		"tomb_chest":
			return [_c("top",Vector3(0.0,top_of.call(RuinKit.CHEST.y),0.0),Vector3.UP,"top","top")]
		"pent_hood":
			# Its back wall's ends on the kit wall's line (a wall's end, or
			# the next hood's, bay to bay along it), and the wall walk.
			var lines := Cloister.hood_lines()
			var h := RuinKit.WALL_LENGTH*Cloister.HOOD_BAYS*0.5
			var zm: float = lines.wall_mid
			return [_c("left",Vector3(-h,0.0,zm),Vector3.LEFT,"wall_end","end"),
				_c("right",Vector3(h,0.0,zm),Vector3.RIGHT,"wall_end","end"),
				_c("top",Vector3(0.0,float(lines.wall_top),zm),Vector3.UP,"top","top")]
		"relic_nimbus":
			# Its two horns' perches (a rope hung off the high one, a bob
			# stone onto the low).
			var nl := Relic.nimbus_lines()
			return [_c("low_horn",Vector3((float(nl.low_end)+float(nl.low_start))*0.5,float(nl.low_perch),0.0),Vector3.UP,"top","top"),
				_c("high_horn",Vector3(float(nl.high_end)+0.5,float(nl.high_perch),0.0),Vector3.UP,"top","top")]
		"keel_hung_stair":
			# The hinge beam's ends where it goes into the keel (two hung
			# flights chain end to end along one hinge), and the turned
			# flight's foot (onto a ledge or a kit flight's landing) and
			# head (a kit flight's foot, or the shaft's floor).
			var hl := Keel.lines()
			var f := Keel.flight_frame()
			var d: Vector3 = hl.dir
			return [_c("hinge_foot",hl.from,-Vector3(d.x,0.0,d.z).normalized(),"hinge","end"),
				_c("hinge_head",hl.to,Vector3(d.x,0.0,d.z).normalized(),"hinge","end"),
				_c("foot",f*Vector3(0.0,0.0,Keel.FRONT),f.basis*Vector3.BACK,"flight_foot","end"),
				_c("head",f*Vector3(0.0,Keel.STEPS*Keel.RISER,Keel.BACK+Keel.head_back()),f.basis*Vector3.FORWARD,"flight_top","end")]
		"relic_torana":
			# The jamb's head (behind the lintel's root) and the lintel's top
			# near its snapped end (a pilgrim's next lintel, tier on tier).
			var tl := Torana.lines()
			var tip := float(tl.x_end)-1.0
			return [_c("jamb_top",Vector3(-Torana.JAMB.x*0.5+Torana.ROOT_BACK*0.5,Torana.JAMB_HEAD,0.0),Vector3.UP,"top","top"),
				_c("top",Vector3(tip,Torana.soffit(tl,tip)+float(tl.depth),0.0),Vector3.UP,"top","top")]
	return []

## Whether a connector of kind `a` mates one of kind `b`.
static func mates(a: String, b: String) -> bool:
	return b in (MATES.get(a,[]) as Array)

## Where a piece whose connector `mine` (its own frame) meets `theirs` (world:
## {at, facing}) stands: {at: Vector3 (its origin), turn: deg}. A post's turn
## is `turn_free` (deg): the caller's choice.
static func pose_onto(mine: Dictionary, theirs: Dictionary, turn_free := 0.0) -> Dictionary:
	var turn := turn_free
	if str(mine.mode) == "end":
		# Its facing turned to point back along theirs.
		var want := -(theirs.facing as Vector3)
		var have: Vector3 = mine.facing
		turn = rad_to_deg(atan2(want.x,want.z)-atan2(have.x,have.z))
	var basis := Basis(Vector3.UP,deg_to_rad(turn))
	var at: Vector3 = (theirs.at as Vector3)-basis*(mine.at as Vector3)
	return {"at":at,"turn":fposmod(turn,360.0)}

## The meshes' box of a built piece (its frame).
static func _mesh_box(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n: Node in node.find_children("*","MeshInstance3D",true,false):
		var m := n as MeshInstance3D
		if m.mesh == null: continue
		var b := m.transform*m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

# --- Cliff lips --------------------------------------------------------------------

## The cliff lip nearest `p` (x, z) within `reach` m on ground `g`
## (Callable(x, z) -> y) inside `outline` (Array of Vector2; past it the
## ground is the void): {at: Vector2 (on the lip's top), out: Vector2 (the
## way down, unit), drop: m} or {}.
## `highest`: the highest lip within reach (a bank's top over the steps
## of a stepped ravine wall), the nearest of those within 0.3 m of it.
static func lip_near(g: Callable, p: Vector2, reach := 4.0, outline: Array = [], highest := false) -> Dictionary:
	var poly := PackedVector2Array(outline)
	var best := {}
	var near := INF
	var top := -INF
	var step := 0.5
	var n := int(ceil(reach/step))
	for i in range(-n,n+1):
		for j in range(-n,n+1):
			var c := p+Vector2(i,j)*step
			var d := c.distance_to(p)
			if d > reach or (d >= near and not highest): continue
			if not poly.is_empty() and not Geometry2D.is_point_in_polygon(c,poly): continue
			var here := float(g.call(c.x,c.y))
			var most := 0.0
			var out := Vector2.ZERO
			for k in range(12):
				var dir := Vector2.from_angle(TAU*k/12.0)
				var q := c+dir*LIP_REACH
				var fall := INF if not poly.is_empty() and not Geometry2D.is_point_in_polygon(q,poly) else here-float(g.call(q.x,q.y))
				if fall > most:
					most = fall
					out = dir
			if most < LIP_DROP: continue
			if highest:
				var higher := here > top+0.3
				var level := absf(here-top) <= 0.3
				if not higher and not (level and d < near): continue
				if higher: top = here
			near = d
			best = {"at":c,"out":out,"drop":most}
	return best

# --- Runs ------------------------------------------------------------------------

## An aqueduct run's plan from `from` to `to` (x, z) on ground `g` (world):
## the head at `from`, spans SPAN apart toward `to` (the far end snapped to
## a whole number of spans), a second head turned round at the far end.
## The deck stands level: DECK over the lowest ground under the run, but no
## more than half DECK over the higher end; where the ground falls more than
## DECK + TWO_TIER_MORE under it a span is two-tier (its deck kept); and
## never under DECK_OVER over the ground between the heads.
## {origin: Vector3 (the run's frame: x along the run, y at the deck less
## DECK), dir: Vector2, count, deck: world y, spans: [{x, kind, y (frame)}],
## length}.
const TWO_TIER_MORE := 2.0
## The deck stands at least DECK_OVER m over the ground between the heads,
## HEAD_ROOM m in from each end (the heads butt into the land there).
const DECK_OVER := 1.0
const HEAD_ROOM := 3.0
static func aqueduct_plan(from: Vector2, to: Vector2, g: Callable) -> Dictionary:
	var dir := (to-from).normalized() if to.distance_to(from) > 0.01 else Vector2.RIGHT
	var count := maxi(1,roundi(from.distance_to(to)/Aqueduct.SPAN))
	var length: float = count*Aqueduct.SPAN
	var across := Vector2(-dir.y,dir.x)
	var low := INF
	var t := 0.0
	while t <= length+0.01:
		for s: float in [-1.0,0.0,1.0]:
			var q := from+dir*t+across*s*Aqueduct.DECK_WIDTH*0.5
			low = minf(low,float(g.call(q.x,q.y)))
		t += 1.0
	var far := from+dir*length
	var ends := maxf(float(g.call(from.x,from.y)),float(g.call(far.x,far.y)))
	# Never buried: over the highest ground between the heads (a hill raised
	# under it lifts the deck; the deep spans go two-tier).
	var high := -INF
	t = HEAD_ROOM
	while t <= length-HEAD_ROOM+0.01:
		var q := from+dir*t
		high = maxf(high,float(g.call(q.x,q.y)))
		t += 1.0
	var deck := maxf(minf(low+Aqueduct.DECK,ends+Aqueduct.DECK*0.5),high+DECK_OVER)
	var spans: Array = []
	for i in range(count):
		var x := Aqueduct.SPAN*(i+0.5)
		var under := INF
		for f: float in [-0.5,-0.25,0.0,0.25,0.5]:
			var q := from+dir*(x+f*Aqueduct.SPAN)
			under = minf(under,float(g.call(q.x,q.y)))
		var tall: bool = deck-under > Aqueduct.DECK+TWO_TIER_MORE
		spans.append({"x":x,"kind":"aqueduct_two_tier" if tall else "aqueduct_span","y":(Aqueduct.DECK-Aqueduct.DECK_HIGH) if tall else 0.0})
	return {"origin":Vector3(from.x,deck-Aqueduct.DECK,from.y),"dir":dir,"count":count,"deck":deck,"spans":spans,"length":length}

## The run's frame (x along it, y up, its origin the plan's).
static func plan_frame(plan: Dictionary) -> Transform3D:
	var dir: Vector2 = plan.dir
	var x := Vector3(dir.x,0.0,dir.y)
	var z := x.cross(Vector3.UP)
	return Transform3D(Basis(x,Vector3.UP,z),plan.origin)

## An aqueduct run built on ground `g` (world) from `from` to `to`: each
## span's piers grown down to the ground under it, a head capping each end.
## Its node is in world space (no transform of its own above the frame).
static func aqueduct_run(seed_value: int, weathered: float, from: Vector2, to: Vector2, g: Callable) -> Node3D:
	var plan := aqueduct_plan(from,to,g)
	var frame := plan_frame(plan)
	var root := Node3D.new()
	root.name = "AqueductRun"
	root.transform = frame
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"aqueduct fit"])
	# The ground in a child's frame at (x, y) along the run.
	var local := func(at: Transform3D) -> Callable:
		var world := frame*at
		return func(x: float, z: float) -> float:
			var w := world*Vector3(x,0.0,z)
			return float(g.call(w.x,w.z))-world.origin.y
	var head_at := Transform3D.IDENTITY
	root.add_child(_placed(Aqueduct.head(seed_value,clampf(weathered+rng.randf_range(-0.1,0.1),0.0,1.0),true,true,local.call(head_at)),head_at))
	var spans: Array = plan.spans
	for i in range(spans.size()):
		var s: Dictionary = spans[i]
		var at := Transform3D(Basis.IDENTITY,Vector3(float(s.x),float(s.y),0.0))
		var w := clampf(weathered+rng.randf_range(-0.15,0.15),0.0,1.0)
		# Each span stands its right pier (its left is the last span's or the
		# head's); the last leans on the far head; a change of kind stands both.
		var piers := 2 if i < spans.size()-1 else 0
		if i > 0 and str((spans[i-1] as Dictionary).kind) != str(s.kind): piers |= 1
		var node: Node3D
		if str(s.kind) == "aqueduct_two_tier": node = Aqueduct.two_tier(seed_value+i+1,w,piers,true,local.call(at))
		else: node = Aqueduct.span(seed_value+i+1,w,piers,true,local.call(at))
		root.add_child(_placed(node,at))
	var tail_at := Transform3D(Basis(Vector3.UP,PI),Vector3(float(plan.length),0.0,0.0))
	root.add_child(_placed(Aqueduct.head(seed_value+97,clampf(weathered+rng.randf_range(-0.1,0.1),0.0,1.0),true,true,local.call(tail_at)),tail_at))
	root.set_meta("plan",plan)
	root.set_meta("ends",[{"at":frame*Vector3(0.0,Aqueduct.DECK,0.0),"facing":-frame.basis.x,"kind":"channel"},{"at":frame*Vector3(float(plan.length),Aqueduct.DECK,0.0),"facing":frame.basis.x,"kind":"channel"}])
	return root

static func _placed(node: Node3D, at: Transform3D) -> Node3D:
	node.transform = at
	return node

## A wall run's plan: walls WALL_LENGTH apart from `from` toward `to`, each
## seated on the lowest ground under it (`sink` in): [{at: Vector3, turn}].
static func wall_plan(from: Vector2, to: Vector2, g: Callable, sink := 0.15) -> Array:
	var dir := (to-from).normalized() if to.distance_to(from) > 0.01 else Vector2.RIGHT
	var count := maxi(1,roundi(from.distance_to(to)/RuinKit.WALL_LENGTH))
	var across := Vector2(-dir.y,dir.x)
	var turn := rad_to_deg(atan2(-dir.y,dir.x))
	var out: Array = []
	for i in range(count):
		var mid := from+dir*RuinKit.WALL_LENGTH*(i+0.5)
		var low := INF
		for f: float in [-0.5,0.0,0.5]:
			for s: float in [-1.0,1.0]:
				var q := mid+dir*f*RuinKit.WALL_LENGTH+across*s*RuinKit.WALL_THICK*0.5
				low = minf(low,float(g.call(q.x,q.y)))
		out.append({"at":Vector3(mid.x,low-sink,mid.y),"turn":turn})
	return out

static func wall_run(seed_value: int, weathered: float, from: Vector2, to: Vector2, g: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = "WallRun"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"wall fit"])
	var plan := wall_plan(from,to,g)
	for i in range(plan.size()):
		var p: Dictionary = plan[i]
		var node := RuinKit.wall(seed_value+i,clampf(weathered+rng.randf_range(-0.15,0.15),0.0,1.0))
		node.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(p.turn))),p.at)
		root.add_child(node)
	return root

## A rope bridge end's lip on the line from `p` toward `toward` (x, z) on
## ground `g`: where the bank's top breaks into the gap the bridge crosses.
## Each point from BRIDGE_LIP_BACK behind `p` to halfway to `toward`
## (BRIDGE_LIP_AHEAD at most) is a lip where the ground falls at least
## BRIDGE_LIP_FALL ahead, steeply (BRIDGE_LIP_STEEP a metre, and steeper by
## far than the ground climbs behind it: a hillside or the face of a wall's
## next step up is no lip). The deeper the fall ahead, the higher (a stepped
## wall's top, not a ledge partway down) and the nearer `p`, the better.
## None: `p`. Outside `outline` (the isle's, x z) is the void.
const BRIDGE_LIP_BACK := 4.0
const BRIDGE_LIP_AHEAD := 4.0
const BRIDGE_LIP_FALL := 0.6
const BRIDGE_LIP_STEEP := 0.8
static func bridge_lip(g: Callable, p: Vector2, toward: Vector2, outline: Array = []) -> Vector2:
	if p.distance_to(toward) < 1.0: return p
	var u := (toward-p).normalized()
	var poly := PackedVector2Array(outline)
	var h := func(q: Vector2) -> float:
		if not poly.is_empty() and not Geometry2D.is_point_in_polygon(q,poly): return -1000.0
		return float(g.call(q.x,q.y))
	var base := float(h.call(p))
	var best := p
	var score := -INF
	var reach := minf(BRIDGE_LIP_AHEAD,p.distance_to(toward)*0.5)
	var t := -BRIDGE_LIP_BACK
	while t <= reach+0.001:
		var q := p+u*t
		var y := float(h.call(q))
		if y > -999.0:
			var fall := 0.0
			var steep := 0.0
			for s: float in [0.3,0.6,1.0,1.5,2.0,2.5]:
				var f := y-float(h.call(q+u*s))
				fall = maxf(fall,f)
				if s <= 1.0: steep = maxf(steep,f/s)
			var climb := 0.0
			for s: float in [0.5,1.0,1.5,2.0]:
				climb = maxf(climb,(float(h.call(q-u*s))-y)/s)
			if fall >= BRIDGE_LIP_FALL and steep >= maxf(BRIDGE_LIP_STEEP,climb*2.5):
				var k := minf(fall,6.0)*0.4+clampf(y-base,-3.0,4.0)-absf(t)*0.25
				if k > score:
					score = k
					best = q
		t += 0.1
	return best

## Both ends of a rope bridge clicked (or saved) at `from` and `to`: each
## on its bank's lip along the line between them (`bridge_lip`), the second
## looked for again along the line the first lip makes.
static func bridge_ends(from: Vector2, to: Vector2, g: Callable, outline: Array = []) -> Array:
	var a := bridge_lip(g,from,to,outline)
	var b := bridge_lip(g,to,a,outline)
	a = bridge_lip(g,a,b,outline)
	return [a,b]

## A rope bridge anchor's seat. The sill (RuinKit.bridge_anchor's: it
## reaches BRIDGE_SILL_FRONT before the anchor's origin, BRIDGE_SILL_BACK
## behind, BRIDGE_SEAT_HALF to each side) stands with its top BRIDGE_SINK
## under the highest ground under it; where the ground under it falls
## further than the sill is deep, a coursed plinth grows down under it to
## BRIDGE_FOOT under the lowest (`bridge_run`), so no part of it stands in
## the air. The ground under it may vary by BRIDGE_FLAT at most, the
## leveller the better. Its front wants to stand BRIDGE_SEAT_IN short of
## the real edge (where the ground first falls BRIDGE_EDGE_FALL under the
## seat), the deck's end at the lip. A ravine's lip is often a narrow
## tongue or a wobbling, slanted edge, so the seat is looked for round the
## lip (BRIDGE_LOOK_BACK inland, BRIDGE_LOOK_SIDE to each side). With
## `outline` (the isle's, x z), no corner stands off the isle.
const BRIDGE_SEAT_IN := 0.25
const BRIDGE_EDGE_FALL := 0.5
static var BRIDGE_SEAT_HALF: float = Footbridge.WIDTH*0.5+0.8
const BRIDGE_SILL_FRONT := 0.2
const BRIDGE_SILL_BACK := 0.6
const BRIDGE_FLAT := 1.2
const BRIDGE_SINK := 0.05
const BRIDGE_FOOT := 0.3
## How deep the anchor's own sill reaches under its top (RuinKit.bridge_anchor).
const BRIDGE_SILL_DEEP := 0.21
## Nothing rises more than BRIDGE_RISE over the seat between the sill and the
## edge (the deck would run into it); BRIDGE_BEHIND behind the sill the bank
## is within BRIDGE_RISE of the seat (he walks on and off without a climb or
## a drop).
const BRIDGE_RISE := 0.35
const BRIDGE_BEHIND := 0.8
const BRIDGE_LOOK_BACK := 3.0
const BRIDGE_LOOK_SIDE := 1.5
## The edge counts as met within BRIDGE_EDGE_NEAR of the sill's front.
const BRIDGE_EDGE_NEAR := 0.8
## Nothing that meets the edge that near (a terrace's narrow ledges):
## looked for again BRIDGE_LOOK_FAR inland.
const BRIDGE_LOOK_FAR := 6.0

## The lowest and highest ground under a seat at `at` facing `out` ([low,
## high]; [] when a point is off `poly`). `dense`: a 9 x 5 grid over the
## whole sill, else 5 x 3.
static func _seat_ground(at: Vector2, out: Vector2, g: Callable, poly: PackedVector2Array, dense := false) -> Array:
	var across := Vector2(-out.y,out.x)
	var low := INF
	var high := -INF
	var fs: Array = [-1.0,-0.75,-0.5,-0.25,0.0,0.25,0.5,0.75,1.0] if dense else [0.0,-1.0,1.0,-0.5,0.5]
	var zs: Array = [BRIDGE_SILL_FRONT,0.0,-0.2,-0.4,-BRIDGE_SILL_BACK] if dense else [BRIDGE_SILL_FRONT,-0.2,-BRIDGE_SILL_BACK]
	for f: float in fs:
		for z: float in zs:
			var q := at+across*f*BRIDGE_SEAT_HALF+out*z
			if not poly.is_empty() and not Geometry2D.is_point_in_polygon(q,poly): return []
			var y := float(g.call(q.x,q.y))
			low = minf(low,y)
			high = maxf(high,y)
		if not dense and high-low > BRIDGE_FLAT: break
	return [low,high]

## The lowest ground on a ring BRIDGE_MESH round a seat's sill.
const BRIDGE_MESH := 0.8
static func _seat_ring_low(at: Vector2, out: Vector2, g: Callable) -> float:
	var across := Vector2(-out.y,out.x)
	var half := BRIDGE_SEAT_HALF+BRIDGE_MESH
	var front := BRIDGE_SILL_FRONT+BRIDGE_MESH
	var back := BRIDGE_SILL_BACK+BRIDGE_MESH
	var low := INF
	for i in range(9):
		var f := lerpf(-half,half,i/8.0)
		for z: float in [front,-back]:
			var q := at+across*f+out*z
			low = minf(low,float(g.call(q.x,q.y)))
	for j in range(5):
		var z := lerpf(-back,front,j/4.0)
		for f: float in [-half,half]:
			var q := at+across*f+out*z
			low = minf(low,float(g.call(q.x,q.y)))
	return low

## Where a bridge end's anchor stands for lip `lip`, the gap toward `out`
## (unit, x z), on ground `g`: {at: Vector2, y (the sill's top, the deck's
## end), low (the lowest ground under the sill), level: bool (it meets the
## edge)}. Seats that meet the edge with the bank behind walkable first,
## then those that meet it, then further edges; nowhere at all: on the lip
## itself, its plinth down to the ground (level false).
## `side` narrows the look to each side (the second pass, once the bridge's
## line is known); `back` how far inland.
static func bridge_seat(lip: Vector2, out: Vector2, g: Callable, outline: Array = [], side := BRIDGE_LOOK_SIDE, back := BRIDGE_LOOK_BACK) -> Dictionary:
	var across := Vector2(-out.y,out.x)
	var top := float(g.call(lip.x,lip.y))
	var poly := PackedVector2Array(outline)
	var best := {}
	var cost := INF
	var t := -back
	while t <= 0.6:
		var c := -side
		while c <= side+0.01:
			var at := lip+out*t+across*c
			var f := _seat_ground(at,out,g,poly)
			if not f.is_empty() and float(f[1])-float(f[0]) <= BRIDGE_FLAT:
				var y := float(f[1])-BRIDGE_SINK
				# The edge ahead of the sill's front, along the deck's line, with
				# nothing rising in the deck's way before it.
				var d := 3.0
				var clear := true
				var s := 0.0
				while s < 3.0:
					var q := at+out*(BRIDGE_SILL_FRONT+s)
					var h := float(g.call(q.x,q.y))
					if h < y-BRIDGE_EDGE_FALL:
						d = s
						break
					if h > y+BRIDGE_RISE:
						clear = false
						break
					s += 0.1
				# He walks on from behind: no step up there he can't take.
				var behind := true
				for k: float in [-0.4,0.0,0.4]:
					var q := at+across*k*BRIDGE_SEAT_HALF-out*(BRIDGE_SILL_BACK+BRIDGE_BEHIND)
					if absf(float(g.call(q.x,q.y))-y) > BRIDGE_RISE: behind = false
				if clear:
					var tier := (0 if d <= BRIDGE_EDGE_NEAR else (2 if d < 3.0 else 4))+(0 if behind else 1)
					var k := tier*100.0+absf(d-BRIDGE_SEAT_IN)*2.0+absf(c)+absf(y-top)+maxf(top-y,0.0)*1.5+(float(f[1])-float(f[0]))*2.0+absf(t)*0.2
					if k < cost:
						cost = k
						best = {"at":at,"y":y,"level":tier <= 1,"cost":k}
			c += 0.5
		t += 0.2 if side > 0.0 else 0.1
	# Nothing that meets the edge near: further inland too, the better kept.
	if (best.is_empty() or float(best.cost) >= 200.0) and back < BRIDGE_LOOK_FAR:
		var far := bridge_seat(lip,out,g,outline,side,BRIDGE_LOOK_FAR)
		if not far.is_empty() and (best.is_empty() or float(far.cost) < float(best.cost)): best = far
	if best.is_empty():
		var at := lip-out*(BRIDGE_SILL_FRONT+BRIDGE_SEAT_IN)
		var f := _seat_ground(at,out,g,PackedVector2Array(),true)
		best = {"at":at,"y":float(f[1])-BRIDGE_SINK,"level":false,"cost":INF}
	var under := _seat_ground(best.at,out,g,PackedVector2Array(),true)
	best.low = float(under[0])
	# Its top never under the ground anywhere under it.
	best.y = maxf(float(best.y),float(under[1])-BRIDGE_SINK)
	return best

## A rope bridge from lip `from` to lip `to` (x, z, on ground `g`): each end
## on its bank's lip along the line between them (`bridge_ends`: a save's
## ends, or ends whose land changed since, found again), a stone anchor
## seated just inside the real edge at each (`bridge_seat`) on a coursed
## plinth grown down to the ground where it falls away under it, the live
## rope bridge (scripts/footbridge.gd `live`) between their fronts.
static func bridge_run(seed_value: int, from: Vector2, to: Vector2, g: Callable, outline: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "BridgeRun"
	var lips := bridge_ends(from,to,g,outline)
	from = lips[0]
	to = lips[1]
	var dir := (to-from).normalized() if to.distance_to(from) > 0.01 else Vector2.RIGHT
	var seats: Array = []
	for k in range(2):
		var lip: Vector2 = from if k == 0 else to
		var out := dir if k == 0 else -dir
		seats.append(bridge_seat(lip,out,g,outline))
	# Again along the line the two seats make (a seat may have stepped to a
	# side), each seat only along it, so each sill squares to the deck.
	var first := seats.duplicate()
	for k in range(2):
		var at: Vector2 = (first[k] as Dictionary).at
		var other: Vector2 = (first[1-k] as Dictionary).at
		var out := (other-at).normalized()
		var lip: Vector2 = from if k == 0 else to
		# The lip moved onto the new line, level with the first seat.
		var seat := bridge_seat(at+out*(lip-at).dot(out),out,g,outline,0.0)
		if bool(seat.level) or not bool((first[k] as Dictionary).level): seats[k] = seat
	var ends: Array = []
	for k in range(2):
		var p: Vector2 = (seats[k] as Dictionary).at
		ends.append(Vector3(p.x,float((seats[k] as Dictionary).y),p.y))
	for k in range(2):
		var at: Vector3 = ends[k]
		var other: Vector3 = ends[1-k]
		var out := Vector2(other.x-at.x,other.z-at.z).normalized()
		var frame := Transform3D(Basis(Vector3.UP,atan2(out.x,out.y)),at)
		var seat: Dictionary = seats[k]
		var under := _seat_ground(Vector2(at.x,at.z),out,g,PackedVector2Array(),true)
		var low := minf(float(seat.low),float(under[0]))
		# The land's mesh is drawn on a grid (crisp at its cliffs), a cell's
		# triangles cutting under the ground's own curve at a lip: the foot
		# goes as low as the ground BRIDGE_MESH round the sill (a metre under
		# its own lowest at most), so the turf drawn never shows under it.
		low = minf(low,maxf(_seat_ring_low(Vector2(at.x,at.z),out,g),low-1.0))
		var spec := {"terrain":func(x: float, z: float) -> float:
			var w := frame*Vector3(x,0.0,z)
			return float(g.call(w.x,w.z))-at.y}
		# The sill's foot under the ground everywhere, else a coursed plinth
		# under it down to the lowest ground (and a little under: the land's
		# mesh cuts a lip's corner under the ground's own curve).
		if low <= at.y-BRIDGE_SILL_DEEP+0.1:
			spec.plinth = Vector3(Footbridge.WIDTH*0.5+0.75,(at.y-BRIDGE_SILL_DEEP)-(low-BRIDGE_FOOT),0.38)
			spec.plinth_z = -0.2
		var anchor := RuinKit.bridge_anchor(seed_value+k,0.4,Footbridge.WIDTH,spec)
		# The anchor's posts stand across its +Z: +Z out over the gap, to the other anchor.
		anchor.transform = frame
		anchor.name = "Anchor%d" % k
		# Its base as built, for probes (the land hides its faces under the ground).
		anchor.set_meta("base",{"plinth":spec.get("plinth",Vector3.ZERO),"plinth_z":float(spec.get("plinth_z",0.0))})
		root.add_child(anchor)
	var mesh: ArrayMesh = Footbridge.build_mesh(ends[0],ends[1],seed_value)
	var bridge: MeshInstance3D = Footbridge.live(mesh,ends[0],ends[1],seed_value)
	bridge.name = "Bridge"
	root.add_child(bridge)
	root.set_meta("ends",ends)
	root.set_meta("lips",[from,to])
	return root

## A run entry ({run, from, to, seed, weathered}) built on ground `g`.
static func build_run(r: Dictionary, g: Callable, outline: Array = []) -> Node3D:
	var from := Vector2(float(r.from[0]),float(r.from[1]))
	var to := Vector2(float(r.to[0]),float(r.to[1]))
	match str(r.run):
		"aqueduct": return aqueduct_run(int(r.seed),float(r.get("weathered",0.3)),from,to,g)
		"wall": return wall_run(int(r.seed),float(r.get("weathered",0.3)),from,to,g)
		"bridge": return bridge_run(int(r.seed),from,to,g,outline)
	return null

## A run's footprint and height span for occupancy: [Rect2 (x, z), low y, high y].
static func run_box(r: Dictionary, g: Callable) -> Array:
	var from := Vector2(float(r.from[0]),float(r.from[1]))
	var to := Vector2(float(r.to[0]),float(r.to[1]))
	var high := -INF
	var low := INF
	var far := to
	var reach := 1.5
	match str(r.run):
		"aqueduct":
			var plan := aqueduct_plan(from,to,g)
			far = from+(plan.dir as Vector2)*float(plan.length)
			high = float(plan.deck)+1.0
			reach = 4.0
		"wall":
			high = -INF
			for p: Dictionary in wall_plan(from,to,g): high = maxf(high,(p.at as Vector3).y+RuinKit.WALL_HEIGHT)
	for q: Vector2 in [from,far]:
		var y := float(g.call(q.x,q.y))
		low = minf(low,y)
		high = maxf(high,y+2.0)
	var box := Rect2(from,Vector2.ZERO).expand(far).grow(reach)
	return [box,low-1.0,high]
