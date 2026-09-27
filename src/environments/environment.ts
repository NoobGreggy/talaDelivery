export const environment = {
  production: false,
  apiBaseUrl: 'https://delivery-api.tala-works.online/api/v1',
  // Relative in dev: proxy.conf.json forwards /broadcasting/** server-side, so the
  // auth request stays same-origin and never triggers a CORS preflight.
  broadcastAuthUrl: '/broadcasting/auth',
  appKey: 'base64:p1bMvccoy1PXI8O5Shqq+CyjUld8/3hVzHHrDy/W/uU=',
  reverb: {
    appKey: 'jBalLpiRXnBrgyURwkYuRTEMabfZMQnKRdRBrmeWmEJnkcY',
    host: 'delivery-reverb.tala-works.online',
    scheme: 'https',
    // Reverb is served over TLS on 443 behind Cloudflare. Port 6001 (Reverb's HTTP
    // API port) is not reachable as a websocket endpoint.
    port: 443,
  },
};
