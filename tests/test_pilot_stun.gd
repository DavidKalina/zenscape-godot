extends SceneTree
## The stun (scripts/pilot_motor.gd's header; docs/design/roguelike/
## stun-round1.md), on the motor at the wanderer's size, drawn by the
## figure so its ragdoll runs through every state:
##   - a fall of the stun's height or more lays him down, longer for a
##     bigger fall, capped; under it, no stun;
##   - the sail's landing, deep water and the slam never stun;
##   - the twirl pressed with the touch close is the roll: no stun, his
##     pace kept; pressed early with the twirl spent, it is locked out and
##     he is laid down;
##   - knocked into the air, no sail, twirl or steer till his poise is
##     back ("poised"), then the sail opens; a bigger blow, longer;
##   - landed before his poise, he is laid down;
##   - a stunned body tossed (a launcher) stays stunned;
##   - one source can't stun him again within its gap (a throw only), a
##     second source can; past the chain's cap a press breaks out;
##   - with `tech` on, a press just before the floor is the roll, into a
##     wall the kick off it; mashed, it is locked out.
## Flat at 0, a wall 5 m tall west of x -10.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const DT := 1.0/60.0
var failures := 0
## Flat at 0 from x -10 to 40 (a 5 m wall west of it); a pool 3 m deep at x 30..40 (z > 20); the void
## east of x 40.
var ground := func(p: Vector2) -> float:
	if p.x < -10.0: return 5.0
	return 0.0 if p.x <= 40.0 else -INF
var water := func(p: Vector2) -> float:
	return 3.0 if p.x > 30.0 and p.x <= 40.0 and p.y > 20.0 else 0.0
var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
var figure: Node3D

func _initialize() -> void:
	figure = PilotFigure.new()
	root.add_child(figure)
	var m := PilotMotor.new()
	m.set_size(WorldScale.wanderer)
	m.water = water
	var at := m.fall_stun_height()
	check(absf(at-PilotMotor.FALL_STUN_PUMPS*float(m.jumps[1])) < 1e-4,"The stun's fall is %.1f pumps of his (%.2f m)" % [PilotMotor.FALL_STUN_PUMPS,at])
	# The fall stun.
	var under := _drop(m,at*0.9)
	check(not under.has("stunned") and m.move != "tumble","A fall under it (%.1f m) is a landing" % (at*0.9))
	var just := _drop(m,at+0.2)
	check(just.get("stunned","") == "fall" and m.downed(),"A fall of %.1f m lays him down" % (at+0.2))
	var t_just := _until_up(m)
	var big := _drop(m,at*1.6)
	var t_big := _until_up(m)
	_drop(m,at*4.0)
	var t_huge := _until_up(m)
	check(t_big > t_just+0.2,"Longer down for a bigger fall (%.2f s, %.2f s)" % [t_just,t_big])
	check(absf(t_huge-PilotMotor.STUN_DOWN.y) < 0.1 and big.has("downed"),"Capped (%.2f s from %.1f m)" % [t_huge,at*4.0])
	# Never from the sail, deep water or the slam.
	m.reset(Vector3(0.0,at*2.0,0.0),0.0)
	m.grounded = false
	var sailed := {}
	for i in range(900):
		var out := _step(m,Vector2.ZERO,i == 10)
		sailed.merge(out,true)
		if m.grounded: break
	check(sailed.get("sail",false) == false and not sailed.has("stunned") and m.move != "tumble","Sailed down from %.1f m, no stun" % (at*2.0))
	m.reset(Vector3(35.0,at*2.0,25.0),0.0)
	m.grounded = false
	var swum := {}
	for i in range(300):
		swum.merge(_step(m,Vector2.ZERO,false),true)
		if m.swimming: break
	check(m.swimming and not swum.has("stunned"),"Into deep water from %.1f m: a swim" % (at*2.0))
	m.reset(Vector3(0.0,at*1.5,0.0),0.0)
	m.grounded = false
	m.slam(24.0,15.0)
	var slammed := {}
	for i in range(300):
		slammed.merge(_step(m,Vector2.ZERO,false),true)
		if m.grounded: break
	check(slammed.has("slammed") and not slammed.has("stunned") and m.move != "tumble","The slam's landing is his own: no stun")
	# The roll.
	m.reset(Vector3(0.0,at*1.5,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),0.0)
	m.grounded = false
	m.velocity = Vector3(5.0,0.0,0.0)
	var rolled := {}
	for i in range(600):
		var close := m.velocity.y < 0.0 and m.feet.y < -m.velocity.y*m.tech_window*0.6
		m.twirl = close and not rolled.has("roll_ready")
		var out := _step(m,Vector2.ZERO,false)
		rolled.merge(out,true)
		if m.grounded: break
	m.twirl = false
	check(rolled.has("rolled") and not rolled.has("stunned") and m.move == "roll","Twirl pressed just before the touch: the roll, no stun")
	check(m.speed() > 4.5,"The roll keeps his pace (%.2f m/s)" % m.speed())
	for i in range(30): _step(m,Vector2.ZERO,false)
	check(m.move == "","Then he runs on")
	m.reset(Vector3(0.0,at*2.0,0.0),0.0)
	m.grounded = false
	var early := {}
	var twirls := 0
	for i in range(600):
		var t := i*DT
		# Twirled at once (spent), then pressed well before the touch, then
		# again just before it: the early press locks the late one out.
		m.twirl = i == 1 or (m.velocity.y < -10.0 and m.feet.y < 4.0 and m.feet.y > 3.0) or (m.velocity.y < 0.0 and m.feet.y < 0.5)
		var out := _step(m,Vector2.ZERO,false)
		m.twirl = false
		_step_release()
		if out.has("twirl"): twirls += 1
		early.merge(out,true)
		if m.grounded: break
	check(twirls == 1 and early.get("stunned","") == "fall","Spent and pressed early, the late press is locked out: laid down")
	# Poise.
	m.reset(Vector3(0.0,0.0,0.0),0.0)
	_step(m,Vector2.ZERO,false)
	var v := m.knock_velocity(Vector2(1.0,0.0),6.0,2.0)
	m.knock(v)
	var p := m.poise_for(v)
	check(p >= PilotMotor.POISE and p <= PilotMotor.POISE_MOST,"Knocked at %.1f m/s: %.2f s without poise" % [v.length(),p])
	check(m.poise_for(v*2.0) > p,"A bigger blow, longer")
	m.reset(Vector3(39.5,0.0,0.0),PilotMotor.facing_of(Vector2(-1.0,0.0)))
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(6.0,6.0,0.0))
	var steered := m.velocity
	var spun := 0.0
	var poised_at := -1.0
	var opened := -1.0
	var early_sail := false
	for i in range(240):
		var out := _step(m,Vector2(-1.0,0.0),i % 2 == 0)
		if out.get("sail",false):
			if poised_at < 0.0: early_sail = true
			if opened < 0.0: opened = i*DT
		if out.has("poised"): poised_at = i*DT
		if poised_at < 0.0: spun = maxf(spun,(figure._rag as Quaternion).get_angle())
		if poised_at < 0.0 and m.move == "tumble": check_quiet(absf(m.velocity.x-steered.x) < 1e-4,"no steer stunned")
		if opened >= 0.0: break
	check(not early_sail and poised_at > 0.0 and absf(poised_at-m.poise_for(Vector3(6.0,6.0,0.0))) < 0.05,"No sail till his poise is back (poised at %.2f s)" % poised_at)
	check(spun > 2.0,"Drawn tumbling with the throw (%.1f rad round)" % spun)
	check(opened >= poised_at and opened < poised_at+0.1,"Then the sail opens (%.2f s)" % opened)
	# Landed stunned.
	m.reset(Vector3.ZERO,0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(2.0,2.0,0.0))
	var hit := {}
	for i in range(120):
		hit.merge(_step(m,Vector2.ZERO,false),true)
		if m.grounded: break
	check(m.downed() and hit.has("downed") and not hit.has("poised"),"Landed before his poise: laid down")
	for i in range(12): _step(m,Vector2.ZERO,false)
	var lying: Vector3 = figure._rag*Vector3.UP
	check(absf(lying.y) < 0.35 and figure._dizzy.visible,"Drawn lying flat (up %.2f), the dizzy over his head" % lying.y)
	check(_until_up(m) > PilotMotor.TUMBLE_DOWN-0.3,"Then up")
	# A hard hit (`down`, a blast's throw): no poise back in a long throw,
	# laid down `down` s from where his skid stops.
	m.reset(Vector3.ZERO,0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(0.0,20.0,18.0),null,1.2)
	var hard := {}
	var aloft := 0.0
	for i in range(600):
		hard.merge(_step(m,Vector2(-1.0,0.0),i % 2 == 0),true)
		if m.grounded: break
		aloft += DT
	check(aloft > PilotMotor.POISE_MOST and not hard.has("poised") and not hard.has("sail") and hard.has("downed"),"A hard hit: stunned the whole throw (%.2f s up), then laid down" % aloft)
	var skid := 0.0
	while m.speed() >= 0.5 and m.move == "tumble" and skid < 5.0:
		_step(m,Vector2.ZERO,false)
		skid += DT
	# Mashed past the chain's cap: no getting up early from a hard hit.
	var hard_up := 0.0
	while m.move == "tumble" and hard_up < 10.0:
		m.twirl = int(hard_up/DT) % 2 == 0
		_step(m,Vector2.ZERO,false)
		hard_up += DT
	m.twirl = false
	check(skid > 0.8 and absf(hard_up-1.2) < 0.1,"Down for the hit's time once his %.2f s skid stops, mashed (%.2f s)" % [skid,hard_up])
	for i in range(int(PilotMotor.STUN_CALM/DT)+5): _step(m,Vector2.ZERO,false)
	m.knock(Vector3(1.0,1.0,0.0),Node.new())
	for i in range(120):
		_step(m,Vector2.ZERO,false)
		if m.grounded: break
	check(absf(_until_up(m)-PilotMotor.TUMBLE_DOWN) < 0.1,"The next plain knock is plain again")
	# Tossed stunned.
	m.reset(Vector3.ZERO,0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(1.0,1.0,0.0))
	for i in range(60):
		_step(m,Vector2.ZERO,false)
		if m.grounded: break
	m.toss(Vector3(0.0,12.0,0.0))
	check(m.move == "tumble" and not m.grounded and m.velocity.y > 11.0,"A stunned body tossed is thrown, still stunned")
	# The lock's guards.
	var a := Node.new()
	var b := Node.new()
	m.reset(Vector3.ZERO,0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(0.0,3.0,0.0),a)
	_step(m,Vector2.ZERO,false)
	check(not m.stunnable(a) and m.stunnable(b),"One source can't stun him again at once; another can")
	var knocks := m.knocks
	m.knock(Vector3(3.0,3.0,0.0),a)
	check(m.knocks == knocks+1 and m.move == "tumble" and m.velocity.x > 2.9,"Its blow still throws him")
	for i in range(int(PilotMotor.RESTUN_GAP/DT)+2): _step(m,Vector2.ZERO,false)
	check(m.stunnable(a) or m._stunned_for >= m.stun_chain_cap,"After its gap it can again")
	# Past the cap a press breaks out.
	m.reset(Vector3.ZERO,0.0)
	_step(m,Vector2.ZERO,false)
	m.stun_down = Vector2(20.0,20.0)
	m.tumble_down = 20.0
	m.knock(Vector3(0.0,2.0,0.0),a)
	for i in range(int((PilotMotor.STUN_CHAIN_CAP+0.2)/DT)): _step(m,Vector2.ZERO,false)
	check(m.downed(),"Held down past the cap by a long stun")
	m.twirl = true
	var broke := _step(m,Vector2.ZERO,false)
	m.twirl = false
	_step_release()
	check(broke.has("got_up") and not m.downed(),"Past the chain's cap a press breaks out")
	m.stun_down = PilotMotor.STUN_DOWN
	m.tumble_down = PilotMotor.TUMBLE_DOWN
	# The timed press (off by default).
	check(not m.tech,"The timed press is off by default")
	m.tech = true
	# The floor: pressed just before the touch, the roll.
	m.reset(Vector3(0.0,0.0,0.0),0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(1.0,5.0,0.0))
	var teched := {}
	var pressed_tech := false
	for i in range(240):
		m.twirl = not pressed_tech and m.velocity.y < 0.0 and m.feet.y < -m.velocity.y*m.tech_window*0.5
		pressed_tech = pressed_tech or m.twirl
		teched.merge(_step(m,Vector2.ZERO,false),true)
		if m.grounded: break
	m.twirl = false
	check(teched.get("teched","") == "land" and m.move == "roll" and not m.downed(),"Tech on: pressed just before the floor, the roll, no time down")
	# Mashed: locked out.
	m.reset(Vector3(0.0,0.0,0.0),0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(1.0,5.0,0.0))
	var mashed := {}
	for i in range(240):
		m.twirl = i % 6 < 3
		mashed.merge(_step(m,Vector2.ZERO,false),true)
		if m.grounded: break
	m.twirl = false
	check(not mashed.has("teched") and m.downed(),"Mashed, the tech is locked out: laid down")
	# A wall: kicked off it.
	m.reset(Vector3(-8.0,0.0,0.0),0.0)
	_step(m,Vector2.ZERO,false)
	m.knock(Vector3(-6.0,4.0,0.0))
	var walled := {}
	pressed_tech = false
	for i in range(120):
		m.twirl = not pressed_tech and m.feet.x < -9.3
		pressed_tech = pressed_tech or m.twirl
		walled.merge(_step(m,Vector2.ZERO,false),true)
		if walled.has("teched") or m.grounded: break
	m.twirl = false
	check(walled.get("teched","") == "wall" and m.move == "kick" and m.velocity.x > 1.0,"Tech on: pressed into a wall, kicked off it")
	m.tech = false
	a.free()
	b.free()
	print("PASS: pilot stun" if failures == 0 else "FAIL: pilot stun (%d)" % failures)
	quit(1 if failures else 0)

## Dropped from `h` m over the flat, standing still: the landing's events.
func _drop(m: PilotMotor, h: float) -> Dictionary:
	m.reset(Vector3(0.0,h,0.0),0.0)
	m.grounded = false
	for i in range(900):
		var out := _step(m,Vector2.ZERO,false)
		if out.has("landed"): return out
	return {}

## Seconds till he is up (move "tumble" over).
func _until_up(m: PilotMotor) -> float:
	var t := 0.0
	while m.move == "tumble" and t < 10.0:
		_step(m,Vector2.ZERO,false)
		t += DT
	return t

func _step(m: PilotMotor, want: Vector2, jump: bool) -> Dictionary:
	var out := m.step(DT,want,m.run,jump,ground,slide)
	figure.drive(m,DT)
	return out

func _step_release() -> void:
	pass

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ")+what)
	if not ok: failures += 1

var _quiet_failed := {}
func check_quiet(ok: bool, what: String) -> void:
	if ok or _quiet_failed.has(what): return
	_quiet_failed[what] = true
	check(false,what)
