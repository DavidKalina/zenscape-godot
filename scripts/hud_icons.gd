extends RefCounted
## The HUD's faceted low-poly icons (design: "ZenScape HUD 4c", Claude Design
## project a0f03cdb, `design_handoff_lowpoly_linen_hud_4c/lowpoly.js`, the
## source of truth; docs/design/materials-tray/HUD-4c.md). Each icon is a
## silhouette (its fill paths, unioned as a clip) filled with a jittered 4x4
## triangle grid shaded along the top-left to bottom-right diagonal, with its
## line paths stroked over it, in a 24-unit box. The grid's jitter and noise
## come from a seeded LCG, so an icon is the same every run.
##
## Icons are built as SVG text here and rasterised at the size they are drawn
## (Image.load_svg_from_string), so nothing is baked to disk and exports need
## no source files. Hex colours only: the SVG importer reads rgba() as black.

## [name, sub, tint, fills, lines, seed, opacity, line width]
static var _items := {}

## The light and shade a facet leans to, and the locked (undiscovered) fill.
const LIGHT := Color("fffaf0")
const SHADE := Color("1a140e")
const LOCKED := Color("a89d8b")
## Facet grid: cells a side, how far a lit facet leans to LIGHT and a shaded
## one to SHADE, and the per-facet noise.
const N := 4
const LIFT := 1.3
const DROP := 1.1
const JITTER := 0.55
## The SVG's box: the 24-unit icon with PAD units round it, since facets
## run from -1 to 25 and some lines reach past the box.
const PAD := 2.0
const BOX := 24.0+PAD*2.0

## Variants: "icon" (faceted), "lit" (tint lit 10%, the held state), "shadow"
## (white silhouette with its lines, to tint as the drop shadow) and "locked"
## (white silhouette, no lines, to tint LOCKED).
static func svg(id: String, variant := "icon") -> String:
	var it: Dictionary = item(id)
	if it.is_empty(): return ""
	var body := ""
	var fills: Array = it.fills
	match variant:
		"shadow", "locked":
			for d: String in fills: body += '<path d="%s" fill="#ffffff"/>' % d
			if variant == "shadow":
				for d: String in it.lines:
					body += '<path d="%s" fill="none" stroke="#ffffff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d,_num(it.lw)]
		_:
			var base: Color = it.tint
			if variant == "lit": base = _mix(base,Color.WHITE,0.1)
			body += '<defs><clipPath id="s">'
			for d: String in fills: body += '<path d="%s"/>' % d
			body += '</clipPath></defs><g clip-path="url(#s)">'
			for tri: Dictionary in facets(int(it.seed),base):
				body += '<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="0.2"/>' % [tri.points,tri.fill,tri.fill]
			body += '</g>'
			var dark := _mix(it.tint,SHADE,0.45).to_html(false)
			for d: String in it.lines:
				body += '<path d="%s" fill="none" stroke="#%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d,dark,_num(it.lw)]
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">%s</svg>' % [int(BOX),int(BOX),_num(-PAD),_num(-PAD),_num(BOX),_num(BOX),body]

## A texture of `id` for an icon drawn `px` pixels across its 24-unit box.
## The texture covers BOX units, so draw it at `px*BOX/24` round the centre.
static func texture(id: String, variant: String, px: float) -> Texture2D:
	var source := svg(id,variant)
	if source.is_empty(): return null
	var image := Image.new()
	if image.load_svg_from_string(source,maxf(0.1,px/24.0)) != OK: return null
	return ImageTexture.create_from_image(image)

## The icon's data: {name, sub, label, tint, fills, lines, seed, opacity, lw}.
static func item(id: String) -> Dictionary:
	if _items.is_empty(): _build()
	return _items.get(id,{})

## The facet grid for `seed`, shaded from `base` (lowpoly.js `facets`).
static func facets(seed: int, base: Color) -> Array:
	var s := seed*131+7
	var step := 26.0/N
	var v: Array[Vector2] = []
	for y in range(N+1):
		for x in range(N+1):
			var edge := x == 0 or y == 0 or x == N or y == N
			var jx := 0.0
			var jy := 0.0
			if not edge:
				s = (s*9301+49297)%233280
				jx = (s/233280.0-0.5)*step*0.75
				s = (s*9301+49297)%233280
				jy = (s/233280.0-0.5)*step*0.75
			v.append(Vector2(-1.0+x*step+jx,-1.0+y*step+jy))
	var out := []
	for y in range(N):
		for x in range(N):
			var a := v[y*(N+1)+x]
			var b := v[y*(N+1)+x+1]
			var c := v[(y+1)*(N+1)+x]
			var d := v[(y+1)*(N+1)+x+1]
			var tris: Array = [[a,b,d],[a,d,c]] if (x+y)%2 == 1 else [[a,b,c],[b,d,c]]
			for q: Array in tris:
				var centre: Vector2 = (q[0]+q[1]+q[2])/3.0
				s = (s*9301+49297)%233280
				var t := (centre.x+centre.y)/48.0+(s/233280.0-0.5)*JITTER
				var fill := _mix(base,LIGHT,(0.5-t)*LIFT) if t < 0.5 else _mix(base,SHADE,(t-0.5)*DROP)
				var points := PackedStringArray()
				for p: Vector2 in q: points.append("%.2f,%.2f" % [p.x,p.y])
				out.append({"points":" ".join(points),"fill":fill.to_html(false)})
	return out

## lowpoly.js `mix`: per channel, rounded to 8 bits.
static func _mix(a: Color, b: Color, t: float) -> Color:
	t = clampf(t,0.0,1.0)
	return Color8(roundi(a.r8+(b.r8-a.r8)*t),roundi(a.g8+(b.g8-a.g8)*t),roundi(a.b8+(b.b8-a.b8)*t))

static func _num(x: float) -> String:
	return String.num(x,3)

# --- Data (lowpoly.js MATERIALS, RESERVE.stone, SHAPING_TOOLS) --------------------

static func _circle(x: float, y: float, r: float) -> String:
	return "M%.2f %.2f a%s %s 0 1 0 %s 0 a%s %s 0 1 0 %s 0Z" % [x-r,y,_num(r),_num(r),_num(2.0*r),_num(r),_num(r),_num(-2.0*r)]

static func _poly(points: Array) -> String:
	var parts := PackedStringArray()
	for p: Vector2 in points: parts.append("%.2f %.2f" % [p.x,p.y])
	return "M"+" L".join(parts)+"Z"

static func _bar(x0: float, y0: float, a: float, length: float, w: float) -> String:
	var n := Vector2(-sin(a),cos(a))*w*0.5
	var p0 := Vector2(x0,y0)
	var p1 := p0+Vector2(cos(a),sin(a))*length
	return _poly([p0+n,p1+n,p1-n,p0-n])

static func _snowflake() -> Array:
	var hexagon := []
	for k in range(6): hexagon.append(Vector2(12.0+3.4*cos(k*PI/3.0),12.0+3.4*sin(k*PI/3.0)))
	var out := [_poly(hexagon)]
	for k in range(6):
		var a := k*PI/3.0-PI/2.0
		var bx := 12.0+cos(a)*6.0
		var by := 12.0+sin(a)*6.0
		out.append_array([_bar(12.0,12.0,a,10.6,2.6),_bar(bx,by,a+0.9,4.0,2.1),_bar(bx,by,a-0.9,4.0,2.1)])
	return out

static func _add(id: String, name: String, sub: String, tint: String, fills: Array, lines: Array, seed: int, opacity := 1.0, lw := 1.8) -> void:
	_items[id] = {"id":id,"name":name,"sub":sub,"label":name+" · "+sub,"tint":Color(tint),"fills":fills,"lines":lines,"seed":seed,"opacity":opacity,"lw":lw}

static func _build() -> void:
	# Materials, keyed by what the hand holds (scripts/hand_materials.gd).
	_add("oak","Acorn","Oak","#c98a3e",["M5 10 Q12 3 19 10 Z","M6.5 10 Q6.5 20 12 22 Q17.5 20 17.5 10 Z"],["M12 5.5 V2.5"],0)
	_add("pine","Cone","Pine","#8a5a3a",["M12 2 Q18 8 16.5 15 Q15 20.5 12 22 Q9 20.5 7.5 15 Q6 8 12 2Z"],["M8 9 L16 15 M16 9 L8 15 M7.5 13 L12 17 L16.5 13"],1)
	_add("willow","Sprig","Willow","#7fa35a",["M10.2 22 Q10.2 12 14.2 2.6 L15.9 3.4 Q12.1 12.5 12.1 22Z","M11 16.8 Q3.2 16.8 2.2 9.4 Q10.2 9.8 11 16.8Z","M13.2 11.2 Q20.8 10.7 21.8 3.4 Q14 3.8 13.2 11.2Z","M11.4 21 Q18.4 21 20.6 14.6 Q13.4 14 11.4 21Z"],[],2)
	_add("wildflower","Clover","Meadow","#b8607a",[_circle(12,8,4.4),_circle(7.8,9.6,3),_circle(16.2,9.6,3),_circle(9.2,5,2.6),_circle(14.8,5,2.6),_circle(12,3.4,2.4),"M10.9 12 H13.1 V22.2 H10.9Z","M12.6 19.2 Q14 14.4 19.8 13.9 Q18.7 19 12.6 19.9Z"],[],3)
	var tufts := [_circle(11,9.6,5.4)]
	for k in range(12): tufts.append(_circle(11.0+6.3*cos(k*PI/6.0),9.6+6.3*sin(k*PI/6.0),1.55))
	tufts.append_array(["M10 14.5 H12 V22.4 H10Z",_circle(20.4,2.3,1.35)])
	var spokes := []
	for k in range(8):
		var a := k*PI/4.0+0.2
		spokes.append("M%.2f %.2f L%.2f %.2f" % [11.0+cos(a),9.6+sin(a),11.0+5.2*cos(a),9.6+5.2*sin(a)])
	spokes.append("M19.9 3.6 L18.7 6.2")
	_add("dandelion","Clock","Dandelion","#d6c290",tufts,spokes,4,1.0,0.8)
	_add("reed","Reed","Cattail","#8a5a34",["M8.8 4.2 Q8.8 2.6 12 2.6 Q15.2 2.6 15.2 4.2 V13.4 Q15.2 15.2 12 15.2 Q8.8 15.2 8.8 13.4Z","M11.35 3 V0.8 H12.65 V3Z","M10.9 14.6 H13.1 V22.6 H10.9Z","M12.6 22.6 Q16.6 17 18 7.2 Q20.2 10 19.4 13.6 Q18 19.6 14.8 22.6Z"],[],5)
	_add("water","Water","Spring","#4f8fc0",["M12 3 Q19 12 19 16 A7 7 0 0 1 5 16 Q5 12 12 3Z"],["M9 15 Q9 18 11.5 19"],6)
	_add("stone","River stone","Place","#8f8a86",["M2.5 14.5 C2.5 9.5 7.5 7.5 12.5 7.5 C18 7.5 21.5 10 21.5 14 C21.5 18 17 20 12 20 C6.5 20 2.5 18.5 2.5 14.5Z"],[],7)
	# Seeds with no slot in the case, reached through the command palette
	# (scripts/command_palette.gd): drawn as the tree they grow. Seeds 40-45.
	_add("birch","Samara","Birch","#d8c79a",[_circle(6.8,12,4.6),_circle(17.2,12,4.6),"M10.2 6.6 Q12 4.8 13.8 6.6 V17.4 Q12 19.2 10.2 17.4Z"],["M12 7.5 V16.5"],40)
	_add("redwood","Redwood","Giant","#a0563a",["M12 1.2 L15.4 7.6 H13.9 L16.8 13.4 H15.1 L18.2 19 H13.3 V22.8 H10.7 V19 H5.8 L8.9 13.4 H7.2 L10.1 7.6 H8.6Z"],["M12 9 V19"],41)
	_add("juniper","Juniper","Berry","#64749c",[_circle(8.6,14.2,4.2),_circle(15.4,14.2,4.2),_circle(12,8.4,4.2),"M11.2 17.6 H12.8 V23 H11.2Z"],["M12 4.6 L12.6 3.4"],42)
	_add("joshua","Joshua","Desert","#9a9658",["M10.8 22.6 V13.4 L7 10.4 V6.6 H9.2 V9.4 L10.8 10.8 V5.6 H13.2 V12.2 L15 10.6 V5.4 H17.2 V11.6 L13.2 15 V22.6Z",_circle(8.1,5.2,2.6),_circle(12,4.4,2.6),_circle(16.1,4.2,2.6)],[],43)
	# The palette's pockets: All (four squares) and Life (a big bare footprint).
	_add("all","All","Everything","#d6c290",["M3 4 Q3 3 4 3 H10 Q11 3 11 4 V10 Q11 11 10 11 H4 Q3 11 3 10Z","M13 4 Q13 3 14 3 H20 Q21 3 21 4 V10 Q21 11 20 11 H14 Q13 11 13 10Z","M3 14 Q3 13 4 13 H10 Q11 13 11 14 V20 Q11 21 10 21 H4 Q3 21 3 20Z","M13 14 Q13 13 14 13 H20 Q21 13 21 14 V20 Q21 21 20 21 H14 Q13 21 13 20Z"],[],44)
	_add("track","Track","Life","#8a6a4a",["M8 11 Q8 6.4 12.2 6.4 Q16.6 6.4 16.6 11.2 Q16.6 15 14.8 18 Q13.8 22.4 11.2 22.4 Q8 22.4 8 18.4Z",_circle(7.4,4.4,1.5),_circle(10.2,2.8,1.5),_circle(13.1,2.5,1.45),_circle(15.8,3.4,1.3),_circle(17.8,5.4,1.15)],[],45)
	# The Life pocket's creatures and signs (seeds 46-54): see `_life` below.
	_life()
	_add("crystal","Crystal","Quartz","#9b7fc9",["M7.5 21 L5.5 11 L8.5 6 L11.5 11 L9.5 21Z","M13 21 L12 8 L15 3 L18 8 L16.5 21Z"],[],8)
	_add("snow","Frost","Winter","#7fbfd0",_snowflake(),[],9)
	# Shaping tools (the tool roll).
	# The Modeller (id "hand", the roll's first pocket, once the bare Hand's): a
	# boxwood modelling tool laid on the diagonal, its spatula down to the left.
	var modeller := _modeller()
	_add("hand","Modeller","Mould","#e0a07a",modeller[0],modeller[1],10,1.0,1.2)
	_add("paddle","Paddle","Mass","#c49a5e",["M5.5 12 Q5.5 9.5 8 9.5 H16 Q18.5 9.5 18.5 12 V19 Q18.5 22 15.5 22 H8.5 Q5.5 22 5.5 19Z","M10.7 9.6 V2.9 A1.3 1.3 0 0 1 13.3 2.9 V9.6Z"],["M9 13 V19 M15 13 V19","M10.9 5.6 H13.1"],11)
	_add("chisel","Chisel","Cut","#6f8aa6",["M6 2.8 Q6 2 6.8 2 H10.2 Q11 2 11 2.8 V10.5 H6Z","M6.8 10.5 H10.2 V18.5 L9.2 21.8 H7.8 L6.8 18.5Z","M13 4 Q13 3 14 3 H21 Q22 3 22 4 V8.5 Q22 9.5 21 9.5 H14 Q13 9.5 13 8.5Z","M16.6 9.5 H18.4 V21 Q18.4 22 17.5 22 Q16.6 22 16.6 21Z"],["M5.8 10.5 H11.2","M6.8 18.5 H10.2","M15.5 3 V9.5"],12)
	_add("wire","Wire","Slice","#b8683f",["M8.6 20.9 L6.6 22.9 L1.1 17.4 L3.1 15.4Z","M22.9 6.6 L20.9 8.6 L15.4 3.1 L17.4 1.1Z"],["M6.2 17.8 L17.8 6.2"],13)
	_add("hammer","Hammer","Break","#7a6a5a",["M3 5.5 Q3 4.5 4 4.5 H15 L20.5 7.2 L15 9.8 H4 Q3 9.8 3 8.8Z","M8.2 9.8 H10.8 V20.8 A1.3 1.3 0 0 1 8.2 20.8Z"],["M12.5 4.5 V9.8"],14)
	# The Feather, "Gust" (HUD 5, lowpoly.js SHAPING_TOOLS[5]): wind held in
	# hand, below the tools after the roll's divider. A finer quill line (1.2).
	_add("feather","Feather","Gust","#cbb994",["M4.6 21.2 Q5.4 11 17.6 2.8 Q19.6 1.8 20.6 3.2 Q21.2 4.6 19.8 6.6 Q12.8 17.4 4.6 21.2Z"],["M3.2 22.6 L17.2 6","M9.4 15.2 L6.6 14.4","M12.6 11.4 L10 10.2","M11.6 15.2 L14.4 14.6","M15 11 L17.4 10.8"],15,1.0,1.2)
	# --- HUD 5 foot icons (docs/design/hud-5/lowpoly.js ROLL_FOOT; the tool
	# roll's foot, scripts/tool_foot.gd). Undo seed 21, Photo seed 22. -------------
	_add("undo","Undo","Back","#b5a78c",_undo_arrow(),[],21)
	_add("photo","Camera","Photo","#8f8a86",["M3 8.2 Q3 6.6 4.6 6.6 H8 L9.6 4.4 H14.4 L16 6.6 H19.4 Q21 6.6 21 8.2 V17.8 Q21 19.4 19.4 19.4 H4.6 Q3 19.4 3 17.8Z"],["M15.6 13 A3.6 3.6 0 1 0 8.4 13 A3.6 3.6 0 1 0 15.6 13","M17.6 9.2 L17.7 9.2"],22,1.0,1.5)
	# --- HUD 5 almanac icons (docs/design/hud-5/lowpoly.js AIR_ICONS, seeds
	# 16-20; docs/design/hud-5/ALMANAC.md). The almanac's pockets drawn as
	# their gestures: the sun and the moon (Time), the plate from above in
	# each season's tint (Season), the snow globe (Weather) and the windsock
	# at each droop the strip draws (Wind: sock_id). Kept in this one block
	# so the HUD 5 branches merge simply.
	var rays := [_circle(12,12,5.2)]
	for k in range(8):
		var a := k*PI/4.0
		rays.append(_bar(12.0+cos(a)*7.2,12.0+sin(a)*7.2,a,3.2,2.2))
	_add("sun","Sun","Day","#e2b25e",rays,[],16)
	_add("moon","Moon","Night","#c9cfdf",[_crescent()],[],17)
	for season: String in SEASON_TINT:
		_add("plate_"+season,"Plate",season.capitalize(),SEASON_TINT[season],["M12 4.4 L21.4 9.6 L12 14.8 L2.6 9.6Z","M2.6 9.6 L12 14.8 L21.4 9.6 L21.4 12.6 L12 18 L2.6 12.6Z",_circle(20.3,16.8,1.2)],["M2.6 9.6 L12 14.8 L21.4 9.6","M4 17.4 Q12 22.8 19.2 17.6"],18,1.0,1.3)
	_add("globe","Globe","Weather","#9fb4c0",[_circle(12,10,7.6),"M6 16.6 H18 L19.6 21.4 Q19.7 22 19.1 22 H4.9 Q4.3 22 4.4 21.4Z"],["M5.4 17.6 H18.6","M5.6 13.2 Q12 9.8 18.4 13.2","M9 6.6 L9 6.7 M14.6 5.6 L14.6 5.7 M12 9 L12 9.1 M16 9.6 L16 9.7 M7.6 10.2 L7.6 10.3"],19,1.0,1.5)
	for deg: int in SOCK_DROOPS: _add(sock_id(deg),"Sock","Wind","#c47c5c",_windsock(deg)[0],_windsock(deg)[1],20,1.0,1.4)

# --- Life (the command palette's Life pocket, scripts/command_palette.gd LIFE) ---
# Each creature as a naturalist's stamp: a profile facing right where it
# matters, in one muted tint. Seeds 46-54. Bigfoot's "bigfoot" (the Patterson
# look-back, watching you) and "bigfoot_stride" share his russet with "howl"
# (his head thrown back, the call's arcs); his tracks reuse "track" above.

static func _life() -> void:
	_add("deer","Deer","Wood's edge","#b98a5c",_deer(),["M18.6 5.4 L18.7 5.4"],46,1.0,1.2)
	var heron := _heron()
	_add("heron","Heron","Wading","#7f93a3",heron[0],heron[1],47,1.0,1.2)
	var snake := _snake()
	_add("snake","Snake","By the pond","#7d8048",snake[0],snake[1],48,1.0,1.2)
	var watch := _bigfoot_watch()
	_add("bigfoot","Bigfoot","Watching","#6e4a34",watch[0],watch[1],49,1.0,1.1)
	var stride := _bigfoot_stride()
	_add("bigfoot_stride","Bigfoot","Striding","#6e4a34",stride[0],stride[1],50,1.0,1.2)
	var howl := _howl()
	_add("howl","Howl","A sign","#6e4a34",howl[0],howl[1],51,1.0,1.2)
	var woodpecker := _woodpecker()
	_add("woodpecker","Woodpecker","On a snag","#8a3a30",woodpecker[0],woodpecker[1],52,1.0,1.2)
	_add("geese","Geese","Passing over","#8a7f6c",_geese(),[],53)
	var bow := _rainbow()
	_add("rainbow","Rainbow","After rain","#c98a7a",bow[0],bow[1],54,1.0,1.2)

## A band along `spine` (Vector2s), `widths` across at each point.
static func _ribbon(spine: Array, widths: Array) -> String:
	var left := []
	var right := []
	for i in range(spine.size()):
		var a: Vector2 = spine[maxi(0,i-1)]
		var b: Vector2 = spine[mini(spine.size()-1,i+1)]
		var n := (b-a).normalized().orthogonal()*float(widths[i])*0.5
		left.append(spine[i]+n)
		right.push_front(spine[i]-n)
	return _poly(left+right)

## An arc round `c`, radius `r`, from angle `a0` to `a1`, `w` across.
static func _arc(c: Vector2, r: float, a0: float, a1: float, w: float) -> String:
	var spine := []
	var widths := []
	for i in range(17):
		spine.append(c+Vector2.from_angle(lerpf(a0,a1,i/16.0))*r)
		widths.append(w)
	return _ribbon(spine,widths)

## Points as Vector2s from a flat [x, y, x, y...] list.
static func _pts(xy: Array) -> Array:
	var out := []
	for i in range(0,xy.size(),2): out.append(Vector2(xy[i],xy[i+1]))
	return out

## A stag in profile: body, neck and head, four legs and a pair of antlers.
static func _deer() -> Array:
	var out := [
		_poly(_pts([4.6,10.6, 8,9.4, 13.6,9.4, 16,10.2, 16.4,13, 14.6,15, 6.6,15.2, 4.4,13.6])),
		_poly(_pts([4.8,10.6, 3,10, 4.2,12.2])),
		_poly(_pts([13.2,10, 15.8,5, 18.4,5.4, 16.8,11.6])),
		_poly(_pts([16,4.8, 17.6,3.8, 21.8,6.2, 21.4,7.4, 18.4,7.6, 16.4,6.8])),
		_poly(_pts([16.4,5, 13.8,3.6, 15.6,3.4, 17.2,4.2])),
	]
	for x: float in [5.8,7.4,14.2,15.6]: out.append(_bar(x,13.6,PI*0.5,8.8,1.3))
	out.append_array([_bar(17.4,4.2,-1.95,4.6,1.1),_bar(16.5,2.4,-1.1,2.6,0.9),_bar(18.4,4.2,-1.55,4.4,1.1),_bar(18.4,2.0,-0.7,2.4,0.9)])
	return out

## A grey heron wading: body, S neck, dagger bill and stilt legs. [fills, lines].
static func _heron() -> Array:
	return [[
		_poly(_pts([4.6,15.6, 7.6,11, 11,9, 14,9.4, 14.6,11.6, 12.6,14.4, 9,15.4])),
		_ribbon(_pts([13,10.4, 15.4,8.6, 14.6,6, 15.4,3.8, 17,3]),[2.4,1.7,1.5,1.6,2.4]),
		_circle(17,3.2,1.7),
		_poly(_pts([17.6,2.3, 23.4,3.9, 17.8,4.4])),
		_bar(10.8,14.4,PI*0.5+0.03,8.2,1.0),
		_bar(12.2,14.2,PI*0.5-0.17,8.4,1.0),
	],["M15.6 2.4 L12.6 2.6"]]

## A snake in an S along the ground, head raised to the right. [fills, lines].
static func _snake() -> Array:
	var spine := []
	var widths := []
	for i in range(25):
		var t := i/24.0
		spine.append(Vector2(2.0+t*15.0,15.0-4.8*sin(t*TAU)))
		widths.append(lerpf(0.8,4.0,sqrt(t)))
	var head := _poly(_pts([15.6,13, 17.6,10.6, 20.6,9.8, 22.6,10.8, 22.6,12.2, 19.4,14.6, 16.2,17]))
	return [[_ribbon(spine,widths),head],["M19.8 11.4 L19.9 11.4"]]

## Bigfoot watching: the Patterson look-back, his stooped body side-on to
## the right and his peaked head turned to face you, his near arm hanging
## long past the hip. [fills, lines].
static func _bigfoot_watch() -> Array:
	var body := _poly(_pts([13.2,2.2, 14.8,3, 15.4,5, 15.2,6.6, 17.6,7.8, 18.4,10.4, 17.8,13.4, 16.8,15.6,
		17,19, 16.8,21.6, 19,22.4, 19,22.9, 13.6,22.9, 13.8,21.4, 13.4,18.8, 12.6,18.6,
		12.4,21.6, 13.2,22.9, 8.6,22.9, 9.4,21.6, 9.2,17.4, 8.4,14, 8.4,10, 9.6,6.6, 11.2,5.8, 11,5, 11.6,3]))
	var arm := _ribbon(_pts([14.2,8, 16.6,12.2, 17.8,17]),[3.2,2.6,2.4])
	return [[body,arm],["M12.4 4.8 L12.5 4.8 M14 4.8 L14.1 4.8","M12.4 9 Q14 12.8 16 17.2"]]

## Bigfoot side-on in the Patterson stride, facing right: peaked head thrust
## forward, hunched back, the far arm swung back and the near one forward,
## legs in mid-step. [fills, lines].
static func _bigfoot_stride() -> Array:
	var body := _poly(_pts([12.8,2.4, 15,2.8, 16.8,4.2, 16.4,5, 17.2,6.4, 16.2,7.6, 15.6,7.8, 17.2,9, 17.4,10.8, 16.6,13.4, 15.8,15.4,
		18.8,17.6, 18.8,21.4, 21.6,22.3, 21.6,22.9, 17,22.9, 16.8,21.4, 16.2,18.8, 13.4,17.2,
		11,19.4, 8,21.4, 8.8,22.9, 4.8,22.9, 5.4,21.6, 9.4,18.4, 10.2,16, 10,12.4, 10.2,8.6, 11.2,5.8, 12.4,4.6]))
	var back_arm := _ribbon(_pts([11.8,7.6, 8.8,11.8, 6.2,15.2]),[3,2.2,2.2])
	var fore_arm := _ribbon(_pts([14.4,8.4, 17.2,12.6, 19.2,16.6]),[3.2,2.4,2.2])
	return [[body,back_arm,fore_arm],["M15.6 5 L15.7 5","M12.8 9.6 Q14.8 12.6 17.6 17"]]

## The howl: Bigfoot's head and shoulders, the head (drawn facing right, then
## turned 55 degrees up round `at`) thrown back with its mouth open, and the
## call going out from the mouth in two arcs. [fills, lines].
static func _howl() -> Array:
	var at := Vector2(8.4,9.8)
	var up := func(p: Vector2) -> Vector2: return at+p.rotated(-0.96)*1.15
	var head: Array = _pts([-3.4,2.4, -3.2,-1.2, -1.6,-4.4, 1.6,-3.2, 3,-2, 2.6,-1.2, 3.6,0, 3.4,0.8, 1.4,1.4, 3.2,2.4, 2.6,3.8, 0.4,4.4]).map(up)
	var body := _poly(_pts([1,23, 1.4,18.6, 3,15.4])+head+_pts([13.6,14.4, 16,17.4, 17,23]))
	var mouth: Vector2 = up.call(Vector2(1.4,1.4))
	var eye: Vector2 = up.call(Vector2(2.2,-1.4))
	return [[body,_arc(mouth,4.8,-1.65,-0.15,1.6),_arc(mouth,8.0,-1.55,-0.25,1.6)],["M%.2f %.2f L%.2f %.2f" % [eye.x,eye.y,eye.x+0.1,eye.y]]]

## A woodpecker on a snag: clinging upright, bill to the trunk, tail propped
## against it, the dead trunk's top broken off. [fills, lines].
static func _woodpecker() -> Array:
	var bird := _poly(_pts([8,3.4, 11,2.6, 13,3.8, 13.6,5, 18.4,6, 13.6,6.8, 13.2,8.4, 14.8,11, 15.8,15.2, 15.6,18, 18.4,22.6, 16.8,22.8, 12.4,19.4, 9.6,17.4, 8,13, 8.6,8.4, 9.2,6.2]))
	var snag := _poly(_pts([18.2,24.6, 18.2,3.2, 19.2,1.6, 20,2.8, 21.2,0.6, 21.2,24.6]))
	return [[bird,snag,_bar(15,14.4,0.25,3.4,1.0)],["M8.8 4.6 Q10.6 2.8 12.8 4.2","M9.8 9 Q12.2 12.6 11 17"]]

## A skein of five geese in a V, flying away up the sky.
static func _geese() -> Array:
	var out := []
	var wings := _pts([-4.2,0.2, -2.2,-2, 0,-0.6, 2.2,-2, 4.2,0.2, 2.2,-0.2, 0,1.8, -2.2,-0.2])
	for at: Vector2 in _pts([12,5, 7.6,9.6, 3.4,14.2, 16.4,9.6, 20.6,14.2]):
		out.append(_poly(wings.map(func(p: Vector2) -> Vector2: return at+p)))
	return out

## A rainbow: three bands over the land, a cloud at each foot. [fills, lines].
static func _rainbow() -> Array:
	var c := Vector2(12,19)
	return [[_arc(c,9.4,PI,TAU,5.6),_circle(3.4,19.6,2.2),_circle(5.6,18.6,2.4),_circle(7.6,20.4,1.6),"M1.2 19.6 H9.2 V22 H1.2Z",_circle(16.4,20.4,1.6),_circle(18.4,18.6,2.4),_circle(20.6,19.6,2.2),"M14.8 19.6 H22.8 V22 H14.8Z"],[
		"M%.2f %.2f A8.5 8.5 0 0 1 %.2f %.2f" % [3.5,19.0,20.5,19.0],"M%.2f %.2f A10.3 10.3 0 0 1 %.2f %.2f" % [1.7,19.0,22.3,19.0]]]

## The Modeller's icon: a boxwood modelling tool from the spatula's centre at
## (5.8, 18.2) up the diagonal to its point, [fills, lines]. The spatula is an
## oval sampled to a polygon (5 along, 3.5 across); the shaft flares from a
## neck at 4 to 1.35 across by 6.8 and runs to a point at 20. A band marks
## the grip at 12.6, and a short line down the spatula its thumb-worn hollow.
static func _modeller() -> Array:
	var centre := Vector2(5.8,18.2)
	var along := Vector2(1.0,-1.0).normalized()
	var across := Vector2(1.0,1.0).normalized()
	var at := func(t: float, w: float) -> Vector2: return centre+along*t+across*w
	var oval := []
	for k in range(16):
		var a := k*TAU/16.0
		oval.append(at.call(cos(a)*5.0,sin(a)*3.5))
	var shaft := [at.call(4.0,0.9),at.call(6.8,1.35),at.call(17.0,1.35),at.call(20.0,0.0),at.call(17.0,-1.35),at.call(6.8,-1.35),at.call(4.0,-0.9)]
	var band: Array = [at.call(12.6,1.35),at.call(12.6,-1.35)]
	var hollow: Array = [at.call(-2.2,0.0),at.call(1.4,0.0)]
	var lines := []
	for pair: Array in [band,hollow]: lines.append("M%.2f %.2f L%.2f %.2f" % [pair[0].x,pair[0].y,pair[1].x,pair[1].y])
	return [[_poly(oval),_poly(shaft)],lines]

## HUD 5 foot: the undo arrow, sampled as lowpoly.js does (`ub`, no masks): a
## half ring round (12.8, 13.4), outer radius 7.8 and inner 4.6, from the left
## over the top to the right in 24 steps, and the arrowhead under its left end.
static func _undo_arrow() -> Array:
	var centre := Vector2(12.8,13.4)
	var ring := []
	for i in range(25): ring.append(centre+Vector2.from_angle(-PI+i/24.0*PI)*7.8)
	for i in range(24,-1,-1): ring.append(centre+Vector2.from_angle(-PI+i/24.0*PI)*4.6)
	var head := [centre+Vector2(-2.6,-0.2),centre+Vector2(-9.8,-0.2),centre+Vector2(-6.2,5.6)]
	return [_poly(ring),_poly(head)]

# --- HUD 5 page icons and vignettes (design "ZenScape HUD 5 Air") -----------------
# docs/design/hud-5/lowpoly.js `vignette()` and VIGNETTE_SIZES; the almanac's
# pages (scripts/almanac_pages.gd) draw them. Everything HUD 5's pages add to
# this file lives in this block.

## The vignette's own box (lowpoly.js: viewBox 40x25, stretched to the card).
const VIGNETTE_BOX := Vector2(40.0,25.0)
## Sizes it is drawn at, design pixels: the strip's Mood pocket, a Moods page
## card, the This world row and a Customise mini.
const VIGNETTE_SIZES := {"strip":Vector2(44.0,28.0),"card":Vector2(78.0,49.0),"world":Vector2(56.0,35.0),"mini":Vector2(22.0,14.0)}
## The clips, in the box: the horizon band the glow shows through, the slab's
## top the land shows through, and the slab's flat side.
const VIGNETTE_GLOW := "M0 10.5 L40 8.6 L40 16.4 L0 17.6Z"
const VIGNETTE_LAND := "M3 18.2 L20 13.4 L37.5 16.8 L21 22.2Z"
const VIGNETTE_SIDE := "M3 18.2 L21 22.2 L37.5 16.8 L37.5 19.4 L21 25.5 L3 20.8Z"
## The sun or moon: radius and x in the box; y high, and low for the hours
## near the horizon. Its colours: the night's moon and the day's sun (a low
## sun is the glow lit 55% toward LIGHT).
const VIGNETTE_DISC := Vector3(1.9,30.0,5.5)
const VIGNETTE_DISC_LOW_Y := 10.0
const VIGNETTE_MOON := Color("e6eaf2")
const VIGNETTE_SUN := Color("fff3d6")
## A slab side is the grass this far toward SHADE.
const VIGNETTE_SIDE_SHADE := 0.55

## A mood's vignette as SVG text: `seed` (lowpoly.js 23..32), its sky, glow and
## grass, and its hour, "night", "low" (dawn, golden hour, dusk) or "high".
## Three facet grids (sky over the card, glow in the horizon band, land on the
## slab's top), the slab's flat side and the disc, `size` pixels.
static func vignette_svg(seed: int, sky: Color, glow: Color, grass: Color, hour: String, size: Vector2) -> String:
	var body := '<defs><clipPath id="g"><path d="%s"/></clipPath><clipPath id="l"><path d="%s"/></clipPath></defs>' % [VIGNETTE_GLOW,VIGNETTE_LAND]
	var stretch := 'transform="scale(%s %s)"' % [_num(VIGNETTE_BOX.x/24.0),_num(VIGNETTE_BOX.y/24.0)]
	var layers := [[seed,sky,""],[seed+40,glow,"g"],[seed+80,grass,"l"]]
	for layer: Array in layers:
		var group := ""
		for tri: Dictionary in facets(int(layer[0]),_mix(layer[1],layer[1],0.0)):
			group += '<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="0.2"/>' % [tri.points,tri.fill,tri.fill]
		group = '<g %s>%s</g>' % [stretch,group]
		body += group if str(layer[2]).is_empty() else '<g clip-path="url(#%s)">%s</g>' % [layer[2],group]
	body += '<path d="%s" fill="#%s"/>' % [VIGNETTE_SIDE,_mix(grass,SHADE,VIGNETTE_SIDE_SHADE).to_html(false)]
	var disc := VIGNETTE_MOON if hour == "night" else _mix(glow,LIGHT,0.55) if hour == "low" else VIGNETTE_SUN
	var y := VIGNETTE_DISC_LOW_Y if hour == "low" else VIGNETTE_DISC.z
	body += '<circle cx="%s" cy="%s" r="%s" fill="#%s"/>' % [_num(VIGNETTE_DISC.y),_num(y),_num(VIGNETTE_DISC.x),disc.to_html(false)]
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s" preserveAspectRatio="none">%s</svg>' % [
		maxi(1,roundi(size.x)),maxi(1,roundi(size.y)),_num(VIGNETTE_BOX.x),_num(VIGNETTE_BOX.y),body]

## The vignette rasterised `size` pixels (its box stretched to fit).
static func vignette_texture(seed: int, sky: Color, glow: Color, grass: Color, hour: String, size: Vector2) -> Texture2D:
	var image := Image.new()
	if image.load_svg_from_string(vignette_svg(seed,sky,glow,grass,hour,size),1.0) != OK: return null
	return ImageTexture.create_from_image(image)

## HUD 5 almanac: the season tints (lowpoly.js SEASON_TINT), keyed by
## mood_look.gd's season ids.
const SEASON_TINT := {"spring":"#93b86c","summer":"#6c9a4a","autumn":"#c27c3e","winter":"#cfd8de"}
## HUD 5 almanac: every droop (degrees below level) the windsock is drawn at:
## the four strengths (lowpoly.js WIND_DROOP 40, 22, 10, 0), the cue's
## halfway droops (20, 11, 5) and its lift just past level (-2).
const SOCK_DROOPS := [40,22,20,11,10,5,0,-2]

## HUD 5 almanac: the windsock's icon id at a droop in SOCK_DROOPS.
static func sock_id(deg: int) -> String:
	return "sock_%d" % deg

## HUD 5 almanac: lowpoly.js `windsock`: the pole, and the sock and its two
## bands turned about (5.2, 8.2) by the droop. [fills, lines].
static func _windsock(deg: float) -> Array:
	var a := deg_to_rad(deg)
	var pivot := Vector2(5.2,8.2)
	var turn := func(p: Vector2) -> Vector2: return pivot+(p-pivot).rotated(a)
	var sock := [Vector2(5.2,4.2),Vector2(21,6.6),Vector2(21,10.4),Vector2(5.2,12.2)].map(turn)
	var lines := []
	for band: Array in [[Vector2(10.4,5),Vector2(10.4,11.6)],[Vector2(15.6,5.8),Vector2(15.6,11)]]:
		var p0: Vector2 = turn.call(band[0])
		var p1: Vector2 = turn.call(band[1])
		lines.append("M%.2f %.2f L%.2f %.2f" % [p0.x,p0.y,p1.x,p1.y])
	return [["M3.4 2.4 H5.2 V22.4 H3.4Z",_poly(sock)],lines]

## HUD 5 almanac: lowpoly.js `crescent`: the circle at (11, 12.4) r 8.6 less
## the one at (15.8, 8.4) r 7.4, sampled to one polygon (no masks).
static func _crescent() -> String:
	var c1 := Vector2(11,12.4)
	var c2 := Vector2(15.8,8.4)
	var r1 := 8.6
	var r2 := 7.4
	var n := 120
	var outer := []
	var inner := []
	var a2 := (c2-c1).angle()
	for i in range(n):
		var p := c1+Vector2.from_angle(a2+float(i)/n*TAU)*r1
		if p.distance_to(c2) >= r2: outer.append(p)
	var a1 := (c1-c2).angle()+PI
	for i in range(n):
		var p := c2+Vector2.from_angle(a1+float(i)/n*TAU)*r2
		if p.distance_to(c1) < r1: inner.append(p)
	var last: Vector2 = outer.back()
	if (inner.back() as Vector2).distance_to(last) < (inner[0] as Vector2).distance_to(last): inner.reverse()
	return _poly(outer+inner)
