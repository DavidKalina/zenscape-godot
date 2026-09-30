extends SceneTree
## Headless layout and state checks for the 4c HUD bars (scripts/materials_tray.gd,
## scripts/tool_roll.gd): sizes at the reference frame, hit tests round trip,
## the bars wake near their edges and stay down while quiet.
## godot --headless --path . --script res://tools/probe_hud_bars.gd

const Tray = preload("res://scripts/materials_tray.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const Icons = preload("res://scripts/hud_icons.gd")
var failures := 0

func check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _init() -> void:
	await process_frame
	root.size = Vector2i(1440,900)
	await process_frame
	print("viewport ",root.get_visible_rect())
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var tray := Tray.new()
	var roll := Roll.new()
	layer.add_child(tray)
	layer.add_child(roll)
	tray.want(true)
	roll.want(true)
	tray.pointer_override = Vector2(720,400)
	roll.pointer_override = Vector2(720,400)
	for i in range(40): await process_frame
	check(tray.shown > 0.99 and roll.shown > 0.99,"both bars shown")
	check(tray.awake < 0.01 and roll.awake < 0.01,"at rest with the pointer over the plate")
	check(absf(tray.modulate.a-0.6) < 0.02,"rest opacity 0.6 (got %.2f)" % tray.modulate.a)
	var bar: Rect2 = tray._bar()
	print("bar ",bar," scale ",tray.ui_scale)
	check(absf(bar.size.x-678.0*tray.ui_scale) < 2.0,"bar is 678 design px wide")
	check(absf(bar.get_center().x-720.0) < 1.0,"bar centred")
	for entry: Dictionary in Tray.SPECIMENS:
		check(tray.specimen_at(tray.specimen_centre(entry.id)) == entry.id,"slot %s hit-tests to itself" % entry.id)
	check(not tray.discovered("crystal") and tray.discovered("stone"),"crystal hidden, stone found")
	# Reach for the bottom bar.
	tray.pointer_override = tray.specimen_centre("water")
	for i in range(30): await process_frame
	check(tray.awake > 0.99 and tray.hovered == "water","bottom bar reached, water hovered")
	# Quiet: a drag never wakes it.
	tray.pointer_override = Vector2(720,400)
	for i in range(80): await process_frame
	tray.quiet = true
	tray.pointer_override = Vector2(720,880)
	for i in range(30): await process_frame
	check(tray.awake < 0.01,"a drag near the bottom edge leaves it down")
	# The roll.
	var r: Rect2 = roll._roll()
	print("roll ",r)
	check(absf(r.size.x-80.0*roll.ui_scale) < 2.0,"roll 80 design px wide")
	for id: String in Roll.TOOLS:
		check(roll.tool_at(roll._cell(Roll.TOOLS.find(id)).get_center()) == id,"tool %s hit-tests to itself" % id)
	for i in range(3):
		check(roll.pip_at(roll._pip_cell(i).get_center()) == i,"pip %d hit-tests" % i)
	check(roll.discovered("hand") and roll.discovered("chisel") and roll.UNBUILT.all(func(t: String) -> bool: return not roll.discovered(t)),"hand and chisel built, the unbuilt not")
	roll.pointer_override = Vector2(40,450)
	for i in range(30): await process_frame
	check(roll.awake > 0.99,"roll comes out near the left edge")
	check(roll._tag_rect().size.x > 0.0,"hand tag shows")
	check(str(Icons.item("hand").get("label","")) == "Modeller · Mould","the first tool's tag reads Modeller · Mould")
	roll.material_held = true
	check(roll._tag_rect().size.x == 0.0,"no tool tag with a material held")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
