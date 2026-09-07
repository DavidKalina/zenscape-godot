import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-frogs',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const data=await evalJs(`(()=>{const system=__dbg.built.mountain.frogs;return system.frogs.map(f=>({natural:f.natural,scale:f.s,phase:f.phase,spot:f.spot,body:{x:f.body.x,z:f.body.z,level:f.body.level},from:f.from}));})()`);
writeFileSync(new URL('../assets/zen_reference/frogs.json',import.meta.url),JSON.stringify(data));console.log(JSON.stringify(data));process.exit(0);
