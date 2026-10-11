extends "res://studies/kit_isle.gd"
## The Broken Ring: a hand-built sky-island motif, a kit isle (its look,
## light, air, presets, ground and rock, grass, life, sky, plane, rope
## bridges underfoot and lodestone are the kit isles' own: studies/
## kit_isle.gd, docs/scenic/kit-isle-shared.md; see docs/scenic/
## broken-ring.md). Size in number, not mass: a central isle with a stone
## circle (two stones missing) round a broken turret, and round it a loose
## spiral of eight small isles climbing 21 m, each with one small ruin note,
## tied by rope bridges and floating stones: a broken ring. The art:
## studies/broken_ring_isle_art.gd.
##   R            back to the start (the lowest isle, looking up the ring)
##   L / Shift+L  look presets · B gust · Space (pad A) by the parked plane
##   ./run-broken-ring.command [--look=<preset id>]
##   godot --path . res://studies/broken_ring_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
## The kit isles' flags hold here: --no-flora, --no-life (and its
## parts), --no-sky (and its parts), --fly, --look=, --capture=, --at=,
## --place=, --no-lode, --carry, --stone-plane.
const Ring = preload("res://studies/broken_ring_isle_art.gd")
const RingLife = preload("res://studies/broken_ring_isle_life.gd")
const RingSky = preload("res://studies/broken_ring_isle_sky.gd")
## The isle itself (its art and turf), built here at the origin as the
## aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_broken_ring.gd).
const Motif = preload("res://scripts/kit_isle/motif_broken_ring.gd")

var motif := Motif.new()
var central: Node3D
var circle: Node3D
var turret: Node3D
var isles: Array = []
var bridges: Array[MeshInstance3D] = []

## No pack: the isle is its own one station, its start on the lowest isle.
func _load_pack() -> void:
	start = Ring.start()
	start_face = Ring.start_face()
	lost = Ring.W-45.0
	_last_stood = start
	stations = []

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

func isle_summit() -> Vector3:
	return motif.summit()

func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func flora_seed() -> int:
	return motif.flora_seed()

func sky_script() -> Script:
	return RingSky

func life_script() -> Script:
	return RingLife

func capture_look() -> Vector3:
	return Vector3(Ring.C.x,Ring.centre_top()+2.0,Ring.C.y)

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	central = motif.central
	circle = motif.circle
	turret = motif.turret
	isles = motif.isles
	bridges = motif.bridges
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	print("broken ring: %d triangles, built in %d ms" % [triangles(art),Time.get_ticks_msec()-began])

# --- The lodestone ------------------------------------------------------------------

## The lodestone hums on the highest isle, at the top of the spiral.
func lode_rest_at() -> Vector3:
	var s: Dictionary = Ring.sat(Ring.SATS.size()-1)
	return Vector3(s.c.x-1.0,Ring.summit_y()+LODE_HOVER,s.c.y+0.6)

func lode_hint() -> String:
	return "A lodestone hums on the highest isle: climb the ring to it"
