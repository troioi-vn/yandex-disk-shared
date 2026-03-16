# Yandex Disk Shared

This repo packages the Yandex Disk Linux console client for deployment on `catarchy2` and preserves runtime state on the server under `/opt/yandex-disk-shared`.

## Runtime layout

The deploy target is:

```text
/opt/yandex-disk-shared/
  Dockerfile
  docker-compose.yml
  docker-entrypoint.sh
  .env
  config/
    config.cfg
    passwd
  data/
```

`config/` and `data/` are intentionally server-local and ignored by git. The container reads the migrated `config.cfg` directly, so the old exclude list and proxy setting continue to apply.
The same `config/` directory is also mounted at the client's default `~/.config/yandex-disk` path so legacy files like `iid` remain visible to the Yandex binary.

## Local usage

Create a local env file first:

```bash
cp .env.example .env
```

If you need a fresh token flow instead of migrating an old auth file:

```bash
docker compose run --rm yandex-disk token
```

Start the sync client:

```bash
docker compose up -d --build
```

Inspect logs:

```bash
docker compose logs -f
```

## Deployment

Woodpecker deploys this repo to `catarchy2` over SSH and keeps the persistent state in `/opt/yandex-disk-shared/config` and `/opt/yandex-disk-shared/data`.

The first migration should copy these from `catarchy`:

```text
/home/ubuntu/.config/yandex-disk/passwd
/home/ubuntu/.config/yandex-disk/config.cfg
/home/ubuntu/Yandex.Disk/
```

The migrated `config.cfg` should use container paths:

```ini
auth="/config/passwd"
dir="/data"
exclude-dirs="backup2,Mama,MyDoc,share,work,Мяу2,Meo2,Фотокамера,backup/qr/.git"
proxy="no"
```

## Aha

For stateful infra in CI/CD, the clean split is:

- Git stores the deploy recipe.
- The server stores runtime state and secrets.
- CI updates code and preserves stateful directories across deploys.
