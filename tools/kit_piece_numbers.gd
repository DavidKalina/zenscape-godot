extends SceneTree
## The numbers that size a ruin-kit piece, read live from the code (so they
## never go stale): `python tools/kit_piece.py numbers`, or
##   python tools/godot.py -s tools/kit_piece_numbers.gd
## Each line: NUM <name> <value> <file>:<constant> [note]. Carries marked
## "est." are ballistic estimates from the motor's constants on level
## ground at run pace; the lanes measured them through the real motor
## (pump ~3.0 m level, twirled run-up ~4.1 m), so prove a gap by a drive.

func _row(name: String, value: Variant, source: String, note := "") -> void:
	var v := ("%.3f" % value) if value is float else str(value)
	print("NUM %-14s %-10s %s%s" % [name, v, source, ("  " + note) if note != "" else ""])

func _initialize() -> void:
	var M: Script = load("res://scripts/pilot_motor.gd")
	var G: Script = load("res://scripts/pilot_physics_ground.gd")
	var K: Script = load("res://scripts/ruin_kit.gd")
	var W: Script = load("res://scripts/world_scale.gd")
	var T: Script = load("res://scripts/ruin_kit_tower.gd")
	var S: Script = load("res://scripts/slam.gd")
	var P: Script = load("res://scripts/pocket_sail.gd")
	var m := M.get_script_constant_map()
	var k := K.get_script_constant_map()
	print("== reach (scripts/ruin_kit.gd Scale, from scripts/pilot_motor.gd)")
	for n in ["GRAB_TOP", "CHAIN_TOP", "SET_OFF", "STAND", "TOP_ROOM", "BODY", "RISER", "TREAD", "WALL_HEIGHT", "WALL_THICK", "WALL_LENGTH", "THREAD"]:
		if k.has(n): _row(n, k[n], "ruin_kit.gd:" + n)
		elif K.get(n) != null: _row(n, K.get(n), "ruin_kit.gd:" + n)
	print("== motor (scripts/pilot_motor.gd)")
	for n in ["STEP_UP", "CLIMB_IN", "HANG_DROP", "GRAB_LOW", "JUMPS", "GRAVITY", "RUN", "SLOPE_SLOW", "SLIDE_FROM", "SLIDE_AUTO", "SHIMMY_SLOPE", "WALL_KICK", "WALL_JUMP", "TWIRL_RISE", "LONG_SPEED", "LONG_HEIGHT", "LONG_GRAVITY"]:
		if m.has(n): _row(n, m[n], "pilot_motor.gd:" + n)
	_row("HEAD", G.get_script_constant_map().get("HEAD"), "pilot_physics_ground.gd:HEAD", "head room over the feet")
	_row("KICK_GAP", T.get("KICK_GAP"), "ruin_kit_tower.gd:KICK_GAP", "wall-kick chimney width")
	print("== carries (est.)")
	var g: float = m.GRAVITY
	var run: float = m.RUN
	var jumps: Array = m.JUMPS
	for i in jumps.size():
		var h: float = jumps[i]
		_row("carry_jump%d" % i, run * 2.0 * sqrt(2.0 * h / g), "JUMPS[%d] %.2f, RUN, GRAVITY" % [i, h], "est. level")
	var lg: float = m.LONG_GRAVITY
	var lh: float = m.LONG_HEIGHT
	_row("carry_long", float(m.LONG_SPEED) * 2.0 * sqrt(2.0 * lh / lg), "LONG_SPEED/HEIGHT/GRAVITY", "est. level")
	print("== slam (scripts/slam.gd)")
	var sm := S.get_script_constant_map()
	_row("SLAM_LOW", sm.get("LOW"), "slam.gd:LOW", "air under him to slam at all")
	if sm.has("DECENT"): _row("SLAM_DECENT", sm.get("DECENT"), "slam.gd:DECENT", "drop for Slam.decent()")
	_row("slam_decent", S.decent(), "slam.gd:decent()", "strength")
	print("== sail (scripts/pocket_sail.gd)")
	var pm := P.get_script_constant_map()
	_row("sail_glide", float(pm.PACE) / float(pm.SINK), "pocket_sail.gd:PACE/SINK", "m out per m down")
	_row("sail_glide_fast", float(pm.PACE_FAST) / float(pm.SINK_FAST), "pocket_sail.gd:PACE_FAST/SINK_FAST")
	print("== plane (scripts/world_scale.gd)")
	_row("span", W.get("span"), "world_scale.gd:span", "wingspan at --plane-scale")
	_row("SNUG", W.get_script_constant_map().get("SNUG"), "world_scale.gd:SNUG")
	_row("opening(3.5)", W.opening(3.5), "WorldScale.opening(TOY_THREAD)", "a flown thread")
	_row("gap(ROOM)", W.gap(), "WorldScale.gap()")
	_row("pilot_size", W.get("pilot_size"), "world_scale.gd:pilot_size")
	quit(0)
