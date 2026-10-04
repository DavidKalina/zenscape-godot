extends Control
## The title as cards (Claude Design "ZenScape Main Menu Cards", face 5d
## Coin; docs/design/title-cards/README.md). Two fans over the orbiting world:
## the main menu (Continue, Your worlds, A new world, Almanac, Rest) and
## world select, every world as its card plus a blank one at the end. Cards
## bob at rest; the one under the pointer lifts and tilts toward it while its
## neighbours lean away; a press sinks it a little; a pick draws it up and
## sinks the rest, and its action follows (`picked`, `enter_requested`,
## `new_world_requested`). ◂ ▸ move, ↵ picks, Esc goes back from world select.
##
## The host (studies/cozy_worlds.gd) owns what the picks do: it switches the
## views (`show_menu`, `show_worlds`), loads the hovered world live behind
## world select (`selection_changed`, then `reveal_live`) and leaves the title.
## Lengths are design pixels of the 1440 x 810 frame times `px`; the fans
## and the hint keep to the foot of the screen, the words to its top.

signal picked(action: String)
signal enter_requested(world: Dictionary)
signal new_world_requested
signal back_requested
signal selection_changed(world: Dictionary)

const Card = preload("res://scripts/menu_card.gd")
const WorldCard = preload("res://scripts/world_card.gd")
const Library = preload("res://scripts/world_library.gd")
const WorldTitle = preload("res://scripts/world_title.gd")
const Style = preload("res://scripts/worlds_style.gd")
const FRAME := Vector2(1440,810)
## The fans: card spacing, centre height in the frame, the arc's drop (×d²),
## the card's scale and the turn per step from the middle (degrees).
const FANS := {
	"menu":{"sp":188.0,"cy":606.0,"arc":6.0,"sc":0.72,"rot":2.5},
	"worlds":{"sp":166.0,"cy":640.0,"arc":5.0,"sc":0.62,"rot":2.0},
}
## A fan never runs closer than this to the screen's sides.
const SIDE := 64.0
## The springs, per 60 Hz step: stiffness and damping.
const K := 0.085
const D := 0.76
const STEP := 1.0/60.0
## Seconds a pick's card rises before its action, and before a settings pick
## (which leaves the title up) settles back.
const DRAW := 0.65
const SETTLE := 1.7
const FADE := 0.3
## The menu's picks, as the design's cards. Colours are the coin window's:
## top and low of its sky, sun and hill. Continue takes its world's.
const ITEMS := [
	{"id":"continue","label":"Continue","glyph":"globe","line":"Back to %s","top":"8b95a2","low":"c4bfb2","sun":"fff3d6","hill":"4f8a5a"},
	{"id":"worlds","label":"Your worlds","glyph":"crystal","line":"Draw from your deck","top":"8a7c9c","low":"e2a462","sun":"f2c79a","hill":"b0703c","deck":true},
	{"id":"new","label":"A new world","glyph":"willow","line":"Sow a fresh seed","top":"4c6c6c","low":"9cc2a0","sun":"d8ecd4","hill":"2f6c4c"},
	{"id":"settings","label":"Almanac","glyph":"dandelion","line":"Sound, light & hands","top":"b89c68","low":"f0cf86","sun":"fff3d6","hill":"c9944e"},
	{"id":"quit","label":"Rest","glyph":"reed","line":"Leave the wilds for now","top":"3c4458","low":"7a8a96","sun":"e8ece6","hill":"3e5a4a"},
]
const ROMAN := ["I","II","III","IV","V","VI","VII","VIII","IX","X"]
const SCRIM_DARK := Color(16/255.0,12/255.0,16/255.0)

## The design's tweaks: how much cards bob, and whether the hovered one tilts
## and its neighbours lean.
var bob := 1.0
var tilt := true
var lean := true
var library
## A fixed clock (unix seconds) for tests; below 0 reads the system's.
var now := -1.0
## "menu" or "worlds".
var view := "menu"
## The menu's picks as shown, and the worlds (most recent first).
var items: Array = []
var worlds: Array = []
var menu_cards: Array = []
var world_cards: Array = []
## Per fan: the card under the pointer (or keys), and the card picked; -1 for none.
var hovered := {"menu":-1,"worlds":-1}
var chosen := {"menu":-1,"worlds":-1}
## World select's focused card: its world is behind, its words above.
var focus := 0
var px := 1.0
var veil := Control.new()
var capture := TextureRect.new()
var shade := ColorRect.new()
var hint: Label
var menu_mark: Control
var worlds_head: Control
var back_link: Button
var count_label: Label
var info: Control
var kicker: Label
var name_label: Label
var line_label: Label
var _menu_layer := Control.new()
var _worlds_layer := Control.new()
var _t := 0.0
var _carry := 0.0
var _serial := 0
var _shown_id := "~"
var _textures := {}
var _veil_tween: Tween
var _shade_tween: Tween

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The world's capture over the live backdrop while it loads, as on the library.
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.modulate.a = 0.0
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dark := ColorRect.new()
	dark.color = SCRIM_DARK
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(dark)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	capture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(capture)
	capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The backdrop dimmed (and on the menu softened), then the scrim.
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/title_backdrop.gdshader")
	shade.material = material
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_scrim()
	_build_words()
	for layer: Control in [_menu_layer,_worlds_layer]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint = WorldTitle.label("",Style.newsreader(500),13,Style.SECONDARY_LINEN,0.26,true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	resized.connect(_layout)
	_set_view("menu")

func _add_scrim() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.3,0.55,1.0])
	gradient.colors = PackedColorArray([Color(20/255.0,16/255.0,22/255.0,0.45),Color(20/255.0,16/255.0,22/255.0,0.0),Color(20/255.0,16/255.0,22/255.0,0.0),Color(SCRIM_DARK,0.7)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 256
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(0,1)
	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The menu's wordmark, centred at the top; world select's, top left with
## the way back, its count top right, and the focused world's words.
func _build_words() -> void:
	menu_mark = WorldTitle.box(true,12)
	add_child(menu_mark)
	# The wordmark's tracking trails its last letter; the design pads its left
	# by as much (.48em) so the letters sit centred.
	var pad := WorldTitle.margins(Vector4(0.48*44.0,0,0,0))
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.add_child(WorldTitle.label("ZENSCAPE",Style.newsreader(400),44,Style.INK,0.48))
	menu_mark.add_child(pad)
	var tagline := WorldTitle.label("a little wilderness, made by you",Style.newsreader(500),14,Style.SECONDARY_SCENE,0.32,true)
	tagline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_mark.add_child(tagline)
	worlds_head = WorldTitle.box(true,10)
	add_child(worlds_head)
	worlds_head.add_child(WorldTitle.label("ZENSCAPE",Style.newsreader(400),26,Style.INK,0.42))
	back_link = WorldTitle.link("◂ Menu",14,Style.THREAD,Style.HOVER_INK,0.26)
	back_link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_link.pressed.connect(func() -> void: back_requested.emit())
	worlds_head.add_child(back_link)
	count_label = WorldTitle.label("",Style.spectral(),17,Style.INK)
	add_child(count_label)
	info = WorldTitle.box(true,10)
	add_child(info)
	kicker = WorldTitle.label("",Style.newsreader(500),13,Style.SECONDARY_SCENE,0.3,true)
	name_label = WorldTitle.label("",Style.newsreader(400),56,Style.INK_PRIMARY)
	WorldTitle.shadow(name_label,Color(10/255.0,8/255.0,10/255.0,0.25),2,6)
	line_label = WorldTitle.label("",Style.spectral_italic(),17,Style.THREAD)
	WorldTitle.shadow(line_label,Color(10/255.0,8/255.0,10/255.0,0.3),1,4)
	for node: Label in [kicker,name_label,line_label]:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_child(node)

# --- What the host calls -------------------------------------------------------------

## Reads the library: `setup` once, then the views re-read it as they open.
func setup(world_library) -> void:
	library = world_library

## The main menu, dealt afresh.
func show_menu() -> void:
	_refresh_items()
	_set_view("menu")
	deal("menu")

## World select, dealt afresh with `select_id` (or the most recent world)
## in focus; its world is announced for the backdrop.
func show_worlds(select_id := "") -> void:
	worlds = library.worlds() if library != null else []
	_textures.clear()
	focus = 0
	for i in worlds.size():
		if worlds[i].id == select_id: focus = i
	_build_world_cards()
	_set_view("worlds")
	deal("worlds")
	_shown_id = "~"
	_show_focus()

## A pick that leaves the title up (the almanac) lets its card settle back.
func settle() -> void:
	chosen[view] = -1
	_update_hint()

## Fades the capture off once the host's live world has caught up.
func reveal_live() -> void:
	_fade_veil(0.0)

## Each card sunk below the screen, rising in turn.
func deal(fan: String) -> void:
	hovered[fan] = -1
	chosen[fan] = -1
	var cards := _cards(fan)
	for i in cards.size():
		var card: Card = cards[i]
		card.rest()
		card.sk = 2.2+i*0.35
	_update_hint()
	_step(0.0)

func selected_world() -> Dictionary:
	return worlds[focus].duplicate() if focus < worlds.size() else {}

## Picks card `index` of the shown fan: it rises, the rest sink, and its
## action follows DRAW seconds later.
func choose(index: int) -> void:
	var fan := view
	var cards := _cards(fan)
	if index < 0 or index >= cards.size() or chosen[fan] >= 0: return
	chosen[fan] = index
	_update_hint()
	_serial += 1
	var serial := _serial
	await get_tree().create_timer(DRAW).timeout
	if serial != _serial or view != fan or chosen[fan] != index or not is_visible_in_tree(): return
	if fan == "menu":
		var action: String = items[index].id
		picked.emit(action)
		if action == "settings":
			await get_tree().create_timer(SETTLE-DRAW).timeout
			if serial == _serial and view == fan and chosen[fan] == index: settle()
	elif index >= worlds.size(): new_world_requested.emit()
	else: enter_requested.emit(worlds[index].duplicate())

## Moves the hover a card along (the keys); from none, the menu starts in
## the middle, world select a card along from the focused world.
func browse(step: int) -> void:
	var cards := _cards(view)
	if cards.is_empty() or chosen[view] >= 0: return
	var at: int = hovered[view]
	if at < 0 and view == "menu": at = int((cards.size()-1)/2.0)
	else: at = clampi((focus if at < 0 else at)+step,0,cards.size()-1)
	hovered[view] = at
	for card: Card in cards:
		card.mx = 0.0
		card.my = 0.0
	if view == "worlds": _focus_on(at)

# --- Building ------------------------------------------------------------------------

func _refresh_items() -> void:
	var latest: Dictionary = {}
	if library != null:
		var all: Array = library.worlds()
		if not all.is_empty(): latest = all[0]
	items = []
	for item: Dictionary in ITEMS:
		var entry := item.duplicate()
		if entry.id == "continue":
			# Nothing to continue without a world.
			if latest.is_empty(): continue
			entry.line = str(entry.line) % str(latest.name)
			var pal: Dictionary = WorldCard.of(latest).pal
			entry.top = pal.sky
			entry.low = pal.glow
			entry.sun = pal.sun
			entry.hill = pal.land
		items.append(entry)
	_build_menu_cards()

func _build_menu_cards() -> void:
	_resize(menu_cards,_menu_layer,items.size(),"menu")
	for i in items.size():
		var item: Dictionary = items[i]
		menu_cards[i].set_spec({"kind":"coin","glyph":item.glyph,"roman":ROMAN[i],"label":item.label,"sub":item.line,
			"top":Color(item.top),"low":Color(item.low),"sun":Color(item.sun),"hill":Color(item.hill)},item.get("deck",false))
	_layout()

func _build_world_cards() -> void:
	_resize(world_cards,_worlds_layer,worlds.size()+1,"worlds")
	for i in worlds.size():
		var world: Dictionary = worlds[i]
		var card := WorldCard.of(world)
		var spec := WorldCard.coin_colours(card.pal)
		spec.merge({"kind":"coin","world":true,"haze_on":true,"glyph":card.hero,"roman":WorldCard.roman(_number(world)),
			"label":str(world.name),"sub":_sub(world,card)},true)
		world_cards[i].set_spec(spec)
	world_cards[worlds.size()].set_spec({"kind":"blank","label":"Begin a new world","sub":"name it, choose the land"})
	_layout()

## Grows or trims `cards` to `count`, wiring new ones to `fan`.
func _resize(cards: Array, layer: Control, count: int, fan: String) -> void:
	while cards.size() > count:
		var gone: Card = cards.pop_back()
		layer.remove_child(gone)
		gone.queue_free()
	while cards.size() < count:
		var card := Card.new()
		card.hovered.connect(func(at: Card) -> void: _on_hovered(fan,at))
		card.unhovered.connect(func(at: Card) -> void: _on_unhovered(fan,at))
		card.pointed.connect(func(at: Card, where: Vector2) -> void:
			at.mx = where.x
			at.my = where.y)
		card.chosen.connect(func(at: Card) -> void: if view == fan: choose(_cards(fan).find(at)))
		cards.append(card)
		layer.add_child(card)

func _number(world: Dictionary) -> int:
	return library.number(str(world.id)) if library != null and library.has_method("number") else 0

## The card's foot: the first two parts of its mood, or its land.
func _sub(world: Dictionary, card: Dictionary) -> String:
	var short := WorldCard.mood_short(card.mood)
	return short if not short.is_empty() else Library.land_name(str(world.get("land","plain")))

func _cards(fan: String) -> Array:
	return menu_cards if fan == "menu" else world_cards

# --- Views, focus and words ----------------------------------------------------------

func _set_view(next: String) -> void:
	view = next
	var menu := view == "menu"
	_menu_layer.visible = menu
	menu_mark.visible = menu
	_worlds_layer.visible = not menu
	worlds_head.visible = not menu
	count_label.visible = not menu
	info.visible = not menu
	if menu: _fade_veil(0.0)
	# The menu's backdrop blur(2px) brightness(.72); world select's brightness(.82).
	var material := shade.material as ShaderMaterial
	if _shade_tween: _shade_tween.kill()
	var target := Vector2(0.72,2.0*px) if menu else Vector2(0.82,0.0)
	if is_inside_tree():
		_shade_tween = create_tween().set_parallel(true)
		_shade_tween.tween_method(func(v: float) -> void: material.set_shader_parameter("brightness",v),float(material.get_shader_parameter("brightness")),target.x,0.4)
		_shade_tween.tween_method(func(v: float) -> void: material.set_shader_parameter("blur",v),float(material.get_shader_parameter("blur")),target.y,0.4)
	else:
		material.set_shader_parameter("brightness",target.x)
		material.set_shader_parameter("blur",target.y)
	_update_hint()
	_layout()

func _on_hovered(fan: String, card: Card) -> void:
	var index := _cards(fan).find(card)
	hovered[fan] = index
	if fan == "worlds" and index >= 0: _focus_on(index)

func _on_unhovered(fan: String, card: Card) -> void:
	if hovered[fan] == _cards(fan).find(card): hovered[fan] = -1

func _focus_on(index: int) -> void:
	if index == focus: return
	focus = index
	_show_focus()

## World select's words for the focused card; a new world is announced.
func _show_focus() -> void:
	var blank := focus >= worlds.size()
	if blank:
		count_label.text = "A blank card"
		kicker.text = Style.caps("Blank card")
		name_label.text = "A new world"
		line_label.text = "A fresh seed, nothing placed yet"
	else:
		var world: Dictionary = worlds[focus]
		var card := WorldCard.of(world)
		count_label.text = "Your worlds · %d of %d" % [focus+1,worlds.size()]
		kicker.text = Style.caps("No. %02d · %s" % [_number(world),Library.relative_time(float(world.get("last_played_at",0.0)),_now())])
		name_label.text = str(world.name)
		var parts: Array = []
		parts.append(card.mood if not str(card.mood).is_empty() else Library.land_name(str(world.get("land","plain"))))
		if not str(world.get("seed","")).is_empty(): parts.append("seed "+str(world.seed))
		line_label.text = " · ".join(parts)
	_layout()
	# The blank card keeps the world behind it.
	if blank: return
	var id := str(worlds[focus].id)
	if id == _shown_id: return
	_shown_id = id
	capture.texture = _capture_of(id)
	_fade_veil(1.0)
	selection_changed.emit(worlds[focus].duplicate())

func _capture_of(id: String) -> Texture2D:
	if library == null: return null
	if not _textures.has(id):
		var path: String = library.thumbnail_path(id)
		var image := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_textures[id] = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	return _textures[id]

func _fade_veil(alpha: float) -> void:
	if _veil_tween: _veil_tween.kill()
	if not is_inside_tree():
		veil.modulate.a = alpha
		return
	_veil_tween = create_tween()
	_veil_tween.tween_property(veil,"modulate:a",alpha,FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_hint() -> void:
	var at: int = chosen[view]
	var text := ""
	if view == "menu": text = "Opening · "+str(items[at].label) if at >= 0 and at < items.size() else "hover or ◂ ▸ · ↵ to choose"
	elif at >= 0: text = "Sowing a new world" if at >= worlds.size() else "Entering · "+str(worlds[at].name)
	else: text = "◂ ▸ browse · ↵ enter · esc menu"
	hint.text = Style.caps(text)

func _now() -> float:
	return now if now >= 0.0 else Time.get_unix_time_from_system()

# --- Layout and motion ---------------------------------------------------------------

## The frame fitted inside the screen: one design pixel in viewport pixels.
static func scale_for(screen: Vector2) -> float:
	return maxf(0.25,minf(screen.x/FRAME.x,screen.y/FRAME.y))

## Card `i` of `count`'s resting place in a fan on a `screen` (design
## pixels): its centre, and the fan's spacing, drop and turn as used.
static func fan_spot(fan: String, i: int, count: int, screen: Vector2) -> Dictionary:
	var spec: Dictionary = FANS[fan]
	var mid := (count-1)*0.5
	var spacing: float = spec.sp
	# Many worlds close the fan up to keep inside the sides; a long fan drops
	# and turns no further at its ends than the design's seven.
	if count > 1: spacing = minf(spacing,(screen.x-SIDE*2.0-240.0*spec.sc)/(count-1))
	var reach := maxf(mid,3.0)
	var arc: float = spec.arc*minf(1.0,9.0/(reach*reach))
	var turn: float = spec.rot*minf(1.0,3.0/reach)
	var d := i-mid
	return {"centre":Vector2(screen.x*0.5+d*spacing,screen.y-(FRAME.y-spec.cy)+d*d*arc),"turn":turn,"d":d}

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	px = scale_for(size)
	WorldTitle.rescale(self,px)
	var screen := size/px
	for fan: String in ["menu","worlds"]:
		var cards := _cards(fan)
		var sc: float = FANS[fan].sc
		for i in cards.size():
			var card: Card = cards[i]
			var spot := fan_spot(fan,i,cards.size(),screen)
			card.set_k(sc*px)
			card.position = ((spot.centre-Card.CENTRE*sc)*px).round()
	_place(menu_mark,Vector2(size.x*0.5,92.0*px),0.5)
	_place(worlds_head,Vector2(64.0*px,46.0*px),0.0)
	_place(count_label,Vector2(size.x-64.0*px,52.0*px),1.0)
	_place(info,Vector2(size.x*0.5,236.0*px),0.5)
	_place(hint,Vector2(size.x*0.5,size.y-30.0*px),0.5)
	if view == "menu" and shade.material != null and (_shade_tween == null or not _shade_tween.is_running()):
		(shade.material as ShaderMaterial).set_shader_parameter("blur",2.0*px)
	_step(0.0)

## Sets `node` at its fitted size, its top at `at.y` and `anchor` of its
## width (0 left, .5 centre, 1 right) at `at.x`.
func _place(node: Control, at: Vector2, anchor: float) -> void:
	node.size = node.get_combined_minimum_size()
	node.position = Vector2(roundf(at.x-node.size.x*anchor),roundf(at.y))

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_step(delta)

## Advances the springs in 60 Hz steps and poses every card of the shown fan
## (the design's `step`).
func _step(delta: float) -> void:
	_t += delta
	_carry = minf(_carry+delta,STEP*4.0)
	var fan := view
	var cards := _cards(fan)
	var hov: int = hovered[fan]
	var ch: int = chosen[fan]
	while _carry >= STEP:
		_carry -= STEP
		for i in cards.size():
			var s: Card = cards[i]
			_spring(s,"l",1.9 if ch == i else (1.0 if ch < 0 and hov == i else 0.0))
			_spring(s,"sk",1.0 if ch >= 0 and ch != i else 0.0)
			_spring(s,"n",signf(i-hov)*(26.0 if absi(i-hov) == 1 else 10.0) if lean and ch < 0 and hov >= 0 and hov != i else 0.0)
			_spring(s,"p",1.0 if s.down else 0.0)
			s.sx += ((s.mx if hov == i else 0.0)-s.sx)*0.14
			s.sy += ((s.my if hov == i else 0.0)-s.sy)*0.14
	var screen := size/px if px > 0.0 else FRAME
	for i in cards.size():
		var s: Card = cards[i]
		var spot := fan_spot(fan,i,cards.size(),screen)
		var lift := clampf(s.l,0.0,1.0)
		var by := sin(_t*1.15+i*1.7)*7.0*bob*(1.0-lift*0.55)
		var br := sin(_t*0.8+i*2.1)*0.9*bob*(1.0-lift*0.7)
		var y := by-s.l*30.0+s.sk*70.0+absf(s.n)*0.4
		var turn: float = spot.d*spot.turn*(1.0-lift)+br+s.n*0.08
		var art := Vector3(s.sx*7.0*lift,s.sy*5.0*lift-lift*5.0,s.sx*-4.0*lift) if fan == "menu" else Vector3.ZERO
		s.pose(Vector2(s.n,y),turn,1.0+s.l*0.07-s.p*0.05,maxf(0.0,1.0-s.sk*0.5),
			Vector2(-s.sy*12.0*lift,s.sx*14.0*lift) if tilt else Vector2.ZERO,art,
			Vector3(0.5+s.sx*0.45,0.35+s.sy*0.45,0.22*lift),
			Vector3(s.n,1.0-s.l*0.2+by*0.012,maxf(0.0,0.75-lift*0.3-s.sk*0.4)))
		# The card in hand over its neighbours where a long fan overlaps.
		s.z_index = 1 if i == ch or (ch < 0 and i == hov) else 0

## v = (v + (target - x)·K)·D; x += v.
static func _spring(card: Card, key: String, target: float) -> void:
	var v: float = (float(card.get(key+"v"))+(target-float(card.get(key)))*K)*D
	card.set(key+"v",v)
	card.set(key,float(card.get(key))+v)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	var handled := true
	match (event as InputEventKey).keycode:
		KEY_LEFT: browse(-1)
		KEY_RIGHT: browse(1)
		KEY_ENTER, KEY_KP_ENTER:
			var at: int = hovered[view]
			if at < 0 and view == "worlds": at = focus
			if at >= 0: choose(at)
		KEY_ESCAPE:
			if view == "worlds" and chosen.worlds < 0: back_requested.emit()
			else: handled = false
		_: handled = false
	if handled: get_viewport().set_input_as_handled()
