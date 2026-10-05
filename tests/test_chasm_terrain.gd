extends SceneTree
const Recipe = preload("res://scripts/chasm_glade.gd").RECIPE
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	var original := data.to_document()
	# Off the island is void before any chasm is cut.
	var island_void := data.void_faces.duplicate()
	# Older seeded recipes must retain their sampled values and draw order.
	var genome = preload("res://scripts/inland_genome.gd")
	for version in [3,4]:
		var legacy: Dictionary = genome.sample(37,{"composition":"valley"},version)
		var current: Dictionary = genome.sample(37,{"composition":"valley"},5)
		current.erase("chasm")
		current.version = version
		check(legacy == current,"Existing genome fields retain their exact RNG draws")
	preload("res://scripts/chasm_glade.gd").populate(data)
	check(data.ground_height(Vector2.ZERO)==null,"Gap contains no ground")
	data.undo()
	check(data.void_faces == island_void,"Undo restores continuous terrain")
	data.redo()
	check(data.is_void(Vector2.ZERO),"Redo restores the exact cut")
	check(data.ground_height(Vector2(-4,0))==0.0 and data.ground_height(Vector2(4,0))==0.0,"Both banks remain solid")
	check(data.ray_hit(Vector3(0,30,0),Vector3.DOWN)==null,"Picking sees through the void including the bottom")
	check(data.ray_hit(Vector3(-4,30,0),Vector3.DOWN)!=null,"Picking still hits a bank")
	var cut := data.play_mesh()
	check(cut.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0] == data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0],"Cut mesh preserves custom growth attributes")
	var faces := data.play_collision_faces()
	var hits := 0
	for i in range(0,faces.size(),3):
		if Geometry3D.ray_intersects_triangle(Vector3(0,30,0),Vector3.DOWN,faces[i],faces[i+1],faces[i+2]) != null: hits+=1
	check(hits==0,"No collision floor spans the chasm")
	data.tunnels = [{"start":[-5.0,-1.0,0.0],"heading":0.0,"width":1.0,"height":1.0,"length":2.0,"sealed":false}]
	var bored := data.play_mesh()
	check(bored.get_surface_count()==2,"Boring into an indexed bank preserves its outer walls")
	check(data.ray_hit(Vector3(0,30,0),Vector3.DOWN)==null,"Boring into a bank cannot restore a floor across the gap")
	data.tunnels.clear()
	var copy = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	check(copy.ground_height(Vector2.ZERO)==null,"Worker height snapshots preserve voids")
	# The cut follows the plate's faces: at z 0 it runs from x -0.6 to 1.8.
	var log_id := data.place("log",Vector2(0.6,0),0,4.0,NativeObjectPose.make(Basis.from_scale(Vector3(4,0.8,4)),-0.07))
	check(log_id>0,"A bridge may be authored with its center over a gap")
	check(data.place("tree",Vector2.ZERO)<0,"Ordinary props cannot be planted in empty space")
	var habitat = preload("res://scripts/fidelity_habitat.gd").new()
	habitat.native_data = data
	var catalog := NativePlayCollisions.new()
	catalog._load_bounds()
	var pose := Transform3D(Basis.from_scale(Vector3(4,0.8,4)),Vector3(0.6,-0.07,0))
	habitat.walkways.add(log_id,pose,pose*catalog._bounds.log,data.ground_height)
	check(not habitat.walkways.at(Vector2.ZERO).is_empty(),"A log can rest on the two actual banks")
	check(habitat.navigation_height(Vector2.ZERO)!=null,"Log provides navigation support above missing terrain")
	var nav := CreatureNavigation.new()
	nav.rebuild(habitat,habitat.clear_at,0.35,0.3)
	check(not nav.path(Vector3(-4,0,0),Vector3(4,0,0)).is_empty(),"Bigfoot can route across real log triangles")
	habitat.walkways.surfaces.clear()
	nav.rebuild(habitat,habitat.clear_at,0.35,0.3)
	check(nav.path(Vector3(-4,0,0),Vector3(4,0,0)).is_empty(),"No path crosses an unsupported chasm")
	check(data.pond_surface({"x":-4.0,"z":0.0,"level":0.3}).is_empty(),"Ponds spilling into a chasm cannot form a floating water floor")
	var document: Dictionary = JSON.parse_string(JSON.stringify(data.to_document(),"",true,true))
	check(data.load_document(document),"Chasm and centered log roundtrip")
	check(data.ground_height(Vector2.ZERO)==null,"Saving does not fill the gap")
	check(data.load_document(original),"A normal world can load while a chasm is open")
	check(data.void_faces == island_void and data.ground_height(Vector2.ZERO)!=null,"Normal-world load restores all ground")
	check(copy.ground_height(Vector2.ZERO)==null,"Earlier worker snapshots remain isolated")
	var old := Recipe.duplicate(); old.version = 4
	check(not NativeTerrainRecipe.valid(old),"Old recipe versions cannot claim chasm topology")
	await preload("res://scripts/inland_landscape.gd").new().form(data,Recipe)
	check(data.ground_height(Vector2.ZERO)==null,"Full genome generation also cuts the void")
	for item in data.objects:
		check(data.ground_height(Vector2(item.x,item.z))!=null,"Generated plants stay on a bank")
	catalog.free()
	print("CHASM TERRAIN failures=",failures)
	quit(1 if failures else 0)
