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
		"livery":{"body":Color("6f8497"),"dark":Color("2a343e"),"trim":Color("6f8497"),"wing":Color("7c91a3")},
		"finish":{"sheen":"satin"},
		"decal":D + "shark_decal.png"},
	{"id":"paint/bee","slot":"paint","name":"Bee","rarity":"uncommon","price":300,
		"livery":{"body":Color("f2b81c"),"dark":Color("17120d"),"trim":Color("17120d"),"wing":Color("efb21c")},
		"finish":{"sheen":"gloss"},
		"decal":D + "bee_decal.png"},
	{"id":"paint/moth","slot":"paint","name":"Moth","rarity":"rare","price":700,
		"livery":{"body":Color("5e9a46"),"dark":Color("1d2b17"),"trim":Color("b9d68c"),"wing":Color("8cc458")},
		"finish":{"sheen":"satin"},
		"decal":D + "moth_decal.png"},
	{"id":"paint/koi","slot":"paint","name":"Koi","rarity":"legendary","price":2100,
		"livery":{"body":Color("f4f1ea"),"dark":Color("2a2a30"),"trim":Color("efe8dd"),"wing":Color("f7f4ee")},
		"finish":{"sheen":"gloss","pearl":Color("ffd9a8"),"pearl_amount":0.55},
		"decal":D + "koi_decal.png"},
]
