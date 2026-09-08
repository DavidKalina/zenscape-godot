extends Node3D
## A self-contained art study: tall redwoods, filtered sunrise, rising ground mist.
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var mist_material: ShaderMaterial
var caption: Label
var paused := false
var atmosphere_enabled := true
var clock := 0.0
var yaw := 0.0
var pitch := 0.0
var distance := 17.0
var target := Vector3(0,3.0,-4)
var ready_for_capture := false
var rng := RandomNumberGenerator.new()
var tree_count := 0

func _ready() -> void:
	get_window().title = "ZenScape · Redwood morning"
	get_viewport().msaa_3d = Viewport.MSAA_4X
	rng.seed = 82031
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("627c70")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5b7ab")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_length = 65.0
	environment.volumetric_fog_anisotropy = 0.65
	environment.volumetric_fog_ambient_inject = 0.2
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffdfaa")
	sun.light_energy = 1.8
	sun.light_volumetric_fog_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65.0
	sun.shadow_bias = 0.035
	add_child(sun)
	sun.position = Vector3(10,18,-14)
	sun.look_at(Vector3(0,0,3))
	_ground()
	for iz in range(11):
		for ix in range(11):
			var x := (ix-5)*3.8+rng.randf_range(-1.1,1.1)
			var z := -24.0+iz*3.8+rng.randf_range(-1.0,1.0)
			# A narrow natural opening through the grove frames the light.
			if absf(x-1.0*sin(z*0.14))<1.9 and z>-16: continue
			if Vector2(x,z-12).length()<3.0: continue
			_tree(Vector3(x,_height(x,z),z),rng.randf_range(17,26),rng.randf_range(0.42,0.8))
	for i in range(220):
		var x := rng.randf_range(-20,20)
		var z := rng.randf_range(-24,16)
		if absf(x-sin(z*0.14))<1.6: continue
		_fern(Vector3(x,_height(x,z),z),rng.randf_range(0.45,0.95))
	for i in range(9):
		var x := rng.randf_range(-15,15)
		var z := rng.randf_range(-20,9)
		if absf(x)<2: continue
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.23
		log_mesh.bottom_radius = 0.32
		log_mesh.height = rng.randf_range(2,4)
		log_mesh.radial_segments = 8
		var log_node := _mesh(log_mesh,Color("57412d"))
		log_node.position = Vector3(x,_height(x,z)+0.26,z)
		log_node.rotation = Vector3(PI/2,rng.randf()*TAU,0)
	var fog := FogVolume.new()
	fog.size = Vector3(48,34,60)
	fog.position = Vector3(0,15,-5)
	mist_material = ShaderMaterial.new()
	mist_material.shader = preload("res://shaders/redwood_mist.gdshader")
	fog.material = mist_material
	add_child(fog)
	camera = Camera3D.new()
	camera.fov = 64.0
	camera.near = 0.08
	camera.far = 100.0
	add_child(camera)
	camera.current = true
	_update_camera()
	var ui := CanvasLayer.new()
	add_child(ui)
	caption = Label.new()
	caption.text = "Redwood morning   ·   drag to look   ·   scroll to move closer   ·   P pause   ·   M floor mist   ·   F8 atmosphere"
	caption.position = Vector2(24,20)
	caption.add_theme_font_size_override("font_size",14)
	ui.add_child(caption)
	ready_for_capture = true
	print("REDWOOD READY trees=",tree_count)

func _height(x: float,z: float) -> float:
	return 0.24*sin(x*0.31)*cos(z*0.25)+0.10*sin(z*0.65)

func _mesh(mesh: Mesh,color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.vertex_color_use_as_albedo = true
	node.material_override = mat
	add_child(node)
	return node

func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-30,22):
		for x in range(-25,25):
			var path := 1.0-smoothstep(0.8,2.4,absf(x-sin(z*0.14)))
			var color := Color("34422c").lerp(Color("665138"),path).darkened(rng.randf()*0.13)
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var px: float = x+corner.x
				var pz: float = z+corner.y
				st.set_color(color.srgb_to_linear())
				st.add_vertex(Vector3(px,_height(px,pz),pz))
	st.generate_normals()
	_mesh(st.commit(),Color.WHITE)

func _tree(origin: Vector3,height: float,radius: float) -> void:
	tree_count += 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean := Vector2(rng.randf_range(-0.45,0.45),rng.randf_range(-0.45,0.45))
	for ring in range(5):
		for side in range(9):
			var color := Color("79513a").lerp(Color("432f25"),rng.randf()*0.65)
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var h: float = (ring+corner.y)/5.0
				var angle: float = (side+corner.x)*TAU/9.0
				var r := radius*(1.0-h*0.77)*(1.0+0.65*exp(-h*18.0))
				st.set_color(color.srgb_to_linear())
				st.add_vertex(Vector3(cos(angle)*r+lean.x*h,height*h,sin(angle)*r+lean.y*h))
	st.generate_normals()
	_mesh(st.commit(),Color.WHITE).position = origin
	# High, irregular masses leave the immense lower trunks legible.
	for tier in range(5):
		var crown := CylinderMesh.new()
		crown.top_radius = 0.12
		crown.bottom_radius = radius*(3.2-tier*0.35)
		crown.height = height*(0.18-tier*0.012)
		crown.radial_segments = 7
		var node := _mesh(crown,Color("254831").lerp(Color("405b34"),rng.randf()))
		node.position = origin+Vector3(lean.x,height*(0.59+tier*0.075),lean.y)
		node.rotation.y = rng.randf()*TAU

func _fern(origin: Vector3,size: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in range(7):
		var angle := frond*TAU/7+rng.randf()*0.2
		var direction := Vector3(cos(angle),0,sin(angle))
		var crosswise := Vector3(-direction.z,0,direction.x)
		for segment in range(4):
			var a := float(segment)/4
			var b := float(segment+1)/4
			var center_a := direction*a*size+Vector3.UP*sin(a*PI*0.85)*size*0.6
			var center_b := direction*b*size+Vector3.UP*sin(b*PI*0.85)*size*0.6
			for p in [center_a-crosswise*(1-a)*size*0.10,center_b,center_a+crosswise*(1-a)*size*0.10]:
				st.set_color(Color("52723b").darkened(rng.randf()*0.18))
				st.add_vertex(p)
	st.generate_normals()
	var node := _mesh(st.commit(),Color.WHITE)
	node.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.position = origin

func _process(delta: float) -> void:
	if not paused: clock += delta
	mist_material.set_shader_parameter("mist_time",clock)

func _update_camera() -> void:
	camera.position = target+Vector3(sin(yaw)*distance, -0.55+pitch*distance, cos(yaw)*distance)
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x*0.003
		pitch = clampf(pitch+event.relative.y*0.002,-0.1,0.6)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(4,distance-0.7)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(24,distance+0.7)
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P: paused = not paused
		if event.keycode == KEY_M:
			var pockets: Variant = mist_material.get_shader_parameter("floor_pockets")
			mist_material.set_shader_parameter("floor_pockets",0.0 if pockets == null or float(pockets)>0.0 else 1.0)
		if event.keycode == KEY_F8:
			atmosphere_enabled = not atmosphere_enabled
			environment.volumetric_fog_enabled = atmosphere_enabled
		if event.keycode == KEY_ESCAPE: get_tree().quit()
