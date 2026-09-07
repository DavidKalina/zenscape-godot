extends RefCounted
## Slow weather state from weather.js / wet-ground.js, independent of particles.
var autumn := 0.0
var target_autumn := 0.0
var cold := 0.0
var target_cold := 0.0
var ice := 0.0
var snow_cover := 0.0
var ground_wet := 0.0
var air_wet := 0.0
var foliage_wet := 0.0
var flow_time := 0.0
var snow_phase := 0.0

func advance(delta: float, paused: bool, rain: float, cloud: float, wind: float) -> void:
	if not paused:
		autumn = lerpf(autumn, target_autumn, 1.0 - exp(-delta * 0.55))
		cold = lerpf(cold, target_cold, 1.0 - exp(-delta * 0.55))
		snow_phase = smoothstep(0.35, 0.7, cold)
		var snowing := minf(1.0, rain * 1.2) * snow_phase
		var melt := maxf(0.0, 0.55 - cold) * 1.8
		snow_cover = clampf(snow_cover + (snowing * 0.16 * (1.0 - snow_cover) - melt * 0.09 * snow_cover) * delta, 0.0, 1.0)
		ice = lerpf(ice, snow_phase, 1.0 - exp(-delta * 0.12))
		ground_wet = wet_after(ground_wet, rain, cold, cloud, wind, delta)
		var raining := minf(1.0, rain * 1.5) * (1.0 - snow_phase)
		air_wet = lerpf(air_wet, raining if raining > air_wet else 0.0, 1.0 - exp(-delta * (0.35 if raining > air_wet else 0.04)))
		if ice <= 0.985:
			flow_time += delta * (1.0 - ice * 0.98)
	snow_phase = smoothstep(0.35, 0.7, cold)
	foliage_wet = rain * (1.0 - snow_phase)
	publish()

func publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_autumn", autumn)
	RenderingServer.global_shader_parameter_set("zs_ice", ice)
	RenderingServer.global_shader_parameter_set("zs_snow", snow_cover)
	RenderingServer.global_shader_parameter_set("zs_ground_wet", ground_wet * (1.0 - snow_phase))
	RenderingServer.global_shader_parameter_set("zs_foliage_wet", foliage_wet)
	RenderingServer.global_shader_parameter_set("zs_flow_time", flow_time)

static func wet_after(wet: float, rain: float, temperature: float, cloud: float, wind: float, dt: float) -> float:
	var liquid := clampf(rain, 0.0, 1.0) * (1.0 - smoothstep(0.35, 0.7, temperature))
	var soak := liquid * 0.32
	var dry := (1.0 - liquid) * (0.012 + (1.0 - cloud) * 0.018 + minf(2.5, wind) * 0.004)
	var rate := soak + dry
	var target := soak / rate
	var next := target + (wet - target) * exp(-rate * maxf(0.0, dt))
	return 0.0 if next < 0.0001 else clampf(next, 0.0, 1.0)
