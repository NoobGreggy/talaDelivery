const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');

const apps = new Set(['api-gateway', 'identity-service', 'merchant-service',
  'catalog-service', 'order-service', 'dispatch-service', 'payment-service',
  'notification-service', 'realtime-service']);
const app = process.env.APP_NAME;
if (!apps.has(app)) throw new Error('APP_NAME must identify a TalaDelivery service.');
const output = path.join(__dirname, 'dist', 'apps', app);
// Resolve compiled libraries without shipping ts-node to production.
const originalResolve = Module._resolveFilename;
Module._resolveFilename = function (request, parent, isMain, options) {
  if (request.startsWith('@taladelivery/')) {
    const [library, ...rest] = request.slice('@taladelivery/'.length).split('/');
    if (!['auth', 'common', 'contracts', 'events', 'observability'].includes(library)) {
      throw new Error('Unknown TalaDelivery library.');
    }
    request = path.join(output, 'libs', library, 'src', ...rest);
  }
  return originalResolve.call(this, request, parent, isMain, options);
};
const entry = path.join(output, 'apps', app, 'src', 'main.js');
if (!fs.existsSync(entry)) throw new Error(`Missing compiled service entry: ${app}`);
require(entry);
