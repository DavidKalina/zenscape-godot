extends "res://studies/character_study.gd"
## The snag study (docs/design/snag/round1.md): one of the ways a part of
## the wanderer's broken plane is found on foot. A sky-folk pilot flies a
## fixed low loop (scripts/snag_plane.gd) with the part, a rune token
## standing in for it, slung on a rope under the plane. Watch a pass, get
## to where the plane dips low, and time a jump, a long jump or an updraft
## to touch the swinging load: it tears off the rope, the plane lurches and
## its pilot looks back, and the part falls with the wanderer ("Got it").
## A new one hangs on the rope a few seconds on.
##
## The pilot is the character study's (this extends it): the same motor,
## figure, camera, updraft, F1 numbers and F2 feel. The ground is a
## greybox: a floor, and over the loop
##   1  the start, a ramp up to
##   2  the pier: the load passes a jump over its top (the easy one)
##   3  the perch, high off the dip's way out: the load swings past a
##      few metres off its lip, a running long jump (or a twirl) out to it
##   4  the terrace under the loop's far side, where the plane passes
##      higher: slide down its ramp and long-jump along it to build a
##      flow charge, and updraft (Q / RB) into the load as it comes over
## The stations are laid against the loop at its default tunables, so the
## flags below make them harder or easier.
## Tunables: --snag-lap=<s> (a lap, 26), --snag-rope=<m> (6),
## --snag-dip=<m> (the belly's height over the pier at the dip, 9.5: the load a jump over its top).
##   ./run-snag-study.command [--snag-lap=20]
##   godot --path . res://studies/snag_study.tscn -- --no-title
const SnagPlane = preload("res://scripts/snag_plane.gd")
const MomentsHud = preload("res://scripts/moments_hud.gd")

## The pier's top, where the plane dips (it passes heading +x).
const LEDGE := Vector3(0.0,10.0,36.0)
## The perch: where round the lap (rad) it stands, how far its lip is off
## the line (m), how far under the resting load its top is (m).
const PERCH_AT := 0.32
const PERCH_OFF := 2.8
const PERCH_UNDER := 1.9
## The terrace under the far side: how far under the resting load (m).
const TERRACE_UNDER := 8.0
## The wanderer's body as a grab reaches: from the feet up to here (m),
## and how near the load must come to it (m).
const BODY := Vector2(0.2,1.7)
const GRAB := 1.05
## The yank of a grab in the air: this share of the plane's flat pace.
const TUG := 0.3
## A part he holds is carried overhead this high (m) till he lands (and at
## least CARRY_LEAST s, at most CARRY_MOST), then taken.
const CARRY_HIGH := 2.0
const CARRY_LEAST := 0.4
const CARRY_MOST := 3.0
const LOST_Y := -10.0

var snag: Node3D
var moments: CanvasLayer
var lap := SnagPlane.LAP
var rope := SnagPlane.ROPE
var dip := SnagPlane.DIP
## The part he carries, and how long he has.
var carried: Node3D
var _carry_t := 0.0
var got := 0
var _shown_pass := -1

func _ready() -> void:
	pack = "snag_study"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--snag-lap="): lap = float(arg.get_slice("=",1))
		elif arg.begins_with("--snag-rope="): rope = float(arg.get_slice("=",1))
		elif arg.begins_with("--snag-dip="): dip = float(arg.get_slice("=",1))
	super._ready()

## The study's stations, laid against the loop at its defaults.
func _load_pack() -> void:
	stations = snag_stations()
	start = stations[0].spawn
	start_face = stations[0].face
	lost = LOST_Y
	_last_stood = start

static func snag_stations() -> Array:
	var hang := SnagPlane.ROPE+SnagPlane.LOAD_SIZE*SnagPlane.HANG
	var p := SnagPlane.path_point(PERCH_AT,LEDGE,SnagPlane.DIP)
	var perch_top := p.y-hang-PERCH_UNDER
	var far := SnagPlane.path_point(PI,LEDGE,SnagPlane.DIP)
	var terrace := far.y-hang-TERRACE_UNDER
	return [
		{"key":1,"name":"Start","spawn":Vector3(0.0,0.0,72.0),"face":Vector2(0.0,-1.0),"sign":Vector3(4.0,3.0,70.0),"parts":[
			["ramp",Vector3(0.0,0.0,66.0),Vector3(0.0,LEDGE.y,LEDGE.z+2.5),3.0,"grey"],
		]},
		{"key":2,"name":"Pier","spawn":LEDGE+Vector3(0.0,0.0,1.5),"face":Vector2(-1.0,0.0),"sign":LEDGE+Vector3(0.0,3.5,2.4),"parts":[
			["box",Rect2(LEDGE.x-2.5,LEDGE.z-2.5,5.0,5.0),-1.0,LEDGE.y,"lip"],
		]},
		{"key":3,"name":"Perch (long jump)","spawn":Vector3(p.x,perch_top,p.z+PERCH_OFF+3.5),"face":Vector2(0.0,-1.0),"sign":Vector3(p.x,perch_top+3.5,p.z+PERCH_OFF+4.5),"parts":[
			["box",Rect2(p.x-3.0,p.z+PERCH_OFF,6.0,5.0),perch_top-1.0,perch_top,"lip"],
		]},
		{"key":4,"name":"Terrace (updraft)","spawn":Vector3(-42.0,terrace+5.5,far.z),"face":Vector2(1.0,0.0),"sign":Vector3(-42.0,terrace+9.0,far.z+3.0),"parts":[
			["box",Rect2(-44.0,far.z-4.0,4.0,8.0),terrace+4.5,terrace+5.5,"grey"],
			["ramp",Vector3(-24.0,terrace,far.z),Vector3(-40.0,terrace+5.5,far.z),8.0,"grey"],
			["box",Rect2(-24.0,far.z-4.0,48.0,8.0),terrace-1.0,terrace,"pad"],
		]},
	]

## The floor under it all, the stations, then the plane on its loop (its
## first pass over the pier a few seconds in).
func _build_room() -> void:
	_box(Rect2(-80.0,-55.0,160.0,140.0),-1.0,0.0,"floor")
	super._build_room()
	snag = SnagPlane.new()
	snag.setup(lap,rope,dip,LEDGE,lap*0.6)
	add_child(snag)
	moments = MomentsHud.new()
	add_child(moments)

## A frame: the pilot, then the grab and the part he carries.
func tick(delta: float) -> void:
	super.tick(delta)
	if snag == null: return
	if snag.attached and snag.load_token != null and touching(snag.load_point()): grab()
	_carry(delta)
	var pass_in := int(ceil(snag.till_pass()))
	if pass_in != _shown_pass and moments != null:
		_shown_pass = pass_in
		moments.status("over the pier in %d s" % pass_in)

## Whether the load at `at` is within reach of his body.
func touching(at: Vector3) -> bool:
	var near := Geometry3D.get_closest_point_to_segment(at,motor.feet+Vector3.UP*BODY.x,motor.feet+Vector3.UP*BODY.y)
	return near.distance_to(at) <= GRAB

## The grab: the load off the rope and into his hands; in the air the
## plane's pace yanks him along a little.
func grab() -> void:
	var token: Node3D = snag.snatch()
	if token == null: return
	if carried != null and is_instance_valid(carried): carried.queue_free()
	token.reparent(self)
	carried = token
	_carry_t = 0.0
	got += 1
	if not motor.grounded:
		var v: Vector3 = snag.flight.velocity
		motor.velocity += Vector3(v.x,0.0,v.z)*TUG
	if moments != null:
		moments.pop("Got it! The part tore free (%d)" % got)
		moments.flourish()

func _carry(delta: float) -> void:
	if carried == null: return
	if not is_instance_valid(carried):
		carried = null
		return
	_carry_t += delta
	carried.global_position = carried.global_position.lerp(motor.feet+Vector3.UP*CARRY_HIGH,1.0-exp(-delta*14.0))
	if (motor.grounded and _carry_t > CARRY_LEAST) or _carry_t > CARRY_MOST:
		carried.take(got,self)
		carried = null

func _hint_text() -> String:
	return "Touch the part on the plane's rope to snatch it · WASD run · Space jump · Shift/C crouch: slide, + Space long jump · X twirl · Q / RB updraft (charged by flow) · 1 start · 2 pier · 3 perch · 4 terrace · R start · F1 numbers · F2 feel · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or snag == null: return
	var lines := PackedStringArray([_hud.text,""])
	lines.append("snag      lap %.0f s · rope %.1f m · dip %.1f m · %.1f s into the lap" % [snag.lap,snag.rope,snag.dip,fposmod(snag.clock,snag.lap)])
	lines.append("load      %s · %.0f° off plumb · %.1f m from him · plane bank %.0f°" % ["on the rope" if snag.attached else "torn off",rad_to_deg(snag.swing()),snag.load_point().distance_to(motor.feet+Vector3.UP*1.0),rad_to_deg(snag.flight.bank)])
	lines.append("got       %d" % got)
	_hud.text = "\n".join(lines)
