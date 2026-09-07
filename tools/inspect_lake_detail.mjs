import {readFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-lake-detail',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
console.log(JSON.stringify(await evalJs(`(()=>{const found=[];__dbg.scene.traverse(o=>{if(o.name.startsWith('lake:'))found.push({name:o.name,count:o.count,uniforms:Object.keys(o.material?.uniforms??{}),homes:o.userData.homes});});const f=__dbg.built.mountain.world.water();return {found,fieldKeys:Object.keys(f),bodies:f.bodies?.map(b=>({kind:b.kind,area:b.area,level:b.level}))};})()`)));
process.exit(0);
