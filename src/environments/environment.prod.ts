export const environment = {
  production: true,
  // The production ingress must proxy /api and /socket.io to NestJS.
  apiBaseUrl: '/api/v1',
  appKey: 'base64:p1bMvccoy1PXI8O5Shqq+CyjUld8/3hVzHHrDy/W/uU=',
  socketIo: {
    path: '/socket.io',
    url: undefined as string | undefined,
  },
};
