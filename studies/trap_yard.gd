extends "res://studies/character_study.gd"
## The trap yard (docs/design/roguelike/traps-round1.md): the roguelike's
## greybox traps side by side, each in its own lane on a start deck and an
## end deck with the drop between, for tuning. The pilot is the character
## study's (this extends it, as studies/interactables_yard.gd does): the
## same motor, figure, camera, F1 numbers, F2 feel. The traps are stepped
## by a TrapField (scripts/traps/trap_field.gd) in the study's
## `foot_pieces` slot.
##   1.. one station per trap in TRAPS order (the number key goes to it)
## `--trap=<name>` (or its number) starts at that trap's entry, a run-up
## back from it, facing along the route. R puts you back at the start; any
## placing (R, a number key, falling out) puts the traps back as built.
##   godot --path . res://studies/trap_yard.tscn -- --no-title --trap=voussoirs
##
## To add a trap: write it to scripts/traps/trap.gd's contract, then add
## one line to TRAPS below.
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const Seesaw = preload("res://scripts/traps/trap_seesaw.gd")
const Wind = preload("res://scripts/traps/trap_wind.gd")
const WindBlaster = preload("res://scripts/traps/trap_wind_blaster.gd")
const Sluice = preload("res://scripts/traps/trap_sluice.gd")
const Logs = preload("res://scripts/traps/trap_logs.gd")
const Flip = preload("res://scripts/traps/trap_flip.gd")
const Tumble = preload("res://scripts/traps/trap_tumble.gd")
const Ray = preload("res://scripts/traps/trap_ray.gd")

## The slots: name -> the trap's script. One line per trap.
const TRAPS := {
	"voussoirs": Voussoirs,
	"seesaw": Seesaw,
	"wind": Wind,
	"wind_blaster": WindBlaster,
	"sluice": Sluice,
	"logs": Logs,
	"flip": Flip,
	"tumble": Tumble,
	"ray": Ray,
}

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
	for key: String in TRAPS:
		var trap: Node3D = (TRAPS[key] as GDScript).new()
		var x := lane_x
		# A trap that flies wide (the ray's loop) asks for lane room east of it.
		lane_x += LANE+(float(trap.call("lane_extra")) if trap.has_method("lane_extra") else 0.0)
		var long: float = trap.length()
		var run_up: float = trap.run_up()
		var spawn := Vector3(x,0.0,run_up)
		trap.position = Vector3(x,0.0,0.0)
		_laid.append(trap)
		stations.append({"key":i+1,"name":"%s (cost %d)" % [key,trap.danger()],"spawn":spawn,"face":Vector2(0.0,-1.0),
			"sign":Vector3(x,SIGN_UP,run_up+2.0),"parts":[
				["box",Rect2(x-DECK_WIDE*0.5,0.0,DECK_WIDE,run_up+4.0),-1.0,0.0,"pad"],
				["box",Rect2(x-DECK_WIDE*0.5,-long-END_DECK,DECK_WIDE,END_DECK),-1.0,0.0,"pad"],
				["box",Rect2(x-DECK_WIDE*0.5,-long,DECK_WIDE,long),-drop-1.0,-drop,"floor"],
				["label",Vector3(x,1.2,-long-END_DECK*0.5),"far deck"],
			]})
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
