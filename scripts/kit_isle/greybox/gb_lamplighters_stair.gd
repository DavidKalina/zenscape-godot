extends "res://scripts/kit_isle/motif_greybox.gd"
## The Lamplighters' Stair (card: docs/design/roguelike/brainstorm/round3-
## olmec-city/motif-lamplighters-stair.md), a place of the underground Olmec
## city: one broken hillside of turf over the void, rising north in three
## uneven shelves, and the city's processional stair laid on it in three
## runs, a Z, its landings marked by small lamps still burning.
##
##   the foot      (0) the arrival meadow, south. Stair 1 leans off it NE
##                 against the first scarp.
##   lower shelf   (3 courses) stair 2 cuts back NW from it; on the west the
##                 beacon tower (unlit, its shelf level with the upper shelf)
##                 and the votive pier at the void edge; off the west tongue
##                 the wick spire on its rock; on the east the fuse wall (a
##                 basalt revetment: corbel holds, a dead runnel beside them
##                 that runs up it to the great cresset on the drum terrace).
##   upper shelf   (6 courses) the Keeper's beat across stair 3's foot; the
##                 hush gallery in the west; the drum terrace in the east,
##                 its court under the drum shelf (a course up), whose steps
##                 climb to the summit by the rim out.
##   summit        (9 courses) the summit beacon (lit since ever), the rim out.
## The scarps come apart into ragged earth steps on the west (the dark way).
##
## Routes (rim in on the foot's south edge, rim out on the summit's NE edge):
##   processional  stairs 1, 2, 3 (his lane at the top: wait, or light the fuse)
##   dark way      the west steps, the votive pier, the west steps, the hush
##                 gallery, the goat climb, the summit east to the rim
##   drum          the fuse wall's corbels, the drum terrace: his pounce on the
##                 court launches you onto the drum shelf, its steps to the summit
## Everything is one LAYOUT table; the ground is solved from it in `ground`.
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const CityRefuges = preload("res://scripts/city_kit_refuges.gd")
const CityBreaks = preload("res://scripts/city_kit_breaks.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const Underground = preload("res://scripts/underground/underground.gd")
## The Stacked Court: its Keeper's beat (STAND-IN) is reused as is.
const Court = preload("res://scripts/kit_isle/greybox/gb_stacked_court.gd")

const COURSE := CityKit.COURSE
const SO := CityKit.SET_OFF
const SEED := 7700

# --- The layout: one table ----------------------------------------------------------------
## Frame: x east, z south (the arrival is south, +z, looking north, -z).
## Heights in m; the shelves a course-set (3 courses, 14.4 m) apart.
const LAYOUT := {
	# The shelves' levels: the foot, lower, upper, summit.
	"levels":[0.0,3.0*COURSE,6.0*COURSE,9.0*COURSE],
	# The keels fade to this (m) into the haze.
	"floor":-60.0,
	# The main island's outline (x, z), clockwise from the arrival.
	"outline":[Vector2(-44.0,101.0),Vector2(-8.0,99.0),Vector2(22.0,88.0),Vector2(38.0,72.0),Vector2(33.0,58.0),Vector2(46.0,45.0),Vector2(60.0,36.0),Vector2(63.0,20.0),
		Vector2(67.0,-5.0),Vector2(70.0,-30.0),Vector2(68.0,-56.0),Vector2(66.0,-80.0),Vector2(58.0,-101.0),Vector2(38.0,-111.0),
		Vector2(8.0,-113.0),Vector2(-22.0,-109.0),Vector2(-52.0,-104.0),Vector2(-76.0,-95.0),Vector2(-91.0,-78.0),Vector2(-94.0,-54.0),
		Vector2(-90.0,-30.0),Vector2(-93.0,-6.0),Vector2(-92.0,8.0),Vector2(-95.0,14.0),Vector2(-95.0,24.0),Vector2(-89.0,34.0),
		Vector2(-84.0,52.0),Vector2(-72.0,72.0),Vector2(-58.0,90.0)],
	# The scarps between the shelves: z = base + a sin(x f + p) + b sin(x g + q).
	"scarps":[
		{"base":32.0,"a":3.0,"f":0.07,"p":0.0,"b":3.5,"g":0.09,"q":1.0},
		{"base":-16.0,"a":3.0,"f":0.06,"p":2.0,"b":3.5,"g":0.09,"q":0.0},
		{"base":-64.0,"a":3.0,"f":0.05,"p":4.0,"b":3.5,"g":0.09,"q":0.5},
	],
	# Each sheer scarp's foot: a turf talus rising `high` m (wandering) over
	# `long` m to the rock (the rest of the rise sheer: under the 9 m a
	# fall costs a heart), but where something stands against the rock
	# (`clear`: x ranges, per scarp).
	"talus":{"high":5.5,"long":20.0,"clear":[[],[[16.0,54.0],[-63.0,-42.0]],[[-74.0,-36.0],[32.0,80.0]]]},
	# The foot meadow's west shoulder (m up, from x to x) and the summit's
	# rise north (m, starting m north of the scarp, over m).
	"shoulder":[3.2,-32.0,-64.0],
	"summit_rise":[2.4,12.0,40.0],
	# The shelves' turf swells: m up and down, east of x, held flat within
	# `keep` m of what stands (`keep_points`).
	"rumple":{"high":1.3,"west":-38.0,"keep":9.0},
	# Where a scarp comes apart into ragged steps (the dark way): west of
	# `west` (wandering), `steps` a set-off each, `deep` m (wandering) each,
	# on the lower side of the scarp line.
	"steps":[
		{"west":-42.0,"steps":9,"deep":2.7},
		{"west":-64.0,"steps":9,"deep":2.5},
		{"west":-72.0,"steps":9,"deep":2.4},
	],
	# The fuse wall: a basalt revetment on the second scarp, straight at
	# `z` from x0 to x1 (the scarp kept straight a little past), its face
	# south; `corbels` holds, the first at x `first` a set-off over the
	# lower shelf, each `side` m on (west) and a set-off up.
	"fuse_wall":{"x0":20.0,"x1":48.0,"z":-14.0,"thick":2.6,"corbels":8,"first":39.0,"side":1.4,"deep":1.4,"thick_c":1.0,
		"port":Vector2(41.6,0.9),"speed":3.0},
	# The drum terrace: the court's middle (x, z) on the upper shelf, sunk
	# into the turf; the drum shelf a course over it, north of the court,
	# its steps up to the summit; the great cresset at the court's corner.
	"drum":{"at":Vector2(44.0,-33.0),"shelf":Rect2(34.0,-64.0,32.0,21.0),"steps_x":52.0,"steps_from":-50.0,"cresset":Vector2(28.5,-25.5)},
	# The stairs: foot (x, z) on a shelf (level index), heading (deg: 0
	# north, + toward east), the fault landing (0 none).
	"stairs":[
		{"foot":Vector2(-24.0,66.0),"on":0,"heading":45.0,"fault":0},
		{"foot":Vector2(0.0,16.0),"on":1,"heading":-45.0,"fault":1},
		{"foot":Vector2(-30.0,-32.0),"on":2,"heading":45.0,"fault":0},
	],
	# The beacon tower on the lower shelf's west, its back a seam off the
	# second scarp (its shelf level with the upper shelf: a hop across).
	"tower":{"at":Vector2(-52.0,-12.0),"base":8.0,"lit":false},
	# The summit beacon: lit since ever (draws no one).
	"summit_tower":{"at":Vector2(18.0,-92.0),"lit":true},
	# The refuges: the votive pier (its shelves to the east) and the hush
	# gallery (its slit south), [x, z, turn deg].
	"niches":[-76.0,20.0,90.0],
	"hush":[-55.0,-53.0,0.0],
	# The wick spire on its rock off the lower shelf's west tongue.
	"spire":{"at":Vector2(-102.0,19.0),"rock":6.5,"drop":0.8,"tall":16.0},
	# Unlit cressets [x, z, level, size]: by stair 2's foot (a lure down onto
	# its fault), by the hush gallery (a lure west).
	"cressets":[[10.0,23.0,1,"cresset"],[-40.0,-56.0,2,"cresset"]],
	# The Keeper's beat on the upper shelf (x, z), his first look.
	"keeper":{"beat":[Vector2(-14.0,-34.0),Vector2(4.0,-37.0),Vector2(20.0,-33.0)],"face":Vector2(-0.6,0.8),"knobs":{"drop_max":3.0}},
	# Far off west: a small lit isle where a headless body roams.
	"far":{"at":Vector3(-170.0,22.0,-92.0),"radius":22.0},
	# The arrival (start) and the rims.
	"start":Vector2(-30.0,90.0),
	"rim_in":Vector2(-30.0,97.0),
	"rim_out":Vector2(42.0,-104.0),
}

static func level(i: int) -> float:
	return float(LAYOUT.levels[i])

## A scarp's line (z) at x; the fuse wall's stretch held straight.
static func scarp_z(k: int, x: float) -> float:
	var s: Dictionary = LAYOUT.scarps[k]
	var fw: Dictionary = LAYOUT.fuse_wall
	if k == 1 and x > float(fw.x0)-4.0 and x < float(fw.x1)+14.0: return float(fw.z)
	if k == 2 and x > float(LAYOUT.drum.shelf.position.x)-2.0: return float(LAYOUT.drum.shelf.position.y)
	return float(s.base)+float(s.a)*sin(x*float(s.f)+float(s.p))+float(s.b)*sin(x*float(s.g)+float(s.q))

## The stairs' frames: foot (world, on its shelf), basis (local -z up the run).
static func stair_xform(i: int) -> Transform3D:
	var s: Dictionary = LAYOUT.stairs[i]
	var f: Vector2 = s.foot
	return Transform3D(Basis(Vector3.UP,-deg_to_rad(float(s.heading))),Vector3(f.x,level(int(s.on)),f.y))

static func stair_length() -> float:
	return CityKit.STAIR_FLIGHTS*CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.STAIR_FLIGHTS*CityKit.LANDING

## The tread's height over a stair's foot `v` m up its run (flights and landings).
static func stair_profile(v: float) -> float:
	var run := CityKit.STAIR_STEPS*CityKit.TREAD
	var y := 0.0
	var at := 0.0
	for f in CityKit.STAIR_FLIGHTS:
		if v < at+run: return y+maxf(v-at,0.0)/run*COURSE
		at += run
		y += COURSE
		if v < at+CityKit.LANDING: return y
		at += CityKit.LANDING
	return y

## A stair's landing lamps (local): the kit's own cresset mounts on its
## landings (CityKit `stair`: beside the lane's right cheek), the sides
## alternating a stair to a stair so the Z reads from either side.
static func landing_mounts(i: int) -> Array:
	var run := CityKit.STAIR_STEPS*CityKit.TREAD
	var hw := CityKit.LANE*0.5
	var side := 1.0 if i % 2 == 0 else -1.0
	var out: Array = []
	for f in range(1,CityKit.STAIR_FLIGHTS+1):
		var lz := -(f*run+(f-1)*CityKit.LANDING)-CityKit.LANDING*0.5
		out.append(Vector3(side*(hw-0.6),f*COURSE,lz+CityKit.LANDING*0.5-0.8))
	return out

## The ground (x, z): the shelves, the ragged steps, the drum terrace, cut
## down under and beside the stairs.
static func ground(x: float, z: float) -> float:
	var y := shelves(x,z)
	# The drum terrace: the court's pit, the shelf and its steps.
	var d: Dictionary = LAYOUT.drum
	var c: Vector2 = d.at
	var half := 2.5*CityBreaks.SLAB
	# (Under the slabs' outer ring the turf stops just under their bottoms,
	# so its edge never sags into a hole past the court's rim.)
	var off := maxf(absf(x-c.x),absf(z-c.y))
	if off <= half-1.5: y = level(2)-2.3
	elif off <= half: y = level(2)-CityBreaks.SLAB_THICK-0.1
	var sh: Rect2 = d.shelf
	if sh.has_point(Vector2(x,z)):
		y = level(2)+COURSE
		if x > float(d.steps_x):
			var n := clampi(int(ceil((float(d.steps_from)-z)/2.3)),0,6)
			y += n*SO
	# The stairs: under the cheeks a hair under the treads, beside them no
	# higher than a little under the crest.
	for i in LAYOUT.stairs.size():
		var xf := stair_xform(i)
		var l := xf.affine_inverse()*Vector3(x,0.0,z)
		var v := -l.z
		if v < 0.0 or v > stair_length()+0.5: continue
		var u := absf(l.x)
		var wall := CityKit.LANE*0.5+CityKit.CHEEK
		var p := xf.origin.y+stair_profile(clampf(v,0.0,stair_length()))
		if u < wall+0.4: y = minf(y,p-0.6)
		elif u < wall+3.0: y = minf(y,maxf(p+0.9,xf.origin.y))
	return y

## The shelves alone: each scarp sheer, or west of its `west` ragged steps.
static func shelves(x: float, z: float) -> float:
	return _shelves(x,z)+rumple(x,z)

## The shelves' turf swells (m), east of the ragged steps and held flat
## round everything that stands or meets (`keep`).
static func rumple(x: float, z: float) -> float:
	var r: Dictionary = LAYOUT.rumple
	var m := smoothstep(float(r.west),float(r.west)+10.0,x)
	if m <= 0.0: return 0.0
	for p: Vector2 in keep_points():
		m = minf(m,smoothstep(float(r.keep),float(r.keep)+12.0,p.distance_to(Vector2(x,z))))
		if m <= 0.0: return 0.0
	var n := sin(x*0.045+z*0.031+1.0)*sin(z*0.052-x*0.02)+0.5*sin(x*0.11+2.0)*sin(z*0.093)
	return float(r.high)*n*m

static var _keep: Array = []
static func keep_points() -> Array:
	if not _keep.is_empty(): return _keep
	var out: Array = []
	for i in LAYOUT.stairs.size():
		var xf := stair_xform(i)
		for v: float in [-6.0,stair_length()+4.0]:
			var p := xf*Vector3(0.0,0.0,-v)
			out.append(Vector2(p.x,p.z))
	out.append_array([LAYOUT.tower.at,LAYOUT.drum.at,LAYOUT.drum.cresset,LAYOUT.summit_tower.at,LAYOUT.start,LAYOUT.rim_in,LAYOUT.rim_out,
		Vector2(20.0,-6.0),Vector2(34.0,-6.0),Vector2(48.0,-6.0),Vector2(LAYOUT.hush[0],LAYOUT.hush[1])])
	for c: Array in LAYOUT.cressets: out.append(Vector2(float(c[0]),float(c[1])))
	_keep = out
	return out

static func _shelves(x: float, z: float) -> float:
	var sh: Array = LAYOUT.shoulder
	var y := level(0)+float(sh[0])*smoothstep(float(sh[1]),float(sh[2]),x)
	for k in 3:
		var sz := scarp_z(k,x)
		var st: Dictionary = LAYOUT.steps[k]
		var west := float(st.west)+3.0*sin(z*0.21+k)
		if x < west:
			var n := int(st.steps)
			var deep := float(st.deep)+0.6*sin(x*0.23+k*1.3)
			var ze := z+0.8*sin(x*0.41+k*2.0)
			var up := clampi(int(ceil((sz+n*deep-ze)/deep)),0,n)
			if ze <= sz: up = n
			y = maxf(y,level(k)+up*(level(k+1)-level(k))/n)
			if up < n: return y
		elif z <= sz:
			y = level(k+1)
		else:
			return maxf(y,talus(k,x,z-sz))
	var sr: Array = LAYOUT.summit_rise
	return y+float(sr[0])*clampf((scarp_z(2,x)-float(sr[1])-z)/float(sr[2]),0.0,1.0)

## The turf talus at scarp `k`'s foot, `out` m south of its rock.
static func talus(k: int, x: float, out: float) -> float:
	var t: Dictionary = LAYOUT.talus
	for r: Array in t.clear[k]:
		if x > float(r[0]) and x < float(r[1]): return level(k)
	var high := float(t.high)+2.4*sin(x*0.09+k*1.7)+0.8*sin(x*0.31+k)
	var long := float(t.long)+4.0*sin(x*0.13+k)
	if out >= long: return level(k)
	return level(k)+maxf(high,0.6)*pow(1.0-out/long,1.4)

## A point on the ground (x, z).
static func on(p: Vector2, up := 0.0) -> Vector3:
	return Vector3(p.x,ground(p.x,p.y)+up,p.y)

## A point on a shelf (level index) at (x, z), the level's own height.
static func at_level(p: Vector2, lv: int, up := 0.0) -> Vector3:
	return Vector3(p.x,level(lv)+up,p.y)

## The fuse wall's corbel `i`: its top's middle (world).
static func corbel(i: int) -> Vector3:
	var fw: Dictionary = LAYOUT.fuse_wall
	return Vector3(float(fw.first)-i*float(fw.side),level(1)+SO*(i+1),float(fw.z)+float(fw.deep)*0.5)

## The runnel's line up the fuse wall's face, over its lip, along the
## upper shelf to the great cresset's plinth (points, normals; world).
static func runnel_line() -> Array:
	var fw: Dictionary = LAYOUT.fuse_wall
	var z := float(fw.z)+0.03
	var port: Vector2 = fw.port
	var p0 := Vector3(port.x,level(1)+port.y,z)
	var slope := SO/float(fw.side)
	var up := level(2)-0.15-p0.y
	var p1 := Vector3(p0.x-up/slope,level(2)-0.15,z)
	var cr: Vector2 = LAYOUT.drum.cresset
	var lip := Vector3(p1.x,level(2)+0.03,float(fw.z)-0.5)
	var bend := Vector3(p1.x-1.5,level(2)+0.03,float(fw.z)-4.0)
	var end := Vector3(cr.x+2.2,level(2)+0.03,cr.y+3.4)
	var pts: Array = [p0,p1,lip,bend,end]
	var nrm: Array = [Vector3.BACK,Vector3.BACK,Vector3.UP,Vector3.UP,Vector3.UP]
	return [pts,nrm]

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "lamplighters_stair"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Lamplighters' Stair"

func epithet() -> String:
	return "They lit it every night for a climber who never came. Light it now and see who comes instead."

func brief() -> String:
	return "Up: the lit stair's three runs; or the dark west steps; or the fuse wall's corbels to the drum terrace.\nThe Keeper walks the upper landing. Every fire you light calls him to it."

func start() -> Vector3:
	return on(LAYOUT.start)

func rims() -> Array:
	var ro: Vector2 = LAYOUT.rim_out
	return [
		{"name":"foot","at":on(LAYOUT.rim_in),"face":Vector3(0.0,0.0,1.0),"run_up":14.0,"lip":1.5},
		{"name":"summit","at":on(ro),"face":Vector3(0.1,0.0,-1.0),"run_up":12.0,"lip":1.5},
	]

func spots() -> Array:
	var d: Dictionary = LAYOUT.drum
	var sh: Rect2 = d.shelf
	var sp: Dictionary = LAYOUT.spire
	var out: Array = [
		{"kind":"arena","name":"foot_meadow","at":on(Vector2(10.0,72.0)),"room":14.0},
		{"kind":"arena","name":"drum_terrace","at":at_level(d.at,2),"room":9.0},
		{"kind":"arena","name":"upper_landing","at":at_level(Vector2(-14.0,-40.0),2),"room":8.0},
		{"kind":"cover","name":"hush_gallery","at":at_level(Vector2(float(LAYOUT.hush[0]),float(LAYOUT.hush[1])),2),"room":4.0},
		{"kind":"cover","name":"under_the_fuse_wall","at":at_level(Vector2(34.0,-10.0),1),"room":3.0},
		{"kind":"perch","name":"summit_beacon","at":on(LAYOUT.summit_tower.at,14.4),"room":1.5},
		{"kind":"perch","name":"spire_cup","at":Vector3(sp.at.x,level(1)-float(sp.drop)+float(sp.tall)+0.5,sp.at.y),"room":1.2},
	]
	# Runes along the routes: each stair's landings, the dark way's steps,
	# the fuse wall's corbels.
	for i in LAYOUT.stairs.size():
		var xf := stair_xform(i)
		for v: float in [6.0,14.0,24.0,33.0,43.0,51.0]:
			out.append({"kind":"rune_line","name":"stair%d_%d" % [i+1,int(v)],"at":xf*Vector3(0.0,stair_profile(v)+0.6,-v),"room":1.0})
	for p: Vector2 in [Vector2(-60.0,48.0),Vector2(-66.0,38.0),Vector2(-80.0,4.0),Vector2(-78.0,-8.0),Vector2(-84.0,-46.0),Vector2(-82.0,-58.0),Vector2(-60.0,-84.0),Vector2(-20.0,-90.0)]:
		out.append({"kind":"rune_line","name":"dark_%d_%d" % [int(p.x),int(p.y)],"at":on(p,0.6),"room":1.0})
	# Tempting and exposed: the stair cheeks' crests over the drops, the
	# fuse wall's top corbels, the lower shelf's west tongue at the void, the
	# drum court (his landing ground).
	var s1 := stair_xform(0)
	var hw := CityKit.LANE*0.5+CityKit.CHEEK*0.5
	out.append({"kind":"rune_risk","name":"stair1_crest","at":s1*Vector3(-hw,stair_profile(40.0)+CityKit.CREST+0.5,-40.0),"room":1.0})
	out.append({"kind":"rune_risk","name":"stair2_crest","at":stair_xform(1)*Vector3(hw,stair_profile(30.0)+CityKit.CREST+0.5,-30.0),"room":1.0})
	for i: int in [5,7]: out.append({"kind":"rune_risk","name":"corbel_%d" % i,"at":corbel(i)+Vector3.UP*0.6,"room":0.8})
	out.append({"kind":"rune_risk","name":"west_tongue","at":on(Vector2(-91.0,19.0),0.6),"room":1.0})
	out.append({"kind":"rune_risk","name":"drum_court","at":at_level(d.at+Vector2(4.0,-6.0),2,0.6),"room":1.5})
	# The rares: the votive alcove (up the lit shelves), the drum shelf (only
	# by his landing's launch), the spire's cup (over the void), the fault's
	# chamber (open once he breaks it).
	var ni: Array = LAYOUT.niches
	out.append({"kind":"rare","name":"votive_alcove","at":Vector3(float(ni[0])+3.4,level(1)+12.9,float(ni[1])),"room":0.8})
	out.append({"kind":"rare","name":"drum_shelf","at":at_level(Vector2(sh.position.x+5.0,sh.end.y-3.0),2,COURSE+0.6),"room":1.0})
	out.append({"kind":"rare","name":"spire_cup","at":Vector3(sp.at.x+1.2,level(1)-float(sp.drop)+float(sp.tall)+1.0,sp.at.y),"room":0.6})
	var s2 := stair_xform(1)
	var lz := CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.LANDING*0.5
	out.append({"kind":"rare","name":"fault_chamber","at":s2*Vector3(0.0,0.6,-lz),"room":1.0})
	return out

## The solids for the occupancy, the footprint and the bodies' cliffs: the
## island's ground in 4 m strips (each its lowest, from the keel), the
## stairs as ramps, the spire's rock, the far isle.
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	var poly := PackedVector2Array(LAYOUT.outline)
	var box := Rect2(poly[0],Vector2.ZERO)
	for p in poly: box = box.expand(p)
	var cell := 4.0
	var z := box.position.y
	while z < box.end.y:
		var x := box.position.x
		var run_x := NAN
		var run_y := NAN
		while x <= box.end.x:
			var inside := Geometry2D.is_point_in_polygon(Vector2(x+cell*0.5,z+cell*0.5),poly)
			var h := NAN
			if inside:
				h = INF
				for q: Vector2 in [Vector2(0.3,0.3),Vector2(cell-0.3,0.3),Vector2(0.3,cell-0.3),Vector2(cell-0.3,cell-0.3),Vector2(cell*0.5,cell*0.5)]:
					h = minf(h,shelves(x+q.x,z+q.y))
				h = snappedf(h,0.1)
			if not is_nan(run_x) and (is_nan(h) or h != run_y):
				out.append(["box",Rect2(run_x,z,x-run_x,cell),floor_y,run_y,"grey"])
				run_x = NAN
			if not is_nan(h) and is_nan(run_x):
				run_x = x
				run_y = h
			x += cell
		if not is_nan(run_x): out.append(["box",Rect2(run_x,z,x-run_x,cell),floor_y,run_y,"grey"])
		z += cell
	for i in LAYOUT.stairs.size():
		var xf := stair_xform(i)
		out.append(["ramp",xf*Vector3(0.0,0.0,CityKit.HEAD_LENGTH),xf*Vector3(0.0,COURSE*CityKit.STAIR_FLIGHTS,-stair_length()),CityKit.LANE+2.0*CityKit.CHEEK,"grey"])
	var sp: Dictionary = LAYOUT.spire
	var r := float(sp.rock)
	out.append(["box",Rect2(sp.at.x-r*0.7,sp.at.y-r*0.7,r*1.4,r*1.4),floor_y*0.5,level(1)-float(sp.drop),"grey"])
	var far: Dictionary = LAYOUT.far
	var fr := float(far.radius)*0.7
	out.append(["box",Rect2(far.at.x-fr,far.at.z-fr,fr*2.0,fr*2.0),far.at.y-30.0,far.at.y,"grey"])
	return out

# --- The land and the stone ------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return SEED+9

## The worn ways: the arrival to stair 1's foot; along the lower shelf from
## stair 1's summit to stair 2's foot and the fuse wall; the upper landing.
static func paths() -> Array:
	var s: Vector2 = LAYOUT.start
	var out: Array = []
	var f1 := stair_xform(0)*Vector3(0.0,0.0,CityKit.HEAD_LENGTH+3.0)
	out.append([s,Vector2(-26.0,78.0),Vector2(f1.x,f1.z)])
	var t1 := stair_xform(0)*Vector3(0.0,0.0,-stair_length())
	var f2 := stair_xform(1)*Vector3(0.0,0.0,CityKit.HEAD_LENGTH+3.0)
	out.append([Vector2(t1.x,t1.z),Vector2(f2.x,f2.z)])
	out.append([Vector2(t1.x,t1.z),Vector2(36.0,8.0),Vector2(41.0,-10.0)])
	var t2 := stair_xform(1)*Vector3(0.0,0.0,-stair_length())
	var f3 := stair_xform(2)*Vector3(0.0,0.0,CityKit.HEAD_LENGTH+3.0)
	out.append([Vector2(t2.x,t2.z),Vector2(f3.x,f3.z),Vector2(14.0,-30.0),Vector2(28.0,-30.0)])
	var t3 := stair_xform(2)*Vector3(0.0,0.0,-stair_length())
	out.append([Vector2(t3.x,t3.z),Vector2(30.0,-92.0),LAYOUT.rim_out as Vector2])
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
	keep_points()
	_computed()

func build_cost() -> int:
	return 900

var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "LamplightersStair"
	into.add_child(root)
	pieces.clear()
	# The hillside.
	var poly: Array = LAYOUT.outline
	var box := Rect2(poly[0],Vector2.ZERO)
	for p: Vector2 in poly: box = box.expand(p)
	var land := KitLand.island({"outline":poly,"seed":SEED+1,"ground":func(x: float, z: float) -> float: return ground(x,z),
		"top":level(0),"depth":-float(LAYOUT.floor),"hang":true,"resample":[200.0,260,64],"cell":2.0,
		"cliffs":box.grow(2.0),"fine":1.2,"fine_box":Rect2(-96.0,-100.0,40.0,160.0),
		"tone":KitLook.turf(SEED+1,KitLand.wear_of(paths()))})
	land.name = "Hillside"
	root.add_child(land)
	turf(land)
	pieces.hillside = land
	# The spire's rock, a little under the lower shelf.
	var sp: Dictionary = LAYOUT.spire
	var rock_y := level(1)-float(sp.drop)
	var rock := KitLand.island({"outline":_blob(sp.at,float(sp.rock),SEED+3),"seed":SEED+3,"ground":func(_x: float, _z: float) -> float: return rock_y,
		"top":rock_y,"depth":28.0,"hang":true,"resample":[30.0,40,24],"tone":KitLook.turf(SEED+3)})
	rock.name = "SpireRock"
	root.add_child(rock)
	turf(rock)
	# The far isle.
	var far: Dictionary = LAYOUT.far
	var fy := float(far.at.y)
	var fi := KitLand.island({"outline":_blob(Vector2(far.at.x,far.at.z),float(far.radius),SEED+4),"seed":SEED+4,"ground":func(_x: float, _z: float) -> float: return fy,
		"top":fy,"depth":34.0,"hang":true,"resample":[60.0,60,32],"tone":KitLook.turf(SEED+4)})
	fi.name = "FarIsle"
	root.add_child(fi)
	turf(fi)
	# The stairs (no flank: the hill is their flank).
	for i in LAYOUT.stairs.size():
		var s: Dictionary = LAYOUT.stairs[i]
		var st := CityKit.stair(SEED+10+i,0.55+0.1*i,{"flank":0.0,"fault":int(s.fault)})
		st.name = "Stair%d" % (i+1)
		st.transform = stair_xform(i)
		root.add_child(st)
		pieces["stair%d" % (i+1)] = st
	_fuse_wall(root)
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## A ragged round outline (x, z) of radius `r` round `c`.
static func _blob(c: Vector2, r: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for i in 14:
		var a := TAU*i/14.0
		out.append(c+Vector2(cos(a),sin(a))*r*rng.randf_range(0.82,1.08))
	return out

## The fuse wall: a revetment faced in the makers' basalt on the second
## scarp, its corbels (a set-off apart up, a stride apart west).
func _fuse_wall(root: Node3D) -> void:
	var fw: Dictionary = LAYOUT.fuse_wall
	var g: RefCounted = GiantStone.mesher()
	var solids := StaticBody3D.new()
	solids.name = "FuseWallSolid"
	var x0 := float(fw.x0)
	var x1 := float(fw.x1)
	var z := float(fw.z)
	var th := float(fw.thick)
	var lo := level(1)-1.0
	var hi := level(2)
	# The facing, in courses (set-offs tall), each a little set back.
	var rows := int(ceil((hi-lo)/SO))
	for r in rows:
		var y0 := lo+r*SO
		var y1 := minf(y0+SO,hi)
		var back := 0.04*r
		var x := x0
		var k := 0
		while x < x1-0.01:
			var w := minf(2.6+1.4*absf(sin(r*1.7+k*2.3)),x1-x)
			var size := Vector3(w-0.04,y1-y0-0.03,th)
			g.box(Transform3D(Basis.IDENTITY,Vector3(x+w*0.5,(y0+y1)*0.5,z-th*0.5-back)),size,0.12,lo)
			x += w
			k += 1
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1-x0,hi-lo,th)
	c.shape = shape
	c.position = Vector3((x0+x1)*0.5,(lo+hi)*0.5,z-th*0.5)
	solids.add_child(c)
	# The corbels.
	var deep := float(fw.deep)
	var side := float(fw.side)
	var thick := float(fw.thick_c)
	for i in int(fw.corbels):
		var t := corbel(i)
		var size := Vector3(side-0.06,thick,deep)
		var xf := Transform3D(Basis.IDENTITY,Vector3(t.x,t.y-thick*0.5,z+deep*0.5))
		g.box(xf,size,0.1,lo,0.92)
		var cc := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = Vector3(side,thick,deep)
		cc.shape = cs
		cc.transform = xf
		solids.add_child(cc)
	var mesh := MeshInstance3D.new()
	mesh.name = "FuseWall"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)
	pieces.fuse_wall = mesh

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces.values(): n += int(p.get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The fires (the landing lamps lit since ever, the dead cressets, the
## towers, the spire, the fuse), the refuges, the drum court, the
## breakables hub, the Keeper and his beat, the far isle's roamer.
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var k := 0
	# The landing lamps: the kit's own mounts on each stair (lit since ever).
	for i in LAYOUT.stairs.size():
		var xf := stair_xform(i)
		for m: Vector3 in landing_mounts(i):
			CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(xf*m)),{"size":"crown","seed":SEED+40+k,"name":"Lamp%d" % k,"lit":true,"draw":1.0,"barge":false})
			k += 1
	# The lower shelf's beacon tower (unlit; its back to the second scarp).
	var tw: Dictionary = LAYOUT.tower
	var base := float(tw.base)*CityFires.size()
	var tat: Vector2 = tw.at
	var tz := scarp_z(1,tat.x)+1.0+base*0.5
	CityFires.tower(fires,Transform3D(Basis.IDENTITY,g.w(Vector3(tat.x,level(1),tz))),{"seed":SEED+20,"name":"LowerTower","lit":bool(tw.lit),"base":float(tw.base)})
	# The summit beacon (lit since ever).
	var su: Dictionary = LAYOUT.summit_tower
	var summit: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.5),g.w(on(su.at))),{"seed":SEED+21,"name":"SummitTower","lit":bool(su.lit),"beam":2.0})
	Court._still(summit)
	# The dead cressets.
	for c: Array in LAYOUT.cressets:
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at_level(Vector2(float(c[0]),float(c[1])),int(c[2])))),{"size":c[3],"seed":SEED+30+k,"name":"Cresset%d" % k,"lit":false})
		k += 1
	# The great cresset on the drum terrace, and the fuse that lights it.
	var dr: Dictionary = LAYOUT.drum
	var great: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at_level(dr.cresset,2))),{"size":"great","seed":SEED+33,"name":"GreatCresset","lit":false})
	var line := runnel_line()
	var pts: Array = []
	for p: Vector3 in line[0]: pts.append(g.w(p))
	CityFires.runnel(fires,Transform3D.IDENTITY,pts,line[1],{"name":"Fuse","tail":great,"speed":float(LAYOUT.fuse_wall.speed)})
	# The wick spire on its rock.
	var sp: Dictionary = LAYOUT.spire
	CityFires.spire(fires,Transform3D(Basis.IDENTITY,g.w(Vector3(sp.at.x,level(1)-float(sp.drop),sp.at.y))),{"tall":float(sp.tall),"seed":SEED+34,"name":"WickSpire"})
	# The far isle's tower (lit since ever).
	var far: Dictionary = LAYOUT.far
	var ft: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,1.1),g.w(far.at+Vector3(6.0,0.0,-5.0))),{"seed":SEED+35,"name":"FarTower","lit":true,"tiers":2,"beam":3.0})
	Court._still(ft)
	# The refuges.
	var ni: Array = LAYOUT.niches
	var pier := CityRefuges.piece("city_niches",SEED+50)
	pier.name = "VotivePier"
	pier.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(ni[2]))),g.w(at_level(Vector2(float(ni[0]),float(ni[1])),1)))
	g.add_child(pier)
	var hu: Array = LAYOUT.hush
	var hall := CityRefuges.piece("city_hush",SEED+51)
	hall.name = "HushGallery"
	hall.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(hu[2]))),g.w(at_level(Vector2(float(hu[0]),float(hu[1])),2)))
	g.add_child(hall)
	# The drum court, its slabs' tops level with the upper shelf.
	var court := CityBreaks.piece("colossus_drum",SEED+52)
	court.name = "DrumCourt"
	court.position = g.w(at_level(dr.at,2))
	g.add_child(court)
	# The hub: every Olmec's breaker (the fault, the cressets, the court).
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	# The Keeper: a whole Olmec on the upper landing, chase on.
	var kd: Dictionary = LAYOUT.keeper
	var beat: Array[Vector3] = []
	for p: Vector2 in kd.beat: beat.append(g.w(at_level(p,2)))
	var post: Vector3 = beat[1]
	var bk := {"chase":1,"chase_routes":1,"seed":SEED}
	bk.merge(kd.get("knobs",{}),true)
	var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,kd.face,bk)
	var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,kd.face,{})
	var keeper: Node = Keeper.new()
	keeper.name = "Keeper_STANDIN"
	keeper.beat = beat
	keeper.post = post
	keeper.field = g.stage.enemies
	keeper.hub = hub
	keeper.wear(body,head)
	g.add_child(keeper)
	# Far off: a headless body roaming the far isle.
	g.enemy(HeadlessBody,g.w(far.at+Vector3(-4.0,0.1,6.0)),Vector2(1.0,0.0),{"seed":SEED+1})
	if Underground.on():
		var dresser := Dresser.new()
		dresser.name = "Dresser"
		dresser.motif = self
		g.add_child(dresser)

## STAND-IN: the Keeper's rounds (the Stacked Court's Keeper, its refind
## made safe for a reset's freed bodies): while he listens or roams and
## isn't hunting, turns him toward the next point of his beat, back and
## forth; holds him at his post till the ground under him stands; puts his
## head back after a reset; hands every Olmec the breakables hub.
class Keeper extends "res://scripts/kit_isle/greybox/gb_stacked_court.gd".Keeper:
	## Times a lit fire had him (the beat let go of him meanwhile).
	var heeding := 0

	func _physics_process(delta: float) -> void:
		# A fire calls him: the beat lets him go to it (else it would turn
		# him back to his rounds every frame).
		if body != null and is_instance_valid(body) and body.get("beacon") != null and landed:
			heeding += 1
			if field != null:
				for e in field.enemies:
					if is_instance_valid(e) and e.has_method("world_changed") and e.get("breaker") == null: e.breaker = hub
			return
		super._physics_process(delta)

	func _refind() -> void:
		if field == null: return
		body = null
		head = null
		for e in field.enemies:
			if not is_instance_valid(e): continue
			var n := e as Node3D
			if n.has_method("make_whole") and n.position.distance_to(post) < 6.0: body = n
			elif n.has_method("mouth") and n.position.distance_to(post) < 12.0: head = n
		if body != null and head != null:
			body.make_whole(head)
			landed = false
			leg = 1
			dir = 1

## The abyss's ground cover on the stairs' landings and summits once they stand.
class Dresser extends Node:
	const ON := ["landing","summit"]
	var motif: RefCounted
	var laid := 0

	func _physics_process(_delta: float) -> void:
		var pieces: Dictionary = motif.get("pieces")
		if pieces.is_empty(): return
		for key: String in pieces:
			var p: Node3D = pieces[key]
			if not is_instance_valid(p) or not p.is_inside_tree(): return
		var kind := GroundCover.asked()
		if kind != "":
			var k := 0
			for key: String in pieces:
				if not key.begins_with("stair"): continue
				var p: Node3D = pieces[key]
				for a: Dictionary in p.get_meta("walk_areas",[]):
					if not String(a.kind) in ON: continue
					if GroundCover.cover(p,a.poly,kind,float(a.y),SEED+k,{}) != null: laid += 1
					k += 1
		set_physics_process(false)
