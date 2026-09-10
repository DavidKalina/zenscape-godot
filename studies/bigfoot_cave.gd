extends "res://studies/fidelity_life.gd"
## Fidelity's northeastern corner, fitted with the approved Blender cave.
func _ready() -> void:
	super._ready()
	creature.set_body_scale(1.0)
	_refresh_habitat()
	get_window().title = "ZenScape · Bigfoot's cave · woodland corner"
	var data: NativeTerrainData = _chunk_editor.data
	data.begin_stroke()
	var site := {"start":[3.0,1.7,7.0],"heading":PI/2.0,"width":6.4,"height":4.8,"length":7.2,"sealed":false,"cave":true,"cave_scale":1.0}
	# A gentle earthen seat supports the den in its own woodland corner.
	data.brush(Vector2(7.2,7.0),6.8,128.0,"flatten",1.7)
	data.tunnels.append(site)
	var site_pose := preload("res://scripts/bigfoot_cave_site.gd").pose(site)
	var bounds := preload("res://scripts/bigfoot_cave_site.gd").bounds(site)
	bounds = bounds.merge(site_pose*AABB(Vector3(-1.5,0,0),Vector3(3,4,4)))
	var groups: Dictionary = preload("res://scripts/world_reference_props.gd").GROUPS
	for interest: Dictionary in habitat.interests:
		var box: AABB = interest.get("bounds",AABB(interest.position-Vector3.ONE*0.6,Vector3.ONE*1.2))
		if not bounds.intersects(box): continue
		var parts: PackedStringArray = str(interest.id).split(":")
		if parts.size()!=2: continue
		if parts[0]=="object": data.remove_object(int(parts[1]))
		else:
			for names: Array in groups.values():
				if parts[0] not in names: continue
				for part: String in names:
					var key := part+":"+parts[1]
					if key not in data.source_replacements: data.source_replacements.append(key)
	data.end_stroke()
	_chunk_editor.refresh()
	_refresh_habitat()
	var arrival: Variant = navigation.nearest_safe(site_pose*Vector3(0,0,2.5))
	if arrival != null: creature.reset_at(arrival)
	for entry in [["Find his cave",_focus_cave],["Visit the cave",_visit_cave]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		_life_status.get_parent().add_child(button)
	_focus_cave()
	if "--visit-cave" in OS.get_cmdline_user_args(): _visit_cave()

func _visit_cave() -> void:
	if not routine.cave.phase.is_empty(): return
	routine.cancel("cave visit invited")
	routine.cave.request("sleep")

func _focus_cave() -> void:
	if _chunk_editor.data.tunnels.is_empty(): return
	_auto_orbit = false
	target = Vector3(2.0,2.0,2.0)
	distance = 32.0
	yaw = -0.75
	polar = 0.9
	_update_camera()

func capture_diorama_state() -> Dictionary:
	var point: Vector3 = routine.cave.entrance if routine.cave._inside else creature.position
	return {"resident":resident_enabled,"resident_scale":creature.body_scale,"position":[point.x,point.y,point.z]}
