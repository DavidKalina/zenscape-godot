extends SceneTree
## The plate's season reaches the sky layer (shaders/sky_season.gdshaderinc):
## the year's quarters (WeatherScheduler.season_sky) are smooth all round and
## never pass through summer between winter and spring; the scene publishes
## them as `zs_sky_season` when they change and not every frame; the peaks'
## snow line comes down through autumn into winter and goes back up to the
## summits by summer, the far faces and the skyline's agreeing with the
## near ones; and the cloud sea takes the season in all three styles, a
## slight grade each quarter. Headless: functions, meshes' arrays and the
## shaders' source, nothing drawn.
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
const LivingWeather = preload("res://scripts/living_weather.gd")
const PeakTest = preload("res://tests/test_sky_peaks.gd")
const SEASON_NAMES := ["spring","summer","autumn","winter"]
const SEEDS := [101,2024,77777]
var failures := 0
var floors := Vector4.ZERO
var taper := 0.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	_quarters()
	_shaders()
	var falls := _snow_falls()
	_snow_line(falls)
	_low_range(falls)
	_sea_mood()
	await _published()
	print("PASS: sky seasons" if failures == 0 else "FAIL: sky seasons (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## The quarters: pure at each season E lands on, summing to one, smooth, and
## winter hands straight to spring.
func _quarters() -> void:
	for q in range(4):
		var w := WeatherScheduler.season_sky(float(LivingWeather.SEASONS[q]))
		check(is_equal_approx(w[q],1.0),"E's %s landing is all %s: %s" % [SEASON_NAMES[q],SEASON_NAMES[q],str(w)])
	var worst_sum := 0.0
	var worst_step := 0.0
	var summer_in_thaw := 0.0
	var last := WeatherScheduler.season_sky(0.0)
	for i in range(1,2001):
		var year := float(i)/2000.0
		var w := WeatherScheduler.season_sky(year)
		worst_sum = maxf(worst_sum,absf(w.x+w.y+w.z+w.w-1.0))
		worst_step = maxf(worst_step,(w-last).abs()[(w-last).abs().max_axis_index()])
		if year > 0.85 or year < 0.15: summer_in_thaw = maxf(summer_in_thaw,w.y+w.z)
		last = w
	check(worst_sum < 0.01,"The quarters always sum to one (worst %.4f)" % worst_sum)
	check(worst_step < 0.05,"The quarters change smoothly through the year (largest step %.3f a 1/2000 year)" % worst_step)
	check(summer_in_thaw == 0.0,"From winter to spring the year passes through no summer or autumn")
	check(WeatherScheduler.season_sky(0.0).x > 0.99,"Day 0 of a fresh garden is spring, the sky as it was drawn")
	check(ProjectSettings.get_setting("shader_globals/zs_sky_season",{}).get("value",Vector4.ZERO) == Vector4(1,0,0,0),"The global defaults to spring, so a sky with no clock looks as drawn")

## The peaks' material and the sky read the season; both shaders still parse.
func _shaders() -> void:
	var surface: Shader = load("res://shaders/reference_surface.gdshader")
	var names: Array = surface.get_shader_uniform_list().map(func(e: Dictionary) -> String: return e.name)
	check(names.has("peak_snow") and names.has("sea_cut"),"The ground shader parses and takes the peaks' snow")
	var code := surface.code
	check("sky_season.gdshaderinc" in code and "zs_sky_peak_snowy(UV.x" in code,"The ground shader lays the peaks' snow by the season's fall and floor")
	check("zs_sky_summer_grass(tint)" in code,"The peaks' grass dries a little through the summer")
	check("sea_cut <= -1.0e8" in code,"The plate's snow cover leaves the peaks to their own line")
	var sky: Shader = load("res://shaders/reference_sky.gdshader")
	var sky_names: Array = sky.get_shader_uniform_list().map(func(e: Dictionary) -> String: return e.name)
	check(sky_names.has("cloud_sea_style") and sky_names.has("cloud_sea"),"The sky shader parses")
	var peaks := SkyPeaks.new()
	var material: ShaderMaterial = peaks._ground()
	check(material.shader.resource_path == "res://shaders/reference_surface.gdshader" and float(material.get_shader_parameter("sea_cut")) > -1.0e8,"The ranges are drawn with that shader, gated as peaks")
	peaks.free()

## The snow line's fall per quarter (m), as the shader has it.
func _snow_falls() -> Vector4:
	var text := FileAccess.get_file_as_string("res://shaders/sky_season.gdshaderinc")
	var falls := _vec4(text,"ZS_SKY_SNOW_FALL")
	check(falls.x == 0.0,"Spring leaves the snow line where it was drawn")
	check(falls.y < falls.z and falls.z < falls.x and falls.x < falls.w,"Summer's line highest, then autumn's, spring's, winter's lowest: %s" % str(falls))
	floors = _vec4(text,"ZS_SKY_SNOW_FLOOR")
	taper = _float(text,"ZS_SKY_SNOW_TAPER")
	check(floors.x == SkyPeak.SNOW_WORLD and floors.y >= SkyPeak.SNOW_WORLD and floors.z >= SkyPeak.SNOW_WORLD,"Spring, summer and autumn keep the drawn floor (%.0f m)" % SkyPeak.SNOW_WORLD)
	check(floors.w < SkyPeak.SNOW_WORLD and floors.w > 40.0 and taper >= 2.0,"Winter's floor is lower, %.0f m, tapering %.1f m a metre under it" % [floors.w,taper])
	return falls

## zs_sky_peak_snowy, as the shader runs it, in quarter `q` alone.
func _snowy(need: float, y: float, q: int, falls: Vector4, scale := 1.0) -> bool:
	var fall: float = falls[q]/scale
	var floor_at: float = SkyPeak.SEA+(floors[q]-SkyPeak.SEA)/scale
	var under := maxf(floor_at-y,0.0)*taper if need >= 0.0 else 0.0
	return fall > need+under

## A range as the game makes it, placed scaled `height` in height: its
## snow line no lower than the drawn floor (SkyPeaks `_make`).
func _range(seed_value: int, height := 1.0) -> RefCounted:
	var peak: RefCounted = SkyPeak.make(seed_value)
	peak.snowline = maxf(peak.snowline,SkyPeak.snow_floor(height))
	return peak

## The snow line on real ranges, near faces and far and the skyline's.
func _snow_line(falls: Vector4) -> void:
	var snow := Color(0.9,0.93,0.96)
	for s: int in SEEDS:
		var peak: RefCounted = _range(s)
		var arrays: Array = peak.body_arrays([Color(0.1,0.3,0.1)],[Color(0.27,0.23,0.18)],Color(0.3,0.3,0.28),Vector3.ZERO,1,snow)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var need: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var counts := []
		var lowest := []
		var summit_snow := []
		var steep_snow := []
		var steep := 0
		for q in range(4):
			var fall: float = falls[q]
			var count := 0
			var low := INF
			var top_snow := 0
			var top := 0
			var sheer := 0
			for k in range(0,vertices.size(),3):
				var y := (vertices[k].y+vertices[k+1].y+vertices[k+2].y)/3.0
				var snowy := _snowy(need[k].x,y,q,falls)
				var n := (vertices[k+2]-vertices[k]).cross(vertices[k+1]-vertices[k]).normalized()
				if y > peak.top-40.0:
					top += 1
					if snowy: top_snow += 1
				if absf(n.y) < 0.3 and y > peak.top-120.0:
					if q == 0: steep += 1
					if snowy: sheer += 1
				if snowy:
					count += 1
					low = minf(low,y)
			counts.append(count)
			lowest.append(low)
			summit_snow.append(float(top_snow)/maxf(top,1.0))
			steep_snow.append(sheer)
		check(counts[3] > counts[0] and counts[0] > counts[2] and counts[2] > counts[1],"Seed %d: more faces snowed in winter than spring, autumn, summer (%s)" % [s,str(counts)])
		check(counts[3] > counts[0]*1.5,"Seed %d: winter's snow is generous above its floor, over half again spring's (%d to %d)" % [s,counts[3],counts[0]])
		check(float(lowest[3]) <= float(lowest[0]),"Seed %d: winter's snow comes at least as low as spring's (%.0f to %.0f m)" % [s,lowest[3],lowest[0]])
		var dust := _winter_dust(arrays,falls,1.0)
		check(dust < 0.12,"Seed %d: under the drawn floor winter adds only a dusting (%.1f%% of that ground)" % [s,dust*100.0])
		check(float(lowest[1]) > float(lowest[0])+40.0,"Seed %d: summer's snow keeps well above spring's (%.0f to %.0f m)" % [s,lowest[1],lowest[0]])
		check(float(summit_snow[1]) > 0.15,"Seed %d: summer still holds snow on the summits (%.0f%% of the top faces)" % [s,float(summit_snow[1])*100.0])
		check(int(steep_snow[3]) < steep,"Seed %d: even in winter the sheerest faces up high stay bare rock (%d of %d)" % [s,steep_snow[3],steep])
		# Spring as drawn: exactly the faces the range was always snowed on.
		var drawn := PeakTest._as_drawn(arrays,falls.x,snow)
		var white := 0
		for k in range(0,drawn.size(),3):
			if drawn[k].b > 0.8 and drawn[k].g > 0.8: white += 1
		check(white == counts[0],"Seed %d: in spring the snowed faces are the ones drawn white (%d, %d)" % [s,white,counts[0]])
		# The far faces and the skyline's read the same line.
		for stride: int in [SkyPeaks.LOD_STRIDE,SkyRing.STRIDE]:
			var coarse: Array = peak.body_arrays([Color(0.1,0.3,0.1)],[Color(0.27,0.23,0.18)],Color(0.3,0.3,0.28),Vector3.ZERO,stride,snow)
			var gaps := []
			for q in range(4):
				gaps.append(snappedf(_snow_share(arrays,falls,q)-_snow_share(coarse,falls,q),0.001))
			print("     seed %d stride %d gaps %s" % [s,stride,str(gaps)])
			var worst := 0.0
			for q in range(4): worst = maxf(worst,absf(float(gaps[q])))
			check(worst < 0.08,"Seed %d: faces at every %d-th point snow as the near ones do (worst band %.3f)" % [s,stride,worst])

## Under the drawn floor (SNOW_WORLD, the world's height), the share of
## the face area winter snows that was bare as drawn, on a range placed
## scaled `height` about the sea.
func _winter_dust(arrays: Array, falls: Vector4, height: float) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var need: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var low := SkyPeak.snow_floor(height)
	var area := 0.0
	var white := 0.0
	for k in range(0,vertices.size(),3):
		var y := (vertices[k].y+vertices[k+1].y+vertices[k+2].y)/3.0
		if y < SkyPeak.SEA or y > low: continue
		var a := (vertices[k+1]-vertices[k]).cross(vertices[k+2]-vertices[k]).length()*0.5
		area += a
		if need[k].x >= 0.0 and _snowy(need[k].x,y,3,falls,height): white += a
	return white/maxf(area,1.0)

## A low range, as a wall's low stretch or a foothill stands (its top not
## far over the drawn floor): winter leaves it a dusting, never a blanket.
func _low_range(falls: Vector4) -> void:
	for s: int in SEEDS:
		var height := 0.5
		var peak: RefCounted = _range(s,height)
		var top_world: float = SkyPeak.SEA+(peak.top-SkyPeak.SEA)*height
		var arrays: Array = peak.body_arrays([Color(0.1,0.3,0.1)],[Color(0.27,0.23,0.18)],Color(0.3,0.3,0.28),Vector3.ZERO,SkyRing.STRIDE)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var need: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var area := 0.0
		var white := 0.0
		for k in range(0,vertices.size(),3):
			var y := (vertices[k].y+vertices[k+1].y+vertices[k+2].y)/3.0
			if y < SkyPeak.SEA: continue
			var a := (vertices[k+1]-vertices[k]).cross(vertices[k+2]-vertices[k]).length()*0.5
			area += a
			if _snowy(need[k].x,y,3,falls,height): white += a
		check(white/maxf(area,1.0) < 0.1,"Seed %d low (top %.0f m): winter dusts it, %.1f%% of its face white" % [s,top_world,white/maxf(area,1.0)*100.0])

## How much of a range's face area is snowed, worst over 40 m height bands
## from the sea to the top, as one share per band averaged.
func _snow_share(arrays: Array, falls: Vector4, q: int) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var need: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var area := {}
	var white := {}
	for k in range(0,vertices.size(),3):
		var y := (vertices[k].y+vertices[k+1].y+vertices[k+2].y)/3.0
		if y < SkyPeak.SEA: continue
		var band := floori((y-SkyPeak.SEA)/40.0)
		var a := (vertices[k+1]-vertices[k]).cross(vertices[k+2]-vertices[k]).length()*0.5
		area[band] = float(area.get(band,0.0))+a
		if _snowy(need[k].x,y,q,falls): white[band] = float(white.get(band,0.0))+a
	var total := 0.0
	var count := 0
	for band in area:
		if float(area[band]) < 2000.0: continue
		total += float(white.get(band,0.0))/float(area[band])
		count += 1
	return total/maxf(count,1.0)

## The cloud sea's mood, the shader's own constants run on a pearl cloud
## colour: every style takes it, each quarter a slight, distinct grade.
func _sea_mood() -> void:
	var sea := FileAccess.get_file_as_string("res://shaders/sky_cloud_sea.gdshaderinc")
	var text := FileAccess.get_file_as_string("res://shaders/sky_season.gdshaderinc")
	check("sky_season.gdshaderinc" in sea and "sea.rgb = zs_sky_season_grade(sea.rgb" in sea,"The cloud sea grades its colour by the season")
	var moods := _vec3(sea,"SEA_SEASON_MOOD")
	for i in range(3):
		check(moods[i] > 0.3 and moods[i] <= 1.0,"%s takes the season's mood (%.2f)" % [["Opal","Storybook","Mystic"][i],moods[i]])
	# Each style's branch sets its own mood, so none paints without one.
	var body := sea.substr(sea.find("vec4 zs_cloud_sea(vec3 dir"))
	check(body.count("mood = SEA_SEASON_MOOD.") == 3 and "zs_cloud_sea_storybook(" in body and "zs_cloud_sea_mystic(" in body and "zs_cloud_sea_opal(" in body,"All three styles are graded")
	var hues := [_vec3(text,"ZS_SKY_MOOD_SPRING"),_vec3(text,"ZS_SKY_MOOD_SUMMER"),_vec3(text,"ZS_SKY_MOOD_AUTUMN"),_vec3(text,"ZS_SKY_MOOD_WINTER")]
	var keep := _vec4(text,"ZS_SKY_MOOD_KEEP")
	var haze := _float(text,"ZS_SKY_MOOD_HAZE")
	var pearl := Vector3(0.80,0.79,0.84)
	var luma := Vector3(0.2126,0.7152,0.0722)
	var graded := []
	for q in range(4):
		var w := Vector4.ZERO
		w[q] = 1.0
		graded.append(_grade(pearl,w,hues,keep,haze,1.0))
	for q in range(4):
		var g: Vector3 = graded[q]
		var shift := (g-pearl).abs()
		check(shift[shift.max_axis_index()] < 0.06,"%s grades Opal's pearl gently (largest shift %.3f)" % [SEASON_NAMES[q],shift[shift.max_axis_index()]])
		check(absf(g.dot(luma)-pearl.dot(luma)) < 0.02,"%s keeps the sea's brightness (%.3f to %.3f)" % [SEASON_NAMES[q],pearl.dot(luma),g.dot(luma)])
	var warmth := func(c: Vector3) -> float: return c.x/c.z
	var spread := func(c: Vector3) -> float: return c[c.max_axis_index()]-c[c.min_axis_index()]
	check(warmth.call(graded[2]) > warmth.call(graded[1]) and warmth.call(graded[1]) > warmth.call(graded[0]) and warmth.call(graded[0]) > warmth.call(graded[3]),"Autumn the warmest (peach), then summer, spring, winter the coolest")
	check(warmth.call(graded[3]) < warmth.call(pearl) and warmth.call(graded[2]) > warmth.call(pearl)*1.03,"Winter cools the pearl to silver and autumn warms it to peach")
	# A low sun's warm cloud: winter mutes it toward silver.
	var dusk := Vector3(0.85,0.72,0.62)
	check(spread.call(_grade(dusk,Vector4(0,0,0,1),hues,keep,haze,1.0)) < spread.call(_grade(dusk,Vector4(1,0,0,0),hues,keep,haze,1.0))*0.92,"Winter is the more silvery: a warm cloud keeps less colour than in spring")
	for i in range(3):
		var a := _grade(pearl,Vector4(0,0,1,0),hues,keep,haze,moods[i])
		check((a-pearl).length() > 0.005,"%s's sea changes with the season (%.3f)" % [["Opal","Storybook","Mystic"][i],(a-pearl).length()])

## zs_sky_season_grade, as the shader runs it.
func _grade(c: Vector3, w: Vector4, hues: Array, keep: Vector4, haze: float, amount: float) -> Vector3:
	var luma := Vector3(0.2126,0.7152,0.0722)
	var hue: Vector3 = hues[0]*w.x+hues[1]*w.y+hues[2]*w.z+hues[3]*w.w
	hue /= maxf(hue.dot(luma),1e-3)
	var lum := c.dot(luma)
	var graded := Vector3.ONE*lum
	graded = graded.lerp(c,w.dot(keep))*hue
	graded = graded.lerp(Vector3.ONE*lum*hue,haze*w.y)
	return c.lerp(graded,amount).max(Vector3.ZERO)

## The scene publishes the quarters when they change, not every frame.
func _published() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var clock: WorldClock = scene.get("world_clock")
	clock.running = false
	clock.season_override = 0.375
	_step(scene,4)
	var sky: Vector4 = scene._season_sky
	check(sky == WeatherScheduler.season_sky(clock.season),"The scene holds the clock's quarters: %s" % str(sky))
	var count: int = scene.sky_season_published
	_step(scene,60)
	check(scene.sky_season_published == count,"A held season is not published again frame by frame (%d more in 60 frames)" % (scene.sky_season_published-count))
	clock.season_override = 0.87
	_step(scene,2)
	check(scene.sky_season_published == count+1 and is_equal_approx(scene._season_sky.w,1.0),"Stepping to winter publishes once: %s" % str(scene._season_sky))
	# With the glide on, E's step to spring is walked through the thaw.
	scene.season_glide = true
	count = scene.sky_season_published
	clock.season_override = 0.14
	var passed_summer := false
	var frames := 0
	while frames < 2400 and not is_equal_approx(scene._season_sky.x,1.0):
		_step(scene,1)
		frames += 1
		if scene._season_sky.y > 0.0 or scene._season_sky.z > 0.0: passed_summer = true
	var walked: int = scene.sky_season_published-count
	check(is_equal_approx(scene._season_sky.x,1.0) and not passed_summer,"The glide walks winter into spring without a summer between (%d frames)" % frames)
	check(walked > 10 and walked <= frames,"It publishes along the way, at most once a frame (%d over %d frames)" % [walked,frames])
	count = scene.sky_season_published
	_step(scene,60)
	check(scene.sky_season_published == count,"Once there, nothing more is published")
	scene.free()

func _step(scene: Node, frames: int) -> void:
	for i in range(frames): scene._process(1.0/30.0)

func _vec4(text: String, name: String) -> Vector4:
	var v := _numbers(text,name)
	return Vector4(v[0],v[1],v[2],v[3]) if v.size() >= 4 else Vector4(NAN,NAN,NAN,NAN)

func _vec3(text: String, name: String) -> Vector3:
	var v := _numbers(text,name)
	return Vector3(v[0],v[1],v[2]) if v.size() >= 3 else Vector3(NAN,NAN,NAN)

func _float(text: String, name: String) -> float:
	var v := _numbers(text,name)
	return v[0] if v.size() >= 1 else NAN

## The numbers a shader constant `name` is set to.
func _numbers(text: String, name: String) -> Array:
	var at := text.find(" "+name+" = ")
	if at < 0: return []
	var line := text.substr(at,text.find(";",at)-at)
	var rx := RegEx.new()
	rx.compile("-?\\d+\\.?\\d*")
	var out := []
	var values := line.substr(line.find("=")+1)
	if "(" in values: values = values.substr(values.find("(")+1)
	for m in rx.search_all(values):
		var s: String = m.get_string()
		out.append(float(s))
	return out
