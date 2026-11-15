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
	# the river. Behind the water a tunnel (`tunnel`, kinds/curtain_land.gd
	# `tunnels`: a sunk cave of the mountain tunnels, its mouth in the back
	# wall's foot) runs under the lake's west lobe and out to the slope
	# south-east; the fall is wide enough (lip_half) to cover its mouth. The
	# clear takes the trees off the bay, its rim and the pool; `clears` off
	# the lake.
	["wild/river_falls","curtain","waterfall",520.0,-654.0,45.0,{"clear":115.0,"y":-12.0,"cave":false,"tunnel":{"seed":21,"turn":10.0,"length":360.0},"back":42.0,"lip":69.3,"half_back":34.0,"half_front":40.0,"round":22.0,"flare":0.3,"pool_r":18.0,"pool_rf":12.0,"pool_depth":1.4,"lip_half":11.0,"spread":9.0,"thread_gaps":0.4,"fall":{"mist":0.95,"veil_fade":0.9},"fan":0.0,"out_under":5.4,"stream":[[6,-100,81.5,3.0],[3,-90,81.45,2.6],[1,-83,81.3,2.2],[-1,-80.5,80.9,2.3],[-2,-77.5,79.0,2.6],[-5,-73,78.8,4.2],[-4,-67,78.7,3.6],[-1,-62.5,78.5,2.2],[-2,-59.5,78.2,2.3],[-3,-55,76.5,2.5],[-3,-52.5,72.5,2.8],[-1,-49,70.6,3.0],[-3,-45.5,70.0,2.3],[-2,-42,69.3,2.5]],"outflow":[[0,-20,0,3.0],[7,-8,0,3.2],[3,4,0,3.4],[-8,14,0,3.6],[-11,26,0,3.8],[-3,37,0,4.0],[5,47,0,4.2],[3,58,0,4.6],[0,67,0,5.0]],"lake":{"level":81.5,"shore":[[-46.7,-198.7],[-70.0,-196.6],[-76.4,-190.2],[-87.0,-200.8],[-93.3,-198.7],[-99.7,-205.1],[-103.9,-200.8],[-112.4,-209.3],[-127.3,-194.5],[-118.8,-181.7],[-123.0,-177.5],[-112.4,-166.9],[-118.8,-156.3],[-112.4,-137.2],[-70.0,-82.0],[-63.6,-88.4],[-53.0,-82.0],[-27.6,-86.3],[-21.2,-79.9],[25.5,-79.9],[36.1,-107.5],[59.4,-92.6],[76.4,-96.9],[89.1,-118.1],[89.1,-126.6],[146.4,-175.4],[140.0,-181.7],[144.2,-190.2],[154.9,-192.3],[169.7,-207.2],[173.9,-219.9],[161.2,-232.6],[137.9,-226.3],[125.2,-239.0],[108.2,-243.2],[91.2,-230.5],[57.3,-256.0],[42.4,-249.6],[27.6,-272.9],[-17.0,-236.9],[-14.8,-230.5],[-27.6,-213.5],[-23.3,-200.8]]},"clears":[[42.4,-179.6,74.0],[-38.2,-141.4,61.1],[108.2,-194.5,38.3],[12.7,-94.8,18.2],[-91.2,-156.3,27.7]]}],
	# The tarn on the plateau's west edge over the river, 3 km north of the
	# start, facing the river (west). A small hollow in the ridge between the
	# plateau and the river holds a tarn (about 3,800 m2, 9 m at its deepest),
	# its level just under the saddle on its west rim. The fall stands under
	# that saddle: a bay cut 44 m back into the slope, the lip 54 m over the
	# foot; the tarn leaves through the saddle in a short stepped outlet. The
	# pool's outflow runs a few metres to the river. Behind the water a
	# tunnel (a sunk cave, as river_falls') runs straight under the middle of
	# the tarn (28 m of rock under its bed), then bends north-east and back
	# under the plateau to a sinkhole on its east slope, 455 m in all. The
	# clear takes the trees off the bay and its rim; `clears` off the tarn.
	["wild/tarn_falls","curtain","waterfall",508.0,-3018.0,90.0,{"clear":80.0,"y":-22.0,"cave":false,"tunnel":{"seed":51,"turn":0.0,"length":300.0},"back":44.0,"lip":54.0,"half_back":32.0,"half_front":40.0,"round":22.0,"flare":0.3,"pool_r":18.0,"pool_rf":12.0,"pool_depth":1.4,"lip_half":11.0,"spread":9.0,"thread_gaps":0.4,"lip_seed":41.0,"fall":{"mist":0.95,"veil_fade":0.9},"fan":0.0,"out_under":2.5,"stream":[[0,-80,56.0,3.0],[0,-66,56.0,2.8],[1,-57,55.9,2.4],[0,-54,55.8,2.2],[-1,-52,55.0,2.4],[-1,-49,54.9,2.6],[0,-47,54.2,2.6],[0,-44,54.0,2.8]],"outflow":[[0,-20,0,3.0],[3,-8,0,3.2],[1,4,0,3.4],[-2,16,0,3.8]],"lake":{"level":56.0,"shore":[[-0.2,-142.2],[-8.0,-147.0],[-15.6,-145.4],[-22.8,-142.4],[-26.8,-134.7],[-31.4,-129.4],[-33.7,-122.5],[-35.0,-115.9],[-34.6,-109.4],[-34.6,-103.6],[-34.1,-98.2],[-32.3,-93.1],[-31.1,-88.2],[-28.6,-83.7],[-26.8,-78.9],[-28.6,-69.9],[-26.0,-62.8],[-20.9,-57.7],[-14.3,-54.9],[-7.4,-53.0],[-0.2,-53.0],[6.9,-53.0],[14.3,-53.5],[21.0,-56.5],[26.6,-61.2],[29.4,-68.6],[31.4,-75.2],[32.6,-81.5],[32.2,-87.6],[32.3,-93.0],[32.1,-98.2],[36.5,-104.0],[35.7,-109.9],[32.4,-114.8],[29.9,-120.1],[27.0,-125.5],[23.8,-131.3],[19.1,-136.2],[13.3,-139.9],[6.6,-141.5]]},"clears":[[0.0,-100.0,48.0],[0.0,-135.0,30.0]]}],
	# The mere in the knoll 2 km north of the start, over the flats by the
	# river's head, the fall facing them (north-north-west). A hollow in
	# the knoll's top holds a mere (about 16,600 m2, 12 m at its deepest), its
	# level just under the saddle at its north tip. The fall stands under that
	# saddle: a bay cut 90 m back into the hill's long slope, the lip 40 m over
	# the foot; the mere leaves by a short stepped outlet through the saddle
	# to the lip. The pool's outflow winds across the bay floor and the flats
	# to the river. Behind the water a tunnel (a sunk cave, as river_falls')
	# runs south-south-east under the mere's north-east arm (22 m of rock
	# under its bed), then bends east under the knoll to a sinkhole on its
	# east slope, 343 m in all; turned 15 degrees east of straight in, as
	# the face stands, it keeps off the mere's deep west lobe. The knoll's
	# south-west foot is the Peak massif's stamp (its lift starts some 80 m
	# past the mere's west shore): a change there can reach this. The clear
	# takes the trees off the bay and its rim; `clears` off the mere.
	["wild/mere_falls","curtain","waterfall",-497.8,-2044.6,20.0,{"clear":125.0,"y":-19.0,"cave":false,"tunnel":{"seed":83,"turn":15.0,"length":250.0},"back":90.0,"lip":40.0,"half_back":34.0,"half_front":40.0,"round":22.0,"flare":0.3,"pool_r":18.0,"pool_rf":12.0,"pool_depth":1.4,"lip_half":11.0,"spread":9.0,"thread_gaps":0.4,"lip_seed":67.0,"fall":{"mist":0.95,"veil_fade":0.9},"fan":0.0,"out_under":1.6,"stream":[[24,-122,44.4,3.0],[19,-113,44.3,2.6],[16,-108,44.2,2.4],[13,-104,43.6,2.3],[11,-101,42.8,2.4],[8,-98,42.4,2.6],[5,-95,41.0,2.6],[2,-92,40.5,2.8],[0,-90,40.0,3.0]],"outflow":[[0,-70,0,3.0],[6,-55,0,3.2],[2,-40,0,3.4],[-6,-25,0,3.6],[-4,-10,0,3.8],[-8,5,0,4.0],[-14,25,0,4.2],[-18,45,0,4.4],[-22,62,0,4.6],[-24,78,0,5.0]],"lake":{"level":44.4,"shore":[[22.0,-222.7],[23.3,-227.6],[16.8,-237.9],[17.0,-260.3],[10.7,-267.6],[-4.2,-270.8],[-12.3,-265.1],[-16.8,-265.1],[-20.0,-267.5],[-28.1,-268.2],[-47.1,-278.1],[-59.6,-276.3],[-67.1,-271.8],[-69.5,-265.9],[-77.4,-265.2],[-80.5,-262.7],[-89.1,-249.1],[-93.7,-249.2],[-99.7,-244.8],[-110.3,-229.9],[-126.3,-228.5],[-129.8,-225.1],[-135.8,-207.8],[-144.4,-193.7],[-141.6,-173.9],[-146.0,-167.3],[-146.2,-161.5],[-140.1,-152.4],[-111.0,-136.6],[-103.0,-138.6],[-73.6,-159.8],[-66.1,-153.5],[-65.7,-147.0],[-61.5,-140.6],[-49.6,-132.1],[-39.0,-129.7],[-32.7,-134.0],[-22.3,-135.4],[18.0,-112.0],[25.2,-120.8],[23.9,-129.6],[32.0,-142.8],[36.7,-157.4],[26.2,-171.4],[28.4,-183.5],[34.5,-195.6],[32.5,-199.9],[19.9,-206.7]]},"clears":[[-35.8,-208.9,55.0],[-114.9,-186.5,40.0],[-8.5,-157.2,40.0],[-69.2,-247.9,40.0],[11.2,-226.0,40.0],[-46.2,-149.8,40.0],[-101.3,-149.0,40.0],[25.9,-150.5,40.0]]}],
]
