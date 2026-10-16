extends "res://studies/whole_body_chase.gd"
## The whole body's leap and grab greybox:
## round 1's chase (studies/whole_body_chase.gd) with the body's `leap_grab`
## on (scripts/enemies/headless_body.gd): up on a higher isle it can't walk
## or climb to, with its rim in reach, it crouches and looks up, leaps,
## catches the rim, hangs and swings, then hauls itself over and comes on.
## Floating grey isles over a base isle in open sky (rims and heights in the
## body's head heights, Hh, from its knobs; the walker's start and stations
## in his):
##   base        80 m square, top 0: the body and you start here;
##   far isle    across a gap north, its wall hanging over the drop, top
##               GRAB_IN Hh: in reach, from the base's rim;
##   overhang    over the base's east half, top OVER Hh: it stands under it
##               and grabs its underside's lip;
##   high isle   over the base's west half, top HIGH Hh: just out of reach
##               (it won't try);
##   top tier    north of the overhang, TIER Hh over the overhang's top: the
##               next level up, in reach from the overhang.
## You get up by the station keys (there are no ways up for you):
##   1 start · 2 the far isle · 3 the overhang · 4 the high isle · 5 the top tier
##   B the body back · R start · J its sight · F1 numbers (its grabs, why it
##   won't) · Esc mouse
##   godot --path . res://studies/whole_body_leap_grab.tscn -- --no-title
##     [--body-knob=<knob>=<value>] [--head-knob=<knob>=<value>]
const HeadlessBodyScript = preload("res://scripts/enemies/headless_body.gd")

## Heights over the base in head heights (Hh, the body's `head_size` of the
## walker's heights): in reach, under the overhang, just out of reach
## (over the body's `grab_up`), a tier over the overhang.
const GRAB_IN := 3.6
const OVER := 4.4
const HIGH := 5.1
const TIER := 2.7
## The isles' thickness (Hh).
const THICK := 1.2
const BASE := Rect2(-40.0,-40.0,80.0,80.0)
## Isles: [name, rect (x, z), its top (Hh over the base), on another's top].
const FAR := Rect2(-15.0,-66.0,30.0,22.0)
const OVERHANG := Rect2(8.0,-20.0,26.0,18.0)
const HIGH_ISLE := Rect2(-34.0,-20.0,20.0,16.0)
const TOP_TIER := Rect2(12.0,-40.0,18.0,14.0)
const GRAB_PILOT := Vector3(0.0,0.0,30.0)
const GRAB_BODY := Vector3(0.0,0.0,10.0)

## The body's head height (m), from its knobs and the walker's height.
func hh() -> float:
	var k: Dictionary = {"head_size":3.0}
	k.merge(_body_knobs,true)
	return float(k.head_size)*walker_tall()

## Tops (m) of the far isle, the overhang, the high isle, the top tier.
func tops() -> Dictionary:
	var h := hh()
	return {"far":GRAB_IN*h,"over":OVER*h,"high":HIGH*h,"tier":OVER*h+TIER*h}

func _study_body_knobs() -> Dictionary:
	return {"leap_grab":1}

func _load_pack() -> void:
	body_at = GRAB_BODY
	body_face = Vector2(0.0,-1.0)
	start = GRAB_PILOT
	start_face = Vector2(0.0,-1.0)
	var t := tops()
	var thick := THICK*hh()
	lost = -60.0
	_last_stood = start
	var parts := []
	parts.append(["box",BASE,-10.0,0.0,"floor"])
	parts.append(["label",Vector3(0.0,0.6,BASE.end.y-2.0),"base · 0 m"])
	var isles := [["far isle (in reach)",FAR,float(t.far),"pad"],["overhang (in reach)",OVERHANG,float(t.over),"grey"],
		["high isle (out of reach)",HIGH_ISLE,float(t.high),"wall"],["top tier (in reach from the overhang)",TOP_TIER,float(t.tier),"pad"]]
	for isle: Array in isles:
		var r: Rect2 = isle[1]
		parts.append(["box",r,float(isle[2])-thick,float(isle[2]),isle[3]])
		parts.append(["label",Vector3(r.get_center().x,float(isle[2])+0.8,r.end.y-1.5),"%s · %.1f m" % [isle[0],float(isle[2])]])
	stations = [
		{"key":1,"name":"start","spawn":GRAB_PILOT,"face":start_face,"sign":Vector3(0.0,4.0,36.0),"parts":parts},
		{"key":2,"name":"the far isle","spawn":Vector3(0.0,float(t.far),FAR.end.y-2.0),"face":Vector2(0.0,1.0),"parts":[]},
		{"key":3,"name":"the overhang","spawn":Vector3(OVERHANG.get_center().x,float(t.over),OVERHANG.end.y-2.0),"face":Vector2(0.0,1.0),"parts":[]},
		{"key":4,"name":"the high isle","spawn":Vector3(HIGH_ISLE.get_center().x,float(t.high),HIGH_ISLE.end.y-2.0),"face":Vector2(0.0,1.0),"parts":[]},
		{"key":5,"name":"the top tier","spawn":Vector3(TOP_TIER.get_center().x,float(t.tier),TOP_TIER.end.y-2.0),"face":Vector2(0.0,1.0),"parts":[]},
	]

## A station key: you up there, the body left as it is (R sets both back).
func go_to(key: int) -> void:
	for station: Dictionary in stations:
		if station.key == key:
			if key == 1:
				place(station.spawn,station.face)
				return
			set_walker(station.spawn,station.face)

## You set down at `at` facing `face`, the body and the chase going on.
func set_walker(at: Vector3, face: Vector2) -> void:
	motor.reset(at,PilotMotor.facing_of(face))
	_yaw = motor.facing
	_cam_y = at.y+CAM_HEIGHT*wanderer_scale
	_cam_at = Vector2(at.x,at.z)
	_cam_pace = Vector2.ZERO
	_last_stood = at
	body.settle()

func _beat(what: String) -> void:
	if what == "grab":
		_say("It crouches and looks up: it will leap for the rim!",2.5)
		return
	super._beat(what)

func _hint_text() -> String:
	return "Leap and grab · 2-5 put you up on an isle · J its sight · B body back · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var b := stone_body()
	if b == null: return
	_hud.text += "\ngrab  leaps %d · grabs %d · refused %d · last: %s · reach %.1f m up, %.1f m off" % [b.grab_leaps,b.grabs,b.grab_refusals,b.grab_why if b.grab_why != "" else "-",
		float(b.knobs.grab_up)*b.hh,float(b.knobs.grab_out)*b.hh]
