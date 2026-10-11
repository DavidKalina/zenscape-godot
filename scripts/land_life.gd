extends Node3D
## Life answers the land (docs/scenic/life.md). Fish, frogspawn, frogs, birds
## and fireflies find their places in the world as it stands now, and arrive
## there in their own time; herons, deer and a rainbow come when a place has
## become rich (scripts/life_moments.gd).
##
## Nothing here is placed by the player. The editor tells us when the land,
## water or plants changed (`play_geometry_changed`, `stroke_finished`, and
## `state_restored` for undo, loads and new worlds); a LifeSurvey then re-reads
## the world across a few frames. Each kind of creature keeps a set of sites,
## keyed by survey cell: a site is born when its conditions first hold, and the
## creature arrives after the site's own delay, like plant emergence. A site
## whose conditions go away sends its creature off. Delays, positions and
## choices come from position hashes on emergence's world salt, so the same
## strokes on the same world bring the same life.
##
## Runs on blank worlds only (the Genesis plain and generated worlds): the
## Fidelity reference world keeps its authored birds, frogs and fireflies.

signal arrived(kind: String, position: Vector3)
signal moment(kind: String, position: Vector3)

const Plate = preload("res://scripts/plate.gd")
const Survey = preload("res://scripts/life_survey.gd")
const Models = preload("res://scripts/life_models.gd")
const Moments = preload("res://scripts/life_moments.gd")
const Snakes = preload("res://scripts/life_snakes.gd")
const Winter = preload("res://scripts/life_winter.gd")
const SmallLife = preload("res://scripts/life_small.gd")
const PondSeasons = preload("res://scripts/pond_seasons.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const BirdFlight = preload("res://studies/bird_flight.gd")
const Notice = preload("res://scripts/life_notice.gd")

## Seconds of quiet after a change before the world is re-read, and the
## shortest gap between surveys that no stroke asked for.
const SURVEY_QUIET := 0.6
const SURVEY_GAP := 4.0
## Seconds between arrival checks.
const TICK := 0.25
## Each kind: [delay, spread] seconds after its conditions first hold. A site's
## own delay is delay + spread × hash.
const DELAYS := {
	"fish":[10.0,16.0],
	"spawn":[22.0,26.0],
	"frog":[16.0,22.0],
	"bird":[6.0,24.0],
	"firefly":[12.0,22.0],
}
## A fresh world (new, regrown or loaded) is already settled: its sites start
## this share of the way through their delay.
const SETTLED_HEAD := 0.85
## Seconds a creature brought back from a save counts as already here, so it
## shows grown in rather than arriving again.
const RESUMED_AGE := 10.0
## Version of the saved life (`document`).
const DOCUMENT_VERSION := 1
## Fish: one per FISH_AREA m² of still water, deep cells only.
const FISH_AREA := 2.0
const FISH_BODY_MAX := 7
const FISH_MAX := 24
## Rare variants, rolled per creature from its site hash so a save brings them
## back: the odds that a koi in a koi pond is a golden koi, and that a frog is
## an albino or a blue one (albino first, so blue is the next slice of the roll).
const KOI_GOLDEN_CHANCE := 0.015
const FROG_ALBINO_CHANCE := 0.015
const FROG_BLUE_CHANCE := 0.01
## A golden koi is drawn this much brighter than the shade its fellows take.
const GOLDEN_GLOW := 1.14
const FISH_GAP := 0.9
## Frogspawn: shallow still edges, not in winter.
const SPAWN_BODY_MAX := 3
const SPAWN_MAX := 9
const SPAWN_GAP := 1.2
## Frogs sit on banks of water that already holds frogspawn.
const FROG_BODY_MAX := 2
const FROG_MAX := 6
const FROG_GAP := 1.6
## Birds: one per BIRD_SHORE shore cells, one per BIRD_TREES trees.
const BIRD_SHORE := 14
const BIRD_TREES := 10
const BIRD_MAX := 8
## Fireflies in damp undergrowth near water.
const FIREFLY_MAX := 64
const FIREFLY_GAP := 0.7
const FIREFLY_FADE := 3.0
## Seconds a creature takes to settle in or leave.
const SETTLE := 1.5
const LEAVE := 1.2
const RINGS := 12
## The pond's year for frogspawn, [spring, summer, autumn, winter].
const SPAWN_SEASON := [1.0, 0.7, 0.3, 0.0]
## Seconds a frog takes to turn round on its bank and face the water.
const FROG_TURN := 0.42
## Fish a water ball carried (`carry_fish`): life-clock seconds they wait for
## their pond to find them before they are gone, and the seconds each waits
## after its site opens, while the new pond finishes rising.
const CARRY_SECONDS := 30.0
const CARRY_DELAY := 2.0
## Carried fish settle in water this deep (m) when the pond they landed in
## has none as deep as the survey's DEEP, so a small ball's pond keeps them.
const CARRY_DEPTH := 0.1
## Prey (docs/scenic/life.md, "Predation"): a fish a heron catches or a frog a
## snake takes slips into the mouth over TAKE_TIME s and is gone, and its site
## waits PREY_RETURN [delay, spread] s before another arrives the usual way.
const TAKE_TIME := {"fish":0.14,"frog":0.3}
const PREY_RETURN := {"fish":[70.0,90.0],"frog":[90.0,120.0]}
## A fish drawn to a heron's feet (`lure`) that the strike misses darts back
## to its round over DART s.
const DART := 1.1

## Multiplies the life clock; probes run it fast.
var pace := 1.0
## --no-life turns the whole system off, for A/B timing.
var enabled := "--no-life" not in preload("res://scripts/launch_args.gd").user_args()
## --force-life[=deer,heron,snake]: each named creature (all three by default)
## comes as soon as the world has its place, skipping delay, chance and hour,
## and again FORCE_GAP s after it has gone, for looking at them in the game.
const FORCE_GAP := 8.0
var _force_kinds := _forced_kinds()
var _force_next := {}
var scene: Node3D
var editor: Node
var data: NativeTerrainData
## The last complete survey, and one still being read.
var survey: RefCounted
var _reading: RefCounted
## The worker reading `_reading`, polled each frame.
var _survey_job: RefCounted
var _dirty := true
var _urgent := true
var _quiet := 0.0
var _since_survey := 0.0
var _fresh := true
var _restored := false
var clock := 0.0
var active := false
var salt := 0
## kind -> {cell: site}
var sites := {"fish":{},"spawn":{},"frog":{},"bird":{},"firefly":{}}
## Arrivals so far by kind, and survey timings, for probes.
var arrivals := {}
## Creatures a loaded save brought back, by kind (not counted as arrivals).
var resumed := {}
## Creatures a heron or snake took, by kind.
var taken := {}
var surveys := 0
var last_usec := 0
var worst_usec := 0
## The last survey's main-thread parts, microseconds, for profiles.
var survey_parts := {}
## The longest survey over every survey so far (each runs whole on a worker).
var survey_worst_usec := 0
var moments: Node3D
var snakes: Node3D
## Ice on the ponds, the thaw after it, and dawn mist (scripts/life_winter.gd).
var winter: Winter
## Dragonflies, butterflies, a woodpecker and geese (scripts/life_small.gd).
var small: Node3D
## Creatures noticing the hand and the wanderer (scripts/life_notice.gd).
var notice: RefCounted
## Lilies on old ponds and autumn leaves on the water (scripts/pond_seasons.gd).
var seasons: Node3D
## Songbird flocks in the trees (scripts/songbirds.gd).
var songbirds: Node3D
var material: Material

var _tick := 0.0
## One batch per look, made when the first creature of that look arrives:
## fish by kind and markings ("kohaku 1"), frogs by kind, markings and pose
## ("toad 0 leap"). A kind's slots are shared, so each batch has room for all
## of them and shows only its own.
var _fish_looks := {}
var _spawn: MultiMeshInstance3D
var _frog_looks := {}
var _rings: MultiMeshInstance3D
var _ring_state: Array[Dictionary] = []
var _next_ring := 0
var _birds: RefCounted
var _bird_node: MultiMeshInstance3D
var _free := {}
var _firefly_source: Array = []
var _fireflies_owned := false
var _fading_flies := {}
var _rng := RandomNumberGenerator.new()
var _planning: Array = []
## A loaded world's life, kind -> {key: [delay, age, here]}, waiting for the
## first survey of the loaded ground to reopen its sites (`restore_document`).
var _resume := {}
## Fish a water ball let go (`carry_fish`): {"center", "looks", "until"}.
var _carried := {}
var _resume_used := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	data = editor.data
	name = "LandLife"
	var reference: Node3D = scene.get_node("Reference")
	var frog_source: MultiMeshInstance3D = reference.get_node("mesh-40")
	material = frog_source.multimesh.mesh.surface_get_material(0)
	_spawn = _batch("Frogspawn",Models.frogspawn(material),_capacity("spawn"),false)
	var ring_source: MultiMeshInstance3D = reference.get_node("mesh-39")
	_rings = _batch("Rings",ring_source.multimesh.mesh,RINGS,false,true)
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://shaders/reference_contact_ring.gdshader")
	_rings.material_override = ring_material
	for i in range(RINGS): _ring_state.append({"p":Vector3.ZERO,"age":100.0,"size":1.0})
	_setup_birds(reference)
	winter = Winter.new()
	add_child(winter)
	winter.setup(self)
	for kind in sites: _free[kind] = range(_capacity(kind)-1,-1,-1)
	var flies: MultiMesh = scene._fireflies.multimesh
	for i in range(flies.instance_count): _firefly_source.append([flies.get_instance_transform(i),flies.get_instance_custom_data(i)])
	moments = Moments.new()
	add_child(moments)
	moments.setup(self)
	snakes = Snakes.new()
	add_child(snakes)
	snakes.setup(self)
	small = SmallLife.new()
	add_child(small)
	small.setup(self)
	notice = Notice.new(self)
	seasons = PondSeasons.new()
	add_child(seasons)
	seasons.setup(self)
	songbirds = preload("res://scripts/songbirds.gd").new()
	add_child(songbirds)
	songbirds.setup(self)
	editor.play_geometry_changed.connect(_changed)
	editor.stroke_finished.connect(func(_center: Vector3, _radius: float, _mode: String) -> void: _changed(true))
	# A pour lands after its stroke has finished, once it settles on a worker.
	editor.water_settled.connect(func(_bounds: Rect2) -> void: _changed(true))
	data.state_restored.connect(_world_restored)
	_world_restored({})

func _batch(label: String, mesh: Mesh, count: int, colors: bool, custom := false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = colors
	instances.use_custom_data = custom
	instances.instance_count = count
	instances.mesh = mesh
	# Creatures wander; one generous box keeps the batch from culling itself.
	instances.custom_aabb = AABB(Vector3(-(Plate.HALF+2.0),NativeTerrainData.MIN_HEIGHT-1.0,-(Plate.HALF+2.0)),Vector3(Plate.SIZE+4.0,45,Plate.SIZE+4.0))
	for i in range(count): instances.set_instance_transform(i,_hidden())
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

## The batch for `look`, built by `build` the first time it is asked for. It
## draws only up to the highest slot it has shown (`_show_slot`); slots are
## handed out lowest first, so that stays near the number of live creatures.
func _look(looks: Dictionary, look: String, capacity: int, build: Callable) -> MultiMesh:
	if not looks.has(look):
		looks[look] = _batch(look.replace(" ","-"),build.call(),capacity,true)
		(looks[look] as MultiMeshInstance3D).multimesh.visible_instance_count = 0
	return (looks[look] as MultiMeshInstance3D).multimesh

static func _show_slot(batch: MultiMesh, slot: int) -> void:
	batch.visible_instance_count = maxi(batch.visible_instance_count,slot+1)

static func _hidden() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE*0.00001),Vector3(0,-50,0))

## The Fidelity gulls, flown by the same thermal model, but over columns this
## world's shores and hills raise, and only once they have arrived.
func _setup_birds(reference: Node3D) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/bird-flight.json"))
	var mesh: Mesh = (reference.get_node(str(source.mesh)) as MultiMeshInstance3D).multimesh.mesh
	_bird_node = MultiMeshInstance3D.new()
	_bird_node.name = "Birds"
	_bird_node.multimesh = MultiMesh.new()
	_bird_node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_bird_node.multimesh.use_colors = true
	_bird_node.multimesh.mesh = mesh
	_bird_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bird_node)
	var flock: Array = source.birds.slice(0,BIRD_MAX)
	# Every gull starts away: `setup` publishes each at its `out`, and the
	# source file has them all out, which left the flock hanging at the
	# Fidelity positions until a site first flew them.
	for bird: Dictionary in flock:
		bird.delay = 5.0
		bird.col = 0
		bird.out = 0.0
	var columns := []
	for i in range(3): columns.append({"x":0.0,"z":0.0,"base":0.0,"top":10.0,"r":3.6,"lift":2.1})
	_birds = BirdFlight.new()
	_birds.setup(_bird_node.multimesh,data,{"birds":flock,"cols":columns,"species":source.species})

func _capacity(kind: String) -> int:
	return {"fish":FISH_MAX,"spawn":SPAWN_MAX+Winter.THAW_SPAWN_MAX,"frog":FROG_MAX,"bird":BIRD_MAX,"firefly":FIREFLY_MAX}[kind]

## `urgent` for a finished stroke, undo or new world: re-read as soon as the
## editor settles. Plain geometry changes (emergence steps) wait SURVEY_GAP.
func _changed(urgent := false) -> void:
	_dirty = true
	_quiet = 0.0
	if urgent: _urgent = true

## Undo, loads and new worlds. A new or loaded world starts settled; an undo
## keeps whatever still fits. A survey of the old ground is dropped. A load
## whose save kept its life then hands it over through `restore_document`, and
## resumes instead of settling.
func _world_restored(state: Dictionary) -> void:
	if state.is_empty():
		clear()
		_fresh = true
	else:
		_restored = true
	_reading = null
	_changed(true)

## Send every creature away at once (a new world).
func clear() -> void:
	for kind in sites:
		for key in sites[kind].keys(): _release(kind,sites[kind][key])
		sites[kind].clear()
	if moments != null: moments.clear()
	if snakes != null: snakes.clear()
	if winter != null: winter.clear()
	if small != null: small.clear()
	if notice != null: notice.clear()
	if seasons != null: seasons.clear()
	if songbirds != null: songbirds.clear()
	_reading = null
	_planning.clear()
	survey = null
	_resume.clear()
	_resume_used = false
	_carried = {}

# --- Saving -------------------------------------------------------------------

## What has arrived where and how far along the rest are, for the place's save
## (NativeGardenStore). Empty when life is not running on this world. Each
## kind lists [key, delay, age, here]: the survey cell (a bird's slot), its own
## delay, the life-clock seconds since its conditions first held, and whether
## its creature had arrived. Moments are not saved; they come round again.
## Saves from before Bigfoot went may carry his trail's "trail": ignored.
func document() -> Dictionary:
	if not active: return {}
	var saved := {}
	for kind: String in sites:
		var rows := []
		for key: int in sites[kind]:
			var site: Dictionary = sites[kind][key]
			if site.leaving or site.get("closing",false): continue
			# One being taken is already gone, waiting for its return.
			rows.append([key,snappedf(float(site.delay),0.001),snappedf(maxf(clock-float(site.since),0.0),0.001),bool(site.here) and not site.has("taken")])
		saved[kind] = rows
	var result := {"version":DOCUMENT_VERSION,"clock":clock,"sites":saved,"ponds":seasons.document()}
	return result

static func valid_document(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.get("version") != float(DOCUMENT_VERSION) and value.get("version") != DOCUMENT_VERSION: return false
	if not GardenData._number(value.get("clock"),0.0,1e9) or not value.get("sites") is Dictionary: return false
	for kind: Variant in value.sites:
		if not DELAYS.has(kind) or not value.sites[kind] is Array or value.sites[kind].size() > 64: return false
		for row: Variant in value.sites[kind]:
			if not row is Array or row.size() != 4 or not GardenData._integer(row[0]) or int(row[0]) < 0 or int(row[0]) >= Survey.SIDE*Survey.SIDE: return false
			if not GardenData._number(row[1],0.0,1e6) or not GardenData._number(row[2],0.0,1e9) or not row[3] is bool: return false
	# Pond ages (PondSeasons), optional: saves from before them have none.
	return not value.has("ponds") or PondSeasons.valid_document(value.ponds)

## Reopen a saved world's life: the clock at least where it stood, and every saved site
## waiting for the first survey of the loaded ground, which keeps the ones whose
## conditions still hold. An empty document (a save from before life was kept,
## or a world without life) starts the world settled, as loads always have.
## Only loads and restored scenes call this, so the old world's life goes.
func restore_document(value: Dictionary) -> void:
	clear()
	_restored = true
	_changed(true)
	if value.is_empty() or not valid_document(value):
		_fresh = true
		return
	# Sites carry their own ages, so the clock only has to not run backwards:
	# moments keep cooldowns on it within a session.
	clock = maxf(clock,float(value.clock))
	for kind: String in value.sites:
		var rows := {}
		for row: Array in value.sites[kind]: rows[int(row[0])] = [float(row[1]),float(row[2]),bool(row[3])]
		_resume[kind] = rows
	seasons.restore(value.get("ponds",[]))
	_fresh = false

func _process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	var blank: bool = enabled and data.blank
	if blank != active: _set_active(blank)
	if not active: return
	var shown: bool = scene._growth.terrain >= 0.995
	visible = shown
	var paused: bool = scene._paused or not shown
	var step := 0.0 if paused else minf(delta,0.1)*pace
	clock += step
	_survey(delta)
	winter.advance(minf(delta,0.1))
	if step > 0.0:
		_tick += step
		if _tick >= TICK:
			_tick = 0.0
			_arrive_due()
		notice.advance(step)
		_animate(step)
		moments.advance(step,minf(delta,0.1))
		snakes.advance(step)
		small.advance(step)
		seasons.advance(step)
		if not _force_kinds.is_empty(): _force_due()
	songbirds.advance(step,minf(delta,0.1))
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

func _set_active(value: bool) -> void:
	active = value
	visible = value
	if value:
		_own_fireflies()
		_changed(true)
	else:
		clear()
		_restore_fireflies()

func _survey(delta: float) -> void:
	_quiet += delta
	_since_survey += delta
	# A survey in progress finishes first; a change meanwhile starts the next.
	# Emergence refreshes every step while plants arrive, so between strokes
	# the world is re-read at most every SURVEY_GAP seconds.
	var due := _urgent or _since_survey >= SURVEY_GAP
	if _dirty and due and _reading == null and _survey_job == null and _quiet >= SURVEY_QUIET and not editor._painting and not editor.water_settling and editor.refresh_pending == 0 and not editor.forming:
		_dirty = false
		_urgent = false
		_since_survey = 0.0
		# Saved life reopens on the first survey of the loaded ground only.
		if _resume_used:
			_resume.clear()
			_resume_used = false
		if _restored and data._undo.is_empty() and data._redo.is_empty(): _fresh = _resume.is_empty()
		_restored = false
		salt = int(editor.emergence.salt)
		var began := Time.get_ticks_usec()
		var still: Variant = editor.still_water_triangles()
		survey_parts.still = Time.get_ticks_usec()-began
		began = Time.get_ticks_usec()
		# The survey reads a private copy of what it needs (heights, cover,
		# records, streams) and runs whole on a worker; the world keeps
		# moving meanwhile, and the next change starts the next read.
		var ground := preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
		ground.grass = data.grass.duplicate()
		ground.objects.assign(data.objects.duplicate(true))
		ground.streams.assign(data.streams.duplicate(true))
		var reading: RefCounted = Survey.new(ground,still)
		_reading = reading
		_survey_job = preload("res://scripts/background_work.gd").new()
		_survey_job.start(func() -> RefCounted:
			while not reading.step(1 << 30): pass
			return reading)
		survey_parts.new = Time.get_ticks_usec()-began
		global_transform = editor.terrain.global_transform
	if _survey_job != null and _survey_job.completed():
		var finished: RefCounted = _survey_job.finish()
		_survey_job = null
		# A reset meanwhile (new world, undo) dropped the read it started.
		if finished != _reading: return
		survey_worst_usec = maxi(survey_worst_usec,_reading.worst_step_usec)
		survey = _reading
		_reading = null
		surveys += 1
		var seasons_began := Time.get_ticks_usec()
		seasons.surveyed(survey,_fresh)
		survey_parts.seasons = Time.get_ticks_usec()-seasons_began
		_rng.seed = Variety.mix([salt,surveys])
		_planning = ["fish","spawn","frog","bird","firefly"]
		return
	# One kind a frame, so a finished survey never lands in a single frame.
	if not _planning.is_empty():
		var began := Time.get_ticks_usec()
		var kind: String = _planning.pop_front()
		call("_plan_"+kind)
		survey_parts["plan_"+kind] = Time.get_ticks_usec()-began
		if _planning.is_empty():
			_fresh = false
			_resume_used = not _resume.is_empty()

# --- Sites ---------------------------------------------------------------

func _plan_fish() -> void:
	var wanted := {}
	var landing := _carried_body()
	for record: Dictionary in survey.bodies:
		var deep: PackedInt32Array = record.deep
		# A small ball's pond may hold no deep water; its own fish still stay.
		if deep.is_empty() and record.id == landing:
			deep = PackedInt32Array(Array(record.cells).filter(func(cell: int) -> bool: return survey.depth(cell) >= CARRY_DEPTH))
		if deep.is_empty(): continue
		var cap := clampi(int(record.area/FISH_AREA),1,FISH_BODY_MAX)
		for cell in _choose("fish",deep,cap,FISH_GAP):
			wanted[cell] = {"body":record.id,"level":record.level,"pond":record.cells[0]}
	_reconcile("fish",wanted,FISH_MAX)
	_claim_carried()

## A water ball's fish (scripts/water_ball.gd), let go into the pond it made
## around `center`: the new fish sites nearest it take them, in the ball's
## own kinds and markings, and come in CARRY_DELAY s later instead of after
## their own delay. `looks` are [{"kind", "seed", "mirror"}]. Fish no new site
## takes within CARRY_SECONDS are gone, as are those beyond the pond's room.
func carry_fish(center: Vector2, looks: Array) -> void:
	if not active or looks.is_empty(): return
	_carried = {"center":center,"looks":looks.duplicate(),"until":clock+CARRY_SECONDS}
	_changed(true)

## The id of the pond body a carried school landed nearest, or -1. Puddles
## (no wading cells) do not count.
func _carried_body() -> int:
	if _carried.is_empty() or survey == null: return -1
	var center: Vector2 = _carried.center
	var found := -1
	var nearest := INF
	for record: Dictionary in survey.bodies:
		if record.wade.is_empty(): continue
		var reach: float = (record.center as Vector2).distance_to(center)
		if reach < nearest:
			nearest = reach
			found = record.id
	return found

func _claim_carried() -> void:
	if _carried.is_empty(): return
	if clock > float(_carried.until):
		_carried = {}
		return
	var center: Vector2 = _carried.center
	var open: Array = sites.fish.values().filter(func(site: Dictionary) -> bool: return not site.here and not site.has("carried") and not site.get("settled",false))
	open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Survey.center(a.cell).distance_to(center) < Survey.center(b.cell).distance_to(center))
	for site: Dictionary in open:
		if _carried.looks.is_empty(): break
		site.carried = _carried.looks.pop_front()
		site.delay = CARRY_DELAY
		site.since = clock
	if _carried.looks.is_empty(): _carried = {}

func _plan_spawn() -> void:
	var wanted := {}
	# None under ice, and a burst in the thaw after it.
	if WorldClock.season_factor(_season(),SPAWN_SEASON) > 0.05 and not winter.frozen():
		for record: Dictionary in survey.bodies:
			if record.shallow.is_empty(): continue
			var cap := clampi(1+int(record.area/10.0),1,SPAWN_BODY_MAX)+winter.extra_spawn()
			for cell in _choose("spawn",record.shallow,cap,SPAWN_GAP):
				wanted[cell] = {"body":record.id,"level":record.level}
	_reconcile("spawn",wanted,SPAWN_MAX+winter.extra_spawn_total())

## Frogs come to banks of water that already holds frogspawn. Where the spawn
## came with a settled world, so do the frogs.
func _plan_frog() -> void:
	if survey == null: return
	var spawning := {}
	for site: Dictionary in sites.spawn.values():
		if site.here and not site.leaving:
			var id: int = survey.body[site.cell]
			spawning[id] = spawning.get(id,false) or site.settled
	var wanted := {}
	for record: Dictionary in survey.bodies:
		if not spawning.has(record.id): continue
		# Every bank cell touches this body; the leap lands in its nearest water.
		for cell in _choose("frog",record.shore,FROG_BODY_MAX,FROG_GAP):
			var water: int = survey.water_near(Survey.center(cell),record.id,1.0,Survey.WADE_MAX)
			if water < 0: water = survey.water_near(Survey.center(cell),record.id,1.0,INF)
			wanted[cell] = {"body":record.id,"level":record.level,"water":water,"settled":spawning[record.id],"pond":record.cells[0]}
	_reconcile("frog",wanted,FROG_MAX)

## Birds come to shores and woods. Their thermals rise over the biggest waters
## and the highest ground.
func _plan_bird() -> void:
	var shore_cells: int = survey.shore.size()
	var count := mini(BIRD_MAX,shore_cells/BIRD_SHORE+int(survey.tree_count/BIRD_TREES)+(1 if survey.stream_cells > 12 else 0))
	var anchors: Array[Vector2] = []
	var by_size: Array = survey.bodies.filter(func(record: Dictionary) -> bool: return record.area >= Survey.MIN_BODY_AREA)
	by_size.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area > b.area)
	for record in by_size.slice(0,2): anchors.append(record.center)
	var peak := -INF
	var summit := Vector2.ZERO
	for index in range(0,Survey.SIDE*Survey.SIDE,3):
		if not is_nan(survey.height[index]) and survey.height[index] > peak:
			peak = survey.height[index]
			summit = Survey.center(index)
	anchors.append(summit)
	while anchors.size() < 3: anchors.append(anchors[0].rotated(2.1*anchors.size())*0.6)
	for i in range(3):
		var column: Dictionary = _birds.columns[i]
		var ground: float = survey.ground_at(anchors[i])
		column.x = clampf(anchors[i].x,-(Plate.HALF-3.0),Plate.HALF-3.0)
		column.z = clampf(anchors[i].y,-(Plate.HALF-3.0),Plate.HALF-3.0)
		column.top = (ground if not is_nan(ground) else 0.0)+9.0+2.0*i
		column.base = column.top-8.0
	# Birds are not tied to one cell; their sites are slots 0..count-1.
	var wanted := {}
	for i in range(count): wanted[i] = {"column":i%3}
	_reconcile("bird",wanted,BIRD_MAX)

func _plan_firefly() -> void:
	var wanted := {}
	for cell in _choose("firefly",survey.damp,FIREFLY_MAX,FIREFLY_GAP): wanted[cell] = {}
	_reconcile("firefly",wanted,FIREFLY_MAX)

## Up to `cap` cells of `cells`: sites that already stand and still qualify
## first, then new cells in hash order, at least `gap` metres apart.
func _choose(kind: String, cells: PackedInt32Array, cap: int, gap: float) -> Array[int]:
	var chosen: Array[int] = []
	var points: Array[Vector2] = []
	var existing: Dictionary = sites[kind]
	var qualified := {}
	for cell in cells: qualified[cell] = true
	for cell: int in existing:
		if chosen.size() >= cap: break
		if qualified.has(cell):
			chosen.append(cell)
			points.append(Survey.center(cell))
	# Then a loaded world's saved sites, which may have come from another salt.
	for cell: int in _resume.get(kind,{}):
		if chosen.size() >= cap: break
		if qualified.has(cell) and not existing.has(cell):
			chosen.append(cell)
			points.append(Survey.center(cell))
	# Hash order through one native sort: the rank in the high bits, the cell
	# (under 4096) in the low twelve.
	var key := Variety.mix([salt,kind.hash()])
	var ranked := PackedInt64Array()
	ranked.resize(cells.size())
	for i in range(cells.size()):
		var h := (cells[i]*0x9E3779B1+key) & 0xFFFFFFFF
		h = (((h >> 15) ^ h)*0x2C1B3C6D) & 0xFFFFFFFF
		h = (((h >> 12) ^ h)*0x297A2D39) & 0xFFFFFFFF
		ranked[i] = (((h >> 15) ^ h) << 12) | cells[i]
	ranked.sort()
	for entry in ranked:
		var cell := int(entry & 0xFFF)
		if chosen.size() >= cap: break
		if existing.has(cell): continue
		var p := Survey.center(cell)
		var spaced := true
		for other in points:
			if p.distance_squared_to(other) < gap*gap:
				spaced = false
				break
		if not spaced: continue
		chosen.append(cell)
		points.append(p)
	return chosen

## Keep sites that are still wanted, send off the rest, and open new ones.
func _reconcile(kind: String, wanted: Dictionary, cap: int) -> void:
	var current: Dictionary = sites[kind]
	for cell: int in current.keys():
		if wanted.has(cell): continue
		_depart(kind,current[cell])
	for cell: int in wanted:
		if current.has(cell):
			current[cell].merge(wanted[cell],true)
			# A settled clump follows its water's new level.
			if current[cell].has("shown"): current[cell].shown = -1.0
			continue
		if current.size() >= cap: break
		var timing: Array = DELAYS[kind]
		var delay: float = (timing[0]+timing[1]*Variety.unit([salt,kind.hash(),cell,7]))*winter.haste(kind)
		var site := {"cell":cell,"kind":kind,"delay":delay,"here":false,"leaving":false,"slot":-1,"settled":_fresh}
		site.merge(wanted[cell],true)
		site.since = clock-(delay*SETTLED_HEAD if site.settled else 0.0)
		# A saved site picks up where it was: its own delay and age, and one
		# that had arrived comes back at once, already settled in.
		var saved: Array = _resume.get(kind,{}).get(cell,[])
		if not saved.is_empty():
			site.delay = float(saved[0])
			site.since = clock-(maxf(float(saved[1]),float(saved[0])) if saved[2] else float(saved[1]))
			site.resumed = bool(saved[2])
		current[cell] = site
	# Sites that have not arrived yet simply close; arrived ones leave.
	for cell: int in current.keys():
		var site: Dictionary = current[cell]
		if site.get("closing",false): current.erase(cell)

func _depart(kind: String, site: Dictionary) -> void:
	if not site.here:
		site.closing = true
		return
	if site.has("taken"):
		_release(kind,site)
		site.closing = true
		return
	if site.leaving: return
	site.leaving = true
	site.left = clock
	if kind == "frog":
		if winter.burrow_on_leave(site): return
		var away: Vector3 = site.home+(site.home-site.landing).normalized()*1.2
		away.y = site.home.y
		_hop(site,away,"away")
	elif kind == "bird":
		_birds.birds[site.slot].delay = 0.75

func _arrive_due() -> void:
	var spawn_changed := false
	for kind in sites:
		for site: Dictionary in sites[kind].values():
			if site.here or clock-float(site.since) < float(site.delay): continue
			if _free[kind].is_empty(): continue
			site.slot = _free[kind].pop_back()
			site.here = true
			site.born = clock
			if site.get("resumed",false):
				# Back from a save: already grown in, and a frog already on its bank.
				site.resumed = false
				site.born = clock-RESUMED_AGE
				call("_arrive_"+kind,site)
				if kind == "frog":
					site.p = site.home
					site.mode = "sit"
					site.yaw = _facing_water(site)
				resumed[kind] = int(resumed.get(kind,0))+1
				if kind == "spawn": spawn_changed = true
				continue
			call("_arrive_"+kind,site)
			arrivals[kind] = int(arrivals.get(kind,0))+1
			arrived.emit(kind,to_global(site.get("p",Vector3.ZERO)))
			if kind == "spawn": spawn_changed = true
	if spawn_changed: _plan_frog()

## Return a site's slot and hide what it showed.
func _release(kind: String, site: Dictionary) -> void:
	if not site.here or site.slot < 0: return
	match kind:
		"fish":
			for look: MultiMeshInstance3D in _fish_looks.values(): look.multimesh.set_instance_transform(site.slot,_hidden())
		"spawn": _spawn.multimesh.set_instance_transform(site.slot,_hidden())
		"frog":
			for look: MultiMeshInstance3D in _frog_looks.values(): look.multimesh.set_instance_transform(site.slot,_hidden())
		"bird": _birds.birds[site.slot].delay = 5.0
		"firefly": _fly_presence(site.slot,0.0)
	_free[kind].append(site.slot)
	site.here = false
	site.slot = -1

func _hash(site: Dictionary, tag: int) -> float:
	return Variety.unit([salt,str(site.kind).hash(),site.cell,tag])

## The same for every site of one kind on one pond, so a pond keeps one
## company of fish and one of frogs.
func _pond_hash(site: Dictionary) -> float:
	return Variety.unit([salt,str(site.kind).hash(),int(site.get("pond",site.cell)),11])

## One of a company's kinds, by its weights ([[kind, weight], ...]).
static func _pick(company: Array, roll: float) -> String:
	return company[Variety.weighted(company.map(func(entry: Array) -> float: return entry[1]),roll)][0]

# --- Arrivals ---------------------------------------------------------------

func _arrive_fish(site: Dictionary) -> void:
	var c := Survey.center(site.cell)
	site.phase = _hash(site,1)*TAU
	site.speed = lerpf(0.45,0.8,_hash(site,2))
	site.size = lerpf(0.85,1.15,_hash(site,3))
	site.rise = clock+lerpf(8.0,24.0,_hash(site,4))
	# A pond is a koi pond or a wild one (Models.FISH_PONDS); each fish is one
	# of its kinds, a patterned kind in one of its markings, and half of them
	# wear those markings mirrored.
	var company: Array = Models.FISH_PONDS[int(_pond_hash(site)*Models.FISH_PONDS.size())]
	var kind := _pick(company,_hash(site,5))
	var seed := int(_hash(site,6)*float(Models.FISH_KINDS[kind].get("seeds",1)))
	site.mirror = _hash(site,8) < 0.5
	if company == Models.FISH_PONDS[0] and _hash(site,21) < KOI_GOLDEN_CHANCE:
		kind = "golden"
		seed = 0
	# A fish a water ball carried keeps the look it swam in with.
	var carried: Dictionary = site.get("carried",{})
	if not carried.is_empty():
		kind = carried.kind
		seed = int(carried.seed)
		site.mirror = bool(carried.mirror)
	site.look = "%s %d" % [kind,seed]
	site.title = Models.FISH_KINDS[kind].title
	# Just under the surface, the dorsal fin clear of it.
	site.sink = maxf(0.07,Models.fish_top(kind)*float(site.size)+0.015)
	site.home = Vector3(c.x,float(site.level)-float(site.sink),c.y)
	site.p = site.home
	var shade := lerpf(0.93,1.05,_hash(site,9))*(GOLDEN_GLOW if kind == "golden" else 1.0)
	var batch := _look(_fish_looks,site.look,FISH_MAX,func() -> Mesh: return Models.fish(material,kind,seed))
	var node: MultiMeshInstance3D = _fish_looks[site.look]
	if node.material_override == null:
		# Its own copy of the shared material, with the tail beat on: same
		# shader, so nothing new to compile.
		var swim: ShaderMaterial = material.duplicate()
		swim.set_shader_parameter("fish_swim",true)
		swim.set_shader_parameter("fish_wave",Models.fish_wave(kind))
		node.material_override = swim
	site.shade = shade
	batch.set_instance_color(site.slot,Color(shade,shade,shade))
	_show_slot(batch,site.slot)

func _arrive_spawn(site: Dictionary) -> void:
	var c := Survey.center(site.cell)+Vector2(_hash(site,1)-0.5,_hash(site,2)-0.5)*0.2
	site.p = Vector3(c.x,float(site.level)-0.012,c.y)
	site.angle = _hash(site,3)*TAU
	site.size = lerpf(0.85,1.3,_hash(site,4))
	site.shown = -1.0

func _arrive_frog(site: Dictionary) -> void:
	var c := Survey.center(site.cell)
	var ground: Variant = data.ground_height(c)
	site.home = Vector3(c.x,(float(ground) if ground != null else 0.0)+0.02,c.y)
	var landing := Survey.center(int(site.water)) if int(site.water) >= 0 else c
	site.landing = Vector3(landing.x,float(site.level)-0.02,landing.y)
	# The pond's frogs are mostly one kind (Models.FROG_PONDS).
	var company: Array = Models.FROG_PONDS[int(_pond_hash(site)*Models.FROG_PONDS.size())]
	var kind := _pick(company,_hash(site,4))
	var roll := _hash(site,22)
	if roll < FROG_ALBINO_CHANCE: kind = "albino"
	elif roll < FROG_ALBINO_CHANCE+FROG_BLUE_CHANCE: kind = "blue"
	site.species = kind
	site.look = "%s %d" % [kind,int(_hash(site,5)*2.0)]
	site.title = Models.FROG_KINDS[kind].title
	site.size = float(Models.FROG_KINDS[kind].size)*lerpf(1.0,1.3,_hash(site,1))
	# A toad's hops are short and low.
	site.spring = 0.6 if kind == "toad" else 1.0
	site.shown_pose = ""
	var shade := lerpf(0.93,1.05,_hash(site,6))
	for pose in ["sit","leap"]:
		var batch := _frog_pose(site,pose)
		batch.set_instance_color(site.slot,Color(shade,shade,shade))
		_show_slot(batch,site.slot)
	site.phase = _hash(site,2)*TAU
	# Hops in from further up the bank.
	var away: Vector3 = site.home+(site.home-site.landing).normalized()*1.1
	away.y = site.home.y
	site.p = away
	site.yaw = 0.0
	site.wait = 4.0+_hash(site,3)*6.0
	_hop(site,site.home,"out")
	winter.emerge_on_arrival(site)

func _arrive_bird(site: Dictionary) -> void:
	var bird: Dictionary = _birds.birds[site.slot]
	var angle := _rng.randf()*TAU
	var entry := Vector2.from_angle(angle)*17.0
	var column: Dictionary = _birds.columns[int(site.column)]
	bird.x = entry.x
	bird.z = entry.y
	bird.y = float(column.top)+2.0
	var inward := -entry.normalized()*float(bird.speed)
	bird.vx = inward.x
	bird.vz = inward.y
	bird.vy = 0.0
	bird.col = int(site.column)
	bird.mode = "cross"
	bird.timer = 6.0
	bird.yaw = atan2(inward.x,inward.y)
	bird.delay = -1.0
	site.p = Vector3(bird.x,bird.y,bird.z)

func _arrive_firefly(site: Dictionary) -> void:
	var c := Survey.center(site.cell)+Vector2(_hash(site,1)-0.5,_hash(site,2)-0.5)*0.4
	var ground: float = survey.ground_at(c)
	site.p = Vector3(c.x,(ground if not is_nan(ground) else 0.0)+0.35+0.75*_hash(site,3),c.y)
	var flies: MultiMesh = scene._fireflies.multimesh
	flies.set_instance_transform(site.slot,Transform3D(Basis.IDENTITY,to_global(site.p)))
	var source: Color = _firefly_source[site.slot][1]
	flies.set_instance_custom_data(site.slot,Color(source.r,source.g,source.b,1.0))
	_fading_flies[site.slot] = site

# --- Motion -----------------------------------------------------------------

func _animate(step: float) -> void:
	for kind in ["fish","spawn","frog"]:
		for cell: int in sites[kind].keys():
			var site: Dictionary = sites[kind][cell]
			if not site.here: continue
			if site.has("taken"):
				_move_taken(kind,site)
				continue
			var fade := 1.0
			if site.leaving:
				fade = 1.0-clampf((clock-float(site.left))/LEAVE,0.0,1.0)
				if fade <= 0.0 and (kind != "frog" or site.mode == "sit"):
					_release(kind,site)
					sites[kind].erase(cell)
					continue
			call("_move_"+kind,site,step,fade)
	for cell: int in sites.bird.keys():
		var site: Dictionary = sites.bird[cell]
		if not site.here or not site.leaving: continue
		var bird: Dictionary = _birds.birds[site.slot]
		bird.delay = float(bird.delay)+step*0.15
		if bird.delay >= 1.05:
			_release("bird",site)
			sites.bird.erase(cell)
	# Fly on while any gull still shows, not only while a site holds one: a
	# gull released at once (a new world) is hidden on the next step, instead
	# of freezing mid-wingbeat where it was.
	if not sites.bird.is_empty() or _birds_out():
		var air: Node3D = scene._atmosphere
		_birds.advance(step,false,air._air_strength,Vector2(cos(air._air_angle),sin(air._air_angle)))
	_fade_fireflies()
	_move_rings(step)

func _birds_out() -> bool:
	for bird: Dictionary in _birds.birds:
		if float(bird.out) > 0.001: return true
	return false

func _move_fish(site: Dictionary, step: float, fade: float) -> void:
	var grow := smoothstep(0.0,SETTLE,clock-float(site.born))*fade
	# Swim time runs on, so the pace can change (ice, a thaw) without a jump.
	site.swim = float(site.get("swim",clock*float(site.speed)))+step*float(site.speed)*winter.fish_pace()
	var t: float = float(site.swim)+float(site.phase)
	# `hush`, `nudge` and `steer` are a startled or curious fish's (life_notice.gd).
	var reach := 0.35*(1.0-float(site.get("hush",0.0)))
	var candidate: Vector3 = site.home+Vector3(sin(t)*reach,0,cos(t*0.83)*reach)+Vector3(site.get("nudge",Vector3.ZERO))
	if survey.wet_at(Vector2(candidate.x,candidate.z)): site.p = candidate
	var heading := Vector2(cos(t)*reach,-0.83*sin(t*0.83)*reach)
	var yaw := atan2(heading.x,heading.y)+sin(clock*9.0+float(site.phase))*0.03
	if site.has("steer"): yaw = lerp_angle(yaw,float(site.steer.x),float(site.steer.y))
	var p: Vector3 = site.p
	p.y = float(site.level)-float(site.sink)-winter.fish_sink(site)-(1.0-grow)*0.3
	if site.has("lure"):
		var drawn := _lured(site,p,yaw)
		p = drawn[0]
		yaw = drawn[1]
	site.shown_p = p
	site.shown_yaw = yaw
	var scale := maxf(float(site.size)*grow,0.00001)
	var basis := Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(-scale if site.mirror else scale,scale,scale))
	var batch: MultiMesh = _fish_looks[site.look].multimesh
	batch.set_instance_transform(site.slot,Transform3D(basis,p))
	winter.shade_fish(site,batch)
	# Now and then a fish rises and leaves a ring, most often in low light,
	# never through ice, and often in a thaw.
	if clock >= float(site.rise) and not site.leaving:
		site.rise = clock+lerpf(10.0,28.0,fposmod(float(site.rise)*0.618,1.0))*(0.6 if _daylight() < 0.6 else 1.0)*winter.rise_wait()
		if winter.rises(): ripple(Vector3(p.x,float(site.level),p.z),0.45)

## A fish drawn in to a heron's feet (LifeMoments): it glides from its round
## to `lure.to` by `lure.at`, noses there with a small drift, and if the strike
## misses (`lure.dart`) darts back to its round. [where it shows, its yaw].
func _lured(site: Dictionary, p: Vector3, yaw: float) -> Array:
	var lure: Dictionary = site.lure
	var to := Vector3(lure.to.x,p.y,lure.to.z)
	var toward := atan2(to.x-p.x,to.z-p.z)
	var w := 0.0
	if float(lure.dart) < 0.0:
		w = smoothstep(float(lure.from),float(lure.at),clock)
		to += Vector3(sin(clock*1.3+float(site.phase)),0.0,cos(clock*1.1+float(site.phase)))*0.035*w
	else:
		var u := (clock-float(lure.dart))/DART
		if u >= 1.0:
			site.erase("lure")
			return [p,yaw]
		# Off at once, slowing as it goes.
		w = pow(1.0-u,3.0)
		toward += PI
	var drawn := p.lerp(to,w)
	return [Vector3(drawn.x,p.y,drawn.z),lerp_angle(yaw,toward,smoothstep(0.0,0.25,w) if float(lure.dart) < 0.0 else smoothstep(0.0,0.3,w))]

func _move_spawn(site: Dictionary, _step: float, fade: float) -> void:
	var grow := smoothstep(0.0,3.0,clock-float(site.born))*fade
	if grow == site.shown: return
	site.shown = grow
	site.p.y = float(site.level)-0.012
	var scale := float(site.size)*lerpf(0.3,1.0,grow) if grow > 0.0 else 0.00001
	_spawn.multimesh.set_instance_transform(site.slot,Transform3D(Basis(Vector3.UP,float(site.angle)).scaled(Vector3(scale,scale,scale)),site.p))

## The Fidelity pond loop: sit on the bank, leap into checked water, paddle,
## hop back to the same bank (studies/frog_motion.gd). A frog sits in its
## sitting pose and flies in its leaping one, legs thrown out behind, from just
## after it pushes off until just before it lands; it swims in the leaping pose
## too, low in the water with its eyes and back above it. Back on the bank it
## turns round to face the water, as frogs sit.
func _move_frog(site: Dictionary, step: float, fade: float) -> void:
	site.age = float(site.age)+step
	var size := float(site.size)
	var pose := "sit"
	var pitch := 0.0
	var squash := Vector3.ONE
	match site.mode:
		"sit":
			site.wait = float(site.wait)-step
			# Stalked, it keeps still (life_snakes.gd).
			if site.wait <= 0.0 and not site.leaving and not site.get("frozen",false): _hop(site,site.landing,"in")
		"in","out","away":
			var u := minf(1.0,float(site.age)/float(site.duration))
			var from: Vector3 = site.from
			var to: Vector3 = site.to
			site.p = from.lerp(to,u)
			site.p.y += 4.0*(0.2+from.distance_to(to)*0.16)*float(site.get("spring",1.0))*u*(1.0-u)
			pitch = -(0.5-u)*1.2
			if u > 0.06 and u < 0.88: pose = "leap"
			# Crouched to push off, and squashed as it lands.
			else: squash = Vector3(1.04,0.9,1.0)
			if u >= 1.0:
				if site.mode == "in":
					ripple(site.landing,0.6)
					site.mode = "swim"
					site.age = 0.0
				elif site.mode == "out":
					if site.get("burrow",false): winter.begin_burrow(site)
					else:
						site.mode = "turn"
						site.age = 0.0
						site.turn_from = float(site.yaw)
				else:
					site.mode = "sit"
					site.wait = 7.0+6.0*fposmod(float(site.phase)+clock*0.37,1.0)
		"burrow","emerge":
			var crawled: Vector2 = winter.crawl(site)
			pitch = crawled.x
			squash = Vector3(1.0,crawled.y,1.0)
		"turn":
			var u := minf(1.0,float(site.age)/FROG_TURN)
			var home: Vector3 = site.home
			site.yaw = lerp_angle(float(site.turn_from),_facing_water(site),smoothstep(0.0,1.0,u))
			site.p = home+Vector3(0,0.05*size*4.0*u*(1.0-u),0)
			if u >= 1.0:
				site.mode = "sit"
				site.wait = 7.0+6.0*fposmod(float(site.phase)+clock*0.37,1.0)
		"swim":
			pose = "leap"
			var landing: Vector3 = site.landing
			var candidate := landing+Vector3(sin(float(site.age)*1.8)*0.12,0,(1.0-cos(float(site.age)*1.8))*0.1)
			if survey.wet_at(Vector2(candidate.x,candidate.z)): site.p = candidate
			site.p.y = landing.y+0.02-0.135*size*sin(minf(1.0,float(site.age)/0.4)*PI*0.5)
			var kick := maxf(0.0,sin(float(site.age)*5.0))
			squash = Vector3(1.0-0.04*kick,1.0,1.0+0.12*kick)
			# Late in the swim it comes round toward its bank.
			if float(site.age) > 2.2:
				var home: Vector3 = site.home
				site.yaw = lerp_angle(float(site.yaw),atan2(home.x-site.p.x,home.z-site.p.z),1.0-exp(-step*3.0))
			# A startled frog stays under a while longer (`lurk`, life_notice.gd).
			if float(site.age) >= 3.5+float(site.get("lurk",0.0)) or site.leaving:
				site.lurk = 0.0
				_hop(site,site.home,"out")
	var scale := Vector3.ONE*size*smoothstep(0.0,0.3,clock-float(site.born))*fade*squash
	if site.mode == "sit":
		# A slow breath through the throat, not a shiver.
		scale.y *= 1.0+0.02*sin(clock*2.4+float(site.phase))
	if scale.x <= 0.0: scale = Vector3.ONE*0.00001
	var shown := _frog_pose(site,pose)
	if site.shown_pose != pose:
		if site.shown_pose != "": _frog_pose(site,site.shown_pose).set_instance_transform(site.slot,_hidden())
		site.shown_pose = pose
	shown.set_instance_transform(site.slot,Transform3D(Basis.from_euler(Vector3(pitch,float(site.yaw),0),EULER_ORDER_XYZ).scaled(scale),site.p))

## The batch showing a frog's look in `pose`.
func _frog_pose(site: Dictionary, pose: String) -> MultiMesh:
	var kind: String = site.species
	var seed := int(str(site.look).get_slice(" ",1))
	return _look(_frog_looks,"%s %s" % [site.look,pose],FROG_MAX,func() -> Mesh: return Models.frog(material,kind,pose,seed))

## The yaw that faces a frog from its bank to its water.
func _facing_water(site: Dictionary) -> float:
	var home: Vector3 = site.home
	var landing: Vector3 = site.landing
	return atan2(landing.x-home.x,landing.z-home.z)

func _hop(site: Dictionary, destination: Vector3, mode: String) -> void:
	var from: Vector3 = site.p
	site.from = from
	site.to = destination
	site.mode = mode
	site.age = 0.0
	site.duration = 0.32+Vector2(destination.x-from.x,destination.z-from.z).length()*0.28
	site.yaw = atan2(destination.x-from.x,destination.z-from.z)

func ripple(point: Vector3, size: float) -> void:
	_ring_state[_next_ring] = {"p":point,"age":0.0,"size":size}
	_next_ring = (_next_ring+1)%RINGS

func _move_rings(step: float) -> void:
	for i in range(RINGS):
		var ring: Dictionary = _ring_state[i]
		if float(ring.age) > 4.0: continue
		ring.age = float(ring.age)+step
		var u := clampf(float(ring.age)/(1.3+float(ring.size)*0.9),0.0,1.0)
		var radius: float = (0.08+sqrt(u)*0.95)*float(ring.size) if u < 1.0 else 0.00001
		_rings.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius),ring.p+Vector3(0,0.03,0)))
		_rings.multimesh.set_instance_custom_data(i,Color((1.0-u)*(1.0-u)*0.75,0,0,0))

# --- Fireflies ----------------------------------------------------------------

## On a blank world the fireflies belong to the land: every one starts absent
## and arrives at a damp place. The Fidelity world gets its own back.
func _own_fireflies() -> void:
	if _fireflies_owned: return
	_fireflies_owned = true
	var flies: MultiMesh = scene._fireflies.multimesh
	for i in range(mini(flies.instance_count,_firefly_source.size())):
		var source: Color = _firefly_source[i][1]
		flies.set_instance_custom_data(i,Color(source.r,source.g,source.b,1.0))
	_free.firefly = range(mini(FIREFLY_MAX,flies.instance_count)-1,-1,-1)

func _restore_fireflies() -> void:
	if not _fireflies_owned: return
	_fireflies_owned = false
	_fading_flies.clear()
	var flies: MultiMesh = scene._fireflies.multimesh
	for i in range(mini(flies.instance_count,_firefly_source.size())):
		flies.set_instance_transform(i,_firefly_source[i][0])
		flies.set_instance_custom_data(i,_firefly_source[i][1])

## Custom data w is absence (shaders/reference_fireflies.gdshader).
func _fly_presence(slot: int, presence: float) -> void:
	var flies: MultiMesh = scene._fireflies.multimesh
	if slot >= flies.instance_count: return
	var source: Color = _firefly_source[slot][1]
	flies.set_instance_custom_data(slot,Color(source.r,source.g,source.b,1.0-presence))

func _fade_fireflies() -> void:
	for cell: int in sites.firefly.keys():
		var site: Dictionary = sites.firefly[cell]
		if site.here and site.leaving and not _fading_flies.has(site.slot): _fading_flies[site.slot] = site
	for slot: int in _fading_flies.keys():
		var site: Dictionary = _fading_flies[slot]
		if site.leaving:
			var presence := 1.0-clampf((clock-float(site.left))/FIREFLY_FADE,0.0,1.0)
			_fly_presence(slot,presence)
			if presence <= 0.0:
				_fading_flies.erase(slot)
				_release("firefly",site)
				sites.firefly.erase(site.cell)
		else:
			var presence := clampf((clock-float(site.born))/FIREFLY_FADE,0.0,1.0)
			_fly_presence(slot,presence)
			if presence >= 1.0: _fading_flies.erase(slot)

## Probes only: start a moment or a snake now (see LifeMoments.force).
func force(kind: String) -> bool:
	return snakes.force() if kind == "snake" else moments.force(kind)

## Kinds `summon` knows, in the command palette's order.
const SUMMONS := ["deer","heron","snake","woodpecker","geese","rainbow"]

## Call `kind` (a SUMMONS id) now, whatever its chance, hour or season: the
## command palette's creative override. Deer come out of the
## nearest wood, or, on open ground, from just beyond the view; the others
## still need their place (water for heron and snake, a snag for the
## woodpecker). "" when it came, else a short line saying what it needs.
func summon(kind: String) -> String:
	if survey == null: return "The land is still waking"
	match kind:
		"snake":
			if snakes.showing() != "": return "A snake is already out"
			return "" if snakes.force() else "A snake needs a pond to come to: pour some water first"
		"heron":
			if str(moments.showing().heron) != "": return "The heron is already here"
			return "" if moments.force("heron") else "A heron needs shallow water"
		"deer":
			if moments.showing().deer: return "The deer are already out"
			if moments.force("deer"): return ""
			moments._deer_arrive(_open_edges())
			return ""
		"woodpecker":
			return "" if small.woodpecker.start() else "A woodpecker needs a dead tree"
		"geese":
			return "" if small.geese.start() else "The geese are already passing"
		_:
			return "" if moments.force(kind) else "Not now"

## Stand-in forest edges for open ground (`summon`): a grid over the plate's
## middle (inside 12.8 m, with room to walk in and out),
## each with its "wood" behind it, away from the camera, so whatever steps
## out walks toward the view. The callers pick the best of them as ever.
func _open_edges() -> Array:
	var eye := to_local(scene.camera.global_position)
	var edges := []
	for i in range(-4,5):
		for j in range(-4,5):
			var p := Vector2(i,j)*2.0
			if data.ground_height(p) == null: continue
			var into := (p-Vector2(eye.x,eye.z)).normalized()
			edges.append({"p":p,"into":into,"trees":99})
	if edges.is_empty(): edges.append({"p":Vector2.ZERO,"into":(-Vector2(eye.x,eye.z)).normalized(),"trees":99})
	return edges

static func _forced_kinds() -> PackedStringArray:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--force-life": return PackedStringArray(["deer","heron","snake"])
		if arg.begins_with("--force-life="): return arg.trim_prefix("--force-life=").split(",",false)
	return PackedStringArray()

func _force_due() -> void:
	var on_stage: Dictionary = moments.showing()
	on_stage.snake = snakes.showing()
	for kind in _force_kinds:
		# Deer and rainbow report a bool, heron and snake their phase.
		var shown: Variant = on_stage.get(kind,"")
		var present: bool = shown if shown is bool else str(shown) != ""
		if present: _force_next[kind] = clock+FORCE_GAP
		elif clock >= float(_force_next.get(kind,0.0)) and force(kind): _force_next[kind] = clock+FORCE_GAP

# --- World ------------------------------------------------------------------

func _season() -> float:
	var world: WorldClock = scene.get("world_clock")
	return world.season if world != null else 0.0

func _daylight() -> float:
	return float(scene._celestial.state.get("zs_daylight",1.0))

## Arrived creatures of `kind` still in place, for moments and probes.
func present(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: Dictionary in sites[kind].values():
		if site.here and not site.leaving and not site.has("taken"): result.append(site)
	return result

# --- Prey -------------------------------------------------------------------

## A heron or snake took this fish or frog: it slips into `mouth` over
## TAKE_TIME and is gone. It counts as gone at once (`present`, the save), and
## its site waits PREY_RETURN before another arrives the usual way.
func take(site: Dictionary, mouth: Vector3) -> void:
	if not site.here or site.leaving or site.has("taken"): return
	var kind: String = site.kind
	site.taken = clock
	site.mouth = mouth
	site.erase("lure")
	site.erase("frozen")
	var timing: Array = PREY_RETURN[kind]
	site.delay = float(timing[0])+float(timing[1])*_rng.randf()
	site.since = clock
	taken[kind] = int(taken.get(kind,0))+1

## A water ball scooping a pond (NativeChunkEditor `_ball_step`): up to
## `most` fish swimming within `reach` m of `center` are taken up into it at
## `mouth` (plate coordinates), as a heron takes one, and their looks come
## back as [{"kind", "seed", "mirror"}] for the ball to carry; their sites
## wait PREY_RETURN before the pond fills them again.
func scoop_fish(center: Vector2, reach: float, most: int, mouth: Vector3) -> Array:
	var looks := []
	if not active or most <= 0: return looks
	var near := present("fish").filter(func(site: Dictionary) -> bool: return Vector2(site.p.x,site.p.z).distance_to(center) <= reach)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.p.x,a.p.z).distance_to(center) < Vector2(b.p.x,b.p.z).distance_to(center))
	for site: Dictionary in near.slice(0,most):
		var look := str(site.get("look","")).split(" ")
		if look.size() != 2: continue
		looks.append({"kind":look[0],"seed":int(look[1]),"mirror":bool(site.get("mirror",false))})
		take(site,mouth)
	return looks

## The batch a fish is drawn with, for the one in a heron's bill.
func fish_look(site: Dictionary) -> MultiMeshInstance3D:
	return _fish_looks.get(site.get("look",""))

## Into the mouth: toward it and smaller, a frog kicking in its leaping pose,
## then gone and waiting to return.
func _move_taken(kind: String, site: Dictionary) -> void:
	var u := (clock-float(site.taken))/float(TAKE_TIME[kind])
	if u >= 1.0:
		_release(kind,site)
		for key in ["taken","mouth","shown_p","shown_yaw"]: site.erase(key)
		return
	var e := smoothstep(0.0,1.0,u)
	var from: Vector3 = site.get("shown_p",site.p)
	var p := from.lerp(site.mouth,e)
	var s := maxf(float(site.size)*(1.0-e),0.00001)
	if kind == "fish":
		var basis := Basis(Vector3.UP,float(site.get("shown_yaw",0.0)))*Basis.from_scale(Vector3(-s if site.mirror else s,s,s))
		_fish_looks[site.look].multimesh.set_instance_transform(site.slot,Transform3D(basis,p))
		return
	if site.shown_pose != "leap":
		if site.shown_pose != "": _frog_pose(site,site.shown_pose).set_instance_transform(site.slot,_hidden())
		site.shown_pose = "leap"
	var kick := sin(u*TAU*2.0)*0.25
	_frog_pose(site,"leap").set_instance_transform(site.slot,Transform3D(Basis.from_euler(Vector3(0.5*e+kick,float(site.yaw),0),EULER_ORDER_XYZ).scaled(Vector3.ONE*s),p))
