#!/bin/bash
set -euo pipefail

usage()
{
    echo >&2 "$0 - archive an OpenBoxes database to a file"
    echo >&2 ''
    echo >&2 "Usage: $0 [-sP] [-d <db_name>] [-o <archive_file>] [-p <mysql_path>] [-u <db_user>]"
    echo >&2 ''
    echo >&2 'Options:'
    echo >&2 '  -s use sudo when accessing db server (if using auth_socket for root)'
    echo >&2 '  -P Copy product_demand tables (will fail if refreshProductDemandData is running on remote)'
    echo >&2 '  -d <db_name> -- name of database to archive (default: "openboxes")'
    echo >&2 '  -o <archive_file> -- name of archive file (default: "<db_name>.tgz")'
    echo >&2 '  -p <mysql_path> -- path under which mysql is installed'
    echo >&2 '  -u <db_user> -- name of database user (default: "openboxes")'

    [ "$@" ] && exit "$@" || exit 2
}

archive_file=
db_name='openboxes'
db_user='openboxes'
local_sudo=
mysql_path=/usr/bin:/usr/local/mysql/bin
declare -a ignored_tables=()

while getopts 'd:ho:p:r:su:P' o
do
    case "$o" in
    d)
        [ "$OPTARG" ] || usage
        db_name="$OPTARG"
        ;;
    h)
        usage 0
        ;;
    o)
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
    P)
        do_copy_product_demand=1
        ;;
    *)
        usage
        ;;
    esac
done
shift $((OPTIND-1))

set +u
[ "$#" -eq 0 ] || usage
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

echo -n "Counting products in database \`$db_name\` ..."
product_cnt=$($local_sudo mysql -u "$db_user" -p"$DB_USER_PASSWORD" "$db_name" -Nse 'select count(id) from product;')
echo " $product_cnt"

if [ ! "${do_copy_product_demand:-}" ]
then
    #
    # ReportService.refreshProductDemandData() drops tables while it works,
    # which can generate "ERROR 1146 (42S02) at line XXXX: Table doesn't exist"
    # errors and make dependent views un-reconstructable.
    #
    declare -a nocreate_tables=(
        'product_demand_details'
        'product_demand_details_tmp'
        'product_expiry_summary'  # this view is invalid when product_demand_details is dropped
    )
    echo 'Skipping tables overwritten by ReportService.refreshProductDemandData() ...'
    for it in "${nocreate_tables[@]}"
    do
        echo " - will not create \`$it\`"
        ignored_tables+=("--ignore-table=$db_name.$it")
    done
fi

echo "Exporting schema (ignoring ${#ignored_tables[@]} tables) from database \`$db_name\` ..."
$local_sudo mysqldump -u "$db_user" -p"$DB_USER_PASSWORD" \
    --opt --allow-keywords --events --no-data --routines --single-transaction \
    "${ignored_tables[@]:-}" "$db_name" \
    > "${sql_basename}-schema.sql"

# quick sanity check -- preceding command has some tricky shell expressions
if [ ! "${do_copy_product_demand:-}" ]
then
    instance_count=$(grep -c "${nocreate_tables[0]}" "${sql_basename}-schema.sql" || :)
    if [ "$instance_count" != "0" ]
    then
        echo >&2 "failed to filter tables as expected; at least ${instance_count} product-demand references remain"
        exit 5
    fi
fi

echo "Inspecting tables in database \`$db_name\` ..."
nocopy_tables=$($local_sudo mysql -u "$db_user" -p"$DB_USER_PASSWORD" -Nse 'select table_name from information_schema.tables where (table_schema like "'"$db_name"'") and (table_name like "%_dimension" or table_name like "%_fact" or table_name like "%_snapshot");')

for it in $nocopy_tables
do
    echo " - will not copy \`$it\`"
    ignored_tables+=("--ignore-table=$db_name.$it")
done

echo "Exporting data (ignoring ${#ignored_tables[@]} tables) from database \`$db_name\` ..."
$local_sudo mysqldump -u "$db_user" -p"$DB_USER_PASSWORD" \
    --opt --allow-keywords --no-create-info --single-transaction \
    "${ignored_tables[@]:-}" "$db_name" \
    > "${sql_basename}-data.sql"

echo "Compressing data to $archive_file ..."
tar acvf "$OLDPWD/$archive_file" "${sql_basename}-schema.sql" "${sql_basename}-data.sql"

echo 'Done'
