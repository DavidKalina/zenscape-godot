"""Adapt the source lake wind recipe; keep generated shader formulas together."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
s=(root.parent/'zenscape/water.js').read_text()
wave=re.search(r'const LAKE_WAVES_GLSL = /\* glsl \*/ `([\s\S]*?)`;',s)[1]
fetch=s[s.index('      float zsFetch('):s.index('\n    `,',s.index('      float zsFetch('))]
chop=s[s.index('export function waterChop('):s.index('export function lakeMaterial(')]
body=re.search(r'    body: /\* glsl \*/ `([\s\S]*?)`',chop)[1]
cap=re.search(r'    capGLSL: /\* glsl \*/ `([\s\S]*?)`',chop)[1]
ring=re.search(r'    ringGLSL: /\* glsl \*/ `([\s\S]*?)`',chop)[1].split('      if (uWet')[0]
code='''uniform float lake_swell = 1.0;
uniform vec2 lake_effects = vec2(1.0);
float zsGale(float wind, float g) { return wind * (0.45 + 1.1 * g); }
'''+wave+fetch+'''
float zs_lake_chop(vec3 position, vec3 world_p, float depth, vec4 aFetchA, vec4 aFetchB, out vec3 state) {
float vFetch, vCrest, vGust;
vec3 transformed = position;
'''+body+'''
state = vec3(vFetch, vCrest, vGust);
return transformed.y - position.y;
}
void zs_lake_foam(inout vec3 body, inout float alpha, vec3 world_p, float water_depth, vec3 state) {
float vFetch = state.x, vCrest = state.y, vGust = state.z;
'''+cap+'''
}
vec3 zs_lake_fine_normal(vec3 normal, vec3 world_p, float water_depth, vec3 state) {
float vFetch = state.x, vCrest = state.y, vGust = state.z;
'''+ring+'\nreturn normal;\n}\n'
code=code.replace('(modelMatrix * vec4(position, 1.0)).xz','world_p.xz').replace('(viewMatrix * vec4(slope.x, 0.0, slope.y, 0.0)).xyz','vec3(slope.x, 0.0, slope.y)')
code=code.replace('zsGust(world_p.xz, uWindDir, uGustT)','zs_gust_field(world_p.xz)')
for a,b in [('uMarineChop','lake_marine_chop'),('uMarineRipples','lake_marine_ripples'),('uLook.z','lake_swell'),('uLakeEffects','lake_effects'),('uWindDir','zs_wind_direction'),('uWind','zs_wind_strength'),('uTime','zs_flow_time'),('uIce','zs_ice'),('uChop.x','0.021'),('uChop.y','9.0'),('uChop.z','1.0'),('aDepth','depth'),('vIceP','world_p'),('vWaterD','water_depth'),('vnNoise','zs_noise'),('diffuseColor.rgb','body'),('diffuseColor.a','alpha')]: code=code.replace(a,b)
(root/'shaders/reference_lake_chop.gdshaderinc').write_text('// Generated from water.js by tools/export_lake_chop.py.\n'+code)
