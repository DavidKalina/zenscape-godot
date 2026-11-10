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
	# The escarpment over the river bend south-east of the start, facing the
	# meadow in the bend (north-west). The wall stands 80-115 m over the
	# river's terrace, with a long trough behind its crest and the land
	# rising past that to 140 m; the trough's high point is behind the fall,
	# so its stream can come from the high ground without crossing lower
	# land. The waterfall (kinds/curtain.gd, its land curtain_land.gd): an
	# amphitheatre cut 75 m back into the wall, the lip 81.4 m over the foot
	# at the bottom of a notch through the crest; its stream winds 514 m
	# down from the high ground behind (the levels the land's own under it:
	# the lowest ground upstream of each point less 1.6 m); an uneven pool
	# at the face's foot, an outflow winding to the river. No cave. The clear
	# takes the trees off the amphitheatre, its rim and the pool.
	["wild/river_falls","curtain","waterfall",622.1,-764.0,45.0,{"clear":125.0,"y":-12.0,"cave":false,
		"back":75.0,"lip":81.4,"half_back":62.0,"half_front":70.0,"round":45.0,"flare":0.5,"pool_r":22.0,"pool_rf":14.0,"pool_depth":1.4,
		"lip_half":13.0,"out_under":6.3,
		"stream":[[40,-565,124.6,2],[44,-551.5,119.7,2.1],[47.9,-537.7,119.6,2.1],[50,-525,119.6,2.2],[48.3,-512.3,119.6,2.3],[44.8,-500.4,107.1,2.4],[44.3,-488.3,103.7,2.4],[47.2,-474.6,103.7,2.5],[50.8,-462.7,103.7,2.6],[54.1,-451,103.7,2.6],[57.5,-439.1,103.7,2.7],[61,-427.5,103.7,2.8],[64,-415.9,98.6,2.8],[66.9,-404.1,98.6,2.9],[69.3,-392.2,98.6,3],[71.2,-380.2,98.6,3],[72.9,-368.1,98.6,3.1],[73.9,-355.9,98.6,3.2],[73.7,-343.7,98.6,3.2],[72.5,-331.3,98.6,3.3],[70,-318,90,3.4],[66.1,-305.4,89.5,3.5],[61,-293.9,88.3,3.6],[54.8,-283.2,88.3,3.7],[47.7,-273,88.3,3.8],[40.2,-263.3,88.3,3.8],[32.3,-254.2,88.3,3.9],[24.9,-244.3,88.3,4],[18.3,-233.9,83.6,4.1],[12.5,-222.3,81.4,4.2],[8.7,-209,81.4,4.2],[6.7,-195.3,81.4,4.3],[5.3,-182.3,81.4,4.4],[3.8,-168.9,81.4,4.3],[2.6,-155,81.4,4.1],[1.7,-142.6,81.4,4.2],[1,-130,81.4,4.8],[0.6,-117.1,81.4,6.3],[0.3,-102.9,81.4,8.4],[0.1,-89.4,81.4,10.6],[0,-77.3,81.4,12.6],[0,-75,81.4,13]],
		"outflow":[[0,-58,0,3.0],[10,-44,0,3.2],[14,-30,0,3.4],[4,-18,0,3.6],[-10,-8,0,3.8],[-16,6,0,4.0],[-8,20,0,4.2],[6,30,0,4.4],[12,44,0,4.6],[6,58,0,4.8],[-2,72,0,5.0]]}],
]
