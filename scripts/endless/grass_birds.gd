extends Node3D
## The grass flocks (docs/design/endless-flight/grass-birds-handoff.md): birds
## down in the meadow grass that nothing shows of until the plane skims low
## and fast. Then they go up in a wave along its line, nearest first, the far
## side birds last, and scatter up and away. Visual only: nothing collides.
##
## Where they are comes from a CELL m grid: a cell's hash and a slow patch
## noise say whether it holds a covey at all, and only those cells read the
## land (deep meadow, flat, dry), one a scan, ahead of the plane. So a meadow
## has its coveys in the same places every flight, in patches.
##
## A burst writes its birds into a ring of a MultiMesh once and is done: from
## then on the shader (shaders/grass_birds.gdshaderinc) flies each from its
## start time and launch, one draw call, with `clock` the only thing set each
## frame. Nothing here runs per bird after the burst, so the wave costs no
## native port; a burst's layout is what a port would move (the handoff's
## numbers).
##
## Drawn dark (scripts/endless/dark_bird_body.gd) or in the songbird's body
## (one merged mesh per species, the same flight): --bird-look=dark|song. The
## tree flocks and the far flocks are the same in both.
##
## None where the world has no grass (its `grass` layer). Flags: --grass-birds=X
## how many birds in a covey over its default (1; 0 none), --bird-look=.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const Body = preload("res://scripts/songbird_body.gd")
const Dark = preload("res://scripts/endless/dark_bird_body.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const SHADER_DARK = preload("res://shaders/grass_birds_dark.gdshader")
const SHADER_SONG = preload("res://shaders/grass_birds_song.gdshader")

## The grid (m), and the share of a patch's cells that hold a covey.
const CELL := 36.0
const CELL_SHARE := 0.62
## The patches: the noise's size (m), and over this it is a patch.
const PATCH := 320.0
const PATCH_OVER := 0.06
## A covey's birds, and its radius (m).
const COVEY := Vector2i(50,130)
const RADIUS := 15.0
## A covey's ground: meadow over this, slope under this across SLOPE_REACH m,
## this far from a river, this far over the sea.
const MEADOW := 0.45
const SLOPE := 0.14
const SLOPE_REACH := 12.0
const RIVER_CLEAR := 6.0
const SEA_CLEAR := 2.5
## The look ahead (seconds between scans, m ahead read, m to a side read).
const SCAN := 0.066
const LOOK := Vector2(0.0,250.0)
const LANE := 90.0
## The plane's height over the covey's ground that flushes it whole, and none.
const SKIM := Vector2(16.0,34.0)
## The plane's speed (m/s) that flushes none, and whole.
const FAST := Vector2(16.0,30.0)
## The wave's front runs this many seconds ahead of the nose, and this share
## of the plane's speed out to the sides; birds within BAND of its line go.
const LEAD := 1.25
const BOW := 0.5
const BAND := 62.0
const STAGGER := 0.14
## A bird's launch (m/s): up, out from the line, and the plane's speed taken
## along. Then its own way: out, up, along.
const LAUNCH_UP := Vector2(13.0,25.0)
const LAUNCH_OUT := Vector2(4.0,12.0)
const LAUNCH_ALONG := Vector2(0.2,0.5)
const AWAY_OUT := Vector2(9.0,15.0)
const AWAY_UP := Vector2(2.0,9.0)
const AWAY_ALONG := Vector2(2.0,9.0)
const AWAY_TURN := 0.75
const SWAY := 3.5
## Seconds a bird lives.
const LIFE := Vector2(3.6,6.0)
## The dark bird's span and the songbird's over the plane's, and a bird's
## spread on it.
const SPAN_DARK := 0.36
const SPAN_SONG := 0.3
const SIZES := Vector2(0.85,1.15)
## Birds at once. A ring's oldest are overwritten past it.
const MOST := 1500
## Instance floats: 12 of transform, 4 custom.
const STRIDE := 16
## How far a burst's birds can get (m), for the draw box.
const SPREAD := Vector2(150.0,110.0)
## The burst's sound: the clips, the gain at a full covey and at few, the
## reach (m), a second take this long after when a covey is big.
const WINGS := "res://assets/audio/kit/wings-%d.wav"
const WING_DB := Vector2(1.0,9.0)
const WING_UNIT := 26.0
const WING_FAR := 260.0
const WING_AGAIN := 0.13
const VOICES := 5
const SPECIES := ["sparrow","sparrow","robin","goldfinch"]

class Ring:
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var data := PackedFloat32Array()
	var head := 0
	var used := 0
	var most := 0

class Site:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var gx := 0.0
	var gz := 0.0
	var birds := 0
	var seed := 0.0

var density := 1.0
var look := "dark"
## The numbers: bursts and birds so far, the coveys found, what a land read and
## a burst cost (ms), the most live birds a ring has had.
var stats := {"bursts":0,"birds":0,"sites":0,"cells":0,"land_reads":0,"land_ms":0.0,"land_ms_most":0.0,"burst_ms":0.0,"burst_ms_most":0.0}
## The last bursts (for drivers): the time, birds, where, the plane's height
## over it and speed, what it cost.
var log_bursts: Array = []

var _field: RefCounted
var _land_seed := 1
var _rng := RandomNumberGenerator.new()
var _cell := RandomNumberGenerator.new()
var _patch := FastNoiseLite.new()
var _rings: Array[Ring] = []
var _paint: Array[ShaderMaterial] = []
var _span := 0.85
var _cells := {}
var _live: Array[Site] = []
var _wait := 0.0
var _clock := 0.0
var _time := 0.0
var _gone_at := -1.0
## Live bursts' boxes: Array of [time they end, AABB].
var _boxes: Array = []
var _voices: Array[AudioStreamPlayer3D] = []
var _voice := 0
var _clips: Array = []
var _again := -1.0
var _again_at := Vector3.ZERO
var _again_db := 0.0

static func flags() -> Dictionary:
	var grows := bool(preload("res://scripts/endless/world/world_profile.gd").current().layer("grass",true))
	var out := {"density":1.0 if grows else 0.0,"look":"dark"}
	for a: String in LaunchArgs.user_args():
		var v := a.get_slice("=",1)
		if a.begins_with("--grass-birds=") and grows: out.density = maxf(0.0,float(v))
		elif a.begins_with("--bird-look="): out.look = "song" if v == "song" else "dark"
	return out

func setup(land_seed: int, field: RefCounted) -> void:
	var f := flags()
	density = f.density
	look = f.look
	_field = field
	_land_seed = land_seed
	_rng.seed = hash("grass birds%d" % land_seed)
	_patch.seed = land_seed*4021+77
	_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patch.frequency = 1.0/PATCH
	_patch.fractal_type = FastNoiseLite.FRACTAL_FBM
	_patch.fractal_octaves = 2
	if density <= 0.0: return
	if look == "song":
		_span = WorldScale.span*SPAN_SONG
		var kinds: Array = Body.SPECIES.keys()
		for kind: String in kinds:
			_add_ring(_song_mesh(kind),SHADER_SONG,MOST/kinds.size(),"song_%s" % kind)
			var paint := _paint[-1]
			paint.set_shader_parameter("shoulder",Body.SHOULDER)
			paint.set_shader_parameter("wrist",0.0)
			paint.set_shader_parameter("hand",0.0)
			paint.set_shader_parameter("fold",0.0)
	else:
		_span = WorldScale.span*SPAN_DARK
		_add_ring(Dark.mesh(),SHADER_DARK,MOST,"dark")
	if FlightSound.wanted(): _add_voices()

func _add_ring(mesh: Mesh, shader: Shader, most: int, tag: String) -> void:
	var ring := Ring.new()
	ring.most = most
	ring.mm = MultiMesh.new()
	ring.mm.transform_format = MultiMesh.TRANSFORM_3D
	ring.mm.use_custom_data = true
	ring.mm.mesh = mesh
	ring.mm.instance_count = most
	ring.mm.visible_instance_count = 0
	ring.data.resize(most*STRIDE)
	var paint := ShaderMaterial.new()
	paint.shader = shader
	var node := MultiMeshInstance3D.new()
	node.name = "GrassBirds_%s" % tag
	node.multimesh = ring.mm
	node.material_override = paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.visible = false
	add_child(node)
	ring.node = node
	_rings.append(ring)
	_paint.append(paint)

## The songbird's flying body, head and both spread wings as one mesh, the
## wings' vertices marked for the shader's hinge.
static func _song_mesh(kind: String) -> ArrayMesh:
	var m := Body.meshes_for(kind)
	var air_head := Transform3D(Basis(Vector3.RIGHT,-0.12),Body.HEAD_AT)
	var fly := SurfaceTool.new()
	fly.append_from(m.body,0,Transform3D.IDENTITY)
	fly.append_from(m.head,0,air_head)
	var trunk := fly.commit()
	var st := SurfaceTool.new()
	st.append_from(trunk,0,Transform3D.IDENTITY)
	var hinge := [Vector3(-Body.SHOULDER.x,Body.SHOULDER.y,Body.SHOULDER.z),Body.SHOULDER]
	for i in 2: st.append_from(m.spread[i],0,Transform3D(Basis.IDENTITY,hinge[i]))
	var whole := st.commit()
	var arrays := whole.surface_get_arrays(0)
	var n: int = arrays[Mesh.ARRAY_VERTEX].size()
	var from := trunk.surface_get_array_len(0)
	var uv := PackedVector2Array()
	uv.resize(n)
	for i in range(from,n): uv[i] = Vector2(1.0,0.0)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

func _add_voices() -> void:
	for i in 4: _clips.append(load(WINGS % (i+1)))
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = FlightSound.SFX
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = WING_UNIT
		p.max_distance = WING_FAR
		p.panning_strength = 0.7
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_voices.append(p)

## One frame: the clock while any bird flies, a scan now and then.
func step(delta: float, plane: RefCounted) -> void:
	if density <= 0.0: return
	_time += delta
	_clock += delta
	if _gone_at >= 0.0:
		if _time > _gone_at: _all_down()
		else:
			for p in _paint: p.set_shader_parameter(&"clock",_clock)
			_keep_box()
	if _again >= 0.0:
		_again -= delta
		if _again < 0.0: _wing_sound(_again_at,_again_db)
	_wait -= delta
	if _wait > 0.0: return
	_wait = SCAN
	_scan(plane.position,plane.velocity)

func _all_down() -> void:
	_gone_at = -1.0
	_boxes.clear()
	for r in _rings:
		r.node.visible = false

## The boxes of bursts that are over dropped from the draw box.
func _keep_box() -> void:
	if _boxes.is_empty() or _boxes[0][0] > _time: return
	_boxes.pop_front()
	_set_box()

func _set_box() -> void:
	if _boxes.is_empty(): return
	var box: AABB = _boxes[0][1]
	for b: Array in _boxes: box = box.merge(b[1])
	for r in _rings:
		r.mm.custom_aabb = box

# --- Where they are -----------------------------------------------------------

func _scan(pp: Vector3, pv: Vector3) -> void:
	var speed := pv.length()
	if speed < FAST.x: return
	var flat := Vector3(pv.x,0.0,pv.z)
	if flat.length() < 1.0: return
	var over := pp.y-maxf(_field.height(pp.x,pp.z),Field.SEA_Y)
	if over > SKIM.y+20.0: return
	var fwd := flat.normalized()
	var right := fwd.cross(Vector3.UP)
	_look_ahead(pp,fwd,right)
	_flush_near(pp,fwd,right,speed)

## Cells ahead not yet known, nearest first, the land read for at most one a
## scan (the hash and the patch rule most out for nothing).
func _look_ahead(pp: Vector3, fwd: Vector3, right: Vector3) -> void:
	var along := LOOK.x
	while along <= LOOK.y:
		var side := -LANE
		while side <= LANE:
			var c := pp+fwd*along+right*side
			var key := Vector2i(floori(c.x/CELL),floori(c.z/CELL))
			if not _cells.has(key) and _read_cell(key): return
			side += CELL
		along += CELL
	if _cells.size() > 1200: _cells.clear()

## True if it read the land.
func _read_cell(key: Vector2i) -> bool:
	_cells[key] = true
	stats.cells += 1
	_cell.seed = hash(key)+_land_seed*7919
	if _cell.randf() > CELL_SHARE: return false
	var x := (key.x+0.2+_cell.randf()*0.6)*CELL
	var z := (key.y+0.2+_cell.randf()*0.6)*CELL
	var fullness := _cell.randf()
	if _patch.get_noise_2d(x,z) < PATCH_OVER: return false
	var t0 := Time.get_ticks_usec()
	var s := _land_site(x,z)
	if s != null:
		s.birds = maxi(roundi(lerpf(COVEY.x,COVEY.y,fullness*fullness)*density),1)
		s.seed = _cell.randf()*100.0
		_live.append(s)
		stats.sites += 1
	var ms := (Time.get_ticks_usec()-t0)/1000.0
	stats.land_reads += 1
	stats.land_ms = lerpf(float(stats.land_ms),ms,0.1)
	stats.land_ms_most = maxf(float(stats.land_ms_most),ms)
	return true

## A covey's ground at (x, z), or null: deep meadow, flat, off the water.
func _land_site(x: float, z: float) -> Site:
	var here: Dictionary = _field.shape(x,z)
	var y := float(here.height)
	if float(here.meadow) < MEADOW or y-Field.SEA_Y < SEA_CLEAR or float(here.river) < RIVER_CLEAR: return null
	var e: float = _field.height(x+SLOPE_REACH,z)
	var w: float = _field.height(x-SLOPE_REACH,z)
	var n: float = _field.height(x,z-SLOPE_REACH)
	var s: float = _field.height(x,z+SLOPE_REACH)
	var gx := (e-w)/(2.0*SLOPE_REACH)
	var gz := (s-n)/(2.0*SLOPE_REACH)
	if absf(gx) > SLOPE or absf(gz) > SLOPE: return null
	var out := Site.new()
	out.x = x
	out.y = y
	out.z = z
	out.gx = gx
	out.gz = gz
	return out

## How much of a covey goes for a plane this high over it, this fast.
func _skim(over: float, speed: float) -> float:
	return (1.0-smoothstep(SKIM.x,SKIM.y,over))*smoothstep(FAST.x,FAST.y,speed)

func _flush_near(pp: Vector3, fwd: Vector3, right: Vector3, speed: float) -> void:
	var front := speed*LEAD
	for i in range(_live.size()-1,-1,-1):
		var s := _live[i]
		var d := Vector3(s.x-pp.x,0.0,s.z-pp.z)
		var ahead := d.dot(fwd)
		if ahead < -RADIUS*2.0:
			_live.remove_at(i)
			continue
		if ahead-RADIUS > front or absf(d.dot(right)) > BAND: continue
		var k := _skim(pp.y-s.y,speed)
		if k < 0.08: continue
		_live.remove_at(i)
		_burst(s,k,pp,fwd,right,speed)

# --- The burst ----------------------------------------------------------------

## The covey up, each bird's whole life written here: its spot in the grass,
## its start (the front passing it, later to the sides), its launch and way.
func _burst(s: Site, share: float, pp: Vector3, fwd: Vector3, right: Vector3, speed: float) -> void:
	var t0 := Time.get_ticks_usec()
	var ring: Ring = _rings[0]
	if look == "song": ring = _rings[Body.SPECIES.keys().find(SPECIES[_rng.randi_range(0,SPECIES.size()-1)])]
	var n := mini(ceili(s.birds*share),ring.most/3)
	var front := speed*LEAD
	var q := ring.head*STRIDE
	var data := ring.data
	var last := 0.0
	var fx := fwd.x
	var fz := fwd.z
	var rx := right.x
	var rz := right.z
	var lanes := 1.0/maxf(BAND,1.0)
	for i in n:
		# Scattered on a sunflower disc, so no two are one.
		var r := RADIUS*sqrt((i+_rng.randf())/n)
		var a := i*2.39996+s.seed
		var dx := cos(a)*r
		var dz := sin(a)*r
		var bx := s.x+dx
		var bz := s.z+dz
		var ax := bx-pp.x
		var az := bz-pp.z
		var along := ax*fx+az*fz
		var lat := ax*rx+az*rz
		var delay := maxf(along-front,0.0)/speed+absf(lat)/(speed*BOW)*0.5+_rng.randf()*STAGGER
		# Out from the line: birds on it pick a side, and take it hardest.
		var side := signf(lat) if absf(lat) > 2.0 else (1.0 if _rng.randf() < 0.5 else -1.0)
		var close := 1.0-minf(absf(lat)*lanes,1.0)
		var up := _rng.randf_range(LAUNCH_UP.x,LAUNCH_UP.y)*(0.8+close*0.4)
		var out := _rng.randf_range(LAUNCH_OUT.x,LAUNCH_OUT.y)*(0.7+close*0.6)*side
		var on := speed*_rng.randf_range(LAUNCH_ALONG.x,LAUNCH_ALONG.y)
		var lvx := rx*out+fx*on
		var lvz := rz*out+fz*on
		var turn := _rng.randf_range(-AWAY_TURN,AWAY_TURN)
		var aw := _rng.randf_range(AWAY_OUT.x,AWAY_OUT.y)*side
		var al := _rng.randf_range(AWAY_ALONG.x,AWAY_ALONG.y)
		var c := cos(turn)
		var sn := sin(turn)
		var avx := (rx*aw+fx*al)*c+(fx*aw-rx*al)*sn
		var avz := (rz*aw+fz*al)*c+(fz*aw-rz*al)*sn
		var avy := _rng.randf_range(AWAY_UP.x,AWAY_UP.y)
		var sway := _rng.randf_range(0.3,1.0)*SWAY*(1.0 if i%2 == 0 else -1.0)
		var life := _rng.randf_range(LIFE.x,LIFE.y)
		var by := s.y+dx*s.gx+dz*s.gz+0.15
		var start := _clock+delay
		data[q] = lvx; data[q+1] = avx; data[q+2] = rx*sway; data[q+3] = bx
		data[q+4] = up; data[q+5] = avy; data[q+6] = sway*0.25; data[q+7] = by
		data[q+8] = lvz; data[q+9] = avz; data[q+10] = rz*sway; data[q+11] = bz
		data[q+12] = start; data[q+13] = _rng.randf(); data[q+14] = _span*_rng.randf_range(SIZES.x,SIZES.y); data[q+15] = life
		last = maxf(last,delay+life)
		q += STRIDE
		if q >= ring.most*STRIDE: q = 0
	ring.head = q/STRIDE
	ring.used = ring.most if ring.head < n else maxi(ring.used,ring.head)
	RenderingServer.multimesh_set_buffer(ring.mm.get_rid(),data)
	ring.mm.visible_instance_count = ring.used
	ring.node.visible = true
	var box := AABB(Vector3(s.x-SPREAD.x,s.y-2.0,s.z-SPREAD.x),Vector3(SPREAD.x*2.0,SPREAD.y,SPREAD.x*2.0))
	_boxes.append([_time+last,box])
	_boxes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_set_box()
	if _gone_at < 0.0:
		for p in _paint: p.set_shader_parameter(&"clock",_clock)
	_gone_at = maxf(_gone_at,_time+last)
	_sound(Vector3(s.x,s.y+1.0,s.z),n)
	var ms := (Time.get_ticks_usec()-t0)/1000.0
	stats.bursts += 1
	stats.birds += n
	stats.burst_ms = lerpf(float(stats.burst_ms),ms,0.2) if int(stats.bursts) > 1 else ms
	stats.burst_ms_most = maxf(float(stats.burst_ms_most),ms)
	log_bursts.append({"t":_time,"n":n,"x":s.x,"z":s.z,"over":pp.y-s.y,"speed":speed,"ms":ms})
	if log_bursts.size() > 256: log_bursts.pop_front()

## Wings going up at `at`, louder the more of them; a big covey's second
## take close behind.
func _sound(at: Vector3, n: int) -> void:
	if _voices.is_empty(): return
	var k := clampf(float(n)/COVEY.y,0.0,1.0)
	var db := lerpf(WING_DB.x,WING_DB.y,sqrt(k))
	_wing_sound(at,db)
	if n > COVEY.x:
		_again = WING_AGAIN*_rng.randf_range(0.7,1.4)
		_again_at = at
		_again_db = db-3.0

func _wing_sound(at: Vector3, db: float) -> void:
	var p := _voices[_voice]
	_voice = (_voice+1)%_voices.size()
	p.global_position = at
	p.stream = _clips[_rng.randi_range(0,_clips.size()-1)]
	p.volume_db = db+_rng.randf_range(-1.5,1.5)
	p.pitch_scale = _rng.randf_range(0.92,1.14)
	p.play()

## The numbers line (F1).
func note() -> String:
	if density <= 0.0: return ""
	return "\ngrass birds (%s): %d bursts, %d birds  ·  burst %.2f ms (most %.2f)  ·  land %.2f ms" % [
		look,int(stats.bursts),int(stats.birds),float(stats.burst_ms),float(stats.burst_ms_most),float(stats.land_ms)]
