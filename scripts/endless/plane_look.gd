class_name PlaneLook
extends RefCounted
## The plane's look as data (docs/design/endless-flight/spec-hangar.md): one
## Dictionary the hangar edits (scripts/endless/ui/hangar_page.gd), the
## pilot's book keeps (PilotBook `look`, `set_look`) and `apply` puts on a
## PlaneFigure. It holds JSON's own types only, so the book writes it as it
## is:
##
##     {"paint": {"body": "b9583b", "trim": "2f6670", "wing": "ece2c8", "dark": "2f4a4f"}}
##
## Each part of a look is a key of its own, and a look may lack any of them:
## what it lacks comes from the skin worn under it (the book's `worn.paint`,
## a ShopStock row), so an empty look is that skin as the shop sells it.
##   paint    the four zones' colours, hex without the #.
##   finish   how the paint shines, {"sheen": a ShopStock SHEENS name,
##            "pearl": hex, "pearl_amount": 0..1, "glow": hex, "glow_on":
##            [zones, and "decal" for the marks], "glow_power": 0..1.3};
##            no pearl or no glow without its colour. In place of the whole
##            of the skin's finish but its bared metal, which is the wear's.
##   wear     the surface the paint lies on: a PlaneFinishes SURFACES id
##            (scripts/endless/plane_finishes.gd), its atlas maps and how its
##            bared metal mirrors, in place of the skin's bake.
##   pattern  {"id": a PlanePatterns id, "a": hex, "b": hex}: a shape over the
##            paint in two colours (scripts/endless/plane_patterns.gd).
## Parts to come, each with its own key and its own lines in `apply`:
## `decal`.
##
## The book's look is worn through ShopStock `dress` (the one place that
## dresses the flight's plane, and only when the look's key changed), which
## calls `apply`. Nothing here runs per frame.

## The paint's zones, in the hangar's order (PlaneFigure HERO_SLOTS' keys).
const ZONES: Array[String] = ["body","trim","wing","dark"]

const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneFinishes = preload("res://scripts/endless/plane_finishes.gd")

## The shader's values (PlaneFigure HERO_FINISH, HERO_ATLAS) a look's
## `finish` sets in place of the skin's, and those its `wear` does.
const FINISH_KEYS: Array[String] = ["finish_rough","finish_coat","finish_metal","finish_sheen","finish_chalk",
	"pearl","pearl_amount","glow","glow_slots","glow_power","glow_decal"]
const WEAR_KEYS: Array[String] = ["albedo_tex","mask_tex","orm_tex","finish_bare"]

## The look `book` holds, or the worn skin's (`row`, its ShopStock paint row)
## as a look when it holds none: a copy, the hangar's to change.
static func of(book: PilotBook, row: Dictionary) -> Dictionary:
	if not book.look.is_empty(): return book.look.duplicate(true)
	return from_skin(row)

## The plane's own colour for a zone (what a skin without one shows).
static func own_colour(zone: String) -> Color:
	return PlaneFigure.HERO_SLOTS[zone][1]

## A ShopStock paint row as a look: its livery as the paint (the plane's own
## colours for the zones it lacks), its finish when it has one, and its bake
## as the wear when that is a surface (PlaneFinishes).
static func from_skin(row: Dictionary) -> Dictionary:
	var livery: Dictionary = row.get("livery",{})
	var paint := {}
	for zone in ZONES:
		var c: Color = livery.get(zone,own_colour(zone))
		paint[zone] = c.to_html(false)
	var out := {"paint":paint}
	var f: Dictionary = row.get("finish",{})
	var finish := {}
	for key: String in f:
		match key:
			"bare": pass
			"pearl", "glow": finish[key] = (f[key] as Color).to_html(false)
			"glow_on": finish[key] = (f[key] as Array).duplicate()
			_: finish[key] = f[key]
	if not finish.is_empty(): out["finish"] = finish
	var surface := PlaneFinishes.surface_of(row.get("bake",{}))
	if surface != "": out["wear"] = surface
	return out

## A look's `finish` as a ShopStock row ({id, finish}: its colours as
## Colors), for ShopStock `finish_values` to turn into the shader's values;
## {} for a look with none.
static func finish_row(look: Dictionary) -> Dictionary:
	if not look.get("finish") is Dictionary: return {}
	var f: Dictionary = look.finish
	var finish := {}
	if f.get("sheen") is String: finish["sheen"] = f.sheen
	if f.has("metal"): finish["metal"] = float(f.metal)
	if f.get("pearl") is String and Color.html_is_valid(f.pearl):
		finish["pearl"] = Color.html(f.pearl)
		finish["pearl_amount"] = clampf(float(f.get("pearl_amount",0.6)),0.0,1.0)
	if f.get("glow") is String and Color.html_is_valid(f.glow):
		finish["glow"] = Color.html(f.glow)
		var on: Array = []
		for slot: Variant in (f.get("glow_on",["trim"]) as Array):
			if slot is String and (ZONES.has(slot) or slot == "decal"): on.append(slot)
		finish["glow_on"] = on
		finish["glow_power"] = float(f.get("glow_power",1.0))
	return {"id":"look","finish":finish}

## A zone's colour in `look`, or `default` when the look has none for it.
static func colour(look: Dictionary, zone: String, default := Color.WHITE) -> Color:
	var paint: Variant = look.get("paint")
	if paint is Dictionary and paint.get(zone) is String and Color.html_is_valid(paint[zone]): return Color.html(paint[zone])
	return default

## Sets a zone's colour in `look`.
static func set_colour(look: Dictionary, zone: String, c: Color) -> void:
	if not look.get("paint") is Dictionary: look["paint"] = {}
	look["paint"][zone] = Color(c.r,c.g,c.b).to_html(false)

## Puts `look` on `figure` (a PlaneFigure) over a skin: `livery` its zones'
## colours and `values` its finish as the shader's values (PlaneFigure
## HERO_FINISH's names; ShopStock `finish_values`), both this call's to
## change. What the look lacks stays the skin's. Each part of the look
## changes what the skin alone would set, then the figure takes it once.
## `finish` is the look's own finish as the shader's values (ShopStock
## `finish_values(PlaneLook.finish_row(look))`: this file does not load
## ShopStock).
static func apply(figure: Node3D, look: Dictionary, livery: Dictionary, values: Dictionary, finish := {}) -> void:
	# Paint: the zones' colours over the skin's livery.
	for zone in ZONES:
		if (look.get("paint",{}) as Dictionary).has(zone): livery[zone] = colour(look,zone,livery.get(zone,own_colour(zone)))
	figure.repaint(livery)
	if not figure.has_method("refinish"): return
	# A part that changes the finish's values (finish, decal, wear) does it
	# here, before `refinish`.
	# Finish: the look's sheen, pearl and glow in place of the skin's.
	if look.get("finish") is Dictionary:
		for key in FINISH_KEYS: values.erase(key)
		values.merge(finish,true)
	# Wear: the surface's maps and bared metal in place of the skin's bake.
	if look.get("wear") is String and not PlaneFinishes.row(PlaneFinishes.SURFACES,look.wear).is_empty():
		for key in WEAR_KEYS: values.erase(key)
		values.merge(PlaneFinishes.surface_values(look.wear),true)
	# Pattern: its mask and two colours, taken with the finish (PlaneFigure
	# HERO_PATTERN), so a refinish without one takes it off.
	values.merge(PlanePatterns.values(look.get("pattern")),true)
	figure.refinish(values)
	# A part with uniforms of its own (pattern) sets them here, after.
