extends RefCounted
## The hangar's decal section (scripts/endless/ui/hangar_page.gd; the look's
## `decal`, scripts/endless/plane_look.gd): one decal over the paint, picked
## from a list: none, then the catalogue's
## (scripts/endless/plane_decals.gd), the emblems before the whole-plane
## ones (a skin's own decal is one of those: the look names it, PlaneLook
## `from_skin`). Each line names its part (the row's `parts`): the page locks the
## ones not had.
##
## A section as paint_section.gd says; its one row is a `list` row.

const TITLE := "Decal"
const KINDS := {"emblem":"emblem","full":"whole plane"}

var look := {}
## The list's ids, top to bottom: PlaneDecals.NONE, then the catalogue's.
var _ids: Array[String] = []
var _names: Array[String] = []
var _notes: Array[String] = []
var _parts: Array[String] = []

func _init() -> void:
	_ids = [PlaneDecals.NONE]
	_names = ["None"]
	_notes = [""]
	_parts = [""]
	for row in PlaneDecals.DECALS:
		_ids.append(String(row.id))
		_parts.append("decal:"+String(row.id))
		_names.append(String(row.name))
		_notes.append(String(KINDS.get(row.kind,"")))

func begin(to: Dictionary) -> void:
	look = to

## The list's index of the look's decal (None for a look without one, or
## for an id the catalogue has lost).
func picked() -> int:
	var id: Variant = look.get("decal","")
	var at := _ids.find(id) if id is String else -1
	return maxi(at,0)

func rows() -> Array[Dictionary]:
	return [{"id":"decal","label":"Decal","kind":"list","names":_names,"notes":_notes,"parts":_parts,"on":picked()}]

func change(id: String, dir: int) -> bool:
	return id == "decal" and _pick(picked()+dir)

func set_to(id: String, v: float) -> bool:
	return id == "decal" and _pick(int(v))

func _pick(i: int) -> bool:
	i = clampi(i,0,_ids.size()-1)
	if i == picked(): return false
	look["decal"] = _ids[i]
	return true
