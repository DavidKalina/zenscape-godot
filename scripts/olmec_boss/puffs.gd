extends Node3D
## The boss head's puffs (scripts/olmec_boss/boss_head.gd): what it drew in,
## blown back out. Each has its tell (`tell_pose`, the head's pose through
## it), its release (`release`) and its own frame (`step`); each knocks the
## wanderer with the game's knock (PilotMotor `knock`, laid down a beat) and
## hits the arena's pieces through the head's `hit_arena` (nothing if the
## study has no arena).
##   volley  3..5 dense air balls in a fan, one after another across it
##           (the dragon's air blast, scripts/dragon_air_blast.gd): each
##           bursts on the turf, on him if it passes near, or pops on stone
##           (a pillar takes it). Sidestep through the fan, or hide.
##   ring    a jaw slam, then a ring of wind rolling out along the turf
##           (RING_R m, the dragon burst's front law, so the grass it
##           flattens keeps pace): it bowls him over unless he is in the air
##           as it passes. Jump it.
##   whirl   a small twister spat out at him: it wanders after him
##           WHIRL_LIFE s and flings him if it catches him, tearing at the
##           pieces in its path.
##   breath  a sustained cone of wind BREATH_LEN s, slowly following him:
##           it shoves him back along it toward the rim; stone between his
##           chest and its mouth breaks the stream.
## Sizes are the walker's (DragonAirBlast.walker_tall) or the field's (m).

const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const GustShot = preload("res://scripts/lock_on/gust_shot.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## Tells (s).
const TELLS := {"volley":1.0,"ring":1.3,"whirl":1.1,"breath":1.1}
## The volley: balls near / far (always odd: one at him), the fan's spacing (rad), the gap between
## shots (s), the ball's pace (m/s), flight (m), fuse (walker heights), the
## knock (walker heights out, up) and the down (s).
const VOLLEY := Vector2i(3,5)
const FAN := 0.3
const VOLLEY_GAP := 0.16
const BALL_SPEED := 21.0
const BALL_FLIGHT := 48.0
const BALL_FUSE := 0.25
const BALL_KNOCK := Vector2(6.5,1.4)
const BALL_DOWN := 0.9
## The ring: its reach (m), its run (s: the dragon burst's front law), the
## band it catches in (m either side), how high off the turf he must be to
## clear it (walker heights), its look's height (walker heights), the knock.
const RING_R := 30.0
const RING_RUN := 2.6
const RING_BAND := 0.9
const RING_CLEAR := 0.22
const RING_TALL := 0.7
const RING_KNOCK := Vector2(5.0,1.1)
const RING_DOWN := 0.8
const BLOW_WIND_UP := 0.14
## The whirlwind: its life (s), pace (m/s), turn (rad/s), catch radius and
## height (walker heights), the fling (walker heights out, up), the down.
const WHIRL_LIFE := 6.0
const WHIRL_SPEED := 5.2
const WHIRL_TURN := 1.1
const WHIRL_CATCH := 0.85
const WHIRL_TALL := 3.6
const WHIRL_KNOCK := Vector2(5.5,3.2)
const WHIRL_DOWN := 1.0
## The long breath: its length (s), half angle (rad), reach (m), its shove
## (shares of his run pace, near and far), in the air (m/s² per m/s).
const BREATH_LEN := 2.8
const BREATH_HALF := 0.3
const BREATH_REACH := 26.0
const BREATH_PUSH := Vector2(1.25,0.55)
const BREATH_AIR := 2.0
const DUST := Color(0.86,0.82,0.70)
const AIR := Color(0.9,0.95,1.0)

var head
var look := true
## The tells' pace: 1 the head alone's; under 1 quicker (worn on his neck,
## phase 2).
var quick := 1.0
var history: Array = []
## Counts, for the card and checks: puffs let go, knocks on him by kind,
## rings he jumped.
var released := {"volley":0,"ring":0,"whirl":0,"breath":0}
var knocks := {"volley":0,"ring":0,"whirl":0,"breath":0}
var ring_jumped := 0
## What is live now.
var shots: Array = []
var ring := {}
var whirl := {}
var breath := {}
var _blasts: Array = []
var _dust: DragonAirBlast
var _mesh: ImmediateMesh
var _draw_node: MeshInstance3D
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _ring_published := false

func setup(owner_head: Node3D, drawn: bool) -> void:
	head = owner_head
	look = drawn
	top_level = true
	_rng.seed = 5150

func _ready() -> void:
	var see: Array[RID] = [head.body.get_rid()]
	for i in range(VOLLEY.y):
		var b := DragonAirBlast.new()
		b.name = "VolleyBall%d" % i
		b.on = false
		b.look = look
		b.speed = BALL_SPEED
		b.flight = BALL_FLIGHT
		b.fuse = BALL_FUSE
		b.knock_out = BALL_KNOCK.x
		b.knock_up = BALL_KNOCK.y
		b.glow = 1.0
		b.see_through = see
		add_child(b)
		b.landed.connect(func(at: Vector3) -> void: head.hit_arena(at,DragonAirBlast.shock_radius()*0.6,0.6))
		b.broke.connect(func(at: Vector3) -> void: head.hit_arena(at,DragonAirBlast.ball_radius()*2.0,1.0))
		_blasts.append(b)
	_dust = DragonAirBlast.new()
	_dust.name = "PuffDust"
	_dust.on = false
	_dust.look = look
	_dust.publish = false
	add_child(_dust)
	if not look: return
	_mesh = ImmediateMesh.new()
	_mat = ShaderMaterial.new()
	_mat.shader = GustShot._shader()
	_draw_node = MeshInstance3D.new()
	_draw_node.name = "PuffLook"
	_draw_node.top_level = true
	_draw_node.mesh = _mesh
	_draw_node.material_override = _mat
	_draw_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_draw_node.extra_cull_margin = 2000.0
	add_child(_draw_node)

func _exit_tree() -> void:
	if _ring_published: _publish_ring(Vector4.ZERO,Vector4.ZERO)

static func tall() -> float:
	return DragonAirBlast.walker_tall()

# --- The head's poses through a puff --------------------------------------------------

func tell_len(kind: String) -> float:
	return float(TELLS.get(kind,1.0))*quick

## The head's pose at `k` (0..1) through `kind`'s tell: {open, lean, shake,
## swell (over full), aim (it keeps turning onto him), roll}.
func tell_pose(kind: String, k: float, clock: float) -> Dictionary:
	match kind:
		"volley":
			# Jaw clamped, cheeks blown right out, a little rise on its heel.
			var e := smoothstep(0.0,0.8,k)
			return {"open":0.0,"lean":0.06*e+0.008*sin(clock*31.0)*k,"shake":0.004+0.014*k,"swell":0.45*e,"aim":true}
		"ring":
			# Up high on its heel, jaw wide (0..0.5), held there trembling
			# (..0.82), then thrown down onto its chin (the slam is the
			# release).
			var lean := 0.0
			if k < 0.5: lean = 0.26*(1.0-pow(1.0-k/0.5,2.0))
			elif k < 0.82: lean = 0.26+0.012*sin(clock*40.0)
			else: lean = lerpf(0.26,-0.12,pow((k-0.82)/0.18,2.0))
			return {"open":0.95*smoothstep(0.0,0.4,k)*(1.0-smoothstep(0.85,1.0,k)*0.6),"lean":lean,"shake":0.006 if k < 0.5 else 0.02,"swell":0.2,"aim":false}
		"whirl":
			# Rocking side to side, faster and wider: winding the air round.
			var e := smoothstep(0.0,1.0,k)
			return {"open":0.35,"lean":0.04*e,"shake":0.006,"swell":0.3*e,"aim":true,"roll":0.075*sin(clock*(6.0+8.0*k))*(0.3+0.7*e)}
		"breath":
			# Leaning back, the jaw slowly opening, eyes flaring.
			var e := smoothstep(0.0,1.0,k)
			return {"open":0.2+0.6*e,"lean":0.13*e,"shake":0.012*k,"swell":0.35*e,"aim":true}
	return {"open":0.0,"lean":0.0,"shake":0.0,"swell":0.0,"aim":true}

func puff_len(kind: String) -> float:
	match kind:
		"volley": return float(shots.size()+_fired)*VOLLEY_GAP+0.4
		"ring": return 0.9
		"whirl": return 0.7
		"breath": return BREATH_LEN
	return 0.5

## The head's pose `t` s into `kind`'s release.
func puff_pose(kind: String, t: float, clock: float) -> Dictionary:
	match kind:
		"volley":
			# A snap of the jaw and a kick forward for each ball.
			var u := fmod(t,VOLLEY_GAP)/VOLLEY_GAP if shots.size() > 0 else 1.0
			return {"open":lerpf(1.0,0.45,u) if shots.size() > 0 or t < float(_fired)*VOLLEY_GAP+0.1 else 0.2,"lean":lerpf(-0.07,-0.02,u),"shake":0.02,"aim":false}
		"ring":
			return {"open":0.3*(1.0-t/0.9),"lean":lerpf(-0.12,-0.02,smoothstep(0.0,0.9,t)),"shake":0.035*(1.0-t/0.9),"aim":false}
		"whirl":
			return {"open":0.8*(1.0-smoothstep(0.2,0.7,t)),"lean":-0.07*(1.0-smoothstep(0.1,0.7,t)),"shake":0.015,"aim":false}
		"breath":
			var fade := 1.0-smoothstep(BREATH_LEN-0.5,BREATH_LEN,t)
			return {"open":(1.05+0.04*sin(clock*21.0))*fade,"lean":-0.02+0.008*sin(clock*13.0),"shake":0.014*fade,"aim":true}
	return {"open":0.0,"lean":0.0,"shake":0.0,"aim":false}

# --- Letting go -------------------------------------------------------------------------

var _fired := 0

## The tell begins: a puff of dust as it draws itself up.
func tell(kind: String) -> void:
	if look and kind == "ring": _skirt(0.5)

## Lets `kind` go at him (his chest `chest`).
func release(kind: String, chest: Vector3) -> void:
	history.append(kind)
	if history.size() > 6: history.pop_front()
	released[kind] = int(released[kind])+1
	var mouth: Vector3 = head.mouth()
	var flat := Vector3(chest.x-mouth.x,0.0,chest.z-mouth.z)
	var d := flat.length()
	flat = flat/d if d > 0.1 else head.face_flat()
	print("boss head: puff %s at %.1f m" % [kind,d])
	match kind:
		"volley":
			var n := VOLLEY.x if d < float(head.knobs.near) or _rng.randf() < 0.3 else VOLLEY.y
			shots.clear()
			_fired = 0
			var from_left := _rng.randf() < 0.5
			for i in range(n):
				var j := i if from_left else n-1-i
				var a := (float(j)-float(n-1)*0.5)*FAN+_rng.randf_range(-0.04,0.04)
				shots.append({"t":float(i)*VOLLEY_GAP,"way":flat.rotated(Vector3.UP,a),"y":chest.y,"d":maxf(d,6.0)})
			head.field.sound(&"head_blast",mouth)
		"ring":
			var c: Vector3 = head.rest_point()
			ring = {"at":c,"t":0.0,"r":0.0,"hit":false,"jumped":false,"swept":0.0}
			_skirt(1.6)
			head.air.thud(c+head.face_flat()*head.height*0.5,head.face_flat(),2.0,head.width)
			head.field.sound(&"head_thud",c)
			head.field.sound(&"head_blast",c)
		"whirl":
			var p: Vector3 = head.rest_point()+head.face_flat()*(head.length*0.6+1.0)
			whirl = {"at":p,"way":flat,"t":0.0,"swirl":0.0,"arena_t":0.0,"done":-1.0}
			head.field.sound(&"head_blast",mouth)
			if look:
				for i in range(10): _dust._free_puff(mouth,(flat+Vector3(_rng.randf_range(-0.4,0.4),_rng.randf_range(-0.2,0.3),_rng.randf_range(-0.4,0.4))).normalized()*_rng.randf_range(6.0,12.0),0.5,1.6,0.6,AIR,0.4)
		"breath":
			breath = {"t":0.0,"arena_t":0.0,"puff_t":0.0}
			head.field.sound(&"head_blast",mouth)
			head.field.sound(&"head_inhale",mouth)

## Everything live stops (balls in flight fly on).
## The absorb: dust lifted off the turf in front and drawn to its mouth
## (`share` how hard it draws).
func absorbing(share: float, delta: float) -> void:
	if not look or share < 0.3: return
	var mouth: Vector3 = head.mouth()
	var way: Vector3 = head.face_flat()
	for i in range(2 if _rng.randf() < share else 1):
		var d := _rng.randf_range(3.0,13.0)
		var a := _rng.randf_range(-0.6,0.6)*(1.0-d/20.0)
		var p: Vector3 = mouth+way.rotated(Vector3.UP,a)*d
		var g: float = head.ground_at(p)
		if g == -INF: continue
		p.y = g+0.15
		var to := mouth-p
		var s := _rng.randf_range(0.2,0.4)*tall()
		_dust._free_puff(p,to/maxf(to.length(),0.1)*_rng.randf_range(7.0,11.0)*share,s,s*1.5,minf(to.length()/9.0,0.9),DUST,0.45*share)

## Its balls fly through `rid` too (his body, worn).
func see_through_also(rid: RID) -> void:
	for b: DragonAirBlast in _blasts:
		if not b.see_through.has(rid): b.see_through.append(rid)

func stop() -> void:
	shots.clear()
	ring = {}
	whirl = {}
	breath = {}

# --- A frame -----------------------------------------------------------------------------

func step(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	var m: PilotMotor = head.field.motor
	var space: PhysicsDirectSpaceState3D = head.get_world_3d().direct_space_state
	var mouth: Vector3 = head.mouth()
	var chest: Vector3 = head._chest(m)
	var can_knock: bool = not bool(head.field.study.get("flying")) and not m.seized() and not bool(head.get("swallowed"))
	_step_volley(delta,mouth)
	for b: DragonAirBlast in _blasts:
		b.advance(delta,space,false,mouth,chest)
		if can_knock:
			var v := b.pilot_knock(m.feet,m)
			if v != Vector3.ZERO: _knock(m,v,BALL_DOWN,"volley")
	_step_ring(delta,m,can_knock)
	_step_whirl(delta,m,can_knock)
	_step_breath(delta,m,mouth,chest,can_knock)
	_dust.advance(delta,space,false,mouth,Vector3.INF)
	_draw()

func _knock(m: PilotMotor, v: Vector3, down: float, kind: String) -> void:
	m.knock(v,head,down)
	knocks[kind] = int(knocks[kind])+1
	print("boss head: %s knocks him (%.1f, %.1f, %.1f) m/s" % [kind,v.x,v.y,v.z])

func _step_volley(delta: float, mouth: Vector3) -> void:
	if shots.is_empty(): return
	for s: Dictionary in shots: s.t = float(s.t)-delta
	while not shots.is_empty() and float(shots[0].t) <= 0.0:
		var s: Dictionary = shots.pop_front()
		var b: DragonAirBlast = _blasts[_fired%_blasts.size()]
		_fired += 1
		var way: Vector3 = s.way
		var aim := mouth+way*float(s.d)
		aim.y = float(s.y)
		b.fire(mouth+way*0.6,aim)
		head._lean_kick = minf(head._lean_kick,-0.04)
		head._open = maxf(head._open,1.0)

# --- The ring ---------------------------------------------------------------------------

## The front's reach `t` s after the slam (the dragon burst's law: quick
## out, slowing).
static func ring_front(t: float) -> float:
	var u := clampf(t/RING_RUN,0.0,1.0)
	return RING_R*(2.0*u-u*u)

func _step_ring(delta: float, m: PilotMotor, can_knock: bool) -> void:
	if ring.is_empty():
		if _ring_published:
			_publish_ring(Vector4.ZERO,Vector4.ZERO)
			_ring_published = false
		return
	ring.t = float(ring.t)+delta
	var was := float(ring.r)
	var r := ring_front(float(ring.t))
	ring.r = r
	var c: Vector3 = ring.at
	_publish_ring(Vector4(c.x,c.z,float(ring.t)+BLOW_WIND_UP,2.6),Vector4(RING_RUN,0.0,RING_R,RING_R))
	_ring_published = true
	var t := tall()
	# Him: caught as the front crosses him, unless he's clear of the turf.
	var feet := m.feet
	var d := Vector2(feet.x-c.x,feet.z-c.z).length()
	if not bool(ring.hit) and was <= d+RING_BAND and r >= d-RING_BAND and r < RING_R*0.98:
		var floor_y: float = head.field.floor_under(feet,0.3,8.0,head.body.get_rid())
		var up := feet.y-floor_y if floor_y != -INF else 99.0
		if not m.grounded and up > RING_CLEAR*t:
			if not bool(ring.jumped):
				ring.jumped = true
				ring_jumped += 1
				print("boss head: ring passed under him, %.2f m up" % up)
		elif can_knock and not m.recovering():
			ring.hit = true
			var away := Vector2(feet.x-c.x,feet.z-c.z).normalized()
			_knock(m,m.knock_velocity(away,RING_KNOCK.x*t,RING_KNOCK.y*t),RING_DOWN,"ring")
	# The pieces it rolls through: every 2.5 m of its front, a ring of blows.
	if r-float(ring.swept) >= 2.5:
		ring.swept = r
		var n := maxi(8,int(TAU*r/3.0))
		for i in range(n):
			var a := TAU*float(i)/float(n)
			head.hit_arena(c+Vector3(cos(a)*r,0.8,sin(a)*r),TAU*r/float(n)*0.6,0.5*(1.0-r/RING_R*0.6))
	# Dust kicked up along its front.
	if look and r < RING_R*0.97:
		var pace := RING_R*(2.0-2.0*clampf(float(ring.t)/RING_RUN,0.0,1.0))/RING_RUN
		for i in range(8):
			var a := _rng.randf()*TAU
			var out := Vector3(cos(a),0.0,sin(a))
			var p := c+out*r
			var g: float = head.ground_at(p)
			if g == -INF: continue
			p.y = g+0.2
			var size := _rng.randf_range(0.3,0.6)*t
			_dust._free_puff(p,out*pace*_rng.randf_range(0.75,0.95)+Vector3.UP*_rng.randf_range(0.6,2.0),size,size*2.6,_rng.randf_range(0.35,0.6),DUST,0.5*(1.0-r/RING_R))
	if float(ring.t) > RING_RUN+0.4: ring = {}

func _publish_ring(a: Vector4, b: Vector4) -> void:
	RenderingServer.global_shader_parameter_set("zs_burst_a",a)
	RenderingServer.global_shader_parameter_set("zs_burst_b",b)

## A skirt of dust round the head's foot (`size` 1 a heave's).
func _skirt(size: float) -> void:
	if not look: return
	var c: Vector3 = head.rest_point()
	var r: float = head.width*0.55
	for i in range(int(14*size)):
		var a := _rng.randf()*TAU
		var out := Vector3(cos(a),0.0,sin(a))
		var s := _rng.randf_range(0.4,0.8)*tall()*size*0.6
		_dust._free_puff(c+out*r+Vector3.UP*0.3,out*_rng.randf_range(5.0,12.0)*size+Vector3.UP*_rng.randf_range(0.5,2.0),s,s*2.4,_rng.randf_range(0.6,1.1),DUST,0.5)

# --- The whirlwind -----------------------------------------------------------------------

func _step_whirl(delta: float, m: PilotMotor, can_knock: bool) -> void:
	if whirl.is_empty(): return
	whirl.t = float(whirl.t)+delta
	whirl.swirl = float(whirl.swirl)+delta*(9.0)
	var t := tall()
	var p: Vector3 = whirl.at
	if float(whirl.done) >= 0.0:
		whirl.done = float(whirl.done)+delta
		if float(whirl.done) > 0.5: whirl = {}
		return
	# After him: turning at most WHIRL_TURN rad/s, wandering a little.
	var way: Vector3 = whirl.way
	var to := Vector3(m.feet.x-p.x,0.0,m.feet.z-p.z)
	if to.length() > 0.2:
		var want := to.normalized().rotated(Vector3.UP,0.5*sin(float(whirl.t)*1.7))
		var turn := way.signed_angle_to(want,Vector3.UP)
		way = way.rotated(Vector3.UP,clampf(turn,-WHIRL_TURN*delta,WHIRL_TURN*delta))
	whirl.way = way
	var grow := smoothstep(0.0,0.6,float(whirl.t))
	p += way*WHIRL_SPEED*grow*delta
	var g: float = head.ground_at(p)
	if g == -INF:
		_end_whirl(p)
		return
	p.y = g
	whirl.at = p
	var d := Vector2(m.feet.x-p.x,m.feet.z-p.z).length()
	if can_knock and d < WHIRL_CATCH*t*grow+0.3 and m.feet.y < p.y+WHIRL_TALL*t and not m.recovering():
		# Flung: round and out along its spin, high.
		var rel := Vector2(m.feet.x-p.x,m.feet.z-p.z)
		var out := rel.normalized() if rel.length() > 0.1 else Vector2(way.x,way.z)
		var spin := Vector2(-out.y,out.x)
		_knock(m,m.knock_velocity((out+spin*0.8).normalized(),WHIRL_KNOCK.x*t,WHIRL_KNOCK.y*t),WHIRL_DOWN,"whirl")
		_end_whirl(p)
		return
	whirl.arena_t = float(whirl.arena_t)-delta
	if float(whirl.arena_t) <= 0.0:
		whirl.arena_t = 0.25
		head.hit_arena(p+Vector3.UP*t,WHIRL_CATCH*t*1.2,0.8)
	if look:
		for i in range(2):
			var a := _rng.randf()*TAU
			var out := Vector3(cos(a),0.0,sin(a))
			var s := _rng.randf_range(0.25,0.5)*t
			_dust._free_puff(p+out*WHIRL_CATCH*t*0.7+Vector3.UP*0.2,Vector3(-out.z,0.0,out.x)*7.0+out*0.8+Vector3.UP*_rng.randf_range(3.0,6.0),s,s*1.8,_rng.randf_range(0.35,0.6),DUST,0.5)
	if float(whirl.t) >= WHIRL_LIFE: _end_whirl(p)

func _end_whirl(p: Vector3) -> void:
	whirl.done = 0.0
	whirl.at = p
	if look:
		for i in range(14):
			var a := _rng.randf()*TAU
			var s := _rng.randf_range(0.4,0.8)*tall()
			_dust._free_puff(p+Vector3.UP*_rng.randf_range(0.3,3.0),Vector3(cos(a),_rng.randf_range(0.0,0.6),sin(a))*_rng.randf_range(3.0,8.0),s,s*2.5,_rng.randf_range(0.5,0.9),DUST if i%2 else AIR,0.45)

# --- The long breath ---------------------------------------------------------------------

func _step_breath(delta: float, m: PilotMotor, mouth: Vector3, chest: Vector3, can_knock: bool) -> void:
	if breath.is_empty(): return
	breath.t = float(breath.t)+delta
	var k := float(breath.t)
	if k >= BREATH_LEN:
		breath = {}
		return
	var on := smoothstep(0.0,0.25,k)*(1.0-smoothstep(BREATH_LEN-0.5,BREATH_LEN,k))
	var way: Vector3 = head.face_flat()
	var rel := chest-mouth
	var flat := Vector3(rel.x,0.0,rel.z)
	var d := flat.length()
	if can_knock and d < BREATH_REACH and d > 0.1 and way.angle_to(flat/d) < BREATH_HALF+atan2(1.0,d) and head._clear(mouth,chest) and m.rider == null and not m.swimming:
		var push := lerpf(BREATH_PUSH.x,BREATH_PUSH.y,d/BREATH_REACH)*float(m.run)*on
		var out := flat/d
		if m.grounded and m.move != "tumble":
			var step := Vector2(out.x,out.z)*push*delta
			var dest: Vector3 = head.field.study.ground.slide(m.feet,step)
			m.carry(Transform3D(Basis.IDENTITY,Vector3(dest.x-m.feet.x,0.0,dest.z-m.feet.z)),0.0)
		else:
			m.velocity += out*push*BREATH_AIR*delta
		breath.pushed = float(breath.get("pushed",0.0))+push*delta
	# Pieces in the stream: the first stone along three lines of it.
	breath.arena_t = float(breath.arena_t)-delta
	if float(breath.arena_t) <= 0.0:
		breath.arena_t = 0.3
		var ray := PhysicsRayQueryParameters3D.new()
		ray.collision_mask = DragonAirBlast.SOLID
		ray.exclude = [head.body.get_rid()]
		for a: float in [-BREATH_HALF*0.6,0.0,BREATH_HALF*0.6]:
			ray.from = mouth
			ray.to = mouth+way.rotated(Vector3.UP,a)*BREATH_REACH
			var hit: Dictionary = head.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty(): head.hit_arena(hit.position,1.5,0.35*on)
	if look:
		breath.puff_t = float(breath.puff_t)-delta
		if float(breath.puff_t) <= 0.0:
			breath.puff_t = 0.035
			var a := _rng.randf_range(-BREATH_HALF,BREATH_HALF)*0.8
			var dir := way.rotated(Vector3.UP,a)
			var s := _rng.randf_range(0.25,0.5)*tall()
			_dust._free_puff(mouth+dir*0.8,dir*_rng.randf_range(16.0,24.0)+Vector3.UP*_rng.randf_range(-0.5,1.0),s,s*3.0,_rng.randf_range(0.9,1.3),AIR if _rng.randf() < 0.6 else DUST,0.35*on)

# --- The look ---------------------------------------------------------------------------

func _draw() -> void:
	if _mesh == null: return
	_mesh.clear_surfaces()
	if ring.is_empty() and whirl.is_empty() and breath.is_empty(): return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null: return
	var eye := cam.global_position
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,_mat)
	# (One clear triangle: a surface with none is an error.)
	for i in range(3): _vert(eye+Vector3(0.0,-1000.0,float(i)*0.01),Vector2.ZERO,Color(0,0,0,0))
	if not ring.is_empty(): _draw_ring()
	if not whirl.is_empty(): _draw_whirl(eye)
	if not breath.is_empty(): _draw_breath(eye)
	_mesh.surface_end()

## The ring: a low band of wind standing on the turf at its front, a fainter
## wider wash behind it, fading as it slows.
func _draw_ring() -> void:
	var c: Vector3 = ring.at
	var r := float(ring.r)
	if r < 0.5: return
	var fade := 1.0-smoothstep(RING_R*0.7,RING_R,r)
	var t := tall()
	var n := clampi(int(TAU*r/1.2),24,128)
	# A wall of wind leaning out, its crest, a dusty wash behind.
	_band(c,r,n,0.0,RING_TALL*t,AIR,0.8*fade,0.35*t)
	_band(c,r-0.3,n,0.0,RING_TALL*t*0.55,Color(1,1,1),0.7*fade,0.2*t)
	for k in range(4): _band(c,maxf(r-0.9-float(k)*0.9,0.3),n,0.0,RING_TALL*t*(0.85-0.15*float(k)),DUST,(0.4-0.08*float(k))*fade,0.25*t)

func _band(c: Vector3, r: float, n: int, h0: float, h1: float, col: Color, alpha: float, lean := 0.0) -> void:
	var prev := Vector3.INF
	var prev_u := 0.0
	var cc := Color(col.r,col.g,col.b,alpha)
	for i in range(n+1):
		var a := TAU*float(i)/float(n)
		var p := c+Vector3(cos(a)*r,0.0,sin(a)*r)
		var g: float = head.ground_at(p) if i%2 == 0 or prev == Vector3.INF else prev.y
		if g == -INF:
			prev = Vector3.INF
			continue
		p.y = g
		var u := float(i)/float(n)*r*0.4
		var out := Vector3(cos(a),0.0,sin(a))*lean
		if prev != Vector3.INF:
			var pout := Vector3(cos(TAU*float(i-1)/float(n)),0.0,sin(TAU*float(i-1)/float(n)))*lean
			_vert(prev+Vector3.UP*h0,Vector2(prev_u,0.0),cc)
			_vert(p+Vector3.UP*h0,Vector2(u,0.0),cc)
			_vert(p+Vector3.UP*h1+out,Vector2(u,1.0),cc)
			_vert(prev+Vector3.UP*h0,Vector2(prev_u,0.0),cc)
			_vert(p+Vector3.UP*h1+out,Vector2(u,1.0),cc)
			_vert(prev+Vector3.UP*h1+pout,Vector2(prev_u,1.0),cc)
		prev = p
		prev_u = u

## The whirlwind: three spiral strands rising and widening, spun round.
func _draw_whirl(eye: Vector3) -> void:
	var p: Vector3 = whirl.at
	var t := tall()
	var life := minf(smoothstep(0.0,0.5,float(whirl.t)),1.0-smoothstep(WHIRL_LIFE-0.6,WHIRL_LIFE,float(whirl.t)))
	if float(whirl.done) >= 0.0: life = 1.0-float(whirl.done)/0.5
	if life <= 0.0: return
	var h := WHIRL_TALL*t*lerpf(0.4,1.0,life)
	for k in range(8):
		var pts: Array = []
		var lift := 0.08*float(k%3)
		for i in range(30):
			var s := lift+(1.0-lift)*float(i)/29.0
			var a := float(whirl.swirl)*(1.5-s*0.6)+s*TAU*2.6+float(k)*TAU/8.0
			var rr := lerpf(0.35,WHIRL_CATCH*t*1.3,pow(s,1.6))*life*(1.0+0.12*sin(float(whirl.t)*5.0+float(k)))
			pts.append(p+Vector3(cos(a)*rr,s*h,sin(a)*rr))
		_ribbon(eye,pts,0.16*t*(0.6+0.4*float(k%2)),AIR if k%3 != 1 else DUST,0.85*life,true)

## The long breath: streaks rushing out of its mouth along the cone.
func _draw_breath(eye: Vector3) -> void:
	var k := float(breath.t)
	var on := smoothstep(0.0,0.2,k)*(1.0-smoothstep(BREATH_LEN-0.5,BREATH_LEN,k))
	var mouth: Vector3 = head.mouth()
	var way: Vector3 = head.face_flat()
	for i in range(16):
		var phase := fmod(k*1.6+float(i)*0.618,1.0)
		var a := (fmod(float(i)*0.37,1.0)*2.0-1.0)*BREATH_HALF*0.9
		var dir := way.rotated(Vector3.UP,a)
		var rise := (fmod(float(i)*0.53,1.0)-0.35)*0.12
		var s0 := phase*BREATH_REACH
		var s1 := s0+3.5+phase*4.0
		var pts: Array = []
		for j in range(4):
			var s := lerpf(s1,s0,float(j)/3.0)
			pts.append(mouth+dir*s+Vector3.UP*(rise*s-0.02*s))
		_ribbon(eye,pts,0.08*tall()*(1.0+phase*2.0),AIR,0.7*on*(1.0-phase))

## A camera-facing ribbon through `pts`, `wide` m each side, its ends
## faded.
func _ribbon(eye: Vector3, pts: Array, wide: float, col: Color, alpha: float, full := false) -> void:
	if pts.size() < 2 or alpha <= 0.0: return
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := Color()
	var prev_u := 0.0
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		var u := float(i)/float(pts.size()-1)
		var along: Vector3 = (pts[mini(i+1,pts.size()-1)] as Vector3)-(pts[maxi(i-1,0)] as Vector3)
		var across := along.cross(eye-p)
		across = across.normalized() if across.length() > 0.0001 else Vector3.UP
		var l := p+across*wide
		var rr := p-across*wide
		var cc := Color(col.r,col.g,col.b,alpha*(minf(1.0,sin(u*PI)*3.0) if full else sin(u*PI)))
		if i > 0:
			_vert(prev_l,Vector2(prev_u,0),prev_c)
			_vert(prev_r,Vector2(prev_u,1),prev_c)
			_vert(rr,Vector2(u,1),cc)
			_vert(prev_l,Vector2(prev_u,0),prev_c)
			_vert(rr,Vector2(u,1),cc)
			_vert(l,Vector2(u,0),cc)
		prev_l = l
		prev_r = rr
		prev_c = cc
		prev_u = u

func _vert(p: Vector3, uv: Vector2, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_set_uv(uv)
	_mesh.surface_set_uv2(Vector2.ZERO)
	_mesh.surface_add_vertex(p)
