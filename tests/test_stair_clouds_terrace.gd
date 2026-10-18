extends "res://tests/test_terrace_rock.gd"
## The Stair to the Clouds mesa (studies/stair_clouds_isle.tscn, built on
## scripts/kit_isle/terrace_rock.gd), headless: the terrace check
## (tools/terrace_check.gd) over the mesa with its eight grand stairs seated
## in their cuts finds no see-in gap, no sight through rock, no floor hole
## and no collision off the drawn faces.
##   godot --headless --path . --script tests/test_stair_clouds_terrace.gd

func scene() -> String: return "res://studies/stair_clouds_isle.tscn"
func label() -> String: return "stair to the clouds mesa"
