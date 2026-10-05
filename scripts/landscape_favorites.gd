extends RefCounted
## A local library of complete discoveries. Metadata stays small so browsing
## never loads every garden's mesh state. All disk content is plain validated JSON.
const ROOT := "user://landscape-favorites"
const MAX_BYTES := 24*1024*1024
var directory := ROOT

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var folder := DirAccess.open(directory)
	if folder == null: return result
	for id in folder.get_directories():
		if not _id_valid(id): continue
		var meta: Variant = _read(directory.path_join(id).path_join("info.json"),4096)
		if not meta is Dictionary or not meta.get("title") is String: continue
		if meta.title.length()>80 or not meta.get("family") is String: continue
		result.append({"id":id,"title":meta.title,"family":meta.family,"biome":str(meta.get("biome","")),"created":str(meta.get("created",""))})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id>b.id)
	return result

func save(scene: Node3D,title: String,preview: Image = null) -> String:
	if scene._chunk_editor.forming: return ""
	title = title.strip_edges().left(80)
	if title.is_empty(): return ""
	var id := "%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	var staging := directory.path_join(".pending-"+id)
	var final_path := directory.path_join(id)
	if DirAccess.make_dir_recursive_absolute(staging)!=OK: return ""
	var data: NativeTerrainData = scene._chunk_editor.data
	var document := {"version":1,"terrain":data.to_document(),"scene":NativeGardenStore.capture(scene)}
	var meta := {"title":title,"family":data._recipe_settings.get("family","custom"),"biome":data._recipe_settings.get("biome",""),"created":Time.get_datetime_string_from_system()}
	if not _write(staging.path_join("scene.json"),document) or not _write(staging.path_join("info.json"),meta): return ""
	if preview != null and not preview.is_empty():
		var thumbnail := preview.duplicate() as Image
		thumbnail.resize(480,320,Image.INTERPOLATE_LANCZOS)
		if thumbnail.save_png(staging.path_join("preview.png"))!=OK: return ""
	if DirAccess.rename_absolute(staging,final_path)!=OK: return ""
	return id

func prepare(scene: Node3D,id: String) -> Dictionary:
	if not _id_valid(id): return {}
	var document: Variant = _read(directory.path_join(id).path_join("scene.json"),MAX_BYTES)
	if not document is Dictionary or document.get("version")!=1: return {}
	if not NativeGardenStore.valid(scene,document.get("scene")): return {}
	# Validate in isolation. NativeTerrainData.load_document intentionally clears
	# history, so the active garden must never be the validation target.
	var candidate := NativeTerrainData.new()
	candidate.setup(scene._chunk_editor.data.source_mesh)
	var scene_state: Dictionary = document.scene
	# A favourite kept on the 28 m plate: its scene's cells come over with it.
	if preload("res://scripts/plate_migration.gd").needs(document.get("terrain")): scene_state = preload("res://scripts/plate_migration.gd").migrate_state(scene_state)
	if not candidate.load_document(document.get("terrain",{})): return {}
	return {"terrain":candidate._snapshot(),"scene":scene_state}

func preview(id: String) -> Texture2D:
	if not _id_valid(id): return null
	var path := directory.path_join(id).path_join("preview.png")
	if not FileAccess.file_exists(path): return null
	var picture := Image.load_from_file(path)
	return null if picture == null or picture.is_empty() else ImageTexture.create_from_image(picture)

func remove(id: String) -> bool:
	if not _id_valid(id): return false
	# Keep removed discoveries on disk, outside the visible library.
	var removed := directory.path_join(".removed")
	if DirAccess.make_dir_recursive_absolute(removed)!=OK: return false
	return DirAccess.rename_absolute(directory.path_join(id),removed.path_join(id))==OK

static func _id_valid(id: String) -> bool:
	if id.is_empty() or id.length()>64: return false
	for c in id:
		if c not in "0123456789-": return false
	return true

static func _read(path: String,limit: int) -> Variant:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>limit: return null
	return JSON.parse_string(file.get_as_text())

static func _write(path: String,value: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value,"",true,true))
	file.flush()
	return file.get_error()==OK
