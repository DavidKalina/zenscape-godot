extends "res://studies/character_study.gd"
## The beetle yard (docs/design/roguelike/beetle-round1.md): the Millstone
## Beetle (scripts/enemies/millstone_beetle.gd) met alone, on greybox lanes
## in open sky, with the character study's motor, figure, camera and keys
## (F1 numbers, R start). Three lanes off the start deck, a beetle on each:
##   - the causeway (middle): 3 m wide, void both sides, its far end a lip
##     over a lower ledge 3 m down. Get past the beetle (a jump over its
##     wheel), stand near the far lip and dodge late: the wheel goes over
##     and lands on the ledge, a new stone down there.
##   - the slot (east): a causeway cut across by a slot narrower than the
##     wheel. Bait it at the slot and the wheel jams in it: a plug to walk.
##   - the terrace (west): a wide flat with a rim: room to step aside.
##   --lane=causeway|slot|terrace|all   which beetles (all)
##   --wheel=<share>                     the wheel's size (1 = a little
##                                       over his plain jump)
##   godot --path . res://studies/beetle_yard.tscn -- --no-title [--lane=slot]
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const Beetle = preload("res://scripts/enemies/millstone_beetle.gd")
const Voice = preload("res://scripts/enemies/beetle_voice.gd")

const YARD_LOST := -30.0
const DECK := Rect2(-22.0,6.0,34.0,10.0)
const CAUSEWAY := Rect2(-1.5,-16.0,3.0,22.0)
const LEDGE := Rect2(-4.0,-27.0,8.0,10.0)
const LEDGE_TOP := -3.0
## The slot causeway: its near run, the slot, its far run.
const SLOT_NEAR := Rect2(5.5,-8.0,3.0,14.0)
const SLOT_FAR := Rect2(5.5,-16.0,3.0,7.4)
const TERRACE := Rect2(-22.0,-12.0,10.0,18.0)
## name: [lane end a, lane end b, where it starts, facing (x, z)].
const LANES := {
	"causeway":[Vector3(0.0,0.0,3.0),Vector3(0.0,0.0,-13.0),Vector3(0.0,0.0,-8.0),Vector2(0.0,1.0)],
	"slot":[Vector3(7.0,0.0,3.0),Vector3(7.0,0.0,-5.5),Vector3(7.0,0.0,-2.0),Vector2(0.0,1.0)],
	"terrace":[Vector3(-17.0,0.0,3.0),Vector3(-17.0,0.0,-9.0),Vector3(-17.0,0.0,-6.0),Vector2(0.0,1.0)],
}

var enemies: Node
var lanes := "all"
var wheel := 1.0

func _ready() -> void:
	pack = "beetle_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--lane="): lanes = arg.get_slice("=",1)
		if arg.begins_with("--wheel="): wheel = float(arg.get_slice("=",1))
	super._ready()

func _load_pack() -> void:
	start = Vector3(0.0,0.0,12.0)
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var parts := [
		["box",DECK,-2.0,0.0,"floor"],
		["box",CAUSEWAY,-2.0,0.0,"floor"],
		["box",LEDGE,LEDGE_TOP-2.0,LEDGE_TOP,"grey"],
		["box",SLOT_NEAR,-2.0,0.0,"floor"],
		["box",SLOT_FAR,-2.0,0.0,"floor"],
		["box",TERRACE,-2.0,0.0,"floor"],
		["label",Vector3(0.0,0.6,CAUSEWAY.position.y+0.6),"the causeway"],
		["label",Vector3(7.0,0.6,-8.4),"the slot"],
		["label",Vector3(-17.0,0.6,TERRACE.position.y+0.6),"the terrace"],
	]
	stations = [{"key":1,"name":"Beetle yard","spawn":start,"face":start_face,"sign":Vector3(-9.0,3.0,15.0),"parts":parts}]

func _build_room() -> void:
	super._build_room()
	enemies = EnemyField.new()
	enemies.attach(self)
	enemies.sound_hook = func(sound_name: StringName, at: Vector3) -> void: Voice.play(self,String(sound_name),at)
	for key: String in LANES:
		if lanes != "all" and lanes != key: continue
		var l: Array = LANES[key]
		enemies.spawn(Beetle,l[2],l[3],{"lane_a":l[0],"lane_b":l[1],"wheel":wheel})

## Set down, the enemies back as they began.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()

func _hint_text() -> String:
	return "Beetle yard: it sees only down its lane, ahead of its wheel. It plants and racks its wheel back (click, click, CLACK), then charges · jump the wheel, or step out of its line late · dodge it near a lip and the wheel goes over (the slot: it jams) · R start · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	for e: Node3D in enemies.enemies:
		lines.append("%s  %s %.1fs · %.1f m/s · %s" % [e.name,e.state,e.state_t,Vector2(e.vel.x,e.vel.z).length(),"on ground" if e.grounded else "falling"])
	_hud.text = "\n".join(lines)
