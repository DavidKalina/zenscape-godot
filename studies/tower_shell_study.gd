extends "res://studies/character_study.gd"
## The tower shell study (docs/design/roguelike/tower-shell-round1.md): the
## ruin kit's tower shell (scripts/ruin_kit_tower.gd) on flat ground, to
## climb its wall-kick chimney. The pilot is the character study's (this
## extends it): the same motor, figure, camera, F1 numbers, F2 feel.
## Walk in at the door, turn to a side wall, jump at it, and press Space
## each time you touch a wall: he kicks across the shaft to the other and
## up, to the rim. A late kick still gains; pulled away from the walls you
## fall (or step out at a breach's sill).
##   1  the doorway (R comes back here)    2  the shaft's foot    3  the rim
## Knobs: --tower-height=<m> (12), --tower-weathered=<0..1> (0.5),
## --tower-seed=<n> (1), --tower-open (the back wall torn away).
##   ./run-tower-shell.command --tower-height=16 --tower-weathered=1
##   godot --path . res://studies/tower_shell_study.tscn -- --no-title
const Tower = preload("res://scripts/ruin_kit_tower.gd")

## The flat ground's half size round the tower (m).
const GROUND := 30.0
## The doorway station stands this far out from the door (m).
const DOOR_OUT := 2.0

## The tower's knobs (set before the study is in the tree, or by flags).
var tower_height := Tower.HEIGHT
var tower_weathered := 0.5
var tower_seed := 1
var tower_open := false
var tower: Node3D

func _ready() -> void:
	pack = "tower_shell"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--tower-height="): tower_height = maxf(Tower.LOWEST,arg.get_slice("=",1).to_float())
		elif arg.begins_with("--tower-weathered="): tower_weathered = clampf(arg.get_slice("=",1).to_float(),0.0,1.0)
		elif arg.begins_with("--tower-seed="): tower_seed = arg.get_slice("=",1).to_int()
		elif arg == "--tower-open": tower_open = true
	super._ready()

## The study's stations round the tower, not a pack's file.
func _load_pack() -> void:
	var outer := Tower.half_extents()
	var door := Vector3(0.0,0.0,outer.y+DOOR_OUT)
	var rim := Vector3(Tower.KICK_GAP*0.5+Tower.WALL*0.5,tower_height,0.0)
	stations = [
		{"key":1,"name":"the doorway","spawn":door,"face":Vector2(0.0,-1.0),"sign":Vector3(-3.5,2.4,outer.y+1.5),
			"parts":[["box",Rect2(-GROUND,-GROUND,GROUND*2.0,GROUND*2.0),-1.0,0.0,"floor"]]},
		{"key":2,"name":"the shaft's foot","spawn":Vector3.ZERO,"face":Vector2(1.0,0.0),"parts":[]},
		{"key":3,"name":"the rim","spawn":rim,"face":Vector2(-1.0,0.0),"parts":[]},
	]
	start = door
	start_face = Vector2(0.0,-1.0)
	lost = -20.0
	_last_stood = start

## The ground (the stations' parts), then the tower in the middle.
func _build_room() -> void:
	super._build_room()
	tower = Tower.tower_shell(tower_seed,tower_weathered,tower_height,tower_open)
	add_child(tower)

func _hint_text() -> String:
	return "Tower shell · in at the door, jump at a side wall, Space at each wall to kick up · 1 door · 2 shaft · 3 rim · R doorway · F1 numbers · F2 feel · Esc mouse"
