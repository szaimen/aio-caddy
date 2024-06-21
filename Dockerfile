FROM caddy:2.8.4-builder-alpine AS builder

ENV CADDY_HASH=8794ba5a3a9ff1cac49f9c40aed2841646de0324

RUN set -ex; \
    xcaddy build --with github.com/porech/caddy-maxmind-geolocation@"$CADDY_HASH"

FROM alpine:3.20.1

# hadolint ignore=DL3018
RUN set -ex; \
    apk add --no-cache shadow; \
    groupdel www-data; \
    addgroup -g 33 -S www-data; \
    adduser -u 33 -D -S -G www-data www-data; \
    apk del shadow; \
    apk add --no-cache tzdata bash bind-tools netcat-openbsd util-linux-misc; \
    mkdir -p /data/caddy; \
    chown 33:33 -R /data; \
    chmod 770 -R /data

VOLUME /data

COPY --from=builder /usr/bin/caddy /usr/local/bin/caddy
COPY --chmod=775 start.sh /start.sh
COPY --chown=33:33 Caddyfile /Caddyfile

USER www-data
ENTRYPOINT [ "/start.sh" ]
