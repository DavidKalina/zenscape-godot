class_name PlanePatterns
extends RefCounted
## The plane's patterns: shapes laid over the paint in two colours of the
## pilot's choosing (the look's `pattern`, scripts/endless/plane_look.gd;
## hero_surface.gdshader's pattern layer). A pattern is a mask in the atlas's
## UV, its R the share of colour A and its G of colour B, made by
## art/blender/hero_plane/patterns.py into DIR as <id>.png.
##
## A row:
##   id      the mask's file name and the look's `pattern.id`
##   name    as the hangar shows it
##   two     whether it has a colour B (the hangar offers B only then)
##   a, b    the colours it starts in when first picked (hex, no #)
##   price   coins, within its rarity's band (Economy.PRICE_BANDS); for the
##   rarity  shop. Nothing sells them yet: the hangar offers them all.

const DIR := "res://assets/models/hero_plane/patterns/"

const PATTERNS: Array[Dictionary] = [
	{"id":"tip_bands","name":"Tip bands","two":true,"a":"1f2a44","b":"f3ead6","price":2500,"rarity":"common"},
	{"id":"cheat_line","name":"Cheat line","two":true,"a":"1f2a44","b":"e9c84a","price":3000,"rarity":"common"},
	{"id":"split","name":"Two-tone","two":true,"a":"f3ead6","b":"1e1f22","price":4000,"rarity":"common"},
	{"id":"spine","name":"Racing stripes","two":true,"a":"e9c84a","b":"1e1f22","price":4500,"rarity":"common"},
	{"id":"chevrons","name":"Chevrons","two":true,"a":"1f2a44","b":"e9c84a","price":7000,"rarity":"uncommon"},
	{"id":"bands","name":"Recognition bands","two":true,"a":"1e1f22","b":"f3ead6","price":8000,"rarity":"uncommon"},
	{"id":"checker","name":"Checker","two":true,"a":"1e1f22","b":"f3ead6","price":10000,"rarity":"uncommon"},
	{"id":"scallops","name":"Scallops","two":true,"a":"a8322a","b":"f3ead6","price":12000,"rarity":"uncommon"},
	{"id":"sunburst","name":"Sunburst","two":true,"a":"e9c84a","b":"a8322a","price":28000,"rarity":"rare"},
]

## The row for `id`, {} when there is none.
static func item(id: String) -> Dictionary:
	for p in PATTERNS:
		if p.id == id: return p
	return {}

## Where `id`'s mask is.
static func path(id: String) -> String:
	return DIR+id+".png"

## A look's `pattern` ({id, a, b}) as the hero shader's values (PlaneFigure
## HERO_PATTERN's names), {} when it names no pattern there is: the mask is
## loaded here, so only the one worn is held.
static func values(pattern: Variant) -> Dictionary:
	if not pattern is Dictionary: return {}
	var row := item(str(pattern.get("id","")))
	if row.is_empty(): return {}
	var tex: Texture2D = load(path(row.id)) if ResourceLoader.exists(path(row.id)) else null
	if tex == null:
		push_error("PlanePatterns: %s has no mask at %s" % [row.id,path(row.id)])
		return {}
	return {"pattern_tex":tex,"pattern_on":1.0,"pattern_a":colour(pattern,"a"),"pattern_b":colour(pattern,"b")}

## A pattern's colour `slot` ("a" or "b"): the look's, else the row's own.
static func colour(pattern: Dictionary, slot: String) -> Color:
	var hex: Variant = pattern.get(slot)
	if hex is String and Color.html_is_valid(hex): return Color.html(hex)
	return Color.html(str(item(str(pattern.get("id",""))).get(slot,"ffffff")))
