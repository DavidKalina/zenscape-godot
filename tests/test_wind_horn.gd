extends SceneTree
## The wind-horn (scripts/ruin_kit_horn.gd, scripts/wind_horn.gd): it builds
## with a Mesh, a Body, a Head holding a Mouth and a Rig; the mouth fits the
## air ball; the cap is a standable top within a pumped jump; the head turns
## toward a point, slowly; the knock-out slumps it and wears off.
const Horn = preload("res://scripts/ruin_kit_horn.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const AirBlast = preload("res://scripts/dragon_air_blast.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL "+label)

func _initialize() -> void:
	for seed_value: int in [1,2,3]:
		for weathered: float in [0.0,1.0]:
			var horn := Horn.wind_horn(seed_value,weathered)
			var tag := " seed %d weathered %.0f" % [seed_value,weathered]
			root.add_child(horn)
			await process_frame
			check(horn.get_node_or_null("Mesh") is MeshInstance3D and horn.get_node_or_null("Body") is StaticBody3D,"Mesh and Body"+tag)
			var head := horn.get_node_or_null("Head") as Node3D
			var mouth := horn.get_node_or_null("Head/Barrel/Mouth") as Marker3D
			check(head != null and mouth != null and Horn.rig(horn) != null,"Head, Mouth, Rig"+tag)
			if head == null or mouth == null: continue
			check(float(horn.get_meta("mouth_radius")) >= AirBlast.ball_radius(),"the mouth fits the air ball"+tag)
			var top := float(horn.get_meta("top"))
			check(float(horn.get_meta("ped_height")) < RuinKit.CHAIN_TOP and top-float(horn.get_meta("ped_height")) < RuinKit.GRAB_TOP,"the pedestal is a jump and the cap a catch from it"+tag)
			var high := -INF
			for holder in head.get_node("Body").get_children():
				for p in ((holder as CollisionShape3D).shape as ConvexPolygonShape3D).points: high = maxf(high,p.y)
			check(head.position.y+high > top-0.02,"the head's hull reaches the cap (the horn's staves collide too, the bell may stand over it)"+tag)
			# Turn toward a point off to the right: the mouth swings toward it, no faster than TURN_RATE.
			var rig := Horn.rig(horn)
			var target := horn.to_global(Vector3(8.0,1.5,2.0))
			var way0 := mouth.global_transform.basis.z
			rig.aim_at(target,0.1)
			var turned := way0.angle_to(mouth.global_transform.basis.z)
			check(turned > 0.01 and turned <= rig.TURN_RATE*0.1+0.02,"the head turns, slowly"+tag)
			for i in range(200): rig.aim_at(target,0.05)
			var flat := Vector3(target.x-head.global_position.x,0.0,target.z-head.global_position.z).normalized()
			var face := mouth.global_transform.basis.z
			face.y = 0.0
			check(face.normalized().dot(flat) > 0.99,"the head ends facing the point"+tag)
			# Knocked out: slumps, ignores aim, wears off.
			rig.disabled(1.0)
			check(rig.is_disabled(),"disabled"+tag)
			var held: Vector3 = mouth.global_transform.basis.z
			rig.aim_at(horn.to_global(Vector3(-8.0,1.0,3.0)),0.5)
			check(held.is_equal_approx(mouth.global_transform.basis.z),"aim does nothing while disabled"+tag)
			rig._left = 0.5
			rig._process(0.0)
			check(mouth.global_transform.basis.z.y < held.y-0.2,"the mouth tips down in the slump"+tag)
			rig._process(2.0)
			check(not rig.is_disabled(),"it wears off"+tag)
			horn.queue_free()
	print("wind horn: %d failures" % failures)
	quit(1 if failures > 0 else 0)
