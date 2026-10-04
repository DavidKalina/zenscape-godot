# Storybook night: notes

Look: indigo and ultramarine washes, a Milky Way brushed in cream and peach strokes with lazy edge curls and dry-brush gaps, a few enlarged warm-cream stars over hushed dust, and an illustrated ringed planet (flat apricot, cream and teal bands; bold three-band ring with two gaps). All in `shaders/night_storybook.gdshaderinc`.

One change outside it: `scripts/sky_objects.gd` built the planet body as a SphereMesh of radius 0.5, so the body drew at half size and the ring was cut out of a larger empty disc. It now has radius 1.0 (applies to every night style).

Weaknesses and next steps:
- The planet's limb is not antialiased at night: `sky_planet_body.gdshader` sets ALPHA to `mix(face.a, 1.0, zs_night)`, so a limb alpha fade from the style is lost. Fix there with an fwidth edge term.
- The ring's planet-shadow edge (`shade`) is hard, as it comes from the shader as 0 or 1.
- The Milky Way reads slightly lavender-grey rather than clearly cream; the scene grade cools it. Peach and cream could go further.
- The planet sits under the camera toolbar in the ground-eye still; check it in the overview.
- The overview (`capture_backdrop`) was not shot.
