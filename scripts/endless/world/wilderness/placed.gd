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
##              clear  m round it kept clear of trees, rock groups, arches
##                     and the cut sites (halls, splits, tunnels):
##                     scripts/endless/placed_list.gd
##
const SITES := [
	# The river (m08-m10) where its west bank rises steeply, 60-75 m in 50 m,
	# with the water 30-50 m out from its foot; facing the river (east). The
	# waterfall (kinds/curtain.gd, its land curtain_land.gd): a face cut 48 m
	# back into the bank, the lip 61.5 m over the foot, a tarn on the ridge
	# behind; a cave from behind the sheet through the hill to a gully down
	# its south flank. The clear takes the trees off the alcove, pool,
	# stream and the cave's ground.
	["wild/river_falls","curtain","waterfall",1940.0,-25.0,-100.0,{"clear":125.0,"y":-21.5}],
]
