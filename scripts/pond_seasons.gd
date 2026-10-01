extends Node3D
## Water that ages and carries the season (docs/scenic/life.md, "Ponds
## through the year"). Owned by LandLife and advanced on its clock; it reads
## LandLife's survey for the ponds and the live water (scripts/water_flow.gd)
## for their surface, through the kernel's own accessors, a few times a second.
##
## Lilies: a still pond that has stood long enough grows lily pads, first in
## one spot on its shallow edge, then round the edge and a little way in, and
## flowers in summer. Pads die back through late autumn and winter and come
## again in spring. A pond's age is kept by body: a re-read body takes the
## oldest age among the cells it now covers, and a pond that drains starts
## again from clear. Pads ride the water's surface, and go where it drains
## or runs.
##
## Leaves: in autumn, deciduous trees within LEAF_REACH of water drop some of
## their leaves onto it. A leaf flutters down, then drifts with the water:
## down a rill, slowly round a pond and out to its banks, lodging where the
## water stops, and sinks after a while. Tinted by its tree's stand
## (scripts/tree_stands.gd autumn). One pooled MultiMesh.

const Survey = preload("res://scripts/life_survey.gd")
const Models = preload("res://scripts/life_models.gd")
const Variety = preload("res://scripts/seeded_variety.gd")

## Seconds between reads of the live water's depth, ground and velocity.
const SAMPLE_SECONDS := 0.2
## Water shallower than this (m) carries nothing.
const WET := 0.02
## Height over the water a pad or leaf floats (the live sheet is drawn 1.2 cm up).
const LIFT := 0.016

# --- Lilies ---
## Life-clock seconds a still pond stands before its first pad, and by when
## its lily edge is full.
const LILY_AGE := Vector2(120.0,720.0)
## A settled world's ponds (a new or generated world) start this old.
const LILY_SETTLED := 480.0
## Pads grow on pond cells up to LILY_RINGS cells (0.5 m each) in from the
## bank, no more than LILY_INNER of the way to the pond's middle, in water
## LILY_DEPTH deep. At most LILY_COVER of a pond's cells take pads.
const LILY_RINGS := 3
const LILY_INNER := 0.6
const LILY_DEPTH := Vector2(0.03,0.9)
const LILY_COVER := 0.5
## A cell's second pad, by this chance.
const LILY_SECOND := 0.35
const LILY_MAX := 160
const FLOWER_MAX := 40
## Pad radius (m); flower radius; the share of pads that flower.
const LILY_SIZE := Vector2(0.09,0.16)
const FLOWER_SIZE := Vector2(0.06,0.085)
const FLOWER_SHARE := 0.22
## Pads and flowers through the year, at the opening of spring, summer,
## autumn and winter (WorldClock.season_factor), and the rust pads take.
const LILY_SEASON := [0.2,1.0,0.75,0.0]
const FLOWER_SEASON := [0.0,1.0,0.1,0.0]
const LILY_RUST := [0.0,0.0,0.0,1.0]
## Flowers open once a pond's pads are this far grown.
const FLOWER_GROWTH := Vector2(0.3,0.7)
## Water faster than this (m/s) keeps no pads.
const LILY_CALM := 0.12
## Seconds a pad takes to open or go.
const LILY_EASE := 3.0
## A live pond with less than this share of its cells wet has drained.
const LILY_DRAINED := 0.3
const LILY_TICK := 0.1
## Pad greens (sRGB): the middle, the rim; the rust; flower whites and pinks.
const PAD_COLORS := ["4a7a34","3a6a2c"]
const PAD_RUST := Color(0.36,0.2,0.06)
const FLOWER_COLORS := [["f4efe4","e8c2cc"],["f2e6ea","d88aa4"]]

# --- Leaves ---
const LEAF_MAX := 160
## Trees that shed onto water.
const LEAF_KINDS := ["broadleaf","layered_tree","birch","willow"]
## Metres from a trunk its leaves land.
const LEAF_REACH := 2.6
## Leaves a second at full shed, reached with LEAF_TREES shedding trees.
const LEAF_RATE := 1.8
const LEAF_TREES := 6
## Height over the water (m) a leaf lets go from, and how fast it falls.
const LEAF_DROP := Vector2(1.3,2.8)
const LEAF_FALL := 0.6
## Seconds a leaf floats before it sinks, how long sinking takes, and the
## most a leaf stranded on dry ground lasts.
const LEAF_FLOAT := Vector2(60.0,130.0)
const LEAF_SINK := 6.0
const LEAF_STRANDED := 8.0
## 1/s: how quickly a leaf takes the water's speed; its top speed (m/s).
const LEAF_FOLLOW := 1.6
const LEAF_SPEED := 1.4
## On still water (slower than LEAF_STILL m/s): m/s round the pond's middle
## and out toward its bank; and m/s per unit of wind.
const LEAF_STILL := 0.06
const LEAF_SWIRL := 0.035
const LEAF_SHORE := 0.012
const LEAF_WIND := 0.03
const LEAF_SIZE := Vector2(0.07,0.11)
## Objects scanned for shedding trees each frame, and seconds between scans.
const LEAF_SCAN := 12
const LEAF_RESCAN := 4.0
## Leaf colour scale over the stand hue, as a crown's turn (lum × 2.9).
const LEAF_BRIGHT := 0.62
## The deep water colour a sinking leaf fades into (GardenView.sample_ponds).
const WATER_TONE := Color(0.0176,0.1022,0.1079)

var life: Node3D
var survey: RefCounted
## Ponds: [{"cells", "first", "center", "age", "live", "wet", "turn"}].
var bodies: Array[Dictionary] = []
## Pads: [{"key", "p", "body", "order", "size", "yaw", "flower", "bloom", "shade", "scale", "open", "cell"}].
var pads: Array[Dictionary] = []
## Leaves in the air or on the water, as parallel arrays (`leaf_count` of
## them), and how many have landed on water in all.
var leaf_count := 0
var leaves_landed := 0
var _leaf_p := PackedVector2Array()
var _leaf_v := PackedVector2Array()
var _leaf_y := PackedFloat32Array()
var _leaf_yaw := PackedFloat32Array()
var _leaf_spin := PackedFloat32Array()
var _leaf_age := PackedFloat32Array()
var _leaf_life := PackedFloat32Array()
var _leaf_size := PackedFloat32Array()
var _leaf_seed := PackedFloat32Array()
var _leaf_color := PackedColorArray()
var _leaf_falling := PackedByteArray()
var _pads: MultiMeshInstance3D
var _flowers: MultiMeshInstance3D
var _leaves: MultiMeshInstance3D
var _pad_buffer := PackedFloat32Array()
var _flower_buffer := PackedFloat32Array()
var _leaf_buffer := PackedFloat32Array()
var _lily_tick := 0.0
var _wet_tick := 0.0
var _resume := {}
## The live water, read every SAMPLE_SECONDS: depth, ground and velocity per
## cell of its grid.
var _flow: RefCounted
var _depth := PackedFloat32Array()
var _ground := PackedFloat32Array()
var _velocity := PackedVector2Array()
var _grid := Vector2i.ZERO
var _origin := Vector2.ZERO
var _cell := 0.25
var _sampled := INF
## Survey cells of still water the live water does not hold (planned ponds).
var _planned := PackedByteArray()
## Each survey body's middle and which way leaves circle it.
var _centres := PackedVector2Array()
var _turns := PackedFloat32Array()
## Shedding trees near water: [{"p", "stand"}]; the scan in progress.
var _trees: Array[Dictionary] = []
var _scan: Array[Dictionary] = []
var _scan_cursor := -1
var _rescan := 0.0
var _shed := 0.0
var _rng := RandomNumberGenerator.new()
var _pad_green: Array[Color] = []
var _flower_tints: Array = []

func setup(owner: Node3D) -> void:
	life = owner
	name = "PondSeasons"
	var material: Material = life.material
	_pads = _batch("LilyPads",lily_pad(material),LILY_MAX)
	_flowers = _batch("LilyFlowers",lily_flower(material),FLOWER_MAX)
	_leaves = _batch("WaterLeaves",floating_leaf(material),LEAF_MAX)
	_pad_buffer = _blank(LILY_MAX)
	_flower_buffer = _blank(FLOWER_MAX)
	_leaf_buffer = _blank(LEAF_MAX)
	for array in [_leaf_p,_leaf_v,_leaf_y,_leaf_yaw,_leaf_spin,_leaf_age,_leaf_life,_leaf_size,_leaf_seed,_leaf_color,_leaf_falling]: array.resize(LEAF_MAX)
	_rng.seed = 7117
	for code: String in PAD_COLORS: _pad_green.append(Color(code).srgb_to_linear())
	for pair: Array in FLOWER_COLORS: _flower_tints.append([Color(pair[0]).srgb_to_linear(),Color(pair[1]).srgb_to_linear()])

func _batch(label: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.instance_count = count
	instances.mesh = mesh
	instances.custom_aabb = AABB(Vector3(-16,NativeTerrainData.MIN_HEIGHT-1.0,-16),Vector3(32,45,32))
	instances.buffer = _blank(count)
	instances.visible_instance_count = 0
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

## A buffer of `count` hidden instances (never a zero transform).
static func _blank(count: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(count*16)
	for i in range(count): _put(buffer,i,Basis.from_scale(Vector3.ONE*0.00001),Vector3(0,-50,0),Color.WHITE)
	return buffer

static func _put(buffer: PackedFloat32Array, i: int, basis: Basis, origin: Vector3, color: Color) -> void:
	var o := i*16
	buffer[o] = basis.x.x
	buffer[o+1] = basis.y.x
	buffer[o+2] = basis.z.x
	buffer[o+3] = origin.x
	buffer[o+4] = basis.x.y
	buffer[o+5] = basis.y.y
	buffer[o+6] = basis.z.y
	buffer[o+7] = origin.y
	buffer[o+8] = basis.x.z
	buffer[o+9] = basis.y.z
	buffer[o+10] = basis.z.z
	buffer[o+11] = origin.z
	buffer[o+12] = color.r
	buffer[o+13] = color.g
	buffer[o+14] = color.b
	buffer[o+15] = color.a

## Everything goes at once (a new world).
func clear() -> void:
	survey = null
	bodies.clear()
	pads.clear()
	leaf_count = 0
	_trees.clear()
	_scan_cursor = -1
	_resume.clear()
	for node: MultiMeshInstance3D in [_pads,_flowers,_leaves]:
		if node != null: node.multimesh.visible_instance_count = 0

# --- Saving -------------------------------------------------------------------

## Each pond's age, for LandLife's document: [[first cell, age], ...].
func document() -> Array:
	var rows := []
	for record: Dictionary in bodies:
		if rows.size() < 64: rows.append([int(record.first),snappedf(float(record.age),0.1)])
	return rows

static func valid_document(value: Variant) -> bool:
	if not value is Array or value.size() > 64: return false
	for row: Variant in value:
		if not row is Array or row.size() != 2 or not GardenData._integer(row[0]) or int(row[0]) < 0 or int(row[0]) >= Survey.SIDE*Survey.SIDE: return false
		if not GardenData._number(row[1],0.0,1e9): return false
	return true

## A loaded world's ponds keep their ages, handed to the first survey.
func restore(rows: Array) -> void:
	_resume.clear()
	for row: Array in rows: _resume[int(row[0])] = float(row[1])

# --- Surveys ------------------------------------------------------------------

## A new survey of the land: ponds take their ages from the ones they cover,
## and the pads are laid out again (grown pads keep their growth).
func surveyed(read: RefCounted, settled: bool) -> void:
	survey = read
	_sample(true)
	var prior := PackedFloat32Array()
	prior.resize(Survey.SIDE*Survey.SIDE)
	prior.fill(-1.0)
	for record: Dictionary in bodies:
		for cell: int in record.cells: prior[cell] = maxf(prior[cell],float(record.age))
	for cell: int in _resume: prior[cell] = maxf(prior[cell],float(_resume[cell]))
	_resume.clear()
	bodies.clear()
	_centres.clear()
	_turns.clear()
	for record: Dictionary in survey.bodies:
		_centres.append(record.center)
		_turns.append(1.0 if Variety.unit([life.salt,int(record.cells[0]),73]) < 0.5 else -1.0)
		if float(record.area) < Survey.MIN_BODY_AREA: continue
		var cells: PackedInt32Array = record.cells
		var age := -1.0
		for cell in cells: age = maxf(age,prior[cell])
		if age < 0.0: age = LILY_SETTLED if settled else 0.0
		var live := 0
		if _flow != null:
			for cell in cells:
				if _flow_depth(Survey.center(cell)) > WET: live += 1
		bodies.append({"cells":cells,"first":cells[0],"center":record.center,"age":age,"live":live*2 > cells.size(),"wet":1.0,
			"turn":1.0 if Variety.unit([life.salt,cells[0],73]) < 0.5 else -1.0,"pink":Variety.unit([life.salt,cells[0],74]) < 0.3})
	_planned.resize(Survey.SIDE*Survey.SIDE)
	_planned.fill(0)
	for record: Dictionary in bodies:
		if record.live: continue
		for cell: int in record.cells: _planned[cell] = 1
	_lay_pads()
	_scan_cursor = 0

func _lay_pads() -> void:
	var grown := {}
	for pad: Dictionary in pads: grown[pad.key] = pad.scale
	pads.clear()
	var order := range(bodies.size())
	# The oldest ponds take their pads first.
	order.sort_custom(func(a: int, b: int) -> bool: return float(bodies[a].age) > float(bodies[b].age))
	for id: int in order:
		if pads.size() >= LILY_MAX: break
		_lay_body(id,grown)

## One pond's pads: its edge cells ringed inward, ranked from a seed spot on
## the bank round the edge and in, so the first pads sit together.
func _lay_body(id: int, grown: Dictionary) -> void:
	var record: Dictionary = bodies[id]
	var cells: PackedInt32Array = record.cells
	var ring := {}
	var queue := PackedInt32Array()
	for cell in cells: ring[cell] = -1
	for cell in cells:
		for next in _neighbours(cell):
			if next < 0 or not ring.has(next):
				ring[cell] = 0
				queue.append(cell)
				break
	var head := 0
	var deepest := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for next in _neighbours(cell):
			if next >= 0 and ring.has(next) and int(ring[next]) < 0:
				ring[next] = int(ring[cell])+1
				deepest = maxi(deepest,int(ring[next]))
				queue.append(next)
	var reach := mini(LILY_RINGS,maxi(1,floori(deepest*LILY_INNER)+1))
	var open: Array[int] = []
	var seed := -1
	var seed_roll := INF
	for cell in cells:
		var d: float = survey.depth(cell)
		if int(ring[cell]) < 0 or int(ring[cell]) >= reach or d < LILY_DEPTH.x or d > LILY_DEPTH.y: continue
		open.append(cell)
		var roll := Variety.unit([life.salt,cell,71])
		if int(ring[cell]) == 0 and roll < seed_roll:
			seed_roll = roll
			seed = cell
	if open.is_empty(): return
	if seed < 0: seed = open[0]
	var home := Survey.center(seed)
	var far := 0.001
	for cell in open: far = maxf(far,Survey.center(cell).distance_to(home))
	var score := {}
	for cell in open: score[cell] = 0.6*Survey.center(cell).distance_to(home)/far+0.3*float(ring[cell])/LILY_RINGS+0.1*Variety.unit([life.salt,cell,72])
	open.sort_custom(func(a: int, b: int) -> bool: return score[a] < score[b])
	open.resize(mini(open.size(),maxi(1,ceili(cells.size()*LILY_COVER))))
	var count := open.size()
	for rank in range(count):
		var cell := open[rank]
		for k in range(2):
			if pads.size() >= LILY_MAX: return
			if k == 1 and Variety.unit([life.salt,cell,75]) >= LILY_SECOND: break
			var key := cell*2+k
			var h := [life.salt,cell,76+k*8]
			var p := Survey.center(cell)+Vector2(Variety.unit(h+[1])-0.5,Variety.unit(h+[2])-0.5)*0.36
			pads.append({"key":key,"cell":cell,"p":p,"body":id,"order":(rank+0.5*k+0.25)/count,
				"size":lerpf(LILY_SIZE.x,LILY_SIZE.y,Variety.unit(h+[3])),"yaw":Variety.unit(h+[4])*TAU,
				"flower":Variety.unit(h+[5]) < FLOWER_SHARE,"bloom":Variety.unit(h+[6]),"shade":Variety.unit(h+[7]),
				"scale":float(grown.get(key,0.0)),"open":0.0,"level":-INF})

static func _neighbours(cell: int) -> PackedInt32Array:
	var x := cell%Survey.SIDE
	var z := cell/Survey.SIDE
	return PackedInt32Array([z*Survey.SIDE+x+1 if x+1 < Survey.SIDE else -1,z*Survey.SIDE+x-1 if x > 0 else -1,
		(z+1)*Survey.SIDE+x if z+1 < Survey.SIDE else -1,(z-1)*Survey.SIDE+x if z > 0 else -1])

# --- Every frame ----------------------------------------------------------------

func advance(step: float) -> void:
	if step <= 0.0: return
	var autumn := _autumn()
	if not bodies.is_empty() or leaf_count > 0 or autumn > 0.02: _sample(false)
	for record: Dictionary in bodies: record.age = float(record.age)+step
	_wet_tick += step
	if _wet_tick >= 1.0:
		_wet_tick = 0.0
		_check_drained()
	_lily_tick += step
	if _lily_tick >= LILY_TICK:
		_update_lilies(_lily_tick)
		_lily_tick = 0.0
	if autumn > 0.02:
		_rescan -= step
		if _scan_cursor < 0 and _rescan <= 0.0: _scan_cursor = 0
		_scan_trees()
		_shed_leaves(step,autumn)
	if leaf_count > 0 or _leaves.multimesh.visible_instance_count > 0: _move_leaves(step)

## A live pond that has mostly gone dry starts again from clear.
func _check_drained() -> void:
	for record: Dictionary in bodies:
		if not record.live or _flow == null: continue
		var wet := 0
		var cells: PackedInt32Array = record.cells
		for cell in cells:
			if _flow_depth(Survey.center(cell)) > WET: wet += 1
		record.wet = float(wet)/maxf(cells.size(),1.0)
		if record.wet < LILY_DRAINED: record.age = 0.0

func _update_lilies(step: float) -> void:
	var season := _season()
	var cover := WorldClock.season_factor(season,LILY_SEASON)
	var bloom := WorldClock.season_factor(season,FLOWER_SEASON)
	var rust := WorldClock.season_factor(season,LILY_RUST)
	var ease := step/LILY_EASE
	var flower := 0
	for i in range(pads.size()):
		var pad: Dictionary = pads[i]
		var record: Dictionary = bodies[pad.body]
		var growth := smoothstep(LILY_AGE.x,LILY_AGE.y,float(record.age))
		var level := _pad_level(pad,record)
		var want := 1.0 if float(pad.order) < growth*cover and level > -INF else 0.0
		pad.scale = move_toward(float(pad.scale),want,ease)
		if level > -INF: pad.level = level
		var s := float(pad.scale)
		var color := _pad_green[0].lerp(_pad_green[1],float(pad.shade)).lerp(PAD_RUST,rust*(0.6+0.4*float(pad.shade)))
		if s <= 0.001 or float(pad.level) <= -INF:
			_put(_pad_buffer,i,Basis.from_scale(Vector3.ONE*0.00001),Vector3(0,-50,0),color)
		else:
			var basis := Basis(Vector3.UP,float(pad.yaw)).scaled(Vector3.ONE*float(pad.size)*(0.25+0.75*s))
			_put(_pad_buffer,i,basis,Vector3(pad.p.x,float(pad.level)+LIFT,pad.p.y),color)
		if not pad.flower or flower >= FLOWER_MAX: continue
		var open := s > 0.9 and float(pad.bloom) < bloom*smoothstep(FLOWER_GROWTH.x,FLOWER_GROWTH.y,growth)
		pad.open = move_toward(float(pad.open),1.0 if open else 0.0,ease*1.5)
		var colors: Array = _flower_tints[1 if record.pink else 0]
		var tint: Color = colors[0].lerp(colors[1],float(pad.bloom))
		if float(pad.open) <= 0.001:
			_put(_flower_buffer,flower,Basis.from_scale(Vector3.ONE*0.00001),Vector3(0,-50,0),tint)
		else:
			var size := lerpf(FLOWER_SIZE.x,FLOWER_SIZE.y,float(pad.shade))*float(pad.open)
			var at := Vector2(pad.p)+Vector2.from_angle(float(pad.yaw)+1.3)*float(pad.size)*0.25
			_put(_flower_buffer,flower,Basis(Vector3.UP,float(pad.yaw)*2.0).scaled(Vector3.ONE*size),Vector3(at.x,float(pad.level)+LIFT+0.004,at.y),tint)
		flower += 1
	_pads.multimesh.buffer = _pad_buffer
	_pads.multimesh.visible_instance_count = pads.size()
	_flowers.multimesh.buffer = _flower_buffer
	_flowers.multimesh.visible_instance_count = flower

## The water a pad floats on, or -INF where it has drained or runs.
func _pad_level(pad: Dictionary, record: Dictionary) -> float:
	if not record.live or _flow == null: return survey.level[int(pad.cell)] if survey != null else -INF
	var p: Vector2 = pad.p
	if _flow_depth(p) < LILY_DEPTH.x or _velocity_at(p).length() > LILY_CALM: return -INF
	return _surface_at(p)

# --- Leaves -----------------------------------------------------------------------

## Walks the plants LEAF_SCAN a frame for deciduous trees with water in reach.
func _scan_trees() -> void:
	if _scan_cursor < 0: return
	var objects: Array = life.data.objects
	var last := mini(_scan_cursor+LEAF_SCAN,objects.size())
	for n in range(_scan_cursor,last):
		var item: Dictionary = objects[n]
		if str(item.get("asset","")) not in LEAF_KINDS: continue
		var p := Vector2(float(item.get("x",0.0)),float(item.get("z",0.0)))
		if _water_near(p): _scan.append({"p":p,"stand":float(item.get("autumn",0.5))})
	_scan_cursor = last
	if _scan_cursor >= objects.size():
		_trees = _scan
		_scan = []
		# Round again in a while, so a pond that fills later is found.
		_scan_cursor = -1
		_rescan = LEAF_RESCAN

func _water_near(p: Vector2) -> bool:
	for radius: float in [1.0,LEAF_REACH-0.3]:
		for k in range(6):
			if _depth_at(p+Vector2.from_angle(TAU*k/6.0+radius)*radius) > WET: return true
	return false

func _shed_leaves(step: float, autumn: float) -> void:
	if _trees.is_empty(): return
	var air: Variant = life.scene.get("_atmosphere")
	var wind: float = float(air.get("_air_strength")) if air != null and air.get("_air_strength") != null else 0.0
	# As the falling leaves shed (reference_leaves.gdshader).
	var shed := smoothstep(0.12,0.85,autumn)*0.72+0.08
	_shed += step*LEAF_RATE*shed*minf(float(_trees.size())/LEAF_TREES,1.0)*(1.0+0.5*minf(wind,2.0))
	while _shed >= 1.0:
		_shed -= 1.0
		if leaf_count >= LEAF_MAX: continue
		var tree: Dictionary = _trees[_rng.randi()%_trees.size()]
		for attempt in range(3):
			var at: Vector2 = tree.p+Vector2.from_angle(_rng.randf()*TAU)*LEAF_REACH*sqrt(_rng.randf())
			var surface := _surface_at(at)
			if surface <= -INF or _depth_at(at) < WET: continue
			var n := leaf_count
			leaf_count += 1
			_leaf_p[n] = at
			_leaf_v[n] = Vector2.ZERO
			_leaf_y[n] = surface+lerpf(LEAF_DROP.x,LEAF_DROP.y,_rng.randf())
			_leaf_yaw[n] = _rng.randf()*TAU
			_leaf_spin[n] = _rng.randf_range(-0.6,0.6)
			_leaf_age[n] = 0.0
			_leaf_life[n] = lerpf(LEAF_FLOAT.x,LEAF_FLOAT.y,_rng.randf())
			_leaf_size[n] = lerpf(LEAF_SIZE.x,LEAF_SIZE.y,_rng.randf())
			_leaf_seed[n] = _rng.randf()*TAU
			_leaf_color[n] = leaf_color(float(tree.stand),autumn,_rng.randf(),_rng.randf())
			_leaf_falling[n] = 1
			break

## Drops leaf `n`, moving the last one into its place.
func _drop_leaf(n: int) -> void:
	leaf_count -= 1
	var last := leaf_count
	_leaf_p[n] = _leaf_p[last]
	_leaf_v[n] = _leaf_v[last]
	_leaf_y[n] = _leaf_y[last]
	_leaf_yaw[n] = _leaf_yaw[last]
	_leaf_spin[n] = _leaf_spin[last]
	_leaf_age[n] = _leaf_age[last]
	_leaf_life[n] = _leaf_life[last]
	_leaf_size[n] = _leaf_size[last]
	_leaf_seed[n] = _leaf_seed[last]
	_leaf_color[n] = _leaf_color[last]
	_leaf_falling[n] = _leaf_falling[last]

func _move_leaves(step: float) -> void:
	var air: Variant = life.scene.get("_atmosphere")
	var wind := Vector2.ZERO
	if air != null and air.get("_air_strength") != null:
		wind = Vector2.from_angle(float(air._air_angle))*float(air._air_strength)*LEAF_WIND
	var follow := 1.0-exp(-LEAF_FOLLOW*step)
	var settle := 1.0-exp(-6.0*step)
	var turn := 1.0-exp(-1.5*step)
	var n := 0
	while n < leaf_count:
		var age := _leaf_age[n]+step
		_leaf_age[n] = age
		var p := _leaf_p[n]
		if age >= _leaf_life[n] or absf(p.x) >= Survey.HALF or absf(p.y) >= Survey.HALF:
			_drop_leaf(n)
			continue
		var t := age+_leaf_seed[n]
		var tilt := 0.06*sin(t*1.3)
		if _leaf_falling[n] == 1:
			tilt = 0.5*sin(t*2.7)
			var y := _leaf_y[n]-LEAF_FALL*step
			p += (Vector2(sin(t*3.1),cos(t*2.3))*0.3+wind*8.0)*step
			_leaf_yaw[n] += sin(t*1.7)*2.0*step
			var surface := _surface_at(p)
			if surface > -INF and y <= surface+LIFT:
				_leaf_falling[n] = 0
				y = surface+LIFT
				leaves_landed += 1
			elif surface <= -INF:
				# Blown over the bank: it lies where it lands and goes soon.
				var ground: Variant = life.data.ground_height(p)
				if ground == null or y <= float(ground)+0.01:
					_leaf_falling[n] = 0
					if ground != null: y = float(ground)+0.01
					_leaf_life[n] = minf(_leaf_life[n],age+LEAF_STRANDED)
			_leaf_p[n] = p
			_leaf_y[n] = y
		elif _depth_at(p) < WET:
			# Stranded: it lies where the water left it, and goes soon.
			if _leaf_v[n] != Vector2.ZERO:
				_leaf_life[n] = minf(_leaf_life[n],age+LEAF_STRANDED)
				_leaf_v[n] = Vector2.ZERO
		else:
			var target := _velocity_at(p)
			if target.length_squared() < LEAF_STILL*LEAF_STILL: target += _pond_drift(p,_leaf_seed[n])
			var v := _leaf_v[n].lerp(target+wind,follow).limit_length(LEAF_SPEED)
			var next := p+v*step
			# Lodged against the bank, or in the lee of the flow.
			if _depth_at(next) < WET: v = Vector2.ZERO
			else: _leaf_p[n] = next
			_leaf_v[n] = v
			var surface := _surface_at(_leaf_p[n])
			if surface > -INF: _leaf_y[n] = lerpf(_leaf_y[n],surface+LIFT,settle)
			var speed := v.length()
			if speed > 0.12: _leaf_yaw[n] = lerp_angle(_leaf_yaw[n],atan2(v.x,v.y),turn)
			else: _leaf_yaw[n] += _leaf_spin[n]*maxf(speed,0.02)*4.0*step
		var sink := clampf((age-(_leaf_life[n]-LEAF_SINK))/LEAF_SINK,0.0,1.0)
		var basis := (Basis(Vector3.UP,_leaf_yaw[n])*Basis(Vector3.RIGHT,tilt)).scaled(Vector3.ONE*_leaf_size[n]*(1.0-0.4*sink))
		var at := _leaf_p[n]
		_put(_leaf_buffer,n,basis,Vector3(at.x,_leaf_y[n]-0.035*sink,at.y),_leaf_color[n].lerp(WATER_TONE,sink*0.8))
		n += 1
	var hidden := Basis.from_scale(Vector3.ONE*0.00001)
	for i in range(leaf_count,_leaves.multimesh.visible_instance_count): _put(_leaf_buffer,i,hidden,Vector3(0,-50,0),Color.WHITE)
	_leaves.multimesh.buffer = _leaf_buffer
	_leaves.multimesh.visible_instance_count = leaf_count

## On still water: slowly round the pond's middle, and out to its bank.
func _pond_drift(p: Vector2, seed: float) -> Vector2:
	if survey == null: return Vector2.ZERO
	var cell := Survey.cell_at(p)
	var id: int = survey.body[cell] if cell >= 0 else -1
	if id < 0 or id >= _centres.size(): return Vector2.from_angle(seed)*LEAF_SHORE
	var out: Vector2 = p-_centres[id]
	var far := out.length()
	if far < 0.001: return Vector2.ZERO
	return Vector2(-out.y,out.x)/far*LEAF_SWIRL*_turns[id]*smoothstep(0.2,1.5,far)+out/far*LEAF_SHORE

## A floating leaf's colour: its stand's autumn hue (zs_autumn_stand_paint:
## gold, amber or copper-red as the stand runs), how far this leaf had
## turned (`pick`), a greener gold early in the fall, and now and then a
## brown one.
static func leaf_color(stand: float, autumn: float, pick: float, shade: float) -> Color:
	var reach := lerpf(0.1,0.45,smoothstep(0.0,0.6,stand))+0.55*smoothstep(0.55,0.85,stand)
	var depth := reach*lerpf(0.35,1.1,pick)
	var hue := Color(1.0,0.66,0.14).lerp(Color(1.0,0.52,0.10),smoothstep(0.0,0.35,depth))
	hue = hue.lerp(Color(0.5,0.16,0.05),smoothstep(0.35,1.0,depth))
	hue = Color(0.55,0.62,0.12).lerp(hue,smoothstep(0.05,0.45,autumn)*(0.55+0.45*pick))
	if shade < 0.15: hue = Color(0.42,0.24,0.1)
	return hue*LEAF_BRIGHT*lerpf(0.8,1.1,shade)

# --- The water -----------------------------------------------------------------

## Reads the live water's grids, at most every SAMPLE_SECONDS.
func _sample(now: bool) -> void:
	var flow: Variant = life.editor.get("flow")
	if flow == null or not flow.ready:
		_flow = null
		return
	if not now and Time.get_ticks_msec()/1000.0-_sampled < SAMPLE_SECONDS: return
	_sampled = Time.get_ticks_msec()/1000.0
	_flow = flow
	_depth = flow.kernel.get_depth()
	_ground = flow.kernel.get_ground()
	_velocity = flow.kernel.get_velocity()
	_grid = Vector2i(flow.width,flow.height)
	_origin = flow.origin
	_cell = flow.cell

func _index(p: Vector2) -> int:
	var i := floori((p.x-_origin.x)/_cell)
	var j := floori((p.y-_origin.y)/_cell)
	return j*_grid.x+i if i >= 0 and j >= 0 and i < _grid.x and j < _grid.y and j*_grid.x+i < _depth.size() else -1

## Water depth at `p`: the live water, or else a planned pond's (survey).
func _depth_at(p: Vector2) -> float:
	var d := _flow_depth(p)
	return d if d > WET else maxf(d,_planned_depth(p))

func _flow_depth(p: Vector2) -> float:
	if _flow == null: return 0.0
	var at := _index(p)
	return _depth[at] if at >= 0 else 0.0

## Still water the survey saw and the live water does not hold; without live
## water, all of the survey's still water.
func _planned_depth(p: Vector2) -> float:
	if survey == null: return 0.0
	var cell := Survey.cell_at(p)
	if cell < 0 or (_flow != null and (_planned.size() <= cell or _planned[cell] == 0)): return 0.0
	return survey.depth(cell)

## The water's surface at `p`, blended over the wet cells round it, or -INF.
func _surface_at(p: Vector2) -> float:
	var live := _flow_surface(p)
	if live > -INF: return live
	return survey.level_at(p) if _planned_depth(p) > 0.0 else -INF

func _flow_surface(p: Vector2) -> float:
	if _flow == null: return -INF
	var fx := (p.x-_origin.x)/_cell-0.5
	var fz := (p.y-_origin.y)/_cell-0.5
	var i := clampi(floori(fx),0,_grid.x-2)
	var j := clampi(floori(fz),0,_grid.y-2)
	var tx := clampf(fx-i,0.0,1.0)
	var tz := clampf(fz-j,0.0,1.0)
	var at := j*_grid.x+i
	if at+_grid.x+1 >= _depth.size(): return -INF
	var sum := 0.0
	var weights := 0.0
	# Only wet corners count, so a bank does not drag the surface down.
	for corner in 4:
		var c := at+(corner&1)+(corner>>1)*_grid.x
		if _depth[c] <= 0.012: continue
		var w := (tx if corner&1 else 1.0-tx)*(tz if corner>>1 else 1.0-tz)+0.0001
		sum += (_ground[c]+_depth[c])*w
		weights += w
	return sum/weights if weights > 0.0 else -INF

## The water's velocity at `p`, blended over the cells round it (m/s, x and z).
func _velocity_at(p: Vector2) -> Vector2:
	if _flow == null or _velocity.size() != _depth.size(): return Vector2.ZERO
	var fx := (p.x-_origin.x)/_cell-0.5
	var fz := (p.y-_origin.y)/_cell-0.5
	var i := clampi(floori(fx),0,_grid.x-2)
	var j := clampi(floori(fz),0,_grid.y-2)
	var tx := clampf(fx-i,0.0,1.0)
	var tz := clampf(fz-j,0.0,1.0)
	var at := j*_grid.x+i
	if at+_grid.x+1 >= _velocity.size(): return Vector2.ZERO
	return _velocity[at].lerp(_velocity[at+1],tx).lerp(_velocity[at+_grid.x].lerp(_velocity[at+_grid.x+1],tx),tz)

func _season() -> float:
	return life._season()

func _autumn() -> float:
	var precipitation: Variant = life.scene.get("_precipitation")
	var weather: Variant = precipitation.get("surface_weather") if precipitation != null else null
	return float(weather.autumn) if weather != null else 0.0

# --- Meshes -------------------------------------------------------------------------

## A lily pad a metre across at scale 1: a faceted disc, domed a little, with
## its notch.
static func lily_pad(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var middle := Color("5c8a3c").srgb_to_linear()
	var rim := Color("4a7a34").srgb_to_linear()
	var notch := 0.55
	var sides := 11
	var hub := Vector3(0,0.035,0)
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in range(sides+1):
		var a := notch*0.5+(TAU-notch)*float(i)/sides
		var wobble := 1.0+0.05*sin(float(i)*2.7)
		inner.append(Vector3(cos(a)*0.55,0.03,sin(a)*0.55)*wobble)
		outer.append(Vector3(cos(a),0.0,sin(a))*wobble)
	for i in range(sides):
		_up(b,hub,inner[i],inner[i+1],middle)
		_up(b,inner[i],outer[i],outer[i+1],rim)
		_up(b,inner[i],outer[i+1],inner[i+1],rim)
	return b.commit(material)

## A water-lily flower a metre across at scale 1: an open ring of eight
## petals, a cupped inner ring of six and a gold heart. White; the instance
## colour tints it.
static func lily_flower(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var petal := Color(1,1,1)
	var inside := Color(0.92,0.9,0.86)
	var heart := Color("e8b830").srgb_to_linear()
	for ring: Array in [[8,0.12,0.95,0.22,0.24,0.0,petal],[6,0.08,0.6,0.5,0.2,0.4,inside]]:
		for k in range(int(ring[0])):
			var a := TAU*k/int(ring[0])+float(ring[5])
			var out := Vector3(cos(a),0,sin(a))
			var side := Vector3(-sin(a),0,cos(a))
			var base := out*float(ring[1])+Vector3(0,0.03,0)
			var tip := out*float(ring[2])+Vector3(0,float(ring[3]),0)
			var mid := out*lerpf(float(ring[1]),float(ring[2]),0.45)+Vector3(0,float(ring[3])*0.4,0)
			var color: Color = ring[6]
			for s: float in [-1.0,1.0]:
				var edge := mid+side*float(ring[4])*s
				# Both faces, so a petal reads from below the rim too.
				b.tri(base,edge,tip,color)
				b.tri(base,tip,edge,color*0.9)
	b.icosahedron(Vector3(0,0.12,0),0.14,heart,0.7)
	return b.commit(material)

## A floating leaf a metre long at scale 1: a pointed blade along +Z, its
## halves turned up a little off the midrib.
static func floating_leaf(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var color := Color(1,1,1)
	var stem := Vector3(0,0,-0.55)
	var tip := Vector3(0,0.01,0.5)
	var rib := Vector3(0,0,0.0)
	for s: float in [-1.0,1.0]:
		var a := Vector3(0.24*s,0.06,-0.22)
		var c := Vector3(0.26*s,0.07,0.12)
		_up(b,stem,a,rib,color)
		_up(b,a,c,rib,color*0.95)
		_up(b,c,tip,rib,color)
	b.spindle(Vector3(0,0,-0.72),stem,0.025,Color(0.6,0.5,0.35),3)
	return b.commit(material)

## A triangle that faces up, whichever way it was wound.
static func _up(b: RefCounted, a: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	if (c-a).cross(d-a).y < 0.0: b.tri(a,d,c,color)
	else: b.tri(a,c,d,color)
