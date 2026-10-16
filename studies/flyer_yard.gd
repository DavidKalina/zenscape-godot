extends "res://studies/motif_yard.gd"
## The flyer yard (feature `flyer`):
## meet the guacharo alone. The motif yard (studies/motif_yard.gd) with one
## guacharo (scripts/enemies/guacharo.gd) laid over the motif through the
## generator's own path (LayerStage -> scripts/roguelike/layer_flyers.gd,
## the plan's `flyers`), hunting after FLYER_GRACE s. Defaults to
## --motif=stacked_court with --rims (pads out over the drop to jump
## to); any motif yard flag works (--motif=, --grey, --bodies=0, --sky,
## --underground=haze), and the flyer's own (--flyer-fold=0.8, --flyer-log).
##
##   godot --path . res://studies/flyer_yard.tscn -- --no-title [--underground=haze]
const FLYER_GRACE := 3.0
const DEFAULT_MOTIF := "stacked_court"

func _ready() -> void:
	var args := LaunchArgs.user_args()
	var with := PackedStringArray(args)
	var has_motif := false
	for a: String in args:
		if a.begins_with("--motif="): has_motif = true
	if not has_motif: with.append("--motif="+DEFAULT_MOTIF)
	if not "--rims" in with and not "--no-rims" in with: with.append("--rims")
	if with != args: LaunchArgs.set_override(with)
	super._ready()

func _first_layer() -> void:
	layer.flyers = [{"home":start+Vector3.UP*22.0,"grace":FLYER_GRACE,"range":1e6}]
	super._first_layer()
	# Home over the highest rim pad (the exposed place to meet it).
	if rim_pads != null:
		var high := -INF
		for p: Node3D in rim_pads.get_children():
			if p.global_position.y > high:
				high = p.global_position.y
				stage.flyers.birds[0].home = p.global_position+Vector3.UP*22.0
	if _card != null: _card.text += "\nThe guácharo hunts you exposed (rims, ledges, leaps). Read the clicks, then the scream. Jump or twirl to struggle free."

func isle_name() -> String:
	return "flyer yard"
