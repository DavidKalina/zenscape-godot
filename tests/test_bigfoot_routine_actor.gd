extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-routine.glb")
	actor.set_process(false)
	var events: Array = []
	actor.action_finished.connect(func(clip: String,cancelled: bool) -> void: events.append([clip,cancelled]))
	for clip in ["SitDown","Sit","StandUp","Sleep","StoneThrow","TreeShake","FishCatch"]:
		check(actor.perform_action(clip,0.2),"Can perform "+clip)
		check(not actor.can_roam(),"An action owns locomotion")
		for i in range(15): actor.advance(1.0/60.0)
		check(actor.can_roam(),"Returns to normal movement after "+clip)
		check(events[-1] == [clip,false],"Completion event is delivered once")
	check(events.size()==7,"Exactly one completion per action")
	actor.perform_action("Sleep",30.0)
	actor.pick_up()
	check(actor.is_held(),"Carrying interrupts sleep")
	check(events[-1] == ["Sleep",true],"Interrupted action reports cancellation")
	actor.reset_at(Vector3.ZERO)
	check(not actor.perform_action("Missing"),"Unknown action is rejected")
	print("BIGFOOT ROUTINE ACTOR: failures=",failures)
	actor.free()
	quit(1 if failures else 0)
