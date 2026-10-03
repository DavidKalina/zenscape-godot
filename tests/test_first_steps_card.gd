extends SceneTree
## The first-steps card: its copy, how it follows the model, found beats, the
## closing card, Skip, where it sits, and each piece's `nudge`.
const Card = preload("res://scripts/first_steps_card.gd")
const FirstSteps = preload("res://scripts/first_steps.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Almanac = preload("res://scripts/almanac.gd")
const Foot = preload("res://scripts/tool_foot.gd")
var failures := 0
var view := SubViewport.new()
var pointings: Array = []

func _initialize() -> void:
	# A 1440x810 frame of its own: the headless root is only 64 square.
	view.size = Vector2i(1440,810)
	view.gui_disable_input = false
	root.add_child(view)
	await process_frame
	await test_copy_and_steps()
	await test_every_near()
	await test_skip()
	await test_finish()
	await test_placement()
	await test_nudges()
	print("First steps card: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

## A model and a card on it, shown at once.
func make() -> Array:
	var model := FirstSteps.new()
	model.settings_path = ""
	root.add_child(model)
	var card: Control = Card.new()
	card.intro_delay = 0.0
	card.pointer_override = Vector2(-50.0,-50.0)
	view.add_child(card)
	card.setup(null,model)
	card.want(true)
	return [card,model]

func drop(pair: Array) -> void:
	pair[0].queue_free()
	pair[1].queue_free()

## Frames of the card by hand, so its fades run without waiting.
func run(card: Control, seconds: float) -> void:
	for i in range(int(seconds/0.05)+1): card._process(0.05)

func filled(card: Control) -> int:
	var count := 0
	for f: float in card._fill: count += 1 if f >= 1.0 else 0
	return count

func test_copy_and_steps() -> void:
	var pair := make()
	var card: Control = pair[0]
	var model: Node = pair[1]
	await process_frame
	check(card.is_in_group("hud_piece"), "It joins the HUD's group")
	check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "It never takes input itself")
	card.presence = 0.0
	card.visible = false
	card.intro_delay = 1.5
	run(card,1.0)
	check(not card.visible, "It waits a moment before it comes in")
	run(card,2.0)
	check(card.visible and is_equal_approx(card.presence,1.0), "It comes in")
	check(card.modulate.a > 0.7 and card.modulate.a < 1.0, "It rests a little receded: %s" % card.modulate.a)
	var words: Array = card.words()
	check(words[0] == "Look round", "The first step's name: %s" % [words[0]])
	check(words[1] == ["Right-drag to look round","scroll to come closer"], "Its line is split on the dot: %s" % [words[1]])
	check(Card.KICKER == "First steps" and Card.SKIP == "Skip", "Kicker and Skip")
	check(card._fill.size() == FirstSteps.STEPS.size() and filled(card) == 0, "A pip a step, none found")
	check(card.near() == "" and card.pointing() == ["",""], "The world's step points at no cloth")
	card.pointing_changed.connect(func(piece: String, id: String) -> void: pointings.append([piece,id]))
	model.mark("look")
	check(card.near() == "", "Between steps it points at nothing")
	run(card,0.6)
	check(filled(card) == 1, "The found pip fills")
	check(card.words()[0] == "Look round" and card._settle >= 1.0, "The name stays and settles through the beat")
	run(card,3.0)
	check(card.words()[0] == "Raise a peak", "The next step eases in: %s" % [card.words()[0]])
	check(card._content >= 1.0, "Its words are fully in")
	check(card.near() == "roll:hand" and card.pointing() == ["roll","hand"], "near follows the step")
	check(pointings == [["roll","hand"]], "It says when it points somewhere new: %s" % [pointings])
	# A later step done early shows as a pip and is never asked.
	model.mark("tree")
	run(card,3.0)
	check(card.words()[0] == "Raise a peak" and filled(card) == 2, "A later step done early only fills its pip")
	model.mark("raise")
	run(card,3.0)
	check(model.current() == "groove" and card.words()[0] == "Thumb a groove", "The next not found step: %s" % [card.words()[0]])
	check(filled(card) == 3, "Pips count the found: %d" % filled(card))
	drop(pair)

func test_every_near() -> void:
	var pair := make()
	var card: Control = pair[0]
	var model: Node = pair[1]
	run(card,2.0)
	for id: String in FirstSteps.STEPS:
		check(card.words()[0] == model.verb(id).name, "%s shows its name" % id)
		check(card.near() == str(model.verb(id).near), "near for %s: %s" % [id,card.near()])
		model.mark(id)
		run(card,4.0)
	# Every verb's near names a piece and an id that piece has.
	var known := {"roll":Roll.TOOLS,"tray":Tray.SPECIMENS.map(func(entry: Dictionary) -> String: return entry.id),"almanac":Almanac.POCKETS,"foot":Foot.SLOTS}
	for id: String in FirstSteps.VERBS:
		var near: String = FirstSteps.VERBS[id].near
		var at := Card.point_at(near)
		check(near.is_empty() == (at[0] == ""), "%s: point_at reads near" % id)
		check(near.is_empty() or at[1] in known[at[0]], "%s: %s is a pocket that exists" % [id,near])
	check(Card.point_at("nonsense") == ["",""] and Card.point_at("roll:") == ["",""], "A near that names nothing points at nothing")
	drop(pair)

func test_skip() -> void:
	var pair := make()
	var card: Control = pair[0]
	var model: Node = pair[1]
	run(card,2.0)
	var skip: Rect2 = card._skip_rect()
	check(card.rect().encloses(skip.grow(-2.0)), "Skip is on the card")
	check(skip.position.y < card.rect().position.y+card.rect().size.y*0.3 and skip.end.x > card.rect().end.x-60.0, "Skip is in the kicker's row, at its right")
	check(not card.press(card.rect().get_center()) and not model.skipped, "A press on the card elsewhere is not Skip's")
	check(not card.press(Vector2(20.0,20.0)) and not model.skipped, "A press on the world is not Skip's")
	check(card.press(skip.get_center()), "A press on Skip is taken")
	check(model.skipped and model.current() == "", "It calls skip on the model")
	check(card.mode == "gone", "It puts itself away")
	run(card,2.0)
	check(card.presence == 0.0 and not card.visible, "It fades away and stays away")
	check(not card.contains_pointer(card.rect().get_center()), "A gone card claims nothing")
	check(not card.press(skip.get_center()), "A gone card takes no press")
	model.restart()
	run(card,2.0)
	check(card.visible and card.words()[0] == "Look round", "A restart brings it back from the top")
	drop(pair)
	# Skipped from the model's side (the field notes) it just leaves too.
	pair = make()
	run(pair[0],2.0)
	pair[1].skip()
	run(pair[0],2.0)
	check(not pair[0].visible, "A skip from elsewhere leaves it")
	drop(pair)

func test_finish() -> void:
	var pair := make()
	var card: Control = pair[0]
	var model: Node = pair[1]
	var finished := [0]
	model.finished.connect(func() -> void: finished[0] += 1)
	run(card,2.0)
	for id: String in FirstSteps.STEPS:
		model.mark(id)
		run(card,3.0)
	check(finished[0] == 1, "The model finished")
	check(card.mode == "last", "The closing card shows")
	check(card.words()[0] == "The rest is yours to find" and card.words()[1] == ["The field notes are under Esc"], "Its copy: %s" % [card.words()])
	check(filled(card) == FirstSteps.STEPS.size(), "Every pip is filled")
	check(card.near() == "" and card.visible, "It points at nothing")
	check(not card.press(card._skip_rect().get_center()) and not model.skipped, "The closing card has no Skip")
	run(card,Card.LAST_HOLD-2.0)
	check(card.mode == "last" and card.visible, "It lingers")
	run(card,4.0)
	check(card.mode == "gone" and not card.visible, "Then it leaves for good")
	check(not model.skipped, "Leaving is not a skip")
	run(card,5.0)
	check(not card.visible, "It stays gone")
	drop(pair)

func test_placement() -> void:
	var pair := make()
	var card: Control = pair[0]
	var roll := Roll.new()
	var tray := Tray.new()
	var almanac := Almanac.new()
	var foot := Foot.new()
	almanac.settings_path = ""
	for piece: Control in [roll,tray,almanac,foot]: view.add_child(piece)
	foot.setup(roll,null)
	for extent: Vector2i in [Vector2i(1440,810),Vector2i(1440,900),Vector2i(1024,768),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(1280,1024),Vector2i(900,1200)]:
		view.size = extent
		for i in range(3): await process_frame
		for piece: Control in [roll,tray,almanac]:
			piece.want(true)
			piece.awake = 1.0
			piece.pointer_override = Vector2(extent)*0.5
		roll.awake_top = 1.0
		almanac.setup(null,null)
		for i in range(25):
			for piece: Control in [roll,tray,almanac,foot]: piece._process(0.05)
		card.pointer_override = Vector2(-50.0,-50.0)
		run(card,2.0)
		var at: Rect2 = card.rect()
		var screen := Vector2(extent)
		var cleared := at.grow(8.0*card.ui_scale)
		var note := " at %s" % [extent]
		check(Rect2(Vector2.ZERO,screen).encloses(at), "On screen"+note)
		check(not cleared.intersects(roll.rect()), "Clear of the roll"+note)
		check(not cleared.intersects(foot.rect()), "Clear of the foot"+note)
		check(not cleared.intersects(roll._strip().grow(4.0*roll.ui_scale)), "Clear of the tool strip"+note)
		check(not cleared.intersects(tray._bar()), "Clear of the tray"+note)
		check(not cleared.intersects(almanac.strip_rect()), "Clear of the almanac"+note)
		# Where the almanac's names appear, to the strip's left, never up here.
		check(at.end.y < almanac.strip_rect().position.y, "Over the almanac"+note)
		check(at.end.y < screen.y*0.5, "In the top half, far from the hint line"+note)
		check(absf(at.end.x-(screen.x-Card.RIGHT*card.ui_scale)) <= 1.0, "Held to the right inset"+note)
		# Only the card claims the pointer.
		var stray := 0
		for gx in range(0,extent.x,24):
			for gy in range(0,extent.y,18):
				var point := Vector2(gx,gy)
				if card.contains_pointer(point) != at.grow(2.0*card.ui_scale).has_point(point): stray += 1
		check(stray == 0, "contains_pointer covers only the card (%d stray)%s" % [stray,note])
		check(card.contains_pointer(at.get_center()) and not card.contains_pointer(at.position-Vector2(40.0,40.0)), "Inside and just outside"+note)
	# It follows the HUD out and back.
	card.want(false)
	run(card,2.0)
	check(not card.visible and not card.contains_pointer(card.rect().get_center()), "It steps out with the HUD")
	card.want(true)
	run(card,2.0)
	check(card.visible, "And comes back with it")
	# It recedes in a drag and does not vanish.
	var calm: float = card.modulate.a
	card.quiet = true
	run(card,2.0)
	check(card.visible and card.modulate.a < calm and card.modulate.a > 0.2, "It recedes in a drag and does not vanish: %s" % card.modulate.a)
	card.quiet = false
	card.pointer_override = card.rect().get_center()
	run(card,2.0)
	check(card.modulate.a > calm, "It wakes with the pointer over it")
	view.size = Vector2i(1440,810)
	for piece: Control in [roll,tray,almanac,foot]: piece.queue_free()
	drop(pair)

func test_nudges() -> void:
	view.size = Vector2i(1440,810)
	await process_frame
	var far := Vector2(720.0,405.0)
	var roll := Roll.new()
	var tray := Tray.new()
	var almanac := Almanac.new()
	var foot := Foot.new()
	almanac.settings_path = ""
	for piece: Control in [roll,tray,almanac,foot]: view.add_child(piece)
	foot.setup(roll,null)
	almanac.setup(null,null)
	for piece: Control in [roll,tray,almanac,foot]:
		if piece != foot: piece.want(true)
		if piece != foot: piece.pointer_override = far
	await process_frame
	var step := func() -> void:
		for i in range(25):
			for piece: Control in [roll,tray,almanac,foot]: piece._process(0.05)
	step.call()
	check(roll.awake == 0.0 and roll.awake_top == 0.0 and tray.awake == 0.0 and almanac.awake == 0.0 and foot.awake == 0.0, "Without a nudge everything rests with the pointer far")
	check(roll.nudged == "" and tray.nudged == "" and almanac.nudged == "" and foot.nudged == "", "Nothing is nudged to begin with")
	# Each piece: set, wake, clear.
	var cases := [[roll,"hand"],[tray,"water"],[almanac,"time"],[foot,"undo"]]
	for entry: Array in cases:
		var piece: Control = entry[0]
		var id: String = entry[1]
		piece.nudge(id)
		check(piece.nudged == id, "%s: nudge sets" % id)
		step.call()
		check(piece.awake >= 1.0, "%s stays reached for" % id)
		check(piece._nudge_a >= 1.0 and piece._nudge_for == id, "%s: its ring is up" % id)
		await process_frame
		# A mid-breath frame draws without a fault.
		piece._nudge_t = Roll.NUDGE_PERIOD*0.5
		piece.queue_redraw()
		await process_frame
		piece.nudge("")
		check(piece.nudged == "", "%s: nudge clears" % id)
		step.call()
		check(piece._nudge_a <= 0.0 and piece._nudge_for == "", "%s: its ring is gone" % id)
		check(piece.awake <= 0.0, "%s rests again" % id)
	# The roll's top strip has its own reach.
	roll.nudge("can")
	step.call()
	check(roll.awake_top >= 1.0 and roll.awake == 0.0, "A top tool wakes the strip, not the roll")
	roll.nudge("")
	step.call()
	check(roll.awake_top == 0.0, "And lets it rest")
	# A drag keeps the piece quiet even when it is pointed at.
	tray.quiet = true
	tray.nudge("water")
	step.call()
	check(tray.awake == 0.0, "A drag under way still keeps the tray quiet")
	tray.nudge("")
	for piece: Control in [roll,tray,almanac,foot]: piece.queue_free()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
