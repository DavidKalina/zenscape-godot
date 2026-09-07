extends SceneTree
## Save the display fog's air march, resolved buffer (colour and alpha as grey)
## and the composited frame at 2560x1600, and print their mean RGBA, for parity
## work against the source's air target (tools/capture_electron_shot.mjs with a
## page script that rewrites the composite quad's fragment shader).
##
##   Godot --path . --rendering-method forward_plus --script res://tools/dump_air_buffer.gd \
##     -- --out=/tmp/air --paused --phase=0.35 --cam=43,1.13,1.8893,0,3,0 [--fog=.. --haze=..]
##
## --zero-sun / --zero-sky publish a black cloud sun or sky each frame to
## separate the two lighting terms.
var scene: Node3D
var frames := 0
var out := "/tmp/g2/air"

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2560, 1600))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	_start.call_deferred()

func _start() -> void:
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	process_frame.connect(_frame)

func _frame() -> void:
	frames += 1
	for a in OS.get_cmdline_user_args():
		if a == "--zero-sun": RenderingServer.global_shader_parameter_set("zs_cloud_sun", Vector3.ZERO)
		if a == "--zero-sky": RenderingServer.global_shader_parameter_set("zs_cloud_sky", Vector3.ZERO)
	if frames < 72: return
	process_frame.disconnect(_frame)
	await RenderingServer.frame_post_draw
	var fog = scene._display_fog
	var march: Image = fog.march.get_texture().get_image()
	var buffer: Image = fog.buffer.get_texture().get_image()
	var frame: Image = root.get_texture().get_image()
	print("AIR march %s format=%d mean=%s" % [str(march.get_size()), march.get_format(), str(_mean(march))])
	print("AIR buffer %s format=%d mean=%s" % [str(buffer.get_size()), buffer.get_format(), str(_mean(buffer))])
	print("AIR frame %s mean=%s" % [str(frame.get_size()), str(_mean(frame))])
	# A column through the mountain and the valley, as the composite sees it.
	for y in [300, 500, 700, 900, 1100]:
		var p := Vector2i(1200, y)
		var b := buffer.get_pixelv(p / 2)
		var m := march.get_pixelv(p / 4)
		print("AIR @%s march=(%.3f %.3f %.3f a=%.3f) buffer=(%.3f %.3f %.3f a=%.3f) frame=%s" % [str(p), m.r, m.g, m.b, m.a, b.r, b.g, b.b, b.a, str(frame.get_pixelv(p))])
	march.save_png(out + "-march.png")
	buffer.save_png(out + "-buffer.png")
	var alpha := Image.create(buffer.get_width(), buffer.get_height(), false, Image.FORMAT_RGB8)
	for y in range(buffer.get_height()):
		for x in range(buffer.get_width()):
			var a := buffer.get_pixel(x, y).a
			alpha.set_pixel(x, y, Color(a, a, a))
	alpha.save_png(out + "-alpha.png")
	frame.save_png(out + "-frame.png")
	quit()

func _mean(image: Image) -> Vector4:
	var sum := Vector4.ZERO
	var step := maxi(1, image.get_width() / 160)
	var count := 0
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var c := image.get_pixel(x, y)
			sum += Vector4(c.r, c.g, c.b, c.a)
			count += 1
	return sum / count
