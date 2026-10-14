extends "res://scripts/kit_isle/motif_greybox.gd"
## The Warden's Well in the generator: studies/greybox/wardens_well.gd's
## LAYOUT (card: docs/design/roguelike/brainstorm/round1/motif-m5-wardens-
## well.md), the same geometry in the same frame, so the head-to-head relay
## keeps the study's numbers: stand on the dais lip, head 1 blasts you north
## down onto cell 1, your skid ends square on head 2's face, head 2 blasts you
## west down onto the exit rim. The study's stand-in exit rim is part of the
## motif here (head 2's blast lands you on it) and the rim out is its far
## (west) edge, where a generated crossing attaches. The flooded entry's
## south edge is the rim in.
##
## One link the study lacked (docs/design/roguelike/cannon-catch.md): a
## catching cannon down in void 2, under cell 1's west edge on head 2's line.
## A missed relay (head 2 asleep, or taken off by its headless body) leaves
## you on cell 1 with no way on; step off its west edge into the cannon's
## mouth and it fires you west onto the exit rim. Head 2's blast flies over
## it going away from its mouth, so it never catches the relay.
const SLAB := 3.0
const Y_DAIS := 0.0
const Y_CELL := -4.0
const Y_EXIT := -11.0
const H1 := Vector3(0.0,Y_DAIS,8.0)
const LIP := 6.0
const H2 := Vector3(4.5,Y_CELL,-14.9)
## The catching cannon: its base on a pier in void 2, under cell 1's west
## edge on head 2's line (z of H2), heading west (PI/2), rest aim (40 deg,
## notch 2). Its mouth is at about (-5.0, -10.4, -14.9), 1.5 m past cell 1's
## edge and 6.4 m under it: a drop from the hang on the edge (x about -3.9,
## measured) comes down 1.1 m from it, a run off the edge (about x -6.4 at
## its height) 1.4 m; its rest shot lands at about x -18.6 on the exit rim
## (Cannon.landing_for), 7.6 m in from its east edge.
const CANNON_AT := Vector3(-3.0,-13.0,-14.9)
const CANNON_HEADING := PI*0.5
## Its funnel widened (the default 2.64 m) so both of those turn in; the
## radius that swallows is the default's.
const CANNON_KNOBS := {"catch_pull":4.0}

## The study's LAYOUT, verbatim but for the exit rim's label (no longer a
## stand-in) and the cannon's pier and notes.
const LAYOUT := {
	"masses": [
		{"name": "hall", "rect": Rect2(-20.0, 1.2, 40.0, 28.8), "top": Y_DAIS-0.4,
		 "tiers": [[Rect2(-12.0, 1.2, 24.0, 12.8), Y_DAIS]],
		 "water": [[Rect2(-20.0, 14.0, 40.0, 16.0), 0.3]],
		 "label": [Vector3(-12.0, 0.6, 20.0), "FLOODED ENTRY (wading) - the hall's drowned floor"]},
		{"name": "cell 1", "rect": Rect2(-3.5, -18.0, 12.0, 11.7), "top": Y_CELL, "tiers": [],
		 "label": [Vector3(5.5, Y_CELL+1.6, -8.0), "CELL 1  (4 m down the well)"]},
		{"name": "plank", "rect": Rect2(8.5, -16.0, 2.5, 2.0), "top": Y_CELL, "tiers": []},
		{"name": "cell 2", "rect": Rect2(11.0, -21.0, 10.0, 10.0), "top": Y_CELL, "tiers": [],
		 "label": [Vector3(16.0, Y_CELL+1.6, -16.0), "CELL 2  (cache; by the plank)"]},
		{"name": "exit rim", "rect": Rect2(-34.0, -34.0, 23.0, 29.0), "top": Y_EXIT, "tiers": [],
		 "label": [Vector3(-20.0, Y_EXIT+1.6, -12.0), "EXIT RIM  (7 m under cell 1; the way on leaves its west edge)"]},
	],
	"pieces": [
		{"kind": "cyl", "name": "column W", "at": Vector2(-3.0, 5.6), "r": 1.0, "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "cyl", "name": "column E", "at": Vector2(3.0, 5.6), "r": 1.0, "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "box", "name": "lip post W", "rect": Rect2(-1.65, 2.6, 0.9, 0.8), "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "box", "name": "exit kerb", "rect": Rect2(-34.0, -5.3, 23.0, 0.3), "bottom": Y_EXIT, "top": Y_EXIT+0.5},
		{"kind": "box", "name": "chest 1", "rect": Rect2(5.5, -8.5, 2.0, 1.2), "bottom": Y_CELL, "top": Y_CELL+1.0},
		{"kind": "box", "name": "chest 2", "rect": Rect2(17.0, -20.6, 2.0, 1.2), "bottom": Y_CELL, "top": Y_CELL+1.0},
	],
	## The catching cannon's pier (grey, not walked: nothing reaches its top).
	"pier": [Rect2(CANNON_AT.x-1.5, CANNON_AT.z-1.5, 3.0, 3.0), CANNON_AT.y-4.0, CANNON_AT.y],
	"heads": [
		{"name": "head 1", "at": H1, "face": Vector2(0.0, -1.0), "knobs": {"size": 3.0}},
		{"name": "head 2 (small)", "at": H2, "face": Vector2(-1.0, 0.0), "knobs": {"size": 2.0}},
	],
	"notes": [
		[H1+Vector3(0.0, 5.0, 0.0), "HEAD 1 - stand on the lip and it blasts you north, down onto cell 1"],
		[H2+Vector3(0.0, 4.0, 0.0), "HEAD 2 (small) - your skid ends on its face; it winds up and blasts you WEST"],
		[Vector3(0.0, 2.0, -2.5), "VOID 1: 7.5 m across, 4 m down to cell 1"],
		[Vector3(-7.0, Y_CELL+2.0, -14.0), "VOID 2: 7.5 m across, 7 m down to the exit rim"],
		[Vector3(-2.2, 3.2, 1.8), "LIP POST: head 1 cannot see you behind it; step out east onto the lip"],
		[H1+Vector3(0.0, 3.0, -LIP), "LIP: on head 1's axis it draws you in and fires you dead north"],
		[CANNON_AT+Vector3(0.0, 4.6, 0.0), "CATCHING CANNON: missed the relay? step off cell 1 here, it fires you onto the exit rim"],
	],
}

func slug() -> String:
	return "wardens_well"

func isle_name() -> String:
	return "The Warden's Well"

func epithet() -> String:
	return "Nobody leaves. They are posted."

func brief() -> String:
	return "The heads are the only way across. Step out from behind the lip post onto the lip and hold still:\nhead 1 spits you down onto cell 1, into head 2's face; hold still again and it spits you west to the exit rim.\nMissed it? Step off cell 1's west edge into the cannon below."

## The study's station 1 (the flooded entry).
func start() -> Vector3:
	return Vector3(-8.0,Y_DAIS-0.4,24.0)

func parts() -> Array:
	var out: Array = []
	for m: Dictionary in LAYOUT.masses:
		out.append(["box",m.rect,float(m.top)-SLAB,m.top,"floor"])
		for t: Array in m.tiers: out.append(["box",t[0],float(m.top)-SLAB,t[1],"grey"])
		for w: Array in m.get("water",[]):
			var r: Rect2 = w[0]
			out.append(["box",r,float(m.top)-SLAB,m.top,"dark"])
			out.append(["water",r,m.top,float(m.top)+float(w[1])])
		if m.has("label"): out.append(["label",m.label[0],m.label[1]])
	for p: Dictionary in LAYOUT.pieces:
		if p.kind == "cyl": out.append(["cyl",p.at,p.r,p.bottom,p.top,"grey"])
		else: out.append(["box",p.rect,p.bottom,p.top,"lip"])
	out.append(["box",LAYOUT.pier[0],LAYOUT.pier[1],LAYOUT.pier[2],"dark"])
	for n: Array in LAYOUT.notes: out.append(["label",n[0],n[1]])
	return out

## In at the flooded entry's south edge (the study's start), out off the
## exit rim's west edge (head 2's blast and the cannon's shot land you on it).
func rims() -> Array:
	return [
		{"name":"entry","at":Vector3(-8.0,Y_DAIS-0.4,29.0),"face":Vector3(0.0,0.0,1.0),"run_up":12.0,"lip":1.0},
		{"name":"exit","at":Vector3(-33.0,Y_EXIT,-19.5),"face":Vector3(-1.0,0.0,0.0),"run_up":15.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"dais","at":Vector3(-7.0,Y_DAIS,8.0),"room":4.0},
		{"kind":"cover","name":"column_w","at":Vector3(-3.0,Y_DAIS,4.2),"room":1.0},
		{"kind":"cover","name":"column_e","at":Vector3(3.0,Y_DAIS,4.2),"room":1.0},
		{"kind":"perch","name":"cell_2","at":Vector3(16.0,Y_CELL,-15.0),"room":3.0},
	]

## Both heads posted on a one-point route (their own spot), as the study.
func heads() -> Array:
	var out: Array = []
	for h: Dictionary in LAYOUT.heads:
		var knobs: Dictionary = (h.knobs as Dictionary).duplicate()
		knobs["route"] = [h.at]
		out.append({"name":h.name,"at":h.at,"face":h.face,"knobs":knobs})
	return out

## The catching cannon in void 2. Added a frame late: the stage makes its
## CannonField after the greybox isles' live bits (layer_stage.gd).
func live(g: Node) -> void:
	var add := func() -> void:
		if is_instance_valid(g) and g.cannons() != null: g.cannons().add_cannon(g.w(CANNON_AT),CANNON_HEADING,CANNON_KNOBS)
	add.call_deferred()
