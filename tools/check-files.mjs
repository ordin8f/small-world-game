import { readFile, access } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const required = [
  'index.html',
  'styles.css',
  'src/game.mjs',
  'src/logic.mjs',
  'src/renderer.mjs',
  'src/world.mjs',
  'src/audio.mjs'
];

for (const file of required) await access(resolve(root, file));

const html = await readFile(resolve(root, 'index.html'), 'utf8');
for (const reference of ['./styles.css', './src/game.mjs']) {
  if (!html.includes(reference)) throw new Error(`index.html is missing ${reference}`);
}

const game = await readFile(resolve(root, 'src/game.mjs'), 'utf8');
if (!game.includes('window.__SMALL_WORLD__')) throw new Error('Smoke-test hook missing');

console.log(`Verified ${required.length} required files and HTML entry references.`);
