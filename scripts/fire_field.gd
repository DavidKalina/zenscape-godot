class_name FireField
extends RefCounted
## Grid fire over the meadow grid (`NativeTerrainData.MEADOW_CELLS` squared at
## `MEADOW_STEP` spacing, indexed `z*cells+x` exactly like `grass/meadow/blades`).
##
## The field owns four `PackedFloat32Array`s — fuel, heat, burn, ash — plus the
## fire state of every placed object. It simulates on a fixed 8 Hz accumulator,
## keeps an active-cell list so an unlit world costs nothing, and reaches the
## outside world only through signals and the two ground writes the design
## allows (cover arrays and the tint layer). Wind, weather and water arrive as
## injected `Callable`s so the whole thing runs in a test without a scene.

signal cell_ignited(index: int, center: Vector3)
signal cell_burned_out(index: int)
signal object_ignited(id: int, kind: String, position: Vector3)
signal object_charring(id: int, char: float)
signal object_burned_out(id: int, kind: String, position: Vector3)
signal explosive_triggered(id: int, position: Vector3)
signal fire_started(position: Vector3)
signal fire_extinguished()
## Undo bracket for the integration layer: one fire is one undoable step.
signal stroke_started()
signal stroke_ended()

const TICK := 0.125
const MEMORY_STRIDE := 7

## Asset groups. The rows are the design's "kind group" table; `kind` in every
## signal is the asset name, which is what the record carries.
const FAST_ASSETS := ["grass_tuft","flower","button_flower","spike_flower","umbel_flower","daisy_flower","fern","reeds","bank_grass","mushroom"]
const SHRUB_ASSETS := ["shrub","cactus","leaf_bed"]
const TREE_ASSETS := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree"]
const DEAD_ASSETS := ["log","stump","snag"]
const BURN_SECONDS := {"fast":4.0,"shrub":12.0,"tree":40.0,"deadwood":25.0}
const CANOPY_FUEL := {"fast":0.15,"shrub":0.5,"tree":1.0,"deadwood":0.6}

# Tunables. Measured targets live in docs/fire/DESIGN.md section 6.
var spread_rate := 0.30 ## Heat pushed per second by a fully burning neighbour.
var wind_scale := 0.18 ## Wind bias per m/s along the neighbour direction.
var wind_bias_min := -0.6
var wind_bias_max := 2.0
var ignite_heat := 0.55
var heat_decay := 0.50 ## Per-second exponential bleed of un-ignited heat.
var grass_burn_rate := 0.16 ## Fuel per second for pure grass.
var canopy_slowdown := 2.0 ## Divides the burn rate by `1 + this * canopy`.
var fade_seconds := 2.0 ## Burn fade once the fuel runs out.
var rain_quench := 0.5 ## Burn lost per second at rain 1.0.
var regrow_seconds := 240.0
var ember_chance := 0.05 ## Per hot cell per tick, ramped in over `ember_wind`.
var ember_wind := 3.0
var ember_ramp := 5.0 ## m/s above `ember_wind` at which spotting is at full odds.
var ember_heat := 0.6
var ember_min_cells := 3
var ember_max_cells := 8
var wet_stall := 0.8 ## ground_wet at or above this stops all spread.
var snow_stall := 0.35 ## snow_cover at or above this stops all spread.
var intensity_scale := 40.0 ## Burning cells that read as a full-strength fire.

var fuel := PackedFloat32Array()
var heat := PackedFloat32Array()
var burn := PackedFloat32Array()
var ash := PackedFloat32Array()
## id -> {burn, char, kind, position, elapsed}
var objects_state := {}

var _data: NativeTerrainData = null
var _wind: Callable = Callable()
var _weather: Callable = Callable()
var _water: Callable = Callable()
var _rng := RandomNumberGenerator.new()
var _seed := 0
var _cells := 0
var _step := 0.5
var _clock := 0.0
var _active := PackedInt32Array()
var _in_active := PackedByteArray()
var _burning := PackedInt32Array()
var _canopy := PackedFloat32Array()
var _water_cell := PackedByteArray()
var _memory := {} ## index -> PackedFloat32Array(grass,meadow,blades,tr,tg,tb,tw)
var _object_cell := {} ## id -> cell index
var _revision := -1
var _lit := false
var _dirty_cover := false

# ---------------------------------------------------------------- lifecycle

## `wind_sampler(position: Vector3) -> Vector3` in m/s (LocalWindField.sample),
## `weather_sampler() -> Dictionary` with ground_wet/snow_cover/rain in 0..1
## (studies/surface_weather.gd plus `_precipitation.state.x`), and
## `water_sampler(position: Vector3) -> bool` for cells standing under water.
func setup(data: NativeTerrainData, wind_sampler := Callable(), weather_sampler := Callable(), water_sampler := Callable(), rng_seed := 0) -> void:
	_data = data
	_wind = wind_sampler
	_weather = weather_sampler
	_water = water_sampler
	_seed = rng_seed
	_rng.seed = rng_seed
	_cells = data.meadow_side()
	_step = data.meadow_step()
	var count := _cells*_cells
	fuel = _blank(count)
	heat = _blank(count)
	burn = _blank(count)
	ash = _blank(count)
	_canopy = _blank(count)
	_in_active = PackedByteArray()
	_in_active.resize(count)
	_in_active.fill(0)
	_water_cell = PackedByteArray()
	_water_cell.resize(count)
	_water_cell.fill(0)
	_active = PackedInt32Array()
	_burning = PackedInt32Array()
	_memory.clear()
	objects_state.clear()
	_object_cell.clear()
	_clock = 0.0
	_lit = false
	_revision = -1
	rebuild()

static func _blank(count: int) -> PackedFloat32Array:
	var array := PackedFloat32Array()
	array.resize(count)
	array.fill(0.0)
	return array

## Re-seed fuel, canopy and the water mask from the world. Cells that are
## already alight keep the fuel they were burning; everything else follows the
## cover arrays. Call after the world changes (load, template, big edit).
func rebuild() -> void:
	if _data == null:
		return
	_revision = _data.objects_revision
	_canopy.fill(0.0)
	_object_cell.clear()
	for item: Dictionary in _data.objects:
		if item.asset == "waterfall":
			continue
		var index := _cell_of(Vector2(item.x,item.z))
		_object_cell[item.id] = index
		var group := FireField.group_of(item.asset)
		if index >= 0 and CANOPY_FUEL.has(group):
			_canopy[index] = minf(1.4,_canopy[index]+CANOPY_FUEL[group]*clampf(item.scale,0.2,2.0))
	for index in range(fuel.size()):
		var center := _center2(index)
		var wet := false
		if _water.is_valid():
			wet = bool(_water.call(_world(index,center)))
		_water_cell[index] = 1 if wet else 0
		if _in_active[index] != 0:
			continue
		if wet:
			fuel[index] = 0.0
		else:
			fuel[index] = clampf(maxf(_data.grass[index],maxf(_data.meadow[index],_data.blades[index])),0.0,1.0)+_canopy[index]

# ------------------------------------------------------------------ queries

func active() -> bool:
	return not _burning.is_empty() or not objects_state.is_empty()

func burning_cells() -> PackedInt32Array:
	return _burning

## id -> {burn, char, kind, position}
func burning_objects() -> Dictionary:
	var result := {}
	for id: int in objects_state:
		var state: Dictionary = objects_state[id]
		result[id] = {"burn":state.burn,"char":state["char"],"kind":state.kind,"position":state.position}
	return result

## 0..1, the `zs_fire` global.
func total_intensity() -> float:
	var sum := 0.0
	for index in _burning:
		sum += burn[index]
	for id: int in objects_state:
		sum += objects_state[id].burn
	return clampf(sum/maxf(1.0,intensity_scale),0.0,1.0)

func cell_center(index: int) -> Vector3:
	return _world(index,_center2(index))

func cell_at(position: Vector3) -> int:
	return _cell_of(Vector2(position.x,position.z))

func ash_center() -> Vector3:
	var total := 0.0
	var sum := Vector3.ZERO
	for index in _active:
		if ash[index] > 0.0:
			total += ash[index]
			sum += cell_center(index)*ash[index]
	return sum/total if total > 0.0 else Vector3.ZERO

# ----------------------------------------------------------------- ignition

## The single entry point. Lightning, explosives, the ember tool and tests all
## call this and nothing else.
func ignite(position: Vector3, radius := 0.6, strength := 1.0) -> void:
	if _data == null or radius <= 0.0 or strength <= 0.0:
		return
	var gate := clampf(_suppression(_conditions())*2.0,0.0,1.0)
	if gate <= 0.0:
		return
	var center := Vector2(position.x,position.z)
	var span := int(ceil(radius/_step))+1
	var origin := _cell_of(center)
	if origin < 0:
		return
	var ox := origin%_cells
	var oz := origin/_cells
	for dz in range(-span,span+1):
		for dx in range(-span,span+1):
			var x := ox+dx
			var z := oz+dz
			if x < 0 or z < 0 or x >= _cells or z >= _cells:
				continue
			var index := z*_cells+x
			if _water_cell[index] != 0:
				continue
			var distance := _center2(index).distance_to(center)
			if distance >= radius and index != origin:
				continue
			# Flat core, soft rim: the struck cell always catches, however the
			# point sits inside it, and the rim thins out to nothing.
			var falloff := 1.0 if index == origin else 1.0-smoothstep(radius*0.5,radius,distance)
			heat[index] = clampf(heat[index]+strength*gate*falloff,0.0,2.0)
			_touch(index)

# ------------------------------------------------------------------ advance

func advance(delta: float, paused := false) -> void:
	if _data == null or paused or delta <= 0.0:
		return
	if _data.objects_revision != _revision:
		rebuild()
	_clock += delta
	var steps := 0
	while _clock >= TICK and steps < 8:
		_clock -= TICK
		steps += 1
		_tick(TICK)
	if steps > 0:
		_flush_ground()

func _conditions() -> Dictionary:
	if not _weather.is_valid():
		return {"ground_wet":0.0,"snow_cover":0.0,"rain":0.0}
	var value: Variant = _weather.call()
	var source: Dictionary = value if value is Dictionary else {}
	return {
		"ground_wet":clampf(float(source.get("ground_wet",0.0)),0.0,1.0),
		"snow_cover":clampf(float(source.get("snow_cover",0.0)),0.0,1.0),
		"rain":clampf(float(source.get("rain",0.0)),0.0,1.0),
	}

func _suppression(weather: Dictionary) -> float:
	if weather.ground_wet >= wet_stall or weather.snow_cover >= snow_stall:
		return 0.0
	return (1.0-weather.ground_wet)*(1.0-weather.snow_cover)*(1.0-weather.rain*0.9)

func _wind_at(position: Vector3) -> Vector3:
	if not _wind.is_valid():
		return Vector3.ZERO
	var value: Variant = _wind.call(position)
	return value if value is Vector3 else Vector3.ZERO

func _tick(dt: float) -> void:
	var weather := _conditions()
	var suppression := _suppression(weather)
	var rain: float = weather.rain
	var deposits := {}
	# 1 + 5. Spread into the eight neighbours, then ember spotting downwind.
	for index in _burning:
		var strength: float = burn[index]
		if strength <= 0.0:
			continue
		var x := index%_cells
		var z := index/_cells
		var center := _world(index,_center2(index))
		var wind := _wind_at(center)
		if suppression > 0.0:
			for dz in range(-1,2):
				for dx in range(-1,2):
					if dx == 0 and dz == 0:
						continue
					var nx := x+dx
					var nz := z+dz
					if nx < 0 or nz < 0 or nx >= _cells or nz >= _cells:
						continue
					var neighbour := nz*_cells+nx
					if _water_cell[neighbour] != 0 or fuel[neighbour] <= 0.05 or burn[neighbour] > 0.0:
						continue
					var direction := Vector3(float(dx),0.0,float(dz)).normalized()
					var bias := clampf(direction.dot(wind)*wind_scale,wind_bias_min,wind_bias_max)
					var reach := 1.0 if dx == 0 or dz == 0 else 0.70710678
					var push := spread_rate*strength*suppression*(1.0+bias)*reach*dt
					deposits[neighbour] = float(deposits.get(neighbour,0.0))+push
		var gust := wind.length()
		if strength > 0.7 and gust > ember_wind and _rng.randf() < ember_chance*clampf((gust-ember_wind)/ember_ramp,0.0,1.0):
			var flat := Vector2(wind.x,wind.z)
			if flat.length() > 0.001:
				var reach_cells := _rng.randi_range(ember_min_cells,ember_max_cells)
				var step := flat.normalized()*float(reach_cells)
				var tx := x+roundi(step.x)
				var tz := z+roundi(step.y)
				if tx >= 0 and tz >= 0 and tx < _cells and tz < _cells:
					var target := tz*_cells+tx
					if _water_cell[target] == 0 and fuel[target] > 0.05:
						deposits[target] = float(deposits.get(target,0.0))+ember_heat*suppression
	for index: int in deposits:
		heat[index] = clampf(heat[index]+deposits[index],0.0,2.0)
		_touch(index)
	# 2. Objects push heat back into the cell they stand on so a torching tree
	#    keeps its ground alight for the whole forty seconds.
	for id: int in objects_state:
		var state: Dictionary = objects_state[id]
		var cell: int = _object_cell.get(id,-1)
		if cell >= 0 and state.burn > 0.0 and suppression > 0.0:
			heat[cell] = clampf(heat[cell]+state.burn*spread_rate*suppression*dt,0.0,2.0)
			_touch(cell)
	# 3 + 4. Ignite, consume, fade.
	var survivors := PackedInt32Array()
	var burned_out := PackedInt32Array()
	for index in _active:
		if heat[index] > 0.0 and burn[index] <= 0.0:
			if heat[index] > ignite_heat and fuel[index] > 0.05 and _water_cell[index] == 0:
				_remember(index)
				burn[index] = 1.0
				heat[index] = ignite_heat
				_ignited_cell(index)
			else:
				heat[index] = maxf(0.0,heat[index]*exp(-dt*(heat_decay+rain*2.0))-rain*0.25*dt)
				if heat[index] < 0.001:
					heat[index] = 0.0
		if burn[index] > 0.0:
			var rate := grass_burn_rate/(1.0+canopy_slowdown*_canopy[index])
			var consumed := minf(fuel[index],rate*dt)
			fuel[index] -= consumed
			ash[index] = clampf(ash[index]+consumed,0.0,1.0)
			if rain > 0.0:
				burn[index] = maxf(0.0,burn[index]-rain*rain_quench*dt)
			if fuel[index] < 0.02:
				burn[index] = maxf(0.0,burn[index]-dt/fade_seconds)
			if burn[index] <= 0.0:
				burn[index] = 0.0
				heat[index] = 0.0
				burned_out.append(index)
	for index in burned_out:
		cell_burned_out.emit(index)
	_advance_objects(dt,weather)
	# 6. Regrowth once the neighbourhood is cold.
	var hot := _hot_mask()
	for index in _active:
		if burn[index] <= 0.0 and ash[index] > 0.0 and hot[index] == 0:
			ash[index] = maxf(0.0,ash[index]-dt/maxf(1.0,regrow_seconds))
		if burn[index] > 0.0 or heat[index] > 0.0 or ash[index] > 0.0:
			survivors.append(index)
		else:
			_restore_cell(index)
			_in_active[index] = 0
	_active = survivors
	_dirty_cover = true
	_refresh_burning()
	if _lit and _burning.is_empty() and objects_state.is_empty():
		_lit = false
		fire_extinguished.emit()
		stroke_ended.emit()

func _refresh_burning() -> void:
	var list := PackedInt32Array()
	for index in _active:
		if burn[index] > 0.0:
			list.append(index)
	_burning = list

## Cells within three of anything still alight. Regrowth waits for this to clear
## so a burnt patch does not green up while its own edge is still burning.
func _hot_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(fuel.size())
	mask.fill(0)
	for index in _active:
		if burn[index] <= 0.0:
			continue
		var x := index%_cells
		var z := index/_cells
		for dz in range(maxi(0,z-3),mini(_cells,z+4)):
			for dx in range(maxi(0,x-3),mini(_cells,x+4)):
				mask[dz*_cells+dx] = 1
	return mask

func _ignited_cell(index: int) -> void:
	var center := cell_center(index)
	if not _lit:
		_lit = true
		stroke_started.emit()
		fire_started.emit(center)
	cell_ignited.emit(index,center)
	for id: int in _object_cell:
		if _object_cell[id] == index:
			_ignite_object(id)

# ------------------------------------------------------------------ objects

static func group_of(asset: String) -> String:
	if asset in FAST_ASSETS: return "fast"
	if asset in SHRUB_ASSETS: return "shrub"
	if asset in TREE_ASSETS: return "tree"
	if asset in DEAD_ASSETS: return "deadwood"
	if asset == "explosive": return "explosive"
	return "inert"

func _ignite_object(id: int) -> void:
	if objects_state.has(id):
		return
	var item := _data.object_by_id(id)
	if item.is_empty():
		return
	var group := FireField.group_of(item.asset)
	if group == "inert":
		return
	var position := _data.object_position(item)
	objects_state[id] = {"burn":1.0,"char":0.0,"kind":item.asset,"position":position,"elapsed":0.0}
	if not _lit:
		_lit = true
		stroke_started.emit()
		fire_started.emit(position)
	object_ignited.emit(id,item.asset,position)

func _advance_objects(dt: float, weather: Dictionary) -> void:
	if objects_state.is_empty():
		return
	var rain: float = weather.rain
	var finished := []
	var torched := []
	for id: int in objects_state:
		var state: Dictionary = objects_state[id]
		var group := FireField.group_of(state.kind)
		if group == "explosive":
			state.burn = minf(1.0,state.burn+dt)
			if state.burn > 0.5:
				explosive_triggered.emit(id,state.position)
				finished.append(id)
			continue
		if rain > 0.0:
			state.burn = maxf(0.0,state.burn-rain*rain_quench*dt)
			if state.burn <= 0.0:
				finished.append(id)
				continue
		state.elapsed += dt*state.burn
		var seconds: float = BURN_SECONDS.get(group,10.0)
		var progress := clampf(state.elapsed/seconds,0.0,1.0)
		if absf(progress-state["char"]) > 0.02 or progress >= 1.0:
			state["char"] = progress
			object_charring.emit(id,progress)
		if progress >= 1.0:
			torched.append(id)
	for id: int in torched:
		var state: Dictionary = objects_state[id]
		var group := FireField.group_of(state.kind)
		var cell: int = _object_cell.get(id,-1)
		if cell >= 0:
			ash[cell] = 1.0
			_remember(cell)
			_touch(cell)
		if group == "tree":
			_data.replace_object_asset(id,"snag",NativeObjectPose.encode_tint(Color(0.078,0.071,0.063)))
		elif group == "deadwood":
			pass
		else:
			_data.remove_object(id)
		object_burned_out.emit(id,state.kind,state.position)
		finished.append(id)
	for id: int in finished:
		objects_state.erase(id)
	# Canopy-to-canopy: a burning tree lights anything inside 1.5 * scale.
	var lit := []
	for id: int in objects_state:
		if FireField.group_of(objects_state[id].kind) != "tree":
			continue
		var source: Vector3 = objects_state[id].position
		for item: Dictionary in _data.objects:
			if objects_state.has(item.id) or item.asset == "waterfall":
				continue
			if FireField.group_of(item.asset) == "inert":
				continue
			var reach := 1.5*maxf(0.2,float(item.scale))
			if Vector2(item.x,item.z).distance_to(Vector2(source.x,source.z)) < reach:
				lit.append(item.id)
	for id: int in lit:
		_ignite_object(id)

# ------------------------------------------------------------------- ground

func _remember(index: int) -> void:
	if _memory.has(index):
		return
	var k := index*NativeTerrainTint.STRIDE
	_memory[index] = PackedFloat32Array([
		_data.grass[index],_data.meadow[index],_data.blades[index],
		_data.tint[k],_data.tint[k+1],_data.tint[k+2],_data.tint[k+3]])

## One batched write per tick. Cover goes to zero while a cell burns and lerps
## back as ash decays; the tint layer carries the scorch over the same curve.
func _flush_ground() -> void:
	if not _dirty_cover:
		return
	_dirty_cover = false
	var scorch := Color(0.290,0.275,0.263).srgb_to_linear()
	for index: int in _memory:
		var memory: PackedFloat32Array = _memory[index]
		var alive := 1.0-clampf(ash[index],0.0,1.0)
		if burn[index] > 0.0:
			alive = 0.0
		_data.grass[index] = memory[0]*alive
		_data.meadow[index] = memory[1]*alive
		_data.blades[index] = memory[2]*alive
		var k := index*NativeTerrainTint.STRIDE
		var coat := clampf(ash[index],0.0,1.0)
		_data.tint[k] = lerpf(memory[3],scorch.r,coat)
		_data.tint[k+1] = lerpf(memory[4],scorch.g,coat)
		_data.tint[k+2] = lerpf(memory[5],scorch.b,coat)
		_data.tint[k+3] = lerpf(memory[6],1.0,coat)

func _restore_cell(index: int) -> void:
	if not _memory.has(index):
		return
	var memory: PackedFloat32Array = _memory[index]
	_data.grass[index] = memory[0]
	_data.meadow[index] = memory[1]
	_data.blades[index] = memory[2]
	var k := index*NativeTerrainTint.STRIDE
	for i in range(NativeTerrainTint.STRIDE):
		_data.tint[k+i] = memory[3+i]
	fuel[index] = clampf(maxf(memory[0],maxf(memory[1],memory[2])),0.0,1.0)+_canopy[index]
	_memory.erase(index)

# -------------------------------------------------------------------- grid

func _touch(index: int) -> void:
	if _in_active[index] == 0:
		_in_active[index] = 1
		_active.append(index)

func _cell_of(point: Vector2) -> int:
	var half := 0.5*float(_cells)*_step
	if absf(point.x) > half or absf(point.y) > half:
		return -1
	return _data.meadow_cell(point)

func _center2(index: int) -> Vector2:
	return _data.meadow_position(index%_cells,index/_cells)+Vector2.ONE*_step*0.5

func _world(index: int, center: Vector2) -> Vector3:
	var height: Variant = _data.ground_height(center)
	return Vector3(center.x,float(height) if height != null else 0.0,center.y)

# -------------------------------------------------------------- persistence

## Optional `"fire"` sub-document. Sparse: only cells the fire has touched and
## the objects currently alight. An inert field documents as `{}`, so old saves
## with no `"fire"` key restore to exactly the same state.
func document() -> Dictionary:
	if _active.is_empty() and objects_state.is_empty() and _memory.is_empty():
		return {}
	var state := PackedFloat32Array()
	for index in _active:
		state.append_array(PackedFloat32Array([fuel[index],heat[index],burn[index],ash[index]]))
	var memory_cells := PackedInt32Array(_memory.keys())
	memory_cells.sort()
	var memory := PackedFloat32Array()
	for index in memory_cells:
		memory.append_array(_memory[index])
	var items := []
	for id: int in objects_state:
		var item: Dictionary = objects_state[id]
		items.append({
			"id":id,"kind":item.kind,
			"values":PackedFloat64Array([item.burn,item["char"],item.elapsed,item.position.x,item.position.y,item.position.z]).to_byte_array().hex_encode()})
	items.sort_custom(func(a,b): return a.id < b.id)
	return {
		"clock":PackedFloat64Array([_clock]).to_byte_array().hex_encode(),
		"lit":_lit,
		"cells":_active.to_byte_array().hex_encode(),
		"state":state.to_byte_array().hex_encode(),
		"memory_cells":memory_cells.to_byte_array().hex_encode(),
		"memory":memory.to_byte_array().hex_encode(),
		"objects":items,
	}

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	for key in ["clock","lit","cells","state","memory_cells","memory","objects"]:
		if not value.has(key):
			return false
	if not value.lit is bool or not value.objects is Array:
		return false
	if not _hex(value.clock,16) or not _hex(value.cells,0) or not _hex(value.state,0):
		return false
	if not _hex(value.memory_cells,0) or not _hex(value.memory,0):
		return false
	var count: int = value.cells.length()/8
	if value.state.length() != count*4*8 or value.memory_cells.length()%8 != 0:
		return false
	if value.memory.length() != (value.memory_cells.length()/8)*MEMORY_STRIDE*8:
		return false
	for item: Variant in value.objects:
		if not item is Dictionary or not GardenData._integer(item.get("id")) or not item.get("kind") is String:
			return false
		if not _hex(item.get("values"),96):
			return false
	return true

static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length()%2 != 0 or (length > 0 and value.length() != length):
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true

func restore(value: Dictionary = {}) -> void:
	if _data == null:
		return
	for index in _active.duplicate():
		_restore_cell(index)
	fuel.fill(0.0)
	heat.fill(0.0)
	burn.fill(0.0)
	ash.fill(0.0)
	_in_active.fill(0)
	_active = PackedInt32Array()
	_burning = PackedInt32Array()
	_memory.clear()
	objects_state.clear()
	_clock = 0.0
	_lit = false
	_rng.seed = _seed
	rebuild()
	if value.is_empty() or not FireField.valid(value):
		return
	var cells: PackedInt32Array = value.cells.hex_decode().to_int32_array()
	var state: PackedFloat32Array = value.state.hex_decode().to_float32_array()
	for i in range(cells.size()):
		var index: int = cells[i]
		if index < 0 or index >= fuel.size():
			continue
		fuel[index] = state[i*4]
		heat[index] = state[i*4+1]
		burn[index] = state[i*4+2]
		ash[index] = state[i*4+3]
		_touch(index)
	var memory_cells: PackedInt32Array = value.memory_cells.hex_decode().to_int32_array()
	var memory: PackedFloat32Array = value.memory.hex_decode().to_float32_array()
	for i in range(memory_cells.size()):
		var index: int = memory_cells[i]
		if index < 0 or index >= fuel.size():
			continue
		_memory[index] = memory.slice(i*MEMORY_STRIDE,(i+1)*MEMORY_STRIDE)
	for item: Dictionary in value.objects:
		var numbers: PackedFloat64Array = item.values.hex_decode().to_float64_array()
		objects_state[int(item.id)] = {"burn":numbers[0],"char":numbers[1],"kind":item.kind,
			"position":Vector3(numbers[3],numbers[4],numbers[5]),"elapsed":numbers[2]}
	_clock = value.clock.hex_decode().to_float64_array()[0]
	_lit = value.lit
	_refresh_burning()
	_dirty_cover = true
	_flush_ground()
