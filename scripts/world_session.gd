extends Node
## The worlds the cozy scene plays (docs/design/worlds): which library world
## (scripts/world_library.gd) is open, switching, forming new ones, copies,
## and keeping them. Worlds keep themselves: a few seconds after the last
## meaningful edit, on pause, on the way back to the title and on quit, never
## mid-stroke or while regrowth is busy or holding. The scene's `places_path`
## always points at the open world's save, which scripts/cozy_regrowth.gd
## reads and writes.
##
## The session manages worlds when the game opens on the title (or with
## --resume); other launch flags, probes and tests that build the scene keep
## the single legacy save and nothing autosaves.
##
## The title's front page (studies/cozy_worlds.gd `open_title`) shows the
## showcase world, kept in a scratch save to come back to (`show_showcase`)
## and kept as a world by Build this world (`keep_showcase`). On its library
## page (`open_library`) the selected world is the live backdrop
## (`show_backdrop`): loaded but not played, so nothing is kept or touched
## until it is entered (`open_world`), and the title is left through the
## scene's `leave_title`.
const Library = preload("res://scripts/world_library.gd")
const Lands = preload("res://scripts/world_lands.gd")
## Seconds after the last edit before the world is kept, and the longest a
## steady stream of edits (a forest still arriving) can hold a keep off.
const AUTOSAVE_DELAY := 4.0
const AUTOSAVE_LONGEST := 30.0
## Seconds before a keep that found the world busy tries again.
const RETRY := 0.5
const THUMBNAIL_WIDTH := 640
## Seconds a title selection or a New world pick settles before its land loads,
## so fast browsing doesn't load every world on the way.
const BACKDROP_DELAY := 0.5
const PREVIEW_DELAY := 0.3
signal keeping_changed(keeping: bool)
## A world is open in the scene and played: kept at least once, and touched.
signal world_opened(id: String)
## The title's selected world (empty: the quiet plain of no worlds) is live
## behind it.
signal backdrop_ready(id: String)
## `return_to_title` kept the world and hands back to the title.
signal title_requested
var scene: Node3D
var library: RefCounted
## The world whose land is in the scene; empty when no library world is open.
var current_id := ""
## True while a write (and its capture) is in progress.
var keeping := false
## When the open world was last kept, unix seconds; 0 before the first keep.
var last_kept_at := 0.0
var autosave_delay := AUTOSAVE_DELAY
var backdrop_delay := BACKDROP_DELAY
var preview_delay := PREVIEW_DELAY
var managing := false
## The seed the next land formed at launch grows from (`begin`).
var launch_seed := -1
## The scene shows a preview land (`preview_land`, or the title's quiet plain
## with no worlds), not the open world.
var previewing := false
## The land and seed the preview shows, once formed.
var previewed: Array = []
## True when the last `create_world` kept the preview as it stood.
var reused_preview := false
## The title's showcase world is in the scene, as formed.
var showing_showcase := false
var _fresh := false
var _preview_serial := 0
var _preview_forming := false
var _backdrop_serial := 0
var _backdrop_loading := false
## Seconds until the debounced keep, and how long edits have gone unkept;
## both negative when nothing waits.
var _due := -1.0
var _unkept := -1.0
var _capturing := false
var _capture_wanted := false
var _listening := false
var _rng := RandomNumberGenerator.new()

## `manage` takes the worlds over: an older single save is adopted the first
## time, and `places_path` points at the most recently played world.
func setup(owner_scene: Node3D, manage: bool) -> void:
	scene = owner_scene
	managing = manage
	_rng.randomize()
	var legacy: String = scene.places_path
	library = Library.new(legacy.get_base_dir().path_join("worlds"))
	if not managing: return
	if library.worlds().is_empty() and FileAccess.file_exists(legacy): library.adopt(legacy,"Your world")
	var worlds: Array = library.worlds()
	if not worlds.is_empty(): _point_at(worlds[0].id)

## The world a launch without the title plays (--resume, probes): the most
## recent, or a new quiet plain. Returns the choice for scripts/cozy_regrowth.gd
## `setup`, with `launch_seed` for a land; `opened` follows it.
func begin(choice: String) -> String:
	if not managing: return choice
	previewing = false
	if current_id.is_empty() or library.find(current_id).is_empty(): _point_at(library.create("","plain",roll_seed()).id)
	return _setup_choice(true)

## The title's backdrop at launch: the most recent world, loaded but not
## played, or a quiet plain when there are none.
func begin_title() -> String:
	if not managing: return ""
	if current_id.is_empty() or library.find(current_id).is_empty():
		_backdrop_only()
		launch_seed = Library.seed_value(roll_seed())
		previewed = ["plain",""]
		return "plain"
	return _setup_choice(false)

## The launch title's showcase, formed in the scene before regrowth is set up:
## its setup choice ("keep"), with nowhere to keep it but its scratch save.
func begin_showcase() -> String:
	if not managing: return ""
	_backdrop_only(showcase_path())
	if FileAccess.file_exists(showcase_path()): DirAccess.remove_absolute(showcase_path())
	showing_showcase = true
	previewed = []
	return "keep"

## Once regrowth holds the showcase: its scratch save, to come back to.
func kept_showcase() -> void:
	if showing_showcase: scene.places.save_places()

func showcase_path() -> String:
	return library.root.path_join("showcase.json")

## The showcase back in the scene for the front page, from its scratch save.
func show_showcase() -> void:
	_backdrop_serial += 1
	_preview_serial += 1
	while _backdrop_loading or _preview_forming: await get_tree().process_frame
	if showing_showcase: return
	await _until_idle()
	_backdrop_only(showcase_path())
	if FileAccess.file_exists(showcase_path()): await scene.places.open_place(showcase_path())
	showing_showcase = true

## Build this world: the showcase as it stands becomes a new world, played.
## Empty when the showcase is not in the scene.
func keep_showcase(world_name: String, land: String, seed_text: String) -> Dictionary:
	if not showing_showcase: return {}
	_backdrop_serial += 1
	_preview_serial += 1
	var world: Dictionary = library.create(world_name,land if land in Lands.IDS else "plain",seed_text)
	showing_showcase = false
	previewing = false
	previewed = []
	_point_at(world.id)
	_due = -1.0
	_unkept = -1.0
	_listen()
	library.touch(world.id)
	world_opened.emit(world.id)
	_entered()
	return library.find(world.id)

func _setup_choice(entering: bool) -> String:
	_fresh = false
	if FileAccess.file_exists(library.save_path(current_id)): return "resume"
	var world: Dictionary = library.find(current_id)
	launch_seed = Library.seed_value(world.seed)
	_fresh = entering
	return world.land

## The launch's world is in the scene and played: a new one is kept at once,
## and edits start keeping it.
func opened() -> void:
	if not managing or current_id.is_empty(): return
	_listen()
	if _fresh or not FileAccess.file_exists(library.save_path(current_id)): keep_now()
	_fresh = false
	library.touch(current_id)
	world_opened.emit(current_id)

## Shows the title's selected world live behind it, `backdrop_delay` after
## the last selection; `id` empty shows the quiet plain of no worlds.
## `backdrop_ready` follows unless a later selection took over.
func show_backdrop(id: String) -> void:
	_backdrop_serial += 1
	var serial := _backdrop_serial
	if backdrop_delay > 0.0: await get_tree().create_timer(backdrop_delay).timeout
	while _backdrop_loading and serial == _backdrop_serial: await get_tree().process_frame
	if serial != _backdrop_serial: return
	_backdrop_loading = true
	if id.is_empty() or library.find(id).is_empty():
		if showing_showcase or not (previewing and current_id.is_empty() and previewed.size() == 2 and previewed[0] == "plain"):
			await _until_idle()
			_backdrop_only()
			showing_showcase = false
			await scene.places.open_land("plain",Library.seed_value(roll_seed()))
			previewed = ["plain",""]
		id = ""
	else: await _switch(id,false)
	_backdrop_loading = false
	if serial != _backdrop_serial: return
	backdrop_ready.emit(id)
	# A world first seen here (an adopted older save) gets its capture now.
	if not id.is_empty() and not FileAccess.file_exists(library.thumbnail_path(id)):
		for i in 3: await get_tree().process_frame
		if serial == _backdrop_serial and current_id == id and not previewing: await capture_thumbnail()

## Saves the open world, then opens and plays `id`: its save, or its land and
## seed when it has none yet. From the title, the world behind it is entered
## as it stands, and the title is left.
func open_world(id: String) -> void:
	if library.find(id).is_empty(): return
	_backdrop_serial += 1
	while _backdrop_loading: await get_tree().process_frame
	await _switch(id,true)
	_entered()

## A new world in the library, formed from its land and seed and opened. A
## preview of the same land and seed is kept as it stands. Returns its entry
## once it is open (await it).
func create_world(world_name: String, land: String, seed_text: String) -> Dictionary:
	land = land if land in Lands.IDS else "plain"
	_preview_serial += 1
	while _preview_forming: await get_tree().process_frame
	var world: Dictionary = library.create(world_name,land,seed_text)
	var places: Node = scene.get("places")
	reused_preview = previewing and previewed == [land,seed_text] and places != null and places.initialized
	if reused_preview:
		previewing = false
		previewed = []
		_point_at(world.id)
		_due = -1.0
		_unkept = -1.0
		keep_now()
		library.touch(world.id)
		_listen()
		world_opened.emit(world.id)
		_entered()
	else: await open_world(world.id)
	return library.find(world.id)

## Forms a land in the scene for the New world screen's backdrop without
## creating a world, `preview_delay` after the last pick; only the last of
## quick picks forms. The open world is kept first (not on the title, where
## it is unchanged); `end_preview` (or opening or creating a world) puts a
## world back.
func preview_land(land: String, seed_text: String) -> void:
	_preview_serial += 1
	var serial := _preview_serial
	# A title selection still settling would load over the preview.
	_backdrop_serial += 1
	if preview_delay > 0.0: await get_tree().create_timer(preview_delay).timeout
	while (_preview_forming or _backdrop_loading) and serial == _preview_serial: await get_tree().process_frame
	if serial != _preview_serial: return
	_preview_forming = true
	var places: Node = scene.get("places")
	if places == null or not places.initialized:
		# Before any world is set up: form in the scene directly.
		while scene._chunk_editor.forming: await get_tree().process_frame
		previewing = true
		await Lands.form(scene,land,Library.seed_value(seed_text))
	else:
		await _until_idle()
		if not previewing and not _titled(): keep_now()
		previewing = true
		showing_showcase = false
		await places.open_land(land,Library.seed_value(seed_text))
	previewed = [land,seed_text]
	_preview_forming = false

## Back from the New world screen without a new world: the open world returns
## (on the title, the selected one; with none, the preview stays as the
## title's quiet plain).
func end_preview() -> void:
	_preview_serial += 1
	while _preview_forming: await get_tree().process_frame
	if not previewing: return
	var places: Node = scene.get("places")
	if places == null or not places.initialized:
		previewing = false
		return
	if current_id.is_empty() or library.find(current_id).is_empty():
		_backdrop_only()
		if not (previewed.size() == 2 and previewed[0] == "plain"):
			await _until_idle()
			await places.open_land("plain",Library.seed_value(roll_seed()))
			previewed = ["plain",""]
		return
	await _switch(current_id,not _titled())

## Keeps the open world now, then copies it as `copy_name` ("{name} (copy)"
## when blank). `carry_on` plays on in the copy: the scene already holds its
## land, so only the save it keeps to changes. Returns the copy, or {}.
func save_copy(copy_name: String, carry_on: bool) -> Dictionary:
	if current_id.is_empty() or previewing: return {}
	if not keep_now() and not FileAccess.file_exists(library.save_path(current_id)): return {}
	var copy: Dictionary = library.duplicate_world(current_id,copy_name)
	if copy.is_empty(): return {}
	if carry_on: _point_at(copy.id)
	else: library.touch(current_id)
	return copy

## An immediate keep of the open world, and a fresh capture for its tile.
## False when there is no world open or it is busy; it then tries again soon.
## The capture hides the UI for a frame, so autosaves skip it (`capture`
## false) once the world has one; pause, the title, copies and quit capture.
func keep_now(capture := true) -> bool:
	if not current_id.is_empty() and library.find(current_id).is_empty():
		# Let go of on the title while it was the backdrop.
		current_id = ""
	if current_id.is_empty() or previewing or _titled(): return false
	_capture_wanted = _capture_wanted or capture
	if not _idle():
		_due = RETRY
		return false
	_set_keeping(true)
	if not scene.save_current():
		_set_keeping(false)
		_due = RETRY
		return false
	capture = _capture_wanted
	_capture_wanted = false
	_due = -1.0
	_unkept = -1.0
	last_kept_at = Time.get_unix_time_from_system()
	library.touch(current_id,last_kept_at)
	if capture or not FileAccess.file_exists(library.thumbnail_path(current_id)): _capture_kept()
	else: _set_keeping(false)
	return true

## Keeps the world, then hands back to the title (studies/cozy_worlds.gd
## `open_worlds_title`) with this world selected and live.
func return_to_title() -> void:
	if _titled() or current_id.is_empty(): return
	await _until_idle()
	keep_now()
	while keeping: await get_tree().process_frame
	title_requested.emit()
	if scene.has_method("open_title"): scene.open_title()

## On quit, after the scene's last save: the time it was kept and its capture.
func leaving() -> void:
	if current_id.is_empty() or previewing or _titled(): return
	last_kept_at = Time.get_unix_time_from_system()
	library.touch(current_id,last_kept_at)
	await capture_thumbnail()

## Something worth keeping changed: keep the world `autosave_delay` seconds
## after the last such change.
func edited() -> void:
	if current_id.is_empty() or previewing or _titled(): return
	_due = autosave_delay
	if _unkept < 0.0: _unkept = 0.0

## The debounce clock; `_process` drives it, tests call it directly.
func tick(delta: float) -> void:
	if _due < 0.0: return
	_due -= delta
	if _unkept >= 0.0: _unkept += delta
	if _due > 0.0 and _unkept < AUTOSAVE_LONGEST: return
	keep_now(_capture_wanted)

## A fresh seed for a new world (word-word-NNNN).
func roll_seed() -> String:
	return Library.roll_seed(_rng)

func _process(delta: float) -> void:
	tick(delta)

## Saves the viewport, drawn once without the UI (every CanvasLayer at layer
## 1 or above, as photo mode hides its chrome), scaled to THUMBNAIL_WIDTH, as
## the open world's capture: its tile and the title's backdrop until the
## world itself loads. Skipped headless, where nothing is drawn.
func capture_thumbnail() -> void:
	if current_id.is_empty() or previewing or _capturing or DisplayServer.get_name() == "headless": return
	var path: String = library.thumbnail_path(current_id)
	_capturing = true
	var hidden: Array = []
	for node in get_tree().root.find_children("*","CanvasLayer",true,false):
		var canvas := node as CanvasLayer
		if canvas.layer >= 1 and canvas.visible:
			canvas.visible = false
			hidden.append(canvas)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	for canvas in hidden:
		if is_instance_valid(canvas): canvas.visible = true
	_capturing = false
	if image == null or image.is_empty(): return
	if image.get_width() > THUMBNAIL_WIDTH:
		image.resize(THUMBNAIL_WIDTH,maxi(1,roundi(image.get_height()*float(THUMBNAIL_WIDTH)/image.get_width())),Image.INTERPOLATE_BILINEAR)
	image.save_png(path)

func _capture_kept() -> void:
	await capture_thumbnail()
	_set_keeping(false)

func _set_keeping(value: bool) -> void:
	if keeping == value: return
	keeping = value
	keeping_changed.emit(value)

## Puts `id`'s land in the scene. `entering` plays it: the world left is kept
## first (not from the title), and the opened one is kept if new, touched
## and listened to. Otherwise (the title's backdrop) nothing is written.
func _switch(id: String, entering: bool) -> void:
	var world: Dictionary = library.find(id)
	if world.is_empty(): return
	await _until_idle()
	if entering and not previewing and not _titled() and not current_id.is_empty() and id != current_id:
		# Kept and captured before its land leaves the scene.
		keep_now()
		while keeping: await get_tree().process_frame
	if id != current_id or previewing:
		previewing = false
		previewed = []
		showing_showcase = false
		_due = -1.0
		_unkept = -1.0
		_point_at(id)
		var path: String = library.save_path(id)
		var places: Node = scene.places
		var opened := false
		if FileAccess.file_exists(path): opened = await places.open_place(path)
		if not opened:
			# A save that will not read is set aside rather than written over.
			if FileAccess.file_exists(path): DirAccess.rename_absolute(path,path.get_basename()+"-unreadable.json")
			await places.open_land(world.land,Library.seed_value(world.seed))
	if not entering: return
	_listen()
	if not FileAccess.file_exists(library.save_path(id)): keep_now()
	library.touch(id)
	world_opened.emit(id)

func _entered() -> void:
	if _titled() and scene.has_method("leave_title"): scene.leave_title()
	# Kept now that the title is gone, if it was new.
	if not current_id.is_empty() and not FileAccess.file_exists(library.save_path(current_id)): keep_now()

## No world is played: the scene shows a land with nowhere to keep it.
func _backdrop_only(path := "") -> void:
	current_id = ""
	previewing = true
	scene.places_path = path if not path.is_empty() else library.root.path_join("backdrop.json")

func _point_at(id: String) -> void:
	current_id = id
	scene.places_path = library.save_path(id)

func _titled() -> bool:
	return scene.get("titled") == true

## The world can be written: regrowth idle, no stroke, pour or mood fade under way.
func _idle() -> bool:
	if not scene._places_idle(): return false
	var editor: Node = scene.get("_chunk_editor")
	if editor != null and (editor.get("_painting") or editor.get("water_settling") or editor.get("_ball_holding") or editor.get("_handful_holding") or not editor.data._before.is_empty()): return false
	var mood: Node = scene.get("mood_look")
	return mood == null or not mood.fading()

func _until_idle() -> void:
	while not scene._places_idle(): await get_tree().process_frame

## The changes worth keeping: strokes and every undoable edit, undo and
## redo, settled water, weathering, trees arriving, and moods.
func _listen() -> void:
	if _listening: return
	_listening = true
	var editor: Node = scene.get("_chunk_editor")
	if editor != null:
		var mark := func(_a = null, _b = null, _c = null) -> void: edited()
		editor.stroke_finished.connect(mark)
		editor.water_settled.connect(mark)
		editor.land_weathered.connect(mark)
		editor.data.history_captured.connect(mark)
		editor.data.state_restored.connect(mark)
		if editor.emergence.has_signal("tree_arrived"): editor.emergence.tree_arrived.connect(mark)
	var mood: Node = scene.get("mood_look")
	if mood != null: mood.changed.connect(edited)
