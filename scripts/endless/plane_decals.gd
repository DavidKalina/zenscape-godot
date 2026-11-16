class_name PlaneDecals
extends RefCounted
## The decals the hangar lays over the plane's paint (the look's `decal`,
## scripts/endless/plane_look.gd; picked in
## scripts/endless/ui/hangar/decal_section.gd): each one premultiplied RGBA
## picture in the atlas's UV, its colours fixed in the image
## (art/blender/hero_plane/hero_plane_decal.py).
##
## A row: id (what the look keeps), name, path, kind ("emblem": a small mark
## or two, clear elsewhere, art/blender/hero_plane/skins/emblems.py; "full":
## a skin's own whole-plane decal, named after its skin, so it goes over any
## paint), and a rarity and price for the shop (Economy PRICE_BANDS).
## The full ones repeat their paths from scripts/endless/skins/*.gd rather
## than read ShopStock, which calls PlaneLook: no script cycle.
##
## The look's `decal` is an id here, "" (or no key) for the worn skin's own
## decal, or NONE for no decal at all.

const NONE := "none"
const E := "res://assets/models/hero_plane/skins/emblems/"
const S := "res://assets/models/hero_plane/skins/"

const DECALS: Array[Dictionary] = [
	{"id":"roundel_ember","name":"Ember Roundel","kind":"emblem","path":E + "roundel_ember_decal.png","rarity":"common","price":2000},
	{"id":"roundel_tide","name":"Tide Roundel","kind":"emblem","path":E + "roundel_tide_decal.png","rarity":"common","price":2000},
	{"id":"roundel_meadow","name":"Meadow Roundel","kind":"emblem","path":E + "roundel_meadow_decal.png","rarity":"common","price":2000},
	{"id":"number_5","name":"Race Number","kind":"emblem","path":E + "number_5_decal.png","rarity":"common","price":2500},
	{"id":"flash","name":"Fin Flash","kind":"emblem","path":E + "flash_decal.png","rarity":"common","price":2500},
	{"id":"streamer","name":"Streamer","kind":"emblem","path":E + "streamer_decal.png","rarity":"common","price":3000},
	{"id":"star","name":"Gold Star","kind":"emblem","path":E + "star_decal.png","rarity":"common","price":3500},
	{"id":"bolt","name":"Bolt","kind":"emblem","path":E + "bolt_decal.png","rarity":"common","price":4000},
	{"id":"swift","name":"Swift","kind":"emblem","path":E + "swift_decal.png","rarity":"common","price":5000},
	{"id":"laurel","name":"Laurel","kind":"emblem","path":E + "laurel_decal.png","rarity":"uncommon","price":6000},
	{"id":"compass","name":"Compass Rose","kind":"emblem","path":E + "compass_decal.png","rarity":"uncommon","price":8000},
	{"id":"skin_pennant","name":"Pennant","kind":"full","path":S + "heritage/pennant_decal.png","rarity":"uncommon","price":6000},
	{"id":"skin_courier","name":"Courier","kind":"full","path":S + "heritage/courier_decal.png","rarity":"uncommon","price":6500},
	{"id":"skin_clubman","name":"Clubman","kind":"full","path":S + "heritage/clubman_decal.png","rarity":"uncommon","price":8000},
	{"id":"skin_barnstormer","name":"Barnstormer","kind":"full","path":S + "heritage/barnstormer_decal.png","rarity":"uncommon","price":12000},
	{"id":"skin_meridian","name":"Meridian","kind":"full","path":S + "heritage/meridian_decal.png","rarity":"rare","price":25000},
	{"id":"skin_chequer","name":"Chequer","kind":"full","path":S + "demo/chequer_decal.png","rarity":"uncommon","price":10000},
	{"id":"skin_gunmetal","name":"Gunmetal","kind":"full","path":S + "metal/gunmetal_decal.png","rarity":"uncommon","price":6000},
	{"id":"skin_kingfisher","name":"Kingfisher","kind":"full","path":S + "wild/kingfisher_decal.png","rarity":"uncommon","price":6000},
	{"id":"skin_shark","name":"Shark","kind":"full","path":S + "wild/shark_decal.png","rarity":"uncommon","price":7000},
	{"id":"skin_bee","name":"Bee","kind":"full","path":S + "wild/bee_decal.png","rarity":"uncommon","price":8000},
	{"id":"skin_moth","name":"Moth","kind":"full","path":S + "wild/moth_decal.png","rarity":"uncommon","price":12000},
	{"id":"skin_koi","name":"Koi","kind":"full","path":S + "wild/koi_decal.png","rarity":"rare","price":25000},
	{"id":"skin_filament","name":"Filament","kind":"full","path":S + "glow/filament_decal.png","rarity":"uncommon","price":12000},
	{"id":"skin_cinder","name":"Cinder","kind":"full","path":S + "glow/cinder_decal.png","rarity":"uncommon","price":15000},
	{"id":"skin_vesper","name":"Vesper","kind":"full","path":S + "glow/vesper_decal.png","rarity":"rare","price":25000},
	{"id":"skin_borealis","name":"Borealis","kind":"full","path":S + "glow/borealis_decal.png","rarity":"rare","price":30000},
	{"id":"skin_abyss","name":"Abyss","kind":"full","path":S + "glow/abyss_decal.png","rarity":"rare","price":35000},
]

## The row for `id`, or {}.
static func item(id: String) -> Dictionary:
	for row in DECALS:
		if row.id == id: return row
	return {}

## The decal's picture, or null when there is no such id or file. Loaded
## when asked for (a look change); the engine's cache keeps it while worn.
static func texture(id: String) -> Texture2D:
	var row := item(id)
	if row.is_empty() or not ResourceLoader.exists(String(row.path)): return null
	return load(String(row.path)) as Texture2D

## The look's `decal` put into a finish's `values` (PlaneFigure HERO_FINISH's
## decal_tex and decal_on): untouched for "" (the skin's own), off for NONE,
## else the catalogue's; an id it does not know leaves the skin's.
static func into(values: Dictionary, id: String) -> void:
	if id == "": return
	if id == NONE:
		values["decal_tex"] = null
		values["decal_on"] = 0.0
		return
	var tex := texture(id)
	if tex == null: return
	values["decal_tex"] = tex
	values["decal_on"] = 1.0
