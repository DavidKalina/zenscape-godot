extends "res://scripts/kit_isle/motif_greybox.gd"
## The Coliseum Pit (card: docs/design/roguelike/brainstorm/round3-olmec-
## city/motif-coliseum-pit.md), a place of the underground Olmec city: the
## city's ballcourt coliseum (CityLandmarks `court`) sunk into a broken turf
## plateau over the void, its north end snapped off into the abyss, a
## corbel gate (CityBreaks2 `maker_corbel`) bored into the terrace wall
## south-west of it, and a temple pyramid (CityLandmarks `pyramid`) on the
## high rim beyond, its shrine a true safe room. Land first: the court's
## stands are buried in turf on both sides, so it reads as a trench cut in
## the land, not a building on a plinth.
##
##   the shelf     the arrival (14.4 m over the court floor): a turf tongue
##                 flush with the east promenade, its north end fallen away
##                 (the stands' back and the court's foundation hang bare
##                 over the void there); its south end steps down in broken
##                 terraces into the gate hollow.
##   the court     the alley (floor 0) the Player owns; the west promenade
##                 the Watcher walks; the rings and their roots.
##   the hollow    the gate hollow south of the court (floor level), void
##                 on its south edge; the corbel gate in its west wall.
##   the terrace   the west terrace behind the west stands, flush with the
##                 promenade, over the corbel's roof; the shoulder's set-off
##                 steps climb from it to the high rim.
##   the high rim  the pyramid's plateau (27.2 m), rising three more steps
##                 at its north-west corner to the way out (32 m).
##   the hollow way  out of the corbel's back, a stepped gully along the
##                 island's south edge up to the high rim by the stair foot.
##
## Routes (rim in on the shelf's east end, rim out on the high rim's NW):
##   the hollow way (safe, slow)  the shelf's terraces down, the hollow,
##                 the corbel's hall, the gully, the high rim.
##   the corbel (clever)  into the court, lure the Player to the corbel's
##                 mouth; his landing brings the bay in; the heap, the
##                 broken stair, the roof, the terrace, the shoulder.
##   the far tier (clever)  into the court, up the west end zone's prisms,
##                 the rows, the Watcher's promenade, onto the terrace, the
##                 shoulder.
##
## Everything is one LAYOUT table; the land's heights are `main_ground` and
## `shelf_ground` from it.
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const CityLandmarks = preload("res://scripts/city_kit_landmarks.gd")
const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
const CorbelVault = preload("res://scripts/city_breaks/corbel_vault.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const SET_OFF := CityKit.SET_OFF
const COURSE := CityKit.COURSE
const SEED := 7700

# --- The layout: one table ----------------------------------------------------------------
## The frame: the court's alley middle at x z 0 on its floor (y 0), its
## alley along z, its broken end north (-z), its gate south (+z). You
## arrive from the east (+x) and leave to the north-west.
const LAYOUT := {
	# The land's levels (m): the shelf and the terrace flush with the
	# court's promenades (CityLandmarks: rim 8 + 4 rows = 14.4), the high
	# rim eight set-offs over them, the way out three more.
	"shelf":14.4,
	"terrace":14.4,
	# The shoulder's steps: every other one a grabbable set-off cliff, the
	# rest a turf ramp `ramp` m long (so from below it reads as land rising,
	# not a rampart).
	"shoulder":{"from_x":-58.0,"treads":[5.0,6.0,4.5,6.5,5.0,5.5,4.5,5.0],"kinds":"crccrcrc","wander":6.0,"ramp":3.2},
	# The way out: the high rim's north-east corner over the void bay, three
	# set-off rings rising toward it (the rim out on the top one).
	"out":{"at":Vector2(-108.0,-88.0),"reach":22.0,"steps":3,"tread":5.0},
	# The court (CityLandmarks court): its foundation hangs where the land
	# has gone (the north end, under the shelf's broken north edge).
	"court":{"wear":0.65,"foundation":6.0},
	# The corbel gate: its mouth (x, z) on the hollow's west wall, the hall
	# running west (its cracked bay toward the hollow), the wall's line.
	"corbel":{"mouth":Vector2(-30.0,36.0),"wear":0.55},
	# The pyramid on the high rim: its middle (x, z), its stair to +z
	# (south), its stair's fault landing (CityKit stair: 1-based; 0 none).
	"pyramid":{"at":Vector2(-172.0,-32.0),"fault":2,"wear":0.7,"foundation":3.0,
		# The berm the land makes over its platform's edge: from `inside` m
		# in from it to `out` m out, `y` m at its crest.
		"berm":{"inside":3.0,"out":10.0,"y":1.4}},
	# The gate hollow (floor level, a hair under the apron): its west wall
	# (x), held back behind the corbel's face; its north edge (z) under the
	# court's apron; the shelf's broken terraces down into it [x from, z
	# under, y].
	"hollow":{"y":-0.1,"wall":-29.5,"wall_at_corbel":-31.2,"north":23.2,
		"terraces":[[45.0,29.0,9.6],[45.0,36.0,4.8]]},
	# The hollow way: its line out of the corbel's back to the high rim,
	# its half width, the flat run before the first step, the rise.
	"gully":{"path":[Vector2(-43.0,36.0),Vector2(-58.0,47.0),Vector2(-80.0,62.0),Vector2(-108.0,69.0),Vector2(-128.0,65.0),Vector2(-148.0,60.0)],
		"half":4.6,"flat":8.0,"end_flat":6.0,"open_from":18.0,"open_to":14.0},
	# The islands' outlines (x, z), clockwise from the court's corner.
	"main_outline":[Vector2(-23.5,-27.0),Vector2(-23.5,23.2),Vector2(34.5,23.2),Vector2(34.5,19.0),Vector2(60.0,18.0),Vector2(88.0,19.5),
		Vector2(93.0,34.0),Vector2(86.0,50.0),Vector2(62.0,60.0),Vector2(32.0,64.0),Vector2(2.0,68.0),Vector2(-28.0,66.0),Vector2(-48.0,64.0),
		Vector2(-64.0,64.0),Vector2(-82.0,71.0),Vector2(-108.0,77.0),Vector2(-132.0,73.0),Vector2(-150.0,62.0),Vector2(-176.0,60.0),
		Vector2(-214.0,64.0),Vector2(-228.0,36.0),Vector2(-230.0,-20.0),Vector2(-234.0,-76.0),Vector2(-226.0,-104.0),Vector2(-196.0,-114.0),
		Vector2(-150.0,-108.0),Vector2(-114.0,-100.0),Vector2(-96.0,-80.0),Vector2(-82.0,-56.0),Vector2(-70.0,-36.0),Vector2(-58.0,-31.0),
		Vector2(-42.0,-33.0),Vector2(-30.0,-29.0)],
	"shelf_outline":[Vector2(23.5,-20.0),Vector2(31.0,-21.4),Vector2(40.0,-17.0),Vector2(52.0,-12.0),Vector2(64.0,-17.0),Vector2(80.0,-10.0),
		Vector2(91.0,2.0),Vector2(90.0,15.0),Vector2(80.0,21.0),Vector2(60.0,21.5),Vector2(34.5,21.5),Vector2(23.5,21.5)],
	# The court's bed: rock under the alley (no turf: the alley's floor is
	# over it), so the snapped end reads as the plateau's broken rock; its
	# ground under the floor.
	"bed":{"outline":[Vector2(-23.0,-21.6),Vector2(23.0,-21.6),Vector2(23.0,23.0),Vector2(-23.0,23.0)],"y":-2.0,"depth":58.0},
	# The arrival on the shelf (x, z): the rim in at its east end.
	"arrive":Vector2(82.0,14.0),
	# A tumbled chunk of the court's north end, a hard jump off its lip (its
	# outline, its ground) and a fallen drum on it.
	"fragment":{"outline":[Vector2(-7.0,-24.6),Vector2(3.0,-24.4),Vector2(8.0,-29.0),Vector2(6.0,-36.0),Vector2(-2.0,-38.0),Vector2(-8.0,-33.0)],"y":-0.5},
	# A lone column standing out of the void off the terrace's north edge
	# (its middle, radius, top).
	"stump":{"at":Vector2(-48.0,-36.7),"radius":2.6,"top":14.4},
	# Fallen column drums (cover) [x, z, radius, length, turn deg].
	"drums":[[18.0,54.0,1.6,5.0,25.0],[-14.0,54.0,1.4,4.0,-40.0],[62.0,8.0,1.5,4.4,70.0],[-104.0,22.0,1.8,5.4,10.0],[3.0,-32.5,1.3,3.6,80.0],[-123.0,56.0,1.7,4.6,-20.0],[-221.0,-10.0,1.5,4.0,40.0],[-150.0,-84.0,1.9,5.6,75.0]],
	# The keepers: the Player's beat down the alley and its end zones, the
	# Watcher's along the west promenade; each one's first look.
	"player":{"beat":[Vector3(0.0,0.0,6.0),Vector3(1.5,0.0,13.0),Vector3(0.0,0.0,21.0)],"face":Vector2(0.0,-1.0)},
	"watcher":{"beat":[Vector3(-21.4,14.4,-16.0),Vector3(-21.4,14.4,0.0),Vector3(-21.4,14.4,16.0)],"face":Vector2(1.0,0.0)},
	# Small fires lit since forever (still: they call no Olmec): the eye-line
	# to the way out [x, z, y or NAN for the ground].
	"lamps":[[-29.0,26.0,NAN],[-29.0,46.4,NAN],[-84.0,66.0,NAN],[-140.0,66.0,NAN],[-104.0,-84.0,NAN]],
}

const PLAYER_KNOBS := {"chase":1,"chase_routes":1}

# --- Where things are -----------------------------------------------------------------------

## The court's frame (the identity: the motif's frame is the court's).
static func court_xf() -> Transform3D:
	return Transform3D.IDENTITY

## The corbel's frame: its hall along world x, its cracked bay (piece -z)
## toward the hollow (+x), its floor on 0.
static func corbel_xf() -> Transform3D:
	var m: Vector2 = LAYOUT.corbel.mouth
	var b := Basis(Vector3.UP,-PI/2.0)
	return Transform3D(b,Vector3(m.x-CorbelVault.BAY_L,0.0,m.y))

## The corbel's footprint (x, z) and the hall's inside (the land is kept
## under its floor there).
static func corbel_rect() -> Rect2:
	var m: Vector2 = LAYOUT.corbel.mouth
	var o := CorbelVault.outer()
	return Rect2(m.x-2.0*CorbelVault.BAY_L,m.y-o,2.0*CorbelVault.BAY_L,2.0*o)

static func corbel_inside() -> Rect2:
	var m: Vector2 = LAYOUT.corbel.mouth
	var o := CorbelVault.outer()
	# Grown into the haunches (out to 1.2 m short of their outer faces), so
	# the land's step stands inside the stone.
	return Rect2(m.x-2.0*CorbelVault.BAY_L-1.0,m.y-o+1.6,2.0*CorbelVault.BAY_L+1.0,2.0*o-3.2)

## The pyramid's frame (its foot on the high rim).
static func pyramid_xf() -> Transform3D:
	var p: Dictionary = LAYOUT.pyramid
	return Transform3D(Basis.IDENTITY,Vector3(p.at.x,rim_y(),p.at.y))

static func rim_y() -> float:
	return float(LAYOUT.terrace)+(LAYOUT.shoulder.treads as Array).size()*SET_OFF

static func out_y() -> float:
	return rim_y()+int(LAYOUT.out.steps)*SET_OFF

# --- The land -------------------------------------------------------------------------------

## The main island's ground (motif frame): the gate hollow, the corbel's
## floor, the hollow way, the terrace, the shoulder, the high rim, the way
## out.
## The land's fixed shapes, worked out once (the ground is asked some
## hundred thousand times a build: the grid, the cliffs' bisection).
static var _memo := {}

static func _shapes() -> Dictionary:
	if _memo.is_empty():
		var path: Array = LAYOUT.gully.path
		var box := Rect2(path[0],Vector2.ZERO)
		for q: Vector2 in path: box = box.expand(q)
		_memo = {"inside":corbel_inside(),"corbel":corbel_rect().grow(2.0),"pyramid":pyramid_rect(),"gully_box":box.grow(32.0),"gully_len":gully_length()}
	return _memo

static func main_ground(x: float, z: float) -> float:
	var sh := _shapes()
	if (sh.inside as Rect2).has_point(Vector2(x,z)): return -1.0
	var g := gully_at(x,z)
	var hd: Dictionary = LAYOUT.hollow
	var wall := float(hd.wall)+0.8*sin(z*0.21)+0.5*sin(z*0.53+1.0)
	var cr: Rect2 = sh.corbel
	if z > cr.position.y and z < cr.end.y: wall = float(hd.wall_at_corbel)
	var hollow := x > wall and z > float(hd.north)-4.0
	var gd: Dictionary = LAYOUT.gully
	if g.x <= g.w and not hollow: return gully_floor(g.y)
	if hollow:
		var y := float(hd.y)
		for t: Array in hd.terraces:
			var edge := float(t[1])+1.4*sin(x*0.17)+0.8*sin(x*0.41+2.0)
			if x > float(t[0])+2.0*sin(z*0.3) and z < edge:
				y = maxf(y,float(t[2]))
		return y
	# Off the hollow way's outer side (the void's): its lip, a little under
	# its floor, out to the island's edge (open, never a slot).
	if g.z < 0.0 and g.x < 26.0 and g.y > float(gd.open_from) and g.y < float(sh.gully_len)-float(gd.open_to):
		return gully_floor(g.y)-minf(1.2,(g.x-g.w)*0.12)
	return upland(x,z)+pyramid_berm(x,z)

## The pyramid's platform sunk in the high rim: the land a hair under its
## paving inside, and a turf berm (rising `berm.y` m) over its outer edge,
## so its paving runs under the grass rather than standing on it.
static func pyramid_berm(x: float, z: float) -> float:
	var r: Rect2 = _shapes().pyramid
	if not r.grow(float(LAYOUT.pyramid.berm.out)+2.0).has_point(Vector2(x,z)): return 0.0
	var bd: Dictionary = LAYOUT.pyramid.berm
	var q := Vector2(x,z)
	var dx := maxf(r.position.x-q.x,q.x-r.end.x)
	var dz := maxf(r.position.y-q.y,q.y-r.end.y)
	var d := maxf(dx,dz)
	var wob := 1.2*sin(x*0.21)+0.9*sin(z*0.17+1.0)
	var inside := -float(bd.inside)+wob
	if d < inside: return -0.3
	var out := float(bd.out)
	if d > out: return 0.0
	var t := (d-inside)/(out-inside)
	return float(bd.y)*sin(PI*clampf(t*1.6,0.0,1.0)*0.5)*(1.0-smoothstep(0.55,1.0,t))

## The pyramid's platform (x, z) in the motif frame (CityLandmarks pyramid:
## base, stair out in front (+z), a cell round it).
static func pyramid_rect() -> Rect2:
	var h0 := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-1)*CityLandmarks.TREAD
	var stair_len := CityLandmarks.TIERS*CityKit.STAIR_STEPS*CityKit.TREAD+CityLandmarks.TIERS*CityKit.LANDING
	var stair_z := CityLandmarks.SUMMIT_HALF-CityKit.LANDING+stair_len
	var at: Vector2 = LAYOUT.pyramid.at
	return Rect2(at.x-h0-CityLandmarks.CELL,at.y-h0-CityLandmarks.CELL,(h0+CityLandmarks.CELL)*2.0,h0+CityLandmarks.CELL+stair_z+CityLandmarks.CELL)

## The terrace, the shoulder's steps and the high rim, the way out's.
static func upland(x: float, z: float) -> float:
	var y := float(LAYOUT.terrace)
	var sh: Dictionary = LAYOUT.shoulder
	var treads: Array = sh.treads
	var kinds: String = sh.kinds
	var edge0 := float(sh.from_x)
	for i in treads.size():
		edge0 -= float(treads[i])
		var amp := float(sh.wander)*(1.0-0.5*i/float(treads.size()))
		var edge := edge0+float(treads[i])+amp*sin(z*0.045+i*0.9)+1.2*sin(z*0.23+i*2.1)
		if kinds[i] == "r": y += SET_OFF*clampf((edge-x)/float(sh.ramp),0.0,1.0)
		elif x < edge: y += SET_OFF
	var o: Dictionary = LAYOUT.out
	var d := Vector2(x,z).distance_to(o.at)
	var a := Vector2(x,z).angle_to_point(o.at)
	for i in int(o.steps):
		if d < float(o.reach)-i*float(o.tread)+3.6*sin(a*2.0+i*1.7)+1.4*sin(a*5.0+i): y += SET_OFF
	return y

## The hollow way near (x, z): (distance from its line, how far along it,
## the side: < 0 its outer (void) side, its half width there).
static func gully_at(x: float, z: float) -> Vector4:
	var gd: Dictionary = LAYOUT.gully
	var path: Array = gd.path
	var q := Vector2(x,z)
	if not (_shapes().gully_box as Rect2).has_point(q): return Vector4(INF,0.0,1.0,float(gd.half))
	var best := INF
	var best_s := 0.0
	var side := 0.0
	var run := 0.0
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var d := b-a
		var t := clampf((q-a).dot(d)/d.length_squared(),0.0,1.0)
		var dist := q.distance_to(a+d*t)
		if dist < best:
			best = dist
			best_s = run+t*d.length()
			side = d.cross(q-a)
		run += d.length()
	return Vector4(best,best_s,side,float(gd.half)+1.0*sin(best_s*0.17))

static func gully_length() -> float:
	var path: Array = LAYOUT.gully.path
	var run := 0.0
	for i in range(path.size()-1): run += (path[i+1] as Vector2).distance_to(path[i])
	return run

## The hollow way's floor `s` m along it.
static func gully_floor(s: float) -> float:
	var gd: Dictionary = LAYOUT.gully
	var steps := int(round(rim_y()/SET_OFF))
	var tread := (float(_shapes().gully_len)-float(gd.flat)-float(gd.end_flat))/steps
	var n := clampi(int(floor((s-float(gd.flat))/tread))+1,0,steps)
	return minf(n*SET_OFF,rim_y())

## The shelf: flat at the promenade's height.
static func shelf_ground(_x: float, _z: float) -> float:
	return float(LAYOUT.shelf)

## Where the ground is (x, z), on whichever land is there (the shelf over
## the main island where both are).
static func ground_at(x: float, z: float) -> float:
	if Geometry2D.is_point_in_polygon(Vector2(x,z),PackedVector2Array(LAYOUT.shelf_outline)): return shelf_ground(x,z)
	return main_ground(x,z)

static func at_ground(p: Vector2) -> Vector3:
	return Vector3(p.x,ground_at(p.x,p.y),p.y)

# --- The motif's face -----------------------------------------------------------------------

func slug() -> String:
	return "coliseum_pit"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Coliseum Pit"

func epithet() -> String:
	return "They played for the sky here once. The far stands kept their seats; the near ones went to the dark."

func brief() -> String:
	return "Across the sunk court to the pyramid's rim: the hollow way round the south edge (long), the far tier past its watcher, or lure the alley's keeper to the corbel gate and climb what he breaks.\nTwo Olmecs keep the court. The shrine on the pyramid is safe."

func start() -> Vector3:
	return at_ground(LAYOUT.arrive)

## In at the shelf's east end; out at the high rim's north-west corner.
func rims() -> Array:
	var a: Vector2 = LAYOUT.arrive
	return [
		{"name":"shelf","at":at_ground(a+Vector2(4.0,0.0)),"face":Vector3(1.0,0.0,0.0),"run_up":16.0,"lip":1.5},
		{"name":"way_out","at":at_ground(LAYOUT.out.at),"face":Vector3(0.5,0.0,-0.85),"run_up":14.0,"lip":5.0},
	]

func spots() -> Array:
	var py := pyramid_xf()
	var summit := py*Vector3(0.0,float(CityLandmarks.TIERS)*COURSE,CityLandmarks.SUMMIT_HALF-CityKit.LANDING*0.5)
	var m: Vector2 = LAYOUT.corbel.mouth
	var st: Dictionary = LAYOUT.stump
	var out: Array = [
		{"kind":"arena","name":"gate_hollow","at":at_ground(Vector2(8.0,46.0)),"room":14.0},
		{"kind":"arena","name":"alley","at":Vector3(0.0,0.0,6.0),"room":5.0},
		{"kind":"arena","name":"high_rim","at":at_ground(Vector2(-110.0,20.0)),"room":12.0},
		{"kind":"cover","name":"corbel_hall","at":Vector3(m.x-CorbelVault.BAY_L*1.5,0.0,m.y),"room":3.0},
		{"kind":"perch","name":"pyramid_summit","at":summit,"room":4.0},
		{"kind":"perch","name":"west_promenade","at":Vector3(-21.4,14.4,0.0),"room":4.0},
		# Rare: behind the break (the broken stair's first top, inside the
		# fallen bay: stone till he brings it in), across the jump to the
		# court's fallen chunk, on the lone column over the void.
		{"kind":"rare","name":"corbel_heart","at":corbel_xf()*Vector3(CorbelVault.HALF+CorbelVault.MASS*0.5,CorbelVault.STAIR_FROM,-CorbelVault.BAY_L*0.5),"room":1.0},
		{"kind":"rare","name":"fallen_chunk","at":Vector3(-1.0,float(LAYOUT.fragment.y),-30.0),"room":1.5},
		{"kind":"rare","name":"lone_column","at":Vector3(st.at.x,float(st.top),st.at.y),"room":1.0},
		# Risk: the serpent beams' heads over the alley (the Player under
		# them), the promenade's north end over the void (the Watcher's), the
		# hollow way's outer lip, the pyramid's fault landing.
		{"kind":"rune_risk","name":"beam_head_w","at":Vector3(-5.4,8.0,-8.8),"room":0.6},
		{"kind":"rune_risk","name":"beam_head_e","at":Vector3(5.4,8.0,8.8),"room":0.6},
		{"kind":"rune_risk","name":"tier_north_end","at":Vector3(-21.4,14.4,-20.5),"room":2.0},
		{"kind":"rune_risk","name":"hollow_way_lip","at":at_ground(Vector2(-108.0,73.0)),"room":1.0},
		{"kind":"rune_risk","name":"pyramid_fault","at":py*Vector3(0.0,2.0*COURSE,CityLandmarks.SUMMIT_HALF+40.0),"room":2.0},
	]
	# Runes along the ways: the alley, the hollow, the hollow way's steps,
	# the shoulder, the high rim to the way out.
	for z: float in [-8.0,0.0,8.0]: out.append({"kind":"rune_line","name":"alley_%d" % int(z),"at":Vector3(0.0,0.0,z),"room":0.5})
	for p: Vector2 in [Vector2(20.0,40.0),Vector2(-5.0,40.0),Vector2(-24.0,36.0)]: out.append({"kind":"rune_line","name":"hollow_%d" % int(p.x),"at":at_ground(p),"room":0.5})
	var path: Array = LAYOUT.gully.path
	for i in range(1,path.size()-1): out.append({"kind":"rune_line","name":"hollow_way_%d" % i,"at":at_ground(path[i]),"room":0.5})
	for x: float in [-74.0,-82.0,-90.0,-98.0]: out.append({"kind":"rune_line","name":"shoulder_%d" % int(-x),"at":at_ground(Vector2(x,-6.0)),"room":0.5})
	for p: Vector2 in [Vector2(-100.0,-50.0),Vector2(-106.0,-72.0)]: out.append({"kind":"rune_line","name":"rim_%d" % int(-p.x),"at":at_ground(p),"room":0.5})
	return out

## The solids for the occupancy and the footprint: the land sampled in
## cells (its ground on top, its keel's reach under), the court, the corbel,
## the pyramid's platform and tiers.
func parts() -> Array:
	var out: Array = []
	var cell := 8.0
	for land: Array in [[LAYOUT.main_outline,-50.0],[LAYOUT.shelf_outline,-35.0]]:
		var poly := PackedVector2Array(land[0])
		var box := Rect2(poly[0],Vector2.ZERO)
		for q in poly: box = box.expand(q)
		var x := box.position.x
		while x < box.end.x:
			var z := box.position.y
			while z < box.end.y:
				var c := Vector2(x+cell*0.5,z+cell*0.5)
				if Geometry2D.is_point_in_polygon(c,poly):
					var hi := -INF
					for o: Vector2 in [Vector2(0.2,0.2),Vector2(cell-0.2,0.2),Vector2(0.2,cell-0.2),Vector2(cell-0.2,cell-0.2),Vector2(cell*0.5,cell*0.5)]:
						hi = maxf(hi,ground_at(x+o.x,z+o.y))
					out.append(["box",Rect2(x,z,cell,cell),float(land[1]),hi,"grey"])
				z += cell
			x += cell
	# The court: its stands to the promenade, its alley's floor.
	out.append(["box",Rect2(-33.4,-22.0,66.9,48.4),-float(LAYOUT.court.foundation),0.0,"grey"])
	for s: float in [-1.0,1.0]:
		out.append(["box",Rect2(9.8 if s > 0.0 else -25.8,-22.0,16.0,44.0),0.0,14.4,"grey"])
	var cr := corbel_rect()
	out.append(["box",cr,-COURSE,CorbelVault.roof(),"grey"])
	var py := pyramid_xf().origin
	var h0 := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-1)*CityLandmarks.TREAD
	for k in CityLandmarks.TIERS:
		var hk := h0-k*CityLandmarks.TREAD
		out.append(["box",Rect2(py.x-hk,py.z-hk,hk*2.0,hk*2.0),py.y-3.0,py.y+(k+1)*COURSE,"grey"])
	out.append(["box",Rect2(py.x-6.0,py.z-12.0,12.0,12.0),py.y,py.y+float(CityLandmarks.TIERS)*COURSE+18.0,"grey"])
	return out

func heads() -> Array:
	return []

# --- The land and the stone ------------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return SEED+9

## The worn ways: the shelf to the court and to its terraces, the hollow
## to the corbel, the hollow way, the terrace over the shoulder to the
## pyramid and the way out.
static func paths() -> Array:
	var a: Vector2 = LAYOUT.arrive
	var out: Array = [[a,Vector2(26.0,4.0)],[a,Vector2(58.0,16.0),Vector2(54.0,40.0),Vector2(10.0,40.0),Vector2(-28.0,36.0)],
		[Vector2(-24.0,0.0),Vector2(-66.0,-4.0),Vector2(-104.0,-2.0),Vector2(-150.0,60.0)],[Vector2(-104.0,-2.0),Vector2(-196.0,-60.0),Vector2(-210.0,-88.0)]]
	out.append(LAYOUT.gully.path)
	return out

func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_computed()

func build_cost() -> int:
	return 2100

## The pieces, by name, once built (for checks).
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "ColiseumPit"
	into.add_child(root)
	pieces.clear()
	_land(root)
	# The court, sunk in the land.
	var court := CityLandmarks.court(SEED+2,float(LAYOUT.court.wear),{"foundation":float(LAYOUT.court.foundation)})
	court.name = "Court"
	court.transform = court_xf()
	root.add_child(court)
	pieces.court = court
	# The corbel gate in the hollow's west wall.
	var corbel := CityBreaks2.piece("maker_corbel",SEED+3,float(LAYOUT.corbel.wear))
	corbel.name = "CorbelGate"
	corbel.transform = corbel_xf()
	root.add_child(corbel)
	pieces.corbel = corbel
	# The pyramid on the high rim, its summit cresset lit (still).
	var pd: Dictionary = LAYOUT.pyramid
	var pyr := CityLandmarks.pyramid(SEED+4,float(pd.wear),{"foundation":float(pd.foundation),"fault":int(pd.fault),"lit":true})
	pyr.name = "Pyramid"
	pyr.transform = pyramid_xf()
	root.add_child(pyr)
	pieces.pyramid = pyr
	_stones(root)
	built_ms = Time.get_ticks_msec()-began

## The islands: the main plateau (the hollow, the terrace, the shoulder,
## the high rim, the hollow way), the shelf, the fallen chunk.
func _land(root: Node3D) -> void:
	var wear := KitLand.wear_of(paths())
	var main := KitLand.island({"outline":LAYOUT.main_outline,"seed":SEED+11,"ground":func(x: float, z: float) -> float: return main_ground(x,z),
		"top":float(LAYOUT.terrace),"depth":70.0,"hang":true,"resample":[60.0,260,64],"tone":KitLook.turf(SEED+11,wear),
		"cell":3.0,"fine":1.2,"fine_box":Rect2(-50.0,22.0,26.0,30.0),"cliffs":Rect2(-155.0,-100.0,125.0,182.0),
		"cliff_skip":func(e: Vector2) -> bool: return corbel_rect().grow(1.0).has_point(e)})
	main.name = "Plateau"
	root.add_child(main)
	turf(main)
	var shelf := KitLand.island({"outline":LAYOUT.shelf_outline,"seed":SEED+12,"ground":func(x: float, z: float) -> float: return shelf_ground(x,z),
		"top":float(LAYOUT.shelf),"depth":46.0,"hang":true,"resample":[60.0,120,48],"tone":KitLook.turf(SEED+12,wear),"cell":2.5})
	shelf.name = "Shelf"
	root.add_child(shelf)
	turf(shelf)
	var fd: Dictionary = LAYOUT.fragment
	var fy := float(fd.y)
	var frag := KitLand.island({"outline":fd.outline,"seed":SEED+13,"ground":func(_x: float, _z: float) -> float: return fy,
		"top":fy,"depth":18.0,"hang":true,"resample":[30.0,40,24],"tone":KitLook.turf(SEED+13),"cell":1.5})
	frag.name = "FallenChunk"
	root.add_child(frag)
	turf(frag)
	# The court's bed: bare rock under the alley.
	var bd: Dictionary = LAYOUT.bed
	var by := float(bd.y)
	var bed := KitLand.island({"outline":bd.outline,"seed":SEED+14,"ground":func(_x: float, _z: float) -> float: return by,
		"top":by,"depth":float(bd.depth),"hang":false,"resample":[60.0,60,40],"tone":KitLook.turf(SEED+14),"cell":4.0})
	bed.name = "CourtBed"
	root.add_child(bed)
	# The lone column: a spire of rock out of the void, turf on its top.
	var st: Dictionary = LAYOUT.stump
	var ring: Array = []
	for i in 9:
		var a := TAU*i/9.0
		ring.append(Vector2(st.at.x,st.at.y)+Vector2(cos(a),sin(a))*float(st.radius)*(0.85+0.3*sin(i*2.3)))
	var top_y := float(st.top)
	var spire := KitLand.island({"outline":ring,"seed":SEED+15,"ground":func(_x: float, _z: float) -> float: return top_y,
		"top":top_y,"depth":26.0,"hang":true,"resample":[20.0,18,18],"tone":KitLook.turf(SEED+15),"cell":1.0})
	spire.name = "LoneSpire"
	root.add_child(spire)
	turf(spire)

## Fallen drums (cover) and the lone column out of the void.
func _stones(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var solids := StaticBody3D.new()
	solids.name = "Stones"
	for d: Array in LAYOUT.drums:
		var r := float(d[2])
		var length := float(d[3])
		var at := at_ground(Vector2(float(d[0]),float(d[1])))
		if Geometry2D.is_point_in_polygon(Vector2(float(d[0]),float(d[1])),PackedVector2Array(LAYOUT.fragment.outline)): at.y = float(LAYOUT.fragment.y)
		var turn := Basis(Vector3.UP,deg_to_rad(float(d[4])))*Basis(Vector3.FORWARD,PI/2.0)
		var xf := Transform3D(turn,at+Vector3.UP*(r-0.25))
		g.cylinder(xf,r,length,12,0.2,at.y-0.3,0.9)
		_cyl_shape(solids,xf,r,length)
	var mesh := MeshInstance3D.new()
	mesh.name = "StonesMesh"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)

static func _cyl_shape(body: StaticBody3D, xf: Transform3D, r: float, length: float) -> void:
	var c := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = length
	c.shape = shape
	c.transform = xf
	body.add_child(c)

# --- What moves ------------------------------------------------------------------------------

## The court's roots (swing ropes), the still lamps, the breakables hub,
## the two keepers.
func live(g: Node) -> void:
	var court: Node3D = pieces.get("court")
	if court != null:
		for r: Dictionary in court.get_meta("ropes",[]):
			g.rope(g.w(court_xf()*(r.anchor as Vector3)),float(r.length))
	var fires := Node3D.new()
	fires.name = "Lamps"
	g.add_child(fires)
	var k := 0
	for l: Array in LAYOUT.lamps:
		var at := at_ground(Vector2(float(l[0]),float(l[1])))
		if not is_nan(float(l[2])): at.y = float(l[2])
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":SEED+40+k,"name":"Lamp%d" % k,"lit":true,"draw":1.0,"barge":false})
		k += 1
	# The pyramid's summit fire burned since the city emptied: it calls no one.
	var pyr: Node3D = pieces.get("pyramid")
	if pyr != null:
		var c := pyr.find_child("SummitCresset",true,false)
		if c != null: _still(c)
	var hub: Node3D = Breakables.new()
	hub.name = "Breakables"
	hub.field = g.stage.enemies
	g.add_child(hub)
	var keepers := Keepers.new()
	keepers.name = "Keepers_STANDIN"
	keepers.field = g.stage.enemies
	keepers.hub = hub
	g.add_child(keepers)
	for who: String in ["player","watcher"]:
		var kd: Dictionary = LAYOUT[who]
		var beat: Array[Vector3] = []
		for p: Vector3 in kd.beat: beat.append(g.w(p))
		var post: Vector3 = beat[1]
		var knobs := PLAYER_KNOBS.duplicate()
		knobs["seed"] = SEED+(1 if who == "watcher" else 0)
		var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,kd.face,knobs)
		var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,kd.face,{})
		keepers.add(who,body,head,beat)

static func _still(fire: Object) -> void:
	var b: Object = fire.get("beacon")
	if b != null: b.set("draw",1.0)

## STAND-IN: the keepers' rounds (gb_stacked_court's Keeper, for two). A
## whole Olmec unaware roams any way; this turns each, while he listens or
## roams and isn't hunting, toward the next point of his beat, back and
## forth: the Player down the alley, the Watcher along the west promenade.
## It holds each at his post till the stone under him stands, puts his head
## back after the yard's reset, and hands every Olmec the breakables hub.
class Keepers extends Node:
	var field: Node = null
	var hub: Node3D = null
	## [{who, body, head, beat, post, leg, dir, landed}]
	var keep: Array = []
	var steered := 0

	func add(who: String, b: Node3D, h: Node3D, beat: Array[Vector3]) -> void:
		if b != null and h != null: b.make_whole(h)
		keep.append({"who":who,"body":b,"head":h,"beat":beat,"post":beat[1],"leg":1,"dir":1,"landed":false})

	## A keeper's body by name ("player", "watcher").
	func body_of(who: String) -> Node3D:
		for k: Dictionary in keep:
			if k.who == who and is_instance_valid(k.body): return k.body
		return null

	func _physics_process(_delta: float) -> void:
		if field != null:
			for e in field.enemies:
				if is_instance_valid(e) and e.has_method("world_changed") and e.get("breaker") == null: e.breaker = hub
		for k: Dictionary in keep:
			var body: Node3D = k.body
			var head: Node3D = k.head
			if body == null or not is_instance_valid(body) or head == null or not is_instance_valid(head):
				_refind(k)
				continue
			if not bool(k.landed):
				var stone: StaticBody3D = body.body
				k.landed = field.floor_under(k.post,2.0,6.0,stone.get_rid() if stone != null else RID()) > -INF
				if not bool(k.landed):
					body.position = k.post
					body.vel = Vector3.ZERO
					continue
			if not body.whole or body.hunting: continue
			if not (str(body.state) in ["listen","roam"]): continue
			var beat: Array = k.beat
			var to: Vector3 = beat[k.leg]
			var flat := Vector2(to.x-body.position.x,to.z-body.position.z)
			if flat.length() < 4.5 and absf(to.y-body.position.y) < 3.0:
				if int(k.leg)+int(k.dir) < 0 or int(k.leg)+int(k.dir) >= beat.size(): k.dir = -int(k.dir)
				k.leg = int(k.leg)+int(k.dir)
				to = beat[k.leg]
			# His own roam plans a route to a goal along a way picked at random
			# (and leaps any drop it likes): once he has picked (listening) or
			# while he roams, his goal is the beat's next point instead, the
			# route found by his own planner (`_start_search`).
			if (bool(body._picked) or str(body.state) == "roam") and (body._goal as Vector3).distance_to(to) > 1.0:
				body._start_search(to,3.0)
				steered += 1

	func _refind(k: Dictionary) -> void:
		if field == null: return
		var post: Vector3 = k.post
		var body: Node3D = null
		var head: Node3D = null
		for e: Node3D in field.enemies:
			if not is_instance_valid(e): continue
			if e.has_method("make_whole") and e.position.distance_to(post) < 6.0: body = e
			elif e.has_method("mouth") and e.position.distance_to(post) < 12.0: head = e
		if body != null and head != null:
			body.make_whole(head)
			k.body = body
			k.head = head
			k.landed = false
			k.leg = 1
			k.dir = 1
