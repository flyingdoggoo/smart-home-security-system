# Home Guardian

Flutter client for the smart home security backend.

## Features

- Polls `GET /api/v1/status` every 2 seconds.
- Polls and caches the latest 20 events from `GET /api/v1/events?limit=20`.
- Controls door and light through the backend REST API.
- Shows a foreground dialog when a new `stranger_alert` event appears.
- Includes a Settings screen for changing the backend URL during same-network testing.

For Android emulator testing, use the default URL:

```text
http://10.0.2.2:8000
```

For a physical phone, use your backend machine's LAN IP, for example:

```text
http://192.168.1.23:8000
```
