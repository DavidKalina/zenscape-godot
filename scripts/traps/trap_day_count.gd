extends "res://scripts/traps/trap.gd"
## The Day-Count (card t1-day-count). A sunk calendar
## court of three nested stone rings round a still hub, over the void. The
## rings turn on footfalls, not on a clock: every footfall on the court, by
## anyone, is counted (`footfall`), each `per_click` of them clicks the
## ratchet once, and each click turns the outer ring one notch, every 2nd
## click the middle ring one notch back the other way, every 4th the inner
## ring (`gear`, `dirs`). The Olmec's step weighs a whole click
## (`olmec_clicks`). Nothing turns while everyone stands still; a jump, a
## hang, a climb or a wall run has no footfalls, so it clicks nothing.
##
## The route the rings carry: each ring has four day-stones (its stair
## stones, every quarter), each ring's a set-off higher than the last
## (inner, middle, outer: 1, 2, 3 set-offs), and two holes to the void
## between them. Out of the court is the terrace on the north side, a
## set-off over the outer stones, too tall to catch from the floor. When
## all three rings stand "in line" (a stone of each on every quarter's
## bearing: the stair window) the stones step up from the hub to the
## terrace: hub, inner stone, middle stone, outer stone, terrace, each a
## catch apart. The window comes round every 16 clicks (the gear's period
## of the quarter), the first at `clicks_to_window()` from the start; the
## calendar round (every ring's sun stone at north, every 64 clicks) also
## opens the hub's cache.
##
## The rings are AnimatableBody3Ds marked moving ground
## (pilot_physics_ground.gd `mark_moving`): stood on one, the motor's own
## `mover` carries him round with it exactly, a ledge he hangs from too. A
## click snaps a ring its notch over `snap` s (an ease out with a little
## kick), so the ratchet reads as a jump, then holds.
##
## The tell: `tell_sound` "clack" on every click (at the outer ring), "burr"
## when the middle or inner ring grinds round too, "thrum" when the next
## click completes the stair window, "round" on the calendar round. The
## glyphs: every notch has a carved day-sign and every stone a band of
## them (the city's dead grooves, CityStone); a ring's glyphs warm when it
## stands in line, all three lit is the stair, and the sun stones flare on
## the round. Weathered basalt in the city's stone; no red.
##
## Knobs: `notches` (per ring), `per_click` (footfalls a click), `olmec_clicks`
## (clicks an Olmec step makes), `gear` (clicks a notch, outer first),
## `dirs`, `start` (each ring's notch at the start), `snap` (s), `hub` (m),
## `ring` (m wide), `seam` (m between rings), `thick` (a ring's slab),
## `rise` (a set-off: the stones' step), `stone_deep`, `stone_wide`, `holes`
## (the notches open to the void), `stones` (the notches with a stone),
## `rim` (m of still pit rim round the rings), `terrace_deep`.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")

## A click: the clicks so far, the rings that moved (outer first).
signal clicked(count: int, moved: Array)

const RINGS := 3
## A ring's glyphs: dead grooves, and lit when in line (energy).
const GLOW_DEAD := 0.0
const GLOW_LINE := 0.55
const GLOW_ROUND := 1.4
const GLOW_EASE := 0.18
## The glyphs' light: a warm amber (no red).
const GLOW := Color(1.0,0.74,0.42)

## Footfalls counted (weighed), clicks made, the footfalls not yet a click.
var footfalls := 0
var clicks := 0
var _owed := 0
## Each ring's notch (signed, outer first) and its shown angle (rad of
## bearing, clockwise from north) chasing it.
var notch: Array[int] = [0,0,0]
var rings: Array[AnimatableBody3D] = []
## Each ring's stones' body (walker-only), turned with it.
var stone_bodies: Array[AnimatableBody3D] = []
var _shown: Array[float] = [0.0,0.0,0.0]
var _from: Array[float] = [0.0,0.0,0.0]
var _snap_t: Array[float] = [1.0,1.0,1.0]
var _glow: Array[ShaderMaterial] = []
var _glow_now: Array[float] = [0.0,0.0,0.0]
var cache_lid: Node3D
var cache_light: OmniLight3D
var _lid_open := 0.0
## Who stepped, counted: {who: footfalls}.
var by := {}
var still: StaticBody3D

func _init() -> void:
	super()
	trap_name = "day_count"
	cost = 3
	under = "void"
	verbs = PackedStringArray(["walk","stop","jump","climb"])

func defaults() -> Dictionary:
	var p := pilot()
	var s := p.size
	return {
		"notches":16,
		# Two strides a click: a walk clicks about every 1.5 m, a run every
		# 2.9 m (the drawn body's footfalls, scripts/pilot_figure.gd).
		"per_click":4,
		"olmec_clicks":1,
		"gear":[1,2,4],
		"dirs":[1,-1,1],
		# The first stair window at click 11, the calendar round at 27.
		"start":[5,13,10],
		"snap":0.45,
		# The hub as wide as the voussoirs' slab (run x 0.375: room to pace
		# on), a ring a quarter of a run's second (1.2 m): narrow, so a
		# stone's top is a standing jump from the next stone's lip (the
		# climb-in, CLIMB_IN, to its face: 0.9 m), as nothing on a stone may
		# walk without clicking its ring away.
		"hub":p.run*0.375,
		"ring":p.run*0.25,
		"seam":0.05*s,
		"thick":0.7*s,
		"rise":RuinKit.SET_OFF*s,
		# A stone's top two stands deep (RuinKit.STAND: room to climb on to),
		# all but a few centimetres of its ring's width.
		"stone_deep":2.0*RuinKit.STAND*s,
		"stone_wide":1.5*s,
		"stones":[0,4,8,12],
		"holes":[2,10],
		"rim":2.4*s,
		"terrace_deep":8.0*s,
		"terrace_wide":18.0*s,
	}

# --- Sizes --------------------------------------------------------------------------

func n() -> int:
	return int(knob("notches"))

func step_angle() -> float:
	return TAU/float(n())

## Ring k's inner and outer radius (0 outer, 2 inner).
func ring_r(k: int) -> Vector2:
	var hub := float(knob("hub"))
	var w := float(knob("ring"))
	var from_in := RINGS-1-k
	return Vector2(hub+w*from_in+float(knob("seam")),hub+w*(from_in+1))

func ring_mid(k: int) -> float:
	var r := ring_r(k)
	return (r.x+r.y)*0.5

## Ring k's stones' top (inner 1 set-off, middle 2, outer 3).
func stone_top(k: int) -> float:
	return float(knob("rise"))*float(RINGS-k)

func outer_r() -> float:
	return ring_r(0).y

## How far north of the centre the terrace's face stands: the outer stones'
## outer face plus the same gap the stones keep between rings.
func terrace_face() -> float:
	var gap := float(knob("ring"))-float(knob("stone_deep"))
	return ring_mid(0)+float(knob("stone_deep"))*0.5+gap

func terrace_top() -> float:
	return float(knob("rise"))*float(RINGS+1)

func rim_r() -> float:
	return outer_r()+float(knob("seam"))+float(knob("rim"))

## The court's centre (local): the way in is the south rim's edge.
func centre() -> Vector3:
	return Vector3(0.0,0.0,-rim_r())

func length() -> float:
	return rim_r()+terrace_face()+float(knob("terrace_deep"))

func footprint() -> Rect2:
	var r := rim_r()
	return Rect2(-r,-length(),2.0*r,length())

func run_up() -> float:
	return pilot().run*1.5

## Out: on the terrace, a stand in from its lip.
func exit() -> Transform3D:
	return global_transform*Transform3D(Basis.IDENTITY,centre()+Vector3(0.0,terrace_top(),-terrace_face()-1.5))

## The bearing's way (clockwise from north, -z).
static func way(bearing: float) -> Vector3:
	return Vector3(sin(bearing),0.0,-cos(bearing))

# --- Building -----------------------------------------------------------------------

func build() -> void:
	CityStone.warm()
	for k in RINGS: _build_ring(k)
	_build_still()
	reset()

func _build_ring(k: int) -> void:
	var body := AnimatableBody3D.new()
	body.name = "Ring%d" % k
	body.sync_to_physics = false
	PhysicsGround.mark_moving(body)
	body.position = centre()
	add_child(body)
	var m := CityStone.Mesher.new(CityStone.stone_colour())
	var r := ring_r(k)
	var nn := n()
	var a := step_angle()
	var holes: Array = knob("holes")
	var stones: Array = knob("stones")
	var thick := float(knob("thick"))
	# Each notch its own block, cut in pieces no longer than about a metre
	# and a half along its outer edge so the round reads round.
	var pieces := maxi(1,ceili(r.y*a/1.6))
	for j in nn:
		if holes.has(j): continue
		for q in pieces:
			var a0 := (float(j)-0.5+float(q)/pieces)*a
			var a1 := (float(j)-0.5+float(q+1)/pieces)*a
			var tone := 0.9+0.12*fposmod(sin(float(j*7+k*3)*12.9898)*43758.5,1.0)
			m.solid(_sector(r.x,r.y,a0,a1,-thick,0.0),-thick,tone)
			_shape(body,_hull(_sector(r.x,r.y,a0,a1,-thick,0.0,INF,float(knob("seam")))))
		# The day-sign: one carved glyph near the outer edge, each its own.
		var mid := float(j)*a
		var t := Vector3(cos(mid),0.0,sin(mid))
		var long := minf(CityStone.RUNE_CELL,r.y*a*0.45)
		var hh := minf(CityStone.RUNE_H,(r.y-r.x)*0.4)
		var foot := way(mid)*(r.y-0.12)
		m.runes(foot-t*long*0.5,foot+t*long*0.5,-way(mid),Vector3.UP,float(j*13+k*101),hh)
	# The day-stones: a block on each of its quarters, its glyphs round it.
	# Their own body, turned with the ring, walker-only (scripts/
	# walker_only.gd): the Olmec barges through them as it does a walker's
	# cresset, so the court is floor to him and his steps can count.
	var held := AnimatableBody3D.new()
	held.name = "Ring%dStones" % k
	held.sync_to_physics = false
	PhysicsGround.mark_moving(held)
	WalkerOnly.mark(held)
	held.position = centre()
	add_child(held)
	stone_bodies.append(held)
	var deep := float(knob("stone_deep"))
	var wide := float(knob("stone_wide"))
	var top := stone_top(k)
	for j: int in stones:
		var mid := float(j)*a
		var xf := Transform3D(Basis(Vector3.UP,-mid),way(mid)*ring_mid(k)+Vector3.UP*top*0.5)
		# The sun stone (notch 0) a shade paler: the one the round lines up.
		var pts := m.solid(CityStone.box(xf,Vector3(wide*0.5,top*0.5,deep*0.5),0.06),0.0,1.12 if j == 0 else 0.95)
		_shape(held,pts)
		var t := Vector3(cos(mid),0.0,sin(mid))
		for side: float in [-1.0,1.0]:
			var face := way(mid)*(ring_mid(k)+side*(deep*0.5))
			var band_h := minf(CityStone.RUNE_H,top-0.5)
			var y0 := top-band_h-0.25
			m.runes(face-t*wide*0.4+Vector3.UP*y0,face+t*wide*0.4+Vector3.UP*y0,Vector3.UP,way(mid)*side,float(j*31+k*7+(5 if side > 0.0 else 0)),band_h)
	var mesh := MeshInstance3D.new()
	mesh.name = "Stone"
	var glow: ShaderMaterial = (CityStone._runes as ShaderMaterial).duplicate()
	glow.set_shader_parameter("energy",GLOW_DEAD)
	glow.set_shader_parameter("glow",GLOW)
	_glow.append(glow)
	mesh.mesh = m.mesh(CityStone.wear("stair"),glow)
	body.add_child(mesh)
	rings.append(body)

## The planes of a ring's sector from bearing `a0` to `a1`, `r0` to `r1`
## out, `y0` to `y1` (outward normals, the convex hull Geometry3D finds).
## `grow` (m): a collider's, its inner face pushed in past the seam and its
## outer face out to the round, so no seam or chord leaves a crack a foot's
## ray falls through (the drawn stone keeps its seams).
static func _sector(r0: float, r1: float, a0: float, a1: float, y0: float, y1: float, clip := INF, grow := -1.0) -> Array:
	var half := (a1-a0)*0.5
	var mid := (a0+a1)*0.5
	var outer := r1*cos(half) if grow < 0.0 else r1+0.02
	var inner := r0 if grow < 0.0 else (r0-grow)*cos(half)-0.02
	var out: Array = [Plane(Vector3.UP,y1),Plane(Vector3.DOWN,-y0),
		Plane(way(mid),outer),
		Plane(-way(mid),-inner),
		# The sides: radial planes through the centre, facing away.
		Plane(-Vector3(cos(a0),0.0,sin(a0)),0.0),Plane(Vector3(cos(a1),0.0,sin(a1)),0.0)]
	if clip != INF: out.append(Plane(Vector3.FORWARD,clip))
	return out

## The corners of the space inside `planes`.
static func _hull(planes: Array) -> PackedVector3Array:
	var typed: Array[Plane] = []
	for p: Plane in planes: typed.append(p)
	return Geometry3D.compute_convex_mesh_points(typed)

func _shape(body: CollisionObject3D, pts: PackedVector3Array) -> void:
	if pts.size() < 4: return
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)

## The still stone: the hub (its cache), the pit rim round the rings, the
## terrace on the north.
func _build_still() -> void:
	still = StaticBody3D.new()
	still.name = "Still"
	still.position = centre()
	add_child(still)
	var m := CityStone.Mesher.new(CityStone.stone_colour())
	var thick := float(knob("thick"))
	var hub := float(knob("hub"))
	# The hub: a drum, its top flush with the rings.
	var pts := m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3.DOWN*thick*2.0),16,hub,hub,thick*2.0,0.04,PI/16.0),-thick*2.0,1.05)
	_shape(still,_hull(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3.DOWN*thick*2.0),16,hub+0.03,hub+0.03,thick*2.0,0.0,PI/16.0)))
	# Its north mark: a carved sight line toward the terrace.
	m.runes(Vector3(-0.3,0.0,-hub+0.15),Vector3(0.3,0.0,-hub+0.15),Vector3.BACK,Vector3.UP,77.0,0.6)
	# The rim: a still band of slabs round the rings, cut off by the
	# terrace's face where they meet it.
	var face := terrace_face()
	var r0 := outer_r()+float(knob("seam"))
	var r1 := rim_r()
	var deep := thick*2.5
	var a := step_angle()
	for j in n():
		for q in 2:
			var a0 := (float(j)-0.5+q*0.5)*a
			var a1 := a0+a*0.5
			m.solid(_sector(r0,r1,a0,a1,-deep,0.0,face),-deep,0.85+0.1*float((j+q)%2))
			_shape(still,_hull(_sector(r0,r1,a0,a1,-deep,0.0,face,float(knob("seam")))))
	# The terrace: the way out, a set-off over the outer stones' tops (four
	# over the floor: past any catch from it), its face toward the court.
	var tw := float(knob("terrace_wide"))
	var td := float(knob("terrace_deep"))
	var tt := terrace_top()
	var below := deep
	var xf := Transform3D(Basis.IDENTITY,Vector3(0.0,(tt-below)*0.5,-face-td*0.5))
	pts = m.solid(CityStone.box(xf,Vector3(tw*0.5,(tt+below)*0.5,td*0.5),0.08),-below,1.0)
	_shape(still,pts)
	# Its lip carved with the round's glyphs (where the stair arrives).
	m.runes(Vector3(-1.2,tt-0.9,-face),Vector3(1.2,tt-0.9,-face),Vector3.UP,Vector3.BACK,404.0,0.7)
	var mesh := MeshInstance3D.new()
	mesh.name = "StillStone"
	mesh.mesh = m.mesh(CityStone.wear("pier"),CityStone._runes)
	still.add_child(mesh)
	# The cache: a lidded box sunk in the hub, its lid slid aside on the
	# round, a warm light in it.
	var cm := CityStone.Mesher.new(CityStone.stone_colour())
	var lid := hub*0.45
	cm.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,0.12,0.0)),Vector3(lid,0.12,lid),0.04),0.0,1.15)
	cache_lid = MeshInstance3D.new()
	cache_lid.name = "CacheLid"
	(cache_lid as MeshInstance3D).mesh = cm.mesh(CityStone.wear("stair"),CityStone._runes)
	cache_lid.position = centre()
	add_child(cache_lid)
	cache_light = OmniLight3D.new()
	cache_light.name = "CacheLight"
	cache_light.light_color = GLOW
	cache_light.omni_range = hub*2.5
	cache_light.light_energy = 0.0
	cache_light.position = centre()+Vector3.UP*0.4
	add_child(cache_light)

# --- The count ----------------------------------------------------------------------

## Is `p` (world) on the court's floor: within the rings or the hub, at
## the floor or a stone's top (not falling past it, not on the terrace)?
func on_court(p: Vector3) -> bool:
	var l := to_local(p)-centre()
	var r := Vector2(l.x,l.z).length()
	return r <= outer_r()+0.1 and l.y > -0.6 and l.y < stone_top(0)+0.6

## A footfall at `p` (world) by `who` ("wanderer", "olmec"), `weight`
## footfalls' worth (the Olmec's step a click's: `olmec_step`). Counted
## only on the court; returns whether it was. Clicks come of it.
func footfall(p: Vector3, who: String, weight := 1) -> bool:
	if not on_court(p): return false
	footfalls += weight
	by[who] = int(by.get(who,0))+weight
	_owed += weight
	var per := maxi(int(knob("per_click")),1)
	while _owed >= per:
		_owed -= per
		click(p)
	return true

## The Olmec's step at `p`: a click's worth of footfalls (`olmec_clicks`).
func olmec_step(p: Vector3) -> bool:
	return footfall(p,"olmec",maxi(int(knob("per_click")),1)*maxi(int(knob("olmec_clicks")),1))

## One click of the ratchet: the outer ring a notch, the gear's others.
func click(at := Vector3.INF) -> void:
	clicks += 1
	var gear: Array = knob("gear")
	var dirs: Array = knob("dirs")
	var moved: Array = []
	for k in RINGS:
		if clicks%maxi(int(gear[k]),1) != 0: continue
		notch[k] += int(dirs[k])
		_from[k] = _shown[k]
		_snap_t[k] = 0.0
		moved.append(k)
	var where := at if at != Vector3.INF else to_global(centre())
	tell_sound(&"clack",where)
	if moved.size() > 1: tell_sound(&"burr",to_global(centre()))
	if round_aligned(): tell_sound(&"round",to_global(centre()))
	elif in_window(): tell_sound(&"stair",to_global(centre()))
	elif clicks_to_window() == 1: tell_sound(&"thrum",to_global(centre()))
	clicked.emit(clicks,moved)

## Ring k's notch at click count `c` (from the start).
func notch_at(k: int, c: int) -> int:
	var start: Array = knob("start")
	var gear: Array = knob("gear")
	var dirs: Array = knob("dirs")
	return int(start[k])+int(dirs[k])*(c/maxi(int(gear[k]),1))

## Ring k's turn now in notches from as built, 0 to notches-1 (its
## `start` and the clicks since): its stone j is at north when j + pos is
## a whole turn.
func pos(k: int) -> int:
	return posmod(int(knob("start")[k])+notch[k],n())

## Ring k stands in line: one of its stones on every stone bearing (its
## notch at north is a stone's, read round its stones' spacing).
func in_line(k: int, at := -1) -> bool:
	var p := posmod(notch_at(k,at),n()) if at >= 0 else pos(k)
	var stones: Array = knob("stones")
	for j: int in stones:
		if posmod(j+p,n()) == 0: return true
	return false

## The stair: every ring in line (`at`: a click count, or now).
func in_window(at := -1) -> bool:
	for k in RINGS:
		if not in_line(k,at): return false
	return true

## The calendar round: every ring's sun stone (notch 0) at north.
func round_aligned(at := -1) -> bool:
	for k in RINGS:
		var p := posmod(notch_at(k,at),n()) if at >= 0 else pos(k)
		if p != 0: return false
	return true

## Clicks until the stair window (0: it is now), or -1 within a round.
func clicks_to_window() -> int:
	for d in range(0,n()*8):
		if in_window(clicks+d): return d
	return -1

## Footfalls until the next click.
func footfalls_to_click() -> int:
	return maxi(int(knob("per_click")),1)-_owed

## The top middle (world) of ring k's stone nearest the bearing `quarter`
## quarters round from north (0 north, 1 east, ...), as the ring stands now.
func stone_point(k: int, quarter := 0) -> Vector3:
	var stones: Array = knob("stones")
	var best := INF
	var at := Vector3.ZERO
	for j: int in stones:
		var bearing := float(j)*step_angle()+_shown[k]
		var d := absf(angle_difference(bearing,TAU*0.25*quarter))
		if d < best:
			best = d
			at = way(bearing)*ring_mid(k)
	return to_global(centre()+at+Vector3.UP*stone_top(k))

## Ring k's turn now (rad of bearing, clockwise from north), as drawn.
func shown(k: int) -> float:
	return _shown[k]

# --- Stepping -----------------------------------------------------------------------

func _target(k: int) -> float:
	return float(int(knob("start")[k])+notch[k])*step_angle()

func _physics_process(delta: float) -> void:
	if rings.is_empty(): return
	var span := maxf(float(knob("snap")),0.01)
	for k in RINGS:
		if _snap_t[k] < 1.0:
			_snap_t[k] = minf(_snap_t[k]+delta/span,1.0)
			_shown[k] = lerpf(_from[k],_target(k),_ease(_snap_t[k]))
		else: _shown[k] = _target(k)
		_pose(k)
	_tell(delta)

## A heavy stone's notch: eased in and out (smoothstep), so the floor
## lurches and settles rather than jerks.
static func _ease(u: float) -> float:
	return u*u*(3.0-2.0*u)

func _pose(k: int) -> void:
	var xf := Transform3D(Basis(Vector3.UP,-_shown[k]),centre())
	rings[k].transform = xf
	if k < stone_bodies.size(): stone_bodies[k].transform = xf

func _tell(delta: float) -> void:
	var rounded := round_aligned()
	var k_ease := 1.0-exp(-delta/GLOW_EASE)
	for k in RINGS:
		var want := GLOW_ROUND if rounded else (GLOW_LINE if in_line(k) else GLOW_DEAD)
		# A thrum's pulse on the ring that the next click lines up.
		_glow_now[k] = lerpf(_glow_now[k],want,k_ease)
		_glow[k].set_shader_parameter("energy",_glow_now[k])
	_lid_open = move_toward(_lid_open,1.0 if rounded else 0.0,delta/0.8)
	if cache_lid != null:
		cache_lid.position = centre()+Vector3(float(knob("hub"))*0.75*_lid_open,0.0,0.0)
		cache_light.light_energy = 2.5*_lid_open
	tell_sight(1.0 if in_window() else 0.0)

func reset() -> void:
	super.reset()
	footfalls = 0
	clicks = 0
	_owed = 0
	by.clear()
	for k in RINGS:
		notch[k] = 0
		_shown[k] = _target(k)
		_from[k] = _shown[k]
		_snap_t[k] = 1.0
		_glow_now[k] = 0.0
		if k < rings.size(): _pose(k)
	_lid_open = 0.0
