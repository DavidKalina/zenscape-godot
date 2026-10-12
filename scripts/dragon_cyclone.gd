extends Node3D
## The dragon's cyclone blast (docs/design/dragon-cyclone/round1.md): his
## answer once he has SPOTTED you (scripts/dragon_sight.gd). No damage
## anywhere: the cyclone is physics, a throw you recover from or don't.
##
##   wind-up  WINDUP s: his head on you, the jaw a little open and drawn back,
##            air drawn into his mouth (the gale's inhale, scripts/
##            dragon_gale.gd `inhale`, driven by scripts/sky_dragon.gd). The
##            warning: get behind cover.
##   shot     a spinning funnel of wind leaves his mouth at SPEED m/s toward
##            where you were as he fired (aimed, not homing) and on along
##            that line. Solid cover (stone, layer 1) in the way breaks it
##            into a harmless puff; turf, or anything within LAND_NEAR of the
##            aim, it lands on. Nothing hit within RANGE, it thins away.
##   on turf  it spins SPIN_LIFE s (then FADE), drifting at DRIFT m/s, and
##            fires the wind tool's ground burst every BURST_EVERY s and its
##            held swirl (zs_burst_*, zs_aim_*: shaders/reference_wind.
##            gdshaderinc zs_blow_at), so grass, trees and water react.
##   contact  in flight or on turf: the pilot on foot or sailing is knocked
##            (PilotMotor `knock`/`knock_velocity`, as the gale's ground gust
##            knocks him) outward and up with a spin, once a funnel; the
##            plane gets it as air (`plane_air`: {wind, shove}, as the gale's
##            `plane_gust` and the downwash's `plane_air`), thrown and rolled
##            hard, lingering THROW_LINGER s after it's out.
##   cadence  COOLDOWN s from a shot to the next wind-up while you stay
##            spotted; losing you stops the wind-up and the shots.
##
## Sized from the dragon (`span`: the model's wingspan times his size, as
## scripts/dragon_downwash.gd); the knock in the walker's heights and the
## plane's catch from its span (scripts/world_scale.gd). The look: soft
## streaks and puffs orbiting the axis (the gale's puff, a tinted streak),
## painterly, no hard mesh. `look` false (headless tests) builds none of it;
## `publish` false leaves the wind tool's shader globals alone.

const WorldScale = preload("res://scripts/world_scale.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const DragonDownwash = preload("res://scripts/dragon_downwash.gd")
const DragonGale = preload("res://scripts/dragon_gale.gd")

# --- Tuning ---------------------------------------------------------------------------

## The tell (s), and the gap from a shot to the next tell (s); FAST_COOLDOWN
## for the greybox's --cyclone-fast.
const WINDUP := 1.3
const COOLDOWN := 6.0
const FAST_COOLDOWN := 2.0
## Seconds into his spotting roar (scripts/sky_dragon.gd ROAR 3.6) the
## first wind-up may start (cutting the roar's close short).
const AFTER_ROAR := 2.5
## The shot: its speed (m/s), the farthest it goes (m), and how near the aim
## (in the walker's heights) a hit on stone still lands (he stands on it).
## He only winds up with you within FIRE_RANGE m of his mouth.
const SPEED := 30.0
const RANGE := 380.0
const FIRE_RANGE := 220.0
const LAND_NEAR := 3.0
## The funnel, as shares of his span (122 m x size: 183 m at 1.5): its
## radius at the base, its height on the turf, and its height in flight
## (a share of that); the top's radius over the base's.
const RADIUS := 0.038
const TALL := 0.14
const FLY_TALL := 0.45
const FLARE := 1.9
## On the turf: how long it spins (s), its fade (s), its drift (m/s) and
## how often the drift turns (s).
const SPIN_LIFE := 4.0
const FADE := 1.2
const DRIFT := 2.5
const DRIFT_TURN := 1.1
## The knock on the pilot (PilotMotor `knock_velocity`): out and up in the
## walker's heights (PhysicsGround.HEAD x WorldScale.wanderer), plus the
## spin along the funnel's turn (m/s).
const KNOCK_OUT := 12.0
const KNOCK_UP := 5.0
const KNOCK_SPIN := 7.0
## The plane in it: the wind (m/s: out, up, round), the shove on the
## airframe (rad/s: nose up, roll) and how long the throw lingers (s).
const PLANE_OUT := 9.0
const PLANE_UP := 16.0
const PLANE_SPIN := 12.0
const PLANE_PITCH := 1.2
const PLANE_ROLL := 7.0
const THROW_LINGER := 0.8
## The wind tool on the turf: the burst's lean, run (s) and travel (radius
## shares) every BURST_EVERY s; the swirl's reach (radius shares) and lean.
const BURST_EVERY := 0.9
const BURST_LEAN := 1.2
const BURST_RUN := 1.1
const BURST_TRAVEL := 3.0
const SWIRL_REACH := 2.5
const SWIRL := 1.0
## The look: streaks and puffs a funnel, their round speed at the rim (m/s)
## and rise (column heights a second); dust puffs kicked off the base a
## second; at most this many funnels at once.
const STREAKS_EACH := 160
const PUFFS_EACH := 36
const ROUND := 24.0
const RISE := 0.35
const DUST_RATE := 9.0
const MOST := 3
const FREE_PUFFS := 160
const DUST_TINT := Color(0.86,0.82,0.70)
const AIR_TINT := Color(0.84,0.88,0.94)
## The rays: stone (layer 1) and turf (layer 11), as his sight's.
const SOLID := 1
const TURF := 1 << 11
const MASK := SOLID | TURF

signal winding_up
signal fired(from: Vector3, aim: Vector3)
signal landed(at: Vector3)
signal broke(at: Vector3)

## Off: no tells, no shots.
var on := true
var look := true
var publish := true
var windup := WINDUP
var cooldown := COOLDOWN
## His span (m), set by the dragon each frame.
var span := DragonDownwash.MODEL_SPAN*1.5
## "idle" or "windup"; seconds into the wind-up; seconds of cooldown left;
## seconds since the last shot (INF none).
var phase := "idle"
var windup_t := 0.0
var cooldown_left := 0.0
var since_shot := INF
## Counts (the sound and the log read them) and where the last landed/broke.
var shots := 0
var lands := 0
var breaks := 0
var last_at := Vector3.INF
## The funnels in the air or on the turf: each {pos, vel, aim, state
## ("fly" | "spin"), age, travelled, drift, turn_t, hit_pilot, burst_t,
## streaks, puffs}.
var funnels: Array = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
## The plane's throw: its air, eased out over THROW_LINGER.
var _throw := {}
var _throw_t := 0.0
var _streaks: MultiMeshInstance3D
var _puffs: MultiMeshInstance3D
var _free: Array = []
var _free_next := 0
var _drawn_s := 0
var _drawn_p := 0
var _burst := Vector4.ZERO
var _burst_travel := 0.0
var _swirl := Vector4.ZERO
var _published := false

func _init() -> void:
	name = "DragonCyclone"
	top_level = true
	_rng.seed = 23

func _ready() -> void:
	if not look: return
	_streaks = _batch("CycloneStreaks",_streak_mesh(),STREAKS_EACH*MOST)
	_puffs = _batch("CyclonePuffs",DragonGale._puff_mesh(),PUFFS_EACH*MOST+FREE_PUFFS)
	for i in range(FREE_PUFFS): _free.append({"life":0.0})

func _exit_tree() -> void:
	if _published:
		_burst = Vector4.ZERO
		_swirl = Vector4.ZERO
		_publish_wind()

# --- Sizes -------------------------------------------------------------------------------

func radius() -> float:
	return RADIUS*span

func tall() -> float:
	return TALL*span

static func walker_tall() -> float:
	return PhysicsGround.HEAD*WorldScale.wanderer

## The funnel's radius `u` of the way up (0 the base, 1 the top).
func radius_at(u: float) -> float:
	return radius()*lerpf(1.0,FLARE,pow(clampf(u,0.0,1.0),1.4))

## How strong a funnel is now (0..1): grown out of the mouth, faded at the end.
func power(f: Dictionary) -> float:
	if str(f.state) == "fly": return smoothstep(0.0,0.35,float(f.age))*(1.0-smoothstep(RANGE*0.85,RANGE,float(f.travelled)))
	return 1.0-smoothstep(SPIN_LIFE,SPIN_LIFE+FADE,float(f.age))

## Its column's height now: short in flight, risen to full on the turf.
func height(f: Dictionary) -> float:
	if str(f.state) == "fly": return tall()*FLY_TALL
	return tall()*lerpf(FLY_TALL,1.0,smoothstep(0.0,0.6,float(f.age)))

# --- The brain ---------------------------------------------------------------------------

## A frame: `spotted` (he sees you and isn't roaring), his `mouth` and the
## pilot's middle `aim` (INF none). Winds up, fires, flies the funnels.
func advance(delta: float, space: PhysicsDirectSpaceState3D, spotted: bool, mouth: Vector3, aim: Vector3) -> void:
	if delta <= 0.0: return
	_clock += delta
	cooldown_left = maxf(0.0,cooldown_left-delta)
	since_shot += delta
	var can := on and spotted and aim != Vector3.INF and mouth.distance_to(aim) <= FIRE_RANGE
	if phase == "windup":
		if not can: phase = "idle"
		else:
			windup_t += delta
			if windup_t >= windup:
				phase = "idle"
				fire(mouth,aim)
	elif can and cooldown_left <= 0.0:
		phase = "windup"
		windup_t = 0.0
		winding_up.emit()
	_step_funnels(delta,space)
	_throw_t = maxf(0.0,_throw_t-delta)
	if _burst.w > 0.0:
		_burst.z += delta
		if _burst.z > BURST_RUN+2.0: _burst = Vector4.ZERO
	if look and is_inside_tree():
		_step_free(delta)
		_draw(delta)
	if publish: _publish_wind()

## The wind-up's share done (0..1), or -1 not winding up.
func windup_share() -> float:
	return clampf(windup_t/maxf(windup,0.01),0.0,1.0) if phase == "windup" else -1.0

## A funnel from `from` toward `aim`, on along that line.
func fire(from: Vector3, aim: Vector3) -> void:
	var way := (aim-from).normalized() if aim.distance_to(from) > 0.01 else Vector3.DOWN
	var f := {"pos":from,"vel":way*SPEED,"aim":aim,"state":"fly","age":0.0,"travelled":0.0,
		"drift":Vector2(way.x,way.z).normalized()*DRIFT if Vector2(way.x,way.z).length() > 0.01 else Vector2.ZERO,
		"turn_t":DRIFT_TURN,"hit_pilot":false,"burst_t":0.0,"streaks":[],"puffs":[]}
	for i in range(STREAKS_EACH):
		f.streaks.append({"u":_rng.randf(),"a":_rng.randf()*TAU,"rj":_rng.randf_range(0.7,1.15),"w":_rng.randf_range(0.8,1.25),
			"len":_rng.randf_range(0.6,1.1),"wid":_rng.randf_range(0.7,1.2)})
	for i in range(PUFFS_EACH):
		f.puffs.append({"u":pow(_rng.randf(),1.7),"a":_rng.randf()*TAU,"rj":_rng.randf_range(0.6,1.05),"w":_rng.randf_range(0.7,1.2),
			"size":_rng.randf_range(0.5,0.95)})
	funnels.append(f)
	while funnels.size() > MOST: funnels.pop_front()
	cooldown_left = cooldown
	since_shot = 0.0
	shots += 1
	print("dragon cyclone: fired from (%.0f, %.0f, %.0f) at (%.1f, %.1f, %.1f)" % [from.x,from.y,from.z,aim.x,aim.y,aim.z])
	fired.emit(from,aim)

func _step_funnels(delta: float, space: PhysicsDirectSpaceState3D) -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = MASK
	for f: Dictionary in funnels.duplicate():
		f.age = float(f.age)+delta
		if str(f.state) == "fly": _fly(f,delta,space,ray)
		else: _spin(f,delta,space,ray)
		if power(f) <= 0.0 and (str(f.state) == "spin" or float(f.travelled) >= RANGE): funnels.erase(f)

## In flight: on along its line; the first thing hit lands it (turf, or
## near the aim) or breaks it (stone in the way).
func _fly(f: Dictionary, delta: float, space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> void:
	var from: Vector3 = f.pos
	var to := from+(f.vel as Vector3)*delta
	if space != null:
		ray.from = from
		ray.to = to
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var at: Vector3 = hit.position
			var layer := 0
			var body: Object = hit.get("collider")
			if body is CollisionObject3D: layer = (body as CollisionObject3D).collision_layer
			var near := at.distance_to(f.aim as Vector3) <= LAND_NEAR*walker_tall()
			var floorish := (hit.normal as Vector3).y > 0.6
			if floorish and ((layer & TURF) != 0 or near): _land(f,at)
			else: _break(f,at,hit.normal)
			return
	f.pos = to
	f.travelled = float(f.travelled)+from.distance_to(to)
	if float(f.travelled) >= RANGE: _puff_out(f.pos,AIR_TINT,10,0.6)

func _land(f: Dictionary, at: Vector3) -> void:
	f.state = "spin"
	f.pos = at
	f.age = 0.0
	f.burst_t = 0.0
	lands += 1
	last_at = at
	_fire_burst(at,1.0)
	print("dragon cyclone: landed at (%.1f, %.1f, %.1f), %.1f m from its aim" % [at.x,at.y,at.z,at.distance_to(f.aim as Vector3)])
	for i in range(18):
		var a := _rng.randf()*TAU
		var out := Vector3(cos(a),0.0,sin(a))
		var size := _rng.randf_range(0.5,0.9)*radius()
		_free_puff(at+out*radius()*0.6+Vector3.UP*size*0.8,out*_rng.randf_range(8.0,16.0)+Vector3.UP*_rng.randf_range(1.0,4.0),size,size*1.6,_rng.randf_range(1.4,2.4),DUST_TINT,0.4)
	landed.emit(at)

## Broken on cover: gone at once, a soft burst of air off what it hit.
func _break(f: Dictionary, at: Vector3, normal: Vector3) -> void:
	funnels.erase(f)
	breaks += 1
	last_at = at
	print("dragon cyclone: broke on cover at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	var back := (-(f.vel as Vector3)).normalized()
	for i in range(22):
		var d := (normal*0.6+back*0.4+Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.6,1),_rng.randf_range(-1,1))*0.7).normalized()
		var size := _rng.randf_range(0.35,0.7)*radius()
		_free_puff(at+normal*1.0,d*_rng.randf_range(6.0,14.0),size,size*2.2,_rng.randf_range(0.9,1.6),AIR_TINT if i%3 else DUST_TINT,0.65)
	broke.emit(at)

## On the turf: spins, drifts (turning now and then, held off walls, gone
## over a rim), bursts the grass.
func _spin(f: Dictionary, delta: float, space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> void:
	f.turn_t = float(f.turn_t)-delta
	if float(f.turn_t) <= 0.0:
		f.turn_t = DRIFT_TURN
		f.drift = (f.drift as Vector2).rotated(_rng.randf_range(-1.2,1.2))
		if (f.drift as Vector2).length() < 0.1: f.drift = Vector2.RIGHT.rotated(_rng.randf()*TAU)*DRIFT
	var d: Vector2 = f.drift
	var at: Vector3 = f.pos
	var next := at+Vector3(d.x,0.0,d.y)*delta
	if space != null:
		var lift := Vector3.UP*walker_tall()
		ray.from = at+lift
		ray.to = next+lift+Vector3(d.x,0.0,d.y).normalized()*0.5
		if not space.intersect_ray(ray).is_empty():
			f.drift = -d
			next = at
		ray.from = next+Vector3.UP*4.0
		ray.to = next+Vector3.DOWN*8.0
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			# Over the rim: it spills off and thins out.
			f.age = maxf(float(f.age),SPIN_LIFE)
			next.y -= 6.0*delta
		else: next.y = (hit.position as Vector3).y
	f.pos = next
	var p := power(f)
	f.burst_t = float(f.burst_t)+delta
	if float(f.burst_t) >= BURST_EVERY and p > 0.2:
		f.burst_t = 0.0
		_fire_burst(next,p)

# --- Contact ------------------------------------------------------------------------------

## How far inside funnel `f` the point `p` is (0 out, 1 on its axis), `extra`
## m added to its radius (the catcher's own size).
func inside(f: Dictionary, p: Vector3, extra := 0.0) -> float:
	var rel := p-(f.pos as Vector3)
	var h := height(f)
	if rel.y < -walker_tall()*1.5 or rel.y > h: return 0.0
	var r := radius_at(rel.y/h)+extra
	var d := Vector2(rel.x,rel.z).length()
	return 1.0-smoothstep(r*0.6,r,d)

## The pilot's knock (m/s: hand to PilotMotor `knock`), ZERO for none: the
## first funnel strong enough with his chest inside it throws him out and up
## with its turn, once a funnel. `motor` gives `knock_velocity`; one
## recovering from a knock isn't thrown again.
func pilot_knock(feet: Vector3, motor: Object) -> Vector3:
	if motor.has_method("recovering") and motor.recovering(): return Vector3.ZERO
	var t := walker_tall()
	var chest := feet+Vector3.UP*0.55*t
	for f: Dictionary in funnels:
		if bool(f.hit_pilot) or power(f) < 0.3: continue
		if inside(f,chest,PhysicsGround.RADIUS*WorldScale.wanderer) <= 0.0: continue
		f.hit_pilot = true
		var away := _away(f,chest)
		var v: Vector3 = motor.knock_velocity(away,KNOCK_OUT*t,KNOCK_UP*t)
		var turn_way := Vector2(-away.y,away.x)*KNOCK_SPIN
		print("dragon cyclone: knocks the pilot, out (%.1f, %.1f) up %.1f m/s" % [v.x+turn_way.x,v.z+turn_way.y,v.y])
		return v+Vector3(turn_way.x,0.0,turn_way.y)
	return Vector3.ZERO

## Flat way out from the funnel's axis to `p` (its travel's way, turned, on
## the axis itself).
func _away(f: Dictionary, p: Vector3) -> Vector2:
	var rel := Vector2(p.x-(f.pos as Vector3).x,p.z-(f.pos as Vector3).z)
	if rel.length() > 0.2: return rel.normalized()
	var v := Vector2((f.vel as Vector3).x,(f.vel as Vector3).z)
	return v.normalized().orthogonal() if v.length() > 0.01 else Vector2.RIGHT

## The funnels as air for the plane at `p` (`nose` its forward): {wind,
## shove, gust, thermal}, as the gale's `plane_gust`: out, up and round,
## the nose tossed up and the wings rolled hard; lingering THROW_LINGER s
## once out. Empty with none.
func plane_air(p: Vector3, nose: Vector3) -> Dictionary:
	var best := 0.0
	var air := {}
	for f: Dictionary in funnels:
		var w := inside(f,p,WorldScale.span*0.5)*power(f)
		if w <= best: continue
		best = w
		var away := _away(f,p)
		var turn_way := Vector2(-away.y,away.x)
		var wind := Vector3(away.x,0.0,away.y)*PLANE_OUT*w+Vector3.UP*PLANE_UP*w+Vector3(turn_way.x,0.0,turn_way.y)*PLANE_SPIN*w
		# Rolled with the funnel's turn: its round way across the wings.
		var right := Vector2(-nose.z,nose.x).normalized() if Vector2(nose.x,nose.z).length() > 0.01 else Vector2.RIGHT
		var tip := signf(turn_way.dot(right)) if absf(turn_way.dot(right)) > 0.1 else 1.0
		var n := sin(_clock*11.0+p.x*0.1)
		air = {"wind":wind,"shove":Vector3(PLANE_PITCH*w*(0.6+0.4*n),0.4*n*w,PLANE_ROLL*w*tip),"gust":w,"thermal":0.0}
	if best > 0.0:
		_throw = air
		_throw_t = THROW_LINGER
		return air
	if _throw_t > 0.0 and not _throw.is_empty():
		var k := _throw_t/THROW_LINGER
		return {"wind":(_throw.wind as Vector3)*k,"shove":(_throw.shove as Vector3)*k,"gust":float(_throw.gust)*k,"thermal":0.0}
	return {}

# --- The wind tool on the turf -----------------------------------------------------------

func _fire_burst(at: Vector3, strength: float) -> void:
	_burst = Vector4(at.x,at.z,0.0,BURST_LEAN*strength)
	_burst_travel = BURST_TRAVEL*radius()

## The burst (zs_burst_*, aged here) and the swirl round the strongest funnel
## on the turf (zs_aim_* held: out and round, trembling), cleared once when
## both are done.
func _publish_wind() -> void:
	_swirl = Vector4.ZERO
	var spun := 0.0
	for f: Dictionary in funnels:
		if str(f.state) != "spin": continue
		var p := power(f)
		if p > spun:
			spun = p
			_swirl = Vector4((f.pos as Vector3).x,(f.pos as Vector3).z,SWIRL_REACH*radius(),SWIRL*p)
	if _burst.w <= 0.0 and _swirl.w <= 0.0 and not _published: return
	_published = _burst.w > 0.0 or _swirl.w > 0.0
	RenderingServer.global_shader_parameter_set("zs_burst_a",_burst)
	RenderingServer.global_shader_parameter_set("zs_burst_b",Vector4(BURST_RUN,0.0,_burst_travel,_burst_travel) if _burst.w > 0.0 else Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("zs_aim_a",Vector4(_swirl.x,_swirl.y,0.0,0.0))
	RenderingServer.global_shader_parameter_set("zs_aim_b",Vector4(_swirl.z,_swirl.w,0.0,1.0) if _swirl.w > 0.0 else Vector4.ZERO)

# --- The look ---------------------------------------------------------------------------

func _batch(label: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 2000.0
	add_child(node)
	return node

## A soft streak along x, its tint per instance, faded by custom.r: the
## gale's streak, coloured.
static func _streak_mesh() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;
varying float fade;
varying vec3 tint;
void vertex() { fade = INSTANCE_CUSTOM.r; tint = COLOR.rgb; }
void fragment() {
	float along = sin(UV.x * 3.14159);
	float head = mix(0.5, 1.0, UV.x);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = tint;
	ALPHA = clamp(fade * along * head * across * 0.95, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	quad.material = m
	return quad

func _free_puff(p: Vector3, v: Vector3, size: float, grow: float, life: float, tint: Color, alpha := 1.0) -> void:
	if _free.is_empty(): return
	_free[_free_next] = {"p":p,"v":v,"size":size,"grow":grow,"life":life,"age":0.0,"alpha":alpha,"tint":tint}
	_free_next = (_free_next+1)%FREE_PUFFS

func _puff_out(at: Vector3, tint: Color, count: int, alpha: float) -> void:
	for i in range(count):
		var d := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.5,1),_rng.randf_range(-1,1)).normalized()
		var size := _rng.randf_range(0.4,0.8)*radius()
		_free_puff(at,d*_rng.randf_range(4.0,9.0),size,size*2.0,_rng.randf_range(1.0,1.8),tint,alpha)

func _step_free(delta: float) -> void:
	for s: Dictionary in _free:
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			continue
		s.v = (s.v as Vector3)*(1.0-0.9*delta)
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta
	# Dust off the base of each funnel on the turf.
	for f: Dictionary in funnels:
		if str(f.state) != "spin": continue
		if _rng.randf() < delta*DUST_RATE*power(f):
			var a := _rng.randf()*TAU
			var out := Vector3(cos(a),0.0,sin(a))
			var turn_way := Vector3(-out.z,0.0,out.x)
			var size := _rng.randf_range(0.4,0.75)*radius()
			_free_puff((f.pos as Vector3)+out*radius()*0.9+Vector3.UP*size*0.8,out*_rng.randf_range(3.0,7.0)+turn_way*_rng.randf_range(5.0,9.0)+Vector3.UP*_rng.randf_range(1.0,3.0),size,size*1.6,_rng.randf_range(1.2,2.0),DUST_TINT,0.35)

## The funnels drawn: streaks round the axis rising and turning, faster near
## the base; puffs of dust low and air higher; the axis swaying.
func _draw(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	var sm := _streaks.multimesh
	var pm := _puffs.multimesh
	var si := 0
	var pj := 0
	for f: Dictionary in funnels:
		var p := power(f)
		var h := height(f)
		var base: Vector3 = f.pos
		var flying := str(f.state) == "fly"
		for s: Dictionary in f.streaks:
			var u := float(s.u)
			var r := radius_at(u)*float(s.rj)
			s.a = float(s.a)+ROUND/maxf(r,0.5)*float(s.w)*delta
			s.u = fposmod(u+RISE*float(s.w)*delta,1.0)
			var a := float(s.a)
			var mid := base+_sway(u,h)+Vector3(cos(a)*r,u*h,sin(a)*r)
			var along := Vector3(-sin(a),0.18,cos(a)).normalized()
			if flying: along = (along+(f.vel as Vector3).normalized()*0.3).normalized()
			var across := along.cross((eye-mid).normalized())
			if across.length() < 0.01: across = Vector3.UP
			across = across.normalized()
			var normal := along.cross(across).normalized()
			var fade := smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.82,1.0,u))*p
			# The far side of the funnel shaded down, so it reads round.
			var to_eye := Vector2(eye.x-base.x,eye.z-base.z).normalized()
			var lit := lerpf(0.62,1.0,0.5+0.5*Vector2(cos(a),sin(a)).dot(to_eye))
			sm.set_instance_transform(si,Transform3D(Basis(along*r*1.0*float(s.len),across*maxf(0.5,0.16*r)*float(s.wid),normal),mid))
			sm.set_instance_custom_data(si,Color(fade*0.75,0,0,0))
			sm.set_instance_color(si,DUST_TINT.lerp(AIR_TINT,smoothstep(0.0,0.45,u))*Color(lit,lit,lit))
			si += 1
		for s: Dictionary in f.puffs:
			var u := float(s.u)
			var r := radius_at(u)*float(s.rj)*0.8
			s.a = float(s.a)+ROUND*0.7/maxf(r,0.5)*float(s.w)*delta
			s.u = fposmod(u+RISE*0.6*float(s.w)*delta,1.0)
			var a := float(s.a)
			var size := float(s.size)*radius_at(u)*0.7
			var mid := base+_sway(u,h)+Vector3(cos(a)*r,maxf(u*h,size*0.5),sin(a)*r)
			var fade := smoothstep(0.0,0.1,u)*(1.0-smoothstep(0.7,1.0,u))*p*0.3
			pm.set_instance_transform(pj,Transform3D(Basis.from_scale(Vector3.ONE*size),mid))
			pm.set_instance_custom_data(pj,Color(fade,0,0,0))
			pm.set_instance_color(pj,DUST_TINT.lerp(AIR_TINT,smoothstep(0.0,0.35,u)) if not flying else AIR_TINT)
			pj += 1
	for s: Dictionary in _free:
		if float(s.life) <= 0.0: continue
		var u := float(s.age)/float(s.life)
		var size := lerpf(float(s.size),float(s.grow),1.0-pow(1.0-u,2.0))
		var fade := smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.4,1.0,u))*float(s.alpha)
		pm.set_instance_transform(pj,Transform3D(Basis.from_scale(Vector3.ONE*size),s.p))
		pm.set_instance_custom_data(pj,Color(fade,0,0,0))
		pm.set_instance_color(pj,s.tint)
		pj += 1
	sm.visible_instance_count = si
	pm.visible_instance_count = pj

## The axis's sway `u` of the way up a column `h` tall: more the higher.
func _sway(u: float, h: float) -> Vector3:
	var k := u*u*h*0.06
	return Vector3(sin(_clock*1.3+u*3.0)*k,0.0,cos(_clock*1.1+u*2.5)*k)
