extends "res://scripts/kit_isle/kit_motif.gd"
## The dragon's roost as a motif (scripts/kit_isle/kit_motif.gd; docs/design/
## dragon-roost/round1.md): a tall crag mountain on its own floating rock, the
## sky dragon's home. A meadow round its foot (turf, the plane can set down),
## a massif of stepped crags cut into buttresses rising out of it to a steep
## upper cone, a narrow shelf at the top and out of it a fluted needle of
## rock, the summit. Round the upper cone the dragon lies coiled
## (scripts/dragon_roost.gd): the rock is cut for it, a groove wound down
## from the shelf like a thread round the peak (`coil`, `_groove`), worn by
## its sleeping, so its body lies in the flank and never in the rock. On the
## shelf by its head, a chest (its hoard, for later) and a fallen pier.
## Under it all the keel hangs, the kit isles' rock (scripts/kit_isle/
## kit_look.gd).
##
## Its own frame is every motif's (the middle near the aqueduct isle's, its
## meadow at 30 m); the aqueduct isle's sky stands it AT from there, out past
## the motif isles to the south-east and high, a landmark from the aqueduct
## isle (scripts/kit_isle/motif_sky.gd, with --dragon-roost). The ground
## (`ground`) is one height function, so the dragon's pose reads the same
## rock the isle is built of, without a physics query.

## Where it stands from its own frame (motif_sky.gd PLACES' way): its middle
## at world (680, 540), 820 m south-east of the aqueduct isle's, its meadow
## 55 m over the aqueduct isle's turf.
const AT := Vector3(600.0,55.0,550.0)
const SEED := 97
## Its meadow's datum and middle (own frame), the outline's radius.
const TOP := 30.0
const O := Vector2(80.0,-10.0)
const R := 74.0
## The mountain's axis (a little off the middle, so the meadow is broad on
## one side, the side facing the aqueduct isle).
const AXIS := Vector2(88.0,-2.0)
## The massif: its foot's radius, its crag steps (m) and how much they step.
const FOOT_R := 52.0
const STEP := 7.0
const STEPPED := 0.55
## The shelf round the needle: its radius and height over the meadow; under
## it the upper cone (the coil's flank) falls, CONE m out for each m down,
## for CONE_DROP m; then the massif's crags to the foot.
const SHELF_R := 10.5
const SHELF_UP := 72.0
const CONE := 0.32
const CONE_DROP := 48.0
## The needle: its foot's radius on the shelf, its height over it.
const NEEDLE_R := 7.5
const NEEDLE_UP := 34.0
## The keel under the meadow (m).
const DEPTH := 64.0

## The coil (scripts/dragon_roost.gd lays the dragon on it): the dragon's
## size (sky_dragon.gd `size`), its spine by rest z (model m, head tip to
## tail tip, every COIL_DZ), its girth there (GIRTH: the hide's reach round
## its bones, about the 90th percentile), wound round the axis from the
## chest at CHEST_AT (deg) with the head end going up the angle; its belly
## falls DESCENT m a metre from the head (on the shelf) down to the tail,
## each point out from the axis where the upper cone is at its belly's
## height, plus OUT_SHARE of its girth (so it bulges out of the flank).
const DRAGON_SIZE := 1.3
const HEAD_TIP := -35.5
const CHEST_Z := 3.5
const TAIL_TIP := 52.5
const COIL_DZ := 0.5
const GIRTH := [[-35.5,1.5],[-31.0,2.3],[-24.5,3.3],[-20.6,3.1],[-16.2,3.2],[-11.9,3.8],[-7.5,4.7],[-3.0,5.5],[3.5,5.3],
	[8.5,3.3],[13.5,2.7],[19.0,2.1],[24.5,1.7],[30.0,1.3],[35.5,1.0],[41.0,0.7],[46.5,0.45],[52.5,0.3]]
const CHEST_AT := 215.0
const DESCENT := 0.36
const OUT_SHARE := 0.75
## The groove: its floor GROOVE_GAP under the belly across GROOVE_FLAT of
## the girth either side of the line, then rising GROOVE_RISE m a metre.
const GROOVE_GAP := 0.35
const GROOVE_FLAT := 0.7
const GROOVE_RISE := 3.5

static var _coil := {}

func id() -> String:
	return "dragon_roost"

func isle_name() -> String:
	return "dragon's roost"

## Placeholder name and line until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"The Dragon's Roost","epithet":"Something sleeps round the needle","finds":[]}

func top() -> float:
	return TOP

## The air's summit: the needle's tip.
func summit() -> Vector3:
	return Vector3(AXIS.x,shelf_y()+NEEDLE_UP,AXIS.y)

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(TOP)
	site.ray = Vector2(shelf_y()+NEEDLE_UP+10.0,TOP-8.0)
	return site

func flora_seed() -> int:
	return SEED+3

## A mountain, not a run: the plane sets down on the meadow only.
func landing_run() -> bool:
	return false

func warm() -> void:
	super.warm()
	coil()

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	var land := island(SEED)
	art.add_child(land)
	for spec: Array in RUINS:
		var piece: Node3D = RuinKit.piece(spec[0],SEED+int(spec[1]),float(spec[2]))
		piece.name = str(spec[0])
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),ruin_at(spec))
		art.add_child(piece)
	turf(land)
	built_ms = Time.get_ticks_msec()-began

# --- The ground ----------------------------------------------------------------------------

## The crags' noise (broad, every 1/0.045 m) and the rock's grain (fine,
## 1/0.16 m), -1..1: a smooth value noise from hashed lattice points, pure
## arithmetic (no noise resource held in a static, so nothing outlives the
## run, and any thread may call it).
static func crag(x: float, z: float) -> float:
	return _value(x*0.045,z*0.045,SEED)

static func grain(x: float, z: float) -> float:
	return _value(x*0.16,z*0.16,SEED+1)

static func _value(x: float, z: float, seed_value: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x-float(ix)
	var fz := z-float(iz)
	var sx := fx*fx*(3.0-2.0*fx)
	var sz := fz*fz*(3.0-2.0*fz)
	var a := lerpf(_lattice(ix,iz,seed_value),_lattice(ix+1,iz,seed_value),sx)
	var b := lerpf(_lattice(ix,iz+1,seed_value),_lattice(ix+1,iz+1,seed_value),sx)
	return lerpf(a,b,sz)

static func _lattice(ix: int, iz: int, seed_value: int) -> float:
	var h := (ix*374761393+iz*668265263+seed_value*2147483) & 0x7fffffff
	h = ((h ^ (h >> 13))*1274126177) & 0x7fffffff
	return float(h % 20001)/10000.0-1.0

## The shelf's height (own frame).
static func shelf_y() -> float:
	return TOP+SHELF_UP

## The ground's height at (x, z) (own frame): the meadow; the massif's
## stepped crags rising from it to the upper cone, the cone up to the shelf,
## the needle out of the shelf; the highest of them, the coil's groove cut
## in.
static func ground(x: float, z: float) -> float:
	var p := Vector2(x,z)-AXIS
	var d := p.length()
	var a := atan2(p.y,p.x)
	# The meadow: a gentle swell rising toward the mountain's foot.
	var meadow := TOP+0.9*grain(x*0.4,z*0.4)+2.5*(1.0-smoothstep(FOOT_R-6.0,FOOT_R+18.0,d))
	# The shelf and the upper cone: smooth rock but for a little grain.
	var cone_foot := SHELF_R+CONE_DROP*CONE
	var high := -INF
	if d < SHELF_R: high = shelf_y()+0.3*grain(x,z)
	elif d < cone_foot: high = shelf_y()-(d-SHELF_R)/CONE+0.8*crag(x*2.0,z*2.0)
	# The massif under it: buttresses (its reach waves round the axis), a
	# concave fall stepped into crags.
	var ridge := 1.0+0.15*sin(5.0*a+0.7)+0.07*sin(11.0*a+2.1)+0.08*crag(cos(a)*40.0,sin(a)*40.0)
	var foot := FOOT_R*ridge
	var massif := -INF
	if d >= cone_foot and d < foot:
		var from := shelf_y()-CONE_DROP-TOP
		var t := clampf((d-cone_foot)/maxf(foot-cone_foot,1.0),0.0,1.0)
		var fall := from*pow(1.0-t,1.4)+3.2*crag(x,z)*smoothstep(0.0,0.15,t)*(1.0-smoothstep(0.85,1.0,t))
		var stepped := floorf(fall/STEP)*STEP+STEP*smoothstep(0.72,1.0,fposmod(fall,STEP)/STEP)
		massif = TOP+lerpf(fall,stepped,STEPPED*smoothstep(0.02,0.1,t))
	# The needle: fluted, steep.
	var nr := needle_r(a)
	var needle := -INF
	if d < nr:
		var u := 1.0-d/nr
		needle = shelf_y()+NEEDLE_UP*pow(u,0.6)+1.4*grain(x*1.5,z*1.5)*u
	var y := maxf(meadow,maxf(maxf(high,massif),needle))
	return minf(y,_groove(Vector2(x,z),a))

## The needle's reach round the axis at angle `a` (m).
static func needle_r(a: float) -> float:
	return NEEDLE_R*(1.0+0.14*sin(4.0*a+0.4)+0.06*sin(9.0*a+1.9))

# --- The coil ------------------------------------------------------------------------------

## The coil's line (see the head): {z, flat (own x, z), angle, belly (own
## y), girth (m)} arrays, head tip first. Made once (`warm`).
static func coil() -> Dictionary:
	if not _coil.is_empty(): return _coil
	var count := int(round((TAIL_TIP-HEAD_TIP)/COIL_DZ))+1
	var chest_i := int(round((CHEST_Z-HEAD_TIP)/COIL_DZ))
	var zs := PackedFloat32Array()
	var girth := PackedFloat32Array()
	var belly := PackedFloat32Array()
	var ring := PackedFloat32Array()
	for i in range(count):
		var z := HEAD_TIP+COIL_DZ*float(i)
		zs.append(z)
		var g := table(GIRTH,z)*DRAGON_SIZE
		girth.append(g)
		var b := shelf_y()-DESCENT*(z-HEAD_TIP)*DRAGON_SIZE
		belly.append(b)
		ring.append(SHELF_R+(shelf_y()-b)*CONE+g*OUT_SHARE)
	var angle := PackedFloat32Array()
	angle.resize(count)
	angle[chest_i] = deg_to_rad(CHEST_AT)
	for i in range(chest_i-1,-1,-1): angle[i] = angle[i+1]+COIL_DZ*DRAGON_SIZE/ring[i]
	for i in range(chest_i+1,count): angle[i] = angle[i-1]-COIL_DZ*DRAGON_SIZE/ring[i]
	var flat := PackedVector2Array()
	for i in range(count): flat.append(AXIS+Vector2(cos(angle[i]),sin(angle[i]))*ring[i])
	_coil = {"z":zs,"flat":flat,"angle":angle,"belly":belly,"girth":girth}
	return _coil

## A rest-z table's value at `z` (GIRTH's kind), straight between its rows.
static func table(rows: Array, z: float) -> float:
	if z <= float(rows[0][0]): return float(rows[0][1])
	for i in range(1,rows.size()):
		if z <= float(rows[i][0]):
			var a: Array = rows[i-1]
			var b: Array = rows[i]
			return lerpf(float(a[1]),float(b[1]),(z-float(a[0]))/(float(b[0])-float(a[0])))
	return float(rows[rows.size()-1][1])

## The groove's floor at `p` (own x, z; `a` its angle round the axis): the
## lowest of the floors of the coil's points near it (INF away from it).
static func _groove(p: Vector2, a: float) -> float:
	var c := coil()
	var angle: PackedFloat32Array = c.angle
	var n := angle.size()
	# Its nearest points by angle, one a turn of the coil (the angle falls
	# head to tail): each turn's floor, the lowest of them.
	var lo_a := angle[n-1]
	var hi_a := angle[0]
	var flat: PackedVector2Array = c.flat
	var belly: PackedFloat32Array = c.belly
	var girth: PackedFloat32Array = c.girth
	var best := INF
	var at := lo_a+fposmod(a-lo_a,TAU)-TAU
	while at < hi_a+TAU:
		var k := -1
		if at >= lo_a-0.4 and at <= hi_a+0.4:
			if at >= hi_a: k = 0
			elif at <= lo_a: k = n-1
			else:
				var lo := 0
				var hi := n-1
				while hi-lo > 1:
					var mid := (lo+hi)/2
					if angle[mid] > at: lo = mid
					else: hi = mid
				k = lo
		at += TAU
		if k < 0: continue
		for i in range(maxi(k-24,0),mini(k+25,n),2):
			var q := p.distance_to(flat[i])
			var g := girth[i]
			if q > g*GROOVE_FLAT+14.0: continue
			best = minf(best,belly[i]-GROOVE_GAP+GROOVE_RISE*maxf(q-g*GROOVE_FLAT,0.0))
	return best

# --- The land --------------------------------------------------------------------------------

## Its outline (own frame), a wandering ring R round the middle.
static func outline() -> Array:
	return KitLand.blob(O,R,SEED)

## The island: the meadow's turf and the mountain's crags (faces too steep
## for turf drawn as rock) over `ground`, collided, the keel under it; the
## upper cone and its groove on the finer grid.
static func island(seed_value: int) -> Node3D:
	var reach := SHELF_R+CONE_DROP*CONE+6.0
	var spec := {"outline":outline(),"depth":DEPTH,"seed":seed_value,"ground":func(x: float, z: float) -> float: return ground(x,z),
		"top":TOP,"hang":true,"cell":2.0,"fine":1.2,"fine_box":Rect2(AXIS-Vector2.ONE*reach,Vector2.ONE*reach*2.0),
		"resample":[60.0,128,64],"tone":KitLook.turf(seed_value)}
	var node := KitLand.island(spec)
	node.name = "Mountain"
	return node

# --- The ruins on the shelf ------------------------------------------------------------------

## [piece, seed, weathered, angle round the axis on past the coil's head
## tip (deg), out from it (m), turn (deg)]: a chest on the shelf by the
## dragon's snout (its hoard), a fallen pier round the needle from it.
const RUINS := [
	["tomb_chest",2,0.3,24.0,9.4,0.0],
	["fallen_pier",3,0.4,70.0,9.6,20.0],
]

## Where a ruin stands (own frame): on the shelf at its angle and reach.
static func ruin_at(spec: Array) -> Vector3:
	var a := float((coil().angle as PackedFloat32Array)[0])+deg_to_rad(float(spec[3]))
	var p := AXIS+Vector2(cos(a),sin(a))*float(spec[4])
	return Vector3(p.x,ground(p.x,p.y)-0.15,p.y)
