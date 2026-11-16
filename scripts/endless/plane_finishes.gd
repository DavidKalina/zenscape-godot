extends RefCounted
## The hangar's finish parts (docs/design/endless-flight/spec-hangar.md): what
## a look's `finish` and `wear` (scripts/endless/plane_look.gd) may name, each
## a row {id, name, price, rarity} as the shop's are (shop_stock.gd; a price
## inside its rarity's band, scripts/endless/economy.gd PRICE_BANDS; 0 is
## free, had by everyone). Nothing is sold yet: the hangar offers them all.
##
##   SHEENS    how the paint shines: the ids are ShopStock SHEENS' names
##   PEARL     the pearl (a colour seen edge-on), one part: its colour and
##             amount are the player's
##   GLOW      the glow after dark, one part: its colour, zones and power are
##             the player's
##   SURFACES  the look's `wear`: an atlas set the paint lies on. `bake` is
##             its maps ({albedo, mask, orm: a texture's path}, none the
##             plane's own; made by art/blender/hero_plane/hero_plane_bake.py)
##             and `bare` how far its bared metal mirrors (the shader's
##             finish_bare). The paint's four colours go where the surface's
##             mask leaves paint: on Gold, the scheme only.

const SHEENS := [
	{"id":"satin","name":"Satin","price":0,"rarity":"common"},
	{"id":"gloss","name":"Gloss","price":0,"rarity":"common"},
	{"id":"matte","name":"Matte","price":0,"rarity":"common"},
	{"id":"metal","name":"Metal","price":12000,"rarity":"uncommon"},
]
const PEARL := {"id":"pearl","name":"Pearl","price":9000,"rarity":"uncommon"}
const GLOW := {"id":"glow","name":"Glow","price":30000,"rarity":"rare"}

const SKINS := "res://assets/models/hero_plane/skins/"
const SURFACES := [
	# The plane's own atlas: flown a while, chipped and a little sooty.
	{"id":"own","name":"Painted","price":0,"rarity":"common","bake":{},"bare":0.0},
	# hero_plane_bake.py --wear 0 --dirt 0.
	{"id":"fresh","name":"Factory fresh","price":3000,"rarity":"common","bare":0.0,
		"bake":{"albedo":SKINS+"surface/fresh_albedo.jpg","mask":SKINS+"surface/fresh_mask.png","orm":SKINS+"surface/fresh_orm.jpg"}},
	# Meridian's own bake (skins/heritage.gd; --wear 0.1 --dirt 0.15), as a
	# surface, so that skin too is a whole look (PlaneLook `from_skin`).
	{"id":"kept","name":"Well kept","price":3500,"rarity":"common","bare":0.0,
		"bake":{"albedo":SKINS+"heritage/meridian_albedo.jpg","mask":SKINS+"heritage/meridian_mask.png","orm":SKINS+"heritage/meridian_orm.jpg"}},
	# hero_plane_bake.py --wear 1.6 --dirt 1.4.
	{"id":"weathered","name":"Weathered","price":4000,"rarity":"common","bare":0.0,
		"bake":{"albedo":SKINS+"surface/weathered_albedo.jpg","mask":SKINS+"surface/weathered_mask.png","orm":SKINS+"surface/weathered_orm.jpg"}},
	# The skins' own bakes (scripts/endless/skins/), as surfaces.
	{"id":"rust","name":"Rust","price":7500,"rarity":"uncommon","bare":0.0,
		"bake":{"albedo":SKINS+"metal/rust_albedo.jpg","mask":SKINS+"metal/rust_mask.png","orm":SKINS+"metal/rust_orm.jpg"}},
	{"id":"copper","name":"Copper","price":15000,"rarity":"uncommon","bare":1.0,
		"bake":{"albedo":SKINS+"metal/copper_albedo.jpg","mask":SKINS+"metal/copper_mask.png","orm":SKINS+"metal/copper_orm.jpg"}},
	{"id":"silver","name":"Bare silver","price":30000,"rarity":"rare","bare":0.0,
		"bake":{"albedo":SKINS+"demo/silverwing_albedo.jpg","mask":SKINS+"demo/silverwing_mask.png","orm":SKINS+"demo/silverwing_orm.jpg"}},
	{"id":"brass","name":"Brass","price":40000,"rarity":"rare","bare":0.6,
		"bake":{"albedo":SKINS+"metal/brass_albedo.jpg","mask":SKINS+"metal/brass_mask.png","orm":SKINS+"metal/brass_orm.jpg"}},
	{"id":"gold","name":"Gold","price":90000,"rarity":"legendary","bare":1.0,
		"bake":{"albedo":SKINS+"metal/gold_albedo.jpg","mask":SKINS+"metal/gold_mask.png","orm":SKINS+"metal/gold_orm.jpg"}},
]

## The row of `rows` (SHEENS, SURFACES) with `id`, or {}.
static func row(rows: Array, id: String) -> Dictionary:
	for r: Dictionary in rows:
		if r.id == id: return r
	return {}

## The index in `rows` of `id`, or 0 (the free first) when it has none.
static func index(rows: Array, id: String) -> int:
	for i in rows.size():
		if rows[i].id == id: return i
	return 0

## The surface whose maps are a skin's `bake` (by its albedo), or "" for a
## bake that is no surface here.
static func surface_of(bake: Dictionary) -> String:
	var albedo := String(bake.get("albedo",""))
	if albedo == "": return ""
	for r: Dictionary in SURFACES:
		if String((r.bake as Dictionary).get("albedo","")) == albedo: return r.id
	return ""

## A surface as the shader's values (PlaneFigure HERO_ATLAS's names and
## finish_bare): its maps loaded, none for the plane's own.
static func surface_values(id: String) -> Dictionary:
	var r := row(SURFACES,id)
	var out := {}
	if r.is_empty(): return out
	if float(r.bare) > 0.0: out["finish_bare"] = float(r.bare)
	var bake: Dictionary = r.bake
	for key: String in bake:
		var tex: Texture2D = load(String(bake[key])) if ResourceLoader.exists(String(bake[key])) else null
		if tex == null: push_error("PlaneFinishes: surface %s has no %s at %s" % [id,key,bake[key]])
		else: out[key+"_tex"] = tex
	return out
