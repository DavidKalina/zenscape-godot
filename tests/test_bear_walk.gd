## Verify the imported skeleton, skin coverage, loop seam, and stance contact.
extends SceneTree
var actor: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
func _initialize():
	call_deferred('run_check')
func run_check():
	actor = load('res://assets/models/zenscape-bear-walk.glb').instantiate()
	root.add_child(actor)
	player = actor.find_child('AnimationPlayer',true,false)
	var skeletons = actor.find_children('*','Skeleton3D',true,false)
	if player == null or skeletons.size()!=1 or not player.has_animation('Walk'):
		fail('Missing animation player, Walk, or skeleton');return
	skeleton=skeletons[0]
	var anim=player.get_animation('Walk')
	if absf(anim.length-1.6)>.001:
		fail('Incorrect loop length: %s' % anim.length);return
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play('Walk')
	var paw=skeleton.find_bone('Paw_Front_L')
	if paw<0:
		fail('Missing front paw bone');return
	var a=sample_paw(paw,.1)
	var b=sample_paw(paw,.6)
	var speed=.2604166666666667
	var slip=(b+Vector3(0,0,speed*.6)-(a+Vector3(0,0,speed*.1))).length()
	if slip>.003:
		fail('Exported planted paw slips: %s' % slip);return
	var moving=sample_paw(paw,1.38)
	if moving.y-a.y<.025:
		fail('Exported paw never lifts during swing');return
	sample_paw(paw,0)
	var first=[]
	for i in skeleton.get_bone_count():first.append(skeleton.get_bone_global_pose(i))
	sample_paw(paw,1.6)
	var seam=0.0
	for i in skeleton.get_bone_count():
		var pose=skeleton.get_bone_global_pose(i)
		seam=maxf(seam,pose.origin.distance_to(first[i].origin))
	if seam>.001:
		fail('Exported loop seam: %s' % seam);return
	var skinned=0
	for mesh in actor.find_children('*','MeshInstance3D',true,false):
		if mesh.skin!=null:skinned+=1
	if skinned!=19:
		fail('Missing skinned meshes: %s' % skinned);return
	print('BEAR_WALK_OK duration=%.3f bones=%d skinned_meshes=%d stance_slip_m=%.8f seam_m=%.8f paw_lift_m=%.4f' % [anim.length,skeleton.get_bone_count(),skinned,slip,seam,moving.y-a.y])
	actor.queue_free();quit()
func sample_paw(index:int,time:float)->Vector3:
	player.seek(time,true)
	skeleton.force_update_all_bone_transforms()
	return skeleton.get_bone_global_pose(index).origin
func fail(message:String):
	push_error(message)
	if actor:actor.queue_free()
	quit(1)
