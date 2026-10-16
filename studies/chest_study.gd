extends "res://studies/character_study.gd"
## The treasure chest study: a start
## isle with two chests (scripts/chest/treasure_chest.gd, in a ChestField,
## scripts/chest/chest_field.gd). The first is open to a press (Space / A near
## it); the second is locked: a press only rattles it, a hard slam on its lid
## (jump onto the chest from height, then crouch in the air) breaks it open.
## Each spills its runes as the sky's rune pickups; walk through them and the
## run's count (scripts/roguelike/run_state.gd, shown in the F1 numbers) climbs
## as it does in the generator's layers. The noise of an opening is logged.
## This extends the character study; the field fills its `foot_pieces` slot.
##   godot --path . res://studies/chest_study.tscn -- --no-title
const ChestField = preload("res://scripts/chest/chest_field.gd")
const RunState = preload("res://scripts/roguelike/run_state.gd")

const START_ISLE := Rect2(-12.0,-9.0,24.0,24.0)
const DROP := 24.0
## The chests: {at, yaw, knobs}.
const CHESTS := [
	{"at":Vector3(0.0,0.0,0.0),"yaw":0.0,"knobs":{"runes":5,"seed":11}},
	{"at":Vector3(-7.0,0.0,0.0),"yaw":0.0,"knobs":{"runes":3,"locked":true,"seed":23}},
]

var chest_field: Node3D
var run: RefCounted

func _ready() -> void:
	pack = "chest_study"
	super._ready()

func _load_pack() -> void:
	start = Vector3(0.0,0.0,8.0)
	start_face = Vector2(0.0,-1.0)
	lost = -DROP
	_last_stood = start
	stations = [{"key":1,"name":"Chest study","spawn":start,"face":start_face,"sign":Vector3(-6.0,3.0,11.0),"parts":[
		["box",START_ISLE,-2.0,0.0,"floor"],
	]}]

func _build_room() -> void:
	super._build_room()
	# A throwaway record file: the study must not touch the player's.
	RunState.record_path = "user://chest_study_record.json"
	run = RunState.new()
	run.begin(1)
	chest_field = ChestField.new()
	add_child(chest_field)
	chest_field.attach(self)
	# The run counts a rune as the generator's stage does (run_loop.gd).
	chest_field.rune_taken.connect(func(_left: int) -> void: run.take_rune())
	for c: Dictionary in CHESTS:
		chest_field.add_chest(c.at,c.yaw,c.knobs)

## Set down again: opened chests stay open (the field's `reset`).
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if chest_field != null:
		chest_field.reset()

func _hint_text() -> String:
	return "Chest study: Space near a chest opens it · the locked one wants a slam on its lid (jump on, then crouch in the air from height) · walk through the runes · R reset · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or chest_field == null: return
	_hud.text = "%s\n\nrun runes: %d   (chest runes taken %d, still to come %d)" % [_hud.text,run.runes,chest_field.taken,chest_field.runes_left()]
