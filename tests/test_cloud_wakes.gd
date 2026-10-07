extends SceneTree
## A plane's wake through a cloud (scripts/cloud_wakes.gd): flown through
## a cloud it lays a trail of tunnel points SPACING apart, each joined to
## the one before; nothing is laid in open air or crawling; the tunnel tears
## open, widens, holds and heals shut; inside, tufts are dragged along, and
## leaving, a burst is pulled out after the plane, flung on along its way,
## then slowed and gone; a full trail drops its oldest point; island swaps
## move it all; a tower is handed only the points near it; and the shaders'
## curve (shaders/cloud_wake.gdshaderinc) matches the script's. Headless:
## state and maths only, nothing drawn.
const CloudWakes = preload("res://scripts/cloud_wakes.gd")
var failures := 0

func _initialize() -> void:
	_lays_in_cloud_only()
	_heals()
	_tufts()
	_full_trail()
	_moves()
	_near_box()
	_shader_matches()
	print("PASS: cloud wakes" if failures == 0 else "FAIL: cloud wakes")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Flies `id` along +x at `speed` from x0 for `seconds`; the cloud is the
## stretch of x in `cloud` (depth 1 inside, 0 out).
func fly(w: Node3D, id: Variant, x0: float, speed: float, seconds: float, cloud: Vector2, time0 := 0.0) -> float:
	var dt := 1.0/60.0
	var t := 0.0
	while t < seconds:
		var x := x0+speed*t
		var depth := 1.0 if x > cloud.x and x < cloud.y else 0.0
		w.trace(id,Vector3(x,20.0,0.0),Vector3(speed,0.0,0.0),depth,time0+t,dt)
		w.advance(dt)
		t += dt
	return time0+t

func laid(w: Node3D) -> Array:
	var points := []
	for i in range(CloudWakes.COUNT):
		if w.way[i].w > 0.0: points.append(i)
	return points

func _lays_in_cloud_only() -> void:
	var w := CloudWakes.new()
	fly(w,0,0.0,14.0,1.0,Vector2(1000.0,2000.0))
	check(laid(w).is_empty(),"open air lays no tunnel")
	w.clear()
	var end := fly(w,0,0.0,14.0,4.0,Vector2(10.0,40.0))
	var points := laid(w)
	check(points.size() >= 6 and points.size() <= 9,"a 30 m cloud lays a point every %.1f m (%d)" % [CloudWakes.SPACING,points.size()])
	var inside := true
	for i in points: inside = inside and w.at[i].x >= 10.0 and w.at[i].x <= 40.0
	check(inside,"every point lies in the cloud")
	var joined := 0
	for i in points:
		if is_equal_approx(w.way[i].x,0.0): continue
		joined += 1
		check(absf(w.way[i].x-CloudWakes.SPACING) < 0.5 and absf(w.way[i].y) < 0.01,"each point steps back to the one before")
	check(joined == points.size()-1,"only the first point stands alone")
	check(w.open_count(end) == points.size(),"just laid, the whole tunnel is open")
	w.clear()
	fly(w,0,0.0,1.5,4.0,Vector2(-10.0,40.0))
	check(laid(w).is_empty(),"crawling through tears nothing")
	w.free()

func _heals() -> void:
	check(CloudWakes.strength(0.0) == 0.0,"a point opens from nothing")
	check(CloudWakes.strength(CloudWakes.OPEN) > 0.99,"torn open within %.2f s" % CloudWakes.OPEN)
	check(CloudWakes.strength(CloudWakes.HOLD) > 0.99,"held open till %.0f s" % CloudWakes.HOLD)
	check(CloudWakes.strength(CloudWakes.HOLD+CloudWakes.HEAL*0.5) < 0.6,"half healed partway")
	check(CloudWakes.strength(CloudWakes.LIFE) == 0.0,"healed shut at %.0f s" % CloudWakes.LIFE)
	check(CloudWakes.radius(CloudWakes.WIDEN_TIME) > CloudWakes.radius(CloudWakes.OPEN)*1.5,"widens behind the plane")
	check(CloudWakes.radius(CloudWakes.LIFE-1.0) < CloudWakes.radius(CloudWakes.HOLD)*0.5,"closes in as it heals")
	var w := CloudWakes.new()
	var end := fly(w,0,0.0,14.0,4.0,Vector2(10.0,40.0))
	check(w.open_count(end+CloudWakes.LIFE+1.0) == 0,"the cloud closes back in")
	w.free()

func _tufts() -> void:
	var w := CloudWakes.new()
	fly(w,0,0.0,14.0,1.9,Vector2(5.0,30.0))
	var inside := w.tufts.size()
	check(inside >= 3,"tufts dragged along inside (%d)" % inside)
	# Out the far side.
	var before := w.tufts.size()
	w.trace(0,Vector3(31.0,20.0,0.0),Vector3(14.0,0.0,0.0),0.0,3.0,1.0/60.0)
	var burst := w.tufts.size()-before
	check(burst >= CloudWakes.BURST-1,"leaving pulls a burst out (%d)" % burst)
	var ahead := 0
	for i in range(before,w.tufts.size()):
		if Vector3(w.tufts[i].velocity).x > 4.0: ahead += 1
	check(ahead == burst,"the burst is flung on after the plane")
	w.trace(0,Vector3(32.0,20.0,0.0),Vector3(14.0,0.0,0.0),0.0,3.1,1.0/60.0)
	check(w.tufts.size() == burst+before,"one exit, one burst")
	var fast: float = Vector3(w.tufts[-1].velocity).length()
	for i in range(60): w.advance(1.0/30.0)
	check(w.tufts.is_empty() or Vector3(w.tufts[-1].velocity).length() < fast*0.5,"the air's drag slows them")
	for i in range(int(CloudWakes.TUFT_LIFE.y*1.2*30.0)+30): w.advance(1.0/30.0)
	check(w.tufts.is_empty(),"and they fray to nothing")
	w.free()

func _full_trail() -> void:
	var w := CloudWakes.new()
	# Far longer than the trail holds.
	fly(w,0,0.0,14.0,20.0,Vector2(-1.0,1000.0))
	var points := laid(w)
	check(points.size() == CloudWakes.COUNT,"a long pass fills the trail")
	var oldest := INF
	for i in points: oldest = minf(oldest,w.at[i].x)
	check(oldest > 14.0*20.0-CloudWakes.COUNT*CloudWakes.SPACING-CloudWakes.SPACING*2.0,"a full trail drops its oldest points")
	w.free()

func _moves() -> void:
	var w := CloudWakes.new()
	fly(w,0,0.0,14.0,1.5,Vector2(-1.0,100.0))
	var first: Vector4 = w.at[laid(w)[0]]
	var tuft: Vector3 = w.tufts[0].position
	w.move(Vector3(100.0,0.0,-50.0))
	check(w.at[laid(w)[0]].is_equal_approx(first+Vector4(100.0,0.0,-50.0,0.0)),"a swap moves the tunnel, not its age")
	check(Vector3(w.tufts[0].position).is_equal_approx(tuft+Vector3(100.0,0.0,-50.0)),"and the tufts")
	w.free()

func _near_box() -> void:
	var w := CloudWakes.new()
	var end := fly(w,0,0.0,14.0,4.0,Vector2(10.0,40.0))
	var near: Array = w.near_box(Vector3(25.0,20.0,0.0),Vector3(30.0,30.0,30.0),end,8)
	check(int(near[2]) > 0 and (near[0] as PackedVector4Array).size() == 8,"a tower round the tunnel gets its points, padded to 8")
	var far: Array = w.near_box(Vector3(2000.0,20.0,0.0),Vector3(30.0,30.0,30.0),end,8)
	check(int(far[2]) == 0,"a tower far off gets none")
	w.free()

func _shader_matches() -> void:
	var text := FileAccess.get_file_as_string("res://shaders/cloud_wake.gdshaderinc")
	for pair in [["ZS_WAKE_OPEN",CloudWakes.OPEN],["ZS_WAKE_HOLD",CloudWakes.HOLD],["ZS_WAKE_LIFE",CloudWakes.LIFE],
			["ZS_WAKE_WIDEN",CloudWakes.WIDEN],["ZS_WAKE_WIDEN_TIME",CloudWakes.WIDEN_TIME]]:
		var re := RegEx.create_from_string("const float %s = ([0-9.]+);" % pair[0])
		var m := re.search(text)
		check(m != null and is_equal_approx(float(m.get_string(1)),float(pair[1])),"the shaders' %s matches the script" % pair[0])
