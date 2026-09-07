# Frozen lake lighting

The native lake now adds lake-ice.js's primary directional highlight before
tone mapping: clear windows sharpen the lobe from exponent 32 to 420, coverage
scales it, and snow suppresses it. Weather-modulated source irradiance supplies
the color and energy. Cut faces do not receive this surface highlight.

Display-space reflection follows the source water.js order: ordinary water sky
reflection, then the clear/frost ice reflection, then celestial glints. The
previous native approximation collapsed the first two into one weight. The
legacy lake-lighting debug path retains that previous approximation.

Validation:
- `test_ice_highlight.gd`: 36 native GPU cases against independent source math,
  varying coverage, clarity, snow and off-specular angle; RGB tolerance .01.
- `test_lake_display_composite.gd`: final ACES pixels check layered ice reflection
  on dark, midtone and bright water with three glint weights, tolerance .015;
  existing open-water checks and rejection of HDR blending also pass.
- `test_fidelity.gd`: integrated scene passes.
- `lake-ice-lighting.mp4`: two seconds native, full freeze, no fog, camera
  `3,1.108864,-.982801,6.2,.38,-3.4`; frame 30 inspected.
- `lake-ice-source.png`: original with the same nominal camera and full freeze.
  Both show broad pale reflection with darker ice away from it. Small camera
  drift, particle differences and native/source transparency prevent treating
  this as pixel-exact appearance parity. That historical native capture includes extra ballistic droplets absent in
  the source. FALL-MIST.md records their subsequent replacement with source mist.

The source lake-detail inspection found area 41.2948865821 and only lake:mist.
The dedicated lake rays require area >=90; submerged props found no eligible
placements. Those absent effects must not be invented for seed 7. Their systems
still need support for eligible larger/deeper scenes. Ice cut-face/base shading
and full matched freeze/thaw motion remain incomplete.
