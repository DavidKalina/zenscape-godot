extends RefCounted
## A disturbance: something the player did that creatures may notice
## (docs/scenic/life.md "Noticing"). Player actions raise one, once, where
## and as hard as they happened; scripts/life_notice.gd answers it. Nothing
## scans for the hand each frame: the event is the whole signal.
##
## `point` is global, `radius` metres, `strength` 0..1. `kind`:
## - "gust": a gust sent (scripts/wind_gust.gd `release`). `detail` holds its
##   front: "shape" ("lane" or "burst"), "way" (global unit heading, zero for a
##   burst), "from" and "span" (metres along the way where the head starts and
##   how far it goes), "run" and "wind_up" (seconds), and "across" (metres
##   either side of the line the air reaches). The head is at
##   from+span*(1-(1-u)²) at wind_up+u*run seconds. A breeze gust front
##   (scripts/shared/gust_fronts.gd) sets "steady": its head runs at an even pace,
##   from+span*u, and keeps its strength the whole way.
## - "poke": a tap on the clay (scripts/land_clay.gd `_poke`).
## - "night", "dawn": a snap of the fingers turned the hour
##   (scripts/void_snap.gd); `point` is the look target.
## - "figure": the wanderer set down, or a stride of its walk
##   (scripts/wanderer_eye.gd); `strength` is its pace, a run 1.

class Hub:
	signal raised(point: Vector3, radius: float, strength: float, kind: String, detail: Dictionary)

static var _hub: Hub
## For probes: disturbances raised so far, by kind.
static var counts := {}

static func hub() -> Hub:
	if _hub == null: _hub = Hub.new()
	return _hub

static func raise(point: Vector3, radius: float, strength: float, kind: String, detail := {}) -> void:
	counts[kind] = int(counts.get(kind,0))+1
	hub().raised.emit(point,radius,clampf(strength,0.0,1.0),kind,detail)
