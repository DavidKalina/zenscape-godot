extends SceneTree
## Headless layout and state checks for the 4c HUD bars (scripts/materials_tray.gd,
## scripts/tool_roll.gd): sizes at the reference frame, hit tests round trip,
## the bars wake near their edges and stay down while quiet, and the case's
## groups fan out over their compartments.
## godot --headless --path . --script res://tools/probe_hud_bars.gd

const Linen = preload("res://scripts/hud_linen.gd")
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
	check(absf(tray.modulate.a-Linen.REST_OPACITY) < 0.02,"rest opacity %.2f (got %.2f)" % [Linen.REST_OPACITY,tray.modulate.a])
	var bar: Rect2 = tray._bar()
	print("bar ",bar," scale ",tray.ui_scale)
	check(absf(bar.size.x-349.0*tray.ui_scale) < 2.0,"bar is 349 design px wide (five compartments: trees, flowers & crops, water & stone, build and, set apart, the one not found yet)")
	check(absf(bar.get_center().x-720.0) < 1.0,"bar centred")
	check(tray.groups() == [0,3,4,1,2],"compartments in GROUPS order (%s)" % str(tray.groups()))
	check(tray.face(0) == "oak" and tray.face(3) == "wildflower" and tray.face(4) == "water" and tray.face(1) == "lamp" and tray.face(2) == "snow","each compartment shows its first specimen at the start")
	for entry: Dictionary in Tray.SPECIMENS:
		if tray.face(int(entry.group)) == entry.id:
			check(tray.specimen_at(tray.specimen_centre(entry.id)) == entry.id,"compartment %s hit-tests to itself" % entry.id)
	check(tray.open_group == -1 and tray.specimen_at(tray.specimen_centre("pine")) == "","with no fan out, pine's fan cell takes nothing")
	check(not tray.discovered("crystal") and tray.discovered("stone"),"crystal hidden, stone found")
	# Reach for the bottom bar: each group of several fans out over its
	# compartment, and its every specimen hit-tests on the fan.
	for group: int in tray.groups():
		var ids: Array = tray.members(group)
		tray.pointer_override = tray.compartment_centre(ids[0])
		for i in range(40): await process_frame
		if ids.size() == 1:
			check(tray.open_group == -1 and tray.hovered == ids[0],"group %d (%s) is one compartment, no fan" % [group,ids[0]])
			continue
		check(tray.awake > 0.99 and tray.open_group == group and tray.fan >= 1.0,"group %d fans out from its compartment" % group)
		var fan_rect: Rect2 = tray._fan_rect(group,1.0)
		check(fan_rect.end.y < tray._bar().position.y and fan_rect.position.x >= 0.0 and fan_rect.end.x <= 1440.0,"group %d's fan sits over the case, on screen (%s)" % [group,str(fan_rect)])
		for id: String in ids:
			var cell: Vector2 = tray._fan_cell(group,ids.find(id),1.0).get_center()
			check(tray.specimen_at(cell) == id and tray.contains_pointer(cell),"%s hit-tests on the fan" % id)
		# Along the fan to its far end it stays out.
		tray.pointer_override = tray._fan_cell(group,ids.size()-1,1.0).get_center()
		for i in range(20): await process_frame
		check(tray.open_group == group and tray.fan >= 1.0 and tray.hovered == ids.back(),"group %d stays out under the pointer on its fan" % group)
	# Taking from the fan: the compartment shows it, the fan folds until the
	# pointer leaves, and a press on the compartment re-takes it.
	tray.pointer_override = tray.compartment_centre("pine")
	for i in range(40): await process_frame
	check(tray.showing("pine") and tray.specimen_at(tray.specimen_centre("pine")) == "pine","pine's cell is out on the trees' fan")
	tray.lift_out("pine")
	check(tray.face(0) == "pine" and tray.specimen_at(tray.compartment_centre("pine")) == "pine","taken from the fan, pine shows on the trees' compartment")
	for i in range(30): await process_frame
	check(tray.fan == 0.0 and tray.open_group == -1,"the fan folds away after a take with the pointer still there")
	tray.return_home("pine")
	tray.pointer_override = Vector2(720,400)
	for i in range(80): await process_frame
	check(tray.fan == 0.0 and tray.face(0) == "pine","off the case the fan stays folded, pine still showing")
	tray.pointer_override = tray.specimen_centre("water")
	for i in range(30): await process_frame
	check(tray.awake > 0.99 and tray.hovered == "water","bottom bar reached, water hovered")
	tray.nudge("stone")
	check(tray.face(4) == "stone" and tray.specimen_at(tray.compartment_centre("stone")) == "stone","a nudge turns the compartment to the specimen pointed at")
	tray.nudge("")
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
