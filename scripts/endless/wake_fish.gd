extends Node3D
## Fish that answer the plane: skim a pond, a lake or a river low and fast and
## they burst out to either side of its line, flung up as it comes and still
## scattering after it has gone, each with a boil, a ring, a crown of drops and
## a plop going back in. The lakes (the sea's level standing inside the land)
## have fish now too: over one, low, the odd fish leaps ahead of the plane.
##
## How hard is the water's own say (WaterContact `stir`): closer and faster,
## more of them. The camera sits about 10 m behind the plane, and at 57 m/s
## that passes a fish in a fifth of a second, so most break the water AHEAD of
## the plane (LEAD), to be in the air as it goes by; the rest (the trail behind
## it, TRAIL) are there for a turn back over the water.
##
## Nothing here touches the plane. Every leap is laid once and then runs on the
## GPU, worked out from its start (shaders/wake_fish.gdshader, the fish;
## shaders/wake_splash.gdshader, its splashes): two pools of MultiMesh slots,
## taken in turn, with the whole buffer set only on a frame that lays one. What
## runs here each frame is the trigger and the plops; the idle leaps in the
## ponds stay EndlessFish's.
##
## --wake-fish=0 none of it.

const Models = preload("res://scripts/life_models.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")

## The kinds: [kind, weight].
const KINDS := [["rudd",1.0],["carp",0.6]]
## Fish in the air at once, of a kind; splashes (two a fish) at once.
const POOL := 34
const SPLASHES := 200
## Length (m) drawn: past a pond fish's, or nothing reads at this speed.
const LONG := Vector2(0.85,1.35)
## Peak over the water (m), run along it (m) for a metre of fish.
const PEAK := Vector2(1.5,2.9)
const RUN := Vector2(3.0,6.5)
const GRAVITY := 9.8
## The centre starts this share of its length under (the shader's sink_share).
const SINK := 0.3
## The water boils this long (s) before it breaks.
const BOIL := 0.32
## A leap laid every SPACING m at full stir and BRISK m/s (by speed squared, so
## faster is more of them a metre), at most MOST on one frame.
const SPACING := 2.6
const BRISK := 57.0
const MOST := 3
## The stir to this power: a low pass sets off far more than a high one.
const STIR_POW := 1.15
const STIR_LEAST := 0.04
## The share laid ahead of the plane. Those are LEAD s of its speed ahead, and
## break WAIT s from now; the rest TRAIL m behind, breaking TRAIL_WAIT s from now.
const AHEAD_SHARE := 0.7
const LEAD := Vector2(0.55,1.3)
const WAIT := Vector2(0.03,0.28)
const TRAIL := Vector2(2.0,34.0)
const TRAIL_WAIT := Vector2(0.05,0.6)
## How far out from the line (m): past the wingtip, up to SCATTER more.
const SCATTER := 20.0
## Spots tried for a leap; leaps owed the moment the plane reaches the water.
const TRIES := 3
const FIRST := 2.0
## Water this deep at least (m) where it breaks and where it lands.
const DEEP := 0.5
## A lake's the sea's level at least this far (m) inside the world's edge line.
const LAKE_IN := 300.0
## Idle over a lake: this high at most (m), a leap every AGAIN s, FORE m ahead.
const IDLE_ABOVE := 90.0
const IDLE_AGAIN := Vector2(0.9,2.4)
const IDLE_FORE := Vector2(70.0,260.0)
const IDLE_SIDE := 90.0
## Splashes sit this far over the water (m), as WaterContact's marks: the
## sea's swell isn't all on the CPU.
const LIFT_SEA := 0.25
const LIFT_STILL := 0.04
## The plops: heard within HEAR m, one every PLOP_EVERY s at most, a lower
## volume the further and the smaller.
const HEAR := 140.0
const PLOP_EVERY := 0.06
const PLOP_QUEUE := 16
const PLOPS := 4
const PLOP_DB := Vector2(-16.0,-7.0)

var _field: RefCounted
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _owed := 0.0
var _stirring := false
var _idle_next := 0.0
## Until this moment something is alive (s): the nodes are shown till then.
var _alive_to := -1.0
var _f_mm: Array[MultiMesh] = []
var _f_node: Array[MultiMeshInstance3D] = []
var _f_mat: Array[ShaderMaterial] = []
var _f_buf: Array[PackedFloat32Array] = []
var _f_next := PackedInt32Array()
var _f_len := PackedFloat32Array()
var _f_dirty := PackedByteArray()
var _s_mm: MultiMesh
var _s_node: MultiMeshInstance3D
var _s_mat: ShaderMaterial
var _s_buf := PackedFloat32Array()
var _s_next := 0
var _s_dirty := false
var _kind_total := 0.0
## The plops to come: when (s), where and how big.
var _p_when := PackedFloat32Array()
var _p_at := PackedVector3Array()
var _p_size := PackedFloat32Array()
var _p_next := 0
var _p_wait := 0.0
var _players: Array[AudioStreamPlayer3D] = []
var _streams: Array = []
## For the numbers and probes: leaps laid, of them by the wake, the stir now,
## the last spot, ms this frame and its mean.
var leaps_total := 0
var wake_total := 0
var stir := 0.0
var last_at := Vector3.ZERO
var ms := 0.0
var ms_avg := 0.0

## --wake-fish=0 none.
static func wanted() -> bool:
	return not ("--wake-fish=0" in preload("res://scripts/launch_args.gd").user_args())

func setup(land_seed: int, field: RefCounted) -> void:
	_field = field
	_rng.seed = hash([land_seed,"wake fish"])
	var shader: Shader = load("res://shaders/wake_fish.gdshader")
	_f_next.resize(KINDS.size())
	_f_len.resize(KINDS.size())
	_f_dirty.resize(KINDS.size())
	for k in KINDS.size():
		var kind: String = KINDS[k][0]
		_kind_total += float(KINDS[k][1])
		var length := float(Models.FISH_KINDS[kind].length)
		_f_len[k] = length
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("fish_length",length)
		mat.set_shader_parameter("nose_z",length*0.42)
		mat.set_shader_parameter("gravity",GRAVITY)
		mat.set_shader_parameter("sink_share",SINK)
		_f_mat.append(mat)
		var mm := _multimesh("Fish"+kind,Models.fish(null,kind,0),POOL,mat)
		_f_mm.append(mm)
		_f_node.append(get_child(get_child_count()-1))
		_f_buf.append(_dead(POOL))
	_s_mat = ShaderMaterial.new()
	_s_mat.shader = load("res://shaders/wake_splash.gdshader")
	_s_mat.set_shader_parameter("gravity",GRAVITY)
	_s_mm = _multimesh("Splash",_splash_mesh(),SPLASHES,_s_mat)
	_s_node = get_child(get_child_count()-1)
	_s_buf = _dead(SPLASHES)
	# Shown for the first moments, all folded away: the pipelines build at the
	# start and not at the first lake.
	_alive_to = 0.5
	_p_when.resize(PLOP_QUEUE)
	_p_when.fill(-1.0)
	_p_at.resize(PLOP_QUEUE)
	_p_size.resize(PLOP_QUEUE)
	if FlightSound.wanted():
		for path: String in ["res://assets/audio/fish-plop-1.wav","res://assets/audio/fish-plop-2.wav",
				"res://assets/audio/foley/water-pop-1.wav","res://assets/audio/foley/water-pop-3.wav","res://assets/audio/foley/water-pop-5.wav"]:
			var s: AudioStream = load(path)
			if s != null: _streams.append(s)
		for i in PLOPS:
			var a := AudioStreamPlayer3D.new()
			a.unit_size = 14.0
			a.max_distance = HEAR
			a.panning_strength = 0.6
			add_child(a)
			_players.append(a)

func _multimesh(n: String, mesh: Mesh, count: int, mat: ShaderMaterial) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = n
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# They run all round the world, moved by the shader: never culled by a stale box.
	node.custom_aabb = AABB(Vector3(-1e5,-1e3,-1e5),Vector3(2e5,3e3,2e5))
	node.visible = false
	add_child(node)
	return mm

## `count` slots, none begun: 3x4 transforms by rows, then the custom data.
func _dead(count: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(count*16)
	for i in count:
		buf[i*16] = 1.0
		buf[i*16+5] = 1.0
		buf[i*16+10] = 1.0
		buf[i*16+12] = -1e6
		buf[i*16+13] = 1.0
	return buf

## One splash's quads (shaders/wake_splash.gdshader says what they carry).
func _splash_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var quad := func(sort: float, g: float, b: float, a: float, size: float, wait: float) -> void:
		var at := verts.size()
		for c: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
			verts.append(Vector3(c.x-0.5,0.0,c.y-0.5))
			uvs.append(c)
			uv2s.append(Vector2(size,wait))
			colors.append(Color(sort,g,b,a))
		for i: int in [0,1,2,0,2,3]: index.append(at+i)
	# The boil, then the rings as it breaks.
	quad.call(0.0,0.0,0.0,0.0,0.6,0.0)
	for i in 2: quad.call(0.0,float(i)/2.0,0.0,0.0,1.0-i*0.35,BOIL+i*0.3)
	# The drops, flung out all round.
	for i in 20:
		quad.call(0.5,(i+rng.randf())/20.0,rng.randf(),rng.randf(),rng.randf_range(0.05,0.11),BOIL+rng.randf_range(0.0,0.05))
	# The puffs.
	for i in 3:
		quad.call(1.0,rng.randf(),0.0,rng.randf(),rng.randf_range(0.35,0.55),BOIL)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## One frame, after the water has been read (`water` the WaterContact, or null).
func step(delta: float, eye: Vector3, plane: RefCounted, water: Node) -> void:
	var began := Time.get_ticks_usec()
	_clock += delta
	stir = 0.0
	if water != null: _wake(delta,plane,water)
	_idle(plane)
	_plops(delta,eye)
	_draw()
	ms = (Time.get_ticks_usec()-began)/1000.0
	ms_avg = lerpf(ms_avg,ms,0.05)

## The stir under the plane owes leaps; those it can place are laid.
func _wake(delta: float, plane: RefCounted, water: Node) -> void:
	stir = pow(float(water.stir()),STIR_POW)
	if stir < STIR_LEAST:
		_owed = 0.0
		_stirring = false
		return
	# Reaching the water sets a few off at once: a pond is over in a second.
	if not _stirring: _owed = FIRST
	_stirring = true
	var speed: float = plane.velocity.length()
	_owed = minf(_owed+delta*speed*speed/(BRISK*SPACING)*stir,float(MOST))
	var way := Vector3(plane.velocity.x,0.0,plane.velocity.z)
	if way.length() < 1.0: return
	var ahead := way.normalized()
	var right := ahead.cross(Vector3.UP)
	var p: Vector3 = plane.position
	while _owed >= 1.0:
		_owed -= 1.0
		var at_side := 1.0 if _rng.randf() < 0.5 else -1.0
		var out := WorldScale.span*0.6+pow(_rng.randf(),1.5)*SCATTER
		var fore := _rng.randf() < AHEAD_SHARE
		var along := speed*_rng.randf_range(LEAD.x,LEAD.y) if fore else -_rng.randf_range(TRAIL.x,TRAIL.y)
		var wait := _rng.randf_range(WAIT.x,WAIT.y) if fore else _rng.randf_range(TRAIL_WAIT.x,TRAIL_WAIT.y)
		# Out from the line, and on the way it was going: fleeing.
		var flee := (right*at_side+ahead*_rng.randf_range(0.0,0.7)).normalized().rotated(Vector3.UP,_rng.randf_range(-0.5,0.5))
		# A spot off the water tries again nearer the line: a pond is soon crossed.
		for t in TRIES:
			var spot := p+ahead*along+right*at_side*out
			if _leap(Vector2(spot.x,spot.z),Vector2(flee.x,flee.z),wait,float(water.level)):
				wake_total += 1
				break
			along *= 0.45
			out *= 0.55

## Now and then a fish leaps in a lake ahead of a plane that's low over it.
func _idle(plane: RefCounted) -> void:
	if _clock < _idle_next: return
	_idle_next = _clock+_rng.randf_range(IDLE_AGAIN.x,IDLE_AGAIN.y)
	var p: Vector3 = plane.position
	if p.y-Field.SEA_Y > IDLE_ABOVE: return
	var way := Vector3(plane.velocity.x,0.0,plane.velocity.z)
	if way.length() < 1.0: return
	var ahead := way.normalized()
	var spot := p+ahead*_rng.randf_range(IDLE_FORE.x,IDLE_FORE.y)+ahead.cross(Vector3.UP)*_rng.randf_range(-IDLE_SIDE,IDLE_SIDE)
	if not _lake(spot.x,spot.z): return
	var a := _rng.randf()*TAU
	_leap(Vector2(spot.x,spot.z),Vector2(cos(a),sin(a)),0.0,Field.SEA_Y)

## The water's level at (x, z) if a fish could break it there (`sea` the
## level to use for the sea's), else NAN.
func _water_at(x: float, z: float, sea: float) -> float:
	var river: float = _field.river_y(x,z)
	var h: float = _field.height(x,z)
	if not is_nan(river) and river > Field.SEA_Y+0.05: return river if h < river-DEEP else NAN
	return sea if h < Field.SEA_Y-DEEP and _lake_edge(x,z) else NAN

func _lake(x: float, z: float) -> bool:
	return float(_field.height(x,z)) < Field.SEA_Y-DEEP and _lake_edge(x,z) and is_nan(float(_field.river_y(x,z)))

func _lake_edge(x: float, z: float) -> bool:
	return float(_field.edge_off(x,z)) < -LAKE_IN

## A fish breaks the water at `spot`, `wait` s from now (after its boil),
## running along `dir`: its one write. False if it wouldn't land in water.
func _leap(spot: Vector2, dir: Vector2, wait: float, sea: float) -> bool:
	var level := _water_at(spot.x,spot.y,sea)
	if is_nan(level): return false
	var long := _rng.randf_range(LONG.x,LONG.y)
	var size := long/0.6
	var peak := _rng.randf_range(PEAK.x,PEAK.y)
	var run := _rng.randf_range(RUN.x,RUN.y)*long
	var land := spot+dir*run
	var landed := _water_at(land.x,land.y,sea)
	if is_nan(landed) or absf(landed-level) > 0.5: return false
	var sink := long*SINK
	var v0 := sqrt(2.0*GRAVITY*(peak+sink))
	var air := 2.0*v0/GRAVITY
	var roll := _rng.randf()*_kind_total
	var k := 0
	if roll > float(KINDS[0][1]): k = 1
	var slot := _f_next[k]
	_f_next[k] = (slot+1)%POOL
	var scale_by := long/_f_len[k]
	var breaks := _clock+wait+BOIL
	var at := Vector3(spot.x,level,spot.y)
	var buf := _f_buf[k]
	var o := slot*16
	# The basis: +z along the leap, up kept.
	var dx := dir.x
	var dz := dir.y
	buf[o] = dz*scale_by; buf[o+1] = 0.0; buf[o+2] = dx*scale_by; buf[o+3] = at.x
	buf[o+4] = 0.0; buf[o+5] = scale_by; buf[o+6] = 0.0; buf[o+7] = at.y
	buf[o+8] = -dx*scale_by; buf[o+9] = 0.0; buf[o+10] = dz*scale_by; buf[o+11] = at.z
	buf[o+12] = breaks; buf[o+13] = air; buf[o+14] = run/air
	buf[o+15] = _rng.randf()*(1.0 if _rng.randf() < 0.5 else -1.0)
	_f_buf[k] = buf
	_f_dirty[k] = 1
	var over := Vector3.UP*(LIFT_SEA if level == sea else LIFT_STILL)
	_splash(at+over,_clock+wait,size*0.45,0.0)
	var into := Vector3(land.x,level,land.y)+over
	_splash(into,breaks+air-BOIL,size*0.75,1.0)
	_plop_later(breaks+air,into,size)
	_alive_to = maxf(_alive_to,breaks+air+3.0)
	leaps_total += 1
	last_at = at
	return true

## A splash beginning at `when` (s; BOIL before the water breaks).
func _splash(at: Vector3, when: float, size: float, going_in: float) -> void:
	var o := _s_next*16
	_s_next = (_s_next+1)%SPLASHES
	_s_buf[o+3] = at.x
	_s_buf[o+7] = at.y
	_s_buf[o+11] = at.z
	_s_buf[o+12] = when
	_s_buf[o+13] = size
	_s_buf[o+14] = going_in
	_s_buf[o+15] = _rng.randf()
	_s_dirty = true

func _plop_later(when: float, at: Vector3, size: float) -> void:
	if _streams.is_empty(): return
	_p_when[_p_next] = when
	_p_at[_p_next] = at
	_p_size[_p_next] = size
	_p_next = (_p_next+1)%PLOP_QUEUE

func _plops(delta: float, eye: Vector3) -> void:
	if _streams.is_empty(): return
	_p_wait -= delta
	for i in PLOP_QUEUE:
		var when := _p_when[i]
		if when < 0.0 or _clock < when: continue
		_p_when[i] = -1.0
		var at := _p_at[i]
		if _p_wait > 0.0 or at.distance_squared_to(eye) > HEAR*HEAR: continue
		for a: AudioStreamPlayer3D in _players:
			if a.playing: continue
			var big := clampf((_p_size[i]-1.3)/1.0,0.0,1.0)
			a.stream = _streams[_rng.randi()%_streams.size()]
			a.global_position = at
			a.volume_db = lerpf(PLOP_DB.x,PLOP_DB.y,big)+_rng.randf_range(-2.0,2.0)
			a.pitch_scale = lerpf(1.25,0.8,big)*_rng.randf_range(0.9,1.1)
			a.play()
			_p_wait = PLOP_EVERY
			break

## What changed goes up; the clock, only while anything lives.
func _draw() -> void:
	var alive := _clock < _alive_to
	if alive != _s_node.visible:
		_s_node.visible = alive
		for n: MultiMeshInstance3D in _f_node: n.visible = alive
	if not alive: return
	for k in KINDS.size():
		_f_mat[k].set_shader_parameter("clock",_clock)
		if _f_dirty[k] == 1:
			_f_dirty[k] = 0
			_f_mm[k].buffer = _f_buf[k]
	_s_mat.set_shader_parameter("clock",_clock)
	if _s_dirty:
		_s_dirty = false
		_s_mm.buffer = _s_buf

## The numbers' line (--numbers).
func note() -> String:
	return "\nwake fish: stir %.2f, leaps %d (wake %d)  %.2f ms (%.2f)" % [stir,leaps_total,wake_total,ms,ms_avg]
