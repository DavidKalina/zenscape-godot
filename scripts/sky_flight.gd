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
var _settling := 0.0
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
	_publish()

## The islands swapped: the world moved by `by`, the eye with it.
func move(by: Vector3) -> void:
	origin += by

func stop() -> void:
	active = false
	_settling = SETTLE

## Each frame of the glide: the eye's place, and how deep it is in a cloud.
func advance(delta: float, eye: Vector3, in_cloud: float) -> void:
	var flown := Vector2(eye.x-origin.x,eye.z-origin.z)/rest_height
	# Into the room's frame, as the sky turns its view (zsRoomDir).
	var yaw: float = scene._celestial.room_yaw if scene.get("_celestial") != null else 0.0
	var room := Vector2(cos(yaw)*flown.x-sin(yaw)*flown.y,sin(yaw)*flown.x+cos(yaw)*flown.y)
	var height := maxf(eye.y-SEA_Y,2.0)/rest_height
	var part := smoothstep(PART_FROM,PART_FULL,eye.y)
	var k := 1.0-exp(-delta/EASE)
	flight = Vector4(room.x,room.y,height,lerpf(flight.w,part,k))
	var sea_vapour := smoothstep(VAPOUR_FROM,VAPOUR_FULL,eye.y)*(1.0-0.6*part)
	vapour = lerpf(vapour,clampf(maxf(in_cloud,sea_vapour),0.0,1.0),k)
	_publish()

## While no glide is on: the sea eases back to rest and the vapour clears.
func _process(delta: float) -> void:
	if active or _settling <= 0.0: return
	_settling = maxf(0.0,_settling-delta)
	var k := 1.0-exp(-delta/(SETTLE*0.3)) if _settling > 0.0 else 1.0
	flight = flight.lerp(Vector4(0.0,0.0,1.0,0.0),k)
	vapour = lerpf(vapour,0.0,k)
	_publish()

func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_sea_flight",flight)
	if _veil == null: return
	_veil.visible = vapour > 0.003
	(_veil.material as ShaderMaterial).set_shader_parameter("amount",vapour)
