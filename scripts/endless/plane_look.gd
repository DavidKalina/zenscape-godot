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
##   pattern  {"id": a PlanePatterns id, "a": hex, "b": hex}: a shape over the
##            paint in two colours (scripts/endless/plane_patterns.gd).
## Parts to come, each with its own key and its own lines in `apply`:
## `finish`, `decal`, `wear`.
##
## The book's look is worn through ShopStock `dress` (the one place that
## dresses the flight's plane, and only when the look's key changed), which
## calls `apply`. Nothing here runs per frame.

## The paint's zones, in the hangar's order (PlaneFigure HERO_SLOTS' keys).
const ZONES: Array[String] = ["body","trim","wing","dark"]

const PlaneFigure = preload("res://scripts/plane_figure.gd")

## The look `book` holds, or the worn skin's (`row`, its ShopStock paint row)
## as a look when it holds none: a copy, the hangar's to change.
static func of(book: PilotBook, row: Dictionary) -> Dictionary:
	if not book.look.is_empty(): return book.look.duplicate(true)
	return from_skin(row)

## The plane's own colour for a zone (what a skin without one shows).
static func own_colour(zone: String) -> Color:
	return PlaneFigure.HERO_SLOTS[zone][1]

## A ShopStock paint row as a look: its livery as the paint (the plane's own
## colours for the zones it lacks).
static func from_skin(row: Dictionary) -> Dictionary:
	var livery: Dictionary = row.get("livery",{})
	var paint := {}
	for zone in ZONES:
		var c: Color = livery.get(zone,own_colour(zone))
		paint[zone] = c.to_html(false)
	return {"paint":paint}

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
static func apply(figure: Node3D, look: Dictionary, livery: Dictionary, values: Dictionary) -> void:
	# Paint: the zones' colours over the skin's livery.
	for zone in ZONES:
		if (look.get("paint",{}) as Dictionary).has(zone): livery[zone] = colour(look,zone,livery.get(zone,own_colour(zone)))
	figure.repaint(livery)
	if not figure.has_method("refinish"): return
	# A part that changes the finish's values (finish, decal, wear) does it
	# here, before `refinish`.
	# Pattern: its mask and two colours, taken with the finish (PlaneFigure
	# HERO_PATTERN), so a refinish without one takes it off.
	values.merge(PlanePatterns.values(look.get("pattern")),true)
	figure.refinish(values)
	# A part with uniforms of its own (pattern) sets them here, after.
