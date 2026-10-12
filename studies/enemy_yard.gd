extends "res://studies/character_study.gd"
## The enemy yard (docs/design/roguelike/ideas-enemies.md): one greybox isle
## in open sky for trying an enemy against the pilot, in the interactables
## yard's style (the character study's grey structure; this extends it, so
## the motor, figure, camera, F1 numbers, F2 feel and recorder are the
## character study's). A flat isle, 24 by 29 m, its edges open over the
## drop, and along its north side a narrow ledge 1.2 m up, orange-lipped
## (jump or pump up to it; an enemy cannot follow). R sets him back and
## brings the enemies back.
##   --enemy=NAME   which enemy (ENEMIES; `none` for an empty yard); the
##                  pilot is set down facing it. Default: ram.
## Adding an enemy is one line in ENEMIES: its script, where it stands, where
## the pilot starts (it is faced toward the pilot, and he toward it).
##   godot --path . res://studies/enemy_yard.tscn -- --no-title --enemy=ram
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const PlinthRam = preload("res://scripts/enemies/plinth_ram.gd")

## name: {script, at (the enemy), pilot (where he starts), knobs (overrides)}.
const ENEMIES := {
	"ram":{"script":PlinthRam,"at":Vector3(0.0,0.0,-2.0),"pilot":Vector3(0.0,0.0,9.0)},
}
const DEFAULT_ENEMY := "ram"
const YARD_LOST := -20.0
## The isle and its ledge (x, z); the ledge up to LEDGE_TOP.
const ISLE := Rect2(-12.0,-16.0,24.0,29.0)
const LEDGE := Rect2(-6.0,-16.0,12.0,3.0)
const LEDGE_TOP := 1.2

var enemies: Node
var enemy_name := DEFAULT_ENEMY

func _ready() -> void:
	pack = "enemy_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--enemy="): enemy_name = arg.get_slice("=",1)
	super._ready()

## The yard's one station, not a pack's file.
func _load_pack() -> void:
	var entry: Dictionary = ENEMIES.get(enemy_name,ENEMIES[DEFAULT_ENEMY])
	var pilot: Vector3 = entry.pilot
	var at: Vector3 = entry.at
	var face := Vector2(at.x-pilot.x,at.z-pilot.z).normalized()
	start = pilot
	start_face = face
	lost = YARD_LOST
	_last_stood = start
	stations = [{"key":1,"name":"Enemy yard","spawn":pilot,"face":face,"sign":Vector3(-9.0,3.0,13.0),"parts":[
		["box",ISLE,-2.0,0.0,"floor"],
		["box",LEDGE,-2.0,LEDGE_TOP,"lip"],
		["ticks",Vector2(12.6,ISLE.end.y),Vector2(12.6,ISLE.position.y),1.0,5],
	]}]

func _build_room() -> void:
	super._build_room()
	enemies = EnemyField.new()
	enemies.attach(self)
	if ENEMIES.has(enemy_name):
		var entry: Dictionary = ENEMIES[enemy_name]
		var at: Vector3 = entry.at
		enemies.spawn(entry.script,at,Vector2(start.x-at.x,start.z-at.z).normalized(),entry.get("knobs",{}))

## Set down, the enemies back as they began.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()

func _hint_text() -> String:
	return "Enemy yard: %s · stand on its line and sidestep it; slide into it from the side; the ledge is out of its reach · R start (the enemies too) · F1 numbers · F2 feel · Esc mouse" % enemy_name

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	for e: Node3D in enemies.enemies:
		lines.append("%s  %s %.1fs · %.1f m/s · %s · tells %d" % [e.name,e.state,e.state_t,Vector2(e.vel.x,e.vel.z).length(),"on ground" if e.grounded else "falling",e.told_count])
	lines.append("fallen and gone: %d" % enemies.gone_count)
	_hud.text = "\n".join(lines)
