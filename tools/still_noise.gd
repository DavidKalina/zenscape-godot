extends SceneTree
## Pixel noise of a still over a patch of open ground (docs/scenic/grass-look.md):
## the mean |luma - its 9x9 local mean| as a share of full scale, over the
## rectangle x0,y0,x1,y1 (pixels; default a patch of open plain in the
## diorama stills' lower left), plus the patch's mean luma and the spread of
## its 33x33 block means (the broad light and shade). Headless:
##   Godot --headless --path . -s res://tools/still_noise.gd -- a.png [b.png ...] [--rect=x0,y0,x1,y1]

func _initialize() -> void:
	var rect := Rect2i(80,470,360,180)
	var files: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rect="):
			var v := arg.trim_prefix("--rect=").split(",")
			rect = Rect2i(int(v[0]),int(v[1]),int(v[2])-int(v[0]),int(v[3])-int(v[1]))
		else: files.append(arg)
	for path in files:
		var image := Image.load_from_file(path)
		if image == null:
			print("NOISE cannot read ",path)
			continue
		var w := image.get_width()
		var h := image.get_height()
		var luma := PackedFloat32Array()
		luma.resize(w*h)
		for y in range(h):
			for x in range(w):
				var c := image.get_pixel(x,y)
				luma[y*w+x] = 0.2126*c.r+0.7152*c.g+0.0722*c.b
		var total := 0.0
		var mean := 0.0
		var count := 0
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var local := 0.0
				for dy in range(-4,5):
					for dx in range(-4,5):
						local += luma[clampi(y+dy,0,h-1)*w+clampi(x+dx,0,w-1)]
				total += absf(luma[y*w+x]-local/81.0)
				mean += luma[y*w+x]
				count += 1
		var blocks := PackedFloat32Array()
		for by in range(rect.position.y,rect.end.y-32,33):
			for bx in range(rect.position.x,rect.end.x-32,33):
				var s := 0.0
				for y in range(by,by+33):
					for x in range(bx,bx+33): s += luma[y*w+x]
				blocks.append(s/1089.0)
		var bm := 0.0
		for b in blocks: bm += b
		bm /= maxf(blocks.size(),1)
		var spread := 0.0
		for b in blocks: spread += absf(b-bm)
		spread /= maxf(blocks.size(),1)
		print("NOISE %s noise %.2f%% luma %.3f broad %.2f%%" % [path.get_file(),100.0*total/count,mean/count,100.0*spread])
	quit(0)
