extends RefCounted
## The glow batch: five skins that come alive after dark. Dark liveries, the
## marks drawn in light by their decals (art/blender/hero_plane/skins/glow.py).

const D := "res://assets/models/hero_plane/skins/glow/"

const SKINS := [
	# Black, with thin lines of hot pink light tracing the body and wing edges.
	{"id":"paint/filament","slot":"paint","name":"Filament","rarity":"rare","price":640,
		"livery":{"body":Color("14141a"),"dark":Color("0a0a0e"),"trim":Color("14141a"),"wing":Color("1a1a22")},
		"finish":{"sheen":"satin","glow":Color("ff3fb0"),"glow_on":["decal"],"glow_power":1.0},
		"decal":D + "filament_decal.png"},
	# Charcoal, cracked, the cracks glowing orange-red.
	{"id":"paint/cinder","slot":"paint","name":"Cinder","rarity":"rare","price":880,
		"livery":{"body":Color("2a2624"),"dark":Color("151211"),"trim":Color("3a2a22"),"wing":Color("33302e")},
		"finish":{"sheen":"matte","glow":Color("ff5a14"),"glow_on":["decal"],"glow_power":1.0},
		"decal":D + "cinder_decal.png"},
	# Deep blue scattered with gold stars.
	{"id":"paint/vesper","slot":"paint","name":"Vesper","rarity":"legendary","price":1700,
		"livery":{"body":Color("0e1a4a"),"dark":Color("070d26"),"trim":Color("1c2c6c"),"wing":Color("142262")},
		"finish":{"sheen":"satin","pearl":Color("6a7cff"),"pearl_amount":0.35,
			"glow":Color("ffe7a6"),"glow_on":["decal"],"glow_power":1.0},
		"decal":D + "vesper_decal.png"},
	# A dark pearl that shifts green to violet, ribbons of aurora in the paint.
	{"id":"paint/borealis","slot":"paint","name":"Borealis","rarity":"legendary","price":2300,
		"livery":{"body":Color("0b2a26"),"dark":Color("06120f"),"trim":Color("14403a"),"wing":Color("0e3430")},
		"finish":{"sheen":"satin","pearl":Color("9a6bff"),"pearl_amount":0.6,
			"glow":Color("28e6a4"),"glow_on":["decal"],"glow_power":1.0},
		"decal":D + "borealis_decal.png"},
	# Deep-sea blue-black with rows of cold lights along the body and wings.
	{"id":"paint/abyss","slot":"paint","name":"Abyss","rarity":"legendary","price":2800,
		"livery":{"body":Color("0a1822"),"dark":Color("050a10"),"trim":Color("12303c"),"wing":Color("0c1f2a")},
		"finish":{"sheen":"satin","glow":Color("28c8ff"),"glow_on":["decal"],"glow_power":1.0},
		"decal":D + "abyss_decal.png"},
]
