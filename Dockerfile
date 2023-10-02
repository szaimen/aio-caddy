
FROM golang:1.21.1-alpine3.18 as go

ENV XCADDY_VERSION v0.3.5
ENV CADDY_HASH 29233e285b83dfa070d1f6889c021cb32c161b89

# hadolint ignore=DL3018
RUN set -ex; \
    apk add --no-cache \
        build-base \
        git; \
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@"$XCADDY_VERSION"; \
    chmod +x /go/bin/xcaddy; \
    /go/bin/xcaddy build --with github.com/porech/caddy-maxmind-geolocation@"$CADDY_HASH"

FROM alpine:3.18.4

# hadolint ignore=DL3018
RUN set -ex; \
    apk add --no-cache shadow; \
    groupmod -g 333 xfs; \
    usermod -u 333 -g 333 xfs; \
    groupdel www-data; \
    addgroup -g 33 -S www-data; \
    adduser -u 33 -D -S -G www-data www-data; \
    apk del shadow; \
    apk add --no-cache tzdata bash bind-tools netcat-openbsd; \
    mkdir /data; \
    chown 33:33 -R /data; \
    chmod 770 -R /data

VOLUME /data

COPY --from=go /go/caddy /usr/local/bin/caddy
COPY --chmod=775 start.sh /start.sh
COPY --chmod=664 Caddyfile /Caddyfile

USER www-data
ENTRYPOINT [ "/start.sh" ]
