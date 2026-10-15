extends Node3D
## The dragon's air blast (docs/design/dragon-air-blast/round1.md): his
## swift answer once he has SPOTTED you (scripts/dragon_sight.gd), in place
## of the slow cyclone (scripts/dragon_cyclone.gd). No damage anywhere: the
## blast is physics, a throw off the isle or out of the sky.
##
##   wind-up  WINDUP s, short and sharp: his head snaps onto you, the jaw
##            draws air (the gale's inhale, scripts/dragon_gale.gd `inhale`,
##            driven by scripts/sky_dragon.gd). The warning: juke or duck.
##   shot     a tight ball of compressed air, about the pilot's size, leaves
##            his mouth at SPEED m/s toward where you will be: your velocity
##            led LEAD of the way to the meeting (not homing), and on along
##            that line. Run straight and it meets you; turn or break his
##            line and it misses.
##   impact   it bursts on the turf or floor it hits, or on the pilot or the
##            plane it passes within reach of: a shock SHOCK_R walker heights
##            round knocks the pilot out and up from the burst (PilotMotor
##            `knock_velocity`: off the isle) and throws the plane (`plane_air`:
##            {wind, shove}, a tumble), once a burst, hidden by stone between.
##            The wind tool's burst (zs_burst_*) flattens grass, trees and
##            water in a ring. Stone cover (layer 1) it meets side on pops it
##            harmlessly.
##   cadence  COOLDOWN s from a shot to the next wind-up while you stay
##            spotted; losing you stops the wind-up and the shots.
##
## Sized from the dragon's span where it is his (the trail), from the
## walker's height where it meets the walker (the ball, the shock, the
## knock: scripts/world_scale.gd), and the plane's span for its reach.
## The look: a heat-shimmer ball (the screen bent through a soft lens, a
## pale rim), a short streak trail and puffs, painterly, no hard mesh.
## `look` false (headless tests) builds none of it; `publish` false leaves
## the wind tool's shader globals alone.

const WorldScale = preload("res://scripts/world_scale.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const DragonDownwash = preload("res://scripts/dragon_downwash.gd")
const DragonGale = preload("res://scripts/dragon_gale.gd")
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")

# --- Tuning ---------------------------------------------------------------------------

## The tell (s), and the gap from a shot to the next tell (s): a shot every
## WINDUP+COOLDOWN s while he sees you. FAST_COOLDOWN for --blast-fast.
const WINDUP := 0.45
const COOLDOWN := 2.3
const FAST_COOLDOWN := 1.0
## Seconds into his spotting roar (scripts/sky_dragon.gd ROAR 3.6) the first
## wind-up may start: as the jaw opens, the roar cut short.
const AFTER_ROAR := 0.8
## The shot: its speed (m/s), the farthest it goes (m); he only winds up
## with you within FIRE_RANGE m of his mouth.
const SPEED := 110.0
const RANGE := 460.0
const FIRE_RANGE := 330.0
## The lead: the share of the way your velocity is led to the meeting, and
## how fast he reads your velocity (an ease a second) and the most he leads.
const LEAD := 1.0
const LEAD_EASE := 14.0
const LEAD_MOST := 60.0
## The ball's radius and the shock's, in the walker's heights; the pilot's
## reach for it (it bursts on him passing within the ball plus his radius).
const BALL := 0.55
const SHOCK_R := 3.2
## The fuse: a ball passing within FUSE walker heights of the pilot (more
## than his body) bursts on him, so a near miss still lands.
const FUSE := 1.2
## Out of the mouth: for its first CARRY s a ball rides along with his
## mouth (he flies 22-54 m/s; left alone it hangs off to his side), and in
## the wind-up it swells in his jaw to GATHER of its size.
const CARRY := 0.15
const GATHER := 0.8
## The knock on the pilot (PilotMotor `knock_velocity`): out and up in the
## walker's heights at the burst's heart, EDGE of it at the shock's rim.
## Out 42 heights flies him some 40 m (the tumble skids less than the
## model asks): off any greybox isle from its middle.
const KNOCK_OUT := 42.0
const KNOCK_UP := 3.5
## A hard hit (PilotMotor `knock`'s `down`): stunned the whole throw, then
## laid down, dizzy, this long (s) where he lands.
const STUN_DOWN := 1.2
const EDGE := 0.45
## The plane: the ball bursts within its half span plus the ball; the shock
## reaches PLANE_SHOCK of its spans. The wind (m/s: out along the shot and
## down: the plane's wind adds to its travel, so up would only lift it), the
## shove (rad/s: nose down, yaw, roll) and how long the throw lingers.
const PLANE_SHOCK := 2.5
const PLANE_OUT := 34.0
const PLANE_DOWN := 26.0
const PLANE_PITCH := 2.4
const PLANE_YAW := 1.2
const PLANE_ROLL := 11.0
const THROW_LINGER := 1.1
## How long a burst can still catch the pilot or the plane (s).
const SHOCK_LIVE := 0.12
## The wind tool: the burst's lean, run (s) and travel (shock radii).
const BURST_LEAN := 2.2
const BURST_RUN := 0.9
const BURST_TRAVEL := 4.0
## The look: the trail's streaks and puffs a ball, the free puffs, at most
## this many balls at once.
const TRAIL_STREAKS := 14
const TRAIL_PUFFS := 10
const FREE_PUFFS := 140
const MOST := 3
const DUST_TINT := Color(0.86,0.82,0.70)
const AIR_TINT := Color(0.88,0.92,0.98)
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
## His span (m), set by the dragon each frame (the trail's length).
var span := DragonDownwash.MODEL_SPAN*1.5
## "idle" or "windup"; seconds into the wind-up; seconds of cooldown left;
## seconds since the last shot (INF none).
var phase := "idle"
var windup_t := 0.0
var cooldown_left := 0.0
var since_shot := INF
## Counts (the sound and the log read them: `lands` are bursts, `breaks`
## pops on cover) and where the last burst or pop was.
var shots := 0
var lands := 0
var breaks := 0
var knocks := 0
var last_at := Vector3.INF
## The pilot's middle as last seen and its velocity, eased (m/s).
var aim_vel := Vector3.ZERO
var _last_aim := Vector3.INF
## His mouth this frame and its move since the last (a jump of more than
## 20 m starts it over).
var _mouth := Vector3.INF
var _mouth_step := Vector3.ZERO
## The balls in flight: each {pos, was, vel, aim, age, travelled}.
var balls: Array = []
## The bursts still catching: each {at, way, age, hit_pilot, hit_plane}.
var shocks: Array = []
var _space: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _throw := {}
var _throw_t := 0.0
var _lens: MultiMeshInstance3D
var _streaks: MultiMeshInstance3D
var _puffs: MultiMeshInstance3D
var _free: Array = []
var _free_next := 0
var _burst := Vector4.ZERO
var _burst_travel := 0.0
var _published := false

func _init() -> void:
	name = "DragonAirBlast"
	top_level = true
	_rng.seed = 31

func _ready() -> void:
	if not look: return
	_lens = _batch("BlastLens",_lens_mesh(),MOST+1)
	_streaks = _batch("BlastStreaks",DragonCyclone._streak_mesh(),TRAIL_STREAKS*MOST)
	_puffs = _batch("BlastPuffs",DragonGale._puff_mesh(),TRAIL_PUFFS*MOST+FREE_PUFFS)
	for i in range(FREE_PUFFS): _free.append({"life":0.0})

func _exit_tree() -> void:
	if _published:
		_burst = Vector4.ZERO
		_publish_wind()

# --- Sizes -------------------------------------------------------------------------------

static func walker_tall() -> float:
	return PhysicsGround.HEAD*WorldScale.wanderer

static func ball_radius() -> float:
	return BALL*walker_tall()

static func shock_radius() -> float:
	return SHOCK_R*walker_tall()

# --- The brain ---------------------------------------------------------------------------

## A frame: `spotted` (he sees you and his roar is far enough on), his
## `mouth` and the pilot's middle `aim` (INF none). Reads your velocity,
## winds up, fires, flies the balls.
func advance(delta: float, space: PhysicsDirectSpaceState3D, spotted: bool, mouth: Vector3, aim: Vector3) -> void:
	if delta <= 0.0: return
	_clock += delta
	_space = space
	cooldown_left = maxf(0.0,cooldown_left-delta)
	since_shot += delta
	_read_velocity(delta,aim)
	_mouth_step = mouth-_mouth if _mouth != Vector3.INF and mouth.distance_to(_mouth) < 20.0 else Vector3.ZERO
	_mouth = mouth
	var can := on and spotted and aim != Vector3.INF and mouth.distance_to(aim) <= FIRE_RANGE
	if phase == "windup":
		if not can: phase = "idle"
		else:
			windup_t += delta
			if windup_t >= windup:
				phase = "idle"
				fire(mouth,lead(mouth,aim,aim_vel))
	elif can and cooldown_left <= 0.0:
		phase = "windup"
		windup_t = 0.0
		winding_up.emit()
	_step_balls(delta,space)
	for s: Dictionary in shocks.duplicate():
		s.age = float(s.age)+delta
		if float(s.age) > SHOCK_LIVE: shocks.erase(s)
	_throw_t = maxf(0.0,_throw_t-delta)
	if _burst.w > 0.0:
		_burst.z += delta
		if _burst.z > BURST_RUN+2.0: _burst = Vector4.ZERO
	if look and is_inside_tree():
		_step_free(delta)
		_draw()
	if publish: _publish_wind()

## The wind-up's share done (0..1), or -1 not winding up.
func windup_share() -> float:
	return clampf(windup_t/maxf(windup,0.01),0.0,1.0) if phase == "windup" else -1.0

## The pilot's velocity, eased from the aim's moves (a jump of more than
## 20 m in a frame, a respawn or a boarding, starts it over).
func _read_velocity(delta: float, aim: Vector3) -> void:
	if aim == Vector3.INF:
		_last_aim = Vector3.INF
		return
	if _last_aim != Vector3.INF and aim.distance_to(_last_aim) < 20.0:
		var now := (aim-_last_aim)/delta
		aim_vel = aim_vel.lerp(now,clampf(LEAD_EASE*delta,0.0,1.0))
	else: aim_vel = Vector3.ZERO
	_last_aim = aim

## Where to shoot from `from` at a pilot at `aim` moving `vel` (m/s): where
## he will be when a ball at SPEED gets there, LEAD of his travel led.
static func lead(from: Vector3, aim: Vector3, vel: Vector3) -> Vector3:
	var v := vel.limit_length(LEAD_MOST)
	var t := from.distance_to(aim)/SPEED
	for i in range(3): t = from.distance_to(aim+v*t*LEAD)/SPEED
	return aim+v*t*LEAD

## A ball from `from` toward `aim`, on along that line.
func fire(from: Vector3, aim: Vector3) -> void:
	var way := (aim-from).normalized() if aim.distance_to(from) > 0.01 else Vector3.DOWN
	balls.append({"pos":from,"was":from,"vel":way*SPEED,"aim":aim,"age":0.0,"travelled":0.0,"trail":[],"fresh":true})
	while balls.size() > MOST: balls.pop_front()
	cooldown_left = cooldown
	since_shot = 0.0
	shots += 1
	print("dragon air blast: fired from (%.0f, %.0f, %.0f) at (%.1f, %.1f, %.1f), leading (%.1f, %.1f, %.1f) m/s" % [from.x,from.y,from.z,aim.x,aim.y,aim.z,aim_vel.x,aim_vel.y,aim_vel.z])
	if look and is_inside_tree():
		for i in range(8):
			var d := (way+Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1))*0.5).normalized()
			var size := _rng.randf_range(0.8,1.4)*ball_radius()
			_free_puff(from,d*_rng.randf_range(10.0,22.0),size,size*2.5,_rng.randf_range(0.4,0.7),AIR_TINT,0.35)
	fired.emit(from,aim)

func _step_balls(delta: float, space: PhysicsDirectSpaceState3D) -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = MASK
	for b: Dictionary in balls.duplicate():
		b.age = float(b.age)+delta
		var from: Vector3 = b.pos
		var to := from+(b.vel as Vector3)*delta
		# (Not on the frame it's fired: it left from this frame's mouth.)
		if b.get("fresh",false): b.fresh = false
		elif float(b.age) <= CARRY+delta:
			to += _mouth_step*clampf((CARRY-(float(b.age)-delta))/delta,0.0,1.0)
			# Out of his mouth's carry: set back on its aim.
			if float(b.age) > CARRY and (b.aim as Vector3).distance_to(to) > 1.0:
				b.vel = ((b.aim as Vector3)-to).normalized()*SPEED
		b.was = from
		if space != null:
			ray.from = from
			ray.to = to+(b.vel as Vector3).normalized()*ball_radius()
			var hit := space.intersect_ray(ray)
			if not hit.is_empty():
				var at: Vector3 = hit.position
				var layer := 0
				var body: Object = hit.get("collider")
				if body is CollisionObject3D: layer = (body as CollisionObject3D).collision_layer
				var floorish := (hit.normal as Vector3).y > 0.6
				if (layer & SOLID) != 0 and not floorish: _pop(b,at,hit.normal)
				else: burst(b,at+(hit.normal as Vector3)*ball_radius()*0.5)
				continue
		b.pos = to
		b.travelled = float(b.travelled)+from.distance_to(to)
		if float(b.travelled) >= RANGE:
			balls.erase(b)
			_puff_out(to,AIR_TINT,8,0.4)

## The ball bursts at `at`: a shock that knocks the pilot and the plane in
## reach (on their next ask), the grass flattened in a ring.
func burst(b: Dictionary, at: Vector3) -> void:
	balls.erase(b)
	lands += 1
	last_at = at
	shocks.append({"at":at,"way":(b.vel as Vector3).normalized(),"age":0.0,"hit_pilot":false,"hit_plane":false})
	_burst = Vector4(at.x,at.z,0.0,BURST_LEAN)
	_burst_travel = BURST_TRAVEL*shock_radius()
	print("dragon air blast: burst at (%.1f, %.1f, %.1f), %.1f m from its aim" % [at.x,at.y,at.z,at.distance_to(b.aim as Vector3)])
	if look and is_inside_tree():
		var r := shock_radius()
		for i in range(30):
			var a := float(i)/30.0*TAU+_rng.randf_range(-0.1,0.1)
			var out := Vector3(cos(a),0.0,sin(a))
			var size := _rng.randf_range(0.5,0.8)*r*0.5
			_free_puff(at+out*r*0.2+Vector3.UP*size*0.4,out*_rng.randf_range(30.0,44.0)+Vector3.UP*_rng.randf_range(0.5,3.0),size,size*2.0,_rng.randf_range(0.6,1.0),DUST_TINT if i%2 else AIR_TINT,0.5)
		for i in range(10):
			var d := Vector3(_rng.randf_range(-1,1),_rng.randf_range(0.2,1),_rng.randf_range(-1,1)).normalized()
			var size := _rng.randf_range(0.4,0.7)*r*0.5
			_free_puff(at,d*_rng.randf_range(8.0,16.0),size,size*2.4,_rng.randf_range(0.7,1.2),AIR_TINT,0.45)
	landed.emit(at)

## Popped on stone cover: gone, harmless, a puff off what it hit.
func _pop(b: Dictionary, at: Vector3, normal: Vector3) -> void:
	balls.erase(b)
	breaks += 1
	last_at = at
	print("dragon air blast: popped on cover at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	if look and is_inside_tree():
		for i in range(14):
			var d := (normal*0.7+Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.5,1),_rng.randf_range(-1,1))*0.6).normalized()
			var size := _rng.randf_range(0.6,1.1)*ball_radius()
			_free_puff(at+normal*0.5,d*_rng.randf_range(5.0,12.0),size,size*2.6,_rng.randf_range(0.5,0.9),AIR_TINT if i%3 else DUST_TINT,0.5)
	broke.emit(at)

# --- Contact ------------------------------------------------------------------------------

## A ball whose last step passed within `reach` m of `p` bursts at its
## nearest; true if one did.
func _catch(p: Vector3, reach: float) -> bool:
	for b: Dictionary in balls.duplicate():
		var near := Geometry3D.get_closest_point_to_segment(p,b.was,b.pos)
		if near.distance_to(p) <= reach:
			burst(b,near)
			return true
	return false

## Whether stone stands between a burst at `at` and `p` (the shock hides
## behind cover too).
func _shielded(at: Vector3, p: Vector3) -> bool:
	if _space == null or at.distance_to(p) < 0.3: return false
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = SOLID
	ray.from = at
	ray.to = p
	var hit := _space.intersect_ray(ray)
	if hit.is_empty(): return false
	var body: Object = hit.get("collider")
	return body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & TURF) == 0 and (hit.position as Vector3).distance_to(p) > 0.3

## The pilot's knock (m/s: hand to PilotMotor `knock`), ZERO for none: a
## ball passing him bursts on him; a fresh burst with his chest in its
## shock, nothing of stone between, throws him out and up from it, harder
## the nearer, once a burst. `motor` gives `knock_velocity`; one recovering
## from a knock isn't thrown again.
func pilot_knock(feet: Vector3, motor: Object) -> Vector3:
	var t := walker_tall()
	var chest := feet+Vector3.UP*0.55*t
	var reach := PhysicsGround.RADIUS*WorldScale.wanderer
	_catch(chest,ball_radius()+reach+FUSE*t)
	if motor.has_method("recovering") and motor.recovering(): return Vector3.ZERO
	for s: Dictionary in shocks:
		if bool(s.hit_pilot): continue
		var at: Vector3 = s.at
		var d := at.distance_to(chest)
		if d > shock_radius()+reach: continue
		if _shielded(at,chest): continue
		s.hit_pilot = true
		var k := lerpf(1.0,EDGE,clampf(d/shock_radius(),0.0,1.0))
		var v: Vector3 = motor.knock_velocity(_away(s,chest),KNOCK_OUT*t*k,KNOCK_UP*t*k)
		knocks += 1
		print("dragon air blast: knocks the pilot %.1f m from the burst, out (%.1f, %.1f) up %.1f m/s" % [d,v.x,v.z,v.y])
		return v
	return Vector3.ZERO

## Flat way out from a burst to `p`: the shot's own way at its heart.
func _away(s: Dictionary, p: Vector3) -> Vector2:
	var at: Vector3 = s.at
	var w: Vector3 = s.way
	var shot := Vector2(w.x,w.z)
	var rel := Vector2(p.x-at.x,p.z-at.z)
	if rel.length() > 0.6: return (rel.normalized()+shot.normalized()*0.3).normalized() if shot.length() > 0.01 else rel.normalized()
	return shot.normalized() if shot.length() > 0.01 else Vector2.RIGHT

## The blast as air for the plane at `p` (`nose` its forward): {wind,
## shove, gust, thermal}, as the cyclone's: a ball passing it bursts on it;
## a fresh burst in reach throws it out along the shot and down, the nose
## kicked down and the wings rolled hard: a tumble out of the sky; lingering
## THROW_LINGER s. Empty with none.
func plane_air(p: Vector3, nose: Vector3) -> Dictionary:
	_catch(p,ball_radius()+WorldScale.span*0.5+FUSE*walker_tall())
	for s: Dictionary in shocks:
		if bool(s.hit_plane): continue
		var at: Vector3 = s.at
		var d := at.distance_to(p)
		var reach := WorldScale.span*PLANE_SHOCK
		if d > reach or _shielded(at,p): continue
		s.hit_plane = true
		var k := lerpf(1.0,EDGE,clampf(d/reach,0.0,1.0))
		var w: Vector3 = s.way
		var out := ((p-at).normalized() if d > 0.5 else w)
		out = (out+w).normalized()
		var flat := Vector2(out.x,out.z)
		flat = flat.normalized() if flat.length() > 0.05 else Vector2(nose.x,nose.z).normalized()
		var wind := Vector3(flat.x,0.0,flat.y)*PLANE_OUT*k+Vector3.DOWN*PLANE_DOWN*k
		var right := Vector2(-nose.z,nose.x).normalized() if Vector2(nose.x,nose.z).length() > 0.01 else Vector2.RIGHT
		var tip := signf(flat.dot(right))
		if tip == 0.0: tip = 1.0
		_throw = {"wind":wind,"shove":Vector3(-PLANE_PITCH*k,PLANE_YAW*k*tip,PLANE_ROLL*k*tip),"gust":k,"thermal":0.0}
		_throw_t = THROW_LINGER
		knocks += 1
		print("dragon air blast: throws the plane %.1f m from the burst, wind (%.1f, %.1f, %.1f)" % [d,wind.x,wind.y,wind.z])
	if _throw_t > 0.0 and not _throw.is_empty():
		var u := _throw_t/THROW_LINGER
		var e := u*u*(3.0-2.0*u)
		return {"wind":(_throw.wind as Vector3)*e,"shove":(_throw.shove as Vector3)*e,"gust":float(_throw.gust)*e,"thermal":0.0}
	return {}

# --- The wind tool ------------------------------------------------------------------------

## The shock's ring (zs_burst_*, aged here, as the cyclone's), cleared once
## done.
func _publish_wind() -> void:
	if _burst.w <= 0.0 and not _published: return
	_published = _burst.w > 0.0
	RenderingServer.global_shader_parameter_set("zs_burst_a",_burst)
	RenderingServer.global_shader_parameter_set("zs_burst_b",Vector4(BURST_RUN,0.0,_burst_travel,_burst_travel) if _burst.w > 0.0 else Vector4.ZERO)

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

## The ball: a camera-facing soft lens that bends the screen behind it (a
## swirl of heat shimmer, strongest in a ring inside its rim), a pale glow
## at the rim and a faint core, no edge.
static func _lens_mesh() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
varying float fade;
varying vec3 tint;
void vertex() {
	fade = INSTANCE_CUSTOM.r;
	tint = COLOR.rgb;
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float wob = 0.06 * sin(a * 3.0 + TIME * 9.0) + 0.04 * sin(a * 7.0 - TIME * 13.0);
	float body = 1.0 - smoothstep(0.55 + wob, 1.0, r);
	float ring = smoothstep(0.2, 0.7, r) * (1.0 - smoothstep(0.7, 1.0, r));
	vec2 swirl = vec2(-c.y, c.x) * sin(TIME * 11.0 + r * 9.0) * 0.4;
	vec2 bend = (c * -0.9 + swirl) * ring * 0.035 * fade;
	vec3 behind = textureLod(screen, SCREEN_UV + bend, 0.0).rgb;
	float glow = ring * 0.35 + (1.0 - smoothstep(0.0, 0.45, r)) * 0.15;
	ALBEDO = mix(behind, tint, clamp(glow, 0.0, 1.0));
	ALPHA = clamp(body * fade, 0.0, 1.0);
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
	if not look or not is_inside_tree(): return
	for i in range(count):
		var d := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.5,1),_rng.randf_range(-1,1)).normalized()
		var size := _rng.randf_range(0.8,1.3)*ball_radius()
		_free_puff(at,d*_rng.randf_range(3.0,7.0),size,size*2.0,_rng.randf_range(0.5,0.9),tint,alpha)

func _step_free(delta: float) -> void:
	for s: Dictionary in _free:
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			continue
		s.v = (s.v as Vector3)*(1.0-minf(0.95,3.0*delta))
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta

## The balls drawn: the lens, its trail of streaks along the line behind it
## (a share of his span long) and puffs shed along it; then the free puffs.
func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	var lm := _lens.multimesh
	var sm := _streaks.multimesh
	var pm := _puffs.multimesh
	var li := 0
	var si := 0
	var pj := 0
	var r := ball_radius()
	for b: Dictionary in balls:
		var at: Vector3 = b.pos
		var way := (b.vel as Vector3).normalized()
		var grown := smoothstep(0.0,0.08,float(b.age))
		var fade := grown*(1.0-smoothstep(RANGE*0.8,RANGE,float(b.travelled)))
		var pulse := 1.0+0.08*sin(_clock*40.0+float(b.age)*7.0)
		lm.set_instance_transform(li,Transform3D(Basis.from_scale(Vector3.ONE*r*2.6*pulse*lerpf(GATHER,1.0,grown)),at))
		lm.set_instance_custom_data(li,Color(fade,0,0,0))
		lm.set_instance_color(li,AIR_TINT)
		li += 1
		# The trail: thin streaks behind it, fanned a little, shorter on the
		# way out of the mouth.
		var long := minf(float(b.travelled),0.12*span)
		for i in range(TRAIL_STREAKS):
			var u := float(i)/float(TRAIL_STREAKS)
			var a := u*TAU*3.0+_clock*20.0
			var side := way.cross(Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT).normalized()
			var up := side.cross(way).normalized()
			var off := (side*cos(a)+up*sin(a))*r*lerpf(0.3,0.9,u)
			var mid := at-way*(long*(0.25+0.6*u))+off
			var across := way.cross((eye-mid).normalized())
			if across.length() < 0.01: across = Vector3.UP
			across = across.normalized()
			var normal := way.cross(across).normalized()
			sm.set_instance_transform(si,Transform3D(Basis(way*long*lerpf(0.7,0.35,u),across*r*lerpf(0.5,0.25,u),normal),mid))
			sm.set_instance_custom_data(si,Color(fade*lerpf(0.55,0.15,u),0,0,0))
			sm.set_instance_color(si,AIR_TINT)
			si += 1
		for i in range(TRAIL_PUFFS):
			var u := float(i+1)/float(TRAIL_PUFFS+1)
			var size := r*lerpf(1.1,2.2,u)
			var wob := Vector3(sin(_clock*7.0+i*1.7),cos(_clock*6.0+i*2.3),sin(_clock*5.0+i))*r*0.3*u
			pm.set_instance_transform(pj,Transform3D(Basis.from_scale(Vector3.ONE*size),at-way*long*u*0.8+wob))
			pm.set_instance_custom_data(pj,Color(fade*0.22*(1.0-u),0,0,0))
			pm.set_instance_color(pj,AIR_TINT)
			pj += 1
	# The wind-up: the ball gathering in his jaw.
	if phase == "windup" and _mouth != Vector3.INF:
		var g := windup_share()
		lm.set_instance_transform(li,Transform3D(Basis.from_scale(Vector3.ONE*r*2.6*GATHER*g*(1.0+0.12*sin(_clock*50.0))),_mouth))
		lm.set_instance_custom_data(li,Color(g,0,0,0))
		lm.set_instance_color(li,AIR_TINT)
		li += 1
	for s: Dictionary in _free:
		if float(s.life) <= 0.0: continue
		var u := float(s.age)/float(s.life)
		var size := lerpf(float(s.size),float(s.grow),1.0-pow(1.0-u,2.0))
		var fade := smoothstep(0.0,0.1,u)*(1.0-smoothstep(0.3,1.0,u))*float(s.alpha)
		pm.set_instance_transform(pj,Transform3D(Basis.from_scale(Vector3.ONE*size),s.p))
		pm.set_instance_custom_data(pj,Color(fade,0,0,0))
		pm.set_instance_color(pj,s.tint)
		pj += 1
	lm.visible_instance_count = li
	sm.visible_instance_count = si
	pm.visible_instance_count = pj
