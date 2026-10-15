class_name KitLook
extends RefCounted
## The kit isles' one look (docs/scenic/kit-isle-shared.md): every hand-built
## sky isle (the aqueduct isle and its motifs, studies/*_isle.gd) wears the
## same ground and the same rock.
##
## The ground: the plate's own (the edit chunks' terrain material as
## assets/zen_reference/geometry.scn carries it and scripts/scene_look.gd
## roles it: reference_surface with terrain_growth, palette_role 1,
## flat_faces, wet_ground), so the calm field (shaders/ground_look.gdshaderinc)
## paints it as it paints the plate: the faces pulled most of the way to one
## broad field of sunlit and deep patches, the light's ambient taken from
## the smoothed ground. Off the plate the field's height map has nothing
## for the isle, so its smoothed normal is the mesh's own: `GroundMesh`
## writes each vertex the mean of the ground faces round it. Its faces
## carry the plate's palette greens (NativeTerrainPalette, as the plate's
## mesh paints them), worn to gravel and earth on the paths.
##
## The rock: the sky islets' (scripts/sky_islets.gd `_side_material`,
## scripts/rock_looks.gd "basalt"): the earth sides' shading with its
## facets split light and dark (FACETS), its colours its own, never the
## world's ground palette. Its colours are painted face by face here
## (`rock_tone`, the shader's `side_painted`, as scripts/sea_cliffs.gd
## paints its walls) from the islets' bands, by depth under the face's own
## rim, not by world height, so every rim, high or low, wears the same thin
## topsoil skin over dark rock: a root mat, the clay and sand, a few thin
## shale beds, then the rock in beds BED m thick (hard ones the paler core
## tones, soft ones the dark), warmer and cooler in broad patches. Faces
## lying back (a ledge, a step) read a little paler, so walkable ledges
## stand out of the wall.
const RockLooks = preload("res://scripts/rock_looks.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
## The isles' rock weathering by default (`rock_weather`).
const ROCK_WEATHER := 1.0
## Its strengths (shares of the ruin stone's) and how much of FACETS it keeps.
const ROCK_GRIT := {"tone":1.6,"streak":1.8,"crack":1.6,"facets":0.6}

## The rock look (scripts/rock_looks.gd), its tone and variant.
const ROCK_LOOK := "basalt"
const ROCK_TONE := 1.0
const ROCK_VARY := 0.5
## Its facets' light and dark spread (the islets' RockLooks.FACETS).
const FACETS := RockLooks.FACETS
## The bands under a rim (m down from it): the root mat, clay, sand, then
## shale beds SHALE m thick down to ROCK_FROM, then the rock's beds.
const SKIN := 0.3
const CLAY := 0.75
const SAND := 1.3
const ROCK_FROM := 2.1
const SHALE := 0.3
## The rock's beds (m, by world height, each a hash of its index hard or
## soft), their tone spread, the share of hard ones; how far they wave
## (m) over how long (m).
const BED := 1.35
const BED_TONE := Vector2(0.85,1.15)
const HARD := 0.35
const BED_WAVE := Vector2(0.35,23.0)
## Broad warm and cool patches over the rock (share, over 1/WARM_WAVE m).
const WARM := 0.12
const WARM_WAVE := 0.045
## A rock face lying back past LEDGE_UP (a ledge, a step's tread) reads
## LEDGE_LIFT times paler.
const LEDGE_UP := 0.72
const LEDGE_LIFT := 1.22
## How far the ground's direct light follows its smoothed normal (the
## reference surface's `facet_soft`).
const FACET_SOFT := 0.65
## The worn paths' earth and the water's bed (sRGB).
const EARTH := Color("6a4f37")

static var _palette := {}
static var _ground: ShaderMaterial
static var _rock: ShaderMaterial
static var _bands := {}
static var _warm: FastNoiseLite

## The plate's palette (NativeTerrainPalette, linear): grass greens, rock,
## sand, gravel; its rock slope.
static func palette() -> Dictionary:
	if _palette.is_empty():
		var p := NativeTerrainPalette.new()
		_palette = {"grass":p.grass.duplicate(),"rock":p.rock.duplicate(),"sand":p.sand,"gravel":p.gravel,
			"rock_slope":p.rock_slope if p.rock_slope > 0.0 else 0.93}
	return _palette

## The plate's ground material (the edit chunks' terrain: its settings as
## geometry.scn's terrain carries them, roled as scene_look roles it).
static func ground_material() -> ShaderMaterial:
	if _ground == null:
		_ground = ShaderMaterial.new()
		_ground.shader = preload("res://shaders/reference_surface.gdshader")
		_ground.set_shader_parameter("base_color",Color.WHITE)
		_ground.set_shader_parameter("flat_faces",true)
		_ground.set_shader_parameter("wet_ground",true)
		_ground.set_shader_parameter("terrain_growth",true)
		_ground.set_shader_parameter("palette_role",1)
		# The plate's mesh is fine (Plate.POINT_STEP, 0.67 m) and its facets
		# small; a kit isle's are 1 to 2 m, so its light leans this far to
		# the smoothed ground too (the sky peaks' `facet_soft`).
		_ground.set_shader_parameter("facet_soft",FACET_SOFT)
		# Its bare steep faces weathered as the rock is.
		_weather_rock(_ground)
	return _ground

## The islets' rock material, its colours painted face by face (`rock_tone`).
static func rock_material() -> ShaderMaterial:
	if _rock == null:
		_rock = ShaderMaterial.new()
		_rock.shader = preload("res://shaders/reference_surface.gdshader")
		_rock.set_shader_parameter("base_color",Color.WHITE)
		_rock.set_shader_parameter("flat_faces",true)
		_rock.set_shader_parameter("earth_sides",true)
		# No mist at a foot: the keels hang free over the open sky.
		_rock.set_shader_parameter("earth_sides_base",-1000.0)
		_rock.set_shader_parameter("side_facets",FACETS)
		_rock.set_shader_parameter("side_own",true)
		_rock.set_shader_parameter("side_painted",true)
		_weather_rock(_rock)
	return _rock

## How weathered the isles' rock is drawn (shaders/kit_weather.gdshaderinc,
## the ruin stone's and the Olmec's weathering): `--kit-rock=` weathered (1,
## the default), smooth (0, the rock as it was), or an amount (0 to 2).
static func rock_weather() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--kit-rock="):
			var v := a.get_slice("=",1)
			if v == "smooth": return 0.0
			if v == "weathered": return ROCK_WEATHER
			return clampf(v.to_float(),0.0,2.0) if v.is_valid_float() else ROCK_WEATHER
	return ROCK_WEATHER

## The rock's weathering, bolder than the ruin stone's (cliffs are seen
## from farther and lit flatter): its washes, streaks and cracks stronger,
## its facets' own light and dark spread eased so the grain carries it.
static func _weather_rock(m: ShaderMaterial) -> void:
	var w := rock_weather()
	m.set_shader_parameter("stone_weather",w)
	m.set_shader_parameter("weather_tone",ROCK_GRIT.tone)
	m.set_shader_parameter("weather_streak",ROCK_GRIT.streak)
	m.set_shader_parameter("weather_crack",ROCK_GRIT.crack)
	if w > 0.0 and m == _rock: m.set_shader_parameter("side_facets",FACETS*float(ROCK_GRIT.facets))

## Whether a ground face facing `normal` is too steep for turf (past the
## palette's rock slope): drawn as rock.
static func is_rock(normal: Vector3, pal: Dictionary = {}) -> bool:
	if pal.is_empty(): pal = palette()
	var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
	return slope > float(pal.rock_slope)

## A turf face's colour (linear), as the plate's mesh paints one (the
## palette's greens by its patch noise, a shimmer each): `worn` 0..1 toward
## a path's gravel and earth, `wet` 0..1 toward a water's bed.
static func ground_tone(pal: Dictionary, patch: FastNoiseLite, at: Vector2, shimmer: float, worn := 0.0, wet := 0.0) -> Color:
	var grass: Array = pal.grass
	var n := patch.get_noise_2d(at.x,at.y)*0.5+0.5
	var tone: Color = grass[1 if n > 0.55 else (2 if n < 0.42 else 0)]
	if wet > 0.0:
		var bed := (pal.gravel as Color).lerp(EARTH.srgb_to_linear(),0.55)*0.62
		tone = tone.lerp(bed,clampf(wet,0.0,1.0))
	elif worn > 0.0:
		tone = tone.lerp((pal.gravel as Color).lerp(EARTH.srgb_to_linear(),0.45)*lerpf(0.85,1.0,n),worn*0.8)
	return Color(tone.r+shimmer,tone.g+shimmer,tone.b+shimmer,1.0)

## The turf's tone (for KitLand `surface`): the plate's greens by a patch
## noise seeded `seed_value`, worn by `wear` ((x, z) -> 0..1, the paths),
## or bedded by `wet` ((x, z), the face's mean height -> 0..1, a water's
## bed) where that is over 0.
static func turf(seed_value: int, wear := Callable(), wet := Callable()) -> Callable:
	var pal := palette()
	var patch := FastNoiseLite.new()
	patch.seed = seed_value+5
	patch.frequency = 0.4
	return func(mid: Vector2, _normal: Vector3, shimmer: float, y: float) -> Color:
		var w := float(wet.call(mid,y)) if wet.is_valid() else 0.0
		var worn := float(wear.call(mid)) if wear.is_valid() and w <= 0.0 else 0.0
		return KitLook.ground_tone(pal,patch,mid,shimmer,worn,w)

## The look's band `key` (rock_looks.gd), linear.
static func band(key: String) -> Color:
	if not _bands.has(key): _bands[key] = RockLooks.colour_of(ROCK_LOOK,key,ROCK_TONE,ROCK_VARY)
	return _bands[key]

## A rock face's colour (linear) at `at` (its middle), `rim` (world y) the
## top of the land it hangs under, facing `normal`; `jitter` (about 1) a
## face's own shade.
static func rock_tone(at: Vector3, rim: float, normal: Vector3, jitter := 1.0) -> Color:
	var depth := rim-at.y
	var c: Color
	if depth < SKIN: c = band("topsoil")*0.9
	elif depth < CLAY: c = band("clay")
	elif depth < SAND: c = band("sand")
	elif depth < ROCK_FROM: c = band("shale" if int(floor((depth-SAND)/SHALE))%2 == 0 else "shale_dark")
	else:
		var wave := BED_WAVE.x*sin(at.x/BED_WAVE.y*TAU)*cos(at.z/BED_WAVE.y*TAU*0.7)
		var k := int(floor((at.y+wave)/BED))
		var pick := absi(hash([k,"kit isle bed"]))
		var hard := float(pick%1000)/1000.0 < HARD
		var from: Array = ["core_a","core_b"] if hard else ["core_c","bedrock","core_c"]
		c = band(from[(pick/1000)%from.size()])*lerpf(BED_TONE.x,BED_TONE.y,float(pick/7%101)/100.0)
	if _warm == null:
		_warm = FastNoiseLite.new()
		_warm.seed = 6151
		_warm.frequency = WARM_WAVE
	var w := _warm.get_noise_3d(at.x,at.y*1.5,at.z)
	c = Color(c.r*(1.0+WARM*w),c.g*(1.0+WARM*0.3*w),c.b*(1.0-WARM*w))
	if normal.y > LEDGE_UP and depth >= SKIN: c *= LEDGE_LIFT
	return Color(c.r*jitter,c.g*jitter,c.b*jitter,1.0)

# --- Meshes ------------------------------------------------------------------------------

## Turf faces gathered, then drawn in the ground material: each vertex the
## mean of the colours of the turf faces round it (so a path wears in soft
## across the faces, never in hard triangles) and their smoothed normal
## (the light follows the smoothed ground, as on the plate's finer mesh). The
## faces are drawn DROP m under where they are collided, so feet stand on
## them.
class GroundMesh extends RefCounted:
	const DROP := 0.02
	var _points := PackedVector3Array()
	var _tones := PackedColorArray()

	## A face (any winding) of colour `tone` (linear).
	func add(a: Vector3, b: Vector3, c: Vector3, tone: Color) -> void:
		var normal := (b-a).cross(c-a)
		if normal.y < 0.0:
			var swap := b
			b = c
			c = swap
		_points.append_array([a,b,c])
		_tones.append(tone)

	func is_empty() -> bool:
		return _points.is_empty()

	static func _key(p: Vector3) -> Vector3i:
		return Vector3i(roundi(p.x*500.0),roundi(p.y*500.0),roundi(p.z*500.0))

	## The mesh (one surface, the ground material), or null with no faces.
	func mesh() -> ArrayMesh:
		if _points.is_empty(): return null
		var sums := {}
		var tones := {}
		for i in range(0,_points.size(),3):
			var a := _points[i]
			var b := _points[i+1]
			var c := _points[i+2]
			# Area-weighted (the cross's length), so slivers count little.
			var normal := (b-a).cross(c-a)
			var weight := normal.length()
			var tone := _tones[i/3]
			for p: Vector3 in [a,b,c]:
				var k := _key(p)
				sums[k] = sums.get(k,Vector3.ZERO)+normal
				tones[k] = (tones.get(k,Vector4.ZERO) as Vector4)+Vector4(tone.r,tone.g,tone.b,1.0)*weight
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		var col := PackedColorArray()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		for i in range(0,_points.size(),3):
			# The shader's front, as the plate's terrain winds it.
			for p: Vector3 in [_points[i],_points[i+2],_points[i+1]]:
				var s: Vector3 = sums[_key(p)]
				var t: Vector4 = tones[_key(p)]
				var tone := Color(t.x/t.w,t.y/t.w,t.z/t.w,1.0) if t.w > 1e-9 else _tones[i/3]
				var smooth := s.normalized() if s.length_squared() > 1e-12 else Vector3.UP
				var y := p.y-DROP
				v.append(Vector3(p.x,y,p.z))
				n.append(smooth)
				col.append(tone)
				# terrain_growth: grown (UV.y 1), standing at its own height (UV2.y).
				uv.append(Vector2(0.0,1.0))
				uv2.append(Vector2(0.5,y))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,KitLook.ground_material())
		return mesh

	## A MeshInstance3D named `label` drawing it, or null with no faces.
	func node(label := "Ground") -> MeshInstance3D:
		var m := mesh()
		if m == null: return null
		var drawn := MeshInstance3D.new()
		drawn.name = label
		drawn.mesh = m
		return drawn

## Rock faces gathered, then drawn in the islets' rock: each face painted
## (`rock_tone`) by its depth under its rim, flat.
class RockMesh extends RefCounted:
	var _v := PackedVector3Array()
	var _n := PackedVector3Array()
	var _c := PackedColorArray()

	## A face of points `tri` (3), turned to face `toward`, hanging under
	## `rim` (world y); `jitter` its own shade (about 1).
	func add(tri: Array, rim: float, toward: Vector3, jitter := 1.0) -> void:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		if (p1-p0).cross(p2-p0).dot(toward) > 0.0:
			var swap := p1
			p1 = p2
			p2 = swap
		var normal := (p2-p0).cross(p1-p0).normalized()
		var tone := KitLook.rock_tone((p0+p1+p2)/3.0,rim,normal,1.0+(jitter-1.0)*0.5)
		for p: Vector3 in [p0,p1,p2]:
			_v.append(p)
			_n.append(normal)
			_c.append(tone)

	## A face painted `tone` (linear) instead (turf on a ledge, say).
	func add_toned(tri: Array, tone: Color, toward: Vector3) -> void:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		if (p1-p0).cross(p2-p0).dot(toward) > 0.0:
			var swap := p1
			p1 = p2
			p2 = swap
		var normal := (p2-p0).cross(p1-p0).normalized()
		for p: Vector3 in [p0,p1,p2]:
			_v.append(p)
			_n.append(normal)
			_c.append(tone)

	func is_empty() -> bool:
		return _v.is_empty()

	## The faces' points, three a face (a trimesh of the drawn rock).
	func faces() -> PackedVector3Array:
		return _v

	func mesh() -> ArrayMesh:
		if _v.is_empty(): return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _v
		arrays[Mesh.ARRAY_NORMAL] = _n
		arrays[Mesh.ARRAY_COLOR] = _c
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,KitLook.rock_material())
		return mesh

	func node(label := "Rock") -> MeshInstance3D:
		var m := mesh()
		if m == null: return null
		var drawn := MeshInstance3D.new()
		drawn.name = label
		drawn.mesh = m
		return drawn
