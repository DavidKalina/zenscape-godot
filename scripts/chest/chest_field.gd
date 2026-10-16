extends Node3D
## The treasure chests of a scene (scripts/chest/treasure_chest.gd), stepped
## beside the pilot's motor the way
## scripts/cannon/cannon_field.gd is: hooked into a character study as its
## `foot_pieces` (`attach`), or a child a stage steps from its own `before`,
## `after` and `pose` (scripts/roguelike/layer_stage.gd does that for its
## cannons).
##
## - **The press.** The game's own Jump action (walk_jump, A / Space, as the
##   cannon's operate) pressed afresh within REACH m of a chest's footprint,
##   on the ground, opens it (a locked one only rattles). There is no
##   separate interact action; the press is the cannon's.
## - **The slam.** The field joins the slam's group (scripts/slam.gd): a hard
##   slam (`Slam.decent`) landing on a lid opens that chest, locked or not.
## - **The noise.** An opening is "opening a chest", a big spike in the
##   dragon's table of what greed costs. The game has no attention system yet, only the
##   sounds an EnemyField (scripts/enemies/enemy_field.gd `sound`) logs and
##   hands its `sound_hook`, as the cannon's `sounded` signal does. So the
##   field emits `sounded(&"chest_open", at, loud)`, logs it in `heard`, and
##   hands it to `enemies.sound(&"chest_open", at)` when `enemies` is set; a
##   listener (the dragon's attention, later) subscribes to either.
## - **The runes.** Each spilled rune that is taken goes out as
##   `rune_taken(left)`; connect it as the stage's is (run_loop.gd:
##   `run.take_rune()`) and the run counts it.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const TreasureChest = preload("res://scripts/chest/treasure_chest.gd")
const Slam = preload("res://scripts/slam.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")

## How near (m, from the footprint's edge, by the walker's size) he must
## stand to open one.
const REACH := 0.9

## A chest opened: the chest, how, and the noise: (kind, at, loud).
signal opened(chest: Node3D, how: String)
signal sounded(kind: StringName, at: Vector3, loud: float)
signal rune_taken(left: int)

var study: Node3D
var motor: PilotMotor
## What stood in the study's slot before, stepped first (or null).
var inner: Node = null
var chests: Array[Node3D] = []
## The noises made, as [kind, at, loud].
var heard: Array = []
## An EnemyField to hand the noise to (its `sound`), or null.
var enemies: Node = null
## Runes taken from chests, all of them.
var taken := 0
var _held := {}
var _ray := PhysicsRayQueryParameters3D.new()
var _prompt: Label

func _init() -> void:
	name = "ChestField"

func _ready() -> void:
	add_to_group(Slam.GROUP)

## Hooked into `scene` (a character study): stepped by its frame, what was
## there before kept.
func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	inner = scene.foot_pieces
	scene.foot_pieces = self
	if get_parent() == null: scene.add_child(self)

## A chest set down at `at` (the ground under its middle) facing `yaw`
## (rad, about up: 0 opens its mouth toward +z); knobs {runes, locked,
## loud, seed, weathered}.
func add_chest(at: Vector3, yaw := 0.0, knobs := {}) -> Node3D:
	var chest: Node3D = TreasureChest.new()
	chest.configure(knobs)
	chest.build()
	chest.ground_at = _floor_under
	add_child(chest)
	chest.global_transform = Transform3D(Basis(Vector3.UP,yaw),at)
	chest.opened.connect(func(where: Vector3, loud: float, how: String) -> void: _opened(chest,where,loud,how))
	chest.rune_taken.connect(func(left: int) -> void:
		taken += 1
		rune_taken.emit(left))
	chests.append(chest)
	return chest

func _opened(chest: Node3D, where: Vector3, loud: float, how: String) -> void:
	heard.append([&"chest_open",where,loud])
	sounded.emit(&"chest_open",where,loud)
	if enemies != null and enemies.has_method("sound"): enemies.sound(&"chest_open",where)
	opened.emit(chest,how)

## How many runes the opened chests have yet to give: lying or in the air.
func runes_left() -> int:
	var n := 0
	for c in chests: n += c.runes_left() if c.state != "closed" else 0
	return n

## The chest he could press now from where he stands, or null.
func near_chest() -> Node3D:
	if motor == null or motor.rider != null or not motor.grounded: return null
	var best: Node3D = null
	var best_gap := INF
	for c in chests:
		if c.state != "closed": continue
		var g: float = c.gap(motor.feet)
		if g <= REACH*motor.size and absf(motor.feet.y-c.global_position.y) < 1.2 and g < best_gap:
			best = c
			best_gap = g
	return best

# --- The slot ------------------------------------------------------------------------

func before(delta: float) -> void:
	if inner != null: inner.before(delta)
	var a := _edge(&"walk_jump")
	if a:
		var c := near_chest()
		if c != null: c.press()
	for c in chests: c.advance(delta)
	_show_prompt()

func after(delta: float, events: Dictionary) -> void:
	if inner != null: inner.after(delta,events)
	if study != null and study.get("figure") != null:
		var middle: Vector3 = study.figure.global_position+Vector3.UP*Lines.WALKER_MIDDLE
		for c in chests: c.touch(middle)

func pose(figure: Node3D) -> void:
	if inner != null: inner.pose(figure)

func frame(camera: Camera3D, delta: float) -> void:
	if inner != null and inner.has_method("frame"): inner.frame(camera,delta)

## Set down again (a respawn, R): the opened chests stay open and what they
## spilled stays where it lies.
func reset() -> void:
	if inner != null and inner.has_method("reset"): inner.reset()
	for c in chests: c._last = Vector3.INF

## A study's restart only: every chest shut and full again.
func close_all() -> void:
	for c in chests: c.close()
	heard.clear()
	taken = 0

## The slam's push: a hard one on a lid opens it.
func slam(at: Vector3, radius: float, strength: float) -> void:
	for c in chests: c.slam(at,radius,strength)

# --- The ground, the buttons, the prompt ------------------------------------------------

## The height of the first thing under `p`, INF if none (a rune lands where
## there is ground).
func _floor_under(p: Vector3) -> float:
	if study == null or study.get("ground") == null or not is_inside_tree(): return p.y
	_ray.from = p+Vector3.UP*2.0
	_ray.to = p-Vector3.UP*3.0
	_ray.collision_mask = study.ground.mask
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return INF if hit.is_empty() else (hit.position as Vector3).y

func _edge(action: StringName) -> bool:
	var down := Input.is_action_pressed(action)
	var was: bool = _held.get(action,false)
	_held[action] = down
	return down and not was

func prompt_lines() -> Array:
	var c := near_chest()
	if c == null: return ["",""]
	if c.locked: return ["Locked: slam on its lid","Locked: {walk_crouch} slam on its lid"]
	return ["Space open the chest","{walk_jump} open the chest"]

func _show_prompt() -> void:
	if _prompt == null:
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_prompt = PadPrompt.new()
		_prompt.add_theme_font_size_override("font_size",16)
		_prompt.add_theme_color_override("font_color",Color("fbf6ea"))
		_prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.offset_top = -110.0
		_prompt.offset_bottom = -80.0
		_prompt.offset_left = -480.0
		_prompt.offset_right = 480.0
		layer.add_child(_prompt)
	var lines := prompt_lines()
	_prompt.alternates = {lines[0]:lines[1]}
	_prompt.text = lines[0]
	_prompt.visible = lines[0] != ""

## The prompt as on screen (for tests).
func shown_prompt() -> String:
	return _prompt.shown_text() if _prompt != null else ""
