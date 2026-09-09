extends RefCounted
## Authored on the same Blender rig; remap bone paths for every actor variant.
const ACTIONS := ["StoneHeave","StoneThrow","LogLift","LogCarry","LogToss","LogSlam","TreeShake","SitDown","Sit","StandUp","Sleep","Tremor"]
static var enabled := true
static var _clips: Dictionary = {}

static func clips_for(player: AnimationPlayer, skeleton: Skeleton3D) -> Dictionary:
	if _clips.is_empty():
		var source := preload("res://assets/models/zenscape-bigfoot-personality.glb").instantiate()
		var author: AnimationPlayer = source.find_child("AnimationPlayer",true,false)
		for name in ["Walk","Idle","Held"]+ACTIONS:
			_clips[name] = author.get_animation("Personality"+name if name not in ACTIONS else name).duplicate()
		source.free()
		var walking := preload("res://assets/models/zenscape-bigfoot-heavy-walk.glb").instantiate()
		var walk_author: AnimationPlayer = walking.find_child("AnimationPlayer",true,false)
		_clips["Walk"] = walk_author.get_animation("HeavyWalk").duplicate()
		_clips["Walk"].set_meta("ground_speed_mps",0.85)
		_clips["Walk"].set_meta("steps_per_loop",4)
		walking.free()
	var result := {}
	var path := str(player.get_node(player.root_node).get_path_to(skeleton))
	for name in _clips:
		var animation: Animation = _clips[name].duplicate()
		for track in range(animation.get_track_count()-1,-1,-1):
			var source_path := animation.track_get_path(track)
			var bone := str(source_path.get_subname(0)) if source_path.get_subname_count()>0 else ""
			if skeleton.find_bone(bone)<0:
				animation.remove_track(track)
			else:
				animation.track_set_path(track,NodePath(path+":"+bone))
		animation.loop_mode = Animation.LOOP_LINEAR if name in ["Walk","Idle","Held","LogCarry","Sit","Sleep"] else Animation.LOOP_NONE
		result[name] = animation
	return result
