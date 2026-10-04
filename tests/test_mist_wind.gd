extends SceneTree
## The ground mist follows the wind (scripts/redwood_biome_mist.gd `_blow`):
## it drifts on the scene's clock, faster in a stronger wind, is drawn out
## along a wind, and stands still while the world is paused. The look itself
## (shaders/beauty_mist.gdshader, redwood_biome_mist.gdshader) needs Forward+
## and a rendered run; this checks only what the CPU hands the shaders.
##   godot --headless --path . --script tests/test_mist_wind.gd
var failures := 0

class Stage extends Node3D:
	var _atmosphere: Node
	var _motion_time := 0.0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("OK   " if ok else "FAIL ")+label)
	if not ok: failures += 1

## Metres the mist drifts in `seconds` of scene time at wind `strength`.
func drift(strength: float, seconds: float) -> Dictionary:
	var stage := Stage.new()
	var air: Node = preload("res://studies/atmosphere.gd").new()
	air._air_strength = strength
	air.swell = 0.0
	air._wind_time = 0.0
	stage._atmosphere = air
	var mist = preload("res://scripts/redwood_biome_mist.gd").new()
	var steps := int(seconds*60.0)
	for i in range(steps+1):
		stage._motion_time = i/60.0
		mist._blow(stage)
	var result := {"travel":mist.air_travel,"stretch":float(mist.woodland_material.get_shader_parameter("air_stretch")),
		"strength":float(mist.woodland_material.get_shader_parameter("air_strength")),"redwood":float(mist.fog_material.get_shader_parameter("air_travel"))}
	# Paused: the clock stops, and so does the mist.
	var held: float = mist.air_travel
	for i in range(30): mist._blow(stage)
	result.held = is_equal_approx(held,mist.air_travel)
	mist.free()
	air.free()
	stage.free()
	return result

func run() -> void:
	var calm := drift(0.0,10.0)
	var breeze := drift(0.4,10.0)
	var gale := drift(2.0,10.0)
	print("10 s of drift: calm %.2f m, breeze %.2f m, gale %.2f m" % [calm.travel,breeze.travel,gale.travel])
	check(calm.travel > 0.5 and calm.travel < 1.5,"still air leaves only a slow creep")
	check(breeze.travel > calm.travel*2.0,"a breeze carries it visibly faster")
	check(gale.travel > breeze.travel*2.0,"a strong wind carries it faster again")
	check(is_equal_approx(calm.stretch,1.0) and gale.stretch < breeze.stretch and gale.stretch < 0.5,"a wind draws it out along itself")
	check(is_equal_approx(gale.strength,2.0),"the shader hears the wind's strength")
	check(is_equal_approx(gale.redwood,gale.travel),"the redwood mist drifts on the same air")
	check(calm.held and gale.held,"a paused world holds the mist still")
	print("RESULT ","PASS" if failures == 0 else "FAIL")
	quit(1 if failures > 0 else 0)
