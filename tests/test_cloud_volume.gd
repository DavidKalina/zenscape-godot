extends SceneTree
## The unified cloud volume (scripts/cloud_volume.gd, --cloud-volume): off
## without the flag, the near sea and the towers drawing themselves as
## before; on, their own drawing goes, the march rides the camera's
## compositor, its parameters are the sea's and the towers' as they stand,
## and turning it off hands the drawing back. Headless: the GPU passes do
## not run here, only that the compute shaders compile, the composite's
## shader takes its inputs, and the parameters are set.
const CloudVolume = preload("res://scripts/cloud_volume.gd")
const CloudVolumeEffect = preload("res://scripts/cloud_volume_effect.gd")
const SkySea = preload("res://scripts/sky_sea.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for path in ["res://shaders/cloud_volume_march.glsl","res://shaders/cloud_volume_resolve.glsl"]:
		var spirv := (load(path) as RDShaderFile).get_spirv()
		check(spirv.compile_error_compute.is_empty() and not spirv.bytecode_compute.is_empty(), "%s compiles %s" % [path.get_file(),spirv.compile_error_compute])
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var look = scene.look_pass
	var sea: MeshInstance3D = look.sea
	check(not CloudVolume.wanted() and look.cloud_volume == null, "Without --cloud-volume the look pass makes none")
	check(sea.mesh is BoxMesh, "and the near sea draws itself")
	look.cloud_sea = 1.0
	look._update_cloud_sea(1.0)
	var camera: Camera3D = scene.camera
	camera.global_position = Vector3(120.0,40.0,-80.0)

	# On: one made by hand as the flag would, with a tower to read.
	var volume: Node3D = CloudVolume.new()
	scene.add_child(volume)
	look.cloud_volume = volume
	var islands := _islands()
	scene.add_child(islands)
	look.update(camera,scene._celestial)
	volume.update(camera,sea,islands,scene._celestial,12.0,Vector4(0.0,0.0,1.0,0.3))
	sea.follow(camera,12.0)
	volume._fill()
	check(sea.mesh == null, "On, the near sea no longer draws itself")
	check(sea.material.get_shader_parameter("envelope_at") is Vector4 and (sea.material.get_shader_parameter("envelope_at") as Vector4).w == 1.0, "but still bakes its envelope round the eye")
	var tower: Dictionary = islands.towers.built["0,0"]
	check(not (tower.node.get_node("Volume") as Node3D).visible, "A tower no longer draws itself")
	check(volume.attached() and camera.compositor.compositor_effects.has(volume.effect), "The march rides the camera's compositor")
	var effect = volume.effect
	check(effect.effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT and effect.access_resolved_depth, "It runs after the opaque pass, on the resolved depth")
	check(volume.material.render_priority == SkySea.RENDER_PRIORITY and volume.sheet.visible, "The composite draws where the near sea drew")
	var names: Array = volume.material.shader.get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)
	check(names.has("cloud_light") and names.has("cloud_shape") and names.has("cloud_sea_style") and names.has("key_light"), "The composite's shader compiles and takes the march's light terms and the sea's style")
	check(volume.material.get_shader_parameter("cloud_light") == effect.resolved_a, "It reads the resolved cloud")

	# The march's parameters (shaders/cloud_volume_march.glsl Params).
	var p: PackedFloat32Array = effect.march_params
	check(p.size() == CloudVolumeEffect.MARCH_FLOATS, "The march's block is its full size")
	check(p[16] > 0.0 and p[17] > 0.0 and is_equal_approx(p[18],camera.near) and is_equal_approx(p[19],camera.far), "The lens is the camera's")
	check(Vector3(p[20],p[21],p[22]).is_equal_approx(camera.global_position) and is_equal_approx(p[23],12.0), "The eye and the motion time are this frame's")
	check(is_equal_approx(p[31],0.3), "The glide's parting is handed on")
	check(is_equal_approx(p[32],SkySea.FLOOR) and is_equal_approx(p[33],SkySea.TALL) and is_equal_approx(p[34],sea.reach) and p[35] > 0.0, "The sea's feet, height, reach and strength")
	check(p[43] == 1.0, "The sea's envelope bake is marked drawn")
	check(int(p[49]) == 1 and volume.tower_count == 1, "One tower is marched")
	check(Vector3(p[84],p[85],p[86]).is_equal_approx((tower.node as Node3D).global_position) and is_equal_approx(p[87],1.0), "at its frame's origin, at full strength")
	check(Vector3(p[116],p[117],p[118]).is_equal_approx(Vector3(150.0,200.0,150.0)) and is_equal_approx(p[119],0.25), "with its box and waning")
	var r: PackedFloat32Array = effect.resolve_params
	check(r.size() == CloudVolumeEffect.RESOLVE_FLOATS and is_equal_approx(r[44],camera.near), "The resolve's block is set")
	effect.resize(Vector2i(1920,1080))
	check(effect.size == Vector2i(960,540) and effect.full_size == Vector2i(1920,1080), "The march is half the render each axis, the resolve the whole")

	# Off: the drawing handed back.
	volume.set_enabled(false)
	check(sea.mesh is BoxMesh and (tower.node.get_node("Volume") as Node3D).visible, "Off, the sea and the tower draw themselves again")
	check(not volume.attached() and not volume.sheet.visible, "and the march leaves the compositor")
	volume.set_enabled(true)
	volume.update(camera,sea,islands,scene._celestial,12.5)
	check(volume.attached() and sea.mesh == null, "On again, it takes over again")
	finish(scene)

## A stand-in for the sky world's islands: towers with one built tower, as
## scripts/sky_towers.gd keeps them, and no wakes.
func _islands() -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar towers: Node3D\nvar wakes: Node3D\n"
	script.reload()
	var holder: Node3D = script.new()
	var towers_script := GDScript.new()
	towers_script.source_code = "extends Node3D\nvar built := {}\n"
	towers_script.reload()
	var towers: Node3D = towers_script.new()
	holder.towers = towers
	holder.add_child(towers)
	var node := Node3D.new()
	node.position = Vector3(400.0,0.0,300.0)
	towers.add_child(node)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sky_tower.gdshader")
	for entry in [["box_mid",Vector3(0.0,80.0,0.0)],["box_half",Vector3(150.0,200.0,150.0)],["morph",0.5],["wane",0.25],["lift",3.0],["sea",-105.0],["top",300.0],["strength",1.0],["noise_shift",Vector3(1.0,2.0,3.0)]]:
		material.set_shader_parameter(entry[0],entry[1])
	var box := MeshInstance3D.new()
	box.name = "Volume"
	box.mesh = BoxMesh.new()
	box.material_override = material
	node.add_child(box)
	towers.built["0,0"] = {"node":node,"material":material,"wane":0.25}
	return holder

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func finish(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	await process_frame
	if failures > 0:
		push_error("cloud volume: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
