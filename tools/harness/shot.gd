extends "res://tools/harness/drive.gd"
## Rendered stills of a scene, for tools/shot.py: opened the way the game
## opens it, settled, shot from its own camera, an eye given, or framed on
## the nodes matching a pattern, from one or more views; then a contact
## sheet of them.
##   --scene=studies/x.tscn   --out=captures/shots/x (the file prefix)
##   --place=x,y,z[,yaw_deg]  the walker set down there first
##   --settle=150             frames before the first shot
##   --at=x,y,z --look=x,y,z  a fixed eye (a camera of the tool's own)
##   --frame=PATTERN          framed on what matches (name, class, script
##                            path; drive.gd `find`), or "walker", or "all"
##   --view=three,top,...     three (default), front, back, left, right,
##                            top, close: each a file <out>_<view>.png
##   --fov=50 --dist=1.0      the framing's lens and distance factor
##   --sheet                  also <out>_sheet.png, the views side by side
##   --hud                    keep the HUD in
##   --size=1440x900          the PNGs' size
## Without --at or --frame: the study's own camera, one <out>.png.
## The views and the framing are drive.gd's (VIEWS, view_eye, mesh_box), so
## a driver's shot_at frames the same way.

func drive() -> void:
	if DisplayServer.get_name() == "headless":
		check(false,"shot","headless has no pixels: run it with tools/shot.py (a window)")
		return
	await open(String(arg("scene","")))
	if study == null: return
	if _args.has("place") and motor != null:
		var p := String(arg("place")).split(",")
		var yaw := deg_to_rad(float(p[3])) if p.size() > 3 else 0.0
		await place(Vector3(float(p[0]),float(p[1]),float(p[2])),Vector2(sin(yaw),cos(yaw)))
	await frames(arg_int("settle",150))
	var out := String(arg("out","captures/shots/shot"))
	var saved: Array[String] = []
	if _args.has("at"):
		var cam := _camera()
		cam.look_at_from_position(arg_vec3("at"),arg_vec3("look"),Vector3.UP)
		await frames(2)
		saved.append(await _save(out+".png"))
	elif _args.has("frame"):
		var box := _box(String(arg("frame")))
		if box.size == Vector3.ZERO:
			check(false,"frame %s" % arg("frame"),"nothing matched with a mesh")
			return
		var cam := _camera()
		cam.fov = arg_float("fov",50.0)
		var middle := box.get_center()
		note("framed %s: middle %s, %.1f m across" % [arg("frame"),middle.round(),box.size.length()])
		for view: String in String(arg("view","three")).split(","):
			var at := view_eye(view if VIEWS.has(view) else "three",box,Vector3.BACK,box,cam.fov,arg_float("dist",1.0))
			cam.look_at_from_position(at.eye,at.look,Vector3.UP)
			cam.far = maxf(4000.0,(at.eye as Vector3).distance_to(at.look)*4.0)
			await frames(2)
			saved.append(await _save("%s_%s.png" % [out,view]))
	else:
		saved.append(await _save(out+".png"))
	saved = saved.filter(func(s: String) -> bool: return s != "")
	result("saved",saved)
	if flag("sheet") and saved.size() > 1:
		var sheet_path := out+"_sheet.png"
		check(make_sheet(saved,sheet_path) == OK,"sheet "+sheet_path)
	check(not saved.is_empty(),"shot saved","%d files" % saved.size())

func _camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "HarnessShotCamera"
	study.add_child(cam)
	cam.make_current()
	return cam

func _save(path: String) -> String:
	var size := String(arg("size","1440x900")).split("x")
	await shot(path,flag("hud"),Vector2i(int(size[0]),int(size[1])))
	return path if FileAccess.file_exists(path) else ""

## The world box of the meshes under what matches `pattern`.
func _box(pattern: String) -> AABB:
	if pattern == "all": return mesh_box([study])
	if pattern == "walker": return mesh_box([study.get("figure")])
	return mesh_box(find(pattern))
