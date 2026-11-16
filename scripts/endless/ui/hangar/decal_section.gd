extends RefCounted
## The hangar's decal section (scripts/endless/ui/hangar_page.gd; the look's
## `decal`, scripts/endless/plane_look.gd): one decal over the paint, picked
## from a list: none, the worn skin's own, then the catalogue's
## (scripts/endless/plane_decals.gd), the emblems before the whole-plane
## ones. All can be picked for now (the shop will lock what is not owned).
##
## A section as paint_section.gd says, with a row kind of its own that the
## page draws for any section:
##   {id, label, kind:"list", names:[String], on:int, notes:[String] (optional,
##    a quiet word at each line's right), lines:int (optional, the lines shown)}
## Up and Down (or Left and Right, or the wheel) step through it by
## `change(id, dir)`; a click on a line is `set_to(id, index)`.

const TITLE := "Decal"
const KINDS := {"emblem":"emblem","full":"whole plane"}

var look := {}
## The list's ids, top to bottom: PlaneDecals.NONE, "" (the skin's own), then
## the catalogue's.
var _ids: Array[String] = []
var _names: Array[String] = []
var _notes: Array[String] = []

func _init() -> void:
	_ids = [PlaneDecals.NONE,""]
	_names = ["None","Skin's own"]
	_notes = ["",""]
	for row in PlaneDecals.DECALS:
		_ids.append(String(row.id))
		_names.append(String(row.name))
		_notes.append(String(KINDS.get(row.kind,"")))

func begin(to: Dictionary) -> void:
	look = to

## The list's index of the look's decal (the skin's own for none, or for an
## id the catalogue has lost).
func picked() -> int:
	var id: Variant = look.get("decal","")
	var at := _ids.find(id) if id is String else -1
	return at if at >= 0 else 1

func rows() -> Array[Dictionary]:
	return [{"id":"decal","label":"Decal","kind":"list","names":_names,"notes":_notes,"on":picked()}]

func change(id: String, dir: int) -> bool:
	return id == "decal" and _pick(picked()+dir)

func set_to(id: String, v: float) -> bool:
	return id == "decal" and _pick(int(v))

func _pick(i: int) -> bool:
	i = clampi(i,0,_ids.size()-1)
	if i == picked(): return false
	if _ids[i] == "": look.erase("decal")
	else: look["decal"] = _ids[i]
	return true
