FROM caddy:2.11.2-builder-alpine AS builder

ENV CADDY_MAXMIND_VERSION=v1.0.3
ENV CADDY_L4_HASH=afd229714fb14a387f0736cab048afeb72b8946a
# latest commit as of 2025-12-05 (no tagged releases)
ENV CADDY_DESEC_DNS_HASH=8cc02bae2ef0445a8c51735e2aac00ea7f6bbf30

WORKDIR /usr/bin

RUN set -ex; \
    xcaddy build --with github.com/porech/caddy-maxmind-geolocation@"$CADDY_MAXMIND_VERSION" \
        --with github.com/mholt/caddy-l4@"$CADDY_L4_HASH" \
        --with github.com/soju841/caddy-dns-desec@"$CADDY_DESEC_DNS_HASH"; \
    /usr/bin/caddy list-modules

FROM alpine:3.23.4

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
