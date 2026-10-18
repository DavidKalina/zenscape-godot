extends "res://studies/aqueduct_isle_sky.gd"
## The motif yard's sky (studies/motif_yard.gd): the aqueduct isle's, its
## one motif isle stood by the sky's own MotifSky (scripts/kit_isle/
## motif_sky.gd `setup_layer` with the yard's `layer_entries`). What flies
## far loops round the authored isles' places (the airships and their
## ferry, the CPU biplanes, the rune serpent's route) is left out. The
## clouds, the open-air life, the motes and the plane tokens only with
## --sky (stills): the yard is for checks, and they cost frames.

var full := false

func setup(study: Node3D) -> void:
	full = flags().has("--sky")
	super.setup(study)

func _start_motifs(args: PackedStringArray) -> void:
	motifs = MotifSky.new()
	add_child(motifs)
	motifs.setup_layer(scene,self,args,scene.layer_entries())

## The clouds keep off the motif.
func places() -> Array:
	return motifs.stood_places() if motifs != null else []

func _build_airships() -> void:
	pass

func _build_traffic() -> void:
	pass

func _build_serpent() -> void:
	pass

func _build_clouds() -> void:
	if full: super._build_clouds()

func _build_life() -> void:
	if full: super._build_life()

## The motes round the isle only.
func _build_motes() -> void:
	if not full: return
	var m: Node3D = SkyMotes.new()
	m.position = MIDDLE+Vector3(0.0,-6.0,0.0)
	m.scale = Vector3.ONE*2.0
	add_child(m)
	m.set_strength(0.75)
	motes.append(m)

## The isle's own plane tokens only.
func _build_tokens() -> void:
	if not full: return
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in plane_tokens():
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source(token_source(),lines)
