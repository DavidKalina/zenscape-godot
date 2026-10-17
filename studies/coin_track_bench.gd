extends "res://studies/motif_yard.gd"
## The coin track bench: the coin track kit (scripts/kit_isle/coin_track.gd)
## and the rolling coin's track mode (scripts/enemies/rolling_coin.gd,
## scripts/enemies/coin_circuit.gd) on the plainest place that has every
## piece: two flat discs, one loop (studies/coin_track_bench_place.gd), two
## coins lapping. A test yard, not a level: the motif yard's stage (its
## pilot, field, breaks and R reset) with this place in it in place of a
## registry motif.
##   R   back at the start, the coins minted again
##   F1  numbers (each coin's laps, flights caught and missed)
##   godot --path . res://studies/coin_track_bench.tscn -- --no-title
##     [--hunt]   the coins may leave through the north gate after him
##     [--sky]    the sky's clouds, motes and gulls too
const Place = preload("res://studies/coin_track_bench_place.gd")

func _ready() -> void:
	motif_slug = "coin_track_bench"
	motif_script = Place
	super._ready()
