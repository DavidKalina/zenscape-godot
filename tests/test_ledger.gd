extends SceneTree
## The ledger (scripts/ledger/ledger.gd, ledger_registry.gd, data/ledger/;
## docs/design/ledger/round1.md), headless: the registry reads clean, region
## "ruins" holds the aqueduct isle and the eight motif isles with every
## on-foot token their code lays, each id "<isle>/<slug>"; what's done
## saves and loads back (a fresh ledger reading the same file, as the next
## run would); an isle's card counts from it; a token taken stays taken
## when its isle is set up again (not laid, counted as found, the readout
## climbing from there); the region's count, all and by type; and the
## autoload outlives a scene change. Across runs too: it starts itself
## headless three times with --ledger=<file> (marking a token, reading it
## back, and with --fresh-ledger starting clean). The autoload of a script
## run keeps to memory, so the player's save is never read or written here;
## this test's files go to user://ledger_test_<pid>*.json and are removed.
##   godot --headless --path . --script tests/test_ledger.gd
const LedgerScript = preload("res://scripts/ledger/ledger.gd")
const Registry = preload("res://scripts/ledger/ledger_registry.gd")
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const MotifIsle = preload("res://scripts/kit_isle/motif_isle.gd")
const BrokenRing = preload("res://scripts/kit_isle/motif_broken_ring.gd")
const BellSpires = preload("res://scripts/kit_isle/motif_bell_spires.gd")
## The tokens laid only with the isle's geometry to hand (the trilithon, the
## belfry, the colonnade's wedged drums), beside those `spots_for(null)` lays.
const NEEDS_ISLE := ["aqueduct_isle/trilithon","bell_spires/belfry_head","colonnade_spine/cleft"]
var failures := 0
var _files: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _file(tag: String) -> String:
	var path := "user://ledger_test_%d_%s.json" % [OS.get_process_id(),tag]
	_files.append(path)
	return path

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("ledger test timed out"); quit(2))
	var book: Node = root.get_node_or_null("GameState")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ledger-child="):
			quit(_child(book,arg.trim_prefix("--ledger-child=")))
			return
	check(book != null and book.get_script() == LedgerScript and LedgerScript.shared() == book,"The ledger is the GameState autoload, and what shared() answers")
	check(book != null and str(book.path).is_empty(),"A script run's ledger keeps to memory (path '%s')" % (book.path if book != null else "?"))
	_registry()
	_round_trip()
	_cards(book)
	_tokens(book)
	_region(book)
	await _survives(book)
	_runs()
	# The readout's blip and flourish ring out before the end.
	await create_timer(1.5).timeout
	for path in _files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path+".tmp"): DirAccess.remove_absolute(path+".tmp")
	print("PASS: ledger" if failures == 0 else "FAIL: ledger (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The registry: clean, ruins' nine isles, ids, every laid token listed.
func _registry() -> void:
	var registry: RefCounted = Registry.make()
	check(registry.errors.is_empty(),"The registry reads without errors %s" % [registry.errors])
	check(registry.has_region("ruins"),"Region 'ruins' is listed")
	var want: Array = ["aqueduct_isle"]
	for place: Array in MotifSky.places(): want.append(place[0])
	var listed: Array = registry.regions[0].isles if not registry.regions.is_empty() else []
	var same := listed.size() == want.size() and want.all(func(i: String) -> bool: return listed.has(i))
	check(same,"Ruins holds the aqueduct isle and the eight motif isles: %s" % [listed])
	var ids: Array[String] = registry.region_objectives("ruins")
	var shaped := ids.all(func(id: String) -> bool:
		var o: Dictionary = registry.objective(id)
		return id == "%s/%s" % [o.isle,o.slug] and o.type == "token" and o.row == "glyphs" and not str(o.name).is_empty())
	check(ids.size() == 57 and shaped,"57 token objectives, each '<isle>/<slug>' with a name and the Glyphs row (%d)" % ids.size())
	# Every token the isles' code lays is listed (those that can be laid
	# without the isle's geometry, and the three that need it).
	var laid: Array[String] = []
	var sources := {"aqueduct_isle":"res://studies/aqueduct_isle_tokens.gd","bell_spires":"res://studies/bell_spires_isle_tokens.gd"}
	for isle: String in sources:
		var tokens: Node3D = load(sources[isle]).new()
		for t: Dictionary in tokens.spots_for(null): laid.append(Registry.objective_id(isle,t.name))
		tokens.free()
	for isle: String in ["broken_ring","cloister_tarn","drowned_nave","colonnade_spine","hollow_keel","stair_clouds","sundered_gorge"]:
		var life: Node3D = load("res://studies/%s_isle_life.gd" % isle).new()
		var tokens: Node3D = life.make_tokens()
		for t: Dictionary in tokens.spots_for(null): laid.append(Registry.objective_id(isle,t.name))
		tokens.free()
		life.free()
	laid.append_array(NEEDS_ISLE)
	var unlisted := laid.filter(func(id: String) -> bool: return registry.objective(id).is_empty())
	var unlaid := ids.filter(func(id: String) -> bool: return not laid.has(id))
	check(unlisted.is_empty() and unlaid.is_empty(),"The registry and the isles' tokens agree, %d laid (unlisted %s, never laid %s)" % [laid.size(),unlisted,unlaid])
	# Ids don't hang on where anything stands: the data has no positions.
	var raw := FileAccess.get_file_as_string("res://data/ledger/ruins.json")
	check(not raw.contains("\"at\"") and not raw.contains("Vector3"),"The region's data holds no positions")
	# A bad file is caught, not half read.
	var bad: RefCounted = Registry.new()
	bad.read("res://data/ledger/missing.json")
	check(not bad.errors.is_empty() and bad.objectives.is_empty(),"A missing index is an error, nothing listed")

## Done, saved, read back by a fresh ledger; an id the data doesn't list is
## kept; reset forgets.
func _round_trip() -> void:
	var path := _file("trip")
	var a: Node = LedgerScript.new()
	a.path = path
	check(a.mark_done("aqueduct_isle/slot"),"Marking a token done answers true")
	check(not a.mark_done("aqueduct_isle/slot"),"Marking it again answers false")
	a.mark_done("hollow_keel/vault")
	a.mark_done("old_isle/renamed")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var objectives: Dictionary = parsed.get("objectives",{}) if parsed is Dictionary else {}
	check(parsed is Dictionary and int(parsed.format) == 1 and objectives.has("aqueduct_isle/slot") and bool(objectives["aqueduct_isle/slot"].done),
		"The file is {format 1, objectives: {id: {done, at}}}")
	check(not FileAccess.file_exists(path+".tmp"),"No half-written file is left beside it")
	var b: Node = LedgerScript.new()
	b.path = path
	b.load_saved()
	check(b.is_done("aqueduct_isle/slot") and b.is_done("hollow_keel/vault") and not b.is_done("aqueduct_isle/span"),"A fresh ledger reads back what was done")
	check(b.is_done("old_isle/renamed") and b.region_progress("ruins").done == 2,"An id the data doesn't list is kept, not counted")
	var memory: Node = LedgerScript.new()
	memory.path = ""
	memory.mark_done("aqueduct_isle/slot")
	check(memory.is_done("aqueduct_isle/slot"),"Memory only: done, nothing written")
	b.reset()
	var c: Node = LedgerScript.new()
	c.path = path
	c.load_saved()
	check(c.records.is_empty(),"Reset forgets, saved")
	var junk := _file("junk")
	var f := FileAccess.open(junk,FileAccess.WRITE)
	f.store_string("not json {")
	f.close()
	var d: Node = LedgerScript.new()
	d.path = junk
	d.load_saved()
	check(d.records.is_empty(),"A broken file reads as nothing done")
	for n: Node in [a,b,c,d,memory]: n.free()

## The cards: rows from the registry, counts from what's done; the motifs'
## and the aqueduct isle's own `isle_card` through the autoload.
func _cards(book: Node) -> void:
	book.reset()
	var card: Dictionary = book.card("bell_spires",{"name":"X","epithet":"Y"})
	check(card.name == "X" and card.epithet == "Y" and card.finds == [["rune","Runes",0,7]],"Bell spires' card: one Glyphs row, 0 of 7 %s" % [card.finds])
	book.mark_done("bell_spires/chimney")
	book.mark_done("bell_spires/turret")
	var motif: RefCounted = BellSpires.new()
	var live: Dictionary = motif.isle_card()
	check(live.finds == [["rune","Runes",2,7]] and live.name == "Spires of the Silent Bell","The motif's own card reads the ledger: 2 of 7 %s" % [live.finds])
	check(book.card("nowhere",{"name":"Z"}).finds == [],"An isle the ledger doesn't list has no rows")
	var counts := {}
	for isle: String in book.registry.isles: counts[isle] = book.card(isle,{}).finds[0][3]
	check(counts == {"aqueduct_isle":7,"bell_spires":7,"cloister_tarn":7,"sundered_gorge":7,"colonnade_spine":6,"broken_ring":6,"drowned_nave":5,"stair_clouds":6,"hollow_keel":6},"Every isle's card counts its own tokens %s" % [counts])
	var stand_in := Node3D.new()
	stand_in.set_script(load("res://studies/aqueduct_isle.gd"))
	check(LedgerScript.isle_id_of(stand_in) == "aqueduct_isle","The aqueduct isle's id is 'aqueduct_isle'")
	book.mark_done("aqueduct_isle/span")
	check(stand_in.isle_card().finds == [["rune","Runes",1,7]],"The aqueduct isle's card reads the ledger: %s" % [stand_in.isle_card().finds])
	stand_in.free()
	book.reset()

## A token taken stays taken: the broken ring's tokens set up, one taken,
## then set up again (as the next run, or Back to the title) from a ledger
## that read the file back.
func _tokens(book: Node) -> void:
	var path := _file("tokens")
	book.path = path
	book.reset()
	var isle: Node3D = MotifIsle.new()
	isle.motif = BrokenRing.new()
	root.add_child(isle)
	check(LedgerScript.isle_id_of(isle) == "broken_ring","A placed motif isle's id is its motif's")
	var life: Node3D = load("res://studies/broken_ring_isle_life.gd").new()
	var first: Node3D = life.make_tokens()
	isle.add_child(first)
	first.setup(isle)
	check(first.tokens.size() == 6 and first.left() == 6 and first.find_child("Token_turret",true,false) != null,"Six tokens laid on a clean ledger")
	first.take("turret")
	check(book.is_done("broken_ring/turret"),"Taking one marks 'broken_ring/turret' done")
	first.queue_free()
	# The next run: what's on disk read back.
	book.load_saved()
	check(book.is_done("broken_ring/turret"),"It was saved")
	var again: Node3D = life.make_tokens()
	isle.add_child(again)
	again.setup(isle)
	check(again.tokens.size() == 6 and again.taken.size() == 1 and again.taken[0] == "turret" and again.left() == 5,"Set up again: still six tokens, 'turret' already taken, five left")
	check(again.find_child("Token_turret",true,false) == null and again.find_child("Token_summit",true,false) != null,"The taken one isn't laid; the others are")
	again.take("summit")
	check(int(again.hud._got) == 2 and int(again.hud._of) == 6,"The readout counts the earlier one: 2 of 6 (%s of %s)" % [again.hud._got,again.hud._of])
	again.take("turret")
	check(book.region_progress("ruins").done == 2,"Taking a taken one again does nothing")
	check(isle.isle_card().finds == [["rune","Runes",2,6]],"The isle's card shows it: %s" % [isle.isle_card().finds])
	life.free()
	isle.queue_free()
	book.reset()

## The region's count, all and by type.
func _region(book: Node) -> void:
	book.reset()
	var none: Dictionary = book.region_progress("ruins")
	check(none.done == 0 and none.total == 57 and none.types == {"token":{"done":0,"total":57}},"Ruins: 0 of 57, tokens 0 of 57 %s" % [none])
	for id in ["aqueduct_isle/slot","bell_spires/drift","hollow_keel/vault"]: book.mark_done(id)
	var some: Dictionary = book.region_progress("ruins")
	check(some.done == 3 and some.types.token.done == 3,"Ruins: 3 done, 3 tokens %s" % [some])
	check(book.isle_progress("hollow_keel") == {"done":1,"total":6,"types":{"token":{"done":1,"total":6}}},"Hollow keel: 1 of 6")
	check(book.region_progress("elsewhere").total == 0,"An unknown region counts nothing")

## The autoload outlives a scene change.
func _survives(book: Node) -> void:
	book.mark_done("drowned_nave/spill")
	var scene := PackedScene.new()
	var top := Node.new()
	scene.pack(top)
	top.free()
	change_scene_to_packed(scene)
	await process_frame
	await process_frame
	var after: Node = root.get_node_or_null("GameState")
	check(after == book and after.is_done("drowned_nave/spill"),"The ledger and what's done outlive a scene change")
	book.reset()
	book.path = ""

## Across runs: this test started again headless, on a file of its own.
func _runs() -> void:
	var path := _file("runs")
	var flag := "--ledger="+path
	check(_spawn(["--ledger-child=mark",flag]) == 0,"A run with --ledger marks 'stair_clouds/gate' done in its file")
	check(FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains("stair_clouds/gate"),"The file holds it")
	check(_spawn(["--ledger-child=read",flag]) == 0,"The next run reads it back done")
	check(_spawn(["--ledger-child=fresh",flag,"--fresh-ledger"]) == 0,"A run with --fresh-ledger starts with nothing done")

func _spawn(args: Array) -> int:
	var command := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_ledger.gd","--"])
	command.append_array(PackedStringArray(args))
	var output := []
	var code := OS.execute(OS.get_executable_path(),command,output,true)
	if code != 0: print("  child %s: %d\n%s" % [args,code,"".join(output)])
	return code

## A child run's part: 0 if it went as it should.
func _child(book: Node, part: String) -> int:
	if book == null or not str(book.path).begins_with("user://ledger_test_"): return 4
	match part:
		"mark": return 0 if book.mark_done("stair_clouds/gate") else 5
		"read": return 0 if book.is_done("stair_clouds/gate") and book.region_progress("ruins").done == 1 else 6
		"fresh": return 0 if book.records.is_empty() else 7
	return 8
