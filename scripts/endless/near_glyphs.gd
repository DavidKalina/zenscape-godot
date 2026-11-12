extends RefCounted
## The flight glyphs: what a pass was near (a tree, a rock, the ground, water,
## an arch, a gap), the line's moves, the chain's ends (the bank, a scrape),
## money, the charge, the finds and the places. Rasterised from SVG text at
## the size drawn (nothing baked to disk; hex colours only, the SVG importer
## reads rgba() as black) and cached. A texture covers BOX units (the 24-unit
## box and PAD round it): draw it `px*BOX/24` across round the glyph's centre.
##
## Two drawings, the same calls:
## - the set of 2026-11-11 (docs/design/ui/mock/glyphs.json, carried in
##   near_glyph_data.gd, made by tools/glyph_data.py): flat polygons in three
##   tones (lit, mid, shade; the light from the top left), each stroked STROKE
##   in its own colour to close the seams. Each glyph has its own colour
##   (TINTS, today's hues; its three tones spaced as the gilt ground's are).
##   `gilt` (--glyphs=gilt) draws them all in the one gilt ground instead, a
##   scrape and a crash in the loss ground. A ground can also be asked for by
##   name as the variant ("gilt", "ink" for a cream plate, "loss", "bone").
##   No sun: banked points are `bank` (two coins), money `coin`, the charge
##   `surge` (a swirl), the roll ready `roll`.
## - `old` (--glyphs=old; the trunk's --ui=old sets it): the faceted glyphs
##   as the archived HUD drew its icons (scripts/hud_icons.gd at the tag
##   archive/before-the-cut, "ZenScape HUD 4c"): a silhouette filled with a
##   jittered 4x4 triangle grid shaded along the top-left to bottom-right
##   diagonal, its line paths cut over it in the tint's shade. An id only the
##   new set has falls back to the one it took over from (OLD_ID).

const Data = preload("res://scripts/endless/near_glyph_data.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const LIGHT := Color("fffaf0")
const SHADE := Color("1a140e")
const N := 4
const LIFT := 1.3
const DROP := 1.1
const JITTER := 0.55
const PAD := 2.0
const BOX := 24.0+PAD*2.0
## The new set's seam-closing stroke (units), in each polygon's own colour.
const STROKE := 0.14

## The new set's colour per glyph (the mid tone; `tones` spaces the lit and
## the shade from it). The kinds and moves keep today's hues; a new id takes
## the colour of what it shows or of the id it took over from. "gilt", "loss"
## and "bone" name a ground of the json's, used as it stands.
const TINTS := {
	"tree":"5e8f4c","rock":"8f8a86","ground":"7fae5a","water":"4f8fc0","arch":"a8977c","gap":"8d8577",
	"pull":"7fae5a","skip":"4f8fc0","dive":"e0a548","knife":"c9ccd4","inverted":"c58fd0","carve":"9cc26a",
	"canopy":"4f8a45","canyon":"b9744a","climb":"a39274","surf":"8fa3ad","crest":"4f8fc0","slalom":"6f9c4e",
	"orbit":"7c9aa8","smash":"8f8a86",
	"coin":"gilt","bank":"e2b25e","surge":"f7c63f","roll":"f7c63f","scrape":"loss","crash":"loss",
	"relic":"e2b25e","landing":"a8977c","line":"e2b25e","event":"f7c63f","plane":"bone",
	"falls":"4f8fc0","tunnel":"8d8577","peak":"8fa3ad","stack":"7c9aa8","balloon":"c2694f","whale":"7c9aa8",
	"burrower":"b9744a","race":"c9ccd4","shop":"e0a548","door":"a8977c",
	"tree_cluster":"5e8f4c","plane_side":"bone","coin_block":"gilt","surge_burst":"f7c63f"}
## The lit and the shade off a mid tone, as the gilt ground's stand off its
## mid (d9a441 to f7dc8a and 8f6a2c): the lit keeps LIT_S of the saturation
## and climbs LIT_V of the way to full value, the shade keeps SHADE_V of the
## value. A dark hue (the rock's grey, the canyon's brown) so gets a lit tone
## that reads on the dark plate at 12 px without the hue moving.
const LIT_S := 0.63
const LIT_V := 0.8
const SHADE_V := 0.66
## What an id of the new set is under `old`.
const OLD_ID := {"pull":"ground","skip":"water","crest":"surf","smash":"rock","coin":"bank","roll":"surge","crash":"scrape"}

## Today's faceted drawing instead of the new set.
static var old := false
## The new set in the one gilt ground instead of a colour per glyph.
static var gilt := false
static var _flags_read := false

## [tint, fills, lines, seed, line width]
static var _items := {}
static var _textures := {}
static var _tones := {}

## --glyphs=old, --glyphs=gilt (or both, comma-separated), read once. It
## only turns a switch on, so one set from code (the trunk's --ui=old) stays.
static func _flags() -> void:
	if _flags_read: return
	_flags_read = true
	for arg: String in LaunchArgs.user_args():
		if not arg.begins_with("--glyphs="): continue
		for word: String in arg.trim_prefix("--glyphs=").split(",",false):
			if word == "old": old = true
			elif word == "gilt": gilt = true

## Which drawing is in force: "old", "gilt" or "tint" (a cache key for
## whoever keeps textures made from `body_of`: near_badges.gd).
static func mode() -> String:
	_flags()
	return "old" if old else ("gilt" if gilt else "tint")

## The id drawn for `id` in the drawing in force, or "" if it has none.
static func resolve(id: String) -> String:
	_flags()
	if old:
		if _items.is_empty(): _build()
		var was := str(OLD_ID.get(id,id))
		return was if _items.has(was) else ""
	return id if Data.GLYPHS.has(id) else ""

## Every id the drawing in force has, in the sheet's order.
static func ids() -> Array:
	_flags()
	if old:
		if _items.is_empty(): _build()
		return _items.keys()
	return Data.ORDER.duplicate()

## The glyph for a "near" event {kind, surface, under, glyph (a move's own,
## line_moves.gd)}.
static func for_moment(m: Dictionary) -> String:
	var own := resolve(str(m.get("glyph","")))
	if own != "": return own
	var kind := str(m.get("of",m.get("kind","")))
	var surface := str(m.get("surface",""))
	if kind == "thread": return "arch" if bool(m.get("under",false)) else "gap"
	# A pull-out has its own mark, and a skip (a pull-out off the water) its.
	if kind == "pull-out" and not old: return "skip" if surface == "water" else "pull"
	if surface == "tree": return "tree"
	if surface == "water": return "water"
	if surface == "stone": return "rock"
	return "ground"

## Variants: "icon" (the glyph), "lit" (lit up, for a gleam) and "shadow"
## (white silhouette, to tint as the cut's shadow); the new set also takes a
## ground's name ("gilt", "ink", "loss", "bone") or "tint" (its own colour
## whatever `gilt` says).
static func svg(id: String, variant := "icon") -> String:
	var body := body_of(id,variant)
	if body.is_empty(): return ""
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">%s</svg>' % [int(BOX),int(BOX),_num(-PAD),_num(-PAD),_num(BOX),_num(BOX),body]

## The glyph's SVG body in its 24-unit box (near_badges.gd sets it on a
## medallion), or "".
static func body_of(id: String, variant := "icon") -> String:
	id = resolve(id)
	if id == "": return ""
	if not old: return _body_new(id,variant)
	var it: Dictionary = _items[id]
	var body := ""
	var fills: Array = it.fills
	if variant == "shadow":
		for d: String in fills: body += '<path d="%s" fill="#ffffff"/>' % d
		for d: String in it.lines:
			body += '<path d="%s" fill="none" stroke="#ffffff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d,_num(it.lw)]
	else:
		var base: Color = it.tint
		if variant == "lit": base = _mix(base,Color.WHITE,0.55)
		body += '<defs><clipPath id="s">'
		for d: String in fills: body += '<path d="%s"/>' % d
		body += '</clipPath></defs><g clip-path="url(#s)">'
		for tri: Dictionary in facets(int(it.seed),base):
			body += '<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="0.2"/>' % [tri.points,tri.fill,tri.fill]
		# The lines are cut into the face, so they stay inside the silhouette.
		var dark := _mix(it.tint,SHADE,0.5).to_html(false)
		for d: String in it.lines:
			body += '<path d="%s" fill="none" stroke="#%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d,dark,_num(it.lw)]
		body += '</g>'
	return body

## The new set's body: its polygons in order, each in its tone's colour.
static func _body_new(id: String, variant: String) -> String:
	var cols := PackedStringArray()
	if variant == "shadow":
		cols = PackedStringArray(["ffffff","ffffff","ffffff"])
	else:
		var from: Array = tones(id,"" if variant == "icon" or variant == "lit" else variant)
		for c: Color in from:
			cols.append((_mix(c,Color.WHITE,0.55) if variant == "lit" else c).to_html(false))
	var body := ""
	for p: Array in Data.GLYPHS[id].polys:
		var col := cols[int(p[0])]
		body += '<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="%s" stroke-linejoin="round"/>' % [p[1],col,col,_num(STROKE)]
	return body

## The new set's three colours for `id`: lit, mid, shade. `ground` "" is the
## one in force (its own colour, or the gilt ground under `gilt`); "tint" its
## own colour; else a ground of the json's by name.
static func tones(id: String, ground := "") -> Array:
	_flags()
	if ground == "": ground = "gilt" if gilt else "tint"
	if ground == "tint": ground = str(TINTS.get(id,"gilt"))
	elif ground == "gilt" and str(TINTS.get(id,"")) == "loss": ground = "loss"
	if _tones.has(ground): return _tones[ground]
	var out: Array
	if Data.GROUNDS.has(ground):
		var g: Array = Data.GROUNDS[ground]
		out = [Color(str(g[0])),Color(str(g[1])),Color(str(g[2]))]
	elif ground.is_valid_html_color():
		var mid := Color(ground)
		out = [Color.from_hsv(mid.h,mid.s*LIT_S,mid.v+(1.0-mid.v)*LIT_V),mid,Color.from_hsv(mid.h,mid.s,mid.v*SHADE_V)]
	else:
		return tones(id,"gilt")
	_tones[ground] = out
	return out

## The new set's polygons for whoever draws them itself: [[tone, points on
## the 24-unit grid], ...] in drawing order ([] for an id it lacks).
static func polygons(id: String) -> Array:
	var out := []
	if not Data.GLYPHS.has(id): return out
	for p: Array in Data.GLYPHS[id].polys:
		var points := PackedVector2Array()
		for pair: String in str(p[1]).split(" ",false):
			var xy := pair.split_floats(",")
			points.append(Vector2(xy[0],xy[1]))
		out.append([int(p[0]),points])
	return out

## A texture of `id` for a glyph drawn `px` pixels across its 24-unit box
## (cached by size). It covers BOX units: draw it `px*BOX/24` round the centre.
static func texture(id: String, variant: String, px: float) -> Texture2D:
	var key := "%s/%s/%s/%d" % [mode(),id,variant,roundi(px)]
	if _textures.has(key): return _textures[key]
	var source := svg(id,variant)
	if source.is_empty(): return null
	var image := Image.new()
	if image.load_svg_from_string(source,maxf(0.1,roundf(px)/24.0)) != OK: return null
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = tex
	return tex

## The glyph's record in the drawing in force ({} if it has none): the old
## set's {id, tint, fills, lines, seed, lw}, the new set's {id, tint, name,
## group, maps, polys}.
static func item(id: String) -> Dictionary:
	id = resolve(id)
	if id == "": return {}
	if old: return _items[id]
	var g: Dictionary = Data.GLYPHS[id]
	return {"id":id,"tint":tones(id)[1],"name":g.name,"group":g.group,"maps":g.maps,"polys":g.polys}

static func tint(id: String) -> Color:
	var it := item(id)
	return it.tint if not it.is_empty() else Color.WHITE

## The facet grid for `seed`, shaded from `base` (the archive's lowpoly.js
## `facets`, by its seeded LCG, so a glyph is the same every run).
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

static func _mix(a: Color, b: Color, t: float) -> Color:
	t = clampf(t,0.0,1.0)
	return Color8(roundi(a.r8+(b.r8-a.r8)*t),roundi(a.g8+(b.g8-a.g8)*t),roundi(a.b8+(b.b8-a.b8)*t))

static func _num(x: float) -> String:
	return String.num(x,3)

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

static func _add(id: String, tint: String, fills: Array, lines: Array, seed: int, lw := 1.6) -> void:
	_items[id] = {"id":id,"tint":Color(tint),"fills":fills,"lines":lines,"seed":seed,"lw":lw}

static func _build() -> void:
	# A spruce in three tiers on its trunk (the land is mostly spruce).
	_add("tree","#5e8f4c",["M12 1.2 L15.6 7.4 H13.8 L17.4 13.2 H15.4 L19.2 19 H13.3 V22.8 H10.7 V19 H4.8 L8.6 13.2 H6.6 L10.2 7.4 H8.4Z"],["M12 8.6 V18.6","M12 12.4 L9.6 14.6","M12 15.8 L14.6 17.6"],101,1.3)
	# A cliff of stacked blocks, a crack down its face.
	_add("rock","#8f8a86",["M2.4 22.4 L3.6 13.4 L7.2 9.6 L9.8 10.4 L13.4 4.2 L18.2 7.4 L21.6 13.8 L21.6 22.4Z"],["M13.4 4.2 L12.2 11 L14.6 15.4","M7.2 9.6 L8.2 16.4","M3.4 17 H9.4 M15 18.6 H21"],102,1.3)
	# The meadow: a band of turf with grass tufts on it.
	_add("ground","#7fae5a",["M2 15.6 Q7 13.4 12 15 Q17 16.6 22 14.6 V22.4 H2Z","M4.4 15 L5.6 8.6 L7.2 14.6Z","M9.8 15.2 L11.6 5.6 L13.4 15.6Z","M16 15.6 L18 9.8 L19.2 15.2Z"],["M3.6 19.4 Q8 18 12.4 19.4 Q16.8 20.8 20.6 19.2"],103,1.3)
	# Water: a breaking wave over a ripple.
	_add("water","#4f8fc0",["M2 13.2 Q4.6 6 11 5.6 Q16.4 5.4 18.4 9.4 Q15.2 7.8 13.2 9.6 Q11.4 11.4 13.6 13.4 Q16.4 15.4 22 13 V22.4 H2Z"],["M3.4 18.4 Q6.2 16.8 9 18.4 Q11.8 20 14.6 18.4 Q17.4 16.8 20.4 18.4"],104,1.3)
	# A stone arch: two piers under a round head, its voussoirs cut.
	_add("arch","#a8977c",["M2 22.6 V10.4 Q2 2.4 12 2.4 Q22 2.4 22 10.4 V22.6 H16.4 V11.6 Q16.4 7.4 12 7.4 Q7.6 7.4 7.6 11.6 V22.6Z"],["M12 2.6 V7.2","M5.2 4.6 L8.6 8.4","M18.8 4.6 L15.4 8.4","M2 11.4 H7.6 M16.4 11.4 H22","M2 17 H7.6 M16.4 17 H22"],105,1.2)
	# A gap: two walls leaning in over a narrow slot of sky.
	_add("gap","#8d8577",["M1.8 22.6 L2.6 2.4 H8.8 L10.4 12.4 L9.6 22.6Z","M14.4 22.6 L13.6 12.4 L15.2 2.4 H21.4 L22.2 22.6Z"],["M5.6 7 L4.2 11 M6.4 15 L5 19","M18.2 6.4 L19.6 10.6 M17.8 15.4 L19.2 19.4"],106,1.3)
	# The bank: a sun disc in its rays, gilt.
	var rays := [_circle(12,12,5.6)]
	for k in range(8):
		var a := k*PI/4.0
		rays.append(_bar(12.0+cos(a)*7.4,12.0+sin(a)*7.4,a,3.4,2.4))
	_add("bank","#e2b25e",rays,[_circle(12,12,3.4)],107,1.1)
	# The surge ready: the bank's sun, brighter gold.
	_add("surge","#f7c63f",rays,[_circle(12,12,3.4)],108,1.1)
	# A scrape: a madder stone split by a crack.
	_add("scrape","#a64a3a",["M3 15 L5.4 7.2 L11.2 3.6 L18 5.4 L21.4 11.6 L19.4 18.8 L12.6 21.2 L5.6 19.6Z"],["M11.6 3.8 L10 9.4 L13.4 12 L11.2 16.8 L12.6 21"],108,1.6)
	# The line's moves (line_moves.gd).
	# Late pull: a dive hooked out level, an arrow on.
	_add("dive","#e0a548",["M4 2 H9 V12 Q9 15.5 12.5 15.5 H15 V11.5 L21.6 17.5 L15 23.4 V19.5 H12.5 Q4 19.5 4 11Z"],["M6.5 4 V11"],109,1.2)
	# Knife edge: the plane on its wingtip between two walls.
	_add("knife","#c9ccd4",["M10.7 1.6 H13.3 V22.4 H10.7Z",_circle(12,12,3.4),"M1.8 22.6 V3 L5 2 L6 22.6Z","M22.2 22.6 V3 L19 2 L18 22.6Z"],["M12 4 V20"],110,1.0)
	# Inverted: the plane from behind, upside down, its fin hanging.
	_add("inverted","#c58fd0",["M2 10.4 H22 V13.6 H2Z",_circle(12,12,3.4),"M10.8 14 H13.2 L12.7 21.6 H11.3Z","M12 2.4 L15.2 6.6 H8.8Z"],["M4 12 H20"],111,1.0)
	# Carve: a swept turn low over the turf.
	_add("carve","#9cc26a",["M2 18.6 Q12 16.6 22 18.6 V22.4 H2Z","M3 15.6 Q10 1.4 21.6 7.4 Q12.6 5.6 5.2 16.6Z"],["M3.6 20.6 Q12 19.2 20.6 20.6"],112,1.2)
	# Canopy run: a path skimming three crowns.
	_add("canopy","#4f8a45",["M2 22.4 V15 Q4.5 9.4 7 15 Q9.5 8.4 12 15 Q14.5 8 17 15 Q19.5 9.4 22 15 V22.4Z",_bar(2.6,5.6,0.06,18.6,1.8)],["M7 15 V21","M12 15 V21","M17 15 V21"],113,1.2)
	# Canyon run: two walls over a deep slot, their strata level.
	_add("canyon","#b9744a",["M1.8 22.6 V2 L6 3 L8.6 9 L9.4 22.6Z","M22.2 22.6 V2.4 L18 3.4 L15.6 10 L14.6 22.6Z"],["M2 8 L7 8.4","M2 14 L8.8 14.6","M22 9 L16.5 9.6","M22 15 L15 15.4"],114,1.2)
	# Climb: up a steep face, the arrow hugging it.
	_add("climb","#a39274",["M2 22.4 L18 2.5 H22 V22.4Z","M3.4 15.2 L11.6 5 L10.2 3.9 L15.6 2.2 L15 7.8 L13.6 6.7 L5.4 16.8Z"],["M10 22 L19.6 8"],115,1.2)
	# Surf: down a steep face, the arrow hugging it.
	_add("surf","#8fa3ad",["M2 2.5 H6 L22 22.4 H2Z","M9.5 2.2 L18 12.4 L19.4 11.2 L20 17 L14.6 15.4 L16.2 14 L7.8 3.6Z"],["M4.4 8 L14 21.6"],116,1.2)
	# Slalom: an S wound between two spruces.
	_add("slalom","#6f9c4e",["M3 20 Q8 4 12 12 Q16 20 21 4 L22.4 5 Q17 23 12 15 Q8 8 4.4 21Z","M2.2 9.6 L5 2.6 L7.8 9.6Z","M16.2 22 L19 15 L21.8 22Z"],[],117,1.2)
	# A relic: the find's broken ring of hewn blocks, one fallen out.
	var ring := []
	for k in range(9):
		if k == 6: continue
		var a := k*TAU/9.0
		var side := Vector2(-sin(a),cos(a))
		var at := Vector2(12.0,12.0)+Vector2(cos(a),sin(a))*9.0-side*2.3
		ring.append(_bar(at.x,at.y,a+PI*0.5,4.6,4.4))
	_add("relic","#e2b25e",ring,[],123,1.1)
	# Stack orbit: a sea stack ringed by the path round it.
	_add("orbit","#7c9aa8",["M9.2 22.6 L9.8 4 L12 2 L14.4 4.4 L14.8 22.6Z","M2 13.4 a10 4.4 0 1 0 20 0 a10 4.4 0 1 0 -20 0Z M4.4 13.4 a7.6 2.6 0 1 1 15.2 0 a7.6 2.6 0 1 1 -15.2 0Z"],["M10.4 8 L13.6 8.4","M10.4 18 L14.4 18.4"],118,1.1)
