extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var menu = load("res://scripts/title_screen.gd").new()
	viewport.add_child(menu)
	for title in ["Continue","New","Open","Save","Settings","Quit"]:
		menu.add_action(title,"Details" if title == "Continue" else "",func(): pass)
	for extent in [Vector2i(960,640),Vector2i(1440,900),Vector2i(3024,1964),Vector2i(3840,2160)]:
		viewport.size = extent
		await process_frame
		menu.present(false)
		check(menu._frame.scale == Vector2.ONE,"Menu rasterizes at its displayed size: " + str(extent))
		# The picks draw their own words at 19 design px times `px` (f887a787),
		# on a frame at least as tall as the card.
		var factor: float = minf(minf(extent.x/1180.0,extent.y/maxf(613.0,menu._card_rect.end.y+40.0)),1.75)
		check(is_equal_approx(menu.buttons[0].px,factor),"Text resolution follows layout size: " + str(extent))
		for button in menu.buttons:
			check(Rect2(Vector2.ZERO,Vector2(extent)).encloses(button.get_global_rect()),"Action stays inside the viewport")
	menu.buttons[0].disabled = true
	menu.present(false)
	check(not menu.buttons[0].visible and is_equal_approx(menu.buttons[1].px,1.75),"Hidden Continue promotes the next action without losing font resolution")
	menu.free()
	viewport.free()
	print("TITLE RESOLUTION failures=",failures)
	quit(failures)
