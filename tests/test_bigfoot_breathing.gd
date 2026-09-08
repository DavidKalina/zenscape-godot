extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	actor.set_process(false)
	# Settle the normal entry blend before measuring the looping clip.
	for i in range(12): actor.advance(1.0/60.0)
	actor.player.seek(0.0,true)
	actor.player.advance(0.0)
	check(actor._mouth!=null and actor._breath!=null,"Animated mouth attachment and breath are present")
	if actor._mouth==null: quit(1); return
	var skeleton := actor.skeleton
	var head := skeleton.find_bone("Head")
	var right := skeleton.find_bone("Foot_R")
	var left := skeleton.find_bone("Foot_L")
	var low := INF
	var high := -INF
	var feet: Array[Vector3] = []
	var drift := 0.0
	for frame in range(312):
		actor.advance(1.0/60.0)
		var y := skeleton.get_bone_global_pose(head).origin.y
		low = minf(low,y); high = maxf(high,y)
		var positions: Array[Vector3] = [skeleton.get_bone_global_pose(right).origin,skeleton.get_bone_global_pose(left).origin]
		if feet.is_empty(): feet = positions
		for i in range(2): drift = maxf(drift,positions[i].distance_to(feet[i]))
		if frame==100: check(actor._breath.emitted==0,"No mist during inhalation")
	check(high-low>0.025 and high-low<0.065,"Subtle visible bob of a few centimetres")
	check(drift<0.0001,"Feet stay planted while breathing")
	check(actor._breath.emitted>=8 and actor._breath.emitted<=12,"One restrained exhalation per cycle")
	print("BREATH mouth=",actor._mouth.global_position," forward=",actor._mouth.global_basis.z," bob=",high-low," foot drift=",drift," puffs=",actor._breath.emitted)
	var count: int = actor._breath.emitted
	var ages: Array = actor._breath.puffs.map(func(puff): return puff.age)
	for i in range(30): actor.advance(0.0)
	check(actor._breath.emitted==count,"Pause prevents new breath")
	for i in range(ages.size()): check(actor._breath.puffs[i].age==ages[i],"Pause freezes existing mist")
	actor.pick_up()
	for i in range(180): actor.advance(1.0/60.0)
	check(actor._breath.emitted==count,"Held animation does not emit idle breath")
	for puff in actor._breath.puffs: check(not puff.mesh.visible,"Old mist dissipates after interruption")
	actor.reset_at(Vector3(5,0,0))
	for puff in actor._breath.puffs: check(not puff.mesh.visible,"Reset clears world-space plumes")
	actor.free()
	print("BIGFOOT BREATHING failures=",failures)
	quit(1 if failures else 0)
