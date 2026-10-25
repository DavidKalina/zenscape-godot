extends RefCounted
## The ruin kit's keel pieces (scripts/ruin_kit.gd, the same stone, wear and
## growth): what hangs under an isle's keel. RuinKit KEEL_PIECES, `piece`.
##
## The hung stair (`keel_hung_stair`): a flight of the kit's own steps (its
## RISER by TREAD, STAIR_WIDTH wide between CHEEK walls) hung upside down
## from a hinge beam socketed into the keel, the beam along the flight's
## pitch at its outer cheek's foot. It is a flying flight (a sloped soffit
## SOFFIT under its nosings), not the kit's solid one: the solid flight's
## underside is flat, and hung it would show a flat face, not a slide.
## Hung, it is turned HUNG about the beam: its treads face the void, its
## soffit faces the sky at HUNG_STEEP (over the walker's SLIDE_AUTO), so
## landed on, he boot-surfs down it and off. A slam on the carved boss in
## the turf above turns it (scripts/keel_hung_stair.gd, its "Rig") right
## way up, a plain walked flight, for `hold` s, then back.
##
## The piece's frame: the boss on the turf at the origin, its foot on y 0
## (the root's "Mesh" and "Body" are the boss: the editor seats the piece
## on the turf by it). Under it, KEEL_DROP down, the hinge: the flight runs
## along +X (climbing toward +X), the axis (the outer cheek's foot) under
## the boss at z 0, the beam on it toward +Z; turned, the flight lies on the
## -Z side of the beam (into the keel: a shaft or an overhang over it),
## hung it hangs out on the +Z side (the piece's front, over the void).
## The turn swings it down under the beam, never up: the turf over it is
## safe, and a shaft's floor at the head stays clear if its lip is cut on
## `head_cut` (the foot's ledge needs no cut).
##   "Mesh", "Body"     the boss (static)
##   "Hinge"            the beam and its two sockets: its own "Mesh" and
##                      "Body" (static, the beam's top walked)
##   "Pivot"            on the hinge's axis, turned about it by the Rig
##   "Pivot/Flight"     the flight: "Mesh" and "Body" (clean boxes)
##   "Rig"              the runtime (scripts/keel_hung_stair.gd)
## Meta (piece frame): "axis" [from, to] the hinge's axis, "hung_angle"
## (rad, the Pivot's turn hung), "boss" (its top), "foot" and "head" (the
## turned flight's foot on its lower ledge and its head's top), "beam_top"
## [from, to] the beam's walked top line, "steps".
## The flight is built right way up, so its moss and ivy grew on its
## treads and hang from them: hung, the strands stand up toward the sky.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build

const PIECES := ["keel_hung_stair"]

## The kit's flight, every step a tread (no landing: the soffit runs on up
## under the last step, so the hung slide has no flat in it).
const STEPS := RuinKit.STEPS
const RISER := RuinKit.RISER
const TREAD := RuinKit.TREAD
const HALF_W := RuinKit.STAIR_WIDTH*0.5
const CHEEK := RuinKit.CHEEK
## The flight's thickness square to its pitch, nosing line to soffit: the
## throat under each riser's foot is this less a riser's reach in.
const SOFFIT := 0.5
## The walker's steepest standing slope (deg), frozen: the pilot on foot
## (scripts/pilot_motor.gd SLIDE_AUTO) is gone from the flight game, whole
## at the tag archive/before-the-cut.
const SLIDE_AUTO := 44.0
## The hung soffit's slope (deg): past the walker's SLIDE_AUTO, so he
## couldn't stand on it and surfed.
const HUNG_STEEP := SLIDE_AUTO+6.0
## The turned flight's head (its last tread's top) under the boss: two
## climbing set-offs (the shaft's floor in the keel).
const KEEL_DROP := 2.0*RuinKit.SET_OFF
## The hinge beam: across (TOP_ROOM: a narrow beam route) and deep (square
## to the pitch); how far past the flight's ends it runs into its sockets,
## and the socket stones' size (along, across, deep).
const BEAM := Vector2(RuinKit.TOP_ROOM,0.45)
const BEAM_PAST := 1.3
const SOCKET := Vector3(0.7,1.9,1.2)
## The boss: apothem, height over the turf, and how deep it is sunk.
const BOSS := Vector3(0.62,0.14,0.3)
## Hinge socket grime (vertex colour, times the stone).
const GRIME := 0.62

## The flight's pitch (rad) and run along it.
static var PITCH: float = atan2(RISER,TREAD)
const RUN := STEPS*TREAD
const FRONT := RUN*0.5
const BACK := -RUN*0.5
## The outer cheek's face (the beam's side) in the flight's frame.
const OUTER := HALF_W+CHEEK.x
## The pivot's turn when hung (rad, about the axis, sign chosen in `lines`
## so the flight swings down under the beam and out to +Z).
static var HUNG_ANGLE: float = PI-acos(cos(deg_to_rad(HUNG_STEEP))/cos(atan2(RISER,TREAD)))

static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"keel_hung_stair": return keel_hung_stair(seed_value,weathered)
	return null

## The flight's own frame (as the kit's `stairs`: climbing toward -Z from
## its foot at +Z, x across, its first riser rising from y 0) into the
## piece's: x across to +Z, its run to -X, the head KEEL_DROP under the
## boss, the axis's middle under the origin.
static func flight_frame() -> Transform3D:
	var basis := Basis(Vector3(0.0,0.0,1.0),Vector3.UP,Vector3(-1.0,0.0,0.0))
	var mid_z := 0.0
	return Transform3D(basis,Vector3(mid_z,-KEEL_DROP-STEPS*RISER,-OUTER))

## The nosing line's height at z (flight frame) and the soffit's under it.
static func nose_y(z: float) -> float:
	return RISER+(FRONT-z)*RISER/TREAD

static func soffit_y(z: float) -> float:
	return nose_y(z)-SOFFIT/cos(PITCH)

## The soffit's outward normal (down and toward the head) and the pitch's
## up normal, the flight's frame.
static func down_normal() -> Vector3:
	return Vector3(0.0,-TREAD,-RISER).normalized()

static func up_normal() -> Vector3:
	return Vector3(0.0,TREAD,RISER).normalized()

## The plane square to the pitch `off` m over the soffit (outward `up`
## true: its up side out), flight frame.
static func pitch_plane(off: float, outward_up: bool) -> Plane:
	var n := up_normal()
	var on := Vector3(0.0,soffit_y(FRONT),FRONT)+n*off
	return Plane(n,n.dot(on)) if outward_up else Plane(-n,(-n).dot(on))

## The flight's head end cut square to the hinge's axis through the axis's
## end (outward along the pitch), flight frame: a point keeps its place
## along the axis as it turns, so nothing of the flight ever swings past
## this plane, and a shaft floor whose lip is cut on it (HEAD_CUT) is never
## struck by the turn. (A plain upright end swung its corners up to 0.8 m
## past itself, under the shaft's floor.) The foot needs no cut: its turn
## carries everything toward the head.
static func head_cut() -> Plane:
	var d := Vector3(0.0,RISER,-TREAD).normalized()
	return Plane(d,d.dot(Vector3(OUTER,soffit_y(BACK),BACK)))

## How far the head's last tread is cut back at its top (m, along the run).
static func head_back() -> float:
	return (STEPS*RISER-soffit_y(BACK))*RISER/TREAD

## The hinge in the piece's frame: {"a" (axis point at the flight's foot
## end), "dir" (up the pitch, unit), "from", "to" (the beam's ends),
## "sign" (the turn's sign that swings it down under the beam), "hung"
## (the signed hung angle)}.
static func lines() -> Dictionary:
	var f := flight_frame()
	var a_f := Vector3(OUTER,soffit_y(FRONT),FRONT)
	var d_f := Vector3(0.0,RISER,-TREAD).normalized()
	var a := f*a_f
	var d := (f.basis*d_f).normalized()
	# Inward (the turned flight's side, -Z) turned a little must go down.
	var inward := f.basis*Vector3(-1.0,0.0,0.0)
	var sgn := -1.0 if (Basis(d,0.1)*inward).y > inward.y else 1.0
	var along := RUN/cos(PITCH)
	return {"a":a,"dir":d,"sign":sgn,"hung":sgn*HUNG_ANGLE,
		"from":a-d*BEAM_PAST,"to":a+d*(along+BEAM_PAST),"length":along}

## A convex block's planes moved into a frame centred on `c`.
static func _local(planes: Array[Plane], c: Vector3) -> Array[Plane]:
	var out: Array[Plane] = []
	for p: Plane in planes: out.append(Plane(p.normal,p.d-p.normal.dot(c)))
	return out

## A box x0..x1, y0..y1, z0..z1 (z0 the lesser).
static func _slab(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> Array[Plane]:
	return [Plane(Vector3.LEFT,-x0),Plane(Vector3.RIGHT,x1),Plane(Vector3.DOWN,-y0),Plane(Vector3.UP,y1),
		Plane(Vector3.FORWARD,-z0),Plane(Vector3.BACK,z1)]

## The hung stair (see the header).
static func keel_hung_stair(seed_value: int, weathered := 0.0) -> Node3D:
	var L := lines()
	var f := flight_frame()
	# --- The boss: the root, on the turf.
	var b := Build.new(seed_value,weathered,"KeelHungStair")
	b.ground = 0.0
	b.solid(RuinKit._prism(8,BOSS.x+0.08,BOSS.x,-BOSS.z,BOSS.y),Transform3D.IDENTITY,RuinKit._stone(b,1.05),true,true)
	# Its carving: a cross of raised bars, the axle's line along X.
	b.solid(RuinKit._box(b,Vector3(BOSS.x*0.8,0.04,0.09),0.02),Transform3D(Basis.IDENTITY,Vector3(0.0,BOSS.y+0.03,0.0)),RuinKit._stone(b,0.92),false,false)
	b.solid(RuinKit._box(b,Vector3(0.09,0.035,BOSS.x*0.45),0.02),Transform3D(Basis.IDENTITY,Vector3(0.0,BOSS.y+0.025,0.0)),RuinKit._stone(b,0.92),false,false)
	var root := b.finish()
	# --- The hinge: the beam and its sockets, built in the flight's frame.
	var h := Build.new(seed_value+1,weathered,"Hinge")
	h.frame = f
	var beam_lo := FRONT+BEAM_PAST*cos(PITCH)
	var beam_hi := BACK-BEAM_PAST*cos(PITCH)
	var beam: Array[Plane] = [Plane(Vector3.LEFT,-OUTER),Plane(Vector3.RIGHT,OUTER+BEAM.x),
		pitch_plane(0.0,false),pitch_plane(BEAM.y,true),Plane(Vector3.BACK,beam_lo),Plane(Vector3.FORWARD,-beam_hi)]
	var beam_mid := Vector3(OUTER+BEAM.x*0.5,(soffit_y(beam_lo)+soffit_y(beam_hi))*0.5+BEAM.y*0.5/cos(PITCH),(beam_lo+beam_hi)*0.5)
	# Drawn in three long stones; walked as one true box.
	for k in range(3):
		var za := beam_lo-(beam_lo-beam_hi)*k/3.0
		var zb := beam_lo-(beam_lo-beam_hi)*(k+1)/3.0
		var part: Array[Plane] = beam.duplicate()
		part[4] = Plane(Vector3.BACK,za-0.01)
		part[5] = Plane(Vector3.FORWARD,-(zb+0.01))
		var c := Vector3(beam_mid.x,(soffit_y(za)+soffit_y(zb))*0.5+BEAM.y*0.5/cos(PITCH),(za+zb)*0.5)
		h.solid(RuinKit._bevel(_local(part,c),Vector3.ZERO,0.04),Transform3D(Basis.IDENTITY,c),RuinKit._stone(h,0.98),false)
	RuinKit._walk_hull(h,Transform3D.IDENTITY,beam)
	# The sockets: rough blocks round the beam's ends, set into the keel,
	# grimed where the beam goes in.
	for end: float in [-1.0,1.0]:
		var z := beam_lo-0.35*cos(PITCH) if end > 0.0 else beam_hi+0.35*cos(PITCH)
		var c := Vector3(OUTER+BEAM.x*0.5,soffit_y(z)+BEAM.y*0.5,z)
		var tilt := Basis(Vector3.RIGHT,-PITCH*0.5)
		var pose := RuinKit._jiggle(h,Transform3D(tilt,c),0.6)
		h.solid(RuinKit._box(h,Vector3(SOCKET.y*0.5,SOCKET.z*0.5,SOCKET.x*0.5)),pose,RuinKit._stone(h,GRIME),true)
	var hinge := h.finish()
	root.add_child(hinge)
	# --- The flight, right way up in its own frame, on the pivot.
	var flight := _flight(seed_value,weathered)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.position = L.a
	root.add_child(pivot)
	flight.transform = Transform3D(f.basis,f.origin-(L.a as Vector3))
	pivot.add_child(flight)
	pivot.transform = Transform3D(Basis(L.dir,float(L.hung)),L.a)
	# --- Meta and the runtime.
	root.set_meta("axis",[L.a,(L.a as Vector3)+(L.dir as Vector3)*float(L.length)])
	root.set_meta("hung_angle",float(L.hung))
	root.set_meta("boss",Vector3(0.0,BOSS.y,0.0))
	root.set_meta("foot",f*Vector3(0.0,0.0,FRONT))
	root.set_meta("head",f*Vector3(0.0,STEPS*RISER,BACK+head_back()))
	root.set_meta("beam_top",[f*Vector3(OUTER+BEAM.x*0.5,soffit_y(beam_lo)+BEAM.y/cos(PITCH),beam_lo),f*Vector3(OUTER+BEAM.x*0.5,soffit_y(beam_hi)+BEAM.y/cos(PITCH),beam_hi)])
	root.set_meta("steps",STEPS)
	var rig: Node3D = load("res://scripts/keel_hung_stair.gd").new()
	rig.name = "Rig"
	root.add_child(rig)
	rig.call("bind",root)
	return root

## The flight right way up (the flight's frame): every step a block from
## the soffit to its tread, cheek walls in courses over the soffit, a newel
## at the free cheek's foot. Collision: clean boxes, each tread's top true
## and cut by the soffit (so none breaks through it hung), the soffit one
## true slab, each cheek one hull (wall kicks either way up).
static func _flight(seed_value: int, weathered: float) -> Node3D:
	var b := Build.new(seed_value+2,weathered,"Flight")
	var soffit_out := pitch_plane(0.0,false)
	var soffit_in := pitch_plane(0.02,false)
	var cut := head_cut()
	for i in range(STEPS):
		var z0 := FRONT-i*TREAD
		var z1 := z0-TREAD
		var top := (i+1)*RISER
		var settle := b.rng.randf_range(0.0,0.015)+b.rng.randf_range(0.0,0.03)*weathered
		var bottom := soffit_y(z0)
		var c := Vector3(0.0,(bottom+top)*0.5,(z0+z1)*0.5)
		var hh := Vector3(HALF_W-0.008,(top-settle-bottom)*0.5,TREAD*0.5-0.006)
		b.lean = true
		var planes := RuinKit._box(b,hh)
		var n := Vector3(0.0,1.0,1.0).normalized()
		planes.append(Plane(n,(hh.y+hh.z)/sqrt(2.0)-0.03-0.05*b.age))
		planes.append(Plane(soffit_out.normal,soffit_out.d-soffit_out.normal.dot(c-Vector3(0.0,settle*0.5,0.0))))
		planes.append(Plane(cut.normal,cut.d-cut.normal.dot(c-Vector3(0.0,settle*0.5,0.0))))
		var tilt := Basis(Vector3.RIGHT,b.rng.randf_range(-0.005,0.005)+b.rng.randf_range(-0.01,0.01)*weathered)
		b.solid(planes,Transform3D(tilt,c-Vector3(0.0,settle*0.5,0.0)),RuinKit._stone(b),false,true)
		b.lean = false
		# The tread walked: its top true, 0.3 deep, a little under the next
		# riser, never through the soffit.
		var back := z1-(0.1 if i < STEPS-1 else 0.0)
		RuinKit._walk_hull(b,Transform3D.IDENTITY,_slab(-HALF_W-0.02,HALF_W+0.02,top-0.3,top,back,z0)+[soffit_in,cut])
	# The soffit walked hung: one true slab over the whole width.
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,OUTER),Plane(Vector3.RIGHT,OUTER),soffit_out,pitch_plane(0.22,true),
		Plane(Vector3.BACK,FRONT),Plane(Vector3.FORWARD,-BACK),cut])
	# The cheeks: ramped stones in two courses over the soffit, a coping.
	var cope := pitch_plane(SOFFIT+CHEEK.y,true)
	var torn := -1.0 if b.rng.randf() < 0.5 else 1.0
	for side: float in [-1.0,1.0]:
		var lo := minf(side*HALF_W,side*OUTER)
		var hi := maxf(side*HALF_W,side*OUTER)
		var stones := 3
		for k in range(stones):
			var za := FRONT-RUN*k/stones
			var zb := FRONT-RUN*(k+1)/stones
			var mid := Vector3((lo+hi)*0.5,(soffit_y(za)+soffit_y(zb))*0.5+(SOFFIT+CHEEK.y)*0.5/cos(PITCH),(za+zb)*0.5)
			var high := cope
			# Weathered, the free cheek is broken down along a stretch.
			if weathered > 0.35 and side == torn and k == 1: high = pitch_plane(SOFFIT+CHEEK.y-0.25*weathered,true)
			for course in range(2):
				var split := (SOFFIT+CHEEK.y)*(0.45+b.rng.randf_range(-0.06,0.06))
				var under: Plane = soffit_out if course == 0 else pitch_plane(split,false)
				var over: Plane = pitch_plane(split,true) if course == 0 else high
				var planes: Array[Plane] = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),under,over,Plane(Vector3.BACK,za-0.008),Plane(Vector3.FORWARD,-(zb+0.008)),cut]
				b.solid(RuinKit._bevel(_local(planes,mid),Vector3.ZERO,0.03),Transform3D(Basis.IDENTITY,mid),RuinKit._stone(b,0.97 if course == 0 else 1.04),false)
		RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),soffit_out,cope,Plane(Vector3.BACK,FRONT),Plane(Vector3.FORWARD,-BACK),cut])
	# The newel at the free cheek's foot: a square post under a gablet.
	var nx := -(HALF_W+CHEEK.x*0.5)
	var post := RuinKit.NEWEL.y-0.18
	var foot := soffit_y(FRONT)+0.1
	b.solid(RuinKit._box(b,Vector3(CHEEK.x*0.5+0.04,(post-foot)*0.5,RuinKit.NEWEL.x*0.5)),RuinKit._settle(b,Vector3(nx,(post+foot)*0.5,FRONT-RuinKit.NEWEL.x*0.5),0.6),RuinKit._stone(b,1.0),false)
	RuinKit._gablet(b,Transform3D(Basis.IDENTITY,Vector3(nx,post,FRONT-RuinKit.NEWEL.x*0.5)),CHEEK.x*0.5+0.09,0.42)
	return b.finish()
