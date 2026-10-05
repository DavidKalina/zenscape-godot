extends RefCounted
## The plate's size, in one place. The land is a square grid of this extent
## in plate-local XZ, middle at the origin; an island's outline is cut from
## it. Everything that needs the land's reach derives it from here.

const HALF := 14.0
const SIZE := HALF * 2.0
## The ground and stream maps the shaders read reach this far each way.
const MAP_HALF := HALF + 2.0
