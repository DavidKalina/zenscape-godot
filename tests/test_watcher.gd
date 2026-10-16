extends SceneTree
## The watcher (scripts/kit_isle/watcher.gd, docs/design/watcher/round1.md),
## headless, on the aqueduct isle with --watcher (and --plane-arc: a script
## run otherwise starts the plane repaired): he stands on the south rim's
## turf near the start; his find is the plane's tail fin on the ferry's
## foredeck (docs/design/airship-ferry/round2.md; the game's sky has no
## serpent); with the ferry coming home in sight he turns to it and holds
## his telescope up on it; the find glints through the pilot's telescope
## aimed his way, and not once it's down; near him his line streams in; on
## foot at the find, it's taken.
##   godot --headless --path . --script tests/test_watcher.gd
const DT := 1.0/60.0
const Telescope = preload("res://scripts/telescope.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
var failures := 0
var study: Node3D
var watcher: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("watcher test timed out"); quit(2))
	LaunchArgs.set_override(["--no-title","--watcher","--plane-arc"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	study.chain_on = false
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	await physics_frame
	watcher = study.watcher
	check(watcher != null and watcher.find != null and watcher.find == study.plane_arc.fin_holder(),"With --watcher he stands, the find the tail fin on the ferry")
	if watcher == null or study.sky.ferry == null:
		quit(1)
		return
	study.sky.ferry.manual = true
	_stands()
	_tracks()
	_glints()
	_line()
	_take()
	LaunchArgs.set_override(null)
	print("PASS: watcher" if failures == 0 else "FAIL: watcher (%d)" % failures)
	quit(1 if failures > 0 else 0)

## Frames of the ferry, his frame and the scene's.
func _frames(seconds: float) -> void:
	for i in range(int(round(seconds/DT))):
		study.sky.ferry.step(DT)
		watcher._process(DT)
		study.tick(DT)

func _stands() -> void:
	var at: Vector3 = watcher.global_position
	var start: Vector3 = study.parked_at
	check(Vector2(at.x-start.x,at.z-start.z).length() < 25.0,"He stands near the start (%.1f m from the parked plane, at %s)" % [Vector2(at.x-start.x,at.z-start.z).length(),at])
	check(absf(at.y-30.0) < 2.0 and at.z > 10.0,"On the south rim's turf (%s)" % at)

func _tracks() -> void:
	var ferry: Node3D = study.sky.ferry
	ferry.set_clock(ferry.clock_before("home",30.0))
	_frames(4.0)
	var to: Vector3 = watcher.find.global_position-watcher.eye()
	var off := rad_to_deg(watcher.gaze().angle_to(to))
	check(watcher.sees and watcher.state in ["watch","rest"],"The ferry coming home, he sees the find (%s, %.0f m)" % [watcher.state,to.length()])
	var worst := 0.0
	var up_frames := 0
	for i in range(180):
		_frames(DT)
		if watcher.state == "watch" and watcher.up >= 1.0:
			up_frames += 1
			worst = maxf(worst,rad_to_deg(watcher.gaze().angle_to(watcher.find.global_position-watcher.eye())))
	check(up_frames > 0 and worst < 10.0,"Telescope up, his gaze stays on the find as it flies by (worst %.1f deg over %d frames; at first %.1f)" % [worst,up_frames,off])

func _glints() -> void:
	var b: Node = study.telescope
	var at: Vector3 = watcher.global_position+Vector3(5.0,0.0,-0.5)
	study.place(at,Vector2(0.0,1.0))
	_frames(0.5)
	study.script_telescope = true
	for i in range(30):
		var to: Vector3 = watcher.find.global_position-b.eye()
		b.yaw = atan2(-to.x,-to.z)
		b.pitch = atan2(to.y,Vector2(to.x,to.z).length())
		_frames(DT)
	var shown: Array = b.glints.map(func(g: Dictionary) -> Node: return g.node)
	check(shown.has(watcher.find),"Through the telescope, aimed his way, the find glints (%.0f m off)" % b.eye().distance_to(watcher.find.global_position))
	study.script_telescope = false
	_frames(0.6)
	check(b.glints.is_empty() and not b._overlay.visible,"Lowered, no glint and no overlay to draw one")

func _line() -> void:
	study.place(watcher.global_position+Vector3(2.5,0.0,0.0),Vector2(-1.0,0.0))
	_frames(0.6)
	check(watcher.speaking() and watcher.state == "rest","Near him his line starts and he lowers it (%s)" % watcher.state)
	var chars := int(watcher._line.visible_characters)
	check(chars > 0 and chars < watcher.FERRY_LINE.length(),"It streams in (%d of %d)" % [chars,watcher.FERRY_LINE.length()])
	check(not study.get_tree().paused,"Nothing pauses")
	study.place(watcher.global_position+Vector3(14.0,0.0,-8.0),Vector2(1.0,0.0))
	_frames(1.0)
	check(not watcher.speaking(),"Walked off mid-line, it fades")

func _take() -> void:
	var find: Node3D = watcher.find
	study.place(find.global_position-Vector3.UP*0.5,Vector2(0.0,-1.0))
	watcher._check_take()
	check(watcher.taken and watcher.find == null and watcher.state == "done","At the find on foot, it's taken")
	var moments: Node = study.get("_moments")
	check(moments != null and str(moments.last_pop).contains("tail fin"),"A moments pop says so (%s)" % (moments.last_pop if moments != null else ""))
