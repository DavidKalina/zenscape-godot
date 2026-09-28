extends RefCounted
## The wind a released pollen cloud drifts on (scripts/pollen_cloud.gd), read
## on the CPU from the same state the shaders' wind reads
## (shaders/reference_wind.gdshaderinc `zs_wind_at`): the atmosphere's
## strength (`zs_wind_strength`: its air strength plus swell, times the gust
## envelope `gust_at`), its direction (`zs_wind_direction`) and the gust
## parcels it has sent (`zs_puff_*`, through the parcels' own CPU mirror of
## `zs_gust_pulse_at`, studies/wind_puffs.gd `sample_at`). The shaders' drifting
## noise field is taken at its mean.
##
## This is the one place pollen asks the wind. It also adds the push of any
## gust the wind tool has sent, when the editor has one (`gust.wind_at`,
## scripts/wind_gust.gd on feature/wind-gust, plate x, z in m/s); without it,
## only the world's wind.
##
## Preloaded, not a class_name.

## Metres a second pollen drifts at wind strength 1 under a mean field. No
## wind, no drift: still air lets it float straight down.
const DRIFT := 1.4
## The shaders' field is 0.45 + 1.1 × (noise + gust pulse); the noise's mean.
const FIELD_MEAN := 0.5

## The drift velocity (plate x, z, m/s) at plate point `p`. `scene` holds the
## atmosphere (`_atmosphere`), `plate` is the terrain node pollen lives under.
## Zero where there is no atmosphere.
static func at(scene: Node, plate: Node3D, p: Vector2) -> Vector2:
	var air: Variant = scene.get("_atmosphere") if scene != null else null
	if air == null or air.get("_air_angle") == null: return Vector2.ZERO
	var strength := maxf(float(air._air_strength)+float(air.swell),0.0)*float(air.gust_at(float(air._wind_time)))
	var direction := Vector2(cos(float(air._air_angle)),sin(float(air._air_angle)))
	var world := plate.to_global(Vector3(p.x,0.0,p.y))
	var pulse := 0.0
	if air.get("puffs") != null: pulse = float(air.puffs.sample_at(Vector2(world.x,world.z),direction,float(air._gust_distance)))
	var speed := DRIFT*strength*(0.45+1.1*minf(1.0,FIELD_MEAN+pulse))
	var flow := plate.global_basis.inverse()*Vector3(direction.x,0.0,direction.y)
	var along := Vector2(flow.x,flow.z)
	var drift := along.normalized()*speed if along.length() > 0.0001 else Vector2.ZERO
	return drift+_gusts(scene,p)

## The wind tool's gusts passing `p` (plate), if the editor has the tool.
static func _gusts(scene: Node, p: Vector2) -> Vector2:
	var editor: Variant = scene.get("_chunk_editor")
	var gust: Variant = editor.get("gust") if editor is Object else null
	if gust is Object and gust.has_method("wind_at"): return gust.wind_at(p)
	return Vector2.ZERO
