extends RefCounted
## The ground's strata (docs/scenic/strata.md): what the plate is made of,
## by height. One definition for the slab's earth sides
## (shaders/reference_surface.gdshader `zs_strata`, fed by `apply`) and for
## ground a stroke cut or exposed (scripts/land_clay.gd `_dirt` and
## `paint_faces`, through `color_at`), so a cut at the plate's edge matches the
## side beside it. Behaviour may read it through `material_at`.
##
## Bands are flat and by absolute plate height (the plain sits near 0), each
## boundary lifted or lowered a little by a gentle, low-frequency warp seeded
## per world (`warp`), so the layers undulate across the plate without
## folding. Under the plain, top down: topsoil, clay, sand, shale, bedrock
## (FLOORS). Above the plain the ground is topsoil (heaped earth), unless the
## column stands CORE_FROM metres or more: tall hills and mountains are the
## range's granite inside (the rock core), down to CORE_BASE.
##
## Colours are sRGB, authored against the default ("Mountain") palette. The
## world's palette reaches them in the shader, as it reaches every ground
## colour (shaders/scene_palette.gdshaderinc `scene_palette_ground`: earthy
## colours take the palette's earth, grey ones its rock), on cut ground and
## sides alike, so the strata suit each world without a second derivation.

## Each band's floor, metres: a height at or above it (after the warp) is that
## band or one above. Below the last is bedrock.
const BANDS := ["topsoil","clay","sand","shale","bedrock"]
const FLOORS := [-0.4,-1.8,-3.2,-4.4]
## The rock core: a column whose surface stands CORE_FROM metres or more is
## granite from CORE_BASE up. The core ignores the warp.
const CORE_FROM := 2.5
const CORE_BASE := 0.0
## The warp: up to WARP metres either way, two long waves WAVES metres long.
const WARP := 0.25
const WAVES := Vector2(19.0,12.0)
## Beds inside a band, metres: shale alternates two tones, the core steps
## through the granite's three, so a wall through either reads as layered.
const SHALE_BED := 0.3
const CORE_BED := 0.6
## A cut face is this much darker than a flat in the same band, so the
## facets read.
const FACE_SHADE := 0.86
## The sides' topsoil skin: the top SKIN metres under the rim, the grass's
## root mat, at SKIN_SHADE of the topsoil.
const SKIN := 0.22
const SKIN_SHADE := 0.55
const COLORS := {
	"topsoil":"7a624b",
	"clay":"a8784c",
	"sand":"cfbd96",
	"shale":"6f6863", "shale_dark":"58524e",
	"bedrock":"7f7e7a",
	# mountain_forms ROCKS.granite
	"core_a":"a8a49b", "core_b":"bab5ab", "core_c":"96928a",
}

var seed := 0
## The warp's two waves: (direction × wavenumber, phase) each.
var wave_a := Vector3.ZERO
var wave_b := Vector3.ZERO
var _linear := {}

static var _cache := {}

## The strata for the world seeded `world_seed` (kept, they never change).
static func for_seed(world_seed: int) -> RefCounted:
	if not _cache.has(world_seed): _cache[world_seed] = new(world_seed)
	return _cache[world_seed]

func _init(world_seed := 0) -> void:
	seed = world_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed,"strata"])
	var a := rng.randf()*TAU
	var b := a+rng.randf_range(1.2,2.0)
	wave_a = Vector3(cos(a)*TAU/WAVES.x,sin(a)*TAU/WAVES.x,rng.randf()*TAU)
	wave_b = Vector3(cos(b)*TAU/WAVES.y,sin(b)*TAU/WAVES.y,rng.randf()*TAU)
	for key: String in COLORS: _linear[key] = Color(COLORS[key]).srgb_to_linear()

## Metres the band boundaries stand raised (or lowered) at plate point `p`.
func warp(p: Vector2) -> float:
	return WARP*(0.6*sin(p.x*wave_a.x+p.y*wave_a.y+wave_a.z)+0.4*sin(p.x*wave_b.x+p.y*wave_b.y+wave_b.z))

## What the ground is made of at plate point `point`, `height` metres up:
## "topsoil", "clay", "sand", "shale", "bedrock" or "rock_core". `surface` is
## the top of the column there (the ground before a cut, say); left out, the
## point is taken as the surface.
func material_at(point: Vector2, height: float, surface := -INF) -> String:
	var top := height if surface == -INF else maxf(surface,height)
	if top >= CORE_FROM and height >= CORE_BASE: return "rock_core"
	var h := height+warp(point)
	for i in range(FLOORS.size()):
		if h >= FLOORS[i]: return BANDS[i]
	return "bedrock"

## The linear colour of the ground at `point`, `height` up, under `surface`
## (as `material_at`); `face` for a cut face, a shade darker.
func color_at(point: Vector2, height: float, surface := -INF, face := false) -> Color:
	var band := material_at(point,height,surface)
	var key := band
	if band == "shale":
		key = "shale_dark" if posmod(floori((height+warp(point)-FLOORS[3])/SHALE_BED),2) == 1 else "shale"
	elif band == "rock_core":
		key = ["core_a","core_b","core_c"][posmod(floori(height/CORE_BED),3)]
	var c: Color = _linear[key]
	return c*FACE_SHADE if face else c

## Whether a painted tint colour (linear) is one of the soft bands' (topsoil,
## clay, sand, flat or face), within `tolerance`: earth, not stone.
static func earthy(color: Color, tolerance := 0.05) -> bool:
	for key: String in ["topsoil","clay","sand"]:
		var e := Color(COLORS[key]).srgb_to_linear()
		for shade: float in [1.0,FACE_SHADE]:
			if Vector3(color.r-e.r*shade,color.g-e.g*shade,color.b-e.b*shade).length() < tolerance: return true
	return false

## Feed the strata to an earth-sides material (reference_surface with
## `earth_sides`). `offset` takes the mesh's own space to plate space.
func apply(material: ShaderMaterial, offset: Vector3) -> void:
	if material == null: return
	material.set_shader_parameter("strata_offset",offset)
	material.set_shader_parameter("strata_floors",Vector4(FLOORS[0],FLOORS[1],FLOORS[2],FLOORS[3]))
	material.set_shader_parameter("strata_core",Vector4(CORE_FROM,CORE_BASE,CORE_BED,SHALE_BED))
	material.set_shader_parameter("strata_wave_a",Vector4(wave_a.x,wave_a.y,wave_a.z,WARP))
	material.set_shader_parameter("strata_wave_b",Vector4(wave_b.x,wave_b.y,wave_b.z,0.0))
	material.set_shader_parameter("strata_skin",Vector2(SKIN,SKIN_SHADE))
	for key: String in COLORS:
		var c: Color = _linear[key]
		material.set_shader_parameter("strata_"+key,Vector3(c.r,c.g,c.b))
