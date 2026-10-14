extends RefCounted
## The gust's knock, shared by everything that blows a body away with a
## burst of pressurized air: the wind blaster (scripts/traps/trap_wind.gd)
## and the wind horn (scripts/wind_horn.gd). Not a breeze: once per blow,
## the first frame he is in it, a knock (PilotMotor.knock, a tumble) that
## throws him `out` m along the gust (his skid counted), peaking `up` m over
## where he was hit, out of a hang, a swim or the sail too. The source names
## itself, so one gust can't restun him within the motor's `restun_gap`.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The blow's knobs and their defaults, from `pilot` (a motor at the
## wanderer's size): `blast_out` (run x 3), `blast_up` (run x 0.25), the
## tell before it (`delay`, s), the blow (`blast_time`, s) and the rest
## after it (`rearm`, s).
static func defaults(pilot: PilotMotor) -> Dictionary:
	return {"blast_out":pilot.run*3.0,"blast_up":pilot.run*0.25,"delay":0.5,"blast_time":0.3,"rearm":2.0}

## The defaults at the wanderer's size (WorldScale.wanderer).
static func wanderer_defaults() -> Dictionary:
	var p := PilotMotor.new()
	p.set_size(WorldScale.wanderer)
	return defaults(p)

## Whether a gust can take him now: anyone but a rider (whose ride holds
## him). A swimmer is taken: a gust lifts him out of the water.
static func can_take(motor: PilotMotor) -> bool:
	return motor != null and motor.rider == null

## Knock him along `way` (world; only its flat part counts) `out` m and `up`
## m, `source` the gust's owner. The velocity given, or zero when `way` has
## no flat part (nothing is done).
static func knock(motor: PilotMotor, way: Vector3, out: float, up: float, source: Object) -> Vector3:
	var flat := Vector2(way.x,way.z)
	if flat.length() < 0.05: return Vector3.ZERO
	var v := motor.knock_velocity(flat,out,up)
	motor.knock(v,source)
	return v
