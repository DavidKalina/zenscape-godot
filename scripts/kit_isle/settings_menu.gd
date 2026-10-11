extends "res://scripts/kit_isle/menu_sheet.gd"
## The game's Settings (docs/design/consolidation-audit.md, round 2): a
## linen sheet (scripts/kit_isle/menu_sheet.gd) of every setting in
## scripts/kit_isle/game_settings.gd, grouped (Look, Sound, Controls), each
## a choice stepped with left and right (or pressed on), kept and applied
## the moment it steps; Back (Esc, pad B) at its foot. Opened from the
## title's card and from the pause (scripts/kit_isle/front_door.gd,
## pause_host.gd); `closed` when it goes.

signal closed

const GameSettings = preload("res://scripts/kit_isle/game_settings.gd")

## The isle the choices apply to (its look pass, its window).
var isle: Node
## Each setting's row, by key.
var choice_rows := {}
var back_row: Row

func _init() -> void:
	super._init()
	row_text = 18.0
	row_pad = 7.0
	set_title("Settings","")
	var group := ""
	for e: Dictionary in GameSettings.ENTRIES:
		if e.group != group:
			group = e.group
			add_group(group)
		var key: String = e.key
		choice_rows[key] = add_choice(e.title,GameSettings.options(key),GameSettings.index_of(key),
			func(index: int) -> void: GameSettings.choose(key,index,isle))
	add_seam()
	back_row = add_row("Back",close_settings,"Esc","B")
	set_hint("Left and right change · Esc goes back","{LEFT}{RIGHT} change   {B} back")
	cancelled.connect(close_settings)

## Shows the sheet with each row on its kept choice, the first in reach.
func present() -> void:
	for key: String in choice_rows:
		var row: Row = choice_rows[key]
		row.chosen = GameSettings.index_of(key)
		row.queue_redraw()
	open()

func close_settings() -> void:
	if not visible: return
	close()
	closed.emit()
