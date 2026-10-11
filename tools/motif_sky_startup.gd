extends SceneTree
## Startup and frame cost of a kit isle scene, headless (docs/scenic/
## motif-sky.md): the time from loading the scene to walking (`isle_up`),
## then every frame's wall time for SECONDS of frames after it (mean, p95,
## worst, frames over 50 ms), and when the motif isles all stand (the
## aqueduct isle's `motifs`, if any).
##   godot --headless --path . --script tools/motif_sky_startup.gd -- [--scene=res://studies/aqueduct_isle.tscn] [--seconds=20] [scene flags, e.g. --no-motifs; --motifs-later for the headless default]
const LaunchArgs = preload("res://scripts/launch_args.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var path := "res://studies/aqueduct_isle.tscn"
	var seconds := 20.0
	# Headless the motif isles are built only near the eye unless asked.
	var extra := PackedStringArray(["--no-title","--motifs-now"])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): path = arg.get_slice("=",1)
		elif arg.begins_with("--seconds="): seconds = float(arg.get_slice("=",1))
		else: extra.append(arg)
	# --motifs-later: the headless default (built only near the eye).
	if extra.has("--motifs-later"): extra.remove_at(extra.find("--motifs-now"))
	LaunchArgs.set_override(extra)
	var began := Time.get_ticks_usec()
	var scene: Node = load(path).instantiate()
	scene.set("scripted",true)
	root.add_child(scene)
	current_scene = scene
	while not bool(scene.get("isle_up")): await process_frame
	var up := (Time.get_ticks_usec()-began)/1000.0
	print("startup: %s up (walking) in %.0f ms" % [path.get_file(),up])
	# Uncapped: each frame's wall time is its cost.
	Engine.max_fps = 0
	var frames: Array[float] = []
	var all_at := -1.0
	var clock := Time.get_ticks_usec()
	var t0 := clock
	while (Time.get_ticks_usec()-t0)/1.0e6 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-clock)/1000.0)
		clock = now
		var motifs: Variant = scene.get("motifs")
		if all_at < 0.0 and motifs != null and bool(motifs.call("all_stood")):
			all_at = (now-t0)/1000.0
			print("startup: every motif isle stands %.0f ms after walking (%d frames)" % [all_at,frames.size()])
	if frames.is_empty(): frames.append(0.0)
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	var over := 0
	for f: float in frames:
		total += f
		if f > 50.0: over += 1
	print("frames: %d in %.0f s, mean %.1f ms, p95 %.1f ms, worst %.1f ms, %d over 50 ms" % [frames.size(),seconds,total/frames.size(),sorted[int(sorted.size()*0.95)],sorted[-1],over])
	var worst: Array = []
	for i in range(frames.size()):
		if frames[i] > 50.0: worst.append("%d:%.0f" % [i,frames[i]])
	if not worst.is_empty(): print("frames over 50 ms (index:ms): %s" % " ".join(worst.slice(0,40)))
	var refs: Array = []
	var motifs: Variant = scene.get("motifs")
	if motifs != null:
		for isle: Node in motifs.isles: refs.append(weakref(isle.motif))
	scene.queue_free()
	for i in range(3): await process_frame
	var alive := refs.filter(func(r: WeakRef) -> bool: return r.get_ref() != null).size()
	if not refs.is_empty(): print("motif builders alive after the scene: %d of %d" % [alive,refs.size()])
	LaunchArgs.set_override(null)
	quit(0)
