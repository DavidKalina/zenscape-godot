extends SceneTree
## The pixel work of tools/look_measure.py: reads PNGs (headless, only the
## Image API), scales each to 720 px wide so numbers compare across window
## sizes, sorts pixels into rough material classes by hue/saturation/value
## and where they sit against the horizon, and prints one `LOOK {json}` line
## per image. Not for direct use; run tools/look_measure.py.
##   godot --headless --path . -s tools/harness/look_measure.gd -- --in=a.png,b.png [--crop=x0,y0,x1,y1 (fractions)] [--classes=0 (one class "all")]
const W := 720
const SCALES := [1, 2, 4, 8, 16, 32, 64]
const CLASSES := ["sky", "cloud", "water", "grass", "rock_sand", "flower", "other"]
const PCTS := [1, 5, 25, 50, 75, 95, 99]

func _initialize() -> void:
	var files: PackedStringArray = []
	var crop := Vector4(0, 0, 1, 1)
	var by_class := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="): files = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--crop="):
			var p := a.get_slice("=", 1).split(",")
			crop = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
		elif a == "--classes=0": by_class = false
	for f in files:
		var r := measure(f, crop, by_class)
		print("LOOK " + JSON.stringify(r))
	quit(0)

func measure(path: String, crop: Vector4, by_class: bool) -> Dictionary:
	var img := Image.load_from_file(path)
	if img == null:
		return {"file": path, "error": "cannot load"}
	var full := Vector2i(img.get_width(), img.get_height())
	img.convert(Image.FORMAT_RGB8)
	# The crop first, then to 720 wide, so the crop's own scale is comparable.
	var k := float(W) / img.get_width()
	var cx0 := int(crop.x * img.get_width())
	var cy0 := int(crop.y * img.get_height())
	var cx1 := int(crop.z * img.get_width())
	var cy1 := int(crop.w * img.get_height())
	if cx0 != 0 or cy0 != 0 or cx1 != img.get_width() or cy1 != img.get_height():
		img = img.get_region(Rect2i(cx0, cy0, cx1 - cx0, cy1 - cy0))
	# A crop keeps the whole picture's scale (never blown up to 720 wide).
	var w := maxi(int(round(img.get_width() * k)), 8)
	var h := maxi(int(round(img.get_height() * k)), 8)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var d := img.get_data()
	var n := w * h
	var H := PackedFloat32Array(); H.resize(n)
	var S := PackedFloat32Array(); S.resize(n)
	var V := PackedFloat32Array(); V.resize(n)
	var L := PackedFloat32Array(); L.resize(n)
	for i in n:
		var r := d[i * 3] / 255.0
		var g := d[i * 3 + 1] / 255.0
		var b := d[i * 3 + 2] / 255.0
		var mx := maxf(r, maxf(g, b))
		var mn := minf(r, minf(g, b))
		var c := mx - mn
		var hue := 0.0
		if c > 0.0:
			if mx == r: hue = fposmod((g - b) / c, 6.0)
			elif mx == g: hue = (b - r) / c + 2.0
			else: hue = (r - g) / c + 4.0
		H[i] = hue * 60.0
		S[i] = 0.0 if mx == 0.0 else c / mx
		V[i] = mx
		# Rec.709 luma on the stored (display) values.
		L[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
	var horizon := _horizon(H, S, V, w, h)
	var cls := PackedByteArray(); cls.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			cls[i] = _class(H[i], S[i], V[i], y < horizon) if by_class else 0
	var out := {"file": path.get_file(), "size": [full.x, full.y], "measured": [w, h], "crop": [crop.x, crop.y, crop.z, crop.w], "horizon": snappedf(float(horizon) / h, 0.01)}
	var names: Array = CLASSES if by_class else ["all"]
	var classes := {}
	for ci in names.size():
		var idx := PackedInt32Array()
		for i in n:
			if cls[i] == ci: idx.append(i)
		if idx.size() < 200: continue
		classes[names[ci]] = _class_stats(idx, H, S, V, L, d, w, h)
	out["classes"] = classes
	out["whole"] = _whole(L, S, V, d, n, w, h)
	out["aerial"] = _aerial(cls, H, S, V, w, h, horizon, 3 if by_class else -1)
	return out

## The horizon row: the median over columns of how far down sky-like pixels
## (blue, or pale and bright) run from the top.
func _horizon(H: PackedFloat32Array, S: PackedFloat32Array, V: PackedFloat32Array, w: int, h: int) -> int:
	var runs := PackedInt32Array()
	for x in range(0, w, 6):
		var y := 0
		while y < h:
			var i := y * w + x
			var blue := H[i] >= 185.0 and H[i] <= 262.0 and S[i] > 0.2
			var pale := S[i] < 0.3 and V[i] > 0.65
			if not (blue or pale): break
			y += 1
		runs.append(y)
	runs.sort()
	return runs[runs.size() / 2]

func _class(hue: float, s: float, v: float, above: bool) -> int:
	if above:
		if hue >= 185.0 and hue <= 262.0 and s > 0.22: return 0
		if s < 0.4 and v > 0.5: return 1
		return 6
	if s > 0.62 and v > 0.45 and (hue < 35.0 or hue > 270.0 or (hue > 45.0 and hue < 62.0)): return 5
	if hue >= 165.0 and hue <= 240.0 and s > 0.25: return 2
	if hue >= 62.0 and hue < 165.0 and s > 0.16: return 3
	if (hue < 62.0 or hue > 330.0) and s < 0.55 and v < 0.9: return 4
	return 6

func _pct(a: PackedFloat32Array, q: float) -> float:
	return a[clampi(int(q / 100.0 * (a.size() - 1)), 0, a.size() - 1)]

func _circ_mean(hues: PackedFloat32Array) -> float:
	var sx := 0.0
	var sy := 0.0
	for h in hues:
		sx += cos(deg_to_rad(h))
		sy += sin(deg_to_rad(h))
	return fposmod(rad_to_deg(atan2(sy, sx)), 360.0)

func _round(x: float, p := 0.001) -> float:
	return snappedf(x, p)

func _class_stats(idx: PackedInt32Array, H: PackedFloat32Array, S: PackedFloat32Array, V: PackedFloat32Array, L: PackedFloat32Array, d: PackedByteArray, w: int, h: int) -> Dictionary:
	var n := idx.size()
	var sv := PackedFloat32Array(); var ss := PackedFloat32Array(); var sl := PackedFloat32Array(); var sh := PackedFloat32Array()
	var bins := {}
	for i in idx:
		sv.append(V[i]); ss.append(S[i]); sl.append(L[i]); sh.append(H[i])
		# Dominant colours: 24 hues x 3 sats x 4 values.
		var key := Vector3i(int(H[i] / 15.0), mini(int(S[i] * 3.0), 2), mini(int(V[i] * 4.0), 3))
		bins[key] = bins.get(key, 0) + 1
	sv.sort(); ss.sort(); sl.sort()
	var st := {"share": _round(float(n) / (w * h), 0.0001)}
	st["V"] = _pcts(sv)
	st["S"] = _pcts(ss)
	st["L"] = _pcts(sl)
	st["hue_mean"] = _round(_circ_mean(sh), 1.0)
	# Hue of the darkest 10% and brightest 10% (by luma), and their means.
	var lo_t := _pct(sl, 10)
	var hi_t := _pct(sl, 90)
	var dk := PackedInt32Array()
	var lt := PackedInt32Array()
	for i in idx:
		if L[i] <= lo_t: dk.append(i)
		elif L[i] >= hi_t: lt.append(i)
	st["dark10"] = _group(dk, H, S, V, L, d)
	st["lit10"] = _group(lt, H, S, V, L, d)
	st["lit_dark_L_ratio"] = _round(st["lit10"]["L"] / maxf(st["dark10"]["L"], 0.001), 0.01)
	var keys := bins.keys()
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return bins[a] > bins[b])
	var dom := []
	for q in mini(5, keys.size()):
		var kk: Vector3i = keys[q]
		dom.append({"hue": kk.x * 15 + 7, "s": [snappedf(kk.y / 3.0, 0.01), snappedf((kk.y + 1) / 3.0, 0.01)], "v": [kk.z / 4.0, (kk.z + 1) / 4.0], "share": _round(float(bins[kk]) / n, 0.01)})
	st["dominant"] = dom
	st["scale"] = _scale(idx, L, w, h)
	st["edges"] = _edges(idx, L, w, h)
	return st

func _pcts(a: PackedFloat32Array) -> Dictionary:
	var r := {}
	for q in PCTS: r["p%d" % q] = _round(_pct(a, q))
	return r

func _group(idx: PackedInt32Array, H: PackedFloat32Array, S: PackedFloat32Array, V: PackedFloat32Array, L: PackedFloat32Array, d: PackedByteArray) -> Dictionary:
	var hs := PackedFloat32Array()
	var ms := 0.0; var mv := 0.0; var ml := 0.0
	var rgb := Vector3.ZERO
	for i in idx:
		hs.append(H[i]); ms += S[i]; mv += V[i]; ml += L[i]
		rgb += Vector3(d[i * 3], d[i * 3 + 1], d[i * 3 + 2])
	var c := float(idx.size())
	return {"hue": _round(_circ_mean(hs), 1.0), "S": _round(ms / c), "V": _round(mv / c), "L": _round(ml / c), "rgb": [int(rgb.x / c), int(rgb.y / c), int(rgb.z / c)]}

## Block-mean luma spread at block sizes (px at 720 wide): the std of the
## means of blocks lying wholly in the class, over the std at 1 px. Rises
## with the scale where there are blotches; a flat spectrum is noise.
func _scale(idx: PackedInt32Array, L: PackedFloat32Array, w: int, h: int) -> Dictionary:
	var inside := PackedByteArray(); inside.resize(w * h)
	for i in idx: inside[i] = 1
	var out := {}
	for bs: int in SCALES:
		var vals := PackedFloat32Array()
		for by: int in range(0, h - bs + 1, bs):
			for bx: int in range(0, w - bs + 1, bs):
				var ok := true
				var s := 0.0
				for yy in bs:
					for xx in bs:
						var i := (by + yy) * w + bx + xx
						if inside[i] == 0:
							ok = false; break
						s += L[i]
					if not ok: break
				if ok: vals.append(s / (bs * bs))
		if vals.size() < 12: continue
		var m := 0.0
		for v in vals: m += v
		m /= vals.size()
		var var_ := 0.0
		for v in vals: var_ += (v - m) * (v - m)
		out[str(bs)] = _round(sqrt(var_ / vals.size()), 0.0005)
	return out

## Luma gradient (per px at 720 wide) over the class's pixels: median and
## 90th/99th percentile, and the share above 0.08 (a hard edge).
func _edges(idx: PackedInt32Array, L: PackedFloat32Array, w: int, h: int) -> Dictionary:
	var g := PackedFloat32Array()
	for i in idx:
		var x := i % w
		var y := i / w
		if x < 1 or y < 1 or x >= w - 1 or y >= h - 1: continue
		var gx := (L[i + 1] - L[i - 1]) * 0.5
		var gy := (L[i + w] - L[i - w]) * 0.5
		g.append(sqrt(gx * gx + gy * gy))
	if g.size() < 100: return {}
	g.sort()
	var hard := 0
	for v in g: if v > 0.08: hard += 1
	return {"p50": _round(_pct(g, 50), 0.0005), "p90": _round(_pct(g, 90), 0.0005), "p99": _round(_pct(g, 99), 0.0005), "hard_share": _round(float(hard) / g.size(), 0.0005)}

func _whole(L: PackedFloat32Array, S: PackedFloat32Array, V: PackedFloat32Array, d: PackedByteArray, n: int, w: int, h: int) -> Dictionary:
	var sl := L.duplicate(); sl.sort()
	var ss := S.duplicate(); ss.sort()
	var t2 := _pct(sl, 2)
	var dk := PackedInt32Array()
	for i in n:
		if L[i] <= t2: dk.append(i)
	var rgb := Vector3.ZERO
	var Hh := _hue_of(d, dk)
	for i in dk:
		rgb += Vector3(d[i * 3], d[i * 3 + 1], d[i * 3 + 2])
	var c := float(dk.size())
	return {"L": _pcts(sl), "S": _pcts(ss), "darkest2pct_rgb": [int(rgb.x / c), int(rgb.y / c), int(rgb.z / c)], "darkest2pct_hue": _round(Hh, 1.0),
		"darkest_L_p0_1": _round(_pct(sl, 0.1))}

func _hue_of(d: PackedByteArray, idx: PackedInt32Array) -> float:
	var rgb := Vector3.ZERO
	for i in idx: rgb += Vector3(d[i * 3], d[i * 3 + 1], d[i * 3 + 2])
	return Color(rgb.x / idx.size() / 255.0, rgb.y / idx.size() / 255.0, rgb.z / idx.size() / 255.0).h * 360.0

## Land (grass class) by distance: its rows, below the horizon, split into
## four bands near to far; mean S, V and hue in each.
func _aerial(cls: PackedByteArray, H: PackedFloat32Array, S: PackedFloat32Array, V: PackedFloat32Array, w: int, h: int, horizon: int, land: int) -> Array:
	if land < 0: return []
	var rows := []
	for y in range(horizon, h):
		var cnt := 0
		for x in w:
			if cls[y * w + x] == land: cnt += 1
		if cnt > w * 0.05: rows.append(y)
	if rows.size() < 40: return []
	var bands := []
	var nb := 4
	for b in nb:
		# band 0 nearest (bottom of the picture), 3 farthest.
		var lo := rows.size() * (nb - 1 - b) / nb
		var hi := rows.size() * (nb - b) / nb
		var hs := PackedFloat32Array(); var ms := 0.0; var mv := 0.0; var c := 0
		for q in range(lo, hi):
			var y: int = rows[q]
			for x in w:
				var i := y * w + x
				if cls[i] != land: continue
				hs.append(H[i]); ms += S[i]; mv += V[i]; c += 1
		if c < 100: continue
		bands.append({"band": b, "rows": [rows[lo], rows[hi - 1]], "S": _round(ms / c), "V": _round(mv / c), "hue": _round(_circ_mean(hs), 1.0)})
	return bands
