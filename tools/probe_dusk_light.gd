extends SceneTree
## Headless: the light the land gets as the sun goes down, by sun height. For
## each setting sun it prints the sky fill on an up-facing surface (hemi sky
## luminance times hemi energy), the bounce, the key's irradiance, the night
## grade and the fog's luminance, so a dusk trough (the land darker after
## sunset than at night) shows as numbers.
##   Godot --headless --path . -s res://tools/probe_dusk_light.gd -- [--overcast]
const SUNS := [0.2, 0.1, 0.05, 0.02, 0.0, -0.02, -0.04, -0.06, -0.08, -0.1, -0.12, -0.14, -0.17, -0.2, -0.25, -0.3, -0.4]

func _initialize() -> void:
	run.call_deferred()

static func lum(v: Vector3) -> float:
	return v.dot(Vector3(0.2126, 0.7152, 0.0722))

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var sky = scene._celestial
	if "--overcast" in OS.get_cmdline_user_args():
		sky.cloud = 0.75
	var ring := WorldClock.elevation_for_phase(0.5)
	print("   sun   fill(up)  hemi_rgb                 bounce  key     night_grade  fog     sky_up")
	for e: float in SUNS:
		sky.set_phase(0.75 - asin(e / ring) / TAU)
		sky.update_rig()
		var s: Dictionary = sky.state
		var hemi: Vector3 = s.zs_hemi_sky
		var energy: float = s.zs_hemi_energy
		print("%6.2f  %7.4f  (%.3f %.3f %.3f)  %7.4f  %6.3f  %5.2f        %6.4f  %6.4f" % [e, lum(hemi) * energy, hemi.x * energy, hemi.y * energy, hemi.z * energy,
			lum(s.zs_hemi_ground) * energy, lum(s.zs_key_irradiance), sky.night_grade.x, lum(sky.fog_display), lum(s.zs_sky_up)])
	scene.queue_free()
	await process_frame
	quit(0)
