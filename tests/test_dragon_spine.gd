extends SceneTree
## The sky dragon's body in flight (scripts/dragon_spine.gd, docs/design/
## dragon-spine/round1.md), headless: beating, the chest heaves and the
## motion reaches the neck's end and the hips late (follow-through); the
## head is steadier than the neck carrying it; turning, the spine bends into
## the turn, the hips and tail the other way about (a curve, not a hinge);
## diving he tucks; climbing he beats bigger; levelling out he flares;
## gliding the body still shifts a little; unstepped a while it starts from
## rest; nothing bends past a weighty bound.
##   godot --headless --path . --script tests/test_dragon_spine.gd
const DragonSpine = preload("res://scripts/dragon_spine.gd")
const NECK := ["chest","spine.2","neck.0","neck.1","neck.2","neck.3"]
const DT := 1.0/60.0
const HZ := 0.3

var failures := 0
var _clock := 0.0
var _phase := 0.0

func _initialize() -> void:
	var s := DragonSpine.new()
	# Beating level: settle, then one beat sampled.
	_fly(s,20.0,1.0,0.0,0.0)
	var chest_at := {}
	var tip_at := {}
	var hips_at := {}
	var head_pp := Vector2(INF,-INF)
	var tip_pp := Vector2(INF,-INF)
	var most := 0.0
	var steps := int(1.0/HZ/DT)
	for i in steps:
		_fly(s,DT,1.0,0.0,0.0)
		var tip := _world(s,"neck.3")
		var head := tip+s.head_steady.x
		_peak(chest_at,s.turn_of("chest").x,_phase)
		_peak(tip_at,-tip,_phase)
		_peak(hips_at,s.turn_of("hips").x,_phase)
		tip_pp = Vector2(minf(tip_pp.x,tip),maxf(tip_pp.y,tip))
		head_pp = Vector2(minf(head_pp.x,head),maxf(head_pp.y,head))
		for b: String in NECK+["hips"]: most = maxf(most,absf(s.turn_of(b).x))
	# The chest's lowest (nose down) comes from the downstroke.
	var chest_swing := float(chest_at.most)-float(chest_at.least)
	check(chest_swing > 0.05,"beating, the chest heaves with each stroke (%.3f rad)" % chest_swing)
	var chest_low := float(chest_at.least_at)
	var lag_hips := fposmod(float(hips_at.least_at)-chest_low,1.0)
	check(lag_hips > 0.02 and lag_hips < 0.5,"the hips lag the chest (%.2f of a beat)" % lag_hips)
	var lag_tip := fposmod(float(tip_at.most_at)-chest_low,1.0)
	check(lag_tip > 0.02 and lag_tip < 0.6,"the neck's end dips after the chest (%.2f of a beat)" % lag_tip)
	check(head_pp.y-head_pp.x < (tip_pp.y-tip_pp.x)*0.5,"the head is steadier than the neck carrying it (%.3f against %.3f rad)" % [head_pp.y-head_pp.x,tip_pp.y-tip_pp.x])
	check(most < 0.35,"no bone of the chain bends past 0.35 rad a beat (%.3f)" % most)
	# Turning left: the front into it, the hips and tail curled in too.
	_fly(s,8.0,1.0,0.0,1.0)
	var chest_yaw := s.turn_of("chest").y
	var hips_yaw := s.turn_of("hips").y
	check(chest_yaw > 0.05 and s.turn_of("spine.2").y > 0.03 and s.turn_of("neck.1").y > 0.02,"turning left, the chest, spine and neck bend left (%.3f, %.3f, %.3f)" % [chest_yaw,s.turn_of("spine.2").y,s.turn_of("neck.1").y])
	check(hips_yaw < -0.1 and s.tail_curl < 0.0,"and the hips and tail curl in on the same side (%.3f, %.3f a segment)" % [hips_yaw,s.tail_curl])
	check(s.leg.y > 0.05,"the legs swing out of the turn (%.3f)" % s.leg.y)
	# Weighty: half a second into the opposite turn the bend has not flipped.
	_fly(s,0.5,1.0,0.0,-1.0)
	check(s.turn_of("chest").y > 0.0,"the bend eases out over the turn's change, it doesn't snap (%.3f)" % s.turn_of("chest").y)
	# Diving: tucked.
	_fly(s,10.0,0.0,-0.55,0.0)
	check(s.neck_s < 0.4 and s.head_level < 0.4,"diving, the neck straightens and the head lines up (S %.2f, level %.2f)" % [s.neck_s,s.head_level])
	check(s.leg.x < -0.2 and s.fold > 0.2 and s.sweep > 0.05,"the legs draw up and the wings fold back (legs %.2f, fold %.2f, sweep %.2f)" % [s.leg.x,s.fold,s.sweep])
	# Levelling out: the flare.
	var flared := 0.0
	var sweep_least := 0.0
	for i in range(int(1.6/DT)):
		_fly(s,DT,0.0,lerpf(-0.55,0.0,float(i)*DT/1.6),0.0)
		flared = maxf(flared,s.flare)
		sweep_least = minf(sweep_least,s.sweep)
	check(flared > 0.3 and sweep_least < 0.0,"pulling out of the dive he flares, wings cupped forward (%.2f, sweep %.2f)" % [flared,sweep_least])
	# Climbing: bigger beats, the chest up.
	_fly(s,12.0,1.0,0.42,0.0)
	check(s.beat_gain > 1.15 and s.climb > 0.8,"climbing, the beats are bigger (gain %.2f)" % s.beat_gain)
	# Gliding: alive, but small.
	_fly(s,10.0,0.0,0.0,0.0)
	var glide := Vector2(INF,-INF)
	for i in range(int(12.0/DT)):
		_step(s,DT,0.0,0.0,0.0,0.03*sin(_clock*0.5),0.0)
		var c := s.turn_of("chest").x
		glide = Vector2(minf(glide.x,c),maxf(glide.y,c))
	check(glide.y-glide.x > 0.01 and glide.y-glide.x < 0.15,"gliding, the spine shifts a little against the air (%.3f rad)" % (glide.y-glide.x))
	# Unstepped a while (clinging, asleep): from rest again.
	_fly(s,4.0,1.0,0.0,1.0)
	_clock += 5.0
	_step(s,DT,0.0,0.0,0.0,0.0,0.0)
	check(absf(s.turn_of("hips").y) < 0.01,"stepped again after a gap, it starts from rest (%.3f)" % s.turn_of("hips").y)
	print("PASS: dragon spine" if failures == 0 else "FAIL: dragon spine (%d)" % failures)
	quit(1 if failures else 0)

func _fly(s: RefCounted, seconds: float, flap_w: float, gamma: float, turning: float) -> void:
	for i in range(maxi(1,int(round(seconds/DT)))): _step(s,DT,flap_w,gamma,turning,0.0,0.0)

func _step(s: RefCounted, dt: float, flap_w: float, gamma: float, turning: float, air_pitch: float, air_roll: float) -> void:
	_clock += dt
	if flap_w > 0.0: _phase = fposmod(_phase+dt*HZ,1.0)
	var bob := -2.2*cos(TAU*_phase)*flap_w
	s.step(dt,_clock,_phase,0.5,flap_w,gamma,turning,air_pitch,air_roll,bob)

## A chain bone's pitch against the body: the turns down to it.
func _world(s: RefCounted, b: String) -> float:
	var sum := 0.0
	for n: String in NECK:
		sum += s.turn_of(n).x
		if n == b: break
	return sum

func _peak(d: Dictionary, v: float, at: float) -> void:
	if v > float(d.get("most",-INF)):
		d.most = v
		d.most_at = at
	if v < float(d.get("least",INF)):
		d.least = v
		d.least_at = at

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)
