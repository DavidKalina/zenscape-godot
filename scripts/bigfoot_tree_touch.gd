extends RefCounted
## One quiet encounter, sampled from action time so pauses and scrubbing agree.
const DURATION := 8.2

static func sample(t: float) -> Dictionary:
	var reach := smoothstep(0.65,2.1,t)
	var release := smoothstep(5.5,7.55,t)
	var affection := smoothstep(2.3,3.5,t)*(1.0-smoothstep(4.6,5.7,t))
	var glance_away := smoothstep(5.1,5.8,t)*(1.0-smoothstep(6.1,6.85,t))
	var goodbye := smoothstep(5.4,6.2,t)*(1.0-smoothstep(7.1,8.2,t))
	return {
		"reach":reach,"release":release,
		"weight":smoothstep(0.15,0.65,t)*(1.0-smoothstep(7.55,8.2,t)),
		"arc":sin(reach*PI)*sin(reach*PI)*(1.0-release),
		"spine":Vector3(0.045*affection,-0.04*affection+0.12*goodbye,-0.025*affection),
		"head":Vector3(-0.018*affection,0,-0.075*affection),
		"glance_away":glance_away,
		"phase":"notice" if t<0.65 else "reach" if t<2.1 else "linger" if t<5.1 else "goodbye" if t<7.55 else "settle",
	}
