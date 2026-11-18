extends RefCounted
## Endless flight's graphics presets: each a render height, a frame cap and
## launch flags laid under the command line's (LaunchArgs `defaults`), so a
## flag typed at launch still wins. Kept in user://look.cfg [graphics] preset;
## --preset=NAME wins for one run; F3 in flight steps to the next and starts
## the flight again (the grass and trees read their flags when they're made).
## Until the player picks, a Mac runs Performance and anything else Full;
## headless and harness (-s) runs run Full unless they pass --preset=.
## The Mac's numbers: docs/design/endless-flight/mac-presets-handoff.md.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const SETTINGS_PATH := "user://look.cfg"
const NAMES := ["performance","quality","full"]
## lines: the 3D's most lines high (0: the player's render resolution cap);
## fps: the frame cap (0: the project's); args: the flags. The numbers are the
## M5 Pro's at 3024x1964 (the handoff): MSAA cost about 8 ms in flight there,
## the trees' far crowns about 5 and their shadows about 3.
const PRESETS := {
	"performance": {"title":"Performance (60)","lines":900,"fps":60,"args":[
		"--msaa=0","--screen-aa=fxaa",
		"--spruce-detail=40","--spruce-far=120","--spruce-mid=250","--no-tree-shadows",
		"--cloud-steps=72","--valley-fog-steps=16"]},
	"quality": {"title":"Quality (45)","lines":1080,"fps":45,"args":[
		"--msaa=0","--screen-aa=fxaa",
		"--grass-range=150","--spruce-far=120"]},
	"full": {"title":"Full","lines":0,"fps":0,"args":[]},
}

## Quality off the Mac (RTX 4070 Super at 1080 lines): --grass-range scales
## every ring, so the Mac's 150 stopped the tall carpet 20 m off the plane; 190
## here is 0.5 to 1 ms under the full 230. The trees' hand-overs cost under
## 0.7 ms together at 200 m (the default) and 120 m, against the Mac's 5.
const QUALITY_PC := ["--msaa=0","--screen-aa=fxaa","--spruce-detail=120"]

## The grass levels (Settings > Grass), their flags laid over the preset's:
## Ultra is the grass as built (every tuft, the rings out to 230 m), High the
## rings drawn in to 190 m, Medium three tufts in four as well, Low half the
## tufts and the rings in to 150 m. On an RTX 4070 SUPER low among trees and
## grass (1440x900, 12.2 ms of GPU a frame on Ultra) High is 0.75 ms under
## Ultra, Medium 1.35, Low 2.3.
const GRASS_NAMES := ["ultra","high","medium","low"]
const GRASS := {
	"ultra": [],
	"high": ["--grass-range=190"],
	"medium": ["--grass=0.75","--grass-range=190"],
	"low": ["--grass=0.5","--grass-range=150"],
}
## The level a preset starts on until the player picks one (the grass each
## preset had before the levels; the Mac's Quality keeps its own range above).
static func grass_default(preset: String) -> String:
	match preset:
		"performance": return "low"
		"quality": return "ultra" if OS.get_name() == "macOS" else "high"
	return "ultra"

## The preset in force this run.
static var current := ""
## The grass level in force this run.
static var grass := ""
## The frame cap the game booted with (the project's), for a preset with none.
static var _boot_fps := -1

## The preset for this run (the flag, else the saved one, else the
## machine's), its flags laid under the command line's and its height given
## to the render resolution. Call before anything reads the flags.
static func begin() -> void:
	current = chosen()
	var p: Dictionary = PRESETS[current]
	grass = chosen_grass(current)
	LaunchArgs.defaults = PackedStringArray(QUALITY_PC if current == "quality" and OS.get_name() != "macOS" else p.args)+PackedStringArray(GRASS[grass])
	preload("res://scripts/render_resolution.gd").preset_lines = int(p.lines)

static func chosen() -> String:
	for a: String in LaunchArgs.own_args():
		if a.begins_with("--preset=") and a.get_slice("=",1) in PRESETS: return a.get_slice("=",1)
	# Tests and harness runs (headless, or a -s script) keep the full look
	# unless they name a preset.
	var script_run := "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args()
	if DisplayServer.get_name() == "headless" or script_run: return "full"
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		var saved := str(file.get_value("graphics","preset",""))
		if saved in PRESETS: return saved
	return "performance" if OS.get_name() == "macOS" else "full"

## The grass level for a run on `preset`: --grass-level=, else the saved one
## (look.cfg [graphics] grass_level; not read by tests and harness runs), else
## the preset's own.
static func chosen_grass(preset: String) -> String:
	for a: String in LaunchArgs.own_args():
		if a.begins_with("--grass-level=") and a.get_slice("=",1) in GRASS: return a.get_slice("=",1)
	var script_run := "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args()
	if DisplayServer.get_name() != "headless" and not script_run:
		var file := ConfigFile.new()
		if file.load(SETTINGS_PATH) == OK:
			var saved := str(file.get_value("graphics","grass_level",""))
			if saved in GRASS: return saved
	return grass_default(preset)

static func title() -> String:
	if not current in PRESETS: return ""
	var t := str(PRESETS[current].title)
	return t if OS.get_name() == "macOS" else t.get_slice(" (",0)

## The frame cap for this run: the preset's, else the project's.
static func fps() -> int:
	if _boot_fps < 0: _boot_fps = Engine.max_fps
	# The caps are the Mac's (its handoff's numbers); a saved Quality on the
	# Windows PC sat at exactly 45 with 12 ms of work a frame.
	if OS.get_name() != "macOS": return _boot_fps
	var own := int(PRESETS[current].fps) if current in PRESETS else 0
	return own if own > 0 else _boot_fps

## The next preset, kept for the next run; its name.
static func step() -> String:
	var next: String = NAMES[(NAMES.find(current)+1)%NAMES.size()]
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	file.set_value("graphics","preset",next)
	file.save(SETTINGS_PATH)
	return next

## The flight again on the next preset, straight into the air: the run's own
## flags without a --preset= (the saved choice is the new one).
static func restart(tree: SceneTree, scene: String) -> void:
	var args := PackedStringArray()
	for a: String in LaunchArgs.own_args():
		if not a.begins_with("--preset="): args.append(a)
	LaunchArgs.open_scene(tree,scene,args)
