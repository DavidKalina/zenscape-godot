extends "res://studies/character_study.gd"
## The wind-horn study: the ruin
## kit's wind-horn (scripts/ruin_kit_horn.gd, its runtime
## scripts/wind_horn.gd) on flat ground. Its head tracks the pilot, and on a
## loop it draws its breath (the tell, WINDUP s) and fires (the kick and the
## puff), then rests. The pilot is the character study's: run about, climb
## onto the pedestal and its cap (the standable top).
##   P  knock it out for DISABLE s (slumps, grinds back up)
##   1  in front of it (R comes back)   2  30 m out   3  on the pedestal
## Knobs: --horn-weathered=<0..1> (0.4), --horn-seed=<n> (1). `--blow`: the
## real blow: it watches you and
## gusts you when it notices you (run, hop, splash); creep past it unseen.
##   ./run-wind-horn.command
const Horn = preload("res://scripts/ruin_kit_horn.gd")

const GROUND := 60.0
## The tell's length (s: the dragon's air blast wind-up is about 0.8), the
## rest between shots, and how long P knocks it out.
const WINDUP := 0.8
const REST := 2.2
const DISABLE := 4.0

var horn_weathered := 0.4
var horn_seed := 1
var horn: Node3D
var rig: Node
var _cycle := 0.0
var blow := false
var _watching := false

func _ready() -> void:
	pack = "wind_horn"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--horn-weathered="): horn_weathered = clampf(arg.get_slice("=",1).to_float(),0.0,1.0)
		elif arg.begins_with("--horn-seed="): horn_seed = arg.get_slice("=",1).to_int()
		elif arg == "--blow": blow = true
	super._ready()

func _load_pack() -> void:
	var front := Vector3(0.0,0.0,9.0)
	stations = [
		{"key":1,"name":"in front","spawn":front,"face":Vector2(0.0,-1.0),"parts":[["box",Rect2(-GROUND,-GROUND,GROUND*2.0,GROUND*2.0),-1.0,0.0,"floor"]]},
		{"key":2,"name":"30 m out","spawn":Vector3(0.0,0.0,30.0),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"on the pedestal","spawn":Vector3(0.0,Horn.PED_H,Horn.PED_R-0.5),"face":Vector2(0.0,-1.0),"parts":[]},
	]
	start = front
	start_face = Vector2(0.0,-1.0)
	lost = -20.0
	_last_stood = start

func _build_room() -> void:
	super._build_room()
	horn = Horn.wind_horn(horn_seed,horn_weathered)
	add_child(horn)
	rig = Horn.rig(horn)

func _process(delta: float) -> void:
	super._process(delta)
	if rig == null or not walk_ready: return
	if blow:
		if not _watching:
			rig.watch(motor)
			_watching = true
		return
	rig.aim_at(motor.feet+Vector3(0.0,0.6,0.0),delta)
	if rig.is_disabled():
		_cycle = 0.0
		return
	var was := _cycle
	_cycle += delta
	if _cycle < REST:
		rig.tell(-1.0)
	elif _cycle < REST+WINDUP:
		rig.tell((_cycle-REST)/WINDUP)
	else:
		if was < REST+WINDUP: rig.fired()
		if _cycle > REST+WINDUP+0.3: _cycle = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P and rig != null:
		rig.disabled(DISABLE)
		return
	super._unhandled_input(event)

func _hint_text() -> String:
	if blow: return "Wind-horn (blowing) · run or hop in its sight: it draws breath and gusts you · creep (light stick) to pass unseen · P knock it out · 1 front · 2 30 m out · 3 pedestal · R start · F1 numbers · Esc mouse"
	return "Wind-horn · it tracks you, draws breath and blows · climb the pedestal and its cap · P knock it out · 1 front · 2 30 m out · 3 pedestal · R start · F1 numbers · Esc mouse"
