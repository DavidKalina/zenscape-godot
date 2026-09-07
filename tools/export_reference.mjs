// Capture the source game's actual scene using its existing GPU probe harness.
// Usage: ZS_URL=http://localhost:8148/ node tools/export_reference.mjs /path/to/zenscape
import { writeFileSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const source = resolve(process.argv[2] ?? '../zenscape');
const { openBrowser } = await import('./capture_browser.mjs');
const output = fileURLToPath(new URL('../assets/zen_reference/', import.meta.url));
const query = '?seed=7&title=0&grow=1,1,1,1&daylen=0&hud=0&aurora=0&bow=0&tod=0.35&wx=shroud:0,cloud:0.06,mist:0.02,haze:0.03,wind:0.4&cam=43,1.13,1.8893,0,3,0';
console.log('Starting reference browser');
const { open, evalJs } = await openBrowser('godot-reference', { flags: ['--use-angle=metal', '--enable-gpu-rasterization', '--ignore-gpu-blocklist'] });
console.log('Browser connected; loading scene');
await open(query);
console.log('Scene ready; setting camera and clock');
await evalJs(`(() => {
  const d = __dbg;
  d.controls.autoRotate = false;
  d.renderer.setPixelRatio(1);
  d.renderer.setSize(1440, 900);
  d.camera.aspect = 1440 / 900;
  d.camera.updateProjectionMatrix();
  d.film.start();
  for (let i = 0; i < 50; i++) d.film.frame(0.1, { quality: 0.02 });
  return true;
})()`);

console.log('Capturing source geometry');
const summary = await evalJs(`(() => {
  const d = __dbg, meshes = [], skipped = [], lights = [];
  let sky = {};
  d.scene.updateMatrixWorld(true);
  d.scene.traverseVisible(o => {
    if (o.isLight) {
      lights.push({ type:o.type, color:o.color.toArray(), ground:o.groundColor?.toArray(), intensity:o.intensity,
        position:o.position.toArray(), target:o.target?.position.toArray(), castShadow:o.castShadow });
    }
    if (o.material?.uniforms?.uDown && o.material?.uniforms?.uMoonDir) {
      for (const [key, u] of Object.entries(o.material.uniforms)) {
        if (typeof u.value === 'number') sky[key] = u.value;
        else if (u.value?.toArray) sky[key] = u.value.toArray();
      }
    }
    if (!o.isMesh || !o.geometry) return;
    const m = o.material;
    if (Array.isArray(m) || m.isShaderMaterial || m.opacity < 0.005 || !m.visible) {
      skipped.push({ name:o.name, type:o.type, shader:m?.type });
      return;
    }
    const attrs = {};
    for (const [key, a] of Object.entries(o.geometry.attributes)) {
      if (['position','normal','color','uv','aDepth','aPhase','aFlow','aShore','aCut','aS','aU','aRun','aGlass','aDelay','aHold','aTo','aDirt','aBaseColor'].includes(key)) {
        attrs[key] = { size:a.itemSize, array:Array.from(a.array) };
      }
    }
    const instanceCount = o.isInstancedMesh ? o.count : 0;
    meshes.push({ name:o.name || 'mesh-' + meshes.length, type:o.type, role:o.geometry.attributes.aWing ? 'birds' : 'static',
      matrix:o.matrixWorld.toArray(), attrs, index:o.geometry.index ? Array.from(o.geometry.index.array) : null,
      castShadow:o.castShadow, receiveShadow:o.receiveShadow, count:instanceCount,
      instances:instanceCount ? Array.from(o.instanceMatrix.array.slice(0,instanceCount*16)) : null,
      instanceColors:o.instanceColor ? Array.from(o.instanceColor.array.slice(0,instanceCount*3)) : null,
      material:{ type:m.type, color:m.color?.toArray() ?? [1,1,1], opacity:m.opacity, transparent:m.transparent,
        vertexColors:m.vertexColors, roughness:m.roughness ?? 1, metalness:m.metalness ?? 0,
        emissive:m.emissive?.toArray() ?? [0,0,0], emissiveIntensity:m.emissiveIntensity ?? 1,
        side:m.side, flat:m.flatShading, sway:m.userData?.zs?.splice === 'sway' ? m.userData.zs.tuning : null,
        water:!!m.userData?.submergedSight || !!m.userData?.lakeEffects,
        tags:Object.keys(m.userData ?? {}) }
    });
  });
  window.__godotExport = { version:1, seed:7, meshes, skipped, lights, sky,
    camera:{position:d.camera.position.toArray(),quaternion:d.camera.quaternion.toArray(),target:d.controls.target.toArray(),fov:d.camera.fov,near:d.camera.near,far:d.camera.far},
    exposure:d.renderer.toneMappingExposure,
    linked:d.renderer.info.programs.every(p=>d.renderer.getContext().getProgramParameter(p.program,d.renderer.getContext().LINK_STATUS)) };
  return {meshes:meshes.length, skipped:skipped.length};
})()`);
console.log('Source summary', summary);
const snapshot = await evalJs('(() => { const {meshes,...meta}=__godotExport; return meta; })()');
snapshot.meshes = [];
for(let i=0; i<summary.meshes; i++) {
  snapshot.meshes.push(await evalJs('__godotExport.meshes['+i+']'));
  if(i%20===0) console.log('Exported mesh',i,'of',summary.meshes);
}
snapshot.query = query;
snapshot.source = 'ZenScape Three.js working tree, 2026-09-06';
writeFileSync(output + 'scene.json', JSON.stringify(snapshot));
const environment = await evalJs(`(() => {
 const result = {};
 for (const key of ['uCloudY','uCloudH','uSummit','uGroundRange']) {
  const value=__dbg.weather().uniforms[key].value;
  result[key]=value?.toArray ? value.toArray() : value;
 }
 return result;
})()`);
writeFileSync(output + 'environment.json', JSON.stringify(environment, null, 2));
const image = await evalJs(`__dbg.film.frame(1/30, {type:'image/png'})`);
writeFileSync(output + 'source.png', Buffer.from(image.split(',')[1], 'base64'));
console.log(JSON.stringify({ meshes:snapshot.meshes.length, instances:snapshot.meshes.reduce((n,m)=>n+m.count,0), lights:snapshot.lights, sky:snapshot.sky, camera:snapshot.camera, skipped:snapshot.skipped, linked:snapshot.linked },null,2));
process.exit(snapshot.linked ? 0 : 1);
