extends Node3D
## Forest seed, thrown by hand (docs/scenic/brushes.md "Pollen",
## docs/scenic/handful.md, docs/scenic/god-hand.md). You throw it; the world
## decides what becomes of it.
##
## With forest in hand, holding the button fills a handful and throws it at
## the pointer, a throw about every THROW_SECONDS, and letting go throws the
## last of it. Every mote is a particle under gravity and air drag toward the
## wind, so what a throw carries is real: heavy seeds arc out and come down
## round where the pointer was, scattered, and a seed coming down fast skips
## once; a throw made on the move carries on the pointer's way; light pollen
## dust puffs out of the hand and floats down on the wind. Where each lands is
## where it lands. A seed landing where the ground could take it (`takes`)
## sprouts, and when a sowing's last mote is down (press to release, every
## throw) it settles as one undo step: `settled` hands its seeds to the
## editor, which raises the forest wish round them and lets emergence decide
## what grows (NativeChunkEditor `_pollen_settled`).
##
## The promise: a soft footprint on the ground (shaders/pollen_footprint.gdshader)
## shows where the next throw's seeds will come down, aimed at the pointer and
## carried on by the pointer's way and the wind as it blows now, and each
## throw's own until its seeds are down. They land inside it unless the wind
## changes while they fly. Dust is not promised: it grows nothing.
##
## Under `--hand-everywhere` the God Hand (scripts/god_hand.gd) holds the
## handful as a pinch in its fingertips (`hand_at`) and it flies when the hand
## tosses (`toss`), at its toss's angle; the hand stands `stand_off()` back
## from the pointer, so each throw is a lob onto it. Otherwise nothing holds
## it and the handful throws itself from STAND_OFF back on the camera's side,
## THROW_HEIGHT up. (The materials bar sows the veil, scripts/pollen_cloud.gd,
## whose `hand_at` and `toss` this shares.)
##
## It keeps the API of the pollen veil it replaced (scripts/pollen_cloud.gd,
## still there behind `--pollen-veil`).
##
## Lives under the terrain node, so its coordinates are the plate's.

const Wind = preload("res://scripts/pollen_wind.gd")
const Veil = preload("res://scripts/pollen_cloud.gd")

## A sowing's last mote is down: {"id", "seeds" (plate x, z), "points" (every
## landing), "lost" (motes that fell off the land), "motes", "throws", "radius"
## (the widest throw's promise), "path" (each throw's promised landing),
## "outside" (seeds that landed outside their throw's promise as it stood
## when they were thrown)}.
signal settled(cloud: Dictionary)

const GRAVITY := 9.8
## Terminal fall speeds (m/s) of a seed and of pollen dust: the air drags each
## toward its own speed at GRAVITY / that, per second.
const SEED_FALL := 5.0
const DUST_FALL := 0.65
## The share of a handful that is seed; the rest is dust.
const SEED_SHARE := 0.35
## Motes a press takes into the handful, and a second while held, at
## REFERENCE_RADIUS and strength 1. A brush's radius scales the handful and
## its scatter within SIZE.
const PUFF := 36
const FILL := 36.0
const REFERENCE_RADIUS := 3.6
const SIZE := Vector2(0.6,1.6)
## The handful's own throws, without a hand: seconds apart (the hand's pace),
## the first after FIRST_THROW; thrown from STAND_OFF m back and THROW_HEIGHT
## m up. Every throw leaves between ANGLE radians up, the hand's own angle
## where it has one.
const THROW_SECONDS := 1.33
const FIRST_THROW := 0.5
const STAND_OFF := 2.2
const THROW_HEIGHT := 1.4
const ANGLE := Vector2(0.55,0.9)
const DEFAULT_ANGLE := 0.75
## Scatter at REFERENCE_RADIUS: radians either way across (half that up and
## down) and the share of the speed; dust goes wider and slower.
const SPREAD := 0.55
const SPEED_JITTER := 0.22
const DUST_SPREAD := 0.8
const DUST_SPEED := Vector2(0.3,0.65)
## The share of the pointer's own speed a throw carries on with, and how
## quickly (1/s) the pointer's speed is read.
const CARRY := 0.8
const POINTER_EASE := 8.0
## A seed landing faster than SKIP_SPEED m/s skips once, keeping BOUNCE of
## its fall and SKID of its way across.
const SKIP_SPEED := 1.5
const BOUNCE := 0.28
const SKID := 0.45
## Dust wanders on the curl of the air (m/s).
const CURL := 0.3
## The longest a handful waits in the hand for its throw (s), held and after
## the button comes up, before it goes by itself.
const HAND_WAIT := 1.8
const RELEASE_WAIT := 0.6
## The pinch's size in the fingertips (m).
const HANDFUL := 0.07
## A promise is the scatter's reach and this much more (m).
const PROMISE_MARGIN := 0.4
## Seeds of a sowing land at least SEED_GAP apart to be its seeds (Emergence
## TREE_GAP); closer ones are dust.
const SEED_GAP := 1.1
## Seconds a landed mote glints; the sprout's pop, life and height (m).
const GLINT := 0.8
const SPROUT_POP := 0.35
const SPROUT_SECONDS := 9.0
const SPROUT_SIZE := 0.3
## Sowings in the air at once; another's release lands the oldest at once.
const CLOUDS := 4
const MOTES_MAX := 2560
const SPROUTS_MAX := 160
## Seconds between aims for the promise.
const AIM_EVERY := 0.08

## The editor's ground: plate x, z -> height, NAN off the land. Whether a
## seed landing there could take (a sprout shows). The scene, for the wind
## and the camera.
var ground_at: Callable = func(_p: Vector2) -> float: return 0.0
var takes: Callable = func(_p: Vector2) -> bool: return true
var scene: Node
## A thrower's handful (plate), or null: the handful gathers there.
var hand_at: Variant = null
## Microseconds the last frame's step took (for probes).
var last_usec := 0
var age := 0.0
## The sowing in hand, or {}; sowings let go with motes still to land.
var held := {}
var clouds: Array[Dictionary] = []
var _hover: Variant = null
var _hover_scale := 1.0
var _serial := 0
var _sprouts: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
var _mote_node: MultiMeshInstance3D
var _sprout_node: MultiMeshInstance3D
var _prints: Array[MeshInstance3D] = []
## The promise of the next throw, and when it was last aimed.
var _next := {}
var _next_age := -1.0

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pollen_mote.gdshader")
	_mote_node = _instances("Motes",Veil._mesh("mote"),MOTES_MAX,material)
	_sprout_node = _instances("Sprouts",Veil._mesh("sprout"),SPROUTS_MAX,material)
	for i in range(CLOUDS+2):
		var print_material := ShaderMaterial.new()
		print_material.shader = preload("res://shaders/pollen_footprint.gdshader")
		print_material.render_priority = -1
		var node := MeshInstance3D.new()
		node.name = "Footprint%d" % i
		node.mesh = BoxMesh.new()
		node.material_override = print_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		node.visible = false
		add_child(node)
		_prints.append(node)

func _instances(title: String, mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.instance_count = count
	# Nothing draws until its transform is written (a fresh buffer is zeros).
	instances.visible_instance_count = 0
	instances.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)
	return node

## Aiming: the promise of a throw at `point` (plate, on the ground), or none
## for null. `brush_radius` sizes it.
func hover(point: Variant, brush_radius := REFERENCE_RADIUS) -> void:
	_hover = point
	_hover_scale = clampf(brush_radius/REFERENCE_RADIUS,SIZE.x,SIZE.y)

## Take up a handful to throw at `point` (plate, on the ground). `tree_kind`
## is the stand's tree there (Emergence `seed_family`), "" for the default
## look.
func gather(point: Vector3, brush_radius: float, strength: float, tree_kind: String, salt: int) -> void:
	if not held.is_empty(): release()
	_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var scale := clampf(brush_radius/REFERENCE_RADIUS,SIZE.x,SIZE.y)
	held = {"id":_serial,"rng":rng,"scale":scale,"density":sqrt(clampf(strength,0.25,3.0))*scale*scale,
		"colour":Color(Veil.LOOKS[Veil.FAMILY.get(tree_kind,"broadleaf")]),"target":point,"last":point,"pointer":Vector3.ZERO,
		"handful":[],"fill":0.0,"timer":THROW_SECONDS-FIRST_THROW,"waited":0.0,"motes":[],"throws":[],"seeds":PackedVector2Array(),
		"points":PackedVector2Array(),"lost":0,"down":0,"outside":0,"released":false}
	_take(held,roundi(PUFF*float(held.density)))

## Aim at the pointer's ground point (plate), or hold the aim over null.
func hold(point: Variant) -> void:
	if not held.is_empty() and point != null: held.target = point

## Let go: the last of the handful is thrown (by the hand, when it has one),
## and the sowing settles once its last mote is down.
func release() -> void:
	if held.is_empty(): return
	var sowing := held
	held = {}
	sowing.released = true
	sowing.waited = 0.0
	if hand_at == null: _throw(sowing,_self_from(sowing),Vector3.ZERO)
	if clouds.size() >= CLOUDS: _settle(clouds[0])
	clouds.append(sowing)

## The God Hand throws what is in its palm, `velocity` its handful's (plate
## m/s): the throw leaves at the hand's angle, aimed at the pointer.
func toss(velocity: Vector3) -> void:
	if hand_at == null: return
	var sowing := held
	if sowing.is_empty() or sowing.handful.is_empty():
		sowing = {}
		for cloud: Dictionary in clouds:
			if not cloud.handful.is_empty(): sowing = cloud
	if sowing.is_empty(): return
	_throw(sowing,Vector3(hand_at),velocity)

## Metres back from the pointer a thrower stands.
func stand_off() -> float:
	return STAND_OFF

func active() -> bool:
	return not held.is_empty() or not clouds.is_empty()

## Motes in hand or in the air.
func motes_in_air() -> int:
	var count := 0
	for sowing in _sowings(): count += sowing.handful.size()+sowing.motes.size()-int(sowing.down)
	return count

## Motes in the handful in hand.
func motes_held() -> int:
	return 0 if held.is_empty() else held.handful.size()

## Land everything now, where it was going: a new stroke of another brush,
## an undo or a world change.
func settle_now() -> void:
	release()
	while not clouds.is_empty(): _settle(clouds[0])

## Drop everything, settling nothing: the ground it was going to is gone.
func withdraw() -> void:
	held = {}
	clouds.clear()
	_sprouts.clear()
	_glints.clear()
	_hide()

func _sowings() -> Array[Dictionary]:
	var all: Array[Dictionary] = clouds.duplicate()
	if not held.is_empty(): all.append(held)
	return all

# --- The handful ------------------------------------------------------------------

## `count` more motes into the handful.
func _take(sowing: Dictionary, count: int) -> void:
	var rng: RandomNumberGenerator = sowing.rng
	var palm := _palm(sowing)
	for i in range(count):
		var seed := rng.randf() < SEED_SHARE
		var off := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.3,1),rng.randf_range(-1,1)).limit_length(1.0)
		sowing.handful.append({"seed":seed,"off":off,"p":palm+off*HANDFUL,"v":Vector3.ZERO,"born":age,
			"size":rng.randf_range(0.8,1.2)*(1.3 if seed else 0.75),"phase":rng.randf()*TAU,"spin":rng.randf_range(-9.0,9.0),
			"landed":false,"skipped":false,"throw":-1})

## Where the handful is: the hand's palm, or where it throws itself from.
func _palm(sowing: Dictionary) -> Vector3:
	return Vector3(hand_at) if hand_at != null else _self_from(sowing)

## Without a hand the handful is thrown from STAND_OFF back on the camera's
## side of the pointer, THROW_HEIGHT up.
func _self_from(sowing: Dictionary) -> Vector3:
	var target: Vector3 = sowing.target
	return target+_toward_camera(target)*STAND_OFF+Vector3.UP*THROW_HEIGHT

func _toward_camera(at: Vector3) -> Vector3:
	var camera: Variant = scene.get("camera") if scene != null else null
	if camera == null: return Vector3.RIGHT
	var local := (get_parent() as Node3D).to_local((camera as Node3D).global_position)-at
	var flat := Vector3(local.x,0.0,local.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT

func _step_held(delta: float) -> void:
	var sowing := held
	# The pointer's way, eased, for what a throw carries on with.
	var target: Vector3 = sowing.target
	var moved: Vector3 = (target-Vector3(sowing.last))/maxf(delta,0.001)
	sowing.pointer = Vector3(sowing.pointer).lerp(Vector3(moved.x,0.0,moved.z),1.0-exp(-POINTER_EASE*delta))
	sowing.last = target
	sowing.fill = float(sowing.fill)+FILL*float(sowing.density)*delta
	var more := floori(float(sowing.fill))
	if more > 0:
		sowing.fill = float(sowing.fill)-more
		_take(sowing,more)
	sowing.timer = float(sowing.timer)+delta
	sowing.waited = float(sowing.waited)+delta
	if hand_at == null and float(sowing.timer) >= THROW_SECONDS: _throw(sowing,_self_from(sowing),Vector3.ZERO)
	elif hand_at != null and float(sowing.waited) > HAND_WAIT: _throw(sowing,Vector3(hand_at),Vector3.ZERO)

# --- Throwing ---------------------------------------------------------------------

## Throw the handful from `from` at the sowing's target: at `launch`'s angle
## (or DEFAULT_ANGLE), as fast as lands a seed on the target in still air,
## plus what the pointer's way carries, each mote scattered.
func _throw(sowing: Dictionary, from: Vector3, launch: Vector3) -> void:
	var motes: Array = sowing.handful
	if motes.is_empty(): return
	sowing.handful = []
	sowing.timer = 0.0
	sowing.waited = 0.0
	var shot := _aim(from,sowing.target,launch,Vector3(sowing.pointer)*CARRY)
	var rng: RandomNumberGenerator = sowing.rng
	var spread := SPREAD*float(sowing.scale)
	var along: Vector2 = shot.along
	var up: float = shot.up
	var speed: float = shot.speed
	var carry: Vector3 = shot.carry
	var seeds := 0
	var aimed := Vector2(sowing.target.x,sowing.target.z)
	for mote: Dictionary in motes:
		mote.p = from+Vector3(mote.off)*HANDFUL
		mote.throw = sowing.throws.size()
		# For probes: the pointer it was thrown at, and when.
		mote.aim = aimed
		mote.thrown = age
		if mote.seed:
			seeds += 1
			mote.v = _heading(along.rotated(rng.randf_range(-1,1)*spread),up+rng.randf_range(-0.5,0.5)*spread)*speed*(1.0+rng.randf_range(-1,1)*SPEED_JITTER)+carry
		else:
			mote.v = _heading(along.rotated(rng.randf_range(-1,1)*DUST_SPREAD),up+rng.randf_range(-0.5,0.5)*DUST_SPREAD)*speed*rng.randf_range(DUST_SPEED.x,DUST_SPEED.y)+carry*0.5
		sowing.motes.append(mote)
	var promise := _promise(from,shot,sowing)
	promise.count = motes.size()
	promise.seeds = seeds
	promise.down = 0
	sowing.throws.append(promise)

## Where a throw from `from` at `target` goes: its way across (`along`), its
## angle (`up`, radians), the speed that lands a seed on the target in still
## air (`speed`), how long a seed flies (`time`) and what it carries (`carry`).
func _aim(from: Vector3, target: Vector3, launch: Vector3, carry: Vector3) -> Dictionary:
	var flat := Vector2(target.x-from.x,target.z-from.z)
	var along := flat.normalized() if flat.length() > 0.05 else Vector2(launch.x,launch.z).normalized()
	if along.length_squared() < 0.5: along = Vector2.RIGHT
	var across := Vector2(launch.x,launch.z).length()
	var up := clampf(atan2(launch.y,across),ANGLE.x,ANGLE.y) if launch.length() > 0.5 else DEFAULT_ANGLE
	var drop := from.y-target.y
	var k := GRAVITY/SEED_FALL
	var low := 0.2
	var high := 30.0
	for i in range(24):
		var mid := (low+high)*0.5
		var t := _fall_time(mid*sin(up),drop,k)
		if mid*cos(up)/k*(1.0-exp(-k*t)) < flat.length(): low = mid
		else: high = mid
	var speed := (low+high)*0.5
	return {"along":along,"up":up,"speed":speed,"time":_fall_time(speed*sin(up),drop,k),"carry":carry}

## A seed's heading: `along` across, `up` radians up.
static func _heading(along: Vector2, up: float) -> Vector3:
	return Vector3(along.x*cos(up),sin(up),along.y*cos(up))

## Seconds until a mote thrown up at `rise` m/s, dragged at `k` per second,
## comes down `drop` m below where it left. Up to its peak it only rises;
## after, it falls ever faster to its terminal speed, so the time is found by
## halving on the way down.
static func _fall_time(rise: float, drop: float, k: float) -> float:
	var reach := (rise+GRAVITY/k)/k
	var sink := GRAVITY/k
	var peak := log(1.0+k*maxf(rise,0.0)/GRAVITY)/k
	if reach*(1.0-exp(-k*peak))-sink*peak < -drop: return peak
	var low := peak
	var high := peak+1.0
	while reach*(1.0-exp(-k*high))-sink*high > -drop and high < 60.0: high *= 2.0
	for i in range(30):
		var mid := (low+high)*0.5
		if reach*(1.0-exp(-k*mid))-sink*mid > -drop: low = mid
		else: high = mid
	return (low+high)*0.5

## Where a seed thrown from `from` at `velocity` comes down on flat ground at
## `floor` in air moving at `air` (plate x, z m/s).
static func _landing(from: Vector3, velocity: Vector3, floor: float, air: Vector2) -> Vector2:
	var k := GRAVITY/SEED_FALL
	var t := _fall_time(velocity.y,from.y-floor,k)
	return Vector2(from.x,from.z)+air*t+(Vector2(velocity.x,velocity.z)-air)/k*(1.0-exp(-k*t))

## A throw's promise: a capsule from where its seeds land in still air to
## where the wind as it blows now takes them, as wide as the farthest its
## scatter throws a seed from the middle (the scatter's corners, thrown), and
## PROMISE_MARGIN for the skip and the lie of the land.
func _promise(from: Vector3, shot: Dictionary, sowing: Dictionary) -> Dictionary:
	var target: Vector3 = sowing.target
	var along: Vector2 = shot.along
	var up: float = shot.up
	var speed: float = shot.speed
	var carry: Vector3 = shot.carry
	var still := _landing(from,_heading(along,up)*speed+carry,target.y,Vector2.ZERO)
	var spread := SPREAD*float(sowing.scale)
	var reach := 0.0
	for across: float in [-1.0,1.0]:
		for rise: float in [-0.5,0.5]:
			for quick: float in [-1.0,1.0]:
				var v := _heading(along.rotated(across*spread),up+rise*spread)*speed*(1.0+quick*SPEED_JITTER)+carry
				reach = maxf(reach,_landing(from,v,target.y,Vector2.ZERO).distance_to(still))
	var wind := Wind.at(scene,get_parent() as Node3D,still)
	var blown := _landing(from,_heading(along,up)*speed+carry,target.y,wind)
	return {"a":still,"b":blown,"radius":PROMISE_MARGIN+reach,"wind":wind}

# --- Flight -------------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var began := Time.get_ticks_usec()
	age += delta
	if not held.is_empty(): _step_held(delta)
	for sowing: Dictionary in _sowings():
		_pin(sowing)
		_fly(sowing,delta)
	for cloud: Dictionary in clouds.duplicate():
		if not cloud.handful.is_empty():
			cloud.waited = float(cloud.waited)+delta
			if hand_at == null or float(cloud.waited) > RELEASE_WAIT: _throw(cloud,_palm(cloud),Vector3.ZERO)
		if cloud.handful.is_empty() and int(cloud.down) >= cloud.motes.size(): _settle(cloud)
	_step_ground(delta)
	_draw()
	_paint_prints()
	last_usec = Time.get_ticks_usec()-began

## The handful sits in the palm, or where it will be thrown from.
func _pin(sowing: Dictionary) -> void:
	if sowing.handful.is_empty(): return
	var palm := _palm(sowing)
	for mote: Dictionary in sowing.handful: mote.p = palm+Vector3(mote.off)*HANDFUL

## Each mote in the air: gravity, and drag toward the air (the wind, the
## curl for dust), stepped so a light mote's strong drag stays steady. Down
## on the ground a fast seed skips once, then lands.
func _fly(sowing: Dictionary, delta: float) -> void:
	var throws: Array = sowing.throws
	var winds := []
	for promise: Dictionary in throws:
		winds.append(Wind.at(scene,get_parent() as Node3D,promise.b) if int(promise.down) < int(promise.count) else Vector2.ZERO)
	for mote: Dictionary in sowing.motes:
		if mote.landed: continue
		_step_mote(sowing,mote,winds[mote.throw],delta)

func _step_mote(sowing: Dictionary, mote: Dictionary, wind: Vector2, delta: float) -> void:
	var seed: bool = mote.seed
	var k := GRAVITY/(SEED_FALL if seed else DUST_FALL)
	var air := Vector3(wind.x,0.0,wind.y)
	if not seed:
		var phase: float = mote.phase
		air += Vector3(sin(age*1.7+phase),0.2*sin(age*2.3+phase*2.0),cos(age*1.3+phase))*CURL
	var v: Vector3 = mote.v
	v = (v+(Vector3.DOWN*GRAVITY+air*k)*delta)/(1.0+k*delta)
	var p: Vector3 = Vector3(mote.p)+v*delta
	mote.v = v
	mote.p = p
	var ground: float = ground_at.call(Vector2(p.x,p.z))
	if is_nan(ground):
		# Off the land it falls on past the plate's edge and is gone.
		if p.y < float(sowing.target.y)-3.0: _land(sowing,mote,Vector2(p.x,p.z),NAN)
		return
	if p.y > ground: return
	if seed and not mote.skipped and v.length() > SKIP_SPEED:
		mote.skipped = true
		mote.p = Vector3(p.x,ground+0.002,p.z)
		mote.v = Vector3(v.x*SKID,-v.y*BOUNCE,v.z*SKID)
		return
	_land(sowing,mote,Vector2(p.x,p.z),ground)

func _land(sowing: Dictionary, mote: Dictionary, point: Vector2, ground: float) -> void:
	mote.landed = true
	mote.flew = age-float(mote.thrown)
	sowing.down = int(sowing.down)+1
	var promise: Dictionary = sowing.throws[mote.throw]
	promise.down = int(promise.down)+1
	if is_nan(ground):
		sowing.lost = int(sowing.lost)+1
		return
	var to := Vector3(point.x,ground,point.y)
	mote.p = to
	sowing.points.append(point)
	_glints.append({"p":to,"t":0.0,"size":float(mote.size),"colour":sowing.colour})
	if not mote.seed: return
	var a: Vector2 = promise.a
	var b: Vector2 = promise.b
	var ab := b-a
	var on := a+ab*clampf((point-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
	if point.distance_to(on) > float(promise.radius): sowing.outside = int(sowing.outside)+1
	var seeds: PackedVector2Array = sowing.seeds
	for q in seeds:
		if q.distance_squared_to(point) < SEED_GAP*SEED_GAP: return
	seeds.append(point)
	sowing.seeds = seeds
	if takes.call(point):
		_sprouts.append({"p":to,"t":0.0,"yaw":randf()*TAU,"lean":Vector2.RIGHT.rotated(randf()*TAU)})
		if _sprouts.size() > SPROUTS_MAX: _sprouts = _sprouts.slice(_sprouts.size()-SPROUTS_MAX)

## Land what is left of a sowing now, where it was going, and hand it on.
func _settle(sowing: Dictionary) -> void:
	if not sowing.handful.is_empty(): _throw(sowing,_palm(sowing),Vector3.ZERO)
	var winds := []
	for promise: Dictionary in sowing.throws: winds.append(Vector2(promise.wind))
	for mote: Dictionary in sowing.motes:
		var steps := 0
		while not mote.landed and steps < 1200:
			_step_mote(sowing,mote,winds[mote.throw],1.0/30.0)
			steps += 1
		if not mote.landed: _land(sowing,mote,Vector2(mote.p.x,mote.p.z),NAN)
	clouds.erase(sowing)
	var path := PackedVector2Array()
	var radius := 0.0
	for promise: Dictionary in sowing.throws:
		path.append(Vector2(promise.b))
		radius = maxf(radius,float(promise.radius))
	settled.emit({"id":sowing.id,"seeds":sowing.seeds,"points":sowing.points,"lost":sowing.lost,"motes":sowing.motes.size(),
		"throws":sowing.throws.size(),"radius":radius,"path":path,"outside":sowing.outside})

func _step_ground(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for glint: Dictionary in _glints:
		glint.t = float(glint.t)+delta
		if float(glint.t) < GLINT: kept.append(glint)
	_glints = kept.slice(maxi(0,kept.size()-MOTES_MAX/2))
	var grown: Array[Dictionary] = []
	for s: Dictionary in _sprouts:
		s.t = float(s.t)+delta
		if float(s.t) < SPROUT_SECONDS: grown.append(s)
	_sprouts = grown

# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var plate: Transform3D = (get_parent() as Node3D).global_transform
	var motes := _mote_node.multimesh
	var n := 0
	for sowing: Dictionary in _sowings():
		var colour: Color = sowing.colour
		for list: Array in [sowing.handful,sowing.motes]:
			for mote: Dictionary in list:
				if mote.landed or n >= MOTES_MAX: continue
				# Seeds tumble as they fly; everything glints; new motes grow in.
				var twinkle := 0.75+0.25*sin(age*5.0+float(mote.phase)*3.0)
				var grow := smoothstep(0.0,0.3,age-float(mote.born))
				var size := 0.045*float(mote.size)*twinkle*maxf(grow,0.01)
				var turn := Basis(Vector3(1,0.4,0.2).normalized(),float(mote.phase)+age*float(mote.spin)) if mote.seed else Basis(Vector3.UP,float(mote.phase)+age)
				motes.set_instance_transform(n,Transform3D(turn.scaled(Vector3.ONE*size),mote.p))
				motes.set_instance_color(n,Color(colour.r,colour.g,colour.b,0.9))
				n += 1
	for glint: Dictionary in _glints:
		if n >= MOTES_MAX: break
		var t: float = glint.t
		var size := 0.04*float(glint.size)*(1.0-t/GLINT)*(0.7+0.3*sin(t*18.0))
		motes.set_instance_transform(n,Transform3D(Basis.from_scale(Vector3.ONE*maxf(size,0.001)),Vector3(glint.p)+Vector3.UP*0.02))
		var colour: Color = glint.colour
		motes.set_instance_color(n,Color(colour.r,colour.g,colour.b,0.9))
		n += 1
	motes.visible_instance_count = n
	_mote_node.global_transform = plate
	_mote_node.visible = n > 0
	var sprouts := _sprout_node.multimesh
	var count := mini(_sprouts.size(),SPROUTS_MAX)
	for i in range(count):
		var s: Dictionary = _sprouts[i]
		var t: float = s.t
		# It pops up past its size, sways back and settles, and sinks away
		# as the forest's own saplings take over.
		var pop := clampf(t/SPROUT_POP,0.0,1.0)-1.0
		var up := (1.0+pop*pop*(2.70158*pop+1.70158))*(1.0-smoothstep(SPROUT_SECONDS-1.2,SPROUT_SECONDS,t))
		var lean: Vector2 = s.lean
		var sway := sin(t*7.0)*0.3*exp(-t*2.2)+sin(age*1.3+float(s.yaw))*0.04
		var basis := Basis(Vector3(lean.x,0,lean.y),sway)*Basis(Vector3.UP,float(s.yaw))
		sprouts.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*SPROUT_SIZE*maxf(up,0.001)),s.p))
		sprouts.set_instance_color(i,Color(1,1,1,0))
	# Shown only once every visible instance has its transform.
	sprouts.visible_instance_count = count
	_sprout_node.global_transform = plate
	_sprout_node.visible = count > 0

## The promise of the next throw at `target` from `from`, re-aimed every
## AIM_EVERY s.
func _next_promise(from: Vector3, target: Vector3, carry: Vector3, scale: float) -> Dictionary:
	if _next.is_empty() or age-_next_age >= AIM_EVERY or age < _next_age:
		var shot := _aim(from,target,Vector3.ZERO,carry)
		_next = _promise(from,shot,{"target":target,"scale":scale})
		_next_age = age
	return _next

## The footprints: the next throw's (at the pointer, or the held handful's)
## and each sowing's throws in the air until their seeds are down.
func _paint_prints() -> void:
	var shapes: Array[Dictionary] = []
	if not held.is_empty():
		var next := _next_promise(_palm(held),held.target,Vector3(held.pointer)*CARRY,float(held.scale))
		shapes.append({"capsules":[[next.a,next.b,next.radius]],"strength":0.6,"soft":1.0})
	elif _hover != null:
		var at: Vector3 = _hover
		var next := _next_promise(at+_toward_camera(at)*STAND_OFF+Vector3.UP*THROW_HEIGHT,at,Vector3.ZERO,_hover_scale)
		shapes.append({"capsules":[[next.a,next.b,next.radius]],"strength":0.45,"soft":1.0})
	for sowing: Dictionary in _sowings():
		var capsules := []
		var left := 0.0
		for promise: Dictionary in sowing.throws:
			var count := int(promise.count)
			if int(promise.down) >= count or int(promise.seeds) == 0: continue
			capsules.append([promise.a,promise.b,promise.radius])
			left = maxf(left,1.0-float(promise.down)/float(count))
		if not capsules.is_empty(): shapes.append({"capsules":capsules,"strength":smoothstep(0.0,0.4,left),"soft":0.0})
	_draw_prints(shapes)

func _draw_prints(shapes: Array[Dictionary]) -> void:
	var parent := get_parent() as Node3D
	var scale := parent.global_basis.get_scale().x
	for i in range(_prints.size()):
		var node := _prints[i]
		if i >= shapes.size() or float(shapes[i].strength) <= 0.001:
			node.visible = false
			continue
		var shape: Dictionary = shapes[i]
		var capsules: Array = shape.capsules
		var low := INF
		var high := -INF
		var box := Rect2()
		var ends := PackedVector4Array()
		var radii := PackedFloat32Array()
		for k in range(capsules.size()):
			var capsule: Array = capsules[k]
			var a: Vector2 = capsule[0]
			var b: Vector2 = capsule[1]
			var r: float = capsule[2]
			var reach := Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*(r+0.6),Vector2(absf(b.x-a.x),absf(b.y-a.y))+Vector2.ONE*(r+0.6)*2.0)
			box = reach if k == 0 else box.merge(reach)
			for q: Vector2 in [a,b]:
				var ground: float = ground_at.call(q)
				if is_nan(ground): continue
				low = minf(low,ground)
				high = maxf(high,ground)
			var wa := parent.to_global(Vector3(a.x,0.0,a.y))
			var wb := parent.to_global(Vector3(b.x,0.0,b.y))
			ends.append(Vector4(wa.x,wa.z,wb.x,wb.z))
			radii.append(r*scale)
		if low == INF:
			node.visible = false
			continue
		var middle := box.get_center()
		var at := parent.to_global(Vector3(middle.x,(low+high)*0.5,middle.y))
		node.global_transform = Transform3D(Basis.from_scale(Vector3(box.size.x*scale,(high-low+8.0)*scale,box.size.y*scale)),at)
		node.visible = true
		var material := node.material_override as ShaderMaterial
		material.set_shader_parameter("ends",ends)
		material.set_shader_parameter("radii",radii)
		material.set_shader_parameter("count",capsules.size())
		material.set_shader_parameter("strength",float(shape.strength))
		material.set_shader_parameter("soft",float(shape.soft))
		material.set_shader_parameter("ceiling",parent.to_global(Vector3(0.0,high+1.0,0.0)).y)
		material.set_shader_parameter("age",age)

func _hide() -> void:
	if _mote_node == null: return
	_mote_node.visible = false
	_sprout_node.visible = false
	for node in _prints: node.visible = false
