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
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
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
const ColiseumLife = preload("res://scripts/kit_isle/greybox/coliseum_pit_life.gd")
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
	# The pyramid on the high rim, on the brink of its north cliff (off the
	# court's line from the arrival): its middle (x, z), its stair to +z
	# (south), its stair's fault landing (CityKit stair: 1-based; 0 none).
	"pyramid":{"at":Vector2(-180.0,-58.0),"fault":2,"wear":0.85,"foundation":3.0,
		# The berm the land makes over its platform's edge: from `inside` m
		# in from it to `out` m out, `y` m at its crest.
		"berm":{"inside":3.0,"out":10.0,"y":1.4},
		# Its slumped corner (the base's north-east, over the void bay): the
		# earth heaped `rise` m up it, falling off over `reach` m.
		"slump":{"corner":Vector2(1.0,-1.0),"rise":11.0,"reach":30.0},
		# The corner's fallen courses: [along the north face from the corner
		# (m, + west), out from it (m, + north), y over the rim (NAN: on the
		# ground), size (x, y, z), turn (yaw, pitch, roll deg)].
		"fallen":[[2.0,-1.0,NAN,Vector3(9.0,4.4,7.0),Vector3(18.0,-14.0,9.0)],[-4.0,7.0,NAN,Vector3(7.0,4.0,6.0),Vector3(-30.0,8.0,-16.0)],
			[9.0,4.5,NAN,Vector3(5.0,2.6,4.0),Vector3(40.0,22.0,-6.0)],[-11.0,3.0,NAN,Vector3(4.4,2.4,3.2),Vector3(70.0,-12.0,18.0)],
			[14.0,-3.0,NAN,Vector3(3.2,1.8,2.6),Vector3(-15.0,6.0,25.0)],[4.0,9.0,NAN,Vector3(3.0,1.6,2.4),Vector3(25.0,30.0,0.0)],
			[-1.0,-6.0,7.0,Vector3(6.0,3.2,5.0),Vector3(10.0,-24.0,12.0)]],
		# Earth and turf drifted onto its treads [tier, face (x, z), along
		# the face from its middle (m), length (m)]: the tiers going back to
		# grass.
		"drifts":[[0,Vector2(1.0,0.0),-16.0,22.0],[0,Vector2(0.0,-1.0),18.0,26.0],[1,Vector2(1.0,0.0),-6.0,16.0],[1,Vector2(-1.0,0.0),10.0,18.0],
			[2,Vector2(0.0,-1.0),-4.0,12.0],[0,Vector2(-1.0,0.0),-12.0,20.0],[1,Vector2(0.0,-1.0),-12.0,20.0],[2,Vector2(1.0,0.0),2.0,14.0],
			[2,Vector2(-1.0,0.0),-6.0,12.0],[0,Vector2(1.0,0.0),18.0,14.0]]},
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
	# The collapse into the void bay, seen from the arrival: the slab (the
	# shelf's north end, broken off and heaved, its near edge sunk a set-off
	# under the shelf's lip, its far end reared up over the dark), its stand
	# rows tumbled on it, a lamp still burning at its high tip; the debris
	# the break shed, falling away below; and under the pyramid's slumped
	# corner, the ledge its courses fell to. Slab: its ground `y` at z `z0`,
	# `fall` m a metre toward +z (rising north) and `roll` a metre east;
	# stones [x, z, size, yaw deg].
	"slab":{"outline":[Vector2(34.5,-23.8),Vector2(40.0,-18.0),Vector2(52.0,-12.8),Vector2(62.0,-17.8),Vector2(66.0,-26.0),
			Vector2(60.0,-40.0),Vector2(48.0,-50.0),Vector2(38.0,-47.0),Vector2(33.0,-36.0)],
		"y":12.8,"near":4,"rise":0.4,"x0":50.0,"roll":-0.04,"depth":38.0,
		"stones":[[44.0,-27.0,Vector3(8.5,1.6,2.6),-8.0],[54.0,-23.5,Vector3(6.0,1.6,2.4),14.0],[46.0,-36.0,Vector3(6.0,1.6,2.4),-32.0],
			[57.0,-32.0,Vector3(4.4,3.2,3.2),48.0],[39.0,-41.0,Vector3(3.6,1.6,2.2),70.0],[60.0,-21.0,Vector3(3.0,1.6,2.0),-20.0]],
		"lamp":Vector2(48.0,-45.5)},
	# The debris it shed, falling away into the dark [at, top y, radius, depth].
	"debris":[[Vector2(10.0,-60.0),-13.0,5.2,13.0],[Vector2(-14.0,-72.0),-27.0,4.0,11.0],[Vector2(26.0,-84.0),-39.0,3.4,9.0]],
	"debris_lamp":1,
	# The ledge under the pyramid's slumped corner (its outline, its y).
	"ledge":{"outline":[Vector2(-148.0,-110.8),Vector2(-133.0,-107.9),Vector2(-121.0,-107.3),Vector2(-117.0,-111.5),Vector2(-127.0,-114.0),Vector2(-143.0,-114.0)],
		"y":15.0},
	# Fallen column drums (cover) [x, z, radius, length, turn deg].
	"drums":[[18.0,54.0,1.6,5.0,25.0],[-14.0,54.0,1.4,4.0,-40.0],[62.0,8.0,1.5,4.4,70.0],[-104.0,22.0,1.8,5.4,10.0],[3.0,-32.5,1.3,3.6,80.0],[-123.0,56.0,1.7,4.6,-20.0],[-218.0,40.0,1.5,4.0,40.0],[-196.0,44.0,1.9,5.6,75.0]],
	# The keepers: the Player's beat down the alley and its end zones, the
	# Watcher's along the west promenade; each one's first look.
	"player":{"beat":[Vector3(0.0,0.0,6.0),Vector3(1.5,0.0,13.0),Vector3(0.0,0.0,21.0)],"face":Vector2(0.0,-1.0)},
	"watcher":{"beat":[Vector3(-21.4,14.4,-16.0),Vector3(-21.4,14.4,0.0),Vector3(-21.4,14.4,16.0)],"face":Vector2(1.0,0.0)},
	# Small fires lit since forever (still: they call no Olmec): the eye-line
	# to the way out [x, z, y or NAN for the ground].
	"lamps":[[-29.0,26.0,NAN],[-29.0,46.4,NAN],[-84.0,66.0,NAN],[-140.0,66.0,NAN],[-104.0,-84.0,NAN]],
}

const PLAYER_KNOBS := {"chase":1,"chase_routes":1}
## Fallen courses tried on each face of each tread (fewer kept far from the
## slumped corner).
const RUBBLE_EACH := 7

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
## out, the pyramid's berm and its slumped corner.
##
## The land's numbers are unpacked from LAYOUT once into typed statics
## (`_prep`, on the main thread in `warm`): the ground is asked some 400
## thousand times a build (most of it the cliffs' scan, KitLand
## `cliff_points`), and the dictionary lookups were half its cost.
static var _ready := false
static var _inside := Rect2()
static var _corbel := Rect2()
static var _pyr := Rect2()
static var _pyr_near := Rect2()
static var _gully_box := Rect2()
static var _gully_len := 0.0
static var _ga := PackedVector2Array()
static var _gd := PackedVector2Array()
static var _gl := PackedFloat32Array()
static var _gl2 := PackedFloat32Array()
static var _gr := PackedFloat32Array()
static var _g_half := 0.0
static var _g_open := Vector2.ZERO
static var _g_flat := 0.0
static var _g_tread := 0.0
static var _g_steps := 0
static var _rim := 0.0
static var _terrace := 0.0
static var _t_edge := PackedFloat32Array()
static var _t_amp := PackedFloat32Array()
static var _t_ramp := PackedByteArray()
static var _t_range := Vector2.ZERO
static var _ramp := 0.0
static var _o_at := Vector2.ZERO
static var _o_box := Rect2()
static var _o_reach := 0.0
static var _o_tread := 0.0
static var _o_steps := 0
static var _h_y := 0.0
static var _h_wall := 0.0
static var _h_wall_c := 0.0
static var _h_north := 0.0
static var _h_terr := PackedFloat32Array()
static var _berm := Vector3.ZERO
static var _slump_at := Vector2.ZERO
static var _slump := Vector2.ZERO
static var _slump_box := Rect2()

static func _prep() -> void:
	if _ready: return
	_inside = corbel_inside()
	_corbel = corbel_rect().grow(2.0)
	_pyr = pyramid_rect()
	_berm = Vector3(float(LAYOUT.pyramid.berm.inside),float(LAYOUT.pyramid.berm.out),float(LAYOUT.pyramid.berm.y))
	_pyr_near = _pyr.grow(_berm.y+2.0)
	var gd: Dictionary = LAYOUT.gully
	var path: Array = gd.path
	var box := Rect2(path[0],Vector2.ZERO)
	var run := 0.0
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var d: Vector2 = (path[i+1] as Vector2)-a
		_ga.append(a)
		_gd.append(d)
		_gl.append(d.length())
		_gl2.append(d.length_squared())
		_gr.append(run)
		run += d.length()
	for q: Vector2 in path: box = box.expand(q)
	_gully_box = box.grow(32.0)
	_gully_len = run
	_g_half = float(gd.half)
	_g_open = Vector2(float(gd.open_from),run-float(gd.open_to))
	_g_flat = float(gd.flat)
	_terrace = float(LAYOUT.terrace)
	var sh: Dictionary = LAYOUT.shoulder
	var treads: Array = sh.treads
	var kinds: String = sh.kinds
	_rim = _terrace+treads.size()*SET_OFF
	_g_steps = int(round(_rim/SET_OFF))
	_g_tread = (run-_g_flat-float(gd.end_flat))/_g_steps
	_ramp = float(sh.ramp)
	var edge0 := float(sh.from_x)
	var lo := INF
	var hi := -INF
	for i in treads.size():
		var amp := float(sh.wander)*(1.0-0.5*i/float(treads.size()))
		_t_edge.append(edge0)
		_t_amp.append(amp)
		_t_ramp.append(1 if kinds[i] == "r" else 0)
		lo = minf(lo,edge0-amp-1.3-_ramp*1.3)
		hi = maxf(hi,edge0+amp+1.3)
		edge0 -= float(treads[i])
	_t_range = Vector2(lo,hi)
	var o: Dictionary = LAYOUT.out
	_o_at = o.at
	_o_reach = float(o.reach)
	_o_tread = float(o.tread)
	_o_steps = int(o.steps)
	_o_box = Rect2(_o_at-Vector2.ONE*(_o_reach+5.2),Vector2.ONE*(_o_reach+5.2)*2.0)
	var hd: Dictionary = LAYOUT.hollow
	_h_y = float(hd.y)
	_h_wall = float(hd.wall)
	_h_wall_c = float(hd.wall_at_corbel)
	_h_north = float(hd.north)
	for t: Array in hd.terraces:
		_h_terr.append_array(PackedFloat32Array([float(t[0]),float(t[1]),float(t[2])]))
	var sd: Dictionary = LAYOUT.pyramid.slump
	_slump_at = pyramid_corner(sd.corner)
	_slump = Vector2(float(sd.rise),float(sd.reach))
	_slump_box = Rect2(_slump_at-Vector2.ONE*_slump.y*1.4,Vector2.ONE*_slump.y*2.8)
	_wear_grid()
	_ready = true

static func main_ground(x: float, z: float) -> float:
	if not _ready: _prep()
	var q := Vector2(x,z)
	if _inside.has_point(q): return -1.0
	var wall := _h_wall_c if z > _corbel.position.y and z < _corbel.end.y else _h_wall+0.8*sin(z*0.21)+0.5*sin(z*0.53+1.0)
	if x > wall and z > _h_north-4.0:
		# The gate hollow and the shelf's broken terraces down into it.
		var y := _h_y
		for i in range(0,_h_terr.size(),3):
			var edge := _h_terr[i+1]+1.4*sin(x*0.17)+0.8*sin(x*0.41+2.0)
			if x > _h_terr[i]+2.0*sin(z*0.3) and z < edge: y = maxf(y,_h_terr[i+2])
		return y
	var g := gully_at(x,z)
	if g.x <= g.w: return gully_floor(g.y)
	# Off the hollow way's outer side (the void's): its lip, a little under
	# its floor, out to the island's edge (open, never a slot).
	if g.z < 0.0 and g.x < 26.0 and g.y > _g_open.x and g.y < _g_open.y:
		return gully_floor(g.y)-minf(1.2,(g.x-g.w)*0.12)
	var y := upland(x,z)
	if _pyr_near.has_point(q): y += pyramid_berm(x,z)
	if _slump_box.has_point(q): y = maxf(y,_rim+slump(x,z))
	return y

## The pyramid's platform sunk in the high rim: the land a hair under its
## paving inside, and a turf berm (rising `berm.y` m) over its outer edge,
## so its paving runs under the grass rather than standing on it.
static func pyramid_berm(x: float, z: float) -> float:
	var r := _pyr
	var dx := maxf(r.position.x-x,x-r.end.x)
	var dz := maxf(r.position.y-z,z-r.end.y)
	var d := maxf(dx,dz)
	var wob := 1.2*sin(x*0.21)+0.9*sin(z*0.17+1.0)
	var inside := -_berm.x+wob
	if d < inside: return -0.3
	if d > _berm.y: return 0.0
	var t := (d-inside)/(_berm.y-inside)
	return _berm.z*sin(PI*clampf(t*1.6,0.0,1.0)*0.5)*(1.0-smoothstep(0.55,1.0,t))

## The pyramid's slumped corner: earth and rubble heaped up its north-east
## corner (`rise` m over the rim at the corner), falling off in lobes over
## `reach` m: the tiers' corner went, and the land took what fell.
static func slump(x: float, z: float) -> float:
	var d := Vector2(x,z)-_slump_at
	var r := d.length()
	var a := atan2(d.y,d.x)
	var reach := _slump.y*(1.0+0.22*sin(a*3.0+1.3)+0.12*sin(a*7.0+0.4))
	if r >= reach: return 0.0
	var t := r/reach
	return _slump.x*(1.0-smoothstep(0.0,1.0,t))+0.5*sin(x*0.6)*sin(z*0.5)*t*(1.0-t)

## A corner of the pyramid's base (x, z, motif frame): `side` (sx, sz)
## each -1 or 1 (north is -z).
static func pyramid_corner(side: Vector2) -> Vector2:
	var at: Vector2 = LAYOUT.pyramid.at
	return at+side*(CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-1)*CityLandmarks.TREAD)

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
	if not _ready: _prep()
	var y := _terrace
	if x <= _t_range.x: y += _t_edge.size()*SET_OFF
	elif x < _t_range.y:
		for i in _t_edge.size():
			var edge := _t_edge[i]+_t_amp[i]*sin(z*0.045+i*0.9)+1.2*sin(z*0.23+i*2.1)
			if _t_ramp[i] == 1:
				y += SET_OFF*clampf((edge-x)/_ramp,0.0,1.0)
				continue
			# A set-off scarp, slumped to a turf ramp along some of its
			# length (so the shoulder reads as broken ground, not bands).
			# Not along the hollow way (z past ~26): its inner wall stays
			# a wall, so the safe way stays the long way.
			var soft := smoothstep(0.25,0.7,0.6*sin(z*0.05+i*2.4)+0.4*sin(z*0.13+i*1.3))*(1.0-smoothstep(16.0,24.0,z))
			if soft <= 0.0:
				if x < edge: y += SET_OFF
			else: y += SET_OFF*clampf((edge-x)/lerpf(0.05,_ramp*1.3,soft),0.0,1.0)
	var q := Vector2(x,z)
	if _o_box.has_point(q):
		var d := q.distance_to(_o_at)
		var a := q.angle_to_point(_o_at)
		for i in _o_steps:
			if d < _o_reach-i*_o_tread+3.6*sin(a*2.0+i*1.7)+1.4*sin(a*5.0+i): y += SET_OFF
	return y

## The hollow way near (x, z): (distance from its line, how far along it,
## the side: < 0 its outer (void) side, its half width there).
static func gully_at(x: float, z: float) -> Vector4:
	if not _ready: _prep()
	var q := Vector2(x,z)
	if not _gully_box.has_point(q): return Vector4(INF,0.0,1.0,_g_half)
	var best := INF
	var best_s := 0.0
	var side := 0.0
	for i in _ga.size():
		var a := _ga[i]
		var d := _gd[i]
		var t := clampf((q-a).dot(d)/_gl2[i],0.0,1.0)
		var dist := q.distance_to(a+d*t)
		if dist < best:
			best = dist
			best_s = _gr[i]+t*_gl[i]
			side = d.cross(q-a)
	return Vector4(best,best_s,side,_g_half+1.0*sin(best_s*0.17))

static func gully_length() -> float:
	if not _ready: _prep()
	return _gully_len

## The hollow way's floor `s` m along it.
static func gully_floor(s: float) -> float:
	var n := clampi(int(floor((s-_g_flat)/_g_tread))+1,0,_g_steps)
	return minf(n*SET_OFF,_rim)

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

static func _on_slab(p: Vector2) -> Vector3:
	return Vector3(p.x,slab_ground(p.x,p.y),p.y)

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
		# The slab's low tip by its lamp, over the void (down its tilt and
		# back up).
		{"kind":"rune_risk","name":"slab_tip","at":_on_slab(Vector2(44.0,-44.0)),"room":1.0},
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
	var slab_y := func(x: float, z: float) -> float: return slab_ground(x,z)
	for land: Array in [[LAYOUT.main_outline,-50.0,Callable()],[LAYOUT.shelf_outline,-35.0,Callable()],[LAYOUT.slab.outline,-21.0,slab_y]]:
		var poly := PackedVector2Array(land[0])
		var ground: Callable = land[2]
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
						hi = maxf(hi,float(ground.call(x+o.x,z+o.y)) if ground.is_valid() else ground_at(x+o.x,z+o.y))
					out.append(["box",Rect2(x,z,cell,cell),float(land[1]),hi,"grey"])
				z += cell
			x += cell
	# The collapse's debris and the ledge under the pyramid's corner.
	for d: Array in LAYOUT.debris:
		var at: Vector2 = d[0]
		var r := float(d[2])
		out.append(["box",Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2.0),float(d[1])-float(d[3]),float(d[1])+2.0,"grey"])
	var lbox := Rect2((LAYOUT.ledge.outline as Array)[0],Vector2.ZERO)
	for q: Vector2 in LAYOUT.ledge.outline: lbox = lbox.expand(q)
	out.append(["box",lbox,float(LAYOUT.ledge.y)-20.0,float(LAYOUT.ledge.y)+3.0,"grey"])
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

## The plants' site: the rays reach from over the pyramid's drifts down
## past the gate hollow and the slab's low tip (the default span, from the
## shelf's datum, stopped 8 m under it: the hollow, the hollow way's low
## steps and the fallen chunk grew nothing), sown as the kit motifs are
## (sundered_gorge: 3 tufts a square metre at a drift's thickest), the worn
## ways read off a grid (`worn_at`).
func flora_site() -> KitFlora.Site:
	_prep()
	var site := KitFlora.Site.new(top(),func(p: Vector2) -> float: return worn_at(p))
	site.ray = Vector2(rim_y()+COURSE*4.0,-4.0)
	site.tufts = 2.8
	return site

func flora_seed() -> int:
	return SEED+9

## The worn ways: the shelf to the court and to its terraces, the hollow
## to the corbel, the hollow way, the terrace over the shoulder to the
## pyramid's stair foot and the way out.
static func paths() -> Array:
	var a: Vector2 = LAYOUT.arrive
	var out: Array = [[a,Vector2(26.0,4.0)],[a,Vector2(58.0,16.0),Vector2(54.0,40.0),Vector2(10.0,40.0),Vector2(-28.0,36.0)],
		[Vector2(-24.0,0.0),Vector2(-66.0,-4.0),Vector2(-104.0,-2.0),Vector2(-150.0,60.0)],[Vector2(-104.0,-2.0),Vector2(-140.0,22.0),Vector2(-180.0,27.0)],
		[Vector2(-104.0,-2.0),Vector2(-112.0,-60.0),Vector2(-108.0,-86.0)]]
	out.append(LAYOUT.gully.path)
	return out

## The worn ways as a grid (WEAR_CELL m, KitLand `wear_of`'s falloff,
## bilinear between): the plants and the turf's tone ask it some 300
## thousand times a build, and scanning every path's segments cost 1.5 us
## a call. Rasterized once in `_prep`.
const WEAR_CELL := 0.5
static var _wear := PackedFloat32Array()
static var _wear_box := Rect2()
static var _wear_w := 0
static var _wear_h := 0

static func _wear_grid() -> void:
	var ps := paths()
	var box := Rect2((ps[0] as Array)[0],Vector2.ZERO)
	for path: Array in ps:
		for q: Vector2 in path: box = box.expand(q)
	box = box.grow(3.0)
	_wear_box = box
	_wear_w = int(ceil(box.size.x/WEAR_CELL))+2
	_wear_h = int(ceil(box.size.y/WEAR_CELL))+2
	_wear.resize(_wear_w*_wear_h)
	_wear.fill(0.0)
	for path: Array in ps:
		for i in range(path.size()-1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i+1]
			var r := Rect2(a,Vector2.ZERO).expand(b).grow(2.2)
			var x0 := maxi(0,int((r.position.x-box.position.x)/WEAR_CELL))
			var x1 := mini(_wear_w-1,int((r.end.x-box.position.x)/WEAR_CELL)+1)
			var z0 := maxi(0,int((r.position.y-box.position.y)/WEAR_CELL))
			var z1 := mini(_wear_h-1,int((r.end.y-box.position.y)/WEAR_CELL)+1)
			for gz in range(z0,z1+1):
				for gx in range(x0,x1+1):
					var p := box.position+Vector2(gx,gz)*WEAR_CELL
					var w := clampf(1.25-p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))/1.5,0.0,1.0)
					var k := gz*_wear_w+gx
					if w > _wear[k]: _wear[k] = w

## How worn the ground is at `p` (0..1, motif frame).
static func worn_at(p: Vector2) -> float:
	if not _ready: _prep()
	var q := (p-_wear_box.position)/WEAR_CELL
	var gx := int(floor(q.x))
	var gz := int(floor(q.y))
	if gx < 0 or gz < 0 or gx >= _wear_w-1 or gz >= _wear_h-1: return 0.0
	var fx := q.x-gx
	var fz := q.y-gz
	var k := gz*_wear_w+gx
	return lerpf(lerpf(_wear[k],_wear[k+1],fx),lerpf(_wear[k+_wear_w],_wear[k+_wear_w+1],fx),fz)

## The life underground: kit_life's undergrowth and fireflies on the turf
## (scripts/kit_isle/greybox/coliseum_pit_life.gd); in the sky, all of it.
func life_script() -> Script:
	return ColiseumLife if Underground.on() else KitLife

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_prep()
	_computed()

## Measured headless on the Mac (build ms, the motif yard): the plateau's
## heightfield is most of it.
func build_cost() -> int:
	return 1500

## The pieces, by name, once built (for checks).
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "ColiseumPit"
	into.add_child(root)
	pieces.clear()
	timings.clear()
	_lap_at = Time.get_ticks_usec()
	_land(root)
	_collapse(root)
	_lap("collapse")
	# The court, sunk in the land.
	var court := CityLandmarks.court(SEED+2,float(LAYOUT.court.wear),{"foundation":float(LAYOUT.court.foundation)})
	court.name = "Court"
	court.transform = court_xf()
	root.add_child(court)
	pieces.court = court
	_lap("court")
	# The corbel gate in the hollow's west wall.
	var corbel := CityBreaks2.piece("maker_corbel",SEED+3,float(LAYOUT.corbel.wear))
	corbel.name = "CorbelGate"
	corbel.transform = corbel_xf()
	root.add_child(corbel)
	pieces.corbel = corbel
	_lap("corbel")
	# The pyramid on the high rim's brink, its summit cresset lit (still),
	# its corner slumped, its treads drifting back to turf.
	var pd: Dictionary = LAYOUT.pyramid
	var pyr := CityLandmarks.pyramid(SEED+4,float(pd.wear),{"foundation":float(pd.foundation),"fault":int(pd.fault),"lit":true})
	pyr.name = "Pyramid"
	pyr.transform = pyramid_xf()
	root.add_child(pyr)
	pieces.pyramid = pyr
	_lap("pyramid")
	_drifts(root)
	_lap("drifts")
	_stones(root)
	_lap("stones")
	built_ms = Time.get_ticks_msec()-began

## Where the build's time went (ms by part, for the budget).
var timings := {}
var _lap_at := 0

func _lap(part: String) -> void:
	var now := Time.get_ticks_usec()
	timings[part] = (now-_lap_at)/1000
	_lap_at = now

## The main ground's answers on the cliffs' scan lattice, kept: KitLand
## `cliff_points` asks each lattice point three times (as itself and as
## each neighbour's step), so two calls in three were repeats. Any other
## point goes straight to `main_ground`. One a build (not shared across
## workers).
class Lattice extends RefCounted:
	const Pit = preload("res://scripts/kit_isle/greybox/gb_coliseum_pit.gd")
	var o := Vector2.ZERO
	var w := 0
	var h := 0
	var grid := PackedFloat32Array()

	func _init(box: Rect2, nudge: Vector2) -> void:
		o = box.position+nudge
		w = int(box.size.x/KitLand.CLIFF_PROBE)+3
		h = int(box.size.y/KitLand.CLIFF_PROBE)+3
		grid.resize(w*h)
		grid.fill(NAN)

	func at(x: float, z: float) -> float:
		var fx := (x-o.x)/KitLand.CLIFF_PROBE
		var fz := (z-o.y)/KitLand.CLIFF_PROBE
		var ix := roundi(fx)
		var iz := roundi(fz)
		if ix < 0 or iz < 0 or ix >= w or iz >= h or absf(fx-ix) > 0.002 or absf(fz-iz) > 0.002: return Pit.main_ground(x,z)
		var k := iz*w+ix
		var y := grid[k]
		if is_nan(y):
			y = Pit.main_ground(x,z)
			grid[k] = y
		return y

## The islands: the main plateau (the hollow, the terrace, the shoulder,
## the high rim, the hollow way), the shelf, the fallen chunk, the court's
## bed, the lone spire.
func _land(root: Node3D) -> void:
	var wear := func(p: Vector2) -> float: return worn_at(p)
	var cliffs := Rect2(-155.0,-100.0,125.0,182.0)
	var nudge := Vector2(0.137,0.213)
	var lattice := Lattice.new(cliffs,nudge)
	var skip := corbel_rect().grow(1.0)
	var main := KitLand.island({"outline":LAYOUT.main_outline,"seed":SEED+11,"ground":lattice.at,
		"top":float(LAYOUT.terrace),"depth":70.0,"hang":true,"resample":[60.0,260,64],"tone":KitLook.turf(SEED+11,wear),
		"cell":3.0,"fine":1.2,"fine_box":Rect2(-50.0,22.0,26.0,30.0),"cliffs":cliffs,"cliffs_nudge":nudge,
		"cliff_skip":func(e: Vector2) -> bool: return skip.has_point(e)})
	main.name = "Plateau"
	root.add_child(main)
	turf(main)
	_lap("plateau")
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
	var top_y := float(st.top)
	var spire := KitLand.island({"outline":_blob(st.at,float(st.radius),9,0.3),"seed":SEED+15,"ground":func(_x: float, _z: float) -> float: return top_y,
		"top":top_y,"depth":26.0,"hang":true,"resample":[20.0,18,18],"tone":KitLook.turf(SEED+15),"cell":1.0})
	spire.name = "LoneSpire"
	root.add_child(spire)
	turf(spire)

## A rough round outline: `n` points round `at`, `radius` m out, its
## radius `wobble` of it in or out.
static func _blob(at: Vector2, radius: float, n: int, wobble: float) -> Array:
	var ring: Array = []
	for i in n:
		var a := TAU*i/float(n)
		ring.append(at+Vector2(cos(a),sin(a))*radius*(1.0-wobble*0.5+wobble*(0.5+0.5*sin(i*2.3))))
	return ring

## The slab's ground: `y` along its near edge (the first `near` points of
## its outline, by the shelf's lip), rising `rise` a metre out from it,
## rolled a little, lumpy.
static func slab_ground(x: float, z: float) -> float:
	var sd: Dictionary = LAYOUT.slab
	var line: Array = sd.outline
	var q := Vector2(x,z)
	var d := INF
	for i in range(int(sd.near)-1):
		d = minf(d,q.distance_to(Geometry2D.get_closest_point_to_segment(q,line[i],line[i+1])))
	return float(sd.y)+d*float(sd.rise)+(x-float(sd.x0))*float(sd.roll)+0.35*sin(x*0.37)*sin(z*0.29+0.6)*minf(1.0,d*0.3)

## The collapse into the void bay (LAYOUT `slab`, `debris`, `ledge`): the
## slab slid off the shelf's broken north end, the debris falling away under
## it, the ledge under the pyramid's slumped corner.
func _collapse(root: Node3D) -> void:
	var sd: Dictionary = LAYOUT.slab
	var slab := KitLand.island({"outline":sd.outline,"seed":SEED+16,"ground":func(x: float, z: float) -> float: return slab_ground(x,z),
		"top":float(sd.y),"depth":float(sd.depth),"hang":true,"resample":[40.0,64,40],"tone":KitLook.turf(SEED+16),"cell":2.0})
	slab.name = "Slab"
	root.add_child(slab)
	turf(slab)
	var k := 0
	for d: Array in LAYOUT.debris:
		var y := float(d[1])
		var isle := KitLand.island({"outline":_blob(d[0],float(d[2]),8,0.35),"seed":SEED+20+k,
			"ground":func(x: float, z: float) -> float: return y+0.4*sin(x*0.7+k)*sin(z*0.6),
			"top":y,"depth":float(d[3]),"hang":true,"resample":[20.0,14,12],"tone":KitLook.turf(SEED+20+k),"cell":1.6})
		isle.name = "Debris%d" % k
		root.add_child(isle)
		k += 1
	var ld: Dictionary = LAYOUT.ledge
	var ly := float(ld.y)
	var ledge := KitLand.island({"outline":ld.outline,"seed":SEED+24,"ground":func(x: float, z: float) -> float: return ly-(z+108.0)*0.18+0.3*sin(x*0.5),
		"top":ly,"depth":20.0,"hang":true,"resample":[30.0,30,20],"tone":KitLook.turf(SEED+24),"cell":1.5})
	ledge.name = "Ledge"
	root.add_child(ledge)
	turf(ledge)

## The pyramid's treads drifting back to turf (LAYOUT `pyramid.drifts`):
## earth heaped against the next tier's foot, thinning out to the tread's
## edge, each its own small turfed island, its sides sunk in the stone.
func _drifts(root: Node3D) -> void:
	var py := pyramid_xf().origin
	var mid := Vector2(py.x,py.z)
	var k := 0
	for d: Array in LAYOUT.pyramid.drifts:
		var tier := int(d[0])
		var f: Vector2 = d[1]
		var side := Vector2(-f.y,f.x)
		var outer := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-1-tier)*CityLandmarks.TREAD-CityLandmarks.PYR_BATTER
		var inner := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-2-tier)*CityLandmarks.TREAD
		var a_in := inner-1.0
		var a_out := outer-0.45
		var half := minf(float(d[3])*0.5,outer-1.0)
		var along := clampf(float(d[2]),-(outer-1.0-half),outer-1.0-half)
		var y0 := py.y+(tier+1)*COURSE
		var ring: Array = []
		for i in 18:
			var t := TAU*i/18.0
			var c := cos(t)
			var s := sin(t)
			var u := signf(c)*pow(absf(c),0.45)
			var v := signf(s)*pow(absf(s),0.6)
			var across := lerpf(a_in,a_out,0.5+0.5*u)
			var al := along+v*half*(0.9+0.1*sin(i*1.7+k))
			ring.append(mid+f*across+side*al)
		var rise := 2.3-0.3*tier
		var ground := func(x: float, z: float) -> float:
			var q := Vector2(x,z)-mid
			var u := clampf((q.dot(f)-a_in)/(a_out-a_in),0.0,1.0)
			var al := absf(q.dot(side)-along)/half
			var taper := 1.0-smoothstep(0.5,1.0,al)
			return y0+0.06+rise*pow(1.0-u,1.6)*taper+0.25*sin(x*0.8)*sin(z*0.7)*(1.0-u)
		var isle := KitLand.island({"outline":ring,"seed":SEED+30+k,"ground":ground,"top":y0,"depth":1.4,"hang":false,
			"resample":[30.0,36,24],"tone":KitLook.turf(SEED+30+k),"cell":1.1})
		isle.name = "Drift%d" % k
		root.add_child(isle)
		turf(isle)
		k += 1

## Fallen drums (cover), the pyramid's fallen courses, the slab's tumbled
## stand rows and the debris' blocks: one mesh of the Olmec's stone, and
## their shapes.
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
	# The pyramid's corner: its courses fallen down the slump to the brink.
	var corner := pyramid_corner(LAYOUT.pyramid.slump.corner)
	for d: Array in LAYOUT.pyramid.fallen:
		var p := corner+Vector2(-float(d[0]),-float(d[1]))
		var size: Vector3 = d[3]
		var y := main_ground(p.x,p.y) if is_nan(float(d[2])) else rim_y()+float(d[2])
		_block(g,solids,Vector3(p.x,y+size.y*0.18,p.y),size,d[4])
	# Each tier's corner over it sagged and slid out (its courses parting
	# from the core), so the stepped edges break where the corner went.
	var py := pyramid_xf().origin
	var sc: Vector2 = LAYOUT.pyramid.slump.corner
	for k in range(1,CityLandmarks.TIERS):
		var ck := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-1-k)*CityLandmarks.TREAD-CityLandmarks.PYR_BATTER
		var out := 2.4+0.6*k
		var at := Vector3(py.x+sc.x*(ck-3.0+out),py.y+k*COURSE+COURSE*0.45-(2.2-0.4*k),py.z+sc.y*(ck-3.0+out))
		var size := Vector3(10.0-1.6*k,COURSE*0.92,8.5-1.3*k)
		_block(g,solids,at,size,Vector3(16.0+9.0*k,-12.0-5.0*k,13.0-8.0*k))
		# And a course of it fallen onto the tread below.
		var low := Vector3(py.x+sc.x*(ck+3.6),py.y+k*COURSE+0.4,py.z+sc.y*(ck+1.2))
		_block(g,solids,low,Vector3(3.4,1.6,2.6),Vector3(-25.0*k,6.0,-14.0))
	# Courses fallen off every tier's lip onto the tread under it (not on
	# the stair's flight), more toward the slumped corner.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+50
	var notch := 0.5*CityKit.LANE+1.5
	for k in range(CityLandmarks.TIERS-1):
		var outer := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-1-k)*CityLandmarks.TREAD-CityLandmarks.PYR_BATTER
		var inner := CityLandmarks.SUMMIT_HALF+(CityLandmarks.TIERS-2-k)*CityLandmarks.TREAD
		var ty := py.y+(k+1)*COURSE
		for f: Vector2 in [Vector2(1.0,0.0),Vector2(-1.0,0.0),Vector2(0.0,1.0),Vector2(0.0,-1.0)]:
			var side := Vector2(-f.y,f.x)
			for n in int(RUBBLE_EACH):
				var al := rng.randf_range(-outer+1.2,outer-1.2)
				var at2 := Vector2(py.x,py.z)+f*rng.randf_range(inner+0.8,outer-0.6)+side*al
				if f.y > 0.0 and absf(at2.x-py.x) < notch: continue
				var near := 1.0-clampf(at2.distance_to(_slump_at)/60.0,0.0,1.0)
				if rng.randf() > 0.45+0.55*near: continue
				var size := Vector3(rng.randf_range(1.0,2.8),rng.randf_range(0.8,1.6),rng.randf_range(1.0,2.2))*(1.0+0.4*near)
				_block(g,solids,Vector3(at2.x,ty+size.y*0.32,at2.y),size,Vector3(rng.randf_range(-90.0,90.0),rng.randf_range(-14.0,14.0),rng.randf_range(-12.0,12.0)))
	# A piece of the shrine's comb, fallen onto the summit court.
	var summit_y := py.y+CityLandmarks.TIERS*COURSE
	_block(g,solids,Vector3(py.x+5.6,summit_y+0.7,py.z+1.0),Vector3(4.2,1.6,1.2),Vector3(-28.0,4.0,-80.0))
	# The slab's tumbled stand rows, lying with its tilt.
	var sd: Dictionary = LAYOUT.slab
	for s: Array in sd.stones:
		var size: Vector3 = s[2]
		var x := float(s[0])
		var z := float(s[1])
		var at := Vector3(x,slab_ground(x,z),z)
		var up := Vector3(slab_ground(x-0.5,z)-slab_ground(x+0.5,z),1.0,slab_ground(x,z-0.5)-slab_ground(x,z+0.5)).normalized()
		var b := Basis(Quaternion(Vector3.UP,up))*Basis(Vector3.UP,deg_to_rad(float(s[3])))
		var xf := Transform3D(b,at+up*size.y*0.3)
		g.box(xf,size,0.22,at.y-0.4,0.92)
		_block_shape(solids,xf,size)
	# A block or two on each piece of debris, one tipped on the ledge.
	var k := 0
	for d: Array in LAYOUT.debris:
		var at: Vector2 = d[0]
		var r := float(d[2])
		_block(g,solids,Vector3(at.x+0.2*r,float(d[1])+0.5,at.y-0.1*r),Vector3(r*0.9,r*0.45,r*0.6),Vector3(30.0*k+10.0,-12.0+9.0*k,14.0-11.0*k))
		k += 1
	_block(g,solids,Vector3(-131.0,float(LAYOUT.ledge.y)+0.9,-110.5),Vector3(5.5,3.0,4.2),Vector3(-22.0,18.0,-10.0))
	var mesh := MeshInstance3D.new()
	mesh.name = "StonesMesh"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)

## A fallen block at `at` (its middle), `size`, turned (yaw, pitch, roll
## deg), drawn and collided.
static func _block(g: RefCounted, solids: StaticBody3D, at: Vector3, size: Vector3, turn: Vector3) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(turn.y),deg_to_rad(turn.x),deg_to_rad(turn.z)),EULER_ORDER_YXZ)
	var xf := Transform3D(b,at)
	g.box(xf,size,0.25,at.y-size.y*0.5,0.9)
	_block_shape(solids,xf,size)

static func _block_shape(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	c.transform = xf
	body.add_child(c)

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
	# The collapse's: one still burning at the slab's low tip, one far down
	# on the debris, so the eye finds the fall from the arrival.
	var sl: Vector2 = LAYOUT.slab.lamp
	var deep: Array = LAYOUT.debris[int(LAYOUT.debris_lamp)]
	for at: Vector3 in [_on_slab(sl),Vector3((deep[0] as Vector2).x-1.2,float(deep[1]),(deep[0] as Vector2).y+1.0)]:
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
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the keepers back).
	for who: String in (["player","watcher"] if OlmecPlaces.keepers(g) else []):
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
	## Frames a keeper spent going to (or looking at) a beacon, not his beat.
	var lured := 0

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
			# Check before the typed assignment: a freed instance can't be put in a typed var.
			if not is_instance_valid(k.body) or not is_instance_valid(k.head):
				_refind(k)
				continue
			var body: Node3D = k.body
			var head: Node3D = k.head
			if not bool(k.landed):
				var stone: StaticBody3D = body.body
				k.landed = field.floor_under(k.post,2.0,6.0,stone.get_rid() if stone != null else RID()) > -INF
				if not bool(k.landed):
					body.position = k.post
					body.vel = Vector3.ZERO
					continue
			if not body.whole or body.hunting: continue
			# A lit beacon he heeds (a court cresset the walker lit) outranks
			# his beat: his own planner takes him there.
			if body.get("beacon") != null:
				lured += 1
				continue
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
		for e in field.enemies:
			if not is_instance_valid(e) or not e is Node3D: continue
			if e.has_method("make_whole") and e.position.distance_to(post) < 6.0: body = e
			elif e.has_method("mouth") and e.position.distance_to(post) < 12.0: head = e
		if body != null and head != null:
			body.make_whole(head)
			k.body = body
			k.head = head
			k.landed = false
			k.leg = 1
			k.dir = 1
