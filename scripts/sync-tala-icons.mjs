import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = fileURLToPath(new URL('../', import.meta.url));
const directory = path.join(root, 'node_modules/tala-icons/icons');
const icons = Object.fromEntries(readdirSync(directory).filter(file => file.endsWith('.svg')).sort().map(file => {
  const svg = readFileSync(path.join(directory, file), 'utf8');
  const content = svg.match(/<svg\b[^>]*>([\s\S]*)<\/svg>/)?.[1];
  if (!content) throw new Error(`Invalid Tala SVG: ${file}`);
  return [file.slice(0, -4), content];
}));
writeFileSync(path.join(root, 'src/app/shared/components/tala-icon/tala-icons.generated.ts'),
  '// Generated from tala-icons (MIT). Run npm run sync:tala-icons to refresh.\n' +
  'export const TALA_ICON_PATHS: Readonly<Record<string, string>> = ' + JSON.stringify(icons, null, 2) + ';\n');
console.log(`Bundled ${Object.keys(icons).length} Tala icons.`);
