extends "res://scripts/kit_isle/motif_greybox.gd"
## The Face, a place of the underground Olmec city: a seated lord the size of a
## hill, cut out of a basalt cliff over the abyss, his face lit from below by
## the fires on his knees. You arrive on a ledge of turf at his feet.
##
##   the colossus  scripts/kit_isle/greybox/face_colossus.gd (a Blender model,
##                 art/blender/face_colossus/; STAND-IN for a kit piece): one
##                 figure, his lane (he climbs any of it), notches cut where
##                 the city kit's real pieces stand:
##   the shins     the facing sheet wall (maker_skin) between his feet, a
##                 coursed jamb post beside it with the old fire channel (a
##                 CityFires runnel) running up it to the cold bowl in his lap
##   the lap       a turf island between his knees, the great cresset (unlit)
##   the chest     the relief cliff (city_relief): ten carved bosses up it;
##                 its top is the collar shelf before his face
##   the shoulder  his left, cut flat, a turf cap; the hauling lip (city_lip)
##                 is the helmet's west ear flap, its shelves up to the crown
##   the crown     the helmet's flat top, turf: the high terrace, the rim out
##   the ridge     what is left of the cliff he was cut from: a long KitLand
##                 island stepping up west of him in set-off terraces, its tip
##                 a hop from the lip's top
##
## Routes (rim in on the ledge's south-west, rim out on the crown's north):
##   the face   light the channel's port: the flame runs up to the lap's bowl,
##              the Olmec on the ledge turns to it and climbs the skin wall,
##              which peels into an earth ramp; run up it past him, the
##              relief's bosses to the collar shelf, west onto the shoulder,
##              the lip's shelves up the flap to the crown.
##   the ridge  west off the ledge, up the ridge's terraces (a jump-catch
##              each), round behind his shoulder; hop from its tip onto the
##              lip's top, east onto the crown.
##
## Threat: the whole Olmec (headless body wearing his head, chase on) on the
## ledge's east end; he climbs after you (climb_after) up the shins, the
## chest and the flap and hauls over the helmet's brim. The breakables hub is
## his breaker: the skin wall, the lip's cracked corner, the cressets.
##
## Everything is one LAYOUT table near the top.
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const CityLight2 = preload("res://scripts/city_kit_light2.gd")
const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
const Colossus = preload("res://scripts/kit_isle/greybox/face_colossus.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const SO := RuinKit.SET_OFF
const SEED := 7700

# --- The layout: one table ----------------------------------------------------------------
## The frame: the middle of the skin wall's foot at x y z 0, the lord facing
## +z (south), the arrival on the ledge in front of him looking north (-z).
## The colossus's notches (Colossus.NOTCH) are cut for these numbers.
const LAP_Y := 9.6          # the skin wall's top (CityBreaks2 skin: two sheets of a course)
const COLLAR_Y := 27.2      # the relief's top (17.6 over the lap)
const CROWN_Y := 46.4       # the helmet's flat crown (the lip's top, 19.2 over the collar)
const KNEE_Y := 11.2
const LAYOUT := {
	# The shafts and keels fade to this depth (m) into the haze.
	"floor":-70.0,
	# The ledge at his feet: its outline (x, z), its west rise (x under which
	# the ground is a set-off up), its hanging depth.
	"ledge":{"outline":[Vector2(-50.0,10.0),Vector2(-42.0,3.0),Vector2(-31.0,4.0),Vector2(-25.0,-1.0),Vector2(-9.9,-1.0),Vector2(-9.9,0.3),
		Vector2(8.4,0.3),Vector2(8.4,-1.0),Vector2(24.0,-1.0),Vector2(29.5,4.0),Vector2(35.0,12.0),Vector2(33.0,21.0),Vector2(25.0,27.0),
		Vector2(12.0,31.0),Vector2(-2.0,34.0),Vector2(-16.0,33.0),Vector2(-28.0,35.5),Vector2(-41.0,31.0),Vector2(-50.0,22.0)],
		"rise":-38.0,"depth":16.0,"seed":SEED+1},
	# The lap's turf between his knees (behind the skin wall's core).
	"lap":{"outline":[Vector2(-12.6,-6.3),Vector2(12.6,-6.3),Vector2(12.6,-15.8),Vector2(-12.6,-15.8)],"seed":SEED+2},
	# His left shoulder's turf (cut flat), west of the relief's top.
	# It runs on east along the collar to the relief's top (his collarbone).
	"shoulder":{"outline":[Vector2(-7.6,-15.6),Vector2(-7.6,-22.4),Vector2(-10.0,-23.2),Vector2(-10.0,-36.4),Vector2(-15.0,-36.4),Vector2(-20.6,-34.6),Vector2(-21.2,-21.0),Vector2(-19.0,-17.0),Vector2(-12.4,-15.6)],"seed":SEED+3},
	# The collar's turf east of the relief's top (his right collarbone).
	"collar_e":{"outline":[Vector2(7.6,-15.6),Vector2(12.4,-15.6),Vector2(12.6,-22.4),Vector2(10.0,-23.2),Vector2(7.6,-22.4)],"seed":SEED+8},
	# The throne's back behind his head: the lip's foot, the ridge's end.
	"back":{"outline":[Vector2(-13.0,-40.6),Vector2(14.4,-40.6),Vector2(14.4,-50.4),Vector2(-13.0,-50.4)],"seed":SEED+7},
	# The crown: the helmet's flat top.
	"crown":{"outline":[Vector2(-8.6,-23.9),Vector2(8.5,-23.9),Vector2(8.5,-39.0),Vector2(6.8,-39.0),Vector2(6.8,-31.3),Vector2(-6.8,-31.3),Vector2(-6.8,-39.0),Vector2(-8.6,-39.0)],"seed":SEED+4},
	# The ridge: its centre line (x, z) from the ledge's west end round behind
	# his shoulder; half its width; its first terrace a set-off over the ledge,
	# then a set-off every `tread` m along the line; the tip `top` (m) flat for
	# its last `tip` m, a hop under the lip's top.
	"ridge":{"line":[Vector2(-46.0,12.0),Vector2(-54.0,-8.0),Vector2(-55.0,-30.0),Vector2(-45.0,-47.0),Vector2(-16.5,-46.0)],
		"half":8.0,"slope":1.0,"top":COLLAR_Y,"tip":8.0,"depth":20.0,"seed":SEED+5,"cracks":[24.0,47.0,70.0],"crack":0.7},
	# A stone standing alone in the gulf between the ridge and his left arm,
	# a long jump off a ridge terrace (the rare find on it): its middle, its
	# top, its radius.
	"gulf_stone":{"at":Vector2(-39.0,-4.6),"top":2.6*SO,"r":1.8,"seed":SEED+6},
	# The kit's pieces: the skin wall (its face z 0), the relief (its foot's
	# middle, width, depth back), the lip (its top's front middle, height),
	# the jamb post west of the skin (x0, x1, z0, z1).
	"skin":{"at":Vector3(0.0,0.0,0.0),"seed":SEED+10},
	# Its width the carved panel's and a hand's breadth (the lord's chest
	# wraps it).
	"relief":{"at":Vector3(0.0,LAP_Y,-16.0),"width":15.0,"deep":26.0,"seed":SEED+11},
	# The lip is the back of his head, facing north (its +x end, her
	# shelves, to the west).
	"lip":{"at":Vector3(0.0,CROWN_Y,-40.3),"turn":180.0,"height":CROWN_Y-COLLAR_Y,"width":15.4,"seed":SEED+12},
	"jamb":[-9.5,-7.55,-6.2,0.7],
	# The fires: the knees' great cressets (lit since forever: they draw no
	# one), the collar's lamps (lit), the lap's great cresset (cold: the
	# channel lights it, and it calls every Olmec in reach).
	"knees":[Vector3(-17.5,KNEE_Y,-1.5),Vector3(18.0,KNEE_Y,-2.0)],
	"lamps":[Vector3(-10.4,COLLAR_Y,-18.8),Vector3(10.6,COLLAR_Y,-19.2)],
	"bowl":Vector3(-7.4,LAP_Y,-11.2),
	# The whole Olmec on the ledge's east end, his beat and his first look.
	"keeper":{"beat":[Vector3(1.0,0.0,24.0),Vector3(14.0,0.0,21.0)],"face":Vector2(0.0,1.0)},
}

# --- The ridge ---------------------------------------------------------------------------

## The ridge line's length (m).
static func ridge_length() -> float:
	var line: Array = LAYOUT.ridge.line
	var n := 0.0
	for i in range(1,line.size()): n += (line[i] as Vector2).distance_to(line[i-1])
	return n

## How far along the ridge's line (m) the point nearest (x, z) is, and how far
## off the line it is.
static func ridge_along(x: float, z: float) -> Vector2:
	var line: Array = LAYOUT.ridge.line
	var p := Vector2(x,z)
	var best := Vector2(0.0,INF)
	var run := 0.0
	for i in range(1,line.size()):
		var a: Vector2 = line[i-1]
		var b: Vector2 = line[i]
		var d := b-a
		var t := clampf((p-a).dot(d)/d.length_squared(),0.0,1.0)
		var off := (a+d*t).distance_to(p)
		if off < best.y: best = Vector2(run+d.length()*t,off)
		run += d.length()
	return best

## The ridge's ground: terraces of lawn along its line, each rising gently
## (`slope` m over its length) to a set-off cliff onto the next (a jump-catch,
## a real lip); the first a set-off over the ledge; flat on its tip.
static func ridge_ground(x: float, z: float) -> float:
	var r: Dictionary = LAYOUT.ridge
	var a := ridge_along(x,z)
	var top := float(r.top)
	if a.x >= ridge_length()-float(r.tip): return top
	var slope := float(r.slope)
	var rise := SO+slope
	var tread := (ridge_length()-float(r.tip))/((top-SO)/rise)
	# The terraces' edges wander across the ridge (not stripes).
	var s := maxf(a.x+1.4*sin(a.y*0.4+a.x*0.11)+2.2*sin(a.x*0.07),0.0)
	var k := floorf(s/tread)
	return minf(SO+rise*k+slope*(s/tread-k),top)

## The ridge's blocks: it slumped apart into great blocks along its line,
## a crack between each (`cracks`, m along the line; `crack` m wide: a step
## across). Each block an island of its own (KitLand's sides hang toward its
## middle, so a crescent as one island would hang its rock across the gulf).
static func ridge_blocks() -> Array:
	var r: Dictionary = LAYOUT.ridge
	var out: Array = []
	var cuts: Array = [0.0]
	cuts.append_array(r.cracks)
	cuts.append(ridge_length())
	for i in range(cuts.size()-1):
		var s0 := float(cuts[i])+(float(r.crack)*0.5 if i > 0 else 0.0)
		var s1 := float(cuts[i+1])-(float(r.crack)*0.5 if i < cuts.size()-2 else 0.0)
		out.append(ridge_outline(s0,s1,i))
	return out

## The ridge's outline from `s0` to `s1` m along its line: the line offset
## each side a ragged half-width, the ends cut square (a crack) or rounded
## (the ridge's own ends).
static func ridge_outline(s0: float, s1: float, k := 0) -> Array:
	var r: Dictionary = LAYOUT.ridge
	var half := float(r.half)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.seed)+k*31
	var left: Array = []
	var right: Array = []
	var total := ridge_length()
	var n := maxi(int(ceil((s1-s0)/4.0)),2)
	for i in range(n+1):
		var s := lerpf(s0,s1,float(i)/n)
		var at := _ridge_point(s)
		var end := i == 0 or i == n
		var w := half*((0.95 if end else 0.8+0.35*rng.randf()))*(0.75 if s > total-8.0 else 1.0)
		left.append(at[0]+(at[1] as Vector2)*w)
		right.append(at[0]-(at[1] as Vector2)*w*(1.0 if end else 0.85+0.3*rng.randf()))
	var out: Array = left
	if s1 >= total-0.01:
		var e: Array = _ridge_point(total)
		out.append(e[0]+Vector2((e[1] as Vector2).y,-(e[1] as Vector2).x)*half*0.6)
	right.reverse()
	out.append_array(right)
	if s0 <= 0.01:
		var b: Array = _ridge_point(0.0)
		out.append(b[0]-Vector2((b[1] as Vector2).y,-(b[1] as Vector2).x)*half*0.5)
	return out

## [point, left normal] at `s` m along the ridge's line.
static func _ridge_point(s: float) -> Array:
	var line: Array = LAYOUT.ridge.line
	var run := 0.0
	for i in range(1,line.size()):
		var a: Vector2 = line[i-1]
		var b: Vector2 = line[i]
		var l := a.distance_to(b)
		if s <= run+l or i == line.size()-1:
			var t := clampf((s-run)/l,0.0,1.0)
			var d := (b-a).normalized()
			return [a.lerp(b,t),Vector2(-d.y,d.x)]
		run += l
	return [line[0],Vector2.RIGHT]

## The ledge's ground: flat, a set-off up west of `rise` (its edge wandering).
static func ledge_ground(x: float, z: float) -> float:
	var edge := float(LAYOUT.ledge.rise)+2.5*sin(z*0.2+0.7)
	return SO if x < edge else 0.0

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "face"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Face"

func epithet() -> String:
	return "He sat down to watch the dark. The dark came up to his knees and stayed."

func brief() -> String:
	return "Up: light the old channel at his shin and let the Olmec climb into the lap (the shins peel), then his chest's bosses and the ear flap's shelves; or the long ridge west.\nThe Olmec keeps the ledge. Lose him above and he climbs after you."

func start() -> Vector3:
	return Vector3(-24.0,0.0,27.0)

## In on the ledge's south-west edge; out on the crown's north edge.
func rims() -> Array:
	return [
		{"name":"ledge","at":Vector3(-24.0,0.0,31.5),"face":Vector3(0.0,0.0,1.0),"run_up":14.0,"lip":1.5},
		{"name":"crown","at":Vector3(2.0,CROWN_Y,-38.9),"face":Vector3(0.0,0.0,-1.0),"run_up":10.0,"lip":1.4},
	]

func spots() -> Array:
	var out := [
		{"kind":"arena","name":"ledge","at":Vector3(-6.0,0.0,18.0),"room":14.0},
		{"kind":"arena","name":"lap","at":Vector3(4.5,LAP_Y,-11.0),"room":5.0},
		{"kind":"cover","name":"lip_undercut","at":lip_port("undercut"),"room":1.5},
		{"kind":"perch","name":"ridge_tip","at":Vector3(-20.0,float(LAYOUT.ridge.top),-46.0),"room":3.0},
		{"kind":"perch","name":"east_knee","at":Vector3(18.0,KNEE_Y,3.0),"room":2.0},
	]
	out.append_array(collect_spots())
	return out

## The collectibles' spots for the next round: runes along the routes and
## just off them, the tempting detours, the rare finds.
func collect_spots() -> Array:
	var out: Array = []
	# Runes along the face: the ramp's line, the lap, the relief's bosses, the
	# collar shelf, the lip's shelves, the crown.
	for p: Vector3 in [Vector3(-3.0,0.0,6.0),Vector3(0.0,LAP_Y,-8.0),Vector3(3.0,LAP_Y,-13.5)]:
		out.append({"kind":"rune_line","name":"face","at":p,"room":1.0})
	for k in range(1,10,2): out.append({"kind":"rune_line","name":"relief","at":relief_hold_top(k)+Vector3(0.0,0.6,0.0),"room":0.6})
	for p: Vector3 in [Vector3(-6.0,COLLAR_Y,-19.0),Vector3(-16.0,COLLAR_Y,-26.0),Vector3(-4.0,CROWN_Y,-27.0)]:
		out.append({"kind":"rune_line","name":"face","at":p,"room":1.0})
	for b: Dictionary in Colossus.holds():
		var bx: AABB = b.box
		if int(b.i)%3 == 1: out.append({"kind":"rune_line","name":"flank","at":Vector3(bx.position.x,bx.end.y+0.6,bx.get_center().z),"room":0.6})
	# Runes along the ridge, every few terraces (it is the poor way: few).
	var total := ridge_length()
	for s: float in [12.0,34.0,56.0,total-3.0]:
		var at: Array = _ridge_point(s)
		var q: Vector2 = at[0]
		out.append({"kind":"rune_line","name":"ridge","at":Vector3(q.x,ridge_ground(q.x,q.y),q.y),"room":1.0})
	# Tempting detours: the east knee's dais beside the lit bowl (lit: you are
	# seen, over the void); the collar shelf's east end under his chin, in
	# his reach from the lap; the ledge's east point by his beat.
	out.append({"kind":"rune_risk","name":"east_knee","at":Vector3(20.0,KNEE_Y,1.0),"room":1.0})
	out.append({"kind":"rune_risk","name":"collar_east","at":Vector3(11.0,COLLAR_Y,-17.0),"room":1.0})
	out.append({"kind":"rune_risk","name":"ledge_point","at":Vector3(31.0,0.0,13.0),"room":1.0})
	# Rare: inside the lip's undercut (hidden); on the stone in the gulf (a
	# long jump off the ridge over the void, and back); in the peeled skin's
	# earth, behind the break (only once a column is down).
	var gs: Dictionary = LAYOUT.gulf_stone
	out.append({"kind":"rare","name":"lip_undercut","at":lip_port("undercut"),"room":0.6})
	out.append({"kind":"rare","name":"gulf_stone","at":Vector3(gs.at.x,float(gs.top),gs.at.y),"room":0.8})
	out.append({"kind":"rare","name":"behind_the_skin","at":Vector3(-1.5,7.0,-3.0),"room":0.8})
	return out

## The lip's place: its top's front middle, turned (its front +z to -x).
static func lip_xform() -> Transform3D:
	var l: Dictionary = LAYOUT.lip
	return Transform3D(Basis(Vector3.UP,deg_to_rad(float(l.turn))),l.at)

## A point of the lip's own frame (CityClimb `lip`'s, front +z, y 0 its top)
## in the motif's: the undercut under the cornice at the face's south end, the
## face's foot, the shelves' foot. As the piece computes them.
static func lip_port(key: String) -> Vector3:
	var l: Dictionary = LAYOUT.lip
	var h := float(l.height)
	var s: Dictionary = preload("res://scripts/city_kit_climb.gd").sizes()
	var w2 := float(l.width)*0.5
	var local := Vector3.ZERO
	match key:
		"undercut": local = Vector3(w2-0.5*SO-float(s.shelf.x)-1.6,-(float(s.cornice)+float(s.undercut))+0.05,-0.6)
		"foot": local = Vector3(0.0,-h,2.5)
		"shelf_foot": local = Vector3(w2-0.5*SO-float(s.shelf.x),-h,2.0)
	return lip_xform()*local

## The relief's hold `k`'s top (motif frame), from the relief's own table
## (a set-off apart, x alternating).
static func relief_hold_top(k: int) -> Vector3:
	const X := [0.0,1.7,3.55,1.65,3.3,1.6,3.45,1.55,3.4,1.6]
	var r: Dictionary = LAYOUT.relief
	var at: Vector3 = r.at
	return at+Vector3(float(X[k]),SO*(k+1),0.6)

## The solids for the occupancy, the footprint and the bodies' cliffs (the
## generator reads these, never the build).
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	# The ledge (its rect) and the ridge's terraces, a box a tread.
	out.append(["box",_bounds(LAYOUT.ledge.outline).grow(-2.0),-float(LAYOUT.ledge.depth),0.0,"grey"])
	var total := ridge_length()
	var s := 0.0
	while s < total:
		var at: Array = _ridge_point(s)
		var q: Vector2 = at[0]
		var h := float(LAYOUT.ridge.half)*0.8
		out.append(["box",Rect2(q-Vector2(h,h),Vector2(h,h)*2.0),ridge_ground(q.x,q.y)-float(LAYOUT.ridge.depth),ridge_ground(q.x,q.y),"grey"])
		s += 8.0
	# The colossus: his root and seat, the lap, the chest, the head.
	out.append(["box",Rect2(-26.0,-42.0,52.0,42.0),floor_y,0.0,"grey"])
	out.append(["box",Rect2(-28.0,-38.0,56.0,44.0),0.0,LAP_Y,"grey"])
	out.append(["box",Rect2(-12.0,-42.0,24.0,26.0),LAP_Y,COLLAR_Y,"grey"])
	out.append(["box",Rect2(-24.0,-36.0,12.0,22.0),LAP_Y,COLLAR_Y,"grey"])
	out.append(["box",Rect2(12.0,-36.0,12.0,22.0),LAP_Y,COLLAR_Y+3.0,"grey"])
	out.append(["box",Rect2(-9.7,-40.1,19.4,17.3),COLLAR_Y,CROWN_Y,"grey"])
	var gs: Dictionary = LAYOUT.gulf_stone
	out.append(["box",Rect2(gs.at-Vector2.ONE*float(gs.r),Vector2.ONE*float(gs.r)*2.0),float(gs.top)-22.0,float(gs.top),"grey"])
	out.append(["box",Rect2(-7.7,-40.3,15.4,8.8),COLLAR_Y,CROWN_Y,"grey"])
	out.append(["box",Rect2(-15.0,-51.0,30.0,11.0),12.6,COLLAR_Y,"grey"])
	return out

static func _bounds(outline: Array) -> Rect2:
	var r := Rect2(outline[0],Vector2.ZERO)
	for p: Vector2 in outline: r = r.expand(p)
	return r

# --- The land and the stone ------------------------------------------------------------

## The flora's rays reach down from over the crown to under the ledge (the
## lowest turf, 46 m under the top: the Site's default reach stops 8 m under
## it, which left the ledge and the ridge without blades); fewer tufts a
## square metre to hold the cost of so much turf.
const LOWEST_TURF := 0.0
func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(top(),KitLand.wear_of(paths()))
	site.ray = Vector2(top()+60.0,LOWEST_TURF-6.0)
	site.tufts = 2.8
	return site

func flora_seed() -> int:
	return SEED+9

## The worn ways on the ledge: the arrival to the channel's port, and west to
## the ridge's foot.
static func paths() -> Array:
	return [[Vector2(-24.0,27.0),Vector2(-14.0,12.0),Vector2(-9.0,3.0)],[Vector2(-24.0,27.0),Vector2(-38.0,18.0),Vector2(-45.0,12.0)]]

func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	Colossus.warm()
	_computed()

func build_cost() -> int:
	return 900

## The pieces, by name, once built.
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Face"
	into.add_child(root)
	pieces.clear()
	# The colossus.
	var lord := Colossus.stand()
	lord.name = "Colossus"
	root.add_child(lord)
	pieces.colossus = lord
	# The land: the ledge, the lap, the shoulder, the crown, the ridge.
	var tone := KitLook.turf(int(LAYOUT.ledge.seed),KitLand.wear_of(paths()))
	var ld: Dictionary = LAYOUT.ledge
	var b := _bounds(ld.outline)
	_land(root,"Ledge",{"outline":ld.outline,"seed":int(ld.seed),"ground":func(x: float, z: float) -> float: return ledge_ground(x,z),
		"top":0.0,"depth":float(ld.depth),"hang":true,"cliffs":b.grow(2.0),"resample":[60.0,140,48],"tone":tone,"cell":2.0},true)
	_turf_cap(root,"Lap",LAYOUT.lap,LAP_Y,2.0)
	_turf_cap(root,"Shoulder",LAYOUT.shoulder,COLLAR_Y,3.0)
	_turf_cap(root,"CollarE",LAYOUT.collar_e,COLLAR_Y,2.4)
	_turf_cap(root,"Crown",LAYOUT.crown,CROWN_Y,2.6)
	_turf_cap(root,"Back",LAYOUT.back,COLLAR_Y,2.6)
	var r: Dictionary = LAYOUT.ridge
	var k := 0
	for outline: Array in ridge_blocks():
		var rb := _bounds(outline)
		var hi := -INF
		for q: Vector2 in outline: hi = maxf(hi,ridge_ground(q.x,q.y))
		_land(root,"Ridge%d" % k,{"outline":outline,"seed":int(r.seed)+k,"ground":func(x: float, z: float) -> float: return ridge_ground(x,z),
			"top":hi,"depth":float(r.depth),"hang":true,"cliffs":rb.grow(2.0),"fine":1.2,"resample":[60.0,90,40],"tone":KitLook.turf(int(r.seed)),"cell":2.0},true)
		k += 1
	# The stone in the gulf: a lone stack of rock with a cap of turf.
	var gs: Dictionary = LAYOUT.gulf_stone
	var ring: Array = []
	for i in 9:
		var t := TAU*i/9.0
		ring.append(gs.at+Vector2(cos(t),sin(t))*float(gs.r)*(0.85+0.3*fposmod(sin(i*7.1),1.0)))
	_land(root,"GulfStone",{"outline":ring,"seed":int(gs.seed),"ground":func(_x: float, _z: float) -> float: return float(gs.top),
		"top":float(gs.top),"depth":22.0,"hang":true,"resample":[20.0,24,18],"tone":KitLook.turf(int(gs.seed)),"cell":1.0},true)
	# The skin wall between his feet.
	var sk: Dictionary = LAYOUT.skin
	var skin := CityBreaks2.piece("maker_skin",int(sk.seed),0.55)
	skin.name = "SkinWall"
	skin.position = sk.at
	root.add_child(skin)
	pieces.skin = skin
	# The jamb post west of it (the channel runs up its face).
	var j: Array = LAYOUT.jamb
	var m := CityStone.Mesher.new(CityStone.stone_colour(),0.3)
	var course := SO*2.0
	var y := 0.0
	k = 0
	while y < LAP_Y-0.01:
		var y1 := minf(y+course,LAP_Y)
		var inset := 0.06 if k%2 == 0 else 0.0
		m.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3((float(j[0])+float(j[1]))*0.5,(y+y1)*0.5,(float(j[2])+float(j[3]))*0.5)),
			Vector3((float(j[1])-float(j[0]))*0.5-inset,(y1-y)*0.5-0.02,(float(j[3])-float(j[2]))*0.5-inset),0.08),NAN,0.92+0.04*float(k%3))
		y = y1
		k += 1
	var jamb := MeshInstance3D.new()
	jamb.name = "Jamb"
	jamb.mesh = CityStone.mesh_of(m,"pier")
	root.add_child(jamb)
	solid_box(Rect2(float(j[0]),float(j[2]),float(j[1])-float(j[0]),float(j[3])-float(j[2])),0.0,LAP_Y)
	# The relief: his chest.
	var rl: Dictionary = LAYOUT.relief
	var relief: Node3D = CityLight2.relief(root,Transform3D(Basis.IDENTITY,rl.at),{"width":float(rl.width),"deep":float(rl.deep),"seed":int(rl.seed),"name":"Chest"})
	pieces.relief = relief
	# The hauling lip: the helmet's west ear flap.
	var lp: Dictionary = LAYOUT.lip
	var lip := CityKit.stand("city_lip",root,lip_xform(),int(lp.seed),0.6,{"height":float(lp.height),"width":float(lp.width)})
	lip.name = "EarFlap"
	pieces.lip = lip
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## A KitLand island in the motif's frame (its sides collided as drawn when
## `sides`: KitLand draws them only, and the bodies climb them).
func _land(root: Node3D, node_name: String, spec: Dictionary, sides := false) -> Node3D:
	var land := KitLand.island(spec)
	land.name = node_name
	root.add_child(land)
	if sides: _collide_sides(land)
	turf(land)
	return land

## A turf cap on a cut-flat top of the colossus at `y`, its edge hanging.
func _turf_cap(root: Node3D, node_name: String, d: Dictionary, y: float, depth: float) -> void:
	var outline: Array = []
	for p: Vector2 in d.outline: outline.append(p)
	var land := KitLand.island({"outline":outline,"seed":int(d.seed),"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":depth,"hang":true,"resample":[40.0,60,32],"tone":KitLook.turf(int(d.seed)),"cell":2.0})
	land.name = node_name
	land.position = Vector3(0.0,y,0.0)
	root.add_child(land)
	turf(land)

## An island's hanging sides collided as drawn (gb_sunken_giant's way).
static func _collide_sides(land: Node3D) -> void:
	var mesh := land.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null or mesh.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.mesh.create_trimesh_shape()
	body.add_child(shape)
	land.add_child(body)

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces.values(): n += int(p.get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The fires and the channel, the breakables hub, the whole Olmec and his beat,
## and (in the abyss) the grass on the lip's top once it stands.
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var k := 0
	for at: Vector3 in LAYOUT.knees:
		var c: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"great","seed":SEED+30+k,"name":"KneeFire%d" % k,"lit":true,"draw":1.0})
		_still(c)
		k += 1
	for at: Vector3 in LAYOUT.lamps:
		var c: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":SEED+40+k,"name":"CollarLamp%d" % k,"lit":true,"draw":1.0,"barge":false})
		_still(c)
		k += 1
	var bowl: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(LAYOUT.bowl)),{"size":"great","seed":SEED+50,"name":"LapBowl","lit":false})
	var line := channel_line()
	var pts: Array = []
	for p: Vector3 in line[0]: pts.append(g.w(p))
	CityFires.runnel(fires,Transform3D.IDENTITY,pts,line[1],{"tail":bowl,"name":"Channel"})
	# The hub: every Olmec's breaker (the skin, the lip's corner, the bowls).
	var hub: Node3D = Breakables.new()
	hub.name = "Breakables"
	hub.field = g.stage.enemies
	g.add_child(hub)
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the Keeper back).
	if OlmecPlaces.keepers(g):
		var kd: Dictionary = LAYOUT.keeper
		var beat: Array[Vector3] = []
		for p: Vector3 in kd.beat: beat.append(g.w(p))
		var post: Vector3 = beat[0]
		var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,kd.face,{"chase":1,"chase_routes":1,"seed":SEED})
		var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,kd.face,{})
		var keeper := Keeper.new()
		keeper.name = "Keeper_STANDIN"
		keeper.beat = beat
		keeper.post = post
		keeper.field = g.stage.enemies
		keeper.hub = hub
		keeper.wear(body,head)
		g.add_child(keeper)
	if Underground.on():
		var dresser := Dresser.new()
		dresser.name = "Dresser"
		dresser.motif = self
		g.add_child(dresser)

## The channel's line (motif frame) and its normals: from the feed port at the
## jamb post's foot up its front face, over its top, across the lap's turf to
## the bowl's plinth and up its face.
static func channel_line() -> Array:
	var j: Array = LAYOUT.jamb
	var x := (float(j[0])+float(j[1]))*0.5
	var front := float(j[3])+0.004
	var bowl: Vector3 = LAYOUT.bowl
	var plinth := 3.2*CityFires.size()
	var pts: Array = [Vector3(x,0.9,front),Vector3(x,LAP_Y-0.06,front),Vector3(x,LAP_Y+0.004,front-0.4),Vector3(x,LAP_Y+0.004,float(j[2])+0.2),
		Vector3(x,LAP_Y+0.02,bowl.z+plinth+0.004),Vector3(bowl.x-1.2,LAP_Y+0.02,bowl.z+plinth+0.004),Vector3(bowl.x-1.2,LAP_Y+SO-0.05,bowl.z+plinth+0.004)]
	var f := Vector3.BACK
	var nrm: Array = [f,f,(f+Vector3.UP).normalized(),Vector3.UP,Vector3.UP,Vector3.UP,f]
	return [pts,nrm]

## A fire lit since the city emptied: its beacon draws no Olmec.
static func _still(fire: Node) -> void:
	var b: Object = fire.get("beacon")
	if b != null: b.set("draw",1.0)

## STAND-IN: the Olmec's rounds on the ledge (gb_stacked_court's Keeper): steers
## the unaware Olmec between his beat's points, holds him at his post till the
## stone under him stands, puts his head back after the yard's reset, and
## hands every Olmec the breakables hub.
class Keeper extends Node:
	var beat: Array[Vector3] = []
	var post := Vector3.ZERO
	var field: Node = null
	var hub: Node3D = null
	var body: Node3D = null
	var head: Node3D = null
	var leg := 1
	var dir := 1
	var landed := false
	var turns := 0
	var steered := 0

	func wear(b: Node3D, h: Node3D) -> void:
		body = b
		head = h
		if body != null and head != null: body.make_whole(head)

	func _physics_process(_delta: float) -> void:
		if field != null:
			for e in field.enemies:
				if is_instance_valid(e) and e.has_method("world_changed") and e.get("breaker") == null: e.breaker = hub
		if body == null or not is_instance_valid(body) or head == null or not is_instance_valid(head):
			_refind()
			return
		if not landed:
			var stone: StaticBody3D = body.body
			landed = field.floor_under(post,2.0,6.0,stone.get_rid() if stone != null else RID()) > -INF
			if not landed:
				body.position = post
				body.vel = Vector3.ZERO
				return
		if not body.whole or body.hunting: return
		if not (str(body.state) in ["listen","roam"]): return
		var to: Vector3 = beat[leg]
		var flat := Vector2(to.x-body.position.x,to.z-body.position.z)
		if flat.length() < 3.0:
			if leg+dir < 0 or leg+dir >= beat.size(): dir = -dir
			leg += dir
			turns += 1
			to = beat[leg]
			flat = Vector2(to.x-body.position.x,to.z-body.position.z)
		body._heading = PilotMotor.facing_of(flat.normalized())
		steered += 1

	func _refind() -> void:
		if field == null: return
		body = null
		head = null
		for e: Node3D in field.enemies:
			if not is_instance_valid(e): continue
			if e.has_method("make_whole") and e.position.distance_to(post) < 6.0: body = e
			elif e.has_method("mouth") and e.position.distance_to(post) < 12.0: head = e
		if body != null and head != null:
			body.make_whole(head)
			landed = false
			leg = 1
			dir = 1

## The abyss's ground cover on the lip's top once it stands.
class Dresser extends Node:
	var motif: RefCounted
	var laid := 0

	func _physics_process(_delta: float) -> void:
		var art: Node3D = motif.get("art")
		if art == null or not art.is_inside_tree(): return
		var pieces: Dictionary = motif.get("pieces")
		if pieces.is_empty(): return
		var kind := GroundCover.asked()
		if kind == "":
			set_physics_process(false)
			return
		var p: Node3D = pieces.get("lip")
		if p == null or not is_instance_valid(p) or not p.is_inside_tree(): return
		for a: Dictionary in p.get_meta("walk_areas",[]):
			if String(a.kind) != "top": continue
			if GroundCover.cover(p,a.poly,kind,float(a.y),SEED+60,{}) != null: laid += 1
		# The skin wall's earth tops, each on its column's core (it goes with
		# the column when it peels).
		var skin: Node3D = pieces.get("skin")
		if skin != null and is_instance_valid(skin):
			for c in skin.cols.size():
				var core: Node3D = skin.cols[c].core_mesh
				if core == null or not is_instance_valid(core): continue
				var x: float = skin.col_x(c)
				var w := 1.5-0.02
				if GroundCover.cover(core,Rect2(x-w,-6.0+0.05,w*2.0,5.95),kind,LAP_Y+0.002,SEED+70+c,{"tufts":0.6}) != null: laid += 1
		# Grass in the hollows of the lord's tops (his moss is his own).
		var lord: Node3D = pieces.get("colossus")
		if lord != null and is_instance_valid(lord):
			var i := 0
			for t: Dictionary in Colossus.tufts():
				if GroundCover.cover(lord,t.poly,kind,float(t.y),SEED+90+i,{"skin":false,"tufts":1.3}) != null: laid += 1
				i += 1
		set_physics_process(false)
