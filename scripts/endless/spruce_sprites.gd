extends Node
## The endless spruces as sprites past the near crowns (scripts/endless/
## land_trees.gd): each variant of the real sprays spruce (its crown in its own
## painted material, its trunk) rendered once at start-up into an atlas, from
## `yaws` turns and ROWS heights of the eye (0, 30, 60 degrees up), its colour
## through the unshaded debug draw (the painted albedo, no light) and its light
## normal (the crown lit as a volume, as reference_surface) in a second pass.
## shaders/endless_spruce_sprite.gdshader stands each tree as a quad facing the
## eye, picks the cell by the eye's turn and height (dithered between) and
## lights it as the near crowns are lit, so the sun, the shade and the shadow
## still fall on it. Until the bake is done the sprites draw nothing.
##
## The atlas: one CELL px square a cell, `yaws` columns a variant, a row a
## height; every cell SIZE m across at the tree's scale 1, centred on the
## point `centre` m up the trunk (the same for every variant, so one quad
## size fits all). `mean` is the crowns' mean colour (linear), for the
## painted forest past the sprites.
##
## Soft (the default; --spruce-sprites=old the first look): SOFT_YAWS turns,
## and the shader blends the nearest views (not dithered between them, the
## grain) and smooths the outline by alpha to coverage over the screen's MSAA.

signal baked

const SHADER = preload("res://shaders/endless_spruce_sprite.gdshader")
const BAKE_NORMAL = preload("res://shaders/endless_spruce_sprite_bake.gdshader")
const CELL := 192
const OLD_YAWS := 4
const SOFT_YAWS := 8
const ROWS := 3
const ROW_STEP := PI/6.0
## The cell's margin round the tree's furthest point from its centre.
const PAD := 1.04
## The bake stands this far (m) from the main camera, past the crowns' near paint.
const BAKE_AWAY := 400.0

var materials: Array = []      # variant -> ShaderMaterial
var quad := QuadMesh.new()
var size := 1.0
var centre := 0.0
var mean := Color(0.08,0.12,0.09)
var done := false
var _parts: Array = []
var _tint := Color.WHITE
var _round := 0.7
var _albedo := ImageTexture.new()
var _normal := ImageTexture.new()
var soft := true
var yaws := SOFT_YAWS

static func soft_wanted() -> bool:
	return not ("--spruce-sprites=old" in preload("res://scripts/launch_args.gd").user_args())

## The materials (drawn while a tree's foot is `band` m off, dithered `fade`
## m round each end, each tree's ends moved by up to half `spread` m, as the
## crowns' lod_spread) and the cell's size from the variants' bounds.
func setup(parts: Array, tint: Color, knobs: Dictionary, band: Vector2, fade: Vector2, spread := 0.0) -> void:
	_parts = parts
	_tint = tint
	_round = float(knobs.get("round",0.7))
	soft = soft_wanted()
	yaws = SOFT_YAWS if soft else OLD_YAWS
	# One centre and size for all: the variants' tops and bottoms.
	var lo := INF
	var hi := -INF
	for p: Array in parts:
		for m: Mesh in p:
			var box := m.get_aabb()
			lo = minf(lo,box.position.y)
			hi = maxf(hi,box.end.y)
	centre = (lo+hi)*0.5
	var reach := 0.0
	for p: Array in parts:
		for m: Mesh in p:
			var box := m.get_aabb()
			for i in 8:
				var c := box.get_endpoint(i)
				reach = maxf(reach,Vector3(c.x,c.y-centre,c.z).length())
	size = reach*2.0*PAD
	var blank := Image.create(1,1,false,Image.FORMAT_RGBA8)
	_albedo.set_image(blank)
	_normal.set_image(blank)
	for v in parts.size():
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo_atlas",_albedo)
		m.set_shader_parameter("normal_atlas",_normal)
		m.set_shader_parameter("cells",Vector2(parts.size()*yaws,ROWS))
		m.set_shader_parameter("variant",v)
		m.set_shader_parameter("yaws",yaws)
		m.set_shader_parameter("soft",soft)
		m.set_shader_parameter("row_step",ROW_STEP)
		m.set_shader_parameter("cell_px",float(CELL))
		m.set_shader_parameter("fit",Vector3(centre,size,reach*0.35))
		m.set_shader_parameter("band",band)
		m.set_shader_parameter("fade",fade)
		m.set_shader_parameter("spread",spread)
		m.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
		m.set_shader_parameter("sun",Vector4(knobs.wrap,knobs.glow,knobs.steps,knobs.soft))
		m.set_shader_parameter("tone",Vector4(knobs.fill,knobs.warm,knobs.floor,knobs.hemiolive))
		m.set_shader_parameter("olive",knobs.olive)
		materials.append(m)

## Renders the atlas (a few frames) and hands it to the materials.
func bake() -> void:
	var cols := _parts.size()*yaws
	var vp := SubViewport.new()
	vp.size = Vector2i(cols*CELL,CELL)
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp.transparent_bg = true
	# No MSAA: its resolve mixes an edge's colour in linear light, which the
	# un-premultiplying (the shader's, for the byte-averaged mips) reads back
	# as a pale rim. The mips and the sprites' alpha to coverage soften it.
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = size
	cam.near = 0.05
	cam.far = 400.0
	vp.add_child(cam)
	add_child(vp)
	# The trees: a crown (its painted material, still) and a trunk a cell.
	var crowns: Array = []
	var trunks: Array = []
	var still: Array = []
	for v in _parts.size():
		var pair: Array = []
		for part in 2:
			var m: Material = (_parts[v][part] as Mesh).surface_get_material(0).duplicate()
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("sway_enabled",false)
				(m as ShaderMaterial).set_shader_parameter("conifer_sway",false)
			pair.append(m)
		still.append(pair)
	var normal_crown := ShaderMaterial.new()
	normal_crown.shader = BAKE_NORMAL
	normal_crown.set_shader_parameter("round",_round)
	var normal_trunk := ShaderMaterial.new()
	normal_trunk.shader = BAKE_NORMAL
	normal_trunk.set_shader_parameter("round",0.0)
	for v in _parts.size():
		for k in yaws:
			for part in 2:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.mesh = _parts[v][part]
				mm.instance_count = 1
				mm.set_instance_color(0,_tint if part == 1 else Color.WHITE)
				var mi := MultiMeshInstance3D.new()
				mi.multimesh = mm
				mi.set_meta("cell",Vector2i(v*yaws+k,k))
				vp.add_child(mi)
				(crowns if part == 1 else trunks).append(mi)
	var albedo := Image.create(cols*CELL,ROWS*CELL,false,Image.FORMAT_RGBA8)
	var normal := Image.create(cols*CELL,ROWS*CELL,false,Image.FORMAT_RGBA8)
	for row in ROWS:
		var e := row*ROW_STEP
		# Away from the main camera, past the near paint, each row afresh.
		var main := get_tree().root.get_camera_3d()
		var eye := main.global_position if main != null else Vector3.ZERO
		var w0 := eye+Vector3(BAKE_AWAY,0.0,BAKE_AWAY)
		var toward := Vector3(0.0,sin(e),cos(e))
		cam.global_position = w0+toward*150.0
		cam.look_at(w0,Vector3.UP if e < 1.4 else Vector3.FORWARD)
		var right := cam.global_basis.x
		for mi: MultiMeshInstance3D in crowns+trunks:
			var cell: Vector2i = mi.get_meta("cell")
			var at := w0+right*((cell.x+0.5)-cols*0.5)*size
			var b := Basis(Vector3.UP,cell.y*TAU/yaws)
			mi.multimesh.set_instance_transform(0,Transform3D(b,at-Vector3(0.0,centre,0.0)))
		for pass_i in 2:
			for v in _parts.size():
				for k in yaws:
					crowns[v*yaws+k].material_override = still[v][1] if pass_i == 0 else normal_crown
					trunks[v*yaws+k].material_override = still[v][0] if pass_i == 0 else normal_trunk
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			if not is_instance_valid(vp): return
			var img := vp.get_texture().get_image()
			if img == null or img.is_empty():
				vp.queue_free()
				return
			img.convert(Image.FORMAT_RGBA8)
			(albedo if pass_i == 0 else normal).blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i(0,row*CELL))
	vp.queue_free()
	# The crowns' mean (side row), its colour un-premultiplied by its cover.
	var side := albedo.get_region(Rect2i(0,0,cols*CELL,CELL))
	side.resize(1,1,Image.INTERPOLATE_TRILINEAR)
	var c := side.get_pixel(0,0)
	if c.a > 0.01: mean = Color(c.r/c.a,c.g/c.a,c.b/c.a).srgb_to_linear()
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	if "--spruce-sprite-dump" in preload("res://scripts/launch_args.gd").user_args():
		albedo.save_png("user://spruce_sprites_albedo.png")
		normal.save_png("user://spruce_sprites_normal.png")
	_albedo.set_image(albedo)
	_normal.set_image(normal)
	done = true
	baked.emit()
