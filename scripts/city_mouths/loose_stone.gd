extends "res://scripts/enemies/enemy.gd"
## A loose stone (round 4 strange city, a5-earth-mouths): a fallen block of
## the city's masonry, dead weight the Earth Mouths eat
## (scripts/city_mouths/earth_mouths.gd). It is the enemy base's prop
## (scripts/enemies/enemy.gd): a stone you stand on; walk or run into it and
## it slides along (`pilot_pushes`), more the faster you came; over a rim it
## falls. Your slam beside it kicks it away (scripts/slam.gd GROUP). Stone on
## stone it slides a little way (`skid_decel`), so a shove at a rim sends it
## over. No thinking, no harm.
const RefugesKit = preload("res://scripts/city_kit_refuges.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Slam = preload("res://scripts/slam.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")

## Its block (m): across, up, along.
const SIZE := Vector3(1.4,1.1,1.4)

## Dead weight: what a mouth eats.
func dead_weight() -> bool:
	return true

func default_knobs(n: Dictionary) -> Dictionary:
	# A walk into it moves it; its slide on stone is long (a shove at a rim
	# sends it over); it lies still till pushed again.
	return {"push_speed":n.walk*0.7,"push_carry":1.0,"skid_decel":4.0,"stun_knock":8.0}

func _size(_n: Dictionary) -> void:
	width = SIZE.x
	height = SIZE.y
	length = SIZE.z

func _init() -> void:
	tags = PackedStringArray(["knockable","dead_weight"])
	tell_sound = &"stone_scrape"

func _ready() -> void:
	add_to_group(Slam.GROUP)

func _art(root: Node3D) -> void:
	var m := RefugesKit.CityMesher.new(GiantStone.stone_colour())
	m.box(Transform3D(Basis(Vector3.UP,0.12),Vector3(0.0,SIZE.y*0.5,0.0)),SIZE,0.16,0.0,0.92)
	# A broken corner, paler (fresh cut): it fell off something.
	m.box(Transform3D(Basis(Vector3(1.0,0.0,1.0).normalized(),0.5),Vector3(0.45,SIZE.y-0.05,0.4)),Vector3(0.5,0.3,0.5),0.06,0.0,1.25)
	var mi := MeshInstance3D.new()
	mi.mesh = m.mesh(RefugesKit.stone_material(),null)
	root.add_child(mi)

## The wanderer's slam beside it: kicked away from his feet.
func slam(at: Vector3, radius: float, strength: float) -> void:
	if gone or not visible: return
	var v := Slam.knock_way(at,radius,strength,position+Vector3.UP*height*0.5)
	if v == Vector3.ZERO: return
	vel = Vector3(v.x,maxf(v.y,1.5),v.z)
	grounded = false
	stun(float(knobs.stun_knock))
	field.sound(&"stone_scrape",position)

func pushed(_speed: float) -> void:
	stun(float(knobs.stun_knock))
	field.sound(&"stone_scrape",position)

func rest() -> void:
	pass

func tint(_colour: Color) -> void:
	pass

## Its air pose: none (a block falls flat).
func _air_pose(_delta: float) -> void:
	pass

func landed() -> void:
	field.sound(&"stone_thud",position)
	Dust.puff(field,position,1.6)
