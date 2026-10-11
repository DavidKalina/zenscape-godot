extends SceneTree
## The hand-flown landing (scripts/manual_landing.gd) and its study
## (studies/landing_study.tscn), headless:
##   - the touch's grade: slow, shallow, level is a greaser; within round
##     1's limits firm; fast hot, steep or nose first hard, a wing low
##     wingtip, all of which stick; mid barrel roll or onto rough ground
##     hops;
##   - a greaser settles, rolls out straight and tidy under the brakes and
##     stops; stopped, it stays stopped until Exit is asked (never out by
##     itself); Exit in the air or rolling is refused; once stopped it gets
##     out;
##   - a hot touch at cruise or boost, and a hard one nosed down at cruise,
##     stick: a thump and a little hop that stays on the wheels, never a
##     bounce, never into the ground; a barrel roll into the ground hops and
##     rights itself, still flying;
##   - round 3: a near-vertical slam and a steep dive bounce ("slam"), the
##     wings level and the nose up, flying on, never into the ground, and
##     let go they come back down and stick; a power dive flared on its last
##     frames (a flick of the nose) still bounces; a dive pulled out of in
##     time sticks;
##   - round 3: stopped, Brake held backs it up and the stick turns it as a
##     car backs; let go it stops; it never backs off the land; Brake, Boost
##     and the stick pivot it stopped; rolled into a wall it stops, the
##     throttle and the stick turn it away, and backed up it is free; stuck
##     in something it can always move out;
##   - round 3: steering a slide bends its line, into it tighter and against
##     it wider, and the power-slide still stops shorter than a brake;
##   - steering hard at speed, or the lean with a turn, breaks it loose into
##     a slide that sprays grit; let go, it grips again; a power-slide stops
##     shorter than a straight brake, and a braked slide in between;
##   - slid off the land's edge it flies on with its speed; Boost on the
##     roll lifts off again (a touch-and-go);
##   - rising air is calmed near the land; flaps slow the plane under SLOW,
##     without them it flies as ever;
##   - in the study: the sharp bot lands and stops and the run is saved;
##     out of the plane, a hop is only a hop, walking off the edge drops
##     (Space opening the pocket sail) and never flies, the plane staying
##     parked; stranded, the pilot
##     is brought back beside the plane, still on foot; Space by the plane
##     boards it and takes off, flying again; the hot bots power-slide to a
##     stop on the short field and the islet.
##   godot --headless --path . --script tests/test_manual_landing.gd
const ManualLanding = preload("res://scripts/manual_landing.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const Course = preload("res://scripts/landing_course.gd")
const DT := 1.0/60.0
## A flat test field: ground at 0 over |x| < 30, -100 < z < 0; open air
## elsewhere.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

static func field_floor(p: Vector2) -> float:
	return 0.0 if absf(p.x) < 30.0 and p.y < 0.0 and p.y > -100.0 else NAN

static func field_ground(p: Vector3) -> Variant:
	return Vector2(0.0,-10.0) if not is_nan(field_floor(Vector2(p.x,p.z))) else null

## A plane flying north at `speed` m/s, `height` m over the field's start,
## nose at `pitch`, and the landing in charge of it.
func approach(speed: float, height: float, pitch: float, z := -5.0) -> ManualLanding:
	var plane := SkyPlane.new()
	plane.launch(Vector3(0.0,SkyPlane.SKIM+height,z),0.0,speed,false)
	plane.speed = speed
	plane.pitch = pitch
	var ml := ManualLanding.new()
	ml.begin(plane)
	return ml

## Steps `ml` with `input` until `until` (a Callable(ml, out) -> bool) or
## `most` s; returns every event seen (merged) and the lowest the plane's
## wheels went under the land.
func fly(ml: ManualLanding, input: Dictionary, most: float, until := Callable()) -> Dictionary:
	var seen := {}
	var lowest := INF
	var t := 0.0
	while t < most:
		var out := ml.step(DT,input,field_ground,field_floor)
		seen.merge(out,true)
		var land := field_floor(Vector2(ml.plane.position.x,ml.plane.position.z))
		if not is_nan(land): lowest = minf(lowest,float(ml.plane.position.y)-land)
		t += DT
		if until.is_valid() and bool(until.call(ml,out)): break
	seen["_lowest"] = lowest
	seen["_t"] = t
	return seen

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("manual landing test timed out"); quit(2))
	_grades()
	_good_touch()
	_hot_sticks()
	_slams()
	_hops()
	_slides()
	_power_slide()
	_slide_steer()
	_reverse()
	_blocked()
	_touch_and_go()
	_edge()
	_calm_air()
	_flaps()
	var finished: bool = await _study()
	check(finished,"The study's checks ran to the end")
	print("PASS: manual landing" if failures == 0 else "FAIL: manual landing (%d)" % failures)
	quit(1 if failures else 0)

func _grades() -> void:
	check(ManualLanding.grade(8.0,0.8,0.05,-0.05,0.0) == "greaser","Slow, shallow, level, on flat ground: a greaser")
	check(ManualLanding.grade(9.0,1.8,0.25,-0.3,0.0) == "firm","Within round 1's limits but firmer: firm")
	check(ManualLanding.grade(8.0,0.8,0.05,-0.05,0.0,false,0.4) == "firm","Drifting at the touch: not a greaser")
	check(ManualLanding.grade(14.0,0.8,0.0,0.0,0.0) == "hot","Too fast: hot")
	check(ManualLanding.grade(8.0,3.0,0.0,-0.1,0.0) == "hard","Sinking hard: hard")
	check(ManualLanding.grade(8.0,0.5,0.0,-0.45,0.0) == "hard","Nose first: hard")
	check(ManualLanding.grade(8.0,4.5,0.0,-0.6,0.0) == "slam","A dive steeper than SLAM_ANGLE: slam")
	check(ManualLanding.grade(28.0,9.5,0.0,-0.34,0.0) == "slam","Sinking over SLAM_SINK down the dive: slam")
	check(ManualLanding.grade(22.0,6.5,0.0,-0.3,0.0) == "hard" and ManualLanding.grade(22.0,1.5,0.0,-0.07,0.0) == "hot","Fast and shallow-ish: it sticks, however fast")
	check(ManualLanding.grade(14.0,0.4,0.0,-0.03,0.0,false,0.0,0.9,11.0) == "slam","A dive remembered, though the nose is up now: slam")
	check(ManualLanding.grade(8.0,0.5,0.9,0.0,0.0,false,0.0,0.8,6.0) == "slam","A slam on a wingtip is still a slam")
	check(ManualLanding.grade(8.0,0.5,0.6,0.0,0.0) == "wingtip","A wing down: wingtip")
	check(ManualLanding.grade(8.0,0.5,0.0,0.0,0.0,true) == "tumble","Mid barrel roll: tumble")
	check(ManualLanding.grade(8.0,0.5,0.0,0.0,0.6) == "rough","Onto ground too steep: rough")
	for g: String in ["greaser","firm","hot","hard","wingtip"]: check(ManualLanding.sticks(g),"A %s touch sticks" % g)
	check(not ManualLanding.sticks("tumble") and not ManualLanding.sticks("rough") and not ManualLanding.sticks("slam"),"A tumble, rough or slam touch hops")
	check(ManualLanding.thump(8.0,0.8,0.0) == 0.0 and ManualLanding.thump(22.0,5.0,0.0) > 0.9,"The hit grows with the speed and the sink")

func _good_touch() -> void:
	# Slow and shallow, brakes on: touches, rolls, stops.
	var ml := approach(8.0,0.25,-0.1)
	var input := {"brake":1.0,"flaps":0.0}
	var seen := fly(ml,input,6.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	check(seen.has("touch") and str(seen.touch.grade) == "greaser","A slow shallow touch is a greaser (%.1f m/s, sink %.2f)" % [float(seen.get("touch",{}).get("speed",0)),float(seen.get("touch",{}).get("sink",0))])
	check(seen.has("settled") and seen.has("greaser") and not seen.has("bounce") and not seen.has("thump"),"It settles, no bounce, no thump")
	check(not seen.has("slide") and float(ml.stats.slide_distance) == 0.0 and absf(float(ml.plane.position.x)) < 0.05,"A greaser rolls out straight: no slide, on its line")
	check(int(ml.stats.greasers) == 1 and str(ml.stats.stop_grade) == "greaser","Counted as a greaser")
	check(ml.phase == ManualLanding.STOPPED and seen.has("stopped"),"It rolls out under the brakes and stops (%.1f s)" % float(seen._t))
	check(float(ml.stats.rollout) > 1.0 and float(ml.stats.rollout) < 14.0,"The rollout is measured (%.1f m)" % float(ml.stats.rollout))
	check(float(seen._lowest) > 0.2,"The wheels never go into the ground (lowest %.2f m)" % float(seen._lowest))
	# Exit while rolling was refused: try again from a fresh roll.
	var ml2 := approach(8.0,0.25,-0.1)
	fly(ml2,{},3.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.ROLL)
	var refused := ml2.step(DT,{"exit":true},field_ground,field_floor)
	check(refused.has("not_yet") and ml2.phase == ManualLanding.ROLL,"Exit while rolling is refused: stop first")
	var ml3 := approach(10.0,8.0,0.0)
	var refused_air := ml3.step(DT,{"exit":true},field_ground,field_floor)
	check(refused_air.has("not_yet") and ml3.flying(),"Exit in the air is refused")
	# Stopped, it waits: never out by itself.
	fly(ml,{"brake":0.0},5.0)
	check(ml.phase == ManualLanding.STOPPED and ml.can_exit(),"Stopped, it stays stopped and waits for Exit (5 s)")
	var out := fly(ml,{"exit":true},0.05)
	check(ml.phase == ManualLanding.EXIT,"Exit asked once stopped: getting out")
	out = fly(ml,{},2.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.done())
	check(ml.done() and out.has("out") and is_equal_approx(ml.hop,1.0) and ml.engine == 0.0,"The engine spins down and the pilot is out")
	check(int(ml.stats.early_exits) == 0,"The early exits are counted per landing (none on this one)")

## Steps until on the wheels; then a while more, watching it stays down.
func _stuck(ml: ManualLanding, label: String, input := {}) -> void:
	var seen := fly(ml,input,3.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.on_ground() or m.stats.bounces > 0)
	var g := str(seen.get("touch",{}).get("grade","none"))
	check(ml.on_ground() and not seen.has("bounce"),"%s sticks (%s, %.1f m/s, sink %.1f)" % [label,g,float(seen.get("touch",{}).get("speed",0.0)),float(seen.get("touch",{}).get("sink",0.0))])
	check(seen.has("thump") and float(seen.thump.k) > 0.0,"%s: the plane takes the hit (k %.2f)" % [label,float(seen.get("thump",{}).get("k",0.0))])
	var state := {"highest":-INF,"stayed":true}
	var after := fly(ml,input,1.0,func(m: ManualLanding, _o: Dictionary) -> bool:
		state.highest = maxf(float(state.highest),float(m.plane.position.y))
		if not m.on_ground(): state.stayed = false
		return false)
	check(bool(state.stayed) and float(state.highest) < SkyPlane.SKIM+ManualLanding.HOP+0.15,"%s: the hop after stays on the wheels (top %.2f m)" % [label,float(state.highest)])
	check(float(after._lowest) > 0.2 and float(seen._lowest) > 0.2,"%s: never into the ground" % label)

func _hot_sticks() -> void:
	# Hot: at cruise and at boost, low over the field, no hands.
	_stuck(approach(SkyPlane.CRUISE_SPEED,0.2,-0.1),"A touch at cruise")
	_stuck(approach(SkyPlane.BOOST_SPEED,0.2,-0.1),"A touch at boost")
	# Nosed down hard at cruise, as a pilot slams it on: still under the
	# slam's limits, so it sticks.
	_stuck(approach(SkyPlane.CRUISE_SPEED,1.1,0.0),"A hard touch nosed down at cruise",{"pitch":-0.6})

## Flown straight into the ground: it bounces, as round 1 did, and comes
## round again; flown out of in time, it sticks.
func _slams() -> void:
	_slam(approach(SkyPlane.CRUISE_SPEED,10.0,-1.25),"A near-vertical slam",{"pitch":-1.0})
	_slam(approach(8.0,3.0,-0.6),"A steep dive",{"pitch":-0.3})
	# A power dive flicked level a frame or two before the wheels (the
	# mouse can): the instant's pose is a greaser's, the dive is not.
	var ml := approach(SkyPlane.BOOST_SPEED,12.0,-1.0)
	fly(ml,{"pitch":-0.5,"boost":1.0},3.0,func(m: ManualLanding, _o: Dictionary) -> bool: return float(m.plane.position.y) < SkyPlane.SKIM+0.35)
	var flick := -float(ml.plane.pitch)-0.02
	var seen := fly(ml,{"look":Vector2(0.0,flick)},DT*0.5)
	seen.merge(fly(ml,{},1.0,func(m: ManualLanding, _o: Dictionary) -> bool: return not m.stats.touches.is_empty()),true)
	var touch: Dictionary = seen.get("touch",{})
	check(not touch.is_empty() and float(touch.pitch) > -0.1,"Flicked level on the last frames (nose %.2f at the touch)" % float(touch.get("pitch",0.0)))
	check(str(touch.get("grade","")) == "slam" and seen.has("bounce"),"A power dive flared for a frame still bounces (%s; dive %.2f rad remembered)" % [str(touch.get("grade","none")),float(touch.get("dive",0.0))])
	# The same dive, pulled out of in time: it sticks.
	var flown := approach(SkyPlane.CRUISE_SPEED,12.0,-0.9)
	fly(flown,{"pitch":-0.2},3.0,func(m: ManualLanding, _o: Dictionary) -> bool: return float(m.plane.position.y) < SkyPlane.SKIM+7.0)
	fly(flown,{"pitch":1.0},2.0,func(m: ManualLanding, _o: Dictionary) -> bool: return float(m.plane.pitch) > -0.12)
	var out := fly(flown,{},4.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.on_ground() or m.stats.bounces > 0)
	check(flown.on_ground() and not out.has("bounce"),"A dive pulled out of in time sticks (%s)" % str(out.get("touch",{}).get("grade","none")))

func _slam(ml: ManualLanding, label: String, input: Dictionary) -> void:
	var seen := fly(ml,input,4.0,func(m: ManualLanding, o: Dictionary) -> bool: return o.has("touch"))
	var touch: Dictionary = seen.get("touch",{})
	check(seen.has("bounce") and str(seen.bounce.reason) == "slam","%s bounces (%s, %.1f m/s along, sink %.1f, dive %.0f deg)" % [label,str(touch.get("grade","none")),
		float(touch.get("speed",0.0)),float(touch.get("sink",0.0)),rad_to_deg(float(touch.get("dive",0.0)))])
	check(ml.flying() and absf(float(ml.plane.bank)) < 0.01 and float(ml.plane.pitch) >= ManualLanding.BOUNCE_NOSE-0.01,"%s: flying again, wings level, nose up" % label)
	# Let go: up a little ("no, try again"), never into the ground, and down
	# again onto its wheels.
	var top := {"y":-INF}
	var up := fly(ml,{},0.8,func(m: ManualLanding, _o: Dictionary) -> bool:
		top.y = maxf(float(top.y),float(m.plane.position.y))
		return false)
	var rise := float(top.y)-SkyPlane.SKIM
	check(rise > 0.6 and rise < 4.5 and float(up._lowest) > 0.2 and float(seen._lowest) > 0.2,"%s: up %.1f m and never into the ground" % [label,rise])
	# A go-around: flown back down gently, it sticks.
	var again := fly(ml,{"pitch":-0.25},12.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.on_ground() or m.stats.bounces > 1)
	check(ml.on_ground() and again.has("settled"),"%s: flown back down gently, it sticks (%s, %.1f s)" % [label,ml.last_touch,float(again._t)])

func _hops() -> void:
	# A barrel roll into the ground: up, the wings put level, still flying.
	var ml := approach(10.0,0.6,-0.15)
	var seen := fly(ml,{"roll":1.0},1.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("touch"))
	check(seen.has("bounce") and str(seen.bounce.reason) == "tumble","Mid barrel roll into the ground: a hop (%s)" % str(seen.get("bounce",{}).get("reason","none")))
	var y0: float = ml.plane.position.y
	var up := fly(ml,{},0.6)
	check(ml.flying() and float(ml.plane.position.y) > y0+0.3 and not bool(ml.plane.rolling),"It hops up and rights itself (%.2f m up)" % (float(ml.plane.position.y)-y0))
	check(float(up._lowest) > 0.2,"Never into the ground after the hop")
	var again := fly(ml,{"brake":1.0,"flaps":1.0},14.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	check(ml.phase == ManualLanding.STOPPED and again.has("settled"),"After the hop it comes down and stops (%.1f s)" % float(again._t))

## On the wheels at `speed`, rolling straight (a firm touch near the field's
## start).
func rolling(speed: float, z := -5.0) -> ManualLanding:
	var ml := approach(speed,0.2,-0.05,z)
	fly(ml,{},2.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.on_ground())
	return ml

func _slides() -> void:
	# Steering hard at speed breaks it loose.
	var ml := rolling(14.0)
	var seen := fly(ml,{"turn":1.0},0.5)
	check(seen.has("slide") and ml.sliding and absf(ml.slip) > 0.3,"Steering hard at speed kicks the tail out (slip %.2f rad)" % ml.slip)
	check(ml.grit > 0.4,"Sliding throws grit off the wheels (%.2f)" % ml.grit)
	var caught := fly(ml,{},2.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("caught"))
	check(caught.has("caught") and not ml.sliding and ml.on_ground(),"Let go, it grips again")
	# Slow, the same stick only steers.
	var slow := rolling(8.0)
	fly(slow,{"brake":1.0},3.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.roll_speed() < 5.0)
	var steer := fly(slow,{"turn":1.0},0.5)
	check(not steer.has("slide"),"Slow, the stick steers it without sliding")
	# The lean (the air drift's button) with a turn drifts even gently.
	var lean := rolling(8.0)
	var drift := fly(lean,{"turn":0.5,"lean":0.8},0.4)
	var plain := rolling(8.0)
	var nope := fly(plain,{"turn":0.5},0.4)
	check(drift.has("slide") and not nope.has("slide"),"The lean with a turn drifts where the turn alone grips")

func _power_slide() -> void:
	var straight := rolling(14.0)
	var from: float = straight.touched_at().z
	fly(straight,{"brake":1.0},10.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	var braked := rolling(14.0)
	fly(braked,{"brake":1.0,"turn":1.0},10.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	var power := rolling(14.0)
	var seen := fly(power,{"brake":1.0,"turn":1.0,"boost":1.0},10.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	var a := from-float(straight.plane.position.z)
	var b := from-float(braked.plane.position.z)
	var c := from-float(power.plane.position.z)
	check(power.phase == ManualLanding.STOPPED and seen.has("stopped"),"A power-slide, the throttle held, still stops")
	check(c < a-4.0 and b < a,"A power-slide stops shorter than a straight brake (%.1f m against %.1f; braked slide %.1f)" % [c,a,b])
	check(float(power.stats.peak_slip) > 1.2 and int(power.stats.power_slides) == 1,"It pivots right round on its wheels (peak slip %.0f deg)" % rad_to_deg(float(power.stats.peak_slip)))
	check(float(power.stats.slide_distance) > 3.0 and not is_nan(float(power.stats.stop_margin)),"The slide and the stop's margin are measured (%.1f m slid, %.1f m to the edge)" % [float(power.stats.slide_distance),float(power.stats.stop_margin)])

## The stick bends a slide's line: the lean held tighter, full stick into
## it as round 2, against it (counter-steer) wider, in a drift and in a
## power-slide; the power-slide still stops well short of a straight brake
## (`_power_slide`).
func _slide_steer() -> void:
	for kind: String in ["drift","power-slide"]:
		var start := {"turn":1.0,"lean":1.0} if kind == "drift" else {"turn":1.0,"brake":1.0,"boost":1.0}
		var held := {} if kind == "drift" else {"brake":1.0}
		var lines := {}
		for way: String in ["tighter","full","counter"]:
			var ml := rolling(14.0)
			fly(ml,start,0.3)
			var side := ml.drift_side
			var from: Vector2 = ml._v.normalized()
			var input := held.duplicate()
			input.turn = -1.0 if way == "counter" else 1.0
			input.lean = 1.0 if way == "tighter" else 0.0
			fly(ml,input,0.8)
			lines[way] = from.angle_to(ml._v.normalized())*-side
			lines[way+"_on"] = side != 0.0 and side == ml.drift_side and ml.sliding
		check(bool(lines.tighter_on) and bool(lines.full_on) and bool(lines.counter_on),"Steering a %s keeps it sliding on its side, into it or against it" % kind)
		check(float(lines.tighter) > float(lines.full)+0.1 and float(lines.full) > float(lines.counter)+0.1,"Steering a %s bends its line: the lean tighter, against it wider (%.0f, %.0f, %.0f deg in 0.8 s)" % [kind,rad_to_deg(float(lines.tighter)),rad_to_deg(float(lines.full)),rad_to_deg(float(lines.counter))])

## Stopped, Brake held backs it up, the stick turning it as a car backs;
## let go it stops; it never backs off the land; stopped, Brake, Boost and
## the stick pivot it.
func _reverse() -> void:
	var ml := rolling(8.0,-12.0)
	fly(ml,{"brake":1.0},6.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	var z0 := float(ml.plane.position.z)
	var h0 := float(ml.plane.heading)
	var short := fly(ml,{"brake":1.0},ManualLanding.REVERSE_DELAY*0.5)
	check(ml.phase == ManualLanding.STOPPED and not short.has("reverse"),"Stopped, a moment's brake only holds it")
	var back := fly(ml,{"brake":1.0},1.5)
	check(back.has("reverse") and ml.reversing and float(ml.plane.position.z) > z0+0.5,"Brake held a moment: it backs up (%.1f m)" % (float(ml.plane.position.z)-z0))
	check(ml.roll_speed() <= ManualLanding.REVERSE_SPEED+0.01 and absf(float(ml.plane.heading)-h0) < 0.01,"Slowly (%.1f m/s), and straight with the stick centred" % ml.roll_speed())
	fly(ml,{"brake":1.0,"turn":1.0},0.8)
	check(float(ml.plane.heading) > h0+0.3,"The stick turns it backing up, as a car backs (stick right: the nose swings left, %.2f rad)" % (float(ml.plane.heading)-h0))
	var stop := fly(ml,{},1.5,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	check(ml.phase == ManualLanding.STOPPED and stop.has("stopped") and not ml.reversing,"Let go of the brake, it stops")
	check(ml.can_exit(),"And Exit can get out")
	# Backed up to the field's start: stopped with its tail at the edge.
	ml.plane.heading = 0.0
	var edge := fly(ml,{"brake":1.0},30.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("edge_behind"))
	fly(ml,{"brake":1.0},1.0)
	check(edge.has("edge_behind") and ml.on_ground() and int(ml.stats.off_edge) == 0,"Backed up to the edge, it stops there, still on the land (%s, %s, off %d)" % [edge.has("edge_behind"),ManualLanding.NAMES[ml.phase],int(ml.stats.off_edge)])
	check(float(ml.plane.position.z) < -ManualLanding.REVERSE_LOOK+0.2,"Its tail short of the edge (middle %.2f m in)" % -float(ml.plane.position.z))
	# Stopped: Brake, Boost and the stick pivot it on the spot.
	fly(ml,{},1.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.STOPPED)
	var at: Vector3 = ml.plane.position
	var h1 := float(ml.plane.heading)
	fly(ml,{"brake":1.0,"boost":1.0,"turn":1.0},1.0)
	check(ml.phase == ManualLanding.STOPPED and float(ml.plane.heading) < h1-0.6 and ml.plane.position.distance_to(at) < 0.05,"Brake, Boost and the stick pivot it where it stands (%.2f rad)" % (h1-float(ml.plane.heading)))

## Rolled into a wall: stopped short, then the throttle and stick turn it
## away, or it backs off it, and it is free; stuck in something, it can
## always move out.
func _blocked() -> void:
	var wall := func(p: Vector3) -> bool: return p.z < -30.0
	var ml := rolling(8.0,-12.0)
	var seen := {}
	var t := 0.0
	while t < 6.0:
		seen.merge(ml.step(DT,{},field_ground,field_floor,Callable(),wall),true)
		t += DT
		if seen.has("hit"): break
	check(seen.has("hit") and ml.roll_speed() < 0.01 and float(ml.plane.position.z) > -30.0,"Rolled into a wall it stops short (at %.1f m)" % -float(ml.plane.position.z))
	# Pushing on it with the throttle and the stick: it turns away at the
	# tail wheel's full, not a quarter of it.
	var h0 := float(ml.plane.heading)
	var pushed := {}
	for i in range(int(1.0/DT)): pushed.merge(ml.step(DT,{"boost":0.3,"turn":1.0},field_ground,field_floor,Callable(),wall),true)
	check(float(ml.plane.heading) < h0-0.6,"Throttle and stick against it: it turns away (%.2f rad in 1 s)" % (h0-float(ml.plane.heading)))
	check(not pushed.has("hit"),"Pushing slowly on it is not a thump each frame")
	# Backing off it: brake to a stop, hold it, and it goes back.
	var stuck := rolling(8.0,-12.0)
	t = 0.0
	while t < 6.0 and stuck.phase != ManualLanding.STOPPED:
		stuck.step(DT,{"brake":1.0 if float(stuck.plane.position.z) < -29.0 else 0.0},field_ground,field_floor,Callable(),wall)
		t += DT
	var z0 := float(stuck.plane.position.z)
	for i in range(int(2.0/DT)): stuck.step(DT,{"brake":1.0},field_ground,field_floor,Callable(),wall)
	check(float(stuck.plane.position.z) > z0+1.0,"Stopped at the wall, Brake held backs it off (%.1f m)" % (float(stuck.plane.position.z)-z0))
	# In something (a slide's swing put a wing in a post): it can move out,
	# never further in.
	var post := func(p: Vector3) -> bool: return Vector2(p.x-1.0,p.z+40.0).length() < 1.5
	var inside := rolling(3.0,-36.0)
	inside.plane.position = Vector3(0.2,inside.plane.position.y,-40.0)
	inside._v = Vector2(-2.0,0.0)
	inside.plane.heading = PI*0.5
	var out_x := float(inside.plane.position.x)
	for i in range(30): inside.step(DT,{"boost":1.0},field_ground,field_floor,Callable(),post)
	check(float(inside.plane.position.x) < out_x-0.3,"In a post, it moves out (%.2f m)" % (out_x-float(inside.plane.position.x)))
	var deeper := rolling(3.0,-36.0)
	deeper.plane.position = Vector3(0.0,deeper.plane.position.y,-40.0)
	deeper.plane.heading = -PI*0.5
	deeper._v = Vector2(2.0,0.0)
	var in_x := float(deeper.plane.position.x)
	for i in range(10): deeper.step(DT,{"boost":1.0},field_ground,field_floor,Callable(),post)
	check(float(deeper.plane.position.x) <= in_x+0.01,"But never further in (%.2f m)" % (float(deeper.plane.position.x)-in_x))

func _touch_and_go() -> void:
	var ml := approach(9.0,0.25,-0.1)
	fly(ml,{},2.0,func(m: ManualLanding, _o: Dictionary) -> bool: return m.phase == ManualLanding.ROLL)
	var seen := fly(ml,{"boost":1.0},5.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("lifted"))
	check(seen.has("lifted") and ml.flying(),"Boost on the roll lifts it off again (a touch-and-go)")
	var climb := fly(ml,{"boost":1.0},1.5)
	check(float(ml.plane.position.y) > SkyPlane.SKIM+0.5 and not climb.has("touch"),"And it climbs away, the wheels not counting a moment (%.1f m)" % float(ml.plane.position.y))

func _edge() -> void:
	# Touching near the field's far end with no brakes: off the edge.
	var ml := approach(9.0,0.25,-0.1,-93.0)
	var seen := fly(ml,{},4.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("off_edge"))
	check(seen.has("settled") and seen.has("off_edge") and ml.flying(),"Rolled off the edge it is flying again")
	check(int(ml.stats.off_edge) == 1,"Counted")
	# Hot and sliding off the end: flying on with its speed.
	var hot := approach(SkyPlane.BOOST_SPEED,0.2,-0.05,-88.0)
	var off := fly(hot,{"turn":0.4,"lean":1.0},4.0,func(_m: ManualLanding, o: Dictionary) -> bool: return o.has("off_edge"))
	check(off.has("slide") and off.has("off_edge") and hot.flying(),"Slid off the edge at boost: flying again")
	check(float(hot.plane.speed) > 14.0,"With its speed carried (%.1f m/s)" % float(hot.plane.speed))
	var dip := fly(hot,{},2.0)
	check(hot.flying() and not dip.has("touch"),"No penalty: a dip and on it flies")

func _calm_air() -> void:
	var lift := {"wind":Vector3(1.0,5.0,0.0)}
	var low := ManualLanding.calmed(lift,Vector3(0.0,0.9,-10.0),field_floor)
	var high := ManualLanding.calmed(lift,Vector3(0.0,8.0,-10.0),field_floor)
	var off := ManualLanding.calmed(lift,Vector3(0.0,0.9,50.0),field_floor)
	check(is_zero_approx((low.wind as Vector3).y) and is_equal_approx((low.wind as Vector3).x,1.0),"Rising air is calmed just over the land, the wind along kept")
	check(is_equal_approx((high.wind as Vector3).y,5.0) and is_equal_approx((off.wind as Vector3).y,5.0),"Higher up, or off the land, it lifts as ever")

func _flaps() -> void:
	var plain := SkyPlane.new()
	plain.launch(Vector3(0.0,50.0,0.0),0.0,8.0,false)
	var down := SkyPlane.new()
	down.launch(Vector3(0.0,50.0,0.0),0.0,8.0,false)
	var none := func(_p: Vector3) -> Variant: return null
	for i in range(600):
		plain.step(DT,{"brake":1.0},none)
		down.step(DT,{"brake":1.0,"flaps":1.0},none)
	check(plain.speed >= SkyPlane.SLOW-0.01 and plain.speed < SkyPlane.BRAKE_SPEED+0.3,"Flaps up it brakes to its usual speed (%.1f m/s)" % plain.speed)
	check(down.speed < SkyPlane.SLOW and down.speed >= SkyPlane.FLAP_SLOW-0.01,"Flaps down it flies slower than SLOW (%.1f m/s)" % down.speed)

# --- The study -----------------------------------------------------------------------

func _study() -> bool:
	var study: Node3D = load("res://studies/landing_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://landing_runs_test"
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	check(study.find_children("Station_*","",false,false).size() == Course.STATIONS.size(),"Every station stands")
	var arrays := Course.pad_mesh(Course.STATIONS[0].pads[0]).surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(normals[0].y > 0.9,"A field's top faces up (%s)" % str(normals[0]))
	# The sharp bot lands the long field and stops.
	study.pilot = "sharp"
	study.start(Course.station("long_field"))
	var frames := 0
	while not study.run.done and frames < 60*60:
		study.tick(DT)
		frames += 1
	check(study.run.done and study.run.ended == "stopped","The sharp bot lands and stops (%.1f s)" % study.run.t)
	check(study._report.visible and FileAccess.file_exists(study.last_path),"The report is up and the run saved")
	# The bot gets out once stopped.
	frames = 0
	while study.mode == "plane" and frames < 60*5:
		study.tick(DT)
		frames += 1
	check(study.mode == "foot" and study.parked,"Out of the plane on foot, the plane parked")
	var parked_at: Vector3 = study.run.plane.position
	# Away from the plane (west, off its left side), a hop is only a hop.
	study._foot_yaw = PI*0.5
	for i in range(60): study.tick(DT,{"move":Vector2(0.0,1.0)})
	check(study.mode == "foot" and not study.by_plane(),"Walked away from the plane")
	study.tick(DT,{"jump":true,"move":Vector2.ZERO})
	var feet_y: float = study.feet.y
	for i in range(10): study.tick(DT,{})
	check(study.mode == "foot" and study.feet.y > feet_y,"Space away from the plane hops, it does not fly")
	for i in range(60): study.tick(DT,{})
	# On west, off the field's side.
	frames = 0
	while study.mode == "foot" and frames < 60*12:
		study.tick(DT,{"move":Vector2(0.0,1.0)})
		frames += 1
	check(study.mode == "drop","Walked off the edge: a drop, not a flight")
	check(study.parked and study.run.plane.position.distance_to(parked_at) < 0.01,"The plane stays parked where it was")
	frames = 0
	var sailed := false
	while study.mode == "drop" and frames < 60*60:
		# Space a moment after the edge: the sail.
		study.tick(DT,{"open":frames == 20})
		sailed = sailed or study.dive.sailing()
		frames += 1
	check(sailed,"Space in the drop opens the sail")
	check(study.mode == "stranded","Down off the plane's field: stranded (%s)" % study.mode)
	frames = 0
	while study.mode == "stranded" and frames < 60*10:
		study.tick(DT,{})
		frames += 1
	check(study.mode == "foot" and study.parked and study.by_plane(),"Stranded a while, then back on foot beside the parked plane")
	check(not study.run.ml.flying() or study.run.ml.on_ground() or study.run.ml.done(),"The plane did not fly off by itself")
	# Space by the plane boards it and takes off.
	study.tick(DT,{"jump":true})
	check(study.mode == "takeoff" and not study.parked,"Space by the plane: in, and the takeoff")
	frames = 0
	while study.mode == "takeoff" and frames < 60*15:
		study.tick(DT,{})
		frames += 1
	check(study.mode == "plane" and study.run.ml.flying(),"Flying again after the takeoff (%.1f s)" % (frames*DT))
	var land := Course.floor_at(Vector2(study.run.plane.position.x,study.run.plane.position.z))
	check(is_nan(land) or study.run.plane.position.y > land+1.5,"Off the ground and climbing")
	# Every station's sharp bot run stops.
	for s: Dictionary in Course.STATIONS:
		study.start(s)
		frames = 0
		while not study.run.done and frames < 60*120:
			study.tick(DT)
			frames += 1
		check(study.run.ended == "stopped","Sharp bot stops on %s (%.1f s, bounces %d)" % [s.id,study.run.t,int(study.run.ml.stats.bounces)])
	# In hot: the sharp bot slams it on and power-slides to a stop first
	# time, at boost on the short field and at cruise on the islet.
	for hot: Array in [["short_ledge","boost"],["islet","hot"]]:
		study.approach = hot[1]
		study.start(Course.station(hot[0]))
		study.bot = load("res://scripts/landing_bot.gd").new(study.bot.skill,1000,study.BOT_PACE[hot[1]])
		frames = 0
		while not study.run.done and frames < 60*120:
			study.tick(DT)
			frames += 1
		var m: Dictionary = study.run.metrics()
		check(bool(m.first_try) and float(m.touch_speed) > ManualLanding.TOUCH_FAST,"In hot (%s) on %s: stopped first time from %.1f m/s" % [hot[1],hot[0],float(m.touch_speed) if m.touch_speed != null else 0.0])
		check(int(m.power_slides) > 0 and float(m.peak_slip) > 1.0 and float(m.stop_margin) > 0.0,"By a power-slide (%.1f m slid, peak %.0f deg, %.1f m to spare)" % [float(m.slide_distance),rad_to_deg(float(m.peak_slip)),float(m.stop_margin) if m.stop_margin != null else -1.0])
	study.approach = "normal"
	study.queue_free()
	return true
