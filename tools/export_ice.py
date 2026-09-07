"""Regenerate the native stationary ice field from the original shader recipe."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root.parent / 'zenscape' / 'lake-ice.js').read_text()
pars = re.search(r'pars: /\* glsl \*/ `([\s\S]*?)`', source)[1]
pars = '\n'.join(line for line in pars.splitlines() if 'uniform ' not in line)
color = re.search(r'color: /\* glsl \*/ `([\s\S]*?)`', source)[1]
shader = pars + '\nvoid zs_ice_surface(inout vec3 body, inout float alpha, vec3 worldP, float depth, float cut, out vec3 ice_state) {\n' + color + '\n ice_state = vec3(zsIceCover, zsIceClear, zsIceSnow);\n}\n'
for original, native in [('uIceDetail', '1.0'), ('uIceWindDir', 'zs_wind_direction'), ('uIce', 'zs_ice'), ('vnHash', 'zs_noise_hash'), ('vnNoise', 'zs_noise'), ('vIceP', 'worldP'), ('vWaterD', 'depth'), ('vCut', 'cut'), ('diffuseColor.rgb', 'body'), ('diffuseColor.a', 'alpha')]:
    shader = shader.replace(original, native)
(root / 'shaders/reference_ice.gdshaderinc').write_text('// Source lake-ice.js stationary fracture, clear-ice, snow and bubble fields.\n' + shader)
