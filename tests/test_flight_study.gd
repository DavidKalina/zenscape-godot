extends SceneTree
## The flight study (studies/flight_study.tscn), headless: the course
## stands, a station flown by the sharp bot through the study's own tick
## ends with the report up and the run saved; two ratings land in the run's
## file; a station left mid-run is abandoned cleanly and a person's flight
## (no input) starts it afresh.
##   godot --headless --path . --script tests/test_flight_study.gd
const Course = preload("res://scripts/flight_course.gd")
const Log = preload("res://scripts/flight_log.gd")
const DT := 1.0/60.0
const DIR := "user://flight_runs_test_study"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("flight study test timed out"); quit(2))
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = DIR
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	check(study.station.id == Course.STATIONS[0].id and study.run != null,"It opens on the first station, flying")
	check(study.find_children("Station_*","",false,false).size() == Course.STATIONS.size(),"Every station stands")
	# The sharp bot flies the gentle arc through the study's tick.
	study.pilot = "sharp"
	study.start(Course.station("gentle_arc"))
	var frames := 0
	while not study.run.done and frames < 60*40:
		study.tick(DT)
		frames += 1
	check(study.run.done and study._report.visible,"The run ends with the report up (%.1f s)" % study.run.t)
	check(study.last_path != "" and FileAccess.file_exists(study.last_path),"The run is saved (%s)" % study.last_path.get_file())
	check(study.asking == "","A bot's run asks for no rating")
	# A person's run asks for difficulty, then fun, saved into the file.
	study.pilot = "human"
	study.start(Course.station("open_swoop"))
	check(not study._report.visible and study.run.pilot == "human","A person's run starts afresh, the report gone")
	for i in range(30): study.tick(DT)
	check(not study.run.done and study.run.t > 0.4,"With no input the plane flies on (%.2f s)" % study.run.t)
	study.start(Course.station("open_swoop"))
	frames = 0
	while not study.run.done and frames < 60*45:
		study.tick(DT)
		frames += 1
	check(study.run.done and study.asking == "difficulty","Hands off, the run ends (%s) and asks how hard it felt" % study.run.ended)
	study.rate(4)
	check(study.asking == "fun","Then how fun")
	study.rate(2)
	var saved := Log.read(study.last_path)
	check(saved.get("rating",{}).get("difficulty",0) == 4.0 and saved.get("rating",{}).get("fun",0) == 2.0,"Both ratings are in the run's file (%s)" % [saved.get("rating",{})])
	check(saved.get("pilot","") == "human" and saved.has("metrics"),"As a person's run with its numbers")
	for i in range(30): study.tick(DT)
	check(study.run.plane.speed > 5.0,"After the end the plane flies on unrecorded")
	print("flight study: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
