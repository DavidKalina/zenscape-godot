extends SceneTree
## The ruins archipelago (studies/island_packs/ruins_archipelago.gd),
## headless: a route through each station driven end to end with scripted
## inputs, as a player would, checking he arrives where the station says he
## can; the expert lines where they can be driven. With `-- --save` each
## route is saved as a recording (studies/character_runs/), so the study's
## F6 shows it and tests/test_character_recordings.gd keeps it possible.
##   godot --headless --path . --script tests/test_island_pack_ruins_archipelago.gd [-- --save]
const Recording = preload("res://scripts/character_recording.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PACK := "ruins_archipelago"
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var save := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("ruins archipelago test timed out"); quit(2))
	save = "--save" in OS.get_cmdline_user_args()
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	study.pack = PACK
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	check(study.stations.size() >= 6,"The pack builds %d stations" % study.stations.size())
	_temple_easy()
	_temple_chain()
	_aqueduct_easy()
	_aqueduct_wallrun()
	_tower_easy()
	_tower_crack()
	_tower_shaft()
	_court_easy()
	_court_slab()
	_bridge_easy()
	_bridge_chain()
	_bridge_chain(6)
	_arch_easy()
	_arch_impost()
	_colonnade_easy()
	_colonnade_wallrun()
	_colonnade_twirl()
	print("PASS: ruins archipelago" if failures == 0 else "FAIL: ruins archipelago (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving ------------------------------------------------------------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

## Set down at station `key`, stood still a moment; recording from here
## when saving.
func begin(key: int) -> void:
	study.go_to(key)
	for i in range(10): tick(Vector2.ZERO)
	if save: study._rec = Recording.new(m,key,study._feel_now(),PACK)

## The route done: stood a moment, then saved under `label` if it held.
func finish(label: String, ok: bool) -> void:
	for i in range(20): tick(Vector2.ZERO)
	var rec: RefCounted = study._rec
	study._rec = null
	if save and ok and rec != null:
		rec.label = label
		rec.save()

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

## The ground's top a little ahead along `way`.
func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

## Walks (or runs, `pace` of the stick) through the points (x, z) in turn,
## jumping where the ground ahead rises past a step and climbing what he
## catches; true once stood within 0.4 m of the last.
func walk(points: Array, pace := 1.0, frames := 1500) -> bool:
	var i := 0
	var holding := 0
	for f in range(frames):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		var last := i == points.size()-1
		if off.length() < (0.4 if last else 0.6) and (not last or (m.grounded and not m.on_ledge())):
			i += 1
			if i >= points.size(): return true
			continue
		var way := off.normalized()
		var jump := false
		if m.grounded and holding == 0 and ahead(way) > m.feet.y+0.45: holding = 14
		if holding > 0:
			jump = true
			holding -= 1
		tick(way*pace,jump)
	return false

## Runs towards `to` (x, z) and jumps at the edge of what he stands on
## (at once if `now`), held to its top, a caught lip climbed; true stood
## again.
func hop(to: Vector2, now := false, frames := 240) -> bool:
	var jumped := false
	for i in range(frames):
		var way: Vector2 = (to-flat(m.feet)).normalized()
		var jump: bool = not jumped and m.grounded and (now or ahead(way,0.35) < m.feet.y-0.45)
		jump = jump or (jumped and not m.grounded and m.velocity.y > 0.0) or (m.on_ledge() and i%20 < 3)
		jumped = jumped or jump
		tick(way,jump)
		if jumped and i > 3 and m.grounded and not m.on_ledge(): return true
	return false

## Runs `way` a moment, throws the stick back and jumps in the skid: the
## side flip, back the way he came; a caught lip climbed. True stood again.
func side_flip(way: Vector2, run := 18) -> bool:
	var flipped := false
	for i in range(240):
		var back := i >= run
		var jump: bool = back and m.skidding and not flipped
		if flipped and m.on_ledge(): jump = i%20 < 3
		tick(-way if back else way,jump)
		flipped = flipped or m.move == "flip"
		if flipped and m.grounded and not m.on_ledge(): return true
	return false

# --- 1 The temple avenue ------------------------------------------------------------

## Easy: walk the avenue between its columns, up the temple's steps, onto
## the cella wall's 1.2 m stump, and along its broken top, step by step, to
## its 4.8 m end.
func _temple_easy() -> void:
	begin(1)
	var ok := walk([Vector2(0.0,-34.5),Vector2(-8.0,-36.8),Vector2(-8.0,-38.2),Vector2(9.5,-38.2)],0.6)
	check(ok and absf(m.feet.y-36.15) < 0.05,"1 Temple: walked the avenue, up the steps and the broken wall to its 4.8 m top (feet %s)" % m.feet)
	finish("ruins 1: avenue, temple steps, broken wall to its 4.8 m top (easy)",ok)

## Expert: a running long jump down the avenue, chained on every landing
## and weaving between its columns, onto the temple floor.
func _temple_chain() -> void:
	begin(1)
	var way := Vector2(0.0,-1.0)
	var hops := 0
	var was_ground := true
	var widest := 0.0
	for i in range(400):
		var weave := 0.0 if hops < 2 else (0.35 if hops%2 == 0 else -0.35)
		var crouch := i > 20 and m.feet.z > -32.0
		var jump := crouch and m.grounded and i > 22
		tick(way.rotated(weave),jump,crouch)
		if was_ground and not m.grounded: hops += 1
		was_ground = m.grounded
		widest = maxf(widest,absf(m.feet.x))
		if m.feet.z < -34.0 and m.grounded: break
	var ok: bool = m.grounded and absf(m.feet.y-31.35) < 0.05 and study.long_chain_top >= 11.0 and widest < 2.4
	check(ok,"1 Temple: long jumps chained down the avenue (%d hops, to %.1f m/s, at most %.2f m off its middle) onto the temple floor (feet %s)" % [hops,study.long_chain_top,widest,m.feet])
	finish("ruins 1: long jump chain down the avenue onto the temple (expert)",ok)

# --- 2 The aqueduct -----------------------------------------------------------------

## Easy: up the rubble slope onto the blind wall, along the channel, a
## running jump twirled over the fallen span, on across the sky to the far
## island and down its rubble.
func _aqueduct_easy() -> void:
	begin(2)
	var ok := walk([Vector2(100.0,8.0),Vector2(100.0,-31.0)])
	var way := Vector2(0.0,-1.0)
	var twirled := false
	for i in range(240):
		var jump: bool = m.feet.z < -32.1 and (m.grounded or m.velocity.y > 0.0) and not twirled
		var twirl: bool = not m.grounded and m.velocity.y < 0.0 and not twirled and m.feet.z < -32.0
		twirled = twirled or twirl
		tick(way,jump,false,twirl)
		if twirled and m.grounded: break
	ok = ok and twirled and m.grounded and m.feet.z < -35.5 and absf(m.feet.y-36.0) < 0.05
	check(ok,"2 Aqueduct: up the rubble and along the channel, a twirled running jump over the 3 m fallen span (feet %s)" % m.feet)
	ok = ok and walk([Vector2(100.0,-44.0),Vector2(100.0,-58.0)])
	check(ok and absf(m.feet.y-30.0) < 0.05,"2 Aqueduct: on across the sky and down the rubble to the far island (feet %s)" % m.feet)
	finish("ruins 2: rubble up, along the aqueduct, twirl over the fallen span (easy)",ok)

## Expert: a running jump along the blind wall's east face into a wall
## run, kicked off it to the buttress, then kicks between the two up to the
## channel's top.
func _aqueduct_wallrun() -> void:
	begin(2)
	var ok := walk([Vector2(103.5,8.0),Vector2(102.1,7.0)],0.4)
	for i in range(10): tick(Vector2.ZERO)
	var ran := false
	var kicks := 0
	var on := 0
	var side := Vector2(1.0,0.0)
	var was := ""
	for i in range(900):
		on = on+1 if m.move == "wall" else 0
		var want := Vector2(0.0,-1.0)
		var jump := false
		if m.feet.z < -0.6 and not ran and (m.grounded or m.velocity.y > 0.0): jump = true
		if m.feet.z < -0.4 and not ran: want = Vector2(-0.25,-1.0).normalized()
		if m.move == "wallrun":
			ran = true
			jump = m.feet.z < -5.5
		elif ran:
			want = side
			if m.move == "wall": jump = on >= 3
		if m.move == "kick" and was != "kick":
			kicks += 1
			if kicks > 1: side = -side
		was = m.move
		tick(want,jump)
		if ran and m.grounded: break
	ok = ok and ran and m.grounded and m.feet.y > 35.0
	check(ok,"2 Aqueduct: a wall run along the blind wall, kicked to the buttress and up between them to the top (%d kicks, feet %s)" % [kicks,m.feet])
	finish("ruins 2: wall run along the blind wall, kicks up to the channel (expert)",ok)

## Kicks up between two walls facing each other: the stick into `side`
## first, swapped at each kick, Jump a few frames after taking hold of a
## wall; a lip caught is climbed. A kick off a wall over `back_over`
## keeps the stick back towards it and twirls at the top, turning him back
## to it (to a ledge over it, or one more kick). Stops stood on ground over
## `over`; the kicks taken.
func kick_up(side: Vector2, over: float, back_over := INF, frames := 600) -> int:
	var on := 0
	var kicks := 0
	var was := ""
	var back := false
	var twirled := false
	for i in range(frames):
		on = on+1 if m.move == "wall" else 0
		var jump: bool = (m.grounded and i < 3) or (not m.grounded and m.move != "wall" and m.velocity.y > 0.0 and kicks == 0) or on >= 3
		if m.on_ledge(): jump = i%20 < 3
		var twirl := back and not twirled and m.velocity.y < 1.0
		twirled = twirled or twirl
		tick(side,jump,false,twirl)
		if m.move == "kick" and was != "kick":
			kicks += 1
			if m.feet.y > back_over and not back: back = true
			else: side = -side
		was = m.move
		if m.grounded and m.feet.y > over and not m.on_ledge(): break
	return kicks

# --- 3 The cracked watchtower -------------------------------------------------------

## Easy: up the fallen blocks east of the tower, 1.2 m a step, onto the
## south wall's top over the door.
func _tower_easy() -> void:
	begin(3)
	var ok := walk([Vector2(211.5,-11.4),Vector2(200.0,-11.3)],0.6)
	check(ok and absf(m.feet.y-36.0) < 0.05,"3 Tower: up the fallen blocks onto the 6 m south wall (feet %s)" % m.feet)
	finish("ruins 3: fallen blocks up to the tower's south wall (easy)",ok)

## Expert: into the crack, kicked up it between the split slab and the
## tower, the last kick (off the tower, over the slab's top) twirled back to
## the tower's 7 m window sill.
func _tower_crack() -> void:
	begin(3)
	var ok := walk([Vector2(196.6,-4.0),Vector2(196.6,-15.6),Vector2(200.0,-15.6)],0.4)
	var kicks := kick_up(Vector2(0.0,-1.0),36.5,34.5)
	ok = ok and absf(m.feet.y-37.0) < 0.05
	check(ok,"3 Tower: kicked up the 1.0 m crack and twirled back to the 7 m window sill (%d kicks, feet %s)" % [kicks,m.feet])
	finish("ruins 3: up the crack, kicks, twirl back to the 7 m window sill (expert)",ok)

## Expert: in at the door and kicked up the 2.6 m shaft to the crown.
func _tower_shaft() -> void:
	begin(3)
	var ok := walk([Vector2(204.0,-6.0),Vector2(200.0,-8.5),Vector2(200.0,-13.0),Vector2(201.0,-13.0)],0.4)
	for i in range(20): tick(Vector2.ZERO)
	for i in range(12): tick(Vector2(-1.0,0.0))
	var kicks := kick_up(Vector2(-1.0,0.0),38.5)
	ok = ok and m.feet.y > 38.7
	check(ok,"3 Tower: in at the door, kicked up the 2.6 m shaft to the crown (%d kicks, feet %s)" % [kicks,m.feet])
	finish("ruins 3: in at the door, kicks up the shaft to the crown (expert)",ok)

# --- 4 The sunken court -------------------------------------------------------------

## Easy: round the rim, down the steps into the court, across it past the
## pool, up onto the altar and from it up onto the east rim.
func _court_easy() -> void:
	begin(4)
	var ok := walk([Vector2(290.0,-27.0),Vector2(290.0,-6.0),Vector2(292.8,-7.0),Vector2(292.8,-14.0),Vector2(304.0,-11.0),Vector2(304.0,-16.0)],0.6)
	var down := absf(m.feet.y-27.2) < 0.05
	ok = ok and walk([Vector2(305.6,-16.0),Vector2(305.4,-16.0)],0.6) and absf(m.feet.y-28.6) < 0.05
	ok = ok and down and hop(Vector2(309.0,-16.0)) and absf(m.feet.y-30.0) < 0.1
	check(ok,"4 Court: down the steps, across the court, onto the altar and out onto the rim (feet %s)" % m.feet)
	finish("ruins 4: steps down, the altar, out onto the rim (easy)",ok)

## Expert: a run off the north rim onto the fallen slab, crouched to surf
## it, a long jump off its foot over the pool (twirled at its top) onto
## the far floor; then a side flip up the 2.8 m south wall onto the rim.
func _court_slab() -> void:
	begin(4)
	var way := Vector2(0.0,1.0)
	var jumped := false
	var twirled := false
	var top := 0.0
	for i in range(300):
		var crouch: bool = m.feet.z > -24.2 and not jumped
		var jump: bool = crouch and m.feet.z > -19.8 and m.grounded
		var twirl: bool = jumped and not twirled and not m.grounded and m.velocity.y < 0.0
		if m.move == "slide": top = maxf(top,m.speed())
		jumped = jumped or jump
		twirled = twirled or twirl
		tick(way,jump,crouch,twirl)
		if jumped and i > 0 and m.grounded and not jump: break
	var dry: bool = absf(m.feet.y-27.2) < 0.05 and m.feet.z > -13.0 and twirled and study.last_jump.get("kind","") == "long"
	check(dry,"4 Court: surfed the slab (to %.1f m/s), long jump over the 6 m pool landing dry (%s, feet %s)" % [top,study.last_jump,m.feet])
	for i in range(40): tick(Vector2.ZERO)
	var ok := dry and walk([Vector2(304.0,-9.0)],0.4)
	for i in range(20): tick(Vector2.ZERO)
	ok = ok and side_flip(Vector2(0.0,-1.0)) and absf(m.feet.y-30.02) < 0.1
	check(ok,"4 Court: a side flip up the 2.8 m wall onto the rim (%s, feet %s)" % [study.last_flip,m.feet])
	finish("ruins 4: surf the slab, long jump over the pool, side flip out (expert)",ok)

# --- 5 The fallen bridge ------------------------------------------------------------

## Easy: running jumps from slab to slab along the east line, 1.6 m gaps,
## stepping up and down 0.4 m, onto the far island and through its gate.
func _bridge_easy() -> void:
	begin(5)
	var ok := walk([Vector2(405.0,-2.0)],0.6)
	var slabs := [-7.1,-11.7,-16.3,-20.9,-25.5,-31.0,-37.0]
	for z: float in slabs: ok = ok and hop(Vector2(405.0,z))
	ok = ok and walk([Vector2(400.0,-38.4),Vector2(398.0,-44.0)],0.6)
	check(ok and absf(m.feet.y-30.0) < 0.05,"5 Bridge: running jumps along the east slabs to the far island and through its gate (feet %s)" % m.feet)
	finish("ruins 5: running jumps along the fallen bridge's slabs (easy)",ok)

## Expert: a running long jump off the near island along the west piers'
## caps, chained on every landing, the last hop (5.1 m to the far island)
## twirled at its top. With `late` each hop is pressed that many frames
## after its landing, still in the chain's 0.2 s: the slide runs on further
## along each cap first, and the caps are long enough for it up to 0.1 s.
func _bridge_chain(late := 0) -> void:
	begin(5)
	var ok := walk([Vector2(395.0,4.5)],0.4)
	for i in range(20): tick(Vector2.ZERO)
	var way := Vector2(0.0,-1.0)
	var hops := 0
	var was_ground := true
	var twirled := false
	var started := false
	var from_z := 0.0
	var down := 0
	for i in range(500):
		down = down+1 if m.grounded else 0
		var crouch := m.feet.z < -2.8 or started
		var jump := false
		if crouch and m.grounded:
			jump = (started and down > late) or (not started and ahead(way,0.35) < m.feet.y-0.45)
		var twirl: bool = not twirled and not m.grounded and from_z < -24.9 and m.velocity.y < 0.0
		started = started or jump
		twirled = twirled or twirl
		tick(way,jump,crouch and m.feet.z > -35.4,twirl)
		if was_ground and not m.grounded:
			hops += 1
			from_z = m.feet.z
		was_ground = m.grounded
		if m.feet.z < -35.9 and m.grounded: break
	ok = ok and m.grounded and absf(m.feet.y-30.0) < 0.05 and m.feet.z < -34.9 and hops == 5
	if late == 0:
		check(ok,"5 Bridge: a long jump chain along the west piers' caps (%d hops, to %.1f m/s), the 5.1 m to the far island twirled (feet %s)" % [hops,study.long_chain_top,m.feet])
		finish("ruins 5: long jump chain along the bridge's piers, twirl over the last 5.1 m (expert)",ok)
	else:
		check(ok,"5 Bridge: the same chain pressed %.2f s after each landing (%d hops, %d chained), still across (feet %s)" % [late*DT,hops,study.long_chain,m.feet])
		finish("ruins 5: the bridge's long jump chain pressed 0.1 s late (expert)",ok)

# --- 6 The arch and the stair to nowhere --------------------------------------------

## Easy: up the stair to nowhere and from its top a jump across the 1.6 m
## it falls short, caught on the attic's edge and climbed.
func _arch_easy() -> void:
	begin(6)
	var ok := walk([Vector2(486.0,-10.0),Vector2(480.0,-20.5),Vector2(491.0,-20.5)],0.6)
	ok = ok and hop(Vector2(496.0,-20.5)) and absf(m.feet.y-37.0) < 0.05
	check(ok,"6 Arch: up the stair to nowhere, across its 1.6 m gap onto the 7 m attic (feet %s)" % m.feet)
	finish("ruins 6: up the stair to nowhere, jump to the arch's attic (easy)",ok)

## Expert: a side flip onto the fallen block, from it a jump into the east
## pier and a kick off it, the stick held back and a twirl turning him back
## to the pier, onto its 5.4 m impost; from the impost up to the attic.
func _arch_impost() -> void:
	begin(6)
	var ok := walk([Vector2(507.0,-12.0),Vector2(508.0,-20.5)],0.4)
	for i in range(20): tick(Vector2.ZERO)
	ok = ok and side_flip(Vector2(1.0,0.0)) and absf(m.feet.y-32.6) < 0.05
	check(ok,"6 Arch: a side flip onto the 2.6 m fallen block (%s, feet %s)" % [study.last_flip,m.feet])
	for i in range(20): tick(Vector2.ZERO)
	ok = ok and walk([Vector2(507.4,-20.5)],0.3)
	for i in range(20): tick(Vector2.ZERO)
	var on := 0
	var kicked := false
	var twirled := false
	var jumped := false
	for i in range(300):
		on = on+1 if m.move == "wall" else 0
		var jump: bool = not jumped and m.grounded and ahead(Vector2(-1.0,0.0),0.35) < m.feet.y-0.45
		jumped = jumped or jump
		jump = jump or (jumped and not kicked and m.move != "wall" and m.velocity.y > 0.0) or (not kicked and on >= 3)
		if m.on_ledge(): jump = i%20 < 3
		var twirl: bool = kicked and not twirled and m.velocity.y < 1.0 and not m.on_ledge()
		twirled = twirled or twirl
		tick(Vector2(-1.0,0.0),jump,false,twirl)
		kicked = kicked or m.move == "kick"
		if kicked and m.grounded and not m.on_ledge(): break
	var on_impost := absf(m.feet.y-35.4) < 0.05
	check(ok and kicked and twirled and on_impost,"6 Arch: off the block into the pier, a kick and a twirl back onto its 5.4 m impost (feet %s)" % m.feet)
	for i in range(20): tick(Vector2.ZERO)
	ok = ok and on_impost and hop(Vector2(500.0,-20.5),true) and absf(m.feet.y-37.0) < 0.05
	check(ok,"6 Arch: from the impost up onto the attic (feet %s)" % m.feet)
	finish("ruins 6: side flip, kick, twirl back to the impost, up to the attic (expert)",ok)

# --- 7 The fallen colonnade ---------------------------------------------------------

## Easy: along the whole column over the chasm to the far island, and up
## the 20° roof slab onto the pediment wall.
func _colonnade_easy() -> void:
	begin(7)
	var ok := walk([Vector2(608.7,-5.0),Vector2(605.3,-32.0),Vector2(591.5,-34.0),Vector2(591.5,-47.4)],0.6)
	check(ok and absf(m.feet.y-34.0) < 0.05,"7 Colonnade: along the fallen column over the chasm, up the 20° slab onto the 4 m pediment (feet %s)" % m.feet)
	finish("ruins 7: walk the fallen column, up the roof slab to the pediment (easy)",ok)

## Expert: a run along the broken column, a long jump off its end to the
## wall beside the break (a run's pace takes a wall run only 3.4 m; the
## long jump's 7.6 m/s takes it 5 m), a wall run along it across the break
## and a kick back off it onto the far half, then up onto the far island.
func _colonnade_wallrun() -> void:
	begin(7)
	var ok := walk([Vector2(594.9,-4.0)],0.4)
	for i in range(20): tick(Vector2.ZERO)
	var ran := false
	var jumped := false
	for i in range(300):
		var want := Vector2(0.0,-1.0)
		var crouch: bool = not jumped and m.feet.z < -12.8
		var jump: bool = crouch and m.grounded and m.feet.z < -13.6
		jumped = jumped or jump
		if jumped and not ran: want = Vector2(0.3,-1.0).normalized()
		if m.move == "wallrun":
			ran = true
			jump = m.feet.z < -18.6
		tick(want,jump,crouch)
		if ran and m.grounded: break
	var across := m.grounded and m.feet.z < -21.0 and absf(m.feet.y-29.0) < 0.05
	check(ok and ran and across,"7 Colonnade: a wall run along the fragment across the 6 m break, kicked back onto the far half (feet %s)" % m.feet)
	ok = ok and across and walk([Vector2(594.0,-33.0)],0.6) and absf(m.feet.y-30.0) < 0.05
	check(ok,"7 Colonnade: on up onto the far island (feet %s)" % m.feet)
	finish("ruins 7: wall run across the broken column's 6 m break (expert)",ok)

## Expert too: the same break taken by a running long jump off the
## column's end, twirled at its top.
func _colonnade_twirl() -> void:
	begin(7)
	var ok := walk([Vector2(593.6,-4.0)],0.4)
	for i in range(20): tick(Vector2.ZERO)
	var jumped := false
	var twirled := false
	for i in range(300):
		var crouch: bool = m.feet.z < -13.9 and not jumped
		var jump: bool = crouch and m.grounded and ahead(Vector2(0.0,-1.0),0.35) < m.feet.y-0.45
		var twirl: bool = jumped and not twirled and not m.grounded and m.velocity.y < 0.0
		jumped = jumped or jump
		twirled = twirled or twirl
		tick(Vector2(0.0,-1.0),jump,crouch,twirl)
		if jumped and not jump and m.grounded: break
	ok = ok and twirled and m.feet.z < -21.0 and absf(m.feet.y-29.0) < 0.05
	check(ok,"7 Colonnade: a twirled long jump over the 6 m break (%s, feet %s)" % [study.last_jump,m.feet])
	finish("ruins 7: twirled long jump over the broken column's break (expert)",ok)
