extends SceneTree
## The drawn pilot on foot (scripts/pilot_figure.gd, its model and clips from
## art/blender/pilot/pilot_build.py): the model loads with its clips (idle,
## walk, run, skid), all loops, dressed in the pilot's paint; walking at
## the walk's speed and running at the run's, a planted boot moves back under
## the body at that speed (it stays on the ground as the body moves on) and
## the boots take turns; let stand, it fades to idle and a boot on the ground
## doesn't slide. The clips by themselves: all through the idle's long loop
## a boot on the ground stays put (it moves only lifted, and one does lift,
## the shuffle), and the loop closes; the skid is short, both boots down, the
## braced one well ahead of the hips.
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotPaint = preload("res://scripts/pilot_paint.gd")
const DT := 1.0/60.0
## Under this, an ankle's boot is flat on the ground (its ankle stands 0.053).
const FLAT := 0.06
## The most (m) an ankle on the ground may move in a frame standing: rolling
## up onto its ball or back on its heel, not sliding.
const STAND_STEP := 0.0015
var failures := 0

## What the figure reads of the motor.
class Motor:
	extends RefCounted
	var facing := 0.0
	var grounded := true
	var skidding := false
	var flip := -1.0
	var velocity := Vector3.ZERO
	var feet := Vector3.ZERO
	var pace := 0.0
	func speed() -> float: return pace

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var figure := PilotFigure.new()
	root.add_child(figure)
	var player := figure.find_child("AnimationPlayer",true,false) as AnimationPlayer
	check(player != null and player.has_animation(&"idle") and player.has_animation(&"walk") and player.has_animation(&"run") and player.has_animation(&"skid"),"The model has its idle, walk, run and skid")
	if player != null:
		for clip: String in ["idle","walk","run","skid"]:
			check(player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR,"%s loops" % clip)
	var dressed := 0
	for mesh: MeshInstance3D in figure.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var m := mesh.mesh.surface_get_material(i) as ShaderMaterial
			if m != null and m.shader == PilotPaint.PAINT: dressed += 1
	check(dressed >= 10,"Dressed in the pilot's paint (%d surfaces)" % dressed)
	var skeleton: Skeleton3D = figure.find_children("*","Skeleton3D",true,false)[0]
	var feet := [skeleton.find_bone("foot.L"),skeleton.find_bone("foot.R")]
	check(feet[0] >= 0 and feet[1] >= 0,"The rig has its boots")
	var motor := Motor.new()
	# At each clip's own speed, a boot planted flat should go back under the
	# body (+Z: the figure faces -Z) at that speed.
	for gait: Array in [["walks",PilotFigure.WALK_SPEED],["runs",PilotFigure.RUN_SPEED]]:
		var speed: float = gait[1]
		motor.pace = speed
		for i in range(60): figure.drive(motor,DT)
		var planted := [0,0]
		var speeds := []
		var was := [_at(skeleton,feet[0]),_at(skeleton,feet[1])]
		for i in range(120):
			figure.drive(motor,DT)
			for f in range(2):
				var now := _at(skeleton,feet[f])
				var before: Vector3 = was[f]
				if now.y < FLAT and before.y < FLAT and absf(now.y-before.y) < 0.0005:
					planted[f] += 1
					speeds.append((now.z-before.z)/DT)
				was[f] = now
		var mean := 0.0
		var worst := 0.0
		for s: float in speeds: mean += s/maxf(speeds.size(),1.0)
		for s: float in speeds: worst = maxf(worst,absf(s-speed))
		check(planted[0] >= 6 and planted[1] >= 6,"As it %s, both boots take turns planted (%d, %d frames)" % [gait[0],planted[0],planted[1]])
		check(absf(mean-speed) < 0.08 and worst < 0.35,"As it %s, a planted boot keeps to the ground (%.2f m/s back for %.2f, worst off %.2f)" % [gait[0],mean,speed,worst])
	# Let stand: the run fades out to the idle (anywhere in its loop) and a
	# boot on the ground stays where it is.
	motor.pace = 0.0
	for i in range(40): figure.drive(motor,DT)
	var standing := []
	for i in range(90):
		figure.drive(motor,DT)
		standing.append([_at(skeleton,feet[0]),_at(skeleton,feet[1])])
	var slid := _worst_slide(standing)
	check(slid < STAND_STEP,"Standing, a boot on the ground doesn't slide (worst %.4f m in a frame)" % slid)
	figure.free()
	# The idle all through its loop: a boot moves only lifted.
	var idle := _clip(&"idle")
	var ankles: Array = idle.ankles
	slid = _worst_slide(ankles)
	var lifted := 0.0
	for pair: Array in ankles: lifted = maxf(lifted,maxf(pair[0].y,pair[1].y))
	var first: Array = ankles[0]
	var last: Array = ankles[ankles.size()-1]
	var seam := maxf(first[0].distance_to(last[0]),first[1].distance_to(last[1]))
	check(idle.length > 10.0,"The idle is a long loop (%.1f s)" % idle.length)
	check(slid < STAND_STEP,"All through the idle a boot on the ground doesn't slide (worst %.4f m in a frame)" % slid)
	check(lifted > 0.07,"Some time in the idle a boot lifts, shuffled (ankle up to %.3f m)" % lifted)
	check(seam < 0.002,"The idle's loop closes (the boots %.4f m apart end to start)" % seam)
	# The skid: short, both boots down, the braced one well ahead of the hips
	# (ahead is -Z).
	var skid := _clip(&"skid")
	var high := 0.0
	var ahead := INF
	for i in range(skid.ankles.size()):
		var pair: Array = skid.ankles[i]
		high = maxf(high,maxf(pair[0].y,pair[1].y))
		ahead = minf(ahead,skid.hips[i].z-minf(pair[0].z,pair[1].z))
	check(skid.length > 0.2 and skid.length < 0.6,"The skid loops short (%.2f s)" % skid.length)
	check(high < 0.09,"Skidding, both boots stay down (ankles at most %.3f m up)" % high)
	check(ahead > 0.15,"Skidding, a boot is braced well ahead of the hips (%.2f m at least)" % ahead)
	print("PASS: pilot figure" if failures == 0 else "FAIL: pilot figure")
	quit(1 if failures else 0)

## `clip` played by itself on a fresh model, every frame of it: its length,
## the ankles [left, right] and the hips, in the model's frame.
func _clip(clip: StringName) -> Dictionary:
	var model: Node3D = PilotFigure.MODEL.instantiate()
	root.add_child(model)
	var player := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
	var feet := [skeleton.find_bone("foot.L"),skeleton.find_bone("foot.R")]
	var hips := skeleton.find_bone("hips")
	var length := player.get_animation(clip).length
	var out := {"length":length,"ankles":[],"hips":[]}
	player.play(clip)
	for i in range(roundi(length/DT)+1):
		player.seek(minf(i*DT,length),true)
		out.ankles.append([_at(skeleton,feet[0]),_at(skeleton,feet[1])])
		out.hips.append(_at(skeleton,hips))
	model.free()
	return out

## The most an ankle down on the ground (flat, this frame and the last) moves
## across the ground in a frame, through `frames` of [left, right] ankles.
func _worst_slide(frames: Array) -> float:
	var worst := 0.0
	for i in range(1,frames.size()):
		for f in range(2):
			var now: Vector3 = frames[i][f]
			var before: Vector3 = frames[i-1][f]
			if now.y < FLAT and before.y < FLAT:
				worst = maxf(worst,Vector2(now.x-before.x,now.z-before.z).length())
	return worst

## The ankle in the world.
func _at(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)
