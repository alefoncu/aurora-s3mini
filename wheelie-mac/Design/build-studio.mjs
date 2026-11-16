// node Design/build-studio.mjs  -> Design/studio.html (inlines bikes.js into the studio template)
import { readFileSync, writeFileSync } from 'node:fs';
const dir = new URL('.', import.meta.url);
const js = readFileSync(new URL('bikes.js', dir), 'utf8');
const tpl = readFileSync(new URL('studio.template.html', dir), 'utf8');
writeFileSync(new URL('studio.html', dir), tpl.replace('/*BIKES_JS*/', () => js));
console.log('studio.html written');
