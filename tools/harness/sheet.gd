extends "res://tools/harness/drive.gd"
## A contact sheet: PNGs side by side in a grid, each scaled to one width.
## Works headless (it only reads and writes images). tools/shot.py --sheet.
##   godot --headless --path . -s tools/harness/sheet.gd -- --in=a.png,b.png --out=sheet.png [--cols=2] [--width=720]

func drive() -> void:
	var files := String(arg("in","")).split(",",false)
	var out := String(arg("out","captures/shots/sheet.png"))
	check(make(Array(files),out,arg_int("cols",2),arg_int("width",720)) == OK,"sheet "+out,"%d images" % files.size())

## Writes the sheet of `paths` to `out`; an Error (drive.gd `make_sheet`).
static func make(paths: Array, out: String, cols := 2, width := 720) -> Error:
	return make_sheet(paths,out,cols,width)
