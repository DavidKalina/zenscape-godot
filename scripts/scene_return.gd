extends Node
## The way back to the title from a scene the scene picker opened
## (scripts/scene_catalog.gd `open`, docs/design/scene-picker.md): hold Esc,
## or View and Menu together on the pad, for HOLD seconds, then let go. A short
## line at the foot of the screen fills while it's held, so a tap of Esc (the
## studies' "let the mouse go", the game's pause) still does only that.
##
## It sits on the tree's root, beside the current scene, so it lives through
## the scene change; it's off again once back on the title.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const NODE_NAME := "SceneReturn"
const HOLD := 1.0

var active := false
## Where the way back goes: the main scene (the title). Tests point it elsewhere.
var title_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
## Seconds held so far.
var held := 0.0
var _hint: Hint

## The return node on `tree`'s root, made if it isn't there yet, and on.
static func ensure(tree: SceneTree) -> Node:
	var node: Node = tree.root.get_node_or_null(NODE_NAME)
	if node == null:
		node = new()
		node.name = NODE_NAME
		tree.root.add_child(node)
	node.active = true
	return node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_hint = Hint.new()
	_hint.owner_node = self
	layer.add_child(_hint)

## Whether the return chord is down: Esc, or View + Menu on any pad.
func chord_down() -> bool:
	if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ESCAPE): return true
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): pads = [0]
	for device: int in pads:
		if Input.is_joy_button_pressed(device,JOY_BUTTON_BACK) and Input.is_joy_button_pressed(device,JOY_BUTTON_START): return true
	return false

func _process(delta: float) -> void:
	if not active:
		held = 0.0
		return
	var down := chord_down()
	# Held long enough: it goes once the chord is let go, so the release of
	# Esc doesn't land on the title's scene while it's still making itself.
	if held >= HOLD:
		if not down: back_to_title()
		return
	held = held+delta if down else 0.0

## Back to the main scene's title, on the command line's own flags (less the
## ones that skip the title).
func back_to_title() -> void:
	active = false
	held = 0.0
	LaunchArgs.set_override(LaunchArgs.title_args())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(title_scene)

## "Back to the title" in small caps over a thread that fills while held.
class Hint extends Control:
	var owner_node: Node
	var _font := Linen.tag_font()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		var on: bool = owner_node.active and owner_node.held > 0.15
		if on or visible: queue_redraw()
		visible = on

	func _draw() -> void:
		var px := Linen.scale_for(get_viewport_rect().size)
		var share := clampf((owner_node.held-0.15)/(HOLD-0.15),0.0,1.0)
		var centre := Vector2(get_viewport_rect().size.x*0.5,get_viewport_rect().size.y-48.0*px)
		var width := 220.0*px
		Linen.fill_round(self,Rect2(centre-Vector2(width*0.5+16.0*px,26.0*px),Vector2(width+32.0*px,40.0*px)),8.0*px,Color(0.078,0.055,0.031,0.55))
		Linen.tag(self,_font,"Let go for the title" if share >= 1.0 else "Back to the title",centre.x,centre.y,px,1.0)
		var line := maxf(1.0,roundf(2.0*px))
		draw_line(Vector2(centre.x-width*0.5,centre.y+8.0*px),Vector2(centre.x-width*0.5+width*share,centre.y+8.0*px),Color(Linen.INK,0.9),line)
