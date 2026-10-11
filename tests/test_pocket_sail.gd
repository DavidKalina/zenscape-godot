extends SceneTree
## The pocket sail (scripts/pocket_sail.gd, flown by scripts/pilot_motor.gd):
## Space again in the air pops it out and it glides about 3 to 4 m on for
## each metre down; its kick comes once an airtime (folded and opened
## again, none), it folds with Space and falls, and opens again only after
## REOPEN; opened early it saves the fall, opened late it barely slows it;
## pace brought into it is kept a while, never over TOP; crouch floats it;
## the wind across carries it and a gust's rise slows its sink, but never
## climbs it over the airtime's peak by more than CEILING; a thermal climbs
## it for real (metres in seconds, over the peak), and out of the column it
## sinks again; landing packs it
## and gives the kick back; a press close over the ground is still the
## jump buffered for the touch; a knock is a fresh airtime. Nothing asks to
## fly. The skydive's sail (scripts/sky_dive.gd) flies the same maths.
##   godot --headless --path . --script tests/test_pocket_sail.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PocketSail = preload("res://scripts/pocket_sail.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const SkyDive = preload("res://scripts/sky_dive.gd")
const DT := 1.0/60.0
var failures := 0
var flew := false
## A cliff: flat at 0 for x under 0, then far down (-400 m).
var cliff := func(p: Vector2) -> float: return 0.0 if p.x < 0.0 else -400.0
var flat := func(p: Vector2) -> float: return 0.0
var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
var _wind := Vector3.ZERO
var _thermal := 0.0
var air := func(_p: Vector3) -> Dictionary: return {"wind":_wind,"thermal":_thermal}

func _initialize() -> void:
	var figure := PilotFigure.new()
	root.add_child(figure)
	var m := PilotMotor.new()
	m.air = air
	# The glide in still air: off the cliff at a run, opened, held on.
	var glide := _glide_off(m,figure,Vector2(1.0,0.0),false,5.0)
	print("MEASURE: still air glide %.2f m on per m down (%.2f m/s across, %.2f m/s down)" % [glide.ratio,glide.across,glide.down])
	check(glide.ratio > 3.0 and glide.ratio < 4.2,"The sail glides 3 to 4 m on for each metre down (%.2f)" % glide.ratio)
	check(absf(glide.down-PocketSail.SINK) < 0.1,"Settled, it sinks at SINK (%.2f m/s)" % glide.down)
	check(not flew,"Nothing in the air asks to fly")
	# Over flat ground a jump (even the pump) has no room for it, and
	# Jump mashed through a long jump does nothing but buffer the next.
	m.reset(Vector3(-20.0,0.0,0.0),0.0)
	_step(m,figure,flat,Vector2.ZERO,false)
	var sailed_low := false
	for k in range(90):
		var out := _step(m,figure,flat,Vector2.ZERO,k%2 == 0)
		sailed_low = sailed_low or out.has("sail")
	check(not sailed_low,"Over flat ground, Jump mashed through jumps never opens it")
	# The kick: jumped off the cliff's edge, at the jump's top over the drop,
	# about 0.3 m more, once an airtime.
	m.reset(Vector3(-0.6,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	_step(m,figure,cliff,Vector2(1.0,0.0),false)
	var top := 0.0
	var i := 0
	_step(m,figure,cliff,Vector2(1.0,0.0),true)
	while m.velocity.y > 0.0 and i < 120:
		_step(m,figure,cliff,Vector2(1.0,0.0),true)
		i += 1
	var at_top := m.feet.y
	var opened := _step(m,figure,cliff,Vector2(1.0,0.0),false)
	opened = _step(m,figure,cliff,Vector2(1.0,0.0),true)
	var kicked := m.velocity.y
	check(opened.get("sail",false) and m.move == "sail","Space again at a jump's top over a drop opens the sail")
	for k in range(24):
		_step(m,figure,cliff,Vector2(1.0,0.0),true)
		top = maxf(top,m.feet.y)
	print("MEASURE: kick at a jump's top to %.2f m/s, %.2f m over the top" % [kicked,top-at_top])
	check(kicked > PocketSail.KICK-1.0 and kicked <= PocketSail.KICK and top-at_top > 0.15 and top-at_top < 0.45,"Its kick lifts him a little (%.2f m/s, %.2f m)" % [kicked,top-at_top])
	# Folded: falls; opened again at once, refused; after REOPEN, no kick.
	var folded := _step(m,figure,cliff,Vector2(1.0,0.0),false)
	folded = _step(m,figure,cliff,Vector2(1.0,0.0),true)
	check(folded.get("sail",true) == false and m.move == "","Space again folds it")
	_step(m,figure,cliff,Vector2(1.0,0.0),false)
	var early := _step(m,figure,cliff,Vector2(1.0,0.0),true)
	check(not early.has("sail") and m.move == "","Pressed again at once (under REOPEN), it stays folded")
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	_until_off(m,figure)
	_air_for(m,figure,0.4,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	_air_for(m,figure,1.0,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	check(m.move == "","Folded over the drop")
	_air_for(m,figure,0.7,Vector2(1.0,0.0))
	var diving := m.velocity.y
	check(diving < -PocketSail.SINK-6.0,"Folded he drops fast (%.2f m/s)" % diving)
	_press(m,figure,Vector2(1.0,0.0))
	var reopened := m.velocity.y
	check(m.move == "sail" and reopened < diving+0.5,"Opened again: no second kick (%.2f to %.2f m/s)" % [diving,reopened])
	_air_for(m,figure,2.5,Vector2(1.0,0.0))
	check(absf(m.velocity.y+PocketSail.SINK) < 0.3,"And it catches the fall (%.2f m/s)" % m.velocity.y)
	# Early saves, late barely slows: off a 40 m drop.
	var early_hit := _drop_and_open(m,figure,0.3)
	var late_hit := _drop_and_open(m,figure,-6.0)
	var never_hit := _drop_and_open(m,figure,INF)
	print("MEASURE: down 40 m, opened at once %.2f m/s at the touch, 6 m over it %.2f, never %.2f" % [early_hit,late_hit,never_hit])
	check(early_hit < PocketSail.SINK+0.3,"Opened early, he touches down soft (%.2f m/s)" % early_hit)
	check(late_hit > 6.0 and late_hit < never_hit,"Opened late, it barely slows the fall (%.2f against %.2f m/s)" % [late_hit,never_hit])
	# Carried pace: a long jump's 10 m/s kept a while, never past TOP.
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),10.0)
	m.velocity = Vector3(10.0,0.0,0.0)
	_until_off(m,figure,10.0)
	_air_for(m,figure,0.2,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	var carried := m.speed()
	_air_for(m,figure,1.0,Vector2(1.0,0.0))
	var after := m.speed()
	_air_for(m,figure,6.0,Vector2(1.0,0.0))
	print("MEASURE: carried pace %.2f m/s at the open, %.2f a second on, %.2f after 7 s" % [carried,after,m.speed()])
	check(carried > 9.5 and carried <= PocketSail.TOP+0.01 and after > 8.0,"Pace brought into it is kept a while (%.2f, %.2f m/s)" % [carried,after])
	check(absf(m.speed()-PocketSail.PACE) < 0.3,"Then bleeds back to its cruise (%.2f m/s)" % m.speed())
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),20.0)
	m.velocity = Vector3(20.0,0.0,0.0)
	_until_off(m,figure,20.0)
	_air_for(m,figure,0.3,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	_air_for(m,figure,0.1,Vector2(1.0,0.0))
	check(m.speed() <= PocketSail.TOP+0.01,"Never over TOP (%.2f m/s)" % m.speed())
	# Crouch floats it: slower across, slower down.
	var braked := _glide_off(m,figure,Vector2(1.0,0.0),true,5.0)
	check(braked.down < glide.down-0.15 and braked.across < glide.across-1.5,"Crouched it floats: %.2f m/s down, %.2f across" % [braked.down,braked.across])
	# Steered: it turns towards the stick.
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	_until_off(m,figure)
	_air_for(m,figure,0.3,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	_air_for(m,figure,2.0,Vector2(0.0,1.0))
	check(m.velocity.z > PocketSail.PACE*0.9 and absf(m.velocity.x) < 1.0,"The stick steers it round (%.2f, %.2f)" % [m.velocity.x,m.velocity.z])
	# The wind across carries it.
	var still := _glide_off(m,figure,Vector2(1.0,0.0),false,3.0)
	_wind = Vector3(0.0,0.0,4.0)
	var gusted := _glide_off(m,figure,Vector2(1.0,0.0),false,3.0)
	_wind = Vector3.ZERO
	var pushed: float = gusted.feet.z-still.feet.z
	print("MEASURE: a 4 m/s wind across carries it %.2f m sideways in 3 s" % pushed)
	check(pushed > 6.0,"A wind across carries it (%.2f m)" % pushed)
	# Air rising: slows the sink, lifts a little, never over the peak.
	_wind = Vector3(0.0,2.0,0.0)
	var held := _glide_off(m,figure,Vector2(1.0,0.0),false,3.0)
	_wind = Vector3.ZERO
	check(held.down < PocketSail.SINK*0.5,"Rising air slows its sink (%.2f m/s down)" % held.down)
	# A gust's rise past the peak: held under it by CEILING.
	_wind = Vector3(0.0,6.0,0.0)
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	_until_off(m,figure)
	var gust_peak := m.feet.y
	_air_for(m,figure,0.3,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	var gust_high := -INF
	for k in range(60*10):
		_step(m,figure,cliff,Vector2(1.0,0.0),false)
		gust_high = maxf(gust_high,m.feet.y)
	_wind = Vector3.ZERO
	print("MEASURE: in a gust's strong rise for 10 s: %.2f m over the airtime's peak at most" % (gust_high-gust_peak))
	check(gust_high <= gust_peak+PocketSail.CEILING+0.05,"A gust's rise never lifts it over the airtime's peak by more than CEILING (%.2f m)" % (gust_high-gust_peak))
	# A thermal: climbs it for real, metres in a few seconds, over the peak.
	_thermal = 3.0
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	_until_off(m,figure)
	var peak := m.feet.y
	_air_for(m,figure,0.3,Vector2(1.0,0.0))
	_press(m,figure,Vector2(1.0,0.0))
	var opened_at := m.feet.y
	for k in range(60*4): _step(m,figure,cliff,Vector2(1.0,0.0),false)
	var climbed := m.feet.y-opened_at
	print("MEASURE: a 3.0 thermal for 4 s: climbed %.2f m (%.2f m over the airtime's peak), %.2f m/s up, riding %s" % [climbed,m.feet.y-peak,m.velocity.y,m.sail.riding])
	check(climbed > 8.0,"A thermal climbs the sail several metres in a few seconds (%.2f m in 4 s)" % climbed)
	check(m.feet.y > peak+5.0,"Over the airtime's peak, with no ceiling (%.2f m over)" % (m.feet.y-peak))
	check(m.sail.riding and m.velocity.y > 2.0,"Riding it, climbing (%.2f m/s)" % m.velocity.y)
	check(m.velocity.y <= PocketSail.THERMAL_MOST+0.01,"Never faster than THERMAL_MOST")
	# Out of the column it sinks again, at its sink.
	_thermal = 0.0
	var left_at := m.feet.y
	for k in range(60*4): _step(m,figure,cliff,Vector2(1.0,0.0),false)
	print("MEASURE: 4 s out of the thermal: %+.2f m, %.2f m/s" % [m.feet.y-left_at,m.velocity.y])
	check(m.feet.y < left_at-3.0 and absf(m.velocity.y+PocketSail.SINK) < 0.1 and not m.sail.riding,"Out of it, it sinks again at SINK (%.2f m/s)" % m.velocity.y)
	# Landing packs it, and gives the kick back: off a 10 m step.
	var step := func(p: Vector2) -> float: return 0.0 if p.x < 0.0 else -10.0
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	for k in range(120):
		_step(m,figure,step,Vector2(1.0,0.0),false)
		if not m.grounded: break
	for k in range(18): _step(m,figure,step,Vector2(1.0,0.0),false)
	_press(m,figure,Vector2(1.0,0.0),step)
	check(m.move == "sail","Off a 10 m step, it opens")
	var landed := {}
	for k in range(600):
		var out := _step(m,figure,step,Vector2(1.0,0.0),false)
		if out.has("landed"):
			landed = out
			break
	check(not landed.is_empty() and landed.get("sail",true) == false and m.move == "" and not m.sail.kicked and not m.sail.open,"Landing packs it, the kick ready again")
	check(float(landed.get("landed",99.0)) < PocketSail.SINK+0.5,"And it touches down soft (%.2f m/s)" % float(landed.get("landed",99.0)))
	# A press close over the ground falling is still the buffered jump.
	m.reset(Vector3(-20.0,0.0,0.0),0.0)
	_step(m,figure,flat,Vector2.ZERO,false)
	var jumped := 0
	var sailed := false
	var press := true
	for k in range(240):
		var near: bool = m.velocity.y < -1.0 and m.feet.y < 0.6
		var out := _step(m,figure,flat,Vector2.ZERO,press or near)
		press = press and not m.grounded and m.velocity.y > 0.0
		sailed = sailed or out.has("sail")
		if out.has("jumped"):
			jumped += 1
			if jumped == 2: break
	check(jumped == 2 and not sailed,"Pressed just over the ground falling, it jumps on the touch, no sail")
	# Knocked: a fresh airtime, the kick ready.
	m.reset(Vector3(-20.0,0.0,0.0),0.0)
	_step(m,figure,flat,Vector2.ZERO,false)
	m.knock(Vector3(6.0,12.0,0.0))
	check(not m.grounded and m.velocity.y > 11.0,"A knock throws him up and out")
	for k in range(15): _step(m,figure,flat,Vector2.ZERO,false)
	var knocked := _step(m,figure,flat,Vector2.ZERO,true)
	check(knocked.get("sail",false) and m.sail.kicked,"And the sail opens out of it with its kick")
	# The skydive flies the same sail.
	var dive := SkyDive.new()
	var no_ground := func(_p: Vector3) -> Variant: return null
	dive.drop(Vector3(0.0,300.0,0.0),0.0,8.0)
	for k in range(30): dive.fall(DT,{},no_ground)
	dive.fall(DT,{"open":true},no_ground)
	check(dive.sailing(),"Out of the plane, Jump opens the same sail")
	for k in range(60*6): dive.fall(DT,{},no_ground)
	var d_across := Vector2(dive.velocity.x,dive.velocity.z).length()
	var d_ratio := d_across/maxf(-dive.velocity.y,0.01)
	check(absf(d_ratio-glide.ratio) < 0.4,"With the walker's glide (%.2f against %.2f)" % [d_ratio,glide.ratio])
	figure.free()
	print("PASS: pocket sail" if failures == 0 else "FAIL: pocket sail")
	quit(1 if failures else 0)

func _step(m: RefCounted, figure: Node3D, ground: Callable, want: Vector2, jump: bool) -> Dictionary:
	var out: Dictionary = m.step(DT,want,PilotMotor.RUN,jump,ground,slide)
	figure.drive(m,DT)
	flew = flew or out.has("fly")
	return out

## A tap of Space in the air (pressed, then let go).
func _press(m: RefCounted, figure: Node3D, want: Vector2, ground := cliff) -> void:
	_step(m,figure,ground,want,true)
	_step(m,figure,ground,want,false)

func _air_for(m: RefCounted, figure: Node3D, seconds: float, want: Vector2) -> void:
	for k in range(int(seconds*60.0)): _step(m,figure,cliff,want,false)

## Run on +x until he is off the cliff's edge.
func _until_off(m: RefCounted, figure: Node3D, top := PilotMotor.RUN) -> void:
	for k in range(120):
		m.step(DT,Vector2(1.0,0.0),top,false,cliff,slide)
		if not m.grounded: return

## Off the cliff at a run, the sail opened 0.3 s on, held along `want`
## (crouched or not) for `seconds` past a settling second: across and down
## (m/s) and the ratio over that stretch, and where the feet ended.
func _glide_off(m: RefCounted, figure: Node3D, want: Vector2, crouched: bool, seconds: float) -> Dictionary:
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.crouch = false
	_until_off(m,figure)
	_air_for(m,figure,0.3,want)
	_press(m,figure,want)
	m.crouch = crouched
	_air_for(m,figure,1.5,want)
	var from: Vector3 = m.feet
	_air_for(m,figure,seconds,want)
	m.crouch = false
	var across := Vector2(m.feet.x-from.x,m.feet.z-from.z).length()
	var down: float = from.y-m.feet.y
	return {"ratio":across/maxf(down,0.001),"across":across/seconds,"down":down/seconds,"feet":m.feet}

## Off a 40 m drop (ground at -40 past x 0), the sail opened `when`: s
## after the edge, or (negative) that many metres over the ground; INF
## never. How fast he comes down at the touch (m/s).
func _drop_and_open(m: RefCounted, figure: Node3D, when: float) -> float:
	var drop := func(p: Vector2) -> float: return 0.0 if p.x < 0.0 else -40.0
	m.reset(Vector3(-1.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	for k in range(120):
		m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,false,drop,slide)
		if not m.grounded: break
	var t := 0.0
	var jump := false
	for k in range(60*60):
		var due: bool = (when >= 0.0 and t >= when) or (when < 0.0 and m.feet.y < -40.0-when)
		jump = due and m.move != "sail" and not jump
		var fell: float = -m.velocity.y
		var out: Dictionary = m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,jump,drop,slide)
		figure.drive(m,DT)
		t += DT
		if out.has("landed"): return maxf(float(out.landed),fell)
	return INF

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ")+what)
	if not ok: failures += 1
