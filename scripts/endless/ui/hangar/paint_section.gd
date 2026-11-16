extends RefCounted
## The hangar's paint section (scripts/endless/ui/hangar_page.gd; the look's
## `paint`, scripts/endless/plane_look.gd): a zone picked from the four, its
## colour set by hue, saturation and value, or taken from a row of swatches.
##
## A hangar section is a RefCounted with:
##   TITLE                  its name on the page's Part row
##   begin(look)            the look to edit (kept, and changed in place);
##                          called on opening and after a reset
##   rows() -> Array        its rows now, top to bottom, each a Dictionary:
##       {id, label, kind:"seg", opts:[String], on:int, dots:[Color] (optional)}
##       {id, label, kind:"slider", frac:0..1, value:String, ramp:[Color] (optional)}
##       {id, label, kind:"swatches", colours:[Color], on:int (-1 none)}
##       {id, label, kind:"choice", opts:[String], on:int}  one of many, only
##           the chosen name shown, between two arrows; Left, Right, Enter
##           and a click go to `change` (round the ends: the left arrow
##           clicked is -1, Enter and a click elsewhere 1)
##       {id, label, kind:"list", names:[String], on:int, notes:[String]
##           (optional, a quiet word at each line's right), lines:int
##           (optional, the lines shown)}  one of many, a few lines of them
##           shown under the label; Up, Down, Left, Right and the wheel go
##           to `change` (not round the ends: Up and Down leave the row
##           there), a click on a line to `set_to(id, index)`
##     any row may have night:true: the page shows the plane after dark
##     while it is selected (a glow)
##   change(id, dir) -> bool    Left or Right on row `id`
##   set_to(id, v) -> bool      the mouse: a slider's 0..1, or the index of
##                              the option or swatch clicked
## `change` and `set_to` return true when the look changed (the page then
## keeps it and repaints the plane); the page reads `rows()` again after
## either.

const TITLE := "Paint"
const NAMES: Array[String] = ["Body","Trim","Wings","Struts"]
const SWATCHES: Array[Color] = [Color("f3ead6"),Color("ece2c8"),Color("e9c84a"),Color("d49a2f"),Color("b9583b"),Color("a8322a"),
	Color("6a3a5a"),Color("1f2a44"),Color("2c4f8a"),Color("2f6670"),Color("2f6b4a"),Color("6f7d3a"),Color("8a8d8f"),Color("1e1f22")]
## Left or Right moves the hue 5 degrees, the others 5 in 100.
const HUE_STEP := 1.0/72.0
const STEP := 0.05

var look := {}
## The zone being painted: an index into PlaneLook.ZONES.
var zone := 0
## Each zone's hue, saturation and value: kept apart from its colour, so a
## grey keeps the hue it was given.
var _hsv: Array[Vector3] = []

func begin(to: Dictionary) -> void:
	look = to
	_hsv.clear()
	for name in PlaneLook.ZONES:
		var c := PlaneLook.colour(look,name,PlaneLook.own_colour(name))
		_hsv.append(Vector3(c.h,c.s,c.v))

## The colour of zone `i` now.
func colour(i: int) -> Color:
	return PlaneLook.colour(look,PlaneLook.ZONES[i],PlaneLook.own_colour(PlaneLook.ZONES[i]))

func rows() -> Array[Dictionary]:
	var at := _hsv[zone]
	var dots: Array[Color] = []
	for i in PlaneLook.ZONES.size(): dots.append(colour(i))
	var hues: Array[Color] = []
	for i in 13: hues.append(Color.from_hsv(float(i)/12.0,maxf(at.y,0.35),maxf(at.z,0.5)))
	var now := colour(zone)
	var on := -1
	for i in SWATCHES.size():
		if SWATCHES[i].to_html(false) == now.to_html(false): on = i
	return [
		{"id":"zone","label":"Zone","kind":"seg","opts":NAMES,"on":zone,"dots":dots},
		{"id":"hue","label":"Hue","kind":"slider","frac":at.x,"value":str(roundi(at.x*360.0)),"ramp":hues},
		{"id":"sat","label":"Saturation","kind":"slider","frac":at.y,"value":str(roundi(at.y*100.0)),"ramp":[Color.from_hsv(at.x,0.0,at.z),Color.from_hsv(at.x,1.0,at.z)]},
		{"id":"val","label":"Value","kind":"slider","frac":at.z,"value":str(roundi(at.z*100.0)),"ramp":[Color.from_hsv(at.x,at.y,0.0),Color.from_hsv(at.x,at.y,1.0)]},
		{"id":"swatch","label":"Swatch","kind":"swatches","colours":SWATCHES,"on":on},
	]

func change(id: String, dir: int) -> bool:
	var at := _hsv[zone]
	match id:
		"zone":
			zone = clampi(zone+dir,0,NAMES.size()-1)
			return false
		"hue": return _put(Vector3(fposmod(at.x+HUE_STEP*dir,1.0),at.y,at.z))
		"sat": return _put(Vector3(at.x,clampf(snappedf(at.y+STEP*dir,STEP),0.0,1.0),at.z))
		"val": return _put(Vector3(at.x,at.y,clampf(snappedf(at.z+STEP*dir,STEP),0.0,1.0)))
		"swatch":
			var on: int = rows()[4].on
			return _swatch(posmod(on+dir,SWATCHES.size()) if on >= 0 else (0 if dir > 0 else SWATCHES.size()-1))
	return false

func set_to(id: String, v: float) -> bool:
	var at := _hsv[zone]
	match id:
		"zone":
			zone = clampi(int(v),0,NAMES.size()-1)
			return false
		"hue": return _put(Vector3(clampf(v,0.0,0.999),at.y,at.z))
		"sat": return _put(Vector3(at.x,clampf(v,0.0,1.0),at.z))
		"val": return _put(Vector3(at.x,at.y,clampf(v,0.0,1.0)))
		"swatch": return _swatch(int(v))
	return false

func _swatch(i: int) -> bool:
	# The swatch's own colour, not its hue, saturation and value turned back
	# into one: the row then finds it again.
	var c := SWATCHES[clampi(i,0,SWATCHES.size()-1)]
	_hsv[zone] = Vector3(c.h,c.s,c.v)
	PlaneLook.set_colour(look,PlaneLook.ZONES[zone],c)
	return true

func _put(to: Vector3) -> bool:
	if to == _hsv[zone]: return false
	_hsv[zone] = to
	PlaneLook.set_colour(look,PlaneLook.ZONES[zone],Color.from_hsv(to.x,to.y,to.z))
	return true
