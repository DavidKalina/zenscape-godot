extends Node
## The run on the sprawl layer (studies/run_layer.tscn --shape=sprawl;
## docs/design/roguelike/stakes-experiment.md, game-v1-climb-up.md): a climb
## from layer 1 on a seed, each gate leading up, the void the end of it.
##
## - **Through the gate**: a flash of warm light, and he stands at the next
##   layer's start (the region he saw far off and up), higher, his runes
##   still with him. The height carried is the true one (`_rise_through`).
## - **Into the void** (under every isle, the plan's `void_y`): he falls on
##   a moment (FALL_ON), the screen goes dark (FADE), and a quiet card says
##   the height he fell from, the runes lost, how long, the highest yet.
##   Then Space (pad A) climbs again from layer 1 on a new seed, R (pad X)
##   the same climb again. The new climb is laid behind the card while it
##   is read.
## - A fall onto a lower isle (its fall stun) is no end, just a setback;
##   a long one costs hearts (docs/design/roguelike/game-v1-hearts.md).
## - **Hearts**: RunState.HEARTS a run, kept through the gate. A fall, the
##   Olmec, a trap or a hazard takes them through the motor's one damage
##   call (PilotMotor `harm`, its `harmed` signal, heard here). After a hit
##   he flickers, safe from the next for RunState.SAFE s. At none he lies
##   where he fell (DOWN_HOLD), the dark comes (FADE), and the same card
##   names what did it (WORDS.causes).
## - Each layer begins at its start spot (scripts/roguelike/start_spot.gd)
##   with the way on lit (scripts/roguelike/way_lights.gd).
## - I shows the layer's long card (the study's); the corner keeps only the
##   height climbed and the runes (scripts/roguelike/run_overlay.gd). The
##   player reads heights, never a layer count: every word is in WORDS.
##
## The study (studies/run_layer.gd) calls `before_tick` / `after_tick` round
## its own tick, `layer_stood` when a layer stands, `input` first in its
## input. Timed in the study's ticks, so a scripted test steps it as play.
const RunState = preload("res://scripts/roguelike/run_state.gd")
const RunOverlay = preload("res://scripts/roguelike/run_overlay.gd")
const StartSpot = preload("res://scripts/roguelike/start_spot.gd")
const WayLights = preload("res://scripts/roguelike/way_lights.gd")
## The way on lit (lanterns, the hung lights): off, the user found them not
## needed (2026-10-12); `--way-lit` puts them back.
static var WAY_LIT := "--way-lit" in preload("res://scripts/launch_args.gd").user_args()
const Pad = preload("res://scripts/pad.gd")
const LayerShapes = preload("res://scripts/roguelike/layer_shapes.gd")
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
## The underground look lightens as the run climbs (scripts/underground/
## underground.gd `climb_lift`): each layer past the first eases the torch's
## dark this share toward the haze's air, at most CLIMB_LIGHTEN_MOST. Light
## and air only, never the growth. 0 keeps the dark as authored.
const CLIMB_LIGHTEN := 0.2
const CLIMB_LIGHTEN_MOST := 0.6
const Underground = preload("res://scripts/underground/underground.gd")
# [collectibles] the corner's tally of runes and rares (game-v1-collectibles.md).
const CollectTally = preload("res://scripts/roguelike/collect_tally.gd")
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const ItemStrip = preload("res://scripts/roguelike/item_strip.gd")
## [items] Whether --wallrun gave the wall run outright (else Gecko Wraps do).
var _wallrun_flag := false
# [items_move] The movement items' verbs, round the study's tick.
const ItemsMove = preload("res://scripts/roguelike/items_move.gd")
var _items_move: Node3D = null

## Past the void, falling on before the dark comes (s), the dark coming (s).
const FALL_ON := 1.1
const FADE := 1.3
## Out of hearts: seconds he lies there before the dark comes. The flicker
## while safe after a hit: blinks a second, and the share of each shown.
const DOWN_HOLD := 1.0
const FLICKER_HZ := 12.0
const FLICKER_ON := 0.6
## The gate's light coming up (s, while the next layer is laid), held at
## the new start (s) and clearing (s).
const GATE_UP := 0.35
const HOLD := 0.3
const CLEAR := 1.6
## Every word the player reads about the run, in one place: rename here.
## The player sees the height climbed (metres above the run's start, "412
## m"), not a count; the layer count stays inside (the gate, the record),
## its word ("stage") only in the study's dev lines.
const WORDS := {
	"unit": "m",                   # after a height: "1,180 m"
	"readout": "%s",               # the corner: the height
	"rune": "%d rune",             # beside it, if any
	"runes": "%d runes",
	"arrive_first": "THE CLIMB",   # the caption a new climb begins with
	"arrive_first_line": "highest  %s",  # under it, once there is a record
	"arrive": "HIGHER STILL",      # the caption through the gate
	"arrive_sky": "OPEN SKY",      # through the last underground gate
	"arrive_line": "%s",           # under it: the height
	"fell": "FELL FROM %s",        # the card's title (the void)
	"felled": "FELLED AT %s",      # the card's title (out of hearts)
	"cause_void": "into the void",  # the card's first fact: what did it
	"cause": "by %s",
	# The harm's causes (PilotMotor `harm`), as the card names them.
	"causes": {"fall":"the fall","olmec":"the Olmec","ram":"the ram","trap":"a trap",
		"wind":"the wind","stone":"falling stone","enemy":"the city's guardians",
		"walker":"the Second Walker"},
	"lost_none": "nothing carried",
	"lost_one": "1 rune lost",
	"lost": "%d runes lost",
	"highest": "highest: %s",
	"highest_new": "the highest yet",
	"prompt": "SPACE / A   A NEW CLIMB            R / X   THE SAME",
	"waking": "...",
	"stage": "layer %d",           # dev only (the study's card, its log)
	# [collectibles] The rare collectible: no name yet (the user's to give);
	# GlyphPickup's sun glyph stands in for its look.
	"rare": "SUN GLYPH",           # the caption a find comes up with
	"rare_line": "%d of %d here",  # under it: this layer's found of laid
	"rares_none": "no sun glyph",  # the card: the run's rares
	"rares_one": "1 sun glyph",
	"rares": "%d sun glyphs",
	"items_lost": "lost with him: %s",  # [items]
	"most": "richest climb: %d runes, %s",
	"most_new": "the richest climb yet",
}
## Seconds the readout stays up after a count changes, and standing still
## before it comes up; the speed (m/s) under which he is still.
const LOUD_FOR := 3.0
const STILL_AFTER := 0.6
const STILL_SPEED := 0.4

var study: Node3D
var run := RunState.new()
var overlay: CanvasLayer
## "play", "falling" (past the void, the dark coming), "dying" (out of
## hearts, the dark coming), "card" (the fall's
## card up), "gate" (through it, the next layer laid), "arrive" (at a
## start, the veil clearing; he can move).
var state := "play"
## What the next layer to stand is: "first", "gate", "run" (a new climb's
## first, behind the card), "skip" (N: a layer on, as the gate), "" (as it
## was).
var pending := "first"
## The card's sums ({depth, runes, time, deepest, record}).
var last_fall := {}
var _t := 0.0
var _veil := 0.0
var _veil_colour := RunOverlay.DARK
## This layer's start's height (world y); the readout's loud time left,
## the time stood still, the runes it last showed.
var _start_y := 0.0
var _loud := 0.0
var _still := 0.0
var _shown_runes := 0
## Behind the card: the seed drawn for a new climb, the one he goes on to,
## the one last asked for, the ask the standing layer answered and its
## seed as laid; whether he has asked to go on.
var _pre := -1
var _want := -1
var _asked := -1
var _laid_for := -1
var _laid_seed := -1
var _wake := false
## The way up taken (`_note_way_up`): the region the gate leads to as seen
## from this layer, this layer's start and the feet at the gate.
var _way_up := {}

func _init() -> void:
	name = "RunLoop"

func setup(scene: Node3D) -> void:
	study = scene
	overlay = RunOverlay.new()
	scene.add_child(overlay)
	watch(study.motor)
	# [items] Carried items: their caption, the strip, the moves they give.
	_wallrun_flag = bool(study.motor.wallrun_on)
	_items = ItemStrip.new()
	overlay.readout.add_child(_items)
	run.item_taken.connect(_item_found)
	run.item_dropped.connect(func(_id: StringName) -> void: _items.show_items(run.items))
	if ItemsMove.on():  # [items_move]
		_items_move = ItemsMove.new()
		_items_move.setup(scene)
	# Until the first layer stands he walks the base as before; it comes
	# up behind a moment's dark (`_arrive`).
	_veil = 0.0
	overlay.set_veil(_veil_colour,_veil)

# --- Round the study's tick -------------------------------------------------------

## Whether the pilot moves this tick (false: held still behind the veil).
func before_tick(delta: float) -> bool:
	# Held still behind the loading screen (studies/run_layer.gd `loading`).
	var loading: Variant = study.get("loading")
	if loading != null and loading.active: return false
	_t += delta
	var moves := true
	match state:
		"play":
			run.tick(delta)
			_item_moves()
			if _items_move != null: _items_move.before(delta)  # [items_move]
		"arrive":
			run.tick(delta)
			if _t > HOLD: _veil = move_toward(_veil,0.0,delta/CLEAR)
			if _veil <= 0.0: state = "play"
		"falling":
			if _t > FALL_ON: _veil = move_toward(_veil,1.0,delta/FADE)
			if _veil >= 1.0: _to_card()
		"dying":
			run.tick(delta)
			if _t > DOWN_HOLD: _veil = move_toward(_veil,1.0,delta/FADE)
			if _veil >= 1.0: _to_card(_dead_by)
		"gate":
			_veil = move_toward(_veil,1.0,delta/GATE_UP)
			moves = false
		"card":
			moves = false
	overlay.set_veil(_veil_colour,_veil)
	_readout(delta)
	_flicker()
	overlay.step(delta)
	return moves

## After the study's tick: the gate and the void.
func after_tick(_delta: float) -> void:
	if _items_move != null: _items_move.after(_delta)  # [items_move]
	if state != "play" and state != "arrive": return
	var stage: Node3D = study.stage
	if stage == null or (study.layer as Dictionary).is_empty(): return
	var feet: Vector3 = study.motor.feet
	run.at(feet.y-_start_y,bool(study.motor.grounded))
	if stage.at_exit(feet):
		state = "gate"
		_t = 0.0
		_veil_colour = RunOverlay.WARM
		pending = "gate"
		_note_way_up(feet)
		# The next region in its own shape (a run alternates them by depth).
		# The region one on: out of the dark past the last underground one.
		study.request_layer(int(study.layer_seed)+1,"Through the gate: %s" % (WORDS.stage % (run.depth+1)),LayerShapes.after(study.layer),LayerWorlds.region_of(study.layer)+1)
	elif feet.y < float(study.layer.void_y):
		state = "falling"
		_t = 0.0
		_veil_colour = RunOverlay.DARK

## The card: the run's sums, the record kept, and a new climb laid behind
## it at once (so it is ready when he is). `cause` what ended it: "" the
## void, else the harm's (WORDS.causes).
func _to_card(cause := "") -> void:
	state = "card"
	_t = 0.0
	_veil = 1.0
	last_fall = run.die()
	last_fall.seed = run.run_seed
	last_fall.cause = cause
	overlay.show_card(card_title(last_fall),card_facts(last_fall),_hint())
	_wake = false
	_laid_for = -1
	_pre = _draw_seed()
	_ask(_pre)
	# (After the ask: laying a layer sets the study's own.)
	study.last_end = "%s: %s (%s)" % [cause_line(last_fall),card_title(last_fall),WORDS.stage % int(last_fall.depth)]

## "1,180 m" for 1180.4 (none under 0).
static func metres(h: float) -> String:
	var digits := str(maxi(0,roundi(h)))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length()-i)%3 == 0: out += ","
		out += digits[i]
	return "%s %s" % [out,WORDS.unit]

static func card_title(fall: Dictionary) -> String:
	if String(fall.get("cause","")) != "": return WORDS.felled % metres(float(fall.height))
	return WORDS.fell % metres(float(fall.height))

## What ended it, as the card says: "into the void", "by the Olmec".
static func cause_line(fall: Dictionary) -> String:
	var cause := String(fall.get("cause",""))
	if cause == "": return WORDS.cause_void
	return WORDS.cause % String((WORDS.causes as Dictionary).get(cause,cause))

## The card's facts: what did it, the runes lost, how long, a pause, the
## highest.
static func card_facts(fall: Dictionary) -> PackedStringArray:
	var n := int(fall.runes)
	var lost: String = WORDS.lost_none if n == 0 else (WORDS.lost_one if n == 1 else WORDS.lost % n)
	var high: String = WORDS.highest_new if bool(fall.high_record) else WORDS.highest % metres(float(fall.highest))
	# [collectibles] The rares found, and the most in a climb.
	var r := int(fall.get("rares",0))
	var found := rares_words(r)
	var most: String = WORDS.most_new if bool(fall.get("runes_record",false)) or bool(fall.get("rares_record",false)) \
		else WORDS.most % [int(fall.get("most_runes",0)),rares_words(int(fall.get("most_rares",0)))]
	var facts := PackedStringArray([cause_line(fall),lost,found])
	# [items] What he carried, lost with him.
	var held: Array = fall.get("items",[])
	if not held.is_empty():
		var names := PackedStringArray()
		for id: StringName in held: names.append(ItemCatalog.title(id))
		facts.append(WORDS.items_lost % ", ".join(names))
	facts.append_array([RunState.clock(float(fall.time)),"",high,most])
	return facts

## [collectibles] "no sun glyph", "1 sun glyph", "3 sun glyphs".
static func rares_words(n: int) -> String:
	return WORDS.rares_none if n == 0 else (WORDS.rares_one if n == 1 else WORDS.rares % n)

# --- [items] Carried items -------------------------------------------------------------

var _items: Control = null

## An item taken: its caption, the strip.
func _item_found(id: StringName) -> void:
	_loud = LOUD_FOR
	var info := ItemCatalog.info(id)
	overlay.show_caption(ItemCatalog.title(id),String(info.get("line","")))
	_items.show_items(run.items)

## `--give=id,id` (a play and test knob): the run begins carrying them.
func _give_asked() -> void:
	_items.show_items(run.items)
	for id in RunFeatures.value("give").split(",",false):
		if ItemCatalog.has(StringName(id)): run.give_item(StringName(id))

## The moves items give, read live (an item taken mid-layer works at once).
func _item_moves() -> void:
	var motor: Variant = study.get("motor")
	if motor == null: return
	motor.wallrun_on = _wallrun_flag or run.carrying(&"wallrun")

# --- Hearts --------------------------------------------------------------------------

## What ended the run when out of hearts (the harm's cause).
var _dead_by := ""
## The wanderers whose harm is heard (one, for now).
var _watched: Array = []

## Hears `wanderer`'s harm (his motor's `harmed`), keyed by him in the run.
func watch(wanderer: Object) -> void:
	if wanderer == null or wanderer in _watched: return
	_watched.append(wanderer)
	wanderer.connect(&"harmed",_harmed.bind(wanderer))

## A hurt on `wanderer`: hearts off (none while safe from a hit; a fall's
## always), the corner's heart drained, the flash; at none, "dying".
func _harmed(amount: int, cause: String, _source: Object, wanderer: Object) -> void:
	if state != "play" and state != "arrive": return
	var took := run.hurt(wanderer,amount,cause,cause == "fall")
	if took <= 0: return
	_loud = LOUD_FOR
	overlay.hurt(run.hearts_of(wanderer),took)
	if run.hearts_of(wanderer) <= 0:
		state = "dying"
		_t = 0.0
		_dead_by = cause
		_veil_colour = RunOverlay.DARK

## While safe after a hit, his figure blinks (the study's `body`); shown
## steady otherwise, and under the card.
func _flicker() -> void:
	var body: Variant = study.get("body")
	var motor: Variant = study.get("motor")
	if not (body is Node3D) or motor == null: return
	var safe := run.safe_for(motor) if state in ["play","arrive","dying"] else 0.0
	var on := safe <= 0.0 or fposmod(safe*FLICKER_HZ,1.0) < FLICKER_ON
	if (body as Node3D).visible != on: (body as Node3D).visible = on

func _hint() -> String:
	if _wake: return WORDS.waking
	return WORDS.prompt

## Seeds a test hands the next new climbs, in order (else drawn at random).
static var next_seeds: Array = []

func _draw_seed() -> int:
	if not next_seeds.is_empty(): return int(next_seeds.pop_front())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := rng.randi_range(1,99999)
	while s == run.run_seed: s = rng.randi_range(1,99999)
	return s

## A new climb's first layer asked for (laid on a worker windowed).
func _ask(seed_value: int) -> void:
	pending = "run"
	_asked = seed_value
	_want = seed_value
	# A new climb from the run's first region (underground).
	study.request_layer(seed_value,"","",int(study.first_region()) if study.has_method("first_region") else 1)

## Off the card: a new climb (on the seed laid behind the card, or
## `seed_value` if given) or, `same`, the one that fell again.
func continue_run(same := false, seed_value := -1) -> void:
	if state != "card": return
	_wake = true
	overlay.set_prompt(_hint())
	_want = int(last_fall.seed) if same else (seed_value if seed_value > 0 else _pre)
	# Laid on a worker meanwhile, the ask waits for it (`layer_stood`).
	if _laid_for != _want and int(study.get("_plan_task")) < 0: _ask(_want)
	_maybe_wake()

func _maybe_wake() -> void:
	if state != "card" or not _wake or _laid_for != _want: return
	run.begin(_laid_seed)
	_give_asked()
	overlay.hide_card()
	study.hold_for_layer()
	_arrive(RunOverlay.DARK)

func _arrive(colour: Color) -> void:
	state = "arrive"
	_t = 0.0
	_veil = 1.0
	_veil_colour = colour
	_loud = LOUD_FOR
	_lighten()
	if run.depth <= 1:
		var line := "" if run.highest <= 0.0 else WORDS.arrive_first_line % metres(run.highest)
		overlay.show_caption(WORDS.arrive_first,line)
	else:
		# Out of the dark: the first sky region has its own caption.
		var out_of_dark := LayerWorlds.first_sky(study.layer)
		overlay.show_caption(WORDS.arrive_sky if out_of_dark else WORDS.arrive,WORDS.arrive_line % metres(run.height))

## The loading screen is lifting: the arrival's dark veil is not needed
## over a view the screen has just shown (its caption still comes).
func loading_done() -> void:
	if state == "arrive": _veil = 0.0

# --- The study's hooks ------------------------------------------------------------

## A layer stood (the stage built, the pilot at the plan's spawn): the
## start spot and the lit way laid, the pilot set at the start, the run
## told.
func layer_stood() -> void:
	var stage: Node3D = study.stage
	var layer: Dictionary = study.layer
	if WAY_LIT:
		var lights := WayLights.new()
		stage.add_child(lights)
		lights.setup(study,layer)
	var spot := StartSpot.new()
	stage.add_child(spot)
	spot.setup(study,layer)
	study.start = spot.start
	study.start_face = Vector2(spot.face.x,spot.face.z).normalized()
	study.respawn()
	study.set("_last_stood",spot.start)
	_start_y = float(study.start.y)
	stage.rune_taken.connect(func(_left: int) -> void: run.take_rune())
	# [collectibles] The layer's runes, rares and chests into the run.
	var found: Node = stage.get("collectibles")
	if found != null:
		found.rune_taken.connect(func(_src: String, worth: int) -> void: run.take_rune(worth))
		found.rare_taken.connect(_rare_found)
	var why := pending
	pending = ""
	match why:
		"first":
			run.begin(int(study.layer_seed))
			_give_asked()
			_arrive(RunOverlay.DARK)
		"gate","skip":
			run.ascend(_rise_through())
			_arrive(RunOverlay.WARM)
		"run":
			# (Laid on past a seed that can't be, the one laid is the run's.)
			_laid_for = _asked
			_laid_seed = int(study.layer_seed)
			if _wake and _laid_for != _want: _ask(_want)
			_maybe_wake()
	_readout(0.0)

## The corner: the height and the runes; up when a count changes or he
## stands still, quiet while he moves; gone under the card, the long card
## (I) and before the first layer.
func _readout(delta: float) -> void:
	if overlay == null or overlay.readout == null: return
	if run.runes != _shown_runes or run.rares != _shown_rares:
		_shown_runes = run.runes
		_shown_rares = run.rares
		_loud = LOUD_FOR
	_loud = maxf(_loud-delta,0.0)
	var motor: Variant = study.get("motor")
	var speed: float = (motor.velocity as Vector3).length() if motor != null else 0.0
	_still = _still+delta if speed < STILL_SPEED else 0.0
	var long_card: Variant = study.get("_card")
	var shown := run.depth > 0 and state in ["play","arrive","dying"] and not (long_card != null and (long_card as Label).visible)
	# [collectibles] The runes and rares are the tally's, by the hearts.
	var side := ""
	overlay.set_readout(WORDS.readout % metres(run.height),side.to_upper(),shown,_loud > 0.0 or _still > STILL_AFTER)
	var motor_now: Variant = study.get("motor")
	overlay.set_hearts(run.hearts_of(motor_now) if motor_now != null else RunState.HEARTS,RunState.HEARTS)
	_tally().set_counts(run.runes,run.rares)

# --- [collectibles] The tally and a rare's find -------------------------------------

var _shown_rares := 0
var _tally_node: Control = null

## The corner's tally (scripts/roguelike/collect_tally.gd), made on first use.
func _tally() -> Control:
	if _tally_node == null:
		_tally_node = CollectTally.new()
		_tally_node.overlay = overlay
		overlay.readout.add_child(_tally_node)
	return _tally_node

## A rare found: the caption, the tally's pop (the find's light, sound and
## beat are scripts/roguelike/collectibles.gd's).
func _rare_found(got: int, of: int) -> void:
	run.take_rare()
	_loud = LOUD_FOR
	overlay.show_caption(WORDS.rare,WORDS.rare_line % [got,of])
	_tally().pop_rare()

## Keys: on the card, Space / Enter / E (pad A) a new climb, R (pad X) the
## same; anywhere, I the layer's long card. True when used.
func input(event: InputEvent) -> bool:
	var key := -1
	if event is InputEventKey and event.pressed and not event.echo: key = (event as InputEventKey).keycode
	if key == KEY_I:
		var card: Variant = study.get("_card")
		if card != null: (card as Label).visible = not (card as Label).visible
		return true
	if state == "card":
		if key in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER,KEY_E] or Pad.pressed(event,&"walk_jump"):
			continue_run(false)
			return true
		if key == KEY_R or Pad.pressed(event,&"walk_twirl"):
			continue_run(true)
			return true
		return key >= 0 and key != KEY_ESCAPE
	if state == "gate" or state == "falling" or state == "dying": return key >= 0 and key != KEY_ESCAPE
	if key == KEY_N and state != "card":
		pending = "skip" if not (event as InputEventKey).shift_pressed else ""
		if pending == "skip": _note_way_up(study.motor.feet)
	if key == KEY_BACKSPACE: pending = ""
	return false

# --- The way up -------------------------------------------------------------------

## Through a gate (or N): what the arrival needs to know how much higher the
## next layer's start stands. Today a layer has one gate and `plan.next` is
## where it leads; a layer with more (branching worlds) hands the gate's own
## region here instead.
func _note_way_up(feet: Vector3) -> void:
	var layer: Dictionary = study.layer
	_way_up = {"next":layer.get("next",{}),"start_y":_start_y,"feet_y":feet.y,"seed":int(study.layer_seed)}

## How far over the left layer's start the new layer's start stands (m).
## The region seen far off was placed by the generator (LayerSprawl
## `_place_next`: its `xform` takes the next plan's frame into this one's,
## its base RISE_ROLL + RISE_OVER over the gate, or more to be seen), so his
## start there, taken into the old frame, is his true height. A layer laid
## that isn't the region seen (a seed skipped, or none laid yet) counts the
## gate's height and the seed's rolled rise over it.
func _rise_through() -> float:
	var way := _way_up
	_way_up = {}
	if way.is_empty(): return 0.0
	var start: Vector3 = study.start
	var nxt: Dictionary = way.next
	if not nxt.is_empty() and int(nxt.get("seed",-1)) == int(study.layer_seed):
		var xf: Transform3D = nxt.xform
		return (xf*start).y-float(way.start_y)
	return float(way.feet_y)-float(way.start_y)+LayerSprawl.next_rise(int(way.seed))

## The underground's dark eased by the layers climbed (CLIMB_LIGHTEN).
func _lighten() -> void:
	var lift := clampf(CLIMB_LIGHTEN*float(maxi(run.depth-1,0)),0.0,CLIMB_LIGHTEN_MOST)
	var u := study.get_node_or_null("Underground")
	Underground.climb_lift = lift if u == null else Underground.climb_lift
	if u != null and u.has_method("set_climb_lift"): u.call("set_climb_lift",lift)

func _exit_tree() -> void:
	Underground.climb_lift = 0.0
