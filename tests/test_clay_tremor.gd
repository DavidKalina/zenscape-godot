extends SceneTree
## The land shudders under the shaping tools (scripts/clay_tremor.gd): a
## Mountain pull kicks the tremor in lurches by how fast it rises and a hand
## held still lets it settle; the Wire's cut is lighter; the gentle tools never
## shake. First on a stand-in clay (exact), then on the real clay in the
## Fidelity world, where the old painted-stroke rumble (scripts/
## stroke_feedback.gd) must leave the clay's strokes alone. Only the trauma is
## checked; how the shake looks on screen needs a rendered run.
##
##   godot --headless --path . --script tests/test_clay_tremor.gd

const ClayTremor = preload("res://scripts/clay_tremor.gd")
const Tremor = preload("res://scripts/reference_tremor.gd")
const DT := 1.0/60.0

## A stand-in for LandClay: the fields ClayTremor reads.
class FakeClay extends Node:
	enum State { IDLE, PENDING, DRAG, HOLD, RUN, PAINT }
	var state := State.IDLE
	var tool_id := "hand"
	var tool: Object
	var scene: Variant = null

class FakeTool extends RefCounted:
	var lift := 0.0
	var share := 1.0
	var length := 0.0
	var running := false
	func busy() -> bool: return running
	func cut_share() -> float: return share
	func cut_length() -> float: return length

var failures := 0
var biggest := 0.0

func check(ok: bool, what: String) -> void:
	if ok: print("PASS: ",what)
	else:
		failures += 1
		push_error(what)
		print("FAIL: ",what)

func _initialize() -> void:
	_run.call_deferred()

## `seconds` of frames: the clay's tremor reads, then the tremor decays.
func tick(shudder: Node, tremor: RefCounted, seconds: float, step := Callable()) -> void:
	for i in range(roundi(seconds/DT)):
		if step.is_valid(): step.call()
		var before: float = tremor.trauma
		shudder._process(DT)
		biggest = maxf(biggest,float(tremor.trauma)-before)
		tremor.advance(DT,false)

## A fresh stand-in clay holding `id`, its tremor and the clay's shudder.
func rig(id: String) -> Array:
	var clay := FakeClay.new()
	root.add_child(clay)
	clay.tool_id = id
	clay.tool = FakeTool.new()
	var tremor := Tremor.new()
	var shudder: Node = ClayTremor.new()
	shudder.setup(clay,tremor)
	# Its child, so it goes with the clay; never processed by the tree (the
	# clay is not), only by `tick`.
	clay.add_child(shudder)
	shudder.set_process(false)
	return [clay,tremor,shudder]

func _run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("clay tremor test timed out"); quit(2))
	_stand_in()
	await _real_clay()
	# Let the audio server let go of the freed scene's playbacks.
	await create_timer(0.5).timeout
	print("Clay tremor: ",failures," failures")
	quit(1 if failures else 0)

func _stand_in() -> void:
	# A Mountain pulled up at 6 m/s for a second.
	var parts := rig("mountain")
	var clay: FakeClay = parts[0]
	var tremor: RefCounted = parts[1]
	var shudder: Node = parts[2]
	var tool: FakeTool = clay.tool
	clay.state = FakeClay.State.HOLD
	biggest = 0.0
	tick(shudder,tremor,1.0,func() -> void: tool.lift += 6.0*DT)
	var pulled: float = tremor.trauma
	check(pulled > 0.4,"a fast Mountain pull builds trauma (%.2f)" % pulled)
	check(pulled <= ClayTremor.CAP+0.001,"and never past the clay's cap (%.2f)" % pulled)
	check(shudder.kicks >= 8,"in lurches, not one push (%d kicks)" % shudder.kicks)
	check(biggest < 0.2,"every kick stays under the resident's stumble (%.3f)" % biggest)
	# Held still: no new kicks, and it settles.
	var kicks: int = shudder.kicks
	tick(shudder,tremor,1.5)
	check(shudder.kicks == kicks,"a hand held still gives no kicks")
	check(tremor.trauma < 0.001,"and the shudder dies away (%.3f)" % tremor.trauma)
	# Slowly: a few small lurches, far less than a fast pull.
	tick(shudder,tremor,1.0,func() -> void: tool.lift += 0.8*DT)
	var slow: float = tremor.trauma
	check(shudder.kicks > kicks and slow < pulled*0.4,"a slow pull is a few small lurches (%.2f vs %.2f)" % [slow,pulled])
	# Pulled down: it shakes, lighter than up.
	tick(shudder,tremor,1.5)
	tool.lift = 0.0
	tick(shudder,tremor,0.05)
	tremor.trauma = 0.0
	tick(shudder,tremor,0.5,func() -> void: tool.lift -= 6.0*DT)
	var sank: float = tremor.trauma
	check(sank > 0.05,"a Mountain pulled down shakes too (%.2f)" % sank)
	# Off: no shudder at all.
	tick(shudder,tremor,1.5)
	shudder.amount = 0.0
	tick(shudder,tremor,1.0,func() -> void: tool.lift += 6.0*DT)
	check(tremor.trauma == 0.0,"amount 0 turns the shudder off")
	shudder.amount = 1.0
	clay.state = FakeClay.State.IDLE
	tick(shudder,tremor,0.1)
	clay.queue_free()

	# The Wire's 16 m cut running at its CUT_SPEED: lighter than a pull, and
	# grittier (more kicks for its travel).
	parts = rig("wire")
	clay = parts[0]
	tremor = parts[1]
	shudder = parts[2]
	tool = clay.tool
	clay.state = FakeClay.State.RUN
	tool.running = true
	tool.length = 16.0
	tool.share = 0.0
	biggest = 0.0
	tick(shudder,tremor,1.0,func() -> void: tool.share = minf(tool.share+DT*0.5,1.0))
	var cut: float = tremor.trauma
	check(cut > 0.1,"the Wire's cut shudders (%.2f)" % cut)
	check(cut < pulled,"lighter than a Mountain pull (%.2f vs %.2f)" % [cut,pulled])
	check(shudder.kicks*ClayTremor.LURCH > 8.0,"in many small kicks (%d)" % shudder.kicks)
	check(biggest < 0.12,"each smaller than a pull's (%.3f)" % biggest)
	tool.running = false
	tick(shudder,tremor,1.5)
	check(tremor.trauma < 0.001,"and settles once the cut has run")
	clay.queue_free()

	# The gentle tools never shake, however much they are worked.
	for id in ["brush","feather","paddle","hills","bowl","sculpt","can","hammer"]:
		parts = rig(id)
		clay = parts[0]
		tremor = parts[1]
		shudder = parts[2]
		tool = clay.tool
		for state in [FakeClay.State.PAINT,FakeClay.State.DRAG,FakeClay.State.HOLD]:
			clay.state = state
			tick(shudder,tremor,0.5,func() -> void: tool.lift += 6.0*DT)
		check(tremor.trauma == 0.0 and shudder.kicks == 0,"the %s never shakes" % id)
		clay.queue_free()

## The real clay in the Fidelity world, driven through its press/pull/release
## seam on real frames.
func _real_clay() -> void:
	root.size = Vector2i(1440,900)
	var scene: Node3D = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(10): await process_frame
	var clay: Node = scene.get("land_clay")
	var shudder: Node = scene.get("clay_tremor")
	check(clay != null and shudder != null,"the Fidelity world builds the clay and its tremor")
	if clay == null or shudder == null:
		scene.free()
		return
	check(shudder.clay == clay and shudder.tremor == scene._tremor,"the clay's tremor kicks the scene's tremor")
	scene._paused = false
	scene.resident_enabled = false
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_active(true)
	for i in range(5): await process_frame
	# A screen spot on the land, nearest the middle of the view.
	var spot := Vector2.INF
	var view := Vector2(root.size)
	for r in range(0,400,20):
		for a in range(8):
			var at := view*0.5+Vector2.from_angle(a*TAU/8.0)*r
			if editor.pick(at) != null:
				spot = at
				break
		if spot != Vector2.INF: break
	check(spot != Vector2.INF,"the view has land to press on")
	if spot == Vector2.INF:
		scene.free()
		return
	# The gentle tools, worked hard: a long fast drag back and forth.
	for id in ["brush","paddle","hills"]:
		clay.set_tool(id)
		scene._tremor.trauma = 0.0
		var most := 0.0
		check(clay.press(spot),"the %s takes the press" % id)
		for k in range(60):
			clay.pull(spot+Vector2(sin(k*0.3)*120.0,cos(k*0.2)*40.0))
			await process_frame
			most = maxf(most,float(scene._tremor.trauma))
		clay.release()
		for k in range(5): await process_frame
		check(most < 0.02,"the %s does not shake the camera (%.3f)" % [id,most])
	# The Mountain pulled straight up, then held.
	for k in range(5): await process_frame
	clay.set_tool("mountain")
	scene._tremor.trauma = 0.0
	var kicks: int = shudder.kicks
	check(clay.press(spot),"the Mountain takes the press")
	var peak := 0.0
	for k in range(40):
		clay.pull(spot-Vector2(0.0,8.0*(k+1)))
		await process_frame
		peak = maxf(peak,float(scene._tremor.trauma))
	check(shudder.kicks > kicks+3 and peak > 0.1,"a real Mountain pull shudders (%d kicks, peak %.2f, lift %.1f m)" % [shudder.kicks-kicks,peak,float(clay.lift)])
	kicks = shudder.kicks
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec()-settle < 2500: await process_frame
	check(shudder.kicks <= kicks+2,"holding still stops the lurches (%d after)" % (shudder.kicks-kicks))
	check(scene._tremor.trauma < 0.05,"and the shudder settles while held (%.3f)" % scene._tremor.trauma)
	clay.release()
	for k in range(5): await process_frame
	# Paused loops (the clay's sound) hold their playbacks past a free.
	for player in scene.find_children("*","AudioStreamPlayer3D",true,false): player.stop()
	for k in range(3): await process_frame
	scene.free()
