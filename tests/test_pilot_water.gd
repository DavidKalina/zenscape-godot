extends SceneTree
## The pilot in water (scripts/pilot_motor.gd `water`, drawn by scripts/
## pilot_figure.gd), on a beach shelving into a pool: wading slows him by the
## depth and keeps him on the bed, the drawn body lifting its knees; chest
## deep he swims, floating SWIM_DRAFT under the surface, slower than on foot,
## the paddle's strokes told; Space there hops him up out of it and never
## opens the sail, and he falls back in with a splash; walked back up the shelf
## he stands and walks out. Out of it he drips a while, less and less, and
## stops; his clothes stay wet a while longer and dry. His wake through the
## plants (scripts/pilot_wake.gd) is quiet while he swims. The rings on the
## water (scripts/pilot_ripples.gd) spread and go.
##   godot --headless --path . --script tests/test_pilot_water.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotWake = preload("res://scripts/pilot_wake.gd")
const PilotRipples = preload("res://scripts/pilot_ripples.gd")
const DT := 1.0/60.0
var failures := 0
## The ground: a dry beach at 0.05 up to x 2, shelving down to -1.2 by x 8,
## level beyond; the water's top at 0.
var ground := func(p: Vector2) -> float:
	return lerpf(0.05,-1.2,clampf((p.x-2.0)/6.0,0.0,1.0))
var water := func(p: Vector2) -> float:
	return maxf(0.0,-float(ground.call(p)))
var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	var m := PilotMotor.new()
	m.water = water
	var holder := Node3D.new()
	root.add_child(holder)
	var figure := PilotFigure.new()
	holder.add_child(figure)
	var wake := PilotWake.new()
	wake.motor = m
	holder.add_child(wake)
	await process_frame
	check(figure._has_swim,"The model has the swim and tread clips")
	# Wading in.
	m.reset(Vector3(0.0,0.05,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	var dry_pace := 0.0
	var wading_pace := 0.0
	var wading_grounded := true
	var on_bed := true
	var knees := 0.0
	var events := {}
	for i in range(600):
		var out := m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
		figure.soak(m.pose(),DT)
		for k in out: events[k] = true
		if m.feet.x < 1.8: dry_pace = m.speed()
		if not m.swimming and m.wade > 0.3:
			wading_pace = m.speed() if wading_pace == 0.0 else minf(wading_pace,m.speed())
			wading_grounded = wading_grounded and m.grounded
			on_bed = on_bed and absf(m.feet.y-float(ground.call(Vector2(m.feet.x,m.feet.z)))) < 0.01
			knees = maxf(knees,figure._wade)
		if m.swimming: break
	check(absf(dry_pace-PilotMotor.RUN) < 0.05,"On the beach he runs at his pace (%.2f m/s)" % dry_pace)
	check(wading_pace > 0.0 and wading_pace < PilotMotor.RUN*0.7,"Wading over 0.3 m slows him (%.2f m/s)" % wading_pace)
	check(wading_grounded and on_bed,"Wading he stays grounded, on the bed")
	check(knees > 0.5,"The drawn body takes up the wading gait (%.2f)" % knees)
	check(m.swimming and events.has("swam"),"Chest deep he swims (at %.2f m deep)" % float(water.call(Vector2(m.feet.x,m.feet.z))))
	# Swimming out to the deep and floating.
	var fastest := 0.0
	var strokes := 0
	for i in range(240):
		m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,false,ground,slide)
		if figure.drive(m.pose(),DT).has("stroke"): strokes += 1
		figure.soak(m.pose(),DT)
		fastest = maxf(fastest,m.speed())
	check(m.swimming and m.feet.x > 5.5,"He swims out into the deep (x %.1f)" % m.feet.x)
	check(fastest <= PilotMotor.SWIM+0.6 and absf(m.speed()-PilotMotor.SWIM) < 0.1,"Slower than on foot, at his swimming pace (%.2f m/s)" % m.speed())
	check(strokes >= 4,"The paddle's strokes are told (%d)" % strokes)
	for i in range(180):
		m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
		figure.soak(m.pose(),DT)
	check(absf(m.feet.y-(0.0-PilotMotor.SWIM_DRAFT)) < 0.02,"Afloat, his feet %.2f m under the surface (SWIM_DRAFT %.2f)" % [-m.feet.y,PilotMotor.SWIM_DRAFT])
	check(m.speed() < 0.05 and not m.grounded,"Let go, he coasts to a stop and treads water")
	check(figure._swim > 0.99 and figure._paddle < 0.1,"Drawn treading water")
	# The wake is quiet.
	var lean := 0.0
	for i in range(120):
		m.feet.z += 0.01
		holder.position = m.feet
		wake._process(DT)
		lean = wake.published[0].w
	check(wake._under_water() and absf(lean) < 0.001,"His wake parts nothing while he swims (%.3f)" % lean)
	# Space in the deep: a hop out, never a flight.
	var flew := false
	var hopped := false
	var back_in := false
	var pressed := true
	for i in range(240):
		var out := m.step(DT,Vector2.ZERO,PilotMotor.RUN,pressed,ground,slide)
		figure.drive(m.pose(),DT)
		figure.soak(m.pose(),DT)
		pressed = not pressed if i < 40 else false
		flew = flew or out.has("sail") or out.has("fly")
		hopped = hopped or out.has("hopped")
		if hopped and out.has("swam"): back_in = true
	check(hopped and not flew,"Space in deep water hops him up, and pressed again never opens the sail")
	check(back_in and m.swimming,"He falls back in with a splash, afloat again")
	# Walking out.
	var stood := false
	for i in range(900):
		var out := m.step(DT,Vector2(-1.0,0.0),PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
		figure.soak(m.pose(),DT)
		stood = stood or out.has("stood")
		if m.feet.x < 1.0: break
	check(stood and m.grounded and not m.swimming and m.feet.x < 1.0,"Shallow enough, he stands and walks out (x %.1f)" % m.feet.x)
	check(m.wade == 0.0 and absf(m.speed()-PilotMotor.RUN) < 0.3,"Out of the water, dry footed and at his pace again (%.2f m/s)" % m.speed())
	check(figure.wet > 0.9 and figure.wet_line > 0.6 and figure.wet_line <= PilotFigure.WET_MOST,"Soaked up to the chest (%.2f m, rest height)" % figure.wet_line)
	# Dripping.
	m.reset(m.feet,m.facing)
	var drips := [0,0,0,0,0]
	for i in range(300):
		m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
		var at := figure.soak(m.pose(),DT)
		drips[i/60] += at.size()
		for p in at:
			if p.y < figure.global_position.y or p.y > figure.global_position.y+0.8: drips[4] += 1000
	print("     drips a second: %s" % [drips])
	check(drips[0] > 5 and drips[0] > drips[2] and drips[2] > 0,"He drips off his clothes a while, less and less")
	check(drips[4] == 0,"Drips stop after DRIP_TIME, and all fell from on him")
	check(figure.wet > 0.4,"His clothes are still wet a while (%.2f)" % figure.wet)
	for i in range(int(PilotFigure.DRY_TIME*60.0)):
		figure.soak(m.pose(),DT)
	check(figure.wet == 0.0 and figure.wet_line == 0.0,"And dry back")
	# The rings.
	var ripples := PilotRipples.new()
	root.add_child(ripples)
	ripples.splash(Vector3.ZERO,1.0)
	for i in range(5): ripples.trail(Vector3(0.3*i,0.0,0.0),true)
	await process_frame
	check(ripples.alive >= 4,"A splash and a swim's wake lay rings (%d)" % ripples.alive)
	for i in range(150): await process_frame
	check(ripples.alive == 0,"And they spread and go")
	print("PASS: pilot water" if failures == 0 else "FAIL: pilot water (%d)" % failures)
	holder.queue_free()
	ripples.queue_free()
	await process_frame
	quit(1 if failures else 0)
