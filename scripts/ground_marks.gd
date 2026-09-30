extends Node
## The in-hand ground marks, design "ZenScape HUD 4b" ("Cursor (ghost hand)
## per held item", docs/design/materials-tray/CURSOR-MARKS.md): a faint cream
## sketch on the land under the ghost hand of what a press there will touch.
## The 3D hand stays the cursor; this is only its shadow of intent.
##
## - **Modeller** (id `hand`): a soft stitched loop with a faint fill, the thumb's reach
##   (hand.gd RUB_RADIUS, between the groove's half-width and the palm).
## - **Paddle:** a wide stitched ellipse, long across the view.
## - **Chisel:** a hard square in one solid line, the only solid mark, laid in
##   the plane of the face it will cut and squared to its fall line.
## - **Wire:** a toggle dot on hover; while its press is dragged, a line along
##   the path the drag has drawn (the wire's `drawn`, the path its gorge will
##   follow) from the press to the pointer, with a toggle at each end.
## - **Hammer:** a small stitched ring and a few scree specks downhill, where
##   chunks will fall.
## - **Material:** a dotted drop ring under the carried item, as wide as the
##   spread it will set down (hand_materials SCATTER spread × size).
## - **Feather** (HUD 5 "Gust", wind in hand): at rest only a small stitched
##   hotspot ellipse (FEATHER_HOTSPOT); while a drag is under way the hotspot
##   rides under the feather, since the wind itself (the live wake) shows
##   where it goes; held still past hand_materials FEATHER_BURST_SECONDS, the
##   burst's ring, growing. The hold keeps its mark while pressed, unlike the
##   tools' (`_step_feather`). The lane's stitched edges (`feather_lane`) are
##   drawn only for an aimed lane, which the Feather no longer makes.
##
## Each scales with the roll's size (tool_roll.gd SIZES) and lies on the
## terrain: a box decal reads the depth buffer back to the ground under it
## (shaders/ground_mark.gdshader, the pollen footprint's way).
##
## **Faint by the user's choice.** They turned down ground outlines that
## preview an outcome as "hand holdy" (the promise marks, --show-promise), and
## agreed to these only if quiet: far under the design's .85-.95 alpha
## (LINE_ALPHA, FILL_ALPHA), fading in over FADE_IN only while the hand hovers
## the land with nothing pressed, and gone once a drag or pinch starts. The
## wire's line is the one exception, as it is its drag's own preview
## (WIRE_ALPHA). No bob, pulse or loop: a mark holds still while it shows.
## Never over the tray or roll, the void or the sky, while the camera moves,
## or under a prop, tree or resident (their own grab wins there).
##
## Two layers: `update`/`hide` draw a given mark (the narrow API, usable by a
## tool's own script), and `step` decides which from the hand's state each
## frame (called by scripts/hand_reach.gd after the materials tray).

## The marks.
const KINDS := ["hand","paddle","chisel","wire","hammer","material","feather","feather_lane","feather_burst"]
const KIND_INDEX := {"hand":0,"paddle":1,"chisel":2,"wire":3,"hammer":4,"material":5,"feather":6,"feather_lane":7,"feather_burst":8}

## How faint (premultiplied alpha at full show, 0..1): the loops' and dots'
## thread, the hand's fill, and the wire's line while dragged. FAINT_CAP is the
## ceiling any of them may be tuned to before it stops being quiet (the probe
## holds them under it). The design's own is 0.85-0.95.
const LINE_ALPHA := 0.3
const FILL_ALPHA := 0.05
const WIRE_ALPHA := 0.3
const FAINT_CAP := 0.4
## Seconds to fade in on hovering the land, and out on a press, a drag, the
## camera moving or the pointer leaving the land.
const FADE_IN := 0.2
const FADE_OUT := 0.12
## Screen pixels: the stitched and solid line's width, the wire's (the
## design's 2 px), a drop-ring dot's radius and a wire toggle's.
const LINE_PX := 1.5
const WIRE_PX := 2.0
const DOT_PX := 1.6
const TOGGLE_PX := 3.0
## Metres of loop per stitch (thread and gap), and the thread's share: about
## the linen hem's 3-on-3 stitch at the diorama's usual framing. The drop
## ring's dots are DOT_METRES apart.
const STITCH_METRES := 0.42
const STITCH_DUTY := 0.55
const DOT_METRES := 0.34
## The cream, rgba(255,250,240) in the design, as linear light; night dims it
## by NIGHT_DIM so it does not glow in the dark.
const TONE := Color(1.0,0.955,0.871)
const NIGHT_DIM := 0.55

## Sizes in metres at size 1 (the roll's middle pip; ×0.6 and ×1.5 either
## side). Each tool says its own (clay_tool.gd `mark_size`, read from the
## clay's tool of that id), so a tool's reach and its mark cannot drift apart:
## the Modeller's thumb rub (1.6 m), the paddle's pat across the view (3 × 1.5 m),
## the chisel's notch (a 0.8 m half-square), the hammer's crack (1.8 m). These
## are the fallbacks, for a tool that gives none or a scene without the clay:
## the design's proportions against the hand's 96×58 px sketch (the paddle
## 180×54, the hammer's ring 54×34, the chisel a 1.6 m square).
const HAND_RADIUS := 1.6
const PADDLE_HALF := Vector2(3.0,1.5)
const CHISEL_HALF := 0.8
const HAMMER_RADIUS := 0.9
## The hammer's scree, downhill of the strike: each speck's turn off the fall
## line (radians), distance out (metres, × size) and radius (metres, × size).
## Fixed, so they stay put as the hand moves.
const SCREE := [Vector3(-0.32,1.25,0.07),Vector3(0.18,1.55,0.09),Vector3(-0.08,1.95,0.06),Vector3(0.4,2.2,0.05),Vector3(-0.45,2.5,0.06),Vector3(0.1,2.85,0.045)]
## The drop ring's radius for materials that do not scatter (metres, × size):
## tree seeds gather a veil about the pollen cloud's CLOUD.y across before the
## wind takes it; the water ball's pool; a stone's biggest tap. Scattered
## things use their SCATTER spread, never under MATERIAL_MIN.
const MATERIAL_RADIUS := {"oak":1.3,"pine":1.3,"willow":1.3,"birch":1.3,"water":1.0,"stone":0.45}
const MATERIAL_MIN := 0.45
## The decal box: metres of margin round the mark, the ground samples round
## its outline for the box's height, metres of box under and over the ground
## read, and how far over the highest ground the mark may still paint (above
## that are trees and props).
const BOX_MARGIN := 0.5
const OUTLINE_SAMPLES := 10
const BOX_BELOW := 1.0
const BOX_ABOVE := 1.0
const CEILING_LIFT := 0.45
## Metres either side a normal is read over.
const NORMAL_REACH := 0.5
## The Feather's hotspot at rest, half extents in metres along the view and
## across: the design's 7×3.5 px ellipse at the hand sketch's scale (its
## 96 px loop is the thumb's 3.2 m, about 30 px a metre). It does not scale
## with the pips: it marks the point, not a reach. A swipe's edges show once
## it has run FEATHER_LANE_MIN m.
const FEATHER_HOTSPOT := Vector2(0.24,0.12)
const FEATHER_LANE_MIN := 0.3
## Holds a wire drag can be under: the clay's until the wire has its own verb.
const WIRE_HOLDS := ["land","wire"]
## The most points of a wire's drawn path the shader takes (its
## `wire_path` array); a longer path is thinned evenly, ends kept.
const WIRE_POINTS := 64

var scene: Node3D
var reach: Node
var node: MeshInstance3D
var material: ShaderMaterial
## The mark in hand, its fade (0..1) and whether it is wanted.
var kind := "hand"
var shown := 0.0
var wanted := false
## Where it lies (terrain local), its half extents (terrain metres) along
## `axis` and across, the wire's press point and the path it has drawn
## (terrain local; the path's x, z, empty for a straight line).
var centre := Vector3.ZERO
var half := Vector2.ONE
var axis := Vector3.RIGHT
var normal := Vector3.UP
var wire_start := Vector3.ZERO
var wire_path := PackedVector2Array()
## The scree specks, terrain local x, z and radius.
var specks: Array[Vector3] = []
## Why it is hidden this frame, for probes ("" while wanted).
var reason := ""
var _cover_key: Array = []
var _covered := false

func setup(owner_scene: Node3D, hand_reach: Node) -> void:
	scene = owner_scene
	reach = hand_reach
	name = "GroundMarks"
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/ground_mark.gdshader")
	material.render_priority = -1
	node = MeshInstance3D.new()
	node.name = "GroundMark"
	var box := BoxMesh.new()
	node.mesh = box
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)

# --- The narrow API ------------------------------------------------------------

## Show `kind`'s mark at `point` (terrain local, on the ground) at `size_scale`
## of its size, fading in. The wire also takes its press point `from`
## (terrain local; without it the wire is a single toggle at `point`) and
## the path drawn from there (terrain x, z; without it a straight line).
func update(next: String, point: Vector3, size_scale: float, delta: float, from: Variant = null, path := PackedVector2Array()) -> void:
	if not next in KINDS:
		hide(delta)
		return
	kind = next
	wanted = true
	reason = ""
	centre = point
	wire_start = from if from != null else point
	wire_path = path.duplicate()
	if path.size() >= 2:
		# The line runs from the press point to the pointer, as its toggles do.
		wire_path[0] = Vector2(wire_start.x,wire_start.z)
		wire_path[-1] = Vector2(point.x,point.z)
	_shape(size_scale)
	_fade(delta)
	_draw()

## Fade the mark out (at once with delta < 0).
func hide(delta := -1.0, why := "") -> void:
	wanted = false
	reason = why
	if delta < 0.0: shown = 0.0
	else: _fade(delta)
	if shown <= 0.0 or _editor() == null:
		shown = 0.0 if _editor() == null else shown
		node.visible = false
	else: _draw()

## The alpha the line has at this moment (for probes: under FAINT_CAP).
func line_alpha_now() -> float:
	return (WIRE_ALPHA if kind == "wire" else LINE_ALPHA)*shown

## The half extents a mark of `which` has at `size_scale` (terrain metres).
func size_of(which: String, size_scale: float) -> Vector2:
	var tool: RefCounted = _tool(which)
	if tool != null:
		var own: Vector2 = tool.mark_size()
		if own != Vector2.ZERO: return own*size_scale
	match which:
		"hand": return Vector2.ONE*HAND_RADIUS*size_scale
		"paddle": return PADDLE_HALF*size_scale
		"chisel": return Vector2.ONE*CHISEL_HALF*size_scale
		"hammer": return Vector2.ONE*HAMMER_RADIUS*size_scale
		"material":
			var r := _material_radius()*size_scale
			return Vector2(r,r)
	return Vector2.ZERO

# --- Deciding, each frame --------------------------------------------------------

## Reads the hand and shows the mark it wants, or fades it.
func step(delta: float) -> void:
	delta = minf(delta,0.1)
	var materials: Node = reach.get("materials")
	if materials == null or materials.roll == null:
		hide(delta,"no tray")
		return
	var held: String = materials.held
	var what := "material" if not held.is_empty() else str(materials.roll.tool)
	var size: float = materials.size_scale()
	if what == "feather":
		_step_feather(delta,materials)
		return
	if not reach.available():
		hide(delta,"unavailable")
		return
	if reach.camera_moving():
		hide(delta,"camera")
		return
	var pointer := _pointer()
	var holding: String = reach.holding
	if not holding.is_empty():
		# A drag or pinch has begun: only the wire's own line stays.
		if what != "wire" or not holding in WIRE_HOLDS:
			hide(delta,"held")
			return
		var to: Variant = reach._land(pointer)
		if to == null:
			hide(delta,"off land")
			return
		var wire: RefCounted = _tool("wire")
		var path: PackedVector2Array = wire.drawn() if wire != null and wire.has_method("drawn") else PackedVector2Array()
		update("wire",to,size,delta,wire_start,path)
		return
	if reach.hover_zone != "land" or reach._hover_point == null:
		hide(delta,"not land")
		return
	if materials.tray_under(pointer):
		hide(delta,"tray")
		return
	if _under_cover(pointer):
		hide(delta,"covered")
		return
	var point: Vector3 = reach._hover_point
	# The wire's press point is where the hover last stood.
	update(what,point,size,delta,point if what == "wire" else null)

func _pointer() -> Vector2:
	return scene.get_viewport().get_mouse_position() if reach.pointer_override == null else reach.pointer_override

## The Feather's marks. While its wind is in hand (a press on the land, or wind
## dragged in from the sky) the mark follows the wind tool's promise: under a
## live wake, the hotspot under the feather; for an aimed lane, the lane's
## edges from the press to the pointer's reach along the heading; held still,
## the burst's ring (hand_materials `feather_ring`), or the hotspot at the
## press until the ring starts. At rest, the hotspot under the hovering hand,
## by the same rules as every mark.
func _step_feather(delta: float, materials: Node) -> void:
	if reach.camera_moving():
		hide(delta,"camera")
		return
	if materials.feather_blowing():
		var plan: Dictionary = materials._gust().promise()
		var start: Vector2 = plan.origin
		var from := Vector3(start.x,_height(start,centre.y),start.y)
		if plan.kind == "wake":
			var under: Variant = reach._land(_pointer())
			_feather_mark("feather",under if under != null else centre,FEATHER_HOTSPOT,_view_right(),delta)
			return
		if plan.kind == "lane":
			var heading: Vector2 = plan.heading
			var to: Variant = reach._land(_pointer())
			var run := (Vector2(to.x,to.z)-start).dot(heading) if to != null else Vector2(centre.x-start.x,centre.z-start.y).length()
			if run >= FEATHER_LANE_MIN:
				var end := start+heading*run
				_feather_mark("feather_lane",Vector3(end.x,_height(end,from.y),end.y),Vector2(float(plan.half),0.0),Vector3(heading.x,0.0,heading.y),delta,from)
				return
		var ring: float = materials.feather_ring()
		if ring > 0.0: _feather_mark("feather_burst",from,Vector2(ring,ring),_view_right(),delta)
		else: _feather_mark("feather",from,FEATHER_HOTSPOT,_view_right(),delta)
		return
	if not reach.available():
		hide(delta,"unavailable")
		return
	if not str(reach.holding).is_empty():
		hide(delta,"held")
		return
	var pointer := _pointer()
	if reach.hover_zone != "land" or reach._hover_point == null:
		hide(delta,"not land")
		return
	if materials.tray_under(pointer):
		hide(delta,"tray")
		return
	if _under_cover(pointer):
		hide(delta,"covered")
		return
	_feather_mark("feather",reach._hover_point,FEATHER_HOTSPOT,_view_right(),delta)

## Show a Feather mark of `which` at `point` (terrain local), `extent` its
## half extents along `way` and across (the lane: its half-width, and `from`
## its press point). Its own shape, not `_shape`'s: the Feather's sizes come
## from the wind, not the tools' size table.
func _feather_mark(which: String, point: Vector3, extent: Vector2, way: Vector3, delta: float, from: Variant = null) -> void:
	kind = which
	wanted = true
	reason = ""
	centre = point
	wire_start = from if from != null else point
	wire_path = PackedVector2Array()
	var p := Vector2(point.x,point.z)
	var e := NORMAL_REACH
	var dx := _height(p+Vector2(e,0.0),point.y)-_height(p-Vector2(e,0.0),point.y)
	var dz := _height(p+Vector2(0.0,e),point.y)-_height(p-Vector2(0.0,e),point.y)
	normal = Vector3(-dx,2.0*e,-dz).normalized()
	axis = (way-normal*way.dot(normal)).normalized()
	half = extent
	specks.clear()
	_fade(delta)
	_draw()

## True when a prop, tree or resident is under the pointer (their own grab
## wins there), or a tree is outlined. Read again only when the hover is.
func _under_cover(pointer: Vector2) -> bool:
	var key: Array = reach.get("_hover_key")
	if key != _cover_key or key.is_empty():
		_cover_key = key.duplicate()
		_covered = reach._prop_at(pointer)
	var outline: Node = reach.get("outline")
	return _covered or (outline != null and int(outline.get("tree_id")) > 0)

## The clay's tool `id` (scripts/clay_tools/), made if it is not yet, or
## null: not a tool (a material), or no clay in this scene.
func _tool(id: String) -> RefCounted:
	if id == "material": return null
	var clay: Node = scene.get("land_clay") as Node
	if clay == null or not clay.has_method("tool_of"): return null
	return clay.tool_of(id)

func _material_radius() -> float:
	var materials: Node = reach.get("materials")
	var held: String = materials.held if materials != null else ""
	if MATERIAL_RADIUS.has(held): return float(MATERIAL_RADIUS[held])
	var scatter: Dictionary = _constant(materials,"SCATTER",{})
	if scatter.has(held): return maxf(float(scatter[held].get("spread",0.0)),MATERIAL_MIN)
	return MATERIAL_MIN

## A script constant of `holder`'s by name, or `fallback` (so a renamed or
## moved constant costs only its tuning, not a crash).
static func _constant(holder: Object, key: String, fallback: Variant) -> Variant:
	if holder == null or holder.get_script() == null: return fallback
	return (holder.get_script() as Script).get_script_constant_map().get(key,fallback)

# --- Shape and drawing -----------------------------------------------------------

func _editor() -> Node:
	return scene.get("_chunk_editor")

func _height(p: Vector2, fallback: float) -> float:
	var h: Variant = _editor().data.ground_height(p)
	return float(h) if h != null else fallback

## The ground's normal and fall line at the centre, the mark's axis and half
## extents, and the hammer's scree.
func _shape(size_scale: float) -> void:
	var p := Vector2(centre.x,centre.z)
	var e := NORMAL_REACH
	var dx := _height(p+Vector2(e,0.0),centre.y)-_height(p-Vector2(e,0.0),centre.y)
	var dz := _height(p+Vector2(0.0,e),centre.y)-_height(p-Vector2(0.0,e),centre.y)
	normal = Vector3(-dx,2.0*e,-dz).normalized()
	# The fall line in the ground's plane; on the flat, the view's right.
	var fall := Vector3(-dx,0.0,-dz)
	var right := _view_right()
	if kind == "chisel" and fall.length() > 0.02: axis = fall.normalized()
	else: axis = right
	axis = (axis-normal*axis.dot(normal)).normalized()
	half = size_of(kind,size_scale) if kind != "wire" else Vector2.ZERO
	specks.clear()
	if kind == "hammer":
		var down := Vector2(fall.x,fall.z)
		if down.length() < 0.02: down = Vector2(-right.z,right.x)
		down = down.normalized()
		for s: Vector3 in SCREE:
			var way := down.rotated(s.x)*s.y*size_scale
			specks.append(Vector3(p.x+way.x,p.y+way.y,s.z*size_scale))

## The camera's right along the ground (terrain local).
func _view_right() -> Vector3:
	var terrain: Node3D = _editor().terrain
	var right: Vector3 = terrain.global_basis.inverse()*scene.camera.global_basis.x
	right.y = 0.0
	return right.normalized() if right.length() > 0.01 else Vector3.RIGHT

func _fade(delta: float) -> void:
	if wanted: shown = move_toward(shown,1.0,delta/FADE_IN)
	else: shown = move_toward(shown,0.0,delta/FADE_OUT)

## Place the box round the mark and hand the shader its shape.
func _draw() -> void:
	var terrain: Node3D = _editor().terrain
	var scale := terrain.global_basis.get_scale().x
	# The ground the mark covers: its outline (or the wire's line and toggles).
	var outline: Array[Vector2] = []
	var c := Vector2(centre.x,centre.z)
	if kind == "wire" and wire_path.size() >= 2:
		outline.append_array(wire_path)
	elif kind in ["wire","feather_lane"]:
		var a := Vector2(wire_start.x,wire_start.z)
		# The Feather's lane also covers its half-width either side.
		var side := Vector2(-axis.z,axis.x)*half.x if kind == "feather_lane" else Vector2.ZERO
		for k in range(OUTLINE_SAMPLES+1):
			var q := a.lerp(c,float(k)/OUTLINE_SAMPLES)
			outline.append(q)
			if side != Vector2.ZERO:
				outline.append(q+side)
				outline.append(q-side)
	else:
		var across := normal.cross(axis).normalized()
		for k in range(OUTLINE_SAMPLES):
			var t := TAU*k/OUTLINE_SAMPLES
			var edge := axis*cos(t)*half.x+across*sin(t)*half.y
			if kind == "chisel": edge *= sqrt(2.0)
			outline.append(c+Vector2(edge.x,edge.z))
		for s: Vector3 in specks: outline.append(Vector2(s.x,s.y))
	outline.append(c)
	var low := INF
	var high := -INF
	var lo := c
	var hi := c
	for q: Vector2 in outline:
		var h := _height(q,centre.y)
		low = minf(low,h)
		high = maxf(high,h)
		lo = Vector2(minf(lo.x,q.x),minf(lo.y,q.y))
		hi = Vector2(maxf(hi.x,q.x),maxf(hi.y,q.y))
	lo -= Vector2.ONE*BOX_MARGIN
	hi += Vector2.ONE*BOX_MARGIN
	var middle := (lo+hi)*0.5
	var local := Transform3D(Basis.from_scale(Vector3(hi.x-lo.x,high-low+BOX_BELOW+BOX_ABOVE,hi.y-lo.y)),Vector3(middle.x,(low-BOX_BELOW+high+BOX_ABOVE)*0.5,middle.y))
	node.global_transform = terrain.global_transform*local
	node.visible = shown > 0.0
	var basis := terrain.global_basis
	material.set_shader_parameter("mark_kind",KIND_INDEX[kind])
	material.set_shader_parameter("mark_centre",terrain.to_global(centre))
	material.set_shader_parameter("mark_axis",(basis*axis).normalized())
	material.set_shader_parameter("mark_normal",(basis*normal).normalized())
	material.set_shader_parameter("mark_half",half*scale)
	material.set_shader_parameter("wire_from",terrain.to_global(wire_start))
	material.set_shader_parameter("wire_to",terrain.to_global(centre))
	var line := PackedVector2Array()
	if kind == "wire" and wire_path.size() >= 2:
		var count := mini(wire_path.size(),WIRE_POINTS)
		for k in count:
			var q := wire_path[roundi(float(k)*(wire_path.size()-1)/(count-1))]
			var w := terrain.to_global(Vector3(q.x,centre.y,q.y))
			line.append(Vector2(w.x,w.z))
	line.resize(WIRE_POINTS)
	material.set_shader_parameter("wire_path",line)
	material.set_shader_parameter("wire_count",mini(wire_path.size(),WIRE_POINTS) if kind == "wire" else 0)
	var packed := PackedVector4Array()
	for s: Vector3 in specks:
		var w := terrain.to_global(Vector3(s.x,centre.y,s.y))
		packed.append(Vector4(w.x,w.z,s.z*scale,0.0))
	material.set_shader_parameter("specks",packed)
	material.set_shader_parameter("speck_count",packed.size())
	material.set_shader_parameter("shown",shown)
	material.set_shader_parameter("line_alpha",WIRE_ALPHA if kind == "wire" else LINE_ALPHA)
	material.set_shader_parameter("fill_alpha",FILL_ALPHA if kind in ["hand","feather_lane"] else 0.0)
	material.set_shader_parameter("line_px",WIRE_PX if kind == "wire" else LINE_PX)
	material.set_shader_parameter("dot_px",DOT_PX)
	material.set_shader_parameter("toggle_px",TOGGLE_PX)
	material.set_shader_parameter("stitches",_stitches())
	material.set_shader_parameter("stitch_duty",STITCH_DUTY)
	material.set_shader_parameter("ceiling",terrain.to_global(Vector3(centre.x,high+CEILING_LIFT,centre.z)).y)
	material.set_shader_parameter("mark_tone",Vector3(TONE.r,TONE.g,TONE.b))
	material.set_shader_parameter("night_dim",NIGHT_DIM)

## Whole stitches (or dots) round the loop, so the ring closes evenly.
func _stitches() -> float:
	# The Feather's lane: whole stitches along its length.
	if kind == "feather_lane": return maxf(2.0,roundf(Vector2(centre.x-wire_start.x,centre.z-wire_start.z).length()/STITCH_METRES))
	var a := half.x
	var b := half.y
	# Ramanujan's perimeter; the chisel's square is solid and ignores it.
	var perimeter := PI*(3.0*(a+b)-sqrt((3.0*a+b)*(a+3.0*b)))
	return maxf(8.0,roundf(perimeter/(DOT_METRES if kind == "material" else STITCH_METRES)))
