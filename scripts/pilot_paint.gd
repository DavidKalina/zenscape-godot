extends RefCounted
## The pilot on foot's own paint (not the islanders' lacquer, scripts/
## person_kit.gd): a material for each of the model's surfaces, by its name
## (art/blender/pilot/pilot_build.py PALETTE, the same colours), all drawn by
## shaders/pilot_paint.gdshader: soft toon bands, warm light and cool
## shade, a gentle rim, no gloss, a painted mottle that stays on the cloth.
## The wanderer's sheet (docs/design/wanderer-look/round1.md): the hat in
## terracotta felt, the face a dark brown shadow with two glowing cyan eyes
## painted on it, a navy scarf, a charcoal-brown jacket, denim trousers,
## brown mitts and boots with tan fleece, gold bracelets with a glowing
## stripe, a charcoal cape. The sheet's hexes: terracotta c9644a, brown
## 5a3a2c, tan d9bc9c, navy 2e4fa3, cyan 5fe6e6, charcoal 4a4848 (the
## plane's livery shares them); the rest are shades between.

const PAINT := preload("res://shaders/pilot_paint.gdshader")
const MODEL := preload("res://assets/models/pilot.glb")
## The sheet's glow (the eyes, the bracelets' stripes, the cap's rotor).
const GLOW := Color("5fe6e6")
## The surfaces that are the hat (hidden on the head while it flies as the
## pocket sail, scripts/pocket_sail_figure.gd).
const HAT := ["pilot_hat","pilot_hat_band"]
## Each surface: its colour, then what it changes of the paint's defaults.
const SURFACES := {
	# The face in the hat's shade, the eyes painted on it (the shader's
	# `eyes`, driven by scripts/pilot_figure.gd).
	"pilot_face": [Color("3b2a22"), {"mottle":0.05,"streaks":0.02,"rim":0.18,"eyes":1.0}],
	# Soft felt: a fine, fuzzy mottle.
	"pilot_hat": [Color("c9644a"), {"mottle":0.12,"streaks":0.04,"paint_scale":26.0,"rim":0.16}],
	"pilot_hat_band": [Color("4a2f24"), {}],
	# Chunky knit.
	"pilot_scarf": [Color("2e4fa3"), {"mottle":0.12,"streaks":0.05,"paint_scale":30.0}],
	"pilot_jacket": [Color("4a403c"), {"rim":0.16}],
	"pilot_strap": [Color("5a3a2c"), {}],
	"pilot_gold": [Color("d9a441"), {"mottle":0.05,"streaks":0.02,"rim":0.35,"sheen":0.35}],
	"pilot_glow": [GLOW, {"mottle":0.0,"streaks":0.0,"glow":2.2}],
	"pilot_mitt": [Color("7a4e38"), {}],
	"pilot_trousers": [Color("323847"), {"mottle":0.12,"streaks":0.09}],
	"pilot_boots": [Color("7a4a32"), {}],
	"pilot_fleece": [Color("d9bc9c"), {"mottle":0.1,"streaks":0.03,"paint_scale":22.0}],
	"pilot_cape": [Color("4a4848"), {"mottle":0.12,"streaks":0.08,"rim":0.18}],
}

## The worn looks (`--wanderer-look=worn|dust`, `paint` the clean one
## above): the same surfaces in real stuff, lived in, to sit with the
## weathered stone (shaders/olmec_stone.gdshader) over the painted turf.
## Each surface: its colour (null keeps SURFACES'), then what it changes of
## SURFACES' tweaks; ALL first, for every surface.
##   worn  the sheet's colours, sun-faded and dusty: felt, knit, waxed
##         canvas, denim, leather scuffed pale, brass tarnished, dust up
##         the boots in the turf's ochre; the toon bands kept, softer.
##   dust  earthier, cut from the stone and the turf: an oxblood hat, an
##         ash-teal scarf, an olive oilskin coat, a slate cape mottled as
##         the stone is, dark bronze with verdigris; the light's terminator
##         soft as the stone's, more dust and grime.
const LOOKS := {
	"worn": {
		"ALL": [null, {"dust":0.55,"fade":0.5,"grime":0.5,"wear":0.5,"bump":1.0,"soft":0.16,"mottle":0.14,"streaks":0.08}],
		"pilot_face": [null, {"dust":0.0,"fade":0.0,"grime":0.0,"wear":0.0,"bump":0.0,"mottle":0.05,"streaks":0.02}],
		"pilot_hat": [Color("aa553b"), {"felt":1.0,"fade":0.4,"dust":0.15,"wear":0.5,"paint_scale":18.0}],
		"pilot_hat_band": [Color("3e2a20"), {"leather":0.8,"grime":0.8}],
		"pilot_scarf": [Color("3b4a6b"), {"knit":1.0,"thread":0.012,"fade":0.7,"paint_scale":20.0}],
		"pilot_jacket": [Color("534739"), {"cloth":0.8,"thread":0.006,"wear":0.7}],
		"pilot_strap": [Color("5e3c2a"), {"leather":1.0}],
		"pilot_gold": [Color("a8843f"), {"metal":1.0,"sheen":0.2,"dust":0.2,"wear":0.0}],
		"pilot_glow": [null, {"dust":0.0,"fade":0.0,"grime":0.0,"wear":0.0,"bump":0.0,"mottle":0.0,"streaks":0.0}],
		"pilot_mitt": [Color("6c4632"), {"leather":1.0,"wear":0.8}],
		"pilot_trousers": [Color("434a5a"), {"cloth":1.0,"twill":1.0,"thread":0.005,"wear":0.8}],
		"pilot_boots": [Color("664130"), {"leather":1.0,"wear":0.9,"dust":0.6}],
		"pilot_fleece": [Color("c4ad8c"), {"felt":0.8,"grime":0.8,"dust":0.8,"paint_scale":30.0}],
		"pilot_cape": [Color("4c4944"), {"cloth":0.9,"thread":0.007,"fade":0.8,"wear":0.6}],
	},
	"dust": {
		"ALL": [null, {"dust":0.8,"fade":0.6,"grime":0.75,"wear":0.6,"bump":1.3,"bands":0.0,"fill":3.0,"mottle":0.16,"streaks":0.1}],
		"pilot_face": [Color("2e241f"), {"dust":0.0,"fade":0.0,"grime":0.0,"wear":0.0,"bump":0.0,"bands":1.0,"fill":3.2,"mottle":0.05,"streaks":0.02}],
		"pilot_hat": [Color("8e4b3b"), {"felt":1.0,"fade":0.5,"dust":0.2,"wear":0.9,"paint_scale":18.0}],
		"pilot_hat_band": [Color("2f241d"), {"leather":0.8}],
		"pilot_scarf": [Color("557570"), {"knit":1.0,"thread":0.012,"paint_scale":20.0}],
		"pilot_jacket": [Color("4e4a36"), {"cloth":0.7,"thread":0.006,"wear":0.8}],
		"pilot_strap": [Color("4f3424"), {"leather":1.0}],
		"pilot_gold": [Color("7d6236"), {"metal":1.0,"sheen":0.12,"dust":0.2,"wear":0.0}],
		"pilot_glow": [null, {"dust":0.0,"fade":0.0,"grime":0.0,"wear":0.0,"bump":0.0,"bands":1.0,"fill":3.2,"mottle":0.0,"streaks":0.0}],
		"pilot_mitt": [Color("5e4130"), {"leather":1.0,"wear":0.8}],
		"pilot_trousers": [Color("4a4438"), {"cloth":1.0,"twill":1.0,"thread":0.005,"wear":0.8}],
		"pilot_boots": [Color("54392a"), {"leather":1.0,"wear":0.9,"dust":1.0}],
		"pilot_fleece": [Color("b3a185"), {"felt":0.8,"dust":1.0,"paint_scale":30.0}],
		"pilot_cape": [Color("55595a"), {"cloth":0.8,"thread":0.007,"fade":0.9,"wear":0.7,"mottle":0.22,"streaks":0.14,"paint_scale":5.0}],
	},
}

## The look this run wears: `--wanderer-look=` (worn by default).
static func look() -> String:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--wanderer-look="): return a.get_slice("=",1)
	return "worn"

## The materials, keyed by the model's surface names, in `which` look
## (look() if empty).
static func outfit(which := "") -> Dictionary:
	if which == "": which = look()
	var worn: Dictionary = LOOKS.get(which,{})
	var all: Dictionary = worn.get("ALL",[null,{}])[1]
	var out := {}
	for key: String in SURFACES:
		var m := ShaderMaterial.new()
		m.shader = PAINT
		m.resource_name = key
		var over: Array = worn.get(key,[null,{}])
		m.set_shader_parameter("albedo",SURFACES[key][0] if over[0] == null else over[0])
		var tweaks: Dictionary = SURFACES[key][1].duplicate()
		tweaks.merge(all,true)
		tweaks.merge(over[1],true)
		for p: String in tweaks: m.set_shader_parameter(p,tweaks[p])
		out[key] = m
	return out

## The model's surfaces named in `keys`, lifted off it once (unskinned, in
## its rest pose) through `at`, each in `paint`'s material of its name: the
## hat for the pocket sail (scripts/pocket_sail_figure.gd), the head and the
## hat for the cockpit's wanderer (scripts/plane_pilot.gd). The paint's rest
## coordinates ride along in the UVs, so the eyes stay painted on.
static func lift(keys: Array, at: Transform3D, paint: Dictionary) -> ArrayMesh:
	var lifted := ArrayMesh.new()
	var model := MODEL.instantiate()
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var placed := Transform3D.IDENTITY
		var up: Node = node
		while up != model:
			placed = (up as Node3D).transform*placed
			up = up.get_parent()
		for i in range(node.mesh.get_surface_count()):
			var material := node.mesh.surface_get_material(i)
			var key := material.resource_name if material != null else ""
			if not key in keys: continue
			var arrays := node.mesh.surface_get_arrays(i)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			var to := at*placed
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for k in range(points.size()):
				points[k] = to*points[k]
				normals[k] = (to.basis*normals[k]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			lifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			lifted.surface_set_material(lifted.get_surface_count()-1,paint[key])
	model.free()
	return lifted
