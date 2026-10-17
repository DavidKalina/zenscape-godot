extends RefCounted
## The aqueduct isle's kit caches (--kit-caches; docs/design/kit-breaks/
## kit-caches-handoff.md): a few ruin kit pieces on the near island's west
## turf, each holding a rune (scripts/kit_isle/kit_caches.gd), breakable
## through a breakables hub of the isle's own (scripts/kit_isle/
## breakables.gd, kit_breaks.gd), which the slam hits. Each rune is one of
## the isle's tokens (studies/aqueduct_isle_tokens.gd: laid once it is up).
##
## PIECES: [cache name, RuinKit id, seed, x, z, yaw (deg), toughness (< 0:
## the kind's)]. The slam needs 1.8 m of air under him and grows with the
## drop (scripts/slam.gd): off the rubble slope's side about 0.4-0.5, off
## the aqueduct's deck (10 m) about 0.95. The pier, buttress and wall stand
## along the deck's west side, each more than a full slam's reach (8.5 m)
## from the next, so one slam off the deck opens one. The tomb chest
## (toughness 1.6, its kind's) by the rubble slope never breaks to a slam:
## its glint only flares.
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const KitBreaks = preload("res://scripts/kit_isle/kit_breaks.gd")
const KitCaches = preload("res://scripts/kit_isle/kit_caches.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

const FLAG := "--kit-caches"
const PIECES := [
	["cache_pier","pier",3,95.6,-5.2,20.0,-1.0],
	["cache_buttress","buttress",4,95.4,-17.0,90.0,-1.0],
	["cache_wall","wall",5,94.6,-28.5,0.0,-1.0],
	["cache_chest","tomb_chest",2,95.2,5.5,80.0,-1.0],
]
const GLYPH := "rune"
## How far each piece sinks into the turf (m).
const SINK := 0.08

static func wanted(args: PackedStringArray = LaunchArgs.user_args()) -> bool:
	return args.has(FLAG)

## The caches' token names (studies/aqueduct_isle_tokens.gd lays them).
static func names() -> Array[String]:
	var out: Array[String] = []
	for p: Array in PIECES: out.append(str(p[0]))
	return out

## The pieces stood, the hub, the breaks and the caches (null without the flag).
static func build(isle: Node3D) -> Node3D:
	if not wanted(): return null
	# Where the plane parks is worked out before they stand, as without them.
	isle.call("plane_home")
	var space := isle.get_world_3d().direct_space_state
	var root := Node3D.new()
	root.name = "KitCachePieces"
	isle.add_child(root)
	for p: Array in PIECES:
		var piece: Node3D = RuinKit.piece(str(p[1]),int(p[2]),0.35)
		if piece == null: continue
		var top: Vector3 = isle.call("_turf_top",space,float(p[3]),float(p[4]))
		var y: float = top.y if top != Vector3.INF else float(isle.call("isle_top"))
		piece.name = "Cache_"+str(p[0])
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(p[5]))),Vector3(float(p[3]),y-SINK,float(p[4])))
		piece.set_meta(KitCaches.META,GLYPH)
		piece.set_meta(KitCaches.NAME_META,str(p[0]))
		if float(p[6]) >= 0.0: piece.set_meta("toughness",float(p[6]))
		root.add_child(piece)
	var hub := Breakables.new()
	isle.add_child(hub)
	var breaks := KitBreaks.new()
	breaks.name = "KitBreaks"
	breaks.hub = hub
	var lost: Variant = isle.get("lost")
	if lost != null: breaks.lost_y = float(lost)
	isle.add_child(breaks)
	breaks.adopt(root)
	hub.others.append(breaks)
	var caches := KitCaches.new()
	var life: Node = isle.get("life")
	if life != null: caches.tokens = life.get("tokens")
	caches.motor = isle.get("motor")
	isle.add_child(caches)
	caches.watch(breaks)
	var n := caches.adopt(root,breaks)
	print("aqueduct isle: %d kit cache(s) of %d, %d piece(s) breakable" % [n,PIECES.size(),breaks.targets.size()])
	return caches
