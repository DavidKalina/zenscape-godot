extends "res://tools/landscapes/harness.gd"
## Zen garden (karesansui): a level bed patted and palmed flat, three stones
## of rising size (a longer press sets a bigger stone), parallel raked lines
## drawn across the bed at the smallest pip, and a small pond in a corner.
## Tests: is the clay fine enough for raked lines; do stones set as intended.

const BED := Vector2(0.0,0.0)
const STONES := [[Vector2(-3.0,-1.5),1.6],[Vector2(-1.6,-0.6),0.6],[Vector2(3.2,1.8),1.0]]
const POND := Vector2(8.5,7.5)

func title() -> String: return "zen_garden"
func budget() -> float: return 900.0

var yaw0 := 0.0

func look(label: String, p: Vector2, distance: float, yaw_off: float, polar: float) -> void:
	await view(p,distance,yaw0+yaw_off,polar)
	await still(label)

func spread(points: Array) -> String:
	var lo := INF
	var hi := -INF
	for p: Vector2 in points:
		lo = minf(lo,height(p))
		hi = maxf(hi,height(p))
	return "%.2f..%.2f m (%.2f)" % [lo,hi,hi-lo]

func grid(c: Vector2, half: float, step: float) -> Array:
	var out := []
	var x := -half
	while x <= half+0.01:
		var z := -half
		while z <= half+0.01:
			out.append(c+Vector2(x,z))
			z += step
		x += step
	return out

func build() -> void:
	yaw0 = scene.yaw
	log_line("bed before: %s" % spread(grid(BED,6.0,0.5)))
	# Level the bed: paddle pats over it, then the palm across it.
	await take_tool("paddle")
	await size(3)
	for p: Vector2 in [Vector2(-4,-4),Vector2(0,-4),Vector2(4,-4),Vector2(-4,0),Vector2(0,0),Vector2(4,0),Vector2(-4,4),Vector2(0,4),Vector2(4,4)]:
		await tap(p)
	log_line("bed after pats: %s" % spread(grid(BED,6.0,0.5)))
	# Take 2: smooth with fast thumb rubs (take 1's palms each sank the bed
	# 0.4 m and left it rougher, 0.65 m spread, than the pats alone).
	await take_tool("hand")
	await size(3)
	await drag([Vector2(-5,-4),Vector2(5,-4),Vector2(-5,-2),Vector2(5,-2),Vector2(-5,0),Vector2(5,0),Vector2(-5,2),Vector2(5,2),Vector2(-5,4),Vector2(5,4)],80.0)
	log_line("bed after rub: %s" % spread(grid(BED,6.0,0.5)))
	await overview()
	await still("bed")
	# Rake, west half: the paddle's narrow blade at the smallest pip (a trough
	# with a ridge either side is the nearest thing to a tine line), 1.5 m apart.
	await take_tool("paddle")
	await size(1)
	var z := -5.0
	while z <= 5.01:
		await drag([Vector2(-6.5,z),Vector2(-0.5,z)],3.0,true)
		z += 1.5
	# Rake, east half: the Modeller's thumb at the smallest pip, 2.5 m apart.
	await take_tool("hand")
	await size(1)
	z = -5.0
	while z <= 5.01:
		await drag([Vector2(0.5,z),Vector2(6.5,z)],3.0)
		z += 2.5
	for x in [-3.5,3.5]:
		var across: PackedStringArray = []
		var q := -5.0
		while q <= 0.01:
			across.append("%.2f" % height(Vector2(x,q)))
			q += 0.25
		log_line("rake profile at x=%.1f, z -5..0 step .25: %s" % [x,", ".join(across)])
	measure_verbs()
	await look("raked",BED,22.0,0.0,0.8)
	# Stones: tap with a longer press for a bigger stone.
	for s: Array in STONES:
		await set_down("stone",[s[0]],s[1])
	log_line("stones set: %d" % materials.stones_set)
	for o: Dictionary in editor.data.objects:
		if o.asset == "rock": log_line("rock at (%.1f, %.1f) scale %s" % [o.x,o.z,o.get("scale",o.get("s","?"))])
	await overview()
	# A small pond: a narrow paddle hollow in the corner, and a burst of water.
	await take_tool("paddle")
	await size(1)
	await hold_to(POND,-0.6)
	await pour(POND,1.2)
	await put_down()
	await let_world_run(15.0)
	measure_water("pond",POND,3.0)
	measure_water("bed",BED,7.0)
	measure_life("plate")
	measure_life("bed",BED,7.0)
	await look("garden",BED,22.0,0.0,0.8)
	await look("garden-low",BED+Vector2(0,1),9.0,0.5,1.2)
	await look("rake-close",Vector2(1,-2),5.0,0.0,1.0)
	await overview()
	await still("overview")
