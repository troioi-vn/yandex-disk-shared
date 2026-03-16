# Yandex Disk Shared

Run the legacy Yandex Disk Linux client in Docker without treating its state like disposable container data.

This repo is a deployment-friendly wrapper around the official `yandex-disk` CLI. It is meant for headless servers, CI/CD-driven setups, and migrations away from desktop-session autostart hacks.

## Why this repo exists

The Yandex Disk Linux client works, but it has a few awkward properties:

- it is old and stateful
- it expects files such as `passwd` and `iid` to live in specific places
- it behaves differently in `--no-daemon` mode than you might expect from `config.cfg`
- it is easy to get into a setup where the config looks right but the running process is not actually honoring it

This repo makes that setup reproducible.

## What it gives you

- a small Docker image for the official Yandex Disk CLI
- persistent host-mounted config and sync directories
- a container entrypoint that runs the client in the foreground
- support for both fresh authorization and migration from an old host
- a Woodpecker deployment flow for SSH-based server rollout
- operational notes for logs, status checks, and common footguns

## Runtime model

The important split is:

- git stores the deployment recipe
- the server stores runtime state and secrets

That means `config/` and `data/` are intentionally not committed.

Typical deployed layout:

```text
/opt/yandex-disk-shared/
  Dockerfile
  docker-compose.yml
  docker-entrypoint.sh
  .env
  config/
    config.cfg
    passwd
    iid
  data/
    .sync/
```

Container mapping:

- host `config/` -> container `/config`
- host `config/` -> container `/home/ubuntu/.config/yandex-disk`
- host `data/` -> container `/data`

That second config mount matters. Some legacy Yandex Disk state still expects the default per-user config path.

## Important caveat

The container runs Yandex Disk with `--no-daemon`.

That sounds straightforward, but it hides a real gotcha: in this mode, the client did not reliably honor `exclude-dirs` and `proxy` from `config.cfg` by itself in our testing.

Because of that, `docker-entrypoint.sh` now:

- reads `exclude-dirs` from `config.cfg` if `YANDEX_EXCLUDE_DIRS` is not set
- reads `proxy` from `config.cfg` if `YANDEX_PROXY` is not set
- passes those values explicitly on the command line

If you remember only one thing from this README, remember this one.

## Quick start

1. Create an env file:

```bash
cp .env.example .env
```

2. Build and start:

```bash
docker compose up -d --build
```

3. Inspect status:

```bash
docker compose logs -f
docker compose exec yandex-disk yandex-disk status --config=/config/config.cfg --dir=/data --auth=/config/passwd
```

## Two setup paths

### Path 1: fresh authorization

Use this when you are creating a new server-side Yandex Disk client from scratch.

Create `.env`, then run:

```bash
docker compose run --rm yandex-disk token
```

The client prints a URL and one-time code. Complete the browser flow, then start the service:

```bash
docker compose up -d
```

### Path 2: migrate an existing Yandex Disk host

Use this when you already have a working Yandex Disk installation on another machine and want to preserve the same account and client identity.

The minimum useful migration is usually:

```text
old-host ~/.config/yandex-disk/config.cfg
old-host ~/.config/yandex-disk/passwd
old-host ~/.config/yandex-disk/iid
```

If you only want the new host to refill its local tree from the cloud, do not copy the whole sync payload.

If you are migrating from an existing setup, rewrite `config.cfg` for container paths:

```ini
auth="/config/passwd"
dir="/data"
exclude-dirs="folder1,folder2"
proxy="no"
```

## Configuration

The main runtime knobs are in `.env`:

```dotenv
YANDEX_CONTAINER_NAME=yandex-disk-shared
YANDEX_UID=1000
YANDEX_GID=1000
YANDEX_HOST_CONFIG_DIR=/opt/yandex-disk-shared/config
YANDEX_HOST_DATA_DIR=/opt/yandex-disk-shared/data
YANDEX_PROXY=
YANDEX_EXCLUDE_DIRS=
YANDEX_READ_ONLY=false
YANDEX_OVERWRITE=false
```

Notes:

- `YANDEX_EXCLUDE_DIRS` overrides `exclude-dirs` from `config.cfg`
- if `YANDEX_EXCLUDE_DIRS` is empty, the entrypoint falls back to `config.cfg`
- `YANDEX_PROXY` behaves the same way
- `YANDEX_READ_ONLY=true` is useful for cautious first runs

## Day-to-day operations

Show container state:

```bash
docker compose ps
```

Check Yandex status:

```bash
docker compose exec yandex-disk yandex-disk status --config=/config/config.cfg --dir=/data --auth=/config/passwd
```

Tail Docker logs:

```bash
docker compose logs -f
```

Tail the client logs that actually matter:

```bash
docker compose exec yandex-disk sh -lc 'tail -n 80 /data/.sync/cli.log'
docker compose exec yandex-disk sh -lc 'tail -n 120 /data/.sync/core.log'
```

See whether files are appearing:

```bash
find /opt/yandex-disk-shared/data -maxdepth 1 -mindepth 1
du -sh /opt/yandex-disk-shared/data
```

## Troubleshooting

### The config file looks right, but excluded directories still sync

Check the startup log first:

```bash
docker compose exec yandex-disk sh -lc 'tail -n 40 /data/.sync/cli.log'
```

You should see lines like:

```text
Exclude dir: folder1
Exclude dir: folder2
```

If those lines are missing, the runtime path is not using the exclude list you think it is.

### `passwd` is present, but auth still behaves strangely

Make sure `iid` is also present under the mounted config directory:

```bash
ls -la /opt/yandex-disk-shared/config
```

### Docker logs are quiet

That is normal. The more useful logs are:

- `/data/.sync/cli.log`
- `/data/.sync/core.log`

### `status` says `no internet access`

That message is not always literal. On this legacy client it can also show up during weird startup/auth states or transient request failures. Check `core.log` before assuming Docker networking is broken.

## Woodpecker deployment

This repo includes `.woodpecker.yml` for SSH-based deployment to `catarchy2`.

The deployment model is:

- upload `Dockerfile`, `docker-compose.yml`, `docker-entrypoint.sh`, and `.env`
- preserve `/opt/yandex-disk-shared/config`
- preserve `/opt/yandex-disk-shared/data`
- rebuild and recreate the container on the target server

This is intentionally stateful. CI updates the recipe, not the synced data.

## Example live checks on `catarchy2`

```bash
cd /opt/yandex-disk-shared
sudo docker compose --env-file .env ps
sudo docker exec yandex-disk-shared yandex-disk status --config=/config/config.cfg --dir=/data --auth=/config/passwd
sudo docker exec yandex-disk-shared sh -lc 'tail -n 80 /data/.sync/cli.log'
sudo docker exec yandex-disk-shared sh -lc 'tail -n 120 /data/.sync/core.log'
sudo find /opt/yandex-disk-shared/data -maxdepth 1 -mindepth 1
```

## Why this may be useful to others

This repo is most useful if you are in one of these situations:

- you use Yandex Disk and want it on a headless Linux server
- you want a reproducible Docker-based deployment instead of a desktop-session daemon
- you need to preserve legacy identity/state while moving hosts
- you want CI/CD to manage the deployment recipe without destroying sync state