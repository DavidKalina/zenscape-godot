extends "res://studies/kit_isle.gd"
## The colonnade spine: a long knife-edge ridge isle in the sky, a
## processional colonnade the length of its crest climbing west in terraces
## to a temple gate on its high head, its tail curling away east in
## fragments stepping down, tied by stepping stones and live rope bridges.
## See docs/scenic/colonnade-spine.md and studies/colonnade_spine_isle_art.gd.
##
## Everything else is the kit isles' (studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md): the pilot and his moves (the character study's),
## the rope bridges underfoot, the ground and rock, the game's grass and
## flowers (scripts/kit_isle/kit_flora.gd), its light, sky, air, weather and the look
## presets (L / Shift+L, --look=<id>), the plane (F), the lodestone, the sky
## round it (far isles, airships, CPU planes, sky life, motes; its tokens
## here this isle's own: studies/colonnade_spine_isle_sky.gd) and the life
## on it (undergrowth, butterflies, fireflies, songbirds on the stones, the
## wind made visible, on-foot tokens: studies/colonnade_spine_isle_life.gd).
## The same opt-outs: --no-flora, --no-life (--no-undergrowth,
## --no-butterflies, --no-fireflies, --no-birds, --no-wind-life,
## --no-tokens), --no-sky (--no-far-isles, --no-airships, --no-traffic,
## --no-sky-life, --no-motes, --no-sky-tokens), --no-lode, --fly.
##   R            back to the start (the low end of the way, looking west)
##   L / Shift+L  next / previous look preset
##   B            a strong gust front
##   Space (pad A) by the parked plane: into it; land by hand, F (pad Y) out once stopped
##   ./run-colonnade-spine.command [--look=first_snow]
##   godot --path . res://studies/colonnade_spine_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const SpineSky = preload("res://studies/colonnade_spine_isle_sky.gd")
const SpineLife = preload("res://studies/colonnade_spine_isle_life.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
## The isle itself (its art and turf), built here at the origin as the
## aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_colonnade_spine.gd).
const Motif = preload("res://scripts/kit_isle/motif_colonnade_spine.gd")

const SPINE_SEED := Motif.SPINE_SEED
## The kit stairs a little ruined: a ceremonial way up.
const STAIR_WEATHERED := Motif.STAIR_WEATHERED
## Where he starts: on the way's low terrace, by its east end, looking west
## up the colonnade to the temple gate.
const START_AT := Vector3(130.5,Spine.TOP+Spine.L0,0.0)
## Falling past this (world y) he is set back where he last stood's nearest
## safe place: the start.
const LOST_Y := Spine.TOP-28.0

var motif := Motif.new()
## The colonnade, the temple and what lies on the isle (metadata drives the
## tests: piers, lintels, portals, ways up).
var colonnade: Node3D
var temple: Node3D
var spine: Node3D
var bridges: Array[MeshInstance3D] = []

func _ready() -> void:
	super._ready()

## No station: the isle is its own (the greybox pack's routes are the
## aqueduct isle's). The start is on the low terrace looking west.
func _load_pack() -> void:
	stations = []
	start = Vector3(START_AT.x,START_AT.y,Spine.zc(START_AT.x))
	start_face = Vector2(-1.0,0.0)
	lost = LOST_Y
	_last_stood = start

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

## The plants keep off the way, the north shelf and the south bench.
func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func sky_script() -> Script:
	return SpineSky

func life_script() -> Script:
	return SpineLife

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	colonnade = motif.colonnade
	temple = motif.temple
	spine = motif.spine
	bridges = motif.bridges
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	print("colonnade spine: %d triangles, %d prisms; the ridge built in %d ms, the rest in %d ms" % [triangles(art),int(spine.get_meta("prisms")),motif.spine_ms,Time.get_ticks_msec()-began-motif.spine_ms])
# --- The lodestone ------------------------------------------------------------------

## The lodestone rests on the last fragment of the tail, at the end of the
## curl (the aqueduct isle's lodestone, here).
const LODE_ON := "frag_5"

func lode_rest_at() -> Vector3:
	var s := Spine.slab(LODE_ON)
	var c := Spine.slab_at(s)
	return Vector3(c.x-0.6,Spine.TOP+float(s[4])+LODE_HOVER+0.25,c.y+0.4)

## On the fragment, beside the stone, he can pick it up.
func can_pick() -> bool:
	if lodestone == null or lode_state != "resting" or flying or not walk_ready: return false
	var feet := motor.feet
	return Vector2(feet.x-lode_rest.x,feet.z-lode_rest.z).length() < PICK_REACH+0.4 and absf(feet.y+LODE_HOVER+0.25-lode_rest.y) < 0.6

func lode_hint() -> String:
	return "A lodestone hums at the end of the tail's curl: follow the fragments round"
