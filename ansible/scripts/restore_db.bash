#!/bin/bash
set -euo pipefail

usage()
{
    echo >&2 "$0 - restore an OpenBoxes database from a file"
    echo >&2 ''
    echo >&2 "Usage: $0 [-fs] [-d <db_name>] [-i <archive_file>] [-p <mysql_path>] [-u <db_user>]"
    echo >&2 ''
    echo >&2 'Options:'
    echo >&2 '  -f Completely delete <db_name>, if it exists, before restoring -- use with care!'
    echo >&2 '  -s use sudo when accessing db server (if using auth_socket for root)'
    echo >&2 '  -c <host_name> -- name of host from which to allow client access (default: "localhost")'
    echo >&2 '  -d <db_name> -- name under which database should be stored (default: "openboxes")'
    echo >&2 '  -i <archive_file> -- name of archive file to restore (default: "<db_name>.tgz")'
    echo >&2 '  -p <mysql_path> -- path under which mysql is installed'
    echo >&2 '  -u <db_user> -- name of database user (default: "openboxes")'

    [ "$@" ] && exit "$@" || exit 2
}

archive_file=
db_client='localhost'
db_name='openboxes'
db_user='openboxes'
local_sudo=
mysql_path=/usr/bin:/usr/local/mysql/bin

while getopts 'c:d:fhi:p:r:su:' o
do
    case "$o" in
    c)
        [ "$OPTARG" ] || usage
        db_client="$OPTARG"
        ;;
    d)
        [ "$OPTARG" ] || usage
        db_name="$OPTARG"
        ;;
    f)
        do_clobber=1
        ;;
    h)
        usage 0
        ;;
    i)
        [ "$OPTARG" ] || usage
        archive_file="$OPTARG"
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
if [ ! "$DB_ROOT_PASSWORD" ]
then
    echo >&2 'please set the DB_ROOT_PASSWORD environment variable'
    exit 1
fi
if [ ! "$DB_USER_PASSWORD" ]
then
    echo >&2 'please set the DB_USER_PASSWORD environment variable'
    exit 1
fi
set -u

sql_basename="$db_name"
[ "$archive_file" ] || archive_file="${sql_basename}.tgz"
export PATH=$PATH:$mysql_path

scratch_dir=$(mktemp -d)
delete_scratch_dir() {
    rm -rf "$scratch_dir"
}
trap delete_scratch_dir EXIT
cd "$scratch_dir"
$local_sudo true

echo "Extracting archived database from $archive_file ..."
tar xvf "$OLDPWD/$archive_file"

database_exists=$($local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -Nse "select count(schema_name) from information_schema.schemata where schema_name = '$db_name';")
if [ "${do_clobber:-}" ]
then
    echo "Clobbering database \`$db_name\` ..."
    $local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "drop database if exists \`$db_name\`;"
elif [ "$database_exists" -ne 0 ]
then
    echo >&2 "Database \`$db_name\` exists and -f was not set!"
    exit 2
fi

echo "Initializing database \`$db_name\` ..."
$local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "drop database if exists \`$db_name\`;"
$local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "drop user if exists '$db_user'@'$db_client'; create user '$db_user'@'$db_client' identified by '$DB_USER_PASSWORD'; flush privileges;"
$local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "create database \`$db_name\` default charset utf8mb4 default collate utf8mb4_unicode_ci; grant all on \`$db_name\`.* to '$db_user'@'$db_client';"
$local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "delete from mysql.user where User = 'finance';"
if [ "$db_client" == 'localhost' ]
then
    $local_sudo mysql -u "$db_user" -p"$DB_USER_PASSWORD" "$db_name" -e 'select 1' > /dev/null
fi

echo "Inserting schema into database \`$db_name\` ..."
original_db_name=$(basename ./*-schema.sql -schema.sql)
cat "${original_db_name}-schema.sql" \
    | sed "/SQL SECURITY DEFINER/! s/\`$original_db_name\`/\`$db_name\`/g" \
    | sed '/SQL SECURITY DEFINER/ s/@`[^`]*`/@`localhost`/g' \
    | sed 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g' \
    | $local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" "$db_name"

#
# Prevent "ERROR 2006 (HY000): MySQL server has gone away" by temporarily
# increasing max_allowed_packet, if needed. MySQL 5.7's default value of 4M
# may not be enough to consistently copy a production OB database, but if the
# db server has already increased it, we don't need, or want, to change it.
#
# see also https://stackoverflow.com/questions/10474922/error-2006-hy000-mysql-server-has-gone-away
#
curr_max_packet=$($local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -Nse 'select @@max_allowed_packet;')
if [ "$curr_max_packet" -lt 16777216 ]
then
    echo 'Temporarily increasing max_allowed_packet to 16M ...'
    $local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e 'set global max_allowed_packet=16*1024*1024;'
fi

echo "Inserting data into database \`$db_name\` (this may take several minutes) ..."
$local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" "$db_name" < "${original_db_name}-data.sql"

if [ "$curr_max_packet" -lt 16777216 ]
then
    echo 'Restoring previous max_allowed_packet ...'
    $local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "set global max_allowed_packet=$curr_max_packet;"
fi

# clear Liquibase's change log lock (it was reserved on a different host)
$local_sudo mysql -u root -p"$DB_ROOT_PASSWORD" "$db_name" -e 'UPDATE DATABASECHANGELOGLOCK SET LOCKED=0, LOCKGRANTED=null, LOCKEDBY=null where ID=1;'

echo -n "Counting products in database \`$db_name\` ..."
product_cnt=$($local_sudo mysql -u "$db_user" -p"$DB_USER_PASSWORD" "$db_name" -Nse 'select count(id) from product;')
echo " $product_cnt"

echo 'Done'
