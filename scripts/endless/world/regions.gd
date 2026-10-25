extends RefCounted
## The regions registry: the world profiles the patchwork world
## (--world=regions, scripts/endless/world/profiles/regions.gd) stitches
## together, each by its share of the cells.
##
## Registering a region: write scripts/endless/world/profiles/<id>.gd as for
## any world, then add one entry here. Nothing else.
##   id     the profile's id (profiles/<id>.gd)
##   share  its share of the cells (any positive number; the shares are
##          normalised)
##   start  whether the start may lie in it (at least one entry needs it)
## --regions=id:share[:start],... replaces the list for a run (e.g.
## --regions=wilderness:2:start,overgrown:1).

const REGISTRY := [
	{"id":"wilderness","share":1.0,"start":true},
	{"id":"overgrown","share":1.0,"start":false},
]

## A region's mean width (m; --region-size=): the cells' spacing. About two
## minutes across at boost.
const SIZE := 6000.0
## The border band's width (m; --region-blend=): the land, flora, paint and
## sky ease from one region to the next over it.
const BLEND := 1500.0
