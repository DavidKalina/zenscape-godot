extends RefCounted
## The wilderness's placed sites: its hand list (docs/design/endless-flight/
## wilderness-kit.md, "How a region is made"; read by scripts/endless/
## placed_sites.gd). Seed 1's land.
##
## Each site: [handle, kind, skin, x, z, heading, params]
##   handle   `<route>/<piece>` (AGENTS.md, Handles): stable once written; the
##            layout file (layouts/endless_flight.json) keys its moves and
##            deletions on it
##   kind     a name in scripts/endless/kinds/kinds.gd
##   skin     the kind's skin ("" its plain one)
##   x, z     world metres
##   heading  degrees, the piece's yaw: 0 faces north (-Z), 90 west (-X)
##   params   the kind's own, and the reader's:
##              y      world height of the foot (else the land's under x, z)
##              lift   m over the land (with no y)
##              reach  m from the eye it is built within (else 2600)
##              clear  m round it kept clear of trees, rocks and generated
##                     sites
##
## The markers stand where the lanes will put their pieces (spec-wild-kit.md):
## the lanes swap each for their kind and keep its handle.

const SITES := [
	# The fast meadow (m03): open and flat some 400 m east-west and 250 m
	# north-south; a river runs past 120 m east. The standing-stone ring.
	["wild/meadow_ring","marker","",770.0,70.0,0.0,{}],
	# The same meadow's south edge, 40 m out from the treeline the herd bolts
	# from; facing east, down the meadow's length. The elk herd
	# (spec-wild-kit-elk.md; --elk=off: its marker).
	["wild/meadow_herd","ground_escort","elk",660.0,145.0,-90.0,{}],
	# The inlet's east shore (m00), 100 m south of the start: a flat beach
	# 2-3 m over the sea, south of the river mouth at (-10, 50); along the
	# shore (NNW). The shipwreck's ribs.
	["wild/inlet_wreck","marker","",25.0,100.0,30.0,{}],
	# The river (m08-m10) where its west bank rises steeply, 60-75 m in 50 m,
	# with the water 30-50 m out from its foot; facing the river (east). The
	# waterfall.
	["wild/river_falls","marker","",1940.0,-25.0,-100.0,{}],
]
