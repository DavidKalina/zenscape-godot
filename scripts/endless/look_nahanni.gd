extends RefCounted
## The Nahanni look: a darker, less toy-like land (a northern river valley:
## dark spruce, grey limestone, silty water, cool heavy air). The default
## since 2026-11-27, in every world; --look=old is the look before it (the
## alpine morning, gold sandstone, turquoise water, the spruce at their old
## size). Looks only: the land's shape and what grows where are as they were.
##
## What it changes:
##   the mood     SceneLookPresets "nahanni" (sky, haze, grass, foliage, rock
##                and water colours, exposure) at HOUR, a low morning sun
##   the trees    the spruce meshes TREES times taller and wider (HeroTrees.
##                spruce_scale), so the spacing, sprites and solids follow
##   the haze     all sky by HAZE_END of the usual distance (EndlessLook)
##   the paint    the wilderness's sea tints and rock (paint_over)
##
## Knobs, with or without the look: --tree-size=H[,W] (times the usual
## spruce), --haze-end=X (times the usual haze distance).

const LaunchArgs = preload("res://scripts/launch_args.gd")

const OFF := "--look=old"
const MOOD := "nahanni"
const HOUR := 7.3
## Height and width, times the usual spruce.
const TREES := Vector2(1.8,1.2)
const HAZE_END := 0.45
## In the world --world=nahanni the haze stands farther: the rim of
## mountains has to show across the valley.
const WORLD := "--world=nahanni"
const WORLD_HAZE_END := 0.85

static func wanted() -> bool:
	return not OFF in LaunchArgs.user_args()

## The spruce meshes' scale over their own (x and z the width, y the height).
static func tree_scale() -> Vector3:
	var s := TREES if wanted() else Vector2.ONE
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--tree-size="):
			var p := a.get_slice("=",1).split(",")
			var h := maxf(p[0].to_float(),0.1)
			s = Vector2(h,maxf(p[1].to_float(),0.1) if p.size() > 1 else h)
	return Vector3(s.y,s.x,s.y)

## The haze's end, times the usual.
static func haze_end() -> float:
	var e := (WORLD_HAZE_END if WORLD in LaunchArgs.user_args() else HAZE_END) if wanted() else 1.0
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--haze-end="): e = clampf(a.get_slice("=",1).to_float(),0.1,4.0)
	return e

## The wilderness's paint (WorldProfile.paint) with this look over it.
static func paint_over(paint: Dictionary) -> void:
	if not wanted(): return
	paint["mood"] = MOOD
	paint["hour"] = HOUR
	# The water: a silty grey-green, never the alpine turquoise.
	var sea: Dictionary = paint.get("sea",{})
	sea.merge({"tint_shallow":Color(0.40,0.56,0.47),"tint_mid":Color(0.15,0.31,0.28),"tint_deep":Color(0.07,0.17,0.19),"tint_abyss":Color(0.03,0.09,0.12)},true)
	paint["sea"] = sea
	# The rock: grey limestone, most of its sandstone gold gone, a shade darker.
	# The grass: darker and part-way to a dull olive, so it stops reading as lawn.
	var ground: Dictionary = paint.get("ground",{})
	ground.merge({"rock_hue":Vector3(0.87,0.87,0.85),"rock_tint":Vector3(0.66,0.67,0.70),
		"carpet_hue":Vector3(0.46,0.47,0.27),"carpet_tone_top":Vector3(0.82,0.86,0.80),"carpet_tone_low":Vector3(0.80,0.84,0.78),
		"carpet_under_tone":Vector3(0.82,0.86,0.80)},true)
	paint["ground"] = ground
