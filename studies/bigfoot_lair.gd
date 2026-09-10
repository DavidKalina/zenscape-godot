extends "res://studies/bigfoot_cave.gd"
## Two visible stories in the same world; inspection only changes camera framing.
var lair: Node3D

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Two-story Bigfoot diorama"
	# Replace the old suspended underside with the inhabited lower story.
	var old_underside := get_node("Reference").find_child("mesh-3",true,false)
	if old_underside != null: old_underside.layers = 0
	var skirt: MeshInstance3D = get_node("Reference/skirt")
	var top: float = (skirt.transform*skirt.mesh.get_aabb()).end.y
	skirt.scale.y *= 0.61
	skirt.position.y = top-(top-skirt.position.y)*0.61
	lair = preload("res://scripts/bigfoot_lair_room.gd").new()
	lair.position = Vector3(0,-11,0)
	add_child(lair)
	routine.cave.rest_anchor = lair.bed
	for entry in [["See both stories",_focus_stack],["Look through lair windows",_focus_lair],["Another rock arrangement",_redress]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		_life_status.get_parent().add_child(button)
	_focus_stack()

func _redress() -> void:
	lair.redress(lair.seed_value+1)

func _focus_stack() -> void:
	_auto_orbit = false
	target = Vector3(0,0,0)
	distance = 64
	yaw = -0.45
	polar = 1.3
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _focus_lair() -> void:
	_auto_orbit = false
	target = Vector3(0,-1.0,0)
	distance = 60
	yaw = -0.05
	polar = 1.63
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _process(delta: float) -> void:
	super._process(delta)
	if lair == null: return
	lair.drips.advance(delta,_paused)
	# Underground occupancy is visible through real openings, from every view.
	creature.visible = resident_enabled and not _habitat_blocked and _growth.terrain>=0.995
	if routine.cave.concealed:
		_life_status.text = "Bigfoot · sleeping downstairs · P pause" if not _paused else "Bigfoot · paused · P pause"

func _focus_bigfoot() -> void:
	if routine != null and routine.cave.concealed and lair != null:
		_focus_lair()
		return
	super._focus_bigfoot()

func _reset_camera(reference_pose := false) -> void:
	if lair != null: _focus_stack()
	else: super._reset_camera(reference_pose)
