extends SceneTree
const Look = preload("res://scripts/scene_look.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Palette render test timed out"); quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	scene._celestial.set_phase(0.48)
	scene._precipitation.set_weather(0,true)
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.set_haze(0.0)
	scene._process(0)
	var look = scene._celestial.look
	var original: Dictionary = look.document()
	var baseline := await shot()
	for key in Look.SURFACES+["sky","ambient","fog"]:
		look.restore(original)
		if key == "fog": scene._atmosphere.set_fog(0.8)
		scene._process(0)
		var before := await shot()
		look.set_color(key,Color("ec3158"))
		scene._process(0)
		var after := await shot()
		var changed := difference(before,after)
		print("Rendered palette ",key," changed ",changed," sampled pixels")
		if changed < 12:
			failures += 1
			push_error("Palette channel does not reach visible scene: "+key)
	look.restore(original)
	scene._atmosphere.set_fog(0.0)
	scene._process(0)
	var reset := await shot()
	var residual := difference(baseline,reset)
	print("Reset residual pixels: ",residual)
	if residual > 20:
		failures += 1
		push_error("Reset does not return to the original rendered look")
	# A newly created diorama starts as bare soil; the Earth picker must affect its top too.
	scene._chunk_editor.start_flat()
	look.restore(original)
	scene._process(0)
	var earth_before := await shot()
	look.set_color("earth",Color("ec3158"))
	scene._process(0)
	var earth_after := await shot()
	var point: Vector2 = scene.camera.unproject_position(Vector3(0,0.6,0))
	# Camera projections are in GUI coordinates; framebuffer coordinates include Retina scaling.
	point = root.get_final_transform()*point
	var color_before := earth_before.get_pixelv(Vector2i(point))
	var color_after := earth_after.get_pixelv(Vector2i(point))
	if Vector3(color_before.r,color_before.g,color_before.b).distance_to(Vector3(color_after.r,color_after.g,color_after.b)) < 0.08:
		failures += 1
		push_error("Earth picker must recolor the bare ground, not only the cutaway sides")
	scene.free()
	print("SCENE LOOK RENDER: failures=",failures)
	quit(1 if failures else 0)
func shot() -> Image:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func difference(a: Image,b: Image) -> int:
	var changed := 0
	for y in range(0,a.get_height(),4):
		for x in range(0,a.get_width(),4):
			var delta := a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(delta.r)+absf(delta.g)+absf(delta.b)>0.045: changed += 1
	return changed
