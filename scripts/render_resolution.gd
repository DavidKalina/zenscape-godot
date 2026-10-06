extends RefCounted
## The 3D world's render resolution: drawn at no more than the chosen height
## and scaled up to the window,
## the HUD and menus staying sharp at the window's own size. A Retina window
## of 1440×900 is 2880×1800 pixels, four times a 1080p screen's worth of
## cloud sea (shaders/sky_sea.gdshader) and peaks to shade; capped, it costs
## what a 1080p one does. Upscaled by MetalFX on Metal, else FSR, both spatial
## so the drifting cloud and the wind in the grass never ghost. Kept in
## user://look.cfg (scripts/look_pass.gd SETTINGS_PATH) under [display], and
## offered in the Settings dialog (studies/diorama.gd) by `build`. Until the
## player chooses, a discrete GPU draws at the window's own resolution and
## anything else (integrated, Apple's) at 1080 lines (`default_cap`).

const SETTINGS_PATH := "user://look.cfg"
## Each choice's most lines high; 0 draws at the window's own resolution.
const CAPS := [0,1440,1080,720]
const CAP_NAMES := ["Native","1440p","1080p","720p"]
const DEFAULT_CAP := 1080

## The cap until the player chooses: none on a discrete GPU, full fidelity
## for the cards that can carry it; 1080 lines on anything else.
static func default_cap(device_type := RenderingServer.get_video_adapter_type()) -> int:
	return 0 if device_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else DEFAULT_CAP

## Draws `viewport`'s 3D at the kept cap now and whenever it is resized.
static func attach(viewport: Viewport) -> void:
	var update := func() -> void: apply(viewport,load_cap())
	viewport.size_changed.connect(update)
	update.call()

static func apply(viewport: Viewport, cap: int) -> void:
	# In pixels: a Retina window's visible rect is in points, half its pixels.
	var height := float((viewport as Window).size.y if viewport is Window else (viewport as SubViewport).size.y)
	var scale := 1.0 if cap <= 0 or height <= cap else cap/height
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL if RenderingServer.get_current_rendering_driver_name() == "metal" else Viewport.SCALING_3D_MODE_FSR
	viewport.scaling_3d_scale = scale

static func load_cap(path := SETTINGS_PATH) -> int:
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section_key("display","max_lines"): return default_cap()
	var cap := int(file.get_value("display","max_lines"))
	return cap if cap in CAPS else default_cap()

static func save_cap(cap: int, path := SETTINGS_PATH) -> void:
	var file := ConfigFile.new()
	file.load(path)
	file.set_value("display","max_lines",cap)
	file.save(path)

## The Settings dialog's "Render resolution" choice, applied at once.
static func build(options: Container, viewport: Viewport) -> void:
	var label := Label.new()
	label.text = "Render resolution"
	options.add_child(label)
	var choice := OptionButton.new()
	choice.name = "RenderResolution"
	for cap_name: String in CAP_NAMES: choice.add_item(cap_name)
	choice.select(CAPS.find(load_cap()))
	choice.item_selected.connect(func(index: int) -> void:
		save_cap(CAPS[index])
		apply(viewport,CAPS[index]))
	options.add_child(choice)
