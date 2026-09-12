extends SceneTree
var failures := 0
var scene: Node
var play: Node
var rock: RigidBody3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures += 1
func ticks(count: int) -> void:
	for i in range(count): await physics_frame
func offer() -> void:
	play.cancel()
	play.exchange._cooldown = 0.0
	scene.creature.reset_at(Vector3.ZERO)
	scene.creature.global_rotation.y = 0.0
	rock.restore(Transform3D(Basis.IDENTITY,Vector3(0,0.3,2)))
	play.loose_props.begin_grab(rock,scene.camera.unproject_position(rock.global_position))
	# Place the cursor's target at a known reachable point; all animation,
	# contact and ownership changes run through the real scene frame loop.
	play.loose_props._target = Vector3(0,1.9,0.85)
	rock.global_position = play.loose_props._target
func wait_for_inspection() -> bool:
	for i in range(240):
		await physics_frame
		if play.exchange.phase == "inspect": return true
	print("exchange phase=",play.exchange.phase," cancel=",play.exchange.last_cancel," steady=",play.exchange._steady," palm=",scene.creature.hand_position()," target=",rock.global_position)
	return false
func capture(label: String) -> void:
	if "--capture-exchange" not in OS.get_cmdline_user_args(): return
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.global_position = scene.creature.global_position+Vector3(3.5,2.8,4.5)
	camera.look_at(scene.creature.global_position+Vector3.UP*1.4)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/bigfoot-exchange-"+label+".png")
	camera.queue_free()
	scene.camera.make_current()

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,960)
	var cozy := "--cozy-exchange" in OS.get_cmdline_user_args()
	scene = load("res://studies/cozy_worlds.tscn" if cozy else "res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/object-exchange-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	if cozy: scene.places_path = scene.library_path+"/places.json"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	if cozy:
		while not scene.places_ready: await process_frame
	scene.set_process_input(false)
	scene.new_diorama()
	var id: int = scene._chunk_editor.data.place("rock",Vector2(0,2),0.0,0.28)
	scene._chunk_editor.refresh()
	check(scene.invite_bigfoot(Vector3.ZERO),"Invite actor in product scene")
	scene.set_building(false)
	scene.set_process_unhandled_input(false)
	scene._build_palette.set_process_input(false)
	scene.routine._next_action = 10000.0
	play = scene.world_play
	play.mischief.autonomous = false
	play._attention_time = 10000.0
	await ticks(120)
	play.rebuild_registry()
	rock = play.promote(id)
	check(play.exchange.accepts(rock),"Small authored rock is an offering")
	await offer()
	await ticks(20)
	check(play.exchange.busy() and play.loose_props.grabbed==rock,"Watch starts while player still owns rock")
	# Model accumulated steadiness with palm contact still pending, then a
	# fast withdrawal on this frame. Old steadiness must never authorize it.
	play.exchange._steady = 1.3
	play.exchange._previous = rock.global_position+Vector3(0.1,0,0)
	play.exchange.advance(1.0/60)
	check(play.exchange.held==null and play.exchange._steady==0.0,"Fast withdrawal clears accumulated offer time")
	play.loose_props._target = Vector3(0,3.5,0.85)
	await ticks(75)
	check(play.exchange.held==null and play.loose_props.grabbed==rock,"Out of reach rock cannot be taken")
	play.loose_props._target = Vector3(0,1.9,0.85)
	check(await wait_for_inspection(),"Real palm contact takes the offered rock")
	check(play.exchange.held==rock and play.loose_props.grabbed==null and rock.held,"Transfer has one owner and no physical release")
	check(play.loose_props._samples.is_empty(),"Transfer clears stale throw samples")
	await ticks(45)
	await capture("inspect")
	var pose := rock.global_transform
	scene._paused = true
	await ticks(30)
	check(rock.global_transform.is_equal_approx(pose) and rock.held,"Pause preserves Bigfoot's grip")
	scene._paused = false
	await ticks(15)
	check(not rock.global_transform.is_equal_approx(pose),"Inspection resumes after pause")
	var mouse: Vector2 = scene.camera.unproject_position(rock.global_position)
	check(play.loose_props.held_at(mouse),"Held rock remains pickable while collision is disabled")
	check(not scene._resident_play.pick(mouse),"Held rock gets click priority over Bigfoot")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = mouse
	check(scene.handle_resident_input(down),"Real click routes to held prop")
	check(not play.exchange.busy() and play.loose_props.grabbed==rock and rock.held,"Player takeover cancels actor grip without losing object")
	for result in ["keep","play","throw"]:
		await offer()
		if not await wait_for_inspection():
			check(false,"Acquire for "+result)
			continue
		# Exercise every resolution independent of the random choice.
		play.exchange._choose()
		play.exchange.outcome = result
		var grip_error := 0.0
		var captured := false
		for i in range(240):
			await physics_frame
			if play.exchange.held != null and play.exchange._age>0.0:
				grip_error = maxf(grip_error,scene.creature.hand_position().distance_to(play.exchange._palm(rock.global_position)))
				if not captured and play.exchange._age>(0.9 if result=="throw" else 1.5 if result=="keep" else 2.0):
					await capture(result)
					captured = true
			if not play.exchange.busy(): break
		check(grip_error<0.25,"Palm follows rock through "+result+" (error="+str(grip_error)+")")
		check(result in play.exchange.history,"Completes "+result)
		check(not rock.held and rock.collision_layer==1,"Restores physics after "+result)
		check(scene.creature.can_roam() and scene.creature.hand_targets.is_empty(),"Releases actor after "+result)
		if result=="keep": check(rock.get_meta("bigfoot_favorite",false),"Kept rock remembers preference this visit")
	await offer()
	check(await wait_for_inspection(),"Acquire before focus loss")
	scene.remove_meta("movie_capture")
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	scene.set_meta("movie_capture",true)
	check(not play.exchange.busy() and not rock.held,"Focus loss clears actor grip and restores physics")
	await offer()
	check(await wait_for_inspection(),"Acquire before world edit")
	scene.set_building(true)
	check(not play.exchange.busy(),"Build transition cancels exchange before saving poses")
	print("BIGFOOT OBJECT EXCHANGE: ",failures," failures")
	quit(1 if failures else 0)
