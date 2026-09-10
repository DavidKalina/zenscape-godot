extends "res://studies/fidelity_life.gd"
## Fidelity's southern hill, fitted with the approved Blender cave.
func _ready() -> void:
	super._ready()
	creature.set_body_scale(0.75)
	_refresh_habitat()
	get_window().title = "ZenScape · Bigfoot's cave · 75% scale"
	var data: NativeTerrainData = _chunk_editor.data
	data.begin_stroke()
	var site := {"start":[3.79,1.5159,-10.09],"heading":-PI/4.0,"width":4.8,"height":3.6,"length":5.4,"sealed":false,"cave":true,"cave_scale":0.75}
	data.tunnels.append(site)
	var bounds := preload("res://scripts/bigfoot_cave_site.gd").bounds(site)
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
	var opening := preload("res://scripts/native_tunnels.gd").pose(_chunk_editor.data.tunnels[0])
	_auto_orbit = false
	target = opening.origin+opening.basis*Vector3(0,2.0,2.0)
	distance = 20.0
	yaw = 2.15
	polar = 1.08
	_update_camera()

func capture_diorama_state() -> Dictionary:
	var point: Vector3 = routine.cave.entrance if routine.cave._inside else creature.position
	return {"resident":resident_enabled,"resident_scale":creature.body_scale,"position":[point.x,point.y,point.z]}
