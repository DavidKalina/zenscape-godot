extends Node3D
## What a plane leaves in a cloud: a torn tunnel along its path and tufts of
## cloud dragged out after it, like a piece pulled off a cotton ball. Every
## flier counts, the eye's plane (scripts/wanderer_eye.gd) and the CPU
## traffic (scripts/sky_traffic.gd) alike, so a plane seen crossing a cloud
## leaves it split.
##
## The tunnel is a trail of points (`points`), laid every SPACING metres
## while a flier is in cloud (`trace`). Each tears open fast (OPEN), widens
## as the air behind the plane stirs (WIDEN), holds, then heals over HEAL as
## the cloud closes back in. The clouds read them: the drifting puffs push
## out of the way and thin along the tunnel (shaders/sky_cloud_puff.gdshader
## `wake_*`), drifting along with them, and a towering cumulus is carved
## along it as it is marched (shaders/sky_tower.gdshader). `strength` and
## `radius` say how open a point is at an age, the shaders' same curve.
##
## The tufts (shaders/sky_cloud_tuft.gdshader) are soft scraps of cloud.
## Inside, the plane drags a few along, pushed out off the tunnel's line;
## leaving, it pulls a burst out of the cloud's far side, flung on after it
## and stretched along the way they fly. They slow on the air's drag, drift
## off on the breeze, swell and fray into nothing.
##
## World coordinates; the islands' swaps move it all (`move`). Plain state
## and maths besides the tufts' drawing, so tests can step it.

## Most points held, and how far apart they are laid (m).
const COUNT := 32
const SPACING := 4.5
## A flier counts as in cloud from this deep (0 to 1), and its exit burst
## comes on falling from over EXIT_FROM to under EXIT_TO.
const IN := 0.06
const EXIT_FROM := 0.22
const EXIT_TO := 0.1
## The tunnel's radius where the plane cuts it (m), how much wider it gets,
## and over how long (s).
const RADIUS := 4.0
const WIDEN := 1.5
const WIDEN_TIME := 3.0
## Seconds to tear open, to hold, and to heal.
const OPEN := 0.35
const HOLD := 7.0
const HEAL := 22.0
const LIFE := HOLD+HEAL
## The tufts: most alive, how many a second at full depth and speed, how
## many in an exit burst, their size (m) and life (s), how much of the
## plane's velocity they take, and the air's drag on them (1/s).
const TUFTS := 140
const TUFT_RATE := 9.0
const BURST := 16
const TUFT_SIZE := Vector2(1.2,3.2)
const TUFT_LIFE := Vector2(4.0,9.0)
const TUFT_CARRY := Vector2(0.55,1.0)
const DRAG := 0.8
## The breeze the drifting clouds ride (SkyClouds DRIFT), the tufts too.
const BREEZE := Vector2(0.6,0.3)
## Speeds (m/s) where a flier starts tearing and where it is full.
const SPEED := Vector2(3.0,14.0)

## The trail: each Vector4(x, y, z, time laid), and its way and radius
## Vector4(dx, dy, dz, radius), the way the step back to the point before
## it (0 for a trail's first). A radius of 0 is none.
var at := PackedVector4Array()
var way := PackedVector4Array()
var _next := 0
## Each flier by id: {last (where it last laid), depth, fresh (no point yet)}.
var _fliers := {}
## Each tuft: {position, velocity, age, life, size, seed}.
var tufts := []
var _rng := RandomNumberGenerator.new()
var _owed := 0.0
var _mesh: MultiMeshInstance3D

func _init() -> void:
	name = "CloudWakes"
	_rng.seed = 5150
	at.resize(COUNT)
	way.resize(COUNT)
	clear()

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = TUFTS
	multimesh.visible_instance_count = 0
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sky_cloud_tuft.gdshader")
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Tufts"
	_mesh.multimesh = multimesh
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Turned to the eye in the shader; never cull them.
	_mesh.custom_aabb = AABB(Vector3.ONE*-1e5,Vector3.ONE*2e5)
	add_child(_mesh)

## No tunnels, no tufts.
func clear() -> void:
	at.fill(Vector4.ZERO)
	way.fill(Vector4.ZERO)
	_next = 0
	_fliers.clear()
	tufts.clear()
	_owed = 0.0

## How open a tunnel point is at `age` seconds (0 to 1).
static func strength(age: float) -> float:
	if age < 0.0 or age >= LIFE: return 0.0
	return smoothstep(0.0,OPEN,age)*(1.0-smoothstep(HOLD,LIFE,age))

## A tunnel point's radius at `age` (m): widening behind the plane, then
## closing in as it heals.
static func radius(age: float) -> float:
	return RADIUS*(1.0+WIDEN*smoothstep(0.0,WIDEN_TIME,age))*sqrt(maxf(strength(age),0.0))

## One step of a flier `id`: where it is, its velocity, and how deep in
## cloud it is (0 to 1); `time` is the scene's motion time.
func trace(id: Variant, position: Vector3, velocity: Vector3, depth: float, time: float, delta: float) -> void:
	var f: Dictionary = _fliers.get(id,{})
	if f.is_empty():
		f = {"last":position,"depth":0.0,"fresh":true}
		_fliers[id] = f
	var tear := clampf((velocity.length()-SPEED.x)/(SPEED.y-SPEED.x),0.0,1.0)
	if depth > IN and tear > 0.0:
		if bool(f.fresh) or position.distance_to(f.last) >= SPACING:
			_lay(position,Vector3.ZERO if bool(f.fresh) else position-Vector3(f.last),time)
			f.last = position
			f.fresh = false
		# Scraps dragged along inside.
		_owed += TUFT_RATE*depth*tear*delta
		while _owed >= 1.0:
			_owed -= 1.0
			_tuft(position,velocity,false)
	else:
		f.fresh = true
	# Leaving: a burst pulled out after it.
	if float(f.depth) > EXIT_FROM and depth < EXIT_TO and tear > 0.0:
		for i in range(int(round(BURST*tear))): _tuft(position,velocity,true)
	if depth < EXIT_TO or float(f.depth) < depth: f.depth = depth

## A flier gone (landed, hidden): its trail ends.
func forget(id: Variant) -> void:
	_fliers.erase(id)

func _lay(point: Vector3, back: Vector3, time: float) -> void:
	# Into the slot of the point nearest its end, so a full trail drops the
	# oldest rather than a fresh one.
	var slot := _next
	var least := INF
	for i in range(COUNT):
		var left := -INF if way[i].w <= 0.0 else LIFE-(time-at[i].w)
		if left < least:
			least = left
			slot = i
		if left == -INF: break
	at[slot] = Vector4(point.x,point.y,point.z,time)
	way[slot] = Vector4(back.x,back.y,back.z,RADIUS)
	_next = (slot+1)%COUNT

func _tuft(point: Vector3, velocity: Vector3, burst: bool) -> void:
	if tufts.size() >= TUFTS: tufts.pop_front()
	var ahead := velocity.normalized() if velocity.length() > 0.01 else Vector3.FORWARD
	var side := ahead.cross(Vector3.UP)
	if side.length() < 0.1: side = ahead.cross(Vector3.RIGHT)
	side = side.normalized()
	var lift := side.cross(ahead).normalized()
	var a := _rng.randf()*TAU
	var out := side*cos(a)+lift*sin(a)
	# Torn off round the plane, flung outward off the line; a burst is
	# pulled on after it, inside ones lag back as they are dragged.
	var carry := _rng.randf_range(TUFT_CARRY.x,TUFT_CARRY.y)*(1.0 if burst else 0.6)
	var spray := _rng.randf_range(0.8,3.2)*(1.6 if burst else 1.0)
	tufts.append({
		"position":point+out*_rng.randf_range(0.4,2.2)-ahead*_rng.randf_range(0.0,2.5 if burst else 1.0),
		"velocity":velocity*carry+out*spray,
		"age":0.0,
		"life":_rng.randf_range(TUFT_LIFE.x,TUFT_LIFE.y)*(1.15 if burst else 1.0),
		"size":_rng.randf_range(TUFT_SIZE.x,TUFT_SIZE.y)*(1.25 if burst else 1.0),
		"seed":_rng.randf(),
	})

## The tufts fly on, slow, drift and fray; the drawing follows.
func advance(delta: float) -> void:
	if delta > 0.0:
		var keep := 0.0 if DRAG*delta > 30.0 else exp(-DRAG*delta)
		var breeze := Vector3(BREEZE.x,0.0,BREEZE.y)
		var alive := []
		for t: Dictionary in tufts:
			t.age = float(t.age)+delta
			if float(t.age) >= float(t.life): continue
			t.velocity = breeze+(Vector3(t.velocity)-breeze)*keep
			t.position = Vector3(t.position)+Vector3(t.velocity)*delta
			alive.append(t)
		tufts = alive
	_draw()

## Moves everything by `by` (an island swap).
func move(by: Vector3) -> void:
	for i in range(COUNT):
		if way[i].w > 0.0: at[i] += Vector4(by.x,by.y,by.z,0.0)
	for id in _fliers: _fliers[id].last = Vector3(_fliers[id].last)+by
	for t: Dictionary in tufts: t.position = Vector3(t.position)+by

## How many tunnel points are still open at `time`.
func open_count(time: float) -> int:
	var n := 0
	for i in range(COUNT):
		if way[i].w > 0.0 and strength(time-at[i].w) > 0.0: n += 1
	return n

## The points near a box (global middle, half size), for a tower's march:
## [ats, ways], up to `most`, padded with none.
func near_box(middle: Vector3, half: Vector3, time: float, most: int) -> Array:
	var ats := PackedVector4Array()
	var ways := PackedVector4Array()
	var reach := half+Vector3.ONE*(RADIUS*(1.0+WIDEN)+SPACING)
	for i in range(COUNT):
		if ats.size() >= most: break
		if way[i].w <= 0.0 or strength(time-at[i].w) <= 0.0: continue
		var d := (Vector3(at[i].x,at[i].y,at[i].z)-middle).abs()
		if d.x > reach.x or d.y > reach.y or d.z > reach.z: continue
		ats.append(at[i])
		ways.append(way[i])
	var count := ats.size()
	while ats.size() < most:
		ats.append(Vector4.ZERO)
		ways.append(Vector4.ZERO)
	return [ats,ways,count]

func _draw() -> void:
	if _mesh == null: return
	var multimesh := _mesh.multimesh
	var n := mini(tufts.size(),TUFTS)
	for i in range(n):
		var t: Dictionary = tufts[i]
		var life := float(t.age)/float(t.life)
		# Swelling as it frays; the shader turns it to the eye along its way.
		var size := float(t.size)*(1.0+1.3*life)
		var basis := Basis(Vector3.RIGHT*size,Vector3.UP*maxf(life,0.001),Vector3.BACK)
		multimesh.set_instance_transform(i,Transform3D(basis,t.position))
		var v: Vector3 = t.velocity
		multimesh.set_instance_custom_data(i,Color(v.x,v.y,v.z,float(t.seed)))
	multimesh.visible_instance_count = n
