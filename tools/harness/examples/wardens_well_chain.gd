extends "res://tools/harness/chain.gd"
## The Warden's Well's chains (scripts/kit_isle/greybox/gb_wardens_well.gd)
## on the chain helper (tools/harness/chain.gd): heads and a cannon.
##
##   --chain=relay (default): head to head. On the dais lip on head 1's axis
##     (the study's station 3), no input: head 1 gulps him and blasts him
##     north down onto cell 1, his skid ends in head 2's face, head 2 blasts
##     him west down onto the exit rim. Passed: at rest on the exit rim,
##     both heads having gulped him.
##   --chain=cannon: the missed relay. Head 2 taken off (as its body would),
##     he runs west off cell 1 from where head 1's skid ends (0, -4, -14.9),
##     drops into the catching cannon in void 2, which fires him onto the
##     exit rim. Passed: at rest on the exit rim, the cannon having fired.
##
##   python tools/drive.py tools/harness/examples/wardens_well_chain.gd -- --trials=10 --scene-args --motif=wardens_well --bodies=0 [--grey]
const WW = preload("res://scripts/kit_isle/greybox/gb_wardens_well.gd")

## The relay's start (the study's station 3) and the cannon chain's (where
## head 1's skid ends on cell 1).
const LIP_AT := WW.H1+Vector3(0.0,0.0,-WW.LIP)
const CELL_AT := Vector3(0.0,WW.Y_CELL,WW.H2.z)
## The exit rim (its LAYOUT mass), where both chains end.
const EXIT := Rect2(-34.0,-34.0,23.0,29.0)
const MOST := 40.0

func drive() -> void:
	if not await open_motif("wardens_well"): return
	var which := str(arg("chain","relay"))
	result("chain",which)
	await trials(arg_int("trials",10),relay if which == "relay" else missed,arg_float("jitter",0.5))

func relay(t: Dictionary) -> Dictionary:
	await place(motif_point(LIP_AT)+t.jitter,Vector2(0.0,-1.0))
	var f0 := frame
	var gulps := [-1.0,-1.0]
	var cell_s := -1.0
	var floor_y := motif_floor()-LOST_UNDER
	var cell_y: float = motif_point(CELL_AT).y
	while frame-f0 < int(MOST*60.0):
		var heads := motif_heads()
		for k in range(mini(heads.size(),2)):
			if gulps[k] < 0.0 and heads[k] != null and bool(heads[k].swallowed): gulps[k] = (frame-f0)/60.0
		if cell_s < 0.0 and motor.grounded and absf(motor.feet.y-cell_y) < 0.6: cell_s = (frame-f0)/60.0
		if gulps[1] >= 0.0 and heads.size() > 1 and heads[1] != null and not bool(heads[1].swallowed): break
		if motor.feet.y < floor_y: break
		await frames(1)
	var out := {"gulp1_s":snappedf(gulps[0],0.1),"cell1_s":snappedf(cell_s,0.1),"gulp2_s":snappedf(gulps[1],0.1)}
	if gulps[1] < 0.0:
		out.ok = false
		out.why = "head 2 never gulped him (head 1 %s, on cell 1 %s)" % ["yes" if gulps[0] >= 0.0 else "no","yes" if cell_s >= 0.0 else "no"]
		out.feet = motor.feet-motif_offset()
		return out
	return await _on_exit(out)

func missed(t: Dictionary) -> Dictionary:
	# Head 2 gone, as its body would take it.
	var heads := motif_heads()
	if heads.size() > 1 and heads[1] != null:
		var h2: Node3D = heads[1]
		var stage: Node3D = study.get("stage")
		stage.enemies.enemies.erase(h2)
		h2.get_parent().remove_child(h2)
		h2.queue_free()
	await place(motif_point(CELL_AT)+t.jitter,Vector2(-1.0,0.0))
	yaw_follows_facing = true
	var cell_y: float = motif_point(CELL_AT).y
	var off := false
	for k in range(300):
		if not motor.grounded and motor.feet.y < cell_y-0.5:
			off = true
			break
		stick(Vector2(0.0,-1.0))
		await frames(1)
	yaw_follows_facing = false
	let_go()
	if not off: return {"ok":false,"why":"never ran off cell 1","feet":motor.feet-motif_offset()}
	var f0 := frame
	var field: Node3D = cannons()
	var fired := -1.0
	var floor_y := motif_floor()-LOST_UNDER
	while frame-f0 < int(MOST*60.0):
		if not (field.spits as Array).is_empty():
			fired = (frame-f0)/60.0
			break
		if motor.feet.y < floor_y: break
		await frames(1)
	var out := {"caught":not (field.catches as Array).is_empty(),"fired_s":snappedf(fired,0.1)}
	if fired < 0.0:
		out.ok = false
		out.why = "the cannon never fired"
		out.feet = motor.feet-motif_offset()
		return out
	return await _on_exit(out)

## At rest on the exit rim?
func _on_exit(out: Dictionary) -> Dictionary:
	var at := await rest(AABB(),20,900)
	var box := motif_box(EXIT,WW.Y_EXIT-1.0,WW.Y_EXIT+1.5)
	out.ok = at != Vector3.INF and box.has_point(at)
	out.rest = at-motif_offset() if at != Vector3.INF else "none"
	if not out.ok: out.why = "not at rest on the exit rim"
	return out
