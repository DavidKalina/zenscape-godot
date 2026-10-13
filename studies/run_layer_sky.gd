extends "res://studies/aqueduct_isle_sky.gd"
## The aqueduct isle's sky round a generated layer (studies/run_layer.gd,
## docs/design/roguelike/layer-round2.md): the same clouds, open-air life,
## motes and plane tokens, but the motif isles are the layer's
## (scripts/kit_isle/motif_sky.gd `setup_layer`), stood where the plan
## (scripts/roguelike/layer_plan.gd) puts them and made again for each new
## layer (`restart`). What flies far loops round the authored isles' places
## (the airships and their ferry, the CPU biplanes, the rune serpent's
## route) is left out: those places are empty here.
##
## The clouds keep off one place, the layer's whole band round the isle
## (LayerPlan BAND), so a new layer never stands in a puff laid for the last.

const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")

func _start_motifs(args: PackedStringArray) -> void:
	motifs = MotifSky.new()
	add_child(motifs)
	motifs.setup_layer(scene,self,args,scene.layer_entries())

## The layer's isles anew (the old freed: their workers waited out).
## The open-air life is made again too: its gulls ride the old isles.
func restart(entries: Array) -> void:
	var lived := life != null
	if lived:
		for node: Node in [life,_hosts]:
			remove_child(node)
			node.free()
		life = null
		_hosts = null
	if motifs != null:
		remove_child(motifs)
		motifs.free()
	motifs = MotifSky.new()
	add_child(motifs)
	motifs.setup_layer(scene,self,flags(),entries)
	if lived: _build_life()

## The band the layers stand in, as one place (the clouds' keep).
func places() -> Array:
	return [["layer",LayerPlan.MIDDLE,LayerPlan.BAND+60.0]]

func _build_airships() -> void:
	pass

func _build_traffic() -> void:
	pass

func _build_serpent() -> void:
	pass

## The motes round the isle only.
func _build_motes() -> void:
	var m: Node3D = SkyMotes.new()
	m.position = MIDDLE+Vector3(0.0,-6.0,0.0)
	m.scale = Vector3.ONE*2.0
	add_child(m)
	m.set_strength(0.75)
	motes.append(m)

## The isle's own plane tokens only (a layer's isles come and go).
func _build_tokens() -> void:
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in plane_tokens():
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source(token_source(),lines)
