extends "res://scripts/endless/shell/shell_page.gd"
## Settings, one screen in three sections (Display, Sound, Controls); every
## change applies at once and is kept (scripts/endless/shell/shell_settings.gd).
## The graphics preset is kept at once and taken up when the screen closes:
## the flight starts again on it as F3 does (from the title, the title again).

const S = preload("res://scripts/endless/shell/shell_settings.gd")
const RenderResolution = preload("res://scripts/render_resolution.gd")
const GraphicsPreset = preload("res://scripts/graphics_preset.gd")

func _init(shell: Node) -> void:
	super()
	title = "Settings"
	width = 640.0
	var presets: Array = []
	for i in GraphicsPreset.NAMES.size(): presets.append(S.preset_title(i))
	var pct := func(v: float) -> String: return "%d" % roundi(v*100.0)
	var sound_get := func(key: String) -> float: return float(S.sound().get(key,0.8))
	var sound_set := func(v: float, key: String) -> void: S.set_sound(key,v)
	set_rows([
		{"kind":"heading","text":"Display"},
		{"kind":"toggle","text":"Fullscreen","get":S.fullscreen,"set":S.set_fullscreen},
		{"kind":"choice","text":"Render resolution","names":RenderResolution.CAP_NAMES,"get":S.cap_index,
			"set":func(i: int) -> void: S.set_cap_index(i,shell.get_tree().root)},
		{"kind":"choice","text":"Graphics","names":presets,"get":S.preset_index,
			"set":func(i: int) -> void:
				S.set_preset_index(i)
				shell.note_preset()},
		{"kind":"toggle","text":"Vsync","get":S.vsync,"set":S.set_vsync},
		{"kind":"heading","text":"Sound"},
		{"kind":"slider","text":"Master","lo":0.0,"hi":1.0,"step":0.05,"fmt":pct,"get":sound_get.bind("master"),"set":sound_set.bind("master")},
		{"kind":"slider","text":"Effects","lo":0.0,"hi":1.0,"step":0.05,"fmt":pct,"get":sound_get.bind("sound"),"set":sound_set.bind("sound")},
		{"kind":"slider","text":"Ambience","lo":0.0,"hi":1.0,"step":0.05,"fmt":pct,"get":sound_get.bind("ambience"),"set":sound_set.bind("ambience")},
		{"kind":"toggle","text":"Mute","get":func() -> bool: return bool(S.sound().get("muted",false)),
			"set":func(on: bool) -> void: S.set_sound("muted",on)},
		{"kind":"toggle","text":"Controller vibration","get":S.vibration,"set":S.set_vibration},
		{"kind":"heading","text":"Controls"},
		{"kind":"slider","text":"Mouse sensitivity","lo":S.MOUSE_MIN,"hi":S.MOUSE_MAX,"step":0.05,"fmt":pct,"get":S.mouse,"set":S.set_mouse},
		{"kind":"toggle","text":"Invert pitch (mouse)","get":S.invert_mouse,"set":S.set_invert_mouse},
		{"kind":"toggle","text":"Invert pitch (stick)","get":S.invert_stick,"set":S.set_invert_stick},
		{"kind":"note","text":"A gamepad works everywhere: plug it in and fly. The keys and buttons are on the Controls page."},
	])
