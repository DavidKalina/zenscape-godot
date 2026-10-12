extends "res://scripts/traps/trap_wind.gd"
## Wind in its blaster mode (see trap_wind.gd), as its own yard lane: a
## plate, four mouths and a half-second inhale.

func _init() -> void:
	super()
	trap_name = "wind_blaster"
	knobs.merge({"mode":"blaster","count":4},true)
