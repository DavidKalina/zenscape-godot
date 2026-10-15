extends "res://tools/harness/drive.gd"
## A contact sheet: PNGs side by side in a grid, each scaled to one width.
## Works headless (it only reads and writes images). tools/shot.py --sheet.
##   godot --headless --path . -s tools/harness/sheet.gd -- --in=a.png,b.png --out=sheet.png [--cols=2] [--width=720]

func drive() -> void:
	var files := String(arg("in","")).split(",",false)
	var out := String(arg("out","captures/shots/sheet.png"))
	check(make(Array(files),out,arg_int("cols",2),arg_int("width",720)) == OK,"sheet "+out,"%d images" % files.size())

## Writes the sheet of `paths` to `out`; an Error.
static func make(paths: Array, out: String, cols := 2, width := 720) -> Error:
	var images: Array[Image] = []
	for p: Variant in paths:
		var img := Image.load_from_file(ProjectSettings.globalize_path(String(p)))
		if img == null: continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(width,int(round(float(img.get_height())*width/img.get_width())),Image.INTERPOLATE_LANCZOS)
		images.append(img)
	if images.is_empty(): return ERR_FILE_NOT_FOUND
	cols = clampi(cols,1,images.size())
	var rows := ceili(float(images.size())/cols)
	var cell_h := 0
	for img in images: cell_h = maxi(cell_h,img.get_height())
	var gap := 4
	var sheet := Image.create_empty(cols*width+(cols-1)*gap,rows*cell_h+(rows-1)*gap,false,Image.FORMAT_RGB8)
	sheet.fill(Color(0.1,0.1,0.1))
	for i in images.size():
		var img := images[i]
		sheet.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i((i%cols)*(width+gap),(i/cols)*(cell_h+gap)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	return sheet.save_png(out)
