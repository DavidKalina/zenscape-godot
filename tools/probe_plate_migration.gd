extends SceneTree
## Reads every saved place under a worlds folder as the game would after the
## plate grew (scripts/plate_migration.gd), without writing anything: per
## slot and per built sky island, whether it loads, its land area and object
## count before and after, and whether it saves and reads back. Pass a COPY
## of a save folder, never the live one:
##   godot --headless --path . --script tools/probe_plate_migration.gd -- /tmp/copy/worlds

const Migration = preload("res://scripts/plate_migration.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else ""
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		print("Pass a copy of a worlds folder after --")
		quit(2)
		return
	var counts := {"slots":0,"islands":0,"loaded":0,"failed":0,"resaved":0}
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with(".json") or name == "index.json": continue
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(name)))
		if not saved is Dictionary or not saved.get("slots") is Array: continue
		var documents: Array = []
		for slot: Variant in saved.slots: documents.append(["slot",slot])
		var sky: Variant = saved.get("islands")
		if sky is Dictionary and sky.get("built") is Array:
			for built: Variant in sky.built: documents.append(["island",{"document":built.get("document",{})}])
		for entry: Array in documents:
			counts.slots += 1 if entry[0] == "slot" else 0
			counts.islands += 1 if entry[0] == "island" else 0
			var slot: Dictionary = entry[1]
			var document: Dictionary = slot.get("document",{})
			var data := NativeTerrainData.new()
			data.setup(preload("res://scripts/plate_mesh.gd").build())
			var began := Time.get_ticks_usec()
			var moved: Variant = Migration.migrate_slot(slot,data)
			var ok: bool = moved != null and data.load_document(moved.document)
			var usec := Time.get_ticks_usec()-began
			if not ok:
				counts.failed += 1
				print("FAIL %s %s v%s: does not load" % [name,entry[0],str(document.get("version"))])
				continue
			counts.loaded += 1
			var before := 784.0
			if document.has("outline"):
				var old := NativeTerrainData.new()
				var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
				old.setup(source.get_node("terrain").mesh,[],false)
				source.free()
				old.set_outline(old._decode_outline(document.outline))
				before = old.land_area()
			var again := NativeTerrainData.new()
			again.setup(preload("res://scripts/plate_mesh.gd").build())
			var reread := again.load_document(JSON.parse_string(JSON.stringify(data.to_document())))
			counts.resaved += 1 if reread else 0
			var sites := 0
			var state: Variant = moved.get("state")
			if state is Dictionary and state.get("land_life") is Dictionary:
				for kind: Variant in state.land_life.get("sites",{}): sites += state.land_life.sites[kind].size()
			print("%s %s %s v%s: area %.1f -> %.1f m², objects %d -> %d, life sites %d, %d ms, saved again %s" % ["OK  " if reread and absf(data.land_area()-before) < before*0.03 and data.objects.size() == document.get("objects",[]).size() else "FAIL",name,entry[0],str(document.get("version")),before,data.land_area(),document.get("objects",[]).size(),data.objects.size(),sites,usec/1000,"yes" if reread else "NO"])
	print("slots %d, sky islands %d: %d loaded, %d failed, %d read back after saving" % [counts.slots,counts.islands,counts.loaded,counts.failed,counts.resaved])
	quit(1 if counts.failed > 0 else 0)
