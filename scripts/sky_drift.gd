extends RefCounted
## The live sky's cloud carried on the sky's wind (docs/design/sky-weather/
## spec-storm-dragon.md, "Weather that moves through the world"): the kit
## sky's towering cumulus (scripts/sky_towers.gd, which on its own never
## drifts) and its small drifting puffs (scripts/sky_clouds.gd `blow`) both
## travel at `speed` m/s along the atmosphere's wind (`_air_angle`, the way
## the plane's storm air and rain slant go), faster in a storm, so towers
## and banks are seen to cross the far isles. Their shade on the land comes
## with them (the cloud volume marches the towers where they stand).
##
## A tower carried WRAP m downwind of the eye is set back WRAP m upwind of
## it, far in the haze, and fades in again there (SkyTowers FADE_IN), so
## the sky keeps its few towers round wherever the plane flies.
##   --cloud-drift=N   the fair-weather speed (m/s; 0 holds them still)

## The fair-weather speed (m/s) and what a full storm adds.
const SPEED := 9.0
const STORM_SPEED := 7.0
## Downwind of the eye past this (m, along the wind), a tower comes back
## this far upwind.
const WRAP := 2300.0

var speed := SPEED

func _init() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if str(arg).begins_with("--cloud-drift="): speed = maxf(0.0,float(str(arg).get_slice("=",1)))

## The wind (m/s, x then z) the cloud rides now: along `angle` (radians
## round, x then z), `storm` (0 to 1) adding STORM_SPEED.
func wind(angle: float, storm: float) -> Vector2:
	if speed <= 0.0: return Vector2.ZERO
	return Vector2(cos(angle),sin(angle))*(speed+STORM_SPEED*storm)

## One frame: every tower of `host` (a cloud host, scripts/cloud_host.gd)
## carried `delta` s on the wind, the puffs set riding it, and towers
## carried past WRAP set back upwind of `eye`.
func step(delta: float, host: Node, eye: Vector3, angle: float, storm: float) -> void:
	if host == null or host.get("towers") == null or host.get("clouds") == null: return
	var blow := wind(angle,storm)
	(host.clouds as Node).blow(blow,float(host.time))
	var towers: Node3D = host.towers
	var by := Vector3(blow.x,0.0,blow.y)*delta
	var way := Vector3(blow.x,0.0,blow.y).normalized() if blow.length() > 0.01 else Vector3.ZERO
	for i in range(towers.fixed.size()):
		var key := "%d,0" % i
		var spot: Vector3 = towers.fixed[i]+by
		var b: Variant = towers.built.get(key)
		var ahead := (spot+towers.position-eye).dot(way)
		var wrapped := way != Vector3.ZERO and ahead > WRAP
		if wrapped: spot -= way*(ahead+WRAP)
		towers.fixed[i] = spot
		if b == null: continue
		b.home = spot
		(b.node as Node3D).position = spot
		if wrapped:
			b.age = 0.0
			(b.material as ShaderMaterial).set_shader_parameter("strength",0.0)

## The cloud's way as the readout says it: "9 m/s toward the east-north-east".
func describe(angle: float, storm: float) -> String:
	var w := wind(angle,storm)
	if w.length() < 0.01: return "Cloud held still"
	# x east, z south: the compass bearing it blows toward.
	var bearing := fposmod(rad_to_deg(atan2(w.x,-w.y)),360.0)
	var names := ["north","north-east","east","south-east","south","south-west","west","north-west"]
	return "Cloud drifts %d m/s toward the %s" % [roundi(w.length()),names[roundi(bearing/45.0)%8]]
