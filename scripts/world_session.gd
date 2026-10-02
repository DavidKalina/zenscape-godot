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
## The title hands its pick to the session: `open_world`, `create_world` and
## the title menu's own picks (studies/cozy_worlds.gd `title_picked`) leave
## the title through `begin` (first launch) or `enter` (after
## `return_to_title`).
const Library = preload("res://scripts/world_library.gd")
const Lands = preload("res://scripts/world_lands.gd")
## Seconds after the last edit before the world is kept, and the longest a
## steady stream of edits (a forest still arriving) can hold a keep off.
const AUTOSAVE_DELAY := 4.0
const AUTOSAVE_LONGEST := 30.0
## Seconds before a keep that found the world busy tries again.
const RETRY := 0.5
const THUMBNAIL_WIDTH := 640
signal keeping_changed(keeping: bool)
## A world is open in the scene, kept at least once, and touched.
signal world_opened(id: String)
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
var managing := false
## The seed the next land formed at launch grows from (`begin`).
var launch_seed := -1
## The scene shows a preview land (`preview_land`), not the open world.
var previewing := false
var _picked := ""
var _preview_next: Array = []
var _preview_forming := false
var _fresh := false
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

## The title's pick (or a launch flag's) as the world to set up: the choice
## for scripts/cozy_regrowth.gd `setup`, with `launch_seed` for a new land.
## "open" is the world `open_world`/`create_world` picked, "resume" (or none)
## the most recent, "plain" a new quiet plain, "keep" the title's land.
func begin(choice: String) -> String:
	if not managing: return choice
	_fresh = false
	previewing = false
	match choice:
		"open":
			if not library.find(_picked).is_empty(): _point_at(_picked)
		"keep":
			var recipe: Variant = scene.get("title_recipe")
			if not recipe is Dictionary: recipe = {}
			var made: Dictionary = library.create("","canyon" if recipe.get("biome","") == "arid" else "plain",str(recipe.get("terrain_recipe",{}).get("seed","")))
			_point_at(made.id)
			_fresh = true
			return "keep"
		"", "resume":
			pass
		_:
			_point_at(library.create("",choice if choice in Lands.IDS else "plain",roll_seed()).id)
	if current_id.is_empty() or library.find(current_id).is_empty(): _point_at(library.create("","plain",roll_seed()).id)
	_picked = ""
	if FileAccess.file_exists(library.save_path(current_id)): return "resume"
	var world: Dictionary = library.find(current_id)
	launch_seed = Library.seed_value(world.seed)
	_fresh = true
	return world.land

## The launch's world is in the scene: a new one is kept at once, and edits
## start keeping it.
func opened() -> void:
	if not managing or current_id.is_empty(): return
	_listen()
	if _fresh: keep_now()
	_fresh = false
	library.touch(current_id)
	world_opened.emit(current_id)

## A title pick after `return_to_title`, with a world already in the scene.
func enter(choice: String) -> void:
	match choice:
		"open": await _switch(_picked)
		"plain": await _switch(library.create("","plain",roll_seed()).id)
		_:
			if previewing: await _switch(current_id)
			library.touch(current_id)
			world_opened.emit(current_id)
	_picked = ""

## Saves the open world, then opens `id`: its save, or its land and seed when
## it has none yet. On the title, this is the pick that leaves it.
func open_world(id: String) -> void:
	if library.find(id).is_empty(): return
	if _titled():
		_picked = id
		scene.title_picked.emit("open")
		await world_opened
		return
	await _switch(id)

## A new world in the library, formed from its land and seed and opened.
## Returns its entry once it is open (await it).
func create_world(world_name: String, land: String, seed_text: String) -> Dictionary:
	var world: Dictionary = library.create(world_name,land if land in Lands.IDS else "plain",seed_text)
	await open_world(world.id)
	return library.find(world.id)

## Forms a land in the scene for the New world screen's backdrop without
## creating a world. The open world is kept first; `end_preview` (or opening
## or creating a world) puts a world back. Picks made while one forms wait,
## and only the last of them forms next.
func preview_land(land: String, seed_text: String) -> void:
	_preview_next = [land,seed_text]
	if _preview_forming: return
	_preview_forming = true
	while not _preview_next.is_empty():
		var next: Array = _preview_next
		_preview_next = []
		var places: Node = scene.get("places")
		if places == null or not places.initialized:
			# The launch title, before any world is set up: form in the scene directly.
			while scene._chunk_editor.forming: await get_tree().process_frame
			previewing = true
			await Lands.form(scene,next[0],Library.seed_value(next[1]))
			continue
		await _until_idle()
		if not previewing: keep_now()
		previewing = true
		await places.open_land(next[0],Library.seed_value(next[1]))
	_preview_forming = false

## Back from the New world screen without a new world: the open world returns.
func end_preview() -> void:
	if not previewing: return
	var places: Node = scene.get("places")
	if places == null or not places.initialized or current_id.is_empty():
		previewing = false
		return
	await _switch(current_id)

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
	if current_id.is_empty() or previewing: return false
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
## `reenter_title`, the hook the title UI takes over).
func return_to_title() -> void:
	if _titled() or current_id.is_empty(): return
	await _until_idle()
	keep_now()
	while keeping: await get_tree().process_frame
	title_requested.emit()
	if scene.has_method("reenter_title"): scene.reenter_title()

## On quit, after the scene's last save: the time it was kept and its capture.
func leaving() -> void:
	if current_id.is_empty() or previewing: return
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

func _switch(id: String) -> void:
	var world: Dictionary = library.find(id)
	if world.is_empty(): return
	await _until_idle()
	if not previewing and not current_id.is_empty() and id != current_id:
		# Kept and captured before its land leaves the scene.
		keep_now()
		while keeping: await get_tree().process_frame
	if id == current_id and not previewing:
		library.touch(id)
		world_opened.emit(id)
		return
	previewing = false
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
		keep_now()
	library.touch(id)
	_listen()
	world_opened.emit(id)

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
