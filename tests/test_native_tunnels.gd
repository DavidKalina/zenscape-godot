extends SceneTree
const Tunnels = preload("res://scripts/native_tunnels.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/tunnel-tests-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	await editor.form_landscape("horn","alpine",false,37)
	var data := editor.data
	var peak := 0
	for i in range(data.heights.size()):
		if data.heights[i]>data.heights[peak]: peak = i
	var hit := Vector3.ZERO
	var plan := {}
	for distance in [5.0,4.0,3.0,6.0,7.0]:
		var p: Vector2 = data.points[peak]+Vector2(0,distance)
		hit = Vector3(p.x,data.ground_height(p),p.y)
		plan = Tunnels.plan(data,hit,Vector3.FORWARD,2.5,5.0)
		if not plan.is_empty(): break
	check(not plan.is_empty(),"A mountain slope supports an enclosed bore")
	if plan.is_empty(): quit(1); return
	scene._auto_orbit = false
	scene.set_building(true)
	scene.camera.global_position = hit+Vector3(0,1,12)
	scene.camera.look_at(hit)
	editor.select_tool("tunnel")
	var before := data.to_document()
	check(editor.place_at(scene.camera.unproject_position(hit)),"Tunnel places through the actual pointer tool")
	check(data.tunnels.size()==1 and data.heights == PackedFloat32Array(before.heights),"Bore leaves the mountain heightfield and summit intact")
	if data.tunnels.is_empty(): quit(1); return
	var tunnel: Dictionary = data.tunnels[0]
	var pose := Tunnels.pose(tunnel)
	var eye: Vector3 = pose*Vector3(0,1,-2)
	var forward: Vector3 = pose.basis*Vector3.BACK
	var back: Variant = data.ray_hit(eye,forward)
	check(back != null and (pose.affine_inverse()*back-Vector3(0,1,tunnel.length)).length()<0.03,"Entrance is a real hole with a solid back wall")
	var inside: Vector3 = Tunnels.charge_point(tunnel)
	var floor_hit: Variant = data.ray_hit(inside+Vector3.UP,Vector3.DOWN)
	check(floor_hit != null and floor_hit.distance_to(inside)<0.03,"Tunnel has a pickable interior floor")
	var ceiling: Variant = data.ray_hit(inside+Vector3.UP,Vector3.UP)
	check(ceiling != null and absf(ceiling.y-inside.y-tunnel.height)<0.03,"Mountain roof remains over the tunnel")
	scene.world_play.ensure_collision()
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(inside+Vector3.UP,inside-Vector3.UP,1)
	var physical: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	check(not physical.is_empty() and physical.position.distance_to(inside)<0.03,"Physics collider agrees with the tunnel floor")
	scene.camera.global_position = eye
	scene.camera.look_at(inside)
	editor.select_tool("explosive")
	check(editor.place_at(scene.camera.unproject_position(inside)),"Explosive pointer can place through the portal onto its floor")
	var clicked: Dictionary = editor.explosives.charges().back()
	check(data.object_position(clicked).distance_to(inside)<0.05,"Pointer placement uses underground elevation instead of the roof")
	editor.select_tool("tunnel")
	editor.plant_tunnel_charge()
	var charge: Dictionary = editor.explosives.charges().back().duplicate(true)
	var anchor := data.object_position(charge)
	check(anchor.distance_to(inside)<0.03 and anchor.y<data.ground_height(Vector2(anchor.x,anchor.z))-1,"Charge is planted underground at the tunnel floor")
	editor.seal_tunnel()
	check(data.tunnels[0].sealed and data.object_position(data.object_by_id(charge.id))==anchor,"Sealing preserves the buried charge")
	var closed_hit: Variant = data.ray_hit(eye,forward)
	check(closed_hit != null and eye.distance_to(closed_hit)<eye.distance_to(back)-1,"Sealing restores solid terrain across the portal")
	check(scene.save_current(),"Sealed tunnel and underground charge save")
	var sealed := data.to_document()
	check(data.load_document(sealed) and data.to_document()==sealed,"Tunnel records round-trip exactly")
	var invalid := sealed.duplicate(true)
	invalid.tunnels[0].length = INF
	check(not data.load_document(invalid) and data.to_document()==sealed,"Malformed tunnel records are rejected atomically")
	editor.refresh()
	editor.reopen_tunnel()
	check(not data.tunnels[0].sealed,"Tunnel can be reopened")
	check(editor.terrain.mesh.surface_get_material(0) != null,"Tunnel mesh retains its terrain material outside Build mode")
	editor.undo()
	check(data.tunnels[0].sealed,"Undo reverses reopening")
	scene.set_building(false)
	editor.explosives.target_id = charge.id
	editor.explosives.detonate()
	check(data.object_by_id(charge.id).is_empty() and data.heights != PackedFloat32Array(sealed.heights),"Buried charge detonates and breaks the mountain")
	var fragments: Array = editor.explosives.bodies.filter(func(body: RigidBody3D) -> bool: return body.get_meta("internal_blast",false))
	check(fragments.size()>3,"Sealed tunnel charge launches the original surrounding rock as pressure fragments")
	check(fragments.all(func(body: RigidBody3D) -> bool: return body.get_meta("release_at")==0.0),"Buried rupture is immediate, without a delayed downhill peel")
	editor.undo()
	check(data.to_document()==sealed,"Undo blast restores the sealed tunnel and armed charge")
	editor.reopen_tunnel()
	check(scene.save_current() and scene.open_path(editor.save_path),"Main game reopens a saved open tunnel")
	scene.set_building(true)
	check(editor._material != null and editor.terrain.get_active_material(0) != null,"Reopened tunnel can switch back into Build mode")
	scene.queue_free()
	await process_frame
	print("Native tunnels: ",failures," failures")
	quit(1 if failures else 0)
