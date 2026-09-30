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
	_add("crystal","Crystal","Quartz","#9b7fc9",["M7.5 21 L5.5 11 L8.5 6 L11.5 11 L9.5 21Z","M13 21 L12 8 L15 3 L18 8 L16.5 21Z"],[],8)
	_add("snow","Frost","Winter","#7fbfd0",_snowflake(),[],9)
	# Shaping tools (the tool roll).
	_add("hand","Hand","Mould","#e0a07a",["M7 11.5 Q7 10 8.5 10 L16.5 10.5 Q18 10.6 17.8 12 L17 17 Q16 21.5 12 21.5 Q8 21.5 7.3 17Z","M7.2 11 L7 5.4 A1.25 1.25 0 0 1 9.5 5.3 L9.7 11Z","M10 10.5 L10.2 3.4 A1.25 1.25 0 0 1 12.7 3.5 L12.5 10.6Z","M12.9 10.7 L13.5 4.4 A1.2 1.2 0 0 1 15.9 4.7 L15.3 11Z","M15.6 11.2 L16.6 6.6 A1.1 1.1 0 0 1 18.7 7.1 L17.7 12Z","M7.6 15.5 L3.8 11.8 A1.3 1.3 0 0 1 5.6 9.9 L9.2 13Z"],["M9.5 15.5 Q12 17 15 14.8"],10,0.82)
	_add("paddle","Paddle","Mass","#c49a5e",["M5.5 12 Q5.5 9.5 8 9.5 H16 Q18.5 9.5 18.5 12 V19 Q18.5 22 15.5 22 H8.5 Q5.5 22 5.5 19Z","M10.7 9.6 V2.9 A1.3 1.3 0 0 1 13.3 2.9 V9.6Z"],["M9 13 V19 M15 13 V19","M10.9 5.6 H13.1"],11)
	_add("chisel","Chisel","Cut","#6f8aa6",["M6 2.8 Q6 2 6.8 2 H10.2 Q11 2 11 2.8 V10.5 H6Z","M6.8 10.5 H10.2 V18.5 L9.2 21.8 H7.8 L6.8 18.5Z","M13 4 Q13 3 14 3 H21 Q22 3 22 4 V8.5 Q22 9.5 21 9.5 H14 Q13 9.5 13 8.5Z","M16.6 9.5 H18.4 V21 Q18.4 22 17.5 22 Q16.6 22 16.6 21Z"],["M5.8 10.5 H11.2","M6.8 18.5 H10.2","M15.5 3 V9.5"],12)
	_add("wire","Wire","Slice","#b8683f",["M8.6 20.9 L6.6 22.9 L1.1 17.4 L3.1 15.4Z","M22.9 6.6 L20.9 8.6 L15.4 3.1 L17.4 1.1Z"],["M6.2 17.8 L17.8 6.2"],13)
	_add("hammer","Hammer","Break","#7a6a5a",["M3 5.5 Q3 4.5 4 4.5 H15 L20.5 7.2 L15 9.8 H4 Q3 9.8 3 8.8Z","M8.2 9.8 H10.8 V20.8 A1.3 1.3 0 0 1 8.2 20.8Z"],["M12.5 4.5 V9.8"],14)
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
