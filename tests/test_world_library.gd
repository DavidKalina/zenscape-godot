extends SceneTree
## The world library: index, names, copies, deletes, seeds and played-at wording.
const Library = preload("res://scripts/world_library.gd")
var failures := 0

func _initialize() -> void:
	var root := "user://test-world-library-%d" % Time.get_ticks_usec()
	var library := Library.new(root)
	check(library.worlds().is_empty(), "A new library has no worlds")
	var first := library.create("","canyon","basalt-heron-2081",1000.0)
	check(first.name == "Red canyon", "A blank name takes the land's name")
	var second := library.create("  Fern bank ","plain","",2000.0)
	check(second.name == "Fern bank", "Names are trimmed")
	check(library.worlds()[0].id == second.id, "Most recently played comes first")
	library.touch(first.id,3000.0)
	check(library.worlds()[0].id == first.id, "Touching a world brings it to the front")
	check(not library.rename(first.id,"   ") and library.find(first.id).name == "Red canyon", "A blank rename keeps the old name")
	check(library.rename(first.id,"Ochre bluffs") and library.find(first.id).name == "Ochre bluffs", "Rename changes the name")
	FileAccess.open(library.save_path(first.id),FileAccess.WRITE).store_string("{\"saved\":true}")
	var copy := library.duplicate_world(first.id,"",4000.0)
	check(copy.name == "Ochre bluffs (copy)" and copy.id != first.id, "Duplicate names the copy")
	check(FileAccess.get_file_as_string(library.save_path(copy.id)) == "{\"saved\":true}", "Duplicate copies the save")
	check(library.duplicate_world(first.id,"Fork",4100.0).name == "Fork", "Save a copy can name the copy")
	var reread := Library.new(root)
	check(reread.worlds().size() == 4 and reread.find(first.id).name == "Ochre bluffs", "The index survives a reload")
	check(reread.delete(copy.id) and not FileAccess.file_exists(reread.save_path(copy.id)), "Delete removes the world and its save")
	check(Library.new(root).worlds().size() == 3, "Delete is kept")
	# Adopting the old single-place save happens once.
	var legacy := root.path_join("legacy.json")
	FileAccess.open(legacy,FileAccess.WRITE).store_string("{}")
	check(not library.adopt(legacy,"Your world",500.0).is_empty(), "An older save is adopted")
	check(library.adopt(legacy,"Your world",500.0).is_empty(), "It is adopted only once")
	# Seeds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rolled := Library.roll_seed(rng)
	check(RegEx.create_from_string("^[a-z]+-[a-z]+-\\d{4}$").search(rolled) != null, "A rolled seed reads word-word-NNNN: "+rolled)
	check(Library.seed_value(rolled) == Library.seed_value(" "+rolled.to_upper()+" "), "The same seed grows the same land")
	check(Library.seed_value("basalt-heron-2081") != Library.seed_value("basalt-heron-2082"), "Different seeds differ")
	check(Library.seed_value("42") == 42 and Library.seed_value("anything") >= 0, "Seed values are non-negative")
	# Played-at wording, around a fixed local noon.
	var bias: int = Time.get_time_zone_from_system().get("bias",0)*60
	var noon := float(Time.get_unix_time_from_datetime_dict({"year":2026,"month":10,"day":1,"hour":12,"minute":0,"second":0})-bias)
	check(Library.relative_time(noon-120.0,noon) == "Played 2 minutes ago", "Minutes ago today")
	check(Library.relative_time(noon-10.0,noon) == "Played just now", "Just now")
	check(Library.relative_time(noon-86400.0+8*3600.0,noon) == "Yesterday evening", "Yesterday evening")
	check(Library.relative_time(noon-2*86400.0,noon) == "Tuesday", "A weekday within the week: "+Library.relative_time(noon-2*86400.0,noon))
	check(Library.relative_time(noon-19*86400.0,noon) == "12 September", "A date this year")
	check(Library.relative_time(noon-400*86400.0,noon) == "August 2025", "Month and year for older worlds: "+Library.relative_time(noon-400*86400.0,noon))
	for world: Dictionary in library.worlds(): library.delete(world.id)
	DirAccess.remove_absolute(legacy)
	DirAccess.remove_absolute(root.path_join("index.json"))
	DirAccess.remove_absolute(root)
	print("World library: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
