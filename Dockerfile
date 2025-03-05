FROM caddy:2.9.1-builder-alpine AS builder

ENV CADDY_HASH=0012fcd15c96ac0ed357932f50899cc5a5f271b9

RUN set -ex; \
    xcaddy build --with github.com/porech/caddy-maxmind-geolocation@"$CADDY_HASH"

FROM alpine:3.21.3

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
