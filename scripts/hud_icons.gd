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
	_add("wildflower","Wildflower","Meadow","#b8607a",[_circle(12,8,4.4),_circle(7.8,9.6,3),_circle(16.2,9.6,3),_circle(9.2,5,2.6),_circle(14.8,5,2.6),_circle(12,3.4,2.4),"M10.9 12 H13.1 V22.2 H10.9Z","M12.6 19.2 Q14 14.4 19.8 13.9 Q18.7 19 12.6 19.9Z"],[],3)
	var tufts := [_circle(11,9.6,5.4)]
	for k in range(12): tufts.append(_circle(11.0+6.3*cos(k*PI/6.0),9.6+6.3*sin(k*PI/6.0),1.55))
	tufts.append_array(["M10 14.5 H12 V22.4 H10Z",_circle(20.4,2.3,1.35)])
	var spokes := []
	for k in range(8):
		var a := k*PI/4.0+0.2
		spokes.append("M%.2f %.2f L%.2f %.2f" % [11.0+cos(a),9.6+sin(a),11.0+5.2*cos(a),9.6+5.2*sin(a)])
	spokes.append("M19.9 3.6 L18.7 6.2")
	_add("dandelion","Clock","Dandelion","#d6c290",tufts,spokes,4,1.0,0.8)
	# Flower seed (scripts/flower_sowing.gd SLOTS), seeds 57-59: the flower each
	# grows. A poppy's four broad petals cupped round its dark cross, with a
	# nodding bud; cosmos's eight notched petals round a dark eye on a wiry
	# stem; a sunflower's ring of pointed petals round its ringed disc, a
	# heart leaf on its thick stem.
	_add("poppy","Poppy","Field","#cf4a3a",[_circle(11.5,5.4,3.6),_circle(8.2,7.8,4.0),_circle(14.8,7.8,4.0),_circle(9.4,11.0,3.5),_circle(13.6,11.0,3.5),
		"M10.6 13.6 Q11.2 18 11.2 22.6 H12.8 Q12.8 18 12.4 13.6Z","M12.2 18.6 Q16.2 13.4 19.4 15.2 L18.8 16.2 Q16.4 15 12.8 19.6Z",_circle(19.2,17.4,1.7)],
		["M9.7 9.6 L13.3 9.6","M11.5 7.8 V11.4"],57,1.0,1.4)
	var cosmos := [_circle(12.0,9.4,2.0),"M11.4 11 Q10.4 16.8 11.6 22.6 H12.8 Q11.8 16.8 12.6 11Z"]
	for k in range(8):
		var a := k*PI/4.0+0.2
		var way := Vector2.from_angle(a)
		var side := way.orthogonal()
		var petal := []
		for tw: Vector2 in [Vector2(1.4,0.6),Vector2(5.4,1.9),Vector2(7.8,1.3),Vector2(7.0,0.0),Vector2(7.8,-1.3),Vector2(5.4,-1.9),Vector2(1.4,-0.6)]:
			petal.append(Vector2(12.0,9.4)+way*tw.x+side*tw.y)
		cosmos.append(_poly(petal))
	_add("cosmos","Cosmos","Drift","#d47aa6",cosmos,[_circle(12.0,9.4,1.0),"M11.9 19.8 Q15 18.6 17 15.8"],58,1.0,1.3)
	var sunflower := [_circle(12.0,9.0,4.2),"M10.9 12.8 H13.1 V22.6 H10.9Z","M13 18.4 Q16.6 14.6 20.6 16.4 Q18.8 20.8 13 19.8Z"]
	for k in range(14):
		var a := k*TAU/14.0
		var way := Vector2.from_angle(a)
		var side := way.orthogonal()
		var c := Vector2(12.0,9.0)
		sunflower.append(_poly([c+way*3.6+side*1.0,c+way*8.0,c+way*3.6-side*1.0]))
	_add("sunflower","Sunflower","Stand","#e2a62e",sunflower,[_circle(12.0,9.0,3.0),_circle(12.0,9.0,1.5)],59,1.0,1.4)
	# Wheat (seed 60): three straws, each ear two rows of kernels staggered
	# up a pointed spindle, awns flicking from the tips.
	var wheat := []
	for s: Array in [[12.0,3.4],[7.0,5.6],[17.0,5.6]]:
		var base := Vector2(12.0,22.6)
		var top := Vector2(float(s[0]),float(s[1]))
		var way := (top-base).normalized()
		var side := way.orthogonal()
		var neck := top-way*8.0
		wheat.append(_poly([base+side*0.5,top-way*1.0+side*0.4,top-way*1.0-side*0.4,base-side*0.5]))
		for k in range(4):
			for sign: float in [-1.0,1.0]:
				var c := neck+way*(1.3+1.6*k+(0.5 if sign > 0.0 else 0.0))+side*sign*0.85
				wheat.append(_poly([c-way*1.25,c+side*sign*1.05,c+way*1.2,c-side*sign*0.9]))
		wheat.append(_poly([top-way*1.7+side*0.75,top,top-way*1.7-side*0.75]))
		wheat.append(_poly([top-side*0.22,top+way*2.4+side*0.5,top+side*0.22]))
	_add("wheat","Wheat","Field","#d9b24e",wheat,[],60,1.0,0.8)
	_add("reed","Reed","Cattail","#8a5a34",["M8.8 4.2 Q8.8 2.6 12 2.6 Q15.2 2.6 15.2 4.2 V13.4 Q15.2 15.2 12 15.2 Q8.8 15.2 8.8 13.4Z","M11.35 3 V0.8 H12.65 V3Z","M10.9 14.6 H13.1 V22.6 H10.9Z","M12.6 22.6 Q16.6 17 18 7.2 Q20.2 10 19.4 13.6 Q18 19.6 14.8 22.6Z"],[],5)
	_add("water","Water","Scoop","#4f8fc0",["M12 3 Q19 12 19 16 A7 7 0 0 1 5 16 Q5 12 12 3Z"],["M9 15 Q9 18 11.5 19"],6)
	_add("stone","River stone","Place","#8f8a86",["M2.5 14.5 C2.5 9.5 7.5 7.5 12.5 7.5 C18 7.5 21.5 10 21.5 14 C21.5 18 17 20 12 20 C6.5 20 2.5 18.5 2.5 14.5Z"],[],7)
	# The stone lamp (scripts/stone_lamp.gd): a roof over a fire box between
	# two pillars, a shelf, a post and a foot. Seed 60.
	_add("lamp","Stone lamp","Glow","#9a958a",["M12 1.6 L13 3.2 L20.5 6.8 H3.5 L11 3.2Z","M5.6 7.6 H18.4 V8.8 H5.6Z","M6.4 8.8 H8.4 V13.2 H6.4Z","M15.6 8.8 H17.6 V13.2 H15.6Z","M5 13.2 H19 V14.8 H5Z","M10.6 14.8 H13.4 V20 H10.6Z","M7 20 H17 V22.4 H7Z"],[],60)
	# The campfire (scripts/campfire.gd): a flame over two crossed sticks,
	# three stones of the ring before them. Seed 74.
	_add("campfire","Campfire","Hearth","#c8703a",["M12 2.4 Q16.8 7.6 15.6 12.2 Q14.8 15 12 15.4 Q9.2 15 8.4 12.2 Q7.6 9.4 10.2 7.2 Q10.4 9.6 11.6 10 Q10.6 6 12 2.4Z","M5 18.6 L18.4 14.2 L19 15.8 L5.6 20.2Z","M19 18.6 L5.6 14.2 L5 15.8 L18.4 20.2Z","M1.6 21.8 L3 18.6 L6.4 18.2 L7.6 21.8Z","M8.4 22.2 L9.6 19.4 L14.4 19.4 L15.6 22.2Z","M16.4 21.8 L17.6 18.2 L21 18.6 L22.4 21.8Z"],[],74,1.0,1.2)
	# The cabin (scripts/cabin.gd): a gable roof over three log courses, the
	# door a gap in the lower two, a chimney at the roof's shoulder, a sill
	# stone. Seed 75.
	_add("cabin","Cabin","Shelter","#9a7448",["M1.4 11.2 L12 3 L22.6 11.2 L20.8 12.2 L12 5.6 L3.2 12.2Z","M15.6 3.6 H18.4 V7.6 L15.6 5.5Z","M4.2 12.6 H19.8 V14.8 H4.2Z","M4.2 15.6 H9.8 V17.8 H4.2Z","M14.2 15.6 H19.8 V17.8 H14.2Z","M4.2 18.6 H9.8 V20.8 H4.2Z","M14.2 18.6 H19.8 V20.8 H14.2Z","M2.6 21.6 H21.4 V22.8 H2.6Z"],[],75,1.0,1.2)
	# The fence (scripts/fences.gd): two cut-topped posts, two split rails.
	_add("fence","Fence","Split rail","#9a7a52",["M4.6 5.2 L6.4 3 L8.2 4.6 V22.4 H4.6Z","M15.8 4.6 L17.6 3 L19.4 5.2 V22.4 H15.8Z","M1.6 8.4 L22.4 7.6 V10.6 L1.6 11.2Z","M1.6 15 L22.4 14.6 V17.4 L1.6 17.8Z"],["M3 9.6 H6","M18 16 H21"],73,1.0,1.2)
	# The footbridge (scripts/footbridge.gd): a timber arch with its posts
	# and rail, over a ripple.
	_add("bridge","Footbridge","Span","#9a7550",["M1.5 15.2 Q12 8.6 22.5 15.2 L22.5 18.2 Q12 11.8 1.5 18.2Z","M3.2 9.6 H4.9 V16.4 H3.2Z","M11.15 6.4 H12.85 V12.4 H11.15Z","M19.1 9.6 H20.8 V16.4 H19.1Z"],["M3.6 10.4 Q12 4.4 20.4 10.4","M7 21.6 Q9.5 20.6 12 21.6 Q14.5 22.6 17 21.6"],81,1.0,1.4)
	# The case's later tree seeds (and the command palette's,
	# scripts/command_palette.gd): drawn as the tree they grow. Seeds 40-45.
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
	# The isles' on-foot token (scripts/rune_token.gd): a red plummet on its thread.
	_add("rune","Rune","Ruins","#c8203a",["M9.6 6.4 H14.4 L17 10 L12 22.4 L7 10Z",_circle(12,5.2,1.1)],["M12 0.8 V4.2","M7 10 H17"],90)
	# A heart: a madder stone
	# heart, a chevron and a stroke carved in it. Seed 92.
	_add("heart","Heart","Life","#9c4436",["M12 21.4 C6 17 2.2 13.2 2.2 8.6 C2.2 5.3 4.7 2.9 7.7 2.9 C9.6 2.9 11.1 3.9 12 5.5 C12.9 3.9 14.4 2.9 16.3 2.9 C19.3 2.9 21.8 5.3 21.8 8.6 C21.8 13.2 18 17 12 21.4Z"],
		["M7 8.6 L12 12.6 L17 8.6","M12 14.8 V17.6"],92,1.0,1.3)
	# The plane's parts (the ledger's Plane row, scripts/plane_arc/): the coin
	# of scripts/plane_parts.gd flat, a brass disc in its bevelled rim, the
	# propeller across it on its hub. Seed 91.
	_add("part","Part","Plane","#c99a52",[_circle(12.0,12.0,10.4)],[_circle(12.0,12.0,8.2),
		"M6.6 17.4 Q8.4 13.4 10.6 12.6 Q11.4 12.2 12 12 Q12.6 11.8 13.4 11.4 Q15.6 10.6 17.4 6.6",_circle(12.0,12.0,1.6)],91,1.0,1.5)
	_add("snow","Frost","Winter","#7fbfd0",_snowflake(),[],9)
	# Shaping tools (the tool roll).
	# The Modeller (id "hand", the roll's first pocket, once the bare Hand's): a
	# boxwood modelling tool laid on the diagonal, its spatula down to the left.
	var modeller := _modeller()
	_add("hand","Modeller","Mould","#e0a07a",modeller[0],modeller[1],10,1.0,1.2)
	# The Sculpt, "Shape": a trowel on the diagonal, its kite blade's point
	# down to the left, the handle up to the right.
	_add("sculpt","Sculpt","Shape","#9fb0a0",["M3 21 L5.4 12.4 L11.6 9.4 L14.6 12.4 L11.6 18.6Z","M16.2 9.6 L20.6 5.2 Q21.7 4.1 20.8 3.2 Q19.9 2.3 18.8 3.4 L14.4 7.8Z"],["M13.1 10.9 L15.3 8.7","M4.6 19.4 L10.7 13.3"],24,1.0,1.4)
	# The drag tools: the Hills (two rolling hills), the Mountain (a peak with a
	# snow cap) and the Bowl (a basin in profile).
	_add("hills","Hills","Roll","#8fae78",["M2 22.5 V16.6 Q5.6 8.4 10 13.8 Q14.6 5.6 19.4 12.6 Q21 14.6 22 16 V22.5Z"],["M4.4 20 Q8 18.4 11.6 20"],47,1.0,1.3)
	_add("mountain","Mountain","Peak","#9a948c",["M1.6 22.5 L9.2 9.4 L11.6 11.8 L14.4 4.2 L22.4 22.5Z"],["M12.2 9.6 L14.4 4.2 L16.6 9.8"],48,1.0,1.6)
	_add("crater","Crater","Hollow","#a08a68",["M2 17 H4.5 Q6.5 12.6 8 13.4 Q9.6 19.2 12 19.2 Q14.4 19.2 16 13.4 Q17.5 12.6 19.5 17 H22 V22.5 H2Z"],["M12 3.4 V9.4","M9.8 7.2 L12 9.4 L14.2 7.2"],64,1.0,1.4)
	# The Island: a mound standing out of the water, a sapling on it.
	_add("island","Island","Isle","#b4a874",["M3.4 18.4 Q6.6 18.4 8.4 14.6 Q12 9.8 15.6 14.6 Q17.4 18.4 20.6 18.4Z",_circle(12,6.2,2.6)],["M12 8.6 V12.4","M1.6 21.2 Q4.4 19.8 7.2 21.2 Q10 22.6 12.8 21.2 Q15.6 19.8 18.4 21.2 Q20.4 22.2 22.4 21.4"],69,1.0,1.4)
	_add("bowl","Bowl","Hollow","#a08a68",["M2 9.4 H5.2 Q7 17.6 12 17.6 Q17 17.6 18.8 9.4 H22 V22.5 H2Z"],["M8 14.4 Q12 15.6 16 14.4"],49,1.0,1.4)
	# The Sculpt's modes, fanned out beside its pocket (scripts/tool_roll.gd
	# SCULPT_MODES): the ground in profile, as each leaves it.
	_add("sculpt_raise","Raise","Sculpt","#8fae78",["M2 21 Q6.5 21 8.6 15.4 Q12 7.6 15.4 15.4 Q17.5 21 22 21 V22.5 H2Z"],["M12 1.8 V7.4","M9.6 4.2 L12 1.8 L14.4 4.2"],25,1.0,1.6)
	_add("sculpt_lower","Lower","Sculpt","#a08a68",["M2 13 Q6.5 13 8.6 17 Q12 22.6 15.4 17 Q17.5 13 22 13 V22.5 H2Z"],["M12 1.8 V9","M9.6 6.6 L12 9 L14.4 6.6"],26,1.0,1.6)
	_add("sculpt_hills","Hills","Sculpt","#7fa86a",["M2 22.5 V17.6 Q4.8 11.6 8.4 15.6 Q11.8 6.8 16 14.2 Q19 10.4 22 15.6 V22.5Z"],[],27,1.0,1.6)
	_add("sculpt_smooth","Smooth","Sculpt","#9aa88a",["M2 15.4 Q12 14.2 22 15.4 V22.5 H2Z"],["M3 8.4 Q6 5.4 9 8.4 Q12 11.4 15 8.4 Q18 5.4 21 8.4"],28,1.0,1.6)
	# The other tools' modes, fanned out the same way, each in its tool's tint.
	_add("hand_pinch","Pinch","Modeller","#e0a07a",["M2 21 Q7.6 20.4 9.6 14.6 L12 4.6 L14.4 14.6 Q16.4 20.4 22 21 V22.5 H2Z"],["M7.6 4 L9.8 6.4","M16.4 4 L14.2 6.4"],29,1.0,1.5)
	_add("hand_groove","Groove","Modeller","#e0a07a",["M2 12.4 H5.6 Q7.2 11 8.6 12.4 Q12 21.4 15.4 12.4 Q16.8 11 18.4 12.4 H22 V22.5 H2Z"],[],30,1.0,1.5)
	_add("hand_palm","Palm","Modeller","#e0a07a",["M2 12.4 H5 Q6.6 17.4 9 17.4 H15 Q17.4 17.4 19 12.4 H22 V22.5 H2Z"],["M7 9.2 H17","M9.6 4.4 V9.2 M14.4 4.4 V9.2"],31,1.0,1.5)
	_add("hand_poke","Poke","Modeller","#e0a07a",["M2 14.4 H9.6 Q12 17.6 14.4 14.4 H22 V22.5 H2Z"],["M12 2.6 V10.4","M9.8 8.2 L12 10.4 L14.2 8.2"],32,1.0,1.5)
	_add("mountain_pull","Pull","Mountain","#9a948c",["M2 22.5 L8.6 14.6 L12 9.8 L15.4 14.6 L22 22.5Z"],["M12 1.8 V7","M9.6 4.2 L12 1.8 L14.4 4.2"],65,1.0,1.5)
	_add("mountain_draw","Draw","Mountain","#9a948c",["M1.6 22.5 L6 15.6 L8.4 17.6 L12.2 10.8 L15.6 15.8 L18 13.8 L22.4 22.5Z"],["M3 6.4 Q7.4 2.6 12 6 Q16.6 9.4 21 5.4"],66,1.0,1.5)
	_add("crater_pull","Pull","Crater","#a08a68",["M2 17 H4.5 Q6.5 12.6 8 13.4 Q9.6 19.2 12 19.2 Q14.4 19.2 16 13.4 Q17.5 12.6 19.5 17 H22 V22.5 H2Z"],["M12 3.4 V9.4","M9.8 7.2 L12 9.4 L14.2 7.2"],67,1.0,1.5)
	_add("crater_draw","Draw","Crater","#a08a68",["M2 13.4 H4 Q5.6 19.6 12 19.6 Q18.4 19.6 20 13.4 H22 V22.5 H2Z"],["M5 7.6 Q5 3.4 11.4 3.6 Q19.4 3.4 19 7.4 Q18.6 10.6 12 10.4 Q6.4 10.6 5 7.6Z"],68,1.0,1.5)
	_add("island_draw","Draw","Island","#b4a874",["M5 17.6 Q8 12.4 12 12.6 Q16 12.4 19 17.6Z"],["M5 6.6 Q5 2.8 11.4 3 Q19.4 2.8 19 6.4 Q18.6 9.4 12 9.2 Q6.4 9.4 5 6.6Z","M1.6 20.6 Q4.4 19.2 7.2 20.6 Q10 22 12.8 20.6 Q15.6 19.2 18.4 20.6 Q20.4 21.6 22.4 20.8"],70,1.0,1.5)
	_add("island_spread","Spread","Island","#b4a874",["M2 17.6 H11.6 Q14.4 17.6 15.6 20.4 Q16.2 21.4 17 21.4 H2Z"],["M13.6 9.4 H20.4","M18.4 7.4 L20.4 9.4 L18.4 11.4","M1.6 21.2 Q4.4 19.8 7.2 21.2","M17.6 20.8 Q20 19.6 22.4 20.8"],71,1.0,1.5)
	_add("paddle_pat","Pat","Paddle","#c49a5e",["M2 15.4 H22 V22.5 H2Z","M4.6 9 H19.4 V11.6 H4.6Z"],["M12 2.4 V9"],35,1.0,1.5)
	# The Plane: the blade stood upright, drawn toward a rough rise; behind it
	# the ground lies planed flat.
	_add("paddle_plane","Plane","Paddle","#c49a5e",["M2 15.4 H13.4 V11.2 L16.2 8.6 L18.6 10.6 L22 9.4 V22.5 H2Z","M11.4 5.6 H13.4 V15.4 H11.4Z"],["M3 10.6 H9","M7 8.6 L9 10.6 L7 12.6"],56,1.0,1.5)
	_add("chisel_mesa","Mesa","Chisel","#6f8aa6",["M2 19.4 H6.2 L7.2 8.4 H16.8 L17.8 19.4 H22 V22.5 H2Z"],[],36,1.0,1.5)
	_add("chisel_shelf","Shelf","Chisel","#6f8aa6",["M2 8.4 H11.4 L12.2 15.4 H22 V22.5 H2Z"],[],37,1.0,1.5)
	_add("chisel_notch","Notch","Chisel","#6f8aa6",["M2 12.4 H8.6 V17.4 H15.4 V12.4 H22 V22.5 H2Z"],[],38,1.0,1.5)
	_add("chisel_slice","Slice","Chisel","#6f8aa6",["M2 21 Q5.8 20.4 7.6 15.6 L8.8 12.4 H15.2 L16.4 15.6 Q18.2 20.4 22 21 V22.5 H2Z"],["M3.4 9.4 H20.6"],46,1.0,1.4)
	_add("paddle","Paddle","Smooth","#c49a5e",["M5.5 12 Q5.5 9.5 8 9.5 H16 Q18.5 9.5 18.5 12 V19 Q18.5 22 15.5 22 H8.5 Q5.5 22 5.5 19Z","M10.7 9.6 V2.9 A1.3 1.3 0 0 1 13.3 2.9 V9.6Z"],["M9 13 V19 M15 13 V19","M10.9 5.6 H13.1"],11)
	_add("chisel","Chisel","Cut","#6f8aa6",["M6 2.8 Q6 2 6.8 2 H10.2 Q11 2 11 2.8 V10.5 H6Z","M6.8 10.5 H10.2 V18.5 L9.2 21.8 H7.8 L6.8 18.5Z","M13 4 Q13 3 14 3 H21 Q22 3 22 4 V8.5 Q22 9.5 21 9.5 H14 Q13 9.5 13 8.5Z","M16.6 9.5 H18.4 V21 Q18.4 22 17.5 22 Q16.6 22 16.6 21Z"],["M5.8 10.5 H11.2","M6.8 18.5 H10.2","M15.5 3 V9.5"],12)
	_add("wire","Ravine","Carve","#b8683f",["M2 9.4 H8.2 L10.8 21.2 H13.2 L15.8 9.4 H22 V22.5 H2Z"],["M3.4 5.4 Q7.6 2.6 12 5.4 Q16.4 8.2 20.6 5.4"],13)
	# The Ravine's modes: the cut in profile, and a ramp falling evenly.
	_add("wire_carve","Carve","Ravine","#b8683f",["M2 9.4 H8.2 L10.8 21.2 H13.2 L15.8 9.4 H22 V22.5 H2Z"],[],72,1.0,1.5)
	_add("wire_slope","Slope","Ravine","#b8683f",["M2 7.4 H6 L18 19.4 H22 V22.5 H2Z"],["M9.6 4.8 L15.6 10.8","M13.2 10.8 H15.6 V8.4"],73,1.0,1.5)
	_add("hammer","Hammer","Break","#7a6a5a",["M3 5.5 Q3 4.5 4 4.5 H15 L20.5 7.2 L15 9.8 H4 Q3 9.8 3 8.8Z","M8.2 9.8 H10.8 V20.8 A1.3 1.3 0 0 1 8.2 20.8Z"],["M12.5 4.5 V9.8"],14)
	# The Feather, "Gust" (HUD 5, lowpoly.js SHAPING_TOOLS[5]): wind held in
	# hand, below the tools after the roll's divider. A finer quill line (1.2).
	_add("feather","Feather","Gust","#cbb994",["M4.6 21.2 Q5.4 11 17.6 2.8 Q19.6 1.8 20.6 3.2 Q21.2 4.6 19.8 6.6 Q12.8 17.4 4.6 21.2Z"],["M3.2 22.6 L17.2 6","M9.4 15.2 L6.6 14.4","M12.6 11.4 L10 10.2","M11.6 15.2 L14.4 14.6","M15 11 L17.4 10.8"],15,1.0,1.2)
	# The watering can, "Pour": water held in hand, under the Feather. A
	# body, a spout rising to the right with its rose, a loop handle over it.
	_add("can","Watering can","Pour","#8aa6a8",["M4 10 H14.5 V19.5 Q14.5 21 13 21 H5.5 Q4 21 4 19.5Z","M14 13.6 L20.4 7.4 L21.6 8.8 L14.5 16.2Z","M19.6 5.6 L22.8 8.8 L21.2 10.2 L18.2 7.2Z"],["M5.6 10 Q5.6 4.4 9.25 4.4 Q12.9 4.4 12.9 10","M4 12.4 H14.5"],16,1.0,1.5)
	# The Brush, "Paint": a flat paint brush on the diagonal, its bristles
	# down to the left; and its modes, the ground as each leaves it.
	_add("brush","Brush","Paint","#b9a46a",["M2.6 21.4 L4 15 L9 10 L14 15 L9 20Z","M9 10 L11 8 L16 13 L14 15Z","M13.4 9.6 L19.6 3.4 Q20.8 2.2 21.7 3.1 Q22.6 4 21.4 5.2 L15.2 11.4Z"],["M4.6 18.6 L9.6 13.6"],50,1.0,1.3)
	_add("brush_grass","Grass","Brush","#7fb069",["M2 16 H22 V22.5 H2Z","M4.6 16 L6 9.6 L7.6 16Z","M9.6 16 L12 6.4 L13.8 16Z","M16 16 L18.2 10.4 L19.4 16Z"],[],51,1.0,1.5)
	_add("brush_rock","Rock","Brush","#8d8577",["M2 22.5 V17 L6 12 L10 13.4 L13.6 7.6 L18.4 11 L22 16.4 V22.5Z"],["M13.6 7.6 L12.4 14","M6 12 L7.6 17"],52,1.0,1.4)
	_add("brush_earth","Earth","Brush","#9a7652",["M2 15.4 H22 V22.5 H2Z",_circle(7,12.4,1.7),_circle(13.2,11.6,2.1),_circle(18.2,12.8,1.4)],[],53,1.0,1.5)
	_add("brush_colour","Colour","Brush","#b06f4a",["M12 3 C18.6 3 22 7.4 22 11.8 C22 15.4 19.6 16.4 17.6 16 C15.6 15.6 14.6 16.8 15.4 18.4 C16.2 20 15.4 21.4 12.6 21.4 C6.6 21.4 2 17.4 2 12 C2 6.8 6.6 3 12 3Z"],[_circle(7.4,10.6,1.6),_circle(11.6,7.2,1.6),_circle(16.4,8.6,1.6),_circle(7.6,15.6,1.6)],55,1.0,1.3)
	_add("brush_wipe","Wipe","Brush","#c8bfa6",["M2 16 H22 V22.5 H2Z"],["M4 10.4 Q12 3.6 20 10.4","M16.8 7.4 L20 10.4 L15.8 11.4"],54,1.0,1.5)
	# The trash can, "Clear": a lidded bin, its lid's handle over it, ribbed.
	_add("trash","Trash can","Clear","#7d9465",["M5.4 8 H18.6 L17.3 20.8 Q17.1 22 15.9 22 H8.1 Q6.9 22 6.7 20.8Z","M3.4 4.8 H20.6 V6.8 H3.4Z","M9.4 4.8 V3 Q9.4 2 10.4 2 H13.6 Q14.6 2 14.6 3 V4.8 H13 V3.6 H11 V4.8Z"],["M9.8 10.6 L10.2 19.4","M14.2 10.6 L13.8 19.4"],72,1.0,1.5)
	# --- HUD 5 foot icons (docs/design/hud-5/lowpoly.js ROLL_FOOT; the tool
	# roll's foot, scripts/tool_foot.gd). Undo seed 21, Photo seed 22. -------------
	_add("undo","Undo","Back","#b5a78c",_undo_arrow(),[],21)
	_add("photo","Camera","Photo","#8f8a86",["M3 8.2 Q3 6.6 4.6 6.6 H8 L9.6 4.4 H14.4 L16 6.6 H19.4 Q21 6.6 21 8.2 V17.8 Q21 19.4 19.4 19.4 H4.6 Q3 19.4 3 17.8Z"],["M15.6 13 A3.6 3.6 0 1 0 8.4 13 A3.6 3.6 0 1 0 15.6 13","M17.6 9.2 L17.7 9.2"],22,1.0,1.5)
	# The foot's third slot: a brass lens that opens the command palette
	# (scripts/command_palette.gd), as the palette's search well draws one.
	# The ring is one path, its hole wound the other way so it stays open.
	_add("palette","Lens","Reach","#c9a45e",["M2.6 10 a7.4 7.4 0 1 0 14.8 0 a7.4 7.4 0 1 0 -14.8 0Z M5.2 10 a4.8 4.8 0 1 1 9.6 0 a4.8 4.8 0 1 1 -9.6 0Z",_bar(14.8,14.8,PI*0.25,9.4,3.8)],["M7.2 8 Q8 6.6 9.8 6.4"],55,1.0,1.4)
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
# matters, in one muted tint. Seeds 46-54.

static func _life() -> void:
	_add("deer","Deer","Wood's edge","#b98a5c",_deer(),["M18.6 5.4 L18.7 5.4"],46,1.0,1.2)
	var heron := _heron()
	_add("heron","Heron","Wading","#7f93a3",heron[0],heron[1],47,1.0,1.2)
	var snake := _snake()
	_add("snake","Snake","By the pond","#7d8048",snake[0],snake[1],48,1.0,1.2)
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
