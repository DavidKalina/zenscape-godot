extends Node
## The run on the sprawl layer (studies/run_layer.tscn --shape=sprawl;
## docs/design/roguelike/stakes-experiment.md): a climb from layer 1 on a
## seed, the gate a layer deeper, the void the end of it.
##
## - **Through the gate**: a flash of warm light, and he stands at the next
##   layer's start (the region he saw far off), a layer deeper, his runes
##   still with him.
## - **Into the void** (under every isle, the plan's `void_y`): he falls on
##   a moment (FALL_ON), the screen goes dark (FADE), and a quiet card says
##   the height he fell from, the runes lost, how long, the highest yet.
##   Then Space (pad A) climbs again from layer 1 on a new seed, R (pad X)
##   the same climb again. The new climb is laid behind the card while it
##   is read.
## - A fall onto a lower isle (its fall stun) is no end, just a setback.
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

## Past the void, falling on before the dark comes (s), the dark coming (s).
const FALL_ON := 1.1
const FADE := 1.3
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
	"fell": "FELL FROM %s",        # the card's title
	"lost_none": "nothing carried",
	"lost_one": "1 rune lost",
	"lost": "%d runes lost",
	"highest": "highest: %s",
	"highest_new": "the highest yet",
	"prompt": "SPACE / A   A NEW CLIMB            R / X   THE SAME",
	"waking": "...",
	"stage": "layer %d",           # dev only (the study's card, its log)
}
## Seconds the readout stays up after a count changes, and standing still
## before it comes up; the speed (m/s) under which he is still.
const LOUD_FOR := 3.0
const STILL_AFTER := 0.6
const STILL_SPEED := 0.4

var study: Node3D
var run := RunState.new()
var overlay: CanvasLayer
## "play", "falling" (past the void, the dark coming), "card" (the fall's
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

func _init() -> void:
	name = "RunLoop"

func setup(scene: Node3D) -> void:
	study = scene
	overlay = RunOverlay.new()
	scene.add_child(overlay)
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
		"arrive":
			run.tick(delta)
			if _t > HOLD: _veil = move_toward(_veil,0.0,delta/CLEAR)
			if _veil <= 0.0: state = "play"
		"falling":
			if _t > FALL_ON: _veil = move_toward(_veil,1.0,delta/FADE)
			if _veil >= 1.0: _to_card()
		"gate":
			_veil = move_toward(_veil,1.0,delta/GATE_UP)
			moves = false
		"card":
			moves = false
	overlay.set_veil(_veil_colour,_veil)
	_readout(delta)
	overlay.step(delta)
	return moves

## After the study's tick: the gate and the void.
func after_tick(_delta: float) -> void:
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
		# The next region in its own shape (a run alternates them by depth).
		# The region one on: out of the dark past the last underground one.
		study.request_layer(int(study.layer_seed)+1,"Through the gate: %s" % (WORDS.stage % (run.depth+1)),LayerShapes.after(study.layer),LayerWorlds.region_of(study.layer)+1)
	elif feet.y < float(study.layer.void_y):
		state = "falling"
		_t = 0.0
		_veil_colour = RunOverlay.DARK

## The card: the run's sums, the record kept, and a new climb laid behind
## it at once (so it is ready when he is).
func _to_card() -> void:
	state = "card"
	_t = 0.0
	_veil = 1.0
	last_fall = run.die()
	last_fall.seed = run.run_seed
	overlay.show_card(card_title(last_fall),card_facts(last_fall),_hint())
	_wake = false
	_laid_for = -1
	_pre = _draw_seed()
	_ask(_pre)
	# (After the ask: laying a layer sets the study's own.)
	study.last_end = "Into the void: fell from %s (%s)" % [metres(float(last_fall.height)),WORDS.stage % int(last_fall.depth)]

## "1,180 m" for 1180.4; "-340 m" under the surface (scripts/roguelike/
## layer_worlds.gd).
static func metres(h: float) -> String:
	var digits := str(absi(roundi(h)))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length()-i)%3 == 0: out += ","
		out += digits[i]
	return "%s%s %s" % ["-" if roundi(h) < 0 else "",out,WORDS.unit]

static func card_title(fall: Dictionary) -> String:
	return WORDS.fell % metres(float(fall.height))

## The card's facts: the runes lost, how long, a pause, the highest.
static func card_facts(fall: Dictionary) -> PackedStringArray:
	var n := int(fall.runes)
	var lost: String = WORDS.lost_none if n == 0 else (WORDS.lost_one if n == 1 else WORDS.lost % n)
	var high: String = WORDS.highest_new if bool(fall.high_record) else WORDS.highest % metres(float(fall.highest))
	return PackedStringArray([lost,RunState.clock(float(fall.time)),"",high])

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
	overlay.hide_card()
	study.hold_for_layer()
	_arrive(RunOverlay.DARK)

func _arrive(colour: Color) -> void:
	state = "arrive"
	_t = 0.0
	_veil = 1.0
	_veil_colour = colour
	_loud = LOUD_FOR
	if run.depth <= 1:
		var line := "" if run.highest <= 0.0 else WORDS.arrive_first_line % metres(run.highest)
		overlay.show_caption(WORDS.arrive_first,line)
	else:
		# Out of the dark: the first sky region has its own caption.
		var out_of_dark := LayerWorlds.first_sky(study.layer)
		overlay.show_caption(WORDS.arrive_sky if out_of_dark else WORDS.arrive,WORDS.arrive_line % metres(shown_height()))

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
	var why := pending
	pending = ""
	match why:
		"first":
			run.begin(int(study.layer_seed))
			_arrive(RunOverlay.DARK)
		"gate","skip":
			run.descend()
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
	if run.runes != _shown_runes:
		_shown_runes = run.runes
		_loud = LOUD_FOR
	_loud = maxf(_loud-delta,0.0)
	var motor: Variant = study.get("motor")
	var speed: float = (motor.velocity as Vector3).length() if motor != null else 0.0
	_still = _still+delta if speed < STILL_SPEED else 0.0
	var long_card: Variant = study.get("_card")
	var shown := run.depth > 0 and state in ["play","arrive"] and not (long_card != null and (long_card as Label).visible)
	var side := "" if run.runes == 0 else (WORDS.rune if run.runes == 1 else WORDS.runes) % run.runes
	overlay.set_readout(WORDS.readout % metres(shown_height()),side.to_upper(),shown,_loud > 0.0 or _still > STILL_AFTER)

## The height the player reads: the run's climb, and underground less how
## far under the surface this region stands (LayerWorlds `depth_below`), so
## the dark reads below zero and the sky above it.
func shown_height() -> float:
	var plan: Dictionary = study.layer
	if plan.is_empty() or LayerWorlds.of(plan) != "under": return run.height
	var k: Dictionary = plan.get("knobs",{})
	return run.height-LayerWorlds.depth_below(LayerWorlds.region_of(plan),int(k.get("under_regions",LayerWorlds.UNDER_REGIONS)))

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
	if state == "gate" or state == "falling": return key >= 0 and key != KEY_ESCAPE
	if key == KEY_N and state != "card": pending = "skip" if not (event as InputEventKey).shift_pressed else ""
	if key == KEY_BACKSPACE: pending = ""
	return false
