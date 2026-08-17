# AWS demo backend

The demo API runs on a single small EC2 instance with persistent EBS storage.
Node listens only on `127.0.0.1:8787`; Caddy exposes ports 80/443 and manages
HTTPS. Mutable accounts, sessions, collections, uploads, generated looks, and
saved fits live under `/var/lib/youcam2` so application releases do not replace
them.

## Runtime layout

- Application releases: `/opt/youcam2/releases`
- Active release: `/opt/youcam2/current`
- Secret environment: `/etc/youcam2/server.env`
- Persistent JSON and media: `/var/lib/youcam2`
- Service logs: `journalctl -u youcam2`
- Reverse proxy logs: `journalctl -u caddy`

`bootstrap-ubuntu.sh` expects the backend archive at
`/tmp/youcam2-server.tgz` and the uncommitted production environment at
`/tmp/youcam2-server.env`. Never add that environment file to Git.

For local Flutter development, override the hosted API explicitly:

```sh
flutter run --dart-define=API_URL=http://127.0.0.1:8787
```

