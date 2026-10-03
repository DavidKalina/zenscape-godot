extends Node
## First steps (docs/scenic/first-steps.md): what the player has found the hand
## can do, and the few things a new player is walked through. Nothing here
## draws, blocks a press or recognises a gesture of its own: the world's own
## pieces say when a verb was really done (`mark`), the way the almanac's
## whispers retire (scripts/almanac.gd `retire`).
##
## - **Verbs** (VERBS): everything the hand can do, by where it is done. A
##   verb is found the first time it is done, for good, across worlds
##   (SETTINGS). The field notes (scripts/field_notes.gd) list them: a found
##   verb reads in full, one not found yet shows only its clue.
## - **Steps** (STEPS): the verbs a new player is led through, in order, one
##   at a time, on the card (scripts/first_steps_card.gd). The step showing is
##   the first one not found yet, so a player who does a later one early never
##   sees it asked. After the last, or a skip, the card is gone for good;
##   `restart` (the field notes' "Walk me through it again") brings it back.
##
## `--no-first-steps` leaves the card out; `--first-steps` shows it from the
## top whatever was found before, without saving (for probes and films).

## The step on the card changed; "" when there is none (done, or skipped).
signal step_changed(id: String)
## A verb was done for the first time.
signal verb_found(id: String)
## The last step was done (not sent on a skip).
signal finished

## Where found verbs and the skip are kept: [found] id = true, [card] skipped.
const SETTINGS := "user://first_steps.cfg"
## The verbs the card walks through, in order.
const STEPS := ["look","raise","groove","water","tree","turn"]
## Where verbs are done, in the field notes' order, with each heading.
const GROUPS := [["eye","The eye"],["land","The land"],["trees","Trees"],["edge","The edge"],["sky","The sky"],["case","The case and the roll"],["air","The air"]]
## Every verb: its group, its name, how it is done (`line`, in the hint
## line's form, " · " between parts), and the `clue` shown until it is found.
## `near` is the cloth to wake while the card asks for it: "roll:<tool>",
## "tray:<material>", "almanac:<pocket>", "foot:<slot>", or "" for the world.
## `take` (steps only) is what the card's step puts in hand as it is asked
## (scripts/hand_materials.gd `_take_for`): "<tool>" or "<tool>:<mode>" from
## the roll, or "free" for the tool put down; without it the hand is left be.
## `show` (steps only) is a part of the world lit while the step is asked:
## "rim", the plate's top edge (scripts/first_steps_card.gd `rim`).
const VERBS := {
	"look":{"group":"eye","name":"Look round","line":"Right-drag to look round · scroll to come closer","clue":"The other button is the eye","near":""},
	"glide":{"group":"eye","name":"Go and see","line":"Point at something and press F to glide to it · Backspace goes back","clue":"Something worth a closer look","near":""},
	"photo":{"group":"eye","name":"Take a photo","line":"Press P and the cloth steps out of the shot · Space keeps it","clue":"A way to keep what you made","near":"foot:photo"},
	"raise":{"group":"land","name":"Raise a peak","line":"The Mountain is in your hand · press the land and pull up","clue":"The land is clay","near":"roll:mountain","take":"mountain"},
	"hollow":{"group":"land","name":"Sink a hollow","line":"With the Crater, press the land and pull down","clue":"What goes up","near":"roll:crater"},
	"groove":{"group":"land","name":"Thumb a groove","line":"The thumb is in your hand · drag slowly across the land · water will run along it","clue":"A slow thumb","near":"roll:hand","take":"hand:groove"},
	"smooth":{"group":"land","name":"Smooth it over","line":"With the thumb, rub fast, back and forth","clue":"A quick rub","near":"roll:hand"},
	"level":{"group":"land","name":"Level a pan","line":"With the palm, drag and it levels a flat a pond can fill","clue":"The flat of the hand","near":"roll:hand"},
	"spillway":{"group":"land","name":"Cut a spillway","line":"Thumb a groove out through the edge · water pours off into the void","clue":"A groove that does not stop","near":"roll:hand"},
	"tool":{"group":"land","name":"Take up a tool","line":"Press a pocket on the roll · Esc puts it down","clue":"The roll on the left","near":"roll:mountain"},
	"undo":{"group":"land","name":"Take it back","line":"Cmd Z takes back any shaping","clue":"Nothing is final","near":"foot:undo"},
	"tree":{"group":"trees","name":"Bend a tree","line":"The tool is put down, your hand is free · press a tree, bend it right over and let go","clue":"A tree gives to a free hand","near":"","take":"free"},
	"pluck":{"group":"trees","name":"Pluck a plant","line":"Shift-press a tree, a shrub or a flower","clue":"Not everything has to stay","near":""},
	"turn":{"group":"edge","name":"Turn the world","line":"The rim is the plate's lit edge · push it sideways · spin it fast and time winds on","clue":"The plate has an edge","near":"","take":"hand","show":"rim"},
	"shake":{"group":"edge","name":"Shake the weather loose","line":"Take the rim and shake it","clue":"A snow globe","near":"almanac:weather"},
	"spring":{"group":"edge","name":"Spring the land","line":"Pull the rim down and let go · what you made springs up bigger","clue":"The block gives under a pull","near":""},
	"basin":{"group":"edge","name":"Sink a basin","line":"Pull the rim up and let go slowly","clue":"Lift it gently","near":""},
	"flip":{"group":"edge","name":"Flip to a new world","line":"Pull the rim up and flick it hard","clue":"The other side","near":""},
	"gust":{"group":"sky","name":"Send a gust","line":"Swipe across the empty sky","clue":"The air can be pushed","near":""},
	"water":{"group":"case","name":"Pour water","line":"The watering can is in your hand · hold it over the land to pour","clue":"A can on the strip along the top","near":"roll:can","take":"can"},
	"scoop":{"group":"case","name":"Carry water","line":"Take the drop from the case and scoop where water lies · carry it and let go","clue":"The case along the bottom","near":"tray:water"},
	"sow":{"group":"case","name":"Sow seeds","line":"Take a seed or a flower from the case and drag it over the land","clue":"A pinch of something","near":"tray:oak"},
	"stone":{"group":"case","name":"Set a stone","line":"Take the stone from the case and tap the land · hold longer for a bigger one","clue":"Beside the water","near":"tray:stone"},
	"night":{"group":"air","name":"Bring the night","line":"Click the sun on the almanac · Shift-click steps the golden hours","clue":"The strip on the right","near":"almanac:time"},
	"mood":{"group":"air","name":"Change the mood","line":"Press M, or the first pocket of the almanac","clue":"The same land, another light","near":"almanac:mood"},
}

const FlowerSowing = preload("res://scripts/flower_sowing.gd")
## What the case holds that counts as sowing when used: every flower slot
## (scripts/flower_sowing.gd SLOTS), the tree seeds (painted as trees since
## 2026-10-02, scripts/hand_materials.gd SEEDS) and reed. Loaded, not
## preloaded: the hand's materials preload the card, which preloads this.
static func sown() -> Array:
	return FlowerSowing.SLOTS.keys()+load("res://scripts/hand_materials.gd").SEEDS.keys()+["reed"]

## Verbs found so far, id -> true.
var found := {}
## The card was dismissed before its last step.
var skipped := false
## Where `found` and `skipped` are kept; probes point it elsewhere. "" keeps
## them for the session only.
var settings_path := SETTINGS

## Metres a pinch must have lifted or sunk the land to be a raise or a hollow;
## seconds a thumb stroke must have dug (its rub share at most DIG_RUB) or
## rubbed (at least RUBBING) to be a groove or a smoothing; radians the rim
## must have turned the world; the dip (scripts/land_spring.gd MIN_PULL) and
## the lift (scripts/edge_spring.gd BASIN_MIN) that spring the land or sink a
## basin.
const LIFTED := 0.5
const DIG_SECONDS := 0.2
const DIG_RUB := 0.3
const RUB_SECONDS := 0.3
const RUBBING := 0.6
const TURNED := 0.4
const SPRUNG := 0.12
const BASIN := 0.08

var _scene: Node
var _reach: Node
## Counters as last read (`_grew`), and what the stroke in hand has done.
var _seen := {}
var _dug := 0.0
var _rubbed := 0.0
## The yaw last read and how far the rim has turned it this push.
var _yaw := 0.0
var _turned := 0.0
## The mood and the pinned time last read, and the world they were read in.
var _air := []
var _world := ""
## Water from the case is out, waiting to settle.
var _water_out := false

## Wires it to the world: the scene (studies/cozy_worlds.gd) and the hand's
## reach (scripts/hand_reach.gd). Reads what was found before, then listens
## for each verb being done.
func setup(scene: Node, reach: Node) -> void:
	_load()
	_listen(scene,reach)

## Connects every verb to the piece that knows it was done: signals where the
## piece sends one, counters polled each frame (`_poll`) where it only counts,
## the way the almanac notices its whispers (scripts/almanac.gd
## `_watch_gestures`). Anything missing (no reach, `--no-tray`, `--no-hand`) is
## left unheard, so its verbs are never marked and nothing else minds. Safe to
## call again: a signal is connected once, and the counters are read afresh.
func _listen(scene: Node, reach: Node) -> void:
	_scene = scene
	_reach = reach
	_seen.clear()
	_air = []
	_world = ""
	_water_out = false
	var clay: Variant = _prop(scene,"land_clay")
	_hook(clay,"worked",_on_worked)
	_hook(_prop(scene,"snow_globe"),"shake_started",_on_shake)
	var flip: Variant = _prop(scene,"flip")
	_hook(flip,"dipped",_on_dipped)
	_hook(flip,"set_down",_on_set_down)
	_hook(flip,"landed",_on_landed)
	_hook(_prop(scene,"photo"),"saved",_on_saved)
	_hook(_prop(scene,"_chunk_editor"),"ball_settled",_on_ball_settled)
	_poll(0.0)

## Connects `signal_name` of `source` to `handler`, once, if it has it.
func _hook(source: Variant, signal_name: String, handler: Callable) -> void:
	if not (source is Object and is_instance_valid(source) and source.has_signal(signal_name)): return
	if not source.is_connected(signal_name,handler): source.connect(signal_name,handler)

## `property` of `source`, or null when there is no such object or property.
func _prop(source: Variant, property: String) -> Variant:
	if source is Object and is_instance_valid(source): return source.get(property)
	return null

## `property` of `source` as a number, 0 when there is none.
func _num(source: Variant, property: String) -> float:
	var value: Variant = _prop(source,property)
	return float(value) if value is int or value is float else 0.0

func _process(delta: float) -> void:
	if _scene != null and is_instance_valid(_scene): _poll(delta)

## True when `value` is more than it was when last asked (the first ask only
## takes the reading), so what was counted before the listening is not news.
func _grew(key: String, value: float) -> bool:
	var before: float = _seen.get(key,value)
	_seen[key] = value
	return value > before

## The counters and states that have no signal, once a frame.
func _poll(delta: float) -> void:
	var reach: Variant = _reach if _reach != null and is_instance_valid(_reach) else null
	var clay: Variant = _prop(_scene,"land_clay")
	if reach != null:
		if _grew("spores",_num(reach,"tree_spores")): mark("tree")
		if _grew("plucked",_num(reach,"plucked")): mark("pluck")
		if _grew("snaps",_num(reach,"snaps")): mark("night")
		var wind: Variant = _prop(reach,"wind")
		if _grew("gusts",_num(wind,"gusts")): mark("gust")
		var uses: Variant = reach.get("uses")
		if uses is Dictionary:
			if _grew("water",float(uses.get("water",0))): _water_out = true
			if _grew("stone",float(uses.get("stone",0))): mark("stone")
			# Flowers are painted (scripts/flower_paint.gd), reeds set down:
			# each counts a use of what was in hand.
			for id: String in sown():
				if _grew(id,float(uses.get(id,0))): mark("sow")
		var materials: Variant = _prop(reach,"materials")
		if materials != null:
			if _grew("flicks",_num(materials,"flicks")): mark("sow")
			var roll: Variant = _prop(materials,"roll")
			var tool := str(_prop(roll,"tool"))
			if roll != null and not tool in ["hand",""]: mark("tool")
		_poll_turn(reach)
	if clay != null:
		if _grew("notches",_num(clay,"notches")): mark("spillway")
		if str(_prop(clay,"verb")) == "thumb":
			var rub := _num(clay,"last_rub")
			if rub <= DIG_RUB: _dug += delta
			elif rub >= RUBBING: _rubbed += delta
	var editor: Variant = _prop(_scene,"_chunk_editor")
	if editor != null and _grew("undos",_num(editor,"undos")): mark("undo")
	# The can has poured: its stream is running and some has left it.
	var can: Variant = _prop(editor,"can")
	if _prop(can,"pouring") == true and _num(can,"poured") > 0.0: mark("water")
	var rig: Variant = _prop(_scene,"camera_rig")
	var used: Variant = _prop(rig,"_used")
	if used is Dictionary:
		if used.get("focus",false): mark("glide")
		if used.get("orbit",false) and used.get("zoom",false): mark("look")
	_poll_air()

## The rim pushed sideways has turned the world: the yaw it has travelled
## while the hand's rim intent is the turn.
func _poll_turn(reach: Variant) -> void:
	var yaw := _num(_scene,"yaw")
	if str(_prop(reach,"rim_intent")) == "turn": _turned += absf(angle_difference(_yaw,yaw))
	else: _turned = 0.0
	_yaw = yaw
	if _turned >= TURNED: mark("turn")

## The mood or the time of day pinned to something new. A world opening or
## coming back from the title restores its own, and is not the hand's doing, so
## those frames only take the reading.
func _poll_air() -> void:
	var look: Variant = _prop(_scene,"mood_look")
	if look == null: return
	var pins: Variant = _prop(look,"pins")
	var key := [str(_prop(look,"mood")),str(pins.get("time","")) if pins is Dictionary else ""]
	var places: Variant = _prop(_scene,"places")
	var session: Variant = _prop(_scene,"world_session")
	var opened := str(_prop(session,"current_id"))
	var settling: bool = _air.is_empty() or opened != _world or bool(_prop(_scene,"titled")) or (places != null and bool(places.get("busy")))
	if session != null and bool(_prop(session,"previewing")): settling = true
	_world = opened
	if not settling:
		if key[0] != _air[0]: mark("mood")
		if key[1] != _air[1]: mark("night")
	_air = key

## A stroke ended: what the Modeller, the Mountain or the Crater did
## (scripts/land_clay.gd `worked`). A pull counts for its lift, up or down;
## the thumb for how long it dug and how long it rubbed.
func _on_worked(verb: String, kept: bool) -> void:
	match verb:
		"pinch","fine_pinch","peak","fine_peak","crater","fine_crater":
			var lift := _num(_prop(_scene,"land_clay"),"lift")
			if kept and lift >= LIFTED: mark("raise")
			elif kept and lift <= -LIFTED: mark("hollow")
		"groove":
			if kept and _dug >= DIG_SECONDS: mark("groove")
			if _rubbed >= RUB_SECONDS: mark("smooth")
		"palm":
			if kept: mark("level")
	_dug = 0.0
	_rubbed = 0.0

## The rim was shaken until the globe took it (scripts/snow_globe.gd).
func _on_shake() -> void:
	mark("shake")

## A pull on the rim was let go and the block came back up: the land springs
## (scripts/diorama_flip.gd `dipped`), unless the pull was too short.
func _on_dipped(amount: float) -> void:
	if amount >= SPRUNG: mark("spring")

## A lifted rim set down slowly sank a basin, if it was lifted far enough
## (scripts/edge_spring.gd BASIN_MIN).
func _on_set_down(progress: float) -> void:
	if progress >= BASIN: mark("basin")

## The block turned over and a new world landed.
func _on_landed(_world_seed: int) -> void:
	mark("flip")

## A photo was kept; a failed one sends an empty path.
func _on_saved(path: String) -> void:
	if not path.is_empty(): mark("photo")

## Water from the case came down and settled (a pool, a spring, a soaking).
func _on_ball_settled(_outcome: Dictionary) -> void:
	if not _water_out: return
	_water_out = false
	mark("scoop")

## The verb's entry (VERBS), or {} for an id that is not one.
func verb(id: String) -> Dictionary:
	return VERBS.get(id,{})

## The step the card shows: the first not found yet, or "" when the card is
## done or was skipped.
func current() -> String:
	if skipped: return ""
	for id: String in STEPS:
		if not found.get(id,false): return id
	return ""

## How many of the card's steps are found.
func steps_found() -> int:
	return STEPS.filter(func(id: String) -> bool: return found.get(id,false)).size()

## The verb was really done. The first time, it is found for good.
func mark(id: String) -> void:
	if not VERBS.has(id) or found.get(id,false): return
	var before := current()
	found[id] = true
	_save()
	verb_found.emit(id)
	var now := current()
	if now == before: return
	step_changed.emit(now)
	if now.is_empty() and not skipped: finished.emit()

## Puts the card away for good, wherever it was.
func skip() -> void:
	if skipped or current().is_empty(): return
	skipped = true
	_save()
	step_changed.emit("")

## Brings the card back from its first step. The field notes keep what was
## found: only the steps are asked for again.
func restart() -> void:
	skipped = false
	for id: String in STEPS: found.erase(id)
	_save()
	step_changed.emit(current())

func _load() -> void:
	if settings_path.is_empty(): return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK: return
	for id: String in VERBS:
		if bool(config.get_value("found",id,false)): found[id] = true
	skipped = bool(config.get_value("card","skipped",false))

func _save() -> void:
	if settings_path.is_empty(): return
	var config := ConfigFile.new()
	for id: String in found: config.set_value("found",id,true)
	config.set_value("card","skipped",skipped)
	config.save(settings_path)
