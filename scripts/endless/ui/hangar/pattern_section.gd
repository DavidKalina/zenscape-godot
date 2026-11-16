extends RefCounted
## The hangar's pattern section (scripts/endless/ui/hangar_page.gd; the
## look's `pattern`, scripts/endless/plane_look.gd): a pattern picked from
## the catalogue (scripts/endless/plane_patterns.gd), None first, then its
## colour A or B set by hue, saturation and value or taken from the swatches.
## The contract is paint_section.gd's; its Pattern row is a `choice` row
## (hangar_page.gd). Every pattern is offered: nothing sells them yet.

const TITLE := "Pattern"
const Paint = preload("res://scripts/endless/ui/hangar/paint_section.gd")
const SLOTS: Array[String] = ["a","b"]
const SLOT_NAMES: Array[String] = ["Colour A","Colour B"]

var look := {}
## The colour being set: an index into SLOTS.
var slot := 0
## Each slot's hue, saturation and value, kept apart from its colour (a grey
## keeps its hue), and through None and a change of pattern once set.
var _hsv: Array[Vector3] = []
## Whether the pilot has set each slot's colour: until then a pattern picked
## comes in its own.
var _set_by_hand: Array[bool] = [false,false]

func begin(to: Dictionary) -> void:
	look = to
	slot = 0
	_hsv = [Vector3.ZERO,Vector3.ZERO]
	_set_by_hand = [false,false]
	var p := _pattern()
	for i in SLOTS.size():
		if p.is_empty(): continue
		_set_by_hand[i] = p.get(SLOTS[i]) is String
		_take(i,PlanePatterns.colour(p,SLOTS[i]))

## The look's pattern, {} when it has none there is.
func _pattern() -> Dictionary:
	var p: Variant = look.get("pattern")
	if p is Dictionary and not PlanePatterns.item(str(p.get("id",""))).is_empty(): return p
	return {}

## The index of the pattern worn in the Pattern row: 0 None, then the catalogue's.
func picked() -> int:
	var id := str(_pattern().get("id",""))
	for i in PlanePatterns.PATTERNS.size():
		if PlanePatterns.PATTERNS[i].id == id: return i+1
	return 0

func _take(i: int, c: Color) -> void:
	_hsv[i] = Vector3(c.h,c.s,c.v)

func colour(i: int) -> Color:
	return PlanePatterns.colour(_pattern(),SLOTS[i])

func rows() -> Array[Dictionary]:
	var names: Array[String] = ["None"]
	for p in PlanePatterns.PATTERNS: names.append(str(p.name))
	var out: Array[Dictionary] = [{"id":"pattern","label":"Pattern","kind":"choice","opts":names,"on":picked()}]
	var p := _pattern()
	if p.is_empty(): return out
	var two: bool = PlanePatterns.item(str(p.id)).two
	if not two: slot = 0
	var at := _hsv[slot]
	if two: out.append({"id":"slot","label":"Colour","kind":"seg","opts":["A","B"],"on":slot,"dots":[colour(0),colour(1)]})
	var hues: Array[Color] = []
	for i in 13: hues.append(Color.from_hsv(float(i)/12.0,maxf(at.y,0.35),maxf(at.z,0.5)))
	var now := colour(slot)
	var on := -1
	for i in Paint.SWATCHES.size():
		if Paint.SWATCHES[i].to_html(false) == now.to_html(false): on = i
	out.append_array([
		{"id":"hue","label":"Hue","kind":"slider","frac":at.x,"value":str(roundi(at.x*360.0)),"ramp":hues},
		{"id":"sat","label":"Saturation","kind":"slider","frac":at.y,"value":str(roundi(at.y*100.0)),"ramp":[Color.from_hsv(at.x,0.0,at.z),Color.from_hsv(at.x,1.0,at.z)]},
		{"id":"val","label":"Value","kind":"slider","frac":at.z,"value":str(roundi(at.z*100.0)),"ramp":[Color.from_hsv(at.x,at.y,0.0),Color.from_hsv(at.x,at.y,1.0)]},
		{"id":"swatch","label":"Swatch","kind":"swatches","colours":Paint.SWATCHES,"on":on},
	])
	return out

func change(id: String, dir: int) -> bool:
	var at := _hsv[slot]
	match id:
		"pattern": return _pick(posmod(picked()+dir,PlanePatterns.PATTERNS.size()+1))
		"slot":
			slot = clampi(slot+dir,0,SLOTS.size()-1)
			return false
		"hue": return _put(Vector3(fposmod(at.x+Paint.HUE_STEP*dir,1.0),at.y,at.z))
		"sat": return _put(Vector3(at.x,clampf(snappedf(at.y+Paint.STEP*dir,Paint.STEP),0.0,1.0),at.z))
		"val": return _put(Vector3(at.x,at.y,clampf(snappedf(at.z+Paint.STEP*dir,Paint.STEP),0.0,1.0)))
		"swatch":
			var now := colour(slot).to_html(false)
			var on := -1
			for i in Paint.SWATCHES.size():
				if Paint.SWATCHES[i].to_html(false) == now: on = i
			return _swatch(posmod(on+dir,Paint.SWATCHES.size()) if on >= 0 else (0 if dir > 0 else Paint.SWATCHES.size()-1))
	return false

func set_to(id: String, v: float) -> bool:
	var at := _hsv[slot]
	match id:
		"pattern": return _pick(clampi(int(v),0,PlanePatterns.PATTERNS.size()))
		"slot":
			slot = clampi(int(v),0,SLOTS.size()-1)
			return false
		"hue": return _put(Vector3(clampf(v,0.0,0.999),at.y,at.z))
		"sat": return _put(Vector3(at.x,clampf(v,0.0,1.0),at.z))
		"val": return _put(Vector3(at.x,at.y,clampf(v,0.0,1.0)))
		"swatch": return _swatch(int(v))
	return false

## Wears pattern `i` of the row (0 None): in the colours set by hand, its
## own for a slot not yet set.
func _pick(i: int) -> bool:
	if i == picked(): return false
	if i <= 0:
		look.erase("pattern")
		return true
	var row: Dictionary = PlanePatterns.PATTERNS[i-1]
	var p := {"id":row.id}
	for k in SLOTS.size():
		if _set_by_hand[k]: p[SLOTS[k]] = Color.from_hsv(_hsv[k].x,_hsv[k].y,_hsv[k].z).to_html(false)
		else:
			p[SLOTS[k]] = str(row[SLOTS[k]])
			_take(k,Color.html(p[SLOTS[k]]))
	look["pattern"] = p
	return true

func _swatch(i: int) -> bool:
	return _colour(Paint.SWATCHES[clampi(i,0,Paint.SWATCHES.size()-1)])

func _put(to: Vector3) -> bool:
	if to == _hsv[slot]: return false
	var hsv := to
	var changed := _colour(Color.from_hsv(to.x,to.y,to.z))
	# The hue and saturation as set, not as a grey or a black gives them back.
	_hsv[slot] = hsv
	return changed

func _colour(c: Color) -> bool:
	var p := _pattern()
	if p.is_empty(): return false
	_take(slot,c)
	_set_by_hand[slot] = true
	p[SLOTS[slot]] = Color(c.r,c.g,c.b).to_html(false)
	return true
