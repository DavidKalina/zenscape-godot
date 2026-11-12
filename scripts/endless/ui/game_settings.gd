extends RefCounted
## The game's settings in one place: loaded, applied and kept. The settings
## page (scripts/endless/ui/settings_page.gd) shows them, the flight's dev
## keys (F2, F3) go through the same setters, and the game reads the getters.
##
##     const GameSettings = preload("res://scripts/endless/ui/game_settings.gd")
##     GameSettings.begin()                 # at a scene's start: load once, apply
##     GameSettings.hud_hints()             # read one
##     GameSettings.set_invert_pitch(true)  # change one: applied and kept at once
##     GameSettings.hub.changed.connect(func(key: String) -> void: ...)
##
## Where each lives (a key sits in the file that already holds its
## neighbours, else in settings.cfg), and how it is applied:
##
## | setting | file, [section] key | applied by |
## |---|---|---|
## | graphics preset | look.cfg [graphics] preset | scripts/graphics_preset.gd at the flight's start: `restart` opens the flight again on it (the grass and trees read its flags when they are made) |
## | 3D resolution | look.cfg [display] scale_3d | RenderResolution.scale_override, as F2 |
## | full screen | look.cfg [display] fullscreen | DisplayServer.window_set_mode |
## | vsync | look.cfg [display] vsync | DisplayServer.window_set_vsync_mode |
## | Master, Effects, Ambience | sound.cfg [sound] master, sound, ambience | the buses Master, SFX (SFX Air and SFX Bore feed it; the Genesis bus too) and Ambience, through genesis_audio's and flight_sound's `apply_settings` |
## | mouse sensitivity | settings.cfg [controls] mouse_sensitivity | a factor on the flight's FLY_LOOK |
## | invert pitch | settings.cfg [controls] invert_pitch | `pitch_sign` on the flight's pitch (keys, stick and mouse) |
## | HUD hints | settings.cfg [hud] hints | `hud_hints`, read by the HUD |
##
## Until the player chooses, the display rows show what the window is doing
## (the project starts full screen with vsync off; the launchers pass
## --windowed) and the 3D resolution the scale the viewport draws at.
##
## A launch flag wins for its run and is not kept: --windowed, --fullscreen
## and --resolution over the kept window mode, --disable-vsync and
## --uncapped over the kept vsync, --render-scale= over the kept 3D scale,
## --preset= over the kept preset. A change made on the page while such a
## run is up is the player's, so it is applied and kept.
##
## Harness runs never write the player's files: nothing is saved when the
## game runs headless, under a script (-s, the drivers), with
## ZENSCAPE_NO_BOOK set (tools/godot.py sets it on every run) or with
## --pilot=fresh, the conditions the pilot's book (scripts/endless/pilot_book.gd)
## and the graphics preset already go by. Headless and script runs do not
## read them either, but for the sound, which the flight has always read: a
## player's inverted pitch would turn every driver's stick over. A run with
## --settings-dir=DIR reads and writes its three files in DIR instead (a
## check's throwaway folder), whatever else it is.

const GraphicsPreset = preload("res://scripts/graphics_preset.gd")
const RenderResolution = preload("res://scripts/render_resolution.gd")
const Audio = preload("res://scripts/genesis_audio.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const LOOK := "look.cfg"
const SOUND := "sound.cfg"
const OWN := "settings.cfg"
## The 3D resolutions offered (the flight's F2 steps through the same).
const SCALES := [1.0,0.85,0.75,0.67]
## The mouse's factor on the flight's look: from, to, a step.
const MOUSE := Vector3(0.2,2.0,0.1)
## A volume slider's step.
const VOLUME_STEP := 0.05
## The window a start in full screen falls back to when the player picks Windowed.
const WINDOW := Vector2i(1440,900)

## `changed(key)` after a setter: "preset", "scale", "display", "vsync",
## "master", "effects", "ambience", "mouse", "invert", "hints".
class Hub:
	signal changed(key: String)
static var hub := Hub.new()

static var _loaded := false
static var _dir := "user://"
static var _saves := true
static var _reads := true
static var _preset := ""
static var _scale := -1.0
static var _fullscreen := true
static var _fullscreen_kept := false
static var _vsync := false
static var _vsync_kept := false
static var _master := 1.0
static var _muted := false
static var _effects := 0.8
static var _ambience := 0.8
static var _mouse := 1.0
static var _invert := false
static var _hints := true

# --- Start -------------------------------------------------------------------------------

## Loads the settings (once a run) and applies them. Call at a scene's start,
## after GraphicsPreset.begin and the scene's own RenderResolution.apply.
static func begin() -> void:
	var first := not _loaded
	_ensure()
	if GraphicsPreset.current in GraphicsPreset.PRESETS: _preset = GraphicsPreset.current
	if _scale > 0.0 and not _flag("--render-scale="): _apply_scale()
	if first and DisplayServer.get_name() != "headless":
		if _fullscreen_kept and not _window_flag(): _apply_window(_fullscreen)
		if _vsync_kept and not "--disable-vsync" in OS.get_cmdline_args(): _apply_vsync(_vsync)
	_apply_sound()

## True when a change is written to the settings files (see the header).
static func saves() -> bool:
	_ensure()
	return _saves

## The file a setting is kept in: `LOOK`, `SOUND` or `OWN` in the run's folder.
static func path(file: String) -> String:
	_ensure()
	return _dir.path_join(file)

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	var own_dir := false
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--settings-dir="):
			_dir = a.get_slice("=",1)
			own_dir = true
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var args := OS.get_cmdline_args()
	var script_run := DisplayServer.get_name() == "headless" or "-s" in args or "--script" in args
	_saves = own_dir or not (script_run or OS.has_environment("ZENSCAPE_NO_BOOK") or "--pilot=fresh" in LaunchArgs.user_args())
	_reads = own_dir or not script_run
	_preset = GraphicsPreset.current if GraphicsPreset.current in GraphicsPreset.PRESETS else GraphicsPreset.chosen()
	var sound := FlightSound.load_settings(_dir.path_join(SOUND))
	_master = float(sound.get("master",1.0))
	_muted = bool(sound.get("muted",false))
	_effects = float(sound.get("sound",0.8))
	_ambience = float(sound.get("ambience",FlightSound.DEFAULT_AMBIENCE))
	if not _reads: return
	var look := ConfigFile.new()
	if look.load(_dir.path_join(LOOK)) == OK:
		if look.has_section_key("display","scale_3d"): _scale = _near_scale(float(look.get_value("display","scale_3d")))
		_fullscreen_kept = look.has_section_key("display","fullscreen")
		if _fullscreen_kept: _fullscreen = bool(look.get_value("display","fullscreen"))
		_vsync_kept = look.has_section_key("display","vsync")
		if _vsync_kept: _vsync = bool(look.get_value("display","vsync"))
	var own := ConfigFile.new()
	if own.load(_dir.path_join(OWN)) == OK:
		_mouse = clampf(snappedf(float(own.get_value("controls","mouse_sensitivity",1.0)),MOUSE.z),MOUSE.x,MOUSE.y)
		_invert = bool(own.get_value("controls","invert_pitch",false))
		_hints = bool(own.get_value("hud","hints",true))

static func _flag(prefix: String) -> bool:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(prefix): return true
	return false

static func _window_flag() -> bool:
	for a: String in OS.get_cmdline_args():
		if a in ["--windowed","-w","--fullscreen","-f","--maximized","-m","--resolution","--position"]: return true
	return false

static func _put(file: String, section: String, key: String, value: Variant) -> void:
	if not _saves: return
	var at := _dir.path_join(file)
	var cfg := ConfigFile.new()
	cfg.load(at)
	cfg.set_value(section,key,value)
	cfg.save(at)

static func _root() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null

# --- Graphics ----------------------------------------------------------------------------

## The graphics preset chosen ("performance", "quality", "full"): the one in
## force, or the one the next `restart` brings while `preset_pending`.
static func preset() -> String:
	_ensure()
	return _preset

## Chooses and keeps a preset. It takes hold when the flight starts again:
## `restart` (the page calls it as it closes, F3 at once).
static func set_preset(id: String) -> void:
	_ensure()
	if not id in GraphicsPreset.PRESETS or id == _preset: return
	_preset = id
	_put(LOOK,"graphics","preset",id)
	hub.changed.emit("preset")

## True while the chosen preset is not the one this flight was built on.
static func preset_pending() -> bool:
	_ensure()
	return GraphicsPreset.current in GraphicsPreset.PRESETS and _preset != GraphicsPreset.current

## Opens `scene` again on the chosen preset, with the run's own flags (the
## preset named among them, so a run that reads no settings file takes it
## too), straight into the air, or behind its title with `title`.
static func restart(tree: SceneTree, scene: String, title := false) -> void:
	_ensure()
	var args := PackedStringArray()
	for a: String in LaunchArgs.own_args():
		if not a.begins_with("--preset=") and a != "--open-settings": args.append(a)
	args.append("--preset="+_preset)
	tree.paused = false
	LaunchArgs.open_scene(tree,scene,args,title)

## The scale the 3D is drawn at (1 is the window's own resolution).
static func scale() -> float:
	var root := _root()
	return root.scaling_3d_scale if root != null else 1.0

## The 3D drawn at `value` of the window's resolution (one of SCALES), kept.
static func set_scale(value: float) -> void:
	_ensure()
	_scale = _near_scale(value)
	_apply_scale()
	_put(LOOK,"display","scale_3d",_scale)
	hub.changed.emit("scale")

static func _near_scale(value: float) -> float:
	var best: float = SCALES[0]
	for s: float in SCALES:
		if absf(s-value) < absf(best-value): best = s
	return best

static func _apply_scale() -> void:
	RenderResolution.scale_override = _scale
	var root := _root()
	if root != null: RenderResolution.apply(root,RenderResolution.load_cap())

## True when the window is full screen (headless: the kept choice).
static func fullscreen() -> bool:
	_ensure()
	if DisplayServer.get_name() == "headless": return _fullscreen
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

## Full screen or a window, now and kept.
static func set_fullscreen(on: bool) -> void:
	_ensure()
	_fullscreen = on
	_fullscreen_kept = true
	_apply_window(on)
	_put(LOOK,"display","fullscreen",on)
	hub.changed.emit("display")

static func _apply_window(on: bool) -> void:
	if DisplayServer.get_name() == "headless" or on == fullscreen(): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if on: return
	# A game started full screen has no window to go back to: it comes out as
	# large as the screen. Give it one, centred.
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var now := DisplayServer.window_get_size()
	if now.x < screen.size.x and now.y < screen.size.y: return
	var size := Vector2i(mini(WINDOW.x,int(screen.size.x*0.8)),mini(WINDOW.y,int(screen.size.y*0.8)))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position+(screen.size-size)/2)

## True when frames wait for the screen (headless: the kept choice).
static func vsync() -> bool:
	_ensure()
	if DisplayServer.get_name() == "headless": return _vsync
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

## VSync on or off, now and kept.
static func set_vsync(on: bool) -> void:
	_ensure()
	_vsync = on
	_vsync_kept = true
	_apply_vsync(on)
	_put(LOOK,"display","vsync",on)
	hub.changed.emit("vsync")

static func _apply_vsync(on: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

# --- Sound -------------------------------------------------------------------------------

## A volume, 0..1: `which` is "master", "effects" or "ambience".
static func volume(which: String) -> float:
	_ensure()
	match which:
		"master": return _master
		"effects": return _effects
		"ambience": return _ambience
	return 0.0

## A volume set (0..1), on its bus now and kept.
static func set_volume(which: String, value: float) -> void:
	_ensure()
	var v := clampf(value,0.0,1.0)
	match which:
		"master":
			_master = v
			_put(SOUND,"sound","master",v)
		"effects":
			_effects = v
			_put(SOUND,"sound","sound",v)
		"ambience":
			_ambience = v
			_put(SOUND,"sound","ambience",v)
		_: return
	_apply_sound()
	hub.changed.emit(which)

## The volumes on their buses, in a run that plays sound (FlightSound.wanted).
static func _apply_sound() -> void:
	if not FlightSound.wanted(): return
	var s := {"master":_master,"muted":_muted,"sound":_effects,"ambience":_ambience}
	Audio.apply_settings(s)
	FlightSound.apply_settings(s)

# --- Controls and the HUD ----------------------------------------------------------------

## The mouse's factor on the flight's look (1 is the game's own).
static func mouse_sens() -> float:
	_ensure()
	return _mouse

static func set_mouse_sens(value: float) -> void:
	_ensure()
	_mouse = clampf(snappedf(value,MOUSE.z),MOUSE.x,MOUSE.y)
	_put(OWN,"controls","mouse_sensitivity",_mouse)
	hub.changed.emit("mouse")

static func invert_pitch() -> bool:
	_ensure()
	return _invert

## -1 with pitch inverted, else 1: the flight multiplies its pitch input by it.
static func pitch_sign() -> float:
	_ensure()
	return -1.0 if _invert else 1.0

static func set_invert_pitch(on: bool) -> void:
	_ensure()
	_invert = on
	_put(OWN,"controls","invert_pitch",on)
	hub.changed.emit("invert")

## Whether the HUD shows its key hints.
static func hud_hints() -> bool:
	_ensure()
	return _hints

static func set_hud_hints(on: bool) -> void:
	_ensure()
	_hints = on
	_put(OWN,"hud","hints",on)
	hub.changed.emit("hints")

# --- The page's rows ---------------------------------------------------------------------
# A row is named by its id: "preset", "scale", "display", "vsync", "invert",
# "hints" pick one of a few; "master", "effects", "ambience", "mouse" slide.

## The option a row shows chosen (On is 0, Off 1; Fullscreen 0, Windowed 1).
static func index(id: String) -> int:
	_ensure()
	match id:
		"preset": return maxi(GraphicsPreset.NAMES.find(_preset),0)
		"scale": return SCALES.find(_near_scale(scale()))
		"display": return 0 if fullscreen() else 1
		"vsync": return 0 if vsync() else 1
		"invert": return 0 if _invert else 1
		"hints": return 0 if _hints else 1
	return 0

## Chooses option `i` of a row.
static func pick(id: String, i: int) -> void:
	match id:
		"preset": set_preset(GraphicsPreset.NAMES[clampi(i,0,GraphicsPreset.NAMES.size()-1)])
		"scale": set_scale(SCALES[clampi(i,0,SCALES.size()-1)])
		"display": set_fullscreen(i == 0)
		"vsync": set_vsync(i == 0)
		"invert": set_invert_pitch(i == 0)
		"hints": set_hud_hints(i == 0)

## A slider's place, 0..1.
static func frac(id: String) -> float:
	if id == "mouse": return (mouse_sens()-MOUSE.x)/(MOUSE.y-MOUSE.x)
	return volume(id)

## A slider set from a place 0..1 (a click or drag), snapped to its steps.
static func slide(id: String, f: float) -> void:
	var to := clampf(f,0.0,1.0)
	if id == "mouse": set_mouse_sens(MOUSE.x+to*(MOUSE.y-MOUSE.x))
	else: set_volume(id,snappedf(to,VOLUME_STEP))

## A slider moved one step down (-1) or up (1).
static func nudge(id: String, dir: int) -> void:
	if id == "mouse": set_mouse_sens(mouse_sens()+MOUSE.z*float(dir))
	else: set_volume(id,snappedf(volume(id)+VOLUME_STEP*float(dir),VOLUME_STEP))

## A slider's numeral: a volume as 0 to 100, the mouse's factor as 0.2 to 2.0.
static func shown(id: String) -> String:
	if id == "mouse": return "%.1f" % mouse_sens()
	return str(roundi(volume(id)*100.0))
