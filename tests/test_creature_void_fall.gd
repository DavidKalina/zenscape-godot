extends SceneTree
## Falling and recovery do not depend on a GPU, terrain renderer or UI timing.
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.setup("res://assets/models/zenscape-bigfoot-interactions.glb")
	actor.reset_at(Vector3(0,1,0))
	var bank := {"position":Vector3(-3,0,0),"landings":0}
	actor.landed.connect(func() -> void: bank.landings += 1)
	actor.begin_void_fall(bank.position,func(_near: Vector3) -> Variant: return bank.position)
	check(not actor.can_roam(),"Routine movement cannot take over a fall")
	for i in range(30): actor.advance(1.0/60.0)
	check(actor.position.y<0.0 and actor.state==CreatureActor.State.FALLING,"Gravity moves feet below the missing surface over multiple frames")
	var feet := actor.position
	actor.advance(0.0)
	check(actor.position==feet,"A stopped simulation does not advance gravity")
	# The recovery provider can change while he is airborne after a terrain edit.
	bank.position = Vector3(3,0.7,1)
	for i in range(200): actor.advance(1.0/60.0)
	check(actor.position==bank.position,"Recovery revalidates the currently safe bank")
	check(actor.state==CreatureActor.State.IDLE and bank.landings==1,"Recovery completes its landing animation and emits one landing")
	actor.begin_void_fall(Vector3(-3,0,0))
	check(actor.pick_up(),"The player can rescue a falling Bigfoot")
	var held := actor.position
	for i in range(200): actor.advance(1.0/60.0)
	check(actor.is_held() and actor.position==held,"Rescuing cancels the pending gravity fall")
	actor.free()
	print("CREATURE VOID FALL failures=",failures)
	quit(1 if failures else 0)
