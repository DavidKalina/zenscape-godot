extends SceneTree
## Headless probe of FlowFalls._chain (scripts/flow_falls.gd): falls stacked
## one above the other join into one; falls side by side or far apart do not.
##   godot --headless --path . -s res://tools/probe_fall_chain.gd
const FlowFalls := preload("res://scripts/flow_falls.gd")
var failures := []

func _initialize() -> void:
	var upper := fall(Vector3(0,4,0),Vector3(0,2.1,0.6))
	var lower := fall(Vector3(0.1,2.0,1.2),Vector3(0.1,0.2,1.8))
	var beside := fall(Vector3(3,4,0),Vector3(3,2,0.6))
	var joined: Array = FlowFalls._chain([lower,upper])
	check("a fall over a ledge onto another is one fall",joined.size() == 1,joined.size())
	if joined.size() == 1:
		var one: Dictionary = joined[0]
		check("it runs from the upper lip to the lower plunge",(one.lip as Vector3).is_equal_approx(upper.lip) and (one.plunge as Vector3).is_equal_approx(lower.plunge))
		check("its course holds both",(one.course as PackedVector4Array).size() == 6,(one.course as PackedVector4Array).size())
		check("its drop is the whole height",is_equal_approx(float(one.drop),3.8),one.drop)
	check("falls side by side stay apart",FlowFalls._chain([upper,beside]).size() == 2)
	var far_below := fall(Vector3(0.1,0.9,1.2),Vector3(0.1,0.0,1.8))
	check("a fall far below another's plunge stays apart",FlowFalls._chain([upper,far_below]).size() == 2)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func fall(lip: Vector3, plunge: Vector3) -> Dictionary:
	var course := PackedVector4Array()
	for k in range(3):
		var at := lip.lerp(plunge,k/2.0)
		course.append(Vector4(at.x,at.y,at.z,0.4))
	return {"course":course,"lip":lip,"plunge":plunge,"flux":0.1,"drop":lip.y-plunge.y,"plunge_depth":0.1,"lip_dir":Vector2(0,1)}

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))
