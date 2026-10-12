extends "res://studies/kit_isle.gd"
## The aqueduct isle: the ruins archipelago's aqueduct station (studies/
## island_packs/ruins_archipelago.gd, station 2) on its own, dressed in the
## gothic ruin kit and the game's real look, played on foot as the pilot.
## Two floating islands of faceted turf over hanging rock keels in the open
## sky at the game's noon (its sky, sun, grade and the cumulus sea far
## below: scripts/landscape_lighting.gd, studies/celestial.gd, scripts/
## look_pass.gd, as the ruin kit gallery has them); the aqueduct striding
## from its head on the near island over 23 m of sky to the far one, its
## channel still carrying water that spills through the fallen span.
##
## A kit isle (studies/kit_isle.gd, docs/scenic/kit-isle-shared.md: the
## pilot, the look rig, the plane, the lodestone, the grass, sky and life;
## the ground and rock the kit isles' one look). The pilot, camera, moves,
## recorder and replays are the character study's: the station's boxes,
## laid at the isle's own numbers (its arches sized for the plane, studies/
## aqueduct_isle_art.gd `station_parts`), collide, invisible, under the
## stone. Round it, on one axis (z 0): the aqueduct with the castellum at
## its head; to the west a hill rising in tiers of crag (the grand stair up
## onto the lower one, a way winding round it up a ramp and a ledge to the
## kit's stair into the crag), the stone circle crowning it, tilted with
## the summit, its sarsen over a bitten edge broken off and floating;
## floating stones and two islets round the isle (chains up, down and out);
## the heel stone out east; the gate on the far island. What stands
## collides as built (the kit's hulls), the ground as the game's terrain
## look. See docs/scenic/aqueduct-isle.md.
##
## The game's look (docs/scenic/aqueduct-isle-game-look.md): the turf grows
## the game's swaying shader grass and its meadow flowers (studies/
## aqueduct_isle_flora.gd), parted by the pilot's wake; the light, sky,
## air, weather and haze are the game's own rig (scripts/
## landscape_lighting.gd, studies/celestial.gd, studies/atmosphere.gd,
## studies/precipitation.gd, studies/display_fog.gd, scripts/look_pass.gd),
## dressed by the edit mode's look presets (scripts/scene_look_presets.gd,
## applied as the look editor applies them). Alpine morning to begin with.
##   R            back to the start (the rubble slope's foot)
##   L / Shift+L  next / previous look preset (its name shows a moment)
##   B            a strong gust front
##   Space (pad A) by the parked plane: climb in and take off; in it,
##                land by hand on the turf (studies/kit_isle.gd: the game's
##                hand landing), F (pad Y) the flaps, and out once stopped
##   F5 F6 F7 F8  record, replay the station's recordings, older, all paths
##   F1 numbers · F2 feel · Esc mouse
##   ./run-aqueduct-isle.command [--look=first_snow]
##   godot --path . res://studies/aqueduct_isle.tscn -- --no-title [--look=<preset id>] [--stone=mass] [--capture=out.png --at=x,y,z --look=x,y,z]
## --no-flora leaves the grass and flowers out (to compare cost).
## Life (studies/aqueduct_isle_life.gd, docs/scenic/aqueduct-isle-life.md):
## undergrowth, butterflies, fireflies, songbirds on the stones, the wind
## made visible and seven on-foot tokens; --no-undergrowth, --no-butterflies,
## --no-fireflies, --no-birds, --no-wind-life, --no-tokens leave each out,
## --no-life all of it.
## --fly starts in the plane; --drift=<x> scales its knife-edge drift
## (scripts/sky_plane.gd). The plane: docs/scenic/aqueduct-isle-game-look.md.
## The lodestone (docs/design/isle-lodestone.md): a stone holding a world in
## miniature (scripts/lodestone.gd) hums on the floating stone past the heel
## stone (east_1); climb to it, E (pad A) picks it up and holds it up to
## look at (drag or the right stick turns it; E, Enter, pad A or B keeps
## it), and it rides at the pilot's side. With --stone-plane, boarding with
## it seats it in the stone plane (scripts/stone_plane_figure.gd; the wooden
## plane is the default), whose wing seams then point to a shard
## floating far off (--target=x,y,z). --carry starts with it; --lode-at=
## <platform name> rests it elsewhere; --no-lode leaves it out; --pickup
## picks it up at once if he stands by it (captures).
## The hall chain (docs/design/isle-hall-chain.md, studies/
## aqueduct_isle_chain.gd): near the shard an arch erupts quietly out of
## the cloud sea far below and climbs to stand past it; threading it, a
## held breath, a pulse through the plane (the nose arrow goes quiet), and
## the Sundered line erupts from the sea ahead, big pieces one after
## another, end to end, sidestepping now and then, each the game's own
## Sundered hall in its basalt and overgrowth on its ridge island (docs/
## design/isle-hall-line.md; --line-look=greybox: round 1's boxes;
## --chain-style=halls: the old hall chain; the line's flags --line-run=,
## --line-jog=, ... apply). --autopilot flies the line
## for you once it starts (any stick or key takes over); --capture-high
## takes the capture from high behind the plane, looking down the line.
## --no-chain leaves it out (the old shard-only arrival); --ring=x,y,z
## moves the ring, --ring-near=<m> the nearest it wakes (150; at speed further),
## --ring-pause=<s> the breath (1.5), --chain-lead=<m> how far on the first
## hall's way in stands at the least (180), --arrive-spare=<s> how long
## before the plane gets to a gate it is still (2), --catch-up=<x> how much
## quicker a hall the plane outruns rises (1.6), --first-at=thread|pulse
## when the first hall starts (thread); --near-ring starts in the plane
## with the stone seated 260 m before the ring; the chain's own flags
## (--chain-at=, --chain-gap=, ...) and the rise's apply.
## --look=<id> (or --preset=<id>) starts in that look preset; --look=x,y,z
## (three numbers) is the capture's look-at point. --capture waits for the
## sky to settle, saves the view (from --at looking at the point, else the
## walker's camera) and quits; --place=x,y,z[,turn] starts the pilot there
## instead (turn: degrees from facing -z, clockwise).
## The roost (docs/design/dragon-roost/round3.md), on by default: the
## dragon's mountain stands out past the motif isles (scripts/kit_isle/
## motif_dragon_roost.gd) and the dragon sleeps curled on its ledge, its neck
## round the summit (scripts/dragon_roost.gd). Once a world day he wakes and
## flies a circuit round the region, spectacle only, then settles back
## (scripts/dragon_wake.gd, docs/design/dragon-wake/round1.md);
## --dragon-wake wakes him a few seconds in, --dragon-wake-at=<s> then,
## --no-dragon-wake keeps him asleep.
## --no-dragon-roost leaves both out; with --dragon he flies instead and the
## nest is empty.
## The dragon (an experiment: docs/design/rim-dragon.md), with --dragon: a
## full-bodied dragon (scripts/sky_dragon.gd) rises out of the cloud sea and
## roams the archipelago, now and then low over the isle; V puts the camera
## on it. Its other flags are its own.
## --watcher: a stranger on the south rim, telescope up, watching a glint
## on the rune serpent's back, the plane's tail fin (scripts/kit_isle/
## watcher.gd, docs/design/watcher/round1.md).
## The plane starts broken (scripts/plane_arc/plane_arc.gd, docs/design/
## plane-arc/round1.md): its six parts are spread over the region, found on
## foot, carried and fitted at the plane; --plane-fixed starts it repaired
## (--fly too), --parts-carried carrying all six, --part-at=<id> by one.
## --dragon-ride (round 5) starts the pilot on foot on the isle it grips, to
## ride the sag and be flung by the snap; G makes it let go.
## The blast is a gust for the plane too (round 10, scripts/dragon_gale.gd
## `plane_gust`, through `plane_air`). --dragon-fly-test starts in the plane
## and, each time the dragon breathes in on a rim, puts it on a pass across
## the blast 30 m out from the jaw; --dragon-fly-test=land puts it on a low
## approach over the held isle's turf instead, to land in the blast.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Life = preload("res://studies/aqueduct_isle_life.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
## The hall chain's halls collide on the ruins' layer (scripts/hall_rise.gd).
const RuinBump = preload("res://scripts/ruin_bump.gd")
const SkyDragon = preload("res://scripts/sky_dragon.gd")
const DragonRoost = preload("res://scripts/dragon_roost.gd")
## The air round the roost: its wreath, haze, cold, carrion birds and the
## crashed plane (docs/design/dragon-roost/round3.md).
const RoostAir = preload("res://scripts/roost_air.gd")
## His wake on a schedule (docs/design/dragon-wake/round1.md).
const DragonWake = preload("res://scripts/dragon_wake.gd")
## The flying dragon's attack targets (round 7): the sky's placed motif
## isles, whatever it places (scripts/kit_isle/motif_sky.gd `places`).
const DragonIsleShape = preload("res://scripts/dragon_isle_shape.gd")

## The station this is (its key in the pack).
const STATION := 2
const SEED := 11
## What stands round the aqueduct besides the landmarks: [kit piece,
## seed, weathered, world x, z, yaw (degrees)], each standing on the ground
## there and colliding as the kit built it. Only the gate on the far
## island, where the aqueduct came down, and its paving.
static func pieces() -> Array:
	return [
		["arch",20,0.35,Art.GATE.x,Art.GATE.y,0.0],
		["floor",23,0.6,Art.GATE_FLOOR.x,Art.GATE_FLOOR.y,15.0],
	]
## The landmarks from the kit: the grand stair up the henge's terrace and
## the stone circle on it, both facing east along the isle's axis.
const STAIR_SEED := 31
const CIRCLE_SEED := 32
const STEPS_SEED := 33
const LANDMARK_WEATHERED := 0.55
## The stair less ruined than the circle: a ceremonial way up, its cheeks
## standing (one torn low), no newel's cap fallen.
const STAIR_WEATHERED := 0.3
## The stepping stumps back from the far island and their knife-edge slot
## (Art `stumps`, `KNIFE_Z`, `stump_slot`).
static func stump_slot() -> float:
	return Art.stump_slot()
## (Funcs, not static vars: a static var on this scene's script left the
## engine reporting pages still in use at exit.)
static func stumps() -> Array:
	return Art.stumps()

## The lodestone's floating stone (Art `platforms`).
const LODE_PLATFORM := "east_1"
## The shard with the chain: 380 m north-north-east of the start, out over
## the cloud sea and clear of the near isles, so the ring past it and the
## halls past that run into open sky (docs/design/isle-hall-chain.md).
## Without it (--no-chain), where the kit isles keep it (TARGET).
const CHAIN_TARGET := Vector3(200.0,42.0,-380.0)
const SHARD_ONLY_TARGET := Vector3(250.0,Art.TOP+24.0,-230.0)
## The ring and the hall chain (studies/aqueduct_isle_chain.gd): on unless
## --no-chain (or a test sets it off before the scene is built). With it,
## nothing happens by being near the shard: only threading the ring.
## --near-ring starts in the plane with the stone seated NEAR_RING_OUT m
## before the ring, NEAR_RING_UP m over its middle, flying at it.
const NEAR_RING_OUT := 260.0
const NEAR_RING_UP := 3.0
## The pulse through the plane once the ring's pause is over: a soft flash
## round it (m across, s).
const PULSE_SIZE := 7.0
const PULSE_TIME := 1.2
var chain_on := true
var isle_chain: Node3D = null
var _near_ring := false
var _plane_flash: MeshInstance3D = null
var _plane_flash_left := 0.0
## --autopilot: the chain's pilot flies its route once it has one (any real
## stick or key turns it off); its place along the route.
var autopilot := false
var _auto_at := -1
## --capture-high: the capture's eye high behind the plane.
var _capture_high := false

## The landmarks from the kit (their metadata drives the tests).
var stair: Node3D
var circle: Node3D
## The dragon, with --dragon.
var dragon_on := false
## --dragon-ride (round 5): on foot on the isle it grips, to feel the sag,
## the snap and the launch.
var dragon_ride := false
var dragon: Node3D = null
## --dragon-fly-test (round 10): "cross" or "land", else "".
var _fly_test := ""
var _fly_test_breath := ""
var _fly_test_t := 0.0
var _fly_test_log := 0.0
var _fly_test_heading := 0.0
## The dragon asleep on its mountain, shown once the mountain stands: on by
## default (--dragon-roost is still accepted); --no-dragon-roost leaves the
## mountain and him out; --dragon flies him instead, the nest left empty.
var dragon_roost := true
var roost_dragon: Node3D = null
var roost_air: Node3D = null
## Each motif isle's record for the dragon, once it stands (its id ->
## {node, shape, home, radius, frame, pivot}).
var _dragon_isles := {}

func _ready() -> void:
	pack = "ruins_archipelago"
	_lode_at = LODE_PLATFORM
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-chain": chain_on = false
		elif arg == "--autopilot": autopilot = true
		elif arg == "--capture-high": _capture_high = true
		elif arg == "--dragon": dragon_on = true
		elif arg == "--dragon-roost": dragon_roost = true
		elif arg == "--no-dragon-roost": dragon_roost = false
		elif arg == "--dragon-ride":
			dragon_on = true
			dragon_ride = true
		elif arg.begins_with("--dragon-fly-test"):
			dragon_on = true
			dragon_ride = true
			_fly_test = "land" if arg.ends_with("=land") else "cross"
		elif arg == "--near-ring":
			_near_ring = true
			_carry = true
	# --target= (the kit's) still moves it.
	lode_target = CHAIN_TARGET if chain_on else SHARD_ONLY_TARGET
	super._ready()

## The pack's station 2 alone: its spawn the start.
func _load_pack() -> void:
	_load_station_pack()
	var kept: Array = []
	for station: Dictionary in stations:
		if station.key == STATION: kept.append(station)
	stations = kept
	start = Art.START
	start_face = kept[0].face
	_last_stood = start

## The station's parts as clean, invisible collision, laid at the isle's
## own numbers (Art `station_parts`: the greybox's own are the old toy
## sizes, and the islands are built), then the art.
func _build_room() -> void:
	for part: Array in Art.station_parts(): _part(part)
	ground.pools.append_array(Art.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var near := Art.island(Art.NEAR,30.0,SEED,Art.ground,Art.TOP,true)
	near.name = "NearIsland"
	art.add_child(near)
	var far := Art.island(Art.FAR,20.0,SEED+1,Art.base)
	far.name = "FarIsland"
	art.add_child(far)
	var built: Dictionary = Art.aqueduct(SEED)
	art.add_child(built.node)
	# Its channel's water, in the world's frame (none with --old-water: the
	# old film is the aqueduct's own).
	if built.water != null: art.add_child(built.water)
	for part: Array in built.parts: _part(part)
	var castellum: Dictionary = Art.castellum(SEED+2)
	art.add_child(castellum.node)
	for part: Array in castellum.parts: _part(part)
	art.add_child(Art.buttress(SEED+3))
	art.add_child(Art.rubble_heap(SEED+6))
	# The hill: its walls and kerbs, the grand stair up its east face onto
	# the lower tier, the kit's stair up into the crag, the stone circle
	# crowning it (tilted with the summit, its sarsen over the bite gone);
	# the floating stones and islets round the isle; the heel stone out
	# east on the axis.
	art.add_child(Art.hill_walls(SEED+7))
	stair = RuinKit.grand_stair(STAIR_SEED,STAIR_WEATHERED)
	stair.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Art.STAIR_AT)
	art.add_child(stair)
	kit_stairs = RuinKit.stairs(STEPS_SEED,STAIR_WEATHERED)
	kit_stairs.transform = Art.stairs_frame()
	art.add_child(kit_stairs)
	circle = RuinKit.stone_circle(CIRCLE_SEED,LANDMARK_WEATHERED,[Art.MISSING])
	circle.transform = Art.circle_transform()
	art.add_child(circle)
	art.add_child(Art.floating_stones(SEED+10))
	var islets: Array = Art.islets(SEED+11)
	for islet: Node3D in islets: art.add_child(islet)
	art.add_child(Art.heel_stone(SEED+8))
	for spec: Array in pieces():
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = spec[3]
		var z: float = spec[4]
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Art.ground(x,z),z))
		art.add_child(piece)
	art.add_child(_stumps())
	# The turf the grass and flowers grow on (`_grow`, once it all stands
	# in the physics space): the islands' and islets' ground.
	for land: Node3D in [near,far]+islets: add_turf(land)
	print("aqueduct isle: %d triangles" % triangles(art))
	# The on-foot pieces' route (balustrades, ropes, a ferry, bobbing slabs).
	preload("res://scripts/interactables/aqueduct_foot_route.gd").build(self)

# --- The isle's hooks --------------------------------------------------------------

func isle_name() -> String:
	return "aqueduct isle"

## Placeholder name and line until the isle is named; its finds are the
## ledger's (scripts/ledger/ledger.gd `card`).
func isle_card() -> Dictionary:
	return Ledger.shared().card(Ledger.isle_id_of(self),{"name":"The Aqueduct of Veyl","epithet":"Where the old water still walks the sky"})

func isle_top() -> float:
	return Art.TOP

func isle_summit() -> Vector3:
	return Vector3(Art.HILL.x,Art.TOP,Art.HILL.y)

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Art.TOP,func(p: Vector2) -> float: return Art.path_wear(p))

func flora_seed() -> int:
	return SEED+4

func life_script() -> Script:
	return Life

# --- The motif isles in its sky (docs/scenic/motif-sky.md) ---------------------------

## The four ruin motifs' isles stand in this isle's sky (studies/
## aqueduct_isle_sky.gd, scripts/kit_isle/motif_sky.gd); a motif's own
## scene has none.
func wants_motifs() -> bool:
	return true

## The sky's motif isles (scripts/kit_isle/motif_sky.gd), or null.
var motifs: Node3D:
	get: return sky.get("motifs") if sky != null else null

## R3 / Tab locks onto the nearest isle in reach: this one or a motif isle
## that stands (its circle, its top, its card).
func lock_target(at: Vector3) -> Dictionary:
	var best := super.lock_target(at)
	var near := INF
	if lock_reaches(best,at): near = Vector2(at.x-best.middle.x,at.z-best.middle.z).length()-float(best.radius)
	if motifs == null: return best
	for isle: Node3D in motifs.isles:
		if not isle.stands(): continue
		var c: Vector3 = isle.circle()
		var target := {"middle":Vector3(c.x,0.0,c.y),"radius":c.z,"top":isle.isle_top(),"card":isle.isle_card()}
		if not lock_reaches(target,at): continue
		var d := Vector2(at.x-c.x,at.z-c.y).length()-c.z
		if d < near:
			near = d
			best = target
	return best

## The telescope's isles: this one and the motif isles that stand.
func sight_isles() -> Array:
	var isles := super.sight_isles()
	if motifs == null: return isles
	for isle: Node3D in motifs.isles:
		if not isle.stands(): continue
		var c: Vector3 = isle.circle()
		isles.append({"middle":Vector3(c.x,0.0,c.y),"radius":c.z,"top":isle.isle_top(),"isle":isle})
	return isles

## The cloister tarn's water (its surface on its own layer, scripts/
## kit_isle/motif_cloister_tarn.gd WATER_LAYER) is skimmed as the turf is,
## as on its own scene.
const MOTIF_WATER := 1 << 12

func plane_ground(p: Vector3) -> Variant:
	if _ground_ray == null:
		_ground_ray = PhysicsRayQueryParameters3D.new()
		_ground_ray.collision_mask = TURF_LAYER|MOTIF_WATER
	return super.plane_ground(p)

## The lodestone on its floating stone (`_lode_at`, else LODE_PLATFORM).
func lode_rest_at() -> Vector3:
	var p: Dictionary = Art.platform(_lode_at)
	if p.is_empty():
		push_warning("aqueduct isle: no platform '%s'; %s instead" % [_lode_at,LODE_PLATFORM])
		p = Art.platform(LODE_PLATFORM)
	return (p.at as Vector3)+Vector3.UP*LODE_HOVER

func lode_hint() -> String:
	return "A lodestone hums on a floating stone east, past the heel stone: climb up to it"

## Only the station's recordings replay here, and only while the aqueduct
## is the station's own size (`--plane-scale=1 --opening-ratio=1`): sized
## for the bigger plane it is longer and taller, so they no longer replay
## true.
func _pack_runs() -> PackedStringArray:
	var found := PackedStringArray()
	if not Art.station_sized(): return found
	for path in _station_runs():
		if int(Recording.read(path).get("station",0)) == STATION: found.append(path)
	return found

## The stepping stumps (`stumps`): an older arcade's piers, coursed solid
## to their tops, mossed and tufted there, their feet broken off under the
## islands; collided as clean boxes.
func _stumps() -> Node3D:
	var b := RuinKit.Build.new(SEED+5,0.6,"Stumps")
	b.settle = Aqueduct.SETTLE
	for s: Array in stumps():
		var x: float = s[0]
		var z0: float = s[1]
		var z1: float = s[2]
		var high: float = float(s[3])-Art.TOP
		var foot := -7.0-absf(z0)*0.1
		var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,Art.TOP,(z0+z1)*0.5))
		var line := func(_x: float) -> float: return high
		RuinKit._courses(b,pose,-absf(z1-z0)*0.5,absf(z1-z0)*0.5,foot,line,1.2,Callable(),0.55)
		b.frame = pose
		Art._broken_foot(b,0.0,foot)
		b.frame = Transform3D.IDENTITY
		for i in range(5):
			Art._tuft(b,Vector3(x+b.rng.randf_range(-0.9,0.9),Art.TOP+high,b.rng.randf_range(z1,z0)),0.3,4)
		_part(["box",Rect2(x-1.2,minf(z0,z1),2.4,absf(z1-z0)),Art.TOP+foot,float(s[3]),"lip"])
	var node := b.finish()
	node.get_node("Body").free()
	return node

# --- The ring and the hall chain ---------------------------------------------------------

## --fly, or --near-ring: in the plane, the stone seated, NEAR_RING_OUT m
## before the ring flying at it.
func _start_in_plane() -> void:
	super._start_in_plane()
	if _near_ring or _fly_test != "": board()
	if _near_ring and isle_chain != null:
		var ahead := Vector3(-sin(isle_chain.ring_heading),0.0,-cos(isle_chain.ring_heading))
		fly_from(isle_chain.ring_at-ahead*NEAR_RING_OUT+Vector3.UP*NEAR_RING_UP,isle_chain.ring_heading)

## The shard, then the ring past it, the chain's cloud sea and the chain
## (studies/aqueduct_isle_chain.gd, docs/design/isle-hall-chain.md).
func _build_target() -> void:
	super._build_target()
	if chain_on: _build_chain()

## With the chain the arch is the ring past the shard; the pier stays.
func _shard_arch() -> bool:
	return not chain_on

func _build_chain() -> void:
	isle_chain = IsleChain.new()
	add_child(isle_chain)
	isle_chain.setup(lode_target,preload("res://scripts/launch_args.gd").user_args())
	isle_chain.chain.plane_box = _chain_plane_box
	isle_chain.started.connect(_ring_pulse)
	_plane_flash = MeshInstance3D.new()
	_plane_flash.name = "PlaneFlash"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*PULSE_SIZE
	_plane_flash.mesh = quad
	var glow := (_shard_flash.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	glow.albedo_color.a = 0.0
	_plane_flash.material_override = glow
	_plane_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane_flash.visible = false
	add_child(_plane_flash)

## The plane's box (world) for the halls' rise, which waits for it to be
## clear before a chunk turns solid; none on foot.
func _chain_plane_box() -> AABB:
	if not flying or plane == null: return AABB()
	# The plane as drawn (ground_scale.size(), about its wheels: its middle
	# middle_shift up from the flight's).
	var half := Vector3.ONE*(WorldScale.TOY_SPAN*0.5*ground_scale.size()+0.3)
	return AABB((plane.position as Vector3)+Vector3.UP*ground_scale.middle_shift().y-half,half*2.0)

## The ring's pause over: the arrival's chime, a soft flash round the plane,
## the nose arrow's flare (the stone plane's sync pulse), no words.
func _ring_pulse() -> void:
	_moments.flourish()
	_plane_flash_left = PULSE_TIME
	if _nose != null:
		_nose.pulse()
		_nose.quiet()
	if stone_plane and flying and plane_figure != null: plane_figure.flash()

func _pulse_frame(delta: float) -> void:
	if _plane_flash == null: return
	_plane_flash.visible = _plane_flash_left > 0.0 and flying
	if _plane_flash_left <= 0.0: return
	_plane_flash_left = maxf(_plane_flash_left-delta,0.0)
	var t := _plane_flash_left/PULSE_TIME
	if flying: _plane_flash.global_position = plane.position
	(_plane_flash.material_override as StandardMaterial3D).albedo_color.a = sin(t*PI)*0.7
	_plane_flash.scale = Vector3.ONE*lerpf(1.5,0.4,t)

func _process(delta: float) -> void:
	super._process(delta)
	# Flying, `_fly_tick` steps the ring and the chain; on foot, here.
	if isle_chain != null and not flying and delta > 0.0: isle_chain.step(delta,null,false,camera.global_position)
	_pulse_frame(delta)
	if dragon != null:
		if _atmosphere != null:
			dragon.air = _atmosphere.breeze()
			dragon.air_angle = _atmosphere._air_angle
		dragon.on_foot = not flying
		dragon.advance(delta)
		if _fly_test != "": _fly_test_frame(delta)
	_roost_frame(delta)

## A fixed-eye capture (--at) still flies the dragon.
func _capture_tick(delta: float) -> void:
	if dragon != null:
		dragon.advance(delta)
	_roost_frame(delta)

func _fly_tick(delta: float) -> void:
	if isle_chain != null: isle_chain.step(delta,plane,lode_state == "seated",camera.global_position)

## The halls collide on the ruins' layer.
func plane_mask() -> int:
	return super.plane_mask()|RuinBump.LAYER

func _into_plane() -> void:
	super._into_plane()
	# Back in the plane once the halls have begun, the arrow stays quiet.
	if _nose != null and isle_chain != null and isle_chain.state == "started": _nose.quiet(true)

func fly_from(at: Vector3, heading: float) -> void:
	super.fly_from(at,heading)
	if flying and isle_chain != null: isle_chain.forget()

func _show_fly_hint() -> void:
	super._show_fly_hint()
	if _switch_hint == null or plane == null: return
	if isle_chain != null and isle_chain.state == "started": _switch_hint.text += "\nThe halls rise out of the cloud ahead: fly on through them"

## With the chain, nothing happens by being near: only threading the ring.
func _check_arrival() -> void:
	if isle_chain != null: return
	super._check_arrival()

## With --autopilot, once the chain has a route: its pilot's input, till a
## real stick or key (turn, pitch, lean) takes over for good.
func _fly_input(delta: float) -> Dictionary:
	var input := super._fly_input(delta)
	if not autopilot or isle_chain == null or isle_chain.chain.halls.is_empty(): return input
	if absf(float(input.turn))+absf(float(input.pitch))+absf(float(input.lean)) > 0.05:
		autopilot = false
		return input
	if _auto_at < 0: _auto_at = isle_chain.chain.route_base
	var got: Array = isle_chain.chain.steer(plane,_auto_at)
	_auto_at = got[1]
	var out: Dictionary = got[0]
	out.boost = input.boost
	out.brake = input.brake
	return out

## With --capture-high, flying: frozen there, seen from high behind,
## looking on down the line.
func _capture_flying() -> void:
	if not _capture_high: return
	set_process(false)
	var on := Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	camera.fov = 60.0
	camera.look_at_from_position(plane.position-on*110.0+Vector3.UP*75.0,plane.position+on*170.0-Vector3.UP*10.0)

# --- The sky dragon (--dragon) --------------------------------------------------------

## The life, then the dragon over it.
func _add_life() -> void:
	super._add_life()
	if dragon_on: _build_sky_dragon()
	elif dragon_roost: _build_roost_dragon()
	# The plane's arc, before the watcher, who watches its tail fin.
	plane_arc = PlaneArc.new()
	add_child(plane_arc)
	plane_arc.setup(self)
	if Watcher.wanted() and sky != null and sky.get("serpent") != null:
		watcher = Watcher.new()
		add_child(watcher)
		watcher.setup(self)
	if NightLights.wanted(preload("res://scripts/launch_args.gd").user_args()):
		night_lights = NightLights.new()
		add_child(night_lights)
		night_lights.setup(self,night_lamp_spots)

# --- The watcher (scripts/kit_isle/watcher.gd, --watcher) ----------------------------

## A stranger on the south rim, telescope up, following a glint on the
## serpent's back (docs/design/watcher/round1.md): the plane's tail fin
## riding it (`watched_find`); null without --watcher.
const Watcher = preload("res://scripts/kit_isle/watcher.gd")
var watcher: Node3D = null

## What the watcher watches: the tail fin while it rides the serpent
## (scripts/plane_arc/plane_arc.gd `fin_holder`), else null.
func watched_find() -> Node3D:
	return plane_arc.fin_holder() if plane_arc != null else null

# --- The plane's arc (scripts/plane_arc/plane_arc.gd) ------------------------------------

## The plane broken till its six parts are found on foot, carried and fitted
## (docs/design/plane-arc/round1.md); its flags (--plane-fixed,
## --parts-carried, --part-at=<id>) are its own.
const PlaneArc = preload("res://scripts/plane_arc/plane_arc.gd")

# --- The night's lights (scripts/kit_isle/kit_night_lights.gd) ----------------------

## The isle's lanterns and its ruins' own light after dark
## (docs/design/night-light/round1.md, round2.md).
const NightLights = preload("res://scripts/kit_isle/kit_night_lights.gd")
var night_lights: Node3D = null

## Where the lanterns stand (x, z): a pair behind the parked plane, the
## grand stair's foot and head, the path from the plane to it, the circle's
## way in, the aqueduct's head, the heel stone, and either side of the
## gate on the far island (Art.GATE, which follows the aqueduct's run).
func night_lamp_spots() -> Array:
	var spots: Array = []
	if parked:
		var forward := Vector3(-sin(parked_heading),0.0,-cos(parked_heading))
		var right := Vector3(cos(parked_heading),0.0,-sin(parked_heading))
		for side: float in [-1.0,1.0]:
			var p := parked_at-forward*6.5+right*3.2*side
			spots.append(Vector3(p.x,parked_at.y+3.5,p.z))
	spots.append_array(NIGHT_LAMPS)
	# The circle's way in: on the summit's east side, NIGHT_WAY_IN degrees
	# round from the drift's landing (its last stone onto the summit at 30
	# degrees, 11 m out), so a hop up or down the drift doesn't land on it.
	var way_in := Art.at_polar(NIGHT_WAY_IN.x,NIGHT_WAY_IN.y)
	spots.append(Vector3(way_in.x,44.0,way_in.y))
	# The gate on the far island (Art.GATE), either side, in front of it.
	for side: float in [-1.0,1.0]: spots.append(Vector3(Art.GATE.x+3.2*side,33.5,Art.GATE.y+2.3))
	return spots

## A Vector3 spot is x, the top of its ray down, z: under the floating
## stones and lintels, so a lantern stands on the turf, not on them.
const NIGHT_LAMPS := [
	# The grand stair (Art.STAIR_AT 83.6, 0): its foot either side, its head.
	Vector3(88.6,33.5,-3.4),Vector3(88.6,33.5,3.4),Vector2(77.5,2.8),
	# The path from the plane toward the stair.
	Vector3(92.0,33.5,2.5),
	# The aqueduct's head and the heel stone (Art.HEEL 118, 0).
	Vector3(105.5,33.5,3.5),Vector3(115.5,33.5,1.8),
]
## The circle's way-in lantern (Art.at_polar: degrees, m from Art.HILL).
## Main stood it at 27.6 degrees, on the drift's landing (30, 11 m out).
const NIGHT_WAY_IN := Vector2(15.0,11.85)

## The kit's on-foot hint, and the dragon's line while it holds the treasure.
func _foot_text() -> String:
	var text := super._foot_text()
	if dragon != null:
		text += "\nV watches the dragon (chase, orbit, from here, off)  ·  G: it lets go of the rim"
	return text

## The dragon asleep on its roost (--dragon-roost): its own body posed
## lying on the mountain (scripts/dragon_roost.gd), not flying.
func _build_roost_dragon() -> void:
	roost_dragon = SkyDragon.new()
	roost_dragon.name = "RoostDragon"
	roost_dragon.sky_scene = self
	add_child(roost_dragon)
	roost_dragon.setup_roost(camera,DragonRoost.new())
	roost_air = RoostAir.new()
	add_child(roost_air)
	roost_air.setup()
	var wake: RefCounted = DragonWake.new()
	wake.setup(roost_dragon,roost_air,preload("res://scripts/launch_args.gd").user_args(),_world_hours,Vector3(IsleSky.MIDDLE.x,Art.TOP,IsleSky.MIDDLE.z))
	roost_dragon.wake = wake

## The world clock's hours so far (its day's 24 and the hour), or -1 while
## the day is held (a look preset, a capture, the day length 0): the wake's
## schedule runs on it.
func _world_hours() -> float:
	if weather == null or weather.clock == null or not weather.live or weather.day_length <= 0.0: return -1.0
	return float(weather.clock.day)*24.0+float(weather.clock.hour)

## Its breath and glow, seen only once its mountain stands; awake and off
## it, wherever he is.
func _roost_frame(delta: float) -> void:
	if roost_dragon == null: return
	var isle := _motif_isle("dragon_roost")
	var stands: bool = isle == null or isle.stands()
	roost_dragon.visible = stands or roost_dragon.awake()
	if roost_air != null: roost_air.visible = stands
	roost_dragon.advance(delta)

## The flying dragon (scripts/sky_dragon.gd) round the archipelago: the
## motif isles (within 700 m) are what it threads between and attacks.
func _build_sky_dragon() -> void:
	var places: Array = sky.places() if sky != null and sky.has_method("places") else []
	var list: Array = []
	for place: Array in places:
		var at: Vector3 = place[1]
		if at.distance_to(IsleSky.MIDDLE) < 700.0: list.append([at,float(place[2])])
	list.append([IsleSky.MIDDLE,60.0])
	dragon = SkyDragon.new()
	dragon.sky_scene = self
	add_child(dragon)
	# Its low passes cast their shadow across the near island's turf.
	var middle := Vector2.ZERO
	for p: Vector2 in Art.NEAR: middle += p
	middle /= float(Art.NEAR.size())
	dragon.shadow_at = Vector3(middle.x,Art.TOP,middle.y)
	# Its attacks: the motif isles, their records once they stand, their
	# birds; the pilot it can knock and who can take its treasure. Never
	# this isle: it is the starter isle, and the player shouldn't have to
	# mind the dragon here (`list` above is only what it flies round; its
	# `_attackable` turns this isle away too). Of the motif isles, only
	# those with room for its grip (scripts/sky_dragon.gd `_has_room`).
	for place: Array in places:
		dragon.targets.append({"name":str(place[0]),"home":place[1],"radius":float(place[2])*0.5})
	dragon.find_isle = _dragon_isle
	dragon.flush_birds = _flush_isle_birds
	dragon.walker = motor
	dragon.slide = ground.slide_callable()
	dragon.yielded.connect(_dragon_yielded)
	# --dragon-ride: the isles stand at once, so it can grip one with the
	# pilot already on it.
	if dragon_ride and sky != null: sky.flush()
	dragon.setup(camera,preload("res://scripts/launch_args.gd").user_args(),IsleChain.SEA_TOP,IsleSky.MIDDLE,Art.TOP,list)
	if dragon_ride and _place == Vector4.INF:
		_place = dragon.ride_spot()
		if _place != Vector4.INF: print("aqueduct isle: --dragon-ride starts the pilot at (%.1f, %.1f, %.1f) on %s" % [_place.x,_place.y,_place.z,str(dragon.grip.target.name)])
	if _switch_hint != null and not flying: _switch_hint.text = _foot_text()
	# Round 10: its blast is a gust for the plane.
	plane_air = _dragon_air

## The air the plane flies in: the dragon's blast (scripts/dragon_gale.gd
## `plane_gust`), or still air.
func _dragon_air(p: Vector3) -> Dictionary:
	if dragon == null or dragon.gale == null or plane == null: return {}
	return dragon.gale.plane_gust(p,plane.forward())

## --dragon-fly-test: each time the dragon breathes in on a rim, the plane
## is put on a pass through its blast (cross: 40 m to the side of the line
## 30 m out from the jaw, 14 m over the jaw (clear of the ruins), flying across it, in the
## blast's core about a second into the blow; land: 60 m to the side, low
## over the held turf 18 m in from the jaw, across the blast toward the isle's
## middle). Logged four times a second while the gust is on it.
func _fly_test_frame(delta: float) -> void:
	_fly_test_t += delta
	var now := str(dragon.breath) if str(dragon.state) == "clinging" else ""
	if now == "inhale" and _fly_test_breath != "inhale" and flying and plane != null:
		var mouth: Vector3 = dragon.mouth_at()
		var way: Vector3 = dragon.blast_way()
		var side := Vector3(-way.z,0.0,way.x)
		var at: Vector3
		var go: Vector3
		if _fly_test == "land":
			var over := mouth+way*18.0
			var floor: Variant = dragon.gale.air_floor(Vector2(over.x,over.z))
			over.y = (float(floor) if floor != null else mouth.y-4.0)+7.0
			at = over-side*60.0+Vector3.UP*5.0
			go = side
		else:
			var cross := mouth+way*30.0+Vector3.UP*14.0
			at = cross-side*40.0-way*4.0
			go = (side+way*0.1).normalized()
		fly_from(at,atan2(-go.x,-go.z))
		_fly_test_heading = float(plane.heading)
		_fly_test_log = 0.0
		print("dragon fly test: on %s's blast, the plane at (%.0f, %.0f, %.0f), the jaw at (%.0f, %.0f, %.0f)" % [str(dragon.grip.target.name),at.x,at.y,at.z,mouth.x,mouth.y,mouth.z])
	_fly_test_breath = now
	if not flying or plane == null: return
	_fly_test_log -= delta
	if _fly_test_log > 0.0: return
	_fly_test_log = 0.25
	var g: Dictionary = dragon.gale.plane_gust(plane.position,plane.forward())
	if g.is_empty(): return
	var w: Vector3 = g.wind
	var floor: Variant = dragon.gale.air_floor(Vector2(plane.position.x,plane.position.z))
	print("dragon fly test: t %.2f %s gust %.2f wind %.1f m/s (up %.1f) shove (%.2f, %.2f, %.2f), plane %.1f m/s, bank %.0f°, pitch %.0f°, turned %.0f°, %s, %s" % [_fly_test_t,now,float(g.gust),w.length(),w.y,
		(g.shove as Vector3).x,(g.shove as Vector3).y,(g.shove as Vector3).z,float(plane.speed),rad_to_deg(float(plane.bank)),rad_to_deg(float(plane.pitch)),
		rad_to_deg(wrapf(float(plane.heading)-_fly_test_heading,-PI,PI)),("%.1f m over the turf" % (plane.position.y-float(floor))) if floor != null else "over open air",ManualLanding.NAMES[hand_landing.phase]])

## The placed motif isle by id (scripts/kit_isle/motif_isle.gd), or null.
func _motif_isle(id: String) -> Node3D:
	var motifs: Variant = sky.get("motifs") if sky != null else null
	if motifs == null: return null
	for isle: Node3D in motifs.isles:
		if str(isle.motif.id()) == id: return isle
	return null

## A motif isle's record for the dragon, once it stands: its node (the
## whole isle, art, turf, water, bridges, plants and life under it, moved
## as one), its land (scripts/dragon_isle_shape.gd, sampled at rest), its
## main land's middle and radius, the shape's frame in the node's, and the
## point it tips about; {} until it stands.
func _dragon_isle(id: String) -> Dictionary:
	if _dragon_isles.has(id): return _dragon_isles[id]
	var isle := _motif_isle(id)
	if isle == null or not isle.stands(): return {}
	# Sampled only at rest (it is never posed before its first record).
	var shape: RefCounted = DragonIsleShape.new()
	shape.build(isle,get_world_3d().direct_space_state)
	if not shape.ok: return {}
	var home: Vector3 = shape.home
	var rec := {"node":isle,"shape":shape,"home":home,"radius":float(shape.radius),"exclude":shape.exclude,
		"frame":isle.global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,home),"pivot":home}
	_dragon_isles[id] = rec
	print("aqueduct isle: the dragon knows %s: its main land %.0f m across about (%.0f, %.0f, %.0f)" % [id,2.0*float(shape.radius),home.x,home.y,home.z])
	return rec

## The isle's birds burst out as the dragon slams onto its rim: the sky's
## gulls over it, and its own songbirds off their perches.
func _flush_isle_birds(at: Vector3) -> void:
	var near: Node3D = null
	var motifs: Variant = sky.get("motifs") if sky != null else null
	if motifs != null:
		var best := INF
		for isle: Node3D in motifs.isles:
			var c: Vector3 = isle.circle()
			var d := Vector2(at.x-c.x,at.z-c.y).length()
			if d < best:
				best = d
				near = isle
	if near != null:
		var own: Variant = near.life.get("birds") if near.life != null else null
		if own != null:
			for flock: Dictionary in own.flocks: own.flush(flock)
		var c: Vector3 = near.circle()
		at = Vector3(c.x,near.isle_top(),c.y)
	var life_node: Variant = sky.get("life") if sky != null else null
	if life_node == null: return
	var host: Variant = life_node.host_at(at)
	if host == null: return
	host.flushed = 0.0
	host.armed = false
	host.stir = 1.0

## The treasure taken: a pop and the flourish, a crystal on the readout.
func _dragon_yielded() -> void:
	print("aqueduct isle: the dragon's treasure is taken")
	if _moments == null:
		_moments = MomentsHud.new()
		add_child(_moments)
	_moments.pop("The dragon's treasure: it lets go of the rim",2.8)
	_moments.flourish()
	var sky_tokens = sky.get("collectibles") if sky != null else null
	if sky_tokens != null and sky_tokens.get("hud") != null: sky_tokens.hud.show_pickup("crystal",1,1,1)
	if _switch_hint != null and not flying: _switch_hint.text = _foot_text()
