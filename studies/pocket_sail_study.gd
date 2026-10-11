extends "res://studies/character_study.gd"
## Pocket sail study: a greybox for the hand glider (scripts/pocket_sail.gd)
## the pilot pops out with Space (the pad's A) in mid-air. The character
## study's pilot, camera, numbers (F1) and feel panel (F2, the sail's own
## numbers at its foot), over a tall floating island in the open sky:
##
##   the top     a 36 m square slab 50 m up on a stem (its rim, as any
##               edge, hung from); on its east side four launch pads (stand-ins for a
##               sentinel's blow, docs/design/sentinels-idea): walked onto,
##               each throws him east, harder down the row (PADS: nudge,
##               shove, blow, hurl). K anywhere is a sentinel's blow: out
##               from the island's middle at one of the pads' forces, a
##               little to either side.
##   the shelf   12 m down, east of the cliff: a short throw lands here.
##               A stair of ten blocks climbs back to the top.
##   the islets  26 m down, further east, joined by stepping stones; two
##               switchback ramps climb from them to the shelf.
##   the floor   50 m down, under everything: four more switchback ramps
##               climb to the islets. Fallen past it (LOST), he is set back
##               at the nearest station. Never death.
##
## The air (`air_at`, read by the motor's sail): gust fronts (GUST_EVERY s
## apart) sweep the whole sky across x, by turns out from the island (east)
## and back towards it (west), each a band GUST_WIDTH m deep pushing at
## GUST_PUSH m/s with a little lift, drawn as a band of streaks; G sends
## the next one now. A rising-air column (THERMAL) stands off the shelf's
## north end, drawn as a warm column with rising bands: under the sail it
## slows the sink or lifts a little, never over the airtime's peak.
##
## Height is what the sail spends: thrown high (blow, hurl) it coasts back
## onto the top; a nudge or a shove comes down short, and costs the climb.
##   ./run-pocket-sail.command
##   godot --path . res://studies/pocket_sail_study.tscn -- --no-title

const NAME := "Pocket sail"
const TOP := 50.0
const START_AT := Vector3(0.0,TOP,6.0)
const START_WAY := Vector2(1.0,0.0)
const FALLEN := -30.0
## The top slab's half width (m), its stem's, and the slab's depth.
const TOP_HALF := 18.0
const STEM_HALF := 8.0
const SLAB := 12.0
## The launch pads along the east edge: name, middle (x, z), the throw out
## (east, m/s) and up (m/s). Walked onto, each throws once.
const PADS := [
	["nudge",Vector2(15.0,14.0),10.0,8.0],
	["shove",Vector2(15.0,7.0),11.0,12.0],
	["blow",Vector2(15.0,0.0),12.0,16.0],
	["hurl",Vector2(15.0,-7.0),14.0,21.0],
]
const PAD_SIZE := 4.0
## A sentinel's blow (K): this far either side of straight out (radians).
const BLOW_SPREAD := 0.5
## Gust fronts: seconds between them, how fast a front travels (m/s), its
## depth (m), its push and lift at its middle (m/s), how far out it starts
## and ends (m), and the first's delay (s).
const GUST_EVERY := 10.0
const GUST_SPEED := 9.0
const GUST_WIDTH := 30.0
const GUST_PUSH := 8.0
const GUST_LIFT := 1.0
const GUST_FROM := 120.0
const GUST_FIRST := 3.0
## The rising-air column: its middle (x, z), radius (m), top (m) and
## strength (thermal units: the sail rises THERMAL m/s for each).
const THERMAL_AT := Vector2(30.0,-27.0)
const THERMAL_RADIUS := 6.0
const THERMAL_TOP := 75.0
const THERMAL_STRENGTH := 1.2

const GUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.92,0.97,1.0,1.0);
uniform float strength = 0.7;
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = strength*COLOR.a;
}
"""
const THERMAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.82,0.55,1.0);
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float a = atan(local.z,local.x);
	float rise = fract(local.y*0.1-TIME*0.4+sin(a*3.0)*0.12);
	float band = smoothstep(0.0,0.12,rise)*smoothstep(0.45,0.2,rise);
	ALBEDO = tint.rgb;
	ALPHA = 0.05+0.22*band;
}
"""

## The air's clock (s); the fronts under way: {born (s), way (1 east, -1
## west), node}; how many have set off.
var air_clock := 0.0
var fronts: Array = []
var _gusts := 0
var _next_gust := GUST_FIRST
## The pad stood on last frame on the ground ("" none), and grounded then.
var _pad_was := ""
var _ground_was := true
## A blow asked (K), and the last throw: {what, at, push}; the highest the
## feet were since it (m), for the numbers.
var _blow_asked := false
var last_throw := {}
var _throw_peak := -INF
var _study_line: Label

func _init() -> void:
	pack = "pocket_sail"
	motor.air = air_at

## The study's stations, start and fall (the pack's, built here, not read
## from studies/island_packs), and its air drawn.
func _load_pack() -> void:
	stations = _stations()
	start = START_AT
	start_face = START_WAY
	lost = FALLEN
	_last_stood = start
	_build_air()
	print("pocket sail study: %d stations" % stations.size())

func _material(colour: String) -> Material:
	if colour == "launch" and not _materials.has(colour):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",Color(0.86,0.3,0.24))
		_materials[colour] = m
	return super._material(colour)

static func _stations() -> Array:
	var top := [
		# The top: a slab on a stem (its rim, as any edge, a lip to hang from).
		["box",Rect2(-TOP_HALF,-TOP_HALF,TOP_HALF*2.0,TOP_HALF*2.0),TOP-SLAB,TOP,"floor"],
		["box",Rect2(-STEM_HALF,-STEM_HALF,STEM_HALF*2.0,STEM_HALF*2.0),0.0,TOP-SLAB,"dark"],
		["label",Vector3(-12.0,TOP+0.6,12.0),"K: a sentinel's blow · G: the next gust now"],
	]
	for pad: Array in PADS:
		var at: Vector2 = pad[1]
		top.append(["box",Rect2(at.x-PAD_SIZE*0.5,at.y-PAD_SIZE*0.5,PAD_SIZE,PAD_SIZE),TOP,TOP+0.08,"launch"])
		top.append(["label",Vector3(at.x-3.4,TOP+0.7,at.y),"%s → %d out, %d up" % [pad[0],int(pad[2]),int(pad[3])]])
	# The shelf, 12 m down past a 4 m gap east of the cliff, and its stair
	# of twelve blocks (1 m each, a jump apiece) back up to a plank onto the
	# top.
	var shelf := [
		["box",Rect2(22.0,-16.0,14.0,36.0),34.0,38.0,"floor"],
		["box",Rect2(18.0,-15.0,4.0,5.0),TOP-1.0,TOP,"floor"],
		["label",Vector3(30.0,38.8,-4.0),"shelf · 12 m down"],
	]
	for k in range(12):
		shelf.append(["box",Rect2(22.0,13.5-2.5*k,3.0,2.5),38.0,38.0+float(k+1),"grey"])
	# The islets, 26 m down: the main one under the shelf's south end, two
	# more north-east and south-east over stepping stones; a switchback
	# (two flights of 7 m at about 19°) climbs from it to the shelf.
	var islets := [
		["box",Rect2(36.0,10.0,12.0,12.0),20.0,24.0,"floor"],
		["box",Rect2(52.0,-30.0,10.0,10.0),20.0,24.0,"floor"],
		["box",Rect2(62.0,24.0,10.0,10.0),20.0,24.0,"floor"],
		["box",Rect2(59.0,32.0,2.0,2.0),22.0,24.0,"pad"],
		["label",Vector3(42.0,24.8,18.0),"islets · 26 m down"],
	]
	# Stepping stones (3 m, about 1.6 m apart) from the main islet's
	# north-east corner to the north-east islet.
	for i in range(1,7):
		var c := Vector2(46.0,8.0).lerp(Vector2(57.0,-22.0),i/7.0)
		islets.append(["box",Rect2(c.x-1.5,c.y-1.5,3.0,3.0),22.0,24.0,"pad"])
	islets.append_array(_switchback(Vector2(37.0,10.0),24.0,2,7.0,-1.0,Vector2(36.0,-1.0)))
	# The floor, 50 m down under everything, and four flights up to the
	# islets, the last landing joined to the main islet by a bridge.
	var floor := [
		["box",Rect2(-120.0,-120.0,240.0,240.0),-4.0,0.0,"floor"],
		["box",Rect2(46.0,22.0,4.0,16.0),23.0,24.0,"floor"],
		["label",Vector3(52.0,0.8,46.0),"floor · 50 m down · the climb back starts here"],
	]
	floor.append_array(_switchback(Vector2(50.0,34.0),0.0,4,6.0,-1.0,Vector2(50.0,0.0)))
	return [
		{"key":1,"name":"Top · start","spawn":START_AT,"face":START_WAY,"sign":Vector3(-4.0,TOP+3.0,0.0),"parts":top},
		{"key":2,"name":"Launch pads","spawn":Vector3(8.0,TOP,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(8.0,TOP+3.5,-16.0),"parts":[]},
		{"key":3,"name":"Shelf · 12 m down","spawn":Vector3(30.0,38.0,4.0),"face":Vector2(-1.0,0.0),"sign":Vector3(30.0,41.0,-14.0),"parts":shelf},
		{"key":4,"name":"Islets · 26 m down","spawn":Vector3(44.0,24.0,18.0),"face":Vector2(0.0,-1.0),"sign":Vector3(44.0,27.0,21.0),"parts":islets},
		{"key":5,"name":"Floor · 50 m down","spawn":Vector3(52.0,0.0,44.0),"face":Vector2(0.0,-1.0),"sign":Vector3(52.0,3.5,47.0),"parts":floor},
		{"key":6,"name":"By the rising air","spawn":Vector3(14.0,TOP,-14.0),"face":Vector2(1.0,-0.8).normalized(),"sign":Vector3(THERMAL_AT.x,TOP+6.0,THERMAL_AT.y),"parts":[]},
	]

## A switchback climb: `flights` ramps of `rise` m each, 4 m wide, about
## 19° steep, alternating north and south (`way` -1 first goes north, -z),
## each starting on its low edge at `from` (its west lane's south-west
## corner, x z) and `low` m up; side by side in two 4 m lanes, with an 8 by
## 4 m landing at each turn. `bridge` (x the landing's west edge, unused z)
## is where the last landing reaches west to (its x), so it meets land.
static func _switchback(from: Vector2, low: float, flights: int, rise: float, way: float, bridge: Vector2) -> Array:
	var parts := []
	var run := rise/tan(deg_to_rad(19.0))
	var y := low
	var z0 := from.y
	for i in range(flights):
		var lane := from.x+(4.0 if i%2 == 1 else 0.0)
		var z1 := z0+way*run
		parts.append(["ramp",Vector3(lane+2.0,y,z0),Vector3(lane+2.0,y+rise,z1),4.0,"grey"])
		y += rise
		# The turn's landing, past the high end, both lanes wide.
		var lz := z1 if way > 0.0 else z1-4.0
		var west := from.x if i < flights-1 else minf(from.x,bridge.x)
		parts.append(["box",Rect2(west,lz,from.x+8.0-west,4.0),y-1.0,y,"floor"])
		z0 = z1
		way = -way
	return parts

# --- The air ------------------------------------------------------------------------

## The air at `p`: the fronts' push and lift, the column's rise
## ({wind, thermal}).
func air_at(p: Vector3) -> Dictionary:
	var wind := Vector3.ZERO
	for front: Dictionary in fronts:
		var k := gust_at(front,p.x)
		wind += Vector3(float(front.way)*GUST_PUSH*k,GUST_LIFT*k,0.0)
	var thermal := 0.0
	var off := Vector2(p.x,p.z).distance_to(THERMAL_AT)
	if p.y < THERMAL_TOP: thermal = THERMAL_STRENGTH*(1.0-smoothstep(THERMAL_RADIUS*0.6,THERMAL_RADIUS,off))
	return {"wind":wind,"thermal":thermal}

## Where front `front` stands along x now.
func front_x(front: Dictionary) -> float:
	return float(front.way)*(-GUST_FROM+GUST_SPEED*(air_clock-float(front.born)))

## How much of front `front`'s push is at `x` (0 to 1, fullest at its
## middle).
func gust_at(front: Dictionary, x: float) -> float:
	var u := (x-front_x(front))/GUST_WIDTH
	if absf(u) >= 0.5: return 0.0
	var c := cos(u*PI)
	return c*c

## A front sets off now: east (out from the island) and west by turns.
func send_gust() -> void:
	var way := 1.0 if _gusts%2 == 0 else -1.0
	_gusts += 1
	var front := {"born":air_clock,"way":way,"node":_gust_node(way)}
	fronts.append(front)
	_next_gust = air_clock+GUST_EVERY

func _advance_air(delta: float) -> void:
	air_clock += delta
	if air_clock >= _next_gust: send_gust()
	for front: Dictionary in fronts.duplicate():
		var x := front_x(front)
		if absf(x) > GUST_FROM+GUST_WIDTH:
			if front.node != null: front.node.queue_free()
			fronts.erase(front)
			continue
		if front.node != null: (front.node as Node3D).position.x = x

func _build_air() -> void:
	var column := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = THERMAL_RADIUS
	tube.bottom_radius = THERMAL_RADIUS
	tube.height = THERMAL_TOP
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 32
	column.mesh = tube
	var warm := ShaderMaterial.new()
	warm.shader = Shader.new()
	warm.shader.code = THERMAL_SHADER
	column.material_override = warm
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position = Vector3(THERMAL_AT.x,THERMAL_TOP*0.5,THERMAL_AT.y)
	add_child(column)
	_label(Vector3(THERMAL_AT.x,TOP+4.0,THERMAL_AT.y),"rising air",48)

## A front drawn: streaks along x scattered through its band, each a thin
## rod a few metres long, fading to its edges.
func _gust_node(way: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Gust"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var rod := BoxMesh.new()
	rod.size = Vector3(4.0,0.06,0.06)
	multi.mesh = rod
	var count := 420
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = _gusts
	for i in range(count):
		var u := rng.randf_range(-0.5,0.5)
		var at := Vector3(u*GUST_WIDTH,rng.randf_range(-2.0,72.0),rng.randf_range(-70.0,70.0))
		var c := cos(u*PI)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(rng.randf_range(0.5,1.4),1.0,1.0)),at))
		multi.set_instance_color(i,Color(1.0,1.0,1.0,c*c))
	var drawn := MultiMeshInstance3D.new()
	drawn.multimesh = multi
	var streak := ShaderMaterial.new()
	streak.shader = Shader.new()
	streak.shader.code = GUST_SHADER
	drawn.material_override = streak
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(drawn)
	var sign := Label3D.new()
	sign.text = "gust →" if way > 0.0 else "← gust"
	sign.font_size = 96
	sign.pixel_size = 0.02
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1.0,1.0,1.0,0.8)
	sign.outline_size = 12
	sign.outline_modulate = Color(0.2,0.3,0.4,0.6)
	sign.position = Vector3(0.0,TOP+12.0,0.0)
	node.add_child(sign)
	node.position.x = -way*GUST_FROM
	add_child(node)
	return node

# --- Throws -------------------------------------------------------------------------

## The pad (its name) under the feet, on the ground on the top, or "".
func pad_under(feet: Vector3) -> String:
	if absf(feet.y-(TOP+0.08)) > 0.3: return ""
	for pad: Array in PADS:
		var at: Vector2 = pad[1]
		if absf(feet.x-at.x) <= PAD_SIZE*0.5 and absf(feet.z-at.y) <= PAD_SIZE*0.5: return pad[0]
	return ""

## Thrown from where he stands: `push` (m/s), named `what`.
func throw(push: Vector3, what: String) -> void:
	motor.knock(push)
	last_throw = {"what":what,"at":motor.feet,"push":push}
	_throw_peak = motor.feet.y
	steps.step(_surface(),1.0)
	puffs.burst(_puff_at(figure.global_position),_surface(),0.6)
	Pad.pulse(0.4,0.3,0.15)

## A sentinel's blow: out from the island's middle (his facing reversed at
## the middle), at a pad's force picked at random, a little to either side.
func blow(force := -1) -> void:
	var out := Vector2(motor.feet.x,motor.feet.z)
	out = out.normalized() if out.length() > 1.0 else -PilotMotor.forward(motor.facing)
	out = out.rotated(randf_range(-BLOW_SPREAD,BLOW_SPREAD))
	var pad: Array = PADS[force if force >= 0 else randi()%PADS.size()]
	throw(Vector3(out.x*float(pad[2]),float(pad[3]),out.y*float(pad[2])),"blow (%s)" % pad[0])

func tick(delta: float) -> void:
	_advance_air(delta)
	# Walked onto a pad (not landed on one): thrown.
	var pad := pad_under(motor.feet) if motor.grounded else ""
	if pad != "" and pad != _pad_was and _ground_was:
		for p: Array in PADS:
			if p[0] == pad: throw(Vector3(float(p[2]),float(p[3]),0.0),pad)
	_pad_was = pad
	_ground_was = motor.grounded
	if _blow_asked and (motor.grounded or motor.on_ledge()): blow()
	_blow_asked = false
	super.tick(delta)
	if not motor.grounded: _throw_peak = maxf(_throw_peak,motor.feet.y)

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var here := air_at(motor.feet)
	var wind: Vector3 = here.wind
	var lines := PackedStringArray([
		"air       wind %+.1f m/s east · rise %.1f · thermal %.1f" % [wind.x,wind.y,float(here.thermal)],
		"gusts     next %s in %.1f s" % ["east (out)" if _gusts%2 == 0 else "west (back)",maxf(_next_gust-air_clock,0.0)],
	])
	if not last_throw.is_empty():
		var from: Vector3 = last_throw.at
		lines.append("throw     %s · peak %.1f m over where it threw · now %+.1f m from there" % [last_throw.what,_throw_peak-from.y,motor.feet.y-from.y])
	_hud.text += "\n"+"\n".join(lines)

func _build_ui() -> void:
	super._build_ui()
	_study_line = Label.new()
	_study_line.text = "Pocket sail: walk onto a pad (or K) to be thrown off · Space in the air: the sail, again: fold · crouch: float · G: a gust now · 1-6 stations · R start"
	_study_line.add_theme_font_size_override("font_size",16)
	_study_line.add_theme_color_override("font_color",Color("fbf6ea"))
	_study_line.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	_study_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_study_line.offset_top = 44.0
	_study_line.offset_left = -640.0
	_study_line.offset_right = 640.0
	_study_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.get_parent().add_child(_study_line)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _tuning():
		match (event as InputEventKey).keycode:
			KEY_K:
				_blow_asked = true
				return
			KEY_G:
				send_gust()
				return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		_blow_asked = true
		return
	super._unhandled_input(event)
