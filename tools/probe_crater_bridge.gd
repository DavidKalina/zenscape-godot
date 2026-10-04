extends SceneTree
## Headless probe: a footbridge dragged over a crater (the Crater's Pull
## profile, scripts/clay_tools/crater.gd) spans it rim to rim, high over the
## bowl, rather than settling on the floor or the inner walls inside it.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_crater_bridge.gd -- --modeless --no-title --no-rain-runoff
const Footbridge = preload("res://scripts/footbridge.gd")
const Crater = preload("res://scripts/clay_tools/crater.gd")

var scene: Node3D
var editor: NativeChunkEditor
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.land_settling or editor.refresh_pending > 0
		quiet = 0 if busy else quiet+1

## A crater of `radius` m and `depth` m round `c` on level ground at `base`,
## shaped as the Crater's Pull shapes one.
func crater(c: Vector2, radius: float, depth: float, base: float) -> void:
	var data := editor.data
	data.begin_stroke()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		var t := p.distance_to(c)/radius
		if t > 2.0: continue
		var bowl := 1.0-smoothstep(Crater.CRATER_FLOOR,Crater.CRATER_RIM_AT,t)
		var rim := 0.0
		if t > Crater.CRATER_FLOOR and t < Crater.CRATER_RIM_OUT: rim = pow(sin(PI*(t-Crater.CRATER_FLOOR)/(Crater.CRATER_RIM_OUT-Crater.CRATER_FLOOR)),2.0)
		data.heights[i] = base+depth*Crater.CRATER_RIM*rim-depth*bowl
	data.end_stroke()
	editor.force_refresh()
	await settled()

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("crater bridge probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-crater-bridge-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	scene.world_clock.running = false
	while editor.flow == null or not editor.flow.ready: await process_frame
	await settled()
	var c := Vector2(0.0,0.0)
	var base := height(c)
	for case: Vector2 in [Vector2(3.0,2.0),Vector2(4.0,3.0),Vector2(5.0,3.0),Vector2(6.0,4.0)]:
		var radius := case.x
		var depth := case.y
		await crater(c,radius,depth,base)
		var crest := radius*0.5*(Crater.CRATER_FLOOR+Crater.CRATER_RIM_OUT)
		var rim_y := height(c+Vector2(crest,0.0))
		print("crater r %.1f depth %.1f: floor %.2f, rim %.2f at %.2f m" % [radius,depth,height(c),rim_y,crest])
		# Drags a player might make: crest to crest, from just inside the
		# rims, from just outside them, and a little off the middle line.
		for drag: Array in [
				[Vector2(-crest,0.0),Vector2(crest,0.0),"crest to crest"],
				[Vector2(-crest+0.6,0.0),Vector2(crest-0.6,0.0),"just inside the rims"],
				[Vector2(-crest-0.8,0.0),Vector2(crest+0.8,0.0),"just outside the rims"],
				[Vector2(-crest,-1.0),Vector2(crest,0.5),"off the middle"]]:
			var found := Footbridge.plan(Footbridge.water(editor),drag[0],drag[1])
			var detail: String = str(found.get("reason",""))
			if found.ok:
				var a: Vector2 = found.a
				var b: Vector2 = found.b
				var mid_deck: float = lerpf(found.ya,found.yb,0.5)+Footbridge.lift(found.span,0.5)
				detail = "a %s (%.2f m out) b %s (%.2f m out), ends %.2f/%.2f, deck mid %.2f over floor %.2f" % [a,a.distance_to(c),b,b.distance_to(c),found.ya,found.yb,mid_deck,height(c)]
				check("r %.0f: %s: ends at or beyond the rims" % [radius,drag[2]],a.distance_to(c) >= crest-0.6 and b.distance_to(c) >= crest-0.6 and minf(found.ya,found.yb) >= rim_y-0.35,detail)
			else:
				check("r %.0f: %s: lays a bridge" % [radius,drag[2]],false,detail)
	# A crater lake: the bridge still hangs rim to rim over the water, not
	# bank to bank down inside the bowl.
	await crater(c,5.0,3.0,base)
	editor.flow.kernel.add_water(c,1.5,25.0)
	editor.flow.run(900)
	for i in range(5): await process_frame
	var crest := 5.0*0.5*(Crater.CRATER_FLOOR+Crater.CRATER_RIM_OUT)
	var water: float = editor.flow.depth_at(c)
	var lake := Footbridge.plan(Footbridge.water(editor),Vector2(-crest,0.0),Vector2(crest,0.0))
	check("the crater holds a lake",water > 0.5,water)
	check("over a crater lake the bridge hangs from rim to rim",lake.get("ok",false) and lake.get("gap",false) and (lake.a as Vector2).distance_to(c) >= crest-0.6 and (lake.b as Vector2).distance_to(c) >= crest-0.6,lake)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
