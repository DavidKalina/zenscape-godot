extends Node
## Frame pacing for a screen that shows each picture as it is done (G-Sync,
## FreeSync): every frame's script work is padded to the same length, so the
## pictures are handed over at an even beat.
##
##     add_child(FramePace.new(10.0))     # --pace=10
##
## A frame cap makes the frames START evenly, but the script work in a frame
## swings (6 ms one frame, 9 the next), so the pictures were handed to the GPU
## 14 to 19 ms apart under a 60 cap: a fine judder on such a screen, though
## every frame was on time. This node runs last in the frame and waits until
## `pad_ms` after the frame began; a frame whose work already took longer goes
## straight through. The price is that much latency on the shorter frames.
##
## The wait is the `pace` part of the frame log (scripts/frame_log.gd).

var pad_ms := 10.0
var _from := 0

func _init(ms := 10.0) -> void:
	pad_ms = ms
	name = "FramePace"
	process_priority = 1000000
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	get_tree().process_frame.connect(_began)

## The frame's script work begins (the tree's process_frame, before any _process).
func _began() -> void:
	_from = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if _from == 0: return
	var until := _from+int(pad_ms*1000.0)
	var left := until-Time.get_ticks_usec()
	# Sleep most of it, then spin the last stretch: a sleep is only good to
	# about a millisecond.
	if left > 2000: OS.delay_usec(left-1500)
	while Time.get_ticks_usec() < until: pass
	if FrameLog.on: FrameLog.add(&"pace",maxf(float(left),0.0)/1000.0)
