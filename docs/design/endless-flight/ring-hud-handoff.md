# Ring HUD (C2) handoff, 2026-10-28

The line HUD is now the Line HUD canvas's C2, "Minimal ring + glyphs & sheen"
(https://claude.ai/artifact/LXk6GLjAz33ka71XSWi5g8, board DirC2):
`scripts/endless/near_miss_hud_ring.gd`, the default in endless flight.
`--near-hud=tag` (or `handoff`, `handoff-tag`) brings back the handoff tag to A/B.

- Flying: the ring by the plane's upper left is the bank timer, in the
  multiplier's heat, growing and glowing as it heats. Each pass pops its glyph
  into the ring. A sheen crosses the glyph, then a glint crosses the move's name,
  then a dash orbits the arc. Beside the ring: the total and the multiplier, the
  newest pass (name, clearance, points, RAZOR), and a trail of up to 4
  medallions plus a count.
- The bank: the ring goes gold, the coin lands in it, the trail flies in and
  the number slams. Then a small ring and a cream banner on a pole: the seals,
  the land, the name and the money, with a sheen across the cloth.
- A lost line: the ring shatters in coral round the cracked glyph of what was
  hit. LINE LOST and the loss show, and the trail falls away greyed.
- Size: `SCALE` (1.25, on the handoff's min(w/2560, h/1440)); place:
  `RING_AT` (mock px off the plane).
- The H key (tag/top) does nothing with the ring.

Proof: a headless smoke check of endless_flight (600 frames, 0 errors), plus
rendered stills from a scripted line (scratch driver, not committed). Not
yet played by hand. No existing tests touch the HUD.
