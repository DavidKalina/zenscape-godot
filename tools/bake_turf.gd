extends SceneTree
## Bakes the far lawn's grain texture from the game's own grass: the soft tuft
## (scripts/grass_tuft_mesh.gd) laid out as a periodic field and drawn from
## straight above with an orthographic camera, as if cut very short
## (docs/design/endless-flight/clean-look-handoff.md, round 8).
## Writes assets/textures/far_turf.png, RGBA 8 bit, seamless:
##   R  shade (greyscale, mean 0.5): blade colour, tips lighter, gaps dark
##   G  height of the blade surface (mean 0.5): for the micro shadows
##   B,A  the blade's lean direction on the ground, x and z as 0.5 + 0.5 v
##        (mipmaps average it to 0.5 = no lean, so far off the wind decides)
## Needs a window (a real renderer), one at a time:
##   python tools/godot.py --rendered --timeout 120 -s res://tools/bake_turf.gd
## Options after `--`: --size=1024 --cells=48 --tuft=5.0 --seed=5 --out=res://assets/textures/far_turf.png
## The tile spans cells x CELL metres in the bake; the shader sets the metres
## it is laid over the ground (grass_lawn_tiles).

const Tuft = preload("res://scripts/grass_tuft_mesh.gd")

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform int mode = 0;
uniform float hmax = 1.0;
uniform float flat_shade = 0.0;
varying float v_h;
varying float v_shade;
void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_h = w.y / hmax;
	v_shade = INSTANCE_CUSTOM.x;
}
vec3 to_lin(vec3 c) { return pow(c, vec3(2.2)); }
void fragment() {
	vec3 out_c;
	if (mode == 0) {
		// COLOR is the blade's linear colour, root dark to tip light.
		float l = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
		float shade = flat_shade > 0.0 ? flat_shade : clamp(l / 0.55 * v_shade, 0.0, 1.0);
		out_c = vec3(shade, clamp(v_h, 0.0, 1.0), 0.0);
	} else {
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		if (!FRONT_FACING) n = -n;
		if (n.y < 0.0) n = -n;
		// Blades climb outward: the up-facing normal's flat part points back.
		vec2 d = -n.xz;
		d = length(d) > 0.001 ? normalize(d) : vec2(0.0);
		out_c = vec3(0.5 + 0.5 * d.x, 0.5 + 0.5 * d.y, 0.0);
	}
	ALBEDO = to_lin(out_c);
}
"""

func _initialize() -> void:
	_run.call_deferred()

func _arg(key: String, d: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key): return a.get_slice("=", 1)
	return d

func _run() -> void:
	var size := int(_arg("size", "1024"))
	var cells := int(_arg("cells", "48"))
	var scale_k := float(_arg("tuft", "5.0"))
	var out_path := _arg("out", "res://assets/textures/far_turf.png")
	var cell := 64.0 / cells
	var span := cells * cell
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = span
	cam.near = 0.05
	cam.far = 100.0
	vp.add_child(cam)
	cam.global_position = Vector3(span * 0.5, 50.0, span * 0.5)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	# The tuft at the game's own colours, a little jittered per tuft.
	var root_c := Color("38663a").srgb_to_linear()
	var tip_c := Color("93c05f").srgb_to_linear()
	var mesh := Tuft.build(root_c, tip_c)
	var hmax := Tuft.HEIGHT.y * scale_k * 1.4
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("hmax", hmax)
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_arg("seed", "5"))
	# One random draw per cell (mod cells), so the border cells copy the far side.
	var draws := []
	for i in cells * cells:
		draws.append([rng.randf(), rng.randf(), rng.randf() * TAU, rng.randf_range(0.8, 1.25), rng.randf_range(0.82, 1.16)])
	var span_n := cells + 4
	mm.instance_count = span_n * span_n
	var n := 0
	for j in range(-2, cells + 2):
		for i in range(-2, cells + 2):
			var dr: Array = draws[posmod(j, cells) * cells + posmod(i, cells)]
			var at := Vector3((i + 0.15 + 0.7 * dr[0]) * cell, 0.0, (j + 0.15 + 0.7 * dr[1]) * cell)
			var s: float = scale_k * dr[3]
			var b := Basis(Vector3.UP, dr[2]).scaled(Vector3(s, s * rng_h(dr[4]), s))
			mm.set_instance_transform(n, Transform3D(b, at))
			mm.set_instance_custom_data(n, Color(dr[4], 0, 0, 0))
			n += 1
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	vp.add_child(inst)
	# The ground between the blades: dark, low.
	var ground := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(span * 3.0, span * 3.0)
	ground.mesh = quad
	var gmat := ShaderMaterial.new()
	gmat.shader = sh
	gmat.set_shader_parameter("flat_shade", 0.22)
	gmat.set_shader_parameter("hmax", hmax)
	ground.material_override = gmat
	ground.position = Vector3(span * 0.5, -0.001, span * 0.5)
	vp.add_child(ground)
	var pass_a := await _grab(vp, [mat, gmat], 0)
	var pass_b := await _grab(vp, [mat, gmat], 1)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var sum_r := 0.0
	var sum_g := 0.0
	for y in size:
		for x in size:
			var a := pass_a.get_pixel(x, y)
			var d := pass_b.get_pixel(x, y)
			sum_r += a.r
			sum_g += a.g
	var mean_r := sum_r / (size * size)
	var mean_g := sum_g / (size * size)
	for y in size:
		for x in size:
			var a := pass_a.get_pixel(x, y)
			var d := pass_b.get_pixel(x, y)
			# Mean 0.5 on shade and height; the ground carries no direction.
			var r := clampf(a.r * 0.5 / mean_r, 0.0, 1.0)
			var g := clampf(a.g * 0.5 / mean_g, 0.0, 1.0)
			var dx := d.r if a.g > 0.004 else 0.5
			var dy := d.g if a.g > 0.004 else 0.5
			img.set_pixel(x, y, Color(r, g, dx, dy))
	var err := img.save_png(out_path)
	# --preview=DIR: each channel as grey, to look at (a 512 crop).
	var prev := _arg("preview", "")
	if prev != "":
		var names := ["r", "g", "b", "a"]
		for c in 4:
			var grey := Image.create(512, 512, false, Image.FORMAT_L8)
			for y in 512:
				for x in 512:
					grey.set_pixel(x, y, Color(img.get_pixel(x, y)[c], 0, 0))
			grey.save_png("%s/turf_%s.png" % [prev, names[c]])
	print("BAKE %s %dx%d mean_r %.3f mean_g %.3f hmax %.2f err %d" % [out_path, size, size, mean_r, mean_g, hmax, err])
	quit(0 if err == OK else 1)

func rng_h(v: float) -> float:
	return 0.9 + 0.2 * (v - 0.82) / 0.34

func _grab(vp: SubViewport, mats: Array, mode: int) -> Image:
	for m: ShaderMaterial in mats: m.set_shader_parameter("mode", mode)
	if mode == 1:
		# The ground carries no direction: flat colour 0.5 in pass b.
		(mats[1] as ShaderMaterial).set_shader_parameter("flat_shade", 0.5)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
