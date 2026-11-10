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
	# The escarpment over the river bend north-east of the start, facing the
	# meadow in the bend (north-west). The wall stands 80-115 m over the
	# river's terrace; behind its crest a hollow in the high ground holds a
	# lake (about 23,000 m2, 19 m at its deepest), its level just under the
	# saddle where it would spill over the wall. The waterfall (kinds/
	# curtain.gd, its land curtain_land.gd) stands under that saddle: a bay
	# cut 42 m back into the wall, the lip 69.3 m over the foot; the lake
	# leaves by a short outlet through a notch in the saddle, down two steps
	# and a small rock pool to the lip (its levels under the land's own, so a
	# move in the layout file wants them again, and the lake's shore: both are
	# the hollow's). An uneven pool at the face's foot, an outflow winding to
	# the river. No cave. The clear takes the trees off the bay, its rim and
	# the pool; `clears` off the lake.
	["wild/river_falls","curtain","waterfall",520.0,-654.0,45.0,{"clear":115.0,"y":-12.0,"cave":false,"back":42.0,"lip":69.3,"half_back":34.0,"half_front":40.0,"round":22.0,"flare":0.3,"pool_r":18.0,"pool_rf":12.0,"pool_depth":1.4,"lip_half":10.0,"fan":0.0,"out_under":5.4,"stream":[[6,-100,81.5,3.0],[3,-90,81.45,2.6],[1,-83,81.3,2.2],[-1,-80.5,80.9,2.3],[-2,-77.5,79.0,2.6],[-5,-73,78.8,4.2],[-4,-67,78.7,3.6],[-1,-62.5,78.5,2.2],[-2,-59.5,78.2,2.3],[-3,-55,76.5,2.5],[-3,-52.5,72.5,2.8],[-1,-49,70.6,3.0],[-3,-45.5,70.0,2.3],[-2,-42,69.3,2.5]],"outflow":[[0,-20,0,3.0],[7,-8,0,3.2],[3,4,0,3.4],[-8,14,0,3.6],[-11,26,0,3.8],[-3,37,0,4.0],[5,47,0,4.2],[3,58,0,4.6],[0,67,0,5.0]],"lake":{"level":81.5,"shore":[[-46.7,-198.7],[-70.0,-196.6],[-76.4,-190.2],[-87.0,-200.8],[-93.3,-198.7],[-99.7,-205.1],[-103.9,-200.8],[-112.4,-209.3],[-127.3,-194.5],[-118.8,-181.7],[-123.0,-177.5],[-112.4,-166.9],[-118.8,-156.3],[-112.4,-137.2],[-70.0,-82.0],[-63.6,-88.4],[-53.0,-82.0],[-27.6,-86.3],[-21.2,-79.9],[25.5,-79.9],[36.1,-107.5],[59.4,-92.6],[76.4,-96.9],[89.1,-118.1],[89.1,-126.6],[146.4,-175.4],[140.0,-181.7],[144.2,-190.2],[154.9,-192.3],[169.7,-207.2],[173.9,-219.9],[161.2,-232.6],[137.9,-226.3],[125.2,-239.0],[108.2,-243.2],[91.2,-230.5],[57.3,-256.0],[42.4,-249.6],[27.6,-272.9],[-17.0,-236.9],[-14.8,-230.5],[-27.6,-213.5],[-23.3,-200.8]]},"clears":[[42.4,-179.6,74.0],[-38.2,-141.4,61.1],[108.2,-194.5,38.3],[12.7,-94.8,18.2],[-91.2,-156.3,27.7]]}],
]
