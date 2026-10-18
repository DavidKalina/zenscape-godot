extends "res://studies/aqueduct_isle.gd"
## The game (the project's main scene, studies/zenscape.tscn): the aqueduct
## isle (studies/aqueduct_isle.gd, everything it does and every flag it
## reads) behind the game's front door (scripts/kit_isle/front_door.gd): the
## loading veil while the isle comes up, then the original minimal centred
## title over it, the camera orbiting the isle. Begin starts on foot beside
## the parked plane; Scenes opens the scene picker
## (scripts/scene_catalog.gd); Quit quits. docs/design/consolidation-audit.md,
## round 1.
##
## In the game, Esc or the pad's Menu pauses (scripts/kit_isle/pause_host.gd:
## Resume, Back to the plane, Settings, Scenes, Back to the title, Quit);
## the settings (scripts/kit_isle/game_settings.gd) are applied as the isle
## comes up. R on foot (or under the canopy) is Back to the plane: beside
## the parked plane, where a hop out of it lands; nothing summons the plane
## (docs/design/manual-landing.md). The study's developer keys (F1-F8, the
## station keys, L, B, R in the plane) and capture flags work only in
## editor and debug runs (scripts/kit_isle/dev_keys.gd); docs/design/
## consolidation-audit.md, round 2.
##
## `--no-title` (and the isle's straight-in starts: --fly, --near-ring,
## --place=, --capture=) skips the title; a played start still has the veil.
## On foot the pilot starts by the plane, not at the rubble slope's foot,
## unless --place= sets the start. `--verify-desktop-build` runs the packaged
## self-check (scripts/desktop_build_check.gd) through the title.
##   godot --path .                                the game, as a player opens it
##   godot --path . -- --no-title [isle flags]     straight in
const FrontDoor = preload("res://scripts/kit_isle/front_door.gd")
const PauseHost = preload("res://scripts/kit_isle/pause_host.gd")
const DevKeys = preload("res://scripts/kit_isle/dev_keys.gd")
const GameSettings = preload("res://scripts/kit_isle/game_settings.gd")

var front_door: Node
var pause: Node

func _ready() -> void:
	# A release build never starts a capture (before the isle reads its flags).
	DevKeys.strip_captures()
	# Stood by the plane before the front door frames the title on him.
	isle_ready.connect(_stand_by_plane,CONNECT_ONE_SHOT)
	isle_ready.connect(func() -> void: GameSettings.apply_start(self),CONNECT_ONE_SHOT)
	front_door = FrontDoor.new()
	front_door.name = "FrontDoor"
	add_child(front_door)
	front_door.open(self)
	if front_door.title_wanted: scripted = true
	pause = PauseHost.new()
	pause.name = "Pause"
	add_child(pause)
	pause.setup(self)
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

## Back on foot beside the parked plane, facing it, as a hop out of it
## lands (kit_isle.gd `_return_to_plane`; off the edge too): R, and
## the pause's Back to the plane. Not in the plane, nor while the lodestone
## is held up to look at.
func back_to_plane() -> void:
	if flying or not walk_ready or lode_state == "inspecting": return
	if not _replay.is_empty(): _end_replay()
	_return_to_plane()
	reset_camera()

## The wind gauge stays down while the title is up.
func wind_gauge_shown() -> bool:
	return super.wind_gauge_shown() and not (front_door != null and front_door.titled)

## Nothing reaches the isle while the title is up: its card has the keys.
## The study's developer keys only where they're on (DevKeys); R on foot is
## Back to the plane.
func _unhandled_input(event: InputEvent) -> void:
	if front_door != null and front_door.titled: return
	if DevKeys.is_dev_event(event,flying) and not DevKeys.enabled(): return
	if not flying and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		if _name_panel == null or not _name_panel.visible: back_to_plane()
		return
	super._unhandled_input(event)
