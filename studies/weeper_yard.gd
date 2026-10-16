extends "res://studies/enemy_yard.gd"
## Meet the Weeper alone (scripts/enemies/weeper.gd): the enemy yard's open
## isle over the drop (its rims,
## the spit, the north ledge, the islet), with a few tall columns to hide
## behind, and a Weeper (two with --weepers=2) set out mourning at the far
## end. Turn your back and listen.
##   godot --path . res://studies/weeper_yard.tscn -- --no-title [--weepers=2]
## R sets him back and the Weepers where they began.
const Weeper = preload("res://scripts/enemies/weeper.gd")

## Where the Weepers start (the first, then the second).
const WEEPERS := [Vector3(0.0,0.0,-9.0),Vector3(-8.0,0.0,5.0)]
## The columns: [middle (x, z), radius, top].
const COLUMNS := [[Vector2(-4.5,-4.0),0.7,5.0],[Vector2(4.0,-6.5),0.7,5.0],[Vector2(5.5,1.5),0.7,5.0],[Vector2(-5.0,3.5),0.7,5.0]]

var weepers := 1
## `--weeper-pose=NAME`: every Weeper held in that pose (WeeperLook POSES),
## frozen, for stills.
var still_pose := ""

func _ready() -> void:
	enemy_name = "none"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--weepers="): weepers = clampi(int(arg.get_slice("=",1)),0,WEEPERS.size())
		if arg.begins_with("--weeper-pose="): still_pose = arg.get_slice("=",1)
	super._ready()

func _load_pack() -> void:
	super._load_pack()
	var parts: Array = stations[0].parts
	for c: Array in COLUMNS: parts.append(["cyl",c[0],c[1],0.0,c[2],"grey"])
	stations[0].name = "Weeper yard"

func _build_room() -> void:
	super._build_room()
	for i in range(weepers):
		var at: Vector3 = WEEPERS[i]
		var knobs := {"seed":i+1}
		if still_pose != "": knobs.merge({"pose":still_pose,"still":true})
		enemies.spawn(Weeper,at,Vector2(start.x-at.x,start.z-at.z).normalized(),knobs)

func _hint_text() -> String:
	return "Weeper yard: it moves only while the camera isn't on it · turn your back (or let the camera follow your run) and listen for the grind · hold right mouse / right stick to look back and freeze it · a heavy grind: it's in reach · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text])
	for e: Node3D in enemies.enemies:
		if e.get("snaps") == null: continue
		lines.append("%s  %s · %.1f m · unseen %.1fs · snaps %d · blows %d · %s" % [e.name,"SEEN" if e.seen else "unseen",e.gap_to_him,e.unseen_for,e.snaps,e.blows,e.look.pose_name])
	_hud.text = "\n".join(lines)
