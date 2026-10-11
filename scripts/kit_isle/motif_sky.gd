extends Node3D
## The ruin motif isles in the aqueduct isle's sky (docs/scenic/motif-sky.md):
## the bell spires, the cloister tarn, the Sundered gorge and the colonnade
## spine, each its own scene's isle (scripts/kit_isle/kit_motif.gd) placed
## a few hundred metres off the aqueduct isle at its own height (PLACES), to
## fly to, land on and walk (scripts/kit_isle/motif_isle.gd). The sky
## (studies/aqueduct_isle_sky.gd) makes this when its scene asks for the
## motifs (`wants_motifs`, studies/aqueduct_isle.gd), after the home isle is
## up, so the pilot walks as soon as before.
##
## They come up one after another, nearest the eye first: each isle's art
## built whole on a worker (one at a time; headless, on the main thread, a
## whole isle in a frame: scripts/kit_isle/motif_isle.gd `threaded`), then
## stood a part a frame, its
## turf registered, its plants grown and its life set up in slices, all
## within the sky's frame budget (scripts/sky_commits.gd), sharing it with
## the towers. `flush` stands them all at once (tests, captures). Their
## plane tokens join the sky's collectibles at once, a source each.
##
## Placed clear of the aqueduct isle's lock ring, of the lodestone's shard,
## its ring and the hall chain's line out north-north-east, and of the
## cumulus towers' spots (scripts/kit_isle/kit_clouds.gd TOWERS, each its
## keep away).
const MotifIsle = preload("res://scripts/kit_isle/motif_isle.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Lines = preload("res://scripts/collectible_lines.gd")

## [motif script, offset from its own frame (m)]. Their middles (world x, z)
## and turf: the bell spires east (420, 60) at 42 m, the cloister tarn south
## (60, 360) at 30 m, the Sundered gorge west (-300, 80) at 36 m, the
## colonnade spine north-west (-200, -330) at 48 m. (Every motif's own
## frame has its middle near the aqueduct isle's, x 75-86, z -5 to -22, its
## turf at 30 m.)
const PLACES := [
	[preload("res://scripts/kit_isle/motif_bell_spires.gd"),Vector3(338.0,12.0,82.0)],
	[preload("res://scripts/kit_isle/motif_cloister_tarn.gd"),Vector3(-14.0,0.0,365.0)],
	[preload("res://scripts/kit_isle/motif_sundered_gorge.gd"),Vector3(-386.0,6.0,102.0)],
	[preload("res://scripts/kit_isle/motif_colonnade_spine.gd"),Vector3(-286.0,18.0,-320.0)],
	[preload("res://scripts/kit_isle/motif_broken_ring.gd"),Vector3(-660.0,6.0,-70.0)],
	[preload("res://scripts/kit_isle/motif_drowned_nave.gd"),Vector3(-310.0,0.0,350.0)],
	[preload("res://scripts/kit_isle/motif_stair_clouds.gd"),Vector3(440.0,14.0,-254.6)],
	[preload("res://scripts/kit_isle/motif_hollow_keel.gd"),Vector3(285.0,16.0,370.0)],
]
## Each motif's reach round its middle before it is registered (m, the
## circle of its own outlines): its keep in the clouds' layout.
const REACH := {"bell_spires":41.0,"cloister_tarn":54.0,"sundered_gorge":56.0,"colonnade_spine":85.0,"broken_ring":38.0,"drowned_nave":64.0,"stair_clouds":33.0,"hollow_keel":62.0}
## Its middle in its own frame (x, z), the same circle's.
const MIDDLES := {"bell_spires":Vector2(82.3,-21.8),"cloister_tarn":Vector2(73.7,-5.0),"sundered_gorge":Vector2(86.0,-22.2),"colonnade_spine":Vector2(86.0,-10.5),"broken_ring":Vector2(80.0,-10.0),"drowned_nave":Vector2(80.0,0.0),"stair_clouds":Vector2(80.0,-5.4),"hollow_keel":Vector2(80.0,-15.0)}
## A slice is at least this long (usec) once the frame's budget is open.
const SLICE_LEAST := 1500
## Headless (built on the main thread, a whole isle's art in one frame of
## up to 4 s), an isle is built only once the eye is within this of its
## edge (m), unless --motifs-now (or `flush`): so a headless run on the
## aqueduct isle (tests, the packaged check) isn't stalled by isles it never
## goes near. Rendered, every isle is built from the start, on a worker.
const HEADLESS_NEAR := 200.0

var scene: Node3D
var sky: Node3D
var isles: Array = []
## The one building on a worker now, or null.
var _building: Node3D = null
## Built on workers (rendered), or on the main thread (headless).
var threaded := DisplayServer.get_name() != "headless"
## Every isle built from the start, near or not (rendered; --motifs-now).
var eager := true

## Where each stands, without making any: [id, middle (world; y its top),
## reach (m)].
static func places() -> Array:
	var out: Array = []
	for spec: Array in PLACES:
		var key := (spec[0] as Script).resource_path.get_file().get_basename().trim_prefix("motif_")
		var at: Vector3 = spec[1]
		var mid: Vector2 = MIDDLES[key]
		out.append([key,Vector3(mid.x+at.x,30.0+at.y,mid.y+at.z),float(REACH[key])])
	return out

func _init() -> void:
	name = "Motifs"

func setup(study: Node3D, owner_sky: Node3D, args: PackedStringArray) -> void:
	scene = study
	sky = owner_sky
	var began := Time.get_ticks_msec()
	eager = threaded or args.has("--motifs-now")
	var where := places()
	for k in range(PLACES.size()):
		var spec: Array = PLACES[k]
		var motif: RefCounted = (spec[0] as Script).new()
		if motif.get("still_bells") != null: motif.set("still_bells",args.has("--no-bell"))
		motif.warm()
		var isle: Node3D = MotifIsle.new()
		isle.setup(study,motif,spec[1],args)
		isle.threaded = threaded
		var at: Vector3 = where[k][1]
		isle.guess = Vector3(at.x,at.z,float(where[k][2]))
		add_child(isle)
		isles.append(isle)
	_next_build()
	print("motif isles: set up in %d ms, built %s" % [Time.get_ticks_msec()-began,"on a worker" if threaded else "on the main thread, one a frame"])

## The plane's tokens of every motif, a source each on the sky's
## collectibles, moved to where they stand.
func add_tokens(collectibles: Node3D, seed_value: int) -> void:
	for isle: Node3D in isles:
		var lines: Array = []
		for t: Array in isle.motif.plane_tokens():
			var points := PackedVector3Array()
			for p: Vector3 in t[3]: points.append(p+(isle.offset as Vector3))
			lines.append(Lines.line(t[0],t[1],t[2],points,seed_value))
		collectibles.add_source(str(isle.motif.token_source()),lines)

## The nearest isle not yet built, onto a worker (one at a time).
func _next_build() -> void:
	if _building != null or not threaded: return
	var eye := _eye()
	var best: Node3D = null
	var near := INF
	for isle: Node3D in isles:
		if isle.stage != "waiting": continue
		var c: Vector3 = isle.circle()
		var d := Vector2(eye.x-c.x,eye.z-c.y).length()
		if d < near:
			near = d
			best = isle
	if best == null: return
	_building = best
	best.start_build()

func _eye() -> Vector3:
	var camera: Variant = scene.get("camera") if scene != null else null
	return (camera as Camera3D).global_position if camera is Camera3D and (camera as Camera3D).is_inside_tree() else Vector3(85.0,30.0,-20.0)

## True once every isle stands whole (its life up).
func all_stood() -> bool:
	for isle: Node3D in isles:
		if not isle.is_up(): return false
	return true

## Every isle stood up at once, its plants and life too.
func flush() -> void:
	for isle: Node3D in isles:
		isle.build_now()
		isle.work(-1)
	_building = null

## The isle whose circle (and lock ring) the plane at `at` is in reach of,
## nearest first; null for none (scripts/isle_lock.gd `in_reach`).
func isle_near(at: Vector3, reach: Callable) -> Node3D:
	var best: Node3D = null
	var near := INF
	for isle: Node3D in isles:
		if not isle.stands(): continue
		var c: Vector3 = isle.circle()
		var d := Vector2(at.x-c.x,at.z-c.y).length()-c.z
		if d < near and bool(reach.call(isle)):
			near = d
			best = isle
	return best

func _process(delta: float) -> void:
	if scene == null: return
	if _building != null and not _building.building():
		_building = null
		_next_build()
	var eye := _eye()
	# The main thread's share: one isle's work a slice, nearest first, while
	# the frame's budget is open.
	while SkyCommits.open():
		var best: Node3D = null
		var near := INF
		for isle: Node3D in isles:
			if not isle.wants_work(): continue
			var c: Vector3 = isle.circle()
			var d := Vector2(eye.x-c.x,eye.z-c.y).length()
			# Headless, an isle's art is built here, a whole isle in one
			# frame: only once the eye comes near (or `eager`).
			if isle.stage == "waiting" and not eager and d-c.z > HEADLESS_NEAR: continue
			if d < near:
				near = d
				best = isle
		if best == null: break
		var began := Time.get_ticks_usec()
		best.work(maxi(SkyCommits.BUDGET_USEC-SkyCommits.used(),SLICE_LEAST))
		SkyCommits.spend("motif isle",Time.get_ticks_usec()-began)
	for isle: Node3D in isles: isle.advance(delta,eye)
