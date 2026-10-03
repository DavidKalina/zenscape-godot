extends Control
## The almanac (design "ZenScape HUD 5 Air", docs/design/hud-5/README.md
## sections A, D and E, lowpoly.js `ALMANAC`, `CUES`, `vignette()`; notes and
## departures in docs/design/hud-5/ALMANAC.md): a strip of the same linen on
## the right edge, the tool roll's mirror (scripts/tool_roll.gd), for what
## changes the AIR rather than the land. Five stitched pockets, top to bottom:
## the Mood (the look on screen now, as a small faceted vignette), a double
## stitch, then Time, Season, Weather and Wind. It never holds anything; its
## pockets do things.
##
## Each pocket is drawn as the gesture that does the same thing in the world,
## and clicking it does what the gesture does ("gesture twins"):
## - **Time** is a sun, or a crescent moon by night: day and night's home
##   since the void's snap was cut (2026-09-30). Click and it is night or day,
##   in the same frame; Shift-click steps the golden hours (dawn, midday, dusk,
##   night). It is the snap's own cut (scripts/void_snap.gd `snap`), without
##   the hand or its sound; its tag opens Customise's Time row for the other
##   hours. With `--void-snap` it is the void's click again (scripts/hand_reach.gd
##   `fire_snap`), and its whisper names that.
## - **Season** is the plate from above in the season's tint, with a rim arc
##   and a bead. Click for the next season.
## - **Weather** is a snow globe. Click for the next weather.
## - **Wind** is a windsock hanging as low as the wind is weak. Click steps
##   Calm, Light, Brisk, Gale; drag across it and the prevailing wind turns.
## - **Mood** asks for the Moods page (`page_requested`), which another piece
##   opens (scripts/almanac_pages.gd).
## Every click pins through scripts/mood_look.gd, as Customise would (the pin
## model is unchanged: a pinned value wins over the mood's), and a pinned
## pocket shows a small cream knot at its top right, even at rest.
##
## Hovering a pocket shows its name on a strip of cloth to the LEFT, with a
## quiet line of Spectral under it naming the real gesture ("or click the
## sky"), and plays a one-shot cue: the moon swaps in, the plate turns a
## little, the globe jiggles, the sock lifts. Nothing loops. Once the player
## has done the real gesture (a spin that winds the season on, the shake, the
## held sweep in the sky), that pocket's line and cue retire for good
## (`retire`, saved in SETTINGS); the name stays. Time has no gesture twin
## now: its line teaches the Shift-click, and retires at the first one (with
## `--void-snap`, at the sky's snap). Clicking the name opens Customise at
## that row.
##
## Like the roll it only draws and answers hit tests; the hand
## (scripts/hand_materials.gd) hands it the presses and treats it as it treats
## the bars (`tray_under`). It rests receded (REST_OPACITY, tucked REST_TUCK
## to the right) and comes out as the pointer nears the right edge, while a
## page is open, or while a pocket is hovered; a drag in progress never wakes
## it.

signal page_requested(page: String, row: String)

const Linen = preload("res://scripts/hud_linen.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const Mood = preload("res://scripts/mood_look.gd")
const VoidSnap = preload("res://scripts/void_snap.gd")
const WHISPER_FONT = preload("res://assets/fonts/spectral-latin-400.woff2")
## The pockets, top to bottom; the double stitch runs under the first.
const POCKETS := ["mood","time","season","weather","wind"]
## Layout, design pixels: the strip's inset from the right edge, its padding
## (x, y), the gap between pockets and the double stitch's block (lines 40
## wide, 3 apart, as the roll's). At rest it tucks REST_TUCK to the right.
const RIGHT := 24.0
const PAD := Vector2(10.0,12.0)
const GAP := 4.0
const DIVIDER := 17.0
const DIVIDER_LINE := 40.0
const REST_TUCK := 6.0
## Past this x of the 1440 frame the pointer is reaching for it (the roll's
## NEAR, mirrored: 180 design px from the right edge).
const REACH_X := 1260.0
## The side tag: its gap from the strip, padding (left, top, right, bottom),
## and the whisper under the name (Spectral, px, and its ink).
const TAG_GAP := 4.0
const TAG_PAD := Vector4(12.0,6.0,10.0,7.0)
const WHISPER_SIZE := 13.0
const WHISPER_INK := Color("d6cbb2")
const WHISPERS := {"time":"shift-click for the golden hours","season":"or spin the plate by its rim","weather":"or shake the plate","wind":"or press and pull in the sky"}
## Time's line with `--void-snap`, naming the void's click.
const SNAP_WHISPER := "or click the sky"
## The Customise row each pocket's tag opens (the Mood's tag opens the Moods page).
const ROWS := {"time":"time","season":"season","weather":"weather","wind":"wind"}
## The Mood's vignette: size and corner radius (design px), its stitch 2 px
## inside, its edge and drop (AIR_TOKENS vignette stitch and edge).
const VIGNETTE := Vector2(44.0,28.0)
const VIGNETTE_RADIUS := 3.0
const VIGNETTE_STITCH := Color(1.0,0.98,0.941,0.3)
const VIGNETTE_EDGE := Color(0.078,0.055,0.031,0.3)
const VIGNETTE_DROP := Color(0.047,0.035,0.020,0.22)
## Seconds between redraws of the vignette while the look is moving (a mood's
## 1.2 s cross-fade), so it follows without rasterising every frame.
const VIGNETTE_EVERY := 0.1
## Each mood's facet seed (lowpoly.js MOODS, seeds 23-32); "" is the world's own.
const MOOD_SEEDS := {"":23,"alpine_morning":24,"golden_meadow":25,"copper_autumn":26,"rosewater_dusk":27,
	"enchanted_forest":28,"halloween_hollow":29,"first_snow":30,"nordic_night":31,"after_the_rain":32,
	"rose_dusk":33,"meadow_morning":34,"desert_afternoon":35,"autumn_evening":36,"winter_hush":37,"misty_hollow":38,
	"ocean_light":39,"moonlit_stillness":40,"storm_gathering":41}
## Faceted vignette colours (lowpoly.js `vignette`): the moon, the sun, and
## the share a low sun leans from the glow to the light.
const VIGNETTE_MOON := Color("e6eaf2")
const VIGNETTE_SUN := Color("fff3d6")
const LOW_SUN := 0.55
## The sun is low (dawn, golden hour, dusk) under this elevation
## (WorldClock.elevation_for_phase; the daylight ramp tops out at 0.28).
const LOW_ELEVATION := 0.22
## The knot (README E): diameter, inset from the pocket's top right, its
## cream, halo ring, the drop under it and the shade in its lower lip.
const KNOT := 6.0
const KNOT_INSET := 5.0
const KNOT_COLOUR := Color("e3d7bd")
const KNOT_HALO := Color(0.890,0.843,0.741,0.14)
const KNOT_HALO_WIDTH := 3.0
const KNOT_DROP := Color(0.047,0.035,0.020,0.3)
const KNOT_LIP := Color(0.102,0.078,0.055,0.35)
## Cues (lowpoly.js CUES, README Motion). Jiggle: the globe's angles
## (degrees), one every JIGGLE_STEP s, eased out, about a pivot at 50% 80% of
## the icon, over by JIGGLE_END. Turn: the plate turns TURN_ANGLE over
## TURN_EASE s, turns back from TURN_BACK, over by TURN_END. Snap: the other
## body shows for SNAP_HOLD s, a hard cut both ways. Lift: the sock droops
## half, lifts past level (SOCK_LIFTED) at LIFT_UP, droops half again at
## LIFT_DOWN, and is back at LIFT_END, in hard steps.
const JIGGLE := [-9.0,7.0,-4.0,0.0]
const JIGGLE_STEP := 0.09
const JIGGLE_END := 0.38
const JIGGLE_PIVOT := Vector2(0.5,0.8)
const TURN_ANGLE := -24.0
const TURN_EASE := 0.32
const TURN_BACK := 0.56
const TURN_END := 0.9
const SNAP_HOLD := 0.52
const LIFT_UP := 0.08
const LIFT_DOWN := 0.46
const LIFT_END := 0.54
const CUE_END := {"time":SNAP_HOLD,"season":TURN_END,"weather":JIGGLE_END,"wind":LIFT_END}
## The windsock hangs its strength's droop (mood_look.gd WIND_STRENGTHS,
## lowpoly.js WIND_DROOP: 40, 22, 10 and 0 degrees under level); the lift
## droops it half that, then just over level.
const SOCK_LIFTED := -2
## Dragging across the Wind pocket turns the prevailing wind this many
## degrees a design pixel (120 px is half a turn), clockwise seen from above
## for a drag to the right; a press that wanders under CLICK_PIXELS is a click.
const TURN_PER_PIXEL := 1.5
const CLICK_PIXELS := 6.0
## Seconds a pressed pocket's patch takes to fade (README Motion: 150 ms).
const PRESS_TIME := 0.15
## Where retired whispers are kept, [whispers] id = true.
const SETTINGS := "user://almanac.cfg"
## Compass points for the wind's tag, round from +x (east) toward +z (south).
## First steps (scripts/first_steps_card.gd) points at a pocket with `nudge`:
## the ring takes NUDGE_FADE s to come and go and breathes once every
## NUDGE_PERIOD s.
const NUDGE_FADE := 0.5
const NUDGE_PERIOD := 3.0
const COMPASS := ["east","south-east","south","south-west","west","north-west","north","north-east"]

var scene: Node
var reach: Node
var ui_scale := 1.0
var shown := 0.0
var awake := 0.0
var hovered := ""
var quiet := false
var pointer_override: Variant = null
## A page (Moods or Customise, scripts/almanac_pages.gd) is open: the strip
## stays reached for.
var page_open := false
## The design's `whispers` tweak: lines and cues on at all.
var whispers := true
## Pockets whose whisper and cue have retired (the real gesture was done).
var retired := {}
## Where `retired` is kept; probes point it elsewhere. "" keeps it per session.
var settings_path := SETTINGS
## For probes: cues started, by pocket.
var cues_played := {}
var _want_shown := false
var _away := 0.0
## The pocket the first-steps card is pointing at, or "". While one is
## pointed at the strip stays reached for and that pocket is stitched round, slowly.
var nudged := ""
var _nudge_for := ""
var _nudge_a := 0.0
var _nudge_t := 0.0
var _font: FontVariation
var _whisper: FontVariation
var _textures := {}
var _texture_px := 0.0
var _vignette: Texture2D
var _vignette_key := ""
var _vignette_wait := 0.0
var _cloth: Linen.Cloth
var _tag_cloth: Linen.Cloth
var _states := {}
## The pocket whose tag shows, and how far it has come in.
var _tag_for := ""
var _tag_alpha := 0.0
## A press on the Wind pocket: where, the heading it started from, and
## whether it has become a drag.
var _drag := {}
## What the watchers saw last, to notice the real gestures.
var _seen_snaps := 0
var _seen_sweeps := 0
var _spin_quarter := -1

func _ready() -> void:
	name = "Almanac"
	# Every HUD piece is in this group; photo mode rests them all with want(false).
	add_to_group("hud_piece")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_whisper = FontVariation.new()
	_whisper.base_font = WHISPER_FONT
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	_tag_cloth = Linen.Cloth.new()
	add_child(_tag_cloth)
	for id: String in POCKETS: _states[id] = {"hover":0.0,"press":0.0,"cue":-1.0,"played":false}
	modulate.a = 0.0
	visible = false

## Wires it to the world: the scene (its mood_look, clock, sky and air) and
## the hand's reach (the snap, the sky's wind). Reads the retired whispers.
func setup(owner_scene: Node, hand_reach: Node) -> void:
	scene = owner_scene
	reach = hand_reach
	_load_retired()
	if reach != null:
		_seen_snaps = int(reach.get("snaps"))
		var wind: Variant = reach.get("wind")
		if wind != null: _seen_sweeps = int(wind.sweeps)
	var globe: Node = scene.get("snow_globe") if scene != null else null
	if globe != null and globe.has_signal("shake_started"): globe.shake_started.connect(retire.bind("weather"))

## Shows it (resting, or reached for) or puts it away, as the roll's `want`.
func want(on: bool) -> void:
	_want_shown = on

## Points at pocket `id` (one of POCKETS), or at none with "": the strip stays reached for (a
## drag still keeps it quiet) and the pocket is stitched round and lifts a
## little, over and over, until it is cleared.
func nudge(id: String) -> void:
	nudged = id
	if not id.is_empty(): _nudge_for = id

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

# --- Reading the pointer --------------------------------------------------------

## The pocket under a viewport point, or "".
func pocket_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	for i in range(POCKETS.size()):
		if _cell(i).has_point(point): return POCKETS[i]
	return ""

## The pocket whose tag is under a viewport point, or "".
func tag_at(point: Vector2) -> String:
	if shown < 0.5 or _tag_for.is_empty() or _tag_alpha < 0.5: return ""
	return _tag_for if _tag_rect(_tag_for).has_point(point) else ""

func contains_pointer(point: Vector2) -> bool:
	if shown < 0.5: return false
	return _strip().grow(2.0*ui_scale).has_point(point) or not tag_at(point).is_empty()

## The strip, viewport pixels (for the pages, which open to its left).
func strip_rect() -> Rect2:
	return _strip()

## The centre of a pocket, viewport pixels.
func pocket_centre(id: String) -> Vector2:
	return _cell(POCKETS.find(id)).get_center()

func _height() -> float:
	return PAD.y*2.0+Linen.SLOT*POCKETS.size()+GAP*POCKETS.size()+DIVIDER

func _strip() -> Rect2:
	var extent := Vector2(PAD.x*2.0+Linen.SLOT,_height())*ui_scale
	var tuck := REST_TUCK*(1.0-Linen.eased(awake))*ui_scale
	return Rect2(Vector2(roundf(size.x-RIGHT*ui_scale-extent.x+tuck),roundf((size.y-extent.y)*0.5)),extent.round())

func _cell(i: int) -> Rect2:
	var strip := _strip()
	var y := PAD.y+(Linen.SLOT+GAP)*i+(DIVIDER+GAP if i >= 1 else 0.0)
	return Rect2((strip.position+Vector2(PAD.x,y)*ui_scale).round(),Vector2.ONE*roundf(Linen.SLOT*ui_scale))

# --- Presses (from scripts/hand_materials.gd) -------------------------------------

## A left press. True when it was the almanac's; `holding()` is then true
## when the press goes on as a drag (the Wind pocket).
func press(point: Vector2) -> bool:
	if not contains_pointer(point): return false
	var tag := tag_at(point)
	if not tag.is_empty():
		open_tag(tag)
		return true
	var id := pocket_at(point)
	if id == "wind" and scene != null and scene.get("_atmosphere") != null:
		_drag = {"from":point,"angle":float(scene._atmosphere.direction_angle),"moved":false}
		_states.wind.press = 1.0
	elif not id.is_empty(): click(id,_shift())
	return true

## Shift was held at the press: the hand's reach reads it off the button
## (hand_reach `_press_shift`) before it hands the press on.
func _shift() -> bool:
	return (reach != null and reach.get("_press_shift") == true) or Input.is_key_pressed(KEY_SHIFT)

## True while a press on the Wind pocket is held.
func holding() -> bool:
	return not _drag.is_empty()

## The held press moves: across the Wind pocket, the prevailing wind turns
## (the atmosphere's heading, which its air eases toward).
func drag(point: Vector2) -> void:
	if _drag.is_empty(): return
	var dx: float = point.x-_drag.from.x
	if not _drag.moved and point.distance_to(_drag.from) <= CLICK_PIXELS: return
	_drag.moved = true
	_states.wind.press = 1.0
	scene._atmosphere.direction_angle = fposmod(float(_drag.angle)+dx/ui_scale*TURN_PER_PIXEL,360.0)

## Let go: a still press is a click (the next strength); a drag leaves the
## wind turned, pinned with its heading.
func let_go(point: Vector2) -> void:
	if _drag.is_empty(): return
	if point != Vector2.INF: drag(point)
	var moved: bool = _drag.moved
	_drag = {}
	if not moved:
		click("wind")
		return
	var mood := _mood()
	if mood != null: mood.pin("wind",Mood.wind_pin(_wind_id(),float(scene._atmosphere.direction_angle)))

## A pocket clicked: what its gesture does, pinned. `step` (Shift) steps
## Time through the golden hours.
func click(id: String, step := false) -> void:
	if not _states.has(id): return
	_states[id].press = 1.0
	match id:
		"mood": page_requested.emit("moods","")
		"time": _snap(step)
		"season": _step("season",Mood.SEASONS)
		"weather": _step("weather",Mood.WEATHERS)
		"wind": _step_wind()

## The tag clicked: Customise at that pocket's row, and the pocket pressed.
## The Mood's tag opens the Moods page (it has no Customise row).
func open_tag(id: String) -> void:
	if not _states.has(id): return
	_states[id].press = 1.0
	if ROWS.has(id): page_requested.emit("customise",ROWS[id])
	else: page_requested.emit("moods","")

## The snap's cut (scripts/void_snap.gd: the clock wound on, the sky, the
## radiance and the wildlife at once), then the hour it landed on pinned as
## Customise would pin it (Night or Morning; Dawn, Midday, Dusk or Night for
## a step). With `--void-snap` it goes the void's own way, with the hand's
## fingers and the sound (hand_reach `fire_snap`). A step retires the line
## that teaches it.
func _snap(step := false) -> void:
	if scene == null: return
	var phase: float
	if reach != null and reach.get("sky_snap") == true and reach.has_method("fire_snap"):
		reach.fire_snap(step)
		_seen_snaps = int(reach.get("snaps"))
		phase = float(scene._celestial.phase)
	else:
		phase = VoidSnap.snap(scene,step)
		if step: retire("time")
	var mood := _mood()
	var id := VoidSnap.pin_id(phase)
	if mood != null: mood.pin("time",id if not id.is_empty() else "night" if VoidSnap.is_night(phase) else "morning")

## The next option of a choice control, pinned.
func _step(control: String, options: Array) -> void:
	var mood := _mood()
	if mood == null: return
	var ids: Array = options.map(func(entry: Dictionary) -> String: return entry.id)
	var at := ids.find(mood.value(control))
	mood.pin(control,ids[(at+1)%ids.size()])

## The next wind strength, pinned (a wind pin carries the heading too: the
## one the air has now).
func _step_wind() -> void:
	var mood := _mood()
	if mood == null: return
	var ids: Array = Mood.WIND_STRENGTHS.map(func(entry: Dictionary) -> String: return entry.id)
	var next: String = ids[(ids.find(_wind_id())+1)%ids.size()]
	mood.pin("wind",Mood.wind_pin(next,float(scene._atmosphere.direction_angle)))

func _mood() -> Node:
	return scene.get("mood_look") if scene != null else null

# --- Whispers --------------------------------------------------------------------

## The real gesture has been done: the pocket's whisper and cue retire for good.
func retire(id: String) -> void:
	if retired.get(id,false): return
	retired[id] = true
	_states[id].cue = -1.0
	_save_retired()

## The pocket's whisper line, or "" once retired (or with whispers off).
func whisper(id: String) -> String:
	if not whispers or retired.get(id,false): return ""
	if id == "time" and reach != null and reach.get("sky_snap") == true: return SNAP_WHISPER
	return str(WHISPERS.get(id,""))

func _private() -> bool:
	if settings_path.is_empty(): return true
	return scene != null and scene.has_meta("movie_capture") and settings_path == SETTINGS

func _load_retired() -> void:
	if _private(): return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK: return
	for id: String in WHISPERS:
		if bool(config.get_value("whispers",_key(id),false)): retired[id] = true

func _save_retired() -> void:
	if _private(): return
	var config := ConfigFile.new()
	config.load(settings_path)
	for id: String in retired: config.set_value("whispers",_key(id),true)
	config.save(settings_path)

## Where a pocket's retirement is kept: Time's Shift-click line is a new line,
## so a sky snap made before it does not retire it.
func _key(id: String) -> String:
	return "time_golden" if id == "time" and not (reach != null and reach.get("sky_snap") == true) else id

## Notices the real gestures: a snap in the sky (the reach's `snaps`), the
## sky's held sweep (scripts/sky_wind.gd `sweeps`), and a rim spin that has
## wound the world into another season (scripts/spin_time.gd `winding`). The
## shake arrives by signal (scripts/snow_globe.gd `shake_started`).
func _watch_gestures() -> void:
	if reach != null:
		var snaps := int(reach.get("snaps"))
		if snaps > _seen_snaps: retire("time")
		_seen_snaps = snaps
		var wind: Variant = reach.get("wind")
		if wind != null:
			if int(wind.sweeps) > _seen_sweeps: retire("wind")
			_seen_sweeps = int(wind.sweeps)
	var spin: Node = scene.get("spin_time") if scene != null else null
	var clock: Variant = scene.get("world_clock") if scene != null else null
	if spin == null or clock == null: return
	var quarter := clampi(int(fposmod(float(clock.season),1.0)*4.0),0,3)
	if bool(spin.winding):
		if _spin_quarter < 0: _spin_quarter = quarter
		elif quarter != _spin_quarter: retire("season")
	else: _spin_quarter = -1

# --- What the pockets show ----------------------------------------------------------

func _night() -> bool:
	var sky: Variant = scene.get("_celestial") if scene != null else null
	return sky != null and VoidSnap.is_night(float(sky.phase))

func _season() -> String:
	var mood := _mood()
	var season: String = mood.value("season") if mood != null else "summer"
	return season if Icons.SEASON_TINT.has(season) else "summer"

## The wind's WIND_STRENGTHS id now: its pin's, or the air's nearest.
func _wind_id() -> String:
	var mood := _mood()
	if mood == null: return "light"
	return str(Mood.wind_parts(mood.value("wind")).get("id","light"))

## The WIND_STRENGTHS entry of an id.
static func _wind_entry(id: String) -> Dictionary:
	for entry: Dictionary in Mood.WIND_STRENGTHS:
		if entry.id == id: return entry
	return Mood.WIND_STRENGTHS[1]

func pinned(id: String) -> bool:
	var mood := _mood()
	return mood != null and id != "mood" and mood.pinned(id)

## The tag's words (lowpoly.js ALMANAC `tag`).
func tag_text(id: String) -> String:
	var mood := _mood()
	match id:
		"mood": return "Mood · "+(Mood.mood_title(mood.mood) if mood != null else "This world")
		"time":
			if mood == null: return "Time · Day"
			var value: String = mood.value("time")
			if value.is_empty() or value.begins_with(Mood.HELD_HOUR): return "Time · "+("Night" if _night() else "Day")
			return "Time · "+str(Mood.option("time",value).get("title","Day"))
		"season": return "Season · "+_season().capitalize()
		"weather":
			var weather: String = mood.value("weather") if mood != null else "fair"
			return "Weather · "+str(Mood.option("weather",weather).get("title",weather.capitalize()))
		"wind":
			var title := str(_wind_entry(_wind_id()).title)
			var air: Variant = scene.get("_atmosphere") if scene != null else null
			if air == null: return "Wind · "+title
			var from := fposmod(float(air.direction_angle)+180.0,360.0)
			return "Wind · %s, from the %s" % [title,COMPASS[int(roundf(from/45.0))%8]]
	return ""

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport().get_visible_rect().size
	var scale_now := Linen.hud_scale_for(screen)
	if not is_equal_approx(scale_now,ui_scale) or _textures.is_empty():
		ui_scale = scale_now
		var px := Linen.ICON*ui_scale
		if not is_equal_approx(px,_texture_px) or _textures.is_empty():
			_texture_px = px
			var ids := ["sun","moon","globe"]
			for season: String in Icons.SEASON_TINT: ids.append("plate_"+season)
			for deg: int in Icons.SOCK_DROOPS: ids.append(Icons.sock_id(deg))
			Linen.rasterise(_textures,ids,px)
			_vignette_key = ""
	_watch_gestures()
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta/Linen.REACH)
	var reaching := pointer.x >= size.x-(Linen.FRAME-REACH_X)*ui_scale
	var over := awake > 0.0 and (_strip().grow(6.0*ui_scale).has_point(pointer) or not tag_at(pointer).is_empty())
	var near := _want_shown and (holding() or (not quiet and (reaching or page_open or over or not nudged.is_empty())))
	if near:
		_away = 0.0
		awake = move_toward(awake,1.0,delta/Linen.REACH)
	else:
		_away += delta
		if _away >= Linen.HOLD: awake = move_toward(awake,0.0,delta/Linen.RECEDE)
	_nudge_step(delta)
	visible = shown > 0.0
	if not visible: return
	modulate.a = Linen.eased(shown)*lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake))
	var was := hovered
	hovered = pocket_at(pointer) if _want_shown and awake > 0.5 and not quiet else ""
	# The tag holds while the pointer crosses onto it.
	if hovered.is_empty() and not was.is_empty() and awake > 0.5 and _tag_rect(was).grow(4.0*ui_scale).has_point(pointer): hovered = was
	for id: String in POCKETS:
		var state: Dictionary = _states[id]
		state.hover = move_toward(float(state.hover),1.0 if id == hovered else 0.0,delta/Roll.HOVER_TIME)
		state.press = move_toward(float(state.press),0.0,delta/PRESS_TIME)
		if id != hovered: state.played = false
		elif not state.played:
			state.played = true
			if CUE_END.has(id) and not whisper(id).is_empty():
				state.cue = 0.0
				cues_played[id] = int(cues_played.get(id,0))+1
		if float(state.cue) >= 0.0:
			state.cue = float(state.cue)+delta
			if float(state.cue) >= float(CUE_END[id]): state.cue = -1.0
	if not hovered.is_empty(): _tag_for = hovered
	_tag_alpha = move_toward(_tag_alpha,1.0 if not hovered.is_empty() else 0.0,delta/Roll.HOVER_TIME)
	if _tag_alpha <= 0.0: _tag_for = ""
	_update_vignette(delta)
	_cloth.place(_strip(),ui_scale)
	var tag := _tag_rect(_tag_for) if not _tag_for.is_empty() else Rect2()
	_tag_cloth.visible = tag.size.x > 0.0 and _tag_alpha > 0.0
	if _tag_cloth.visible: _tag_cloth.place(tag,ui_scale,2.0,Vector2.ZERO)
	_tag_cloth.modulate.a = Linen.eased(_tag_alpha)*Linen.eased(awake)
	queue_redraw()

## The tag's strip, left of the pocket: the name, and the whisper under it.
func _tag_rect(id: String) -> Rect2:
	if id.is_empty(): return Rect2()
	var cell := _cell(POCKETS.find(id))
	var width := Linen.tag_width(_font,tag_text(id),ui_scale)
	var line := (Linen.TAG_SIZE+4.0)*ui_scale
	var height := line
	var words := whisper(id)
	if not words.is_empty():
		width = maxf(width,_whisper.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,_whisper_size()).x)
		height += (WHISPER_SIZE+4.0)*ui_scale
	var extent := Vector2(width+(TAG_PAD.x+TAG_PAD.z)*ui_scale,height+(TAG_PAD.y+TAG_PAD.w)*ui_scale).round()
	var right := _strip().position.x-TAG_GAP*ui_scale
	return Rect2(Vector2(roundf(right-extent.x),roundf(cell.get_center().y-extent.y*0.5)),extent)

func _whisper_size() -> int:
	return maxi(6,roundi(WHISPER_SIZE*ui_scale))

# --- The vignette -------------------------------------------------------------------

## The look on screen now (sky, horizon glow, grass, the hour), redrawn when
## it changes, at most every VIGNETTE_EVERY s.
func _update_vignette(delta: float) -> void:
	_vignette_wait -= delta
	var look := vignette_look()
	var key := "%s %s %s %s %d %.2f" % [look.sky.to_html(false),look.glow.to_html(false),look.grass.to_html(false),look.time,look.seed,ui_scale]
	if key == _vignette_key or (_vignette != null and _vignette_wait > 0.0): return
	_vignette_key = key
	_vignette_wait = VIGNETTE_EVERY
	var image := Image.new()
	if image.load_svg_from_string(vignette_svg(look),VIGNETTE.x*ui_scale/40.0) == OK: _vignette = ImageTexture.create_from_image(image)

## The resolved look the Mood pocket shows: {sky, glow, grass, time ("night",
## "low" or "day"), seed}. Pinned Sky and Grass colours are in the look.
func vignette_look() -> Dictionary:
	var look := {"sky":Color("7ea3c4"),"glow":Color("e8dcc0"),"grass":Color("6c9a58"),"time":"day","seed":23}
	if scene == null: return look
	var sky: Variant = scene.get("_celestial")
	if sky == null: return look
	var colors: Dictionary = sky.look.colors
	look.sky = colors.get("sky",look.sky)
	look.glow = colors.get("horizon",look.glow)
	look.grass = colors.get("grass",look.grass)
	var elevation := WorldClock.elevation_for_phase(float(sky.phase))
	look.time = "night" if elevation < 0.0 else "low" if elevation < LOW_ELEVATION else "day"
	var mood := _mood()
	look.seed = int(MOOD_SEEDS.get(mood.mood if mood != null else "",23))
	return look

## lowpoly.js `vignette()` as SVG, viewBox 40x25: faceted sky over the card,
## a faceted glow in the horizon band, a faceted slab top of grass with its
## flat darker side, and a sun or moon disc.
static func vignette_svg(look: Dictionary) -> String:
	var seed := int(look.seed)
	var stretch := "scale(%s %s)" % [String.num(40.0/24.0,4),String.num(25.0/24.0,4)]
	var sun: Color = VIGNETTE_MOON if look.time == "night" else Icons._mix(look.glow,Icons.LIGHT,LOW_SUN) if look.time == "low" else VIGNETTE_SUN
	var sun_y := 10.0 if look.time == "low" else 5.5
	var body := '<defs><clipPath id="c"><rect width="40" height="25" rx="2"/></clipPath>'
	body += '<clipPath id="g"><path d="M0 10.5 L40 8.6 L40 16.4 L0 17.6Z"/></clipPath>'
	body += '<clipPath id="l"><path d="M3 18.2 L20 13.4 L37.5 16.8 L21 22.2Z"/></clipPath></defs>'
	body += '<g clip-path="url(#c)">'
	body += '<g transform="%s">%s</g>' % [stretch,_facets(seed,look.sky)]
	body += '<g clip-path="url(#g)"><g transform="%s">%s</g></g>' % [stretch,_facets(seed+40,look.glow)]
	body += '<circle cx="30" cy="%s" r="1.9" fill="#%s"/>' % [String.num(sun_y,1),sun.to_html(false)]
	body += '<g clip-path="url(#l)"><g transform="%s">%s</g></g>' % [stretch,_facets(seed+80,look.grass)]
	body += '<path d="M3 18.2 L21 22.2 L37.5 16.8 L37.5 19.4 L21 25.5 L3 20.8Z" fill="#%s"/>' % Icons._mix(look.grass,Icons.SHADE,0.55).to_html(false)
	body += '</g>'
	return '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="25" viewBox="0 0 40 25">%s</svg>' % body

static func _facets(seed: int, base: Color) -> String:
	var out := ""
	for tri: Dictionary in Icons.facets(seed,base):
		out += '<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="0.2"/>' % [tri.points,tri.fill,tri.fill]
	return out

# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var line := maxf(1.0,roundf(ui_scale))
	for i in range(POCKETS.size()):
		var id: String = POCKETS[i]
		var state: Dictionary = _states[id]
		var cell := _cell(i)
		var press := Linen.eased(state.press)
		var h := maxf(Linen.eased(state.hover)*(1.0-press),0.0)
		if press > 0.0: Linen.pressed_patch(self,cell,ui_scale,Color(Linen.PRESSED,Linen.PRESSED.a*press),Color(Linen.PRESSED_SHADE,Linen.PRESSED_SHADE.a*press))
		if h > 0.0: Linen.pressed_patch(self,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
		var centre := cell.get_center()-Vector2(0.0,Roll.LIFT*ui_scale)
		_contents(id,centre,float(state.cue))
		if id == _nudge_for: _nudge_ring(self,cell,line,Linen.SLOT_RADIUS)
		if pinned(id): _knot(cell)
	# The double stitch under the Mood.
	var first := _cell(0)
	var mid := first.get_center().x
	var top := first.end.y+GAP*ui_scale
	for k in range(2):
		var y := roundf(top+(DIVIDER*0.5-2.0+k*4.0)*ui_scale)+line*0.5
		Linen.dashed(self,PackedVector2Array([Vector2(mid-DIVIDER_LINE*0.5*ui_scale,y),Vector2(mid+DIVIDER_LINE*0.5*ui_scale,y)]),Linen.DIVIDER,line,3.0*ui_scale,3.0*ui_scale)
	# The hovered pocket's tag, on its strip of cloth to the left.
	if _tag_for.is_empty() or _tag_alpha <= 0.0: return
	var tag := _tag_rect(_tag_for)
	var alpha := Linen.eased(_tag_alpha)*Linen.eased(awake)
	var text := tag_text(_tag_for)
	var width := Linen.tag_width(_font,text,ui_scale)
	var rule := tag.position.y+(TAG_PAD.y+Linen.TAG_SIZE+2.0)*ui_scale
	Linen.tag(self,_font,text,tag.position.x+TAG_PAD.x*ui_scale+width*0.5,rule,ui_scale,alpha)
	var words := whisper(_tag_for)
	if not words.is_empty():
		draw_string(_whisper,Vector2(tag.position.x+TAG_PAD.x*ui_scale,tag.end.y-(TAG_PAD.w+3.0)*ui_scale),words,HORIZONTAL_ALIGNMENT_LEFT,-1,_whisper_size(),Color(WHISPER_INK,alpha))

## What a pocket holds, drawn as its gesture, with its cue at `cue` s (< 0 none).
func _contents(id: String, centre: Vector2, cue: float) -> void:
	match id:
		"mood": _draw_vignette(centre)
		"time":
			var night := _night()
			if cue >= 0.0 and cue < SNAP_HOLD: night = not night
			_icon("moon" if night else "sun",centre,0.0,Vector2(0.5,0.5))
		"season":
			var angle := 0.0
			if cue >= 0.0:
				angle = TURN_ANGLE*(Linen.eased(cue/TURN_EASE) if cue < TURN_BACK else 1.0-Linen.eased((cue-TURN_BACK)/TURN_EASE))
			_icon("plate_"+_season(),centre,angle,Vector2(0.5,0.5))
		"weather":
			_icon("globe",centre,jiggle_angle(cue),JIGGLE_PIVOT)
		"wind":
			var droop := roundi(float(_wind_entry(_wind_id()).droop))
			if cue >= 0.0: droop = SOCK_LIFTED if cue >= LIFT_UP and cue < LIFT_DOWN else roundi(droop*0.5)
			_icon(Icons.sock_id(droop),centre,0.0,Vector2(0.5,0.5))

## The globe's jiggle angle (degrees) `cue` s into it: each step eased out
## from the last angle over JIGGLE_STEP.
static func jiggle_angle(cue: float) -> float:
	if cue < 0.0: return 0.0
	var k := int(cue/JIGGLE_STEP)
	if k >= JIGGLE.size(): return 0.0
	var from: float = 0.0 if k == 0 else JIGGLE[k-1]
	var u := clampf((cue-k*JIGGLE_STEP)/JIGGLE_STEP,0.0,1.0)
	return lerpf(from,JIGGLE[k],1.0-(1.0-u)*(1.0-u))

## An icon turned `degrees` about `pivot` (a share of its 24-unit box).
func _icon(id: String, centre: Vector2, degrees: float, pivot: Vector2) -> void:
	var px := Linen.ICON*ui_scale
	if is_zero_approx(degrees):
		Linen.icon(self,_textures,id,centre,px,ui_scale,"icon",2.0)
		return
	var at := centre+(pivot-Vector2(0.5,0.5))*px
	draw_set_transform(at,deg_to_rad(degrees),Vector2.ONE)
	Linen.icon(self,_textures,id,centre-at,px,ui_scale,"icon",2.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_vignette(centre: Vector2) -> void:
	if _vignette == null: return
	var extent := (VIGNETTE*ui_scale).round()
	var rect := Rect2((centre-extent*0.5).round(),extent)
	var radius := VIGNETTE_RADIUS*ui_scale
	Linen.fill_round(self,Rect2(rect.position+Vector2(0.0,2.0*ui_scale),rect.size),radius,VIGNETTE_DROP)
	Linen.fill_round(self,rect.grow(ui_scale),radius+ui_scale,VIGNETTE_EDGE)
	draw_texture_rect(_vignette,rect,false)
	Linen.dashed_round(self,rect.grow(-2.0*ui_scale),maxf(radius-2.0*ui_scale,ui_scale),VIGNETTE_STITCH,maxf(1.0,roundf(ui_scale)),ui_scale)

## The knot of a pinned pocket: a cream dot at its top right, with its halo,
## a drop under it and a shaded lower lip.
func knot_centre(cell: Rect2) -> Vector2:
	var r := KNOT*0.5*ui_scale
	return Vector2(cell.end.x-KNOT_INSET*ui_scale-r,cell.position.y+KNOT_INSET*ui_scale+r)

func _knot(cell: Rect2) -> void:
	var r := KNOT*0.5*ui_scale
	var centre := knot_centre(cell)
	draw_circle(centre,r+KNOT_HALO_WIDTH*0.5*ui_scale,KNOT_HALO,false,KNOT_HALO_WIDTH*ui_scale,true)
	draw_circle(centre+Vector2(0.0,ui_scale),r,KNOT_DROP,true,-1.0,true)
	draw_circle(centre,r,KNOT_COLOUR,true,-1.0,true)
	draw_arc(centre,r-0.5*ui_scale,0.15*PI,0.85*PI,10,KNOT_LIP,ui_scale,true)
