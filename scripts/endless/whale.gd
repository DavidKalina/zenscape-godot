extends Node3D
## The whale of the open sea (docs/design/whale/spec-whale.md): a rare moment for
## a plane skimming deep water far from any shore. Ahead of the plane and a
## little off its line a blow goes up, the back rolls through the surface, the
## tail lifts in a tall arc with water sheeting off the flukes, holds, and slides
## under, leaving foam and rings. One at a time, no forces on the plane, nothing
## it can crash into: the tail is passed, not hit (a near miss, NearMiss
## `shot_pass`, as a cannon ball's pass is).
##
## Waiting costs a countdown a frame and one look at the sea under the plane
## every READ s. A whale is staged when the plane has flown low and fast over
## open sea for STINT s, COOLDOWN s of flight after the last one (FIRST s into
## the run for the first), on a CHANCE roll; a lost roll waits RETRY s of open
## sea. The spot is where the plane will be in MEET s, OFF m to one side, the
## whale swimming much the plane's way, so its flukes face the plane coming up
## astern. `_site_ok` keeps it in deep water clear of every shore, rock, ship
## and the edge's big swell, with open water all the way from the plane.
##
## Staged, the clip plays a little faster or slower (RATE) until the tail starts
## up, so the flukes stand as the plane arrives whether it boosts or eases off
## on the way; a plane that turns away is let go and the clip runs as baked.
##
## Flags: `--whale=0` none; `--whale-now` the first as soon as the plane has been
## STINT_NOW s over open sea, and again every COOLDOWN_NOW s; `--whale-cooldown=S`,
## `--whale-first=S`, `--whale-chance=P`, `--whale-retry=S`.

const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WhaleBody = preload("res://scripts/endless/whale_body.gd")

## Rarity (s of flight; a share).
const COOLDOWN := 600.0
const FIRST := 150.0
const CHANCE := 0.35
const RETRY := 45.0
const STINT := 8.0
const STINT_NOW := 2.0
const COOLDOWN_NOW := 25.0
## A roll won is kept this long while a spot is looked for (s).
const WON_FOR := 40.0
## How often the sea under the plane is looked at (s).
const READ := 0.5
## Open sea, for the plane: this low over the sea (m), at least this share of
## cruise, the bed this far under the sea's level (m).
const LOW := 35.0
const FAST := 0.75
const DEEP := 20.0
## The spot: where the plane is in MEET s (the middle of the flukes' stand), no
## nearer or farther than LEAD (m), OFF m to a side, the whale's way within TURN
## rad of the plane's.
const MEET := 11.0
const LEAD := Vector2(360.0,760.0)
const OFF := Vector2(12.0,26.0)
const TURN := 0.3
## The site: deep water on rings this far out (m), eight bearings each; the
## whale's own lane (m: astern, ahead, half across, the step) free of stone;
## this far from a ship.
const RINGS: Array[float] = [0.0,90.0,200.0,330.0,450.0]
const LANE := Vector4(90.0,50.0,32.0,22.0)
const SHIP_CLEAR := 600.0
## The most the edge's big swell may rise there (m).
const SURGE_MOST := 6.0
## The whale rides the swell at its spot, eased this fast (1/s).
const RIDE := 0.8
## The clip's rate while the plane is on its way (least, most), and how fast it
## changes (1/s). The plane is "on its way" closing at this share of its speed.
const RATE := Vector2(0.6,1.7)
const RATE_EASE := 1.5
const CLOSING := 0.5
## Particle caps: the blow's mist, the drops off the flukes, the spume at the
## tail's foot.
const BLOW := 160
const SHEET := 500
const SPUME := 60
## The second, smaller blow (s into the clip).
const BLOW_AGAIN := 3.4
## Foam laid every this long (s) where the body cuts the surface.
const FOAM_EVERY := 0.55
## Rings run out from where the tail went under, this many, one every FOAM_EVERY.
const RINGS_OUT := 5
## The near miss: within this many wingspans of the tail; it must be this far
## away again (m) before another pass counts.
const PASS_REACH := 2.5
const PASS_REARM := 45.0
## Under a fluke shedding water the screen is doused this much.
const DOUSE := 0.45
## The sea's hump and shade over the back fade out as it goes this deep (m).
const BACK_DEEP := 9.0
## How strong the sea's hump and shade over it are (the lake fish's is 1).
const OVER := 0.6

var body: Node3D
## Read by drivers and the numbers: staged now, how many so far, where the last
## one was and which way, the last spot's refusal, this frame's cost (ms).
var staged := false
var count := 0
var spot := Vector3.ZERO
var way := Vector3.FORWARD
var refused := ""
var ms := 0.0
var ms_peak := 0.0
var ms_sum := 0.0
var ms_frames := 0
var ms_stage := 0.0
var ms_peak_t := 0.0
var passes := 0
var open_sea := false

var _game: Node3D
var _rng := RandomNumberGenerator.new()
var _now := false
var _cool := FIRST
var _cooldown := COOLDOWN
var _chance := CHANCE
var _retry_for := RETRY
var _read := 0.0
var _stint := 0.0
var _retry := 0.0
var _won := 0.0
var _rate := 1.0
var _foam := 0.0
var _blow: GPUParticles3D
var _sheet: GPUParticles3D
var _spume: GPUParticles3D
var _blown := 0
var _sheeting := false
var _least := INF
var _least_at := Vector3.ZERO
var _armed := true
var _doused := false
var _rings := 0
var _over_on := false
var _level := Field.SEA_Y

static func wanted() -> bool:
	if not bool(preload("res://scripts/endless/world/world_profile.gd").current().layer("whale",true)): return false
	return not ("--whale=0" in LaunchArgs.user_args())

static func _knob(name: String, otherwise: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--whale-"+name+"="): return float(a.get_slice("=",1))
	return otherwise

func setup(game: Node3D, land_seed: int) -> void:
	_game = game
	_rng.seed = hash([land_seed,"whale",Time.get_ticks_usec()])
	_now = "--whale-now" in LaunchArgs.user_args()
	_cooldown = _knob("cooldown",COOLDOWN_NOW if _now else COOLDOWN)
	_cool = _knob("first",0.0 if _now else FIRST)
	_chance = _knob("chance",1.0 if _now else CHANCE)
	_retry_for = _knob("retry",RETRY)
	body = WhaleBody.new()
	body.name = "WhaleBody"
	add_child(body)
	_blow = _emitter(BLOW,4.2,1,true)
	_sheet = _emitter(SHEET,1.6,0,false)
	_spume = _emitter(SPUME,2.4,1,false)

## A spray emitter of the plane's own kind (WaterContact `_emitter`): drops (0)
## or mist (1), a burst or running.
func _emitter(amount: int, life: float, look: int, burst: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 0.75 if burst else 0.0
	p.randomness = 0.3
	p.local_coords = false
	p.fixed_fps = 0
	p.interpolate = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-60,-30,-60),Vector3(120,90,120))
	var process := ShaderMaterial.new()
	process.shader = preload("res://shaders/water_spray_process.gdshader")
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := ShaderMaterial.new()
	draw.shader = preload("res://shaders/water_spray.gdshader")
	draw.set_shader_parameter("kind",look)
	if look == 0:
		draw.set_shader_parameter("opacity",0.9)
		draw.set_shader_parameter("near_fade",Vector2(1.0,4.0))
	else:
		draw.set_shader_parameter("opacity",0.42)
		draw.set_shader_parameter("near_fade",Vector2(4.0,14.0))
		draw.set_shader_parameter("glow",0.5)
		draw.set_shader_parameter("backlight",0.85)
	quad.material = draw
	p.draw_pass_1 = quad
	add_child(p)
	return p

func _send(e: GPUParticles3D, values: Dictionary) -> void:
	var m := e.process_material as ShaderMaterial
	for key: String in values: m.set_shader_parameter(key,values[key])

## One frame (the study's `tick`).
func step(delta: float, game: Node3D) -> void:
	if staged:
		var from := Time.get_ticks_usec()
		_staged_step(delta,game)
		ms = (Time.get_ticks_usec()-from)/1000.0
		if ms > ms_peak: ms_peak_t = body.time()
		ms_peak = maxf(ms_peak,ms)
		ms_sum += ms
		ms_frames += 1
		return
	_cool -= delta
	_read -= delta
	if _read > 0.0: return
	_read = READ
	ms = 0.0
	open_sea = _open(game)
	if not open_sea:
		_stint = 0.0
		return
	_stint += READ
	_retry -= READ
	_won -= READ
	if _cool > 0.0 or _stint < (STINT_NOW if _now else STINT) or (_retry > 0.0 and _won <= 0.0): return
	if _won <= 0.0:
		if _rng.randf() > _chance:
			_retry = _retry_for
			return
		_won = WON_FOR
	var from := Time.get_ticks_usec()
	if _try(game): _won = 0.0
	ms_stage = (Time.get_ticks_usec()-from)/1000.0

## The plane low and fast over deep sea.
func _open(game: Node3D) -> bool:
	if not bool(game.hand_landing.flying()): return false
	var plane = game.plane
	var p: Vector3 = plane.position
	if p.y-Field.SEA_Y > LOW or float(plane.speed) < float(plane.cruise())*FAST: return false
	if game.doors != null and bool(game.doors.holds(p)): return false
	return float(game.field.height(p.x,p.z)) < Field.SEA_Y-DEEP

## A spot ahead of the plane, staged if it is fit. `refused` says why not.
func _try(game: Node3D) -> bool:
	var plane = game.plane
	var p: Vector3 = plane.position
	var v := Vector3(plane.velocity.x,0.0,plane.velocity.z)
	var speed := v.length()
	if speed < 1.0: return false
	var ahead := v/speed
	var right := ahead.cross(Vector3.UP)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var at := p+ahead*clampf(speed*MEET,LEAD.x,LEAD.y)+right*side*_rng.randf_range(OFF.x,OFF.y)
	at.y = Field.SEA_Y
	var heading := ahead.rotated(Vector3.UP,_rng.randf_range(-TURN,TURN))
	refused = _site_refusal(game,at,heading,p)
	if refused != "": return false
	_stage(game,at,heading)
	return true

## Why a whale can't come up at `at` swimming along `heading`, seen from `eye`
## ("" if it can): shallow water or a shore near, the edge's big swell, stone in
## its lane, a ship near, land or stone between it and the plane.
func _site_refusal(game: Node3D, at: Vector3, heading: Vector3, eye: Vector3) -> String:
	var field = game.field
	for r in RINGS:
		for b in (1 if r == 0.0 else 8):
			var q := at+Vector3(sin(b*TAU/8.0),0.0,cos(b*TAU/8.0))*r
			if float(field.height(q.x,q.z)) > Field.SEA_Y-DEEP: return "shore within %d m" % int(r)
	var sea = game.look.water if game.look != null else null
	if sea != null and float(sea.surge_room(at.x,at.z)) > SURGE_MOST: return "the edge's swell"
	var across := heading.cross(Vector3.UP)
	var along := -LANE.x
	while along <= LANE.y:
		for k in [-1.0,0.0,1.0]:
			if _stone(game,at+heading*along+across*k*LANE.z): return "stone in its lane"
		along += LANE.w
	if game.coast != null:
		for ship: Node3D in game.coast.ships:
			if ship != null and Vector2(ship.global_position.x-at.x,ship.global_position.z-at.z).length() < SHIP_CLEAR: return "a ship near"
	for i in range(1,8):
		var q := eye.lerp(at,i/8.0)
		if float(field.height(q.x,q.z)) > Field.SEA_Y-2.0 or _stone(game,Vector3(q.x,Field.SEA_Y,q.z)): return "land on the way"
	return ""

## Anything standing in or over the water at `q` (a rock, an arch, a wreck).
func _stone(game: Node3D, q: Vector3) -> bool:
	var g: Variant = game.plane_ground(Vector3(q.x,Field.SEA_Y+2.0,q.z),0.0)
	if g is Vector2: return true
	return g != null and float(g) > Field.SEA_Y-2.0

## The whale comes up at `at` (on the water), swimming along `heading`.
func _stage(game: Node3D, at: Vector3, heading: Vector3) -> void:
	spot = at
	way = heading
	staged = true
	count += 1
	_rate = 1.0
	_foam = 0.0
	_blown = 0
	_sheeting = false
	_least = INF
	_armed = true
	_doused = false
	_rings = 0
	body.global_transform = Transform3D(Basis.looking_at(heading,Vector3.UP),at)
	_level = Field.SEA_Y+float(game.sea_height(at))
	body.global_position.y = _level
	body.set_effect("surface_y",_level)
	body.set_effect("sheet",0.0)
	body.play()

func _staged_step(delta: float, game: Node3D) -> void:
	var plane = game.plane
	var p: Vector3 = plane.position
	var t: float = body.time()
	var beats: Dictionary = WhaleBody.BEATS
	# The clip's rate: so the flukes stand as the plane arrives.
	var want := 1.0
	if t < float(beats["fluke.up"]):
		var to := Vector3(spot.x-p.x,0.0,spot.z-p.z)
		var dist := to.length()
		var closing: float = Vector3(plane.velocity.x,0.0,plane.velocity.z).dot(to/maxf(dist,0.01))
		if closing > float(plane.speed)*CLOSING: want = clampf((MEET-t)/maxf(dist/closing,0.3),RATE.x,RATE.y)
	_rate = move_toward(_rate,want,RATE_EASE*delta)
	body.advance(delta*_rate)
	var was := t
	t = body.time()
	# It rides the swell where it is.
	_level = lerpf(_level,Field.SEA_Y+float(game.sea_height(Vector3(spot.x,Field.SEA_Y,spot.z))),1.0-exp(-RIDE*delta))
	var level := _level
	body.global_position.y = level
	body.set_effect("surface_y",level)
	# The blows.
	if (_blown == 0 and t >= float(beats.blow)) or (_blown == 1 and t >= BLOW_AGAIN):
		_puff(body.socket(&"blowhole"),1.2 if _blown == 0 else 0.7,level)
		_blown += 1
	# The flukes' water.
	var up: float = beats["fluke.up"]
	var slide: float = beats["fluke.slide"]
	var gone: float = beats.gone
	var shed := smoothstep(up-0.3,up+0.4,t)*(1.0-smoothstep(slide-0.5,gone-1.0,t))
	if shed > 0.01:
		_shed(shed,level,delta)
		_sheeting = true
	elif _sheeting:
		_sheeting = false
		_sheet.emitting = false
		_spume.emitting = false
		body.set_effect("sheet",0.0)
	# The water over it: a hump pushed ahead, the chop stilled, its back dark
	# under the surface (EndlessSea `swimmers`, the lake fish's own slot).
	_over(game,t,level)
	# Foam and rings where it cuts the surface.
	_foam -= delta
	if _foam <= 0.0 and game.water != null:
		_foam = FOAM_EVERY
		_wash(game,t,level)
	if was < slide+1.5 and t >= slide+1.5: _rings = RINGS_OUT
	if t >= WhaleBody.LENGTH:
		_end()
		return
	if t > up-0.5 and t < gone: _pass(game,p,level,shed)

## The sea's shader told where the body lies: its middle, its way, its length,
## how deep its back is (as the lake fish counts depth: the shader's hump and
## shade are whole at 0.6 and gone by 2.4) and how strong.
func _over(game: Node3D, t: float, level: float) -> void:
	var sea = game.look.water if game.look != null else null
	if sea == null: return
	var mid: Vector3 = body.socket(&"root")
	var back := level-(mid.y+WhaleBody.BACK)
	var k := smoothstep(0.0,1.2,t)*(1.0-smoothstep(BACK_DEEP*0.5,BACK_DEEP,back))
	if k <= 0.0:
		if _over_on: _over_off(sea)
		return
	if not _over_on: sea.material.set_shader_parameter("swim_body",0.0)
	_over_on = true
	sea.swimmers(Vector4(mid.x,mid.z,way.x,way.z),Vector4(WhaleBody.LONG,clampf(back,0.0,BACK_DEEP)*2.4/BACK_DEEP,0.0,k*OVER),Vector4.ZERO,Vector4.ZERO,1)

func _over_off(sea: Object) -> void:
	_over_on = false
	sea.swimmers(Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,0)
	sea.material.set_shader_parameter("swim_body",1.0)

## The blow: a tall bushy burst of mist off the blowhole, `k` big.
func _puff(at: Vector3, k: float, level: float) -> void:
	_blow.global_position = Vector3(at.x,maxf(at.y,level+0.3),at.z)
	_send(_blow,{"rate":1.0,"travel":Vector3.ZERO,"ahead":way,"right":way.cross(Vector3.UP),"plane_speed":0.0,
		"carry":Vector2.ZERO,"up_speed":Vector2(9.0,30.0)*k,"side_speed":Vector2(0.0,3.6)*k,"back_speed":Vector2(-2.0,4.0),
		"strength":1.0,"box":Vector3(0.8,0.5,1.0),"size_range":Vector2(2.2,4.6)*k,"growth":2.4,"drag":1.05,
		"gravity":1.6,"buoyancy":0.9,"stretch":0.0,"water_y":level-6.0})
	_blow.restart()
	_blow.emitting = true

## Water off the flukes (`k` 0 to 1): drops from under their whole span, spume
## where the tail stock stands in the sea.
func _shed(k: float, level: float, _delta: float) -> void:
	var root: Vector3 = body.socket(&"fluke")
	var left: Vector3 = body.socket(&"tip_l")
	var right: Vector3 = body.socket(&"tip_r")
	var mid := (left+right)*0.5
	var across := right-left
	var half := across.length()*0.5
	var chord := mid-root
	_sheet.global_position = (mid+root)*0.5
	_send(_sheet,{"rate":clampf(k,0.0,1.0),"travel":Vector3.ZERO,"ahead":chord.normalized(),"right":across.normalized(),"plane_speed":0.0,
		"carry":Vector2.ZERO,"up_speed":Vector2(-2.5,0.5),"side_speed":Vector2(0.0,0.8),"back_speed":Vector2(-0.6,0.6),
		"strength":1.0,"box":Vector3(half,0.3,chord.length()*0.6),"size_range":Vector2(0.09,0.24),"growth":0.2,"drag":0.25,
		"gravity":9.8,"buoyancy":0.0,"stretch":0.07,"water_y":level})
	if not _sheet.emitting: _sheet.emitting = true
	var foot: Vector3 = body.socket(&"tail2")
	_spume.global_position = Vector3(foot.x,level+0.2,foot.z)
	_send(_spume,{"rate":clampf(k*1.2,0.0,1.0),"travel":Vector3.ZERO,"ahead":way,"right":way.cross(Vector3.UP),"plane_speed":0.0,
		"carry":Vector2.ZERO,"up_speed":Vector2(0.5,3.5),"side_speed":Vector2(0.5,3.0),"back_speed":Vector2(-1.5,1.5),
		"strength":1.0,"box":Vector3(4.0,0.2,5.0),"size_range":Vector2(1.2,2.6),"growth":2.2,"drag":1.2,
		"gravity":1.5,"buoyancy":0.8,"stretch":0.0,"water_y":level-3.0})
	if not _spume.emitting: _spume.emitting = true
	body.set_effect("sheet",k)

## Foam where the body cuts the surface now, and the last rings.
func _wash(game: Node3D, t: float, level: float) -> void:
	var water = game.water
	if _rings > 0:
		# Where the tail went under: rings running out one after another, foam left.
		_rings -= 1
		var foot: Vector3 = body.socket(&"tail3")
		foot.y = level
		water.mark(foot,true,0.5,5.0,34.0+3.0*_rings,6.0)
		water.mark(foot+Vector3(_rng.randf_range(-8,8),0,_rng.randf_range(-8,8)),false,0.5,6.0,15.0,7.0)
		if t >= float(WhaleBody.BEATS.gone): return
	for name: StringName in [&"blowhole",&"root",&"lumbar",&"tail1",&"tail2",&"tail3",&"fluke"]:
		var at: Vector3 = body.socket(name)
		# The spine within a body's thickness of the surface: the back awash.
		var reach := 5.0 if name in [&"root",&"lumbar",&"blowhole"] else 3.0
		if at.y < level-reach or at.y > level+reach+1.0: continue
		var k := clampf(1.0-absf(at.y-level)/(reach+1.0),0.3,1.0)
		var size := (7.0 if name in [&"root",&"lumbar"] else 4.5)*_rng.randf_range(0.8,1.2)
		water.mark(Vector3(at.x+_rng.randf_range(-4,4),level,at.z+_rng.randf_range(-4,4)),false,0.5*k,size,size*2.2,4.5)
		if _rng.randf() < 0.35: water.mark(Vector3(at.x,level,at.z),true,0.35*k,size*0.8,size*0.8+14.0,3.5)

## The plane passing the tail: its nearest clearance (off the tail stock's and
## the flukes' own shape), scored once it is going away; under a shedding fluke
## the screen is doused.
func _pass(game: Node3D, p: Vector3, level: float, shed: float) -> void:
	var fluke: Vector3 = body.socket(&"fluke")
	if p.distance_squared_to(fluke) > 90.0*90.0:
		if _least < INF: _score(game)
		_armed = true
		return
	var a: Vector3 = body.socket(&"tail2")
	var b: Vector3 = body.socket(&"tail3")
	var left: Vector3 = body.socket(&"tip_l")
	var right: Vector3 = body.socket(&"tip_r")
	var r: Vector3 = WhaleBody.STOCK_R
	var clear := INF
	if b.y > level: clear = minf(clear,_off(p,a,b,(r.x+r.y)*0.5,level))
	if fluke.y > level: clear = minf(clear,_off(p,b,fluke,(r.y+r.z)*0.5,level))
	if maxf(left.y,fluke.y) > level: clear = minf(clear,_off(p,fluke,left,WhaleBody.LOBE_R,level))
	if maxf(right.y,fluke.y) > level: clear = minf(clear,_off(p,fluke,right,WhaleBody.LOBE_R,level))
	clear -= WorldScale.span*0.5
	# Under a fluke that still sheds: the screen doused, once a pass.
	if shed > 0.3 and not _doused and game.water != null:
		for tip: Vector3 in [left,right]:
			var mid := (tip+fluke)*0.5
			if p.y < mid.y and Vector2(p.x-mid.x,p.z-mid.z).length() < 7.0:
				_doused = true
				game.water.douse(DOUSE*shed)
	if not _armed:
		if clear > PASS_REARM: _armed = true
		return
	if clear < _least:
		_least = clear
		_least_at = p
	elif _least < INF and clear > _least+6.0: _score(game)

## How far `p` is off the capsule `a`-`b` of radius `r` (m), the part of it
## under the water's `level` left out.
func _off(p: Vector3, a: Vector3, b: Vector3, r: float, level: float) -> float:
	if a.y < level and b.y > a.y: a = a.lerp(b,(level-a.y)/(b.y-a.y))
	elif b.y < level and a.y > b.y: b = b.lerp(a,(level-b.y)/(a.y-b.y))
	var ab := b-a
	var k := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-4),0.0,1.0)
	return p.distance_to(a+ab*k)-r

func _score(game: Node3D) -> void:
	var reach := PASS_REACH*WorldScale.span
	if _least < reach and _least > -WorldScale.span and bool(game.hand_landing.flying()):
		passes += 1
		game.near.shot_pass(maxf(_least,0.0),reach,_least_at)
	_least = INF
	_armed = false
	_doused = false

func _end() -> void:
	if _least < INF: _score(_game)
	staged = false
	_cool = _cooldown
	_stint = 0.0
	_sheet.emitting = false
	_spume.emitting = false
	var sea = _game.look.water if _game.look != null else null
	if _over_on and sea != null: _over_off(sea)
	body.stop()

## The numbers' line (--numbers).
func note() -> String:
	return "\nwhale: %s, %d so far, next in %.0f s, open sea %.0f s%s  %.2f ms (peak %.2f, the last staging %.2f)" % ["up" if staged else "none",count,maxf(_cool,0.0),_stint,"" if refused == "" else " ("+refused+")",ms,ms_peak,ms_stage]
