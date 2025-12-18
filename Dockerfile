FROM caddy:2.10.2-builder-alpine AS builder

ENV CADDY_MAXMIND_VERSION=v1.0.1
ENV CADDY_L4_HASH=66170bec9f4d6a015e31b04545afa1f90a873b3f

WORKDIR /usr/bin

RUN set -ex; \
    xcaddy build --with github.com/porech/caddy-maxmind-geolocation@"$CADDY_MAXMIND_VERSION" \
        --with github.com/mholt/caddy-l4@"$CADDY_L4_HASH"; \
    /usr/bin/caddy list-modules

FROM alpine:3.23.2

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

# Needed for Nextcloud AIO so that image cleanup can work. 
# Unfortunately, this needs to be set in the Dockerfile in order to work.
LABEL org.label-schema.vendor="Nextcloud"
