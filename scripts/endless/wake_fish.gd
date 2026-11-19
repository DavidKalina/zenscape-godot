extends Node3D
## Now and then, flying low over a lake, a fish leaps: over the plane's nose when
## it skims at about wingtip height, off a wingtip, small and far off in a corner
## of the view, a pair, or now and then a big one, higher and slower and heavier in
## the water. One moment every GAP s or so of time low over a lake, however it's
## flown, and not the same one twice running.
##
## What seed 1 calls lakes are the sea's level standing inside the land: under
## that level and at least LAKE_IN m inside the world's edge line.
##
## The plane does 57 m/s with the chase camera close behind, so a moment is worked
## out backwards. Each is a point in the camera's view (`_beside`) or on the
## plane's line (`_over`) at the moment the fish should be there, which is the
## water's swirl and the rise ahead of now: `_line` carries the plane on through
## that time, turning as it is turning. A fish going over the plane is still led
## onto it in the air, a metre or so, for a line that wobbled after it left.
##
## A fish flies on real gravity here on the CPU, one or two at a time: fast out,
## a slowing rise, a touch of hang at the top (its clock slowed there, not its
## path), a real fall, in nose first. `_pose` bends it through its spine each
## frame (shaders/wake_fish.gdshader). The splashes are worked out on the GPU from
## their start (shaders/wake_splash.gdshader). The water's own surface takes the
## swirl, the rings and the broken water where it went through (EndlessSea `leaps`).
##
## Nothing here touches the plane.
##
## --wake-fish=0 none of it. --leap-gap=S the mean gap (s), --leap-size=X the fish
## times X. --leap-big=S[,X] the big fish's share of the moments (0 none, 1 all of
## them) and their length times X.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const SwimFish = preload("res://scripts/endless/swim_fish.gd")

const MODEL := "res://assets/models/fish/hero_fish.glb"
const SKIN := "res://assets/models/fish/hero_fish_skin.png"

## The mean gap (s of time low over a lake) and how far either way it goes; the
## first comes at this share of one, so a short lake isn't nothing.
const GAP := 45.0
const GAP_SPREAD := 1.0/3.0
const FIRST := Vector2(0.15,0.55)
## Low: this high at most over the water (m). Looked at every LOOK s.
const LOW := 45.0
const LOOK := 0.2
## A moment that found no water in view tries again in this long (s), on each
## side this many times.
const AGAIN := 0.3
const SIDES := 3
## [moment, weight]. A pair's the rare one.
const MOMENTS := [["over",3.0],["wing",3.0],["far",3.0],["pair",1.2]]
## The big one's share of the moments (the rest keep their weights among them).
const BIG_SHARE := 0.2

## Length (m) drawn.
const LONG := Vector2(0.4,0.8)
## The kinds of fish: tints of the skin, and the shape: wider, deeper.
const KINDS := [
	{"back":Color(0.1,0.13,0.1),"flank":Color(0.72,0.62,0.36),"belly":Color(0.9,0.84,0.62),"spot":Color(0.08,0.05,0.04),"band":Color(0.5,0.3,0.15),"fin":Color(0.32,0.25,0.15),"spots":0.9,"bands":0.0,"wide":1.1,"deep":1.08},
	{"back":Color(0.1,0.19,0.2),"flank":Color(0.7,0.74,0.76),"belly":Color(0.93,0.93,0.91),"spot":Color(0.05,0.06,0.08),"band":Color(0.72,0.28,0.34),"fin":Color(0.3,0.3,0.32),"spots":0.75,"bands":0.65,"wide":1.0,"deep":1.0},
	{"back":Color(0.07,0.11,0.17),"flank":Color(0.78,0.82,0.86),"belly":Color(0.96,0.96,0.95),"spot":Color(0.05,0.07,0.1),"band":Color(0.8,0.82,0.85),"fin":Color(0.16,0.2,0.26),"spots":0.4,"bands":0.0,"wide":0.92,"deep":0.94},
	{"back":Color(0.14,0.17,0.1),"flank":Color(0.55,0.56,0.38),"belly":Color(0.86,0.68,0.42),"spot":Color(0.72,0.68,0.5),"band":Color(0.6,0.4,0.2),"fin":Color(0.42,0.24,0.14),"spots":0.7,"bands":0.0,"wide":1.05,"deep":1.14},
]

## The water swirls this long (s) before it breaks; over the plane it's too far
## off to see, and a shorter wait is a surer aim.
const SWIRL := Vector2(0.42,0.62)
const SWIRL_OVER := Vector2(0.2,0.3)
const GRAVITY := 9.8
## The centre starts this share of the length under, so the tail comes out too.
const SINK := 0.62
## How deep the hang goes (a share of the clock) and how long it lasts (s).
const HANG := Vector2(0.14,0.34)
const HANG_LONG := 0.2
## How far the body's nose leads the arc round the top (rad).
const LEAD := Vector2(0.15,0.42)

## Over the plane: up to this high the plane's centre over the water (m), its line
## this steady (rad/s). Top of the arc this far over the plane's centre (m), this
## far on from it, the fish running this fast (m/s).
const OVER_BELOW := 3.4
const OVER_STEADY := 0.35
const OVER_CLEAR := Vector2(1.3,1.9)
const OVER_FORE := 1.2
const OVER_RUN := Vector2(3.0,5.5)
## How often it runs along the line, either way, rather than across it.
const OVER_ALONG := 0.1
## Led in the air: at most this far (m), this fast (m/s); before it breaks, under
## the swirl, more.
const STEER := 5.0
const STEER_RATE := 7.0
const STEER_UNDER := 10.0
const STEER_UNDER_RATE := 20.0

## Beside: how far on from the eye (m) and off its axis (rad) at the moment; the
## fish's height, its run, and how far through its leap it is by then (so some are
## seen rising and some going in). The eye is 12 m behind the plane at speed, so a
## fish level with a wingtip is already small: the close ones pass between the two.
## `big`: this much longer than the fish it would be: at that range it's pixels,
## and it can't be measured against anything.
const WING := {"on":Vector2(6.0,12.0),"off":Vector2(0.5,0.78),"peak":Vector2(1.0,2.4),"run":Vector2(2.0,5.0),"through":Vector2(0.35,0.7),"long":Vector2(0.5,1.0)}
const FAR := {"on":Vector2(55.0,100.0),"off":Vector2(0.28,0.55),"peak":Vector2(1.4,2.9),"run":Vector2(2.5,5.5),"through":Vector2(0.4,0.6),"long":Vector2(0.7,1.0),"big":1.4}
const PAIR := {"on":Vector2(8.0,18.0),"off":Vector2(0.35,0.65),"peak":Vector2(1.0,2.2),"run":Vector2(2.5,4.5),"through":Vector2(0.35,0.65),"long":Vector2(0.4,0.85)}
## A big one: its `long` in m, and heavy: it comes up slow and is long in the air.
## BIG_FAR, this often: it stands well off, the whole arc in the view.
const BIG := {"on":Vector2(14.0,24.0),"off":Vector2(0.4,0.68),"peak":Vector2(4.6,6.8),"run":Vector2(3.5,6.5),"through":Vector2(0.45,0.62),"long":Vector2(2.6,3.8),"heavy":true}
const BIG_FAR := {"on":Vector2(30.0,46.0),"off":Vector2(0.25,0.5),"peak":Vector2(5.6,8.0),"run":Vector2(3.5,6.0),"through":Vector2(0.42,0.6),"long":Vector2(3.4,4.6),"heavy":true}
const BIG_FAR_SHARE := 0.4
## Its build, deeper and wider for its length; the water's swirl (s), the hang, the
## slow tail (Hz), a held bend that's stiffer, and a little of the roll.
const BIG_BUILD := Vector2(1.12,1.2)
const BIG_SWIRL := Vector2(0.7,0.95)
const BIG_HANG := Vector2(0.24,0.4)
const BIG_BEAT_HZ := Vector2(2.6,4.2)
const BIG_ARCH := Vector2(0.45,0.95)
const BIG_TWIST := Vector2(0.3,1.1)
## A second, wider burst of water this long (s) after it goes in, at this share of
## the first: the hole it left closing.
const BIG_SLAM_AFTER := 0.16
const BIG_SLAM := 0.7
## How often a fish beside the plane turns its flank to the eye rather than any way.
const FLANK_SHARE := 0.75
## The second of a pair: this much later (s), this far from the first (m).
const SECOND_AFTER := Vector2(0.12,0.36)
const SECOND_OFF := Vector2(0.8,2.4)

## Water this deep at least (m) where it breaks and lands.
const DEEP := 0.5
## A lake's the sea's level at least this far (m) inside the world's edge line.
const LAKE_IN := 300.0
## The sea's surface isn't all on the CPU: a splash sits this far over it (m).
const LIFT := 0.08
## Fish at once; splashes at once; the water's marks at once (EndlessSea LEAPS).
const FISH := 2
const SPLASHES := 8
const MARKS := 6
## A mark on the water lasts this long (s) from the break.
const MARK_LIFE := 5.0
## The plops: heard within HEAR m, a beat after the splash, softer the further and
## the smaller. The levels are a guess.
const HEAR := 150.0
const BEAT := Vector2(0.06,0.16)
const SOUND_SPEED := 340.0
const PLOP_DB := Vector2(-20.0,-10.0)
const PLOPS := 3

## One fish, from its swirl to under the water again.
class Leap:
	var node: MeshInstance3D
	var mat: ShaderMaterial
	var kind: Dictionary
	var long := 0.6
	var heavy := false
	var shape := Vector2.ONE
	var at := Vector3.ZERO
	var dir := Vector2.ZERO
	var level := 0.0
	var wait := 0.0
	var clock := 0.0
	var v0 := 0.0
	var vh := 0.0
	var air := 0.0
	var top := 0.0
	var hang := 0.0
	var lead := 0.0
	var side := 1.0
	var arch := 0.0
	var flips := 1.0
	var beat := 0.0
	var beat_hz := 8.0
	var phase := 0.0
	var roll := 0.0
	var twist := 0.0
	var wobble := 0.0
	var out := false
	var went_in := false
	## Being led onto the plane: the clock when it should be there, and how much
	## it has been moved. -1: not led.
	var lead_on := -1.0
	var moved := Vector3.ZERO
	## Its swirl's slot on the water.
	var mark := -1

var sea: RefCounted
## The big fish that swims beside the plane (scripts/endless/swim_fish.gd), or null.
var swim: Node3D
var _field: RefCounted
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _gap_mean := GAP
var _size := 1.0
## How long till the next moment, of time low over a lake; the look's wait.
var _left := 0.0
var _look := 0.0
var _low := false
var _last := ""
var _moments: Array = []
var _big_size := 1.0
var _at := Vector3.ZERO
var _ahead := Vector3.FORWARD
var _right := Vector3.RIGHT
var _speed := 0.0
var _turn := 0.0
var _high := INF
var _eye := Vector3.ZERO
var _look_on := Vector3.FORWARD
var _look_right := Vector3.RIGHT
var _pool: Array[MeshInstance3D] = []
var _leaps: Array[Leap] = []
var _s_mm: MultiMesh
var _s_node: MultiMeshInstance3D
var _s_mat: ShaderMaterial
var _s_buf := PackedFloat32Array()
var _s_next := 0
var _s_until := -1.0
var _marks := PackedVector4Array()
var _mark_next := 0
var _marks_until := -1.0
## The plops to come: when (s), where and how big.
var _p_when := PackedFloat32Array()
var _p_at := PackedVector3Array()
var _p_size := PackedFloat32Array()
## Which are a fish breaking the surface (its splash, `_splashes`), not a plop.
var _p_splash := PackedByteArray()
var _splashes: Array = []
var _players: Array[AudioStreamPlayer3D] = []
var _streams: Array = []
var _spine := PackedVector3Array()
## Shown for the first moments, folded away: the pipelines build at the start
## and not at the first lake.
var _warm := 0.5
## For the numbers and probes: time low over a lake (s), the moments by name, the
## last and when (of that time), the last fish's spot, ms this frame and its mean.
var water_s := 0.0
var moments := {}
var last_moment_at := -1.0
var last_at := Vector3.ZERO
var ms := 0.0
var ms_avg := 0.0

## --wake-fish=0 none.
static func wanted() -> bool:
	return not ("--wake-fish=0" in LaunchArgs.user_args())

static func _knob(name: String, otherwise: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--"+name+"="): return a.get_slice("=",1).to_float()
	return otherwise

func setup(field: RefCounted) -> void:
	_field = field
	_rng.randomize()
	_gap_mean = maxf(_knob("leap-gap",GAP),0.2)
	_size = maxf(_knob("leap-size",1.0),0.05)
	_left = _gap_mean*_rng.randf_range(FIRST.x,FIRST.y)
	_set_moments()
	var scene := (load(MODEL) as PackedScene).instantiate()
	var found: Array[Node] = scene.find_children("*","MeshInstance3D",true,false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh
	scene.free()
	var shader: Shader = load("res://shaders/wake_fish.gdshader")
	var skin: Texture2D = load(SKIN)
	_spine.resize(9)
	for i in 9: _spine[i] = Vector3(0.0,0.42-i/8.0,0.0)
	for i in FISH:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("skin",skin)
		mat.set_shader_parameter("spine",_spine)
		var f := MeshInstance3D.new()
		f.name = "Fish%d" % i
		f.mesh = mesh
		f.material_override = mat
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Folded, and flown by hand: never culled by a stale box.
		f.custom_aabb = AABB(Vector3(-4.0,-4.0,-4.0),Vector3(8.0,8.0,8.0))
		f.scale = Vector3.ONE*0.001
		f.top_level = true
		add_child(f)
		_pool.append(f)
	if SwimFish.wanted():
		swim = SwimFish.new()
		swim.name = "Swim"
		add_child(swim)
		swim.setup(self,mesh,shader,skin)
	_s_mat = ShaderMaterial.new()
	_s_mat.shader = load("res://shaders/wake_splash.gdshader")
	_s_mat.set_shader_parameter("gravity",GRAVITY)
	_s_mm = MultiMesh.new()
	_s_mm.transform_format = MultiMesh.TRANSFORM_3D
	_s_mm.use_custom_data = true
	_s_mm.mesh = _splash_mesh()
	_s_mm.instance_count = SPLASHES
	_s_node = MultiMeshInstance3D.new()
	_s_node.name = "Splash"
	_s_node.multimesh = _s_mm
	_s_node.material_override = _s_mat
	_s_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# It runs all round the world, moved by the shader: never culled by a stale box.
	_s_node.custom_aabb = AABB(Vector3(-1e5,-1e3,-1e5),Vector3(2e5,3e3,2e5))
	add_child(_s_node)
	_s_buf.resize(SPLASHES*16)
	for i in SPLASHES:
		_s_buf[i*16+12] = -1e6
		_s_buf[i*16+5] = 1.0
		_s_buf[i*16+10] = 1.0
		_s_buf[i*16] = 1.0
		_s_buf[i*16+13] = 1.0
	_s_mm.buffer = _s_buf
	_marks.resize(MARKS)
	_p_when.resize(PLOPS*2)
	_p_when.fill(-1.0)
	_p_at.resize(PLOPS*2)
	_p_size.resize(PLOPS*2)
	_p_splash.resize(PLOPS*2)
	if FlightSound.wanted():
		for i in 4:
			var s: AudioStream = load("res://assets/audio/foley/fish-splash-%d.wav" % (i+1))
			if s != null: _splashes.append(s)
		for path: String in ["res://assets/audio/fish-plop-1.wav","res://assets/audio/fish-plop-2.wav",
				"res://assets/audio/foley/water-pop-1.wav","res://assets/audio/foley/water-pop-3.wav"]:
			var s: AudioStream = load(path)
			if s != null: _streams.append(s)
		for i in PLOPS:
			var a := AudioStreamPlayer3D.new()
			a.unit_size = 14.0
			a.max_distance = HEAR
			a.panning_strength = 0.6
			a.bus = FlightSound.SFX
			add_child(a)
			_players.append(a)

## The moments and their weights, the big one's by its knob: a share, or a share and
## a size.
func _set_moments() -> void:
	var share := BIG_SHARE
	for a: String in LaunchArgs.user_args():
		if not a.begins_with("--leap-big="): continue
		var parts := a.get_slice("=",1).split(",")
		share = clampf(parts[0].to_float(),0.0,1.0)
		if parts.size() > 1: _big_size = maxf(parts[1].to_float(),0.05)
	var rest := 0.0
	moments["big"] = 0
	if share < 1.0:
		for m: Array in MOMENTS:
			moments[m[0]] = 0
			_moments.append(m)
			rest += float(m[1])
	if share > 0.0: _moments.append(["big",rest*share/(1.0-share) if share < 1.0 else 1.0])

## One splash's mesh (shaders/wake_splash.gdshader says what it carries).
func _splash_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	# The crown: a wall, 20 round and 3 up.
	const ROUND := 20
	const UP := 3
	for j in UP+1:
		for i in ROUND+1:
			verts.append(Vector3.ZERO)
			uvs.append(Vector2(float(i)/ROUND,float(j)/UP))
			uv2s.append(Vector2.ZERO)
			colors.append(Color(0.0,0.0,0.0,0.0))
	for j in UP:
		for i in ROUND:
			var p := j*(ROUND+1)+i
			var q := p+ROUND+1
			for k: int in [p,p+1,q+1,p,q+1,q]: index.append(k)
	var quad := func(sort: float, g: float, b: float, a: float, size: float, wait: float) -> void:
		var at := verts.size()
		for c: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
			verts.append(Vector3.ZERO)
			uvs.append(c)
			uv2s.append(Vector2(size,wait))
			colors.append(Color(sort,g,b,a))
		for i: int in [0,1,2,0,2,3]: index.append(at+i)
	# Drops off the crown, then those shed up the fish's path (early, mostly).
	for i in 44:
		quad.call(0.25,(i+rng.randf())/44.0,rng.randf(),rng.randf(),rng.randf_range(0.006,0.018),rng.randf_range(0.0,0.06))
	for i in 34:
		quad.call(0.5,rng.randf(),rng.randf(),rng.randf(),rng.randf_range(0.005,0.014),pow(rng.randf(),1.5)*0.5)
	# The jet, a stem of blobs, each a little later.
	for i in 7:
		quad.call(0.75,rng.randf(),rng.randf(),float(i)/6.0,lerpf(0.035,0.016,float(i)/6.0),0.14+0.03*i)
	for i in 2:
		quad.call(1.0,rng.randf(),0.0,rng.randf(),rng.randf_range(0.3,0.5),0.0)
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

## One frame, after the plane moved.
func step(delta: float, eye: Vector3, plane: RefCounted) -> void:
	var began := Time.get_ticks_usec()
	_clock += delta
	_read(delta,eye,plane)
	_wait(delta)
	_fly(delta)
	if swim != null: swim.step(delta)
	_plops(eye)
	_draw(delta)
	ms = (Time.get_ticks_usec()-began)/1000.0
	ms_avg = lerpf(ms_avg,ms,0.05)

## The plane's line and the camera's way this frame.
func _read(delta: float, eye: Vector3, plane: RefCounted) -> void:
	var way := Vector3(plane.velocity.x,0.0,plane.velocity.z)
	_at = plane.position
	_high = _at.y-Field.SEA_Y
	_speed = way.length()
	_eye = eye
	if _speed > 1.0:
		var now := way/_speed
		_turn = lerpf(_turn,-_ahead.cross(now).y/maxf(delta,0.001),1.0-exp(-delta/0.25))
		_ahead = now
		_right = now.cross(Vector3.UP)
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var on := -camera.global_basis.z*Vector3(1.0,0.0,1.0)
	if on.length() < 0.01: return
	_look_on = on.normalized()
	_look_right = _look_on.cross(Vector3.UP)

## Where the plane will be in `t` s, turning as it is.
func _line(t: float) -> Vector3:
	var along := _speed*t
	return _at+_ahead*along+_right*0.5*_turn*along*t

## Time low over a lake counts the next moment down.
func _wait(delta: float) -> void:
	_look -= delta
	if _look <= 0.0:
		_look = LOOK
		_low = _high < LOW and _lake(_at.x,_at.z)
	if not _low: return
	water_s += delta
	_left -= delta
	if _left > 0.0 or _speed < 5.0 or not _leaps.is_empty() or (swim != null and swim._on): return
	# The last one isn't among them, and neither is one that couldn't be placed.
	var chosen := _choose()
	if chosen == "":
		_left = AGAIN
		return
	moments[chosen] = int(moments[chosen])+1
	last_moment_at = water_s
	_last = chosen
	_left = _gap_mean*_rng.randf_range(1.0-GAP_SPREAD,1.0+GAP_SPREAD)

func _choose() -> String:
	var open: Array = []
	var total := 0.0
	for m: Array in _moments:
		if m[0] == _last and _moments.size() > 1: continue
		open.append(m)
		total += float(m[1])
	while not open.is_empty():
		var roll := _rng.randf()*total
		for m: Array in open:
			roll -= float(m[1])
			if roll > 0.0: continue
			if _moment(m[0]): return m[0]
			total -= float(m[1])
			open.erase(m)
			break
	return ""

## The moment by name, on either side: false if it has no water to fall in.
func _moment(kind: String) -> bool:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in SIDES:
		var done := false
		match kind:
			"over": done = _over(side)
			"wing": done = _beside(side,WING)
			"far": done = _beside(side,FAR)
			"pair": done = _beside(side,PAIR,true)
			"big": done = _beside(side,BIG_FAR if _rng.randf() < BIG_FAR_SHARE else BIG)
		if done: return true
		side = -side
	return false

func _length(share: Vector2) -> float:
	return lerpf(LONG.x,LONG.y,_rng.randf_range(share.x,share.y))*_size

## Over the plane: the top of the arc over the nose as it gets there. Only at
## about wingtip height, on a steady line: from any higher a fish can't reach.
func _over(side: float) -> bool:
	if _high > OVER_BELOW or absf(_turn) > OVER_STEADY: return false
	var long := _length(Vector2(0.7,1.0))
	var peak := _high+_rng.randf_range(OVER_CLEAR.x,OVER_CLEAR.y)
	var run := _rng.randf_range(OVER_RUN.x,OVER_RUN.y)
	var way := _right*side
	if _rng.randf() < OVER_ALONG: way = _ahead*(1.0 if _rng.randf() < 0.3 else -1.0)
	way = way.rotated(Vector3.UP,_rng.randf_range(-0.45,0.45))
	var l := _leap_for(long,peak,run)
	l.wait = _rng.randf_range(SWIRL_OVER.x,SWIRL_OVER.y)
	var moment := l.wait+_to_clock(l,l.top)
	var spot := _line(moment)+_ahead*OVER_FORE
	_flank_to(l,way,_eye-_at)
	if not _send(l,Vector2(spot.x,spot.z),Vector2(way.x,way.z).normalized(),0.5): return false
	l.lead_on = _clock+moment
	return true

## A fish in the view: `spec`'s `on` m from the eye and `off` rad off its axis to
## `side` at the moment it's `through` its leap. A pair: another close behind it.
func _beside(side: float, spec: Dictionary, pair := false) -> bool:
	var heavy: bool = spec.get("heavy",false)
	var long := _rng.randf_range(spec.long.x,spec.long.y)*_big_size*_size if heavy else _length(spec.long)*float(spec.get("big",1.0))
	var peak: float = _rng.randf_range(spec.peak.x,spec.peak.y)*(1.0 if heavy else clampf(long/0.6,0.75,1.25))
	var run: float = _rng.randf_range(spec.run.x,spec.run.y)
	var through: float = _rng.randf_range(spec.through.x,spec.through.y)
	var l := _leap_for(long,peak,run)
	if heavy: _heavy(l)
	var moment := l.wait+_to_clock(l,l.air*through)
	var on: float = _rng.randf_range(spec.on.x,spec.on.y)
	var off: float = tan(_rng.randf_range(spec.off.x,spec.off.y))*on
	var eye := _line(moment)+_eye-_at
	var there := eye+_look_on*on+_look_right*side*off
	# Side on to the eye, mostly, so the arc reads: then out from the line or the
	# way the plane's going.
	var to := (there-eye).normalized()
	var way := Vector3(-to.z,0.0,to.x)*(1.0 if _rng.randf() < 0.5 else -1.0)
	var pick := _rng.randf()
	if pick > 0.85: way = _ahead
	elif pick > 0.65: way = _right*side
	way = way.rotated(Vector3.UP,_rng.randf_range(-0.5,0.5))
	var dir := Vector2(way.x,way.z).normalized()
	if _rng.randf() < FLANK_SHARE: _flank_to(l,way,eye-there)
	if not _send(l,Vector2(there.x,there.z),dir,through): return false
	if pair:
		var second := _leap_for(long*_rng.randf_range(0.72,0.95),peak*_rng.randf_range(0.7,1.05),run*_rng.randf_range(0.85,1.1))
		second.wait = l.wait+_rng.randf_range(SECOND_AFTER.x,SECOND_AFTER.y)
		var beside := dir.orthogonal()*(1.0 if _rng.randf() < 0.5 else -1.0)*_rng.randf_range(SECOND_OFF.x,SECOND_OFF.y)
		_send(second,Vector2(there.x,there.z)+beside,dir.rotated(_rng.randf_range(-0.3,0.3)),through)
	return true

## What makes a leap a big fish's.
func _heavy(l: Leap) -> void:
	l.heavy = true
	l.shape *= BIG_BUILD
	l.wait = _rng.randf_range(BIG_SWIRL.x,BIG_SWIRL.y)
	l.hang = _rng.randf_range(BIG_HANG.x,BIG_HANG.y)
	l.beat_hz = _rng.randf_range(BIG_BEAT_HZ.x,BIG_BEAT_HZ.y)
	l.arch = _rng.randf_range(BIG_ARCH.x,BIG_ARCH.y)
	l.flips = 1.0
	l.roll = _rng.randf_range(-0.15,0.15)
	l.twist = _rng.randf_range(BIG_TWIST.x,BIG_TWIST.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	l.wobble = _rng.randf_range(0.05,0.15)

## It rolls its flank up to the eye (`to_eye`) through the leap, running along
## `way`: seen from over it, the back's dark on dark water.
func _flank_to(l: Leap, way: Vector3, to_eye: Vector3) -> void:
	var side_on := Vector3.UP.cross(way)
	l.roll = _rng.randf_range(-0.15,0.2)
	l.twist = _rng.randf_range(1.3,2.3)*(1.0 if side_on.dot(to_eye) > 0.0 else -1.0)

## A leap of this size, not yet on the water: `run` its speed along the water.
func _leap_for(long: float, peak: float, run: float) -> Leap:
	var l := Leap.new()
	l.kind = KINDS[_rng.randi()%KINDS.size()]
	l.long = long
	l.shape = Vector2(float(l.kind.wide),float(l.kind.deep))*_rng.randf_range(0.96,1.05)
	l.level = Field.SEA_Y
	l.wait = _rng.randf_range(SWIRL.x,SWIRL.y)
	var sink := long*SINK
	l.v0 = sqrt(2.0*GRAVITY*(peak+sink))
	l.air = 2.0*l.v0/GRAVITY
	l.top = l.v0/GRAVITY
	l.vh = run
	l.hang = _rng.randf_range(HANG.x,HANG.y)
	l.lead = _rng.randf_range(LEAD.x,LEAD.y)
	l.side = 1.0 if _rng.randf() < 0.5 else -1.0
	# The body's held bend, how often it changes sides, and the tail.
	l.arch = _rng.randf_range(0.7,1.7)
	l.flips = float(_rng.randi_range(1,3))
	l.beat = _rng.randf_range(0.5,0.85)
	l.beat_hz = _rng.randf_range(6.0,11.0)
	l.phase = _rng.randf()*TAU
	l.roll = _rng.randf_range(-0.35,0.35)
	l.twist = _rng.randf_range(0.5,2.3)*(1.0 if _rng.randf() < 0.5 else -1.0)
	l.wobble = _rng.randf_range(0.1,0.4)
	return l

## From the break to `to` s on its own clock, on the frame's clock (the hang
## stretches it).
func _to_clock(l: Leap, to: float) -> float:
	var at := 0.0
	var t := 0.0
	const H := 1.0/120.0
	while at < to:
		at += H*_rate(l,at)
		t += H
	return t

## How fast a fish's own clock runs at `at`: slowed round the top of the arc.
func _rate(l: Leap, at: float) -> float:
	var off := (at-l.top)/HANG_LONG
	return 1.0-l.hang*exp(-off*off)

## On the water, its place at `share` of its air at `there`: false if that isn't
## water, or the fish has nowhere to go.
func _send(l: Leap, there: Vector2, dir: Vector2, share: float) -> bool:
	var spot := there-dir*l.vh*l.air*share
	var land := spot+dir*l.vh*l.air
	if not (_lake(spot.x,spot.y) and _lake(land.x,land.y) and _lake(there.x,there.y)): return false
	var node: MeshInstance3D = null
	for f: MeshInstance3D in _pool:
		var busy := false
		for o: Leap in _leaps: busy = busy or o.node == f
		if not busy: node = f
	if node == null: return false
	l.node = node
	l.mat = node.material_override
	l.dir = dir
	l.at = Vector3(spot.x,l.level-l.long*SINK,spot.y)
	var k := l.kind
	l.mat.set_shader_parameter("back_tint",k.back)
	l.mat.set_shader_parameter("flank_tint",k.flank)
	l.mat.set_shader_parameter("belly_tint",k.belly)
	l.mat.set_shader_parameter("spot_tint",k.spot)
	l.mat.set_shader_parameter("band_tint",k.band)
	l.mat.set_shader_parameter("fin_tint",k.fin)
	l.mat.set_shader_parameter("spot_share",k.spots)
	l.mat.set_shader_parameter("band_share",k.bands)
	l.mark = _mark(Vector3(spot.x,l.level,spot.y),_clock+l.wait,l.long/0.6)
	_leaps.append(l)
	last_at = l.at
	return true

## A spot of a lake: the sea's level inside the land.
func _lake(x: float, z: float) -> bool:
	return float(_field.height(x,z)) < Field.SEA_Y-DEEP and float(_field.edge_off(x,z)) < -LAKE_IN and is_nan(float(_field.river_y(x,z)))

## A mark on the water, breaking at `breaks`: its slot.
func _mark(at: Vector3, breaks: float, size: float) -> int:
	var slot := _mark_next
	_mark_next = (slot+1)%MARKS
	_marks[slot] = Vector4(at.x,at.z,breaks,size)
	_marks_until = maxf(_marks_until,breaks+MARK_LIFE)
	return slot

## The fish in hand, a frame on.
func _fly(delta: float) -> void:
	var i := _leaps.size()-1
	while i >= 0:
		var l := _leaps[i]
		i -= 1
		if l.lead_on >= 0.0 and _clock < l.lead_on: _lead(l,delta)
		if l.wait > 0.0:
			l.wait -= delta
			if l.wait > 0.0: continue
			l.node.visible = true
		l.clock += delta*_rate(l,l.clock)
		var t := l.clock
		var pos := l.at+l.moved+Vector3(l.dir.x*l.vh*t,l.v0*t-0.5*GRAVITY*t*t,l.dir.y*l.vh*t)
		var vel := Vector3(l.dir.x*l.vh,l.v0-GRAVITY*t,l.dir.y*l.vh)
		var nose := pos.y+vel.normalized().y*l.long*0.42
		if not l.out and nose > l.level:
			l.out = true
			_splash(Vector3(pos.x,l.level,pos.z),vel,l.long/0.6,false)
			_plop_later(Vector3(pos.x,l.level,pos.z),l.long/0.6,true)
		if l.out and not l.went_in and vel.y < 0.0 and nose < l.level:
			l.went_in = true
			var into := Vector3(pos.x,l.level,pos.z)+vel.normalized()*Vector3(1,0,1)*l.long*0.42
			_splash(into,vel,l.long/0.6,true)
			if l.heavy: _splash(into,vel*0.5,l.long/0.6*BIG_SLAM,true,BIG_SLAM_AFTER)
			_mark(into,_clock,l.long/0.6*1.3)
			_plop_later(into,l.long/0.6)
		if t > l.air*1.08 or (l.went_in and pos.y < l.level-l.long*0.72):
			l.node.visible = false
			_leaps.remove_at(i+1)
			continue
		_pose(l,pos,vel)

## Keeps a fish on the plane's line as the line moves.
func _lead(l: Leap, delta: float) -> void:
	var left := l.lead_on-_clock
	var want := _line(left)+_ahead*OVER_FORE
	var nominal := l.at+l.moved+Vector3(l.dir.x,0.0,l.dir.y)*l.vh*l.top
	var err := Vector3(want.x-nominal.x,0.0,want.z-nominal.z)
	var under := l.wait > 0.0
	var goal := (l.moved+err).limit_length(STEER_UNDER if under else STEER)
	l.moved = l.moved.move_toward(goal,(STEER_UNDER_RATE if under else STEER_RATE)*delta)
	if under and l.mark >= 0:
		var m := _marks[l.mark]
		_marks[l.mark] = Vector4(l.at.x+l.moved.x,l.at.z+l.moved.z,m.z,m.w)

## The body: along its flight with the nose leading round the top, rolling over
## as it goes, its spine bent by a held curve and the tail's beat.
func _pose(l: Leap, pos: Vector3, vel: Vector3) -> void:
	var t := l.clock
	var u := clampf(t/l.air,0.0,1.0)
	var climb := atan2(vel.y,l.vh)-l.lead*sin(u*PI)
	var along := Vector3(l.dir.x,0.0,l.dir.y)
	var fore := (along*cos(climb)+Vector3.UP*sin(climb)).normalized()
	var over := Vector3.UP.cross(fore).normalized()
	var b := Basis(over,fore.cross(over),fore)
	var roll := l.roll+l.twist*smoothstep(0.08,0.92,u)+l.wobble*sin(u*TAU*l.flips+l.phase)
	b = Basis(fore,roll)*b
	# Stretched as it bursts out.
	var long := l.long*(1.0+0.08*(1.0-smoothstep(0.0,0.25,u)))
	var thin := 1.0/sqrt(1.0+0.08*(1.0-smoothstep(0.0,0.25,u)))
	l.node.global_transform = Transform3D(b*Basis.from_scale(Vector3(l.long*l.shape.x*thin,l.long*l.shape.y*thin,long)),pos)
	# The bend held through the air, thrown over to the other side `flips` times.
	var bend := l.side*l.arch*sin(u*PI*l.flips)*pow(sin(u*PI),0.6)
	# The beat: hard as it breaks out, dying at the top, a last flick going in.
	var beat := l.beat*(0.2+(1.0-smoothstep(0.0,0.4,u))+0.9*smoothstep(0.72,0.92,u))
	var wave := TAU*l.beat_hz*t+l.phase
	var head := 0.7*(bend*(0.25-0.42)*1.5+beat*pow(0.25,1.6)*sin(wave-0.25*5.5))
	var x := 0.0
	var z := 0.42
	for i in 9:
		var s := i/8.0
		var theta := bend*(s-0.42)*1.5+beat*pow(s,1.6)*sin(wave-s*5.5)-head
		if i > 0:
			x += sin(theta)/8.0
			z -= cos(theta)/8.0
		_spine[i] = Vector3(x,z,theta)
	# Round its middle.
	var mid := _spine[3]
	for i in 9: _spine[i] -= Vector3(mid.x,mid.y-(0.42-3.0/8.0),0.0)
	l.mat.set_shader_parameter("spine",_spine)
	l.mat.set_shader_parameter("flare",lerpf(-1.0,0.6,sin(u*PI)))

## A splash where it goes through the water, `vel` its velocity there.
func _splash(at: Vector3, vel: Vector3, size: float, going_in: bool, after := 0.0) -> void:
	var o := _s_next*16
	_s_next = (_s_next+1)%SPLASHES
	var lifted := at+Vector3.UP*LIFT
	_s_buf[o] = vel.x
	_s_buf[o+4] = vel.y
	_s_buf[o+8] = vel.z
	_s_buf[o+3] = lifted.x
	_s_buf[o+7] = lifted.y
	_s_buf[o+11] = lifted.z
	_s_buf[o+12] = _clock+after
	_s_buf[o+13] = size
	_s_buf[o+14] = 1.0 if going_in else 0.0
	_s_buf[o+15] = _rng.randf()
	_s_mm.buffer = _s_buf
	_s_until = maxf(_s_until,_clock+after+3.5)

## A plop a beat after a fish goes in at `at`, or with `splash` the burst of
## one breaking the surface (no beat: only the sound's way to the eye).
func _plop_later(at: Vector3, size: float, splash := false) -> void:
	if _streams.is_empty(): return
	var free := 0
	for i in _p_when.size():
		if _p_when[i] < 0.0: free = i
	_p_when[free] = _clock+(0.0 if splash else _rng.randf_range(BEAT.x,BEAT.y))+at.distance_to(_eye)/SOUND_SPEED
	_p_at[free] = at
	_p_size[free] = size
	_p_splash[free] = 1 if splash and not _splashes.is_empty() else 0

func _plops(eye: Vector3) -> void:
	if _streams.is_empty(): return
	for i in _p_when.size():
		var when := _p_when[i]
		if when < 0.0 or _clock < when: continue
		_p_when[i] = -1.0
		var at := _p_at[i]
		if at.distance_squared_to(eye) > HEAR*HEAR: continue
		for a: AudioStreamPlayer3D in _players:
			if a.playing: continue
			var big := clampf((_p_size[i]-0.6)/0.8,0.0,1.0)
			# A big fish, lower still.
			var low := 0.72 if _p_size[i] > 2.0 else 1.0
			a.stream = _splashes[_rng.randi()%_splashes.size()] if _p_splash[i] == 1 else _streams[_rng.randi()%_streams.size()]
			a.global_position = at
			a.volume_db = lerpf(PLOP_DB.x,PLOP_DB.y,big)+_rng.randf_range(-2.0,2.0)
			a.pitch_scale = lerpf(1.3,0.9,big)*low*_rng.randf_range(0.92,1.08)
			a.play()
			break

## What changed goes up; the clock, only while anything lives.
func _draw(delta: float) -> void:
	if _warm > 0.0:
		_warm -= delta
		if _warm <= 0.0:
			for f: MeshInstance3D in _pool: f.visible = false
			_s_node.visible = false
	var alive := _clock < _s_until
	if alive != _s_node.visible and _warm <= 0.0: _s_node.visible = alive
	if alive: _s_mat.set_shader_parameter("clock",_clock)
	if sea != null: sea.leaps(_marks,_clock,_clock < _marks_until)

## The numbers' line (--numbers).
func note() -> String:
	return "\nleaping fish: low over a lake %.0f s, next in %.0f s, %s  %.2f ms (%.2f)" % [water_s,_left,str(moments),ms,ms_avg]+(swim.note() if swim != null else "")
