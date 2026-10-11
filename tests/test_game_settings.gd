extends SceneTree
## The game's settings, saved and applied (scripts/kit_isle/game_settings.gd,
## settings_menu.gd, the title's card in scripts/kit_isle/front_door.gd;
## docs/design/consolidation-audit.md, round 2), headless, on files of its
## own (never the player's user://look.cfg, sound.cfg or pad.cfg):
##   - the kept sound comes back as the isle comes up (the Master volume and
##     the Sound bus on the AudioServer);
##   - the title's card has Settings; it opens the settings sheet over the
##     faded card, every setting there in its group, on its kept choice; Esc
##     brings the card back with Settings in reach;
##   - right on Volume steps it and applies it at once and keeps it; Mute
##     mutes the Master bus; Controller vibration off turns scripts/pad.gd's
##     rumble off; the render resolution's cap scales the 3D at once;
##   - the look's choices (quality, clouds, night sky, planet) are kept in
##     the look file under the old game's keys, so its look pass reads them
##     (headless has no look pass to apply them to live: unverified here);
##   - what's kept reads back the same.
##   godot --headless --path . --script tests/test_game_settings.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const GameSettings = preload("res://scripts/kit_isle/game_settings.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const Audio = preload("res://scripts/genesis_audio.gd")
const Pad = preload("res://scripts/pad.gd")
const FRONT_DOOR := "res://studies/zenscape.tscn"
const LOOK := "user://test_game_settings_look.cfg"
const SOUND := "user://test_game_settings_sound.cfg"
const PAD := "user://test_game_settings_pad.cfg"
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func until(condition: Callable, seconds := 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	return true

func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func near(a: float, b: float) -> bool:
	return absf(a-b) < 0.01

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	root.size = Vector2i(1440,900)
	for path: String in [LOOK,SOUND,PAD]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameSettings.look_path = LOOK
	GameSettings.sound_path = SOUND
	GameSettings.pad_path = PAD
	# A kept sound before the game starts.
	var kept := ConfigFile.new()
	kept.set_value("sound","master",0.3)
	kept.set_value("sound","muted",false)
	kept.set_value("sound","sound",0.6)
	kept.save(SOUND)
	LaunchArgs.set_override(PackedStringArray())
	change_scene_to_file(FRONT_DOOR)
	check(await until(func() -> bool: return current_scene != null and current_scene.scene_file_path == FRONT_DOOR,10.0),"The game opens")
	var game: Node3D = current_scene
	check(await until(func() -> bool: return game.isle_up,180.0),"The isle comes up")
	await frames(2)
	var bus := AudioServer.get_bus_index(Audio.BUS)
	check(near(db_to_linear(AudioServer.get_bus_volume_db(0)),0.3) and bus >= 0 and near(db_to_linear(AudioServer.get_bus_volume_db(bus)),0.6),"The kept sound is applied as the isle comes up")
	# The title's Settings.
	var door: Node = game.front_door
	check(door.titled and door.settings_button != null and door.settings_button.get("quiet"),"Settings quiet on the title's card")
	door.settings_button.grab_focus()
	await key(KEY_ENTER)
	var sheet: Control = door.settings
	check(sheet != null and sheet.is_visible_in_tree() and door.title.modulate.a == 0.0,"It opens the settings sheet over the faded card")
	var keys: Array = sheet.choice_rows.keys()
	check(keys.size() == GameSettings.ENTRIES.size(),"Every setting is on it (%s)" % ", ".join(PackedStringArray(keys)))
	var volume: Button = sheet.choice_rows.master
	check(volume.chosen == 3 and volume.value() == "30%","Volume on its kept 30%")
	check(root.gui_get_focus_owner() == sheet.choice_rows.quality,"Visual quality in reach first")
	# Volume: right steps it, applies and keeps it.
	volume.grab_focus()
	await key(KEY_RIGHT)
	check(volume.value() == "40%" and near(db_to_linear(AudioServer.get_bus_volume_db(0)),0.4),"Right steps the volume and applies it at once")
	check(near(GameSettings.sound().master,0.4),"...and keeps it")
	await key(KEY_LEFT)
	await key(KEY_LEFT)
	check(volume.value() == "20%" and near(db_to_linear(AudioServer.get_bus_volume_db(0)),0.2),"Left steps it down")
	# Mute.
	var mute: Button = sheet.choice_rows.muted
	mute.grab_focus()
	await key(KEY_ENTER)
	check(mute.value() == "On" and AudioServer.is_bus_mute(0) and GameSettings.sound().muted,"Mute mutes the Master bus, kept")
	await key(KEY_ENTER)
	check(not AudioServer.is_bus_mute(0),"...and lets it go")
	# Vibration.
	var shake: Button = sheet.choice_rows.vibration
	check(shake.value() == "On" and Pad.vibration(),"Controller vibration on to begin with")
	shake.grab_focus()
	await key(KEY_RIGHT)
	check(shake.value() == "Off" and not Pad.vibration() and not GameSettings.vibration(),"Off turns the rumble off, kept")
	await key(KEY_RIGHT)
	check(Pad.vibration(),"...and on again")
	# Render resolution.
	var lines: Button = sheet.choice_rows.resolution
	lines.grab_focus()
	var index := 0
	while lines.value() != "720p" and index < 8:
		await key(KEY_RIGHT)
		index += 1
	var expected := minf(1.0,720.0/float(root.size.y))
	check(lines.value() == "720p" and near(root.scaling_3d_scale,expected),"720p scales the 3D at once (%.2f)" % root.scaling_3d_scale)
	var file := ConfigFile.new()
	file.load(LOOK)
	check(int(file.get_value("display","max_lines",0)) == 720,"...kept as the old game keeps it")
	# The look's choices.
	for pair: Array in [["quality",KEY_RIGHT],["clouds",KEY_RIGHT],["night",KEY_RIGHT],["planet",KEY_RIGHT],["season",KEY_RIGHT]]:
		var row: Button = sheet.choice_rows[pair[0]]
		row.grab_focus()
		await key(pair[1])
	file = ConfigFile.new()
	file.load(LOOK)
	check(int(file.get_value("quality","tier",-1)) == 2,"Visual quality kept (Balanced to Ultra)")
	check(LookPass.load_cloud_style(LOOK) == LookPass.CLOUD_STYLES[1],"Clouds kept where the look pass reads them")
	var night_was := LookPass.NIGHT_STYLES.find(LookPass.NIGHT_DEFAULT)
	check(LookPass.load_night_style(LOOK) == LookPass.NIGHT_STYLES[(night_was+1)%LookPass.NIGHT_STYLES.size()],"Night sky kept")
	check(LookPass.load_sky_planet(LOOK),"Planet kept")
	check(int(file.get_value("time","season",-1)) == 1 and GameSettings.options("season")[1] == "Spring","Season kept (Live to Spring) under [time]")
	for key_name: String in sheet.choice_rows:
		check(GameSettings.index_of(key_name) == sheet.choice_rows[key_name].chosen,"%s reads back as chosen" % key_name)
	# Back.
	await key(KEY_ESCAPE)
	check(not sheet.visible and door.titled and door.settings_button.has_focus(),"Esc brings the card back, Settings in reach")
	check(await until(func() -> bool: return door.title.modulate.a >= 1.0,3.0),"The card comes back")
	for path: String in [LOOK,SOUND,PAD]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	LaunchArgs.set_override(null)
	print("game settings: %d failures" % failures)
	quit(1 if failures else 0)
