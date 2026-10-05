import { localMapboxToken } from './mapbox-config';

export const environment = {
  production: false,

  /**
   * Public API base. Requests go through the Angular dev proxy, so they stay
   * same-origin and never trigger a CORS preflight.
   *
   * In dev, `proxy.conf.json` forwards:
   *   /api        -> api-gateway      (port 3000, itself a prefix proxy)
   *   /socket.io  -> realtime-service (port 3008, Socket.IO)
   */
  apiBaseUrl: '/api/v1',

  // Socket.IO gateway. `url: undefined` means "same origin as the page". Set an
  // absolute origin (e.g. 'https://ws.tala-works.online') when the gateway is
  // on another host and the ingress does not proxy /socket.io.
  socketIo: {
    path: '/socket.io',
    url: undefined as string | undefined,
  },

  appKey: 'base64:p1bMvccoy1PXI8O5Shqq+CyjUld8/3hVzHHrDy/W/uU=',
  mapboxAccessToken: localMapboxToken(),
};
