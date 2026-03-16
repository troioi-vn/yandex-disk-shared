# Yandex Disk in Docker

This container runs the Yandex Disk Linux console client in the foreground, which matches Docker's process model better than starting the client as a background daemon.

## Build

```bash
docker compose build
```

## Authorize the container

Run the token flow once:

```bash
docker compose run --rm yandex-disk token
```

The client prints a URL and a one-time code. Open that URL in your browser, log in to the correct Yandex account, and enter the code. The OAuth token is stored in `./config/passwd` on the host.

## Start syncing

```bash
docker compose up -d
```

The local sync folder is `./data` on the host. The container maps it to `/data` and starts:

```bash
yandex-disk --no-daemon --dir=/data --auth=/config/passwd
```

## Useful commands

See logs:

```bash
docker compose logs -f
```

Run in read-only mode:

```bash
YANDEX_READ_ONLY=true docker compose up -d
```

Exclude directories:

```bash
YANDEX_EXCLUDE_DIRS=Downloads,temp docker compose up -d
```

## Notes

- This image uses the official Yandex Linux console client repository described in the Yandex docs.
- `yandex-disk setup` is not required here because the container passes the sync directory and auth file directly on the command line.
- If you want files created on the host to keep your local UID and GID, run the container with `--user $(id -u):$(id -g)` or add an equivalent `user:` setting in Compose.