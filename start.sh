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
# Reset the file
sed -i "/(GEOFILTER)/,$ d" /Cadddyfile

while ! [ -f /nextcloud/admin/files/nextcloud-aio-caddy/allowed-countries.txt ]; do
    echo "Waiting for allowed-countries.txt file to be created"
    sleep 5
done

ALLOW_CONTRIES="$(head -n 1 filename /nextcloud/admin/files/nextcloud-aio-caddy/allowed-countries.txt)"
if echo "$ALLOW_CONTRIES" | grep -q '^[A-Z ]\+$'; then
    FILTER_SET=1
fi
if [ -f "/nextcloud/admin/files/nextcloud-aio-caddy/GeoLite2-Country.mmdb" ]; then
    rm -f /data/GeoLite2-Country.mmdb
    cp /nextcloud/admin/files/nextcloud-aio-caddy/GeoLite2-Country.mmdb /data/
    FILE_THERE=1
fi

if [ "$FILTER_SET" = 1 ] && [ "$FILE_THERE" = 1 ]; then
    cat << CADDY >> /Caddyfile
(GEOFILTER) {
    @geofilter {
        not maxmind_geolocation {
            db_path "/data/GeoLite2-Country.mmdb"
            allow_countries $ALLOW_CONTRIES
        }
        not remote_ip private_ranges
    }
    respond @geofilter 403
}
CADDY
fi

cat << CADDY >> /Caddyfile
https://{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy nextcloud-aio-apache:{\$APACHE_PORT}

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY

if [ -n "$(dig A +short nextcloud-aio-vaultwarden)" ]; then
    cat << CADDY >> /Caddyfile
https://bw.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy nextcloud-aio-vaultwarden:8812

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

if [ "$FILTER_SET" = 1 ] && [ "$FILE_THERE" = 1 ]; then
    sed -i "s|# import GEOFILTER|import GEOFILTER|" /Caddyfile
fi
set +x

caddy fmt --overwrite /Caddyfile

caddy run --config /Caddyfile
