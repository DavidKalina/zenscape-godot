extends Control
## The maker's jars (docs/scenic/modeless.md "Materials tray (experiment)"): a
## slim rounded strip low in the middle of the bottom edge, holding seeds,
## water and stones. It only draws; the hand (scripts/hand_materials.gd) reads
## `jar_at` and `contains_pointer` and takes the presses, and it never takes a
## right press, so the camera's drag starts over it as anywhere.
##
## It rests low and faint, and rises and brightens a little as the pointer
## nears the bottom edge. The jar under the pointer lifts and names itself;
## taking from a jar squashes it (`squash`), and material put back flies home
## to its jar, which settles as it lands (`fly_home`).
##
## Numbers are design units at 1440x900, scaled as the Lantern shell scales
## (scripts/lantern_style.gd `ui_scale`).

const Style = preload("res://scripts/lantern_style.gd")
const JARS := ["seeds","water","stones"]
const NAMES := {"seeds":"Seeds","water":"Water","stones":"Stones"}
const TINTS := {"seeds":Color("a9dc92"),"water":Color("92cdf2"),"stones":Color("c9bdb0")}
## A jar's slot, its glyph, the strip's padding, height and corner, and its
## lower edge's gap to the bottom of the screen.
const JAR := 46.0
const GLYPH := 30.0
const PAD := 9.0
const HEIGHT := 48.0
const CORNER := 16
const BOTTOM := 14.0
## Resting it is RESTING opaque and sunk REST_DROP; within NEAR of the bottom
## edge it rises to full (ALERT opaque). It eases there at EASE (1/s).
const RESTING := 0.36
const ALERT := 0.92
const REST_DROP := 7.0
const NEAR := 150.0
const EASE := 7.0
## A hovered jar lifts HOVER_LIFT and grows by HOVER_GROW.
const HOVER_LIFT := 3.0
const HOVER_GROW := 0.1
## The jars' springs (1/s², 1/s): under-damped, so a squash overshoots once.
const SPRING := 260.0
const DAMP := 12.0
## A put-back mote's flight home (s) and how high it arcs (design units).
const FLIGHT := 0.4
const ARC := 70.0

var ui_scale := 1.0
## 0..1 how shown it is (a world open, nothing over it), and how near the
## pointer is to the bottom edge; both eased.
var shown := 0.0
var near := 0.0
## The jar whose material the hand holds, or "".
var held := ""
## The jar under the pointer, or "".
var hovered := ""
## Headless probes have no pointer: where they say it is.
var pointer_override: Variant = null
var _want_shown := false
var _root := Control.new()
var _strip := Panel.new()
var _glyphs := {}
var _halos := {}
var _name := Label.new()
var _fx := Control.new()
## Per jar: squash (and its rate), lift (and its rate), hover (0..1).
var _jars := {}
## Motes on their way home: {"kind", "from" (design), "t"}.
var _flights: Array[Dictionary] = []
static var _material: ShaderMaterial

func _ready() -> void:
	name = "MaterialsTray"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_theme_stylebox_override("panel",Style.plate(CORNER,0.34,10))
	_root.add_child(_strip)
	for kind: String in JARS:
		var halo := TextureRect.new()
		halo.texture = Style.glyph("halo")
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_SCALE
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.size = Vector2.ONE*JAR*1.3
		halo.pivot_offset = halo.size*0.5
		halo.modulate = Color(TINTS[kind],0.0)
		_root.add_child(halo)
		_halos[kind] = halo
		var glyph := TextureRect.new()
		glyph.texture = load("res://assets/ui/tray/%s.svg" % kind)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.size = Vector2.ONE*GLYPH
		# Scaled about the jar's foot, so a squash sits on the strip.
		glyph.pivot_offset = Vector2(GLYPH*0.5,GLYPH*0.86)
		glyph.material = glyph_material()
		_root.add_child(glyph)
		_glyphs[kind] = glyph
		_jars[kind] = {"squash":0.0,"squash_v":0.0,"lift":0.0,"lift_v":0.0,"hover":0.0}
	Style.style_label(_name,14,Style.LIGHT,true)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.modulate.a = 0.0
	_root.add_child(_name)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_flights)
	_root.add_child(_fx)
	modulate.a = 0.0
	visible = false

## The Lantern glyph's rim and glow, softer, for filled glyphs.
static func glyph_material() -> ShaderMaterial:
	if _material != null: return _material
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/lantern_glyph.gdshader")
	_material.set_shader_parameter("rim_color",Color(Style.SHADE,0.5))
	_material.set_shader_parameter("rim",0.026)
	_material.set_shader_parameter("glow",0.06)
	_material.set_shader_parameter("glow_strength",0.25)
	return _material

## Show or hide it, eased.
func want(on: bool) -> void:
	_want_shown = on

# --- Reading the pointer --------------------------------------------------------

## The jar under a viewport point, or "".
func jar_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	var at := _design(point)
	for kind: String in JARS:
		if Rect2(_slot(kind),Vector2(JAR,HEIGHT)).has_point(at): return kind
	return ""

## True over the strip.
func contains_pointer(point: Vector2) -> bool:
	return shown >= 0.5 and _strip_rect().grow(2.0).has_point(_design(point))

## A jar's centre, in viewport pixels.
func jar_centre(kind: String) -> Vector2:
	return (_slot(kind)+Vector2(JAR,HEIGHT)*0.5)*ui_scale

func _design(point: Vector2) -> Vector2:
	return point/maxf(ui_scale,0.01)

func _strip_rect() -> Rect2:
	var size := Vector2(JAR*JARS.size()+PAD*2.0,HEIGHT)
	var drop := REST_DROP*(1.0-_eased(near))
	return Rect2(Vector2((_root.size.x-size.x)*0.5,_root.size.y-BOTTOM-HEIGHT+drop),size)

func _slot(kind: String) -> Vector2:
	var strip := _strip_rect()
	return strip.position+Vector2(PAD+JAR*JARS.find(kind),0.0)

static func _eased(t: float) -> float:
	return smoothstep(0.0,1.0,t)

# --- Reactions ------------------------------------------------------------------

## A pinch taken from `kind`: the jar squashes and springs back.
func squash(kind: String) -> void:
	if not _jars.has(kind): return
	_jars[kind].squash_v -= 5.5

## Material of `kind` put back from the hand at `from` (viewport pixels): a
## mote flies home in an arc and the jar settles as it lands.
func fly_home(kind: String, from: Vector2) -> void:
	if not _jars.has(kind): return
	_flights.append({"kind":kind,"from":_design(from),"t":0.0})

func _settle(kind: String) -> void:
	_jars[kind].lift = -6.0
	_jars[kind].lift_v = 0.0
	_jars[kind].squash_v -= 2.2

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport().get_visible_rect().size
	ui_scale = Style.ui_scale(screen)
	_root.scale = Vector2.ONE*ui_scale
	_root.size = screen/ui_scale
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	var rate := 1.0-exp(-EASE*delta)
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta*3.0)
	var close := clampf(1.0-(screen.y-pointer.y)/(NEAR*ui_scale),0.0,1.0) if _want_shown else 0.0
	# A mote flying home brings the tray up to meet it.
	if not _flights.is_empty(): close = maxf(close,0.7)
	near = lerpf(near,close,rate)
	visible = shown > 0.0
	if not visible:
		_flights.clear()
		return
	modulate.a = _eased(shown)*lerpf(RESTING,ALERT,_eased(near))
	hovered = jar_at(pointer) if _want_shown else ""
	var strip := _strip_rect()
	_strip.position = strip.position
	_strip.size = strip.size
	for kind: String in JARS:
		var jar: Dictionary = _jars[kind]
		jar.hover = lerpf(float(jar.hover),1.0 if kind == hovered else 0.0,1.0-exp(-12.0*delta))
		jar.squash_v += (-float(jar.squash)*SPRING-float(jar.squash_v)*DAMP)*delta
		jar.squash += float(jar.squash_v)*delta
		var falling := float(jar.lift) < 0.0
		jar.lift_v += (-float(jar.lift)*SPRING*0.7-float(jar.lift_v)*DAMP)*delta
		jar.lift += float(jar.lift_v)*delta
		# The settle's touch-down squashes it a little.
		if falling and float(jar.lift) >= 0.0: jar.squash_v -= 1.6
		var s := float(jar.squash)
		var grow := 1.0+HOVER_GROW*float(jar.hover)
		var glyph: TextureRect = _glyphs[kind]
		var centre := _slot(kind)+Vector2(JAR,HEIGHT)*0.5
		glyph.position = centre-glyph.size*0.5+Vector2(0.0,float(jar.lift)-HOVER_LIFT*float(jar.hover))
		glyph.scale = Vector2(grow*(1.0-0.55*s),grow*(1.0+s))
		# A jar whose material is out is a touch quieter.
		glyph.modulate.a = 0.72 if kind == held else 1.0
		var halo: TextureRect = _halos[kind]
		halo.position = centre-halo.size*0.5
		halo.modulate.a = 0.55*float(jar.hover)+(0.22 if kind == held else 0.0)
		halo.scale = Vector2.ONE*(0.85+0.2*float(jar.hover))
	# The hovered jar's name, in quiet sentence case over it.
	if not hovered.is_empty():
		_name.text = NAMES[hovered]
		_name.size = _name.get_minimum_size()
	var label_a := float(_jars[hovered].hover) if not hovered.is_empty() else 0.0
	_name.modulate.a = lerpf(_name.modulate.a,0.9*label_a,1.0-exp(-10.0*delta))
	if not hovered.is_empty():
		var over := _slot(hovered)+Vector2(JAR*0.5,0.0)
		_name.position = Vector2(over.x-_name.size.x*0.5,strip.position.y-_name.size.y-4.0)
	for flight: Dictionary in _flights.duplicate():
		flight.t = float(flight.t)+delta/FLIGHT
		if float(flight.t) >= 1.0:
			_flights.erase(flight)
			_settle(flight.kind)
	_fx.size = _root.size
	_fx.queue_redraw()

## Put-back motes: a soft tinted dot on an arc home, shrinking as it lands.
func _draw_flights() -> void:
	for flight: Dictionary in _flights:
		var t := clampf(float(flight.t),0.0,1.0)
		var u := t*t*(3.0-2.0*t)
		var to := _slot(flight.kind)+Vector2(JAR,HEIGHT)*0.5
		var from: Vector2 = flight.from
		var mid := (from+to)*0.5+Vector2(0.0,-ARC)
		var at := from.lerp(mid,u).lerp(mid.lerp(to,u),u)
		var colour: Color = TINTS[flight.kind]
		var r := lerpf(6.0,3.0,u)
		_fx.draw_circle(at,r*2.2,Color(colour,0.16*(1.0-u*0.5)),true,-1.0,true)
		_fx.draw_circle(at,r,Color(colour,0.9),true,-1.0,true)
