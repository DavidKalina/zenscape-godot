extends SceneTree
## Headless probe of wheat (docs/scenic/wheat.md): the crop painted from the
## hand like the flowers (scripts/flower_paint.gd, FlowerSowing SLOTS "wheat").
##
## On a flat plate: a stroke paints wheat and only wheat under the brush, in
## rows square to the plate, hand work, one undo step, the ground warmed
## under it; Shift thins it (a pass takes some, passes clear it, undo brings
## it back); one undo takes a stroke back whole; it saves and reopens as it
## was; a field-scale stroke stays cheap a frame, and every clump is one
## instance of one mesh. The rows read: clumps drilled on a narrow band down
## each row, turned along it, an open furrow between, rows spaced as
## configured, dense down each row; the crop stands under a fence's posts;
## a field keeps to its triangle budget; and the other slots place exactly
## what they did before wheat's rows. Its wiring: tray, icon, palette, pluck, trash can,
## the ripening material.
##
## In the cozy scene, through real input: a wheat stroke shows as it is
## painted and settles in one undo step; Shift-drag thins; undo; a
## Shift-press plucks a clump (one undo step, undo brings it back); the trash
## can sweeps it (one undo step, undo brings it back); the world saves and
## reopens with it.
##   godot --headless --path . -s res://tools/probe_wheat.gd [-- --only=unit|scene]
const FlowerPaint = preload("res://scripts/flower_paint.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Kit = preload("res://scripts/meadow_flower_mesh.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Materials = preload("res://scripts/hand_materials.gd")
const Palette = preload("res://scripts/command_palette.gd")
const Reach = preload("res://scripts/hand_reach.gd")
const Trash = preload("res://scripts/clay_tools/trash.gd")
const SceneLook = preload("res://scripts/scene_look.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const Fences = preload("res://scripts/fences.gd")

## The rows as configured (FlowerSowing SLOTS "wheat").
const ROWS: Dictionary = FlowerSowing.SLOTS.wheat.drift.rows
## A field's budget: the 10 m by 8 m stroke (`field`) was 1,716 clumps of
## 277 triangles (475k) before the rows were drilled; it may grow a little
## for the denser rows, not far past.
const FIELD_TRIANGLES := 520000

var failures: Array[String] = []
var only := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: print("FAIL timed out"); quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if only.is_empty() or only == "unit":
		wiring()
		look()
		painting()
		field()
		unchanged()
	if only.is_empty() or only == "scene":
		await in_scene()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

# --- On a flat plate ------------------------------------------------------------------

func _flat_data() -> NativeTerrainData:
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	source.free()
	return data

## One stroke of `slot` along `path` at `speed` m/s, `passes` times back and
## forth, the brush `size` times its own, thinning when `thinning`: its
## summary, with "changed" (one undo step), "frame_usec" (the worst frame's
## painting) and "stroke".
func paint_on(data: NativeTerrainData, slot: String, path: Array, speed := 3.0, passes := 1, size := 1.0, thinning := false, salt := 1, world := 4242) -> Dictionary:
	var stroke = FlowerPaint.new(FlowerSowing.new(data,slot,world),size,thinning,salt)
	data.begin_stroke()
	var worst := 0
	stroke.press(path[0])
	for k in range(passes):
		var leg: Array = path.duplicate()
		if k%2 == 1: leg.reverse()
		for i in range(leg.size()-1):
			var a: Vector2 = leg[i]
			var b: Vector2 = leg[i+1]
			var frames := maxi(1,ceili(a.distance_to(b)/(speed/60.0)))
			for f in range(1,frames+1):
				var began := Time.get_ticks_usec()
				stroke.stroke(a.lerp(b,float(f)/frames),1.0/60.0)
				worst = maxi(worst,Time.get_ticks_usec()-began)
	var summary: Dictionary = stroke.finish()
	summary.changed = data.end_stroke()
	summary.frame_usec = worst
	summary.stroke = stroke
	return summary

func _wheat(data: NativeTerrainData) -> Array:
	return data.objects.filter(func(item: Dictionary) -> bool: return item.asset == "wheat")

static func near(data: NativeTerrainData, centre: Vector2, reach: float) -> int:
	return data.objects.filter(func(item: Dictionary) -> bool: return item.asset == "wheat" and Vector2(item.x,item.z).distance_to(centre) < reach).size()

func wiring() -> void:
	var ids: Array = Tray.SPECIMENS.map(func(entry: Dictionary) -> String: return entry.id)
	check("wheat" in ids and ids.find("wheat") == ids.find("sunflower")+1,"Wheat has a tray specimen, after the sunflower")
	check(FlowerSowing.has("wheat") and Materials.paints("wheat") and not Materials.sows("wheat"),"Wheat is painted under the brush, as the flowers are")
	var item := Icons.item("wheat")
	check(not item.is_empty() and str(item.label) == "Wheat · Field" and Icons.texture("wheat","icon",44.0) != null,"Wheat has its faceted icon and name (%s)" % item.get("label",""))
	check(Palette.SEEDS.any(func(entry: Array) -> bool: return entry[0] == "wheat"),"Wheat is in the command palette")
	check(Reach.pluckable("wheat"),"A Shift-press plucks wheat, as it plucks a flower")
	check(Trash.takes("wheat") and Trash.takes("wheat",true),"The trash can takes wheat, Shift or not (it is small stuff)")
	check(FlowerPaint.is_flower("wheat"),"Wheat thins under Shift as the flowers do")
	check("wheat" in NativeTerrainData.ASSETS and MeadowTypes.asset("wheat") == "wheat","Wheat is its own asset, saved by name")
	var mesh: ArrayMesh = Kit.mesh("wheat")
	var triangles: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	var material: ShaderMaterial = mesh.surface_get_material(0)
	var aabb := mesh.get_aabb()
	print("wheat clump: %d triangles, %.2f m tall, %.2f m along its row by %.2f m across" % [triangles,aabb.end.y,aabb.size.x,aabb.size.z])
	check(triangles <= 240,"A clump of six straws is cheap (%d triangles)" % triangles)
	# Straws and ears only (the blades low down reach further along).
	check(aabb.size.x > aabb.size.z*1.5,"A clump is a short line along its row, narrow across (%.2f by %.2f m)" % [aabb.size.x,aabb.size.z])
	var sizes: Array = FlowerSowing.SLOTS.wheat.sizes.wheat
	var low := aabb.end.y*float(sizes[0])
	var high := aabb.end.y*float(sizes[1])
	print("wheat stands %.2f to %.2f m (fence posts %.2f m, rails at %s)" % [low,high,Fences.POST_HEIGHT,str(Fences.RAIL_HEIGHTS)])
	check(low >= 0.5 and high <= 0.72 and (low+high)*0.5 < Fences.POST_HEIGHT,"Wheat stands knee-high, under a fence's posts on the whole (%.2f to %.2f m)" % [low,high])
	check(material.get_shader_parameter("flower_ripen") == true and material.get_shader_parameter("flower_heads") == true and material.get_shader_parameter("sway_enabled") == true,"Its material sways with the flowers and ripens with the year")
	check(SceneLook.leaf_season("wheat:meadow-flower-wheat") == Vector4.ZERO,"No autumn paint or die-back over it: it ripens and is cut its own way")
	check(not Kit.casts_shadow("wheat"),"A field casts no per-clump shadows (cost)")

func painting() -> void:
	var radius := FlowerPaint.RADIUS
	var leak := FlowerPaint.CELL*1.5
	var data := _flat_data()
	var path := [Vector2(-5.0,0.0),Vector2(5.0,0.0)]
	var one: Dictionary = paint_on(data,"wheat",path,3.0,2)
	var wheat := _wheat(data)
	var meadow: RefCounted = one.stroke.sowing.meadow
	var outside := wheat.filter(func(w: Dictionary) -> bool: return absf(float(w.z)) > radius+leak or absf(float(w.x)) > 5.0+radius+leak).size()
	var rowed := wheat.filter(func(w: Dictionary) -> bool: return meadow.on_row(Vector2(w.x,w.z),"wheat")).size()
	var core := wheat.filter(func(w: Dictionary) -> bool: return absf(float(w.z)) < 0.6 and absf(float(w.x)) < 4.0).size()/(8.0*1.2)
	print("two wheat passes, 10 m: %d clumps %s, core %.1f clumps a m² (%.0f straws), %d cells washed, rows along %s" % [one.placed.size(),str(one.kinds),core,core*6.0,one.washed,str(meadow._row)])
	check(one.placed.size() >= 100 and wheat.size() == one.placed.size() and data.objects.size() == wheat.size(),"A stroke paints wheat and only wheat (%d clumps)" % wheat.size())
	check(outside == 0,"Every clump stands under the brush (%d outside)" % outside)
	check(rowed == wheat.size(),"Every clump stands on its rows (%d of %d)" % [rowed,wheat.size()])
	check(meadow._row in [Vector2.RIGHT,Vector2.DOWN],"The rows run square to the plate's sides (%s)" % str(meadow._row))
	check(core >= 8.0,"The patch is dense at its middle (%.1f clumps a m²)" % core)
	check(one.changed and wheat.all(func(w: Dictionary) -> bool: return w.get("source") == "hand"),"One undo step, and the wheat is hand work")
	check(int(one.washed) > 0,"The ground under the patch is warmed toward stubble gold (%d cells)" % one.washed)
	rows_read(wheat,meadow)
	# The other way round, in a world whose rows run the plate's other axis.
	var other := _flat_data()
	var world := 4242
	for k in range(1,64):
		if FlowerSowing.new(other,"wheat",4242+k).meadow._row != meadow._row:
			world = 4242+k
			break
	var turned: Dictionary = paint_on(other,"wheat",path,3.0,2,1.0,false,1,world)
	check(turned.stroke.sowing.meadow._row != meadow._row,"Another world turns its rows the plate's other way (%s)" % str(turned.stroke.sowing.meadow._row))
	rows_read(_wheat(other),turned.stroke.sowing.meadow)
	# Undo takes the stroke back whole.
	data.undo()
	check(_wheat(data).is_empty(),"One undo takes the whole stroke back")
	data.redo()
	check(_wheat(data).size() == wheat.size(),"Redo brings it again")

	# Shift thins: a pass takes some, passes clear it, nothing outside; undo.
	var thinned := _flat_data()
	paint_on(thinned,"wheat",path,3.0,4)
	var before := near(thinned,Vector2.ZERO,0.6)
	var aside := thinned.objects.filter(func(w: Dictionary) -> bool: return absf(float(w.x)) > 2.0+radius+leak).size()
	var thin_path := [Vector2(-2.0,0.0),Vector2(2.0,0.0)]
	var first: Dictionary = paint_on(thinned,"wheat",thin_path,3.0,1,1.0,true)
	var after_one := near(thinned,Vector2.ZERO,0.6)
	paint_on(thinned,"wheat",thin_path,3.0,3,1.0,true)
	var after_more := near(thinned,Vector2.ZERO,0.6)
	var aside_after := thinned.objects.filter(func(w: Dictionary) -> bool: return absf(float(w.x)) > 2.0+radius+leak).size()
	print("thinning the middle: %d, one pass %d, four %d (%d taken in the first)" % [before,after_one,after_more,first.removed.size()])
	check(after_one < before*0.75 and after_one > 0,"Shift thins: one pass takes some (%d of %d left)" % [after_one,before])
	check(after_more <= before*0.05,"Going over it clears it (%d left)" % after_more)
	check(aside_after == aside,"Thinning touches nothing outside the brush (%d, %d)" % [aside,aside_after])
	check(first.placed.is_empty(),"Thinning places nothing")
	thinned.undo()
	check(near(thinned,Vector2.ZERO,0.6) == after_one,"One undo brings a thinning stroke's wheat back")

	# Saves: ordinary object records, reopened as they were.
	var reopened := _flat_data()
	check(reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document()))),"A world with painted wheat saves and reopens")
	var same := reopened.objects.size() == data.objects.size()
	for i in range(mini(reopened.objects.size(),data.objects.size())):
		var a: Dictionary = data.objects[i].duplicate()
		a.erase("born")
		if JSON.stringify(a) != JSON.stringify(reopened.objects[i]): same = false
	check(same and reopened.tint == data.tint and _wheat(reopened).size() == wheat.size(),"Its wheat and the warmed ground reopen as they were (%d clumps)" % _wheat(reopened).size())
	# The ground decides, as for flowers: none on water.
	var wet := _flat_data()
	wet.ponds.append({"x":0.0,"z":0.0,"level":0.4})
	var drowned: Dictionary = paint_on(wet,"wheat",[Vector2(-0.4,0.0),Vector2(0.4,0.0)],1.0,3,0.6)
	check(drowned.placed.is_empty(),"No wheat on water (%d)" % drowned.placed.size())

## Each plant reads: plump ears on thicker straw, and the ears well lighter
## than their straw in every season, after the material's ripening and the
## world's palette lean (a mirror of reference_surface's `flower_ripen`
## path, `_ripened`, held to the shader's source). The scene's light and mood
## multiply ear and straw alike, so the ratio survives them.
## Before this pass: ears 0.015 m in radius (flattened 0.6) on 0.0055 m
## straw, d9ab4a to f4d57c over d6b05a; one spring green for both.
const EAR_BEFORE := 0.015
const STRAW_BEFORE := 0.0055
const CONTRAST := 2.0
const SEASONS := {"ripe":Vector4.ZERO,"green":Vector4(1.0,0.0,0.0,0.0),"autumn":Vector4(0.0,0.0,0.0,1.0)}
const PALETTE_LEANS := [Vector3(1.0,1.0,1.0),Vector3(1.15,1.0,0.7),Vector3(0.85,1.0,1.15)]

func look() -> void:
	var ear := Kit.WHEAT_EAR_RADIUS*float(Kit.HEAD_SCALE.wheat)
	var straw := Kit.WHEAT_STRAW_RADIUS
	print("wheat ears %.4f m in radius as drawn (%.4f authored, was %.4f), straw %.4f m (was %.4f): ear %.1f times the straw's width (was %.1f)" % [ear,Kit.WHEAT_EAR_RADIUS,EAR_BEFORE*float(Kit.HEAD_SCALE.wheat),straw,STRAW_BEFORE,ear/straw,EAR_BEFORE*float(Kit.HEAD_SCALE.wheat)/STRAW_BEFORE])
	check(Kit.WHEAT_EAR_RADIUS >= EAR_BEFORE*1.5 and straw >= STRAW_BEFORE*1.3,"Plumper ears (%.1f times) on thicker straw (%.1f times)" % [Kit.WHEAT_EAR_RADIUS/EAR_BEFORE,straw/STRAW_BEFORE])
	check(ear/straw >= 4.0,"An ear is several straws wide (%.1f)" % (ear/straw))
	var source: String = load("res://shaders/reference_surface.gdshader").code
	for line in ["float ripen_lum = dot(COLOR.rgb, vec3(0.30, 0.55, 0.15));",
			"COLOR.rgb = mix(COLOR.rgb, (UV2.x < 1.5 ? flower_ripen_green_straw : flower_ripen_green_ear) * ripen_lum, 0.85 * ripen_green);",
			"COLOR.rgb *= mix(vec3(1.0), vec3(1.0, 0.86, 0.64), 0.6 * zs_season.w);",
			"COLOR.rgb = mix(COLOR.rgb, vec3(1.12, 1.0, 0.76) * ripen_lum, 0.7 * zs_season.z);",
			"if (UV2.x < 1.5) COLOR.rgb *= mix(1.0, UV.x, 0.5);"]:
		check(line in source,"The probe's ripening mirrors the shader: %s" % line.left(48))
	var material: ShaderMaterial = Kit.mesh("wheat").surface_get_material(0)
	check(material.get_shader_parameter("flower_ripen_green_ear") == Kit.RIPEN_GREEN_EAR and material.get_shader_parameter("flower_ripen_green_straw") == Kit.RIPEN_GREEN_STRAW,"The material greens ears and straw their own ways")
	var arrays: Array = Kit.mesh("wheat").surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var pull := float(material.get_shader_parameter("flower_palette_pull")) if material.get_shader_parameter("flower_palette_pull") != null else 0.12
	for state: String in SEASONS:
		var worst := INF
		var shown := ""
		for lean: Vector3 in PALETTE_LEANS:
			var ears := Vector3.ZERO
			var straws := Vector3.ZERO
			var e := 0
			var t := 0
			for i in range(colours.size()):
				var part := uv2[i].x
				if part > 2.5 and part < 3.5:
					ears += _ripened(colours[i],part,uv[i].x,SEASONS[state],lean,pull)
					e += 1
				elif part < 0.5:
					straws += _ripened(colours[i],part,uv[i].x,SEASONS[state],lean,pull)
					t += 1
			ears /= maxf(e,1)
			straws /= maxf(t,1)
			var ratio := _lum(ears)/maxf(_lum(straws),0.0001)
			if ratio < worst:
				worst = ratio
				shown = "ears #%s over straw #%s" % [Color(ears.x,ears.y,ears.z).linear_to_srgb().to_html(false),Color(straws.x,straws.y,straws.z).linear_to_srgb().to_html(false)]
		print("wheat %s: ear to straw luminance %.2f at the least (%s)" % [state,worst,shown])
		check(worst >= CONTRAST,"Wheat %s: its ears stand out from their straw (luminance %.2f to 1)" % [state,worst])
	# Soft, not neon: the ripe ears' colours stay pale and gentle.
	for hex: String in [Kit.WHEAT_EAR_FOOT,Kit.WHEAT_EAR_TIP,Kit.WHEAT_STRAW]:
		var c := Color(hex)
		check(c.s <= 0.65,"Wheat's %s is soft, not neon (saturation %.2f)" % [hex,c.s])

static func _lum(c: Vector3) -> float:
	return c.dot(Vector3(0.30,0.55,0.15))

## A wheat vertex's albedo after reference_surface's `flower_ripen` path:
## authored linear colour `colour`, its part (UV2.x) and shade (UV.x), the
## season (`zs_season`) and the world's palette lean (zs_palette_grass /
## ZS_GRASS_SOURCE, `zs_flower_palette`).
static func _ripened(colour: Color, part: float, shade: float, season: Vector4, lean: Vector3, pull: float) -> Vector3:
	var c := Vector3(colour.r,colour.g,colour.b)
	var lum := _lum(c)
	var green := maxf(season.x,(1.0-season.w)*(1.0-smoothstep(0.5,1.0,season.z))*smoothstep(0.0,0.2,season.z))
	c = c.lerp((Kit.RIPEN_GREEN_STRAW if part < 1.5 else Kit.RIPEN_GREEN_EAR)*lum,0.85*green)
	c *= Vector3.ONE.lerp(Vector3(1.0,0.86,0.64),0.6*season.w)
	c = c.lerp(Vector3(1.12,1.0,0.76)*lum,0.7*season.z)
	if part < 1.5: c *= lerpf(1.0,shade,0.5)
	var lean_lum := _lum(lean)
	var leaning := (lean/maxf(lean_lum,0.05)).clamp(Vector3.ONE*0.6,Vector3.ONE*1.5)
	return c*Vector3.ONE.lerp(leaning,clampf(pull,0.0,1.0))

## The rows in `wheat`, a stroke along x through the plate's middle (core
## |x| < 4, |z| < 0.6), read as drilled rows in `meadow`'s world: every clump
## on its row's band, an open furrow between bands, the rows spaced as
## configured, dense down each row, each clump turned along it.
func rows_read(wheat: Array, meadow: RefCounted) -> void:
	var label := "along z" if absf(meadow._row.y) > 0.5 else "along x"
	var spacing := float(ROWS.spacing)
	var band := float(ROWS.band)
	var u: Vector2 = meadow._row
	var n := Vector2(-u.y,u.x)
	var lowest := INF
	var highest := -INF
	var bins := PackedInt32Array()
	bins.resize(16)
	var by_row := {}
	var turned := 0
	var core := 0
	for w: Dictionary in wheat:
		var p := Vector2(w.x,w.z)
		var across: float = n.dot(p)+meadow.row_waver(p)
		var off := fposmod(across,spacing)-spacing*0.5
		lowest = minf(lowest,off)
		highest = maxf(highest,off)
		bins[mini(int(fposmod(across,spacing)/spacing*16.0),15)] += 1
		if absf(p.x) < 4.0 and absf(p.y) < 0.6:
			core += 1
			by_row.get_or_add(floori(across/spacing),[]).append(n.dot(p))
		var heading := Vector2(cos(float(w.angle)),-sin(float(w.angle)))
		if absf(heading.dot(u)) > 0.9: turned += 1
	# Clumps a metre of band against a metre of furrow, across the rows.
	var on := 0
	var off_row := 0
	for b in range(16):
		var middle := (b+0.5)/16.0*spacing-spacing*0.5
		if absf(middle) < band*0.5: on += bins[b]
		else: off_row += bins[b]
	var on_width := 0.0
	for b in range(16):
		if absf((b+0.5)/16.0*spacing-spacing*0.5) < band*0.5: on_width += spacing/16.0
	var ratio := (on/on_width)/maxf(off_row/(spacing-on_width),1.0/(spacing-on_width))
	var furrow := spacing-(highest-lowest)
	# Rows spaced as configured: the mean of neighbouring rows' clumps.
	var means := []
	var keys: Array = by_row.keys()
	keys.sort()
	for k: int in keys:
		var at: Array = by_row[k]
		means.append(at.reduce(func(a: float, b: float) -> float: return a+b,0.0)/at.size())
	var gaps := []
	for i in range(keys.size()-1):
		if keys[i+1] == keys[i]+1: gaps.append(float(means[i+1])-float(means[i]))
	var worst := 0.0
	for g: float in gaps: worst = maxf(worst,absf(g-spacing))
	var length := 1.2 if absf(u.y) > 0.5 else 8.0
	var per_metre := core/maxf(keys.size()*length,0.001)
	print("rows %s: band %.3f m of %.2f m, furrow %.3f m clear, on-row %d vs furrow %d clumps (density ratio %.0f:1), %d rows in the core, spacing off by at most %.3f m, %.1f clumps (%.0f straws) a metre of row, %d of %d turned along it; across a row by sixteenths: %s" % [label,highest-lowest,spacing,furrow,on,off_row,ratio,keys.size(),worst,per_metre,per_metre*6.0,turned,wheat.size(),str(bins)])
	check(off_row == 0 and ratio >= 20.0,"Rows %s: every clump on its row's band, none in the furrows (%d of %d)" % [label,off_row,wheat.size()])
	check(highest-lowest <= band and furrow >= spacing-band-0.001,"Rows %s: an open furrow %.2f m wide between bands %.2f m wide" % [label,furrow,highest-lowest])
	check(gaps.size() >= 3 and worst <= 0.04,"Rows %s: spaced %.2f m as configured (off by at most %.3f m)" % [label,spacing,worst])
	check(per_metre >= 4.0,"Rows %s: dense down each row (%.1f clumps, %.0f straws a metre)" % [label,per_metre,per_metre*6.0])
	check(turned == wheat.size(),"Rows %s: each clump turned along its row (%d of %d)" % [label,turned,wheat.size()])

## A field: a 10 m by 8 m patch painted in one stroke, back and forth with the
## wide brush. Its frames stay cheap, and every clump draws as one instance
## of the one wheat mesh (GardenView batches a part per kind).
func field() -> void:
	var data := _flat_data()
	var path := []
	for k in range(5):
		var z := -4.0+2.0*k
		path.append(Vector2(-5.0 if k%2 == 0 else 5.0,z))
		path.append(Vector2(5.0 if k%2 == 0 else -5.0,z))
	var began := Time.get_ticks_usec()
	var made: Dictionary = paint_on(data,"wheat",path,4.0,2,1.5)
	var took := (Time.get_ticks_usec()-began)/1000.0
	var clumps := _wheat(data).size()
	var triangles: int = Kit.mesh("wheat").surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	var sampled := preload("res://scripts/garden_instance_samples.gd").build(data,{"wheat":["meadow-flower-wheat"]},{"meadow-flower-wheat":Transform3D.IDENTITY},{})
	var batch: int = sampled.transforms.get("meadow-flower-wheat",[]).size()
	print("field 10 x 8 m: %d clumps (%d straws, %.1f clumps a m²), %d triangles before distance thinning; stroke %.0f ms, worst frame %.2f ms; finish %d cells washed" % [clumps,clumps*6,clumps/80.0,clumps*triangles,took,made.frame_usec/1000.0,made.washed])
	check(clumps >= 600,"A field-scale patch (%d clumps)" % clumps)
	check(clumps*triangles <= FIELD_TRIANGLES,"A field keeps to its budget before distance thinning (%dk of %dk triangles)" % [clumps*triangles/1000,FIELD_TRIANGLES/1000])
	check(made.frame_usec < 16000,"Painting a field stays under a frame's budget (worst %.2f ms)" % (made.frame_usec/1000.0))
	check(batch == clumps,"Every clump is one instance in the wheat batch (%d of %d)" % [batch,clumps])
	# Drawn along its row: each instance's long side (the mesh's x) runs down it.
	var row: Vector2 = made.stroke.sowing.meadow._row
	var along := 0
	for t: Transform3D in sampled.transforms.get("meadow-flower-wheat",[]):
		var x := t.basis.x.normalized()
		if absf(Vector2(x.x,x.z).dot(row)) > 0.9: along += 1
	check(along == batch,"Every clump is drawn with its long side down its row (%d of %d)" % [along,batch])

## The other slots are untouched by wheat's own rows: a sunflower stroke, a
## wildflower stroke and a sunflower sowing (FlowerSowing `grow`) on a flat
## plate place exactly the records they did before wheat's row lattice
## (digests of the records, `born` aside, and the ground's wash, taken from
## the code before it).
const UNCHANGED := {"sunflower":"e04e8cd743e577fc65bdb4c140b5304b","wildflower":"637dc3eee37a2e8c571704b442b21c03","sunflower grow":"40fb3209ca2f7fcc11cbad0617d0b819"}

func _digest(data: NativeTerrainData) -> String:
	var records := []
	for item: Dictionary in data.objects:
		var copy := item.duplicate(true)
		copy.erase("born")
		records.append(copy)
	return (JSON.stringify(records)+JSON.stringify(Array(data.tint))).md5_text()

func unchanged() -> void:
	var path := [Vector2(-5.0,-1.0),Vector2(5.0,1.5)]
	var made := {}
	for slot in ["sunflower","wildflower"]:
		var data := _flat_data()
		paint_on(data,slot,path,3.0,3,1.2,false,7)
		made[slot] = [_digest(data),data.objects.size()]
	var sown := _flat_data()
	var sowing = FlowerSowing.new(sown,"sunflower",4242)
	var points := PackedVector2Array()
	var times := PackedFloat32Array()
	for i in range(400):
		points.append(Vector2(-3.0+6.0*Variety.unit([i,1]),-2.0+4.0*Variety.unit([i,2])))
		times.append(float(i)*0.01)
	sown.begin_stroke()
	sowing.grow(points,times,3,0.0)
	sown.end_stroke()
	made["sunflower grow"] = [_digest(sown),sown.objects.size()]
	for key: String in UNCHANGED:
		print("%s: %d records, digest %s" % [key,made[key][1],made[key][0]])
		check(made[key][1] > 0 and made[key][0] == UNCHANGED[key],"%s places exactly what it did before wheat's rows (%d records)" % [key.capitalize(),made[key][1]])

# --- In the cozy scene ---------------------------------------------------------------

var scene: Node3D
var editor: Node
var reach: Node
var materials: Node
var clay: Node

func screen_of(p: Vector2) -> Vector2:
	var data: NativeTerrainData = editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,float(data.sample(p,data.heights)),p.y)))

func button(at: Vector2, pressed: bool, shift := false) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

func frames(count: int) -> void:
	for i in range(count): await process_frame

func settle() -> void:
	var began := Time.get_ticks_msec()
	while int(editor.refresh_pending) > 0 and Time.get_ticks_msec()-began < 10000: await process_frame
	await frames(4)

## Paints wheat along `path` (plate) over `seconds` through the hand.
func paint(path: Array, seconds: float, shift := false) -> Dictionary:
	var out := {"drawn":0,"refreshed":false}
	check(materials.take("wheat") and materials.held == "wheat","Wheat is taken in hand")
	var start := screen_of(path[0])
	point(start)
	await frames(20)
	button(start,true,shift)
	await process_frame
	check(reach.holding == Materials.PAINT and editor.flower_paint != null,"A press on the land with wheat in hand paints%s" % (" (Shift)" if shift else ""))
	var began := Time.get_ticks_msec()
	var was := start
	while (Time.get_ticks_msec()-began)/1000.0 < seconds:
		var t := (Time.get_ticks_msec()-began)/1000.0/maxf(seconds,0.001)
		var at := screen_of(Vector2(path[0]).lerp(path[-1],clampf(t,0.0,1.0)))
		motion(at,at-was)
		was = at
		await process_frame
		out.drawn = maxi(out.drawn,editor.content.paint_preview_count())
		if int(editor.refresh_pending) > 0: out.refreshed = true
	button(was,false,shift)
	await process_frame
	out.summary = editor.last_paint
	await settle()
	materials.put_back()
	return out

func has(id: int) -> bool:
	return editor.data._object_index(id) >= 0

func in_scene() -> void:
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-wheat-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	var waited := Time.get_ticks_msec()
	while scene._growth.terrain < 0.995 and Time.get_ticks_msec()-waited < 30000: await process_frame
	if not editor.active: scene.set_building(false)
	check(editor.active,"The land takes presses")
	scene.world_clock.running = false
	reach = scene.hand_reach
	materials = reach.get("materials")
	clay = scene.get("land_clay")
	check(materials != null and clay != null,"The hand scheme's materials and clay are in the scene")
	if materials == null or clay == null: return
	var data: NativeTerrainData = editor.data
	await frames(60)
	await settle()
	var steps: int = data._undo.size()
	var path := [Vector2(-4.0,3.0),Vector2(3.0,3.0)]
	var stroke: Dictionary = await paint(path,1.2)
	var placed: Array = stroke.summary.get("placed",[])
	print("scene wheat stroke: %d clumps %s; preview drew up to %d" % [placed.size(),str(stroke.summary.get("kinds",{})),stroke.drawn])
	# One quick pass lays a loose patch (its count varies with the frames the
	# headless run gets); the flat-plate checks above measure its density.
	check(placed.size() >= 30 and int(stroke.summary.get("kinds",{}).get("wheat",0)) == placed.size(),"A wheat stroke paints a wheat patch (%d clumps)" % placed.size())
	check(stroke.drawn > 0 and not stroke.refreshed,"Wheat shows as it is painted, with no refresh while the button is down")
	check(data._undo.size() == steps+1,"One undo step for the stroke (%d)" % (data._undo.size()-steps))
	check(editor.content.paint_preview_count() == 0,"Once settled the land's own batches draw it")
	# Shift thins it; undo brings it back.
	var before := near(data,Vector2(0.0,3.0),1.0)
	var thinning: Dictionary = await paint([Vector2(-1.0,3.0),Vector2(1.0,3.0)],0.8,true)
	var after := near(data,Vector2(0.0,3.0),1.0)
	print("scene thinning: %d to %d in the middle, %d taken" % [before,after,thinning.summary.get("removed",[]).size()])
	check(after < before and data._undo.size() == steps+2,"Shift-drag thins the wheat under the brush, its own undo step (%d to %d)" % [before,after])
	editor.undo()
	await settle()
	check(near(data,Vector2(0.0,3.0),1.0) == before,"Undo brings the thinned wheat back")
	# A Shift-press plucks one clump: one undo step, undo brings it back.
	var standing := placed.filter(func(id: int) -> bool: return has(id))
	var target: int = standing[standing.size()/2]
	var undo_before: int = data._undo.size()
	check(reach.pluck(target) and not has(target) and data._undo.size() == undo_before+1,"A pluck takes one clump of wheat, one undo step")
	await settle()
	editor.undo()
	await settle()
	check(has(target),"Undo puts the plucked clump back")
	# The trash can sweeps wheat away: one undo step, undo brings it back.
	materials.select_tool("trash")
	await frames(10)
	check(clay.tool_id == "trash","The trash can is in hand")
	var count := _wheat(data).size()
	undo_before = data._undo.size()
	var from := screen_of(Vector2(-1.5,3.0))
	var to := screen_of(Vector2(1.5,3.0))
	button(from,true)
	await frames(2)
	for k in range(24):
		var at := from.lerp(to,float(k+1)/24.0)
		motion(at,(to-from)/24.0)
		await frames(1)
	await frames(10)
	button(to,false)
	await frames(30)
	await settle()
	var swept := count-_wheat(data).size()
	print("scene trash sweep: %d of %d clumps taken" % [swept,count])
	check(swept > 0 and near(data,Vector2(0.0,3.0),0.8) == 0 and data._undo.size() == undo_before+1,"The trash can sweeps the wheat off its line, one undo step (%d taken)" % swept)
	editor.undo()
	await settle()
	check(_wheat(data).size() == count,"Undo brings the swept wheat back")
	materials.select_tool(Materials.FREE)
	# Saves and reopens with it.
	var reopened := NativeTerrainData.new()
	reopened.setup(data.source_mesh)
	check(reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document()))) and _wheat(reopened).size() == _wheat(data).size(),"The world saves and reopens with its wheat (%d clumps)" % _wheat(reopened).size())
	scene.queue_free()
	await frames(2)
