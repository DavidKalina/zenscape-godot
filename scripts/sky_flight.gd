extends Node
## How the sky answers the glide (scripts/sky_glide.gd).
##
## The Opal cloud sea is drawn in the sky box, one depth below the eye
## (shaders/sky_cloud_sea_opal.gdshaderinc), so on its own it never comes
## nearer. While gliding this tells it, through `zs_sea_flight`, where the
## eye has gone: the sea lies SEA_Y metres down in the world, so it slides
## by under a glide and swells up under a fall. Falling towards it, the
## cloud parts beneath the eye, from PART_FROM down to PART_FULL, and the
## land far below shows through. The cushion (SkyGlide FLOOR) catches the
## fall in the opening, and the sea closes again as the glide climbs.
##
## The vapour is a soft white-out over the view: deep in a cloud
## (scripts/sky_clouds.gd) and down in the cloud sea's top.
##
## The haze (scripts/sky_haze.gd) is on for the whole glide, perched or
## flying, and eases off with the sea once it ends, so the build view's own
## haze comes back as it was. It reads the rising islands off the islands
## (scripts/sky_islands.gd), which the eye that owns this keeps as `islands`.
##
## Under --below (scripts/sky_below.gd, `lower`) the sea never parts: falling
## into it the vapour whitens whole (SkyBelow `band`), and deep in it the
## eye crosses to the lower world and back, the sky turned overcast while
## it is there (reference_sky's `below_world`) and the stars and planet put
## away.

## The cloud sea's height in the world, in metres.
const SEA_Y := -105.0
## The sea starts to part with the eye this low, and is open at PART_FULL.
const PART_FROM := -40.0
const PART_FULL := -85.0
## The sea's top vapour: from VAPOUR_FROM down to VAPOUR_FULL.
const VAPOUR_FROM := -70.0
const VAPOUR_FULL := -100.0
## Seconds the sea takes to settle back to rest after the glide.
const SETTLE := 1.2
const EASE := 0.15
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SkyBelow = preload("res://scripts/sky_below.gd")

var scene: Node3D
## Where the eye stepped off, moved with the islands' swaps, and its height
## over the sea then.
var origin := Vector3.ZERO
var rest_height := 1.0
var active := false
## The value last published, and how much of the glide's view is left
## while settling back.
var flight := Vector4(0.0,0.0,1.0,0.0)
var vapour := 0.0
## How much of the glide's haze is on (0 to 1).
var haze := 0.0
var _settling := 0.0
## The lower world, under --below (scripts/sky_below.gd), or null.
var lower: Node3D = null
var _layer: CanvasLayer
var _veil: ColorRect

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "SkyFlight"
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glide_vapour.gdshader")
	_veil.material = material
	_veil.visible = false
	_layer.add_child(_veil)
	_publish()

func start(eye: Vector3) -> void:
	active = true
	_settling = 0.0
	origin = eye
	rest_height = maxf(eye.y-SEA_Y,1.0)
	flight = Vector4(0.0,0.0,1.0,0.0)
	vapour = 0.0
	# On at once: the islands bake in over the next frames, out where the
	# haze must already hide them, and near the plate it is all but clear.
	haze = 1.0
	if lower != null:
		lower.reset()
		if _veil != null: (_veil.material as ShaderMaterial).set_shader_parameter("whole",1.0)
	_publish()

## The islands swapped: the world moved by `by`, the eye with it.
func move(by: Vector3) -> void:
	origin += by

func stop() -> void:
	active = false
	_settling = SETTLE
	if lower != null: lower.reset()

## Each frame of the glide: the eye's place, and how deep it is in a cloud.
func advance(delta: float, eye: Vector3, in_cloud: float) -> void:
	var flown := Vector2(eye.x-origin.x,eye.z-origin.z)/rest_height
	# Into the room's frame, as the sky turns its view (zsRoomDir).
	var yaw: float = scene._celestial.room_yaw if scene.get("_celestial") != null else 0.0
	var room := Vector2(cos(yaw)*flown.x-sin(yaw)*flown.y,sin(yaw)*flown.x+cos(yaw)*flown.y)
	var height := maxf(eye.y-SEA_Y,2.0)/rest_height
	var part := smoothstep(PART_FROM,PART_FULL,eye.y) if lower == null else 0.0
	var k := 1.0-exp(-delta/EASE)
	flight = Vector4(room.x,room.y,height,lerpf(flight.w,part,k))
	var sea_vapour: float = smoothstep(VAPOUR_FROM,VAPOUR_FULL,eye.y)*(1.0-0.6*part) if lower == null else SkyBelow.band(eye.y)
	vapour = lerpf(vapour,clampf(maxf(in_cloud,sea_vapour),0.0,1.0),k)
	if lower != null:
		# Across the line only ever under a white-out.
		if lower.cross(eye.y): vapour = maxf(vapour,SkyBelow.SNAP)
		var islands: Node = get_parent().get("islands") if get_parent() != null else null
		var swaps: Variant = islands.get("origin") if islands != null else null
		lower.follow(eye,swaps if swaps is Vector3 else Vector3.ZERO,delta)
	_publish()

## While no glide is on: the sea eases back to rest and the vapour clears.
func _process(delta: float) -> void:
	if active: return
	if _settling <= 0.0:
		_publish_overview()
		return
	_settling = maxf(0.0,_settling-delta)
	var k := 1.0-exp(-delta/(SETTLE*0.3)) if _settling > 0.0 else 1.0
	flight = flight.lerp(Vector4(0.0,0.0,1.0,0.0),k)
	vapour = lerpf(vapour,0.0,k)
	haze = lerpf(haze,0.0,k)
	_publish()

## The build view's mountains' haze (SkyHaze `overview`), each frame the
## glide is off: the cloud sea's style may change under it.
func _publish_overview() -> void:
	var view: Variant = scene.get("_display_fog") if scene != null else null
	if view == null: return
	SkyHaze.overview(view.blend,_sea(),Vector3.ZERO)

## The sky's cloud sea: (strength, style).
func _sea() -> Vector2:
	var environment: Variant = scene.get("_environment") if scene != null else null
	var sky: ShaderMaterial = environment.sky.sky_material as ShaderMaterial if environment != null and environment.sky != null else null
	if sky == null: return Vector2.ZERO
	var strength: Variant = sky.get_shader_parameter("cloud_sea")
	var style: Variant = sky.get_shader_parameter("cloud_sea_style")
	return Vector2(0.0 if strength == null else float(strength),0.0 if style == null else float(style))

func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_sea_flight",flight)
	var islands: Node = get_parent().get("islands") if get_parent() != null else null
	var view: Variant = scene.get("_display_fog") if scene != null else null
	var blend: ShaderMaterial = view.blend if view != null else null
	var eye: Vector3 = scene.camera.global_position if scene != null and scene.get("camera") != null else Vector3.ZERO
	var sea := Vector2.ZERO
	var environment: Variant = scene.get("_environment") if scene != null else null
	var sky: ShaderMaterial = environment.sky.sky_material as ShaderMaterial if environment != null and environment.sky != null else null
	if sky != null:
		var strength: Variant = sky.get_shader_parameter("cloud_sea")
		var style: Variant = sky.get_shader_parameter("cloud_sea_style")
		sea = Vector2(0.0 if strength == null else float(strength),0.0 if style == null else float(style))
	var peaks: Node = islands.get("peaks") if islands != null else null
	var isles: Node = islands.get("isles") if islands != null else null
	# The ranges' and the forested isles' spots, nearest first.
	var spots: Array = peaks.haze_spots(eye) if peaks != null else []
	if isles != null:
		spots.append_array(isles.haze_spots(eye))
		spots.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(b.x-eye.x,b.y-eye.z).length())
	# The world's middle, for the mountain ring's skyline (scripts/sky_world.gd).
	var middle: Variant = islands.get("origin") if islands != null else null
	var ring := SkyHaze.ring_spot(middle) if middle is Vector3 else Vector4.ZERO
	var below := 1.0 if lower != null and lower.below else 0.0
	SkyHaze.publish(haze,blend,sea,SkyHaze.emerging(islands,eye) if islands != null and haze > 0.0 else [],spots,ring,below)
	if lower != null: _overcast(sky,below)
	if _veil == null: return
	_veil.visible = vapour > 0.003
	(_veil.material as ShaderMaterial).set_shader_parameter("amount",vapour)

## Under the cloud (`below` 1) the sky is the overcast, and the stars and
## the planet (scripts/sky_objects.gd) are put away.
func _overcast(sky: ShaderMaterial, below: float) -> void:
	if sky != null: sky.set_shader_parameter("below_world",below)
	var lighting: Variant = scene.get("_lighting") if scene != null else null
	var objects: Variant = lighting.get("sky_objects") if lighting is Object else null
	if objects is Node3D: (objects as Node3D).visible = below < 0.5
