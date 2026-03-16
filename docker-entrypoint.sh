#!/bin/sh
set -eu

CONFIG_DIR="${YANDEX_CONFIG_DIR:-/config}"
SYNC_DIR="${YANDEX_SYNC_DIR:-/data}"
AUTH_FILE="${YANDEX_AUTH_FILE:-${CONFIG_DIR}/passwd}"
PROXY="${YANDEX_PROXY:-}"
EXCLUDE_DIRS="${YANDEX_EXCLUDE_DIRS:-}"
READ_ONLY="${YANDEX_READ_ONLY:-false}"
OVERWRITE="${YANDEX_OVERWRITE:-false}"

mkdir -p "$CONFIG_DIR" "$SYNC_DIR"

COMMAND="${1:-run}"

case "$COMMAND" in
    token)
        shift || true
        exec yandex-disk token "$AUTH_FILE"
        ;;
    run)
        shift || true
        set -- --no-daemon "--dir=${SYNC_DIR}" "--auth=${AUTH_FILE}"

        if [ -n "$EXCLUDE_DIRS" ]; then
            set -- "$@" "--exclude-dirs=${EXCLUDE_DIRS}"
        fi

        if [ -n "$PROXY" ]; then
            set -- "$@" "--proxy=${PROXY}"
        fi

        if [ "$READ_ONLY" = "true" ]; then
            set -- "$@" --read-only
        fi

        if [ "$OVERWRITE" = "true" ]; then
            set -- "$@" --overwrite
        fi

        exec yandex-disk "$@"
        ;;
    shell)
        shift || true
        exec /bin/sh "$@"
        ;;
    *)
        exec "$@"
        ;;
esac