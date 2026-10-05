import { localMapboxToken } from './mapbox-config';

export const environment = {
  production: true,

  /**
   * Public API base. In production the ingress routes `/api` to the NestJS API
   * gateway and `/socket.io` to the realtime service, so the app stays
   * same-origin and needs no CORS configuration.
   */
  apiBaseUrl: '/api/v1',

  socketIo: {
    path: '/socket.io',
    // `undefined` means "same origin as the page". Set an absolute origin
    // (e.g. 'https://ws.tala-works.online') when the gateway is on another host
    // and the ingress does not proxy /socket.io.
    url: undefined as string | undefined,
  },

  appKey: 'base64:p1bMvccoy1PXI8O5Shqq+CyjUld8/3hVzHHrDy/W/uU=',
  mapboxAccessToken: localMapboxToken(),
};
