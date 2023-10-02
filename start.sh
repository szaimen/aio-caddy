#!/bin/bash

# Fix socket
rm -f /run/fail2ban/*

if ! mountpoint -q /nextcloud; then
    echo "/nextcloud is not a mountpoint which it must be!"
    exit 1
fi

while ! [ -f /nextcloud/data/nextcloud.log ]; do
    echo "Waiting for /nextcloud/data/nextcloud.log to become available"
    sleep 5
done

cat << FILTER > /etc/fail2ban/filter.d/nextcloud.conf
[INCLUDES]
before = common.conf

[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
FILTER

cat << JAIL > /etc/fail2ban/jail.d/nextcloud.local
[nextcloud]
enabled = true
port = 80,443,8080,8443,3478
protocol = tcp,udp
filter = nextcloud
banaction = %(banaction_allports)s
maxretry = 3
bantime = 14400
findtime = 14400
logpath = /nextcloud/data/nextcloud.log
chain=DOCKER-USER
JAIL

if [ -f /vaultwarden/vaultwarden.log ]; then
    echo "Configuring vaultwarden for logs"
    # Vaultwarden conf
    cat << BW_CONF > /etc/fail2ban/filter.d/vaultwarden.conf
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
ignoreregex =
BW_CONF

    # Vaultwarden jail
    cat << BW_JAIL_CONF > /etc/fail2ban/jail.d/vaultwarden.local
[vaultwarden]
enabled = true
port = 80,443,8812
protocol = tcp,udp
filter = vaultwarden
banaction = %(banaction_allports)s
logpath = /vaultwarden/vaultwarden.log
maxretry = 3
bantime = 14400
findtime = 14400
chain=DOCKER-USER
BW_JAIL_CONF

    # Vaultwarden-admin conf
    cat << BWA_CONF > /etc/fail2ban/filter.d/vaultwarden-admin.conf
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Invalid admin token\. IP: <ADDR>.*$
ignoreregex =
BWA_CONF

    # Vaultwarden-admin jail
    cat << BWA_JAIL_CONF > /etc/fail2ban/jail.d/vaultwarden-admin.local
[vaultwarden-admin]
enabled = true
port = 80,443,8812
protocol = tcp,udp
filter = vaultwarden-admin
banaction = %(banaction_allports)s
logpath = /vaultwarden/vaultwarden.log
maxretry = 3
bantime = 14400
findtime = 14400
chain=DOCKER-USER
BWA_JAIL_CONF
fi

fail2ban-server -f --logtarget stderr --loglevel info 
