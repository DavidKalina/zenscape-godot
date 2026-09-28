extends "res://scripts/creation_brush.gd"
## The wind tool's place in the brush list (scripts/genesis_canvas.gd
## `BRUSHES`). It paints nothing: NativeChunkEditor hands its presses to the
## gust (scripts/wind_gust.gd, docs/scenic/wind-gust.md). Size ([ ]) is the
## lane's half width in metres; strength (Shift [ ]) scales how hard a swipe
## blows.

func _init() -> void:
	brush_id = "wind"
	radius = 3.0
	radius_range = Vector2(1.5,5.0)
	strength = 1.0
	strength_range = Vector2(0.5,1.5)
