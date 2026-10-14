extends "res://tools/harness/drive.gd"
## Every station of a study (its number keys): he is sent there and must
## stand within a second, above the study's fall line. The first check of a
## greybox round.
##   python tools/drive.py tools/harness/stations.gd -- --scene=studies/greybox/lidstack.tscn
##   python tools/sweep.py tools/harness/stations.gd --set scene=studies/greybox/a.tscn,studies/greybox/b.tscn

func drive() -> void:
	await open(String(arg("scene","studies/greybox/lidstack.tscn")))
	if study == null or not "stations" in study: return
	for st: Dictionary in study.stations:
		await go_to(int(st.key))
		var stood := await until(func() -> bool: return motor.grounded,60)
		await frames(60)
		check(stood >= 0 and motor.grounded and motor.feet.y > float(study.lost),"station %s stands" % st.key,"feet %s" % motor.feet.round())
	result("stations",(study.stations as Array).size())
