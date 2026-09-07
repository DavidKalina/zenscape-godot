import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-fireflies',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const data=await evalJs(`(()=>{const fly=__dbg.built.mountain.fireflies;const points=fly.group.children.find(o=>o.geometry?.attributes.aAmp);if(!points)throw Error('No source firefly cloud');const a=points.geometry.attributes;return {positions:Array.from(a.position.array),phase:Array.from(a.aPhase.array),amplitude:Array.from(a.aAmp.array),rate:Array.from(a.aRate.array)};})()`);
writeFileSync(new URL('../assets/zen_reference/fireflies.json',import.meta.url),JSON.stringify(data));console.log('Exported',data.phase.length,'fireflies');process.exit(0);
