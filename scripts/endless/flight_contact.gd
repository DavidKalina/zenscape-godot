extends RefCounted
## The land is real (endless flight, the weighted presets: scripts/
## flight_weight.gd). What the plane's move ran into (SkyPlane `contact`:
## the ground, a tree's crown, a ruin, a face it was turned along, an
## underside, the water) or a body point in the land, a tree or a wall
## though its middle is clear (NearMiss `touching`: a wingtip), graded:
##
## - a crash: going into the surface faster than CRASH_INTO m/s at more than
##   CRASH_ANGLE radians to it (a dive into the ground, nose first into a
##   cliff or a trunk). The study puts the plane back a little behind and
##   above (studies/endless_flight.gd `crash`).
## - a scrape: anything shallower. It keeps SCRAPE_KEEP of its speed (less
##   SCRAPE_COST per m/s it went into the surface, never under SCRAPE_LEAST),
##   its path is turned off the surface and it is shoved out at KICK.x m/s
##   plus KICK.y per m/s into it (SkyPlane `scrape`). For GRACE s after one
##   another touch only crashes.
##
## A spruce is neither: the plane knocks it down (scripts/endless/
## tree_knock.gd, before the move; a tree touch that still gets here is
## handed to TreeKnock `at_hit` and comes back as "knock").
##
## The wheels' own touches are left to the hand landing: a touch of the land
## no faster along it than LAND_MOST m/s (ManualLanding `land_most`; Brake's
## 13.2 under it) is a landing as ever, and the water ridden that slowly is
## ridden as before. Nothing here acts in `off`.
##
## The surface's normal: the ground's own slope (from the study's
## `plane_ground` either side, NORMAL_STEP m apart) for a ride; a brushed
## face's way out, or the land's slope where that is steep (a cliff); down
## under an underside; up on the water.

const SkyGlide = preload("res://scripts/sky_glide.gd")

const LAND_MOST := 16.0
const CRASH_ANGLE := 0.42
const CRASH_INTO := 7.0
const SCRAPE_KEEP := 0.88
const SCRAPE_COST := 0.012
const SCRAPE_LEAST := 0.6
const KICK := Vector2(2.2,0.35)
const GRACE := 0.45
const NORMAL_STEP := 0.6
## A brushed face is the land's slope where that is steeper than this (its
## normal's up part).
const CLIFF := 0.7

var _grace := 0.0
## Counted for the drivers and the numbers.
var scrapes := 0
var crashes := 0

## Ready for a fresh flight.
func reset() -> void:
	_grace = 0.0

## One frame, after the plane's step and NearMiss `measure`. `game` is the
## endless flight study. Returns {} or one of "scrape" / "crash", each
## {at, normal, what (land, water, tree, stone), into (m/s), angle (rad),
## speed (m/s before)}; or "knock" (TreeKnock `at_hit`) for a tree.
func step(delta: float, game: Node3D, touching: Dictionary) -> Dictionary:
	_grace = maxf(0.0,_grace-delta)
	var plane = game.plane
	var landing = game.hand_landing
	if not bool(landing.flying()): return {}
	var c: Dictionary = plane.contact
	var hit := {}
	if not c.is_empty(): hit = _from_contact(c,game)
	if hit.is_empty() and not touching.is_empty():
		hit = {"at":touching.at,"normal":touching.normal,"what":touching.what,"velocity":plane.velocity}
	if hit.is_empty(): return {}
	# A tree (weighted) is knocked down, not grazed or crashed into
	# (scripts/endless/tree_knock.gd; this is a touch its own tries missed).
	if str(hit.what) == "tree" and game.get("knock") != null:
		var k: Dictionary = game.knock.at_hit(game,hit.at)
		if not k.is_empty(): return {"knock":k}
	var v: Vector3 = hit.velocity
	var n: Vector3 = hit.normal
	var speed := v.length()
	if speed < 0.1: return {}
	var into := -v.dot(n)
	var angle := asin(clampf(into/speed,-1.0,1.0))
	var out := {"at":hit.at,"normal":n,"what":hit.what,"into":into,"angle":angle,"speed":speed}
	if into > CRASH_INTO and angle > CRASH_ANGLE:
		crashes += 1
		return {"crash":out}
	if _grace > 0.0: return {}
	var keep := clampf(SCRAPE_KEEP-SCRAPE_COST*maxf(into,0.0),SCRAPE_LEAST,1.0)
	plane.scrape(n,keep,KICK.x+KICK.y*maxf(into,0.0))
	_grace = GRACE
	scrapes += 1
	out["keep"] = keep
	return {"scrape":out}

## The contact the plane's move made, as a hit, or {} where it is the
## landing's (a slow touch of the land, slow on the water).
func _from_contact(c: Dictionary, game: Node3D) -> Dictionary:
	var plane = game.plane
	var v: Vector3 = c.velocity
	var flat := Vector2(v.x,v.z).length()
	var p: Vector3 = plane.position
	var kind := str(c.kind)
	match kind:
		"water":
			if flat <= LAND_MOST: return {}
			return {"at":p+Vector3.DOWN*SkyGlide.SKIM,"normal":Vector3.UP,"what":"water","velocity":v}
		"under":
			return {"at":p,"normal":Vector3.DOWN,"what":"stone","velocity":v}
		"brush":
			var n: Vector3 = c.get("normal",Vector3.ZERO)
			var slope := _slope(game,p)
			if slope.y < CLIFF or n == Vector3.ZERO: n = slope
			# What it was turned off: just inside the face it was put back out of.
			var at := p-n*0.8
			return {"at":at,"normal":n,"what":_what(game,at),"velocity":v}
	# A ride onto what is under it: the land's own touch if slow enough.
	var what := _what(game,p)
	if what == "land" and flat <= LAND_MOST and not is_nan(float(game.floor_at(Vector2(p.x,p.z)))): return {}
	return {"at":p+Vector3.DOWN*SkyGlide.SKIM,"normal":_slope(game,p),"what":what,"velocity":v}

## The normal of the top under `p` (the study's `plane_ground`), from its
## heights NORMAL_STEP m either side.
func _slope(game: Node3D, p: Vector3) -> Vector3:
	var e := NORMAL_STEP
	var dx := _top(game,p+Vector3(e,0,0))-_top(game,p-Vector3(e,0,0))
	var dz := _top(game,p+Vector3(0,0,e))-_top(game,p-Vector3(0,0,e))
	if is_nan(dx) or is_nan(dz) or is_inf(dx) or is_inf(dz): return Vector3.UP
	return Vector3(-dx/(2.0*e),1.0,-dz/(2.0*e)).normalized()

func _top(game: Node3D, p: Vector3) -> float:
	var under: Variant = game.plane_ground(p)
	if under is Vector2: return (under as Vector2).x
	if under == null: return NAN
	return float(under)

## What stands at `p`: a tree, stone (an arch, a hall, a bore's rock) or
## the land.
func _what(game: Node3D, p: Vector3) -> String:
	var h: float = game.field.height(p.x,p.z)
	var under: Variant = game.plane_ground(p)
	var top := float((under as Vector2).x) if under is Vector2 else (float(under) if under != null else h)
	if game.trees != null and float(game.trees.top_at(p)) > h+0.5 and absf(float(game.trees.top_at(p))-top) < 1.0: return "tree"
	if top > h+0.5 or bool(game.arches.inside(p)) or bool(game.halls.inside(p)): return "stone"
	return "land"
