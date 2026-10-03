extends Control
## The materials case (design "ZenScape HUD 4c", scripts/hud_linen.gd;
## docs/design/materials-tray/HUD-4c.md): a short strip of linen in shadow
## along the bottom edge, one compartment to a group of specimens (GROUPS):
## the trees, the flowers and crops, water and stone, and what is built. Each
## compartment shows one faceted low-poly icon (scripts/hud_icons.gd), the
## specimen last taken from it. Rest the pointer on it and the group's
## specimens fan out above the case on a scrap of the same linen, as the tool
## roll's modes fan beside its pocket (scripts/tool_roll.gd); press one and it
## is in hand, and the compartment shows it from then on. A press on the
## compartment itself takes the one it shows, so the last-used specimen is one
## press away. What you ADD to the world; the tool roll on the left holds how
## you shape it. Kinds not found yet show only their silhouette in pale
## linen, in the fan and, for a group not found at all, on the case.
##
## It only draws; the hand (scripts/hand_materials.gd) reads `specimen_at` and
## `contains_pointer` and takes the presses, and it never takes a right press,
## so the camera's drag starts over it as anywhere.
##
## Nothing bounces or loops. It rests receded (REST_OPACITY, sunk REST_SINK)
## and rises as the pointer nears the bottom edge; a drag in progress never
## wakes it, so pulling the plate's near rim down does not raise it under the
## hand. The material in hand is pressed into the cloth, its icon lit. Its
## name, or the hovered specimen's, shows on a small tag of linen over the
## case (over the fan while one is out), in small caps over a hairline.

const Linen = preload("res://scripts/hud_linen.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const Icons = preload("res://scripts/hud_icons.gd")
## Every specimen, in order: id (what the hand holds) and the `group` (a key
## of GROUPS) whose compartment it lives in; within a group they fan out in
## this order. Those marked "hidden" are not found yet: a silhouette only.
## Those marked "desert" are held back for an update
## (scripts/desert_landscape.gd `on`): not in the case at all.
const ALL_SPECIMENS := [
	{"id":"oak","group":0},
	{"id":"pine","group":0},
	{"id":"willow","group":0},
	{"id":"birch","group":0},
	{"id":"redwood","group":0},
	{"id":"juniper","group":0},
	{"id":"joshua","group":0,"desert":true},
	{"id":"wildflower","group":3},
	{"id":"dandelion","group":3},
	{"id":"poppy","group":3},
	{"id":"cosmos","group":3},
	{"id":"sunflower","group":3},
	{"id":"wheat","group":3},
	{"id":"reed","group":3},
	{"id":"water","group":4},
	{"id":"stone","group":4},
	{"id":"lamp","group":1},
	{"id":"campfire","group":1},
	{"id":"cabin","group":1},
	{"id":"fence","group":1},
	{"id":"bridge","group":1},
	{"id":"crystal","group":1,"hidden":true},
	{"id":"snow","group":2,"hidden":true},
]
## The case's compartments, left to right: a SPECIMENS `group` number each
## (the numbers are the old divider groups', kept so a specimen's line need not
## change: 1 is still what is set down or built). `apart` puts a double
## stitched line before it. A group a specimen names but this table does not
## gets a compartment of its own at the right end.
const GROUPS := {
	0:{"name":"Trees"},
	3:{"name":"Flowers & crops"},
	4:{"name":"Water & stone"},
	1:{"name":"Build"},
	2:{"name":"Not found yet","apart":true},
}
## The case: ALL_SPECIMENS, less the desert's while it is held back.
static var SPECIMENS: Array = _offered()

static func _offered() -> Array:
	if preload("res://scripts/desert_landscape.gd").on: return ALL_SPECIMENS.duplicate()
	return ALL_SPECIMENS.filter(func(entry: Dictionary) -> bool: return not entry.get("desert",false))
## Layout, design pixels: the gap between compartments, a divider's width (two
## lines 4 px apart) and height, the padding and the case's lift off the
## bottom edge. At rest it sinks REST_SINK. The name of the specimen hovered
## or in hand is on its own scrap of linen TAG_GAP over the case or the fan:
## TAG_PAD (x, y) round the small caps, coming and going over TAG_TIME s.
const GAP := 4.0
const DIVIDER_W := 5.0
const DIVIDER_H := 40.0
const PAD_TOP := 10.0
const TAG_GAP := 6.0
const TAG_PAD := Vector2(10.0,6.0)
const TAG_TIME := 0.15
const PAD_SIDE := 12.0
const PAD_BOTTOM := 10.0
const BOTTOM := 22.0
const REST_SINK := 8.0
## The fan over a compartment: a cell and icon each and its padding (design
## pixels), FAN_GAP over the case; it unfolds from the compartment over
## FAN_TIME s, rising FAN_RISE as it does. The pointer rests FAN_DWELL s on a
## compartment before its fan opens (one already out passes straight to the
## next), and the fan folds away FAN_LINGER s after the pointer leaves it.
const FAN_CELL := 52.0
const FAN_ICON := 40.0
const FAN_PAD := 4.0
const FAN_GAP := 6.0
const FAN_RISE := 6.0
const FAN_TIME := 0.18
const FAN_DWELL := 0.12
const FAN_LINGER := 0.25
## Within NEAR of the bottom edge it is reached for.
const NEAR := 150.0
## Seconds for a slot's hover patch, and a hidden slot's quiet refusal.
const HOVER_TIME := 0.15
const NOT_YET := 0.45
## First steps (scripts/first_steps_card.gd) points at a specimen with
## `nudge`: the ring takes NUDGE_FADE s to come and go and breathes once every
## NUDGE_PERIOD s.
const NUDGE_FADE := 0.5
const NUDGE_PERIOD := 3.0

var ui_scale := 1.0
## 0..1 how shown it is (a world open, nothing over it), and how reached for.
var shown := 0.0
var awake := 0.0
## The material the hand holds, or "".
var held := ""
## The specimen under the pointer (on the case or the fan), or "".
var hovered := ""
## True while a drag is under way elsewhere: the bar does not wake.
var quiet := false
## Headless probes have no pointer: where they say it is.
var pointer_override: Variant = null
## The group whose fan is out (or folding away), -1 for none, and how far
## out it is, 0..1.
var open_group := -1
var fan := 0.0
var _want_shown := false
var _away := 0.0
var _font: FontVariation
var _textures := {}
var _texture_px := 0.0
var _cloth: Linen.Cloth
var _fan_cloth: Linen.Cloth
## The name tag: its cloth, the specimen it names and how shown it is.
var _tag_cloth: Linen.Cloth
var _tag_for := ""
var _tag_a := 0.0
## Per specimen: its fan cell's "hover" and "refuse" (0..1, linear); per
## group: its compartment's "hover".
var _states := {}
var _group_states := {}
## Per group, the specimen its compartment shows (the last taken).
var _faces := {}
## The fan: how long the pointer has rested on a closed compartment, how
## long since it left the fan, and whether a take has put it away until the
## pointer leaves.
var _dwell := 0.0
var _linger := 0.0
var _dismissed := false
## The specimen the first-steps card is pointing at, or "". While one is
## pointed at the bar stays reached for and its compartment is stitched round, slowly.
var nudged := ""
var _nudge_for := ""
var _nudge_a := 0.0
var _nudge_t := 0.0

func _ready() -> void:
	name = "MaterialsTray"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	_fan_cloth = Linen.Cloth.new()
	_fan_cloth.visible = false
	add_child(_fan_cloth)
	_tag_cloth = Linen.Cloth.new()
	add_child(_tag_cloth)
	for entry: Dictionary in SPECIMENS: _states[entry.id] = {"hover":0.0,"refuse":0.0}
	for group: int in groups(): _group_states[group] = {"hover":0.0}
	modulate.a = 0.0
	visible = false

## Show or hide it, eased.
func want(on: bool) -> void:
	_want_shown = on

## Points at specimen `id` (a SPECIMENS id), or at none with "": the bar stays
## reached for (a drag still keeps it quiet), its compartment turns to show
## it and is stitched round and lifts a little, over and over, until it is
## cleared.
func nudge(id: String) -> void:
	nudged = id
	if id.is_empty(): return
	_nudge_for = id
	if discovered(id): _faces[group_of(id)] = id

## The nudge's frame: its ring comes and goes eased, and breathes while it is on.
func _nudge_step(delta: float) -> void:
	_nudge_a = move_toward(_nudge_a,1.0 if not nudged.is_empty() else 0.0,delta/NUDGE_FADE)
	_nudge_t = fposmod(_nudge_t+delta,NUDGE_PERIOD)
	if _nudge_a <= 0.0: _nudge_for = ""

## The pointing ring on `cell`: a faint lift of the hover patch and a stitched
## ring in the pip's stitch, both breathing. Nothing without a nudge.
func _nudge_ring(item: CanvasItem, cell: Rect2, line: float, radius: float) -> void:
	var a := Linen.eased(_nudge_a)
	if a <= 0.0: return
	var breath := 0.5-0.5*cos(_nudge_t/NUDGE_PERIOD*TAU)
	Linen.pressed_patch(item,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*a*breath),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*a*breath))
	var ring := cell.grow((1.0-3.0*breath)*ui_scale)
	Linen.dashed_round(item,ring,radius*ui_scale,Color(Linen.PIP_STITCH,Linen.PIP_STITCH.a*a*(0.45+0.55*breath)),line,ui_scale)

## False for a specimen whose kind has not been found.
func discovered(id: String) -> bool:
	var entry := _entry(id)
	return not entry.is_empty() and not entry.get("hidden",false)

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in specimens():
		if entry.id == id: return entry
	return {}

# --- Groups ---------------------------------------------------------------------

## The specimens the case holds, in order: SPECIMENS, read only through here
## so a world can leave some out.
func specimens() -> Array:
	return SPECIMENS

## The groups with a compartment, left to right: GROUPS' order, then any
## other group a specimen names, in the order they first appear.
func groups() -> Array:
	var out: Array = []
	var named := {}
	for entry: Dictionary in specimens(): named[int(entry.group)] = true
	for group: int in GROUPS:
		if named.has(group): out.append(group)
	for entry: Dictionary in specimens():
		if not int(entry.group) in out: out.append(int(entry.group))
	return out

## The ids in `group`, in fan order.
func members(group: int) -> Array:
	var out: Array = []
	for entry: Dictionary in specimens():
		if int(entry.group) == group: out.append(entry.id)
	return out

## The group `id` is in, or -1.
func group_of(id: String) -> int:
	var entry := _entry(id)
	return -1 if entry.is_empty() else int(entry.group)

## The specimen `group`'s compartment shows: the last taken from it, else its
## first found, else its first.
func face(group: int) -> String:
	var ids := members(group)
	if ids.is_empty(): return ""
	var last := str(_faces.get(group,""))
	if last in ids: return last
	for id: String in ids:
		if discovered(id): return id
	return ids[0]

## True for a group of more than one: its compartment fans out.
func _fans(group: int) -> bool:
	return members(group).size() > 1

# --- Reading the pointer --------------------------------------------------------

## The specimen under a viewport point, or "": a cell of the fan that is out,
## or a compartment (the one it shows). Undiscovered ones count.
func specimen_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	var on_fan := _fan_at(point)
	if not on_fan.is_empty(): return on_fan
	var group := _compartment_at(point)
	return face(group) if group >= 0 else ""

## True over the case or the fan that is out.
func contains_pointer(point: Vector2) -> bool:
	if shown < 0.5: return false
	if _bar().grow(2.0*ui_scale).has_point(point): return true
	return open_group >= 0 and fan > 0.0 and _fan_rect(open_group,fan).grow(2.0*ui_scale).has_point(point)

## Where a press takes `id`, in viewport pixels: its compartment while that
## shows it, else its cell on the group's fan (as it lies fully out, unless
## it is unfolding now).
func specimen_centre(id: String) -> Vector2:
	var group := group_of(id)
	if group < 0: return _bar().get_center()
	if face(group) == id: return compartment_centre(id)
	return _fan_cell(group,members(group).find(id),fan if group == open_group else 1.0).get_center()

## The centre of the compartment `id` lives in, viewport pixels: rest the
## pointer here to fan its group out.
func compartment_centre(id: String) -> Vector2:
	var at := groups().find(group_of(id))
	if at < 0: return _bar().get_center()
	return _cell(at).get_center()

## True when a press at `specimen_centre(id)` takes `id` now: its compartment
## shows it, or its group's fan is fully out.
func showing(id: String) -> bool:
	var group := group_of(id)
	if group < 0 or shown < 0.5: return false
	return face(group) == id or (group == open_group and fan >= 1.0)

## The group whose compartment is under a point, or -1.
func _compartment_at(point: Vector2) -> int:
	var order := groups()
	for i in range(order.size()):
		if _cell(i).has_point(point): return order[i]
	return -1

## The specimen on the open fan under a point, or "". Only once it is half out.
func _fan_at(point: Vector2) -> String:
	if open_group < 0 or fan < 0.5: return ""
	var ids := members(open_group)
	for k in range(ids.size()):
		if _fan_cell(open_group,k,fan).has_point(point): return ids[k]
	return ""

## How many compartments set apart (GROUPS `apart`) are at or before place `i`.
func _apart_through(i: int) -> int:
	var order := groups()
	var count := 0
	for k in range(mini(i+1,order.size())):
		if bool(GROUPS.get(order[k],{}).get("apart",false)): count += 1
	return count

func _width() -> float:
	var n := groups().size()
	return PAD_SIDE*2.0+Linen.SLOT*n+GAP*(n-1)+(DIVIDER_W+GAP)*_apart_through(n-1)

## The case, viewport pixels.
func _bar() -> Rect2:
	var height := PAD_TOP+Linen.SLOT+PAD_BOTTOM
	var extent := Vector2(_width(),height)*ui_scale
	var sink := REST_SINK*(1.0-Linen.eased(awake))*ui_scale
	return Rect2(Vector2(roundf((size.x-extent.x)*0.5),roundf(size.y-(BOTTOM+height)*ui_scale+sink)),extent.round())

## Compartment `i` (a place in `groups()`), viewport pixels.
func _cell(i: int) -> Rect2:
	var bar := _bar()
	var x := PAD_SIDE+(Linen.SLOT+GAP)*i+(DIVIDER_W+GAP)*_apart_through(i)
	return Rect2((bar.position+Vector2(x,PAD_TOP)*ui_scale).round(),Vector2.ONE*roundf(Linen.SLOT*ui_scale))

## The fan's centre x for `group`, fully out: over its compartment, kept on screen.
func _fan_x(group: int) -> float:
	var x := _cell(groups().find(group)).get_center().x
	var half := (FAN_PAD*2.0+FAN_CELL*members(group).size())*0.5*ui_scale
	var margin := 8.0*ui_scale
	return clampf(x,margin+half,maxf(margin+half,size.x-margin-half))

## The fan's scrap of linen over `group`'s compartment, `out` (0..1) unfolded.
func _fan_rect(group: int, out: float) -> Rect2:
	var eased := Linen.eased(out)
	var n := members(group).size()
	var extent := Vector2(FAN_PAD*2.0+FAN_CELL*lerpf(1.0,n,eased),FAN_PAD*2.0+FAN_CELL)*ui_scale
	var bottom := _bar().position.y-(FAN_GAP-FAN_RISE*(1.0-eased))*ui_scale
	return Rect2(Vector2(roundf(_fan_x(group)-extent.x*0.5),roundf(bottom-extent.y)),extent.round())

## Cell `k` of `group`'s fan, `out` unfolded: they spread from the middle.
func _fan_cell(group: int, k: int, out: float) -> Rect2:
	var rect := _fan_rect(group,out)
	var n := members(group).size()
	var x := _fan_x(group)+(k-(n-1)*0.5)*FAN_CELL*Linen.eased(out)*ui_scale
	var cell := roundf(FAN_CELL*ui_scale)
	return Rect2(Vector2(roundf(x-cell*0.5),rect.position.y+roundf(FAN_PAD*ui_scale)),Vector2.ONE*cell)

## Where the pointer keeps `group`'s fan out: the fan, its compartment and
## the gap between them.
func _fan_zone(group: int) -> Rect2:
	var rect := _fan_rect(group,1.0).grow(8.0*ui_scale)
	return rect.merge(_cell(groups().find(group)))

# --- Reactions ------------------------------------------------------------------

## The hand takes `id`: its compartment shows it, pressed into the cloth, and
## a fan that is out folds away until the pointer leaves it.
func lift_out(id: String) -> void:
	held = id
	var group := group_of(id)
	if group >= 0: _faces[group] = id
	if open_group >= 0: _dismissed = true

## The material goes back: its compartment comes up again. (`_from`, where
## the hand let it go, is kept for the API; nothing glides.)
func return_home(id: String, _from := Vector2.ZERO) -> void:
	if held == id: held = ""

## A press on a specimen not found yet: its silhouette warms a little and
## cools again. Nothing is given.
func not_yet(id: String) -> void:
	if _states.has(id): _states[id].refuse = 1.0
	ClaySound.cue(&"ui_refuse")

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport().get_visible_rect().size
	var scale_now := Linen.hud_scale_for(screen)
	if not is_equal_approx(scale_now,ui_scale) or _textures.is_empty():
		ui_scale = scale_now
		_rasterise()
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta/Linen.REACH)
	var on_it := _bar().grow(6.0*ui_scale).has_point(pointer) or (open_group >= 0 and _fan_zone(open_group).has_point(pointer))
	var near := _want_shown and not quiet and (screen.y-pointer.y <= NEAR*ui_scale or (awake > 0.0 and on_it) or not nudged.is_empty())
	if near:
		_away = 0.0
		if awake == 0.0: ClaySound.cue(&"ui_reach")
		awake = move_toward(awake,1.0,delta/Linen.REACH)
	else:
		_away += delta
		if _away >= Linen.HOLD: awake = move_toward(awake,0.0,delta/Linen.RECEDE)
	_nudge_step(delta)
	_fan_step(delta,pointer)
	visible = shown > 0.0
	if not visible: return
	modulate.a = Linen.eased(shown)*lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake))
	var reaching := _want_shown and awake > 0.5
	var was_hovered := hovered
	hovered = specimen_at(pointer) if reaching else ""
	if hovered != was_hovered and not hovered.is_empty() and hovered != held: ClaySound.cue(&"ui_hover")
	var on_fan := _fan_at(pointer) if reaching else ""
	var on_case := _compartment_at(pointer) if reaching and on_fan.is_empty() else -1
	for entry: Dictionary in SPECIMENS:
		var state: Dictionary = _states[entry.id]
		var on: bool = entry.id == on_fan and entry.id != held and not entry.get("hidden",false)
		state.hover = move_toward(float(state.hover),1.0 if on else 0.0,delta/HOVER_TIME)
		state.refuse = move_toward(float(state.refuse),0.0,delta/NOT_YET)
	for group: int in _group_states:
		var shows := face(group)
		var on: bool = group == on_case and shows != held and discovered(shows)
		_group_states[group].hover = move_toward(float(_group_states[group].hover),1.0 if on else 0.0,delta/HOVER_TIME)
	_cloth.place(_bar(),ui_scale)
	_fan_cloth.visible = open_group >= 0 and fan > 0.0
	if _fan_cloth.visible:
		_fan_cloth.place(_fan_rect(open_group,fan),ui_scale,2.0,Vector2.ZERO)
		_fan_cloth.modulate.a = Linen.eased(fan)
	# The tag names the hovered specimen (once found), else what is in hand.
	var named := hovered if not hovered.is_empty() and discovered(hovered) else held
	if not named.is_empty(): _tag_for = named
	_tag_a = move_toward(_tag_a,1.0 if not named.is_empty() and named == _tag_for else 0.0,delta/TAG_TIME)
	var tag := _tag_rect()
	_tag_cloth.visible = tag.size.x > 0.0
	if _tag_cloth.visible: _tag_cloth.place(tag,ui_scale,2.0,Vector2.ZERO)
	_tag_cloth.modulate.a = Linen.eased(_tag_a)
	queue_redraw()

## The fan's frame: the pointer resting on a compartment of several opens its
## fan (straight away if another is already out); on the fan or between it
## and its compartment it stays; elsewhere it folds after FAN_LINGER. A take
## folds it until the pointer has left.
func _fan_step(delta: float, pointer: Vector2) -> void:
	var reaching := _want_shown and not quiet and shown >= 0.5 and awake > 0.5
	var over := _compartment_at(pointer) if reaching else -1
	var in_zone := reaching and open_group >= 0 and _fan_zone(open_group).has_point(pointer)
	if over < 0 and not in_zone: _dismissed = false
	var want_fan := false
	if reaching and not _dismissed:
		if over >= 0 and _fans(over):
			if over == open_group: want_fan = true
			elif open_group >= 0 and fan > 0.0:
				open_group = over
				fan = 0.0
				want_fan = true
			else:
				_dwell += delta
				if _dwell >= FAN_DWELL:
					open_group = over
					fan = 0.0
					want_fan = true
		elif over < 0 and in_zone: want_fan = true
	if over < 0 or not _fans(over) or want_fan: _dwell = 0.0
	if want_fan: _linger = 0.0
	else: _linger += delta
	var hold := want_fan or (_linger < FAN_LINGER and not _dismissed and reaching)
	fan = move_toward(fan,1.0 if hold and open_group >= 0 else 0.0,delta/FAN_TIME)
	if fan <= 0.0 and not hold: open_group = -1

## The name tag's scrap of linen over what it names (its cell on the fan
## while that is out, else its compartment), or an empty rect for none.
func _tag_rect() -> Rect2:
	var group := group_of(_tag_for)
	if _tag_a <= 0.0 or group < 0: return Rect2()
	var x := compartment_centre(_tag_for).x
	var top := _bar().position.y
	if open_group >= 0 and fan > 0.0:
		top = _fan_rect(open_group,fan).position.y
		if group == open_group and fan >= 0.5: x = _fan_cell(group,members(group).find(_tag_for),fan).get_center().x
	var extent := Vector2(Linen.tag_width(_font,_tag_text(),ui_scale)+TAG_PAD.x*2.0*ui_scale,(Linen.TAG_CAPS+TAG_PAD.y*2.0+4.0)*ui_scale)
	return Rect2(Vector2(roundf(x-extent.x*0.5),roundf(top-TAG_GAP*ui_scale-extent.y)),extent.round())

func _tag_text() -> String:
	return str(Icons.item(_tag_for).get("label",""))

func _rasterise() -> void:
	var px := Linen.ICON*ui_scale
	if is_equal_approx(px,_texture_px) and not _textures.is_empty(): return
	_texture_px = px
	var ids := []
	for entry: Dictionary in SPECIMENS: ids.append(entry.id)
	Linen.rasterise(_textures,ids,px)

func _draw() -> void:
	var line := maxf(1.0,roundf(ui_scale))
	var order := groups()
	for i in range(order.size()):
		var group: int = order[i]
		var cell := _cell(i)
		# A compartment set apart: two stitched lines, 4 px apart, before it.
		if i > 0 and bool(GROUPS.get(group,{}).get("apart",false)):
			var x := cell.position.x-(GAP+DIVIDER_W)*ui_scale
			var top := cell.get_center().y-DIVIDER_H*0.5*ui_scale
			for k in range(2):
				var lx := roundf(x+k*4.0*ui_scale)+line*0.5
				Linen.dashed(self,PackedVector2Array([Vector2(lx,top),Vector2(lx,top+DIVIDER_H*ui_scale)]),Linen.DIVIDER,line,3.0*ui_scale,3.0*ui_scale)
		var id := face(group)
		var on := id == held
		var hover := Linen.eased(float(_group_states[group].hover))
		if on: Linen.pressed_patch(self,cell,ui_scale,Linen.PRESSED,Linen.PRESSED_SHADE)
		elif hover > 0.0: Linen.pressed_patch(self,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*hover),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*hover))
		if group_of(_nudge_for) == group: _nudge_ring(self,cell,line,Linen.SLOT_RADIUS)
		_specimen(id,cell.get_center(),Linen.ICON,on)
		# A compartment that fans: three stitches along its top edge, gone
		# while its fan is out.
		if _fans(group):
			var a := Linen.DIVIDER.a*(1.0-(Linen.eased(fan) if group == open_group else 0.0))
			for k in range(3):
				var dot := Vector2(cell.get_center().x+(k-1)*4.0*ui_scale,cell.position.y+4.0*ui_scale)
				draw_circle(dot,0.9*ui_scale,Color(Linen.DIVIDER,a),true,-1.0,true)
	_draw_fan(line)
	# The name of the specimen hovered or in hand, on its tag.
	var tag := _tag_rect()
	if tag.size.x > 0.0: Linen.tag(self,_font,_tag_text(),tag.get_center().x,tag.end.y-TAG_PAD.y*ui_scale,ui_scale,Linen.eased(_tag_a))

## The open group's fan: each specimen in a cell, the one in hand pressed in,
## those not found yet a silhouette; drawn last first, so the folded cells
## sit under the first.
func _draw_fan(line: float) -> void:
	if open_group < 0 or fan <= 0.0: return
	var ids := members(open_group)
	var alpha := Linen.eased(fan)
	for k in range(ids.size()-1,-1,-1):
		var id: String = ids[k]
		var cell := _fan_cell(open_group,k,fan).grow(-2.0*ui_scale)
		var on := id == held
		var hover := Linen.eased(float(_states[id].hover))
		if on: Linen.pressed_patch(self,cell,ui_scale,Color(Linen.PRESSED,Linen.PRESSED.a*alpha),Color(Linen.PRESSED_SHADE,Linen.PRESSED_SHADE.a*alpha))
		elif hover > 0.0: Linen.pressed_patch(self,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*hover*alpha),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*hover*alpha))
		if id == _nudge_for: _nudge_ring(self,cell,line,6.0)
		_specimen(id,cell.get_center(),FAN_ICON,on,alpha)

## Specimen `id`'s icon round `centre`, `icon` design pixels across: lit in
## hand, a silhouette (warming as it refuses) while not found.
func _specimen(id: String, centre: Vector2, icon: float, on: bool, alpha := 1.0) -> void:
	if not discovered(id):
		var warm := Linen.eased(_states[id].refuse)*0.25
		Linen.icon(self,_textures,id,centre,icon*ui_scale,ui_scale,"locked",0.0,Color(Color.WHITE.lerp(Color(1.25,1.2,1.1),warm),alpha))
		return
	Linen.icon(self,_textures,id,centre,icon*ui_scale,ui_scale,"lit" if on else "icon",(1.0 if on else 2.0)*icon/Linen.ICON,Color(1.0,1.0,1.0,alpha))
