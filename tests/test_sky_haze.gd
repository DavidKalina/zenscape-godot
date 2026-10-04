extends SceneTree
## The glide's aerial perspective (scripts/sky_haze.gd): its colour is the
## sky's horizon through the day, golden hour and night (never lifting the
## dark); its curve keeps near things clear and is whole by the distance
## islets are built and islands let go; a rising island is hidden in it
## until it has risen; and it is off in the build view, where the old haze
## stands as it was. Headless, so the shaders are compiled, not drawn: the
## look itself is unverified here.
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const Celestial = preload("res://studies/celestial.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	_shaders()
	_colour()
	_curve()
	_emerging()
	await _flight()
	print("PASS: sky haze" if failures == 0 else "FAIL: sky haze")
	quit(1 if failures else 0)

func _shaders() -> void:
	var blend: Shader = load("res://shaders/reference_air_blend.gdshader")
	var names: Array = blend.get_shader_uniform_list().map(func(e: Dictionary) -> String: return e.name)
	check(names.has("glide_emerge_lo") and names.has("surface_fog_color"),"The display haze compiles with the glide's haze")
	var puff: Shader = load("res://shaders/sky_cloud_puff.gdshader")
	check(puff.get_shader_uniform_list().size() > 0,"The glide's clouds compile with it")
	var haze := FileAccess.get_file_as_string("res://shaders/reference_surface_haze.gdshaderinc")
	check(haze.contains("vec3 col = zsSkyBase(toward);"),"Its colour is the dome's own gradient")
	check(haze.contains("if (zs_glide_haze.x > 0.0)"),"The build view's haze runs untouched while it is off")
	check(is_equal_approx(SkyHaze.SEA,SkyFlight.SEA_Y),"It lies thickest at the cloud sea")

## The dome's horizon (zsSkyBase at the horizon, shaders/reference_sky_common
## .gdshaderinc), ported apart from SkyHaze, before the night's dimming.
func _dome(state: Dictionary, flat: Vector3) -> Vector3:
	var sun: Vector3 = state.zs_sun_direction
	var col: Vector3 = (state.zs_sky_down as Vector3).lerp(state.zs_sky_up,smoothstep(-0.4,0.7,0.0))
	var to_sun := Vector2(flat.x,flat.z).normalized().dot(Vector2(sun.x,sun.z).normalized())*0.5+0.5
	col += state.zs_sky_glow*lerpf(1.0,to_sun*to_sun*1.6+0.08,state.zs_dusk_direction)
	var away := 1.0-to_sun
	col += Vector3(0.42,0.13,0.16)*exp(-0.01/0.012)*away*away*state.zs_belt
	col = col.lerp(col*Vector3(0.55,0.62,0.8),away*0.5*state.zs_belt)
	return col

func _colour() -> void:
	var sun := DirectionalLight3D.new()
	var rim := DirectionalLight3D.new()
	root.add_child(sun)
	root.add_child(rim)
	var sky = Celestial.new()
	sky.setup([sun,rim] as Array[DirectionalLight3D])
	var lumas := {}
	for hour: Array in [["morning",0.32],["noon",0.5],["golden",0.705],["dusk",0.745],["night",0.0]]:
		sky.set_phase(hour[1])
		var state: Dictionary = sky.state
		var s: Vector3 = state.zs_sun_direction
		# Looking across the sky away from the sun, where no aureole lies.
		var flat := Vector3(-s.x,0.0,-s.z).normalized()
		var dome := _dome(state,flat)
		var haze := SkyHaze.horizon(state,flat)
		var night := float(state.zs_night)*float(state.zs_celestial_clear)
		var want := dome*lerpf(1.0,0.4,night)
		var top := maxf(maxf(want.x,want.y),want.z)
		if top > 0.98: want *= 0.98/top
		var off := Vector3(haze.r,haze.g,haze.b).distance_to(want)
		var old: Vector3 = sky.surface_fog_color
		# Down at the islands under the eye, over the Opal sea.
		var down := Vector3(flat.x,-0.3,flat.z).normalized()
		var opal := SkyHaze.horizon(state,down,Vector2(1.0,0.0))
		print("     %s: horizon #%s, glide haze #%s, under the eye over Opal #%s, Mystic #%s; build haze #%s" % [hour[0],Color(want.x,want.y,want.z).to_html(false),haze.to_html(false),opal.to_html(false),SkyHaze.horizon(state,down,Vector2(1.0,2.0)).to_html(false),Color(old.x,old.y,old.z).to_html(false)])
		check(off < 0.01,"At %s the glide's haze is the horizon's colour (off by %.4f)" % [hour[0],off])
		check(SkyHaze.horizon(state,down).is_equal_approx(haze),"At %s with no sea, below the horizon it stays the horizon's" % hour[0])
		if hour[0] == "night":
			check(opal.get_luminance() < 0.03,"At night under the eye it stays as dark as the sea there (luminance %.3f)" % opal.get_luminance())
			check(haze.get_luminance() <= Color(dome.x,dome.y,dome.z).get_luminance()+0.0001,"At night it never lifts the dark sky")
		else:
			var dusty := func(c: Color) -> float: return (c.r-c.b)/maxf(maxf(c.r,maxf(c.g,c.b)),1e-4)
			var air := SkyHaze.sea_air(state,want,0)
			check(opal.is_equal_approx(Color(air.x,air.y,air.z)),"At %s under the eye it is the Opal sea's far air" % hour[0])
			check(opal.get_luminance() >= haze.get_luminance()-0.03,"At %s the sea's air is never murkier than the horizon" % hour[0])
			# By day it is cleaner; low sun keeps its warm peach sea.
			if hour[0] in ["morning","noon"]: check(dusty.call(opal) < dusty.call(haze),"At %s the sea's air is cleaner than the dusty horizon glow" % hour[0])
		lumas[hour[0]] = haze.get_luminance()
		if hour[0] == "golden":
			var toward := SkyHaze.horizon(state,Vector3(s.x,0.0,s.z).normalized())
			check(toward.r-toward.b > haze.r-haze.b,"At golden hour it warms toward the sun")
	check(lumas.night < lumas.dusk and lumas.night < lumas.noon,"Night's haze is darker than the day's")
	# Another look's sky: Meadow's mint horizon, not the default's rose.
	sky.look.choose("Meadow")
	sky.set_phase(0.5)
	var flat := Vector3(1,0,0)
	var want := _dome(sky.state,flat)
	var meadow := SkyHaze.horizon(sky.state,flat)
	var old: Vector3 = sky.surface_fog_color
	print("     Meadow noon: horizon #%s, glide haze #%s, build haze #%s" % [Color(want.x,want.y,want.z).to_html(false),meadow.to_html(false),Color(old.x,old.y,old.z).to_html(false)])
	check(Vector3(meadow.r,meadow.g,meadow.b).distance_to(want*minf(1.0,0.98/maxf(want.x,maxf(want.y,want.z)))) < 0.01,"Under another look it is that look's horizon")
	sun.queue_free()
	rim.queue_free()

func _curve() -> void:
	var at := func(d: float) -> float: return SkyHaze.fog(d,0.0)
	print("     fog at 0/100/300/500/700/900 m: %.3f %.3f %.3f %.3f %.3f %.3f" % [at.call(0.0),at.call(100.0),at.call(300.0),at.call(500.0),at.call(700.0),at.call(900.0)])
	check(at.call(0.0) == 0.0 and at.call(30.0) < 0.01,"Near things keep their colour")
	check(at.call(100.0) < 0.06,"An island 100 m off is barely hazed")
	check(at.call(400.0) > 0.35 and at.call(400.0) < 0.7,"The nearest far island is half in the haze")
	var rising := true
	for d in range(0,1200,10): rising = rising and at.call(d+10.0) >= at.call(float(d))
	check(rising,"The haze only thickens with distance")
	check(is_equal_approx(SkyHaze.WHOLE,SkyIslets.VIEW),"It is whole where islets are built")
	check(at.call(SkyIslets.VIEW) >= 0.999 and at.call(SkyIslets.FORGET) >= 0.999,"Islets come and go fully hidden")
	check(at.call(SkyIslets.VIEW*0.95) > 0.97,"Just inside the view an islet is still all but hidden")
	check(SkyHaze.fog(300.0,SkyHaze.SEA) > SkyHaze.fog(300.0,0.0),"Low toward the cloud sea the air is thicker")
	check(SkyHaze.fog(300.0,40.0) == SkyHaze.fog(300.0,0.0),"Up among the islands it is even")

class FakeEditor extends RefCounted:
	var terrain: Node3D
class FakeIslands extends Node:
	var editor := FakeEditor.new()
	var offsets: Array[Vector3] = []
	var depth: Array[float] = []
	func sunk(i: int) -> float: return depth[i]

func _emerging() -> void:
	var islands := FakeIslands.new()
	islands.editor.terrain = Node3D.new()
	root.add_child(islands.editor.terrain)
	islands.offsets = [Vector3(300,0,0),Vector3(-400,10,0),Vector3(0,0,500)]
	islands.depth = [0.0,SkyIslands.WANDER_RISE.x,SkyIslands.WANDER_RISE.x*0.5]
	var boxes := SkyHaze.emerging(islands,Vector3.ZERO)
	check(boxes.size() == 2,"Only the islands still rising are hidden")
	check(boxes[0][2] == 1.0 and boxes[1][2] == 0.5,"Nearest first, each by how far it has still to come")
	var lo: Vector3 = boxes[0][0]
	var hi: Vector3 = boxes[0][1]
	var middle := Vector3(-400,10-SkyIslands.WANDER_RISE.x,0)
	check(lo.x < middle.x-SkyIslands.HALF and hi.x > middle.x+SkyIslands.HALF and lo.y < middle.y+NativeTerrainData.SLAB_BASE and hi.y > middle.y,"Its box holds the whole sunken slab")
	islands.editor.terrain.free()
	islands.free()

func _flight() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var flight := SkyFlight.new()
	scene.add_child(flight)
	flight.setup(scene)
	check(flight.haze == 0.0,"In the build view the glide's haze is off")
	flight.start(Vector3(14,2,0))
	check(flight.haze == 1.0,"Off the edge it is on at once, before the islands bake in")
	flight.advance(1.0/60.0,Vector3(20,0,0),0.0)
	check(flight.haze == 1.0,"It holds through the glide")
	flight.stop()
	for i in range(int(SkyFlight.SETTLE*60.0)+5): await process_frame
	check(flight.haze == 0.0,"Landed, it is gone and the build view's haze stands alone")
	scene.queue_free()
	await process_frame
