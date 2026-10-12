# Plane parts, round 1: look study

Branch `look/plane-parts` (from `feature/ledger`). This is a look study only. Nothing is wired into gameplay, the ledger or the isles.

## What's there

- `scripts/plane_parts.gd`: `PlaneParts.part(id, size, style)` returns a holder that turns, bobs and glows. `style` is `"coin"` or `"piece"`, and `glow_for(night)` lights it for day or night.
- `studies/plane_parts_gallery.tscn` (`run-plane-parts.command`, and "Plane parts gallery" in the scene picker): all six parts as coins on the top row and as pieces on the bottom row, with the plane parked on the left. Keys: `N` toggles night, `F` freezes the turning. Flags: `--night`, `--yaw=`, `--distance=`, `--focus=x,y` and `--capture=<png>`.
- `scripts/plane_figure.gd`: refactored without changing the look. The new `piece(id)` and `paints()` methods build the cowl, spinner, propeller, windscreen, wheels and fin, and the figure is now built from them. A headless comparison against the old figure found all 37 meshes the same, triangle for triangle. `piece("wingtip")` is new: it builds the upper wing's right tip from the same `_wing` and `_decal` calls.
- `shaders/plane_part_glow.gdshader`: the warm rim glow and shine drawn over a hovering piece as a material overlay.

## The six parts

| Part | Why it's in the set | Silhouette |
|---|---|---|
| Propeller (with spinner) | The part everyone recognises as a plane | A long thin diagonal bar with a hub |
| Wheel | Easy to imagine losing in a rough landing | A dark ring around a cream disc |
| Cowl | The engine's housing, with louvres and exhaust stacks | A terracotta drum with pipes trailing behind |
| Tail fin (fin and rudder) | The most iconic flat shape on the plane | A tall terracotta and cream slab |
| Wingtip (with roundel and aileron) | Holds the roundel, the plane's emblem | A cream panel with a round terracotta tip |
| Windscreen | A small cockpit piece in brass and glass | A thin framed pane |

The plane has no compass or instrument panel, so I picked only parts that are really on the model. Every part is built from the plane's own meshes and paints, so a found part matches the spot it goes back to.

## The two treatments

- **A, coin:** a thick faceted coin with a sky-blue face, a brass bevel and rim, and the part in raised relief on both sides, painted in its own colours. The relief comes from drawing the part's real triangles flat from its most telling side (the propeller from the front, the wingtip from above, the cowl from three-quarters on). The outline is traced and raised into a faceted pillow, the same way the glyph tokens are made, and it uses the glyph token shader (rim glow and shine).
- **B, piece:** the actual part, hovering and turning slowly, posed so each one shows its shape as it turns, under a warm rim glow with the same shine.

Both share the holder: a warm halo, motes, and a soft brass ring of light under the part (the plane's own landing-mark texture). The ring keeps them apart from the rune token's cool, tilted solid ring.

## Recommendation: B, the hovering pieces

In the captures the pieces are far easier to tell apart. Each silhouette is different (bar, ring, drum, slab, panel, pane), they read as the thing you'll bolt back on, and they match the parked plane. The coins look good up close, but at gallery distance they become six similar blue discs with small reliefs inside, and they lose most of their shape when edge-on. They also look like a family of the glyph and rune tokens, while a plane part should feel different from a token. If coins are wanted for the HUD or ledger, coin A would make a good icon for the same part.

## Captures (local only; `captures/` is gitignored)

- `captures/plane_parts/day.png`: the whole gallery by day
- `captures/plane_parts/close.png`: close on the wheel, cowl, fin and wingtip, coins above and pieces below
- `captures/plane_parts/night.png`: the gallery at night

I made these fixes after looking at the captures: framed the camera closer, started each part three-quarters on so the wheel and fin aren't edge-on, deepened the coin face colour, and toned down the night glow, which had washed the paint to beige.

## Open questions

- Should a found part go missing from the plane until it's found? For example, the plane could start with no propeller and one wheel. `piece()` makes that easy to try: leave a part out of `_init`.
- The windscreen is the weakest piece because its glass is faint. It could be swapped for the exhaust stacks or a strut-and-wire pair, or given a stronger glass just for the find.
- The wheel is plain from the hub side. Should the found wheel show its brass hub on both faces?
- How big should a part be in the world? The study shows them at about 1 m. The real parts are 0.15 to 0.6 m at the plane's toy scale.
- How does each part get found? Each one is meant to be found a different way. That's design work for the next round.
