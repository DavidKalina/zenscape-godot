extends RefCounted
## The city kit, family `city`:
## the bones of the abandoned Olmec city the run starts in, deep under the
## sky stage. Heavy weathered basalt (the Olmec's own stone, scripts/
## city_kit_stone.gd), talud under tablero, stepped massing, carved glyph
## bands that do not glow. Built around him (scripts/enemies/
## headless_body.gd): every lane he is meant to use is his width, every
## landing his room, every shelf his rule;
## the wanderer's lines (ledge chains, a rail, the turn below) are cut into
## the same stone at her own numbers (RuinKit SET_OFF, GRAB_TOP, STAND).
## The gothic ruin kit (scripts/ruin_kit.gd) stays with the dragon's sky.
##
## The pieces (ids in PIECES; `piece` builds one by id):
##   city_pillar      the isle: a hex basalt column out of an unseen floor,
##                    stepped collar courses down its flanks (a ledge ring
##                    every COURSE), organ-pipe prisms on its climb face (the
##                    wanderer's chain up from collar to collar), a paved
##                    crown or a bare one for a KitLand turf crown, an
##                    optional round well for the drum stair.
##   city_drum_stair  a stair wound down a well as an inward spiral: each
##                    turn steps COURSE down and LANE in, so a fall off the
##                    inside of a turn lands on the turn below, standing.
##   city_stair       the epic stair: flights LANE wide between serpent
##                    cheek walls whose crest is a rail to slide, landings
##                    his room, a stepped pyramid flank, serpent heads at the
##                    foot; one landing can be a fault course that drops into
##                    the chamber under it when he stands on it.
##   city_causeway    the hero bridge: a deck his lane on battered piers with
##                    corbelled (stepped) openings; one bay's middle can break
##                    and fall to whatever road lies under it.
##
## Every piece, as the ruin kit's: a static func (seed, `weathered` 0-1,
## `opts`) giving a Node3D, front toward +Z: "Mesh" (stone, then the carved
## runes) and "Body" (clean walk boxes and hulls). Where its y 0 is differs
## by what it meets (each func says): the stair's foot, the pillar's crown,
## the drum's rim, the causeway's deck. Meta on the root: "ports" (named
## points a motif joins to), "mounts" ({"cresset": [points]}: fire bowls,
## the only light), "rails" (the cheek crests), "breaks" (the breakable
## units, for scripts/kit_isle/city_breaks.gd), "his" (what the body can do).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")
const WalkerOnly = preload("res://scripts/walker_only.gd")
## The floors that break (the stair's fault, the causeway's bay): pieces of
## the breakables hub (scripts/kit_isle/breakables.gd).
const FloorBreak = preload("res://scripts/city_breaks/floor_break.gd")
## The family's other breakables: the felled column and the drum floor
## (scripts/city_kit_breaks.gd).
const CityBreaks = preload("res://scripts/city_kit_breaks.gd")
## The family's fires: the great cresset, the beacon tower, the oil runnel,
## the wick spire (scripts/city_kit_fires.gd). They
## stand in a parent (`stand`), not as a returned piece.
const CityFires = preload("res://scripts/city_kit_fires.gd")
## The family's refuges: the mouse run, the votive niches, the hush gallery,
## the slotted wall (scripts/city_kit_refuges.gd).
const CityRefuges = preload("res://scripts/city_kit_refuges.gd")
## The family's light pieces: the sun-mirror, the relief face
## (scripts/city_kit_light2.gd); stood like the fires.
const CityLight2 = preload("res://scripts/city_kit_light2.gd")
## The family's landmarks: the ballcourt coliseum, the temple pyramid, the
## sundered hall (scripts/city_kit_landmarks.gd).
## The court's swing roots come as data on the piece: its scene hangs them.
const CityLandmarks = preload("res://scripts/city_kit_landmarks.gd")
## Breaks round 2: corbel vault, facing sheet wall, chocked slab, plug-stone.
const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
## Climb pieces, a lane for each body: wedge, terrace, wrapped pillar, hauling
## lip, leaper's pit, giant's riser.
const CityClimb = preload("res://scripts/city_kit_climb.gd")
## The serpent's pieces, stood like the fires: waiting dais, ring, coil, ash bowl;
## the collar rides a serpent.
const CitySerpent = preload("res://scripts/city_kit_serpent.gd")

const PIECES := ["city_pillar","city_drum_stair","city_stair","city_causeway"]+CityBreaks.PIECES+CityRefuges.PIECES+CityLandmarks.PIECES+CityBreaks2.PIECES+CityClimb.PIECES
const NAMES := {"city_pillar":"Basalt pillar-isle","city_drum_stair":"Drum stair","city_stair":"Epic stair","city_causeway":"Causeway"}

## Every id in the family: its pieces, its breaks, its fires.
static var ALL: Array = PIECES+CityFires.PIECES.keys()+CityLight2.PIECES.keys()+CitySerpent.PIECES.keys()

## Any of the family's pieces stood in `parent` at `xform` (a fire through
## CityFires `build`, the rest through `piece`).
static func stand(id: String, parent: Node3D, xform: Transform3D, seed_value := 1, weathered := 0.4, opts := {}) -> Node3D:
	if CityFires.PIECES.has(id): return CityFires.build(id,parent,xform,opts)
	if CityLight2.PIECES.has(id): return CityLight2.build(id,parent,xform,opts)
	if CitySerpent.PIECES.has(id): return CitySerpent.build(id,parent,xform,opts)
	var n := piece(id,seed_value,weathered,opts)
	if n == null: return null
	parent.add_child(n)
	n.transform = xform
	return n

## A piece's name (the family's breakables' too).
static func name_of(id: String) -> String:
	return String(NAMES.get(id,CityBreaks.NAMES.get(id,CityRefuges.NAMES.get(id,CityLandmarks.NAMES.get(id,CityBreaks2.NAMES.get(id,CityClimb.NAMES.get(id,id)))))))

# --- The wanderer's numbers (the ruin kit's) ------------------------------------------
const SET_OFF := RuinKit.SET_OFF
const STAND := RuinKit.STAND
const TOP_ROOM := RuinKit.TOP_ROOM
const GRAB_TOP := RuinKit.GRAB_TOP
## The kit's module (the ruin kit's bay; the makers' CELL).
const CELL := RuinKit.BAY
## A course: three set-offs. A collar's rise, a flight's, a drum turn's.
## Under the fall stun (PilotMotor FALL_STUN_PUMPS x the pump, 6 m), so a
## fall off the inside of anything lands standing on the course below.
const COURSE := 3.0*SET_OFF
## The city's step: four to a set-off, a tread two risers (a grand,
## shallow stair the wanderer runs and he walks: under PilotMotor STEP_UP).
const RISER := SET_OFF/4.0
const TREAD := 2.0*RISER

# --- His numbers (what he can use) ------------------------
## The least stair width and landing he uses (m), his headroom (neck 6.7 m
## and the bulk over it), and the shelf rule: a shelf under a rim is at
## least HIS_SHELF.y deep or under HIS_SHELF.x (nothing between).
const HIS_LANE_LEAST := 5.0
const HIS_LANDING_LEAST := 6.0
const HIS_HEADROOM := 7.5
const HIS_SHELF := Vector2(2.0,6.0)
## His lane: a stair's and a drum's width, two cells. Round 11's 5 m is
## his planner's; his bulk (scripts/enemies/headless_body.gd BULK_W, its
## shoulders and hanging arms: 2 x BULK_W head heights, 6.7 m at his size)
## is eased off any wall it meets, so a lane narrower than that holds him
## off its cheeks (6.6 m stalled him at the stair's foot). His landing,
## two cells (over his 6 x 6, his bulk turning on it).
const LANE := 2.0*CELL
const LANDING := 2.0*CELL

# --- The pillar ---------------------------------------------------------------------------
## The crown's apothem (m, centre to a flat face): 7 cells, 62 m flat to flat.
const PILLAR_APOTHEM := 7.0*CELL
## A collar's ledge: each course stands this much out from the one over it.
## One set-off: a walker's ledge, and under his 2 m shelf rule (he never
## lands on it; he climbs on past it).
const LEDGE := SET_OFF
## The talud's lean at a course's foot (m out over its set-off rise).
const BATTER := 0.25
## The collar courses down the flank, and the shaft below them (m under
## the crown) that fades into the haze.
const COURSES := 3
const SHAFT_DEPTH := 70.0
## The climb face's prisms: their apothem (flat to flat 1.2 m: a top the
## walker stands on, STAND and more past the lip she climbs over).
const PRISM := 0.6
## A bare crown (for a KitLand turf top) sits this far under y 0.
const CROWN_SOIL := 0.35

# --- The drum stair -------------------------------------------------------------------
## The well's radius (m: its turns' lanes and a core), its turns, its
## segments a turn, its steps a turn.
const DRUM_RADIUS := 6.5*CELL
const DRUM_TURNS := 2
const DRUM_SEGMENTS := 24
const DRUM_STEPS := int(COURSE/RISER)
## A standing drum's own rim ring (m wide).
const DRUM_RIM := CELL

# --- The epic stair -------------------------------------------------------------------
const STAIR_FLIGHTS := 3
const STAIR_STEPS := int(COURSE/RISER)
## The cheek: its width (a top to run, TOP_ROOM), its crest a set-off over
## the nosings (one jump's grab from the stair; a rail the motor slides
## crouched, as the balustrade's coping), eased down to MOUNT over the summit
## RAMP back.
const CHEEK := 1.2
const CREST := SET_OFF
## The crest's head eased all the way down into the summit (MOUNT over it):
## the rail is walked onto from the top, crouched, and slid.
const MOUNT := 0.0
## (The balustrade's RAMP is for its 0.95 m coping; this crest eases down
## at the stair's own pitch, so it is walked up, not climbed.)
const RAMP := (CREST-MOUNT)*TREAD/RISER
## The pyramid's flank either side of the cheeks (m).
const FLANK := 2.0*CELL
## The serpent head at each cheek's foot: its length out in front (m).
const HEAD_LENGTH := 3.4

# --- The causeway ---------------------------------------------------------------------
## A span pier to pier (six cells: its middle third the bay that can break,
## two cells, a gap he leaps and the wanderer sails), the deck's width
## (two and a half cells: 9.4 m clear between the parapets, his lane and
## his bulk's 6.7 m with room), its thickness
## (two set-offs: a deep girder course under the road, the far silhouette),
## the parapets (a set-off tall: a grab from the deck, a top to stand).
const SPAN := 6.0*CELL
const DECK := 2.5*CELL
const DECK_THICK := 2.0*SET_OFF
const PARAPET := Vector2(0.8,SET_OFF)
## A pier's top (m square), its batter (m out a metre down), its depth.
const PIER := 1.5*CELL
const PIER_BATTER := 0.05
const PIER_DROP := 48.0
## The corbels: courses stepping in from each pier (each this far out and a
## set-off tall), leaving the opening's top about 14 m clear (the rune
## serpent's bore: kit-k5's KUKUL_BORE, never flown by the plane).
const CORBELS := 3
const CORBEL_STEP := 1.0
const SPANS := 4

## Under a solid that stands on another walked top, its collision stops
## this far over that top (m; the mesh goes down to it). The body's route
## reads (scripts/enemies/body_routes.gd `col`) cast on down through a
## solid and measure the room over each top they find from just over it
## (0.1 m): a top buried under a solid touching it reads as a floor with
## all the room in the world inside the masonry (a phantom lane through a
## stair's cheek). A gap over 0.1 m makes its room the gap.
const GAP := 0.2
## A breakable unit's pieces collide this far past their seams into each
## other (m): a ray down a seam where two boxes only touch can slip
## through, and the body's routes read the floor between columns on them.
const SEAM := 0.06

## The kg of a cubic metre of the city's basalt (the destruction round's).
const STONE_KG := 2300.0

static func _typed(planes: Array) -> Array[Plane]:
	var out: Array[Plane] = []
	for p: Plane in planes: out.append(p)
	return out

## Collision kept GAP over `y` (it stands on a top there), or GAP under it.
static func over(y: float) -> Plane:
	return Plane(Vector3.DOWN,-(y+GAP))

static func under(y: float) -> Plane:
	return Plane(Vector3.UP,y-GAP)

## A piece's walked tops in the world (it in the tree): [{kind, poly (world
## x, z), y, y1}] (`Piece.area`): landings, summits, crowns, collars, drum
## turns, decks, parapets, tiers, flights (y to y1 along -Z, their slope).
## For ground cover: a dresser lays its layer over these, the stone under
## them as bare as it likes.
static func walk_areas(piece: Node3D, kinds: Array = []) -> Array:
	var out: Array = []
	var xf := piece.global_transform
	for a: Dictionary in piece.get_meta("walk_areas",[]):
		if not kinds.is_empty() and not String(a.kind) in kinds: continue
		var poly := PackedVector2Array()
		for q: Vector2 in a.poly:
			var w := xf*Vector3(q.x,float(a.y),q.y)
			poly.append(Vector2(w.x,w.z))
		out.append({"kind":a.kind,"poly":poly,"y":float(a.y)+xf.origin.y,"y1":float(a.y1)+xf.origin.y})
	return out

## A piece by its id.
static func piece(id: String, seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	if id in CityBreaks.PIECES: return CityBreaks.piece(id,seed_value,weathered)
	if id in CityRefuges.PIECES: return CityRefuges.piece(id,seed_value,weathered)
	if id in CityLandmarks.PIECES: return CityLandmarks.piece(id,seed_value,weathered,opts)
	if id in CityBreaks2.PIECES: return CityBreaks2.piece(id,seed_value,weathered)
	if id in CityClimb.PIECES: return CityClimb.piece(id,seed_value,weathered,opts)
	match id:
		"city_pillar": return pillar(seed_value,weathered,opts)
		"city_drum_stair": return drum_stair(seed_value,weathered,opts)
		"city_stair": return stair(seed_value,weathered,opts)
		"city_causeway": return causeway(seed_value,weathered,opts)
	push_error("city kit: no piece %s" % id)
	return null

## The face `f` of a hex (0 toward +Z, then every 60 degrees toward +X).
static func hex_dir(f: int) -> Vector3:
	var a := TAU*f/6.0
	return Vector3(sin(a),0.0,cos(a))

## A ring's planes: the hex of apothem `a` (around the y axis).
static func hex_planes(a: float) -> Array:
	var out: Array = []
	for f in 6: out.append(Plane(hex_dir(f),a))
	return out

## Planes y over `lo` and under `hi`.
static func slab(lo: float, hi: float) -> Array:
	return [Plane(Vector3.DOWN,-lo),Plane(Vector3.UP,hi)]

static func dir(a: float) -> Vector3:
	return Vector3(sin(a),0.0,cos(a))

## The wedge between angles `a0` and `a1` (a0 < a1, under PI apart).
static func wedge(a0: float, a1: float) -> Array:
	var t0 := Vector3(cos(a0),0.0,-sin(a0))
	var t1 := Vector3(cos(a1),0.0,-sin(a1))
	return [Plane(-t0,0.0),Plane(t1,0.0)]

## Outside the chord from `p` to `q` (seen from the centre), or inside it.
static func chord(p: Vector3, q: Vector3, outside: bool) -> Plane:
	var mid := (p+q)*0.5
	var t := (q-p).normalized()
	var nrm := Vector3.UP.cross(t).normalized()
	if nrm.dot(Vector3(mid.x,0.0,mid.z)) < 0.0: nrm = -nrm
	# nrm points away from the centre.
	return Plane(-nrm,-nrm.dot(mid)) if outside else Plane(nrm,nrm.dot(mid))

# --- The builder ----------------------------------------------------------------------

## A piece being built: its stone, its body, its meta.
class Piece extends RefCounted:
	var root := Node3D.new()
	var m: Stone.Mesher
	var body := StaticBody3D.new()
	var rng := RandomNumberGenerator.new()
	var weathered := 0.4
	var meta := {"ports":{},"mounts":{"cresset":[]},"rails":[],"breaks":[],"his":{},"walk_areas":[]}

	func _init(node_name: String, seed_value: int, wear: float) -> void:
		root.name = node_name
		body.name = "Body"
		rng.seed = seed_value
		weathered = wear
		m = Stone.Mesher.new(Stone.stone_colour())

	## A block of `planes`, drawn with the wear's chips and its tone a little
	## off its neighbours'; collided as its clean planes (`collide`) into
	## `into` (the body if null). Returns its clean corners.
	## `clip` more planes for its collision only (`over`, `under`: a GAP off
	## what it stands on or what stands on it).
	func block(planes: Array, collide := true, into: CollisionObject3D = null, chips := 1.0, mesher: Stone.Mesher = null, clip: Array = []) -> PackedVector3Array:
		var typed: Array[Plane] = []
		for p: Plane in planes: typed.append(p)
		var clean := Geometry3D.compute_convex_mesh_points(typed)
		if clean.size() < 4: return clean
		var drawn := planes.duplicate()
		var c := Vector3.ZERO
		var top := -INF
		for p in clean:
			c += p
			top = maxf(top,p.y)
		c /= clean.size()
		var n_chips := int(rng.randf_range(0.0,1.0+3.0*weathered)*chips)
		for k in range(n_chips):
			var corner := clean[rng.randi_range(0,clean.size()-1)]
			if corner.y < top-0.05 and rng.randf() < 0.7: continue
			var out := (corner-c).normalized()
			out = (out+Vector3(rng.randf_range(-0.3,0.3),rng.randf_range(0.0,0.4),rng.randf_range(-0.3,0.3))).normalized()
			drawn.append(Plane(out,out.dot(corner)-rng.randf_range(0.08,0.22+0.3*weathered)))
		var tone := 1.0+rng.randf_range(-0.07,0.07)
		var into_mesh := mesher if mesher != null else m
		var pts := into_mesh.solid(drawn,NAN,tone)
		if pts.size() < 4: into_mesh.solid(planes,NAN,tone)
		if collide:
			if clip.is_empty(): hull(clean,into)
			else:
				var cut: Array[Plane] = typed.duplicate()
				for cp: Plane in clip: cut.append(cp)
				hull(Geometry3D.compute_convex_mesh_points(cut),into)
		return clean

	## A convex hull of `points` into `into` (the body if null).
	func hull(points: PackedVector3Array, into: CollisionObject3D = null, xf := Transform3D.IDENTITY) -> CollisionShape3D:
		var shape := ConvexPolygonShape3D.new()
		var local := PackedVector3Array()
		var inv := xf.affine_inverse()
		for p in points: local.append(inv*p)
		shape.points = local
		var holder := CollisionShape3D.new()
		holder.shape = shape
		holder.transform = xf
		(into if into != null else body).add_child(holder)
		return holder

	## A clean walk box from `lo` (a GAP over it) up to `hi` over the
	## rect (x, z) `rect` (axis-aligned).
	func walk_column(rect: Rect2, lo: float, hi: float, into: CollisionObject3D = null) -> CollisionShape3D:
		var bottom := lo+GAP
		return walk_box(Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,(bottom+hi)*0.5,rect.get_center().y)),Vector3(rect.size.x*0.5,(hi-bottom)*0.5,rect.size.y*0.5),into)

	## A clean walk box: half-size `h` at `xf` into `into` (the body if null).
	func walk_box(xf: Transform3D, h: Vector3, into: CollisionObject3D = null) -> CollisionShape3D:
		var shape := BoxShape3D.new()
		shape.size = h*2.0
		var holder := CollisionShape3D.new()
		holder.shape = shape
		holder.transform = xf
		(into if into != null else body).add_child(holder)
		return holder

	## A carved glyph band on a face (CityStone `runes`).
	func runes(a: Vector3, b: Vector3, up: Vector3, normal: Vector3, height := Stone.RUNE_H) -> void:
		m.runes(a,b,up,normal,float(rng.randi_range(1,9999)),height)

	## A walked top to dress (ground cover, grass): `kind`, its outline
	## (piece-local x, z, a convex or simple polygon), its y (`y1` the far
	## end's, a flight's slope, else the same).
	func area(kind: String, outline: Array, y: float, y1 := NAN) -> void:
		var poly := PackedVector2Array()
		for q: Vector2 in outline: poly.append(q)
		(meta.walk_areas as Array).append({"kind":kind,"poly":poly,"y":y,"y1":y if is_nan(y1) else y1})

	func rect_area(kind: String, r: Rect2, y: float, y1 := NAN) -> void:
		area(kind,[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)],y,y1)

	func cresset(at: Vector3) -> void:
		(meta.mounts.cresset as Array).append(at)

	## The piece, its mesh and body in.
	func finish() -> Node3D:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var kind := "stair" if String(root.name).ends_with("Stair") else ("span" if root.name == "CityCauseway" else "pier")
		mesh.mesh = Stone.mesh_of(m,kind)
		root.add_child(mesh)
		root.add_child(body)
		for k: String in meta: root.set_meta(k,meta[k])
		root.set_meta("kit","city")
		root.set_meta("triangles",m.triangles())
		return root

## A breakable unit's piece: its own mesh (built in its own frame, the
## grain kept as in place) and shapes, in the unit (`unit`, a Node3D with a
## "Body"). `xf` the piece's place in the unit; `shapes` [[Shape3D, local xf]].
static func _unit_piece(unit: Node3D, index: int, xf: Transform3D, mesher: Stone.Mesher, shapes: Array) -> void:
	var holder := Node3D.new()
	holder.name = "P%d" % index
	holder.transform = xf
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = Stone.mesh_of(mesher,"break")
	holder.add_child(mi)
	unit.add_child(holder)
	var body: StaticBody3D = unit.get_node("Body")
	var k := 0
	for s: Array in shapes:
		var cs := CollisionShape3D.new()
		cs.name = "P%d_%d" % [index,k]
		cs.shape = s[0]
		cs.transform = xf*(s[1] as Transform3D)
		body.add_child(cs)
		k += 1

static func _new_unit(node_name: String, xf: Transform3D) -> Node3D:
	var unit: Node3D = FloorBreak.new()
	unit.name = node_name
	unit.transform = xf
	var body := StaticBody3D.new()
	body.name = "Body"
	unit.add_child(body)
	return unit

## A breakable unit (scripts/city_breaks/floor_break.gd) told what it is.
static func _arm(unit: Node3D, d: Dictionary) -> void:
	unit.set("kind",d.kind)
	unit.set("count",d.pieces)
	unit.set("box",d.box)
	unit.set("weight",d.weight)
	unit.set("kg",d.kg)

static func _box_shape(h: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = h*2.0
	return s

# --- The pillar-isle ------------------------------------------------------------------

## The pillar-isle (ol_pillar). y 0 its crown; the shaft goes down out of
## sight. Opts:
##   apothem   the crown's (PILLAR_APOTHEM)
##   courses   collar courses down the flank (COURSES); each one LEDGE out
##             from the one over it, COURSE tall, talud under tablero
##   depth     the shaft's foot under the crown (SHAFT_DEPTH)
##   climb     the face (0-5, hex_dir) its prism chain climbs (1), -1 none
##   well      a round well's radius in the crown (0 none; a drum stair's
##             DRUM_RADIUS), `well_depth` deep (a drum's turns x COURSE)
##   crown     "paved" (a stepped dais in the middle, streets round it),
##             "bare" (CROWN_SOIL under y 0: a KitLand turf top goes on it,
##             `crown_outline`), "flat"
## His: walks the crown (streets >= 6 m, `ports.crown`), climbs any flank
## to it (collar ledges are under his 2 m shelf rule: he climbs on past);
## never stands on a collar. The wanderer: every collar a ring to walk,
## the climb face's prisms a set-off chain from collar to collar.
static func pillar(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := Piece.new("CityPillar",seed_value,weathered)
	var a: float = opts.get("apothem",PILLAR_APOTHEM)
	var courses: int = opts.get("courses",COURSES)
	var depth: float = maxf(float(opts.get("depth",SHAFT_DEPTH)),(courses+1)*COURSE+2.0)
	var climb: int = opts.get("climb",1)
	var well: float = opts.get("well",0.0)
	var well_depth: float = opts.get("well_depth",DRUM_TURNS*COURSE)
	var crown: String = opts.get("crown","paved")
	var top0 := -CROWN_SOIL if crown == "bare" else 0.0
	for k in range(courses+1):
		var hi := top0 if k == 0 else -k*COURSE
		var lo := -depth if k == courses else -(k+1)*COURSE
		var ak := a+k*LEDGE
		var talud_top := lo+SET_OFF if k < courses else lo
		var holed := well > 0.0 and hi > -well_depth+0.01
		var parts: Array = []
		# The tablero: plumb, the course's upper part.
		parts.append(hex_planes(ak)+slab(talud_top,hi))
		# The talud: its foot BATTER out, leaning in to the tablero.
		if k < courses:
			var t: Array = slab(lo,talud_top)
			var lean := atan2(BATTER,SET_OFF)
			for f in 6:
				var nl := (hex_dir(f)*cos(lean)+Vector3.UP*sin(lean)).normalized()
				t.append(Plane(nl,nl.dot(hex_dir(f)*(ak+BATTER)+Vector3.UP*lo)))
			parts.append(t)
		# Drawn as talud and tablero, a course on the one under it. Collided
		# as columns, never stacked (`_pillar_columns`).
		var sectors: Array = [[]]
		if holed:
			sectors = []
			for s in range(24):
				var a0 := TAU*s/24.0
				var a1 := TAU*(s+1)/24.0
				var cut: Array = wedge(a0,a1)
				cut.append(chord(dir(a0)*well,dir(a1)*well,true))
				sectors.append(cut)
		for cut: Array in sectors:
			for planes: Array in parts:
				b.block(planes+cut,false,null,(0.5 if holed else (0.4 if k < courses else 0.15)))
		# A glyph band round each tablero (the drum courses' frieze).
		if k < courses or k == 0:
			var band_y := (talud_top+hi)*0.5-0.4 if k < courses else hi-2.2
			var half := ak*tan(PI/6.0)*0.82
			for f in 6:
				var d := hex_dir(f)
				var t := Vector3(d.z,0.0,-d.x)
				b.runes(d*ak+t*half+Vector3.UP*band_y,d*ak-t*half+Vector3.UP*band_y,Vector3.UP,d)
		# A fire bowl at each collar's corners on the climb side.
		if k >= 1 and climb >= 0:
			for f in [climb,(climb+1)%6]:
				var corner := (hex_dir(f)+hex_dir(f-1)).normalized()*(ak-LEDGE*0.5)/cos(PI/6.0)
				b.cresset(corner+Vector3.UP*hi)
	_pillar_columns(b,a,courses,depth,top0,well,well_depth)
	# The organ pipes: the shaft under the collars is fluted with columns
	# half sunk in its faces, their tops broken at many heights: basalt's
	# columns, the silhouette's flutes.
	var deep_a := a+courses*LEDGE
	var below := -courses*COURSE-COURSE
	for f in 6:
		var d := hex_dir(f)
		var t := Vector3(d.z,0.0,-d.x)
		var half := deep_a*tan(PI/6.0)
		var x := -half+1.2
		while x < half-1.2:
			var r := b.rng.randf_range(1.0,2.2)
			var top := lerpf(below,-depth*0.55,pow(b.rng.randf(),1.5))
			var xf := Transform3D(Basis(Vector3.UP,TAU*f/6.0+PI/6.0),d*(deep_a+r*0.35)+t*x+Vector3.UP*(-depth))
			b.block(Stone.drum(xf,6,r,r,top+depth,0.15),false,null,0.4)
			x += r*1.75
	# The climb face's chain: on each collar's ledge, two prisms against the
	# course over it, a set-off and two up, then the collar's own lip.
	# Walker-only (scripts/walker_only.gd): high on a wall he climbs past.
	if climb >= 0:
		var chain := StaticBody3D.new()
		chain.name = "ClimbChain"
		WalkerOnly.mark(chain)
		var d := hex_dir(climb)
		var t := Vector3(d.z,0.0,-d.x)
		var steps: Array = []
		for k in range(courses,0,-1):
			var y := -k*COURSE
			var a_over := a+(k-1)*LEDGE
			var side := 1.0 if k%2 == 0 else -1.0
			var at := a_over*tan(PI/6.0)*0.3*side
			for j: int in [1,2]:
				var centre := d*(a_over+BATTER+PRISM)+t*(at+side*(j-1)*2.0*PRISM)
				var xf := Transform3D(Basis(Vector3.UP,TAU*climb/6.0+PI/6.0),centre+Vector3.UP*y)
				var top := j*SET_OFF
				b.block(Stone.drum(xf,6,PRISM,PRISM,top,0.08),true,chain,0.3)
				steps.append(centre+Vector3.UP*(y+top))
		b.root.add_child(chain)
		b.meta.ports["climb_steps"] = steps
		b.meta.ports["climb_foot"] = d*(a+courses*LEDGE-LEDGE*0.45)+Vector3.UP*(-courses*COURSE)
	# The crown.
	if crown == "paved" and well <= 0.0:
		var dais := [[0.42,SET_OFF],[0.26,2.0*SET_OFF]]
		for tier: Array in dais:
			var ta := a*float(tier[0])
			b.block(hex_planes(ta)+slab(float(tier[1])-SET_OFF,float(tier[1])),true,null,0.6,null,[over(float(tier[1])-SET_OFF)])
			var half := ta*tan(PI/6.0)*0.7
			for f in 6:
				var dd := hex_dir(f)
				var tt := Vector3(dd.z,0.0,-dd.x)
				b.runes(dd*ta+tt*half+Vector3.UP*(float(tier[1])-SET_OFF+0.35),dd*ta-tt*half+Vector3.UP*(float(tier[1])-SET_OFF+0.35),Vector3.UP,dd,0.7)
		b.meta.ports["dais"] = Vector3.UP*2.0*SET_OFF
		b.meta.ports["crown"] = dir(0.0)*a*0.7
	else:
		b.meta.ports["crown"] = dir(0.0)*(a-maxf(well,0.0))*0.5+dir(0.0)*maxf(well,0.0)
	for f in 6:
		var corner := (hex_dir(f)+hex_dir(f+1)).normalized()*(a-3.0)/cos(PI/6.0)
		b.cresset(corner+Vector3.UP*top0)
	b.meta.ports["well"] = well
	# Its walked tops: the crown (round a well, a sector a face) and each
	# collar's ledge ring (a quad a face).
	for f in 6:
		var c0 := (hex_dir(f)+hex_dir(f-1)).normalized()*a/cos(PI/6.0)
		var c1 := (hex_dir(f)+hex_dir(f+1)).normalized()*a/cos(PI/6.0)
		var poly: Array = [Vector2(c0.x,c0.z),Vector2(c1.x,c1.z)]
		if well > 0.0:
			var a1 := TAU*f/6.0+PI/6.0
			for k in range(9):
				var q := dir(a1-PI/3.0*k/8.0)*well
				poly.append(Vector2(q.x,q.z))
		else:
			poly.append(Vector2.ZERO)
		b.area("crown",poly,top0)
		for k in range(1,courses+1):
			var lo_a := a+(k-1)*LEDGE+BATTER
			var hi_a := a+k*LEDGE
			var p0 := (hex_dir(f)+hex_dir(f-1)).normalized()/cos(PI/6.0)
			var p1 := (hex_dir(f)+hex_dir(f+1)).normalized()/cos(PI/6.0)
			b.area("collar",[Vector2(p0.x,p0.z)*lo_a,Vector2(p1.x,p1.z)*lo_a,Vector2(p1.x,p1.z)*hi_a,Vector2(p0.x,p0.z)*hi_a],-k*COURSE)
	b.meta.his = {"walks":"the crown (its ring %.1f m round a well, else streets %.1f m round the dais)" % [a-well,a*0.58],"climbs":"any flank, collar to crown (ledges %.1f m: under his shelf rule, he climbs past)" % LEDGE,"never":"stands on a collar"}
	b.root.set_meta("apothem",a)
	b.root.set_meta("courses",courses)
	return b.finish()

## The pillar's collision as columns side by side, each one top only,
## never a course stood on the one under it: the crown (round its well, the
## well's floor under it) and each collar's ring a trapezoid a face, all down
## to the shaft's foot; each course's talud a sloped band on the ring under
## it, GAP over it. (A course stood on the next leaves that one's top inside
## the stone, which the body's route reads as a floor with all the room in
## the world; a GAP between them is a slit his climb reads as a lip.)
static func _pillar_columns(b: Piece, a: float, courses: int, depth: float, top0: float, well: float, well_depth: float) -> void:
	var foot := -depth
	if well > 0.0:
		for s in range(24):
			var a0 := TAU*s/24.0
			var a1 := TAU*(s+1)/24.0
			var p: Array = hex_planes(a)+slab(foot,top0)+wedge(a0,a1)
			p.append(chord(dir(a0)*well,dir(a1)*well,true))
			b.hull(Geometry3D.compute_convex_mesh_points(_typed(p)))
		b.hull(Geometry3D.compute_convex_mesh_points(_typed(Stone.drum(Transform3D(Basis.IDENTITY,Vector3.UP*foot),24,well,well,-well_depth-foot))))
	else:
		b.hull(Geometry3D.compute_convex_mesh_points(_typed(hex_planes(a)+slab(foot,top0))))
	var lean := atan2(BATTER,SET_OFF)
	for k in range(1,courses+1):
		var a_in := a+(k-1)*LEDGE
		var a_out := a+k*LEDGE
		var top := -k*COURSE
		for f in 6:
			var d := hex_dir(f)
			var w: Array = wedge(TAU*f/6.0-PI/6.0,TAU*f/6.0+PI/6.0)
			b.hull(Geometry3D.compute_convex_mesh_points(_typed([Plane(d,a_out),Plane(-d,-a_in)]+w+slab(foot,top))))
			# The talud of the course over this ring, at its foot.
			var nl := (d*cos(lean)+Vector3.UP*sin(lean)).normalized()
			var t: Array = [Plane(nl,nl.dot(d*(a_in+BATTER)+Vector3.UP*top)),Plane(-d,-a_in)]+w+slab(top+GAP,top+SET_OFF)
			b.hull(Geometry3D.compute_convex_mesh_points(_typed(t)))

## A pillar's crown as an outline (x, z) for KitLand.island: its hex inset
## `inset` m (the turf's lip tucked inside the top course). With the
## pillar's `crown` "bare" and `well` 0, a motif lays its turf top on it:
##   KitLand.island({"outline": CityKit.crown_outline(a), "ground": flat 0,
##                   "top": 0, "depth": COURSE*0.6, "tone": KitLook.turf(...)})
static func crown_outline(apothem := PILLAR_APOTHEM, inset := 1.4) -> Array:
	var out: Array = []
	var r := (apothem-inset)/cos(PI/6.0)
	for k in 6:
		var a := TAU*k/6.0+PI/6.0
		out.append(Vector2(sin(a),cos(a))*r)
	return out

# --- The drum stair --------------------------------------------------------------------

## The drum stair (ol_drum_stair): a stair wound down a round well as an
## inward spiral. y 0 its rim; turn by turn it goes COURSE down and LANE in,
## to a core floor `turns` x COURSE down. Every point of a turn's inner edge
## stands COURSE over the turn below (under the fall stun): falling off the
## inside lands on the next turn standing. Nothing roofs any turn, so his
## headroom is the sky. Opts:
##   radius   the well's (DRUM_RADIUS); turns (DRUM_TURNS); lane (LANE)
##   rim      true: its own ring DRUM_RIM wide (a standing drum); false: set
##            in a pillar's well (`pillar` opts well = radius)
## His: walks every turn down and up (LANE wide, a step each 30 degrees),
## drops a turn on purpose (COURSE), climbs one back. The wanderer: runs it,
## drops a turn to cut it short (the fall inward), climbs a turn back (a
## COURSE wall: no; she takes the stair).
static func drum_stair(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := Piece.new("CityDrumStair",seed_value,weathered)
	var w: float = opts.get("radius",DRUM_RADIUS)
	var turns: int = opts.get("turns",DRUM_TURNS)
	var lane: float = opts.get("lane",LANE)
	var rim: bool = opts.get("rim",true)
	var segs := DRUM_SEGMENTS*turns
	var bottom := -turns*COURSE
	var foot := bottom-SET_OFF
	var r_out := func(th: float) -> float: return w-lane*th/TAU
	var top_of := func(j: int) -> float: return -RISER*floori(j*DRUM_STEPS/float(DRUM_SEGMENTS))
	var path: Array = []
	for j in range(segs):
		var a0 := TAU*j/DRUM_SEGMENTS
		var a1 := TAU*(j+1)/DRUM_SEGMENTS
		var o0: float = r_out.call(a0)
		var o1: float = r_out.call(a1)
		var y: float = top_of.call(j)
		var wa0 := fposmod(a0,TAU)
		var wa1 := wa0+(a1-a0)
		var p: Array = wedge(wa0,wa1)+slab(foot,y)
		p.append(chord(dir(wa0)*o0,dir(wa1)*o1,false))
		p.append(chord(dir(wa0)*(o0-lane),dir(wa1)*(o1-lane),true))
		b.block(p,true,null,0.6,null,[over(bottom)])
		path.append(dir((wa0+wa1)*0.5)*((o0+o1)*0.5-lane*0.5)+Vector3.UP*y)
		# The wall over the turn below (its inner face): a glyph band on
		# every other segment, a third of the way up.
		if j+DRUM_SEGMENTS < segs and j%2 == 0:
			var i0 := dir(wa0)*(o0-lane)
			var i1 := dir(wa1)*(o1-lane)
			var nrm := -((i0+i1)*0.5).normalized()
			b.runes(i1+Vector3.UP*(y-COURSE*0.62),i0+Vector3.UP*(y-COURSE*0.62),Vector3.UP,nrm,0.7)
		# Turn 0's outer wall up to the rim.
		if j < DRUM_SEGMENTS and w-o1 > 0.3:
			var q: Array = wedge(wa0,wa1)+slab(foot,0.0)
			q.append(chord(dir(wa0)*w,dir(wa1)*w,false))
			q.append(chord(dir(wa0)*o0,dir(wa1)*o1,true))
			b.block(q,true,null,0.5,null,[over(bottom)])
	# The core floor.
	var core: float = r_out.call(TAU*(turns-1))-lane
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,Vector3.UP*foot),24,core/cos(PI/24.0),core/cos(PI/24.0),bottom-foot,0.05),true,null,0.2)
	if rim:
		for s in range(24):
			var a0 := TAU*s/24.0
			var a1 := TAU*(s+1)/24.0
			var q: Array = wedge(a0,a1)+slab(foot,0.0)
			q.append(chord(dir(a0)*(w+DRUM_RIM),dir(a1)*(w+DRUM_RIM),false))
			q.append(chord(dir(a0)*w,dir(a1)*w,true))
			b.block(q,true,null,0.6,null,[over(bottom)])
	b.cresset(dir(PI)*core*0.45+Vector3.UP*bottom)
	for k in 4: b.cresset(dir(TAU*k/4.0+PI/4.0)*(w+0.6)+Vector3.UP*0.0)
	# Its walked tops: each segment of each turn (a quad at its step's y).
	for j in range(segs):
		var a0 := TAU*j/DRUM_SEGMENTS
		var a1 := TAU*(j+1)/DRUM_SEGMENTS
		var o0: float = r_out.call(a0)
		var o1: float = r_out.call(a1)
		var pts: Array = []
		for q: Vector3 in [dir(a0)*o0,dir(a1)*o1,dir(a1)*(o1-lane),dir(a0)*(o0-lane)]: pts.append(Vector2(q.x,q.z))
		b.area("turn",pts,top_of.call(j))
	b.meta.ports["rim"] = dir(0.0)*(w-lane*0.5)
	b.meta.ports["bottom"] = dir(PI)*core*0.5+Vector3.UP*bottom
	b.meta.ports["path"] = path
	b.meta.his = {"walks":"every turn (%.1f m wide, %d steps a turn)" % [lane,DRUM_STEPS],"drops":"a turn on purpose (%.1f m)" % COURSE,"headroom":"open sky over every turn"}
	b.root.set_meta("radius",w)
	b.root.set_meta("turns",turns)
	return b.finish()

## Where on the drum stair's turn `turn` at angle `angle` (rad, 0 toward
## +Z): [the walk top's y, the inner edge's radius, the outer edge's].
static func drum_at(turn: int, angle: float, radius := DRUM_RADIUS, lane := LANE) -> Array:
	var th := TAU*turn+fposmod(angle,TAU)
	var j := floori(th/(TAU/DRUM_SEGMENTS))
	var y := -RISER*floori(j*DRUM_STEPS/float(DRUM_SEGMENTS))
	var o := radius-lane*th/TAU
	return [y,o-lane,o]

# --- The epic stair ---------------------------------------------------------------------

## The epic stair (city_stair + oc_proc + kukul_balustrade +
## maker_stairfault). y 0 its foot; it climbs toward -Z in `flights` of
## STAIR_STEPS (a COURSE each), LANE wide, a LANDING deep between flights and
## at the summit, between serpent cheek walls CHEEK wide whose crest runs
## CREST over the nosings (eased over each landing, one unbroken slope: the
## rail, "Rail_L"/"Rail_R", slid crouched) down onto a serpent head at the
## foot, its snout a launch. A stepped pyramid FLANK either side (talud
## under tablero, a course a tier). Opts:
##   flights (STAIR_FLIGHTS), flank (FLANK; 0 none), heads (true)
##   fault   a landing (1-based) built as a breakable slab over a chamber a
##           COURSE deep (0 none): he stands on it and it drops in quarters
##           (scripts/kit_isle/city_breaks.gd); the chamber's back wall is a
##           set-off chain for the wanderer, a climb for him.
## His: walks every flight and landing (LANE, LANDING); in the broken fault
## he drops into the chamber and climbs out. The wanderer: runs it, climbs
## or hops onto a cheek, slides the crest down, the flank tiers.
static func stair(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := Piece.new("CityStair",seed_value,weathered)
	var flights: int = opts.get("flights",STAIR_FLIGHTS)
	var flank: float = opts.get("flank",FLANK)
	var heads: bool = opts.get("heads",true)
	var fault: int = opts.get("fault",0)
	var hw := LANE*0.5
	var run := STAIR_STEPS*TREAD
	var length := flights*run+(flights-1)*LANDING+LANDING
	var top := flights*COURSE
	var crest_pts: Array = []
	var z := 0.0
	var landings: Array = []
	for f in range(1,flights+1):
		var base := (f-1)*COURSE
		for i in range(1,STAIR_STEPS+1):
			var z0 := z-(i-1)*TREAD
			var y := base+i*RISER
			var zc := z0-TREAD*0.5
			# The tread stone: a riser and a little more, its foot hidden.
			var hs := Vector3(hw,(RISER+0.3)*0.5,TREAD*0.5+0.02)
			b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,y-hs.y,zc)),hs,0.06),false,null,0.5)
			b.walk_column(Rect2(-hw,zc-TREAD*0.5,hw*2.0,TREAD),0.0,y)
			if i == 1: crest_pts.append(Vector3(0.0,y+CREST,z0))
			if i == STAIR_STEPS: crest_pts.append(Vector3(0.0,y+CREST,z0))
		z -= run
		var deep := LANDING
		var lz := z-deep*0.5
		landings.append(Vector3(0.0,f*COURSE,lz))
		b.rect_area("summit" if f == flights else ("fault" if f == fault else "landing"),Rect2(-hw,lz-deep*0.5,hw*2.0,deep),f*COURSE)
		b.rect_area("flight",Rect2(-hw,z,hw*2.0,run),(f-1)*COURSE,f*COURSE)
		if f == fault and f < flights:
			_fault(b,f,z,deep,hw)
		else:
			var hs := Vector3(hw,0.4,deep*0.5)
			b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,f*COURSE-0.4,lz)),hs,0.08),false,null,0.6)
			b.walk_column(Rect2(-hw,lz-deep*0.5,hw*2.0,deep),0.0,f*COURSE)
			if f < flights:
				# A glyph panel sunk in the landing (k1): carved, dark.
				b.runes(Vector3(hw*0.6,f*COURSE+0.01,lz+1.0),Vector3(-hw*0.6,f*COURSE+0.01,lz+1.0),Vector3.FORWARD,Vector3.UP,1.4)
		z -= deep
	var summit_front := z+LANDING
	# The crest: over the head's snout, up the flights, eased over the
	# landings, then down to MOUNT over the summit RAMP back.
	var line: Array = []
	if heads: line.append(Vector3(0.0,RISER+CREST*0.8,HEAD_LENGTH))
	line.append_array(crest_pts)
	var last: Vector3 = line[line.size()-1]
	line.append(Vector3(0.0,top+MOUNT,last.z-RAMP))
	for side: float in [-1.0,1.0]:
		var rail := StaticBody3D.new()
		rail.name = "Rail_L" if side < 0.0 else "Rail_R"
		var x0 := side*hw
		var x1 := side*(hw+CHEEK)
		var lo := minf(x0,x1)
		var hi := maxf(x0,x1)
		var pts := PackedVector3Array()
		for k in range(line.size()-1):
			var p: Vector3 = line[k]
			var q: Vector3 = line[k+1]
			if heads and k == 0:
				_head(b,side,hw,p,q,rail)
				pts.append(Vector3((lo+hi)*0.5,p.y,p.z))
				continue
			# The cheek's block: its top the crest from p to q, down to the
			# ground (the flank's tier, or y 0).
			var nrm := Vector3(0.0,q.z-p.z,-(q.y-p.y)).normalized()
			if nrm.y < 0.0: nrm = -nrm
			var planes: Array = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.BACK,p.z),Plane(Vector3.FORWARD,-q.z),Plane(Vector3.DOWN,0.0),Plane(nrm,nrm.dot(p))]
			b.block(planes,false,null,0.4)
			b.hull(Geometry3D.compute_convex_mesh_points(_typed(planes+[over(0.0)])),rail)
			pts.append(Vector3((lo+hi)*0.5,p.y,p.z))
			# The serpent's scales: a carved band down its outer face.
			if absf(q.z-p.z) > 2.0:
				var face := Vector3(hi if side > 0.0 else lo,0.0,0.0)
				b.runes(face+Vector3(0.0,p.y-1.15,p.z),face+Vector3(0.0,q.y-1.15,q.z),Vector3.UP,Vector3(side,0.0,0.0),0.7)
		var end: Vector3 = line[line.size()-1]
		pts.append(Vector3((lo+hi)*0.5,end.y,end.z))
		b.root.add_child(rail)
		(b.meta.rails as Array).append({"body":String(rail.name),"points":pts})
		# Under the crest's eased end: the summit's cheek strip.
		var cz0 := end.z
		var hs := Vector3((hi-lo)*0.5,top*0.5,(cz0-(-length))*0.5)
		b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3((lo+hi)*0.5,top*0.5,(cz0+(-length))*0.5)),hs,0.05),false,null,0.3)
		b.walk_column(Rect2(lo,-length,hi-lo,cz0+length),0.0,top)
	# The flanks: a tier a course, its front face over the landing it
	# stands beside, talud under tablero.
	if flank > 0.0:
		for side: float in [-1.0,1.0]:
			var x0 := side*(hw+CHEEK)
			var x1 := side*(hw+CHEEK+flank)
			var lo := minf(x0,x1)
			var hi := maxf(x0,x1)
			for f in range(1,flights+1):
				var y0 := (f-1)*COURSE
				var y1 := f*COURSE
				var front := -(f*run+(f-1)*LANDING)
				var lean := atan2(BATTER,SET_OFF)
				var nl := Vector3(0.0,sin(lean),cos(lean))
				var talud: Array = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.FORWARD,length),Plane(Vector3.DOWN,-y0),Plane(Vector3.UP,y0+SET_OFF),Plane(nl,nl.dot(Vector3(0.0,y0,front+BATTER)))]
				b.block(talud,false,null,0.4)
				var tablero: Array = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.FORWARD,length),Plane(Vector3.BACK,front),Plane(Vector3.DOWN,-(y0+SET_OFF)),Plane(Vector3.UP,y1)]
				b.block(tablero,false,null,0.6)
				# Collided as a column from the ground over its own strip (the
				# next tier's front to its own: no tier stood on another), its
				# talud a sloped band on the tier under it, GAP over it.
				var back := -length if f == flights else -((f+1)*run+f*LANDING)
				b.hull(Geometry3D.compute_convex_mesh_points(_typed([Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.FORWARD,-back),Plane(Vector3.BACK,front)]+slab(GAP,y1))))
				b.hull(Geometry3D.compute_convex_mesh_points(_typed(talud+[over(y0)]+[Plane(Vector3.FORWARD,-front)])))
				b.runes(Vector3(lo+0.6,y0+SET_OFF+0.9,front+0.01),Vector3(hi-0.6,y0+SET_OFF+0.9,front+0.01),Vector3.UP,Vector3.BACK)
				b.rect_area("tier",Rect2(lo,-length,hi-lo,front+length),y1)
				# The outer side, a plain face with its own band.
				var ox := hi if side > 0.0 else lo
				b.runes(Vector3(ox,y0+SET_OFF+0.9,front-0.6),Vector3(ox,y0+SET_OFF+0.9,-length+0.6),Vector3.UP,Vector3(side,0.0,0.0))
			b.cresset(Vector3(side*(hw+CHEEK+flank*0.5),top,-length+2.0))
	for l: Vector3 in landings: b.cresset(l+Vector3(hw-0.6,0.0,LANDING*0.5-0.8))
	var full := hw+CHEEK+maxf(flank,0.0)
	b.meta.ports["foot"] = Vector3(0.0,0.0,HEAD_LENGTH+2.0)
	b.meta.ports["summit"] = Vector3(0.0,top,summit_front-LANDING*0.5)
	b.meta.ports["summit_edge"] = Vector3(0.0,top,-length)
	b.meta.ports["landings"] = landings
	b.meta.his = {"walks":"every flight (%.1f m) and landing (%.1f x %.1f)" % [LANE,LANE,LANDING],"breaks":"the fault landing, standing on it" if fault > 0 else "nothing","in the fault":"drops in (%.1f m), climbs the back wall out" % COURSE}
	b.root.set_meta("length",length)
	b.root.set_meta("top",top)
	b.root.set_meta("width",full*2.0)
	return b.finish()

## The fault: landing `f` (its front at `z`, `deep` long) a slab in four
## quarters over a chamber a COURSE deep; the slab its own unit ("Fault").
static func _fault(b: Piece, f: int, z: float, deep: float, hw: float) -> void:
	var top := f*COURSE
	var floor_y := (f-1)*COURSE
	var lz := z-deep*0.5
	var thick := 2.0*RISER
	# The chamber: its floor, its back wall's set-off ledges (to the next
	# flight's first tread, RISER over the landing), its walls drawn (the
	# treads' boxes go down to y 0 round it).
	if floor_y > 0.0:
		b.walk_column(Rect2(-hw,lz-deep*0.5,hw*2.0,deep),0.0,floor_y)
	b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,floor_y-0.3,lz)),Vector3(hw,0.3,deep*0.5),0.05),false,null,0.3)
	var lip := top+RISER-floor_y
	# The ledges are the wanderer's (walker-only: he climbs the wall
	# behind them in one go; a 1 m ledge mid-climb threw him off it).
	var ledges := StaticBody3D.new()
	ledges.name = "ChamberLedges"
	WalkerOnly.mark(ledges)
	b.root.add_child(ledges)
	for k: int in [1,2]:
		var y := floor_y+lip*k/3.0
		# Each its own strip out from the wall (none buried under another).
		var hs := Vector3(hw,0.5*(y-floor_y),0.45)
		var at := Vector3(0.0,floor_y+hs.y,z-deep+0.45+0.9*(2-k))
		b.block(Stone.box(Transform3D(Basis.IDENTITY,at),hs,0.05),true,ledges,0.4,null,[over(floor_y)])
	for zz: float in [z,z-deep]:
		var face := Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,(floor_y+top-thick)*0.5,zz+(0.3 if zz == z else -0.3))),Vector3(hw,(top-thick-floor_y)*0.5,0.3),0.04)
		b.block(face,false,null,0.4)
	# The slab, in quarters (each its own mesh), pre-cracked.
	var unit := _new_unit("Fault",Transform3D(Basis.IDENTITY,Vector3(0.0,top,lz)))
	var k := 0
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			var hs := Vector3(hw*0.5-0.03,thick*0.5,deep*0.25-0.03)
			var at := Vector3(sx*hw*0.5,-thick*0.5,sz*deep*0.25)
			var mesher := Stone.Mesher.new(Stone.stone_colour())
			mesher.rest_frame = Transform3D(Basis.IDENTITY,Vector3(0.0,top,lz)+at)
			b.block(Stone.box(Transform3D.IDENTITY,hs,0.05),false,null,0.8,mesher)
			_unit_piece(unit,k,Transform3D(Basis.IDENTITY,at),mesher,[[_box_shape(Vector3(hw*0.5+SEAM,thick*0.5,deep*0.25+SEAM)),Transform3D.IDENTITY]])
			k += 1
	b.root.add_child(unit)
	(b.meta.breaks as Array).append({"kind":"fault","unit":"Fault","pieces":k,"box":AABB(Vector3(-hw,-thick,-deep*0.5),Vector3(hw*2.0,thick,deep)),
		"top":0.0,"kg":STONE_KG*hw*thick*deep*0.5,"weight":0.5,"drop":top-floor_y})
	_arm(unit,(b.meta.breaks as Array)[-1])

## A serpent head at a cheek's foot (side -1 left, 1 right): its brow
## carries the crest from `q` (the first nosing's) down to `p` (the snout);
## jaws open, a fang each side, heavy brows. Its top is the rail's end.
static func _head(b: Piece, side: float, hw: float, p: Vector3, q: Vector3, rail: StaticBody3D) -> void:
	var w := CHEEK*0.5+0.5
	# Out of the lane: its inner jowl flush with the cheek's inner face.
	var cx := side*(hw+w)
	var lo := cx-w
	var hi := cx+w
	var mouth := Vector2(0.55,1.15)
	# The skull: from the first nosing forward to the snout, over the open
	# mouth, its top the crest (the rail runs down onto it and off its snout).
	var nrm := Vector3(0.0,q.z-p.z,-(q.y-p.y)).normalized()
	if nrm.y < 0.0: nrm = -nrm
	var skull: Array = [Plane(Vector3.LEFT,-lo),Plane(Vector3.RIGHT,hi),Plane(Vector3.BACK,p.z),Plane(Vector3.FORWARD,-q.z),Plane(Vector3.DOWN,-mouth.y),Plane(nrm,nrm.dot(p))]
	# Its jowls rounded off: the lower front and side edges cut.
	for s: float in [-1.0,1.0]:
		var cut := Vector3(s,-0.8,0.0).normalized()
		skull.append(Plane(cut,cut.dot(Vector3(cx+s*w,mouth.y+0.45,0.0))))
	var snout_cut := Vector3(0.0,-0.6,1.0).normalized()
	skull.append(Plane(snout_cut,snout_cut.dot(Vector3(0.0,mouth.y,p.z-0.05))))
	b.block(skull,false,null,0.3)
	b.hull(Geometry3D.compute_convex_mesh_points(_typed(skull)),rail)
	# The lower jaw: a broad step out under the open mouth.
	var jaw: Array = Stone.box(Transform3D(Basis.IDENTITY,Vector3(cx,mouth.x*0.5,(p.z+q.z)*0.5+0.3)),Vector3(w-0.08,mouth.x*0.5,(p.z-q.z)*0.5+0.3),0.12)
	b.block(jaw,true,rail,0.3,null,[over(0.0)])
	# The throat behind the open mouth, set back and dark.
	var throat: Array = Stone.box(Transform3D(Basis.IDENTITY,Vector3(cx,(mouth.x+mouth.y)*0.5,q.z+0.7)),Vector3(w-0.15,(mouth.y-mouth.x)*0.5,0.7),0.04)
	b.m.solid(throat,NAN,0.6)
	b.hull(Geometry3D.compute_convex_mesh_points(_typed(throat+[over(mouth.x)])),rail)
	for s: float in [-1.0,1.0]:
		# A fang down from the upper jaw at each corner of the mouth.
		var at := Vector3(cx+s*(w-0.3),mouth.y,p.z-0.45)
		var lean := Vector3(0.0,-1.0,0.25).normalized()
		var fang: Array = [Plane(Vector3.LEFT,-(at.x-0.13)),Plane(Vector3.RIGHT,at.x+0.13),Plane(Vector3.BACK,at.z+0.12),Plane(Vector3.FORWARD,-(at.z-0.16)),Plane(Vector3.UP,mouth.y+0.02),Plane(lean,lean.dot(at+Vector3.DOWN*0.42))]
		b.block(fang,false,null,0.0)
		# A heavy brow over each eye (outside the rail's width), the eye a
		# dark socket under it.
		var bz := lerpf(p.z,q.z,0.62)
		var by := lerpf(p.y,q.y,0.62)
		var brow: Array = Stone.box(Transform3D(Basis(Vector3.RIGHT,-0.18),Vector3(cx+s*(w-0.18),by+0.12,bz)),Vector3(0.22,0.22,0.62),0.1)
		b.block(brow,false,null,0.5)
		var eye: Array = Stone.box(Transform3D(Basis.IDENTITY,Vector3(cx+s*(w+0.01),by-0.32,bz-0.05)),Vector3(0.06,0.17,0.28),0.03)
		b.m.solid(eye,NAN,0.55)

# --- The causeway ----------------------------------------------------------------------

## The causeway (ol_causeway + city_aqueduct + maker_causeway). y 0 its
## deck; it runs from z 0 toward -Z, `spans` of SPAN between piers (none at
## its ends: it rests on the isles it joins), DECK wide between parapets a
## set-off tall. Each pier is battered, PIER square at its head, PIER_DROP
## down into the haze, corbels stepping in from its head (the openings a
## comb of stepped false arches, their tops about 14 m clear). Opts:
##   spans (SPANS), drop (PIER_DROP), end_piers (false)
##   bay     a span (0-based) whose middle third ("Bay", two cells) breaks:
##           he stands on it and it drops in four slabs onto whatever road
##           lies under it (the motif's), leaving a gap he leaps and the
##           wanderer sails (-1 none).
## His: walks the deck its whole length (9.4 m clear); leaps the broken
## bay; drops with it. The wanderer: runs the deck and its parapets.
static func causeway(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := Piece.new("CityCauseway",seed_value,weathered)
	var spans: int = opts.get("spans",SPANS)
	var drop: float = opts.get("drop",PIER_DROP)
	var end_piers: bool = opts.get("end_piers",false)
	var bay: int = opts.get("bay",-1)
	var hw := DECK*0.5
	var third := SPAN/3.0
	var length := spans*SPAN
	for s in range(spans):
		for part in 3:
			var z1 := -s*SPAN-part*third
			var z0 := z1-third
			var mid := (z0+z1)*0.5
			if s == bay and part == 1:
				_bay(b,s,mid,third,hw)
				continue
			# The deck: two paving slabs along, a parapet run each side.
			for k in 2:
				var zc := z1-third*0.25-third*0.5*k
				b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-DECK_THICK*0.5,zc)),Vector3(hw-PARAPET.x,DECK_THICK*0.5,third*0.25-0.01),0.06),false,null,0.5)
				for side: float in [-1.0,1.0]:
					var px := side*(hw-PARAPET.x*0.5)
					b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(px,(PARAPET.y-DECK_THICK)*0.5,zc)),Vector3(PARAPET.x*0.5,(PARAPET.y+DECK_THICK)*0.5,third*0.25-0.01),0.07),false,null,0.8)
			b.walk_box(Transform3D(Basis.IDENTITY,Vector3(0.0,-DECK_THICK*0.5,mid)),Vector3(hw-PARAPET.x,DECK_THICK*0.5,third*0.5))
			for side: float in [-1.0,1.0]:
				b.walk_box(Transform3D(Basis.IDENTITY,Vector3(side*(hw-PARAPET.x*0.5),(PARAPET.y-DECK_THICK)*0.5,mid)),Vector3(PARAPET.x*0.5,(PARAPET.y+DECK_THICK)*0.5,third*0.5))
				# The stepped fret on the parapet's outer face.
				b.runes(Vector3(side*hw,0.25,z1-0.3 if side > 0.0 else z0+0.3),Vector3(side*hw,0.25,z0+0.3 if side > 0.0 else z1-0.3),Vector3.UP,Vector3(side,0.0,0.0),0.9)
				b.runes(Vector3(side*hw,-DECK_THICK+0.7,z1-0.3 if side > 0.0 else z0+0.3),Vector3(side*hw,-DECK_THICK+0.7,z0+0.3 if side > 0.0 else z1-0.3),Vector3.UP,Vector3(side,0.0,0.0),1.4)
	var piers: Array = []
	for k in range(0 if end_piers else 1,spans+1 if end_piers else spans):
		piers.append(-k*SPAN)
	for pz: float in piers:
		var ph := PIER*0.5
		# The corbels, under the deck, each course out further than the one
		# under it (the top one most): one block either side of the pier.
		for c in range(CORBELS):
			var reach := ph+(CORBELS-c)*CORBEL_STEP
			var y1 := -DECK_THICK-c*SET_OFF
			b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,y1-SET_OFF*0.5,pz)),Vector3(hw-0.25-0.1*c,SET_OFF*0.5,reach),0.1),true,null,0.6,null,[under(y1)])
		var head_y := -DECK_THICK-CORBELS*SET_OFF
		var foot := -drop
		var tall := head_y-foot
		# The collar under the corbels, then the battered shaft.
		b.block(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,head_y-0.5,pz)),Vector3(ph+0.35,0.5,ph+0.35),0.1),true,null,0.5,null,[under(head_y)])
		b.block(Stone.drum(Transform3D(Basis.IDENTITY,Vector3(0.0,foot,pz)),4,ph+PIER_BATTER*tall,ph,tall-1.0,0.15),true,null,0.4,null,[under(head_y-1.0)])
		for side: float in [-1.0,1.0]:
			var face := pz+side*(ph+0.02)
			b.runes(Vector3(-ph*0.8 if side > 0.0 else ph*0.8,head_y-2.6,face),Vector3(ph*0.8 if side > 0.0 else -ph*0.8,head_y-2.6,face),Vector3.UP,Vector3(0.0,0.0,side),1.2)
			b.cresset(Vector3(side*(hw-PARAPET.x*0.5),PARAPET.y,pz))
	# Its walked tops: the deck a third at a time (the bay's its own kind),
	# the parapets' tops.
	for s2 in range(spans):
		for part in 3:
			var z1 := -s2*SPAN-part*third
			b.rect_area("bay" if s2 == bay and part == 1 else "deck",Rect2(-(hw-PARAPET.x),z1-third,(hw-PARAPET.x)*2.0,third),0.0)
	for side: float in [-1.0,1.0]:
		b.rect_area("parapet",Rect2(side*(hw-PARAPET.x*0.5)-PARAPET.x*0.5,-length,PARAPET.x,length),PARAPET.y)
	b.meta.ports["near"] = Vector3.ZERO
	b.meta.ports["far"] = Vector3(0.0,0.0,-length)
	b.meta.ports["piers"] = piers
	b.meta.his = {"walks":"the deck (%.1f m clear)" % (DECK-2.0*PARAPET.x),"leaps":"the broken bay (%.1f m)" % third,"breaks":"the bay, standing on it" if bay >= 0 else "nothing"}
	b.root.set_meta("length",length)
	return b.finish()

## The breakable bay: span `s`'s middle third (`mid` its middle, `third`
## long), four slabs (two along, two across), each with its parapet run.
static func _bay(b: Piece, s: int, mid: float, third: float, hw: float) -> void:
	var unit := _new_unit("Bay",Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,mid)))
	var k := 0
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			var at := Vector3(sx*hw*0.5,-DECK_THICK*0.5,sz*third*0.25)
			var mesher := Stone.Mesher.new(Stone.stone_colour())
			mesher.rest_frame = Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,mid)+at)
			var deck_h := Vector3(hw*0.5-PARAPET.x*0.5,DECK_THICK*0.5,third*0.25)
			var deck_at := Vector3(-sx*PARAPET.x*0.5,0.0,0.0)
			b.block(Stone.box(Transform3D(Basis.IDENTITY,deck_at),deck_h-Vector3(0.02,0.0,0.03),0.06),false,null,0.8,mesher)
			var par_h := Vector3(PARAPET.x*0.5,(PARAPET.y+DECK_THICK)*0.5,third*0.25)
			var par_at := Vector3(sx*(hw*0.5-PARAPET.x*0.5),(PARAPET.y+DECK_THICK)*0.5-DECK_THICK*0.5,0.0)
			b.block(Stone.box(Transform3D(Basis.IDENTITY,par_at),par_h-Vector3(0.0,0.0,0.03),0.07),false,null,0.8,mesher)
			mesher.runes(par_at+Vector3(sx*PARAPET.x*0.5,-par_h.y+0.25+DECK_THICK*0.5,sz*-third*0.2),par_at+Vector3(sx*PARAPET.x*0.5,-par_h.y+0.25+DECK_THICK*0.5,sz*third*0.2),Vector3.UP,Vector3(sx,0.0,0.0),float(k+11),0.9)
			_unit_piece(unit,k,Transform3D(Basis.IDENTITY,at),mesher,[[_box_shape(deck_h+Vector3(SEAM,0.0,SEAM)),Transform3D(Basis.IDENTITY,deck_at)],[_box_shape(par_h+Vector3(0.0,0.0,SEAM)),Transform3D(Basis.IDENTITY,par_at)]])
			k += 1
	b.root.add_child(unit)
	(b.meta.breaks as Array).append({"kind":"bay","unit":"Bay","pieces":k,"span":s,"box":AABB(Vector3(-hw,-DECK_THICK,-third*0.5),Vector3(hw*2.0,DECK_THICK,third)),
		"top":0.0,"kg":STONE_KG*DECK*DECK_THICK*third*0.25,"weight":0.7,"drop":-1.0})
	_arm(unit,(b.meta.breaks as Array)[-1])
