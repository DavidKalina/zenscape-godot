extends Node
## The ledger (docs/design/ledger/round1.md): what the player has done in
## the world, kept across scenes and runs. The game state autoload
## ("GameState" in project.godot), so it outlives Back to the title and
## every scene change; what there is to do is its registry's (scripts/
## ledger/ledger_registry.gd, data/ledger/), what has been done is here,
## saved to its own file (PATH), apart from the settings' cfgs.
##
## Scripts reach it through `shared()` (preload this script as `Ledger`),
## not the autoload's name: a script run (--script) compiles its scripts
## before the autoloads are up, so the name isn't known to them then.
## Before the autoload is up (or with no SceneTree) `shared()` answers a
## stand-in kept in memory.
##
## An isle marks an objective done by its id ("<isle>/<slug>": `mark_done`,
## saved at once) and asks what is done (`is_done`); the isle card's rows
## come from here (`card`), and so does a region's count for the gates to
## come (`region_progress`). Nothing gates on it yet.
##
## Flags: --ledger=<path> keeps the progress in another file (tests, a second
## save); --fresh-ledger starts with nothing done, and the first thing done
## writes over the file. A script run (--script: the tests, the tools) keeps
## its progress in memory only, unless it names a file with --ledger, so a
## test never reads or writes the player's save (user:// is shared by every
## checkout of the project).
const Registry = preload("res://scripts/ledger/ledger_registry.gd")

const PATH := "user://progress.json"
const FORMAT := 1
## The autoload's node, under the root.
const NODE := "GameState"

## One done ({id}), on every objective done (not on a load or a reset).
signal changed(id: String)

var registry: RefCounted
## Where it's kept, "" for memory only.
var path := PATH
## objective id -> {done: true, at: ISO time}. Ids the registry no longer
## lists (a renamed slug) are kept as they were, not counted.
var records := {}

## The stand-in `shared()` answers with no autoload up.
static var _stand_in: Node

## The game's ledger: the autoload, else a stand-in kept in memory.
static func shared() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var node: Node = tree.root.get_node_or_null(NODE) if tree != null and tree.root != null else null
	if node != null: return node
	if _stand_in == null:
		_stand_in = new()
		_stand_in.path = ""
	return _stand_in

func _init() -> void:
	registry = Registry.make()
	for error in registry.errors: push_warning("Ledger: "+error)

func _ready() -> void:
	var args := _args()
	var named := ""
	for arg: String in args:
		if arg.begins_with("--ledger="): named = arg.trim_prefix("--ledger=")
	if not named.is_empty(): path = named
	elif _script_run(): path = ""
	if args.has("--fresh-ledger"): records = {}
	else: load_saved()

static func _args() -> PackedStringArray:
	var out := OS.get_cmdline_user_args()
	out.append_array(OS.get_cmdline_args())
	return out

static func _script_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")

# --- Keeping ----------------------------------------------------------------------

## Reads what's done from `path` (nothing if there's no file, or memory only).
func load_saved() -> void:
	records = {}
	if path.is_empty() or not FileAccess.file_exists(path): return
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not parsed is Dictionary:
		push_warning("Ledger: %s isn't a JSON object; starting with nothing done" % path)
		return
	var saved: Variant = (parsed as Dictionary).get("objectives",{})
	if not saved is Dictionary: return
	for id: Variant in saved:
		var r: Variant = saved[id]
		if r is Dictionary and bool(r.get("done",false)): records[str(id)] = {"done":true,"at":str(r.get("at",""))}

## Writes what's done to `path` (beside it first, then over it, so a crash
## mid-write leaves the last save whole). Nothing for memory only.
func save() -> void:
	if path.is_empty(): return
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir): DirAccess.make_dir_recursive_absolute(dir)
	var temp := path+".tmp"
	var f := FileAccess.open(temp,FileAccess.WRITE)
	if f == null:
		push_warning("Ledger: can't write %s (%s)" % [temp,error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify({"format":FORMAT,"saved":Time.get_datetime_string_from_system(true),"objectives":records},"\t"))
	f.close()
	var err := DirAccess.rename_absolute(temp,path)
	if err != OK: push_warning("Ledger: can't move %s over %s (%s)" % [temp,path,error_string(err)])

## Forgets everything done (and saves that, if kept in a file).
func reset() -> void:
	records = {}
	save()

# --- Doing ------------------------------------------------------------------------

## Whether objective `id` is done.
func is_done(id: String) -> bool:
	return records.has(id)

## Marks objective `id` done and saves; true if it wasn't before. An id the
## registry doesn't list is kept all the same (and warned of): the isle's
## code knows it, the data should.
func mark_done(id: String) -> bool:
	if records.has(id): return false
	if registry.objective(id).is_empty(): push_warning("Ledger: '%s' isn't in data/ledger; kept, not counted" % id)
	records[id] = {"done":true,"at":Time.get_datetime_string_from_system(true)}
	save()
	changed.emit(id)
	return true

# --- Asking -----------------------------------------------------------------------

## An isle's id, as the registry knows it: a placed or standalone motif
## isle's motif's (scripts/kit_isle/kit_motif.gd `id`), else its name in
## snake case (the aqueduct isle's "aqueduct_isle").
static func isle_id_of(isle: Object) -> String:
	if isle == null: return ""
	var motif: Variant = isle.get("motif")
	if motif is Object and (motif as Object).has_method("id"): return str(motif.id())
	if isle.has_method("isle_name"): return str(isle.isle_name()).to_snake_case()
	return ""

## An objective's id: "<isle>/<slug>".
static func objective_id(isle: String, slug: String) -> String:
	return Registry.objective_id(isle,slug)

## Done and total of `ids`, and by type: {done, total, types: {type: {done,
## total}}}.
func count(ids: Array[String]) -> Dictionary:
	var out := {"done":0,"total":0,"types":{}}
	for id in ids:
		var type: String = registry.objective(id).type
		if not out.types.has(type): out.types[type] = {"done":0,"total":0}
		var done := 1 if is_done(id) else 0
		out.done += done
		out.total += 1
		out.types[type].done += done
		out.types[type].total += 1
	return out

## Isle `isle`'s count ({done, total, types}).
func isle_progress(isle: String) -> Dictionary:
	return count(registry.isle_objectives(isle))

## Region `region`'s count ({done, total, types}): what its beat will gate on.
func region_progress(region: String) -> Dictionary:
	return count(registry.region_objectives(region))

## Isle `isle`'s card (scripts/isle_splash.gd) with its finds from the
## ledger: `base` (name, epithet, tag) and a [icon, label, found, of] row
## for each of the registry's rows the isle has objectives under, in the
## registry's order. An isle the registry doesn't list has no rows.
func card(isle: String, base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	var finds: Array = []
	var ids: Array[String] = registry.isle_objectives(isle)
	for row: Dictionary in registry.rows:
		var found := 0
		var of := 0
		for id in ids:
			if registry.objective(id).row != row.id: continue
			of += 1
			if is_done(id): found += 1
		if of > 0: finds.append([row.icon,row.label,found,of])
	out["finds"] = finds
	return out
