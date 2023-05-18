#!/bin/bash
set -euo pipefail

usage()
{
    echo >&2 "$0 - back up an OpenBoxes database via ssh/scp"
    echo >&2 ''
    echo >&2 "Usage: $0 [-d <db_name>] [-u <db_user>] <target>"
    echo >&2 ''
    echo >&2 'Options:'
    echo >&2 '  -d <db_name> -- name of database to archive (default: "openboxes")'
    echo >&2 '  -u <db_user> -- name of user (default: "openboxes")'
    echo >&2 ''
	echo >&2 'Positional Parameter:'
    echo >&2 '  <target> the scp(1) target to which to copy the database archive'

    [ "$@" ] && exit "$@" || exit 2
}

archive_file=
db_name='openboxes'
db_user='openboxes'

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
[ "$#" -eq 1 ] || usage
set -u


PATH=$PATH:/opt:$(realpath $(dirname "$0"))
export PATH

scratch_dir=$(mktemp -d)
delete_scratch_dir() {
    rm -rf "$scratch_dir"
}
trap delete_scratch_dir EXIT

# UTC timestamp suitable for inclusion in a filename on BSD/Linux/Mac
timestamp=$(date -u +'%Y-%m-%dT%H-%M-%SZ')

target="$1"
archive_file="${db_name}.tgz"
target_directory="$(hostname)/${timestamp}"

set -x
ssh "${target}" "mkdir -p ${target_directory}"
cd "$scratch_dir"
archive_db.bash -d "$db_name" -u "$db_user"
scp "${archive_file}" "${target}:${target_directory}/${archive_file}"
set +x

echo 'Done'
