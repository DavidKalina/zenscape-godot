extends RefCounted
## The hangar's finish section (scripts/endless/ui/hangar_page.gd; a section
## is what paint_section.gd says): the look's `wear` and `finish`
## (scripts/endless/plane_look.gd), from the parts in
## scripts/endless/plane_finishes.gd.
##   Surface   the atlas the paint lies on (the look's `wear`)
##   Sheen     satin, gloss, matte or metal
##   Pearl     off or on; on, its colour (a hue) and amount
##   Glow      off or on; on, its colour (hue and saturation), which zones
##             are lit (a zone picked, then lit or not; Marks is the decal)
##             and its power. A glow shows after dark only, so its rows ask
##             the page for night (`night`).
## A look with no `finish` shows satin with no pearl or glow, and gets one
## at the first change here; the same for `wear` and the plane's own surface.

const PlaneFinishes = preload("res://scripts/endless/plane_finishes.gd")

const TITLE := "Finish"
## What a glow can light, and each one's name: the paint's zones, then the
## decal.
const LIT: Array[String] = ["body","trim","wing","dark","decal"]
const LIT_NAMES: Array[String] = ["Body","Trim","Wings","Struts","Marks"]
const UNLIT := Color("2a2c30")
const HUE_STEP := 1.0/72.0
const STEP := 0.05
## A pearl's saturation (its hue is the player's), and what each starts as
## when turned on.
const PEARL_SAT := 0.45
const PEARL_FROM := Vector3(0.64,PEARL_SAT,0.5)
const GLOW_FROM := Vector3(0.53,0.8,1.0)
const POWER_MOST := 1.3

var look := {}
var surface := 0
var sheen := 0
var pearl_on := false
## The pearl's hue, saturation and amount.
var pearl := PEARL_FROM
var glow_on := false
## The glow's hue, saturation and power.
var glow := GLOW_FROM
## Whether each of LIT glows, and the one picked on the Zone row.
var lit: Array[bool] = [false,true,false,false,false]
var zone := 1
## The finish's `metal` (how far a metal sheen mirrors), kept as it came.
var _metal: Variant = null

func begin(to: Dictionary) -> void:
	look = to
	surface = PlaneFinishes.index(PlaneFinishes.SURFACES,str(look.get("wear","")))
	var f: Dictionary = look.get("finish",{}) if look.get("finish") is Dictionary else {}
	sheen = PlaneFinishes.index(PlaneFinishes.SHEENS,str(f.get("sheen","")))
	_metal = f.get("metal")
	pearl_on = f.get("pearl") is String and Color.html_is_valid(f.pearl)
	pearl = PEARL_FROM
	if pearl_on:
		var c := Color.html(f.pearl)
		pearl = Vector3(c.h,c.s,clampf(float(f.get("pearl_amount",0.6)),0.0,1.0))
	glow_on = f.get("glow") is String and Color.html_is_valid(f.glow)
	glow = GLOW_FROM
	lit = [false,true,false,false,false]
	if glow_on:
		var c := Color.html(f.glow)
		glow = Vector3(c.h,c.s,clampf(float(f.get("glow_power",1.0)),0.0,POWER_MOST))
		var on: Array = f.get("glow_on",["trim"])
		for i in LIT.size(): lit[i] = on.has(LIT[i])

func pearl_colour() -> Color:
	return Color.from_hsv(pearl.x,pearl.y,1.0)

func glow_colour() -> Color:
	return Color.from_hsv(glow.x,glow.y,1.0)

func rows() -> Array[Dictionary]:
	var surfaces: Array[String] = []
	var surface_parts: Array[String] = []
	for r: Dictionary in PlaneFinishes.SURFACES:
		surfaces.append(r.name)
		surface_parts.append("surface:"+String(r.id))
	var sheens: Array[String] = []
	var sheen_parts: Array[String] = []
	for r: Dictionary in PlaneFinishes.SHEENS:
		sheens.append(r.name)
		sheen_parts.append("sheen:"+String(r.id))
	# Each option's part (the page locks the ones not had).
	var out: Array[Dictionary] = [
		{"id":"surface","label":"Surface","kind":"choice","opts":surfaces,"parts":surface_parts,"on":surface},
		{"id":"sheen","label":"Sheen","kind":"seg","opts":sheens,"parts":sheen_parts,"on":sheen},
		{"id":"pearl","label":"Pearl","kind":"seg","opts":["Off","On"],"parts":["","finish:pearl"],"on":int(pearl_on)},
	]
	if pearl_on:
		out.append({"id":"pearl_hue","label":"Pearl colour","kind":"slider","frac":pearl.x,"value":str(roundi(pearl.x*360.0)),"ramp":_hues(pearl.y)})
		out.append({"id":"pearl_amount","label":"Pearl amount","kind":"slider","frac":pearl.z,"value":str(roundi(pearl.z*100.0))})
	out.append({"id":"glow","label":"Glow","kind":"seg","opts":["Off","On"],"parts":["","finish:glow"],"on":int(glow_on),"night":glow_on})
	if glow_on:
		var dots: Array[Color] = []
		for i in LIT.size(): dots.append(glow_colour() if lit[i] else UNLIT)
		out.append({"id":"glow_hue","label":"Glow colour","kind":"slider","frac":glow.x,"value":str(roundi(glow.x*360.0)),"ramp":_hues(glow.y),"night":true})
		out.append({"id":"glow_sat","label":"Glow tint","kind":"slider","frac":glow.y,"value":str(roundi(glow.y*100.0)),"ramp":[Color.WHITE,Color.from_hsv(glow.x,1.0,1.0)],"night":true})
		out.append({"id":"glow_zone","label":"Glow on","kind":"seg","opts":LIT_NAMES,"on":zone,"dots":dots,"night":true})
		out.append({"id":"glow_lit","label":LIT_NAMES[zone]+" lit","kind":"seg","opts":["Off","On"],"on":int(lit[zone]),"night":true})
		out.append({"id":"glow_power","label":"Glow power","kind":"slider","frac":glow.z/POWER_MOST,"value":str(roundi(glow.z*100.0)),"night":true})
	return out

func _hues(sat: float) -> Array[Color]:
	var out: Array[Color] = []
	for i in 13: out.append(Color.from_hsv(float(i)/12.0,sat,1.0))
	return out

func change(id: String, dir: int) -> bool:
	match id:
		"surface": return _surface(posmod(surface+dir,PlaneFinishes.SURFACES.size()))
		"sheen": return _sheen(clampi(sheen+dir,0,PlaneFinishes.SHEENS.size()-1))
		"pearl": return _pearl_on(dir > 0)
		"pearl_hue": return _pearl(Vector3(fposmod(pearl.x+HUE_STEP*dir,1.0),pearl.y,pearl.z))
		"pearl_amount": return _pearl(Vector3(pearl.x,pearl.y,clampf(snappedf(pearl.z+STEP*dir,STEP),0.0,1.0)))
		"glow": return _glow_on(dir > 0)
		"glow_hue": return _glow(Vector3(fposmod(glow.x+HUE_STEP*dir,1.0),glow.y,glow.z))
		"glow_sat": return _glow(Vector3(glow.x,clampf(snappedf(glow.y+STEP*dir,STEP),0.0,1.0),glow.z))
		"glow_zone":
			zone = clampi(zone+dir,0,LIT.size()-1)
			return false
		"glow_lit": return _lit(dir > 0)
		"glow_power": return _glow(Vector3(glow.x,glow.y,clampf(snappedf(glow.z+STEP*dir,STEP),0.0,POWER_MOST)))
	return false

func set_to(id: String, v: float) -> bool:
	match id:
		"surface": return _surface(clampi(int(v),0,PlaneFinishes.SURFACES.size()-1))
		"sheen": return _sheen(clampi(int(v),0,PlaneFinishes.SHEENS.size()-1))
		"pearl": return _pearl_on(int(v) > 0)
		"pearl_hue": return _pearl(Vector3(clampf(v,0.0,0.999),pearl.y,pearl.z))
		"pearl_amount": return _pearl(Vector3(pearl.x,pearl.y,clampf(v,0.0,1.0)))
		"glow": return _glow_on(int(v) > 0)
		"glow_hue": return _glow(Vector3(clampf(v,0.0,0.999),glow.y,glow.z))
		"glow_sat": return _glow(Vector3(glow.x,clampf(v,0.0,1.0),glow.z))
		"glow_zone":
			zone = clampi(int(v),0,LIT.size()-1)
			return false
		"glow_lit": return _lit(int(v) > 0)
		"glow_power": return _glow(Vector3(glow.x,glow.y,clampf(v,0.0,1.0)*POWER_MOST))
	return false

func _surface(to: int) -> bool:
	if to == surface: return false
	surface = to
	look["wear"] = PlaneFinishes.SURFACES[surface].id
	return true

func _sheen(to: int) -> bool:
	if to == sheen: return false
	sheen = to
	return _keep()

func _pearl_on(to: bool) -> bool:
	if to == pearl_on: return false
	pearl_on = to
	return _keep()

func _pearl(to: Vector3) -> bool:
	if to == pearl: return false
	pearl = to
	return _keep()

func _glow_on(to: bool) -> bool:
	if to == glow_on: return false
	glow_on = to
	return _keep()

func _glow(to: Vector3) -> bool:
	if to == glow: return false
	glow = to
	return _keep()

func _lit(to: bool) -> bool:
	if to == lit[zone]: return false
	lit[zone] = to
	return _keep()

## The rows' state written as the look's `finish`.
func _keep() -> bool:
	var f := {"sheen":PlaneFinishes.SHEENS[sheen].id}
	if _metal != null: f["metal"] = _metal
	if pearl_on:
		f["pearl"] = pearl_colour().to_html(false)
		f["pearl_amount"] = snappedf(pearl.z,0.01)
	if glow_on:
		var on: Array = []
		for i in LIT.size():
			if lit[i]: on.append(LIT[i])
		f["glow"] = glow_colour().to_html(false)
		f["glow_on"] = on
		f["glow_power"] = snappedf(glow.z,0.01)
	look["finish"] = f
	return true
