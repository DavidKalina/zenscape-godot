extends RefCounted
## A ruin motif's isle, apart from any scene (docs/scenic/motif-sky.md): its
## land and ruins built into a node in the isle's own frame, its turf, the
## ground its plants grow on, its life, its plane tokens and its live bits
## (bells). Its standalone study (studies/bell_spires_isle.gd and the other
## motifs) builds it at the origin into its Art; the aqueduct isle's sky
## places it elsewhere (scripts/kit_isle/motif_isle.gd, motif_sky.gd), built
## on a worker. So `build` touches nothing but the node it is given: no
## scene, no physics queries, no tree.
##
## A motif answers: `id`, `isle_name`, `isle_card`, `top` (its datum),
## `summit`, `flora_site` and `flora_seed`, `life_script`, `pools` (the
## water the pilot wades), `plane_tokens` and `token_source`, `warm` (its
## lazy layout caches made on the main thread before a worker builds it),
## `build`; and, if it has live bits, `frame`, `landed` and `plane_near`.
## Everything it answers is in its own frame (the standalone scene's world).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

## The Art node it was built into, and its lands: [land, outline (or null
## for its meta), cliffs] each, registered as turf by whoever stands it.
var art: Node3D
var lands: Array = []
## Seconds the build took (ms).
var built_ms := 0

func id() -> String:
	return ""

func isle_name() -> String:
	return ""

func isle_card() -> Dictionary:
	return {}

func top() -> float:
	return 30.0

func summit() -> Vector3:
	return Vector3(0.0,top(),0.0)

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top())

func flora_seed() -> int:
	return 15

func life_script() -> Script:
	return null

func pools() -> Array:
	return []

## The plane's tokens: [line id, category, kind, points].
func plane_tokens() -> Array:
	return []

func token_source() -> String:
	return id()

## The lazy caches its build and its life share (layouts, paths, platforms),
## made once on the main thread so a worker's build never races them.
func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	KitWater.material()
	RuinKit.materials()

## Builds the land and ruins into `into` (its Art), filling `lands`.
func build(into: Node3D) -> void:
	art = into

## A land to register as turf (`add_turf`'s arguments).
func turf(land: Node3D, outline: Variant = null, cliffs := true) -> void:
	lands.append([land,outline,cliffs])

## A clean, invisible box over `rect` (x, z) from `bottom` to `top` in
## `frame` (the station's boxes under the stone, as kit_isle `_solid`).
func solid_box(rect: Rect2, bottom: float, high: float, frame := Transform3D.IDENTITY) -> void:
	var solid := StaticBody3D.new()
	solid.transform = frame*Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,(high+bottom)*0.5,rect.get_center().y))
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x,high-bottom,rect.size.y)
	collider.shape = box
	solid.add_child(collider)
	art.add_child(solid)

## Each frame: its live bits (`host` the scene or the placed isle: its
## `_atmosphere`, `_motion_time`).
func frame(_delta: float, _host: Node) -> void:
	pass

## The pilot came down at `feet` (world).
func landed(_feet: Vector3) -> void:
	pass

## The plane flies at `at` (world) this frame.
func plane_near(_at: Vector3) -> void:
	pass

## Whether its rope bridges' resting decks stand as walk boxes
## (scripts/kit_isle/deck_ground.gd `rest_decks`).
func rest_decks() -> bool:
	return false
