extends Node3D
## The lower world under the cloud sea (`--below`, a prototype): dived
## down through the sea, the plane comes out under an overcast cloud
## ceiling over an endless ocean, the mountain ranges standing down into
## it, and climbs back up through the cloud to the islands.
##
## The two worlds never show together. Above, the sea is the sky's painted
## one (shaders/sky_cloud_sea.gdshaderinc), which never parts under --below
## (scripts/sky_flight.gd); the swap is made deep in the sea's vapour
## (`band`), under a full white-out, with CROSS metres of play each way so
## it never flickers at the line (`cross`). Below, the sky is the overcast
## (shaders/reference_sky.gdshader `below_world`), the cloud's underside is
## a real plane at the sea's height (`ceiling`), the ranges' rock runs on
## down past it (scripts/sky_peaks.gd `open_sea`), the haze is the
## overcast's pearl and thickest by the water (scripts/sky_haze.gd), and the
## ocean (`ocean`) lies OCEAN down, the glide's floor just over it
## (SkyGlide `floor_y`, `water`).
##
## The ocean and the ceiling follow the eye (`follow`), so they never end;
## their ripples and billows are laid in home coordinates (the islands'
## `origin` taken off), so a swap that moves the world moves them with it.
##
## OCEAN is -300: the ring's runs (most of the ranges, scripts/sky_world.gd
## `layout`) end at about BASE (-280) in their own heights and stand about
## there in the world, and its massifs reach -340, so at -300 most rock
## meets the water as it was built, a little stretched; every range's flanks
## from the sea down are drawn out so its foot lies SINK under the water
## (SkyPeaks `sunk`), the low ridges and foothills most. It leaves about 150
## clear metres between the vapour and the water to fly in.

## The cloud sea's top (scripts/sky_flight.gd SEA_Y), where the ceiling is.
const SEA := -105.0
## The ocean's height, the glide's floor over it, and how far under the
## water every range's foot is drawn down to.
const OCEAN := -300.0
const FLOOR := OCEAN+6.0
const SINK := 30.0
const FOOT := OCEAN-SINK
## The swap's play each way of SEA (m), and the vapour it is always made
## under (it snaps up to at least this as it happens).
const CROSS := 3.0
const SNAP := 0.97
## The sea's vapour round the swap: coming in from x down to y, whole to z,
## gone by w (m).
const BAND := Vector4(-65.0,-95.0,-115.0,-145.0)
## Half the ocean's and the ceiling's span (m): SkyWorld VIEW_FAR.
const REACH := 9000.0

## Whether this run has the lower world: `--below`.
static var _on := -1
static func on() -> bool:
	if _on < 0: _on = int("--below" in OS.get_cmdline_user_args())
	return _on == 1

## True while the eye is below the cloud.
var below := false
## The ranges (scripts/sky_peaks.gd), opened to the lower world while below.
var peaks: Node3D
var ocean: MeshInstance3D
var ceiling: MeshInstance3D

func _init() -> void:
	name = "SkyBelow"
	ocean = _plane("Ocean",preload("res://shaders/sky_below_ocean.gdshader"))
	ceiling = _plane("Ceiling",preload("res://shaders/sky_below_ceiling.gdshader"))
	_show()

func _plane(label: String, shader: Shader) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE*REACH*2.0
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("skip_reflection",true)
	add_child(node)
	return node

## How white the sea's vapour is at height `y` (0 to 1).
static func band(y: float) -> float:
	return minf(smoothstep(BAND.x,BAND.y,y),smoothstep(BAND.w,BAND.z,y))

## Each frame: crosses to below under SEA-CROSS and back above over
## SEA+CROSS. True on the frame it crosses.
func cross(y: float) -> bool:
	var was := below
	if below and y > SEA+CROSS: below = false
	elif not below and y < SEA-CROSS: below = true
	if below == was: return false
	_show()
	return true

## Back above, as at the start of a glide.
func reset() -> void:
	if not below: return
	below = false
	_show()

## The ocean and the ceiling under and over `eye` (global); `origin` is the
## islands' swaps added up (SkyIslands `origin`), which their patterns take
## off.
func follow(eye: Vector3, origin: Vector3) -> void:
	ocean.position = Vector3(eye.x,OCEAN,eye.z)
	ceiling.position = Vector3(eye.x,SEA,eye.z)
	for node in [ocean,ceiling]:
		((node.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter("home",Vector2(origin.x,origin.z))

func _show() -> void:
	ocean.visible = below
	ceiling.visible = below
	if peaks != null and peaks.has_method("open_sea"): peaks.open_sea(below)
