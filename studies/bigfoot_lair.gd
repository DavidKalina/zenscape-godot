extends "res://studies/bigfoot_cave.gd"
## Two visible stories in the same world; inspection only changes camera framing.
var _invitation_notice := ""
var _invitation_notice_time := 0.0


func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Two-story Bigfoot diorama"
	restore_cave_state({"genome":preload("res://scripts/inland_genome.gd").cave(37),"stash":[]})
	for entry in [["See both stories",_focus_stack],["Look through lair windows",_focus_lair],["Generate another cave",_regenerate],["Change cave palette",_change_palette],["Another rock arrangement",_redress],["Gather a branch",_gather_branch],["Bring home a fish",_bring_fish]]:
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
	# Underground occupancy is visible through real openings, from every view.
	creature.visible = resident_enabled and not _habitat_blocked and _growth.terrain>=0.995
	if routine.cave.concealed:
		_life_status.text = ("Bigfoot · storing supplies downstairs · P pause" if routine.cave.reason=="forage" else "Bigfoot · sleeping downstairs · P pause") if not _paused else "Bigfoot · paused · P pause"
	if _invitation_notice_time>0.0:
		_invitation_notice_time = maxf(0.0,_invitation_notice_time-delta)
		_life_status.text = _invitation_notice

func _focus_bigfoot() -> void:
	if routine != null and routine.cave.concealed and lair != null:
		_focus_lair()
		return
	super._focus_bigfoot()

func _reset_camera(reference_pose := false) -> void:
	if lair != null: _focus_stack()
	else: super._reset_camera(reference_pose)

func _regenerate() -> void:
	var state := capture_cave_state()
	state.genome.seed = (int(state.genome.seed)+1)%1000000
	restore_cave_state(state)

func _change_palette() -> void:
	var state := capture_cave_state()
	var names: Array = preload("res://scripts/cave_genome.gd").PALETTES.keys()
	state.genome.palette = names[(names.find(state.genome.palette)+1)%names.size()]
	restore_cave_state(state)

func _gather_branch() -> void:
	routine.cancel("gathering invited")
	if not routine.request("tree"): _life_status.text = "Bigfoot · no nearby reachable tree"

func _bring_fish() -> void:
	routine.cancel("fishing invited")
	_invitation_notice_time = 0.0
	if not routine.request("fish",{},true):
		_invitation_notice = "Bigfoot · no reachable fishing spot · try another shore or clear a path"
		_invitation_notice_time = 6.0
		_life_status.text = _invitation_notice
