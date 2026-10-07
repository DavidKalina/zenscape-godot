extends SceneTree
## The islander (scripts/islander_figure.gd): it stands with its boots on
## the ground; every move runs without its pose going wrong; jumping, it
## leaves the ground and comes back down onto it; waving, its right hand
## goes up over its head; hailing, both do; walking, one boot is always
## down while the other lifts, and the planted boot slides back at
## WALK_SPEED, so moved at that speed it does not skate; and it starts no
## unknown move.
const IslanderFigure = preload("res://scripts/islander_figure.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	var figure: Node3D = IslanderFigure.new()
	root.add_child(figure)
	figure.set_process(false)
	for i in range(120): figure.advance(DT)
	check(absf(_soles(figure)) < 0.003,"Idle, it stands on the ground (soles at %.4f)" % _soles(figure))
	for move: String in IslanderFigure.MOVES:
		figure.play(move)
		var ok := true
		var highest := -INF
		var lowest := INF
		var hands := Vector2(-INF,-INF)
		for i in range(240):
			figure.advance(DT)
			for node: Node3D in figure.find_children("*","Node3D",true,false):
				ok = ok and node.transform.origin.is_finite() and node.transform.basis.x.is_finite()
			highest = maxf(highest,_soles(figure))
			lowest = minf(lowest,_soles(figure))
			hands = Vector2(maxf(hands.x,_hand(figure,0)),maxf(hands.y,_hand(figure,1)))
		check(ok,"%s: every part stays finite" % move)
		var head := _head(figure)
		match move:
			"jump":
				check(highest > 0.08,"Jumping, it leaves the ground (%.3f)" % highest)
				check(lowest < 0.003,"And lands back on it (%.4f)" % lowest)
			"wave":
				check(hands.y > head-0.05 and hands.x < head-0.1,"Waving, the right hand goes up, the left stays down")
			"hail":
				check(hands.x > head-0.05 and hands.y > head-0.05,"Hailing, both hands go up")
			"walk":
				check(lowest < 0.003,"Walking, a boot is always on the ground (%.4f)" % lowest)
				check(_highest_boot(figure,240) > 0.015,"And the other lifts")
				check(absf(_planted_speed(figure)-IslanderFigure.WALK_SPEED) < 0.01,"The planted boot slides back at WALK_SPEED (%.3f)" % _planted_speed(figure))
	figure.play("dance")
	check(figure.move == IslanderFigure.MOVES[-1],"An unknown move is ignored")
	figure.free()
	print("PASS: islander figure" if failures == 0 else "FAIL: islander figure")
	quit(1 if failures else 0)

## The lowest boot sole's height over the figure's origin.
func _soles(figure: Node3D) -> float:
	var low := INF
	for leg: Array in figure._legs: low = minf(low,(leg[2] as Node3D).position.y-IslanderFigure.ANKLE)
	return low

## The highest any boot lifts over `frames` more frames.
func _highest_boot(figure: Node3D, frames: int) -> float:
	var high := -INF
	for i in range(frames):
		figure.advance(DT)
		for leg: Array in figure._legs: high = maxf(high,(leg[2] as Node3D).position.y-IslanderFigure.ANKLE)
	return high

## How fast the lower (planted) boot moves back, over a few frames.
func _planted_speed(figure: Node3D) -> float:
	var speeds := []
	for i in range(30):
		var low := 0 if (figure._legs[0][2] as Node3D).position.y < (figure._legs[1][2] as Node3D).position.y else 1
		var was := (figure._legs[low][2] as Node3D).position.z
		figure.advance(DT)
		var now := (figure._legs[low][2] as Node3D).position.z
		if now > was: speeds.append((now-was)/DT)
	speeds.sort()
	return speeds[speeds.size()/2] if speeds.size() > 0 else 0.0

## A hand's height (0 left, 1 right) and the head's, in the figure's frame.
func _hand(figure: Node3D, side: int) -> float:
	return (_torso(figure)*(figure._arms[side][2] as Node3D).position).y

func _head(figure: Node3D) -> float:
	var neck: Node3D = figure._neck
	return (_torso(figure)*neck.transform*(figure._head as Node3D).position).y

## The torso's transform in the figure's frame.
func _torso(figure: Node3D) -> Transform3D:
	return (figure._hips as Node3D).transform*(figure._torso as Node3D).transform

func check(ok: bool, label: String) -> void:
	print(("OK   " if ok else "FAIL ")+label)
	if not ok: failures += 1
