extends Node3D
## The dandelion's round (docs/scenic/dandelions.md). Seed clocks let their
## seeds go on the air, stand bare, bloom gold, and fluff out into clocks
## again; a few of the seeds that come down take, so a drift creeps out
## downwind. Living plants spread; the hand's tools only paint
## (docs/scenic/handful.md "Flower seed").
##
## - **The breeze peels.** Now and then the world's air takes a seed or two
##   from a clock, more often the stronger it blows (`PEEL`, read from the
##   same air the pollen rides, scripts/pollen_wind.gd). A clock in the
##   default breeze is bare in the better part of an hour.
## - **A gust strips.** Where the wind tool's air leans the plants hard (its
##   lanes, bursts, the blowing hand and the Feather's wake, WindGust
##   `blow_at`), clocks lose their seeds in a second, in a soft cloud that the
##   gust carries on (`STRIP`).
## - **The round.** A clock whose last seed has gone stands bare for BARE
##   seconds (and up to BARE_JITTER more, so a stripped patch comes back plant
##   by plant), opens a gold head for GOLD, closes over CLOSE, and fluffs out
##   over FLUFF. The material draws all of it from one number per clock, its
##   instance alpha (GardenView `set_flower_state`, `flower_cycle` in
##   shaders/reference_surface.gdshader); nothing is rebuilt and the record
##   never changes.
## - **The seeds** (shaders/dandelion_seed.gdshader) lift off the head, ride
##   the air, rise a little in a stiff breeze, sink slowly in still air, and
##   fade where they land or as they leave the land. At most SEEDS_MAX fly at
##   once; a stripped clock sends a share of its seeds (STRIP_SHOWN) as motes.
## - **Some take.** A seed that lands may come up as a dandelion (or a seed
##   clock) where the flower brush could paint one (FlowerSowing `suits`,
##   with room), only near flowers already standing (CREEP) and not where a
##   drift is already full (CROWD), never on ground the hand thinned in the
##   last CLEAR_HOLD seconds, at most one every SPREAD_GAP seconds, and none
##   once the land holds MOST_FLOWERS. It is
##   emerged life: saved, drawn at once through the paint preview, growing in
##   with its birth, and never written into an open stroke.
##
## - **Pollen, the other kinds** (docs/scenic/flower-spread.md). The kit's other
##   flowers (BLOOMS: the per-kind spec, the seam) let faint pollen glints
##   off their heads: a little in the breeze (`PUFF`), more under a wind-tool
##   gust (`GUST_PUFF`). The glints ride the same air as the seeds and are
##   drawn as the wind tool's specks (shaders/pollen_speck.gdshader). A
##   grain that lands takes far more rarely (`POLLEN_TAKE`, a quarter of the
##   dandelion's creep) under the very same rules, and what comes up copies
##   its parent's kind. They have no round: no wilting, no regrowing.
##
## Nothing here is saved: a world reopens with every clock whole.
##
## Lives under the terrain node, so its coordinates are the plate's.

const Wind = preload("res://scripts/pollen_wind.gd")
const Emergence = preload("res://scripts/emergence.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const Flowers = preload("res://scripts/meadow_flower_mesh.gd")

## The round's seconds (the material's `flower_cycle_times`).
const BARE := 30.0
const GOLD := 55.0
const CLOSE := 2.0
const FLUFF := 5.0
const BARE_JITTER := 25.0
## Seeds on one clock (its parachutes).
const SEEDS := 42
## The breeze's peel: a clock loses a seed or two about once every 1 / PEEL
## seconds when the air drifts pollen at PEEL_AIR m/s, as the square of the
## air above that, and hardly at all in calm.
const PEEL := 1.0/80.0
const PEEL_AIR := 1.0
## The wind tool's strip: share of a clock's seeds a second where its air
## leans the plants from STRIP_LEAN.x (none) to .y (all of STRIP).
const STRIP := 4.5
const STRIP_LEAN := Vector2(0.25,0.85)
## Share of a stripped clock's seeds drawn as motes; each carries the rest's
## chance of taking.
const STRIP_SHOWN := 0.2
## The seeds in the air.
const SEEDS_MAX := 360
## The other kinds' spec: the flower slot whose ground rules and sizes a new
## plant of the kind uses (FlowerSowing SLOTS), and the pollen's colour
## (sRGB), warm and pale. Dandelions are the seeds' own and are not here.
const BLOOMS := {
	"oxeye_daisy":{"slot":"wildflower","pollen":"f3e18c"},
	"buttercup":{"slot":"wildflower","pollen":"f6d94e"},
	"poppy":{"slot":"poppy","pollen":"f0cf72"},
	"cosmos":{"slot":"cosmos","pollen":"f6d88a"},
	"lupine":{"slot":"wildflower","pollen":"f1e4a8"},
	"sunflower":{"slot":"sunflower","pollen":"f5c94a"},
}
## Pollen: about once every 1 / PUFF seconds a bloom lets a grain go when the
## air drifts at PEEL_AIR m/s (as the square of the air), at most POLLEN_RATE
## a second over the whole land; under a gust a bloom lets GUST_PUFF a second
## go at full lean, the lanes read GUST_TICK seconds apart.
const PUFF := 1.0/25.0
const POLLEN_RATE := 24.0
const GUST_PUFF := 0.6
const GUST_TICK := 0.25
## The grains in the air, their radius (m), opacity, sinking speed (m/s), the
## highest above the ground they ride (m), longest flight and settle (s).
const POLLEN_MAX := 220
const POLLEN_SIZE := Vector2(0.05,0.085)
const POLLEN_OPACITY := 0.85
const POLLEN_SINK := 0.22
const POLLEN_CEILING := 3.0
const POLLEN_LONGEST := 14.0
const POLLEN_SETTLE := 1.0
## Chance a landed grain takes: about a quarter of the dandelion's creep.
const POLLEN_TAKE := 0.008
## Seed size (m), drawn larger than life as the heads are.
const SIZE := Vector2(0.022,0.034)
const COLOUR := Color(0.97,0.96,0.92)
const OPACITY := 0.55
## Sinking speed in still air (m/s), how fast a seed takes up the air's way
## (1/s), the lift a moving air gives (m/s per m/s of air), how high above
## the ground a seed may ride (m), and the share of the wind tool's lean, in
## m/s per unit, a seed rides on.
const SINK := 0.32
const FOLLOW := 2.2
const LIFT := 0.06
const CEILING := 5.0
const LEAN_CARRY := 3.2
## Seconds a seed lingers once landed, and the longest it flies.
const SETTLE := 1.4
const LONGEST := 45.0
## Spreading: chance a landed seed takes, the nearest standing flower it needs
## (m), at most CROWD flowers within CROWD_REACH (m) round it, the room it
## needs from any plant (m), the least seconds between takes, and how long
## (and how near, m) ground the hand thinned stays clear.
const TAKE := 0.12
const CREEP := 3.0
const CROWD := 5
const CROWD_REACH := 0.8
const ROOM := 0.22
const SPREAD_GAP := 3.0
const CLEAR_HOLD := 900.0
const CLEAR_REACH := 1.0
## No seed takes once the land holds this many kit flowers (the densest
## meadow type is about 4,500), so a world left running never fills up.
const MOST_FLOWERS := 5500
## Share of new plants that come up as seed clocks (the dandelion slot's mix).
const CLOCK_SHARE := 0.37
## Spatial buckets (m) for clocks and flowers, and the ground's cache cell.
const CELL := 2.0
const GROUND_CELL := 0.5
const SOWING_FRESH := 10.0

static func cycle_times() -> Vector4:
	return Vector4(BARE,GOLD,CLOSE,FLUFF)

static func round_seconds() -> float:
	return BARE+GOLD+CLOSE+FLUFF

var data: NativeTerrainData
## The view (GardenView) the clocks' state is written to.
var view: Object
## The scene, for the air (pollen_wind `at`).
var scene: Node
## The wind tool, when the editor has made one.
var gust: Node3D
## Makes a FlowerSowing for a slot ("dandelion"), with the live water.
var sowing_for: Callable
## True while the land may not take new plants (an open stroke, forming).
var held: Callable = func() -> bool: return false
var enabled := true
var spreading := true
## Probes and tests: the world's air everywhere (m/s), instead of the scene's.
var air_override := Vector2.INF

## Clock id -> {"p": its head (`_track`), "lost": 0..1, "bare": t or -1}.
var clocks := {}
var _clock_cells := {}
var _clock_ids: Array[int] = []
## Every kit flower's foot, bucketed: Vector2i -> [Vector2].
var _flower_cells := {}
## Every plant's foot and room, bucketed by 0.5 m.
var _room_cells := {}
var _flower_ids := {}
## The other kinds' heads (BLOOMS): x, height over the foot, z; the kind; and
## the same bucketed by CELL, as indexes.
var _bloom_p := PackedVector3Array()
var _bloom_kind := PackedStringArray()
var _bloom_cells := {}
var _since_gust := 0.0
var _pollen_n := 0
var _pollen_tint := {}
## [Vector2 foot, time] where the hand thinned flowers.
var _cleared: Array = []
var _rng := RandomNumberGenerator.new()
var _since_round := 0.0
var _stale := false
var _read_revision := -1
var _read_count := -1
var _since_take := INF
var _sowings := {}

# The seeds in the air (plate space).
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _landed := PackedFloat32Array()
var _size := PackedFloat32Array()
var _weight := PackedFloat32Array()
var _turn := PackedFloat32Array()
var _floor := PackedFloat32Array()
## "" for a dandelion seed, else the kind of the bloom a grain came from.
var _kind := PackedStringArray()
var _buffer := PackedFloat32Array()
var _pollen_buffer := PackedFloat32Array()
var _pollen_node: MultiMeshInstance3D
var _node: MultiMeshInstance3D
var _air_cache := {}
var _ground_cache := {}
var _blow_cache := {}
var _blowing := false

## Counters for probes and tests.
var peeled := 0
var pollen_released := 0
var stripped := 0
var landed := 0
## Where seeds came down (the first 4096), for probes.
var landings := PackedVector2Array()
var taken: Array[int] = []
## Why seeds that came down did not take: reason -> count.
var refused := {}
var last_step_usec := 0
## The dearest step since the counter was last cleared, for probes.
var most_step_usec := 0

func _ready() -> void:
	_rng.seed = 7741
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	multimesh.mesh = quad
	multimesh.instance_count = SEEDS_MAX
	multimesh.visible_instance_count = 0
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dandelion_seed.gdshader")
	_node = MultiMeshInstance3D.new()
	_node.name = "Seeds"
	_node.multimesh = multimesh
	_node.material_override = material
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.top_level = true
	_node.custom_aabb = AABB(Vector3(-400,-100,-400),Vector3(800,300,800))
	_node.visible = false
	add_child(_node)
	for kind: String in BLOOMS: _pollen_tint[kind] = Color(str(BLOOMS[kind].pollen)).srgb_to_linear()
	var grains := MultiMesh.new()
	grains.transform_format = MultiMesh.TRANSFORM_3D
	grains.use_colors = true
	grains.use_custom_data = true
	grains.mesh = quad
	grains.instance_count = POLLEN_MAX
	grains.visible_instance_count = 0
	var speck := ShaderMaterial.new()
	speck.shader = preload("res://shaders/pollen_speck.gdshader")
	_pollen_node = MultiMeshInstance3D.new()
	_pollen_node.name = "Pollen"
	_pollen_node.multimesh = grains
	_pollen_node.material_override = speck
	_pollen_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pollen_node.top_level = true
	_pollen_node.custom_aabb = _node.custom_aabb
	_pollen_node.visible = false
	add_child(_pollen_node)

# --- What stands -------------------------------------------------------------------

## The land was published: read it again on the next step, not in the
## publish's own frame, and only when its objects changed (a dense meadow
## takes a few milliseconds to read). The ground is read afresh either way.
func land_changed() -> void:
	_ground_cache.clear()
	if data != null and data.objects_revision == _read_revision and data.objects.size() == _read_count: return
	_stale = true

## Reads the clocks and flowers from the records (after a publish or undo).
## Clocks that are gone lose their state.
func reindex() -> void:
	_stale = false
	_read_revision = data.objects_revision
	_read_count = data.objects.size()
	var kept := {}
	_ground_cache.clear()
	_clock_cells.clear()
	_clock_ids.clear()
	_flower_cells.clear()
	_room_cells.clear()
	_flower_ids.clear()
	_bloom_p.clear()
	_bloom_kind.clear()
	_bloom_cells.clear()
	for item: Dictionary in data.objects:
		var foot := Vector2(float(item.x),float(item.z))
		var asset := str(item.asset)
		_room_cells.get_or_add(Vector2i((foot/0.5).floor()),[]).append(foot)
		if not Flowers.SPEC.has(asset): continue
		var id := int(item.id)
		_flower_ids[id] = foot
		_flower_cells.get_or_add(_cell(foot),[]).append(foot)
		if asset in Flowers.CYCLE_KINDS: kept[id] = _track(item,clocks.get(id,{}))
		elif BLOOMS.has(asset): _add_bloom(item,asset)
	for id: int in clocks.keys():
		if not kept.has(id) and view != null: view.set_flower_state(id,1.0)
	clocks = kept
	for id: int in clocks: _clock_ids.append(id)

## A bloom of a kind in BLOOMS: its head's place for the pollen.
func _add_bloom(item: Dictionary, asset: String) -> void:
	var scale := float(item.get("scale",1.0))
	var head := Vector3(float(item.x),float(Flowers.SPEC[asset].height)*0.92*scale,float(item.z))
	_bloom_cells.get_or_add(_cell(Vector2(head.x,head.z)),PackedInt32Array()).append(_bloom_p.size())
	_bloom_p.append(head)
	_bloom_kind.append(asset)

## A clock's entry: "p" its head's x, z (plate) with, in y, the head's height
## over its foot (its neck, 0.34 m, and the head's middle above, at the
## record's scale); the ground is read only when a seed leaves (`head_of`).
func _track(item: Dictionary, was: Dictionary) -> Dictionary:
	var id := int(item.id)
	var head := Vector3(float(item.x),0.39*float(item.get("scale",1.0)),float(item.z))
	var entry := {"p":head,"lost":float(was.get("lost",0.0)),"bare":float(was.get("bare",-1.0))}
	_clock_cells.get_or_add(_cell(Vector2(head.x,head.z)),[]).append(id)
	return entry

## The head of the clock `entry` describes, in plate space.
func head_of(entry: Dictionary) -> Vector3:
	var head: Vector3 = entry.p
	var ground: Variant = ground_at(Vector2(head.x,head.z))
	return Vector3(head.x,(float(ground) if ground != null else 0.0)+head.y,head.z)

## The world was restored (undo, load): every clock is whole and the air clear.
func restored() -> void:
	if view != null:
		for id: int in clocks: view.set_flower_state(id,1.0)
	clocks.clear()
	clear_air()
	reindex()

func clear_air() -> void:
	_pos.clear(); _vel.clear(); _age.clear(); _landed.clear(); _size.clear(); _weight.clear(); _turn.clear(); _floor.clear(); _kind.clear()
	_pollen_n = 0
	if _node != null:
		_node.multimesh.visible_instance_count = 0
		_node.visible = false
	if _pollen_node != null:
		_pollen_node.multimesh.visible_instance_count = 0
		_pollen_node.visible = false

## The hand thinned flowers `ids` (scripts/flower_paint.gd): seed keeps off
## where they stood for a while.
func cleared(ids: Array) -> void:
	for id in ids:
		if _flower_ids.has(int(id)): _cleared.append([_flower_ids[int(id)],Emergence.time])

func _cell(p: Vector2) -> Vector2i:
	return Vector2i((p/CELL).floor())

# --- Every frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	# Paused, the seeds hang where they are, as the wind tool's motes do.
	if scene != null and scene.get("_paused") == true: return
	step(minf(delta,0.05))

func step(delta: float) -> void:
	var began := Time.get_ticks_usec()
	if data == null or not enabled:
		return
	if _stale: reindex()
	_air_cache.clear()
	_blow_cache.clear()
	_blowing = gust != null and is_instance_valid(gust) and (not gust.gusts.is_empty() or gust.aiming() or not gust.wakes.is_empty())
	_since_take += delta
	if not clocks.is_empty():
		_peel(delta)
		if _blowing: _strip(delta)
		_since_round += delta
		if _since_round >= 0.5:
			_since_round = 0.0
			_turn_round()
	if not _bloom_p.is_empty():
		_puff(delta)
		if _blowing:
			_since_gust += delta
			if _since_gust >= GUST_TICK:
				_gust_puff(_since_gust)
				_since_gust = 0.0
	_fly(delta)
	_draw_seeds()
	last_step_usec = Time.get_ticks_usec()-began
	most_step_usec = maxi(most_step_usec,last_step_usec)

## The world's air at `p` (plate x, z, m/s): pollen's drift there, cached per
## cell a frame.
func air_at(p: Vector2) -> Vector2:
	if air_override != Vector2.INF: return air_override
	var key := _cell(p)
	if not _air_cache.has(key):
		_air_cache[key] = Wind.at(scene,get_parent() as Node3D,(Vector2(key)+Vector2(0.5,0.5))*CELL) if scene != null and get_parent() is Node3D else Vector2.ZERO
	return _air_cache[key]

## The ground under `p` (plate x, z), or null off the land: read once per
## GROUND_CELL and kept until the land is published again (`reindex`).
func ground_at(p: Vector2) -> Variant:
	var key := Vector2i((p/GROUND_CELL).floor())
	if not _ground_cache.has(key): _ground_cache[key] = data.ground_height((Vector2(key)+Vector2(0.5,0.5))*GROUND_CELL)
	return _ground_cache[key]

## The wind tool's lean on the plants at `p` (plate x, z): its push in plate
## x, z, 0 to about 1.4. Cached per metre cell a frame.
func lean_at(p: Vector2) -> Vector2:
	if not _blowing: return Vector2.ZERO
	var key := Vector2i(p.floor())
	if not _blow_cache.has(key):
		var plate := get_parent() as Node3D
		var centre := Vector3(float(key.x)+0.5,0.0,float(key.y)+0.5)
		var world := plate.to_global(centre) if plate != null else centre
		var lean: Vector3 = gust.blow_at(Vector2(world.x,world.z))
		var way := plate.global_basis.inverse()*Vector3(lean.x,0.0,lean.y) if plate != null else Vector3(lean.x,0.0,lean.y)
		_blow_cache[key] = Vector2(way.x,way.z)
	return _blow_cache[key]

## The breeze takes a seed or two from a few clocks.
func _peel(delta: float) -> void:
	# The meadow's air, read once; each pick reads its own.
	var mean := air_at(Vector2.ZERO).length()
	var rate := PEEL*float(_clock_ids.size())*pow(mean/PEEL_AIR,2.0)
	var events := int(rate*delta)
	if _rng.randf() < rate*delta-float(events): events += 1
	for i in range(mini(events,8)):
		var id: int = _clock_ids[_rng.randi_range(0,_clock_ids.size()-1)]
		var entry: Dictionary = clocks[id]
		if float(entry.bare) >= 0.0: continue
		var head: Vector3 = entry.p
		var local := air_at(Vector2(head.x,head.z)).length()
		if _rng.randf() > clampf(pow(local/maxf(mean,0.05),2.0),0.0,2.0)*0.5: continue
		var count := 1 if _rng.randf() < 0.7 else 2
		_lose(id,entry,float(count)/SEEDS,1.0)
		peeled += count

## The breeze lifts a grain of pollen off a few blooms. Never a loop over
## them: the rate is for the whole land and each pick is a random bloom.
func _puff(delta: float) -> void:
	if _pollen_n >= POLLEN_MAX: return
	var mean := air_at(Vector2.ZERO).length()
	var rate := minf(PUFF*float(_bloom_p.size())*pow(mean/PEEL_AIR,2.0),POLLEN_RATE)
	var events := int(rate*delta)
	if _rng.randf() < rate*delta-float(events): events += 1
	for i in range(mini(events,8)):
		var index := _rng.randi_range(0,_bloom_p.size()-1)
		var head := _bloom_p[index]
		var local := air_at(Vector2(head.x,head.z)).length()
		if _rng.randf() > clampf(pow(local/maxf(mean,0.05),2.0),0.0,2.0)*0.5: continue
		_release(index)

## The wind tool's lanes shake pollen from the blooms they lean on, read a
## cell at a time every GUST_TICK seconds, and only the cells the air touches.
func _gust_puff(span: float) -> void:
	for cell: Vector2i in _bloom_cells:
		if _pollen_n >= POLLEN_MAX: return
		var middle := (Vector2(cell)+Vector2(0.5,0.5))*CELL
		if _cell_lean(middle) < STRIP_LEAN.x*0.6: continue
		var members: PackedInt32Array = _bloom_cells[cell]
		var lean := lean_at(middle).length()
		var rate := GUST_PUFF*float(members.size())*smoothstep(STRIP_LEAN.x*0.6,STRIP_LEAN.y,lean)
		var events := int(rate*span)
		if _rng.randf() < rate*span-float(events): events += 1
		for i in range(mini(events,6)): _release(members[_rng.randi_range(0,members.size()-1)])

## A grain of pollen leaves bloom `index`.
func _release(index: int) -> void:
	if _pollen_n >= POLLEN_MAX: return
	var head := _bloom_p[index]
	var ground: Variant = ground_at(Vector2(head.x,head.z))
	var kind := _bloom_kind[index]
	if _spawn(Vector3(head.x,(float(ground) if ground != null else 0.0)+head.y,head.z),1.0,kind): pollen_released += 1

## The wind tool's air strips the clocks it leans hard.
func _strip(delta: float) -> void:
	for cell: Vector2i in _clock_cells:
		var middle := (Vector2(cell)+Vector2(0.5,0.5))*CELL
		# A cell the air misses by a margin is skipped whole.
		if _cell_lean(middle) < STRIP_LEAN.x*0.6: continue
		for id: int in _clock_cells[cell]:
			var entry: Dictionary = clocks[id]
			if float(entry.bare) >= 0.0: continue
			var head: Vector3 = entry.p
			var lean := lean_at(Vector2(head.x,head.z)).length()
			var share := STRIP*smoothstep(STRIP_LEAN.x,STRIP_LEAN.y,lean)*delta
			if share <= 0.0: continue
			var before := float(entry.lost)
			_lose(id,entry,share,STRIP_SHOWN)
			stripped += int(round((float(entry.lost)-before)*SEEDS))

func _cell_lean(middle: Vector2) -> float:
	var most := 0.0
	for offset: Vector2 in [Vector2.ZERO,Vector2(-0.7,-0.7),Vector2(0.7,-0.7),Vector2(-0.7,0.7),Vector2(0.7,0.7)]:
		most = maxf(most,lean_at(middle+offset).length())
	return most

## Clock `id` loses `share` of its seeds; `shown` of them fly as motes.
func _lose(id: int, entry: Dictionary, share: float, shown: float) -> void:
	var before := float(entry.lost)
	var after := minf(before+share,1.0)
	var whole_before := floori(before*SEEDS+0.0001)
	var whole_after := floori(after*SEEDS+0.0001)
	entry.lost = after
	var gone := whole_after-whole_before
	var head := head_of(entry) if gone > 0 else Vector3.ZERO
	for k in range(gone):
		if _rng.randf() < shown: _launch(head,1.0/shown)
	if after >= 1.0:
		entry.bare = Emergence.time+_rng.randf()*BARE_JITTER
		if view != null: view.set_flower_state(id,4.0+float(entry.bare))
	elif gone > 0 and view != null:
		view.set_flower_state(id,1.0+float(whole_after)/SEEDS)

## Bare clocks that have come round are whole again; thinned ground that has
## been clear long enough is open to seed again.
func _turn_round() -> void:
	var now := Emergence.time
	_cleared = _cleared.filter(func(stamp: Array) -> bool: return now-float(stamp[1]) < CLEAR_HOLD and now >= float(stamp[1]))
	for id: int in _clock_ids:
		var entry: Dictionary = clocks[id]
		var bare := float(entry.bare)
		if bare < 0.0 or now < bare+round_seconds(): continue
		entry.bare = -1.0
		entry.lost = 0.0
		if view != null: view.set_flower_state(id,1.0)

# --- The seeds -------------------------------------------------------------------

func _launch(head: Vector3, weight: float) -> void:
	if _pos.size()-_pollen_n >= SEEDS_MAX: return
	_spawn(head,weight,"")

## A seed (`kind` "") or a grain of pollen leaves `head`. False when the air
## holds all it may.
func _spawn(head: Vector3, weight: float, kind: String) -> bool:
	var pollen := not kind.is_empty()
	if pollen and _pollen_n >= POLLEN_MAX: return false
	var out := Vector3(_rng.randfn(0.0,1.0),_rng.randfn(0.0,1.0)*0.6+0.4,_rng.randfn(0.0,1.0)).normalized()
	var p := head+out*0.06
	var air := air_at(Vector2(p.x,p.z))+lean_at(Vector2(p.x,p.z))*LEAN_CARRY
	_pos.append(p)
	_vel.append(Vector3(air.x*0.5,0.25+_rng.randf()*0.35,air.y*0.5)+out*0.15)
	_age.append(0.0)
	_landed.append(-1.0)
	var size_range := POLLEN_SIZE if pollen else SIZE
	_size.append(_rng.randf_range(size_range.x,size_range.y))
	_kind.append(kind)
	if pollen: _pollen_n += 1
	_weight.append(weight)
	_turn.append(_rng.randf()*TAU)
	var ground: Variant = ground_at(Vector2(p.x,p.z))
	_floor.append(float(ground) if ground != null else p.y)
	return true

func _fly(delta: float) -> void:
	var i := 0
	var t := Emergence.time
	while i < _pos.size():
		_age[i] += delta
		var p := _pos[i]
		var pollen := not _kind[i].is_empty()
		if _landed[i] >= 0.0:
			if _age[i]-_landed[i] >= (POLLEN_SETTLE if pollen else SETTLE):
				_drop(i)
				continue
			i += 1
			continue
		var flat := Vector2(p.x,p.z)
		var air := air_at(flat)+lean_at(flat)*LEAN_CARRY
		var speed := air.length()
		# Each seed bobs on its own eddy.
		var eddy := sin(t*1.7+float(i)*2.3)*0.12+sin(t*0.63+float(i)*0.71)*0.08
		var sink := POLLEN_SINK if pollen else SINK
		var want := Vector3(air.x,-sink+LIFT*speed+eddy*(0.4+0.4*minf(speed,2.0)),air.y)
		if p.y > _floor[i]+(POLLEN_CEILING if pollen else CEILING): want.y = minf(want.y,-sink)
		var v := _vel[i].lerp(want,1.0-exp(-FOLLOW*delta))
		_vel[i] = v
		p += v*delta
		_pos[i] = p
		var ground: Variant = ground_at(Vector2(p.x,p.z))
		if ground != null: _floor[i] = float(ground)
		if ground == null or _age[i] >= (POLLEN_LONGEST if pollen else LONGEST):
			# Off the land, or long gone: it fades out in the air.
			_landed[i] = _age[i]
			_weight[i] = 0.0
		elif p.y <= float(ground)+0.03:
			_pos[i] = Vector3(p.x,float(ground)+0.03,p.z)
			_landed[i] = _age[i]
			landed += 1
			if landings.size() < 4096: landings.append(Vector2(p.x,p.z))
			_settle(Vector2(p.x,p.z),_weight[i],_kind[i])
		i += 1

func _drop(i: int) -> void:
	var last := _pos.size()-1
	if not _kind[i].is_empty(): _pollen_n -= 1
	if i != last:
		_pos[i] = _pos[last]; _vel[i] = _vel[last]; _age[i] = _age[last]; _landed[i] = _landed[last]
		_size[i] = _size[last]; _weight[i] = _weight[last]; _turn[i] = _turn[last]; _floor[i] = _floor[last]
		_kind[i] = _kind[last]
	_pos.resize(last); _vel.resize(last); _age.resize(last); _landed.resize(last)
	_size.resize(last); _weight.resize(last); _turn.resize(last); _floor.resize(last)
	_kind.resize(last)

func _draw_seeds() -> void:
	if _node == null: return
	var count := _pos.size()
	var grains := _pollen_n
	var seeds := count-grains
	_node.visible = seeds > 0
	_pollen_node.visible = grains > 0
	if count == 0:
		_node.multimesh.visible_instance_count = 0
		_pollen_node.multimesh.visible_instance_count = 0
		return
	var plate := get_parent() as Node3D
	var to_world := plate.global_transform if plate != null else Transform3D.IDENTITY
	var scale := to_world.basis.get_scale().x
	var t := Emergence.time
	# One buffer a look for the lot (transform, colour, custom: 20 floats a
	# particle), not three calls a particle.
	if _buffer.size() != SEEDS_MAX*20: _buffer.resize(SEEDS_MAX*20)
	if _pollen_buffer.size() != POLLEN_MAX*20: _pollen_buffer.resize(POLLEN_MAX*20)
	var buffer := _buffer
	var pollen_buffer := _pollen_buffer
	var n_seed := 0
	var n_grain := 0
	for i in range(count):
		var kind := _kind[i]
		var pollen := not kind.is_empty()
		var fade := 1.0
		if _landed[i] >= 0.0: fade = 1.0-clampf((_age[i]-_landed[i])/(POLLEN_SETTLE if pollen else SETTLE),0.0,1.0)
		fade *= clampf(_age[i]/0.25,0.0,1.0)
		var world := to_world*_pos[i]
		var size := _size[i]*scale
		var moving := to_world.basis*_vel[i]
		if pollen:
			if n_grain >= POLLEN_MAX: continue
			# A glint: it catches the light now and then as it turns.
			var twinkle := 0.7+0.3*sin(t*5.0+_turn[i]*3.0)
			var tint: Color = _pollen_tint[kind]
			var o := n_grain*20
			n_grain += 1
			pollen_buffer[o] = size; pollen_buffer[o+1] = 0.0; pollen_buffer[o+2] = 0.0; pollen_buffer[o+3] = world.x
			pollen_buffer[o+4] = 0.0; pollen_buffer[o+5] = size; pollen_buffer[o+6] = 0.0; pollen_buffer[o+7] = world.y
			pollen_buffer[o+8] = 0.0; pollen_buffer[o+9] = 0.0; pollen_buffer[o+10] = size; pollen_buffer[o+11] = world.z
			pollen_buffer[o+12] = tint.r; pollen_buffer[o+13] = tint.g; pollen_buffer[o+14] = tint.b; pollen_buffer[o+15] = POLLEN_OPACITY*fade*twinkle
			pollen_buffer[o+16] = moving.x; pollen_buffer[o+17] = moving.y; pollen_buffer[o+18] = moving.z; pollen_buffer[o+19] = 0.0
			continue
		var o := n_seed*20
		n_seed += 1
		buffer[o] = size; buffer[o+1] = 0.0; buffer[o+2] = 0.0; buffer[o+3] = world.x
		buffer[o+4] = 0.0; buffer[o+5] = size; buffer[o+6] = 0.0; buffer[o+7] = world.y
		buffer[o+8] = 0.0; buffer[o+9] = 0.0; buffer[o+10] = size; buffer[o+11] = world.z
		buffer[o+12] = COLOUR.r; buffer[o+13] = COLOUR.g; buffer[o+14] = COLOUR.b; buffer[o+15] = OPACITY*fade
		buffer[o+16] = moving.x; buffer[o+17] = moving.y; buffer[o+18] = moving.z; buffer[o+19] = _turn[i]+_age[i]*0.6
	_buffer = buffer
	_pollen_buffer = pollen_buffer
	if n_seed > 0:
		_node.multimesh.buffer = buffer
	_node.multimesh.visible_instance_count = n_seed
	if n_grain > 0:
		_pollen_node.multimesh.buffer = pollen_buffer
	_pollen_node.multimesh.visible_instance_count = n_grain

## The dandelion's seeds on the wing (not the pollen).
func seeds_in_air() -> int:
	var count := 0
	for i in range(_pos.size()):
		if _landed[i] < 0.0 and _kind[i].is_empty(): count += 1
	return count

## The grains of pollen on the wing.
func pollen_in_air() -> int:
	var count := 0
	for i in range(_pos.size()):
		if _landed[i] < 0.0 and not _kind[i].is_empty(): count += 1
	return count

# --- Taking root ------------------------------------------------------------------

## A seed (`kind` "") or a grain from a bloom of `kind` came down at `p`
## carrying `weight` seeds' chance.
func _settle(p: Vector2, weight: float, kind := "") -> void:
	if not spreading or weight <= 0.0 or _since_take < SPREAD_GAP: return
	if _rng.randf() >= (POLLEN_TAKE if not kind.is_empty() else TAKE)*weight: return
	take(p,kind)

## Tries to grow a new plant where a seed came down: a dandelion or a seed
## clock for a dandelion's seed (`parent` ""), else a plant of the `parent`
## bloom's own kind. Its id, or -1.
func take(p: Vector2, parent := "") -> int:
	if held.call(): return _refuse("held")
	if _flower_ids.size() >= MOST_FLOWERS: return _refuse("land full")
	if not _near_flowers(p): return _refuse("far or full")
	for stamp: Array in _cleared:
		if Emergence.time-float(stamp[1]) < CLEAR_HOLD and p.distance_to(stamp[0]) < CLEAR_REACH: return _refuse("thinned")
	if not _roomy(p): return _refuse("no room")
	var sowing := _the_sowing("dandelion" if parent.is_empty() else str(BLOOMS[parent].slot))
	if sowing == null: return _refuse("no sowing")
	sowing._survey(Rect2(p,Vector2.ZERO).grow(1.0))
	if not sowing.suits(p): return _refuse("ground")
	var key := [sowing.salt,8807,int(roundf(p.x*40.0)),int(roundf(p.y*40.0))]
	var kind := parent
	if parent.is_empty(): kind = "dandelion_clock" if Variety.unit(key+[1]) < CLOCK_SHARE else "dandelion"
	var record: Array = sowing.meadow.flower(kind,p,key)
	var id: int = data.place(record[0],p,record[4],record[1],record[3],record[2])
	if id < 0: return -1
	var item: Dictionary = data.objects.back()
	item["source"] = "emerged"
	item["born"] = Emergence.time+0.15
	data.objects_revision += 1
	_since_take = 0.0
	taken.append(id)
	_flower_ids[id] = p
	_flower_cells.get_or_add(_cell(p),[]).append(p)
	_room_cells.get_or_add(Vector2i((p/0.5).floor()),[]).append(p)
	if str(item.asset) in Flowers.CYCLE_KINDS:
		clocks[id] = _track(item,{})
		_clock_ids.append(id)
	elif BLOOMS.has(str(item.asset)): _add_bloom(item,str(item.asset))
	# The index already has it: the publish this brings need not read the land.
	_read_revision = data.objects_revision
	_read_count = data.objects.size()
	if view != null and view.has_method("paint_preview"): view.paint_preview([item])
	return id

func _refuse(why: String) -> int:
	refused[why] = int(refused.get(why,0))+1
	return -1

## A flower stands within CREEP, and fewer than CROWD within CROWD_REACH.
func _near_flowers(p: Vector2) -> bool:
	var near := false
	var crowd := 0
	var cell := _cell(p)
	for dz in range(-2,3):
		for dx in range(-2,3):
			for foot: Vector2 in _flower_cells.get(cell+Vector2i(dx,dz),[]):
				var d := p.distance_to(foot)
				if d < CREEP: near = true
				if d < CROWD_REACH: crowd += 1
	return near and crowd < CROWD

func _roomy(p: Vector2) -> bool:
	var cell := Vector2i((p/0.5).floor())
	for dz in range(-1,2):
		for dx in range(-1,2):
			for foot: Vector2 in _room_cells.get(cell+Vector2i(dx,dz),[]):
				if p.distance_to(foot) < ROOM: return false
	return true

## The sowing of `slot` (the ground's rules and the drift's sizes), made
## afresh every SOWING_FRESH seconds so it reads the live water as it is.
func _the_sowing(slot: String) -> RefCounted:
	if not sowing_for.is_valid(): return null
	var made: Array = _sowings.get(slot,[null,-INF])
	if made[0] == null or Emergence.time-float(made[1]) > SOWING_FRESH or Emergence.time < float(made[1]):
		made = [sowing_for.call(slot),Emergence.time]
		_sowings[slot] = made
	return made[0]
