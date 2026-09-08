extends SceneTree
## Process-frame wall intervals; not GPU or presentation timing.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440, 900)
	var study = load("res://studies/visual_benchmark.tscn").instantiate()
	root.add_child(study)
	while not study.ready_for_capture: await process_frame
	study.scene.set_process_input(false)
	study.scene.set_process_unhandled_input(false)
	study.scene._orbit_delta = Vector2.ZERO
	study.scene._pan_delta = Vector2.ZERO
	var results := []
	for enhanced in [false, true, false]:
		study.set_enhanced(enhanced)
		await create_timer(2.0).timeout
		var samples: Array[float] = []
		var start := Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec() - start < 4000000:
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		var total := 0.0
		for sample in samples: total += sample
		results.append({"enhanced":enhanced, "frames":samples.size(), "mean_ms":total/samples.size(), "p95_ms":samples[int(samples.size()*0.95)], "p99_ms":samples[int(samples.size()*0.99)], "max_ms":samples.back(), "pixels":[root.size.x,root.size.y], "fps_cap":Engine.max_fps})
	var file := FileAccess.open("res://docs/visual-benchmark/pacing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	print("BENCHMARK PACING ", JSON.stringify(results))
	study.free()
	await process_frame
	quit()
