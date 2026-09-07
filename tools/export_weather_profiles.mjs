import {readFileSync,writeFileSync} from 'node:fs';
const source=readFileSync(new URL('../../zenscape/weather.js',import.meta.url),'utf8');
const body=source.match(/export const WEATHER_PRESETS = (\{[\s\S]*?\n\});/)?.[1];
if(!body)throw Error('Weather preset seam changed');
writeFileSync(new URL('../assets/zen_reference/weather-profiles.json',import.meta.url),JSON.stringify(new Function('return '+body)(),null,2));
