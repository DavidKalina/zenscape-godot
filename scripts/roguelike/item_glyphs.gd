extends RefCounted
## [juice] Small hand-drawn-feeling glyphs for the items carried (the strip,
## the find's rising mark): a few jittered strokes in a -1..1 box, in the
## style of scripts/hud_icons.gd's linework but drawn straight on a
## CanvasItem. A known id has its own mark; an unknown id (other agents add
## items in parallel) gets its kind's mark with pips from its name, so it
## still reads as its own thing.

const TINTS := {"verb":Color("dcb87a"),"passive":Color("b9c8a2"),"cursed":Color("c4909a")}
const INK := Color(0.03,0.025,0.02,0.6)
## Ids with a mark of their own.
const OWN := ["wallrun","lantern","heart"]

static func _circle(c: Vector2, r: float, n := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n+1): out.append(c+Vector2(cos(TAU*float(i)/float(n)),sin(TAU*float(i)/float(n)))*r)
	return out

## Strokes by mark: point lists in -1..1; a closed one repeats its first point.
static func strokes(mark: String) -> Array:
	match mark:
		"hand":  # Gecko Wraps: a splayed palm, five toes
			return [_circle(Vector2(0.0,0.35),0.42,10),
				PackedVector2Array([Vector2(-0.3,0.05),Vector2(-0.62,-0.45)]),
				PackedVector2Array([Vector2(-0.1,-0.04),Vector2(-0.24,-0.85)]),
				PackedVector2Array([Vector2(0.14,-0.04),Vector2(0.26,-0.85)]),
				PackedVector2Array([Vector2(0.33,0.05),Vector2(0.64,-0.45)]),
				PackedVector2Array([Vector2(-0.4,0.4),Vector2(-0.85,0.2)]),
				_circle(Vector2(-0.64,-0.5),0.09,6),_circle(Vector2(-0.25,-0.9),0.09,6),
				_circle(Vector2(0.27,-0.9),0.09,6),_circle(Vector2(0.66,-0.5),0.09,6)]
		"lantern":
			return [PackedVector2Array([Vector2(-0.3,-0.55),Vector2(0.3,-0.55),Vector2(0.45,0.55),Vector2(-0.45,0.55),Vector2(-0.3,-0.55)]),
				PackedVector2Array([Vector2(-0.2,-0.55),Vector2(-0.2,-0.85),Vector2(0.2,-0.85),Vector2(0.2,-0.55)]),
				PackedVector2Array([Vector2(0.0,-0.25),Vector2(0.14,0.05),Vector2(0.0,0.3),Vector2(-0.14,0.05),Vector2(0.0,-0.25)]),
				PackedVector2Array([Vector2(-0.5,0.8),Vector2(0.5,0.8)])]
		"heart":
			return [PackedVector2Array([Vector2(0.0,0.8),Vector2(-0.8,-0.05),Vector2(-0.75,-0.55),Vector2(-0.35,-0.7),Vector2(0.0,-0.35),
				Vector2(0.35,-0.7),Vector2(0.75,-0.55),Vector2(0.8,-0.05),Vector2(0.0,0.8)])]
		"verb":  # a swept arrow with a feathered tail
			return [PackedVector2Array([Vector2(-0.8,0.7),Vector2(0.7,-0.7)]),
				PackedVector2Array([Vector2(0.15,-0.7),Vector2(0.7,-0.7),Vector2(0.7,-0.15)]),
				PackedVector2Array([Vector2(-0.8,0.7),Vector2(-0.8,0.25)]),PackedVector2Array([Vector2(-0.8,0.7),Vector2(-0.35,0.7)]),
				PackedVector2Array([Vector2(-0.45,0.3),Vector2(-0.1,0.45)]),PackedVector2Array([Vector2(-0.1,-0.05),Vector2(0.25,0.15)])]
		"cursed":  # a jagged diamond with a slit eye
			return [PackedVector2Array([Vector2(0.0,-0.9),Vector2(0.4,-0.3),Vector2(0.75,0.0),Vector2(0.3,0.25),Vector2(0.0,0.9),
				Vector2(-0.3,0.25),Vector2(-0.75,0.0),Vector2(-0.4,-0.3),Vector2(0.0,-0.9)]),
				PackedVector2Array([Vector2(-0.3,0.0),Vector2(0.0,-0.15),Vector2(0.3,0.0),Vector2(0.0,0.12),Vector2(-0.3,0.0)])]
		_:  # passive and unknown: a ring with four ticks
			return [_circle(Vector2.ZERO,0.62,16),_circle(Vector2.ZERO,0.2,8),
				PackedVector2Array([Vector2(0.0,-0.62),Vector2(0.0,-0.9)]),PackedVector2Array([Vector2(0.0,0.62),Vector2(0.0,0.9)]),
				PackedVector2Array([Vector2(-0.62,0.0),Vector2(-0.9,0.0)]),PackedVector2Array([Vector2(0.62,0.0),Vector2(0.9,0.0)])]

## The mark an id wears: its own when known, else its kind's.
static func mark_of(id: StringName, kind: String) -> String:
	if String(id) == "wallrun": return "hand"
	if String(id) in OWN: return String(id)
	return kind if kind in ["verb","cursed"] else "passive"

## The tint an id wears (by its kind).
static func tint_of(id: StringName, kind: String) -> Color:
	if String(id) == "heart": return Color("c98a7a")
	return TINTS.get(kind,TINTS.passive)

## `id`'s glyph centred on `at`, `size` px across, tinted by its kind and
## `alpha`; `weight` scales the stroke.
static func draw(on: CanvasItem, id: StringName, kind: String, at: Vector2, size: float, alpha := 1.0, weight := 1.0) -> void:
	var mark := mark_of(id,kind)
	var tint := tint_of(id,kind)
	var seed_h: int = hash(String(id))
	var rng := RandomNumberGenerator.new()
	var half := size*0.5
	var width := maxf(1.4,size*0.075)*weight
	var all := strokes(mark)
	# A name's pips for an item with no mark of its own.
	if not (String(id) in OWN):
		var pips := 1+(seed_h & 3)
		for i in range(pips):
			var ang := TAU*float((seed_h>>(4+i*3)) & 7)/8.0
			all.append(_circle(Vector2(cos(ang),sin(ang))*0.97,0.07,5))
	for pass_i in range(2):
		var shadow := pass_i == 0
		rng.seed = seed_h
		for s: PackedVector2Array in all:
			var pts := PackedVector2Array()
			for p in s:
				var j := Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))*0.045
				pts.append(at+(p+j)*half+(Vector2(0.9,1.4) if shadow else Vector2.ZERO))
			if pts.size() < 2: continue
			var col := Color(INK.r,INK.g,INK.b,INK.a*alpha) if shadow else Color(tint,alpha)
			on.draw_polyline(pts,col,width*(1.6 if shadow else 1.0),true)
