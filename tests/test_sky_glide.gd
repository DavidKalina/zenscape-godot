extends SceneTree
## The glide (scripts/sky_glide.gd) keeps its rules: off the edge it drops
## before it catches; it never stalls; a dive builds speed and pulling out
## swings it higher than a plain glide would; there is a float at the top of
## the arc; Rise always climbs; it turns easily and banks into turns; it
## skims along the ground instead of crashing; and a long fall is caught.
const SkyGlide = preload("res://scripts/sky_glide.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_drop()
	_never_stalls()
	_dive_and_swoop()
	_rise()
	_turns()
	_skim()
	_caught()
	print("PASS: sky glide" if failures == 0 else "FAIL: sky glide")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func air(_p: Vector3) -> Variant:
	return null

func fly(glide: SkyGlide, seconds: float, input: Dictionary, ground := Callable(self,"air")) -> void:
	for i in range(int(seconds/DT)): glide.step(DT,input,ground)

func launched() -> SkyGlide:
	var glide := SkyGlide.new()
	glide.launch(Vector3(0.0,10.0,0.0),0.0,1.6)
	return glide

func _drop() -> void:
	var glide := launched()
	fly(glide,0.6,{})
	var dropping := glide.velocity.y
	fly(glide,2.0,{})
	check(dropping < -4.0,"Off the edge it drops (%.1f m/s)" % dropping)
	check(glide.velocity.y > dropping+2.0,"Then the glide catches it (%.1f m/s)" % glide.velocity.y)

func _never_stalls() -> void:
	var glide := launched()
	var slowest := INF
	for i in range(int(8.0/DT)):
		glide.step(DT,{"pitch":1.0},air)
		slowest = minf(slowest,glide.speed)
	check(slowest >= SkyGlide.MIN-0.001,"Nose held up, it never drops under MIN (%.2f m/s)" % slowest)

func _dive_and_swoop() -> void:
	var glide := launched()
	fly(glide,3.0,{})
	var cruise := glide.speed
	fly(glide,3.0,{"dive":1.0})
	var dived := glide.speed
	check(dived > cruise*2.0,"A dive builds speed (%.1f to %.1f m/s)" % [cruise,dived])
	var bottom := glide.position.y
	var top := bottom
	var floated := 0.0
	for i in range(int(6.0/DT)):
		glide.step(DT,{"pitch":1.0} if glide.pitch < 0.7 else {},air)
		top = maxf(top,glide.position.y)
		floated = maxf(floated,glide.hang)
	check(top-bottom > 12.0,"Pulled out, it swings up a big arc (%.1f m)" % (top-bottom))
	check(floated > 0.4,"There is a float at the top (%.2f)" % floated)
	fly(glide,3.0,{})
	check(glide.pitch < 0.0,"Then the nose tips over (%.2f rad)" % glide.pitch)

func _rise() -> void:
	var glide := launched()
	fly(glide,2.0,{})
	var from := glide.position.y
	fly(glide,10.0,{"rise":1.0})
	check(glide.position.y-from > 15.0,"Rise climbs for as long as it is held (%.1f m in 10 s)" % (glide.position.y-from))
	var high := launched()
	high.position.y = SkyGlide.CEILING+SkyGlide.CEILING_FADE+20.0
	var start := high.position.y
	fly(high,4.0,{"rise":1.0})
	check(high.position.y <= start,"Above the ceiling Rise no longer climbs")

func _turns() -> void:
	var glide := launched()
	fly(glide,1.0,{})
	var from := glide.heading
	fly(glide,1.5,{"turn":1.0})
	check(absf(angle_difference(from,glide.heading)) > 2.0,"A held turn comes round fast (%.2f rad in 1.5 s)" % absf(angle_difference(from,glide.heading)))
	check(glide.bank > 0.3,"It banks into the turn (%.2f rad)" % glide.bank)
	fly(glide,2.0,{})
	check(absf(glide.bank) < 0.05,"Let go, it levels (%.2f rad)" % glide.bank)
	var mouse := launched()
	mouse.step(DT,{"look":Vector2(0.05,0.0)},air)
	check(mouse.heading < 0.0,"Mouse right turns right")

func flat(_p: Vector3) -> Variant:
	return 2.0

func _skim() -> void:
	var glide := launched()
	glide.position.y = 6.0
	var lowest := INF
	var skims := 0
	for i in range(int(5.0/DT)):
		glide.step(DT,{"dive":1.0},flat)
		lowest = minf(lowest,glide.position.y)
		if glide.skimming: skims += 1
	check(lowest >= 2.0+SkyGlide.SKIM-0.001,"Diving into the ground skims over it (lowest %.2f m)" % lowest)
	check(skims > 0 and glide.speed > SkyGlide.MIN,"It keeps going along it (%.1f m/s)" % glide.speed)
	glide.step(DT,{"rise":1.0},flat)
	fly(glide,2.0,{"rise":1.0},flat)
	check(glide.position.y > 2.0+SkyGlide.SKIM+1.0,"Rise lifts it off again")

func _caught() -> void:
	var glide := launched()
	var lowest := INF
	for i in range(int(90.0/DT)):
		glide.step(DT,{"dive":1.0},air)
		lowest = minf(lowest,glide.position.y)
	check(lowest > SkyGlide.FLOOR-60.0,"A long dive is caught under the floor (lowest %.1f m)" % lowest)
	fly(glide,20.0,{})
	check(glide.position.y > SkyGlide.FLOOR-25.0,"Let go, the cushion lifts it back towards the band (%.1f m)" % glide.position.y)
