import {readFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-wildlife',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const found=await evalJs(`(()=>{const d=__dbg.built.mountain,out=[];for(const role of ['fish','frogs','bears','fireflies']){const obj=d[role];obj?.group?.traverse(o=>{if(o.geometry)out.push({role,name:o.name,count:o.count,positions:Array.from(o.geometry.attributes.position.array)});});}return out;})()`);
for(const o of found){const match=saved.meshes.find(m=>m.attrs.position.array.length===o.positions.length&&m.attrs.position.array.every((v,i)=>Math.abs(v-o.positions[i])<1e-6));console.log(o.role,o.name,o.count,match?.name??'not imported');}
process.exit(0);
