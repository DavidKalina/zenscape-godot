extends RefCounted
## The wild batch: animals and plants. Decals painted by
## art/blender/hero_plane/skins/wild.py.

const D := "res://assets/models/hero_plane/skins/wild/"

const SKINS := [
	{"id":"paint/kingfisher","slot":"paint","name":"Kingfisher","rarity":"common","price":110,
		"livery":{"body":Color("1f8fb8"),"dark":Color("1d3a52"),"trim":Color("f08a1c"),"wing":Color("2a9fc4")},
		"finish":{"sheen":"gloss"},
		"decal":D + "kingfisher_decal.png"},
	{"id":"paint/shark","slot":"paint","name":"Shark","rarity":"uncommon","price":180,
		"livery":{"body":Color("68798a"),"dark":Color("2a343e"),"trim":Color("68798a"),"wing":Color("7a8b9a")},
		"finish":{"sheen":"satin"},
		"decal":D + "shark_decal.png"},
	{"id":"paint/bee","slot":"paint","name":"Bee","rarity":"uncommon","price":300,
		"livery":{"body":Color("f2b81c"),"dark":Color("17120d"),"trim":Color("17120d"),"wing":Color("f7cf4a")},
		"finish":{"sheen":"gloss"},
		"decal":D + "bee_decal.png"},
	{"id":"paint/moth","slot":"paint","name":"Moth","rarity":"rare","price":700,
		"livery":{"body":Color("7a5f45"),"dark":Color("2e231b"),"trim":Color("6f5a40"),"wing":Color("a58b66")},
		"finish":{"sheen":"matte"},
		"decal":D + "moth_decal.png"},
	{"id":"paint/koi","slot":"paint","name":"Koi","rarity":"legendary","price":2100,
		"livery":{"body":Color("f4f1ea"),"dark":Color("2a2a30"),"trim":Color("efe8dd"),"wing":Color("f7f4ee")},
		"finish":{"sheen":"gloss","pearl":Color("ffd9c4"),"pearl_amount":0.35},
		"decal":D + "koi_decal.png"},
]
