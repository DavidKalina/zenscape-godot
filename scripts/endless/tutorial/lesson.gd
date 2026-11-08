extends Node
## The lesson (endless flight; docs/ship/spec-ship.md, round 2, lane
## `tutorial-flow`): a fresh book's first flight, taught by the land ahead.
## No step list: one stage at a time, each ended by doing its thing enough
## times (NEEDS below), counted off the near-miss moments that already
## exist (near_miss.gd's frame events; the scoring is not forked):
##   GRASS  pull-outs over land, or seconds of skim (NearMiss `skimming`);
##   TREES  grazes of a tree;
##   WATER  pull-outs over water;
##   GAUGE  the surge meter full once (SurgeSmash FULL);
##   WALL   the ruin hall's cracked wall broken: `tutorial_land.broke_through`
##          when that node is there (lane `tutorial-land`); without it, the
##          next surge roll, or `wall_done()` (a driver's).
## Then DONE: `tutorial_done` in the book, the money, the shop pointer and
## the key strip back. Skip (Backspace, the pad's D-pad down) ends it at
## any time the same way, and swaps to the wilderness through
## `tutorial_land.skip()` when that node is there.
##
## The HUD while it runs is one line top centre (the verb and the count),
## the skip hint small under it, "lower" after LOWER_HOLD s above LOWER_OVER
## m over the turf; the money HUD, its shop pointer and the key strip are
## hidden (node visibility; the money HUD's own fade is paused).
##
## The start: on Start from the title the plane is put in the air, low and
## level over the grass, flying, in place of the takeoff (`air_start`);
## with no title, at once.
##
## Wanted on a fresh book (no `tutorial_done`, no flight before this one);
## --tutorial (or round 1's --first-flight) in any run, --tutorial=0 never.
## --no-title does not stop it on a real book; a harness run (no book file)
## with --no-title gets it only with --tutorial.

const MoneyHud = preload("res://scripts/endless/money_hud.gd")
const SurgeSmash = preload("res://scripts/endless/surge_smash.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Pad = preload("res://scripts/pad.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TreePlan = preload("res://scripts/endless/tree_plan.gd")
const LessonRibbon = preload("res://scripts/endless/tutorial/lesson_ribbon.gd")
const WORDS = preload("res://assets/fonts/newsreader-latin.woff2")
const NUMS = preload("res://assets/fonts/barlow-semi-condensed-800-latin.woff2")

enum Stage {GRASS, TREES, WATER, GAUGE, WALL, DONE}

# --- The requirements (one table; tuned later) -----------------------------------
## Per stage: the line's verb, and what ends it. `pulls_land` pull-outs over
## land, `skim` seconds of skim, `grazes` grazes of a tree, `pulls_water`
## pull-outs over water, `meter` the meter full once, `wall` the wall broken.
## At TREES `pass_spans` is the lesson's own tree pass: the plane's middle
## within that many spans of a tree's crown, counted once per tree as it
## leaves (`_tree_pass`); looser than the game's scored graze (CLOSE, half a
## span over the crown), which still counts and is left as it is.
const NEEDS := {
	Stage.GRASS: {"verb":"dive and pull out over the grass", "pulls_land":3, "skim":8.0},
	Stage.TREES: {"verb":"graze a tree", "pass_spans":3.0, "grazes":3},
	Stage.WATER: {"verb":"pull out low over the water", "pulls_water":2},
	Stage.GAUGE: {"verb":"fill the gauge", "meter":1},
	Stage.WALL: {"verb":"surge roll through the cracked wall", "wall":1},
}
## The plane put in the air at the start: this high over the turf (in plane
## spans, at least SKIM_MIN m), level, at cruise.
const SKIM_SPANS := 1.6
const SKIM_MIN := 3.0
## "lower" is shown after LOWER_HOLD s more than LOWER_OVER m over the turf.
const LOWER_OVER := 40.0
const LOWER_HOLD := 2.0
## The count's flash when it goes up, and the line's when the stage changes (s).
const FLASH := 0.6

const CREAM := Color("f6f3ea")
const GOLD := Color("ffd36b")
const KEY := Color("0e1013")
const GREY := Color("8a93a0")

signal stage_changed(stage: int)

var game: Node
var stage: int = Stage.GRASS
## This stage's count toward its requirement, and the skim's seconds (GRASS).
var count := 0
var skim := 0.0
## The tree pass (TREES): the nearest crown's clearance this frame (m, from
## the plane's middle; INF none near), the tree the open pass is by (its
## XZ, or INF) and the trees already counted.
var tree_clear := INF
var _pass_tree := Vector2(INF,INF)
var _passed := {}
var skipped := false
## Seconds the plane has been over LOWER_OVER m (for "lower").
var high_for := 0.0
## Whether the lesson has begun (the title's Start, or at once with no title).
var begun := false
var _flash := 0.0
var _line: Control
## The guide ribbon at GRASS and WATER (lesson_ribbon.gd).
var ribbon: Node
var _land: Node
var _hidden: Array[CanvasItem] = []

## Whether this run gets the lesson.
static func wanted(book: RefCounted) -> bool:
	var args := LaunchArgs.user_args()
	for off: String in ["--tutorial=0","--tutorial=off","--first-flight=0","--first-flight=off"]:
		if off in args: return false
	for on: String in ["--tutorial","--tutorial=1","--first-flight","--first-flight=1"]:
		if on in args: return true
	if book == null: return false
	if "--no-title" in args and str(book.get("path")) == "": return false
	return not bool(book.get("tutorial_done")) and int(book.get("flights")) <= 1

func setup(g: Node) -> void:
	game = g
	name = "Lesson"
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_line = Line.new()
	_line.lesson = self
	_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_line)
	_line.visible = false
	ribbon = LessonRibbon.new()
	add_child(ribbon)
	ribbon.setup(g)
	_hide_hud(true)
	if game.get("stage") == null: air_start()

func running() -> bool:
	return stage < Stage.DONE

## The requirement of the current stage ({} at DONE).
func need() -> Dictionary:
	return NEEDS.get(stage,{})

## The count the stage wants (the first of its keys; GRASS's pull-outs).
func goal() -> int:
	var n := need()
	for k: String in ["pulls_land","grazes","pulls_water","meter","wall"]:
		if n.has(k): return int(n[k])
	return 0

## Start picked on the title: in the air, low and level, flying, in place
## of the takeoff. True when it took the start (the study then skips the
## stage's own).
func air_start() -> bool:
	if game == null or not running(): return false
	var st: RefCounted = game.get("stage")
	if st != null and st.has_method("start"): st.start()  # the overlay fades
	var p: Vector3 = game.plane.position
	var h := float(game.plane.heading)
	var turf := maxf(float(game.field.height(p.x,p.z)),float(game.water_at(p)))
	var alt := maxf(WorldScale.span*SKIM_SPANS,SKIM_MIN)
	game._launch(Vector3(p.x,turf+alt,p.z),h)
	begun = true
	_flash = FLASH
	return true

## The wall broken (the land lane's signal, the surge roll without it, or a
## driver).
func wall_done() -> void:
	if stage == Stage.WALL: _set_stage(Stage.DONE)

func skip() -> void:
	if not running(): return
	skipped = true
	_set_stage(Stage.DONE)
	# The wilderness: through the lesson's land when it is there; else the
	# world is already the game's (in the tutorial world without its land,
	# back to the world's own start).
	var land: Node = game.get("tutorial_land")
	if land != null and land.has_method("skip"): land.skip()
	elif game.world != null and str(game.world.id) == "tutorial":
		var s: Vector2 = game.world.spawn.get("at",Vector2(game.plane.position.x,game.plane.position.z))
		game._start = s
		game._launch(Vector3(s.x,game._start_height(),s.y),float(game.plane.heading))

func _unhandled_input(event: InputEvent) -> void:
	if not running() or game == null or game.get("stage") != null or game.get("overlay") != null: return
	var hit: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_BACKSPACE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_DOWN)
	if hit:
		skip()
		get_viewport().set_input_as_handled()

## One frame, after the plane moved and the near misses were scored.
func step(delta: float) -> void:
	if not running(): return
	_connect_land()
	_hide_hud(true)
	if game.get("stage") != null or game.plane == null:
		_line.visible = false
		if ribbon.stage >= 0: ribbon.set_stage(-1)
		return
	begun = true
	_flash = maxf(0.0,_flash-delta)
	var flying: bool = game.hand_landing.flying()
	var ev: Dictionary = game._events
	var m: Dictionary = ev.get("near",{})
	var kind := str(m.get("kind",""))
	var surf := str(m.get("surface",""))
	var n := need()
	var before := count
	match stage:
		Stage.GRASS:
			if kind == "pull-out" and surf == "land": count += 1
			if flying and bool(game.near.skimming): skim += delta
			if count >= int(n.pulls_land) or skim >= float(n.skim): _next()
		Stage.TREES:
			if _tree_pass(flying,float(n.pass_spans)): count += 1
			elif kind == "graze" and surf == "tree" and _pass_tree.x == INF: count += 1
			if count >= int(n.grazes): _next()
		Stage.WATER:
			if kind == "pull-out" and surf == "water": count += 1
			if count >= int(n.pulls_water): _next()
		Stage.GAUGE:
			if float(game.near.meter) >= SurgeSmash.FULL:
				count = 1
				_next()
		Stage.WALL:
			# Without the lesson's land there is no wall: the surge roll is it.
			if _land == null and game.smash != null and bool(game.smash.hot): wall_done()
	if count > before and running(): _flash = FLASH
	if running():
		if ribbon.stage != stage: ribbon.set_stage(stage)
		ribbon.step(delta)
	# "lower": long over the turf's band.
	var p: Vector3 = game.plane.position
	var turf := maxf(float(game.field.height(p.x,p.z)),float(game.water_at(p)))
	high_for = high_for+delta if flying and p.y-turf > LOWER_OVER else 0.0
	_line.visible = running() and game.get("overlay") == null
	if _line.visible: _line.queue_redraw()

## The lesson's tree pass, one frame: true as a pass ends (the plane leaves
## the crown it came within `spans` of, flying). A tree counts once.
func _tree_pass(flying: bool, spans: float) -> bool:
	var near := _nearest_tree()
	tree_clear = near.z
	var reach := spans*WorldScale.span
	var at := Vector2(near.x,near.y)
	if _pass_tree.x != INF:
		# Still by the same tree and inside the reach (a little slack out).
		if flying and at == _pass_tree and tree_clear < reach*1.25: return false
		var done := _pass_tree
		_pass_tree = Vector2(INF,INF)
		if _passed.has(done): return false
		_passed[done] = true
		return true
	if flying and tree_clear < reach and not _passed.has(at): _pass_tree = at
	return false

## The nearest tree crown to the plane's middle: (x, z, clearance m). The
## crown a cone from its bottom (its radius) to the top; under it, the
## crown's side; over it, the line to the top.
func _nearest_tree() -> Vector3:
	var best := Vector3(INF,INF,INF)
	if game.trees == null: return best
	var p: Vector3 = game.plane.position
	var ck := TreePlan.cell_of(p.x,p.z)
	for dz in range(-1,2):
		for dx in range(-1,2):
			var s: PackedFloat32Array = game.trees.cell_trees(ck+Vector2i(dx,dz))
			for i in range(0,s.size(),8):
				if s[i+3] <= 0.0: continue
				var h := Vector2(p.x-s[i],p.z-s[i+1]).length()
				if h-s[i+6] > best.z: continue
				var top := s[i+2]+s[i+3]
				var bottom := s[i+2]+s[i+4]
				var c: float
				if p.y >= top: c = Vector2(h,p.y-top).length()
				elif p.y <= bottom: c = maxf(h-s[i+6],0.0)
				else: c = maxf(h-s[i+6]*(top-p.y)/maxf(top-bottom,0.01),0.0)
				if c < best.z: best = Vector3(s[i],s[i+1],c)
	return best

func _next() -> void:
	_set_stage(stage+1)

func _set_stage(s: int) -> void:
	stage = s
	count = 0
	skim = 0.0
	_pass_tree = Vector2(INF,INF)
	_passed.clear()
	_flash = FLASH
	ribbon.set_stage(stage)
	if stage == Stage.DONE:
		_line.visible = false
		_hide_hud(false)
		game.book.set("tutorial_done",true)
		game.book.save()
	stage_changed.emit(stage)

func _connect_land() -> void:
	if _land != null: return
	var land: Node = game.get("tutorial_land")
	if land == null: return
	_land = land
	if land.has_signal("broke_through") and not land.is_connected("broke_through",wall_done):
		land.connect("broke_through",wall_done)

## The money HUD (and its shop pointer), the finds and the key strip hidden while the
## lesson runs, shown again after. The money HUD fades itself each frame, so
## its processing is paused while hidden.
func _hide_hud(hide: bool) -> void:
	var strip: CanvasItem = game.get("_hint")
	if _hidden.is_empty() and strip != null:
		for c: Node in strip.get_parent().get_children():
			if c.get_script() == MoneyHud: _hidden.append(c)
	for c: CanvasItem in _hidden:
		c.visible = not hide
		c.process_mode = Node.PROCESS_MODE_DISABLED if hide else Node.PROCESS_MODE_INHERIT
	# The finds' tally and their marks too.
	var finds: Node = game.get("finds")
	if finds != null and finds.has_method("hush"): finds.hush(hide)
	if strip != null:
		if hide: strip.visible = false
		elif game.get("stage") == null: strip.visible = true

## The line's words: [the verb and the count, the skip hint].
func line_text() -> Array:
	var n := need()
	var verb := str(n.get("verb",""))
	var c := ""
	if stage == Stage.GRASS and skim >= 1.0 and skim/float(n.skim) > float(count)/float(n.pulls_land):
		c = "%d/%d s" % [int(skim),int(float(n.skim))]
	elif goal() > 1: c = "%d/%d" % [count,goal()]
	var t := verb+("  "+c if c != "" else "")
	if high_for >= LOWER_HOLD: t += "  ·  lower"
	return [t,Pad.pick("Backspace  skip","D-pad down  skip")]

## The line at the top of the screen.
class Line extends Control:
	var lesson: Node

	func _draw() -> void:
		if lesson == null: return
		var lines: Array = lesson.line_text()
		var cx := size.x*0.5
		var y := 58.0
		var f := float(lesson._flash)/FLASH
		var t := str(lines[0])
		var w := WORDS.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x+64.0
		draw_rect(Rect2(cx-w*0.5,y-30.0,w,64.0),Color(KEY,0.45))
		_text(WORDS,t,Vector2(cx,y),26,CREAM.lerp(GOLD,f))
		_text(NUMS,str(lines[1]),Vector2(cx,y+24.0),14,Color(GREY.lightened(0.25),0.85))

	func _text(font: Font, t: String, at: Vector2, px: int, col: Color) -> void:
		var tw := font.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		var p := Vector2(at.x-tw*0.5,at.y)
		draw_string_outline(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,px,6,Color(KEY,0.85))
		draw_string(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,px,col)
