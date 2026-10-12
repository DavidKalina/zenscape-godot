extends RefCounted
## What there is to do in the world (docs/design/ledger/round1.md): regions,
## their isles, each isle's named objectives, read from data/ledger/. The
## index (ledger.json) names the objective types, the isle card's rows they
## count under (in the card's order) and the region files; a region file
## (ruins.json) lists its isles and, for each, its objectives: {slug, type,
## name, row (optional: the type's row if left out)}.
##
## An objective's id is "<isle>/<slug>" (the challenge recorder's key style,
## scripts/challenges/challenge_progress.gd on feature/challenge-recorder):
## the isle's id is a motif's own (scripts/kit_isle/kit_motif.gd `id`) or
## the kit isle's name in snake case ("aqueduct_isle"), and the slug is what
## the isle's code calls it (a token's name, kit_tokens.gd `spots_for`).
## Nothing here knows where anything stands: placement stays in the isle's
## code, so the isles can move and grow without the ids changing.
##
## Nothing is done here either: what the player has done is the ledger's
## (scripts/ledger/ledger.gd). This only answers what there is.

const INDEX := "res://data/ledger/ledger.json"
const DIR := "res://data/ledger"
const FORMAT := 1
## A slug: lower case letters, digits, "_" and "-".
const SLUG := "^[a-z0-9_-]+$"

## type -> {row}
var types := {}
## The card's rows in order: {id, icon, label}.
var rows: Array[Dictionary] = []
## Regions in order: {id, name, isles: [isle ids]}.
var regions: Array[Dictionary] = []
## isle id -> {id, region, objectives: [objective ids, in order]}
var isles := {}
## objective id -> {id, isle, region, slug, type, name, row}
var objectives := {}
## What was wrong with the data (a duplicate id, an unknown type, a bad
## slug, a file that won't parse); an objective with an error is left out.
var errors: PackedStringArray = []

static func make(index := INDEX) -> RefCounted:
	var registry: RefCounted = new()
	registry.read(index)
	return registry

## An objective's id: "<isle>/<slug>".
static func objective_id(isle: String, slug: String) -> String:
	return "%s/%s" % [isle,slug]

## Reads the index at `index` and every region it names (from its folder).
func read(index := INDEX) -> void:
	types = {}
	rows = []
	regions = []
	isles = {}
	objectives = {}
	errors = []
	var data := _json(index)
	if data.is_empty(): return
	var t: Variant = data.get("types",{})
	if t is Dictionary:
		for type: Variant in t:
			var spec: Variant = t[type]
			types[str(type)] = {"row":str((spec as Dictionary).get("row","")) if spec is Dictionary else ""}
	for row: Variant in data.get("rows",[]):
		if row is Dictionary: rows.append({"id":str(row.get("id","")),"icon":str(row.get("icon","")),"label":str(row.get("label",""))})
	var dir := index.get_base_dir()
	for region: Variant in data.get("regions",[]):
		_read_region("%s/%s.json" % [dir,str(region)])

func _read_region(path: String) -> void:
	var data := _json(path)
	if data.is_empty(): return
	var region := str(data.get("id",path.get_file().get_basename()))
	var entry := {"id":region,"name":str(data.get("name",region)),"isles":[]}
	regions.append(entry)
	for isle: Variant in data.get("isles",[]):
		if not isle is Dictionary: continue
		var isle_id := str(isle.get("id",""))
		if isle_id.is_empty() or isles.has(isle_id):
			errors.append("%s: isle '%s' empty or listed twice" % [path,isle_id])
			continue
		(entry.isles as Array).append(isle_id)
		var listed: Array[String] = []
		isles[isle_id] = {"id":isle_id,"region":region,"objectives":listed}
		for o: Variant in isle.get("objectives",[]):
			if o is Dictionary: _add(o,isle_id,region,listed,path)

func _add(o: Dictionary, isle: String, region: String, listed: Array[String], path: String) -> void:
	var slug := str(o.get("slug",""))
	var type := str(o.get("type",""))
	var id := objective_id(isle,slug)
	var slugs := RegEx.create_from_string(SLUG)
	if slugs.search(slug) == null:
		errors.append("%s: '%s' isn't a slug" % [path,id])
		return
	if objectives.has(id):
		errors.append("%s: '%s' listed twice" % [path,id])
		return
	if not types.has(type):
		errors.append("%s: '%s' has an unknown type '%s'" % [path,id,type])
		return
	var row := str(o.get("row",types[type].row))
	if row_spec(row).is_empty():
		errors.append("%s: '%s' counts under an unknown row '%s'" % [path,id,row])
		return
	objectives[id] = {"id":id,"isle":isle,"region":region,"slug":slug,"type":type,"name":str(o.get("name",slug)),"row":row}
	listed.append(id)

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("%s: missing" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s: not a JSON object" % path)
		return {}
	if int((parsed as Dictionary).get("format",0)) > FORMAT:
		errors.append("%s: format %s is newer than this game reads (%d)" % [path,str(parsed.get("format")),FORMAT])
		return {}
	return parsed

# --- Asking ----------------------------------------------------------------------

func has_isle(isle: String) -> bool:
	return isles.has(isle)

func has_region(region: String) -> bool:
	return regions.any(func(r: Dictionary) -> bool: return r.id == region)

## The objective `id` ({id, isle, region, slug, type, name, row}), {} if none.
func objective(id: String) -> Dictionary:
	return objectives.get(id,{})

## The ids of isle `isle`'s objectives, in order (of `type` only if given).
func isle_objectives(isle: String, type := "") -> Array[String]:
	var out: Array[String] = []
	if not isles.has(isle): return out
	for id: String in isles[isle].objectives:
		if type.is_empty() or objectives[id].type == type: out.append(id)
	return out

## The ids of every objective in region `region`, isle by isle.
func region_objectives(region: String, type := "") -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in regions:
		if r.id != region: continue
		for isle: String in r.isles: out.append_array(isle_objectives(isle,type))
	return out

## The card row `row` ({id, icon, label}), {} if none.
func row_spec(row: String) -> Dictionary:
	for r: Dictionary in rows:
		if r.id == row: return r
	return {}
