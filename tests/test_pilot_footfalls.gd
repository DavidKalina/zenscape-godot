extends SceneTree
## The pilot's footfalls and puffs (scripts/pilot_figure.gd `drive`,
## scripts/pilot_puffs.gd), driven by the real motor (scripts/pilot_motor.gd):
## at a run a footfall comes at each boot's touchdown, the boots taking turns,
## six a second, each as its boot is down on the ground; stood still, none;
## thrown back at a run it skids long enough to see, then whips round to the
## new way once. Its springs: a jump stretches it rising and flies its arms
## out; landing squashes it and it bounces back past standing; stopping from
## a run it tips forward and wobbles back past upright; running, its chest
## leans forward (further than walking, further still uphill); turning, its
## chest rolls into the turn and its head looks into it. A run's footfall kicks up a puff (a walk's does not), a
## wade's throws droplets, a skid sprays them, a hard landing rings them, and
## they all shrink away within a second.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotPuffs = preload("res://scripts/pilot_puffs.gd")
const DT := 1.0/60.0
## Over this, an ankle is off the ground (it stands 0.053 flat).
const DOWN := 0.075
var failures := 0
var ground := func(_p: Vector2) -> float: return 0.0
var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var m := PilotMotor.new()
	var figure := PilotFigure.new()
	root.add_child(figure)
	var skeleton: Skeleton3D = figure.find_children("*","Skeleton3D",true,false)[0]
	var boots := [skeleton.find_bone("foot.L"),skeleton.find_bone("foot.R")]
	# The run.
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)))
	var falls := []
	var set_off := 0
	var low := true
	for i in range(150):
		m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,false,ground,slide)
		figure.position = m.feet
		figure.rotation.y = m.facing
		var out := figure.drive(m.pose(),DT)
		if out.has("set_off"): set_off += 1
		if out.has("footfall"):
			falls.append([i,int(out.footfall)])
			if i >= 60: low = low and _at(skeleton,boots[int(out.footfall)]).y < DOWN
	var last_second := falls.filter(func(f: Array) -> bool: return f[0] >= 90)
	var turns := true
	for k in range(1,falls.size()): turns = turns and falls[k][1] != falls[k-1][1]
	check(set_off == 1,"Setting off from a stand is told once (%d)" % set_off)
	check(absi(last_second.size()-roundi(2.0/PilotFigure.RUN_CYCLE)) <= 1,"At a run, %d footfalls a second (the run's two a cycle: %d)" % [last_second.size(),roundi(2.0/PilotFigure.RUN_CYCLE)])
	check(turns and falls.size() > 4,"The boots take turns: %s" % [falls.map(func(f: Array) -> int: return f[1])])
	check(low,"Each footfall comes as its boot is down on the ground")
	# Stood still.
	for i in range(40):
		m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
	var still := 0
	for i in range(60):
		m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)
		if figure.drive(m.pose(),DT).has("footfall"): still += 1
	check(still == 0,"Stood still, no footfalls (%d)" % still)
	# The skid.
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	for i in range(10): figure.drive(m.pose(),DT)
	var skid_frames := 0
	var turned := 0
	var whipped_at := -1
	for i in range(60):
		m.step(DT,Vector2(-1.0,0.0),PilotMotor.RUN,false,ground,slide)
		if m.skidding: skid_frames += 1
		var out := figure.drive(m.pose(),DT)
		if out.has("turned"):
			turned += 1
			whipped_at = i
		if whipped_at >= 0 and i == whipped_at+12:
			var pivot := figure.get_child(0) as Node3D
			check(absf(pivot.rotation.y) < 0.15,"A fifth of a second on it faces the new way (%.2f rad still to turn)" % pivot.rotation.y)
	check(skid_frames >= 14,"Thrown back at a run it skids long enough to see (%.2f s)" % (skid_frames*DT))
	check(turned == 1,"Then whips round once (%d)" % turned)
	await _springs(m,figure,skeleton)
	figure.free()
	# The puffs.
	var puffs := PilotPuffs.new()
	root.add_child(puffs)
	puffs.footfall(Vector3.ZERO,Vector3.BACK,"grass",1.0)
	check(_alive(puffs) == PilotPuffs.LOBES,"A run's footfall kicks up a puff of %d balls (%d)" % [PilotPuffs.LOBES,_alive(puffs)])
	puffs.footfall(Vector3.ZERO,Vector3.BACK,"grass",0.2)
	check(_alive(puffs) == PilotPuffs.LOBES,"A walk's does not")
	puffs.footfall(Vector3.ZERO,Vector3.BACK,"water",0.2)
	check(_alive(puffs)-PilotPuffs.LOBES >= 2,"A wade's throws droplets (%d)" % (_alive(puffs)-PilotPuffs.LOBES))
	var before := _alive(puffs)
	for i in range(18): puffs.spray(Vector3.ZERO,Vector3.FORWARD,"earth",1.0,DT)
	check(_alive(puffs)-before >= 6,"A skid's 0.3 s sprays them (%d)" % (_alive(puffs)-before))
	before = _alive(puffs)
	puffs.burst(Vector3.ZERO,"snow",1.0)
	check(_alive(puffs)-before == 20,"A hard landing rings ten of them (%d balls)" % (_alive(puffs)-before))
	await create_timer(1.0).timeout
	await process_frame
	check(puffs.alive == 0 and not puffs.is_processing(),"They shrink away within a second (%d left)" % puffs.alive)
	puffs.free()
	print("PASS: pilot footfalls" if failures == 0 else "FAIL: pilot footfalls")
	quit(1 if failures else 0)

## The body's springs over the clips, driven by the motor.
func _springs(m: RefCounted, figure: Node3D, skeleton: Skeleton3D) -> void:
	var tilt := figure.get_child(0) as Node3D
	var pivot := tilt.get_child(0) as Node3D
	var hands := [skeleton.find_bone("hand.L"),skeleton.find_bone("hand.R")]
	var head := skeleton.find_bone("head")
	m.reset(Vector3.ZERO,0.0)
	figure.settle()
	var apart := _at(skeleton,hands[0]).distance_to(_at(skeleton,hands[1]))
	# A jump from a stand, held.
	var tallest := 1.0
	var widest := 0.0
	var lowest := 1.0
	var rebound := 1.0
	var landed := -1
	for i in range(90):
		var out: Dictionary = m.step(DT,Vector2.ZERO,PilotMotor.RUN,i < 30,ground,slide)
		if out.has("landed"):
			figure.land(float(out.landed))
			landed = i
		figure.drive(m.pose(),DT)
		if landed < 0:
			tallest = maxf(tallest,pivot.scale.y)
			widest = maxf(widest,_at(skeleton,hands[0]).distance_to(_at(skeleton,hands[1])))
		else:
			lowest = minf(lowest,pivot.scale.y)
			if lowest < 0.95: rebound = maxf(rebound,pivot.scale.y)
	check(tallest > 1.06,"A jump stretches it rising (%.2f tall)" % tallest)
	check(widest > apart+0.1,"And flies its arms out (hands %.2f m apart, %.2f standing)" % [widest,apart])
	check(landed >= 0 and lowest < 0.88,"Landing squashes it (%.2f tall)" % lowest)
	check(rebound > 1.02,"And it bounces back past standing (%.2f)" % rebound)
	check(absf(pivot.scale.y-1.0) < 0.02,"Then stands as it was (%.2f)" % pivot.scale.y)
	# Stopping from a run.
	m.reset(Vector3.ZERO,0.0)
	figure.settle()
	for i in range(60):
		m.step(DT,Vector2(0.0,-1.0),PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
	var forward := 0.0
	var back := 0.0
	for i in range(60):
		m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
		forward = minf(forward,tilt.rotation.x)
		back = maxf(back,tilt.rotation.x)
	check(forward < -0.1,"Stopping from a run it tips forward (%.2f rad)" % forward)
	check(back > 0.01,"And wobbles back past upright (%.2f rad)" % back)
	# The chest's lean: walking, running, running uphill (a cycle each).
	var chest := skeleton.find_bone("chest")
	var leans := []
	for gait: Array in [[0.35,ground],[1.0,ground],[1.0,func(p: Vector2) -> float: return -0.3*p.y]]:
		m.reset(Vector3.ZERO,0.0)
		figure.settle()
		var mean := 0.0
		for i in range(90):
			m.step(DT,Vector2(0.0,-float(gait[0])),PilotMotor.RUN,false,gait[1],slide)
			figure.drive(m.pose(),DT)
			if i >= 70: mean += _forward_lean(figure,tilt,skeleton,chest)/20.0
		leans.append(mean)
	check(leans[1] > leans[0]+0.1,"Running, its chest leans further forward than walking (%.2f rad, %.2f)" % [leans[1],leans[0]])
	check(leans[2] > leans[1]+0.08,"And further still running uphill (%.2f rad)" % leans[2])
	# Turning left at a run: the chest rolls left and the head looks further
	# left than the body faces.
	m.reset(Vector3.ZERO,0.0)
	figure.settle()
	for i in range(40):
		m.step(DT,Vector2(0.0,-1.0),PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
	var looked := 0.0
	var rolled := 0.0
	for i in range(12):
		m.step(DT,Vector2(-1.0,0.0),PilotMotor.RUN,false,ground,slide)
		figure.drive(m.pose(),DT)
		var body := figure.global_basis*tilt.basis
		var face := skeleton.global_basis*skeleton.get_bone_global_pose(head).basis
		# The head's turn about up past the body's, left positive.
		var ahead := -(body.inverse()*face).z
		looked = maxf(looked,atan2(-ahead.x,-ahead.z))
		# The chest's up leaning left (-X) in the world, past the body's own.
		var up := (skeleton.global_basis*skeleton.get_bone_global_pose(chest).basis).y.normalized()
		rolled = maxf(rolled,-(body.inverse()*up).x)
	check(rolled > 0.15,"Turning, its chest rolls into the turn (%.2f)" % rolled)
	check(looked > 0.1,"And its head looks into it (%.2f rad)" % looked)
	await process_frame

## How far the chest's up leans forward of the body's up, radians.
func _forward_lean(figure: Node3D, tilt: Node3D, skeleton: Skeleton3D, chest: int) -> float:
	var body := figure.global_basis*tilt.basis
	var up := (body.inverse()*(skeleton.global_basis*skeleton.get_bone_global_pose(chest).basis).y).normalized()
	# The figure faces -Z: forward is -Z.
	return atan2(-up.z,up.y)

## Puffs spawned and not yet gone.
func _alive(puffs: Node3D) -> int:
	var n := 0
	for life: float in puffs._life: if life > 0.0: n += 1
	return n

## The ankle in the world.
func _at(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)
