import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-leaves',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const data=await evalJs(`(()=>{
 const d=__dbg; let leaves,canopy;
 d.scene.traverse(o=>{if(o.geometry?.attributes.aLeaf)leaves=o;if(o.name==='broadleaf-canopies')canopy=o;});
 if(!leaves||!canopy)throw Error('Missing source leaves or canopy');
 const built=Object.values(d.built).find(b=>b?.foliage?.leafSpots);
 return {positions:Array.from(leaves.geometry.attributes.position.array),attributes:Array.from(leaves.geometry.attributes.aLeaf.array),colors:Array.from(leaves.geometry.attributes.color.array),canopyMatrices:Array.from(canopy.instanceMatrix.array),spots:built?.foliage.leafSpots??[]};
})()`);
const canopy=saved.meshes.find(m=>m.name==='broadleaf-canopies');
const expected=canopy.instances.flat();
if(expected.length!==data.canopyMatrices.length||expected.some((v,i)=>Math.abs(v-data.canopyMatrices[i])>1e-5))throw Error('Source canopy geometry changed; recapture scene before leaves');
delete data.canopyMatrices;
writeFileSync(new URL('../assets/zen_reference/leaves.json',import.meta.url),JSON.stringify(data));
console.log('Exported',data.positions.length/3,'leaves from',data.spots.length,'canopy spots');
process.exit(0);
