extends SceneTree
## The almanac's pages (scripts/almanac_pages.gd, docs/design/hud-5/PAGES.md)
## in the product scene, headless: opens the plain, puts the pages on it (as
## --pages-preview would, without the strip), and checks the layout and hit
## tests, choosing a mood card, a pin through every chip row with its knot,
## unpinning and Back to mood, a swatch and Mix drags, the wind's chips and
## dial, and Esc and frame clicks closing the page. Headless draws nothing, so
## it writes the vignettes (rasterised SVG) to /tmp/zs-hud/ and says so for
## the pages.
##   Godot --headless --fixed-fps 60 --path . -s res://tools/probe_almanac_pages.gd -- --modeless --no-title

const Pages = preload("res://scripts/almanac_pages.gd")
const Mood = preload("res://scripts/mood_look.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const OUT := "/tmp/zs-hud"

var scene: Node3D
var mood: Node
var pages: Control
var failures := 0
var closes := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ")+what)
	if not ok: failures += 1

func frames(n: int) -> void:
	for i in range(n): await process_frame

func settle() -> void:
	while mood.fading(): await process_frame
	await frames(2)

func mouse(point: Vector2, pressed: bool) -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	return pages.handle_event(event)

func click(point: Vector2) -> bool:
	var used := mouse(point,true)
	mouse(point,false)
	await frames(2)
	return used

func drag(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	pages.handle_event(event)

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	pages.handle_event(event)

func centre(kind: String, id := "", value: Variant = null) -> Vector2:
	return pages.item_rect(kind,id,value).get_center()

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("Almanac pages probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-pages-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(0.5).timeout
	mood = scene.mood_look
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	pages = Pages.new()
	layer.add_child(pages)
	pages.setup(scene)
	pages.closed.connect(func() -> void: closes += 1)
	pages.pointer_override = Vector2(200,450)
	var screen := root.get_visible_rect().size
	print("Viewport %s, mood '%s', pins %s" % [screen,mood.mood,mood.pins])

	# --- Moods page: layout and hit tests.
	pages.open("moods")
	await frames(30)
	var rect: Rect2 = pages.page_rect()
	var px: float = pages.ui_scale
	print("Moods page %s at %.2f px per design px" % [rect,px])
	check(absf(rect.size.x-320.0*px) <= 1.0,"moods page is 320 wide")
	check(absf(rect.end.x-(screen.x-116.0*px)) <= 1.0,"its right edge is 116 from the frame's")
	check(absf(rect.get_center().y-screen.y*0.5) <= 1.0,"vertically centred")
	check(rect.position.y >= 0.0 and rect.end.y <= screen.y,"on screen (%.0f tall)" % rect.size.y)
	var ids: Array = Mood.mood_ids()
	var all_cards := true
	for id: String in ids:
		var card: Rect2 = pages.item_rect("card",id)
		all_cards = all_cards and card.size.x > 90.0*px and rect.encloses(card) and pages._item_at(card.get_center()).get("id") == id
	check(all_cards,"%d cards three to a row, each hit-tests to itself" % ids.size())
	check(pages.item_rect("world").size == Vector2.ZERO,"no This world row while the look is the world's own")
	check(pages._item_at(centre("link","customise")).get("id") == "customise","CUSTOMISE link hit-tests")
	pages.pointer_override = centre("card","nordic_night")
	await frames(15)
	check(pages.hovered == "card:nordic_night:<null>","hovering a card: %s (the foot shows it)" % pages.hovered)

	# --- Choosing a card.
	var sky_before: Color = scene._celestial.look.colors.sky
	await click(centre("card","golden_meadow"))
	check(mood.mood == "golden_meadow" and mood.fading(),"a card click chooses golden meadow, cross-fading")
	await settle()
	check(scene._celestial.look.colors.sky.is_equal_approx(Color(SceneLookPresets.PRESETS.golden_meadow.colors.sky)) and not sky_before.is_equal_approx(scene._celestial.look.colors.sky),
		"the look changed to the mood's sky (%s -> %s)" % [sky_before.to_html(false),scene._celestial.look.colors.sky.to_html(false)])
	await frames(2)
	check(pages.item_rect("world").size.y > 0.0,"This world row appears once the look differs")
	await click(centre("card","golden_meadow"))
	check(pages.is_open(),"a click on the chosen card keeps the page open")

	# --- Closing: frame click, strip, Esc.
	pages.pointer_override = Vector2(200,450)
	var used := await click(Vector2(300,450))
	await frames(20)
	check(used and not pages.is_open() and closes == 1 and pages.shown < 0.01,"a click on the empty frame closes the page")
	pages.open("moods")
	await frames(20)
	used = await click(Vector2(screen.x-40.0*px,450))
	check(not used and pages.is_open(),"a click on the strip's column leaves it open (the strip's own)")
	escape()
	await frames(20)
	check(not pages.is_open() and closes == 2,"Esc closes the page")

	# --- Customise.
	pages.open("moods")
	await frames(20)
	await click(centre("link","customise"))
	await frames(20)
	rect = pages.page_rect()
	check(pages.page == "customise" and absf(rect.size.x-360.0*px) <= 1.0,"CUSTOMISE link opens the 360 wide Customise page")
	check(rect.position.y >= 0.0 and rect.end.y <= screen.y,"on screen (%.0f tall, content %.0f)" % [rect.size.y,pages._content_h])
	var minis := 0
	for id: String in [""]+ids:
		if pages._item_at(centre("mini",id)).get("id") == id: minis += 1
	check(minis == ids.size()+1,"%d mini vignettes, each hit-tests to itself (%d)" % [ids.size()+1,minis])
	await click(centre("mini","first_snow"))
	check(mood.mood == "first_snow","a mini switches the mood without leaving")
	await settle()
	check(pages.item_rect("back").size == Vector2.ZERO,"no Back to mood without knots")
	var picks := {"season":"spring","time":"dusk","weather":"mist","wind":"gale","rock_type":"slate"}
	for row: String in picks:
		var at := centre("chip",row,picks[row])
		check(pages._item_at(at).get("value") == picks[row],"%s chip %s hit-tests" % [row,picks[row]])
		await click(at)
		await settle()
		var now: String = mood.value(row)
		var shows: bool = now == picks[row] if row != "wind" else Mood.wind_parts(now).get("id") == picks[row]
		check(mood.pinned(row) and shows and pages.item_rect("knot",row).size.x > 0.0,"%s pinned to %s through mood_look, with a knot (%s)" % [row,picks[row],now])
	var time_turning := centre("chip","time","turning")
	check(time_turning != Vector2.ZERO,"Time lists Turning day")
	check(pages.item_rect("back").size.x > 0.0,"Back to mood shows while knots exist")
	# The wind.
	var air: Node = scene._atmosphere
	check(absf(float(air.strength)-1.3) < 0.01,"Gale sets the prevailing strength (%.2f)" % air.strength)
	for entry: Dictionary in Mood.WIND_STRENGTHS:
		await click(centre("chip","wind",entry.id))
		await settle()
		check(absf(float(air.strength)-float(entry.strength)) < 0.01 and Mood.wind_strength_id(air.strength) == entry.id,"%s chip: strength %.2f" % [entry.title,air.strength])
	var dial: Rect2 = pages.item_rect("dial","wind")
	check(dial.size.x > 0.0 and absf(dial.size.x-22.0*px) <= 1.0,"a 22 px dial on the Wind row")
	mouse(dial.get_center()+Vector2(0,-8)*px,true)
	check(absf(angle_difference(deg_to_rad(float(air.direction_angle)),deg_to_rad(-90.0))) < 0.03 and not mood.fading(),"pressing the dial's top turns the wind north (%.0f deg), directly" % air.direction_angle)
	drag(dial.get_center()+Vector2(8,0)*px)
	check(absf(angle_difference(deg_to_rad(float(air.direction_angle)),0.0)) < 0.03,"dragging it round to the right turns it east (%.0f deg)" % air.direction_angle)
	mouse(dial.get_center()+Vector2(8,8)*px,false)
	check(str(mood.pins.get("wind","")) == Mood.wind_pin("gale",45.0),"the wind pin holds strength and heading (%s)" % mood.pins.get("wind",""))
	var chosen_wind := str(mood.pins.wind)
	mood.choose("nordic_night")
	await settle()
	check(str(mood.pins.get("wind","")) == chosen_wind and absf(float(air.strength)-1.3) < 0.01 and absf(float(air.direction_angle)-45.0) < 0.5,"the pinned wind survives a mood change")

	# --- Knots.
	var knot: Rect2 = pages.item_rect("knot","season")
	pages.pointer_override = knot.get_center()
	await frames(15)
	check(pages.hovered.begins_with("knot:season"),"hovering the season knot (halo and Unpin tip)")
	await click(knot.get_center())
	check(not mood.pinned("season") and pages._ghosts.size() == 1,"a knot click unpins, leaving a ghost knot")
	await create_timer(0.5).timeout
	check(pages._ghosts.is_empty(),"the ghost fades within 400 ms")
	await frames(2)
	check(pages.item_rect("knot","season").size == Vector2.ZERO,"the season knot is gone")
	pages.pointer_override = Vector2(200,450)
	await click(centre("back"))
	await settle()
	await frames(2)
	check(mood.pins.is_empty() and pages.item_rect("back").size == Vector2.ZERO and not pages._items.any(func(it: Dictionary) -> bool: return it.kind == "knot"),"Back to mood clears every knot and hides itself")

	# --- Colours: a swatch, then Mix.
	await click(centre("colour","grass"))
	check(pages.colour_open == "grass" and pages.item_rect("swatch","grass",5).size.x > 0.0,"clicking Grass opens its six swatches")
	var swatch: String = Mood.swatches("grass")[2]
	await click(centre("swatch","grass",2))
	await settle()
	check(mood.value("grass") == swatch and mood.pinned("grass") and pages.item_rect("knot","grass").size.x > 0.0,"a swatch sets grass %s and ties a knot" % swatch)
	await click(centre("mix","grass"))
	check(pages.mixing and pages.item_rect("groove","grass",2).size.x > 0.0,"Mix replaces the swatches with three grooves")
	var light: Rect2 = pages.item_rect("groove","grass",2)
	var track: Rect2 = pages._groove_track(light)
	mouse(Vector2(track.position.x+track.size.x*0.25,light.get_center().y),true)
	var dark := Color(mood.value("grass"))
	check(absf(dark.v-0.25) < 0.02 and not mood.fading(),"pressing Light a quarter along sets it live (v %.2f)" % dark.v)
	drag(Vector2(track.position.x+track.size.x*0.8,light.get_center().y))
	var lit := Color(mood.value("grass"))
	check(absf(lit.v-0.8) < 0.02 and scene._celestial.look.colors.grass.is_equal_approx(lit),"dragging it along lightens it live, on the look (v %.2f)" % lit.v)
	mouse(Vector2(track.position.x+track.size.x*0.8,light.get_center().y),false)
	var hue: Rect2 = pages.item_rect("groove","grass",0)
	var hue_track: Rect2 = pages._groove_track(hue)
	mouse(Vector2(hue_track.position.x+hue_track.size.x*0.6,hue.get_center().y),true)
	mouse(Vector2(hue_track.position.x+hue_track.size.x*0.6,hue.get_center().y),false)
	check(absf(Color(mood.value("grass")).h-0.6) < 0.02,"Hue sets the hue (%.2f)" % Color(mood.value("grass")).h)
	escape()
	await frames(2)
	check(not pages.mixing and pages.is_open() and pages.item_rect("swatch","grass",0).size.x > 0.0,"Esc in Mix goes back to the swatches")
	escape()
	await frames(20)
	check(not pages.is_open(),"a second Esc closes the page")

	# --- open() with a row.
	pages.open("customise","rock")
	await frames(3)
	check(pages._flash_row == "rock_type" and pages._flash > 0.0,"open(customise, rock) lights the Rock row")
	pages.open("customise","c_water")
	await frames(3)
	check(pages.colour_open == "water","open(customise, c_water) opens Water's swatches")
	pages.close()
	await frames(20)

	# --- Pictures.
	DirAccess.make_dir_recursive_absolute(OUT)
	write_vignettes()
	check(pages.draws > 100,"the drawing code ran %d times without errors" % pages.draws)
	# The dummy renderer has no viewport image to read back.
	print("  note  headless draws no canvas: no page PNG, only the vignettes")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)

## Every mood's card vignette (This world first) on one sheet, 3x scaled.
func write_vignettes() -> void:
	var size: Vector2 = Icons.VIGNETTE_SIZES.card*3.0
	var ids: Array = [""]+Mood.mood_ids()
	var sheet := Image.create(int(size.x+12)*5+12,int(size.y+12)*2+12,false,Image.FORMAT_RGBA8)
	sheet.fill(Color(0.384,0.345,0.290))
	var distinct := {}
	for i in range(ids.size()):
		var source: Dictionary = pages._vignette_source(ids[i])
		var texture: Texture2D = Icons.vignette_texture(Pages.seed_of(ids[i]),source.sky,source.glow,source.grass,source.hour,size)
		if texture == null: continue
		var image := texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		distinct[image.get_data().hex_encode().md5_text()] = true
		sheet.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(12+(i%5)*int(size.x+12),12+(i/5)*int(size.y+12)))
	check(distinct.size() == ids.size(),"ten distinct mood vignettes")
	var path := OUT+"/almanac-vignettes.png"
	check(sheet.save_png(path) == OK,"wrote "+path)
