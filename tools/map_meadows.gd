extends SceneTree
## Headless top-down maps of the meadow types (docs/scenic/meadows.md): each
## habitat's ground, water, the meadow's painted ground, and every record as
## a dot (flowers in their colour), to judge the drifts' composition without
## a renderer. Saves captures/meadows/map-<type>-<seed>.png, 16 px a metre.
##   godot --headless --path . -s res://tools/map_meadows.gd -- [--types=sunflower,cosmos] [--seed=2081]
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const OUT := "res://captures/meadows"
const PX := 16.0
const HABITATS := {"meadow":Color("9fbe5c"),"woodland":Color("4f7d4a"),"alpine":Color("9a978c"),"wetland":Color("6f9c86"),"redwood":Color("3f5f3a"),"arid":Color("c2a678")}
const KINDS := {"daisy_flower":Color("f6f2e4"),"button_flower":Color("f2c53d"),"spike_flower":Color("8f7ad6"),"umbel_flower":Color("f4f2ea")}
const TREES := ["tree","broadleaf","birch","willow","juniper","layered_tree","redwood"]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var types: Array = MeadowTypes.ORDER.duplicate()
	var seed_value := 2081
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--types="): types = Array(arg.trim_prefix("--types=").split(","))
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(reference.get_node("terrain").mesh)
	reference.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for type_id: String in types:
		var land = preload("res://scripts/inland_landscape.gd").new()
		await land.form(data,MeadowTypes.recipe(type_id,seed_value))
		var side := int(28.0*PX)
		var image := Image.create(side,side,false,Image.FORMAT_RGB8)
		for y in range(side):
			for x in range(side):
				var p := Vector2(x,y)/PX-Vector2(14,14)
				var h: Variant = data.ground_height(p)
				var colour: Color = Color("2b2b2b") if h == null else Color("5d8fb5") if land._is_wet(p) else HABITATS.get(land._habitat(p),Color.MAGENTA)
				if h != null:
					var cell := clampi(int((p.y+14.0)/data.MEADOW_STEP),0,data.MEADOW_CELLS-1)*data.MEADOW_CELLS+clampi(int((p.x+14.0)/data.MEADOW_STEP),0,data.MEADOW_CELLS-1)
					colour = NativeTerrainTint.blend(colour.srgb_to_linear(),data.tint,cell,0.0).linear_to_srgb()
					colour = colour.darkened(clampf(-(float(h)-1.5)*0.04,-0.25,0.25))
				image.set_pixel(x,y,colour)
		for item: Dictionary in data.objects:
			var at := (Vector2(item.x,item.z)+Vector2(14,14))*PX
			var colour: Color = Color("2f4f2a") if item.asset in TREES else Color("5f7a3a") if item.asset == "grass_tuft" else Color("777777") if item.asset == "rock" or str(item.asset).begins_with("boulder") else KINDS.get(item.asset,Color("405040"))
			if item.has("tint") and not item.asset == "grass_tuft": colour = NativeObjectPose.decode_tint(item.tint).linear_to_srgb()
			var radius := 3 if item.asset in TREES else 1
			for dy in range(-radius,radius+1):
				for dx in range(-radius,radius+1):
					var q := Vector2i(at)+Vector2i(dx,dy)
					if q.x >= 0 and q.y >= 0 and q.x < side and q.y < side and dx*dx+dy*dy <= radius*radius+1: image.set_pixelv(q,colour)
		var path := "%s/map-%s-%d.png" % [ProjectSettings.globalize_path(OUT),type_id,seed_value]
		image.save_png(path)
		var flowers := data.objects.filter(func(item: Dictionary) -> bool: return item.asset in KINDS).size()
		print("MAP %s %s  records %d flowers %d" % [type_id,path,data.objects.size(),flowers])
	quit()
