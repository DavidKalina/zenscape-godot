extends SceneTree
## The dragon's downwash field (scripts/dragon_downwash.gd, docs/design/
## dragon-downwash/round1.md), headless, sampled at a flying dragon's size:
## down under him on the downstroke, weaker in the lull, a steady press
## gliding, up over him, nothing far off or when he isn't flying.
##   godot --headless --path . --script tests/test_dragon_downwash.gd
const DragonDownwash = preload("res://scripts/dragon_downwash.gd")
const SkyDragon = preload("res://scripts/sky_dragon.gd")

var failures := 0

func _initialize() -> void:
	var f := DragonDownwash.new()
	var at := Vector3(10.0,200.0,-30.0)
	var size := SkyDragon.SIZE
	var span := DragonDownwash.MODEL_SPAN*size
	var under := at+Vector3.DOWN*0.1*span
	var over := at+Vector3.UP*0.1*span
	# Beating, the downstroke's middle reaching that depth.
	var lag := 0.1*span*SkyDragon.BEAT/DragonDownwash.WASH_FALL
	f.update(0.016,true,at,0.0,size,0.25+lag,1.0,SkyDragon.BEAT,-INF,false)
	var stroke := f.air_at(under)
	check(stroke < -0.6*DragonDownwash.DOWN_PEAK,"under him on the downstroke the air comes down hard (%.1f m/s)" % stroke)
	# The lull: mid upstroke at that depth.
	f.update(0.016,true,at,0.0,size,0.75+lag,1.0,SkyDragon.BEAT,-INF,false)
	var lull := f.air_at(under)
	check(lull < 0.0 and lull > stroke*0.3,"in the lull it is much weaker (%.1f m/s against %.1f)" % [lull,stroke])
	# Gliding: steady, between the two.
	f.update(0.016,true,at,0.0,size,0.0,0.0,SkyDragon.BEAT,-INF,false)
	var glide := f.air_at(under)
	check(glide < lull and glide > stroke,"gliding, a steady press between them (%.1f m/s)" % glide)
	# Over him: up, the same beating or gliding.
	var up_glide := f.air_at(over)
	f.update(0.016,true,at,0.0,size,0.25,1.0,SkyDragon.BEAT,-INF,false)
	var up_beat := f.air_at(over)
	check(up_glide > 0.6*DragonDownwash.UP and is_equal_approx(up_glide,up_beat),"over him a steady updraft (%.1f m/s)" % up_beat)
	# Out past a wingtip, far under, far over: still.
	var right := Vector3(cos(0.0),0.0,-sin(0.0))
	var aside := f.air_at(at+right*0.6*span+Vector3.DOWN*0.1*span)
	var deep := f.air_at(at+Vector3.DOWN*span)
	var high := f.air_at(at+Vector3.UP*span)
	var far := f.air_at(at+Vector3(400.0,-20.0,300.0))
	check(absf(aside) < 0.01 and absf(deep) < 0.01 and absf(high) < 0.01 and absf(far) < 0.01,"nothing far off (aside %.2f, deep %.2f, high %.2f, far %.2f)" % [aside,deep,high,far])
	# Sized from him: a smaller dragon's field is smaller.
	f.update(0.016,true,at,0.0,size*0.5,0.25+lag,1.0,SkyDragon.BEAT,-INF,false)
	check(absf(f.air_at(at+right*0.3*span+Vector3.DOWN*0.1*span)) < 0.01,"a half-size dragon's wash ends nearer him")
	# Not flying: no air.
	f.update(0.016,false,at,0.0,size,0.25+lag,1.0,SkyDragon.BEAT,-INF,false)
	check(f.air_at(under) == 0.0 and f.plane_air(under,Vector3.FORWARD).is_empty(),"not flying, no air at all")
	print("PASS: dragon downwash" if failures == 0 else "FAIL: dragon downwash (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)
