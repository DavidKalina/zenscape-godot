extends "res://scripts/kit_isle/mechanics/mechanic.gd"
## A kit cache on a motif (scripts/kit_isle/kit_caches.gd; the aqueduct
## isle's --kit-caches, studies/aqueduct_isle_caches.gd): a breakable ruin
## kit piece (`piece`, a RuinKit id) holding a find (`holds`, a GlyphPickup
## glyph), its one-spot glint showing. Playing, it is a kit breakable
## (scripts/breaks/kit_breaks.gd, in a breakables hub the slam reaches)
## `tough` strong (0.5 is the slam's own; it grows with the drop); broken,
## the find comes up and is his when he comes to it. Its own hub, breaks and
## caches stand under its pieces, so `reset` takes them with the piece.

const SINK := 0.08

var piece: Node3D = null
var breaks: Node = null
var caches: Node = null

func _init() -> void:
	super()
	trap_name = "kit_cache"
	verbs = PackedStringArray(["slam"])

func defaults() -> Dictionary:
	return {"piece":"pier","holds":"rune","tough":0.45,"seed":3,"weathered":0.35}

func lay(pieces: Node3D, frame: Transform3D) -> void:
	piece = load("res://scripts/ruin_kit.gd").piece(str(knobs.piece),int(knobs.seed),float(knobs.weathered))
	if piece == null:
		push_warning("kit cache: no kit piece %s" % knobs.piece)
		return
	piece.name = "CachePiece"
	piece.transform = frame*Transform3D(Basis.IDENTITY,Vector3(0.0,-SINK,0.0))
	var KitCaches: GDScript = load("res://scripts/kit_isle/kit_caches.gd")
	piece.set_meta(KitCaches.META,str(knobs.holds))
	piece.set_meta(KitCaches.NAME_META,"cache_%d" % get_instance_id())
	piece.set_meta("toughness",float(knobs.tough))
	pieces.add_child(piece)
	if name != "TrapGhost": KitCaches.dress(piece,false,KitCaches.tint_of(str(knobs.holds)))

func woke() -> void:
	if piece == null: return
	var KitCaches: GDScript = load("res://scripts/kit_isle/kit_caches.gd")
	KitCaches.dress(piece,true)
	var hub: Node3D = load("res://scripts/breaks/breakables.gd").new()
	hub.top_level = true
	host.add_child(hub)
	breaks = load("res://scripts/breaks/kit_breaks.gd").new()
	breaks.name = "KitBreaks"
	breaks.hub = hub
	breaks.top_level = true
	var lost: Variant = study.get("lost") if study != null else null
	breaks.lost_y = float(lost) if lost != null else global_position.y-60.0
	host.add_child(breaks)
	breaks.adopt(piece)
	hub.others.append(breaks)
	caches = KitCaches.new()
	caches.motor = motor
	host.add_child(caches)
	caches.watch(breaks)
	caches.adopt(piece,breaks)

func reset() -> void:
	breaks = null
	caches = null
	super.reset()

func hint_path() -> PackedVector3Array:
	return PackedVector3Array()
