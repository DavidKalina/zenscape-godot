from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
source = (root.parent / 'zenscape/weather.js').read_text()
match = re.search(r'const AUTUMN_FRAG = /\* glsl \*/ `([\s\S]*?)`;', source)
assert match, 'Original autumn shader not found'
shader = match[1].replace('#include <color_fragment>', '')
for original, native in [('uAutumn', 'amount'), ('diffuseColor.rgb', 'color'), ('vWxPos', 'world_position'), ('wxsNoise', 'zs_noise')]:
    shader = shader.replace(original, native)
(root / 'shaders/reference_autumn.gdshaderinc').write_text('// Extracted from weather.js AUTUMN_FRAG by tools/export_autumn.py.\nvoid zs_autumn_paint(inout vec3 color, vec3 world_position, float amount) {\n' + shader + '\n}\n')
