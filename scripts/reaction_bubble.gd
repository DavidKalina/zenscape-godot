extends Node3D
## Bigfoot's painted reaction bubbles. Callers name a feeling or an intent
## ("fish", "rainbow", "?"); this node chooses the bubble shape, paints the
## icon and animates both on a screen-space layer, so fog, depth and distance
## never hide or shrink it. Place it where the tail should point (his head).
## Art comes from tools/paint_reaction_icons.py and works in viewBox units;
## the SVGs are imported at twice that size and drawn at half scale.

const PAINT = preload("res://shaders/reaction_paint.gdshader")
## Preloaded with the script: a first load() mid-reaction stalls the frame
## the reaction starts on, which is usually the frame an activity begins.
const ART := {
	"bubble_speech":preload("res://assets/reactions/bubble_speech.svg"),
	"bubble_thought":preload("res://assets/reactions/bubble_thought.svg"),
	"bubble_shout":preload("res://assets/reactions/bubble_shout.svg"),
	"bolt":preload("res://assets/reactions/bolt.svg"),
	"cloud":preload("res://assets/reactions/cloud.svg"),
	"dot":preload("res://assets/reactions/dot.svg"),
	"drop":preload("res://assets/reactions/drop.svg"),
	"exclaim":preload("res://assets/reactions/exclaim.svg"),
	"fire":preload("res://assets/reactions/fire.svg"),
	"fish":preload("res://assets/reactions/fish.svg"),
	"heart":preload("res://assets/reactions/heart.svg"),
	"leaf":preload("res://assets/reactions/leaf.svg"),
	"nest":preload("res://assets/reactions/nest.svg"),
	"puff":preload("res://assets/reactions/puff.svg"),
	"question":preload("res://assets/reactions/question.svg"),
	"rainbow":preload("res://assets/reactions/rainbow.svg"),
	"snowflake":preload("res://assets/reactions/snowflake.svg"),
	"star":preload("res://assets/reactions/star.svg"),
	"stick":preload("res://assets/reactions/stick.svg"),
	"stone":preload("res://assets/reactions/stone.svg"),
	"tree":preload("res://assets/reactions/tree.svg"),
}
## symbol -> [bubble shape, icon]. Speech is for wants and intentions, thought
## for noticing and wondering, shout for fright and temper. The original
## glyphs stay valid, so every existing caller gets a bubble.
const MOODS := {
	"?": ["thought","question"],
	"!": ["speech","exclaim"],
	"!!": ["shout","steam"],
	"…": ["thought","dots"],
	"Home": ["speech","nest"],
	"home": ["speech","nest"],
	"fish": ["speech","fish"],
	"stone": ["speech","stone"],
	"stick": ["speech","stick"],
	"tree": ["speech","tree"],
	"heart": ["speech","heart"],
	"rainbow": ["thought","rainbow"],
	"meteor": ["thought","star"],
	"rain": ["thought","rain"],
	"snow": ["thought","snow"],
	"bolt": ["shout","bolt"],
	"fire_fright": ["shout","fire"],
	"fire_watch": ["thought","fire"],
	"fire_warm": ["speech","fire"],
}
## Where each bubble's tail ends, and the centre of its icon area.
const TAILS := {"speech":Vector2(44,192),"thought":Vector2(34,192),"shout":Vector2(40,194)}
const CONTENT := Vector2(128,88)
const EXTENT := Rect2(0,0,240,200)
const POP_IN := 0.34
const POP_OUT := 0.24

## Seconds a reaction stays up, including its pop in and out.
var hold := 2.4
## True while the scene is paused: the bubble holds its pose and timer.
var frozen := false
## Screen height of the bubble as a share of the viewport, before DPI limits.
var screen_share := 0.12
## The symbol currently or most recently shown.
var text: String:
	get: return _symbol

var _layer := CanvasLayer.new()
var _root := Node2D.new()
var _pop := Node2D.new()
var _bubble := Sprite2D.new()
var _icon := Node2D.new()
var _parts := {}
var _paint := ShaderMaterial.new()
var _symbol := ""
var _shape := ""
var _icon_name := ""
var _age := 0.0
var _life := 0.0

func _ready() -> void:
	_paint.shader = PAINT
	add_child(_layer)
	_layer.layer = 1
	_layer.add_child(_root)
	_root.add_child(_pop)
	_pop.add_child(_bubble)
	_pop.add_child(_icon)
	_bubble.centered = false
	_bubble.scale = Vector2.ONE*0.5
	_bubble.material = _paint
	_layer.visible = false

## Show a reaction. An empty symbol clears it; repeating the one on screen
## keeps it up without popping it again.
func show_reaction(symbol: String, duration := -1.0) -> void:
	if symbol.is_empty():
		_life = 0.0
		_layer.visible = false
		return
	var life := hold if duration < 0.0 else duration
	if symbol == _symbol and showing():
		_life = maxf(_life,life)
		return
	var mood: Array = MOODS.get(symbol,["speech","exclaim"])
	_symbol = symbol
	_age = 0.0
	_life = life
	if mood[0] != _shape:
		_shape = mood[0]
		_bubble.texture = ART["bubble_"+_shape]
		_bubble.offset = -TAILS[_shape]*2.0
	if mood[1] != _icon_name:
		_build(mood[1])
	_icon.position = CONTENT-TAILS[_shape]
	_place()

func showing() -> bool:
	return _life > 0.0

func icon() -> String:
	return _icon_name if showing() else ""

func shape() -> String:
	return _shape if showing() else ""

func _process(delta: float) -> void:
	if not showing():
		_layer.visible = false
		return
	if not frozen:
		_age += delta
		_life -= delta
		if _life <= 0.0:
			_layer.visible = false
			return
	_place()

## Follow the head on screen and play the pop, the idle float and the icon.
func _place() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_visible_in_tree() or camera.is_position_behind(global_position):
		_layer.visible = false
		return
	_layer.visible = true
	var view := get_viewport().get_visible_rect().size
	var size := clampf(view.y*screen_share,72.0,260.0)/EXTENT.size.y
	_root.scale = Vector2.ONE*size
	var tail: Vector2 = TAILS[_shape]
	var point := camera.unproject_position(global_position)
	# Keep the whole bubble on screen; the tail may then leave the head a little.
	point.x = clampf(point.x,(tail.x+6.0)*size,view.x-(EXTENT.size.x-tail.x+6.0)*size)
	point.y = clampf(point.y,(tail.y+6.0)*size,view.y-(EXTENT.size.y-tail.y+6.0)*size)
	_root.position = point
	var grow := _back_out(clampf(_age/POP_IN,0.0,1.0))
	var leave := smoothstep(0.0,POP_OUT,_life)
	_pop.scale = Vector2.ONE*grow*lerpf(0.7,1.0,leave)
	_pop.modulate.a = leave
	_pop.rotation = sin(_age*2.1)*0.025
	_pop.position.y = sin(_age*2.9)*3.0
	_animate(_age)

static func _back_out(x: float) -> float:
	var t := x-1.0
	return 1.0+2.2*t*t*t+1.2*t*t

# ------------------------------------------------------------------- icons

func _build(icon_name: String) -> void:
	_icon_name = icon_name
	for child in _icon.get_children():
		_icon.remove_child(child)
		child.queue_free()
	_parts.clear()
	match icon_name:
		"dots":
			for i in range(3): _part("dot%d" % i,"dot",Vector2(-34+34*i,6),1.1)
		"steam":
			_part("left","exclaim",Vector2(-20,6),0.62,Vector2(0.5,0.9))
			_part("right","exclaim",Vector2(20,4),0.62,Vector2(0.5,0.9))
			for i in range(3): _part("puff%d" % i,"puff",Vector2.ZERO,0.7)
		"rain":
			for i in range(3): _part("drop%d" % i,"drop",Vector2.ZERO,0.9)
			_part("cloud","cloud",Vector2(0,-8),0.72)
		"tree":
			_part("main","tree",Vector2.ZERO,0.72,Vector2(0.5,0.94))
			for i in range(2): _part("leaf%d" % i,"leaf",Vector2.ZERO,0.8)
		"rainbow":
			_part("main","rainbow",Vector2(0,6),0.8)
			var sweep := _paint.duplicate() as ShaderMaterial
			_parts.main.get_child(0).material = sweep
		"fire": _part("main","fire",Vector2(0,-2),0.72,Vector2(0.5,0.84))
		"stick": _part("main","stick",Vector2.ZERO,0.72,Vector2(0.2,0.8))
		"star": _part("main","star",Vector2.ZERO,0.72)
		"snow": _part("main","snowflake",Vector2.ZERO,0.66)
		_: _part("main",icon_name,Vector2.ZERO,0.72,Vector2(0.5,0.62))

## A part is a pivot node at `pivot` (fraction of the art) whose visual centre
## sits at `at`; animations move, turn and scale the pivot only.
func _part(part: String, art: String, at: Vector2, size: float, pivot := Vector2(0.5,0.5)) -> void:
	var texture: Texture2D = ART[art]
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE*0.5
	sprite.offset = -pivot*texture.get_size()
	sprite.material = _paint
	var holder := Node2D.new()
	holder.add_child(sprite)
	holder.set_meta("rest",at+(pivot-Vector2(0.5,0.5))*texture.get_size()*0.5*size)
	holder.set_meta("size",size)
	_icon.add_child(holder)
	_parts[part] = holder

func _pose(part: String, offset := Vector2.ZERO, turn := 0.0, stretch := Vector2.ONE, alpha := 1.0) -> void:
	var holder: Node2D = _parts[part]
	holder.position = holder.get_meta("rest")+offset
	holder.rotation = turn
	holder.scale = stretch*float(holder.get_meta("size"))
	holder.modulate.a = alpha

func _animate(t: float) -> void:
	var urgent := 1.6 if _shape == "shout" else 1.0
	match _icon_name:
		"question":
			_pose("main",Vector2.ZERO,sin(t*2.6)*0.22)
		"exclaim":
			var ring := exp(-t*4.0)*sin(t*22.0)
			_pose("main",Vector2(0,-absf(sin(t*5.0))*6.0*exp(-t*1.5)),ring*0.08,Vector2.ONE*(1.0+ring*0.12))
		"dots":
			for i in range(3):
				_pose("dot%d" % i,Vector2(0,-maxf(0.0,sin(t*5.0-i*0.8))*9.0),0.0,Vector2.ONE,clampf((t-i*0.2)/0.15,0.0,1.0))
		"steam":
			var shake := sin(t*31.0)*0.09
			_pose("left",Vector2.ZERO,-0.18+shake)
			_pose("right",Vector2.ZERO,0.18-shake)
			for i in range(3):
				var rise := fmod(t*0.9+i/3.0,1.0)
				_pose("puff%d" % i,Vector2(-46+46*i+sin(rise*6.0+i)*4.0,-26-rise*34.0),0.0,Vector2.ONE*(0.5+rise*0.6),sin(rise*PI))
		"fish":
			var flop := sin(t*7.0)*(0.6+0.4*absf(sin(t*1.3)))
			_pose("main",Vector2(0,-absf(sin(t*3.5))*8.0),flop*0.28,Vector2(1.0+sin(t*14.0)*0.04,1.0))
		"stone":
			var bounce := absf(sin(t*4.0))
			var squash := (1.0-bounce)*(1.0-bounce)*0.14
			_pose("main",Vector2(0,-bounce*10.0),0.0,Vector2(1.0+squash,1.0-squash))
		"stick":
			_pose("main",Vector2.ZERO,sin(t*6.0)*0.3)
		"tree":
			var burst := pow(absf(sin(t*1.7)),2.0)
			_pose("main",Vector2.ZERO,sin(t*11.0)*0.12*burst,Vector2(1.0,1.0+burst*0.03))
			for i in range(2):
				var fall := fmod(t*0.55+i*0.5,1.0)
				_pose("leaf%d" % i,Vector2(-26+44*i+sin(fall*7.0+i)*10.0,-22+fall*58.0),fall*6.0-i,Vector2.ONE,sin(fall*PI))
		"rainbow":
			_pose("main",Vector2.ZERO,0.0,Vector2.ONE*(1.0+sin(t*2.0)*0.02))
			_parts.main.get_child(0).material.set_shader_parameter("reveal",smoothstep(0.08,1.1,t))
		"star":
			var streak := fmod(t*0.7,1.0)
			var glide := Vector2(-22,18).lerp(Vector2(10,-10),smoothstep(0.0,0.6,streak))
			_pose("main",glide,0.0,Vector2.ONE*(1.0+sin(t*9.0)*0.08),1.0-smoothstep(0.75,1.0,streak)*0.6)
		"rain":
			_pose("cloud",Vector2(0,sin(t*2.0)*2.0))
			for i in range(3):
				var fall := fmod(t*1.3+i*0.37,1.0)
				_pose("drop%d" % i,Vector2(-24+24*i,6+fall*30.0),0.0,Vector2.ONE,sin(fall*PI))
		"snow":
			_pose("main",Vector2(sin(t*1.4)*4.0,sin(t*2.2)*3.0),t*0.8)
		"heart":
			var beat := pow(maxf(0.0,sin(t*6.5)),6.0)+0.6*pow(maxf(0.0,sin(t*6.5-0.9)),6.0)
			_pose("main",Vector2.ZERO,0.0,Vector2.ONE*(1.0+beat*0.14))
		"bolt":
			var flash := fmod(t,0.9) < 0.1
			_pose("main",Vector2(sin(t*40.0)*2.0,0),0.0,Vector2.ONE*(1.12 if flash else 1.0))
			_parts.main.modulate = Color(1.5,1.5,1.4,1.0) if flash else Color.WHITE
		"fire":
			var f := t*urgent
			_pose("main",Vector2.ZERO,sin(f*5.3)*0.06,Vector2(1.0+sin(f*13.0)*0.04,1.0+sin(f*9.7)*0.07+sin(f*17.0)*0.03))
			_parts.main.skew = sin(f*5.3)*0.08
		"nest":
			_pose("main",Vector2(0,sin(t*2.0)*2.0),sin(t*1.6)*0.05)
		_:
			_pose("main",Vector2(0,sin(t*2.4)*3.0),sin(t*1.8)*0.06)
