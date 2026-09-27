extends RefCounted
## The Sound part of the Settings dialog (studies/diorama.gd, also opened from
## the creation shell's World > Sound): mute everything, the Master volume and
## the creation Sound volume (the Genesis bus: strokes, creation beds and life's
## one-shots). Kept in user://sound.cfg by scripts/genesis_audio.gd.

const Audio = preload("res://scripts/genesis_audio.gd")

static func build(options: Container) -> void:
	var settings := Audio.load_settings()
	var mute := CheckButton.new()
	mute.text = "Mute all sound"
	mute.button_pressed = bool(settings.muted)
	mute.focus_mode = Control.FOCUS_NONE
	mute.toggled.connect(func(value: bool) -> void: Audio.change("muted",value))
	options.add_child(mute)
	_slider(options,"Master","master",float(settings.master))
	_slider(options,"Sound · painting, creatures and the land's beds","sound",float(settings.sound))

static func _slider(options: Container, title: String, key: String, value: float) -> void:
	var label := Label.new()
	label.text = title
	options.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(level: float) -> void: Audio.change(key,level))
	options.add_child(slider)
