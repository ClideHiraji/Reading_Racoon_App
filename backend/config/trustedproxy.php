<?php

/*
|--------------------------------------------------------------------------
| Trusted proxies (NFR-04, D-036)
|--------------------------------------------------------------------------
|
| On the home server, the internet reaches Laravel through a tunnel connector
| (cloudflared or tailscaled) running on the same laptop, so every request
| arrives from 127.0.0.1. Only the proxies listed here may set
| X-Forwarded-For/-Proto/-Host/-Port; Laravel then sees the real client IP
| (for the rate limits and the admin IP allowlist) and the real https scheme.
|
| Keep this to the local connector. Never use "*": anyone who can reach the
| web server directly could then spoof their IP. Apache must listen on
| 127.0.0.1 only, so the tunnel is the one way in.
|
*/

return [
    'proxies' => array_values(array_filter(array_map('trim',
        explode(',', (string) env('TRUSTED_PROXIES', '127.0.0.1,::1'))))),
];
