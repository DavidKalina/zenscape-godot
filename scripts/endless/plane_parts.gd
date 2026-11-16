extends RefCounted
## The parts of a look that are bought (docs/design/endless-flight/spec-hangar.md,
## "Shop sells parts"): the patterns (scripts/endless/plane_patterns.gd), the
## surfaces other than the plane's own, the metal sheen, the pearl and the
## glow (scripts/endless/plane_finishes.gd) and the decals
## (scripts/endless/plane_decals.gd). Paint colours and the free rows of
## those catalogues are had by everyone and are no parts here.
##
## A part's id is its kind, a colon and its catalogue id, so it can share the
## pilot book's `owned` with the shop's items (those are slot/name):
##     pattern:<id>   surface:<id>   sheen:metal   finish:pearl   finish:glow
##     decal:<id>
## A part's row is the shop's kind of row: {id, slot (its SECTIONS name: the
## shop's section and the hangar's), name, price, rarity, part: true, thumb:
## [body, trim, wing, dark] for the shop's little plane}.
##
## This file knows looks (scripts/endless/plane_look.gd's Dictionary) and the
## catalogues, not the book or the shop: ShopStock (`has`, `buy`, `put_part`)
## asks it, the hangar and the shop ask ShopStock.

const PlaneFinishes = preload("res://scripts/endless/plane_finishes.gd")

## The sections the parts are listed under, in order.
const SECTIONS: Array[String] = ["pattern","finish","decal"]

## What a pearl and a glow start as when a part puts them on a look that has
## none (the hangar's finish section starts them the same).
const PEARL := "8c9fff"
const PEARL_AMOUNT := 0.5
const GLOW := "33daff"
const GLOW_ON := ["trim"]

## The shop's little plane for a part: [body, trim, wing, dark].
const THUMB_PLAIN := ["b9583b","2f6670","ece2c8","2f4a4f"]
const THUMBS := {
	"surface:fresh":["c8603f","2f6670","f3ead6","2f4a4f"],
	"surface:weathered":["8f5a48","3d5458","c9c0a8","33403f"],
	"surface:rust":["7a4a30","5a3a28","8f6a4c","3a2a22"],
	"surface:copper":["c47a4e","8a4a2c","d99a6c","4a2c1c"],
	"surface:silver":["c9cdd2","8d949c","e2e5e8","4a4f55"],
	"surface:brass":["c9a64a","8a6a24","dcc070","4a3a16"],
	"surface:gold":["f0c23c","b8861c","ffdc6a","5a4210"],
	"sheen:metal":["8f9aa6","5a6570","c2cad2","30363c"],
	"finish:pearl":["e8e2f2","b8a8e0","f6f2fa","6a6488"],
	"finish:glow":["20242c","33d1ff","2c323c","14161a"],
}

static var _rows: Array = []
static var _by_id := {}

## Every part, section by section, each in its catalogue's order.
static func all() -> Array:
	if _rows.is_empty():
		for p: Dictionary in PlanePatterns.PATTERNS:
			_add("pattern:"+String(p.id),"pattern",p,String(p.name),[String(p.a),String(p.b),"ece2c8",String(p.b)])
		for s: Dictionary in PlaneFinishes.SURFACES: _add("surface:"+String(s.id),"finish",s,String(s.name))
		for s: Dictionary in PlaneFinishes.SHEENS: _add("sheen:"+String(s.id),"finish",s,String(s.name)+" sheen")
		_add("finish:pearl","finish",PlaneFinishes.PEARL,String(PlaneFinishes.PEARL.name))
		_add("finish:glow","finish",PlaneFinishes.GLOW,String(PlaneFinishes.GLOW.name))
		for d: Dictionary in PlaneDecals.DECALS: _add("decal:"+String(d.id),"decal",d,String(d.name))
	return _rows

static func _add(id: String, section: String, from: Dictionary, name: String, thumb: Array = []) -> void:
	if int(from.price) <= 0: return
	if thumb.is_empty(): thumb = THUMBS.get(id,THUMB_PLAIN)
	var cols: Array = []
	for hex: String in thumb: cols.append(Color.html(hex))
	var row := {"id":id,"slot":section,"name":name,"price":int(from.price),"rarity":String(from.rarity),"part":true,"thumb":cols}
	_rows.append(row)
	_by_id[id] = row

## The parts of `section`.
static func listed(section: String) -> Array:
	return all().filter(func(r: Dictionary) -> bool: return r.slot == section)

## The part's row, {} for an id that is no part (a free row's too).
static func row(id: String) -> Dictionary:
	all()
	return _by_id.get(id,{})

## The parts `look` names, in SECTIONS' order. What a look lacks is the worn
## skin's own and no part of the look.
static func of_look(look: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var p: Variant = look.get("pattern")
	if p is Dictionary: _note(out,"pattern:"+str(p.get("id","")))
	if look.get("wear") is String: _note(out,"surface:"+String(look.wear))
	var f: Variant = look.get("finish")
	if f is Dictionary:
		if f.get("sheen") is String: _note(out,"sheen:"+String(f.sheen))
		if f.get("pearl") is String: _note(out,"finish:pearl")
		if f.get("glow") is String: _note(out,"finish:glow")
	if look.get("decal") is String: _note(out,"decal:"+String(look.decal))
	return out

static func _note(out: Array[String], id: String) -> void:
	if not row(id).is_empty(): out.append(id)

## The parts a skin (a ShopStock paint row) comes with: its decal, its bake
## as a surface, its metal sheen, pearl and glow.
static func of_skin(skin: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var surface := PlaneFinishes.surface_of(skin.get("bake",{}))
	if surface != "": _note(out,"surface:"+surface)
	var f: Dictionary = skin.get("finish",{})
	if f.has("sheen"): _note(out,"sheen:"+String(f.sheen))
	if f.has("pearl"): _note(out,"finish:pearl")
	if f.has("glow") or f.has("glow_on"): _note(out,"finish:glow")
	if skin.has("decal"):
		for d: Dictionary in PlaneDecals.DECALS:
			if String(d.path) == String(skin.decal): _note(out,"decal:"+String(d.id))
	return out

## Puts part `id` on `look`, in place of what the look had of its kind. A
## pattern keeps the look's two colours when it has them; a pearl or a glow
## already on the look stays as it is.
static func put(look: Dictionary, id: String) -> void:
	if row(id).is_empty(): return
	var kind := id.get_slice(":",0)
	var name := id.get_slice(":",1)
	match kind:
		"pattern":
			var was: Dictionary = look.pattern if look.get("pattern") is Dictionary else {}
			var p := {"id":name}
			for slot: String in ["a","b"]:
				p[slot] = was[slot] if was.get(slot) is String else String(PlanePatterns.item(name)[slot])
			look["pattern"] = p
		"surface": look["wear"] = name
		"decal": look["decal"] = name
		"sheen", "finish":
			if not look.get("finish") is Dictionary: look["finish"] = {}
			var f: Dictionary = look.finish
			if kind == "sheen": f["sheen"] = name
			elif name == "pearl":
				if not f.get("pearl") is String:
					f["pearl"] = PEARL
					f["pearl_amount"] = PEARL_AMOUNT
			elif not f.get("glow") is String:
				f["glow"] = GLOW
				f["glow_on"] = GLOW_ON.duplicate()
				f["glow_power"] = 1.0

## Takes the parts `ids` off `look`: each one's kind back to what `from` (a
## look, the last one kept) has of it, and where that has none to the skin's
## own (the key gone) or, inside a finish, to satin, no pearl, no glow.
static func take_off(look: Dictionary, ids: Array, from := {}) -> void:
	var f_from: Dictionary = from.finish if from.get("finish") is Dictionary else {}
	for id: String in ids:
		var name := id.get_slice(":",1)
		match id.get_slice(":",0):
			"pattern": _back(look,from,["pattern"])
			"surface": _back(look,from,["wear"])
			"decal": _back(look,from,["decal"])
			"sheen":
				if look.get("finish") is Dictionary: look.finish["sheen"] = f_from.get("sheen","satin")
			"finish":
				if look.get("finish") is Dictionary:
					_back(look.finish,f_from,["pearl","pearl_amount"] if name == "pearl" else ["glow","glow_on","glow_power"])

static func _back(to: Dictionary, from: Dictionary, keys: Array) -> void:
	for key: String in keys:
		if not from.has(key): to.erase(key)
		elif from[key] is Dictionary or from[key] is Array: to[key] = from[key].duplicate(true)
		else: to[key] = from[key]
