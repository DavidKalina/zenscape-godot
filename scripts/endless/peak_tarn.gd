class_name PeakTarn
extends RefCounted
## The Peak's tarn look: the ground shader's uniforms for shaders/
## peak_tarn.gdshaderinc (dark still water that mirrors another sky, cracked
## ice at its edge, a shore of wet rock, ice shelf and blown snow), read from
## the massif's own pond entry so it follows the tarn wherever the `peak/tarn`
## handle puts it. Flag: --peak-tarn=0 leaves the old water and shore.
##
## peak_tarn    x z the water's centre, y its level (world), w 1 on
## peak_tarn_a  radius, then lobe 2's share and phase, lobe 3's share
## peak_tarn_b  lobe 3's phase, lobe 5's share and phase, the shore's reach (m)
## peak_tarn_c  the massif's facing (xz)
## (the outline is land_ponds.gd `edge_at`).

const LaunchArgs = preload("res://scripts/launch_args.gd")

## How far past the water's edge the shore's rock and snow reach.
const SHORE_REACH := 40.0

static func wanted() -> bool:
	return not LaunchArgs.user_args().has("--peak-tarn=0")

## The uniforms for `peak`'s tarn (empty when off or no massif).
static func uniforms(peak: RefCounted) -> Dictionary:
	if peak == null or not wanted(): return {}
	var p: PackedFloat32Array = peak.pond
	if p.size() < 12: return {}
	return {
		"peak_tarn":Vector4(p[0],p[1],p[3],1.0),
		"peak_tarn_a":Vector4(p[2],p[5],p[6],p[7]),
		"peak_tarn_b":Vector4(p[8],p[9],p[10],SHORE_REACH),
		"peak_tarn_c":Vector4(peak.facing.x,peak.facing.y,0.0,0.0),
	}

## Sets them on the ground material.
static func apply(peak: RefCounted, ground: ShaderMaterial) -> void:
	if ground == null: return
	var u := uniforms(peak)
	for k: String in u: ground.set_shader_parameter(k,u[k])
