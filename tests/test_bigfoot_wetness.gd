extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	actor.set_process(false)
	var wet = actor.wet_coat
	actor.advance(0.05)
	check(not wet.coats.is_empty(),"Imported coat materials are found")
	var dry_color: Color = wet.coats[0].material.albedo_color
	wet.rain = 1.0
	for i in range(240): actor.advance(0.05)
	check(wet.wetness>0.99,"Twelve seconds of heavy rain soaks the coat")
	check(wet.coats[0].material.albedo_color.r<dry_color.r*0.6,"Soaked coat is visibly darker")
	check(wet.emitted>30,"Soaked fur drips")
	var before: float = wet.wetness
	var count: int = wet.emitted
	actor.advance(0.0)
	check(wet.wetness==before and wet.emitted==count,"Pause freezes moisture and drips")
	wet.rain = 0.0
	for i in range(600): actor.advance(0.05)
	check(wet.wetness>0.65 and wet.wetness<0.68,"Still damp thirty seconds after rain")
	check(wet.emitted>count,"Runoff continues after rain stops")
	for i in range(1220): actor.advance(0.05)
	check(wet.wetness==0.0,"Coat dries fully after ninety seconds")
	check(wet.coats[0].material.albedo_color==dry_color,"Original dry color restored exactly")
	for drop in wet.drops: check(not drop.mesh.visible,"No drops remain once dry")
	wet.rain = 1.0
	for i in range(240): actor.advance(0.05)
	actor.reset_at(Vector3(8,0,0))
	for drop in wet.drops: check(not drop.mesh.visible,"Teleport clears old runoff")
	check(wet.wetness>0.99,"Moving Bigfoot does not instantly dry him")
	actor.free()
	# Production scenes replace imported materials after actor setup.
	var resident := CreatureActor.new()
	root.add_child(resident)
	resident.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	resident.set_process(false)
	var shared := ShaderMaterial.new()
	shared.shader = preload("res://shaders/reference_surface.gdshader")
	for mesh: MeshInstance3D in resident.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = shared
	var original_parameter: Variant = shared.get_shader_parameter("coat_wetness")
	resident.wet_coat.rain = 1.0
	for i in range(240): resident.advance(0.05)
	check(resident.wet_coat.coats.size()==1,"Production coat stays shared within one actor")
	check(resident.wet_coat.coats[0].material.get_shader_parameter("coat_wetness")>0.99,"Production shader receives wetness")
	check(shared.get_shader_parameter("coat_wetness")==original_parameter,"Shared source material remains dry")
	resident.free()
	print("BIGFOOT WETNESS failures=",failures)
	quit(1 if failures else 0)
