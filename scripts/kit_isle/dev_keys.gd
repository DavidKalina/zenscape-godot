extends RefCounted
## The study's developer keys and capture flags in the game (studies/
## zenscape.gd; docs/design/consolidation-audit.md, round 2): what the
## character study and the kit isle answer that a player shouldn't meet.
## On foot: F1 (the numbers), F2 (the feel panel), F3 (carving), F5-F8 (the
## recorder and its replays), the station keys 0-9, -, =, [, ] and \, L and
## Shift+L (the look presets), B (a gust front). In the plane: F1 (the
## numbers) and R (the study's reset: the plane home, the pilot at the
## start). Both: F9-F12 (the time and weather, scripts/kit_isle/
## kit_weather.gd). The capture flags: --capture=, --capture-seq=, --capture-wait=,
## --capture-high, --at= and --card-hold.
##
## Gated as the scene picker is (scripts/scene_catalog.gd `enabled`,
## docs/design/scene-picker.md "Release gating"): editor and debug runs
## always have them; a release export only while IN_RELEASE is true or the
## project setting zenscape/dev/dev_keys (default IN_RELEASE) says so.
## `--dev-keys` forces them on, `--no-dev-keys` off anywhere. `as_release`
## makes a debug run judge as a release export would (tests).

const LaunchArgs = preload("res://scripts/launch_args.gd")
## Whether a release export keeps the developer keys. Off: players don't
## get them.
const IN_RELEASE := false
const SETTING := "zenscape/dev/dev_keys"
## The keys that are the study's on foot, and in the plane.
const FOOT_KEYS := [KEY_F1,KEY_F2,KEY_F3,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12,KEY_L,KEY_B,
	KEY_0,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,
	KEY_MINUS,KEY_EQUAL,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_BACKSLASH]
const PLANE_KEYS := [KEY_F1,KEY_R,KEY_L,KEY_B,KEY_F9,KEY_F10,KEY_F11,KEY_F12]
## Capture flags: whole flags, and flags by their prefix.
const CAPTURE_FLAGS := ["--capture-high","--card-hold"]
const CAPTURE_PREFIXES := ["--capture=","--capture-seq=","--capture-wait=","--at="]

static var as_release := false

## Whether the developer keys and capture flags work in this run.
static func enabled() -> bool:
	var args := LaunchArgs.user_args()
	if "--no-dev-keys" in args: return false
	if "--dev-keys" in args: return true
	if not as_release and (OS.has_feature("editor") or OS.is_debug_build()): return true
	return bool(ProjectSettings.get_setting(SETTING,IN_RELEASE))

## True for a key press that is one of the study's (on foot, or in the
## plane while `flying`).
static func is_dev_event(event: InputEvent, flying: bool) -> bool:
	if not event is InputEventKey or not event.pressed: return false
	return (event as InputEventKey).keycode in (PLANE_KEYS if flying else FOOT_KEYS)

static func is_capture_flag(arg: String) -> bool:
	if arg in CAPTURE_FLAGS: return true
	for prefix: String in CAPTURE_PREFIXES:
		if arg.begins_with(prefix): return true
	return false

## `args` without the capture flags.
static func without_captures(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for arg: String in args:
		if not is_capture_flag(arg): out.append(arg)
	return out

## Before the isle reads its flags: with the developer keys off, the
## capture flags leave the flags in force (scripts/launch_args.gd), so a
## release build never starts a capture.
static func strip_captures() -> void:
	if enabled(): return
	var args := LaunchArgs.user_args()
	var kept := without_captures(args)
	if kept.size() != args.size(): LaunchArgs.set_override(kept)
