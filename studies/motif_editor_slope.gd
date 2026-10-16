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
		e._status_line = "Slope: %.0f deg, %.1f m down over %.1f m%s%s" % [rad_to_deg(atan(made.grade)),made.top-made.bottom,made.run,
			", %.0f m run-out" % (made.length-made.run) if made.length-made.run > 0.5 else "",
			" · short: little slide (drag from higher ground to lower for more)" if made.run < MotifAuthored.SLOPE_RUN_FELT else ""]
	var mid := (a+b)*0.5
	e.feel.cue(&"lurch",Vector3(mid.x,float(e.motif.ground(mid.x,mid.y)),mid.y),0.5)
	e._changed_at = Time.get_ticks_msec()
	e._want_dress = true
	e._show_status()

# --- The edit-mode read ---------------------------------------------------------------------
# A ramp is turf like the hill round it and, seen from the editing camera,
# hardly reads: the land changes on release but nothing says "slope". Each
# slope's band gets a tinted skin over its faces with chevrons down its fall
# line (steps: the skin only). Editor-only: a mesh with no collider, shown
# while editing, hidden in play, rebuilt with every stand (`mark`).

const MARK_NAME := "SlopeMarks"
## The skin's lattice (m), its lift over the ground (m), and the chevrons'
## spacing and size (m).
const MARK_CELL := 0.5
const MARK_LIFT := 0.08
const CHEVRON_EVERY := 2.0
const CHEVRON_HALF := 1.2
const CHEVRON_DEEP := 0.9
const CHEVRON_THICK := 0.35
const SKIN := Color(0.95,0.75,0.45,0.32)
const SKIN_RUNOUT := Color(0.95,0.75,0.45,0.12)
const CHEVRON := Color(1.0,0.93,0.78,0.85)

## The slopes' marks stood again over the editor's motif (none: removed).
static func mark(e: Node3D) -> void:
	var old := e.get_node_or_null(MARK_NAME)
	if old != null:
		e.remove_child(old)
		old.free()
	var m: RefCounted = e.motif
	if m == null or not m.has_method("slope_bands"): return
	m.ground_fn()
	var slopes: Array = (m.get("_ground_parts") as Dictionary).get("slopes",[])
	var skin := SurfaceTool.new()
	skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for sl in slopes:
		if sl.dead: continue
		any = true
		_skin(skin,sl,m)
	if not any: return
	var mi := MeshInstance3D.new()
	mi.name = MARK_NAME
	mi.mesh = skin.commit()
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = bool(e.get("editing"))
	e.add_child(mi)

## Shown while editing, hidden in play.
static func show_marks(e: Node3D, on: bool) -> void:
	var n := e.get_node_or_null(MARK_NAME) as Node3D
	if n != null: n.visible = on

## One slope's skin (its ramp strong, its run-out faint) and its chevrons.
static func _skin(st: SurfaceTool, sl: Object, m: RefCounted) -> void:
	var a: Vector2 = sl.a
	var dir: Vector2 = sl.dir
	var side := Vector2(-dir.y,dir.x)
	var half := float(sl.half)
	var length := float(sl.length)
	var run := float(sl.run)
	var nu := maxi(1,ceili(length/MARK_CELL))
	var nv := maxi(1,ceili(2.0*half/MARK_CELL))
	var at := func(u: float, v: float, lift: float) -> Vector3:
		var p := a+dir*u+side*v
		return Vector3(p.x,float(m.ground(p.x,p.y))+lift,p.y)
	for i in range(nu):
		var u0 := length*i/nu
		var u1 := length*(i+1)/nu
		var c := SKIN if (u0+u1)*0.5 < run+0.25 else SKIN_RUNOUT
		for j in range(nv):
			var v0 := -half+2.0*half*j/nv
			var v1 := -half+2.0*half*(j+1)/nv
			var q := [at.call(u0,v0,MARK_LIFT),at.call(u1,v0,MARK_LIFT),at.call(u1,v1,MARK_LIFT),at.call(u0,v1,MARK_LIFT)]
			for k: int in [0,1,2,0,2,3]:
				st.set_color(c)
				st.add_vertex(q[k])
	if bool(sl.steps) or run < 1.0: return
	# Chevrons down the ramp, pointing the way he slides.
	var hw := minf(CHEVRON_HALF,half*0.7)
	var u := CHEVRON_EVERY*0.5
	while u+CHEVRON_DEEP <= run:
		for s: float in [-1.0,1.0]:
			# One arm: from the side, back up the ramp, to the tip down it.
			var o0: Vector3 = at.call(u,s*hw,MARK_LIFT*2.0)
			var o1: Vector3 = at.call(u+CHEVRON_DEEP,0.0,MARK_LIFT*2.0)
			var i1: Vector3 = at.call(u+CHEVRON_DEEP+CHEVRON_THICK,0.0,MARK_LIFT*2.0)
			var i0: Vector3 = at.call(u+CHEVRON_THICK,s*hw,MARK_LIFT*2.0)
			for p: Vector3 in [o0,o1,i1,o0,i1,i0]:
				st.set_color(CHEVRON)
				st.add_vertex(p)
		u += CHEVRON_EVERY

static func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = 1
	return mat

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
