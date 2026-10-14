extends "res://studies/run_layer_sky.gd"
## The motif yard's sky (studies/motif_yard.gd): run_layer's (studies/
## run_layer_sky.gd), its one motif isle stood by the sky's own MotifSky
## (`setup_layer` with the yard's `layer_entries`), as a layer's are. The
## clouds, the open-air life, the motes and the plane tokens only with
## --sky (stills): the yard is for checks, and they cost frames.

var full := false

func setup(study: Node3D) -> void:
	full = flags().has("--sky")
	super.setup(study)

## The clouds keep off the motif (not the layer's band).
func places() -> Array:
	return motifs.stood_places() if motifs != null else []

func _build_clouds() -> void:
	if full: super._build_clouds()

func _build_life() -> void:
	if full: super._build_life()

func _build_motes() -> void:
	if full: super._build_motes()

func _build_tokens() -> void:
	if full: super._build_tokens()
