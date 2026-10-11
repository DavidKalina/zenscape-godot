# Skydive (prototype)

> **2026-10-10: the canopy is gone.** Out of the plane (and off an edge on
> foot) you now fall until you press Jump (Space, pad A), which pops out the
> pocket sail, the walker's own hand glider. Nothing opens by itself, X no
> longer opens anything, and there is no assist or flare. See
> `docs/design/pocket-sail.md`. The canopy notes below are kept for history.

Eject from the plane, dive, float down under a canopy, land and walk on. Branch `feature/skydive`, cut from `feature/ruins` (knife-edge included). Not on main.

## Try it

```sh
~/Applications/Godot.app/Contents/MacOS/Godot --path . -- --no-title --skydive
```

- `--skydive`: starts in the plane 110 m over the home island, 50 m short of its middle and flying towards it. Press X.
- `--skydive=fall`: the same, but already out of the plane and falling.
- Without either flag, it works from any normal flight: X in the plane.

Rendered stills of the whole sequence come from:

```sh
Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_skydive.gd -- --no-title --out=/private/tmp/zs-skydive
```

## Controls

| Moment | Keys / mouse | Pad |
|---|---|---|
| In the plane: eject | X | X |
| Falling: open the canopy | X | X |
| Falling: turn | A D | Left stick ◂ ▸ |
| Falling: track forward (fly on over the ground, head lower) / slide back | W / S | Left stick ▴ / ▾ |
| Falling: tuck and dive faster (17 → 34 m/s) | Space | RT or A |
| Falling: spread and slow (→ 9.5 m/s) | Shift | LT |
| Canopy: steer | A D | Left stick ◂ ▸ |
| Canopy: speed up (sinks faster) / brake (floats) | W / S or Shift | Left stick ▴ / ▾, LT |
| Look round (swings back after 1.5 s) | Mouse | Right stick |
| Step out | V / Esc | B or View |

The flare is automatic: from 3.2 m over whatever is under you, the sink and forward speed bleed off, so every canopy landing is soft. `fly_eject` is a new action in `scripts/pad.gd`. The pad's X did nothing while flying the plane before (it is the old glider's flap only under `--glider`), so it doesn't clash with anything.

## What was built

- `scripts/sky_dive.gd` holds the physics as plain state and maths. It extends the glide, so the sky, the cloud tearing, the lower-world swap and the claim shift all read it like a flight. The phases run in order: POP, FREEFALL, OPENING, CANOPY, DOWN.
  - **Pop:** a 5.5 m/s kick up, keeping 60 % of the plane's way, with a forward tumble onto the belly.
  - **Freefall:** gravity against drag gives a terminal speed set by posture. You can turn, track or backslide, and wind drifts you.
  - **Opening:** the canopy streams out, bites at 40 % of 1.1 s, and swings you forward under it.
  - **Canopy:** steer, speed up or brake. You swing on the lines when turning or changing speed. Wind carries you, and rising air holds you up.
  - **Assist:** with no turn held under the canopy, it eases round towards the nearest island's middle, so a hands-off float lands on land.
  - **Auto-open:** the canopy opens by itself at 12 m + 1 s of fall over ground or water. A fall that hits ground before the canopy fills is a "hard" bump, never a hurt.
  - **Island sides:** falling beside an island holds you off its face.
  - Springs are sub-stepped (≤ 1/90 s), so a long frame can't throw the tumble.
- `scripts/dive_camera.gd`: the camera.
  - Falling, it sits behind and above, looking forward and down with the horizon in view. It draws in when tucked, widens its view with speed and adds a few centimetres of tremor at full speed.
  - Under the canopy it eases back to frame the pilot and the canopy.
  - It kicks down when the canopy bites.
- `scripts/canopy_figure.gd` + `shaders/canopy_cloth.gdshader`: the canopy.
  - A faceted ram-air wing of 7 cells on an arc. The colours are the plane's livery: cream cloth, terracotta tips and a brass centre stripe.
  - Each cell puffs between its ribs, with flat-lit facets taken from screen derivatives.
  - The trailing edge ripples, and sunlight glows through the underside.
  - Lines run to the shoulders. It streams out, swells past full and settles. On landing it flies on a little and folds down onto the ground.
- `scripts/pilot_figure.gd` `dive()` poses the pilot's limbs over the idle clip.
  - Falling, he holds the box position: arms out, elbows bent, boots up. Spread is wider; tucked sweeps the arms back.
  - Under the canopy his mitts are up on the toggles. In the flare he pulls them down and puts his boots forward.
  - The pop is a flail. Proportions are unchanged; only bones are turned.
- `scripts/wanderer_eye.gd` (section "The skydive") ties it in:
  - **Eject:** `eject()`, from any flight except during a landing or takeoff sequence, or while perched.
  - **Claims:** if you dive over another island it is claimed before you touch down, as the plane's flight does.
  - **Landing:** on the plate you go on foot, round any trunk, with the camera swooping in. On an islet or a lower-world island you perch there. Deep water means you swim; it reads the motor's own water, so ponds and swimmable islet lakes work.
  - **Ground:** the dive lands on islet ground, not tree crowns.
  - **The plane:** after you eject it flies itself. It circles you 26 m out and 14 m over you (or 10 m over the ground). Once you are down on the plate it lands on the best strip near you using `plane_landing.gd`, pilotless, and parks. Walk up to it and Space boards it, as before.
  - **On an islet:** the plane keeps circling. The existing "jump, then Space again in the air" brings it, and the circling one goes.
  - **Pickups (never death):**
    - With no lower world, a fall into the cloud sea is caught by the plane, which flies on with you aboard.
    - With the lower world (the default in play), the fall carries on through the existing white-out swap.
    - Open ocean, a mountain's rock, forested isles and the airship all get the same plane pickup.
  - **Step out:** V mid-dive packs the canopy and steps out cleanly. If you leave while the plane is circling over the plate, it parks beside you.

## Checks

- `tests/test_sky_dive.gd`: the physics, the camera and the figure, headless. Passes.
- `tests/test_skydive.gd`: the live scene, headless, tagged `## suite: slow`. Passes, and also passes with `-- --below`. It covers:
  - eject, auto-open, and the hand-off to walking on the home island;
  - the canopy folding;
  - the plane landing near you and parking, then Space boarding it;
  - X opening the canopy and the stick steering;
  - landing in deep water and swimming;
  - a fall past everything being caught;
  - an open-water pickup;
  - V mid-dive.
  - Under `--below`, the fall goes through the cloud sea and lands on an archipelago island.
- `tests/test_plane_flight.gd` and `tests/test_gamepad.gd` still pass. I touched the plane's hints and the pad's actions, so I ran them too. The full suite was not run.

## Known issues

- **Water test is faked.** The default world has no pond deep enough to swim, and the islets near home have no swimmable lake. So the water landing test gives the motor a fake pond. A real plate pond or islet lake should behave the same, because the hand-off reads the same `motor.water`, but that is unverified. On a plate pond the dive also falls to the bed for its last half second, because the dive's ground has no pond surface, before the motor floats the pilot up.
- **Flaky drone check.** One live run (out of about six) failed "the plane comes in to land near the pilot" and "parks", and it didn't reproduce. The test now prints the drone's state if it fails again.
- **The plane appears and vanishes.** When you fly again from an islet, the circling plane vanishes and the plane appears under you. The game already worked this way, but now you can see the other plane at the moment it goes. Pickups also cut straight to flying, with no swoop-in animation. Under the cloud-sea white-out you can't see it; over open ocean you can.
- **Assist pulls towards the plate.** The canopy assist aims at the nearest plate or island middle, never at islets. If you're heading for an islet hands-off, it pulls you away; steer instead.
- **No auto-open beside cliffs.** Falling down beside a cliff, the land under the pilot is read as lower, so auto-open waits for whatever is below. Brushing a mountain face while falling just slides you down it.
- **Inside rock after the swap.** Crossing into the lower world, a fall over a mountain range can find itself inside that range's lower-world rock, which reaches down into the ocean. It is held at the face and slides down to the water, where the plane picks you up. It looks wrong if you watch it.
- **Freefall pose is bone turns, not an authored clip.** It reads as a skydiver from behind and above. From the side it reads lumpier.
- **Sound is reused:** the glide's wind, a flap's whoosh for the canopy, and the plane's hum from nearby. There is no canopy rustle or landing thump of its own.
- **Untested on hardware:** the pad's rumble, and how the X glyph shows in the hints.

## Next steps

- Skydive into set pieces (ruins), then go on foot. The touch-down to perch hand-off is the hook: give a ruin a standable ground like an islet's and the dive lands on it.
- Author freefall and canopy clips in Blender (`art/blender/pilot`) to replace the bone turns.
- Add a visible swoop for the pickup, and let the plane come in to an islet's edge rather than only the plate.
- Point the canopy assist at whatever landable thing is nearest, islets included.
- Make the canopy's cloth sound and wind rush its own, and add a landing sound.
