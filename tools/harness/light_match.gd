extends SceneTree
## Per-class display stats of stills over a light_split.gd mask
## (pixel-matched), for tools/light_split.py match.
##   godot -s tools/harness/light_match.gd -- --mask=M.png [--mask2=M2.png] A.png B.png ...
func _init() -> void:
	var mask_path := ""
	var mask2_path := ""
	var files: Array[String] = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mask="): mask_path = a.trim_prefix("--mask=")
		elif a.begins_with("--mask2="): mask2_path = a.trim_prefix("--mask2=")
		else: files.append(a)
	var mask := Image.load_from_file(mask_path)
	var W := mask.get_width()
	var H := mask.get_height()
	var names := {40:"haze",80:"grass",160:"rock",240:"tree"}
	var out := {}
	for f in files:
		var img := Image.load_from_file(f)
		img.resize(W,H,Image.INTERPOLATE_NEAREST)
		var acc := {}
		for y in H:
			for x in W:
				var m := mask.get_pixel(x,y)
				var cls: int = m.r8
				if not names.has(cls): continue
				var key: String = "haze_far" if cls == 40 else names[cls]+("_lit" if m.g8 > 200 else "_shade")
				if not acc.has(key): acc[key] = {"v":[],"s":[],"h":[],"r":0.0,"g":0.0,"b":0.0}
				var c := img.get_pixel(x,y)
				var a: Dictionary = acc[key]
				(a.v as Array).append(c.v)
				(a.s as Array).append(c.s)
				(a.h as Array).append(c.h)
				a.r += c.r
				a.g += c.g
				a.b += c.b
		var res := {}
		for key: String in acc:
			var a: Dictionary = acc[key]
			var n: int = (a.v as Array).size()
			if n < 40: continue
			for k in ["v","s","h"]: (a[k] as Array).sort()
			res[key] = {"n":n,"V":(a.v as Array)[n/2],"S":(a.s as Array)[n/2],"H":float((a.h as Array)[n/2])*360.0,"rgb":[a.r/n,a.g/n,a.b/n]}
		out[f] = res
	# --mask2: the other run's mask; how many classed pixels keep their
	# class (a run whose land or trees streamed in differently reads low).
	if mask2_path != "":
		var m2 := Image.load_from_file(mask2_path)
		var same := 0
		var seen := 0
		for y in H:
			for x in W:
				var a := mask.get_pixel(x,y).r8
				var b := m2.get_pixel(x,y).r8
				if a == 0 and b == 0: continue
				seen += 1
				if a == b: same += 1
		out["agree"] = float(same)/maxf(seen,1.0)
	print("CMP "+JSON.stringify(out))
	quit()
