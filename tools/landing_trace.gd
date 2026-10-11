extends SceneTree
## One bot approach in the landing study, printed tick by tick (every half
## second and on every event): why a run went as it did.
##   godot --headless --path . -s tools/landing_trace.gd -- <station> <skill> [seed]

const Course = preload("res://scripts/landing_course.gd")
const Run = preload("res://scripts/landing_run.gd")
const Bot = preload("res://scripts/landing_bot.gd")
const DT := 1.0/60.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var s := Course.station(args[0] if args.size() > 0 else "long_field")
	var params := Bot.params(args[1] if args.size() > 1 else "decent")
	var run := Run.new(s,"bot",params)
	var bot := Bot.new(params,int(args[2]) if args.size() > 2 else 1000)
	var k := 0
	while not run.done:
		var input := bot.input(run,DT)
		run.tick(DT,input)
		if k%30 == 0 or not run.last.is_empty():
			var p: Vector3 = run.plane.position
			print("%5.1f %-8s %-7s x%6.1f y%6.1f z%7.1f speed %4.1f vy %5.2f pitch %5.2f heading %5.2f | turn %4.1f pitch %4.1f brake %.0f flaps %.0f %s" % [run.t,bot.mode,run.ml.NAMES[run.ml.phase],
				p.x,p.y,p.z,run.plane.speed,run.plane.velocity.y,run.plane.pitch,run.plane.heading,input.turn,input.pitch,input.brake,input.flaps,str(run.last) if not run.last.is_empty() else ""])
		k += 1
	print(run.metrics())
	quit()
