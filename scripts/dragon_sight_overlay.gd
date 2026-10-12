extends Node3D
## The dragon's sight drawn for tuning (docs/design/dragon-vision/round1.md):
## his cone in the world (a faint fill, its rim and rays, a ring at NEAR),
## a line from his eye to each of the pilot's points (green seen, red
## blocked by cover, grey out of the cone or range), and on screen the
## awareness meter with its thresholds and the state. Tinted by the state:
## pale unaware, amber suspicious, red spotted. KEY (J) shows and hides it.
## Reads the dragon's `sight` (scripts/dragon_sight.gd); steers nothing.

const DragonSight = preload("res://scripts/dragon_sight.gd")

const KEY := KEY_J
## The cone's look: rays round its rim, its fill's and lines' alpha.
const RAYS := 24
const FILL_ALPHA := 0.05
const LINE_ALPHA := 0.45
const TINT := {"unaware":Color(0.95,0.95,0.85),"suspicious":Color(1.0,0.66,0.15),"spotted":Color(1.0,0.2,0.15)}
const SEEN := Color(0.3,1.0,0.35)
const BLOCKED := Color(1.0,0.2,0.2)
const OUT := Color(0.6,0.6,0.6)

var dragon: Node3D
var _cone: MeshInstance3D
var _lines: MeshInstance3D
var _cone_mesh := ImmediateMesh.new()
var _line_mesh := ImmediateMesh.new()
var _layer: CanvasLayer
var _bar: ColorRect
var _fill: ColorRect
var _label: Label

func _init() -> void:
	name = "DragonSightOverlay"

func setup(flier: Node3D) -> void:
	dragon = flier
	top_level = true
	_cone = _drawn(_cone_mesh,true)
	_lines = _drawn(_line_mesh,false)
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	var box := Control.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -560.0
	box.offset_top = 20.0
	_layer.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size",18)
	_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	_label.position = Vector2(0.0,0.0)
	box.add_child(_label)
	_bar = ColorRect.new()
	_bar.color = Color(0,0,0,0.55)
	_bar.position = Vector2(0.0,52.0)
	_bar.size = Vector2(300.0,16.0)
	box.add_child(_bar)
	_fill = ColorRect.new()
	_fill.position = Vector2(2.0,2.0)
	_fill.size = Vector2(0.0,12.0)
	_bar.add_child(_fill)
	for mark: Array in [[DragonSight.SUSPECT_UP,TINT.suspicious],[DragonSight.SPOT_UP,TINT.spotted]]:
		var tick := ColorRect.new()
		tick.color = mark[1]
		tick.position = Vector2(2.0+296.0*float(mark[0])-1.0,-2.0)
		tick.size = Vector2(2.0,20.0)
		_bar.add_child(tick)

func _drawn(mesh: ImmediateMesh, fill: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = not fill
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY:
		visible = not visible
		_layer.visible = visible
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if dragon == null or not visible: return
	var sight: RefCounted = dragon.get("sight")
	var shown: bool = (dragon.get("model") as Node3D).visible and str(dragon.get("state")) != "waiting"
	var tint: Color = TINT.get(str(sight.state),TINT.unaware)
	_label.text = "Dragon sight: %s   (J hides)\nawareness %.2f · visibility %.2f · %d/%d points seen%s" % [str(sight.state).to_upper(),sight.awareness,sight.visibility,
		(sight.seen as Array).count(true),(sight.points as PackedVector3Array).size()," · %.0f m" % sight.distance if is_finite(float(sight.distance)) else ""]
	_label.add_theme_color_override("font_color",tint)
	_fill.size.x = 296.0*float(sight.awareness)
	_fill.color = tint
	_cone_mesh.clear_surfaces()
	_line_mesh.clear_surfaces()
	if not shown: return
	var eye: Vector3 = dragon.head_eye()
	var look: Vector3 = dragon.head_look()
	_draw_cone(eye,look,tint)
	_draw_lines(sight,eye)

## The cone: a fan of faint triangles from the eye to its far rim, the rim,
## rays out to it and a ring at NEAR.
func _draw_cone(eye: Vector3, look: Vector3, tint: Color) -> void:
	var side := look.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var up := side.cross(look).normalized()
	var rim := PackedVector3Array()
	var near := PackedVector3Array()
	for i in range(RAYS+1):
		var a := TAU*float(i)/float(RAYS)
		var way := (look*cos(DragonSight.HALF_ANGLE)+(side*cos(a)+up*sin(a))*sin(DragonSight.HALF_ANGLE)).normalized()
		rim.append(eye+way*DragonSight.RANGE)
		near.append(eye+way*DragonSight.NEAR)
	var fill := Color(tint,FILL_ALPHA)
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(RAYS):
		for p: Vector3 in [eye,rim[i],rim[i+1]]:
			_cone_mesh.surface_set_color(fill)
			_cone_mesh.surface_add_vertex(p)
	_cone_mesh.surface_end()
	var line := Color(tint,LINE_ALPHA)
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(RAYS):
		for p: Vector3 in [rim[i],rim[i+1],near[i],near[i+1]]:
			_cone_mesh.surface_set_color(line)
			_cone_mesh.surface_add_vertex(p)
		if i%3 == 0:
			for p: Vector3 in [eye,rim[i]]:
				_cone_mesh.surface_set_color(line)
				_cone_mesh.surface_add_vertex(p)
	# The snout's own line, bright.
	for p: Vector3 in [eye,eye+look*DragonSight.NEAR]:
		_cone_mesh.surface_set_color(Color(tint,0.9))
		_cone_mesh.surface_add_vertex(p)
	_cone_mesh.surface_end()

## A line from the eye to each of the pilot's points, by what it got.
func _draw_lines(sight: RefCounted, eye: Vector3) -> void:
	var points: PackedVector3Array = sight.points
	if points.is_empty(): return
	var seen: Array = sight.seen
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(points.size()):
		var p := points[i]
		var colour := OUT
		if DragonSight.in_view(eye,(sight.look as Vector3),p): colour = SEEN if i < seen.size() and bool(seen[i]) else BLOCKED
		for q: Vector3 in [eye,p]:
			_line_mesh.surface_set_color(colour)
			_line_mesh.surface_add_vertex(q)
	_line_mesh.surface_end()
