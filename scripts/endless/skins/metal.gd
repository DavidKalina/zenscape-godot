extends RefCounted
## The metal batch: skins whose surface is the point. Bakes and decal are
## made by art/blender/hero_plane/skins/metal.py.

const D := "res://assets/models/hero_plane/skins/metal/"

const SKINS := [
	# Gunmetal: dark blued steel, the metal sheen at 0.55 so it stays dark;
	# a pale rule.
	{"id":"paint/gunmetal","slot":"paint","name":"Gunmetal","rarity":"common","price":5000,
		"livery":{"body":Color("2e3c52"),"dark":Color("101318"),"trim":Color("8a94a0"),"wing":Color("1e2a40")},
		"finish":{"sheen":"metal","metal":0.55},
		"decal":D + "gunmetal_decal.png"},
	# Rust: a wreck that still flies: chipped to steel, the steel rusted, rust
	# run back from every chip and gathered in the seams, the paint left chalky.
	{"id":"paint/rust","slot":"paint","name":"Rust","rarity":"uncommon","price":7500,
		"livery":{"body":Color("7a3a22"),"dark":Color("2a1c16"),"trim":Color("5a3020"),"wing":Color("8a6a4a")},
		"finish":{"sheen":"matte"},
		"bake":{"albedo":D + "rust_albedo.jpg","mask":D + "rust_mask.png","orm":D + "rust_orm.jpg"}},
	# Copper: polished copper nose to tail, verdigris in the seams and chips.
	{"id":"paint/copper","slot":"paint","name":"Copper","rarity":"uncommon","price":15000,
		"livery":{"body":Color("c47a3a"),"dark":Color("2a1c14"),"trim":Color("4f8a72"),"wing":Color("4f8a72")},
		"finish":{"sheen":"gloss","bare":1.0},
		"bake":{"albedo":D + "copper_albedo.jpg","mask":D + "copper_mask.png","orm":D + "copper_orm.jpg"}},
	# Brass: bare brass forward over oiled dark wood tones, duller than gold.
	{"id":"paint/brass","slot":"paint","name":"Brass","rarity":"rare","price":40000,
		"livery":{"body":Color("4a2e1a"),"dark":Color("21140b"),"trim":Color("a8964a"),"wing":Color("5e3e24")},
		"finish":{"bare":0.6},
		"bake":{"albedo":D + "brass_albedo.jpg","mask":D + "brass_mask.png","orm":D + "brass_orm.jpg"}},
	# Gold: gold nose to tail, a mirror, the scheme in black.
	{"id":"paint/gold","slot":"paint","name":"Gold","rarity":"legendary","price":90000,
		"livery":{"body":Color("f0b428"),"dark":Color("14110e"),"trim":Color("16120e"),"wing":Color("16120e")},
		"finish":{"bare":1.0},
		"bake":{"albedo":D + "gold_albedo.jpg","mask":D + "gold_mask.png","orm":D + "gold_orm.jpg"}},
]
