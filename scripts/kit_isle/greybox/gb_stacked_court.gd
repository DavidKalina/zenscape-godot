extends "res://scripts/kit_isle/motif_greybox.gd"
## The Stacked Court, a place of the underground Olmec city built
## from the city kit (scripts/city_kit.gd, its fires): basalt pillar-isles
## stacked a course-set apart, each layer further back and higher, round a
## court of air. You arrive on the lowest and look up at the lit crowns.
##
##   F  the forecourt (ground 0): the arrival, land not stone (polish
##      round 1): one KitLand island on its own keel, flat round the
##      arrival and the stair's foot, swelling to the east, its north-east
##      edge broken a step down; west of the stair a hill rises toward M in
##      broad tilted meadows broken by two scarps, run on as the west bank
##      into the corner between M and U and banked against M's flank, a
##      sunken way cut through it to the drum's door. The serpent stair
##      climbs north from it to M (the hill its west flank); beside the
##      stair a beacon tower stands with its back to M's face.
##   M  the well (crown 3 courses up): the drum stair wound down its well, a
##      great cresset unlit on its core floor; a door through its south-west
##      flank (STAND-IN, stacked_court_door.gd) into the drum's second turn,
##      so the drum is a way up. The stair lands on its south ring; the
##      hill's growth has gone on over its south-west crown (a turf mantle
##      hanging over the door); the Keeper walks its north ring.
##   U, T  the west and east pillars (crowns 6 courses up), set flush (a
##      seam) to M's north-west and north-east faces, collared three courses
##      down to M's crown, their prism chains facing M. The causeway runs
##      from U's crown to T's behind the well, its two middle piers standing
##      on M's north ring, its breakable bay over the Keeper's beat. T bears
##      the summit's beacon tower (9 courses up) and the way out.
##   the needle  a lone pillar far behind, higher than all, its tower lit:
##      the layer above.
## Alone (the motif yard) a few far pillars with lit crowns stand off in the
## haze, the layers in the distance; in a layer the other isles are those.
##
## Routes (rim in on F's south edge, rim out on T's far edge):
##   the court   the serpent stair, west round M's ring past the well, U's
##               collar chain, U's crown, the causeway east, T's crown.
##   the tower   F's beacon tower (its giant steps), across the seam onto
##               M's ring, east round it, T's collar chain to its crown.
##   the well    the sunken way up the hill to the door, the tunnel (walker
##               high: he can't follow), up the drum's coil out of the dark
##               onto M's south rim, then either pillar's chain. Slower and
##               sheltered, through the Keeper's home.
##
## Threat: the Keeper (a whole Olmec, chase on) walks M's north ring (a
## STAND-IN beat), under the causeway's bay; an inhaler head holds T's crown
## at the causeway's end, its headless body coming up the cliffs; the
## breakables hub is every Olmec's breaker (the bay, the stair's fault, the
## cressets). The cressets are dressing: some burn, some stand cold.
##
## Everything is one LAYOUT table; where the pillars stand is solved from it
## in `place_of`.
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Door = preload("res://scripts/kit_isle/greybox/stacked_court_door.gd")

const COURSE := CityKit.COURSE
const SEED := 7300

# --- The layout: one table ----------------------------------------------------------------
## Heights in courses (COURSE, 4.8 m: a collar, a flight, a drum turn).
## Apothems in m (centre to a flat face). `seam`: the gap left between two
## pillars set face to face (m: a step across, never stone in stone).
## The frame: M's centre at x z 0, F to the south (+z), the arrival on F
## looking north (-z). Offsets (x, z) are from their pillar's centre.
const LAYOUT := {
	"seam":0.5,
	# The shafts all fade to this depth (m) into the haze.
	"floor":-70.0,
	# Each turfed crown's cap: a KitLand turf island on the bare crown, its
	# ragged edge grown out past the stone up to `grow` m (hanging earth and
	# roots) but for the `keep` faces, tucked inside the lip (a seam to a
	# neighbour, or a climb face whose lip is grabbed).
	"forecourt":{"apothem":40.0,"crown":0,"wear":0.6,"cap":{"grow":4.0,"keep":[3,0,1,5],"tuck":0.0,"seed":SEED+1,"faces":{2:10.0}},
		# Its turf's west terraces, each a set-off up (grabbable cliffs), their
		# edges (local x) wandering; clear of the stair's flank (x -14.6).
		"terraces":[-19.0,-30.0]},
	# The west bank: the forecourt's land run on past its NW face into the
	# corner between M's south-west flank and U, banked up against M's stone
	# (its edge a metre inside M's faces) round the drum's door, its far
	# west edge hanging over the haze clear of U's shaft. World (x, z), from
	# F's north face (west of the stair) round to F's west corner.
	"bank":[Vector2(-15.0,36.4),Vector2(-21.0,36.4),Vector2(-31.0,19.0),Vector2(-40.4,2.0),Vector2(-48.0,13.0),Vector2(-56.0,27.0),
		Vector2(-63.0,44.0),Vector2(-62.0,60.0),Vector2(-53.0,72.0)],
	# The land's shape: the hill west of the stair (`high` m at its full,
	# rising from z `south` to z `north` and from the stair's cheek at x
	# `east`, easing down by `ease` past x `west`), terraced a set-off at a
	# time; the sunken way to the door `way` m half wide; the bank's far west
	# lip a set-off down past x `lip`; F's north-east face's grown earth
	# (past its stone, `sag` m out along hex_dir 2) broken a set-off down,
	# north of z `sag_z` (clear of the beacon tower); the keel's depth.
	"land":{"hill":{"south":104.0,"north":52.0,"east":-6.5,"west":-44.0,"ease":0.45,"high":10.4,"tilt":0.62,"scarps":[2.6,7.2]},"way":3.0,
		"lip":-54.0,"sag":40.0,"sag_z":50.0,"swell":1.1,"depth":45.0,
		# The fine grid (m) where the hill's scarps and the way's cut are
		# (world x, z); the kit's coarser `cell` elsewhere.
		"fine":1.5,"fine_box":Rect2(-66.0,-2.0,62.0,120.0),
		# The least step drawn and collided as a cliff (the scarps, the cut's
		# walls; not the hill's slopes).
		"cliff_drop":1.4},
	# Stone fallen from M's crown onto the bank and F (world (x, z), half
	# size, yaw, tilt (deg), sunk m): cover and silhouette, off the ways.
	"fallen":[[Vector2(-51.0,21.0),Vector3(3.2,2.2,4.4),25.0,10.0,1.4],[Vector2(-50.0,30.0),Vector3(2.2,1.6,2.6),-40.0,-22.0,0.6],
		[Vector2(-41.0,9.0),Vector3(1.6,1.2,2.0),70.0,30.0,0.4],[Vector2(-58.0,50.0),Vector3(2.6,1.8,3.0),10.0,-12.0,1.0],
		[Vector2(40.0,62.0),Vector3(2.4,1.7,3.2),-20.0,18.0,0.8]],
	# The door out of the drum (STAND-IN, stacked_court_door.gd): its
	# tunnel's axis (deg, CityKit `dir`), through M's south-west face to the
	# drum's second turn, 5.6 m over F.
	"door":{"angle":307.5},
	# The turf mantle on M's crown (deg, CityKit `dir`): from, to, its inner
	# edge past the well's lip, its ragged overhang past the faces, its swell.
	"mantle":{"from":274.0,"to":325.0,"inner":1.2,"grow":5.0,"high":0.5},
	# The worn way from the arrival up F's terraces and the bank's shelf to
	# the door (world x, z; the mouth's apron ends it).
	"door_way":[Vector2(-14.0,100.0),Vector2(-26.0,88.0),Vector2(-36.0,70.0),Vector2(-38.0,48.0),Vector2(-36.0,34.0)],
	# Lamps on the way's east rim (lit since forever).
	"way_lamps":[Vector2(-28.5,72.0),Vector2(-30.0,50.0)],
	"well":{"apothem":CityKit.DRUM_RADIUS+CityKit.LANDING,"crown":3,"wear":0.5},
	# U and T: the face of M each is set to (hex_dir), their size.
	"west":{"apothem":16.0,"crown":8,"courses":5,"on_face":4,"climb":1,"wear":0.7,"cap":{"grow":4.2,"keep":[1],"seed":SEED+11,"faces":{0:7.5,5:9.0,4:6.5}},
		# U's crown wears a mound of earth on its far side (offset, radius, high).
		"mound":[Vector2(-7.0,-5.0),9.0,2.2]},
	"east":{"apothem":16.0,"crown":8,"courses":5,"on_face":2,"climb":5,"wear":0.45,"cap":{"grow":2.6,"keep":[5],"seed":SEED+12}},
	"needle":{"at":Vector2(-24.0,-124.0),"apothem":12.0,"crown":24,"courses":4,"wear":0.8,"cap":{"grow":5.0,"keep":[],"seed":SEED+13}},
	# The serpent stair: its fault landing (1-based).
	"stair":{"fault":1,"wear":0.55},
	# The causeway: its spans, the breakable bay, its line (z m) over M's
	# north ring (its middle piers stand on the ring there).
	"causeway":{"spans":3,"bay":1,"line":-32.0,"wear":0.6},
	# The beacon towers: F's beside the stair, its back to M (cold: the
	# tower route); T's on its crown (lit: the summit); the needle's (lit).
	"towers":{"forecourt":{"at":Vector2(19.0,0.0),"base":7.2,"lit":false},"summit":{"at":Vector2(5.0,-2.0),"lit":true},"needle":{"lit":true}},
	# The cressets: [on (a pillar), offset (x, z), level over its crown
	# (courses), size, lit].
	"cressets":[
		["well",Vector2(0.0,0.0),-2,"great",false],     # the drum's core floor
		["well",Vector2(-28.6,16.5),0,"cresset",false], # M's south-west ring
		["well",Vector2(28.6,16.5),0,"cresset",false],  # M's south-east ring
		["west",Vector2(-5.0,6.0),0,"cresset",true],    # U's crown, off the causeway's end
		["forecourt",Vector2(-24.0,20.0),0,"great",false], # the forecourt, west of the stair's foot
	],
	# The Keeper's beat on M's north ring (offsets from M), his first look.
	"keeper":{"beat":[Vector2(-12.0,-31.0),Vector2(0.0,-33.0),Vector2(12.0,-31.0)],"face":Vector2(0.0,1.0)},
	# The inhaler head on T's crown at the causeway's end, facing down it.
	"head":{"at":Vector2(-8.0,-1.0),"face":Vector2(-1.0,0.0)},
	# Fallen drums on the forecourt (offset, radius, length, turn deg): cover.
	"drums":[[Vector2(30.0,-15.0),1.7,5.4,20.0],[Vector2(-20.0,14.0),1.5,4.2,-35.0],[Vector2(-30.0,-34.0),1.9,3.2,70.0]],
	# Alone (the yard): far pillars in the haze [x, z, crown (courses), apothem].
	"far":[[-290.0,-250.0,20,30.0],[250.0,-360.0,30,26.0],[350.0,-70.0,10,34.0],[-370.0,50.0,2,38.0],[70.0,-560.0,42,32.0],[-190.0,-510.0,34,28.0]],
	# Small fires lit since forever: on M's crown corners
	# (hex corner f, between faces f and f+1) and on the causeway's parapets
	# over its piers.
	"lamps":{"well_corners":[5,0,2,3],"causeway":true},
}

## Where the pillars stand (x z centres, crowns y), solved from LAYOUT:
## F due south of M (a seam of GAP: the stair spans it); U and T each set
## to one of M's faces (`on_face`) a `seam` off, their lowest collar level
## with M's crown, so a step crosses from M's ring onto it.
static func place_of(key: String) -> Vector3:
	var a_m := float(LAYOUT.well.apothem)
	match key:
		"well": return Vector3(0.0,float(LAYOUT.well.crown)*COURSE,0.0)
		"forecourt": return Vector3(0.0,float(LAYOUT.forecourt.crown)*COURSE,a_m+CityKit.GAP+float(LAYOUT.forecourt.apothem))
		"west","east":
			var p: Dictionary = LAYOUT[key]
			var r := float(p.apothem)+int(p.courses)*CityKit.LEDGE
			var c := CityKit.hex_dir(int(p.on_face))*(a_m+float(LAYOUT.seam)+r)
			return Vector3(c.x,float(p.crown)*COURSE,c.z)
		"needle":
			var n: Dictionary = LAYOUT.needle
			return Vector3(n.at.x,float(n.crown)*COURSE,n.at.y)
	return Vector3.ZERO

## A point `off` (x, z) from pillar `key`'s centre, `up` courses over its crown.
static func on(key: String, off: Vector2, up := 0.0) -> Vector3:
	var p := place_of(key)
	return Vector3(p.x+off.x,p.y+up*COURSE,p.z+off.y)

## The stair's foot (its summit edge on M's south face).
static func stair_foot() -> Vector3:
	return Vector3(0.0,place_of("forecourt").y,float(LAYOUT.well.apothem)+stair_length())

static func stair_length() -> float:
	return CityKit.STAIR_FLIGHTS*CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.STAIR_FLIGHTS*CityKit.LANDING

## The causeway's ends (x): centred on M, U's end to T's.
static func causeway_ends() -> Vector2:
	var half := int(LAYOUT.causeway.spans)*CityKit.SPAN*0.5
	return Vector2(-half,half)

## F's beacon tower: its foot's middle, its giant steps on its local +z
## (south, toward the arrival), its back a seam off M's south face.
static func forecourt_tower() -> Transform3D:
	var base := float(LAYOUT.towers.forecourt.base)*CityFires.size()
	var at: Vector2 = LAYOUT.towers.forecourt.at
	var z := float(LAYOUT.well.apothem)+CityKit.GAP+0.3+base*0.5
	return Transform3D(Basis.IDENTITY,Vector3(at.x,place_of("forecourt").y,z))

## F's turf (local x, z from F's centre): flat by the stair, the tower and
## the ways; west of each terrace edge a set-off up, the edges wandering.
static func forecourt_ground(x: float, z: float) -> float:
	var fp := place_of("forecourt")
	return land_y(x+fp.x,z+fp.z)-fp.y

## The land's ground (world x, z; y over F's crown): F's turf and the west
## bank. Flat round the arrival, the stair and the rims; west of the stair
## F's terraces climb a set-off at a time onto the bank's shelf against M's
## south-west flank, the earth banked higher against the stone either side
## of the door, its apron rising to the tunnel's floor at the mouth; the
## bank's far west lip and F's north-east shelf broken a set-off down.
static var _k := {}
## The land's fixed numbers, once (warm, on the main thread, fills it).
static func _land_k() -> Dictionary:
	if not _k.is_empty(): return _k
	var k := {}
	k.fp = place_of("forecourt")
	var md := door_mouth()
	var u := CityKit.dir(deg_to_rad(float(LAYOUT.door.angle)))
	var line: Array = []
	line.append_array(LAYOUT.door_way)
	line.append(Vector2(md.x-u.x*1.5,md.z-u.z*1.5))
	var total := 0.0
	for i in range(line.size()-1): total += (line[i] as Vector2).distance_to(line[i+1])
	k.line = line
	k.total = total
	k.ramp = place_of("well").y+float(door_spec().floor)-(k.fp as Vector3).y
	var foot := stair_foot()
	k.foot_x = foot.x
	k.foot_z = foot.z
	k.stair_len = stair_length()
	k.wall = CityKit.LANE*0.5+CityKit.CHEEK
	k.fz = (k.fp as Vector3).z
	k.edge = float((LAYOUT.forecourt.terraces as Array)[0])
	var ld: Dictionary = LAYOUT.land
	var hd: Dictionary = ld.hill
	for key: String in ["south","north","east","west","ease","high","tilt"]: k[key] = float(hd[key])
	k.s1 = float(hd.scarps[0])
	k.s2 = float(hd.scarps[1])
	for key: String in ["way","lip","sag","sag_z","swell"]: k[key] = float(ld[key])
	var wb := Rect2(line[0],Vector2.ZERO)
	for q: Vector2 in line: wb = wb.expand(q)
	k.way_box = wb.grow(float(ld.way)+3.0)
	k.keep = [Vector2(6.0,111.6),Vector2(6.0,115.0),Vector2(32.4,96.3),Vector2(0.0,96.0),Vector2(19.0,41.0),Vector2(19.0,52.0),Vector2(19.0,62.0)]
	_k = k
	return k

static func land_y(wx: float, wz: float) -> float:
	var kk := _land_k()
	var z := wz-float(kk.fz)
	var y := 0.0
	# F's first west terrace (the south-west rim's ground).
	if wx < float(kk.edge)+2.2*sin(z*0.11)+1.3*sin(z*0.29+0.6): y = CityKit.SET_OFF
	# The hill: rising north toward M and west from the stair's cheek,
	# easing down again toward the bank's far west, its slope broken by two
	# scarps (a set-off each, their lines wandering): a broad tilted meadow
	# between them, not a stack of plates.
	var east := float(kk.east)
	if wx < east:
		var north := smoothstep(float(kk.south),float(kk.north),wz)
		var west := float(kk.west)
		var across := smoothstep(east,east-9.0,wx)*(1.0-float(kk.ease)*smoothstep(west,west-14.0,wx))
		var na := north*across
		var h := float(kk.high)*na+1.4*sin(wx*0.11+wz*0.07+0.3)*sin(wz*0.09-0.5)*na
		var hill := 0.0
		if h > 0.05:
			hill = float(kk.tilt)*h
			if h > float(kk.s1)+1.1*sin(wx*0.19+wz*0.05+0.4)+0.6*sin(wz*0.31-wx*0.11): hill += CityKit.SET_OFF
			if h > float(kk.s2)+1.3*sin(wx*0.13-wz*0.17+2.1)+0.5*sin(wx*0.37+1.0): hill += CityKit.SET_OFF
		# Beside the stair (its flank is the hill): under its cheek a hair
		# under the treads, then no higher than a little over them.
		var su := absf(wx-float(kk.foot_x))
		if su < float(kk.wall)+3.0:
			var sv := float(kk.foot_z)-wz
			if sv > -1.0 and sv < float(kk.stair_len)+1.0:
				var p := stair_profile(sv)
				if su < float(kk.wall)+0.4: hill = minf(hill,p-0.6)
				else: hill = minf(hill,maxf(p+0.9,0.0))
		y = maxf(y,hill)
		# The sunken way to the door: a cut through the hill (an earth ramp
		# where the hill is lower), rising to the tunnel's floor at the mouth.
		if (kk.way_box as Rect2).has_point(Vector2(wx,wz)):
			var cut := _door_way_at(wx,wz)
			var way := float(kk.way)
			if cut.x < way+2.6:
				var r := float(kk.ramp)*smoothstep(0.0,0.7,cut.y)
				y = lerpf(r,y,smoothstep(way,way+2.6,cut.x))
		if wx < float(kk.lip)+1.8*sin(wz*0.17+0.4): y -= CityKit.SET_OFF
		return y
	if wx*0.8660254+z*-0.5 > float(kk.sag)+1.2*sin(wz*0.21+2.0)+1.2 and wz > float(kk.sag_z): y -= 1.2
	# Swells on F's open east (never under its stone's lip), held flat round
	# the rims, the arrival, the stair's foot and the tower's steps.
	if wx > -8.0:
		var keep := smoothstep(-8.0,2.0,wx)
		# Never up under the stair's east cheek.
		var sv := float(kk.foot_z)-wz
		if sv > -6.0 and sv < float(kk.stair_len)+1.0:
			keep = minf(keep,smoothstep(float(kk.wall)+1.0,float(kk.wall)+7.0,absf(wx-float(kk.foot_x))))
		var at := Vector2(wx,wz)
		for q: Vector2 in kk.keep:
			keep = minf(keep,smoothstep(8.0,18.0,q.distance_to(at)))
			if keep <= 0.0: return y
		var n := 0.5+0.5*sin(wx*0.09+wz*0.05)*sin(wz*0.11-wx*0.04+1.2)
		y += float(kk.swell)*keep*n
	return y

## The serpent stair's tread height (over its foot) `v` m up its run.
static func stair_profile(v: float) -> float:
	var run := CityKit.STAIR_STEPS*CityKit.TREAD
	var s := 0.0
	for f in CityKit.STAIR_FLIGHTS:
		if v < s+run: return f*COURSE+clampf((v-s)/run,0.0,1.0)*COURSE
		if v < s+run+CityKit.LANDING: return (f+1)*COURSE
		s += run+CityKit.LANDING
	return CityKit.STAIR_FLIGHTS*COURSE

## The door's way at a world point: (its distance to the worn way's line
## from the terraces' foot to the mouth, how far along it 0-1).
static func _door_way_at(wx: float, wz: float) -> Vector2:
	var kk := _land_k()
	var line: Array = kk.line
	var total := float(kk.total)
	var p := Vector2(wx,wz)
	var best := INF
	var at := 0.0
	var run := 0.0
	for i in range(line.size()-1):
		var a: Vector2 = line[i]
		var b: Vector2 = line[i+1]
		var ab := b-a
		var t := clampf((p-a).dot(ab)/ab.length_squared(),0.0,1.0)
		var dist := p.distance_to(a+ab*t)
		if dist < best:
			best = dist
			at = (run+ab.length()*t)/total
		run += ab.length()
	return Vector2(best,at)

## How far (m) a world point (x, z) lies outside M's hex (negative inside).
static func m_dist(wx: float, wz: float) -> float:
	var a := float(LAYOUT.well.apothem)
	var best := -INF
	for f in 6:
		var n := CityKit.hex_dir(f)
		best = maxf(best,wx*n.x+wz*n.z-a)
	return best

## The door (M's frame: CityKit-built `Door.door`).
static func door_spec() -> Dictionary:
	return Door.door(deg_to_rad(float(LAYOUT.door.angle)))

## The door's mouth on M's face (world; y its floor).
static func door_mouth() -> Vector3:
	return place_of("well")+Door.door_mouth(float(LAYOUT.well.apothem),door_spec())

## Along the door's face (x, z), unit.
static func _face_side() -> Vector2:
	var f := int(round(deg_to_rad(float(LAYOUT.door.angle))/(TAU/6.0)))%6
	var n := CityKit.hex_dir(f)
	return Vector2(n.z,-n.x)

## The land's outline (world x, z): F's ragged cap on its south faces (the
## rims' faces tucked inside the stone) and its broken north-east face, its
## north face east of the bank, then the bank round to F's west corner.
static func land_outline(cap: Dictionary = {}) -> Array:
	var fp := place_of("forecourt")
	var f0 := Vector2(fp.x,fp.z)
	var ring := cap_outline(float(LAYOUT.forecourt.apothem),LAYOUT.forecourt.cap if cap.is_empty() else cap)
	var out: Array = []
	for i in range(0,18): out.append((ring[i] as Vector2)+f0)
	var bank: Array = LAYOUT.bank
	for i in range(18,24):
		var q: Vector2 = (ring[i] as Vector2)+f0
		if q.x > (bank[0] as Vector2).x+1.0: out.append(q)
	out.append_array(bank)
	for i in range(30,36): out.append((ring[i] as Vector2)+f0)
	return out

## A turfed crown's ground (local): flat, but a hair under the causeway's
## deck where its end rests on the crown (so the turf never shows through).
static func crown_ground(key: String, x: float, z: float) -> float:
	if not key in ["west","east"]: return 0.0
	var p := place_of(key)
	var wx := p.x+x
	var wz := p.z+z
	var end := causeway_ends().y
	var under := absf(wz-float(LAYOUT.causeway.line)) < CityKit.DECK*0.5+0.6 and absf(wx) < end+0.6
	if under: return -0.18
	var mound: Array = LAYOUT[key].get("mound",[])
	if mound.is_empty(): return 0.0
	var d := Vector2(x,z).distance_to(mound[0])
	var r := float(mound[1])
	return float(mound[2])*smoothstep(r,r*0.25,d)*(0.85+0.15*sin(x*0.7+z*0.4))

## A crown cap's outline (local x, z): the hex of `apothem`, each face
## grown out a ragged `grow` m (or its `faces` own), the `keep` faces
## tucked `tuck` m inside (1.4, as CityKit `crown_outline`).
static func cap_outline(apothem: float, cap: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cap.seed)
	var keep: Array = cap.keep
	var tuck := float(cap.get("tuck",1.4))
	var faces: Dictionary = cap.get("faces",{})
	var r := apothem/cos(PI/6.0)
	var out: Array = []
	for f in 6:
		var n := CityKit.hex_dir(f)
		var a0 := TAU*(f-1)/6.0+PI/6.0
		var a1 := TAU*f/6.0+PI/6.0
		var c0 := Vector2(sin(a0),cos(a0))*r
		var c1 := Vector2(sin(a1),cos(a1))*r
		var kept := f in keep
		var kept_prev := ((f+5)%6) in keep
		var grow := float(faces.get(f,cap.grow))
		for i in 6:
			var t := i/6.0
			var off := -tuck if kept else grow*(0.35+0.65*rng.randf())
			if i == 0:
				# The corner: tucked if either face is, else out along both.
				off = -tuck if (kept or kept_prev) else grow*0.6
				var bis := Vector2(sin(a0),cos(a0))
				out.append(c0+bis*off/cos(PI/6.0))
				continue
			out.append(c0.lerp(c1,t)+Vector2(n.x,n.z)*off)
	return out

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "stacked_court"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Stacked Court"

func epithet() -> String:
	return "Every crown was lit for someone climbing. Someone still keeps the well."

func brief() -> String:
	return "Up: the serpent stair, round the well, the west pillar's collars and the causeway; or the beacon tower, round the well, the east pillar's collars.\nThe Keeper walks the well's far ring; a head holds the summit."

func start() -> Vector3:
	return on("forecourt",Vector2(6.0,float(LAYOUT.forecourt.apothem)-6.0))

## In on F's south edge; out on T's far (north-east) edge. Underground the
## court is most of the pool, and the generator
## never turns an isle, so court must join court: more ways in on F's
## south-east and south-west faces, and out on T's north face. A way out
## north meets a way in south, north-east (the summit's) meets south-west;
## the south-east one meets the base's rims. F's land keeps those faces on
## the old hex's lines (LAYOUT `keep`, `tuck` 0: no ragged growth), each rim
## IN m in from the land's edge, its lip there. (A way out on U's north-west face was tried: its
## collars stand under the lip.)
const IN := 2.6
func rims() -> Array:
	var n := CityKit.hex_dir(int(LAYOUT.east.on_face))
	var out := on("east",Vector2(n.x,n.z)*(float(LAYOUT.east.apothem)-1.4))
	var a_f := float(LAYOUT.forecourt.apothem)
	var se := CityKit.hex_dir(1)
	var sw := CityKit.hex_dir(5)
	# The south-west face toward its south corner, between the terraces.
	var sw_at := Vector2(-46.2,0.0).lerp(Vector2(-23.1,40.0),0.85)*(a_f/40.0)-Vector2(sw.x,sw.z)*IN
	var t_n := CityKit.hex_dir(3)
	return [
		{"name":"forecourt","at":on("forecourt",Vector2(6.0,a_f-IN)),"face":Vector3(0.0,0.0,1.0),"run_up":14.0,"lip":IN},
		{"name":"forecourt_se","at":on_forecourt(Vector2(se.x,se.z)*(a_f-IN)),"face":se,"run_up":12.0,"lip":IN,"way":"in"},
		{"name":"forecourt_sw","at":on_forecourt(sw_at),"face":sw,"run_up":5.0,"lip":IN,"way":"in"},
		{"name":"east_north","at":on("east",Vector2(t_n.x,t_n.z)*(float(LAYOUT.east.apothem)-1.4)),"face":t_n,"run_up":8.0,"lip":1.0,"way":"out"},
		{"name":"summit","at":out,"face":n,"run_up":10.0,"lip":1.0},
	]

func spots() -> Array:
	var s: Vector2 = LAYOUT.towers.summit.at
	return [
		{"kind":"arena","name":"forecourt","at":on("forecourt",Vector2(-12.0,8.0)),"room":12.0},
		{"kind":"arena","name":"keepers_ring","at":on("well",Vector2(0.0,-33.0)),"room":4.0},
		{"kind":"cover","name":"under_the_causeway","at":on("well",Vector2(-6.0,float(LAYOUT.causeway.line)+3.0)),"room":3.0},
		{"kind":"perch","name":"summit_tower","at":on("east",s,3.0),"room":1.5},
		{"kind":"perch","name":"west_crown","at":on("west",Vector2(-6.0,4.0)),"room":3.0},
		{"kind":"cover","name":"the_door","at":door_mouth()+Vector3.UP*0.1-_door_u()*6.0,"room":1.8},
	]+collect_spots()

func _door_u() -> Vector3:
	return CityKit.dir(deg_to_rad(float(LAYOUT.door.angle)))

## A point on the drum's coil (M's frame turned world): turn `t`, angle `deg`.
static func coil(t: int, deg: float, up := 0.6) -> Vector3:
	var a := deg_to_rad(deg)
	var j := t*CityKit.DRUM_SEGMENTS+int(floor(a/(TAU/CityKit.DRUM_SEGMENTS)))
	var y := -CityKit.RISER*floori(j*CityKit.DRUM_STEPS/float(CityKit.DRUM_SEGMENTS))
	var r := CityKit.DRUM_RADIUS-CityKit.LANE*(t+a/TAU)-CityKit.LANE*0.5
	return place_of("well")+CityKit.dir(a)*r+Vector3.UP*(y+up)

## The collectibles' spots (the collectibles round reads them): runes along
## the ways (rune_line), tempting exposed detours (rune_risk), and the rare
## finds (behind a break, down the well, up the summit tower, on the door's
## lintel).
func collect_spots() -> Array:
	var out: Array = []
	var foot := stair_foot()
	var cw := float(LAYOUT.causeway.line)
	var deck := place_of("east").y
	# The serpent stair's flights and landings.
	for p: Vector2 in [Vector2(-4.8,2.4),Vector2(-23.2,7.2),Vector2(-32.4,9.6),Vector2(-41.6,12.0)]:
		out.append({"kind":"rune_line","name":"stair_%d" % int(-p.x),"at":foot+Vector3(0.0,p.y+0.6,p.x),"room":1.0})
	# The worn way up the terraces to the door, and the tunnel.
	var k := 0
	for q: Vector2 in LAYOUT.door_way:
		if k > 0: out.append({"kind":"rune_line","name":"door_way_%d" % k,"at":Vector3(q.x,land_y(q.x,q.y)+place_of("forecourt").y+0.6,q.y),"room":1.0})
		k += 1
	for d: float in [4.0,12.0,20.0]:
		out.append({"kind":"rune_line","name":"tunnel_%d" % int(d),"at":door_mouth()+Vector3.UP*0.6-_door_u()*d,"room":0.8})
	# Up the coil from the door to the rim.
	for c: Array in [[1,250.0],[1,170.0],[1,90.0],[1,15.0],[0,290.0],[0,200.0],[0,110.0],[0,30.0]]:
		out.append({"kind":"rune_line","name":"coil_%d_%d" % [int(c[0]),int(c[1])],"at":coil(int(c[0]),float(c[1])),"room":1.0})
	# M's ring west, the causeway's deck.
	for deg: float in [330.0,300.0,278.0]:
		out.append({"kind":"rune_line","name":"ring_%d" % int(deg),"at":on("well",Vector2(sin(deg_to_rad(deg)),cos(deg_to_rad(deg)))*30.5,0.125),"room":1.0})
	for x: float in [-26.0,-13.0,13.0,26.0]:
		out.append({"kind":"rune_line","name":"causeway_%d" % int(x),"at":Vector3(x,deck+0.6,cw),"room":1.0})
	# Tempting and exposed: the cracked bay over the Keeper, F's broken
	# north-east shelf over the haze, the bank's west lip, the stair's west
	# cheek crest.
	out.append({"kind":"rune_risk","name":"cracked_bay","at":Vector3(0.0,deck+0.6,cw),"room":1.0})
	var ne := place_of("forecourt")+CityKit.hex_dir(2)*47.0
	out.append({"kind":"rune_risk","name":"broken_shelf","at":Vector3(ne.x,land_y(ne.x,ne.z)+0.6,ne.z),"room":1.0})
	out.append({"kind":"rune_risk","name":"bank_lip","at":Vector3(-59.0,land_y(-59.0,46.0)+0.6,46.0),"room":1.0})
	out.append({"kind":"rune_risk","name":"stair_crest","at":foot+Vector3(-(CityKit.LANE*0.5+CityKit.CHEEK*0.5),7.2+CityKit.CREST+0.5,-23.2),"room":0.8})
	# The rare: in the fault's chamber under the stair's first landing (it
	# opens when he breaks it), by the cold great cresset at the well's
	# bottom (the Keeper's home), the summit tower's crown.
	out.append({"kind":"rare","name":"fault_chamber","at":foot+Vector3(0.0,0.6,-14.0),"room":1.0})
	out.append({"kind":"rare","name":"well_bottom","at":place_of("well")+Vector3(0.0,-2.0*COURSE+0.6,-7.0),"room":1.0})
	out.append({"kind":"rare","name":"summit_crown","at":on("east",LAYOUT.towers.summit.at,3.0),"room":1.0})
	# A hop from the cut's rim onto the makers' lintel over the door.
	out.append({"kind":"rune_line","name":"makers_lintel","at":door_mouth()+Vector3.UP*(Door.DOOR_HEAD+1.7+0.6)+_door_u()*0.3,"room":0.8})
	return out

## The solids for the occupancy, the footprint and the bodies' cliffs (the
## generator reads these, never the build): each pillar's crown and collar
## rings as hexes in axis strips (inside the real faces, so a cliff found
## on them fits the real face), M's crown round its well and the drum's
## turns in it, the stair as a ramp, the causeway's deck, the towers.
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	for key: String in ["well","west","east","needle"]:
		var p := place_of(key)
		var d: Dictionary = LAYOUT[key]
		var courses := int(d.get("courses",0))
		var well := CityKit.DRUM_RADIUS if key == "well" else 0.0
		for k in range(courses,-1,-1):
			_hex_strips(out,Vector2(p.x,p.z),float(d.apothem)+k*CityKit.LEDGE,floor_y,p.y-k*COURSE,well if k == 0 else 0.0)
		if well > 0.0:
			_hex_strips(out,Vector2(p.x,p.z),well*cos(PI/6.0),floor_y,p.y-COURSE,0.0)
		# The turf cap's ragged overhang (`cap_outline`, `grow` past the stone,
		# its earth hanging a course): in the occupancy, so no crossing's
		# corridor runs through it (a layer of courts
		# put them in each other's way).
		if d.has("cap") and key != "forecourt":
			_hex_strips(out,Vector2(p.x,p.z),float(d.apothem)+_grow_most(d.cap),p.y-COURSE,p.y+(2.2 if key == "west" else 0.0),0.0)
	# The land (F's turf and the west bank): in 4 m strips, each its highest
	# ground, down to the keel's reach (1.4 x its depth).
	_land_strips(out)
	var foot := stair_foot()
	out.append(["ramp",foot+Vector3(0.0,0.0,CityKit.HEAD_LENGTH),foot+Vector3(0.0,CityKit.STAIR_FLIGHTS*COURSE,-stair_length()),CityKit.LANE+2.0*(CityKit.CHEEK+CityKit.FLANK),"grey"])
	var ends := causeway_ends()
	var line := float(LAYOUT.causeway.line)
	var deck := place_of("east").y
	out.append(["box",Rect2(ends.x,line-CityKit.DECK*0.5,ends.y-ends.x,CityKit.DECK),deck-CityKit.DECK_THICK,deck,"grey"])
	# (The beacon towers stand on these crowns; left out, so the bodies'
	# cliffs are the crowns' and collars' edges, not a tower's shelf.)
	return out

static func _grow_most(cap: Dictionary) -> float:
	var g := float(cap.grow)
	for f: int in cap.get("faces",{}): g = maxf(g,float(cap.faces[f]))
	return g

static func _land_strips(out: Array) -> void:
	var poly := PackedVector2Array(land_outline())
	var box := Rect2(poly[0],Vector2.ZERO)
	for q in poly: box = box.expand(q)
	var fy := place_of("forecourt").y
	var bottom := fy-1.4*float(LAYOUT.land.depth)
	var cell := 4.0
	var z := box.position.y
	while z < box.end.y:
		var x := box.position.x
		var run_x := NAN
		var run_y := NAN
		while x <= box.end.x:
			var h := NAN
			for q: Vector2 in [Vector2(0.3,0.3),Vector2(cell-0.3,0.3),Vector2(0.3,cell-0.3),Vector2(cell-0.3,cell-0.3),Vector2(cell*0.5,cell*0.5)]:
				if Geometry2D.is_point_in_polygon(Vector2(x,z)+q,poly):
					h = maxf(h if not is_nan(h) else -INF,land_y(x+q.x,z+q.y)+fy)
			if not is_nan(h): h = snappedf(h+0.05,0.4)
			if not is_nan(run_x) and (is_nan(h) or h != run_y):
				out.append(["box",Rect2(run_x,z,x-run_x,cell),bottom,run_y,"grey"])
				run_x = NAN
			if not is_nan(h) and is_nan(run_x):
				run_x = x
				run_y = h
			x += cell
		if not is_nan(run_x): out.append(["box",Rect2(run_x,z,x-run_x,cell),bottom,run_y,"grey"])
		z += cell

## A hex of apothem `a` round `c` (faces to +-z) as axis boxes in bands of
## RuinKit.BAY along z, each its band's narrowest (inside the faces); a
## round hole of radius `hole` cut from the middle.
static func _hex_strips(out: Array, c: Vector2, a: float, bottom: float, top: float, hole: float) -> void:
	var band := CityKit.CELL
	var z := -a
	while z < a-0.01:
		var z1 := minf(z+band,a)
		var zm := maxf(absf(z),absf(z1))
		var hw := (a-0.5*zm)/cos(PI/6.0)
		var zn := minf(absf(z),absf(z1)) if z*z1 > 0.0 else 0.0
		if hole > 0.0 and zn < hole:
			var hx := sqrt(hole*hole-zn*zn)
			if hw > hx:
				out.append(["box",Rect2(c.x-hw,c.y+z,hw-hx,z1-z),bottom,top,"grey"])
				out.append(["box",Rect2(c.x+hx,c.y+z,hw-hx,z1-z),bottom,top,"grey"])
		elif hw > 0.0:
			out.append(["box",Rect2(c.x-hw,c.y+z,hw*2.0,z1-z),bottom,top,"grey"])
		z = z1

func heads() -> Array:
	var h: Dictionary = LAYOUT.head
	var at := on("east",h.at)
	return [{"name":"summit","at":at,"face":h.face,"knobs":{"route":[Vector3(at.x,0.0,at.z)]}}]

# --- The land and the stone ------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return _seed+9

# --- One court of many (the underground layer) ----------------
## Underground the court is most of the pool, so a layer holds several. The
## generator never turns an isle and the occupancy is the motif's (one per
## slug), so the shape stays; `vary` (scripts/roguelike/layer_plan.gd
## `_motif_isle`, from the isle's own seed) changes what doesn't touch it:
## the stone's seeds and weathering, the turf caps' ragged edges, the fallen
## drums' lie, the Keeper's seed, and which of the cold cressets someone
## still keeps lit. The yard's court is SEED's.
var _seed := SEED
var _wear := 0.0
var _lit: Array = []
var _drum_turn := 0.0

func vary(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_seed = SEED+seed_value*97
	_wear = rng.randf_range(-0.15,0.2)
	_drum_turn = rng.randf_range(-35.0,35.0)
	_lit.clear()
	for k in range((LAYOUT.cressets as Array).size()):
		if rng.randf() < 0.3: _lit.append(k)
	knobs = {"look":seed_value,"wear":snappedf(_wear,0.01),"lit":_lit.duplicate()}

## A piece's wear, this court's.
func _w(w: Variant) -> float:
	return clampf(float(w)+_wear,0.1,0.95)

## The worn ways on F (the motif's frame): the arrival to the stair's foot,
## and to the tower's steps.
static func paths() -> Array:
	var s := on("forecourt",Vector2(6.0,float(LAYOUT.forecourt.apothem)-6.0))
	var foot := stair_foot()
	var tw := forecourt_tower().origin
	var md := door_mouth()
	var u := CityKit.dir(deg_to_rad(float(LAYOUT.door.angle)))
	var way: Array = [Vector2(s.x,s.z)]
	for q: Vector2 in LAYOUT.door_way: way.append(q)
	way.append(Vector2(md.x+u.x*3.0,md.z+u.z*3.0))
	return [[Vector2(s.x,s.z),Vector2(foot.x,foot.z+6.0)],[Vector2(s.x,s.z),Vector2(tw.x,tw.z+12.0),Vector2(tw.x,tw.z+5.0)],way]

## Butterflies and the wind's bits under the sky; none in the abyss.
func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	_land_k()
	warm_look()
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_computed()

## Measured headless on the Mac (the build alone, `built_ms`: 560-700 ms;
## the land island is most of it, the kit's cliff probe over the hill).
func build_cost() -> int:
	return 650

## The pieces, by name, once built (for `live`'s dresser and checks).
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "StackedCourt"
	into.add_child(root)
	pieces.clear()
	var floor_y := float(LAYOUT.floor)
	# F: land, not a pillar: the forecourt and the west bank one KitLand
	# island hanging over the haze on its own keel, the city's pillars
	# standing up out of the depths beside it.
	_land(root)
	# M: the well and its drum stair, the door through its south-west flank
	# into the drum's second turn (STAND-IN: stacked_court_door.gd).
	var md: Dictionary = LAYOUT.well
	var mp := place_of("well")
	var door := door_spec()
	var m := Door.well_pillar(_seed+3,_w(md.wear),float(md.apothem),CityKit.DRUM_RADIUS,mp.y-floor_y,door)
	m.name = "Well"
	m.position = mp
	root.add_child(m)
	pieces.well = m
	var drum := Door.drum(SEED+4,float(md.wear),door)
	drum.name = "Drum"
	drum.position = mp
	root.add_child(drum)
	pieces.drum = drum
	_mantle(root)
	_fallen(root)
	# U and T on M's faces; the needle behind.
	var k := 0
	for key: String in ["west","east","needle"]:
		var d: Dictionary = LAYOUT[key]
		var p := place_of(key)
		var n := CityKit.pillar(_seed+5+k,_w(d.wear),{"apothem":d.apothem,"courses":d.courses,"climb":int(d.get("climb",-1)),"crown":"bare","depth":p.y-floor_y})
		n.name = key.capitalize()
		n.position = p
		root.add_child(n)
		pieces[key] = n
		var g_key := key
		_turf_cap(root,key,{"ground":func(x: float, z: float) -> float: return crown_ground(g_key,x,z)})
		k += 1
	# The serpent stair from F to M's south face.
	var sd: Dictionary = LAYOUT.stair
	var stair := CityKit.stair(SEED+8,float(sd.wear),{"fault":int(sd.fault),"flank":0.0})
	stair.name = "SerpentStair"
	stair.position = stair_foot()
	root.add_child(stair)
	pieces.stair = stair
	# The causeway from U's crown to T's: its local -z turned to +x, its
	# middle piers stopped a GAP over M's ring (CityKit's rule).
	var cd: Dictionary = LAYOUT.causeway
	var ends := causeway_ends()
	var deck_y := place_of("east").y
	var cw := CityKit.causeway(SEED+9,float(cd.wear),{"spans":int(cd.spans),"bay":int(cd.bay),"drop":deck_y-mp.y-CityKit.GAP})
	cw.name = "Causeway"
	cw.transform = Transform3D(Basis(Vector3.UP,-PI/2.0),Vector3(ends.x,deck_y,float(cd.line)))
	root.add_child(cw)
	pieces.causeway = cw
	_drums(root)
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## A turf cap on pillar `key`'s bare crown (KitLand, CityKit `crown_outline`'s
## way, its edge ragged past the stone: `cap_outline`), registered as turf.
## `spec` adds to the island's (ground, cliffs, tone).
func _turf_cap(root: Node3D, key: String, spec: Dictionary) -> void:
	var d: Dictionary = LAYOUT[key]
	# This court's ragged edge (`vary`; the yard's is SEED's).
	var cap: Dictionary = (d.cap as Dictionary).duplicate()
	cap.seed = int(cap.seed)+_seed-SEED
	var island := {"outline":cap_outline(float(d.apothem),cap),"seed":int(cap.seed),"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":CityKit.COURSE*0.6,"hang":true,"resample":[60.0,120,48],"tone":KitLook.turf(int(cap.seed)),"cell":2.5}
	island.merge(spec,true)
	var land := KitLand.island(island)
	land.name = "Turf_"+key
	land.position = place_of(key)
	root.add_child(land)
	turf(land,_placed_outline(land))

## The land: F's turf and the west bank as one KitLand island on F's bare
## crown, its keel hanging under the bank and F's grown north-east edge.
var land_node: Node3D = null
func _land(root: Node3D) -> void:
	var fd: Dictionary = LAYOUT.forecourt
	var fp := place_of("forecourt")
	var f0 := Vector2(fp.x,fp.z)
	var cap: Dictionary = (fd.cap as Dictionary).duplicate()
	cap.seed = int(cap.seed)+_seed-SEED
	var outline: Array = []
	var box := Rect2()
	for q: Vector2 in land_outline(cap):
		var l := q-f0
		box = Rect2(l,Vector2.ZERO) if outline.is_empty() else box.expand(l)
		outline.append(l)
	# The hill's scarps, the way's cut and the first terrace are all in the
	# fine box: its cliffs (the probe runs the ground every half metre over
	# the box: kept to where the cliffs are).
	var fine := Rect2((LAYOUT.land.fine_box as Rect2).position-f0,(LAYOUT.land.fine_box as Rect2).size)
	var land := KitLand.island({"outline":outline,"seed":int(cap.seed),"ground":func(x: float, z: float) -> float: return land_y(x+fp.x,z+fp.z)-fp.y,
		"top":0.0,"depth":float(LAYOUT.land.depth),"hang":true,"resample":[200.0,240,80],"cell":2.5,"cliffs":fine.intersection(box.grow(2.0)),
		"cliff_drop":float(LAYOUT.land.cliff_drop),"fine":float(LAYOUT.land.fine),"fine_box":fine,
		"tone":KitLook.turf(int(cap.seed),KitLand.wear_of(_local(paths(),fp)))})
	land.name = "Turf_forecourt"
	land.position = fp
	root.add_child(land)
	turf(land,_placed_outline(land))
	land_node = land

## The hill's growth gone on up over M's south-west crown: a turf mantle on
## its ring (walked over on the court's way west), its ragged edge hanging
## over the flank above the door. Clear of U's seam (the NW face), the
## stair's landing and M's lit corner.
func _mantle(root: Node3D) -> void:
	var md: Dictionary = LAYOUT.mantle
	var a := float(LAYOUT.well.apothem)
	var inner := CityKit.DRUM_RADIUS+float(md.inner)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed+61
	var a0 := deg_to_rad(float(md.from))
	var a1 := deg_to_rad(float(md.to))
	var outline: Array = []
	var n := 14
	for i in n+1:
		var ang := lerpf(a0,a1,i/float(n))
		var face := a/cos(fposmod(ang+PI/6.0,PI/3.0)-PI/6.0)
		var grow := float(md.grow)*(0.4+0.6*rng.randf()) if i > 0 and i < n else 0.0
		var d := CityKit.dir(ang)
		outline.append(Vector2(d.x,d.z)*(face+grow))
	for i in range(n,-1,-1):
		var ang := lerpf(a0,a1,i/float(n))
		var d := CityKit.dir(ang)
		outline.append(Vector2(d.x,d.z)*(inner+0.6*rng.randf()))
	var high := float(md.high)
	var ground := func(x: float, z: float) -> float:
		return 0.12+high*smoothstep(inner,inner+5.0,Vector2(x,z).length())*(0.7+0.3*sin(x*0.5+z*0.37))
	var land := KitLand.island({"outline":outline,"seed":_seed+61,"ground":ground,
		"top":0.0,"depth":COURSE*0.6,"hang":true,"resample":[60.0,60,40],"cell":2.0,"tone":KitLook.turf(_seed+61)})
	land.name = "Turf_mantle"
	land.position = place_of("well")
	root.add_child(land)
	turf(land,_placed_outline(land))

## Stone fallen from M's crown and the city's walls, tumbled on the land and
## half sunk in it (the kit's stone, collided): [world (x, z), half size,
## yaw, tilt (deg), sink].
func _fallen(root: Node3D) -> void:
	var b := CityKit.Piece.new("Fallen",_seed+50,_w(0.75))
	for f: Array in LAYOUT.fallen:
		var at: Vector2 = f[0]
		var h: Vector3 = f[1]
		var basis := Basis.from_euler(Vector3(deg_to_rad(float(f[3])),deg_to_rad(float(f[2])+_drum_turn*0.3),deg_to_rad(float(f[3])*0.6)))
		var y := land_y(at.x,at.y)+place_of("forecourt").y+h.y-float(f[4])
		b.block(CityStone.box(Transform3D(basis,Vector3(at.x,y,at.y)),h,0.25),true,null,1.4)
	var node := b.finish()
	root.add_child(node)
	pieces.fallen = node

## A turf island's outline in the motif's frame. The placed isle registers
## a land's outline (its KitLand meta, the island's own frame) moved only by
## the isle's offset (motif_isle.gd `_register`), so an island stood off the
## motif's origin (every land here: F's centre, the pillars' crowns) gives
## its outline itself, else the plants' rim test finds no turf where it
## really is and the grass never grows there.
static func _placed_outline(land: Node3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	var at := Vector2(land.position.x,land.position.z)
	for p: Vector2 in (land.get_meta("outline") as PackedVector2Array): out.append(p+at)
	return out

## Where F's ground is at an offset from its centre (on its terraces).
static func on_forecourt(off: Vector2) -> Vector3:
	return on("forecourt",off)+Vector3.UP*forecourt_ground(off.x,off.y)

## Fallen column drums on the forecourt (cover; the makers' stone).
func _drums(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var solids := StaticBody3D.new()
	solids.name = "Drums"
	for d: Array in LAYOUT.drums:
		var r := float(d[1])
		var length := float(d[2])
		var at := on_forecourt(d[0])
		var turn := Basis(Vector3.UP,deg_to_rad(float(d[3])+_drum_turn))*Basis(Vector3.FORWARD,PI/2.0)
		var xf := Transform3D(turn,at+Vector3.UP*(r-0.25))
		g.cylinder(xf,r,length,12,0.2,at.y-0.3,0.9)
		var c := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = length
		c.shape = shape
		c.transform = xf
		solids.add_child(c)
	var mesh := MeshInstance3D.new()
	mesh.name = "DrumsMesh"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)

static func _local(lines: Array, at: Vector3) -> Array:
	var out: Array = []
	for line: Array in lines:
		var l: Array = []
		for q: Vector2 in line: l.append(q-Vector2(at.x,at.z))
		out.append(l)
	return out

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces.values(): n += int(p.get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The fires, the breakables hub, the Keeper and his beat, the yard's far
## pillars, and (in the abyss) the grass on the stone tops once they stand.
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var tw: Dictionary = LAYOUT.towers
	var ft := forecourt_tower()
	ft.origin = g.w(ft.origin)
	CityFires.tower(fires,ft,{"seed":_seed+20,"name":"ForecourtTower","lit":bool(tw.forecourt.lit),"base":float(tw.forecourt.base)})
	CityFires.tower(fires,Transform3D(Basis(Vector3.UP,-PI/2.0),g.w(on("east",tw.summit.at))),{"seed":_seed+21,"name":"SummitTower","lit":bool(tw.summit.lit)})
	CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.4),g.w(place_of("needle"))),{"seed":_seed+22,"name":"NeedleTower","lit":bool(tw.needle.lit),"steps":false,"base":9.0,"beam":3.0})
	var k := 0
	for c: Array in LAYOUT.cressets:
		var lit := bool(c[4]) or _lit.has(k)
		var at := on_forecourt(c[1]) if str(c[0]) == "forecourt" else on(str(c[0]),c[1],float(c[2]))
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":c[3],"seed":_seed+30+k,"name":"Cresset%d_%s" % [k,str(c[0])],"lit":lit})
		k += 1
	for at: Vector3 in lamp_points():
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":_seed+40+k,"name":"Lamp%d" % k,"lit":true,"barge":false})
		k += 1
	# The hub: every Olmec's breaker (the bay, the fault, the cressets).
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	# The Keeper: a whole Olmec on M's north ring, chase on, his routes.
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the Keeper back).
	if OlmecPlaces.keepers(g):
		var kd: Dictionary = LAYOUT.keeper
		var beat: Array[Vector3] = []
		for p: Vector2 in kd.beat: beat.append(g.w(on("well",p)))
		var post: Vector3 = beat[1]
		var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,kd.face,{"chase":1,"chase_routes":1,"seed":_seed})
		var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,kd.face,{})
		var keeper := Keeper.new()
		keeper.name = "Keeper_STANDIN"
		keeper.beat = beat
		keeper.post = post
		keeper.field = g.stage.enemies
		keeper.hub = hub
		keeper.wear(body,head)
		g.add_child(keeper)
	if str(g.stage.study.get_script().resource_path).ends_with("motif_yard.gd"): _far(g)
	if Underground.on():
		var dresser := Dresser.new()
		dresser.name = "Dresser"
		dresser.motif = self
		g.add_child(dresser)

## The small lit lamps (the motif's frame): M's crown corners (the kit's
## own cresset mounts, CityKit `pillar`) and the causeway's parapets over
## its middle piers (CityKit `causeway`'s mounts, turned as it stands).
static func lamp_points() -> Array:
	var out: Array = []
	var m := place_of("well")
	var a := float(LAYOUT.well.apothem)
	for f: int in LAYOUT.lamps.well_corners:
		var corner := (CityKit.hex_dir(f)+CityKit.hex_dir(f+1)).normalized()*(a-3.0)/cos(PI/6.0)
		out.append(m+corner)
	if bool(LAYOUT.lamps.causeway):
		var ends := causeway_ends()
		var xf := Transform3D(Basis(Vector3.UP,-PI/2.0),Vector3(ends.x,place_of("east").y,float(LAYOUT.causeway.line)))
		for s in range(1,int(LAYOUT.causeway.spans)):
			for side: float in [-1.0,1.0]:
				out.append(xf*Vector3(side*(CityKit.DECK*0.5-CityKit.PARAPET.x*0.5),CityKit.PARAPET.y,-s*CityKit.SPAN))
	# Either side of the drum's door on the bank, seen from the arrival.
	var md := door_mouth()
	var sd := _face_side()
	var n := CityKit.hex_dir(int(round(deg_to_rad(float(LAYOUT.door.angle))/(TAU/6.0)))%6)
	for s: float in [-1.0,1.0]:
		var q := Vector2(md.x,md.z)+sd*s*4.6+Vector2(n.x,n.z)*1.6
		out.append(Vector3(q.x,land_y(q.x,q.y)+place_of("forecourt").y,q.y))
	# On the sunken way's rim, leading the eye from the arrival to the door.
	for q: Vector2 in LAYOUT.way_lamps:
		out.append(Vector3(q.x,land_y(q.x,q.y)+place_of("forecourt").y,q.y))
	return out

## Alone in the yard: far pillars in the haze, their crowns lit (drawn
## only; the layers in the distance a layer's own isles are).
func _far(g: Node) -> void:
	var far := Node3D.new()
	far.name = "FarLayers"
	g.add_child(far)
	var k := 0
	for f: Array in LAYOUT.far:
		var crown := float(f[2])*COURSE
		var at: Vector3 = g.w(Vector3(float(f[0]),crown,float(f[1])))
		var p := CityKit.pillar(SEED+60+k,0.7,{"apothem":float(f[3]),"courses":2,"climb":-1,"crown":"paved","depth":crown-float(LAYOUT.floor)-40.0})
		p.position = at
		for n: Node in p.find_children("*","CollisionObject3D",true,false): (n as CollisionObject3D).collision_layer = 0
		far.add_child(p)
		CityFires.tower(far,Transform3D(Basis(Vector3.UP,k*1.3),at+Vector3(float(f[3])*0.3,2.0*CityKit.SET_OFF,0.0)),{"tiers":2,"base":9.0,"steps":false,"lit":true,"seed":SEED+70+k,"name":"FarTower%d" % k,"beam":3.0})
		k += 1

## STAND-IN: the Keeper's rounds. A whole Olmec unaware roams any way; this
## turns him, while he listens or roams and isn't hunting, toward the next
## point of his beat on M's north ring, back and forth (gb_rootbound_cut's
## Patrol). It holds him at his post till the stone under him stands (a
## rendered yard builds the art on a worker after the stage), puts his head
## back after the yard's reset, and hands every Olmec the breakables hub.
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
	## Counted, for checks.
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
		# Untyped: a freed one still listed is skipped, not assigned.
		for v: Variant in field.enemies:
			if not is_instance_valid(v): continue
			var e: Node3D = v
			if e.has_method("make_whole") and e.position.distance_to(post) < 6.0: body = e
			elif e.has_method("mouth") and e.position.distance_to(post) < 12.0: head = e
		if body != null and head != null:
			body.make_whole(head)
			landed = false
			leg = 1
			dir = 1

## The abyss's ground cover (GroundCover `asked`: grass unless --ground=
## says) on the stone's walked tops once they stand: M's crown ring, U's,
## T's and the needle's crowns and collars, the stair's landings, summit and
## flank tiers, the causeway's deck (not the bay or the fault: a cover would
## hang where they were; nor the drum's turns: its coil reads as bare stone).
class Dresser extends Node:
	const ON := ["crown","landing","summit","deck","tier","collar"]
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
		for key: String in pieces:
			var p: Node3D = pieces[key]
			if not is_instance_valid(p) or not p.is_inside_tree(): return
		var k := 0
		for key: String in pieces:
			if key in ["forecourt","drum"]: continue
			var p: Node3D = pieces[key]
			for a: Dictionary in p.get_meta("walk_areas",[]):
				if not String(a.kind) in ON: continue
				var opts := {"tufts":0.5,"under":0.3} if String(a.kind) == "collar" else {}
				if GroundCover.cover(p,a.poly,kind,float(a.y),SEED+k,opts) != null: laid += 1
				k += 1
		print("stacked court: ground %s on %d tops" % [kind,laid])
		set_physics_process(false)
