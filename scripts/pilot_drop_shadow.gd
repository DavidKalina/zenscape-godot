extends MeshInstance3D
## The pilot's drop shadow: a soft dark disc on the ground straight under
## him while he is in the air, so a jump, a glide or a slam can be aimed at
## where he will come down (the platformer's blob shadow; the sun's own
## shadow falls aside and is lost at a height). Hidden on the ground (the
## sun's shadow is enough there) and over nothing (the void).
##
## `update(motor, ground)` each frame after the motor steps: `ground` is the
## motor's own ground callable (plate point -> height under his feet,
## -INF none), so the disc lands where he would.
const WorldScale = preload("res://scripts/world_scale.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")

## The disc's radius at his feet as a share of his height, and how much it
## shrinks by FAR m up (a share of that radius).
const RADIUS := 0.36
const SHRINK := 0.35
const FAR := 30.0
## Its darkness (alpha) near and FAR up, and how high over the ground it
## sits (m, clear of the turf's flicker).
const NEAR_ALPHA := 0.6
const FAR_ALPHA := 0.3
const LIFT := 0.04
## The least height over the ground it shows at (m: a hop's start).
const SHOW_OVER := 0.25

var _material := StandardMaterial3D.new()

func _init() -> void:
	name = "DropShadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE*2.0
	mesh = quad
	var fade := Gradient.new()
	fade.set_color(0,Color(0.04,0.04,0.07,1.0))
	fade.set_color(1,Color(0.04,0.04,0.07,0.0))
	fade.add_point(0.55,Color(0.04,0.04,0.07,0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	tex.width = 64
	tex.height = 64
	_material.albedo_texture = tex
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false

func update(motor: Object, ground: Callable) -> void:
	var feet: Vector3 = motor.feet
	var under: float = ground.call(Vector2(feet.x,feet.z))
	var over := feet.y-under
	if motor.grounded or under == -INF or under == INF or over < SHOW_OVER:
		visible = false
		return
	visible = true
	var t := clampf(over/FAR,0.0,1.0)
	var r := RADIUS*PhysicsGround.HEAD*WorldScale.wanderer*(1.0-SHRINK*t)
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(r,1.0,r)),Vector3(feet.x,under+LIFT,feet.z))
	_material.albedo_color = Color(1.0,1.0,1.0,lerpf(NEAR_ALPHA,FAR_ALPHA,t))
