extends SceneTree
## Rasterises every HUD icon (scripts/hud_icons.gd) in its icon, lit and
## locked forms onto one sheet at /tmp/zs-hud/icons.png, and checks the
## silhouette clip holds (the box's corners stay clear) and the facets vary.
## godot --headless --path . --script res://tools/probe_hud_icons.gd

const Icons = preload("res://scripts/hud_icons.gd")
const IDS := ["oak","pine","willow","wildflower","dandelion","reed","water","stone","crystal","snow","hand","paddle","chisel","wire","hammer"]

func _init() -> void:
	var px := 88.0
	var cell := int(px*Icons.BOX/24.0)
	var sheet := Image.create(cell*IDS.size(),cell*3,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("5d6873"))
	var failures := 0
	for i in range(IDS.size()):
		var row := 0
		for variant: String in ["icon","lit","locked"]:
			var tex := Icons.texture(IDS[i],variant,px)
			if tex == null:
				print("FAIL: no texture for %s %s" % [IDS[i],variant])
				failures += 1
				continue
			var image := tex.get_image()
			image.convert(Image.FORMAT_RGBA8)
			if variant == "locked":
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						var c := image.get_pixel(x,y)
						image.set_pixel(x,y,Color(Icons.LOCKED,c.a))
			sheet.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(i*cell,row*cell))
			if variant == "icon":
				if image.get_pixel(1,1).a > 0.01:
					print("FAIL: %s draws outside its silhouette" % IDS[i])
					failures += 1
				var seen := {}
				for y in range(0,image.get_height(),3):
					for x in range(0,image.get_width(),3):
						var c := image.get_pixel(x,y)
						if c.a > 0.99: seen[c.to_html(false)] = true
				if seen.size() < 4:
					print("FAIL: %s has %d facet colours" % [IDS[i],seen.size()])
					failures += 1
			row += 1
	sheet.save_png("/tmp/zs-hud/icons.png")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
