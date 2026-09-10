extends SceneTree
## One whole world year, scrubbed past the camera so the calendar can be
## watched doing its work: spring showers, a bright summer, the gold of autumn
## and a white winter, with the sun still rising and setting over each day.
##
## The clock genuinely runs. Nothing pins `season_override`; the tool only sets
## `day_length` so a world day fits in FRAMES_PER_DAY recorded frames, turns the
## weather scheduler on with a fixed seed, and lets `_apply_season()` carry the
## year into the ground the way it does in play. Each recorded frame takes
## SUBSTEPS ordinary simulation steps, so the surface weather (gold, cold, ice,
## snow cover) has real seconds to ease into the season instead of lagging a
## quarter behind it.
##
## A label in its own CanvasLayer, and a line per frame in `year-log.txt` beside
## the frames, say which day, season and sky each image is.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_year.gd \
##     --fixed-fps 30 -- --clean --cam=43,1.13,1.8893,0,3,0 \
##     --film-frames=1120 --film-dir=/private/tmp/zenscape-year-frames
##   ffmpeg -y -framerate 30 -i /private/tmp/zenscape-year-frames/%04d.jpg \
##     -vf format=yuv420p -color_range tv -c:v libx264 -pix_fmt yuv420p \
##     -crf 20 -movflags +faststart /private/tmp/zenscape-year.mp4
##
## 1120 frames is 28 world days at FRAMES_PER_DAY, and 37 s of video at 30 fps.
## The frames come out of the scene's own film path at a fixed 1/30 s, so the
## framerate is the flat 30 the day-cycle films use, not a measured fps.txt.

const FRAMES_PER_DAY := 40   ## 1.33 s of video per world day at 30 fps: 28 days -> 1120 frames.
const SUBSTEPS := 3          ## Simulation steps per recorded frame.
const SEED := 20260910       ## Fixed, so the year's weather is the same every run.
const LOG_NAME := "year-log.txt"
const FRAME_SIZE := Vector2i(1280, 800)

var scene: Node3D
var clock: WorldClock
var label: Label
var log_path := ""
var last_line := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	_hold_frame_size()
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	clock = scene.world_clock
	# --film-frames sets the length; without it (a live preview) fall back to
	# the length this tool is tuned for, so the year still runs at film pace.
	var frames: int = scene._film_frames if scene._film_frames > 0 else clock.year_days * FRAMES_PER_DAY
	var per_day := float(frames) / float(maxi(clock.year_days, 1))
	# hours per substep = 24 / (per_day * SUBSTEPS), and the clock reads
	# step * speed * 24 / day_length with step = 1 / _film_fps.
	clock.day_length = float(SUBSTEPS) * per_day / scene._film_fps
	clock.speed = 1.0
	clock.running = true
	clock.season_override = -1.0
	clock.set_time(0, 0.0)
	# A fresh, seeded scheduler: the scene's own is seeded from randi().
	scene.weather_scheduler = WeatherScheduler.new(SEED, "fair", 0.0)
	scene.weather_scheduler.enabled = true
	_build_readout()
	if not scene._film_directory.is_empty():
		log_path = scene._film_directory.path_join(LOG_NAME)
		var file := FileAccess.open(log_path, FileAccess.WRITE)
		if file != null:
			file.store_line("frame\tday\thour\tseason\tweather\tautumn\tcold\tsnow")
	print("Film year: ", frames, " frames, ", clock.year_days, " days, %.2f frames/day, day_length %.3f s" % [per_day, clock.day_length])
	process_frame.connect(step)

func step() -> void:
	if scene._film_frames > 0 and scene._processed_film_frame == scene._recorded_frames:
		return
	var frame: int = scene._recorded_frames
	_hold_frame_size()
	for i in range(SUBSTEPS):
		scene._processed_film_frame = -1
		scene._process(1.0 / scene._film_fps)
	_report(frame)

## The project opens maximized (display/window/size/mode=3) and the window
## manager re-applies that several frames after the window is shown, which would
## change the image size partway through the film and break the encode. Asking
## once is not enough, so every frame checks and takes the size back.
func _hold_frame_size() -> void:
	if root.size == FRAME_SIZE: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = FRAME_SIZE

## The readout the film is for: which day of which season, and what the sky is
## doing. Kept on its own layer so `--clean` still hides the study's own UI.
func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	root.add_child(layer)

func _report(frame: int) -> void:
	var weather: String = scene._precipitation.PRESET_NAMES[scene._precipitation.preset_index]
	var season := WorldClock.name_for_season(clock.season)
	var surface: RefCounted = scene._precipitation.surface_weather
	label.text = "Day %d of %d · %s · %02d:%02d · %s" % [
		clock.day + 1, clock.year_days, season.capitalize(),
		int(clock.hour) % 24, int(clock.hour * 60.0) % 60, weather]
	var line := "%d\t%d\t%05.2f\t%s\t%s\t%.2f\t%.2f\t%.2f" % [
		frame, clock.day, clock.hour, season, weather,
		surface.autumn, surface.cold, surface.snow_cover]
	if not log_path.is_empty():
		var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
			file.store_line(line)
	# One printed line per change of day or sky keeps the console readable.
	var marker := "%d|%s|%s" % [clock.day, season, weather]
	if marker != last_line:
		print("FILM YEAR ", line)
		last_line = marker
