extends "res://scripts/traps/trap_seesaw_drop.gd"
## Seesaw dropper (traps-round2-seesaw.md): the timed trap. A heavy block
## falls on the near end every `period` s with a warning glow (it lands as
## the span tips, a runner halfway across has the near end up); a pilot on the
## far half is thrown on and sideways (`veer`) off the span.

func _init() -> void:
	super()
	trap_name = "seesaw_dropper"
	cost = 4
	under = "void"

func defaults() -> Dictionary:
	var d := super()
	d.merge({"plate":false,"ledge":0.0,"cap_mul":1.0,"along":0.15,"veer":0.9},true)
	return d
