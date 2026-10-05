# Public API endpoints

All four clients use `https://api.tala-works.online/api/v1` and the Socket.IO
origin `https://realtime.tala-works.online` (namespace `/realtime`, transport
path `/socket.io`). Flutter private configuration overrides must use these
same domains; rebuild and reinstall mobile apps after changing dart defines.

The gateway accepts the known local browser origins on ports 4200 and 4300
(`localhost` and `127.0.0.1`) by default. For hosted admin/merchant websites,
set `CORS_ORIGINS` in the API's private environment to a comma-separated list
of their exact origins, for example:

```env
CORS_ORIGINS=https://your-admin-host.example,https://your-merchant-host.example
```

This replaces the default allowlist. Include local origins explicitly if still
needed. Do not include URL paths, trailing slashes or wildcards. Restart the API
gateway after changes. The gateway owns CORS response headers for proxied API
responses. Native Android/iOS requests are not governed by browser CORS.

Neither private config files nor APKs should be committed to the repository.
