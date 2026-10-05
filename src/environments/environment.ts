import { localMapboxToken } from './mapbox-config';

export const environment = {
  production: false,

  // Public HTTPS API gateway (development and production).
  apiBaseUrl: 'https://api.tala-works.online/api/v1',

  // Public Socket.IO origin; /realtime is selected by the realtime client.
  socketIo: {
    path: '/socket.io',
    url: 'https://realtime.tala-works.online',
  },

  appKey: 'base64:p1bMvccoy1PXI8O5Shqq+CyjUld8/3hVzHHrDy/W/uU=',
  mapboxAccessToken: localMapboxToken(),
};
