#!/bin/bash

if ! mountpoint -q /data; then
    echo "/data is not a mountpoint!"
    exit 1
fi

while ! nc -z nextcloud-aio-nextcloud 9001; do
    echo "Waiting for nextcloud to start"
    sleep 5
done

set -x
while ! [ -f /nextcloud/admin/files/nextcloud-aio-caddy/allowed-countries.txt ]; do
    echo "Waiting for allowed-countries.txt file to be created"
    sleep 5
done

# Get ipv4-address of caddy
IPv4_ADDRESS="$(dig nextcloud-aio-caddy A +short +search | head -1)"
# Bring it in CIDR notation
# shellcheck disable=SC2001
IPv4_ADDRESS="$(echo "$IPv4_ADDRESS" | sed 's|[0-9]\+$|0/16|')"
CADDYFILE="$(sed "s|trusted_proxies.*|trusted_proxies static $IPv4_ADDRESS|" /Caddyfile)"
echo "$CADDYFILE" > /Caddyfile

ALLOW_CONTRIES="$(head -n 1 /nextcloud/admin/files/nextcloud-aio-caddy/allowed-countries.txt)"
if echo "$ALLOW_CONTRIES" | grep -q '^[A-Z ]\+$'; then
    FILTER_SET=1
fi
if [ -f "/nextcloud/admin/files/nextcloud-aio-caddy/GeoLite2-Country.mmdb" ]; then
    rm -f /data/GeoLite2-Country.mmdb
    cp /nextcloud/admin/files/nextcloud-aio-caddy/GeoLite2-Country.mmdb /data/
    FILE_THERE=1
fi
if [ -f "/nextcloud/admin/files/nextcloud-aio-caddy/block-vaultwarden-admin" ]; then
    VAULTWARDEN_BLOCK=1
fi

if [ -n "$(dig A +short nextcloud-aio-vaultwarden)" ] && ! grep -q nextcloud-aio-vaultwarden /Caddyfile; then
    cat << CADDY >> /Caddyfile
https://bw.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
CADDY

    if [ "$VAULTWARDEN_BLOCK" = 1 ]; then
        cat << CADDY >> /Caddyfile
    @blacklisted {
        not {
            path /admin*
        }
    }
    reverse_proxy @blacklisted nextcloud-aio-vaultwarden:8812
CADDY
    else
        cat << CADDY >> /Caddyfile
    reverse_proxy nextcloud-aio-vaultwarden:8812
CADDY
    fi

    cat << CADDY >> /Caddyfile
    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

if [ -n "$(dig A +short nextcloud-aio-stalwart)" ] && ! grep -q "mail.{\$NC_DOMAIN}" /Caddyfile; then
    cat << CADDY >> /Caddyfile
https://mail.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy nextcloud-aio-stalwart:10003

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
https://autoconfig.{\$NC_DOMAIN}.fr:443 {
    # import GEOFILTER
    route /mail/config-v1.1.xml {
        reverse_proxy nextcloud-aio-stalwart:10003
    }
    route {
        abort
    }
    
    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
https://autodiscover.{\$NC_DOMAIN}.fr:443 {
    # import GEOFILTER
    route /autodiscover/autodiscover.xml {
        reverse_proxy nextcloud-aio-stalwart:10003
    }
    route {
        abort
    }
    
    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

if [ -n "$(dig A +short nextcloud-aio-lldap)" ] && ! grep -q nextcloud-aio-lldap /Caddyfile; then
    cat << CADDY >> /Caddyfile
https://ldap.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy nextcloud-aio-lldap:17170

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

if [ -n "$(dig A +short nextcloud-aio-nocodb)" ] && ! grep -q nextcloud-aio-nocodb /Caddyfile; then
    cat << CADDY >> /Caddyfile
https://tables.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy nextcloud-aio-nocodb:10028

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

if nc -z host.docker.internal 8096 && ! grep -q "host.docker.internal:8096" /Caddyfile; then
    cat << CADDY >> /Caddyfile
https://media.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy host.docker.internal:8096

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

mkdir -p /data/caddy-imports
if ! grep -q "/data/caddy-imports" /Caddyfile; then
    echo 'import /data/caddy-imports/*' >> /Caddyfile
    # Make sure that the caddy-imports dir is not empty
    echo "# empty file so that caddy does not print a warning" > /data/caddy-imports/empty
fi

if [ "$FILTER_SET" = 1 ] && [ "$FILE_THERE" = 1 ]; then
    CADDYFILE="$(sed "s|allow_countries.*|allow_countries $ALLOW_CONTRIES|;s|# import GEOFILTER|  import GEOFILTER|" /Caddyfile)"
else
    CADDYFILE="$(sed "s|  import GEOFILTER|# import GEOFILTER|" /Caddyfile)"
fi
echo "$CADDYFILE" > /Caddyfile
set +x

caddy fmt --overwrite /Caddyfile

caddy run --config /Caddyfile
