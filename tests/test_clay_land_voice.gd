extends SceneTree
## The clay's land voice (scripts/clay_sound.gd): a rising pull rumbles on its
## bed and gives in lurches, more of them the faster it rises; a still hold, a
## slow pull and a sinking one never lurch; the Wire's cut grinds instead.
## Lurch takes never repeat back to back. Wiring only: it hears nothing, and
## an ear has to judge the sound itself.
##
##   Godot --headless --path . --script res://tests/test_clay_land_voice.gd

const ClaySound = preload("res://scripts/clay_sound.gd")
const STEP := 1.0/60.0

## A stand-in for LandClay: the fields ClaySound reads, and its signal.
class FakeClay extends Node:
	signal sounded(cue: StringName, at: Vector3, strength: float)
	enum State { IDLE, PENDING, DRAG, HOLD, RUN, PAINT }
	var state := State.IDLE
	var tool_id := "mountain"
	var tool: Object
	var verb := "peak"
	var speed := 0.0
	var rub := 0.0
	var center := Vector2(1.0,2.0)
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
var sound: Node
var clay: FakeClay
var tool: FakeTool

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	clay = FakeClay.new()
	root.add_child(clay)
	root.add_child(clay.editor.terrain)
	sound = ClaySound.new()
	root.add_child(sound)
	sound.setup(clay)
	tool = FakeTool.new()
	clay.tool = tool
	for i in range(3): await process_frame
	check(sound._takes_for("land-lurch").size() >= 4,"lurch has several takes")
	check(sound._takes_for("land-grind").size() >= 4,"grind has several takes")
	check(sound._voices[ClaySound.RUMBLE].stream != null,"the rumble bed loads")
	check(sound._voices[ClaySound.GRIND].stream != null,"the grind bed loads")

	# A fast mountain pull: 7 m/s of rise for two seconds.
	clay.state = FakeClay.State.HOLD
	var fast := pull(7.0/60.0,120)
	check(fast.lurch >= 3,"a fast pull lurches (%d)" % fast.lurch)
	check(fast.repeats == 0,"no lurch take plays twice running (%d)" % fast.repeats)
	check(fast.grind == 0,"a mountain pull does not grind")
	check(sound._gain[ClaySound.RUMBLE] > 0.5,"a fast pull brings the rumble bed up (%.2f)" % sound._gain[ClaySound.RUMBLE])
	# Held still at the top: the bed lets go and nothing lurches.
	var still := pull(0.0,90)
	check(still.lurch == 0,"a still hold does not lurch (%d)" % still.lurch)
	check(sound._gain[ClaySound.RUMBLE] < 0.05,"a still hold lets the rumble go (%.2f)" % sound._gain[ClaySound.RUMBLE])
	# Slower pulls lurch less, a creep not at all, a sinking one never.
	var steady := pull(1.5/60.0,120)
	check(steady.lurch < fast.lurch,"a steady pull lurches less than a fast one (%d < %d)" % [steady.lurch,fast.lurch])
	check(pull(0.2/60.0,90).lurch == 0,"a creeping pull does not lurch")
	check(pull(-7.0/60.0,60).lurch == 0,"a sinking pull does not lurch")

	# The Wire's cut drawing through: grinding, not lurching.
	clay.state = FakeClay.State.RUN
	clay.tool_id = "wire"
	tool.running = true
	tool.share = 0.0
	var cut := {"lurch":0,"grind":0}
	var before := counts()
	for i in range(40):
		tool.share += 0.02
		frame()
	var after := counts()
	cut.lurch = after.lurch-before.lurch
	cut.grind = after.grind-before.grind
	check(cut.grind >= 2,"the wire's cut grinds (%d)" % cut.grind)
	check(cut.lurch == 0,"the wire's cut does not lurch")
	check(sound._gain[ClaySound.GRIND] > 0.5,"the wire's cut brings the grind bed up (%.2f)" % sound._gain[ClaySound.GRIND])
	check(sound._gain[ClaySound.RUMBLE] < 0.05,"the wire's cut leaves the deep rumble out")

	print("PASS: clay land voice lurches, holds still and grinds" if failures == 0 else "FAIL: clay land voice")
	quit(1 if failures else 0)

## `frames` frames of a hold whose lift moves `step` a frame, at real time (the
## cues' gaps are wall-clock). The land players are stopped each frame so the
## count is the beat's, not the stack's.
func pull(step: float, frames: int) -> Dictionary:
	var before := counts()
	var repeats := 0
	var last: int = sound._last_take.get(&"lurch",-1)
	var played: int = before.lurch
	for i in range(frames):
		tool.lift += step
		frame()
		var now := counts()
		if now.lurch > played:
			if sound._last_take[&"lurch"] == last: repeats += 1
			last = sound._last_take[&"lurch"]
			played = now.lurch
	var after := counts()
	return {"lurch":after.lurch-before.lurch,"grind":after.grind-before.grind,"repeats":repeats}

func frame() -> void:
	for p in sound._land: p.stop()
	sound._process(STEP)
	OS.delay_msec(roundi(STEP*1000.0))

func counts() -> Dictionary:
	return {"lurch":int(sound.counts.get(&"lurch",[0,0])[0]),"grind":int(sound.counts.get(&"grind",[0,0])[0])}

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("ok: ",message)
