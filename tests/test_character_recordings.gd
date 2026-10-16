extends SceneTree
## The character study's recordings (scripts/character_recording.gd),
## headless: a run driven here (a running jump, a long jump chain, a twirl)
## is recorded, saved through JSON and replayed to within a millimetre of
## where it ended, so a replay is the run; then every run saved under
## studies/character_runs/ (the user's, each the platforming they want
## possible) is replayed on the feel now, in the room or the island pack it
## was made in, and must end within REACH of its recorded end. One that
## doesn't says where it strayed and names the feel numbers changed since.
##   godot --headless --path . --script tests/test_character_recordings.gd
const Recording = preload("res://scripts/character_recording.gd")
const DT := 1.0/60.0
const REACH := 0.25
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("character recordings test timed out"); quit(2))
	await _open("")
	_round_trip()
	# The saved runs, by the pack each was made in.
	var by_pack := {}
	for path in Recording.paths(): by_pack.get_or_add(str(Recording.read(path).get("pack","")),[]).append(path)
	if by_pack.is_empty(): print("no saved runs under %s yet" % Recording.DIR)
	for pack: String in by_pack:
		if pack != study.pack: await _open(pack)
		_saved_runs(by_pack[pack])
	print("PASS: character recordings" if failures == 0 else "FAIL: character recordings (%d)" % failures)
	quit(1 if failures else 0)

## Driven, recorded, saved to a scratch folder, read back and replayed.
func _round_trip() -> void:
	var m: RefCounted = study.motor
	study.go_to(13)
	for i in range(10): _drive(Vector2.ZERO,false,false,false,DT)
	var rec := Recording.new(m,study.station_near(m.feet),study._feel_now())
	study._rec = rec
	var way := Vector2(1.0,0.0)
	for i in range(420):
		var dt := DT*(1.0+0.3*sin(i*0.7))
		var crouch := i > 60
		var jump: bool = i == 40 or (i > 70 and m.grounded and i%2 == 0)
		var twirl: bool = i > 70 and not m.grounded and m.velocity.y < 0.0 and i%37 == 0
		_drive(way if i < 200 else way.rotated(0.6),jump,crouch,twirl,dt)
	study._rec = null
	rec.label = "round trip"
	var dir := "user://character_runs_test"
	var path: String = rec.save(dir)
	var data := Recording.read(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var moves: Dictionary = data.get("summary",{}).get("moves",{})
	check(int(moves.get("long",0)) >= 2 and moves.has("jump"),"The recording's beats name its moves: %s" % [moves])
	check(study.begin_replay(data),"It replays")
	while study.replay_step(): pass
	var v: Dictionary = study.replay_verdict()
	check(float(v.off) < 0.001,"Replayed from its JSON it ends %.5f m from where it did (%d ticks, %.1f m across)" % [v.off,rec.size(),float(data.summary.across)])
	study._replay = {}

## The study, in the room ("") or a pack.
func _open(pack: String) -> void:
	if study != null:
		study.queue_free()
		await process_frame
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	study.pack = pack
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	# The runs were recorded with the wall run, now an unlock `--wallrun` gives.
	study.motor.wallrun_on = true

## These saved runs replayed on the feel now.
func _saved_runs(paths: Array) -> void:
	for path: String in paths:
		var data := Recording.read(path)
		var name := "%s (\"%s\")" % [path.get_file(),data.get("label","")]
		if not study.begin_replay(data):
			check(false,"%s replays" % name)
			continue
		while study.replay_step(): pass
		var v: Dictionary = study.replay_verdict()
		var changed: Array = v.changed
		var why := ""
		var strayed: Dictionary = v.strayed
		if float(v.off) >= REACH and not strayed.is_empty():
			var after: Dictionary = strayed.after
			why = " · strayed from it at %.2f s%s" % [strayed.t,"" if after.is_empty() else ", after its %s at %.2f s (%s)" % [after.what,after.t,after.at]]
		var feel := "" if changed.is_empty() else " · feel changed since: %s" % ", ".join(changed)
		if float(v.off) >= REACH and changed.is_empty(): feel = " · the feel's numbers are as recorded: the motor's code changed"
		check(float(v.off) < REACH,"%s ends %.2f m from its recorded end%s%s" % [name,v.off,why,feel])
		study._replay = {}

func _drive(want: Vector2, jump: bool, crouch: bool, twirl: bool, dt: float) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(dt)
