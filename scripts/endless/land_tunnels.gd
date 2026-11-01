extends Node3D
## The mountain tunnels' bores (scripts/endless/tunnel_sites.gd), as the
## flight, the camera and the wheels meet them, and a greybox of each:
## the tube (floor, walls, flat roof) along the path, through a portal block
## at each mouth. The land's surface stays whole over the bore (the massif's
## heightmap), so under the bore's roof and inside its walls the land's
## height is not the solid: `ground`, `land_y` and `inside` answer for the
## rock round the tube. The land mesh drops its triangles on each portal's
## footprint (land_stream.gd), and the block hides the hole's edge.
##
## The hall stretches (Tunnels.stretches: one straight slot piece on each
## hall piece of the path) stand in the tube through a LandHalls of their
## own (`halls`, fixed pieces only: far detail on a worker, near detail
## streamed section by section round the eye, the kit's bodies on layer 1).
## Their solid joins the bore's: `ground` stands the hall's stretches on the
## bore's floor with the rock roof as one more stretch over them
## (LandHalls `over`), and `inside` counts them.
##
## The --tunnel-test tunnel is built whole at setup (a tube of a few
## thousand quads); streamed ones (the field's `tunnels_in`, one per
## Tunnels.CELL square from the seed) are found and built whole on a
## WorkerThreadPool task (its own field) as their box comes within
## STREAM_REACH m of the eye (looked for every STREAM_MOVE m), stood on the
## main thread one a frame, and dropped past STREAM_DROP. `prime` builds
## those within PRIME_REACH on the main thread, so the start's is there at
## once. Each built tunnel is a `Built`: its node and what the pools, the
## braziers and the daylight read; only those near the eye are ranked.

const Field = preload("res://scripts/endless/land_field.gd")
const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const TUNNEL_STONE = preload("res://shaders/tunnel_stone.gdshader")
const Flame = preload("res://scripts/flame.gd")
const HangingRoots = preload("res://scripts/shared/hanging_roots.gd")
const UndergrowthMesh = preload("res://scripts/undergrowth_mesh.gd")

## Physics layer of the greybox's bodies (the walker, the wheels).
const LAYER := 1
## The render layer of everything inside the bore (the rock, the hall
## stretches, the torches): the sun and the moon (every DirectionalLight3D)
## leave it out, so only the torches light the inside.
const UNDER_LAYER := 1 << 14
## The portal (knobs): a mass of carved rock on the mouth's footprint
## (Tunnels.portal_at), its top PORTAL_OVER m over the land or, over the
## opening, CAP_OVER m over the vault, flat CAP_FLAT m either side of the
## way and falling CAP_FALL m a metre past that; its skin a grid of
## SKIN_STEP m, its edges sunk SKIRT m into the land. Its front is cut
## sheer at the footprint's outer edge.
const PORTAL_OVER := 0.6
const CAP_OVER := 16.0
const CAP_FLAT := 24.0
const CAP_FALL := 2.4
## The cap's top broken by up to CAP_ROUGH m of the bore's rock noise,
## CAP_GRAIN times finer than the walls' swell.
const CAP_ROUGH := 3.5
const CAP_GRAIN := 4.0
const SKIN_STEP := 4.0
const SKIRT := 5.0
## The sides and back sink SKIRT_FAR m (over the tube only down to
## SKIRT_TUBE m over its crown): a coarse chunk's quads (16-64 m, from about
## 1.3 km) fall that far under the land the skin follows, and the skin would
## stand on nothing there.
const SKIRT_FAR := 30.0
const SKIRT_TUBE := 1.5
## Past DOOR_FROM m a dark door stands DOOR_IN m inside each gate (seen
## only from outside): a coarse chunk's land crosses the tube behind the
## gate (the heightmap can't step from the trench's floor to the rock over
## the tube within a quad), and from afar the opening reads as a dark way
## in, not a sunlit slope in a frame.
const DOOR_FROM := 1200.0
const DOOR_IN := 1.0
const DOOR_TINT := Color(0.035,0.026,0.02)
## The gate on the portal's front: jambs JAMB_W wide either side of the
## opening, a lintel LINTEL_H high over the vault running LINTEL_PAST past
## the jambs, a pediment PED_H high over it, all FRAME_OUT proud of the
## face; a fire bowl on each end of the lintel (BOWL: half width, height),
## its fire FIRE_R round and a light FIRE_RANGE m.
const JAMB_W := 4.0
const LINTEL_H := 4.5
const LINTEL_PAST := 2.0
const PED_H := 9.0
const FRAME_OUT := 2.5
const BOWL := Vector2(1.6,1.4)
const FIRE_R := 0.9
## The bowls' fires: flame.gd braziers this big (its light is FIRE_RANGE's).
const FIRE_SCALE := 3.6
const FIRE_RANGE := 26.0
const FIRE_ENERGY := 4.0
const FACE_TINT := Color(0.5,0.43,0.36)
const SKIN_TINT := Color(0.74,0.64,0.52)
const FRAME_TINT := Color(0.94,0.9,0.83)
## The portals' texture: its darkest (ROCK_TEX_LOW for the bore's rock),
## so the cut stone reads even in the sun.
const PORTAL_TEX_LOW := 0.86
## Daylight in at each mouth: a spot SPILL_IN m inside the front, SPILL_Y
## over the floor, looking SPILL_AIM m in at the floor, lighting the
## inside's layer in the sun's colour at SPILL_ENERGY x its energy, its
## falloff SPILL_ATTEN (Godot's decay: low, so it carries in).
const SPILL_IN := 1.0
const SPILL_Y := 13.0
const SPILL_AIM := 45.0
const SPILL_RANGE := 110.0
const SPILL_ANGLE := 50.0
const SPILL_ENERGY := 2.0
const SPILL_ATTEN := 0.35
## The test tunnel's start: this high over the bore's floor, so the plane
## flies straight in at mouth A (unless --alt= is given).
const TEST_ALT := 9.0
## The shafts (Tunnels.shafts), knobs: the vault's roof is cut open within
## SHAFT_CUT m of the axis (past SHAFT_R: the jagged edge of whole
## triangles), and a lip rises from LIP_R m (a skirt from the vault's solid
## LIP_UP m up into the rock, then a flare to the shaft's radius FLARE_H m
## over the crown); the shaft's wall in rings every SHAFT_RING m, SHAFT_SEGS
## round, lumped outward by up to ROCK_LUMP m, its tint darkening from the
## sky down; a curb of dressed stone CURB_H m high and CURB_W m wide round
## the top (covering the land's hole, HOLE_PAD), sunk SKIRT m. Daylight
## down it: a spot from the top (SHAFT_SPREAD: the pool's radius on the
## floor over the shaft's), SHAFT_ENERGY x the sun, and a faint beam
## (BEAM_ALPHA).
const SHAFT_CUT := Tunnels.SHAFT_R+4.0
const LIP_R := SHAFT_CUT+1.0
const LIP_UP := Tunnels.ROCK_LUMP+0.4
const FLARE_H := 3.0
const SHAFT_RING := 4.0
const SHAFT_SEGS := 28
const CURB_H := 1.1
const CURB_W := 3.6
const SHAFT_SPREAD := 2.2
const SHAFT_ENERGY := 8.0
const BEAM_ALPHA := 0.035
const BEAM_TINT := Color(1.0,0.93,0.78)
## Streaming (`_stream`): a tunnel is built when its box comes within
## STREAM_REACH m of the eye, looked for every STREAM_MOVE m it moves, and
## dropped when its box is past STREAM_DROP; `prime` builds those within
## PRIME_REACH at once.
const STREAM_REACH := 2500.0
const STREAM_DROP := 3500.0
const STREAM_MOVE := 200.0
const PRIME_REACH := 800.0
## The braziers burn (and their bowls' lights shine) within FIRE_REACH m of
## the eye, past their flames' own draw distance (FIRE_SCALE x 110 m); the
## mouths' and shafts' daylight within DAY_REACH of the tunnel's box.
const FIRE_REACH := 450.0
const DAY_REACH := 600.0
## The collider's pieces (triangles each), and the main thread's time for
## standing them each frame (ms; at least one stands a frame).
const BODY_TRIS := 4000
const BODY_BUDGET := 3.0
## How far past the tube's walls `inside` counts the rock (m).
const WALL_NEAR := 12.0
## The guard (`guide`): how near the clear room's edge it starts (m), its
## push off a wall or the roof at the edge and its lift off the floor
## (m/s), how far ahead it reads the room (s at the speed), and how near
## the roof and the floor it starts (m).
const GUARD_MARGIN := 6.0
const GUARD_PUSH := 14.0
const GUARD_LIFT := 6.0
const GUARD_LOOK := 0.5
const GUARD_ROOF := 4.0
const GUARD_FLOOR := 2.5
## How far inside the clear room's edge `keep` puts a point back (m).
const KEEP_IN := 0.05
## The camera's sight in a bore (`sight`): marched every SIGHT_STEP m
## where either end is within a tunnel's box and SIGHT_UP m over its floor.
const SIGHT_STEP := 0.75
const SIGHT_UP := 60.0

## The torch: an iron sconce (a plate on the wall, an arm rising out of it
## to a cup TORCH_CUP out and up), its flame card (width, height) and its
## real flame (flame.gd's torch times TORCH_FIRE), the size and glow by
## kind, all times TORCH_SIZE.
const TORCH_CUP := Vector2(0.62,0.12)
const TORCH_FLAME := Vector2(0.9,1.25)
const TORCH_FIRE := 1.6
const TORCH_SIZE := 1.5
const TORCH_BIG := {"wall":1.0,"outside":1.35,"mouth":2.2,"glow":1.5}
const TORCH_GLOW := {"wall":Color(1.0,0.55,0.16),"outside":Color(1.0,0.78,0.38),"mouth":Color(1.0,0.66,0.26),"glow":Color(0.4,0.8,0.68)}
## The sunk caves' glows' light (no flame, a cold wash).
const GLOW_LIGHT := Color(0.82,0.88,0.8)
const GLOW_POWER := 1.1
## Its fire in three tiers: the FLAME_POOL torches nearest the eye burn as
## real flames (scripts/flame.gd: volumes, sparks, smoke), easing in and out
## over FLAME_EASE s as the pool moves; every other torch is a glowing flame
## card (one MultiMesh), and far down the bore the card holds at least
## CARD_DOT rad across, a dot of glow.
const FLAME_POOL := 16
const FLAME_EASE := 0.35
const CARD_DOT := 0.006
## The pools (flames and lights) rank torches by their distance from a point
## POOL_AHEAD m ahead of the eye, so more of them light the way ahead.
const POOL_AHEAD := 24.0

## The carved rock's mesh: segments round a ring, across the floor, a
## cavern's rings apart (m); the lumps (m, Tunnels.ROCK_LUMP).
const RING_SEGS := 32
const FLOOR_SEGS := 6
const CAVE_RING := 2.0
## A sunk cave's lumps over ROCK_LUMP.
const CAVE_LUMP := 2.6
const ROCK_LUMP := Tunnels.ROCK_LUMP
const HALL_ROCK_TINT := Color(0.42,0.4,0.37)
const FLOOR_TINT := Color(0.36,0.33,0.29)
const CAVE_TINT := Color(0.46,0.4,0.33)
const BLOCK_TINT := Color(0.4,0.37,0.33)
## The basalt (shaders/tunnel_basalt.gdshader): its growth (`_green`: the
## least anywhere, more in patches, full GREEN_MOUTH m in from a mouth and
## GREEN_SHAFT m round a shaft); the columns along the caverns' walls
## (`_build_columns`): a column's width, the rows out from each wall, the
## first row's height (m, a range by the wall's swell), the second's top,
## the first's top by a torch.
const GREEN_BASE := 0.3
const GREEN_PATCH := 0.5
const GREEN_MOUTH := 90.0
const GREEN_SHAFT := 40.0
const COLUMN_CELL := 1.7
const COLUMN_ROWS := 3
const COLUMN_TALL := Vector2(1.6,7.5)
const COLUMN_STEP := 1.4
const COLUMN_UNDER_TORCH := 5.0
const BASALT = preload("res://shaders/tunnel_basalt.gdshader")
const CAVE_ROCK = preload("res://shaders/tunnel_cave.gdshader")
## The overgrowth (`_build_growth`), each the more where the rock is green
## (`_green`): strands from the vault every VINE_STEP m along, VINE_VAULT of
## them at the most, VINE_LONG m long (by the walls; shorter by the crown);
## a curtain down a cavern's wall where it is greener than CURTAIN_GREEN,
## CURTAIN strands; vines off a hall stretch's architraves; ferns at the
## walls' feet and out of the rock every FERN_STEP m, FERN of them at the
## most, FERN_SIZE across (a range). Drawn within GROWTH_FAR m, in chunks
## GROWTH_CHUNK m along. Their colours: bark, vine green, fern green. The
## leafy curtains (shaders/tunnel_vines.gdshader): cards CARD_WIDE m wide
## (a range) in a curtain or off an architrave; a vault's leafy tuft where
## it is greener than TUFT_GREEN.
const VINE_STEP := 2.0
const VINE_VAULT := 6
const VINE_LONG := Vector2(2.0,11.0)
const CURTAIN_GREEN := 0.25
const CURTAIN := 9
const FERN_STEP := 1.6
const FERN := 6
const FERN_SIZE := Vector2(1.6,3.8)
const GROWTH_FAR := 150.0
const GROWTH_CHUNK := 120.0
const ROOT_BARK := Color(0.16,0.12,0.09)
const VINE_GREEN := Color(0.1,0.21,0.05)
const FERN_GREEN := Color(0.14,0.3,0.07)
const CARD_WIDE := Vector2(1.1,2.0)
const TUFT_GREEN := 0.45
const VINES = preload("res://shaders/tunnel_vines.gdshader")
const STRANDS = preload("res://shaders/tunnel_strands.gdshader")
const FERN_LOOK = preload("res://shaders/tunnel_fern.gdshader")
## The rock's texture: a ridged noise worn triplanar in world space, ROCK_TILE
## m a repeat, its relief ROCK_BUMP; ROCK_TEX_LOW the darkest it takes the
## vertex colour to.
const ROCK_TILE := 9.0
const ROCK_BUMP := 5.0
const ROCK_TEX_LOW := 0.62

## The dark inside (knobs): the hall stretches' stone and growth keep
## STONE_DIM of their sky fill (shaders/tunnel_stone.gdshader), so the
## torches carry them; the carved rock takes no fill at all.
const STONE_DIM := 0.08
## The stretches' stone lifted less than in the sun (LandHalls STONE_LIFT),
## so under the torches it sits with the rock.
const STONE_LIFT := Color(1.53,1.32,1.06)
## The stretches' stone weathered harder than in the sun (kit_weather's
## grain, pits and cracks, `--hall-weather=X`) and its bump deeper
## (`--hall-bump=X`): under a torch's raking light the smooth kit stone read
## as card (found in play).
const STONE_WEATHER := 1.5
const STONE_CRACK := 1.6
const STONE_BUMP := 2.0
const GROWTH_DIM := 0.08
## The torches' lights: the nearest TORCH_LIGHTS torches to the eye get a
## real light, TORCH_RANGE m, TORCH_ENERGY, falling off by TORCH_ATTEN,
## flickering by TORCH_FLICKER; past LIGHT_REACH m none do, and the farthest
## lit ones fade over LIGHT_FADE m so a light coming on doesn't pop. The
## TORCH_SHADOWS nearest cast shadows (`--torch-shadows=N`), so a column
## darkens its far side and throws its shadow on the floor; about +1.4 ms
## GPU and +0.6 ms render CPU inside at 4 (8: +2.0, +1.1). Before, 16 lights
## without shadows and a flat falloff (0.8) lit every face of a hall alike:
## the cardboard look (found in play). `--torch-energy=X`, `--torch-atten=X`.
const TORCH_LIGHTS := 16
const TORCH_SHADOWS := 4
const TORCH_RANGE := 30.0
const TORCH_ENERGY := 13.0
const TORCH_ATTEN := 1.15
const TORCH_FLICKER := 0.12
const TORCH_LIGHT := Color(1.0,0.74,0.5)
const LIGHT_REACH := 260.0
const LIGHT_FADE := 40.0
## Each shadowed torch's bounce: a dim light with no shadow or gleam, out in
## the bore (BOUNCE_OUT of the way from the wall to the path, BOUNCE_DOWN m
## under the torch), BOUNCE of its torch's energy (BOUNCE_CAVE of that in a
## cavern, whose floor it would light flat), so the far side of a column is
## dim, not black (`--torch-bounce=X`, 0 none).
const BOUNCE := 0.1
const BOUNCE_CAVE := 0.3
const BOUNCE_RANGE := 34.0
const BOUNCE_ATTEN := 0.6
const BOUNCE_OUT := 0.6
const BOUNCE_DOWN := 0.5
const BOUNCE_LIGHT := Color(1.0,0.8,0.6)

## `--name=X` as a float, else `fallback`.
static func _knob(name: String, fallback: float) -> float:
	for a: String in Tunnels.LaunchArgs.user_args():
		if a.begins_with("--%s=" % name): return float(a.get_slice("=",1))
	return fallback
## The valley fog (EndlessClouds `fog_hush`) fades out over the first
## HUSH_IN m into the bore from either mouth: it would haze the dark inside.
const HUSH_IN := 60.0

## A built tunnel: its site, the node holding everything it stands (not
## yet in the tree while a worker builds it), and what the pools, the
## braziers and the daylight read. `id` keys its torches (id << 16 | i).
class Built extends RefCounted:
	var id := 0
	var site: RefCounted
	var node: Node3D
	## Each torch's light spot (world) and size; its flame's foot and size;
	## its card's tint; the cards' MultiMesh.
	var lamps := PackedVector3Array()
	var lamp_big := PackedFloat32Array()
	var feet := PackedVector3Array()
	var feet_big := PackedFloat32Array()
	var tint: Array[Color] = []
	var cards: MultiMesh
	## The mouths' and shafts' daylight (its gain on the sun), the beams.
	var spills: Array[SpotLight3D] = []
	var spill_gain := PackedFloat32Array()
	var beams: Array[MeshInstance3D] = []
	## The braziers and their bowls' lights, and whether they burn.
	var fires: Array[Node3D] = []
	var fire_lights: Array[OmniLight3D] = []
	var burning := false
	## The hall stretches' infos (LandHalls `add_fixed`) and their keys
	## once stood.
	var stretches: Array = []
	var keys: Array[Vector2i] = []
	## The collider's pieces not yet stood (`_stand_bodies`).
	var bodies: Array[StaticBody3D] = []
	var tris := 0
	var torches := 0
	var ms := 0.0

var field: RefCounted
var stats := {"tunnels":0,"tris":0,"torches":0,"stretches":0,"lights":0}
## The hall stretches' streamer.
var halls: Node3D
## shaders/endless_sea.gdshader `dry_cut`'s size.
const DRY_CUTS := 8
## The look's clouds (their valley fog hushed in the bore), or null.
var clouds: Node
## The land's ground material, which a sunk cave's mouth rock wears.
var _ground: Material
## The sea's material, cut along the sunk tunnels' ramps (`_cut_sea`), or null.
var sea: ShaderMaterial
var _cuts := -1
var _sea_hushed := false
## The stood tunnels' sites (the solid's queries walk these), and each
## Built by its name and by its id.
var _sites: Array = []
var _built := {}
var _by_id := {}
var _next_id := 1
## The streaming task (-1 none), the tunnels it built waiting to stand
## (under `_lock`), where `_stream` last looked.
var _task := -1
var _lock := Mutex.new()
var _done: Array = []
var _quit := false
var _streamed_at := Vector3.INF
## The plane's wingtip: the tube's half width it may fly in.
var _grow := 0.0
## Whether the hall stretches' naves stand open (Tunnels `open_nave`).
var _open_nave := true
## Whether `sight`'s last march was all in a bore's tube.
var sight_whole := false
var _lights: Array[OmniLight3D] = []
var _bounce: Array[OmniLight3D] = []
var _torch_energy := TORCH_ENERGY
var _bounce_gain := BOUNCE
## The pooled flames, which torch each burns (id << 16 | i, -1 none) and
## how far it has burned in.
var _flames: Array[Node3D] = []
var _flame_on := PackedInt64Array()
var _flame_burn := PackedFloat32Array()
var _time := 0.0
var _sky_cut := false
## The sun (the brightest DirectionalLight3D).
var _sun: DirectionalLight3D

func setup(land_field: RefCounted, ground: Material = null) -> void:
	field = land_field
	_ground = ground
	_grow = WorldScale.span*0.5
	_open_nave = Tunnels.open_nave()
	# Made here, once: the workers' builds share them.
	_beam_shader()
	_card_shader()
	_door_material()
	_growth_materials()
	halls = LandHalls.new()
	halls.name = "Stretches"
	halls.squares = false
	halls.swap = _dark_materials()
	halls.swap_of = _dark_materials
	halls.swap_layers = UNDER_LAYER
	add_child(halls)
	halls.setup(int(field.seed))
	halls.density = 1.0
	stats.lights = 0
	stats["flames"] = 0
	stats["fires"] = 0
	stats["commit_ms"] = 0.0
	stats["dropped"] = 0
	var fixed: Array = field.tunnel_sites() if field.has_method("tunnel_sites") else []
	for t: Tunnels.Site in fixed: _commit(_make(t,field))

func _exit_tree() -> void:
	_quit = true
	if _task >= 0: WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	for b: Built in _done: _free_built(b)
	_done.clear()

## Frees built tunnel `b` that never stood.
static func _free_built(b: Built) -> void:
	for body in b.bodies: body.free()
	b.bodies.clear()
	b.node.free()

## Tunnel `t` built whole off the tree with field `f` (the caller's own:
## a worker's, or `field` on the main thread): its rock, portals, fires,
## shafts, torches and its hall stretches' infos.
func _make(t: Tunnels.Site, f: RefCounted) -> Built:
	var t0 := Time.get_ticks_usec()
	var b := Built.new()
	b.site = t
	b.node = Node3D.new()
	b.node.name = t.name.replace("/","_")
	_build(b,f)
	_build_torches(b)
	for h: Dictionary in Tunnels.stretches(t):
		var frame: Transform3D = h.frame
		var half := float(h.piece.s1-h.piece.s0)*0.5
		var mid := frame*Vector3(half,0.0,0.0)
		var site := PackedFloat32Array([mid.x,mid.z,0,0,0,0,0,half+Tunnels.HALL_HALF])
		b.stretches.append({"n":int(h.n),"info":{"name":"%s/stretch_%d" % [t.name,int(h.n)],"seed":h.seed,"bays":h.bays,
			"frame":frame,"coded":frame,"site":site,"piece":Tunnels.stretch_piece(h)}})
	b.ms = (Time.get_ticks_usec()-t0)/1000.0
	return b

## Stands built tunnel `b` (main thread): into the tree, its stretches to
## the halls, the pools readied with the first torches.
func _commit(b: Built) -> void:
	var t0 := Time.get_ticks_usec()
	b.id = _next_id
	_next_id += 1
	add_child(b.node)
	_sites.append(b.site)
	_built[b.site.name] = b
	_by_id[b.id] = b
	for h: Dictionary in b.stretches:
		var key := Vector2i(b.id,int(h.n))
		halls.add_fixed(key,h.info)
		b.keys.append(key)
	stats.stretches += b.keys.size()
	stats.tris += b.tris
	stats.torches += b.torches
	stats.tunnels = _sites.size()
	_ensure_pools()
	stats["build_ms"] = maxf(float(stats.get("build_ms",0.0)),b.ms)
	stats.commit_ms = maxf(float(stats.commit_ms),(Time.get_ticks_usec()-t0)/1000.0)

## Takes tunnel `b` down: its flames out of the pool, its stretches, its
## node.
func _drop(b: Built) -> void:
	for j in _flames.size():
		if _flame_on[j] >= 0 and (_flame_on[j] >> 16) == b.id:
			_flame_on[j] = -1
			_flame_burn[j] = 0.0
			_flames[j].set("burn",0.0)
	for key: Vector2i in b.keys: halls.remove_fixed(key)
	for body in b.bodies: body.free()
	b.bodies.clear()
	_sites.erase(b.site)
	_built.erase(b.site.name)
	_by_id.erase(b.id)
	b.node.queue_free()
	stats.stretches -= b.keys.size()
	stats.tris -= b.tris
	stats.torches -= b.torches
	stats.tunnels = _sites.size()
	stats.dropped += 1

## How far (x, z) of `at` lies outside `box` (0 in it).
static func _gap(box: Rect2, at: Vector3) -> float:
	var dx := maxf(maxf(box.position.x-at.x,at.x-box.end.x),0.0)
	var dz := maxf(maxf(box.position.y-at.z,at.z-box.end.y),0.0)
	return Vector2(dx,dz).length()

## Whether tunnels stream (not with --tunnel-test, which keeps its own).
func _streams() -> bool:
	return field != null and field.has_method("tunnel_test") and not field.tunnel_test()

## Streaming: stands one tunnel the worker built (a frame), and every
## STREAM_MOVE m drops those past STREAM_DROP and sends a task to find and
## build those within STREAM_REACH.
func _stream(at: Vector3) -> void:
	if not _streams(): return
	_stand_one(at)
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task): return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _streamed_at != Vector3.INF and Vector2(at.x-_streamed_at.x,at.z-_streamed_at.z).length() < STREAM_MOVE: return
	_streamed_at = at
	for b: Built in _built.values():
		if _gap(b.site.box,at) > STREAM_DROP: _drop(b)
	var have := {}
	for name: String in _built: have[name] = true
	_lock.lock()
	for b: Built in _done: have[b.site.name] = true
	_lock.unlock()
	_task = WorkerThreadPool.add_task(_find_and_build.bind(at,have),false,"Tunnels")

## The worker: finds the tunnels within STREAM_REACH of `at` with a field
## of its own and builds, nearest first, those not in `have`.
func _find_and_build(at: Vector3, have: Dictionary) -> void:
	if _quit: return
	var f: RefCounted = Field.new(int(field.seed),field.world)
	var got: Array = f.tunnels_in(at.x-STREAM_REACH,at.z-STREAM_REACH,at.x+STREAM_REACH,at.z+STREAM_REACH)
	got.sort_custom(func(a: Tunnels.Site, b: Tunnels.Site) -> bool: return _gap(a.box,at) < _gap(b.box,at))
	for t: Tunnels.Site in got:
		if _quit: return
		if have.has(t.name) or _gap(t.box,at) > STREAM_REACH: continue
		var b := _make(t,f)
		_lock.lock()
		_done.append(b)
		_lock.unlock()

## Stands the next built tunnel, unless it is stood already or now past
## STREAM_DROP.
func _stand_one(at: Vector3) -> void:
	_lock.lock()
	var b: Built = _done.pop_front() if not _done.is_empty() else null
	_lock.unlock()
	if b == null: return
	if _built.has(b.site.name) or _gap(b.site.box,at) > STREAM_DROP:
		_free_built(b)
		return
	_commit(b)

## The flame and light pools, made once there are torches.
func _ensure_pools() -> void:
	if not _flames.is_empty() or int(stats.torches) <= 0: return
	for i in FLAME_POOL:
		var fl: Node3D = Flame.new()
		fl.name = "TorchFlame%d" % i
		fl.set("kind","torch")
		fl.set("with_light",false)
		fl.set("dark",true)
		fl.set("layer_mask",UNDER_LAYER)
		fl.set("vis_end",LIGHT_REACH)
		fl.set("burn",0.0)
		add_child(fl)
		_flames.append(fl)
		_flame_on.append(-1)
		_flame_burn.append(0.0)
	# The pool is ranked nearest first, so the first lights are the shadowed.
	var shadows := int(_knob("torch-shadows",TORCH_SHADOWS))
	var atten := _knob("torch-atten",TORCH_ATTEN)
	_torch_energy = _knob("torch-energy",TORCH_ENERGY)
	_bounce_gain = _knob("torch-bounce",BOUNCE)
	for i in TORCH_LIGHTS:
		var l := OmniLight3D.new()
		l.name = "TorchLight%d" % i
		l.light_color = TORCH_LIGHT
		l.omni_range = TORCH_RANGE
		l.omni_attenuation = atten
		l.shadow_enabled = i < shadows
		l.shadow_blur = 1.5
		l.light_specular = 0.3
		l.visible = false
		add_child(l)
		_lights.append(l)
		if i < shadows and _bounce_gain > 0.0:
			var bl := OmniLight3D.new()
			bl.name = "TorchBounce%d" % i
			bl.light_color = BOUNCE_LIGHT
			bl.omni_attenuation = BOUNCE_ATTEN
			bl.shadow_enabled = false
			bl.light_specular = 0.0
			bl.visible = false
			add_child(bl)
			_bounce.append(bl)

## Leaves the inside's layer out of every DirectionalLight3D (the sun and
## the moon), once they stand.
func _cut_sky() -> void:
	var lights: Array = get_tree().root.find_children("*","DirectionalLight3D",true,false)
	for l: DirectionalLight3D in lights:
		l.light_cull_mask &= ~UNDER_LAYER
		if _sun == null or l.light_energy > _sun.light_energy: _sun = l
	_sky_cut = not lights.is_empty()

## The hall stretches' own materials for the kit's (LandHalls `swap`): the
## stone and the growth with their sky fill dimmed, the stone weathered
## harder. `tone`: the ruin tone's name (LandArches TONES; "": the world's).
static func _dark_materials(tone_of := "") -> Dictionary:
	var kit: Dictionary = RuinKit.materials()
	var stone := (kit.stone as ShaderMaterial).duplicate() as ShaderMaterial
	stone.shader = TUNNEL_STONE
	# The land's ruin tone (LandArches TONES), lifted less by the same share
	# as STONE_LIFT is under the amber one.
	const Arches = preload("res://scripts/endless/land_arches.gd")
	var tone: Color = Arches.TONES.get(tone_of,Arches.tone_lift())
	var amber: Color = Arches.STONE_LIFT
	stone.set_shader_parameter("albedo",Color(tone.r*STONE_LIFT.r/amber.r,tone.g*STONE_LIFT.g/amber.g,tone.b*STONE_LIFT.b/amber.b))
	stone.set_shader_parameter("rim",0.0)
	stone.set_shader_parameter("dim_fill",STONE_DIM)
	# --kit-stone=smooth keeps the smooth stone here too.
	var weathered: Variant = stone.get_shader_parameter("stone_weather")
	if weathered != null and float(weathered) > 0.0:
		stone.set_shader_parameter("stone_weather",_knob("hall-weather",STONE_WEATHER))
		stone.set_shader_parameter("weather_crack",STONE_CRACK)
		stone.set_shader_parameter("weather_bump",_knob("hall-bump",STONE_BUMP))
	var growth := (kit.growth as ShaderMaterial).duplicate() as ShaderMaterial
	growth.set_shader_parameter("fill",1.25*GROWTH_DIM)
	growth.set_shader_parameter("rim",0.0)
	growth.set_shader_parameter("shelter_fill",4.5*GROWTH_DIM)
	return {kit.stone:stone,kit.growth:growth}

## Builds, on this thread, the streamed tunnels within PRIME_REACH of `at`
## (a task still running is left to finish; the rest stream) and the hall
## stretches' far detail now, and the near detail round `at`. Never waits
## on the task: its build reads meshes back from the renderer
## (`surface_get_arrays`, `get_faces`), which answers only when this thread
## runs, so a wait here never ends (the title's parking spot primed it). A
## tunnel the task builds too is dropped as stood already (`_stand_one`).
func prime(at: Vector3) -> void:
	if _streams():
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
		while not _done.is_empty(): _stand_one(at)
		for t: Tunnels.Site in field.tunnels_in(at.x-PRIME_REACH,at.z-PRIME_REACH,at.x+PRIME_REACH,at.z+PRIME_REACH):
			if not _built.has(t.name) and _gap(t.box,at) <= PRIME_REACH: _commit(_make(t,field))
		_streamed_at = Vector3.INF
		_stream(at)
	_stand_bodies(Time.get_ticks_usec(),true)
	halls.prime(at)

## Stands the colliders' pieces waiting, in the order the tunnels stood: one at
## least, then while the frame's BODY_BUDGET (from `began`) lasts, or all
## of them with `all`.
func _stand_bodies(began: int, all: bool) -> void:
	var first := true
	for b: Built in _built.values():
		while not b.bodies.is_empty():
			if not first and not all and (Time.get_ticks_usec()-began)/1000.0 > BODY_BUDGET: return
			first = false
			b.node.add_child(b.bodies.pop_back())

func step(at: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	_stream(at)
	_cut_sea()
	_hush_sea(at)
	_stand_bodies(t0,false)
	halls.step(at)
	_light_torches(at)
	_spill(at)
	_burn_fires(at)
	if clouds != null and "fog_hush" in clouds: clouds.fog_hush = under(at)
	stats["step_ms"] = (Time.get_ticks_usec()-t0)/1000.0

## How deep in a bore `p` is: 0 outside (or in a portal), 1 HUSH_IN m or
## more past either mouth, under the roof.
func under(p: Vector3) -> float:
	for t: Tunnels.Site in _sites:
		var b := Tunnels.bore_at(t,p.x,p.z)
		if is_nan(b.x): continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if p.y > (b.y if sh < 0 else float(t.shafts[sh].top)): continue
		var q := Tunnels.local(t,p.x,p.z)
		return smoothstep(0.0,HUSH_IN,minf(q.x,t.length-q.x))
	return 0.0

## Each mouth's and shaft's daylight in the sun's colour and strength (none
## at night, nor past DAY_REACH of its tunnel).
func _spill(at: Vector3) -> void:
	if _built.is_empty(): return
	if not _sky_cut: _cut_sky()
	var sun := _sun != null and is_instance_valid(_sun) and _sun.visible
	for b: Built in _built.values():
		var lit := sun and _gap(b.site.box,at) < DAY_REACH
		for beam in b.beams: beam.visible = lit
		for i in b.spills.size():
			var l := b.spills[i]
			l.visible = lit
			if not lit: continue
			l.light_color = _sun.light_color
			l.light_energy = b.spill_gain[i]*_sun.light_energy

## The braziers: burning, and their bowls' lights on, within FIRE_REACH of
## the eye only (out, their sparks and smoke stop).
func _burn_fires(at: Vector3) -> void:
	var n := 0
	for b: Built in _built.values():
		var on := false
		if _gap(b.site.box,at) < FIRE_REACH:
			for fire in b.fires:
				if fire.global_position.distance_to(at) < FIRE_REACH: on = true
		if on != b.burning:
			b.burning = on
			for fire in b.fires: fire.set("burn",1.0 if on else 0.0)
			for l in b.fire_lights: l.visible = on
		if b.burning: n += b.fires.size()
	stats.fires = n

## The pools: the TORCH_LIGHTS torches nearest `at` (biased POOL_AHEAD
## ahead of the eye) within LIGHT_REACH get a light, the farthest of them
## fading out, and the FLAME_POOL nearest burn as real flames. Only the
## tunnels whose box is within LIGHT_REACH are looked at.
func _light_torches(at: Vector3) -> void:
	if _lights.is_empty(): return
	if not _sky_cut: _cut_sky()
	var dt := get_process_delta_time()
	_time += dt
	var key := at
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.global_position.distance_squared_to(at) < 1.0:
		key = at-cam.global_basis.z*POOL_AHEAD
	var near: Array = []
	var reach2 := LIGHT_REACH*LIGHT_REACH
	var looked := 0
	for b: Built in _built.values():
		if _gap(b.site.box,key) > LIGHT_REACH: continue
		looked += b.lamps.size()
		for i in b.lamps.size():
			var d2 := key.distance_squared_to(b.lamps[i])
			if d2 < reach2: near.append(Vector3(d2,b.id,i))
	stats["ranked"] = looked
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var n := mini(near.size(),_lights.size())
	# The farthest lit one fades out as the next one in comes nearer.
	var last := LIGHT_REACH
	if near.size() > n: last = sqrt((near[n] as Vector3).x)
	for k in _lights.size():
		var l := _lights[k]
		if k >= n:
			l.visible = false
			continue
		var c := near[k] as Vector3
		var b: Built = _by_id[int(c.y)]
		var i := int(c.z)
		var d := sqrt(c.x)
		var fade := clampf((last-d)/LIGHT_FADE,0.0,1.0)
		var flick := 1.0+TORCH_FLICKER*(sin(_time*11.0+i*1.7)*0.6+sin(_time*23.0+i*3.1)*0.4)
		l.position = b.lamps[i]
		l.light_color = GLOW_LIGHT if b.site.sunk else TORCH_LIGHT
		l.omni_range = TORCH_RANGE*b.lamp_big[i]
		l.light_energy = _torch_energy*b.lamp_big[i]*fade*(GLOW_POWER if b.site.sunk else flick)
		l.visible = fade > 0.0
		if k < _bounce.size():
			# Its bounce, out in the bore.
			var bl := _bounce[k]
			var lp: Vector3 = b.lamps[i]
			var q := Tunnels.local(b.site,lp.x,lp.z)
			var mid: Vector2 = Tunnels.at_s(b.site,q.x)[0]
			var out := Vector2(lp.x,lp.z).lerp(mid,BOUNCE_OUT)
			bl.position = Vector3(out.x,lp.y-BOUNCE_DOWN,out.y)
			bl.omni_range = BOUNCE_RANGE*b.lamp_big[i]
			bl.light_energy = _bounce_gain*l.light_energy*lerpf(1.0,BOUNCE_CAVE,Tunnels.cave_ease(b.site,q.x))
			bl.visible = l.visible
	for k in range(n,_bounce.size()): _bounce[k].visible = false
	stats.lights = n
	# A sunk cave's glows are light on the rock: they never burn.
	var fires: Array = []
	for c: Vector3 in near:
		var built: Built = _by_id[int(c.y)]
		if not built.site.sunk: fires.append(c)
	_burn_flames(fires,dt)

## A ranked torch's key (id << 16 | i).
static func _key(c: Vector3) -> int:
	return (int(c.y) << 16) | int(c.z)

## The flame pool: the FLAME_POOL first of `near` (ranked torches) burn as
## real flames, easing in over FLAME_EASE while their cards fade out, and a
## flame whose torch left the pool eases out before it moves.
func _burn_flames(near: Array, dt: float) -> void:
	if _flames.is_empty(): return
	var want := {}
	for k in mini(near.size(),FLAME_POOL): want[_key(near[k])] = true
	var held := {}
	for j in _flames.size():
		if _flame_on[j] >= 0: held[_flame_on[j]] = j
	var rate := dt/FLAME_EASE
	var free: Array[int] = []
	for j in _flames.size():
		var i := _flame_on[j]
		if i < 0:
			free.append(j)
			continue
		var b := _flame_burn[j]
		b = minf(b+rate,1.0) if want.has(i) else maxf(b-rate,0.0)
		_flame_burn[j] = b
		if b <= 0.0:
			held.erase(i)
			_flame_on[j] = -1
			_card(i,1.0)
			_flames[j].set("burn",0.0)
			free.append(j)
			continue
		_flames[j].set("burn",b)
		_card(i,1.0-b)
	for k in mini(near.size(),FLAME_POOL):
		if free.is_empty(): break
		var c := near[k] as Vector3
		var i := _key(c)
		if held.has(i): continue
		var j: int = free.pop_back()
		_flame_on[j] = i
		_flame_burn[j] = 0.0
		var fl := _flames[j]
		var built: Built = _by_id[int(c.y)]
		fl.global_position = built.feet[int(c.z)]
		fl.scale = Vector3.ONE*built.feet_big[int(c.z)]*TORCH_FIRE
		held[i] = j
	var lit := 0
	for j in _flames.size(): if _flame_on[j] >= 0: lit += 1
	stats.flames = lit

## Torch `key`'s card (id << 16 | i) at `show` (1 whole, 0 hidden by its
## real flame).
func _card(key: int, show: float) -> void:
	var b: Built = _by_id.get(key >> 16)
	if b == null: return
	var i := key & 0xffff
	var c := b.tint[i]
	c.a = show
	b.cards.set_instance_color(i,c)

## Where the test tunnel's start stands (world y), NAN with none.
func start_y() -> float:
	for t: Tunnels.Site in _sites:
		if t.name.ends_with("/test"): return t.floor_y+TEST_ALT
	return NAN

# --- The solid ------------------------------------------------------------------------

## The cover over (x, z): the land `h`, or the portal's top on its
## footprint.
func _cover(t: Tunnels.Site, x: float, z: float, h: float) -> float:
	var m := Tunnels.portal_at(t,x,z)
	if m < 0: return h
	var q := Tunnels.portal_local(t,m,x,z)
	return maxf(h+PORTAL_OVER,_cap(t,m,q.x,q.y))

## Mouth `m`'s portal cap at `a` in, `d` across: CAP_OVER over the vault,
## broken by CAP_ROUGH, falling past CAP_FLAT.
static func _cap(t: Tunnels.Site, m: int, a: float, d: float) -> float:
	var rough := CAP_ROUGH*(t.rock.get_noise_2d(d*CAP_GRAIN,a*CAP_GRAIN+5000.0*(m+1))*0.5+0.5)
	return t.floor_y+Tunnels.HALL_VAULT+CAP_OVER+rough-CAP_FALL*maxf(absf(d)-CAP_FLAT,0.0)

## SkyGlide's `ground` at `p` over `h` (what the layers under answered), as
## LandHalls `ground`: in the tube under its roof, the hall stretch's solid
## standing on the bore's floor with the rock roof (roof to cover) over it
## (LandHalls `over`: the floor or a column's top, or Vector2(top,
## underside) for a roof the plane is nearer, which it slides under); in
## the rock round it, the cover (a wall).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if not h is float: return h
	var grow := _grow if pad < 0.0 else pad
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		# Up a shaft, under its top: open to the bore's floor.
		var sh := Tunnels.shaft_at(t,p.x,p.z,grow)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return t.floor_y
		var cover := _cover(t,p.x,p.z,h)
		var b := Tunnels.bore_at(t,p.x,p.z,grow)
		if not is_nan(b.x) and cover > b.y:
			if p.y >= b.y: return cover
			# An open nave's column rows are one smooth wall to the glide
			# (NAVE_CLEAR off the line, the wingtip's reach in), so it glances
			# along them; found in play, it slipped between two columns into
			# the aisle behind, where every way out was a column or the wall.
			if _open_nave and _in_nave(t,p): return cover
			var list: Array = halls.stretches(p,pad)
			list.append(Vector2(b.y,cover))
			return LandHalls.over(p,b.x,list)
		if cover > h: return cover
	return h

## SkyGlide's `guide` at `p` (heading, speed): in a bore under its roof, a
## soft guard that works before the solid does, so a hand that wanders
## off the middle is eased back, not stopped. Found in play: a brush on the
## rock stopped and turned the plane every frame it touched, so near a wall
## it felt pinned. The clear room across is the wall at the plane's height
## (an open nave's column rows in a hall stretch), the narrower of here and
## GUARD_LOOK s ahead, less the wingtip's reach; within GUARD_MARGIN m of it
## the push off it grows to GUARD_PUSH m/s and, pointing at it, the heading
## eases along the path. Within GUARD_ROOF m of the roof a climb levels
## and it is pushed down; within GUARD_FLOOR m of the floor a dive levels.
func guide(p: Vector3, heading: float, speed: float) -> Dictionary:
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var b := Tunnels.bore_at(t,p.x,p.z)
		if is_nan(b.x) or p.y >= b.y: continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y > b.y-GUARD_ROOF: continue
		var q := Tunnels.local(t,p.x,p.z)
		var h := p.y-b.x
		var got: Array = Tunnels.at_s(t,clampf(q.x,0.0,t.length))
		var tg: Vector2 = got[1]
		var across := Vector3(-tg.y,0.0,tg.x)
		var fwd := Vector2(-sin(heading),-cos(heading))
		var sense := 1.0 if fwd.dot(tg) >= 0.0 else -1.0
		# The room across: here and ahead the way it is going.
		var mid := 0.0
		var room := INF
		for ds: float in [0.0,sense*maxf(speed,10.0)*GUARD_LOOK]:
			var r := _room(t,q.x+ds,h)
			if r.y < room:
				room = r.y
				mid = r.x
		var off := q.y-mid
		var near := clampf((absf(off)-(room-GUARD_MARGIN))/GUARD_MARGIN,0.0,1.0)
		var push := -signf(off)*across*GUARD_PUSH*near*near
		var turn := 0.0
		var way := atan2(-tg.x*sense,-tg.y*sense)
		# Pointing at the near wall: the heading eases along.
		if near > 0.0 and Vector2(across.x,across.z).dot(fwd)*signf(off) > 0.0: turn = near
		var level := 0.0
		var top := b.y-b.x-SkyGlide.CLEAR
		var up := clampf((h-(top-GUARD_ROOF))/GUARD_ROOF,0.0,1.0)
		if up > 0.0:
			push.y -= GUARD_PUSH*up*up
			level = up
		var down := clampf((SkyGlide.SKIM+GUARD_FLOOR-h)/GUARD_FLOOR,0.0,1.0)
		if down > 0.0:
			push.y += GUARD_LIFT*down*down
			level = -down
		if near == 0.0 and level == 0.0: return {}
		return {"push":push,"heading":way,"turn":turn,"level":level}
	return {}

## True where `p` is past an open nave's clear room (Tunnels NAVE_CLEAR off
## its line), along a hall stretch and its end columns.
func _in_nave(t: Tunnels.Site, p: Vector3) -> bool:
	var q := Tunnels.local(t,p.x,p.z)
	if absf(q.y) <= Tunnels.NAVE_CLEAR: return false
	var reach := Hall.COLUMN_R+_grow
	for piece: Dictionary in t.pieces:
		if piece.kind == "hall" and q.x >= float(piece.s0)-reach and q.x <= float(piece.s1)+reach: return true
	return false

## SkyGlide's `keep`: `p` in a bore under its roof, past its clear room
## across (`_room`, the wall at its height or an open nave's column rows)
## or over its roof's (less CLEAR), put back on that edge, its way along
## kept; so pressed into a wall it slides along it, where the solid alone
## stopped it and turned it every frame (found in play: pinned).
func keep(p: Vector3) -> Vector3:
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var b := Tunnels.bore_at(t,p.x,p.z)
		if is_nan(b.x) or p.y >= b.y: continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0: return p
		var q := Tunnels.local(t,p.x,p.z)
		if q.x < 0.0 or q.x > t.length: return p
		var h := p.y-b.x
		var r := _room(t,q.x,h)
		var off := q.y-r.x
		var out := p
		if absf(off) > r.y-KEEP_IN:
			var tg: Vector2 = Tunnels.at_s(t,q.x)[1]
			var across := Vector3(-tg.y,0.0,tg.x)
			out -= across*signf(off)*(absf(off)-(r.y-KEEP_IN))
		var bg := Tunnels.bore_at(t,out.x,out.z,_grow)
		if not is_nan(bg.y) and out.y > bg.y-SkyGlide.CLEAR-KEEP_IN: out.y = bg.y-SkyGlide.CLEAR-KEEP_IN
		return out
	return p

## Vector2(the middle across, the clear half width from it) at `s` along
## `t`, `h` m over the floor: the carved wall at that height (the wingtip's
## reach off it); in an open nave's hall stretch, its column rows.
func _room(t: Tunnels.Site, s: float, h: float) -> Vector2:
	var pr := Tunnels.profile(t,s)
	var hw := (pr.x+pr.y)*0.5
	# The eye keeps CLEAR under the rock (SkyGlide `_skim`), so the wall
	# that counts is the rock's at CLEAR over it.
	var f := clampf((h+SkyGlide.CLEAR)/pr.z,0.0,0.999)
	var out := Vector2((pr.y-pr.x)*0.5,hw*pow(1.0-pow(f,pr.w),1.0/pr.w)-_grow)
	if _open_nave:
		var reach := Hall.COLUMN_R+_grow
		for piece: Dictionary in t.pieces:
			if piece.kind == "hall" and s >= float(piece.s0)-reach and s <= float(piece.s1)+reach:
				out = Vector2(0.0,minf(out.y,Tunnels.NAVE_CLEAR))
				break
	return out

## The solid's top under `p` over the land's `h`: the bore's floor in the
## tube under its roof, else the cover.
func land_y(p: Vector3, h: float) -> float:
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return t.floor_y
		var cover := _cover(t,p.x,p.z,h)
		var b := Tunnels.bore_at(t,p.x,p.z)
		if not is_nan(b.x) and cover > b.y and p.y < b.y: return b.x
		if cover != h: return cover
	return h

## True inside the rock round a bore or a portal's block (the camera keeps
## out, the wheels stop): under the tube's floor, over its roof under the
## cover, or in the walls beside it under the land.
func inside(p: Vector3) -> bool:
	if halls.inside(p): return true
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return p.y < t.floor_y
		var h: float = field.height(p.x,p.z)
		var cover := _cover(t,p.x,p.z,h)
		var b := Tunnels.bore_at(t,p.x,p.z)
		if not is_nan(b.x) and cover > b.y: return p.y < b.x or (p.y > b.y and p.y < cover)
		if p.y >= cover: continue
		if cover != h: return true
		# Beside the tube, in its walls (elsewhere the land's own height
		# answers).
		var q := Tunnels.local(t,p.x,p.z)
		if q.x >= -Tunnels.PORTAL_OUT and q.x <= t.length+Tunnels.PORTAL_OUT and absf(q.y) < Tunnels.section(t,q.x).x+WALL_NEAR: return true
	return false

## The chase camera's sight inside a bore (studies/endless_flight.gd
## `_sight`, GlideCamera `sight`): the share of the way from `from` to `to`
## clear of the rock and the hall stretches, marched every SIGHT_STEP m (the
## field's own march is too coarse for a stretch's columns and lintels, or
## a bend's inside corner, so the eye went through them). 1 where neither
## end is near a bore. `sight_whole` says whether the tube answered every
## point (nothing else can be in the way there, so the caller's own march
## can be skipped).
func sight(from: Vector3, to: Vector3) -> float:
	sight_whole = false
	if not near(from) and not near(to): return 1.0
	var n := maxi(1,ceili(from.distance_to(to)/SIGHT_STEP))
	var whole := true
	for i in range(1,n+1):
		var p := from.lerp(to,float(i)/n)
		var got := tube(p)
		if got < 0:
			whole = false
			if inside(p) or p.y < land_y(p,field.height(p.x,p.z)): got = 1
		if got == 1:
			sight_whole = whole
			return float(i-1)/n
	sight_whole = whole
	return 1.0

## True in a sunk tunnel's corridor, where the sea has no say.
func dry(p: Vector3) -> bool:
	for t: Tunnels.Site in _sites:
		if Tunnels.dry_at(t,p.x,p.z): return true
	return false

## The sunk tunnels stood near the eye, into the sea's cuts when they change.
func _cut_sea() -> void:
	if sea == null or _sites.size() == _cuts: return
	_cuts = _sites.size()
	var list: Array = []
	for t: Tunnels.Site in _sites: list.append_array(Tunnels.dry_cuts(t))
	list.resize(mini(list.size(),DRY_CUTS))
	var out := PackedVector4Array()
	for c: Vector4 in list: out.append(c)
	out.resize(DRY_CUTS)
	sea.set_shader_parameter("dry_cut",out)
	sea.set_shader_parameter("dry_cuts",list.size())
	sea.set_shader_parameter("dry_half",Tunnels.DRY_HALF)

## The sea is one level sheet, and a cave's chambers stand over it: with the eye
## above the level it lies across the bore like a flood. So with the eye low in
## a sunk tunnel's corridor, the sea goes wherever the land stands over it (the
## shader's `dry_under`). Only then: a map this coarse would nibble the shores.
func _hush_sea(at: Vector3) -> void:
	if sea == null: return
	var on := false
	for t: Tunnels.Site in _sites:
		if at.y < t.floor_y+SIGHT_UP and Tunnels.dry_at(t,at.x,at.z): on = true
	if on == _sea_hushed: return
	_sea_hushed = on
	sea.set_shader_parameter("dry_under",1.0 if on else 0.0)

## Whether `p` is in a tunnel's box, low enough to be in its bore.
func near(p: Vector3) -> bool:
	for t: Tunnels.Site in _sites:
		if t.box.has_point(Vector2(p.x,p.z)) and p.y < t.floor_y+SIGHT_UP: return true
	return false

## The quick answer in a bore's tube away from its portals (and up a
## shaft), where the land over it can't matter: 1 in the rock or a hall
## stretch, 0 open, -1 elsewhere (ask `inside` and `land_y`).
func tube(p: Vector3) -> int:
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)) or p.y > t.floor_y+SIGHT_UP: continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return 1 if p.y < t.floor_y else 0
		var b := Tunnels.bore_at(t,p.x,p.z)
		if is_nan(b.x) or Tunnels.portal_at(t,p.x,p.z) >= 0: return -1
		return 1 if p.y < b.x or p.y > b.y or halls.inside(p) else 0
	return -1

## One line for the numbers HUD.
func note() -> String:
	return "tunnels %d (built in %.0f ms worst, stood in %.1f ms worst, %d dropped), greybox %dk tris, %d torches (%d lit), %d stretches: %s" % [stats.tunnels,float(stats.get("build_ms",0.0)),float(stats.commit_ms),int(stats.dropped),stats.tris/1000,stats.torches,stats.lights,stats.stretches,halls.note()]

# --- The greybox ----------------------------------------------------------------------

func _build(b: Built, f: RefCounted) -> void:
	var t: Tunnels.Site = b.site
	var rock := _build_rock(t,b)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := 0
	var lip := _mouth_arrays(t,f) if t.sunk else {}
	if not t.sunk:
		for m in 2: tris += _build_portal(st,t,m,f)
	var mesh: ArrayMesh = rock.commit()
	if t.sunk:
		tris += int(lip.tris)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,lip.arrays,[],{},RockShape.format(lip.arrays))
	else: st.commit(mesh)
	# Seen: the rock on the inside's layer (torch lit), the portal blocks
	# in the day (sun, sky and haze); the collider is both.
	var mat := _basalt_material(t)
	var node := MeshInstance3D.new()
	node.name = t.name.replace("/","_")
	node.mesh = _surface(mesh,0,mat)
	node.layers = UNDER_LAYER
	b.node.add_child(node)
	var blocks := MeshInstance3D.new()
	blocks.name = node.name+"_portals"
	if t.sunk:
		var day := ArrayMesh.new()
		day.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,lip.arrays,[],{},RockShape.format(lip.arrays))
		day.surface_set_material(0,_ground if _ground != null else _portal_material(t))
		blocks.mesh = day
	else: blocks.mesh = _surface(mesh,1,_portal_material(t))
	b.node.add_child(blocks)
	if not t.sunk:
		for m in 2: _build_fires(b,m)
	if not t.sunk: b.node.add_child(_build_doors(t,node.name))
	tris += _build_shafts(b,mesh,node.name,mat)
	tris += _build_growth(b)
	# The collider in BODY_TRIS pieces (in the mesh's order, so each is a
	# run of the bore), stood one a frame (`_stand_bodies`): Jolt builds a
	# trimesh's tree as it enters the space, ~30 ms for a whole tunnel.
	var faces := mesh.get_faces()
	var per := BODY_TRIS*3
	var i0 := 0
	while i0 < faces.size():
		var body := StaticBody3D.new()
		body.name = "%s_body%d" % [node.name,b.bodies.size()]
		body.collision_layer = LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces.slice(i0,mini(i0+per,faces.size())))
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		b.bodies.append(body)
		i0 += per
	b.tris += tris

## Mouth `m`'s portal into `st`: the skin over its footprint (the land's
## top PORTAL_OVER over it, or the cap over the opening: `_cover`), sunk
## SKIRT into the land at its sides and back; the sheer front with the
## opening (filleted to the bore's rounded corners); the gate (jambs, a
## lintel, a pediment) and a fire bowl on each end of the lintel. Flat
## shaded, so it reads as cut stone. Returns its triangles.
func _build_portal(st: SurfaceTool, t: Tunnels.Site, m: int, lf: RefCounted) -> int:
	var tris := 0
	var a0 := -Tunnels.PORTAL_OUT
	var k := Tunnels.PORTAL_HALF
	var w := Tunnels.HALL_HALF
	var f := t.floor_y
	var vault := f+Tunnels.HALL_VAULT
	var as_: Array[float] = []
	var a := a0
	while a < Tunnels.PORTAL_IN-0.01:
		as_.append(a)
		a += SKIN_STEP
	as_.append(Tunnels.PORTAL_IN)
	var ds: Array[float] = [-w,w]
	var d := -k
	while d < k-0.01:
		if absf(absf(d)-w) > 0.5: ds.append(d)
		d += SKIN_STEP
	ds.append(k)
	ds.sort()
	# The skin's heights.
	var ys: Array = []
	for i in as_.size():
		var row := PackedFloat32Array()
		for j in ds.size():
			# A hair inside the footprint: on its very edge `portal_at` could
			# miss by rounding, and the front dropped to the trench's floor.
			var q := Tunnels.portal_point(t,m,clampf(as_[i],a0+0.05,Tunnels.PORTAL_IN-0.05),clampf(ds[j],-k+0.05,k-0.05))
			row.append(_cover(t,q.x,q.y,lf.height(q.x,q.y)))
		ys.append(row)
	var inward := _v(t,m,1.0,0.0,0.0)-_v(t,m,0.0,0.0,0.0)
	var across := _v(t,m,0.0,1.0,0.0)-_v(t,m,0.0,0.0,0.0)
	for i in as_.size()-1:
		for j in ds.size()-1:
			var p00 := _v(t,m,as_[i],ds[j],ys[i][j])
			var p10 := _v(t,m,as_[i+1],ds[j],ys[i+1][j])
			var p11 := _v(t,m,as_[i+1],ds[j+1],ys[i+1][j+1])
			var p01 := _v(t,m,as_[i],ds[j+1],ys[i][j+1])
			var nm := (p11-p00).cross(p01-p10)
			if nm.y < 0.0: nm = -nm
			nm = nm.normalized()
			tris += _quad(st,p00,p10,p11,p01,nm,FACE_TINT.lerp(SKIN_TINT,smoothstep(0.4,0.9,nm.y)))
	# Skirts into the land: the sides and the back.
	for side in 2:
		var j := 0 if side == 0 else ds.size()-1
		var dd := ds[j]
		for i in as_.size()-1:
			var y0: float = ys[i][j]
			var y1: float = ys[i+1][j]
			tris += _quad(st,_v(t,m,as_[i],dd,y0),_v(t,m,as_[i+1],dd,y1),_v(t,m,as_[i+1],dd,_land(t,m,as_[i+1],dd,lf)-SKIRT_FAR),_v(t,m,as_[i],dd,_land(t,m,as_[i],dd,lf)-SKIRT_FAR),across*signf(dd),FACE_TINT)
	var back := as_.size()-1
	var ab := as_[back]
	var sec := Tunnels.section(t,ab if m == 0 else t.length-ab)
	var bottoms := PackedFloat32Array()
	for j in ds.size():
		var land := _land(t,m,ab,ds[j],lf)
		var deep := land-SKIRT_FAR
		if absf(ds[j]) < sec.x+SKIN_STEP: deep = minf(maxf(deep,f+sec.y+SKIRT_TUBE),land-SKIRT)
		bottoms.append(deep)
	for j in ds.size()-1:
		tris += _quad(st,_v(t,m,ab,ds[j],ys[back][j]),_v(t,m,ab,ds[j+1],ys[back][j+1]),_v(t,m,ab,ds[j+1],bottoms[j+1]),_v(t,m,ab,ds[j],bottoms[j]),inward,FACE_TINT)
	# The sheer front, the opening cut out of it.
	var lo := f-Tunnels.SINK-SKIRT
	for j in ds.size()-1:
		var bot := vault if absf((ds[j]+ds[j+1])*0.5) < w else lo
		var tint := FACE_TINT.darkened(0.12*(t.rock.get_noise_2d(ds[j]*7.0,float(m)*300.0)*0.5+0.5))
		tris += _quad(st,_v(t,m,a0,ds[j],ys[0][j]),_v(t,m,a0,ds[j+1],ys[0][j+1]),_v(t,m,a0,ds[j+1],bot),_v(t,m,a0,ds[j],bot),-inward,tint)
	# The fillets between the square opening and the bore's rounded ring.
	var pr := Tunnels.profile(t,-1.0)
	for r in RING_SEGS:
		var q0 := Tunnels.profile_point(pr,PI*(1.0-float(r)/RING_SEGS))
		var q1 := Tunnels.profile_point(pr,PI*(1.0-float(r+1)/RING_SEGS))
		var c := _v(t,m,a0,signf(q0.x+q1.x)*w,vault)
		var v0 := _v(t,m,a0,q0.x,f+q0.y)
		var v1 := _v(t,m,a0,q1.x,f+q1.y)
		if (v1-v0).cross(c-v0).length() < 0.01: continue
		tris += _tri_flat(st,c,v0,v1,-inward,FACE_TINT)
	# The gate: jambs, a lintel, a pediment.
	var out := a0-FRAME_OUT
	for sg: float in [-1.0,1.0]:
		tris += _box(st,t,m,out,a0+0.3,sg*w,sg*(w+JAMB_W),f-Tunnels.SINK,vault,FRAME_TINT.darkened(0.05),false)
	var lw := w+JAMB_W+LINTEL_PAST
	tris += _box(st,t,m,out-0.6,a0+0.3,-lw,lw,vault,vault+LINTEL_H,FRAME_TINT,true)
	var base := vault+LINTEL_H
	var pw := w+JAMB_W
	var pa := out+0.4
	var apex_f := _v(t,m,pa,0.0,base+PED_H)
	var apex_b := _v(t,m,a0+0.3,0.0,base+PED_H)
	tris += _tri_flat(st,_v(t,m,pa,-pw,base),_v(t,m,pa,pw,base),apex_f,-inward,FRAME_TINT.lightened(0.04))
	for sg: float in [-1.0,1.0]:
		var e_f := _v(t,m,pa,sg*pw,base)
		var e_b := _v(t,m,a0+0.3,sg*pw,base)
		var slope := (apex_f-e_f).cross(inward)
		if slope.y < 0.0: slope = -slope
		tris += _quad(st,e_f,e_b,apex_b,apex_f,slope,FRAME_TINT.darkened(0.04))
	# A fire bowl on each end of the lintel.
	for sg: float in [-1.0,1.0]:
		var bd := sg*(lw-BOWL.x)
		tris += _box(st,t,m,out-0.6,out-0.6+2.0*BOWL.x,bd-BOWL.x,bd+BOWL.x,base,base+BOWL.y,Color(0.16,0.14,0.12),false)
	return tris

## A sunk cave's mouth rock, both mouths in one indexed mesh's arrays: at each
## mouth a shelf of the land's rock round the opening, its inner edge ragged
## just inside the bore's own ring and rolled out over it, its outer edge
## running back under the land past the hole the land leaves, so the land's
## own cliff meets it and no edge shows. Spokes out of the ring, smooth shaded, baked for the land's rock
## paint: it wears the ground material (`_ground`). Returns its triangles.
const LIP_SPOKES := 96
const LIP_RINGS := 30
## How far past the mouth's bowl the rock reaches across; up, it stops at the
## highest land along LIP_LAND (m in), LIP_OVER over it, then runs back to
## LIP_BACK m in, LIP_UNDER m under the land there.
const LIP_PAST := 8.0
const LIP_LAND := [7.0,10.0,13.0]
const LIP_OVER := 1.5
const LIP_UNDER := 3.0
## The inner edge: how far it stands out of the bore's end, how far it rolls
## out over the opening, how far it comes in from the ring (ragged).
const LIP_FRONT := 3.2
const LIP_ROLL := 2.6
const LIP_RAGGED := Vector2(0.3,2.0)
## The rings' share that make the face (the rest run back); how far the face
## curves back at its sides; how far the feet sink into the sinkhole's floor.
const LIP_BACK := 19.0
const LIP_FACE := 0.8
const LIP_CURVE := 7.0
const LIP_FOOT := 3.0
## The rock's own shape, m: big bulges and bedded ledges (out of the face),
## their sizes, and the wander across the face that hides the spokes.
const LIP_BULGE := 3.2
const LIP_BULGE_SIZE := 15.0
const LIP_LEDGE := 1.1
const LIP_LEDGE_SIZE := 4.5
const LIP_WANDER := 1.1
func _mouth_arrays(t: Tunnels.Site, lf: RefCounted) -> Dictionary:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var noise := FastNoiseLite.new()
	noise.seed = hash([t.seed,t.name,"mouth"]) & 0x7fffffff
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 1.0/LIP_BULGE_SIZE
	var pr := Tunnels.profile(t,-1.0)
	var half := Tunnels.BOWL_MOUTH+LIP_PAST
	var cols := ceili(half*2.0/2.0)
	var per := LIP_SPOKES+1
	for m in 2:
		var base := v.size()
		var tops := PackedFloat32Array()
		for j in cols+1:
			var top := -INF
			for along: float in LIP_LAND:
				var q := Tunnels.portal_point(t,m,along,-half+j*2.0)
				top = maxf(top,float(lf.height(q.x,q.y))+LIP_OVER)
			tops.append(top)
		var pts := PackedVector3Array()
		pts.resize(per*(LIP_RINGS+1))
		var lumps := PackedFloat32Array()
		lumps.resize(pts.size())
		for k in per:
			var th := PI*(1.0-float(k)/LIP_SPOKES)
			var q := Tunnels.profile_point(pr,th)
			var dir := Vector2(q.x,q.y*0.8).normalized()
			# Out along the spoke to the bowl's side or the land.
			var reach := 0.0
			while reach < 120.0:
				var at := q+dir*reach
				if absf(at.x) >= half: break
				var c := clampf((at.x+half)/2.0,0.0,float(cols)-0.001)
				var i0 := int(c)
				if t.floor_y+at.y >= lerpf(tops[i0],tops[i0+1],c-i0): break
				reach += 1.0
			var seam := Vector3(q.x*0.31,q.y*0.31,float(m)*77.0)
			var rag := clampf(noise.get_noise_3dv(seam)*1.4+0.5,0.0,1.0)
			var inner := -lerpf(LIP_RAGGED.x,LIP_RAGGED.y,rag)
			for i in LIP_RINGS+1:
				var u := float(i)/LIP_RINGS
				# The face up to the land, then the run back over the hole.
				var fu := minf(u/LIP_FACE,1.0)
				var over := maxf((u-LIP_FACE)/(1.0-LIP_FACE),0.0)
				var r := lerpf(inner,reach,fu)
				var off := q+dir*r
				var y := t.floor_y+off.y
				var w := Tunnels.portal_point(t,m,0.0,off.x)
				var lump := noise.get_noise_3d(w.x,y,w.y)
				var cross := noise.get_noise_3d(w.y+311.0,y*1.3,w.x-97.0)
				var bed := y/LIP_LEDGE_SIZE+lump*2.2
				var ledge := smoothstep(0.0,1.0,absf(fposmod(bed,1.0)-0.5)*2.0)-0.5
				var settle := smoothstep(0.0,0.25,fu)
				var a := -LIP_FRONT-LIP_ROLL*smoothstep(0.0,5.0,r-inner)
				# The face curves back into the land at its sides.
				a += LIP_CURVE*smoothstep(half*0.55,half,absf(off.x))
				a -= settle*(lump*LIP_BULGE+ledge*LIP_LEDGE)
				var along := off.x+cross*LIP_WANDER*settle
				var up := y+lump*LIP_WANDER*settle*0.7
				# The feet go under the sinkhole's floor.
				up -= LIP_FOOT*smoothstep(0.0,0.1,fu)*(1.0-smoothstep(0.0,5.0,off.y))
				if over > 0.0:
					a = lerpf(a,LIP_BACK,over)
					var far := Tunnels.portal_point(t,m,a,along)
					up = lerpf(up,float(lf.height(far.x,far.y))-LIP_UNDER,over*over*over)
				pts[k+i*per] = _v(t,m,a,along,up)
				lumps[k+i*per] = lump
		var out := _v(t,m,0.0,0.0,0.0)-_v(t,m,1.0,0.0,0.0)
		for i in LIP_RINGS+1:
			for k in per:
				var e := pts[k+i*per]
				var du := pts[mini(k+1,per-1)+i*per]-pts[maxi(k-1,0)+i*per]
				var dv := pts[k+mini(i+1,LIP_RINGS)*per]-pts[k+maxi(i-1,0)*per]
				var nm := du.cross(dv)
				if nm.dot(out) < 0.0: nm = -nm
				# The run back: no grass grows on it, so it shades as rock.
				var lean := smoothstep(LIP_FACE-0.08,LIP_FACE,float(i)/LIP_RINGS)
				nm = nm.normalized()+out.normalized()*1.6*lean
				v.append(e)
				nrm.append(nm.normalized())
				col.append(Color(0.56*0.94+0.1*lumps[k+i*per],0.45*0.94+0.08*lumps[k+i*per],0.33*0.94+0.06*lumps[k+i*per],0.0))
		for i in LIP_RINGS:
			for k in LIP_SPOKES:
				var p := base+k+i*per
				# Wound to face out (Godot's front faces are clockwise as seen).
				var flip := (pts[k+1+i*per]-pts[k+i*per]).cross(pts[k+(i+1)*per]-pts[k+i*per]).dot(out) > 0.0
				if flip: idx.append_array([p,p+per+1,p+1,p,p+per,p+per+1])
				else: idx.append_array([p,p+1,p+per+1,p,p+per+1,p+per])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	RockShape.bake(arrays)
	return {"arrays":arrays,"tris":idx.size()/3}

## The far doors (DOOR_FROM): a dark quad filling each gate's opening
## DOOR_IN m inside its front, facing out (so not seen from inside), drawn
## only past DOOR_FROM m; no light, the haze still on it.
func _build_doors(t: Tunnels.Site, base: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Tunnels.HALL_HALF
	var f := t.floor_y
	var a := -Tunnels.PORTAL_OUT+DOOR_IN
	for m in 2:
		var out := _v(t,m,0.0,0.0,0.0)-_v(t,m,1.0,0.0,0.0)
		_quad(st,_v(t,m,a,-w,f+Tunnels.HALL_VAULT),_v(t,m,a,w,f+Tunnels.HALL_VAULT),_v(t,m,a,w,f-Tunnels.SINK),_v(t,m,a,-w,f-Tunnels.SINK),out,DOOR_TINT)
	var door := MeshInstance3D.new()
	door.name = base+"_doors"
	door.mesh = st.commit()
	door.material_override = _door_material()
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	door.visibility_range_begin = DOOR_FROM
	return door

## The doors' material (made in setup, shared).
static func _door_material() -> StandardMaterial3D:
	if _door_mat != null: return _door_mat
	_door_mat = StandardMaterial3D.new()
	_door_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_door_mat.vertex_color_use_as_albedo = true
	_door_mat.albedo_color = Color.WHITE
	return _door_mat

## Mouth `m`'s fires: on the lintel's bowls, a glow and a light each; and
## its daylight in (`_spill`), lighting the inside's layer only.
func _build_fires(b: Built, m: int) -> void:
	var t: Tunnels.Site = b.site
	var f := t.floor_y
	var a0 := -Tunnels.PORTAL_OUT
	var top := f+Tunnels.HALL_VAULT+LINTEL_H+BOWL.y
	var lw := Tunnels.HALL_HALF+JAMB_W+LINTEL_PAST
	var out := _v(t,m,-1.0,0.0,0.0)-_v(t,m,0.0,0.0,0.0)
	for sg: float in [-1.0,1.0]:
		var at := _v(t,m,a0-FRAME_OUT-0.6+BOWL.x,sg*(lw-BOWL.x),top)
		var fire: Node3D = Flame.new()
		fire.name = "%s_fire%d%s" % [t.name.replace("/","_"),m,"l" if sg < 0.0 else "r"]
		fire.set("kind","brazier")
		fire.set("scale_by",FIRE_SCALE)
		fire.set("with_light",false)
		# Out until the eye comes near (`_burn_fires`).
		fire.set("burn",0.0)
		fire.position = at
		b.node.add_child(fire)
		b.fires.append(fire)
		var l := OmniLight3D.new()
		l.name = fire.name+"_light"
		l.light_color = TORCH_LIGHT
		l.omni_range = FIRE_RANGE
		l.omni_attenuation = TORCH_ATTEN
		l.light_energy = FIRE_ENERGY
		l.shadow_enabled = false
		l.position = at+Vector3.UP*(FIRE_R*2.4)+out*1.5
		l.visible = false
		b.node.add_child(l)
		b.fire_lights.append(l)
	var spot := SpotLight3D.new()
	spot.name = "%s_spill%d" % [t.name.replace("/","_"),m]
	var from := _v(t,m,a0+SPILL_IN,0.0,f+SPILL_Y)
	spot.transform = Transform3D(Basis.looking_at(_v(t,m,SPILL_AIM,0.0,f)-from,Vector3.UP),from)
	spot.spot_range = SPILL_RANGE
	spot.spot_angle = SPILL_ANGLE
	spot.spot_attenuation = SPILL_ATTEN
	spot.light_cull_mask = UNDER_LAYER
	spot.shadow_enabled = false
	spot.light_specular = 0.2
	spot.visible = false
	b.node.add_child(spot)
	b.spills.append(spot)
	b.spill_gain.append(SPILL_ENERGY)

## The land's height at mouth `m`'s (a, d).
static func _land(t: Tunnels.Site, m: int, a: float, d: float, f: RefCounted) -> float:
	var q := Tunnels.portal_point(t,m,a,d)
	return f.height(q.x,q.y)

## A box in mouth `m`'s frame (a along the way in, d across, y world),
## without its back (into the portal's face) and, unless `bottom`, its
## underside.
static func _box(st: SurfaceTool, t: Tunnels.Site, m: int, a0: float, a1: float, d0: float, d1: float, y0: float, y1: float, tint: Color, bottom: bool) -> int:
	var inward := _v(t,m,1.0,0.0,0.0)-_v(t,m,0.0,0.0,0.0)
	var across := _v(t,m,0.0,1.0,0.0)-_v(t,m,0.0,0.0,0.0)
	var dl := minf(d0,d1)
	var dh := maxf(d0,d1)
	var n := 0
	n += _quad(st,_v(t,m,a0,dl,y0),_v(t,m,a0,dh,y0),_v(t,m,a0,dh,y1),_v(t,m,a0,dl,y1),-inward,tint)
	n += _quad(st,_v(t,m,a0,dl,y1),_v(t,m,a0,dh,y1),_v(t,m,a1,dh,y1),_v(t,m,a1,dl,y1),Vector3.UP,tint.lightened(0.05))
	n += _quad(st,_v(t,m,a0,dl,y0),_v(t,m,a1,dl,y0),_v(t,m,a1,dl,y1),_v(t,m,a0,dl,y1),-across,tint.darkened(0.08))
	n += _quad(st,_v(t,m,a0,dh,y0),_v(t,m,a1,dh,y0),_v(t,m,a1,dh,y1),_v(t,m,a0,dh,y1),across,tint.darkened(0.08))
	if bottom: n += _quad(st,_v(t,m,a0,dl,y0),_v(t,m,a0,dh,y0),_v(t,m,a1,dh,y0),_v(t,m,a1,dl,y0),Vector3.DOWN,tint.darkened(0.15))
	return n

## One flat triangle facing `normal`.
static func _tri_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, tint: Color) -> int:
	var nm := normal.normalized()
	var order := [a,b,c]
	if (b-a).cross(c-a).dot(nm) > 0.0: order = [a,c,b]
	for v: Vector3 in order:
		st.set_normal(nm)
		st.set_color(tint)
		st.add_vertex(v)
	return 1

## The portals' material: the rock's texture in the day (sun, sky, haze).
static func _portal_material(t: Tunnels.Site) -> StandardMaterial3D:
	if t.sunk:
		# A sunk cave's mouth is the land's own rock: its colour, faceted, no cut stone.
		var raw := StandardMaterial3D.new()
		raw.vertex_color_use_as_albedo = true
		raw.roughness = 0.95
		raw.cull_mode = BaseMaterial3D.CULL_DISABLED
		return raw
	var mat := _rock_material(t,PORTAL_TEX_LOW)
	mat.disable_ambient_light = false
	mat.disable_fog = false
	mat.roughness = 0.95
	return mat

## Surface `i` of `mesh` as a mesh of its own, wearing `mat`.
static func _surface(mesh: ArrayMesh, i: int, mat: Material) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(i))
	out.surface_set_material(0,mat)
	return out

## The rock's material: its vertex colours under a noise worn
## triplanar in world space (grain and relief), lit by the torches alone.
static func _rock_material(t: Tunnels.Site, low := ROCK_TEX_LOW) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = hash([t.seed,"rock_tex"]) & 0x7fffffff
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.006
	var fine := FastNoiseLite.new()
	fine.seed = noise.seed+1
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.fractal_type = FastNoiseLite.FRACTAL_FBM
	fine.fractal_octaves = 6
	fine.frequency = 0.012
	var grad := Gradient.new()
	grad.set_color(0,Color(low,low*0.97,low*0.93))
	grad.set_color(1,Color(1.0,0.98,0.95))
	var albedo := NoiseTexture2D.new()
	albedo.width = 512
	albedo.height = 512
	albedo.seamless = true
	albedo.noise = noise
	albedo.color_ramp = grad
	var bump := NoiseTexture2D.new()
	bump.width = 512
	bump.height = 512
	bump.seamless = true
	bump.noise = fine
	bump.as_normal_map = true
	bump.bump_strength = ROCK_BUMP
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = albedo
	mat.normal_enabled = true
	mat.normal_texture = bump
	mat.normal_scale = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3.ONE/ROCK_TILE
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# No sky fill and no haze inside: the torches alone.
	mat.disable_ambient_light = true
	mat.disable_fog = true
	return mat

## The bore's carved rock: columnar basalt (shaders/tunnel_basalt.gdshader),
## its growth by the vertex green (`_green`), lit by the torches alone.
static func _basalt_material(t: Tunnels.Site) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CAVE_ROCK if t.sunk else BASALT
	mat.set_shader_parameter("floor_y",t.floor_y)
	return mat

## The carved rock of the bore (Tunnels.profile: superellipse rings from
## the -d wall's foot over the crown to the +d wall's foot, RING_SEGS
## segments, every CAVE_RING m in the caverns and every STEP m in the
## hall stretches and the portals), lumped outward into the rock
## (ROCK_LUMP; none in the portals, so the opening stays true) and a flat
## floor of FLOOR_SEGS strips between the walls' feet. Indexed, its normals
## smoothed, so the lumps shade.
func _build_rock(t: Tunnels.Site, b: Built) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ends := 3.0 if t.sunk else Tunnels.PORTAL_OUT
	var ss := PackedFloat32Array([-ends,0.0])
	for i in t.ss.size():
		var s: float = t.ss[i]
		if s <= 0.0 or s >= t.length: continue
		var prev: float = ss[ss.size()-1]
		var sub := ceili((s-prev)/CAVE_RING) if Tunnels.cave_ease(t,(s+prev)*0.5) > 0.0 else 1
		for k in range(1,sub): ss.append(lerpf(prev,s,float(k)/sub))
		ss.append(s)
	ss.append_array([t.length,t.length+ends])
	# The lumps: ridged noise, so the rock reads broken rather than poured.
	var grain := FastNoiseLite.new()
	grain.seed = hash([t.seed,"grain"]) & 0x7fffffff
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	grain.fractal_octaves = 3
	grain.frequency = 1.0/Tunnels.ROCK_GRAIN
	var pos := PackedVector3Array()
	var inward := PackedVector3Array()
	var per := RING_SEGS+1+FLOOR_SEGS+1
	var tris := 0
	for r in ss.size():
		var s: float = ss[r]
		var at: Array = Tunnels.at_s(t,s)
		var c: Vector2 = at[0]
		var tg: Vector2 = at[1]
		var n := Vector2(-tg.y,tg.x)
		var n3 := Vector3(n.x,0.0,n.y)
		var pr := Tunnels.profile(t,s)
		var e := Tunnels.cave_ease(t,s)
		var lump := 0.0 if s <= 0.0 or s >= t.length else ROCK_LUMP*(0.45+0.55*e)
		if t.sunk: lump *= CAVE_LUMP*smoothstep(0.0,Tunnels.CAVE_CALM,minf(s,t.length-s))
		var fy := Tunnels.floor_at(t,s)
		var hw := (pr.x+pr.y)*0.5
		var feet: Array = []
		for k in RING_SEGS+1:
			var th := PI*(1.0-float(k)/RING_SEGS)
			var q := Tunnels.profile_point(pr,th)
			var x := (q.x-(pr.y-pr.x)*0.5)/hw
			var y := q.y/pr.z
			# Out of the rock's surface (the superellipse's gradient).
			var g := Vector2(signf(x)*pow(absf(x),pr.w-1.0)/hw,pow(y,pr.w-1.0)/pr.z).normalized()
			var base := Vector3(c.x,fy,c.y)+n3*q.x+Vector3.UP*q.y
			var nz := clampf(grain.get_noise_3dv(base)*0.5+0.5,0.0,1.0)
			var out := n3*g.x+Vector3.UP*g.y
			# None round a shaft's lip, so its skirt meets the rock's face.
			var calm := 1.0
			for sh: Dictionary in t.shafts: calm = minf(calm,smoothstep(LIP_R+0.5,LIP_R+4.0,Vector2(base.x,base.z).distance_to(sh.at)))
			var v := base+out*lump*nz*calm
			if k == 0 or k == RING_SEGS: feet.append(v)
			pos.append(v)
			inward.append(-out)
			st.set_color(Color(1.0-0.6*nz,_green(t,s,v),e))
			st.add_vertex(v)
		for k in FLOOR_SEGS+1:
			var v: Vector3 = (feet[0] as Vector3).lerp(feet[1],float(k)/FLOOR_SEGS)
			var nz := t.rock.get_noise_2d(v.x*3.0,v.z*3.0)*0.5+0.5
			# A cave's floor falls away from the plane's level into the rock.
			if t.sunk and k > 0 and k < FLOOR_SEGS: v.y -= lump*nz
			pos.append(v)
			inward.append(Vector3.UP)
			st.set_color(Color(0.6+0.4*nz,_green(t,s,v),e))
			st.add_vertex(v)
		if r == 0: continue
		var b0 := (r-1)*per
		var b1 := r*per
		var near_shaft := false
		for sh: Dictionary in t.shafts: near_shaft = near_shaft or absf(s-float(sh.s)) < SHAFT_CUT+CAVE_RING*2.0
		for k in RING_SEGS:
			for tri: Array in [[b0+k,b0+k+1,b1+k+1],[b0+k,b1+k+1,b1+k]]:
				if near_shaft and _opened(t,pos,tri): continue
				tris += _tri(st,pos,inward,tri[0],tri[1],tri[2])
		var f := RING_SEGS+1
		for k in FLOOR_SEGS:
			tris += _tri(st,pos,inward,b0+f+k,b0+f+k+1,b1+f+k+1)+_tri(st,pos,inward,b0+f+k,b1+f+k+1,b1+f+k)
	if not t.sunk: tris += _build_columns(t,st,pos,inward)
	st.generate_normals()
	b.tris += tris
	return st

## The overgrowth's materials (main thread, once): the hanging strands'
## (HangingRoots' strand and sway, torch lit, bark or vine green) and the
## ferns' (UndergrowthMesh's fern, torch lit, a little light through).
static var _root_mat: ShaderMaterial
static var _vine_mat: ShaderMaterial
static var _fern_mat: ShaderMaterial
static var _card_mat: ShaderMaterial
static var _card_mesh: QuadMesh

static func _growth_materials() -> void:
	if _fern_mat != null: return
	HangingRoots.warm()
	UndergrowthMesh.fern()
	_root_mat = ShaderMaterial.new()
	_root_mat.shader = STRANDS
	_root_mat.set_shader_parameter("tint",ROOT_BARK)
	_vine_mat = ShaderMaterial.new()
	_vine_mat.shader = STRANDS
	_vine_mat.set_shader_parameter("tint",VINE_GREEN)
	_fern_mat = ShaderMaterial.new()
	_fern_mat.shader = FERN_LOOK
	_fern_mat.set_shader_parameter("tint",FERN_GREEN)
	_card_mat = ShaderMaterial.new()
	_card_mat.shader = VINES
	_card_mesh = QuadMesh.new()

## Tunnel `b`'s overgrowth, in GROWTH_CHUNK m chunks along it, each drawn
## within GROWTH_FAR m (on the inside's layer, torch lit): strands from the
## vault (roots and vines), curtains of vines down the caverns' walls,
## vines off the hall stretches' architraves, ferns at the walls' feet and
## out of the rock. All the thicker where the rock is green (`_green`).
## Drawn only, never collided. Returns the triangles.
func _build_growth(b: Built) -> int:
	var t: Tunnels.Site = b.site
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"growth"])
	var halls: Array = []
	for piece: Dictionary in t.pieces:
		if piece.kind == "hall": halls.append(Vector2(float(piece.s0),float(piece.s1)))
	var chunks := ceili(t.length/GROWTH_CHUNK)
	var tris := 0
	for ci in chunks:
		var roots: Array = []
		var vines: Array = []
		var ferns: Array[Transform3D] = []
		var cards: Array[Transform3D] = []
		var sa := ci*GROWTH_CHUNK
		var sb := minf(sa+GROWTH_CHUNK,t.length)
		var s := sa+rng.randf()*VINE_STEP
		while s < sb:
			var got: Array = Tunnels.at_s(t,s)
			var c: Vector2 = got[0]
			var tg: Vector2 = got[1]
			var n := Vector2(-tg.y,tg.x)
			var pr := Tunnels.profile(t,s)
			var hw := (pr.x+pr.y)*0.5
			var mid := (pr.y-pr.x)*0.5
			var in_hall := false
			for h: Vector2 in halls: in_hall = in_hall or (s >= h.x and s <= h.y)
			var g := _green(t,s,Vector3(c.x,0.0,c.y))
			# From the vault: roots by the crown, vines towards the walls.
			for k in int(round(g*VINE_VAULT+rng.randf()*0.8)):
				var x := rng.randf_range(-0.9,0.9)
				var d := mid+x*hw
				var roof := Tunnels.roof_over(pr,d)
				if is_nan(roof): continue
				var at := c+n*d+tg*rng.randf_range(-1.0,1.0)
				var long := lerpf(VINE_LONG.x,VINE_LONG.y,absf(x))*rng.randf_range(0.4,1.0)*(0.6+0.6*g)
				(vines if rng.randf() < 0.35+0.6*g else roots).append(Vector4(at.x,Tunnels.floor_xz(t,at.x,at.y)+roof+0.8,at.y,long+0.8))
				if g > TUFT_GREEN and rng.randf() < g*0.5:
					var face := Vector3(tg.x,0.0,tg.y).rotated(Vector3.UP,rng.randf_range(-1.2,1.2))
					cards.append(_leaf_card(Vector3(at.x,Tunnels.floor_xz(t,at.x,at.y)+roof+0.6,at.y),face,rng.randf_range(CARD_WIDE.x,CARD_WIDE.y),long*rng.randf_range(0.4,0.8)+0.6))
			if in_hall:
				# Off the architraves along the column rows.
				if rng.randf() < 0.3+0.6*g:
					for side: float in [-1.0,1.0]:
						if rng.randf() < 0.5: continue
						for k in rng.randi_range(2,5):
							var at := c+n*side*(Hall.ROW_Z+rng.randf_range(-0.7,0.7))+tg*rng.randf_range(-1.5,1.5)
							vines.append(Vector4(at.x,Tunnels.floor_xz(t,at.x,at.y)+Hall.COLUMN_H+Hall.BEAM.x*0.5,at.y,rng.randf_range(1.5,7.0)))
						for k in rng.randi_range(1,3):
							var at := c+n*side*(Hall.ROW_Z-Hall.BEAM.y-0.05)+tg*rng.randf_range(-4.0,4.0)
							cards.append(_leaf_card(Vector3(at.x,Tunnels.floor_xz(t,at.x,at.y)+Hall.COLUMN_H+0.6,at.y),Vector3(n.x,0.0,n.y)*-side,rng.randf_range(CARD_WIDE.x,CARD_WIDE.y),rng.randf_range(2.0,6.5)))
			elif g > CURTAIN_GREEN and rng.randf() < 0.45:
				# A curtain down the cavern's wall.
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var top := rng.randf_range(0.45,0.7)*pr.z
				var wx := hw*pow(1.0-pow(top/pr.z,pr.w),1.0/pr.w)
				for k in int(CURTAIN*rng.randf_range(0.5,1.0)):
					var along := (k-CURTAIN*0.5)*0.45+rng.randf_range(-0.15,0.15)
					var at := c+tg*along+n*(mid+side*(wx-0.35))
					vines.append(Vector4(at.x,Tunnels.floor_xz(t,at.x,at.y)+top+0.5,at.y,top*rng.randf_range(0.55,0.97)))
				var into := Vector3(n.x,0.0,n.y)*-side
				var run := -CURTAIN*0.25
				while run < CURTAIN*0.25:
					var wide := rng.randf_range(CARD_WIDE.x,CARD_WIDE.y)
					var at := c+tg*(run+wide*0.5)+n*(mid+side*(wx-0.45))
					cards.append(_leaf_card(Vector3(at.x,Tunnels.floor_xz(t,at.x,at.y)+top+0.3,at.y),into,wide,top*rng.randf_range(0.45,0.9)))
					run += wide*0.8
			s += VINE_STEP*rng.randf_range(0.6,1.4)
		# The ferns.
		s = sa+rng.randf()*FERN_STEP
		while s < sb:
			var got: Array = Tunnels.at_s(t,s)
			var c: Vector2 = got[0]
			var tg: Vector2 = got[1]
			var n := Vector2(-tg.y,tg.x)
			var pr := Tunnels.profile(t,s)
			var hw := (pr.x+pr.y)*0.5
			var mid := (pr.y-pr.x)*0.5
			var in_hall := false
			for h: Vector2 in halls: in_hall = in_hall or (s >= h.x and s <= h.y)
			var g := _green(t,s,Vector3(c.x,0.0,c.y))
			for k in int(round(g*FERN+rng.randf()*0.7)):
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var size := rng.randf_range(FERN_SIZE.x,FERN_SIZE.y)
				var up := Vector3.UP
				var at := Vector3.ZERO
				if in_hall:
					# At the hall walls' feet or round a column's foot.
					var d := side*(Tunnels.HALL_INNER-0.7) if rng.randf() < 0.6 else side*(Hall.ROW_Z+rng.randf_range(-2.2,2.2))
					var p := c+n*d+tg*rng.randf_range(-1.0,1.0)
					at = Vector3(p.x,Tunnels.floor_xz(t,p.x,p.y)+0.1,p.y)
				elif rng.randf() < 0.55:
					# At the wall's foot, among the columns' steps.
					var p := c+n*(mid+side*(hw-rng.randf_range(0.6,4.5)))+tg*rng.randf_range(-1.0,1.0)
					at = Vector3(p.x,Tunnels.floor_xz(t,p.x,p.y)+0.05,p.y)
				else:
					# Out of the rock, up the wall.
					var hgt := rng.randf_range(2.0,0.75*pr.z)
					var wx := hw*pow(1.0-pow(hgt/pr.z,pr.w),1.0/pr.w)
					var p := c+n*(mid+side*(wx-0.2))+tg*rng.randf_range(-1.0,1.0)
					at = Vector3(p.x,Tunnels.floor_xz(t,p.x,p.y)+hgt,p.y)
					var into := Vector3(n.x,0.0,n.y)*-side
					up = (into*0.8+Vector3.UP*0.6).normalized()
					size *= 0.75
				var yaw := Basis(Vector3.UP,rng.randf()*TAU)
				var turn := Basis.IDENTITY
				var axis := Vector3.UP.cross(up)
				if axis.length() > 0.001: turn = Basis(axis.normalized(),Vector3.UP.angle_to(up))
				ferns.append(Transform3D((turn*yaw).scaled(Vector3.ONE*size),at))
			s += FERN_STEP*rng.randf_range(0.6,1.4)
		var base := "%s_growth%d" % [b.node.name,ci]
		for pair: Array in [[roots,_root_mat,"roots"],[vines,_vine_mat,"vines"]]:
			var list: Array = pair[0]
			if list.is_empty(): continue
			var mi := HangingRoots.batch(list,hash([t.seed,ci,pair[2]]))
			mi.name = "%s_%s" % [base,pair[2]]
			mi.material_override = pair[1]
			_far_draw(mi,list)
			b.node.add_child(mi)
			tris += list.size()*HangingRoots.triangles()
		if not cards.is_empty():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = _card_mesh
			mm.instance_count = cards.size()
			var spots: Array = []
			for i in cards.size():
				mm.set_instance_transform(i,cards[i])
				mm.set_instance_custom_data(i,Color(rng.randf(),0.0,0.0,0.0))
				spots.append(Vector4(cards[i].origin.x,cards[i].origin.y,cards[i].origin.z,0.0))
			var mi := MultiMeshInstance3D.new()
			mi.name = base+"_curtains"
			mi.multimesh = mm
			mi.material_override = _card_mat
			_far_draw(mi,spots)
			b.node.add_child(mi)
			tris += cards.size()*2
		if not ferns.is_empty():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = UndergrowthMesh.fern()
			mm.instance_count = ferns.size()
			var spots: Array = []
			for i in ferns.size():
				mm.set_instance_transform(i,ferns[i])
				mm.set_instance_color(i,Color.WHITE*rng.randf_range(0.75,1.15))
				mm.set_instance_custom_data(i,Color(rng.randf(),0.0,0.0,0.0))
				spots.append(Vector4(ferns[i].origin.x,ferns[i].origin.y,ferns[i].origin.z,0.0))
			var mi := MultiMeshInstance3D.new()
			mi.name = base+"_ferns"
			mi.multimesh = mm
			mi.material_override = _fern_mat
			_far_draw(mi,spots)
			b.node.add_child(mi)
			tris += ferns.size()*_fern_tris()
	return tris

## A leafy curtain card (a unit QuadMesh) hung from `top`, facing `face`
## (flat), `wide` m across and `long` m down.
static func _leaf_card(top: Vector3, face: Vector3, wide: float, long: float) -> Transform3D:
	var z := face.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x*wide,Vector3.UP*long,z),top-Vector3.UP*long*0.5)

## A growth chunk drawn on the inside's layer, no shadows, out past
## GROWTH_FAR m from the middle of its spots (Vector4: x, y, z).
static func _far_draw(mi: GeometryInstance3D, spots: Array) -> void:
	mi.layers = UNDER_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for v: Vector4 in spots:
		lo = lo.min(Vector3(v.x,v.y,v.z))
		hi = hi.max(Vector3(v.x,v.y,v.z))
	mi.visibility_range_end = GROWTH_FAR+(hi-lo).length()*0.5
	mi.visibility_range_end_margin = 20.0

static var _fern_n := -1

## The fern mesh's triangles.
static func _fern_tris() -> int:
	if _fern_n < 0:
		var m: ArrayMesh = UndergrowthMesh.fern()
		_fern_n = 0
		for i in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(i)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			_fern_n += (idx as PackedInt32Array).size()/3 if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
	return _fern_n

## How much growth the rock at `v` (`s` along) takes (0..1, the basalt's
## vertex green): GREEN_BASE everywhere, more in patches along the path,
## full by the mouths (GREEN_MOUTH m in) and under a shaft (GREEN_SHAFT m
## round), where the daylight reaches.
static func _green(t: Tunnels.Site, s: float, v: Vector3) -> float:
	var g := GREEN_BASE+GREEN_PATCH*smoothstep(0.1,0.6,t.rock.get_noise_2d(s*0.6,9000.0))
	g = maxf(g,1.0-smoothstep(0.0,GREEN_MOUTH,minf(s,t.length-s)))
	for sh: Dictionary in t.shafts: g = maxf(g,1.0-smoothstep(GREEN_SHAFT*0.3,GREEN_SHAFT,Vector2(v.x,v.z).distance_to(sh.at)))
	return clampf(g,0.0,1.0)

## The basalt columns along the caverns' walls (into the rock's mesh, so
## the walker's collider has them too): hexagonal prisms on a lattice along
## each wall's foot, COLUMN_ROWS rows out from it, stepped down as they
## come out (a causeway at the wall's foot), the first row never over
## COLUMN_UNDER_TORCH by a torch (the vault shows the columns' ends in
## the basalt's own pattern). The flight's solid is the bore's own, so the
## rows stand within the wingtip's reach of the wall but for the low steps.
## Their alpha 0 tells the basalt they are columns of their own (no
## lattice drawn over them). Returns the triangles.
func _build_columns(t: Tunnels.Site, st: SurfaceTool, pos: PackedVector3Array, inward: PackedVector3Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.seed,"columns"])
	var torches: Array = Tunnels.torch_spots(t)
	var tris := 0
	for piece: Dictionary in t.pieces:
		if piece.kind != "cave": continue
		var s0 := float(piece.s0)+COLUMN_CELL
		var s1 := float(piece.s1)-COLUMN_CELL
		for side: float in [-1.0,1.0]:
			var s := s0+rng.randf()*COLUMN_CELL
			var k := 0
			while s < s1:
				var got: Array = Tunnels.at_s(t,s)
				var c: Vector2 = got[0]
				var tg: Vector2 = got[1]
				var n := Vector2(-tg.y,tg.x)
				var pr := Tunnels.profile(t,s)
				var foot := (pr.y-pr.x)*0.5+side*(pr.x+pr.y)*0.5
				var swell := t.rock.get_noise_2d(s*0.05,side*700.0)*0.5+0.5
				var by_torch := false
				for tc: Dictionary in torches:
					if float(tc.side) == side and absf(float(tc.s)-s) < COLUMN_CELL*2.0: by_torch = true
				for row in COLUMN_ROWS:
					var r := COLUMN_CELL*0.5*rng.randf_range(0.85,1.0)
					var inset := COLUMN_CELL*0.35+row*COLUMN_CELL*0.87
					var stagger := COLUMN_CELL*0.5 if (row+k)%2 == 1 else 0.0
					var at := c+tg*stagger+n*(foot-side*inset)
					var h := 0.0
					if row == 0: h = lerpf(COLUMN_TALL.x,COLUMN_TALL.y,swell)*rng.randf_range(0.7,1.0)
					elif row == 1: h = lerpf(0.3,COLUMN_STEP,swell)*rng.randf_range(0.5,1.0) if rng.randf() < 0.3+0.6*swell else 0.0
					else: h = rng.randf_range(0.15,0.55) if rng.randf() < 0.45*swell else 0.0
					if row == 0 and by_torch: h = minf(h,COLUMN_UNDER_TORCH)
					if h <= 0.05: continue
					tris += _prism(st,pos,inward,Vector3(at.x,t.floor_y-0.6,at.y),Vector3(at.x,t.floor_y+h,at.y),r,rng,Color(rng.randf(),_green(t,s,Vector3(at.x,0.0,at.y)),1.0,0.0))
				s += COLUMN_CELL
				k += 1
	return tris

## A hexagonal prism from `a` (its back end, in the rock) to `b` (its face:
## a top or a hanging end), radius `r`, its corners jittered, its face a
## little tilted; flat shaded (its own corners), wound to face out,
## coloured `tint` (the basalt's tone and growth).
static func _prism(st: SurfaceTool, pos: PackedVector3Array, inward: PackedVector3Array, a: Vector3, b: Vector3, r: float, rng: RandomNumberGenerator, tint: Color) -> int:
	var axis := signf(b.y-a.y)
	var spin := rng.randf()*TAU
	var ring: Array[Vector2] = []
	for i in 6:
		var ang := spin+TAU*i/6.0+rng.randf_range(-0.12,0.12)
		ring.append(Vector2(cos(ang),sin(ang))*r*rng.randf_range(0.88,1.06))
	var tilt := Vector2(rng.randf_range(-0.08,0.08),rng.randf_range(-0.08,0.08))
	var tris := 0
	for i in 6:
		var p0 := ring[i]
		var p1 := ring[(i+1)%6]
		var out := Vector3((p0.x+p1.x)*0.5,0.0,(p0.y+p1.y)*0.5).normalized()
		tris += _faces_out(st,pos,inward,[Vector3(a.x+p0.x,a.y,a.z+p0.y),Vector3(a.x+p1.x,a.y,a.z+p1.y),
			Vector3(b.x+p1.x,b.y+tilt.dot(p1),b.z+p1.y),Vector3(b.x+p0.x,b.y+tilt.dot(p0),b.z+p0.y)],out,tint)
	# The face: a fan round its middle.
	var face_n := Vector3(-tilt.x*axis,axis,-tilt.y*axis).normalized()
	for i in 6:
		var p0 := ring[i]
		var p1 := ring[(i+1)%6]
		tris += _faces_out(st,pos,inward,[b,Vector3(b.x+p0.x,b.y+tilt.dot(p0),b.z+p0.y),Vector3(b.x+p1.x,b.y+tilt.dot(p1),b.z+p1.y)],face_n,tint)
	return tris

## A triangle or quad (`corners`) of its own corners into the indexed rock,
## wound to face `out`, coloured `tint`.
static func _faces_out(st: SurfaceTool, pos: PackedVector3Array, inward: PackedVector3Array, corners: Array, out: Vector3, tint: Color) -> int:
	var at := pos.size()
	for v: Vector3 in corners:
		pos.append(v)
		inward.append(out)
		st.set_color(tint)
		st.add_vertex(v)
	var n := _tri(st,pos,inward,at,at+1,at+2)
	if corners.size() == 4: n += _tri(st,pos,inward,at,at+2,at+3)
	return n

## Tunnel `t`'s shafts (Tunnels.shafts): the lip in the vault (a skirt and
## a flare, the rock's material on the inside's layer), the wall up to the
## pit's floor and the curb round its top (in the day), each added to
## `mesh` too (the collider's); a spot of daylight down each and a faint
## beam. Returns the triangles.
func _build_shafts(bt: Built, mesh: ArrayMesh, base_name: String, rock_mat: Material) -> int:
	var t: Tunnels.Site = bt.site
	if t.shafts.is_empty(): return 0
	var tris := 0
	var dark := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb := SurfaceTool.new()
	curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dpos := PackedVector3Array()
	var dnrm := PackedVector3Array()
	var wpos := PackedVector3Array()
	var wnrm := PackedVector3Array()
	var r := Tunnels.SHAFT_R
	var lump := Tunnels.ROCK_LUMP
	var n := SHAFT_SEGS+1
	for si in t.shafts.size():
		var sh: Dictionary = t.shafts[si]
		var at: Vector2 = sh.at
		var crown: float = sh.crown
		var top_y: float = sh.top
		# The lip: per angle, the vault's solid at LIP_R, LIP_UP over it,
		# then the shaft's radius FLARE_H over the crown.
		var d0 := dpos.size()
		for k in n:
			var th := TAU*float(k)/SHAFT_SEGS
			var rad := Vector3(cos(th),0.0,sin(th))
			var lip := at+Vector2(rad.x,rad.z)*LIP_R
			var q := Tunnels.local(t,lip.x,lip.y)
			var hy := Tunnels.roof_over(Tunnels.profile(t,q.x),q.y)
			var ys := t.floor_y+(hy if not is_nan(hy) else crown-t.floor_y-4.0)
			var p0 := Vector3(lip.x,ys-0.1,lip.y)
			var p1 := Vector3(lip.x,ys+LIP_UP,lip.y)
			var p2 := Vector3(at.x,crown+FLARE_H,at.y)+rad*r
			var dr := r-LIP_R
			var dy := p2.y-p1.y
			var flare := (-rad*dy+Vector3.UP*dr).normalized()
			for v: Array in [[p0,-rad],[p1,-rad],[p1,flare],[p2,flare]]:
				dark.set_normal(v[1])
				dark.set_color(CAVE_TINT.darkened(0.3))
				dark.add_vertex(v[0])
				dpos.append(v[0])
				dnrm.append(v[1])
		for k in SHAFT_SEGS:
			var a := d0+k*4
			var b := d0+(k+1)*4
			for band in [[0,1],[2,3]]:
				tris += _tri(dark,dpos,dnrm,a+band[0],b+band[0],b+band[1])+_tri(dark,dpos,dnrm,a+band[0],b+band[1],a+band[1])
		# The wall: rings from the flare's top to the curb's, lumped out
		# (none at the top, where the curb meets it), darkening downward.
		var y0 := crown+FLARE_H
		var y1 := top_y+CURB_H
		var rings := maxi(2,ceili((y1-y0)/SHAFT_RING))
		var w0 := wpos.size()
		for j in rings+1:
			var u := float(j)/rings
			var y := lerpf(y0,y1,u)
			var lumped := lump*(1.0-smoothstep(y1-6.0,y1-1.0,y))
			for k in n:
				var th := TAU*float(k % SHAFT_SEGS)/SHAFT_SEGS
				var rad := Vector3(cos(th),0.0,sin(th))
				var base := Vector3(at.x,y,at.y)+rad*r
				var nz := clampf(t.rock.get_noise_3d(base.x*3.0,base.y*3.0,base.z*3.0)*0.5+0.5,0.0,1.0)
				var v := base+rad*lumped*nz
				wall.set_normal(-rad)
				wall.set_color(CAVE_TINT.darkened(0.82).lerp(FACE_TINT,pow(u,1.6)).darkened(0.25*nz))
				wall.add_vertex(v)
				wpos.append(v)
				wnrm.append(-rad)
		for j in rings:
			for k in SHAFT_SEGS:
				var a := w0+j*n+k
				var b := a+n
				tris += _tri(wall,wpos,wnrm,a,a+1,b+1)+_tri(wall,wpos,wnrm,a,b+1,b)
		# The curb: a flat top and its outer face sunk into the pit's floor.
		for k in SHAFT_SEGS:
			var ta := TAU*float(k)/SHAFT_SEGS
			var tb := TAU*float(k+1)/SHAFT_SEGS
			var ra := Vector3(cos(ta),0.0,sin(ta))
			var rb := Vector3(cos(tb),0.0,sin(tb))
			var c := Vector3(at.x,y1,at.y)
			var tint := FRAME_TINT.darkened(0.1*(t.rock.get_noise_2d(float(k)*9.0,float(si)*200.0)*0.5+0.5))
			tris += _quad(curb,c+ra*r,c+rb*r,c+rb*(r+CURB_W),c+ra*(r+CURB_W),Vector3.UP,tint)
			var down := Vector3.DOWN*(CURB_H+SKIRT)
			tris += _quad(curb,c+ra*(r+CURB_W),c+rb*(r+CURB_W),c+rb*(r+CURB_W)+down,c+ra*(r+CURB_W)+down,(ra+rb).normalized(),tint.darkened(0.12))
		_shaft_light(bt,si,base_name)
	var dmesh := dark.commit()
	var wmesh := wall.commit()
	curb.commit(wmesh)
	for m: ArrayMesh in [dmesh,wmesh]:
		for i in m.get_surface_count(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,m.surface_get_arrays(i))
	var lipn := MeshInstance3D.new()
	lipn.name = base_name+"_shaft_lips"
	lipn.mesh = _surface(dmesh,0,rock_mat)
	lipn.layers = UNDER_LAYER
	bt.node.add_child(lipn)
	var day := _portal_material(t)
	var walls := MeshInstance3D.new()
	walls.name = base_name+"_shafts"
	var wm := _surface(wmesh,0,day)
	wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,wmesh.surface_get_arrays(1))
	wm.surface_set_material(1,day)
	walls.mesh = wm
	bt.node.add_child(walls)
	return tris

## Shaft `si`'s daylight: a spot from its top down onto the bore's floor
## (the inside's layer only, the sun's colour, SHAFT_ENERGY x it) and a
## faint beam of light from the vault down into the cavern.
func _shaft_light(b: Built, si: int, base_name: String) -> void:
	var t: Tunnels.Site = b.site
	var sh: Dictionary = t.shafts[si]
	var at: Vector2 = sh.at
	var top_y: float = sh.top
	var drop := top_y-1.0-t.floor_y
	var spot := SpotLight3D.new()
	spot.name = "%s_shaft%d_light" % [base_name,si]
	spot.transform = Transform3D(Basis.looking_at(Vector3.DOWN,Vector3.FORWARD),Vector3(at.x,top_y-1.0,at.y))
	spot.spot_range = drop+12.0
	spot.spot_angle = rad_to_deg(atan(Tunnels.SHAFT_R*SHAFT_SPREAD/drop))
	spot.spot_attenuation = SPILL_ATTEN
	spot.light_cull_mask = UNDER_LAYER
	spot.shadow_enabled = false
	spot.light_specular = 0.2
	spot.visible = false
	b.node.add_child(spot)
	b.spills.append(spot)
	b.spill_gain.append(SHAFT_ENERGY)
	var cyl := CylinderMesh.new()
	cyl.top_radius = Tunnels.SHAFT_R*0.92
	cyl.bottom_radius = Tunnels.SHAFT_R*SHAFT_SPREAD*0.7
	# From just over the vault's crown (under the rock's cut edge) down.
	var beam_top := float(sh.crown)+FLARE_H*0.5
	cyl.height = beam_top-t.floor_y
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = _beam_shader()
	mat.set_shader_parameter("tint",BEAM_TINT)
	mat.set_shader_parameter("alpha",BEAM_ALPHA)
	cyl.material = mat
	var beam := MeshInstance3D.new()
	beam.name = "%s_shaft%d_beam" % [base_name,si]
	beam.mesh = cyl
	beam.position = Vector3(at.x,(beam_top+t.floor_y)*0.5,at.y)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.layers = UNDER_LAYER
	beam.visible = false
	b.node.add_child(beam)
	b.beams.append(beam)

static var _beam: Shader
static var _door_mat: StandardMaterial3D

## The beam's shader: added light, faint at its edges (seen side on) and
## fading toward the floor.
static func _beam_shader() -> Shader:
	if _beam != null: return _beam
	_beam = Shader.new()
	_beam.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha = 0.07;
void fragment() {
	float face = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	float down = mix(1.0, 0.4, UV.y)*smoothstep(1.0, 0.9, UV.y)*smoothstep(0.0, 0.2, UV.y);
	ALBEDO = tint.rgb;
	ALPHA = alpha*face*down;
}
"""
	return _beam

## Whether the rock's triangle `tri` (indices into `pos`) lies wholly in a
## shaft's opening: every corner within SHAFT_CUT of the axis, in the roof.
static func _opened(t: Tunnels.Site, pos: PackedVector3Array, tri: Array) -> bool:
	for sh: Dictionary in t.shafts:
		var at: Vector2 = sh.at
		var all := true
		for i: int in tri:
			var v := pos[i]
			if v.y < t.floor_y+2.0 or Vector2(v.x,v.z).distance_to(at) > SHAFT_CUT:
				all = false
				break
		if all: return true
	return false

## One triangle of the rock, wound to face `inward` (Godot's front faces are
## clockwise as seen; generate_normals follows the winding).
static func _tri(st: SurfaceTool, pos: PackedVector3Array, inward: PackedVector3Array, a: int, b: int, c: int) -> int:
	var nm := inward[a]+inward[b]+inward[c]
	if (pos[b]-pos[a]).cross(pos[c]-pos[a]).dot(nm) > 0.0:
		var k := b
		b = c
		c = k
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)
	return 1

## The torch lines (Tunnels.torch_spots): an iron bracket off the wall and
## a glowing flame card on it (one MultiMesh each), bigger and whiter on a
## bend's outside wall and at the mouths. The nearest burn as real flames
## and get lights (`_light_torches`); their feet and light spots are kept.
func _build_torches(b: Built) -> void:
	var t: Tunnels.Site = b.site
	var spots: Array = Tunnels.torch_spots(t)
	var bracket := _sconce()
	var card := QuadMesh.new()
	card.size = TORCH_FLAME
	card.center_offset = Vector3(0.0,TORCH_FLAME.y*0.5,0.0)
	var glow := ShaderMaterial.new()
	glow.shader = _card_shader()
	glow.set_shader_parameter("dot_rad",CARD_DOT)
	card.material = glow
	var mb := MultiMesh.new()
	mb.transform_format = MultiMesh.TRANSFORM_3D
	mb.mesh = bracket
	# A sunk cave's glows stand on the rock: no sconce.
	mb.instance_count = 0 if t.sunk else spots.size()
	var mf := MultiMesh.new()
	mf.transform_format = MultiMesh.TRANSFORM_3D
	mf.use_colors = true
	mf.mesh = card
	# A sunk cave's glows are light on the rock: no flame, and no card (a card
	# of any size still grows to a dot of glow down the bore).
	mf.instance_count = 0 if t.sunk else spots.size()
	b.cards = mf
	for i in spots.size():
		var sp: Dictionary = spots[i]
		var into: Vector2 = sp.into
		var pos: Vector3 = sp.pos
		var big: float = float(TORCH_BIG.get(sp.kind,1.0))*TORCH_SIZE
		var out := Vector3(into.x,0.0,into.y)
		# The sconce stands on the wall at `pos`, its arm out (local -z).
		var bs := Basis.looking_at(out,Vector3.UP)
		if not t.sunk: mb.set_instance_transform(i,Transform3D(bs.scaled(Vector3.ONE*big),pos))
		# The flame's foot: in the cup.
		var foot := pos+out*TORCH_CUP.x*big+Vector3.UP*TORCH_CUP.y*big
		var tint := (TORCH_GLOW.get(sp.kind,TORCH_GLOW.wall) as Color).srgb_to_linear()
		if not t.sunk:
			mf.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*big),foot))
			mf.set_instance_color(i,tint)
		b.tint.append(tint)
		b.feet.append(foot)
		b.feet_big.append(big)
		# The light: at the flame, a little out of it into the bore.
		b.lamps.append(foot+out*0.4*big+Vector3.UP*TORCH_FLAME.y*0.4*big)
		b.lamp_big.append(sqrt(big/TORCH_SIZE))
	for pair: Array in [[mb,"_torch_brackets"],[mf,"_torch_flames"]]:
		var node := MultiMeshInstance3D.new()
		node.name = t.name.replace("/","_")+str(pair[1])
		node.multimesh = pair[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = UNDER_LAYER
		b.node.add_child(node)
	b.torches = spots.size()

## The sconce in its own space (the wall at z 0, out along -z, the cup's
## rim at TORCH_CUP): a plate, an arm rising out to the cup, the cup. Iron.
static func _sconce() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.3,0.62,0.06)
	st.append_from(plate,0,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.42,-0.03)))
	var from := Vector3(0.0,-0.5,-0.04)
	var to := Vector3(0.0,TORCH_CUP.y-0.3,-TORCH_CUP.x)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.08,0.08,from.distance_to(to)+0.06)
	st.append_from(arm,0,Transform3D(Basis.looking_at(to-from,Vector3.UP),(from+to)*0.5))
	var cup := CylinderMesh.new()
	cup.top_radius = 0.2
	cup.bottom_radius = 0.07
	cup.height = 0.32
	cup.radial_segments = 10
	cup.rings = 1
	st.append_from(cup,0,Transform3D(Basis.IDENTITY,Vector3(0.0,TORCH_CUP.y-0.16,-TORCH_CUP.x)))
	var mesh := st.commit()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09,0.08,0.07)
	iron.roughness = 0.75
	iron.metallic = 0.4
	mesh.surface_set_material(0,iron)
	return mesh

static var _card_sh: Shader

## The flame card's shader: an upright billboard (it turns about its own
## up), a flickering teardrop of fire with a pale heart and a soft halo,
## added light. Far off it grows to hold `dot` rad across and rounds into a
## dot of glow. The instance colour is its tint; its alpha hides it under a
## real flame.
static func _card_shader() -> Shader:
	if _card_sh != null: return _card_sh
	_card_sh = Shader.new()
	_card_sh.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float dot_rad = 0.006;
varying vec4 tint;
varying float seed;
varying float grow;
void vertex() {
	tint = COLOR;
	seed = float(INSTANCE_ID)*1.731;
	vec3 at = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = CAMERA_POSITION_WORLD-at;
	float d = length(to_eye);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye+vec3(1e-4, 0.0, 0.0)));
	vec3 face = cross(side, vec3(0.0, 1.0, 0.0));
	grow = max(1.0, d*dot_rad/(size*0.62));
	vec3 v = VERTEX*size*grow;
	// A grown dot stands on its middle, not its foot.
	v.y -= (grow-1.0)*size*0.55*0.5;
	vec3 w = at+side*v.x+vec3(0.0, 1.0, 0.0)*v.y+face*v.z;
	POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(w, 1.0);
}
void fragment() {
	float y = 1.0-UV.y;
	float t = TIME*1.0+seed;
	float x = UV.x-0.5+sin(y*7.0-t*9.0)*0.05*y+sin(t*3.1)*0.03*y;
	float flick = 0.86+0.1*sin(t*11.0)+0.06*sin(t*23.0+1.7);
	float tall = 0.82+0.12*sin(t*5.3)*sin(t*1.9+0.4);
	float yb = y/tall;
	float w = 0.3*smoothstep(0.0, 0.28, yb)*pow(clamp(1.0-yb, 0.0, 1.0), 0.85)+0.001;
	float core = 1.0-smoothstep(0.0, w, abs(x));
	core *= step(yb, 1.0);
	float hot = core*core*(1.0-yb);
	vec2 c = vec2(UV.x-0.5, y-0.32)*vec2(1.0, 0.8);
	float halo = exp(-dot(c, c)*22.0)*0.35;
	vec3 fire = mix(tint.rgb, vec3(1.0, 0.86, 0.6), hot)*(core*1.6+hot)+tint.rgb*halo;
	vec2 r = (UV-0.5)*2.0;
	float spot = exp(-dot(r, r)*5.0);
	float k = clamp((grow-1.0)*2.0, 0.0, 1.0);
	ALBEDO = mix(fire, tint.rgb*vec3(1.4, 1.2, 1.0)*spot*1.6, k)*flick*tint.a;
}
"""
	return _card_sh

## Mouth `m`'s point `a` in, `d` across, at height `y`.
static func _v(t: Tunnels.Site, m: int, a: float, d: float, y: float) -> Vector3:
	var q := Tunnels.portal_point(t,m,a,d)
	return Vector3(q.x,y,q.y)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, tint: Color) -> int:
	var nm := normal.normalized()
	# Wound to face its normal (Godot's front faces are clockwise as seen),
	# else the far side's flipped normal lights it.
	var order := [a,b,c,a,c,d]
	if (b-a).cross(c-a).dot(nm) > 0.0: order = [a,c,b,a,d,c]
	for v: Vector3 in order:
		st.set_normal(nm)
		st.set_color(tint)
		st.add_vertex(v)
	return 2
