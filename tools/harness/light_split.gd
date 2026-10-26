extends "res://tools/harness/look_views.gd"
## Where the light on screen comes from, per view of look_views.gd (its
## SPOTS and SUN views): the still as the game shows it, then linear passes
## with the sun only (fill and rim off), the sky fill only (sun and rim off),
## the rim only, none of them (what's left: the haze, the sky's reflection,
## the materials' own glows), that without the depth fog (so the haze's own
## share: the fog's colour and its aerial sky, not its sun scatter, which
## goes with the sun), and the frame without trees (the tree mask).
## Pixels are sorted into grass, rock and tree, sunlit (the sun gives over
## 60% of their light) or deep shade (under 10%), and far land in the haze
## (haze_far: the depth fog gives over 40% of its light); a ROW per view gives each
## class's median V, S, H on screen and each light's share. The shares come
## from separate passes, so they are approximate.
##   python tools/drive.py tools/harness/light_split.gd --rendered -- --out=DIR --views=hills,sun_toward --save-mask --scene-args --no-title --hour=17.5
## --save-mask writes <view>_mask.png (the classes), for a pixel-matched
## comparison of two runs' stills: `python tools/light_split.py match
## BEFORE_DIR AFTER_DIR` (and `python tools/light_split.py shares LOG` for
## the shares table). --save-lin keeps the sun and fill passes. --win=WxH,
## --full-size as look_views.gd.
var _ov := {}
var _mask: Image
var _sun: DirectionalLight3D
var _rim: DirectionalLight3D
const W := 480
const H := 300

func drive() -> void:
	await open("studies/endless_flight.tscn")
	study.walk_ready = false
	var cam: Camera3D = study.camera
	if study.plane_figure != null: study.plane_figure.visible = false
	_sun = study.look.sun
	for l: Node in find("DirectionalLight3D"):
		if l != _sun: _rim = l
	RenderingServer.frame_pre_draw.connect(_apply)
	var out := str(arg("out","scratch/light/split"))
	var names: PackedStringArray = str(arg("views","meadow_low,hills,rock,forest,cruise")).split(",")
	var env: Environment = study.look.environment
	for n in names:
		aim(n)
		_true = {}
		await _hold(arg_int("hold",300))
		_true = {"sun":_sun.light_energy,"rim":_rim.light_energy if _rim != null else 0.0,"hemi":float(study.look.celestial.state.zs_hemi_energy)*float(study.look._fill)}
		_ov = {}
		var disp := await _img("%s/%s.png" % [out,n])
		var tm := env.tonemap_mode
		var glow := env.glow_enabled
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_enabled = false
		var full := await _img("")
		_ov = {"hemi":true,"rim":true}
		var sun := await _img("%s/%s_lin_sun.png" % [out,n] if flag("save-lin") else "")
		_ov = {"sun":true,"rim":true}
		var fill := await _img("%s/%s_lin_fill.png" % [out,n] if flag("save-lin") else "")
		_ov = {"sun":true,"rim":true,"hemi":true}
		var none := await _img("")
		env.fog_enabled = false
		var nofog := await _img("")
		env.fog_enabled = true
		_ov = {"rim_only":true}
		var rimimg := await _img("")
		_ov = {}
		study.trees.visible = false
		var notree := await _img("")
		study.trees.visible = true
		env.tonemap_mode = tm
		env.glow_enabled = glow
		var st := _stats(disp,full,sun,fill,none,rimimg,notree,nofog)
		if flag("save-mask"):
			_mask.save_png("%s/%s_mask.png" % [out,n])
		var state: Dictionary = study.look.celestial.state
		var fwd := -cam.global_basis.z
		var sd: Vector3 = state.zs_sun_direction
		st["view"] = n
		st["mood"] = str(study.look.mood)
		st["hour"] = snappedf(study.look.hour(),0.01)
		st["sun_y"] = snappedf(sd.y,0.001)
		# The view's bearing to the sun: 1 looking at it, -1 with it behind.
		st["to_sun"] = snappedf(Vector2(fwd.x,fwd.z).normalized().dot(Vector2(sd.x,sd.z).normalized()),0.01)
		st["key_irr"] = _v(state.zs_key_irradiance)
		st["hemi_sky"] = _v(state.zs_hemi_sky)
		st["hemi_ground"] = _v(state.zs_hemi_ground)
		st["hemi_energy"] = snappedf(float(state.zs_hemi_energy)*float(study.look._fill),0.0001)
		st["sun_energy"] = snappedf(float(_true.sun),0.0001)
		st["rim_energy"] = snappedf(float(_true.rim),0.0001)
		var sc := _sun.light_color.srgb_to_linear()
		st["sun_color"] = _v(Vector3(sc.r,sc.g,sc.b))
		for k in ["zs_sun_hue","zs_shadow_tint","zs_sun_lean","zs_shade_lean"]:
			if state.has(k): st[k] = _v(state[k])
		var fc := env.fog_light_color.srgb_to_linear()
		st["fog"] = _v(Vector3(fc.r,fc.g,fc.b)*env.fog_light_energy)
		st["fog_aerial"] = snappedf(env.fog_aerial_perspective,0.001)
		st["fog_scatter"] = snappedf(env.fog_sun_scatter,0.001)
		st["exposure"] = snappedf(env.tonemap_exposure,0.001)
		st["window"] = str(root.size)
		row(st)
		await frames(2)
	finish()

func _v(x: Vector3) -> Array:
	return [snappedf(x.x,0.001),snappedf(x.y,0.001),snappedf(x.z,0.001)]

var _true := {}
func _apply() -> void:
	if _true.is_empty(): return
	_sun.light_energy = 0.0 if (_ov.has("sun") or _ov.has("rim_only")) else float(_true.sun)
	if _rim != null: _rim.light_energy = 0.0 if _ov.has("rim") else float(_true.rim)
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",0.0 if (_ov.has("hemi") or _ov.has("rim_only")) else float(_true.hemi))

func _img(path: String) -> Image:
	for c: Node in root.find_children("*","CanvasLayer",true,false): c.visible = false
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if path != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		var save := image.duplicate()
		if not flag("full-size"): save.resize(1440,900,Image.INTERPOLATE_LANCZOS)
		save.save_png(path)
	image.resize(W,H,Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGB8)
	return image

static func _lin(b: int) -> float:
	var c := b/255.0
	return c/12.92 if c <= 0.04045 else pow((c+0.055)/1.055,2.4)

static func _luma(c: Vector3) -> float:
	return c.dot(Vector3(0.2126,0.7152,0.0722))

func _stats(disp: Image, full: Image, sun: Image, fill: Image, none: Image, rimimg: Image, notree: Image, nofog: Image) -> Dictionary:
	var D := disp.get_data()
	var F := full.get_data()
	var S := sun.get_data()
	var L := fill.get_data()
	var N := none.get_data()
	var R := rimimg.get_data()
	var NF := nofog.get_data()
	var T := notree.get_data()
	var lut := PackedFloat32Array()
	lut.resize(256)
	for i in 256: lut[i] = _lin(i)
	var acc := {}
	var hist := {}
	_mask = Image.create(W,H,false,Image.FORMAT_RGB8)
	for i in W*H:
		var k := i*3
		var f := Vector3(lut[F[k]],lut[F[k+1]],lut[F[k+2]])
		var s := Vector3(lut[S[k]],lut[S[k+1]],lut[S[k+2]])
		var l := Vector3(lut[L[k]],lut[L[k+1]],lut[L[k+2]])
		var no := Vector3(lut[N[k]],lut[N[k+1]],lut[N[k+2]])
		var r := Vector3(lut[R[k]],lut[R[k+1]],lut[R[k+2]])
		var nf := Vector3(lut[NF[k]],lut[NF[k+1]],lut[NF[k+2]])
		var t := Vector3(lut[T[k]],lut[T[k+1]],lut[T[k+2]])
		var fl := _luma(f)
		if fl < 0.002: continue
		var dc := Color8(D[k],D[k+1],D[k+2])
		# Far land in the haze: the depth fog is over 40% of its light (the
		# sky is untouched by the fog). Its display colour only, class "haze".
		var nfv := Vector3(lut[NF[k]],lut[NF[k+1]],lut[NF[k+2]])
		if _luma(no-nfv) > 0.4*fl:
			_mask.set_pixel(i%W,i/W,Color8(40,255,0))
			if not acc.has("haze_far"): acc["haze_far"] = {"n":0,"f":Vector3.ZERO,"s":Vector3.ZERO,"l":Vector3.ZERO,"no":Vector3.ZERO,"r":Vector3.ZERO,"fog":Vector3.ZERO,"v":[],"sat":[],"h":[]}
			var ah: Dictionary = acc["haze_far"]
			ah.n += 1
			ah.f += f
			ah.no += no
			ah.fog += no-nfv
			(ah.v as Array).append(dc.v)
			(ah.sat as Array).append(dc.s)
			(ah.h as Array).append(dc.h)
			continue
		# Light-made share: sky and fogged-out land are mostly `none`.
		if _luma(no) > 0.5*fl: continue
		var cls := ""
		if (f-t).length() > 0.02 + 0.15*f.length(): cls = "tree"
		else:
			if dc.v > 0.9 and dc.s < 0.15: continue  # snow
			var hue := dc.h*360.0
			if hue > 62.0 and hue < 170.0 and dc.s > 0.18: cls = "grass"
			elif dc.s < 0.45 and (hue < 62.0 or hue > 200.0 or dc.s < 0.12): cls = "rock"
			else: continue
		s -= no
		l -= no
		r -= no
		var share := _luma(s)/maxf(fl,1e-4)
		var hk := cls+"_hist"
		if not hist.has(hk): hist[hk] = [0,0,0,0,0,0,0,0,0,0]
		var hb := clampi(int(share*10.0),0,9)
		var ha: Array = hist[hk]
		ha[hb] = int(ha[hb]) + 1
		var lit := ""
		if share > 0.6: lit = "lit"
		elif share < 0.1: lit = "shade"
		else: continue
		var key := cls+"_"+lit
		_mask.set_pixel(i%W,i/W,Color8({"grass":80,"rock":160,"tree":240}[cls],255 if lit == "lit" else 128,0))
		if not acc.has(key): acc[key] = {"n":0,"f":Vector3.ZERO,"s":Vector3.ZERO,"l":Vector3.ZERO,"no":Vector3.ZERO,"r":Vector3.ZERO,"fog":Vector3.ZERO,"v":[],"sat":[],"h":[]}
		var a: Dictionary = acc[key]
		a.n += 1
		a.f += f
		a.s += s
		a.l += l
		a.no += no
		a.r += r
		a.fog += no-nf
		(a.v as Array).append(dc.v)
		(a.sat as Array).append(dc.s)
		(a.h as Array).append(dc.h)
	var res := {"classes":{},"hist":{}}
	for hk: String in hist: res.hist[hk] = hist[hk]
	for key: String in acc:
		var a: Dictionary = acc[key]
		var n := float(a.n)
		if n < 50: continue
		var v: Array = a.v
		v.sort()
		var sa: Array = a.sat
		sa.sort()
		var hh: Array = a.h
		hh.sort()
		var fm: Vector3 = a.f/n
		var sm: Vector3 = a.s/n
		var lm: Vector3 = a.l/n
		var nm: Vector3 = a.no/n
		var rm: Vector3 = a.r/n
		res.classes[key] = {"n":int(n),"V":snappedf(v[v.size()/2],0.001),"S":snappedf(sa[sa.size()/2],0.001),"H":snappedf(float(hh[hh.size()/2])*360.0,0.1),
			"full":_v(fm),"sun":_v(sm),"fill":_v(lm),"none":_v(nm),"rim":_v(rm),
			"sun_fill":snappedf(_luma(sm)/maxf(_luma(lm),1e-4),0.01),
			"sun_share":snappedf(_luma(sm)/maxf(_luma(fm),1e-4),0.01),"fill_share":snappedf(_luma(lm)/maxf(_luma(fm),1e-4),0.01),
			"none_share":snappedf(_luma(nm)/maxf(_luma(fm),1e-4),0.01),"rim_share":snappedf(_luma(rm)/maxf(_luma(fm),1e-4),0.01),
			"fog":_v(a.fog/n),"fog_share":snappedf(_luma(a.fog/n)/maxf(_luma(fm),1e-4),0.01)}
	return res
