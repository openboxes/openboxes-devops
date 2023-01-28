#!/bin/bash
set -euo pipefail

usage()
{
    echo >&2 "$0 - reset/recreate an OpenBoxes database"
    echo >&2 ''
    echo >&2 "Usage: $0 [-s] [-d <db_name>] [-p <mysql_path> ] [-u <db_user> ]"
    echo >&2 ''
    echo >&2 'Options:'
    echo >&2 '  -s use sudo when accessing db server (if using auth_socket for root)'
    echo >&2 '  -d <db_name> -- name of database to reset/recreate (default: "openboxes")'
    echo >&2 '  -p <mysql_path> -- path under which mysql is installed'
    echo >&2 '  -u <db_user> -- name of database user (default: "root")'

    [ "$@" ] && exit "$@" || exit 2
}

db_name='openboxes'
db_user='root'
local_sudo=
mysql_path=/usr/bin:/usr/local/mysql/bin

while getopts 'd:hp:su:' o
do
    case "$o" in
    d)
        [ "$OPTARG" ] || usage
        db_name="$OPTARG"
        ;;
    h)
        usage 0
        ;;
    p)
        [ "$OPTARG" ] || usage
        mysql_path="$OPTARG:$mysql_path"
        ;;
    s)
        local_sudo=sudo
        ;;
    u)
        [ "$OPTARG" ] || usage
        db_user="$OPTARG"
        ;;
    *)
        usage
        ;;
    esac
done
shift $((OPTIND-1))

set +u
[ "$#" -eq 0 ] || usage
if [ ! "$DB_PASSWORD" ]
then
    echo >&2 'please set the DB_PASSWORD environment variable'
    exit 1
fi
set -u

export PATH=$PATH:$mysql_path
$local_sudo true

echo "(Re)initializing database \`$db_name\` ..."
$local_sudo mysql -u "$db_user" -p"$DB_PASSWORD" -e "drop database if exists \`$db_name\`;"
$local_sudo mysql -u "$db_user" -p"$DB_PASSWORD" -e "create database \`$db_name\` default charset utf8; grant all on \`$db_name\`.* to 'openboxes'@'localhost' identified by 'openboxes';"
$local_sudo mysql -u "$db_user" -p"$DB_PASSWORD" "$db_name" -e 'select 1' > /dev/null

echo 'Done'
