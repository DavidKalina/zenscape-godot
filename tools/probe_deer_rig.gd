extends SceneTree
## Headless check of the Blender deer (tools/blender_creatures): the glb loads,
## life_rigs builds a doe and a fawn with the life material, every clip is there
## and plays, and LifeMoments' clip sequencing runs a visit (walk in, graze,
## head up, walk out) on the life clock. Prints DEER_PROBE lines and exits
## non-zero on a failure. Nothing is drawn, so the look stays unverified.
##
##   Godot --headless --path . --script res://tools/probe_deer_rig.gd

const Rigs = preload("res://scripts/life_rigs.gd")
const Moments = preload("res://scripts/life_moments.gd")
const CLIPS := ["Idle","Graze","Look","Alert","Walk","HeadDown","HeadUp"]

var failures := 0

func check(ok: bool, what: String) -> void:
	print("DEER_PROBE ", "ok   " if ok else "FAIL ", what)
	if not ok: failures += 1

func _initialize() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	var holder := Node3D.new()
	root.add_child(holder)
	var doe: RefCounted = Rigs.deer(material,false)
	var fawn: RefCounted = Rigs.deer(material,true)
	holder.add_child(doe.root)
	holder.add_child(fawn.root)
	for rig in [doe,fawn]:
		var meshes: Array = rig.root.find_children("*","MeshInstance3D",true,false)
		check(meshes.size() == 1,"%s keeps one mesh (%d)" % [rig.root.name,meshes.size()])
		var mesh := meshes[0] as MeshInstance3D
		check(mesh.material_override == material,"%s wears the life material" % rig.root.name)
		check(mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D,"%s is skinned" % rig.root.name)
		var arrays := mesh.mesh.surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		check(colors.size() > 0,"%s has vertex colours" % rig.root.name)
		var mean := Color(0,0,0)
		for c in colors: mean += c
		mean /= float(colors.size())
		print("DEER_PROBE info %s triangles %d vertices %d mean colour %s first colour %s" % [rig.root.name,indices.size()/3,colors.size(),mean,colors[0]])
		var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
		print("DEER_PROBE info %s bones %d" % [rig.root.name,skeleton.get_bone_count()])
		for clip in CLIPS:
			check(rig.player.has_animation(clip),"%s has clip %s" % [rig.root.name,clip])
		for clip in Rigs.LOOPS:
			check(rig.player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR,"%s loops %s" % [rig.root.name,clip])
	# Every clip plays and turns the neck (local bone poses are set as the clip advances).
	var skeleton := (doe.root.find_children("*","Skeleton3D",true,false)[0]) as Skeleton3D
	var neck := skeleton.find_bone("Neck1")
	check(neck >= 0,"skeleton has a Neck1 bone")
	for clip in CLIPS:
		doe.play(clip,0.0)
		doe.advance(0.0)
		var length: float = doe.player.get_animation(clip).length
		var turned := 0.0
		var a := skeleton.get_bone_pose_rotation(neck)
		for k in range(1,9):
			doe.advance(length/8.0)
			turned = maxf(turned,rad_to_deg(a.angle_to(skeleton.get_bone_pose_rotation(neck))))
		print("DEER_PROBE info %s %.2f s, neck turns up to %.1f deg" % [clip,length,turned])
		check(length > 0.5 and turned > 0.5,"%s plays and moves" % clip)
	# A visit through LifeMoments' sequencing: walk in, graze, head up, graze, walk out.
	var moments: Node3D = Moments.new()
	var m := {"phase":"in","scale":1.0,"down":true}
	var seen := []
	var plan := [["in",true,false,3.0],["graze",false,true,6.0],["graze",false,false,8.0],["graze",false,true,4.0],["graze",false,false,5.0],["out",true,false,3.0]]
	for leg in plan:
		m.phase = leg[0]
		m.down = leg[2]
		var t := 0.0
		while t < leg[3]:
			moments._play_deer(doe,m,leg[1],1.0/30.0)
			t += 1.0/30.0
			var now: String = doe.current()
			if seen.is_empty() or seen[-1] != now: seen.append(now)
	print("DEER_PROBE info visit clips ",seen)
	check(seen == ["Walk","HeadDown","Graze","HeadUp","Alert","Idle","HeadDown","Graze","HeadUp","Idle","Walk"],"visit plays walk, graze, alert, idle and walk out in order")
	# The first head-up of a visit holds long enough for HeadUp and Alert to play out.
	var am := {"phase":"graze","scale":1.0,"down":false,"clip":"Graze","age":10.0,"next":12.5}
	moments._play_deer(doe,am,false,1.0/30.0)
	check(is_equal_approx(float(am.next),10.0+doe.length("HeadUp")+doe.length("Alert")),"alert head-up window runs %.2f s" % (float(am.next)-10.0))
	var im := {"phase":"graze","scale":1.0,"down":false,"clip":"Graze","ups":1,"age":10.0,"next":12.5}
	moments._play_deer(doe,im,false,1.0/30.0)
	check(is_equal_approx(float(im.next),12.5),"a later head-up keeps its rolled window")
	var fm := {"phase":"in","scale":0.62,"down":true}
	moments._play_deer(fawn,fm,true,1.0/30.0)
	check(is_equal_approx(fawn.speed,0.42*1.15/(0.42*0.62)),"fawn walk speed syncs to 1.15x at 0.62 scale (%.3f)" % fawn.speed)
	moments.free()
	print("DEER_PROBE done failures=%d" % failures)
	quit(1 if failures > 0 else 0)
