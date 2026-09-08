extends Control
## A software cursor: the target never lags; only the glove eases between poses.
## Owns hiding the system pointer only while visible, and restores it on exit.
const CREAM := Color("f7f0df")
const INK := Color("392e38")
const GOLD := Color("d8b26f")
var grip := 0.0
var reaction := 0.0
var accepted := false
var clock := 0.0
var _owns_pointer := false

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 z_index = 100
 visible = false

func show_at(point: Vector2, carrying: bool, delta: float) -> void:
 visible = true
 position = point
 if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
  Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
  _owns_pointer = true
 advance(carrying,delta)

func advance(carrying: bool, delta: float) -> void:
 clock += delta
 reaction = maxf(0.0,reaction-delta)
 var target := 0.62 if carrying else 0.0
 if reaction > 0.18: target = 1.0 if accepted else 0.0
 grip = lerpf(grip,target,1.0-exp(-delta*20.0))
 queue_redraw()

func take() -> void:
 reaction = 0.0

func release(placed: bool) -> void:
 accepted = placed
 reaction = 0.38

func hide_pointer() -> void:
 visible = false
 if _owns_pointer:
  if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
  _owns_pointer = false

func _exit_tree() -> void:
 hide_pointer()

func _stroke(points: PackedVector2Array, width: float, color: Color) -> void:
 for i in range(points.size()-1): draw_line(points[i],points[i+1],color,width,true)
 for point in points: draw_circle(point,width*0.5,color,true,-1,true)

func _draw() -> void:
 # Tiny hollow target marks the exact click; the palm stays clear of it.
 draw_circle(Vector2.ZERO,3.1,INK,true,-1,true)
 draw_circle(Vector2.ZERO,1.5,GOLD,true,-1,true)
 if reaction > 0.0 and accepted:
  var progress := 1.0-reaction/0.38
  draw_arc(Vector2.ZERO,5.0+progress*13.0,0,TAU,40,Color(0.85,0.70,0.44,(1.0-progress)*0.65),1.2,true)
 var bounce := -sin((1.0-reaction/0.38)*PI)*3.0 if reaction > 0.0 else sin(clock*2.5)*0.5
 draw_set_transform(Vector2(15,15+bounce),-0.20+grip*0.13)
 # Four soft fingers curl toward the palm, with a separate thumb.
 var fingers: Array[PackedVector2Array] = []
 for i in range(4):
  var x := -8.0+i*5.0
  var length := [11.0,15.0,13.0,8.0][i] as float
  fingers.append(PackedVector2Array([Vector2(x,0),Vector2(x,-length*(1.0-grip*0.72)),Vector2(x+grip*2.5,-length*(1.0-grip*0.72)+grip*3)]))
 var thumb := PackedVector2Array([Vector2(-9,7),Vector2(-15+grip*3,1),Vector2(-15+grip*8,-4+grip*6)])
 for finger in fingers: _stroke(finger,6.3,INK)
 _stroke(thumb,7.0,INK)
 draw_circle(Vector2(0,4),12,INK,true,-1,true)
 for finger in fingers: _stroke(finger,4.2,CREAM)
 draw_circle(Vector2(0,4),10.2,CREAM,true,-1,true)
 _stroke(thumb,4.8,CREAM)
 # Two seam marks keep the glove readable at game scale.
 draw_line(Vector2(-3,3),Vector2(-3,7),Color("d4c6af"),1.0,true)
 draw_line(Vector2(2,3),Vector2(2,7),Color("d4c6af"),1.0,true)
 _stroke(PackedVector2Array([Vector2(-7,14),Vector2(7,14)]),8,INK)
 _stroke(PackedVector2Array([Vector2(-7,14),Vector2(7,14)]),5,Color("725966"))
 draw_line(Vector2(-7,11),Vector2(7,11),GOLD,1.5,true)
 draw_set_transform(Vector2.ZERO)
