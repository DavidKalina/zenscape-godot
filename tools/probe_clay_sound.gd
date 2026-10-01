extends SceneTree
## Headless wiring probe for scripts/clay_sound.gd (docs/scenic/sound.md,
## "Tool sound"): every cue has takes on disk and plays, gaps hold, a take is
## not repeated, and the voices rise with a drag, a hold and the Wire's cut,
## then fall away. It hears nothing; an ear has to judge the sound itself.
##
##   Godot --headless --path . --script res://tools/probe_clay_sound.gd

const ClaySound = preload("res://scripts/clay_sound.gd")

## A stand-in for LandClay: the fields ClaySound reads, and its signal.
class FakeClay extends Node:
	signal sounded(cue: StringName, at: Vector3, strength: float)
	enum State { IDLE, PENDING, DRAG, HOLD, RUN }
	var state := State.IDLE
	var tool_id := "hand"
	var tool: Object
	var verb := ""
	var speed := 0.0
	var rub := 0.0
	var center := Vector2.ZERO
	var last_plate: Variant = null
	var editor := FakeEditor.new()
	func ground_at(p: Vector2) -> Vector3: return Vector3(p.x,0.0,p.y)

class FakeEditor extends RefCounted:
	var terrain := Node3D.new()

class FakeTool extends RefCounted:
	var lift := 0.0
	var share := 1.0
	var running := false
	func busy() -> bool: return running
	func cut_share() -> float: return share

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok: print("PASS: ",what)
	else:
		failures += 1
		print("FAIL: ",what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var clay := FakeClay.new()
	root.add_child(clay)
	root.add_child(clay.editor.terrain)
	var sound: Node = ClaySound.new()
	root.add_child(sound)
	sound.setup(clay)
	# A player's pause only takes once it has run a frame.
	for i in range(3): await process_frame
	# Every cue has takes and plays.
	for cue: StringName in ClaySound.CUES:
		var clip: String = ClaySound.CUES[cue].clip
		check(not sound._takes_for(clip).is_empty(),"%s has takes (%s)" % [cue,clip])
		sound._last_at.erase(cue)
		for p in sound._land+sound._ui: p.stop()
		check(sound.play(cue,Vector3.ZERO,0.7),"%s plays" % cue)
	# A cue inside its gap is held back; the static path reaches the node.
	check(not sound.play(&"mesa_break",Vector3.ZERO),"mesa_break inside its gap is held back")
	sound._last_at.erase(&"ui_pick")
	for p in sound._ui: p.stop()
	ClaySound.cue(&"ui_pick")
	check(int(sound.counts[&"ui_pick"][0]) == 2,"ClaySound.cue reaches the running node")
	# No take twice running.
	var repeats := 0
	for i in range(40):
		var was: int = sound._last_take.get(&"poke",-1)
		sound._last_at.erase(&"poke")
		for p in sound._land: p.stop()
		sound.play(&"poke",Vector3.ZERO)
		if sound._last_take[&"poke"] == was: repeats += 1
	check(repeats == 0,"poke never repeats a take (%d repeats)" % repeats)
	# The signal path.
	sound._last_at.erase(&"crack")
	var before: int = sound.counts.get(&"crack",[0,0])[0]
	for p in sound._land: p.stop()
	clay.sounded.emit(&"crack",Vector3.ZERO,1.0)
	check(int(sound.counts[&"crack"][0]) == before+1,"LandClay.sounded plays a cue")
	# Voices: a fast Modeller groove, then idle.
	var tool := FakeTool.new()
	clay.tool = tool
	clay.state = FakeClay.State.DRAG
	clay.verb = "groove"
	clay.speed = 900.0
	clay.last_plate = Vector2.ZERO
	for i in range(30): sound._process(1.0/60.0)
	check(sound._gain[ClaySound.GROOVE] > 0.9,"a fast groove brings the groove voice up (%.2f)" % sound._gain[ClaySound.GROOVE])
	check(not sound._voices[ClaySound.GROOVE].stream_paused,"the groove voice plays")
	clay.rub = 1.0
	for i in range(30): sound._process(1.0/60.0)
	check(sound._gain[ClaySound.RUB] > 0.9 and sound._gain[ClaySound.GROOVE] < 0.3,"a fast rub crossfades to the rub voice")
	clay.state = FakeClay.State.IDLE
	for i in range(90): sound._process(1.0/60.0)
	await process_frame
	sound._process(1.0/60.0)
	check(sound._voices[ClaySound.RUB].stream_paused and sound._voices[ClaySound.GROOVE].stream_paused,"voices pause once the drag ends")
	# A rising pinch: stretch and rumble.
	clay.state = FakeClay.State.HOLD
	for i in range(30):
		tool.lift += 0.1
		sound._process(1.0/60.0)
	check(sound._gain[ClaySound.STRETCH] > 0.5,"a rising pinch stretches (%.2f)" % sound._gain[ClaySound.STRETCH])
	check(sound._gain[ClaySound.RUMBLE] > 0.3,"a rising pinch rumbles (%.2f)" % sound._gain[ClaySound.RUMBLE])
	for i in range(60): sound._process(1.0/60.0)
	check(sound._gain[ClaySound.STRETCH] < 0.05,"a still hold falls quiet")
	# The Wire's cut drawing through.
	clay.state = FakeClay.State.RUN
	clay.tool_id = "wire"
	tool.running = true
	tool.share = 0.0
	for i in range(30):
		tool.share += 0.02
		sound._process(1.0/60.0)
	check(sound._gain[ClaySound.CUT] > 0.5,"the wire's cut runs (%.2f)" % sound._gain[ClaySound.CUT])
	print("Failures: ",failures)
	quit(1 if failures > 0 else 0)
