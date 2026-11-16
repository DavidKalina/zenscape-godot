extends RefCounted
## The hangar's preset section (scripts/endless/ui/hangar_page.gd; a section
## is what paint_section.gd says): whole looks to load in place of the one
## being edited, and the pilot's own slots to save it in.
##   Preset    a list: the look as it stands, the look the last load replaced
##             (when that was no preset), the pilot's own saved looks, then
##             the shop's skins (ShopStock paint rows, each a preset), the
##             ones had first. Stepping through it only shows a line on the
##             plane (`preview`); Enter loads the one shown (the page:
##             `line`), and on a skin not had goes to its buy row.
##   Save to   one of the pilot's slots
##   Save      the look as it stands kept in that slot, over what was there
##             (`press`)
## It changes nothing of the look itself: `change` and `set_to` return false.
## Besides a section's own it has `setup(book)` (before `begin`), `preview()`
## (the look to show in place of the edited one, {} for none), `line()` (the
## preset picked: {name, look, skin, part}) and `press(id)` (a button row).

const ShopStock = preload("res://scripts/endless/shop_stock.gd")

const TITLE := "Preset"

var look := {}
var book: PilotBook
## The line picked in the list, and the slot picked to save in.
var at := 0
var slot := 0
## The list's lines: {name, note, part (a skin's id, "" else), look ({} for
## the look as it stands), skin}.
var _lines: Array[Dictionary] = []

func setup(b: PilotBook) -> void:
	book = b

func begin(to: Dictionary) -> void:
	look = to
	at = 0
	_list()

func _list() -> void:
	_lines.clear()
	var name := ShopStock.saved_as(book,look)
	_lines.append({"name":"Current look","note":name if name != "" else "not saved","part":"","look":{},"skin":""})
	if book.presets.get(ShopStock.LAST) is Dictionary:
		_lines.append({"name":"Previous look","note":"replaced","part":"","look":book.presets[ShopStock.LAST],"skin":""})
	for n in ShopStock.CUSTOM_SLOTS:
		var saved: Variant = book.presets.get(str(n+1))
		if saved is Dictionary: _lines.append({"name":ShopStock.custom_name(str(n+1)),"note":"yours","part":"","look":saved,"skin":""})
	# The skins, the ones had first, each in the shop's order.
	for had: bool in [true,false]:
		for i: Dictionary in ShopStock.items("paint"):
			if ShopStock.has(book,i.id) != had: continue
			_lines.append({"name":String(i.name),"note":ShopStock.rarity(i),"part":String(i.id),"look":ShopStock.preset(i.id),"skin":String(i.id)})

func line() -> Dictionary:
	return _lines[at]

func preview() -> Dictionary:
	return _lines[at].look

func rows() -> Array[Dictionary]:
	# The look may have changed in another section since `begin`.
	var name := ShopStock.saved_as(book,look)
	_lines[0].note = name if name != "" else "not saved"
	var names: Array[String] = []
	var notes: Array[String] = []
	var parts: Array[String] = []
	for l in _lines:
		names.append(l.name)
		notes.append(l.note)
		parts.append(l.part)
	var slots: Array[String] = []
	for n in ShopStock.CUSTOM_SLOTS: slots.append(ShopStock.custom_name(str(n+1)))
	var full := book.presets.get(str(slot+1)) is Dictionary
	# A glow shows after dark only.
	var shown: Dictionary = preview() if not preview().is_empty() else look
	var glows: bool = shown.get("finish") is Dictionary and shown.finish.get("glow") is String
	return [
		{"id":"preset","label":"Preset","kind":"list","names":names,"notes":notes,"parts":parts,"on":at,"load":true,"night":glows},
		{"id":"slot","label":"Save to","kind":"choice","opts":slots,"on":slot},
		{"id":"save","label":("Save over %s" if full else "Save look as %s") % slots[slot],"kind":"button"},
	]

func change(id: String, dir: int) -> bool:
	match id:
		"preset": at = clampi(at+dir,0,_lines.size()-1)
		"slot": slot = posmod(slot+dir,ShopStock.CUSTOM_SLOTS)
	return false

func set_to(id: String, v: float) -> bool:
	match id:
		"preset": at = clampi(int(v),0,_lines.size()-1)
		"slot": slot = clampi(int(v),0,ShopStock.CUSTOM_SLOTS-1)
	return false

## The Save row: the look kept in the slot picked.
func press(id: String) -> void:
	if id != "save": return
	ShopStock.save_custom(book,slot,look)
	_list()
