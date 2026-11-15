extends RefCounted
## The metal batch: skins whose surface is the point. Bakes and decal are
## made by art/blender/hero_plane/skins/metal.py.

const D := "res://assets/models/hero_plane/skins/metal/"

const SKINS := [
	# Gunmetal: the metal sheen on a near-black blue paint, a pale rule.
	{"id":"paint/gunmetal","slot":"paint","name":"Gunmetal","rarity":"common","price":110,
		"livery":{"body":Color("3a4452"),"dark":Color("171b22"),"trim":Color("8a94a0"),"wing":Color("2c3644")},
		"finish":{"sheen":"metal"},
		"decal":D + "gunmetal_decal.png"},
	# Rust: the paint mostly gone, stained and chipped.
	{"id":"paint/rust","slot":"paint","name":"Rust","rarity":"uncommon","price":160,
		"livery":{"body":Color("9a4c22"),"dark":Color("2a1c16"),"trim":Color("6e3a1e"),"wing":Color("a06a40")},
		"finish":{"sheen":"matte"},
		"bake":{"albedo":D + "rust_albedo.jpg","mask":D + "rust_mask.png","orm":D + "rust_orm.jpg"}},
	# Copper: bare copper forward, seams going green.
	{"id":"paint/copper","slot":"paint","name":"Copper","rarity":"uncommon","price":330,
		"livery":{"body":Color("c47a3a"),"dark":Color("3a2418"),"trim":Color("4f8a72"),"wing":Color("8f5430")},
		"finish":{"sheen":"metal"},
		"bake":{"albedo":D + "copper_albedo.jpg","mask":D + "copper_mask.png","orm":D + "copper_orm.jpg"}},
	# Brass: bare brass forward over oiled dark wood tones.
	{"id":"paint/brass","slot":"paint","name":"Brass","rarity":"rare","price":780,
		"livery":{"body":Color("5a3a22"),"dark":Color("2a1a10"),"trim":Color("c9a23c"),"wing":Color("6e4a2c")},
		"finish":{"sheen":"gloss"},
		"bake":{"albedo":D + "brass_albedo.jpg","mask":D + "brass_mask.png","orm":D + "brass_orm.jpg"}},
	# Gold: leaf over a dark deck, fresh as the day it was laid.
	{"id":"paint/gold","slot":"paint","name":"Gold","rarity":"legendary","price":2600,
		"livery":{"body":Color("f0b428"),"dark":Color("14110e"),"trim":Color("ffd25a"),"wing":Color("2a2420")},
		"finish":{"sheen":"metal"},
		"bake":{"albedo":D + "gold_albedo.jpg","mask":D + "gold_mask.png","orm":D + "gold_orm.jpg"}},
]
