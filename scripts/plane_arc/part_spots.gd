extends RefCounted
## Where the plane's six lost parts are (docs/design/plane-arc/round1.md,
## docs/game-direction.md "The plane's parts"), worked out by name from the
## isles' own geometry, never from a world position: an isle can move (its
## place in scripts/kit_isle/motif_sky.gd PLACES) and a part goes with it.
## Each still part answers {at (its middle, world), glint (where the
## binoculars see it glint: `at`, or the water's surface over it), stand and
## face (where --part-at=<id> starts the pilot, facing it), move (how it's
## got)}. Two ride: the tail fin on the rune serpent's back (`fin_ring`,
## `on_serpent`) and the propeller on the salvager's rope (`snag`).
##
##   wheel       on the stone circle's standing lintel nearest the start (the
##               east one, on the skyline from the parked plane): up the
##               hill's tiers and the leaning stone onto the lintels
##   wingtip     under the cloister tarn's water, out in its deep across from
##               the shrine isle: swim out to it
##   fin         caught in the rune serpent's back ridges RIDE_ARC m back from
##               its snout (where the watcher's rune rode): ride it from the
##               home ledge; it carries you on toward the tarn
##   windscreen  lying in the drowned nave's aisle water, a bay past the
##               crossing (later it falls there at dusk)
##   propeller   on a rope under a sky-folk plane flying a fixed loop whose
##               dip runs north along the Sundered gorge's west lip, past the
##               gate tower at the rope bridge's head: climb the tower's
##               fallen quarter to its crown and leap off its gorge-side
##               edge into the load as it passes (about 3 m out and a metre
##               down; never in reach of anyone standing on the crown)
##   cowl        jammed under the bell in the bell spires' belfry (reached
##               with the plane for now; a ferry and the downdraft later)
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
const BellSpires = preload("res://scripts/kit_isle/motif_bell_spires.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")
const SnagPlane = preload("res://scripts/snag_plane.gd")

## The six, in the order the direction lists them.
const IDS := ["wheel","cowl","fin","wingtip","propeller","windscreen"]
## Each part's isle in the ledger (its objective is "<isle>/<part id>").
const ISLES := {"wheel":"aqueduct_isle","fin":"aqueduct_isle","wingtip":"cloister_tarn","windscreen":"drowned_nave","propeller":"sundered_gorge","cowl":"bell_spires"}
## How each is found: "still" where it's laid, "serpent" riding its back,
## "snag" on the salvager's rope.
const KINDS := {"wheel":"still","cowl":"still","fin":"serpent","wingtip":"still","propeller":"snag","windscreen":"still"}
## A still part's middle over what it rests on (m).
const HOVER := 0.85
## The wingtip under the tarn's surface (m), in water at least SWIM_DEEP m
## deep (he swims there, never wades), at least SHRINE_CLEAR m off the
## shrine isle's beach.
const SUNK := 0.45
const SWIM_DEEP := 1.6
const SHRINE_CLEAR := 2.5
## The glint over a part under water: this far over the surface (the
## binoculars' sight ray stops at the water's skin).
const GLINT_OVER := 0.3
## The windscreen lies this far over the nave's floor, in the film of water.
const LIE := 0.18
## The cowl's middle under the bell's mouth (m).
const UNDER_BELL := 0.3
## The tail fin: m back from the serpent's snout (the watcher's rune's,
## scripts/kit_isle/watcher.gd RIDE_ARC), over its back's crest.
const RIDE_ARC := 45.0
const FIN_LIFT := 0.55
## The salvager's loop: the dip's pass this far out from the gate tower's
## crown edge over the gorge (m), the load's lowest this far under the
## crown's top (m); the loop turned to pass heading north along the lip.
const SNAG_OUT := 1.7
const SNAG_UNDER := 0.9
const SNAG_YAW := PI*0.5

## Where motif `id`'s isle stands from its own frame (MotifSky PLACES).
static func offset(id: String) -> Vector3:
	for spec: Array in MotifSky.PLACES:
		if (spec[0] as Script).resource_path.get_file().get_basename() == "motif_"+id: return spec[1]
	return Vector3.ZERO

## Part `id`'s objective id in the ledger.
static func objective(id: String) -> String:
	return "%s/%s" % [ISLES[id],id]

## Still part `id`'s spot ({at, glint, stand, face, move}), or {} if its
## geometry isn't there (the wheel wants the aqueduct isle's stone circle).
static func spot(id: String, isle: Node3D = null) -> Dictionary:
	match id:
		"wheel": return wheel(isle)
		"wingtip": return wingtip()
		"windscreen": return windscreen()
		"cowl": return cowl()
	return {}

## A spot: `at`, glinting at `glint`, the start `stand` facing it.
static func _spot(at: Vector3, glint: Vector3, stand: Vector3, move: String) -> Dictionary:
	var to := Vector2(at.x-stand.x,at.z-stand.z)
	return {"at":at,"glint":glint,"stand":stand,"face":to.normalized() if to.length() > 0.01 else Vector2(0.0,-1.0),"move":move}

## The wheel: on the stone circle's standing lintel farthest east (toward
## the start), HOVER over its top; `isle` the aqueduct isle (its `circle`,
## the kit's ring with its "ring" meta: scripts/ruin_kit.gd).
static func wheel(isle: Node3D) -> Dictionary:
	var circle: Node3D = isle.get("circle") if isle != null else null
	if circle == null or not circle.has_meta("ring"): return {}
	var ring: Dictionary = circle.get_meta("ring")
	var best := Vector3.INF
	var along := Vector3.ZERO
	for lintel: Array in ring.lintels:
		if not bool(lintel[1]): continue
		var mid: Vector3 = lintel[0]
		var top: Vector3 = circle.transform*mid
		if best != Vector3.INF and top.x <= best.x: continue
		best = top
		# Along the lintel: square to its way out from the ring's middle.
		var out := Vector3(mid.x,0.0,mid.z).normalized()
		along = (circle.transform.basis*Vector3(out.z,0.0,-out.x)).normalized()
	if best == Vector3.INF: return {}
	return _spot(best+Vector3.UP*HOVER,best+Vector3.UP*HOVER,best+along*1.2+Vector3.UP*0.05,
		"Up the hill's tiers, the leaning stone and onto the ring's lintels")

## The wingtip: in the cloister tarn's deep across from the shrine isle,
## SUNK under the surface, where it's at least SWIM_DEEP deep.
static func wingtip() -> Dictionary:
	var off := offset("cloister_tarn")
	var away := -TarnArt.SHRINE.normalized()
	var found := Vector2.INF
	for r: float in [6.0,5.0,7.0,4.0,8.0]:
		for turn: float in [0.0,0.3,-0.3,0.6,-0.6]:
			var l := away.rotated(turn)*r
			var p := TarnArt.world(l)
			if l.distance_to(TarnArt.SHRINE) < TarnArt.SHRINE_BEACH+SHRINE_CLEAR: continue
			if TarnArt.ground(p.x,p.y) > TarnArt.W-SWIM_DEEP: continue
			found = p
			break
		if found != Vector2.INF: break
	if found == Vector2.INF: found = TarnArt.world(away*6.0)
	var at := Vector3(found.x,TarnArt.W-SUNK,found.y)+off
	var shrine := TarnArt.world(TarnArt.SHRINE)
	return _spot(at,Vector3(found.x,TarnArt.W+GLINT_OVER,found.y)+off,Vector3(shrine.x,TarnArt.SHRINE_TOP+0.05,shrine.y)+off,
		"Swim out into the tarn's deep across from the shrine isle")

## The windscreen: in the drowned nave's aisle, two bays east of the
## crossing, between the causeway and the north row, LIE over the floor.
static func windscreen() -> Dictionary:
	var off := offset("drowned_nave")
	var x := NaveArt.C.x+NaveArt.bay_mid(NaveArt.CROSS_AT+2)
	var z := NaveArt.C.y-NaveArt.ROW_Z*0.5
	var floor := NaveArt.ground(x,z)
	var at := Vector3(x,floor+LIE,z)+off
	var sx := x-NaveArt.BAY*0.5
	var stand := Vector3(sx,NaveArt.ground(sx,z)+0.05,z)+off
	return _spot(at,Vector3(x,maxf(NaveArt.W,floor)+GLINT_OVER,z)+off,stand,"Down the drowned nave, glinting in its water")

## The cowl: jammed under the bell in the bell spires' belfry, UNDER_BELL
## under its mouth; he starts on the belfry floor.
static func cowl() -> Dictionary:
	var off := offset("bell_spires")
	var frame := BellSpires.belfry_frame()
	var at := frame*Vector3(0.0,Belfry.BEAM-Belfry.BELL.y-UNDER_BELL,0.0)+off
	var stand := frame*Vector3(0.75,Belfry.FLOOR+0.05,0.75)+off
	return _spot(at,at,stand,"Up the belfry's stair: it's jammed under the bell; a downdraft on the bell swings it loose")

## Where the cowl comes to rest once a downdraft has swung the bell and
## knocked it down: on the belfry floor, COWL_FLOOR off the bell's plumb
## (the belfry's frame, m), hovering as a laid part does.
const COWL_FLOOR := Vector2(-0.45,0.35)
static func cowl_floor() -> Vector3:
	var frame := BellSpires.belfry_frame()
	return frame*Vector3(COWL_FLOOR.x,Belfry.FLOOR+HOVER,COWL_FLOOR.y)+offset("bell_spires")

# --- The two that ride ------------------------------------------------------------------

## The serpent's ring nearest RIDE_ARC m back from its snout.
static func fin_ring(serpent: Node3D) -> int:
	var arcs: PackedFloat32Array = serpent.stations()
	var ring := 0
	var best := INF
	for k in range(arcs.size()):
		if absf(arcs[k]-RIDE_ARC) < best:
			best = absf(arcs[k]-RIDE_ARC)
			ring = k
	return ring

## The fin's frame on the serpent's back now: over the middle of its crest
## at `ring`, FIN_LIFT up off it, upright along the body.
static func on_serpent(serpent: Node3D, ring: int) -> Transform3D:
	var frame: Transform3D = serpent.ring_frame(ring)
	var corners: Array[Vector3] = serpent.ring_corners(ring)
	var crest := frame*((corners[0]+corners[1])*0.5)
	var up := frame.basis.y.normalized()
	return Transform3D(frame.basis.orthonormalized(),crest+up*FIN_LIFT)

## The salvager's loop: {over (the dip's ledge point, world), yaw, dip (the
## belly over it, m) for `rope` m of rope, crown (the gate tower crown's
## top middle, world), edge (its gorge-side edge), stand, face}.
static func snag(rope := SnagPlane.ROPE) -> Dictionary:
	var off := offset("sundered_gorge")
	var frame := Gorge.tower_frame()
	var top := float(Gorge.TOWER[0][1])
	var crown := frame*Vector3(0.0,top,-1.7)+off
	var edge := frame*Vector3(2.5,top,-1.7)+off
	var out := frame.basis.x.normalized()
	out = Vector3(out.x,0.0,out.z).normalized()
	var over := edge+out*SNAG_OUT
	var dip := rope+SnagPlane.LOAD_SIZE*SnagPlane.HANG-SNAG_UNDER
	var stand := crown+Vector3.UP*0.05
	return {"over":over,"yaw":SNAG_YAW,"dip":dip,"crown":crown,"edge":edge,"stand":stand,"face":Vector2(out.x,out.z),
		"move":"Climb the gate tower's fallen quarter to its crown and leap into the load as it passes"}
