extends RefCounted
## The heritage batch: old flying liveries. Decals and bake are painted by
## art/blender/hero_plane/skins/heritage.py.

const T := "res://assets/models/hero_plane/skins/heritage/"

const SKINS := [
	{"id":"paint/pennant","slot":"paint","name":"Pennant","rarity":"common","price":110,
		"livery":{"body":Color("2f86a8"),"dark":Color("1f2f38"),"trim":Color("f1e8d0"),"wing":Color("2f86a8")},
		"decal":T + "pennant_decal.png"},
	{"id":"paint/courier","slot":"paint","name":"Courier","rarity":"uncommon","price":200,
		"livery":{"body":Color("2f5d46"),"dark":Color("23281f"),"trim":Color("e0a93a"),"wing":Color("e8dfc0")},
		"finish":{"sheen":"satin"},
		"decal":T + "courier_decal.png"},
	{"id":"paint/clubman","slot":"paint","name":"Clubman","rarity":"uncommon","price":310,
		"livery":{"body":Color("ece4cf"),"dark":Color("3a2430"),"trim":Color("6e2c48"),"wing":Color("f0e9d8")},
		"finish":{"sheen":"gloss"},
		"decal":T + "clubman_decal.png"},
	{"id":"paint/barnstormer","slot":"paint","name":"Barnstormer","rarity":"rare","price":720,
		"livery":{"body":Color("c4521f"),"dark":Color("3a1f16"),"trim":Color("f2c230"),"wing":Color("efdcae")},
		"finish":{"sheen":"gloss"},
		"decal":T + "barnstormer_decal.png"},
	{"id":"paint/meridian","slot":"paint","name":"Meridian","rarity":"legendary","price":2100,
		"livery":{"body":Color("1d2745"),"dark":Color("12172a"),"trim":Color("d8d4c4"),"wing":Color("e9e6da")},
		"finish":{"sheen":"gloss","pearl":Color("8aa0ff"),"pearl_amount":0.4},
		"decal":T + "meridian_decal.png",
		"bake":{"albedo":T + "meridian_albedo.jpg","mask":T + "meridian_mask.png","orm":T + "meridian_orm.jpg"}},
]
