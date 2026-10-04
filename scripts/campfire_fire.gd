extends Node3D
## The campfires' fire (docs/scenic/campfire.md). The campfires themselves
## are records on the land (asset "campfire", drawn by GardenView from
## scripts/campfire.gd: the ring of stones and the laid sticks); this follows
## them and keeps them burning. Soft things only, after the style rule:
##
## - **Flames**: FLAME_TONGUES cards a fire, every campfire in one MultiMesh
##   on the campfire's own flame shader (shaders/campfire_flame.gdshader):
##   a few clear flame shapes in three warm bands, and licks torn off the tip
##   that rise and dwindle. They dance on the GPU, lean with the wind and
##   shrink in rain.
## - **Coals**: a glowing bed laid on the ash under the sticks
##   (shaders/campfire_coals.gdshader), one MultiMesh, so the fire stands on
##   heat. It breathes slowly and dims in rain.
## - **Glow**: a soft camera-facing halo round each fire (the stone lamp's
##   halo shader), one MultiMesh, strong at night, faint by day.
## - **Smoke and sparks**: from the ACTIVE_FIRES fires nearest the camera
##   only, in two capped pools (SMOKE_CAP, SPARK_CAP) on the wildfire's smoke
##   and ember shaders. The smoke drifts with the wind (and the wind tool's
##   gusts); rain thins the sparks and thickens the smoke.
## - **Light**: the fires join the stone lamps' pool of real lights
##   (scripts/stone_lamp_lights.gd `set_guests`): the nearest MAX_LIGHTS of
##   lamps and fires together get one, so many fires never add more lights.
##   A fire's light is warm and flickers gently (`flicker`, under 1 Hz); it
##   is strong at night, small by day, dimmed by rain.
## - **Hearth**: one quiet looping voice at the nearest fire (`hearth_sound`,
##   synthesized here): a low soft breath of burning with sparse small
##   crackles of wood, an occasional snap. It follows the Nature sounds
##   toggle and volume.
##
## A campfire is a contained hearth: nothing here touches the wildfire's
## FireField, and the asset is "inert" to it (FireField `group_of`), so it
## neither spreads fire nor is burnt by one. Made and owned by
## NativeChunkEditor (`campfires`).

const Campfire = preload("res://scripts/campfire.gd")
const Lights = preload("res://scripts/stone_lamp_lights.gd")
const PollenWind = preload("res://scripts/pollen_wind.gd")
const ASSET := "campfire"
## The cards of one fire: (x, z) offset in m at fire scale 1, height in m, a
## phase so no two move together, and the kind: FLAME a body of flame, LICK
## a scrap torn off the tip that rises from it (its height is the flame's it
## rises off).
const FLAME := 0
const LICK := 1
const FLAME_TONGUES := [
	[Vector2(0.0,0.0),0.66,0.0,FLAME],
	[Vector2(0.08,0.05),0.42,0.31,FLAME],
	[Vector2(-0.07,-0.06),0.38,0.57,FLAME],
	[Vector2(-0.02,0.08),0.3,0.79,FLAME],
	[Vector2(0.0,0.0),0.66,0.13,LICK],
	[Vector2(0.03,-0.02),0.6,0.46,LICK],
	[Vector2(-0.03,0.02),0.62,0.78,LICK],
]
const FLAME_INTENSITY := 1.1
## The coal bed: its width (m at fire scale 1), height over the fire's foot
## (just over the ash), and strength.
const COALS_SIZE := 0.62
const COALS_LIFT := 0.03
const COALS_STRENGTH := 1.0
## The halo's width (m at fire scale 1), and strength by night and by day.
const HALO_SIZE := 2.0
const HALO_NIGHT := 0.6
const HALO_DAY := 0.06
## Real light: reach (m at fire scale 1), energy by night and by day, colour.
const LIGHT_RANGE := 5.0
const NIGHT_ENERGY := 1.8
const DAY_ENERGY := 0.35
const LIGHT_COLOR := Color("ff9a4a")
## Rain (0..1) takes this share off the flames' height, the light and glow.
const RAIN_FLAME := 0.45
const RAIN_LIGHT := 0.6
## Seconds for rain to reach the fire, between re-reading the records, and
## between laying the flames again (their lean and height).
const RAIN_SECONDS := 3.0
const READ_SECONDS := 0.5
const LAY_SECONDS := 0.1
## How far a flame leans for a wind of 1 m/s (share of its height), at most.
const LEAN := 0.12
const LEAN_MOST := 0.35
## Only this many fires (the nearest the camera) smoke, spark and crackle.
const ACTIVE_FIRES := 6
const PICK_SECONDS := 0.25
const SMOKE_CAP := 72
const SMOKE_RATE := 1.3
const SMOKE_RAIN := 2.0
const SMOKE_LIFE := 5.0
const SMOKE_RISE := 0.5
const SPARK_CAP := 60
const SPARK_RATE := 2.4
const SPARK_GRAVITY := 1.2
## The hearth's voice: its loudness at volume 1, the distance (m) it holds
## full loudness to, and its reach (m).
const HEARTH_GAIN := 0.32
const HEARTH_NEAR := 2.5
const HEARTH_REACH := 22.0
## The loop: its length (s), sample rate, and the seam's crossfade (s).
const HEARTH_SECONDS := 9.0
const HEARTH_RATE := 22050
const HEARTH_SEAM := 0.4
const HEARTH_PEAK := 0.85

var editor: Node
## The fires as last read: {"id", "foot" (global), "at" (global, the fire's
## middle), "scale" (world), "phase", "lean" (world Vector3)}.
var fires: Array[Dictionary] = []
## 0..1: how dark it is (the lamps' eased glow) and how hard it rains (eased).
var night := 0.0
var rain := 0.0
## For probes: >= 0 holds the rain at this instead of the sky's.
var rain_override := -1.0
## The flames' height now as a share of their full height (rain lowers it).
var tall := 1.0
var flames: MultiMeshInstance3D
var halos: MultiMeshInstance3D
var coals: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var sparks: MultiMeshInstance3D
var voice: AudioStreamPlayer3D
## The live smoke puffs and sparks: {"position", "velocity", "age", "life", "seed", "size"}.
var puffs: Array[Dictionary] = []
var embers: Array[Dictionary] = []
## Indices into `fires` of the ones nearest the camera.
var active: Array[int] = []
var _flame_material := ShaderMaterial.new()
var _halo_material := ShaderMaterial.new()
var _coals_material := ShaderMaterial.new()
var _smoke_material := ShaderMaterial.new()
var _spark_material := ShaderMaterial.new()
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _revision := -1
var _count := -1
var _read_in := 0.0
var _lay_in := 0.0
var _pick_in := 0.0
var _smoke_debt := 0.0
var _spark_debt := 0.0
var _scale := 1.0
var _by_id := {}

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	name = "Campfires"
	_rng.seed = 51207
	_flame_material.shader = preload("res://shaders/campfire_flame.gdshader")
	_flame_material.set_shader_parameter("intensity",FLAME_INTENSITY)
	_smoke_material.shader = preload("res://shaders/fire_smoke.gdshader")
	_spark_material.shader = preload("res://shaders/fire_ember.gdshader")
	_halo_material.shader = preload("res://shaders/stone_lamp_halo.gdshader")
	_halo_material.set_shader_parameter("tint",LIGHT_COLOR)
	_coals_material.shader = preload("res://shaders/campfire_coals.gdshader")
	_coals_material.set_shader_parameter("strength",COALS_STRENGTH)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	flames = _batch("Flames",quad,_flame_material,true)
	halos = _batch("Glow",quad,_halo_material,false)
	var bed := PlaneMesh.new()
	bed.size = Vector2.ONE
	coals = _batch("Coals",bed,_coals_material,true)
	smoke = _batch("Smoke",quad,_smoke_material,false)
	sparks = _batch("Sparks",quad,_spark_material,false)
	smoke.multimesh.instance_count = SMOKE_CAP
	sparks.multimesh.instance_count = SPARK_CAP
	for node in [smoke,sparks]: node.multimesh.visible_instance_count = 0
	voice = AudioStreamPlayer3D.new()
	voice.name = "Hearth"
	voice.stream = hearth_sound()
	voice.unit_size = HEARTH_NEAR
	voice.max_distance = HEARTH_REACH
	voice.volume_db = -80.0
	add_child(voice)

func _batch(label: String, mesh: Mesh, material: Material, colours: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	node.multimesh.use_colors = colours
	node.multimesh.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)
	return node

## A fire's gentle flicker, 0.71..1.01: three slow sines (under 1 Hz), each
## fire its own phase, so the light breathes rather than strobes.
static func flicker(phase: float, t: float) -> float:
	var p := phase*TAU
	return 0.86+0.07*sin(t*2.1+p)+0.05*sin(t*3.3+p*2.0+1.3)+0.03*sin(t*5.2+p*3.0+0.4)

## Fire `id`'s light energy now: by night and day, dimmed by rain, with its
## flicker. The lamps' pool (`guest_energy`) reads it for each light it gives.
func energy(id: int) -> float:
	var fire: Variant = _by_id.get(id)
	if fire == null: return 0.0
	var base := lerpf(DAY_ENERGY,NIGHT_ENERGY,night)*(1.0-RAIN_LIGHT*rain)
	return base*flicker(float(fire.phase),_clock)

## The dark the fires answer to: the lamps' eased glow (the same sky).
func _night() -> float:
	var lamps: Variant = editor.get("lamps")
	if lamps == null: return 0.0
	return float(lamps.glow)

## Rain and snow falling now, 0..1.
func _rain() -> float:
	if rain_override >= 0.0: return rain_override
	var scene: Variant = editor.get("scene")
	var sky: Variant = scene.get("_precipitation") if scene != null else null
	if sky == null or not sky.get("state") is Vector2: return 0.0
	return clampf(sky.state.x+sky.state.y,0.0,1.0)

func _process(delta: float) -> void:
	if editor == null or editor.get("data") == null: return
	var data: NativeTerrainData = editor.data
	_read_in -= delta
	if data.objects_revision != _revision or data.objects.size() != _count or _read_in <= 0.0: _read(data)
	if fires.is_empty() and puffs.is_empty() and embers.is_empty():
		voice.volume_db = -80.0
		if voice.playing: voice.stop()
		return
	var dt := clampf(delta,0.0,0.1)
	_clock += dt
	night = _night()
	rain = move_toward(rain,_rain(),dt/RAIN_SECONDS)
	for material in [_flame_material,_coals_material,_smoke_material,_spark_material]: material.set_shader_parameter("time",_clock)
	_halo_material.set_shader_parameter("glow",lerpf(HALO_DAY,HALO_NIGHT,night)*(1.0-RAIN_LIGHT*rain))
	halos.visible = not fires.is_empty()
	_lay_in -= dt
	if _lay_in <= 0.0:
		_lay_in = LAY_SECONDS
		_lay()
	_pick_in -= dt
	if _pick_in <= 0.0:
		_pick_in = PICK_SECONDS
		_pick()
	_smoke(dt)
	_sparks(dt)
	_hearth()

## Reads the campfire records into world points, and hands them to the
## lamps' light pool as guests.
func _read(data: NativeTerrainData) -> void:
	_revision = data.objects_revision
	_count = data.objects.size()
	_read_in = READ_SECONDS
	var terrain: Node3D = editor.terrain
	_scale = terrain.global_basis.get_scale().x
	var old := _by_id
	var found: Array[Dictionary] = []
	_by_id = {}
	for item: Dictionary in data.objects:
		if str(item.asset) != ASSET: continue
		var id := int(item.id)
		var size := float(item.scale)
		var foot: Vector3 = data.object_position(item)
		var fire := {"id":id,"foot":terrain.to_global(foot+Vector3.UP*Campfire.FLAME_FOOT*size),
			"bed":terrain.to_global(foot+Vector3.UP*COALS_LIFT*size),
			"at":terrain.to_global(foot+Vector3.UP*Campfire.FIRE_HEIGHT*size),"scale":size*_scale,
			"plate":Vector2(float(item.x),float(item.z)),"phase":fposmod(float(id)*0.6180339887,1.0),
			"lean":old[id].lean if old.has(id) else Vector3.ZERO}
		found.append(fire)
		_by_id[id] = fire
	fires = found
	var guests: Array[Dictionary] = []
	for fire in fires: guests.append({"id":fire.id,"at":fire.at,"range":LIGHT_RANGE*float(fire.scale),"color":LIGHT_COLOR})
	var lamps: Variant = editor.get("lamps")
	if lamps != null: lamps.set_guests(guests,ASSET,energy)
	flames.multimesh.instance_count = fires.size()*FLAME_TONGUES.size()
	halos.multimesh.instance_count = fires.size()
	coals.multimesh.instance_count = fires.size()
	var bounds := AABB()
	for i in range(fires.size()):
		var fire: Dictionary = fires[i]
		halos.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*float(fire.scale)*HALO_SIZE),fire.at))
		halos.multimesh.set_instance_custom_data(i,Color())
		var lie := Basis(terrain.global_basis.get_rotation_quaternion())
		coals.multimesh.set_instance_transform(i,Transform3D(lie.scaled(Vector3.ONE*float(fire.scale)*COALS_SIZE),fire.bed))
		coals.multimesh.set_instance_custom_data(i,Color(float(fire.phase),0.0,0.0,0.0))
		coals.multimesh.set_instance_color(i,Color(1,1,1,1))
		bounds = AABB(fire.foot,Vector3.ZERO) if i == 0 else bounds.expand(fire.foot)
	# The shaders move the quads off their instance points: room round them all.
	var room := bounds.grow(3.0*maxf(1.0,_scale))
	room.size.y += 6.0*maxf(1.0,_scale)
	for node in [flames,halos,coals,smoke,sparks]: node.custom_aabb = room if not fires.is_empty() else AABB()
	flames.visible = not fires.is_empty()
	coals.visible = not fires.is_empty()
	if fires.is_empty():
		halos.visible = false
		active.clear()
	_lay()
	_pick()

## Lays every fire's cards: where, how tall (less in rain) and how they
## lean (with the wind there, eased); and dims the coals in rain.
func _lay() -> void:
	if fires.is_empty(): return
	var scene: Node = editor.get("scene")
	var terrain: Node3D = editor.terrain
	var mesh := flames.multimesh
	tall = 1.0-RAIN_FLAME*rain
	var life := clampf(1.0-0.35*rain,0.0,1.0)
	var n := FLAME_TONGUES.size()
	for i in range(fires.size()):
		var fire: Dictionary = fires[i]
		var drift: Vector2 = PollenWind.at(scene,terrain,fire.plate) if scene != null else Vector2.ZERO
		var wind := terrain.global_basis*Vector3(drift.x,0.0,drift.y)
		var want := wind.normalized()*minf(LEAN_MOST,wind.length()*LEAN) if wind.length() > 0.001 else Vector3.ZERO
		fire.lean = (fire.lean as Vector3).lerp(want,0.25)
		fire.wind = wind
		var s: float = fire.scale
		for k in range(n):
			var tongue: Array = FLAME_TONGUES[k]
			var offset: Vector2 = tongue[0]
			var at: Vector3 = fire.foot+Vector3(offset.x,0.0,offset.y)*s
			mesh.set_instance_transform(i*n+k,Transform3D(Basis.IDENTITY,at))
			mesh.set_instance_custom_data(i*n+k,Color(fposmod(float(fire.phase)+float(tongue[2]),1.0),float(tongue[1])*s*tall,fire.lean.x,fire.lean.z))
			mesh.set_instance_color(i*n+k,Color(float(tongue[3]),0,0,life))
		coals.multimesh.set_instance_color(i,Color(1,1,1,1.0-0.5*rain))

## The fires nearest the camera, which smoke, spark and crackle.
func _pick() -> void:
	active.clear()
	if fires.is_empty(): return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var order := range(fires.size())
	order.sort_custom(func(a: int, b: int) -> bool: return eye.distance_squared_to(fires[a].at) < eye.distance_squared_to(fires[b].at))
	for k in range(mini(ACTIVE_FIRES,order.size())): active.append(int(order[k]))

## Thin smoke off the nearest fires, drifting with the wind, thicker in rain.
func _smoke(dt: float) -> void:
	_smoke_debt += float(active.size())*(SMOKE_RATE+SMOKE_RAIN*rain)*dt
	while _smoke_debt >= 1.0:
		_smoke_debt -= 1.0
		if puffs.size() >= SMOKE_CAP or active.is_empty(): continue
		var fire: Dictionary = fires[active[_rng.randi_range(0,active.size()-1)]]
		var s: float = fire.scale
		puffs.append({"position":fire.foot+Vector3(_rng.randf_range(-0.08,0.08)*s,0.55*s,_rng.randf_range(-0.08,0.08)*s),
			"wind":fire.get("wind",Vector3.ZERO),"age":0.0,"life":SMOKE_LIFE*_rng.randf_range(0.8,1.2),"seed":_rng.randf(),
			"size":0.32*s*_rng.randf_range(0.85,1.2),"rise":SMOKE_RISE*s*_rng.randf_range(0.8,1.2),"strength":0.16+0.14*rain})
	_smoke_debt = minf(_smoke_debt,3.0)
	var mesh := smoke.multimesh
	var count := 0
	for i in range(puffs.size()-1,-1,-1):
		var puff: Dictionary = puffs[i]
		puff.age += dt
		if puff.age >= puff.life:
			puffs.remove_at(i)
			continue
		# The puff leans downwind the higher it climbs.
		var u: float = puff.age/puff.life
		var wind: Vector3 = puff.wind
		puff.position += (Vector3.UP*float(puff.rise)+wind*0.6*smoothstep(0.0,0.4,u))*dt
	for puff in puffs:
		var u: float = puff.age/puff.life
		var size: float = lerpf(puff.size,puff.size*3.0,sqrt(u))
		var alpha: float = float(puff.strength)*smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.4,1.0,u))
		mesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,puff.position))
		mesh.set_instance_custom_data(count,Color(puff.seed,size,alpha,0.35+0.65*u))
		count += 1
	mesh.visible_instance_count = count
	smoke.visible = count > 0

## Sparks rising off the nearest fires, fewer in rain.
func _sparks(dt: float) -> void:
	_spark_debt += float(active.size())*SPARK_RATE*(1.0-0.8*rain)*dt
	while _spark_debt >= 1.0:
		_spark_debt -= 1.0
		if embers.size() >= SPARK_CAP or active.is_empty(): continue
		var fire: Dictionary = fires[active[_rng.randi_range(0,active.size()-1)]]
		var s: float = fire.scale
		embers.append({"position":fire.foot+Vector3(_rng.randf_range(-0.1,0.1)*s,0.2*s,_rng.randf_range(-0.1,0.1)*s),
			"velocity":Vector3(_rng.randf_range(-0.15,0.15),_rng.randf_range(0.9,1.6),_rng.randf_range(-0.15,0.15))*s,
			"wind":fire.get("wind",Vector3.ZERO),"age":0.0,"life":_rng.randf_range(0.9,1.8),"seed":_rng.randf(),"size":0.05*s})
	_spark_debt = minf(_spark_debt,3.0)
	var mesh := sparks.multimesh
	var count := 0
	for i in range(embers.size()-1,-1,-1):
		var spark: Dictionary = embers[i]
		spark.age += dt
		if spark.age >= spark.life:
			embers.remove_at(i)
			continue
		var velocity: Vector3 = spark.velocity
		velocity.y -= SPARK_GRAVITY*dt
		var wind: Vector3 = spark.wind
		velocity = velocity.lerp(Vector3(wind.x,velocity.y,wind.z),1.0-exp(-dt*1.2))
		spark.velocity = velocity
		spark.position += velocity*dt
	for spark in embers:
		var u: float = spark.age/spark.life
		var heat := 1.0-u
		mesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,spark.position))
		mesh.set_instance_custom_data(count,Color(spark.seed,spark.size,smoothstep(1.0,0.5,u)*(0.4+0.6*heat),heat))
		count += 1
	mesh.visible_instance_count = count
	sparks.visible = count > 0

## The hearth's voice at the nearest fire, looping, following the ambience.
func _hearth() -> void:
	var scene: Variant = editor.get("scene")
	var ambience: Variant = scene.get("_ambient_audio") if scene != null else null
	var muted: bool = ambience != null and bool(ambience.get("muted"))
	var volume: float = float(ambience.get("volume")) if ambience != null and ambience.get("volume") != null else 0.55
	if muted or active.is_empty():
		voice.volume_db = -80.0
		if voice.playing: voice.stop()
		return
	voice.volume_db = linear_to_db(maxf(0.0001,HEARTH_GAIN*volume*(1.0-0.5*rain)))
	voice.global_position = fires[active[0]].at
	if not voice.playing: voice.play(_rng.randf_range(0.0,HEARTH_SECONDS))

## The sound of a small fire, synthesized once, a seamless HEARTH_SECONDS
## loop. Two layers, neither of them raw noise:
## - the breath: noise through two low-pass poles (about 250 Hz), swelling
##   and settling on a few slow beats, quiet under everything;
## - the wood: sparse crackles, about three a second, mostly tiny, now and
##   then a snap; each a few clicks close together, every click a short
##   woody knock (a damped tone, 0.9 to 2.6 kHz) over a breath of band-passed
##   noise, gone within about 10 ms.
## The tail is crossfaded into the head, so the loop has no seam.
static func hearth_sound() -> AudioStreamWAV:
	var rate := HEARTH_RATE
	var count := int(rate*HEARTH_SECONDS)
	var seam := int(rate*HEARTH_SEAM)
	var total := count+seam
	var noise := RandomNumberGenerator.new()
	noise.seed = 90211
	var mix := PackedFloat32Array()
	mix.resize(total)
	# The breath.
	var low_a := 0.0
	var low_b := 0.0
	for i in range(total):
		var t := float(i)/rate
		low_a = lerpf(low_a,noise.randf_range(-1.0,1.0),0.07)
		low_b = lerpf(low_b,low_a,0.07)
		var swell := 0.7+0.18*sin(t*TAU*0.23)+0.12*sin(t*TAU*0.61+1.3)
		mix[i] = low_b*0.55*swell
	# The wood.
	var bright := PackedFloat32Array()
	bright.resize(total)
	var fast := 0.0
	var slow := 0.0
	for i in range(total):
		var white := noise.randf_range(-1.0,1.0)
		fast = lerpf(fast,white,0.55)
		slow = lerpf(slow,white,0.12)
		bright[i] = fast-slow
	var at := noise.randf_range(0.05,0.3)
	while at < float(total)/rate-0.05:
		var loud := 0.08+0.55*pow(noise.randf(),3.0)
		var clicks := noise.randi_range(1,4)
		var when := at
		for c in range(clicks):
			var tone := noise.randf_range(900.0,2600.0)
			var decay := noise.randf_range(450.0,1100.0)
			var size := loud*noise.randf_range(0.45,1.0)
			var from := int(when*rate)
			for j in range(int(0.012*rate)):
				if from+j >= total: break
				var age := float(j)/rate
				var fade := exp(-age*decay)*minf(1.0,age*rate/3.0)
				mix[from+j] += size*fade*(0.6*sin(TAU*tone*age)+0.9*bright[from+j])
			when += noise.randf_range(0.006,0.045)
		at += -log(maxf(noise.randf(),0.0001))/3.0
	# Close the loop: the tail fades into the head.
	for i in range(seam):
		var k := float(i)/seam
		mix[i] = mix[i]*sin(k*PI*0.5)+mix[count+i]*cos(k*PI*0.5)
	# Its loudest snap at HEARTH_PEAK, so HEARTH_GAIN alone sets the level.
	var peak := 0.0001
	for i in range(count): peak = maxf(peak,absf(mix[i]))
	var samples := PackedByteArray()
	samples.resize(count*2)
	for i in range(count):
		samples.encode_s16(i*2,int(clampf(mix[i]*HEARTH_PEAK/peak,-1.0,1.0)*32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = samples
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = count
	return sound
