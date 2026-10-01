extends SceneTree
## Rasterises the palette's Life icons (scripts/hud_icons.gd `_life`) to PNGs
## for review: each at 34 px (the palette row) and 136 px, and a contact sheet
## of them beside a few existing icons at 34 px on the dark linen, each with
## its drop shadow as hud_linen.gd `icon` draws it.
##   Godot --headless --path . -s res://tools/render_life_icons.gd

const Icons = preload("res://scripts/hud_icons.gd")
const OUT := "/tmp/zs-critter-icons-review"
const LIFE := ["deer","heron","snake","bigfoot","bigfoot_stride","track","howl","woodpecker","geese","rainbow"]
const OLD := ["oak","pine","feather","hand","track","sun","moon"]
const LINEN := Color("62584a")
const SHADOW := Color(0.047,0.035,0.020,0.28)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for id: String in LIFE:
		for px: int in [34,136]: _raster(id,"icon",px).save_png("%s/%s_%d.png" % [OUT,id,px])
	for px: int in [34,68]:
		var cell := px+px/2
		var sheet := Image.create(cell*maxi(LIFE.size(),OLD.size())+px/2,cell*2+px/2,false,Image.FORMAT_RGBA8)
		sheet.fill(LINEN)
		for row in range(2):
			var ids: Array = LIFE if row == 0 else OLD
			for i in range(ids.size()):
				var at := Vector2i(px/2+i*cell,px/2+row*cell)
				var shade := _raster(ids[i],"shadow",px)
				for y in range(shade.get_height()):
					for x in range(shade.get_width()):
						var a := shade.get_pixel(x,y).a
						shade.set_pixel(x,y,Color(SHADOW,SHADOW.a*a))
				sheet.blend_rect(shade,Rect2i(Vector2i.ZERO,shade.get_size()),at+Vector2i(0,roundi(2.0*px/34.0)))
				var icon := _raster(ids[i],"icon",px)
				sheet.blend_rect(icon,Rect2i(Vector2i.ZERO,icon.get_size()),at)
		sheet.save_png("%s/contact_sheet_%d.png" % [OUT,px])
	print("Wrote %s" % OUT)
	quit()

func _raster(id: String, variant: String, px: int) -> Image:
	var image := Image.new()
	image.load_svg_from_string(Icons.svg(id,variant),px/24.0)
	image.convert(Image.FORMAT_RGBA8)
	return image
