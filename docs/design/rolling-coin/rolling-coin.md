# The rolling coin (prototype)

A variation of the Olmec's head, standalone (no body comes for it). The head
is round, standing on its rim like a coin, with its face on one of the flat
sides. It charges, breaks stone, and can lap a track.

## Play

- **The coin alone, with breakable stone:** `run-rolling-coin.command`. On
  Windows:
  `& $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/rolling_coin_isle.tscn -- --no-title`
  (`studies/inhaler_isle.tscn -- --head=coin` is the same coin without the
  breakables).
- **The track kit on its bench:** `run-coin-track-bench.command`
  (`studies/coin_track_bench.tscn -- --no-title [--hunt] [--sky]`). Two flat
  discs, one loop, two coins lapping.
- F1 shows the coin's state. `--head-knob=<knob>=<value>` sets any knob on
  the isle study (e.g. `--head-knob=charge_speed=10`).

## What's built

- **`scripts/enemies/rolling_coin.gd`**, which extends the inhaler head.
  - **Free:** it strolls its round, sees all round, stares, turns its rim
    to him, rocks back and charges. It steers in wide arcs (`turn`), banks
    and speeds up downhill. Past him or spent, it wobbles like a dropped coin,
    topples flat on its face or back (he can stand on it), then heaves itself
    back up. Rolling into him knocks him aside and costs a heart. Off a rim
    it falls.
  - **Breaking:** a breaker named `coin` in the breakables hub
    (`scripts/kit_isle/breakables.gd`). Into stone at speed it hits the hub
    with `smash_strength` × its share of `charge_speed`. What breaks, it rolls
    through (`smash_keep` of its speed); what doesn't, it crashes into and
    topples. At full speed it breaks piers (0.5) and walls (0.6), not slabs
    (1.6). `--breakers=-coin` turns it off.
  - **Track mode** (opt-in; with no circuit given, the coin is as above):
    - It follows a lap at the track's speed.
    - It is kicked off each launch lip into a real ballistic arc
      (`fly_gravity`, default 39) and is caught in the next cradle (or
      misses and goes spent).
    - It queues behind a coin lying on the line, and waits at a lip while the
      cradle ahead is full.
    - A lost coin is minted back into a free cradle.
    - Hunting is off by default: the track's data sets `hunt`, and then a
      coin that sees him leaves through a gate, charges, and rejoins.
- **`scripts/enemies/coin_circuit.gd`**: the lap's driver (samples, flights,
  gates, the hunting cap, the queue, the mint-back).
- **`scripts/kit_isle/coin_track.gd`**: the track kit. It builds the stone
  (channel beds and kerbs, arcs, launch lips with side rails, catch cradles,
  gates, rim kerbs) from a track description given as data, in the kit's
  stone colours, as one mesh and one body. Its header says how to describe a
  track. The stone is STAND-IN boxes; real pieces (track_channel,
  track_corner, launch_lip, catch_cradle, track_gate) are still to make.
- **The model:** `art/blender/inhaler_head/inhaler_head_build.py --wheel`
  writes `assets/models/wheel_head.glb`. It has the same face features on a
  drum 3.36 m across and 1.72 m thick. The rim is a tread of 14 coursed
  blocks, with the ear flaps and spools at its sides, a forehead band and a
  back ring. The look loads it through `model_path` / `model_height`.

## Model budget (the coin)

75,220 triangles (the old head has 66,408).
- **Import LODs:** applies; already on.
- **Vertex-colour grime:** applies; already used.
- **Sculpt high, bake low:** applies. Baking onto a 10-15k mesh would save
  about 60k triangles, about 0.1-0.2 ms each on screen.
- **Silhouette geometry:** applies. The tread stays real; the back ring and
  band could go to textures (about 8k triangles).
- **Parallax depth** and **rigid parts on bones:** do not apply.

## What was tried and set aside

A motif level built round the track (the Coin Circuit: six discs, four
coins, hunting out of gates) played as mindless. The coins pivot out of a
gate and have no room to roll at him, so there is nothing to fear. The level
was dropped and the kit kept for a different arrangement.
