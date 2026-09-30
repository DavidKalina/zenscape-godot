extends SceneTree
## Headless CPU cost of live water around a release (scripts/water_flow.gd):
## a ball landing on a flank (a spring, its bed worn in) and on low ground (a
## burst), then the frames after while the water runs and falls form. Prints
## the synchronous land cost, the worst main-loop gaps, and each part's worst
## (sim step, surface build, mesh publish, falls, edge falls).
## Dummy renderer: shader compiles, uploads and drawing are not measured.
##   perl -e 'alarm 300; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     -s res://tools/probe_water_release_cost.gd -- --modeless [--gdscript-kernels]
const Probe := preload("res://tools/probe_water_flow.gd")
const WaterFlow := preload("res://scripts/water_flow.gd")
var scene: Node3D
var editor: NativeChunkEditor

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("release cost probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-release-cost-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	var waited := 0
	while not scene.shell_ready or scene.get("_chunk_editor") == null:
		await process_frame
		waited += 1
		if waited % 300 == 0: print("waiting: places_ready %s shell_ready %s" % [scene.places_ready,scene.shell_ready])
	editor = scene._chunk_editor
	while scene.places != null and scene.places.busy or editor.forming: await process_frame
	for i in range(600):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	if editor.flow == null or not editor.flow.ready:
		push_error("no live water (run with --modeless)")
		quit(1)
		return
	scene.world_clock.running = false
	var flow: RefCounted = editor.flow
	var data := editor.data
	print("SETUP native %s grid %dx%d cell %.2f points %d" % [flow.native,flow.width,flow.height,flow.cell,data.points.size()])
	for i in range(data.points.size()): data.heights[i] = Probe.land(data.points[i])
	editor.force_refresh()
	await settle()

	# The spring: the parts of `drop`, then the whole landing as the editor runs it.
	var began := Time.get_ticks_usec()
	var course: Dictionary = WaterFlow.descent(data,Probe.HEAD)
	var descent_ms := (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	var bed: Dictionary = WaterFlow.spring_bed(data,course,2,6.0)
	var bed_ms := (Time.get_ticks_usec()-began)/1000.0
	print("SPRING parts: descent %.1f ms (%d points), spring_bed %.1f ms (%s)" % [descent_ms,course.points.size(),bed_ms,"bed" if not bed.is_empty() else "no bed"])
	began = Time.get_ticks_usec()
	editor._flow_landed(Probe.HEAD,6.0,[])
	print("SPRING landing (sync) %.1f ms, springs %d" % [(Time.get_ticks_usec()-began)/1000.0,flow.springs.size()])
	await watch("spring",15.0)

	began = Time.get_ticks_usec()
	editor._flow_landed(Vector2(6.0,6.0),6.0,[])
	print("BURST landing (sync) %.1f ms, bursts %d" % [(Time.get_ticks_usec()-began)/1000.0,flow.bursts.size()])
	await watch("burst",8.0)
	quit(0)

func settle() -> void:
	for i in range(30): await process_frame
	while editor.refresh_pending > 0 or editor.land_settling: await process_frame
	for i in range(30): await process_frame

## Frames for `seconds`: main-loop gaps and each water part's cost that frame.
func watch(label: String, seconds: float) -> void:
	var flow: RefCounted = editor.flow
	var view: Node = editor.flow_view
	var falls: Node = view.falls
	var edge: Node = view.edge_falls
	var frames := []
	var last := Time.get_ticks_usec()
	var t := 0.0
	while t < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		var row := {"t":snappedf(t,0.01),"gap":(now-last)/1000.0,"step":flow.last_step_usec/1000.0,
			"surface":view.last_build_usec/1000.0,"publish":view.last_publish_usec/1000.0,
			"falls":(falls.last_update_usec/1000.0) if falls != null else 0.0,
			"falls_read":(falls.last_read_usec/1000.0) if falls != null else 0.0,
			"edge":(edge.last_update_usec/1000.0) if edge != null and "last_update_usec" in edge else 0.0}
		frames.append(row)
		last = now
		t += 1.0/60.0
	var gaps := frames.map(func(r: Dictionary) -> float: return r.gap)
	gaps.sort()
	var worst := frames.duplicate()
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap > b.gap)
	var peaks := {}
	for key in ["step","surface","publish","falls","falls_read","edge"]:
		peaks[key] = snappedf(frames.reduce(func(m: float, r: Dictionary) -> float: return maxf(m,r[key]),0.0),0.01)
	print("%s: frames %d, gap median %.1f p95 %.1f max %.1f ms; falls shown %d" % [label,frames.size(),gaps[gaps.size()/2],gaps[int(gaps.size()*0.95)],gaps[-1],view.fall_count()])
	print("%s: worst per part %s" % [label,JSON.stringify(peaks)])
	for r in worst.slice(0,6): print("%s:   %s" % [label,JSON.stringify(r)])
