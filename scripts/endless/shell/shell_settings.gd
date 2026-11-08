extends RefCounted
## The shell's settings (scripts/endless/shell/settings_page.gd): each read
## from and written to the config file its owner already keeps, applied live,
## saved on change. No new files: look.cfg [display] fullscreen and vsync and
## [controls] (mouse, invert_mouse, invert_stick) sit beside the render cap
## and the preset; sound.cfg [sound] (master, sound, ambience, muted) is
## flight_sound.gd's and genesis_audio.gd's; pad.cfg is pad.gd's.

const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const GraphicsPreset = preload("res://scripts/graphics_preset.gd")
const RenderResolution = preload("res://scripts/render_resolution.gd")
const Pad = preload("res://scripts/pad.gd")
const Audio = preload("res://scripts/genesis_audio.gd")
const LOOK := "user://look.cfg"
## The mouse's steer, a multiple of the flight's own (endless_flight FLY_LOOK).
const MOUSE_MIN := 0.25
const MOUSE_MAX := 3.0
## How far the sound sinks while paused (dB on Effects, Ambience, Genesis).
const DUCK_DB := -18.0
## The window a windowed switch opens at, at most this share of the screen.
const WINDOW := Vector2i(1440,900)

static var _cache := {}

static func _look(section: String, key: String, default: Variant) -> Variant:
	var id := section+"/"+key
	if not _cache.has(id):
		var file := ConfigFile.new()
		file.load(LOOK)
		_cache[id] = file.get_value(section,key,default)
	return _cache[id]

static func _keep(section: String, key: String, value: Variant, path := LOOK) -> void:
	if path == LOOK: _cache[section+"/"+key] = value
	var file := ConfigFile.new()
	file.load(path)
	file.set_value(section,key,value)
	file.save(path)

static func _saved(section: String, key: String) -> bool:
	var file := ConfigFile.new()
	return file.load(LOOK) == OK and file.has_section_key(section,key)

static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

# --- Display --------------------------------------------------------------

static func fullscreen() -> bool:
	if _headless(): return bool(_look("display","fullscreen",true))
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

static func set_fullscreen(on: bool) -> void:
	_keep("display","fullscreen",on)
	_window(on)

static func _window(on: bool) -> void:
	if _headless(): return
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := Vector2i(mini(WINDOW.x,int(screen.size.x*0.9)),mini(WINDOW.y,int(screen.size.y*0.9)))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position+(screen.size-size)/2)

static func vsync() -> bool:
	return bool(_look("display","vsync",false))

static func set_vsync(on: bool) -> void:
	_keep("display","vsync",on)
	if not _headless(): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

static func cap_index() -> int:
	return maxi(0,RenderResolution.CAPS.find(RenderResolution.load_cap()))

static func set_cap_index(i: int, viewport: Viewport) -> void:
	var cap: int = RenderResolution.CAPS[clampi(i,0,RenderResolution.CAPS.size()-1)]
	RenderResolution.save_cap(cap)
	RenderResolution.apply(viewport,cap)

## The preset kept for the next run (the one in force until the flight restarts).
static func preset_index() -> int:
	var file := ConfigFile.new()
	var saved := GraphicsPreset.current
	if file.load(GraphicsPreset.SETTINGS_PATH) == OK: saved = str(file.get_value("graphics","preset",saved))
	return maxi(0,GraphicsPreset.NAMES.find(saved if saved in GraphicsPreset.NAMES else GraphicsPreset.current))

static func set_preset_index(i: int) -> void:
	_keep("graphics","preset",GraphicsPreset.NAMES[clampi(i,0,GraphicsPreset.NAMES.size()-1)],GraphicsPreset.SETTINGS_PATH)

static func preset_title(i: int) -> String:
	var t := str(GraphicsPreset.PRESETS[GraphicsPreset.NAMES[i]].title)
	return t if OS.get_name() == "macOS" else t.get_slice(" (",0)

## The kept window mode and vsync, at boot: only what the player chose, and
## not over a launch flag that sets the window (the harness's --windowed).
static func apply_boot() -> void:
	_cache.clear()
	if _headless(): return
	var args := OS.get_cmdline_args()
	var flagged := false
	for a: String in args:
		if a in ["--windowed","--fullscreen","-f","-w","--maximized"] or a.begins_with("--resolution"): flagged = true
	if not flagged and _saved("display","fullscreen") and fullscreen() != bool(_look("display","fullscreen",true)): _window(bool(_look("display","fullscreen",true)))
	if _saved("display","vsync") and not "--uncapped" in OS.get_cmdline_user_args(): set_vsync(vsync())

# --- Controls -------------------------------------------------------------

static func mouse() -> float:
	return clampf(float(_look("controls","mouse",1.0)),MOUSE_MIN,MOUSE_MAX)

static func set_mouse(v: float) -> void:
	_keep("controls","mouse",clampf(v,MOUSE_MIN,MOUSE_MAX))

static func invert_mouse() -> bool:
	return bool(_look("controls","invert_mouse",false))

static func set_invert_mouse(on: bool) -> void:
	_keep("controls","invert_mouse",on)

static func invert_stick() -> bool:
	return bool(_look("controls","invert_stick",false))

static func set_invert_stick(on: bool) -> void:
	_keep("controls","invert_stick",on)

## The mouse's move (x right, y up) as the flight should steer by it.
static func steer(v: Vector2) -> Vector2:
	return Vector2(v.x,-v.y if invert_mouse() else v.y)*mouse()

## The stick's pitch as the flight should read it: turned over with the
## pad in hand only (W and S share the actions and stay as they are).
static func stick_pitch(y: float) -> float:
	return -y if invert_stick() and Pad.using_pad() else y

# --- Sound ----------------------------------------------------------------

static var ducked := false

static func sound() -> Dictionary:
	return FlightSound.load_settings()

static func set_sound(key: String, value: Variant) -> void:
	_keep("sound",key,value,Audio.SETTINGS_PATH)
	apply_sound()

static func apply_sound() -> void:
	var s := sound()
	FlightSound.apply_settings(s)
	Audio.apply_settings(s)
	if not ducked: return
	for bus: StringName in [FlightSound.SFX,FlightSound.AMBIENCE,Audio.BUS]:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0: AudioServer.set_bus_volume_db(i,AudioServer.get_bus_volume_db(i)+DUCK_DB)

static func duck(on: bool) -> void:
	ducked = on
	apply_sound()

static func vibration() -> bool:
	return Pad.vibration()

static func set_vibration(on: bool) -> void:
	Pad.set_vibration(on)
