extends Node3D
## The thin base of an enemy: a mass with a reach and a footing, no hit points.
##
##   knobs   every number it plays by (speeds, timings, forces, sizes), made
##           from the pilot's numbers (`default_knobs`, given
##           enemy_field.gd `numbers()`) and then `overrides` on top, so a
##           tier can randomize them without touching the script.
##   cost    1 to 5, against a section's danger budget.
##   tags    the module model's tags ("knockable", "pushes", ...).
##   tell    `tell(colour)`: the greybox tell, a colour change on the body
##           and a placeholder sound call (field `sound`). Held for the
##           enemy's own `knobs.tell` seconds.
##
## Two ways physics, no damage. It can shove the pilot: `shove_pilot` is
## PilotMotor.knock, a knock_velocity out `out` m along a way. The pilot
## can knock it: running or sliding into it at `knobs.push_speed` or more
## throws it along (`pilot_pushes`, then it is stunned `stun_knock` s and
## slides to rest on its own friction); off an edge it falls under the
## pilot's gravity and is gone below the study's `lost`.
## It is also a prop: a StaticBody3D the size of its body, so the pilot
## stands on it and jumps off it (a stunned one, or one standing). The body
## is set in the physics space as it moves (not at the frame's flush), it
## shoves him out when it moves into him (`push_out`), and stood on it
## carries him unless it `bucks()` (then `buck` throws him off behind it).
##
## A new enemy extends this and overrides: `default_knobs(n)` (merged over
## the base's), `_art(skin)` (draw it; `_part` adds a box, tinted ones take
## the tell's colour), `think(delta)` (set `vel`, change `state`), and
## optionally `harmful()`, `bucks()`, `bumped()`, `landed()`. Then it is one line in a
## scene's table (studies/enemy_yard.gd ENEMIES).
const PilotMotor = preload("res://scripts/pilot_motor.gd")

signal told(enemy)
signal hit_pilot(enemy)
signal knocked(enemy)
signal fell(enemy)

var knobs := {}
var cost := 1
var tags: PackedStringArray = []
var field: Node
var vel := Vector3.ZERO
## The way it faces (PilotMotor.forward / facing_of); -Z is its front.
var facing := 0.0
var grounded := true
var state := "idle"
var state_t := 0.0
## The body's size (m): along, across, up.
var length := 1.0
var width := 1.0
var height := 1.0
var body: StaticBody3D
var skin: Node3D
var gone := false
## What it moved this step.
var moved := Vector3.ZERO
## Tells given, for tests and the HUD.
var told_count := 0
var rest_colour := Color(0.62,0.58,0.5)
var tell_colour := Color(0.95,0.35,0.15)
var stun_colour := Color(0.45,0.6,0.85)
var mark_colour := Color(0.96,0.84,0.2)
var tell_sound := &"enemy_tell"
var _mat := StandardMaterial3D.new()
var _cool := 0.0
var _stun_for := 0.0

## Set up as `field` (enemy_field.gd) places it at `at`, facing `face`.
func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	field = host
	var n: Dictionary = host.numbers()
	knobs = _base_knobs(n)
	knobs.merge(default_knobs(n),true)
	knobs.merge(overrides,true)
	_size(n)
	position = at
	facing = PilotMotor.facing_of(face)
	rotation.y = facing
	_build()
	rest()

## The numbers every enemy shares.
func _base_knobs(n: Dictionary) -> Dictionary:
	return {
		"gravity":n.gravity*n.fall,"step_up":n.step_up,"wall_probe":n.step_up+0.1,
		"skid_decel":n.skid,"push_speed":n.run*1.1,"push_carry":0.85,"stun_knock":1.5,
		"tell":0.8,"rest":0.8,"radius":n.radius,
	}

## An enemy's own knobs, over the base's.
func default_knobs(_n: Dictionary) -> Dictionary:
	return {}

## `length`, `width` and `height`, from the pilot's numbers.
func _size(n: Dictionary) -> void:
	height = n.unit
	width = n.unit*0.5
	length = n.unit*0.8

func _build() -> void:
	body = StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width,height,length)
	collider.shape = box
	collider.position.y = height*0.5
	body.add_child(collider)
	add_child(body)
	skin = Node3D.new()
	add_child(skin)
	_mat.albedo_color = rest_colour
	_mat.roughness = 0.9
	_art(skin)

## Draws it: greybox boxes, -Z the front. Override.
func _art(_root: Node3D) -> void:
	_part(Vector3(width,height,length),Vector3(0.0,height*0.5,0.0),true)

## A box part of the skin (or of `parent`, a pivot in it): `tinted` ones
## change colour with the tell.
func _part(size: Vector3, at: Vector3, tinted := false, colour := Color.WHITE, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.position = at
	if tinted: m.material_override = _mat
	else:
		var own := StandardMaterial3D.new()
		own.albedo_color = colour
		own.roughness = 0.9
		m.material_override = own
	(parent if parent != null else skin).add_child(m)
	return m

# --- The tell --------------------------------------------------------------------

## The tell: the body turns `tell_colour` (it glows) and the placeholder
## sound is called. The enemy holds it for `knobs.tell` s itself.
func tell(colour := tell_colour) -> void:
	told_count += 1
	tint(colour)
	field.sound(tell_sound,global_position)
	told.emit(self)

func tint(colour: Color) -> void:
	_mat.albedo_color = colour
	_mat.emission_enabled = colour != rest_colour
	_mat.emission = colour
	_mat.emission_energy_multiplier = 0.5

func rest() -> void:
	tint(rest_colour)

# --- A frame ---------------------------------------------------------------------

func step(delta: float) -> void:
	if gone: return
	_cool = maxf(0.0,_cool-delta)
	var was := position
	if state == "stun":
		state_t += delta
		slow(delta,float(knobs.skid_decel))
		if state_t >= _stun_for:
			state = "idle"
			state_t = 0.0
			rest()
	else: think(delta)
	_move(delta)
	moved = position-was
	# The body to where it is drawn in the physics space now, not at the
	# tree's flush: the pilot's step this frame meets it here.
	if not gone: body.force_update_transform()

## What it does this frame: set `vel` and `state`. Override.
func think(_delta: float) -> void:
	pass

## Whether touching it now shoves the pilot (a charge, a swing). Override.
func harmful() -> bool:
	return false

## Whether a pilot stood on its back is NOT carried (it runs out from under
## him: a charge, a skid). Override.
func bucks() -> bool:
	return not grounded

## It ran into a wall (a body above the step) with `vel` ended. Override.
func bumped() -> void:
	pass

## It came down onto the ground out of the air. Override.
func landed() -> void:
	pass

## It is not above ground at `way` (x, z) a `dist` ahead of its middle.
func edge_ahead(way: Vector2, dist: float) -> bool:
	var probe := position+Vector3(way.x,0.0,way.y)*dist
	return field.floor_under(probe,knobs.step_up,knobs.step_up*2.0,body.get_rid()) == -INF

func _move(delta: float) -> void:
	var rid := body.get_rid()
	if grounded:
		var flat := Vector2(vel.x,vel.z)
		if flat.length() > 0.001:
			var dir := flat.normalized()
			var step := flat*delta
			var ahead := Vector3(dir.x,0.0,dir.y)*(length*0.5+step.length()+0.05)
			if field.blocked(position+Vector3.UP*float(knobs.wall_probe),ahead,rid):
				vel.x = 0.0
				vel.z = 0.0
				bumped()
			else: position += Vector3(step.x,0.0,step.y)
		var g: float = field.floor_under(position,knobs.step_up,knobs.step_up,rid)
		if g == -INF:
			grounded = false
			vel.y = 0.0
		else: position.y = g
	else:
		vel.y -= float(knobs.gravity)*delta
		var was_y := position.y
		position += vel*delta
		_air_pose(delta)
		if vel.y <= 0.0:
			var g: float = field.floor_under(position,was_y-position.y+0.05,0.05,rid)
			if g != -INF:
				position.y = g
				grounded = true
				vel.y = 0.0
				skin.rotation.x = 0.0
				landed()
		if position.y < field.lost:
			gone = true
			field.gone_count += 1
			fell.emit(self)
			queue_free()

## Its pose while it falls (override): the front tipping up.
func _air_pose(delta: float) -> void:
	skin.rotation.x = minf(skin.rotation.x+1.6*delta,1.2)

## Slows the flat velocity by `decel` m/s^2; true once at rest.
func slow(delta: float, decel: float) -> bool:
	var flat := Vector2(vel.x,vel.z)
	flat = flat.move_toward(Vector2.ZERO,decel*delta)
	vel.x = flat.x
	vel.z = flat.y
	return flat.length() < 0.05

# --- The pilot -------------------------------------------------------------------

## Tests contact with the pilot `m` (PilotMotor), who was going `v_pre`
## (x, z) into the step: a push at `knobs.push_speed` or more along the
## line to it throws it; otherwise a harmful one shoves him.
func touch(m: PilotMotor, v_pre: Vector3) -> void:
	if gone or _cool > 0.0: return
	var rel := m.feet-position
	var local := Basis(Vector3.UP,facing).inverse()*rel
	var margin := float(knobs.radius)+0.2
	if absf(local.x) > width*0.5+margin or absf(local.z) > length*0.5+margin: return
	# Stood on it (over its back), or under it: no contact.
	if m.feet.y > position.y+height-0.1 or m.feet.y < position.y-0.6: return
	var to := Vector2(position.x-m.feet.x,position.z-m.feet.z)
	if to.length() < 0.01: return
	to = to.normalized()
	var toward := Vector2(v_pre.x,v_pre.z).dot(to)
	if toward >= float(knobs.push_speed) and not m.recovering():
		pilot_pushes(m,to,toward)
	elif harmful() and not m.seized() and (not m.recovering() or m.stunnable(self)):
		# A stunned body is hit again once this one's own gap is past
		# (PilotMotor `restun_gap`): the world may chain its hits.
		hits_pilot(m)

## Whether `lip` (a ledge's edge the pilot holds) is on its back.
func holds(lip: Vector3) -> bool:
	if absf(lip.y-(position.y+height)) > 0.15: return false
	var local := Basis(Vector3.UP,facing).inverse()*(lip-position)
	return absf(local.x) <= width*0.5+0.1 and absf(local.z) <= length*0.5+0.1

## A pilot on its back (or hanging from it) as it `bucks()`: thrown off
## behind it (PilotMotor.knock: a tumble, no harm), not left standing on air
## or hanging from an edge that ran off.
func buck(m: PilotMotor) -> void:
	var back := -PilotMotor.forward(facing)
	var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
	var out := maxf(length*0.5-local.z,0.0)*0.5+float(knobs.radius)*2.0
	m.knock(m.knock_velocity(back,out,height*0.3,maxf(m.feet.y-position.y,0.0)),self)
	_cool = 0.3

## It moved or turned into the pilot `m` (its body is a stone he can't walk
## through, but he is no collider to it): he is shoved out of its box, the
## shortest way, sliding along walls as he goes (`slide`, the study's
## PhysicsGround.slide). Only where his body meets it: his feet under its top
## by more than his body's lowest part (PhysicsGround.BODY_LOW; higher, the
## motor's ground ray steps or lands him onto its back), his head over its
## foot. A pilot hanging from a rim is never touched.
func push_out(m: PilotMotor, slide: Callable, body_low: float, head: float) -> void:
	if gone or m.on_ledge(): return
	var top := position.y+height
	if m.feet.y+body_low >= top or m.feet.y+head <= position.y: return
	var basis := Basis(Vector3.UP,facing)
	var local := basis.inverse()*(m.feet-position)
	var p := Vector2(local.x,local.z)
	var half := Vector2(width*0.5,length*0.5)
	var r := float(knobs.radius)
	var near := Vector2(clampf(p.x,-half.x,half.x),clampf(p.y,-half.y,half.y))
	var off := p-near
	var out := Vector2.ZERO
	if off.length() > 0.0001:
		if off.length() >= r: return
		out = off.normalized()*(r-off.length())
	else:
		# His middle inside its box: out through the nearest side.
		var gx := half.x-absf(p.x)
		var gz := half.y-absf(p.y)
		if gx < gz: out = Vector2(signf(p.x) if p.x != 0.0 else 1.0,0.0)*(gx+r)
		else: out = Vector2(0.0,signf(p.y) if p.y != 0.0 else 1.0)*(gz+r)
	var w := basis*Vector3(out.x,0.0,out.y)
	var step := Vector2(w.x,w.z)*(1.0+0.02/maxf(out.length(),0.01))
	# Its own body set aside so the cast sees only the walls round him.
	var was := body.collision_layer
	body.collision_layer = 0
	var to: Vector3 = slide.call(m.feet,step)
	body.collision_layer = was
	m.carry(Transform3D(Basis.IDENTITY,Vector3(to.x-m.feet.x,0.0,to.z-m.feet.z)),0.0)

## The pilot ran or slid into it at `speed` along `way` (x, z): thrown
## along it, stunned; he loses most of his pace.
func pilot_pushes(m: PilotMotor, way: Vector2, speed: float) -> void:
	var carried: float = speed*float(knobs.push_carry)
	vel = Vector3(way.x*carried,0.0,way.y*carried)
	m.velocity.x *= 0.35
	m.velocity.z *= 0.35
	_cool = 0.3
	pushed(speed)
	knocked.emit(self)

## It was pushed (override: stun, tint).
func pushed(_speed: float) -> void:
	stun(float(knobs.stun_knock))

## Shoves the pilot: PilotMotor.knock out `out` m along `way` (x, z),
## peaking `up` m.
## A shove hurts (a heart, PilotMotor.harm, named `harm_cause()`).
func shove_pilot(m: PilotMotor, way: Vector2, out: float, up: float) -> void:
	m.knock(m.knock_velocity(way,out,up),self)
	m.harm(harm_cause(),1,self)
	_cool = 0.3
	hit_pilot.emit(self)

## What its hits are called on the death card (run_loop.gd WORDS.causes).
func harm_cause() -> String:
	return "enemy"

## It hit the pilot (override: shove him with `shove_pilot`).
func hits_pilot(_m: PilotMotor) -> void:
	pass

## Stunned for `seconds`: a prop, sliding to rest on `skid_decel`, then
## "idle" again (`think` is not called meanwhile).
func stun(seconds: float) -> void:
	state = "stun"
	state_t = 0.0
	_stun_for = seconds
	tint(stun_colour)
