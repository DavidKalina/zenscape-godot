extends "res://studies/fidelity.gd"
## The full imported Fidelity world, alive: its pond's fish, the wind's
## fallen wood, the life a blank world draws (scripts/land_life.gd), and the
## sounds and shudder of shaping. The habitat (where things may stand and
## walk) is read for the fish's homes and the wood's sites.
var habitat = preload("res://scripts/fidelity_habitat.gd").new()
var navigation = preload("res://scripts/creature_navigation.gd").new()
var fish: Node
var dead_wood: Node
var _habitat_changed := false
var land_life: Node3D
## Stroke voices, creation beds and life's one-shots (scripts/genesis_audio.gd).
var genesis_audio: Node
## The shaping tools' and the HUD's sound (scripts/clay_sound.gd), with the clay.
var clay_sound: Node
## The land's shudder under the shaping tools (scripts/clay_tremor.gd).
var clay_tremor: Node

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Fidelity"
	habitat.setup($Reference,_chunk_editor.data)
	_chunk_editor.play_geometry_changed.connect(_geometry_changed)
	_chunk_editor.formation_started.connect(_geometry_changed)
	navigation.rebuild(habitat,habitat.clear_at,0.35,0.3)
	fish = preload("res://scripts/fidelity_fish.gd").new()
	add_child(fish)
	fish.setup(self)
	dead_wood = preload("res://scripts/dead_wood.gd").new()
	add_child(dead_wood)
	dead_wood.setup(self)
	# Blank worlds: fish, frogs, birds and fireflies find the land you made
	# (docs/scenic/life.md). The Fidelity world keeps its authored life.
	land_life = preload("res://scripts/land_life.gd").new()
	add_child(land_life)
	land_life.setup(self)
	genesis_audio = preload("res://scripts/genesis_audio.gd").new()
	add_child(genesis_audio)
	genesis_audio.setup(self)
	if land_clay != null:
		clay_sound = preload("res://scripts/clay_sound.gd").new()
		add_child(clay_sound)
		clay_sound.setup(land_clay)
		clay_tremor = preload("res://scripts/clay_tremor.gd").new()
		add_child(clay_tremor)
		clay_tremor.setup(land_clay,_tremor)

func _process(delta: float) -> void:
	super._process(delta)
	# The fish read the habitat for their water, and it is only read again
	# when asked (`_refresh_habitat`): once the land changes, or on a blank
	# world (LandLife's fish live there), it describes water that is not
	# there, and they would hang over dry grass. They stand down until the
	# habitat is current again.
	var fish_current: bool = not _habitat_changed and not _chunk_editor.data.blank
	if fish != null: fish.visible = fish_current
	if _paused: return
	if fish != null and fish_current: fish.advance(delta)
	if dead_wood != null: dead_wood.advance(delta)

func _geometry_changed() -> void:
	_habitat_changed = true

func _refresh_habitat(budgeted := false) -> void:
	if _habitat_changed or not budgeted:
		_habitat_changed = false
		habitat.setup($Reference,_chunk_editor.data)
		navigation.begin_rebuild(habitat,habitat.clear_at,0.35,0.3,budgeted)
	if budgeted:
		if not navigation.advance_rebuild(2000): return
	else:
		while not navigation.advance_rebuild(1000000): pass
	# New trees, new places for the wind to drop wood. Branches already lying on
	# the ground keep the spot they fell on.
	if dead_wood != null: dead_wood.rebuild_sites()

func capture_fish_state() -> Dictionary:
	return fish.capture_state() if fish != null else {"version":1,"stored_ids":[]}

func restore_fish_state(state: Dictionary) -> void:
	if fish != null: fish.restore_state(state)

func capture_wood_state() -> Dictionary:
	return dead_wood.capture_state() if dead_wood != null else {"version":1,"branches":[]}

func restore_wood_state(state: Dictionary) -> void:
	if dead_wood != null: dead_wood.restore_state(state)
