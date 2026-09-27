extends Node3D
## Life answers the land (docs/scenic/life.md). Fish, frogspawn, frogs, birds
## and fireflies find their places in the world as it stands now, and arrive
## there in their own time; herons, deer, a rainbow and, very rarely, a
## glimpse of Bigfoot come when a place has become rich (scripts/life_moments.gd).
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

const Survey = preload("res://scripts/life_survey.gd")
const Models = preload("res://scripts/life_models.gd")
const Moments = preload("res://scripts/life_moments.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const BirdFlight = preload("res://studies/bird_flight.gd")

## Microseconds a survey may spend per frame.
const SURVEY_BUDGET_USEC := 1200
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
## Fish: one per FISH_AREA m² of still water, deep cells only.
const FISH_AREA := 2.0
const FISH_BODY_MAX := 7
const FISH_MAX := 24
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
const FISH_COLORS := [Color(0.88,0.47,0.16),Color(0.92,0.74,0.32),Color(0.72,0.74,0.72),Color(0.94,0.9,0.82)]

## Multiplies the life clock; probes run it fast.
var pace := 1.0
## --no-life turns the whole system off, for A/B timing.
var enabled := "--no-life" not in OS.get_cmdline_user_args()
var scene: Node3D
var editor: NativeChunkEditor
var data: NativeTerrainData
## The last complete survey, and one still being read.
var survey: RefCounted
var _reading: RefCounted
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
var surveys := 0
var last_usec := 0
var worst_usec := 0
## The longest single survey step over every survey so far.
var survey_worst_usec := 0
var moments: Node3D
var material: Material

var _tick := 0.0
var _fish: MultiMeshInstance3D
var _spawn: MultiMeshInstance3D
var _frogs: MultiMeshInstance3D
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

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	data = editor.data
	name = "LandLife"
	var reference: Node3D = scene.get_node("Reference")
	var frog_source: MultiMeshInstance3D = reference.get_node("mesh-40")
	material = frog_source.multimesh.mesh.surface_get_material(0)
	_fish = _batch("Fish",Models.fish(material),FISH_MAX,true)
	_spawn = _batch("Frogspawn",Models.frogspawn(material),SPAWN_MAX,false)
	_frogs = _batch("Frogs",frog_source.multimesh.mesh,FROG_MAX,true)
	var ring_source: MultiMeshInstance3D = reference.get_node("mesh-39")
	_rings = _batch("Rings",ring_source.multimesh.mesh,RINGS,false,true)
	var ring_material := ShaderMaterial.new()
	ring_material.shader = preload("res://shaders/reference_contact_ring.gdshader")
	_rings.material_override = ring_material
	for i in range(RINGS): _ring_state.append({"p":Vector3.ZERO,"age":100.0,"size":1.0})
	var frog_colors: Array[Color] = []
	for i in range(frog_source.multimesh.instance_count): frog_colors.append(frog_source.multimesh.get_instance_color(i))
	if frog_colors.is_empty(): frog_colors.append(Color(0.45,0.6,0.3))
	for i in range(FROG_MAX): _frogs.multimesh.set_instance_color(i,frog_colors[i%frog_colors.size()])
	_setup_birds(reference)
	for kind in sites: _free[kind] = range(_capacity(kind)-1,-1,-1)
	var flies: MultiMesh = scene._fireflies.multimesh
	for i in range(flies.instance_count): _firefly_source.append([flies.get_instance_transform(i),flies.get_instance_custom_data(i)])
	moments = Moments.new()
	add_child(moments)
	moments.setup(self)
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
	instances.custom_aabb = AABB(Vector3(-16,-4,-16),Vector3(32,40,32))
	for i in range(count): instances.set_instance_transform(i,_hidden())
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

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
	for bird: Dictionary in flock:
		bird.delay = 5.0
		bird.col = 0
	var columns := []
	for i in range(3): columns.append({"x":0.0,"z":0.0,"base":0.0,"top":10.0,"r":3.6,"lift":2.1})
	_birds = BirdFlight.new()
	_birds.setup(_bird_node.multimesh,data,{"birds":flock,"cols":columns,"species":source.species})

func _capacity(kind: String) -> int:
	return {"fish":FISH_MAX,"spawn":SPAWN_MAX,"frog":FROG_MAX,"bird":BIRD_MAX,"firefly":FIREFLY_MAX}[kind]

## `urgent` for a finished stroke, undo or new world: re-read as soon as the
## editor settles. Plain geometry changes (emergence steps) wait SURVEY_GAP.
func _changed(urgent := false) -> void:
	_dirty = true
	_quiet = 0.0
	if urgent: _urgent = true

## Undo, loads and new worlds. A new or loaded world starts settled; an undo
## keeps whatever still fits. A survey of the old ground is dropped.
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
	_reading = null
	_planning.clear()
	survey = null

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
	if step > 0.0:
		_tick += step
		if _tick >= TICK:
			_tick = 0.0
			_arrive_due()
		_animate(step)
		moments.advance(step,minf(delta,0.1))
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
	if _dirty and due and _reading == null and _quiet >= SURVEY_QUIET and not editor._painting and not editor.water_settling and editor.refresh_pending == 0 and not editor.forming:
		_dirty = false
		_urgent = false
		_since_survey = 0.0
		if _restored and data._undo.is_empty() and data._redo.is_empty(): _fresh = true
		_restored = false
		salt = int(editor.emergence.salt)
		_reading = Survey.new(data,editor.content.pond_vertices)
		global_transform = editor.terrain.global_transform
	if _reading != null and _reading.step(SURVEY_BUDGET_USEC):
		survey_worst_usec = maxi(survey_worst_usec,_reading.worst_step_usec)
		survey = _reading
		_reading = null
		surveys += 1
		_rng.seed = Variety.mix([salt,surveys])
		_planning = ["fish","spawn","frog","bird","firefly"]
		return
	# One kind a frame, so a finished survey never lands in a single frame.
	if not _planning.is_empty():
		call("_plan_"+_planning.pop_front())
		if _planning.is_empty(): _fresh = false

# --- Sites ---------------------------------------------------------------

func _plan_fish() -> void:
	var wanted := {}
	for record: Dictionary in survey.bodies:
		if record.deep.is_empty(): continue
		var cap := clampi(int(record.area/FISH_AREA),1,FISH_BODY_MAX)
		for cell in _choose("fish",record.deep,cap,FISH_GAP):
			wanted[cell] = {"body":record.id,"level":record.level}
	_reconcile("fish",wanted,FISH_MAX)

func _plan_spawn() -> void:
	var wanted := {}
	if WorldClock.season_factor(_season(),SPAWN_SEASON) > 0.05:
		for record: Dictionary in survey.bodies:
			if record.shallow.is_empty(): continue
			var cap := clampi(1+int(record.area/10.0),1,SPAWN_BODY_MAX)
			for cell in _choose("spawn",record.shallow,cap,SPAWN_GAP):
				wanted[cell] = {"body":record.id,"level":record.level}
	_reconcile("spawn",wanted,SPAWN_MAX)

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
			wanted[cell] = {"body":record.id,"level":record.level,"water":water,"settled":spawning[record.id]}
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
		column.x = clampf(anchors[i].x,-11.0,11.0)
		column.z = clampf(anchors[i].y,-11.0,11.0)
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
		var delay: float = timing[0]+timing[1]*Variety.unit([salt,kind.hash(),cell,7])
		var site := {"cell":cell,"kind":kind,"delay":delay,"here":false,"leaving":false,"slot":-1,"settled":_fresh}
		site.merge(wanted[cell],true)
		site.since = clock-(delay*SETTLED_HEAD if site.settled else 0.0)
		current[cell] = site
	# Sites that have not arrived yet simply close; arrived ones leave.
	for cell: int in current.keys():
		var site: Dictionary = current[cell]
		if site.get("closing",false): current.erase(cell)

func _depart(kind: String, site: Dictionary) -> void:
	if not site.here:
		site.closing = true
		return
	if site.leaving: return
	site.leaving = true
	site.left = clock
	if kind == "frog":
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
			call("_arrive_"+kind,site)
			arrivals[kind] = int(arrivals.get(kind,0))+1
			arrived.emit(kind,to_global(site.get("p",Vector3.ZERO)))
			if kind == "spawn": spawn_changed = true
	if spawn_changed: _plan_frog()

## Return a site's slot and hide what it showed.
func _release(kind: String, site: Dictionary) -> void:
	if not site.here or site.slot < 0: return
	match kind:
		"fish": _fish.multimesh.set_instance_transform(site.slot,_hidden())
		"spawn": _spawn.multimesh.set_instance_transform(site.slot,_hidden())
		"frog": _frogs.multimesh.set_instance_transform(site.slot,_hidden())
		"bird": _birds.birds[site.slot].delay = 5.0
		"firefly": _fly_presence(site.slot,0.0)
	_free[kind].append(site.slot)
	site.here = false
	site.slot = -1

func _hash(site: Dictionary, tag: int) -> float:
	return Variety.unit([salt,str(site.kind).hash(),site.cell,tag])

# --- Arrivals ---------------------------------------------------------------

func _arrive_fish(site: Dictionary) -> void:
	var c := Survey.center(site.cell)
	site.home = Vector3(c.x,float(site.level)-0.07,c.y)
	site.p = site.home
	site.phase = _hash(site,1)*TAU
	site.speed = lerpf(0.45,0.8,_hash(site,2))
	site.size = lerpf(0.85,1.25,_hash(site,3))
	site.rise = clock+lerpf(8.0,24.0,_hash(site,4))
	var color: Color = FISH_COLORS[Variety.weighted([1.0,0.7,0.5,0.35],_hash(site,5))]
	_fish.multimesh.set_instance_color(site.slot,color)

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
	site.size = lerpf(1.25,1.7,_hash(site,1))
	site.phase = _hash(site,2)*TAU
	# Hops in from further up the bank.
	var away: Vector3 = site.home+(site.home-site.landing).normalized()*1.1
	away.y = site.home.y
	site.p = away
	site.yaw = 0.0
	site.wait = 4.0+_hash(site,3)*6.0
	_hop(site,site.home,"out")

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
	if not sites.bird.is_empty():
		var air: Node3D = scene._atmosphere
		_birds.advance(step,false,air._air_strength,Vector2(cos(air._air_angle),sin(air._air_angle)))
	_fade_fireflies()
	_move_rings(step)

func _move_fish(site: Dictionary, _step: float, fade: float) -> void:
	var grow := smoothstep(0.0,SETTLE,clock-float(site.born))*fade
	var t: float = clock*float(site.speed)+float(site.phase)
	var reach := 0.35
	var candidate: Vector3 = site.home+Vector3(sin(t)*reach,0,cos(t*0.83)*reach)
	if survey.wet_at(Vector2(candidate.x,candidate.z)): site.p = candidate
	var heading := Vector2(cos(t)*reach,-0.83*sin(t*0.83)*reach)
	var yaw := atan2(heading.x,heading.y)+sin(clock*7.0+float(site.phase))*0.12
	var p: Vector3 = site.p
	p.y = float(site.level)-0.07-(1.0-grow)*0.3
	_fish.multimesh.set_instance_transform(site.slot,Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*maxf(float(site.size)*grow,0.00001)),p))
	# Now and then a fish rises and leaves a ring, most often in low light.
	if clock >= float(site.rise) and not site.leaving:
		site.rise = clock+lerpf(10.0,28.0,fposmod(float(site.rise)*0.618,1.0))*(0.6 if _daylight() < 0.6 else 1.0)
		ripple(Vector3(p.x,float(site.level),p.z),0.45)

func _move_spawn(site: Dictionary, _step: float, fade: float) -> void:
	var grow := smoothstep(0.0,3.0,clock-float(site.born))*fade
	if grow == site.shown: return
	site.shown = grow
	site.p.y = float(site.level)-0.012
	var scale := float(site.size)*lerpf(0.3,1.0,grow) if grow > 0.0 else 0.00001
	_spawn.multimesh.set_instance_transform(site.slot,Transform3D(Basis(Vector3.UP,float(site.angle)).scaled(Vector3(scale,scale,scale)),site.p))

## The Fidelity pond loop: sit on the bank, leap into checked water, paddle,
## hop back to the same bank (studies/frog_motion.gd).
func _move_frog(site: Dictionary, step: float, fade: float) -> void:
	site.age = float(site.age)+step
	match site.mode:
		"sit":
			site.wait = float(site.wait)-step
			if site.wait <= 0.0 and not site.leaving: _hop(site,site.landing,"in")
		"in","out","away":
			var u := minf(1.0,float(site.age)/float(site.duration))
			var from: Vector3 = site.from
			var to: Vector3 = site.to
			site.p = from.lerp(to,u)
			site.p.y += 4.0*(0.2+from.distance_to(to)*0.16)*u*(1.0-u)
			if u >= 1.0:
				if site.mode == "in":
					ripple(site.landing,0.6)
					site.mode = "swim"
					site.age = 0.0
				else:
					site.mode = "sit"
					site.wait = 7.0+6.0*fposmod(float(site.phase)+clock*0.37,1.0)
		"swim":
			var landing: Vector3 = site.landing
			var candidate := landing+Vector3(sin(float(site.age)*1.8)*0.12,0,(1.0-cos(float(site.age)*1.8))*0.1)
			if survey.wet_at(Vector2(candidate.x,candidate.z)): site.p = candidate
			site.p.y = landing.y-0.06*sin(minf(1.0,float(site.age)/0.4)*PI*0.5)
			if float(site.age) >= 3.5 or site.leaving: _hop(site,site.home,"out")
	var scale := Vector3.ONE*float(site.size)*smoothstep(0.0,0.3,clock-float(site.born))*fade
	var pitch := 0.0
	if site.mode in ["in","out","away"]:
		scale *= Vector3(1,0.85,1.35)
		pitch = -(0.5-minf(1.0,float(site.age)/float(site.duration)))*1.2
	elif site.mode == "swim":
		var kick := maxf(0.0,sin(float(site.age)*5.0))
		scale *= Vector3(1.0-0.06*kick,1.0-0.12*kick,1.0+0.3*kick)
	else:
		scale.y *= 1.0+0.05*sin(clock*7.0+float(site.phase))
	if scale.x <= 0.0: scale = Vector3.ONE*0.00001
	_frogs.multimesh.set_instance_transform(site.slot,Transform3D(Basis.from_euler(Vector3(pitch,float(site.yaw),0),EULER_ORDER_XYZ).scaled(scale),site.p))

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
		if site.here and not site.leaving: result.append(site)
	return result
