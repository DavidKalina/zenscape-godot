extends RefCounted
## Stage 1's demo skins (docs/design/endless-flight/spec-skins.md): one that
## is finish alone, one with a decal, one with a bake. Rows as
## shop_stock.gd's ITEMS, with the skin fields its header names.

const SKINS := [
	# Finish alone: gloss white with a pearl's blue-violet edge-on, the trim
	# lit pale blue after dark.
	{"id":"paint/moonstone","slot":"paint","name":"Moonstone","rarity":"rare","price":600,
		"livery":{"body":Color("e6e4ea"),"dark":Color("3a3f52"),"trim":Color("6f86b8"),"wing":Color("f1eff2")},
		"finish":{"sheen":"gloss","pearl":Color("9aa8ff"),"pearl_amount":0.55,
			"glow":Color("4aa8ff"),"glow_on":["trim"],"glow_power":1.0}},
	# A decal: a racer's marks (art/blender/hero_plane/skins/demo.py) over a
	# deep red: a chequered cowl, scallops, cream lines and the number 9.
	{"id":"paint/chequer","slot":"paint","name":"Chequer","rarity":"rare","price":500,
		"livery":{"body":Color("9e2a22"),"dark":Color("2a2224"),"trim":Color("9e2a22"),"wing":Color("efe6d2")},
		"finish":{"sheen":"gloss"},
		"decal":"res://assets/models/hero_plane/skins/demo/chequer_decal.png"},
]
