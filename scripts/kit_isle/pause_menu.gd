extends "res://scripts/kit_isle/menu_sheet.gd"
## The game's pause (docs/design/consolidation-audit.md, round 2): a linen
## sheet (scripts/kit_isle/menu_sheet.gd) saying Paused over the isle's
## name, with Resume (Esc, pad B or Menu), Back to the plane (on foot or
## under the canopy: back beside the parked plane, as a hop out of it
## lands), Settings, Scenes (when the scene picker is offered: scripts/
## scene_catalog.gd `enabled`), then past the seam Back to the title and
## Quit. It only shows and asks; scripts/kit_isle/pause_host.gd pauses and
## does what's asked.

signal resumed
signal plane_requested
signal settings_requested
signal scenes_requested
signal title_requested
signal quit_requested

var resume_row: Row
var plane_row: Row
var settings_row: Row
var scenes_row: Row
var title_row: Row
var quit_row: Row

func _init() -> void:
	super._init()
	set_title("Paused","")
	resume_row = add_row("Resume",func() -> void: resumed.emit(),"Esc","B")
	plane_row = add_row("Back to the plane",func() -> void: plane_requested.emit(),"R")
	settings_row = add_row("Settings",func() -> void: settings_requested.emit())
	scenes_row = add_row("Scenes",func() -> void: scenes_requested.emit())
	add_seam()
	title_row = add_row("Back to the title",func() -> void: title_requested.emit())
	quit_row = add_row("Quit",func() -> void: quit_requested.emit())
	set_hint("The isle starts afresh from the title.","The isle starts afresh from the title.")
	cancelled.connect(func() -> void: resumed.emit())

## Shows the pause over the isle `isle_name`, Resume in reach; Back to the
## plane only when `can_return`, Scenes only when `with_scenes`.
func present(isle_name: String, can_return: bool, with_scenes: bool) -> void:
	set_title("Paused",isle_name)
	plane_row.visible = can_return
	scenes_row.visible = with_scenes
	open(resume_row)
