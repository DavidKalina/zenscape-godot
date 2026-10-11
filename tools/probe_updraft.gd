extends SceneTree
## Updraft probe: rise at full charge from standing, mid-air and out of a slide
## hop, and whether the flat pace survives the next 0.5 s of air.
## godot --headless --path . --script tools/probe_updraft.gd
const DT := 1.0/60.0

func _initialize() -> void:
	var s: Node3D = load("res://studies/character_study.tscn").instantiate()
	root.add_child(s)
	for i in range(10): await process_frame
	s.scripted = true
	var m = s.motor
	var u = s.updraft
	print("updraft on: ",u != null)
	# Standing.
	_settle(s)
	var y0: float = m.feet.y
	u.charge = 1.0
	var peak := _fire(s,y0)
	print("standing: planned ",snappedf(u.last_rise,0.01)," rose ",snappedf(peak-y0,0.01))
	# Mid-air: a jump, fire on the way up/at the top.
	_settle(s)
	s.script_jump = true
	for i in range(6): s.tick(DT)
	s.script_jump = false
	for i in range(12): s.tick(DT)
	print("  airborne before: ",not m.grounded," vy ",snappedf(m.velocity.y,0.1))
	y0 = m.feet.y
	u.charge = 1.0
	peak = _fire(s,y0)
	print("mid-air (relative to fire height): rose ",snappedf(peak-y0,0.01))
	# Mid-air, falling.
	_settle(s)
	m.feet.y += 8.0
	m.velocity = Vector3.ZERO
	for i in range(20): s.tick(DT)
	print("  falling vy ",snappedf(m.velocity.y,0.1))
	y0 = m.feet.y
	u.charge = 1.0
	peak = _fire(s,y0)
	print("falling: rose ",snappedf(peak-y0,0.01))
	# Out of a slide hop at pace, stick forward: flat pace over the next 0.5 s.
	for pace in [13.0,10.0,6.0]:
		_settle(s)
		var fw: Vector2 = m.forward(m.facing)
		m.velocity = Vector3(fw.x*pace,0.0,fw.y*pace)
		s.script_want = fw
		for i in range(3): s.tick(DT)
		u.charge = 1.0
		var before: float = m.speed()
		var move_before: String = m.move
		u.update(DT,m,true)
		var out := [snappedf(before,0.1)]
		for i in range(30):
			s.tick(DT)
			if i == 14 or i == 29: out.append(snappedf(m.speed(),0.1))
		print("pace ",pace," (move '",move_before,"') flat before/0.25s/0.5s ",out," stick forward")
		s.script_want = Vector2.ZERO
	# Without the stick.
	_settle(s)
	var fw2: Vector2 = m.forward(m.facing)
	m.velocity = Vector3(fw2.x*13.0,0.0,fw2.y*13.0)
	s.script_want = Vector2.ZERO
	for i in range(3): s.tick(DT)
	u.charge = 1.0
	var b2: float = m.speed()
	u.update(DT,m,true)
	var o2 := [snappedf(b2,0.1)]
	for i in range(30):
		s.tick(DT)
		if i == 14 or i == 29: o2.append(snappedf(m.speed(),0.1))
	print("pace 13 no stick: flat before/0.25s/0.5s ",o2)
	# Sail after the updraft.
	_settle(s)
	u.charge = 1.0
	u.update(DT,m,true)
	for i in range(40): s.tick(DT)
	s.script_jump = true
	for i in range(3): s.tick(DT)
	print("sail after updraft: move '",m.move,"' sail open ",m.sail.open)
	quit()

func _settle(s) -> void:
	s.script_want = Vector2.ZERO
	s.script_jump = false
	s.respawn()
	s.updraft.charge = 0.0
	for i in range(60): s.tick(DT)

func _fire(s, _y0: float) -> float:
	var m = s.motor
	s.updraft.update(DT,m,true)
	var peak: float = m.feet.y
	for i in range(150):
		s.tick(DT)
		peak = maxf(peak,m.feet.y)
	return peak
