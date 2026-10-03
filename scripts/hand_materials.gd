extends Node
## The materials tray, an experiment (docs/scenic/modeless.md "Materials tray
## (experiment)"): the linen materials bar along the bottom edge
## (scripts/materials_tray.gd) and the tool roll on the left
## (scripts/tool_roll.gd), design "ZenScape HUD 4c"
## (docs/design/materials-tray/HUD-4c.md). One thing is in hand across both:
## the bare Hand, or one material. The roll's pips (or 1, 2, 3, [ and ]) size
## it: the clay's reach, or a scatter's spread. Esc, the Hand or the material
## again puts a material down. With a tool that has modes in hand (the
## Modeller, the Sculpt, the Paddle, the Chisel, the Wire), its fan in the roll
## (or Q and E) says what its press does. A built shaping tool in the roll is taken by
## pressing it (scripts/land_clay.gd `set_tool`, docs/design/tools/PLAN.md);
## Esc or the Hand puts it back, and taking a material does too. Press a material and
## some is in hand: no hand holds it (docs/design/tools/PLAN.md "The hand at
## the rim"). A small stand-in of the material itself is the cursor (`Clump`):
## a pinch of seeds tinted by kind, a bead of water, a few pebbles. It moves
## as a shaping tool's prop does (scripts/cursor_motion.gd). What is in hand
## decides what a press does.
##
## - **Tree seeds** (oak, pine, willow, birch, redwood, juniper, Joshua). Press and drag over the land:
##   the pinch flicks the forest brush's veil out along the way (FLICK_SECONDS),
##   and the wind carries it down (NativeChunkEditor `sow_from_hand`, the Forest
##   brush's own veil, scripts/pollen_cloud.gd). The seeds' kind is stamped on the veil, as
##   a flicked tree's spores are: what comes up leans to it, as far as the
##   ground there allows (SEEDS).
## - **Flowers** (wildflower, dandelion, poppy, cosmos, sunflower;
##   scripts/flower_sowing.gd SLOTS) are a paintbrush. Press and drag over the
##   land: flowers come up under the brush as it goes, growing in at once; go
##   over them again, or linger, and the drift packs toward a full core, its
##   edge feathered. A tap paints a small dab. The ground still decides where
##   they can stand (not on water, rock, snow, steep slopes, under trees or on
##   stones), and they compose as a meadow type's drift. Shift thins the
##   flowers under the brush instead, as the Brush's Shift wipes. The pips
##   size the brush; one undo step a stroke (NativeChunkEditor
##   `paint_flowers_begin`, scripts/flower_paint.gd). The wind's veil is kept
##   for pollen from what already grows, later.
## - **Reeds.** Tap to set a clump of reeds; drag to scatter more under the
##   pointer (SCATTER: the build palette's plants, set down by
##   NativeChunkEditor `set_objects`, one undo step a drag). They sprout as a
##   placed plant does.
## - **Water.** Press and hold over the land: the bead swells into a water
##   ball that fills while held, and on release is tossed up, pops on its own
##   beat and drops, a pool or a spring as the ground decides (NativeChunkEditor
##   `ball_from_sky`, the cloud tuft's own ball; scripts/water_ball.gd). The
##   bead comes back once the ball is down.
## - **Stones.** Tap to set one down, bigger the longer the press; drag to
##   scatter a few pebbles under the pointer (the rock tool's placement).
##
## - **The Feather** (the tool roll's "feather", HUD 5 "Gust"): wind held in
##   hand, taken like a tool. Drag it over the land: the wind goes with it
##   while it moves, along the path it takes, as hard as it moves, and dies
##   away when let go (a live wake). Hold still FEATHER_BURST_SECONDS: a
##   burst, rung out round the press on release (a shorter still press sends
##   nothing). Both are the wind tool's own air (NativeChunkEditor `gust_in_hand`,
##   scripts/wind_gust.gd), FEATHER_HALF m either side at the middle pip. It
##   changes no land and takes no undo step. Dragging wind from the sky onto
##   the land puts the Feather in hand too (`take_feather`).
##
## A press in the sky, on the case or on the specimen held puts the material
## back; so does letting go there after drawing it out of the case. A press on
## a compartment not found yet gives nothing. The rim keeps its verbs with
## material in hand. The cloud still gives water as before; a tree's flick
## gives seeds with the Feather in hand, as a shaping tool presses through a
## tree to the land under it. `--no-tray` leaves all of this out.
##
## Made by scripts/hand_reach.gd, which hands it the presses first.

const Tray = preload("res://scripts/materials_tray.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const Foot = preload("res://scripts/tool_foot.gd")
const Almanac = preload("res://scripts/almanac.gd")
const Card = preload("res://scripts/first_steps_card.gd")
const Pages = preload("res://scripts/almanac_pages.gd")
const Palette = preload("res://scripts/command_palette.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Modeless = preload("res://scripts/modeless_input.gd")
## Tree seeds: the specimen and the emergence tree kind it sows
## (scripts/tree_stands.gd TREE_POOLS; "tree" is the spruce family's pine).
const SEEDS := {"oak":"broadleaf","pine":"tree","willow":"willow","birch":"birch","redwood":"redwood","juniper":"juniper","joshua":"joshua"}
## Flowers: the slots scripts/flower_sowing.gd composes, painted
## (scripts/flower_paint.gd). PAINT is their press's hold.
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const PAINT := "paint"
## While painting, the clump sheds a little and the brush is heard at most
## every PAINT_CUE seconds that flowers come up under it.
const PAINT_CUE := 0.28
## Things set down by a tap or a drag: the assets (one picked for each), how
## many one drop sets and how far they spread (m), a tap's size range (record
## scale, growing over `grow` s of holding) and a drag's (growing over
## `scatter_grow` s), and at most `most` drops a drag.
const SCATTER := {
	"stone":{"assets":["rock"],"each":1,"spread":0.0,"tap":Vector2(0.5,1.4),"grow":1.6,"scatter":Vector2(0.26,0.6),"scatter_grow":2.5,"most":7},
	"reed":{"assets":["reeds"],"each":3,"spread":0.4,"tap":Vector2(0.6,1.0),"grow":1.6,"scatter":Vector2(0.55,0.85),"scatter_grow":2.5,"most":8},
}
## Pressed, the cursor comes down to PRESS_GAP m over the land: a stone
## touches it, a pinch of seeds or flowers stops short.
const PRESS_GAP := {"stone":0.0}
const PRESS_GAP_DEFAULT := 0.1
## Sowing from the pinch: while the button is held it flicks every
## FLICK_SECONDS (the first FIRST_FLICK after the press), and once more as the
## button comes up, throwing what has gathered in it (the veil's `toss`,
## scripts/pollen_cloud.gd, whose motes wait in it at most 0.6 s) out along its
## way at FLICK_OUT and up at FLICK_UP m/s, plus THROW_CARRY of the pointer's
## speed, at most MAX_THROW m/s. Where the seeds land is the veil's, as ever.
const FLICK_SECONDS := 0.45
const FIRST_FLICK := 0.25
const FLICK_OUT := 1.5
const FLICK_UP := 3.0
const THROW_CARRY := 1.3
const MAX_THROW := 7.0
const GodHand = preload("res://scripts/god_hand.gd")
const CursorMotion = preload("res://scripts/cursor_motion.gd")
## A drag drops a set every STONE_GAP m under the pointer, no sooner than
## STONE_SECONDS apart (and only once the last has been drawn and has landed).
const STONE_GAP := 0.9
const STONE_SECONDS := 0.3
## The Feather. It is not a clay tool (it shapes no land), so its press is
## held here, as "scatter" is, and handed to the wind tool, which reads the
## pointer each frame; the prop and the grip come from the clay's seam
## (scripts/clay_tools/feather.gd). FEATHER_HALF is the wake's half-width (m)
## at the middle pip: the wind brush's radius (scripts/wind_brush.gd). The
## pips scale it as they scale every tool, 0.6 / 1 / 1.5 (the design's 20 /
## 34 / 52 px lanes). A still press held FEATHER_BURST_SECONDS is a burst;
## let go sooner it sends nothing, so a stray click blows nothing. The burst's
## ring (the ground mark) grows from the wake's half-width to FEATHER_RING
## times it, 1.5× the wake's width across, over the wind tool's gather
## (WindGust.BURST_GATHER), then the gust rings out past it on release.
const FEATHER := "feather"
const FEATHER_HALF := 3.0
const FEATHER_BURST_SECONDS := 0.4
const FEATHER_RING := 1.5
## Screen pixels a press may wander and still be a tap.
const CLICK_PIXELS := 6.0
## The hint line with material in hand, until each has been used once.
const SOW_HINT := "Drag over the land to sow"
const FLOWER_HINT := "Drag over the land to paint flowers  ·  Shift thins them"
const HINTS := {"water":"Hold over water to scoop it up","stone":"Tap to set a stone  ·  Drag to scatter pebbles",
	"reed":"Tap to set reeds  ·  Drag to scatter"}
const BACK_HINT := "Click the sky or the case to put it back"
## Water in hand pressed on dry land: nothing to scoop.
const DRY_HINT := "No water here to scoop  ·  Pour some with the watering can"
## The watering can (the tool roll's "can"): not a clay tool either. Its press
## on the land is held here, as the Feather's is, and handed to the can's
## stream (NativeChunkEditor `can_in_hand`, scripts/watering_can.gd), which
## reads the pointer each frame until the button comes up.
const CAN := "can"
## The roll's tool while nothing is in hand: Esc, or the tool's own pocket
## pressed again, puts the tool down (LandClay `put_tool_down`). The land is
## not worked, and trees bend and flick as for the Feather.
const FREE := ""
## Design units the Lantern hint line moves up to clear the case.
const HINT_LIFT := 124.0

static func enabled() -> bool:
	return Modeless.enabled() and not "--no-tray" in OS.get_cmdline_user_args()

var scene: Node3D
var reach: Node
var tray: Control
var roll: Control
var foot: Control
## The HUD's one "hud hidden" switch: while true every HUD piece in HUD_GROUP
## steps out (`want(false)`). Photo mode throws it (scripts/tool_foot.gd). A new
## piece (the almanac) joins HUD_GROUP and has `want(on)`; the foot follows the roll.
const HUD_GROUP := "hud_piece"
var hud_hidden := false
## The almanac on the right edge (scripts/almanac.gd, HUD 5): the air's pockets.
var almanac: Control
## The first steps' card (scripts/first_steps_card.gd), top right, once the
## scene has its model (`show_first_steps`); null without one.
var card: Control
var _first_steps: Node
## The step the hand was last made ready for (`_take_for`).
var _asked := ""
## The page the almanac last asked for, [page, row], until the pages
## (scripts/almanac_pages.gd, another branch) take the request.
var page_asked := []
## The almanac's Moods and Customise pages (scripts/almanac_pages.gd), opened
## by its pockets and tags. They take their own input while open.
var pages: Control
## The command palette (scripts/command_palette.gd): Cmd/Ctrl K or /.
var palette: Control
var clump: Clump
## The specimen in hand (a materials_tray.gd SPECIMENS id) or "".
var held := ""
## Stones, flowers and reeds set down, for probes.
var stones_set := 0
var _press_pos := Vector2.ZERO
var _left_tray := false
var _held_seconds := 0.0
var _travel := 0.0
var _stone_last: Variant = null
var _stone_step: Variant = null
var _stone_count := 0
var _stone_since := 0.0
## Seconds to the pinch's next flick, and whether it was sowing last frame;
## flicks thrown, for probes.
var _flick_in := FIRST_FLICK
var _sowing := false
var flicks := 0
var _paint_cue := 0.0
var _paint_seen := 0
var _shell_lifted := false
## Seconds the Feather's press has been held, and what its last release sent
## ("wake", "burst" or "" for nothing), with counts, for the marks and probes.
var feather_seconds := 0.0
var feather_last := ""
var feather_sent := {"wake":0,"burst":0,"none":0}

func setup(owner_scene: Node3D, hand_reach: Node) -> void:
	scene = owner_scene
	reach = hand_reach
	name = "HandMaterials"
	var layer := CanvasLayer.new()
	layer.name = "MaterialsTrayLayer"
	layer.layer = 19
	add_child(layer)
	tray = Tray.new()
	layer.add_child(tray)
	roll = Roll.new()
	layer.add_child(roll)
	# The Modeller is in hand from the start: its fan, once the clay is made.
	_show_modes.call_deferred(roll.tool)
	foot = Foot.new()
	foot.setup(roll,self)
	layer.add_child(foot)
	tray.add_to_group(HUD_GROUP)
	roll.add_to_group(HUD_GROUP)
	almanac = Almanac.new()
	layer.add_child(almanac)
	almanac.setup(scene,reach)
	almanac.page_requested.connect(_page_requested)
	pages = Pages.new()
	layer.add_child(pages)
	pages.setup(scene)
	palette = Palette.new()
	layer.add_child(palette)
	palette.setup(scene,self)
	clump = Clump.new()
	clump.name = "HeldMaterial"
	clump.ground = func(flat: Vector2) -> Variant: return reach._editor().data.ground_height(flat)
	reach._editor().terrain.add_child(clump)

## Puts the first steps' card on the HUD's layer for the scene's model
## (scripts/first_steps.gd). The pocket its step names is nudged, the others
## let go.
func show_first_steps(steps: Node) -> void:
	if card != null or steps == null or tray == null: return
	card = Card.new()
	tray.get_parent().add_child(card)
	card.setup(scene,steps)
	_first_steps = steps
	card.pointing_changed.connect(func(piece: String, id: String) -> void:
		var pieces := {"roll":roll,"tray":tray,"almanac":almanac,"foot":foot}
		for key: String in pieces: pieces[key].nudge(id if key == piece else ""))

## Makes the hand ready for the step the card asks (scripts/first_steps.gd
## VERBS `take`): its tool from the roll, in its mode, or the tool put down,
## and the mode's cell on the fan is ringed. A step without one leaves the
## hand as it is.
func _take_for(step_id: String) -> void:
	var take := str(_first_steps.verb(step_id).get("take",""))
	roll.nudge_mode("")
	if take.is_empty(): return
	var parts := take.split(":")
	if not held.is_empty(): put_back()
	select_tool(FREE if parts[0] == "free" else parts[0])
	if parts.size() > 1:
		set_mode(parts[1])
		roll.nudge_mode(parts[1])

## True over the materials bar, the tool roll or its foot, the almanac, the
## first steps' card or an open page, while they show.
func tray_under(point: Vector2) -> bool:
	return (card != null and card.contains_pointer(point)) or (tray != null and tray.contains_pointer(point)) or (roll != null and roll.contains_pointer(point)) \
		or (foot != null and foot.contains_pointer(point)) or (almanac != null and almanac.contains_pointer(point)) \
		or (pages != null and pages.is_open() and pages.contains_pointer(point)) or (palette != null and palette.is_open())

## The almanac asks for a page: the Moods page, or Customise at a row.
func _page_requested(page: String, row: String) -> void:
	page_asked = [page,row]
	if pages != null:
		pages.open(page,row)
		ClaySound.cue(&"ui_page")

## The size in hand (the roll's pips): the clay's reach and a scatter's spread.
func size_scale() -> float:
	return roll.size_scale() if roll != null else 1.0

func set_size(level: int) -> void:
	if roll == null: return
	var was: int = roll.size_level
	roll.size_level = clampi(level,0,Roll.SIZES.size()-1)
	if roll.size_level != was: ClaySound.cue(&"ui_size")
	var clay: Node = scene.get("land_clay")
	if clay != null: clay.size_scale = roll.size_scale()

## Keys for the hand's HUD: 1, 2, 3 or [ and ] size what is in hand; Q and E
## step the mode of the tool in hand; Esc puts a material down, else the tool
## (FREE), else falls through to the menu. True when the key was used.
func key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo or roll == null or roll.shown < 0.5: return false
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed: return false
	match event.keycode:
		KEY_1, KEY_2, KEY_3: set_size(event.keycode-KEY_1)
		KEY_BRACKETLEFT: set_size(roll.size_level-1)
		KEY_BRACKETRIGHT: set_size(roll.size_level+1)
		KEY_Q, KEY_E:
			var clay: Node = scene.get("land_clay")
			if clay == null or not held.is_empty() or roll.modes.is_empty() or clay.tool_id != roll.tool: return false
			clay.tool.step_mode(-1 if event.keycode == KEY_Q else 1)
			set_mode(clay.tool.mode)
		KEY_ESCAPE:
			if not held.is_empty(): put_back()
			elif roll.tool != FREE: select_tool(FREE)
			else: return false
		_: return false
	return true

func _pointer() -> Vector2:
	return scene.get_viewport().get_mouse_position() if reach.pointer_override == null else reach.pointer_override

# --- Presses ----------------------------------------------------------------------

## A left press the hand reach has let through (nothing held, the hand free).
## True when it was the case's or the material's.
func press(point: Vector2) -> bool:
	if card != null and card.press(point): return true
	if foot != null and foot.press(point): return true
	# The almanac: its pockets act at once, the Wind's press holds for a drag.
	if almanac != null and almanac.press(point):
		if almanac.holding(): reach.take_hold("almanac",point)
		return true
	# The tool roll: the pips size what is in hand; the Hand puts a material down.
	var pip: int = roll.pip_at(point)
	if pip >= 0:
		set_size(pip)
		return true
	var mode: String = roll.mode_at(point)
	if not mode.is_empty():
		set_mode(mode)
		return true
	var swatch: int = roll.swatch_at(point)
	if swatch >= 0:
		if swatch < roll.swatches.size(): set_colour(roll.swatches[swatch])
		else: roll.open_picker(func(picked: Color) -> void: set_colour(picked,true))
		return true
	var tool: String = roll.tool_at(point)
	if not tool.is_empty():
		if not roll.discovered(tool): roll.not_yet(tool)
		# The tool in hand's own pocket puts it down, unless it puts a material
		# down first.
		elif tool == roll.tool and held.is_empty(): select_tool(FREE)
		else:
			put_back()
			select_tool(tool)
		return true
	if roll.contains_pointer(point): return true
	var specimen: String = tray.specimen_at(point)
	if not specimen.is_empty():
		if not tray.discovered(specimen):
			tray.not_yet(specimen)
			return true
		if specimen == held: put_back()
		else:
			if not held.is_empty(): put_back()
			_take(specimen)
		_press_pos = point
		_left_tray = false
		reach.take_hold("jar",point)
		return true
	if tray.contains_pointer(point):
		put_back()
		return true
	# The Feather in hand: a press on the land is the wind's; the rim and the
	# sky keep their own verbs (a sky swipe still sends a passing gust), and a
	# grown tree is the hand's to bend and flick (hand_reach `_tree_press`): the
	# shaping tools press through trees to the land, so this is where it lives.
	# Shift on a plant, undergrowth too, is the hand's pluck (hand_reach `pluck`).
	if held.is_empty() and roll.tool == FEATHER:
		if reach.reach_at(point) == "rim" or reach._land(point) == null or reach._tree_under(point) > 0: return false
		if reach._press_shift and reach.plant_under(point) > 0: return false
		_feather_press(point)
		return true
	# The can in hand: a press on the land pours there (through trees too).
	if held.is_empty() and roll.tool == CAN:
		if reach.reach_at(point) == "rim" or reach._land(point) == null: return false
		var editor: Node = reach._editor()
		if editor.has_method("can_in_hand") and editor.can_in_hand(point,size_scale(),Input.is_key_pressed(KEY_SHIFT)):
			reach.take_hold(CAN,point)
			reach.uses[CAN] = int(reach.uses.get(CAN,0))+1
		return true
	if held.is_empty(): return false
	# The rim keeps its verbs; the land is the material's; the sky puts it back.
	if reach.reach_at(point) == "rim": return false
	if reach._land(point) != null:
		_use(point)
		return true
	if reach._editor().pointer_in_world(point):
		put_back()
		return true
	return false

## Take the shaping tool `id` in the roll (the bare Hand is "hand"); the
## clay works with it from the next press. FREE puts the tool down.
func select_tool(id: String, quiet := false) -> void:
	var clay: Node = scene.get("land_clay")
	if id == FREE:
		if clay != null: clay.put_tool_down()
	elif clay != null and not clay.set_tool(id): return
	if roll.tool != id and not quiet: ClaySound.cue(&"ui_pick")
	roll.tool = id
	_show_modes(id)

## The roll's fan for the tool `id`: its modes, and the one in hand.
func _show_modes(id: String) -> void:
	var clay: Node = scene.get("land_clay")
	var made: RefCounted = clay.tool_of(id) if clay != null else null
	var ids: Array = made.modes().map(func(spec: Dictionary) -> String: return spec.id) if made != null else []
	roll.set_modes(ids,made.mode if made != null else "")
	_show_swatches()

## The mode of the tool in hand (scripts/clay_tools/clay_tool.gd `modes`), in
## the tool and on the roll's fan.
func set_mode(mode: String) -> void:
	var clay: Node = scene.get("land_clay")
	if clay != null and clay.tool_id == roll.tool: clay.tool.mode = mode
	if roll.mode != mode: ClaySound.cue(&"ui_size")
	roll.mode = mode
	_show_swatches()

## The colour the tool in hand lays (the Brush's Colour), sRGB; `quiet` for
## the full picker, which sends one per step of a drag.
func set_colour(picked: Color, quiet := false) -> void:
	var clay: Node = scene.get("land_clay")
	if clay == null or clay.tool_id != roll.tool: return
	if not quiet and not clay.tool.colour.is_equal_approx(picked): ClaySound.cue(&"ui_size")
	clay.tool.colour = picked
	_show_swatches()

## The roll's swatch strip for the tool in hand: its colours while its mode
## lays one, none otherwise.
func _show_swatches() -> void:
	var clay: Node = scene.get("land_clay")
	var made: RefCounted = clay.tool_of(roll.tool) if clay != null else null
	if made == null:
		roll.set_swatches([],Color.WHITE)
		return
	roll.set_swatches(made.swatches(),made.colour,made.picks())

# --- The Feather ------------------------------------------------------------------

## The Feather's wake half-width (m) at the size in hand.
func feather_half() -> float:
	return FEATHER_HALF*size_scale()

## Wind dragged in from the sky onto the land (scripts/hand_reach.gd
## `_void_drag`): the Feather is in hand from here, pressed in the roll. One
## thing in hand: a material goes back first.
func take_feather() -> void:
	put_back()
	if roll.tool != FEATHER: select_tool(FEATHER)

## A press on the land with the Feather: the wind tool is taken there, no
## flick carried, as wide as the Feather's wake, and the press is held here
## until the button comes up. Nothing happens if the land is busy.
func _feather_press(point: Vector2) -> void:
	var editor: Node = reach._editor()
	if not editor.has_method("gust_in_hand") or not editor.gust_in_hand(point,Vector2.ZERO,0.0,feather_half()): return
	feather_seconds = 0.0
	reach.take_hold(FEATHER,point)

## The wind tool's gust, or null.
func _gust() -> Node:
	var editor: Node = reach._editor()
	return editor.get("gust") if editor != null else null

## True while the can pours (its press is held).
func can_pouring() -> bool:
	var can: Node = reach._editor().get("can")
	return roll != null and roll.tool == CAN and held.is_empty() and can != null and can.pouring

## True while the Feather's wind is in hand (its own press, or wind dragged
## in from the sky), for the marks.
func feather_blowing() -> bool:
	var gust := _gust()
	return roll != null and roll.tool == FEATHER and held.is_empty() and gust != null and gust.aiming()

## The burst ring's radius (m) while the Feather is held still, or 0 before
## FEATHER_BURST_SECONDS: the wake's half-width, growing to FEATHER_RING of it.
func feather_ring() -> float:
	if reach.holding != FEATHER or feather_seconds < FEATHER_BURST_SECONDS: return 0.0
	var gust := _gust()
	var gather: float = float(gust.BURST_GATHER) if gust != null else 1.2
	return feather_half()*lerpf(1.0,FEATHER_RING,smoothstep(FEATHER_BURST_SECONDS,gather,feather_seconds))

## The Feather's press comes up: a drag's wake is let go and dies away; a
## still press is a burst only once held long enough.
func _feather_let_go() -> void:
	var gust := _gust()
	if gust == null or not gust.aiming(): return
	var plan: Dictionary = gust.promise()
	if plan.get("kind","") == "burst" and feather_seconds < FEATHER_BURST_SECONDS:
		gust.cancel()
		feather_last = ""
		feather_sent.none += 1
		return
	var sent: Dictionary = gust.release()
	feather_last = str(sent.get("kind",""))
	if feather_sent.has(feather_last): feather_sent[feather_last] += 1
	reach.uses["feather"] = int(reach.uses.get("feather",0))+1

## Take `id` in hand from outside the case (the command palette): a seed,
## water or something to set down, whether or not it has a slot. False when
## it is not a material the hand knows.
func take(id: String) -> bool:
	if not (sows(id) or paints(id) or SCATTER.has(id) or id == "water"): return false
	if held == id: return true
	if not held.is_empty(): put_back()
	_take(id)
	return true

func _take(id: String) -> void:
	# One thing in hand: a material puts the tool back.
	if roll.tool != "hand": select_tool("hand",true)
	held = id
	tray.lift_out(id)
	ClaySound.cue(&"ui_take")
	clump.show_kind(id)

## The specimen goes home to its compartment.
func put_back() -> void:
	if held.is_empty(): return
	var from := _pointer()
	if clump.visible and not scene.camera.is_position_behind(clump.global_position): from = scene.camera.unproject_position(clump.global_position)
	tray.return_home(held,from)
	ClaySound.cue(&"ui_put")
	reach.uses["tray_back"] = int(reach.uses.get("tray_back",0))+1
	held = ""

## A press over the land with material in hand. Seeds and water go to the
## editor, which holds them until the button comes up; what is set down by
## hand is held here.
func _use(point: Vector2) -> void:
	var editor: Node = reach._editor()
	if paints(held):
		# Shift thins, read at the press (or held as it is drawn out of the case).
		var thinning: bool = reach._press_shift or Input.is_key_pressed(KEY_SHIFT)
		if editor.has_method("paint_flowers_begin") and editor.paint_flowers_begin(point,held,size_scale(),thinning):
			reach.take_hold(PAINT,point)
			_press_pos = point
			_travel = 0.0
			_paint_cue = 0.0
			_paint_seen = 0
			ClaySound.cue(&"sow")
			_used()
	elif sows(held):
		var sown: bool = editor.has_method("sow_from_hand") and editor.sow_from_hand(point,SEEDS[held])
		if sown:
			ClaySound.cue(&"sow")
			_used()
	elif held == "water":
		if editor.get("water_ball") != true: return
		editor.ball_supply = Callable()
		# The ball is the ponds' own water: it forms only where there is some.
		var scooped: String = editor.scoop_ball(point) if editor.has_method("scoop_ball") else ("" if editor.ball_from_sky(point) else "busy")
		if scooped.is_empty(): _used()
		elif scooped == "dry":
			clump.shed()
			ClaySound.cue(&"ui_refuse")
			reach._show_hint(DRY_HINT)
	elif SCATTER.has(held):
		reach.take_hold("scatter",point)
		_press_pos = point
		_held_seconds = 0.0
		_travel = 0.0
		_stone_last = null
		_stone_step = null
		_stone_count = 0
		_stone_since = STONE_SECONDS

## True for what the pinch sows as a veil: tree seed. (Flowers were sown so
## until 2026-10-02; they are painted now, `paints`. The veil stays for pollen
## from what already grows.)
static func sows(id: String) -> bool:
	return SEEDS.has(id)

## True for what is painted under a brush: the flower slots.
static func paints(id: String) -> bool:
	return FlowerSowing.has(id)

func _used() -> void:
	reach.uses[held] = int(reach.uses.get(held,0))+1
	reach._show_hint("")

## The pointer moves while the hand holds "jar" or "scatter".
func drag(point: Vector2) -> void:
	if reach.holding == "almanac":
		almanac.drag(point)
		return
	_travel = maxf(_travel,point.distance_to(_press_pos))
	if reach.holding != "jar": return
	if tray.contains_pointer(point): return
	_left_tray = true
	if held.is_empty() or reach._land(point) == null or reach.reach_at(point) == "rim": return
	# Drawn out of the case onto the land: the press is the material's from here.
	reach.drop_hold()
	_use(point)

## The hold of "jar" or "scatter" ends at `point` (Vector2.INF: the window lost it).
func let_go(what: String, point: Vector2) -> void:
	if what == "almanac":
		almanac.let_go(point)
		return
	if what == FEATHER:
		_feather_let_go()
		return
	if what == CAN:
		var can: Node = reach._editor().get("can")
		if can != null: can.release()
		return
	if what == PAINT:
		var editor: Node = reach._editor()
		if editor.has_method("paint_flowers_end"): editor.paint_flowers_end()
		return
	var known := point != Vector2.INF
	var over_land: bool = known and reach._land(point) != null
	var home: bool = known and not over_land and reach.reach_at(point) != "rim"
	if what == "jar":
		# Drawn out and let go in the sky or back on the case.
		if _left_tray and home: put_back()
		return
	if _stone_count == 0 and SCATTER.has(held):
		var spec: Dictionary = SCATTER[held]
		if _travel <= CLICK_PIXELS: _drop(_ground(_press_pos),lerpf(spec.tap.x,spec.tap.y,smoothstep(0.12,float(spec.grow),_held_seconds)))
		elif over_land: _drop(_ground(point),_scatter_size())
		elif home: put_back()
	elif home: put_back()
	_stone_step = null

func _scatter_size() -> float:
	var spec: Dictionary = SCATTER[held]
	return lerpf(spec.scatter.x,spec.scatter.y,smoothstep(0.0,float(spec.scatter_grow),_held_seconds))

## The plate point under a pointer, or null.
func _ground(point: Vector2) -> Variant:
	var hit: Variant = reach._land(point)
	return Vector2(hit.x,hit.z) if hit != null else null

## Sets down one drop of what is held at `at` (plate): a stone, or a drift of
## flowers or reeds round it.
func _drop(at: Variant, size: float) -> bool:
	if at == null or not SCATTER.has(held): return false
	var spec: Dictionary = SCATTER[held]
	var items := []
	for i in range(int(spec.each)):
		var offset := Vector2.ZERO
		if i > 0: offset = Vector2.from_angle(randf()*TAU)*float(spec.spread)*size_scale()*sqrt(randf())
		var assets: Array = spec.assets
		items.append({"asset":assets[randi()%assets.size()],"point":at+offset,"size":size*randf_range(0.88,1.12)*(1.0 if i == 0 else randf_range(0.75,1.0)),"angle":randf()*TAU})
	var step: Variant = reach._editor().set_objects(items,_stone_step)
	if step == null: return false
	_stone_step = step
	_stone_last = at
	_stone_count += 1
	_stone_since = 0.0
	stones_set += 1
	var ground: Vector3 = reach._editor().terrain.to_global(Vector3(at.x,0.0,at.y))
	ClaySound.cue_at(&"stone_drop" if held == "stone" else &"plant",ground,clampf(size,0.3,1.0))
	reach.uses[held] = int(reach.uses.get(held,0))+1
	clump.shed()
	return true

# --- Frames -----------------------------------------------------------------------

## Each frame, after the hand reach has driven the hand.
func step(delta: float) -> void:
	var wanted := _tray_wanted() and not hud_hidden
	for piece in get_tree().get_nodes_in_group(HUD_GROUP): piece.want(wanted)
	# An open page keeps the almanac reached, and knows the strip's column so a
	# click on a pocket does not close it; photo mode closes it.
	if pages != null:
		if hud_hidden and pages.is_open(): pages.close()
		almanac.page_open = pages.is_open()
		pages.strip_rect = almanac.strip_rect()
	if palette != null and hud_hidden and palette.is_open(): palette.close()
	# A drag under way (a rim pull, the clay, a sowing) never wakes the bars.
	var quiet: bool = not str(reach.holding) in ["","jar","almanac"]
	tray.quiet = quiet
	roll.quiet = quiet
	almanac.quiet = quiet
	if card != null:
		card.quiet = quiet or reach.camera_moving()
		# Never mid-stroke: the hand is made ready once it holds nothing.
		var asked: String = card.asking()
		if asked != _asked and str(reach.holding).is_empty():
			_asked = asked
			_take_for(asked)
		# A step that shows the rim has it lit while it is asked.
		var lit: bool = not asked.is_empty() and str(_first_steps.verb(asked).get("show","")) == "rim"
		card.rim = reach.rim_outline() if lit else PackedVector2Array()
	roll.material_held = not held.is_empty()
	roll.held_tint = Icons.item(held if not held.is_empty() else roll.tool).get("tint",roll.held_tint)
	# The Lantern hint line sits just over the case.
	var shell: Node = scene.get("creation_palette")
	if not _shell_lifted and shell != null and "bottom_lift" in shell:
		shell.bottom_lift = HINT_LIFT
		shell.fit()
		_shell_lifted = true
	if reach.holding == "scatter": _scatter(delta)
	if reach.holding == PAINT: _painting(delta)
	if reach.holding == FEATHER: feather_seconds += delta
	_carry(delta)

## The material in hand is its own cursor (`Clump`): over the land while
## nothing else holds the press, not while the camera moves or the wanderer
## looks, and not while the water ball it became is out (the ball is the
## water then). Pressed, it comes down onto the land. Seeds gather in it and
## it flicks them out as it sows (`_sow`).
func _carry(delta: float) -> void:
	var editor: Node = reach._editor()
	if not held.is_empty() and clump.kind != held: clump.show_kind(held)
	var ball: Node = editor.get("ball")
	var pouring: bool = held == "water" and ball != null and str(ball.state) in ["holding","tossed","falling"]
	var sowing: bool = sows(held) and editor.get("_handful_holding") == true
	var pressing: bool = reach.holding in ["scatter",PAINT] or sowing
	var wanderer: Node = scene.get("wanderer")
	var eye: bool = wanderer != null and wanderer.get("active") == true
	var hit: Variant = editor.pointer_hit
	var want: bool = not held.is_empty() and hit != null and not reach.camera_moving() and not eye and not pouring
	# The sowing editor holds the press, so the reach is not free while it does.
	want = want and (pressing or (reach.available() and reach.holding.is_empty() and reach.hover_zone == "land"))
	var growing: bool = reach.holding == "scatter" and _travel <= CLICK_PIXELS and SCATTER.has(held)
	clump.grow = smoothstep(0.12,float(SCATTER[held].grow),_held_seconds) if growing else 0.0
	var size: float = float(scene.distance)/GodHand.CURSOR_DISTANCE if "--hand-cursor" in OS.get_cmdline_user_args() else 1.0
	var rest := CursorMotion.across_view(editor.terrain,scene.camera)
	clump.advance(delta,want,hit,pressing,rest,float(PRESS_GAP.get(held,PRESS_GAP_DEFAULT)),size)
	_sow(delta,sowing)

## Seeds in hand: what the veil lays gathers in the pinch (its `hand_at`) and
## the pinch flicks it out, every FLICK_SECONDS while held and once as the
## button comes up. Under `--hand-everywhere` the God Hand's palm has it.
func _sow(delta: float, sowing: bool) -> void:
	var handful: Node = reach._editor().get("handful")
	if handful == null or not "hand_at" in handful or GodHand.everywhere: return
	var pinching := sows(held) and clump.visible
	handful.hand_at = clump.launch_point() if pinching else null
	if sowing:
		_flick_in -= delta
		if _flick_in <= 0.0:
			_flick_in = FLICK_SECONDS
			_flick(handful)
	else:
		# The button came up: the last of it goes.
		if _sowing: _flick(handful)
		_flick_in = FIRST_FLICK
	_sowing = sowing

func _flick(handful: Node) -> void:
	if not clump.visible: return
	clump.flick()
	flicks += 1
	var motion: CursorMotion = clump.motion
	var along := Vector3(motion.way.x,0.0,motion.way.y)
	var carry := Vector3(motion.tip_velocity.x,0.0,motion.tip_velocity.y)*THROW_CARRY
	handful.toss((carry+along*FLICK_OUT+Vector3.UP*FLICK_UP).limit_length(MAX_THROW))

func _tray_wanted() -> bool:
	var editor: Node = reach._editor()
	if editor == null or editor.forming or scene.camera == null: return false
	if scene.get("_has_world") == false or scene.get("crafting") == true or scene.get("titled") == true: return false
	var menu: Control = scene.get("_menu")
	if menu != null and menu.visible: return false
	for key: String in ["photo","wanderer"]:
		var node: Node = scene.get(key)
		if node != null and node.get("active") == true: return false
	return true

## While flowers are painted: the clump sheds a little and the brush is heard
## as they come up under it (thinning, as they go).
func _painting(delta: float) -> void:
	_paint_cue -= delta
	var stroke: RefCounted = reach._editor().get("flower_paint")
	if stroke == null: return
	var count: int = stroke.placed.size()+stroke.removed.size()
	if count > _paint_seen and _paint_cue <= 0.0:
		_paint_cue = PAINT_CUE
		clump.shed()
		var hit: Variant = reach._editor().pointer_hit
		if hit != null: ClaySound.cue_at(&"plant",reach._editor().terrain.to_global(hit),clampf(float(count-_paint_seen)/40.0,0.3,0.8))
		_paint_seen = count

## A held drag sets more down under the pointer as it goes.
func _scatter(delta: float) -> void:
	_held_seconds += delta
	_stone_since += delta
	if not SCATTER.has(held): return
	if _travel <= CLICK_PIXELS or _stone_count >= int(SCATTER[held].most) or _stone_since < STONE_SECONDS: return
	var editor: Node = reach._editor()
	if int(editor.refresh_pending) > 0 or editor.reactions.active_count() > 0: return
	var at: Variant = _ground(_pointer())
	if at == null: return
	if _stone_last == null or (at as Vector2).distance_to(_stone_last) >= STONE_GAP*size_scale(): _drop(at,_scatter_size())

## The God Hand is for the whole world: material in hand is its own cursor,
## so the hand stands down while it is held over the land and the sky, while
## the case or the almanac holds the press, and over the case. The rim keeps
## its reach. False when the hand reach drives it as usual.
func drive_hand(hand: Node3D) -> bool:
	var holding: String = reach.holding
	if not holding in ["","jar","scatter","almanac",PAINT]: return false
	if holding.is_empty():
		if not reach.available(): return false
		if reach.hover_zone == "rim" or (held.is_empty() and reach.hover_zone != "tray"): return false
		# Only a hand that is free, or one of the hover's own poses.
		if not (hand.reach_gesture.is_empty() or hand.reach_gesture == reach._hover_shown): return true
	reach._set_hand(hand,"",null,null)
	return true

## The hint with material in hand: its verb over the land, the way home over
## the sky. [zone, text], or ["", ""].
func hint(zone: String) -> Array:
	if held.is_empty(): return ["",""]
	if zone == "land": return [held,FLOWER_HINT if FlowerSowing.has(held) else SOW_HINT if SEEDS.has(held) else str(HINTS.get(held,""))]
	if zone in ["void","cloud"]: return ["tray_back",BACK_HINT]
	return ["",""]

## The material in hand as the cursor: a small faceted stand-in of it, built
## in code as the tools' props are (scripts/clay_tools/clay_tool.gd `part`), its
## underside pinned to the pointer's ground point and moving as a tool's prop
## does (scripts/cursor_motion.gd): a pinch of seeds tinted by kind (acorns,
## winged pine and birch seed, willow down, flower seed with a petal or two,
## a dandelion's puff, slim reed seed), a bead of water, a few pebbles. It
## grows in over the land and shrinks away off it, comes down onto the land
## on a press, swells as a still press grows a stone, sheds a little as a
## drop is set down, and flicks (a quick snap forward and a swell) as it
## throws seed.
class Clump extends Node3D:
	const ClayTool = preload("res://scripts/clay_tools/clay_tool.gd")
	const Motion = preload("res://scripts/cursor_motion.gd")
	const Icons = preload("res://scripts/hud_icons.gd")
	## Seed tones by specimen (sRGB): acorn browns, pine-seed umber, willow
	## down, birch straw, flower seed with a petal or two, dandelion clock,
	## reed brown.
	const TONES := {
		"oak":["a57b48","8c6a3f","c09a66"],"pine":["7a5a3a","946f48","6a4c30"],"willow":["dcd8c4","c9c6ae","ece8d6"],
		"birch":["c9ab7a","b89868","dcc190"],"redwood":["8a4a32","a15a3c","6e3a26"],"juniper":["5f6f8a","74849c","4c5a72"],"joshua":["9a8a5a","b2a06a","7e7048"],"wildflower":["c9a86a","f2c53d","e38aa0"],"dandelion":["efe9d6","d8cfb4","b89a5e"],"reed":["8a6a45","7a5c3a","a07e56"],
		"poppy":["3a2e2a","e0442f","f07a3a"],"cosmos":["4a3a30","e8609f","fcefe2"],"sunflower":["3e3226","f4b61e","d8cdb8"],
	}
	## The flick: FLICK_SNAP s, tipping FLICK_TURN degrees forward and
	## swelling by FLICK_SWELL at its height, then back.
	const FLICK_SNAP := 0.28
	const FLICK_TURN := 38.0
	const FLICK_SWELL := 0.25
	var kind := ""
	var grow := 0.0
	var motion := Motion.new()
	## The land's height at a plate x, z (a Vector2), or null.
	var ground := Callable()
	var _body: Node3D
	var _height := 0.0
	var _shed := 0.0
	var _flick := 0.0
	var _time := 0.0
	var _parts: Array[MeshInstance3D] = []
	var _rest: Array[Vector3] = []

	func _init() -> void:
		visible = false
		_body = Node3D.new()
		add_child(_body)

	func show_kind(next: String) -> void:
		if next != kind: _build(next)
		kind = next

	func shed() -> void:
		_shed = 1.0

	func flick() -> void:
		_flick = 1.0

	## True while it is flicking.
	func flicking() -> bool:
		return _flick > 0.0

	## Where thrown seed leaves it (plate): the middle of the pinch.
	func launch_point() -> Vector3:
		return position+basis*Vector3(0.0,_height*0.5,0.0)

	## One frame: toward `goal` (the pointer's ground point, plate) while
	## `want`, pressed onto the land to `press_gap` while `pressing`, facing
	## `rest_way` before it has moved, `size` times its own size.
	func advance(delta: float, want: bool, goal: Variant, pressing: bool, rest_way: Vector2, press_gap: float, size: float) -> void:
		delta = minf(delta,0.05)
		_time += delta
		visible = motion.show(want and goal != null,delta)
		if not visible: return
		motion.advance(delta,goal if goal != null else motion.tip,pressing,ground,rest_way,-INF,press_gap)
		_shed = move_toward(_shed,0.0,delta*3.0)
		_flick = move_toward(_flick,0.0,delta/FLICK_SNAP)
		# Out fast, back slower: a snap.
		var u := 1.0-_flick
		var snap := sin(PI*sqrt(u))*(1.0-u) if _flick > 0.0 else 0.0
		var s := size*motion.size()*(1.0+0.45*grow)*(1.0-0.35*_shed*_shed)*(1.0+FLICK_SWELL*snap)
		transform = Transform3D(motion.turn(-FLICK_TURN*snap).scaled(Vector3.ONE*maxf(s,0.001)),motion.tip)
		# A small living stir in the pinch, never quite still.
		for i in range(_parts.size()):
			_parts[i].position = _rest[i]+Vector3(0.0,sin(_time*2.3+i*1.7)*0.006,0.0)

	func _build(next: String) -> void:
		for part in _parts: part.queue_free()
		_parts.clear()
		_rest.clear()
		match next:
			"oak":
				# Three acorns, capped, leaning out from the pinch.
				for i in range(3):
					var out := Vector3.RIGHT.rotated(Vector3.UP,TAU*i/3.0)
					var lean := Vector3(out.z,0.0,-out.x)*0.35
					var at := out*0.07+Vector3.UP*0.09
					_part(_egg(),TONES.oak[i],at,Vector3(0.065,0.085,0.065),lean)
					_part(_egg(),"6b4a2c",at+Vector3.UP*0.06+out*0.02,Vector3(0.075,0.035,0.075),lean)
			"pine", "birch", "redwood", "juniper", "joshua":
				# Winged seeds in a fan: pine's long wings (redwood's, juniper's
				# and Joshua's too), birch's round ones.
				var pine := next != "birch"
				var tones: Array = TONES[next]
				for i in range(5):
					var angle := TAU*i/5.0+0.3
					var out := Vector3(cos(angle),0.0,sin(angle))
					var at := out*0.05+Vector3.UP*(0.05+(i%2)*0.03)
					_part(_egg(),tones[i%3],at,Vector3(0.03,0.025,0.045) if pine else Vector3(0.025,0.02,0.03),Vector3(0.0,-angle,0.0))
					var wing := Vector3(0.028,0.006,0.07) if pine else Vector3(0.055,0.005,0.04)
					_part(_egg(),"d8bf8f" if pine else "e2cfa4",at+out*(0.06 if pine else 0.03)+Vector3.UP*0.02,wing,Vector3(0.25,-angle+(0.0 if pine else PI*0.5),0.0))
			"willow", "dandelion":
				# Down: soft pale balls, a few dark seeds caught under them.
				var tones: Array = TONES[next]
				for i in range(6):
					var angle := TAU*i/6.0
					_part(_egg(),tones[i%2],Vector3(cos(angle)*0.07,0.08+(i%3)*0.03,sin(angle)*0.07),Vector3.ONE*(0.055+0.01*(i%3)),Vector3(i,angle,0.0))
				_part(_egg(),tones[0],Vector3(0.0,0.14,0.0),Vector3.ONE*0.07)
				for i in range(3):
					var angle := TAU*i/3.0+0.5
					_part(_egg(),"8a6a45" if next == "willow" else tones[2],Vector3(cos(angle)*0.04,0.03,sin(angle)*0.04),Vector3(0.018,0.03,0.018),Vector3(0.4,angle,0.0))
			"wildflower", "reed", "poppy", "cosmos", "sunflower":
				# Seed heaped in the pinch; flower seed with a petal or two
				# (poppy's fine dark seed, cosmos's slim seed, sunflower's
				# striped seed under a gold petal).
				var tones: Array = TONES[next]
				var reed := next == "reed"
				for i in range(7):
					var angle := TAU*i/7.0
					var shape := Vector3(0.018,0.018,0.07) if reed else Vector3(0.035,0.03,0.05)
					_part(_egg(),tones[i%2] if reed else tones[0],Vector3(cos(angle)*0.07,0.03+(i%2)*0.04,sin(angle)*0.07),shape,Vector3(0.3*i,angle,0.2))
				if reed: _part(_egg(),tones[2],Vector3(0.0,0.1,0.0),Vector3(0.02,0.02,0.08),Vector3(0.9,0.4,0.0))
				else:
					_part(_egg(),tones[1],Vector3(0.03,0.11,0.02),Vector3(0.06,0.012,0.035),Vector3(0.3,0.6,0.0))
					_part(_egg(),tones[2],Vector3(-0.04,0.1,-0.02),Vector3(0.055,0.012,0.032),Vector3(-0.25,2.2,0.0))
			"water":
				# A bead: a faceted drop coming to a point, a glint on it and
				# a droplet beside it.
				_part(_egg(),"8ecaf0",Vector3(0.0,0.12,0.0),Vector3(0.12,0.11,0.12),Vector3.ZERO,true)
				_part(_cone(),"8ecaf0",Vector3(0.0,0.26,0.0),Vector3(0.085,0.12,0.085),Vector3.ZERO,true)
				_part(_egg(),"f4fbff",Vector3(-0.05,0.18,0.08),Vector3.ONE*0.025,Vector3.ZERO,true)
				_part(_egg(),"a9d8f4",Vector3(0.14,0.035,0.05),Vector3.ONE*0.035,Vector3.ZERO,true)
			"stone":
				# A few pebbles, heaped.
				_part(_egg(),"a89d91",Vector3(0.0,0.08,0.0),Vector3(0.14,0.09,0.12),Vector3(0.2,0.4,0.1))
				_part(_egg(),"c6bbae",Vector3(0.07,0.15,0.03),Vector3(0.09,0.065,0.085),Vector3(-0.3,1.2,0.2))
				_part(_egg(),"b7ab9f",Vector3(-0.12,0.05,0.06),Vector3(0.06,0.05,0.055),Vector3(0.5,2.0,-0.2))
			_:
				var tint: Variant = Icons.item(next).get("tint")
				_part(_egg(),(tint as Color).to_html(false) if tint is Color else "c6bbae",Vector3(0.0,0.1,0.0),Vector3.ONE*0.1)
		# Pinned by its underside: the lowest point sits on its origin.
		var low := INF
		var high := -INF
		for part in _parts:
			var box: AABB = part.transform*part.get_aabb()
			low = minf(low,box.position.y)
			high = maxf(high,box.end.y)
		_body.position.y = -low if low < INF else 0.0
		_height = high-low if low < INF else 0.0

	func _part(mesh: Mesh, colour: String, at: Vector3, size: Vector3, turn := Vector3.ZERO, wet := false) -> void:
		var node := ClayTool.part(mesh,Color(colour),at,size,turn)
		if wet:
			# Water: smooth and glinting, where the rest is matte.
			var material := node.material_override as StandardMaterial3D
			material.roughness = 0.08
			material.metallic_specular = 0.9
			material.rim_enabled = true
			material.rim = 0.6
		_body.add_child(node)
		_parts.append(node)
		_rest.append(at)

	## Faceted, like the land's stones and the tools' props.
	static func _egg() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 7
		mesh.rings = 4
		return mesh

	## A unit cone, point up, for the bead's tip.
	static func _cone() -> Mesh:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 7
		mesh.rings = 1
		return mesh
