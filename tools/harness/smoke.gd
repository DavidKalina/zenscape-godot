extends "res://tools/harness/drive.gd"
## The smoke check: `--scene=` opened the way the game opens it, `--frames=`
## (400) of its loop run untouched, and what it reached printed. Run it with
## tools/smoke.py, which reads the log's errors.
##   godot --headless --fixed-fps 60 --path . -s tools/harness/smoke.gd -- --scene=studies/trap_yard.tscn [--frames=400] [--scene-args --seed=2]

func drive() -> void:
	var scene := String(arg("scene",""))
	if scene == "":
		check(false,"smoke","no --scene=")
		return
	var t := Time.get_ticks_msec()
	var ready := await open(scene,null,arg_int("ready-frames",3000))
	result("scene",scene)
	result("ready_frames",ready)
	result("ready_s",snappedf((Time.get_ticks_msec()-t)/1000.0,0.1))
	result("walker","walk_ready" in study)
	var n := arg_int("frames",400)
	t = Time.get_ticks_msec()
	await frames(n)
	result("run_s",snappedf((Time.get_ticks_msec()-t)/1000.0,0.1))
	result("nodes",study.find_children("*","",true,false).size())
