class_name FireEffects
extends Node3D
## Flames, smoke, embers, firelight and crackle for `FireField`.
##
## Everything here is MultiMesh quads plus a shader, because the project has no
## GPUParticles: one add-blended flame batch, one depth-writing smoke batch, one
## add-blended ember batch, a pool of four `OmniLight3D` and a pool of
## `AudioStreamPlayer3D` voices playing a synthesized crackle. The field owns the
## simulation; this node only reads `burning_cells()`, `burning_objects()` and a
## handful of signals, so nothing here can change how a fire spreads.
##
## Idle cost is one `active()` check per frame: with no fire and no lingering
## smoke the batches are hidden and `advance` returns immediately.

const FLAME_CAP := 384
const SMOKE_CAP := 256
const EMBER_CAP := 128
const LIGHT_COUNT := 4
const VOICE_COUNT := 4

const SMOKE_LIFE := 6.0
const SMOULDER_SECONDS := 20.0
const SMOKE_RISE := 1.2 ## m/s, the design's figure.
const EMBER_GRAVITY := 3.2
const LIGHT_RANGE := 6.0
const CLUSTER_RADIUS := 3.2
const CLUSTER_INTERVAL := 0.25
const TREE_HEIGHT := 4.0 ## Metres per unit scale for a tree-group asset.

## Object flame heights by `FireField.group_of` row.
const OBJECT_HEIGHT := {"tree":TREE_HEIGHT,"shrub":1.0,"fast":0.5,"deadwood":0.7,"explosive":0.6}

## Mirrors of the ambience settings. `setup` points `audio_source` at the
## scene's `_ambient_audio` when it has one, so the fire follows the Nature
## sounds toggle and its volume slider; clear it to drive them by hand.
var muted := false
var volume := 0.55
var audio_source: Node = null

var _field: FireField = null
var _scene: Node = null
var _wind_field: Node = null
var _atmosphere: Node = null
var _tremor: Object = null
var _data: NativeTerrainData = null

var _flames: MultiMeshInstance3D = null
var _smoke: MultiMeshInstance3D = null
var _embers: MultiMeshInstance3D = null
var _flame_material := ShaderMaterial.new()
var _smoke_material := ShaderMaterial.new()
var _ember_material := ShaderMaterial.new()
var _lights: Array[OmniLight3D] = []
var _voices: Array[AudioStreamPlayer3D] = []

var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _cluster_in := 0.0
var _crackle_in := 0.35
var _gain := 0.0
var _smoke_debt := 0.0
var _ember_debt := 0.0
var _puffs: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _smoulder := {} ## cell index -> seconds of smoulder left
var _object_size := {} ## id -> scale on the record at ignition
var _busy := false
var _idle_done := false
var _audio_paused := false

# ---------------------------------------------------------------- lifecycle

func setup(field: FireField, scene: Node) -> void:
	_field = field
	_scene = scene
	_rng.seed = 90210
	if _flames == null:
		_build()
	# Resolve the wind and camera hooks once; the scene may have neither.
	_wind_field = null
	_atmosphere = null
	_tremor = null
	_data = null
	if scene != null:
		var resident: Variant = scene.get("_resident_wind")
		if resident != null and resident.get("field") != null:
			_wind_field = resident.field
		var air: Variant = scene.get("_atmosphere")
		if air != null:
			_atmosphere = air
		var tremor: Variant = scene.get("_tremor")
		if tremor != null:
			_tremor = tremor
		var ambience: Variant = scene.get("_ambient_audio")
		if ambience is Node and ambience.get("muted") != null:
			audio_source = ambience
		var editor: Variant = scene.get("_chunk_editor")
		if editor != null and editor.get("data") != null:
			_data = editor.data
	if field != null:
		_connect(field.cell_burned_out,_on_cell_burned_out)
		_connect(field.object_ignited,_on_object_ignited)
		_connect(field.object_burned_out,_on_object_burned_out)
	_idle()

func _connect(source: Signal, target: Callable) -> void:
	if not source.is_connected(target):
		source.connect(target)

func clear() -> void:
	_puffs.clear()
	_sparks.clear()
	_smoulder.clear()
	_object_size.clear()
	_smoke_debt = 0.0
	_ember_debt = 0.0
	_gain = 0.0
	_clock = 0.0
	for voice in _voices:
		voice.stop()
	_idle_done = false
	_idle()

func _build() -> void:
	_flame_material.shader = preload("res://shaders/fire_flame.gdshader")
	_smoke_material.shader = preload("res://shaders/fire_smoke.gdshader")
	_ember_material.shader = preload("res://shaders/fire_ember.gdshader")
	# A tall narrow quad: the flame's own taper does the rest of the silhouette.
	_flames = _batch("Flames",_quad(Vector2(0.7,1.0)),_flame_material,FLAME_CAP,true)
	_smoke = _batch("Smoke",_quad(Vector2.ONE),_smoke_material,SMOKE_CAP,false)
	_embers = _batch("Embers",_quad(Vector2.ONE),_ember_material,EMBER_CAP,false)
	for i in range(LIGHT_COUNT):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0,0.55,0.18)
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
	var crackle := _build_audio()
	for i in range(VOICE_COUNT):
		var voice := AudioStreamPlayer3D.new()
		voice.stream = crackle
		voice.unit_size = 6.0
		voice.max_distance = 45.0
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)

static func _quad(size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	return mesh

func _batch(node_name: String, mesh: Mesh, material: ShaderMaterial, count: int, colors: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	node.multimesh.use_colors = colors
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.multimesh.visible_instance_count = 0
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The vertex stage displaces well past the instance transforms.
	node.custom_aabb = AABB(Vector3(-40,-4,-40),Vector3(80,60,80))
	node.visible = false
	add_child(node)
	return node

# ------------------------------------------------------------------ advance

func advance(delta: float, paused := false) -> void:
	# The one check an idle world pays for.
	if _field == null or (not _busy and not _field.active()):
		return
	if paused:
		if not _audio_paused:
			_audio_paused = true
			for voice in _voices:
				voice.stream_paused = true
		return
	if _audio_paused:
		_audio_paused = false
		for voice in _voices:
			voice.stream_paused = muted
	var dt := clampf(delta,0.0,0.1)
	_clock += dt
	_flame_material.set_shader_parameter("time",_clock)
	_smoke_material.set_shader_parameter("time",_clock)
	_ember_material.set_shader_parameter("time",_clock)
	var cells := _field.burning_cells()
	var objects := _field.burning_objects()
	var focus := _focus(cells,objects)
	var wind := _wind_at(focus)
	_age_smoulder(dt)
	var hot := _flame_pass(cells,objects,wind)
	_smoke_pass(dt,cells,objects,wind)
	_ember_pass(dt,hot,wind)
	_light_pass(dt,cells,objects)
	_audio_pass(dt,cells,objects,focus)
	_busy = _field.active() or not _puffs.is_empty() or not _sparks.is_empty() or not _smoulder.is_empty()
	if not _busy:
		_idle()
	else:
		_idle_done = false

## Everything off, once. Called on the frame the last spark dies and on setup.
func _idle() -> void:
	if _idle_done:
		return
	_idle_done = true
	_busy = false
	for node in [_flames,_smoke,_embers]:
		if node != null:
			node.multimesh.visible_instance_count = 0
			node.visible = false
	for light in _lights:
		light.visible = false
	for voice in _voices:
		voice.volume_db = -80.0
	_gain = 0.0

func _focus(cells: PackedInt32Array, objects: Dictionary) -> Vector3:
	if not objects.is_empty():
		for id: int in objects:
			return objects[id].position
	if not cells.is_empty():
		return _field.cell_center(cells[0])
	if not _smoulder.is_empty():
		for index: int in _smoulder:
			return _field.cell_center(index)
	return Vector3.ZERO

## `LocalWindField.sample` when the scene has one, the atmosphere's mean air
## otherwise, zero in a bare fixture.
func _wind_at(point: Vector3) -> Vector3:
	if _wind_field != null:
		var value: Variant = _wind_field.sample(point)
		if value is Vector3:
			return value
	if _atmosphere != null:
		var angle: float = _atmosphere._air_angle
		var strength: float = _atmosphere._air_strength
		return Vector3(cos(angle),0.0,sin(angle))*strength*3.0
	return Vector3.ZERO

# ------------------------------------------------------------------- flames

## Hottest cells first, then a column of tongues up every burning object, so a
## torching tree burns along its crown instead of glowing at the ankles.
func _flame_pass(cells: PackedInt32Array, objects: Dictionary, wind: Vector3) -> Array:
	var anchors: Array = []
	var hot: Array = []
	for id: int in objects:
		var state: Dictionary = objects[id]
		var strength: float = clampf(state.burn,0.0,1.0)
		if strength <= 0.01:
			continue
		var group := FireField.group_of(state.kind)
		var size: float = _object_size.get(id,1.0)
		var height: float = float(OBJECT_HEIGHT.get(group,1.0))*(size if group == "tree" else maxf(0.5,size))
		var count := clampi(int(ceil(height/0.7)),2,10)
		var base: Vector3 = state.position
		for j in range(count):
			var t := (float(j)+0.5)/float(count)
			var angle := float(id)*2.399963+float(j)*2.399963
			var spread := 0.32*maxf(0.3,size)*sin(t*PI)
			var point := base+Vector3(cos(angle)*spread,height*t,sin(angle)*spread)
			var lick := (0.75+0.95*sin(t*PI))*maxf(0.4,size)
			# Objects outrank ground cells for the cap: the torch is the subject.
			anchors.append([2.0+strength-t*0.5,point,lick*strength,fposmod(float(id)*0.6180339887+float(j)*0.2451,1.0),strength])
	for index in cells:
		var strength: float = clampf(_field.burn[index],0.0,1.0)
		if strength <= 0.01:
			continue
		var phase := fposmod(float(index)*0.6180339887,1.0)
		var jitter := fposmod(float(index)*0.7548776662,1.0)
		# Jitter inside the cell and vary the height, or a burning grid of
		# half-metre cells reads as a row of identical pickets.
		var center := _field.cell_center(index)+Vector3((phase-0.5)*0.34,-0.04,(jitter-0.5)*0.34)
		anchors.append([strength,center,(0.34+0.50*strength)*(0.72+0.62*jitter),phase,strength])
		if strength > 0.7:
			hot.append(center)
	if anchors.size() > FLAME_CAP:
		anchors.sort_custom(func(a,b): return a[0] > b[0])
		anchors.resize(FLAME_CAP)
	var mesh := _flames.multimesh
	var lean := Vector3(wind.x,0.0,wind.z)*0.055
	if lean.length() > 0.5:
		lean = lean.normalized()*0.5
	for i in range(anchors.size()):
		var anchor: Array = anchors[i]
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,anchor[1]))
		mesh.set_instance_custom_data(i,Color(anchor[3],anchor[2],lean.x,lean.z))
		mesh.set_instance_color(i,Color(1,1,1,clampf(anchor[4]*1.4,0.0,1.0)))
	mesh.visible_instance_count = anchors.size()
	_flames.visible = anchors.size() > 0
	return hot

# -------------------------------------------------------------------- smoke

func _on_cell_burned_out(index: int) -> void:
	_smoulder[index] = SMOULDER_SECONDS
	_busy = true
	_idle_done = false

func _age_smoulder(dt: float) -> void:
	if _smoulder.is_empty():
		return
	var dead: Array = []
	for index: int in _smoulder:
		_smoulder[index] -= dt
		if _smoulder[index] <= 0.0:
			dead.append(index)
	for index: int in dead:
		_smoulder.erase(index)

func _smoke_pass(dt: float, cells: PackedInt32Array, objects: Dictionary, wind: Vector3) -> void:
	# Rate: a plume off every burning cell, a thick one off every torching
	# object, and a thin wisp off the burnt-out ground for twenty seconds.
	var rate := minf(26.0,1.1*float(cells.size())+4.0*float(objects.size()))
	rate += minf(6.0,0.18*float(_smoulder.size()))
	_smoke_debt += rate*dt
	while _smoke_debt >= 1.0 and _puffs.size() < SMOKE_CAP:
		_smoke_debt -= 1.0
		_spawn_puff(cells,objects)
	if _smoke_debt > 4.0:
		_smoke_debt = 4.0
	var mesh := _smoke.multimesh
	var count := 0
	for i in range(_puffs.size()-1,-1,-1):
		var puff: Dictionary = _puffs[i]
		puff.age += dt
		if puff.age >= SMOKE_LIFE:
			_puffs.remove_at(i)
			continue
		var drift: Vector3 = wind*puff.drag
		puff.position += (Vector3(drift.x,SMOKE_RISE*puff.lift,drift.z))*dt
	for puff: Dictionary in _puffs:
		if count >= SMOKE_CAP:
			break
		var u: float = clampf(puff.age/SMOKE_LIFE,0.0,1.0)
		var size: float = lerpf(puff.size,puff.size*2.4,sqrt(u))
		var alpha: float = puff.strength*smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.45,1.0,u))
		mesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,puff.position))
		mesh.set_instance_custom_data(count,Color(puff.seed,size,alpha,u))
		count += 1
	mesh.visible_instance_count = count
	_smoke.visible = count > 0

func _spawn_puff(cells: PackedInt32Array, objects: Dictionary) -> void:
	var point := Vector3.ZERO
	var strength := 0.5
	var size := 0.6
	var roll := _rng.randf()
	if not objects.is_empty() and roll < 0.4:
		var ids: Array = objects.keys()
		var id: int = ids[_rng.randi_range(0,ids.size()-1)]
		var group := FireField.group_of(objects[id].kind)
		var height: float = float(OBJECT_HEIGHT.get(group,1.0))*maxf(0.4,float(_object_size.get(id,1.0)))
		point = objects[id].position+Vector3(_rng.randf_range(-0.4,0.4),height*_rng.randf_range(0.5,1.0),_rng.randf_range(-0.4,0.4))
		strength = 0.62
		size = 0.85
	elif not cells.is_empty() and (roll < 0.9 or _smoulder.is_empty()):
		var index: int = cells[_rng.randi_range(0,cells.size()-1)]
		point = _field.cell_center(index)+Vector3(_rng.randf_range(-0.2,0.2),_rng.randf_range(0.4,0.9),_rng.randf_range(-0.2,0.2))
		strength = 0.5
	elif not _smoulder.is_empty():
		var keys: Array = _smoulder.keys()
		var index: int = keys[_rng.randi_range(0,keys.size()-1)]
		point = _field.cell_center(index)+Vector3(_rng.randf_range(-0.2,0.2),0.15,_rng.randf_range(-0.2,0.2))
		# A smoulder wisp is thin, pale and slow: the field is spent, not alight.
		strength = 0.18*clampf(_smoulder[index]/SMOULDER_SECONDS,0.0,1.0)
		size = 0.55
	else:
		return
	_puffs.append({
		"position":point,"age":0.0,"seed":_rng.randf(),"size":size*_rng.randf_range(0.85,1.25),
		"strength":strength*0.58,"lift":_rng.randf_range(0.75,1.25),"drag":_rng.randf_range(0.55,0.95)})

# ------------------------------------------------------------------- embers

func _ember_pass(dt: float, hot: Array, wind: Vector3) -> void:
	if not hot.is_empty():
		_ember_debt += minf(14.0,0.7*float(hot.size()))*dt
		while _ember_debt >= 1.0 and _sparks.size() < EMBER_CAP:
			_ember_debt -= 1.0
			var point: Vector3 = hot[_rng.randi_range(0,hot.size()-1)]
			_sparks.append({
				"position":point+Vector3(_rng.randf_range(-0.15,0.15),_rng.randf_range(0.2,0.6),_rng.randf_range(-0.15,0.15)),
				"velocity":Vector3(_rng.randf_range(-0.3,0.3),_rng.randf_range(1.6,3.0),_rng.randf_range(-0.3,0.3)),
				"age":0.0,"life":_rng.randf_range(2.0,4.0),"seed":_rng.randf()})
	else:
		_ember_debt = 0.0
	var mesh := _embers.multimesh
	var count := 0
	for i in range(_sparks.size()-1,-1,-1):
		var spark: Dictionary = _sparks[i]
		spark.age += dt
		if spark.age >= spark.life:
			_sparks.remove_at(i)
			continue
		var velocity: Vector3 = spark.velocity
		velocity.y -= EMBER_GRAVITY*dt
		velocity = velocity.lerp(Vector3(wind.x,velocity.y,wind.z),1.0-exp(-dt*1.6))
		spark.velocity = velocity
		spark.position += velocity*dt
	for spark: Dictionary in _sparks:
		if count >= EMBER_CAP:
			break
		var u: float = clampf(spark.age/spark.life,0.0,1.0)
		var heat: float = 1.0-u
		mesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,spark.position))
		mesh.set_instance_custom_data(count,Color(spark.seed,0.075,smoothstep(1.0,0.55,u)*(0.35+0.65*heat),heat))
		count += 1
	mesh.visible_instance_count = count
	_embers.visible = count > 0

# -------------------------------------------------------------------- light

## Four greedy clusters over the burning points, recomputed four times a second
## so the pool does not swim between frames. Forward+ handles four extra omnis
## without touching the clustered-light budget.
func _light_pass(dt: float, cells: PackedInt32Array, objects: Dictionary) -> void:
	_cluster_in -= dt
	if _cluster_in <= 0.0:
		_cluster_in = CLUSTER_INTERVAL
		_assign_lights(cells,objects)
	for i in range(_lights.size()):
		var light := _lights[i]
		if not light.visible:
			continue
		var base: float = light.get_meta("base",1.0)
		# 7-11 Hz flicker: three incommensurate rates read as noise.
		var t := _clock*TAU+float(i)*2.1
		var flicker := 0.62+0.20*sin(t*7.0)+0.12*sin(t*9.3+1.7)+0.10*sin(t*11.0+0.4)
		light.light_energy = base*clampf(flicker,0.25,1.25)

func _assign_lights(cells: PackedInt32Array, objects: Dictionary) -> void:
	var points: Array = []
	for id: int in objects:
		var strength: float = clampf(objects[id].burn,0.0,1.0)
		if strength > 0.01:
			var group := FireField.group_of(objects[id].kind)
			var height: float = float(OBJECT_HEIGHT.get(group,1.0))*maxf(0.4,float(_object_size.get(id,1.0)))
			points.append([strength*3.0,objects[id].position+Vector3.UP*height*0.5])
	for index in cells:
		var strength: float = clampf(_field.burn[index],0.0,1.0)
		if strength > 0.05:
			points.append([strength,_field.cell_center(index)+Vector3.UP*0.35])
	var clusters: Array = []
	while points.size() > 0 and clusters.size() < LIGHT_COUNT:
		var best := 0
		for i in range(1,points.size()):
			if points[i][0] > points[best][0]:
				best = i
		var seed_point: Vector3 = points[best][1]
		var total := 0.0
		var sum := Vector3.ZERO
		var rest: Array = []
		for entry: Array in points:
			if entry[1].distance_to(seed_point) <= CLUSTER_RADIUS:
				total += entry[0]
				sum += entry[1]*entry[0]
			else:
				rest.append(entry)
		points = rest
		clusters.append([total,sum/maxf(total,0.0001)])
	for i in range(_lights.size()):
		var light := _lights[i]
		if i >= clusters.size():
			light.visible = false
			light.light_energy = 0.0
			continue
		light.visible = true
		light.global_position = clusters[i][1]
		light.set_meta("base",clampf(0.9+float(clusters[i][0])*0.35,0.9,4.0))

# -------------------------------------------------------------------- audio

## Pooled voices in the manner of `nature_audio.gd` footsteps, with the smoothed
## gain of `ambient_audio.update_state` and the synthesized source of
## `explosion_effects._build_audio`: no imported asset, no external dependency.
func _audio_pass(dt: float, cells: PackedInt32Array, objects: Dictionary, focus: Vector3) -> void:
	if audio_source != null:
		muted = audio_source.muted
		volume = audio_source.volume
	var size := float(cells.size())+3.0*float(objects.size())
	var wanted := clampf(size/22.0,0.0,1.0)*0.55
	_gain = lerpf(_gain,wanted,1.0-exp(-dt*3.0))
	for voice in _voices:
		voice.stream_paused = muted
		voice.volume_db = linear_to_db(maxf(0.0001,_gain*volume))
	if muted or wanted <= 0.0:
		return
	_crackle_in -= dt
	if _crackle_in > 0.0:
		return
	_crackle_in = _rng.randf_range(0.10,0.45)/maxf(0.2,wanted*2.0)
	var point := focus
	if not cells.is_empty():
		point = _field.cell_center(cells[_rng.randi_range(0,cells.size()-1)])
	for voice in _voices:
		if voice.playing:
			continue
		voice.global_position = point+Vector3.UP*0.4
		voice.pitch_scale = _rng.randf_range(0.82,1.24)
		voice.play()
		return

## A crackle: a soft filtered hiss with a scatter of sharp resinous pops.
static func _build_audio() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.6
	var count := int(rate*seconds)
	var samples := PackedByteArray()
	samples.resize(count*2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4127
	var pops := PackedFloat32Array()
	for i in range(11):
		pops.append(noise.randf_range(0.02,float(seconds)-0.08))
	var low := 0.0
	for i in range(count):
		var t := float(i)/float(rate)
		var raw := noise.randf_range(-1.0,1.0)
		low = lerpf(low,raw,0.30)
		var high := raw-low
		var value := low*0.30
		for p in pops:
			var age := t-float(p)
			if age >= 0.0 and age < 0.10:
				value += high*exp(-age*95.0)*1.15
		value *= minf(t*90.0,1.0)*(1.0-smoothstep(float(seconds)-0.08,float(seconds),t))
		samples.encode_s16(i*2,int(clampf(value,-1.0,1.0)*24000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = samples
	return sound

# ------------------------------------------------------------------ objects

func _on_object_ignited(id: int, kind: String, _position: Vector3) -> void:
	_busy = true
	_idle_done = false
	var size := 1.0
	if _data != null:
		var item := _data.object_by_id(id)
		if not item.is_empty():
			size = maxf(0.2,float(item.get("scale",1.0)))
	_object_size[id] = size
	if FireField.group_of(kind) == "tree" and _tremor != null:
		_tremor.add(0.15)

func _on_object_burned_out(id: int, _kind: String, _position: Vector3) -> void:
	_object_size.erase(id)
