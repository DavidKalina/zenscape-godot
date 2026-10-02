extends RefCounted
## The player's worlds (docs/design/worlds): each world is one regrowth save
## (scripts/cozy_regrowth.gd `save_places`) in its own file, plus a capture
## for its tile and backdrop. The index keeps names, lands, seeds and when
## each was last played. There are no slots and no Save button: worlds are
## opened, created, renamed, duplicated and deleted, and they keep themselves.

const LANDS := [
	{"id":"plain","name":"Quiet plain","description":"Flat and green. Raise every hill yourself."},
	{"id":"canyon","name":"Red canyon","description":"Banded stone and slow cactus."},
	{"id":"isle","name":"Misty isle","description":"Low cloud and soft grey water."},
	{"id":"hollow","name":"Moss hollow","description":"Deep shade and damp ground."},
]
const SEED_WORDS_A := ["basalt","cedar","ember","fern","flint","heather","juniper","lichen","marl","moss","ochre","pumice","quartz","rowan","sage","shale","slate","sorrel","tamarack","willow"]
const SEED_WORDS_B := ["heron","wren","otter","finch","hare","lark","marten","newt","owl","plover","quail","robin","stoat","teal","vole","crane","kestrel","linnet","pika","swift"]
const MONTHS := ["January","February","March","April","May","June","July","August","September","October","November","December"]
const WEEKDAYS := ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]

var root: String
var _index: Array = []

func _init(root_path := "user://cozy-worlds/worlds") -> void:
	root = root_path
	DirAccess.make_dir_recursive_absolute(root)
	_read_index()

## Every world, most recently played first. Copies: edit through the methods.
func worlds() -> Array:
	var sorted := _index.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.last_played_at) > float(b.last_played_at))
	return sorted

func find(id: String) -> Dictionary:
	for world: Dictionary in _index:
		if world.id == id: return world.duplicate()
	return {}

## The regrowth save for a world (the scene's `places_path`).
func save_path(id: String) -> String:
	return root.path_join(id+".json")

func thumbnail_path(id: String) -> String:
	return root.path_join(id+".png")

## A new, empty world entry. The save itself is written when the world is
## first formed and kept. A blank name takes the land's name.
func create(world_name: String, land: String, seed_text: String, now := -1.0) -> Dictionary:
	var world := {"id":_new_id(),"name":_name_or(world_name,land_name(land)),"land":land,"seed":seed_text,
		"last_played_at":_now(now)}
	_index.append(world)
	_write_index()
	return world.duplicate()

## A blank name is ignored and the old name stays. False when nothing changed.
func rename(id: String, world_name: String) -> bool:
	var trimmed := world_name.strip_edges()
	for world: Dictionary in _index:
		if world.id == id and not trimmed.is_empty() and trimmed != world.name:
			world.name = trimmed
			return _write_index()
	return false

## "{name} (copy)", or the given name, with its save and capture copied,
## played "just now". Empty when the source is missing.
func duplicate_world(id: String, copy_name := "", now := -1.0) -> Dictionary:
	var source := find(id)
	if source.is_empty(): return {}
	var copy := source.duplicate()
	copy.id = _new_id()
	copy.name = _name_or(copy_name,str(source.name)+" (copy)")
	copy.last_played_at = _now(now)
	for pair: Array in [[save_path(id),save_path(copy.id)],[thumbnail_path(id),thumbnail_path(copy.id)]]:
		if FileAccess.file_exists(pair[0]) and DirAccess.copy_absolute(pair[0],pair[1]) != OK: return {}
	_index.append(copy)
	_write_index()
	return copy.duplicate()

func delete(id: String) -> bool:
	for i in _index.size():
		if _index[i].id == id:
			_index.remove_at(i)
			for path: String in [save_path(id),thumbnail_path(id)]:
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
			return _write_index()
	return false

func touch(id: String, now := -1.0) -> void:
	for world: Dictionary in _index:
		if world.id == id:
			world.last_played_at = _now(now)
			_write_index()
			return

## Brings an older single-place save (user://cozy-worlds/places.json) into the
## library once, as a world of its own. The old file is left where it is.
func adopt(path: String, world_name: String, now := -1.0) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	for world: Dictionary in _index:
		if world.get("adopted_from","") == path: return {}
	var world := create(world_name,"plain","",now if now >= 0.0 else FileAccess.get_modified_time(path))
	if DirAccess.copy_absolute(path,save_path(world.id)) != OK:
		delete(world.id)
		return {}
	for entry: Dictionary in _index:
		if entry.id == world.id: entry.adopted_from = path
	_write_index()
	return find(world.id)

static func land_name(land: String) -> String:
	for entry: Dictionary in LANDS:
		if entry.id == land: return entry.name
	return LANDS[0].name

## A seed reads "word-word-NNNN" (basalt-heron-2081).
static func roll_seed(rng: RandomNumberGenerator) -> String:
	return "%s-%s-%04d" % [SEED_WORDS_A[rng.randi_range(0,SEED_WORDS_A.size()-1)],SEED_WORDS_B[rng.randi_range(0,SEED_WORDS_B.size()-1)],rng.randi_range(0,9999)]

## The same seed text always grows the same land: a stable, non-negative int.
static func seed_value(seed_text: String) -> int:
	var cleaned := seed_text.strip_edges().to_lower()
	if cleaned.is_valid_int(): return absi(int(cleaned))
	var hash_value := 2166136261
	for byte: int in cleaned.to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * 16777619) & 0x7fffffff
	return hash_value

## "Played 2 minutes ago", "Yesterday evening", "Tuesday", "12 September",
## "March 2024". Times are unix seconds, read in local time.
static func relative_time(played_at: float, now: float) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias",0)*60
	var then := Time.get_datetime_dict_from_unix_time(int(played_at)+bias)
	var today := Time.get_datetime_dict_from_unix_time(int(now)+bias)
	var day_then := int((played_at+bias)/86400.0)
	var day_now := int((now+bias)/86400.0)
	var days := day_now-day_then
	if days <= 0:
		var minutes := int(maxf(now-played_at,0.0)/60.0)
		if minutes < 1: return "Played just now"
		if minutes < 60: return "Played %d minute%s ago" % [minutes,"" if minutes == 1 else "s"]
		var hours := int(minutes/60.0)
		return "Played %d hour%s ago" % [hours,"" if hours == 1 else "s"]
	if days == 1:
		var hour := int(then.hour)
		return "Yesterday " + ("morning" if hour < 12 else "afternoon" if hour < 17 else "evening" if hour < 22 else "night")
	if days < 7: return WEEKDAYS[int(then.weekday)]
	if int(then.year) == int(today.year): return "%d %s" % [int(then.day),MONTHS[int(then.month)-1]]
	return "%s %d" % [MONTHS[int(then.month)-1],int(then.year)]

func _name_or(world_name: String, fallback: String) -> String:
	var trimmed := world_name.strip_edges()
	return fallback if trimmed.is_empty() else trimmed

func _now(now: float) -> float:
	return now if now >= 0.0 else Time.get_unix_time_from_system()

func _new_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var id := "w%d-%04x" % [int(Time.get_unix_time_from_system()),rng.randi_range(0,0xffff)]
	while not find(id).is_empty(): id = "w%d-%04x" % [int(Time.get_unix_time_from_system()),rng.randi_range(0,0xffff)]
	return id

func _index_path() -> String:
	return root.path_join("index.json")

func _read_index() -> void:
	_index = []
	if not FileAccess.file_exists(_index_path()): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index_path()))
	if not parsed is Dictionary or not parsed.get("worlds") is Array: return
	for world: Variant in parsed.worlds:
		if world is Dictionary and world.get("id") is String and world.get("name") is String:
			world.last_played_at = float(world.get("last_played_at",0.0))
			world.land = str(world.get("land","plain"))
			world.seed = str(world.get("seed",""))
			_index.append(world)

func _write_index() -> bool:
	var temporary := _index_path()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version":1,"worlds":_index},"\t"))
	file.close()
	return DirAccess.rename_absolute(temporary,_index_path()) == OK
