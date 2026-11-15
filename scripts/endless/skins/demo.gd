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
]
