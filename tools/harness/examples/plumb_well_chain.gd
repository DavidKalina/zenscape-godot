extends "res://tools/harness/chain.gd"
## The Plumb Well's chains (scripts/kit_isle/greybox/gb_plumb_well.gd), on
## the chain helper (tools/harness/chain.gd): the example to copy.
##
##   --chain=column (default): the whole column. From 2.6 m south of oculus
##     1 on the cap (the study's combo 1 start), run north (full stick) till he
##     drops in, pull back (south) till he is down on the leaf, then let go
##     (the motif's brief; a walk-off catches the lip as a ledge and hangs
##     there): the leaf throws him into the
##     plumb wall and down the slot, the seesaw's block flings him down
##     oculus 3, the slabs go, the head at the foot gulps and blasts him
##     south, the catching cannon on the terrace fires him east, and he
##     comes to rest on the landing. Passed: at rest on the landing.
##   --chain=cannon: the Olmec cannon alone. In the head's face at the foot
##     (the study's combo 3 start), no input: gulped, blasted into the
##     cannon, fired onto the landing.
##
##   python tools/drive.py tools/harness/examples/plumb_well_chain.gd -- --trials=10 --scene-args --motif=plumb_well --bodies=0 [--grey]
const PW = preload("res://scripts/kit_isle/greybox/gb_plumb_well.gd")

## The column's start (the study's station 6), his run's stick and how
## long at most he pulls back in the air (s): the motif's brief, "run off
## the cap into the oculus by the wall, pull back onto the leaf".
const COLUMN_AT := Vector3(0.0,PW.FOOT_DROP+3.0*PW.H,5.5)
const RUN_STICK := 1.0
const PULL := 1.0
## The cannon chain's start (the study's station 8).
const CANNON_START := Vector3(-2.4,0.0,1.5)
## The most a trial may take (s of game time) before the cannon fires.
const MOST := 40.0

func drive() -> void:
	if not await open_motif("plumb_well"): return
	var which := str(arg("chain","column"))
	result("chain",which)
	await trials(arg_int("trials",10),column if which == "column" else cannon_chain,arg_float("jitter",0.5))

func column(t: Dictionary) -> Dictionary:
	await place(motif_point(COLUMN_AT)+t.jitter,Vector2(0.0,1.0))
	# His forward is north: run till he's off the cap and falling.
	yaw_follows_facing = true
	var cap_y: float = motif_point(COLUMN_AT).y
	var off := false
	for k in range(300):
		if not motor.grounded and motor.feet.y < cap_y-0.3:
			off = true
			break
		stick(Vector2(0.0,-arg_float("stick",RUN_STICK)))
		await frames(1)
	yaw_follows_facing = false
	if not off:
		let_go()
		return {"ok":false,"why":"never dropped into oculus 1","feet":motor.feet}
	# Pulled back (south) in the air till he's down on the leaf (or past it).
	var leaf_y: float = motif_point(Vector3(0.0,PW.FOOT_DROP+2.0*PW.H,0.0)).y
	var pulled := 0
	while pulled < int(arg_float("pull",PULL)*60.0) and not motor.grounded and motor.feet.y > leaf_y-1.0:
		stick(stick_toward(motor.feet+Vector3(0.0,0.0,-4.0)))
		await frames(1)
		pulled += 1
	let_go()
	var out: Dictionary = await _ride_down()
	out.pulled_s = snappedf(pulled/60.0,0.01)
	return out

func cannon_chain(t: Dictionary) -> Dictionary:
	await place(motif_point(CANNON_START)+t.jitter,Vector2(0.0,1.0))
	return await _ride_down()

## No input from here: the links watched (the plates he passed, the head's
## gulp, the cannon's catch and shot), then he must rest on the landing.
func _ride_down() -> Dictionary:
	var f0 := frame
	var low: float = motor.feet.y
	var gulp_s := -1.0
	var caught_s := -1.0
	var fired_s := -1.0
	var field: Node3D = cannons()
	var floor_y := motif_floor()-LOST_UNDER
	# Where he came down, in order (the plates' tops: 26 the leaf, 17 the
	# seesaw, 8 the slabs, 0 the foot, -6 the terrace).
	var touched: Array = []
	var was_down := true
	while frame-f0 < int(MOST*60.0):
		low = minf(low,motor.feet.y)
		var down: bool = motor.grounded
		if down and not was_down:
			var level := roundi(motor.feet.y-motif_offset().y)
			if touched.is_empty() or int(touched[touched.size()-1]) != level: touched.append(level)
		was_down = down
		if gulp_s < 0.0:
			for h: Variant in motif_heads():
				if h != null and bool(h.swallowed): gulp_s = (frame-f0)/60.0
		if caught_s < 0.0 and field != null and not (field.catches as Array).is_empty(): caught_s = (frame-f0)/60.0
		if fired_s < 0.0 and field != null and not (field.spits as Array).is_empty():
			fired_s = (frame-f0)/60.0
			break
		if motor.feet.y < floor_y: break
		await frames(1)
	var out := {"touched":touched,"low":snappedf(low-motif_offset().y,0.1),"gulp_s":snappedf(gulp_s,0.1),"caught_s":snappedf(caught_s,0.1),"fired_s":snappedf(fired_s,0.1)}
	if fired_s < 0.0:
		out.ok = false
		out.why = "the cannon never fired (lowest %.1f m, gulped %s)" % [low-motif_offset().y,"yes" if gulp_s >= 0.0 else "no"]
		out.feet = motor.feet-motif_offset()
		return out
	var landing := motif_box(PW.LANDING,PW.LANDING_Y-1.0,PW.LANDING_Y+1.5)
	var at := await rest(AABB(),20,900)
	out.ok = at != Vector3.INF and landing.has_point(at)
	out.rest = at-motif_offset() if at != Vector3.INF else "none"
	if not out.ok: out.why = "fired, but not at rest on the landing"
	return out
