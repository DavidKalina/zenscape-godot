extends RefCounted
## The city kit's landmarks (docs/design/roguelike/city-landmarks-round1.md):
## the three set pieces of the underground Olmec city the user named, cards
## city_court, city_pyramid and city_hall (brainstorm/round3-olmec-city/
## kit-k1-literal.md). Each is a place you see from far off in the haze as a
## silhouette, and a place two bodies use differently: his lanes his width
## (CityKit.LANE, 8.8 m), her lines cut at her own numbers (SET_OFF, STAND).
##
##   city_court    the ballcourt coliseum: a sunk alley between battered
##                 walls (a talud you slide, a tablero you climb by the
##                 walker-only prisms), stone rings hung off serpent beams
##                 from the rim with a root to swing from each, stepped
##                 stands up to his promenade, a shaft in the alley's middle
##                 and an end that breaks off into the abyss.
##   city_pyramid  the temple pyramid: four talud-tablero tiers his lanes,
##                 the epic stair (CityKit.stair) up its face with its fault
##                 landing, a walker-only grab chain up the west face, kick
##                 chimneys up the east face, a summit shrine whose door only
##                 she fits (a true safe room), a cresset on the summit.
##   city_hall     the sundered hall: a hypostyle hall of square pillars, a
##                 raised nave his lane, side aisles a slot only she fits
##                 (walker-only screens hide her from him), split by a crack
##                 the low half dropped a set-off and drifted from; a fallen
##                 nave slab bridges it.
##
## Built as the family's pieces are (scripts/city_kit.gd): CityKit.Piece
## (blocks in the Olmec's basalt, scripts/city_kit_stone.gd, collided as
## clean columns that each run down to the piece's foot so no top is buried
## under another solid), a Node3D front toward +Z with "Mesh" and "Body",
## meta `ports`, `mounts`, `walk_areas`, `his`, `breaks`, `triangles`, and
## here `ropes` (the court's swing roots: [{anchor, length}] piece-local; the
## scene hangs them, FootPieces `rope`) and `sizes`. A piece stands on its own
## foundation (`foundation` m of battered basalt under its foot, into the
## haze), so each is an isle chunk; y 0 is its walked ground (the court's
## alley, the pyramid's foot, the hall's high floor).
##
## Registration (scripts/city_kit.gd, the family's file, untouched here):
##   const CityLandmarks = preload("res://scripts/city_kit_landmarks.gd")
##   PIECES ... + CityLandmarks.PIECES;  NAMES.merge(CityLandmarks.NAMES)
##   in piece(): if id in CityLandmarks.PIECES: return CityLandmarks.piece(id,seed_value,weathered,opts)
const CityKit = preload("res://scripts/city_kit.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const WalkerOnly = preload("res://scripts/walker_only.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const PIECES := ["city_court","city_pyramid","city_hall"]
const NAMES := {"city_court":"Ballcourt coliseum","city_pyramid":"Temple pyramid","city_hall":"Sundered hall"}

# --- The numbers (the kit's) ----------------------------------------------------------
const SET_OFF := CityKit.SET_OFF
const CELL := CityKit.CELL
const COURSE := CityKit.COURSE
const LANE := CityKit.LANE
const STAND := CityKit.STAND
const GAP := CityKit.GAP
## A walker-only prism on a climb face (the pillar's: 1.2 m flat to flat,
## a top she stands on, STAND and more past the lip she climbs over).
const PRISM := 1.2
## The foundation under a piece's foot (m): its isle's flank into the haze.
const FOUNDATION := 60.0

# --- The court ----------------------------------------------------------------------------
## The alley between the taluds' feet: his lane and a set-off either side
## (12 m, the card's: he fits it with room to turn).
const ALLEY_HALF := (LANE+2.0*SET_OFF)*0.5
## The alley's length (six cells, the card's 3 to 6 BAY) and each end zone's
## (his lane deep): the I's crossbars, wider than the alley (no talud there).
const ALLEY_LEN := 6.0*CELL
const END_ZONE := LANE
## The talud: two set-offs high (out of a standing grab), pitched steeper
## than PilotMotor SLIDE_AUTO (44) by a margin, so it is never stood on: a
## face she surfs down into the alley.
const TALUD_H := 2.0*SET_OFF
const TALUD_PITCH := 55.0
## Its top's ledge (a set-off wide: hers, under his 2 m shelf).
const COURT_LEDGE := SET_OFF
## The tablero over it: a course (so the drop from the rim to the ledge is
## under the fall stun, 6 m).
const TABLERO := COURSE
## The rim's walk (m across) and the stands: rows a set-off high and deep
## (a grab each for her, a cascade he climbs past: under his shelf rule),
## up to his promenade (his lane wide), the stands' back stepping down to
## the court's foot in courses a set-off ledge apart.
const RIM_W := 1.5*SET_OFF
const ROWS := 4
const PROMENADE := LANE
const OUTER_COURSES := 3
## The rings: three a wall, a ring's centre ring radius and the stone's own
## radius (2.4 m across, a 1.2 m hole: the card's), hung off the end of a
## serpent beam from the rim, the ring's middle this far in front of the
## talud's foot (its root swings clear of the talud).
const RING_Z := [-2.0*CELL,0.0,2.0*CELL]
const RING_R := 0.9
const RING_THICK := 0.3
const RING_CLEAR := 0.6
const BEAM := Vector2(1.2,0.6)
## A ring's root: its knot at a standing walker's hands over the alley
## (SwingRope KNOT), so a run into it takes it.
const ROOT_KNOT := SwingRope.KNOT
## The ball's grave: an octagonal shaft through the alley's floor to the
## abyss (apothem m), a long jump across or a fall.
const SHAFT := 2.0

# --- The pyramid --------------------------------------------------------------------------
## Four tiers a course each (talud a set-off, `PYR_BATTER` out, then a plumb
## tablero), each tread his lane, the summit three cells half-side.
const TIERS := 4
const PYR_BATTER := 0.8
const TREAD := LANE
const SUMMIT_HALF := 3.0*CELL
## The shrine: its room's inside (two cells square, a course high), walls,
## its roof, the roof comb on it; its door (hers: under his 4.4 m width by
## far, a jog behind it so nothing sees or reaches in); its screen a set-off
## behind the door.
const SHRINE_IN := 2.0*CELL
const SHRINE_WALL := 1.2
const SHRINE_TALL := 2.0*COURSE
const SHRINE_ROOF := 1.2
const COMB := Vector3(2.0*CELL,4.0*SET_OFF,1.2)
const DOOR := Vector2(1.6,2.6)
## The shrine's middle, behind the summit's middle (its court in front his
## room to stand and look).
const SHRINE_Z := -6.0
## The kick chimneys: two plumb fins a slot apart (she kicks up between
## them; he is four times too wide), out from each tier's face.
const CHIMNEY := Vector3(1.8,0.9,2.4)

# --- The hall -----------------------------------------------------------------------------
## Pillars square (half a cell), a bay along a row (1.5 cells, the card's).
const PILLAR := 0.5*CELL
const BAY := 1.5*CELL
## The nave between the inner rows his lane; the side aisle between an
## inner and an outer row a slot only she fits (the card's 1.8 m: a kick
## chimney between two plumb faces).
const NAVE_HALF := LANE*0.5
const AISLE := 1.8
## Clear heights: the aisle's roof under his neck (he never fits under it),
## the nave's over his head worn whole (his eye is about 8.1 m), and four
## set-offs over the aisle's roof top (her glyph steps up an inner pillar).
const SLAB := 0.8
const AISLE_CLEAR := CELL
const NAVE_CLEAR := AISLE_CLEAR+SLAB+4.0*SET_OFF-SLAB
## Bays a half, the crack (a running jump for her, the card's), the low
## half's drop (a set-off) and drift across.
const HALL_BAYS := 3
const CRACK := 2.0*SET_OFF
const HALL_DROP := SET_OFF
const HALL_DRIFT := 1.1
## The hall's stylobate past its outer rows (m).
const HALL_MARGIN := 2.2

# --- Shared builders ----------------------------------------------------------------------

## The cover the city's walk tops wear: the flags' (`--ground=`), else grass
## under the underground look, nothing without it.
static func cover_kind() -> String:
	var args: Array = LaunchArgs.user_args()
	for a: String in args:
		if a.begins_with("--ground="): return GroundCover.asked()
	return "grass" if GroundCover.asked() != "" else ""

## An axis-aligned box's planes, `lo` to `hi`.
static func bx(lo: Vector3, hi: Vector3) -> Array:
	return [Plane(Vector3.LEFT,-lo.x),Plane(Vector3.RIGHT,hi.x),Plane(Vector3.DOWN,-lo.y),Plane(Vector3.UP,hi.y),Plane(Vector3.FORWARD,-lo.z),Plane(Vector3.BACK,hi.z)]

static func _typed(planes: Array) -> Array[Plane]:
	var out: Array[Plane] = []
	for p: Plane in planes: out.append(p)
	return out

## A collision column (the body's, or `into`): the box `lo` to `hi`, grown
## CityKit.SEAM across into its neighbours (a ray down a seam where two
## boxes only touch slips through: she fell through one).
static func column(b: CityKit.Piece, lo: Vector3, hi: Vector3, into: CollisionObject3D = null) -> void:
	var g := Vector3(CityKit.SEAM,0.0,CityKit.SEAM)
	b.walk_box(Transform3D(Basis.IDENTITY,(lo+hi)*0.5),(hi-lo)*0.5+g,into)

## A drawn block (chipped by the wear), no collision.
static func draw(b: CityKit.Piece, planes: Array, chips := 0.6, mesher: Stone.Mesher = null) -> void:
	b.block(planes,false,null,chips,mesher)

## A walk top, its area for cover and its cover laid (`tufts` 0 for a skin).
static func top(b: CityKit.Piece, kind: String, r: Rect2, y: float, covers: Array) -> void:
	b.rect_area(kind,r,y)
	covers.append([r,y])

## The cover on every walk top gathered (nothing without the look).
static func lay_cover(b: CityKit.Piece, covers: Array, seed_value: int, opts: Dictionary) -> void:
	if not bool(opts.get("cover",true)): return
	var kind := str(opts.get("ground",cover_kind()))
	if kind == "": return
	var i := 0
	for c: Array in covers:
		i += 1
		var r: Rect2 = c[0]
		if r.size.x < 0.6 or r.size.y < 0.6: continue
		GroundCover.cover(b.root,r.grow(-0.1),kind,float(c[1]),seed_value*31+i,{"tufts":0.7 if r.size.x > 3.0 and r.size.y > 3.0 else 0.0,"fade":0.5})

## A battered foundation under the rect `r` (x, z) from `y` down `deep`:
## drawn only, in courses stepping in a little going down (the isle's
## flank); `hole` (x, z) left open through it (a shaft).
static func foundation(b: CityKit.Piece, r: Rect2, y: float, deep: float, hole := Rect2()) -> void:
	var courses := 4
	var each := deep/courses
	var lean := each*0.22
	for k in courses:
		var y1 := y-k*each
		var y0 := y1-each
		var rr := r.grow(-each*0.22*k-0.3*k*k)
		var planes: Array = bx(Vector3(rr.position.x,y0,rr.position.y),Vector3(rr.end.x,y1,rr.end.y))
		for d: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var edge := Vector3(rr.end.x if d.x > 0.0 else rr.position.x,y1,rr.end.y if d.z > 0.0 else rr.position.y)
			var n := Vector3(d.x,-lean/each,d.z).normalized()
			planes.append(Plane(n,n.dot(edge)))
		if hole.size.x <= 0.0:
			b.block(planes,false,null,0.3)
			continue
		# Round the hole: before it, after it, either side of it.
		for cut: Array in [[Plane(Vector3.BACK,hole.position.y)],[Plane(Vector3.FORWARD,-hole.end.y)],
				[Plane(Vector3.RIGHT,hole.position.x),Plane(Vector3.FORWARD,-hole.position.y),Plane(Vector3.BACK,hole.end.y)],
				[Plane(Vector3.LEFT,-hole.end.x),Plane(Vector3.FORWARD,-hole.position.y),Plane(Vector3.BACK,hole.end.y)]]:
			b.block(planes+cut,false,null,0.3)

## A walker-only prism (a glyph block standing against a face): its foot
## `foot` y, its top `top_y`, at (x, z) `at`, PRISM square; drawn and put in
## `walker` (a walker-only body).
static func prism(b: CityKit.Piece, at: Vector2, foot: float, top_y: float, walker: StaticBody3D) -> void:
	var h := PRISM*0.5
	var planes: Array = Stone.box(Transform3D(Basis.IDENTITY,Vector3(at.x,(foot+top_y)*0.5,at.y)),Vector3(h,(top_y-foot)*0.5,h),0.08)
	b.block(planes,true,walker,0.3,null,[CityKit.over(foot)])
	# The glyph on its face toward the open.
	b.runes(Vector3(at.x-h*0.8,top_y-0.95,at.y+h+0.005),Vector3(at.x+h*0.8,top_y-0.95,at.y+h+0.005),Vector3.UP,Vector3.BACK,0.7)

static func walker_body(b: CityKit.Piece, node_name: String) -> StaticBody3D:
	var w := StaticBody3D.new()
	w.name = node_name
	WalkerOnly.mark(w)
	b.root.add_child(w)
	return w

## A smooth torus into `m` (painterly, not faceted: normals per vertex): its
## middle `c`, its hole's axis `axis` (unit), ring radius `R`, stone radius `r`.
static func torus(m: Stone.Mesher, c: Vector3, axis: Vector3, R: float, r: float, major := 24, minor := 10) -> void:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := axis.cross(u).normalized()
	m._centre = c
	m._foot = c.y-R-r
	m._tone = 1.0
	var pts: Array = []
	var nrm: Array = []
	for i in major+1:
		var a := TAU*i/major
		var radial := u*cos(a)+w*sin(a)
		var row: Array = []
		var nrow: Array = []
		for j in minor+1:
			var t := TAU*j/minor
			var n := radial*cos(t)+axis*sin(t)
			row.append(c+radial*R+n*r)
			nrow.append(n)
		pts.append(row)
		nrm.append(nrow)
	for i in major:
		for j in minor:
			var quad := [pts[i][j],pts[i+1][j],pts[i+1][j+1],pts[i][j+1]]
			var qn := [nrm[i][j],nrm[i+1][j],nrm[i+1][j+1],nrm[i][j+1]]
			_smooth_tri(m,quad[0],quad[1],quad[2],qn[0],qn[1],qn[2])
			_smooth_tri(m,quad[0],quad[2],quad[3],qn[0],qn[2],qn[3])

## One triangle, its normals per vertex, wound to face along them.
static func _smooth_tri(m: Stone.Mesher, a: Vector3, b2: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face := (b2-a).cross(c-a)
	var order := [[a,na],[c,nc],[b2,nb]] if face.dot(na+nb+nc) > 0.0 else [[a,na],[b2,nb],[c,nc]]
	for e: Array in order:
		var p: Vector3 = e[0]
		var n: Vector3 = e[1]
		var d: Array = m._dress(p,n)
		m.v.append(p)
		m.n.append(n)
		m.col.append(d[0])
		m.uv.append(d[1])
		m.uv2.append(d[2])

## A piece by its id.
static func piece(id: String, seed_value := 1, weathered := 0.4, opts := {}) -> Node3D:
	match id:
		"city_court": return court(seed_value,weathered,opts)
		"city_pyramid": return pyramid(seed_value,weathered,opts)
		"city_hall": return hall(seed_value,weathered,opts)
	push_error("city landmarks: no piece %s" % id)
	return null

## A piece stood in `parent` at `xform`.
static func stand(id: String, parent: Node3D, xform: Transform3D, seed_value := 1, weathered := 0.4, opts := {}) -> Node3D:
	var n := piece(id,seed_value,weathered,opts)
	if n == null: return null
	parent.add_child(n)
	n.transform = xform
	return n

## A piece's walked tops in the world (CityKit's).
static func walk_areas(p: Node3D, kinds: Array = []) -> Array:
	return CityKit.walk_areas(p,kinds)

# --- The ballcourt coliseum ---------------------------------------------------------------

## The ballcourt (city_court). y 0 the alley's floor (the ground it meets at
## its open +Z end); the alley along Z, its -Z end zone broken off over the
## abyss. Opts: `foundation` (FOUNDATION), `fires` (true: a cresset at each
## of the promenade's -Z corners), `cover`, `ground`.
## His: walks the alley and its end zones (12 m), climbs the stands' back
## (three courses, 14.4 m) and walks the promenade (his lane), hunts from it
## and drops into the alley; never on a ledge, a ring or a beam.
## Hers: the rings' roots (run into one, swing along the wall, chain to the
## next), the talud (slide it into the alley), the slumped facing at each
## ledge's +Z end (two set-offs up onto the ledge), the walker-only prisms up
## the end zones' walls to the rim, the beams out from the rim over the
## alley, the stands' rows (a grab each), the prisms up the stands' back.
static func court(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityCourt",seed_value,weathered)
	var deep: float = opts.get("foundation",FOUNDATION)
	var covers: Array = []
	var walker := walker_body(b,"WalkerOnly")
	var run := TALUD_H/tan(deg_to_rad(TALUD_PITCH))
	var x_ledge := ALLEY_HALF+run
	var x_tab := x_ledge+COURT_LEDGE
	var rim_y := TALUD_H+TABLERO
	var x_rows := x_tab+RIM_W
	var prom_y := rim_y+ROWS*SET_OFF
	var x_prom := x_rows+(ROWS-1)*SET_OFF
	var x_back := x_prom+PROMENADE
	var x_outer := x_back+(OUTER_COURSES-1)*SET_OFF
	var x_apron := x_outer+CELL
	var half_len := ALLEY_LEN*0.5
	var z_end := half_len+END_ZONE
	var bottom := -deep
	var sq := ALLEY_HALF
	# The floor round the shaft: eight wedges between its octagon and the
	# alley's middle square, drawn down the foundation (the shaft's wall).
	for i in 8:
		var a := TAU*i/8.0
		var n := Vector3(sin(a),0.0,cos(a))
		var a0 := a-PI/8.0-0.01
		var a1 := a+PI/8.0+0.01
		var t0 := Vector3(cos(a0),0.0,-sin(a0))
		var t1 := Vector3(cos(a1),0.0,-sin(a1))
		var planes: Array = [Plane(-n,-SHAFT),Plane(-t0,0.0),Plane(t1,0.0),Plane(Vector3.LEFT,sq),Plane(Vector3.RIGHT,sq),Plane(Vector3.FORWARD,sq),Plane(Vector3.BACK,sq)]
		draw(b,planes+[Plane(Vector3.UP,0.0),Plane(Vector3.DOWN,deep*0.6)],0.6)
		b.hull(Geometry3D.compute_convex_mesh_points(_typed(planes+[Plane(Vector3.UP,0.0),Plane(Vector3.DOWN,-bottom)])))
	# The shaft's lip: a ring of pale kerb stones round the octagon.
	for i in 8:
		var a := TAU*i/8.0
		var at := Vector3(sin(a),0.0,cos(a))*(SHAFT+0.35)+Vector3.UP*0.06
		b.m.solid(Stone.box(Transform3D(Basis(Vector3.UP,a),at),Vector3(SHAFT*tan(PI/8.0)+0.12,0.08,0.35),0.04),NAN,1.25)
	for s: float in [-1.0,1.0]:
		# The alley past the shaft's square, to the end zone.
		var z0 := sq if s > 0.0 else -half_len
		var z1 := half_len if s > 0.0 else -sq
		draw(b,bx(Vector3(-ALLEY_HALF,-0.9,z0),Vector3(ALLEY_HALF,0.0,z1)),0.3)
		column(b,Vector3(-ALLEY_HALF,bottom,z0),Vector3(ALLEY_HALF,0.0,z1))
		top(b,"alley",Rect2(-ALLEY_HALF,z0,ALLEY_HALF*2.0,z1-z0),0.0,covers)
		# The end zone, out to the tablero line (the I's crossbar).
		var e0 := half_len if s > 0.0 else -z_end
		var e1 := z_end if s > 0.0 else -half_len
		draw(b,bx(Vector3(-x_tab,-0.9,e0),Vector3(x_tab,0.0,e1)),0.5)
		column(b,Vector3(-x_tab,bottom,e0),Vector3(x_tab,0.0,e1))
		top(b,"end_zone",Rect2(-x_tab,e0,x_tab*2.0,e1-e0),0.0,covers)
	top(b,"alley",Rect2(-ALLEY_HALF,-sq,ALLEY_HALF-SHAFT-0.6,sq*2.0),0.0,covers)
	top(b,"alley",Rect2(SHAFT+0.6,-sq,ALLEY_HALF-SHAFT-0.6,sq*2.0),0.0,covers)
	# The front apron (meets the ground at the gate).
	draw(b,bx(Vector3(-x_apron,-0.9,z_end),Vector3(x_apron,0.0,z_end+CELL)),0.3)
	column(b,Vector3(-x_apron,bottom,z_end),Vector3(x_apron,0.0,z_end+CELL))
	top(b,"apron",Rect2(-x_apron,z_end,x_apron*2.0,CELL),0.0,covers)
	# The long walls, either side, each strip a column from the foot.
	var rings: Array = []
	var ropes: Array = []
	for side: float in [-1.0,1.0]:
		var out := Vector3(-side,0.0,0.0)
		var sx := func(x0: float, x1: float) -> Vector2:
			return Vector2(minf(side*x0,side*x1),maxf(side*x0,side*x1))
		# The talud (along the alley only): a sloped face, its collision the
		# same hull from the foot (never stood on: steeper than SLIDE_AUTO).
		var tx: Vector2 = sx.call(ALLEY_HALF,x_ledge)
		var tn := (out*TALUD_H+Vector3.UP*run).normalized()
		var talud: Array = [Plane(Vector3.LEFT,-tx.x),Plane(Vector3.RIGHT,tx.y),Plane(Vector3.FORWARD,half_len),Plane(Vector3.BACK,half_len),Plane(Vector3.UP,TALUD_H),Plane(tn,tn.dot(Vector3(side*ALLEY_HALF,0.0,0.0)))]
		draw(b,talud+[Plane(Vector3.DOWN,0.9)],0.5)
		b.hull(Geometry3D.compute_convex_mesh_points(_typed(talud+[Plane(Vector3.DOWN,-bottom)])))
		# Its polished slabs: a carved band along its foot.
		var up_slope := (Vector3.UP*TALUD_H-out*run).normalized()
		b.runes(Vector3(side*(ALLEY_HALF+0.3),0.45,half_len-0.6),Vector3(side*(ALLEY_HALF+0.3),0.45,-half_len+0.6),up_slope,tn,0.7)
		# The ledge (hers).
		var lx: Vector2 = sx.call(x_ledge,x_tab)
		draw(b,bx(Vector3(lx.x,0.0,-half_len),Vector3(lx.y,TALUD_H,half_len)),0.6)
		column(b,Vector3(lx.x,bottom,-half_len),Vector3(lx.y,TALUD_H,half_len))
		top(b,"ledge",Rect2(lx.x,-half_len,lx.y-lx.x,ALLEY_LEN),TALUD_H,covers)
		# The tablero and rim, the wall's whole length.
		var wx: Vector2 = sx.call(x_tab,x_rows)
		for seg: Array in [[-z_end,-half_len,0.0],[-half_len,half_len,TALUD_H],[half_len,z_end,0.0]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			draw(b,bx(Vector3(wx.x,0.0,z0),Vector3(wx.y,rim_y,z1)),0.8)
			var face_x := side*x_tab-side*0.005
			b.runes(Vector3(face_x,rim_y-SET_OFF,z0+0.6),Vector3(face_x,rim_y-SET_OFF,z1-0.6),Vector3.UP,out,1.0)
		column(b,Vector3(wx.x,bottom,-z_end),Vector3(wx.y,rim_y,z_end))
		top(b,"rim",Rect2(wx.x,-z_end,wx.y-wx.x,z_end*2.0),rim_y,covers)
		# The rows (a set-off rise and tread) up to the promenade.
		for k in range(1,ROWS):
			var rx: Vector2 = sx.call(x_rows+(k-1)*SET_OFF,x_rows+k*SET_OFF)
			var ry := rim_y+k*SET_OFF
			draw(b,bx(Vector3(rx.x,0.0,-z_end),Vector3(rx.y,ry,z_end)),0.7)
			column(b,Vector3(rx.x,bottom,-z_end),Vector3(rx.y,ry,z_end))
			top(b,"row",Rect2(rx.x,-z_end,rx.y-rx.x,z_end*2.0),ry,covers)
		# The promenade (his lane: the tiers he hunts from).
		var px: Vector2 = sx.call(x_prom,x_back)
		draw(b,bx(Vector3(px.x,0.0,-z_end),Vector3(px.y,prom_y,z_end)),0.6)
		column(b,Vector3(px.x,bottom,-z_end),Vector3(px.y,prom_y,z_end))
		top(b,"promenade",Rect2(px.x,-z_end,px.y-px.x,z_end*2.0),prom_y,covers)
		# The back: courses stepping out a set-off ledge each, down to the
		# foot (he climbs it; her prisms climb it near the +Z end).
		for c in range(OUTER_COURSES):
			var y1 := prom_y-c*COURSE
			var y0 := y1-COURSE
			var face := x_back+c*SET_OFF
			if c > 0:
				var cx: Vector2 = sx.call(face-SET_OFF,face)
				draw(b,bx(Vector3(cx.x,0.0,-z_end),Vector3(cx.y,y1,z_end)),0.8)
				column(b,Vector3(cx.x,bottom,-z_end),Vector3(cx.y,y1,z_end))
				top(b,"back_ledge",Rect2(cx.x,-z_end,cx.y-cx.x,z_end*2.0),y1,covers)
			var fx := side*face+side*0.005
			b.runes(Vector3(fx,y0+SET_OFF*1.4,z_end-0.8),Vector3(fx,y0+SET_OFF*1.4,-z_end+0.8),Vector3.UP,-out,1.0)
			for k: int in [1,2]:
				var zz := z_end-4.0-(1.4 if k == 2 else 0.0)
				prism(b,Vector2(side*(face+PRISM*0.5),zz),y0,y0+k*SET_OFF,walker)
		# The apron round the court's foot.
		var ax: Vector2 = sx.call(x_outer,x_apron)
		draw(b,bx(Vector3(ax.x,-0.9,-z_end),Vector3(ax.y,0.0,z_end)),0.3)
		column(b,Vector3(ax.x,bottom,-z_end),Vector3(ax.y,0.0,z_end))
		top(b,"apron",Rect2(ax.x,-z_end,ax.y-ax.x,z_end*2.0),0.0,covers)
		# The slumped facing at the ledge's +Z end: a set-off block from the
		# end zone's floor, the ledge a set-off over it.
		draw(b,Stone.box(Transform3D(Basis.IDENTITY,Vector3((lx.x+lx.y)*0.5,SET_OFF*0.5,half_len+SET_OFF*0.5)),Vector3((lx.y-lx.x)*0.5,SET_OFF*0.5,SET_OFF*0.5),0.12),0.9)
		column(b,Vector3(lx.x,bottom,half_len),Vector3(lx.y,SET_OFF,half_len+SET_OFF))
		top(b,"slump",Rect2(lx.x,half_len,lx.y-lx.x,SET_OFF),SET_OFF,covers)
		# Her prisms up the end zones' walls to the rim: a stair of columns
		# a set-off apart, side by side along the wall.
		for zs: float in [1.0,-1.0]:
			var steps := int(roundf(rim_y/SET_OFF))-1
			for k in range(1,steps+1):
				var zz := zs*(half_len+END_ZONE*0.5+(k-2.5)*(PRISM+0.3))
				prism(b,Vector2(side*(x_tab-PRISM*0.5),zz),0.0,k*SET_OFF,walker)
		# The rings: a serpent beam out from the rim (its top the rim's, a
		# perch over the alley), a ring hung in its head's jaws, a root from
		# the ring's hole down to her hands.
		for rz: float in RING_Z:
			var ring_x := side*(ALLEY_HALF-RING_CLEAR)
			var ring_y := ring_height()
			var bxx: Vector2 = sx.call(ALLEY_HALF-RING_CLEAR-0.5,x_tab)
			b.block(bx(Vector3(bxx.x,rim_y-BEAM.y,rz-BEAM.x*0.5),Vector3(bxx.y,rim_y,rz+BEAM.x*0.5)),true,null,0.4)
			top(b,"beam",Rect2(bxx.x,rz-BEAM.x*0.5,bxx.y-bxx.x,BEAM.x),rim_y,covers)
			var head := Stone.box(Transform3D(Basis.IDENTITY,Vector3(ring_x,rim_y+0.15,rz)),Vector3(0.75,0.45,0.8),0.22)
			b.block(head,true,null,0.4,null,[CityKit.over(rim_y-0.3)])
			for jz: float in [-1.0,1.0]:
				var jaw := Stone.box(Transform3D(Basis.IDENTITY,Vector3(ring_x,rim_y-BEAM.y-0.25,rz+jz*(RING_THICK+0.12))),Vector3(0.45,0.35,0.1),0.05)
				b.block(jaw,false,null,0.2)
				var eye := Stone.box(Transform3D(Basis.IDENTITY,Vector3(ring_x-side*0.55,rim_y+0.28,rz+jz*0.55)),Vector3(0.12,0.1,0.12),0.03)
				b.m.solid(eye,NAN,0.5)
			var c := Vector3(ring_x,ring_y,rz)
			torus(b.m,c,Vector3.RIGHT,RING_R,RING_THICK)
			for i in 12:
				var a0 := TAU*i/12.0
				var a1 := TAU*(i+1)/12.0
				var pts := PackedVector3Array()
				for a: float in [a0,a1]:
					for rr: float in [RING_R-RING_THICK,RING_R+RING_THICK]:
						for dx: float in [-RING_THICK,RING_THICK]:
							pts.append(c+Vector3(dx,cos(a)*rr,sin(a)*rr))
				b.hull(pts)
			rings.append(c)
			var anchor := c+Vector3.DOWN*(RING_R-RING_THICK)
			ropes.append({"anchor":anchor,"length":anchor.y-ROOT_KNOT})
	# The -Z end zone breaks off over the abyss in a ragged lip of tipped
	# slabs; fallen blocks off the stands' broken ends.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*13+5
	for i in 7:
		var x := lerpf(-x_tab+1.2,x_tab-1.2,(i+0.5)/7.0)
		var tip := Basis(Vector3.RIGHT,rng.randf_range(-0.45,-0.12))*Basis(Vector3.UP,rng.randf_range(-0.2,0.2))
		var at := Vector3(x,-0.7-rng.randf_range(0.0,0.8),-z_end-rng.randf_range(0.3,1.2))
		draw(b,Stone.box(Transform3D(tip,at),Vector3(rng.randf_range(1.0,1.6),0.45,rng.randf_range(0.6,1.1)),0.1),1.2)
	for side: float in [-1.0,1.0]:
		for k in 4:
			var at := Vector3(side*(x_rows+2.0+k*5.0),rim_y+k*1.6-2.4,-z_end-0.9)
			draw(b,Stone.box(Transform3D(Basis(Vector3.UP,rng.randf_range(-0.4,0.4))*Basis(Vector3.RIGHT,rng.randf_range(-0.3,0.0)),at),Vector3(1.6,1.0+k*0.3,1.0),0.15),1.4)
	if deep > 0.0:
		foundation(b,Rect2(-x_apron,-z_end,x_apron*2.0,z_end*2.0+CELL),-0.9,deep,Rect2(-sq,-sq,sq*2.0,sq*2.0))
	var fires: Array = []
	for side: float in [-1.0,1.0]:
		var at := Vector3(side*(x_prom+PROMENADE*0.5),prom_y,-z_end+3.0)
		b.cresset(at)
		fires.append(at)
	b.meta.ports["gate"] = Vector3(0.0,0.0,z_end+CELL)
	b.meta.ports["alley"] = Vector3(0.0,0.0,0.0)
	b.meta.ports["shaft"] = Vector3.ZERO
	b.meta.ports["promenade_l"] = Vector3(-(x_prom+PROMENADE*0.5),prom_y,0.0)
	b.meta.ports["promenade_r"] = Vector3(x_prom+PROMENADE*0.5,prom_y,0.0)
	b.meta.ports["ledge_l"] = Vector3(-(x_ledge+x_tab)*0.5,TALUD_H,half_len-1.0)
	b.meta.ports["ledge_r"] = Vector3((x_ledge+x_tab)*0.5,TALUD_H,half_len-1.0)
	b.meta.ports["slump_l"] = Vector3(-(x_ledge+x_tab)*0.5,0.0,half_len+SET_OFF+1.2)
	b.meta.ports["back_prisms_r"] = Vector3(x_outer+1.5,0.0,z_end-4.7)
	b.meta.ports["end_prisms_r"] = Vector3(x_tab-PRISM-1.0,0.0,half_len+END_ZONE*0.5)
	b.meta.ports["abyss_end"] = Vector3(0.0,0.0,-z_end)
	b.meta.ports["rings"] = rings
	b.meta["ropes"] = ropes
	b.meta.his = {"walks":"the alley (%.1f m clear) and end zones; the promenade (%.1f m) along the stands" % [ALLEY_HALF*2.0,PROMENADE],
		"climbs":"the stands' back (%.1f m, three courses) and rows; the end walls (%.1f m)" % [prom_y,rim_y],
		"drops":"from the promenade into the alley (%.1f m)" % prom_y,"never":"a ledge (%.1f m), a ring, a beam (%.1f m)" % [COURT_LEDGE,BEAM.x]}
	b.meta["sizes"] = {"alley":ALLEY_HALF*2.0,"length":ALLEY_LEN,"end_zone":END_ZONE,"talud":[TALUD_H,run,TALUD_PITCH],"ledge":COURT_LEDGE,"rim":rim_y,
		"rows":[ROWS-1,SET_OFF],"promenade":[prom_y,PROMENADE],"width":2.0*x_apron,"long":2.0*z_end+CELL,
		"ring":[ring_height(),RING_R+RING_THICK,RING_R-RING_THICK],"root":float((ropes[0] as Dictionary).length),"shaft":SHAFT*2.0}
	var root := b.finish()
	if bool(opts.get("fires",true)):
		var i := 0
		for at: Vector3 in fires:
			CityFires.cresset(root,Transform3D(Basis.IDENTITY,at),{"size":"cresset","seed":seed_value*7+i,"name":"CourtCresset%d" % i,"lit":bool(opts.get("lit",false))})
			i += 1
	lay_cover(b,covers,seed_value,opts)
	return root

## A ring's middle over the alley (m).
static func ring_height() -> float:
	return TALUD_H+TABLERO-BEAM.y-RING_R-RING_THICK

# --- The temple pyramid -------------------------------------------------------------------

## The temple pyramid (city_pyramid). y 0 its foot; its stair's foot toward
## +Z (`ports.stair_foot`). Opts: `foundation`, `fault` (the stair's landing
## that breaks, 2; 0 none), `fires` (true: the summit's cresset), `lit`,
## `cover`, `ground`.
## His: the stair (every flight and landing; its fault drops him into the
## chamber), every tread (his lane round each tier), the summit's court in
## front of the shrine; climbs any tier's face. Never in the shrine: its
## door is hers; inside, the floor, screen and niche are walker-only.
## Hers: the stair (run it, slide the serpent's crest), the west face's
## walker-only prism chain (two prisms and the lip a tier), the east face's
## kick chimneys (two fins a slot apart a tier), the shrine (a safe room),
## the cresset (light it, and every Olmec comes to look).
static func pyramid(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityPyramid",seed_value,weathered)
	var deep: float = opts.get("foundation",FOUNDATION)
	var covers: Array = []
	var walker := walker_body(b,"WalkerOnly")
	var bottom := -deep
	var fault := int(opts.get("fault",2))
	# The stair: its summit landing the summit court's front, its flanks
	# off (the tiers are its flank).
	var stair := CityKit.stair(seed_value+1,weathered,{"flights":TIERS,"flank":0.0,"heads":true,"fault":fault})
	var stair_len := float(stair.get_meta("length"))
	var notch := float(stair.get_meta("width"))*0.5
	var stair_z := SUMMIT_HALF-CityKit.LANDING+stair_len
	stair.name = "Stair"
	b.root.add_child(stair)
	stair.position = Vector3(0.0,0.0,stair_z)
	# Each tier's half side at its talud's foot (h) and at its tablero (c,
	# where it collides plumb: the talud is a sloped hull in front of it).
	var h: Array = []
	var c: Array = []
	for k in range(TIERS):
		h.append(SUMMIT_HALF+(TIERS-1-k)*TREAD)
		c.append(float(h[k])-PYR_BATTER)
	var summit_y := TIERS*COURSE
	var summit_cut := SUMMIT_HALF-CityKit.LANDING
	for k in range(TIERS):
		var hk: float = h[k]
		var ck: float = c[k]
		var y0 := k*COURSE
		var y1 := y0+COURSE
		var top_tier := k == TIERS-1
		var cn: float = c[k+1] if not top_tier else 0.0
		var front_cut: float = summit_cut if top_tier else cn
		# Drawn: three blocks round the stair's notch (back, front left,
		# front right), the talud leaning on the outer faces.
		for p: Array in [[-hk,hk,-hk,front_cut],[-hk,-notch,front_cut,hk],[notch,hk,front_cut,hk]]:
			var x0: float = p[0]
			var x1: float = p[1]
			var z0: float = p[2]
			var z1: float = p[3]
			var tal: Array = bx(Vector3(x0,y0-0.3,z0),Vector3(x1,y0+SET_OFF,z1))
			var tab: Array = bx(Vector3(x0,y0+SET_OFF,z0),Vector3(x1,y1,z1))
			for f: Array in [[Vector3.LEFT,x0 <= -hk+0.01],[Vector3.RIGHT,x1 >= hk-0.01],[Vector3.FORWARD,z0 <= -hk+0.01],[Vector3.BACK,z1 >= hk-0.01]]:
				if not bool(f[1]): continue
				var d: Vector3 = f[0]
				var lean := (d*SET_OFF+Vector3.UP*PYR_BATTER).normalized()
				tal.append(Plane(lean,lean.dot(d*hk+Vector3.UP*y0)))
				tab.append(Plane(d,ck))
			draw(b,tal,0.6)
			draw(b,tab,0.9)
		# Collided: the ring this tier adds past the next tier's tablero
		# (or the summit), plumb at its own tablero, round the notch.
		var parts: Array = []
		if top_tier:
			parts = [[-ck,ck,-ck,summit_cut],[-ck,-notch,summit_cut,ck],[notch,ck,summit_cut,ck]]
		else:
			parts = [[-ck,ck,-ck,-cn],[-ck,-cn,-cn,cn],[cn,ck,-cn,cn],[-ck,-notch,cn,ck],[notch,ck,cn,ck]]
		for p: Array in parts:
			column(b,Vector3(float(p[0]),bottom,float(p[2])),Vector3(float(p[1]),y1,float(p[3])))
		# The talud: a sloped hull on each outer face, on the tread under it.
		for d: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var lean := (d*SET_OFF+Vector3.UP*PYR_BATTER).normalized()
			var base: Array = [Plane(lean,lean.dot(d*hk+Vector3.UP*y0)),Plane(-d,-ck),Plane(Vector3.UP,y0+SET_OFF),CityKit.over(y0)]
			var across := Vector3(d.z,0.0,d.x).abs()
			if d == Vector3.BACK:
				for s: float in [-1.0,1.0]:
					var lo := minf(s*notch,s*hk)
					var hi := maxf(s*notch,s*hk)
					b.hull(Geometry3D.compute_convex_mesh_points(_typed(base+[Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi)])))
			else:
				b.hull(Geometry3D.compute_convex_mesh_points(_typed(base+[Plane(-across,hk),Plane(across,hk)])))
		# Walk tops: the tread round the next tier (his lane).
		if not top_tier:
			var hn: float = h[k+1]
			top(b,"tread",Rect2(-ck,-ck,ck*2.0,ck-hn),y1,covers)
			top(b,"tread",Rect2(-ck,-hn,ck-hn,hn*2.0),y1,covers)
			top(b,"tread",Rect2(hn,-hn,ck-hn,hn*2.0),y1,covers)
			top(b,"tread",Rect2(-ck,hn,ck-notch,ck-hn),y1,covers)
			top(b,"tread",Rect2(notch,hn,ck-notch,ck-hn),y1,covers)
		# The tablero's glyph band on each outer face.
		var band := y0+SET_OFF+COURSE*0.25
		var fh := ck+0.005
		b.runes(Vector3(-fh,band,hk-1.0),Vector3(-fh,band,-hk+1.0),Vector3.UP,Vector3.LEFT,1.2)
		b.runes(Vector3(fh,band,-hk+1.0),Vector3(fh,band,hk-1.0),Vector3.UP,Vector3.RIGHT,1.2)
		b.runes(Vector3(hk-1.0,band,-fh),Vector3(-hk+1.0,band,-fh),Vector3.UP,Vector3.FORWARD,1.2)
		for s: float in [-1.0,1.0]:
			b.runes(Vector3(s*(hk-1.0),band,fh),Vector3(s*(notch+0.8),band,fh),Vector3.UP,Vector3.BACK,1.2)
		# Her grab chain up the west face: two walker-only prisms against
		# the tablero, standing on the tread (or the apron), then its lip.
		for j: int in [1,2]:
			var zz := 4.0+(1.4 if j == 2 else 0.0)
			prism(b,Vector2(-(ck+PRISM*0.5),zz),y0,y0+j*SET_OFF,walker)
		# The kick chimney up the east face: two plumb fins a slot apart out
		# from the tablero, standing on the tread (GAP over it).
		for s: float in [-1.0,1.0]:
			var fz := -4.0+s*(CHIMNEY.x+CHIMNEY.y)*0.5
			var fin := bx(Vector3(ck-0.1,y0,fz-CHIMNEY.y*0.5),Vector3(ck+CHIMNEY.z,y1-0.05,fz+CHIMNEY.y*0.5))
			b.block(fin,true,null,0.3,null,[CityKit.over(y0)])
	var court_front := SHRINE_Z+SHRINE_IN*0.5+SHRINE_WALL
	top(b,"summit_court",Rect2(-SUMMIT_HALF+PYR_BATTER,court_front,SUMMIT_HALF-PYR_BATTER-notch,SUMMIT_HALF-PYR_BATTER-court_front),summit_y,covers)
	top(b,"summit_court",Rect2(notch,court_front,SUMMIT_HALF-PYR_BATTER-notch,SUMMIT_HALF-PYR_BATTER-court_front),summit_y,covers)
	# The shrine.
	shrine(b,Vector3(0.0,summit_y,SHRINE_Z),walker)
	# The platform it stands on (its apron), out past the stair's foot.
	var c0: float = c[0]
	var h0: float = h[0]
	var plat := Rect2(-h0-CELL,-h0-CELL,(h0+CELL)*2.0,h0+CELL+stair_z+CELL)
	var apron: Array = [[plat.position.x,-c0,plat.position.y,plat.end.y],[c0,plat.end.x,plat.position.y,plat.end.y],
		[-c0,c0,plat.position.y,-c0],[-c0,-notch,c0,plat.end.y],[notch,c0,c0,plat.end.y],[-notch,notch,stair_z,plat.end.y]]
	for a: Array in apron:
		var x0: float = a[0]
		var x1: float = a[1]
		var z0: float = a[2]
		var z1: float = a[3]
		draw(b,bx(Vector3(x0,-0.9,z0),Vector3(x1,0.0,z1)),0.3)
		column(b,Vector3(x0,bottom,z0),Vector3(x1,0.0,z1))
		top(b,"apron",Rect2(x0,z0,x1-x0,z1-z0),0.0,covers)
	# Under the stair where it stands out from the tiers.
	column(b,Vector3(-notch,bottom,c0),Vector3(notch,-GAP,stair_z))
	if deep > 0.0: foundation(b,plat,-0.9,deep)
	var fire_at := Vector3(SUMMIT_HALF-PYR_BATTER-3.0,summit_y,SUMMIT_HALF-PYR_BATTER-3.0)
	b.cresset(fire_at)
	b.meta.ports["stair_foot"] = Vector3(0.0,0.0,stair_z+CityKit.HEAD_LENGTH+2.0)
	b.meta.ports["summit"] = Vector3(0.0,summit_y,SUMMIT_HALF-CityKit.LANDING*0.5)
	b.meta.ports["door"] = Vector3(0.0,summit_y,court_front+0.6)
	b.meta.ports["sanctum"] = Vector3(0.0,summit_y+0.12,SHRINE_Z-SHRINE_IN*0.5+1.6)
	b.meta.ports["chain_foot"] = Vector3(-c0-PRISM-1.4,0.0,4.7)
	b.meta.ports["chimney_foot"] = Vector3(c0+CHIMNEY.z*0.5,0.0,-4.0)
	b.meta.ports["fire"] = fire_at
	b.meta.ports["treads"] = c
	b.meta.his = {"walks":"the stair (%.1f m) and every tread (%.1f m)" % [LANE,TREAD-PYR_BATTER],"climbs":"any tier's face (%.1f m)" % COURSE,
		"never":"the shrine: its door %.1f x %.1f m" % [DOOR.x,DOOR.y],"breaks":"the stair's fault landing" if fault > 0 else "nothing"}
	b.meta["sizes"] = {"tiers":[TIERS,COURSE,TREAD],"base":h0*2.0,"summit":[summit_y,SUMMIT_HALF*2.0],"stair":[stair_len,notch*2.0,stair_z-h0],
		"shrine":[SHRINE_IN,SHRINE_TALL,SHRINE_WALL],"door":[DOOR.x,DOOR.y],"comb":[COMB.x,COMB.y],"chimney":[CHIMNEY.x,CHIMNEY.z],
		"top":summit_y+SHRINE_TALL+SHRINE_ROOF+COMB.y,"platform":[plat.size.x,plat.size.y]}
	b.meta.breaks = stair.get_meta("breaks",[])
	var root := b.finish()
	if bool(opts.get("fires",true)):
		CityFires.cresset(root,Transform3D(Basis.IDENTITY,fire_at),{"size":"cresset","seed":seed_value*5+1,"name":"SummitCresset","lit":bool(opts.get("lit",false))})
	lay_cover(b,covers,seed_value,opts)
	# The stair's own tops dressed too (its landings and summit).
	if bool(opts.get("cover",true)):
		var kind := str(opts.get("ground",cover_kind()))
		if kind != "":
			var i := 0
			for a: Dictionary in stair.get_meta("walk_areas",[]):
				if not String(a.kind) in ["landing","summit"]: continue
				var poly: PackedVector2Array = a.poly
				var r := Rect2(poly[0],Vector2.ZERO)
				for q in poly: r = r.expand(q)
				GroundCover.cover(stair,r.grow(-0.2),kind,float(a.y),seed_value*17+i,{"tufts":0.6,"fade":0.5})
				i += 1
	return root

## The summit shrine: its floor's middle at `at` (the summit's y), its door
## in the front (+Z) wall; walker-only inside (floor, screen, niche bench)
## so he reads none of it and sees nothing past the screen.
static func shrine(b: CityKit.Piece, at: Vector3, walker: StaticBody3D) -> void:
	var hi := SHRINE_IN*0.5
	var ho := hi+SHRINE_WALL
	var y0 := at.y
	var y1 := y0+SHRINE_TALL
	var o := at
	# The walls, the front split round the door.
	var walls: Array = [
		[Vector3(-ho,y0,-ho),Vector3(ho,y1,-hi)],
		[Vector3(-ho,y0,-hi),Vector3(-hi,y1,hi)],
		[Vector3(hi,y0,-hi),Vector3(ho,y1,hi)],
		[Vector3(-ho,y0,hi),Vector3(-DOOR.x*0.5,y1,ho)],
		[Vector3(DOOR.x*0.5,y0,hi),Vector3(ho,y1,ho)],
		[Vector3(-DOOR.x*0.5,y0+DOOR.y,hi),Vector3(DOOR.x*0.5,y1,ho)],
	]
	for w: Array in walls:
		var lo: Vector3 = w[0]
		var hh: Vector3 = w[1]
		draw(b,bx(o+Vector3(lo.x,0.0,lo.z)+Vector3.UP*(lo.y-o.y),o+Vector3(hh.x,0.0,hh.z)+Vector3.UP*(hh.y-o.y)),0.5)
		b.hull(Geometry3D.compute_convex_mesh_points(_typed(bx(o+Vector3(lo.x,lo.y-o.y+GAP,lo.z),o+Vector3(hh.x,hh.y-o.y,hh.z)))))
	# The lintel: a pale stone over the door (the tell, as the mouse run's).
	var lintel := bx(o+Vector3(-DOOR.x*0.5-0.5,DOOR.y,ho-0.05),o+Vector3(DOOR.x*0.5+0.5,DOOR.y+0.5,ho+0.25))
	b.m.solid(lintel,NAN,1.35)
	# The roof, a slab over the walls with a cornice, and the comb on it.
	var roof := bx(o+Vector3(-ho-0.4,SHRINE_TALL,-ho-0.4),o+Vector3(ho+0.4,SHRINE_TALL+SHRINE_ROOF,ho+0.4))
	b.block(roof,true,null,0.6,null,[CityKit.over(o.y+SHRINE_TALL)])
	var comb_y := SHRINE_TALL+SHRINE_ROOF
	# The comb: a pierced wall (two openings) along X on the roof's back half.
	var cz := -ho*0.35
	var cw := COMB.x*0.5
	var holes := [-cw*0.45,cw*0.45]
	var hole_w := 1.6
	var xs: Array = [-cw]
	for hx: float in holes:
		xs.append(hx-hole_w*0.5)
		xs.append(hx+hole_w*0.5)
	xs.append(cw)
	for i in range(0,xs.size(),2):
		var x0: float = xs[i]
		var x1: float = xs[i+1]
		var piece := bx(o+Vector3(x0,comb_y,cz-COMB.z*0.5),o+Vector3(x1,comb_y+COMB.y,cz+COMB.z*0.5))
		b.block(piece,true,null,0.7,null,[CityKit.over(o.y+comb_y)])
	for hx: float in holes:
		var cap := bx(o+Vector3(hx-hole_w*0.5,comb_y+COMB.y*0.62,cz-COMB.z*0.5),o+Vector3(hx+hole_w*0.5,comb_y+COMB.y,cz+COMB.z*0.5))
		b.block(cap,true,null,0.5,null,[CityKit.over(o.y+comb_y)])
	b.runes(o+Vector3(-cw+0.4,comb_y+COMB.y-1.2,cz+COMB.z*0.5+0.005),o+Vector3(cw-0.4,comb_y+COMB.y-1.2,cz+COMB.z*0.5+0.005),Vector3.UP,Vector3.BACK,0.9)
	b.runes(o+Vector3(-ho+0.3,SHRINE_TALL+0.2,ho+0.4+0.005),o+Vector3(ho-0.3,SHRINE_TALL+0.2,ho+0.4+0.005),Vector3.UP,Vector3.BACK,0.8)
	# Inside, all walker-only: the floor (a hand over the summit), the
	# screen a set-off behind the door (no line in), the bench at the back.
	var fl := bx(o+Vector3(-hi,-0.2,-hi),o+Vector3(hi,0.12,hi))
	b.block(fl,true,walker,0.2)
	var screen := bx(o+Vector3(-DOOR.x-0.6,0.12,hi-SET_OFF-0.6),o+Vector3(DOOR.x+0.6,SHRINE_TALL-0.6,hi-SET_OFF))
	b.block(screen,true,walker,0.5)
	b.runes(o+Vector3(-DOOR.x-0.4,1.4,hi-SET_OFF+0.005),o+Vector3(DOOR.x+0.4,1.4,hi-SET_OFF+0.005),Vector3.UP,Vector3.BACK,0.8)
	var bench := bx(o+Vector3(-hi+0.4,0.12,-hi),o+Vector3(hi-0.4,0.62,-hi+0.9))
	b.block(bench,true,walker,0.3)
	b.rect_area("sanctum",Rect2(o.x-hi,o.z-hi,SHRINE_IN,SHRINE_IN),o.y+0.12)

# --- The sundered hall ----------------------------------------------------------------------

## The sundered hall (city_hall). y 0 the high half's floor; the nave along
## Z, the crack across it at z 0, the high half toward +Z (its far end the
## ground it meets), the low half toward -Z, HALL_DROP lower and HALL_DRIFT
## across. Opts: `foundation`, `fires` (a cresset at the high half's far
## end), `cover`, `ground`.
## His: the nave of each half (his lane, NAVE_CLEAR over it), across the
## fallen slab; never the aisles (AISLE wide, AISLE_CLEAR under their roof).
## Hers: the aisles (hide between the pillars, behind the walker-only screens
## out of his sight), the kick chimney where an aisle slab has slid (inner
## and outer pillar facing across the aisle), the aisle roofs, the
## walker-only glyph steps up an inner pillar to the nave roof, the roof run,
## the crack (a running jump), the fallen slab.
static func hall(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityHall",seed_value,weathered)
	var deep: float = opts.get("foundation",FOUNDATION)
	var covers: Array = []
	var walker := walker_body(b,"WalkerOnly")
	var hp := PILLAR*0.5
	var x_in := NAVE_HALF+hp
	var x_out := NAVE_HALF+PILLAR+AISLE+hp
	var half_w := x_out+hp+HALL_MARGIN
	var length := HALL_BAYS*BAY+PILLAR+HALL_MARGIN
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*29+3
	var aisle_top := AISLE_CLEAR+SLAB
	var nave_top := NAVE_CLEAR+SLAB
	var bottom := -deep
	var open_aisle := 1
	var open_nave := 2
	var steps_at := Vector3.ZERO
	for half: int in [1,-1]:
		var s := float(half)
		var y := 0.0 if half > 0 else -HALL_DROP
		var o := Vector3(0.0 if half > 0 else HALL_DRIFT,y,0.0)
		var z_edge := s*CRACK*0.5
		var z_far := z_edge+s*length
		var zlo := minf(z_edge,z_far)
		var zhi := maxf(z_edge,z_far)
		# The stylobate: drawn whole, collided as strips from the foot.
		draw(b,bx(o+Vector3(-half_w,-0.9,zlo),o+Vector3(half_w,0.0,zhi)),0.4)
		column(b,o+Vector3(-half_w,bottom-y,zlo),o+Vector3(half_w,0.0,zhi))
		top(b,"nave",Rect2(o.x-NAVE_HALF,zlo,LANE,zhi-zlo),y,covers)
		for sx: float in [-1.0,1.0]:
			var a0 := minf(sx*(x_in+hp),sx*(x_out-hp))
			var a1 := maxf(sx*(x_in+hp),sx*(x_out-hp))
			top(b,"aisle",Rect2(o.x+a0,zlo,a1-a0,zhi-zlo),y,covers)
		# The pillars: inner rows to the nave's roof, outer to the aisle's.
		# At the crack the low half's inner pair snapped to stumps.
		var zs: Array = []
		for k in range(HALL_BAYS+1):
			zs.append(z_edge+s*(hp+k*BAY))
		for k in zs.size():
			var pz: float = zs[k]
			for sx: float in [-1.0,1.0]:
				for row: int in [0,1]:
					var px := sx*(x_in if row == 0 else x_out)
					var tall := NAVE_CLEAR if row == 0 else AISLE_CLEAR
					var snapped := half < 0 and k == 0 and row == 0
					if snapped: tall = rng.randf_range(1.8,3.2)
					var p := o+Vector3(px,0.0,pz)
					var planes: Array = bx(p+Vector3(-hp,0.0,-hp),p+Vector3(hp,tall,hp))
					if snapped:
						var cut := Vector3(rng.randf_range(-0.5,0.5),1.0,rng.randf_range(-0.5,0.5)).normalized()
						planes.append(Plane(cut,cut.dot(p+Vector3.UP*tall)))
					b.block(planes,false,null,0.6)
					b.hull(Geometry3D.compute_convex_mesh_points(_typed(bx(p+Vector3(-hp,GAP,-hp),p+Vector3(hp,tall,hp)))))
					if not snapped:
						# The capital: a square abacus a hand out all round.
						draw(b,bx(p+Vector3(-hp-0.22,tall-0.45,-hp-0.22),p+Vector3(hp+0.22,tall,hp+0.22)),0.4)
					# Its glyphs, stacked bands up the face toward the nave (inner)
					# or the outside (outer).
					var face_n := Vector3(-sx,0.0,0.0) if row == 0 else Vector3(sx,0.0,0.0)
					var fx := p.x+face_n.x*(hp+0.005)
					var band_y := 0.7
					while band_y+Stone.RUNE_H < minf(tall-0.9,5.2):
						b.runes(Vector3(fx,p.y+band_y,pz+0.65*face_n.x),Vector3(fx,p.y+band_y,pz-0.65*face_n.x),Vector3.UP,face_n)
						band_y += Stone.RUNE_H+0.35
		# The roofs, a slab a bay (each from a pillar's middle to the next):
		# the aisles' on the outer pillars (abutting the inner), the nave's on
		# the inner. One aisle slab slid away east (the kick chimney and a
		# shaft of light), one nave slab gone in the high half; the low half's
		# crack bay roofless (its nave slab is the one that fell across). At
		# the crack the high half's roofs hang a set-off over the void.
		for k in range(zs.size()):
			if half < 0 and k == 0: continue
			var za: float = float(zs[k])-s*hp
			var zb: float = float(zs[k])+s*(BAY-hp) if k < zs.size()-1 else float(zs[k])+s*hp
			if k == 0: za = z_edge-s*SET_OFF
			var r0 := minf(za,zb)
			var r1 := maxf(za,zb)
			for sx: float in [-1.0,1.0]:
				if k == open_aisle and sx > 0.0 and half > 0: continue
				var a0 := minf(sx*(x_in+hp),sx*(x_out+hp+0.4))
				var a1 := maxf(sx*(x_in+hp),sx*(x_out+hp+0.4))
				b.block(bx(o+Vector3(a0,AISLE_CLEAR,r0),o+Vector3(a1,aisle_top,r1)),true,null,0.7,null,[CityKit.over(y+AISLE_CLEAR)])
				top(b,"aisle_roof",Rect2(o.x+a0,r0,a1-a0,r1-r0),y+aisle_top,covers)
			if half > 0 and k == open_nave: continue
			var nx := x_in+hp
			b.block(bx(o+Vector3(-nx,NAVE_CLEAR,r0),o+Vector3(nx,nave_top,r1)),true,null,0.7,null,[CityKit.over(y+NAVE_CLEAR)])
			top(b,"nave_roof",Rect2(o.x-nx,r0,nx*2.0,r1-r0),y+nave_top,covers)
			for sx: float in [-1.0,1.0]:
				var ex := o.x+sx*(nx+0.005)
				var ea := r0+0.4 if sx > 0.0 else r1-0.4
				var eb := r1-0.4 if sx > 0.0 else r0+0.4
				b.runes(Vector3(ex,y+NAVE_CLEAR+0.05,ea),Vector3(ex,y+NAVE_CLEAR+0.05,eb),Vector3.UP,Vector3(sx,0.0,0.0),SLAB-0.1)
		# Her glyph steps (walker-only) up the high half's crack-edge inner
		# pillar's east face, from the aisle roof to the nave roof's lip.
		if half > 0:
			var pz: float = zs[0]
			var face := x_in+hp
			var n_steps := int(roundf((nave_top-aisle_top)/SET_OFF))-1
			for j in range(1,n_steps+1):
				# A stair of stele columns on the aisle roof, side by side along
				# the pillar's face, each a set-off over the last.
				var zz := pz-(j-2)*1.2
				var tp := aisle_top+j*SET_OFF
				var hh := Vector3(0.45,(tp-aisle_top)*0.5,0.5)
				b.block(Stone.box(Transform3D(Basis.IDENTITY,o+Vector3(face+hh.x,aisle_top+hh.y,zz)),hh,0.06),true,walker,0.3,null,[CityKit.over(y+aisle_top)])
			steps_at = o+Vector3(face+1.6,aisle_top,pz+2.6)
		# The aisle screens: walker-only carved lattices between the outer
		# pillars (she hides behind them from him outside; he looks through
		# nothing she can't), pierced by dark slots.
		for k in range(zs.size()-1):
			for sx: float in [-1.0,1.0]:
				var z0 := minf(float(zs[k]),float(zs[k+1]))+hp
				var z1 := maxf(float(zs[k]),float(zs[k+1]))-hp
				var px := o.x+sx*x_out
				b.block(bx(Vector3(px-0.3,y,z0),Vector3(px+0.3,y+2.6,z1)),true,walker,0.6)
				for q: float in [0.3,0.7]:
					var hz := lerpf(z0,z1,q)
					b.m.solid(bx(Vector3(px-0.32,y+1.0,hz-0.25),Vector3(px+0.32,y+2.0,hz+0.25)),NAN,0.45)
		if deep > 0.0: foundation(b,Rect2(o.x-half_w,zlo,half_w*2.0,zhi-zlo),y-0.9,deep)
		# The crack's lip: broken blocks on the edge.
		for i in 5:
			var x := o.x+lerpf(-half_w+1.0,half_w-1.0,(i+0.5)/5.0)+rng.randf_range(-0.8,0.8)
			var at := Vector3(x,y-0.6-rng.randf_range(0.0,1.2),z_edge+s*rng.randf_range(-0.2,0.2))
			draw(b,Stone.box(Transform3D(Basis(Vector3.RIGHT,s*rng.randf_range(0.1,0.4)),at),Vector3(rng.randf_range(0.6,1.2),0.5,0.5),0.08),1.3)
	# The fallen slab: a nave slab broken to his lane's width, lying across
	# the crack from the high floor to the low.
	var w := LANE*0.45
	# Its ends bedded into both floors (it fell and wedged): its top a
	# step (under PilotMotor STEP_UP) over each floor where it meets it.
	var bed := 0.12
	var p_hi := Vector3(HALL_DRIFT*0.25,bed,CRACK*0.5+SET_OFF*1.5)
	var p_lo := Vector3(HALL_DRIFT*0.75,-HALL_DROP+bed,-CRACK*0.5-SET_OFF*1.5)
	var pitch := atan2(p_hi.y-p_lo.y,p_hi.z-p_lo.z)
	var basis := Basis(Vector3.RIGHT,-pitch)
	var slab_len := p_hi.distance_to(p_lo)
	var xf := Transform3D(basis,(p_hi+p_lo)*0.5-basis.y*SLAB*0.5)
	b.block(Stone.box(xf,Vector3(w,SLAB*0.5,slab_len*0.5),0.12),true,null,1.0)
	b.runes(xf*Vector3(w*0.7,SLAB*0.5+0.01,-slab_len*0.2),xf*Vector3(-w*0.7,SLAB*0.5+0.01,-slab_len*0.2),basis.z,basis.y,1.2)
	var fire_at := Vector3(-NAVE_HALF+2.4,0.0,CRACK*0.5+length-HALL_MARGIN-3.6)
	b.cresset(fire_at)
	var mid_bay := CRACK*0.5+hp+BAY*0.5
	b.meta.ports["high_end"] = Vector3(0.0,0.0,CRACK*0.5+length)
	b.meta.ports["low_end"] = Vector3(HALL_DRIFT,-HALL_DROP,-CRACK*0.5-length)
	b.meta.ports["slab_high"] = p_hi
	b.meta.ports["slab_low"] = p_lo
	b.meta.ports["chimney"] = Vector3((x_in+x_out)*0.5,0.0,CRACK*0.5+hp+BAY)
	b.meta.ports["aisle"] = Vector3(-(x_in+x_out)*0.5,0.0,CRACK*0.5+hp+BAY*1.5)
	b.meta.ports["steps"] = steps_at
	b.meta.ports["nave_roof"] = Vector3(0.0,nave_top,mid_bay)
	b.meta.ports["fire"] = fire_at
	b.meta.his = {"walks":"each half's nave (%.1f m clear, %.1f m under its roof) and the fallen slab (%.1f m wide)" % [LANE,NAVE_CLEAR,w*2.0],
		"never":"the aisles (%.1f m wide, %.1f m under their roof)" % [AISLE,AISLE_CLEAR],"jumps":"the crack (%.1f m) beside the slab" % CRACK}
	b.meta["sizes"] = {"pillar":PILLAR,"bay":BAY,"nave":[LANE,NAVE_CLEAR],"aisle":[AISLE,AISLE_CLEAR],"crack":CRACK,"drop":HALL_DROP,"drift":HALL_DRIFT,
		"slab":[w*2.0,slab_len,rad_to_deg(pitch)],"width":half_w*2.0,"long":(length+CRACK*0.5)*2.0,"roof":[aisle_top,nave_top]}
	var root := b.finish()
	if bool(opts.get("fires",true)):
		CityFires.cresset(root,Transform3D(Basis.IDENTITY,fire_at),{"size":"cresset","seed":seed_value*3+2,"name":"HallCresset","lit":bool(opts.get("lit",false))})
	lay_cover(b,covers,seed_value,opts)
	return root
