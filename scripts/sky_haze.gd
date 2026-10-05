extends RefCounted
## The glide's aerial perspective: with distance everything goes into one
## colour, the sky's own, so near islands keep their colour and far ones,
## islets and clouds melt into the sky behind them rather than into a grey
## or beige of their own. The build view's haze (shaders/reference_surface
## _haze.gdshaderinc) is left exactly as it was; this only comes on while
## gliding (scripts/sky_flight.gd), through `zs_glide_haze`.
##
## The colour is what the sky draws behind each ray. Above the horizon that
## is the dome's own gradient (shaders/reference_sky_common.gdshaderinc
## zsSkyBase) with the sun's aureole, so the haze warms toward the sun at
## golden hour. Below it, where the glide mostly looks, the cloud sea comes
## in, and far off the sea lifts into an air of its own style's (Opal's
## luminous pearl, Storybook's horizon, Mystic's cleaned pearl by day), so
## islands under the eye melt into that and not into the dusty horizon
## glow. At night it dims as the sea's horizon does and the sea is pulled
## down under the stars, so the haze never lifts the dark. `horizon` is that
## colour on the CPU, for the tests.
##
## The curve (`fog`) is gentle: a Gaussian falloff over REACH metres, a
## little thicker low toward the cloud sea, and whole by WHOLE, the distance
## islets are built at (scripts/sky_islets.gd VIEW), so nothing ever shows up
## out of clear air. A fresh island rises into place (scripts/sky_islands.gd
## `sunk`) much nearer than that; while it rises it is hazed by how far it
## still has to come (`emerging`), so it comes up out of the haze.
##
## A mountain range risen through the sea (scripts/sky_peaks.gd) is a
## landform, not scenery streamed in: within its reach (`publish`'s peaks)
## the curve's reach and its whole are lengthened (`fog_far`), so a range
## stands pale and blue in the distance long after an island would have
## gone.

const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
## The falloff's scale and where it is whole (m), and the cloud sea's height
## (scripts/sky_flight.gd SEA_Y), where the air is thickest: up to THICK more
## over the last LOW metres above it.
const REACH := 520.0
const WHOLE := SkyIslets.VIEW
const SEA := -105.0
const LOW := 75.0
const THICK := 0.6
## The most rising islands hazed at once (the shader's arrays).
const EMERGING := 4
## A range's curve: its reach and whole this many times the islands', and
## the most ranges hazed at once.
const PEAK_REACH := 1.8
const PEAK_WHOLE := 3.0
const PEAKS := 2

## How much of a thing `dist` metres off at height `y` has gone into the
## sky's colour (shaders/glide_haze.gdshaderinc, the same curve).
static func fog(dist: float, y: float) -> float:
	var low := smoothstep(SEA+LOW,SEA,y)
	var reach := dist*(1.0+THICK*low)/REACH
	return 1.0-exp(-reach*reach)*(1.0-smoothstep(WHOLE*0.72,WHOLE,dist))

## The same, `far` (0 to 1) of the way onto a range's gentler curve
## (zs_glide_fog_far).
static func fog_far(dist: float, y: float, far: float) -> float:
	var low := smoothstep(SEA+LOW,SEA,y)
	var reach := dist*(1.0+THICK*low)/(REACH*lerpf(1.0,PEAK_REACH,far))
	var whole := WHOLE*lerpf(1.0,PEAK_WHOLE,far)
	return 1.0-exp(-reach*reach)*(1.0-smoothstep(whole*0.72,whole,dist))

## The haze's colour along world ray `ray`, in display colour, from the
## sky's state (studies/celestial.gd `state`, plus zs_cloud) over a cloud sea
## `sea` (x strength, y style as in scripts/look_pass.gd CLOUD_STYLES):
## zs_glide_horizon in shaders/reference_surface_haze.gdshaderinc.
static func horizon(state: Dictionary, ray: Vector3, sea := Vector2.ZERO) -> Color:
	var toward := (Vector3(ray.x,maxf(ray.y,0.0),ray.z)+Vector3(0.0,1e-5,0.0)).normalized()
	var sun: Vector3 = state.get("zs_sun_direction",Vector3.UP)
	var clear := float(state.get("zs_celestial_clear",1.0))
	var deep := float(state.get("zs_night",0.0))*clear
	var dim := lerpf(1.0,0.4,deep)
	var col := _dome(state,toward)
	var high := smoothstep(0.02,0.4,sun.y)
	var sun_away := sqrt(maxf(2.0*(1.0-toward.dot(sun)),0.0))
	col += Vector3(1.0,0.42,0.12).lerp(Vector3(1.0,0.8,0.52),high)*exp(-sun_away/0.16)*lerpf(0.16,0.07,high)*clear*smoothstep(-0.06,0.01,sun.y)
	col *= dim
	var seen := Vector2(ray.x,ray.z).normalized()
	var air := sea_air(state,_dome(state,Vector3(seen.x,0.0,seen.y))*dim,int(sea.y))
	var veil := sea.x*smoothstep(-0.02,-0.16,ray.y)*lerpf(1.0,smoothstep(-0.34,-0.66,ray.y),deep)
	col = col.lerp(air,veil).max(Vector3.ZERO)
	col *= 0.98/maxf(maxf(maxf(col.x,col.y),col.z),0.98)
	return Color(col.x,col.y,col.z)

## The air the cloud sea in `style` lifts into far off, from the `horizon`
## it is given (zs_glide_sea_air).
static func sea_air(state: Dictionary, horizon: Vector3, style: int) -> Vector3:
	var luma := Vector3(0.2126,0.7152,0.0722)
	var sun: Vector3 = state.get("zs_sun_direction",Vector3.UP)
	var night := float(state.get("zs_night",0.0))
	var overcast := smoothstep(0.35,0.9,(state.get("zs_cloud",Vector4.ZERO) as Vector4).x)
	var lum := horizon.dot(luma)
	if style == 2:
		var day := smoothstep(0.1,0.32,sun.y)*(1.0-night)*(1.0-0.6*overcast)
		var top := maxf(horizon.x,maxf(horizon.y,horizon.z))
		var sat := (top-minf(horizon.x,minf(horizon.y,horizon.z)))/maxf(top,1e-4)
		var dusty := smoothstep(0.0,0.08,(horizon.x-horizon.z)/maxf(top,1e-4))*(1.0-smoothstep(0.28,0.5,sat))
		var up: Vector3 = state.get("zs_sky_up",Vector3.ONE)
		var hue := (horizon.max(Vector3.ZERO)/maxf(lum,1e-4)).lerp(up.max(Vector3.ZERO)/maxf(up.dot(luma),1e-4),0.8)
		return horizon.lerp(Vector3.ONE.lerp(hue,0.12)*lum*0.96,day*dusty)
	if style == 1: return horizon
	var level := maxf(lum,0.17*night*float(state.get("zs_celestial_clear",1.0)))*(1.0+0.3*overcast*(1.0-night))
	var cloud_sun: Vector3 = state.get("zs_cloud_sun",Vector3.ONE)
	var sun_hue := cloud_sun/maxf(maxf(maxf(cloud_sun.x,cloud_sun.y),cloud_sun.z),1e-3)
	var golden := smoothstep(0.35,0.06,sun.y)*smoothstep(-0.12,0.0,sun.y)*(1.0-overcast)
	var pearl := Vector3(0.97,0.97,1.0).lerp(sun_hue,lerpf(0.35,0.5,golden))
	return horizon.lerp(pearl*level,0.45)

## The dome's gradient along `toward` (zsSkyBase).
static func _dome(state: Dictionary, toward: Vector3) -> Vector3:
	var sun: Vector3 = state.get("zs_sun_direction",Vector3.UP)
	var down: Vector3 = state.get("zs_sky_down",Vector3.ZERO)
	var col := down.lerp(state.get("zs_sky_up",Vector3.ZERO),smoothstep(-0.4,0.7,toward.y))
	var to_sun := Vector2(toward.x,toward.z).normalized().dot(Vector2(sun.x,sun.z).normalized())*0.5+0.5
	col += state.get("zs_sky_glow",Vector3.ZERO)*exp(-absf(toward.y)*3.5)*lerpf(1.0,to_sun*to_sun*1.6+0.08,float(state.get("zs_dusk_direction",0.0)))
	var belt := float(state.get("zs_belt",0.0))
	if belt > 0.001:
		var away := 1.0-to_sun
		col += Vector3(0.42,0.13,0.16)*exp(-(toward.y-0.1)*(toward.y-0.1)/0.012)*away*away*belt
		col = col.lerp(col*Vector3(0.55,0.62,0.8),exp(-toward.y*toward.y/0.004)*away*0.5*belt)
	return col

## The islands still rising into place, as boxes round them, nearest
## first: [low corner, high corner, how hidden (0 to 1)], in world metres.
## The box reaches down past the deepest rock an island's outline can hang
## (scripts/island_shore.gd DEEPEST).
## A wandered-to island rises its whole WANDER_RISE depth out of the haze;
## one surfacing from the cloud sea is hidden until it is that near.
static func emerging(islands: Node, eye: Vector3) -> Array:
	var out := []
	var terrain: Node3D = islands.editor.terrain if islands.get("editor") != null else null
	if terrain == null: return out
	var corners := [terrain.to_global(Vector3(-SkyIslands.HALF-1.0,NativeTerrainData.SLAB_BASE-preload("res://scripts/island_shore.gd").DEEPEST-2.0,-SkyIslands.HALF-1.0)),
		terrain.to_global(Vector3(SkyIslands.HALF+1.0,12.0,SkyIslands.HALF+1.0))]
	var lo: Vector3 = (corners[0] as Vector3).min(corners[1])
	var hi: Vector3 = (corners[0] as Vector3).max(corners[1])
	for i in range(islands.offsets.size()):
		var sunk: float = islands.sunk(i)
		if sunk <= 0.0: continue
		var at: Vector3 = islands.offsets[i]+Vector3.DOWN*sunk
		out.append([lo+at,hi+at,clampf(sunk/SkyIslands.WANDER_RISE.x,0.0,1.0)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return eye.distance_squared_to((a[0]+a[1])*0.5) < eye.distance_squared_to((b[0]+b[1])*0.5))
	return out.slice(0,EMERGING)

## Lays the haze on by `amount` (0 to 1) and hands the display haze's
## `blend` (studies/display_fog.gd) the cloud sea under it (`sea`, as in
## `horizon`), the rising islands' boxes and the standing ranges' spots
## (SkyPeaks `haze_spots`).
static func publish(amount: float, blend: ShaderMaterial = null, sea := Vector2.ZERO, rising: Array = [], peaks: Array = []) -> void:
	RenderingServer.global_shader_parameter_set("zs_glide_haze",Vector4(amount,REACH,WHOLE,SEA))
	if blend == null: return
	blend.set_shader_parameter("glide_sea",sea)
	var lows := PackedVector4Array()
	var highs := PackedVector4Array()
	for i in range(EMERGING):
		var box: Array = rising[i] if i < rising.size() else [Vector3.ZERO,Vector3.ZERO,0.0]
		lows.append(Vector4(box[0].x,box[0].y,box[0].z,float(box[2])*amount))
		highs.append(Vector4(box[1].x,box[1].y,box[1].z,0.0))
	blend.set_shader_parameter("glide_emerge_lo",lows)
	blend.set_shader_parameter("glide_emerge_hi",highs)
	var spots := PackedVector4Array()
	for i in range(PEAKS): spots.append(peaks[i] if i < peaks.size() else Vector4.ZERO)
	blend.set_shader_parameter("glide_peaks",spots)
