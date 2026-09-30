extends Control
## The naturalist's field case (docs/scenic/modeless.md "Materials tray
## (experiment)", brief docs/design/materials-tray/BRIEF.md): a long, low case
## of dark smoked glass along the bottom edge, edged in a brass hairline, one
## specimen to a compartment, engraved in amber line work (assets/ui/tray/,
## drawn by tools/paint_tray_specimens.py). Seeds, then water and stones, then
## snow, each group parted by a hairline. A compartment or two hold only a
## faint outline: kinds not found yet.
##
## It only draws; the hand (scripts/hand_materials.gd) reads `specimen_at` and
## `contains_pointer` and takes the presses, and it never takes a right press,
## so the camera's drag starts over it as anywhere.
##
## Nothing bounces. It rests receded, low and faint, and wakes as the pointer
## nears the bottom edge: a WAKE fade and a rise of at most RISE. The specimen
## under the pointer warms from resting to lit amber, a hairline draws out
## beneath it and its name fades in, in tracked small caps as the title's
## tagline is set. A specimen taken leaves its compartment faintly outlined
## while it is in the hand; one put back glides home and settles in.
##
## Everything is drawn in viewport pixels from design units at 1440x900
## (scripts/lantern_style.gd `ui_scale`), and the specimens are rasterised at
## the size they are drawn, so the line work stays crisp at any scale.

const Style = preload("res://scripts/lantern_style.gd")
const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const GLYPH_DIR := "res://assets/ui/tray/"
## The case, in order: id (what the hand holds), glyph, label, group. Those
## marked "hidden" are not found yet: a faint outline, or nothing ("glyph" "").
const SPECIMENS := [
	{"id":"oak","glyph":"acorn","label":"ACORN · OAK","group":0},
	{"id":"pine","glyph":"pine_cone","label":"PINE CONE · PINE","group":0},
	{"id":"willow","glyph":"willow_catkin","label":"WILLOW CATKIN","group":0},
	{"id":"birch","glyph":"birch_samara","label":"SAMARA · BIRCH","group":0},
	{"id":"wildflower","glyph":"seed_head","label":"SEED HEAD · MEADOW","group":0},
	{"id":"reed","glyph":"reed","label":"REED · WATERSIDE","group":0},
	{"id":"water","glyph":"water_drop","label":"WATER","group":1},
	{"id":"stone","glyph":"river_stone","label":"RIVER STONE","group":1},
	{"id":"crystal","glyph":"crystal","label":"","group":1,"hidden":true},
	{"id":"snow","glyph":"snowflake","label":"","group":2,"hidden":true},
	{"id":"vacant","glyph":"","label":"","group":2,"hidden":true},
]
## The amber ramp, beside the title's warm hairline (`e2d0aa`) and cream
## (`e3d7bd`): a specimen at rest, lit under the pointer, the case's brass
## hairline, and the deep amber of what is not found yet.
const AMBER_REST := Color("b08a55")
const AMBER_LIT := Color("f0c67f")
const BRASS := Color("c49a5c")
const AMBER_DEEP := Color("8a6b45")
## The label's cream, the title tagline's (`e6decd`, about 63% there).
const CREAM := Color("e6decd")
## Smoked glass: warmer at its top edge, deeper at its foot.
const GLASS_TOP := Color("231b12")
const GLASS_FOOT := Color("0b0a08")
const GLASS_ALPHA := Vector2(0.44,0.6)
## Layout, design units: a compartment's width, the case's height, the gap a
## group divider sits in, the case's side padding and its lift off the bottom
## edge. A specimen is GLYPH square, centred GLYPH_Y below the case's top; its
## hairline sits at RULE_Y and draws out to RULE wide; its label's baseline at
## LABEL_Y, LABEL_SIZE with LABEL_TRACK tracking.
const CELL := 66.0
const HEIGHT := 80.0
const GROUP_GAP := 20.0
const PAD := 18.0
const BOTTOM := 28.0
const GLYPH := 46.0
const GLYPH_Y := 33.0
const RULE_Y := 61.0
const RULE := 30.0
const LABEL_Y := 72.0
const LABEL_SIZE := 9.5
const LABEL_TRACK := 2.4
## At rest it shows RESTING of itself, sunk RISE; within NEAR of the bottom
## edge it wakes over WAKE seconds.
const RESTING := 0.42
const RISE := 4.0
const NEAR := 170.0
const WAKE := 0.3
## Seconds for a specimen's warm-up and hairline (HOVER), its fade as it is
## taken or settles back (HELD), a put-back's glide home (GLIDE) and an
## undiscovered compartment's quiet refusal (NOT_YET).
const HOVER := 0.2
const HELD := 0.2
const GLIDE := 0.3
const NOT_YET := 0.45
## A specimen's alpha while it is in the hand, and an undiscovered outline's
## at rest and under the pointer.
const HELD_ALPHA := 0.2
const HIDDEN_ALPHA := Vector2(0.26,0.36)

var ui_scale := 1.0
## 0..1 how shown it is (a world open, nothing over it), and how woken.
var shown := 0.0
var awake := 0.0
## The specimen the hand holds, or "".
var held := ""
## The specimen under the pointer, or "".
var hovered := ""
## Headless probes have no pointer: where they say it is.
var pointer_override: Variant = null
var _want_shown := false
var _font := FontVariation.new()
var _textures := {}
var _texture_px := 0
## Per specimen: "hover", "held", "refuse" progress (0..1, linear; drawn eased).
var _states := {}
## Specimens gliding home: {"id", "from" (viewport px), "t"}.
var _glides: Array[Dictionary] = []

func _ready() -> void:
	name = "MaterialsTray"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font.base_font = DISPLAY
	for entry: Dictionary in SPECIMENS: _states[entry.id] = {"hover":0.0,"held":0.0,"refuse":0.0}
	modulate.a = 0.0
	visible = false

## Show or hide it, eased.
func want(on: bool) -> void:
	_want_shown = on

## False for a compartment whose kind has not been found.
func discovered(id: String) -> bool:
	var entry := _entry(id)
	return not entry.is_empty() and not entry.get("hidden",false)

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in SPECIMENS:
		if entry.id == id: return entry
	return {}

# --- Reading the pointer --------------------------------------------------------

## The compartment under a viewport point, or "". Undiscovered ones count.
func specimen_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	for i in range(SPECIMENS.size()):
		if _cell(i).has_point(point): return SPECIMENS[i].id
	return ""

## True over the case.
func contains_pointer(point: Vector2) -> bool:
	return shown >= 0.5 and _case().grow(2.0*ui_scale).has_point(point)

## A specimen's centre, in viewport pixels.
func specimen_centre(id: String) -> Vector2:
	var i := _index(id)
	if i < 0: return _case().get_center()
	var cell := _cell(i)
	return Vector2(cell.get_center().x,cell.position.y+GLYPH_Y*ui_scale)

func _index(id: String) -> int:
	for i in range(SPECIMENS.size()):
		if SPECIMENS[i].id == id: return i
	return -1

func _width() -> float:
	var groups := int(SPECIMENS.back().group)+1
	return PAD*2.0+CELL*SPECIMENS.size()+GROUP_GAP*(groups-1)

## The case, viewport pixels.
func _case() -> Rect2:
	var screen := size
	var extent := Vector2(_width(),HEIGHT)*ui_scale
	var sink := RISE*(1.0-_eased(awake))*ui_scale
	return Rect2(Vector2(roundf((screen.x-extent.x)*0.5),roundf(screen.y-(BOTTOM+HEIGHT)*ui_scale+sink)),extent.round())

## A compartment's rect, viewport pixels.
func _cell(i: int) -> Rect2:
	var case := _case()
	var x := PAD+CELL*i+GROUP_GAP*int(SPECIMENS[i].group)
	return Rect2(case.position+Vector2(x*ui_scale,0.0),Vector2(CELL,HEIGHT)*ui_scale)

static func _eased(t: float) -> float:
	return smoothstep(0.0,1.0,clampf(t,0.0,1.0))

# --- Reactions ------------------------------------------------------------------

## The hand takes `id`: its compartment fades to a faint outline while it is out.
func lift_out(id: String) -> void:
	held = id

## A specimen put back from the hand at `from` (viewport pixels): it glides
## home and settles into its compartment.
func return_home(id: String, from: Vector2) -> void:
	if _index(id) < 0: return
	if held == id: held = ""
	_glides.append({"id":id,"from":from,"t":0.0})

## A press on a compartment not found yet: its outline warms a little and
## cools again. Nothing is given.
func not_yet(id: String) -> void:
	if _states.has(id): _states[id].refuse = 1.0

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport().get_visible_rect().size
	var scale_now := Style.ui_scale(screen)
	if not is_equal_approx(scale_now,ui_scale) or _textures.is_empty():
		ui_scale = scale_now
		_rasterise()
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta/WAKE)
	var near := _want_shown and screen.y-pointer.y <= NEAR*ui_scale
	# A specimen gliding home, or one in the hand, keeps the case awake.
	if not _glides.is_empty() or not held.is_empty(): near = near or _want_shown
	awake = move_toward(awake,1.0 if near else 0.0,delta/WAKE)
	visible = shown > 0.0
	if not visible:
		_glides.clear()
		return
	modulate.a = _eased(shown)*lerpf(RESTING,1.0,_eased(awake))
	hovered = specimen_at(pointer) if _want_shown and awake > 0.5 else ""
	var gliding := {}
	for glide: Dictionary in _glides.duplicate():
		glide.t = float(glide.t)+delta/GLIDE
		if float(glide.t) >= 1.0: _glides.erase(glide)
		else: gliding[glide.id] = true
	for entry: Dictionary in SPECIMENS:
		var state: Dictionary = _states[entry.id]
		state.hover = move_toward(float(state.hover),1.0 if entry.id == hovered and entry.id != held and not gliding.has(entry.id) else 0.0,delta/HOVER)
		state.held = move_toward(float(state.held),1.0 if entry.id == held or gliding.has(entry.id) else 0.0,delta/HELD)
		state.refuse = move_toward(float(state.refuse),0.0,delta/NOT_YET)
	queue_redraw()

## Specimens are rasterised at the size they are drawn. Exported builds may
## lack the SVG source; they fall back to the imported texture.
func _rasterise() -> void:
	var px := maxi(8,roundi(GLYPH*ui_scale))
	if px == _texture_px and not _textures.is_empty(): return
	_texture_px = px
	_textures.clear()
	for entry: Dictionary in SPECIMENS:
		var glyph: String = entry.glyph
		if glyph.is_empty(): continue
		var path := GLYPH_DIR+glyph+".svg"
		var source := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if source.is_empty():
			if ResourceLoader.exists(path): _textures[glyph] = load(path)
			continue
		var image := Image.new()
		if image.load_svg_from_string(source,px/48.0) != OK: continue
		_textures[glyph] = ImageTexture.create_from_image(image)
	_font.spacing_glyph = roundi(LABEL_TRACK*ui_scale)

func _hairline() -> float:
	return maxf(1.0,roundf(ui_scale))

func _draw() -> void:
	var case := _case()
	var line := _hairline()
	# The glass: warmer at the top, deeper at the foot.
	var top := Color(GLASS_TOP,GLASS_ALPHA.x)
	var foot := Color(GLASS_FOOT,GLASS_ALPHA.y)
	draw_polygon(PackedVector2Array([case.position,Vector2(case.end.x,case.position.y),case.end,Vector2(case.position.x,case.end.y)]),PackedColorArray([top,top,foot,foot]))
	# A brass hairline round it, and a fainter inner one: a case, not a pill.
	draw_rect(case.grow(-line*0.5),Color(BRASS,0.5),false,line)
	draw_rect(case.grow(-line*0.5-3.0*ui_scale),Color(BRASS,0.13),false,line)
	# The glass's sheen along its top edge.
	_rule(Vector2(case.position.x+PAD*ui_scale,case.position.y+line*2.0),Vector2(case.end.x-PAD*ui_scale,case.position.y+line*2.0),Color(CREAM,0.1),line)
	# Group dividers, fading out at both ends, as the title's rules.
	for i in range(1,SPECIMENS.size()):
		if SPECIMENS[i].group == SPECIMENS[i-1].group: continue
		var x := roundf(_cell(i).position.x-GROUP_GAP*0.5*ui_scale)+line*0.5
		_rule(Vector2(x,case.position.y+10.0*ui_scale),Vector2(x,case.end.y-10.0*ui_scale),Color(BRASS,0.5),line)
	var glyph_px := GLYPH*ui_scale
	for i in range(SPECIMENS.size()):
		var entry: Dictionary = SPECIMENS[i]
		var state: Dictionary = _states[entry.id]
		var cell := _cell(i)
		var centre := Vector2(cell.get_center().x,cell.position.y+GLYPH_Y*ui_scale)
		var hover := _eased(state.hover)
		var hidden: bool = entry.get("hidden",false)
		if hidden:
			var warm := _eased(state.refuse)*0.16
			var alpha := lerpf(HIDDEN_ALPHA.x,HIDDEN_ALPHA.y,hover)+warm
			if entry.glyph.is_empty():
				# A vacant place: only where its hairline would be.
				_rule(Vector2(centre.x-RULE*0.3*ui_scale,cell.position.y+RULE_Y*ui_scale),Vector2(centre.x+RULE*0.3*ui_scale,cell.position.y+RULE_Y*ui_scale),Color(AMBER_DEEP,alpha),line)
			else:
				_glyph(entry.glyph,centre,glyph_px,Color(AMBER_DEEP.lerp(AMBER_REST,warm*3.0),alpha))
			continue
		var colour := AMBER_REST.lerp(AMBER_LIT,hover)
		var alpha := lerpf(1.0,HELD_ALPHA,_eased(state.held))
		_glyph(entry.glyph,centre,glyph_px,Color(colour,alpha))
		# The hairline draws out from the middle.
		if hover > 0.0:
			var half := RULE*0.5*hover*ui_scale
			var y := roundf(cell.position.y+RULE_Y*ui_scale)+line*0.5
			_rule(Vector2(centre.x-half,y),Vector2(centre.x+half,y),Color(AMBER_LIT,0.75*hover),line)
	_label(case)
	for glide: Dictionary in _glides:
		var u := _eased(glide.t)
		var entry := _entry(glide.id)
		var at: Vector2 = (glide.from as Vector2).lerp(specimen_centre(glide.id),u)
		_glyph(entry.glyph,at,glyph_px*lerpf(0.8,1.0,u),Color(AMBER_LIT.lerp(AMBER_REST,u),0.7*(1.0-u*u)))

func _glyph(glyph: String, centre: Vector2, px: float, colour: Color) -> void:
	var texture: Texture2D = _textures.get(glyph)
	if texture == null or colour.a <= 0.0: return
	var rect := Rect2((centre-Vector2.ONE*px*0.5).round(),Vector2.ONE*roundf(px))
	draw_texture_rect(texture,rect,false,colour)

## A hairline from `a` to `b`, fading to nothing at both ends.
func _rule(a: Vector2, b: Vector2, colour: Color, width: float) -> void:
	var clear := Color(colour,0.0)
	var mid := (a+b)*0.5
	draw_polyline_colors(PackedVector2Array([a,a.lerp(mid,0.5),mid,b.lerp(mid,0.5),b]),PackedColorArray([clear,Color(colour,colour.a*0.7),colour,Color(colour,colour.a*0.7),clear]),width)

## The hovered specimen's name under it, kept inside the case.
func _label(case: Rect2) -> void:
	var shown_id := ""
	var best := 0.0
	for entry: Dictionary in SPECIMENS:
		var h := float(_states[entry.id].hover)
		if h > best and not str(entry.label).is_empty():
			best = h
			shown_id = entry.id
	if shown_id.is_empty(): return
	var entry := _entry(shown_id)
	var font_size := maxi(6,roundi(LABEL_SIZE*ui_scale))
	var text: String = entry.label
	var width := _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var centre := specimen_centre(shown_id)
	var x := clampf(centre.x-width*0.5,case.position.x+PAD*0.6*ui_scale,case.end.x-PAD*0.6*ui_scale-width)
	var at := Vector2(roundf(x),roundf(case.position.y+LABEL_Y*ui_scale))
	var alpha := _eased(best)
	draw_string(_font,at+Vector2(0.0,ui_scale),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,0.25*alpha))
	draw_string(_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(CREAM,0.78*alpha))
