extends SceneTree
## Headless checks for the HUD 5 almanac (scripts/almanac.gd,
## docs/design/hud-5/ALMANAC.md), in two parts.
##
## On its own (no world): layout and hit tests, rest and reach, quiet while a
## drag is under way, the tag to the left with its whisper, the one-shot cues,
## whispers retiring and staying retired across a restart, `page_requested`
## from the Mood pocket and a tag, and an icon sheet at /tmp/zs-hud/almanac.png.
##
## In the game (the hand scheme): each pocket's click changes the world (the
## hour, season, weather, wind strength and heading) and ties a pin, through
## the hand's own press path; the almanac counts as a bar for the hand; and
## the real gestures (the snap, the sky's held sweep, the shake, a spin into
## another season) retire their whispers.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_almanac.gd -- --modeless --no-title

const Almanac = preload("res://scripts/almanac.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Linen = preload("res://scripts/hud_linen.gd")
const Mood = preload("res://scripts/mood_look.gd")
const VoidSnap = preload("res://scripts/void_snap.gd")
var failures := []
var pages := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("almanac probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	await frames(2)
	sheet()
	await alone()
	await in_game()
	print("failures=%d %s" % [failures.size(),failures])
	quit(1 if failures.size() > 0 else 0)

# --- The icon sheet ------------------------------------------------------------------

func sheet() -> void:
	var px := 88.0
	var cell := int(px*Icons.BOX/24.0)
	var ids := ["sun","moon","globe"]
	for season: String in Icons.SEASON_TINT: ids.append("plate_"+season)
	for deg: int in Icons.SOCK_DROOPS: ids.append(Icons.sock_id(deg))
	var looks := [
		{"sky":Color("7ea3c4"),"glow":Color("e8dcc0"),"grass":Color("6c9a58"),"time":"day","seed":24},
		{"sky":Color("9c7a6c"),"glow":Color("e2a462"),"grass":Color("b0703c"),"time":"low","seed":26},
		{"sky":Color("2a3452"),"glow":Color("5c7c9c"),"grass":Color("3a5048"),"time":"night","seed":31},
		{"sky":Color("a8b2be"),"glow":Color("e8e8ea"),"grass":Color("dde3e8"),"time":"day","seed":30},
	]
	var vignette := Vector2i(176,110)
	var image := Image.create(maxi(cell*ids.size(),vignette.x*looks.size()),cell*2+vignette.y,false,Image.FORMAT_RGBA8)
	image.fill(Color("5d6873"))
	for i in range(ids.size()):
		var row := 0
		for variant: String in ["icon","lit"]:
			var tex := Icons.texture(ids[i],variant,px)
			if tex == null:
				check("texture %s %s" % [ids[i],variant],false)
				continue
			var icon := tex.get_image()
			icon.convert(Image.FORMAT_RGBA8)
			image.blend_rect(icon,Rect2i(Vector2i.ZERO,icon.get_size()),Vector2i(i*cell,row*cell))
			if variant == "icon":
				var seen := {}
				for y in range(0,icon.get_height(),3):
					for x in range(0,icon.get_width(),3):
						var c := icon.get_pixel(x,y)
						if c.a > 0.99: seen[c.to_html(false)] = true
				if icon.get_pixel(1,1).a > 0.01 or seen.size() < 4: check("icon %s clipped and faceted" % ids[i],false,seen.size())
			row += 1
	# The crescent is a crescent: its centre (inside the bite) is clear.
	var moon := Icons.texture("moon","icon",px).get_image()
	var bite := Vector2(15.8+Icons.PAD,8.4+Icons.PAD)*px/24.0
	check("the moon's bite is empty",moon.get_pixelv(Vector2i(bite)).a < 0.05)
	check("the moon's limb is solid",moon.get_pixelv(Vector2i(Vector2(4.0+Icons.PAD,14.0+Icons.PAD)*px/24.0)).a > 0.9)
	for i in range(looks.size()):
		var picture := Image.new()
		var ok := picture.load_svg_from_string(Almanac.vignette_svg(looks[i]),vignette.x/40.0) == OK
		check("vignette %d rasterises" % i,ok)
		if not ok: continue
		picture.convert(Image.FORMAT_RGBA8)
		image.blend_rect(picture,Rect2i(Vector2i.ZERO,picture.get_size()),Vector2i(i*vignette.x,cell*2))
		if i == 0:
			var sky := picture.get_pixel(20,8)
			var land := picture.get_pixel(int(21.0/40.0*vignette.x),int(18.0/25.0*vignette.y))
			check("vignette: sky blue above, grass green on the slab",sky.b > sky.r and land.g > land.b,[sky,land])
	DirAccess.make_dir_recursive_absolute("/tmp/zs-hud")
	image.save_png("/tmp/zs-hud/almanac.png")
	print("sheet /tmp/zs-hud/almanac.png")

# --- On its own --------------------------------------------------------------------

func alone() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var almanac := Almanac.new()
	almanac.settings_path = "/tmp/zs-almanac-probe-%d.cfg" % Time.get_ticks_usec()
	layer.add_child(almanac)
	almanac.setup(null,null)
	almanac.page_requested.connect(func(page: String, row: String) -> void: pages.append([page,row]))
	almanac.want(true)
	almanac.pointer_override = Vector2(720,400)
	await frames(40)
	var s := almanac.ui_scale
	var strip := almanac.strip_rect()
	print("strip ",strip," scale ",s)
	check("in the hud_piece group",almanac.is_in_group("hud_piece"))
	check("shown, at rest",almanac.shown > 0.99 and almanac.awake < 0.01)
	check("rest opacity 0.6",absf(almanac.modulate.a-0.6) < 0.02,almanac.modulate.a)
	check("80 design px wide",absf(strip.size.x-80.0*s) < 2.0,strip.size.x/s)
	check("about 370 design px tall",absf(strip.size.y/s-370.0) < 12.0,strip.size.y/s)
	check("centred vertically",absf(strip.get_center().y-450.0) < 1.0)
	check("at rest 6 px out to the right (24-6 from the edge)",absf(1440.0-strip.end.x-(24.0-6.0)*s) < 1.0,(1440.0-strip.end.x)/s)
	for id: String in Almanac.POCKETS:
		check("pocket %s hit-tests to itself" % id,almanac.pocket_at(almanac.pocket_centre(id)) == id)
	check("60 px pockets",absf(almanac._cell(1).size.y-60.0*s) < 1.0)
	check("mood above the stitch, then time",almanac._cell(1).position.y-almanac._cell(0).end.y > 20.0*s)
	check("nothing hit off the strip",almanac.pocket_at(Vector2(720,400)).is_empty() and not almanac.contains_pointer(Vector2(720,400)))
	# Reach: past x 1260.
	almanac.pointer_override = Vector2(1270,120)
	await frames(24)
	strip = almanac.strip_rect()
	check("reached past x 1260",almanac.awake > 0.99 and absf(almanac.modulate.a-1.0) < 0.01,almanac.awake)
	check("reached, 24 px in",absf(1440.0-strip.end.x-24.0*s) < 1.0,(1440.0-strip.end.x)/s)
	almanac.pointer_override = Vector2(1250,120)
	await frames(10)
	check("holds 300 ms before receding",almanac.awake > 0.99)
	await frames(40)
	check("recedes when the pointer leaves",almanac.awake < 0.01,almanac.awake)
	almanac.page_open = true
	await frames(24)
	check("a page open keeps it reached",almanac.awake > 0.99)
	almanac.page_open = false
	await frames(60)
	# Quiet: a drag never wakes it.
	almanac.quiet = true
	almanac.pointer_override = Vector2(1400,450)
	await frames(30)
	check("a drag toward the edge leaves it down",almanac.awake < 0.01 and almanac.hovered.is_empty(),almanac.awake)
	almanac.quiet = false
	# Hover Weather: tag to the left, the whisper, one cue.
	almanac.pointer_override = almanac.pocket_centre("weather")
	await frames(20)
	check("weather hovered",almanac.hovered == "weather")
	var tag := almanac._tag_rect("weather")
	check("the tag hangs to the LEFT of the strip",tag.end.x <= almanac.strip_rect().position.x and tag.size.x > 0.0,tag)
	check("its whisper names the shake",almanac.whisper("weather") == "or shake the plate")
	check("the tag has two lines",tag.size.y > (Linen.TAG_SIZE+Almanac.WHISPER_SIZE)*s)
	check("the jiggle started once",int(almanac.cues_played.get("weather",0)) == 1,almanac.cues_played)
	check("the jiggle's steps",Almanac.jiggle_angle(0.09) == -9.0 and Almanac.jiggle_angle(0.18) == 7.0 and Almanac.jiggle_angle(0.27) == -4.0 and Almanac.jiggle_angle(0.4) == 0.0)
	await frames(30)
	check("and stopped: no loop while still hovered",almanac._states.weather.cue < 0.0 and int(almanac.cues_played.weather) == 1,almanac._states.weather.cue)
	for id: String in ["time","season","wind"]:
		almanac.pointer_override = almanac.pocket_centre(id)
		await frames(3)
		var started: bool = almanac._states[id].cue >= 0.0
		await frames(int(Almanac.CUE_END[id]*60.0)+4)
		check("%s cue plays once and ends" % id,started and almanac._states[id].cue < 0.0 and int(almanac.cues_played.get(id,0)) == 1)
	almanac.pointer_override = almanac.pocket_centre("mood")
	await frames(10)
	check("the Mood has no cue or whisper",not almanac.cues_played.has("mood") and almanac.whisper("mood").is_empty())
	# Clicks with no world: the Mood asks for its page; a tag asks for Customise.
	check("the Mood's press is the almanac's",almanac.press(almanac.pocket_centre("mood")))
	check("the Mood pocket asks for the Moods page",pages.back() == ["moods",""],pages)
	almanac.pointer_override = almanac.pocket_centre("season")
	await frames(20)
	var season_tag := almanac._tag_rect("season")
	almanac.pointer_override = season_tag.get_center()
	await frames(5)
	check("the tag stays while the pointer crosses onto it",almanac.hovered == "season" and almanac.tag_at(season_tag.get_center()) == "season")
	check("a press on the tag is the almanac's",almanac.press(season_tag.get_center()))
	check("the tag opens Customise at its row",pages.back() == ["customise","season"],pages)
	check("and presses the pocket",almanac._states.season.press > 0.5)
	# Retiring.
	almanac.retire("weather")
	check("retired: no whisper",almanac.whisper("weather").is_empty())
	almanac.pointer_override = almanac.pocket_centre("time")
	await frames(20)
	almanac.pointer_override = almanac.pocket_centre("weather")
	await frames(20)
	check("retired: the tag stays",almanac._tag_rect("weather").size.x > 0.0 and almanac.tag_text("weather").begins_with("Weather"))
	check("retired: no cue on a new hover",int(almanac.cues_played.weather) == 1,almanac.cues_played)
	var again := Almanac.new()
	again.settings_path = almanac.settings_path
	layer.add_child(again)
	again.setup(null,null)
	check("retired for good (read back from the settings)",again.retired.get("weather",false) and not again.retired.get("time",false),again.retired)
	layer.queue_free()
	await frames(2)

# --- In the game -----------------------------------------------------------------

func in_game() -> void:
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-almanac-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await frames(30)
	var reach: Node = scene.hand_reach
	var materials: Node = reach.materials
	check("the game is the hand scheme with the tray",scene.hand_only == true and materials != null)
	var almanac: Control = materials.almanac
	check("the almanac is made with the roll",almanac != null and almanac.get_parent() == materials.roll.get_parent())
	almanac.settings_path = "/tmp/zs-almanac-probe-game-%d.cfg" % Time.get_ticks_usec()
	almanac.retired = {}
	var mood: Node = scene.mood_look
	var point := func(at: Vector2) -> void:
		almanac.pointer_override = at
		reach.pointer_override = at
		scene._chunk_editor.pointer_override = at
	point.call(almanac.pocket_centre("time"))
	await frames(30)
	check("reached in the game",almanac.shown > 0.99 and almanac.awake > 0.99,[almanac.shown,almanac.awake])
	check("the hand treats it as a bar (tray_under)",materials.tray_under(almanac.pocket_centre("wind")))
	var tap := func(at: Vector2) -> void:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = at
		reach.handle(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = at
		reach.handle(up)
	# Time: the snap.
	var night := VoidSnap.is_night(float(scene._celestial.phase))
	var snaps: int = reach.snaps
	tap.call(almanac.pocket_centre("time"))
	await frames(3)
	check("Time: day and night swap",VoidSnap.is_night(float(scene._celestial.phase)) != night,[night,scene._celestial.phase])
	check("Time: through the snap's own path",reach.snaps == snaps+1)
	check("Time: pinned, knot shown",mood.pinned("time") and almanac.pinned("time"),mood.pins)
	check("Time: its own click does not retire the whisper",not almanac.retired.get("time",false))
	check("Time: the pocket draws the new body",almanac._night() == (not night))
	await frames(80)
	# Season.
	var season: String = mood.value("season")
	tap.call(almanac.pocket_centre("season"))
	await frames(3)
	var ids: Array = Mood.SEASONS.map(func(e: Dictionary) -> String: return e.id)
	check("Season: the next season",mood.value("season") == ids[(ids.find(season)+1)%4],[season,mood.value("season")])
	check("Season: pinned",mood.pinned("season"))
	await frames(80)
	# Weather.
	var weather: String = mood.value("weather")
	tap.call(almanac.pocket_centre("weather"))
	await frames(3)
	var wids: Array = Mood.WEATHERS.map(func(e: Dictionary) -> String: return e.id)
	check("Weather: the next weather",mood.value("weather") == wids[(wids.find(weather)+1)%wids.size()],[weather,mood.value("weather")])
	check("Weather: pinned",mood.pinned("weather"))
	await frames(80)
	# Wind: a click steps the strength.
	var wind: String = almanac._wind_id()
	tap.call(almanac.pocket_centre("wind"))
	await frames(3)
	var kinds: Array = Mood.WIND_STRENGTHS.map(func(e: Dictionary) -> String: return e.id)
	var next: String = kinds[(kinds.find(wind)+1)%4]
	check("Wind: the next strength",almanac._wind_id() == next,[wind,almanac._wind_id()])
	check("Wind: pinned",mood.pinned("wind"),mood.pins.get("wind"))
	check("Wind: the tag names it",almanac.tag_text("wind").begins_with("Wind · "+str(Almanac._wind_entry(next).title)+", from the "),almanac.tag_text("wind"))
	await frames(80)
	check("Wind: the air's strength lands on it after the 1.2 s fade",absf(float(scene._atmosphere.strength)-float(Almanac._wind_entry(next).strength)) < 0.01,scene._atmosphere.strength)
	# Wind: a drag across it turns the heading.
	var at: Vector2 = almanac.pocket_centre("wind")
	var heading := float(scene._atmosphere.direction_angle)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	reach.handle(down)
	check("Wind: the press holds for a drag",reach.holding == "almanac")
	for k in range(1,7):
		var motion := InputEventMouseMotion.new()
		motion.position = at+Vector2(10.0*k*almanac.ui_scale,0.0)
		motion.relative = Vector2(10.0*almanac.ui_scale,0.0)
		point.call(motion.position)
		reach.handle(motion)
		await frames(1)
	check("Wind: its own drag keeps it awake",almanac.awake > 0.99 and not almanac.quiet)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at+Vector2(60.0*almanac.ui_scale,0.0)
	reach.handle(up)
	await frames(3)
	var turned := angle_difference(deg_to_rad(heading),deg_to_rad(float(scene._atmosphere.direction_angle)))
	check("Wind: the drag turned the heading 90 degrees",absf(rad_to_deg(turned)-60.0*Almanac.TURN_PER_PIXEL) < 1.0,rad_to_deg(turned))
	check("Wind: the heading is pinned with the strength",Mood.wind_parts(str(mood.pins.get("wind",""))).has("degrees") and almanac._wind_id() == next,mood.pins.get("wind"))
	check("Wind: let go",reach.holding.is_empty())
	await frames(80)
	# A mood keeps the pins.
	mood.choose("first_snow")
	await frames(90)
	check("a new mood keeps the wind pin",almanac._wind_id() == next and absf(angle_difference(deg_to_rad(heading),deg_to_rad(float(scene._atmosphere.direction_angle)))-turned) < 0.02)
	# Mood and its tag.
	tap.call(almanac.pocket_centre("mood"))
	check("Mood: asks for the Moods page",materials.page_asked == ["moods",""],materials.page_asked)
	point.call(almanac.pocket_centre("wind"))
	await frames(20)
	tap.call(almanac._tag_rect("wind").get_center())
	check("Wind's tag: Customise at the wind row",materials.page_asked == ["customise","wind"],materials.page_asked)
	# Quiet while another drag is under way.
	point.call(Vector2(720,450))
	await frames(60)
	reach.take_hold("scatter",Vector2(720,450))
	point.call(almanac.pocket_centre("season"))
	await frames(30)
	check("a drag in progress never wakes it",almanac.quiet and almanac.awake < 0.01,almanac.awake)
	reach.drop_hold()
	await frames(30)
	check("after the drag it reaches again",almanac.awake > 0.99)
	# The real gestures retire the whispers.
	reach.fire_snap()
	await frames(2)
	check("the sky's snap retires Time's whisper",almanac.retired.get("time",false) and almanac.whisper("time").is_empty())
	var sky: RefCounted = reach.wind
	sky.press(Vector2(700,40))
	sky.state = "steer"
	sky.release(Vector2(760,60))
	await frames(2)
	check("the sky's held sweep retires Wind's",almanac.retired.get("wind",false))
	scene.snow_globe.shake_started.emit()
	check("the shake retires Weather's",almanac.retired.get("weather",false))
	check("Season's still speaks",not almanac.retired.get("season",false))
	scene.spin_time._wind(scene.world_clock,24.0*8.0)
	for i in range(600):
		await process_frame
		if almanac.retired.get("season",false): break
	check("a spin into another season retires Season's",almanac.retired.get("season",false))
	var config := ConfigFile.new()
	check("and it is saved",config.load(almanac.settings_path) == OK and bool(config.get_value("whispers","season",false)))
