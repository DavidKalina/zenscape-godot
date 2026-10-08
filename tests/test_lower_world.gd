extends SceneTree
## suite: slow
## The lower world under the cloud sea (scripts/sky_below.gd, `--below`)
## and its archipelago (scripts/sky_archipelago.gd, scripts/landforms.gd).
## Without the flag nothing changes: the plane's cushion is at FLOOR over no
## water, the painted sea parts under a fall, the ranges are cut at CUT and
## their heights are as they were. With it, a dive crosses into the lower
## world deep in a whole white-out with the sea never parting, the floor
## lies just over the ocean and the water is never sunk under, climbing back
## crosses back up, and a flutter at the line never flips it; the ocean
## sheet follows the plane on its own lattice, crack-free, its chop calming
## far out. The landforms' registry draws, sizes and lays out every entry.
## An island in the sea stands in the water, its wall down to the bed, a
## shelf of bed round it, its ground the land's alone. The archipelago is
## the same from the same seed, dense with water always between, builds
## round the eye and lets go far off, and --landform lays its landforms
## ahead of the way down. In the live scene the plane dives under the cloud
## into the archipelago, F brings it in to an island, it perches and the
## pilot walks it, flies off again and climbs back up into the sky. Headless,
## so the shaders are compiled, not drawn: the look is unverified here.
##   godot --headless --path . --script tests/test_lower_world.gd
const SkyBelow = preload("res://scripts/sky_below.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyArchipelago = preload("res://scripts/sky_archipelago.gd")
const Landforms = preload("res://scripts/landforms.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func air(_p: Vector3) -> Variant:
	return null

func run() -> void:
	_shaders()
	SkyBelow._on = 0
	_off()
	SkyBelow._on = 1
	_line()
	await _dive()
	await _follows()
	_sheet()
	_ranges()
	_haze()
	_landforms()
	_sea_island()
	_arch()
	_layout()
	await _streaming()
	await _forced()
	await _live()
	SkyBelow._on = -1
	print("PASS: lower world" if failures == 0 else "FAIL: lower world")
	quit(1 if failures else 0)

func _uniforms(path: String) -> Array:
	return (load(path) as Shader).get_shader_uniform_list().map(func(e: Dictionary) -> String: return e.name)

func _shaders() -> void:
	var water := _uniforms("res://shaders/reference_water.gdshader")
	check(water.has("depth_read") and water.has("below_sky"),"The islands' water compiles with the bed read per pixel and the cloud in its mirror")
	var sea := _uniforms("res://shaders/sky_ocean.gdshader")
	check(sea.has("tint_depths") and sea.has("mirror_steps") and sea.has("paws"),"The ocean's water compiles with its depth ramp, its mirror and its cat's paws")
	check(_uniforms("res://shaders/sky_below_ceiling.gdshader").has("volume_reach"),"The cloud's underside compiles")
	check(_uniforms("res://shaders/sky_below_air.gdshader").has("ceiling"),"The lower world's air compiles")
	check(_uniforms("res://shaders/cloud_volume_composite.gdshader").has("from_below"),"The cloud volume compiles with its look from beneath")
	check(_uniforms("res://shaders/reference_sky.gdshader").has("below_world"),"The sky compiles with its overcast")
	var rock := _uniforms("res://shaders/reference_surface.gdshader")
	check(rock.has("sea_open") and rock.has("below_sink"),"The ranges' rock compiles with the lower world")
	check(_uniforms("res://shaders/reference_air_blend.gdshader").has("glide_below"),"The display haze compiles with the overcast's")
	check(_uniforms("res://shaders/glide_vapour.gdshader").has("whole"),"The vapour compiles with its whole white-out")

## Without --below: the plane's cushion at FLOOR over no water, a long fall
## caught well over the sea, the sea parting, the ranges as they were.
func _off() -> void:
	check(not SkyBelow.on(),"Without --below there is no lower world")
	var plane := SkyPlane.new()
	check(plane.floor_y == SkyGlide.FLOOR and plane.water == -INF,"The floor is FLOOR (%.0f m) over no water" % plane.floor_y)
	plane.launch(Vector3(0,0,0),0.0,14.0,false)
	var lowest := INF
	for i in range(int(4.0/DT)):
		plane.step(DT,{"pitch":-1.0,"boost":1.0},air)
		lowest = minf(lowest,plane.position.y)
	for i in range(int(20.0/DT)):
		plane.step(DT,{},air)
		lowest = minf(lowest,plane.position.y)
	check(lowest > SkyFlight.SEA_Y,"A dive let go is caught over the sea (lowest %.1f m)" % lowest)
	var scene := Node3D.new()
	root.add_child(scene)
	var flight := SkyFlight.new()
	scene.add_child(flight)
	flight.setup(scene)
	flight.start(Vector3(0,0,0))
	for i in range(60): flight.advance(DT,Vector3(0,-95,0),0.0)
	check(flight.lower == null and flight.flight.w > 0.9,"Down in it the painted sea parts (%.2f)" % flight.flight.w)
	scene.free()
	check(SkyPeak.face_floor() == SkyPeak.CUT,"The ranges' faces are cut at CUT")
	check(SkyPeaks.sunk(-200.0,-105.0,-280.0) == -200.0,"Their heights are their own")

## The line: below under SEA-CROSS, back over SEA+CROSS, never between.
func _line() -> void:
	var lower := SkyBelow.new()
	check(not lower.below and not lower.ocean.visible and not lower.ceiling.visible and not lower.archipelago.visible,"It starts above, the ocean, the cloud's underside and the islands hidden")
	check(not lower.air.visible,"And the lower world's air off")
	check(SkyBelow.band(SkyBelow.SEA) == 1.0 and SkyBelow.band(-40.0) == 0.0 and SkyBelow.band(-200.0) == 0.0,"The vapour is whole at the line and clear well over and under it")
	check(SkyBelow.CEILING > SkyBelow.SEA+SkyBelow.CROSS and SkyBelow.CEILING < SkyBelow.BAND.y,"The ceiling lies just over the swap, inside the whole white-out")
	check(not lower.cross(SkyBelow.SEA-1.0) and not lower.below,"Just under the line it stays above")
	check(lower.cross(SkyBelow.SEA-SkyBelow.CROSS-0.1) and lower.below,"Deeper it crosses below")
	check(lower.ocean.visible and lower.ceiling.visible and lower.archipelago.visible,"Below, the ocean, the cloud's underside and the islands show")
	check(lower.air.visible,"And the lower world's air is laid on")
	var flips := 0
	for i in range(600):
		if lower.cross(SkyBelow.SEA+sin(i*0.37)*(SkyBelow.CROSS-0.2)): flips += 1
	check(flips == 0 and lower.below,"Fluttering at the line it never flips (%d)" % flips)
	check(lower.cross(SkyBelow.SEA+SkyBelow.CROSS+0.1) and not lower.below,"Over the line it crosses back above")
	lower.archipelago.free()
	lower.free()

## A plane and the sky under --below: dived, it crosses below under a
## white-out, the sea never parting; it skims the ocean and settles at the
## floor; climbed, it crosses back up.
func _dive() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var flight := SkyFlight.new()
	scene.add_child(flight)
	flight.setup(scene)
	var lower := SkyBelow.new()
	scene.add_child(lower)
	flight.lower = lower
	var plane := SkyPlane.new()
	plane.floor_y = SkyBelow.FLOOR
	plane.water = SkyBelow.OCEAN
	plane.launch(Vector3(0,0,0),0.0,14.0,false)
	flight.start(plane.position)
	var crossed_at := INF
	var veil_at_cross := 0.0
	var parted := 0.0
	var lowest := INF
	for i in range(int(40.0/DT)):
		plane.step(DT,{"pitch":-1.0,"boost":1.0},air)
		var was: bool = lower.below
		flight.advance(DT,plane.position,0.0)
		parted = maxf(parted,flight.flight.w)
		lowest = minf(lowest,plane.position.y)
		if lower.below and not was:
			crossed_at = plane.position.y
			veil_at_cross = flight.vapour
	check(lower.below,"Dived, it crosses into the lower world")
	check(crossed_at < SkyBelow.SEA and crossed_at > SkyBelow.SEA-40.0,"It crosses deep in the sea's vapour (%.1f m)" % crossed_at)
	check(veil_at_cross >= SkyBelow.SNAP,"Under a whole white-out (%.2f)" % veil_at_cross)
	check(parted == 0.0,"The painted sea never parts")
	check(lowest >= SkyBelow.OCEAN+SkyGlide.SKIM-0.001,"Held down, it skims the ocean and never sinks in (lowest %.2f m)" % lowest)
	for i in range(int(25.0/DT)):
		plane.step(DT,{},air)
		flight.advance(DT,plane.position,0.0)
	var y := plane.position.y
	check(y > SkyBelow.OCEAN and y < SkyBelow.FLOOR+4.0,"Let go, it flies on low over the water (%.1f m, the ocean %.0f)" % [y,SkyBelow.OCEAN])
	var off := Vector2(lower.ocean.position.x-plane.position.x,lower.ocean.position.z-plane.position.z)
	check(lower.ocean.position.y == SkyBelow.OCEAN and absf(off.x) <= SkyBelow.SHEET_STEP and absf(off.y) <= SkyBelow.SHEET_STEP,"The ocean lies under it")
	var climbed := false
	for i in range(int(60.0/DT)):
		plane.step(DT,{"pitch":1.0,"boost":1.0},air)
		flight.advance(DT,plane.position,0.0)
		if not lower.below:
			climbed = true
			break
	check(climbed and plane.position.y > SkyBelow.SEA,"Climbed, it crosses back above (%.1f m)" % plane.position.y)
	check(not lower.ocean.visible and flight.vapour > 0.5,"Back above under the vapour, the ocean hidden")
	lower.archipelago.free()
	scene.queue_free()
	await process_frame

## The ocean and the cloud's underside follow the eye, and the islands'
## swaps through the sky's flight: the ocean on its own lattice, so its
## water never swims, the ceiling's billows in home coordinates.
func _follows() -> void:
	var holder := GDScript.new()
	holder.source_code = "extends Node\nvar islands: Node3D\n"
	holder.reload()
	var keeper := GDScript.new()
	keeper.source_code = "extends Node3D\nvar origin := Vector3.ZERO\n"
	keeper.reload()
	var scene := Node3D.new()
	root.add_child(scene)
	var eye: Node = holder.new()
	scene.add_child(eye)
	var islands: Node3D = keeper.new()
	eye.add_child(islands)
	eye.islands = islands
	var flight := SkyFlight.new()
	eye.add_child(flight)
	flight.setup(scene)
	var lower := SkyBelow.new()
	eye.add_child(lower)
	flight.lower = lower
	flight.start(Vector3(0,0,0))
	var at := Vector3(830.7,-250.0,-415.3)
	flight.advance(DT,at,0.0)
	var lattice := SkyBelow.SHEET_STEP*2.0
	var p := lower.ocean.position
	check(is_equal_approx(fposmod(p.x,lattice),0.0) and is_equal_approx(fposmod(p.z,lattice),0.0) and absf(p.x-at.x) <= lattice*0.5 and absf(p.z-at.z) <= lattice*0.5,"The ocean is under the plane, on its own lattice")
	check(lower.ceiling.position.is_equal_approx(Vector3(at.x,SkyBelow.CEILING,at.z)),"The cloud's underside is over it")
	var shift := Vector3(-450.0,0.0,300.0)
	islands.origin += shift
	flight.move(shift)
	flight.advance(DT,at+shift,0.0)
	var lid: ShaderMaterial = (lower.ceiling.mesh as PlaneMesh).material
	var home: Vector2 = lid.get_shader_parameter("home")
	check(home.is_equal_approx(Vector2(shift.x,shift.z)),"After a swap the billows moved with the world")
	lower.archipelago.free()
	scene.queue_free()
	await process_frame

## The ocean's sheet: rings ever coarser out past REACH, no crack between
## them (every edge of the sheet's inside shared by two faces), drawn with
## the sea's own water (shaders/sky_ocean.gdshader), not the islands' ponds.
func _sheet() -> void:
	var mesh := SkyBelow._sheet()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var reach := 0.0
	for v in vertices: reach = maxf(reach,maxf(absf(v.x),absf(v.z)))
	print("     the sheet: %d vertices, %d triangles, out to %.0f m" % [vertices.size(),faces.size()/3,reach])
	check(reach >= SkyBelow.REACH,"The ocean reaches out past %.0f m" % SkyBelow.REACH)
	var edges := {}
	for f in range(0,faces.size(),3):
		for k in range(3):
			var a := faces[f+k]
			var b := faces[f+(k+1)%3]
			var key := Vector2i(mini(a,b),maxi(a,b))
			edges[key] = int(edges.get(key,0))+1
	var open := 0
	for key: Vector2i in edges:
		if edges[key] != 1: continue
		var a := vertices[key.x]
		var b := vertices[key.y]
		# The sheet's own outer edge is open; any other is a crack.
		if maxf(absf(a.x),absf(a.z)) < reach-0.01 or maxf(absf(b.x),absf(b.z)) < reach-0.01: open += 1
	check(open == 0,"No cracks between its rings (%d open edges inside)" % open)
	var lower := SkyBelow.new()
	var sea: ShaderMaterial = lower.ocean.material_override
	check(sea.shader.resource_path == "res://shaders/sky_ocean.gdshader" and is_equal_approx(float(sea.get_shader_parameter("below_sky")),1.0) and (sea.get_shader_parameter("tint_depths") as Vector3).is_equal_approx(SkyBelow.TINT_DEPTHS),"It is the sea's own water: its depth ramp, the cloud overhead in its mirror")
	lower.archipelago.free()
	lower.free()

## The ranges under --below: built down to just over their foot, drawn
## down so it lies under the water, solid under the ocean, and opened to
## the lower world only from below.
func _ranges() -> void:
	check(SkyPeak.face_floor() == SkyPeak.BELOW_CUT,"The ranges' faces are built on down to their foot")
	check(is_equal_approx(SkyPeaks.sunk(SkyPeak.BASE,SkyPeak.SEA,SkyPeak.BASE),SkyBelow.FOOT),"A range's foot is drawn down under the ocean")
	check(SkyPeaks.sunk(-50.0,SkyPeak.SEA,SkyPeak.BASE) == -50.0,"Over the sea it is as it was")
	var low := SkyPeaks.lift(0.15)
	var foot := SkyPeak.BASE*0.15+low
	check(foot > SkyBelow.OCEAN and SkyPeaks.sunk(foot,SkyPeak.SEA*0.15+low,foot) < SkyBelow.OCEAN,"A low ridge's foot (%.0f m) reaches the water too" % foot)
	check(SkyPeaks.sunk(-450.0,SkyPeak.SEA,-500.0) == -450.0,"One already reaching under the water is left alone")
	var peaks := SkyPeaks.new()
	var rock: ShaderMaterial = peaks._ground()
	check(rock.get_shader_parameter("below_sink") == Vector4(1.0,SkyPeak.SEA,SkyPeak.BASE,SkyBelow.FOOT),"The rock is drawn down in the shader the same way")
	check(rock.get_shader_parameter("sea_open") == false,"Above, the rock is cut at the sea as before")
	peaks.open_sea(true)
	check(rock.get_shader_parameter("sea_open") == true,"Below, it runs on down")
	peaks.free()

func _haze() -> void:
	check(SkyHaze.thickest(1.0) == SkyBelow.OCEAN and SkyHaze.thickest(0.0) == SkyHaze.SEA,"The haze is thickest by the ocean below and by the sea above")

## The registry: every entry drawn, sized and laid out; the placeholders
## island-sized.
func _landforms() -> void:
	Landforms.prepare()
	var names := Landforms.names()
	check(names.size() >= 6,"The registry lists its landforms (%s)" % ", ".join(names))
	var drawn := {}
	for i in range(400): drawn[Landforms.pick(float(i)/400.0)] = true
	check(drawn.size() == names.size(),"Every landform is drawn now and then (%d of %d)" % [drawn.size(),names.size()])
	var ok := true
	for n: String in names:
		var across := Landforms.across(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var spec := Landforms.recipe(n,rng,across.y)
		if across.x < 20.0 or across.y > 95.0 or not spec.has("kind") or absf(float(spec.get("radius",across.y*0.5))-across.y*0.5) > 0.01: ok = false
	check(ok,"Each is 20 to 95 m across and gives a recipe of that size")

## One island in the sea: its rim over the water, its wall down to the bed
## under it, a shelf of bed round it falling away, no rock hanging under it,
## the bed no ground; a big one on a coarser grid.
func _sea_island() -> void:
	for width in [30.0,85.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var spec := Landforms.recipe("meadow",rng,width)
		SkyArchipelago.dress_spec(spec,width,SkyIslet.RIM_HEIGHT-2.0,11)
		var shape: RefCounted = SkyIslet.author(11,spec)
		var level: float = spec.sea_foot.level
		var shelf: float = spec.sea_foot.shelf
		check(shape.base < level and shape.base > level-1.0 and shape.ground_at(Vector2.ZERO) > level+1.0,"%.0f m: its land over the water, the wall's foot just under it (%.2f, the water %.2f)" % [width,shape.base,level])
		var deepest := 0.0
		for k in shape.keel: deepest = maxf(deepest,k)
		check(deepest == 0.0,"%.0f m: no rock hangs under it" % width)
		# Off the land, out from the shore, the bed falls away under the water.
		var near_bed := INF
		var far_bed := INF
		var off_land := Vector2.INF
		for i in range(shape.points.size()):
			var out: float = shape.sea_out[i]
			if out > 0.0 and out < shelf*0.25: near_bed = minf(near_bed,shape.sea_bed[i])
			if out >= shelf*0.95 and out < shelf*1.05: far_bed = minf(far_bed,level-shape.sea_bed[i])
			if out > 1.0 and off_land == Vector2.INF: off_land = shape.points[i]
		check(near_bed < level and near_bed > level-SkyIslet.SEA_SHALLOW-0.2 and far_bed > 6.0,"%.0f m: a shelf, at most %.1f m under by the shore and %.1f m at its end" % [width,level-near_bed,far_bed])
		check(off_land != Vector2.INF and not shape.inside(off_land),"%.0f m: the bed is no ground" % width)
		var top: Array = shape.top_arrays(SkyIslet.plain_palette())
		var sides: Array = shape.side_arrays()
		var under := 0
		var lowest_wall := INF
		for v: Vector3 in sides[Mesh.ARRAY_VERTEX]: lowest_wall = minf(lowest_wall,v.y)
		for v: Vector3 in top[Mesh.ARRAY_VERTEX]:
			if v.y < level-0.2: under += 1
		check(under > 0 and lowest_wall >= shape.base-0.01,"%.0f m: the bed is drawn with the top (%d vertices under the water), the wall ends on it" % [width,under])
		print("     %.0f m: step %.2f m, %d points, %d top and %d side triangles" % [width,shape.step,shape.points.size(),(top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,(sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3])
		if width > 60.0: check(shape.step > SkyIslet.STEP and shape.points.size() < 12000,"A big island is on a coarser grid (%.2f m, %d points)" % [shape.step,shape.points.size()])

## The layout: the same from the same seed; dense, with water always
## between; none in a range.
## A landform's own underside raised over the water (a cliffs arch) is left
## open under a sea foot; a landform's SEA sets where the water meets it.
func _arch() -> void:
	var shape: RefCounted = SkyIslet.author(21,{"kind":"meadow","radius":16.0})
	var level := SkyIslet.RIM_HEIGHT-2.0
	var raised := []
	for i in range(shape.points.size()):
		if shape.shore_distance[i] >= 0.0 and shape.points[i].x > shape.reach*0.6:
			shape.keel[i] = shape.base-(level+1.0)
			raised.append(i)
	shape.recipe.sea_foot = {"level":level,"shelf":8.0,"depth":12.0}
	shape._lay_sea_bed(shape.recipe.sea_foot)
	var open := raised.size() > 0
	for i: int in raised:
		if not is_equal_approx(shape.base-shape.keel[i],level+1.0): open = false
	var rest := 0
	for i in range(shape.points.size()):
		if not i in raised and shape.keel[i] != 0.0: rest += 1
	check(open and rest == 0,"An underside raised over the water stays open (%d points), the rest walled down to the bed" % raised.size())
	check(is_nan(Landforms.sea_level("meadow")),"A landform without SEA leaves the water's height to the archipelago")

func _layout() -> void:
	var a := SkyArchipelago.new()
	var b := SkyArchipelago.new()
	var plans := []
	var same := true
	var span := 12
	for x in range(-span,span):
		for z in range(-span,span):
			for slot: Vector3i in SkyArchipelago.slots(Vector2i(x,z)):
				var p: Variant = a.plan(slot)
				var q: Variant = b.plan(slot)
				if (p == null) != (q == null) or (p != null and (p.landform != q.landform or p.width != q.width or p.home != q.home)): same = false
				if p != null: plans.append(p)
	check(same,"The same seed lays out the same islands")
	var overlaps := 0
	for i in range(plans.size()):
		for j in range(i+1,plans.size()):
			var d := Vector2(plans[i].home.x-plans[j].home.x,plans[i].home.z-plans[j].home.z).length()
			if d < (float(plans[i].width)+float(plans[j].width))*0.5*SkyArchipelago.LOBE+SkyArchipelago.GAP-0.01: overlaps += 1
	check(overlaps == 0,"Water always lies between two islands (%d too close)" % overlaps)
	var area := pow(span*2.0*SkyArchipelago.CELL/1000.0,2.0)
	var widths := plans.map(func(p: Dictionary) -> float: return float(p.width))
	var mean := 0.0
	for w: float in widths: mean += w/maxf(widths.size(),1)
	# The share of the open sea (off the ranges) that is an island's land.
	var probe := RandomNumberGenerator.new()
	probe.seed = 9
	var on_land := 0
	var on_coast := 0
	var open_sea := 0
	for t in range(3000):
		var at := Vector2(probe.randf_range(-span+1,span-1),probe.randf_range(-span+1,span-1))*SkyArchipelago.CELL
		if SkyPeaks.blocks(Vector3(at.x,0.0,at.y)): continue
		open_sea += 1
		var nearest_shore := INF
		for p: Dictionary in plans: nearest_shore = minf(nearest_shore,Vector2(p.home.x,p.home.z).distance_to(at)-float(p.width)*0.5)
		if nearest_shore < 0.0: on_land += 1
		if nearest_shore < 15.0: on_coast += 1
	var cover := float(on_land)/maxf(open_sea,1)
	var coast := float(on_coast)/maxf(open_sea,1)
	print("     %d islands over %.1f km^2 (%.0f a km^2), %.0f m across on average; of the open sea %.0f%% land, %.0f%% land or within 15 m of a shore" % [plans.size(),area,plans.size()/area,mean,cover*100.0,coast*100.0])
	check(cover > 0.2,"A sea thick with islands (%.0f%% land)" % (cover*100.0))
	# From anywhere over the sea, land within a few hundred metres.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var far := 0
	var tries := 200
	for t in range(tries):
		var at := Vector2(rng.randf_range(-span+2,span-2),rng.randf_range(-span+2,span-2))*SkyArchipelago.CELL
		var nearest := INF
		for p: Dictionary in plans: nearest = minf(nearest,Vector2(p.home.x,p.home.z).distance_to(at)-float(p.width)*0.5)
		# The ranges standing in the sea are land too.
		if nearest > 150.0 and not SkyPeaks.blocks(Vector3(at.x,0.0,at.y),150.0): far += 1
	check(plans.size()/area > 15.0 and far <= tries/20,"Dense: land within 150 m of nearly anywhere (%d of %d spots further)" % [far,tries])
	var in_rock := 0
	for p: Dictionary in plans:
		if SkyPeaks.blocks(p.home): in_rock += 1
	check(in_rock == 0,"None stands in a range")
	a.free()
	b.free()

## Streaming round a flying eye: built within VIEW, faded in, let go past
## FORGET, the main thread's share of a frame small.
func _streaming() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var arch := SkyArchipelago.new()
	arch.ocean = SkyBelow.OCEAN
	holder.add_child(arch)
	var eye := Vector3(0.0,SkyBelow.OCEAN+20.0,0.0)
	var worst := 0
	var worst_survey := 0
	var worst_stand := 0
	var frames := 0
	var began := Time.get_ticks_msec()
	while arch.island_count() < 12 and Time.get_ticks_msec()-began < 60000:
		var t := Time.get_ticks_usec()
		arch.advance(DT,eye,Vector3.ZERO)
		worst = maxi(worst,Time.get_ticks_usec()-t)
		worst_survey = maxi(worst_survey,int(arch.spent.survey))
		worst_stand = maxi(worst_stand,int(arch.spent.stand))
		frames += 1
		await process_frame
	var usec := []
	for key in arch.built: usec.append(int(arch.built[key].usec))
	usec.sort()
	print("     %d islands in %.1f s (%d frames); worker build %.0f to %.0f ms, median %.0f; the frame's worst %.1f ms (survey %.1f, standing one up %.1f)" % [arch.island_count(),(Time.get_ticks_msec()-began)/1000.0,frames,usec[0]/1000.0,usec[-1]/1000.0,usec[usec.size()/2]/1000.0,worst/1000.0,worst_survey/1000.0,worst_stand/1000.0])
	check(arch.island_count() >= 12,"Islands are built round the eye (%d)" % arch.island_count())
	var nearest := INF
	for key in arch.built: nearest = minf(nearest,SkyArchipelago._flat(arch.built[key].home,eye))
	check(nearest < 200.0,"Nearest first (%.0f m off)" % nearest)
	check(worst < 60000,"The main thread's worst frame stays short (%.1f ms; it only stands nodes)" % (worst/1000.0))
	var b: Dictionary = arch.built.values()[0]
	check(arch.islets.built.has(arch.built.keys()[0]) and b.get("fixed",false),"Each is a fixed record in its islets, a solid to the glide")
	var top: Variant = arch.body(arch.islets.place(b)+Vector3.UP*5.0)
	check(top != null and absf((top as Vector2).x-(arch.islets.place(b).y+float(b.shape.solid_top(Vector2.ZERO)))) < 0.01,"The glide reads its ground")
	var water := SkyBelow.OCEAN
	var rim: Vector2 = b.shape.rim_point(0.7)*0.97
	var rim_y: float = arch.islets.place(b).y+float(b.shape.ground_at(rim))
	check(rim_y > water and rim_y < water+0.8,"Its shore meets the water low, a bank or beach (%.2f m over it)" % (rim_y-water))
	# Flown far off, they go.
	eye += Vector3(3000.0,0.0,0.0)
	for i in range(60):
		arch.advance(DT,eye,Vector3.ZERO)
		await process_frame
	var left := 0
	for key in arch.built:
		if SkyArchipelago._flat(arch.built[key].home,eye) > SkyArchipelago.FORGET: left += 1
	check(left == 0,"Past FORGET they are let go")
	holder.queue_free()
	await process_frame

## --landform: the asked-for landforms on the islands ahead of the way down,
## one after another along it.
func _forced() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var arch := SkyArchipelago.new()
	holder.add_child(arch)
	arch.asked = ["crag","spring","shore"]
	var way := Vector2(0.6,-0.8)
	# On the way down towards open sea: a spot short of a laid-out island.
	var eye := Vector3(400.0,-80.0,-200.0)
	for x in range(-8,8):
		var p: Variant = arch.plan(Vector3i(x,2,0))
		if p != null:
			eye = Vector3(p.home.x-way.x*200.0,-80.0,p.home.z-way.y*200.0)
			break
	arch.arrive(eye,way)
	check(arch.forced.size() == 3,"Each asked-for landform has an island (%d)" % arch.forced.size())
	var ahead := true
	var order := []
	for key in arch.forced:
		var parts: PackedStringArray = key.split(",")
		var p: Variant = arch.plan(Vector3i(int(parts[0]),int(parts[1]),int(parts[2])))
		if p == null or p.landform != arch.forced[key]:
			ahead = false
			continue
		var off := Vector2(p.home.x-eye.x,p.home.z-eye.z)
		if off.dot(way) < 0.0 or off.length() > SkyArchipelago.NEAR_AHEAD+SkyArchipelago.NEAR_GAP*3.0+SkyArchipelago.NEAR_REACH: ahead = false
		order.append([off.dot(way),p.landform])
	order.sort()
	check(ahead and order.map(func(o: Array) -> String: return o[1]) == ["crag","spring","shore"],"They lie ahead along the way down, in order")
	arch.build_near(eye,700.0)
	check(not arch.forced_island("spring").is_empty() and arch.forced_island("spring").shape.kind == "spring","They are built as asked")
	holder.queue_free()
	await process_frame

## The live scene under --below, through the wanderer (scripts/
## wanderer_eye.gd): off the edge, down under the cloud into the
## archipelago, F in to an island, perched and walking, off again, and back
## up into the sky.
func _live() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("lower world test timed out"); quit(2))
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/lower-world-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	for i in range(20): await process_frame
	var eye: Node = scene.wanderer
	check(eye.lower != null and eye.sky.lower == eye.lower,"With --below the wanderer has the lower world")
	check(eye.glide.floor_y == SkyBelow.FLOOR and eye.glide.water == SkyBelow.OCEAN,"Its plane's floor is just over the ocean")
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye._polar = PI*0.5
	eye._launch(1.0)
	for i in range(2): await process_frame
	check(eye.flying and not eye.below(),"Off the edge it flies above the cloud")
	var copies: int = eye.islands.offsets.size()
	var origin: Vector3 = eye.islands.origin
	eye.glide.position.y = -200.0
	eye.glide.pitch = 0.0
	for i in range(30): await process_frame
	var sky: ShaderMaterial = scene._environment.sky.sky_material if scene.get("_environment") != null and scene._environment.sky != null else null
	check(eye.below() and eye.lower.ocean.visible,"Under the cloud it is in the lower world")
	check(sky == null or sky.get_shader_parameter("below_world") == 1.0,"And the sky is the overcast")
	check(eye.sky.flight.w == 0.0,"The painted sea never parted")
	var arch: Node3D = eye.lower.archipelago
	check(arch.islets.ground_source != null and arch.taken_from == eye.islands.islets.ground_source and arch.islets.ground_source.get_shader_parameter("look_shift") == Vector3(0.0,SkyBelow.OCEAN,0.0),"The islands wear the sky islets' ground, its looks read from the ocean's height")
	check((eye.lower.ocean.material_override as ShaderMaterial).shader.resource_path == "res://shaders/sky_ocean.gdshader","The ocean is the sea's own water")
	# The islands round the plane, built now.
	arch.build_near(eye.glide.position,500.0)
	check(arch.island_count() > 3,"The archipelago stands round it (%d islands)" % arch.island_count())
	check(eye.islands.offsets.size() <= copies and eye.islands.origin == origin and not eye.islands.claiming,"No island surfaced or was claimed from below")
	# F: in to the nearest island.
	var b: Dictionary = arch.nearest(eye.glide.position,2000.0)
	var middle: Vector3 = arch.islets.place(b)
	eye.glide.position = middle+Vector3(-40.0,14.0,0.0)
	eye.glide.heading = atan2(-1.0,0.0)
	eye.glide.pitch = 0.0
	eye.glide.speed = 12.0
	eye._land_key()
	check(eye.glide.approach and eye.glide.approach_target != Vector3.INF,"F brings the plane in to the nearest island")
	var perched := false
	for i in range(int(40.0/DT)):
		await process_frame
		if not eye.perch.is_empty():
			perched = true
			break
	check(perched and eye.below(),"It touches down and the pilot perches on the island, under the cloud")
	if perched:
		check(eye.perch.has("landform") and eye.lower.islets().pinned == eye.perch.node,"On an island of the archipelago, held while stood on")
		var feet: Vector3 = eye._perch_feet
		Input.action_press(&"move_forward")
		for i in range(40): await process_frame
		Input.action_release(&"move_forward")
		var walked: float = Vector2(eye._perch_feet.x-feet.x,eye._perch_feet.z-feet.z).length()
		var ground: float = eye.perch.shape.ground_at(Vector2(eye._perch_feet.x,eye._perch_feet.z))
		check((walked > 0.5 and absf(eye._perch_feet.y-ground) < 0.3) or eye.perch.is_empty(),"The pilot walks its ground (%.1f m)" % walked)
		if not eye.perch.is_empty(): eye._launch(4.0,false)
		for i in range(2): await process_frame
		check(eye.flying and eye.perch.is_empty() and eye.below(),"Off again, still under the cloud")
	eye.glide.position.y = -80.0
	for i in range(30): await process_frame
	check(not eye.below() and not eye.lower.ocean.visible and not arch.visible,"Back over the cloud it is above again, the archipelago hidden")
	check(sky == null or sky.get_shader_parameter("below_world") == 0.0,"And the sky is as it was")
	eye.leave()
	for i in range(5): await process_frame
	scene.queue_free()
	await process_frame
