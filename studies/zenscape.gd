extends "res://studies/aqueduct_isle.gd"
## The game (the project's main scene, studies/zenscape.tscn): the aqueduct
## isle (studies/aqueduct_isle.gd, everything it does and every flag it
## reads) behind the game's front door (scripts/kit_isle/front_door.gd): the
## loading veil while the isle comes up, then the original minimal centred
## title over it, the camera orbiting the isle. Begin starts on foot beside
## the parked plane; Scenes opens the scene picker, where the old game (the
## plate builder, its worlds and saves) waits as "Builder (old game)"
## (scripts/scene_catalog.gd); Quit quits. docs/design/consolidation-audit.md,
## round 1.
##
## `--no-title` (and the isle's straight-in starts: --fly, --near-ring,
## --place=, --capture=) skips the title; a played start still has the veil.
## On foot the pilot starts by the plane, not at the rubble slope's foot,
## unless --place= sets the start. `--verify-desktop-build` runs the packaged
## self-check (scripts/desktop_build_check.gd) through the title.
##   godot --path .                                the game, as a player opens it
##   godot --path . -- --no-title [isle flags]     straight in
const FrontDoor = preload("res://scripts/kit_isle/front_door.gd")

var front_door: Node

func _ready() -> void:
	# Stood by the plane before the front door frames the title on him.
	isle_ready.connect(_stand_by_plane,CONNECT_ONE_SHOT)
	front_door = FrontDoor.new()
	front_door.name = "FrontDoor"
	add_child(front_door)
	front_door.open(self)
	if front_door.title_wanted: scripted = true
	if front_door.veil != null:
		# Two frames for the veil to draw before the isle's build holds the
		# main thread (as the old title's, studies/diorama.gd); nothing of the
		# isle is made yet, so it doesn't step.
		set_process(false)
		set_process_unhandled_input(false)
		await get_tree().process_frame
		await get_tree().process_frame
		set_process(true)
		set_process_unhandled_input(true)
	if "--verify-desktop-build" in preload("res://scripts/launch_args.gd").user_args():
		preload("res://scripts/desktop_build_check.gd").run.call_deferred(self)
	super._ready()

## On foot to begin with, the pilot stands beside the parked plane (where he
## lands hopping out of it), facing it; --place= keeps its own start.
func _stand_by_plane() -> void:
	if flying or not parked or _place != Vector4.INF: return
	var spot := _hop_spot(parked_at,parked_heading)
	var to := Vector2(parked_at.x-spot.x,parked_at.z-spot.z)
	place(spot,to.normalized() if to.length() > 0.01 else start_face)
	_last_stood = spot

## Nothing reaches the isle while the title is up: its card has the keys.
func _unhandled_input(event: InputEvent) -> void:
	if front_door != null and front_door.titled: return
	super._unhandled_input(event)
