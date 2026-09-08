extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func tick(actor: CreatureActor, seconds: float) -> void:
	for i in range(int(seconds*60)): actor.advance(1.0/60.0)
func _run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-routine.glb")
	actor.set_process(false)
	var tremor = preload("res://scripts/reference_tremor.gd").new()
	tremor.shaken.connect(actor.queue_tremor)
	tremor.add(0.1)
	tick(actor,0.1)
	check(actor.state!=CreatureActor.State.STUMBLING,"Tiny tremors do not constantly interrupt Bigfoot")
	tremor.add(0.7)
	check(actor.state!=CreatureActor.State.STUMBLING,"Reaction waits for the actor clock, preserving pause")
	actor.advance(1.0/60.0)
	check(actor.state==CreatureActor.State.STUMBLING and not actor.can_roam(),"Ground tremor interrupts locomotion with a stumble")
	var location := actor.position
	tick(actor,0.35)
	check(actor.position==location,"Balance reaction cannot push the feet off safe ground")
	var strong_duration := actor._stumble_duration
	tick(actor,4.0)
	check(actor.can_roam(),"Bigfoot regains balance and resumes normal behavior")
	actor.queue_tremor(0.3)
	actor.advance(1.0/60.0)
	check(actor._stumble_duration<strong_duration,"Smaller tremors produce shorter recoveries")
	actor.pick_up()
	tremor.add(1.0)
	tick(actor,0.3)
	check(actor.state==CreatureActor.State.HELD,"A tremor cannot knock him out of the user's hand")
	actor.reset_at(Vector3.ZERO)
	actor.perform_action("Sleep",20.0)
	var events: Array = []
	actor.action_finished.connect(func(clip: String,cancelled: bool) -> void: events.append([clip,cancelled]))
	tremor.add(0.7)
	actor.advance(1.0/60.0)
	check(events==[["Sleep",true]],"Tremor interrupts sleep exactly once")
	check(actor.hand_targets.is_empty(),"Interrupted interactions release hand constraints")
	tick(actor,4.0)
	tremor.enabled = false
	tremor.add(1.0)
	actor.advance(1.0/60.0)
	check(actor.state!=CreatureActor.State.STUMBLING,"Disabled tremors do not affect the actor")
	print("Creature tremor: ",failures," failures")
	actor.free()
	quit(1 if failures else 0)
