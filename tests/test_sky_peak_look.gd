extends SceneTree
## The mountains' look (scripts/sky_peak.gd `body_arrays`, `_tone`): basalt
## under snow. For two ranges, near and as their skylines, and a sea's
## summit: no face wound or lit from behind (its vertex normals within
## NORMAL_AGREE of its own, so the ground shader never turns a face inward
## into a dark triangular pit); no face lit far darker than every face round
## it (the pit's signature, as tools/probe_peak_look.gd measures it); no
## green and no warm (brown) rock; the rock in basalt's range, dark and
## cool; snow over the snow line, with steep faces up there left dark; and
## the ranges' material keeps the plate's grass field and geology off the
## rock (reference_surface `peak_rock`). Headless: arrays and materials
## only, nothing drawn.
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
const Probe = preload("res://tools/probe_peak_look.gd")
const SUNS := [Vector3(0.45,0.62,0.35),Vector3(-0.55,0.45,-0.2),Vector3(0.1,0.9,-0.4)]
var failures := 0
var palette: RefCounted

func _initialize() -> void:
	preload("res://scripts/sky_world.gd").ring = false
	palette = preload("res://scripts/native_terrain_palette.gd").new()
	for s: int in [SkyPeaks.seed_of(Vector2i.ZERO),4242]:
		var shape: RefCounted = SkyPeak.make(s)
		_check_arrays("Range %d near" % s,shape,_arrays(shape,1),true)
		_check_arrays("Range %d skyline" % s,shape,_arrays(shape,SkyRing.STRIDE),true)
	var out := {}
	SkyRing._make_summit(9001,90.0,palette.grass,palette.rock,palette.gravel,palette.snow,SkyPeaks.OFF_MAP,out)
	_check_arrays("A sea's summit",SkyPeak.make(9001,1.0,false),out.arrays,false)
	_material()
	print("PASS: sky peak look" if failures == 0 else "FAIL: sky peak look")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _arrays(shape: RefCounted, stride: int) -> Array:
	return shape.body_arrays(palette.grass,palette.rock,palette.gravel,SkyPeaks.OFF_MAP,stride,palette.snow)

func _check_arrays(label: String, shape: RefCounted, arrays: Array, snow_line: bool) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var faces := v.size()/3
	var turned := 0
	var worst_agree := 1.0
	var green := 0
	var warm := 0
	var rock := 0
	var lum_lo := INF
	var lum_hi := -INF
	var over := 0
	var over_snow := 0
	var steep_over := 0
	var steep_over_snow := 0
	var face_n := PackedVector3Array()
	face_n.resize(faces)
	var broad := PackedVector3Array()
	broad.resize(faces)
	var drawn := PackedColorArray()
	drawn.resize(faces)
	var edges := {}
	for f in range(faces):
		var a := v[f*3]
		var b := v[f*3+1]
		var c := v[f*3+2]
		# Godot's front faces wind clockwise: outward is (c-a)x(b-a).
		var n := (c-a).cross(b-a).normalized()
		face_n[f] = n
		broad[f] = (nrm[f*3]+nrm[f*3+1]+nrm[f*3+2]).normalized()
		if n.y <= 0.0: turned += 1
		for k in range(3): worst_agree = minf(worst_agree,nrm[f*3+k].dot(n))
		var snowy := uv[f*3].x < 0.0
		var colour := col[f*3]
		drawn[f] = palette.snow if snowy else colour
		var y := (a.y+b.y+c.y)/3.0
		if y > shape.snowline+SkyPeak.SNOW_RAG:
			over += 1
			if snowy: over_snow += 1
			if n.y < 0.35:
				steep_over += 1
				if snowy: steep_over_snow += 1
		if not snowy:
			rock += 1
			if colour.g > maxf(colour.r,colour.b): green += 1
			if colour.r > colour.b: warm += 1
			var l := Probe._lum(colour)
			lum_lo = minf(lum_lo,l)
			lum_hi = maxf(lum_hi,l)
		for e in [[a,b],[b,c],[c,a]]:
			var key := Probe._edge(e[0],e[1])
			if edges.has(key): edges[key].append(f)
			else: edges[key] = [f]
	var round := []
	round.resize(faces)
	for f in range(faces): round[f] = []
	for key in edges:
		var fs: Array = edges[key]
		if fs.size() == 2:
			round[fs[0]].append(fs[1])
			round[fs[1]].append(fs[0])
	var pits := 0
	for f in range(faces):
		if (round[f] as Array).size() < 2: continue
		for sun: Vector3 in SUNS:
			var least := INF
			for g: int in round[f]: least = minf(least,Probe.lit(drawn[g],face_n[g],broad[g],sun))
			if least > 0.02 and Probe.lit(drawn[f],face_n[f],broad[f],sun) < least*Probe.PIT_SHARE:
				pits += 1
				break
	check(faces > 0 and turned == 0,"%s: every face of %d wound to face out and up" % [label,faces])
	check(worst_agree >= SkyPeak.NORMAL_AGREE-0.001,"%s: no vertex normal leans past its face's (worst cosine %.2f)" % [label,worst_agree])
	# A facet turned from the sun among sunlit ones is the faceted look, so
	# a few are fine; the pits were faces lit from behind and lone bare
	# faces in the snow, five to ten times as many on a skyline.
	check(pits <= faces/500,"%s: hardly a face lit far darker than every face round it, a pit (%d of %d)" % [label,pits,faces])
	# At every season's line no face stands alone: bare in the snow, or
	# white on bare rock (`_despeckle`): summer's, as drawn and winter's.
	for fall in [-70.0,0.0,110.0]:
		var lone := 0
		for f in range(faces):
			if (round[f] as Array).size() < 2: continue
			var mine: bool = uv[f*3].x < fall
			var alone := true
			for g: int in round[f]:
				if (uv[g*3].x < fall) == mine: alone = false
			if alone: lone += 1
		check(lone == 0,"%s: with the snow line %+.0f m, no face alone, bare in the snow or white on the rock (%d)" % [label,fall,lone])
	check(green == 0,"%s: no green rock (%d faces)" % [label,green])
	check(warm == 0,"%s: no warm, brown rock (%d faces)" % [label,warm])
	check(rock > 0 and lum_lo >= 0.03 and lum_hi <= 0.2,"%s: the rock is basalt, dark (luminance %.3f to %.3f, linear)" % [label,lum_lo,lum_hi])
	if snow_line:
		check(over > 0 and over_snow > over/2,"%s: snow lies over the snow line (%d of %d faces)" % [label,over_snow,over])
		# A skyline's faces snow by the fine ground at a corner (SkyPeak
		# `_point_need`), so its few sheer faces hold a little more.
		var most := 0.35 if label.ends_with("near") else 0.6
		check(steep_over_snow < steep_over*most,"%s: the sheerest faces up there stay dark rock (%d of %d snowed)" % [label,steep_over_snow,steep_over])
	else:
		var snowed := 0
		for f in range(faces):
			if uv[f*3].x < 0.0: snowed += 1
		check(snowed > faces/20,"%s: its cap is snowed (%d of %d faces)" % [label,snowed,faces])

func _material() -> void:
	var peaks: Node3D = SkyPeaks.new()
	var m: ShaderMaterial = peaks._ground()
	check(m.get_shader_parameter("peak_rock") == true,"The ranges' material is bare rock (peak_rock)")
	var code := FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader")
	check("ground_grass = peak_rock ? 0.0" in code and "!peak_rock && (rock_treatment" in code,"Bare rock takes neither the plate's grass field nor its geology")
	peaks.free()
