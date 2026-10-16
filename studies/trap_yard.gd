extends "res://studies/character_study.gd"
## The trap yard: the
## greybox traps side by side, each in its own lane on a start deck and an
## end deck with the drop between, for tuning. The pilot is the character
## study's (this extends it, as studies/interactables_yard.gd does): the
## same motor, figure, camera, F1 numbers, F2 feel. The traps are stepped
## by a TrapField (scripts/traps/trap_field.gd) in the study's
## `foot_pieces` slot.
##   1.. one station per trap in TrapRegistry order (the number key goes to it)
## `--trap=<name>` (or its number) starts at that trap's entry, a run-up
## back from it, facing along the route. R puts you back at the start; any
## placing (R, a number key, falling out) puts the traps back as built.
##   godot --path . res://studies/trap_yard.tscn -- --no-title --trap=voussoirs
## `--knob=<key>=<value>` (repeatable) overrides that trap's knobs, e.g.
## `--trap=seesaw_drop --knob=block_mass=600 --knob=hook=12`.
##
## To add a trap: write it to scripts/traps/trap.gd's contract, then add
## one line to scripts/traps/trap_registry.gd (the one trap list).
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const TrapRegistry = preload("res://scripts/traps/trap_registry.gd")

## Lanes are this far apart along x (m); decks this wide, the end deck this
## long past the trap, and the floor a layer down this many jump heights
## under it (the soft fail).
const LANE := 16.0
const DECK_WIDE := 10.0
const END_DECK := 8.0
const DROP_JUMPS := 4.0
const SIGN_UP := 3.0

var traps: Node3D
var _chosen := ""
var _laid: Array = []

func _ready() -> void:
	pack = "trap_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--trap="): _chosen = arg.get_slice("=",1)
	super._ready()

## `--knob=<key>=<value>` (repeatable) overrides the chosen trap's knobs, to
## try numbers without editing: a number, true/false, or a word.
func _knob_args() -> Dictionary:
	var over := {}
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if not arg.begins_with("--knob="): continue
		var pair := arg.trim_prefix("--knob=")
		var value := pair.get_slice("=",1)
		var parsed: Variant = value
		if value.is_valid_float(): parsed = value.to_float()
		elif value == "true" or value == "false": parsed = value == "true"
		over[pair.get_slice("=",0)] = parsed
	return over

## The yard's stations (one per trap), not a pack's file.
func _load_pack() -> void:
	stations = []
	_laid = []
	start = Vector3.ZERO
	start_face = Vector2(0.0,-1.0)
	var drop: float = DROP_JUMPS*float(Trap.pilot().jumps[1])
	lost = -drop-8.0
	var i := 0
	var lane_x := 0.0
	for key: String in TrapRegistry.keys():
		var trap: Node3D = TrapRegistry.make(key)
		if key == _chosen or str(i+1) == _chosen: trap.configure(_knob_args())
		var x := lane_x
		# A trap that flies wide (the ray's loop) asks for lane room east of it.
		lane_x += LANE+(float(trap.call("lane_extra")) if trap.has_method("lane_extra") else 0.0)
		var long: float = trap.length()
		var run_up: float = trap.run_up()
		var spawn := Vector3(x,0.0,run_up)
		trap.position = Vector3(x,0.0,0.0)
		_laid.append(trap)
		var parts: Array = [
			["box",Rect2(x-DECK_WIDE*0.5,0.0,DECK_WIDE,run_up+4.0),-1.0,0.0,"pad"],
			["box",Rect2(x-DECK_WIDE*0.5,-long-END_DECK,DECK_WIDE,END_DECK),-1.0,0.0,"pad"],
			["label",Vector3(x,1.2,-long-END_DECK*0.5),"far deck"],
		]
		# A trap may ask for open void under it (`open_below`): no floor.
		if not (trap.has_method("open_below") and bool(trap.call("open_below"))):
			parts.append(["box",Rect2(x-DECK_WIDE*0.5,-long,DECK_WIDE,long),-drop-1.0,-drop,"floor"])
		stations.append({"key":i+1,"name":"%s (cost %d)" % [key,trap.danger()],"spawn":spawn,"face":Vector2(0.0,-1.0),
			"sign":Vector3(x,SIGN_UP,run_up+2.0),"parts":parts})
		if _chosen == key or _chosen == str(i+1):
			start = spawn
		i += 1
	if start == Vector3.ZERO and not stations.is_empty(): start = stations[0].spawn
	_last_stood = start

## The decks (the pack's parts), then the traps in the field.
func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	for trap: Node3D in _laid: traps.add(trap)

## Set down anywhere: the traps as built.
func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	super.place(at,face)

func _hint_text() -> String:
	return "number keys: a trap's start · R start (traps rebuilt) · F1 numbers · F2 feel · Esc mouse · run across; walking drops you"
