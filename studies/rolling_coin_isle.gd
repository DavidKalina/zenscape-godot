extends "res://studies/inhaler_isle.gd"
## The rolling coin's study: the inhaler head's
## isle (studies/inhaler_isle.gd: the aqueduct isle's turf east of the
## aqueduct, its cover) with the rolling coin (scripts/enemies/
## rolling_coin.gd) alone, no body, and its stone breakable: the cover and
## a few more piers and walls in the way of its charges are kit pieces the
## breakables hub (scripts/breaks/breakables.gd, kit_breaks.gd) breaks
## when the coin rolls into them hard enough (the breaker `coin`; the slam
## breaks them too).
##   R   back to the start, the coin back too (what broke stays broken)
##   F1  numbers (the coin's state, speed, smashes)
##   godot --path . res://studies/rolling_coin_isle.tscn -- --no-title
##     [--head-at=x,z] [--head-knob=<knob>=<value>] (e.g.
##     --head-knob=charge_speed=10) [--breakers=-coin]
const Breakables = preload("res://scripts/breaks/breakables.gd")
const KitBreaks = preload("res://scripts/breaks/kit_breaks.gd")

## More stone in the way of its charges: [piece, seed, (x, z), yaw, weathered].
const MORE := [
	["pier",11,Vector2(114.2,2.6),0.3,0.3],
	["pier",12,Vector2(111.4,7.8),-0.2,0.4],
	["pier",14,Vector2(106.5,0.5),0.5,0.4],
	["wall",13,Vector2(107.5,-6.0),1.2,0.3],
]

var hub: Node3D
var kit_breaks: Node3D

func _ready() -> void:
	_head_kind = "coin"
	super._ready()

func _stand_head() -> void:
	super._stand_head()
	for c: Array in MORE:
		var piece := RuinKit.piece(c[0],c[1],c[4])
		if piece == null: continue
		var at: Vector2 = c[2]
		piece.transform = Transform3D(Basis(Vector3.UP,float(c[3])),Vector3(at.x,_turf_y(at),at.y))
		cover.add_child(piece)
	hub = Breakables.new()
	hub.field = enemies
	hub.sound_hook = _voice
	add_child(hub)
	if not hub.breakers.has(&"coin"): hub.set_breaker(&"coin",true,1.0)
	kit_breaks = KitBreaks.new()
	kit_breaks.name = "KitBreaks"
	kit_breaks.hub = hub
	kit_breaks.field = enemies
	kit_breaks.sound_hook = _voice
	kit_breaks.lost_y = float(lost)
	add_child(kit_breaks)
	var n: int = kit_breaks.adopt(cover)
	hub.others.append(kit_breaks)
	print("rolling coin isle: %d piece(s) breakable" % n)
