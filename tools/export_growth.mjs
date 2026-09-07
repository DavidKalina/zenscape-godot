// Supplemental growth data: verify imported terrain before adding attributes.
import {readFileSync, writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const output = new URL('../assets/zen_reference/growth.json', import.meta.url);
const saved = JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json', import.meta.url)));
const {open, evalJs} = await openBrowser('godot-growth', {flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query ?? '?seed=7&title=0&grow=1,1,1,1&daylen=0&tod=0.35&wx=shroud:0');
const growth = await evalJs(`(() => {
 const out = {};
 __dbg.scene.traverse(o => {
  if (!['terrain','landmark-arch'].includes(o.name) || !o.geometry) return;
  const attrs = {};
  for (const key of ['position','aDelay','aHold','aTo','aDirt','aBaseColor']) {
   const a = o.geometry.attributes[key];
   if(a) attrs[key] = {size:a.itemSize,array:Array.from(a.array)};
  }
  out[o.name] = attrs;
 });
 return out;
})()`);
for (const [name, attrs] of Object.entries(growth)) {
 const expected = saved.meshes.find(m => m.name === name).attrs.position.array;
 if (expected.length !== attrs.position.array.length || expected.some((v,i)=>Math.abs(v-attrs.position.array[i])>1e-5)) throw Error('Source geometry changed: '+name);
 for(const key of ['aDelay','aHold','aTo','aDirt','aBaseColor']) if(!attrs[key]) throw Error('Missing '+name+' '+key);
 delete attrs.position;
}
writeFileSync(output, JSON.stringify(growth));
console.log('Verified and exported growth attributes:', Object.keys(growth));
process.exit(0);
