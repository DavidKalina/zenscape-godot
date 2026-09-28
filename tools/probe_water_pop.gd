extends SceneTree
## Headless check of the water ball's release (scripts/water_ball.gd): let go,
## it is tossed straight up, pops at the top on its beat (POP_SECONDS, when
## the God Hand's finger pokes it), and falls straight down onto its mark.
##   Godot --headless --path . --script res://tools/probe_water_pop.gd

const Ball := preload("res://scripts/water_ball.gd")
const STEP := 1.0/60.0

var failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var plate := Node3D.new()
	root.add_child(plate)
	var ball: Node3D = Ball.new()
	plate.add_child(ball)
	ball.set_process(false)
	ball.ground_at = func(_p: Vector2) -> Variant: return 0.5
	var landed := []
	ball.landed.connect(func(point: Vector2, volume: float, _fish: Array) -> void: landed.append([point,volume]))
	ball.condense(Vector3(1.0,0.5,-2.0),null,7)
	for i in range(90):
		ball.hold(Vector3(1.0+i*0.01,0.5,-2.0),0.6+i*0.02)
		ball._process(STEP)
	var mark: Vector3 = ball.mark()
	var top: float = ball.position.y
	ball.poke = Vector3(0.0,0.0,1.0)
	ball.release()
	_check(ball.state == "tossed","let go, it is tossed")
	_check(absf(ball.pop_in()-Ball.POP_SECONDS) < 0.001,"and pops in %.3f s" % ball.pop_in())
	var t := 0.0
	var highest := top
	while ball.state == "tossed" and t < 2.0:
		ball._process(STEP)
		t += STEP
		highest = maxf(highest,ball.position.y)
	_check(absf(t-Ball.POP_SECONDS) < STEP*1.5,"it pops on its beat (%.3f s)" % t)
	_check(absf(highest-top-Ball.TOSS) < 0.02,"at the top of its toss (%.2f m up)" % (highest-top))
	_check(ball.state == "falling","then falls")
	var sprayed := 0
	for bead: Dictionary in ball._beads:
		if bead.kind == "drip" and Vector3(bead.v).dot(ball.poke) > 0.0: sprayed += 1
	_check(sprayed > 5,"its skin bursts out round where it was poked (%d droplets that way)" % sprayed)
	var stretched := 0.0
	while ball.state == "falling" and t < 4.0:
		ball._process(STEP)
		t += STEP
		stretched = maxf(stretched,ball._ball.basis.y.length()/ball.radius)
	_check(stretched > 1.3,"the loose water stretches as it falls (%.2f)" % stretched)
	_check(landed.size() == 1,"and lands")
	if landed.size() == 1:
		var at: Vector2 = landed[0][0]
		_check(at.distance_to(Vector2(mark.x,mark.z)) < 0.001,"on its mark (%.4f m off)" % at.distance_to(Vector2(mark.x,mark.z)))
	print("  released to landed: %.2f s" % t)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
