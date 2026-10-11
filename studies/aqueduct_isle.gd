extends "res://studies/kit_isle.gd"
## The aqueduct isle: the ruins archipelago's aqueduct station (studies/
## island_packs/ruins_archipelago.gd, station 2) on its own, dressed in the
## gothic ruin kit and the game's real look, played on foot as the pilot.
## Two floating islands of faceted turf over hanging rock keels in the open
## sky at the game's noon (its sky, sun, grade and the cumulus sea far
## below: scripts/landscape_lighting.gd, studies/celestial.gd, scripts/
## look_pass.gd, as the ruin kit gallery has them); the aqueduct striding
## from its head on the near island over 16 m of sky to the far one, its
## channel still carrying water that spills through the fallen span.
##
## A kit isle (studies/kit_isle.gd, docs/scenic/kit-isle-shared.md: the
## pilot, the look rig, the plane, the lodestone, the grass, sky and life;
## the ground and rock the kit isles' one look). The pilot, camera, moves,
## recorder and replays are the character study's: the station's own
## boxes collide, invisible,
## under the stone (studies/aqueduct_isle_art.gd), so its proven routes
## hold. Round it, on one axis (z 0): the aqueduct with the castellum at
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
## moves the ring, --ring-near=<m> how near it wakes (420),
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
## The dragon (an experiment: docs/design/rim-dragon.md), with --dragon: a
## full-bodied dragon (scripts/sky_dragon.gd) rises out of the cloud sea and
## roams the archipelago, now and then low over the isle; V puts the camera
## on it. --dragon-look=a|b|c picks its dress (c by default); its other flags are its own.
## --dragon-ride (round 5) starts the pilot on foot on the isle it grips, to
## ride the sag and be flung by the snap; G makes it let go.
## Round 1's rim grip (scripts/rim_dragon.gd) is parked behind --dragon-rim:
## it swoops in, grips the east rim and blows gales across the isle; take
## the treasure off its tongue and it lets go (--dragon-perched, ...).
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Life = preload("res://studies/aqueduct_isle_life.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
## The hall chain's halls collide on the ruins' layer (scripts/hall_rise.gd).
const RuinBump = preload("res://scripts/ruin_bump.gd")
const RimDragon = preload("res://scripts/rim_dragon.gd")
const SkyDragon = preload("res://scripts/sky_dragon.gd")
## Where the rim dragon grips (world x, z on the near island's east rim) and
## the way it faces, into the isle.
const DRAGON_RIM := Vector2(126.6,-9.0)
const DRAGON_INTO := Vector2(-1.0,0.0)
## The flying dragon's attack targets (round 4), in turn: lone isles of
## the sky (IsleSky.ISLES names) seen from the turf, 270, 190 and 135 m off.
const DRAGON_TARGETS := ["hills_ne","meadow_south","grove_east"]

## The station this is (its key in the pack).
const STATION := 2
const SEED := 11
## What stands round the aqueduct besides the landmarks: [kit piece,
## seed, weathered, world x, z, yaw (degrees)], each standing on the ground
## there and colliding as the kit built it. Only the gate on the far
## island, where the aqueduct came down, and its paving.
const PIECES := [
	["arch",20,0.35,100.0,-62.5,0.0],
	["floor",23,0.6,94.5,-58.5,15.0],
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
## The stepping stumps back from the far island (world x, z from, z to,
## top): an older arcade's piers broken off at the islands' height, their
## feet hanging in the sky; each collides as a clean box.
const STUMPS := [[92.0,-26.7,-28.7,30.4],[92.0,-30.6,-32.6,29.8],[92.0,-36.0,-38.4,30.2]]

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
## The dragon, with --dragon (flying) or --dragon-rim (round 1's rim grip).
var dragon_on := false
var dragon_rim := false
## --dragon-ride (round 5): on foot on the isle it grips, to feel the sag,
## the snap and the launch.
var dragon_ride := false
var dragon: Node3D = null

func _ready() -> void:
	pack = "ruins_archipelago"
	_lode_at = LODE_PLATFORM
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-chain": chain_on = false
		elif arg == "--autopilot": autopilot = true
		elif arg == "--capture-high": _capture_high = true
		elif arg == "--dragon": dragon_on = true
		elif arg == "--dragon-ride":
			dragon_on = true
			dragon_ride = true
		elif arg == "--dragon-rim": dragon_rim = true
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
	start = kept[0].spawn
	start_face = kept[0].face
	_last_stood = start

## The station's parts as clean, invisible collision (the islands' slabs
## and the moss pad left out: the islands are built), then the art.
func _build_room() -> void:
	for station: Dictionary in stations:
		for part: Array in station.parts:
			if part[0] == "box" and float(part[3]) <= Art.TOP+0.11: continue
			if part[0] == "label": continue
			_part(part)
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
	for spec: Array in PIECES:
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

# --- The isle's hooks --------------------------------------------------------------

func isle_name() -> String:
	return "aqueduct isle"

## Placeholder name, line and finds until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"The Aqueduct of Veyl","epithet":"Where the old water still walks the sky","finds":[["wildflower","Glyphs",2,7],["crystal","Lodestones",0,1],["bridge","Hidden ways",1,3]]}

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

## The lodestone on its floating stone (`_lode_at`, else LODE_PLATFORM).
func lode_rest_at() -> Vector3:
	var p: Dictionary = Art.platform(_lode_at)
	if p.is_empty():
		push_warning("aqueduct isle: no platform '%s'; %s instead" % [_lode_at,LODE_PLATFORM])
		p = Art.platform(LODE_PLATFORM)
	return (p.at as Vector3)+Vector3.UP*LODE_HOVER

func lode_hint() -> String:
	return "A lodestone hums on a floating stone east, past the heel stone: climb up to it"

## Only the station's recordings replay here.
func _pack_runs() -> PackedStringArray:
	var found := PackedStringArray()
	for path in _station_runs():
		if int(Recording.read(path).get("station",0)) == STATION: found.append(path)
	return found

## The stepping stumps (STUMPS): an older arcade's piers, coursed solid
## to their tops, mossed and tufted there, their feet broken off under the
## islands; collided as clean boxes.
func _stumps() -> Node3D:
	var b := RuinKit.Build.new(SEED+5,0.6,"Stumps")
	b.settle = Aqueduct.SETTLE
	for s: Array in STUMPS:
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
	if _near_ring: board()
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
	var half := Vector3.ONE*(PlaneFigure.SPAN*0.5+0.3)
	return AABB((plane.position as Vector3)-half,half*2.0)

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
		if dragon_rim: dragon.advance(delta,not flying)
		else:
			if _atmosphere != null:
				dragon.air = _atmosphere.breeze()
				dragon.air_angle = _atmosphere._air_angle
			dragon.on_foot = not flying
			dragon.advance(delta)

## A fixed-eye capture (--at) still flies the dragon.
func _capture_tick(delta: float) -> void:
	if dragon != null and not dragon_rim:
		dragon.advance(delta)

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

# --- The rim dragon (--dragon) --------------------------------------------------------

## The life, then the dragon over it.
func _add_life() -> void:
	super._add_life()
	if dragon_rim: _build_dragon()
	elif dragon_on: _build_sky_dragon()

## The kit's on-foot hint, and the dragon's line while it holds the treasure.
func _foot_text() -> String:
	var text := super._foot_text()
	if dragon != null and not dragon_rim:
		text += "\nV watches the dragon (chase, orbit, from here, off)  ·  G: it lets go of the rim"
	if dragon != null and dragon_rim and not dragon.taken:
		text += "\nThe dragon on the east rim holds a treasure in its mouth: get to it between gusts; when it breathes in, get behind stone"
	return text

## The dragon (scripts/rim_dragon.gd) on the east rim, over the cloud sea.
func _build_dragon() -> void:
	var rim := Vector3(DRAGON_RIM.x,Art.ground(DRAGON_RIM.x-1.0,DRAGON_RIM.y),DRAGON_RIM.y)
	dragon = RimDragon.new()
	add_child(dragon)
	dragon.setup(motor,ground.slide_callable(),rim,DRAGON_INTO,IsleChain.SEA_TOP,preload("res://scripts/launch_args.gd").user_args())
	dragon.gust.connect(_dragon_gust)
	dragon.yielded.connect(_dragon_yielded)
	if _switch_hint != null and not flying: _switch_hint.text = _foot_text()

## The flying dragon (scripts/sky_dragon.gd) round the archipelago: the near
## isles and clusters (within 700 m) are what it threads between.
func _build_sky_dragon() -> void:
	var list: Array = []
	for isle: Array in IsleSky.ISLES:
		var at: Vector3 = isle[3]
		if at.distance_to(IsleSky.MIDDLE) < 700.0: list.append([at,float(isle[4])])
	for cluster: Array in IsleSky.CLUSTERS:
		var at: Vector3 = cluster[2]
		if at.distance_to(IsleSky.MIDDLE) < 700.0: list.append([at,40.0])
	list.append([IsleSky.MIDDLE,60.0])
	dragon = SkyDragon.new()
	add_child(dragon)
	# Its low passes cast their shadow across the near island's turf.
	var middle := Vector2.ZERO
	for p: Vector2 in Art.NEAR: middle += p
	middle /= float(Art.NEAR.size())
	dragon.shadow_at = Vector3(middle.x,Art.TOP,middle.y)
	# Its attacks: the far isles it clings to, their built records, their
	# birds; the pilot it can knock and who can take its treasure.
	for want: String in DRAGON_TARGETS:
		for isle: Array in IsleSky.ISLES:
			if isle[0] == want: dragon.targets.append({"name":want,"home":isle[3],"radius":float(isle[4])})
	dragon.find_isle = func(isle_name: String) -> Dictionary:
		return sky.isles.get(isle_name,{}) if sky != null and sky.get("isles") != null else {}
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

## The far isle's songbirds burst out of its crown and its gulls stir, as
## the dragon slams onto its rim.
func _flush_isle_birds(at: Vector3) -> void:
	var life_node: Variant = sky.get("life") if sky != null else null
	if life_node == null: return
	var host: Variant = life_node.host_at(at)
	if host == null: return
	host.flushed = 0.0
	host.armed = false
	host.stir = 1.0

## Each gale as a strong gust front along its way, so the grass and the
## air's ribbons lie over with it.
func _dragon_gust(way: Vector2) -> void:
	var focus := camera.global_position
	var fronts: RefCounted = _atmosphere.fronts
	fronts.set_bounds(Vector2(focus.x,focus.z),36.0)
	for i in range(fronts.fronts.size()): fronts.fronts[i] = {}
	fronts.send(way,1.0,Atmosphere.breeze_air(_atmosphere._air_strength),1.0)

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
