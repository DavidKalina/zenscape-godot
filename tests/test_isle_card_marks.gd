extends SceneTree
## The isle card's hairline, diamonds and sockets (scripts/isle_splash.gd
## `_draw_marks`) drawn at every stage of the fade in, for a card with finds
## like the isles' (studies/aqueduct_isle.gd, scripts/kit_isle/motif_*.gd),
## raise no "triangulation failed" error: the title diamond starts at zero
## size, and a polygon with no area is skipped rather than handed to the
## canvas. The runner (tools/run_tests.py) fails a test that logs an ERROR.
##   godot --headless --path . --script tests/test_isle_card_marks.gd
const IsleSplash = preload("res://scripts/isle_splash.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(60.0).timeout.connect(func() -> void: push_error("isle card marks test timed out"); quit(2))
	var splash := IsleSplash.new()
	root.add_child(splash)
	splash.show_card({"tag":"AN ISLE ADRIFT","name":"The Aqueduct of Veyl","epithet":"Water remembers the way",
		"finds":[["a","Lodestones",1,3],["b","Tokens",0,5],["c","Glyphs",2,2]]})
	var drawn := 0
	for step in range(40):
		splash.age = 0.0 if step == 0 else splash.IN*float(step)/30.0
		splash._layout(clampf(splash.age/splash.IN,0.0,1.0))
		splash._frame.get_node("Marks").queue_redraw()
		await process_frame
		drawn += 1
	check(drawn == 40,"The card's marks draw through the fade in")
	# The title diamond grows from nothing: at screen coordinates its first
	# frames are too small to triangulate, and the draw skips those (`_stud`).
	var tiny := 0
	var grown := 0
	for px in [1.0,1.5,2.0]:
		for i in range(0,2001):
			var d: float = 4.5*px*smoothstep(0.0,0.4,float(i)/2000.0*0.4)
			var empty := Geometry2D.triangulate_polygon(IsleSplash._diamond(Vector2(960.0*px,94.0*px),d)).is_empty()
			if empty: tiny += 1
			elif d >= 0.01*px: grown += 1
	check(tiny > 0 and grown > 0,"The diamond starts too small to triangulate (%d sizes) and grows into one (%d)" % [tiny,grown])
	check(not Geometry2D.triangulate_polygon(IsleSplash._octagon(Vector2(960,540),8.0)).is_empty(),"A socket's octagon triangulates")
	print("PASS: isle card marks" if failures == 0 else "FAIL: isle card marks (%d)" % failures)
	quit(1 if failures > 0 else 0)
