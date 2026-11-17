extends RefCounted
## Written by tools/map_bake.py with the picture beside it: what the map
## page's land picture (assets/ui/map/land_seed1.png) covers. Bake again
## rather than edit.

const PICTURE := "res://assets/ui/map/land_seed1.png"
## The land it was drawn from: this seed, the profile holding the start.
const SEED := 1
const WORLD := "wilderness"
## The picture's box, world x and z (m): x right, z down.
const BOX := Rect2(-7500.0,-7500.0,13000.0,13000.0)
## Where a game starts (the title's spot).
const START := Vector2(164.8,-32.4)
