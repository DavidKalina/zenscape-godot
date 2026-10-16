extends RefCounted
## The motif editor's slope tool (spec-editor-traps item 14; the Ravine
## pocket's second mode, key 9): a drag from the top down lays a "slope"
## stroke (scripts/kit_isle/motif_authored.gd `Slope`: an even ramp at the
## pilot's surf angle, turf, no lips), its width from the brush radius. The
## same drag along a slope already there turns it to steps (risers of the
## kit's set-off, lips to grab), and along steps back to a slope. One undo
## step each; the land rebuilds as after a ravine.

const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")

## How far off a slope's band (m) a drag's middle may be and still be
## along it, and how parallel (the cosine) its line must run.
const ALONG_PAD := 1.0
const ALONG_COS := 0.7

## The drag `pts` (world (x, z) Vector2s) done with.
static func drag(e: Node, pts: Array) -> void:
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[-1]
	var strokes: Array = e.data.strokes
	var k := along(strokes,a,b)
	if k >= 0:
		e.snapshot()
		var s: Dictionary = strokes[k]
		var to_steps := not bool(s.get("steps",false))
		if to_steps: s.steps = true
		else: s.erase("steps")
		e._status_line = "Slope turned to steps (%.1f m risers)" % MotifAuthored.SLOPE_STEP if to_steps else "Steps turned back to a slope"
	else:
		var stroke := {"tool":"slope","r":snappedf(float(e.brush_r),0.01),"pts":[[snappedf(a.x,0.001),snappedf(a.y,0.001)],[snappedf(b.x,0.001),snappedf(b.y,0.001)]]}
		var made := MotifAuthored.Slope.new(stroke,e.motif.ground_fn())
		if made.dead:
			e.say("No fall there: drag a slope from higher ground down to lower")
			return
		e.snapshot()
		strokes.append(stroke)
		e._status_line = "Slope: %.0f deg, %.1f m down over %.1f m%s" % [rad_to_deg(atan(made.grade)),made.top-made.bottom,made.run,
			", %.0f m run-out" % (made.length-made.run) if made.length-made.run > 0.5 else ""]
	var mid := (a+b)*0.5
	e.feel.cue(&"lurch",Vector3(mid.x,float(e.motif.ground(mid.x,mid.y)),mid.y),0.5)
	e._changed_at = Time.get_ticks_msec()
	e._want_dress = true
	e._show_status()

## The last slope stroke the line a..b runs along (its middle in the band,
## its way near the band's), or -1.
static func along(strokes: Array, a: Vector2, b: Vector2) -> int:
	if a.distance_to(b) < 0.5: return -1
	var mid := (a+b)*0.5
	var way := (b-a).normalized()
	for k in range(strokes.size()-1,-1,-1):
		var s: Dictionary = strokes[k]
		if str(s.get("tool","")) != "slope": continue
		var band := MotifAuthored.Slope.band_of(s)
		if band.is_empty(): continue
		if not MotifAuthored.Slope.inside(band,mid,ALONG_PAD): continue
		if absf(way.dot((band.b-band.a).normalized())) >= ALONG_COS: return k
	return -1
