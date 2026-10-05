extends CanvasLayer
## A real build veil, without invented percentage progress: a line of text,
## and under it, while something real is counted (the sky's mountains:
## scripts/sky_reveal.gd), a faint line that glows out as it is made
## (`progress`). Taken away with a gentle fade (`fade_out`).
const GLOW := Color("e2d0aa")
## The progress line's width (px) and its fill, 0 to 1; hidden below 0.
const LINE := 220.0
var _label := Label.new()
var _line := Control.new()
var _backdrop := ColorRect.new()
var _elapsed := 0.0
var _progress := -1.0
var _shown := -1.0
## True once fading out (`fade_out`).
var fading := false

func _ready() -> void:
	layer = 100
	_backdrop.color = Color("0b0e12")
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font",preload("res://assets/fonts/newsreader-latin.woff2"))
	_label.add_theme_font_size_override("font_size",24)
	_label.add_theme_color_override("font_color",GLOW)
	_backdrop.add_child(_line)
	_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.draw.connect(_draw_line)
	stage("A wilderness is taking shape")

func stage(text: String) -> void:
	_label.text = text

## How much of what is counted is made, 0 to 1 (below 0: no line).
func progress(share: float) -> void:
	_progress = share

func _process(delta: float) -> void:
	_elapsed += delta
	_label.modulate.a = 0.55+0.35*(0.5+0.5*sin(_elapsed*TAU/3.5))
	# The line eases toward what is made, so it grows smoothly.
	if _progress < 0.0: _shown = -1.0
	elif _shown < 0.0: _shown = _progress
	else: _shown = lerpf(_shown,_progress,clampf(delta*3.0,0.0,1.0))
	_line.queue_redraw()

## A hairline across, faint, and over it the share made, glowing softly
## from the middle out, below the text.
func _draw_line() -> void:
	if _shown < 0.0: return
	var size := _line.size
	var y := size.y*0.5+30.0
	var middle := size.x*0.5
	var half := LINE*0.5
	_line.draw_line(Vector2(middle-half,y),Vector2(middle+half,y),Color(GLOW,0.12),1.0,true)
	var reach := half*clampf(_shown,0.0,1.0)
	if reach <= 0.5: return
	var breathe := 0.75+0.25*(0.5+0.5*sin(_elapsed*TAU/3.5))
	_line.draw_line(Vector2(middle-reach,y),Vector2(middle+reach,y),Color(GLOW,0.18*breathe),5.0,true)
	_line.draw_line(Vector2(middle-reach,y),Vector2(middle+reach,y),Color(GLOW,0.7*breathe),1.0,true)

## Fades the veil away over `seconds`, then frees it.
func fade_out(seconds := 1.2) -> void:
	if fading: return
	fading = true
	var tween := create_tween()
	tween.tween_property(_backdrop,"modulate:a",0.0,seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)
