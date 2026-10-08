extends RefCounted
## Mountains, a landform of the lower world's archipelago: an island that is
## a massif rising from the sea, the landmark seen from far across the
## water and flown round and over, not just past. Its recipe is a sky
## islet's (scripts/sky_islet.gd, `author`), its massif raised by scripts/
## mountain_massif.gd: two summits on a ridge with a col between them low
## and wide enough to fly through, a corrie under the main summit's headwall
## opening down a glen to the shore, aretes and gullies, scree fans; green
## lower slopes, conifers to a ragged treeline, dark faceted basalt over
## it, snow on the summits; a hut on the col, its window lit at night.
##
## Its summit stands SUMMIT m over its rim (the sea, once the lower world
## stands it in the water), never higher, well under the cloud ceiling.
## Its grid is coarser than an islet's (STEP), so its faces stay few at its
## size; the island's own planting is a few meadow trees and flowers, the
## massif plants its own conifers.

const NAME := "mountains"
const ACROSS := Vector2(55.0,100.0)
## The main summit's height over the rim (m): at least, at most. Its height
## is the island's radius times its stature, held within these; tune the
## most here to keep the summits clear of the cloud ceiling.
const SUMMIT := Vector2(36.0,85.0)
## The grid's step (m; an islet's is 2/3).
const STEP := 1.333
## The earth sides' look (scripts/rock_looks.gd), and how much deeper than
## its own the rock hangs.
const ROCK := {"palettes":["basalt","slate","basalt_warm"],"tone":Vector2(0.82,1.0)}
const KEEL := Vector2(1.0,1.3)

## The recipe for a mountain island `across` m wide (ACROSS), drawn by `rng`.
static func recipe(rng: RandomNumberGenerator, across: float) -> Dictionary:
	var size := clampf(across,ACROSS.x,ACROSS.y)
	var palettes: Array = ROCK.palettes
	return {
		"kind":"hills","radius":size*0.5,"step":STEP,"mounds":[],"dome":0.6,
		"massif":{"height":SUMMIT,"hut":rng.randf() < 0.85},
		"trees":Vector2i(3,8),"tree_pool":{"birch":1.0,"tree":0.8,"broadleaf":0.4},"mixed":true,
		"drifts":Vector2i(4,9),"undergrowth":0.6,
		"rock":{"palette":palettes[rng.randi()%palettes.size()],"tone":rng.randf_range(ROCK.tone.x,ROCK.tone.y),"vary":rng.randf()},
		"keel":rng.randf_range(KEEL.x,KEEL.y),
	}
