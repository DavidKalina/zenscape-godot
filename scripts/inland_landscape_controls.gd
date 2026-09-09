extends VBoxContainer
const Genome = preload("res://scripts/inland_genome.gd")
var choices := {}
var seed_box := SpinBox.new()
var relief := SpinBox.new()
var breadth := SpinBox.new()
var form_button := Button.new()
var scene: Node3D
func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "Wild landscapes"
	var help := Label.new()
	help.text = "Tall peaks, broad valleys and desert country.\nGenerate a new landscape, then sculpt and save it."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	for pair in [["composition",Genome.COMPOSITIONS],["archetype",Genome.ARCHETYPES],["landform",Genome.LANDFORMS],["biome",Genome.HABITATS]]:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = "Habitat" if pair[0] == "biome" else pair[0].capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var choice := OptionButton.new()
		for value in pair[1]: choice.add_item(value.capitalize())
		row.add_child(choice)
		choices[pair[0]] = {"control":choice,"values":pair[1]}
	choices.landform.control.select(6)
	choices.composition.control.item_selected.connect(func(index: int) -> void:
		var composition: String = Genome.COMPOSITIONS[index]
		var desert: bool = composition in preload("res://scripts/desert_landscape.gd").KINDS
		choices.biome.control.select(4 if desert else 3 if composition == "marsh" else 1)
		choices.landform.control.select(4 if composition == "valley" else 6 if composition in ["mountain","massif"] else 0))
	for spec in [[seed_box,"Seed",0,999999,1,7],[relief,"Height",0.5,1.8,0.05,1.0],[breadth,"Breadth",0.6,1.5,0.05,1.0]]:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = spec[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin: SpinBox = spec[0]
		spin.min_value = spec[2]; spin.max_value = spec[3]; spin.step = spec[4]; spin.value = spec[5]
		row.add_child(spin)
	form_button.text = "Generate landscape"
	form_button.pressed.connect(func() -> void: await scene._chunk_editor.form_inland(recipe()))
	add_child(form_button)
	var another := Button.new()
	another.text = "Another seed"
	another.pressed.connect(func() -> void: seed_box.value = randi_range(0,999999))
	add_child(another)
	visibility_changed.connect(sync_from_world)
func recipe() -> Dictionary:
	var result := {"kind":"inland","version":3,"seed":int(seed_box.value),"relief":relief.value,"breadth":breadth.value}
	for key in choices: result[key] = choices[key].values[choices[key].control.selected]
	return result
func _process(_delta: float) -> void:
	if scene != null: form_button.disabled = scene._chunk_editor.forming

func sync_from_world() -> void:
	if not is_visible_in_tree() or scene == null: return
	var current: Dictionary = scene._chunk_editor.data._recipe_settings
	if current.get("kind") != "inland": return
	seed_box.value = current.seed
	relief.value = current.relief
	breadth.value = current.breadth
	for key in choices: choices[key].control.select(choices[key].values.find(current[key]))
