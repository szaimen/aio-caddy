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

    if [ -f /nextcloud/admin/files/nextcloud-aio-caddy/allowed-IPs-vaultwarden.txt ]; then 
        ALLOWED_IPS_VAULTWARDEN=$(cat /nextcloud/admin/files/nextcloud-aio-caddy/allowed-IPs-vaultwarden.txt)
        if [ -n "$ALLOWED_IPS_VAULTWARDEN" ]; then
            cat << CADDY >> /Caddyfile
        @public_networks not remote_ip $ALLOWED_IPS_VAULTWARDEN
        respond @public_networks 403 {
            close
        }
CADDY
        fi
    fi
	
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
CADDY

	if [ -f /nextcloud/admin/files/nextcloud-aio-caddy/allowed-IPs-stalwart.txt ]; then 
        ALLOWED_IPS_STALWART=$(cat /nextcloud/admin/files/nextcloud-aio-caddy/allowed-IPs-stalwart.txt)
        if [ -n "$ALLOWED_IPS_STALWART" ]; then
            cat << CADDY >> /Caddyfile
        @public_networks not remote_ip $ALLOWED_IPS_STALWART
        respond @public_networks 403 {
            close
        }
CADDY
        fi
    fi
	
	cat << CADDY >> /Caddyfile
    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
https://autoconfig.{\$NC_DOMAIN}:443 {
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
https://autodiscover.{\$NC_DOMAIN}:443 {
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
CADDY

	if [ -f /nextcloud/admin/files/nextcloud-aio-caddy/allowed-IPs-lldap.txt ]; then 
        ALLOWED_IPS_LLDAP=$(cat /nextcloud/admin/files/nextcloud-aio-caddy/allowed-IPs-lldap.txt)
        if [ -n "$ALLOWED_IPS_LLDAP" ]; then
            cat << CADDY >> /Caddyfile
        @public_networks not remote_ip $ALLOWED_IPS_LLDAP
        respond @public_networks 403 {
            close
        }
CADDY
        fi
    fi

 	cat << CADDY >> /Caddyfile
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

if nc -z -w 30 host.docker.internal 8096 && ! grep -q "host.docker.internal:8096" /Caddyfile; then
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

if [ -n "$(dig A +short nextcloud-aio-jellyseerr)" ] && ! grep -q nextcloud-aio-jellyseerr /Caddyfile; then
    cat << CADDY >> /Caddyfile
https://requests.{\$NC_DOMAIN}:443 {
    # import GEOFILTER
    reverse_proxy nextcloud-aio-jellyseerr:5055

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
fi

if [ -n "$(dig A +short nextcloud-aio-nextcloud-exporter)" ] && ! grep -q "nextcloud-aio-nextcloud-exporter" /Caddyfile; then
    echo "INFO: nextcloud-aio-nextcloud-exporter detected, configuring metrics endpoint..."

    # Use hardcoded username and environment variable for password
    METRICS_USERNAME="metrics"

    if [ -n "$NEXTCLOUD_EXPORTER_CADDY_PASSWORD" ]; then
        echo "INFO: Generating password hash for metrics authentication..."
        METRICS_PASSWORD_HASH=$(caddy hash-password --plaintext "$NEXTCLOUD_EXPORTER_CADDY_PASSWORD")

        cat << CADDY >> /Caddyfile
https://metrics.{\$NC_DOMAIN}:443 {
    # import GEOFILTER

    # Basic authentication for metrics endpoint
    basicauth {
        $METRICS_USERNAME $METRICS_PASSWORD_HASH
    }

    # Rewrite root path to /metrics for the upstream
    rewrite / /metrics

    reverse_proxy nextcloud-aio-nextcloud-exporter:9205

    # TLS options
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
}
CADDY
        echo "INFO: Metrics endpoint configuration completed successfully"
    else
        echo "WARNING: NEXTCLOUD_EXPORTER_CADDY_PASSWORD environment variable not set"
        echo "WARNING: Skipping metrics endpoint configuration - authentication required"
    fi
fi

if [ -n "$(dig A +short nextcloud-aio-talk)" ] && ! grep -q nextcloud-aio-talk /Caddyfile; then
    cat << CADDY > /tmp/turn.config
            layer4 {
                @turn not tls
                route @turn {
                        proxy nextcloud-aio-talk:443
                    }
                route
            }
CADDY
    CADDYFILE="$(sed "/layer4-placeholder/r /tmp/turn.config" /Caddyfile)"
    echo "$CADDYFILE" > /Caddyfile
fi

if [ -n "$APACHE_IP_BINDING" ] && [ "$APACHE_IP_BINDING" != "@INTERNAL" ] && ! grep -q proxy_protocol /Caddyfile; then
    cat << CADDY > /tmp/proxy.config
            proxy_protocol {
                timeout 5s
                allow $APACHE_IP_BINDING
                fallback_policy skip
            }
CADDY
    CADDYFILE="$(sed "/proxy-protocol-placeholder/r /tmp/proxy.config" /Caddyfile)"
    echo "$CADDYFILE" > /Caddyfile
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
