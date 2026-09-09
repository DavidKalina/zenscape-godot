extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/ai-decision-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	await scene._chunk_editor.form_landscape("redwood_grove","",false,37)
	scene.set_building(false)
	scene.set_process(false)
	assert(scene.invite_bigfoot(Vector3.ZERO))
	var origin: Vector3 = scene.creature.position
	var timings := []
	for trial in range(8):
		scene.creature.reset_at(origin)
		scene.brain.reset_behavior()
		scene.brain._rng.seed = 4707+trial
		var start := Time.get_ticks_usec()
		scene.brain._choose_next()
		while scene.brain.choosing: await process_frame
		var elapsed: float = scene.brain.last_choice_slice_usec/1000.0
		timings.append(elapsed)
		if elapsed>8.0: failures += 1
		if scene.brain.phase not in [CreatureBrain.Phase.MOVE,CreatureBrain.Phase.NOTICE]:
			push_error("Decision must produce a reachable destination")
			failures += 1
		for i in range(scene.brain._route.size()-1):
			if not scene.navigation.segment_safe(scene.brain._route[i],scene.brain._route[i+1]):
				push_error("Budgeted route must keep every leg safe")
				failures += 1
		print("AI trial=",trial," peak_slice_ms=",elapsed," slices=",scene.brain.last_choice_slices," total_wall_ms=",(Time.get_ticks_usec()-start)/1000.0)
	# A carried resident or changed map must not receive a stale route later.
	scene.creature.reset_at(origin)
	scene.brain.reset_behavior()
	scene.brain._rng.seed = 4708
	scene.brain._choose_next()
	assert(scene.brain.choosing,"Expensive route yields before completion")
	scene.creature.pick_up()
	for i in range(3): await process_frame
	assert(not scene.brain.choosing and scene.brain._route.is_empty(),"Pickup cancels pending route")
	scene.creature.reset_at(origin)
	scene.brain.reset_behavior()
	scene.brain._rng.seed = 4708
	scene.brain._choose_next()
	scene._paused = true
	for i in range(3): await process_frame
	assert(not scene.brain.choosing and scene.brain._route.is_empty(),"Pause cancels pending route")
	scene._paused = false
	scene.brain.reset_behavior()
	scene.brain._choose_next()
	scene.navigation.begin_rebuild(scene.habitat,scene.habitat.clear_at,0.35,0.3)
	for i in range(3): await process_frame
	assert(not scene.brain.choosing and scene.brain._route.is_empty(),"Map revision cancels pending route")
	print("AI DECISION BUDGET milliseconds=",timings," over_budget=",failures)
	scene.free()
	quit(1 if failures>0 else 0)
