extends "res://tools/landscapes/harness.gd"
## Mesa badlands: Chisel mesas (hold, then drag up) at several sizes and
## heights, some with Shift, then the Chisel breaks them: notches knocked into
## one mesa's lip and another's top sliced lower (the Hammer did this until
## it left the roll, 2026-10-02). Tests: can the plate look dry (badlands).

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
	await take_mode("mesa")
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
	# Take 3 (2026-10-02, the Hammer off the roll): the Chisel breaks the
	# mesas instead, notches knocked into A's lip and B's top sliced lower.
	await take_tool("chisel")
	await take_mode("notch")
	await size(2)
	var a: Vector2 = MESAS[0][0]
	var b: Vector2 = MESAS[1][0]
	await overview()
	var cam: Vector3 = editor.terrain.to_local(scene.camera.global_position)
	var side := (Vector2(cam.x,cam.z)-a).normalized().orthogonal()
	for k in range(4): await tap(lip(a,3)+side*(-1.8+1.2*k))
	across("A after a row of lip notches",a)
	await take_mode("slice")
	await hold_to(b,height(b)-1.2)
	across("B after a slice",b)
	measure_verbs()
	await overview()
	await still("broken")
	await view(a,13.0,scene.yaw+0.3,1.1)
	await still("broken-A")
	await view(b,12.0,scene.yaw-0.4,1.1)
	await still("broken-B")
	await put_down()
	await let_world_run(20.0)
	measure_life("plate")
	await overview()
	await still("life")
	await view(Vector2(0,-1),20.0,scene.yaw+0.4,1.15)
	await still("life-low")
