extends SceneTree
## Render the actual catalog materials: trunks and crowns must both shrink,
## reach zero before terrain recedes, and return to their original silhouette.
const PARTS := ["trunk","canopy","broadleaf:mesh-11","broadleaf:broadleaf-canopies","layered_tree:layered-trunk","layered_tree:layered-canopies","redwood:redwood-trunk","redwood:redwood-canopies",
	"birch:birch-trunk","birch:birch-canopies","willow:willow-trunk","willow:willow-canopies","juniper:juniper-trunk","juniper:juniper-deadwood","juniper:juniper-canopies"]
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func silhouette(growth: float) -> int:
	RenderingServer.global_shader_parameter_set("zs_growth",Vector2(1,growth))
	await create_timer(.2).timeout
	RenderingServer.force_draw(false)
	var picture := root.get_texture().get_image()
	var background := picture.get_pixel(0,0)
	var count := 0
	for y in range(0,picture.get_height(),2):
		for x in range(0,picture.get_width(),2):
			var pixel := picture.get_pixel(x,y)
			if absf(pixel.r-background.r)+absf(pixel.g-background.g)+absf(pixel.b-background.b)>.05: count += 1
	return count
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Tree degrowth needs a GPU window")
		quit(2)
		return
	create_timer(90).timeout.connect(func() -> void: quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(800,800)
	var world := Node3D.new()
	root.add_child(world)
	var catalog := GardenView.new()
	world.add_child(catalog)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.2,.1,.3)
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	RenderingServer.global_shader_parameter_set("zs_wind_strength",0.0)
	RenderingServer.global_shader_parameter_set("zs_breeze", 0.0)
	await create_timer(.5).timeout
	for key: String in PARTS:
		var mesh := MeshInstance3D.new()
		mesh.mesh = catalog._meshes[key]
		mesh.material_override = catalog._materials[key]
		world.add_child(mesh)
		var box: AABB = mesh.mesh.get_aabb().expand(Vector3.ZERO)
		var center := box.get_center()
		camera.size = maxf(box.size.x,box.size.y)*1.5
		camera.position = center+Vector3(0,0,100)
		camera.look_at(center)
		check(mesh.material_override.get_shader_parameter("plant_growth")==true,key+" opts into the shared foliage timeline")
		var full := await silhouette(1.0)
		var shrinking := await silhouette(.035)
		var gone := await silhouette(0.0)
		var returned := await silhouette(1.0)
		print("TREE DEGROW ",key," pixels=",[full,shrinking,gone,returned])
		check(full>100,key+" is visible at full growth")
		check(shrinking>0 and shrinking<full*.6,key+" visibly shrinks before removal")
		check(gone<maxi(2,int(full*.001)),key+" reaches zero while terrain is still fully grown")
		check(abs(returned-full)<=maxi(2,int(full*.005)),key+" regrows to the original silhouette")
		mesh.free()
	world.queue_free()
	await process_frame
	print("Tree degrowth: ",failures," failures")
	quit(1 if failures else 0)
