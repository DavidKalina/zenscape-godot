extends SceneTree
## Exports a small vignette of the real gothic ruin kit (scripts/ruin_kit.gd)
## to glTF, so the plane concepts can be rendered beside the game's own
## stone (art/blender/plane/plane_render.py imports it). Headless, no window:
##
##   Godot --headless --path . --script art/blender/plane/ruin_export.gd -- OUT.glb
##
## The stone's colours are in the vertex colours (the kit colours face by
## face); the glTF carries them as COLOR_0.

const RuinKit = preload("res://scripts/ruin_kit.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/ruin_vignette.glb"
	var root := Node3D.new()
	root.name = "RuinVignette"
	# A rose gable in the middle, lancet walls either side of it, a pier and
	# an arch standing forward, a fallen pier and paving.
	var layout := [
		["rose_gable",3,Vector3(0.0,0.0,0.0),0.0],
		["lancet_wall",5,Vector3(-10.5,0.0,0.5),0.12],
		["lancet_wall",8,Vector3(10.5,0.0,0.5),-0.12],
		["arch",4,Vector3(-6.0,0.0,10.0),0.1],
		["pier",6,Vector3(6.0,0.0,9.0),0.0],
		["fallen_pier",2,Vector3(1.0,0.0,12.0),0.6],
		["floor_slabs",1,Vector3(0.0,0.0,6.0),0.0],
	]
	for item in layout:
		var builder := Callable(RuinKit,item[0])
		var piece: Node3D = builder.call(item[1],0.6)
		piece.position = item[2]
		piece.rotation.y = item[3]
		var body := piece.get_node_or_null("Body")
		if body: piece.remove_child(body)
		root.add_child(piece)
		var mesh := piece.get_node_or_null("Mesh") as MeshInstance3D
		if mesh: print("RUIN ",item[0]," ",mesh.get_aabb())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root,state)
	if err == OK: err = doc.write_to_filesystem(state,out)
	print("RUIN_EXPORT ",out," ",err," tris ",RuinKit.triangles(root))
	root.free()
	quit(0 if err == OK else 1)
