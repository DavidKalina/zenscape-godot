extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: droplet transform and ring color checks require native rendering")
		quit()
		return
	var drips = load("res://scripts/waterfall_drips.gd").new()
	root.add_child(drips)
	drips.add_emitter(Vector3(0,2,0),Vector3(0,0.025,0))
	drips._draw()
	check(drips.drops.multimesh.visible_instance_count == 1,"A droplet begins at its emitter")
	var flight: float = drips.emitters[0].flight
	drips.advance(flight*0.5,false)
	var falling: Vector3 = drips.drops.multimesh.get_instance_transform(0).origin
	check(falling.y<2.0 and falling.y>0.025,"Droplet falls above the water")
	var clock_before: float = drips.clock
	drips.advance(10.0,true)
	check(drips.clock == clock_before and drips.drops.multimesh.get_instance_transform(0).origin == falling,"Pause holds the droplet")
	drips.advance(flight*0.5+0.05,false)
	check(drips.drops.multimesh.visible_instance_count == 0,"Droplet disappears on impact")
	check(drips.rings.multimesh.visible_instance_count == 1 and drips.splashes.multimesh.visible_instance_count == 3,"Impact produces one ring and a tiny splash")
	var start_radius: float = drips.rings.multimesh.get_instance_transform(0).basis.x.length()
	var start_alpha: float = drips.rings.multimesh.get_instance_color(0).a
	drips.advance(0.5,false)
	check(drips.rings.multimesh.get_instance_transform(0).basis.x.length()>start_radius and drips.rings.multimesh.get_instance_color(0).a<start_alpha,"Ring expands and fades")
	check(drips.splashes.multimesh.visible_instance_count == 0,"Splash quickly expires")
	drips.advance(0.85,false)
	check(drips.rings.multimesh.visible_instance_count == 0,"Ring expires before the next drip")
	for i in range(40): drips.add_emitter(Vector3(0,1,0),Vector3.ZERO)
	check(drips.emitters.size()==drips.CAPACITY,"Emitter population stays bounded")
	drips.seed_from([],null)
	check(drips.emitters.is_empty() and drips.rings.multimesh.visible_instance_count==0,"Terrain refresh clears stale effects")
	drips.free()
	print("WATERFALL DRIPS: ",failures," failures")
	quit(1 if failures else 0)
