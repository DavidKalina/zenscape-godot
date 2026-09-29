extends SceneTree
## Headless probe of the title (studies/cozy_worlds.gd `_run_title`): the main
## scene, loaded as the current scene, opens on a generated world under the
## title menu with no world open; "Create a new world" closes the menu and
## opens the Genesis plain.
var failures: Array[String] = []

func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print(("OK   " if ok else "FAIL ")+what+("  "+str(detail) if str(detail) != "" else ""))
	if not ok: failures.append(what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("Title probe timed out"); quit(2))
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	while current_scene == null or current_scene.get("titled") != true: await process_frame
	var scene: Node = current_scene
	await create_timer(0.5).timeout
	_check(scene._menu.visible, "the title menu is up")
	_check(scene._has_world == false, "no world is open behind it")
	_check(scene.places == null, "the place is not loaded yet")
	_check(scene.title_recipe.has("family"), "a showcase world was chosen", scene.title_recipe.get("family",""))
	var shown: Array = scene._menu.buttons.filter(func(button: Button) -> bool: return button.visible).map(func(button: Button) -> String: return button.text)
	_check(shown.size() >= 3 and "Create a new world" in shown and "Quit" in shown, "the menu offers a new world", shown)
	_check(not ("Fidelity world" in shown or "Open diorama…" in shown or "Save a copy…" in shown), "the legacy entries are hidden", shown)
	var fresh: Button = scene._menu.buttons[2]
	fresh.pressed.emit()
	while not scene.places_ready or not scene.shell_ready: await process_frame
	await create_timer(0.5).timeout
	_check(not scene._menu.visible, "the menu closes on the pick")
	_check(scene._has_world, "a world is open")
	_check(scene.places.plain, "the pick opened the Genesis plain")
	_check(scene.hand_reach == null or scene.hand_reach.available(), "the hand is free once the world is open")
	scene.show_menu()
	_check(scene.hand_reach == null or not scene.hand_reach.available(), "the in-game main menu takes the hand's clicks")
	scene.close_menu()
	print("PASS" if failures.is_empty() else "FAILED: "+", ".join(failures))
	quit(1 if not failures.is_empty() else 0)
