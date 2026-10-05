import type * as MapboxGL from 'mapbox-gl';

/**
 * mapbox-gl is loaded as a plain <script> from `vendor/mapbox-gl.js`, which
 * `scripts/sync-mapbox-gl.mjs` copies out of node_modules into `public/vendor/`
 * (run automatically by `postinstall`, or via `npm run sync:mapbox`).
 *
 * DO NOT change this back to `import * as mapboxgl from 'mapbox-gl'`.
 *
 * Angular's esbuild pipeline force-disables the `object-rest-spread` language
 * feature (see `getFeatureSupport` in @angular/build: it is a deliberate V8
 * performance workaround, unrelated to browserslist or build target). So any
 * mapbox code that goes through the bundler is rewritten to call the helper
 * functions `__spreadValues` / `__spreadProps`.
 *
 * On the main thread that is harmless: esbuild hoists the helpers into a shared
 * chunk and emits an `import` for them. But mapbox-gl v3 builds its tile worker
 * by stringifying its own bundled code into a Blob. Stringification drops the
 * `import` statement while keeping the helper *calls*, so the worker throws
 *
 *   ReferenceError: __spreadValues is not defined
 *
 * on every tile and the map renders permanently blank with no visible error.
 * Loading mapbox-gl outside the bundler keeps its worker self-contained.
 */
declare global {
  interface Window {
    mapboxgl?: typeof MapboxGL;
  }
}

export function mapboxgl(): typeof MapboxGL {
  const api = window.mapboxgl;
  if (!api) {
    throw new Error(
      'Mapbox GL failed to load. Check that public/vendor/mapbox-gl.js exists ' +
        '(run `npm run sync:mapbox`) and that the <script> tag in src/index.html ' +
        'runs before the application bundle. A 404 here usually means the Angular ' +
        'dev server was started before that file was added; restart `ng serve`.',
    );
  }
  return api;
}
