/**
 * Copies the Mapbox GL browser bundle out of node_modules into `public/vendor/`
 * so it is served as a plain static file and never passes through the Angular
 * bundler.
 *
 * This must not be replaced with an angular.json `assets` entry pointing at
 * node_modules: the dev server only reads angular.json at startup, so adding
 * the asset there requires a restart. `public/` is already watched live, which
 * means this file is available immediately after `npm install`.
 *
 * WHY mapbox-gl has to stay out of the bundle:
 * Angular's esbuild pipeline force-disables the `object-rest-spread` feature
 * (getFeatureSupport() in @angular/build) as a V8 performance workaround. It
 * is not configurable - browserslist and the build target do not affect it.
 * Bundled mapbox code is therefore rewritten to call __spreadValues /
 * __spreadProps. The main thread is fine because esbuild hoists those helpers
 * into a shared chunk and emits an import, but mapbox-gl v3 builds its tile
 * worker by stringifying its own bundled code into a Blob. Stringification
 * drops the import but keeps the calls, so the worker throws
 * `ReferenceError: __spreadValues is not defined` on every tile and the map
 * renders permanently blank.
 *
 * See src/app/core/mapbox/mapbox-global.ts and nestjs_api.md section 20.8.1.
 */
import { copyFileSync, mkdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(here, '..');

const source = join(projectRoot, 'node_modules', 'mapbox-gl', 'dist', 'mapbox-gl.js');
const targetDir = join(projectRoot, 'public', 'vendor');
const target = join(targetDir, 'mapbox-gl.js');

let version = 'unknown';
try {
  version = JSON.parse(readFileSync(join(projectRoot, 'node_modules', 'mapbox-gl', 'package.json'), 'utf8'))
    .version;
} catch {
  // version is informational only
}

try {
  mkdirSync(targetDir, { recursive: true });
  copyFileSync(source, target);
  console.log(`[mapbox] copied mapbox-gl@${version} -> public/vendor/mapbox-gl.js`);
} catch (error) {
  // A missing mapbox-gl must not fail `npm install`; the app shows a clear
  // "Mapbox GL failed to load" error only if a map is actually opened.
  console.warn(`[mapbox] could not copy mapbox-gl: ${error.message}`);
  console.warn('[mapbox] run `npm run sync:mapbox` after installing dependencies.');
}
