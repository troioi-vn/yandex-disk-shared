FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL http://repo.yandex.ru/yandex-disk/YANDEX-DISK-KEY.GPG | gpg --dearmor -o /etc/apt/keyrings/yandex-disk.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/yandex-disk.gpg] http://repo.yandex.ru/yandex-disk/deb/ stable main" > /etc/apt/sources.list.d/yandex-disk.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends yandex-disk \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/config", "/data"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["run"]