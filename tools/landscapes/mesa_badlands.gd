extends "res://tools/landscapes/harness.gd"
## Mesa badlands: Chisel mesas (hold, then drag up) at several sizes and
## heights, some with Shift, then the Hammer: taps on a mesa's middle and on
## its lip, a Shift tap, and a drag across a mesa, to knock tops down and
## spill scree. Tests: does the Hammer feel distinct from the other tools,
## and can the plate look dry (badlands) at all.

## [centre, size pip, top height wanted, fine]
const MESAS := [
	[Vector2(-6.0,-5.0),3,4.5,false],
	[Vector2(4.5,-6.0),2,3.0,false],
	[Vector2(-3.0,5.5),1,3.5,false], # take 1 at (-4,4.5): the press did nothing
	[Vector2(5.5,3.5),2,2.0,true],
	[Vector2(0.5,-0.5),1,1.5,true],
]

func title() -> String: return "mesa_badlands"

func across(label: String, c: Vector2, half := 5.0) -> void:
	var parts: PackedStringArray = []
	for i in range(11):
		parts.append("%.2f" % height(c+Vector2(-half+half*2.0*i/10.0,0.0)))
	log_line("across %s x %+.0f..%+.0f: %s" % [label,-half,half," ".join(parts)])
	parts.clear()
	for i in range(11):
		parts.append("%.2f" % height(c+Vector2(0.0,-half+half*2.0*i/10.0)))
	log_line("  down %s z %+.0f..%+.0f: %s" % [label,-half,half," ".join(parts)])

func lip(c: Vector2, pip: int) -> Vector2:
	# The mesa's edge on the camera side, a touch inside the outline.
	var cam: Vector3 = editor.terrain.to_local(scene.camera.global_position)
	var toward := (Vector2(cam.x,cam.z)-c).normalized()
	return c+toward*2.5*[0.6,1.0,1.5][pip-1]*0.8

func build() -> void:
	await take_tool("chisel")
	for m: Array in MESAS:
		await size(m[1])
		await hold_to(m[0],m[2],m[3])
		log_line("verbs now %d, last %s" % [worked.size(),worked.back() if not worked.is_empty() else "none"])
	for m: Array in MESAS: across("mesa %s" % m[0],m[0])
	measure_verbs()
	await overview()
	await still("mesas")
	await view(Vector2(0,-1),20.0,scene.yaw+0.4,1.15)
	await still("mesas-low")
	await take_tool("hammer")
	await size(2)
	var a: Vector2 = MESAS[0][0]
	var b: Vector2 = MESAS[1][0]
	var c: Vector2 = MESAS[2][0]
	var d: Vector2 = MESAS[3][0]
	await overview()
	# A blow in the middle of a mesa's top (flat ground, not rock).
	await tap(a)
	across("A after a middle tap",a)
	# Blows on its lip (the cliff edge).
	await tap(lip(a,3))
	await tap(lip(a,3)+Vector2(1.2,0.0))
	across("A after two lip taps",a)
	# Take 2: a row of blows along A's near lip, watching the foot for scree.
	var cam: Vector3 = editor.terrain.to_local(scene.camera.global_position)
	var toward := (Vector2(cam.x,cam.z)-a).normalized()
	var side := toward.orthogonal()
	var foot := a+toward*5.0
	heights_at({"A foot":foot,"A foot+1":foot+toward,"A lip":lip(a,3)})
	for k in range(4): await tap(lip(a,3)+side*(-1.8+1.2*k))
	heights_at({"A foot":foot,"A foot+1":foot+toward,"A lip":lip(a,3)})
	across("A after a row of lip taps",a)
	# A drag of blows straight across B (take 1 read it as one knock), after a pause.
	await seconds(1.0)
	await drag([b+Vector2(-3.5,0.4),b+Vector2(3.5,-0.4)],2.0)
	across("B after a drag",b)
	# And a drag of blows along B's near lip.
	var tb := (Vector2(cam.x,cam.z)-b).normalized()
	await drag([b+tb*1.8-tb.orthogonal()*2.0,b+tb*1.8+tb.orthogonal()*2.0],2.0)
	across("B after a lip drag",b)
	# Shift taps on C's lip.
	await tap(lip(c,1),true)
	await tap(lip(c,1)+Vector2(0.6,0.0),true)
	across("C after fine lip taps",c)
	# A held blow on D.
	await tap(lip(d,2),false,0.6)
	across("D after a held blow",d)
	measure_verbs()
	await overview()
	await still("hammered")
	await view(a,13.0,scene.yaw+0.3,1.1)
	await still("hammered-A")
	await view(b,12.0,scene.yaw-0.4,1.1)
	await still("hammered-B")
	await put_down()
	await let_world_run(20.0)
	measure_life("plate")
	await overview()
	await still("life")
	await view(Vector2(0,-1),20.0,scene.yaw+0.4,1.15)
	await still("life-low")
