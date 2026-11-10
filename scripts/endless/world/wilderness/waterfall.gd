extends RefCounted
## The wilderness's skin of the curtain kind (scripts/endless/kinds/
## curtain.gd): a waterfall. The water is the fall study's marched plume
## (shaders/waterfall_volume.gdshader, studies/waterfall_study.tscn): a box
## fitted to the sheet (its lip at the stream's end, its foot on the plunge
## pool, its wall the alcove's face leaning back), the plume thrown out
## from the face so the cave mouth is behind it, its spray and the cloud at
## its foot; the study's pool foam (shaders/waterfall_pool.gdshader) on a
## plane just over the pool's water (the ground shader draws the water).
## Both take the world's light (the key light and the sky fill). Punched
## through (`punch`): a burst of spray, the screen doused and a splash; its
## voice (`voice`) a roar.

const BodyDust = preload("res://scripts/breaks/body_dust.gd")
const Land = preload("res://scripts/endless/kinds/curtain_land.gd")

## The fall (the volume shader's frame: x across, y up from the pool's water,
## z out from the face's top edge). FRONT: the water's front at the lip (m
## out from the face's top); THROW: how much further out it is at the foot;
## SPREAD: how much wider each side is at the foot; OVER_LIP: the water's top
## over the stream's water at the lip; ROCK_UNDER: the rock's top under it.
const FRONT := 4.0
const THROW := 3.0
const SPREAD := 3.0
const OVER_LIP := 0.15
const ROCK_UNDER := 1.0
## The box the fall is marched in: its back BOX_BACK m behind the face's top
## (in the rock, so the stream's water can come over), its depth out from
## there, its width and how far over the lip it reaches (m).
const BOX_BACK := -2.5
const BOX_DEPTH := 32.0
const BOX_HALF := 27.0
const BOX_OVER := 4.0
## The pool's foam: a plane FOAM_SIZE m (across, out) just FOAM_OVER m over
## the pool's water, from the face out.
const FOAM_SIZE := Vector2(56.0,30.0)
const FOAM_OVER := 0.06
## The lip in channels (the volume shader's): the main chute where the
## stream comes over (its last point, across the lip), CHUTE_WIDTH of the
## sheet's half-width; THREAD_GAPS of the lip with no thread beside it (bare
## rock); the chute's top LIP_NOTCH m under the threads' (the stream's water
## comes over at the lip, the threads a little over the rock). Each a param of
## the site's of the same name (lowercase); the lip's seed from its handle.
const CHUTE_WIDTH := 0.3
const THREAD_GAPS := 0.55
const LIP_NOTCH := 0.5
## The world's light on the fall and the foam (shaders: world_gain).
const LIGHT_GAIN := 1.15

## The punch (curtain_punch.gd calls `punch`): the screen doused WET at the
## sheet's middle (times the punch's k, less at its sides), a splash heard
## SPLASH_GAIN at SPLASH_PITCH, and a burst where the plane went through:
## DROPS drops thrown on along its way and PUFFS mist puffs (size, speed m/s,
## life s).
const WET := 0.8
const SPLASH_GAIN := 1.3
const SPLASH_PITCH := 0.75
const DROPS := {"amount":90,"size":0.5,"speed":Vector2(8.0,22.0),"life":1.1,"spread":38.0,"gravity":-9.8,"damp":1.5}
const PUFFS := {"amount":16,"size":5.0,"speed":Vector2(2.0,9.0),"life":2.2,"spread":70.0,"gravity":-1.0,"damp":2.5}
## The fall's voice (curtain_punch.gd): a band of noise pitched down to a
## roar, its gain at the foot.
const VOICE := {"clip":"res://assets/audio/water-bed.wav","gain":0.9,"pitch":0.55}

static var _blob: Texture2D = null

## The fall's voice, for curtain_punch.gd.
static func voice() -> Dictionary:
	return VOICE

## The plane punched through the sheet at `at` (world), flying `way` (m/s),
## `k` 1 through its middle (less at its sides): `root` the curtain's root,
## `game` the flight (its `wet`, `sound`).
static func punch(root: Node3D, at: Vector3, way: Vector3, k: float, game: Node) -> void:
	if game != null:
		game.wet(WET*k)
		var sound: Variant = game.get("sound")
		if sound != null: sound.shot("splash",SPLASH_GAIN*k,SPLASH_PITCH,at)
	var burst := root.get_node_or_null("PunchBurst") as Node3D
	if burst == null:
		burst = Node3D.new()
		burst.name = "PunchBurst"
		root.add_child(burst)
		burst.add_child(_emitter(DROPS,Color(0.9,0.95,0.98,0.95),false))
		burst.add_child(_emitter(PUFFS,Color(0.92,0.95,0.97,0.55),true))
	var dir := way.normalized() if way.length() > 1.0 else Vector3.UP
	for e: CPUParticles3D in burst.get_children():
		e.global_position = at
		# Drops carried on through with the plane, mist hanging back.
		e.direction = (dir+Vector3.UP*0.25).normalized() if e.name == "Drops" else (dir*0.4+Vector3.UP).normalized()
		e.restart()
		e.emitting = true

static func _emitter(k: Dictionary, color: Color, mist: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Puffs" if mist else "Drops"
	p.one_shot = true
	p.emitting = false
	p.amount = int(k.amount)
	p.lifetime = float(k.life)
	p.explosiveness = 0.95
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.5 if mist else 1.5
	p.spread = float(k.spread)
	p.initial_velocity_min = (k.speed as Vector2).x
	p.initial_velocity_max = (k.speed as Vector2).y
	p.gravity = Vector3(0.0,float(k.gravity),0.0)
	p.damping_min = float(k.damp)
	p.damping_max = float(k.damp)*1.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4 if not mist else 1.8
	p.angle_max = 360.0
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,1))
	fade.set_color(1,Color(1,1,1,0))
	p.color_ramp = fade
	p.color = color
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*float(k.size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _blob == null: _blob = BodyDust._blob_texture()
	m.albedo_texture = _blob
	# Faded out near the eye, so the camera flying through isn't filled with it.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.5 if not mist else 3.0
	m.distance_fade_max_distance = 5.0 if not mist else 12.0
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Dresses curtain `root` for `sheet` (curtain.gd `sheet_of`).
static func dress(root: Node3D, sheet: Dictionary, site: Dictionary) -> void:
	var lip: Vector3 = sheet.lip
	var out: Vector3 = (sheet.out as Vector3).normalized()
	var pool: Vector3 = sheet.pool
	var drop := float(sheet.drop)
	var half := float(sheet.half)
	# The fall's frame: its origin under the lip's middle on the pool's water,
	# +z out from the face, +x across (to the left looking at it).
	var fall_basis := Basis(Vector3.UP.cross(out).normalized(),Vector3.UP,out)
	var origin := Vector3(lip.x,pool.y,lip.z)
	var box := Vector3(BOX_HALF*2.0,drop+BOX_OVER,BOX_DEPTH)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/waterfall_volume.gdshader")
	m.set_shader_parameter("box_size",box)
	m.set_shader_parameter("box_z0",BOX_BACK)
	m.set_shader_parameter("lip_y",drop+OVER_LIP)
	m.set_shader_parameter("wall_top",drop-ROCK_UNDER)
	# The face runs from its top edge down to the alcove's floor over WALL m.
	m.set_shader_parameter("wall_lean",Land.WALL)
	m.set_shader_parameter("front_z",FRONT)
	m.set_shader_parameter("half_width",half)
	m.set_shader_parameter("spread",SPREAD)
	m.set_shader_parameter("throw_out",THROW)
	m.set_shader_parameter("world_light",1.0)
	m.set_shader_parameter("world_gain",LIGHT_GAIN)
	# The chute under the stream's end (site s is the fall's -x).
	var p: Dictionary = site.get("params",{})
	var stream: Array = p.get("stream",[])
	var lip_s := float((stream[stream.size()-1] as Array)[0]) if stream.size() >= 2 else 0.0
	m.set_shader_parameter("chute_x",clampf(-lip_s/maxf(half,0.1),-1.0,1.0))
	m.set_shader_parameter("chute_width",float(p.get("chute_width",CHUTE_WIDTH)))
	m.set_shader_parameter("thread_gaps",float(p.get("thread_gaps",THREAD_GAPS)))
	m.set_shader_parameter("lip_notch",float(p.get("lip_notch",LIP_NOTCH)))
	m.set_shader_parameter("lip_seed",float(p.get("lip_seed",float(hash(str(site.get("handle",""))) % 97))))
	# After the pool's foam (which writes no depth): the fall writes depth.
	m.render_priority = 1
	var bm := BoxMesh.new()
	bm.size = box
	var fall := MeshInstance3D.new()
	fall.name = "Fall"
	fall.mesh = bm
	fall.material_override = m
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fall.transform = Transform3D(fall_basis,origin+fall_basis*Vector3(0.0,box.y*0.5,BOX_BACK+box.z*0.5))
	fall.custom_aabb = AABB(-box*0.5,box)
	root.add_child(fall)
	# The pool's foam, in the fall's frame (a child of a node at its origin).
	var frame := Node3D.new()
	frame.name = "FallFrame"
	frame.transform = Transform3D(fall_basis,origin)
	root.add_child(frame)
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://shaders/waterfall_pool.gdshader")
	var at := Vector3(0.0,FOAM_OVER,FOAM_SIZE.y*0.5)
	pm.set_shader_parameter("in_fall",true)
	pm.set_shader_parameter("fall_offset",at)
	pm.set_shader_parameter("front_z",FRONT+THROW)
	pm.set_shader_parameter("half_width",half)
	pm.set_shader_parameter("spread",SPREAD)
	pm.set_shader_parameter("mound_reach",2.6)
	pm.set_shader_parameter("world_light",1.0)
	pm.set_shader_parameter("world_gain",LIGHT_GAIN)
	var pl := PlaneMesh.new()
	pl.size = FOAM_SIZE
	pl.material = pm
	var foam := MeshInstance3D.new()
	foam.name = "PoolFoam"
	foam.mesh = pl
	foam.position = at
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(foam)
