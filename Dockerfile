FROM alpine:3.18.4

# hadolint ignore=DL3018
RUN set -ex; \
    apk add --no-cache fail2ban tzdata util-linux-misc bash nftables ip6tables; \
    mv /etc/fail2ban/filter.d/common.conf /tmp/; \
    rm -r /etc/fail2ban/jail.d/*; \
    rm -r /etc/fail2ban/filter.d/*; \
    mv /tmp/common.conf /etc/fail2ban/filter.d/

COPY --chmod=775 start.sh /start.sh

# hadolint ignore=DL3002
USER root
ENTRYPOINT [ "/start.sh" ]
